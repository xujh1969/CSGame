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
	var car_enemy=scene.get_node("Enemies/ECar")
	var window_enemy=scene.get_node("Enemies/EWindow")
	var manager=scene.get_node("EncounterManager")
	var peek:Vector3=enemy.peek_marker.global_position
	var cover:Vector3=enemy.cover_marker.global_position
	var navigation=enemy.get_node("NavigationAgent3D")
	var car_navigation=car_enemy.get_node("NavigationAgent3D")
	check(scene.get_node("Enemies").get_child_count()==3,"seeded sample stages multiple enemies at distinct cover types")
	check(manager.encounter_enemies[&"A1"].size()==3,"one encounter tracks all staged enemies")
	check(car_enemy.position.z< -17 and window_enemy.position.y>3.0,"sample includes a car flank and a window position")
	check(manager.activate_encounter(&"A1"),"sample trigger activates the full enemy group")
	check(enemy.activation_count==1 and car_enemy.activation_count==1 and window_enemy.activation_count==1,"all three enemies activate once")
	var car_path:=NavigationServer3D.map_get_path(car_navigation.get_navigation_map(),car_enemy.global_position,car_enemy.peek_marker.global_position,true)
	check(car_path.size()>=2,"car flank has a baked path to its peek point")
	var path:=NavigationServer3D.map_get_path(navigation.get_navigation_map(),enemy.global_position,peek,true)
	var wall_bounds:=AABB(Vector3(1.3,0,-14.75),Vector3(2.6,1.1,.5)).grow(.02)
	check(peek.distance_to(cover)>1.0,"peek and cover points are distinct")
	check(path.size()>=2,"baked sample navigation reaches the peek point")
	enemy.set_physics_process(false)
	car_enemy.set_physics_process(false);window_enemy.set_physics_process(false)
	var live_roots_clear:=true
	var live_bones_clear:=true
	var actor=enemy.get_node("VisualRoot/RiggedEnemy")
	for i in 360:
		await physics_frame
		enemy._travel_to(peek)
		enemy.move_and_slide()
		await process_frame
		if wall_bounds.has_point(enemy.global_position):live_roots_clear=false
		for bone in actor.skeleton.get_bone_count():
			var bone_name:String=actor.skeleton.get_bone_name(bone)
			if bone_name.contains("Thumb") or bone_name.contains("Index") or bone_name.contains("Toe") or bone_name.contains("Foot"):continue
			var bone_world:Vector3=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)).origin
			if wall_bounds.has_point(bone_world):
				live_bones_clear=false
	check(enemy.global_position.distance_to(peek)<0.35,"enemy physically moves around cover to peek point")
	car_enemy.set_physics_process(false)
	for i in 240:
		await physics_frame
		car_enemy._travel_to(car_enemy.peek_marker.global_position)
		car_enemy.move_and_slide()
		await process_frame
	check(car_enemy.global_position.distance_to(car_enemy.peek_marker.global_position)<0.35,"car flank physically reaches its peek point")
	for i in 360:
		await physics_frame
		enemy._travel_to(cover)
		enemy.move_and_slide()
		await process_frame
		if wall_bounds.has_point(enemy.global_position):live_roots_clear=false
		for bone in actor.skeleton.get_bone_count():
			var bone_name:String=actor.skeleton.get_bone_name(bone)
			if bone_name.contains("Thumb") or bone_name.contains("Index") or bone_name.contains("Toe") or bone_name.contains("Foot"):continue
			var bone_world:Vector3=(actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)).origin
			if wall_bounds.has_point(bone_world):
				live_bones_clear=false
	check(enemy.global_position.distance_to(cover)<0.35,"enemy physically returns behind cover")
	check(live_roots_clear,"live navigation keeps the enemy body outside the concrete wall")
	check(live_bones_clear,"live movement animation keeps the enemy skeleton outside the concrete wall")
	enemy.global_position=Vector3(2.6,0,-13)
	enemy.rotation.y=0
	for i in 2:await physics_frame
	for i in 240:
		await physics_frame
		enemy.velocity=Vector3(0,0,-2)
		enemy.move_and_slide()
	check(enemy.is_on_wall() and enemy.global_position.z>-14.1,"enemy body collision stops direct movement at the solid wall")
	var stopped_position:Vector3=enemy.global_position
	enemy.apply_damage(1000)
	actor.set_process(false)
	var death_bones_clear:=true
	var death_length:float=actor.player.get_animation(actor.clips.Death).length
	for i in range(int(ceil(death_length*60.0))):
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
	check(not manager.cleared.has(&"A1"),"encounter stays active while other enemies remain alive")
	car_enemy.apply_damage(1000);window_enemy.apply_damage(1000)
	check(manager.cleared.has(&"A1"),"encounter clears only after every staged enemy is defeated")
	print("ENEMY_COMBAT_SAMPLE failures=",failures)
	quit(1 if failures else 0)
