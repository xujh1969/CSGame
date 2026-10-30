# TASK-008 — v003人工验收通过

2026-10-29（Asia/Shanghai）用户明确回复“验收通过”。本任务关闭，以下实现和检查证据保留；先前“待验收”措辞记录的是验收前状态。此次仅更新验收文档，未修改运行时或重复声明新的游戏测试结果。下一张允许开始的任务为TASK-009，本轮未开始。

2026-10-29。仍只执行TASK-008；以下为当前状态，后面的v002章节保留历史结果。

## A 修改文件清单（v003）

- 新增 scripts/tools/audit_vehicle_delivery.py、prepare_vehicle_asset.py、finish_vehicle_collision.py、register_vehicle_asset.py：只读原件审计、隔离Blender烘焙、车头校正、凸碰撞数据、来源登记；register_sample_assets.py重跑会保留已经ready的真实车辆。
- 新增 assets/models/task008/vehicle_final_v001.glb（9614三角面）、assets/textures/task008/vehicle/四张2K PBR、assets/source/task008/vehicle/VehicleBake_v001.blend（高低模派生副本）；原件两个文件未改字节。FBX新增keep导入侧车，不将约150万面高模导入游戏。
- 修改 scripts/art/street_sample.gd、data/asset_registry.json：真实车型替换代理，底中心原点、1.8×1.5×4.2m、车头-Z，实际低模提取的车身/车舱两段凸碰撞，金属命中表面；保留缺失时代理回退。
- 修改 tests/test_art_sample.gd；新增 tests/capture_vehicle.gd、正反面真实Godot截图和vehicle审计/烘焙/回归日志。更新MCP组装工具，另存StreetReview_v003.blend，保留原默认Scene和v001/v002，13对象、外部贴图无缺失。
- 更新README、任务卡、QA/决策/资产交付文档、PROVENANCE。原默认战役、玩家/枪械/AI没有修改。

## B 已执行检查和结果（v003）

Godot完整路径为 `C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`（4.7.2）；Blender为 `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`（5.2.3 LTS）。以下godot/blender代表该完整路径；cwd为本项目。

| 命令/检查 | 实际结果与证据 |
|---|---|
| `git status --short` | fatal: not a git repository；不能提供Git diff/提交，未初始化 |
| `blender --background --factory-startup --python scripts/tools/audit_vehicle_delivery.py` | 退出0；LP9614面且无UV/材质，HP1499788面、四张内嵌4K贴图；vehicle-delivery-audit.json |
| `blender --background --factory-startup --python scripts/tools/prepare_vehicle_asset.py` | 退出0；实际低模smart UV，Cycles烘焙Albedo/Normal/Roughness/Metallic各2K，未以高模代替低模；vehicle-bake.txt |
| `blender --background --factory-startup --python scripts/tools/finish_vehicle_collision.py` | 退出0；根据实际正反面渲染将派生副本旋转180度为车头-Z，导出两段凸支持点，不重复烘焙；vehicle-collision.txt |
| `python scripts/tools/register_vehicle_asset.py`、重跑register_sample_assets.py并比较车型JSON | 退出0；真实车型ready且不被环境登记脚本重置；v003-registry-preserve.txt |
| `godot --headless --editor --path . --quit` | 退出0；v003-import-final.txt无ERROR；高模FBX无导入产物，只有低模派生GLB用于运行时 |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_art_sample.gd` | 29项PASS，0失败；实际导入9614面/2K PBR、两份原件SHA256、凸形状、车身射线阻挡/车顶上方射线畅通、玩家胶囊阻挡、1.2m全通道、真实实体行走/战斗/终点、Low和重开 |
| 相同headless参数分别运行test_campaign.gd、test_game_flow.gd、test_level_runtime.gd | 50/44/30项PASS，各退出0；v003-test_*.txt |
| `godot --audio-driver Dummy --path . --script res://tests/capture_vehicle.gd` | 退出0；真实正反面渲染可见破损车窗/轮胎/锈迹，已目视检查并纠正车头方向 |
| `godot --audio-driver Dummy --path . --script res://tests/test_art_sample.gd -- --render-checkpoints --measure-performance`，另加`--render-1080`再运行 | 720/1080均退出0，实际窗口截图和墙钟帧间隔短测；不使用fixed-fps做性能结论 |
| `python scripts/validate_docs.py` | 24份主文档/任务 + 4个JSON合同通过；不是游戏验收替代 |

最终增加玩家胶囊碰撞检查后再次执行图形 `--render-checkpoints`：33项PASS、0失败、退出0，见TASK-008-v003-gui-final.txt。所有新增/修改Python工具通过 `python -m py_compile`。

