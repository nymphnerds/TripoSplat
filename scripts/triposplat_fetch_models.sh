#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_triposplat_common.sh"

triposplat_ensure_data_dirs
if [[ ! -x "$(triposplat_python)" ]]; then
  echo "TripoSplat runtime is missing. Run Install or Repair before Fetch Models." >&2
  exit 1
fi

fetch_lock="${TRIPOSPLAT_CONFIG_DIR}/fetch_models.lock"
if ! mkdir "${fetch_lock}" 2>/dev/null; then
  echo "MODEL FETCH STATUS: status=running waiting_on=existing_fetch"
  exit 0
fi
trap 'rmdir "${fetch_lock}" 2>/dev/null || true' EXIT

"$(triposplat_python)" - <<'PY'
import os
import threading
import time
from pathlib import Path

from huggingface_hub import snapshot_download

repo_id = os.environ.get("TRIPOSPLAT_MODEL_REPO", "VAST-AI/TripoSplat")
target = Path(os.environ["TRIPOSPLAT_CKPT_DIR"])
hf_cache = Path(os.environ.get("HF_HUB_CACHE", ""))
token = os.environ.get("NYMPHS3D_HF_TOKEN") or os.environ.get("HF_TOKEN") or None
target.mkdir(parents=True, exist_ok=True)
stop = threading.Event()


def dir_size(path: Path) -> int:
    if not path.exists():
        return 0
    total = 0
    for item in path.rglob("*"):
        try:
            if item.is_file():
                total += item.stat().st_size
        except OSError:
            pass
    return total


def format_bytes(value: int) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    size = float(value)
    for unit in units:
        if size < 1024 or unit == units[-1]:
            return f"{size:.2f} {unit}" if unit != "B" else f"{int(size)} B"
        size /= 1024
    return f"{value} B"


def active_download_files(*roots: Path) -> int:
    names = (".incomplete", ".lock", ".tmp")
    count = 0
    seen: set[Path] = set()
    for root in roots:
        if not root or not root.exists():
            continue
        for item in root.rglob("*"):
            try:
                resolved = item.resolve()
            except OSError:
                resolved = item
            if resolved in seen:
                continue
            seen.add(resolved)
            if item.is_file() and (item.name.endswith(names) or ".incomplete" in item.name):
                count += 1
    return count


def print_status(status: str = "downloading") -> None:
    print(
        "MODEL FETCH STATUS: "
        f"step=1/1 repo={repo_id} status={status} "
        f"this_repo_cache={format_bytes(dir_size(target))} "
        f"active_download_files={active_download_files(target, hf_cache)}",
        flush=True,
    )


def reporter() -> None:
    print_status()
    while not stop.wait(8):
        print_status()


print("model_fetch_plan=1 required TripoSplat checkpoint bundle", flush=True)
print(f"MODEL FETCH STARTED: step=1/1 repo={repo_id}", flush=True)
thread = threading.Thread(target=reporter, daemon=True)
thread.start()
try:
    for attempt in range(1, 4):
        try:
            snapshot_download(
                repo_id=repo_id,
                local_dir=str(target),
                local_dir_use_symlinks=False,
                token=token,
            )
            break
        except Exception:
            if attempt >= 3:
                raise
            print(
                "MODEL FETCH STATUS: "
                f"step 1/1 {repo_id} download was interrupted. "
                f"Retrying attempt {attempt + 1}/3 using the existing cache.",
                flush=True,
            )
            time.sleep(5)
finally:
    stop.set()
    thread.join(timeout=1)

print_status("complete")
print(f"MODEL FETCH COMPLETE: step=1/1 repo={repo_id}", flush=True)
PY

if triposplat_models_ready; then
  echo "models_ready=true"
else
  echo "models_ready=false"
  echo "Missing required TripoSplat files:" >&2
  while IFS= read -r file; do
    [[ -f "${file}" ]] || echo "missing=${file}" >&2
  done < <(triposplat_required_model_files)
  exit 1
fi
