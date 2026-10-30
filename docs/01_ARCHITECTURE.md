# 01 Godot 技术架构与接口

## TASK-009 独立电影/枪械表现

`CinematicSample.tscn`继承已验收StreetSample；`cinematic_sample.gd`读取资产登记安装远景与玩家枪模，不改变默认战役。`cinematic_camera.gd`只管理平滑景深/清晰区和质量开关；`cinematic_rifle.gd`只管理姿态/近墙约束/镜片/弹匣，保留原RifleViewModel根和Muzzle路径，禁用该实例原盒体显示及位移动画。WeaponController继续独占伤害、射速、弹量/换弹时间；原真实射线阻挡规则不变。近墙按球形探测安全距离与实际网格旋转包围盒收回，不用前景覆盖绕过深度。新表现随关加载/释放，暂停继承PAUSABLE。

## TASK-007 多关卡骨架

`Campaign.tscn` 是默认入口。`level_catalog.gd` 校验 data/campaign.json 的 start_id、levels[{id,title,scene_path,required_encounters,next_id}]：唯一ID/场景/遭遇数组/引用/环路/可达性。
`campaign_session.gd` 只负责目录、加载过渡和关间生命周期；LevelHost 始终只有一个关卡，process_mode 明确为 PAUSABLE，避免从 ALWAYS 的加载控制器继承而破坏暂停。
关内 GameFlow 接收可选 session、关名和本关 required_encounters，判断胜负；通过 session 重试/下一关。独立运行原80m/20m时 session 为空，重开行为保留。

切换同步上锁、暂停旧关，校验新关结构后停旧音频并有界等待混音释放，再移除并释放旧关；新关恢复暂停/鼠标状态、HP与弹药。预备的离树关卡归 session 所有，失败/退出时释放；BattlePresentation 在 _init 就拥有特效容器，避免离树实例被丢弃时遗留孤儿节点。状态不序列化到磁盘，不缓存旧敌人节点。

## 引擎决策

TASK-006 实现：固定玩法继续由离线工具烘焙为可编辑场景；道路独立为 `RoadStrip.tscn`，保持 WorldGeo/Ground 等路径。`level_runtime.gd` 校验 JSON/hash、只重建自己拥有的 Decorations，使用独立 RNG；`asset_visual_slot.gd` 根据 registry 替换静态模块外观，碰撞与 Marker 保留；`level_debug.gd` 提供 F3/F4 只读调试。玩家/武器/AI 无需改动。这里不提供任意地形或无穷街景生成。
Godot 4.7.x 稳定版 + GDScript；**TASK-000 必须检查本机版本并锁定，不得把版本号当成已安装事实**。Windows 桌面首选 Forward+，提供低特效档，必要时对兼容硬件另做测试。使用 Git 仓库；资源尽量 `.glb`，不要依赖不可追溯的编辑器缓存。

## 推荐根目录（是目标约定，不代表文件已经存在）
```text
project.godot
AGENTS.md
scenes/
  main.tscn
  player/Player.tscn
  weapons/RifleViewModel.tscn
  enemies/EnemyBase.tscn
  cover/ConcreteBarrier.tscn
  levels/VerticalSlice01.tscn
  fx/MuzzleFlash.tscn
scripts/
  player/player_controller.gd
  player/health_component.gd
  weapons/weapon_controller.gd
  enemies/enemy_brain.gd
  enemies/enemy_perception.gd
  game/encounter_manager.gd
  game/level_runtime.gd
  game/game_flow.gd
  ui/hud.gd
assets/models/ assets/materials/ assets/audio/ assets/animations/
data/ docs/ tasks/ tests/ logs/
```

## 场景责任边界
- Player: `CharacterBody3D` 驱动位置与碰撞；Camera3D 负责视角；武器 ViewModel 单独设置，避免跟随玩家身体碰撞。耦合通过信号。
- WeaponController: 射速、弹量、Hitscan、可命中层、后坐；发出 `fired(origin,direction)`、`ammo_changed(mag,reserve)`、`hit(target,damage)`；HUD 只能订阅，不能修改弹量。
- EnemyBase: 外观、碰撞、生命组件、状态机与感知组件；将行为与资源渲染分开，之后才能替换骨骼 GLB。
- EncounterManager: 按触发区和敌人站位标记管理遭遇，不负责渲染世界。
- LevelRuntime: 加载布局、校验可通行区域、根据 seed 复现装饰。
- WorldGeo/Cover: 静态几何使用 `StaticBody3D`/GridMap，掩体要正确碰撞层；敌人和交互体使用独立场景，不硬塞进 GridMap。
- GameFlow: 进入游戏、暂停、失败、胜利及重置。

## 事件合同
- `damage_requested(target, amount, hit_position, hit_normal)`：由命中模块触发，HealthComponent 验证并扣血。
- `actor_died(actor_id)`：敌人去活与遭遇结束依据。每个 actor 至多触发一次。
- `encounter_started(id)` / `encounter_cleared(id)`：仅遭遇管理器广播。
- `objective_changed(text)`：UI 被动显示。

## 关键约束
1. Godot 长度单位：**1 unit = 1 米**，Y 向上、玩家主进方向 -Z；所有资源导入统一变换，不在每处临时缩放。
2. 伤害射线同时查询 World、Cover、Characters，按照碰撞层判断最近命中。可见性查询与伤害查询共享一套阻挡语义，不可穿实墙。
3. 基础几何不等于渲染几何：低成本盒型/凸体用于碰撞；精细碎石、小挂件通常不需要独立碰撞。
4. 敌人移动使用 NavigationAgent3D；不能假定导航路径保证物理避障，移动还需要 CharacterBody3D；窗口敌人可用固定炮位，避免第一版做三维攀爬寻路。
5. 资源通过明确路径或 manifest 加载；资源缺失时灰盒替代并输出日志。禁止假定参考概念图可直接加载为 3D mesh。
6. 预留 debug：AI 视锥/状态、伤害射线、性能、Trigger、坐标/种子显示开关。

## 碰撞建议（TASK-000 实际落地前需核对引擎）
- Layer 1 WorldStatic；2 Cover；3 PlayerBody；4 EnemyBody；5 Interactable；6 Trigger（Area3D 作为监测）。
- 武器射线命中 mask = WorldStatic | Cover | EnemyBody（玩家开火）；敌人射线 = WorldStatic | Cover | PlayerBody；感知可见性查询需排除本人并含遮挡层。
- 触发区域用 Area3D 的监测，而非物理阻挡玩家的 CollisionShape。

## 外部依赖政策
原则上无需额外插件即可完成第一版；Blender、模型资产导入为可选。使用第三方内容必须记录出处、许可、版本。
