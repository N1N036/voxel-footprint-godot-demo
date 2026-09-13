"""Read-only Unreal editor exporter. Set VOXEL_EXPORT_DIRECTORY and
VOXEL_EXPORT_ASSETS (semicolon-separated /Game/... paths). Enable Unreal's
PythonScriptPlugin and ProceduralMeshComponent on the command line.
"""
import json
import os
from pathlib import Path
import unreal

out = Path(os.environ["VOXEL_EXPORT_DIRECTORY"]).resolve()
out.mkdir(parents=True, exist_ok=True)
paths = [p.strip() for p in os.environ["VOXEL_EXPORT_ASSETS"].split(";") if p.strip()]
manifest = []
for path in paths:
    mesh = unreal.load_asset(path)
    if not isinstance(mesh, unreal.StaticMesh):
        raise RuntimeError("Not a static mesh: " + path)
    name = mesh.get_name()
    sections = []
    for index in range(mesh.get_num_sections(0)):
        vertices, triangles, normals, _, _ = unreal.ProceduralMeshLibrary.get_section_from_static_mesh(mesh, 0, index)
        sections.append({
            "positions": [[v.x, v.y, v.z] for v in vertices],
            "normals": [[n.x, n.y, n.z] for n in normals],
            "indices": list(triangles),
            "material_slot": index,
        })
    if not any(section["indices"] for section in sections):
        raise RuntimeError("No LOD0 triangles: " + path)
    filename = name + ".json"
    (out / filename).write_text(json.dumps({
        "name": name, "source": path, "units": "Unreal centimeters",
        "lod": 0, "sections": sections,
    }), encoding="utf-8")
    manifest.append({"name": name, "file": filename, "source": path})
(out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
unreal.log("Exported %d static meshes to %s" % (len(manifest), out))
