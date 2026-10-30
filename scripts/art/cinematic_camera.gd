extends Node
## Conservative clear combat range. No focus noise, damage or input changes.

var attributes := CameraAttributesPractical.new()
var camera: Camera3D
var weapon: Node
var actor: CharacterBody3D
var low_quality := false
var focus_distance := 28.0

func _ready() -> void:
	var level := get_parent().get_parent()
	actor = level.get_node("Player")
	camera = actor.get_node("Camera3D")
	weapon = actor.get_node("WeaponController")
	attributes.dof_blur_far_distance = 32
	attributes.dof_blur_far_transition = 28
	attributes.dof_blur_near_distance = .2
	attributes.dof_blur_near_transition = .12
	attributes.dof_blur_amount = .10
	camera.attributes = attributes
	level.get_node("BattlePresentation").quality_changed.connect(set_low_quality)
	set_low_quality(false)

func set_low_quality(low: bool) -> void:
	low_quality = low
	attributes.dof_blur_far_enabled = not low
	attributes.dof_blur_near_enabled = not low

func _physics_process(delta: float) -> void:
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 100, 1 | 2 | 8, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var target := 45.0 if hit.is_empty() else origin.distance_to(hit.position)
	focus_distance = lerpf(focus_distance, clampf(target, 4, 70), minf(delta * 5, 1))
	# All current 24m combat is clear; distant silhouettes gradually lose detail.
	attributes.dof_blur_far_distance = maxf(28, focus_distance + 12)
	attributes.dof_blur_amount = move_toward(attributes.dof_blur_amount, .13 if weapon.aiming else .10, delta * .1)
	attributes.dof_blur_near_distance = .24 if weapon.aiming else .18
