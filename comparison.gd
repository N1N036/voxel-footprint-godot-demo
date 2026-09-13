extends Control

const CASES := ["Object rotation", "Object translation", "Camera orbit / reveal", "Camera translation", "Camera look rotation", "Zoom through LOD", "Threshold jitter"]
var cameras: Array[Camera3D] = []
var views: Array[SubViewport] = []
var roots: Array[Node3D] = []
var source: ArrayMesh
var voxels: VoxelOctreeDemo
var probe: ProbeSplatDemo
var reference: MeshInstance3D
var canvas_scale := 1.0
var canvas_label: Label
var canvas_slider: HSlider
var probe_origin := Vector3(6, 4.5, 10)
var fixed_origin := Vector3(6, 4.5, 10)
var case_index := 0
var playing := true
var time := 0.0
var speed := 1.0
var resolution := 256
var track_probe := false
var show_reference := false
var refresh_probe := true
var previous_transform := Transform3D()
var previous_origin := Vector3.INF
var left_stats: Label
var right_stats: Label
var description: Label
var time_slider: HSlider
var play_button: Button
var case_picker: OptionButton
var capture_path := ""
var capture_frame := 0
var self_test := false
var test_step := 0
var report: Array[String] = []
var peak_churn := 0.0
var sum_churn := 0.0
var churn_frames := 0
var orbit_angle := 0.0
var original_leaves := 0
var report_path := ""
var recording_dir := ""
var experiment_running := false
var captured_this_frame := false
var asset_entries: Array = []
var asset_index := 0
var asset_picker: OptionButton
var asset_note: Label
var sampling_depth := 10
var status_label: Label
var display_zoom := 1.0
var triangle_count := 0
var shared_pixels := 2.0
var matched_pixels := true
var lighting := true
var splat_materials: Array[ShaderMaterial] = []
var texture_cache: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists("res://local_assets/manifest.json"):
		asset_entries = JSON.parse_string(FileAccess.get_file_as_string("res://local_assets/manifest.json"))
	if not asset_entries.is_empty(): asset_index=1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="): asset_index=int(arg.trim_prefix("--asset="))
	source = _load_asset(asset_index)
	_count_triangles()
	_build_ui()
	_build_renderers()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--case="): case_index = int(arg.trim_prefix("--case=")); case_picker.select(case_index)
		if arg.begins_with("--time="): time = float(arg.trim_prefix("--time=")); playing = false
		if arg == "--lab-test": self_test = true; playing = false
		if arg == "--asset-test": playing=false; _asset_test.call_deferred()
		if arg == "--canvas-test": playing=false; _canvas_test.call_deferred()
		if arg.begins_with("--canvas-scale="): _set_canvas_scale(float(arg.trim_prefix("--canvas-scale=")))
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report="); playing=false
		if arg.begins_with("--record="): recording_dir=arg.trim_prefix("--record="); playing=false
	_apply_motion()
	original_leaves = voxels.get_leaf_count()
	asset_note.text=_asset_description()
	if not report_path.is_empty() or not recording_dir.is_empty():
		_experiment.call_deferred()

func _add_shape(tool: SurfaceTool, mesh: PrimitiveMesh, position: Vector3, rotation: Vector3, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rotation)
	for index in indices:
		tool.set_color(color)
		tool.set_normal((basis * normals[index]).normalized())
		tool.add_vertex(basis * vertices[index] + position)

