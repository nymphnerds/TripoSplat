#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

triposplat_ensure_data_dirs
if [[ -d "${TRIPOSPLAT_INSTALL_ROOT}/.git" ]]; then
  echo "Updating TripoSplat git checkout."
  git -C "${TRIPOSPLAT_INSTALL_ROOT}" pull --ff-only
else
  triposplat_sync_module_source
fi

if [[ -x "$(triposplat_python)" ]]; then
  "$(triposplat_python)" -m pip install -r "${TRIPOSPLAT_INSTALL_ROOT}/requirements.nymph.txt"
fi

printf '%s\n' "${TRIPOSPLAT_VERSION}" > "${TRIPOSPLAT_INSTALL_ROOT}/.nymph-module-version"
echo "installed_module_version=${TRIPOSPLAT_VERSION}"
echo "install_root=${TRIPOSPLAT_INSTALL_ROOT}"
