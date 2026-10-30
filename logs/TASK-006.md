# TASK-006 — 模块化场景生成与资源替换接口

日期：2026-10-28；前置 TASK-005 已由用户明确确认“已测试，验收合格”。
Godot 实测 4.7.2.stable.official.ed1daf0bf；程序路径 `C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。
Git 审计仍报 not a git repository；无法列出 Git diff 或提交，未初始化或覆盖现有工程。

## A 修改文件清单与范围

- 新增 `scripts/game/level_runtime.gd`：结构化数据/源 hash 校验、独立 seed RNG、仅重建无碰撞装饰层、核心改动拒绝、缺失模型汇总。
- 新增 `scripts/game/asset_visual_slot.gd`：从 registry 载入 ready GLB，缺失/不合规回退灰盒；拒绝含脚本/碰撞的模型；原碰撞/Marker 保留，重复替换不累积节点。
- 新增 `scripts/game/level_debug.gd`、修改 `project.godot` InputMap：F3 静态盒碰撞/Area/固定标记/seed；F4 装饰显示。默认关闭且调试几何首次开启才创建；不改变真实碰撞。未绘制角色胶囊或 AI 视锥。
- 修改 `scripts/tools/build_vertical_slice.py`：增加写入前的 80m 配置校验；抽取道路，添加各模块 VisualSlot，生成两个无碰撞装饰模块。
- 重烘焙原 8 个场景：VerticalSlice01、Residential、Shopfront、Ruin、HighWindowFacade、ConcreteLowWall、JerseyBarrier、WoodenCrates；新增模块 RoadStrip、FacadeAC、FacadeVent，共 11 个。
- 修改 `data/vertical_slice.json`（装饰合同/数据状态）、`data/asset_registry.json`（空调/百叶槽位仍 missing）。固定起终点、三遭遇、掩体和导航未改变。
- 新增 `tests/test_level_runtime.gd`、`tests/fixtures/generate_visual_fixture.py`、真实 `visual_only.glb` 及 Godot 导入/UID 侧车。GLB 是测试专用原创盒体，不是正式美术。
- 更新 README、架构/关卡/资产/QA/决策文档、TASK-005 验收状态，新增 `docs/10_ASSET_HANDOFF.md`（资源接入及与用户的建模协作方式、可选首批参考图提示词），本记录及原始日志/截图。
- 玩家、武器、AI 实现与现有测试断言未修改；不扩展 500m、存档或骨骼资产系统。

实施顺序：审计/依赖核对 → 保留静态核心并抽取道路 → 配置与 seed 装饰 → 独立外观接口 → 调试层 → 真实 GLB/多 seed/无重复检查 → 通路和战斗回归 → 图形/性能短测 → 文档。

## B 真实命令及结果

以下 godot 使用上述绝对程序路径，工作目录为项目根目录。

| 命令 | 最终结果/证据 |
|---|---|
| `git status --short` | 非 Git 仓库，无可用 diff |
| `godot --version` | 4.7.2.stable.official.ed1daf0bf |
| `python tests/fixtures/generate_visual_fixture.py` | 生成真实 932 字节 glTF2 GLB，无第三方素材 |
| `python scripts/tools/build_vertical_slice.py` | 退出 0，11 场景；TASK-006-bake.txt |
| `godot --headless --editor --path . --quit` | 退出 0，TASK-006-import.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_level_runtime.gd` | 30 PASS / 0 failures，退出 0；TASK-006-tests.txt |
| `godot --audio-driver Dummy --path . --script res://tests/test_level_runtime.gd -- --render-checkpoints` | 32 PASS / 0 failures，退出 0；TASK-006-render.txt；真实渲染非 fixed-fps |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_level.gd` | 40 PASS，退出 0；TASK-006-route.txt；实体步行 1232 步，到 z=-77.90866 |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_game_flow.gd` | 44 PASS，退出 0；TASK-006-flow.txt；真实三场战斗/装填/伤害/胜负/重开 |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_enemies.gd` | 46 PASS，退出 0；TASK-006-ai.txt |
| `godot --headless --audio-driver Dummy --path . --script res://tests/test_weapon.gd` | 30 PASS，退出 0；TASK-006-weapon.txt |
| `godot --headless --audio-driver Dummy --path . --quit-after 120` | 退出 0；TASK-006-smoke.txt |
| `python scripts/validate_docs.py` | 最终结果见 TASK-006-docs.txt；仅文档检查 |

