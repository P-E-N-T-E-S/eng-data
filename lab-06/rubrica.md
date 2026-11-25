# Rubrica — Exercício 06 (Aula 29): o lake em camadas, e quem lê cada uma

Pública desde a Aula 28. É a mesma tabela do `enunciado.html` e a que o `verifica.sh` imprime.
Sem nota própria: é o terceiro incremento da Parte 2 do projeto (AV2).

| # | Critério | Como é verificado | Peso |
| --- | --- | --- | --- |
| 0 | Terraform com backend remoto; **três databases**, um por camada; a refined `madrugada_bairro` em Parquet | `verifica.sh` (estado do backend + Glue API) | **elimina** |
| 1 | **A Prefeitura lê a refined:** como o perfil `prefeitura`, a madrugada dos últimos 7 dias dá **11.137** | `verifica.sh` · Athena, como o perfil | 20% |
| 2 | **E só a refined:** como `prefeitura`, a trusted e a raw são **recusadas** pelo Athena, e o S3 direto também | `verifica.sh` · Athena + S3, como o perfil | 25% |
| 3 | **A analista lê a trusted sem os ids escolhidos:** `count(bairro)` = 518.400 e `SELECT passageiro_id` **recusado** | `verifica.sh` · Athena, como o perfil | 15% |
| 4 | **O contrato da refined está no catálogo:** descrição com ao menos 40 caracteres, parâmetro `dono` e comentário em toda coluna | `verifica.sh` · Glue API | 10% |
| 5 | `destroy` limpo: nenhum recurso `eda-a29-<sufixo>` sobra, nem registro no Lake Formation | `verifica.sh --pos-destroy` | 10% |
| 6 | `DECISOES.md`: uma frase e **uma evidência medida** por decisão | leitura | 20% |

**O critério 2 é o exercício.** Ele pergunta como a Prefeitura o que ela não pode ver. Recusado
passa; qualquer número reprova. Nada de argumentação.

**O que mais reprova**

1. A trusted ainda dá acesso automático a qualquer usuário com IAM (`IAMAllowedPrincipals`): a
   Prefeitura lê a trusted e o critério 2 cai inteiro.
2. Esquecer a DECISÃO 01 no `main.tf`: o `plan` recusa (`name` e `wildcard` nulos), ou a Prefeitura
   não lê nem a refined — cai o 1.
3. `excluded_column_names` vazio: a analista vê `passageiro_id` — cai o 3.
4. Descrição genérica ("tabela da refined"): menos de 40 caracteres, ou sem dizer o que a tabela
   responde — cai o 4 no script, e a DECISÃO 03 no `DECISOES.md`.
5. Recurso órfão depois do destroy — cai o 5 inteiro.

**O que não conta na nota:** elegância do HCL, recursos extras que ninguém pediu, e ter feito a
mesma escolha do lab. Uma DECISÃO 01 diferente da do lab, bem justificada, vale 10.

**Entrega:** PR com `terraform/` (sem `terraform.tfvars` de outro grupo, sem `backend.hcl`,
sem `.terraform/`, sem `*.tfstate`), `DECISOES.md` e a saída do `verifica.sh` colada.
Fora do prazo, nota inicial 8,0.
