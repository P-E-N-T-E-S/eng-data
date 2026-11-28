#!/usr/bin/env bash
set -euo pipefail
parte="$(cd "$(dirname "$0")" && pwd -P)"

"$parte/ingest.sh"
"$parte/job.sh" 2024,2025,2026
python3 "$parte/verificacao/aceite.py" --snapshot primeira

"$parte/job.sh" 2024,2025,2026
python3 "$parte/verificacao/aceite.py" --compare primeira

"$parte/job.sh" 2024
python3 "$parte/verificacao/aceite.py" --compare primeira

"$parte/verificacao/verifica.sh"
