最新修正记录：TASK-009-v004.md（2026-10-30，原生手套双臂/左侧换弹，仍待人工验收）。

# TASK-009 当前v002：用户AR-15已接入，待人工验收

2026-10-29。最新修改、真实检查、模型来源、双臂/完整影子依赖见 [TASK-009-v002.md](TASK-009-v002.md)。用户实际AR替换了下述自制枪；旧资源/截图保留，以下是v001历史记录。

# TASK-009 | 电影镜头与M4风格枪械样板 v001（待人工验收）

2026-10-29（Asia/Shanghai）。用户验收008后授权下一任务，明确优先电影感/远景/景深/真实枪模，随后指定玩家M4A1/AR-15红点、敌方木托AK-47，并确认景深克制/优先识别敌人。候选009敌人任务顺延；当前只做本任务，不接入骨骼敌人或AK，不修改已验收默认战役/v003。

## A 修改文件清单

- 新增tasks/TASK-009.md：范围/设计/实施步骤/验收命令和风险；新增run_cinematic_sample.bat、scenes/levels/art/CinematicSample.tscn，继承原24m关卡，独立入口。
- 新增scripts/art/cinematic_sample.gd、cinematic_camera.gd、scripts/weapons/cinematic_rifle.gd：资产登记加载、三层远景、暖主光/冷环境光调整、克制近远景深/平滑调焦/Low关闭、真实深度测试、球探测和旋转网格包围盒约束、后坐/ADS/红点、原换弹时间驱动弹匣抽插。WeaponController、伤害/射速/原射线代码未改。
- 新增scripts/tools/build_cinematic_assets.py、register_cinematic_assets.py；assets/source/task009/CinematicKit_v001.blend、.gdignore、PROVENANCE.md；assets/models/task009/rifle_v001.glb、skyline_v001.glb及导入侧车、assets/textures/task009三张512px颜色/粗糙度/微法线图。全部原创几何/程序纹理，无下载第三方网格。
- 枪模16,828三角面，源文件111件可编辑部件，运行时合并为Rifle_Body、Magazine、Optic_Glass三网格。实际轮廓机匣/倾斜握把/可调枪托，贯通护木散热槽、导轨、枪管/制退器、扳机护圈；独立弹匣带底板和筋条。米/Y-up/枪口-Z；枪口局部(0,.006,-.582)，瞄准中心(0,.135,.042)。当前是风格与机械接口样板，不是厂家精确复刻或最终写实级枪模。
- 远景12,168三角面：27栋建筑/三距离层，有窗格、女儿墙、屋顶水箱/楼梯间；导出为一网格/多材质，位于原实体终点边界之后，没有假装可探索远方城市。
- 新增assets/materials/optic_glass.gdshader：轻镀膜、随视角增加反光/透明度，深度测试保留、不写深度；镜片无投影。不做光学折射放大，不把透明镜片烘成白色实体。红点启用时隐藏本样板的白准星，HUD其他行为不变。
- 新增tests/test_cinematic_sample.gd、capture_rifle.gd、真实引擎产品图/游戏截图/JSON审计/真实检查日志。修改data/asset_registry.json，新增fps_rifle_m4_sample/cinematic_skyline，技术ready且sample_pending_user_visual_acceptance，其他条目保留。
- 更新README、架构、QA、决策和后续候选路线；新增docs/asset_requests/TASK-009_WEAPONS.md，保留用户M4/AK提示词与镜头用途、尺寸、原点、分件、GLB/UV/贴图、来源/许可要求。AK未虚构为ready。

## B 已执行检查和结果

cwd `C:\Users\AYOU\Desktop\CS`；Godot `C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`，实测4.7.2.stable.official.ed1daf0bf；Blender `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`，实测5.2.3 LTS。下表godot/blender均代表上述完整路径。

| 实际命令/工具 | 结果与证据 |
|---|---|
| `git status --short` | fatal: not a git repository；无Git diff/分支/提交，未初始化，不覆盖工程 |
| `godot --headless --path . --script res://tests/test_cinematic_sample.gd`（样板创建前） | 退出1，缺样板预期失败；TASK-009-red.txt |
| `blender --background --factory-startup --python scripts/tools/build_cinematic_assets.py` | 退出0；实际源文件、UV、GLB和审计；TASK-009-blender.txt、asset-audit.json；隔离进程，不改交互MCP场景 |
| `python scripts/tools/register_cinematic_assets.py` | 退出0；仅新增两项真实资产登记 |
| `godot --headless --editor --path . --quit` | 最终退出0，无ERROR；TASK-009-import.txt |
| `godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_cinematic_sample.gd` | 最终31项PASS、0失败、退出0；实际模型/镜片/枪口/ADS/弹量/换弹/暂停/正墙与±30°斜墙网格约束/真实挡弹/Low/实体行走杀敌/终点/重开；TASK-009-test_cinematic_sample.txt |
| 相同headless参数分别运行test_weapon.gd、test_art_sample.gd、test_campaign.gd | 30/29/50项PASS、各退出0；TASK-009-test_weapon.txt等，原v003包含原车模型SHA核对 |
| `godot --audio-driver Dummy --path . --script res://tests/capture_rifle.gd` | 退出0，真实GLB左右产品图，目视检查完整枪托/枪口/材质/瞄具；TASK-009-rifle-preview.txt、rifle-right/left.png |
| `godot --audio-driver Dummy --path . --script res://tests/test_cinematic_sample.gd -- --render-checkpoints --measure-performance`，另加`--render-1080`复跑 | 最终720/1080各37项PASS、0失败、退出0，无ERROR；TASK-009-gui720/1080.txt。实际渲染，不用headless/fixed-fps测性能 |
| 独立代码审查（requesting-code-review技能） | 发现枪根收回仍可能枪管穿墙；实际顶点测试先复现两失败，再按旋转AABB约束修复，审查确认该问题已解决。补正墙、±30°斜墙真实网格检查；未泛称所有窄障碍/斜角均已验证 |
| `python -m py_compile scripts/tools/build_cinematic_assets.py scripts/tools/register_cinematic_assets.py`、`python scripts/validate_docs.py` | 工具语法/文档检查见收尾实际运行；不代替游戏交互验收 |

