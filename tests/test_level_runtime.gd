extends SceneTree

const Runtime = preload("res://scripts/game/level_runtime.gd")
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
	var data := Runtime.read_json("res://data/vertical_slice.json")
	var registry := Runtime.read_json("res://data/asset_registry.json")
	check(Runtime.validate_layout(data).is_empty(), "production layout validates")
	for mutation in ["seed", "socket", "duplicate", "variant", "budget", "spawn", "encounter", "axis", "bounds", "objective"]:
		var invalid := data.duplicate(true)
		match mutation:
			"seed": invalid.seed = 3.5
			"socket": invalid.decoration.sockets[0].position[0] = 0
			"duplicate": invalid.decoration.sockets[1].id = invalid.decoration.sockets[0].id
			"variant": invalid.decoration.variants = ["untrusted"]
			"budget": invalid.decoration.max_instances = 1000
			"spawn": invalid.player_spawn.position = [0, 0]
			"encounter": invalid.encounters[1].enemy_id = invalid.encounters[0].enemy_id
			"axis": invalid.axis_convention.up = "+Z"
			"bounds": invalid.bounds.z_end = 100
			"objective": invalid.objective.required_enemies = ["E99"]
		check(not Runtime.validate_layout(invalid).is_empty(), "invalid config rejected: " + mutation)
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("GameFlow").enabled = false
	scene.get_node("EncounterManager").enabled = false
	scene.get_node("Player/InputController").set_physics_process(false)
	scene.get_node("Player/InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in scene.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
	await process_frame
	var runtime = scene.get_node("LevelRuntime")
	check(runtime.validation_errors.is_empty(), "runtime source hash and JSON agree")
	var first: Array = runtime.decoration_manifest.duplicate(true)
	check(not first.is_empty() and first.size() <= 24, "bounded nonempty decoration generated")
	check(runtime.missing_assets.size() == 9, "nine missing GLBs reported and greybox fallback retained")
	var core := _core_snapshot(scene)
	var bodies := _physics_count(scene)
	var nodes := _node_count(scene)
	check(runtime.rebuild(data, registry) and runtime.decoration_manifest == first, "same seed reproduces IDs, positions, types and yaw")
	await process_frame
	check(_node_count(scene) == nodes, "repeat rebuild does not duplicate nodes")
	var safe := true
	for item in first:
		safe = safe and absf(item.position.x) >= 5.3 and item.position.y >= 3.2
	check(safe and _physics_count(runtime.decorations) == 0, "all decoration stays outside road with zero physics bodies")
	var stable := true
	var different := false
	for seed_value in range(20):
		runtime.seed_override = seed_value
		stable = stable and runtime.rebuild(data, registry)
		different = different or runtime.decoration_manifest != first
		stable = stable and _core_snapshot(scene) == core and _physics_count(scene) == bodies and runtime.decorations.get_child_count() <= 24
	check(stable and different, "20 seeds vary decoration while preserving every core marker/collider and bounded counts")
	runtime.seed_override = -1
	runtime.rebuild(data, registry)
	var before: Array = runtime.decoration_manifest.duplicate(true)
	check(not runtime.rebuild(data, {}) and runtime.decoration_manifest == before, "missing fallback fails before altering existing decoration")
	var moved_core := data.duplicate(true)
	moved_core.covers[0].position[0] = 0
	check(not runtime.rebuild(moved_core, registry) and _core_snapshot(scene) == core, "core edits require offline rebake and cannot silently change live gameplay")
	runtime.rebuild(data, registry)
	var slot = scene.get_node("Cover/cover_01/VisualSlot")
	var fallback: MeshInstance3D = scene.get_node("Cover/cover_01/Slab/Mesh")
	var swapped_registry := registry.duplicate(true)
	for entry in swapped_registry.entries:
		if entry.id == "cover_wall_A":
			entry.status = "ready"
			entry.proposed_path = "res://tests/fixtures/visual_only.glb"
	check(runtime.rebuild(data, swapped_registry) and slot.loaded_path == "res://tests/fixtures/visual_only.glb", "registry-only edit imports real GLB and replaces one visual slot")
	check(not fallback.visible and slot.get_child_count() == 1 and slot.loaded_path.ends_with(".glb"), "replacement hides greybox visuals only")
	check(_core_snapshot(scene) == core and _physics_count(scene) == bodies, "GLB replacement preserves all authored collision and gameplay markers")
	await physics_frame
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1.5, .5, -18), Vector3(-1.5, .5, -22), 3))
	check(not hit.is_empty() and scene.get_node("Cover/cover_01").is_ancestor_of(hit.collider), "replaced cover still blocks real weapon-layer ray")
	slot.apply_entry({"status": "ready", "proposed_path": "res://tests/fixtures/visual_only.glb"})
	await process_frame
	check(slot.get_child_count() == 1, "replacing GLB twice leaves exactly one model")
	check(not slot.apply_entry({"status": "ready", "proposed_path": "res://assets/models/absent.glb"}) and fallback.visible, "missing GLB restores greybox without losing collision")
	check(InputMap.action_get_events("debug_level")[0].physical_keycode == KEY_F3 and InputMap.action_get_events("debug_decoration")[0].physical_keycode == KEY_F4, "debug keys match actual engine F3/F4 constants")
	var debug = scene.get_node("LevelDebug")
	var key := InputEventAction.new()
	key.action = "debug_level"
	key.pressed = true
	debug._unhandled_input(key)
	print("DEBUG visible=", debug.canvas.visible, " geometry=", debug.overlay.get_child_count(), " label=", debug.label.text)
	check(debug.canvas.visible and debug.overlay.get_child_count() > 30 and debug.label.text.contains(str(int(data.seed))), "debug action shows real box colliders, markers and active seed")
	var debug_count: int = debug.overlay.get_child_count()
	debug._unhandled_input(key)
	debug._unhandled_input(key)
	check(debug.overlay.get_child_count() == debug_count and _physics_count(scene) == bodies, "debug toggles reuse nodes and never alter collision")
	key.action = "debug_decoration"
	debug._unhandled_input(key)
	check(not runtime.decorations.visible, "decoration action hides only visual decoration")
	debug._unhandled_input(key)
	await _capture("debug")
	debug.set_debug(false)
	await _capture("street")
	if "--render-checkpoints" in OS.get_cmdline_user_args():
		await _measure(scene, runtime)
	scene.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	print("TASK-006 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _core_snapshot(node: Node, result: Array = []) -> Array:
	# New array per top-level call; recursion passes the explicit shared accumulator.
	if node is StaticBody3D or node is Marker3D or node is Area3D:
		result.append([str(node.get_path()), node.global_transform])
	if node is CollisionShape3D:
		result.append([str(node.get_path()), node.global_transform, node.shape])
	for child in node.get_children():
		_core_snapshot(child, result)
	return result

func _physics_count(node: Node) -> int:
	var count := 1 if node is CollisionObject3D or node is CollisionShape3D else 0
	for child in node.get_children():
		count += _physics_count(child)
	return count

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count

func _capture(title: String) -> void:
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://logs/TASK-006-" + title + ".png") == OK, "actual render saved: " + title)

func _measure(scene: Node3D, runtime: Node3D) -> void:
	# Real wall-clock render samples, not fixed-fps simulation or a target-GPU claim.
	for visible_value in [false, true, false]:
		runtime.decorations.visible = visible_value
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
		print("RENDER SAMPLE 720p Medium decorations=", visible_value, " nodes=", _node_count(scene), " median_ms=", samples[90], " p95_ms=", samples[171], " max_ms=", samples[179])
	runtime.decorations.visible = true
