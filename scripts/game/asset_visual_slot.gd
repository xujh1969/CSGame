extends Node3D
## Visual-only GLB socket. Authored StaticBody/CollisionShape siblings stay authoritative.

@export var asset_id := ""
var loaded_path := ""

func apply_entry(entry: Dictionary) -> bool:
	var path := str(entry.get("proposed_path", ""))
	var replacement: Node3D
	if entry.get("status") == "ready" and path.ends_with(".glb") and ResourceLoader.exists(path):
		var packed = load(path)
		if packed is PackedScene:
			var instance = packed.instantiate()
			if instance is Node3D and _visual_only(instance):
				replacement = instance
			else:
				instance.free()
	# Remove before adding: a repeated rebuild must not accumulate children.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	loaded_path = ""
	for mesh in _fallback_meshes(get_parent()):
		mesh.visible = replacement == null
	if replacement == null:
		return false
	replacement.name = "Replacement"
	add_child(replacement)
	loaded_path = path
	return true

func _visual_only(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node.get_script() != null:
		return false
	for child in node.get_children():
		if not _visual_only(child):
			return false
	return true

func _fallback_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child == self:
			continue
		if child is MeshInstance3D:
			meshes.append(child)
		meshes.append_array(_fallback_meshes(child))
	return meshes
