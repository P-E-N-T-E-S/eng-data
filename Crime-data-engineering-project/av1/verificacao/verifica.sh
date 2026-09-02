#!/usr/bin/env bash
# Verificacao da AV1 (grupo g04) — Data Lake Crime, schema declarado, sem crawler.
# Rode da raiz de av1/. Imprime PASSA/FALHA por criterio da rubrica da AV1.
#
#   ./verificacao/verifica.sh           # criterios 0..4
#   ./verificacao/verifica.sh --pos-destroy   # criterio 5 (destroy limpo)
set -uo pipefail

REGIAO="us-east-1"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
MODO="${1:-}"

BUCKET="eda262-g04-lake-trusted"
DATABASE="eda262_g04_crime_db"
TABLE="crime_trusted"
WORKGROUP="eda262-g04-crime-wg"

falhas=0
evidencia=""

ok()   { printf "  [PASSA]   %s\n" "$1"; evidencia+="[PASSA]   $1"$'\n'; }
nao()  { printf "  [FALHA]   %s\n" "$1"; evidencia+="[FALHA]   $1"$'\n'; falhas=$((falhas+1)); }
info() { printf "            %s\n" "$1"; evidencia+="          $1"$'\n'; }

echo "verificacao AV1 g04 · regiao ${REGIAO}"
echo

# ---------------------------------------------------------- criterio 5 (pos-destroy)
if [[ "$MODO" == "--pos-destroy" ]]; then
  echo "CRITERIO 5 - destroy limpo (15%)"
  sobrou=""
  aws s3api head-bucket --bucket "$BUCKET" --region "$REGIAO" 2>/dev/null && sobrou+="bucket "
  [[ -n "$(aws glue get-database --name "$DATABASE" --region "$REGIAO" \
        --query Database.Name --output text 2>/dev/null || true)" ]] && sobrou+="database "
  [[ -n "$(aws glue get-table --database-name "$DATABASE" --name "$TABLE" --region "$REGIAO" \
        --query Table.Name --output text 2>/dev/null || true)" ]] && sobrou+="tabela "
  [[ -n "$(aws athena list-work-groups --region "$REGIAO" \
        --query "WorkGroups[?Name=='$WORKGROUP'].Name" --output text 2>/dev/null || true)" ]] && sobrou+="workgroup "
  if [[ -z "$sobrou" ]]; then ok "nenhum recurso orfao"
  else nao "sobraram: ${sobrou}"; fi
  echo; echo "----- cole no PR a partir daqui -----"
  printf "%s" "$evidencia"; echo "-------------------------------------"
  exit $(( falhas > 0 ? 1 : 0 ))
fi

# ---------------------------------------------------------- criterio 0: sem crawler
echo "CRITERIO 0 - sem AWS::Glue::Crawler (eliminatorio)"
if aws glue list-crawlers --region "$REGIAO" --query "CrawlerNames[?starts_with(@,'eda262-g04')]" \
     --output text 2>/dev/null | grep -q .; then
  nao "existe crawler do grupo no Glue — AV1 exige schema declarado"
  echo "criterio eliminatorio: paro."; exit 1
else ok "nenhum crawler do grupo"; fi
echo

# ---------------------------------------------------------- criterio 1: bucket existe
echo "CRITERIO 1 - bucket trusted existe"
if aws s3api head-bucket --bucket "$BUCKET" --region "$REGIAO" 2>/dev/null; then
  ok "s3://${BUCKET} acessivel"
else nao "s3://${BUCKET} nao encontrado"; fi
echo

# ---------------------------------------------------------- criterio 2: database + tabela + 16 colunas
echo "CRITERIO 2 - schema declarado (>=16 colunas, particao ano)"
tabela="$(aws glue get-table --database-name "$DATABASE" --name "$TABLE" \
  --region "$REGIAO" --output json 2>/dev/null || true)"
if [[ -z "$tabela" ]]; then
  nao "tabela ${TABLE} nao existe em ${DATABASE}"
