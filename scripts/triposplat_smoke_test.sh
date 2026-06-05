#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

started_here=false
if ! triposplat_is_running; then
  "${SCRIPT_DIR}/triposplat_start.sh"
  started_here=true
fi

triposplat_probe_url "${TRIPOSPLAT_SERVER_URL}/health" >/dev/null
server_info="$(triposplat_probe_url "${TRIPOSPLAT_SERVER_URL}/server_info")"
echo "${server_info}"
echo "SMOKE TEST PASSED"

if [[ "${started_here}" == "true" ]]; then
  "${SCRIPT_DIR}/triposplat_stop.sh" >/dev/null 2>&1 || true
fi
