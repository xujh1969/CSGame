extends SceneTree

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var scene: Node3D = load("res://scenes/levels/VerticalSlice01.tscn").instantiate()
	root.add_child(scene)
	var navigation := NavigationMesh.new()
	navigation.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation.geometry_collision_mask = 1 | 2
	navigation.cell_size = 0.1
	navigation.cell_height = 0.05
	navigation.agent_radius = 0.3
	navigation.agent_height = 1.8
	navigation.agent_max_climb = 0.2
	navigation.filter_baking_aabb = AABB(Vector3(1.8, -0.2, -28.5), Vector3(4.4, 4.0, 5.5))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation, source, scene)
	NavigationServer3D.bake_from_source_geometry_data(navigation, source)
	var error := ResourceSaver.save(navigation, "res://scenes/levels/CornerNavigation.tres")
	print("Corner navigation polygons: ", navigation.get_polygon_count(), "; save error: ", error)
	scene.queue_free()
	await process_frame
	quit(0 if error == OK and navigation.get_polygon_count() > 0 else 1)
