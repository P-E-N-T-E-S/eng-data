#!/usr/bin/env python3
"""Converte o BancoVDE bruto em CSVs prontos para a tabela trusted da AV1.

Cada arquivo de saída contém as 14 colunas de origem e ``mes``. ``ano`` não é
gravado no CSV: ele é fornecido pela partição Hive ``ano=YYYY`` no S3.
"""

from __future__ import annotations

import argparse
import csv
import sys
from tempfile import NamedTemporaryFile
from pathlib import Path

import pandas as pd


SOURCE_COLUMNS = [
    "uf",
    "municipio",
    "evento",
    "data_referencia",
    "agente",
    "arma",
    "faixa_etaria",
    "feminino",
    "masculino",
    "nao_informado",
    "total_vitima",
    "total",
    "total_peso",
    "abrangencia",
]

INTEGER_COLUMNS = [
    "feminino",
    "masculino",
    "nao_informado",
    "total_vitima",
    "total",
]
NULL_TOKEN = "~"


def parse_args() -> argparse.Namespace:
    base_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--raw-dir",
        type=Path,
        default=base_dir.parent / "data" / "raw",
        help="Diretório somente leitura com os XLSX originais.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=base_dir,
        help="Diretório dos CSVs anuais gerados.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Permite substituir CSVs de saída existentes.",
    )
    parser.add_argument(
        "--years",
        nargs="+",
        type=int,
        choices=(2024, 2025, 2026),
        default=(2024, 2025, 2026),
        help="Anos a converter; por padrão converte todos.",
    )
    return parser.parse_args()


def as_nullable_integer(frame: pd.DataFrame, column: str) -> None:
    values = pd.to_numeric(frame[column], errors="raise")
    non_integral = values.notna() & values.mod(1).ne(0)
    if non_integral.any():
        examples = values[non_integral].head(5).tolist()
        raise ValueError(f"{column} contém valores não inteiros: {examples}")
    frame[column] = values.astype("Int64")


def convert_year(source: Path, year: int, output: Path, overwrite: bool) -> tuple[int, int]:
    if output.exists() and not overwrite:
        raise FileExistsError(f"{output} já existe; use --overwrite para substituí-lo.")

    frame = pd.read_excel(source, engine="calamine", keep_default_na=False, na_values=[""])
    if list(frame.columns) != SOURCE_COLUMNS:
        raise ValueError(
            f"Schema inesperado em {source.name}: {list(frame.columns)}; "
            f"esperado: {SOURCE_COLUMNS}"
        )

    dates = pd.to_datetime(frame["data_referencia"], errors="coerce")
    if dates.isna().any():
        raise ValueError(
            f"{source.name} tem {dates.isna().sum()} data(s) inválida(s) em data_referencia."
        )
    unexpected_years = sorted(dates.dt.year.dropna().unique().tolist())
    if unexpected_years != [year]:
        raise ValueError(
            f"{source.name} deveria conter apenas {year}, mas contém {unexpected_years}."
        )

    frame["data_referencia"] = dates.dt.strftime("%Y-%m-%d")
    for column in INTEGER_COLUMNS:
        as_nullable_integer(frame, column)
    frame["total_peso"] = pd.to_numeric(frame["total_peso"], errors="raise").astype("Float64")
    frame["mes"] = dates.dt.month.astype("Int64")

    output.parent.mkdir(parents=True, exist_ok=True)
    # LazySimpleSerDe lê uma linha física por evento. QUOTE_NONE produz o mesmo
    # contrato: vírgulas e barras literais são escapadas com barra invertida.
    text_columns = ("uf", "municipio", "evento", "agente", "arma", "faixa_etaria", "abrangencia")
    for column in text_columns:
        values = frame[column].astype("string")
        if values.str.contains(r"[\r\n]", regex=True).any():
            raise ValueError(f"{column} contém quebra de linha incompatível com o SerDe")

    if frame[list(text_columns)].astype("string").eq(NULL_TOKEN).any().any():
        raise ValueError("a fonte contém o marcador interno de NULL")

    with NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent, delete=False) as temp:
        temp_path = Path(temp.name)
        try:
            frame.to_csv(
                temp,
                columns=[*SOURCE_COLUMNS, "mes"],
                index=False,
                encoding="utf-8",
                na_rep=NULL_TOKEN,
                lineterminator="\n",
                quoting=csv.QUOTE_NONE,
                escapechar="\\",
            )
            temp.flush()
            temp_path.replace(output)
        finally:
            temp_path.unlink(missing_ok=True)
    return len(frame), output.stat().st_size


def main() -> int:
    args = parse_args()
    files = {year: args.raw_dir / f"BancoVDE {year}.xlsx" for year in args.years}
    missing = [str(path) for path in files.values() if not path.is_file()]
    if missing:
        print("Arquivos brutos ausentes:\n- " + "\n- ".join(missing), file=sys.stderr)
        return 1

    total_rows = 0
    total_bytes = 0
    for year, source in files.items():
        output = args.output_dir / f"BancoVDE_{year}.csv"
        rows, size = convert_year(source, year, output, args.overwrite)
        total_rows += rows
        total_bytes += size
        print(f"{source.name} -> {output}: {rows:,} linhas, {size / 1024 / 1024:.1f} MiB")

    print(f"Total: {total_rows:,} linhas, {total_bytes / 1024 / 1024:.1f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
