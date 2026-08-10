# 安装与装配

扩展代码存在并不代表会自动注册运行时模块。需要参与 `GFArchitecture` 的扩展，应提供一个继承 `GFInstaller` 的 `extension.gd` 或安装器脚本，并在 manifest 的 `installer_paths` 中声明。

## 项目设置

插件启用后，GF 会注册这些项目设置：

- `gf/extensions/selection_mode`：扩展选择模式。`default` 表示按当前可发现 manifest 的默认启用声明派生；`explicit` 表示读取显式启用列表。
- `gf/extensions/enabled`：显式启用模式下使用的扩展 ID 列表。
- `gf/extensions/auto_install_enabled_installers`：是否在 `Gf.init()` / `Gf.set_architecture()` 时自动执行启用扩展的 `installer_paths`。
- `gf/extensions/external_roots`：额外扩展集合根目录列表。每个根目录下一层目录视为一个独立扩展，根目录必须是 `res://` 路径，例如 `res://addons/acme_extensions`。
- `gf/extensions/preset_paths`：项目侧扩展 preset JSON 文件路径列表。路径必须是 `res://` 下的 `.json` 文件。
- `gf/extensions/export_exclude_disabled`：导出时是否跳过禁用扩展目录。
- `gf/extensions/export_fail_on_disabled_references`：导出审计发现项目仍引用禁用扩展时，是否把结果报告为错误；默认开启，避免导出产物缺失仍被引用的扩展文件。

新项目使用 `gf/extensions/selection_mode="default"`，默认不启用 GF 内置可选扩展，`gf/extensions/enabled` 作为显式列表可以为空。项目需要 Save、Combat、Network、Flow、Domain 等能力时，通过 `GF Workspace` 的 `GF Extensions` 页面或 `GFExtensionSettings.set_enabled_extension_ids()` 保存显式选择；保存显式列表会把模式切换为 `explicit`。

扩展 ID 统一使用 manifest 中声明的稳定 ID，GF 内置扩展使用 `gf.*` 命名空间。

外部扩展根目录只是一种发现机制，不是项目目录规范。GF 不要求项目把玩法代码、资源或业务脚本放进这些目录；只有希望被 GF 扩展管理器发现、启用、导出过滤或贡献编辑器入口的独立扩展，才需要提供 manifest。

## 两类 Preset 与依赖

GF 有两类消费方和两套稳定 ID，不能互换：

| 任务 | 消费方 | Preset / 成员 ID | 是否写文件 |
| --- | --- | --- | --- |
| 选择已经存在于项目中的扩展 | `GF Extensions` / `GFExtensionPreset` | 扩展选择 preset，例如成员 `gf.save` | 只写扩展启用设置，不下载 package |
| 安装模块化 package 闭包 | `GF Package Manager` / package CLI | package 安装 preset，例如 `gf.preset.save`，成员 `gf.extension.save` | 经过预览与事务校验后写 package 文件和 lockfile |

