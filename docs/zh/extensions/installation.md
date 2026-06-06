# 安装与装配

扩展代码存在并不代表会自动注册运行时模块。需要参与 `GFArchitecture` 的扩展，应提供一个继承 `GFInstaller` 的 `extension.gd` 或安装器脚本，并在 manifest 的 `installer_paths` 中声明。

## 项目设置

插件启用后，GF 会注册这些项目设置：

- `gf/extensions/enabled`：启用的扩展 ID 列表。
- `gf/extensions/auto_install_enabled_installers`：是否在 `Gf.init()` / `Gf.set_architecture()` 时自动执行启用扩展的 `installer_paths`。
- `gf/extensions/external_roots`：额外扩展集合根目录列表。每个根目录下一层目录视为一个独立扩展，根目录必须是 `res://` 路径，例如 `res://addons/acme_extensions`。
- `gf/extensions/export_exclude_disabled`：导出时是否跳过禁用扩展目录。
- `gf/extensions/export_fail_on_disabled_references`：导出审计发现项目仍引用禁用扩展时，是否把结果报告为错误；默认开启，避免导出产物缺失仍被引用的扩展文件。

新项目会把 GF 内置扩展的默认启用列表写入 `gf/extensions/enabled`。如果希望项目只启用其中一部分，可以通过 `GF Workspace` 的 `GF Extensions` 页面或 `GFExtensionSettings.set_enabled_extension_ids()` 保存显式选择。

扩展 ID 统一使用 manifest 中声明的稳定 ID，GF 内置扩展使用 `gf.*` 命名空间。

外部扩展根目录只是一种发现机制，不是项目目录规范。GF 不要求项目把玩法代码、资源或业务脚本放进这些目录；只有希望被 GF 扩展管理器发现、启用、导出过滤或贡献编辑器入口的独立扩展，才需要提供 manifest。

## 启用状态解析

启用状态解析只会产生当前可发现的 manifest ID。项目设置中如果残留不存在的扩展 ID，`GFExtensionSettings.get_extension_selection_report()` 会在 `unknown_enabled_ids` 中报告，并且这些 ID 不会进入最终启用集合。

通过 `set_enabled_extension_ids()` 或扩展管理器保存设置时，也会只写回当前可发现的扩展 ID。

## 装配顺序

`Gf` 会先按依赖优先顺序收集启用扩展的 `installer_paths`，再追加 `gf/project/installers` 中的项目级 Installer。这样内置扩展负责装配自己的抽象模块，项目仍然可以在后面继续注册业务模块或覆盖绑定。

GF 内置扩展中，只有需要参与 `GFArchitecture` 生命周期的服务会进入 `extension.gd`。例如 `save` 注册 `GFSaveGraphUtility`，`combat` 注册 `GFSkillTargetingUtility` 和 `GFCombatSystem`，`domain` 注册 `GFLevelUtility` 和 `GFQuestUtility`；纯数据模型、Resource、动作对象和节点桥接不会被扩展安装器自动注册，仍由项目或局部上下文按使用场景装配。

项目 Installer 通常只注册项目自己的 `GFModel`、`GFSystem` 和 `GFUtility`。如果某个内置扩展已启用，不需要再手动注册它的扩展级服务；重复注册会被忽略并提示使用 `replace_*()`。确实需要替换默认实现时，应显式调用 `replace_utility()` 或 `replace_system()`，让覆盖意图和所有权边界清楚可见。
