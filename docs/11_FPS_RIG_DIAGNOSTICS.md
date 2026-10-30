# TASK-009 FPS Rig diagnostic contract

2026-10-30. Godot 4.7.2 / GDScript / Blender 5.2.3. User-supplied CODEX_TASK.md, FPSRigDiagnostics.gd and setup guide are preserved under debug/reference/. No Three.js code is used.

## Isolation and status
`debug/fps_rig_test.tscn` is the isolated fixture. The default campaign scene and combat/ammo scripts are unchanged. `main` is a README/config bootstrap only; `task-009-rig-diagnostics` is a work-in-progress branch. No hand/reload visual acceptance or merge to the main game is claimed.

Modes: default = static v006 (animations intentionally absent); `--legacy` = unaccepted dynamic v005; `--candidate` = palmar-marker-solved static v008. Candidate Fire/Reload snapshots deliberately preserve StaticBind: these validate instrumentation and original ammo authority, not restored animation quality. Static pose approval is required before rebuilding Reload.

## What is measured
- Actual scene hierarchy, Skeleton3D rest/pose, skin bindings, animation clips/typed tracks/key counts, AnimationTree presence/absence, and BoneAttachment3D override state.
- The two meshes have 61 skin bindings each. The normal dynamic fixture uses a manually driven AnimationPlayer, not AnimationTree. The static fixture has no AnimationPlayer. Do not add a second controller to drive the same bones.
- Anatomical sides are independently inspected with animation off and open fingers. Original glove textures are retained: black palmar side; yellow/green cloth and rubber dorsal side. Red/blue sleeves identify right/left inspection copies. Bone names alone do not establish handedness; no negative scaling was found.
- Palm contact markers are separate from the old RightGripSocket wrist reference. They are children of read-only BoneAttachment3D nodes with override_pose=false. Their local positions/orientation are derived from actual mesh/skin/texture data; weapon sockets remain independent physical surface targets.
- Right contact remains expected. Left foregrip contact is disabled while reaching/removing/inserting a magazine; a separate magazine contact/parent check is enabled during grasp.
- Eye camera local/world transforms, FOV, sight projection, eye-to-stock distances and clipped stock vertex bounds are recorded. Vertex bounds are not exact pixel coverage. The eye remains at Player/Camera3D, standing local Y=1.7m; do not move the eye to repair a viewmodel.

## Snapshot protocol
F9 saves JSON and PNG to user://fps_rig_debug/. JSON and pixels are sampled after frame_post_draw, in the same displayed frame. Headless mode explicitly omits PNG. Automated snapshots cover Idle, ADS, Fire, Reload-start, old-mag-grasp, old-mag-remove, new-mag-insert, Reload-end at 1280x720 and fixed 60fps simulation. This is not a performance benchmark.

```
godot --headless --editor --path . --quit
godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd
godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd -- --legacy
godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd -- --candidate
```

Outputs: logs/fps_rig/<fixture>/summary.json plus timestamped state JSON/PNG. All current images are unapproved evidence, not golden baselines. Do not copy them into an approved reference folder automatically.

## Diagnostic self-tests
The tests verify bindings, tracks, real BoneAttachment3D palm markers, unchanged bone/root/controller state before/after make_report, detection of an injected 20cm DEBUG-marker error, and detection of a missing required marker. No imported bone/skin is modified by diagnostics. Framework test success is separate from pose issue counts; known bad poses are reported, not hidden.

The provided script was extended because a missing required marker originally returned configured=false without an issue, and JSON was sampled before the screenshot frame. The palm texture reader was independently checked against the original texture: CPU Image rows need V inversion for these imported 3D UVs. Provisional pre-calibration orientation reports must not be treated as final evidence.

## Build and motion guards
Use Blender --python-exit-code 1; plain background Blender can return 0 after an AssertionError. The attempted v006 stronger-finger pose hit 30.29mm edge-length increase and was not exported. The v008 palmar candidate uses Hand_target = Socket_target * inverse(PalmMarker_local), with imported joint-frame conversion checked against the actual skin bind. Its prebind edge-length increase was 12.20mm; original weights and raw model are preserved. This is a diagnostic candidate, not final animation acceptance.

Known remaining limits: local palette/marker definitions require visual review, palm/socket tolerances are initial 4cm/25deg, finger tips and cloth intersection need visual checks, no full-body shadow, no target RTX2060 validation, Reload restoration remains gated by static-pose review.

## 2026-10-30 eye / stock regression
The camera remains at Player/Camera3D, standing Y=1.70m. Legacy viewmodel root was only 6cm below the eye. The isolated static fixture uses Hip (0.16,-0.23,-0.28)m and ADS (0,-0.135,-0.33)m relative to the camera. Hip captures show the stock no longer covering the right half of the screen. This is framing progress, not hand acceptance. ADS still shows unnatural left fingers near the optic.

v008 uses anatomical mid-palm selection (25¨C80 percent of wrist-to-MCP length, texture-verified black hemisphere), replacing the wrist-biased Hand-weight-only selection. It solves the hand bind frame to the independent physical weapon socket; the eye and weapon sockets are not moved to force the marker test. Zero contact issues only confirms initial palm tolerances, not fingertip wrapping or absence of penetration.

Current evidence: logs/fps_rig/candidate_v008/summary.json; clean fixed views logs/TASK-009-v008-hip.png and logs/TASK-009-v008-ads.png. Independent original-model hands: logs/TASK-009-v006-right-hand.png and logs/TASK-009-v006-left-hand.png. All are unapproved. Run run_rig_candidate.bat; right mouse ADS, F9 capture, Esc pause. Reload animation is deliberately frozen pending static review. The normal campaign is not switched to this candidate.
