extends Node3D
## Visual-only replacement. WeaponController remains the sole ammo/damage authority.

var grip_calibration := {}
var static_calibration := false
var right_grip_socket: Marker3D
var view_model: Node3D
var camera: Camera3D
var actor: CharacterBody3D
var weapon: Node
var model: Node3D
var magazine: Node3D
var magazine_origin := Vector3.ZERO
var obstruction := 0.0
var kick := 0.0
var reticle: MeshInstance3D
var optic_glass: MeshInstance3D
var crosshair: CanvasItem
var model_path := "res://assets/models/task009/rifle_v001.glb"
var weapon_bounds := AABB()
var safe_distance := 1.05
var muzzle_offset := Vector3(0, .006, -.582)
var has_obstacle := false
var reload_phase := 0.0
var magazine_rest := Transform3D.IDENTITY
var magazine_held := false
var magazine_grip_offset := Transform3D.IDENTITY
var attachment_jump := 0.0
var attachment_angle := 0.0
var magazine_settling := false
var settle_start := 0.0
var settle_from := Transform3D.IDENTITY

func _ready() -> void:
	view_model = get_parent()
	camera = view_model.get_parent()
	actor = camera.get_parent()
	weapon = actor.get_node("WeaponController")
	crosshair = actor.get_node_or_null("WeaponHUD/Crosshair")
	right_grip_socket = Marker3D.new()
	right_grip_socket.name = "RightGripSocket"
	var grip_position: Array = grip_calibration.position
	var grip_rotation: Array = grip_calibration.rotation
	right_grip_socket.transform = Transform3D(Basis(Quaternion(grip_rotation[0], grip_rotation[1], grip_rotation[2], grip_rotation[3])), Vector3(grip_position[0], grip_position[1], grip_position[2]))
	add_child(right_grip_socket)
	model = load(model_path).instantiate()
	add_child(model)
	var bounds_initialized := false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		# A close camera weapon cannot provide a complete human silhouette.
		# Full-body world shadows need a separate posed actor, still a declared dependency.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var relative: Transform3D = view_model.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = relative * mesh.mesh.get_aabb()
		weapon_bounds = weapon_bounds.merge(bounds) if bounds_initialized else bounds
		bounds_initialized = true
	magazine = model.find_child("Magazine", true, false)
	magazine_origin = magazine.position
	magazine_rest = magazine.transform
	optic_glass = model.find_child("Optic_Glass", true, false)
	var coating := ShaderMaterial.new()
	coating.shader = preload("res://assets/materials/optic_glass.gdshader")
	optic_glass.material_override = coating
	optic_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Preserve the original root/Muzzle and all damage subscriptions.
	view_model.set_process(false)
	for name in ["Receiver", "Barrel", "Sight"]:
		view_model.get_node(name).hide()
	view_model.get_node("Muzzle").position = muzzle_offset
	weapon.fired.connect(_on_fired)
	reticle = MeshInstance3D.new()
	var dot := QuadMesh.new()
	dot.size = Vector2(.0018, .0018)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, .08, .02)
	dot.material = material
	reticle.mesh = dot
	reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reticle.position = Vector3(0, .135, .02)
	add_child(reticle)

func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	kick = .035

func _physics_process(delta: float) -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .07
	query.shape = sphere
	query.collision_mask = 1 | 2
	query.exclude = [actor.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, camera.global_position + camera.global_basis * Vector3(.12, -.12, 0))
	query.motion = -camera.global_basis.z * 1.05
	var space := actor.get_world_3d().direct_space_state
	var motion := space.cast_motion(query)
	safe_distance = motion[0] * 1.05
	has_obstacle = motion[0] < 1.0
	var target := 1.0 - motion[0] if motion[0] < 1.0 else 0.0
	if not space.intersect_shape(query, 1).is_empty():
		target = 1
		safe_distance = 0
		has_obstacle = true
	obstruction = move_toward(obstruction, target, delta * 8)

func _process(delta: float) -> void:
	kick = move_toward(kick, 0, delta * .35)
	reload_phase = clampf(1 - weapon.reload_remaining / weapon.reload_duration, 0, 1) if weapon.reloading and not static_calibration else 0.0
	var reload_blend := smoothstep(0.0, .18, reload_phase) * (1 - smoothstep(.82, 1.0, reload_phase)) if weapon.reloading else 0.0
	var target := Vector3(0, -.135, -.43) if weapon.aiming else Vector3(.10, -.06, -.43)
	if static_calibration:
		target = Vector3(0, -.135, -.33) if weapon.aiming else Vector3(.16, -.23, -.28)
	target = target.lerp(Vector3(.15, .03, -.45), reload_blend)
	target += Vector3(0, -.13 * obstruction, .42 * obstruction + kick)
	var reload_angle := -.04 * reload_blend
	view_model.rotation.x = lerp_angle(view_model.rotation.x, reload_angle - .65 * obstruction, minf(delta * 12, 1))
	view_model.rotation.z = lerp_angle(view_model.rotation.z, -.30 * reload_blend, minf(delta * 12, 1))
	view_model.rotation.y = lerp_angle(view_model.rotation.y, .10 * reload_blend, minf(delta * 12, 1))
	# Clamp the rotated mesh envelope, not just the root: the barrel extends far ahead.
	var rotated_bounds: AABB = Transform3D(view_model.basis, Vector3.ZERO) * weapon_bounds
	var minimum_z := -safe_distance - rotated_bounds.position.z if has_obstacle else -INF
	target.z = maxf(target.z, minimum_z)
	view_model.position = view_model.position.lerp(target, minf(delta * 15, 1))
	view_model.position.z = maxf(view_model.position.z, minimum_z)
	camera.fov = move_toward(camera.fov, 55 if weapon.aiming else 75, delta * 100)
	reticle.visible = weapon.aiming and not weapon.reloading and obstruction < .15
	if crosshair != null:
		crosshair.visible = not reticle.visible

func update_magazine_attachment(socket: Node3D, hand_world: Transform3D) -> void:
	# Detach before moving the socket into the hand's withdrawal pose on this frame.
	var should_hold: bool = not static_calibration and weapon.reloading and reload_phase >= .18 and reload_phase < .82
	if not should_hold and magazine_held:
		var previous := magazine.global_transform
		magazine.reparent(model, true)
		attachment_jump = previous.origin.distance_to(magazine.global_position)
		attachment_angle = previous.basis.get_rotation_quaternion().angle_to(magazine.global_basis.get_rotation_quaternion())
		settle_from = magazine.transform
		settle_start = reload_phase
		magazine_settling = true
		magazine_held = false
		print("MAG_RELEASE phase=", reload_phase, " jump=", attachment_jump)
	socket.global_transform = hand_world
	if should_hold and not magazine_held:
		# A frame can cross the grab boundary; align to the current authored extraction phase.
		var extracted := smoothstep(.18, .38, reload_phase) * (1 - smoothstep(.62, .82, reload_phase))
		var local := magazine_rest
		local.origin += Vector3(0, -.14, .025) * extracted
		magazine.global_transform = model.global_transform * local
		magazine.reparent(socket, true)
		magazine_grip_offset = magazine.transform
		magazine_held = true
		magazine_settling = false
		print("MAG_ATTACH phase=", reload_phase)
	if magazine_held:
		magazine.transform = magazine_grip_offset
	elif magazine_settling:
		var seat := smoothstep(settle_start, minf(1.0, settle_start + .08), reload_phase) if weapon.reloading else 1.0
		magazine.transform = settle_from.interpolate_with(magazine_rest, seat)
		magazine_settling = seat < 1.0
	else:
		magazine.transform = magazine_rest
