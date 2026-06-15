# 安装与装配

扩展代码存在并不代表会自动注册运行时模块。需要参与 `GFArchitecture` 的扩展，应提供一个继承 `GFInstaller` 的 `extension.gd` 或安装器脚本，并在 manifest 的 `installer_paths` 中声明。

## 项目设置

插件启用后，GF 会注册这些项目设置：

- `gf/extensions/enabled`：启用的扩展 ID 列表。
- `gf/extensions/auto_install_enabled_installers`：是否在 `Gf.init()` / `Gf.set_architecture()` 时自动执行启用扩展的 `installer_paths`。
- `gf/extensions/external_roots`：额外扩展集合根目录列表。每个根目录下一层目录视为一个独立扩展，根目录必须是 `res://` 路径，例如 `res://addons/acme_extensions`。
- `gf/extensions/preset_paths`：项目侧扩展 preset JSON 文件路径列表。路径必须是 `res://` 下的 `.json` 文件。
- `gf/extensions/export_exclude_disabled`：导出时是否跳过禁用扩展目录。
- `gf/extensions/export_fail_on_disabled_references`：导出审计发现项目仍引用禁用扩展时，是否把结果报告为错误；默认开启，避免导出产物缺失仍被引用的扩展文件。

新项目默认不启用 GF 内置可选扩展，`gf/extensions/enabled` 可以为空。项目需要 Save、Combat、Network、Flow、Domain 等能力时，通过 `GF Workspace` 的 `GF Extensions` 页面或 `GFExtensionSettings.set_enabled_extension_ids()` 保存显式选择。

扩展 ID 统一使用 manifest 中声明的稳定 ID，GF 内置扩展使用 `gf.*` 命名空间。

外部扩展根目录只是一种发现机制，不是项目目录规范。GF 不要求项目把玩法代码、资源或业务脚本放进这些目录；只有希望被 GF 扩展管理器发现、启用、导出过滤或贡献编辑器入口的独立扩展，才需要提供 manifest。

## Preset 与依赖

Preset 是安装向导或项目工具使用的启用组合，例如把 Save、Dialogue、Domain 一次写入 `gf/extensions/enabled`。Preset 不会写入扩展 manifest，也不代表这些扩展之间存在硬依赖。

`GFExtensionPreset` 是 preset JSON 对应的结构化描述。GF 内置只提供动态基础组合，例如默认选择、全部关闭和全部可发现扩展。业务组合由项目或 `addons/gf` 外的独立插件提供 preset JSON，并把路径写入 `gf/extensions/preset_paths`：

```json
{
  "id": "project.rpg",
  "display_name": "RPG 工具",
  "description": "启用项目常用的存档、对话和领域模型扩展。",
  "extension_ids": ["gf.save", "gf.dialogue", "gf.domain"],
  "tags": ["rpg"]
}
```

`GFExtensionSettings.get_extension_presets()` 会返回内置动态组合和项目 preset；`add_extension_preset_path()` 只接受能解析为有效 `GFExtensionPreset` 的 `res://` JSON 文件，`remove_extension_preset_path()` 只移除项目 preset 路径；`apply_extension_preset()` 会把 preset 的 `extension_ids` 写入 `gf/extensions/enabled`，并按 manifest 硬依赖补齐可发现的依赖 ID。扩展管理器中的“扩展组合”下拉框使用同一套 API，但只更新当前勾选状态，仍需要点击“保存设置”写入 `project.godot`。

Preset JSON 使用字段白名单，只描述 `id`、`display_name`、`description`、`extension_ids` 和 `tags`；`name`、`summary`、`extensions` 等旧别名字段会被拒绝。`dependencies`、`optional_dependencies`、`load_after` 等软关系字段，以及 `download_url`、`packages`、`registry`、`installer_paths` 等下载包或装配覆盖字段会被 `GFExtensionPreset.get_validation_errors()` 拒绝。GF 内置安装和扩展管理流程不处理网络下载、包仓库、第三方 registry 或复杂包安装；这些能力只能由 `addons/gf` 外的独立插件或项目自管工具承担。GF 官方安装向导应只写入本地 ProjectSettings、preset 启用状态，并提示导出审计。

扩展 manifest 的 `dependencies` 只描述启用当前扩展必须同时启用的基础能力。GF 内置扩展保持原子化，只声明 `gf.kernel` 与 `gf.standard`；跨扩展项目流程应放在项目 Installer 或 `addons/gf` 外的独立插件中。

Domain、Combat 这类业务型内置扩展按外置候选治理：随 GF 包分发时必须默认关闭、只依赖基础层，并通过 manifest `tags` 标记 `externalization-candidate`。它们不升级为默认基础能力；需要 RPG、ARPG、卡牌或关卡流程组合时，用项目 preset、项目 Installer 或 `addons/gf` 外的独立插件显式启用。

## 启用状态解析

启用状态解析只会产生当前可发现的 manifest ID。项目设置中如果残留不存在的扩展 ID，`GFExtensionSettings.get_extension_selection_report()` 会在 `unknown_enabled_ids` 中报告，并且这些 ID 不会进入最终启用集合。

通过 `set_enabled_extension_ids()` 或扩展管理器保存设置时，也会只写回当前可发现的扩展 ID。

## 装配顺序

`Gf` 会先按依赖优先顺序收集启用扩展的 `installer_paths`，再追加 `gf/project/installers` 中的项目级 Installer。这样内置扩展负责装配自己的抽象模块，项目仍然可以在后面继续注册业务模块或覆盖绑定。

GF 内置扩展中，只有需要参与 `GFArchitecture` 生命周期的服务会进入 `extension.gd`。例如 `save` 注册 `GFSaveGraphUtility`，`combat` 注册 `GFSkillTargetingUtility` 和 `GFCombatSystem`，`domain` 注册 `GFLevelUtility` 和 `GFQuestUtility`；纯数据模型、Resource、动作对象和节点桥接不会被扩展安装器自动注册，仍由项目或局部上下文按使用场景装配。

项目 Installer 通常只注册项目自己的 `GFModel`、`GFSystem` 和 `GFUtility`。如果某个内置扩展已启用，不需要再手动注册它的扩展级服务；重复注册会被忽略并提示使用 `replace_*()`。确实需要替换默认实现时，应显式调用 `replace_utility()` 或 `replace_system()`，让覆盖意图和所有权边界清楚可见。
