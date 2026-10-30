extends SceneTree
func _initialize() -> void:
 var scene: Node3D = load("res://scenes/levels/art/CinematicSample.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 var arms=scene.get_node("Player/Camera3D/RifleViewModel/FirstPersonArms")
 var result={"bones":[],"animations":[],"meshes":[]}
 for i in arms.skeleton.get_bone_count():
  result.bones.append({"name":arms.skeleton.get_bone_name(i),"parent":arms.skeleton.get_bone_parent(i),"rest_scale":str(arms.skeleton.get_bone_rest(i).basis.get_scale())})
 for name in arms.player.get_animation_list():
  var a:Animation=arms.player.get_animation(name)
  var tracks=[]
  for i in a.get_track_count():tracks.append({"path":str(a.track_get_path(i)),"type":a.track_get_type(i),"keys":a.track_get_key_count(i)})
  result.animations.append({"name":name,"length":a.length,"tracks":tracks})
 for m in arms.find_children("*","MeshInstance3D",true,false):
  result.meshes.append({"name":m.name,"skeleton_path":str(m.skeleton),"skin_binds":m.skin.get_bind_count() if m.skin else 0,"can_bake_pose":m.has_method("bake_mesh_from_current_skeleton_pose"),"transform":str(m.global_transform)})
 var f=FileAccess.open("res://logs/TASK-009-v005-runtime-rig-audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
 print("RUNTIME_RIG_AUDIT bones=",result.bones.size()," animations=",result.animations.size()," meshes=",result.meshes)
 quit()
