#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

triposplat_ensure_data_dirs
log_file="${TRIPOSPLAT_LOG_DIR}/triposplat-server.log"
touch "${log_file}"
echo "last_log=${log_file}"
echo "logs_dir=${TRIPOSPLAT_LOG_DIR}"
