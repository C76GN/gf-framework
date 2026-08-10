# GFInventoryItemRegistry

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_item_registry.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用库存物品定义注册表。 统一提供物品堆叠上限、堆叠数量上限和实例数据兼容性规则。 未注册物品可按默认规则处理，便于项目渐进接入资源化定义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`definitions`](#member-gfinventoryitemregistry-properties-definitions) | `var definitions: Dictionary = {}` |
| 属性 | [`default_max_stack_amount`](#member-gfinventoryitemregistry-properties-default_max_stack_amount) | `var default_max_stack_amount: int:` |
| 属性 | [`default_max_stack_count`](#member-gfinventoryitemregistry-properties-default_max_stack_count) | `var default_max_stack_count: int:` |
| 属性 | [`allow_unregistered_items`](#member-gfinventoryitemregistry-properties-allow_unregistered_items) | `var allow_unregistered_items: bool = true` |
| 方法 | [`set_definition`](#member-gfinventoryitemregistry-methods-set_definition) | `func set_definition(definition: GFInventoryItemDefinition) -> void:` |
| 方法 | [`remove_definition`](#member-gfinventoryitemregistry-methods-remove_definition) | `func remove_definition(item_id: StringName) -> void:` |
| 方法 | [`clear`](#member-gfinventoryitemregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`has_definition`](#member-gfinventoryitemregistry-methods-has_definition) | `func has_definition(item_id: StringName) -> bool:` |
| 方法 | [`get_definition`](#member-gfinventoryitemregistry-methods-get_definition) | `func get_definition(item_id: StringName) -> GFInventoryItemDefinition:` |
| 方法 | [`accepts_item`](#member-gfinventoryitemregistry-methods-accepts_item) | `func accepts_item(item_id: StringName) -> bool:` |
| 方法 | [`get_max_stack_amount`](#member-gfinventoryitemregistry-methods-get_max_stack_amount) | `func get_max_stack_amount(item_id: StringName) -> int:` |
| 方法 | [`get_max_stack_count`](#member-gfinventoryitemregistry-methods-get_max_stack_count) | `func get_max_stack_count(item_id: StringName) -> int:` |
| 方法 | [`normalize_instance_data`](#member-gfinventoryitemregistry-methods-normalize_instance_data) | `func normalize_instance_data(item_id: StringName, instance_data: Dictionary = {}) -> Dictionary:` |
| 方法 | [`are_instance_data_compatible`](#member-gfinventoryitemregistry-methods-are_instance_data_compatible) | `func are_instance_data_compatible( item_id: StringName, left: Dictionary = {}, right: Dictionary = {} ) -> bool:` |
| 方法 | [`to_dict`](#member-gfinventoryitemregistry-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinventoryitemregistry-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfinventoryitemregistry-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFInventoryItemRegistry:` |

## 属性

<a id="member-gfinventoryitemregistry-properties-definitions"></a>

### `definitions`

- API：`public`

```gdscript
var definitions: Dictionary = {}
```

物品定义表。Key 推荐为 StringName，Value 应为 GFInventoryItemDefinition。

结构：

- `definitions`: Dictionary，键为 StringName 或 String 物品 ID，值为 GFInventoryItemDefinition 物品定义资源。

<a id="member-gfinventoryitemregistry-properties-default_max_stack_amount"></a>

### `default_max_stack_amount`

- API：`public`

```gdscript
var default_max_stack_amount: int:
```

未注册物品的默认单堆叠容量。

<a id="member-gfinventoryitemregistry-properties-default_max_stack_count"></a>

### `default_max_stack_count`

- API：`public`

```gdscript
var default_max_stack_count: int:
```

未注册物品的默认堆叠数量上限。小于等于 0 表示不限制。

<a id="member-gfinventoryitemregistry-properties-allow_unregistered_items"></a>

### `allow_unregistered_items`

- API：`public`

```gdscript
var allow_unregistered_items: bool = true
```

是否允许未注册物品进入库存。

## 方法

<a id="member-gfinventoryitemregistry-methods-set_definition"></a>

### `set_definition`

- API：`public`

```gdscript
func set_definition(definition: GFInventoryItemDefinition) -> void:
```

添加或替换物品定义。

参数：

| 名称 | 说明 |
|---|---|
| `definition` | 物品定义。 |

<a id="member-gfinventoryitemregistry-methods-remove_definition"></a>

### `remove_definition`

- API：`public`

```gdscript
func remove_definition(item_id: StringName) -> void:
```

移除物品定义。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

<a id="member-gfinventoryitemregistry-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有物品定义。

<a id="member-gfinventoryitemregistry-methods-has_definition"></a>

### `has_definition`

- API：`public`

```gdscript
func has_definition(item_id: StringName) -> bool:
```

检查物品定义是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

返回：存在返回 true。

<a id="member-gfinventoryitemregistry-methods-get_definition"></a>

### `get_definition`

- API：`public`

```gdscript
func get_definition(item_id: StringName) -> GFInventoryItemDefinition:
```

获取物品定义。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

返回：物品定义；不存在时返回 null。

<a id="member-gfinventoryitemregistry-methods-accepts_item"></a>

### `accepts_item`

- API：`public`

```gdscript
func accepts_item(item_id: StringName) -> bool:
```

检查物品是否可被库存接受。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

返回：可接受返回 true。

<a id="member-gfinventoryitemregistry-methods-get_max_stack_amount"></a>

### `get_max_stack_amount`

- API：`public`

```gdscript
func get_max_stack_amount(item_id: StringName) -> int:
```

获取单堆叠容量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

返回：单堆叠容量。

<a id="member-gfinventoryitemregistry-methods-get_max_stack_count"></a>

### `get_max_stack_count`

- API：`public`

```gdscript
func get_max_stack_count(item_id: StringName) -> int:
```

获取堆叠数量上限。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |

返回：堆叠数量上限；小于等于 0 表示不限制。

<a id="member-gfinventoryitemregistry-methods-normalize_instance_data"></a>

### `normalize_instance_data`

- API：`public`

```gdscript
func normalize_instance_data(item_id: StringName, instance_data: Dictionary = {}) -> Dictionary:
```

规范化物品实例数据。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 实例数据。 |

返回：规范化后的实例数据副本。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。
- `return`: Dictionary，规范化后的物品实例数据副本。

<a id="member-gfinventoryitemregistry-methods-are_instance_data_compatible"></a>

### `are_instance_data_compatible`

- API：`public`

```gdscript
func are_instance_data_compatible( item_id: StringName, left: Dictionary = {}, right: Dictionary = {} ) -> bool:
```

判断两份实例数据是否可合并堆叠。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `left` | 左侧实例数据。 |
| `right` | 右侧实例数据。 |

返回：可合并返回 true。

结构：

- `left`: Dictionary，左侧物品实例数据。
- `right`: Dictionary，右侧物品实例数据。

<a id="member-gfinventoryitemregistry-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。

<a id="member-gfinventoryitemregistry-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

结构：

- `data`: Dictionary，可包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。

<a id="member-gfinventoryitemregistry-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFInventoryItemRegistry:
```

从字典创建注册表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

返回：物品定义注册表。

结构：

- `data`: Dictionary，可包含 definitions、default_max_stack_amount、default_max_stack_count 与 allow_unregistered_items。