Save 是最小映射示例：扩展 manifest ID 是 `gf.save`，承载其文件的 package ID 是 `gf.extension.save`，官方 package 安装 preset ID 是 `gf.preset.save`。其他扩展也必须分别从扩展 manifest、package manifest 和 package preset 读取实际 ID，不能靠名称拼接推断。需要下载、更新、卸载、registry、offline bundle 或供应链校验时，使用内置 [Package Manager](../editor/workspace.md#package-manager)；本页其余“preset”均特指扩展选择 preset。

扩展选择 preset 是安装向导或项目工具使用的启用组合，例如把 Save、Dialogue、Domain 一次写入显式启用列表。它不会写入扩展 manifest，也不代表这些扩展之间存在硬依赖。

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

`GFExtensionSettings.get_extension_presets()` 会返回内置动态组合和项目 preset；`add_extension_preset_path()` 只接受能解析为有效 `GFExtensionPreset` 的 `res://` JSON 文件，`remove_extension_preset_path()` 只移除项目 preset 路径；`apply_extension_preset()` 会把 preset 的 `extension_ids` 写入显式启用列表、切换到 `explicit` 模式，并按 manifest 硬依赖补齐可发现的依赖 ID。扩展管理器中的“扩展组合”下拉框使用同一套 API，但只更新当前勾选状态，仍需要点击“保存设置”写入 `project.godot`。

`GFExtensionPresetDiscovery` 是项目工具需要直接读取 preset 诊断时的底层快照入口。它会把内置动态 preset、项目 JSON preset、重复 ID、无效文件和未知扩展 ID 汇总到同一个 report，并根据 manifest、preset 路径和 preset 文件内容自动失效。

扩展选择 preset JSON 使用字段白名单，只描述 `id`、`display_name`、`description`、`extension_ids` 和 `tags`；`name`、`summary`、`extensions` 等旧别名字段会被拒绝。`dependencies`、`optional_dependencies`、`load_after` 等软关系字段，以及 `download_url`、`packages`、`registry`、`installer_paths` 等 package 下载或装配覆盖字段会被 `GFExtensionPreset.get_validation_errors()` 拒绝。这条边界只适用于 `GFExtensionPreset`：它负责本地扩展选择，网络下载、package registry、离线包、完整性校验与安装事务由内置 Package Manager 负责。项目自定义下载器或私有供应链集成仍应放在 `addons/gf` 外，并复用公开 package 协议，而不是把下载字段塞进扩展选择 preset。

`GFExtensionPreset.from_json_file()` 只在 preset 文件可读、JSON 为对象且校验通过时返回对象。编辑器或项目工具需要展示诊断时，应使用 `from_json_file_report()`，它返回 JSON-safe 的 `preset_data` 与错误列表，适合直接进入日志、CI 报告或工具输出。

Manifest、preset 和 tool contribution 的 JSON object 文件读取由 `GFExtensionJsonFileReader` 统一，扩展 ID 语法由 `GFExtensionIdValidator` 统一。三类输入都会在规范化前区分“字段缺失”和“字段类型错误”，并受单文件、累计字节与嵌套深度硬预算约束；签名与解析共享同一次发现预算。`GFExtensionToolContribution` 负责 `editor/gf_tool_contribution.json` 的严格 schema v2：只接受版本、所属扩展 ID 和已声明的路径字段，schema v1、未来版本与未知字段都会被拒绝。项目工具通常应通过 `GFExtensionManifest`、`GFExtensionPreset`、`GFExtensionPresetDiscovery`、`GFExtensionSelectionDiscovery` 和 `GFExtensionSettings` 这些更高层入口读取，不需要重复实现底层解析、ID 正则或贡献字段兼容分支。

扩展级 `EditorDebuggerPlugin` 必须在 tool contribution 中显式声明，不能写入运行时 manifest：

```json
{
  "schema_version": 2,
  "extension_id": "acme.runtime_tools",
  "debugger_plugin_paths": [
    "res://addons/acme_extensions/runtime_tools/editor/acme_debugger_plugin.gd"
  ]
}
```

路径必须位于所属扩展根目录内，目标脚本应继承 `EditorDebuggerPlugin`。`GFExtensionSettings.get_enabled_debugger_plugin_paths()` 只返回当前启用扩展的有效工具贡献；没有安装 tool package 时不会从运行时包猜测或合成 Debugger 入口。

扩展 manifest 的 `dependencies` 只描述启用当前扩展必须同时启用的基础能力。GF 内置扩展保持原子化，只声明 `gf.kernel` 与 `gf.standard`；跨扩展项目流程应放在项目 Installer 或 `addons/gf` 外的独立插件中。

Domain、Combat 这类业务型内置扩展按外置候选治理：随 GF 包分发时必须默认关闭、只依赖基础层，并通过 manifest `tags` 标记 `externalization-candidate`。它们不升级为默认基础能力；需要 RPG、ARPG、卡牌或关卡流程组合时，用项目 preset、项目 Installer 或 `addons/gf` 外的独立插件显式启用。

## 启用状态解析

`GFExtensionSettings.get_enabled_extension_ids()` 返回当前有效启用 ID。`default` 模式下，有效列表从当前可发现 manifest 的 `enabled_by_default` 派生；`explicit` 模式下，有效列表来自 `gf/extensions/enabled`。

启用状态解析只会产生当前可发现的 manifest ID。项目设置中如果残留不存在的扩展 ID，`GFExtensionSettings.get_extension_selection_report()` 会在 `unknown_enabled_ids` 中报告，并且这些 ID 不会进入最终启用集合。此时报告状态为 `partial`：未知 ID 不产生副作用，已验证的已知扩展仍可装配。已存在但无效的 tool contribution 同样形成 `partial`，错误通过 `tool_contribution_errors` 暴露且其无效路径不会注册；manifest 图错误则形成 `invalid` 并阻断全部扩展路径。调用方应检查 `status` 和 `paths_allowed`，不要自行从 `ok` 推断路径授权。报告中的 `selection_mode` 表示当前模式，`explicit_ids` 表示显式列表原始存储值，`configured_ids` 表示参与本次解析的有效配置来源。

通过 `set_enabled_extension_ids()` 或扩展管理器保存显式选择时，也会只写回当前可发现的扩展 ID。需要回到 manifest 默认派生时，使用扩展管理器的“恢复默认”或调用 `GFExtensionSettings.use_default_extension_selection()`；这不会改写显式列表，只会把 `gf/extensions/selection_mode` 切回 `default`。

## 装配顺序

`Gf` 会先按依赖优先顺序收集启用扩展的 `installer_paths`，再追加 `gf/project/installers` 中的项目级 Installer。这样内置扩展负责装配自己的抽象模块，项目仍然可以在后面继续注册业务模块或覆盖绑定。

GF 内置扩展中，只有需要参与 `GFArchitecture` 生命周期的服务或扩展正确工作所必需的标准能力会进入 `extension.gd`。例如 `save` 先确保 `GFStorageUtility` 存在，再注册 `GFSaveGraphUtility`；`combat` 注册 `GFSkillTargetingUtility2D` 和 `GFCombatSystem`，`domain` 注册 `GFLevelUtility` 和 `GFQuestUtility`。纯数据模型、Resource、动作对象和节点桥接不会被扩展安装器自动注册，仍由项目或局部上下文按使用场景装配。

项目 Installer 通常只注册项目自己的 `GFModel`、`GFSystem` 和 `GFUtility`。如果某个内置扩展已启用，不需要再手动注册它的扩展级服务或必需标准能力；重复注册会被忽略并提示使用 `replace_*()`。需要调整 Save 的 Storage 参数时，应在扩展 Installer 完成后取回已安装实例并配置；确实需要替换实现时，显式调用 `replace_utility()` 或 `replace_system()`，让覆盖意图和所有权边界清楚可见。
