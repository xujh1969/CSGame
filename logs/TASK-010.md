# TASK-010A | AK 敌人表现与战斗样板

日期：2026-10-31  
分支：`task-010-enemy-ak`  
状态：实现与自动检查通过；用户视觉/操作验收和性能验收待完成。

## 实现

- 用户提供的蒙面人物低模/高模与 AK-47 低模/模型保留在原处；新增派生 GLB、Blender 源文件和烘焙贴图位于 `assets/models/task010/`、`assets/source/task010/`、`assets/textures/task010/`。构建输入 SHA-256 和对齐误差记录见 `TASK-010-body-build.json`、`TASK-010-ak-build.json`。
- 敌人沿用原 AI、碰撞、伤害和射线；真实骨架播放 Fire、Move、Crouch、Death。AK 挂到右手骨，实际显示枪口作为 EnemyWeapon 的射线起点。枪械展示方向跟随 AI 瞄准点，修复并回归验证了窗台敌人的枪口俯仰偏差。
- 枪口火焰使用多层短时火焰、暖光及少量烟雾；死亡动画播放至末帧并保持，尸体停火且关闭命中碰撞。
- `EnemyCombatSample.tscn` 使用独立导航网格。墙后掩体点为 `(2.6, 0, -16)`，探身点为墙侧 `(0.8, 0, -13.5)`，验证敌人沿实体墙侧路径到达并返回。

## 来源与限制

- 人物和枪械源模型由用户交付（混元 3D）；导入的 Mixamo 格式动作随交付资产一并提供。动作文件/许可来源尚未确认，未推断或声明其商业许可。烘焙模型不改变原始源文件。
- 全局截图日志显示本机 Godot 使用 AMD Radeon(TM) Graphics。未记录帧时、GPU/CPU 性能基线或 60 FPS/720p 结论。性能验收待做。
- 环境任务（碎石、水洼、棕榈树、电线、远景建筑/雾尘）仍未开始。

## 执行检查

Godot：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`，版本 4.7.2 stable。

- `--headless --editor --path . --quit`：exit 0，导入/解析通过。
- `--headless --path . --script res://tests/test_enemy_presentation.gd`：exit 0，失败 0；骨架、动画、AK/枪口绑定、射击火焰、死亡保持及死后禁射通过。
- `--headless --path . --script res://tests/test_enemy_combat_sample.gd`：exit 0，失败 0；探身点/掩体点可达，实体移动绕墙到达并返回通过。
- `--headless --path . --script res://tests/test_enemies.gd`：exit 0，失败 0；AI、遮挡、枪口瞄准、玩家伤害、死亡与重开回归通过。
- `--headless --path . --script res://tests/test_weapon.gd`：exit 0，失败 0。
- `--headless --path . --script res://tests/test_campaign.gd`：exit 0，失败 0。
- `--headless --path . --script res://tests/test_art_sample.gd`：exit 0，失败 0。
- GUI 交战样板已启动，窗口标题为 `Urban Corridor FPS / TASK-010A AK Enemy Combat (DEBUG)`；截图和状态记录见 `TASK-010-enemy-*.png`、`TASK-010-gui-captures.txt`。已确认人物、AK 与火焰可见，死亡姿势落地。未完成窗口内实际移动、玩家对敌射击/击杀/重开流程；现有截图不是实战验收。

## 待验收

- 用户人工检查角色贴图与 AK 握持/枪口方向、火焰尺度及死亡姿势。
- GUI 中实际移动、敌人开火、玩家命中致死、尸体保持、重开。
- 目标硬件上的 FPS/帧时实测；当前机器不能代表 RTX 2060 目标。
- 动作来源及许可确认。
