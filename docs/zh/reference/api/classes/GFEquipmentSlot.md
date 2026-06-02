# GFEquipmentSlot

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/equipment/gf_equipment_slot.gd`
- 模块：`Domain`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用装备/挂载槽位。 槽位只记录可接受标签和已挂载 item_id，不规定装备类型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`slot_id`](#member-gfequipmentslot-properties-slot_id) | `var slot_id: StringName = &""` |
| 属性 | [`item_id`](#member-gfequipmentslot-properties-item_id) | `var item_id: StringName = &""` |
| 属性 | [`accepted_tags`](#member-gfequipmentslot-properties-accepted_tags) | `var accepted_tags: Array[StringName] = []` |
| 属性 | [`require_all_tags`](#member-gfequipmentslot-properties-require_all_tags) | `var require_all_tags: bool = false` |
| 属性 | [`metadata`](#member-gfequipmentslot-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`can_accept`](#member-gfequipmentslot-methods-can_accept) | `func can_accept(item_tags: Array[StringName]) -> bool:` |
| 方法 | [`equip`](#member-gfequipmentslot-methods-equip) | `func equip(p_item_id: StringName, item_tags: Array[StringName] = []) -> bool:` |
| 方法 | [`unequip`](#member-gfequipmentslot-methods-unequip) | `func unequip() -> void:` |

## 属性

<a id="member-gfequipmentslot-properties-slot_id"></a>

### `slot_id`

- API：`public`

```gdscript
var slot_id: StringName = &""
```

槽位 ID。

<a id="member-gfequipmentslot-properties-item_id"></a>

### `item_id`

- API：`public`

```gdscript
var item_id: StringName = &""
```

当前挂载的物品 ID。

<a id="member-gfequipmentslot-properties-accepted_tags"></a>

### `accepted_tags`

- API：`public`

```gdscript
var accepted_tags: Array[StringName] = []
```

接受的物品标签。为空表示不限制。

结构：

- `accepted_tags`: Array[StringName]，槽位接受的物品标签；为空时不限制。

<a id="member-gfequipmentslot-properties-require_all_tags"></a>

### `require_all_tags`

- API：`public`

```gdscript
var require_all_tags: bool = false
```

是否要求物品同时拥有全部 accepted_tags。false 表示拥有任一标签即可。

<a id="member-gfequipmentslot-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据。

结构：

- `metadata`: Dictionary，项目自定义槽位元数据；GF 不读取或改写其中字段。

## 方法

<a id="member-gfequipmentslot-methods-can_accept"></a>

### `can_accept`

- API：`public`

```gdscript
func can_accept(item_tags: Array[StringName]) -> bool:
```

检查标签是否可被槽位接受。

参数：

| 名称 | 说明 |
|---|---|
| `item_tags` | 物品标签。 |

返回：可接受时返回 true。

结构：

- `item_tags`: Array[StringName]，当前物品拥有的标签列表。

<a id="member-gfequipmentslot-methods-equip"></a>

### `equip`

- API：`public`

```gdscript
func equip(p_item_id: StringName, item_tags: Array[StringName] = []) -> bool:
```

挂载物品。

参数：

| 名称 | 说明 |
|---|---|
| `p_item_id` | 物品 ID。 |
| `item_tags` | 物品标签。 |

返回：成功时返回 true。

结构：

- `item_tags`: Array[StringName]，当前物品拥有的标签列表。

<a id="member-gfequipmentslot-methods-unequip"></a>

### `unequip`

- API：`public`

```gdscript
func unequip() -> void:
```

清空槽位。
