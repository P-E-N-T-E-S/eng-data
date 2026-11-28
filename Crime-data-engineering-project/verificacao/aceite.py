"""Aceite da AV1 usando AWS CLI v2 e a biblioteca padrão do Python."""
import argparse
import base64
import csv
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from decimal import Decimal, InvalidOperation
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TF = ROOT / "parte-1/terraform"
REFERENCE = ROOT / "evidencias"
TAGS = {"turma": "eda262", "grupo": "g04", "projeto": "engenharia-de-dados"}
MIB = 2**20


class AwsError(RuntimeError):
    def __init__(self, message):
        super().__init__(message)
        match = re.search(r"\(([^)]+)\) when calling", message)
        self.code = match.group(1) if match else ""


def require(condition, message):
    if not condition:
        raise ValueError(message)


def aws(*command):
    process = subprocess.run(["aws", *map(str, command), "--region", config["region"],
                              "--output", "json", "--no-cli-pager"], capture_output=True, text=True)
    if process.returncode:
        raise AwsError(process.stderr.strip())
    return json.loads(process.stdout) if process.stdout.strip() else {}


def save(name, value):
    (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def absent(code, *command):
    try:
        aws(*command)
    except AwsError as error:
        if error.code == code:
            return
        raise
    raise ValueError(f"recurso ainda presente: {' '.join(command)}")


def tf(*command):
    return subprocess.check_output(["terraform", *command], cwd=TF, text=True).strip()


def context():
    require(aws("sts", "get-caller-identity")["Account"] == config["conta"], "conta diferente do deploy")


def workspace():
    require(os.getenv("TF_VAR_region", config["region"]) == config["region"], "região diferente do inventário")
    require(tf("workspace", "show") == "av1", "workspace diferente de av1")
    local_state = Path(os.environ.get("TF_DATA_DIR", ".terraform")) / "terraform.tfstate"
    backend = json.loads((TF / local_state).read_text())["backend"]
    expected = {"bucket": config["state_bucket"], "region": config["region"],
                "dynamodb_table": config["lock_table"], "key": "av1/crime/terraform.tfstate"}
    require(backend["type"] == "s3" and all(backend["config"][k] == v for k, v in expected.items()),
            "backend inicializado difere do inventário do deploy")
    lock = aws("dynamodb", "describe-table", "--table-name", config["lock_table"])["Table"]
    check_tags(aws("dynamodb", "list-tags-of-resource", "--resource-arn", lock["TableArn"])["Tags"])
    s3_tags(config["state_bucket"])



def check_tags(items):
    actual = {tag["Key"]: tag["Value"] for tag in items}
    require(TAGS.items() <= actual.items(), f"tags exigidas ausentes ou divergentes: {TAGS}")


def s3_tags(bucket):
    check_tags(aws("s3api", "get-bucket-tagging", "--bucket", bucket,
                   "--expected-bucket-owner", config["conta"])["TagSet"])


def lake():
    require(int(tf("output", "-raw", "bytes_cutoff")) == config["bytes_cutoff"], "state diferente do inventário")
    s3_tags(config["bucket_name"])
    wg = aws("athena", "get-work-group", "--work-group", config["workgroup_name"])["WorkGroup"]
    settings = wg["Configuration"]
    require(wg["State"] == "ENABLED" and settings["EnforceWorkGroupConfiguration"]
            and settings["BytesScannedCutoffPerQuery"] == config["bytes_cutoff"], "workgroup ou teto incorreto")
    arn = f"arn:aws:athena:{config['region']}:{config['conta']}:workgroup/{wg['Name']}"
    check_tags(aws("athena", "list-tags-for-resource", "--resource-arn", arn)["Tags"])
    crawlers = aws("glue", "list-crawlers").get("CrawlerNames", [])
    require(not any(n.startswith("eda262-g04") for n in crawlers), "Crawler do grupo encontrado")


def schema():
    db = config["database_name"]
    name = config["table_name"]
    aws("glue", "get-database", "--name", db)
    arn = f"arn:aws:glue:{config['region']}:{config['conta']}:database/{db}"
    require(TAGS.items() <= aws("glue", "get-tags", "--resource-arn", arn)["Tags"].items(), "tags do banco incorretas")
    table = aws("glue", "get-table", "--database-name", db, "--name", name)["Table"]
    columns = [("uf","string"), ("municipio","string"), ("evento","string"), ("data_referencia","date"),
               ("agente","string"), ("arma","string"), ("faixa_etaria","string"), ("feminino","int"),
               ("masculino","int"), ("nao_informado","int"), ("total_vitima","int"), ("total","int"),
               ("total_peso","double"), ("abrangencia","string"), ("mes","int")]
    require([(c["Name"], c["Type"]) for c in table["StorageDescriptor"]["Columns"]] == columns, "schema divergente")
    require([(c["Name"], c["Type"]) for c in table["PartitionKeys"]] == [("ano","int")], "partição inválida")
    parts = aws("glue", "get-partitions", "--database-name", db, "--table-name", name)["Partitions"]
    bucket = config["bucket_name"]
    locations = {tuple(p["Values"]): p["StorageDescriptor"]["Location"] for p in parts}
    expected = {(str(v["ano"]),): f"s3://{bucket}/crime/ano={v['ano']}/" for v in volumes}
    require(locations == expected, "anos ou localizações no catálogo divergentes")
    for v in volumes:
        prefix = f"crime/ano={v['ano']}/"
        key = f"{prefix}BancoVDE_{v['ano']}.csv"
        objects = aws("s3api", "list-objects-v2", "--bucket", bucket, "--prefix", prefix)
        require([obj["Key"] for obj in objects.get("Contents", [])] == [key], f"arquivos imprevistos em {prefix}")
        obj = aws("s3api", "head-object", "--bucket", bucket, "--key", key, "--checksum-mode", "ENABLED",
                  "--expected-bucket-owner", config["conta"])
        require(obj["ContentLength"] == v["bytes"] and obj.get("ChecksumSHA256") ==
                base64.b64encode(bytes.fromhex(v["sha256"])).decode(), f"conteúdo diferente da edição em {key}")


def query(label, sql):
    (output / f"{label}.sql").write_text(sql, encoding="utf-8")
    qid = aws("athena", "start-query-execution", "--work-group", config["workgroup_name"],
              "--query-execution-context", json.dumps({"Database":config["database_name"]}),
              "--query-string", sql, "--result-reuse-configuration",
              '{"ResultReuseByAgeConfiguration":{"Enabled":false}}')["QueryExecutionId"]
    print(f"{label} · {qid}", flush=True)
    for _ in range(120):
        run = aws("athena", "get-query-execution", "--query-execution-id", qid)["QueryExecution"]
        if run["Status"]["State"] in ("SUCCEEDED", "CANCELLED", "FAILED"):
            break
        time.sleep(2)
    else:
        aws("athena", "stop-query-execution", "--query-execution-id", qid)
        raise ValueError(f"timeout na execução {qid}")
    save(f"{label}.json", {k:run[k] for k in ("QueryExecutionId","Status","Statistics")})
    return run


def identifier(name):
    return name.replace('"', '""')


def broad_query():
    name = f'"{identifier(config["database_name"])}"."{identifier(config["table_name"])}"'
    run = query("limite", f"SELECT SUM(total_vitima) FROM {name}")
    status = run["Status"]
    reason = status.get("StateChangeReason", "") + " " + status.get("AthenaError", {}).get("ErrorMessage", "")
    require(status["State"] in ("CANCELLED", "FAILED") and
            re.search(r"(bytes scanned limit|data scanned.{0,30}limit|scan limit|exceeded.{0,40}bytes)", reason, re.I),
            "consulta ampla sem cancelamento comprovado pelo limite de bytes: " + reason)


def estimated_cost(scanned, price):
    units = max(10, (scanned + MIB - 1) // MIB)
    return Decimal(units) * price / (2**20)


def business():
    template = (ROOT / "parte-1/consultas/homicidios.sql").read_text()
    with (REFERENCE / "homicidios-local.csv").open(encoding="utf-8") as stream:
        reference = list(csv.DictReader(stream))
    try:
        price = Decimal(os.getenv("ATHENA_USD_POR_TB", "5"))
    except InvalidOperation as error:
        raise ValueError("ATHENA_USD_POR_TB deve ser numérico") from error
    require(price.is_finite() and price > 0 and (config["region"] == "us-east-1" or "ATHENA_USD_POR_TB" in os.environ),
            "informe ATHENA_USD_POR_TB para a região do ensaio")
    results, costs = [], []
    for v in volumes:
        year = v["ano"]
        sql = template.format(database=identifier(config["database_name"]), table=identifier(config["table_name"]), year=year)
        run = query(str(year), sql)
        status = run["Status"]
        require(status["State"] == "SUCCEEDED", f"{year}: {status}")
        scanned = run["Statistics"]["DataScannedInBytes"]
        require(0 < scanned <= config["bytes_cutoff"], f"varredura fora do teto em {year}")
        qid = run["QueryExecutionId"]
        data = aws("athena", "get-query-results", "--query-execution-id", qid)["ResultSet"]["Rows"]
        cells = [[c.get("VarCharValue", "") for c in r["Data"]] for r in data]
        require(cells and cells[0] == ["uf","ano","vitimas","meses_informados"], "cabeçalho inesperado")
        rows = [dict(zip(cells[0], values, strict=True)) for values in cells[1:]]
        save(f"{year}-resultado.json", rows)
        cost = estimated_cost(scanned, price)
        costs.append(dict(ano=year, id=qid, bytes_lidos=scanned, usd_por_tb=str(price), custo_usd=format(cost, ".9f")))
        save("custos.json", costs)
        print(f"{year} · {len(rows)} UFs · {scanned} bytes · USD {cost:.9f}", flush=True)
        require(rows == [r for r in reference if r["ano"] == str(year)], f"indicador de {year} diverge do BancoVDE local")
        results.extend(rows)
    with (output / "homicidios-athena.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=results[0].keys())
        writer.writeheader()
        writer.writerows(results)


def backend_free():
    bucket = config["state_bucket"]
    items = aws("s3api", "list-objects-v2", "--bucket", bucket, "--expected-bucket-owner", config["conta"])
    for obj in items.get("Contents", []):
        key = obj["Key"]
        require(key == "env:/av1/av1/crime/terraform.tfstate", f"backend contém chave imprevista: {key}")
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "state"
            aws("s3api", "get-object", "--bucket", bucket, "--key", key, str(path))
            state = json.loads(path.read_text())
            require(isinstance(state.get("resources"), list) and not any(
                r.get("instances") for r in state["resources"] if r.get("mode", "managed") == "managed"),
                "backend possui recursos ativos")
    locks = aws("dynamodb", "scan", "--table-name", config["lock_table"], "--consistent-read")
    allowed = f"{bucket}/env:/av1/av1/crime/terraform.tfstate-md5"
    require(all(item["LockID"]["S"] == allowed for item in locks["Items"]), "lock ativo ou estado alheio no backend")


def destroyed():
    for bucket in (config["bucket_name"], config["state_bucket"]):
        absent("404", "s3api", "head-bucket", "--bucket", bucket, "--expected-bucket-owner", config["conta"])
    absent("EntityNotFoundException", "glue", "get-table", "--database-name", config["database_name"], "--name", config["table_name"])
    absent("EntityNotFoundException", "glue", "get-database", "--name", config["database_name"])
    absent("ResourceNotFoundException", "dynamodb", "describe-table", "--table-name", config["lock_table"])
    groups = aws("athena", "list-work-groups")["WorkGroups"]
    require(config["workgroup_name"] not in {g["Name"] for g in groups}, "workgroup ainda presente")


def main():
    global config, output, volumes
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    for flag in ("--pos-destroy", "--backend-livre", "--confere-contexto"):
        modes.add_argument(flag, action="store_true")
    args = parser.parse_args()
    inventory = ROOT / ".av1/inventario.json"
    require(inventory.is_file(), "inventário ausente: execute o deploy da AV1")
    config = json.loads(inventory.read_text())
    context()
    if args.backend_livre:
        backend_free()
        return 0
    if args.confere_contexto:
        workspace()
        return 0
    output = Path(os.environ["AV1_EVIDENCIAS"])
    if args.pos_destroy:
        tests = [("ausência dos recursos do lake e do backend", destroyed)]
    else:
        volumes = json.loads((REFERENCE / "volumes-local.json").read_text())
        tests = [("backend, tags e workspace av1", workspace), ("bucket, workgroup e ausência de Crawler", lake),
                 ("schema, partições e conteúdo da edição", schema), ("consulta ampla interrompida pelo teto", broad_query),
                 ("pergunta de negócio por ano, resultado e custo", business)]
    failures = 0
    for label, check in tests:
        try:
            check()
        except (RuntimeError, ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
            print(f"[FALHA] {label} — {error}")
            failures += 1
        else:
            print(f"[PASSA] {label}")
    return int(bool(failures))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, KeyError, ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f"[FALHA] {error}")
