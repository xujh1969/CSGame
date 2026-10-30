extends Node
## Godot 4.x — FPS ViewModel non-destructive diagnostic snapshot.
## Attach to a Node under your isolated test scene and assign paths in the Inspector.
## F9: save JSON report + viewport PNG to user://fps_rig_debug/.
## IMPORTANT: this does not mutate bones, IK, animations, or weapon transforms.

@export_group("Scene References")
@export var skeleton_path: NodePath
@export var viewmodel_root_path: NodePath
@export var weapon_root_path: NodePath
@export var camera_path: NodePath
@export var animation_player_path: NodePath
@export var animation_tree_path: NodePath

@export_group("Contact Markers (both sides are world-aligned when correctly gripped)")
## Palm markers should be children of BoneAttachment3D nodes attached to hand bones.
@export var right_palm_marker_path: NodePath
@export var right_grip_socket_path: NodePath
@export var left_palm_marker_path: NodePath
@export var left_grip_socket_path: NodePath
@export var sight_marker_path: NodePath

@export_group("Expected Skeleton / Tolerance")
@export var required_bones: PackedStringArray = PackedStringArray(["hand.L", "hand.R"])
@export var max_grip_error_m: float = 0.04
@export var max_grip_angle_deg: float = 25.0
## Set this false for the left hand during the detached phase of Reload.
@export var expect_left_hand_gripping: bool = true
@export var expect_right_hand_gripping: bool = true

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
        capture_report("manual")
        get_viewport().set_input_as_handled()

func _resolve(path: NodePath) -> Node:
    if path.is_empty():
        return null
    return get_node_or_null(path)

func _v3(value: Vector3) -> Array:
    return [value.x, value.y, value.z]

func _basis_info(node: Node3D) -> Dictionary:
    var determinant := node.global_transform.basis.determinant()
    return {
        "path": str(node.get_path()),
        "origin_world": _v3(node.global_position),
        "basis_determinant": determinant,
        "possibly_mirrored": determinant < 0.0,
        "scale": _v3(node.global_transform.basis.get_scale())
    }

func _grip_info(palm: Node3D, grip: Node3D, should_grip: bool, errors: Array, label: String) -> Dictionary:
    if palm == null or grip == null:
        return {"configured": false, "expected_contact": should_grip}
    var delta := palm.global_position.distance_to(grip.global_position)
    var q_palm := palm.global_transform.basis.orthonormalized().get_rotation_quaternion()
    var q_grip := grip.global_transform.basis.orthonormalized().get_rotation_quaternion()
    var angle_deg := rad_to_deg(q_palm.angle_to(q_grip))
    if should_grip and delta > max_grip_error_m:
        errors.append("%s contact distance %.3fm > %.3fm" % [label, delta, max_grip_error_m])
    if should_grip and angle_deg > max_grip_angle_deg:
        errors.append("%s grip angle %.1fdeg > %.1fdeg" % [label, angle_deg, max_grip_angle_deg])
    return {
        "configured": true,
        "expected_contact": should_grip,
        "distance_m": delta,
        "relative_orientation_deg": angle_deg,
        "palm_world": _v3(palm.global_position),
        "socket_world": _v3(grip.global_position)
    }

