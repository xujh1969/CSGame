extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/game/level_catalog.gd") or not ResourceLoader.exists("res://scenes/game/Campaign.tscn"):
		check(false, "campaign implementation and scene exist")
		quit(1)
		return
	var catalog = load("res://scripts/game/level_catalog.gd")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign.json"))
	check(catalog.validate(data).is_empty(), "production level catalog validates")
	for mutation in ["duplicate", "scene", "next", "cycle", "start", "encounter"]:
		var invalid := data.duplicate(true)
		match mutation:
			"duplicate": invalid.levels[1].id = invalid.levels[0].id
			"scene": invalid.levels[0].scene_path = "res://missing.tscn"
			"next": invalid.levels[0].next_id = "absent"
			"cycle": invalid.levels[1].next_id = invalid.levels[0].id
			"start": invalid.start_id = "absent"
			"encounter": invalid.levels[0].required_encounters = ["A1", "A1"]
		check(not catalog.validate(invalid).is_empty(), "invalid catalog rejected: " + mutation)
	var campaign = load("res://scenes/game/Campaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await _settle(campaign)
	check(campaign.current_id == "entry" and campaign.load_count == 1, "campaign boots first level exactly once")
	var incomplete = load(data.levels[0].scene_path).instantiate()
	incomplete.get_node("EncounterManager").free()
	check(campaign._level_error(incomplete, data.levels[0]).contains("EncounterManager"), "incomplete PackedScene is rejected before ready")
	incomplete.free()
	await _capture("entry-start")
	await _sample_frames("entry-idle")
	await _play_level(campaign, "first")
	var old_level = weakref(campaign.active_level)
	var old_audio = weakref(campaign.active_level.get_node("BattlePresentation"))
	var count: int = campaign.load_count
	check(campaign.has_next_level() and campaign.active_level.get_node("Player/WeaponHUD/Overlay/Panel/Margin/Column/Next").visible, "first victory displays next-level button")
	campaign.active_level.get_node("Player/WeaponHUD/Overlay/Panel/Margin/Column/Next").pressed.emit()
	check(campaign.transitioning, "victory button starts transition to next level")
	check(not campaign.next_level() and not campaign.restart_level(), "duplicate next/retry is rejected during transition")
	await _settle(campaign)
	check(campaign.current_id == "yard" and campaign.load_count == count + 1, "next loads second level once")
	check(old_level.get_ref() == null and old_audio.get_ref() == null, "old level and spatial audio owner are freed")
	var second = campaign.active_level
	_freeze_input(second)
	await _sample_frames("yard-idle")
	check(second.get_node("Player/HealthComponent").current_health == 100 and second.get_node("Player/WeaponController").magazine == 30 and second.get_node("Player/WeaponController").reserve == 90, "new level starts HP100 and 30/90")
	check(not paused and second.get_node("GameFlow").state == 0, "new level resets pause and starts running")
	check(not campaign.next_level(), "cannot skip running level")
	second.get_node("Player/HealthComponent").apply_damage(100)
	await process_frame
	await process_frame
	check(second.get_node("GameFlow").state == 2 and paused, "second level can fail independently")
	await _capture("yard-failed")
	var old_enemy = weakref(second.get_node("Enemies/BGuard"))
	second.get_node("Player/WeaponHUD/Overlay/Panel/Margin/Column/Retry").pressed.emit()
	await _settle(campaign)
	check(campaign.current_id == "yard" and old_enemy.get_ref() == null, "failure retry rebuilds current level, not campaign start")
	check(campaign.active_level.get_node("Player/HealthComponent").current_health == 100 and campaign.active_level.get_node("EncounterManager").cleared.is_empty(), "retry restores player and encounter state")
	await _play_level(campaign, "final")
	check(not campaign.has_next_level() and not campaign.next_level(), "final level has no next level")
	var column = campaign.active_level.get_node("Player/WeaponHUD/Overlay/Panel/Margin/Column")
	check(not column.get_node("Next").visible and column.get_node("Title").text.contains("完成"), "final victory UI shows completion without next button")
	var unchanged = campaign.active_level
	check(not campaign.request_level("absent") and campaign.active_level == unchanged, "unknown level request preserves current level")
	var base_nodes := 0
	var stable := true
	for i in range(4):
		var previous = weakref(campaign.active_level)
		campaign.restart_level()
		await _settle(campaign)
		_freeze_input(campaign.active_level)
		var current_nodes := _node_count(campaign)
		if i == 0:
			base_nodes = current_nodes
		stable = stable and previous.get_ref() == null and current_nodes == base_nodes and get_nodes_in_group("game_flow").size() == 1 and get_nodes_in_group("battle_presentation").size() == 1
	check(stable, "four restarts keep one level, flow and audio owner without node growth")
	var flow = campaign.active_level.get_node("GameFlow")
	flow.toggle_pause()
	check(paused, "current level pauses")
	flow.restart()
	await _settle(campaign)
	check(not paused and campaign.current_id == "yard", "paused retry resets pause while preserving current level id")
	var retained = campaign.active_level
	campaign.definitions.entry.required_encounters = ["missing_trigger"]
	campaign.request_level("entry")
	var deadline := Time.get_ticks_msec() + 3000
	while campaign.transitioning and Time.get_ticks_msec() < deadline:
		await process_frame
	check(campaign.last_error.contains("Missing encounter trigger") and campaign.active_level == retained and paused, "bad encounter relation reports error and retains paused current level")
	check(campaign.get_node("Status/Block").visible, "load error has a visible recovery screen")
	await _capture("load-error")
	campaign.definitions.entry = data.levels[0].duplicate(true)
	campaign.get_node("Status/Block/Center/Panel/Margin/Column/Retry").pressed.emit()
	await _settle(campaign)
	check(campaign.current_id == "entry" and not paused, "corrected config can retry load from error UI")
	var sizes := {}
	var cross_stable := true
	for id in ["yard", "entry", "yard", "entry"]:
		var prior = weakref(campaign.active_level)
		campaign.request_level(id)
		await _settle(campaign)
		_freeze_input(campaign.active_level)
		var size := _node_count(campaign)
		if not sizes.has(id):
			sizes[id] = size
		cross_stable = cross_stable and prior.get_ref() == null and sizes[id] == size and campaign.get_node("LevelHost").get_child_count() == 1
	check(cross_stable, "repeated A/B loading frees old worlds with stable per-level node counts")
	print("CAMPAIGN load_count=", campaign.load_count, " stable_nodes=", base_nodes, " static_memory_bytes=", Performance.get_monitor(Performance.MEMORY_STATIC))
	campaign.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	var invalid_campaign = load("res://scenes/game/Campaign.tscn").instantiate()
	invalid_campaign.catalog_path = "res://data/missing-campaign.json"
	root.add_child(invalid_campaign)
	await process_frame
	await process_frame
	check(not invalid_campaign.last_error.is_empty() and invalid_campaign.active_level == null and invalid_campaign.load_count == 0, "missing catalog fails explicitly without spawning a level")
	invalid_campaign.queue_free()
	await process_frame
	print("TASK-007 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _settle(campaign: Node) -> void:
	# Fixed-fps tests can execute thousands of frames before one real audio mix.
	var deadline := Time.get_ticks_msec() + 5000
	while campaign.transitioning and Time.get_ticks_msec() < deadline:
		await process_frame
	await process_frame
	check(not campaign.transitioning and campaign.last_error.is_empty(), "transition completes without error")

func _freeze_input(level: Node) -> void:
	level.get_node("Player/InputController").set_physics_process(false)
	level.get_node("Player/InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _play_level(campaign: Node, checkpoint: String) -> void:
	var level = campaign.active_level
	_freeze_input(level)
	var player = level.get_node("Player")
	var weapon = player.get_node("WeaponController")
	weapon.hip_spread = 0.0
	var enemy = level.get_node("Enemies").get_child(0)
	var frames := 0
	var reached := true
	var real_shots := 0
	for point in level.get_node("Route").get_children():
		var segment := 0
		while Vector2(player.position.x - point.position.x, player.position.z - point.position.z).length() > .15 and segment < 600:
			await physics_frame
			if paused:
				break
			var direction: Vector3 = point.position - player.position
			direction.y = 0
			player.move_player(Vector2(direction.normalized().x, direction.normalized().z), false, false, 1.0 / 60)
			if enemy.active and enemy.is_alive():
				var target: Vector3 = enemy.global_position + Vector3.UP * 1.4
				player.get_node("Camera3D").look_at(target)
				if weapon.try_fire():
					real_shots += 1
			segment += 1
			frames += 1
		reached = reached and segment < 600
	await process_frame
	await process_frame
	check(reached and not enemy.is_alive() and real_shots >= 4, checkpoint + " real trigger, player rays and physical walk clear enemy")
	check(level.get_node("GameFlow").state == 3 and player.get_node("HealthComponent").current_health > 0, checkpoint + " physical finish area produces alive victory")
	check(level.get_node("FinishArea").get_overlapping_bodies().has(player), checkpoint + " player actually overlaps finish trigger")
	await _capture(checkpoint)
	print("ROUTE ", checkpoint, " frames=", frames, " shots=", real_shots, " hp=", player.get_node("HealthComponent").current_health)

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
	check(root.get_texture().get_image().save_png("res://logs/TASK-007-" + title + ".png") == OK, "actual render saved: " + title)

func _sample_frames(title: String) -> void:
	if not "--measure-performance" in OS.get_cmdline_user_args():
		return
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
	print("RENDER SAMPLE ", title, " 720p Medium median_ms=", samples[90], " p95_ms=", samples[171], " max_ms=", samples[179], " GPU=", RenderingServer.get_video_adapter_name())
