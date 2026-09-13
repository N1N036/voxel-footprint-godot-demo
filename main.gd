extends Node

var camera: Camera3D
var voxels: VoxelOctreeDemo
var world_view: SubViewport
var scene: Node3D
var hud: Control
var stats: Label
var footprint_label: Label
var orbit := 0.48
var elevation := 0.40
var distance := 29.0
var auto_orbit := false
var debug_lod := false
var frozen := false
var dragging := false
var capture_frames := 0
var capture_path := ""
var elapsed := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("LAST LIGHT / Voxel atelier")
	RenderingServer.set_default_clear_color(Color("#142d36"))
	world_view = SubViewport.new()
	world_view.size = Vector2i(480, 270)
	world_view.own_world_3d = true
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(world_view)
	scene = Node3D.new()
	world_view.add_child(scene)
	_make_environment()
	voxels = VoxelOctreeDemo.new()
	scene.add_child(voxels)
	camera = Camera3D.new()
	camera.fov = 43.0
	camera.near = 0.1
	camera.far = 800.0
	scene.add_child(camera)
	camera.make_current()
	_make_sea()
	_make_lantern()
	var output := TextureRect.new()
	output.texture = world_view.get_texture()
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(output)
	_make_hud()
	_update_camera()
	for arg in OS.get_cmdline_user_args():
		if arg == "--self-test":
			_self_test.call_deferred()
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--footprint="):
			voxels.target_pixel_footprint = float(arg.trim_prefix("--footprint="))
		if arg.begins_with("--distance="):
			distance = float(arg.trim_prefix("--distance="))
		if arg == "--lod":
			debug_lod = true
			voxels.set_diagnostic(true)

func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#34586b")
	sky_mat.sky_horizon_color = Color("#d5b594")
	sky_mat.ground_bottom_color = Color("#243e45")
	sky_mat.ground_horizon_color = Color("#bca68b")
	sky_mat.sky_curve = 0.18
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#91b6cb")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#94acaf")
	env.fog_light_energy = 0.65
	env.fog_density = 0.0025
	var environment := WorldEnvironment.new()
	environment.environment = env
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -55, 0)
	sun.light_color = Color("#ffcb89")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 0.5
	scene.add_child(sun)

func _make_sea() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500, 1500)
	sea.mesh = plane
	sea.position.y = -0.35
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://sea.gdshader")
	sea.material_override = material
	scene.add_child(sea)

