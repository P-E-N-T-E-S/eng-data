# Valores escolhidos pelo grupo04 para as três decisões do exercício.
turma  = "TURMA-A"
sufixo = "grupo04"

escopo_prefeitura        = "banco"
colunas_ocultas_analista = ["passageiro_id", "motorista_id", "corrida_id"]

contrato_refined = {
  descricao   = "Corridas de madrugada agregadas por bairro e dia, sem identificadores pessoais."
  dono        = "engenharia-de-dados-grupo04"
  atualizacao = "diaria, apos execucao do job refinar-madrugada"
  comentarios = {
    bairro   = "nome do bairro onde a corrida terminou"
    corridas = "total de corridas de madrugada naquele bairro e dia"
    receita  = "soma do valor pago nas corridas de madrugada por bairro e dia"
  }
}
