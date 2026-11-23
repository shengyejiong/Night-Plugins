# AST 插件合并筛选台账

更新：2026-11-17。以 [AST 本地副本 c0d829f](https://github.com/Sglight/L4D2-AstMod-Scriptings/tree/c0d829fbb7b3e3a157e66459197fd02b1b6b72db)、2026-10-28 VPS 快照、Night-Plugins 现有源码及 [Anne 台账](Anne插件合并筛选台账.md) 为基线。只读本地副本，未拉取或操作线上。

范围：仓库根目录的 **31 个 `.sp` 源码入口**。`AI_HardSI/`、`nativevotes/` 和 `include/` 不另计；按使用方核对。没有用源文件清单推断线上实际加载项。

进度：**已核对 8**，**待逐项核对 23**。分组只表示筛选顺序；有同类功能的先核对差异，沿用过去明确的决定。有价值的功能再考虑单独移植，并提供能保存的游戏内开关。

## 已核对

| 项目 | 决定 | 核对结果 |
| --- | --- | --- |
| 第 1 项 · [`wave_spawner.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/wave_spawner.sp) | 不装 | 依靠原生导演选点，在 AI 特感刷出前限制波次。源码默认一波预算 3，第一只 AI 特感死后开始 8 秒计时，同波后续击杀在指定时间段内会追加等待；重置时存活特感占用新波预算。不新增刷点。`!si` 是本插件的数量和间隔投票，不接现服 `!x`。依赖 Left 4 DHooks、BuiltinVotes；重置时触发导演计时，部分路径依赖 AST 的 `das_fakedifficulty` 和 `sm_reloadscript`。按事件和定时器处理，开销未实测。和现服 `specialspawner_fullslots` 职责重叠，叠加可能拦掉现有刷特；用户认为没有必要，决定不装。 |
| 第 2 项 · [`jointeam.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/jointeam.sp) | 不加 | 等已连接玩家完成加载，再倒计时约 10 秒；提前触发离开安全区会被传回。等待依据是进服状态，不检查真人是否接管 Bot，源码也没有冻结 Bot 的逻辑；不能加快换图或保证修好进图闲置。换图后开启全局无敌和无限弹药，出门后关闭，并重置背包、发止痛药；默认不留生还者 Bot，出门时会踢 Bot、修改生还者上限，也注册 `!spec` 等命令。依赖 Left 4 DHooks、SDKTools；等待时每秒检查连接，无实测开销。10 月 28 日快照已有 `bots.smx`、换图和过渡插件，职责会交叉。用户认为用不到，决定不加。Bot 先走问题留待单独排查。 |
| 第 3 项 · [`jointeam_hunter.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/jointeam_hunter.sp) | 不加 | AST 的猎人玩法用入队变体。仍等玩家加载、倒计时、提前出门传回，开局有无敌和无限弹药，出门发药；不按 Bot 接管状态放行。相较第 2 项，不在出门时主动踢生还者 Bot，但 `!join` 写死最多 4 名真人生还者，缺人时尝试补 Bot；`!spec` 仍和现服重复。会每帧查找真人感染者，条件成立时每帧创建转旁观的延时计时器；也监听 Hunter 上限来执行对应的 `cmt` 配置。依赖 Left 4 DHooks 和 SDKTools；实服开销未测。用户认为用不到，决定不加。 |
| 第 4 项 · [`difficulty_adjustment_system.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/difficulty_adjustment_system.sp) | 不加 | 按生还队内非闲置真人数量切换配置档，默认 1／2／3／4 人对应简单／普通／高级／专家档，默认 5 人及以上没有切档分支。当前源码不要求真人存活；不直接改原生 `z_difficulty`，只更新 AST 档位并执行对应 CFG；缺失时生成的 CFG 只有注释和空行。启用后每秒统计客户端，且有入队后的延时检查，实服开销未测。10 月 28 日快照的 `!x` 管刷特，`l4d2_flow_difficulty` 按团灭和地图进度投票减难，另有管理员手动改原生难度；触发条件和职责不同。照搬四人档对多人服收益有限，若预设写到同一批设置还可能覆盖手动调整，用户认为没必要，决定不加。 |
| 第 5 项 · [`AI_HardSI.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/AI_HardSI.sp) | 不加 | AST 的整套 AI 特感增强。出安全区后默认每 2 秒催进攻；Hunter 连扑和改扑角，Smoker 在近距离主动出手（初始化虽注释，按键分支仍在），Boomer 连跳及加快／辅助喷吐，Charger 延后远距离冲锋并在出招时有条件换目标，Jockey 连跳并在合作模式骑中时使附近生还者踉跄，Tank 连跳及投石窗口重瞄。此版 Spitter、Witch 模块没有实际增强。现服已有强攻插件与 `!tankdiff` Hunter 连扑／Tank 投石后重瞄；实现不完全相同，但整装会叠加进攻规则，并把用户已移除的 Smoker 主动出手带回。依赖 Left 4 DHooks、SDKTools、SMLib 及 Boomer 喷吐签名；在高频输入回调中判断距离或视线，Tank 重瞄时可能遍历生还者，未实测开销。用户认为用不到，整套及所拆功能均未选用。 |
| 第 6 项 · [`mob_interval_limit.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/mob_interval_limit.sp) | 不加 | 对经过 Left 4 DHooks `L4D_OnSpawnMob` 的普通尸潮请求进行全局限流：放行一次后，默认 8 秒内拦掉后续请求，插件不排队补刷；放行的请求数量最多为 `z_mega_mob_size`。源码把 `mob_spawn_limit_enabled` 的变量句柄当布尔值判断，没有读取其值，配置为 0 也不会关闭这段逻辑。另有服务器命令可锁定三项尸潮数量参数。使用生成回调和一次性冷却计时，无逐帧扫描。10 月 28 日快照未见同名；现服刷特不管普感。它和 Anne 第 165 项的每图事件配额不同，可能削弱重叠尸潮；用户认为用不到，决定不加。 |
| 第 7 项 · [`autowipe.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/autowipe.sp) | 不加 | 出安全区后逐帧检查生还者：剩余活人全被控时等 1 秒，全员非被控即倒地的其他情况等 5 秒，届时若仍无人能行动且不是全员倒地，就按被控时记录的血量结算（扣血参数默认 40），扶起还活着的倒地者、清掉非 Tank 特感。血不够会记一次倒地并可能进入黑白或死亡，已死玩家不会复活。源码只在抓人事件记录血量，混合倒地时部分成员可能没有本次有效快照。依赖 Left 4 DHooks 和 SDKTools，有逐帧扫描，实服开销未测。10 月 28 日快照的动态减难按实际团灭和进度投票，与这里直接解控、改血不同。用户认为用不到，决定不加；保留原生倒地和失败判定。 |
| 第 8 项 · [`l4d2_bot_spit_ignite_gascan.sp`](https://github.com/Sglight/L4D2-AstMod-Scriptings/blob/c0d829fbb7b3e3a157e66459197fd02b1b6b72db/l4d2_bot_spit_ignite_gascan.sp) | 部分合并到 4.4.14，改进于 4.4.15 | 目的是让酸液点燃可拾取的油桶，默认开启。游戏检查酸液能否伤到油桶时累计回调次数，按 `gascan_spit_time` 延时，够次数就把当初记录的油桶实体血量设为 0，未实测是否点燃。所有酸池和油桶共用计数，多个桶能互相凑次数；计时器只存实体编号，回调时不确认仍是原桶，且没有换图取消标记。名称虽写 AI，源码未验证酸液来源或模式。依赖 Left 4 DHooks；用伤害判定回调和一次性计时器，无持续扫图。10 月 28 日快照未见同名。现服 `l4d2_acid_damage_fix` 的扣血过滤只处理生还者，公共酸液接触范围可能间接影响油桶候选；`l4d2_uniform_spit` 超过玩家跳伤上限时可移除整个酸池，也可能间接打断判定。触发阈值为 `ceil(gascan_spit_time / 0.199951)` 次回调，例如 2.9 秒需 15 次；快照未记录实际变量值。AST 不查拾取历史；原地桶是否进回调、归零是否引燃需实测。现有 `l4d_explosion_announcer` 依赖有效伤害者或破坏事件来源，AST 没有把口水来源传给它。用户选用独立计时、带来源伤害和现有播报，并要求默认开启；实现见下。 |

### 第 5 项细拆：AI_HardSI 1.1

| 模块 | 生效行为与源码默认值 | 和现服比较 |
| --- | --- | --- |
| 全局强攻 | 第一名生还者离开安全区后，默认每 2 秒向游戏下达一次 AI 进攻指令；源码没有回合结束时清理这条重复计时器的逻辑。 | VPS 快照已有 `aggresive_specials_patch`，作用有重叠，实现不同。 |
| Hunter（猎人） | 禁止 Bot 用副攻击抓挠；着地、蹲着、看得到生还者且在 1000 单位内时，按原有 `z_lunge_interval` 排队起扑。被瞄且距最近生还者超过 200 单位时可随机偏转并调整俯仰；默认正面避墙分支关闭，但起扑仍做射线检查。另写全局进攻距离 10000、准备距离 500、受击跳退距离 0、原生最大起扑仰角 0，以及扑击伤害打断参数 150。 | 与现有连扑重叠；随机斜扑和全局打断参数是额外变化。 |
| Smoker（舌头） | 未被推的 Bot 若距最近生还者不足 100 单位，会同时按主副攻击。初始化里的血量／出舌延迟改动与断舌自杀均未启用。 | 会重新引入此前明确删除的近距离主动出手。 |
| Boomer（胖子） | 全局喷吐前摇设 0.1 秒，暴露容忍时间设 10000；AI 连跳默认开启。AI 有效喷吐时，直接给范围内可见生还者上胆汁，不另做正面锥形角度检查，可命中不在正前方的人。插件的辅助上胆汁在出生约 1 秒后解锁，被推后约 1.5 秒解锁，并使用游戏喷吐间隔控制重复触发。 | 风险主要是多人同时中胆汁；不等于只把原版喷吐快一点。 |
| Charger（牛） | 默认距离超过 300 单位且血量高于 350 时先压住技能冷却；贴近或血量降到门槛以后解除限制。出招时如果没瞄着生还者，或当前目标在看它，可能换近处目标并转向；只按当前位置瞄准。 | 是 AI 冲锋时机／选靶规则，和快照里的重复角色碰撞修复是两回事。 |
| Jockey（猴子） | 全局跃击范围参数设 1000；AI 在有视线且靠近至 500 单位内时交替普通跳和飞扑，被推后暂停。合作等模式骑中时，会使受害者 50 单位内未被控的其他生还者踉跄；该事件本身没有限制攻击者必须是 Bot。 | 会影响近身救控，和现有骑人命中框／空爆修复不重复。 |
| Tank | 默认开启 AI 连跳；看得见人且已有一定速度时跳跃加速，近身还会跳着出拳。投石按键松开后约 0.25～4 秒的窗口内，如当前未瞄到可见目标，可转向最近的可见且未倒地生还者。此外把腰间投石动作替换成两种过肩投石动作之一。 | 现有重瞄是在石头离手后恢复追踪；AST 的投石窗口转向更主动，还另改连跳和投石动作。 |
| Spitter／Witch | 模块初始化和卸载为空，Spitter 输入分支被注释，没有独立的吐酸或 Witch 行为强化。 | 不影响现有死酸修复的功能范围。 |

性能：全局强攻是定时器；各职业增强多在 AI 输入回调运行。胖子、Tank 等分支会扫描候选目标、检查视线，不能按只有事件监听来估算开销。数值来自本地源码，未在 Linux 实服或多人满刷场景测量。

### 第 8 项落地：油桶点燃与来源播报

- 用户确认战役服的 `gascan_spit_time` 为 2.9 秒，功能默认开启，只处理生还者拿过后放到地上的桶。
- `!tankdiff` 4.4.14 按桶记录同一片酸液的接触开始时间和攻击者用户 ID，脱离、换酸池、重新拿起或换图会重置，取消 AST 原版的全局计数。
- 通过引擎伤害流程以 Spitter 为攻击者，保留 SDKHooks 回调；沿用现有 `l4d_explosion_announcer` 的破坏事件和游戏名，不改播报插件、不另发聊天。只在有已拾取桶及酸池时，每 0.2 秒查接触，不扫全图。
- 4.4.15 新增跟随每桶采样轮询的黄色闪烁，拾取时清警示；默认关闭的诊断日志可对照提交伤害、拾取与游戏判定烧毁的时序。源码没有拾取时补伤的路径，已提交给引擎的伤害无法撤销，偶发抱起瞬间爆炸仍需实服日志确认来源。
- 本地编译通过。需实服确认引擎烧毁、已有播报的归因和同一桶的播报次数。新签名文件未加载时只停用此功能。

## 待逐项核对

**优先核对：战役玩法和难度**

- `weapon_slowdown.sp`
- `challenge.sp`

**优先核对：小功能和反馈**

- `HunterSkeetSound.sp`
- `l4d2_sniper_stats.sp`
- `l4d_drop.sp`
- `l4d2_drop.sp`
- `l4d2_votetospec.sp`
- `pills_giver.sp`
- `CommandShortcut.sp`

**初筛：可能与现服或 Anne 重叠**

- `ACS.sp`
- `all4dead2.sp`
- `l4d2_hunter_no_deadstops.sp`
- `pause.sp`
- `survivor_mvp.sp`
- `versus2coop.sp`
- `l4d_boss_percent.sp`
- `l4d_boss_percent_hunter.sp`
- `l4d_boss_vote_hunter.sp`
- `wingman.sp`

**初筛：整套配置或配套工具**

- `confogl_autoloader.sp`
- `script_reloader.sp`
- `server.sp`
- `vote.sp`
