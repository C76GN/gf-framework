# GFPropertyBagCapability

[API Reference](../index.md) / [Capability](../extensions-capability.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/capability/core/gf_property_bag_capability.gd`
- 模块：`Capability`
- 继承：`GFCapability`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

轻量动态属性扩展能力。 适合为对象挂载少量运行时标签值、编辑器调试值或原型数据。 长期核心状态仍应放入 GFModel 或配置资源。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`property_changed`](#member-gfpropertybagcapability-signals-property_changed) | `signal property_changed(key: StringName, old_value: Variant, new_value: Variant)` |
| 信号 | [`property_removed`](#member-gfpropertybagcapability-signals-property_removed) | `signal property_removed(key: StringName, old_value: Variant)` |
| 属性 | [`values`](#member-gfpropertybagcapability-properties-values) | `var values: Dictionary = {}` |
| 方法 | [`set_property_value`](#member-gfpropertybagcapability-methods-set_property_value) | `func set_property_value(key: StringName, value: Variant) -> void:` |
| 方法 | [`get_property_value`](#member-gfpropertybagcapability-methods-get_property_value) | `func get_property_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`has_property_value`](#member-gfpropertybagcapability-methods-has_property_value) | `func has_property_value(key: StringName) -> bool:` |
| 方法 | [`remove_property_value`](#member-gfpropertybagcapability-methods-remove_property_value) | `func remove_property_value(key: StringName) -> bool:` |
| 方法 | [`clear_properties`](#member-gfpropertybagcapability-methods-clear_properties) | `func clear_properties() -> void:` |
| 方法 | [`get_int`](#member-gfpropertybagcapability-methods-get_int) | `func get_int(key: StringName, default_value: int = 0) -> int:` |
| 方法 | [`get_float`](#member-gfpropertybagcapability-methods-get_float) | `func get_float(key: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`get_bool`](#member-gfpropertybagcapability-methods-get_bool) | `func get_bool(key: StringName, default_value: bool = false) -> bool:` |
| 方法 | [`get_string`](#member-gfpropertybagcapability-methods-get_string) | `func get_string(key: StringName, default_value: String = "") -> String:` |
| 方法 | [`get_vector2`](#member-gfpropertybagcapability-methods-get_vector2) | `func get_vector2(key: StringName, default_value: Vector2 = Vector2.ZERO) -> Vector2:` |
| 方法 | [`get_color`](#member-gfpropertybagcapability-methods-get_color) | `func get_color(key: StringName, default_value: Color = Color.WHITE) -> Color:` |

## 信号

<a id="member-gfpropertybagcapability-signals-property_changed"></a>

### `property_changed`

- API：`public`

```gdscript
signal property_changed(key: StringName, old_value: Variant, new_value: Variant)
```

当属性值发生变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `old_value` | 旧属性值。 |
| `new_value` | 新属性值。 |

结构：

- `old_value`: 属性表中的任意项目值；属性之前不存在时为 null。
- `new_value`: 属性表中的任意项目值。

<a id="member-gfpropertybagcapability-signals-property_removed"></a>

### `property_removed`

- API：`public`

```gdscript
signal property_removed(key: StringName, old_value: Variant)
```

当属性被移除时发出。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `old_value` | 被移除的旧属性值。 |

结构：

- `old_value`: 属性表中的任意项目值。

## 属性

<a id="member-gfpropertybagcapability-properties-values"></a>

### `values`

- API：`public`

```gdscript
var values: Dictionary = {}
```

当前属性表。

结构：

- `values`: 动态属性 Dictionary；键通常为 StringName，值由项目决定。

## 方法

<a id="member-gfpropertybagcapability-methods-set_property_value"></a>

### `set_property_value`

- API：`public`

```gdscript
func set_property_value(key: StringName, value: Variant) -> void:
```

设置属性值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `value` | 要写入或修改的值。 |

结构：

- `value`: 要写入属性表的任意项目值。

<a id="member-gfpropertybagcapability-methods-get_property_value"></a>

### `get_property_value`

- API：`public`

```gdscript
func get_property_value(key: StringName, default_value: Variant = null) -> Variant:
```

获取属性值。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失时返回的默认值。 |

返回：属性值或默认值。

结构：

- `default_value`: 属性缺失时返回的任意默认值。
- `return`: 属性表中的项目值，或传入的 default_value。

<a id="member-gfpropertybagcapability-methods-has_property_value"></a>

### `has_property_value`

- API：`public`

```gdscript
func has_property_value(key: StringName) -> bool:
```

检查属性是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |

返回：存在返回 true。

<a id="member-gfpropertybagcapability-methods-remove_property_value"></a>

### `remove_property_value`

- API：`public`

```gdscript
func remove_property_value(key: StringName) -> bool:
```

移除属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |

返回：移除成功返回 true。

<a id="member-gfpropertybagcapability-methods-clear_properties"></a>

### `clear_properties`

- API：`public`

```gdscript
func clear_properties() -> void:
```

清空全部属性。

<a id="member-gfpropertybagcapability-methods-get_int"></a>

### `get_int`

- API：`public`

```gdscript
func get_int(key: StringName, default_value: int = 0) -> int:
```

获取 int 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：int 属性值或默认值。

<a id="member-gfpropertybagcapability-methods-get_float"></a>

### `get_float`

- API：`public`

```gdscript
func get_float(key: StringName, default_value: float = 0.0) -> float:
```

获取 float 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：float 属性值或默认值。

<a id="member-gfpropertybagcapability-methods-get_bool"></a>

### `get_bool`

- API：`public`

```gdscript
func get_bool(key: StringName, default_value: bool = false) -> bool:
```

获取 bool 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：bool 属性值或默认值。

<a id="member-gfpropertybagcapability-methods-get_string"></a>

### `get_string`

- API：`public`

```gdscript
func get_string(key: StringName, default_value: String = "") -> String:
```

获取 String 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：String 属性值或默认值。

<a id="member-gfpropertybagcapability-methods-get_vector2"></a>

### `get_vector2`

- API：`public`

```gdscript
func get_vector2(key: StringName, default_value: Vector2 = Vector2.ZERO) -> Vector2:
```

获取 Vector2 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：Vector2 属性值或默认值。

<a id="member-gfpropertybagcapability-methods-get_color"></a>

### `get_color`

- API：`public`

```gdscript
func get_color(key: StringName, default_value: Color = Color.WHITE) -> Color:
```

获取 Color 属性。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 属性键。 |
| `default_value` | 缺失或类型不匹配时返回的默认值。 |

返回：Color 属性值或默认值。
