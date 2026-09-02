# Crime-data-engineering-project

Projeto de Engenharia de Dados (CESAR School, 2026.2) — grupo g04.
Data Lake incremental na AWS, do zero, 100% infraestrutura como codigo.

## Estrutura

```
.
├── aula-04/                 # Exercicio individual Aula 04 — CloudFormation, dataset "corridas" (JSON, schema declarado sem crawler)
│   ├── template.yaml        # stack: bucket + Glue DB/tabela + Athena WG + particoes por dia
│   ├── verifica.sh          # PASSA/FALHA por criterio da rubrica da aula
│   ├── deploy.sh            # sobe a stack
│   ├── destroy.sh           # derruba e confere orfaos
│   ├── parameters.json      # Turma/Owner/Teto — PREENCHA O TETO
│   └── amostra-corridas.jsonl
│
└── av1/                     # AV1 do GRUPO — Terraform, dataset BancoVDE / Crime (CSV, sem crawler)
    ├── terraform/           # provider / backend remoto / variables / main / locals / outputs / tfvars
    │   ├── bootstrap.sh     # cria o backend remoto (S3 + DynamoDB lock) 1x
    │   ├── deploy.sh        # terraform init + apply
    │   └── destroy.sh       # terraform destroy + esvazia bucket
    ├── dados/               # CSVs ja convertidos (1 por ano) + converter_xlsx_para_csv.py
    ├── data/raw/            # XLSX originais do BancoVDE (read-only)
    ├── verificacao/
    │   ├── verifica.sh      # PASSA/FALHA da AV1 (sem crawler, 16 colunas, particao ano, teto)
    │   └── ingest.sh        # sobe os CSVs pro S3 trusted (1 por particao)
    ├── apresentacao/        # slide da defesa (PDF)
    └── DECISOES.md          # 6 decisoes numeradas com metricas
```

## AV1 (grupo g04) — como rodar

1. Preparar backend remoto (1x):
   ```bash
   cd av1/terraform && ./bootstrap.sh
   ```
2. Aplicar a infra (bucket trusted, Glue DB/tabela crime_trusted, Athena WG):
   ```bash
   ./deploy.sh
   ```
3. Subir os dados pro S3 (1 CSV por particao de ano):
   ```bash
   cd ../verificacao && ./ingest.sh
   ```
4. Conferir tudo (rubrica):
   ```bash
   ./verifica.sh
   ```
5. Consulta de negocio (tendencia de homicidios por UF/ano), workgroup `eda262-g04-crime-wg`:
   ```sql
   SELECT uf, ano, SUM(total_vitima) AS homicidios
   FROM "eda262_g04_crime_db"."crime_trusted"
   WHERE evento ILIKE '%Homicidio%' AND evento NOT ILIKE '%Tentativa%'
   GROUP BY uf, ano ORDER BY uf, ano;
   ```
6. Destruir limpo (criterio 5):
   ```bash
   cd ../terraform && ./destroy.sh && cd ../verificacao && ./verifica.sh --pos-destroy
   ```

**ONTEM**: `terraform` e `aws cli` configurados com credenciais da conta da
disciplina. Sem crawler (schema declarado). State nunca vai pro git.

## Aula 04 (individual) — como rodar

```bash
cd aula-04
# 1) preencher TetoBytesPorConsulta em parameters.json (hoje esta "???")
# 2) completar os 4 placeholders no template.yaml (tipo de valor/tempo + ignore.malformed)
./deploy.sh <seu-login>
./verifica.sh <seu-login>
./destroy.sh <seu-login>
```
