# Crime Brasil · Engenharia de Dados

Projeto do grupo g04 para a CESAR School, semestre 2026.2. A pergunta analítica é quantas vítimas de homicídio doloso foram informadas por UF e ano na abrangência Estadual do BancoVDE.

- `parte-1/` mantém a AV1 em CSV e o histórico do custo original.
- `parte-2/` implementa raw, trusted e refined, Parquet particionado, idempotência, backfill e Lake Formation.
- `DECISOES.md` reúne as decisões e medições.
- `evidencias/` contém resultados locais e AWS, IDs de consulta, custos, jobs e o aceite.

O caminho `av1/` é um alias compatível para `parte-1/`.

## Preparar os dados

Execute a partir de `Crime-data-engineering-project/` com Python 3.10 ou superior.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r parte-2/requirements.txt
./parte-1/dados/baixar.sh
python parte-1/dados/converter_xlsx_para_csv.py --overwrite
python parte-2/dados/pipeline_local.py \
  --csv-dir parte-1/dados \
  --output-dir parte-2/data \
  --evidence-dir evidencias
```

O download valida os hashes de `parte-1/dados/originais.sha256`. O marcador `~` representa ausência nos CSVs. O conversor rejeita esse valor se ele aparecer literalmente na fonte, valida tipos e datas e publica cada arquivo por substituição atômica.

## Provisionar a AV2

Pré-requisitos são Terraform 1.5 ou superior, AWS CLI v2 e credenciais para S3, DynamoDB, Glue, Athena, IAM, STS e Lake Formation em `us-east-1`.

```bash
export AWS_REGION=us-east-1
aws sts get-caller-identity
./parte-2/terraform/bootstrap.sh -auto-approve
./parte-2/terraform/deploy.sh -auto-approve
```

O bootstrap cria o backend remoto exclusivo da AV2. O deploy seleciona o workspace `av2`, aplica o módulo `modules/platform` e grava `.av2/inventario.json` para o aceite. Na conta do grupo, o bucket trusted foi migrado uma vez do state da AV1 para o da AV2 sem apagar seus CSVs. `import_existing_trusted_bucket` permanece `false`, então a entrega provisiona os recursos normalmente em uma conta limpa.

## Executar ingestão, idempotência e backfill

```bash
./parte-2/ingest.sh

./parte-2/job.sh 2024,2025,2026
python parte-2/verificacao/aceite.py --snapshot primeira

./parte-2/job.sh 2024,2025,2026
python parte-2/verificacao/aceite.py --compare primeira

./parte-2/job.sh 2024
python parte-2/verificacao/aceite.py --compare primeira
```

O atalho `./parte-2/executar.sh` executa essa sequência. O job substitui somente os anos informados. A raw usa `s3://eda262-g04-lake-raw/crime/ano=AAAA/`, a trusted escreve em `s3://eda262-g04-lake-trusted/crime_parquet/ano=AAAA/` e a refined escreve em `s3://eda262-g04-lake-refined/homicidios_uf/ano=AAAA/`.

## Verificar

```bash
./verificacao/verifica.sh
```

O aceite confere workspace, backend, tags, catálogo, schema, formatos, partições, checksums da raw e um Parquet corrente por partição. Depois compara as contagens trusted e os resultados refined com a referência local, mede bytes e custo e assume os papéis `analyst` e `manager` para provar permissões e negações por camada.

Medições finais de 27/11/2026:

- 2.290.260 linhas na trusted e 81 linhas na refined.
- 370, 378 e 376 bytes lidos nas consultas refined anuais.
- Meta de 1 MiB cumprida nos três anos.
- Reexecução completa e backfill de 2024 sem mudança de contagens ou resultados.
- Analyst permitido em trusted/refined e negado em raw.
- Manager permitido em refined e negado em trusted/raw.

## Destruir depois da apresentação

```bash
./parte-2/terraform/destroy.sh -auto-approve
./parte-2/verificacao/verifica.sh --pos-destroy
```

O destroy remove os buckets versionados, catálogos, job, workgroup, papéis, permissões e o backend dedicado. Como o bucket trusted é compartilhado com a AV1, sua remoção encerra também a consulta histórica em CSV. A infraestrutura foi mantida ativa para a apresentação e a prova destrutiva deve ser executada ao final dela.

## Entrega

O PDF `apresentacao-parte-2-g04.pdf` e o roteiro em `parte-2/apresentacao/roteiro.md` usam as medições desta execução. A entrega oficial deve usar o repositório `eda262-projeto-g04`, branch `main` e tag `av2-entrega`.
