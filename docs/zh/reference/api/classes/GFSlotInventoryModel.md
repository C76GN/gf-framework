# GFSlotInventoryModel

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_slot_inventory_model.gd`
- 模块：`Domain`
- 继承：`GFModel`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用可序列化槽位库存模型。 管理固定或可增长槽位中的 `GFInventoryStack`，支持槽位接收规则、 堆叠容量、最大堆叠数量、实例数据兼容性、移动、交换和序列化。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`slot_changed`](#member-gfslotinventorymodel-signals-slot_changed) | `signal slot_changed(slot_index: int)` |
| 信号 | [`slot_state_changed`](#member-gfslotinventorymodel-signals-slot_state_changed) | `signal slot_state_changed(slot_index: int, before_stack_data: Dictionary, after_stack_data: Dictionary)` |
| 信号 | [`slot_filled`](#member-gfslotinventorymodel-signals-slot_filled) | `signal slot_filled(slot_index: int, stack_data: Dictionary)` |
| 信号 | [`slot_emptied`](#member-gfslotinventorymodel-signals-slot_emptied) | `signal slot_emptied(slot_index: int, previous_stack_data: Dictionary)` |
| 信号 | [`item_added`](#member-gfslotinventorymodel-signals-item_added) | `signal item_added(slot_index: int, item_id: StringName, amount: int)` |
| 信号 | [`item_removed`](#member-gfslotinventorymodel-signals-item_removed) | `signal item_removed(slot_index: int, item_id: StringName, amount: int)` |
| 信号 | [`inventory_changed`](#member-gfslotinventorymodel-signals-inventory_changed) | `signal inventory_changed` |
| 属性 | [`registry`](#member-gfslotinventorymodel-properties-registry) | `var registry: GFInventoryItemRegistry = null` |
| 属性 | [`slot_definitions`](#member-gfslotinventorymodel-properties-slot_definitions) | `var slot_definitions: Array[GFInventorySlotDefinition] = []` |
| 属性 | [`allow_growth`](#member-gfslotinventorymodel-properties-allow_growth) | `var allow_growth: bool = false` |
| 属性 | [`default_slot_count`](#member-gfslotinventorymodel-properties-default_slot_count) | `var default_slot_count: int = 0` |
| 方法 | [`set_registry`](#member-gfslotinventorymodel-methods-set_registry) | `func set_registry(item_registry: GFInventoryItemRegistry) -> void:` |
| 方法 | [`set_slot_count`](#member-gfslotinventorymodel-methods-set_slot_count) | `func set_slot_count(count: int, preserve_existing: bool = true) -> void:` |
| 方法 | [`get_slot_count`](#member-gfslotinventorymodel-methods-get_slot_count) | `func get_slot_count() -> int:` |
| 方法 | [`is_valid_slot`](#member-gfslotinventorymodel-methods-is_valid_slot) | `func is_valid_slot(slot_index: int) -> bool:` |
| 方法 | [`set_slot_definition`](#member-gfslotinventorymodel-methods-set_slot_definition) | `func set_slot_definition(slot_index: int, definition: GFInventorySlotDefinition) -> bool:` |
| 方法 | [`get_slot_definition`](#member-gfslotinventorymodel-methods-get_slot_definition) | `func get_slot_definition(slot_index: int) -> GFInventorySlotDefinition:` |
| 方法 | [`can_accept_item_at_slot`](#member-gfslotinventorymodel-methods-can_accept_item_at_slot) | `func can_accept_item_at_slot( slot_index: int, item_id: StringName, instance_data: Dictionary = {} ) -> bool:` |
| 方法 | [`get_stack`](#member-gfslotinventorymodel-methods-get_stack) | `func get_stack(slot_index: int) -> GFInventoryStack:` |
| 方法 | [`get_stack_data`](#member-gfslotinventorymodel-methods-get_stack_data) | `func get_stack_data(slot_index: int) -> Dictionary:` |
| 方法 | [`is_slot_empty`](#member-gfslotinventorymodel-methods-is_slot_empty) | `func is_slot_empty(slot_index: int) -> bool:` |
| 方法 | [`set_stack`](#member-gfslotinventorymodel-methods-set_stack) | `func set_stack(slot_index: int, stack: GFInventoryStack) -> bool:` |
| 方法 | [`clear_slot`](#member-gfslotinventorymodel-methods-clear_slot) | `func clear_slot(slot_index: int) -> bool:` |
| 方法 | [`clear`](#member-gfslotinventorymodel-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_item`](#member-gfslotinventorymodel-methods-add_item) | `func add_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {}, start_slot: int = -1, partial_add: bool = true ) -> GFInventoryOperationResult:` |
| 方法 | [`add_item_to_slot`](#member-gfslotinventorymodel-methods-add_item_to_slot) | `func add_item_to_slot( slot_index: int, item_id: StringName, amount: int = 1, instance_data: Dictionary = {} ) -> GFInventoryOperationResult:` |
| 方法 | [`remove_item`](#member-gfslotinventorymodel-methods-remove_item) | `func remove_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {}, start_slot: int = -1, partial_remove: bool = true ) -> GFInventoryOperationResult:` |
| 方法 | [`remove_item_from_slot`](#member-gfslotinventorymodel-methods-remove_item_from_slot) | `func remove_item_from_slot(slot_index: int, amount: int = 1) -> GFInventoryOperationResult:` |
| 方法 | [`swap_slots`](#member-gfslotinventorymodel-methods-swap_slots) | `func swap_slots(first_slot: int, second_slot: int) -> bool:` |
| 方法 | [`sort_slots`](#member-gfslotinventorymodel-methods-sort_slots) | `func sort_slots(order_resolver: Callable = Callable()) -> bool:` |
| 方法 | [`move_between_slots`](#member-gfslotinventorymodel-methods-move_between_slots) | `func move_between_slots(source_slot: int, target_slot: int, amount: int = 0) -> GFInventoryOperationResult:` |
| 方法 | [`get_item_total`](#member-gfslotinventorymodel-methods-get_item_total) | `func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:` |
| 方法 | [`has_item`](#member-gfslotinventorymodel-methods-has_item) | `func has_item(item_id: StringName, amount: int = 1, instance_data: Dictionary = {}) -> bool:` |
| 方法 | [`get_remaining_capacity_for_item`](#member-gfslotinventorymodel-methods-get_remaining_capacity_for_item) | `func get_remaining_capacity_for_item(item_id: StringName, instance_data: Dictionary = {}) -> int:` |
| 方法 | [`get_empty_slot_indices`](#member-gfslotinventorymodel-methods-get_empty_slot_indices) | `func get_empty_slot_indices() -> PackedInt32Array:` |
| 方法 | [`get_occupied_slot_indices`](#member-gfslotinventorymodel-methods-get_occupied_slot_indices) | `func get_occupied_slot_indices() -> PackedInt32Array:` |
| 方法 | [`get_slots_for_item`](#member-gfslotinventorymodel-methods-get_slots_for_item) | `func get_slots_for_item(item_id: StringName, instance_data: Dictionary = {}) -> PackedInt32Array:` |
| 方法 | [`rebuild_index`](#member-gfslotinventorymodel-methods-rebuild_index) | `func rebuild_index() -> void:` |
| 方法 | [`get_index_debug_snapshot`](#member-gfslotinventorymodel-methods-get_index_debug_snapshot) | `func get_index_debug_snapshot() -> Dictionary:` |
| 方法 | [`validate_inventory`](#member-gfslotinventorymodel-methods-validate_inventory) | `func validate_inventory() -> Dictionary:` |
| 方法 | [`apply_registry_constraints`](#member-gfslotinventorymodel-methods-apply_registry_constraints) | `func apply_registry_constraints(repair: bool = false) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfslotinventorymodel-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfslotinventorymodel-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfslotinventorymodel-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |

## 信号

<a id="member-gfslotinventorymodel-signals-slot_changed"></a>

### `slot_changed`

- API：`public`

```gdscript
signal slot_changed(slot_index: int)
```

任意槽位变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 变化的槽位索引。 |

<a id="member-gfslotinventorymodel-signals-slot_state_changed"></a>

### `slot_state_changed`

- API：`public`

```gdscript
signal slot_state_changed(slot_index: int, before_stack_data: Dictionary, after_stack_data: Dictionary)
```

槽位内容变化时发出，并携带变化前后的稳定快照。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 变化的槽位索引。 |
| `before_stack_data` | 变化前的槽位堆叠字典；空槽为 `{}`。 |
| `after_stack_data` | 变化后的槽位堆叠字典；空槽为 `{}`。 |

结构：

- `before_stack_data`: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽为空字典。
- `after_stack_data`: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽为空字典。

<a id="member-gfslotinventorymodel-signals-slot_filled"></a>

### `slot_filled`

- API：`public`

```gdscript
signal slot_filled(slot_index: int, stack_data: Dictionary)
```

槽位从空变为有内容时发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 变化的槽位索引。 |
| `stack_data` | 新写入的槽位堆叠字典。 |

结构：

- `stack_data`: Dictionary，GFInventoryStack.to_dict() 形状的新堆叠快照。

<a id="member-gfslotinventorymodel-signals-slot_emptied"></a>

### `slot_emptied`

- API：`public`

```gdscript
signal slot_emptied(slot_index: int, previous_stack_data: Dictionary)
```

槽位从有内容变为空时发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 变化的槽位索引。 |
| `previous_stack_data` | 清空前的槽位堆叠字典。 |

结构：

- `previous_stack_data`: Dictionary，GFInventoryStack.to_dict() 形状的清空前堆叠快照。

<a id="member-gfslotinventorymodel-signals-item_added"></a>

### `item_added`

- API：`public`

```gdscript
signal item_added(slot_index: int, item_id: StringName, amount: int)
```

物品加入槽位后发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 物品加入的槽位索引。 |
| `item_id` | 加入的物品 ID。 |
| `amount` | 实际加入数量。 |

<a id="member-gfslotinventorymodel-signals-item_removed"></a>

### `item_removed`

- API：`public`

```gdscript
signal item_removed(slot_index: int, item_id: StringName, amount: int)
```

物品从槽位移除后发出。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 物品移除的槽位索引。 |
| `item_id` | 移除的物品 ID。 |
| `amount` | 实际移除数量。 |

<a id="member-gfslotinventorymodel-signals-inventory_changed"></a>

### `inventory_changed`

- API：`public`

```gdscript
signal inventory_changed
```

库存整体发生变化时发出。

## 属性

<a id="member-gfslotinventorymodel-properties-registry"></a>

### `registry`

- API：`public`

```gdscript
var registry: GFInventoryItemRegistry = null
```

可选物品定义注册表。

<a id="member-gfslotinventorymodel-properties-slot_definitions"></a>

### `slot_definitions`

- API：`public`

```gdscript
var slot_definitions: Array[GFInventorySlotDefinition] = []
```

可选槽位定义。索引与库存槽位一致；空项表示该槽位不添加额外接收限制。

结构：

- `slot_definitions`: Array[GFInventorySlotDefinition]，按槽位索引存放的接收规则；空项表示不限制。

<a id="member-gfslotinventorymodel-properties-allow_growth"></a>

### `allow_growth`

- API：`public`

```gdscript
var allow_growth: bool = false
```

是否允许库存在创建新堆叠时自动增长。 为 false 时，0 槽位库存不会接收 `add_item()` 的新堆叠。

<a id="member-gfslotinventorymodel-properties-default_slot_count"></a>

### `default_slot_count`

- API：`public`

```gdscript
var default_slot_count: int = 0
```

默认初始槽位数量。仅在 GF 生命周期调用 `init()` 时自动应用。 手动创建后直接使用时，应调用 `set_slot_count()` 或启用 `allow_growth`。

## 方法

<a id="member-gfslotinventorymodel-methods-set_registry"></a>

### `set_registry`

- API：`public`

```gdscript
func set_registry(item_registry: GFInventoryItemRegistry) -> void:
```

设置物品注册表。

参数：

| 名称 | 说明 |
|---|---|
| `item_registry` | 物品注册表。 |

<a id="member-gfslotinventorymodel-methods-set_slot_count"></a>

### `set_slot_count`

- API：`public`

```gdscript
func set_slot_count(count: int, preserve_existing: bool = true) -> void:
```

设置槽位数量。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 新槽位数量。 |
| `preserve_existing` | 是否保留已有槽位内容。 |

<a id="member-gfslotinventorymodel-methods-get_slot_count"></a>

### `get_slot_count`

- API：`public`

```gdscript
func get_slot_count() -> int:
```

获取槽位数量。

返回：槽位数量。

<a id="member-gfslotinventorymodel-methods-is_valid_slot"></a>

### `is_valid_slot`

- API：`public`

```gdscript
func is_valid_slot(slot_index: int) -> bool:
```

检查槽位索引是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：有效返回 true。

<a id="member-gfslotinventorymodel-methods-set_slot_definition"></a>

### `set_slot_definition`

- API：`public`

```gdscript
func set_slot_definition(slot_index: int, definition: GFInventorySlotDefinition) -> bool:
```

设置槽位定义。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `definition` | 槽位定义；传 null 表示清除该槽位额外规则。 |

返回：成功返回 true。

<a id="member-gfslotinventorymodel-methods-get_slot_definition"></a>

### `get_slot_definition`

- API：`public`

```gdscript
func get_slot_definition(slot_index: int) -> GFInventorySlotDefinition:
```

获取槽位定义。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：槽位定义；无额外规则或无效槽位返回 null。

<a id="member-gfslotinventorymodel-methods-can_accept_item_at_slot"></a>

### `can_accept_item_at_slot`

- API：`public`

```gdscript
func can_accept_item_at_slot( slot_index: int, item_id: StringName, instance_data: Dictionary = {} ) -> bool:
```

检查指定物品是否可被槽位接收。 该方法只检查全局注册表与槽位定义，不判断当前槽位是否为空、 是否可与已有堆叠合并或是否有剩余容量。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `item_id` | 物品标识。 |
| `instance_data` | 实例数据。 |

返回：槽位可接收该物品时返回 true。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；会先经注册表规范化。

<a id="member-gfslotinventorymodel-methods-get_stack"></a>

### `get_stack`

- API：`public`

```gdscript
func get_stack(slot_index: int) -> GFInventoryStack:
```

获取槽位堆叠副本。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：堆叠副本；空槽或无效槽位返回 null。

<a id="member-gfslotinventorymodel-methods-get_stack_data"></a>

### `get_stack_data`

- API：`public`

```gdscript
func get_stack_data(slot_index: int) -> Dictionary:
```

获取槽位堆叠字典。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：堆叠字典；空槽或无效槽位返回空字典。

结构：

- `return`: Dictionary，GFInventoryStack.to_dict() 形状的槽位快照；空槽或无效槽位为空字典。

<a id="member-gfslotinventorymodel-methods-is_slot_empty"></a>

### `is_slot_empty`

- API：`public`

```gdscript
func is_slot_empty(slot_index: int) -> bool:
```

检查槽位是否为空。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：空槽位返回 true。

<a id="member-gfslotinventorymodel-methods-set_stack"></a>

### `set_stack`

- API：`public`

```gdscript
func set_stack(slot_index: int, stack: GFInventoryStack) -> bool:
```

设置指定槽位堆叠。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `stack` | 堆叠；传 null 表示清空。 |

返回：成功返回 true。

<a id="member-gfslotinventorymodel-methods-clear_slot"></a>

### `clear_slot`

- API：`public`

```gdscript
func clear_slot(slot_index: int) -> bool:
```

清空指定槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：成功返回 true。

<a id="member-gfslotinventorymodel-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空全部槽位内容。

<a id="member-gfslotinventorymodel-methods-add_item"></a>

### `add_item`

- API：`public`

```gdscript
func add_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {}, start_slot: int = -1, partial_add: bool = true ) -> GFInventoryOperationResult:
```

添加物品到库存。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `amount` | 添加数量。 |
| `instance_data` | 实例数据。 |
| `start_slot` | 起始槽位；小于 0 时从头开始。 |
| `partial_add` | 容量不足时是否允许部分加入。 |

返回：操作结果。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；会先经注册表规范化。

<a id="member-gfslotinventorymodel-methods-add_item_to_slot"></a>

### `add_item_to_slot`

- API：`public`

```gdscript
func add_item_to_slot( slot_index: int, item_id: StringName, amount: int = 1, instance_data: Dictionary = {} ) -> GFInventoryOperationResult:
```

添加物品到指定槽位。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `item_id` | 物品标识。 |
| `amount` | 添加数量。 |
| `instance_data` | 实例数据。 |

返回：操作结果。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；会先经注册表规范化。

<a id="member-gfslotinventorymodel-methods-remove_item"></a>

### `remove_item`

- API：`public`

```gdscript
func remove_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {}, start_slot: int = -1, partial_remove: bool = true ) -> GFInventoryOperationResult:
```

从库存移除物品。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `amount` | 移除数量。 |
| `instance_data` | 实例数据。 |
| `start_slot` | 起始槽位；小于 0 时从头开始。 |
| `partial_remove` | 数量不足时是否允许部分移除。 |

返回：操作结果。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；为空时匹配全部同 ID 物品。

<a id="member-gfslotinventorymodel-methods-remove_item_from_slot"></a>

### `remove_item_from_slot`

- API：`public`

```gdscript
func remove_item_from_slot(slot_index: int, amount: int = 1) -> GFInventoryOperationResult:
```

从指定槽位移除物品。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |
| `amount` | 移除数量。 |

返回：操作结果。

<a id="member-gfslotinventorymodel-methods-swap_slots"></a>

### `swap_slots`

- API：`public`

```gdscript
func swap_slots(first_slot: int, second_slot: int) -> bool:
```

交换两个槽位内容。

参数：

| 名称 | 说明 |
|---|---|
| `first_slot` | 第一个槽位。 |
| `second_slot` | 第二个槽位。 |

返回：成功返回 true。

<a id="member-gfslotinventorymodel-methods-sort_slots"></a>

### `sort_slots`

- API：`public`

```gdscript
func sort_slots(order_resolver: Callable = Callable()) -> bool:
```

按排序规则重排槽位内容。 默认排序把非空槽位排在前面，再按 item_id 和原槽位索引稳定排序。 可传入回调覆盖本次排序，或继承并重写 `_should_sort_slot_before()`。

参数：

| 名称 | 说明 |
|---|---|
| `order_resolver` | 可选比较回调，签名为 `func(left_slot_index, left_stack_data, right_slot_index, right_stack_data) -> bool`。 |

返回：槽位顺序发生变化时返回 true。

<a id="member-gfslotinventorymodel-methods-move_between_slots"></a>

### `move_between_slots`

- API：`public`

```gdscript
func move_between_slots(source_slot: int, target_slot: int, amount: int = 0) -> GFInventoryOperationResult:
```

移动一个槽位的内容到另一个槽位，目标为空时移动，兼容时合并。

参数：

| 名称 | 说明 |
|---|---|
| `source_slot` | 源槽位。 |
| `target_slot` | 目标槽位。 |
| `amount` | 移动数量；小于等于 0 时移动全部。 |

返回：操作结果。

<a id="member-gfslotinventorymodel-methods-get_item_total"></a>

### `get_item_total`

- API：`public`

```gdscript
func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:
```

获取指定物品总数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 实例数据。为空时统计全部同 ID 物品。 |

返回：总数量。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；为空时统计全部同 ID 物品。

<a id="member-gfslotinventorymodel-methods-has_item"></a>

### `has_item`

- API：`public`

```gdscript
func has_item(item_id: StringName, amount: int = 1, instance_data: Dictionary = {}) -> bool:
```

检查是否拥有足够数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `amount` | 需要数量。 |
| `instance_data` | 实例数据。 |

返回：数量足够返回 true。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；为空时统计全部同 ID 物品。

<a id="member-gfslotinventorymodel-methods-get_remaining_capacity_for_item"></a>

### `get_remaining_capacity_for_item`

- API：`public`

```gdscript
func get_remaining_capacity_for_item(item_id: StringName, instance_data: Dictionary = {}) -> int:
```

获取指定物品剩余可加入容量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 实例数据。 |

返回：剩余容量。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；用于筛选可合并堆叠。

<a id="member-gfslotinventorymodel-methods-get_empty_slot_indices"></a>

### `get_empty_slot_indices`

- API：`public`

```gdscript
func get_empty_slot_indices() -> PackedInt32Array:
```

获取空槽位索引。

返回：空槽位索引数组。

<a id="member-gfslotinventorymodel-methods-get_occupied_slot_indices"></a>

### `get_occupied_slot_indices`

- API：`public`

```gdscript
func get_occupied_slot_indices() -> PackedInt32Array:
```

获取已占用槽位索引。

返回：已占用槽位索引数组。

<a id="member-gfslotinventorymodel-methods-get_slots_for_item"></a>

### `get_slots_for_item`

- API：`public`

```gdscript
func get_slots_for_item(item_id: StringName, instance_data: Dictionary = {}) -> PackedInt32Array:
```

获取指定物品所在槽位索引。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 实例数据。为空时返回全部同 ID 槽位。 |

返回：槽位索引列表。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据；为空时返回全部同 ID 槽位。

<a id="member-gfslotinventorymodel-methods-rebuild_index"></a>

### `rebuild_index`

- API：`public`

```gdscript
func rebuild_index() -> void:
```

立即重建物品到槽位的索引。

<a id="member-gfslotinventorymodel-methods-get_index_debug_snapshot"></a>

### `get_index_debug_snapshot`

- API：`public`

```gdscript
func get_index_debug_snapshot() -> Dictionary:
```

获取索引调试快照。

返回：索引快照字典。

结构：

- `return`: Dictionary，包含 dirty: bool、item_count: int、stack_count_by_item: Dictionary 与 slot_indices_by_item: Dictionary。

<a id="member-gfslotinventorymodel-methods-validate_inventory"></a>

### `validate_inventory`

- API：`public`

```gdscript
func validate_inventory() -> Dictionary:
```

校验当前库存内容是否满足注册表约束。

返回：校验报告字典。

结构：

- `return`: Dictionary，包含 ok、healthy、summary、next_action、issue_count 与 issues；issues 每项包含 severity、kind、slot_index、item_id 与 message。

<a id="member-gfslotinventorymodel-methods-apply_registry_constraints"></a>

### `apply_registry_constraints`

- API：`public`

```gdscript
func apply_registry_constraints(repair: bool = false) -> Dictionary:
```

应用注册表约束并返回报告。

参数：

| 名称 | 说明 |
|---|---|
| `repair` | 为 true 时会移除不合法堆叠并裁剪超过上限的数量。 |

返回：校验报告字典。

结构：

- `return`: Dictionary，包含 ok、healthy、summary、next_action、issue_count 与 issues；repair 为 true 时会同步修复可修复堆叠。

<a id="member-gfslotinventorymodel-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取库存调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 slot_count、occupied_slot_count、empty_slot_count、allow_growth、items 与 index。

<a id="member-gfslotinventorymodel-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

序列化为字典。

返回：可序列化字典。

结构：

- `return`: Dictionary，包含 slot_count、allow_growth 与 slots；slots 每项为 GFInventoryStack.to_dict() 形状或空字典。

<a id="member-gfslotinventorymodel-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 序列化数据。 |

结构：

- `data`: Dictionary，包含 slot_count、allow_growth 与 slots；slots 每项为 GFInventoryStack.to_dict() 形状或空字典。
