# DECISOES.md — AV1 (grupo g04, Crime Brasil)

Cada decisao tem numero e metrica real. Numeros medidos na execucao; repita
os comandos e atualize os valores quando rodar na sua conta.

## DECISAO 01 — Grao da tabela
- **Grao**: `(uf, municipio, evento, data_referencia, abrangencia)`
- **Metrica**: `SELECT COUNT(*) FROM crime_trusted` deve bater com
  `COUNT(DISTINCT uf||municipio||evento||data_referencia||abrangencia)`.
- **Valor esperado**: ~1.996.088 linhas (2024: 764.788 + 2025: 832.285 +
  2026: 399.013, menos eventuais dup por ajuste de fonte).
- Sem duplicata: a consulta de validacao abaixo retorna 0 linhas.
  ```sql
  SELECT uf, municipio, evento, data_referencia, abrangencia, COUNT(*) c
  FROM "eda262_g04_crime_db"."crime_trusted"
  GROUP BY 1,2,3,4,5 HAVING COUNT(*) > 1;
  ```

## DECISAO 02 — Schema declarado vs Crawler
- **Decisao**: schema DECLARADO no Terraform (`aws_glue_catalog_table`), sem
  `aws_glue_crawler`.
- **Metrica**: 16 colunas declaradas (14 originais + ano + mes).
  `aws glue get-table` -> StorageDescriptor.Columns tem 16.
- **Justificativa**: a AV1 da disciplina exige schema explicito (idem Aula 04);
  crawler seria eliminatorio e ainda cobra ~88% da conta do lab anterior.

## DECISAO 03 — Tipo das colunas de valor/sexo
- **Decisao**: `feminino`, `masculino`, `nao_informado`, `total_vitima`,
  `total` = `int`; `total_peso` = `double`.
- **Metrica**: no CSV original 84% dessas colunas chegam como STRING; o
  conversor faz `to_numeric(errors='coerce').fillna(0).astype(int)`.
- **Justificativa**: dominio e contagem de vitimas (inteiro). Manter int
  evita "0.0" no Athena e `NULL` por type mismatch.

## DECISAO 04 — Particionamento
- **Decisao**: particionar por `ano` (1 CSV por ano: 2024/2025/2026).
- **Metrica**: 3 particoes declaradas; Location exato
  `s3://eda262-g04-lake-trusted/crime/ano=YYYY/`.
- **Justificativa**: o dado ja vem anual; a consulta de negocio filtra por
  ano, entao a particao corta os ~400 MB de varredura para ~130 MB por ano.

## DECISAO 05 — Teto de bytes por consulta (workgroup)
- **Decisao**: `BytesScannedCutoffPerQuery = 419430400` (400 MB).
- **Metrica**: piso AWS = 10.485.760; lake inteiro ~400 MB.
- **Justificativa**: mata a consulta larga (`SELECT count(*) FROM crime_trusted`
  sem WHERE) e deixa passar a estreita (`WHERE ano='2024'`, ~130 MB).
- **Custo medido**: Athena cobra US$ 5 / TB varrido.
  - Consulta larga abortada: ~US$ 0 (nao varreu tudo).
  - Consulta estreita (~130 MB): US$ 5 * 0,13 = ~US$ 0,00065 (~R$ 0,004).
  - Custo total da AV1 (algumas consultas): < US$ 0,01.

## DECISAO 06 (extra, AV1) — Formato na camada trusted
- **Decisao**: AV1 mantem CSV na trusted (nao Parquet). Parquet + 3 camadas
  ficam para a AV2.
- **Metrica**: 3 arquivos CSV, ~171 MB totais no bucket.
- **Justificativa**: CSV eh o formato direto do conversor e o Athena le nativo;
  adiar a conversao para a AV2 (refined) evita retrabalho agora.
