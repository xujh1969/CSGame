# TASK-007 | 多关卡最小骨架

2026-10-29：用户要求按 docs/11_NEXT_PHASE_DESIGN.md 继续，授权本任务；只执行这一张。

验收状态：2026-10-29 用户明确回复“验收通过”，TASK-007 人工验收通过。

## Goal / Architecture
新增两个短灰盒验证关，通过 JSON 关卡目录和独立 CampaignSession 串联。关内复用 GameFlow/EncounterManager，关间只保存当前关 id，不保存玩家/敌人节点。原80m及20m场景保留独立运行。

## Scope
- 关卡目录校验：唯一 id、场景存在、必需遭遇、下一关引用/环路。
- A→B、当前关重玩/失败重试、最后一关完成；重复点击只能提交一次切换。
- 关间恢复 HP100、30/90，释放旧关节点/音频并清理暂停状态；显示关名/加载状态/错误。
- 默认入口改为两关验证流程；两个关均可真实行走、战斗和到达终点。

## Out of Scope
正式三关地图、美术/新人物、关卡选择、磁盘存档、关内检查点、无缝流式加载、多武器。

## Files
新增 data/campaign.json、scripts/game/level_catalog.gd、scripts/game/campaign_session.gd、scenes/game/Campaign.tscn、scenes/levels/campaign/*.tscn、scripts/tools/build_campaign_levels.py、tests/test_campaign.gd。
小改 GameFlow、WeaponHUD 脚本与场景及 project.godot 主入口；更新 README/架构/QA/路线/决策和 logs/TASK-007.md。不改玩家/武器/AI 实现。

## Implementation Plan
使用 writing-plans；本目录任务卡作为计划位置，按仓库一次一张TASK约定执行。Godot 4.7.2/GDScript，不引入第三方依赖。无 Git 仓库，因此不能创建工作树或提交。

1. [x] 目录/生命周期测试先行：验证坏配置、切换互斥、独立关卡实例；先运行观察缺少实现的失败。
2. [x] 实现 LevelCatalog 的 JSON 校验；CampaignSession 只管理加载、卸载、目录与过渡 UI，不包含战斗逻辑。
3. [x] 用工具生成两个短关：固定路/掩体、预摆且被掩体遮挡的单敌、触发/终点；复用当前资源。
4. [x] GameFlow 增加可选 session/level_title；独立场景仍使用原重开。HUD 增加下一关和最终关文字，保留暂停/失败/原回归入口。
5. [x] 测试真实射线杀敌+物理走到终点、A→B、B失败重试、最终关无下一关、多轮重开/旧对象释放/音频收尾；恢复原回归检查。
6. [x] 真实图形截图与可用窗口交互、记录节点/内存及时间；更新文档，报告未验证项，不把fixed-fps当性能。窗口激活失败，未宣称人工按键通过。

## Acceptance / Commands
- [x] 两关均可从启动到终点获胜，首关可进入下一关，末关不显示下一关（图形脚本验证）。
- [x] 失败/暂停重试只重建当前关；HP/弹药/遭遇恢复，暂停状态正确；用户已确认人工验收通过。
- [x] 快速重复请求不重复加载；多轮切换旧对象和声音不残留。
- [x] 无效目录/场景/遭遇关系明确失败，不破坏当前关或静默跳关。
- [x] 原80m战斗/通路/seed与原武器/AI回归通过。
- [x] 导入无错误，图形/人工结果与未验证项分别记录。

命令（godot 使用本机已核对完整程序路径）：
`python scripts/tools/build_campaign_levels.py`
`godot --headless --editor --path . --quit`
`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_campaign.gd`
图形：去掉 headless，末尾加 `-- --render-checkpoints`。
回归：相同参数分别运行 test_game_flow.gd、test_level.gd、test_level_runtime.gd、test_weapon.gd、test_enemies.gd。
`godot --headless --audio-driver Dummy --path . --quit-after 120`
`python scripts/validate_docs.py`