func _make_lantern() -> void:
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.31
	sphere.height = 0.75
	bulb.mesh = sphere
	bulb.position = Vector3(-1, 7.55, -1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#ffe5a6")
	bulb.material_override = material
	scene.add_child(bulb)
	var light := OmniLight3D.new()
	light.position = bulb.position
	light.light_color = Color("#ffb351")
	light.light_energy = 3.0
	light.omni_range = 4.5
	scene.add_child(light)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade_material := ShaderMaterial.new()
	var shade_shader := Shader.new()
	shade_shader.code = "shader_type canvas_item; void fragment() { float top = pow(1.0 - UV.y, 7.0) * 0.70; float bottom = pow(UV.y, 8.0) * 0.35; COLOR = vec4(0.02, 0.055, 0.065, top + bottom); }"
	shade_material.shader = shade_shader
	shade.material = shade_material
	hud.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var titles := VBoxContainer.new()
	top.add_child(titles)
	titles.add_child(_label("FIELD STUDY   /   001", 12, Color("#d5b78b")))
	titles.add_child(_label("LAST LIGHT", 34, Color("#f4e6ce")))
	titles.add_child(_label("A small island at the edge of evening.", 14, Color("#a6b8b8")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var right := VBoxContainer.new()
	top.add_child(right)
	var tag := _label("VOXEL ATELIER", 13, Color("#ddc9a6"))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(tag)
	stats = _label("", 12, Color("#acbfbd"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(stats)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(fill)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.10, 0.12, 0.90)
	style.border_color = Color("#3c5559")
	style.set_border_width_all(1)
	style.set_content_margin_all(17)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	column.add_child(panel)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 20)
	panel.add_child(controls)
	var slider_column := VBoxContainer.new()
	controls.add_child(slider_column)
	footprint_label = _label("VOXEL FOOTPRINT   /   1.50 px", 12, Color("#ebd6ad"))
	slider_column.add_child(footprint_label)
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 6.0
	slider.step = 0.05
	slider.value = 1.5
	slider.custom_minimum_size.x = 255
	slider.value_changed.connect(func(value: float): voxels.target_pixel_footprint = value)
	slider_column.add_child(slider)
	var resolution := OptionButton.new()
	for text in ["480 × 270", "320 × 180", "640 × 360"]:
		resolution.add_item(text)
	resolution.item_selected.connect(func(index: int): world_view.size = [Vector2i(480,270), Vector2i(320,180), Vector2i(640,360)][index])
	controls.add_child(resolution)
	_button(controls, "LOD colours", func(): debug_lod = not debug_lod; voxels.set_diagnostic(debug_lod))
	_button(controls, "Freeze LOD", func(): frozen = not frozen; voxels.set_frozen(frozen))
	_button(controls, "Auto orbit", func(): auto_orbit = not auto_orbit)
	_button(controls, "Reset view", func(): orbit = 0.48; elevation = 0.40; distance = 29.0, false)
	var help := _label("DRAG  orbit     SCROLL  zoom     SPACE  auto orbit     H  hide interface", 12, Color("#adbfbd"))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help)

func _button(parent: Node, text: String, action: Callable, toggle := true) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.pressed.connect(action)
	button.add_theme_font_size_override("font_size", 13)
	parent.add_child(button)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(14.0, distance - 1.5)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(65.0, distance + 1.5)
	if event is InputEventMouseMotion and dragging:
		orbit -= event.relative.x * 0.005
		elevation = clampf(elevation + event.relative.y * 0.003, 0.12, 1.1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: auto_orbit = not auto_orbit
		if event.keycode == KEY_H: hud.visible = not hud.visible
		if event.keycode == KEY_ESCAPE: get_tree().quit()

func _process(delta: float) -> void:
	elapsed += delta
	if auto_orbit: orbit += delta * 0.10
	orbit += Input.get_axis("ui_left", "ui_right") * delta * 0.55
	_update_camera()
	stats.text = "%s / %s voxels\n%.2f ms selection  ·  %d fps%s" % [
		voxels.get_selected_count(), voxels.get_leaf_count(), voxels.get_selection_ms(),
		Engine.get_frames_per_second(), "  /  FROZEN" if frozen else ""]
	footprint_label.text = "VOXEL FOOTPRINT   /   %.2f px" % voxels.target_pixel_footprint
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 150:
			await RenderingServer.frame_post_draw
			var error := get_viewport().get_texture().get_image().save_png(capture_path)
			print("CAPTURE ", error, " selected=", voxels.get_selected_count(), " leaves=", voxels.get_leaf_count(), " selection_ms=", voxels.get_selection_ms())
			get_tree().quit()

func _update_camera() -> void:
	var focus := Vector3(0, 2.7, 0.5)
	camera.position = focus + Vector3(sin(orbit)*cos(elevation), sin(elevation), cos(orbit)*cos(elevation))*distance
	camera.look_at(focus)

func _settle() -> void:
	for i in range(4):
		await get_tree().process_frame

func _self_test() -> void:
	voxels.target_pixel_footprint = 0.5
	await _settle()
	var fine := voxels.get_selected_count()
	var valid := voxels.validate_cut()
	voxels.target_pixel_footprint = 4.0
	await _settle()
	var coarse := voxels.get_selected_count()
	valid = valid and voxels.validate_cut() and coarse < fine
	voxels.set_frozen(true)
	distance = 60.0
	await _settle()
	valid = valid and voxels.get_selected_count() == coarse and voxels.validate_cut()
	voxels.set_frozen(false)
	await _settle()
	var far := voxels.get_selected_count()
	valid = valid and far < coarse and voxels.validate_cut()
	world_view.size = Vector2i(640, 360)
	await _settle()
	valid = valid and voxels.get_selected_count() >= far and voxels.validate_cut()
	print("SELF_TEST ", "PASS" if valid else "FAIL", " fine=", fine, " coarse=", coarse, " far=", far, " higher_resolution=", voxels.get_selected_count())
	get_tree().quit(0 if valid else 1)
