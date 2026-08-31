# GFExtensionSelectionDiscovery

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_selection_discovery.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

GF 扩展启用选择与贡献路径快照缓存。 基于 manifest 集合、当前启用 ID 和扩展工具贡献文件，生成启用选择、依赖图、 enabled/disabled manifest 与各类贡献路径的稳定 snapshot。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_VALID`](#member-gfextensionselectiondiscovery-constants-status_valid) | `const STATUS_VALID: StringName = &"valid"` |
| 常量 | [`STATUS_PARTIAL`](#member-gfextensionselectiondiscovery-constants-status_partial) | `const STATUS_PARTIAL: StringName = &"partial"` |
| 常量 | [`STATUS_INVALID`](#member-gfextensionselectiondiscovery-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 方法 | [`get_snapshot`](#member-gfextensionselectiondiscovery-methods-get_snapshot) | `static func get_snapshot( manifests: Array[GFExtensionManifest] = [], configured_ids: Array[String] = [], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear_cache`](#member-gfextensionselectiondiscovery-methods-clear_cache) | `static func clear_cache() -> void:` |

## 常量

<a id="member-gfextensionselectiondiscovery-constants-status_valid"></a>

### `STATUS_VALID`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_VALID: StringName = &"valid"
```

启用选择完整有效。

<a id="member-gfextensionselectiondiscovery-constants-status_partial"></a>

### `STATUS_PARTIAL`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_PARTIAL: StringName = &"partial"
```

启用选择包含可隔离的问题，但已验证的已知扩展路径仍可使用。

<a id="member-gfextensionselectiondiscovery-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

Manifest 图无效，任何扩展路径都不得使用。

## 方法

<a id="member-gfextensionselectiondiscovery-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_snapshot( manifests: Array[GFExtensionManifest] = [], configured_ids: Array[String] = [], options: Dictionary = {} ) -> Dictionary:
```

获取当前扩展启用选择快照。 默认会复用仍然有效的快照；当 manifest、启用 ID、manifest load errors 或当前解析出的启用扩展工具贡献文件变化时，自动重新派生并替换缓存。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 当前可发现的扩展 manifest 列表。 |
| `configured_ids` | 项目配置中的启用扩展 ID。 |
| `options` | 发现选项。 |

返回：扩展启用选择快照。

结构：

- `options`: Dictionary，支持 force_refresh、builtin_extension_ids、manifest_load_errors、max_json_file_bytes、max_json_total_bytes 和 max_json_depth；JSON 预算只能收紧框架硬上限。
- `return`: Dictionary，包含 ok、status、partial、paths_allowed、configured_ids、resolved_ids、unknown_enabled_ids、enabled_manifests、disabled_manifests、graph_report、manifest_paths、contribution_paths、paths、tool_contribution_errors、signature、signature_hash 和 revision；manifest_paths 只包含 installer_paths，contribution_paths 包含 access_generator_extension_paths、debugger_plugin_paths、editor_action_paths、editor_dock_paths、editor_inspector_paths、export_plugin_paths、gltf_document_extension_paths 和 import_plugin_paths，paths 为前两者的同字段稳定合并视图。

<a id="member-gfextensionselectiondiscovery-methods-clear_cache"></a>

### `clear_cache`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func clear_cache() -> void:
```

清空启用选择快照缓存。
