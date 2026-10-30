extends SceneTree

var failures := 0
var pose_records := []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	print("PASS: " + description if ok else "FAIL: " + description)
	if not ok:
		failures += 1

func _run() -> void:
	check(ResourceLoader.exists("res://scenes/levels/art/CinematicSample.tscn"), "cinematic sample exists")
	if failures:
		quit(1)
		return
	if "--render-1080" in OS.get_cmdline_user_args():
		root.size = Vector2i(1920, 1080)
	var scene: Node3D = load("res://scenes/levels/art/CinematicSample.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player: CharacterBody3D = scene.get_node("Player")
	player.get_node("InputController").set_physics_process(false)
	player.get_node("InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(15)
	var presentation = scene.get_node("CinematicPresentation")
	var rifle = presentation.rifle
	var lens = presentation.lens
	var weapon = player.get_node("WeaponController")
	var camera: Camera3D = player.get_node("Camera3D")
	var arms = camera.get_node("RifleViewModel/FirstPersonArms")
	check(arms.skeleton.get_bone_count() >= 6 and arms.hold_animation != "" and arms.reload_animation != "", "actual arms skin and hold/reload animations load")
	check(_shoulders_anchored(arms, camera), "both shoulder joints remain anchored behind the camera")
	check(arms.skeleton.get_bone_name(arms.skeleton.get_bone_parent(arms.skeleton.find_bone("thumb_L.L_8"))) == "R_Hand" and arms.skeleton.get_bone_name(arms.skeleton.get_bone_parent(arms.skeleton.find_bone("thumb_L.R_34"))) == "L_Hand", "native hand chains match the user reference instead of misleading L/R suffixes")
	var glove_entry: Dictionary = scene.get_node("StreetArt").registry.player_fp_arms
	var source_unchanged := true
	for path in glove_entry.raw_sha256:
		source_unchanged = source_unchanged and FileAccess.get_sha256("res://" + path) == glove_entry.raw_sha256[path]
	check(source_unchanged, "downloaded glove source SHA256 remains unchanged")
	check(_palm_facing(arms, rifle, glove_entry, "R", Vector3.LEFT), "right palm faces inward toward the pistol grip")
	check(_palm_facing(arms, rifle, glove_entry, "L", Vector3.UP), "left palm supports the handguard from below")

	print("ARM REACHABILITY ERRORS ", arms.reachability_errors)
	check(float(arms.reachability_errors.R) < .015 and float(arms.reachability_errors.L) < .015, "both authored wrist targets are anatomically reachable within 15mm")
	check(rifle.model != null and rifle.magazine != null, "real GLB body and independent magazine load")
	check(rifle.optic_glass != null and rifle.optic_glass.material_override is ShaderMaterial, "optic has real separate coated transparent glass mesh")
	check(not camera.get_node("RifleViewModel/Receiver").visible, "old box weapon hidden only in cinematic sample")
	check(camera.get_node("RifleViewModel/Muzzle").position.is_equal_approx(rifle.muzzle_offset), "shot marker aligns with modeled bore")
	var registry: Dictionary = scene.get_node("StreetArt").registry.fps_rifle_m4_sample
	var original_files_unchanged := true
	for path in registry.get("raw_sha256", {}):
		original_files_unchanged = original_files_unchanged and FileAccess.get_sha256("res://" + path) == registry.raw_sha256[path]
	check(original_files_unchanged, "user source rifle hashes remain unchanged")
	var triangle_count := 0
	var textured := false
	var metal_finish := false
	var polymer_finish := false
	var user_finish := false
	var orphan_shadow := false
	var interfaces_assigned := true
	for mesh in rifle.model.find_children("*", "MeshInstance3D", true, false):
		orphan_shadow = orphan_shadow or mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in range(mesh.mesh.get_surface_count()):
			triangle_count += mesh.mesh.surface_get_array_index_len(surface) / 3
			var material = mesh.mesh.surface_get_material(surface)
			interfaces_assigned = interfaces_assigned and material != null
			textured = textured or (material is StandardMaterial3D and material.albedo_texture != null and material.roughness_texture != null and material.normal_enabled)
			if material is StandardMaterial3D and material.albedo_texture != null:
				user_finish = user_finish or (material.albedo_texture.get_size() == Vector2(2048, 2048) and material.normal_enabled and material.roughness_texture != null and material.metallic_texture != null)
				metal_finish = metal_finish or (material.resource_name.begins_with("Anodized_receiver") and material.albedo_texture.get_size() == Vector2(2048, 2048) and material.metallic > .5)
				polymer_finish = polymer_finish or (material.resource_name.begins_with("Black_polymer") and material.albedo_texture.get_size() == Vector2(1024, 1024) and material.metallic < .1 and material.normal_enabled)
	check(triangle_count == int(registry.triangles) and triangle_count < 50000 and textured, "actual imported rifle matches registered bounded geometry and PBR textures")
	print("ACTUAL RIFLE TRIANGLES ", triangle_count)
	check(user_finish if registry.get("user_delivery", false) else metal_finish and polymer_finish, "actual imported rifle retains its registered PBR finish")
	check(not orphan_shadow, "first-person weapon does not cast an orphan floating gun shadow")
	check(interfaces_assigned and _declared_materials(registry.proposed_path), "all split component and optic-bore faces have explicit materials")
	check(_optic_open(rifle), "real scope body has an open sight-axis aperture")
	check(presentation.get_node("DistantCity").find_children("*", "MeshInstance3D", true, false).size() > 0, "layered distant building mesh exists")
	var skyline_height := 0.0
	for mesh in presentation.get_node("DistantCity").find_children("*", "MeshInstance3D", true, false):
		skyline_height = maxf(skyline_height, (mesh.transform * mesh.mesh.get_aabb()).end.y)
	check(skyline_height > 35, "actual distant mesh includes tall landmark silhouette")
	check(camera.attributes == lens.attributes and lens.attributes.dof_blur_far_enabled, "camera owns active conservative DOF attributes")
	check(lens.attributes.dof_blur_far_distance >= 28, "entire 24m combat range remains inside sharp far region")
	check(_right_grip_error(arms, rifle) < .002, "Idle wrist matches the calibrated RightGripSocket within 2mm")
	check(_skin_stretch(arms) < .03, "Idle glove skin has no edge stretched by more than 30mm")
	await _capture("hip")
	weapon.set_controls(false, true, false, false)
	await _frames(35)
	check(is_equal_approx(camera.fov, 55) and rifle.reticle.visible, "ADS aligns open reflex sight without opaque overlay")
	check(rifle.view_model.position.is_equal_approx(Vector3(0, -.135, -.43)), "ADS positions actual sight center on camera axis")
	await _capture("ads")
	if "--render-checkpoints" in OS.get_cmdline_user_args():
		await _check_glass(rifle)
	weapon.set_controls(false, false, false, false)
	await _frames(30)
	var reserve_before: int = weapon.reserve
	check(weapon.try_fire() and weapon.magazine == 29, "new viewmodel fires once through original ammo authority")
	await _frames(1)
	check(arms.current.ends_with("Fire"), "actual firing selects the authored finger Fire clip")
	check(_right_grip_error(arms, rifle) < .002, "Fire retains the right-hand grip socket")
	check(_skin_stretch(arms) < .03, "Fire preserves the glove webbing without a flattened sheet")
	await _capture("fire")
	check(weapon.request_reload(), "original reload starts")
	var arm_clearance := INF
	var left_side_path := true
	var grip_error := 0.0
	for frame in range(45):
		await _frames(1)
		arm_clearance = minf(arm_clearance, _arm_clearance(arms))
		left_side_path = left_side_path and _left_arm_stays_left(arms, camera)
		grip_error = maxf(grip_error, _right_grip_error(arms, rifle))
		if frame == 12:
			await _capture("reload_start")
	check(rifle.magazine.position.distance_to(rifle.magazine_origin) > .1, "real magazine visibly extracts during actual reload")
	check(_magazine_visible(rifle, camera), "extracted magazine remains clearly inside the actual camera frame")
	check(_shoulders_anchored(arms, camera), "reload does not move open shoulder cuts into view")
	check(float(arms.reachability_errors.R) < .015 and float(arms.reachability_errors.L) < .015, "reload wrist targets remain anatomically reachable")
	check(rifle.magazine_held and rifle.magazine.get_parent() == arms.magazine_socket, "extracted magazine is actually parented to the left-hand socket")
	check(_skin_stretch(arms) < .03, "Reload glove skin has no edge stretched by more than 30mm")
	await _capture("reload")
	paused = true
	var remaining: float = weapon.reload_remaining
	var hand_pose: Transform3D = arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone("L_Hand"))
	for i in range(6):
		await process_frame
	check(is_equal_approx(remaining, weapon.reload_remaining), "pause freezes reload and visual presentation")
	check(arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone("L_Hand")).is_equal_approx(hand_pose), "pause freezes the actual arm pose")
	paused = false
	for frame in range(110):
		await _frames(1)
		if frame == 45:
			await _capture("reload_insert")
		arm_clearance = minf(arm_clearance, _arm_clearance(arms))
		left_side_path = left_side_path and _left_arm_stays_left(arms, camera)
		grip_error = maxf(grip_error, _right_grip_error(arms, rifle))
	print("RELOAD MINIMUM ARM CENTERLINE CLEARANCE ", arm_clearance)
	check(arm_clearance >= .12, "entire reload keeps arm centerlines at least 120mm apart")
	check(left_side_path, "left wrist approaches and leaves magazine from the camera left side")
	check(grip_error < .002, "reload samples retain the right wrist at its grip socket")
	check(weapon.magazine == 30 and weapon.reserve == reserve_before - 1, "reload transfers exactly one round without animation duplicating ammo")
	check(rifle.magazine.position.is_equal_approx(rifle.magazine_origin), "magazine returns to socket after reload")
	print("MAGAZINE ATTACHMENT JUMP ", rifle.attachment_jump)
	check(not rifle.magazine_held and rifle.magazine.get_parent() == rifle.model and rifle.attachment_jump < .005 and rifle.attachment_angle < .01, "magazine reparent preserves world transform, then seats smoothly in weapon socket")
	check(_arm_lengths_valid(arms), "reload preserves original upper-arm and forearm lengths")
	await _capture("post_reload")
	check(weapon.try_fire(), "cancellation fixture fires through original authority")
	check(weapon.request_reload(), "second reload starts for cancellation check")
	await _frames(45)
	check(rifle.magazine_held, "second reload actually transfers magazine to hand")
	weapon.cancel_actions()
	await _frames(3)
	check(not rifle.magazine_held and rifle.magazine.get_parent() == rifle.model and arms.current.ends_with("Hold"), "cancel restores weapon parent and Idle pose without an orphaned held magazine")

	var original_rotation := camera.rotation
	var stable := true
	for frame in range(180):
		await physics_frame
		camera.rotation = Vector3(.08 * sin(frame * .05), .3 * sin(frame * .07), 0)
		weapon.set_controls(false, false, false, true)
		player.move_player(Vector2(0, -1 if frame % 60 < 30 else 1), true, false, 1.0 / 60)
		await process_frame
		stable = stable and _arm_lengths_valid(arms) and _shoulders_anchored(arms, camera)
	player.velocity = Vector3.ZERO
	camera.rotation = original_rotation
	weapon.set_controls(false, false, false, false)
	check(stable, "180 frames of sprinting and turning do not accumulate arm stretch")
	await _capture("post_sprint")
	var wall := StaticBody3D.new()
	wall.name = "TestWall"
	wall.position = camera.global_position - camera.global_basis.z * .62
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, .12)
	shape.shape = box
	wall.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	visual.mesh = mesh
	wall.add_child(visual)
	scene.add_child(wall)
	await _frames(40)
	check(rifle.obstruction > .35 and rifle.view_model.position.z > -.2, "near-wall sphere cast retracts weapon")
	check(_gun_in_front_of_wall(rifle, wall), "entire rendered hip weapon remains in front of wall surface")
	var hit: Dictionary = weapon.trace_shot(camera.global_position, -camera.global_basis.z, rifle.view_model.get_node("Muzzle").global_position)
	check(not hit.is_empty() and hit.collider == wall, "retracted muzzle still cannot shoot through real wall")
	await _capture("wall")
	weapon.set_controls(false, true, false, false)
	await _frames(40)
	check(_gun_in_front_of_wall(rifle, wall), "entire rendered ADS weapon remains in front of wall surface")
	for angle in [-30, 30]:
		wall.rotation_degrees.y = angle
		await _frames(35)
		check(_gun_in_front_of_wall(rifle, wall), "ADS weapon remains outside oblique wall " + str(angle))
	weapon.set_controls(false, false, false, false)
	wall.queue_free()
	await _frames(40)
	check(rifle.obstruction < .01, "weapon smoothly recovers after leaving wall")
	scene.get_node("BattlePresentation").set_low_quality(true)
	check(not lens.attributes.dof_blur_far_enabled and not lens.attributes.dof_blur_near_enabled, "Low disables all added DOF")
	await _capture("low")
	await _performance(scene, true)
	scene.get_node("BattlePresentation").set_low_quality(false)
	check(lens.attributes.dof_blur_far_enabled, "Medium restores conservative DOF")
	await _performance(scene, false)
	weapon.hip_spread = 0
	var enemy = scene.get_node("Enemies/AGuard")
	for index in range(1, scene.get_node("Route").get_child_count()):
		var point: Vector3 = scene.get_node("Route").get_child(index).position
		var frames := 0
		while Vector2(player.position.x - point.x, player.position.z - point.z).length() > .15 and frames < 900 and not paused:
			await physics_frame
			var direction: Vector3 = (point - player.position)
			direction.y = 0
			direction = direction.normalized()
			player.move_player(Vector2(direction.x, direction.z), false, false, 1.0 / 60)
			if enemy.active and enemy.is_alive():
				camera.look_at(enemy.global_position + Vector3.UP * 1.4)
				weapon.try_fire()
			frames += 1
		check(frames < 900, "new rifle fixture physically reaches route point " + str(index))
	await process_frame
	check(not enemy.is_alive() and scene.get_node("GameFlow").state == 3, "new muzzle and lens retain actual combat victory")
	scene.get_node("GameFlow").restart()
	await _frames(5)
	scene = current_scene
	check(scene.has_node("CinematicPresentation") and scene.get_node("CinematicPresentation").rifle.model != null, "retry retains cinematic scene and rifle")
	scene.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	print("TASK-009 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _capture(title: String) -> void:
	var camera := current_scene.get_node("Player/Camera3D")
	var arms = camera.get_node("RifleViewModel/FirstPersonArms")
	var rifle = camera.get_node("RifleViewModel/CinematicRifle")
	var row := {"checkpoint": title, "animation": arms.current, "reload_phase": rifle.reload_phase, "weapon_world": str(rifle.model.global_transform), "right_grip_socket_world": str(rifle.right_grip_socket.global_transform), "magazine_world": str(rifle.magazine.global_transform), "magazine_parent": str(rifle.magazine.get_parent().get_path()), "bone_world": {}}
	for side in ["R", "L"]:
		row.bone_world[side] = str(arms.skeleton.global_transform * arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side + "_Hand")))
	pose_records.append(row)
	var output := FileAccess.open("res://logs/TASK-009-v005-state-transforms.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(pose_records, "\t"))
	output.close()
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "1080-" if "--render-1080" in OS.get_cmdline_user_args() else ""
	check(root.get_texture().get_image().save_png("res://logs/TASK-009-" + prefix + title + ".png") == OK, "actual render saved: " + title)

func _performance(scene: Node3D, low: bool) -> void:
	if not "--measure-performance" in OS.get_cmdline_user_args():
		return
	await _frames(60)
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	print("CINEMATIC PERFORMANCE low=", low, " resolution=", root.size, " median_ms=", samples[90], " p95_ms=", samples[171], " max_ms=", samples[179], " engine_video_memory_bytes=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), " GPU=", RenderingServer.get_video_adapter_name())

func _check_glass(rifle: Node3D) -> void:
	await RenderingServer.frame_post_draw
	var coated := root.get_texture().get_image()
	rifle.optic_glass.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var clear := root.get_texture().get_image()
	var difference := 0.0
	for x in range(-18, 19, 3):
		for y in range(-18, 19, 3):
			var pixel := root.size / 2 + Vector2i(x, y)
			var a := coated.get_pixelv(pixel)
			var b := clear.get_pixelv(pixel)
			difference += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3
	difference /= 169
	rifle.optic_glass.show()
	print("OPTIC THROUGH-VIEW mean_rgb_difference=", difference)
	check(difference < .12, "rendered sight glass transmits actual scene rather than an opaque panel")

func _gun_in_front_of_wall(rifle: Node3D, wall: Node3D) -> bool:
	for mesh in rifle.model.find_children("*", "MeshInstance3D", true, false):
		for vertex in mesh.mesh.get_faces():
			if wall.to_local(mesh.global_transform * vertex).z < .065:
				return false
	return true

func _optic_open(rifle: Node3D) -> bool:
	var body: MeshInstance3D = rifle.model.find_child("Rifle_Body", true, false)
	var from := body.to_local(rifle.view_model.to_global(Vector3(0, .135, .18)))
	var to := body.to_local(rifle.view_model.to_global(Vector3(0, .135, -.30)))
	var faces: PackedVector3Array = body.mesh.get_faces()
	for index in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(from, to, faces[index], faces[index + 1], faces[index + 2]) != null:
			print("APERTURE BLOCKER ", Geometry3D.segment_intersects_triangle(from, to, faces[index], faces[index + 1], faces[index + 2]))
			return false
	return true

func _magazine_visible(rifle: Node3D, camera: Camera3D) -> bool:
	var mesh: MeshInstance3D = rifle.magazine
	var bounds: AABB = mesh.mesh.get_aabb()
	var rectangle := Rect2(camera.unproject_position(mesh.to_global(bounds.get_endpoint(0))), Vector2.ZERO)
	for index in range(1, 8):
		rectangle = rectangle.expand(camera.unproject_position(mesh.to_global(bounds.get_endpoint(index))))
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	var visible := rectangle.intersection(viewport)
	print("MAGAZINE FRAMING rect=", rectangle, " viewport=", viewport.size, " ratio=", visible.get_area() / maxf(rectangle.get_area(), 1))
	return rectangle.get_area() > 1 and visible.get_area() / rectangle.get_area() > .65

func _declared_materials(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	file.seek(12)
	var length := file.get_32()
	file.get_32()
	var document: Dictionary = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
	for mesh in document.meshes:
		for primitive in mesh.primitives:
			if not primitive.has("material"):
				return false
	return true

func _shoulders_anchored(arms: Node3D, camera: Camera3D) -> bool:
	for side in ["R", "L"]:
		var bone: int = arms.skeleton.find_bone(side + "_Upper")
		var point: Vector3 = arms.skeleton.to_global(arms.skeleton.get_bone_global_pose(bone).origin)
		var target := camera.to_global(Vector3(.22 if side == "R" else -.22, -.25, .01))
		if point.distance_to(target) > .002:
			return false
	return true

func _arm_lengths_valid(arms: Node3D) -> bool:
	for side in ["R", "L"]:
		var a: Vector3 = arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side + "_Upper")).origin
		var b: Vector3 = arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side + "_Forearm")).origin
		var c: Vector3 = arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side + "_Hand")).origin
		var lengths: Vector2 = arms.segment_lengths[side]
		if absf(a.distance_to(b) - lengths.x) > .004 or absf(b.distance_to(c) - lengths.y) > .004:
			return false
	return true

