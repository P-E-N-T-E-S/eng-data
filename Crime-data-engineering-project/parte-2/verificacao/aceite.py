"""Aceite executável da AV2 do projeto Crime Brasil."""

import argparse
import base64
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from decimal import Decimal, InvalidOperation
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PART = ROOT / "parte-2"
TF = PART / "terraform"
EVIDENCE = ROOT / "evidencias"
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


def aws(*command, env=None):
    process = subprocess.run(
        ["aws", *map(str, command), "--region", config["region"], "--output", "json", "--no-cli-pager"],
        capture_output=True,
        text=True,
        env=env,
    )
    if process.returncode:
        raise AwsError(process.stderr.strip())
    return json.loads(process.stdout) if process.stdout.strip() else {}


def tf(*command):
    return subprocess.check_output(["terraform", *command], cwd=TF, text=True).strip()


def check_tags(items):
    actual = {item["Key"]: item["Value"] for item in items}
    require(TAGS.items() <= actual.items(), f"tags obrigatórias ausentes: {TAGS}")


def s3_tags(bucket):
    check_tags(aws("s3api", "get-bucket-tagging", "--bucket", bucket,
                   "--expected-bucket-owner", config["account"])["TagSet"])


def context():
    identity = aws("sts", "get-caller-identity")
    require(identity["Account"] == config["account"], "conta diferente da usada no deploy")


def workspace():
    require(os.getenv("TF_VAR_region", config["region"]) == config["region"], "região divergente")
    require(tf("workspace", "show") == "av2", "workspace diferente de av2")
    require(int(tf("output", "-raw", "query_target_bytes")) == config["query_target_bytes"],
            "state diverge do inventário")


def catalog():
    for bucket in (config["raw_bucket"], config["trusted_bucket"], config["refined_bucket"]):
        s3_tags(bucket)

    expected_formats = {
        "raw": (config["database_raw"], config["table_raw"], "csv"),
        "trusted": (config["database_trusted"], config["table_trusted"], "parquet"),
        "refined": (config["database_refined"], config["table_refined"], "parquet"),
    }
    for layer, (database, table_name, classification) in expected_formats.items():
        database_data = aws("glue", "get-database", "--name", database)["Database"]
        arn = f"arn:aws:glue:{config['region']}:{config['account']}:database/{database}"
        actual_tags = aws("glue", "get-tags", "--resource-arn", arn)["Tags"]
        require(TAGS.items() <= actual_tags.items(), f"tags divergentes no banco {layer}")
        table = aws("glue", "get-table", "--database-name", database, "--name", table_name)["Table"]
        require(table["Parameters"]["classification"] == classification, f"formato incorreto em {layer}")
        require(table["PartitionKeys"] == [{"Name": "ano", "Type": "int", "Comment": table["PartitionKeys"][0].get("Comment", "")}],
                f"partição incorreta em {layer}")
        parts = aws("glue", "get-partitions", "--database-name", database,
                    "--table-name", table_name)["Partitions"]
        require({item["Values"][0] for item in parts} == {str(year) for year in config["years"]},
                f"partições incompletas em {layer}")
        require(database_data["Name"] == database, f"database ausente em {layer}")

    refined = aws("glue", "get-table", "--database-name", config["database_refined"],
                  "--name", config["table_refined"])["Table"]
    require(refined["Parameters"]["grao"] == "uma linha por UF e ano", "grão refined divergente")
    require(refined["Parameters"]["meta_custo"] ==
            f"até {config['query_target_bytes']} bytes por consulta anual", "meta de custo divergente")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.digest()


def objects():
    metrics = local_metrics()
    csv_dir = ROOT / "parte-1/dados"
    for item in metrics:
        year = item["ano"]
        raw_key = f"crime/ano={year}/BancoVDE_{year}.csv"
        raw = aws("s3api", "head-object", "--bucket", config["raw_bucket"], "--key", raw_key,
                  "--checksum-mode", "ENABLED", "--expected-bucket-owner", config["account"])
        local = csv_dir / f"BancoVDE_{year}.csv"
        require(raw["ContentLength"] == local.stat().st_size, f"tamanho raw divergente em {year}")
        require(raw.get("ChecksumSHA256") == base64.b64encode(sha256(local)).decode(),
                f"checksum raw divergente em {year}")

        for layer, bucket, prefix in (
            ("trusted", config["trusted_bucket"], f"crime_parquet/ano={year}/"),
            ("refined", config["refined_bucket"], f"homicidios_uf/ano={year}/"),
        ):
            listing = aws("s3api", "list-objects-v2", "--bucket", bucket, "--prefix", prefix)
            parquet = [obj for obj in listing.get("Contents", []) if obj["Key"].endswith(".parquet")]
            require(len(parquet) == 1 and parquet[0]["Size"] > 0,
                    f"{layer}/{year} deve possuir um Parquet não vazio")


