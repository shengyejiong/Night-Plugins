# [L4D2] Rescue Door Marker v0.2.0

目的：仅给地图原生复活房（rescue closet）的**尚未开启的门**加轮廓高亮，提醒玩家“这是一扇复活门，没必要的话先别开”。

插件依旧坚持：**不锁门、不解锁门、不自动开门、不阻止玩家开门、不修改死亡生还者的复活逻辑。**

## v0.2.0 的主要变化

v0.1.0 中，复活门打开之后仍会保持黄色高亮。

v0.2.0 改为：

1. 插件识别到复活门后给门加黄色 Glow。
2. 对该门监听 `OnOpen` 输出。
3. 玩家第一次打开它时，立即恢复门原本的 Glow 状态，高亮消失。
4. 记录“本回合这扇门已经打开过”。
5. 即使门随后又自动关闭、管理员执行 `sm_rdm_rescan`、或者修改颜色/扫描参数，本回合都不会重新把它标亮。
6. 下一回合 `round_start` 时才清空“已经打开”记录，重新正常标记。

因此默认语义非常直接：

- **黄色高亮 = 尚未被打开过的复活门。**
- **高亮消失 = 这扇复活门本回合已经有人打开过。**

## 额外的晚加载保护

如果插件在回合进行到一半才加载，或者管理员中途重新扫描，而某扇候选复活门此时已经处于“打开 / 正在打开 / 正在关闭”等非关闭状态，v0.2.0 会把它直接视为已经使用过，本回合不再加高亮。

这样可以避免“明明已经打开了，插件刚重载却又把它标黄”的误导。

## 识别思路

插件仍使用 v0.1.0 的“复活点投票”算法：

1. 扫描所有 `info_survivor_rescue`。
2. 每个复活点在一定半径内寻找最近的 `prop_door_rotating`。
3. 每个复活点给最近的门投 1 票。
4. 一扇门获得至少 2 票，则判定为复活门。
5. 为兼容只放 1 个复活点的非标准第三方图：如果门离该复活点足够近（默认 220 units），1 票也接受。
6. 默认不把 `prop_door_rotating_checkpoint` 作为候选，避免把出生/终点安全屋门标记为复活门。

## 安装

本仓库已经按 `left4dead2` 相对根目录整理：

- `addons/sourcemod/plugins/l4d2_rescue_door_marker.smx`：编译后的插件；
- `addons/sourcemod/scripting/l4d2_rescue_door_marker.sp`：SourcePawn 源码。

部署时，把插件目录中的 `addons` 合并到服务器的：

`left4dead2/addons/`

插件仍然使用原来的自动配置文件：

`left4dead2/cfg/sourcemod/l4d2_rescue_door_marker.cfg`

所以从 v0.1.0 升级时不需要重新写配置。

依赖：SourceMod 1.12（仅使用 SourceMod 和 SDKTools 自带接口，无第三方扩展依赖）。

## 默认/推荐测试配置

```cfg
rdm_enable 1
rdm_color "255 180 0"
rdm_glow_range 1200
rdm_search_radius 450
rdm_single_point_distance 220
rdm_include_checkpoint_doors 0
rdm_debug 1
```

管理员手动重新扫描：

```text
sm_rdm_rescan
```

注意：`sm_rdm_rescan` **不会**让本回合已经打开过的复活门重新发光。

## Debug 中值得观察的输出

扫描时：

```text
[RDM] MARKED door #123 ...
[RDM] Scan complete: rescue points=6, votes=6, marked doors=2, opened doors skipped=0.
```

第一次开门时：

```text
[RDM] Door #123 hammerid=456 opened: marker removed for the rest of this round.
```

之后手动 `sm_rdm_rescan`：

```text
[RDM] Skipped door #123: already opened earlier this round.
```

## 第一轮实测建议

建议先在一张确定有复活房的官方地图测试以下四项：

1. 未开启的复活门是否正常黄色高亮；
2. 普通门是否没有被误标；
3. 高亮门是否仍能像原版一样直接按 E 打开；
4. 门一开始打开时，高亮是否立即消失，并且之后关回去也不再出现。

如果这四项正常，再用第三方战役测试识别兼容性。
