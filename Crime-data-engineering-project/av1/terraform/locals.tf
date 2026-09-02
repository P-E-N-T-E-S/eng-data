# Definicao unica das 16 colunas (tabela + particoes reusam via dynamic).
#
# NOTA DE TIPO (gotcha): o CSV grava total_vitima/total como inteiro
# (o conversor grava int). Se por acaso aparecer "0.0" no CSV, declare
# estas duas como double em vez de int.
locals {
  colunas = [
    { name = "uf",              type = "string"  },
    { name = "municipio",       type = "string"  },
    { name = "evento",          type = "string"  },
    { name = "data_referencia", type = "date"    },
    { name = "agente",          type = "string"  },
    { name = "arma",            type = "string"  },
    { name = "faixa_etaria",    type = "string"  },
    { name = "feminino",        type = "int"     },
    { name = "masculino",       type = "int"     },
    { name = "nao_informado",   type = "int"     },
    { name = "total_vitima",    type = "int"     },
    { name = "total",           type = "int"     },
    { name = "total_peso",      type = "double"  },
    { name = "abrangencia",     type = "string"  },
    { name = "ano",             type = "int"     },
    { name = "mes",             type = "int"     },
  ]
}
