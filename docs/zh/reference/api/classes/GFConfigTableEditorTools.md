# GFConfigTableEditorTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_editor_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`6.0.0`

配置表 schema 的编辑器描述辅助。 该工具只把 `GFConfigTableSchema`、列声明和跨表引用转换为通用描述字典， 供 Inspector、表格编辑器、CI 预览或项目侧工具自由消费；不会创建 UI 控件， 也不规定具体业务字段语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`METADATA_LABEL_KEY`](#member-gfconfigtableeditortools-constants-metadata_label_key) | `const METADATA_LABEL_KEY: StringName = &"label"` |
| 常量 | [`METADATA_EDITOR_LABEL_KEY`](#member-gfconfigtableeditortools-constants-metadata_editor_label_key) | `const METADATA_EDITOR_LABEL_KEY: StringName = &"editor_label"` |
| 常量 | [`METADATA_EDITABLE_KEY`](#member-gfconfigtableeditortools-constants-metadata_editable_key) | `const METADATA_EDITABLE_KEY: StringName = &"editable"` |
| 常量 | [`METADATA_CHOICES_KEY`](#member-gfconfigtableeditortools-constants-metadata_choices_key) | `const METADATA_CHOICES_KEY: StringName = &"choices"` |
| 常量 | [`METADATA_HINT_KEY`](#member-gfconfigtableeditortools-constants-metadata_hint_key) | `const METADATA_HINT_KEY: StringName = &"hint"` |
| 常量 | [`METADATA_LABEL_FIELDS_KEY`](#member-gfconfigtableeditortools-constants-metadata_label_fields_key) | `const METADATA_LABEL_FIELDS_KEY: StringName = &"label_fields"` |
| 常量 | [`METADATA_EDITOR_KIND_KEY`](#member-gfconfigtableeditortools-constants-metadata_editor_kind_key) | `const METADATA_EDITOR_KIND_KEY: StringName = &"editor_kind"` |
| 常量 | [`METADATA_PROPERTY_TYPE_KEY`](#member-gfconfigtableeditortools-constants-metadata_property_type_key) | `const METADATA_PROPERTY_TYPE_KEY: StringName = &"property_type"` |
| 常量 | [`METADATA_PROPERTY_HINT_KEY`](#member-gfconfigtableeditortools-constants-metadata_property_hint_key) | `const METADATA_PROPERTY_HINT_KEY: StringName = &"property_hint"` |
| 常量 | [`METADATA_PROPERTY_HINT_STRING_KEY`](#member-gfconfigtableeditortools-constants-metadata_property_hint_string_key) | `const METADATA_PROPERTY_HINT_STRING_KEY: StringName = &"property_hint_string"` |
| 常量 | [`METADATA_RESOURCE_TYPE_KEY`](#member-gfconfigtableeditortools-constants-metadata_resource_type_key) | `const METADATA_RESOURCE_TYPE_KEY: StringName = &"resource_type"` |
| 常量 | [`METADATA_RESOURCE_EXTENSIONS_KEY`](#member-gfconfigtableeditortools-constants-metadata_resource_extensions_key) | `const METADATA_RESOURCE_EXTENSIONS_KEY: StringName = &"resource_extensions"` |
| 方法 | [`build_column_descriptors`](#member-gfconfigtableeditortools-methods-build_column_descriptors) | `static func build_column_descriptors( schema: GFConfigTableSchema, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`build_field_editor_descriptors`](#member-gfconfigtableeditortools-methods-build_field_editor_descriptors) | `static func build_field_editor_descriptors( schema: GFConfigTableSchema, database: GFConfigDatabaseResource = null, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`build_reference_choice_records`](#member-gfconfigtableeditortools-methods-build_reference_choice_records) | `static func build_reference_choice_records( reference_definition: GFConfigTableReference, target_table: Variant, target_schema: GFConfigTableSchema = null, options: Dictionary = {} ) -> Array[Dictionary]:` |
| 方法 | [`build_reference_choice_records_for_database`](#member-gfconfigtableeditortools-methods-build_reference_choice_records_for_database) | `static func build_reference_choice_records_for_database( database: GFConfigDatabaseResource, reference_definition: GFConfigTableReference, options: Dictionary = {} ) -> Array[Dictionary]:` |

## 常量

<a id="member-gfconfigtableeditortools-constants-metadata_label_key"></a>

### `METADATA_LABEL_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_LABEL_KEY: StringName = &"label"
```

列 metadata 中的通用显示标签键。

<a id="member-gfconfigtableeditortools-constants-metadata_editor_label_key"></a>

### `METADATA_EDITOR_LABEL_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_EDITOR_LABEL_KEY: StringName = &"editor_label"
```

列 metadata 中的编辑器显示标签键，优先级高于 label。

<a id="member-gfconfigtableeditortools-constants-metadata_editable_key"></a>

### `METADATA_EDITABLE_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_EDITABLE_KEY: StringName = &"editable"
```

列 metadata 中的可编辑状态键。

<a id="member-gfconfigtableeditortools-constants-metadata_choices_key"></a>

### `METADATA_CHOICES_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_CHOICES_KEY: StringName = &"choices"
```

列 metadata 中的通用候选值键。

<a id="member-gfconfigtableeditortools-constants-metadata_hint_key"></a>

### `METADATA_HINT_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_HINT_KEY: StringName = &"hint"
```

列 metadata 中的通用提示文本键。

<a id="member-gfconfigtableeditortools-constants-metadata_label_fields_key"></a>

### `METADATA_LABEL_FIELDS_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_LABEL_FIELDS_KEY: StringName = &"label_fields"
```

引用或 schema metadata 中声明选项显示字段的键。

<a id="member-gfconfigtableeditortools-constants-metadata_editor_kind_key"></a>

### `METADATA_EDITOR_KIND_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_EDITOR_KIND_KEY: StringName = &"editor_kind"
```

列 metadata 中的编辑器类型覆盖键。

<a id="member-gfconfigtableeditortools-constants-metadata_property_type_key"></a>

### `METADATA_PROPERTY_TYPE_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_PROPERTY_TYPE_KEY: StringName = &"property_type"
```

列 metadata 中的 Godot 属性类型覆盖键。

<a id="member-gfconfigtableeditortools-constants-metadata_property_hint_key"></a>

### `METADATA_PROPERTY_HINT_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_PROPERTY_HINT_KEY: StringName = &"property_hint"
```

列 metadata 中的 Godot PropertyHint 覆盖键。

<a id="member-gfconfigtableeditortools-constants-metadata_property_hint_string_key"></a>

### `METADATA_PROPERTY_HINT_STRING_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_PROPERTY_HINT_STRING_KEY: StringName = &"property_hint_string"
```

列 metadata 中的 Godot PropertyHint 字符串覆盖键。

<a id="member-gfconfigtableeditortools-constants-metadata_resource_type_key"></a>

### `METADATA_RESOURCE_TYPE_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_RESOURCE_TYPE_KEY: StringName = &"resource_type"
```

列 metadata 中的资源类型提示键。

<a id="member-gfconfigtableeditortools-constants-metadata_resource_extensions_key"></a>

### `METADATA_RESOURCE_EXTENSIONS_KEY`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const METADATA_RESOURCE_EXTENSIONS_KEY: StringName = &"resource_extensions"
```

列 metadata 中的资源扩展名提示键。

## 方法

<a id="member-gfconfigtableeditortools-methods-build_column_descriptors"></a>

### `build_column_descriptors`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func build_column_descriptors( schema: GFConfigTableSchema, options: Dictionary = {} ) -> Array[Dictionary]:
```

根据配置表 schema 构建通用列描述。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 配置表 schema。 |
| `options` | 描述选项，支持 editable_by_default 和 include_references。 |

返回：列描述列表。

结构：

- `options`: Dictionary，可包含 editable_by_default 和 include_references 布尔值。
- `return`: Array[Dictionary]，每项包含 field_name、label、value_type、required、allow_null、default_value、editable、choices、reference_ids、hint 和 metadata。

<a id="member-gfconfigtableeditortools-methods-build_field_editor_descriptors"></a>

### `build_field_editor_descriptors`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func build_field_editor_descriptors( schema: GFConfigTableSchema, database: GFConfigDatabaseResource = null, options: Dictionary = {} ) -> Array[Dictionary]:
```

根据配置表 schema 构建通用字段编辑描述。

参数：

| 名称 | 说明 |
|---|---|
| `schema` | 配置表 schema。 |
| `database` | 可选配置数据库；提供后可为跨表引用字段附带候选记录。 |
| `options` | 描述选项，支持 editable_by_default、include_references、include_reference_choices、label_fields 和 include_record。 |

返回：字段编辑描述列表。

结构：

- `options`: Dictionary，可包含 editable_by_default、include_references、include_reference_choices、label_fields 和 include_record。
- `return`: Array[Dictionary]，每项包含列描述字段，并额外包含 editor_kind、value_type_name、property_type、property_hint、property_hint_string、property_info、constraints、validation_rules 和 references。

<a id="member-gfconfigtableeditortools-methods-build_reference_choice_records"></a>

### `build_reference_choice_records`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func build_reference_choice_records( reference_definition: GFConfigTableReference, target_table: Variant, target_schema: GFConfigTableSchema = null, options: Dictionary = {} ) -> Array[Dictionary]:
```

根据跨表引用和目标表数据构建通用候选记录。

参数：

| 名称 | 说明 |
|---|---|
| `reference_definition` | 跨表引用声明。 |
| `target_table` | 目标表数据，可为 GFConfigTableResource、Array[Dictionary] 或 Dictionary 形式表。 |
| `target_schema` | 可选目标 schema；为空且 target_table 为 GFConfigTableResource 时使用其 schema。 |
| `options` | 候选记录选项，支持 label_fields 和 include_record。 |

返回：候选记录列表。

结构：

- `target_table`: Variant，支持 GFConfigTableResource、Array[Dictionary] 或键到记录 Dictionary 的 Dictionary。
- `options`: Dictionary，可包含 label_fields 与 include_record。
- `return`: Array[Dictionary]，每项包含 key、label、value、record_id、target_fields，并可按 include_record 包含 record。

<a id="member-gfconfigtableeditortools-methods-build_reference_choice_records_for_database"></a>

### `build_reference_choice_records_for_database`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func build_reference_choice_records_for_database( database: GFConfigDatabaseResource, reference_definition: GFConfigTableReference, options: Dictionary = {} ) -> Array[Dictionary]:
```

根据数据库资源中的目标表构建跨表引用候选记录。

参数：

| 名称 | 说明 |
|---|---|
| `database` | 配置数据库资源。 |
| `reference_definition` | 跨表引用声明。 |
| `options` | 候选记录选项，支持 label_fields 和 include_record。 |

返回：候选记录列表。

结构：

- `options`: Dictionary，可包含 label_fields 与 include_record。
- `return`: Array[Dictionary]，每项包含 key、label、value、record_id、target_fields，并可按 include_record 包含 record。
