extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(64,64)
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera:=Camera3D.new()
	viewport.add_child(camera)
	var instance:=MultiMeshInstance3D.new()
	var data:=MultiMesh.new()
	data.transform_format=MultiMesh.TRANSFORM_3D
	data.use_colors=true
	data.use_custom_data=true
	var quad:=QuadMesh.new()
	quad.size=Vector2.ONE
	data.mesh=quad
	data.instance_count=1
	data.set_instance_color(0,Color.WHITE)
	instance.multimesh=data
	var material:=ShaderMaterial.new()
	material.shader=load("res://lab_splat.gdshader")
	material.set_shader_parameter("lighting",false)
	instance.material_override=material
	viewport.add_child(instance)
	var valid:=true
	for depth in [2.0,20.0,100.0]:
		for width in [2.0,4.0]:
			data.set_instance_transform(0,Transform3D(Basis.from_euler(Vector3(0.3,0.7,0.2)).scaled(Vector3.ONE*7),Vector3(0,0,-depth)))
			data.set_instance_custom_data(0,Color(0,1,0,0))
			material.set_shader_parameter("pixel_size",width)
			await process_frame
			await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			var count:=0
			for y in range(64):
				for x in range(64):
					if image.get_pixel(x,y).a>0.5: count+=1
			var expected:=int(width*width)
			valid=valid and count==expected
			print("PIXEL_TEST depth=",depth," width=",width," pixels=",count," expected=",expected)
	print("PIXEL_TEST ","PASS" if valid else "FAIL")
	quit(0 if valid else 1)
