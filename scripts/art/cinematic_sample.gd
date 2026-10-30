extends Node3D
## Opt-in TASK-009 presentation; the accepted v003 fixture stays available.

@export var static_hand_calibration := false
@export var calibration_asset_id: StringName = &"player_fp_arms_calibration"

var rifle: Node3D
var lens: Node

func _ready() -> void:
	var level := get_parent()
	get_window().title = "Urban Corridor FPS / TASK-009 Hand Calibration v006" if static_hand_calibration else "Urban Corridor FPS / TASK-009 Cinematic v005"
	var environment: Environment = level.get_node("WorldEnvironment").environment
	environment.ambient_light_energy = .75
	environment.fog_density = .002
	environment.adjustment_contrast = 1.06
	environment.tonemap_exposure = .92
	level.get_node("Sun").light_energy = 1.4
	var registry: Dictionary = level.get_node("StreetArt").registry
	var backdrop: Node3D = load(registry.cinematic_skyline.proposed_path).instantiate()
	backdrop.name = "DistantCity"
	add_child(backdrop)
	var arm_asset: Dictionary = registry[calibration_asset_id] if static_hand_calibration else registry.player_fp_arms
	var camera: Camera3D = level.get_node("Player/Camera3D")
	rifle = preload("res://scripts/weapons/cinematic_rifle.gd").new()
	rifle.name = "CinematicRifle"
	rifle.model_path = registry.fps_rifle_m4_sample.proposed_path
	rifle.grip_calibration = arm_asset.right_grip_socket
	rifle.static_calibration = static_hand_calibration
	if registry.fps_rifle_m4_sample.has("mounts"):
		var muzzle: Array = registry.fps_rifle_m4_sample.mounts.muzzle
		rifle.muzzle_offset = Vector3(muzzle[0], muzzle[1], muzzle[2])
	camera.get_node("RifleViewModel").add_child(rifle)
	var arms := preload("res://scripts/weapons/first_person_arms.gd").new()
	arms.name = "FirstPersonArms"
	arms.model_path = arm_asset.proposed_path
	arms.static_calibration = static_hand_calibration
	camera.get_node("RifleViewModel").add_child(arms)
	var clutter := preload("res://scripts/art/street_clutter.gd").new()
	clutter.name = "StreetClutter"
	add_child(clutter)
	lens = preload("res://scripts/art/cinematic_camera.gd").new()
	lens.name = "CinematicCamera"
	add_child(lens)
	level.get_node("GameFlow").level_title = "电影镜头与步枪样板 / 24m"
