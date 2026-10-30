extends Node3D

signal fired(origin: Vector3, impact_position: Vector3, collider: Node)
signal impact(target: Node, position: Vector3, normal: Vector3)

@export var damage := 8
@export var spread := 0.035
@onready var actor: CharacterBody3D = get_parent()
@onready var perception = $"../Perception"
@onready var muzzle: Marker3D = $"../VisualRoot/Gun/Muzzle"
var random := RandomNumberGenerator.new()
var shots_fired := 0
var player_hits := 0

func _ready() -> void:
	random.seed = 20261027 + str(actor.name).hash()

func fire_at(point: Vector3) -> bool:
	if not actor.is_alive() or not perception.can_see_target():
		return false
	var origin: Vector3 = perception.global_position
	var aim := Basis.looking_at((point - origin).normalized())
	var direction := (aim * Vector3(random.randf_range(-spread, spread), random.randf_range(-spread, spread), -1)).normalized()
	var end: Vector3 = origin + direction * perception.view_distance
	var camera_hit := _ray(origin, end)
	if not camera_hit.is_empty():
		end = camera_hit.position
	var near_hit := _ray(origin, muzzle.global_position)
	var result: Dictionary
	if not near_hit.is_empty():
		result = near_hit
	else:
		var muzzle_hit := _ray(muzzle.global_position, end + (end - muzzle.global_position).normalized() * 0.02)
		result = muzzle_hit if not muzzle_hit.is_empty() else camera_hit
	shots_fired += 1
	var collider: Node = result.get("collider")
	if collider == perception.target:
		var health := collider.get_node("HealthComponent")
		if health.current_health > 0:
			health.apply_damage(damage)
			player_hits += 1
	fired.emit(origin, result.get("position", end), collider)
	if not result.is_empty():
		impact.emit(collider, result.position, result.normal)
	return true

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, [actor.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)
