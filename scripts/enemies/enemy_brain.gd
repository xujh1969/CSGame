extends CharacterBody3D

signal state_changed(actor_id: StringName, state_name: StringName)

enum State { DORMANT, ALERT, AIM, FIRE_BURST, SEEK_COVER, COOLDOWN, SEARCH, DEAD }

@export_enum("corner_ambusher", "window_sentry", "cover_rifleman") var archetype := "corner_ambusher"
@export var reaction_delay := 0.65
@export var aim_delay := 0.45
@export var burst_size := 3
@export var burst_interval := 0.18
@export var cooldown_duration := 1.5
@export var search_duration := 2.0
@export var movement_speed := 2.0
@export var view_distance := 25.0
@export var tint := Color(0.8, 0.3, 0.16)
@export var player_path := NodePath("../../Player")
@export var cover_path: NodePath
@export var peek_path: NodePath

@onready var health = $HealthComponent
@onready var perception = $Perception
@onready var weapon = $EnemyWeapon
@onready var visual = $VisualRoot
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var player: CharacterBody3D = get_node(player_path)
@onready var cover_marker: Marker3D = get_node(cover_path)
@onready var peek_marker: Marker3D = get_node(peek_path)
@onready var navigation: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var state := State.DORMANT
var active := false
var activation_count := 0
var remaining := 0.0
var elapsed := 0.0
var burst_left := 0
var shot_cooldown := 0.0
var last_known_position := Vector3.ZERO

func _ready() -> void:
	perception.target = player
	perception.view_distance = view_distance
	health.actor_died.connect(_on_died)
	_update_pose(1.0)

func activate() -> bool:
	if active or not is_alive():
		return false
	active = true
	activation_count += 1
	_transition(State.ALERT)
	return true

func apply_damage(amount: int) -> void:
	health.apply_damage(amount)

func is_alive() -> bool:
	return health.current_health > 0

func get_state() -> StringName:
	return State.keys()[state]

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if state == State.DEAD:
		return
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	if player.get_node("HealthComponent").current_health <= 0:
		if active and state != State.COOLDOWN:
			_transition(State.COOLDOWN)
		_update_pose(delta)
		move_and_slide()
		return
	elapsed += delta
	remaining -= delta
	var sees_player: bool = perception.can_see_target()
	if sees_player and active:
		last_known_position = perception.target_point()
		visual.aim_at(last_known_position)
	match state:
		State.DORMANT:
			pass
		State.ALERT:
			if remaining <= 0:
				_transition(State.AIM)
		State.AIM:
			if archetype == "corner_ambusher" and not _travel_to(peek_marker.global_position):
				remaining = aim_delay
				if elapsed > 4.0:
					_transition(State.SEARCH)
			elif not sees_player:
				_transition(State.SEARCH)
			elif remaining <= 0:
				_transition(State.FIRE_BURST)
		State.FIRE_BURST:
			if not sees_player:
				_transition(State.SEARCH)
			else:
				shot_cooldown -= delta
				if shot_cooldown <= 0:
					weapon.fire_at(last_known_position)
					burst_left -= 1
					shot_cooldown = burst_interval
					if burst_left <= 0:
						_transition(State.SEEK_COVER)
		State.SEEK_COVER:
			var arrived := true
			if archetype == "corner_ambusher":
				arrived = _travel_to(cover_marker.global_position)
			if (arrived and remaining <= 0) or elapsed > 4.0:
				_transition(State.COOLDOWN)
		State.COOLDOWN:
			if remaining <= 0:
				_transition(State.AIM)
		State.SEARCH:
			if sees_player:
				_transition(State.AIM)
			elif remaining <= 0:
				_transition(State.SEEK_COVER)
	_update_pose(delta)
	move_and_slide()

func _travel_to(point: Vector3) -> bool:
	if Vector2(position.x - point.x, position.z - point.z).length() < 0.15:
		return true
	if navigation == null or NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) == 0:
		return false
	if navigation.target_position.distance_to(point) > 0.05:
		navigation.target_position = point
	var next := navigation.get_next_path_position()
	var direction := next - global_position
	direction.y = 0
	direction = direction.normalized()
	velocity.x = direction.x * movement_speed
	velocity.z = direction.z * movement_speed
	return false

func _update_pose(delta: float) -> void:
	var crouched := state in [State.DORMANT, State.SEEK_COVER, State.COOLDOWN]
	var capsule := body_shape.shape as CapsuleShape3D
	var height := move_toward(capsule.height, 1.0 if crouched else 1.8, delta * 5.0)
	capsule.height = height
	body_shape.position.y = height * 0.5
	perception.position.y = height - 0.15
	visual.set_height(height)

func _transition(next: State) -> void:
	state = next
	elapsed = 0.0
	match state:
		State.ALERT:
			remaining = maxf(0.4, reaction_delay)
		State.AIM:
			remaining = aim_delay
		State.FIRE_BURST:
			burst_left = burst_size
			shot_cooldown = 0.0
		State.SEEK_COVER:
			remaining = 0.3
		State.COOLDOWN:
			remaining = cooldown_duration
		State.SEARCH:
			remaining = search_duration
	state_changed.emit(name, get_state())

func _on_died(_actor_id: StringName) -> void:
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	body_shape.set_deferred("disabled", true)
	_transition(State.DEAD)
