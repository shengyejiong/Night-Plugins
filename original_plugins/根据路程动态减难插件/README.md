# 根据路程动态减难

作者：night  
版本：1.0.0

根据本章团灭次数和团灭路程，通过全员投票分两阶降低难度。第一阶在后续每次团灭重开时按真人数量生成止痛药；第二阶会在最近五次团灭的平均路程处，以 50 实血复活死亡真人。

## 游戏内指令

- `!flowassist_status`：管理员查看当前计数、阶段和复活路程。
- `!flowassist_reset`：高级管理员清空当前章节的计数和减难状态。

## 注意事项

- 需要 Left 4 DHooks 和 `l4d2_nativevote`（原生投票函数库）。
- 投票开始时在线的真人必须全部投票，否则本次投票作废。
- 导航异常地图可在 `addons/sourcemod/configs/l4d2_flow_difficulty_maps.cfg` 中禁用路程功能或覆盖最大 Flow 距离。
