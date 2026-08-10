# 卸载、清理与恢复

完整 GF 插件卸载的目标不是“把目录删掉”，而是先撤销编辑器注册和项目引用，再移除文件，同时保留恢复一致状态所需的证据。核心顺序是：**先禁用插件，再删除文件**。

## 卸载前确认边界

先确认项目采用哪种安装方式：

- 官方 Store / Asset Library 包或 `gf-framework-<version>.zip`：项目中有完整 `addons/gf`，按本页“完整插件卸载”处理。
- Package Manager、package CLI 或 offline bundle：已安装文件由 `.gf/packages.lock.json` 记录，先按“package 卸载”处理。

在开始前提交或备份项目，并记录当前 GF 版本与安装来源。停止正在运行的游戏、导出任务和 Package Manager 操作；模块化安装如果报告遗留事务，先运行 `recover`，再运行 `verify`。不要在事务仍为 active 或 recovery required 时移动框架文件。

## 完整插件卸载

1. 清理项目脚本、场景、资源、`preload()`、类型声明、Installer 配置和项目生成访问器中对 GF 的直接引用。可选扩展应先在 `GF Extensions` 中禁用并完成引用扫描。
2. 在 Godot 的 `Project > Project Settings > Plugins` 中禁用 `GF Framework`，等待编辑器完成插件退出和项目设置保存。
3. 检查 AutoLoad。禁用时 GF **只移除由 GF 插件登记的 `Gf` AutoLoad**；它**不会删除同名但不指向 GF 的 AutoLoad**。如果项目原本就有自己的 `Gf`，不要手动删除或改写它。
4. 关闭 Godot 编辑器，确保没有编辑器、游戏或命令行进程仍在读取项目。
5. 删除完整的 `addons/gf` 目录，然后重新打开项目，检查脚本解析、场景加载、项目设置和导出配置。只有这些检查通过，卸载才完成。

不要颠倒第 2 步和第 5 步。先删脚本会让插件无法执行对称退出，可能把指向缺失文件的 GF AutoLoad 或编辑器注册留在 `project.godot` 中。

## 默认保留哪些状态

首次重新打开并验证项目之前，默认保留以下状态，不把“卸载代码”和“销毁项目证据”混成一步：

- `.gf/packages.lock.json`：package 所有权、来源和文件摘要证据。
- `.gf/package_cache`、`.gf/package_workspace` 与 package transaction 记录：缓存可重建，但中断恢复和问题排查可能仍需要它们。
- `gf/*` ProjectSettings、项目 Installer 列表、项目自己的 preset，以及项目生成的访问器或常量脚本。
- 项目存档、配置、资源和任何 `user://` 数据；GF 插件卸载不会把它们视为可删除内容。

项目在无 GF 状态下成功打开、测试和导出后，才根据仓库策略单独清理派生缓存或失效设置。删除 lockfile 会丢失 package 文件的所有权基线；删除事务状态可能使未完成写入无法恢复，因此不能把这些路径加入无条件清理脚本。

## Package 卸载不是完整插件卸载

**package 卸载不是完整插件卸载**。Package Manager / CLI 的 `uninstall <package-id>...` 只按 lockfile、依赖闭包、项目引用和文件摘要移除所选 package；它不会代替 Godot 插件禁用流程，也不应通过手动删文件绕过事务与引用保护。

模块化项目先预览整批卸载计划，并把互相依赖、需要同时移除的 package 放进同一请求。计划被项目引用、外部 depender、本地文件改动或恢复义务阻断时，应先消除原因；`--force` 只用于调用方明确接受保护失效的场景。卸载完成后运行 `verify`。如果最终仍安装着提供编辑器插件的 GF package，继续按其 package 契约管理，不要再执行“完整插件卸载”的目录删除步骤。

## 失败恢复

- 如果误删 `addons/gf` 后才发现 `Gf` AutoLoad 或插件设置残留，先从与项目记录匹配的官方发布物**恢复同一版本**到原路径，重新打开并启用插件，再按本页顺序禁用。不要用不同版本覆盖现场后直接猜测清理项。
- 如果 package 事务中断，保留 `.gf` 状态并运行同版本 backend 的 `recover`；恢复完成后再重新预览卸载。
- 如果项目引用遗漏，恢复备份或同版本框架，清理引用并重新运行脚本解析、测试与导出检查。
- 如果同名 `Gf` 指向项目自己的脚本，保持该 AutoLoad 不变；GF 的所有权标记不存在时，插件退出不会接管它。

安装与 AutoLoad 的正向流程见 [安装与 AutoLoad](install-autoload.md)，模块化 package 命令、事务和供应链边界见 [GF Workspace](../../editor/workspace.md#package-manager)。
