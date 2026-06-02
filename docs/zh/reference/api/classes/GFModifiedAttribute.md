# GFModifiedAttribute

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_modified_attribute.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

带修饰器公式的响应式属性。 持有基础值并管理多个修饰器 (GFModifier)。 内部使用公式 (Base + BaseAdd) * (1.0 + PercentAdd) + FinalAdd 进行自动重算。 对外通过只读的 current_value 暴露响应式结果，方便 UI 绑定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`current_value`](#member-gfmodifiedattribute-properties-current_value) | `var current_value: GFBindableProperty:` |
| 方法 | [`set_base_value`](#member-gfmodifiedattribute-methods-set_base_value) | `func set_base_value(p_value: float) -> void:` |
| 方法 | [`get_base_value`](#member-gfmodifiedattribute-methods-get_base_value) | `func get_base_value() -> float:` |
| 方法 | [`add_modifier`](#member-gfmodifiedattribute-methods-add_modifier) | `func add_modifier(p_modifier: GFModifier) -> void:` |
| 方法 | [`remove_modifier`](#member-gfmodifiedattribute-methods-remove_modifier) | `func remove_modifier(p_modifier: GFModifier) -> void:` |
| 方法 | [`remove_modifiers_by_source`](#member-gfmodifiedattribute-methods-remove_modifiers_by_source) | `func remove_modifiers_by_source(p_source_id: StringName) -> void:` |
| 方法 | [`force_recalculate`](#member-gfmodifiedattribute-methods-force_recalculate) | `func force_recalculate() -> void:` |

## 属性

<a id="member-gfmodifiedattribute-properties-current_value"></a>

### `current_value`

- API：`public`

```gdscript
var current_value: GFBindableProperty:
```

属性的只读响应式当前值。

## 方法

<a id="member-gfmodifiedattribute-methods-set_base_value"></a>

### `set_base_value`

- API：`public`

```gdscript
func set_base_value(p_value: float) -> void:
```

设置基础值。

参数：

| 名称 | 说明 |
|---|---|
| `p_value` | 新的基础值。 |

<a id="member-gfmodifiedattribute-methods-get_base_value"></a>

### `get_base_value`

- API：`public`

```gdscript
func get_base_value() -> float:
```

获取基础值。

返回：当前基础值。

<a id="member-gfmodifiedattribute-methods-add_modifier"></a>

### `add_modifier`

- API：`public`

```gdscript
func add_modifier(p_modifier: GFModifier) -> void:
```

添加修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_modifier` | 修饰器实例。 |

<a id="member-gfmodifiedattribute-methods-remove_modifier"></a>

### `remove_modifier`

- API：`public`

```gdscript
func remove_modifier(p_modifier: GFModifier) -> void:
```

移除修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_modifier` | 要移除的修饰器实例。 |

<a id="member-gfmodifiedattribute-methods-remove_modifiers_by_source"></a>

### `remove_modifiers_by_source`

- API：`public`

```gdscript
func remove_modifiers_by_source(p_source_id: StringName) -> void:
```

根据 source_id 移除所有匹配的修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_id` | 来源标识。 |

<a id="member-gfmodifiedattribute-methods-force_recalculate"></a>

### `force_recalculate`

- API：`public`

```gdscript
func force_recalculate() -> void:
```

强制执行一次属性重算。 当外部直接修改了 Modifier 的数值时，可手动调用此方法触发 UI 更新。
