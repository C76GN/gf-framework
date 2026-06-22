# GF Workspace

`GF Workspace` 是核心插件固定提供的独立编辑器窗口。它把 GF 自带的扩展管理、输入映射、信号诊断和诊断快照等基础面板收束到一个响应式工作区，避免多个 GF 面板挤占 Godot 底部栏。存档图、Flow 等业务型工具页面只在对应可选扩展显式启用后，通过 manifest 贡献到同一个工作区。

窗口右上角的“置顶”开关可让独立工作区保持在其他窗口上方，便于一边操作编辑器或运行窗口一边观察调试页面。

## 打开与布局

插件启用或编辑器打开项目时，GF 会默认弹出工作区窗口；关闭窗口后，可从 `工具 > GF > 打开 GF 工作区` 再次打开。

工作区顶部提供自动换行的短页面入口，完整页面名保留在 tooltip；页面默认按“状态、输入、存储、信号、诊断、扩展、保存、流程”的产品顺序展示，未启用扩展贡献的页面不会占位。标准库页面通过记录里的 `order` 和 `short_label` 声明顺序与短标签，扩展页面通过 manifest 的 `editor_dock_order` 和 `editor_dock_short_label` 声明对应信息，核心插件只按记录排序。

内容区仍只显示当前页面，避免多个工具同时挤压。每个页面都会放进无最小高度的裁剪容器，页面内容不会把窗口撑坏。右上角的“关于”按钮会打开 GF Framework 简介，并提供项目地址、正式文档地址、Issues、Releases、维护者联系方式和手动最新版本检测入口。检测到 GitHub Releases 存在更高版本时，关于弹窗会显示“打开更新页面”按钮，跳转到对应 Release；GF 不会在编辑器运行中自动覆盖 `addons/gf`，以避免丢失本地修改或替换正在加载的插件脚本。

内置页面共享 `GFEditorWorkspaceUI` 提供的页面根、工具栏、摘要、空状态和详情输出构建方式。新增页面应优先复用这些通用控件，再把真正的业务无关编辑逻辑放在页面自身脚本中，这样工作区的密度、状态颜色、空态文案和只读详情区会保持一致。

## Extensions 页面

`GF Extensions` 页面用于查看 `gf_extension.json`、显式启用或禁用默认关闭的内置可选扩展、检查 manifest 状态、扫描禁用扩展引用并保存扩展相关设置。

面板里的三个开关含义不同：

- `自动装配启用扩展 Installer`：`Gf.init()` / `Gf.set_architecture()` 时执行启用扩展 manifest 声明的 `installer_paths`。
- `导出时排除禁用扩展`：导出阶段跳过禁用扩展根目录下的文件。
- `引用禁用扩展时阻止导出`：导出审计发现项目仍引用禁用扩展时，以错误形式报告，适合发布前或 CI 使用。

扩展启用状态不会让编辑器中的脚本或 `class_name` 立刻消失。它影响的是扩展 Installer 是否自动参与运行时装配，以及导出时是否排除禁用扩展目录。禁用或删除扩展前，应先清理项目脚本、场景、资源、preload 和已生成访问器中的直接引用。

## Package Manager 页面

`GF Package Manager` 页面用于从 GF registry、registry source 或 offline bundle 安装模块化 package。空项目可以直接安装 package 闭包完成 GF bootstrap；已经安装 GF 的项目会读取 `addons/gf/plugin.cfg` 中的框架版本，并在刷新状态、预览安装和真实安装前检查 registry 与 package 的 `minimum_framework_version` / `maximum_framework_version_exclusive` 兼容范围。

默认在线源会优先指向当前 GF 版本对应的 release registry source，避免旧框架项目无意间读取最新 registry。自定义 registry source 或 offline bundle 仍可用于团队内分发，但应与目标项目的 GF 主版本线匹配；不兼容时页面会显示失败原因，安装流程不会下载 archive、写入 lockfile 或覆盖项目文件。

只安装 `gf.kernel` 的项目也可以直接使用 Godot 原生命令行入口，不需要 Python：

```powershell
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- status
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- install <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- update [<package-id>...] [--all-installed]
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- uninstall <package-id>...
godot --headless --path . --script res://addons/gf/kernel/package/gf_package_cli.gd -- verify
```

常用参数包括 `--registry`、`--channel`、`--project-root`、`--lockfile`、`--cache-dir`、`--dry-run`、`--all-installed`、`--force` 和 `--json`。`status` 用来查看 registry 中有哪些 package、哪些已安装、哪些可安装或可更新；`install` 会根据依赖闭包安装新 package；`update` 只更新 lockfile 中已经安装的 package，可显式指定 package id，也可用 `--all-installed` 对齐全部已安装 package；`uninstall` 会按 lockfile、依赖关系和项目引用检查卸载风险；`verify` 用来检查 lockfile 与当前 registry 是否一致。

Package Manager 不是正在运行的 GF 框架自更新器。使用默认源时，GF `1.0.0` 项目执行 `install gf.kernel` 仍然会对齐 `1.0.0` registry；要升级到 GF `1.0.1`，应先用 GF `1.0.1` release 替换框架，再刷新 Package Manager 或运行 `status`，最后用 `update --all-installed` 同步已安装 package。

已安装 package 以 `.gf/packages.lock.json` 为准。手动替换或升级 `addons/gf` 不会自动同步更新 lockfile 中的 package；升级 GF 后应先刷新 Package Manager 或运行 `status`，再对需要对齐当前 registry 的 package 执行 `update <package-id>` 或 `update --all-installed`。`update` 不会隐式安装未在 lockfile 中的 package，新增功能包仍使用 `install`。
