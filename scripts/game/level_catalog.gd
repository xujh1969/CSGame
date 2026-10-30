extends RefCounted
## Validates this small linear campaign, not a general graph or map editor.

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if data.get("schema_version") != "1.0" or not data.get("levels") is Array or data.levels.is_empty():
		errors.append("Invalid campaign schema or empty levels")
		return errors
	var ids := {}
	for level in data.levels:
		if not level is Dictionary:
			errors.append("Level must be an object")
			continue
		var id = level.get("id")
		if not id is String or id.is_empty() or ids.has(id):
			errors.append("Duplicate/empty level id")
			continue
		ids[id] = level
		if not level.get("title") is String or level.title.strip_edges().is_empty():
			errors.append("Missing level title: " + id)
		var path = level.get("scene_path")
		if not path is String or not path.begins_with("res://") or not path.ends_with(".tscn") or not ResourceLoader.exists(path):
			errors.append("Missing scene: " + id)
		elif not load(path) is PackedScene:
			errors.append("Not a PackedScene: " + id)
		if not level.get("next_id") is String:
			errors.append("Invalid next_id: " + id)
		var encounters = level.get("required_encounters")
		if not encounters is Array:
			errors.append("Invalid required_encounters: " + id)
		else:
			var seen := {}
			for encounter in encounters:
				if not encounter is String or encounter.is_empty() or seen.has(encounter):
					errors.append("Duplicate/empty encounter id: " + id)
				seen[encounter] = true
	if not data.get("start_id") is String or not ids.has(data.start_id):
		errors.append("Missing start level")
	for id in ids:
		var next_id = ids[id].get("next_id")
		if next_id is String and not next_id.is_empty() and not ids.has(next_id):
			errors.append("Unknown next level: " + id)
	if not errors.is_empty():
		return errors
	var visited := {}
	var cursor: String = data.start_id
	while not cursor.is_empty():
		if visited.has(cursor):
			errors.append("Campaign contains a cycle")
			break
		visited[cursor] = true
		cursor = ids[cursor].next_id
	if visited.size() != ids.size():
		errors.append("Campaign contains unreachable levels")
	return errors
