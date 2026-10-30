extends Node3D
## Lazy, visual-only debug geometry; never enables/disables real collision.

var overlay: Node3D
var label: Label
var canvas: CanvasLayer

func _ready() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(20, 96)
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	canvas.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_level"):
		set_debug(not canvas.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_decoration"):
		var decor := get_node("../LevelRuntime/Decorations") as Node3D
		decor.visible = not decor.visible
		_update_text()
		get_viewport().set_input_as_handled()

func set_debug(enabled: bool) -> void:
	if overlay == null and enabled:
		overlay = Node3D.new()
		overlay.name = "CollisionAndMarkers"
		add_child(overlay)
		_build(get_parent())
	if overlay != null:
		overlay.visible = enabled
	canvas.visible = enabled
	_update_text()

func _update_text() -> void:
	var runtime = get_node("../LevelRuntime")
	label.text = "F3 碰撞/标记调试 | F4 装饰开关\nseed: %d | 装饰: %d / 24 | 显示: %s\n缺失 GLB: %d | 配置错误: %d\n青色=实体盒碰撞  橙色=触发区  绿色=固定 Marker" % [runtime.active_seed, runtime.decoration_manifest.size(), runtime.decorations.visible, runtime.missing_assets.size(), runtime.validation_errors.size()]

func _build(node: Node) -> void:
	if node == self:
		return
	if node is CollisionShape3D and node.shape is BoxShape3D:
		var immediate := ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.albedo_color = Color.ORANGE if node.get_parent() is Area3D else Color.CYAN
		immediate.surface_begin(Mesh.PRIMITIVE_LINES, mat)
		var half: Vector3 = node.shape.size / 2.0
		for axis in range(3):
			for a in [-1, 1]:
				for b in [-1, 1]:
					var start := Vector3.ZERO
					start[axis] = -half[axis]
					start[(axis + 1) % 3] = a * half[(axis + 1) % 3]
					start[(axis + 2) % 3] = b * half[(axis + 2) % 3]
					var finish := start
					finish[axis] = half[axis]
					immediate.surface_add_vertex(node.global_transform * start)
					immediate.surface_add_vertex(node.global_transform * finish)
		immediate.surface_end()
		var mesh := MeshInstance3D.new()
		mesh.mesh = immediate
		overlay.add_child(mesh)
	elif node is Marker3D and (str(node.get_parent().name) in ["SpawnMarkers", "CoverMarkers", "PeekMarkers", "Route"] or str(node.name) in ["PlayerSpawn", "FinishMarker"]):
		var marker_label := Label3D.new()
		marker_label.text = str(node.name)
		marker_label.position = node.global_position + Vector3.UP * .3
		marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker_label.no_depth_test = true
		marker_label.modulate = Color.GREEN
		marker_label.font_size = 28
		marker_label.fixed_size = true
		marker_label.pixel_size = 0.001
		marker_label.visibility_range_end = 30.0
		overlay.add_child(marker_label)
	for child in node.get_children():
		_build(child)
