# TASK-007 — 多关卡最小骨架

日期：2026-10-29（Asia/Shanghai）。用户要求按已讨论路线继续，当前只执行 TASK-007。
Godot 实测：4.7.2.stable.official.ed1daf0bf；控制台程序 `C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。
当前目录已有工程和灰盒/音频资源；未清空或覆盖原关。`git status --short` 仍报 not a git repository，无可用分支、diff 或提交。中断后的审计未发现既有 TASK-007 实现。

## A 修改文件清单

- 新增 `tasks/TASK-007.md`：授权范围、实施计划、验收命令和人工闸门。
- 新增 `data/campaign.json`、`scripts/game/level_catalog.gd`：线性关卡目录、起始/下一关、唯一ID、场景资源、遭遇需求、环路/可达性检查。
- 新增 `scripts/game/campaign_session.gd`、`scenes/game/Campaign.tscn`：唯一当前关、加载互斥、过渡/错误/重试UI、预备关卡所有权、旧关/音频释放、关闭时取消预备实例。
- 新增 `scripts/tools/build_campaign_levels.py`，生成 `scenes/levels/campaign/Entry.tscn` 与 `Yard.tscn`：两个约24/27米推进的短灰盒验证关，每关单敌，固定实体路/墙/掩体、预摆蹲伏遮挡敌人、触发/终点；复用原模块和玩家/敌人资源。
- 小改 `scripts/game/game_flow.gd`：可选session/关名/本关遭遇、下一关、当前关重试及退出通知；原独立场景无session仍可重开。
- 小改 `scripts/ui/weapon_hud.gd`、`scenes/weapons/WeaponHUD.tscn`：显示关名、胜利下一关、末关完成；终局说明不再写死三场遭遇。
- 小改 `scripts/fx/battle_presentation.gd`：两个构造出的特效容器在 _init 就归属父节点，修复离树候选场景释放时的孤儿；未改音量、伤害或射击逻辑。
- `project.godot` 默认入口改为 Campaign；原80米/20米场景原位保留。`run_graybox.bat` 无需修改。
- 新增 `tests/test_campaign.gd`、`tests/test_campaign_close.gd` 和 Godot UID；测试先红后绿，保留失败诊断。
- 更新 README、PRD扩展说明、架构/QA/路线/决策/后续设计，`scripts/validate_docs.py` 增加第三个JSON合同；本记录及真实日志/截图。
- 玩家、武器、AI 实现、原80米布局/导航和原测试断言未修改；本轮没有正式新美术或新音频。编辑器可能生成参考图 PNG 导入侧车，它们不属于游戏模型。

## B 已执行检查和真实结果

命令均在项目根目录执行，下表 godot 使用上述完整路径。

| 命令 | 最终结果与证据 |
|---|---|
| `godot --version` | 4.7.2.stable.official.ed1daf0bf |
| `git status --short` | 非 Git 仓库，无法提交/比对Git diff |
| `python scripts/tools/build_campaign_levels.py` | 退出0，两短关；TASK-007-bake.txt |
| `godot --headless --editor --path . --quit` | 退出0；TASK-007-import.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_campaign.gd` | 50 PASS，0 failures，退出0；TASK-007-tests.txt |
| `godot --audio-driver Dummy --path . --script res://tests/test_campaign.gd -- --render-checkpoints --measure-performance` | 55 PASS，0 failures，退出0；TASK-007-render.txt；真实Windows图形，无fixed-fps |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_campaign_close.gd` | 退出0；预备实例已存在且5个空间音频活动时关闭；TASK-007-close.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_game_flow.gd` | 44 PASS；TASK-007-flow-regression.txt |
| 同参数运行 `test_level.gd` | 40 PASS；TASK-007-route-regression.txt |
| 同参数运行 `test_level_runtime.gd` | 30 PASS；TASK-007-seed-regression.txt |
| 同参数运行 `test_enemies.gd` | 46 PASS；TASK-007-ai-regression.txt |
| `godot --headless --audio-driver Dummy --path . --script res://tests/test_weapon.gd` | 30 PASS；TASK-007-weapon-regression.txt |
| `godot --headless --audio-driver Dummy --path . --quit-after 120` | 退出0；TASK-007-smoke.txt |
| `python scripts/validate_docs.py` | 退出0，23主文档/任务 + 3 JSON；TASK-007-docs.txt |

