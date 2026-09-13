# Textured assets and coverage experiment

Three synchronized 320×270 panes show single-probe texel samples (or reference triangles), baseline object-space samples, and the **same voxel buffer/cut** with coverage reconstruction. Apophenia meshes and ten exported textures remain in ignored `local_assets/`; Unreal source assets are never saved.

## Texture transfer

The exporter resolves actual section material slots and direct Base Color texture connections, preserving UV0. Reference triangles and both C++ samplers use the same linearized images, bilinear repeating UVs and mip zero. Probe hits interpolate UVs; voxel samples store texture colour and parents average leaf colours in linear space. Imported colour noise is disabled. Leaf colours retain the first sample entering each cell, not an area integral.

This is opaque base colour, not UE shader baking: no glass, opacity masks, normal maps, roughness or emissive transfer. Unsupported base-colour graphs are rejected rather than guessed. Assets are Y-up, base-centred and normalized to 5.5 units on their longest axis.

## Matched footprints

Shared px controls identical continuous screen-space square widths for texel and baseline voxel samples, at every depth/orientation. All panes have equal internal and displayed dimensions. Raster coverage can still differ at subpixel positions. Probe resolution controls density, not square width; equal size does not imply equal sample counts or costs.

This controlled reconstruction replaces native cubemap-face quads and voxel cubes with screen-facing squares. It is not the full published Texel Splatting renderer. Single-probe holes do not establish limitations of its full multi-probe implementation.

## Coverage

Triangle area is distributed evenly over its barycentric sample lattice, including repeat samples in occupied cells. Areas accumulate up the hierarchy independently of baseline occupancy/colour/normal data. Coverage is `clamp(area * max(abs(normal)) / cell_width², 0, 1)`.

The third pane shares exactly the baseline buffer, cut and transforms. Continuous mode renders width `shared_px * sqrt(coverage)`. Quantized mode first rounds coverage to 0, ¼, ½, ¾ or 1. Diagnostic mode shows raw coverage in grayscale. There is no alpha blending, animated dithering or stochastic discard.

This is an area estimate, not exact clipping or a union mask. Lattice boundaries introduce error; overlapping sheets can saturate coverage. Quantization can discard features or jump at LOD transitions. Shrinking squares cannot preserve wire direction or multiple surfaces. It may reduce dilation but can introduce holes. Surface-plane reconstruction is not implemented yet.

Earlier thin-feature LOD heuristics, Thin px, adjustable dilation and density UI are removed. Source depth is fixed at 10. Lighthouse rendering is unchanged. Stable sample IDs do not prove shimmer-free images or stable LOD appearance.

## Run and test

Run `godot --path . comparison.tscn`. Choose an asset, pause/scrub, test orbit and zoom, toggle Triangle reference or Lighting, and switch coverage modes.

**Canvas resolution** scales all three render canvases together from 0.5× (160×135) to 4× (1280×1080), starting at 320×270. Higher values produce finer displayed pixels without changing the pane size or camera framing. Shared px remains measured in internal canvas pixels, so its displayed footprint becomes smaller as canvas resolution increases. Higher resolution also requests finer voxel LOD and costs more GPU work. Probe capture density remains independently controlled by Probe resolution.

```powershell
godot --path . comparison.tscn -- --asset-test
godot --path . comparison.tscn -- --lab-test
godot --path . --script tools/test_pixel_footprint.gd
godot --path . comparison.tscn -- --canvas-test
```

Checks cover UV/material presence, colour variation, finite fractional coverage, shared buffers, synchronized cameras/transforms, complete hierarchy cuts over 21 poses, and GPU square area across depths/sizes. These are regression checks, not perceptual stability measurements.

For more assets set `VOXEL_EXPORT_DIRECTORY` to `local_assets` and `VOXEL_EXPORT_ASSETS` to semicolon-separated UE mesh paths. Run `tools/export_static_meshes.py` through Unreal's Python commandlet with PythonScriptPlugin and ProceduralMeshComponent enabled. The local manifest is replaced. These raw inputs are for development, not a packaged game export.
