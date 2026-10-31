# TASK-010A | AK 敌人表现与战斗样板

日期：2026-10-31  
分支：`task-010-enemy-ak`  
状态：实现与自动检查通过；用户视觉/操作验收和性能验收待完成。

## 实现

- 用户提供的蒙面人物低模/高模与 AK-47 低模/模型保留在原处；新增派生 GLB、Blender 源文件和烘焙贴图位于 `assets/models/task010/`、`assets/source/task010/`、`assets/textures/task010/`。构建输入 SHA-256 和对齐误差记录见 `TASK-010-body-build.json`、`TASK-010-ak-build.json`。
- 敌人沿用原 AI、碰撞、伤害和射线；真实骨架播放 Fire、Move、Crouch、Death。AK 挂到右手骨，实际显示枪口作为 EnemyWeapon 的射线起点。枪械展示方向跟随 AI 瞄准点，修复并回归验证了窗台敌人的枪口俯仰偏差。
- 枪口火焰调整为更柔和的不规则焰形，烟雾降至 3 个小颗粒、0.24 秒寿命和低透明度；视觉检查截图中不再有大团烟雾遮挡。
- 敌人模型关闭硬阴影接收/投射，并加无阴影暖色近身补光，保留环境本身阴影。死亡时扫描主要骨骼与场景碰撞；贴墙时最多将视觉模型推离障碍 0.25m，若仍相交则保持在最后安全帧。活体移动动画也会回退并暂停在安全姿势，直到骨骼离开实体墙。
- `EnemyCombatSample.tscn` 使用独立导航网格。墙后掩体点为 `(2.6, 0, -16)`，探身点为墙侧 `(0.8, 0, -13.5)`，验证敌人沿实体墙侧路径到达并返回。

## 来源与限制

- 人物和枪械源模型由用户交付（混元 3D）；导入的 Mixamo 格式动作随交付资产一并提供。动作文件/许可来源尚未确认，未推断或声明其商业许可。烘焙模型不改变原始源文件。
- 全局截图日志显示本机 Godot 使用 AMD Radeon(TM) Graphics。未记录帧时、GPU/CPU 性能基线或 60 FPS/720p 结论。性能验收待做。
- 环境任务（碎石、水洼、棕榈树、电线、远景建筑/雾尘）仍未开始。

## 执行检查

Godot：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`，版本 4.7.2 stable。

- `--headless --editor --path . --quit`：exit 0，导入/解析通过。
- `--headless --path . --script res://tests/test_enemy_presentation.gd`：exit 0，失败 0；骨架、动画、AK/枪口绑定、射击火焰、死亡保持及死后禁射通过。
- `--headless --path . --script res://tests/test_enemy_combat_sample.gd`：exit 0，失败 0；探身/掩体可达、绕墙移动、直线冲墙被物理碰撞阻挡、贴墙死亡主要骨骼不穿入实体墙均通过。
- `--headless --path . --script res://tests/test_enemies.gd`：exit 0，失败 0；AI、遮挡、枪口瞄准、玩家伤害、死亡与重开回归通过。
- `--headless --path . --script res://tests/test_weapon.gd`：exit 0，失败 0。
- `--headless --path . --script res://tests/test_campaign.gd`：exit 0，失败 0。
- `--headless --path . --script res://tests/test_art_sample.gd`：exit 0，失败 0。
- 2026-10-31 本轮光照/枪口/碰撞修正后重跑以上 6 个测试及 `--headless --editor --path . --quit`：全部 exit 0。
- GUI 真实渲染截图刷新于本轮，记录见 `TASK-010-enemy-*.png`、`TASK-010-gui-captures.txt`。已确认补光显出衣物细节、短火焰可见、烟雾收敛；未完成窗口内实际移动、玩家对敌射击/击杀/重开流程，截图仍不是实战验收。

## 待验收

- 用户人工检查角色贴图与 AK 握持/枪口方向、火焰尺度及死亡姿势。
- GUI 中实际移动、敌人开火、玩家命中致死、尸体保持、重开。
- 目标硬件上的 FPS/帧时实测；当前机器不能代表 RTX 2060 目标。
- 动作来源及许可确认。

## 2026-10-31 用户视频问题回归

- 实体碰撞实测中，CharacterBody3D 直冲混凝土墙会停住；导航移动时跑步动画的手臂仍会切入墙面，视觉上像敌人穿墙。表现层现逐帧检查主要骨骼与世界/掩体碰撞；相交时回退到安全动画帧并暂停，离墙后恢复。回归覆盖到墙后掩体绕行、返回和直线冲墙。
- 死亡贴地改为持续校正骨架最低非末端骨骼，动画停止后仍继续校正。完整死亡时长测试确认最低骨骼维持在地面附近；GUI 更新图 `TASK-010-enemy-dead.png` 可见尸体横躺在路面。
- `EnemyCombatSample` 现在按 seed `20261031` 布置三名同遭遇敌人：墙后、汽车侧后、随机左右窗位。汽车侧后敌人有可达探身路线；遭遇管理等全部成员死亡才清场。当前 seed 选择车侧 `x=-2.25`、窗侧 `x=5.4`，改 seed 可复现其他选点。
- 最近检查：`--headless --editor --path . --quit` exit 0；`test_enemy_presentation.gd`、`test_enemy_combat_sample.gd`、`test_enemies.gd`、`test_weapon.gd`、`test_campaign.gd`、`test_art_sample.gd` 均 exit 0，失败数 0。样板与实际死亡姿势 GUI 捕获已更新；交互式人工游玩和目标硬件帧时仍待验收。
