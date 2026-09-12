# Night Plugins

个人整理的 Left 4 Dead 2 SourceMod（服务器插件平台）插件仓库，主要面向我服战役专用服务器。

- [`original_plugins`](original_plugins/)：night 原创或参与修改、维护的插件。
- [`collected_plugins`](collected_plugins/)：从公开项目收集并重新整理的插件。

每个插件文件夹均以 `left4dead2` 为相对根目录整理。点击下表中的插件名称，可查看游戏内指令、依赖和注意事项。

## 原创及自行维护插件

| 插件 | 主要功能 | 作者 / 版本 |
| --- | --- | --- |
| [抽象操作通报](<original_plugins/抽象操作通报插件/>) | 通报炸队友、多撞、Witch 责任和高额友伤等操作 | night / 1.1.0 |
| [胆汁砸队友](<original_plugins/胆汁砸队友/>) | 胆汁瓶爆炸时使附近队友受到胆汁效果 | night / 1.0.0 |
| [动态调整子弹上限](<original_plugins/动态调整子弹上限（协同specialspawner插件）/>) | 根据特感数量动态调整备弹上限 | morzlee、night / 1.1.0 |
| [根据路程动态减难](<original_plugins/根据路程动态减难插件/>) | 根据团灭次数和路程分阶减难，并为无主武器玩家提供开局援助 | night / 1.4.0-night |
| [满槽稳定多特感](<original_plugins/满槽稳定多特感插件/>) | 满槽时停止无效特感创建，并在槽位释放后恢复补刷 | Tordecybombo、breezy、night / 1.3.10-night |
| [多特经验分](<original_plugins/服务器经验分插件/>) | 计算回合表现、长期经验分、技巧统计和个人排名 | night / 1.10.6 |
| [服务器增加难度](<original_plugins/服务器增加难度插件/>) | 集中控制 Tank、特感、推击、起身和石头等难度选项 | Visor、A1m、Forgetest、CanadaRox、night / 4.4.0 |
| [开局随机近战](<original_plugins/开局随机生成两把近战/>) | 回合开始时生成一把或两把随机近战武器 | N3wton、night / 1.1.0 |
| [坦克打铁训练](<original_plugins/坦克打铁训练/>) | 提供可打物件重置、Bot 控制和训练辅助 | night / 1.1.0 |
| [修改爪击伤害](<original_plugins/修改爪击伤害/>) | 只调整特感普通爪击及 Charger 普通拳击伤害 | night / 1.0.2 |
| [友伤过高封禁](<original_plugins/友伤过高踢出/>) | 统计站立生还者受到的友伤，达到阈值后临时封禁非管理员 | night / 1.2.0 |
| [HUD 增加弹量显示](<original_plugins/hud增加显示弹量（基于豆瓣酱插件包）/>) | 在 HUD 中显示弹药等状态 | 豆瓣酱な、sorallll、らくらく安楽死、night / 2.21.31 |
| [安全门标记](<original_plugins/安全门标记/>) | 为本回合尚未打开的复活房门添加轮廓高亮 | OpenAI / ChatGPT / 0.2.0 |

## 收集插件

