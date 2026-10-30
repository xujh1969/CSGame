extends SceneTree
## Actual game renderer previews of the user's baked low-poly car, both ends.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(960, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.18, .21, .24)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(.85, .9, 1)
	world.environment.ambient_light_energy = .7
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.5
	scene.add_child(sun)
	var model: Node3D = load("res://assets/models/task008/vehicle_final_v001.glb").instantiate()
	scene.add_child(model)
	var camera := Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4
	scene.add_child(camera)
	var errors := 0
	for side in ["front", "rear"]:
		camera.position = Vector3(4, 2.7, -6) if side == "front" else Vector3(-4, 2.7, 6)
		camera.look_at(Vector3(0, .7, 0))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/asset_requests/TASK-008/vehicle_runtime_" + side + ".png"
		var error := root.get_texture().get_image().save_png(path)
		print("VEHICLE PREVIEW ", side, " save=", error)
		if error != OK:
			errors += 1
	scene.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
