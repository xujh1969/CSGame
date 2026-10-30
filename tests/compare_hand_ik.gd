extends SceneTree
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var scene:Node3D=load("res://scenes/levels/art/CinematicSample.tscn").instantiate();root.add_child(scene)
 var p=scene.get_node("Player");p.get_node("InputController").set_physics_process(false)
 var w=p.get_node("WeaponController");w.set_physics_process(false);w.reloading=true;w.reload_remaining=1.1
 var a=p.get_node("Camera3D/RifleViewModel/FirstPersonArms")
 for i in range(50):await process_frame
 a.set_process(false)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://logs/TASK-009-v005-runtime-ik.png")
 a.skeleton.reset_bone_poses();a.player.seek(a.player.get_animation(a.reload_animation).length*.5,true);a.player.advance(0)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://logs/TASK-009-v005-native-skin.png")
 print("CAPTURED WITH AND WITHOUT SHOULDER IK")
 quit()
