extends CharacterBody3D

@export var look_sensitivity := 0.0025
@export var move_speed := 8.0

@onready var camera: Camera3D = $Camera3D
var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * look_sensitivity
		pitch = clampf(pitch - event.relative.y * look_sensitivity, deg_to_rad(-80), deg_to_rad(80))
		rotation.y = yaw
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if input.length_squared() > 0.0:
		var direction := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		move_and_collide(direction * move_speed * delta)
