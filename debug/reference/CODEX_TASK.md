# Codex task: Prevent recurring FPS hands / reload defects (Godot 4.x)

The project is developed in **Godot**, with Blender 5.2.3 as the DCC tool. Do **not** propose Three.js code. Work on a separate branch, and inspect the existing project scene tree before making changes.

1. Inventory real imported GLB scene trees: Skeleton3D bone names + parent indices, mesh-to-skeleton bindings, AnimationPlayer clips + track paths, AnimationTree state transitions, BoneAttachment3D nodes, viewmodel camera and weapon root transforms.
2. Check *anatomical* left/right hands: isolate each hand with fingers straight; verify thumb side, glove geometry, corresponding skeleton and weights. Do not infer only from `hand.L` and `hand.R` names. Flag negative determinant / mirrored nodes.
3. Set up `res://debug/fps_rig_test.tscn` and attach FPSRigDiagnostics.gd. Use calibrated palm markers on BoneAttachment3D and gun grip sockets. Wire all Inspector paths.
4. Capture reproducible evidence in Idle, ADS, Fire, Reload-start, old-mag-grasp, old-mag-remove, new-mag-insert, Reload-end: screenshot + JSON bone/marker data. During reloading, disable the left foregrip contact expectation when that hand must move to the magazine and separately check magazine hand attachment.
5. Diagnose **cause** before changing offsets: wrong mesh side, wrong rest/pose, wrong bone track, wrong parent transform, wrong socket orientation, bad animation blending, or keyframe timing. Provide a root-cause report with affected scene/node and evidence.
6. Fix only one cause at a time. For hip-fire/ADS, create separately reviewed poses; do not choose arbitrary absolute offsets without approving camera framing. For reload, define explicit attachment phases and avoid simultaneous weapon-hand parenting cycles.
7. Regression check every state before commit. Record a baseline screenshot from the approved camera, test clip/position and FOV. Repeat with fixed settings. Compare all grip distances and projected sight position, and visually inspect thumb side and cloth intersections. Declare an untested step untested.
8. Deliver: changed files, precise issue causes, screenshots, JSON reports, before/after metrics, and outstanding limitations. Avoid modifying unrelated combat/ammo logic.
