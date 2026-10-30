extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var campaign = load("res://scenes/game/Campaign.tscn").instantiate()
	root.add_child(campaign)
	current_scene = campaign
	while campaign.transitioning:
		await process_frame
	var old_level = campaign.active_level
	var weapon = old_level.get_node("Player/WeaponController")
	for i in range(5):
		weapon.cooldown = 0
		weapon.try_fire()
	campaign.restart_level()
	# Let the transition prepare a detached candidate and await audio cleanup.
	await process_frame
	print("CLOSE DURING TRANSITION prepared=", is_instance_valid(campaign.prepared_level), " voices=", old_level.get_node("BattlePresentation").sounds.get_child_count())
	old_level.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		await process_frame
	push_error("Window close failed to quit during transition")
	quit(1)
