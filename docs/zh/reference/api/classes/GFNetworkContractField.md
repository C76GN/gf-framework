# GFNetworkContractField

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/contracts/gf_network_contract_field.gd`
- 模块：`Network`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

网络契约中的单个 payload 字段。 字段只描述名称、值类型、必填性和默认值，用于生成器、校验器或项目工具， 不规定消息含义、权限或同步策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfnetworkcontractfield-enums-valuetype) | `enum ValueType` |
| 属性 | [`field_name`](#member-gfnetworkcontractfield-properties-field_name) | `var field_name: StringName = &""` |
| 属性 | [`display_name`](#member-gfnetworkcontractfield-properties-display_name) | `var display_name: String = ""` |
| 属性 | [`value_type`](#member-gfnetworkcontractfield-properties-value_type) | `var value_type: ValueType = ValueType.VARIANT` |
| 属性 | [`required`](#member-gfnetworkcontractfield-properties-required) | `var required: bool = true` |
| 属性 | [`allow_null`](#member-gfnetworkcontractfield-properties-allow_null) | `var allow_null: bool = false` |
| 属性 | [`default_value`](#member-gfnetworkcontractfield-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`class_name_hint`](#member-gfnetworkcontractfield-properties-class_name_hint) | `var class_name_hint: StringName = &""` |
| 属性 | [`metadata`](#member-gfnetworkcontractfield-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_field_name`](#member-gfnetworkcontractfield-methods-get_field_name) | `func get_field_name() -> StringName:` |
| 方法 | [`get_display_name`](#member-gfnetworkcontractfield-methods-get_display_name) | `func get_display_name() -> String:` |
| 方法 | [`get_default_value`](#member-gfnetworkcontractfield-methods-get_default_value) | `func get_default_value() -> Variant:` |
| 方法 | [`normalize_value`](#member-gfnetworkcontractfield-methods-normalize_value) | `func normalize_value(value: Variant) -> Variant:` |
| 方法 | [`validate_definition`](#member-gfnetworkcontractfield-methods-validate_definition) | `func validate_definition() -> Dictionary:` |
| 方法 | [`validate_value`](#member-gfnetworkcontractfield-methods-validate_value) | `func validate_value(value: Variant) -> Dictionary:` |
| 方法 | [`describe`](#member-gfnetworkcontractfield-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfnetworkcontractfield-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType {
	## 任意 Variant。
	VARIANT,
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
	## Vector3。
	VECTOR3,
	## Vector2i。
	VECTOR2I,
	## Vector3i。
	VECTOR3I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
	## NodePath。
	NODE_PATH,
	## Object 或 Resource。
	OBJECT,
}
```

字段值类型。

## 属性

<a id="member-gfnetworkcontractfield-properties-field_name"></a>

### `field_name`

- API：`public`

```gdscript
var field_name: StringName = &""
```

字段稳定名称。

<a id="member-gfnetworkcontractfield-properties-display_name"></a>

### `display_name`

- API：`public`

```gdscript
var display_name: String = ""
```

编辑器展示名称。

<a id="member-gfnetworkcontractfield-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.VARIANT
```

字段值类型。

<a id="member-gfnetworkcontractfield-properties-required"></a>

### `required`

- API：`public`

```gdscript
var required: bool = true
```

是否为必填字段。

<a id="member-gfnetworkcontractfield-properties-allow_null"></a>

### `allow_null`

- API：`public`

```gdscript
var allow_null: bool = false
```

是否允许显式 null 值。

<a id="member-gfnetworkcontractfield-properties-default_value"></a>

### `default_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var default_value: Variant = null
```

可选默认值。非 null 值必须精确匹配 value_type 并满足 transport-safe 边界；生成器会完整写入生成函数签名。

结构：

- `default_value`: Variant，字段默认值；非 null 时必须精确匹配 value_type，并且是可复制的 transport-safe 值。

<a id="member-gfnetworkcontractfield-properties-class_name_hint"></a>

### `class_name_hint`

- API：`public`

```gdscript
var class_name_hint: StringName = &""
```

Object / Resource 字段的类名提示，仅用于工具校验。

<a id="member-gfnetworkcontractfield-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，保存项目自定义字段元数据。

## 方法

<a id="member-gfnetworkcontractfield-methods-get_field_name"></a>

### `get_field_name`

- API：`public`

```gdscript
func get_field_name() -> StringName:
```

获取字段名称。

返回：字段名称。

<a id="member-gfnetworkcontractfield-methods-get_display_name"></a>

### `get_display_name`

- API：`public`

```gdscript
func get_display_name() -> String:
```

获取展示名称。

返回：展示名称。

<a id="member-gfnetworkcontractfield-methods-get_default_value"></a>

### `get_default_value`

- API：`public`

```gdscript
func get_default_value() -> Variant:
```

获取默认值副本。

返回：默认值。

结构：

- `return`: Variant，default_value 的深拷贝或原始标量值。

<a id="member-gfnetworkcontractfield-methods-normalize_value"></a>

### `normalize_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func normalize_value(value: Variant) -> Variant:
```

归一化字段值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：归一化后的值；allow_null 为 true 时显式 null 原样保留，否则可回落到非空默认值。

结构：

- `value`: Variant，待归一化字段值。
- `return`: Variant，字段默认值或输入值的安全副本。

<a id="member-gfnetworkcontractfield-methods-validate_definition"></a>

### `validate_definition`

- API：`public`

```gdscript
func validate_definition() -> Dictionary:
```

校验字段定义是否完整。

返回：校验报告字典。

结构：

- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractfield-methods-validate_value"></a>

### `validate_value`

- API：`public`

```gdscript
func validate_value(value: Variant) -> Dictionary:
```

校验字段值是否符合声明类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 字段值。 |

返回：校验报告字典。

结构：

- `value`: Variant，待校验字段值。
- `return`: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。

<a id="member-gfnetworkcontractfield-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

描述字段契约。

返回：描述字典。

结构：

- `return`: Dictionary，包含 field_name、display_name、value_type、required、allow_null、default_value、class_name_hint、metadata。
