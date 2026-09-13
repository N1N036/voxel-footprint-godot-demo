extends Node

const INTERNAL_SIZE := Vector2i(320, 180)

var camera: Camera3D
var voxel_world: VoxelOctreeDemo
var orbit := 0.0

func _ready() -> void:
	# The world is deliberately rendered at a tiny fixed resolution, then enlarged
	# with nearest-neighbour filtering. The C++ selector therefore measures its
	# target footprint in the same pixels the player actually sees.
	var viewport := SubViewport.new()
	viewport.size = INTERNAL_SIZE
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)

	var scene := Node3D.new()
	viewport.add_child(scene)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("10213d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a9c4ff")
	env.ambient_light_energy = 0.55
	environment.environment = env
	scene.add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	scene.add_child(sun)

	voxel_world = VoxelOctreeDemo.new()
	voxel_world.target_pixel_footprint = 1.5
	voxel_world.internal_render_width = INTERNAL_SIZE.x
	scene.add_child(voxel_world)

	camera = Camera3D.new()
	camera.fov = 55.0
	scene.add_child(camera)

	var output := TextureRect.new()
	output.texture = viewport.get_texture()
	output.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	output.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(output)

	var label := Label.new()
	label.text = "VOXEL FOOTPRINT\nC++ octree cut at ~1.5 internal pixels\nArrow keys: orbit   +/-: footprint"
	label.position = Vector2(16, 14)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	_update_camera()

func _process(delta: float) -> void:
	orbit += Input.get_axis("ui_left", "ui_right") * delta * 0.7
	voxel_world.target_pixel_footprint = clampf(
		voxel_world.target_pixel_footprint + Input.get_axis("ui_down", "ui_up") * delta,
		0.6, 5.0
	)
	_update_camera()

func _update_camera() -> void:
	var radius := 24.0
	camera.global_position = Vector3(sin(orbit) * radius, 14.0, cos(orbit) * radius)
	camera.look_at_from_position(camera.global_position, Vector3(0, 1.5, 0))

