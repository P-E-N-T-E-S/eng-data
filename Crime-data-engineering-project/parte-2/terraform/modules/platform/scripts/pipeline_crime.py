"""Transforma as partições anuais do BancoVDE em trusted e refined Parquet."""

import json
import sys
from datetime import datetime, timezone

import boto3
from awsglue.context import GlueContext
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql import types as T


args = getResolvedOptions(
    sys.argv,
    ["RAW_BUCKET", "TRUSTED_BUCKET", "REFINED_BUCKET", "YEARS"],
)
raw_bucket = args["RAW_BUCKET"]
trusted_bucket = args["TRUSTED_BUCKET"]
refined_bucket = args["REFINED_BUCKET"]
years = [year.strip() for year in args["YEARS"].split(",") if year.strip()]

if not years or any(len(year) != 4 or not year.isdigit() for year in years):
    raise ValueError("YEARS deve conter ao menos um ano no formato AAAA")

physical_columns = [
    "uf", "municipio", "evento", "data_referencia", "agente", "arma",
    "faixa_etaria", "feminino", "masculino", "nao_informado",
    "total_vitima", "total", "total_peso", "abrangencia", "mes",
]

raw_schema = T.StructType([
    T.StructField("uf", T.StringType()),
    T.StructField("municipio", T.StringType()),
    T.StructField("evento", T.StringType()),
    T.StructField("data_referencia", T.StringType()),
    T.StructField("agente", T.StringType()),
    T.StructField("arma", T.StringType()),
    T.StructField("faixa_etaria", T.StringType()),
    T.StructField("feminino", T.StringType()),
    T.StructField("masculino", T.StringType()),
    T.StructField("nao_informado", T.StringType()),
    T.StructField("total_vitima", T.StringType()),
    T.StructField("total", T.StringType()),
    T.StructField("total_peso", T.StringType()),
    T.StructField("abrangencia", T.StringType()),
    T.StructField("mes", T.StringType()),
])

spark = GlueContext(SparkContext.getOrCreate()).spark_session
spark.conf.set("spark.sql.session.timeZone", "UTC")


def parse_partition(year):
    source = f"s3://{raw_bucket}/crime/ano={year}/"
    raw = (
        spark.read.schema(raw_schema)
        .option("header", "true")
        .option("sep", ",")
        .option("escape", "\\")
        .option("nullValue", "~")
        .csv(source)
    )

    typed = raw.select(
        "uf", "municipio", "evento",
        F.to_date("data_referencia", "yyyy-MM-dd").alias("data_referencia"),
        "agente", "arma", "faixa_etaria",
        F.col("feminino").cast("int").alias("feminino"),
        F.col("masculino").cast("int").alias("masculino"),
        F.col("nao_informado").cast("int").alias("nao_informado"),
        F.col("total_vitima").cast("int").alias("total_vitima"),
        F.col("total").cast("int").alias("total"),
        F.col("total_peso").cast("double").alias("total_peso"),
        "abrangencia",
        F.col("mes").cast("int").alias("mes"),
    )

    invalid = typed.filter(
        F.col("data_referencia").isNull()
        | (F.year("data_referencia") != int(year))
        | ~F.col("mes").between(1, 12)
    ).limit(1).count()
    if invalid:
        raise ValueError(f"partição {year} contém data ou mês inválido")

    return typed.cache()


reports = []
for year in years:
    trusted = parse_partition(year)
    trusted_count = trusted.count()
    if trusted_count == 0:
        raise ValueError(f"partição {year} está vazia")

    refined = (
        trusted.filter(
            (F.col("evento") == "Homicídio doloso")
            & (F.col("abrangencia") == "Estadual")
        )
        .groupBy("uf")
        .agg(
            F.sum("total_vitima").cast("long").alias("vitimas"),
            F.countDistinct(
                F.when(F.col("total_vitima").isNotNull(), F.col("mes"))
            ).cast("long").alias("meses_informados"),
        )
        .orderBy("uf")
        .cache()
    )
    refined_count = refined.count()
    if refined_count != 27:
        raise ValueError(f"partição {year} deveria conter 27 UFs, contém {refined_count}")

    # Cada execução substitui somente as partições solicitadas. Uma nova execução
    # recupera uma tentativa interrompida e não acrescenta linhas aos anos existentes.
    trusted.coalesce(1).write.mode("overwrite").option("compression", "snappy").parquet(
        f"s3://{trusted_bucket}/crime_parquet/ano={year}/"
    )
    refined.coalesce(1).write.mode("overwrite").option("compression", "snappy").parquet(
        f"s3://{refined_bucket}/homicidios_uf/ano={year}/"
    )

    reports.append({
        "ano": int(year),
        "linhas_trusted": trusted_count,
        "linhas_refined": refined_count,
        "vitimas": refined.agg(F.sum("vitimas")).first()[0],
    })
    trusted.unpersist()
    refined.unpersist()

report = {
    "executado_em": datetime.now(timezone.utc).isoformat(),
    "anos": years,
    "particoes": reports,
    "modo": "overwrite da partição anual",
}
boto3.client("s3").put_object(
    Bucket=raw_bucket,
    Key="relatorios/pipeline-ultimo.json",
    Body=(json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    ContentType="application/json",
)
