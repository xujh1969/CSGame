# 07 验收、测试与性能标准

## TASK-009 电影与枪械样板

v002接入用户混元3D AR-15，新增原件SHA、真实圆筒瞄具轴线开孔、GLB显式材质引用（防Boolean白截面）、抽出弹匣实际Camera逻辑视口覆盖检查。第一人称枪影关闭仅去除孤立投影，未实现完整身体影子；双臂/全身协作规范见PLAYER_ARMS_AND_SHADOW.md。最新真实38项headless/44项图形与依赖见logs/TASK-009-v002.md。

`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_cinematic_sample.gd`：实际网格/独立弹匣/镜片、枪口对齐、ADS、真实弹量/装填/暂停、全枪网格在正面/±30°斜墙前、真实挡弹、Low景深关闭、原实体路线/杀敌/胜利/重开。
图形去掉headless/fixed-fps，加`-- --render-checkpoints --measure-performance`，另加`--render-1080`复验；额外比较ADS时有无玻璃的真实中心像素差，防不透明镜片或着色器白块漏过逻辑测试。真实截图hip/ads/reload/wall/low和帧间隔见logs/TASK-009*；`capture_rifle.gd`输出真实产品视图。
脚本走测不等于用户键鼠/视觉验收；模型/镜片品质、视野遮挡和手感仍需人工。参考图效果与RTX2060性能目标不按文件存在或退出码直接判定完成。

## TASK-008 样板验证入口

`test_art_sample.gd` 验证GLB真实加载、Albedo/Normal/Roughness保留、路障/车辆/立面射线、全程1.2m胶囊余量、原玩家实体行走/杀敌/终点与样板重开、Low阴影关闭。
`godot --audio-driver Dummy --path . --script res://tests/test_art_sample.gd -- --render-checkpoints --measure-performance` 保存实际三视点及Low图、测720p短时帧间隔；加 `--render-1080` 测1920×1080。
`capture_sample_assets.gd` 输出7个真实GLB模型预览。背景Blender命令、MCP状态、材质来源、原功能回归、实测数值与未完成依赖见 logs/TASK-008.md；2026-10-29用户确认TASK-008 v003人工验收通过，原自动/图形检查证据保留。
v003新增 `capture_vehicle.gd` 输出实际低模正反面；test_art_sample验证导入后实际9614三角面/2K PBR、原件SHA256、真实车身/车舱凸碰撞、车身射线阻挡/车顶上方射线通过、玩家胶囊阻挡及重开保留车型。性能在接入车辆后重新短测。
反馈后新增四条实际网格线段检查，验证两个阳台的左右回栏；v001缺侧栏失败保留在TASK-008-rail-red.txt。另验证95粒子上限、体积雾与火光的Low关闭、40块较大碎片实体碰撞及新增碎石后的1.2m全路线余量。新效果有成本，按新版本重新记录720/1080p帧时，不沿用无烟尘时的数据。

## TASK-007 多关卡验证

`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_campaign.gd` 覆盖目录拒绝、真实战斗与实体走到两关终点、按钮切关、失败/暂停当前关重试、末关结算、重复请求互斥、旧实例释放、重复A/B装卸与坏配置恢复。
图形检查去掉 headless/fixed-fps，末尾加入 `-- --render-checkpoints --measure-performance`；保存启动/首关胜利/第二关失败/最终胜利/加载错误的真实图像，并做两关静止视点各180帧墙钟采样，不能当目标硬件长测。
`test_campaign_close.gd` 在预备实例已创建且五个空间音频活动时发出真实 WM_CLOSE 通知，验证切换中退出。最终结果与初始失败诊断分开存于 logs/TASK-007*。

## TASK-006 验证入口

- `python scripts/tools/build_vertical_slice.py`：写入前检查当前 80m 核心配置，生成 11 个场景。
- `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_level_runtime.gd`：配置拒绝、同 seed 复现、20 seed 核心/碰撞不变、无重复、真实 GLB 替换仍挡弹、F3/F4 动作。
- 去掉 headless/fixed-fps，末尾加 `-- --render-checkpoints`：真实图形截图及装饰关/开/关各 180 帧墙钟采样；是本机短测，不是 RTX2060/5分钟基准。
- `test_level.gd` 继续实体步行全通路；`test_game_flow.gd` 继续完整战斗通关。命令与结果在 `logs/TASK-006.md`。

## TASK-005 增加的验证入口

