# Night Plugins

个人整理的 Left 4 Dead 2 SourceMod（服务器插件平台）插件仓库，主要面向我服战役专用服务器。

- [`original_plugins`](original_plugins/)：night 原创或参与修改、维护的插件。
- [`collected_plugins`](collected_plugins/)：从公开项目收集并重新整理的插件。

每个插件文件夹均以 `left4dead2` 为相对根目录整理。点击下表中的插件名称，可查看游戏内指令、依赖和注意事项。

## 原创及自行维护插件

| 插件 | 作者 / 版本 | 主要功能 | 游戏内指令 | 依赖或备注 |
| --- | --- | --- | --- | --- |
| [抽象操作通报](<original_plugins/抽象操作通报插件/>) | night / 1.1.0 | 通报炸队友、多撞、Witch 责任和高额友伤等操作 | 无 | Left 4 DHooks |
| [胆汁砸队友](<original_plugins/胆汁砸队友/>) | night / 1.0.0 | 胆汁瓶爆炸时使附近队友受到胆汁效果 | 无 | Left 4 DHooks |
| [动态调整子弹上限](<original_plugins/动态调整子弹上限（协同specialspawner插件）/>) | morzlee、night / 1.1.0 | 根据特感数量动态调整备弹上限 | `!da_status`、`!da_recalc` | `specialspawner` |
| [多特经验分](<original_plugins/服务器经验分插件/>) | night / 1.7.0 | 计算回合表现、长期经验分和个人排名 | `!mexp`、`!mexp_round`、`!mexp_enable` | 技巧分可配合 `l4d2_skill_detect` |
| [服务器增加难度](<original_plugins/服务器增加难度插件/>) | Visor、A1m、Forgetest、CanadaRox、night / 4.4.0 | 集中控制 Tank、特感、推击、起身和石头等难度选项 | `!tankdiff`、`!tankdifficulty` | Left 4 DHooks、Actions 扩展及 GameData |
| [开局随机近战](<original_plugins/开局随机生成两把近战/>) | N3wton、night / 1.1.0 | 回合开始时生成一把或两把随机近战武器 | `!melee` | 指令需要管理员权限 |
| [坦克打铁训练](<original_plugins/坦克打铁训练/>) | night / 1.1.0 | 提供可打物件重置、Bot 控制和训练辅助 | `!tanktraining`、`!hittable`、`!tk` | Left 4 DHooks；默认关闭 |
| [修改爪击伤害](<original_plugins/修改爪击伤害/>) | night / 1.0.2 | 只调整特感普通爪击及 Charger 普通拳击伤害 | 无 | 不影响控制、撞墙和砸地伤害 |
| [友伤过高封禁](<original_plugins/友伤过高踢出/>) | night / 1.1 | 每关统计友伤，达到阈值后临时封禁非管理员 | 无 | 默认阈值 100，封禁 5 分钟 |
| [HUD 增加弹量显示](<original_plugins/hud增加显示弹量（基于豆瓣酱插件包）/>) | 豆瓣酱な、sorallll、らくらく安楽死、night / 2.21.31 | 在 HUD 中显示弹药等状态 | `!hud` | 依赖豆瓣酱插件包中的 HUD、模拟及 DHooks 组件 |

## 收集插件

| 插件 | 作者 / 版本 | 主要功能 | 游戏内指令 | 依赖或备注 |
| --- | --- | --- | --- | --- |
| [过场动画不受伤害](<collected_plugins/过场动画不受伤害/>) | HarryPotter / 1.0 | 过场动画期间保护生还者并阻止特感控制 | 无 | Left 4 DHooks |
| [VScript 脚本屏蔽](<collected_plugins/脚本屏蔽插件/>) | 洛琪、Forgetest / 1.2 | 屏蔽非当前地图或白名单中的 VScript | 无 | DHooks / DynamicDetour |
| [禁止速砍](<collected_plugins/禁止速砍/>) | sheo / 2.3 | 修复快速切换武器绕过近战攻击间隔 | 无 | 自动生效 |
| [命中反馈分支](<collected_plugins/命中反馈分支1.1.5(反馈声音玩家自选)/>) | TsukasaSato、Hesh233 / 1.1.5+ | 提供可由玩家选择的击中与击杀反馈 | `!snd` | 自定义素材不会自动分发给玩家端 |
| [舌头拖拽伤害](<collected_plugins/舌头拖拽伤害/>) | Silvers / 未注明 | Smoker 拖拽生还者时持续造成伤害 | 无 | 当前仅保存编译文件 |
| [刷特感控制菜单](<collected_plugins/刷特感插件控制插件/>) | らくらく安楽死、Assistant / 2.9 | 通过投票控制多特开关、数量和刷新间隔 | `!x` | `l4d2_nativevote`、`specialspawner` |
| [针药缓慢回血](<collected_plugins/药改为缓慢回血(可在源码内调整回复量和速度)/>) | ProdigySim、CircleSquared、Forgetest / 2.4 | 将止痛药和肾上腺素改为分段恢复 | 无 | Left 4 DHooks；功能默认关闭 |
| [脏话和谐](<collected_plugins/脏话和谐插件/>) | Seiunsky Maomao / 1.1 | 按规则替换聊天中的指定词语或整句内容 | `!bszh_reload` | 规则保存在 SourceMod 数据目录 |
| [All4Dead 2](<collected_plugins/all4dead/>) | grandwazir、HarryPotter / 未注明 | 通过管理菜单控制导演并生成实体 | `!admin` | 需要管理员权限及配套 GameData |
| [Jockey 空爆](<collected_plugins/Jockey空爆/>) | Visor、A1m\` / 1.4 | 霰弹枪在 Jockey 飞扑途中造成足够伤害时将其空爆 | 无 | 默认伤害门槛 195 |
| [附加手电筒](<collected_plugins/l4d_flashlight/>) | SilverShot / 2.34 | 提供可自定义颜色的附加手电筒 | `!light`、`!lightmenu`、`!lightbow` | 当前配置仅允许死亡生还者使用个人手电 |
| [Hunter 飞扑伤害](<collected_plugins/l4d2_pounce_damage/>) | SilverShot / 1.1d | 让远距离飞扑奖励伤害在所有模式生效 | 无 | 需要配套 GameData |
| [L4D2 Vomit Fix](<collected_plugins/l4d2_vomit_fix-master/>) | lakwsh / 1.1.1、1.0.2 | 修复非 30 Tick 下的喷吐距离，并附带可选 A2S 修复 | 无 | 两个插件均需配套 GameData |
| [Little Anti-Cheat](<collected_plugins/Little-Anti-Cheat-1.7.4_3/>) | J_Tanzanite / 1.7.4 | 检测瞄准、连跳、宏、非法 CVar 等作弊或滥用行为 | 无 | 启用前应检查处罚配置 |
| [R 键给药](<collected_plugins/r键给药/>) | CanadaRox、A1m\`、Forgetest / 1.6.2 | 手持针药时按 `R` 键递给瞄准的队友 | 无 | 可选配合延迟补偿插件 |

## 说明

- 收集插件尽量保留原作者、版本、项目链接和必要依赖；详细信息以各插件目录中的 README 为准。
- 部分收集插件只有编译文件，或需要未包含在对应文件夹中的前置插件，使用前请查看该插件的注意事项。
- 各插件继续遵循其原项目的许可与署名要求，本仓库的整理行为不会改变第三方项目的许可证。
- 仓库不保存服务器密码、管理员名单、玩家数据、日志或运行时数据库。
