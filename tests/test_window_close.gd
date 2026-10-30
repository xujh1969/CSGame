extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.get_node("Player/InputController").set_physics_process(false)
	for i in range(5):
		scene.get_node("Player/WeaponController").cooldown = 0
		scene.get_node("Player/WeaponController").try_fire()
	await process_frame
	print("Close-request test: active spatial audio voices=", scene.get_node("BattlePresentation/Sounds").get_child_count())
	scene.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var deadline := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	push_error("FAIL: window-close handler did not exit")
	quit(1)
