extends Node
func _ready()->void:
 get_window().title="Urban Corridor FPS / TASK-010A AK Enemy Combat"
 var level=get_parent()
 var enemy=level.get_node("Enemies/AGuard")
 enemy.archetype="corner_ambusher"
 level.get_node("CoverMarkers/C1").position=Vector3(2.6,0,-16)
 level.get_node("PeekMarkers/P1").position=Vector3(0.8,0,-13.5)
 var agent:=NavigationAgent3D.new();agent.name="NavigationAgent3D";agent.path_desired_distance=.2;agent.target_desired_distance=.15;agent.radius=.28;agent.height=1.8
 enemy.add_child(agent);enemy.navigation=agent
