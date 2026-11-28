"""Gera e valida localmente as partições Parquet da AV2."""

import argparse
import csv
import hashlib
import json
from pathlib import Path

import pandas as pd


YEARS = (2024, 2025, 2026)
COUNT_COLUMNS = ["feminino", "masculino", "nao_informado", "total_vitima", "total"]
NULL_TOKEN = "~"


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def read_raw(path, year):
    frame = pd.read_csv(
        path,
        quoting=csv.QUOTE_NONE,
        escapechar="\\",
        na_values=[NULL_TOKEN],
        keep_default_na=False,
        low_memory=False,
        parse_dates=["data_referencia"],
    )
    if frame["data_referencia"].isna().any() or set(frame["data_referencia"].dt.year) != {year}:
        raise ValueError(f"datas inválidas na partição {year}")
    if not frame["mes"].between(1, 12).all():
        raise ValueError(f"meses inválidos na partição {year}")
    for column in COUNT_COLUMNS:
        frame[column] = frame[column].astype("Int32")
    frame["mes"] = frame["mes"].astype("Int8")
    return frame


def refined(frame, year):
    selected = frame[
        (frame["evento"] == "Homicídio doloso")
        & (frame["abrangencia"] == "Estadual")
    ]
    result = (
        selected.groupby("uf", as_index=False)
        .agg(
            vitimas=("total_vitima", lambda values: values.sum(min_count=1)),
            meses_informados=("mes", lambda values: values[selected.loc[values.index, "total_vitima"].notna()].nunique()),
        )
        .sort_values("uf")
    )
    if len(result) != 27:
        raise ValueError(f"{year} deveria produzir 27 UFs, produziu {len(result)}")
    result["vitimas"] = result["vitimas"].astype("Int64")
    result["meses_informados"] = result["meses_informados"].astype("Int64")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    report = []
    all_refined = []

    for year in YEARS:
        source = args.csv_dir / f"BancoVDE_{year}.csv"
        frame = read_raw(source, year)
        result = refined(frame, year)
        trusted_path = args.output_dir / "trusted" / f"ano={year}" / "crime.parquet"
        refined_path = args.output_dir / "refined" / f"ano={year}" / "homicidios_uf.parquet"
        trusted_path.parent.mkdir(parents=True, exist_ok=True)
        refined_path.parent.mkdir(parents=True, exist_ok=True)
        frame.to_parquet(trusted_path, index=False, compression="snappy")
        result.to_parquet(refined_path, index=False, compression="snappy")
        all_refined.append(result.assign(ano=year))
        report.append({
            "ano": year,
            "linhas_raw": len(frame),
            "linhas_trusted": len(pd.read_parquet(trusted_path)),
            "linhas_refined": len(pd.read_parquet(refined_path)),
            "bytes_csv": source.stat().st_size,
            "bytes_trusted": trusted_path.stat().st_size,
            "bytes_refined": refined_path.stat().st_size,
            "sha256_csv": sha256(source),
            "sha256_trusted": sha256(trusted_path),
            "sha256_refined": sha256(refined_path),
            "vitimas": int(result["vitimas"].sum()),
        })

    pd.concat(all_refined).to_csv(args.evidence_dir / "homicidios-refined-local.csv", index=False)
    (args.evidence_dir / "metricas-parquet-local.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
