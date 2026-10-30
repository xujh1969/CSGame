# TASK-001 | FPS 玩家运动与碰撞

## 读哪些文件
`AGENTS.md`、`docs/01_ARCHITECTURE.md`、`docs/04_GAMEPLAY.md`、`docs/07_QA_PERFORMANCE.md`，及 TASK-000 的实际代码。

## Goal
新增 CharacterBody3D 玩家控制器，支持鼠标视角、WASD、Shift 奔跑、Space 跳跃、Ctrl 蹲与 Esc 解锁鼠标。

## Scope
输入与物理分离；平滑蹲伏并检查头顶空间；镜头与碰撞盒正确对应；配一处可藏的矮墙和可跳的小台阶供测试。
## Out of Scope
武器、敌人 AI、真实动作资源。
## Acceptance
- [ ] 走跑跳蹲可操作且各状态速度正确。
- [ ] 不穿过实墙、地面、箱子；站起前检查头顶。
- [ ] Esc 焦点切换正确；相机无异常摆动。
- [ ] Godot 导入检查和人工走测均通过。
