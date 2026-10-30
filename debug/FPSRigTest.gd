extends Node3D
## Isolated adapter: adds diagnostics/markers only; never edits bones or imported animations.
@export var legacy_baseline := false
@export var show_marker_axes := true
var candidate_mode := false
var fixture: Node3D
var arms: Node3D
var rifle: Node3D
var weapon: Node
var camera: Camera3D
var diagnostics: Node
var setup_issues: Array[String] = []

func _ready() -> void:
 process_priority = 2
 legacy_baseline = legacy_baseline or "--legacy" in OS.get_cmdline_user_args()
 candidate_mode = "--candidate" in OS.get_cmdline_user_args()
 if "--clean" in OS.get_cmdline_user_args(): show_marker_axes = false
 diagnostics = $RigDiagnostics
 var path := "res://scenes/levels/art/CinematicSample.tscn" if legacy_baseline else "res://scenes/levels/art/HandCalibrationSample.tscn"
 fixture = load(path).instantiate()
 if candidate_mode:
  fixture.get_node("CinematicPresentation").calibration_asset_id = &"player_fp_arms_candidate_v009"
 fixture.name = "Fixture"
 add_child(fixture)
 camera = fixture.get_node("Player/Camera3D")
 arms = camera.get_node("RifleViewModel/FirstPersonArms")
 rifle = camera.get_node("RifleViewModel/CinematicRifle")
 weapon = fixture.get_node("Player/WeaponController")
 get_window().title = "TASK-009 FPS Rig Diagnostics / " + ("legacy v005" if legacy_baseline else ("candidate v009" if candidate_mode else "static v006"))
 var model: Node = arms.skeleton
 while model.get_parent() != arms:
  model = model.get_parent()
 model.name = "ArmsModel"
 rifle.model.name = "RifleModel"
 rifle.right_grip_socket.name = "RightWristReference"
 var glove := arms.find_child("Object_7",true,false) as MeshInstance3D
 var palm_tool := preload("res://debug/FPSPalmCalibration.gd").new()
 var palm_markers := {}
 for side in ["R","L"]:
  var result:Dictionary = palm_tool.calibrate(glove,arms.skeleton,side+"_Hand")
  if not result.valid:
   setup_issues.append(side+" palm: "+result.reason)
   continue
  var attachment := BoneAttachment3D.new()
  attachment.name = "RightPalmAttachment" if side == "R" else "LeftPalmAttachment"
  attachment.bone_name = side+"_Hand"
  arms.skeleton.add_child(attachment)
  var marker := Marker3D.new()
  marker.name = "RightPalmMarker" if side == "R" else "LeftPalmMarker"
  marker.transform = result.transform
  marker.set_meta("surface_calibration",result.metadata)
  attachment.add_child(marker)
  palm_markers[side] = marker
  if show_marker_axes:
   _axes(marker,Color.RED if side=="R" else Color.BLUE)
 # Desired surface targets come from the actual gun surfaces, not the wrist position.
 var right_socket := _socket(rifle.model,"RightGripSocket",Vector3(0,-.11,.155),Basis(Vector3.DOWN,Vector3.LEFT,Vector3.FORWARD))
 var left_socket := _socket(rifle.model,"LeftGripSocket",Vector3(0,.022,-.23),Basis(Vector3.BACK,Vector3.RIGHT,Vector3.UP))
 var mag_socket := _socket(rifle.magazine,"LeftMagazineGripSocket",Vector3(-.024,-.20,0),Basis(Vector3.DOWN,Vector3.FORWARD,Vector3.RIGHT))
 mag_socket.owner = self
 mag_socket.unique_name_in_owner = true
 rifle.magazine.name = "Magazine"
 rifle.magazine.owner = self
 rifle.magazine.unique_name_in_owner = true
 var sight := _socket(rifle.model,"SightMarker",Vector3(0,.135,.042),Basis.IDENTITY)
 var rear := -INF
 var stock_points: Array[Vector3] = []
 for mesh in rifle.model.find_children("*","MeshInstance3D",true,false):
  for surface in mesh.mesh.get_surface_count():
   var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for vertex in vertices:
    var point:Vector3=rifle.model.to_local(mesh.to_global(vertex))
    if point.z > rear + .001:
     rear=point.z;stock_points=[point]
    elif absf(point.z-rear)<.001:
     stock_points.append(point)
 var stock_center:=Vector3.ZERO
 for point in stock_points:stock_center+=point
 stock_center/=stock_points.size()
 var stock_marker:=_socket(rifle.model,"ButtstockSurfaceMarker",stock_center,Basis.IDENTITY)
 var shoulder_marker:=_socket(fixture.get_node("Player"),"RightShoulderDesignReference",Vector3(.22,1.45,.08),Basis.IDENTITY)
 diagnostics.stock_marker_path=diagnostics.get_path_to(stock_marker)
 diagnostics.shoulder_marker_path=diagnostics.get_path_to(shoulder_marker)
 diagnostics.muzzle_marker_path=diagnostics.get_path_to(camera.get_node("RifleViewModel/Muzzle"))

 diagnostics.skeleton_path = diagnostics.get_path_to(arms.skeleton)
 diagnostics.viewmodel_root_path = diagnostics.get_path_to(rifle.view_model)
 diagnostics.weapon_root_path = diagnostics.get_path_to(rifle.model)
 diagnostics.camera_path = diagnostics.get_path_to(camera)
 diagnostics.animation_player_path = diagnostics.get_path_to(arms.player) if arms.player!=null else NodePath()
 var trees := arms.find_children("*","AnimationTree",true,false)
 diagnostics.animation_tree_path = diagnostics.get_path_to(trees[0]) if not trees.is_empty() else NodePath()
 diagnostics.right_palm_marker_path = diagnostics.get_path_to(palm_markers.R) if palm_markers.has("R") else NodePath()
 diagnostics.left_palm_marker_path = diagnostics.get_path_to(palm_markers.L) if palm_markers.has("L") else NodePath()
 diagnostics.right_grip_socket_path = diagnostics.get_path_to(right_socket)
 diagnostics.left_grip_socket_path = diagnostics.get_path_to(left_socket)
 diagnostics.sight_marker_path = diagnostics.get_path_to(sight)
 diagnostics.magazine_socket_path = NodePath("%LeftMagazineGripSocket")
 diagnostics.magazine_path = NodePath("%Magazine")
 diagnostics.required_bones = PackedStringArray(["R_Hand","L_Hand"])
 diagnostics.static_bind_fixture = not legacy_baseline
 _process(0)

