# GFInventoryReadView

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_read_view.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

槽位接收回调的临时只读库存投影。 库存模型与原子转移规划器会为每次槽位接收检查创建此视图。查询反映 当前逐步候选，因而后续槽位可观察此前写入；视图不暴露可变库存引用。 回调返回后视图立即失效，项目不得跨回调保存并依赖它。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_active`](#member-gfinventoryreadview-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_slot_count`](#member-gfinventoryreadview-methods-get_slot_count) | `func get_slot_count() -> int:` |
| 方法 | [`is_valid_slot`](#member-gfinventoryreadview-methods-is_valid_slot) | `func is_valid_slot(slot_index: int) -> bool:` |
| 方法 | [`get_stack`](#member-gfinventoryreadview-methods-get_stack) | `func get_stack(slot_index: int) -> GFInventoryStack:` |
| 方法 | [`get_stack_data`](#member-gfinventoryreadview-methods-get_stack_data) | `func get_stack_data(slot_index: int) -> Dictionary:` |
| 方法 | [`is_slot_empty`](#member-gfinventoryreadview-methods-is_slot_empty) | `func is_slot_empty(slot_index: int) -> bool:` |
| 方法 | [`get_item_total`](#member-gfinventoryreadview-methods-get_item_total) | `func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:` |
| 方法 | [`has_item`](#member-gfinventoryreadview-methods-has_item) | `func has_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {} ) -> bool:` |
| 方法 | [`get_empty_slot_indices`](#member-gfinventoryreadview-methods-get_empty_slot_indices) | `func get_empty_slot_indices() -> PackedInt32Array:` |
| 方法 | [`get_occupied_slot_indices`](#member-gfinventoryreadview-methods-get_occupied_slot_indices) | `func get_occupied_slot_indices() -> PackedInt32Array:` |
| 方法 | [`get_slots_for_item`](#member-gfinventoryreadview-methods-get_slots_for_item) | `func get_slots_for_item( item_id: StringName, instance_data: Dictionary = {} ) -> PackedInt32Array:` |

## 方法

<a id="member-gfinventoryreadview-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

检查视图是否仍处于当前同步接收回调内。

返回：仍可查询时返回 true；回调返回后为 false。

<a id="member-gfinventoryreadview-methods-get_slot_count"></a>

### `get_slot_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_slot_count() -> int:
```

获取候选槽位数量。

返回：当前候选槽位数量；失效后返回 0。

<a id="member-gfinventoryreadview-methods-is_valid_slot"></a>

### `is_valid_slot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_valid_slot(slot_index: int) -> bool:
```

检查候选槽位索引是否有效。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：视图有效且索引存在时返回 true。

<a id="member-gfinventoryreadview-methods-get_stack"></a>

### `get_stack`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stack(slot_index: int) -> GFInventoryStack:
```

获取候选堆叠的隔离副本。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：候选堆叠副本；空槽、无效索引或失效视图返回 null。

<a id="member-gfinventoryreadview-methods-get_stack_data"></a>

### `get_stack_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_stack_data(slot_index: int) -> Dictionary:
```

获取候选堆叠字典快照。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：候选堆叠字典；空槽、无效索引或失效视图返回空字典。

结构：

- `return`: Dictionary，包含 item_id、amount 与 instance_data。

<a id="member-gfinventoryreadview-methods-is_slot_empty"></a>

### `is_slot_empty`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_slot_empty(slot_index: int) -> bool:
```

检查候选槽位是否为空。

参数：

| 名称 | 说明 |
|---|---|
| `slot_index` | 槽位索引。 |

返回：空槽返回 true；无效索引或失效视图也返回 true。

<a id="member-gfinventoryreadview-methods-get_item_total"></a>

### `get_item_total`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_item_total(item_id: StringName, instance_data: Dictionary = {}) -> int:
```

获取候选中指定物品总数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 可选实例数据过滤条件；空字典匹配全部同 ID 堆叠。 |

返回：候选总数量；失效视图返回 0。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。

<a id="member-gfinventoryreadview-methods-has_item"></a>

### `has_item`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_item( item_id: StringName, amount: int = 1, instance_data: Dictionary = {} ) -> bool:
```

检查候选中是否拥有足够数量。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `amount` | 需要数量。 |
| `instance_data` | 可选实例数据过滤条件。 |

返回：数量足够返回 true。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。

<a id="member-gfinventoryreadview-methods-get_empty_slot_indices"></a>

### `get_empty_slot_indices`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_empty_slot_indices() -> PackedInt32Array:
```

获取候选空槽位索引。

返回：空槽位索引；失效视图返回空数组。

<a id="member-gfinventoryreadview-methods-get_occupied_slot_indices"></a>

### `get_occupied_slot_indices`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_occupied_slot_indices() -> PackedInt32Array:
```

获取候选已占用槽位索引。

返回：已占用槽位索引；失效视图返回空数组。

<a id="member-gfinventoryreadview-methods-get_slots_for_item"></a>

### `get_slots_for_item`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_slots_for_item( item_id: StringName, instance_data: Dictionary = {} ) -> PackedInt32Array:
```

获取候选中指定物品所在槽位。

参数：

| 名称 | 说明 |
|---|---|
| `item_id` | 物品标识。 |
| `instance_data` | 可选实例数据过滤条件；空字典匹配全部同 ID 堆叠。 |

返回：匹配槽位索引；失效视图返回空数组。

结构：

- `instance_data`: Dictionary，项目自定义物品实例数据。
