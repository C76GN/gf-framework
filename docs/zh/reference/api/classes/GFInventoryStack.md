# GFInventoryStack

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_stack.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用库存堆叠记录。 只保存物品标识、数量和实例数据，不解释实例数据的业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`item_id`](#member-gfinventorystack-properties-item_id) | `var item_id: StringName = &""` |
| 属性 | [`amount`](#member-gfinventorystack-properties-amount) | `var amount: int:` |
| 属性 | [`instance_data`](#member-gfinventorystack-properties-instance_data) | `var instance_data: Dictionary = {}` |
| 方法 | [`is_empty`](#member-gfinventorystack-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_stack_limit`](#member-gfinventorystack-methods-get_stack_limit) | `func get_stack_limit(registry: GFInventoryItemRegistry = null) -> int:` |
| 方法 | [`get_available_space`](#member-gfinventorystack-methods-get_available_space) | `func get_available_space(registry: GFInventoryItemRegistry = null) -> int:` |
| 方法 | [`can_merge`](#member-gfinventorystack-methods-can_merge) | `func can_merge( target_item_id: StringName, target_instance_data: Dictionary = {}, registry: GFInventoryItemRegistry = null ) -> bool:` |
| 方法 | [`add_amount`](#member-gfinventorystack-methods-add_amount) | `func add_amount(quantity: int, registry: GFInventoryItemRegistry = null) -> int:` |
| 方法 | [`remove_amount`](#member-gfinventorystack-methods-remove_amount) | `func remove_amount(quantity: int) -> int:` |
| 方法 | [`clear`](#member-gfinventorystack-methods-clear) | `func clear() -> void:` |
| 方法 | [`duplicate_stack`](#member-gfinventorystack-methods-duplicate_stack) | `func duplicate_stack() -> GFInventoryStack:` |
| 方法 | [`to_dict`](#member-gfinventorystack-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinventorystack-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfinventorystack-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFInventoryStack:` |

## 属性

<a id="member-gfinventorystack-properties-item_id"></a>

### `item_id`

- API：`public`

```gdscript
var item_id: StringName = &""
```

物品稳定标识。

<a id="member-gfinventorystack-properties-amount"></a>

### `amount`

- API：`public`

```gdscript
var amount: int:
```

当前堆叠数量。

<a id="member-gfinventorystack-properties-instance_data"></a>

### `instance_data`

- API：`public`

```gdscript
var instance_data: Dictionary = {}
```

项目自定义实例数据。框架只用于兼容性比较和序列化。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；GF 只用于兼容性比较和序列化。

## 方法

<a id="member-gfinventorystack-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查堆叠是否为空。

返回：为空返回 true。

<a id="member-gfinventorystack-methods-get_stack_limit"></a>

### `get_stack_limit`

- API：`public`

```gdscript
func get_stack_limit(registry: GFInventoryItemRegistry = null) -> int:
```

获取当前堆叠容量上限。

参数：

| 名称 | 说明 |
|---|---|
| `registry` | 可选物品注册表。 |

返回：堆叠容量上限。

<a id="member-gfinventorystack-methods-get_available_space"></a>

### `get_available_space`

- API：`public`

```gdscript
func get_available_space(registry: GFInventoryItemRegistry = null) -> int:
```

获取当前堆叠剩余空间。

参数：

| 名称 | 说明 |
|---|---|
| `registry` | 可选物品注册表。 |

返回：剩余空间。

<a id="member-gfinventorystack-methods-can_merge"></a>

### `can_merge`

- API：`public`

```gdscript
func can_merge( target_item_id: StringName, target_instance_data: Dictionary = {}, registry: GFInventoryItemRegistry = null ) -> bool:
```

检查是否可与指定物品实例合并。

参数：

| 名称 | 说明 |
|---|---|
| `target_item_id` | 目标物品标识。 |
| `target_instance_data` | 目标实例数据。 |
| `registry` | 可选物品注册表。 |

返回：可合并返回 true。

结构：

- `target_instance_data`: Dictionary，目标物品实例数据。

<a id="member-gfinventorystack-methods-add_amount"></a>

### `add_amount`

- API：`public`

```gdscript
func add_amount(quantity: int, registry: GFInventoryItemRegistry = null) -> int:
```

增加数量并返回未加入的剩余数量。

参数：

| 名称 | 说明 |
|---|---|
| `quantity` | 尝试增加的数量。 |
| `registry` | 可选物品注册表。 |

返回：未加入的剩余数量。

<a id="member-gfinventorystack-methods-remove_amount"></a>

### `remove_amount`

- API：`public`

```gdscript
func remove_amount(quantity: int) -> int:
```

移除数量并返回实际移除数量。

参数：

| 名称 | 说明 |
|---|---|
| `quantity` | 尝试移除的数量。 |

返回：实际移除数量。

<a id="member-gfinventorystack-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空堆叠。

<a id="member-gfinventorystack-methods-duplicate_stack"></a>

### `duplicate_stack`

- API：`public`

```gdscript
func duplicate_stack() -> GFInventoryStack:
```

复制堆叠。

返回：新堆叠资源。

<a id="member-gfinventorystack-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Godot Variant 字典；不保证可直接编码为 JSON。

结构：

- `return`: Dictionary，包含 item_id、amount 与 instance_data。

<a id="member-gfinventorystack-methods-apply_dict"></a>

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

- `data`: Dictionary，可包含 item_id、amount 与 instance_data。

<a id="member-gfinventorystack-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFInventoryStack:
```

从字典创建堆叠。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

返回：堆叠资源。

结构：

- `data`: Dictionary，可包含 item_id、amount 与 instance_data。
