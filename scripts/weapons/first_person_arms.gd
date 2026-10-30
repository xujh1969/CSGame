extends Node3D
## Visual pose playback only; the weapon timer remains authoritative.

var model_path := ""
var static_calibration := false
var weapon: Node
var player: AnimationPlayer
var hold_animation := ""
var reload_animation := ""
var fire_animation := ""
var fire_remaining := 0.0
var rifle: Node3D
var magazine_socket: Node3D
var skeleton: Skeleton3D
var current := ""
var camera: Camera3D
var reachability_errors := {"R": 0.0, "L": 0.0}
var segment_lengths := {}

func _ready() -> void:
	process_priority = 1
	var view_model := get_parent()
	rifle = view_model.get_node("CinematicRifle")
	camera = view_model.get_parent()
	weapon = view_model.get_parent().get_parent().get_node("WeaponController")
	weapon.fired.connect(_on_fired)
	var model: Node3D = load(model_path).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for side in ["R", "L"]:
		var a := skeleton.get_bone_global_rest(skeleton.find_bone(side + "_Upper")).origin
		var b := skeleton.get_bone_global_rest(skeleton.find_bone(side + "_Forearm")).origin
		var c := skeleton.get_bone_global_rest(skeleton.find_bone(side + "_Hand")).origin
		segment_lengths[side] = Vector2(a.distance_to(b), b.distance_to(c))
	if not static_calibration:
		player = model.find_children("*", "AnimationPlayer", true, false)[0]
		for name in player.get_animation_list():
			if name.ends_with("Hold"):
				hold_animation = name
			elif name.ends_with("Fire"):
				fire_animation = name
			elif name.ends_with("Reload"):
				reload_animation = name
		player.set_process(false)
		player.set_physics_process(false)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.deterministic = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	magazine_socket = Node3D.new()
	magazine_socket.name = "LeftMagazineSocket"
	add_child(magazine_socket)
	_update_pose()

func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	fire_remaining = weapon.fire_interval

func _process(delta: float) -> void:
	fire_remaining = maxf(0, fire_remaining - delta)
	_update_pose()

func _update_pose() -> void:
	# Exported animations may omit constant tracks. Clear last frame's IK before evaluation.
	skeleton.reset_bone_poses()
	if static_calibration:
		current = "StaticBind"
	else:
		var firing: bool = not weapon.reloading and fire_remaining > 0 and fire_animation != ""
		var animation := reload_animation if weapon.reloading else (fire_animation if firing else hold_animation)
		if current != animation:
			player.play(animation)
			current = animation
		var duration := player.get_animation(animation).length
		# glTF retains the source first-frame offset; use its exact sampled time span.
		var first := 0.0
		var clip: Animation = player.get_animation(animation)
		for track in clip.get_track_count():
			if clip.track_get_key_count(track) > 1:
				first = clip.track_get_key_time(track, 0)
				break
		var phase: float = rifle.reload_phase if weapon.reloading else (clampf(1 - fire_remaining / weapon.fire_interval, 0, 1) if firing else 0.0)
		var time: float = lerpf(first, duration, phase)
		player.seek(time, true)
		player.advance(0)
	_anchor_shoulders()
	var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("L_Hand"))
	rifle.update_magazine_attachment(magazine_socket, hand_world)

func _set_world(index: int, world: Transform3D) -> void:
	var desired := skeleton.global_transform.affine_inverse() * world
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		desired = skeleton.get_bone_global_pose(parent).affine_inverse() * desired
	# Godot 4 pose already includes the rest transform; applying its inverse twice stretches the skin.
	skeleton.set_bone_pose(index, desired)

func _anchor_shoulders() -> void:
	for side in ["R", "L"]:
		var upper := skeleton.find_bone(side + "_Upper")
		var forearm := skeleton.find_bone(side + "_Forearm")
		var hand := skeleton.find_bone(side + "_Hand")
		var a := skeleton.global_transform * skeleton.get_bone_global_pose(upper)
		var b := skeleton.global_transform * skeleton.get_bone_global_pose(forearm)
		var c := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
		var length_a: float = segment_lengths[side].x
		var length_b: float = segment_lengths[side].y
		var sign_value := 1.0 if side == "R" else -1.0
		var shoulder := camera.to_global(Vector3(sign_value * .22, -.25, .01))
		var direction := c.origin - shoulder
		var distance := clampf(direction.length(), absf(length_a - length_b) + .001, length_a + length_b - .001)
		direction = direction.normalized()
		var wrist := shoulder + direction * distance
		reachability_errors[side] = wrist.distance_to(c.origin)
		var projection := (length_a * length_a - length_b * length_b + distance * distance) / (2 * distance)
		var pole := camera.global_basis * Vector3(sign_value * .5, -.6, .05)
		var bend := (pole - direction * pole.dot(direction)).normalized()
		var elbow := shoulder + direction * projection + bend * sqrt(maxf(0, length_a * length_a - projection * projection))
		var upper_rotation := Quaternion((b.origin - a.origin).normalized(), (elbow - shoulder).normalized())
		var fore_rotation := Quaternion((c.origin - b.origin).normalized(), (wrist - elbow).normalized())
		_set_world(upper, Transform3D((Basis(upper_rotation) * a.basis).orthonormalized(), shoulder))
		_set_world(forearm, Transform3D((Basis(fore_rotation) * b.basis).orthonormalized(), elbow))
		c.basis = c.basis.orthonormalized()
		c.origin = wrist
		_set_world(hand, c)
