# GFConfigTableSchema

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_schema.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用导表结构声明与校验器。 用于在导入期或运行时校验表数据结构，保持数据工具链可替换且不绑定业务表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`table_name`](#member-gfconfigtableschema-properties-table_name) | `var table_name: StringName = &""` |
| 属性 | [`id_field`](#member-gfconfigtableschema-properties-id_field) | `var id_field: StringName = &"id"` |
| 属性 | [`columns`](#member-gfconfigtableschema-properties-columns) | `var columns: Array[GFConfigTableColumn] = []` |
| 属性 | [`allow_extra_fields`](#member-gfconfigtableschema-properties-allow_extra_fields) | `var allow_extra_fields: bool = true` |
| 属性 | [`coerce_values`](#member-gfconfigtableschema-properties-coerce_values) | `var coerce_values: bool = false` |
| 属性 | [`fail_on_coerce_error`](#member-gfconfigtableschema-properties-fail_on_coerce_error) | `var fail_on_coerce_error: bool = true` |
| 属性 | [`require_unique_id`](#member-gfconfigtableschema-properties-require_unique_id) | `var require_unique_id: bool = false` |
| 属性 | [`indexes`](#member-gfconfigtableschema-properties-indexes) | `var indexes: Array[GFConfigTableIndexDefinition] = []` |
| 属性 | [`references`](#member-gfconfigtableschema-properties-references) | `var references: Array[GFConfigTableReference] = []` |
| 属性 | [`record_validation_rules`](#member-gfconfigtableschema-properties-record_validation_rules) | `var record_validation_rules: Array[GFConfigValidationRule] = []` |
| 属性 | [`table_validation_rules`](#member-gfconfigtableschema-properties-table_validation_rules) | `var table_validation_rules: Array[GFConfigValidationRule] = []` |
| 属性 | [`metadata`](#member-gfconfigtableschema-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`infer_from_records`](#member-gfconfigtableschema-methods-infer_from_records) | `static func infer_from_records( inferred_table_name: StringName, table_data: Variant, options: Dictionary = {} ) -> GFConfigTableSchema:` |
| 方法 | [`get_table_key`](#member-gfconfigtableschema-methods-get_table_key) | `func get_table_key() -> StringName:` |
| 方法 | [`get_column`](#member-gfconfigtableschema-methods-get_column) | `func get_column(field_name: StringName) -> GFConfigTableColumn:` |
| 方法 | [`has_column`](#member-gfconfigtableschema-methods-has_column) | `func has_column(field_name: StringName) -> bool:` |
| 方法 | [`get_index`](#member-gfconfigtableschema-methods-get_index) | `func get_index(index_id: StringName) -> GFConfigTableIndexDefinition:` |
| 方法 | [`has_index`](#member-gfconfigtableschema-methods-has_index) | `func has_index(index_id: StringName) -> bool:` |
| 方法 | [`get_reference`](#member-gfconfigtableschema-methods-get_reference) | `func get_reference(reference_id: StringName) -> GFConfigTableReference:` |
| 方法 | [`has_reference`](#member-gfconfigtableschema-methods-has_reference) | `func has_reference(reference_id: StringName) -> bool:` |
| 方法 | [`get_column_names`](#member-gfconfigtableschema-methods-get_column_names) | `func get_column_names() -> PackedStringArray:` |
| 方法 | [`validate_definition`](#member-gfconfigtableschema-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_record`](#member-gfconfigtableschema-methods-validate_record) | `func validate_record(record: Dictionary, row_key: Variant = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`validate_table`](#member-gfconfigtableschema-methods-validate_table) | `func validate_table(table_data: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`coerce_record`](#member-gfconfigtableschema-methods-coerce_record) | `func coerce_record(record: Dictionary) -> Dictionary:` |
| 方法 | [`build_empty_record`](#member-gfconfigtableschema-methods-build_empty_record) | `func build_empty_record(include_optional: bool = true) -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfconfigtableschema-methods-duplicate_schema) | `func duplicate_schema() -> GFConfigTableSchema:` |
| 方法 | [`describe`](#member-gfconfigtableschema-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfconfigtableschema-properties-table_name"></a>

### `table_name`

- API：`public`

```gdscript
var table_name: StringName = &""
```

表名。为空时可由调用方自行决定表标识。

<a id="member-gfconfigtableschema-properties-id_field"></a>

### `id_field`

- API：`public`

```gdscript
var id_field: StringName = &"id"
```

记录 ID 字段。为空时不检查记录 ID。

<a id="member-gfconfigtableschema-properties-columns"></a>

### `columns`

- API：`public`

```gdscript
var columns: Array[GFConfigTableColumn] = []
```

字段声明列表。

结构：

- `columns`: Array[GFConfigTableColumn]，定义当前表允许的字段和字段级校验规则。

<a id="member-gfconfigtableschema-properties-allow_extra_fields"></a>

### `allow_extra_fields`

- API：`public`

```gdscript
var allow_extra_fields: bool = true
```

是否允许记录包含 schema 未声明的字段。

<a id="member-gfconfigtableschema-properties-coerce_values"></a>

### `coerce_values`

- API：`public`

```gdscript
var coerce_values: bool = false
```

是否在校验前按字段声明尝试类型转换。

<a id="member-gfconfigtableschema-properties-fail_on_coerce_error"></a>

### `fail_on_coerce_error`

- API：`public`

```gdscript
var fail_on_coerce_error: bool = true
```

启用 coerce_values 时，转换失败是否作为校验错误。

<a id="member-gfconfigtableschema-properties-require_unique_id"></a>

### `require_unique_id`

- API：`public`

```gdscript
var require_unique_id: bool = false
```

校验整表时是否要求 id_field 唯一。

<a id="member-gfconfigtableschema-properties-indexes"></a>

### `indexes`

- API：`public`

```gdscript
var indexes: Array[GFConfigTableIndexDefinition] = []
```

可选复合索引声明。唯一索引会参与表级校验。

结构：

- `indexes`: Array[GFConfigTableIndexDefinition]，定义当前表的复合索引和唯一性约束。

<a id="member-gfconfigtableschema-properties-references"></a>

### `references`

- API：`public`

```gdscript
var references: Array[GFConfigTableReference] = []
```

可选跨表引用声明。引用目标由 `GFConfigReferenceResolver` 在多表上下文中校验。

结构：

- `references`: Array[GFConfigTableReference]，定义当前表到其他表的引用关系。

<a id="member-gfconfigtableschema-properties-record_validation_rules"></a>

### `record_validation_rules`

- API：`public`

```gdscript
var record_validation_rules: Array[GFConfigValidationRule] = []
```

可选记录级校验规则。规则会在字段结构校验后作用于整条记录。

结构：

- `record_validation_rules`: Array[GFConfigValidationRule]，包含作用于单条记录的校验规则。

<a id="member-gfconfigtableschema-properties-table_validation_rules"></a>

### `table_validation_rules`

- API：`public`

```gdscript
var table_validation_rules: Array[GFConfigValidationRule] = []
```

可选表级校验规则。规则会在行结构、唯一 ID 和索引校验后作用于整表。

结构：

- `table_validation_rules`: Array[GFConfigValidationRule]，包含作用于整张表的校验规则。

<a id="member-gfconfigtableschema-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供导入器、编辑器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存导入器、编辑器或项目层附加到当前 schema 的元数据。

## 方法

<a id="member-gfconfigtableschema-methods-infer_from_records"></a>

### `infer_from_records`

- API：`public`

```gdscript
static func infer_from_records( inferred_table_name: StringName, table_data: Variant, options: Dictionary = {} ) -> GFConfigTableSchema:
```

从记录样本推导通用 schema。

参数：

| 名称 | 说明 |
|---|---|
| `inferred_table_name` | 推导出的表名。 |
| `table_data` | Array[Dictionary] 或 Dictionary 形式的表数据。 |
| `options` | 可选参数，支持 id_field、required_if_present_in_all_rows、allow_extra_fields、coerce_values。 |

返回：推导出的 schema；数据无效时返回空 schema。

结构：

- `table_data`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `options`: Dictionary，可包含 id_field、required_if_present_in_all_rows、allow_extra_fields 和 coerce_values。

<a id="member-gfconfigtableschema-methods-get_table_key"></a>

### `get_table_key`

- API：`public`

```gdscript
func get_table_key() -> StringName:
```

获取稳定表键。

返回：表名。

<a id="member-gfconfigtableschema-methods-get_column"></a>

### `get_column`

- API：`public`

```gdscript
func get_column(field_name: StringName) -> GFConfigTableColumn:
```

获取字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：找到时返回字段声明，否则返回 null。

<a id="member-gfconfigtableschema-methods-has_column"></a>

### `has_column`

- API：`public`

```gdscript
func has_column(field_name: StringName) -> bool:
```

检查字段声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：存在返回 true。

<a id="member-gfconfigtableschema-methods-get_index"></a>

### `get_index`

- API：`public`

```gdscript
func get_index(index_id: StringName) -> GFConfigTableIndexDefinition:
```

获取索引声明。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引标识。 |

返回：找到时返回索引声明，否则返回 null。

<a id="member-gfconfigtableschema-methods-has_index"></a>

### `has_index`

- API：`public`

```gdscript
func has_index(index_id: StringName) -> bool:
```

检查索引声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `index_id` | 索引标识。 |

返回：存在返回 true。

<a id="member-gfconfigtableschema-methods-get_reference"></a>

### `get_reference`

- API：`public`

```gdscript
func get_reference(reference_id: StringName) -> GFConfigTableReference:
```

获取引用声明。

参数：

| 名称 | 说明 |
|---|---|
| `reference_id` | 引用标识。 |

返回：找到时返回引用声明，否则返回 null。

<a id="member-gfconfigtableschema-methods-has_reference"></a>

### `has_reference`

- API：`public`

```gdscript
func has_reference(reference_id: StringName) -> bool:
```

检查引用声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `reference_id` | 引用标识。 |

返回：存在返回 true。

<a id="member-gfconfigtableschema-methods-get_column_names"></a>

### `get_column_names`

- API：`public`

```gdscript
func get_column_names() -> PackedStringArray:
```

获取当前 schema 的字段名列表。

返回：字段名列表。

<a id="member-gfconfigtableschema-methods-validate_definition"></a>

### `validate_definition`

- API：`public`

```gdscript
func validate_definition(options: Dictionary = {}) -> Dictionary:
```

校验 schema 自身声明是否完整、一致。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选上下文，支持 source。 |

返回：校验报告字典。

结构：

- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableschema-methods-validate_record"></a>

### `validate_record`

- API：`public`

```gdscript
func validate_record(record: Dictionary, row_key: Variant = null, options: Dictionary = {}) -> Dictionary:
```

校验单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 记录字典。 |
| `row_key` | 可选行标识，用于错误报告。 |
| `options` | 可选上下文，支持 source、line、row_index、row_locations。 |

返回：校验报告字典。

结构：

- `record`: Dictionary，待校验的配置记录，键为字段名，值为字段数据。
- `row_key`: Variant，写入校验报告 issue 的行标识。
- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableschema-methods-validate_table"></a>

### `validate_table`

- API：`public`

```gdscript
func validate_table(table_data: Variant, options: Dictionary = {}) -> Dictionary:
```

校验整张表。

参数：

| 名称 | 说明 |
|---|---|
| `table_data` | Array[Dictionary] 或 Dictionary 形式的表数据。 |
| `options` | 可选上下文，支持 source、row_locations。 |

返回：校验报告字典。

结构：

- `table_data`: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
- `options`: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
- `return`: GFConfigValidationReport 兼容 Dictionary。

<a id="member-gfconfigtableschema-methods-coerce_record"></a>

### `coerce_record`

- API：`public`

```gdscript
func coerce_record(record: Dictionary) -> Dictionary:
```

按字段声明转换单条记录。

参数：

| 名称 | 说明 |
|---|---|
| `record` | 输入记录。 |

返回：转换后的新记录。

结构：

- `record`: Dictionary，待转换的配置记录，键为字段名，值为字段数据。
- `return`: Dictionary，转换后的记录副本。

<a id="member-gfconfigtableschema-methods-build_empty_record"></a>

### `build_empty_record`

- API：`public`

```gdscript
func build_empty_record(include_optional: bool = true) -> Dictionary:
```

创建空记录模板。

参数：

| 名称 | 说明 |
|---|---|
| `include_optional` | 为 true 时包含非必填字段。 |

返回：新记录字典。

结构：

- `return`: Dictionary，键为字段名，值为字段默认值转换后的结果。

<a id="member-gfconfigtableschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`

```gdscript
func duplicate_schema() -> GFConfigTableSchema:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新 schema。

<a id="member-gfconfigtableschema-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出 schema 摘要。

返回：schema 字典。

结构：

- `return`: Dictionary，包含 table_name、id_field、columns、allow_extra_fields、coerce_values、fail_on_coerce_error、require_unique_id、indexes、references、record_validation_rules、table_validation_rules 和 metadata。
