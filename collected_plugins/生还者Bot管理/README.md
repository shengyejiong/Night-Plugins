# 生还者 Bot 管理

版本：1.11.8-night.1

作者：DDRKhat、Marcus101RR、Merudo、Lux、Shadowysn、sorallll、night

基于 2026-10-28 服务器快照里的 `bots` 1.11.8。只将 `!spec` 开放给普通玩家，沿用原有的纯旁观处理。

- `!spec`：转纯旁观。原本已闲置时先解除与原 Bot 的绑定；指令本身不会踢 Bot。
- `!afk`：临时闲置，保留 Bot 绑定。
- `!away`：管理员专用，仍走原有纯旁观处理。

继续使用服务器已有的 `bots.cfg` 和 `gamedata/bots.txt`。Bot 数量及刷特人数规则未改；如果 Bot 仍留在生还队，仍可能被计入刷特人数。
