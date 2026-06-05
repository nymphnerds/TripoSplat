#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

ensure_system_dependencies() {
  local need_apt=0
  for command_name in git curl python3; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
      need_apt=1
    fi
  done
  if ! python3 - <<'PY' >/dev/null 2>&1; then
import ensurepip
import venv
PY
    need_apt=1
  fi
  if [[ "${need_apt}" -eq 0 ]]; then
    return 0
  fi
  if ! command -v sudo >/dev/null 2>&1; then
    echo "Missing required system packages and sudo is unavailable." >&2
    exit 1
  fi
  echo "Installing TripoSplat system dependencies."
  sudo apt update
  sudo apt install -y ca-certificates curl git python3 python3-venv python3-pip
}

ensure_venv() {
  if [[ -x "$(triposplat_python)" ]] && "$(triposplat_python)" -m pip --version >/dev/null 2>&1; then
    return 0
  fi
  rm -rf "${TRIPOSPLAT_VENV_DIR}"
  python3 -m venv "${TRIPOSPLAT_VENV_DIR}"
  "$(triposplat_python)" -m ensurepip --upgrade
  "$(triposplat_python)" -m pip --version
}

install_python_dependencies() {
  "$(triposplat_python)" -m pip install --upgrade pip "setuptools<82" wheel
  "$(triposplat_python)" -m pip install torch==2.11.0 torchvision torchaudio --index-url "${TRIPOSPLAT_TORCH_INDEX_URL}"
  "$(triposplat_python)" -m pip install -r "${TRIPOSPLAT_INSTALL_ROOT}/requirements.nymph.txt"
  "$(triposplat_python)" - <<'PY'
import importlib

for module_name in ("fastapi", "huggingface_hub", "numpy", "PIL", "safetensors", "torch", "torchvision", "tqdm", "uvicorn"):
    importlib.import_module(module_name)

print("TripoSplat Python runtime imports available.")
PY
}

write_install_markers() {
  cp "${TRIPOSPLAT_INSTALL_ROOT}/nymph.json" "${TRIPOSPLAT_INSTALL_ROOT}/nymph.json.tmp"
  mv "${TRIPOSPLAT_INSTALL_ROOT}/nymph.json.tmp" "${TRIPOSPLAT_INSTALL_ROOT}/nymph.json"
  printf '%s\n' "${TRIPOSPLAT_VERSION}" > "${TRIPOSPLAT_INSTALL_ROOT}/.nymph-module-version"
}

ensure_system_dependencies
triposplat_ensure_data_dirs
triposplat_sync_module_source
ensure_venv
install_python_dependencies
write_install_markers

echo "installed_module_version=${TRIPOSPLAT_VERSION}"
echo "install_root=${TRIPOSPLAT_INSTALL_ROOT}"
echo "models_root=${TRIPOSPLAT_CKPT_DIR}"
echo "outputs_root=${TRIPOSPLAT_OUTPUT_DIR}"
