# L4D2 Dynamic Ammo（动态调整子弹上限）

作者：morzlee（原始思路）、night  
版本：1.1.0

根据 `specialspawner` 的 `ss_spawn_size` 动态调整武器备弹上限，不会直接补充玩家现有弹药。

## 游戏内指令

- `!da_status`：管理员查看当前动态备弹状态。
- `!da_recalc`：管理员重新绑定并计算备弹上限。

## 注意事项

- 需要服务器使用提供 `ss_spawn_size` 的 `specialspawner` 插件。
