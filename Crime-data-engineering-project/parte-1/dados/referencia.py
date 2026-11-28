"""Reconcilia CSVs locais com a mesma medida de negócio definida para o Athena."""
import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

YEARS = (2024, 2025, 2026)
NULL_TOKEN = "~"


def summarize(path, year):
    totals = Counter()
    months = defaultdict(set)
    scopes = Counter()
    rows = 0
    with path.open(encoding="utf-8", newline="") as stream:
        records = csv.DictReader(stream, quoting=csv.QUOTE_NONE, escapechar="\\")
        for record in records:
            rows += 1
            if record["evento"] != "Homicídio doloso":
                continue
            scope = record["abrangencia"]
            scopes[scope] += 1
            if scope == "Estadual":
                uf = record["uf"]
                months[uf]  # Incluir UF mesmo quando todas as contagens são nulas.
                if record["total_vitima"] != NULL_TOKEN:
                    totals[uf] += int(record["total_vitima"])
                    months[uf].add(int(record["mes"]))
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    if not months:
        raise ValueError(f"{year} sem registros estaduais de homicídio doloso")
    answers = [{"uf": uf, "ano": year, "vitimas": totals[uf] if months[uf] else None,
                "meses_informados": len(months[uf])} for uf in sorted(months)]
    return {"ano": year, "linhas": rows, "bytes": path.stat().st_size, "sha256": digest.hexdigest(),
            "linhas_homicidio_por_abrangencia": dict(sorted(scopes.items()))}, answers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dados", type=Path)
    parser.add_argument("destino", type=Path)
    args = parser.parse_args()
    volumes, results = [], []
    for year in YEARS:
        volume, answers = summarize(args.dados / f"BancoVDE_{year}.csv", year)
        volumes.append(volume)
        results.extend(answers)
    args.destino.mkdir(exist_ok=True, parents=True)
    (args.destino / "volumes-local.json").write_text(json.dumps(volumes, indent=2, ensure_ascii=False) + "\n")
    with (args.destino / "homicidios-local.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=results[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(results)


if __name__ == "__main__":
    main()
