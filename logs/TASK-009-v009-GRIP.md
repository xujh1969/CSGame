# TASK-009 | v009 grip 静态左手包握校正

2026-10-30。继续 TASK-009，未启动 TASK-010 环境开发。旧 v009 和原始手套 GLB 保留。新资源独立位于 assets/models/task009/v009_grip/，可编辑源文件位于 assets/source/task009/v009_grip/。

## 根因与变化

1. 实际指链包含三段指节及末端辅助骨；旧左手统一弯曲约95°，指尖在护木外侧竖起，拇指也跨向了错误侧。新构建从真实护木网格建立 BVH，先求近端接触，再固定近端，仅以中远端指节避开瞄具视锥；不改变手腕、物理握点或眼位。
2. 直接把拇指拉向目标点，会拉扯原模型虎口中食指根骨/拇指中节混合权重的连接面。前三次导出守卫分别在33.39、33.37、38.31mm边长增量处拒绝，没有导出。后续将原始蒙皮的实际虎口变形纳入36个CMC/MCP可达配置的筛选，保持权重不变，最终全网格最大边长增量22.65mm，小于原30mm限制。
3. 第一版包握改善后，ADS出现指尖挡镜片的新回退；真实GPU烘焙手套三角形的25条瞄具视线中有6条被挡。加入镜片视锥约束后，检查降为0/25；这只是抽样无遮挡，不代表所有像素/角度都通过。
4. 折叠指尖进入原掌面空间区域，会污染掌心自动取样，使左右壳层分离变得模糊。诊断现在要求样本同时有至少0.5直接Hand绑定权重，排除由指节骨主要驱动的指尖；不移动标记来迎合测试。算法记录为 anatomical_midpalm_v3_hand_weight_filtered。

## 修改文件

- scripts/tools/audit_finger_chains.py、audit_foregrip.py：只读实际指链和枪模截面审计。
- scripts/tools/fit_foregrip_fingers.py、build_palmar_candidate.py：离线约束求解与导出；不会在游戏帧中运行优化器。
- tests/test_foregrip_pose.gd：实际枪宽、XYZ指尖范围、对照旧v009右侧rest、GPU蒙皮25条ADS视线；tests/capture_grip_sides.gd：左右握点外部固定视角。
- debug/FPSPalmCalibration.gd、FPSRigTest.gd、tests/test_fps_rig_diagnostics.gd、data/asset_registry.json：独立候选和真实掌面诊断。
- run_cinematic_sample.bat、run_rig_candidate.bat：启动标题显示 candidate v009 grip。
- README.md、docs/11_FPS_RIG_DIAGNOSTICS.md及本轮日志：状态与真实限制。
- 用户追加的 tasks/TASK-010.md、docs/08_ROADMAP.md：仅登记下一张环境卡，不实施环境变更。

## 实际命令与结果

Godot路径：C:/Program Files/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe。
Blender路径：C:/Program Files/Blender Foundation/Blender 5.2/blender.exe。

- Blender --background --factory-startup --python-exit-code 1 --python scripts/tools/build_palmar_candidate.py：最终 exit 0，22.65mm守卫通过。失败配置另记 TASK-009-foregrip-rejected-attempts.json。
- Godot --headless --editor --path . --quit：exit 0。
- Godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_foregrip_pose.gd -- --candidate：最终 exit 0；原包握范围检查红4失败，首轮镜片检查红6/25遮挡，最终绿0/25；右侧rest对照v009不变。日志 TASK-009-foregrip-red.txt、TASK-009-aperture-red.txt、TASK-009-aperture-green.txt。烘焙蒙皮须真实渲染设备；一次headless尝试报无有效skin并中止，已加显式失败退出，不将其计作通过。
- Godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_fps_rig_diagnostics.gd -- --candidate --clean：8组同帧JSON/PNG，框架失败0、初始掌面容差问题0。一次诊断因折叠指尖污染掌面而失败（3项框架失败）；修复取样后通过，不删除该问题的说明。
- test_hand_chirality.gd：exit 0，两侧仍正确。test_weapon.gd、test_art_sample.gd、test_campaign.gd：分别30、29、50项通过，日志 TASK-009-grip-*.txt。
- capture_grip_sides.gd：真实GPU两张外部握点截图，保存均OK；它使用单独调试相机，不改变玩家眼位。
- python scripts/validate_docs.py：通过；TASK-010仅计划，无实现结果。

## 画面核对与门禁

固定Hip/ADS与左右侧视图见 TASK-009-v009-grip-hip.png、ads.png、right-side.png、left-side.png；8状态JSON/PNG见 fps_rig/candidate_v009_grip/summary.json。

Hip/ADS中左手不再竖在瞄具旁，抽样视线清晰。外部侧视仍暴露右手与主握把的贴合问题，左手也不能仅凭包络/射线通过就视为自然、无穿模。指尖XYZ包络只约束位置范围，不证明接触；BVH近似法线、指腹半径和离线眼位参数仅适用于当前归一化资产。需要人工视觉核查及进一步握点校准。

没有恢复Reload表现，没有更改射击判定或弹药计算，没有将候选合入默认战役，没有新性能达标声明。下一步仍是TASK-009静态握持核对，随后才允许恢复换弹。TASK-010等待当前任务完成并验收。
