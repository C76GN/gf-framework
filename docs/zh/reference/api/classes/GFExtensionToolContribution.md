# GFExtensionToolContribution

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/extension/gf_extension_tool_contribution.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

扩展编辑器工具贡献文件的稳定 schema 解析器。 该类型只定义贡献文件协议，不负责加载脚本、验证资源存在性或管理编辑器生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SCHEMA_VERSION`](#member-gfextensiontoolcontribution-constants-schema_version) | `const SCHEMA_VERSION: int = 3` |
| 常量 | [`PATH_FIELDS`](#member-gfextensiontoolcontribution-constants-path_fields) | `const PATH_FIELDS: Array[String] = [ 	"access_generator_extension_paths", 	"debugger_plugin_paths", 	"editor_action_paths", 	"editor_dock_paths", 	"editor_inspector_paths", 	"export_plugin_paths", 	"gltf_document_extension_paths", 	"import_plugin_paths", ]` |
| 常量 | [`ALLOWED_FIELDS`](#member-gfextensiontoolcontribution-constants-allowed_fields) | `const ALLOWED_FIELDS: Array[String] = [ 	"task_records", 	"resource_action_records", 	"schema_version", 	"extension_id", 	"access_generator_extension_paths", 	"debugger_plugin_paths", 	"editor_action_paths", 	"editor_dock_paths", 	"editor_inspector_paths", 	"export_plugin_paths", 	"gltf_document_extension_paths", 	"import_plugin_paths", ]` |
| 方法 | [`parse_dictionary`](#member-gfextensiontoolcontribution-methods-parse_dictionary) | `static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:` |

## 常量

<a id="member-gfextensiontoolcontribution-constants-schema_version"></a>

### `SCHEMA_VERSION`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const SCHEMA_VERSION: int = 3
```

当前支持的贡献文件 schema 版本。

<a id="member-gfextensiontoolcontribution-constants-path_fields"></a>

### `PATH_FIELDS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const PATH_FIELDS: Array[String] = [
	"access_generator_extension_paths",
	"debugger_plugin_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]
```

所有可声明的工具贡献路径字段。

<a id="member-gfextensiontoolcontribution-constants-allowed_fields"></a>

### `ALLOWED_FIELDS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const ALLOWED_FIELDS: Array[String] = [
	"task_records",
	"resource_action_records",
	"schema_version",
	"extension_id",
	"access_generator_extension_paths",
	"debugger_plugin_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]
```

工具贡献文件允许的全部顶层字段。

## 方法

<a id="member-gfextensiontoolcontribution-methods-parse_dictionary"></a>

### `parse_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:
```

校验并规范化一个工具贡献字典。 接受 v2 与 v3；v3 额外支持任务和资源动作记录。未知字段、其他 schema、错误扩展 ID、非数组路径字段、 非字符串或空路径都会使报告失败。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 待校验的 JSON object 数据。 |
| `expected_extension_id` | 非空时要求 contribution 的 extension_id 与其一致。 |

返回：schema 校验报告。

结构：

- `data`: Dictionary，字段必须属于 ALLOWED_FIELDS。
- `return`: Dictionary，含 ok: bool、data: Dictionary、errors: Array[String]；仅 ok 为 true 时可消费 data。data 始终含 schema_version: int、extension_id: String 及全部 PATH_FIELDS（去空白、去重的字符串数组，省略时为空）。v2 不返回工作区记录字段，输入携带它们时失败；v3 另含 task_records、resource_action_records: Array[Dictionary]（省略时为空）。每项均含 owner_package_id: String（默认 extension_id）、source_id: String（owner_package_id:本地来源 ID）、title: String（去首尾空白）、description: String（默认空）、keywords: 字符串数组（默认空）、group: String（默认“常用”）、page_path: String（保留声明路径，须匹配同一 owner 的 editor_dock_paths）、action_id: String（任务默认空）。资源动作另要求 action_id 非空，并含 resource_types: 非空字符串数组（仅 Resource、PackedScene、Texture2D、AudioStream、Font、Material、Mesh、Script）、max_selection: int（1 到 100，默认 1）。失败时 errors 非空，data 可保留部分规范化结果，不能作为已通过校验的贡献。
