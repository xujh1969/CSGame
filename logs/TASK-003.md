# TASK-003 — 80 米灰盒街段和掩体

2026-10-28 用户反馈“一切正常，继续开发”，据此将 TASK-003 走测记为用户确认，并开始 TASK-004。以下保留本代理当时的实际验证边界。

日期：2026-10-28（Asia/Shanghai）。引擎：4.7.2.stable.official.ed1daf0bf。
项目：`C:\Users\AYOU\Desktop\CS`。仍非 Git 仓库，`git status` 报 not a git repository，无法给出提交或 Git diff。

## A 修改文件清单

- 新增 `scenes/levels/VerticalSlice01.tscn`：约 80m 连续街道、实体地板与边界、路面/人行道、街角、高窗、窄路段、3 个 SpawnMarker、3 个触发区、终点 Marker/Area 和可复测路线点。
- 新增 `scenes/levels/modules/{Residential,Shopfront,Ruin,HighWindowFacade}.tscn`：住宅阳台、商铺雨棚、破损立面、真实开洞高窗。左右各含至少 3 类构成。
- 新增 `scenes/cover/{ConcreteLowWall,JerseyBarrier,WoodenCrates}.tscn`：独立可替换灰盒接口，内含匹配可见盒体的静态碰撞。
- 新增 `scripts/tools/build_vertical_slice.py`：离线读取 JSON、显式 seed 和源文件 hash，烘焙以上 8 个可编辑场景。游戏运行时不执行该脚本。
- 新增 `tests/test_level.gd` 和 Godot 生成的 `.gd.uid`：点位、通口、掩体射线、窗洞/平台和真实玩家物理步行检查；可选保存渲染检查点。
- 修改 `project.godot` 主场景指向新街段；现有 `run_graybox.bat` 无需改动。
- 修改 `data/vertical_slice.json` 的 E01 脚点 y=0.08，匹配人行道高度；修改 `data/asset_registry.json` 登记灰盒替代场景，正式 GLB 仍 missing。
- 更新 README、关卡/决策文档、TASK-002 用户授权记录及本日志；新增基线 hash、真实检查输出与 5 张引擎渲染 PNG。
- 新增 `logs/.gdignore`，使证据截图不会被当成运行资源导入。

原 `scenes/main.tscn`、玩家/武器/UI 实现及原武器测试不改动，10 个基线文件以 SHA256 比对验证。基线见 `TASK-003-baseline.json`。

## B 已执行检查及真实结果

引擎完整路径：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。

| 命令（godot 使用上述完整路径） | 结果/证据 |
|---|---|
| `python scripts/tools/build_vertical_slice.py` | 写入 8 个静态场景，seed=20261027；重复烘焙的文件哈希比对见 final-audit |
| `godot --headless --editor --path . --quit` | 退出 0，无解析/脚本错误；`TASK-003-import.txt` |
| `godot --headless --path . --fixed-fps 60 --script res://tests/test_level.gd` | 40 项 PASS，failures=0；`TASK-003-tests.txt` |
| `godot --path . --fixed-fps 60 --script res://tests/test_level.gd -- --render-checkpoints` | 开启真实 Forward+ 图形渲染，重复关卡检查并保存 5 张检查点；`TASK-003-render-walk.txt` |
| `godot --headless --path . --script res://tests/test_weapon.gd` | 原武器 30 项 PASS，failures=0；`TASK-003-weapon-regression.txt` |
| `godot --headless --path . --quit-after 120` | 退出 0，默认新街段成功运行；`TASK-003-smoke.txt` |
| `python scripts/validate_docs.py` | 文档/JSON 检查；`TASK-003-docs.txt` |

步行使用原玩家的 move_player / move_and_slide 和真实物理碰撞，不瞬移、不跳跃，从 (0,0,4) 沿 9 个路线点走至约 (0.000081,0.000838,-77.90866)，1232 个固定物理帧后进入 FinishArea。此帧数是模拟步行步数，不是 FPS 性能测量。

检查还确认：源 JSON 的 seed/hash、出生与终点坐标一致；3 个 SpawnMarker 及 Trigger 与数据一致；3 个脚点均在实体支撑表面；左右各 3 类立面；3 类掩体阻挡最近射线；高窗平台高度 4.2m、窗洞上身视线可通；街角翼墙和第三点位低墙提供真实遮挡；每隔 0.2m 以直径 1.2m 胶囊检查全通路无重叠。

## C 图形运行和人工操作验收

已启动真实 Windows 游戏窗口，查看起点街道、建筑、光照与武器 UI，并尝试 W 键。单次短按不足以独立确认整段人工走测，故不将其等同于完整人工验收。

另外启动非 headless 的自动物理步行，使用实际渲染器导出当前游戏视口：

- `TASK-003-start.png`：起点与住宅街纵深。
- `TASK-003-corner.png`：街角翼墙。
- `TASK-003-window.png`：真实开洞高窗与平台。
- `TASK-003-crates.png`：木箱组与窄路段。
- `TASK-003-finish.png`：终点标志和绿色终点线。

这些是引擎运行中的视口截图，不是概念图；自动步行与截图不能替代完整键鼠人工走测。

本机复核：关闭旧窗口，双击 `run_graybox.bat`；沿 -Z 方向经过住宅/街角、商铺/高窗、窄路/木箱，绕过左右掩体，走到绿色 FINISH 线。原 WASD、Shift、Space、Ctrl、鼠标、射击和换弹保留。对掩体射击时 Impact 应显示实体掩体；编辑器打开 VerticalSlice01 查看 SpawnMarkers、Triggers 和 FinishArea。原 20m 武器测试场仍可打开 `scenes/main.tscn` 按 F6 运行。

## D 未完成项 / 依赖 / 占位

- 人工完整走测与 1080p 布局尚未独立完成；图形运行/截图使用 1280×720、本机 AMD 集成显卡 Forward+。
- 敌人仍只有 Marker，无 AI、生成、遭遇状态或动态开火；触发区不激活敌人，终点不触发胜利。这些分属后续任务。
- 所有立面、掩体、武器均为内建盒体灰盒；无真实 GLB、纹理或音效，没有伪造资产完成状态。
- 没有 RTX2060 的 5 分钟实测、1% low 或最大帧时间，无性能达标结论。
- 数据坐标 z=4 到终点 -78；道路主设计段为 z=0 到 -80。地板覆盖 z=8 到 -84，是安全余量。

## E 下一任务闸门

TASK-003 的实现、关卡自动检查与武器回归已完成；完整人工走测仍待确认。在当前任务获得验收前，不自行进入 TASK-004。
