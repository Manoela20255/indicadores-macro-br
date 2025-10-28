#!/usr/bin/env bash
# Start the local plumber API in background and print PID
set -euo pipefail
ROOT_DIR="/Users/manoelacardosocalheiros/Downloads/_includes/Tentativa3"
R_SCRIPT="$ROOT_DIR/scripts/start_api.R"
if [ ! -f "$R_SCRIPT" ]; then
  echo "start_api.R not found: $R_SCRIPT" >&2
  exit 1
fi

nohup Rscript "$R_SCRIPT" > "$ROOT_DIR/logs/api.log" 2>&1 &
PID=$!
echo "API started (PID=$PID). Logs: $ROOT_DIR/logs/api.log"
exit 0
