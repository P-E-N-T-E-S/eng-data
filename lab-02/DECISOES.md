# DECISAO 01
Sobre os números para valor, escolhemos manter o double porque mesmo que as 1.5% das linhas vão dar problema, conseguimos extrair muito valor do restante dos dados, visto que temos uma boa quantidade de dados. Esse erro não parece ser recorrente, então faz mais sentido mitigar esse erro e posteriormente resolver, do que não ter nenhuma consulta
# DECISAO 02
Para as colunas de tempo, optamos por manter em string porque assim ainda podíamos fazer as consultas usando between e caso houvesse alguma data enviada em um padrão incorreto, podemos manter ela sem que a consulta quebre inteiramente, quanto testamos com string, conseguimos fazer a consulta corretamente
# DECISAO 03
Colocamos o ignore json porque não queremos que as querys sejam derrubadas por algum erro, queremos o resultado de toda a forma e rapidamente, a ideia seria colocar algumas validações de data quality antes de enviar os dados para o S3. Ainda assim tivemos um erro de BAD_DATA para o parse dos dados de double devido as vírgulas, precisamos colocar também a property 'use.null.for.invalid.data' = 'true', na tabela para conseguir fazer a consulta
# DECISAO 04
Definimos as 8 partições de dados para que o Athena enxergasse todos os nossos dados disponíveis, a fim de poder usar todas as corridas para fazer qualquer tipo de consulta acerca desses dados
# DECISAO 05
Escolhemos o teto de bytes de 16.965.960, esse valor é o necessário para fazer pesquisa em 5 dias dos dados, julgamos que 5 dias já consegue responder a boa parte das perguntas de negócios que o cliente pode fazer, com um bom histórico das corridas