extends Node
## Owns only cross-level loading. Combat and outcome remain in the local GameFlow.

signal level_changed(id: String)
signal transition_failed(message: String)
const Catalog = preload("res://scripts/game/level_catalog.gd")
const Presentation = preload("res://scripts/fx/battle_presentation.gd")
const Flow = preload("res://scripts/game/game_flow.gd")
@export var catalog_path := "res://data/campaign.json"
var definitions: Dictionary = {}
var current_id := ""
var active_level: Node3D
var transitioning := true
var last_error := ""
var load_count := 0
var pending_id := ""
var prepared_level: Node3D
var closing := false
var transition_started_usec := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Status/Block/Center/Panel/Margin/Column/Retry.pressed.connect(_retry_error)
	_start.call_deferred()

func _start() -> void:
	var data := Catalog.read(catalog_path)
	var errors := Catalog.validate(data)
	if not errors.is_empty():
		_fail("; ".join(errors))
		return
	definitions.clear()
	for entry in data.levels:
		definitions[entry.id] = entry
	transitioning = false
	request_level(data.start_id)

func has_next_level() -> bool:
	return definitions.has(current_id) and not str(definitions[current_id].next_id).is_empty()

func next_level() -> bool:
	if transitioning or not is_instance_valid(active_level) or active_level.get_node("GameFlow").state != Flow.State.WON or not has_next_level():
		return false
	return request_level(definitions[current_id].next_id)

func restart_level() -> bool:
	if transitioning or current_id.is_empty():
		return false
	return request_level(current_id)

func request_level(id: String) -> bool:
	if closing or transitioning or not definitions.has(id):
		return false
	transitioning = true
	last_error = ""
	pending_id = id
	transition_started_usec = Time.get_ticks_usec()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Status/Block.visible = true
	$Status/Block/Center/Panel/Margin/Column/Message.text = "正在载入 · " + definitions[id].title
	$Status/Block/Center/Panel/Margin/Column/Retry.visible = false
	_perform_transition.call_deferred(id)
	return true

func _perform_transition(id: String) -> void:
	var definition: Dictionary = definitions[id]
	var packed = load(definition.scene_path)
	var candidate = packed.instantiate() if packed is PackedScene else null
	var error := _level_error(candidate, definition)
	if not error.is_empty():
		if candidate != null:
			candidate.free()
		_fail(error)
		return
	prepared_level = candidate
	var flow = candidate.get_node("GameFlow")
	flow.session = self
	flow.level_title = definition.title
	flow.required_encounters.clear()
	for encounter in definition.required_encounters:
		flow.required_encounters.append(StringName(encounter))
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(active_level):
		active_level.get_node("GameFlow").enabled = false
		active_level.get_node("BattlePresentation").stop_audio()
		await Presentation.drain_audio(get_tree())
		if closing:
			prepared_level.free()
			prepared_level = null
			return
		$LevelHost.remove_child(active_level)
		active_level.free()
	# Old flow's _exit_tree releases pause, so reassert during the new scene's ready.
	get_tree().paused = true
	current_id = id
	active_level = candidate
	prepared_level = null
	$LevelHost.add_child(active_level)
	load_count += 1
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	transitioning = false
	$Status/Block.visible = false
	print("Campaign loaded ", id, " transition_ms=", (Time.get_ticks_usec() - transition_started_usec) / 1000.0, " count=", load_count)
	level_changed.emit(id)

func _level_error(candidate: Node, definition: Dictionary) -> String:
	if not candidate is Node3D:
		return "Level root must be Node3D: " + definition.id
	for path in ["Player/WeaponController", "Player/HealthComponent", "GameFlow", "EncounterManager", "Enemies", "Triggers", "SpawnMarkers", "FinishArea", "BattlePresentation", "Sun"]:
		if not candidate.has_node(path):
			return "Missing level node: " + path
	if candidate.get_node("GameFlow").get_script() != Flow or candidate.get_node("BattlePresentation").get_script() != Presentation:
		return "Unsupported level flow/presentation component"
	if not candidate.get_node("Player") is CharacterBody3D or not candidate.get_node("FinishArea") is Area3D:
		return "Invalid player or finish area type"
	for id in definition.required_encounters:
		var trigger := candidate.get_node_or_null("Triggers/" + id) as Area3D
		if trigger == null:
			return "Missing encounter trigger: " + id
		var enemy_id := str(trigger.get_meta("enemy_id", ""))
		if enemy_id.is_empty() or not candidate.has_node("Enemies/" + enemy_id) or not candidate.has_node("SpawnMarkers/" + enemy_id):
			return "Missing encounter enemy/marker: " + id
	return ""

func _fail(message: String) -> void:
	last_error = message
	transitioning = false
	$Status/Block.visible = true
	$Status/Block/Center/Panel/Margin/Column/Message.text = "关卡载入失败\n" + message
	$Status/Block/Center/Panel/Margin/Column/Retry.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Campaign load rejected: ", message)
	transition_failed.emit(message)

func _retry_error() -> void:
	if definitions.is_empty():
		_start()
	else:
		request_level(pending_id)

func begin_shutdown() -> void:
	closing = true

func _exit_tree() -> void:
	if is_instance_valid(prepared_level):
		prepared_level.free()
	get_tree().paused = false
