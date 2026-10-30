extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vertical_slice.json"))
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	var player = scene.get_node("Player")
	player.get_node("InputController").set_physics_process(false)
	player.get_node("InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.get_node("WeaponController").set_physics_process(false)
	# This regression checks route geometry, independently of live combat.
	if scene.has_node("EncounterManager"):
		scene.get_node("GameFlow").enabled = false
		scene.get_node("EncounterManager").enabled = false
		for enemy in scene.get_node("Enemies").get_children():
			enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	await _capture(scene, "start", Vector3(0, 1.7, -20))
	check(scene.get_meta("seed") == data.seed, "fixed layout seed matches JSON")
	check(scene.get_meta("layout_sha256") == FileAccess.get_sha256("res://data/vertical_slice.json"), "baked scene traces exact source JSON")
	check(player.position.is_equal_approx(_vector(data.player_spawn.position)), "player spawn matches JSON")
	check(is_equal_approx(scene.get_node("FinishMarker").position.z, float(data.objective.finish_z)), "finish position matches JSON")
	for encounter in data.encounters:
		var marker: Marker3D = scene.get_node("SpawnMarkers/" + encounter.enemy_id)
		check(marker.position.is_equal_approx(_vector(encounter.spawn_position)), encounter.enemy_id + " editor marker matches JSON")
		var trigger: Area3D = scene.get_node("Triggers/" + encounter.id)
		check(is_equal_approx(trigger.position.z, float(encounter.activate_at_z)) and trigger.collision_mask == 4, encounter.id + " trigger matches JSON and observes player layer")
	for side in ["-1", "1"]:
		for style in ["Residential", "Shopfront", "Ruin"]:
			var found := false
			for facade in scene.get_node("Facades").get_children():
				if str(facade.name).begins_with(style + "_" + side + "_"):
					found = true
			check(found, style + " facade present on side " + side)

	var space := scene.get_world_3d().direct_space_state
	for marker in scene.get_node("SpawnMarkers").get_children():
		var foot: Vector3 = marker.global_position
		var support: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.2, foot - Vector3.UP * 0.2, 3))
		check(not support.is_empty() and is_equal_approx(support.position.y, foot.y), str(marker.name) + " foot matches physical support surface")
	for cover_data in data.covers:
		var cover: Node3D = scene.get_node("Cover/" + cover_data.id)
		check(cover.position.is_equal_approx(_vector(cover_data.position)), cover_data.id + " position matches JSON")
		var from := cover.global_position + Vector3(-0.3, 0.5, 3)
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -6), 3)
		var hit: Dictionary = space.intersect_ray(query)
		check(not hit.is_empty() and cover.is_ancestor_of(hit.collider), cover_data.kind + " blocks real shot ray")
	var window_foot: Vector3 = scene.get_node("SpawnMarkers/E02").global_position
	var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(window_foot + Vector3.UP * 2, window_foot - Vector3.UP, 3))
	check(not floor_hit.is_empty() and is_equal_approx(floor_hit.position.y, window_foot.y), "high-window marker stands on real 4.2m platform")
	var window_los: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.7, -40), window_foot + Vector3.UP * 1.2, 3))
	check(window_los.is_empty(), "high-window opening has visible upper-body sight line")
	var corner_los: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.7, -13), Vector3(4.7, 1.6, -25), 3))
	check(not corner_los.is_empty() and corner_los.collider.name == "CornerWing", "corner marker concealed by physical wing wall")
	var low_wall_los: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 0.8, -56), Vector3(2.6, 0.7, -70), 3))
	check(not low_wall_los.is_empty(), "third marker lower body shielded by low wall")

	var route := scene.get_node("Route").get_children()
	var clearance_shape := CapsuleShape3D.new()
	clearance_shape.radius = 0.6
	clearance_shape.height = 1.8
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = clearance_shape
	clearance.margin = 0.0
	clearance.collision_mask = 1 | 2 | 8
	clearance.exclude = [player.get_rid(), scene.get_node("WorldGeo/Ground").get_rid()]
	var blocked_points := 0
	for i in range(1, route.size()):
		var start: Vector3 = route[i - 1].global_position
		var finish: Vector3 = route[i].global_position
		var steps := ceili(start.distance_to(finish) / 0.2)
		for step in range(steps + 1):
			var sample := start.lerp(finish, float(step) / steps)
			clearance.transform = Transform3D(Basis.IDENTITY, sample + Vector3(0, 0.95, 0))
			var overlaps := space.intersect_shape(clearance, 1)
			if not overlaps.is_empty():
				blocked_points += 1
				if blocked_points <= 3:
					print("Blocked corridor at ", sample, " by ", overlaps[0].collider.name)
	check(blocked_points == 0, "entire sampled route has at least 1.2m capsule clearance")

	var frames := 0
	var grounded_route := true
	for i in range(1, route.size()):
		var goal: Vector3 = route[i].global_position
		var segment_frames := 0
		while Vector2(player.position.x - goal.x, player.position.z - goal.z).length() > 0.12 and segment_frames < 900:
			await physics_frame
			var direction: Vector3 = goal - player.position
			direction.y = 0
			direction = direction.normalized()
			player.move_player(Vector2(direction.x, direction.z), false, false, 1.0 / 60.0)
			grounded_route = grounded_route and player.position.y > -0.05 and player.position.y < 0.15
			segment_frames += 1
			frames += 1
		check(segment_frames < 900, "physical walking reaches route point " + str(i))
		if i == 2:
			await _capture(scene, "corner", Vector3(4.7, 1.5, -25))
		elif i == 3:
			await _capture(scene, "window", Vector3(-5.4, 5.4, -46))
		elif i == 6:
			await _capture(scene, "crates", Vector3(-1.6, 0.8, -63))
		elif i == 7:
			await _capture(scene, "finish", Vector3(0, 2.5, -78))
		if segment_frames >= 900:
			break
	check(grounded_route, "walk remains on ground without jumping or falling")
	await physics_frame
	await physics_frame
	check(scene.get_node("FinishArea").get_overlapping_bodies().has(player), "physical player reaches finish trigger")
	print("Walk frames: ", frames, "; final position: ", player.position)
	scene.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	print("TASK-003 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _capture(scene: Node3D, title: String, look_target: Vector3) -> void:
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	var camera: Camera3D = scene.get_node("Player/Camera3D")
	var original := camera.rotation
	camera.look_at(look_target)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://logs/TASK-003-" + title + ".png")
	check(error == OK, "render checkpoint saved: " + title)
	camera.rotation = original