else
  ncol="$(printf '%s' "$tabela" | python3 -c \
    "import json,sys;print(len(json.load(sys.stdin)['Table']['StorageDescriptor']['Columns']))")"
  chave="$(printf '%s' "$tabela" | python3 -c \
    "import json,sys;k=json.load(sys.stdin)['Table'].get('PartitionKeys',[]);print(','.join(c['Name'] for c in k))")"
  info "colunas declaradas: ${ncol}"
  info "chave de particao: ${chave:-nenhuma}"
  if [[ "$ncol" -ge 16 && "$chave" == "ano" ]]; then
    ok ">= 16 colunas e particao 'ano'"
  else nao "exige >= 16 colunas (tem ${ncol}) e particao ano (tem '${chave}')"; fi
fi
echo

# ---------------------------------------------------------- criterio 3: particoes ano=2024/2025/2026
echo "CRITERIO 3 - particoes por ano declaradas"
parts="$(aws glue get-partitions --database-name "$DATABASE" --table-name "$TABLE" \
  --region "$REGIAO" --output json 2>/dev/null || true)"
if [[ -z "$parts" ]]; then
  nao "nenhuma particao registrada"
else
  npart="$(printf '%s' "$parts" | python3 -c "import json,sys;print(len(json.load(sys.stdin)['Partitions']))")"
  info "particoes: ${npart}"
  ruins="$(printf '%s' "$parts" | python3 -c "
import json,sys
p=json.load(sys.stdin)['Partitions']
ruins=[x['Values'][0] for x in p if 'ano='+x['Values'][0] not in x['StorageDescriptor']['Location']]
print(' '.join(ruins))")"
  if [[ "$npart" -ge 3 && -z "$ruins" ]]; then
    ok ">= 3 particoes e todo Location bate com ano="
  else nao "exige >= 3 particoes bem formadas (tem ${npart}, ruins: '${ruins}')"; fi
fi
echo

# ---------------------------------------------------------- criterio 4: teto mata larga
echo "CRITERIO 4 - trabalho de consulta medido (teto mata larga, deixa estreita)"
consulta() {
  local sql="$1" qid
  qid="$(aws athena start-query-execution --region "$REGIAO" \
    --work-group "$WORKGROUP" --query-execution-context "Database=$DATABASE" \
    --query-string "$sql" --query QueryExecutionId --output text 2>/dev/null || true)"
  [[ -z "$qid" ]] && { echo "ERRO|0"; return; }
  for _ in $(seq 1 40); do
    local est bytes
    est="$(aws athena get-query-execution --region "$REGIAO" --query-execution-id "$qid" \
      --query "QueryExecution.Status.State" --output text 2>/dev/null || echo ERRO)"
    case "$est" in
      SUCCEEDED|FAILED|CANCELLED)
        bytes="$(aws athena get-query-execution --region "$REGIAO" --query-execution-id "$qid" \
          --query "QueryExecution.Statistics.DataScannedInBytes" --output text 2>/dev/null || echo 0)"
        echo "${est}|${bytes}"; return;;
    esac
    sleep 3
  done
  echo "TIMEOUT|0"
}
larga="$(consulta "SELECT count(*) FROM \"${DATABASE}\".\"${TABLE}\";")"
estreita="$(consulta "SELECT count(*) FROM \"${DATABASE}\".\"${TABLE}\" WHERE ano='2024';")"
info "larga (sem WHERE): ${larga%%|*} · ${larga##*|} bytes"
info "estreita (ano=2024): ${estreita%%|*} · ${estreita##*|} bytes"
if [[ "${larga%%|*}" == "FAILED" && "${estreita%%|*}" == "SUCCEEDED" ]]; then
  ok "o freio tocou na larga e deixou a estreita passar"
elif [[ "${larga%%|*}" == "SUCCEEDED" ]]; then
  nao "consulta larga passou — teto alto demais"
else nao "estreita nao respondeu — confira Location/particoes"; fi
echo

echo "----- cole no PR a partir daqui -----"
printf "%s" "$evidencia"
echo "resumo: ${falhas} criterio(s) em FALHA"
echo "-------------------------------------"
exit $(( falhas > 0 ? 1 : 0 ))
