# TASK-000 verification record

Date: 2026-10-27 (Asia/Shanghai)
Project root: `C:\Users\AYOU\Desktop\CS`
Godot: 4.7.2.stable.official.ed1daf0bf
Executable: `C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`
Renderer configured: Forward+ (project setting; GUI runtime not yet visually checked)
Git: current directory is not a Git repository (`git status` returned fatal); no branch or diff baseline is available.
Assets: no existing 3D models, textures, or audio found; graybox uses built-in primitives.

## Planned checks and actual results

- `python scripts/validate_docs.py` — passed before edits: 20 Markdown files and 2 JSON contracts consistent. Must rerun after edits.
- `& '<Godot console exe>' --headless --editor --path . --quit` — pending.
- `& '<Godot console exe>' --headless --path . --quit-after 120` — pending.
- GUI launch: open `project.godot`, press F6/F5, inspect street and collision geometry — pending; headless checks do not prove the visual scene.

## Graybox contents

20 m long (Z -16 to +4) road/ground slab, 2 m × 6 m × 20 m side building blocks, one 2.5 m × 1.1 m × 0.45 m static barricade, and a camera-only player placeholder at the start. Static collision shapes are provided for the ground, buildings, and barricade. Player movement/collision, input behavior, gameplay, and performance have not been implemented or verified.

## Manual acceptance steps

1. Open the project folder in Godot 4.7.2 and confirm no import/parse errors.
2. Run the main scene; confirm the 20 m road, two side blocks, barricade, and camera view render.
3. In the Remote/Local scene tree, confirm Ground, BuildingLeft, BuildingRight, and Barricade each have a CollisionShape3D.
4. Confirm Project Settings > Input Map includes move_forward/back/left/right (W/S/A/D), sprint (Shift), jump (Space), crouch (Ctrl), fire/aim (mouse buttons 1/2), reload (R), pause (Esc).
5. Record GUI result and any errors here before considering TASK-000 passed.

## Final recorded checks (2026-10-27)

- `python scripts/validate_docs.py` — exit 0; reports 20 Markdown files and 2 JSON contracts consistent.
- `& 'C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --quit` — exit 0; filesystem scan/editor initialization completed without errors.
- `& 'C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --quit-after 120` — exit 0; printed `TASK-000 graybox scene loaded`.
- Initial editor parse found invalid inline mesh syntax; corrected to explicit BoxMesh subresources and reran both Godot checks successfully.
- Git status/diff could not be obtained: directory is not a Git repository. No existing project files were present to overwrite.
- GUI visual inspection and interactive tests remain pending. Headless checks do not satisfy the GUI acceptance item.

## Local GUI acceptance still required

Open `C:\Users\AYOU\Desktop\CS\project.godot` with Godot 4.7.2, wait for import, run with F6 or F5, and inspect the road, building blocks, barricade, and collision shapes. Confirm Input Map bindings in Project Settings. Record GUI result/errors here. No player controller exists, so movement/collision interaction is intentionally not testable in TASK-000.

## GUI follow-up (2026-10-27)

- Launched Godot 4.7.2 GUI for this project; a `Urban Corridor FPS (DEBUG)` game window appeared and displayed geometry, so the scene is not blank.
- The first visible run showed the road/building proportions obscuring the forward street view. Scene resource references and camera rotation were corrected in `scenes/main.tscn`.
- The computer-control session could not reliably stop/restart the running scene after that edit (F6/F8 did not transition away from the DEBUG window), so the corrected view has not been visually confirmed. Do not count GUI acceptance as passed yet.
- Manual follow-up: close the DEBUG window, stop any running scene in Godot, reopen/reload `scenes/main.tscn`, press F6, and verify road ground, side buildings, and barricade are visible ahead. Then inspect collision nodes and Input Map.

## User feedback and graybox preview adjustment (2026-10-27)

User reported that only the two side boxes were visible, the barricade was not visible, and mouse control did not respond, preventing collision inspection. Updated the graybox preview (still not a player controller): added a free-look camera script (captured mouse to look, Esc releases, left click recaptures; WASD translates the camera), moved the barricade to the center of the initial forward view at Z=-7, and gave it a high-contrast orange material. Collision remains static geometry only.

Headless editor import/parse and scene startup pass after these changes. GUI automation currently shows two stale `Urban Corridor FPS (DEBUG)` windows whose process start times predate the final scene edit; tool reported user-input interruption while trying to interact, so the updated GUI view and mouse response are NOT visually/ interactively verified. Close both old DEBUG windows and launch the project again to inspect. Then use mouse to look, WASD to move, Esc to release mouse, left click to recapture, and visually approach the orange barricade to confirm it blocks the preview camera. This is a preview-only collision inspection, not a physics-based player collision test.

## Collision and color fix from user retest (2026-10-27)

User verified that look, WASD, and Esc work, and reported the barricade still appeared white and could be passed through. Root cause: the preview camera translated a plain Node3D directly, bypassing Godot physics collision. Replaced it with a CharacterBody3D preview capsule (radius 0.3 m, height 1.8 m) and physics movement via `move_and_collide()`. The barricade mesh now owns a high-contrast unshaded orange StandardMaterial3D; the barricade remains a StaticBody3D with a matching 2.5 × 1.1 × 0.45 m BoxShape3D.

Checks rerun: Godot 4.7.2 headless editor import/parse exited 0; headless scene run exited 0 and printed the scene-loaded marker; `python scripts/validate_docs.py` exited 0. These checks do not prove the updated material appearance or physical blocking in GUI. User should retest by running the latest scene: orange barricade should be visible; moving forward into it should stop the preview capsule. User previously confirmed mouse look, WASD, and Esc respond.
