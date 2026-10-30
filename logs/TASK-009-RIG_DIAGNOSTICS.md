# TASK-009 diagnostic checkpoint — 2026-10-30

## A 修改文件
- debug/FPSRigDiagnostics.gd, FPSPalmCalibration.gd, FPSRigTest.gd, fps_rig_test.tscn: actual node/skin/track inventory, real palmar BoneAttachments, independent physical sockets, eye/stock framing, same-frame capture.
- tests/test_fps_rig_diagnostics.gd: injected missing/20cm palm errors and missing/behind-camera ADS errors; real weapon authority and eight state snapshots.
- scripts/tools/build_palmar_candidate.py, assets/models/task009/v008/arms_palmar_candidate.glb, assets/source/task009/v008/Arms_Palmar_Candidate.blend, data/asset_registry.json: isolated anatomical mid-palm candidate, no original-model replacement.
- run_rig_candidate.bat, docs/11_FPS_RIG_DIAGNOSTICS.md; debug/reference preserves the three supplied files.

## B 已执行检查
Godot 4.7.2.stable.official.ed1daf0bf, Blender 5.2.3 LTS.
Commands (absolute Godot/Blender paths recorded in launchers/logs):
- Godot --headless --editor --path . --quit: exit 0; logs/TASK-009-final-import.txt.
- Godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd -- --candidate --clean: exit 0, framework failures=0, 8 same-frame PNG+JSON captures. logs/TASK-009-diagnostics-clean-gui.txt. Static Fire/Reload presentation is intentionally frozen; this does NOT validate restored animations.
- Godot --headless --path . --script res://tests/test_weapon.gd: exit 0, 30 PASS.
- ... tests/test_art_sample.gd: exit 0, 29 PASS.
- ... tests/test_campaign.gd: exit 0, 50 PASS; missing-catalog rejection is the intentional negative case.
- Blender --background --factory-startup --python-exit-code 1 --python scripts/tools/inspect_hand_anatomy.py: exit 0, independent open-bind hands rendered with actual wrist axes, original glove texture.
- Blender candidate build with --python-exit-code 1: passed 12.20mm prebind edge-increase guard; preserved original weights. Prior v006 stronger-curl experiment failed at 30.29mm and was not exported.
- git lfs fsck: passed before initial upload. GitHub first push is still in progress with no successful remote refs verified; upload must not be called complete.

## C 人工画面核查
The black palmar and yellow/green dorsal material plus independent thumb direction confirm source native L chain is anatomical right and native R chain is anatomical left; no negative scaling. Evidence: TASK-009-v006-right-hand.png and left-hand.png.
Latest Hip view: TASK-009-v008-hip.png, stock no longer horizontally fills right side. ADS: TASK-009-v008-ads.png, sight aligned but left fingers remain visibly unnatural near optic. These are NOT approved baselines.
Run run_rig_candidate.bat; right mouse ADS; F9 saves actual same-frame diagnostics; Esc pauses. Candidate is separate from campaign.

## D 根因与未完成项
Legacy viewmodel was only 6cm below eye, creating head-side stock framing. Eye remains Player/Camera3D at local Y=1.70m; static Hip root is 23cm below eye. Eye-to-stock marker 26.88cm, nearest stock vertex 22.75cm. No full-body shoulder geometry is approved, so a design shoulder marker alone cannot establish correct contact.
Earlier wrist-biased palm selection could pass contact checks while fingers stood away from grip. v008 samples anatomical middle palm from actual skin/texture and solves the complete hand bind frame to independently fixed sockets. Current contacts R10.18mm/L11.23mm within preliminary 4cm tolerances do not prove finger wrapping or collision-free mesh.
ADS left fingers require further anatomical finger-chain correction. Fire/Reload animation restoration, static visual approval, approved regression baseline and target GPU performance remain incomplete. Do not merge into main game or report overall acceptance.

## E 下一个允许任务
Continue TASK-009 static hand/eye/shoulder calibration. Only after static review may Reload be restored and all four animated states tested. Do not start TASK-010.
