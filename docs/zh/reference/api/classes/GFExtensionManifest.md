# GFExtensionManifest

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_manifest.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

GF 扩展元数据描述。 用于描述 GF 扩展的稳定 ID、版本、依赖、安装入口和编辑器扩展。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FILE_NAME`](#member-gfextensionmanifest-constants-file_name) | `const FILE_NAME: String = "gf_extension.json"` |
| 常量 | [`KIND_STANDARD`](#member-gfextensionmanifest-constants-kind_standard) | `const KIND_STANDARD: String = "standard"` |
| 常量 | [`KIND_EXTENSION`](#member-gfextensionmanifest-constants-kind_extension) | `const KIND_EXTENSION: String = "extension"` |
| 属性 | [`id`](#member-gfextensionmanifest-properties-id) | `var id: String = ""` |
| 属性 | [`display_name`](#member-gfextensionmanifest-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`version`](#member-gfextensionmanifest-properties-version) | `var version: String = ""` |
| 属性 | [`extension_version`](#member-gfextensionmanifest-properties-extension_version) | `var extension_version: String = ""` |
| 属性 | [`kind`](#member-gfextensionmanifest-properties-kind) | `var kind: String = KIND_EXTENSION` |
| 属性 | [`root_path`](#member-gfextensionmanifest-properties-root_path) | `var root_path: String = ""` |
| 属性 | [`description`](#member-gfextensionmanifest-properties-description) | `var description: String = ""` |
| 属性 | [`dependencies`](#member-gfextensionmanifest-properties-dependencies) | `var dependencies: Array[String] = []` |
| 属性 | [`installer_paths`](#member-gfextensionmanifest-properties-installer_paths) | `var installer_paths: Array[String] = []` |
| 属性 | [`editor_action_paths`](#member-gfextensionmanifest-properties-editor_action_paths) | `var editor_action_paths: Array[String] = []` |
| 属性 | [`editor_dock_paths`](#member-gfextensionmanifest-properties-editor_dock_paths) | `var editor_dock_paths: Array[String] = []` |
| 属性 | [`editor_dock_order`](#member-gfextensionmanifest-properties-editor_dock_order) | `var editor_dock_order: int = 1000` |
| 属性 | [`editor_dock_short_label`](#member-gfextensionmanifest-properties-editor_dock_short_label) | `var editor_dock_short_label: String = ""` |
| 属性 | [`editor_inspector_paths`](#member-gfextensionmanifest-properties-editor_inspector_paths) | `var editor_inspector_paths: Array[String] = []` |
| 属性 | [`import_plugin_paths`](#member-gfextensionmanifest-properties-import_plugin_paths) | `var import_plugin_paths: Array[String] = []` |
| 属性 | [`export_plugin_paths`](#member-gfextensionmanifest-properties-export_plugin_paths) | `var export_plugin_paths: Array[String] = []` |
| 属性 | [`gltf_document_extension_paths`](#member-gfextensionmanifest-properties-gltf_document_extension_paths) | `var gltf_document_extension_paths: Array[String] = []` |
| 属性 | [`access_generator_extension_paths`](#member-gfextensionmanifest-properties-access_generator_extension_paths) | `var access_generator_extension_paths: Array[String] = []` |
| 属性 | [`tags`](#member-gfextensionmanifest-properties-tags) | `var tags: Array[String] = []` |
| 属性 | [`enabled_by_default`](#member-gfextensionmanifest-properties-enabled_by_default) | `var enabled_by_default: bool = false` |
| 属性 | [`source_path`](#member-gfextensionmanifest-properties-source_path) | `var source_path: String = ""` |
| 方法 | [`from_dictionary`](#member-gfextensionmanifest-methods-from_dictionary) | `static func from_dictionary( data: Dictionary, extension_root_path: String = "", manifest_source_path: String = "" ) -> GFExtensionManifest:` |
| 方法 | [`from_json_file`](#member-gfextensionmanifest-methods-from_json_file) | `static func from_json_file(path: String) -> GFExtensionManifest:` |
| 方法 | [`from_json_file_report`](#member-gfextensionmanifest-methods-from_json_file_report) | `static func from_json_file_report(path: String) -> Dictionary:` |
| 方法 | [`is_valid_extension_id`](#member-gfextensionmanifest-methods-is_valid_extension_id) | `static func is_valid_extension_id(extension_id: String) -> bool:` |
| 方法 | [`get_extension_id_validation_error`](#member-gfextensionmanifest-methods-get_extension_id_validation_error) | `static func get_extension_id_validation_error(extension_id: String, field_name: String = "id") -> String:` |
| 方法 | [`to_dictionary`](#member-gfextensionmanifest-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`duplicate_manifest`](#member-gfextensionmanifest-methods-duplicate_manifest) | `func duplicate_manifest() -> GFExtensionManifest:` |
| 方法 | [`is_valid`](#member-gfextensionmanifest-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`get_validation_errors`](#member-gfextensionmanifest-methods-get_validation_errors) | `func get_validation_errors() -> Array[String]:` |

## 常量

<a id="member-gfextensionmanifest-constants-file_name"></a>

### `FILE_NAME`

- API：`public`

```gdscript
const FILE_NAME: String = "gf_extension.json"
```

GF 扩展 manifest 文件名。

<a id="member-gfextensionmanifest-constants-kind_standard"></a>

### `KIND_STANDARD`

- API：`public`

```gdscript
const KIND_STANDARD: String = "standard"
```

扩展类型：GF 标准库内置能力。

<a id="member-gfextensionmanifest-constants-kind_extension"></a>

### `KIND_EXTENSION`

- API：`public`

```gdscript
const KIND_EXTENSION: String = "extension"
```

扩展类型：GF 可选扩展。

## 属性

<a id="member-gfextensionmanifest-properties-id"></a>

### `id`

- API：`public`

```gdscript
var id: String = ""
```

稳定扩展 ID，推荐格式为反向域名或作者命名空间，例如 `author.extension_name`。

<a id="member-gfextensionmanifest-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

面向用户显示的扩展名。

<a id="member-gfextensionmanifest-properties-version"></a>

### `version`

- API：`public`

```gdscript
var version: String = ""
```

扩展发行版本号。GF 内置扩展必须与当前 GF 发行版本一致。

<a id="member-gfextensionmanifest-properties-extension_version"></a>

### `extension_version`

- API：`public`

```gdscript
var extension_version: String = ""
```

扩展自身版本号。GF 内置扩展按扩展内公开行为变化独立递增；未声明时回退到 version。

<a id="member-gfextensionmanifest-properties-kind"></a>

### `kind`

- API：`public`

```gdscript
var kind: String = KIND_EXTENSION
```

扩展类型，应为 `standard` 或 `extension`。

<a id="member-gfextensionmanifest-properties-root_path"></a>

### `root_path`

- API：`public`

```gdscript
var root_path: String = ""
```

扩展根目录。

<a id="member-gfextensionmanifest-properties-description"></a>

### `description`

- API：`public`

```gdscript
var description: String = ""
```

简短说明。

<a id="member-gfextensionmanifest-properties-dependencies"></a>

### `dependencies`

- API：`public`

```gdscript
var dependencies: Array[String] = []
```

依赖的扩展 ID 列表。

<a id="member-gfextensionmanifest-properties-installer_paths"></a>

### `installer_paths`

- API：`public`

```gdscript
var installer_paths: Array[String] = []
```

可选 GFInstaller 路径列表。需要自动装配运行时模块时使用。

<a id="member-gfextensionmanifest-properties-editor_action_paths"></a>

### `editor_action_paths`

- API：`public`

```gdscript
var editor_action_paths: Array[String] = []
```

可选编辑器菜单动作脚本路径列表。

<a id="member-gfextensionmanifest-properties-editor_dock_paths"></a>

### `editor_dock_paths`

- API：`public`

```gdscript
var editor_dock_paths: Array[String] = []
```

可选编辑器工作区页面脚本路径列表。

<a id="member-gfextensionmanifest-properties-editor_dock_order"></a>

### `editor_dock_order`

- API：`public`

```gdscript
var editor_dock_order: int = 1000
```

编辑器工作区页面排序。数值越小越靠前。

<a id="member-gfextensionmanifest-properties-editor_dock_short_label"></a>

### `editor_dock_short_label`

- API：`public`

```gdscript
var editor_dock_short_label: String = ""
```

编辑器工作区页面短标签。为空时使用扩展显示名。

<a id="member-gfextensionmanifest-properties-editor_inspector_paths"></a>

### `editor_inspector_paths`

- API：`public`

```gdscript
var editor_inspector_paths: Array[String] = []
```

可选 EditorInspectorPlugin 路径列表。需要为扩展内类型提供 Inspector 增强时使用。

<a id="member-gfextensionmanifest-properties-import_plugin_paths"></a>

### `import_plugin_paths`

- API：`public`

```gdscript
var import_plugin_paths: Array[String] = []
```

可选 EditorImportPlugin 路径列表。需要为自定义资源格式提供导入器时使用。

<a id="member-gfextensionmanifest-properties-export_plugin_paths"></a>

### `export_plugin_paths`

- API：`public`

```gdscript
var export_plugin_paths: Array[String] = []
```

可选 EditorExportPlugin 路径列表。

<a id="member-gfextensionmanifest-properties-gltf_document_extension_paths"></a>

### `gltf_document_extension_paths`

- API：`public`

```gdscript
var gltf_document_extension_paths: Array[String] = []
```

可选 GLTFDocumentExtension 路径列表。用于导入期资产元数据桥接等编辑器能力。

<a id="member-gfextensionmanifest-properties-access_generator_extension_paths"></a>

### `access_generator_extension_paths`

- API：`public`

```gdscript
var access_generator_extension_paths: Array[String] = []
```

可选 GFAccessGenerator 扩展脚本路径列表。

<a id="member-gfextensionmanifest-properties-tags"></a>

### `tags`

- API：`public`

```gdscript
var tags: Array[String] = []
```

便于工具筛选的标签。

<a id="member-gfextensionmanifest-properties-enabled_by_default"></a>

### `enabled_by_default`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var enabled_by_default: bool = false
```