`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_game_flow.gd` 验证真实战斗/换弹/物理步行到胜利、同帧胜负竞态、暂停、重开、HUD 与低画质限额。
去掉 `--headless` 并在末尾加入 `-- --render-checkpoints`，可验证 Windows 鼠标捕获并保存 720p/1080p、暂停/失败/胜利图像。
旧 AI 和通路回归显式禁用 GameFlow，仅隔离测试各模块；完整流程由上述新测试覆盖。音频使用 Dummy 时不能宣称已通过实际听音验收。

## 验证链（从便宜到昂贵）
1. JSON / 文档规范检查：`python scripts/validate_docs.py`。
2. Godot 资源导入/脚本解析（引擎安装后执行，命令示例）：`godot --headless --editor --path . --quit`；如果 PATH 没有 godot，请用完整可执行路径。
3. Headless 场景烟雾测试：`godot --headless --path . --quit-after 120`，注意命令退出并不证明按键/画面有效。
4. 必须在 Windows GUI 中完成一次操作测试：操作、瞄准、换弹、碰撞、AI、HUD、重开。
5. 性能测试在正式基准机器实际跑一次，记录分辨率、渲染器、画质档、FPS 分布、最大帧时间、GPU/CPU 大致指标。

## 第一阶段人工验收清单
- [ ] 启动第一关后鼠标锁定，Esc 可释放、暂停，返回游戏后再次锁定。
- [ ] W/A/S/D + Shift/Space/Ctrl 动作全部有效，无自动漂移。
- [ ] 蹲下可以躲在矮墙后，站立或移出掩体可以被射中。
- [ ] 贴近障碍物时不能越墙攻击；射线命中与视觉遮挡一致。
- [ ] 左键射击扣 1 弹，连射频率可控；弹量为 0 时不能射出伤害。
- [ ] R 正常换弹，库存扣减正确；在换弹未完成时反复按 R 不能刷子弹。
- [ ] 街角、窗口、矮墙三名敌人能分别被激活，数量不会因 Trigger 多次进入重复增加。
- [ ] 被击中减少生命，生命为零仅触发一次失败；重开所有数据重置。
- [ ] 三名敌人失能后向终点推进触发胜利。
- [ ] 玩家不能掉出路面、穿过墙/车辆或被随机物件堵死主路线。
- [ ] 游戏 UI 在 1280x720 与 1920x1080 不遮挡主要视线/按钮。

## 自动化与脚本测试建议
- `test_reload_math`：30/90 -> 开 10 发 -> 20/90 -> R -> 30/80；库存为 0 时不可补弹。
- `test_enemy_death_once`：重复伤害不重复死亡事件。
- `test_encounter_once`：触发器重复进入不重复 activate/spawn。
- `test_level_seed`：固定 seed 产生相同的非核心装饰清单。
- `test_asset_contract`：资源 registry 中 `ready` 的文件必须存在。
- `test_route_clearance`：关键点之间无明显阻断（静态网格检测 + 人工走测）。

## 性能实测合同
- 最低：1280x720 Low，持续游玩 5 分钟，基准 RTX2060 参考机目标 >=30 FPS 且没有严重 1 秒以上冻结。
- 理想：1920x1080 Medium，目标 60 FPS；**未实测之前只能称目标**。
- 记录在 `logs/performance_<date>.md`，包括 Godot 精确版本、分辨率、场景版本、敌人数、平均 FPS、1% low（如有采集）、最差帧时、CPU/GPU。
- 发现瓶颈优先定位：透明烟雾过度叠加、动态阴影数量、重复节点/Draw Calls、实时导航烘焙、纹理分辨率和内存。

## 一张 TASK 通过的共同定义
完成代码 + 与现有工程不冲突 + Godot 解析成功 + 本任务可视操作测试通过或清楚标注未验证项 + Git diff/资源变化列表 + 更新日志；有 P0 阻断问题不得跳到下一任务。

## TASK-009 v004 双臂回归（2026-10-30）
新增手套原件SHA、初始右掌向握把/左掌向上检查；换弹采样检测双臂骨骼中心线至少120mm、左腕在相机坐标中始终处于右腕左侧至少50mm。截图覆盖持枪、瞄准、取弹匣、抽出、插回、冲刺后。骨骼距离仅为胶囊式粗检查，不能代表袖口/指尖网格零穿模；截图等待会经过额外物理帧，采样不能声称逐物理帧全覆盖。旧 contact_errors 已改名 reachability_errors，只代表手腕目标可达性。人工重点仍为掌根贴握把、指节方向、左侧换弹及连续动作。
