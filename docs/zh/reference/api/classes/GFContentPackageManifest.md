# GFContentPackageManifest

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/resources/gf_content_package_manifest.gd`
- 模块：`Extensions / Content Package`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.4.0`

通用内容包 manifest。 描述一个内容包的稳定包 ID、版本、依赖和资源键映射。GF 只校验结构、路径安全和依赖关系， 不解释内容类型的业务语义，也不负责下载、启用策略或具体玩法规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`FILE_NAME`](#member-gfcontentpackagemanifest-constants-file_name) | `const FILE_NAME: String = "gf_content_package.json"` |
| 常量 | [`SCHEMA_VERSION`](#member-gfcontentpackagemanifest-constants-schema_version) | `const SCHEMA_VERSION: int = 1` |
| 常量 | [`SAFETY_KIND_DATA_ONLY`](#member-gfcontentpackagemanifest-constants-safety_kind_data_only) | `const SAFETY_KIND_DATA_ONLY: StringName = &"data_only"` |
| 常量 | [`SAFETY_KIND_TRUSTED_DEVELOPER`](#member-gfcontentpackagemanifest-constants-safety_kind_trusted_developer) | `const SAFETY_KIND_TRUSTED_DEVELOPER: StringName = &"trusted_developer"` |
| 属性 | [`schema_version`](#member-gfcontentpackagemanifest-properties-schema_version) | `var schema_version: int = SCHEMA_VERSION` |
| 属性 | [`package_id`](#member-gfcontentpackagemanifest-properties-package_id) | `var package_id: StringName = &""` |
| 属性 | [`display_name`](#member-gfcontentpackagemanifest-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`version`](#member-gfcontentpackagemanifest-properties-version) | `var version: String = ""` |
| 属性 | [`content_types`](#member-gfcontentpackagemanifest-properties-content_types) | `var content_types: PackedStringArray = PackedStringArray()` |
| 属性 | [`dependencies`](#member-gfcontentpackagemanifest-properties-dependencies) | `var dependencies: PackedStringArray = PackedStringArray()` |
| 属性 | [`safety_kind`](#member-gfcontentpackagemanifest-properties-safety_kind) | `var safety_kind: StringName = SAFETY_KIND_DATA_ONLY` |
| 属性 | [`forbidden_resource_extensions`](#member-gfcontentpackagemanifest-properties-forbidden_resource_extensions) | `var forbidden_resource_extensions: PackedStringArray = PackedStringArray()` |
| 属性 | [`resources`](#member-gfcontentpackagemanifest-properties-resources) | `var resources: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfcontentpackagemanifest-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`root_path`](#member-gfcontentpackagemanifest-properties-root_path) | `var root_path: String = ""` |
| 属性 | [`source_path`](#member-gfcontentpackagemanifest-properties-source_path) | `var source_path: String = ""` |
| 方法 | [`configure`](#member-gfcontentpackagemanifest-methods-configure) | `func configure( p_package_id: StringName, p_version: String, p_resources: Array[Dictionary] = [], p_display_name: String = "", p_content_types: PackedStringArray = PackedStringArray(), p_dependencies: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {}, p_root_path: String = "", p_source_path: String = "", p_safety_kind: StringName = SAFETY_KIND_DATA_ONLY, p_forbidden_resource_extensions: PackedStringArray = PackedStringArray() ) -> GFContentPackageManifest:` |
| 方法 | [`apply_dictionary`](#member-gfcontentpackagemanifest-methods-apply_dictionary) | `func apply_dictionary(data: Dictionary, p_root_path: String = "", p_source_path: String = "") -> void:` |
| 方法 | [`to_dictionary`](#member-gfcontentpackagemanifest-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`to_report_dictionary`](#member-gfcontentpackagemanifest-methods-to_report_dictionary) | `func to_report_dictionary(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_manifest`](#member-gfcontentpackagemanifest-methods-duplicate_manifest) | `func duplicate_manifest() -> GFContentPackageManifest:` |
| 方法 | [`is_valid`](#member-gfcontentpackagemanifest-methods-is_valid) | `func is_valid(options: Dictionary = {}) -> bool:` |
| 方法 | [`get_validation_report`](#member-gfcontentpackagemanifest-methods-get_validation_report) | `func get_validation_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_validation_errors`](#member-gfcontentpackagemanifest-methods-get_validation_errors) | `func get_validation_errors(options: Dictionary = {}) -> Array[String]:` |
| 方法 | [`get_normalized_resources`](#member-gfcontentpackagemanifest-methods-get_normalized_resources) | `func get_normalized_resources() -> Array[Dictionary]:` |
| 方法 | [`get_resource_keys`](#member-gfcontentpackagemanifest-methods-get_resource_keys) | `func get_resource_keys() -> PackedStringArray:` |
| 方法 | [`from_dictionary`](#member-gfcontentpackagemanifest-methods-from_dictionary) | `static func from_dictionary( data: Dictionary, p_root_path: String = "", p_source_path: String = "" ) -> GFContentPackageManifest:` |
| 方法 | [`load_from_path`](#member-gfcontentpackagemanifest-methods-load_from_path) | `static func load_from_path(path: String) -> GFContentPackageManifest:` |

## 常量

<a id="member-gfcontentpackagemanifest-constants-file_name"></a>

### `FILE_NAME`

- API：`public`

```gdscript
const FILE_NAME: String = "gf_content_package.json"
```

内容包 JSON manifest 默认文件名。

<a id="member-gfcontentpackagemanifest-constants-schema_version"></a>

### `SCHEMA_VERSION`

- API：`public`

```gdscript
const SCHEMA_VERSION: int = 1
```

当前 manifest schema 版本。

<a id="member-gfcontentpackagemanifest-constants-safety_kind_data_only"></a>

### `SAFETY_KIND_DATA_ONLY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const SAFETY_KIND_DATA_ONLY: StringName = &"data_only"
```

只允许数据资源的内容包安全分类。

<a id="member-gfcontentpackagemanifest-constants-safety_kind_trusted_developer"></a>

### `SAFETY_KIND_TRUSTED_DEVELOPER`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const SAFETY_KIND_TRUSTED_DEVELOPER: StringName = &"trusted_developer"
```

允许开发者代码资源的内容包安全分类。

## 属性

<a id="member-gfcontentpackagemanifest-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var schema_version: int = SCHEMA_VERSION
```

manifest schema 版本。JSON manifest 必须显式声明当前支持的版本。

<a id="member-gfcontentpackagemanifest-properties-package_id"></a>

### `package_id`

- API：`public`

```gdscript
var package_id: StringName = &""
```

稳定内容包 ID。

<a id="member-gfcontentpackagemanifest-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器或诊断显示名。

<a id="member-gfcontentpackagemanifest-properties-version"></a>

### `version`

- API：`public`

```gdscript
var version: String = ""
```

内容包版本字符串。

<a id="member-gfcontentpackagemanifest-properties-content_types"></a>

### `content_types`

- API：`public`

```gdscript
var content_types: PackedStringArray = PackedStringArray()
```

内容类型标签。GF 只做归一化和诊断，不解释业务语义。

<a id="member-gfcontentpackagemanifest-properties-dependencies"></a>

### `dependencies`

- API：`public`

```gdscript
var dependencies: PackedStringArray = PackedStringArray()
```

依赖内容包 ID 列表。

<a id="member-gfcontentpackagemanifest-properties-safety_kind"></a>

### `safety_kind`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var safety_kind: StringName = SAFETY_KIND_DATA_ONLY
```

内容包安全分类。data_only 默认拒绝脚本、shader、GDExtension 和可执行文件。

<a id="member-gfcontentpackagemanifest-properties-forbidden_resource_extensions"></a>

### `forbidden_resource_extensions`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var forbidden_resource_extensions: PackedStringArray = PackedStringArray()
```

调用方额外禁止的资源扩展名，不需要前导点。

<a id="member-gfcontentpackagemanifest-properties-resources"></a>

### `resources`

- API：`public`

```gdscript
var resources: Array[Dictionary] = []
```

资源键映射列表。

结构：

- `resources`: Array[Dictionary]，每项包含 key、path、可选 type_hint、priority 和 metadata。

<a id="member-gfcontentpackagemanifest-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 不解释其中业务字段。

结构：

- `metadata`: Dictionary project-defined content package metadata.

<a id="member-gfcontentpackagemanifest-properties-root_path"></a>

### `root_path`

- API：`public`

```gdscript
var root_path: String = ""
```

manifest 所在内容包根目录。通常由加载路径推导。

<a id="member-gfcontentpackagemanifest-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: String = ""
```

manifest 文件路径。通常指向 `gf_content_package.json`。

## 方法

<a id="member-gfcontentpackagemanifest-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func configure( p_package_id: StringName, p_version: String, p_resources: Array[Dictionary] = [], p_display_name: String = "", p_content_types: PackedStringArray = PackedStringArray(), p_dependencies: PackedStringArray = PackedStringArray(), p_metadata: Dictionary = {}, p_root_path: String = "", p_source_path: String = "", p_safety_kind: StringName = SAFETY_KIND_DATA_ONLY, p_forbidden_resource_extensions: PackedStringArray = PackedStringArray() ) -> GFContentPackageManifest:
```

配置 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `p_package_id` | 稳定内容包 ID。 |
| `p_version` | 内容包版本。 |
| `p_resources` | 资源键映射列表。 |
| `p_display_name` | 可选显示名。 |
| `p_content_types` | 内容类型标签。 |
| `p_dependencies` | 依赖内容包 ID 列表。 |
| `p_metadata` | 项目自定义元数据。 |
| `p_root_path` | 内容包根目录。 |
| `p_source_path` | manifest 文件路径。 |
| `p_safety_kind` | 内容包安全分类。 |
| `p_forbidden_resource_extensions` | 调用方额外禁止的资源扩展名。 |

返回：当前 manifest。

结构：

- `p_resources`: Array[Dictionary]，每项包含 key、path、可选 type_hint、priority 和 metadata。
- `p_metadata`: Dictionary project-defined content package metadata.
- `p_forbidden_resource_extensions`: PackedStringArray extension names without leading dots.

<a id="member-gfcontentpackagemanifest-methods-apply_dictionary"></a>

### `apply_dictionary`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func apply_dictionary(data: Dictionary, p_root_path: String = "", p_source_path: String = "") -> void:
```

从字典应用 manifest 字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | manifest 字典。 |
| `p_root_path` | 内容包根目录。 |
| `p_source_path` | manifest 文件路径。 |

结构：

- `data`: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、safety_kind、forbidden_resource_extensions、resources 和 metadata；字段类型必须与 manifest schema 一致，不执行字符串、数组或字典宽松转换。

<a id="member-gfcontentpackagemanifest-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为内容包 manifest 字典。

返回：manifest 字典副本。

结构：

- `return`: Dictionary，包含 schema_version、package_id、display_name、version、content_types、dependencies、resources 和 metadata。

<a id="member-gfcontentpackagemanifest-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
```

转换为 JSON-safe 报告字典。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 传给 GFReportValueCodec 的编码选项。 |

返回：manifest 报告字典。

结构：

- `options`: Dictionary with GFReportValueCodec encoding options.
- `return`: JSON-safe Dictionary based on to_dictionary().

<a id="member-gfcontentpackagemanifest-methods-duplicate_manifest"></a>

### `duplicate_manifest`

- API：`public`

```gdscript
func duplicate_manifest() -> GFContentPackageManifest:
```

创建 manifest 深拷贝。

返回：新 manifest。

<a id="member-gfcontentpackagemanifest-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func is_valid(options: Dictionary = {}) -> bool:
```

检查 manifest 是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项。可启用文件存在性与传递依赖安全扫描。 |

返回：无 error issue 时返回 true。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。

<a id="member-gfcontentpackagemanifest-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_validation_report(options: Dictionary = {}) -> Dictionary:
```

获取 manifest 校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项。可启用文件存在性与传递依赖安全扫描。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count、warning_count、issue_count、package_id、source_path 和 resource_count。

<a id="member-gfcontentpackagemanifest-methods-get_validation_errors"></a>

### `get_validation_errors`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_validation_errors(options: Dictionary = {}) -> Array[String]:
```

获取校验错误文本列表。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项。可启用文件存在性与传递依赖安全扫描。 |

返回：错误文本列表。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。

<a id="member-gfcontentpackagemanifest-methods-get_normalized_resources"></a>

### `get_normalized_resources`

- API：`public`

```gdscript
func get_normalized_resources() -> Array[Dictionary]:
```

获取归一化资源键映射。

返回：资源映射副本。

结构：

- `return`: Array[Dictionary]，每项包含 key、path、type_hint、priority、metadata 和 package_id。

<a id="member-gfcontentpackagemanifest-methods-get_resource_keys"></a>

### `get_resource_keys`

- API：`public`

```gdscript
func get_resource_keys() -> PackedStringArray:
```

获取 manifest 中声明的资源键列表。

返回：排序后的资源键列表。

<a id="member-gfcontentpackagemanifest-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
static func from_dictionary( data: Dictionary, p_root_path: String = "", p_source_path: String = "" ) -> GFContentPackageManifest:
```

从字典创建 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `data` | manifest 字典。 |
| `p_root_path` | 内容包根目录。 |
| `p_source_path` | manifest 文件路径。 |

返回：新 manifest。

结构：

- `data`: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、safety_kind、forbidden_resource_extensions、resources 和 metadata；字段类型必须与 manifest schema 一致。

<a id="member-gfcontentpackagemanifest-methods-load_from_path"></a>

### `load_from_path`

- API：`public`

```gdscript
static func load_from_path(path: String) -> GFContentPackageManifest:
```

从 JSON manifest 文件加载内容包。

参数：

| 名称 | 说明 |
|---|---|
| `path` | manifest 文件路径。 |

返回：加载成功返回 manifest；解析失败返回 null。
