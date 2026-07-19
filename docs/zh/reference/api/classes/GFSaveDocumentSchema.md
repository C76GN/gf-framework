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
| 属性 | [`allow_unknown_sections`](#member-gfsavedocumentschema-properties-allow_unknown_sections) | `var allow_unknown_sections: bool = true` |
| 方法 | [`configure`](#member-gfsavedocumentschema-methods-configure) | `func configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> GFSaveDocumentSchema:` |
| 方法 | [`get_section_version`](#member-gfsavedocumentschema-methods-get_section_version) | `func get_section_version(section_id: StringName) -> int:` |
| 方法 | [`has_section`](#member-gfsavedocumentschema-methods-has_section) | `func has_section(section_id: StringName) -> bool:` |
| 方法 | [`get_section_ids`](#member-gfsavedocumentschema-methods-get_section_ids) | `func get_section_ids() -> PackedStringArray:` |
| 方法 | [`validate_schema`](#member-gfsavedocumentschema-methods-validate_schema) | `func validate_schema() -> Dictionary:` |
| 方法 | [`validate_document`](#member-gfsavedocumentschema-methods-validate_document) | `func validate_document( document: GFSaveDocument, require_current_versions: bool = true ) -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfsavedocumentschema-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfsavedocumentschema-methods-duplicate_schema) | `func duplicate_schema() -> GFSaveDocumentSchema:` |
| 方法 | [`from_dict`](#member-gfsavedocumentschema-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSaveDocumentSchema:` |

## 属性

<a id="member-gfsavedocumentschema-properties-schema_id"></a>

### `schema_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var schema_id: StringName = &""
```

项目存档 schema 的稳定 ID。

<a id="member-gfsavedocumentschema-properties-schema_version"></a>

### `schema_version`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var schema_version: int = 1
```

当前文档 schema 版本。

<a id="member-gfsavedocumentschema-properties-section_versions"></a>

### `section_versions`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
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
var required_sections: PackedStringArray = PackedStringArray()
```

当前 schema 必须存在的分区。

<a id="member-gfsavedocumentschema-properties-allow_unknown_sections"></a>

### `allow_unknown_sections`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
var allow_unknown_sections: bool = true
```

是否允许并原样保留 schema 未声明的分区。

## 方法

<a id="member-gfsavedocumentschema-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure( p_schema_id: StringName, p_schema_version: int, p_section_versions: Dictionary = {}, options: Dictionary = {} ) -> GFSaveDocumentSchema:
```

配置当前 schema 契约。

参数：

| 名称 | 说明 |
|---|---|
| `p_schema_id` | 稳定 schema ID。 |
| `p_schema_version` | 当前文档版本。 |
| `p_section_versions` | 分区当前版本映射。 |
| `options` | 可包含 required_sections 与 allow_unknown_sections。 |

返回：当前 schema。

结构：

- `p_section_versions`: Dictionary from non-empty section_id to positive int version.
- `options`: Dictionary with optional required_sections: PackedStringArray and allow_unknown_sections: bool.

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
func validate_document( document: GFSaveDocument, require_current_versions: bool = true ) -> Dictionary:
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

- `return`: Dictionary with schema_id, schema_version, section_versions, required_sections, and allow_unknown_sections.

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

- `data`: Dictionary with schema_id, schema_version, section_versions, required_sections, and allow_unknown_sections.
