extends SceneTree
func _initialize()->void:
 _run.call_deferred()
func _run()->void:
 var scene=load("res://scenes/levels/art/StreetSample.tscn").instantiate();root.add_child(scene)
 var nav:=NavigationMesh.new();nav.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS;nav.geometry_collision_mask=1|2
 nav.cell_size=.15;nav.cell_height=.05;nav.agent_radius=.3;nav.agent_height=1.8;nav.agent_max_climb=.2
 nav.filter_baking_aabb=AABB(Vector3(-5.5,-.3,-24),Vector3(11,4,28))
 var source:=NavigationMeshSourceGeometryData3D.new()
 NavigationServer3D.parse_source_geometry_data(nav,source,scene);NavigationServer3D.bake_from_source_geometry_data(nav,source)
 var error=ResourceSaver.save(nav,"res://scenes/levels/art/EnemySampleNavigation.tres")
 print("ENEMY_NAV polygons=",nav.get_polygon_count()," save_error=",error)
 quit(0 if error==OK and nav.get_polygon_count()>0 else 1)
