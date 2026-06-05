# TripoSplat Nymph Module Handoff

Last updated: 2026-06-05

## North Star

Build `triposplat` as the NymphsCore dev-mode module for raw single-image
Gaussian splat generation.

The target is:

```text
source image
  -> TripoSplat pipeline
  -> .ply / .splat outputs under NymphsData
  -> SparkJS preview in Manager
```

This module is not a mesh exporter. Do not advertise GLB, OBJ, textured mesh, or
game-mesh output until a later conversion stage is implemented and tested.

## Repo Map

```text
nymphnerds/TripoSplat
  Nymphs TripoSplat fork and module source.
  Current pushed module commit: 4a667e9
  Current module version: 0.1.1

nymphnerds/nymphs-registry
  Dev registry entry for TripoSplat.
  Current pushed registry commit: 3957a8d
  Current dev registry version: 22

NymphsCore
  Manager shell, module install/update flow, and UI standards.
  The TripoSplat module is dev/experimental and not part of the Superhive v1
  release path.
```

## Current Decisions

- TripoSplat stays in the dev registry.
- TripoSplat is not essential to the Superhive / Blender addon v1 release.
- Superhive release docs, addon panels, tutorial videos, and listing copy should
  not depend on TripoSplat.
- The module installs from `https://github.com/nymphnerds/TripoSplat.git`.
- The Manager UI is Nymphs-native HTML, not upstream Gradio.
- Upstream Gradio remains reference/debug only.
- The real module surface is image in, `.ply` / `.splat` out, splat preview.
- There is no Pixal3D-style warmup flow in this module.
- The backend may load the pipeline on first generation, but that is not exposed
  as a separate user action.
- Mesh conversion is a research track only.
- Module install/update scripts own installed `nymph.json` and
  `.nymph-module-version`.
- Do not manually edit installed module files, markers, manifests, cached
  manifests, or runtime state.

## Superhive Boundary

This handoff owns the TripoSplat dev track. The Superhive release checklist
should not carry TripoSplat implementation tasks.

For Superhive v1:

- Do not add TripoSplat as a Blender addon backend.
- Do not add TripoSplat service metadata to the addon.
- Do not present TripoSplat as a public release feature.
- Do not include TripoSplat in first-run videos or the main public 3D backend
  story.
- Do not describe TripoSplat as a GLB or game-mesh backend.

TripoSplat can be promoted later only after the raw module is proven through
Manager and a separate release plan defines what Blender support actually means.

## Pushed State

Raw TripoSplat manifest:

```text
https://raw.githubusercontent.com/nymphnerds/TripoSplat/main/nymph.json
```

Verified raw manifest:

```text
id=triposplat
version=0.1.1
hash=4fa1ce018da1c60e95d26acf5310f2bdac6ea9ef580c006b4eed7a3920919ee5
```

Dev registry entry:

```text
https://raw.githubusercontent.com/nymphnerds/nymphs-registry/main/nymphs-dev.json
registry_version=22
manifest_version=0.1.1
manifest_hash=4fa1ce018da1c60e95d26acf5310f2bdac6ea9ef580c006b4eed7a3920919ee5
```

## Module Surface

Manager actions:

```text
Install / Update
Start / Stop / Status / Logs
Fetch Models
Open UI
Smoke Test
Open Weights
Open Outputs
Uninstall
```

Manager UI:

```text
left rail:
  source image picker/drop zone
  seed/output format
  gaussian count
  generation parameters
  model/output status
  .ply / .splat download buttons

right stage:
  SparkJS splat preview
  recent output browser strip
  always-visible generation progress strip
```

Supported outputs:

```text
.ply
.splat
```

Explicitly unsupported in this module version:

```text
.glb
.obj
textured mesh
game mesh
collision/proxy mesh
Blender import helper
```

## Proven Source State

Source-side checks completed:

```text
python3 -m json.tool nymph.json
bash -n scripts/triposplat_fetch_models.sh
Python compile check for scripts/api_server_triposplat.py
git diff --check
raw GitHub nymph.json hash verification
raw dev registry verification
```

The TripoSplat source repo was clean after push.

The dev registry source repo was clean after push.

## Fetch Models Contract

`scripts/triposplat_fetch_models.sh` follows the module guide output shape.

Expected high-level log shape:

```text
model_fetch_plan=1 required TripoSplat checkpoint bundle
MODEL FETCH STARTED: step=1/1 repo=VAST-AI/TripoSplat
MODEL FETCH STATUS: step=1/1 repo=VAST-AI/TripoSplat status=downloading this_repo_cache=... active_download_files=...
MODEL FETCH COMPLETE: step=1/1 repo=VAST-AI/TripoSplat
models_ready=true
```

