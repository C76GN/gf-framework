# 安装与 AutoLoad

请从 Godot Asset Store / Asset Library 官方页面，或 GitHub Release 中的 `gf-framework-<version>.zip` 安装 GF。这个包包含完整的 `addons/gf` 插件目录：kernel、standard、编辑器工具和随包发布的可选内置扩展。可选扩展默认关闭，只有项目显式启用后才会自动装配。

将包里的 `addons/gf` 复制到目标项目，然后在 Godot 的 `Project > Project Settings > Plugins` 中启用 `GF Framework`。

插件启用后会自动注册：

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

插件也会默认打开独立的 `GF Workspace`，其中 `GF Extensions` 页面用于查看扩展信息、按需启用默认关闭的可选扩展、控制扩展 Installer 是否自动装配，以及控制导出时是否排除禁用扩展。扩展机制的完整说明见 [GF 内置扩展总览与扩展规范](../../extensions/index.md)。

GF 11 只提供完整框架 ZIP，不再提供 Package Manager、包管理命令行或逐模块发布包。升级时先关闭 Godot，提交或备份项目，再用同一个新版本发布包中的完整目录替换整个 `addons/gf`；不要把新文件直接叠加到旧目录，以免已经移除的脚本残留。曾使用 GF 10 模块化安装器的项目，应先按[从 GF 10 模块化安装迁移](package-manager-migration.md)完成旧事务收敛和备份。

如果只想先了解完整文档地图、源码分层和所有页面职责，回到 [首页](../../index.md)。

需要移除框架时，不要直接删除 `addons/gf`。按[卸载、清理与恢复](uninstall.md)先禁用插件并核实 AutoLoad 所有权，再处理文件和遗留状态。
