# TripoSplat Splat-To-Mesh Research

This note tracks possible later conversion paths for TripoSplat Gaussian splat outputs. The TripoSplat Nymph module is currently a dev/experimental module, not part of the Superhive v1 release path. Its first goal is raw `.ply` / `.splat` generation and Spark.js preview.

Do not use this research track to advertise Superhive release features. GLB, OBJ, textured mesh, game-mesh export, and Blender splat import remain unproven until a later implementation and test pass promotes them.

## Summary

| Candidate | License | Existing `.ply` / `.splat` input | Real mesh output | Textured mesh / GLB / OBJ | Dependency weight | NymphsCore managed WSL fit | Single-image TripoSplat fit | Best role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SuGaR | Source-available, non-commercial 3DGS-style license | Starts from a trained Gaussian scene and usually expects COLMAP/camera context; not a simple `.splat` converter | Yes | Mesh extraction plus refinement/export workflows; GLB would need an extra packaging step | Heavy Python/CUDA stack with 3DGS dependencies | Risky for a managed module without a proven wrapper | Weak until we prove a camera/refinement path for single-image splats | Research only for now |
| Gaussian Opacity Fields / GOF | Source-available, non-commercial 3DGS-style license | Uses Gaussian scenes with training/refinement assumptions, not a direct raw `.splat` action | Yes | Mesh extraction is core; textured/export packaging still needs validation | Heavy Python/CUDA/research stack | Risky as a Manager action today | Unproven for single-image TripoSplat outputs | Research only for now |
| 2D Gaussian Splatting | Source-available, non-commercial 3DGS-style license | Training-oriented; not a direct converter for arbitrary TripoSplat `.ply` / `.splat` | Yes, via geometry extraction in its pipeline | Export formats need validation and likely extra tooling | Heavy Python/CUDA/research stack | Risky unless isolated as a separate experimental module | Unproven | Research only for now |
| KIRI 3DGS Render Blender addon | Apache-2.0 | Intended for loading/rendering 3DGS assets in Blender | Not primarily a conversion engine | Blender-side render/import helper, not a complete mesh export solution | Blender addon dependency surface | Better in Blender than managed WSL | Useful for inspection/rendering, not game-mesh conversion | Blender-side helper |
| SparkJS viewer | MIT | Yes, browser viewer for splat assets | No | No | Light browser dependency | Good | Good for previewing raw TripoSplat outputs | Manager preview |
| MeshSplatting | Apache-2.0 | Not a drop-in converter; it is an optimization/reconstruction pipeline with camera/training assumptions | Yes | Claims meshes suitable for standard graphics engines; export format packaging needs hands-on validation | Heavy Python/CUDA stack, tested around Python 3.11 and CUDA 12.6 | Research fit, not a lightweight managed action yet | Unproven for single-image TripoSplat outputs | Research only for now |
| 3DGS-to-PC | Apache-2.0 | Yes, accepts `.ply` or `.splat`; camera transforms/COLMAP improve color quality | Yes, via dense point cloud plus Open3D Poisson reconstruction | Mesh output is `.ply`; GLB/OBJ/texturing would require extra conversion and quality validation | Moderate to heavy; Python plus optional CUDA renderer and Open3D for meshing | Possible as an experimental Manager conversion action after testing | Potentially the most direct candidate, but quality and color from single-image TripoSplat need proof | Experimental Manager action candidate |
| GSOPs | AGPL-3.0, with commercial licensing options mentioned by project | Yes, Houdini plugin supports `.ply`, `.splat`, and `.spz` import | Yes, coarse meshing utilities | DCC-side editing/export workflows; not a direct managed WSL converter | Houdini plugin dependency surface | Poor fit for managed WSL core | Useful for artist inspection/editing, not automatic TripoSplat conversion | Houdini-side helper |
| fVDB Reality Capture | Apache-2.0 | Reality-capture/radiance-field pipeline, not a direct raw TripoSplat converter | Likely through its reconstruction pipeline, but direct splat-to-mesh path needs validation | Export path needs validation | Heavy but production-minded; sensor/camera/data pipeline oriented | Research fit only until direct conversion is proven | Unproven | Research only for now |

## Reddit Thread Notes

Thread: https://www.reddit.com/r/GaussianSplatting/comments/1qx5e03/is_there_a_way_to_convert_gaussiansplat_into_a/

The practical community signal is cautious: converting splats to meshes is possible, but often gives poor close-up geometry. Several replies steer toward photogrammetry when a mesh is the primary requirement, direct splat rendering in Unity/Unreal when visual fidelity is the goal, or proxy/collision meshes when interaction is the real need.

Extra leads from the thread:

- MeshSplatting: https://meshsplatting.github.io/ and https://github.com/meshsplatting/mesh-splatting
- 3DGS-to-PC: https://github.com/Lewis-Stuart-11/3DGS-to-PC
- GSOPs: https://github.com/cgnomads/GSOPs
- fVDB Reality Capture: https://openvdb.github.io/fvdb-core/reality-capture/

## Direction

Use SparkJS now for Manager preview. Keep mesh conversion as a later Nymphs-specific stage, likely a separate action or module after a converter is proven against TripoSplat's single-image `.ply` outputs.

The first conversion experiment should probably be 3DGS-to-PC because it directly accepts `.ply` / `.splat` and can produce a mesh through Open3D. Treat that as an experimental conversion action with honest output labels like "dense point cloud" and "rough mesh," not as game-mesh or GLB support. MeshSplatting is promising but belongs in research until its training/camera assumptions are mapped against TripoSplat outputs.

Do not advertise GLB, OBJ, textured mesh, or game-mesh export from the TripoSplat module until that path is implemented and tested.