def local_metrics():
    path = EVIDENCE / "metricas-parquet-local.json"
    require(path.is_file(), "métricas locais ausentes; execute preparar-local.sh")
    return json.loads(path.read_text())


def role_environment(role_arn):
    session = aws("sts", "assume-role", "--role-arn", role_arn,
                  "--role-session-name", "av2-aceite")["Credentials"]
    env = os.environ.copy()
    env.update(
        AWS_ACCESS_KEY_ID=session["AccessKeyId"],
        AWS_SECRET_ACCESS_KEY=session["SecretAccessKey"],
        AWS_SESSION_TOKEN=session["SessionToken"],
    )
    return env


def query(label, sql, env=None, expect_success=True):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    query_id = aws(
        "athena", "start-query-execution",
        "--work-group", config["workgroup"],
        "--query-string", sql,
        "--result-reuse-configuration", '{"ResultReuseByAgeConfiguration":{"Enabled":false}}',
        env=env,
    )["QueryExecutionId"]
    for _ in range(120):
        run = aws("athena", "get-query-execution", "--query-execution-id", query_id, env=env)["QueryExecution"]
        if run["Status"]["State"] in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(2)
    else:
        aws("athena", "stop-query-execution", "--query-execution-id", query_id, env=env)
        raise ValueError(f"timeout na consulta {query_id}")

    state = run["Status"]["State"]
    if expect_success:
        require(state == "SUCCEEDED", f"consulta {label} terminou em {state}: {run['Status']}")
    else:
        reason = json.dumps(run["Status"], ensure_ascii=False)
        require(state == "FAILED" and re.search(r"(permission|access denied|not authorized|lake formation)", reason, re.I),
                f"negação de {label} não foi causada por acesso: {reason}")
        return run, []

    data = aws("athena", "get-query-results", "--query-execution-id", query_id, env=env)["ResultSet"]["Rows"]
    cells = [[cell.get("VarCharValue", "") for cell in row["Data"]] for row in data]
    return run, [dict(zip(cells[0], values, strict=True)) for values in cells[1:]]


