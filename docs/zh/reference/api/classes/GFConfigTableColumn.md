# GFConfigTableColumn

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/config/gf_config_table_column.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

导表字段声明。 只描述字段名、值类型、必填性、空值策略和默认值，不绑定任何具体业务表。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfconfigtablecolumn-enums-valuetype) | `enum ValueType` |
| 属性 | [`field_name`](#member-gfconfigtablecolumn-properties-field_name) | `var field_name: StringName = &""` |
| 属性 | [`value_type`](#member-gfconfigtablecolumn-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`required`](#member-gfconfigtablecolumn-properties-required) | `var required: bool = false` |
| 属性 | [`allow_null`](#member-gfconfigtablecolumn-properties-allow_null) | `var allow_null: bool = true` |
| 属性 | [`default_value`](#member-gfconfigtablecolumn-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`validation_rules`](#member-gfconfigtablecolumn-properties-validation_rules) | `var validation_rules: Array[GFConfigValidationRule] = []` |
| 属性 | [`metadata`](#member-gfconfigtablecolumn-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_field_key`](#member-gfconfigtablecolumn-methods-get_field_key) | `func get_field_key() -> StringName:` |
| 方法 | [`coerce_value`](#member-gfconfigtablecolumn-methods-coerce_value) | `func coerce_value(value: Variant) -> Variant:` |
| 方法 | [`try_coerce_value`](#member-gfconfigtablecolumn-methods-try_coerce_value) | `func try_coerce_value(value: Variant) -> Dictionary:` |
| 方法 | [`is_value_valid`](#member-gfconfigtablecolumn-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`duplicate_column`](#member-gfconfigtablecolumn-methods-duplicate_column) | `func duplicate_column() -> GFConfigTableColumn:` |
| 方法 | [`describe`](#member-gfconfigtablecolumn-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfconfigtablecolumn-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType { ## 不做类型约束。 ANY, ## 布尔值。 BOOL, ## 整数。 INT, ## 浮点数。 FLOAT, ## 字符串。 STRING, ## StringName。 STRING_NAME, ## Vector2。 VECTOR2, ## Vector2i。 VECTOR2I, ## Color。 COLOR, ## Dictionary。 DICTIONARY, ## Array。 ARRAY, }
```

导表字段值类型，用于导入与运行时校验。

## 属性

<a id="member-gfconfigtablecolumn-properties-field_name"></a>

### `field_name`

- API：`public`

```gdscript
var field_name: StringName = &""
```

字段名。建议和导表列名保持一致。

<a id="member-gfconfigtablecolumn-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.ANY
```

字段值类型。

<a id="member-gfconfigtablecolumn-properties-required"></a>

### `required`

- API：`public`

```gdscript
var required: bool = false
```

是否必须出现在记录中。

<a id="member-gfconfigtablecolumn-properties-allow_null"></a>

### `allow_null`

- API：`public`

```gdscript
var allow_null: bool = true
```

是否允许 null 值。

<a id="member-gfconfigtablecolumn-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

字段缺省值。`GFConfigTableSchema.coerce_record()` 会在缺字段时使用。

结构：

- `default_value`: Variant，字段缺失时复制到记录中的默认值。

<a id="member-gfconfigtablecolumn-properties-validation_rules"></a>

### `validation_rules`

- API：`public`

```gdscript
var validation_rules: Array[GFConfigValidationRule] = []
```

字段级校验规则。只作用于当前字段值，不绑定具体业务枚举。

结构：

- `validation_rules`: Array，包含作用于当前字段的 GFConfigValidationRule 资源。

<a id="member-gfconfigtablecolumn-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供编辑器、导入器或项目层扩展使用。

结构：

- `metadata`: Dictionary，保存编辑器、导入器或项目层附加到当前字段的元数据。

## 方法

<a id="member-gfconfigtablecolumn-methods-get_field_key"></a>

### `get_field_key`

- API：`public`

```gdscript
func get_field_key() -> StringName:
```

获取稳定字段键。

返回：字段名。

<a id="member-gfconfigtablecolumn-methods-coerce_value"></a>

### `coerce_value`

- API：`public`

```gdscript
func coerce_value(value: Variant) -> Variant:
```

将输入值转换为当前列要求的类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：转换后的值。

结构：

- `value`: Variant，按 value_type 转换的输入字段值。
- `return`: Variant，按当前 value_type 转换后的值。

<a id="member-gfconfigtablecolumn-methods-try_coerce_value"></a>

### `try_coerce_value`

- API：`public`

```gdscript
func try_coerce_value(value: Variant) -> Dictionary:
```

尝试将输入值转换为当前列要求的类型，并返回转换报告。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：包含 ok、value 与 message 的转换报告。

结构：

- `value`: Variant，按 value_type 尝试转换的输入字段值。
- `return`: Dictionary，包含 ok、value 和 message 字段。

<a id="member-gfconfigtablecolumn-methods-is_value_valid"></a>

### `is_value_valid`

- API：`public`

```gdscript
func is_value_valid(value: Variant) -> bool:
```

检查输入值是否符合当前列声明。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查值。 |

返回：符合声明时返回 true。

结构：

- `value`: Variant，按 value_type 与 allow_null 检查的字段值。

<a id="member-gfconfigtablecolumn-methods-duplicate_column"></a>

### `duplicate_column`

- API：`public`

```gdscript
func duplicate_column() -> GFConfigTableColumn:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新字段声明。

<a id="member-gfconfigtablecolumn-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出字段声明摘要。

返回：字段声明字典。

结构：

- `return`: Dictionary，包含 field_name、value_type、required、allow_null、default_value、validation_rules 和 metadata。
