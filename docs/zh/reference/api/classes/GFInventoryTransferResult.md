# GFInventoryTransferResult

[API Reference](../index.md) / [Domain](../extensions-domain.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/domain/inventory/gf_inventory_transfer_result.gd`
- 模块：`Domain`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

槽位库存转移的类型化阶段结果。 结果只保存事务状态、稳定身份、数量与 revision，不保留库存模型或候选堆叠。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_PREPARED`](#member-gfinventorytransferresult-constants-status_prepared) | `const STATUS_PREPARED: StringName = &"prepared"` |
| 常量 | [`STATUS_COMMITTED`](#member-gfinventorytransferresult-constants-status_committed) | `const STATUS_COMMITTED: StringName = &"committed"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfinventorytransferresult-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_BUSY`](#member-gfinventorytransferresult-constants-status_busy) | `const STATUS_BUSY: StringName = &"busy"` |
| 常量 | [`STATUS_NOT_ENOUGH_ITEMS`](#member-gfinventorytransferresult-constants-status_not_enough_items) | `const STATUS_NOT_ENOUGH_ITEMS: StringName = &"not_enough_items"` |
| 常量 | [`STATUS_NOT_ENOUGH_SPACE`](#member-gfinventorytransferresult-constants-status_not_enough_space) | `const STATUS_NOT_ENOUGH_SPACE: StringName = &"not_enough_space"` |
| 常量 | [`STATUS_UNSUPPORTED_DATA`](#member-gfinventorytransferresult-constants-status_unsupported_data) | `const STATUS_UNSUPPORTED_DATA: StringName = &"unsupported_data"` |
| 常量 | [`STATUS_STALE_REVISION`](#member-gfinventorytransferresult-constants-status_stale_revision) | `const STATUS_STALE_REVISION: StringName = &"stale_revision"` |
| 常量 | [`STATUS_STALE_PLAN`](#member-gfinventorytransferresult-constants-status_stale_plan) | `const STATUS_STALE_PLAN: StringName = &"stale_plan"` |
| 方法 | [`is_successful`](#member-gfinventorytransferresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfinventorytransferresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_item_id`](#member-gfinventorytransferresult-methods-get_item_id) | `func get_item_id() -> StringName:` |
| 方法 | [`get_requested_amount`](#member-gfinventorytransferresult-methods-get_requested_amount) | `func get_requested_amount() -> int:` |
| 方法 | [`get_transferred_amount`](#member-gfinventorytransferresult-methods-get_transferred_amount) | `func get_transferred_amount() -> int:` |
| 方法 | [`get_remaining_amount`](#member-gfinventorytransferresult-methods-get_remaining_amount) | `func get_remaining_amount() -> int:` |
| 方法 | [`get_source_slot`](#member-gfinventorytransferresult-methods-get_source_slot) | `func get_source_slot() -> int:` |
| 方法 | [`get_target_slot`](#member-gfinventorytransferresult-methods-get_target_slot) | `func get_target_slot() -> int:` |
| 方法 | [`get_source_revision`](#member-gfinventorytransferresult-methods-get_source_revision) | `func get_source_revision() -> int:` |
| 方法 | [`get_target_revision`](#member-gfinventorytransferresult-methods-get_target_revision) | `func get_target_revision() -> int:` |
| 方法 | [`duplicate_result`](#member-gfinventorytransferresult-methods-duplicate_result) | `func duplicate_result() -> GFInventoryTransferResult:` |
| 方法 | [`to_dict`](#member-gfinventorytransferresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfinventorytransferresult-constants-status_prepared"></a>

### `STATUS_PREPARED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_PREPARED: StringName = &"prepared"
```

已完成隔离规划，可尝试提交。

<a id="member-gfinventorytransferresult-constants-status_committed"></a>

### `STATUS_COMMITTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_COMMITTED: StringName = &"committed"
```

两个库存已完成原子内存提交；不表示库存通知已经派发完毕。

<a id="member-gfinventorytransferresult-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

请求参数、模型身份或槽位无效。

<a id="member-gfinventorytransferresult-constants-status_busy"></a>

### `STATUS_BUSY`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_BUSY: StringName = &"busy"
```

模型正在处理其他变更或通知，无法取得协调锁。

<a id="member-gfinventorytransferresult-constants-status_not_enough_items"></a>

### `STATUS_NOT_ENOUGH_ITEMS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_NOT_ENOUGH_ITEMS: StringName = &"not_enough_items"
```

来源槽位没有可转移堆叠或请求数量超过来源且不允许部分转移。

<a id="member-gfinventorytransferresult-constants-status_not_enough_space"></a>

### `STATUS_NOT_ENOUGH_SPACE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_NOT_ENOUGH_SPACE: StringName = &"not_enough_space"
```

目标容量不足或目标槽位拒绝物品。

<a id="member-gfinventorytransferresult-constants-status_unsupported_data"></a>

### `STATUS_UNSUPPORTED_DATA`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_UNSUPPORTED_DATA: StringName = &"unsupported_data"
```

实例数据或规则数据包含不支持、循环或超预算的结构。

<a id="member-gfinventorytransferresult-constants-status_stale_revision"></a>

### `STATUS_STALE_REVISION`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_STALE_REVISION: StringName = &"stale_revision"
```

模型 identity 或 revision 在 prepare 后发生变化。

<a id="member-gfinventorytransferresult-constants-status_stale_plan"></a>

### `STATUS_STALE_PLAN`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_STALE_PLAN: StringName = &"stale_plan"
```

重新规划结果与 prepare 阶段绑定的计划摘要不同。

## 方法

<a id="member-gfinventorytransferresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查结果是否表示可继续的成功阶段。

返回：状态为 prepared 或 committed 时返回 true。

<a id="member-gfinventorytransferresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfinventorytransferresult-methods-get_item_id"></a>

### `get_item_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_item_id() -> StringName:
```

获取物品标识。

返回：转移物品 ID；请求尚未识别物品时为空。

<a id="member-gfinventorytransferresult-methods-get_requested_amount"></a>

### `get_requested_amount`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_requested_amount() -> int:
```

获取本次规划请求处理的数量。

返回：非负请求数量。

<a id="member-gfinventorytransferresult-methods-get_transferred_amount"></a>

### `get_transferred_amount`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_transferred_amount() -> int:
```

获取规划或提交的实际转移数量。

返回：非负转移数量。

<a id="member-gfinventorytransferresult-methods-get_remaining_amount"></a>

### `get_remaining_amount`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_remaining_amount() -> int:
```

获取未转移数量。

返回：请求数量减去实际转移数量。

<a id="member-gfinventorytransferresult-methods-get_source_slot"></a>

### `get_source_slot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_slot() -> int:
```

获取来源槽位。

返回：来源槽位索引；无有效槽位时为 -1。

<a id="member-gfinventorytransferresult-methods-get_target_slot"></a>

### `get_target_slot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_slot() -> int:
```

获取显式目标槽位。

返回：显式目标槽位索引；自动选择时为 -1。

<a id="member-gfinventorytransferresult-methods-get_source_revision"></a>

### `get_source_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_revision() -> int:
```

获取结果绑定的来源 revision。

返回：非负 revision；无有效来源时为 -1。

<a id="member-gfinventorytransferresult-methods-get_target_revision"></a>

### `get_target_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_target_revision() -> int:
```

获取结果绑定的目标 revision。

返回：非负 revision；无有效目标时为 -1。

<a id="member-gfinventorytransferresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFInventoryTransferResult:
```

创建隔离结果副本。

返回：不共享可变集合的新结果。

<a id="member-gfinventorytransferresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为稳定字典。

返回：只含状态、物品、数量、槽位与 revision 的字典。

结构：

- `return`: Dictionary with status, ok, item_id, requested_amount, transferred_amount, remaining_amount, source_slot, target_slot, source_revision, and target_revision.
