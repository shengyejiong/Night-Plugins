# L4D2 Multi-SI Campaign Experience（多特经验分）

作者：night  
版本：1.7.0

根据玩家每回合表现计算本关分数，并维护长期经验分与个人排名。

## 游戏内指令

- `!mexp`：查看个人长期经验分。
- `!mexp_round`：查看本回合统计。
- `!mexp_enable`：管理员打开计分开关菜单，也可附加 `0` 或 `1` 快速切换。

## 注意事项

- 长期数据保存在 `addons/sourcemod/data/l4d2_multisi_exp.txt`。
- 空爆、秒救等技巧分需要 `l4d2_skill_detect` 提供数据。
- 完整计分说明、更新日志和后续计划保存在 [`docs`](docs/) 中。