func make_report(stage: String = "manual") -> Dictionary:
    var issues: Array = []
    var warnings: Array = []
    var report: Dictionary = {
        "stage": stage,
        "engine": Engine.get_version_info().get("string", "unknown"),
        "rig_bones": [],
        "issues": issues,
        "warnings": warnings
    }

    var skeleton := _resolve(skeleton_path) as Skeleton3D
    var vm := _resolve(viewmodel_root_path) as Node3D
    var weapon := _resolve(weapon_root_path) as Node3D
    var cam := _resolve(camera_path) as Camera3D
    var player := _resolve(animation_player_path) as AnimationPlayer
    var tree := _resolve(animation_tree_path) as AnimationTree

    if skeleton == null:
        issues.append("Skeleton3D is missing; set skeleton_path")
    else:
        report["skeleton_transform"] = _basis_info(skeleton)
        report["bone_count"] = skeleton.get_bone_count()
        for i in range(skeleton.get_bone_count()):
            var parent_id := skeleton.get_bone_parent(i)
            var bone_entry: Dictionary = {
                "id": i,
                "name": skeleton.get_bone_name(i),
                "parent": skeleton.get_bone_name(parent_id) if parent_id >= 0 else "",
                "pose_world": _v3((skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin),
                "rest_world": _v3((skeleton.global_transform * skeleton.get_bone_global_rest(i)).origin)
            }
            report["rig_bones"].append(bone_entry)
        for required in required_bones:
            if skeleton.find_bone(required) < 0:
                issues.append("Required bone not found: %s (verify import naming)" % required)

    if vm != null:
        report["viewmodel_root"] = _basis_info(vm)
        if vm.global_transform.basis.determinant() < 0.0:
            warnings.append("ViewModel root has negative determinant (mirroring risk)")
    if weapon != null:
        report["weapon_root"] = _basis_info(weapon)
        if weapon.global_transform.basis.determinant() < 0.0:
            warnings.append("Weapon root has negative determinant (mirroring risk)")

    report["right_grip"] = _grip_info(
        _resolve(right_palm_marker_path) as Node3D,
        _resolve(right_grip_socket_path) as Node3D,
        expect_right_hand_gripping, issues, "Right hand")
    report["left_grip"] = _grip_info(
        _resolve(left_palm_marker_path) as Node3D,
        _resolve(left_grip_socket_path) as Node3D,
        expect_left_hand_gripping, issues, "Left hand")

    if player != null:
        var anims: Array = []
        for anim_name in player.get_animation_list():
            var anim := player.get_animation(anim_name)
            var paths: Array = []
            for track_id in range(anim.get_track_count()):
                paths.append(str(anim.track_get_path(track_id)))
            anims.append({
                "name": str(anim_name),
                "length_s": anim.length,
                "track_count": anim.get_track_count(),
                "tracks": paths
            })
        report["animations"] = anims
        report["player_assigned_animation"] = str(player.assigned_animation)
    else:
        warnings.append("AnimationPlayer path not assigned")
    if tree != null:
        report["animation_tree_active"] = tree.active
        if not tree.active:
            warnings.append("AnimationTree is present but inactive")

    var sight := _resolve(sight_marker_path) as Node3D
    if cam != null and sight != null:
        var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
        if viewport_size.x > 0.0 and viewport_size.y > 0.0:
            if cam.is_position_behind(sight.global_position):
                warnings.append("SightMarker is behind Camera3D")
                report["sight_screen"] = {"behind_camera": true}
            else:
                var px := cam.unproject_position(sight.global_position)
                report["sight_screen"] = {
                    "behind_camera": false,
                    "normalized_xy": [px.x / viewport_size.x, px.y / viewport_size.y],
                    "pixels": [px.x, px.y],
                    "viewport_size": [viewport_size.x, viewport_size.y]
                }
    else:
        warnings.append("Camera/SightMarker not configured; no screen-space evaluation")

    report["issue_count"] = issues.size()
    return report

func capture_report(stage: String = "manual") -> void:
    var report := make_report(stage)
    var folder := "user://fps_rig_debug/"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var stamp := str(Time.get_ticks_msec())
    var json_path := folder + "rig_" + stamp + ".json"
    var writer := FileAccess.open(json_path, FileAccess.WRITE)
    if writer != null:
        writer.store_string(JSON.stringify(report, "  "))
        writer.close()
        print("FPS rig diagnostics JSON: ", ProjectSettings.globalize_path(json_path))
    else:
        push_error("Cannot write FPS rig diagnostics JSON")
    for issue in report["issues"]:
        push_warning("FPS RIG: " + str(issue))
    # Capture after the frame has been rendered, so this is the actual displayed state.
    await RenderingServer.frame_post_draw
    var png_path := folder + "rig_" + stamp + ".png"
    var cam := _resolve(camera_path) as Camera3D
    var target_viewport: Viewport = cam.get_viewport() if cam != null else get_viewport()
    var error_code := target_viewport.get_texture().get_image().save_png(png_path)
    if error_code == OK:
        print("FPS rig screenshot: ", ProjectSettings.globalize_path(png_path))
    else:
        push_warning("FPS rig screenshot failed; check rendering mode")
