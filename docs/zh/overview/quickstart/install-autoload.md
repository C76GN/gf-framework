# 安装与 AutoLoad

从 [GitHub Releases](https://github.com/C76GN/gf-framework/releases) 选择所需版本。把安装包解压到项目根目录，与 `project.godot` 同一级。

| 你的项目 | 下载 | 解压后 |
| --- | --- | --- |
| 新建 Windows x64 项目，希望直接用原生加速 | `gf-framework-windows-x86_64-<version>.zip` | 同时得到 `addons/gf` 和 `addons/gf_native` |
| Linux x86_64（glibc 2.34+）、Android arm64-v8a/x86_64（API 24+）、iOS arm64（15+）项目使用原生加速 | `gf-framework-<version>.zip` 加同版本 `gf-native-multiplatform-<version>.zip` | 得到 GF 和对应平台的预编译库，含 Apple Silicon 编辑器和 iOS 模拟器 |
| 只用 GDScript | `gf-framework-<version>.zip`，也可从 Godot Asset Store / Asset Library 安装 | 得到完整的 `addons/gf` |
| 已装同版本 GF，希望加入 Windows x64 原生能力 | `gf-native-windows-x86_64-<version>.zip` | 只增加 `addons/gf_native` |

打开 Godot，在 `Project > Project Settings > Plugins` 启用 `GF Framework`。Godot 在导入时加载原生库。项目开发者和玩家都无需安装 Rust。请在项目中仅保留一份原生库；如需移动，可以整体移动 `gf_native` 目录。

iOS 设备版可以直接使用 Godot 的官方导出模板。Godot 4.7.2 在 Apple Silicon 模拟器上还需要带 arm64 引擎的模板。在本仓库原生 CI 的成功运行中下载 `godot-ios-simulator-template`，解压出 `ios.zip`，将 iOS 导出预设的 **Custom Template → Debug / Release** 都设为此文件，并为移动端选择 **Compatibility** 渲染器。下载过期后，可在 Apple Silicon Mac 上按同版本 GF 源码中 `native/gf_native/README.md` 的步骤重建模板。[Godot 4.7.2 模板重建步骤](https://github.com/C76GN/gf-framework/blob/b684edaddb221a340d597dcd6767a5cfc6515f0c/native/gf_native/README.md#rebuild-the-godot-472-simulator-template) · [Godot 上游问题](https://github.com/godotengine/godot/issues/122379)

插件启用后会自动注册：

```text
Gf -> res://addons/gf/kernel/core/gf.gd
```

这个登记保存在项目设置中。关闭编辑器后，直接运行项目或导出的游戏都能使用 `Gf`。在插件面板明确禁用 GF 时，插件只移除自己创建且仍指向 GF 核心脚本的登记。项目原有的同名登记由项目管理。

插件也会默认打开独立的 `GF Workspace`，其中 `GF Extensions` 页面用于查看扩展信息、按需启用默认关闭的可选扩展、控制扩展 Installer 是否自动装配，以及控制导出时是否排除禁用扩展。扩展机制的完整说明见 [GF 内置扩展总览与扩展规范](../../extensions/index.md)。

使用 [Data Batch 的整型行筛选](../../extensions/data-batch/index.md#可选原生-gather)时，在 `GF Extensions` 中启用 Data Batch。相同的业务脚本可以在两种安装包中运行。

升级时先关闭 Godot，提交或备份项目，再用新版本的完整目录替换 `addons/gf`。若安装了原生库，同时替换它所在的目录，使两者版本一致。曾使用 GF 10 模块化安装器的项目，应先按[从 GF 10 模块化安装迁移](package-manager-migration.md)完成迁移和备份。

如果只想先了解完整文档地图、源码分层和所有页面职责，回到 [首页](../../index.md)。

需要移除框架时，不要直接删除 `addons/gf`。按[卸载、清理与恢复](uninstall.md)先禁用插件并核实 AutoLoad 所有权，再处理文件和遗留状态。
