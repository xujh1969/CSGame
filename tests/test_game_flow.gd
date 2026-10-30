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

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _fixture() -> Node3D:
	paused = false
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("Player/InputController").set_physics_process(false)
	scene.get_node("Player/InputController").set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(3)
	return scene

func _run() -> void:
	var scene := await _fixture()
	var flow = scene.get_node("GameFlow")
	var player = scene.get_node("Player")
	var weapon = player.get_node("WeaponController")
	var hud = player.get_node("WeaponHUD")
	var presentation = scene.get_node("BattlePresentation")
	check(flow.state == flow.State.RUNNING and not paused, "new scene starts running")
	check(hud.get_node("Ammo").text.contains("30") and hud.get_node("HealthBar").value == 100, "HUD initializes from real ammo and health")
	check(hud.get_node("Objective").text.contains("0 / 3"), "HUD shows initial encounter objective")
	for i in range(10):
		weapon.cooldown = 0
		weapon.try_fire()
	check(weapon.magazine == 20 and hud.get_node("Ammo").text.begins_with("20"), "ten real shots update HUD to 20/90")
	check(presentation.flash.remaining > 0 and presentation.effects.get_child_count() > 0, "effective firing emits muzzle flash and impact/smoke")
	check(presentation.streams.size() == 9, "nine synthesized audio streams load")
	var valid_audio := true
	for sound in presentation.sounds.get_children():
		valid_audio = valid_audio and sound is AudioStreamPlayer3D and sound.max_distance > 0 and sound.max_distance <= 35
	check(valid_audio and presentation.sounds.get_child_count() <= 12, "3D audio has bounded distance and voice budget")
	weapon.request_reload()
	scene.get_node("EncounterManager").activate_encounter(&"T2")
	await _frames(30)
	var reload_time: float = weapon.reload_remaining
	var enemy_timer: float = scene.get_node("Enemies/E02").remaining
	var player_before: Vector3 = player.position
	flow.toggle_pause()
	await _capture("pause-720")
	await _frames(120)
	check(paused and flow.state == flow.State.PAUSED, "pause freezes scene tree")
	check(is_equal_approx(weapon.reload_remaining, reload_time) and weapon.magazine == 20, "pause freezes reload without transferring ammo")
	check(player.position.is_equal_approx(player_before), "pause freezes player physics")
	check(is_equal_approx(scene.get_node("Enemies/E02").remaining, enemy_timer), "pause freezes active enemy reaction timer")
	check(hud.get_node("Overlay").visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pause menu visible with released mouse")
	hud.get_node("Overlay/Panel/Margin/Column/Quality").select(1)
	hud.get_node("Overlay/Panel/Margin/Column/Quality").item_selected.emit(1)
	await _frames(2)
	presentation._effect(&"smoke", Vector3(0, 1, 0), Vector3.UP)
	presentation._effect(&"concrete", Vector3(0, 1, 0), Vector3.UP)
	check(presentation.effects.get_child_count() == 0 and not scene.get_node("Sun").shadow_enabled, "low quality disables smoke/dust and dynamic shadows")
	for i in range(20):
		presentation._effect(&"metal", Vector3(0, 1, -5), Vector3.BACK)
	check(presentation.effects.get_child_count() <= 6, "low-quality essential spark effects stay within six instances")
	var spark = presentation.effects.get_child(0)
	check(spark.global_position.z > -5, "impact effect is offset to front of hit normal")
	hud.get_node("Overlay/Panel/Margin/Column/Quality").select(0)
	hud.get_node("Overlay/Panel/Margin/Column/Quality").item_selected.emit(0)
	flow.toggle_pause()
	await _frames(140)
	print("Resume diagnostic: backend=", DisplayServer.get_name(), " state=", flow.state, " paused=", paused, " mouse_mode=", Input.mouse_mode)
	check(not paused and flow.state == flow.State.RUNNING, "resume restores running game")
	if DisplayServer.get_name() == "headless":
		print("UNVERIFIED in headless backend: OS mouse capture; checked by graphical run")
	else:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "graphical resume restores OS mouse capture")
	check(weapon.magazine == 30 and weapon.reserve == 80 and not weapon.reloading, "resumed reload completes exactly to 30/80")
	player.get_node("HealthComponent").apply_damage(8)
	check(hud.get_node("HealthBar").value == 92 and hud.damage_time > 0, "damage updates real HP and visible flash")
	await _capture("hud-720")
	root.size = Vector2i(1920, 1080)
	await _frames(2)
	flow.toggle_pause()
	await _capture("pause-1080")
	var panel: Control = hud.get_node("Overlay/Panel")
	check(panel.get_global_rect().end.x <= root.size.x and panel.get_global_rect().end.y <= root.size.y, "pause panel remains inside 1080p viewport")
	flow.toggle_pause()
	root.size = Vector2i(1280, 720)

	scene = await _fixture()
	flow = scene.get_node("GameFlow")
	player = scene.get_node("Player")
	hud = player.get_node("WeaponHUD")
	player.position = Vector3(0, 0, -78)
	await _frames(3)
	check(flow.state == flow.State.RUNNING, "finish area alone cannot win before enemies cleared")
	var outcomes := {"won": 0, "failed": 0}
	flow.state_changed.connect(func(value):
		if value == &"WON": outcomes.won += 1
		if value == &"FAILED": outcomes.failed += 1)
	for enemy in scene.get_node("Enemies").get_children():
		enemy.apply_damage(100)
	player.get_node("HealthComponent").apply_damage(100)
	await _frames(3)
	check(flow.state == flow.State.FAILED and outcomes.failed == 1 and outcomes.won == 0, "same-frame death takes priority over victory and resolves once")
	check(paused and hud.get_node("Overlay/Panel/Margin/Column/Title").text == "行动失败", "failure freezes combat and shows retry screen")
	await _capture("failed")
	flow.toggle_pause()
	flow._on_finish_entered(player)
	await _frames(2)
	check(flow.state == flow.State.FAILED and outcomes.failed == 1, "terminal failure cannot be resumed or replaced by victory")
	hud.get_node("Overlay/Panel/Margin/Column/Retry").pressed.emit()
	await _frames(4)
	scene = current_scene
	check(not paused and scene.get_node("GameFlow").state == 0, "retry button rebuilds running scene")
	check(scene.get_node("Player/HealthComponent").current_health == 100 and scene.get_node("Player/WeaponController").magazine == 30, "retry resets player health and ammo")
	check(scene.get_node("EncounterManager").cleared.is_empty() and scene.get_node("Enemies").get_child_count() == 3, "retry resets encounters and three dormant enemies")

	# Run the whole route using the original motor, real triggers, AI and weapon rays.
	scene = await _fixture()
	flow = scene.get_node("GameFlow")
	player = scene.get_node("Player")
	weapon = player.get_node("WeaponController")
	weapon.hip_spread = 0.0
	var route := scene.get_node("Route").get_children()
	for index in range(1, route.size()):
		var reached := await _walk_to(scene, route[index].global_position)
		check(reached, "full gameplay route reaches point " + str(index))
		if not reached:
			break
		var enemy_id: String = {1: "E01", 3: "E02", 5: "E03"}.get(index, "")
		if enemy_id != "":
			var killed := await _defeat(scene, scene.get_node("Enemies/" + enemy_id))
			check(killed, "real player shots clear " + enemy_id)
			if index == 1:
				for shot in range(6):
					await _frames(8)
					player.get_node("Camera3D").look_at(player.position + Vector3(0, 0, -5))
					weapon.try_fire()
				check(weapon.magazine == 20 and weapon.reserve == 90, "full cycle spends ten rounds before reload")
				weapon.request_reload()
				await _frames(140)
				check(weapon.magazine == 30 and weapon.reserve == 80, "full cycle reload transfers correct reserve")
			player.get_node("Camera3D").rotation = Vector3.ZERO
	check(scene.get_node("EncounterManager").cleared.size() == 3, "full route clears all three encounters")
	await _frames(3)
	check(flow.state == flow.State.WON and paused and player.get_node("HealthComponent").current_health > 0, "alive player reaches actual finish area and wins")
	check(player.get_node("WeaponHUD/Overlay/Panel/Margin/Column/Title").text == "街段已清除", "victory screen matches true game outcome")
	presentation = scene.get_node("BattlePresentation")
	check(presentation.sounds.get_child_count() == 1 and presentation.sounds.get_child(0).stream == presentation.streams["victory"], "victory cue replaces combat voices even at voice budget")
	await _capture("victory")
	flow.restart()
	await _frames(4)
	check(current_scene.get_node("GameFlow").state == 0 and not paused, "victory replay starts a fresh running scene")
	paused = false
	current_scene.queue_free()
	await process_frame
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	print("TASK-005 failures: ", failures)
	quit(0 if failures == 0 else 1)

