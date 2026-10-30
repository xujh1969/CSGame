extends SceneTree
func _initialize()->void:
 var rows:=[]
 for path in ["res://assets/models/人物战斗动作/Firing Rifle.fbx","res://assets/models/人物战斗动作/Run Forward.fbx","res://assets/models/人物战斗动作/Dying.fbx","res://assets/models/人物战斗动作/Crouch Rapid Fire.fbx","res://assets/models/AK-47低模.glb","res://assets/models/恐怖分子-低模.glb","res://assets/models/恐怖分子-高清.glb"]:
  var model=load(path).instantiate()
  root.add_child(model)
  var row={"path":path,"meshes":[],"skeletons":[],"animations":[]}
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   row.meshes.append({"name":mesh.name,"bounds":str(mesh.mesh.get_aabb()),"skin":mesh.skin!=null,"global_bounds":str(mesh.global_transform*mesh.mesh.get_aabb()),"material":str(mesh.mesh.surface_get_material(0))})
  for skeleton in model.find_children("*","Skeleton3D",true,false):
   var bones:=[]
   for i in skeleton.get_bone_count():bones.append(skeleton.get_bone_name(i))
   row.skeletons.append({"name":skeleton.name,"bones":bones})
  for player in model.find_children("*","AnimationPlayer",true,false):
   for name in player.get_animation_list():
    var clip:Animation=player.get_animation(name)
    var tracks:=[]
    for i in mini(clip.get_track_count(),5):tracks.append(str(clip.track_get_path(i)))
    row.animations.append({"name":name,"length":clip.length,"tracks":clip.get_track_count(),"first_tracks":tracks})
  rows.append(row);model.free()
 var f=FileAccess.open("res://logs/TASK-010-asset-audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "))
 print(JSON.stringify(rows));quit()
