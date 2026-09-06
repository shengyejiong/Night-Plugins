# 满槽稳定多特感插件

作者：Tordecybombo、breezy、night  
版本：1.3.10-night

基于 `Special Spawner 1.3.7` 增加满槽保护，避免客户端槽位用尽后反复搜索出生点、创建 Bot 和叠加补刷计时器；有可用槽位时仍保留原版动态数量和整批补刷逻辑。

## 游戏内指令

- `!weight`：管理员设置特感生成比重。
- `!limit`：管理员设置特感生成数量。
- `!timer`：管理员设置特感生成时间。
- `!resetspawn`：管理员处死特感并重新开始生成计时。
- `!forcetimer`：管理员强制开始生成计时。

## 注意事项

- 需要 Left 4 DHooks，并继续读取 `cfg/sourcemod/specialspawner.cfg`。
- `specialspawner_fullslots.smx` 不能与原版 `specialspawner.smx` 同时加载。
- 满 31 个客户端实体时不会预留真人连接槽。
- 普通特感死亡或被外部插件处死后，不会按客户端断开事件立即补刷；下一批仍由原版生成计时器及 `ss_time_min` / `ss_time_max` 决定。
- 团灭重开后会低频检查生还者是否已经离开起点；若 Left 4 DHooks 的首次离开安全区回调漏失，会重新启动原版刷新流程。
- 原版 1.3.7 源码、SMX 和默认配置保存在 `原版备份-1.3.7` 中。
