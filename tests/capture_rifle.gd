extends SceneTree
## Studio product views of the actual exported mesh, not AI reference artwork.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.16, .18, .20)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = .7
	environment.ambient_light_color = Color(.72, .82, 1)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.environment = environment
	scene.add_child(world)
	for angle in [Vector3(-35, -45, 0), Vector3(-15, 140, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angle
		light.light_energy = 2.4 if angle.y < 0 else 1.0
		scene.add_child(light)
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_registry.json"))
	var rifle_path := ""
	for entry in registry.entries:
		if entry.id == "fps_rifle_m4_sample":
			rifle_path = entry.proposed_path
	var model: Node3D = load(rifle_path).instantiate()
	scene.add_child(model)
	var coating := ShaderMaterial.new()
	coating.shader = preload("res://assets/materials/optic_glass.gdshader")
	model.find_child("Optic_Glass", true, false).material_override = coating
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .72
	camera.current = true
	scene.add_child(camera)
	var errors := 0
	for side in ["right", "left"]:
		camera.position = Vector3(1.2, .4, .6) if side == "right" else Vector3(-1.2, .3, -.65)
		camera.look_at(Vector3(0, -.04, -.10))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://logs/TASK-009-rifle-" + side + ".png"
		var error := root.get_texture().get_image().save_png(path)
		print("RIFLE STUDIO ", side, " save=", error)
		if error != OK:
			errors += 1
	scene.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
