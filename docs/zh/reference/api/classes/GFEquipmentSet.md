# GFEquipmentSet

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/equipment/gf_equipment_set.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用槽位集合。 用于管理一组 `GFEquipmentSlot`，不约束槽位名称或装备类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`slots`](#member-gfequipmentset-properties-slots) | `var slots: Dictionary = {}` |
| 方法 | [`set_slot`](#member-gfequipmentset-methods-set_slot) | `func set_slot(slot: GFEquipmentSlot) -> void:` |
| 方法 | [`get_slot`](#member-gfequipmentset-methods-get_slot) | `func get_slot(slot_id: StringName) -> GFEquipmentSlot:` |
| 方法 | [`equip`](#member-gfequipmentset-methods-equip) | `func equip(slot_id: StringName, item_id: StringName, item_tags: Array[StringName] = []) -> bool:` |
| 方法 | [`unequip`](#member-gfequipmentset-methods-unequip) | `func unequip(slot_id: StringName) -> void:` |
| 方法 | [`get_equipped_item`](#member-gfequipmentset-methods-get_equipped_item) | `func get_equipped_item(slot_id: StringName) -> StringName:` |

## 属性

<a id="member-gfequipmentset-properties-slots"></a>

### `slots`

- API：`public`

```gdscript
var slots: Dictionary = {}
```

槽位表。Key 推荐为 StringName，Value 应为 GFEquipmentSlot。

结构：

- `slots`: Dictionary，键为 StringName 槽位 ID，值为 GFEquipmentSlot 槽位资源。

## 方法

<a id="member-gfequipmentset-methods-set_slot"></a>

### `set_slot`

- API：`public`

```gdscript
func set_slot(slot: GFEquipmentSlot) -> void:
```

添加或替换槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot` | 槽位资源。 |

<a id="member-gfequipmentset-methods-get_slot"></a>

### `get_slot`

- API：`public`

```gdscript
func get_slot(slot_id: StringName) -> GFEquipmentSlot:
```

获取槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_id` | 槽位 ID。 |

返回：槽位资源；不存在时返回 null。

<a id="member-gfequipmentset-methods-equip"></a>

### `equip`

- API：`public`

```gdscript
func equip(slot_id: StringName, item_id: StringName, item_tags: Array[StringName] = []) -> bool:
```

挂载物品到槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_id` | 槽位 ID。 |
| `item_id` | 物品 ID。 |
| `item_tags` | 物品标签。 |

返回：成功时返回 true。

结构：

- `item_tags`: Array[StringName]，当前物品拥有的标签列表。

<a id="member-gfequipmentset-methods-unequip"></a>

### `unequip`

- API：`public`

```gdscript
func unequip(slot_id: StringName) -> void:
```

清空槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_id` | 槽位 ID。 |

<a id="member-gfequipmentset-methods-get_equipped_item"></a>

### `get_equipped_item`

- API：`public`

```gdscript
func get_equipped_item(slot_id: StringName) -> StringName:
```

获取槽位当前物品。

参数：

| 名称 | 说明 |
|---|---|
| `slot_id` | 槽位 ID。 |

返回：物品 ID。
