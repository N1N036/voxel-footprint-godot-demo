# Voxel Footprint — Godot C++ demo

A deliberately tiny prototype of the idea in the design notes: select a **single cut through a voxel octree** such that the chosen voxel is roughly 1–2 pixels wide in a low-resolution render target. The result is nearest-neighbour scaled to the window, so the geometric and display pixel vocabularies match.

This is not a Nanite clone. It is a clear, editable starting point for experimenting with the useful part of that family of renderers: screen-space hierarchy selection.

## What it demonstrates

- A static procedural terrain stored as an occupancy octree in C++.
- An internal 320×180 `SubViewport`, enlarged with nearest-neighbour filtering.
- A per-frame hierarchy cut: keep a node when its projected width is at or below `target_pixel_footprint`; otherwise visit its children.
- Parent nodes are real representative voxels, with filtered colour, not arbitrary child picks.

Use left/right arrows to orbit. Use up/down arrows to adjust the footprint from 0.6 to 5 internal pixels. The coarsening transition is intentionally obvious; it is the technique, not a bug.

## Prerequisites

- Godot 4.7 (the project metadata is saved in the current stable format).
- A C++17 compiler and [SCons](https://scons.org/).
- The matching `godot-cpp` bindings (installed as a submodule below).

## Build and run (Windows)

```powershell
git submodule update --init --recursive
scons platform=windows target=template_debug
```

Open `project.godot` in Godot and run it. For a release build, replace `template_debug` with `template_release`.

## The selection rule

`projected_pixels = node_world_width × pixels_per_world_unit / camera_distance`

If `projected_pixels <= target_pixel_footprint`, the node represents its entire subtree; otherwise its children are considered. This gives a coherent hierarchy cut: a parent and one of its descendants are never rendered together.

For an actual game, replace the procedural occupancy test with imported voxel assets, add frustum/node visibility tests before descent, and use a GPU-driven instance or surfel path rather than rebuilding one CPU mesh.
