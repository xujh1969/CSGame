extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 900)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.18, .21, .24)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_energy = .75
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.8
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	scene.add_child(camera)
	for asset in ["new_ar", "arms", "clutter1", "clutter2", "clutter3"]:
		var model: Node3D = load("res://assets/models/task009/v003/" + asset + "_base.glb").instantiate()
		scene.add_child(model)
		var bounds := AABB()
		var initialized := false
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.transform * mesh.mesh.get_aabb()
			bounds = bounds.merge(box) if initialized else box
			initialized = true
		var center := bounds.get_center()
		camera.size = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.7
		camera.position = center + (Vector3(.15, .15, 2) if asset == "arms" else Vector3(1.3, .7, 1)) * camera.size
		camera.look_at(center)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://logs/TASK-009-v003-baked-" + asset + ".png"
		print("BAKED PREVIEW ", asset, " save=", root.get_texture().get_image().save_png(path))
		model.free()
	scene.queue_free()
	await process_frame
	quit()
