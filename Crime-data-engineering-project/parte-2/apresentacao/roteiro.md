# Roteiro da AV2 · Crime Brasil · grupo g04

Duração prevista de 4 min 50 s, com margem de 10 s.

## Slide 1 · pergunta e resposta · 35 s

“A plataforma responde quantas vítimas de homicídio doloso foram informadas por UF e ano no BancoVDE. Usamos somente a abrangência Estadual para não misturar níveis geográficos. A edição atual tem 2,29 milhões de registros. O resultado nacional foi 35.136 vítimas em 2024, 31.520 em 2025 e 23.264 no período disponível de 2026.”

## Slide 2 · três camadas · 45 s

“A raw preserva os CSVs anuais. A trusted mantém o grão da fonte e converte os 15 campos para Parquet tipado. A refined entrega uma linha por UF e ano. Tudo é particionado por ano e declarado em Terraform, sem Crawler.”

## Slide 3 · formato e custo · 45 s

“Os CSVs somam 192 MiB. A referência trusted em Parquet soma aproximadamente 1,6 MiB e a refined fica abaixo de 3 KiB por ano. Declaramos uma meta de 1 MiB por consulta anual. O Athena mediu 370, 378 e 376 bytes, todos abaixo da meta. Pelo mínimo faturável, estimamos US$ 0,000047684 por consulta.”

## Slide 4 · idempotência e backfill · 45 s

“Cada execução substitui somente as partições solicitadas. Duas execuções completas mantiveram 2.290.260 linhas trusted e 81 linhas refined. Em seguida, reprocessamos apenas 2024. Os objetos de 2025 e 2026 conservaram seus horários e todos os resultados permaneceram iguais.”

## Slide 5 · Lake Formation · 45 s

“As três localizações estão registradas no Lake Formation. O analista lê trusted e refined, mas recebe negação na raw. O gerente lê somente refined e recebe negação nas outras duas camadas. O verificador assumiu os dois papéis e executou seis consultas, três permitidas e três negadas.”

## Slide 6 · demonstração · 1 min 15 s

1. Mostrar a saída com cinco critérios em PASSA de `./verificacao/verifica.sh`.
2. Abrir `evidencias/custos-av2.json` e destacar IDs, bytes e meta.
3. Abrir `evidencias/acesso-camadas.json` e destacar permitidos e negados.
4. Mostrar os três jobs `SUCCEEDED`, incluindo o backfill 2024.
5. Explicar que `destroy.sh` e o aceite pós-destroy serão executados ao fim da apresentação.

## Perguntas prováveis

**Por que não deduplicar linhas iguais?** A fonte não fornece uma chave natural que distinga repetição legítima de duplicata. Substituir a partição garante idempotência de processamento sem descartar informação da fonte.

**Por que particionar somente por ano?** A pergunta e os arquivos são anuais. Uma segunda chave criaria mais diretórios sem reduzir os dados necessários à consulta.

**Por que o custo estimado não usa apenas 370 bytes?** O Athena cobra uma quantidade mínima de 10 MiB por consulta sob demanda. Os bytes medidos comprovam eficiência e a estimativa usa o mínimo faturável.

**Como provar o backfill?** O job recebeu `YEARS=2024`. As versões correntes mostram horário novo somente em 2024, enquanto 2025 e 2026 mantiveram os horários da segunda carga completa.