是否在项目首次启用 GF 时进入默认扩展选择。

<a id="member-gfextensionmanifest-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: String = ""
```

manifest 文件路径。

## 方法

<a id="member-gfextensionmanifest-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`

```gdscript
static func from_dictionary( data: Dictionary, extension_root_path: String = "", manifest_source_path: String = "" ) -> GFExtensionManifest:
```

从字典创建扩展 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `data` | manifest 字典。 |
| `extension_root_path` | 扩展根目录。 |
| `manifest_source_path` | manifest 文件路径。 |

返回：扩展 manifest 实例。

结构：

- `data`: Dictionary decoded from gf_extension.json.

<a id="member-gfextensionmanifest-methods-from_json_file"></a>

### `from_json_file`

- API：`public`

```gdscript
static func from_json_file(path: String) -> GFExtensionManifest:
```

从 JSON 文件读取扩展 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `path` | `gf_extension.json` 文件路径。 |

返回：读取成功时返回 manifest；失败时返回 null。

<a id="member-gfextensionmanifest-methods-from_json_file_report"></a>

### `from_json_file_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_json_file_report(path: String) -> Dictionary:
```

从 JSON 文件读取扩展 manifest 并返回诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `path` | `gf_extension.json` 文件路径。 |

返回：读取诊断，包含 ok、source_path、manifest_data 和 errors。

结构：

- `return`: Dictionary { ok: bool, source_path: String, manifest_data: Dictionary, errors: Array[String] }.

<a id="member-gfextensionmanifest-methods-is_valid_extension_id"></a>

### `is_valid_extension_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func is_valid_extension_id(extension_id: String) -> bool:
```

判断文本是否是合法 GF 扩展 ID。 合法 ID 使用小写 dotted identifier segments，例如 `vendor.feature` 或 `author.feature_name`。它是机器稳定 ID，不承载显示名、路径或加载顺序。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 要检查的扩展 ID。 |

返回：满足扩展 ID 语法时返回 true。

<a id="member-gfextensionmanifest-methods-get_extension_id_validation_error"></a>

### `get_extension_id_validation_error`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func get_extension_id_validation_error(extension_id: String, field_name: String = "id") -> String:
```

获取扩展 ID 语法错误。

参数：

| 名称 | 说明 |
|---|---|
| `extension_id` | 要检查的扩展 ID。 |
| `field_name` | 报错中使用的字段名。 |

返回：ID 合法时返回空字符串，否则返回错误说明。

<a id="member-gfextensionmanifest-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：manifest 字典副本。

结构：

- `return`: Dictionary matching the gf_extension.json manifest shape.

<a id="member-gfextensionmanifest-methods-duplicate_manifest"></a>

### `duplicate_manifest`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_manifest() -> GFExtensionManifest:
```

创建 manifest 副本。

返回：与当前 manifest 内容一致的新实例。

<a id="member-gfextensionmanifest-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
func is_valid() -> bool:
```

检查 manifest 是否满足基本规范。

返回：满足规范时返回 true。

<a id="member-gfextensionmanifest-methods-get_validation_errors"></a>

### `get_validation_errors`

- API：`public`

```gdscript
func get_validation_errors() -> Array[String]:
```

获取 manifest 规范错误。

返回：错误消息列表。
