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
subsystem = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem) or unreal.StaticMeshEditorSubsystem()
exported_textures = {}

def base_color(material):
    # Deliberately support only a direct texture -> Base Color connection.
    # Do not guess from texture names or silently pretend to bake a UE shader.
    if not isinstance(material, unreal.Material):
        raise RuntimeError('Direct base-colour Material required: ' + str(material))
    node = unreal.MaterialEditingLibrary.get_material_property_input_node(material, unreal.MaterialProperty.MP_BASE_COLOR)
    if not isinstance(node, unreal.MaterialExpressionTextureSample):
        raise RuntimeError('Base Color is not a direct texture: ' + material.get_path_name())
    if node.get_editor_property('const_coordinate') != 0 or any(unreal.MaterialEditingLibrary.get_inputs_for_material_expression(material, node)):
        raise RuntimeError('Only unmodified UV0 supported: ' + material.get_path_name())
    texture = node.get_editor_property('texture')
    path = texture.get_path_name()
    if path not in exported_textures:
        filename = texture.get_name() + '.tga'
        task = unreal.AssetExportTask()
        task.object = texture
        task.filename = str(out / filename)
        task.automated = True
        task.prompt = False
        task.replace_identical = True
        task.exporter = unreal.TextureExporterTGA()
        if not unreal.Exporter.run_asset_export_task(task):
            raise RuntimeError('Texture export failed: ' + path)
        exported_textures[path] = filename
    return {'file': exported_textures[path], 'source': path,
            'srgb': bool(texture.get_editor_property('srgb')),
            'material': material.get_path_name(), 'scope': 'opaque base colour only'}

for path in paths:
    mesh = unreal.load_asset(path)
    if not isinstance(mesh, unreal.StaticMesh):
        raise RuntimeError("Not a static mesh: " + path)
    name = mesh.get_name()
    sections = []
    for index in range(mesh.get_num_sections(0)):
        vertices, triangles, normals, uvs, _ = unreal.ProceduralMeshLibrary.get_section_from_static_mesh(mesh, 0, index)
        material_slot = subsystem.get_lod_material_slot(mesh, 0, index)
        sections.append({
            "positions": [[v.x, v.y, v.z] for v in vertices],
            "normals": [[n.x, n.y, n.z] for n in normals],
            "indices": list(triangles),
            "uvs": [[uv.x, uv.y] for uv in uvs],
            "material_slot": material_slot,
            "base_color": base_color(mesh.get_material(material_slot)),
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
