# GFBlackboardEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/blackboard/gf_blackboard_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用黑板字段声明。 只描述字段键、类型、必填性、空值策略和默认值，不绑定行为树、AI 或具体玩法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfblackboardentry-enums-valuetype) | `enum ValueType` |
| 属性 | [`key`](#member-gfblackboardentry-properties-key) | `var key: StringName = &""` |
| 属性 | [`value_type`](#member-gfblackboardentry-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`required`](#member-gfblackboardentry-properties-required) | `var required: bool = false` |
| 属性 | [`allow_null`](#member-gfblackboardentry-properties-allow_null) | `var allow_null: bool = true` |
| 属性 | [`default_value`](#member-gfblackboardentry-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`metadata`](#member-gfblackboardentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_key`](#member-gfblackboardentry-methods-get_key) | `func get_key() -> StringName:` |
| 方法 | [`is_value_valid`](#member-gfblackboardentry-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`coerce_value`](#member-gfblackboardentry-methods-coerce_value) | `func coerce_value(value: Variant) -> Variant:` |
| 方法 | [`try_coerce_value`](#member-gfblackboardentry-methods-try_coerce_value) | `func try_coerce_value(value: Variant) -> Dictionary:` |
| 方法 | [`duplicate_entry`](#member-gfblackboardentry-methods-duplicate_entry) | `func duplicate_entry() -> GFBlackboardEntry:` |
| 方法 | [`describe`](#member-gfblackboardentry-methods-describe) | `func describe() -> Dictionary:` |
| 方法 | [`value_type_to_name`](#member-gfblackboardentry-methods-value_type_to_name) | `static func value_type_to_name(type_id: ValueType) -> String:` |

## 枚举

<a id="member-gfblackboardentry-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType { ## 不做类型约束。 ANY, ## 布尔值。 BOOL, ## 整数。 INT, ## 浮点数。 FLOAT, ## 字符串。 STRING, ## StringName。 STRING_NAME, ## Vector2。 VECTOR2, ## Vector2i。 VECTOR2I, ## Vector3。 VECTOR3, ## Vector3i。 VECTOR3I, ## Color。 COLOR, ## Dictionary。 DICTIONARY, ## Array。 ARRAY, ## Object。 OBJECT, }
```

黑板字段值类型。

## 属性

<a id="member-gfblackboardentry-properties-key"></a>

### `key`

- API：`public`

```gdscript
var key: StringName = &""
```

字段键。

<a id="member-gfblackboardentry-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.ANY
```

字段值类型。

<a id="member-gfblackboardentry-properties-required"></a>

### `required`

- API：`public`

```gdscript
var required: bool = false
```

是否必须出现在黑板数据中。

<a id="member-gfblackboardentry-properties-allow_null"></a>

### `allow_null`

- API：`public`

```gdscript
var allow_null: bool = true
```

是否允许 null 值。

<a id="member-gfblackboardentry-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

默认值。`GFBlackboardSchema.apply_defaults()` 会在缺字段时使用。

结构：

- `default_value`: Variant default blackboard value.

<a id="member-gfblackboardentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供编辑器、调试器或项目工具使用。

结构：

- `metadata`: Dictionary metadata for editor, debugger, or project tooling.

## 方法

<a id="member-gfblackboardentry-methods-get_key"></a>

### `get_key`

- API：`public`

```gdscript
func get_key() -> StringName:
```

获取稳定字段键。

返回：字段键。

<a id="member-gfblackboardentry-methods-is_value_valid"></a>

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

<a id="member-gfblackboardentry-methods-coerce_value"></a>

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

<a id="member-gfblackboardentry-methods-try_coerce_value"></a>

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

<a id="member-gfblackboardentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`

```gdscript
func duplicate_entry() -> GFBlackboardEntry:
```

创建同内容拷贝，避免运行时修改污染共享 Resource。

返回：新字段声明。

<a id="member-gfblackboardentry-methods-describe"></a>

### `describe`

- API：`public`

```gdscript
func describe() -> Dictionary:
```

导出字段声明摘要。

返回：字段声明字典。

结构：

- `return`: Dictionary entry description.

<a id="member-gfblackboardentry-methods-value_type_to_name"></a>

### `value_type_to_name`

- API：`public`

```gdscript
static func value_type_to_name(type_id: ValueType) -> String:
```

将字段类型转换为可读名称。

参数：

| 名称 | 说明 |
|---|---|
| `type_id` | 字段类型。 |

返回：类型名称。
