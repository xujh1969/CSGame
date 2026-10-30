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

func _fixture() -> Node3D:
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("EncounterManager").enabled = false
	scene.get_node("GameFlow").enabled = false
	scene.get_node("Player/InputController").set_physics_process(false)
	scene.get_node("Player/InputController").set_process_unhandled_input(false)
	scene.get_node("Player/WeaponController").set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for enemy in scene.get_node("Enemies").get_children():
		enemy.set_physics_process(false)
		enemy.get_node("EnemyWeapon").spread = 0.0
	await physics_frame
	await physics_frame
	return scene

func _tick(enemies: Array, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		for enemy in enemies:
			enemy.step(1.0 / 60.0)

func _place_player(scene: Node3D, point: Vector3) -> void:
	scene.get_node("Player").position = point
	scene.get_node("Player").velocity = Vector3.ZERO
	await physics_frame
	await physics_frame

func _run() -> void:
	var scene: Node3D = await _fixture()
	var enemies := scene.get_node("Enemies")
	var e1 = enemies.get_node("E01")
	var e2 = enemies.get_node("E02")
	var e3 = enemies.get_node("E03")
	var manager = scene.get_node("EncounterManager")
	var player = scene.get_node("Player")
	check(enemies.get_child_count() == 3, "exactly three enemies preplaced at scene load")
	for enemy in enemies.get_children():
		check(enemy.get_state() == &"DORMANT" and enemy.activation_count == 0, str(enemy.name) + " starts dormant")
		check(enemy.position.is_equal_approx(scene.get_node("SpawnMarkers/" + str(enemy.name)).position), str(enemy.name) + " initially occupies editor marker")

	var counts := {"started": 0, "cleared": 0, "died": 0}
	manager.encounter_started.connect(func(_id): counts.started += 1)
	manager.encounter_cleared.connect(func(_id): counts.cleared += 1)
	manager.enabled = true
	await _place_player(scene, Vector3(0, 0, -12))
	for i in range(30):
		await physics_frame
		player.move_player(Vector2(0, -1), false, false, 1.0 / 60.0)
	check(manager.started.has(&"T1") and e1.activation_count == 1, "physical T1 crossing activates E01")
	await _place_player(scene, Vector3(0, 0, -11))
	await _place_player(scene, Vector3(0, 0, -13))
	for i in range(5):
		manager.activate_encounter(&"T1")
	check(e1.activation_count == 1 and counts.started == 1 and enemies.get_child_count() == 3, "repeat T1 entry/calls do not respawn or duplicate activation")
	manager.enabled = false

	await _place_player(scene, Vector3(0, 0, -15))
	var path := NavigationServer3D.map_get_path(e1.get_node("NavigationAgent3D").get_navigation_map(), e1.position, e1.peek_marker.position, true)
	check(path.size() >= 2, "baked corner navigation provides a path to peek point")
	var min_x: float = e1.position.x
	var largest_step := 0.0
	var saw_burst := false
	var saw_cover := false
	var captured_corner := false
	for i in range(250):
		var before: Vector3 = e1.position
		await _tick([e1], 1)
		min_x = minf(min_x, e1.position.x)
		largest_step = maxf(largest_step, Vector2(e1.position.x - before.x, e1.position.z - before.z).length())
		saw_burst = saw_burst or e1.get_state() == &"FIRE_BURST"
		saw_cover = saw_cover or e1.get_state() == &"SEEK_COVER"
		if e1.get_state() == &"FIRE_BURST" and e1.weapon.shots_fired > 0 and not captured_corner:
			await _capture(scene, "corner-fire", e1.global_position + Vector3.UP * 1.3)
			captured_corner = true
	print("Corner diagnostics: min_x=", min_x, " largest_step=", largest_step, " position=", e1.position, " state=", e1.get_state(), " nav_path=", e1.navigation.get_current_navigation_path())
	check(min_x < 3.2 and largest_step < 0.06, "E01 physically approaches corner edge without teleporting")
	check(saw_burst and saw_cover, "E01 performs finite burst then seeks cover")
	check(e1.position.distance_to(e1.cover_marker.position) < 0.25, "E01 navigation returns to sidewalk cover")
	check(is_equal_approx(e2.get_node("CollisionShape3D").shape.height, 1.0), "enemy stance shapes are independent between instances")

	await _place_player(scene, Vector3(0, 0, -35))
	manager.enabled = true
	check(manager.activate_encounter(&"T2"), "T2 activates fixed window sentry")
	manager.enabled = false
	var initial_window: Vector3 = e2.position
	await _tick([e2], 23)
	check(e2.weapon.shots_fired == 0, "no enemy shot during first 0.4s reaction window")
	await _capture(scene, "window-alert", e2.global_position + Vector3.UP * 1.3)
	var first_shot_frame := -1
	for i in range(100):
		await _tick([e2], 1)
		if e2.weapon.shots_fired > 0:
			first_shot_frame = i + 24
			break
	check(first_shot_frame >= 60, "window sentry waits for alert and aim before firing")
	check(e2.weapon.player_hits > 0, "visible player receives real ray damage")
	var gun_direction: Vector3 = -e2.weapon.muzzle.global_basis.z
	check(gun_direction.angle_to((e2.perception.target_point() - e2.weapon.muzzle.global_position).normalized()) < 0.03, "window gun visibly aims down toward player")
	check(e2.position.distance_to(initial_window) < 0.02 and not e2.has_node("NavigationAgent3D"), "window sentry remains on platform without floor navigation")
	print("Window first shot at seconds: ", first_shot_frame / 60.0)
	await _capture(scene, "window-fire", e2.global_position + Vector3.UP * 1.3)

	var wall := StaticBody3D.new()
	wall.name = "TestSolidWall"
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 8, 0.5)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	scene.add_child(wall)
	wall.position = Vector3(-2.7, 3.8, -40.5)
	await physics_frame
	await physics_frame
	check(not e2.perception.can_see_target(), "solid wall blocks enemy LOS")
	var hp_before: int = player.get_node("HealthComponent").current_health
	var shots_before: int = e2.weapon.shots_fired
	var last_known: Vector3 = e2.last_known_position
	await _place_player(scene, Vector3(0.4, 0, -35))
	await _tick([e2], 300)
	check(player.get_node("HealthComponent").current_health == hp_before and e2.weapon.shots_fired == shots_before, "wall stops attacks and damage for five simulated seconds")
	check(e2.last_known_position.is_equal_approx(last_known), "occluded player is not tracked through wall")
	check(not e2.weapon.fire_at(player.get_node("Camera3D").global_position), "enemy weapon rechecks LOS before each shot")
	wall.queue_free()
	await physics_frame
	await physics_frame
	await _place_player(scene, Vector3(-5.4, 0, -54))
	check(not e2.perception.can_see_target(), "window sentry does not see player behind its facing arc")

	await _place_player(scene, Vector3(0, 0, -60))
	check(not e3.perception.can_see_target(), "dormant E03 crouches behind real low-wall collision")
	manager.enabled = true
	check(manager.activate_encounter(&"T3"), "T3 activates cover rifleman")
	manager.enabled = false
	var stood := false
	var ducked_after_fire := false
	var captured_cover := false
	for i in range(200):
		await _tick([e3], 1)
		var height: float = e3.get_node("CollisionShape3D").shape.height
		stood = stood or height > 1.7
		if height > 1.7 and not captured_cover:
			await _capture(scene, "cover-alert", e3.global_position + Vector3.UP * 1.3)
			captured_cover = true
		if e3.weapon.shots_fired > 0 and height < 1.05:
			ducked_after_fire = true
	check(stood and ducked_after_fire and e3.weapon.shots_fired >= 3, "E03 stands for burst then crouches behind cover")

	await _place_player(scene, Vector3(0, 0, -65))
	e3._transition(e3.State.AIM)
	e3._update_pose(1.0)
	await physics_frame
	var player_weapon = player.get_node("WeaponController")
	player_weapon.hip_spread = 0.0
	e3.health.actor_died.connect(func(_id): counts.died += 1)
	var health_e1: int = e1.health.current_health
	for i in range(4):
		player.get_node("Camera3D").look_at(e3.global_position + Vector3.UP * 1.5)
		player_weapon.cooldown = 0.0
		check(player_weapon.try_fire(), "player shot against enemy accepted: " + str(i + 1))
		await physics_frame
	check(e3.health.current_health == 0 and e3.get_state() == &"DEAD", "four actual player shots kill 100HP enemy")
	check(e1.health.current_health == health_e1, "enemy health is not shared")
	e3.apply_damage(200)
	var dead_shots: int = e3.weapon.shots_fired
	await _tick([e3], 240)
	check(counts.died == 1 and counts.cleared == 1 and manager.cleared.has(&"T3"), "death and encounter-cleared each emit once")
	check(e3.weapon.shots_fired == dead_shots and e3.get_node("CollisionShape3D").disabled, "dead enemy cannot fire and hit collision is disabled")
	await _place_player(scene, Vector3(0, 0, -72))
	await _capture(scene, "enemy-dead", e3.global_position + Vector3.UP * 0.4)

	await _place_player(scene, Vector3(0, 0, -35))
	check(e2.perception.can_see_target(), "player death test begins with valid enemy LOS")
	player_weapon.request_reload()
	player_weapon.advance(0.5)
	var death_magazine: int = player_weapon.magazine
	var death_reserve: int = player_weapon.reserve
	player_weapon.trigger_held = true
	player.get_node("HealthComponent").apply_damage(100)
	check(not player_weapon.trigger_held and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "player death stops held fire and releases mouse")
	player_weapon.advance(3.0)
	check(not player_weapon.reloading and player_weapon.magazine == death_magazine and player_weapon.reserve == death_reserve, "player death cancels reload without transferring ammo")
	shots_before = e2.weapon.shots_fired
	await _tick([e2], 180)
	check(e2.weapon.shots_fired == shots_before, "enemies stop attacking a downed player")
	await _capture(scene, "player-down", e2.global_position + Vector3.UP * 1.3)
	scene.queue_free()
	await process_frame
	scene = await _fixture()
	manager = scene.get_node("EncounterManager")
	check(manager.started.is_empty() and manager.cleared.is_empty() and scene.get_node("Enemies").get_child_count() == 3, "scene restart resets encounters and enemy count")
	for enemy in scene.get_node("Enemies").get_children():
		check(enemy.health.current_health == 100 and enemy.get_state() == &"DORMANT" and enemy.weapon.shots_fired == 0, str(enemy.name) + " restart restores health, state and weapon")
	check(scene.get_node("Player/HealthComponent").current_health == 100 and scene.get_node("Player/WeaponController").magazine == 30 and not scene.get_node("Player/WeaponController").reloading, "restart restores player health, ammo and reload state")
	var dormant = scene.get_node("Enemies/E02")
	dormant.apply_damage(100)
	manager.enabled = true
	check(manager.cleared.has(&"T2") and not manager.activate_encounter(&"T2"), "enemy killed before activation stays cleared without respawning")
	scene.queue_free()
	await process_frame
	print("TASK-004 failures: ", failures)
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(self)
	quit(0 if failures == 0 else 1)

func _capture(scene: Node3D, title: String, look_target: Vector3) -> void:
	if not "--render-checkpoints" in OS.get_cmdline_user_args():
		return
	var camera: Camera3D = scene.get_node("Player/Camera3D")
	var original := camera.rotation
	camera.look_at(look_target)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://logs/TASK-004-" + title + ".png")
	check(error == OK, "render checkpoint saved: " + title)
	camera.rotation = original
