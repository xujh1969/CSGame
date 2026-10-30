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
	enemy.global_position=Vector3(2.6,0,-13)
	enemy.rotation.y=0
	for i in 2:await physics_frame
	for i in 120:
		await physics_frame
		enemy.velocity=Vector3(0,0,-2)
		enemy.move_and_slide()
	check(enemy.is_on_wall() and enemy.global_position.z>-14.0,"enemy body collision stops direct movement at the solid wall")
	var stopped_position:Vector3=enemy.global_position
	enemy.apply_damage(1000)
	var actor=enemy.get_node("VisualRoot/RiggedEnemy")
	var wall_bounds:=AABB(Vector3(1.3,0,-14.75),Vector3(2.6,1.1,.5)).grow(.06)
	var death_bones_clear:=true
	for i in 120:
		await physics_frame
		actor._process(1.0/60.0)
		for bone in actor.skeleton.get_bone_count():
			var bone_name:String=actor.skeleton.get_bone_name(bone)
			if bone_name.contains("Thumb") or bone_name.contains("Index") or bone_name.contains("Toe") or bone_name.contains("Foot"):continue
			var bone_world:Vector3=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)).origin
			if wall_bounds.has_point(bone_world):
				death_bones_clear=false
	check(enemy.global_position.distance_to(stopped_position)<0.01,"lethal hit beside wall does not move enemy root through it")
	check(actor.current_clip=="Death","enemy beside wall plays the death animation")
	check(death_bones_clear,"death animation keeps the enemy skeleton outside the solid wall")
	print("ENEMY_COMBAT_SAMPLE failures=",failures)
	quit(1 if failures else 0)