func _asset() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var plinth := CylinderMesh.new()
		plinth.top_radius = 1.3 - i * 0.17
		plinth.bottom_radius = plinth.top_radius + 0.08
		plinth.height = 0.22
		plinth.radial_segments = 48
		_add_shape(tool, plinth, Vector3(0, i*0.22, 0), Vector3.ZERO, Color("#887455"))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.3
	stem.bottom_radius = 0.65
	stem.height = 1.6
	stem.radial_segments = 32
	_add_shape(tool, stem, Vector3(0,1.25,0), Vector3.ZERO, Color("#be9352"))
	var orb := SphereMesh.new()
	orb.radius = 1.10
	orb.height = 2.2
	orb.radial_segments = 48
	orb.rings = 24
	_add_shape(tool, orb, Vector3(0,3,0), Vector3.ZERO, Color("#448d88"))
	for i in range(3):
		var ring := TorusMesh.new()
		ring.inner_radius = 1.58 + i*0.17
		ring.outer_radius = 1.74 + i*0.17
		ring.rings = 64
		ring.ring_segments = 12
		_add_shape(tool, ring, Vector3(0,3,0), Vector3(PI/2, i*PI/3, 0.25), Color("#d6ac63"))
	for i in range(12):
		var a := i*TAU/12
		var bead := SphereMesh.new()
		bead.radius = 0.13 if i % 3 else 0.23
		bead.height = bead.radius*2
		bead.radial_segments = 12
		bead.rings = 6
		_add_shape(tool, bead, Vector3(cos(a)*2.25,3+sin(a)*2.25,0), Vector3.ZERO, Color("#cb7552"))
	# Asymmetric back fin exposes geometry unseen from the initial front probe.
	var fin := BoxMesh.new()
	fin.size = Vector3(0.9,1.25,0.16)
	_add_shape(tool, fin, Vector3(0,3,-1.22), Vector3(0,0,0.25), Color("#cc6045"))
	for i in range(9):
		var tick := BoxMesh.new()
		tick.size = Vector3(0.05,0.4 + float(i%3)*0.1,0.12)
		_add_shape(tool, tick, Vector3(-0.6+i*0.15,0.9,0.6), Vector3.ZERO, Color("#e5c88e"))
	tool.index()
	var mesh:=tool.commit()
	var material:=ShaderMaterial.new()
	material.shader=load("res://lab_reference.gdshader")
	mesh.surface_set_material(0,material)
	return mesh

