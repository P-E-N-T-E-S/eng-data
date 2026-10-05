# Decisões — Exercício 03

## DECISÃO 01 — Fronteira do módulo
Coloquei os seis recursos de S3, Glue e Athena no módulo `lake`, preservando seus nomes e propriedades, e mantive provider, backend e chamada do módulo na raiz, com os cinco outputs encaminhados pelo módulo, para separar a infraestrutura do lake da configuração de execução.

## DECISÃO 02 — Movimentação do estado
Executei um `terraform state mv` para cada um dos seis recursos, associando seus endereços antigos aos novos endereços em `module.lake` sem recriá-los, e entendi que `state mv` altera diretamente o estado enquanto blocos `moved` registram essa migração declarativamente no código.

## DECISÃO 03 — Workspace e pasta
Criei o workspace `dev` para permitir um estado separado usando o mesmo código, sem duplicar pastas de configuração, e voltei ao `default` para manter a stack migrada no estado que já a gerencia, pois `dev` começa vazio e os nomes atuais não incluem o workspace, o que causaria conflitos ao tentar criar outra stack com o mesmo sufixo.

## DECISÃO 04 — Significado do plan limpo
O resultado `No changes`, obtido após mover os endereços e novamente após migrar o estado para o S3, mostra que o Terraform não propõe alterações nos recursos gerenciados naquele momento, mas não prova sozinho que nunca houve recriações nem impede drift futuro ou detecta diferenças fora do que o provider acompanha.

## DECISÃO 05 — Ordem das operações
Se eu tivesse executado `apply` após mover o código e antes de mover o estado, o Terraform teria tentado destruir os recursos nos endereços antigos e criar os dos novos endereços, arriscando perda de dados, indisponibilidade e conflitos de nomes, por isso movi o estado antes de prosseguir.
