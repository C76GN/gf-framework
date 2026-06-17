# GFEditorToolOption

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_editor_tool_option.gd`
- 模块：`Kernel`
- 继承：`Resource`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

编辑器工具选项声明。 用通用字段描述工具面板需要的一个选项，不绑定具体 UI 控件或资源类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfeditortooloption-enums-valuetype) | `enum ValueType` |
| 属性 | [`option_id`](#member-gfeditortooloption-properties-option_id) | `var option_id: StringName = &""` |
| 属性 | [`label`](#member-gfeditortooloption-properties-label) | `var label: String = ""` |
| 属性 | [`tooltip`](#member-gfeditortooloption-properties-tooltip) | `var tooltip: String = ""` |
| 属性 | [`value_type`](#member-gfeditortooloption-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`default_value`](#member-gfeditortooloption-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`min_value`](#member-gfeditortooloption-properties-min_value) | `var min_value: float = 0.0` |
| 属性 | [`max_value`](#member-gfeditortooloption-properties-max_value) | `var max_value: float = 1.0` |
| 属性 | [`step`](#member-gfeditortooloption-properties-step) | `var step: float = 0.01` |
| 属性 | [`choices`](#member-gfeditortooloption-properties-choices) | `var choices: Array = []` |
| 属性 | [`metadata`](#member-gfeditortooloption-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_option_id`](#member-gfeditortooloption-methods-get_option_id) | `func get_option_id() -> StringName:` |
| 方法 | [`is_valid_definition`](#member-gfeditortooloption-methods-is_valid_definition) | `func is_valid_definition() -> bool:` |
| 方法 | [`normalize_value`](#member-gfeditortooloption-methods-normalize_value) | `func normalize_value(value: Variant) -> Variant:` |
| 方法 | [`is_value_valid`](#member-gfeditortooloption-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`duplicate_option`](#member-gfeditortooloption-methods-duplicate_option) | `func duplicate_option() -> GFEditorToolOption:` |
| 方法 | [`describe`](#member-gfeditortooloption-methods-describe) | `func describe() -> Dictionary:` |

## 枚举

<a id="member-gfeditortooloption-enums-valuetype"></a>

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
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName。
	STRING_NAME,
	## Color。
	COLOR,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## NodePath。
	NODE_PATH,
	## 从 choices 中选择。
	OPTION,
}
```

编辑器工具选项的通用值类型。

## 属性

<a id="member-gfeditortooloption-properties-option_id"></a>

### `option_id`

- API：`public`

```gdscript
var option_id: StringName = &""
```

选项稳定标识。

<a id="member-gfeditortooloption-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

选项显示名称。

<a id="member-gfeditortooloption-properties-tooltip"></a>

### `tooltip`

- API：`public`

```gdscript
var tooltip: String = ""
```

选项提示文本。

<a id="member-gfeditortooloption-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.ANY
```

选项值类型。

<a id="member-gfeditortooloption-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

默认值。

结构：

- `default_value`: Variant default value duplicated when needed.

<a id="member-gfeditortooloption-properties-min_value"></a>

### `min_value`

- API：`public`

```gdscript
var min_value: float = 0.0
```

数值最小值。

<a id="member-gfeditortooloption-properties-max_value"></a>

### `max_value`

- API：`public`

```gdscript
var max_value: float = 1.0
```

数值最大值。

<a id="member-gfeditortooloption-properties-step"></a>

### `step`

- API：`public`

```gdscript
var step: float = 0.01
```

数值步长。

<a id="member-gfeditortooloption-properties-choices"></a>

### `choices`

- API：`public`

```gdscript
var choices: Array = []
```

可选项列表。`value_type` 为 OPTION 时用于校验。

结构：

- `choices`: Array of allowed values for OPTION value_type.

<a id="member-gfeditortooloption-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供工具 UI、持久化或项目层扩展使用。

结构：

- `metadata`: Dictionary for caller-defined option metadata.

## 方法

<a id="member-gfeditortooloption-methods-get_option_id"></a>

### `get_option_id`

- API：`public`

```gdscript
func get_option_id() -> StringName:
```

获取稳定选项标识。

返回：选项标识。

<a id="member-gfeditortooloption-methods-is_valid_definition"></a>

### `is_valid_definition`

- API：`public`

```gdscript
func is_valid_definition() -> bool:
```

检查选项声明是否有效。

返回：有效返回 true。

<a id="member-gfeditortooloption-methods-normalize_value"></a>

### `normalize_value`

- API：`public`

```gdscript
func normalize_value(value: Variant) -> Variant:
```

规范化输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：规范化后的值。

结构：

- `value`: Variant raw option value.
- `return`: Variant normalized option value.

<a id="member-gfeditortooloption-methods-is_value_valid"></a>

### `is_value_valid`

- API：`public`

```gdscript
func is_value_valid(value: Variant) -> bool:
```

检查值是否符合选项声明。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查值。 |

返回：符合声明时返回 true。

结构：

- `value`: Variant option value to validate.

<a id="member-gfeditortooloption-methods-duplicate_option"></a>

### `duplicate_option`

- API：`public`

```gdscript
func duplicate_option() -> GFEditorToolOption:
```

创建同内容拷贝。

返回：新选项声明。

<a id="member-gfeditortooloption-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出选项声明摘要。

返回：选项声明字典。

结构：

- `return`: Dictionary containing option_id, label, tooltip, value_type, default_value, numeric constraints, choices, and metadata.
