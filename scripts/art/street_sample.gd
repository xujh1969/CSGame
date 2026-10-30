extends Node3D
## Environment-only adaptation of the existing combat fixture. No gameplay overrides.

const Slot = preload("res://scripts/game/asset_visual_slot.gd")
const SHOP = preload("res://scenes/levels/modules/Shopfront.tscn")
const CRATES = preload("res://scenes/cover/WoodenCrates.tscn")
var loaded_assets: Array[String] = []
var asset_errors: Array[String] = []
var registry := {}

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_registry.json"))
	for entry in data.entries:
		registry[entry.id] = entry
	var level := get_parent()
	get_window().title = "Urban Corridor FPS / TASK-008 Sample v003"
	# The old fixture's visible 3m boundary boxes would cover the shop fronts.
	# Reusable facades provide the real collision on both sides instead.
	for name in ["Boundary-1", "Boundary1"]:
		var boundary := level.get_node("WorldGeo/" + name)
		boundary.collision_layer = 0
		boundary.collision_mask = 0
		boundary.hide()
	level.get_node("WorldGeo/End-28/Mesh").hide()
	for z in [2, 10, 18]:
		_apply_slot(level.get_node("Facade" + str(z) + "/VisualSlot"), "sample_residential_A")
	for z in [-2, -10, -18]:
		var shop := SHOP.instantiate()
		shop.name = "Shop" + str(-z)
		shop.position = Vector3(-6, 0, z)
		shop.rotation.y = PI / 2
		add_child(shop)
		_apply_slot(shop.get_node("VisualSlot"), "sample_shopfront_A")
		var sign := Label3D.new()
		sign.text = ["GENERAL GOODS", "REPAIRS", "OLD CITY MARKET"][[-2, -10, -18].find(z)]
		sign.position = Vector3(-5.77, 3.45, z)
		sign.rotation.y = PI / 2
		sign.font_size = 42
		sign.pixel_size = .006
		sign.modulate = Color(.78, .70, .51)
		add_child(sign)
		var board := MeshInstance3D.new()
		var board_mesh := BoxMesh.new()
		board_mesh.size = Vector3(.05, .42, 3.3)
		var board_material := StandardMaterial3D.new()
		board_material.albedo_color = Color(.10, .14, .15)
		board_mesh.material = board_material
		board.mesh = board_mesh
		board.position = Vector3(-5.9, 3.45, z)
		add_child(board)
	_apply_slot(level.get_node("Cover/PlayerCover/VisualSlot"), "sample_barrier_A")
	var crates := CRATES.instantiate()
	crates.position = Vector3(3.8, 0, -5.5)
	add_child(crates)
	_apply_slot(crates.get_node("VisualSlot"), "sample_crates_A")
	level.get_node("WorldGeo/Ground/Mesh").hide()
	_add_model("sample_road_A")
	_add_model("sample_street_details_A")
	var physics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_sample_physics.json"))
	var debris_body := StaticBody3D.new()
	debris_body.name = "LargeDebrisCollision"
	debris_body.collision_layer = 1
	debris_body.set_meta("surface_type", "concrete")
	add_child(debris_body)
	for piece in physics.debris_boxes:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(piece.size[0], piece.size[1], piece.size[2])
		collider.shape = shape
		collider.position = Vector3(piece.position[0], piece.position[1], piece.position[2])
		debris_body.add_child(collider)
	# Actual LP uses two convex hulls derived from its body/cabin; keep fallback boxes.
	var vehicle_entry: Dictionary = registry.get("sample_vehicle_final", {})
	var model: Node3D
	if vehicle_entry.get("status") == "ready":
		model = _add_model("sample_vehicle_final")
	var final_vehicle := model != null
	if model == null:
		model = _add_model("sample_vehicle_proxy")
	if model != null:
		model.position = Vector3(-3.35, 0, -15)
		model.rotation.y = -.15
	var vehicle := StaticBody3D.new()
	vehicle.name = "VehicleCollision"
	vehicle.collision_layer = 1
	vehicle.set_meta("surface_type", "metal")
	vehicle.position = Vector3(-3.35, 0, -15)
	vehicle.rotation.y = -.15
	add_child(vehicle)
	if final_vehicle:
		for hull in vehicle_entry.collision_hulls:
			var collider := CollisionShape3D.new()
			var convex := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for point in hull:
				points.append(Vector3(point[0], point[1], point[2]))
			convex.points = points
			collider.shape = convex
			vehicle.add_child(collider)
	else:
		for offset in [Vector3(0, .5, 0), Vector3(0, 1.02, .1)]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.8, .5, 4.2) if offset.y < .6 else Vector3(1.5, .55, 2.2)
			shape.shape = box
			shape.position = offset
			vehicle.add_child(shape)
	# Keep the original enemy wall collision; give its visible mesh the concrete PBR.
	var barrier = load(registry.sample_barrier_A.proposed_path).instantiate()
	var concrete := _find_material(barrier, "Pitted_concrete")
	if concrete != null:
		level.get_node("Cover/EnemyWall/Mesh").material_override = concrete
	barrier.free()
	level.get_node("GreyboxSign").hide()
	level.get_node("TriggerLine").hide()
	level.get_node("FinishSign").hide()
	level.get_node("Enemies/AGuard/Label3D").hide()
	level.get_node("GameFlow").level_title = "旧城环境样板 / 24m"
	var sun: DirectionalLight3D = level.get_node("Sun")
	sun.rotation_degrees = Vector3(-32, -45, 0)
	sun.light_color = Color(1.0, .85, .67)
	sun.light_energy = 1.7
	sun.directional_shadow_max_distance = 65
	var environment := level.get_node("WorldEnvironment").environment.duplicate() as Environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(.22, .36, .52)
	sky_material.sky_horizon_color = Color(.47, .55, .61)
	sky_material.ground_horizon_color = Color(.40, .43, .43)
	sky_material.sky_curve = .25
	sky_material.ground_bottom_color = Color(.22, .19, .15)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.55, .63, .73)
	environment.ambient_light_energy = .6
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .95
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.04
	environment.adjustment_saturation = .88
	environment.glow_enabled = true
	environment.glow_intensity = .25
	environment.glow_bloom = .03
	environment.volumetric_fog_density = .008
	environment.volumetric_fog_length = 64
	environment.volumetric_fog_albedo = Color(.64, .61, .55)
	environment.volumetric_fog_anisotropy = .35
	environment.fog_enabled = true
	environment.fog_light_color = Color(.60, .65, .67)
	environment.fog_density = .0015
	level.get_node("WorldEnvironment").environment = environment
	_make_backdrop()
	var atmosphere := preload("res://scripts/art/sample_atmosphere.gd").new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	print("Street sample models=", loaded_assets, " errors=", asset_errors, " vehicle_final=", final_vehicle)