The fetch script uses a module-owned single-flight lock:

```text
$HOME/NymphsData/config/triposplat/fetch_models.lock
```

If a fetch is already running, it exits cleanly with:

```text
MODEL FETCH STATUS: status=running waiting_on=existing_fetch
```

Model files live under:

```text
$HOME/NymphsData/models/triposplat/ckpts
```

Required files:

```text
diffusion_models/triposplat_fp16.safetensors
vae/triposplat_vae_decoder_fp16.safetensors
clip_vision/dino_v3_vit_h.safetensors
vae/flux2-vae.safetensors
background_removal/birefnet.safetensors
```

## Testing Path

Use the Manager/dev registry flow. Do not manually sync source files into the
managed/runtime/test WSL.

1. Enable dev modules in Manager.
2. Confirm TripoSplat appears from the dev registry only.
3. Install or Update TripoSplat through Manager.
4. Run `Fetch Models`.
5. Confirm the Manager details pane shows compact model download progress:

```text
Model download: downloading
This repo cache: ...
Active downloads: ...
```

6. Start the module.
7. Open UI.
8. Pick an image with `Pick Image`.
9. Confirm the source preview appears and `Generate Splat` enables.
10. Generate `PLY + SPLAT`.
11. Confirm the progress strip moves through loading/preparing/sampling/export.
12. Confirm output files appear under:

```text
$HOME/NymphsData/outputs/triposplat/<run-id>/
```

13. Confirm the output strip lists the run.
14. Confirm the SparkJS preview loads a `.ply` or `.splat`.
15. Confirm `.ply` and `.splat` download buttons are enabled only when those
    files exist.

## Current Risk

The source module and dev registry are pushed and verified. The next required
step is a managed WSL end-user test through Manager.

Do not claim the module is production-ready until that runtime pass proves:

- model fetch completes on the managed WSL image,
- first generation loads the pipeline without missing dependency errors,
- the output files are valid,
- SparkJS preview can load the generated splat in Manager WebView2,
- progress strips behave correctly while the pipeline is loading and sampling.

## Known Boundaries

- First generation may spend time loading models. This is represented as normal
  generation progress, not a separate warmup action.
- TripoSplat output quality and preview orientation need hands-on testing with
  real generated splats.
- `.splat` preview support depends on SparkJS accepting the exported file shape.
  The UI prefers `.ply` when both are present.
- The module currently uses CUDA 13 / PyTorch cu130 direction from the common
  script, matching the newer Nymphs 3D module runtime direction.
- Blender's native or addon-based Gaussian splat support is not the same thing
  as GLB import or game-ready mesh generation.
- SparkJS preview solves Manager viewing only. Blender integration needs its own
  import/display strategy if it is ever promoted.

## Mesh Conversion Track

Mesh conversion is not part of the raw TripoSplat module.

Current rule:

```text
no proven converter -> no GLB / OBJ / game-mesh claim
```

Research lives in:

```text
docs/TRIPOSPLAT_SPLAT_TO_MESH_RESEARCH.md
```

Current direction:

- Keep SparkJS as the Manager preview path for raw `.ply` / `.splat`.
- Treat splat-to-mesh as a later Nymphs-specific stage, not a TripoSplat
  generation feature.
- Prefer an experimental Manager conversion action only after it is tested
  against real TripoSplat single-image outputs.
- Keep Blender-side helpers separate from managed WSL conversion unless the
  dependency story is proven.
- Use honest output labels such as "rough mesh" or "dense point cloud" until
  quality is proven.

Research candidates:

```text
3DGS-to-PC
MeshSplatting
SuGaR
Gaussian Opacity Fields / GOF
2D Gaussian Splatting
KIRI 3DGS Render Blender addon
GSOPs
fVDB Reality Capture
```

The current best first experiment is `3DGS-to-PC` because it directly accepts
`.ply` / `.splat` and can produce a mesh through Open3D. It still needs runtime,
quality, color, and export-format validation before it becomes a module action.

## Next Work

- Run the managed WSL install/update path from the dev registry.
- Watch `Fetch Models` in Manager and verify the compact progress display.
- Run a real generation from a simple source image.
- Check output browser strip behavior after one and multiple runs.
- Check SparkJS preview for `.ply` and `.splat` files.
- If preview fails for `.splat`, keep `.ply` preview as the first supported
  Manager preview path and document `.splat` as output/download-only until fixed.
- Keep all mesh-conversion experiments documented in the research note until a
  converter is proven.
- Add screenshots or notes from the first successful runtime pass to this doc.
