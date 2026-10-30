extends Node3D

signal fired(origin: Vector3, direction: Vector3)
signal ammo_changed(mag: int, reserve: int)
signal reload_changed(active: bool)
signal dry_fired()
signal hit(target: Node, damage: int)
signal impact(target: Node, position: Vector3, normal: Vector3)
signal damage_requested(target: Node, amount: int, hit_position: Vector3, hit_normal: Vector3)

@export var mag_size := 30
@export var starting_reserve := 90
@export var fire_interval := 0.11
@export var reload_duration := 2.2
@export var damage := 25
@export var max_distance := 100.0
@export var hip_spread := 0.003
@export var ads_spread := 0.0005

@onready var camera: Camera3D = $"../Camera3D"
@onready var muzzle: Marker3D = $"../Camera3D/RifleViewModel/Muzzle"
@onready var actor: CharacterBody3D = get_parent()

var magazine := 30
var reserve := 90
var reloading := false
var aiming := false
var cooldown := 0.0
var reload_remaining := 0.0
var trigger_held := false
var random := RandomNumberGenerator.new()

func _ready() -> void:
	random.seed = 20261028
	reset_weapon()

func reset_weapon() -> void:
	magazine = mag_size
	reserve = starting_reserve
	reloading = false
	aiming = false
	trigger_held = false
	cooldown = 0.0
	reload_remaining = 0.0
	ammo_changed.emit(magazine, reserve)
	reload_changed.emit(false)

func set_controls(fire_held: bool, aim_held: bool, reload_pressed: bool, sprinting: bool) -> void:
	trigger_held = fire_held
	aiming = aim_held and not sprinting and not reloading
	if reload_pressed:
		request_reload()

func cancel_actions() -> void:
	trigger_held = false
	aiming = false
	reloading = false
	reload_remaining = 0.0
	reload_changed.emit(false)

func _physics_process(delta: float) -> void:
	advance(delta)
	if trigger_held:
		try_fire()

func advance(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if reloading:
		reload_remaining -= delta
		if reload_remaining <= 0.0:
			var transferred := mini(mag_size - magazine, reserve)
			magazine += transferred
			reserve -= transferred
			reloading = false
			ammo_changed.emit(magazine, reserve)
			reload_changed.emit(false)

func request_reload() -> bool:
	if reloading or magazine >= mag_size or reserve <= 0:
		return false
	reloading = true
	aiming = false
	reload_remaining = reload_duration
	reload_changed.emit(true)
	return true

func try_fire() -> bool:
	if reloading or cooldown > 0.0:
		return false
	if magazine <= 0:
		cooldown = 0.2
		dry_fired.emit()
		return false
	magazine -= 1
	cooldown = fire_interval
	ammo_changed.emit(magazine, reserve)
	var spread := ads_spread if aiming else hip_spread
	var local_direction := Vector3(random.randf_range(-spread, spread), random.randf_range(-spread, spread), -1.0)
	var direction := (camera.global_basis * local_direction).normalized()
	var result := trace_shot(camera.global_position, direction, muzzle.global_position)
	fired.emit(camera.global_position, direction)
	if not result.is_empty():
		var target: Node = result.collider
		impact.emit(target, result.position, result.normal)
		var health := target.get_node_or_null("HealthComponent")
		if health != null and health.current_health > 0:
			damage_requested.emit(target, damage, result.position, result.normal)
			health.apply_damage(damage)
			hit.emit(target, damage)
	return true

func trace_shot(origin: Vector3, direction: Vector3, muzzle_position: Vector3) -> Dictionary:
	var camera_hit := _ray(origin, origin + direction * max_distance)
	# A clipped viewmodel must not let the muzzle start beyond a solid wall.
	var near_blocker := _ray(origin, muzzle_position)
	if not near_blocker.is_empty():
		return near_blocker
	var aim_point: Vector3 = camera_hit.position if not camera_hit.is_empty() else origin + direction * max_distance
	var muzzle_hit := _ray(muzzle_position, aim_point + (aim_point - muzzle_position).normalized() * 0.02)
	return muzzle_hit if not muzzle_hit.is_empty() else camera_hit

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8, [actor.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)
