# TASK-001 verification record

2026-10-28 用户最新复测反馈：“都正确了，可以进行下一步了”。此前报告的 Ctrl 蹲伏问题已获用户确认解决，按该反馈开始 TASK-002。

Date: 2026-10-28 (Asia/Shanghai)
Godot: 4.7.2.stable.official.ed1daf0bf
Scope: player movement, view, crouch clearance, and collision test geometry only.

## Implemented

- `scenes/player/player.tscn`: CharacterBody3D player, capsule collision (0.6 m diameter, 1.8 m standing height), Camera3D at 1.7 m / 75 degree FOV, separate input controller node.
- `scripts/player/player_controller.gd`: mouse look (0.0025 rad per relative unit), capture on start/left click, Esc release, action mapping and input forwarding.
- `scripts/player/player_motor.gd`: physics movement with walk 4.0, sprint 6.5, crouch 2.0 m/s; ~1 m jump; smooth capsule/camera crouch transition; standing overlap query; CharacterBody3D slide collision.
- `scenes/main.tscn`: instanced player plus 1.1 m low wall and 0.3 m test step with matching static box collision shapes; existing orange barrier retained.

## Checks actually run

- `& 'C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --quit` — exit 0, import and script registration completed.
- `& 'C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --quit-after 120` — exit 0, prints `TASK-000 graybox scene loaded`.
- `python scripts/validate_docs.py` — exit 0.
- One headless runtime attempt exposed a Node vs Node3D attachment mismatch; corrected the player input node type and reran runtime successfully.
- GUI window opened, but the computer control layer reported user-input interruption when sending key input. Screenshot showed the game window but did not establish reliable movement/crouch/jump/collision behavior. GUI acceptance remains pending; no physics interaction is claimed as passed.
- Git diff unavailable because project directory has no `.git` repository.

## Manual acceptance still required

Run `run_graybox.bat`; use mouse look, W/A/S/D, hold Shift for faster movement, Space to jump onto/over the small step, and hold Ctrl behind the low wall. Release Ctrl where there is overhead clearance and verify standing is blocked where clearance is insufficient. Walk into the low wall/buildings/barrier and verify no penetration. Press Esc to release the mouse and left click to recapture. Record any behavior issues before marking this task complete.

Not implemented: weapons, ADS, enemies, full level movement tuning, or performance measurement.

## Final validation update (2026-10-28)

- A final edit to the standing-clearance query briefly introduced a GDScript indentation parse error; fixed before completion.
- Reran `godot --headless --editor --path . --quit` with the full Godot 4.7.2 console path — exit 0, no script errors.
- Reran `godot --headless --path . --quit-after 120` — exit 0, scene load marker only; no runtime script errors.
- Reran `python scripts/validate_docs.py` — exit 0.
- GUI interaction acceptance is still pending; task is not marked passed until the movement states and collisions are manually walked.

## Crouch key correction (2026-10-28)

User reported Left Ctrl did not crouch. Inspection found `crouch` mapped to physical keycode 4194328 (Meta), not Ctrl. Corrected the InputMap physical keycode to 4194327 (Ctrl). Godot 4.7.2 headless editor import/parse exited 0; headless scene launch exited 0 with the scene-loaded marker; docs validator exited 0. The user should restart `run_graybox.bat` and retest holding Left Ctrl; no GUI keypress retest was performed in this turn.

## Follow-up: corrected Ctrl keycode after user retest (2026-10-28)

The prior keycode update was still wrong: local Godot runtime reports `KEY_CTRL=4194326` and `KEY_META=4194327` (the earlier 4194328 value had also been wrong). Set the crouch InputMap physical keycode to 4194326. A one-off Godot script constructed an `InputEventKey` with `KEY_CTRL` and confirmed `InputMap.event_is_action(..., "crouch") == true`; the inspection script was removed afterward. Godot headless editor import/parse, scene launch, and docs validation all pass after the correction. User needs to fully close and relaunch the game before retesting Left Ctrl.
