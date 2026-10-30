# TASK-004 — 三名敌人、触发与状态机

日期：2026-10-28（Asia/Shanghai）。Godot：4.7.2.stable.official.ed1daf0bf。
本目录仍非 Git 仓库，git status 无分支或 diff；通过基线 SHA256 和逐文件记录追踪改动。

## A 修改文件清单

- 新增 `scenes/enemies/EnemyBase.tscn`：灰盒胶囊/头/枪、独立生命组件、感知、武器、状态和表现接口。
- 新增 `scripts/enemies/{enemy_brain,enemy_perception,enemy_weapon,enemy_visual}.gd`：状态机、实体导航/站蹲、LOS/FOV、短点射与最近碰撞、警戒/失能可见反馈。Godot 生成对应 `.gd.uid`。
- 新增 `scripts/game/encounter_manager.gd`：一次激活和一次清场事件；不生成新敌人。
- 新增 `scripts/tools/bake_corner_navigation.gd`、`scenes/levels/CornerNavigation.tres`：从实际静态碰撞离线烘焙 10 个导航多边形。
- 修改 `scripts/tools/build_vertical_slice.py`、`data/vertical_slice.json` 和重烘焙的 `scenes/levels/VerticalSlice01.tscn`：加入三名预摆敌人、朝向、掩体/探出点、局部导航区及管理器。建筑/道路/三类掩体模块不改。
- 修改 `scenes/player/player.tscn`、`scripts/player/player_controller.gd`：复用 HealthComponent，死亡时停止输入并释放鼠标。
- 修改 `scripts/weapons/weapon_controller.gd`：只新增 cancel_actions，用于死亡取消持续开火、ADS 和未完成换弹；弹量/射速/命中算法保持。
- 修改 `scripts/ui/weapon_hud.gd`、`scenes/weapons/WeaponHUD.tscn`：增加临时 HP 和 PLAYER DOWN 文字，沿用 Reset test。
- 新增 `tests/test_enemies.gd`；修改 `tests/test_level.gd` 的回归初始化，显式关闭 AI 以单独检查原几何通路，未删失败用例。
- 更新资产 registry 的 EnemyBase 灰盒 fallback_scene、README、AI/决策文档及 TASK-003 用户反馈记录。
- 新增本记录、基线 hash、真实命令输出与 6 张实际图形渲染截图。所有正式 GLB 仍 missing。

## B 已执行检查和结果

引擎完整路径：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。

| 命令（godot 用完整路径） | 真实结果/证据 |
|---|---|
| `python scripts/tools/build_vertical_slice.py` | 写入静态可编辑场景；seed 与 JSON hash 保持追踪 |
| `godot --headless --path . --script res://scripts/tools/bake_corner_navigation.gd` | 退出 0，实际烘焙 10 多边形；`TASK-004-navigation-bake.txt` |
| `godot --headless --editor --path . --quit` | 退出 0，无 ERROR / SCRIPT ERROR；`TASK-004-import.txt` |
| `godot --headless --path . --fixed-fps 60 --script res://tests/test_enemies.gd` | 46 项 PASS，failures=0；`TASK-004-tests.txt` |
| `godot --path . --fixed-fps 60 --script res://tests/test_enemies.gd -- --render-checkpoints` | 同一战斗检查以真实 Forward+ 渲染运行，52 项检查通过（含保存 6 张图）；`TASK-004-render-combat.txt` |
| `godot --headless --path . --script res://tests/test_weapon.gd` | 原武器 30 项 PASS；`TASK-004-weapon-regression.txt` |
| `godot --headless --path . --fixed-fps 60 --script res://tests/test_level.gd` | 原通路 40 项 PASS，仍实体步行到终点；`TASK-004-route-regression.txt` |
| `godot --headless --path . --quit-after 120` | 默认场景无运行错误；`TASK-004-smoke.txt` |
| `python scripts/validate_docs.py` | 退出 0，20 个主文档/任务文件与 2 个 JSON 合同通过；`TASK-004-docs.txt` |

