extends Node3D

@onready var enemy = get_parent()
@onready var body: MeshInstance3D = $Body
@onready var head: MeshInstance3D = $Head
@onready var label: Label3D = $"../Label3D"
@onready var health = $"../HealthComponent"
var flash_remaining := 0.0
var presentation:Node3D

func _ready() -> void:
	body.mesh = body.mesh.duplicate()
	body.material_override = body.material_override.duplicate()
	head.material_override = body.material_override
	enemy.state_changed.connect(_on_state)
	health.health_changed.connect(_on_health)
	$"../EnemyWeapon".fired.connect(_on_fired)
	if ResourceLoader.exists("res://assets/models/task010/enemy_fighter.glb"):
		presentation=preload("res://scripts/enemies/enemy_presentation.gd").new()
		presentation.name="RiggedEnemy"
		add_child(presentation)
		body.hide();head.hide();$Gun/Mesh.hide();label.hide()
	_refresh()

func aim_at(point: Vector3) -> void:
	var local: Vector3 = enemy.to_local(point)
	rotation.y = atan2(-local.x, -local.z)
	$Gun.rotation.x = atan2(local.y - $Gun.position.y, Vector2(local.x, local.z).length())
	if presentation != null:
		presentation.aim_at(point)

func set_height(height: float) -> void:
	if enemy.get_state() == &"DEAD":
		return
	body.mesh.height = height
	body.position.y = height * 0.5
	head.position.y = height - 0.18
	$Gun.position.y = height - 0.38
	if presentation!=null:presentation.crouched=height<1.4

func _on_fired(_origin: Vector3, _impact: Vector3, _collider: Node) -> void:
	flash_remaining = 0.08

func _process(delta: float) -> void:
	flash_remaining = maxf(0, flash_remaining - delta)
	$Gun/Muzzle/Flash.visible = presentation==null and flash_remaining > 0 and enemy.is_alive()

func _on_health(_current: int, _maximum: int) -> void:
	_refresh()

func _on_state(_actor_id: StringName, state: StringName) -> void:
	if state == &"DEAD":
		if presentation==null:scale.y = 0.3
		flash_remaining = 0.0
	_refresh()

func _refresh() -> void:
	var state: StringName = enemy.get_state()
	var color: Color = enemy.tint
	if state == &"ALERT":
		color = Color(1, 0.8, 0.12)
	elif health.current_health <= 0:
		color = Color(0.2, 0.2, 0.2)
	body.material_override.albedo_color = color
	label.text = "%s  %d HP\n%s" % [enemy.name, health.current_health, state]
