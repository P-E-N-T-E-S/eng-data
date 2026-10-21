# DECISOES.md — Exercício 04 (Aula 21)

Medições registradas após a execução de 21/10/2026: a trusted contém **518.400
corridas em 30 dias**, com 30 arquivos Parquet totalizando **18.143.089 bytes**.

## DECISÃO 01 — chave de partição

Escolhemos `dt` como única chave de partição. A pergunta da madrugada filtra
sete dias, portanto abre **7 pastas diárias** das **30 partições registradas**,
não `7 × 22` pastas de bairro.
Aceitamos ler os bairros dentro de cada dia porque a consulta agrupa por bairro,
mas não o filtra. Isso reduz diretórios, metadados e arquivos abertos.

## DECISÃO 02 — arquivos por pasta

Escolhemos **1 arquivo Parquet por pasta diária**. A execução produziu
**30 arquivos**, com no máximo **1 arquivo por partição**, e **18.143.089
bytes** no total. A pergunta de sete dias abre **7 arquivos**, dentro do limite
de quatro arquivos por partição.

## DECISÃO 03 — meta de custo

Declaramos **524.288 bytes (512 KiB)** para a pergunta da madrugada, com base
na referência de aproximadamente 0,4 MiB do enunciado para o layout diário em
Parquet. A medição no Athena foi **355.803 bytes** para os sete dias e retornou
**11.137 corridas**. Assim, a meta tem margem de 168.485 bytes (cerca de 47%) e
permanece abaixo de **1.048.576 bytes (1 MiB)**.

## DECISÃO 04 — teto do workgroup

Declaramos **10.485.760 bytes (10 MiB)**, o mínimo aceito pelo Athena. A
pergunta curta passou com **355.803 bytes**; a consulta larga foi cancelada ao
atingir **10.485.760 bytes** (`Bytes scanned limit was exceeded`). O preço é que
análises sem filtro de data são bloqueadas e precisam ser reescritas.

## DECISÃO 05 — registro das partições

Escolhemos **MSCK REPAIR TABLE** após cada job. Aceitamos registrar as pastas
no Glue para manter a configuração simples; o `rodar-job.sh` executou o repair
e o Athena confirmou **30 valores distintos de `dt`**. No dia 31, uma nova
pasta `dt=AAAA-MM-DD` é descoberta pelo MSCK, sem alterar o Terraform.
