#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TRIPOSPLAT_VERSION="${TRIPOSPLAT_VERSION:-}"
if [[ -z "${TRIPOSPLAT_VERSION}" && -f "${MODULE_ROOT}/nymph.json" ]] && command -v python3 >/dev/null 2>&1; then
  TRIPOSPLAT_VERSION="$(
    python3 - "${MODULE_ROOT}/nymph.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)
print(str(manifest.get("version", "0.1.0")).strip() or "0.1.0")
PY
  )"
fi
TRIPOSPLAT_VERSION="${TRIPOSPLAT_VERSION:-0.1.0}"
TRIPOSPLAT_INSTALL_ROOT="${TRIPOSPLAT_INSTALL_ROOT:-$HOME/TripoSplat}"
TRIPOSPLAT_VENV_DIR="${TRIPOSPLAT_VENV_DIR:-$TRIPOSPLAT_INSTALL_ROOT/.venv}"
NYMPHS_DATA_ROOT="${NYMPHS_DATA_ROOT:-$HOME/NymphsData}"
TRIPOSPLAT_MODEL_ROOT="${TRIPOSPLAT_MODEL_ROOT:-$NYMPHS_DATA_ROOT/models/triposplat}"
TRIPOSPLAT_CKPT_DIR="${TRIPOSPLAT_CKPT_DIR:-$TRIPOSPLAT_MODEL_ROOT/ckpts}"
TRIPOSPLAT_OUTPUT_DIR="${TRIPOSPLAT_OUTPUT_DIR:-$NYMPHS_DATA_ROOT/outputs/triposplat}"
TRIPOSPLAT_LOG_DIR="${TRIPOSPLAT_LOG_DIR:-$NYMPHS_DATA_ROOT/logs/triposplat}"
TRIPOSPLAT_CONFIG_DIR="${TRIPOSPLAT_CONFIG_DIR:-$NYMPHS_DATA_ROOT/config/triposplat}"
TRIPOSPLAT_CACHE_DIR="${TRIPOSPLAT_CACHE_DIR:-$NYMPHS_DATA_ROOT/cache/triposplat}"
TRIPOSPLAT_HF_CACHE_DIR="${TRIPOSPLAT_HF_CACHE_DIR:-$NYMPHS_DATA_ROOT/cache/huggingface}"
TRIPOSPLAT_PID_FILE="${TRIPOSPLAT_PID_FILE:-$TRIPOSPLAT_LOG_DIR/triposplat-runtime.pid}"
TRIPOSPLAT_HOST="${TRIPOSPLAT_HOST:-127.0.0.1}"
TRIPOSPLAT_PORT="${TRIPOSPLAT_PORT:-7002}"
TRIPOSPLAT_SERVER_URL="${TRIPOSPLAT_SERVER_URL:-http://${TRIPOSPLAT_HOST}:${TRIPOSPLAT_PORT}}"
TRIPOSPLAT_MODEL_REPO="${TRIPOSPLAT_MODEL_REPO:-VAST-AI/TripoSplat}"
TRIPOSPLAT_TORCH_INDEX_URL="${TRIPOSPLAT_TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu130}"

export HF_HOME="${HF_HOME:-$NYMPHS_DATA_ROOT/cache/huggingface-home}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-$TRIPOSPLAT_HF_CACHE_DIR}"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-0}"
export TORCH_HOME="${TORCH_HOME:-$NYMPHS_DATA_ROOT/cache/torch-hub}"
export TRIPOSPLAT_CKPT_DIR TRIPOSPLAT_OUTPUT_DIR TRIPOSPLAT_LOG_DIR TRIPOSPLAT_CONFIG_DIR

if [[ -d /usr/local/cuda-13.0 ]]; then
  export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-13.0}"
elif [[ -d /usr/local/cuda-12.4 ]]; then
  export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda-12.4}"
