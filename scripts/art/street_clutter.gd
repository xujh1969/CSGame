extends Node3D
## Fixed placements, with actual static triangle collision and no random path changes.

const PLACEMENTS = [
	[1, 0, Vector3(4.1, 0, -13), 0.3],
	[2, 0, Vector3(-4.1, 0, 0), 0.2], [2, 1, Vector3(4.2, 0, 1), -0.3],
	[2, 2, Vector3(-4.2, 0, -4), 1.0], [2, 3, Vector3(4.2, 0, -9), 0.5],
	[2, 4, Vector3(4.1, 0, -18), -0.6], [2, 5, Vector3(-4.3, 0, -20), 0.8],
	[3, 0, Vector3(-3.9, 0, -2), -0.4], [3, 1, Vector3(4.2, 0, -3), 0.9],
	[3, 2, Vector3(-4.1, 0, -7), 0.3], [3, 3, Vector3(4.3, 0, -16), -0.7],
	[3, 4, Vector3(-4.2, 0, -11), 0.5], [3, 5, Vector3(4.2, 0, -21), 0.1]]

var piles: Array[StaticBody3D] = []

func _ready() -> void:
	var registry: Dictionary = get_parent().get_parent().get_node("StreetArt").registry
	for placement in PLACEMENTS:
		var entry: Dictionary = registry["street_clutter" + str(placement[0])]
		var library: Node3D = load(entry.proposed_path).instantiate()
		var part: MeshInstance3D = library.find_child("Pile" + str(placement[1]), true, false)
		part.get_parent().remove_child(part)
		library.free()
		var body := StaticBody3D.new()
		body.name = "ClutterPile" + str(piles.size())
		body.position = placement[2]
		body.rotation.y = placement[3]
		body.collision_layer = 1
		body.set_meta("surface_type", "concrete")
		add_child(body)
		body.add_child(part)
		var collision := CollisionShape3D.new()
		collision.shape = part.mesh.create_trimesh_shape()
		collision.transform = part.transform
		body.add_child(collision)
		piles.append(body)
