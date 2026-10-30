> GitHub 上传说明：当前工程位于 `task-009-rig-diagnostics` 分支，TASK-009 双手/诊断尚未验收；`main` 暂仅放仓库说明与 Git 配置，未合并未验收游戏修改。克隆后切换该分支，并执行 `git lfs pull` 获取模型和源文件。项目约 3.2GB（不含 Godot 缓存），原始高模与 Blender 源文件使用 Git LFS。

# 城市巷战 FPS · Codex 开发文档包 v1.0

## 当前本机工程（TASK-008，人工验收通过）

TASK-009电影镜头与枪械样板进行中，尚未获得本轮人工验收。双击 `run_cinematic_sample.bat` 运行独立样板（默认战役和已验收 TASK-008 保留）。当前采用 AR-15-1 用户枪模、独立弹匣与透明瞄具；新交付杂物按13个独立堆体接入。双臂已换用下载的 `hand_with_gloves.glb` 派生模型，保留原权重、手指骨骼和PBR材质；持枪和左侧换弹路径仍在视觉校准。骨长/动画检查通过不能代表握持正确。原件及前版派生资源均保留。诊断流程见 `docs/11_FPS_RIG_DIAGNOSTICS.md`，历史记录见 `logs/TASK-009-v004.md`；完整人物影子仍未实现。

TASK-008 环境样板v003已于2026-10-29获用户人工验收通过：关闭旧样板窗口后，双击 `run_art_sample.bat` 单独运行24米材质/灯光样板，标题应为“TASK-008 Sample v003”；不影响下面两关默认入口。已补三面阳台围栏、成簇碎石杂物、烟柱/浮尘/火光与分档体积薄雾，并接入用户混元3D废弃汽车：9,614三角面低模、四张2K高模烘焙贴图、车身/车舱凸碰撞。两份原文件保留，高模不在运行时加载。本次验收范围为24米环境样板；下一张允许开始TASK-009。游戏截图/实测见 `logs/TASK-008.md`，来源与制作单见 `docs/asset_requests/TASK-008_FIRST_BATCH.md`。

双击根目录 `run_graybox.bat` 启动两关灰盒验证流程，默认入口为 `scenes/game/Campaign.tscn`：街口 → 院落。每关预摆一名敌人，清除后进入绿色终点线；首关胜利可点“下一关”，最后一关显示“验证战役完成”。失败/暂停/胜利重开均只重试当前关，跨关恢复 HP100、30/90。
原80米 `scenes/levels/VerticalSlice01.tscn` 保留，可在编辑器打开后按 F6 独立运行。
原 20 米武器测试场 `scenes/main.tscn` 保留，可在编辑器打开后按 F6 运行。
80米场含三名敌人；本轮两关仅用来验证切关和生命周期，不是参考图对应的正式关卡。Esc 暂停，菜单可继续、重开或选择低画质。模型仍为灰盒，声音为原创程序合成占位。
TASK-005 已由用户确认人工验收通过。TASK-006 增加固定核心 + seed 装饰、GLB 外观替换接口；F3 显示碰撞/关卡标记/seed，F4 切换装饰显示（均不改变物理碰撞）。
F3/F4 已获用户确认，仅用于原80米回归场；新增短关暂不带装饰/seed调试层。TASK-007 不做关卡选择或磁盘存档，退出后再启动从第一关开始。
修改 `data/vertical_slice.json` 后运行 `python scripts/tools/build_vertical_slice.py` 再启动；只测试其他装饰 seed 可在编辑器设置 LevelRuntime.seed_override，-1 使用 JSON seed。
当前证据见 `logs/TASK-007.md`；短关烘焙命令为 `python scripts/tools/build_campaign_levels.py`，关卡顺序由 `data/campaign.json` 定义。模型交付与替换步骤见 `docs/10_ASSET_HANDOFF.md`。下述文档包原始说明不等于当前所有任务已完成。

> 状态：设计与实现合同（**并非已完成的 Godot 游戏**）。适用：Windows 单人 FPS、Godot 4.7.x（如项目机器版本不同，在 TASK-000 审核并锁定当前 4.x 稳定版本）、GDScript、离线开发。

