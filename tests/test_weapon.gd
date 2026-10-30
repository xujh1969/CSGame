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
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node3D = packed.instantiate()
	root.add_child(scene)
	scene.get_node("Player/InputController").set_physics_process(false)
	var weapon = scene.get_node("Player/WeaponController")
	weapon.set_physics_process(false)
	weapon.hip_spread = 0.0
	await physics_frame
	await physics_frame

	check(weapon.magazine == 30 and weapon.reserve == 90, "initial ammo 30/90")
	for shot in range(10):
		check(weapon.try_fire(), "shot %d accepted" % (shot + 1))
		weapon.advance(weapon.fire_interval)
	check(weapon.magazine == 20 and weapon.reserve == 90, "10 shots produce 20/90")
	check(weapon.request_reload(), "reload begins")
	check(not weapon.request_reload(), "repeated R does not restart/stack reload")
	check(not weapon.try_fire(), "shooting during reload is rejected")
	weapon.advance(weapon.reload_duration)
	check(weapon.magazine == 30 and weapon.reserve == 80, "reload produces 30/80")
	check(weapon.try_fire() and not weapon.try_fire(), "cooldown rejects a second immediate shot")
	weapon.magazine = 0
	weapon.reserve = 0
	weapon.cooldown = 0.0
	check(not weapon.try_fire(), "empty magazine cannot fire")
	check(not weapon.request_reload(), "empty reserve cannot reload")
	weapon.magazine = 28
	weapon.reserve = 5
	weapon.request_reload()
	weapon.advance(weapon.reload_duration)
	check(weapon.magazine == 30 and weapon.reserve == 3, "partial reload transfers only missing rounds")
	weapon.set_controls(false, true, false, true)
	check(not weapon.aiming, "sprint blocks ADS")
	weapon.set_controls(false, true, false, false)
	check(weapon.aiming, "ADS available outside sprint")

	var nearest: Dictionary = weapon.trace_shot(Vector3(0, 0.6, 0), Vector3.FORWARD, Vector3(0, 0.5, -0.4))
	check(nearest.get("collider") == scene.get_node("Barricade"), "low ray first hits nearest barricade")
	nearest = weapon.trace_shot(Vector3(0, 1.7, 0), Vector3.FORWARD, Vector3(0, 1.6, -0.4))
	check(nearest.get("collider") == scene.get_node("ShotBlocker"), "standing ray hits solid wall before covered target")
	nearest = weapon.trace_shot(Vector3(0, 1.7, -9.5), Vector3.FORWARD, Vector3(0, 1.7, -10.5))
	check(nearest.get("collider") == scene.get_node("ShotBlocker"), "muzzle beyond wall cannot bypass wall")
	nearest = weapon.trace_shot(Vector3(-2.5, 1.2, 0), Vector3.FORWARD, Vector3(-2.5, 1.1, -0.4))
	check(nearest.get("collider") == scene.get_node("ExposedTarget"), "unblocked ray hits exposed target")

	var camera: Camera3D = scene.get_node("Player/Camera3D")
	weapon.reset_weapon()
	camera.global_position = Vector3(0, 1.7, 0)
	camera.rotation = Vector3.ZERO
	weapon.try_fire()
	check(scene.get_node("CoveredTarget/HealthComponent").current_health == 100, "firing at wall does not damage covered target")
	weapon.advance(weapon.fire_interval)
	camera.global_position = Vector3(-2.5, 1.2, 0)
	camera.rotation = Vector3.ZERO
	weapon.try_fire()
	check(scene.get_node("ExposedTarget/HealthComponent").current_health == 75, "unblocked shot applies 25 damage")

	weapon.request_reload()
	scene.queue_free()
	await process_frame
	var restarted: Node3D = packed.instantiate()
	root.add_child(restarted)
	restarted.get_node("Player/InputController").set_physics_process(false)
	var fresh = restarted.get_node("Player/WeaponController")
	fresh.set_physics_process(false)
	await physics_frame
	check(fresh.magazine == 30 and fresh.reserve == 90 and not fresh.reloading, "scene rebuild cancels reload and restores 30/90")
	check(restarted.get_node("ExposedTarget/HealthComponent").current_health == 100, "scene rebuild restores target health")
	restarted.queue_free()
	await process_frame
	print("TASK-002 failures: ", failures)
	quit(0 if failures == 0 else 1)