原件SHA256：LP `24a74e143f4b57a1d9f0e9f8a40c3ccfc2596a8a7e846875308766afabca4714`；HP `4ddeb7e3b9dbd7ac47fcdc011ab2d72ec0a9da0fad27a9642d3c62d1083d7851`。烘焙JSON与实际Godot测试均核对未变。

实际AMD Radeon(TM) Graphics、Vulkan Forward+；每档热身60帧/采样180帧，单位ms：

| 分辨率/档位 | 中位 | P95 | 最慢 |
|---|---:|---:|---:|
| 1280×720 Medium | 10.105 | 12.362 | 15.288 |
| 1280×720 Low | 6.871 | 8.432 | 9.723 |
| 1920×1080 Medium | 16.296 | 17.882 | 21.407 |
| 1920×1080 Low | 9.697 | 12.771 | 13.941 |

1080引擎图形内存计数约592.0/577.8MB（Medium/Low，非独立显卡物理显存测量）。短测受缓存/系统负载影响，不与v002直接归因比较，不等于RTX2060/全程长测达标。

首次预览脚本有局部变量类型推断解析错误；首次车型测试使用JSON数组与整型数组比较导致断言失败。均保留first-failure/parse-failure日志；修正显式类型，改测实际导入网格面数和PBR贴图后复验通过。Blender导出有sampler多图像节点警告，未隐瞒；实际GLB导入和四通道贴图检查通过，外观仍待人工评审。

## C 人工操作验收（v003）

关闭旧样板窗口，双击根目录run_art_sample.bat，标题应为TASK-008 Sample v003。沿左侧街道走到车辆旁，观察车头/车尾/两侧、轮胎接地、车窗破损及贴图；车身应挡住玩家和子弹，车顶上方可射过，中央路线可走。Esc切Low，再重开，车辆和碰撞都应保留。继续核对三面栏杆、烟尘/碎石/暖冷光照，并完成原灰盒敌人和终点流程。当前只有脚本驱动的GUI走测，尚未代替用户键鼠/听感/视觉验收。

真实截图：docs/asset_requests/TASK-008/vehicle_runtime_front.png、vehicle_runtime_rear.png；logs/TASK-008-[1080-]start/cover/shop/low.png。图像由Godot实际渲染，不是生成图。

## D 未完成问题/依赖（v003）

车型已收到并接入，无需再次生成。用户确认混元3D，但尚未给出适用的使用条款，当前标注本地样板评估。生成模型内饰/破损细节仍有近似，贴图接缝和目标观感需要近距离人工评审。建筑变化/破损密度和远景细节仍未达到参考图最终质量；敌人/手臂/武器仍为原灰盒。声音仍为程序合成占位，Dummy测试不证明听感；没有目标硬件长测。TASK-008尚未人工验收。

## E 下一个允许开始的任务（v003）

TASK-008已于2026-10-29获用户人工验收通过；下一张允许开始TASK-009，本轮仅登记验收，未开始开发。已有样板范围、灰盒占位、资产条款和目标硬件长测限制继续保留。

---

# v002历史记录（以下“车辆待交付”等描述已由上述v003状态取代）

日期：2026-10-29（Asia/Shanghai）。用户验收TASK-007后授权继续，仅执行TASK-008；尚未进入TASK-009。
本轮用户已实际运行run_art_sample.bat并反馈：阳台缺左右栏杆、光线平实、空气过干净、地面需更多不规则碎石杂物。下述v002包含这些修正，但不等同用户最终视觉验收。

## A 修改文件清单

