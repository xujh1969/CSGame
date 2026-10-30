# TASK-009 | 电影镜头与第一人称步枪样板

2026-10-29。TASK-008用户已验收；用户明确授权下一任务，并将电影感/远景/景深/逼真枪械提前。原候选009骨骼敌人顺延，不同时开发。用户确认景深克制、优先看清敌人。

## Goal / Design
独立CinematicSample继承已验收24m街道，不修改默认战役或v003入口。增加三层有窗/屋顶构件的不可达远景，采用冷暖空气透视、轻微远景DOF；中近距离交战清晰，准星射线平滑调焦且设28m清晰区下限。近景DOF轻微，只影响很近的枪托等，瞄具保持清晰。Low关闭DOF。

枪械使用本机Blender独立制作的虚构分件步枪（机匣、护木/导轨/散热槽、枪管/制退器、枪托、握把、扳机护圈、独立弹匣、瞄具），真实GLB和可编辑源文件，不新增伤害逻辑。沿用原WeaponController控制弹量/射速/换弹时间；表现层只订阅数据，枪口Marker对齐真实网格。近墙球形探测收枪，真实深度测试保留；不使用总在最上层绘制枪械的穿墙覆盖。换弹只做可见弹匣抽插，不制作骨骼手臂；手臂/敌人动画明确留后续。

## Implementation plan / Files
追加用户枪械方向：M4A1 / AR-15平台、紧凑红点、黑色阳极氧化金属/聚合物，注意透明镜片；敌方木托AK-47记录到后续敌人任务。本机原创模型是风格样板，不是精确厂家复刻或最终扫描级资产。镜片使用透明镀膜/掠射反光，真实像素对比验证透视，不声称物理光路放大。

- [x] tests/test_cinematic_sample.gd：缺样板先失败留档；实际导入网格/组件/材质、ADS/弹量/换弹、近墙球探测/射线挡弹、Low景深关闭、重开；实际截图hip/ADS/贴墙/换弹/远景。
- [x] scripts/tools/build_cinematic_assets.py → assets/models/task009/rifle_v001.glb、skyline_v001.glb；assets/source/task009/CinematicKit_v001.blend（隔离background，不覆盖MCP场景），PBR纹理和面数/单位/来源审计。模型外观仍待近景人工评审。
- [x] scripts/art/cinematic_sample.gd：只在独立scene安装资产、背景与镜头；scripts/art/cinematic_camera.gd管理清晰区/DOF/Low；scripts/weapons/cinematic_rifle.gd仅管理武器表现和近墙收回。
- [x] scenes/levels/art/CinematicSample.tscn、run_cinematic_sample.bat：复用已验证启动方式；registry登记实际资源和后续占位；修改候选路线顺序、README、QA、logs/TASK-009.md。
- [x] 实际导入/解析、headless测试、GUI截图/脚本走测、720/1080帧间隔，test_weapon/art_sample/campaign回归；记录未完成视觉与键鼠验收。

## Acceptance / Commands
`blender --background --factory-startup --python scripts/tools/build_cinematic_assets.py`
`godot --headless --editor --path . --quit`
`godot --headless --audio-driver Dummy --path . --fixed-fps 60 --script res://tests/test_cinematic_sample.gd`
GUI去headless/fixed-fps，加`-- --render-checkpoints --measure-performance`，另加`--render-1080`复查。
`test_weapon.gd`、`test_art_sample.gd`、`test_campaign.gd`回归；`python scripts/validate_docs.py`。

- [x] 原入口/v003不变，射击尊重真实墙体，无新穿透规则；换弹无重复刷弹。
- [x] 分件模型、PBR、实际面数和前向/枪口审计，近景真实截图供评审，不自称最终商业品质。
- [x] 背景具有多层建筑且不入可玩路径，景深轻微/Low关闭，不影响HUD与交战识别。
- [ ] 用户视觉与键鼠验收通过；无目标硬件达标的未测声明。

## Risks / Scope
### v002续作计划（用户要求继续开发）
用户随后交付混元3D AR-15/AK-47/杂物高低模，要求修透明瞄具、拆弹匣，并咨询双臂与全身影子。当前优先接入实际AR-15（7044面、四张2K烘焙图、独立Magazine/Optic_Glass），自制v002枪保留回退；AK/杂物只读审计。取消孤立第一人称枪影，完整人体影子/手臂仍是后续依赖，不能宣称已完成。双臂制作单与全身替代方案已写入PLAYER_ARMS_AND_SHADOW.md。
- [x] 保留v001 GLB/源文件和截图，新增v002模型/源文件；2K金属纹理加入粗糙度变化/细划痕，1K聚合物独立颗粒微法线，轻度边缘露底。
- [x] 远景增加穹顶与塔楼轮廓，保持不可达和合并网格；不增加近景SSAO或新增玩法。
- [x] 登记实际新资源，产品渲染读取登记；验证真实导入贴图材质/远景高度、镜片透视与原有收枪/战斗/重开，重新测720/1080帧时。
- [x] 更新v002记录与人工操作入口；仍等待用户TASK-009视觉/键鼠验收，不开始010。

景深支持Forward+/Mobile，使用CameraAttributesPractical，资料：https://docs.godotengine.org/en/stable/classes/class_cameraattributespractical.html 。不新增插件。当前枪模为用户混元3D派生资源，自制枪保留回退，仍须评审；不购买第三方资产，不把原灰盒敌人当正式角色；无骨骼手臂、光学镜内真实放大或新增武器系统。本机无Git仓库，无法提交/diff，不初始化。

## v003 / v004 用户明确追加范围（2026-10-30）
用户要求新 AR-15-1、杂物及双臂接入；随后明确改用下载的 hand_with_gloves.glb。
- [x] 原件保留；AR-15-1/杂物低模烘焙高模贴图，弹匣独立，13堆杂物仅部署在当前独立样板。
- [x] 下载手套双臂保留原蒙皮/材质/手指骨骼，独立 v004 导出，旧手臂可回退。
- [ ] 右手掌心向握把、掌根贴合、拇指/食指方向正确；左手从左侧换弹，无双臂穿插。
- [ ] 全换弹路径及新姿态视觉检查、性能复测与用户键鼠验收通过。
旧段落的“不做手臂”被本次显式指令覆盖，仅限 TASK-009；不引入敌人/AK或 TASK-010。

## 2026-10-30 用户新增诊断门禁
先读 Desktop/CODEX_TASK.md、FPSRigDiagnostics.gd 和安装配置方法.md；建立 debug/fps_rig_test.tscn，实际库存 Skeleton3D/蒙皮/AnimationPlayer/AnimationTree/BoneAttachment3D，使用真实掌面 Marker 与独立武器 Socket。覆盖 Idle/ADS/Fire/Reload 分阶段 JSON/固定视角截图，禁止只测手腕可达性。未通过的模型不合并主场景。当前候选只静态校准；四状态记录中的 Fire/Reload 表现冻结并明确标记，换弹仍未验收。GitHub 上传到独立任务分支，main 仅仓库说明。
