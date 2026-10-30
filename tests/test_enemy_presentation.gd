extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
 print("PASS: " if ok else "FAIL: ",label)
 if not ok:failures+=1
func _initialize()->void:
 _run.call_deferred()
func _run()->void:
 var path="res://assets/models/task010/enemy_fighter.glb"
 check(ResourceLoader.exists(path),"real skinned enemy asset exists")
 if not ResourceLoader.exists(path):quit(1);return
 var scene=load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
 root.add_child(scene)
 scene.get_node("EncounterManager").enabled=false
 scene.get_node("GameFlow").enabled=false
 for i in 10:await process_frame
 var enemy=scene.get_node("Enemies/E01")
 var visual=enemy.get_node("VisualRoot")
 var actor=visual.get_node_or_null("RiggedEnemy")
 check(actor!=null,"existing enemy uses the real skeleton presentation")
 if actor==null:quit(1);return
 check(actor.skeleton.get_bone_count()>=35,"actual delivered skeleton is retained")
 for name in ["Fire","Move","Crouch","Death"]:check(actor.clips.has(name),name+" clip resolves")
 check(actor.gun!=null and actor.muzzle!=null,"independent AK and actual muzzle loaded")
 check(actor.weapon_hand is BoneAttachment3D,"AK attached to real right hand bone")
 check(enemy.get_node("EnemyWeapon").muzzle==actor.muzzle,"damage rays use the displayed gun muzzle")
 enemy.set_physics_process(false)
 enemy.velocity=Vector3(1,0,0)
 actor._process(.1)
 check(actor.current_clip=="Move","moving enemy selects locomotion")
 enemy.velocity=Vector3.ZERO
 actor.crouched=false
 actor._on_fired(Vector3.ZERO,Vector3.ZERO,null)
 actor._process(.01)
 check(actor.current_clip=="Fire","shot event selects firing pose")
 check(actor.flash.remaining>0,"shot emits short muzzle flash")
 enemy.apply_damage(1000)
 actor._process(.1)
 check(actor.current_clip=="Death","lethal hit selects actual death animation")
 check(is_equal_approx(visual.scale.y,1),"death does not squash the actor mesh")
 actor.player.advance(actor.player.get_animation(actor.clips.Death).length+.1)
 var final_pose=actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(actor.hips_bone))
 actor._process(.2)
 check(actor.current_clip=="Death" and not actor.player.is_playing(),"death holds final frame and does not revive")
 check(not enemy.get_node("EnemyWeapon").fire_at(Vector3.ZERO),"dead enemy cannot shoot")
 print("ENEMY_PRESENTATION failures=",failures)
 quit(1 if failures else 0)
