extends CharacterBody3D

@export var walk_speed := 4.0
@export var sprint_speed := 6.5
@export var crouch_speed := 2.0
@export var jump_height := 1.0
@export var gravity := 9.8
@export var standing_height := 1.8
@export var crouching_height := 1.15
@export var crouch_transition_speed := 8.0

@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var camera: Camera3D = $Camera3D

var crouch_requested := false
var target_height := standing_height
var pitch := 0.0

func request_crouch(value: bool) -> void:
	crouch_requested = value

func move_player(move_input: Vector2, sprint_requested: bool, jump_requested: bool, delta: float) -> void:
	var wants_crouch := crouch_requested
	if not wants_crouch and target_height < standing_height and not _can_stand():
		wants_crouch = true
	target_height = crouching_height if wants_crouch else standing_height

	var capsule := body_shape.shape as CapsuleShape3D
	var current_height := capsule.height
	var next_height := move_toward(current_height, target_height, crouch_transition_speed * delta)
	var camera_target := 1.1 if wants_crouch else 1.7
	body_shape.position.y = next_height * 0.5
	capsule.height = next_height
	camera.position.y = move_toward(camera.position.y, camera_target, crouch_transition_speed * delta)

	var input_direction := Vector3(move_input.x, 0.0, move_input.y)
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()
	var direction := (global_transform.basis * input_direction).normalized()
	var speed := crouch_speed if wants_crouch else (sprint_speed if sprint_requested else walk_speed)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if is_on_floor():
		if jump_requested and not wants_crouch:
			velocity.y = sqrt(2.0 * gravity * jump_height)
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var test_shape := CapsuleShape3D.new()
	test_shape.radius = (body_shape.shape as CapsuleShape3D).radius
	test_shape.height = standing_height
	query.shape = test_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, standing_height * 0.5 + 0.05, 0.0))
	query.margin = 0.0
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


