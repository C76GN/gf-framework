# GFInventoryModel

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_model.gd`
- 模块：`Domain`
- 继承：`GFModel`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用可序列化库存模型。 只管理 item_id、数量和元数据，不假设道具类型、品质、装备等业务概念。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`add_item`](#member-gfinventorymodel-methods-add_item) | `func add_item(item_id: StringName, amount: int = 1, metadata: Dictionary = {}) -> void:` |
| 方法 | [`remove_item`](#member-gfinventorymodel-methods-remove_item) | `func remove_item(item_id: StringName, amount: int = 1) -> bool:` |
| 方法 | [`set_item_amount`](#member-gfinventorymodel-methods-set_item_amount) | `func set_item_amount(item_id: StringName, amount: int) -> void:` |
| 方法 | [`get_item_amount`](#member-gfinventorymodel-methods-get_item_amount) | `func get_item_amount(item_id: StringName) -> int:` |
| 方法 | [`has_item`](#member-gfinventorymodel-methods-has_item) | `func has_item(item_id: StringName, amount: int = 1) -> bool:` |
| 方法 | [`get_item_metadata`](#member-gfinventorymodel-methods-get_item_metadata) | `func get_item_metadata(item_id: StringName) -> Dictionary:` |
| 方法 | [`get_items`](#member-gfinventorymodel-methods-get_items) | `func get_items() -> Dictionary:` |
| 方法 | [`clear`](#member-gfinventorymodel-methods-clear) | `func clear() -> void:` |
| 方法 | [`to_dict`](#member-gfinventorymodel-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfinventorymodel-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 方法

<a id="member-gfinventorymodel-methods-add_item"></a>

### `add_item`

- API：`public`

```gdscript
func add_item(item_id: StringName, amount: int = 1, metadata: Dictionary = {}) -> void:
```

添加物品数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |
| `amount` | 增加数量。 |
| `metadata` | 可选元数据；首次加入时保存。 |

结构：

- `metadata`: Dictionary，首次加入物品时保存的项目自定义元数据。

<a id="member-gfinventorymodel-methods-remove_item"></a>

### `remove_item`

- API：`public`

```gdscript
func remove_item(item_id: StringName, amount: int = 1) -> bool:
```

移除物品数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |
| `amount` | 移除数量。 |

返回：成功移除完整数量时返回 true。

<a id="member-gfinventorymodel-methods-set_item_amount"></a>

### `set_item_amount`

- API：`public`

```gdscript
func set_item_amount(item_id: StringName, amount: int) -> void:
```

设置物品数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |
| `amount` | 新数量；小于等于 0 时移除。 |

<a id="member-gfinventorymodel-methods-get_item_amount"></a>

### `get_item_amount`

- API：`public`

```gdscript
func get_item_amount(item_id: StringName) -> int:
```

获取物品数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |

返回：数量。

<a id="member-gfinventorymodel-methods-has_item"></a>

### `has_item`

- API：`public`

```gdscript
func has_item(item_id: StringName, amount: int = 1) -> bool:
```

检查是否拥有足够数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |
| `amount` | 需要数量。 |

返回：足够时返回 true。

<a id="member-gfinventorymodel-methods-get_item_metadata"></a>

### `get_item_metadata`

- API：`public`

```gdscript
func get_item_metadata(item_id: StringName) -> Dictionary:
```

获取物品元数据。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品 ID。 |

返回：元数据副本。

结构：

- `return`: Dictionary，物品项目自定义元数据副本；不存在时为空字典。

<a id="member-gfinventorymodel-methods-get_items"></a>

### `get_items`

- API：`public`

```gdscript
func get_items() -> Dictionary:
```

获取库存快照。

返回：库存字典副本。

结构：

- `return`: Dictionary，键为 StringName 物品 ID，值为包含 amount 与 metadata 的堆叠记录。

<a id="member-gfinventorymodel-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空库存。

<a id="member-gfinventorymodel-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

序列化库存状态。

返回：可写入存档的字典。

结构：

- `return`: Dictionary，包含 items 字典；items 键为 String 物品 ID，值为 amount 与 metadata 记录。

<a id="member-gfinventorymodel-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复库存状态。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 序列化数据。 |

结构：

- `data`: Dictionary，包含 items 字典；items 键为 String 物品 ID，值为 amount 与 metadata 记录。
