# Motion lab: what this comparison does and does not show

**Historical report:** the implementation/settings below predate the textured, matched-footprint, three-pane coverage experiment. See [current controls and limitations](imported-assets.md). The old JSON is historical data, not results for the current renderer. Current imported samples have no colour noise; the lab uses shared pixel squares instead of the native reconstruction below.

Open **Motion lab →** from the lighthouse, or run Godot with:

```powershell
godot --path . comparison.tscn
```

The two panes use the exact same procedural triangle mesh: an astrolabe with thin torus rings, small beads, a stepped base, and an asymmetric rear fin. Both have the same 320×270 perspective camera and simple world-space diffuse lighting. Shadows, fog, temporal antialiasing and water are excluded from this experiment.

## Left: fixed-probe core adaptation

This is an original, deliberately limited implementation of the sampling principle in [Dylan Ebert's Texel Splatting paper](https://arxiv.org/html/2603.14587v1). The [author's complete renderer](https://github.com/dylanebert/texel-splatting) is separate.

The C++ implementation traces first-hit rays through cubemap texel centres into a triangle BVH. This replaces rasterized cubemap capture. It reconstructs face-aligned world-space quads at a shared Chebyshev depth, with fixed 3% overlap. The probe remains stationary while the object moves; object motion triggers a fresh capture. Static captures are cached. The eye-probe option moves this single probe with the camera.

It does **not** reproduce the paper's multi-probe combination, previous/grid probe blending, disocclusion filling, adaptive quad expansion, posterization, outlines, or GPU pipeline. Eye probe instead is a replacement, not a multi-probe fallback. Thus visible holes demonstrate the limitation of a single fixed probe, not the final output quality of the full published renderer. CPU capture timing must not be used to compare GPU method performance.

## Right: persistent object-space voxels

The same triangles are sampled once into the existing sparse octree, including back surfaces. Rigid object transforms move the existing hierarchy without voxelizing it again. Each selected voxel has one filtered normal, colour and position. The renderer retains its small procedural colour variation and bounded representative positions. Samples outside the fixed 38.4-unit root bounds would be omitted; this asset fits.

Probe texel resolution and voxel footprint are adjustable independently. The defaults produce broadly comparable visible detail, not equal sample counts, memory costs, or reconstruction kernels. The probe stores visible quads; the octree retains surfaces around the entire object. Cubes and quads have intrinsically different silhouettes.

## Cases and controls

Select object rotation, object translation, camera orbit/reveal, parallel camera translation, camera look rotation, zoom, or threshold jitter. Pause and scrub the timeline to hold an identical pose in both panes. The speed selector includes quarter-speed playback.

Toggle hysteresis or freeze the voxel cut to isolate LOD effects. Switch the left pane to the original triangle reference to inspect missing or widened geometry. The zoom spans 6–100 units, a 16.7× range, **not several orders of magnitude**. Only rigid animation is tested; there is no skinning/deformation test.

## Recorded results

[Raw report](motion-report.json), produced with 120 deterministic poses per case, a 256²-per-face probe, and a 2.7-pixel voxel target:

| Case | Observed voxel result |
| --- | --- |
| Object rotation / translation | All 14,583 source leaves retained; no hierarchy cut changes at these distances |
| Camera orbit / translation / look | No hierarchy cut changes at these distances |
| Hidden-surface reveal | Rear fin and back surfaces exist in the voxel representation; the single fixed-probe reconstruction has substantial holes |
| Zoom | Selected count ranges from 14,583 to 269; average cut churn 6.89%, peak 95.07% |
| Threshold jitter, hysteresis on | 0% cut churn in this tested trajectory |
| Threshold jitter, hysteresis off | Average cut churn 2.06%, peak 3.43% |

Every sampled cut passed the invariant that each source leaf has exactly one selected ancestor or is itself selected. The source leaf count remains unchanged under motion.

**These are not shimmer scores.** Voxel cut churn is one minus Jaccard similarity of selected node IDs on adjacent poses. Probe slot reassignment counts changes in the first-hit triangle ID (including appearance/disappearance) per visible cubemap slot. That counter depends on source tessellation, misses movement within the same triangle, and cannot be compared numerically to voxel churn. Neither measures image-space error or perceptual stability.

The zero-churn rigid-motion results occur at leaf resolution, so they do not establish stability during simultaneous motion and LOD transitions. Pixel coverage and depth ordering can still change even with identical node IDs. Hysteresis deliberately retains more detail in the jitter case, and its result depends on preceding traversal history.

The zoom result deserves attention: transitions can replace much of a small distant representation in one step. Stable source samples do not remove this issue. The lab supports further inspection; it is not proof that the technique is shimmer-free or superior to Texel Splatting.

## Reproduce

```powershell
godot --path . comparison.tscn -- --lab-test
godot --path . comparison.tscn -- --report=C:/absolute/path/report.json
godot --path . comparison.tscn -- --capture=C:/absolute/path/reveal.png --case=2 --time=3.14
godot --path . comparison.tscn -- --record=C:/absolute/path/frames
```

The recorder generates 96 frames each of object rotation, reveal orbit and zoom. It pauses simulation at each deterministic pose before capturing. Playback frame rate is chosen separately; it is not a recording of achieved interactive fps.
