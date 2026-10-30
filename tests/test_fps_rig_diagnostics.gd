extends SceneTree
var failures := 0
var snapshots := []
func check(ok:bool,label:String)->void:
 print(("PASS: " if ok else "FAIL: ")+label)
 if not ok:failures+=1
func _initialize()->void:
 _run.call_deferred()
func _frames(count:int)->void:
 for i in count:
  await process_frame
func _run()->void:
 root.size=Vector2i(1280,720)
 var harness:Node3D=load("res://debug/fps_rig_test.tscn").instantiate()
 root.add_child(harness);current_scene=harness
 var control=harness.fixture.get_node("Player/InputController")
 control.set_physics_process(false);control.set_process_unhandled_input(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var w=harness.weapon;w.set_physics_process(false)
 var d=harness.diagnostics
 var variant:String="legacy_v005" if harness.legacy_baseline else ("candidate_v009_grip" if harness.candidate_mode else "static_v006")
 d.output_directory="res://logs/fps_rig/"+variant+"/"
 await _frames(35)
 check(harness.setup_issues.is_empty(),"palm calibration resolves real skin binds and source palette")
 var report:Dictionary=d.make_report("inventory")
 check(report.bone_count==61 and report.inventory.skinned_meshes.size()==2,"actual skeleton and both skinned meshes inventoried")
 var binds_valid:=true
 for mesh in report.inventory.skinned_meshes:
  for bind in mesh.binds:binds_valid=binds_valid and bool(bind.resolved)
 check(binds_valid,"all actual mesh-to-skeleton bindings resolve")
 check(report.inventory.bone_attachments.size()==2,"both palm markers use real BoneAttachment3D nodes")
 var tracks_valid:=true
 for player in report.inventory.animation_players:
  for clip in player.clips:
   for track in clip.tracks:tracks_valid=tracks_valid and bool(track.resolved)
 check(tracks_valid,"actual animation track targets resolve")
 check(report.right_grip.configured and report.left_grip.configured,"required palms and physically separate surface sockets are configured")
 check(report.right_grip.surface_calibration.kind=="black_palmar_surface_from_skin_and_texture","contact marker is derived from palmar geometry rather than wrist origin")
 var before:Array[Transform3D]=[]
 for i in harness.arms.skeleton.get_bone_count():before.append(harness.arms.skeleton.get_bone_pose(i))
 var root_before:Transform3D=harness.rifle.view_model.global_transform
 var clip_before:String=harness.arms.current
 d.make_report("readonly_check")
 var unchanged:bool=root_before.is_equal_approx(harness.rifle.view_model.global_transform) and clip_before==harness.arms.current
 for i in before.size():unchanged=unchanged and before[i].is_equal_approx(harness.arms.skeleton.get_bone_pose(i))
 check(unchanged,"diagnostic snapshot does not change bones, animation or weapon transform")
 # Deliberately corrupt DEBUG markers only; never alter imported bones or skin weights.
 var marker:Node3D=d.get_node(d.right_palm_marker_path)
 var saved:Transform3D=marker.transform
 marker.global_position=d.get_node(d.right_grip_socket_path).global_position+Vector3(.2,0,0)
 var bad:Dictionary=d.make_report("injected_contact_error")
 check(float(bad.right_grip.distance_m)>.19 and bad.issues.has("Right hand contact distance %.3fm > %.3fm" % [bad.right_grip.distance_m,d.max_grip_error_m]),"known 20cm marker error is detected")
 marker.transform=saved
 var path_before:NodePath=d.right_palm_marker_path
 d.right_palm_marker_path=NodePath()
 bad=d.make_report("injected_missing_marker")
 check(not bad.right_grip.configured and bad.issues.has("Right hand expected contact has missing palm marker or socket"),"missing required palm marker cannot silently pass")
 d.right_palm_marker_path=path_before
 var sight:Node3D=d.get_node(d.sight_marker_path)
 var sight_before:Transform3D=sight.global_transform
 var ads_before:bool=d.expect_ads_sight_centered
 d.expect_ads_sight_centered=true
 sight.global_position=harness.camera.global_position+harness.camera.global_basis.z
 bad=d.make_report("injected_ads_behind_camera")
 check(bad.issues.has("ADS sight is behind Camera3D"),"ADS sight behind camera cannot silently pass")
 sight.global_transform=sight_before
 var sight_path_before:NodePath=d.sight_marker_path
 d.sight_marker_path=NodePath()
 bad=d.make_report("injected_missing_ads_sight")
 check(bad.issues.has("ADS sight projection is unavailable"),"missing ADS sight cannot silently pass")
 d.sight_marker_path=sight_path_before
 d.expect_ads_sight_centered=ads_before
 await _snapshot(harness,"Idle")
 w.set_controls(false,true,false,false);await _frames(40)
 await _snapshot(harness,"ADS")
 w.set_controls(false,false,false,false);await _frames(35)
 check(w.try_fire(),"Fire uses the existing weapon authority")
 await _frames(1)
 await _snapshot(harness,"Fire")
 check(w.request_reload(),"Reload uses the existing weapon timer")
 var previous:=0.0
 for entry in [["Reload_start",.01],["Old_mag_grasp",.20],["Old_mag_remove",.42],["New_mag_insert",.72],["Reload_end",.995]]:
  var phase:float=entry[1]
  w.advance((phase-previous)*w.reload_duration);previous=phase
  await _frames(20)
  await _snapshot(harness,entry[0])
 w.advance(w.reload_remaining+.001)
 check(w.magazine==30 and w.reserve==89,"diagnostic state stepping preserves original ammo transfer")
 var total_issues:=0
 for item in snapshots:total_issues+=int(item.issue_count)
 var summary={"fixture":variant,"framework_failures":failures,"snapshot_count":snapshots.size(),"pose_issue_count":total_issues,"approved_baseline":false,"states":snapshots,"rendering":"no PNG available" if DisplayServer.get_name()=="headless" else "real GPU viewport; fixed 60fps simulation, not performance measurement"}
 var file:=FileAccess.open(d.output_directory.path_join("summary.json"),FileAccess.WRITE);file.store_string(JSON.stringify(summary,"  "));file.close()
 print("FPS_RIG_FRAMEWORK failures=",failures," pose_issues=",total_issues," fixture=",variant)
 quit(0 if failures==0 else 1)
func _snapshot(harness:Node3D,stage:String)->void:
 var result:Dictionary=await harness.diagnostics.capture_report(stage)
 check(result.has("json") and FileAccess.file_exists(result.json),"JSON capture "+stage)
 if DisplayServer.get_name()!="headless":check(result.has("png") and FileAccess.file_exists(result.png),"same-frame GUI capture "+stage)
 snapshots.append({"stage":stage,"issue_count":result.report.issue_count,"issues":result.report.issues,"warnings":result.report.warnings,"json":result.get("json",""),"png":result.get("png","")})
