extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, text: String) -> void:
	if ok:
		print("PASS: ", text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func _run() -> void:
	if "--render-1080" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
	if not ResourceLoader.exists("res://scenes/levels/art/StreetSample.tscn"):
		check(false, "art sample exists")
		quit(1)
		return
	var scene: Node3D = load("res://scenes/levels/art/StreetSample.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("Player/InputController").set_physics_process(false)
	scene.get_node("Player/InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame
	await physics_frame
	var art = scene.get_node("StreetArt")
	var railing_model: Node3D = load(art.registry.sample_residential_A.proposed_path).instantiate()
	scene.add_child(railing_model)
	var side_returns := true
	for balcony_x in [-2.5, 2.5]:
		for side in [-1, 1]:
			var x: float = balcony_x + side * .79
			side_returns = side_returns and _visual_segment_hit(railing_model, Vector3(x - .3, 4.05, .6), Vector3(x + .3, 4.05, .6))
	check(side_returns, "both balconies include both side return railings in actual exported triangles")
	railing_model.free()
	check(art.loaded_assets.size() >= 5, "five real Blender GLB modules load")
	check(art.asset_errors.is_empty(), "registered sample assets exist and load")
	check(art.loaded_assets.has("sample_vehicle_final") and not art.loaded_assets.has("sample_vehicle_proxy"), "user low-poly car replaces the proxy")
	var vehicle_entry: Dictionary = art.registry.sample_vehicle_final
	var car_model: Node3D = load(vehicle_entry.proposed_path).instantiate()
	var car_triangles := 0
	var car_pbr := false
	for mesh_node in car_model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh_node.mesh.get_surface_count()):
			car_triangles += mesh_node.mesh.surface_get_array_index_len(surface) / 3
			var material = mesh_node.mesh.surface_get_material(surface)
			car_pbr = material is StandardMaterial3D and material.albedo_texture != null and material.albedo_texture.get_size() == Vector2(2048, 2048) and material.normal_enabled and material.normal_texture != null and material.roughness_texture != null and material.metallic_texture != null
	check(car_triangles == 9614 and car_pbr, "actual imported car has 9614 triangles and baked 2K PBR maps")
	car_model.free()
	var source_unchanged := true
	for path in vehicle_entry.raw_sha256:
		source_unchanged = source_unchanged and FileAccess.get_sha256("res://" + path.replace("\\", "/")) == vehicle_entry.raw_sha256[path]
	check(source_unchanged, "both original user model SHA256 values remain unchanged")
	var vehicle_body: StaticBody3D = art.get_node("VehicleCollision")
	check(vehicle_body.get_child_count() == 2 and vehicle_body.get_child(0).shape is ConvexPolygonShape3D and vehicle_body.get_child(1).shape is ConvexPolygonShape3D, "car collision uses actual low-poly body and cabin hulls")
	var atmosphere = art.get_node("Atmosphere")
	check(atmosphere.particles.size() == 4 and atmosphere.environment.volumetric_fog_enabled, "Medium creates bounded smoke, dust, fire and volumetric haze")
	var smoke_texture: Texture2D = load("res://assets/textures/task008/smoke_puff_v001.png")
	var smoke_image := smoke_texture.get_image()
	if smoke_image.is_compressed():
		smoke_image.decompress()
	check(smoke_image != null and smoke_image.get_pixel(0, 0).a < .01 and smoke_image.get_pixel(smoke_image.get_width() / 2, smoke_image.get_height() / 2).a > .1, "smoke sprite contains actual alpha, not a painted background")
	check(art.get_node("LargeDebrisCollision").get_child_count() == 40, "forty larger debris pieces have real collision shapes")
	var player = scene.get_node("Player")
	var enemy = scene.get_node("Enemies/AGuard")
	var weapon = player.get_node("WeaponController")
	weapon.hip_spread = 0
	var space := scene.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2, .6, -6), Vector3(-2, .6, -12), 3))
	check(not hit.is_empty(), "textured player barrier still blocks weapon layer ray")
	var car_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3.35, .5, -12), Vector3(-3.35, .5, -18), 3))
	check(not car_hit.is_empty() and car_hit.collider.name == "VehicleCollision", "actual car body blocks weapon ray with metal collision")
	var above_car := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3.35, 1.7, -12), Vector3(-3.35, 1.7, -18), 3))
	check(above_car.is_empty(), "ray above the car roof remains unobstructed")
	var facade_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 1.7, -12), Vector3(-8, 1.7, -12), 3))
	check(not facade_hit.is_empty() and art.is_ancestor_of(facade_hit.collider), "shop facade, not hidden boundary box, blocks real shot")
	var pbr_surfaces := 0
	for node in art.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null:
			continue
		for i in range(node.mesh.get_surface_count()):
			var material = node.get_active_material(i)
			if material is StandardMaterial3D and material.albedo_texture != null and material.normal_enabled and material.roughness_texture != null:
				pbr_surfaces += 1
	check(pbr_surfaces >= 5, "imported GLBs retain albedo, normal and roughness textures")
	var capsule := CapsuleShape3D.new()
	capsule.radius = .6
	capsule.height = 1.8
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.margin = 0
	clearance.collision_mask = 3
	clearance.exclude = [scene.get_node("WorldGeo/Ground").get_rid()]
	clearance.transform = Transform3D(Basis.IDENTITY, Vector3(-3.35, .95, -15))
	var body_hits := space.intersect_shape(clearance, 8)
	var car_blocks_body := false
	for body_hit in body_hits:
		car_blocks_body = car_blocks_body or body_hit.collider == vehicle_body
	check(car_blocks_body, "player-size capsule cannot overlap the actual car body")
	var blocked := 0
	for index in range(97):
		clearance.transform = Transform3D(Basis.IDENTITY, Vector3(0, .95, 3 - index * .25))
		if not space.intersect_shape(clearance, 1).is_empty():
			blocked += 1
	check(blocked == 0, "entire sample route preserves 1.2m capsule clearance")
	check(scene.get_node("Player/HealthComponent").current_health == 100, "sample starts with original player health")
	await _capture("start")
	await _sample_frames(scene, false)
	await _sample_frames(scene, true)
	scene.get_node("BattlePresentation").set_low_quality(false)
	for index in range(1, scene.get_node("Route").get_child_count()):
		var point: Vector3 = scene.get_node("Route").get_child(index).position
		var frames := 0
		while Vector2(player.position.x - point.x, player.position.z - point.z).length() > .15 and frames < 900:
			await physics_frame
			if paused:
				break
			var direction: Vector3 = point - player.position
			direction.y = 0
			direction = direction.normalized()
			player.move_player(Vector2(direction.x, direction.z), false, false, 1.0 / 60)
			if enemy.active and enemy.is_alive():
				player.get_node("Camera3D").look_at(enemy.global_position + Vector3.UP * 1.4)
				weapon.try_fire()
			frames += 1
		check(frames < 900, "physical route reaches point " + str(index))
		if index == 1:
			player.get_node("Camera3D").rotation = Vector3.ZERO
			await _capture("cover")
		elif index == 2:
			player.get_node("Camera3D").rotation = Vector3.ZERO
			await _capture("shop")
			scene.get_node("BattlePresentation").set_low_quality(true)
			await _capture("low")
			scene.get_node("BattlePresentation").set_low_quality(false)
	await process_frame
	await process_frame
	check(not enemy.is_alive() and scene.get_node("GameFlow").state == 3, "sample retains real combat and finish victory")
	check(scene.get_node("FinishArea").get_overlapping_bodies().has(player), "physical player overlaps sample finish")
	scene.get_node("BattlePresentation").set_low_quality(true)
	check(not scene.get_node("Sun").shadow_enabled, "Low still disables dynamic shadow")
	check(not atmosphere.environment.volumetric_fog_enabled and not atmosphere.flame_light.visible, "Low disables volumetric atmosphere and fire light")
	var stopped := true
	for emitter in atmosphere.particles:
		stopped = stopped and not emitter.visible and not emitter.emitting
	check(stopped, "Low stops all noncritical atmosphere particles")
	scene.get_node("GameFlow").restart()
	for i in range(4):
		await process_frame
	scene = current_scene
	check(scene.has_node("StreetArt") and scene.get_node("StreetArt").loaded_assets.size() >= 5, "retry reloads art sample rather than base graybox fixture")
	check(scene.get_node("StreetArt").loaded_assets.has("sample_vehicle_final"), "retry retains actual delivered car")
	check(not paused and scene.get_node("Player/HealthComponent").current_health == 100, "art retry restores running player state")
	scene.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	print("TASK-008 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _capture(title: String) -> void:
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	var camera: Camera3D = current_scene.get_node("Player/Camera3D")
	var original := camera.rotation
	var targets := {"start": Vector3(0, 2.7, -22), "cover": Vector3(1, 2.4, -18), "shop": Vector3(-5.8, 3.2, -16), "low": Vector3(-5.8, 3.2, -16)}
	if targets.has(title):
		camera.look_at(targets[title])
	await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "1080-" if "--render-1080" in OS.get_cmdline_user_args() else ""
	check(root.get_texture().get_image().save_png("res://logs/TASK-008-" + prefix + title + ".png") == OK, "actual render saved: " + prefix + title)
	camera.rotation = original

func _sample_frames(scene: Node3D, low: bool) -> void:
	if not "--measure-performance" in OS.get_cmdline_user_args():
		return
	scene.get_node("BattlePresentation").set_low_quality(low)
	for i in range(60):
		await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	print("SAMPLE PERFORMANCE low=", low, " resolution=", root.size, " median_ms=", samples[90], " p95_ms=", samples[171], " max_ms=", samples[179], " engine_video_memory_bytes=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), " GPU=", RenderingServer.get_video_adapter_name())

func _visual_segment_hit(model: Node3D, from: Vector3, to: Vector3) -> bool:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var local_from: Vector3 = mesh.to_local(from)
		var local_to: Vector3 = mesh.to_local(to)
		for i in range(0, faces.size(), 3):
			if Geometry3D.segment_intersects_triangle(local_from, local_to, faces[i], faces[i + 1], faces[i + 2]) != null:
				return true
	return false
