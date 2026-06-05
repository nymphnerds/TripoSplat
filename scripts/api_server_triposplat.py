#!/usr/bin/env python3
"""Nymphs TripoSplat API and Manager UI server."""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import mimetypes
import os
import sys
import threading
import time
from pathlib import Path
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

APP = FastAPI(title="TripoSplat Nymph API")
NYMPH_UI_PATH = REPO_ROOT / "nymph_triposplat.html"
ASSETS_ROOT = REPO_ROOT / "assets"
APP.mount("/assets", StaticFiles(directory=str(ASSETS_ROOT)), name="assets")

PIPELINE_LOCK = threading.Lock()
INFERENCE_LOCK = threading.Lock()
PIPELINE: Any | None = None
ACTIVE_TASK: dict[str, Any] = {
    "status": "idle",
    "stage": "idle",
    "detail": "Idle",
    "progress_current": None,
    "progress_total": None,
    "progress_percent": 0,
    "message": "",
}
TASK_LOCK = threading.Lock()


def _set_task(**updates: Any) -> None:
    with TASK_LOCK:
        ACTIVE_TASK.update(updates)


def _task_snapshot() -> dict[str, Any]:
    with TASK_LOCK:
        return dict(ACTIVE_TASK)


def _as_int(value: Any, default: int) -> int:
    try:
        if value in {"", None}:
            return default
        return int(value)
    except Exception:
        return default


def _as_float(value: Any, default: float) -> float:
    try:
        if value in {"", None}:
            return default
        return float(value)
    except Exception:
        return default


def _decode_image_payload(raw: str) -> bytes:
    if not raw:
        raise HTTPException(status_code=400, detail="Missing image payload.")
    if "," in raw and raw.split(",", 1)[0].lower().startswith("data:"):
        raw = raw.split(",", 1)[1]
    try:
        return base64.b64decode(raw, validate=False)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid base64 image payload: {exc}") from exc


def _ckpt_dir() -> Path:
    return Path(os.environ.get("TRIPOSPLAT_CKPT_DIR") or Path.home() / "NymphsData" / "models" / "triposplat" / "ckpts")


def _output_dir() -> Path:
    return Path(os.environ.get("TRIPOSPLAT_OUTPUT_DIR") or Path.home() / "NymphsData" / "outputs" / "triposplat")


def _required_paths() -> dict[str, Path]:
    ckpt_dir = _ckpt_dir()
    return {
        "ckpt": ckpt_dir / "diffusion_models" / "triposplat_fp16.safetensors",
        "decoder": ckpt_dir / "vae" / "triposplat_vae_decoder_fp16.safetensors",
        "dinov3": ckpt_dir / "clip_vision" / "dino_v3_vit_h.safetensors",
        "flux2_vae": ckpt_dir / "vae" / "flux2-vae.safetensors",
        "rmbg": ckpt_dir / "background_removal" / "birefnet.safetensors",
    }


def _models_ready() -> bool:
    return all(path.is_file() for path in _required_paths().values())


def _missing_models() -> list[str]:
    return [str(path) for path in _required_paths().values() if not path.is_file()]


def _get_pipeline() -> Any:
    global PIPELINE
    if PIPELINE is not None:
        return PIPELINE
    with PIPELINE_LOCK:
        if PIPELINE is not None:
            return PIPELINE
        if not _models_ready():
            raise HTTPException(status_code=503, detail={"message": "TripoSplat model files are missing.", "missing": _missing_models()})
        _set_task(status="processing", stage="loading", detail="Loading TripoSplat models", progress_percent=12)
        from triposplat import TripoSplatPipeline

        paths = _required_paths()
        device = os.environ.get("TRIPOSPLAT_DEVICE", "cuda")
        PIPELINE = TripoSplatPipeline(
            ckpt_path=str(paths["ckpt"]),
            decoder_path=str(paths["decoder"]),
            dinov3_path=str(paths["dinov3"]),
            flux2_vae_encoder_path=str(paths["flux2_vae"]),
            rmbg_path=str(paths["rmbg"]),
            device=device,
        )
        _set_task(status="idle", stage="ready", detail="TripoSplat models loaded", progress_percent=0)
        return PIPELINE


def _safe_output_path(relative_path: str) -> Path:
    root = _output_dir().resolve()
    candidate = (root / relative_path).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Forbidden") from exc
    if not candidate.is_file():
        raise HTTPException(status_code=404, detail="Not found")
    return candidate


def _file_record(path: Path) -> dict[str, Any]:
    root = _output_dir().resolve()
    rel = path.resolve().relative_to(root).as_posix()
    return {
        "name": path.name,
        "relative_path": rel,
        "url": f"/outputs/{rel}",
        "bytes": path.stat().st_size,
        "modified": path.stat().st_mtime,
        "kind": path.suffix.lower().lstrip("."),
    }


@APP.get("/", response_class=HTMLResponse)
@APP.get("/nymph", response_class=HTMLResponse)
def nymph_ui() -> HTMLResponse:
    return HTMLResponse(NYMPH_UI_PATH.read_text(encoding="utf-8"))


@APP.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ok", "backend": "TripoSplat"}


@APP.get("/server_info")
def server_info() -> dict[str, Any]:
    return {
        "status": "ready",
        "backend": "TripoSplat",
        "output_formats": ["ply", "splat"],
        "mesh_formats": [],
        "models_ready": _models_ready(),
        "missing_models": _missing_models(),
        "ckpt_dir": str(_ckpt_dir()),
        "outputs_root": str(_output_dir()),
        "device": os.environ.get("TRIPOSPLAT_DEVICE", "cuda"),
        "pipeline_loaded": PIPELINE is not None,
        "runtime_distro": os.environ.get("NYMPHS3D_WSL_DISTRO", ""),
        "runtime_user": os.environ.get("NYMPHS3D_WSL_USER", ""),
        "hf_home": os.environ.get("HF_HOME", ""),
        "hf_cache": os.environ.get("HF_HUB_CACHE", ""),
    }


