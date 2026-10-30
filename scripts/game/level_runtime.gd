extends Node3D
## Fixed gameplay is baked/editor-visible; only this bounded visual layer uses RNG.

const Slot = preload("res://scripts/game/asset_visual_slot.gd")
@export var layout_path := "res://data/vertical_slice.json"
@export var registry_path := "res://data/asset_registry.json"
@export var seed_override := -1
var active_seed := 0
var decoration_manifest: Array[Dictionary] = []
var missing_assets: Array[String] = []
var validation_errors: Array[String] = []
var decorations: Node3D
var baked_core: Dictionary = {}

func _ready() -> void:
	decorations = Node3D.new()
	decorations.name = "Decorations"
	add_child(decorations)
	var data = read_json(layout_path)
	validation_errors = validate_layout(data)
	if validation_errors.is_empty() and FileAccess.get_sha256(layout_path) != get_parent().get_meta("layout_sha256", ""):
		validation_errors.append("Layout changed: run python scripts/tools/build_vertical_slice.py before playing")
	if not validation_errors.is_empty():
		push_error("LevelRuntime: " + "; ".join(validation_errors))
		return
	baked_core = _core_data(data)
	rebuild(data, read_json(registry_path))

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func validate_layout(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if data.get("schema_version") != "1.0" or data.get("units") != "meters":
		errors.append("Unsupported schema/units")
	if data.get("axis_convention") != {"up": "+Y", "forward": "-Z"}:
		errors.append("Unsupported axis convention")
	var bounds = data.get("bounds")
	if not bounds is Dictionary or not _number(bounds.get("z_start")) or not _number(bounds.get("z_end")) or bounds.z_start <= bounds.z_end:
		errors.append("Invalid level bounds")
	var seed_value = data.get("seed")
	if not _integer(seed_value) or seed_value < 0 or seed_value > 2147483647:
		errors.append("seed must be an integer in 0..2147483647")
	var spawn = data.get("player_spawn")
	if not spawn is Dictionary or not _position(spawn.get("position")):
		errors.append("Invalid player_spawn")
	var objective = data.get("objective")
	if not objective is Dictionary or not _number(objective.get("finish_z")):
		errors.append("Invalid objective")
	var covers = data.get("covers")
	var encounters = data.get("encounters")
	if not covers is Array or not encounters is Array:
		errors.append("covers/encounters must be arrays")
	else:
		var ids := {}
		for cover in covers:
			if not cover is Dictionary or not _position(cover.get("position")) or not cover.get("kind", "") in ["low_concrete_wall", "jersey_barrier", "wooden_crates"]:
				errors.append("Invalid cover")
			elif ids.has(cover.get("id", "")) or str(cover.get("id", "")).is_empty():
				errors.append("Duplicate/empty cover id")
			else:
				ids[cover.id] = true
		ids.clear()
		var enemies := {}
		for encounter in encounters:
			if not encounter is Dictionary or not _position(encounter.get("spawn_position")) or not _position(encounter.get("peek_position")) or not _number(encounter.get("activate_at_z")):
				errors.append("Invalid encounter")
			elif ids.has(encounter.get("id", "")) or enemies.has(encounter.get("enemy_id", "")) or str(encounter.get("id", "")).is_empty() or str(encounter.get("enemy_id", "")).is_empty():
				errors.append("Duplicate/empty encounter or enemy id")
			else:
				ids[encounter.id] = true
				enemies[encounter.enemy_id] = true
		if not objective is Dictionary or not objective.get("required_enemies") is Array or objective.required_enemies.size() != enemies.size():
			errors.append("Required enemies do not match encounters")
		else:
			for enemy_id in objective.required_enemies:
				if not enemies.has(enemy_id):
					errors.append("Unknown required enemy")
	var decor = data.get("decoration")
	if not decor is Dictionary:
		errors.append("Missing decoration configuration")
		return errors
	if not _integer(decor.get("max_instances")) or decor.max_instances < 0 or decor.max_instances > 24:
		errors.append("decoration.max_instances must be in 0..24")
	if not _number(decor.get("chance")) or decor.chance < 0 or decor.chance > 1:
		errors.append("decoration.chance must be in 0..1")
	var sockets = decor.get("sockets")
	if not sockets is Array or sockets.size() > 24:
		errors.append("Invalid decoration sockets")
	else:
		var names := {}
		for socket in sockets:
			if not socket is Dictionary or not _position(socket.get("position")):
				errors.append("Invalid socket position")
				continue
			var p: Array = socket.position
			# Visuals are <=1m wide, anchored outside the road and above player height.
			if absf(p[0]) < 5.3 or absf(p[0]) > 5.7 or p[1] < 3.2 or p[1] > 6 or p[2] < -80 or p[2] > 0:
				errors.append("Socket outside safe facade band")
			if names.has(socket.get("id", "")) or str(socket.get("id", "")).is_empty():
				errors.append("Duplicate/empty socket id")
			names[socket.get("id", "")] = true
	var variants = decor.get("variants")
	if not variants is Array or variants.is_empty():
		errors.append("Missing decoration variants")
	else:
		for variant in variants:
			if not variant in ["facade_ac_A", "facade_vent_A"]:
				errors.append("Unsupported decoration variant")
	return errors

static func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _integer(value) -> bool:
	return _number(value) and float(value) == floor(float(value))

static func _position(value) -> bool:
	return value is Array and value.size() == 3 and _number(value[0]) and _number(value[1]) and _number(value[2])

static func _core_data(data: Dictionary) -> Dictionary:
	var core := data.duplicate(true)
	for key in ["seed", "decoration", "status", "validation_notes"]:
		core.erase(key)
	return core

func rebuild(data: Dictionary, registry: Dictionary) -> bool:
	validation_errors = validate_layout(data)
	if not baked_core.is_empty() and _core_data(data) != baked_core:
		validation_errors.append("Core layout differs from baked scene; rebuild offline")
	if not validation_errors.is_empty():
		return false
	var entries := {}
	for entry in registry.get("entries", []):
		if entry is Dictionary:
			entries[str(entry.get("id", ""))] = entry
	for variant in data.decoration.variants:
		var fallback: String = entries.get(variant, {}).get("fallback_scene", "")
		if fallback.is_empty() or not ResourceLoader.exists(fallback) or not load(fallback) is PackedScene:
			validation_errors.append("Missing fallback scene: " + str(variant))
	if not validation_errors.is_empty():
		return false
	# Clear only the layer owned by this component, never authored gameplay nodes.
	for child in decorations.get_children():
		decorations.remove_child(child)
		child.queue_free()
	decoration_manifest.clear()
	missing_assets.clear()
	active_seed = seed_override if seed_override >= 0 else int(data.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = active_seed
	for socket in data.decoration.sockets:
		if decoration_manifest.size() >= int(data.decoration.max_instances):
			break
		if rng.randf() > float(data.decoration.chance):
			continue
		var asset_id: String = data.decoration.variants[rng.randi_range(0, data.decoration.variants.size() - 1)]
		var entry: Dictionary = entries.get(asset_id, {})
		var path: String = entry.get("fallback_scene", "")
		var instance: Node3D = load(path).instantiate()
		instance.name = str(socket.id)
		instance.position = Vector3(socket.position[0], socket.position[1], socket.position[2])
		instance.rotation.y = PI / 2 if instance.position.x < 0 else -PI / 2
		decorations.add_child(instance)
		decoration_manifest.append({"id": socket.id, "asset_id": asset_id, "position": instance.position, "yaw": instance.rotation.y})
	_apply_slots(get_parent(), entries)
	print("LevelRuntime seed=", active_seed, " decoration=", decoration_manifest.size(), " missing GLB=", missing_assets)
	return true

func _apply_slots(node: Node, entries: Dictionary) -> void:
	if node is Slot:
		if not node.apply_entry(entries.get(node.asset_id, {})) and not missing_assets.has(node.asset_id):
			missing_assets.append(node.asset_id)
	for child in node.get_children():
		_apply_slots(child, entries)
