extends SceneTree
var failures:=0
func check(ok:bool,label:String)->void:
 print(('PASS: ' if ok else 'FAIL: ')+label)
 if not ok:failures+=1
func _initialize()->void:
 _run.call_deferred()
func _frames(n:int)->void:
 for i in n:
  await physics_frame
  await process_frame
func _capture(label:String)->void:
 await process_frame
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png('res://logs/TASK-009-v006-'+label+'.png')==OK,'real GUI capture '+label)
func _wrist(arms:Node3D,side:String)->Transform3D:
 return arms.skeleton.global_transform*arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone(side+'_Hand'))
func _run()->void:
 root.size=Vector2i(1280,720)
 var scene:Node3D=load('res://scenes/levels/art/HandCalibrationSample.tscn').instantiate();root.add_child(scene);current_scene=scene
 var player=scene.get_node('Player');player.get_node('InputController').set_physics_process(false);player.get_node('InputController').set_process_unhandled_input(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 await _frames(35)
 var camera:Camera3D=player.get_node('Camera3D');var presentation=scene.get_node('CinematicPresentation');var rifle=presentation.rifle;var arms=camera.get_node('RifleViewModel/FirstPersonArms');var weapon=player.get_node('WeaponController')
 check(presentation.static_hand_calibration and arms.static_calibration and rifle.static_calibration,'isolated v006 static calibration is active')
 check(arms.player==null and arms.find_children('*','AnimationPlayer',true,false).is_empty(),'Idle Fire Reload animation players are absent')
 check(arms.skeleton.get_bone_count()==61,'native 61-bone skin retained')
 var positive:=true
 for i in arms.skeleton.get_bone_count():positive=positive and arms.skeleton.get_bone_rest(i).basis.determinant()>0
 check(positive,'bone bind matrices contain no negative scaling')
 var entry:Dictionary=scene.get_node('StreetArt').registry.player_fp_arms_calibration
 check(FileAccess.get_sha256('res://assets/models/hand_with_gloves.glb')==entry.raw_sha256['assets/models/hand_with_gloves.glb'],'original hand source SHA256 preserved')
 var palm_checks={}
 for side in ['R','L']:
  var a:Array=entry.palm_axes[side];var axis:=Vector3(a[0],a[1],a[2]);var world:Vector3=_wrist(arms,side).basis*axis;var local:Vector3=rifle.view_model.global_basis.inverse()*world
  palm_checks[side]=local
 check(palm_checks.R.dot(Vector3.FORWARD)>.99,'actual black right palm faces the rear grip contact, not the dorsal panel')
 check(palm_checks.L.dot(Vector3.UP)>.99,'actual black left palm faces upward into the handguard')
 check(_wrist(arms,'R').origin.distance_to(rifle.right_grip_socket.global_position)<.002,'right wrist remains at its static grip socket')
 var left_local:Vector3=rifle.view_model.to_local(_wrist(arms,'L').origin)
 check(left_local.z<-.18 and left_local.z>-.30,'left hand supports the forward handguard instead of the grip')
 check(float(arms.reachability_errors.L)<.015,'forward support is within anatomical arm reach')
 check(absf(rifle.view_model.rotation.y)<.001 and absf(rifle.view_model.rotation.z)<.001,'Hip has no arbitrary lateral weapon rotation')
 var obscures:=false
 var local_from:Vector3=rifle.model.to_local(camera.global_position);var local_to:Vector3=rifle.model.to_local(camera.global_position-camera.global_basis.z*2)
 for mesh in rifle.model.find_children('*','MeshInstance3D',true,false):
  var points:PackedVector3Array=mesh.mesh.get_faces()
  for i in range(0,points.size(),3):
   var t:Transform3D=rifle.model.global_transform.affine_inverse()*mesh.global_transform
   if Geometry3D.segment_intersects_triangle(local_from,local_to,t*points[i],t*points[i+1],t*points[i+2])!=null:obscures=true
 check(not obscures,'Hip weapon geometry does not block the central crosshair ray')
 await _capture('hip')
 weapon.set_controls(false,true,false,false);await _frames(40)
 var center:Vector3=camera.to_local(rifle.to_global(Vector3(0,.135,.042)))
 check(absf(center.x)<.001 and absf(center.y)<.001,'ADS sight center aligns with the camera crosshair')
 check(is_equal_approx(camera.fov,55),'ADS interpolation reaches its own view pose')
 await _capture('ads')
 weapon.set_controls(false,false,false,false);await _frames(35)
 check(weapon.try_fire() and weapon.magazine==29,'original firing/ammo authority still works')
 await _frames(3)
 check(arms.current=='StaticBind','Fire does not override the frozen calibration bind pose')
 check(weapon.request_reload(),'original reload timer starts')
 await _frames(45)
 check(not rifle.magazine_held and rifle.magazine.get_parent()==rifle.model and arms.current=='StaticBind','reload presentation remains frozen while static calibration awaits review')
 await _frames(100)
 check(weapon.magazine==30 and weapon.reserve==89,'original ammo reload computation remains unchanged')
 print('CALIBRATION PALM DIRECTIONS ',palm_checks,' LEFT WRIST ',left_local)
 print('TASK-009 STATIC CALIBRATION failures: ',failures)
 quit(0 if failures==0 else 1)

