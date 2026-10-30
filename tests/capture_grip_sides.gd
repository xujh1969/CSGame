extends SceneTree
func _initialize()->void:
 _run.call_deferred()
func _run()->void:
 root.size=Vector2i(1280,720)
 var h=load("res://debug/fps_rig_test.tscn").instantiate()
 root.add_child(h)
 var control=h.fixture.get_node("Player/InputController")
 control.set_physics_process(false);control.set_process_unhandled_input(false)
 for i in 35:await process_frame
 var camera:=Camera3D.new()
 camera.fov=45
 h.add_child(camera)
 camera.make_current()
 for entry in [["right",Vector3(.45,.02,.35),Vector3(0,-.10,.12)],["left",Vector3(-.35,.08,-.03),Vector3(0,.03,-.23)]]:
  camera.global_position=h.rifle.model.to_global(entry[1])
  camera.look_at(h.rifle.model.to_global(entry[2]),Vector3.UP)
  for i in 5:await process_frame
  await RenderingServer.frame_post_draw
  var path:String="res://logs/TASK-009-v009-grip-"+entry[0]+"-side.png"
  var error:int=root.get_texture().get_image().save_png(path)
  print("SIDE_CAPTURE ",entry[0]," error=",error)
  if error!=OK:
   quit(1)
   return
 quit(0)
