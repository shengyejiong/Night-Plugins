# 文明聊天，人人有责

作者：Seiunsky Maomao  
版本：1.1  
原项目：<https://github.com/NanakaFathry/L4D2-Plugins>

检测玩家聊天内容，并按照规则替换指定词语或整句内容。

## 游戏内指令

- `!bszh_reload`：重新加载敏感词替换规则，需要 Root 管理员权限。

## 注意事项

- 规则文件首次运行时生成在 `addons/sourcemod/data/BieShuoZangHua.txt`。
- 默认 SMX 使用 SourceMod 1.12-7210 编译；SourceMod 1.11-6970 备用版本保存在 `alternate_builds`。
- 两个版本的 SMX 文件同名，不要同时使用。
- 源码未启用 `AutoExecConfig`，插件 CVar 不会自动写入独立配置文件。