| 插件 | 主要功能 | 作者 / 版本 |
| --- | --- | --- |
| [过场动画不受伤害](<collected_plugins/过场动画不受伤害/>) | 过场动画期间保护生还者并阻止特感控制 | HarryPotter / 1.0 |
| [VScript 脚本屏蔽](<collected_plugins/脚本屏蔽插件/>) | 屏蔽非当前地图或白名单中的 VScript | 洛琪、Forgetest / 1.2 |
| [禁止速砍](<collected_plugins/禁止速砍/>) | 修复快速切换武器绕过近战攻击间隔 | sheo / 2.3 |
| [命中反馈分支](<collected_plugins/命中反馈分支1.1.5(反馈声音玩家自选)/>) | 提供可由玩家选择的击中与击杀反馈 | TsukasaSato、Hesh233 / 1.1.5+ |
| [舌头拖拽伤害](<collected_plugins/舌头拖拽伤害/>) | Smoker 拖拽生还者时持续造成伤害 | Silvers / 未注明 |
| [刷特感控制菜单](<collected_plugins/刷特感插件控制插件/>) | 控制多特开关、数量、刷新间隔和六类特感上限 | らくらく安楽死、night / 3.1.0-night |
| [针药缓慢回血](<collected_plugins/药改为缓慢回血(可在源码内调整回复量和速度)/>) | 将止痛药和肾上腺素改为分段恢复 | ProdigySim、CircleSquared、Forgetest / 2.4 |
| [脏话和谐](<collected_plugins/脏话和谐插件/>) | 按规则替换聊天中的指定词语或整句内容 | Seiunsky Maomao / 1.1 |
| [All4Dead 2](<collected_plugins/all4dead/>) | 通过管理菜单控制导演并生成实体 | grandwazir、HarryPotter / 未注明 |
| [Jockey 空爆](<collected_plugins/Jockey空爆/>) | 霰弹枪在 Jockey 飞扑途中造成足够伤害时将其空爆 | Visor、A1m\`、night / 1.5-night |
| [附加手电筒](<collected_plugins/l4d_flashlight/>) | 提供可自定义颜色的附加手电筒 | SilverShot / 2.34 |
| [Hunter 飞扑伤害](<collected_plugins/l4d2_pounce_damage/>) | 让远距离飞扑奖励伤害在所有模式生效 | SilverShot / 1.1d |
| [L4D2 Vomit Fix](<collected_plugins/l4d2_vomit_fix-master/>) | 修复非 30 Tick 下的喷吐距离，并附带可选 A2S 修复 | lakwsh / 1.1.1、1.0.2 |
| [Little Anti-Cheat](<collected_plugins/Little-Anti-Cheat-1.7.4_3/>) | 检测瞄准、连跳、宏、非法 CVar 等作弊或滥用行为 | J_Tanzanite / 1.7.4 |
| [R 键给药](<collected_plugins/r键给药/>) | 手持针药时按 `R` 键递给瞄准的队友 | CanadaRox、A1m\`、Forgetest / 1.6.2 |

## 常用指令速查

| 插件 | 常用指令 |
| --- | --- |
| [动态调整子弹上限](<original_plugins/动态调整子弹上限（协同specialspawner插件）/>) | `!da_status`、`!da_recalc` |
| [根据路程动态减难](<original_plugins/根据路程动态减难插件/>) | `!fd`、`!flowassist_reset` |
| [满槽稳定多特感](<original_plugins/满槽稳定多特感插件/>) | `!weight`、`!limit`、`!timer`、`!resetspawn`、`!forcetimer` |
| [多特经验分](<original_plugins/服务器经验分插件/>) | `!mx`、`!mr`、`!mra`、`!mw`、`!mxe` |
| [服务器增加难度](<original_plugins/服务器增加难度插件/>) | `!tankdiff` |
| [开局随机近战](<original_plugins/开局随机生成两把近战/>) | `!melee` |
| [坦克打铁训练](<original_plugins/坦克打铁训练/>) | `!tanktraining`、`!hittable`、`!tk` |
| [HUD 增加弹量显示](<original_plugins/hud增加显示弹量（基于豆瓣酱插件包）/>) | `!hud` |
| [安全门标记](<original_plugins/安全门标记/>) | `sm_rdm_rescan`（控制台） |
| [命中反馈分支](<collected_plugins/命中反馈分支1.1.5(反馈声音玩家自选)/>) | `!snd` |
| [刷特感控制菜单](<collected_plugins/刷特感插件控制插件/>) | `!x` |
| [脏话和谐](<collected_plugins/脏话和谐插件/>) | `!bszh_reload` |
| [All4Dead 2](<collected_plugins/all4dead/>) | `!admin` |
| [附加手电筒](<collected_plugins/l4d_flashlight/>) | `!light`、`!lightmenu`、`!lightbow` |

## 说明

- 收集插件尽量保留原作者、版本、项目链接和必要依赖；详细信息以各插件目录中的 README 为准。
- 部分收集插件只有编译文件，或需要未包含在对应文件夹中的前置插件，使用前请查看该插件的注意事项。
- 各插件继续遵循其原项目的许可与署名要求，本仓库的整理行为不会改变第三方项目的许可证。
- 仓库不保存服务器密码、管理员名单、玩家数据、日志或运行时数据库。
