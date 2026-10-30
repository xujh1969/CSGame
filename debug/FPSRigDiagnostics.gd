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

@export_group("Capture / State")
@export var output_directory := "user://fps_rig_debug/"
@export var expect_ads_sight_centered := false
@export var max_sight_error_normalized := 0.01
@export var static_bind_fixture := false
@export var magazine_socket_path: NodePath
@export var expect_left_hand_on_magazine := false
@export var magazine_expected_parent_path: NodePath
@export var magazine_path: NodePath
@export var stock_marker_path: NodePath
@export var shoulder_marker_path: NodePath
@export var muzzle_marker_path: NodePath

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
        "scale": _v3(node.global_transform.basis.get_scale()),
        "local_origin": _v3(node.position),
        "basis_columns": [_v3(node.global_basis.x), _v3(node.global_basis.y), _v3(node.global_basis.z)],
        "rotation_world_xyzw": _q4(node.global_basis.orthonormalized().get_rotation_quaternion())
    }

func _grip_info(palm: Node3D, grip: Node3D, should_grip: bool, errors: Array, label: String) -> Dictionary:
    if palm == null or grip == null:
        if should_grip:
            errors.append("%s expected contact has missing palm marker or socket" % label)
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
        "socket_world": _v3(grip.global_position),
        "palm_transform": _basis_info(palm),
        "socket_transform": _basis_info(grip),
        "surface_calibration": palm.get_meta("surface_calibration", {})
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
                "rest_world": _v3((skeleton.global_transform * skeleton.get_bone_global_rest(i)).origin),
                "rest_determinant": skeleton.get_bone_global_rest(i).basis.determinant(),
                "pose_determinant": skeleton.get_bone_global_pose(i).basis.determinant(),
                "pose_basis": [_v3(skeleton.get_bone_global_pose(i).basis.x), _v3(skeleton.get_bone_global_pose(i).basis.y), _v3(skeleton.get_bone_global_pose(i).basis.z)]
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
        report["player_time_s"] = player.current_animation_position
        report["player_playing"] = player.is_playing()
    else:
        warnings.append("AnimationPlayer intentionally absent in static bind fixture" if static_bind_fixture else "AnimationPlayer path not assigned")
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

    if expect_ads_sight_centered and report.has("sight_screen") and not report.sight_screen.get("behind_camera", true):
        var xy: Array = report.sight_screen.normalized_xy
        if Vector2(xy[0], xy[1]).distance_to(Vector2(.5, .5)) > max_sight_error_normalized:
            issues.append("ADS sight is outside the configured reticle tolerance")
    report["magazine_grip"] = _grip_info(_resolve(left_palm_marker_path) as Node3D, _resolve(magazine_socket_path) as Node3D, expect_left_hand_on_magazine, issues, "Magazine hand")
    var magazine := _resolve(magazine_path)
    var expected_parent := _resolve(magazine_expected_parent_path)
    if magazine != null:
        report["magazine_parent"] = str(magazine.get_parent().get_path())
        if expected_parent != null and magazine.get_parent() != expected_parent:
            issues.append("Magazine is not parented to the expected phase owner")
    if cam != null:
        report["camera"] = _basis_info(cam)
        report.camera["fov"] = cam.fov
        report.camera["near"] = cam.near
        report.camera["far"] = cam.far
        report.camera["viewport"] = [cam.get_viewport().size.x, cam.get_viewport().size.y]
    report["view_framing"] = _view_framing(weapon, cam, issues)
    report["context"] = get_meta("context", {"approved_baseline": false})
    report["inventory"] = _inventory(vm, issues, warnings)
    report["issue_count"] = issues.size()
    return report

func _q4(q: Quaternion) -> Array:
    return [q.x, q.y, q.z, q.w]

func _inventory(root: Node, issues: Array, warnings: Array) -> Dictionary:
    var result := {"nodes": [], "skinned_meshes": [], "animation_players": [], "animation_trees": [], "bone_attachments": []}
    if root == null:
        issues.append("ViewModel root missing; inventory cannot be scoped")
        return result
    var nodes := root.find_children("*", "Node", true, false)
    nodes.push_front(root)
    for node in nodes:
        var row := {"path": str(node.get_path()), "class": node.get_class(), "parent": str(node.get_parent().get_path())}
        if node is Node3D:
            row["transform"] = _basis_info(node)
            if row.transform.possibly_mirrored:
                warnings.append("Negative determinant: " + str(node.get_path()))
        result.nodes.append(row)
        if node is MeshInstance3D and node.skin != null:
            var mesh_skeleton := node.get_node_or_null(node.skeleton) as Skeleton3D
            var binds := []
            for i in node.skin.get_bind_count():
                var name: StringName = node.skin.get_bind_name(i)
                var index: int = node.skin.get_bind_bone(i)
                var valid: bool = mesh_skeleton != null and ((name != &"" and mesh_skeleton.find_bone(name) >= 0) or (name == &"" and index >= 0 and index < mesh_skeleton.get_bone_count()))
                binds.append({"name": str(name), "bone_index": index, "resolved": valid, "determinant": node.skin.get_bind_pose(i).basis.determinant()})
                if not valid:
                    issues.append("Unresolved skin bind on " + str(node.get_path()) + ": " + str(name))
            result.skinned_meshes.append({"path": str(node.get_path()), "skeleton_path": str(node.skeleton), "binds": binds, "surface_count": node.mesh.get_surface_count()})
        if node is AnimationPlayer:
            var clips := []
            var animation_root := node.get_node_or_null(node.root_node)
            for name in node.get_animation_list():
                var animation: Animation = node.get_animation(name)
                var tracks := []
                var seen := {}
                for i in animation.get_track_count():
                    var path: NodePath = animation.track_get_path(i)
                    var target: Node = animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) if animation_root != null else null
                    var valid := target != null
                    if target is Skeleton3D and path.get_subname_count() > 0:
                        valid = target.find_bone(path.get_subname(0)) >= 0
                    var key := str(path) + ":" + str(animation.track_get_type(i))
                    if seen.has(key):
                        issues.append("Duplicate animation track: " + key)
                    seen[key] = true
                    if not valid:
                        issues.append("Unresolved animation track: " + str(path))
                    tracks.append({"path": str(path), "type": animation.track_get_type(i), "keys": animation.track_get_key_count(i), "enabled": animation.track_is_enabled(i), "resolved": valid})
                clips.append({"name": name, "length": animation.length, "tracks": tracks})
            result.animation_players.append({"path": str(node.get_path()), "root_node": str(node.root_node), "clips": clips})
        if node is AnimationTree:
            result.animation_trees.append({"path": str(node.get_path()), "active": node.active, "tree_root_type": node.tree_root.get_class() if node.tree_root != null else "none"})
        if node is BoneAttachment3D:
            result.bone_attachments.append({"path": str(node.get_path()), "bone_name": node.bone_name, "override_pose": node.override_pose})
    if result.animation_trees.is_empty():
        warnings.append("AnimationTree absent; no state machine transitions to inspect")
    return result

