# 03 3D 资产规范 / Asset Contract

## TASK-008 样板资产当前状态

Blender 5.2.3已实际验证，MCP从初始未连通到用户配置后成功连接。当前7种独立样板GLB、StreetKit_v002.blend及MCP组装的StreetReview_v002.blend；v001保留为历史检查点。只用于独立24m样板，不替换已验收战役/80m的原资源槽。
registry 新增 sample_* 槽，技术可加载资源记ready，同时标记review_status=sample_art_pending_visual_acceptance；车辆代理额外placeholder=true，sample_vehicle_final仍missing，不能把ready理解为已达到参考图质量。资产几何/UV与三套程序材质原创，抹灰Albedo和车辆参考由内置imagegen生成；详见 assets/source/task008/PROVENANCE.md。2D参考图未注册为模型。
每资产预览在 docs/asset_requests/TASK-008/preview_*.png，全部为Godot真实模型渲染。源文件与参考图目录以.gdignore排除引擎自动导入，实际运行只加载独立GLB。车辆制作/回传合同见 docs/asset_requests/TASK-008_FIRST_BATCH.md。
v002大碎块碰撞由模型生成审计同步到data/art_sample_physics.json。烟雾透明贴图单独登记为vfx_texture，不算3D资产；图片透明度有真实导入纹理验证。

TASK-006 提供静态立面/掩体/装饰的 VisualSlot，操作说明见 `10_ASSET_HANDOFF.md`。此接口只替换外观，不自动接入骨骼角色、武器动作或新碰撞。正式 GLB 仍全部 missing；tests/fixtures 的 GLB 是原创盒体测试样本，禁止冒充正式资产。

## 模型资产的核心原则
使用程序生成的规则模型做灰盒；近景重要模型用授权 GLB；角色和武器不能把 2D 概念图当作真实 mesh。`data/asset_registry.json` 是资源计划表，`status=missing` 即表示需要制作/采购/授权。

## 统一规格
- 世界：m（米），Y up；导入时核对 Blender ↔ Godot 轴向与面向，必要时用单独 import root 调整，不在游戏逻辑中大量修正。
- 默认资源 pivot：地面站立物取底部中心；建筑立面模块取标准墙段底边定位点；武器根据 viewmodel 绑定点。
- 资产文件：`.glb` 优先；PBR 贴图规范命名；材质使用可复用资源；统一可见外表、碰撞与破坏标记。
- 示例命名：`bld_residential_facade_A_4m.glb`、`cover_concrete_jersey_A.glb`、`prop_wood_crate_A.glb`、`chr_enemy_light_A.glb`。
- 资源方向和正反：导入预览后在 Asset Registry 记录 `forward_axis`；不要默认不同工具一致。

## 资产类别与预算（初始设计指导，不是硬件强制上限）
| 类别 | 粒度 | 建议初期 tris / LOD0 | 碰撞 |
|---|---|---:|---|
| 基础墙段 | 2m/4m 标准段 | 100–2,000 | 简单 box 或复合盒 |
| 近景建筑立面 | 4–8m 模块 | 2k–15k | 按墙/门洞分段 |
| 混凝土障碍 | 独立 | 300–3k | 简化形状，应挡弹 |
| 木箱 / 桶 / 沙袋组 | 独立可复用 | 100–2k | 简化形状，按属性挡弹 |
| 车辆 | 完整 | 10k–50k | 简化车身碰撞 |
| 敌人 | 完整骨骼角色 | 15k–40k | Capsule + 命中区域，动画预留 |
| FPS 第一人称武器 | 独立 viewmodel | 10k–35k | 不参与世界射击碰撞 |
预算由实测后调，不宜作为资产自动生成时的唯一标准。

## 角色导入必须核对
1. 一个统一角色骨架及可复用动作；至少 `Idle`, `Walk`, `Run`, `Crouch`, `Aim`, `Fire`, `Reload`, `Hit`, `Death`（允许部分用占位动画过渡）。
2. 贴图、骨骼方向、root motion、动画 loop、换弹事件与命中盒匹配；**必须真人观察动画**。
3. 第一人称玩家武器与第三人称敌人枪械分开：枪口挂点 `MuzzleSocket`，手部绑定位 `GripSocket`。
4. 资源无动作时不能声称已完成自然动作；可使用程序化姿态占位。

## 程序化与手工建模边界
- Codex 适合自动生成：道路、墙体、门窗洞、通用遮挡、低精度立面、贴图变体和实例布置。
- 需要独立美术资源以保证品质：真实人物、武器细部、车辆、特殊倒塌建筑、复杂音效/动作。
- 重复静态小物件考虑 MultiMesh 按街区分组；物理可交互掩体、带独立 AI 的敌人仍用独立节点。

## 入库门槛
建模文件 + GLB + 使用许可 + 缩略图 + 单位/Pivot 检查 + 材质完整 + 一键拖入样板场景正常显示 + 有适当碰撞 + 资产注册表状态更新；其中任意一项未完成，则记为待完善。
