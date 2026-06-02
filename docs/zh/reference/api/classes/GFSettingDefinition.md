# GFSettingDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/settings/gf_setting_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

单个运行时设置项的声明。 只描述稳定键、默认值、值类型和持久化策略，不绑定具体 UI 或业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`ValueType`](#member-gfsettingdefinition-enums-valuetype) | `enum ValueType` |
| 属性 | [`key`](#member-gfsettingdefinition-properties-key) | `var key: StringName = &""` |
| 属性 | [`default_value`](#member-gfsettingdefinition-properties-default_value) | `var default_value: Variant = null` |
| 属性 | [`value_type`](#member-gfsettingdefinition-properties-value_type) | `var value_type: ValueType = ValueType.ANY` |
| 属性 | [`persistent`](#member-gfsettingdefinition-properties-persistent) | `var persistent: bool = true` |
| 属性 | [`metadata`](#member-gfsettingdefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_setting_key`](#member-gfsettingdefinition-methods-get_setting_key) | `func get_setting_key() -> StringName:` |
| 方法 | [`coerce_value`](#member-gfsettingdefinition-methods-coerce_value) | `func coerce_value(value: Variant) -> Variant:` |
| 方法 | [`is_value_valid`](#member-gfsettingdefinition-methods-is_value_valid) | `func is_value_valid(value: Variant) -> bool:` |
| 方法 | [`duplicate_definition`](#member-gfsettingdefinition-methods-duplicate_definition) | `func duplicate_definition() -> GFSettingDefinition:` |

## 枚举

<a id="member-gfsettingdefinition-enums-valuetype"></a>

### `ValueType`

- API：`public`

```gdscript
enum ValueType { ## 不做类型转换。 ANY, ## 布尔值。 BOOL, ## 整数。 INT, ## 浮点数。 FLOAT, ## 字符串。 STRING, ## StringName。 STRING_NAME, ## Vector2。 VECTOR2, ## Vector2i。 VECTOR2I, ## Color。 COLOR, ## Dictionary。 DICTIONARY, ## Array。 ARRAY, }
```

设置值类型，用于运行时输入钳制和持久化恢复。

## 属性

<a id="member-gfsettingdefinition-properties-key"></a>

### `key`

- API：`public`

```gdscript
var key: StringName = &""
```

设置项稳定键。建议使用 `category/name` 形式。

<a id="member-gfsettingdefinition-properties-default_value"></a>

### `default_value`

- API：`public`

```gdscript
var default_value: Variant = null
```

默认值。

结构：

- `default_value`: Variant setting value accepted by value_type.

<a id="member-gfsettingdefinition-properties-value_type"></a>

### `value_type`

- API：`public`

```gdscript
var value_type: ValueType = ValueType.ANY
```

值类型。

<a id="member-gfsettingdefinition-properties-persistent"></a>

### `persistent`

- API：`public`

```gdscript
var persistent: bool = true
```

是否参与持久化保存。

<a id="member-gfsettingdefinition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供设置界面分组、排序或展示使用。

结构：

- `metadata`: Dictionary with optional UI grouping, ordering, label, and project-defined metadata.

## 方法

<a id="member-gfsettingdefinition-methods-get_setting_key"></a>

### `get_setting_key`

- API：`public`

```gdscript
func get_setting_key() -> StringName:
```

获取稳定设置键。

返回：设置键；未显式设置时尝试使用资源路径。

<a id="member-gfsettingdefinition-methods-coerce_value"></a>

### `coerce_value`

- API：`public`

```gdscript
func coerce_value(value: Variant) -> Variant:
```

将输入值转换为当前定义要求的类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入值。 |

返回：转换后的值。

结构：

- `value`: Variant setting value accepted by value_type.
- `return`: Variant coerced to the configured value_type when possible.

<a id="member-gfsettingdefinition-methods-is_value_valid"></a>

### `is_value_valid`

- API：`public`

```gdscript
func is_value_valid(value: Variant) -> bool:
```

检查值是否符合声明类型。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 待检查值。 |

返回：符合时返回 true。

结构：

- `value`: Variant setting value to validate against value_type.

<a id="member-gfsettingdefinition-methods-duplicate_definition"></a>

### `duplicate_definition`

- API：`public`

```gdscript
func duplicate_definition() -> GFSettingDefinition:
```

创建同内容拷贝，避免运行时修改污染共享资源。

返回：新定义。
