# Roteiro de apresentação — AV1 Crime Brasil

**Duração:** 5 minutos de apresentação + 2 minutos de perguntas  
**Grupo:** g04  
**Objetivo:** demonstrar que a infraestrutura sobe do zero, responde à pergunta
de negócio com custo controlado e pode ser destruída sem recursos órfãos.

## Sequência de slides

| Tempo | Slide | Mostrar | Fala principal |
| --- | --- | --- | --- |
| 0:00–0:25 | 1. Crime Brasil | Domínio, pergunta e grupo | “Nosso cenário usa dados do BancoVDE, do Ministério da Justiça. Queremos identificar, por estado e ano, a tendência de homicídio doloso.” |
| 0:25–0:55 | 2. Dados | 3 arquivos, 1.996.085 linhas, 2024–2026 | “Recebemos três XLSX. O pipeline gera um CSV por ano, preserva os campos de origem, adiciona `mes` e usa a pasta S3 `ano=YYYY` para a partição.” |
| 0:55–1:40 | 3. Arquitetura | Terraform, backend S3+DynamoDB, bucket trusted, Glue e Athena | “O Terraform cria toda a infraestrutura. O Glue recebe schema declarado, sem Crawler. O Athena consulta a tabela `crime_trusted`.” |
| 1:40–2:25 | 4. Decisões de dados | Grão, schema e tipos | “O grão é o registro recebido da fonte; as dimensões município, evento, mês e abrangência podem se repetir, por isso não deduplicamos sem uma regra de negócio. Mantemos 15 colunas no CSV e `ano` como partição, totalizando 16 colunas lógicas. As contagens ficam como inteiros e ausências usam `\\N`, lido como `NULL`.” |
| 2:25–3:10 | 5. Partição e custo | tamanhos por ano, teto de 100 MiB, saída do `verifica.sh` | “A maior partição tem 74,3 MiB e o lake completo tem 177,6 MiB. Por isso configuramos 100 MiB. A leitura sem filtro foi cancelada no limite, e a consulta de negócio em 2024 leu 67,87 MB.” |
| 3:10–4:30 | 6. Demonstração | `verifica.sh` e consulta de negócio no Athena | “Aqui mostramos o bucket, a tabela, as três partições e o workgroup. Em seguida, executamos a consulta de homicídio doloso para 2024 e mostramos o resultado com 67,87 MB lidos.” |
| 4:30–5:00 | 7. Encerramento | decisões, reprodutibilidade e próximo ciclo | “A AV1 entrega uma camada trusted reproduzível e verificável. Na AV2, evoluiremos para raw, trusted e refined em Parquet, com ingestão idempotente.” |

## Consulta de negócio para a demonstração

```sql
SELECT
  uf,
  ano,
  SUM(total_vitima) AS homicidios
FROM "eda262_g04_crime_db"."crime_trusted"
WHERE evento = 'Homicídio doloso'
  AND ano = 2024
GROUP BY uf, ano
ORDER BY uf, ano;
```

Antes de apresentar, registrar no slide os **67,87 MB** lidos nessa consulta.

## Evidências a capturar antes da apresentação

- `terraform apply` concluído, com os outputs do bucket, database, tabela e workgroup.
- Saída completa de `./verificacao/verifica.sh` com todos os critérios em PASSA.
- Resultado da consulta de negócio filtrada para 2024 e os 67,87 MB lidos.
- Saída de `./destroy.sh` seguida de `./verificacao/verifica.sh --pos-destroy`.
- Após essa prova, executar `terraform apply` novamente se a demonstração exigir a infraestrutura ativa.

## Perguntas prováveis

**Por que o limite é 100 MiB?**  
Porque a maior partição anual mede 74,3 MiB e o lake completo mede 177,6 MiB.
O teto deixa consultas por ano passarem e interrompe leituras sem filtro.

**Por que não usar Glue Crawler?**  
A AV1 exige schema declarado em infraestrutura como código. Isso torna tipos,
colunas e partições previsíveis no deploy em uma conta limpa.

**Por que `ano` não aparece dentro do CSV?**  
`ano` é a chave da partição Hive. Repeti-lo como coluna física criaria um campo
duplicado no Glue.

**Por que CSV, e não Parquet?**  
A AV1 exige apenas a camada trusted. CSV é a saída direta e verificável da
conversão. Parquet e as três camadas entram na AV2.

**Como tratam 2026?**  
2026 contém dados parciais. A apresentação deve informar essa limitação ao
interpretar tendências anuais.
