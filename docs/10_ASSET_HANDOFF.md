# TASK-006 静态模型交付与替换

## 协作方式

需要正式资产时，先由 Codex 给出独立模型/部件清单、参考图片生成提示词和尺寸/朝向/拆分要求。用户可用 Tripo 或混元3D 生成并发回 GLB；Codex 检查单位、轮廓、贴图、许可和碰撞一致性后接入。规则部件可由 Codex 使用本机 Blender 制作；必须先检查实际版本和连接。用户报告 Blender 5.2.3，本任务未调用 Blender，也未要求立刻制作正式美术。

## 当前接口

可替换的静态槽位是 registry 中的 cover_wall_A、cover_barrier_A、cover_box_A、facade_residential_A、facade_shopfront_A、facade_ruin_A、facade_high_window_A、facade_ac_A、facade_vent_A。敌人和武器的动画接口不属于此次静态 VisualSlot 范围。

1. GLB 放入 `assets/models/`，允许 Godot 导入。米制、Y up；不带脚本、碰撞体、导航、额外灯光或相机。不要使用 `-col` 自动碰撞命名。
2. 先在对应 fallback_scene 中查看坐标/轮廓；对齐其根节点原点，保持窗口洞和掩体尺寸。墙/掩体根原点在底部中心；装饰挂点原点在模型中心，正面朝局部 +Z。面片不可遮住高窗射击洞口。
3. 修改 `data/asset_registry.json` 中该项 proposed_path 为真实 `res://...glb`，status 改为 ready，补 source、license、usage_restrictions。不要修改玩家、武器或 AI。
4. 启动游戏，LevelRuntime 只隐藏该实例的灰盒 Mesh，载入 GLB 到 VisualSlot；原 StaticBody/CollisionShape/Marker 不动。F3 复查碰撞轮廓，实测玩家碰撞及射线。含碰撞节点/脚本的 GLB 会被拒绝并保留灰盒。
5. 移走文件或改回 missing，重启即恢复灰盒。若修改布局 JSON，需执行 `python scripts/tools/build_vertical_slice.py`；仅 registry 更新无需烘焙布局。

## 首批适合制作的简单装饰（以后需要时使用）

| 独立模型 | 目标尺寸 X/Y/Z | 原点/拆分 |
|---|---|---|
| facade_ac_A 外挂机 | 0.9 / 0.55 / 0.35m | 中心原点；外壳、风扇格栅可独立网格；不做室内机/长管道 |
| facade_vent_A 百叶通风箱 | 0.9 / 0.55 / 0.35m | 中心原点；边框、百叶独立网格；背面贴墙 |

参考图片生成提示词（生成参考图不等于生成 3D）：

“单个旧式城市建筑空调室外机，正交三分之四视图，完整展示外壳、圆形风扇格栅、固定支架，浅灰金属，轻微灰尘和锈蚀，真实尺度，无品牌无文字，纯中性背景，无建筑、人物或杂物，柔和均匀工作室照明，适合三维建模参考。”

“单个矩形金属百叶通风箱，正交三分之四视图，清楚展示边框、水平百叶和侧面厚度，灰色旧金属，轻微风化，无品牌无文字，纯中性背景，无建筑、人物或其他物体，均匀工作室照明，适合三维建模参考。”

回传 GLB 时同时提供生成工具、使用许可/条款和参考图。首批以每件不超过约 2k 三角面、单套不超过 1k 贴图为制作目标，最终质量和性能以导入后实测为准。未入库验收前保持 missing。

## 测试样本

`tests/fixtures/visual_only.glb` 是 `generate_visual_fixture.py` 写出的真实 glTF 2 二进制原创盒体，仅验证导入和替换，不是正式空调/路障资产，不在生产 registry 登记为 ready。
