#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

yes=false
purge=false
data_only=false
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) yes=true ;;
    --purge) purge=true ;;
    --data-only) data_only=true ;;
    --dry-run) dry_run=true ;;
  esac
  shift
done

if [[ "${yes}" != "true" && "${dry_run}" != "true" ]]; then
  echo "Pass --yes to uninstall TripoSplat." >&2
  exit 1
fi

paths=()
if [[ "${data_only}" == "true" ]]; then
  paths+=("${TRIPOSPLAT_OUTPUT_DIR}" "${TRIPOSPLAT_LOG_DIR}" "${TRIPOSPLAT_CONFIG_DIR}")
else
  paths+=("${TRIPOSPLAT_INSTALL_ROOT}")
  if [[ "${purge}" == "true" ]]; then
    paths+=("${TRIPOSPLAT_OUTPUT_DIR}" "${TRIPOSPLAT_LOG_DIR}" "${TRIPOSPLAT_CONFIG_DIR}" "${TRIPOSPLAT_MODEL_ROOT}")
  fi
fi

if [[ "${dry_run}" == "true" ]]; then
  printf 'would_remove=%s\n' "${paths[@]}"
  exit 0
fi

"${SCRIPT_DIR}/triposplat_stop.sh" >/dev/null 2>&1 || true
for path in "${paths[@]}"; do
  if [[ -n "${path}" && "${path}" == "$HOME"* && -e "${path}" ]]; then
    rm -rf "${path}"
    echo "removed=${path}"
  fi
done
