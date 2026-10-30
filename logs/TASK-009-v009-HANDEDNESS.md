# TASK-009 v009 — 左右手错用纠正

2026-10-30。本记录纠正之前 v006/v008 的错误解剖判断；旧图及资源保留作历史证据，不能作为通过基线。

## 根因、前后变化

`inspect_hand_anatomy.py` 曾把“黑色掌面正对镜头、手指向上时拇指位于画面左侧”判为右手，实际应是左手。`prepare_gloves.py` 制作的历史 v005 语义映射将 native .L 作为 R、native .R 作为 L，v006/v008 延续了这一错误。这不是单纯文件命名问题：错误模型确实被部署到相反的握点。

v009 的独立派生构建从保留的 v005 源文件加载后，同时交换六个语义骨骼名及对应蒙皮 vertex groups，保留顶点组索引和数值权重；原生 .R 手指链归 R_Hand，原生 .L 手指链归 L_Hand。重新求解右手主握把、左手前护木的完整手掌坐标，不移动相机或武器物理 Socket，不镜像网格、不使用负缩放。原始 GLB SHA256 仍为 c93b94a69940656937e35848e9eb7f706e63c214f1972bf662ae64acc9630455。

新图片按正确关系重新渲染，原始手套材质保留，右手袖口红、左手袖口蓝。每张独立手图的左栏为黑色掌面，右栏为拼接手背；右手掌面拇指在画面右侧，左手掌面拇指在画面左侧。

## 修改文件

- scripts/tools/inspect_hand_anatomy.py：修正几何分类条件，输出 v009 独立图与 Blender 检视源文件。
- scripts/tools/build_palmar_candidate.py：语义骨骼/蒙皮组同步纠正，输出 assets/models/task009/v009/arms_palmar_candidate.glb 及 assets/source/task009/v009/Arms_Palmar_Candidate.blend。
- tests/test_hand_chirality.gd：旋转无关的掌面/拇指几何检查，验证真实 Skin 绑定。
- data/asset_registry.json、debug/FPSRigTest.gd、tests/test_fps_rig_diagnostics.gd：登记并独立验证 v009。
- run_cinematic_sample.bat、run_rig_candidate.bat：样板入口指向独立 v009，避免继续打开旧 v006；默认战役场景不变。
- README.md、docs/11_FPS_RIG_DIAGNOSTICS.md、本记录及本轮 logs：撤回旧结论，保留真实检查结果。

## 实际检查

Godot 可执行文件：C:/Program Files/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe。
Blender 可执行文件：C:/Program Files/Blender Foundation/Blender 5.2/blender.exe。

1. Godot --headless --path . --script res://tests/test_hand_chirality.gd -- --candidate：修改前 v008 exit 1，两侧错误（R 实际 L，L 实际 R）；修改后 v009 exit 0，两侧正确。红绿日志分别为 TASK-009-chirality-red.txt、TASK-009-chirality-green.txt。
2. Blender --background --factory-startup --python-exit-code 1 --python scripts/tools/build_palmar_candidate.py：exit 0；预绑定网格最大边长增量14.66mm，小于30mm守卫，权重数值未变。
3. Blender 同参数执行 scripts/tools/inspect_hand_anatomy.py：exit 0，实际重渲染两手，无动画、无负缩放。
4. Godot --headless --editor --path . --quit：exit 0；TASK-009-v009-import.txt。
5. Godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd -- --candidate --clean：exit 0，框架失败0，8组同帧JSON/PNG；TASK-009-v009-gui.txt，fps_rig/candidate_v009/summary.json。候选 Fire/Reload 表现仍冻结，不能称动画通过。
6. test_weapon.gd / test_art_sample.gd / test_campaign.gd：均 exit 0，分别30/29/50项通过。TASK-009-v009-weapon.txt、art_sample.txt、campaign.txt。
7. cmd /c "run_rig_candidate.bat --quit-after 60 < NUL"：实际 GPU 启动及退出，exit 0；TASK-009-v009-bat-smoke.txt。无人工键鼠操作通过声明。
8. 只读代码复核确认实际 GLB 手指链、两份 Skin 绑定及握点映射；未改主关卡、相机父节点或弹药控制逻辑。

## 画面核查与未完成项

四张新图：TASK-009-v009-right-hand.png、TASK-009-v009-left-hand.png、TASK-009-v009-hip.png、TASK-009-v009-ads.png。全部为实际渲染，无镜像后期处理，尚未获用户视觉验收。

左右手错用已经数据复现并纠正。ADS 仍能看到左手手指竖在瞄具旁，包握角度尚不自然；不能把本次纠正说成握持/换弹整体修好。静态姿态通过前不恢复 Reload，不合入默认战役，不进入 TASK-010。未重新进行目标 RTX2060 性能验收。

GitHub 初次推送完成3.4GB LFS传输后被 GH008 拒绝（缺少至少23个对象）；不能声称上传完成。后续需补齐 LFS 对象并核对远端提交。
