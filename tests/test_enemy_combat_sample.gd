extends SceneTree

var failures:=0

func check(ok:bool,label:String)->void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1

func _initialize()->void:
	_run.call_deferred()

func _run()->void:
	var scene=load("res://scenes/levels/art/EnemyCombatSample.tscn").instantiate()
	root.add_child(scene)
	for i in 5:await physics_frame
	var enemy=scene.get_node("Enemies/AGuard")
	var peek:Vector3=enemy.peek_marker.global_position
	var cover:Vector3=enemy.cover_marker.global_position
	var navigation=enemy.get_node("NavigationAgent3D")
	var path:=NavigationServer3D.map_get_path(navigation.get_navigation_map(),enemy.global_position,peek,true)
	check(peek.distance_to(cover)>1.0,"peek and cover points are distinct")
	check(path.size()>=2,"baked sample navigation reaches the peek point")
	enemy.set_physics_process(false)
	for i in 360:
		await physics_frame
		enemy._travel_to(peek)
		enemy.move_and_slide()
	check(enemy.global_position.distance_to(peek)<0.35,"enemy physically moves around cover to peek point")
	for i in 360:
		await physics_frame
		enemy._travel_to(cover)
		enemy.move_and_slide()
	check(enemy.global_position.distance_to(cover)<0.35,"enemy physically returns behind cover")
	print("ENEMY_COMBAT_SAMPLE failures=",failures)
	quit(1 if failures else 0)
