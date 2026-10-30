extends SceneTree
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var scene:Node3D=load("res://scenes/levels/art/CinematicSample.tscn").instantiate();root.add_child(scene)
 var p=scene.get_node("Player");p.get_node("InputController").set_physics_process(false)
 var w=p.get_node("WeaponController");w.set_physics_process(false)
 var a=p.get_node("Camera3D/RifleViewModel/FirstPersonArms")
 var r=p.get_node("Camera3D/RifleViewModel/CinematicRifle")
 var report=[]
 for phase in [0.0,.1,.18,.4,.65,.819,.82,.95,1.0]:
  w.reloading=true;w.reload_remaining=w.reload_duration*(1-phase)
  for i in range(20):await process_frame
  var bone=a.skeleton.find_bone("L_Hand")
  var hand=r.view_model.to_local(a.skeleton.to_global(a.skeleton.get_bone_global_pose(bone).origin))
  var expected=Vector3(-.075,-.20,.06)+Vector3(0,-.14,.025)*smoothstep(.18,.38,phase)*(1-smoothstep(.62,.82,phase))
  report.append({"phase":phase,"left_hand":str(hand),"expected":str(expected),"error":hand.distance_to(expected),"held":r.magazine_held,"jump":r.attachment_jump,"animation":a.current,"time":a.player.current_animation_position,"length":a.player.get_animation(a.current).length,"first":[a.player.get_animation(a.current).track_get_key_time(2,0)]})
 var f=FileAccess.open("res://logs/TASK-009-v005-phase-probe.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close()
 print(report)
 quit()
