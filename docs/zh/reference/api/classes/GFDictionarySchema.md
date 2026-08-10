# GFDictionarySchema

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/schema/gf_dictionary_schema.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.4.0`

通用 Dictionary 结构声明与校验器。 为任意 Dictionary 提供字段声明、默认值补齐、类型转换、嵌套结构校验和定义自检。 它只描述数据形态，不包含配置表索引、跨表引用、内容包启用策略或游戏业务规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`schema_id`](#member-gfdictionaryschema-properties-schema_id) | `var schema_id: StringName = &""` |
| 属性 | [`fields`](#member-gfdictionaryschema-properties-fields) | `var fields: Array[GFSchemaField] = []` |
| 属性 | [`allow_extra_fields`](#member-gfdictionaryschema-properties-allow_extra_fields) | `var allow_extra_fields: bool = true` |
| 属性 | [`coerce_values`](#member-gfdictionaryschema-properties-coerce_values) | `var coerce_values: bool = false` |
| 属性 | [`fail_on_coerce_error`](#member-gfdictionaryschema-properties-fail_on_coerce_error) | `var fail_on_coerce_error: bool = true` |
| 属性 | [`metadata`](#member-gfdictionaryschema-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfdictionaryschema-methods-configure) | `func configure( p_schema_id: StringName, p_fields: Array[GFSchemaField] = [], options: Dictionary = {} ) -> GFDictionarySchema:` |
| 方法 | [`add_field`](#member-gfdictionaryschema-methods-add_field) | `func add_field(field: GFSchemaField) -> bool:` |
| 方法 | [`get_field`](#member-gfdictionaryschema-methods-get_field) | `func get_field(field_name: StringName) -> GFSchemaField:` |
| 方法 | [`has_field`](#member-gfdictionaryschema-methods-has_field) | `func has_field(field_name: StringName) -> bool:` |
| 方法 | [`get_field_names`](#member-gfdictionaryschema-methods-get_field_names) | `func get_field_names() -> PackedStringArray:` |
| 方法 | [`build_defaults`](#member-gfdictionaryschema-methods-build_defaults) | `func build_defaults(include_optional: bool = true) -> Dictionary:` |
| 方法 | [`apply_defaults`](#member-gfdictionaryschema-methods-apply_defaults) | `func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:` |
| 方法 | [`coerce_dictionary`](#member-gfdictionaryschema-methods-coerce_dictionary) | `func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:` |
| 方法 | [`validate_definition`](#member-gfdictionaryschema-methods-validate_definition) | `func validate_definition(options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`validate_dictionary`](#member-gfdictionaryschema-methods-validate_dictionary) | `func validate_dictionary(values: Dictionary, options: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`normalize_dictionary_array`](#member-gfdictionaryschema-methods-normalize_dictionary_array) | `func normalize_dictionary_array(values: Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`duplicate_schema`](#member-gfdictionaryschema-methods-duplicate_schema) | `func duplicate_schema() -> GFDictionarySchema:` |
| 方法 | [`describe`](#member-gfdictionaryschema-methods-describe) | `func describe() -> Dictionary:` |

## 属性

<a id="member-gfdictionaryschema-properties-schema_id"></a>

### `schema_id`

- API：`public`

```gdscript
var schema_id: StringName = &""
```

Schema 标识。为空时可由调用方自行决定报告主题。

<a id="member-gfdictionaryschema-properties-fields"></a>

### `fields`

- API：`public`

```gdscript
var fields: Array[GFSchemaField] = []
```

字段声明列表。

结构：

- `fields`: Array[GFSchemaField] declared Dictionary fields.

<a id="member-gfdictionaryschema-properties-allow_extra_fields"></a>

### `allow_extra_fields`

- API：`public`

```gdscript
var allow_extra_fields: bool = true
```

是否允许包含 schema 未声明的字段。

<a id="member-gfdictionaryschema-properties-coerce_values"></a>

### `coerce_values`

- API：`public`

```gdscript
var coerce_values: bool = false
```

是否在校验前按字段声明尝试类型转换。

<a id="member-gfdictionaryschema-properties-fail_on_coerce_error"></a>

### `fail_on_coerce_error`

- API：`public`

```gdscript
var fail_on_coerce_error: bool = true
```

启用 coerce_values 时，转换失败是否作为校验错误。

<a id="member-gfdictionaryschema-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。GF 不解释其中业务字段。

结构：

- `metadata`: Dictionary caller-defined schema metadata.

## 方法

<a id="member-gfdictionaryschema-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_schema_id: StringName, p_fields: Array[GFSchemaField] = [], options: Dictionary = {} ) -> GFDictionarySchema:
```

配置 schema。

参数：

| 名称 | 说明 |
|---|---|
| `p_schema_id` | Schema 标识。 |
| `p_fields` | 字段声明列表。 |
| `options` | 可选配置，支持 allow_extra_fields、coerce_values、fail_on_coerce_error 和 metadata。 |

返回：当前 schema。

结构：

- `p_fields`: Array[GFSchemaField] declared Dictionary fields.
- `options`: Dictionary schema options.

<a id="member-gfdictionaryschema-methods-add_field"></a>

### `add_field`

- API：`public`

```gdscript
func add_field(field: GFSchemaField) -> bool:
```

添加字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `field` | 字段声明。 |

返回：添加成功返回 true。

<a id="member-gfdictionaryschema-methods-get_field"></a>

### `get_field`

- API：`public`

```gdscript
func get_field(field_name: StringName) -> GFSchemaField:
```

获取字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：找到时返回字段声明，否则返回 null。

<a id="member-gfdictionaryschema-methods-has_field"></a>

### `has_field`

- API：`public`

```gdscript
func has_field(field_name: StringName) -> bool:
```

检查字段声明是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `field_name` | 字段名。 |

返回：存在返回 true。

<a id="member-gfdictionaryschema-methods-get_field_names"></a>

### `get_field_names`

- API：`public`

```gdscript
func get_field_names() -> PackedStringArray:
```

获取当前 schema 的字段名列表。

返回：排序后的字段名。

<a id="member-gfdictionaryschema-methods-build_defaults"></a>

### `build_defaults`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func build_defaults(include_optional: bool = true) -> Dictionary:
```

创建默认 Dictionary。 只写入可表达的默认值：default_value 非 null，或字段允许 null。没有可用默认值的 non-nullable 字段保持缺失，不会被注入一个随后无法通过 schema 的 null。

参数：

| 名称 | 说明 |
|---|---|
| `include_optional` | 为 true 时包含非必填字段。 |

返回：默认数据字典。

结构：

- `return`: Dictionary default values.

<a id="member-gfdictionaryschema-methods-apply_defaults"></a>

### `apply_defaults`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:
```

为输入 Dictionary 补齐默认值。 只为缺失字段写入可表达的默认值；没有可用默认值的 non-nullable 字段保持缺失。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入字典。 |
| `include_optional` | 为 true 时补齐非必填字段。 |
| `should_coerce` | 为 true 时按字段声明转换已有值和默认值。 |

返回：补齐后的新字典。

结构：

- `values`: Dictionary source values.
- `return`: Dictionary normalized values.

<a id="member-gfdictionaryschema-methods-coerce_dictionary"></a>

### `coerce_dictionary`

- API：`public`

```gdscript
func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:
```

按字段声明转换 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入字典。 |
| `include_defaults` | 为 true 时同时补默认值。 |

返回：转换后的新字典。

结构：

- `values`: Dictionary source values.
- `return`: Dictionary coerced values.

<a id="member-gfdictionaryschema-methods-validate_definition"></a>

### `validate_definition`

- API：`public`

```gdscript
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
```

校验 schema 自身声明。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选上下文，支持 subject、source_path 和 source。 |

返回：校验报告。

结构：

- `options`: Dictionary validation context.

<a id="member-gfdictionaryschema-methods-validate_dictionary"></a>

### `validate_dictionary`

- API：`public`

```gdscript
func validate_dictionary(values: Dictionary, options: Dictionary = {}) -> GFValidationReport:
```

校验 Dictionary 数据。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入字典。 |
| `options` | 可选上下文，支持 subject、path、source_path 和 source。 |

返回：校验报告。

结构：

- `values`: Dictionary source values.
- `options`: Dictionary validation context.

<a id="member-gfdictionaryschema-methods-normalize_dictionary_array"></a>

### `normalize_dictionary_array`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func normalize_dictionary_array(values: Array, options: Dictionary = {}) -> Dictionary:
```

批量规范化 Dictionary 数组，并汇总行级校验报告。

参数：

| 名称 | 说明 |
|---|---|
| `values` | 输入数组。 |
| `options` | 可选配置，支持 include_optional、coerce、strip_extra_fields、validate_rows、keep_invalid_rows、path、subject、source_path 和 source。 |

返回：规范化结果字典。

结构：

- `values`: Array[Dictionary] source rows; non-Dictionary rows are reported as invalid_row.
- `options`: Dictionary normalization options.
- `return`: Dictionary with ok, rows, row_count, normalized_count, invalid_row_count, skipped_row_count, and report.

<a id="member-gfdictionaryschema-methods-duplicate_schema"></a>

### `duplicate_schema`

- API：`public`

```gdscript
func duplicate_schema() -> GFDictionarySchema:
```

创建同内容拷贝。

返回：新 schema。

<a id="member-gfdictionaryschema-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出 schema 摘要。

返回：schema 字典。

结构：

- `return`: Dictionary schema description.
