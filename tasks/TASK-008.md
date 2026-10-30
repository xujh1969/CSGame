# TASK-008 | 24米旧城街道环境美术样板

状态：2026-10-29 用户明确回复“验收通过”，TASK-008 v003人工验收通过。下一张允许开始的任务为TASK-009，本轮仅登记验收。

2026-10-29。用户已验收TASK-007并明确要求继续，采用 docs/11_NEXT_PHASE_DESIGN.md 中20–30m样板方案；本轮只执行本任务。

追加反馈：用户已实际运行样板，要求补齐阳台两侧围栏、加强电影光照与战场空气、增加大量不规则碎石杂物。v002执行这些修正；v003已收到用户混元3D低模GLB和高模FBX，保留原件，完成UV/2K材质烘焙、朝向/尺度校正与两段凸碰撞替换，等待新版视觉反馈。

## Goal / Design
参照 visual_target_01/03 的旧城街道，制作可行走/战斗的24m环境样板。双侧8m模块立面、粗糙路面、剥落抹灰、窗框/铁栏杆/卷帘门、路障与木箱、少量电线/杂物、暖日光及远景层次；三个固定玩家尺度视点评审。玩家/枪械/敌人仍为现有灰盒，此处不制作骨骼角色。

默认已验收的两关不动；独立 StreetSample.tscn 和 run_art_sample.bat 供用户观察。
Blender实测5.2.3，MCP最初不可达，用户配置后已验证连接；隔离background制作，MCP新增评审场景并另存v003，保留原场景和v001/v002。正式车辆已回传混元3D原件并派生入库；来源/许可限制/原件SHA256可追踪。

## Files / Implementation plan
使用writing-plans，按仓库惯例以当前任务卡保存计划。

- [x] 新增 tests/test_art_sample.gd：真实GLB/纹理路径、样板碰撞/射线/通路、三视点、Medium/Low渲染检查；首次运行出现类型推断解析错误，留档后修正，没有将其称为功能红测试。
- [x] scripts/tools/build_sample_assets.py：独立Blender原创规则资产，保存 assets/source/task008/*.blend、assets/models/task008/*.glb，导出几何/材质/单位/面数审计。先制作立面/店面/路面/路障/木箱与装饰套件。
- [x] scripts/art/street_sample.gd 与 scenes/levels/art/StreetSample.tscn：继承已验收短关只替换环境；可见几何/简单碰撞对齐。复用原GameFlow/玩家/武器/敌人，不改其数值。
- [x] 用户反馈修正：三面阳台栏杆（导出网格线段检查先红后绿）、seed成簇碎石和40块实体碎块、独立sample_atmosphere.gd，Medium烟/尘/火光/体积薄雾，Low关闭非关键表现。
- [x] run_art_sample.bat 使用已验证路径引用方式；原默认主场景/启动批处理保留。
- [x] docs/asset_requests/TASK-008_FIRST_BATCH.md：废弃车辆图生3D制作单、独立参考图、提示词、尺度/原点/坐标/拆分/许可/回传检查。图像不登记成模型。
- [x] 导入/自动/图形/物理走测与回归、三视点复查、实际帧时短测、更新registry与文档/logs；正式车辆已接入，用户视觉验收仍待完成。

## Acceptance
- [x] Blender源文件与真实GLB独立可复用，实际存在的资源才登记ready，记录来源和占位（质量为sample待审）。
- [x] 24m从起点到终点真实可走；掩体与替换外观吻合、挡弹；原有战斗可完成（自动实体验证）。
- [x] 起点/掩体/店前三张真实游戏截图可评审材质、尺度、光照和层次，不用生成图当游戏截图。
- [x] Low可用，实际记录本机帧时；不宣称RTX2060达标。
- [x] 用户所需的外部模型制作单与参考图交付，收到混元3D车型后替换/复验（9614面、四张2K贴图、两段凸碰撞，原文件哈希不变）。
- [x] 用户视觉/键鼠验收通过（2026-10-29用户确认）。建筑/远景仍为样板，不把部分样板标为最终写实达标。

## Commands
`blender --background --factory-startup --python scripts/tools/build_sample_assets.py`
`godot --headless --editor --path . --quit`
`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_art_sample.gd`
图形去掉headless/fixed-fps，末尾加 `-- --render-checkpoints`。
回归：test_campaign.gd、test_game_flow.gd、test_level_runtime.gd。
`python scripts/validate_docs.py`

## Out of Scope
整关美术替换、正式敌人/手臂动画、新武器、新AI、多关扩展、存档、全场景破坏、商业资产采购。