## 先做什么
1. 将本包所有文件复制到**现有 Godot 工程根目录**（如果还没有工程，新建一个空目录并将本包置入）；不要覆盖已存在的 `AGENTS.md` / `docs` / `tasks`，先手工合并。
2. 初始化 Git，执行 `git status`，确认基线和未提交改动。引擎版本、项目状态、资源情况以实际检测为准。
3. 在 Codex 中打开项目根目录，把 `PROMPT_FIRST_RUN.md` 的文字发给 Codex，**只执行 TASK-000**。
4. TASK-000 验收后，按 `docs/08_ROADMAP.md` 顺序一次执行一张 TASK。每张任务结束检查验收记录、截图、运行日志及 Git diff。
5. 不要把这里的概念图误认为已存在的 GLB、角色骨骼或者可用动画。

## 文档索引（按执行优先级）
| 文件 | 职责 | 谁使用 |
|---|---|---|
| `AGENTS.md` | Codex 每次操作都遵守的红线与完成定义 | Codex 必读 |
| `docs/00_PRD.md` | 产品目标、范围、玩家体验、第一版完成定义 | 产品 + Codex |
| `docs/01_ARCHITECTURE.md` | Godot 场景树、模块边界、信号与数据约束 | Codex |
| `docs/02_LEVEL_DESIGN.md` | 80m 纵切片、5 区段路线和场景变化规则 | 关卡 + Codex |
| `docs/03_ASSET_PIPELINE.md` | 3D 拆分粒度、GLB/骨骼/材质/碰撞标准 | 建模 + Codex |
| `docs/04_GAMEPLAY.md` | 移动、武器、伤害、掩体、数值初稿 | Codex |
| `docs/05_AI.md` | 敌人状态机、生成约束和行为边界 | Codex |
| `docs/06_PRESENTATION.md` | HUD、音效、烟尘、爆炸表现及性能档位 | 美术 + Codex |
| `docs/07_QA_PERFORMANCE.md` | 自动化 + 实机验收用例、性能指标 | QA + Codex |
| `docs/08_ROADMAP.md` | 小任务顺序、里程碑和停工条件 | 项目管理 |
| `docs/09_DECISIONS_RISKS.md` | 已确定与未确定事项、易踩的坑 | 全员 |
| `tasks/TASK-*.md` | 一次交给 Codex 的独立、可验收任务 | Codex |
| `data/vertical_slice.json` | 80 米切片的数据示例（不是游戏资源） | Codex |
| `data/asset_registry.json` | 资产槽位合同（并不意味着文件已经存在） | Codex |
| `templates/TASK_TEMPLATE.md` | 未来扩展任务的标准格式 | 你 / Codex |
| `scripts/validate_docs.py` | 文档/JSON 的基础一致性检查 | 本地 |

## 两条推荐路径
- **已有 Godot 工程**：保留原有项目、检查兼容性，在分支上开发，严禁清空重建。TASK-000 先审计，再进行最小改动。
- **空目录新项目**：TASK-000 创建可打开的 Godot 项目及灰盒测试场景。

## 核心原则
**先能玩再写实；先 80 米战斗切片再扩展 500 米；先占位资源再替换 GLB；先验证再进入下一任务。**

## 本包不提供的东西
- 不包括已绑定骨骼的敌人模型、动作动画、武器模型、PBR 材质贴图或爆炸音效的商用授权。
- 不包含可运行游戏项目、实际 FPS 性能测量结果或 Codex 执行结果。必须由你的本地 Godot + Codex 开发验证。

## 资料依据
- Codex `AGENTS.md`：https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Codex 最佳实践：https://learn.chatgpt.com/docs/learn/best-practices
- Godot 4.7 及支持策略：https://docs.godotengine.org/en/stable/about/release_policy.html
- Godot GridMap：https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html

自动诊断测试场：`debug/fps_rig_test.tscn`，F9 导出同帧 JSON/PNG。默认静态候选尚未验收；`--legacy` 记录旧版问题，`--candidate` 记录掌面 Marker 求解版。工具测试通过不等于模型视觉通过。
