#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

if [[ -f "${TRIPOSPLAT_PID_FILE}" ]]; then
  pid="$(head -n 1 "${TRIPOSPLAT_PID_FILE}" 2>/dev/null || true)"
  if [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    echo "Stopping TripoSplat process ${pid}"
    kill "${pid}" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
      if ! kill -0 "${pid}" >/dev/null 2>&1; then
        rm -f "${TRIPOSPLAT_PID_FILE}"
        echo "TripoSplat stopped."
        exit 0
      fi
      sleep 0.5
    done
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi
fi

rm -f "${TRIPOSPLAT_PID_FILE}"
echo "TripoSplat is stopped."
