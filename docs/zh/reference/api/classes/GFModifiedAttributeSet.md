# GFModifiedAttributeSet

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/attributes/gf_modified_attribute_set.gd`
- 模块：`Combat`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

一组可修饰运行时属性。 用 StringName 管理多个 GFModifiedAttribute，便于角色、装备或能力对象集中维护 移动速度、攻击、防御等项目自定义数值。它不规定属性含义，也不直接处理 Buff 生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`attribute_defined`](#member-gfmodifiedattributeset-signals-attribute_defined) | `signal attribute_defined(attribute_id: StringName, attribute: GFModifiedAttribute)` |
| 信号 | [`attribute_removed`](#member-gfmodifiedattributeset-signals-attribute_removed) | `signal attribute_removed(attribute_id: StringName)` |
| 信号 | [`attribute_changed`](#member-gfmodifiedattributeset-signals-attribute_changed) | `signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)` |
| 方法 | [`define_attribute`](#member-gfmodifiedattributeset-methods-define_attribute) | `func define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:` |
| 方法 | [`set_attribute`](#member-gfmodifiedattributeset-methods-set_attribute) | `func set_attribute(attribute_id: StringName, attribute: GFModifiedAttribute) -> bool:` |
| 方法 | [`define_defaults`](#member-gfmodifiedattributeset-methods-define_defaults) | `func define_defaults(defaults: Dictionary) -> void:` |
| 方法 | [`has_attribute`](#member-gfmodifiedattributeset-methods-has_attribute) | `func has_attribute(attribute_id: StringName) -> bool:` |
| 方法 | [`get_attribute`](#member-gfmodifiedattributeset-methods-get_attribute) | `func get_attribute(attribute_id: StringName) -> GFModifiedAttribute:` |
| 方法 | [`get_or_define_attribute`](#member-gfmodifiedattributeset-methods-get_or_define_attribute) | `func get_or_define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:` |
| 方法 | [`remove_attribute`](#member-gfmodifiedattributeset-methods-remove_attribute) | `func remove_attribute(attribute_id: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfmodifiedattributeset-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_attribute_ids`](#member-gfmodifiedattributeset-methods-get_attribute_ids) | `func get_attribute_ids() -> Array[StringName]:` |
| 方法 | [`get_attributes`](#member-gfmodifiedattributeset-methods-get_attributes) | `func get_attributes() -> Dictionary:` |
| 方法 | [`get_value`](#member-gfmodifiedattributeset-methods-get_value) | `func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`set_base_value`](#member-gfmodifiedattributeset-methods-set_base_value) | `func set_base_value(attribute_id: StringName, base_value: float) -> bool:` |
| 方法 | [`get_base_value`](#member-gfmodifiedattributeset-methods-get_base_value) | `func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`add_modifier`](#member-gfmodifiedattributeset-methods-add_modifier) | `func add_modifier( attribute_id: StringName, modifier: GFModifier, define_if_missing: bool = false ) -> bool:` |
| 方法 | [`remove_modifier`](#member-gfmodifiedattributeset-methods-remove_modifier) | `func remove_modifier(attribute_id: StringName, modifier: GFModifier) -> bool:` |
| 方法 | [`remove_modifiers_by_source`](#member-gfmodifiedattributeset-methods-remove_modifiers_by_source) | `func remove_modifiers_by_source(source_id: StringName, attribute_id: StringName = &"") -> void:` |
| 方法 | [`force_recalculate`](#member-gfmodifiedattributeset-methods-force_recalculate) | `func force_recalculate(attribute_id: StringName = &"") -> void:` |
| 方法 | [`get_base_value_snapshot`](#member-gfmodifiedattributeset-methods-get_base_value_snapshot) | `func get_base_value_snapshot() -> Dictionary:` |
| 方法 | [`restore_base_value_snapshot`](#member-gfmodifiedattributeset-methods-restore_base_value_snapshot) | `func restore_base_value_snapshot(snapshot: Dictionary, clear_existing: bool = false) -> void:` |

## 信号

<a id="member-gfmodifiedattributeset-signals-attribute_defined"></a>

### `attribute_defined`

- API：`public`

```gdscript
signal attribute_defined(attribute_id: StringName, attribute: GFModifiedAttribute)
```

属性被定义或替换时发出。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `attribute` | 属性实例。 |

<a id="member-gfmodifiedattributeset-signals-attribute_removed"></a>

### `attribute_removed`

- API：`public`

```gdscript
signal attribute_removed(attribute_id: StringName)
```

属性被移除时发出。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

<a id="member-gfmodifiedattributeset-signals-attribute_changed"></a>

### `attribute_changed`

- API：`public`

```gdscript
signal attribute_changed(attribute_id: StringName, current_value: float, previous_value: float)
```

属性当前值变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `current_value` | 当前值。 |
| `previous_value` | 变化前的值。 |

## 方法

<a id="member-gfmodifiedattributeset-methods-define_attribute"></a>

### `define_attribute`

- API：`public`

```gdscript
func define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:
```

定义或替换属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `base_value` | 基础值。 |

返回：新创建的属性；attribute_id 为空时返回 null。

<a id="member-gfmodifiedattributeset-methods-set_attribute"></a>

### `set_attribute`

- API：`public`

```gdscript
func set_attribute(attribute_id: StringName, attribute: GFModifiedAttribute) -> bool:
```

设置已有属性实例。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `attribute` | 属性实例。 |

返回：设置成功返回 true。

<a id="member-gfmodifiedattributeset-methods-define_defaults"></a>

### `define_defaults`

- API：`public`

```gdscript
func define_defaults(defaults: Dictionary) -> void:
```

批量定义默认属性。

参数：

| 名称 | 说明 |
|---|---|
| `defaults` | attribute_id -> base_value 字典。 |

结构：

- `defaults`: Dictionary，键为属性标识，值为基础数值。

<a id="member-gfmodifiedattributeset-methods-has_attribute"></a>

### `has_attribute`

- API：`public`

```gdscript
func has_attribute(attribute_id: StringName) -> bool:
```

检查属性是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

返回：存在返回 true。

<a id="member-gfmodifiedattributeset-methods-get_attribute"></a>

### `get_attribute`

- API：`public`

```gdscript
func get_attribute(attribute_id: StringName) -> GFModifiedAttribute:
```

获取属性实例。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

返回：属性实例；不存在时返回 null。

<a id="member-gfmodifiedattributeset-methods-get_or_define_attribute"></a>

### `get_or_define_attribute`

- API：`public`

```gdscript
func get_or_define_attribute(attribute_id: StringName, base_value: float = 0.0) -> GFModifiedAttribute:
```

获取属性实例，不存在时自动定义。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `base_value` | 自动定义时使用的基础值。 |

返回：属性实例；attribute_id 为空时返回 null。

<a id="member-gfmodifiedattributeset-methods-remove_attribute"></a>

### `remove_attribute`

- API：`public`

```gdscript
func remove_attribute(attribute_id: StringName) -> bool:
```

移除属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |

返回：移除成功返回 true。

<a id="member-gfmodifiedattributeset-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func clear() -> void:
```

清空所有属性。 清理会先原子地脱离原有索引与信号，再发送移除通知；通知期间新定义的属性会保留。

<a id="member-gfmodifiedattributeset-methods-get_attribute_ids"></a>

### `get_attribute_ids`

- API：`public`

```gdscript
func get_attribute_ids() -> Array[StringName]:
```

获取属性 ID 列表。

返回：属性 ID 列表。

结构：

- `return`: Array[StringName]，元素为属性标识。

<a id="member-gfmodifiedattributeset-methods-get_attributes"></a>

### `get_attributes`

- API：`public`

```gdscript
func get_attributes() -> Dictionary:
```

获取属性字典副本。

返回：attribute_id -> GFModifiedAttribute 字典副本。

结构：

- `return`: Dictionary，键为属性标识，值为 GFModifiedAttribute 实例。

<a id="member-gfmodifiedattributeset-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(attribute_id: StringName, default_value: float = 0.0) -> float:
```

获取属性当前值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `default_value` | 属性不存在时返回的默认值。 |

返回：当前值。

<a id="member-gfmodifiedattributeset-methods-set_base_value"></a>

### `set_base_value`

- API：`public`

```gdscript
func set_base_value(attribute_id: StringName, base_value: float) -> bool:
```

设置属性基础值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `base_value` | 新基础值。 |

返回：设置成功返回 true。

<a id="member-gfmodifiedattributeset-methods-get_base_value"></a>

### `get_base_value`

- API：`public`

```gdscript
func get_base_value(attribute_id: StringName, default_value: float = 0.0) -> float:
```

获取属性基础值。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `default_value` | 属性不存在时返回的默认值。 |

返回：基础值。

<a id="member-gfmodifiedattributeset-methods-add_modifier"></a>

### `add_modifier`

- API：`public`

```gdscript
func add_modifier( attribute_id: StringName, modifier: GFModifier, define_if_missing: bool = false ) -> bool:
```

添加修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `modifier` | 修饰器实例。 |
| `define_if_missing` | 属性不存在时是否自动定义。 |

返回：添加成功返回 true。

<a id="member-gfmodifiedattributeset-methods-remove_modifier"></a>

### `remove_modifier`

- API：`public`

```gdscript
func remove_modifier(attribute_id: StringName, modifier: GFModifier) -> bool:
```

移除修饰器。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 属性标识。 |
| `modifier` | 修饰器实例。 |

返回：属性存在且 modifier 有效时返回 true。

<a id="member-gfmodifiedattributeset-methods-remove_modifiers_by_source"></a>

### `remove_modifiers_by_source`

- API：`public`

```gdscript
func remove_modifiers_by_source(source_id: StringName, attribute_id: StringName = &"") -> void:
```

按来源移除修饰器；attribute_id 为空时会作用于全部属性。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 来源标识。 |
| `attribute_id` | 可选属性标识。 |

<a id="member-gfmodifiedattributeset-methods-force_recalculate"></a>

### `force_recalculate`

- API：`public`

```gdscript
func force_recalculate(attribute_id: StringName = &"") -> void:
```

强制重算属性；attribute_id 为空时会重算全部属性。

参数：

| 名称 | 说明 |
|---|---|
| `attribute_id` | 可选属性标识。 |

<a id="member-gfmodifiedattributeset-methods-get_base_value_snapshot"></a>

### `get_base_value_snapshot`

- API：`public`

```gdscript
func get_base_value_snapshot() -> Dictionary:
```

导出基础值快照。修饰器属于运行时状态，不会进入该快照。

返回：attribute_id -> base_value 字典。

结构：

- `return`: Dictionary，键为属性标识，值为基础数值。

<a id="member-gfmodifiedattributeset-methods-restore_base_value_snapshot"></a>

### `restore_base_value_snapshot`

- API：`public`

```gdscript
func restore_base_value_snapshot(snapshot: Dictionary, clear_existing: bool = false) -> void:
```

从基础值快照恢复。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | attribute_id -> base_value 字典。 |
| `clear_existing` | 是否先清空现有属性。 |

结构：

- `snapshot`: Dictionary，键为属性标识，值为基础数值。