@APP.get("/active_task")
@APP.get("/progress")
def active_task() -> dict[str, Any]:
    return _task_snapshot()


@APP.get("/outputs/{relative_path:path}")
def output_file(relative_path: str) -> FileResponse:
    path = _safe_output_path(relative_path)
    media_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
    if path.suffix.lower() == ".ply":
        media_type = "application/octet-stream"
    if path.suffix.lower() == ".splat":
        media_type = "application/octet-stream"
    return FileResponse(str(path), media_type=media_type, filename=path.name)


@APP.get("/api/outputs")
def list_outputs() -> dict[str, Any]:
    root = _output_dir()
    root.mkdir(parents=True, exist_ok=True)
    files = [p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in {".ply", ".splat", ".webp", ".json"}]
    files.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return {"outputs": [_file_record(path) for path in files[:80]]}


@APP.post("/api/warmup")
async def warmup() -> dict[str, Any]:
    await asyncio.to_thread(_get_pipeline)
    return {"ok": True, "detail": "TripoSplat models loaded."}


@APP.post("/api/generate")
async def generate(request: Request) -> JSONResponse:
    payload = await request.json()
    if not INFERENCE_LOCK.acquire(blocking=False):
        raise HTTPException(status_code=409, detail="TripoSplat is already processing another request.")

    try:
        image_bytes = _decode_image_payload(str(payload.get("image") or ""))
        seed = _as_int(payload.get("seed"), 42)
        steps = max(1, min(50, _as_int(payload.get("steps"), 20)))
        guidance_scale = max(1.0, min(10.0, _as_float(payload.get("guidance_scale"), 3.0)))
        shift = max(1.0, min(8.0, _as_float(payload.get("shift"), 3.0)))
        erode_radius = max(0, min(6, _as_int(payload.get("erode_radius"), 1)))
        num_gaussians = _as_int(payload.get("num_gaussians"), 262144)
        if num_gaussians not in {32768, 65536, 131072, 262144}:
            num_gaussians = 262144
        output_format = str(payload.get("output_format") or "both").lower()
        if output_format not in {"ply", "splat", "both"}:
            output_format = "both"

        output_dir = _output_dir()
        output_dir.mkdir(parents=True, exist_ok=True)
        run_id = f"triposplat_{int(time.time())}_{uuid4().hex[:8]}"
        run_dir = output_dir / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        input_path = run_dir / "source.png"
        input_path.write_bytes(image_bytes)

        def _progress(step: int, total: int) -> None:
            percent = 25 + (step / max(total, 1)) * 55
            _set_task(
                status="processing",
                stage="sampling",
                detail=f"Sampling Gaussian latent {step}/{total}",
                progress_current=step,
                progress_total=total,
                progress_percent=round(percent, 1),
            )

        def _run_generation() -> dict[str, Any]:
            pipe = _get_pipeline()
            _set_task(status="processing", stage="preparing", detail="Preparing source image", progress_percent=20)
            gaussian, prepared = pipe.run(
                str(input_path),
                seed=seed,
                steps=steps,
                guidance_scale=guidance_scale,
                shift=shift,
                num_gaussians=num_gaussians,
                erode_radius=erode_radius,
                show_progress=False,
                callback=_progress,
            )
            _set_task(status="processing", stage="exporting", detail="Saving splat outputs", progress_percent=88)
            prepared_path = run_dir / "prepared.webp"
            prepared.save(prepared_path)
            outputs: dict[str, Path] = {}
            ply_path = run_dir / "splat.ply"
            gaussian.save_ply(str(ply_path))
            outputs["ply"] = ply_path
            if output_format in {"splat", "both"}:
                splat_path = run_dir / "splat.splat"
                gaussian.save_splat(str(splat_path))
                outputs["splat"] = splat_path
            meta_path = run_dir / "metadata.json"
            meta_path.write_text(
                json.dumps(
                    {
                        "backend": "TripoSplat",
                        "seed": seed,
                        "steps": steps,
                        "guidance_scale": guidance_scale,
                        "shift": shift,
                        "erode_radius": erode_radius,
                        "num_gaussians": num_gaussians,
                        "output_format": output_format,
                        "outputs": {key: path.name for key, path in outputs.items()},
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )
            return {
                "run_id": run_id,
                "num_gaussians": num_gaussians,
                "prepared": _file_record(prepared_path),
                "outputs": {key: _file_record(path) for key, path in outputs.items()},
                "preview": _file_record(ply_path),
                "metadata": _file_record(meta_path),
            }

        result = await asyncio.to_thread(_run_generation)
        _set_task(status="completed", stage="complete", detail="TripoSplat generation complete", progress_percent=100)
        return JSONResponse(result)
    except HTTPException:
        _set_task(status="failed", stage="failed", detail="Request failed", progress_percent=0)
        raise
    except Exception as exc:
        _set_task(status="failed", stage="failed", detail=str(exc), message=str(exc), progress_percent=0)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        INFERENCE_LOCK.release()


def main() -> None:
    parser = argparse.ArgumentParser(description="TripoSplat Nymph API server")
    parser.add_argument("--host", default=os.environ.get("TRIPOSPLAT_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("TRIPOSPLAT_PORT", "7002")))
    args = parser.parse_args()

    _output_dir().mkdir(parents=True, exist_ok=True)
    import uvicorn

    uvicorn.run(APP, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()