AI 检查覆盖：三敌预摆/休眠；实际步行跨 T1；反复触发不增敌；街角导航真实往返且单帧水平位移不超过 0.06m；实例碰撞独立；窗口首次开火约 1.133s；窗口无楼层导航；完整实墙阻挡 LOS、攻击与伤害，连续 5s 无穿墙跟踪；视野背后不追踪；E03 真实矮墙站蹲；玩家 4 发实际射线击杀 100HP 敌人；死亡/清场各一次；失能碰撞关闭、停火；玩家死亡停火并取消换弹；重开复位；提前击杀休眠敌人不补刷。

初次测试 3 项街角导航失败。诊断路径点 y≈0.1m，而实体脚点 y≈0，原到达阈值 0.1m，卡在 x≈3.66 的中间点。调整阈值为 0.2m 后，同一测试达到 x≈3.125、实体返回约 (4.577,0.079,-25)，没有瞬移或忽略碰撞。

## C GUI / 实际画面与本机复核

使用非 headless、真实 Vulkan / Forward+ 图形窗口运行同一战斗检查（本机 AMD Radeon 集显、1280×720），通过当前游戏视口保存：

- `TASK-004-corner-fire.png`：街角敌人探出并短点射，玩家 HP 实际下降。
- `TASK-004-window-alert.png`：窗口兵黄色警戒。
- `TASK-004-window-fire.png`：窗口兵开火并朝玩家俯仰瞄准。
- `TASK-004-cover-alert.png`：矮墙兵站起警戒。
- `TASK-004-enemy-dead.png`：敌人真实受到四发玩家伤害后失能。
- `TASK-004-player-down.png`：玩家 HP=0、停止输入和火力，临时文字提示重开。

自动检查会设置测试站位、控制时钟及动作，使用真实物理查询/角色移动；截图为运行画面，不能当作全程人工键鼠战斗验收。

另执行 `cmd.exe /d /c run_graybox.bat`，普通游戏窗口真实启动，起点可见 HP 100/100、30/90 和灰盒街段。尝试通过 Windows 自动操作持续按 W 进入遭遇区时，接口返回 `Held key presses are unavailable on Windows`，未发送该持续按键。故未将这次尝试记为人工战斗通过；完整操作仍需用户复核。测试启动的窗口保持打开，若出现多个 DEBUG 窗口，应全关后用批处理重新打开最新版。

人工步骤：关闭旧游戏，再双击 run_graybox.bat；走过三条蓝色触发线，观察黄色警戒后才点射；E01 从右侧街角移出/退回，E02 固定左侧高窗，E03 在右侧低墙后站蹲。用实墙躲避；射击敌人应扣 25HP，四次有效命中后失能且停火。反复进出触发线不增敌。玩家倒下后可直接点击右上角 Reset test，敌人/HP/弹量均应复位。

## D 未验证项和依赖

- 2026-10-28 用户反馈“功能都确认实现”，TASK-004 功能验收由用户确认通过；难度/手感进一步调优、1080p 完整布局与性能实测不在此次确认中推定完成。
- 只有灰盒胶囊、简易枪与警戒颜色/状态标签，无骨骼动作、语音或音效，EnemyBase 作为正式 GLB 的替代接口。
- 失能使用原脚点的灰色压低占位；未使用会把身体转进邻墙的侧倒表现，不宣称已制作正式倒地动画。
- 固定站位 AI；只有 E01 的短局部导航，没有全地图追击或复杂掩体规划。
- SEARCH 超时后回指定掩体再观察，未实现永久脱战 Dormant 重置。
- 临时死亡停用不等于正式失败流程；未做胜利、暂停菜单或正式 GameFlow，Esc 当前仍只释放鼠标。
- 未做 RTX2060 5 分钟性能测量，固定帧测试不代表实测 FPS，不宣称达标。

## E 下一任务闸门

TASK-004 功能验收通过（2026-10-28 用户确认），结合此前 46 项 AI 检查和 70 项回归检查。下一允许开始的任务是 TASK-005：完整战斗循环、HUD、基础特效/音效与暂停/胜负/重开流程。本轮仅更新验收记录，未开始 TASK-005。
