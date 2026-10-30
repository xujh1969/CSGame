extends Node3D

@export var mouse_sensitivity := 0.0025

@onready var motor: CharacterBody3D = get_parent()
@onready var camera: Camera3D = $"../Camera3D"
@onready var weapon = $"../WeaponController"
@onready var health = $"../HealthComponent"

var yaw := 0.0
var pitch := 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon.fired.connect(_on_fired)
	health.actor_died.connect(_on_player_died)

func _on_player_died(_actor_id: StringName) -> void:
	weapon.cancel_actions()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_physics_process(false)

func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	pitch = clampf(pitch - 0.012, deg_to_rad(-80.0), deg_to_rad(80.0))
	camera.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().get_first_node_in_group("game_flow") != null:
			return
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif health.current_health <= 0:
		return
	elif event.is_action_pressed("fire"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		motor.rotation.y = yaw
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var movement := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	motor.request_crouch(Input.is_action_pressed("crouch"))
	motor.move_player(movement, Input.is_action_pressed("sprint"), Input.is_action_just_pressed("jump"), delta)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	weapon.set_controls(captured and Input.is_action_pressed("fire"), captured and Input.is_action_pressed("aim"), captured and Input.is_action_just_pressed("reload"), Input.is_action_pressed("sprint"))

