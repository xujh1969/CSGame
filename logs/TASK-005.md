# TASK-005 — 完整战斗循环、HUD 与基础声画反馈

日期：2026-10-28（Asia/Shanghai）；Godot 4.7.2.stable.official.ed1daf0bf。
项目仍无 Git 仓库（git status 报 not a git repository），没有伪造提交或 diff。

## A 修改文件清单

- 新增 `scripts/game/game_flow.gd`：进行中、暂停、失败、胜利四状态，帧末互斥结算、场景重开与正常窗口关闭。
- 重做 `scripts/ui/weapon_hud.gd`、`scenes/weapons/WeaponHUD.tscn`：真实生命/弹量/准星、命中/受伤反馈、目标进度及暂停/终局卡片。旧 20m 武器测试场保留重置入口。
- 新增 `scripts/fx/{battle_presentation,impact_fx,muzzle_flash}.gd`、`scenes/fx/{MuzzleFlash,ImpactFx}.tscn`：事件驱动、按法线生成的火花/粉尘/烟、枪口反馈及有并发/听距上限的 3D 音频。
- 新增 `scripts/tools/generate_placeholder_audio.py`、`assets/audio/*.wav` 九个文件及 `PLACEHOLDERS.md`：原创程序合成、无外部采样的占位声音。Godot 生成 WAV 导入侧车与新脚本 UID。
- 修改玩家输入脚本以让 Esc 交给 GameFlow；修改武器控制器仅增加空仓反馈事件/0.2s 空仓点击节流；敌人武器增加真实弹着点事件，未改伤害/射速/命中逻辑。
- 修改离线关卡烘焙工具并重烘焙 8 个场景：加入 GameFlow/BattlePresentation、为已有静态碰撞加 surface_type 标签；路线、掩体尺寸和出生坐标保持。
- 新增 `tests/test_game_flow.gd` 与 `tests/test_window_close.gd`；旧 AI/通路测试显式隔离流程状态，并在退出时等待音频混音清理，原断言保留。
- 更新资产 registry，将真实存在的 9 个 WAV 登记为 ready + placeholder；更新 README、表现/QA/决策文档、本记录和原始输出/截图。

## B 已执行检查和真实结果

引擎路径：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。
最终完整输出保存在同目录 TASK-005-*.txt；命令使用上述完整 godot 路径。

最终结果：流程 headless 44 项、Windows 图形流程 50 项全部通过；武器 30 项、AI 46 项、通路 40 项回归全部通过。导入、启动冒烟、关闭通知及文档检查退出码均为 0。最终 TASK-005 文本证据未检出 ERROR、SCRIPT ERROR、FAIL 或 leaked。图形检查额外确认胜利音效会替换旧战斗声音，不受此前声音并发已满影响。

| 命令 | 证据 |
|---|---|
| `python scripts/tools/generate_placeholder_audio.py` | 生成 9 个 22050Hz 单声道 PCM16 WAV；不是下载或外部素材 |
| `python scripts/tools/build_vertical_slice.py` | 保存 8 个静态编辑器场景，新增流程/表现节点及碰撞表面标签 |
| `godot --headless --editor --path . --quit` | `TASK-005-import.txt`，检查非零退出及 ERROR / SCRIPT ERROR |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_game_flow.gd` | `TASK-005-tests.txt` |
| `godot --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_game_flow.gd -- --render-checkpoints` | `TASK-005-render-flow.txt`，真实图形窗口 |
| `godot --headless --audio-driver Dummy --path . --script res://tests/test_weapon.gd` | 武器 30 项回归；`TASK-005-weapon-regression.txt` |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_enemies.gd` | AI 46 项回归；`TASK-005-ai-regression.txt` |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_level.gd` | 原通路 40 项回归；`TASK-005-route-regression.txt` |
| `godot --headless --audio-driver Dummy --path . --quit-after 120` | `TASK-005-smoke.txt` |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_window_close.gd` | 5 个空间声音活动时派发真实关闭通知，经 GameFlow 收尾退出 0；`TASK-005-close.txt` |
| `python scripts/validate_docs.py` | `TASK-005-docs.txt` |

新测试覆盖：HUD 与真实生命/弹量同步；有效射击产生表现；9 音频流及听距/并发；暂停冻结玩家和装填，恢复后精确完成 20/90→30/80；Low 实际去除烟/粉尘与动态阴影、限制火花；法线外侧弹着；受伤闪红；1080p 菜单边界；未清敌时终点不胜利；同帧死/胜优先失败且只结算一次；终局不能恢复战斗；重试重置生命/弹药/遭遇；用原玩家移动、真实触发/AI/玩家射线完成 80m 三场战斗、装填、进入 FinishArea 获胜和胜利重开。

最初一项鼠标捕获断言在 headless 失败，诊断确认 headless 返回 mouse_mode=0；保留为明确未验证项，由 Windows 图形运行验证 mode=2，不用 headless 假称鼠标捕获有效。

快速测试退出时曾发生 WAV Playback 引用残留，verbose 日志定位到音频服务器异步持有，而非未释放节点。生产关闭路径显式停音，等到 3 次真实混音回调或 250ms 上限；测试退出也使用此边界。本机观测 2–3 个周期后关闭检查退出 0，无资源残留错误。引擎背景参考：[Godot issue #76745](https://github.com/godotengine/godot/issues/76745)。

## C 图形检查与人工操作

图形测试为 Windows / Vulkan Forward+ / 本机 AMD 集显，实际渲染保存：
`TASK-005-hud-720.png`、`TASK-005-pause-720.png`、`TASK-005-pause-1080.png`、`TASK-005-failed.png`、`TASK-005-victory.png`。
截图复查中文可读、菜单不越界；图形运行确认恢复后 OS 鼠标捕获。自动音频验证使用 Dummy，不代表实际听音。

人工复核：关闭旧窗口，双击 run_graybox.bat。Esc 应暂停敌人/移动/装填并显示菜单，再按 Esc 或“继续游戏”恢复；菜单可选择低画质。三名敌人清除前终点不能获胜，清除后进入绿色终点线显示胜利；死亡显示失败；任一终局“重新开始”恢复 HP100、30/90、三名休眠敌人。验证枪声、空间敌方枪声、警戒、步行、空仓、装填、受伤、跳/落地及通关音。

## D 未验证项 / 占位 / 风险

- 模型仍为灰盒，音频为简单原创合成占位，不是商业音效；没有骨骼动画或精细贴图。
- 未做实际耳机/扬声器的听感、声源方位和音量混音验收；未独立完成全程人工键鼠通关。
- 声画自动战斗检查及截图不代替人工操作。Windows 持续按键自动化能力有限，当前输入/战斗人工结果需要用户确认。
- 未做 RTX2060 5 分钟性能实测，不将 fixed-fps 当作实测 FPS；Low 的禁烟尘/阴影与限额有功能测试，但无帧率达标声明。
- 画质选择每次重开默认 Medium；本轮不做设置存档、完整菜单或爆炸破坏。

## E 下一任务闸门

TASK-005 实现与自动验证按本日志记录。2026-10-28 用户明确回复“已测试，验收合格，继续下一步”，人工验收通过，允许开启 TASK-006。
