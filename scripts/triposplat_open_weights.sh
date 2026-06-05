#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

triposplat_ensure_data_dirs
echo "${TRIPOSPLAT_CKPT_DIR}"
