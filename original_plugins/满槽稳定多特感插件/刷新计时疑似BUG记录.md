# Special Spawner 刷新计时疑似 BUG 记录

记录日期：2026-09-15  
检查版本：`specialspawner_fullslots 1.3.11-night`  
相关源码：[specialspawner_fullslots.sp](addons/sourcemod/scripting/specialspawner_fullslots.sp)

## 背景

服务器生还者总人数超过 7 人后，特感容易出现连续生成、压力骤增的现象。检查人数成长公式时，发现正常刷新计时器可能使用了生成前的特感数量来安排下一轮刷新。

目前服务器配置中与此现象关系较大的参数如下：

```text
ss_base_limit "6"
ss_extra_limit "2"
ss_base_size "5"
ss_extra_size "1"
ss_time_min "3.0"
ss_time_max "13.0"
ss_time_mode "1"
```

其中 `ss_time_mode 1` 表示场上剩余特感越少，下一轮等待时间越短；场上没有特感时使用 `ss_time_min`。

## 涉及代码

问题位于 `tmrSpawnSpecial()`：

```sourcepawn
Action tmrSpawnSpecial(Handle timer) { 
	g_hSpawnTimer = null;
	delete g_hRetryTimer;

	int totalSI = GetTotalSI();
	ExecuteSpawnQueue(totalSI, 0, true, false);

	g_hSpawnTimer = CreateTimer(
		g_iSpawnTimeMode > 0
			? g_fSpawnTimes[totalSI]
			: Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax),
		tmrSpawnSpecial
	);
	return Plugin_Continue;
}
```

执行顺序为：

1. 调用 `GetTotalSI()`，记录生成前的场上特感数量。
2. 调用 `ExecuteSpawnQueue()` 生成本批特感。
3. 继续使用生成前保存的 `totalSI` 计算下一轮等待时间。

代码没有在本批生成完成后重新统计场上的实际特感数量。

## 具体影响示例

以 8 名生还者为例，按当前人数公式计算：

```text
特感上限 = 6 + 2 × (8 - 4) = 14
每批数量 = 5 + (8 - 4) = 9
```

刷新时间模式 1 的计算结果约为：

```text
单位时间 = (13 - 3) / (14 - 1) ≈ 0.769 秒
场上 0 只特感：下一轮等待 3.00 秒
场上 9 只特感：下一轮等待约 9.92 秒
```

假设计时器触发前场上没有特感：

1. `totalSI` 被记录为 `0`。
2. `ExecuteSpawnQueue()` 尝试生成 9 只特感。
3. 即使 9 只全部成功生成，下一轮仍按 `g_fSpawnTimes[0]` 设置为 3 秒。
4. 3 秒后插件会再次尝试生成剩余的 5 只，将场上数量迅速补到 14 只上限。

这会形成“一大批刚出现，约 3 秒后又立刻补一批”的体感。人数越多，每批数量和特感上限越大，该现象越明显。

## 疑问与设计意图

需要向原作者确认以下问题：

1. 下一轮等待时间原本应该根据“本批生成前”的特感数量计算，还是根据“本批生成后”的实际特感数量计算？
2. `ss_time_mode 1` 的设计目标是尽快把特感数量分批填满上限，还是让已经生成的本批特感先获得一段行动时间？
3. 当一批计划生成 9 只、实际只成功生成一部分时，下一轮时间是否应该根据实际成功数量计算？
4. 由客户端满槽或出生点查找失败触发的 1 秒缺额重试，是否应该影响下一轮正常刷新时间？
5. “杀得越快刷得越快”是否只应反映玩家击杀后的场上剩余数量，而不应忽略本次刚生成的特感？

## 候选修正方式

如果设计目标是让下一轮时间反映当前真实压力，可以在生成后重新统计：

```sourcepawn
int totalBeforeSpawn = GetTotalSI();
ExecuteSpawnQueue(totalBeforeSpawn, 0, true, false);

int totalAfterSpawn = GetTotalSI();
g_hSpawnTimer = CreateTimer(
	g_iSpawnTimeMode > 0
		? g_fSpawnTimes[totalAfterSpawn]
		: Math_GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax),
	tmrSpawnSpecial
);
```

这样在上述 8 人示例中，如果本批成功生成 9 只，下一轮正常刷新时间会由约 3 秒变为约 9.92 秒。如果只成功生成 6 只，则按 6 只的实际压力计算，而不是按计划数量或生成前数量计算。

## 当前结论

从“刷新时间应反映当前场上特感压力”的理解来看，这是一处疑似计时逻辑错误，并且会与高人数下快速增长的特感上限、单批数量叠加，造成连续灌特。

但如果原设计就是先按最低间隔连续生成，直到尽快接近特感上限，那么当前行为属于设计选择而不是 BUG。建议确认原作者意图后，再决定是否修改源码。

本文档仅记录分析结果，尚未修改 `specialspawner_fullslots.sp`、编译文件或服务器配置。