镜片实际图形对比：ADS时暂时隐藏镜片，比较中心169像素有/无玻璃RGB平均差；720=0.055714、1080=0.051847，均低于0.12阈值，确认没有不透明白块挡目标。截图和像素对比结合，不仅检查Shader资源存在。

最终本机AMD Radeon(TM) Graphics、Vulkan Forward+，静止视点每档热身60帧/采样180帧，墙钟间隔ms：

| 分辨率/档位 | 中位 | P95 | 最慢 |
|---|---:|---:|---:|
| 1280×720 Medium | 11.055 | 12.152 | 13.612 |
| 1280×720 Low | 6.969 | 7.677 | 8.668 |
| 1920×1080 Medium | 21.739 | 25.010 | 25.895 |
| 1920×1080 Low | 8.629 | 9.814 | 10.276 |

1080引擎图形内存计数约599.8/585.7MB（Medium/Low），非独立显卡物理显存占用。1080中档本机短测未达到60FPS，不能声明达标；720最低30FPS只具备本视点短测证据，无全程/目标RTX2060长测。DOF有成本，Low可关闭；不把跨次缓存/负载差异直接归因某一个网格。

真实失败/撤回记录：

- 初轮镜片Shader用了旧CLEARCOAT_GLOSS，Godot4.7报Unknown identifier并渲染白块。逻辑测试退出0仍不代表图形通过，保留TASK-009-glass-shader-first-failure.txt；按4.7实际文档改CLEARCOAT_ROUGHNESS后图形复验无ERROR。
- 审查后补正墙实际顶点检查，在旧收枪位移下腰射/ADS两项FAIL，退出1，见TASK-009-wall-envelope-red.txt；修复不删除用例，最终两姿态及±30°都通过。
- 试加SSAO导致720/1080中档中位19.052/25.050ms，明显增加开销，撤销此额外增强，保留TASK-009-ssao-cost-720/1080.txt；只移除与撤回功能对应的检查，没有隐藏失败。

技术资料：Godot [CameraAttributesPractical](https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html)、[4.7 Spatial shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)。实际运行验证优先于仅引用文档。

## C 人工操作验收

关闭旧窗口后双击 `run_cinematic_sample.bat`，确认TASK-009 Cinematic v001。此入口独立，原run_art_sample.bat仍是已验收008 v003。

1. 腰射看新枪的轮廓、金属/聚合物、护木槽、导轨、远方多层建筑与轻微虚化；交战近处不应整体糊掉。
2. 右键ADS：红点对中，白准星隐藏；镜片可透视，带轻微色调/斜视反光，不能显示白块。测试横看墙根/靠近墙体，枪应收回，伤害不能穿墙。
3. 射几发后R：弹匣抽出再插回，装填期间不能开火；Esc暂停应冻结装填，恢复后弹量只按实际缺弹数转移。
4. Esc切Low观察远景/近景DOF关闭；继续走到终点击败原灰盒敌人并获胜，重开仍是电影枪械样板。
5. 与用户参考图对照近景质量、镜片强度、枪体遮挡面积、聚焦清晰度。本任务目前只有脚本控制GUI走测和代理目视截图，尚未获用户实际键鼠/听感/美术验收。

## D 未完成问题/依赖

- TASK-009尚未用户验收。枪为本机原创技术/造型样板，机械比例、近景材质/磨损仍有简化；不能宣称已经达到用户真实M4产品图或摄影级目标。若用户采用混元3D/Tripo制作更精细枪模，制作单已备，低高模/分件/UV/镜片需再验。
- 尚无骨骼手臂/真实握持、枪机动作；换弹为弹匣抽插表现。玻璃为镀膜反射近似，没有物理光学放大/折射。准星射线和枪口尊重真实碰撞，近墙不绕过深度。
- 敌人和声效仍沿用灰盒/程序合成占位；敌方木托AK-47仅方向/交付合同，不是已完成资产。检测到用户另放的敌人高低模源文件，本任务未编辑/绑定/集成；Godot可能生成其导入侧车/内嵌贴图缓存，不等于动画验收。
- 远景为不可达低精度城市，不含额外可玩关卡；当前仅独立24m样板。没有目标硬件长测/完整授权清关声明。无Git仓库，因此无法给Git diff或提交。

## E 下一个允许开始的任务

停留TASK-009：等待用户近景枪模/镜片/景深/键鼠验收，必要时继续同任务打磨。通过后才允许TASK-010敌人/AK；本轮未开始该任务。
