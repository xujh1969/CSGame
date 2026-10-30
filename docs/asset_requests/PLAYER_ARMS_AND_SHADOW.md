# 玩家双臂与完整影子：模型协作制作单

2026-10-30更新：已收到手臂2高低模，随后按用户要求替换为 hand_with_gloves.glb。当前已接入原生骨骼/蒙皮手套双臂和Hold/Reload派生动作，仍待姿态人工验收，无需重复生成双臂。完整身体影子仍未实现；以下生成规范保留供后续需要新全身资产时使用。

## 为什么不只用两条手臂投影

画面中的第一人称双臂适合近景精度与相机构图，通常并不等于世界中一个完整人物的位置/比例；单独给它们和枪投影仍缺头、身体与腿。完整影子应由一套全身、随玩家运动/瞄准/换弹的角色与世界武器产生，第一人称镜头再显示高精度局部手臂。两者需对齐身高、骨架与动作时序；只是把完整角色隐藏，不会自动得到正确影子。

当前已收到的无枪战士高低模可评估复用为世界身体/影子来源，无需先重复生成一个全身战士。新样板先关闭孤立的第一人称枪影；完整人体影子是明确待办，Low关闭动态阴影时也不会显示。

## 现在最值得补的模型

首选只补 **一套无枪男性双臂+完整双手**。两只手臂使用同一肤色/手套，真实成年男性运动员体型、发达但不过度夸张的前臂，黑/深橄榄色全指战术手套，指节/掌心/手背都有结构，肘部或卷袖到上臂，双臂分开、无遮挡。不要融合枪械，不要闭拳或握住看不见的枪，不要手指粘连。

如果图生工具很难生成独立双臂，则改交 **一个无枪A-pose全身人物**，短袖/卷袖、露出前臂、同样的战术手套，我再评估从身体拆取第一人称双臂。两种方案选一种即可，不需同时生成两套。

## 可直接用于生成参考图的提示词

双臂方案：

“Game-ready first-person male arms asset reference, a matched pair of anatomically correct muscular adult male arms, both left and right arms fully visible from upper arm to fingertips, strong realistic forearms with natural muscle definition, black full-finger tactical gloves with reinforced knuckles, detailed palms and finger joints, rolled dark olive sleeves ending above the elbows, natural skin texture, neutral relaxed A-pose, elbows slightly bent, fingers gently separated and relaxed, arms spaced apart without overlap, clean upper-arm boundaries for a game asset, realistic PBR material definition, neutral gray studio background, soft even lighting, no weapon, no gun, no torso, no injuries, no text, no watermark, no cropped fingers. Provide consistent front and back views of the same design.”

全身替代方案：

“Full-body modern male tactical operator, realistic athletic muscular build, approximately 1.82 meters tall, short or rolled dark olive sleeves exposing strong forearms, black full-finger tactical gloves with reinforced knuckles, practical tactical vest and trousers, neutral relaxed A-pose with arms about 40 degrees away from torso, complete hands and naturally separated fingers, both feet visible, realistic PBR materials, neutral gray studio background, evenly lit 3D modeling reference, no weapon, no gun, no held objects, no text, no watermark, no dramatic pose. Consistent front, side and back views of the same character.”

## 交付合同

| 项目 | 要求 |
|---|---|
| asset_id | player_fp_arms；全身替代方案为player_body_source |
| 尺寸 | 参考身高1.82m；肩到指尖每臂约0.75–0.85m，保持正常手掌/指长，不为充满画面拉长手臂 |
| 坐标/原点 | 米、Y向上；角色面向-Z；双臂根原点在肩线中心，全身根在两脚间地面。工具轴向不同可保留原始输出，由Codex校正 |
| 分件 | 左臂、右臂最好独立；手套/皮肤/衣袖独立材质。手指与手掌可同一可变形网格，不要把指缝封成团块 |
| 网格 | 有高低模就两份都交；双臂低模先以30–50k三角面内作为预算，重点保留五指/拇指/肘腕轮廓 |
| 材质 | 2K BaseColor/Normal/Roughness，手套金属配件与皮肤有不同粗糙度；颜色图不烘死方向光 |
| 文件 | GLB优先，带UV和材质；若低模无UV，仍保留高模及贴图供烘焙。不要把两份原件覆盖成同一文件 |
| 骨骼 | 如工具可靠支持，保留肩/肘/腕/各手指骨与蒙皮；不支持就交静态原件并说明，不必假装已有动作 |
| 来源 | 工具名、适用许可/使用条款；建议放assets/models/player_delivery/，保留原始命名和说明 |

## 接收后还要完成的工作

检查拓扑/UV/法线与五指，绑定肩肘腕指，定位M4握把与护木的左右手挂点；制作持枪、ADS、射击和换弹动作；世界全身与第一人称动作同步，世界武器随手部挂点运动，完整角色影子随步行和瞄准变化。必须用实际光源、地面、行走/转向/贴墙/换弹验收，不能只凭一个静态人影宣称准确。后续按任务顺序实施，不在本次接入AK或开发新战斗机制。