func _arm_clearance(arms: Node3D) -> float:
	var chains := []
	for side in ["L", "R"]:
		var chain := []
		for joint in ["Upper", "Forearm", "Hand"]:
			chain.append(arms.skeleton.to_global(arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side + "_" + joint)).origin))
		chains.append(chain)
	var result := INF
	for left in range(2):
		for right in range(2):
			var pair := Geometry3D.get_closest_points_between_segments(chains[0][left], chains[0][left + 1], chains[1][right], chains[1][right + 1])
			result = minf(result, pair[0].distance_to(pair[1]))
	return result

func _palm_facing(arms: Node3D, rifle: Node3D, entry: Dictionary, side: String, expected: Vector3) -> bool:
	var axis: Array = entry.palm_axes[side]
	var local := Vector3(axis[0], axis[1], axis[2])
	var bone: int = arms.skeleton.find_bone(side + "_Hand")
	var world: Vector3 = arms.skeleton.global_basis * arms.skeleton.get_bone_global_pose(bone).basis * local
	return (rifle.view_model.global_basis.inverse() * world).normalized().dot(expected) > .9

func _left_arm_stays_left(arms: Node3D, camera: Camera3D) -> bool:
	var hands := []
	for side in ["L", "R"]:
		var bone: int = arms.skeleton.find_bone(side + "_Hand")
		hands.append(camera.to_local(arms.skeleton.to_global(arms.skeleton.get_bone_global_pose(bone).origin)))
	return hands[0].x + .05 < hands[1].x

func _skin_stretch(arms: Node3D) -> float:
	var glove: MeshInstance3D = arms.find_child("Object_7", true, false)
	var baked: ArrayMesh = glove.bake_mesh_from_current_skeleton_pose()
	var largest := 0.0
	for surface in glove.mesh.get_surface_count():
		var original: Array = glove.mesh.surface_get_arrays(surface)
		var current: Array = baked.surface_get_arrays(surface)
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		var rest: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var posed: PackedVector3Array = current[Mesh.ARRAY_VERTEX]
		for triangle in range(0, indices.size(), 3):
			for corner in range(3):
				var a := indices[triangle + corner]
				var b := indices[triangle + (corner + 1) % 3]
				largest = maxf(largest, posed[a].distance_to(posed[b]) - rest[a].distance_to(rest[b]))
	print("GLOVE MAX EDGE LENGTH INCREASE ", largest)
	return largest

func _right_grip_error(arms: Node3D, rifle: Node3D) -> float:
	var wrist: Vector3 = arms.skeleton.to_global(arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone("R_Hand")).origin)
	return wrist.distance_to(rifle.right_grip_socket.global_position)