func capture_report(stage: String = "manual") -> Dictionary:
    # JSON and pixels are sampled together after final pose/modifier and attachment updates.
    var gui := DisplayServer.get_name() != "headless"
    if gui:
        await RenderingServer.frame_post_draw
    var report := make_report(stage)
    report["capture_frame"] = Engine.get_process_frames()
    report["screenshot_status"] = "captured" if gui else "unavailable_headless"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
    var prefix := output_directory.path_join(stage.validate_filename() + "_" + str(Time.get_ticks_msec()))
    var png_path := prefix + ".png"
    if gui:
        var cam := _resolve(camera_path) as Camera3D
        var viewport: Viewport = cam.get_viewport() if cam != null else get_viewport()
        var status := viewport.get_texture().get_image().save_png(png_path)
        if status != OK:
            report["screenshot_status"] = "failed: " + str(status)
    var json_path := prefix + ".json"
    var writer := FileAccess.open(json_path, FileAccess.WRITE)
    if writer == null:
        push_error("Cannot write FPS rig diagnostics JSON: " + json_path)
        return {"report": report, "write_error": FileAccess.get_open_error()}
    writer.store_string(JSON.stringify(report, "  "))
    writer.close()
    print("FPS_RIG_CAPTURE ", stage, " issues=", report.issue_count, " JSON=", ProjectSettings.globalize_path(json_path))
    return {"report": report, "json": json_path, "png": png_path if gui else ""}

func _view_framing(weapon: Node3D, camera: Camera3D, issues: Array) -> Dictionary:
    if weapon == null or camera == null:
        return {"configured": false}
    var result := {"configured": true, "camera_parent": str(camera.get_parent().get_path()), "camera_local_eye": _v3(camera.position), "eye_in_weapon": _v3(weapon.to_local(camera.global_position)), "metric_note": "stock bounds are clipped vertex bounds, not exact rendered pixel coverage"}
    if weapon.is_ancestor_of(camera):
        issues.append("Eye camera is parented under the weapon")
    var stock := _resolve(stock_marker_path) as Node3D
    var shoulder := _resolve(shoulder_marker_path) as Node3D
    if stock != null:
        result["eye_to_buttstock_m"] = camera.global_position.distance_to(stock.global_position)
        result["buttstock_world"] = _v3(stock.global_position)
    if stock != null and shoulder != null:
        result["stock_to_design_shoulder_m"] = stock.global_position.distance_to(shoulder.global_position)
        result["shoulder_reference_note"] = "design marker, no full-body avatar has been accepted"
    var muzzle := _resolve(muzzle_marker_path) as Node3D
    if muzzle != null:
        result["muzzle_in_camera"] = _v3(camera.to_local(muzzle.global_position))
    var nearest := INF
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    var visible := 0
    var screen_size := camera.get_viewport().get_visible_rect().size
    for mesh in weapon.find_children("*", "MeshInstance3D", true, false):
        if mesh.mesh == null:
            continue
        for surface in mesh.mesh.get_surface_count():
            var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
            for vertex in vertices:
                var world: Vector3 = mesh.to_global(vertex)
                if weapon.to_local(world).z <= .20:
                    continue
                nearest = minf(nearest, camera.global_position.distance_to(world))
                if camera.to_local(world).z >= -camera.near:
                    continue
                var pixel := camera.unproject_position(world) / screen_size
                low = low.min(pixel)
                high = high.max(pixel)
                visible += 1
    result["nearest_stock_vertex_m"] = nearest if is_finite(nearest) else -1.0
    result["visible_stock_vertices"] = visible
    if visible > 0:
        low = low.clamp(Vector2.ZERO, Vector2.ONE)
        high = high.clamp(Vector2.ZERO, Vector2.ONE)
        result["stock_vertex_screen_bounds"] = [[low.x, low.y], [high.x, high.y]]
        result["stock_vertex_bounds_fraction"] = maxf(0, high.x-low.x) * maxf(0, high.y-low.y)
    return result
