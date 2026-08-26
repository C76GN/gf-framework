# 快速开始总览

快速开始覆盖 GF 插件安装、`Gf` AutoLoad、最小模块注册和 Installer 装配。完整项目应优先使用 Installer 管理注册入口，而不是把所有模块注册写在某个场景 `_ready()` 中。

## 阅读入口

- [安装与 AutoLoad](install-autoload.md)：复制 `addons/gf`、启用插件和确认 `Gf` 全局入口。
- [最小启动与 Installer](minimal-installer.md)：注册 Model / Utility / System，调用 `Gf.init()`，并迁移到项目 Installer。
- [从 GF 10 模块化安装迁移](package-manager-migration.md)：先用原 GF 10 工具收敛旧事务，再整体替换为 GF 11 完整插件。
- [卸载、清理与恢复](uninstall.md)：先撤销项目引用和插件注册，再移除完整插件与确认无用的遗留状态。

## 你会用到什么

- `Gf`：全局 AutoLoad 入口。
- `GFModel`：保存项目状态。
- `GFSystem`：处理规则、事件、命令和逐帧逻辑。
- `GFUtility`：提供存档、资源、时间、日志等运行时服务。
- `GFInstaller`：集中装配项目或扩展的模块。
