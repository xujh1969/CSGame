extends Node

signal encounter_started(id: StringName)
signal encounter_cleared(id: StringName)

var enabled := true
var started: Dictionary = {}
var cleared: Dictionary = {}
var encounter_enemies: Dictionary = {}

func _ready() -> void:
	for area in get_node("../Triggers").get_children():
		if area is Area3D:
			area.body_entered.connect(_on_body_entered.bind(area.name))
	for enemy in get_node("../Enemies").get_children():
		var marker = get_node_or_null("../SpawnMarkers/" + str(enemy.name))
		if marker != null and marker.has_meta("encounter_id"):
			register_enemy(enemy, marker.get_meta("encounter_id"))

func register_enemy(enemy: Node, encounter_id: StringName) -> void:
	if not encounter_enemies.has(encounter_id):
		encounter_enemies[encounter_id] = []
	encounter_enemies[encounter_id].append(enemy)
	enemy.get_node("HealthComponent").actor_died.connect(_on_enemy_died.bind(encounter_id))

func _on_body_entered(body: Node3D, id: StringName) -> void:
	if body == get_node("../Player"):
		activate_encounter(id)

func activate_encounter(id: StringName) -> bool:
	if not enabled or started.has(id) or cleared.has(id):
		return false
	var trigger := get_node("../Triggers/" + str(id))
	var enemy_ids: Array = trigger.get_meta("enemy_ids", [trigger.get_meta("enemy_id")])
	var activated := false
	for enemy_id in enemy_ids:
		var enemy = get_node("../Enemies/" + str(enemy_id))
		activated = enemy.activate() or activated
	if not activated:
		return false
	started[id] = true
	encounter_started.emit(id)
	return true

func _on_enemy_died(_actor_id: StringName, id: StringName) -> void:
	if cleared.has(id):
		return
	for enemy in encounter_enemies.get(id, []):
		if enemy.is_alive():
			return
	cleared[id] = true
	encounter_cleared.emit(id)