def current_snapshot():
    metrics = local_metrics()
    trusted_counts = {}
    refined_rows = []
    costs = []
    refined_sql = (PART / "consultas/homicidios_refined.sql").read_text()
    trusted_sql = (PART / "consultas/contagem_trusted.sql").read_text()
    try:
        price = Decimal(os.getenv("ATHENA_USD_POR_TB", "5"))
    except InvalidOperation as error:
        raise ValueError("ATHENA_USD_POR_TB deve ser numérico") from error
    require(price.is_finite() and price > 0, "tarifa do Athena inválida")

    for item in metrics:
        year = item["ano"]
        run, rows = query(
            f"trusted-{year}",
            trusted_sql.format(database=config["database_trusted"], table=config["table_trusted"], year=year),
        )
        require(rows == [{"ano": str(year), "linhas": str(item["linhas_trusted"])}],
                f"contagem trusted divergente em {year}")
        trusted_counts[str(year)] = int(rows[0]["linhas"])

        run, rows = query(
            f"refined-{year}",
            refined_sql.format(database=config["database_refined"], table=config["table_refined"], year=year),
        )
        scanned = run["Statistics"]["DataScannedInBytes"]
        require(0 < scanned <= config["query_target_bytes"],
                f"meta de custo excedida em {year}: {scanned} > {config['query_target_bytes']}")
        billed_mib = max(10, (scanned + MIB - 1) // MIB)
        costs.append({
            "ano": year,
            "query_execution_id": run["QueryExecutionId"],
            "bytes_lidos": scanned,
            "meta_bytes": config["query_target_bytes"],
            "usd_por_tb": str(price),
            "custo_estimado_usd": format(Decimal(billed_mib) * price / Decimal(2**20), ".9f"),
        })
        refined_rows.extend(rows)

    expected_path = EVIDENCE / "homicidios-refined-local.csv"
    with expected_path.open(encoding="utf-8") as stream:
        expected = list(csv.DictReader(stream))
    expected = [
        {"uf": row["uf"], "ano": row["ano"], "vitimas": row["vitimas"],
         "meses_informados": row["meses_informados"]}
        for row in expected
    ]
    require(refined_rows == expected, "resultado refined diverge da referência local")
    return {"trusted_counts": trusted_counts, "refined": refined_rows, "costs": costs}


def access_control():
    analyst = role_environment(config["role_analyst"])
    manager = role_environment(config["role_manager"])
    year = config["years"][0]
    checks = [
        ("analyst-trusted", analyst, config["database_trusted"], config["table_trusted"], True),
        ("analyst-refined", analyst, config["database_refined"], config["table_refined"], True),
        ("analyst-raw", analyst, config["database_raw"], config["table_raw"], False),
        ("manager-refined", manager, config["database_refined"], config["table_refined"], True),
        ("manager-trusted", manager, config["database_trusted"], config["table_trusted"], False),
        ("manager-raw", manager, config["database_raw"], config["table_raw"], False),
    ]
    results = []
    for label, env, database, table, allowed in checks:
        run, _ = query(label, f'SELECT count(*) AS linhas FROM "{database}"."{table}" WHERE ano = {year}',
                       env=env, expect_success=allowed)
        results.append({"teste": label, "esperado": "permitido" if allowed else "negado",
                        "estado": run["Status"]["State"], "id": run["QueryExecutionId"]})
    (EVIDENCE / "acesso-camadas.json").write_text(json.dumps(results, indent=2) + "\n")


def snapshot(name, compare):
    data = current_snapshot()
    path = EVIDENCE / f"snapshot-{name}.json"
    if compare:
        require(path.is_file(), f"snapshot {name} ausente")
        before = json.loads(path.read_text())
        require(before["trusted_counts"] == data["trusted_counts"], "reexecução alterou contagens da trusted")
        require(before["refined"] == data["refined"], "reexecução alterou o resultado refined")
    else:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    (EVIDENCE / "custos-av2.json").write_text(json.dumps(data["costs"], indent=2) + "\n")


def backend_free():
    items = aws("s3api", "list-objects-v2", "--bucket", config["state_bucket"]).get("Contents", [])
    allowed_key = "env:/av2/av2/crime/terraform.tfstate"
    for item in items:
        require(item["Key"] == allowed_key, f"backend contém chave imprevista: {item['Key']}")
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "state"
            aws("s3api", "get-object", "--bucket", config["state_bucket"], "--key", item["Key"], state)
            data = json.loads(state.read_text())
            require(not any(resource.get("instances") for resource in data.get("resources", [])
                            if resource.get("mode", "managed") == "managed"),
                    "backend ainda contém recursos ativos")
    locks = aws("dynamodb", "scan", "--table-name", config["lock_table"], "--consistent-read")
    allowed_lock = f"{config['state_bucket']}/{allowed_key}-md5"
    require(all(item["LockID"]["S"] == allowed_lock for item in locks["Items"]), "lock ativo no backend")


def absent(code, *command):
    try:
        aws(*command)
    except AwsError as error:
        if error.code == code:
            return
        raise
    raise ValueError(f"recurso ainda presente: {' '.join(command)}")


def destroyed():
    for bucket in (config["raw_bucket"], config["trusted_bucket"], config["refined_bucket"], config["state_bucket"]):
        absent("404", "s3api", "head-bucket", "--bucket", bucket,
               "--expected-bucket-owner", config["account"])
    for database in (config["database_raw"], config["database_trusted"], config["database_refined"]):
        absent("EntityNotFoundException", "glue", "get-database", "--name", database)
    absent("EntityNotFoundException", "dynamodb", "describe-table", "--table-name", config["lock_table"])
    workgroups = aws("athena", "list-work-groups")["WorkGroups"]
    require(config["workgroup"] not in {item["Name"] for item in workgroups}, "workgroup ainda presente")


def run_checks(checks):
    failures = 0
    for label, check in checks:
        try:
            check()
        except (AwsError, ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
            print(f"[FALHA] {label} — {error}")
            failures += 1
        else:
            print(f"[PASSA] {label}")
    return int(bool(failures))


def main():
    global config
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--confere-contexto", action="store_true")
    modes.add_argument("--backend-livre", action="store_true")
    modes.add_argument("--pos-destroy", action="store_true")
    modes.add_argument("--snapshot")
    modes.add_argument("--compare")
    args = parser.parse_args()

    inventory = ROOT / ".av2/inventario.json"
    require(inventory.is_file(), "inventário ausente; execute o deploy da AV2")
    config = json.loads(inventory.read_text())
    context()

    if args.confere_contexto:
        workspace()
        return 0
    if args.backend_livre:
        backend_free()
        return 0
    if args.pos_destroy:
        return run_checks([("ausência do lake e do backend", destroyed)])
    if args.snapshot:
        return run_checks([("métricas e custo", lambda: snapshot(args.snapshot, False))])
    if args.compare:
        return run_checks([("idempotência e resultado", lambda: snapshot(args.compare, True))])

    return run_checks([
        ("backend e workspace av2", workspace),
        ("catálogo, formatos, partições, contratos e tags", catalog),
        ("arquivos raw e um Parquet por partição", objects),
        ("resultado analítico e meta de custo", lambda: snapshot("aceite", False)),
        ("permissão por camada via Lake Formation", access_control),
    ])


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (AwsError, ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        sys.exit(f"[FALHA] {error}")
