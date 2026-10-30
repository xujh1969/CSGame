# TASK-003 | 80 米灰盒战斗街段和掩体

## Goal
在现有玩法系统上建立 `VerticalSlice01.tscn`，配置长度约 80m 的连续街道、关键遮蔽物和 3 个敌人占位 Marker。
## Scope
根据 `data/vertical_slice.json` 初始化主要几何；两边至少 3 种不同立面构成；高窗、街角、矮墙、触发线及胜利终点；留出 1.2m 以上路线通口。
## Out of Scope
正式高精度 PBR、程序随机街区、完整 AI。
## Acceptance
- [ ] 起点到终点能步行抵达。
- [ ] 三种关键掩体及高窗位置清楚可见，命中受遮挡。
- [ ] SpawnMarkers 与触发点数据可通过编辑器检查。
- [ ] 不改变已有玩家控制和武器实现。