func _apply_slot(slot: Node3D, id: String) -> void:
	if slot.apply_entry(registry.get(id, {})):
		if not loaded_assets.has(id):
			loaded_assets.append(id)
	else:
		asset_errors.append("Missing visual: " + id)

func _add_model(id: String) -> Node3D:
	var entry: Dictionary = registry.get(id, {})
	var path: String = entry.get("proposed_path", "")
	if entry.get("status") != "ready" or not ResourceLoader.exists(path):
		asset_errors.append("Missing model: " + id)
		return null
	var instance = load(path).instantiate()
	var validator := Slot.new()
	var valid: bool = instance is Node3D and validator._visual_only(instance)
	validator.free()
	if not valid:
		instance.free()
		asset_errors.append("Invalid model: " + id)
		return null
	add_child(instance)
	loaded_assets.append(id)
	return instance

func _find_material(node: Node, prefix: String) -> Material:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var material = node.mesh.surface_get_material(i)
			if material != null and material.resource_name.begins_with(prefix):
				return material
	for child in node.get_children():
		var found := _find_material(child, prefix)
		if found != null:
			return found
	return null

func _make_backdrop() -> void:
	# Unreachable low-detail skyline beyond the level's solid end boundary.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.42, .39, .32)
	mat.roughness = .95
	for i in range(9):
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(5, 7 + (i % 3) * 2, 4)
		box.material = mat
		mesh.mesh = box
		mesh.position = Vector3((i - 4) * 5.5, box.size.y / 2, -43 - (i % 2) * 8)
		add_child(mesh)
	var gate_mat := StandardMaterial3D.new()
	gate_mat.albedo_color = Color(.52, .46, .35)
	for x in [-3.6, 3.6]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.8, 5, 2)
		box.material = gate_mat
		pillar.mesh = box
		pillar.position = Vector3(x, 2.5, -35)
		add_child(pillar)
	var arch := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(gate_mat)
	gate_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(20):
		var a := PI * i / 20.0
		var b := PI * (i + 1) / 20.0
		var corners: Array[Vector3] = []
		for depth in [-.8, .8]:
			for point in [Vector2(cos(a), sin(a)) * 2.8, Vector2(cos(a), sin(a)) * 4.3, Vector2(cos(b), sin(b)) * 4.3, Vector2(cos(b), sin(b)) * 2.8]:
				corners.append(Vector3(point.x, point.y, depth))
		for face in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [3, 2, 6, 7]]:
			for index in [face[0], face[1], face[2], face[0], face[2], face[3]]:
				surface.add_vertex(corners[index])
	surface.generate_normals()
	arch.mesh = surface.commit()
	arch.position = Vector3(0, 5, -35)
	add_child(arch)
