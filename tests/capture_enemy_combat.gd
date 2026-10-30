extends SceneTree
func _initialize()->void:
 _run.call_deferred()
func frames(count:int)->void:
 for i in count:await process_frame
func capture(name_value:String,actor:Node)->void:
 await RenderingServer.frame_post_draw
 var error=root.get_texture().get_image().save_png("res://logs/TASK-010-"+name_value+".png")
 print("CAPTURE ",name_value," error=",error," clip=",actor.current_clip," time=",actor.player.current_animation_position)
func _run()->void:
 root.size=Vector2i(1280,720)
 var scene=load("res://scenes/levels/art/EnemyCombatSample.tscn").instantiate()
 root.add_child(scene)
 scene.get_node("EncounterManager").enabled=false;scene.get_node("GameFlow").enabled=false
 scene.get_node("Player/InputController").set_physics_process(false);scene.get_node("Player/InputController").set_process_unhandled_input(false)
 for layer in scene.find_children("*","CanvasLayer",true,false):layer.hide()
 var enemy=scene.get_node("Enemies/AGuard");enemy.set_physics_process(false);enemy.position=Vector3(0,0,-8)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(1.4,1.25,-4.8);camera.fov=45;camera.look_at(Vector3(0,.9,-8));camera.make_current()
 await frames(15)
 var actor=enemy.get_node("VisualRoot/RiggedEnemy");actor.crouched=false
 enemy.visual.aim_at(camera.global_position)
 await frames(15);await capture("enemy-idle",actor)
 camera.position=Vector3(3.8,1.25,-6.5);camera.look_at(Vector3(0,1,-8))
 await frames(3);await capture("enemy-side",actor)
 camera.position=Vector3(1.4,1.25,-4.8);camera.look_at(Vector3(0,.9,-8))
 enemy.velocity=Vector3(1.8,0,0)
 await frames(12);await capture("enemy-move",actor)
 enemy.velocity=Vector3.ZERO;await frames(10)
 enemy.get_node("EnemyWeapon").fire_at(scene.get_node("Player").global_position+Vector3(0,1.3,0))
 actor.flash.set_process(false);await capture("enemy-fire",actor);actor.flash.set_process(true)
 enemy.apply_damage(1000);camera.position=Vector3(2,2.1,-4);camera.look_at(Vector3(0,.2,-8))
 await frames(30);await capture("enemy-death-mid",actor)
 await frames(200);await capture("enemy-dead",actor)
 quit()
