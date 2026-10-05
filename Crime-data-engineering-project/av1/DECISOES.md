# DECISOES.md — AV1 (grupo g04, Crime Brasil)

Cada decisao tem numero e metrica real. Numeros medidos na execucao; repita
os comandos e atualize os valores quando rodar na sua conta.

## DECISAO 01 — Grao da tabela
- **Grao**: um registro da fonte BancoVDE. A combinacao
  `(uf, municipio, evento, data_referencia, abrangencia)` descreve o contexto
  de negocio, mas nao e uma chave unica do dado de origem.
- **Metrica**: preservar as 1.996.085 linhas convertidas (2024: 764.788;
  2025: 832.285; 2026: 399.012), sem deduplicacao arbitraria.
- **Valor medido na conversao**: 1.996.085 linhas (2024: 764.788; 2025:
  832.285; 2026: 399.012).
- **Validacao (2026-09-23)**: a consulta abaixo encontrou grupos repetidos em
  cada ano; por exemplo, no DF, "Tentativa de feminicídio", agosto/2024,
  abrangencia Estadual aparece 33 vezes. Algumas linhas sao identicas em todas
  as colunas expostas pela fonte, portanto nao ha chave natural suficiente.
- **Tratamento**: a AV1 preserva os registros como recebidos. A AV2 avaliara
  uma chave tecnica de origem e uma regra de deduplicacao somente depois de
  validar a semantica da fonte.
  ```sql
  SELECT uf, municipio, evento, data_referencia, abrangencia, COUNT(*) c
  FROM "eda262_g04_crime_db"."crime_trusted"
  WHERE ano = 2024
  GROUP BY 1,2,3,4,5 HAVING COUNT(*) > 1;
  ```

## DECISAO 02 — Schema declarado vs Crawler
- **Decisao**: schema DECLARADO no Terraform (`aws_glue_catalog_table`), sem
  `aws_glue_crawler`.
- **Metrica observada**: 16 colunas logicas: 15 fisicas no CSV (14 originais
  + `mes`) e a particao `ano`. A tabela no Glue exibiu 15 colunas em
  `StorageDescriptor.Columns` e uma `PartitionKey` chamada `ano`.
- **Justificativa**: a AV1 da disciplina exige schema explicito (idem Aula 04);
  crawler seria eliminatorio e ainda cobra ~88% da conta do lab anterior.
- **Evidências**: capturas de schema e Glue sem Crawler foram compartilhadas
  separadamente com a equipe e não entram no Git.

## DECISAO 03 — Tipo das colunas de valor/sexo
- **Decisao**: `feminino`, `masculino`, `nao_informado`, `total_vitima`,
  `total` = `int`; `total_peso` = `double`.
- **Metrica**: o conversor valida que os valores de contagem sao inteiros e
  preserva ausencias como `\\N`, que o SerDe interpreta como `NULL`.
- **Justificativa**: dominio e contagem de vitimas (inteiro). Manter int
  evita "0.0" no Athena e `NULL` por type mismatch.

## DECISAO 04 — Particionamento
- **Decisao**: particionar por `ano` (1 CSV por ano: 2024/2025/2026).
- **Metrica observada**: 3 particoes verificadas no S3 e no Glue, com Location
  `s3://eda262-g04-lake-trusted/crime/ano=YYYY/`.
- **Justificativa**: o dado ja vem anual; a consulta de negocio filtra por
  ano, entao a particao reduz a leitura de 177,6 MiB para no maximo 74,3 MiB
  antes de considerar a sobrecarga do Athena.
- **Evidências**: capturas do bucket e das partições foram compartilhadas
  separadamente com a equipe e não entram no Git.

## DECISAO 05 — Teto de bytes por consulta (workgroup)
- **Decisao**: `BytesScannedCutoffPerQuery = 104857600` (100 MiB).
- **Metrica**: CSVs medidos na conversao: 2024 = 71.166.285 bytes (67,9 MiB),
  2025 = 77.948.744 bytes (74,3 MiB), 2026 = 37.141.916 bytes (35,4 MiB);
  total = 186.256.945 bytes (177,6 MiB). O teto fica acima da maior particao e
  abaixo da leitura completa.
- **Justificativa**: a consulta larga (`SELECT count(*) FROM crime_trusted`
  sem WHERE) deve ser cancelada, enquanto a estreita (`WHERE ano = 2024`) deve passar.
- **Evidencia observada (2026-09-23)**: a consulta de negocio sem filtro de
  `ano` atingiu o limite do workgroup (100,00 MB). Portanto, a evidencia final
  usou somente a particao de 2024 e leu **67,87 MB**.
- **Evidências**: capturas da configuração, execução e resultado da query foram
  compartilhadas separadamente com a equipe e não entram no Git.
- **Nota**: 67,87 MB e a quantidade de dados lidos, nao um custo financeiro.
  A AV1 usa essa metrica para demonstrar a eficacia do particionamento.

## DECISAO 06 (extra, AV1) — Formato na camada trusted
- **Decisao**: AV1 mantem CSV na trusted (nao Parquet). Parquet + 3 camadas
  ficam para a AV2.
- **Metrica**: 3 arquivos CSV, 177,6 MiB totais antes do upload.
- **Justificativa**: CSV eh o formato direto do conversor e o Athena le nativo;
  adiar a conversao para a AV2 (refined) evita retrabalho agora.

## DECISAO 07 (extra, AV1) — Destruicao limpa
- **Decisao**: usar `force_destroy = true` no workgroup Athena e executar o
  `destroy.sh`, que esvazia objetos, versoes e delete markers do bucket antes
  do `terraform destroy`.
- **Metrica observada**: o `verifica.sh --pos-destroy` confirmou a ausencia de
  recursos orfaos apos a destruicao.
- **Justificativa**: historico de queries impede excluir um workgroup Athena
  sem exclusao recursiva; o bucket precisa estar vazio para o Terraform removê-lo.
- **Evidência**: captura do destroy e da verificação pós-destruição foi
  compartilhada separadamente com a equipe e não entra no Git.
