# 安装与 AutoLoad

将 `addons/gf` 复制到目标项目，然后在 Godot 的 `Project > Project Settings > Plugins` 中启用 `GF Framework`。

插件启用后会自动注册：

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

插件也会默认打开独立的 `GF Workspace`，其中 `GF Extensions` 页面用于查看扩展信息、按需启用默认关闭的可选扩展、控制扩展 Installer 是否自动装配，以及控制导出时是否排除禁用扩展。扩展机制的完整说明见 [GF 内置扩展总览与扩展规范](../../extensions/index.md)。

如果只想先了解完整文档地图、源码分层和所有页面职责，回到 [首页](../../index.md)。
