extends Node3D

@onready var weapon = $"../../WeaponController"
@onready var camera: Camera3D = get_parent()
var kick := 0.0

func _ready() -> void:
	weapon.fired.connect(_on_fired)

func _on_fired(_origin: Vector3, _direction: Vector3) -> void:
	kick = 0.05

func _process(delta: float) -> void:
	kick = move_toward(kick, 0.0, delta * 0.4)
	var target := Vector3(0.0, -0.13, -0.45) if weapon.aiming else Vector3(0.28, -0.22, -0.5)
	position = position.lerp(target, minf(1.0, delta * 12.0))
	position.z += kick * minf(1.0, delta * 12.0)
	rotation.x = -0.35 if weapon.reloading else 0.0
	camera.fov = move_toward(camera.fov, 55.0 if weapon.aiming else 75.0, delta * 100.0)
