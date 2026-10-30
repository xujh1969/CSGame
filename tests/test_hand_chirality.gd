extends SceneTree
## Rotation-invariant check: black palm faces viewer, fingers up, right thumb is screen-right.
func _initialize()->void:
 _run.call_deferred()
func _run()->void:
 var harness=load("res://debug/fps_rig_test.tscn").instantiate()
 root.add_child(harness)
 await process_frame
 var skeleton:Skeleton3D=harness.arms.skeleton
 var glove:MeshInstance3D=harness.arms.find_child("Object_7",true,false)
 var failures:=0
 var evidence:=[]
 for side in ["R","L"]:
  var name_value:String=side+"_Hand"
  var hand:=skeleton.find_bone(name_value)
  var thumb:=-1
  for bone in skeleton.get_bone_count():
   if skeleton.get_bone_parent(bone)==hand and String(skeleton.get_bone_name(bone)).begins_with("thumb"):
    thumb=bone
  var tool=load("res://debug/FPSPalmCalibration.gd")
  var cal:Dictionary=tool.calibrate(glove,skeleton,name_value)
  if thumb<0 or not cal.valid:
   failures+=1
   push_error("Cannot independently resolve thumb/palm for "+name_value)
   continue
  var thumb_bind:int=tool._bind(glove.skin,skeleton,thumb)
  var hand_frame:Transform3D=glove.skin.get_bind_pose(cal.metadata.hand_bind).affine_inverse()
  var palm_frame:Transform3D=hand_frame*cal.transform
  var thumb_point:Vector3=glove.skin.get_bind_pose(thumb_bind).affine_inverse().origin
  var thumb_screen_x:float=(thumb_point-hand_frame.origin).dot(palm_frame.basis.x.normalized())
  var actual:String="R" if thumb_screen_x>0 else "L"
  var valid:bool=actual==side and absf(thumb_screen_x)>.005 and hand_frame.basis.determinant()>0
  print("PASS: " if valid else "FAIL: ",name_value," actual=",actual," thumb_screen_x_m=",thumb_screen_x)
  evidence.append({"semantic_hand":side,"anatomical_hand":actual,"thumb_screen_x_m":thumb_screen_x,"thumb_bone":skeleton.get_bone_name(thumb),"valid":valid})
  if not valid:failures+=1
 var file=FileAccess.open("res://logs/TASK-009-chirality-runtime.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"model":harness.arms.model_path,"hands":evidence,"failures":failures},"  "))
 print("CHIRALITY_FAILURES=",failures)
 quit(1 if failures else 0)
