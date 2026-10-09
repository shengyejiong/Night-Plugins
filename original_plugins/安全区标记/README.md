# [L4D2] Start Safe Area Marker v0.4.1 — Scavenge Style

在战役开局安全区外围显示一圈类似清道夫模式的白色斜纹提示。第一名生还者被 Director 判定离开起始安全区后，整圈标记立即删除。

## v0.4.1 修复内容

- 修复长边经过坡地、路肩或台阶时，部分斜纹陷入地面的问题；
- 每根斜纹的两个端点都会重新读取附近起始安全区 NAV 的局部坡度；
- 随后再用短距离垂直检测贴到实际地图表面，不再只在两个凸包顶点之间插值高度；
- 斜纹的上下端分别取样，因此在斜坡上也会顺着地形倾斜。

## v0.4.0 修复内容

本版针对“显示数量少、边走边闪、部分斜纹断续出现”重做了渲染层：

- 不再按固定间隔重复发送短寿命 TempEntity；
- 每根斜纹改为常驻 `env_beam`，客户端不需要等待下一轮刷新；
- 整个外轮廓一次建立并均匀分配斜纹，不再按玩家距离裁剪；
- 第一名生还者离开安全区、回合结束、换图或卸载插件时，立即删除所有标记实体；
- 自动保留 128 个实体名额；地图接近实体上限时会均匀放宽间距，而不是只画前半圈；
- `ssam_refresh`、`ssam_draw_distance`、`ssam_max_stripes` 仅为兼容旧配置而保留，v0.4.0 已不再使用。

v0.3.0 虽然已经把 NAV 外沿改为连续二维凸包，但仍使用大量短寿命 TempEntity。c2m1 这类开局区域较大的地图会在同一刷新周期发送很多特效，客户端可能丢掉一部分或在不同帧看到不同片段，因此仍会出现少、断、闪的问题。

## 外观与原版的区别

官方清道夫地图是在 Hammer 中用 `func_brush` 配合 `effects/scavenge_boundary` 材质制作边界。SourceMod 运行时不能凭空创建新的 BSP Brush，所以本插件使用一排白色斜向 Beam 模拟 `/ / / / /` 的外观。

插件根据 Director 的起始安全区 NAV 数据生成一个连续的二维外轮廓，再沿整圈放置常驻斜纹。它只提供视觉提示，不阻挡玩家、不锁门、不修改 NAV、Director、特感刷新或安全区规则。

## 安全区识别

1. 通过 `L4D_GetAllNavAreas()` 获取地图 NAV Area；
2. 通过 `L4D_IsPositionInFirstCheckpoint()` 找出起始安全区；
3. 兼容读取这些 NAV Area 的四角坐标；
4. 计算所有角点的二维凸包，得到连续外轮廓；
5. 沿轮廓按等弧长位置建立白色斜纹实体。

凸包会把凹进去的小缺口包在内部，以换取稳定、连续并更接近官图清道夫矩形 Brush 的外观。

## 默认参数

```cfg
ssam_enable "1"              // 0=关闭，1=开启
ssam_stripe_width "3.0"      // 单根斜纹宽度
ssam_stripe_height "34.0"    // 斜纹高度
ssam_stripe_spacing "16.0"   // 目标间距；越小越密
ssam_stripe_slant "13.0"     // 横向倾斜距离；0 会变为竖线
ssam_alpha "220"             // 透明度 0~255
ssam_z_offset "2.0"          // 相对 NAV 地面的起始高度
ssam_max_beams "320"         // 整圈最多使用的常驻斜纹实体数
ssam_survivors_only "1"      // 1=仅生还者可见，0=所有玩家可见
ssam_debug "0"               // 调试日志

// 以下三个只为兼容 v0.3.0 及更早的 cfg，v0.4.0 忽略它们：
ssam_refresh "0.35"
ssam_draw_distance "1400.0"
ssam_max_stripes "160"
```

如果觉得条纹太稀，可以把 `ssam_stripe_spacing` 调到 `12`；如果地图实体很多，不建议盲目提高 `ssam_max_beams`。

旧版配置不会妨碍新插件运行，但建议首次测试 v0.4.0 时删除一次：

```text
left4dead2/cfg/sourcemod/l4d2_start_safe_area_marker.cfg
```

让插件重新生成带 `ssam_max_beams` 的完整配置。

## 管理员命令

```text
sm_ssam_rescan
```

在本回合尚无人离开起始安全区时，重新扫描并建立边界。

```text
sm_ssam_hide
```

立即删除本回合的边界。

## 依赖

- Left 4 Dead 2
- SourceMod 1.12（建议）
- Left4DHooks 1.128+

插件只调用较早版本已有的 `L4D_GetAllNavAreas()`、`L4D_IsPositionInFirstCheckpoint()`、`L4D_HasMapStarted()` 和 `L4D_HasAnySurvivorLeftSafeArea()`；不再依赖曾导致加载失败的 `L4D_NavArea_GetAdjacentAreas()`。

## 安装

目录已经按 `left4dead2` 相对路径整理：

- `addons/sourcemod/plugins/l4d2_start_safe_area_marker.smx`：编译文件；
- `addons/sourcemod/scripting/l4d2_start_safe_area_marker.sp`：SourcePawn 源码。

把本目录中的 `addons` 合并到服务器的 `left4dead2/addons/`。替换 SMX 后建议换图或重开当前地图，不要在已经离开安全区的回合里判断是否生效。

## 测试建议

先设置：

```cfg
ssam_debug "1"
```

然后从一张新加载的地图开始测试：

1. c2m1 开局是否出现完整、稳定的一圈白色斜纹；
2. 站着不动和左右转视角时，斜纹是否还会周期闪烁；
3. 公路护栏附近是否不再只有零散几簇；
4. 坡地、路肩和台阶附近的斜纹底端是否贴地，不再陷入地面；
5. 第一名玩家跨出 Director 安全区后，整圈是否立即消失；
6. 灭团重开后是否重新出现；
7. 再抽查几张第三方战役地图。

正常调试日志类似：

```text
[SSAM] NAV scan: total=xxx, first-checkpoint=xx, unique-corners=xx.
[SSAM] Persistent render: perimeter=xxxx.x, requested=xxx, budget=xxx, created=xxx, effective-spacing=xx.x, entities=xxx/xxxx.
[SSAM] Boundary ready: xx continuous hull edges, xxx persistent stripe entities. No refresh timer is used.
[SSAM] First Survivor left starting safe area: client=1 (...). Scavenge-style boundary stopped.
```

## 已知限制

- 这是 Beam 对官方 Brush 材质的模拟，不会与原版 `effects/scavenge_boundary` 完全一致；
- 第三方地图如果没有正确标记起始 checkpoint NAV，可能找不到边界或得到过大的凸包；
- 常驻斜纹会占用实体名额。插件默认最多建立 320 根，并动态预留 128 个名额；接近地图实体上限时会自动减少数量；
- 二维凸包会封住凹形安全区的缺口，这是当前为连续性和跨地图兼容作出的取舍。

## 实现参考

- [Left4DHooks](https://github.com/SilvDev/Left4DHooks)
- [SourceMod 社区的常驻 env_beam 写法](https://forums.alliedmods.net/showthread.php?t=283011)
- [L4D2 Decompiled Assets](https://github.com/Tsuey/L4D2-Decompiled-Assets)
- [清道夫地图边界制作说明](https://worldofleveldesign.com/categories/left4dead2_mapping/l4d2-how-to-create-scavenge-gamemode-part1.php)