- 新增 `tasks/TASK-008.md`：范围、计划、验收/未完成项。
- 新增 `scripts/tools/build_sample_assets.py`、`register_sample_assets.py`：隔离Blender生成/导出原创网格、UV、数学PBR微表面，登记真实文件/来源/单位/面数/占位并同步碎块碰撞数据。
- 新增 `assets/source/task008/StreetKit_v002.blend`、`StreetReview_v002.blend`、PROVENANCE.md；v001保留检查点。当前7个GLB模块：residential_v002、shopfront_v001、road_v001、barrier_v001、crates_v001、street_details_v002、vehicle_proxy_v001。原有玩法槽位未替换。
- 新增 `assets/models/task008/*.glb`、`assets/textures/task008/*` 及Godot导入侧车。贴图含原创程序微表面、内置imagegen抹灰Albedo、透明烟精灵；烟图片明确是2D特效，不是模型。
- 新增 `scripts/art/street_sample.gd`、`sample_atmosphere.gd`、`scenes/levels/art/StreetSample.tscn`：继承Entry短关，只替换环境。对双侧立面/掩体/地面应用独立GLB，增加杂物、车辆占位及实体碰撞、暖主光/冷阴影/ACES/局部火光/烟尘/分档体积雾。
- 新增 `data/art_sample_physics.json`，修改asset_registry：当前模块技术ready + sample_art_pending_visual_acceptance，车辆代理placeholder=true，最终车辆仍missing；smoke sprite归类vfx_texture。
- 新增 `run_art_sample.bat`：独立启动样板，沿用既有路径引用方式，默认战役主入口不变。
- 新增 `tests/test_art_sample.gd`、`capture_sample_assets.gd`，模型/引擎真实截图、JSON审计、测试日志；新增MCP组装工具 `assemble_blender_sample_review.py`。
- 新增 `docs/asset_requests/TASK-008_FIRST_BATCH.md` 和车辆单物件参考、7份当前模型预览；源文件/参考图目录.gdignore避免引擎自动导入blend/参考图片。
- 更新README、资产/QA/决策文档、文档检查脚本（4个JSON合同）。玩家、武器、AI及原战役/80m实现未修改；无外部插件。

Blender几何/材质审计为 `TASK-008-asset-audit.json`；当前7种模块合计19,524三角面（实例化重复另计）。residential_v002=3,136；shopfront=1,712；road=1,044；barrier=1,968；crates=3,240；details_v002=8,224；vehicle proxy=200。文件存在不代表已获最终视觉验收。

## B 已执行检查和结果

引擎实际运行Godot 4.7.2.stable.official.ed1daf0bf，程序：`C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`。下表godot均使用该完整路径，cwd为本项目。Git审计仍报not a git repository；无法提交/提供Git diff，未初始化或清空原工程。

| 命令/工具 | 真实结果 |
|---|---|
| `blender --version`（完整路径C:\Program Files\Blender Foundation\Blender 5.2\blender.exe） | 5.2.3 LTS，实际版本已核对 |
| `blender --background --factory-startup --python scripts/tools/build_sample_assets.py` | 退出0，7种GLB和源库；TASK-008-blender.txt |
| `python scripts/tools/register_sample_assets.py` | 实际文件才登记，最终车辆保持missing，生成40块大碎片碰撞数据 |
| Blender MCP execute_blender_code | 初始9876不可达；用户配置后只读实测5.2.3成功，创建独立Review_v002；保留默认场景3对象及v001评审场景，13个当前评审对象、无缺失贴图；TASK-008-mcp-audit.json |
| `godot --headless --editor --path . --quit` | 退出0；TASK-008-import.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_art_sample.gd` | 22 PASS / 0 failures，退出0；TASK-008-tests.txt |
| `godot --audio-driver Dummy --path . --script res://tests/test_art_sample.gd -- --render-checkpoints --measure-performance` | 26 PASS，退出0；TASK-008-render.txt；真实720p窗口，无fixed-fps |
| 上一命令末尾加 `--render-1080` | 26 PASS，退出0；TASK-008-render-1080.txt；1920×1080真实渲染 |
| `godot --audio-driver Dummy --path . --script res://tests/capture_sample_assets.gd` | 7个实际GLB预览save=0，退出0；TASK-008-previews.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_campaign.gd` | 50 PASS，退出0；TASK-008-campaign-regression.txt |
| 相同参数运行 `test_game_flow.gd` | 44 PASS，退出0；TASK-008-flow-regression.txt |
| 相同参数运行 `test_level_runtime.gd` | 30 PASS，退出0；TASK-008-seed-regression.txt |
| `godot --headless --audio-driver Dummy --path . res://scenes/levels/art/StreetSample.tscn --quit-after 120` | 退出0；TASK-008-smoke.txt |
| `python scripts/validate_docs.py` | 真实结果在TASK-008-docs.txt，4 JSON数据合同；文档验证不等于游戏验收 |

主测试实际覆盖：从导出三角形检测两个阳台各两侧回栏；真实GLB和PBR贴图保留；95个环境粒子有界、烟精灵实际透明通道；40块大碎片实体碰撞；路障/车辆/店面射线阻挡；全24m路线按1.2m胶囊采样；原玩家实体行走/触发/射线击败敌人/FinishArea胜利；Low关闭阴影、体积雾、火光、环境粒子；重开仍加载样板并恢复HP。

失败与修正如实记录：

