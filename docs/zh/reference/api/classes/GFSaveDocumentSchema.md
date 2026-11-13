# GFSaveDocumentSchema

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/document/gf_save_document_schema.gd`
- 模块：`Save`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`9.0.0`

项目存档文档的当前版本契约。 项目用该 Resource 声明 schema_id、当前文档版本、已知分区版本和必需分区。 GF 只校验结构与版本，不解释任何业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`schema_id`](#member-gfsavedocumentschema-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`schema_version`](#member-gfsavedocumentschema-properties-schema_version) | `var schema_version: int = 1` |
| 属性 | [`section_versions`](#member-gfsavedocumentschema-properties-section_versions) | `var section_versions: Dictionary = {}` |
| 属性 | [`required_sections`](#member-gfsavedocumentschema-properties-required_sections) | `var required_sections: PackedStringArray = PackedStringArray()` |
| 属性 | [`preserved_sections`](#member-gfsavedocumentschema-properties-preserved_sections) | `var preserved_sections: PackedStringArray = PackedStringArray()` |
| 方法 | [`configure`](#member-gfsavedocumentschema-methods-configure) | `func configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> GFSaveDocumentSchema:` |
| 方法 | [`validate_configuration`](#member-gfsavedocumentschema-methods-validate_configuration) | `static func validate_configuration( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`try_configure`](#member-gfsavedocumentschema-methods-try_configure) | `func try_configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_preserved_section_limits`](#member-gfsavedocumentschema-methods-get_preserved_section_limits) | `static func get_preserved_section_limits() -> Dictionary:` |
| 方法 | [`measure_preserved_section`](#member-gfsavedocumentschema-methods-measure_preserved_section) | `static func measure_preserved_section(section: GFSaveSection) -> Dictionary:` |
| 方法 | [`get_section_version`](#member-gfsavedocumentschema-methods-get_section_version) | `func get_section_version(section_id: StringName) -> int:` |
| 方法 | [`has_section`](#member-gfsavedocumentschema-methods-has_section) | `func has_section(section_id: StringName) -> bool:` |
| 方法 | [`get_section_ids`](#member-gfsavedocumentschema-methods-get_section_ids) | `func get_section_ids() -> PackedStringArray:` |
| 方法 | [`validate_schema`](#member-gfsavedocumentschema-methods-validate_schema) | `func validate_schema() -> Dictionary:` |
| 方法 | [`validate_document`](#member-gfsavedocumentschema-methods-validate_document) | `func validate_document(document: GFSaveDocument, require_current_versions: bool = true) -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfsavedocumentschema-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfsavedocumentschema-methods-duplicate_schema) | `func duplicate_schema() -> GFSaveDocumentSchema:` |
| 方法 | [`from_dict`](#member-gfsavedocumentschema-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSaveDocumentSchema:` |

## 属性

<a id="member-gfsavedocumentschema-properties-schema_id"></a>

### `schema_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
@export
var schema_id: StringName = &""
```

项目存档 schema 的稳定 ID。

<a id="member-gfsavedocumentschema-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
@export
var schema_version: int = 1
```

当前文档 schema 版本。

<a id="member-gfsavedocumentschema-properties-section_versions"></a>

### `section_versions`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
@export
var section_versions: Dictionary = {}
```

已知分区及其当前版本。

结构：

- `section_versions`: Dictionary from non-empty section_id to positive int version.

<a id="member-gfsavedocumentschema-properties-required_sections"></a>

### `required_sections`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
@export
var required_sections: PackedStringArray = PackedStringArray()
```

当前 schema 必须存在的分区。

<a id="member-gfsavedocumentschema-properties-preserved_sections"></a>

### `preserved_sections`

- API：`public`
- 首次版本：`unreleased`

```gdscript
@export
var preserved_sections: PackedStringArray = PackedStringArray()
```

允许原样保留但不解释的分区 ID 清单；默认拒绝全部未知分区。

## 方法

<a id="member-gfsavedocumentschema-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> GFSaveDocumentSchema:
```

配置当前 schema 契约，保留返回当前对象的旧用法。 失败时不覆盖原字段，但 validate_schema() 会报告最近的配置错误，to_dict() 返回空。 调用 try_configure() 可直接取得诊断；使用合法参数再次配置后解除拒绝状态。

参数：

| 名称 | 说明 |
|---|---|
| `p_schema_id` | 稳定 schema ID。 |
| `p_schema_version` | 当前文档版本。 |
| `p_section_versions` | 分区当前版本映射。 |
| `options` | 可包含 required_sections 与 preserved_sections。 |

返回：当前 schema。

结构：

- `p_section_versions`: Dictionary from non-empty section_id to positive int version.
- `options`: Dictionary with optional required_sections: PackedStringArray and preserved_sections: PackedStringArray.

<a id="member-gfsavedocumentschema-methods-validate_configuration"></a>

### `validate_configuration`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func validate_configuration( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

只读验证完整配置；不改变当前对象或清除其上次配置错误。

参数：

| 名称 | 说明 |
|---|---|
| `p_schema_id` | 文档 schema 身份。 |
| `p_schema_version` | 当前正整数版本。 |
| `p_section_versions` | 分区版本映射。 |
| `options` | 只接受 required_sections 和 preserved_sections。 |

返回：不含业务载荷的配置诊断。

结构：

- `p_section_versions`: 与 configure() 相同的 Dictionary。
- `options`: 与 configure() 相同的闭合 Dictionary；allow_unknown_sections 已移除且不会自动转换。
- `return`: Dictionary with ok:bool,error_kind:StringName,path:String.

<a id="member-gfsavedocumentschema-methods-try_configure"></a>

### `try_configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func try_configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> Dictionary:
```

原子应用完整配置并返回诊断；失败保留原字段，同时阻止旧字段被误当作本次配置成功。

参数：

| 名称 | 说明 |
|---|---|
| `p_schema_id` | 文档 schema 身份。 |
| `p_schema_version` | 当前正整数版本。 |
| `p_section_versions` | 分区版本映射。 |
| `options` | 只接受 required_sections 和 preserved_sections。 |

返回：配置诊断；再次成功配置会清除上次错误。

结构：

- `p_section_versions`: 与 configure() 相同的 Dictionary。
- `options`: 与 configure() 相同的闭合 Dictionary。
- `return`: Dictionary with ok:bool,error_kind:StringName,path:String.

<a id="member-gfsavedocumentschema-methods-get_preserved_section_limits"></a>

### `get_preserved_section_limits`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_preserved_section_limits() -> Dictionary:
```

获取每个未知保留分区的固定规范编码预算。

返回：独立预算记录；整个请求仍须接受它所在层的总预算。

结构：

- `return`: Dictionary with max_depth:int,max_items:int,max_output_bytes:int,max_string_length:int.

<a id="member-gfsavedocumentschema-methods-measure_preserved_section"></a>

### `measure_preserved_section`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func measure_preserved_section(section: GFSaveSection) -> Dictionary:
```

只读计量一个未知保留分区，不复制业务载荷。

参数：

| 名称 | 说明 |
|---|---|
| `section` | 待保留的完整分区；是否允许该 ID 仍由 validate_document() 判定。 |

返回：不含业务载荷的预算报告。

结构：

- `return`: Dictionary with ok:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary.

<a id="member-gfsavedocumentschema-methods-get_section_version"></a>

### `get_section_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_section_version(section_id: StringName) -> int:
```

获取指定分区的当前版本。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区 ID。 |

返回：已声明版本；未知分区返回 0。

<a id="member-gfsavedocumentschema-methods-has_section"></a>

### `has_section`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func has_section(section_id: StringName) -> bool:
```

检查是否声明了分区。

参数：

| 名称 | 说明 |
|---|---|
| `section_id` | 分区 ID。 |

返回：已声明时返回 true。

<a id="member-gfsavedocumentschema-methods-get_section_ids"></a>

### `get_section_ids`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_section_ids() -> PackedStringArray:
```

获取排序后的已知分区 ID。

返回：已知分区 ID。

<a id="member-gfsavedocumentschema-methods-validate_schema"></a>

### `validate_schema`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func validate_schema() -> Dictionary:
```

校验 schema 自身。

返回：结构化校验报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.

<a id="member-gfsavedocumentschema-methods-validate_document"></a>

### `validate_document`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func validate_document(document: GFSaveDocument, require_current_versions: bool = true) -> Dictionary:
```

校验文档是否符合该 schema。

参数：

| 名称 | 说明 |
|---|---|
| `document` | 待校验文档。 |
| `require_current_versions` | 为 true 时要求文档和已知分区恰好为当前版本；为 false 时旧版本仅产生迁移警告。 |

返回：结构化兼容性报告。

结构：

- `return`: GFValidationReportDictionary-compatible report with compatible, migration_required, schema_id, schema_version, issues, counts, summary, and next_actions.

<a id="member-gfsavedocumentschema-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：schema 字典。

结构：

- `return`: Dictionary with schema_id, schema_version, section_versions, required_sections, and preserved_sections; empty while a rejected configure() has not been corrected.

<a id="member-gfsavedocumentschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func duplicate_schema() -> GFSaveDocumentSchema:
```

创建 schema 副本。

返回：隔离 schema。

<a id="member-gfsavedocumentschema-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFSaveDocumentSchema:
```

从字典创建 schema。 该方法执行严格边界检查，不修补非法字段或忽略未知字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | schema 字典。 |

返回：新 schema；输入不规范或 schema 自身无效时返回 null。

结构：

- `data`: Dictionary with schema_id, schema_version, section_versions, required_sections, and preserved_sections.
