# Crime-data-engineering-project

Projeto de Engenharia de Dados (CESAR School, 2026.2) — grupo g04.
Data Lake incremental na AWS, do zero, 100% infraestrutura como codigo.

## Estrutura

```
.
├── .gitignore               # ignora dados gerados e state local
└── av1/                     # AV1 do GRUPO — Terraform, dataset BancoVDE / Crime (CSV, sem crawler)
    ├── terraform/           # provider / backend remoto / variables / main / locals / outputs / tfvars
    │   ├── bootstrap.sh     # cria o backend remoto (S3 + DynamoDB lock) 1x
    │   ├── deploy.sh        # terraform init + apply
    │   └── destroy.sh       # terraform destroy + esvazia bucket
    ├── dados/               # conversor + CSVs gerados (1 por ano, ignorados pelo Git)
    ├── data/raw/            # XLSX originais do BancoVDE (read-only)
    ├── requirements.txt     # dependencias do conversor
    ├── verificacao/
    │   ├── verifica.sh      # PASSA/FALHA da AV1 (sem crawler, 16 colunas, particao ano, teto)
    │   └── ingest.sh        # sobe os CSVs pro S3 trusted (1 por particao)
    ├── apresentacao/        # slide da defesa (PDF)
    └── DECISOES.md          # 6 decisoes numeradas com metricas
```

## AV1 (grupo g04)

### Pré-requisitos

- Python 3.9+;
- Terraform 1.5+;
- AWS CLI autenticada na conta do grupo, na região `us-east-1`.

### Preparar os dados

Os XLSX originais ficam em `av1/data/raw/` e não devem ser alterados. Gere os
CSVs antes de provisionar ou ingerir:

```bash
python3 -m venv .venv
.venv/bin/pip install -r av1/requirements.txt
.venv/bin/python av1/dados/converter_xlsx_para_csv.py
```

O conversor produz um CSV UTF-8 por ano, com 14 colunas de origem e `mes`.
`ano` não é gravado no arquivo: é fornecido exclusivamente pela partição S3
`ano=YYYY`.

| Ano | Linhas | Tamanho |
| --- | ---: | ---: |
| 2024 | 764.788 | 67,9 MiB |
| 2025 | 832.285 | 74,3 MiB |
| 2026 | 399.012 | 35,4 MiB |

### Provisionar e verificar

1. Preparar o backend remoto (uma vez):

   ```bash
   cd av1/terraform && ./bootstrap.sh
   ```

2. Aplicar a infraestrutura — bucket trusted, Glue Database/tabela
   `crime_trusted` e workgroup Athena:

   ```bash
   ./deploy.sh
   ```

3. Subir um CSV para cada partição anual:

   ```bash
   cd ../verificacao && ./ingest.sh
   ```

4. Conferir os critérios da rubrica:

   ```bash
   ./verifica.sh
   ```

5. Executar a consulta de negócio no workgroup `eda262-g04-crime-wg`:

   ```sql
   SELECT uf, ano, SUM(total_vitima) AS homicidios
   FROM "eda262_g04_crime_db"."crime_trusted"
   WHERE evento = 'Homicídio doloso'
   GROUP BY uf, ano ORDER BY uf, ano;
   ```

6. Registrar o custo real no Athena e atualizar `av1/DECISOES.md`.

7. Para comprovar o destroy limpo:

   ```bash
   cd ../terraform && ./destroy.sh && cd ../verificacao && ./verifica.sh --pos-destroy
   ```

### Decisões implementadas

- Schema declarado: 15 colunas físicas no CSV + partição `ano` = 16 colunas
  lógicas, sem Glue Crawler.
- Teto do Athena: 100 MiB. Uma partição anual cabe no limite; a leitura de todo
  o lake (177,6 MiB) deve ser cancelada pelo workgroup.
- O workgroup usa exclusão recursiva no Terraform para remover seu histórico de
  consultas; o `destroy.sh` remove objetos, versões e delete markers do bucket
  antes de executar `terraform destroy`.

O state e os CSVs gerados não entram no Git.
