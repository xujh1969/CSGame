extends Node
@export var seed:=20261031
func _ready()->void:
 get_window().title="Urban Corridor FPS / TASK-010A AK Enemy Combat"
 var level=get_parent()
 var enemy=level.get_node("Enemies/AGuard")
 enemy.archetype="corner_ambusher"
 level.get_node("CoverMarkers/C1").position=Vector3(2.6,0,-16)
 level.get_node("PeekMarkers/P1").position=Vector3(0.8,0,-13.5)
 var agent:=NavigationAgent3D.new();agent.name="NavigationAgent3D";agent.path_desired_distance=.2;agent.target_desired_distance=.15;agent.radius=.28;agent.height=1.8
 enemy.add_child(agent);enemy.navigation=agent
 var rng:=RandomNumberGenerator.new();rng.seed=seed
 var window_x:float=[-5.4,5.4][rng.randi_range(0,1)]
 var car_x:float=[-4.45,-2.25][rng.randi_range(0,1)]
 _add_enemy(level,"ECar",Vector3(car_x,0,-17.8),"corner_ambusher",Vector3(car_x,0,-17.8),Vector3(-1.4,0,-14.2))
 _add_enemy(level,"EWindow",Vector3(window_x,4.2,-46),"window_sentry",Vector3(window_x,4.2,-46),Vector3(window_x,4.2,-46))
 level.get_node("Triggers/A1").set_meta("enemy_ids",["AGuard","ECar","EWindow"])
 print("Enemy combat sample seed=",seed," car_x=",car_x," window_x=",window_x)

func _add_enemy(level:Node3D,id:StringName,spawn:Vector3,archetype:String,cover:Vector3,peek:Vector3)->void:
 var marker:=Marker3D.new();marker.name=id;marker.position=spawn;marker.set_meta("encounter_id",&"A1")
 level.get_node("SpawnMarkers").add_child(marker)
 var cover_marker:=Marker3D.new();cover_marker.name=id;cover_marker.position=cover
 level.get_node("CoverMarkers").add_child(cover_marker)
 var peek_marker:=Marker3D.new();peek_marker.name=id;peek_marker.position=peek
 level.get_node("PeekMarkers").add_child(peek_marker)
 var enemy:CharacterBody3D=load("res://scenes/enemies/EnemyBase.tscn").instantiate()
 enemy.name=id;enemy.position=spawn;enemy.archetype=archetype
 enemy.cover_path=NodePath("../../CoverMarkers/"+str(id));enemy.peek_path=NodePath("../../PeekMarkers/"+str(id))
 if archetype=="corner_ambusher":
  var nav:=NavigationAgent3D.new();nav.name="NavigationAgent3D";nav.path_desired_distance=.2;nav.target_desired_distance=.15;nav.radius=.28;nav.height=1.8
  enemy.add_child(nav)
 level.get_node("Enemies").add_child(enemy)
 level.get_node("EncounterManager").register_enemy(enemy,&"A1")
