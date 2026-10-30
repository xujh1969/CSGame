extends SceneTree
## Actual Godot renders of the exported models, not generated reference images.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(640, 640)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.22, .25, .28)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.85, .9, 1)
	settings.ambient_light_energy = .7
	environment.environment = settings
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.5
	scene.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	scene.add_child(camera)
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://logs/TASK-008-asset-audit.json"))
	var errors := 0
	for asset in audit.assets:
		var model: Node3D = load("res://assets/models/task008/" + asset.id + ".glb").instantiate()
		scene.add_child(model)
		var low := Vector3(asset.bounds_godot[0][0], asset.bounds_godot[0][1], asset.bounds_godot[0][2])
		var high := Vector3(asset.bounds_godot[1][0], asset.bounds_godot[1][1], asset.bounds_godot[1][2])
		var center := (low + high) / 2
		var extent := (high - low).length()
		camera.position = center + Vector3(.8, .55, 1).normalized() * extent * 1.5
		camera.size = extent * 1.15
		camera.look_at(center)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var output: String = "res://docs/asset_requests/TASK-008/preview_" + asset.id + ".png"
		var error := root.get_texture().get_image().save_png(output)
		print("MODEL PREVIEW ", asset.id, " save=", error)
		if error != OK:
			errors += 1
		model.free()
	scene.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
