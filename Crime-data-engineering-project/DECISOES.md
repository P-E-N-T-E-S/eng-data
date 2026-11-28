# Decisões de engenharia · Crime Brasil · grupo g04

## Pergunta e fonte

A plataforma responde quantas vítimas de homicídio doloso o BancoVDE informa por UF e ano na abrangência Estadual. A soma usa `total_vitima`. A cobertura é expressa pela quantidade de meses com valor informado, para evitar interpretar 2026 como ano completo quando a fonte ainda é parcial.

A edição do Ministério da Justiça verificada em 27/11/2026 contém 2.290.260 linhas. Os originais são identificados por SHA-256 em `parte-1/dados/originais.sha256`. A conversão atual preservou 764.820 linhas em 2024, 832.302 em 2025 e 693.138 em 2026.

## AV1 · referência histórica

A AV1 declarou 15 campos físicos em CSV e `ano` como partição, totalizando 16 colunas lógicas, sem Glue Crawler. O grão é uma linha recebida do BancoVDE. A combinação de UF, município, evento, data e abrangência não é uma chave natural. Em 23/09/2026, o grupo encontrou 33 linhas no mesmo contexto de tentativa de feminicídio no DF. Por isso, registros repetidos foram preservados.

O ensaio de setembro usou uma edição anterior com 1.996.085 linhas e 177,6 MiB. O workgroup limitou consultas a 100 MiB. A consulta anual de 2024 leu 67,87 MiB e a leitura ampla foi interrompida pelo teto. Essa medição permanece como histórico da AV1.

## AV2 · grãos e chave

- Raw e trusted mantêm uma linha por registro da fonte.
- Refined possui uma linha por `(UF, ano)`. A edição atual produz 81 linhas, sendo 27 UFs em cada ano.
- A fonte continua sem chave natural suficiente para deduplicação semântica. A idempotência usa substituição integral e determinística da partição anual. Ela elimina duplicação de processamento e preserva repetições legítimas da fonte.

A primeira execução e a segunda execução completa produziram as mesmas contagens e os mesmos 81 resultados. Depois, o backfill isolado de 2024 manteve todas as contagens e métricas. Os três jobs concluíram com `SUCCEEDED`. Os registros estão em `evidencias/job-*.json` e os resultados comparados em `evidencias/snapshot-primeira.json`.

## AV2 · partição e formato

As três camadas usam `ano` como única chave de partição. A pergunta é anual e a origem chega em arquivos anuais, então uma segunda chave criaria diretórios sem reduzir a leitura exigida.

Os CSVs medem 67.101.049, 73.333.990 e 60.962.756 bytes. A referência local em Parquet Snappy reduziu as partições trusted para 547.480, 610.488 e 524.840 bytes. Cada partição refined ficou entre 2.577 e 2.579 bytes. Métricas e hashes estão em `evidencias/metricas-parquet-local.json`.

No Glue, cada partição atual possui um arquivo Parquet. O backfill executado às 21:23 de 27/11/2026 atualizou somente os objetos de 2024. Os objetos de 2025 e 2026 permaneceram com os horários da segunda carga completa, às 21:20. A evidência está em `evidencias/backfill-particoes.json`.

## AV2 · custo

A meta declarada é no máximo 1.048.576 bytes lidos por consulta anual na refined. O workgroup usa o teto mínimo aceito pelo Athena, 10.485.760 bytes.

As consultas finais leram 370 bytes em 2024, 378 em 2025 e 376 em 2026. Pela tarifa de referência de US$ 5/TB e pelo mínimo faturável de 10 MiB, cada consulta tem custo estimado de US$ 0,000047684. IDs, bytes e cálculo estão em `evidencias/custos-av2.json`.

Os resultados nacionais são 35.136 vítimas em 2024, 31.520 em 2025 e 23.264 no período disponível de 2026. O detalhe por UF está em `evidencias/homicidios-refined-local.csv` e foi comparado com o Athena durante o aceite.

## AV2 · permissão por camada

As três localizações S3 são registradas no Lake Formation.

- O perfil `analyst` consulta trusted e refined e recebe negação na raw.
- O perfil `manager` consulta somente refined e recebe negação em trusted e raw.
- O job Glue possui acesso técnico às três camadas para executar a transformação.

O aceite realizou seis consultas com os papéis assumidos. Três terminaram em `SUCCEEDED` e três em `FAILED` por falta de permissão, conforme `evidencias/acesso-camadas.json`.

## Infraestrutura e destruição

O Terraform provisiona os três buckets, os bancos e tabelas Glue, as partições, o job, o workgroup, os papéis, as políticas e as concessões do Lake Formation. Recursos compatíveis recebem `turma=eda262`, `grupo=g04` e `projeto=engenharia-de-dados`.

O bucket trusted da AV1 foi preservado e transferido para o state da AV2. O prefixo CSV `crime/` continua atendendo a AV1, enquanto a AV2 escreve Parquet em `crime_parquet/`. O state da AV1 permaneceu versionado no S3 e ganhou uma cópia de segurança local antes da migração.

O `destroy.sh` remove a AV2, o bucket compartilhado trusted, o backend dedicado e executa a verificação pós-destroy. A prova destrutiva fica para depois da apresentação, pois a infraestrutura ativa é necessária para a demonstração.
