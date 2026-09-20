# 满槽稳定多特感插件

作者：Tordecybombo、breezy、night  
版本：1.3.12-night

基于 `Special Spawner 1.3.7` 增加满槽保护，避免客户端槽位用尽后反复搜索出生点、创建 Bot 和叠加补刷计时器；有可用槽位时仍保留原版动态数量和整批补刷逻辑。

## 游戏内指令

- `!weight`：管理员设置特感生成比重。
- `!limit`：管理员设置特感生成数量。
- `!timer`：管理员设置特感生成时间。
- `!resetspawn`：管理员处死特感并重新开始生成计时。
- `!forcetimer`：管理员强制开始生成计时。

## 高人数单批成长

- `ss_spawn_size_high_threshold`：生还者总人数超过多少人后，单批数量改用高人数成长间隔，默认 `8`。
- `ss_spawn_size_high_step`：超过阈值后，每增加多少名生还者才让单批数量增加一只，默认 `2`。
- 该功能只改变 `ss_spawn_size` 的人数成长；`ss_si_limit` 仍完全使用原来的 `ss_base_limit` 和 `ss_extra_limit` 公式。
- 默认配置下，8 人为每批 9 只，9 人仍为 9 只，10 人增加到 10 只，11 人仍为 10 只。
- 人数统计包含生还者队伍中的 Bot。

## 注意事项

- 需要 Left 4 DHooks，并继续读取 `cfg/sourcemod/specialspawner.cfg`。
- `specialspawner_fullslots.smx` 不能与原版 `specialspawner.smx` 同时加载。
- 满 31 个客户端实体时不会预留真人连接槽。
- 普通特感死亡或被外部插件处死后，不会按客户端断开事件立即补刷；下一批仍由原版生成计时器及 `ss_time_min` / `ss_time_max` 决定。
- 正常批次因出生点失败或死亡特感仍在踢出队列而缺额时，会在 1 秒后按实时上限和空槽补试缺额，最多补试一次；不会恢复逐只死亡立即补位。
- 团灭重开后会低频检查生还者是否已经离开起点；若 Left 4 DHooks 的首次离开安全区回调漏失，会重新启动原版刷新流程。
- 原版 1.3.7 源码、SMX 和默认配置保存在 `原版备份-1.3.7` 中。
