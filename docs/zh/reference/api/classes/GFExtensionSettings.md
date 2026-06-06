# GFExtensionSettings

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_settings.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

GF 扩展启用状态与 ProjectSettings 桥接。 负责读取启用扩展 ID、解析扩展依赖、收集启用扩展 Installer，以及提供导出排除开关。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ENABLED_EXTENSIONS_SETTING`](#member-gfextensionsettings-constants-enabled_extensions_setting) | `const ENABLED_EXTENSIONS_SETTING: String = "gf/extensions/enabled"` |
| 常量 | [`AUTO_INSTALL_ENABLED_INSTALLERS_SETTING`](#member-gfextensionsettings-constants-auto_install_enabled_installers_setting) | `const AUTO_INSTALL_ENABLED_INSTALLERS_SETTING: String = "gf/extensions/auto_install_enabled_installers"` |
| 常量 | [`EXTERNAL_EXTENSION_ROOTS_SETTING`](#member-gfextensionsettings-constants-external_extension_roots_setting) | `const EXTERNAL_EXTENSION_ROOTS_SETTING: String = "gf/extensions/external_roots"` |
| 常量 | [`EXPORT_EXCLUDE_DISABLED_SETTING`](#member-gfextensionsettings-constants-export_exclude_disabled_setting) | `const EXPORT_EXCLUDE_DISABLED_SETTING: String = "gf/extensions/export_exclude_disabled"` |
| 常量 | [`EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING`](#member-gfextensionsettings-constants-export_fail_on_disabled_references_setting) | `const EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING: String = "gf/extensions/export_fail_on_disabled_references"` |
| 常量 | [`AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT`](#member-gfextensionsettings-constants-auto_install_enabled_installers_default) | `const AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT: bool = true` |
| 常量 | [`EXTERNAL_EXTENSION_ROOTS_DEFAULT`](#member-gfextensionsettings-constants-external_extension_roots_default) | `const EXTERNAL_EXTENSION_ROOTS_DEFAULT: Array[String] = []` |
| 常量 | [`EXPORT_EXCLUDE_DISABLED_DEFAULT`](#member-gfextensionsettings-constants-export_exclude_disabled_default) | `const EXPORT_EXCLUDE_DISABLED_DEFAULT: bool = true` |
| 常量 | [`EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT`](#member-gfextensionsettings-constants-export_fail_on_disabled_references_default) | `const EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT: bool = true` |
| 常量 | [`BUILT_IN_EXTENSION_IDS`](#member-gfextensionsettings-constants-built_in_extension_ids) | `const BUILT_IN_EXTENSION_IDS: Array[String] = [` |
| 方法 | [`ensure_defaults`](#member-gfextensionsettings-methods-ensure_defaults) | `static func ensure_defaults() -> bool:` |
| 方法 | [`register_property_info`](#member-gfextensionsettings-methods-register_property_info) | `static func register_property_info() -> void:` |
| 方法 | [`get_default_enabled_extension_ids`](#member-gfextensionsettings-methods-get_default_enabled_extension_ids) | `static func get_default_enabled_extension_ids() -> Array[String]:` |
| 方法 | [`get_enabled_extension_ids`](#member-gfextensionsettings-methods-get_enabled_extension_ids) | `static func get_enabled_extension_ids() -> Array[String]:` |
| 方法 | [`set_enabled_extension_ids`](#member-gfextensionsettings-methods-set_enabled_extension_ids) | `static func set_enabled_extension_ids(extension_ids: Array[String], include_dependencies: bool = true) -> void:` |
| 方法 | [`should_auto_install_enabled_installers`](#member-gfextensionsettings-methods-should_auto_install_enabled_installers) | `static func should_auto_install_enabled_installers() -> bool:` |
| 方法 | [`set_auto_install_enabled_installers`](#member-gfextensionsettings-methods-set_auto_install_enabled_installers) | `static func set_auto_install_enabled_installers(enabled: bool) -> void:` |
| 方法 | [`get_external_extension_roots`](#member-gfextensionsettings-methods-get_external_extension_roots) | `static func get_external_extension_roots() -> Array[String]:` |
| 方法 | [`set_external_extension_roots`](#member-gfextensionsettings-methods-set_external_extension_roots) | `static func set_external_extension_roots(root_paths: Array[String]) -> void:` |
| 方法 | [`should_export_exclude_disabled_extensions`](#member-gfextensionsettings-methods-should_export_exclude_disabled_extensions) | `static func should_export_exclude_disabled_extensions() -> bool:` |
| 方法 | [`set_export_exclude_disabled_extensions`](#member-gfextensionsettings-methods-set_export_exclude_disabled_extensions) | `static func set_export_exclude_disabled_extensions(enabled: bool) -> void:` |
| 方法 | [`should_fail_export_on_disabled_extension_references`](#member-gfextensionsettings-methods-should_fail_export_on_disabled_extension_references) | `static func should_fail_export_on_disabled_extension_references() -> bool:` |
| 方法 | [`set_fail_export_on_disabled_extension_references`](#member-gfextensionsettings-methods-set_fail_export_on_disabled_extension_references) | `static func set_fail_export_on_disabled_extension_references(enabled: bool) -> void:` |
| 方法 | [`get_all_manifests`](#member-gfextensionsettings-methods-get_all_manifests) | `static func get_all_manifests() -> Array[GFExtensionManifest]:` |
| 方法 | [`clear_manifest_cache`](#member-gfextensionsettings-methods-clear_manifest_cache) | `static func clear_manifest_cache() -> void:` |
| 方法 | [`get_manifest_by_id`](#member-gfextensionsettings-methods-get_manifest_by_id) | `static func get_manifest_by_id(extension_id: String) -> GFExtensionManifest:` |
| 方法 | [`has_extension`](#member-gfextensionsettings-methods-has_extension) | `static func has_extension(extension_id: String) -> bool:` |
| 方法 | [`get_extension_resource_path`](#member-gfextensionsettings-methods-get_extension_resource_path) | `static func get_extension_resource_path( extension_id: String, relative_path: String = "" ) -> String:` |
| 方法 | [`is_extension_enabled`](#member-gfextensionsettings-methods-is_extension_enabled) | `static func is_extension_enabled( extension_id: String, include_dependencies: bool = true ) -> bool:` |
| 方法 | [`load_enabled_extension_script`](#member-gfextensionsettings-methods-load_enabled_extension_script) | `static func load_enabled_extension_script( extension_id: String, relative_path: String, include_dependencies: bool = true ) -> Script:` |
| 方法 | [`get_enabled_manifests`](#member-gfextensionsettings-methods-get_enabled_manifests) | `static func get_enabled_manifests() -> Array[GFExtensionManifest]:` |
| 方法 | [`get_disabled_manifests`](#member-gfextensionsettings-methods-get_disabled_manifests) | `static func get_disabled_manifests() -> Array[GFExtensionManifest]:` |
| 方法 | [`get_enabled_installer_paths`](#member-gfextensionsettings-methods-get_enabled_installer_paths) | `static func get_enabled_installer_paths() -> Array[String]:` |
| 方法 | [`get_enabled_editor_action_paths`](#member-gfextensionsettings-methods-get_enabled_editor_action_paths) | `static func get_enabled_editor_action_paths() -> Array[String]:` |
| 方法 | [`get_enabled_editor_dock_paths`](#member-gfextensionsettings-methods-get_enabled_editor_dock_paths) | `static func get_enabled_editor_dock_paths() -> Array[String]:` |
| 方法 | [`get_enabled_editor_inspector_paths`](#member-gfextensionsettings-methods-get_enabled_editor_inspector_paths) | `static func get_enabled_editor_inspector_paths() -> Array[String]:` |
| 方法 | [`get_enabled_import_plugin_paths`](#member-gfextensionsettings-methods-get_enabled_import_plugin_paths) | `static func get_enabled_import_plugin_paths() -> Array[String]:` |
| 方法 | [`get_enabled_export_plugin_paths`](#member-gfextensionsettings-methods-get_enabled_export_plugin_paths) | `static func get_enabled_export_plugin_paths() -> Array[String]:` |
| 方法 | [`get_enabled_gltf_document_extension_paths`](#member-gfextensionsettings-methods-get_enabled_gltf_document_extension_paths) | `static func get_enabled_gltf_document_extension_paths() -> Array[String]:` |
| 方法 | [`get_enabled_access_generator_extension_paths`](#member-gfextensionsettings-methods-get_enabled_access_generator_extension_paths) | `static func get_enabled_access_generator_extension_paths() -> Array[String]:` |
| 方法 | [`resolve_extension_dependencies`](#member-gfextensionsettings-methods-resolve_extension_dependencies) | `static func resolve_extension_dependencies( extension_ids: Array[String], manifests: Array[GFExtensionManifest] = [] ) -> Array[String]:` |
| 方法 | [`get_manifest_graph_report`](#member-gfextensionsettings-methods-get_manifest_graph_report) | `static func get_manifest_graph_report(manifests: Array[GFExtensionManifest] = []) -> Dictionary:` |
| 方法 | [`get_extension_selection_report`](#member-gfextensionsettings-methods-get_extension_selection_report) | `static func get_extension_selection_report() -> Dictionary:` |

## 常量

<a id="member-gfextensionsettings-constants-enabled_extensions_setting"></a>

### `ENABLED_EXTENSIONS_SETTING`

- API：`public`

```gdscript
const ENABLED_EXTENSIONS_SETTING: String = "gf/extensions/enabled"
```

项目设置：启用的 GF 扩展 ID 列表。

<a id="member-gfextensionsettings-constants-auto_install_enabled_installers_setting"></a>

### `AUTO_INSTALL_ENABLED_INSTALLERS_SETTING`

- API：`public`

```gdscript
const AUTO_INSTALL_ENABLED_INSTALLERS_SETTING: String = "gf/extensions/auto_install_enabled_installers"
```

项目设置：是否自动执行启用扩展 manifest 中声明的 installer_paths。

<a id="member-gfextensionsettings-constants-external_extension_roots_setting"></a>

### `EXTERNAL_EXTENSION_ROOTS_SETTING`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
const EXTERNAL_EXTENSION_ROOTS_SETTING: String = "gf/extensions/external_roots"
```

项目设置：额外扩展集合根目录列表。每个根目录下一层为独立扩展目录。

<a id="member-gfextensionsettings-constants-export_exclude_disabled_setting"></a>

### `EXPORT_EXCLUDE_DISABLED_SETTING`

- API：`public`

```gdscript
const EXPORT_EXCLUDE_DISABLED_SETTING: String = "gf/extensions/export_exclude_disabled"
```

项目设置：导出时是否跳过禁用扩展目录。

<a id="member-gfextensionsettings-constants-export_fail_on_disabled_references_setting"></a>

### `EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING`

- API：`public`

```gdscript
const EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING: String = "gf/extensions/export_fail_on_disabled_references"
```

项目设置：导出审计发现项目仍引用禁用扩展时是否报告为错误。

<a id="member-gfextensionsettings-constants-auto_install_enabled_installers_default"></a>

### `AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT`

- API：`public`

```gdscript
const AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT: bool = true
```

默认自动执行启用扩展 Installer。

<a id="member-gfextensionsettings-constants-external_extension_roots_default"></a>

### `EXTERNAL_EXTENSION_ROOTS_DEFAULT`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
const EXTERNAL_EXTENSION_ROOTS_DEFAULT: Array[String] = []
```

默认不扫描额外扩展根目录。

<a id="member-gfextensionsettings-constants-export_exclude_disabled_default"></a>

### `EXPORT_EXCLUDE_DISABLED_DEFAULT`

- API：`public`

```gdscript
const EXPORT_EXCLUDE_DISABLED_DEFAULT: bool = true
```

默认导出时排除禁用扩展。

<a id="member-gfextensionsettings-constants-export_fail_on_disabled_references_default"></a>

### `EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT`

- API：`public`

```gdscript
const EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT: bool = true
```

默认把禁用扩展引用作为导出错误，避免导出产物缺少被引用的扩展文件。

<a id="member-gfextensionsettings-constants-built_in_extension_ids"></a>

### `BUILT_IN_EXTENSION_IDS`

- API：`public`

```gdscript
const BUILT_IN_EXTENSION_IDS: Array[String] = [
```

内置依赖 ID。这些不是可启停扩展 manifest，但允许被扩展声明为基础依赖。

## 方法

<a id="member-gfextensionsettings-methods-ensure_defaults"></a>

### `ensure_defaults`

- API：`public`

```gdscript
static func ensure_defaults() -> bool:
```

确保扩展相关 ProjectSettings 存在。

返回：写入了默认值时返回 true。

<a id="member-gfextensionsettings-methods-register_property_info"></a>

### `register_property_info`

- API：`public`

```gdscript
static func register_property_info() -> void:
```

注册扩展相关 ProjectSettings 显示信息。

<a id="member-gfextensionsettings-methods-get_default_enabled_extension_ids"></a>

### `get_default_enabled_extension_ids`

- API：`public`

```gdscript
static func get_default_enabled_extension_ids() -> Array[String]:
```

获取默认启用的扩展 ID。

返回：默认启用扩展 ID 列表。

<a id="member-gfextensionsettings-methods-get_enabled_extension_ids"></a>

### `get_enabled_extension_ids`

- API：`public`

```gdscript
static func get_enabled_extension_ids() -> Array[String]:
```

获取用户配置的启用扩展 ID。

返回：启用扩展 ID 列表。

<a id="member-gfextensionsettings-methods-set_enabled_extension_ids"></a>

### `set_enabled_extension_ids`

- API：`public`

```gdscript
static func set_enabled_extension_ids(extension_ids: Array[String], include_dependencies: bool = true) -> void:
```

保存启用扩展 ID，可选自动补齐依赖。

参数：

| 名称 | 说明 |
|---|---|
| `extension_ids` | 要启用的扩展 ID 列表。 |
| `include_dependencies` | 是否自动包含依赖扩展。 |

<a id="member-gfextensionsettings-methods-should_auto_install_enabled_installers"></a>

### `should_auto_install_enabled_installers`

- API：`public`

```gdscript
static func should_auto_install_enabled_installers() -> bool:
```

判断是否自动运行启用扩展 Installer。

返回：自动运行时返回 true。

<a id="member-gfextensionsettings-methods-set_auto_install_enabled_installers"></a>

### `set_auto_install_enabled_installers`

- API：`public`

```gdscript
static func set_auto_install_enabled_installers(enabled: bool) -> void:
```

设置是否自动运行启用扩展 Installer。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 是否自动运行。 |

<a id="member-gfextensionsettings-methods-get_external_extension_roots"></a>

### `get_external_extension_roots`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func get_external_extension_roots() -> Array[String]:
```

获取项目配置的额外扩展集合根目录。 只返回 `res://` 根目录，保证 manifest 贡献路径仍可由 Godot 资源系统加载。

返回：扩展集合根目录列表。

<a id="member-gfextensionsettings-methods-set_external_extension_roots"></a>

### `set_external_extension_roots`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func set_external_extension_roots(root_paths: Array[String]) -> void:
```

保存项目配置的额外扩展集合根目录，并刷新 manifest 缓存。

参数：

| 名称 | 说明 |
|---|---|
| `root_paths` | 扩展集合根目录列表。 |

<a id="member-gfextensionsettings-methods-should_export_exclude_disabled_extensions"></a>

### `should_export_exclude_disabled_extensions`

- API：`public`

```gdscript
static func should_export_exclude_disabled_extensions() -> bool:
```

判断导出时是否排除禁用扩展目录。

返回：排除禁用扩展时返回 true。

<a id="member-gfextensionsettings-methods-set_export_exclude_disabled_extensions"></a>

### `set_export_exclude_disabled_extensions`

- API：`public`

```gdscript
static func set_export_exclude_disabled_extensions(enabled: bool) -> void:
```

设置导出时是否排除禁用扩展目录。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 是否排除禁用扩展。 |

<a id="member-gfextensionsettings-methods-should_fail_export_on_disabled_extension_references"></a>

### `should_fail_export_on_disabled_extension_references`

- API：`public`

```gdscript
static func should_fail_export_on_disabled_extension_references() -> bool:
```

判断导出审计发现禁用扩展引用时是否报告为错误。

返回：报告为错误时返回 true。

<a id="member-gfextensionsettings-methods-set_fail_export_on_disabled_extension_references"></a>

### `set_fail_export_on_disabled_extension_references`

- API：`public`

```gdscript
static func set_fail_export_on_disabled_extension_references(enabled: bool) -> void:
```

设置导出审计发现禁用扩展引用时是否报告为错误。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 是否报告为错误。 |

<a id="member-gfextensionsettings-methods-get_all_manifests"></a>

### `get_all_manifests`

- API：`public`

```gdscript
static func get_all_manifests() -> Array[GFExtensionManifest]:
```

获取所有 manifest。

返回：manifest 列表。

<a id="member-gfextensionsettings-methods-clear_manifest_cache"></a>

### `clear_manifest_cache`

- API：`public`

```gdscript
static func clear_manifest_cache() -> void:
```

清空 manifest 发现缓存。编辑器或工具在扩展目录发生变化后可主动调用。

<a id="member-gfextensionsettings-methods-get_manifest_by_id"></a>

### `get_manifest_by_id`

- API：`public`

```gdscript
static func get_manifest_by_id(extension_id: String) -> GFExtensionManifest:
```

按 ID 获取 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 扩展 ID。 |

返回：找到时返回 manifest，否则返回 null。

<a id="member-gfextensionsettings-methods-has_extension"></a>

### `has_extension`

- API：`public`

```gdscript
static func has_extension(extension_id: String) -> bool:
```

判断扩展 manifest 是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 扩展 ID。 |

返回：存在 manifest 时返回 true。

<a id="member-gfextensionsettings-methods-get_extension_resource_path"></a>

### `get_extension_resource_path`

- API：`public`

```gdscript
static func get_extension_resource_path( extension_id: String, relative_path: String = "" ) -> String:
```

获取扩展内资源路径。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 扩展 ID。 |
| `relative_path` | 相对扩展根目录的资源路径；传入 `res://` 时必须仍位于扩展根目录下。 |

返回：扩展根目录下的资源路径；扩展不存在或路径越界时返回空字符串。

<a id="member-gfextensionsettings-methods-is_extension_enabled"></a>

### `is_extension_enabled`

- API：`public`

```gdscript
static func is_extension_enabled( extension_id: String, include_dependencies: bool = true ) -> bool:
```

判断扩展当前是否启用。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 扩展 ID。 |
| `include_dependencies` | 是否把依赖补齐后的启用结果纳入判断。 |

返回：扩展存在且启用时返回 true。

<a id="member-gfextensionsettings-methods-load_enabled_extension_script"></a>

### `load_enabled_extension_script`

- API：`public`

```gdscript
static func load_enabled_extension_script( extension_id: String, relative_path: String, include_dependencies: bool = true ) -> Script:
```

加载启用扩展内的脚本资源。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 扩展 ID。 |
| `relative_path` | 相对扩展根目录的脚本路径；传入 `res://` 时必须仍位于扩展根目录下。 |
| `include_dependencies` | 是否把依赖补齐后的启用结果纳入判断。 |

返回：扩展存在、已启用、依赖图有效且脚本可加载时返回 Script，否则返回 null。

<a id="member-gfextensionsettings-methods-get_enabled_manifests"></a>

### `get_enabled_manifests`

- API：`public`

```gdscript
static func get_enabled_manifests() -> Array[GFExtensionManifest]:
```

获取启用扩展的 manifest。

返回：启用 manifest 列表。

<a id="member-gfextensionsettings-methods-get_disabled_manifests"></a>

### `get_disabled_manifests`

- API：`public`

```gdscript
static func get_disabled_manifests() -> Array[GFExtensionManifest]:
```

获取禁用扩展的 manifest。

返回：禁用 manifest 列表。

<a id="member-gfextensionsettings-methods-get_enabled_installer_paths"></a>

### `get_enabled_installer_paths`

- API：`public`

```gdscript
static func get_enabled_installer_paths() -> Array[String]:
```

获取启用扩展声明的 Installer 路径。

返回：Installer 路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_editor_action_paths"></a>

### `get_enabled_editor_action_paths`

- API：`public`

```gdscript
static func get_enabled_editor_action_paths() -> Array[String]:
```

获取启用扩展声明的编辑器菜单动作路径。

返回：编辑器菜单动作脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_editor_dock_paths"></a>

### `get_enabled_editor_dock_paths`

- API：`public`

```gdscript
static func get_enabled_editor_dock_paths() -> Array[String]:
```

获取启用扩展声明的编辑器工作区页面路径。

返回：编辑器工作区页面脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_editor_inspector_paths"></a>

### `get_enabled_editor_inspector_paths`

- API：`public`

```gdscript
static func get_enabled_editor_inspector_paths() -> Array[String]:
```

获取启用扩展声明的 Inspector 扩展路径。

返回：EditorInspectorPlugin 脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_import_plugin_paths"></a>

### `get_enabled_import_plugin_paths`

- API：`public`

```gdscript
static func get_enabled_import_plugin_paths() -> Array[String]:
```

获取启用扩展声明的导入插件路径。

返回：EditorImportPlugin 脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_export_plugin_paths"></a>

### `get_enabled_export_plugin_paths`

- API：`public`

```gdscript
static func get_enabled_export_plugin_paths() -> Array[String]:
```

获取启用扩展声明的导出插件路径。

返回：EditorExportPlugin 脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_gltf_document_extension_paths"></a>

### `get_enabled_gltf_document_extension_paths`

- API：`public`

```gdscript
static func get_enabled_gltf_document_extension_paths() -> Array[String]:
```

获取启用扩展声明的 glTF 文档扩展路径。

返回：GLTFDocumentExtension 脚本路径列表。

<a id="member-gfextensionsettings-methods-get_enabled_access_generator_extension_paths"></a>

### `get_enabled_access_generator_extension_paths`

- API：`public`

```gdscript
static func get_enabled_access_generator_extension_paths() -> Array[String]:
```

获取启用扩展声明的访问器生成扩展路径。

返回：GFAccessGenerator 扩展脚本路径列表。

<a id="member-gfextensionsettings-methods-resolve_extension_dependencies"></a>

### `resolve_extension_dependencies`

- API：`public`

```gdscript
static func resolve_extension_dependencies( extension_ids: Array[String], manifests: Array[GFExtensionManifest] = [] ) -> Array[String]:
```

根据 manifest 依赖关系补齐启用扩展。

参数：

| 名称 | 说明 |
|---|---|
| `extension_ids` | 原始启用扩展 ID。 |
| `manifests` | 可选 manifest 列表。 |

返回：补齐依赖后的扩展 ID。

<a id="member-gfextensionsettings-methods-get_manifest_graph_report"></a>

### `get_manifest_graph_report`

- API：`public`

```gdscript
static func get_manifest_graph_report(manifests: Array[GFExtensionManifest] = []) -> Dictionary:
```

获取 manifest 依赖图诊断。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | 可选 manifest 列表；为空时扫描所有 GF 内置扩展。 |

返回：包含重复 ID、无效 manifest、缺失依赖和循环依赖的诊断字典。

结构：

- `return`: Dictionary containing ok, extension_count, issue_count, duplicate_ids, invalid_manifests, missing_dependencies, and dependency_cycles.

<a id="member-gfextensionsettings-methods-get_extension_selection_report"></a>

### `get_extension_selection_report`

- API：`public`

```gdscript
static func get_extension_selection_report() -> Dictionary:
```

获取启用状态诊断。

返回：诊断字典。

结构：

- `return`: Dictionary containing external_roots, configured_ids, resolved_ids, unknown_enabled_ids, graph status, and extension counts.
