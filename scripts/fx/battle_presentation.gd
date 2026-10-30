extends Node3D

signal quality_changed(low: bool)
const IMPACT_FX = preload("res://scenes/fx/ImpactFx.tscn")
const FLASH = preload("res://scenes/fx/MuzzleFlash.tscn")
var low_quality := false
var streams: Dictionary = {}
var effects := Node3D.new()
var sounds := Node3D.new()
var flash: Node3D
var step_time := 0.0
var previous_floor := false
var previous_vertical := 0.0
var audio_closed := false

@onready var player: CharacterBody3D = $"../Player"
@onready var weapon = $"../Player/WeaponController"

func _init() -> void:
	# Own these immediately, including when a prepared level is rejected before ready.
	effects.name = "Effects"
	sounds.name = "Sounds"
	add_child(effects)
	add_child(sounds)

func _ready() -> void:
	add_to_group("battle_presentation")
	for sound in ["shot", "reload", "hurt", "step", "alert", "empty", "jump", "land", "victory"]:
		streams[sound] = load("res://assets/audio/" + sound + ".wav")
	flash = FLASH.instantiate()
	weapon.muzzle.add_child(flash)
	weapon.fired.connect(_player_fired)
	weapon.impact.connect(_impact)
	weapon.dry_fired.connect(_empty)
	weapon.reload_changed.connect(_reload)
	player.get_node("HealthComponent").health_changed.connect(_hurt)
	for enemy in get_node("../Enemies").get_children():
		enemy.get_node("EnemyWeapon").fired.connect(_enemy_fired)
		enemy.get_node("EnemyWeapon").impact.connect(_impact)
		enemy.state_changed.connect(_enemy_state.bind(enemy))
	get_node("../GameFlow").state_changed.connect(_flow_state)

func set_low_quality(value: bool) -> void:
	low_quality = value
	get_node("../Sun").shadow_enabled = not value
	for effect in effects.get_children():
		effect.queue_free()
	quality_changed.emit(value)

func _player_fired(_origin: Vector3, direction: Vector3) -> void:
	flash.trigger()
	_sound("shot", weapon.muzzle.global_position, 32.0, -14.0)
	_effect(&"smoke", weapon.muzzle.global_position, (Vector3.UP - direction * 0.15).normalized())

func _enemy_fired(origin: Vector3, _point: Vector3, _collider: Node) -> void:
	_sound("shot", origin, 35.0, -16.0)

func _impact(target: Node, point: Vector3, normal: Vector3) -> void:
	var kind: StringName = target.get_meta("surface_type", &"concrete")
	if target.has_node("HealthComponent"):
		kind = &"hit"
	_effect(kind, point, normal)

func _effect(kind: StringName, point: Vector3, normal: Vector3) -> void:
	if low_quality and kind in [&"smoke", &"concrete", &"wood"]:
		return
	if effects.get_child_count() >= (6 if low_quality else 20):
		return
	var effect = IMPACT_FX.instantiate()
	effect.kind = kind
	effect.normal = normal
	effect.position = effects.to_local(point + normal * 0.02)
	effects.add_child(effect)

func _sound(id: String, point: Vector3, max_distance: float, volume: float, always := false) -> void:
	if audio_closed:
		return
	if sounds.get_child_count() >= (6 if low_quality else 12):
		return
	var sound := AudioStreamPlayer3D.new()
	sound.stream = streams[id]
	sound.max_distance = max_distance
	sound.unit_size = 4.0
	sound.volume_db = volume
	if always:
		sound.process_mode = Node.PROCESS_MODE_ALWAYS
	sound.position = sounds.to_local(point)
	sounds.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func _empty() -> void:
	_sound("empty", player.global_position, 6.0, -18.0)

func _reload(active: bool) -> void:
	if active:
		_sound("reload", player.global_position, 6.0, -15.0)

func _hurt(_current: int, _maximum: int) -> void:
	_sound("hurt", player.global_position, 8.0, -15.0)

func _enemy_state(_id: StringName, state: StringName, enemy: Node3D) -> void:
	if state == &"ALERT":
		_sound("alert", enemy.global_position, 22.0, -16.0)

func _flow_state(state: StringName) -> void:
	if state in [&"FAILED", &"WON"]:
		for effect in effects.get_children():
			effect.queue_free()
		for sound in sounds.get_children():
			sound.stop()
			sounds.remove_child(sound)
			sound.queue_free()
		flash.remaining = 0.0
		flash.visible = false
		if state == &"WON":
			_sound("victory", player.global_position, 8.0, -12.0, true)

func _physics_process(delta: float) -> void:
	var grounded := player.is_on_floor()
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if grounded and speed > 0.5:
		step_time -= delta
		if step_time <= 0:
			_sound("step", player.global_position, 8.0, -20.0)
			step_time = 0.3 if speed > 5.0 else 0.48
	if previous_floor and not grounded and player.velocity.y > 1.0:
		_sound("jump", player.global_position, 8.0, -19.0)
	if not previous_floor and grounded and previous_vertical < -0.5:
		_sound("land", player.global_position, 10.0, -17.0)
	previous_floor = grounded
	previous_vertical = player.velocity.y

func _exit_tree() -> void:
	stop_audio()
	streams.clear()

func stop_audio() -> void:
	audio_closed = true
	for sound in sounds.get_children():
		sound.stop()
		sound.stream = null

static func drain_audio(tree: SceneTree) -> void:
	# AudioServer releases stopped playbacks asynchronously over mix callbacks.
	var previous := AudioServer.get_time_since_last_mix()
	var cycles := 0
	var deadline := Time.get_ticks_msec() + 250
	while cycles < 3 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		var current := AudioServer.get_time_since_last_mix()
		if current < previous:
			cycles += 1
		previous = current
	print("Audio shutdown mix cycles: ", cycles)
