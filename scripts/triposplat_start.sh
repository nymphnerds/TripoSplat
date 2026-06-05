#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

if triposplat_is_running; then
  echo "TripoSplat is already running at ${TRIPOSPLAT_SERVER_URL}"
  echo "url=${TRIPOSPLAT_SERVER_URL}/nymph"
  echo "module_ui_url=${TRIPOSPLAT_SERVER_URL}/nymph"
  exit 0
fi

if [[ ! -x "$(triposplat_python)" ]]; then
  echo "TripoSplat runtime is missing. Run Install or Repair first." >&2
  exit 1
fi

if [[ ! -f "${TRIPOSPLAT_INSTALL_ROOT}/scripts/api_server_triposplat.py" ]]; then
  echo "TripoSplat API server is missing. Run Install or Repair first." >&2
  exit 1
fi

triposplat_ensure_data_dirs
log_file="${TRIPOSPLAT_LOG_DIR}/triposplat-server.log"
echo "Starting TripoSplat at ${TRIPOSPLAT_SERVER_URL}"
(
  cd "${TRIPOSPLAT_INSTALL_ROOT}"
  nohup "$(triposplat_python)" -u scripts/api_server_triposplat.py --host "${TRIPOSPLAT_HOST}" --port "${TRIPOSPLAT_PORT}" >"${log_file}" 2>&1 &
  echo $! > "${TRIPOSPLAT_PID_FILE}"
)

for _ in $(seq 1 60); do
  if triposplat_probe_url "${TRIPOSPLAT_SERVER_URL}/server_info" >/dev/null 2>&1; then
    echo "TripoSplat started."
    echo "url=${TRIPOSPLAT_SERVER_URL}/nymph"
    echo "module_ui_url=${TRIPOSPLAT_SERVER_URL}/nymph"
    exit 0
  fi
  sleep 1
done

echo "TripoSplat did not answer before timeout. Check ${log_file}" >&2
exit 1