func _label(text: String, size := 16, color := Color("#c1d2cc")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#10242c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_label("MOTION LAB   /   PERSISTENT SAMPLES", 27, Color("#efd9b2")))
	column.add_child(_label("Same triangle asset · synchronized canvas resolution, camera and light · no TAA, shadows or animated water",14))
	var assets_row := HBoxContainer.new()
	assets_row.add_theme_constant_override("separation",16)
	column.add_child(assets_row)
	assets_row.add_child(_label("ASSET",13,Color("#d5bc8a")))
	asset_picker=OptionButton.new()
	asset_picker.add_item("Procedural astrolabe")
	for entry in asset_entries: asset_picker.add_item(str(entry.name).trim_prefix("SM_"))
	asset_picker.select(asset_index)
	asset_picker.item_selected.connect(_change_asset)
	assets_row.add_child(asset_picker)
	asset_note=_label("",12)
	assets_row.add_child(asset_note)
	var panes := HBoxContainer.new()
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panes.add_theme_constant_override("separation",24)
	column.add_child(panes)
	for i in range(2):
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panes.add_child(panel)
		panel.add_child(_label(["TEXEL SPLATS / REFERENCE","OBJECT-SPACE / BASELINE"][i],15,Color("#d5bc8a")))
		var vp := SubViewport.new()
		vp.size = Vector2i(320,270)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		views.append(vp)
		var image := TextureRect.new()
		image.texture = vp.get_texture()
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(image)
		var stat := _label("",13)
		stat.clip_text=true
		stat.custom_minimum_size.y=44
		panel.add_child(stat)
		if i==0: left_stats = stat
		else: right_stats = stat
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",12)
	column.add_child(controls)
	case_picker = OptionButton.new()
	for c in CASES: case_picker.add_item(c)
	case_picker.item_selected.connect(func(index: int): case_index=index; time=0; peak_churn=0; sum_churn=0; churn_frames=0)
	controls.add_child(case_picker)
	play_button = Button.new()
	play_button.text = "Pause"
	play_button.pressed.connect(func(): playing=not playing)
	controls.add_child(play_button)
	var reset := Button.new()
	reset.text = "Restart"
	reset.pressed.connect(func(): time=0; refresh_probe=true; peak_churn=0; sum_churn=0; churn_frames=0)
	controls.add_child(reset)
	time_slider = HSlider.new()
	time_slider.min_value=0
	time_slider.max_value=TAU
	time_slider.step=0.005
	time_slider.custom_minimum_size.x=220
	time_slider.value_changed.connect(func(value: float): playing=false; time=value)
	controls.add_child(time_slider)
	var slow := OptionButton.new()
	for text in ["1× speed","0.25× slow motion","2× speed"]: slow.add_item(text)
	slow.item_selected.connect(func(index: int): speed=[1.0,0.25,2.0][index])
	controls.add_child(slow)
	var home := Button.new()
	home.text = "Lighthouse"
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://main.tscn"))
	controls.add_child(home)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation",14)
	column.add_child(options)
	var probe_res := OptionButton.new()
	for n in [192,256,384,512]: probe_res.add_item("Probe: %d² / face" % n)
	probe_res.select(1)
	probe_res.item_selected.connect(func(index: int): resolution=[192,256,384,512][index]; refresh_probe=true)
	options.add_child(probe_res)
	var footprint := HSlider.new()
	footprint.min_value=1; footprint.max_value=6; footprint.step=0.25; footprint.value=shared_pixels
	footprint.custom_minimum_size.x=140
	footprint.value_changed.connect(func(value: float): shared_pixels=value; _sync_splat_settings())
	options.add_child(_label("Shared px",13))
	options.add_child(footprint)
	_check(options,"Hysteresis",true,func(value: bool): voxels.set_hysteresis(value))
	_check(options,"Freeze cut",false,func(value: bool): voxels.set_frozen(value))
	_check(options,"Eye probe instead",false,func(value: bool): track_probe=value; refresh_probe=true)
	_check(options,"Triangle reference",false,func(value: bool): show_reference=value; reference.visible=value; probe.visible=not value)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation",12)
	column.add_child(detail_row)
	detail_row.add_child(_label("Matched pixel squares",13))
	_check(detail_row,"Lighting",true,func(value: bool): lighting=value; _sync_lighting())
	detail_row.add_child(_label("Zoom",12))
	var zoom:=HSlider.new()
	zoom.min_value=0.55; zoom.max_value=2.0; zoom.step=0.05; zoom.value=1
	zoom.custom_minimum_size.x=100
	zoom.value_changed.connect(func(value: float): display_zoom=value)
	detail_row.add_child(zoom)
	var canvas_row:=HBoxContainer.new()
	canvas_row.add_theme_constant_override("separation",12)
	column.add_child(canvas_row)
	canvas_label=_label("Canvas resolution: 320 × 270 / view (1×)",13)
	canvas_label.custom_minimum_size.x=340
	canvas_row.add_child(canvas_label)
	canvas_slider=HSlider.new()
	canvas_slider.min_value=0.5; canvas_slider.max_value=4.0
	canvas_slider.step=0.1; canvas_slider.value=canvas_scale
	canvas_slider.custom_minimum_size.x=260
	canvas_slider.value_changed.connect(_set_canvas_scale)
	canvas_row.add_child(canvas_slider)
	canvas_row.add_child(_label("Higher = finer pixels · all three views · Shared px stays in canvas pixels",12))
	status_label=_label("",12,Color("#d5bc8a"))
	column.add_child(status_label)
	description = _label("",13)
	column.add_child(description)
	column.add_child(_label("Single-probe adaptation, not the full Texel Splatting renderer. Matched mode changes reconstruction, not sampling. Base colour only; no UE glass / normal maps.",12,Color("#8da7ac")))

func _check(parent: Node,text: String,value: bool,callback: Callable) -> void:
	var button := CheckButton.new()
	button.text=text
	button.button_pressed=value
	button.toggled.connect(callback)
	parent.add_child(button)

func _build_renderers() -> void:
	for vp in views:
		var root := Node3D.new()
		vp.add_child(root)
		roots.append(root)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode=Environment.BG_COLOR
		environment.environment.background_color=Color("#1b3640")
		root.add_child(environment)
		var camera := Camera3D.new()
		camera.fov=43
		camera.near=0.05
		camera.far=250
		root.add_child(camera)
		camera.make_current()
		cameras.append(camera)
	voxels=VoxelOctreeDemo.new()
	voxels.set_sampling_depth(sampling_depth)
	voxels.load_mesh(source)
	voxels.target_pixel_footprint=shared_pixels
	roots[1].add_child(voxels)
	probe=ProbeSplatDemo.new()
	probe.load_mesh(source)
	roots[0].add_child(probe)
	reference=MeshInstance3D.new()
	reference.mesh=source
	reference.visible=false
	roots[0].add_child(reference)
	for renderer in [probe,voxels]:
		var material:=ShaderMaterial.new()
		material.shader=load("res://lab_splat.gdshader")
		material.set_shader_parameter("normal_is_world",renderer==probe)
		renderer.material_override=material
		splat_materials.append(material)
	_sync_splat_settings()
	_sync_lighting()

func _set_canvas_scale(value: float) -> void:
	canvas_scale=clampf(value,0.5,4.0)
	canvas_slider.set_value_no_signal(canvas_scale)
	var dimensions:=Vector2i(roundi(320*canvas_scale),roundi(270*canvas_scale))
	for viewport in views: viewport.size=dimensions
	canvas_label.text="Canvas resolution: %d × %d / view (%.1f×)" % [dimensions.x,dimensions.y,canvas_scale]

func _sync_splat_settings() -> void:
	voxels.target_pixel_footprint=shared_pixels
	var shape: Mesh=QuadMesh.new() if matched_pixels else BoxMesh.new()
	if shape is QuadMesh: shape.size=Vector2.ONE
	else: shape.size=Vector3.ONE
	voxels.multimesh.mesh=shape
	for material in splat_materials:
		material.set_shader_parameter("pixel_size",shared_pixels)
		material.set_shader_parameter("matched_pixels",matched_pixels)

func _sync_lighting() -> void:
	for material in splat_materials: material.set_shader_parameter("lighting",lighting)
	for surface in range(source.get_surface_count()):
		source.surface_get_material(surface).set_shader_parameter("lighting",lighting)

func _apply_motion() -> void:
	captured_this_frame=false
	var focus := Vector3(0,2.5,0)
	var camera_pos := fixed_origin
	var target := focus
	var object_transform := Transform3D.IDENTITY
	match case_index:
		0:
			object_transform = Transform3D(Basis(Vector3.UP,time),Vector3.ZERO)
			description.text="OBJECT ROTATION · same voxel identities rotate with the asset; fixed-probe texels sample the moving mesh again."
		1:
			object_transform.origin=Vector3(sin(time)*2.2,0,cos(time)*0.3-0.3)
			description.text="OBJECT TRANSLATION · rigid sideways motion. Probe slots stay fixed; their surface assignments change."
		2:
			camera_pos=focus+Basis(Vector3.UP,time)*(fixed_origin-focus)
			description.text="ORBIT / REVEAL · watch the rear red fin and ring cavities. A fixed probe cannot supply unseen surfaces."
		3:
			camera_pos+=Vector3(sin(time)*3.0,0,0)
			target+=Vector3(sin(time)*3.0,0,0)
			description.text="CAMERA TRANSLATION · parallel sideways dolly; the probe stays at the initial camera position."
		4:
			target+=Vector3(sin(time)*1.7,cos(time)*0.5,0)
			description.text="CAMERA LOOK ROTATION · camera position remains fixed; only its viewing direction changes."
		5:
			camera_pos=focus+(fixed_origin-focus).normalized()*exp(lerpf(log(6.0),log(100.0),0.5-0.5*cos(time)))
			description.text="ZOOM · 6–100 units (16.7×). Finite leaves and coarse material merging remain visible; this is not several orders of magnitude."
		6:
			camera_pos=focus+(fixed_origin-focus).normalized()*(18.0+0.18*sin(time*10))
			description.text="THRESHOLD JITTER · small repeated distance changes. Toggle hysteresis and compare voxel cut churn."
	for cam in cameras:
		cam.position=focus+(camera_pos-focus)/display_zoom
		cam.look_at(target)
	voxels.transform=object_transform
	reference.transform=object_transform
	probe_origin=cameras[0].position if track_probe else fixed_origin
	if refresh_probe or object_transform!=previous_transform or probe_origin!=previous_origin:
		probe.capture(object_transform,probe_origin,resolution)
		captured_this_frame=true
		previous_transform=object_transform
		previous_origin=probe_origin
		refresh_probe=false

func _process(delta: float) -> void:
	if playing: time=fmod(time+minf(delta,0.1)*0.35*speed,TAU)
	_apply_motion()
	time_slider.set_value_no_signal(time)
	play_button.text="Pause" if playing else "Play"
	left_stats.text="%d splats · %.1f ms last CPU capture · %.1f%% slot reassignment" % [probe.get_splat_count(),probe.get_capture_ms(),(probe.get_reassignment()*100 if captured_this_frame else 0)]
	if show_reference:
		left_stats.text="Original LOD0: %d triangles · UV base colour · no resampling" % triangle_count
	var churn: float=voxels.get_cut_churn()
	if playing: peak_churn=maxf(peak_churn,churn); sum_churn+=churn; churn_frames+=1
	right_stats.text="%d / %d voxels · %.2f ms select · %.1f%% cut churn · %.1f px" % [voxels.get_selected_count(),voxels.get_leaf_count(),voxels.get_selection_ms(),churn*100,voxels.target_pixel_footprint]
	status_label.text=("MATCHED: both splats %.2f × %.2f internal pixels · equal footprint, NOT equal sampling density" % [shared_pixels,shared_pixels]) if matched_pixels else "NATIVE: face-aligned probe quads vs voxel cubes · projected sizes are NOT matched"
	if not capture_path.is_empty():
		capture_frame+=1
		if capture_frame==12:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
			print("LAB_CAPTURE case=",case_index," splats=",probe.get_splat_count()," voxels=",voxels.get_selected_count()," ms=",probe.get_capture_ms())
			get_tree().quit()
	if self_test:
		_test_tick.call_deferred()

func _test_tick() -> void:
	test_step+=1
	if test_step%3!=0:return
	if not voxels.validate_cut() or voxels.get_leaf_count()!=original_leaves or cameras[0].transform!=cameras[1].transform or voxels.transform!=reference.transform:
		push_error("Comparison synchronization or persistent source leaf count failed")
		get_tree().quit(1)
		return
	var index:=test_step/3-1
	if index>=CASES.size()*3:
		print("LAB_TEST PASS: synchronized transforms; exact voxel leaf coverage across 21 motion poses.")
		get_tree().quit()
		return
	case_index=int(index)/3
	time=float(int(index)%3)*1.6
	print("LAB_TEST ",CASES[case_index]," t=",time," voxels=",voxels.get_selected_count()," source=",original_leaves)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: playing=not playing
		if event.keycode==KEY_ESCAPE: get_tree().change_scene_to_file("res://main.tscn")

func _load_asset(index: int) -> ArrayMesh:
	if index<=0 or index>asset_entries.size(): return _asset()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local_assets/"+str(asset_entries[index-1].file)))
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=-minimum
	for section in data.sections:
		for p in section.positions:
			var v:=Vector3(p[1],p[2],-p[0])
			minimum=minimum.min(v); maximum=maximum.max(v)
	var extent:=maximum-minimum
	var scale_factor: float=5.5/maxf(extent.x,maxf(extent.y,extent.z))
	var center:=Vector3((minimum.x+maximum.x)*0.5,minimum.y,(minimum.z+maximum.z)*0.5)
	var mesh:=ArrayMesh.new()
	for section in data.sections:
		var vertices:=PackedVector3Array()
		var normals:=PackedVector3Array()
		var colors:=PackedColorArray()
		var uvs:=PackedVector2Array()
		for p in section.positions: vertices.append((Vector3(p[1],p[2],-p[0])-center)*scale_factor)
		for n in section.normals: normals.append(Vector3(n[1],n[2],-n[0]).normalized())
		colors.resize(vertices.size())
		colors.fill(Color.WHITE)
		for uv in section.get("uvs",[]): uvs.append(Vector2(uv[0],uv[1]))
		var material:=ShaderMaterial.new()
		material.shader=load("res://lab_reference.gdshader")
		if section.has("base_color"):
			var path: String="res://local_assets/"+str(section.base_color.file)
			if not texture_cache.has(path):
				var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
				assert(image!=null and not image.is_empty(),"Missing exported texture: "+path)
				var converter:=ProbeSplatDemo.new()
				var linear:=converter.linearize_image(image,bool(section.base_color.srgb))
				converter.free()
				texture_cache[path]=ImageTexture.create_from_image(linear)
			material.set_shader_parameter("base_texture",texture_cache[path])
			material.set_shader_parameter("textured",true)
		else:
			push_warning("No UV base-colour export; re-export this asset with tools/export_static_meshes.py")
		var arrays: Array=[]
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		if not uvs.is_empty(): arrays[Mesh.ARRAY_TEX_UV]=uvs
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(section.indices)
		if not vertices.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			mesh.surface_set_material(mesh.get_surface_count()-1,material)
	return mesh

func _asset_description() -> String:
	if asset_index==0:return "Procedural source mesh"
	return "Apophenia · LOD0 / UV0 · actual base-colour textures · opaque colour-transfer test"

func _change_asset(index: int) -> void:
	asset_index=index
	source=_load_asset(index)
	_count_triangles()
	voxels.set_frozen(false)
	voxels.set_sampling_depth(sampling_depth)
	voxels.load_mesh(source)
	probe.load_mesh(source)
	reference.mesh=source
	_sync_splat_settings()
	_sync_lighting()
	original_leaves=voxels.get_leaf_count()
	time=0; refresh_probe=true
	asset_note.text=_asset_description()

func _count_triangles() -> void:
	triangle_count=0
	for surface in range(source.get_surface_count()):
		var arrays:=source.surface_get_arrays(surface)
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		triangle_count+=indices.size()/3

func _canvas_test() -> void:
	var valid:=true
	for value in [0.5,1.0,2.0,4.0,1.0]:
		_set_canvas_scale(value)
		await get_tree().process_frame
		await get_tree().process_frame
		for viewport in views:
			valid=valid and viewport.size==Vector2i(roundi(320*value),roundi(270*value))
		for material in splat_materials:
			valid=valid and material.get_shader_parameter("pixel_size")==shared_pixels
		valid=valid and voxels.validate_cut() and voxels.get_leaf_count()==original_leaves
		print("CANVAS_TEST scale=",value," size=",views[0].size," valid=",valid)
	print("CANVAS_TEST ","PASS" if valid else "FAIL")
	get_tree().quit(0 if valid else 1)

func _asset_test() -> void:
	set_process(false)
	var all_valid:=true
	for index in range(1,asset_entries.size()+1):
		_change_asset(index)
		_apply_motion()
		await get_tree().process_frame
		await get_tree().process_frame
		var valid:=voxels.validate_cut() and probe.get_splat_count()>0
		for surface in range(source.get_surface_count()):
			var arrays:=source.surface_get_arrays(surface)
			valid=valid and arrays[Mesh.ARRAY_TEX_UV].size()==arrays[Mesh.ARRAY_VERTEX].size()
			valid=valid and source.surface_get_material(surface).get_shader_parameter("textured")==true
		for renderer in [voxels,probe]:
			var buffer: PackedFloat32Array=renderer.multimesh.buffer
			var low:=Vector3(INF,INF,INF)
			var high:=-low
			for i in range(renderer.multimesh.instance_count):
				var color:=Vector3(buffer[i*20+12],buffer[i*20+13],buffer[i*20+14])
				low=low.min(color); high=high.max(color)
			valid=valid and (high-low).length()>0.05
		all_valid=all_valid and valid
		print("ASSET_TEST ",asset_entries[index-1].name," UV/material/colour variance valid=",valid)
	print("ASSET_TEST ", "PASS" if all_valid else "FAIL")
	get_tree().quit(0 if all_valid else 1)

func _experiment() -> void:
	experiment_running=true
	var results: Array[Dictionary] = []
	var frame_number := 0
	if not recording_dir.is_empty(): DirAccess.make_dir_recursive_absolute(recording_dir)
	var case_count := 3 if not recording_dir.is_empty() else 8
	for scenario in range(case_count):
		case_index = [0,2,5][scenario] if not recording_dir.is_empty() else mini(scenario,6)
		case_picker.select(case_index)
		voxels.set_hysteresis(scenario!=7)
		var record: Dictionary = {"case":CASES[case_index],"hysteresis":scenario!=7,"mean_cut_churn":0.0,"max_cut_churn":0.0,"mean_triangle_slot_reassignment":0.0,"min_voxels":999999,"max_voxels":0,"coverage_valid":true}
		var frames := 96 if not recording_dir.is_empty() else 120
		for step in range(frames):
			time=TAU*float(step)/float(frames)
			# Apply synchronously, then wait for the renderer to select the cut.
			# Disable normal process updates while collecting this pose.
			set_process(false)
			_apply_motion()
			var reassignment: float=probe.get_reassignment() if captured_this_frame else 0.0
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var churn: float=voxels.get_cut_churn()
			if step>0:
				record.mean_cut_churn += churn
				record.max_cut_churn = maxf(record.max_cut_churn,churn)
				record.mean_triangle_slot_reassignment += reassignment
			record.min_voxels=mini(record.min_voxels,voxels.get_selected_count())
			record.max_voxels=maxi(record.max_voxels,voxels.get_selected_count())
			record.coverage_valid = record.coverage_valid and voxels.validate_cut() and voxels.get_leaf_count()==original_leaves
			left_stats.text="%d splats · %.1f ms CPU · %.1f%% slot reassignment" % [probe.get_splat_count(),probe.get_capture_ms(),reassignment*100]
			right_stats.text="%d voxels · %.2f ms select · %.1f%% cut churn" % [voxels.get_selected_count(),voxels.get_selection_ms(),churn*100]
			time_slider.set_value_no_signal(time)
			if not recording_dir.is_empty():
				# Capture the updated HUD on the following render, with the pose held.
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(recording_dir.path_join("%04d.png" % frame_number))
				frame_number+=1
		record.mean_cut_churn /= frames-1
		record.mean_triangle_slot_reassignment /= frames-1
		results.append(record)
		print("EXPERIMENT ",JSON.stringify(record))
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"source_voxels":original_leaves,"probe_resolution":resolution,"voxel_target":voxels.target_pixel_footprint,"steps_per_case":120,"results":results}, "\t"))
	get_tree().quit()
