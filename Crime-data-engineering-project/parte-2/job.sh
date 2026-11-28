#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/terraform/ambiente.sh"

years="${1:-2024,2025,2026}"
[[ "$years" =~ ^20[0-9]{2}(,20[0-9]{2})*$ ]] || { echo "Use AAAA ou AAAA,AAAA" >&2; exit 1; }
python3 "$PROJETO/parte-2/verificacao/aceite.py" --confere-contexto
job="$(terraform -chdir="$TF_DIR" output -raw job)"
run_id="$(aws glue start-job-run --job-name "$job" --arguments "{\"--YEARS\":\"$years\"}" --query JobRunId --output text)"
echo "job=$job run=$run_id years=$years"

while :; do
  state="$(aws glue get-job-run --job-name "$job" --run-id "$run_id" --query JobRun.JobRunState --output text)"
  case "$state" in
    SUCCEEDED) break ;;
    FAILED|ERROR|TIMEOUT|STOPPED|EXPIRED)
      aws glue get-job-run --job-name "$job" --run-id "$run_id" --output json
      exit 1
      ;;
  esac
  sleep 10
done

mkdir -p "$PROJETO/evidencias"
aws glue get-job-run --job-name "$job" --run-id "$run_id" --output json \
  > "$PROJETO/evidencias/job-${years//,/-}-$run_id.json"
echo "SUCCEEDED · $run_id"
