# Local Unreal assets and thin-detail controls

The motion lab discovers `local_assets/manifest.json` and offers its entries in the asset picker. This directory is Git-ignored: project assets and potential third-party licensed content are not redistributed by the public demo.

The current local session contains four Apophenia Cigar Room meshes: chandelier, desk lamp, globe and armchair. They are extracted from LOD0 render data with Unreal's ProceduralMeshLibrary. No source asset is saved or modified. This is not an extraction of Nanite's internal runtime clusters.

The importer changes Unreal's Z-up coordinates to Godot's Y-up coordinates, centres the base, and normalizes the longest dimension to 5.5 scene units. Both views receive the same converted triangles and normals. Material sections receive a neutral palette. Unreal textures, materials, glass, opacity masks and displacement are **not** reproduced. Thin details that exist only in textures cannot be evaluated here.

## Controls

- **Leaf size + Rebuild samples:** 0.075, 0.0375 or 0.01875 normalized scene units. Finer source samples preserve smaller features before LOD selection. Sampling depth is not applied until rebuild (or changing asset).
- **Voxel px:** general projected-cell width target. Lower it to descend further everywhere.
- **Protect thin detail:** uses a stricter target when occupied leaf surface area is sparse relative to a parent cell, or descendant normals strongly disagree. This is a heuristic, not a topology-preservation guarantee.
- **Thin px:** the stricter footprint for those regions. Start at 1 pixel; try 0.5 for small supports.
- **Coverage:** instance width multiplier, from 1.0 to 1.6. It can close sample gaps but thickens outlines and may merge adjacent features.
- **Zoom:** inspects the same transformed mesh in both panes.
- **Triangle reference:** enabled initially for imported assets. Disable to return the left pane to the limited fixed-probe splat adaptation.

Suggested order: compare the triangle reference, choose finer leaves and rebuild, lower Thin px, then cautiously increase coverage to about 1.15–1.25. Lowering a LOD threshold cannot restore geometry already lost during source sampling. Once a feature projects below one display pixel, visibility can still fluctuate without a reconstruction/antialiasing solution.

## Checks

`godot --path . comparison.tscn -- --asset-test` rebuilds every local asset at all three depths, checks complete nonoverlapping hierarchy coverage, verifies that finer grids retain at least as many occupied cells for these meshes, and confirms that feature protection selects at least as many representatives at the same 6-pixel general target.

All 12 combinations passed in this session. At depth 10, chandelier selection increased from 839 to 2,184 representatives with protection; lamp 2,796 to 15,266; globe 2,618 to 12,070; chair 7,536 to 19,587. These are geometry-selection counters, not visual error measurements.

The original motion-report JSON records the older astrolabe settings, not these imported-asset defaults. To reproduce that setup, select asset 0, depth 9, and disable feature protection.

## Export more meshes

`tools/export_static_meshes.py` is a read-only Unreal editor Python exporter driven by `VOXEL_EXPORT_DIRECTORY` and `VOXEL_EXPORT_ASSETS` environment variables. Point the directory at this project's `local_assets`, and list `/Game/...` static-mesh paths separated by semicolons. It replaces the manifest with the selected set. Run it using `UnrealEditor-Cmd.exe <project.uproject> -run=pythonscript -script=<absolute-script-path> -EnablePlugins=PythonScriptPlugin,ProceduralMeshComponent -unattended -nullrhi`.

Restart the motion lab to discover the updated manifest. Keep exported asset data out of a public repository unless redistribution rights are established.
