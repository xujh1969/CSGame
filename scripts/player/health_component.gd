extends Node

signal health_changed(current: int, maximum: int)
signal actor_died(actor_id: StringName)

@export var max_health := 100
var current_health := 100

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: int) -> void:
	if current_health <= 0 or amount <= 0:
		return
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		actor_died.emit(get_parent().name)
