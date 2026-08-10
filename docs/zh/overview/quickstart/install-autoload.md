# 安装与 AutoLoad

普通安装推荐使用 Godot Asset Store / Asset Library 官方页面下载的包，或 GitHub Release 中的 `gf-framework-<version>.zip`。这个包包含完整的 `addons/gf` 插件目录：kernel、standard、编辑器工具、包管理器和随包发布的可选内置扩展。可选扩展默认关闭，只有项目显式启用后才会自动装配。

将包里的 `addons/gf` 复制到目标项目，然后在 Godot 的 `Project > Project Settings > Plugins` 中启用 `GF Framework`。

插件启用后会自动注册：

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

插件也会默认打开独立的 `GF Workspace`，其中 `GF Extensions` 页面用于查看扩展信息、按需启用默认关闭的可选扩展、控制扩展 Installer 是否自动装配，以及控制导出时是否排除禁用扩展。扩展机制的完整说明见 [GF 内置扩展总览与扩展规范](../../extensions/index.md)。

如果项目需要最小引导，可以从 GitHub Release 下载 `gf-kernel-<version>.zip`。启用插件后，打开 `GF Workspace` 中的 [GF Package Manager](../../editor/workspace.md#package-manager)，或使用 `res://addons/gf/kernel/package/gf_package_cli.gd` 命令行入口安装所需 package。这个路径适合受控项目模板、离线分发或团队内部 registry，不是面向首次使用者的默认安装方式。

模块化安装路径只接受 `gf.*` 形式的安全 package id。原生安装器会在写入前校验 registry、依赖闭包、archive 元数据、checksum 和文件边界；`dry-run` 只做解析与校验，不会解压 staging，也不会写入项目。安装后的 lockfile 会记录每个已安装文件的 hash 与大小，后续更新只会删除仍匹配旧元数据的过期文件；如果项目手动改过旧 package 文件，更新会拒绝继续，避免误删本地改动。

如果只想先了解完整文档地图、源码分层和所有页面职责，回到 [首页](../../index.md)。

需要移除框架时，不要直接删除 `addons/gf`。按 [卸载、清理与恢复](uninstall.md) 先禁用插件并核实 AutoLoad 所有权，再处理文件和 package 状态。
