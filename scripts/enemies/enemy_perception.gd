extends Node3D

@export var view_distance := 25.0
@export var field_of_view := 110.0
var target: CharacterBody3D

func target_point() -> Vector3:
	return target.get_node("Camera3D").global_position

func can_see_target() -> bool:
	if not is_instance_valid(target):
		return false
	var offset := target_point() - global_position
	if offset.length() > view_distance:
		return false
	var horizontal := Vector3(offset.x, 0, offset.z)
	var forward: Vector3 = -get_parent().global_basis.z
	if horizontal.length_squared() > 0.001 and forward.angle_to(horizontal) > deg_to_rad(field_of_view * 0.5):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, target_point(), 1 | 2 | 4, [get_parent().get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target
