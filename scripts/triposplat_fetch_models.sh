#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

triposplat_ensure_data_dirs
if [[ ! -x "$(triposplat_python)" ]]; then
  echo "TripoSplat runtime is missing. Run Install or Repair before Fetch Models." >&2
  exit 1
fi

echo "MODEL FETCH STATUS"
echo "module=triposplat"
echo "repo=${TRIPOSPLAT_MODEL_REPO}"
echo "target=${TRIPOSPLAT_CKPT_DIR}"

"$(triposplat_python)" - <<'PY'
import os
from pathlib import Path

from huggingface_hub import snapshot_download

repo_id = os.environ.get("TRIPOSPLAT_MODEL_REPO", "VAST-AI/TripoSplat")
target = Path(os.environ["TRIPOSPLAT_CKPT_DIR"])
token = os.environ.get("NYMPHS3D_HF_TOKEN") or os.environ.get("HF_TOKEN") or None
target.mkdir(parents=True, exist_ok=True)
snapshot_download(
    repo_id=repo_id,
    local_dir=str(target),
    local_dir_use_symlinks=False,
    token=token,
)
print(f"downloaded_repo={repo_id}")
print(f"local_dir={target}")
PY

if triposplat_models_ready; then
  echo "models_ready=true"
  echo "MODEL FETCH COMPLETE"
else
  echo "models_ready=false"
  echo "Missing required TripoSplat files:" >&2
  while IFS= read -r file; do
    [[ -f "${file}" ]] || echo "missing=${file}" >&2
  done < <(triposplat_required_model_files)
  exit 1
fi
