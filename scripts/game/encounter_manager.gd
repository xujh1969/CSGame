extends Node

signal encounter_started(id: StringName)
signal encounter_cleared(id: StringName)

var enabled := true
var started: Dictionary = {}
var cleared: Dictionary = {}

func _ready() -> void:
	for area in get_node("../Triggers").get_children():
		if area is Area3D:
			area.body_entered.connect(_on_body_entered.bind(area.name))
	for enemy in get_node("../Enemies").get_children():
		enemy.get_node("HealthComponent").actor_died.connect(_on_enemy_died)

func _on_body_entered(body: Node3D, id: StringName) -> void:
	if body == get_node("../Player"):
		activate_encounter(id)

func activate_encounter(id: StringName) -> bool:
	if not enabled or started.has(id) or cleared.has(id):
		return false
	var trigger := get_node("../Triggers/" + str(id))
	var enemy = get_node("../Enemies/" + str(trigger.get_meta("enemy_id")))
	if not enemy.activate():
		return false
	started[id] = true
	encounter_started.emit(id)
	return true

func _on_enemy_died(actor_id: StringName) -> void:
	var id: StringName = get_node("../SpawnMarkers/" + str(actor_id)).get_meta("encounter_id")
	if cleared.has(id):
		return
	cleared[id] = true
	encounter_cleared.emit(id)
