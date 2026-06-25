# GFModifier

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_modifier.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

属性修饰器数据类。 定义了如何修改一个通用属性（如加值、乘值）。 `attribute_id` 表示目标属性，`source_id` 表示来源，避免把“改谁”和“从哪来”混在一起。 通常由 Buff、装备或被动技能产生。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Type`](#member-gfmodifier-enums-type) | `enum Type` |
| 属性 | [`type`](#member-gfmodifier-properties-type) | `var type: Type = Type.BASE_ADD` |
| 属性 | [`value`](#member-gfmodifier-properties-value) | `var value: float = 0.0` |
| 属性 | [`attribute_id`](#member-gfmodifier-properties-attribute_id) | `var attribute_id: StringName = &""` |
| 属性 | [`source_id`](#member-gfmodifier-properties-source_id) | `var source_id: StringName = &""` |
| 方法 | [`create_base_add`](#member-gfmodifier-methods-create_base_add) | `static func create_base_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:` |
| 方法 | [`create_percent_add`](#member-gfmodifier-methods-create_percent_add) | `static func create_percent_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:` |
| 方法 | [`create_final_add`](#member-gfmodifier-methods-create_final_add) | `static func create_final_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:` |
| 方法 | [`duplicate_modifier`](#member-gfmodifier-methods-duplicate_modifier) | `func duplicate_modifier() -> GFModifier:` |
| 方法 | [`to_dictionary`](#member-gfmodifier-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`apply_dictionary`](#member-gfmodifier-methods-apply_dictionary) | `func apply_dictionary(data: Dictionary) -> void:` |
| 方法 | [`from_dictionary`](#member-gfmodifier-methods-from_dictionary) | `static func from_dictionary(data: Dictionary) -> GFModifier:` |

## 枚举

<a id="member-gfmodifier-enums-type"></a>

### `Type`

- API：`public`

```gdscript
enum Type {
	## 基础加值。
	BASE_ADD,
	## 百分比乘区。
	PERCENT_ADD,
	## 最终加值。
	FINAL_ADD,
}
```

修饰器计算类型。

## 属性

<a id="member-gfmodifier-properties-type"></a>

### `type`

- API：`public`

```gdscript
var type: Type = Type.BASE_ADD
```

修饰器类型。

<a id="member-gfmodifier-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: float = 0.0
```

修饰器的数值。

<a id="member-gfmodifier-properties-attribute_id"></a>

### `attribute_id`

- API：`public`

```gdscript
var attribute_id: StringName = &""
```

目标属性标识，例如 &"ATK"、&"HP"。

<a id="member-gfmodifier-properties-source_id"></a>

### `source_id`

- API：`public`

```gdscript
var source_id: StringName = &""
```

来源标识，例如 Buff ID、装备 ID 或被动技能 ID，用于查找和移除。

## 方法

<a id="member-gfmodifier-methods-create_base_add"></a>

### `create_base_add`

- API：`public`

```gdscript
static func create_base_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:
```

静态工厂方法：创建基础加值修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_value` | 修饰器数值。 |
| `p_attribute_id` | 修饰器作用的属性标识。 |
| `p_source_id` | 修饰器来源标识。 |

返回：新修饰器。

<a id="member-gfmodifier-methods-create_percent_add"></a>

### `create_percent_add`

- API：`public`

```gdscript
static func create_percent_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:
```

静态工厂方法：创建百分比加值修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_value` | 修饰器数值。 |
| `p_attribute_id` | 修饰器作用的属性标识。 |
| `p_source_id` | 修饰器来源标识。 |

返回：新修饰器。

<a id="member-gfmodifier-methods-create_final_add"></a>

### `create_final_add`

- API：`public`

```gdscript
static func create_final_add( p_value: float, p_attribute_id: StringName = &"", p_source_id: StringName = &"" ) -> GFModifier:
```

静态工厂方法：创建最终加值修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_value` | 修饰器数值。 |
| `p_attribute_id` | 修饰器作用的属性标识。 |
| `p_source_id` | 修饰器来源标识。 |

返回：新修饰器。

<a id="member-gfmodifier-methods-duplicate_modifier"></a>

### `duplicate_modifier`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func duplicate_modifier() -> GFModifier:
```

创建修饰器副本。

返回：新修饰器。

<a id="member-gfmodifier-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为可序列化字典。

返回：修饰器字典。

结构：

- `return`: Dictionary with type, value, attribute_id, and source_id.

<a id="member-gfmodifier-methods-apply_dictionary"></a>

### `apply_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func apply_dictionary(data: Dictionary) -> void:
```

从字典应用修饰器字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 修饰器字典。 |

结构：

- `data`: Dictionary with optional type, value, attribute_id, and source_id.

<a id="member-gfmodifier-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_dictionary(data: Dictionary) -> GFModifier:
```

从字典创建修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 修饰器字典。 |

返回：新修饰器。

结构：

- `data`: Dictionary with optional type, value, attribute_id, and source_id.
