#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

installed=false
runtime_present=false
data_present=false
env_ready=false
models_ready=false
running=false
version=not-installed
state=available
health=unavailable
detail="TripoSplat is not installed."
marker="${TRIPOSPLAT_INSTALL_ROOT}/.nymph-module-version"

if [[ -f "${marker}" ]]; then
  installed=true
  runtime_present=true
  version="$(head -n 1 "${marker}" 2>/dev/null || true)"
  [[ -n "${version}" ]] || version=unknown
  state=installed
  health=ok
  detail="TripoSplat is installed."
fi

if [[ -d "${TRIPOSPLAT_OUTPUT_DIR}" && -n "$(find "${TRIPOSPLAT_OUTPUT_DIR}" -mindepth 1 -print -quit 2>/dev/null)" ]] ||
   [[ -d "${TRIPOSPLAT_CONFIG_DIR}" && -n "$(find "${TRIPOSPLAT_CONFIG_DIR}" -mindepth 1 -print -quit 2>/dev/null)" ]] ||
   [[ -d "${TRIPOSPLAT_LOG_DIR}" && -n "$(find "${TRIPOSPLAT_LOG_DIR}" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
  data_present=true
fi

if [[ "${installed}" == "true" && -x "$(triposplat_python)" ]] &&
   "$(triposplat_python)" -m pip --version >/dev/null 2>&1; then
  env_ready=true
fi

if triposplat_models_ready; then
  models_ready=true
fi

if [[ "${installed}" == "true" && "${env_ready}" != "true" ]]; then
  state=needs_attention
  health=degraded
  detail="TripoSplat Python runtime is incomplete. Run Repair."
elif [[ "${installed}" == "true" && "${models_ready}" != "true" ]]; then
  state=model_download_needed
  health=model-download-needed
  detail="TripoSplat model files need downloading. Use Fetch Models."
fi

if triposplat_is_running; then
  running=true
  state=running
  health=ok
  detail="TripoSplat is running."
elif [[ "${installed}" == "true" && "${health}" == "ok" ]]; then
  detail="TripoSplat is installed and stopped."
fi

echo "id=triposplat"
echo "installed=${installed}"
echo "runtime_present=${runtime_present}"
echo "data_present=${data_present}"
echo "version=${version}"
echo "running=${running}"
echo "state=${state}"
echo "health=${health}"
echo "detail=${detail}"
echo "install_root=${TRIPOSPLAT_INSTALL_ROOT}"
echo "marker=${marker}"
echo "url=${TRIPOSPLAT_SERVER_URL}/nymph"
echo "server_url=${TRIPOSPLAT_SERVER_URL}"
echo "models_ready=${models_ready}"
echo "env_ready=${env_ready}"
echo "outputs_root=${TRIPOSPLAT_OUTPUT_DIR}"
echo "models_root=${TRIPOSPLAT_CKPT_DIR}"
