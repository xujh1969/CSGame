extends Node

signal state_changed(state_name: StringName)
signal objective_changed(text: String)

enum State { RUNNING, PAUSED, FAILED, WON }
@export var required_encounters: Array[StringName] = [&"T1", &"T2", &"T3"]
var session: Node
var level_title := ""
var state := State.RUNNING
var enabled := true
var finish_reached := false
var outcome_pending := false
var quitting := false

@onready var player: CharacterBody3D = $"../Player"
@onready var encounters = $"../EncounterManager"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	add_to_group("game_flow")
	player.get_node("HealthComponent").actor_died.connect(_on_player_died)
	encounters.encounter_cleared.connect(_on_cleared)
	$"../FinishArea".body_entered.connect(_on_finish_entered)
	$"../FinishArea".body_exited.connect(_on_finish_exited)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not enabled or state in [State.FAILED, State.WON]:
		return
	_set_state(State.RUNNING if state == State.PAUSED else State.PAUSED)

func _set_state(next: State) -> void:
	if next == state:
		return
	state = next
	if state != State.RUNNING:
		player.get_node("WeaponController").set_controls(false, false, false, false)
	if state in [State.FAILED, State.WON]:
		player.get_node("WeaponController").cancel_actions()
		encounters.enabled = false
	get_tree().paused = state != State.RUNNING
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if state == State.RUNNING else Input.MOUSE_MODE_VISIBLE
	state_changed.emit(State.keys()[state])

func get_objective() -> String:
	var count := 0
	for id in required_encounters:
		if encounters.cleared.has(id):
			count += 1
	if count == required_encounters.size():
		return _title_prefix() + "威胁已清除 · 前往绿色终点线"
	return _title_prefix() + "清除街段威胁  %d / %d" % [count, required_encounters.size()]

func _title_prefix() -> String:
	return level_title + "\n" if not level_title.is_empty() else ""

func has_next_level() -> bool:
	return is_instance_valid(session) and session.has_next_level()

func advance() -> void:
	if state == State.WON and is_instance_valid(session):
		session.next_level()

func _on_player_died(_id: StringName) -> void:
	_request_outcome()

func _on_cleared(_id: StringName) -> void:
	objective_changed.emit(get_objective())
	_request_outcome()

func _on_finish_entered(body: Node3D) -> void:
	if body == player:
		finish_reached = true
		_request_outcome()

func _on_finish_exited(body: Node3D) -> void:
	if body == player:
		finish_reached = false

func _request_outcome() -> void:
	if not enabled or outcome_pending:
		return
	outcome_pending = true
	_resolve_outcome.call_deferred()

func _resolve_outcome() -> void:
	outcome_pending = false
	if not enabled or state in [State.FAILED, State.WON]:
		return
	if player.get_node("HealthComponent").current_health <= 0:
		_set_state(State.FAILED)
		return
	if not finish_reached:
		return
	for id in required_encounters:
		if not encounters.cleared.has(id):
			return
	_set_state(State.WON)

func restart() -> void:
	if is_instance_valid(session):
		session.restart_level()
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _exit_tree() -> void:
	get_tree().paused = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not quitting:
		_quit_game()

func _quit_game() -> void:
	quitting = true
	if is_instance_valid(session):
		session.begin_shutdown()
	get_tree().paused = true
	get_node("../BattlePresentation").stop_audio()
	await preload("res://scripts/fx/battle_presentation.gd").drain_audio(get_tree())
	get_tree().quit()