func _walk_to(scene: Node3D, goal: Vector3) -> bool:
	var player = scene.get_node("Player")
	var flow = scene.get_node("GameFlow")
	for frame in range(1000):
		if flow.state == flow.State.WON:
			return true
		if flow.state != flow.State.RUNNING:
			return false
		var direction: Vector3 = goal - player.position
		direction.y = 0
		if direction.length() < 0.12:
			return true
		await physics_frame
		direction = direction.normalized()
		player.move_player(Vector2(direction.x, direction.z), false, false, 1.0 / 60.0)
	return false

func _defeat(scene: Node3D, enemy: Node3D) -> bool:
	var player = scene.get_node("Player")
	var weapon = player.get_node("WeaponController")
	for frame in range(240):
		await physics_frame
		if not enemy.is_alive():
			return true
		if player.get_node("HealthComponent").current_health <= 0:
			return false
		if enemy.get_node("CollisionShape3D").shape.height < 1.7:
			continue
		var camera: Camera3D = player.get_node("Camera3D")
		camera.look_at(enemy.global_position + Vector3.UP * 1.3)
		var result: Dictionary = weapon.trace_shot(camera.global_position, -camera.global_basis.z, weapon.muzzle.global_position)
		if result.get("collider") == enemy:
			weapon.try_fire()
	return not enemy.is_alive()

func _capture(title: String) -> void:
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://logs/TASK-005-" + title + ".png") == OK, "render saved: " + title)
