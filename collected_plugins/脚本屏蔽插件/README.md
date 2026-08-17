# L4D2 VScript Purifier

插件显示名称：`l4d2_ignore_airwall`  
作者：洛琪、Forgetest  
版本：1.2

用于阻止不属于当前地图或白名单的 VScript，减少第三方 VPK 对地图脚本和服务器 CVar 的污染，并可在过关时恢复被脚本修改的 CVar。

## 游戏内指令

无，插件通过自动生成的配置文件和白名单进行控制。

## 注意事项

- 仅支持 Left 4 Dead 2 专用服务器，并依赖 DHooks / DynamicDetour。
- 模式白名单与 VPK 白名单文件会在首次运行时自动生成。
- 当前 1.2 源码把两个白名单开关注册成了同一个 CVar 名称 `l4d2_vscript_modewhiteList`，应将其视为共用开关。
- 插件包含 Detour 和内存修改，替换或更新后建议完整重启服务器。