func _socket(parent:Node3D,name_value:String,point:Vector3,basis:Basis)->Marker3D:
 var marker:=Marker3D.new()
 marker.name=name_value
 marker.transform=Transform3D(basis,point)
 parent.add_child(marker)
 return marker

func _axes(parent:Node3D,color:Color)->void:
 var material:=StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.vertex_color_use_as_albedo=true
 material.no_depth_test=true
 var mesh:=ImmediateMesh.new()
 mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
 for pair in [[Vector3.RIGHT,Color.RED],[Vector3.UP,Color.GREEN],[Vector3.BACK,Color.BLUE]]:
  mesh.surface_set_color(pair[1]);mesh.surface_add_vertex(Vector3.ZERO);mesh.surface_add_vertex(pair[0]*.04)
 mesh.surface_end()
 var axes:=MeshInstance3D.new();axes.mesh=mesh;axes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(axes)
 var sphere:=SphereMesh.new();sphere.radius=.004;sphere.height=.008
 var dot:=MeshInstance3D.new();dot.mesh=sphere
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=color;mat.no_depth_test=true;dot.material_override=mat;dot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(dot)

func _process(_delta:float)->void:
 if diagnostics==null or weapon==null:
  return
 var detached:bool=legacy_baseline and weapon.reloading and rifle.reload_phase>=.02 and rifle.reload_phase<.98
 var held:bool=legacy_baseline and weapon.reloading and rifle.reload_phase>=.18 and rifle.reload_phase<.82
 diagnostics.expect_left_hand_gripping=not detached
 diagnostics.expect_left_hand_on_magazine=held
 diagnostics.expect_ads_sight_centered=weapon.aiming and not weapon.reloading
 diagnostics.magazine_expected_parent_path=diagnostics.get_path_to(arms.magazine_socket if held else rifle.model)
 diagnostics.set_meta("context",{"fixture":"legacy_v005" if legacy_baseline else ("candidate_v009" if candidate_mode else "static_v006"),"approved_baseline":false,"arms_model_path":arms.model_path,"weapon_model_path":rifle.model_path,"setup_issues":setup_issues,"reload_phase":rifle.reload_phase,"weapon_reload_remaining":weapon.reload_remaining,"weapon_reloading":weapon.reloading,"arm_clip":arms.current,"reload_presentation":"legacy_unaccepted" if legacy_baseline else "frozen_pending_static_approval","frame_policy":"sample after frame_post_draw; diagnostic code does not modify bones"})
