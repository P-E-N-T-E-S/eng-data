# DECISOES.md — Exercício 06 · grupo: grupo04

## DECISÃO 01 — o alcance da Prefeitura na refined (`escopo_prefeitura`)

Escolhemos `banco`: a Prefeitura pode ler todas as tabelas da camada refined, inclusive as criadas depois; aceitamos que uma nova tabela refined ficará visível automaticamente e, por isso, essa camada não pode receber identificadores. A madrugada dos últimos sete dias, lida como Prefeitura, deu **11.137 corridas**.

## DECISÃO 02 — as colunas que a analista não vê (`colunas_ocultas_analista`)

Escondemos `corrida_id`, `motorista_id` e `passageiro_id`. A analista continua lendo as outras 8 das 11 colunas; `SELECT passageiro_id` como ela foi **RECUSADO**. Deixamos `bairro`, horário, distância, duração e valor visíveis porque são necessários para investigar uma corrida reclamada sem identificar pessoas.

## DECISÃO 03 — o contrato da refined (`contrato_refined`)

A descrição informa que a tabela agrega corridas de madrugada por bairro e dia e não contém identificadores pessoais. Um consumidor que só ler o catálogo sabe o grão, que as métricas são corridas e receita, e que a tabela não tem IDs; a descrição tem **79 caracteres**. O dono é `engenharia-de-dados-grupo04`, e a tabela muda diariamente após o job `refinar-madrugada`.