模块测试覆盖非法 seed/轴向/边界/目标/挂点/重复 ID/预算拒绝；同 seed 清单完全相等；20 seed 核心 Marker/实体碰撞/数量不变；无装饰物理体；重复重建无节点累积；缺失 fallback 不破坏已有层；核心变更需离线重烘焙；仅编辑 registry 导入真实 GLB；隐藏灰盒外观同时仍被真实武器层射线阻挡；重复替换无累积；缺失 GLB 恢复灰盒；F3/F4 与 Godot KEY_F3/F4 实值对应。

首次调试标签测试发现 JSON 数值字符串 20261027.0 与 HUD 整数 20261027 不一致，改为按整数语义断言，保留原检查目的。截图复查发现所有 Marker 文字过大、包含枪口挂点，修正为只标关卡固定 Marker、降低字号投影并限制 30m 显示距离；最终截图已复查。最终文本证据未检出 ERROR、SCRIPT ERROR、FAIL 或 leaked。

本机 Windows Vulkan Forward+ / AMD Radeon(TM) Graphics，1280×720 Medium；同一固定视点装饰关/开/关，每组预热 60 帧、墙钟采样 180 帧：

| 装饰 | 中位帧时 ms | P95 ms | 最差 ms |
|---|---:|---:|---:|
| 关 | 6.962 | 7.695 | 8.594 |
| 开（默认 11 件） | 6.917 | 7.867 | 19.014 |
| 关 | 6.909 | 7.867 | 11.530 |

测试已创建的调试节点保留但隐藏，三组节点总数均 812。这只比较装饰绘制开销，观察到无明显持续回退；不代表完全移除生成系统的旧版本对比，不是全程战斗、五分钟或 RTX2060 目标达标证据。

## C 图形与人工操作验收

真实 viewport 截图：TASK-006-debug.png、TASK-006-street.png。图形脚本验证调试动作与装饰开关并截图；正常游戏窗口也已启动。Windows UI 观察时目标被其他前台窗口遮挡，未发送系统按键；实际前台 F3/F4 按键仍待用户确认，没有记录或保存其他应用内容。

1. 关闭旧版本窗口，双击 `run_graybox.bat`。应有空调/百叶灰盒装饰，主路和三场战斗保持原样。
2. 前台按 F3：显示 seed=20261027、默认装饰 11/24、缺失 GLB 9、配置错误 0，并看到青/橙色盒线和绿色关卡 Marker；再按 F3 关闭。F4 只切换装饰，路障碰撞、敌人和通关保持有效。
3. Esc 暂停/继续与原有射击、装填、三敌清场、终点胜利/重开正常。重开应复现同样装饰。
4. 要比较 seed，在 Godot 编辑器给 LevelRuntime.seed_override 设其他非负整数，保存并 F6；主路/掩体/敌人与触发不移动。设回 -1 恢复 JSON seed。若改 JSON，先运行烘焙命令再启动。
5. 正式 GLB 到位后按 `docs/10_ASSET_HANDOFF.md` 接入，逐件人工核对尺寸、轮廓/真实碰撞和贴图。测试盒体不可当正式资源。

## D 未验证项/依赖

- 正式模型仍 missing，本轮只验证替换接口，未制作或采购商业美术、骨骼动画。声音沿用 TASK-005 原创合成占位。
- 用户 Tripo/混元3D + 本机 Blender 的资产协作偏好已写入交付文档并按用户要求保存为长期偏好。本轮未调用 Blender，也未核验用户报告的 5.2.3。
- 前台物理 F3/F4、全程人工战斗与实际听音待本轮用户复核。脚本图形和先前 TASK-005 用户验收不能冒充本轮人工结果。
- 缺少 RTX2060 五分钟性能数据；短测没有达标声明。修改核心几何后仍需重烘焙导航并重新验通路，不允许用装饰 seed 修改核心。
- 无 Git 仓库，无法提交/提供差异基线。

## E 下一任务

TASK-006 实现及可用自动/图形检查通过，等待人工验收。当前 tasks 仅定义 TASK-000 至 TASK-006，没有可直接执行的 TASK-007。验收通过后再按用户选择，把首批正式美术制作/接入拆成独立任务；不自动扩展游戏。
