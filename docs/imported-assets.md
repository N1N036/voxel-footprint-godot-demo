# Textured imported assets

The motion lab compares synchronized single-probe texel samples (or original triangles) with persistent object-space samples. Apophenia meshes and exported textures stay in ignored `local_assets/`; Unreal source assets are never saved or committed.

## Texture transfer

The read-only exporter resolves actual material slots and direct Base Color texture connections, preserving UV0. Triangle reference, probe samples and voxel samples use the same linearized image, bilinear repeating UVs and mip zero. Probe hits interpolate triangle UVs; voxel samples store UV colour when the hierarchy is built, and parents average leaf colours in linear space. Imported samples have no procedural colour noise.

This is opaque base colour, not Unreal material baking: glass, opacity masks, normal maps, roughness and emissive are excluded. Unsupported base-colour graphs are rejected rather than guessed. Assets are converted to Y-up, base-centred and normalized to 5.5 units on the longest axis.

## Matched footprints and canvas resolution

Shared px controls identical continuous screen-space square widths for the texel and object-space sample renderers, independent of depth and orientation. It isolates sampling differences; it does not make sample density, memory use or performance equivalent. Probe resolution remains a density setting.

Canvas resolution scales both render canvases together from 0.5× (160×135) to 4× (1280×1080), starting at 320×270. Shared px is measured in internal canvas pixels, so higher canvas resolution produces finer displayed pixels and requests finer voxel LOD. It costs more GPU work. The optional native mode restores face-aligned probe quads and voxel cubes, whose projected sizes are intentionally not matched.

The earlier fractional coverage / area-scaled reconstruction experiment, thin-feature LOD heuristics and adjustable dilation are removed. The source sampling depth is fixed at 10. Stable sample IDs alone do not prove stable images or LOD appearance.

## Run and test

Run `godot --path . comparison.tscn`; select an asset, pause/scrub, test orbit and zoom, and toggle Triangle reference or Lighting.

```powershell
godot --path . comparison.tscn -- --asset-test
godot --path . comparison.tscn -- --lab-test
godot --path . --script tools/test_pixel_footprint.gd
godot --path . comparison.tscn -- --canvas-test
```

Tests cover UV/material presence, colour variation, synchronized camera/transforms, hierarchy cuts, canvas sizing, and equal GPU square area across depths and sizes. They are regression checks, not perceptual stability measurements.

To export more meshes, set `VOXEL_EXPORT_DIRECTORY` to `local_assets` and `VOXEL_EXPORT_ASSETS` to semicolon-separated Unreal mesh paths. Run `tools/export_static_meshes.py` through Unreal's Python commandlet with PythonScriptPlugin and ProceduralMeshComponent enabled. It replaces the local manifest; those raw inputs are development-only.
