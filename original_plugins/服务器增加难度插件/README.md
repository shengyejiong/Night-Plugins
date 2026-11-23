# 服务器增加难度插件

主插件：L4D2 Campaign Difficulty Options 4.4.15

作者：Visor、A1m、Forgetest、CanadaRox、Sir、Harry Potter、Derpduck、night

独立 Hunter 插件作者：Visor、A1m、night

集中控制 AI Tank、特感行为、推击、起身、石头和其他战役难度选项，并附带独立的 Hunter 空中防推插件。

## 游戏内指令

- `!tankdiff`：打开战役难度选项菜单。
- `!tankdifficulty`：打开同一菜单。

## 注意事项

- 依赖 Left 4 DHooks；Linux Actions 扩展和所需 gamedata 已随插件保存。
- `l4d2_no_hunter_deadstops.smx` 是独立的 Hunter 防推插件，不要同时启用主插件中的同类功能。
- Jockey 骑人命中框修复已内置，默认开启；可与飞扑空爆共存，同款独立命中框修复只需保留一份。
- 4.4.3 新增隐形死酸位置修复，默认开启；增量更新需同时上传 SMX 与 `gamedata/l4d2_difficulty_invisible_deathspit.txt`。只检查新生成死酸，不追溯已有酸液；缺签名文件只停用此选项。
- 4.4.4 新增 Ellis 被 Hunter 扑后的起身时长统一，默认开启，可在 `!tankdiff` 单独切换和保存；只加速该动画片段。
- 4.4.5 新增「持近战挨 Tank 拳后切主枪」，默认开启，可在 `!tankdiff` 单独切换；只抽取 Anne 对抗的切枪规则。
- 4.4.9 将 Anne 生还者 Bot 增强移出当前包并标为待办，移除菜单联动，不恢复早期内置的 Bot 救控或拦石。其他战役难度选项保留。
- 4.4.10 新增「AI Tank 战后清理打过的物件」：最后一只 Tank 死后等 15 秒，再移除仍在地图上的、被 AI Tank 直接打过的可打物件。默认开启，在 `!tankdiff` 可单独切换并保存。
- 4.4.11 新增「禁用原生辅助瞄准」，默认开启（也会关闭手柄辅助）。有 SourceMod 变量权限的管理员可在 `!tankdiff` 切换并保存。需要[辅助瞄准签名文件](addons/sourcemod/gamedata/l4d2_difficulty_block_autoaim.txt)。
- 4.4.12 新增「材质调试项检查」，默认开启。在队真人的 `mat_texture_list` 值大于 0，或客户端明确返回不存在、无效、受保护时踢出，并告知具体理由。有变量权限的管理员可在 `!tankdiff` 切换并保存。
- 4.4.13 新增「隐藏变量变更和 ! 命令原文」，默认开启。有 SourceMod 变量权限的管理员可在 `!tankdiff` 切换并保存。只隐藏游戏自带的变量变更广播和已识别的 `!` 命令原文，命令照常执行。
- 4.4.14 新增「Spitter 酸液点燃油桶」，默认开启。只处理生还者拿过又放到地上的汽油桶，每桶单独计时；连续接触同一片酸达到 `gascan_spit_time` 后，以 Spitter 为攻击者尝试走游戏的伤害流程，由现有油桶播报负责显示。管理员可在 `!tankdiff` 切换并保存。需要[酸液接触签名文件](addons/sourcemod/gamedata/l4d2_difficulty_spitter_gascan.txt)。
- 4.4.15 为受酸计时的油桶加上黄色闪烁，和自身的 0.2 秒接触检查同步。移出酸池或抱起会取消警示并重置未结算的计时。新增默认关闭的诊断日志，用于区分插件提交伤害和引擎实际烧毁油桶的时刻。
- 更完整的选项和来源说明保存在 [`docs`](docs/) 中。
- [Anne 插件合并筛选台账](docs/Anne插件合并筛选台账.md)：记录已筛选、现服同名项和待筛选的功能。
