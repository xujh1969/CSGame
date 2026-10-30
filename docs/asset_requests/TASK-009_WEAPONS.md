# TASK-009 枪械方向与模型交付合同

2026-10-29用户指定：玩家M4A1 / AR-15风格卡宾枪、紧凑红点，注意玻璃表现；敌方经典AK-47木托木护木。当前任务只接玩家枪械/电影镜头；AK外形方向记录供后续敌人任务使用，不在本轮接入。

## 当前资产与边界

已收到混元3D的AR-15/AK-47/杂物高低模。当前AR实际低模已展开UV、烘焙四张2K高模材质并派生入库；弹匣已拆为独立组件、瞄具开孔并插入透明圆片，7044三角面。AK和杂物保持原件、完成只读哈希/面数审计，后续任务再接入。下一份优先补双臂，见PLAYER_ARMS_AND_SHADOW.md；不需要重复生成AR-15。下面自制枪说明与参考提示词保留为历史/回退合同。
本机Blender原创rifle_v001是真实可加载网格，独立弹匣/镜片，含PBR；是近景评审样板，不能冒充扫描级或授权M4A1成品。场内保留真实深度测试，近墙收枪；反射镀膜近似没有真实光路/折射放大。当前没有手臂骨骼或握持动画。真实模型工作室渲染见logs/TASK-009-rifle-right.png、left.png，不是AI图。

如果用混元3D/Tripo进一步提升近景真实度，请只生成一件独立物件。保留原始高模/贴图和低模，不手工覆盖当前运行文件；Codex接收后核对SHA、拓扑、UV/材质、尺寸/方向、枪口/瞄准线和实际帧时。生成图仅作参考，不算模型完成。

## 可直接使用的参考图提示词

玩家M4（基于用户原文，补充展示要求）：
“M4A1 tactical carbine, modern AR-15 platform, black anodized metal receiver, Picatinny rail handguard, compact red dot sight with clear subtly coated glass, adjustable black polymer stock, detachable magazine, realistic PBR materials, full weapon clearly visible including muzzle and buttstock, isolated neutral gray studio product render, side three-quarter view, accurate mechanical proportions, no person, no hands, no text, no watermark, no ground pedestal. Do not fuse glass with the sight frame.”

敌方AK（保存用户方向，后续任务才制作/接入）：
“Classic AK-47 assault rifle, full weapon clearly visible, wooden stock, wooden handguard, curved metal magazine, black worn steel receiver, realistic style, neutral gray studio background, product showcase, clear material definition, highly detailed, suitable for 3D modeling reference, no person, no hands, no text, no watermark.”

最好另输出相同造型的左右侧正交图，镜头无景深模糊、不裁切；不用游戏战斗画面直接生成枪。木材与钢铁分材质，镜片不烘成白色实体。

## GLB交付

| 模型 | 使用与尺寸 | 分件 | 建议预算 |
|---|---|---|---|
| 玩家M4 / AR-15 | 第一人称近景，长约0.88–0.95m；Y向上、枪口-Z；机匣中心原点 | 枪身/弹匣/瞄具镜片至少独立，最好枪机/拉机柄另拆；枪口/瞄准中心定位可提供Empty | 先控制30–50k三角面以内，2K PBR；高模单独保留供烘焙 |
| 敌方AK-47 | 后续第三人称，长约0.87m；Y向上、枪口-Z | 枪身/弹匣分件；木/钢分材质，不含人手 | 先控制10–25k三角面，1–2K PBR |

提交GLB + 外部贴图（若未内嵌）+ 来源工具/适用使用条款。BaseColor不含方向光高光，Roughness/Metallic/Normal分通道清楚；镜片独立透明材质，不夹带场景灯、相机、脚本或碰撞。若工具无法分件，先交原始文件，保持原件便于后处理，不把静态图或缺UV低模当完整交付。
