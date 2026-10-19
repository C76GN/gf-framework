# 快速开始总览

快速开始覆盖 GF 插件安装、`Gf` AutoLoad、空项目初始化，以及按需添加模块和 Installer 装配。没有业务模块时无需创建 Model 或 System；项目需要集中注册模块时，优先使用 Installer 管理装配入口。

## 阅读入口

- [安装与 AutoLoad](install-autoload.md)：复制 `addons/gf`、启用插件和确认 `Gf` 全局入口。
- [项目初始化](../../editor/tools/project-bootstrap.md)：从工作区创建空项目启动入口，或保留现有主场景并复制接入片段。
- [最小启动与 Installer](minimal-installer.md)：注册 Model / Utility / System，调用 `Gf.init()`，并迁移到项目 Installer。
- [从 GF 10 模块化安装迁移](package-manager-migration.md)：先用原 GF 10 工具收敛旧事务，再整体替换为 GF 11 完整插件。
- [卸载、清理与恢复](uninstall.md)：先撤销项目引用和插件注册，再移除完整插件与确认无用的遗留状态。

## 入口与按需使用的模块

- `Gf`：全局 AutoLoad 入口。
- `GFInstaller`：集中装配项目或扩展的模块；初始化工具默认提供空入口，可选择不生成。
- `GFModel`：需要独立状态模块时使用。
- `GFSystem`：需要集中处理规则、事件、命令或逐帧逻辑时使用。
- `GFUtility`：需要可复用的运行时服务时使用。
