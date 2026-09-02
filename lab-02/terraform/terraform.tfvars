# Copie este arquivo para terraform.tfvars e preencha.
#   cp terraform.tfvars.example terraform.tfvars

sufixo = "gruo04"        # so minusculas, numeros e hifen

# DECISAO 05 — o teto que voce MEDIU (nao copie do lab).
# Rode a consulta larga sem teto, veja o Data scanned, e escolha. para 5 dias temos = 16965960 de bytes escaneados
teto_bytes = 16965960

# DECISAO 04 — os dias que voce vai registrar como particao (>= 3, incluindo hoje).
# Troque pelos dias reais; o do meio e o de hoje.
dias_particao = ["2026-08-26", "2026-08-27", "2026-08-28", "2026-08-29", "2026-08-30", "2026-08-31", "2026-09-01", "2026-09-02"]
