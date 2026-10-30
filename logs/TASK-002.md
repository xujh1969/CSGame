# TASK-002 — 枪械、射线命中与换弹记录

2026-10-28 用户授权“可以继续开发后续功能”，据此进入 TASK-003。下文保留本代理实际完成与未独立完成的 GUI 验证边界。

日期：2026-10-28（Asia/Shanghai）。Godot：4.7.2.stable.official.ed1daf0bf。
项目：`C:\Users\AYOU\Desktop\CS`。本目录仍无 Git 仓库，无法提供分支、提交或 Git diff。

## A 修改文件清单

- 新增 `scripts/weapons/weapon_controller.gd`：30/90 弹量、0.11 秒射击间隔、2.2 秒换弹、25 伤害、散布及最近物理碰撞查询。
- 新增 `scripts/player/health_component.gd`：独立生命值、生命变化及单次死亡信号。
- 新增 `scripts/weapons/rifle_view_model.gd`、`scenes/weapons/RifleViewModel.tscn`：内建盒体灰盒枪、轻微后坐表现、ADS 视角和换弹姿态。
- 新增 `scripts/weapons/target_dummy.gd`、`scenes/weapons/TargetDummy.tscn`：青色静态靶子、受伤文字与失能灰色表现。靶子为实心测试物，失能后仍保持可见碰撞，不是 AI 敌人。
- 新增 `scripts/ui/weapon_hud.gd`、`scenes/weapons/WeaponHUD.tscn`：被动弹量/换弹/最近撞击显示、准星、Reset test 按钮。
- 修改 `scenes/player/player.tscn`、`scripts/player/player_controller.gd`：接入独立武器和 UI、InputMap 射击/ADS/换弹输入、轻微视角后坐。玩家碰撞查询包含测试靶层。
- 修改 `scenes/main.tscn`：新增无遮挡靶、实墙后的遮挡靶和匹配网格尺寸的静态实墙；维持 20m TASK-000 场地。
- 新增 `tests/test_weapon.gd`、本记录和原始导入/测试/烟雾输出；更新决策记录、TASK-001 用户复测记录。
- 由 Godot 导入生成相应新脚本的 `.gd.uid` 文件；没有第三方内容或插件。

## B 真实检查与结果

以下命令中的 `$godot` 对应实际可执行文件：
`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。

| 命令 | 真实结果 | 原始证据 |
|---|---|---|
| `& $godot --headless --editor --path . --quit` | 退出 0；检查输出无 ERROR / SCRIPT ERROR | `TASK-002-import.txt` |
| `& $godot --headless --path . --script res://tests/test_weapon.gd` | 退出 0；30 项检查通过，failures: 0 | `TASK-002-tests.txt` |
| `& $godot --headless --path . --quit-after 120` | 退出 0；成功加载，无运行错误 | `TASK-002-smoke.txt` |
| `python scripts/validate_docs.py` | 退出 0；20 个主文档/任务文件与 2 个 JSON 合同通过 | `TASK-002-docs.txt` |

测试覆盖：30/90→射 10 发→20/90→换弹→30/80；冷却；空弹仓；空库存；部分库存转移；重复 R；换弹期间禁射；跑步禁 ADS；普通 ADS；矮墙最近碰撞；实墙先于目标；枪口模型越过墙后仍被墙阻挡；无遮挡目标扣 25 HP；场景重建取消换弹并恢复弹药/靶子生命。

## C GUI 检查与本机步骤

已真实启动 Windows GUI。截图中可见灰盒枪、准星、弹量 26/90 和 13/90、ExposedTarget 从 75/100 到 DOWN、Impact: Barricade。窗口中有用户输入活动，发送自动 R 键时工具返回 `user input was detected in this window; call get_window_state before continuing`，已停止抢占式输入。

尚未独立完成的 GUI 项：ADS 的视觉变化、R 换弹操作和实际完成时机、Reset test 按钮交互、1280×720 / 1920×1080 两种尺寸的完整检查。

复核步骤：
1. 关闭旧游戏，再双击 `run_graybox.bat`；初始弹量应为 30/90。
2. 左键单发/按住连射；用右键 ADS，Shift 时 ADS 应退出。
3. 对左侧青靶射击，生命每次有效命中减少 25；实墙后的靶子必须绕开墙才能命中。
4. 打 10 发，确认 20/90；按 R，约 2.2 秒后应为 30/80。换弹时连续按 R 或开火不应增加弹药或产生伤害。换弹结束后仍按住左键则恢复自动射击。
5. 弹仓/库存为零时不能凭空发弹或补弹。满弹仓 R 无操作。
6. Esc 释放鼠标，点击右上角 Reset test；应恢复 30/90、靶子 100 HP，且取消旧换弹。左键返回鼠标捕获。

## D 未验证项与资源占位

- 当前没有真实武器模型、敌人模型、音效、枪口特效或正式 HUD；全部灰盒已声明。`data/asset_registry.json` 中缺失的 GLB 仍标为 missing。
- 轻微固定视角后坐和固定 seed 的散布用于原型验证；未做手感调优或复杂动画。
- 未做 RTX2060 的 5 分钟性能实测，无 FPS 达标结论。
- 自动测试检查真实物理查询，不能代替完整 GUI 操作验收。

## E 下一任务闸门

TASK-002 已实现且自动检查通过；GUI 剩余项确认前保持待验收。当前不放行 TASK-003，不自行进入 80m 关卡开发。
