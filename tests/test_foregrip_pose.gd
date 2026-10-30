extends SceneTree
func _initialize()->void:
 _run.call_deferred()
func _run()->void:
 var h=load("res://debug/fps_rig_test.tscn").instantiate()
 root.add_child(h)
 var control=h.fixture.get_node("Player/InputController")
 control.set_physics_process(false);control.set_process_unhandled_input(false)
 for i in 35:await process_frame
 var s:Skeleton3D=h.arms.skeleton
 var width:=0.0
 for mesh in h.rifle.model.find_children("*","MeshInstance3D",true,false):
  if mesh.name!="Rifle_Body":continue
  for surface in mesh.mesh.get_surface_count():
   for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
    var point:Vector3=h.rifle.model.to_local(mesh.to_global(vertex))
    if absf(point.z+.23)<.015:width=maxf(width,absf(point.x))
 var failures:=0
 var baseline=load("res://assets/models/task009/v009/arms_palmar_candidate.glb").instantiate()
 root.add_child(baseline)
 var old_skeleton:Skeleton3D=baseline.find_children("*","Skeleton3D",true,false)[0]
 var right_unchanged:=true
 for i in s.get_bone_count():
  var name_value:String=s.get_bone_name(i)
  if name_value.begins_with("R_") or ".R_" in name_value:
   var old_index:int=old_skeleton.find_bone(name_value)
   right_unchanged=right_unchanged and old_index>=0 and s.get_bone_global_rest(i).is_equal_approx(old_skeleton.get_bone_global_rest(old_index))
 print("PASS: " if right_unchanged else "FAIL: ","right bone rests preserved against v009")
 if not right_unchanged:failures+=1
 baseline.queue_free()
 var rows:=[]
 for family in ["index_L","middle_L","ring_L","pink_L","thumb_L"]:
  var bone:=-1
  for i in s.get_bone_count():
   if String(s.get_bone_name(i)).begins_with(family+".L_"):bone=i
  while true:
   var child:=-1
   for i in s.get_bone_count():
    if s.get_bone_parent(i)==bone and String(s.get_bone_name(i)).begins_with(family):child=i
   if child<0:break
   bone=child
  var point:Vector3=h.rifle.model.to_local(s.to_global(s.get_bone_global_pose(bone).origin))
  var ok:bool=absf(point.x)<width+.020 if family!="thumb_L" else (point.x < -width+.008 and point.x > -width-.030)
  ok=ok and point.y>=-.008 and point.y<=.105 and point.z>=-.35 and point.z<=-.14
  rows.append({"family":family,"tip_gun_local":[point.x,point.y,point.z],"valid":ok})
  print("PASS: " if ok else "FAIL: ",family," tip=",point," measured_half_width=",width)
  if not ok:failures+=1
 h.weapon.set_controls(false,true,false,false)
 for i in 40:await process_frame
 var glove:MeshInstance3D=h.arms.find_child("Object_7",true,false)
 var baked:ArrayMesh=glove.bake_mesh_from_current_skeleton_pose()
 if baked==null:
  push_error("A real rendering device is required for the skinned aperture check")
  quit(1)
  return
 var faces:PackedVector3Array=baked.get_faces()
 var glass:MeshInstance3D=h.rifle.optic_glass
 var center:Vector3=glass.mesh.get_aabb().get_center()
 var blocked:=0
 for sample in 25:
  var r:float=0 if sample==0 else (.008 if sample<=12 else .014)
  var angle:float=float((sample-1)%12)*TAU/12
  var target:Vector3=glass.to_global(center+Vector3(cos(angle)*r,sin(angle)*r,0))
  var start:Vector3=glove.to_local(h.camera.global_position)
  var end:Vector3=glove.to_local(h.camera.global_position+(target-h.camera.global_position).normalized()*2)
  for i in range(0,faces.size(),3):
   if Geometry3D.segment_intersects_triangle(start,end,faces[i],faces[i+1],faces[i+2])!=null:
    blocked+=1;break
 print("PASS: " if blocked==0 else "FAIL: ","ADS glove aperture blockers=",blocked,"/25")
 if blocked>0:failures+=1
 var f=FileAccess.open("res://logs/TASK-009-foregrip-runtime.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"model":h.arms.model_path,"guard_half_width":width,"right_bind_unchanged":right_unchanged,"fingers":rows,"ads_glove_blocked_rays":blocked,"failures":failures,"limitation":"Bone envelope and sampled aperture rays; not full mesh collision or visual acceptance"},"  "))
 quit(1 if failures else 0)
