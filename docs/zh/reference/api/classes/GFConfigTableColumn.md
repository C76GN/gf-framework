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
| 属性 | [`type_definition`](#member-gfconfigtablecolumn-properties-type_definition) | `var type_definition: GFConfigTypeDefinition = null` |
| 属性 | [`required`](#member-gfconfigtablecolumn-properties-required) | `var required: bool = false` |
| 属性 | [`allow_null`](#member-gfconfigtablecolumn-properties-allow_null) | `var allow_null: bool = true` |
| 属性 | [`default_value`](#member-gfconfigtablecolumn-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`validation_rules`](#member-gfconfigtablecolumn-properties-validation_rules) | `var validation_rules: Array[GFConfigValidationRule] = []` |
| 属性 | [`element_validation_rules`](#member-gfconfigtablecolumn-properties-element_validation_rules) | `var element_validation_rules: Array[GFConfigValidationRule] = []` |
| 属性 | [`metadata`](#member-gfconfigtablecolumn-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_field_key`](#member-gfconfigtablecolumn-methods-get_field_key) | `func get_field_key() -> StringName:` |
| 方法 | [`coerce_value`](#member-gfconfigtablecolumn-methods-coerce_value) | `func coerce_value(value: Variant) -> Variant:` |
| 方法 | [`try_coerce_value`](#member-gfconfigtablecolumn-methods-try_coerce_value) | `func try_coerce_value(value: Variant, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`is_value_valid`](#member-gfconfigtablecolumn-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`duplicate_column`](#member-gfconfigtablecolumn-methods-duplicate_column) | `func duplicate_column(options: Dictionary = {}) -> GFConfigTableColumn:` |
| 方法 | [`describe`](#member-gfconfigtablecolumn-methods-describe) | `func describe(options: Dictionary = {}) -> Dictionary:` |

## 枚举

<a id="member-gfconfigtablecolumn-enums-valuetype"></a>

### `ValueType`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum ValueType {
	## 不做类型约束。
	ANY,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
}
```

导表字段值类型，用于导入与运行时校验。

## 属性

<a id="member-gfconfigtablecolumn-properties-field_name"></a>

### `field_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var field_name: StringName = &""
```

字段名。建议和导表列名保持一致。

<a id="member-gfconfigtablecolumn-properties-value_type"></a>

### `value_type`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var value_type: ValueType = ValueType.ANY
```

字段值类型。

<a id="member-gfconfigtablecolumn-properties-type_definition"></a>

### `type_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var type_definition: GFConfigTypeDefinition = null
```

可选结构化类型；设置后由该定义决定值形状，value_type 只保留旧资源字段兼容。 字段的 required、allow_null、default_value 及整值规则继续生效。

<a id="member-gfconfigtablecolumn-properties-required"></a>

### `required`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var required: bool = false
```

是否必须出现在记录中。

<a id="member-gfconfigtablecolumn-properties-allow_null"></a>

### `allow_null`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var allow_null: bool = true
```

是否允许 null 值。

<a id="member-gfconfigtablecolumn-properties-default_value"></a>

### `default_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_value: Variant = null
```

字段缺省值。`GFConfigTableSchema.coerce_record()` 会在缺字段时使用。

结构：

- `default_value`: Variant，字段缺失时复制到记录中的默认值。

<a id="member-gfconfigtablecolumn-properties-validation_rules"></a>

### `validation_rules`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var validation_rules: Array[GFConfigValidationRule] = []
```

字段级校验规则。只作用于当前字段值，不绑定具体业务枚举。

结构：

- `validation_rules`: Array，包含作用于当前字段的 GFConfigValidationRule 资源。

<a id="member-gfconfigtablecolumn-properties-element_validation_rules"></a>

### `element_validation_rules`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var element_validation_rules: Array[GFConfigValidationRule] = []
```

一维 Array 的逐元素值规则；仅可用于 ValueType.ARRAY，不改变 validation_rules 的整值语义。 缺失字段及容器 null 沿用 required/allow_null；元素 null 交由各规则的 allow_null 判断。 只执行启用规则，不转换元素类型，不接受嵌套集合、Object、Callable、Signal 或 RID 元素。 空列表或全部停用时不遍历元素；最多声明 64 条规则。

结构：

- `element_validation_rules`: Array[GFConfigValidationRule]，按原数组下标和声明顺序执行的规则资源；问题保留 field 并附加零基 element_index。

<a id="member-gfconfigtablecolumn-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

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
- 首次版本：`3.17.0`

```gdscript
func get_field_key() -> StringName:
```

获取稳定字段键。

返回：字段名。

<a id="member-gfconfigtablecolumn-methods-coerce_value"></a>

### `coerce_value`

- API：`public`
- 首次版本：`3.17.0`

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
- 首次版本：`3.17.0`

```gdscript
func try_coerce_value(value: Variant, options: Dictionary = {}) -> Dictionary:
```

尝试将输入值转换为当前列要求的类型，并返回转换报告。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |
| `options` | 结构化类型的调用期预算；旧标量转换忽略此选项。 |

返回：包含 ok、value 与 message 的转换报告；结构化失败时 value 为 null。

结构：

- `value`: Variant，按 value_type 尝试转换的输入字段值。
- `options`: Dictionary，可包含 work_budget 或 work_limits，以及来源字段路径。
- `return`: Dictionary，包含 ok、value 和 message 字段。

<a id="member-gfconfigtablecolumn-methods-is_value_valid"></a>

### `is_value_valid`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func is_value_valid(value: Variant) -> bool:
```

检查输入值是否符合当前列声明；结构类型先验证声明及默认值，再应用空值策略。

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
- 首次版本：`3.17.0`

```gdscript
func duplicate_column(options: Dictionary = {}) -> GFConfigTableColumn:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 调用期复制预算；不执行默认值或业务规则。 |

返回：新字段声明；循环类型图或复制预算失败时为 null，非循环的无效声明原样保留。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits。

<a id="member-gfconfigtablecolumn-methods-describe"></a>

### `describe`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func describe(options: Dictionary = {}) -> Dictionary:
```

有界导出结构化字段摘要，不执行默认值或业务规则。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 结构化描述的调用期预算。 |

返回：字段声明字典；结构化描述失败由 type_definition 报告保留，未复制的默认值及元数据为空。

结构：

- `options`: Dictionary，可包含 work_budget 或 work_limits。
- `return`: Dictionary，包含 field_name、value_type、type_definition、required、allow_null、default_value、validation_rules、element_validation_rules 和 metadata；type_definition 为 null 或保留 ok/issues/definition 的编译报告。