- 首次 `TASK-008-red.txt` 是测试脚本Variant类型推断解析错误，不是已成功复现的功能红测试；修正显式类型后才运行了功能检查。
- 用户指出缺侧栏后，用旧v001实际导出网格线段检测复现失败，`TASK-008-rail-red.txt`退出1；新增左右回栏/后立柱/连接扶手后，同一检测通过。
- 图形复查发现原短关3m侧边界盒遮住店面；在样板中关闭这些边界，由真实立面碰撞承担阻挡，射线和净宽验证通过，未改原短关资源。
- MCP本地化环境节点名称、library加载列表原地替换曾导致组装失败，已改为按节点类型查找、复制请求名称列表；最终新建v002，保留原Scene和v001。
- smoke alpha检查改用导入的Texture2D.get_image，而非Image.load_from_file，消除打包不兼容警告。最终import/tests/render/render-1080/previews/smoke/三份regression日志无ERROR、SCRIPT ERROR、FAIL、leaked或WARNING；历史red文件为预期失败，不当成最终通过证据。

性能：Windows Vulkan Forward+ / AMD Radeon(TM) Graphics，固定起点；每档预热60帧、采180个墙钟帧间隔。不是GPU计时器/全程战斗/5分钟/RTX2060测试。

| 分辨率/档 | 中位帧间隔ms | P95 ms | 最差ms |
|---|---:|---:|---:|
| 1280×720 Medium | 14.879 | 17.206 | 22.214 |
| 1280×720 Low | 7.119 | 8.886 | 14.401 |
| 1920×1080 Medium | 18.740 | 21.500 | 24.953 |
| 1920×1080 Low | 9.511 | 12.127 | 16.874 |

1080p引擎图形内存监测约490.8MB/476.6MB（Medium/Low，非整机显存）。气氛表现有实测开销；不宣称本机1080p Medium稳定60FPS，也不以本机短测替代目标硬件验收。画质/密度还需随正式车辆和人物接入继续评估。

## C 可视与人工操作验收

真实游戏图像为TASK-008-[1080-]start/cover/shop/low.png，模型预览为docs/asset_requests/TASK-008/preview_*.png。抹灰、烟精灵和车辆参考由imagegen生成，均不充当引擎截图。Blender Review只展示模型组装，不包含Godot后处理/烟尘。

用户已运行v001并给出明确问题；本轮v002修正后等待用户再次确认。操作步骤：

1. 关闭旧样板窗口，重新双击 `run_art_sample.bat`，窗口标题应包含 `TASK-008 Sample v002`。仅点旧进程的重开可能仍使用旧GLB缓存。
2. 看阳台正面及左右回栏；靠近墙根、车旁与道路观察不规则碎石/纸片/木条。大块有碰撞，小微粒只做视觉；中央1.2m路线可走。
3. 中档观察侧方车辆/远景烟柱、局部火光、空气微尘、暖主光/冷阴影；Esc切低画质后非关键烟/尘/火光/体积雾/泛光应关闭，碰撞与战斗仍有效。
4. 继续推进击败原灰盒敌人、到绿色终点，胜利重开仍保留样板而不是退回纯灰盒场。声音仍为TASK-005合成占位。
5. 按 `docs/asset_requests/TASK-008_FIRST_BATCH.md` 制作并回传一辆废弃两厢车GLB（4.2×1.8×1.5m），配套参考图已交付。模型回传后由Codex检查、对齐、替换并重测。

## D 未完成问题/依赖

- **TASK-008尚未验收。** 当前是结构/材质/光照样板与反馈修正，不宣称已达到用户摄影级参考图质量；建筑变化/破损密度、材质丰富度和整体构图仍需视觉迭代。
- sample_vehicle_final仍missing；车辆是明确200面占位。敌人/手臂/武器为原灰盒，正式角色另属TASK-009及后续；远景门/楼群为低精度轮廓占位。
- 烟为透明2D粒子与体积薄雾，不改变AI感知或伤害射线；火光为表现，不是燃烧/爆炸伤害或破坏物理。没有隐性新增玩法。
- 用户已对v001操作反馈，v002的完整人工通关/听感/视觉评审仍待确认；代理做的图形脚本不等于用户实际操作验收。
- 无目标机器长测，无商业级素材/完整许可已清关声明；来源与限制在PROVENANCE和registry记录。源/图像均保存在工作区，未依赖临时目录。
- 无Git仓库，不能提交或提供Git差异；原玩法脚本/默认入口未改，三组原回归通过。

## E 下一个允许开始的任务

停留在TASK-008：等待车辆模型与新版视觉反馈，继续本任务的替换/打磨/验收。只有TASK-008通过后才允许开始TASK-009，不因自动检查通过跳任务。
