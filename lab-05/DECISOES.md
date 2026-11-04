# DECISOES.md — Exercício 05 · grupo: grupo04

Medições registradas na execução de 04/11/2026: a tabela trusted contém 518.400 linhas para 518.400 corridas distintas, com 11.137 corridas na madrugada dos últimos 7 dias antes e depois de rodar o job novamente.

## DECISÃO 01 — modo de escrita (`modo_escrita`)
Escolhemos `sobrescrever` com dynamic partition overwrite para garantir a idempotência do pipeline; aceitamos o custo de reescrever as partições afetadas em vez de anexar rapidamente. Rodando o job duas vezes, a tabela foi de 518.400 para 518.400 linhas (e manteve 11.137 corridas na madrugada em ambas as execuções).

## DECISÃO 02 — a chave da linha (`chave_dedup`)
Escolhemos `corrida_id` ordenado por `chegada` para manter apenas uma linha por evento; aceitamos o overhead computacional de shuffle do Window (`row_number()`) e o descarte de dados duplicados. Com o reenvio de 5 dias atrás (17.280 corridas duplicadas da raw lida de 535.680 linhas), a tabela ficou com 518.400 linhas para 518.400 corridas distintas.

## DECISÃO 03 — janela de atraso (`janela_atraso_dias`)
Escolhemos 3 dias para acomodar eventos com até 72h de latência (como a falha de borda em D-3); aceitamos o custo de reprocessar até 4 dias de chegada (`dt` e os 3 anteriores) a cada execução diária e aceitamos que atrasos maiores exijam backfill. A madrugada dos últimos 7 dias deu 11.137 corridas (incluindo as 1.591 corridas atrasadas de 2026-11-01 que chegaram hoje com `fora_da_janela = 0`); cada execução diária relê 4 dias de chegada.

## DECISÃO 04 — o backfill
Se uma corrida chegar com mais atraso do que a janela, o comando que conserta é `./rodar-job.sh DIAS=AAAA-MM-DD` (ex.: `./rodar-job.sh DIAS=2026-11-01`); ele reescreve apenas 1 pasta de partição (`dt=AAAA-MM-DD`) via dynamic overwrite e a tabela fica com 518.400 linhas (não duplica porque o Spark substitui exclusivamente a partição do dia especificado e reaplica a deduplicação por `corrida_id`).
