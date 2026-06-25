# GFSchemaField

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/schema/gf_schema_field.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`4.4.0`

通用数据字段声明。 描述一个 Dictionary 字段或数组元素的类型、必填性、空值策略、默认值和可选嵌套 schema。 它只表达结构契约，不绑定配置表、黑板、内容包或具体业务字段语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfschemafield-enums-valuetype) | `enum ValueType` |
| 属性 | [`field_name`](#member-gfschemafield-properties-field_name) | `var field_name: StringName = &""` |
| 属性 | [`value_type`](#member-gfschemafield-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`required`](#member-gfschemafield-properties-required) | `var required: bool = false` |
| 属性 | [`allow_null`](#member-gfschemafield-properties-allow_null) | `var allow_null: bool = true` |
| 属性 | [`default_value`](#member-gfschemafield-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`dictionary_schema`](#member-gfschemafield-properties-dictionary_schema) | `var dictionary_schema: GFDictionarySchema = null` |
| 属性 | [`array_item_schema`](#member-gfschemafield-properties-array_item_schema) | `var array_item_schema: GFSchemaField = null` |
| 属性 | [`metadata`](#member-gfschemafield-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`validation_rules`](#member-gfschemafield-properties-validation_rules) | `var validation_rules: Array[GFValidationRule] = []` |
| 方法 | [`configure`](#member-gfschemafield-methods-configure) | `func configure( p_field_name: StringName, p_value_type: ValueType = ValueType.ANY, options: Dictionary = {} ) -> GFSchemaField:` |
| 方法 | [`get_field_key`](#member-gfschemafield-methods-get_field_key) | `func get_field_key() -> StringName:` |
| 方法 | [`is_value_valid`](#member-gfschemafield-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`coerce_value`](#member-gfschemafield-methods-coerce_value) | `func coerce_value(value: Variant) -> Variant:` |
| 方法 | [`try_coerce_value`](#member-gfschemafield-methods-try_coerce_value) | `func try_coerce_value(value: Variant) -> Dictionary:` |
| 方法 | [`validate_value`](#member-gfschemafield-methods-validate_value) | `func validate_value(value: Variant, context: Dictionary = {}) -> GFValidationReport:` |
| 方法 | [`add_validation_rule`](#member-gfschemafield-methods-add_validation_rule) | `func add_validation_rule(rule: GFValidationRule) -> bool:` |
| 方法 | [`get_enabled_validation_rules`](#member-gfschemafield-methods-get_enabled_validation_rules) | `func get_enabled_validation_rules() -> Array[GFValidationRule]:` |
| 方法 | [`duplicate_field`](#member-gfschemafield-methods-duplicate_field) | `func duplicate_field() -> GFSchemaField:` |
| 方法 | [`describe`](#member-gfschemafield-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`value_type_to_name`](#member-gfschemafield-methods-value_type_to_name) | `static func value_type_to_name(type_id: ValueType) -> String:` |

## 枚举

<a id="member-gfschemafield-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType {
	## 不做类型约束。
	ANY,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数；int 也视为有效。
	FLOAT,
	## String。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## Vector3。
	VECTOR3,
	## Vector3i。
	VECTOR3I,
	## Color。
	COLOR,
	## Dictionary，可选嵌套 GFDictionarySchema。
	DICTIONARY,
	## Array，可选数组元素 GFSchemaField。
	ARRAY,
	## Object。
	OBJECT,
	## Resource。
	RESOURCE,
	## NodePath。
	NODE_PATH,
}
```

字段值类型。

## 属性

<a id="member-gfschemafield-properties-field_name"></a>

### `field_name`

- API：`public`

```gdscript
var field_name: StringName = &""
```

字段名。作为数组元素 schema 使用时可为空。

<a id="member-gfschemafield-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.ANY
```

字段值类型。

<a id="member-gfschemafield-properties-required"></a>

### `required`

- API：`public`

```gdscript
var required: bool = false
```

是否必须出现在所属 Dictionary 中。

<a id="member-gfschemafield-properties-allow_null"></a>

### `allow_null`

- API：`public`

```gdscript
var allow_null: bool = true
```

是否允许 null 值。

<a id="member-gfschemafield-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

默认值。`GFDictionarySchema.apply_defaults()` 会在缺字段时使用。

结构：

- `default_value`: Variant default field value.

<a id="member-gfschemafield-properties-dictionary_schema"></a>

### `dictionary_schema`

- API：`public`

```gdscript
var dictionary_schema: GFDictionarySchema = null
```

字典类型字段的嵌套 schema。

<a id="member-gfschemafield-properties-array_item_schema"></a>

### `array_item_schema`

- API：`public`

```gdscript
var array_item_schema: GFSchemaField = null
```

数组类型字段的元素 schema。

<a id="member-gfschemafield-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。GF 不解释其中业务字段。

结构：

- `metadata`: Dictionary caller-defined schema metadata.

<a id="member-gfschemafield-properties-validation_rules"></a>

### `validation_rules`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var validation_rules: Array[GFValidationRule] = []
```

字段级附加校验规则。 规则在基础类型、空值和嵌套 schema 校验通过后执行，用于表达范围、集合、 格式或项目自定义约束，而不把这些策略硬编码进字段类型。

结构：

- `validation_rules`: Array[GFValidationRule] field-level validation rules.

## 方法

<a id="member-gfschemafield-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_field_name: StringName, p_value_type: ValueType = ValueType.ANY, options: Dictionary = {} ) -> GFSchemaField:
```

配置字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `p_field_name` | 字段名。 |
| `p_value_type` | 字段值类型。 |
| `options` | 可选配置，支持 required、allow_null、default_value、dictionary_schema、array_item_schema 和 metadata。 |

返回：当前字段。

结构：

- `options`: Dictionary schema field options.

<a id="member-gfschemafield-methods-get_field_key"></a>

### `get_field_key`

- API：`public`

```gdscript
func get_field_key() -> StringName:
```

获取稳定字段键。

返回：字段名。

<a id="member-gfschemafield-methods-is_value_valid"></a>

### `is_value_valid`

- API：`public`

```gdscript
func is_value_valid(value: Variant) -> bool:
```

检查输入值是否符合字段声明。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查值。 |

返回：符合声明时返回 true。

结构：

- `value`: Variant value to validate.

<a id="member-gfschemafield-methods-coerce_value"></a>

### `coerce_value`

- API：`public`

```gdscript
func coerce_value(value: Variant) -> Variant:
```

将输入值转换为字段要求的类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：转换后的值。

结构：

- `value`: Variant value to coerce.
- `return`: Variant coerced value.

<a id="member-gfschemafield-methods-try_coerce_value"></a>

### `try_coerce_value`

- API：`public`

```gdscript
func try_coerce_value(value: Variant) -> Dictionary:
```

尝试转换输入值并返回转换报告。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：包含 ok、value、message 的转换报告。

结构：

- `value`: Variant value to coerce.
- `return`: Dictionary with ok, value, and message.

<a id="member-gfschemafield-methods-validate_value"></a>

### `validate_value`

- API：`public`

```gdscript
func validate_value(value: Variant, context: Dictionary = {}) -> GFValidationReport:
```

校验字段值并返回报告。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待校验值。 |
| `context` | 可选上下文，支持 subject、path、key 和 schema_id。 |

返回：校验报告。

结构：

- `value`: Variant value to validate.
- `context`: Dictionary validation context.

<a id="member-gfschemafield-methods-add_validation_rule"></a>

### `add_validation_rule`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_validation_rule(rule: GFValidationRule) -> bool:
```

添加字段级校验规则。

参数：

| 名称 | 说明 |
|---|---|
| `rule` | 校验规则。 |

返回：添加成功返回 true。

<a id="member-gfschemafield-methods-get_enabled_validation_rules"></a>

### `get_enabled_validation_rules`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_enabled_validation_rules() -> Array[GFValidationRule]:
```

获取启用的字段级校验规则。

返回：规则数组副本。

<a id="member-gfschemafield-methods-duplicate_field"></a>

### `duplicate_field`

- API：`public`

```gdscript
func duplicate_field() -> GFSchemaField:
```

创建同内容拷贝。

返回：新字段声明。

<a id="member-gfschemafield-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出字段声明摘要。

返回：字段声明字典。

结构：

- `return`: Dictionary schema field description.

<a id="member-gfschemafield-methods-value_type_to_name"></a>

### `value_type_to_name`

- API：`public`

```gdscript
static func value_type_to_name(type_id: ValueType) -> String:
```

将字段类型转换为稳定名称。

参数：

| 名称 | 说明 |
|---|---|
| `type_id` | 字段类型。 |

返回：类型名称。