fi
if [[ -n "${CUDA_HOME:-}" ]]; then
  cuda_lib_dir="${CUDA_HOME}/lib64"
  if [[ -d "${CUDA_HOME}/targets/x86_64-linux/lib" ]]; then
    cuda_lib_dir="${CUDA_HOME}/targets/x86_64-linux/lib"
  fi
  cuda_include_dir="${CUDA_HOME}/include"
  if [[ -d "${CUDA_HOME}/targets/x86_64-linux/include" ]]; then
    cuda_include_dir="${CUDA_HOME}/targets/x86_64-linux/include"
  fi
  export PATH="${CUDA_HOME}/bin:${PATH}"
  export LD_LIBRARY_PATH="${cuda_lib_dir}:${LD_LIBRARY_PATH:-}"
  export LIBRARY_PATH="${cuda_lib_dir}:${LIBRARY_PATH:-}"
  export CUDA_INCLUDE_DIRS="${cuda_include_dir}"
  export CUDACXX="${CUDACXX:-${CUDA_HOME}/bin/nvcc}"
  export CMAKE_PREFIX_PATH="${CUDA_HOME}:${CUDA_HOME}/targets/x86_64-linux:${CMAKE_PREFIX_PATH:-}"
fi

triposplat_python() {
  printf '%s\n' "${TRIPOSPLAT_VENV_DIR}/bin/python"
}

triposplat_pip() {
  printf '%s\n' "${TRIPOSPLAT_VENV_DIR}/bin/pip"
}

triposplat_ensure_data_dirs() {
  mkdir -p \
    "${TRIPOSPLAT_MODEL_ROOT}" \
    "${TRIPOSPLAT_CKPT_DIR}" \
    "${TRIPOSPLAT_OUTPUT_DIR}" \
    "${TRIPOSPLAT_LOG_DIR}" \
    "${TRIPOSPLAT_CONFIG_DIR}" \
    "${TRIPOSPLAT_CACHE_DIR}" \
    "${TRIPOSPLAT_HF_CACHE_DIR}" \
    "${HF_HOME}" \
    "${TORCH_HOME}"
}

triposplat_probe_url() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 2 "${url}"
  else
    "$(triposplat_python)" - "${url}" <<'PY'
import sys
from urllib.request import urlopen

with urlopen(sys.argv[1], timeout=2) as response:
    sys.stdout.write(response.read().decode("utf-8", errors="replace"))
PY
  fi
}

triposplat_pid_running() {
  local pid_file="${TRIPOSPLAT_PID_FILE}"
  [[ -f "${pid_file}" ]] || return 1
  local pid
  pid="$(head -n 1 "${pid_file}" 2>/dev/null || true)"
  [[ "${pid}" =~ ^[0-9]+$ ]] || return 1
  kill -0 "${pid}" >/dev/null 2>&1
}

triposplat_is_running() {
  triposplat_probe_url "${TRIPOSPLAT_SERVER_URL}/health" >/dev/null 2>&1
}

triposplat_required_model_files() {
  printf '%s\n' \
    "${TRIPOSPLAT_CKPT_DIR}/diffusion_models/triposplat_fp16.safetensors" \
    "${TRIPOSPLAT_CKPT_DIR}/vae/triposplat_vae_decoder_fp16.safetensors" \
    "${TRIPOSPLAT_CKPT_DIR}/clip_vision/dino_v3_vit_h.safetensors" \
    "${TRIPOSPLAT_CKPT_DIR}/vae/flux2-vae.safetensors" \
    "${TRIPOSPLAT_CKPT_DIR}/background_removal/birefnet.safetensors"
}

triposplat_models_ready() {
  local file
  while IFS= read -r file; do
    [[ -f "${file}" ]] || return 1
  done < <(triposplat_required_model_files)
}

triposplat_sync_module_source() {
  local source_root
  local install_root
  source_root="$(cd "${MODULE_ROOT}" && pwd)"
  mkdir -p "${TRIPOSPLAT_INSTALL_ROOT}"
  install_root="$(cd "${TRIPOSPLAT_INSTALL_ROOT}" && pwd)"
  if [[ "${source_root}" == "${install_root}" ]]; then
    return 0
  fi

  echo "Syncing TripoSplat module source into ${TRIPOSPLAT_INSTALL_ROOT}"
  tar \
    --exclude='.git' \
    --exclude='.venv' \
    --exclude='.cache' \
    --exclude='.nymph-module-version' \
    --exclude='ckpts' \
    --exclude='gradio_outputs' \
    --exclude='logs' \
    --exclude='outputs' \
    -cf - -C "${MODULE_ROOT}" . | tar -xf - -C "${TRIPOSPLAT_INSTALL_ROOT}"
}