50项主测试覆盖：目录/重复ID/不存在资源/下一关/环路/起点/重复遭遇拒绝；缺组件PackedScene在ready前拒绝；两关真实玩家射线击败敌人并实体走入终点；首关Next按钮；重复next/retry互斥；跨关HP100/30-90；运行中不能跳过；第二关失败/当前关重试；末关无下一关；未知id保留当前关；四次重开与四次A/B装卸；暂停重试；错误结构保留当前关并可修正恢复；缺失目录不生成关卡。

图形测试记录 load_count=13；同关重开节点数稳定170，group中只有一个game_flow和一个battle_presentation，旧关及音频节点WeakRef失效。单点 static_memory_bytes=77975501（含渲染/资源缓存），不是内存上限或长期泄漏证明。关闭中途的预备关卡也正确释放。

保留的历史诊断：

- TASK-007-red.txt：实现前测试按预期退出1，缺少实现。
- TASK-007-lifecycle-diagnostic.txt：初次测试用1800逻辑帧等待，fixed-fps过快而尚未跨过真实250ms音频清理期限，造成级联失败；改为真实墙钟5秒截止，不删除断言。
- TASK-007-close-diagnostic.txt：verbose定位两个未归属父节点的Node3D，源于离树候选中的特效容器；_init归属修复后，最终close与主测试无泄漏。不能把这些历史失败文件当最终通过证据。
- 最终tests/render/close/import/smoke及五份regression日志未检出 ERROR、SCRIPT ERROR、FAIL、leaked 或资源残留提示。预期坏配置显示 Campaign load rejected 并由测试检查，未静默跳关。

性能仅为本机 AMD Radeon(TM) Graphics、Windows/Vulkan Forward+、1280×720 Medium 的短时空闲视点墙钟采样：每关预热60帧、采样180帧。

| 视点 | 中位帧时ms | P95 ms | 最差ms |
|---|---:|---:|---:|
| 街口起点 | 6.968 | 7.772 | 8.347 |
| 院落起点 | 6.850 | 8.168 | 10.035 |

本次图形记录首关加载74.509ms，首次切关301.586ms（包括有界音频清理）；这是小灰盒加载，不保证正式资产加载速度。重复装卸没有节点累积，短测未见长冻结；未做旧版同场景帧时A/B、RTX2060或5分钟全战斗验收，不宣称目标帧率达标。

## C 图形与人工操作验收

实际 viewport 截图：TASK-007-entry-start.png、TASK-007-first.png、TASK-007-yard-failed.png、TASK-007-final.png、TASK-007-load-error.png；已复查中文菜单、按钮和关卡身份，无可见越界。图形脚本经过真实物理与武器流程，不能算用户人工操作。

另以普通默认入口启动窗口（TASK-007-window.txt），Computer Use两次报 failed to activate captured window；未发送键鼠，故实际系统窗口点击/键鼠/听音未验收。自动音频使用Dummy，不代表真实听感。

人工步骤：

1. 关闭旧窗口，双击 `run_graybox.bat`，看到“01 / 街口验证关”、HP100、30/90。前进越过青线激活敌人，清除后进入绿色终点线。
2. 胜利点“下一关”，应到“02 / 院落验证关”；HP/弹量重新100/30-90，只有本关一名敌人。
3. 第二关死亡后“重新开始”仍留在第二关；Esc暂停后重开也仍留在第二关。不能回到第一关或残留暂停。
4. 第二关清场抵达终点显示“验证战役完成”，不出现下一关；重开重试第二关。退出程序再启动回第一关，本轮无磁盘存档。
5. 原80米回归场在编辑器打开 VerticalSlice01.tscn 按F6运行，三场战斗及F3/F4仍有效；新短关没有装饰/seed调试层。

## D 未完成问题/依赖

- 当前只完成多关骨架，两个短关仍是灰盒，不是用户参考图的正式主街/市场/工地，敌人/第一人称枪械仍占位。
- 2026-10-29 用户明确回复“验收通过”，人工验收通过；此前窗口自动化失败记录保留，不将其改写为代理操作成功。
- 未实现关卡选择/存档/检查点/无缝加载。画质仍按关重置Medium；关间生命/弹量不继承。
- 未做RTX2060长测或正式资产预算验证。没有本轮新增资源需求，继续遵守用户Tripo/混元3D与Blender协作合同。
- 无Git仓库，不能提供提交或Git差异。本轮对共享代码的改动经原回归检查，未大规模重写。

## E 下一个允许开始的任务

TASK-007 实现、自动/图形检查及用户人工验收通过。下一张允许开始的任务为 TASK-008：20–30米写实样板及首批具体资产制作单/参考图提示词。本次仅记录验收，未开始 TASK-008。
