# GFVirtualListSyncResult

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/ui/gf_virtual_list_sync_result.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`11.0.0`

虚拟列表同步的不可变诊断结果。 只保存范围、计数、版本和稳定错误信息，不保存项目条目数据或原始稳定 ID。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_SYNCED`](#member-gfvirtuallistsyncresult-constants-status_synced) | `const STATUS_SYNCED: StringName = &"synced"` |
| 常量 | [`STATUS_UNCHANGED`](#member-gfvirtuallistsyncresult-constants-status_unchanged) | `const STATUS_UNCHANGED: StringName = &"unchanged"` |
| 常量 | [`STATUS_DEFERRED`](#member-gfvirtuallistsyncresult-constants-status_deferred) | `const STATUS_DEFERRED: StringName = &"deferred"` |
| 常量 | [`STATUS_TRUNCATED`](#member-gfvirtuallistsyncresult-constants-status_truncated) | `const STATUS_TRUNCATED: StringName = &"truncated"` |
| 常量 | [`STATUS_UNBOUND`](#member-gfvirtuallistsyncresult-constants-status_unbound) | `const STATUS_UNBOUND: StringName = &"unbound"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfvirtuallistsyncresult-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 常量 | [`STATUS_INVALID_IDENTITY`](#member-gfvirtuallistsyncresult-constants-status_invalid_identity) | `const STATUS_INVALID_IDENTITY: StringName = &"invalid_identity"` |
| 常量 | [`STATUS_DUPLICATE_IDENTITY`](#member-gfvirtuallistsyncresult-constants-status_duplicate_identity) | `const STATUS_DUPLICATE_IDENTITY: StringName = &"duplicate_identity"` |
| 常量 | [`STATUS_FACTORY_FAILED`](#member-gfvirtuallistsyncresult-constants-status_factory_failed) | `const STATUS_FACTORY_FAILED: StringName = &"factory_failed"` |
| 常量 | [`STATUS_BIND_FAILED`](#member-gfvirtuallistsyncresult-constants-status_bind_failed) | `const STATUS_BIND_FAILED: StringName = &"bind_failed"` |
| 方法 | [`is_successful`](#member-gfvirtuallistsyncresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfvirtuallistsyncresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_layout_revision`](#member-gfvirtuallistsyncresult-methods-get_layout_revision) | `func get_layout_revision() -> int:` |
| 方法 | [`get_data_revision`](#member-gfvirtuallistsyncresult-methods-get_data_revision) | `func get_data_revision() -> int:` |
| 方法 | [`get_viewport_range`](#member-gfvirtuallistsyncresult-methods-get_viewport_range) | `func get_viewport_range() -> Vector2i:` |
| 方法 | [`get_requested_range`](#member-gfvirtuallistsyncresult-methods-get_requested_range) | `func get_requested_range() -> Vector2i:` |
| 方法 | [`get_materialized_indices`](#member-gfvirtuallistsyncresult-methods-get_materialized_indices) | `func get_materialized_indices() -> PackedInt32Array:` |
| 方法 | [`get_materialized_count`](#member-gfvirtuallistsyncresult-methods-get_materialized_count) | `func get_materialized_count() -> int:` |
| 方法 | [`get_pooled_count`](#member-gfvirtuallistsyncresult-methods-get_pooled_count) | `func get_pooled_count() -> int:` |
| 方法 | [`get_created_count`](#member-gfvirtuallistsyncresult-methods-get_created_count) | `func get_created_count() -> int:` |
| 方法 | [`get_reused_count`](#member-gfvirtuallistsyncresult-methods-get_reused_count) | `func get_reused_count() -> int:` |
| 方法 | [`get_released_count`](#member-gfvirtuallistsyncresult-methods-get_released_count) | `func get_released_count() -> int:` |
| 方法 | [`get_measured_count`](#member-gfvirtuallistsyncresult-methods-get_measured_count) | `func get_measured_count() -> int:` |
| 方法 | [`get_anchor_adjustment`](#member-gfvirtuallistsyncresult-methods-get_anchor_adjustment) | `func get_anchor_adjustment() -> float:` |
| 方法 | [`was_truncated`](#member-gfvirtuallistsyncresult-methods-was_truncated) | `func was_truncated() -> bool:` |
| 方法 | [`get_error_index`](#member-gfvirtuallistsyncresult-methods-get_error_index) | `func get_error_index() -> int:` |
| 方法 | [`get_error`](#member-gfvirtuallistsyncresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`duplicate_result`](#member-gfvirtuallistsyncresult-methods-duplicate_result) | `func duplicate_result() -> GFVirtualListSyncResult:` |
| 方法 | [`to_dict`](#member-gfvirtuallistsyncresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfvirtuallistsyncresult-constants-status_synced"></a>

### `STATUS_SYNCED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_SYNCED: StringName = &"synced"
```

目标范围已完整同步。

<a id="member-gfvirtuallistsyncresult-constants-status_unchanged"></a>

### `STATUS_UNCHANGED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_UNCHANGED: StringName = &"unchanged"
```

当前 materialization 已满足目标且没有结构变化。

<a id="member-gfvirtuallistsyncresult-constants-status_deferred"></a>

### `STATUS_DEFERRED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_DEFERRED: StringName = &"deferred"
```

当前轮冻结快照在完成提交前或项目绑定副作用期间失效；Binder 已保留后续同步请求。 该状态不表示同步成功。若漂移发生在绑定副作用前，Binder 保留最近一次可信 materialization；若已调用 bind/unbind、测量、布局或焦点副作用，则对称解绑并清空 不可信 materialization。调用方应以结果中的当前索引为准并等待下一轮结果。

<a id="member-gfvirtuallistsyncresult-constants-status_truncated"></a>

### `STATUS_TRUNCATED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_TRUNCATED: StringName = &"truncated"
```

目标范围超过显式节点预算，已优先物化真实视口范围。

<a id="member-gfvirtuallistsyncresult-constants-status_unbound"></a>

### `STATUS_UNBOUND`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_UNBOUND: StringName = &"unbound"
```

Binder 当前没有有效绑定。

<a id="member-gfvirtuallistsyncresult-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

Binder 已进入不可复用的终态。

<a id="member-gfvirtuallistsyncresult-constants-status_invalid_identity"></a>

### `STATUS_INVALID_IDENTITY`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_INVALID_IDENTITY: StringName = &"invalid_identity"
```

identity callback 返回了不可稳定编码的值。

<a id="member-gfvirtuallistsyncresult-constants-status_duplicate_identity"></a>

### `STATUS_DUPLICATE_IDENTITY`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_DUPLICATE_IDENTITY: StringName = &"duplicate_identity"
```

当前请求范围包含重复稳定 identity。

<a id="member-gfvirtuallistsyncresult-constants-status_factory_failed"></a>

### `STATUS_FACTORY_FAILED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_FACTORY_FAILED: StringName = &"factory_failed"
```

item factory 没有返回可接管的 parentless Control。

<a id="member-gfvirtuallistsyncresult-constants-status_bind_failed"></a>

### `STATUS_BIND_FAILED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATUS_BIND_FAILED: StringName = &"bind_failed"
```

项目 bind callback 拒绝了一个条目。

## 方法

<a id="member-gfvirtuallistsyncresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_successful() -> bool:
```

检查同步是否提交了内部一致的目标状态。

返回：完整、无变化或按显式预算截断完成时返回 true。

<a id="member-gfvirtuallistsyncresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_status() -> StringName:
```

获取稳定同步状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfvirtuallistsyncresult-methods-get_layout_revision"></a>

### `get_layout_revision`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_layout_revision() -> int:
```

获取本轮计算范围前冻结的布局版本。

返回：`GFVirtualListModel` revision。

<a id="member-gfvirtuallistsyncresult-methods-get_data_revision"></a>

### `get_data_revision`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_data_revision() -> int:
```

获取本轮开始时冻结的 Binder 数据失效版本。

返回：从 0 开始的 data revision。

<a id="member-gfvirtuallistsyncresult-methods-get_viewport_range"></a>

### `get_viewport_range`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_viewport_range() -> Vector2i:
```

获取未加入 overscan 的真实视口范围。

返回：Vector2i(start, end)，end 不包含。

<a id="member-gfvirtuallistsyncresult-methods-get_requested_range"></a>

### `get_requested_range`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_requested_range() -> Vector2i:
```

获取加入 overscan、应用预算前的请求范围。

返回：Vector2i(start, end)，end 不包含。

<a id="member-gfvirtuallistsyncresult-methods-get_materialized_indices"></a>

### `get_materialized_indices`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_materialized_indices() -> PackedInt32Array:
```

获取实际物化索引副本。

返回：升序物化索引。

<a id="member-gfvirtuallistsyncresult-methods-get_materialized_count"></a>

### `get_materialized_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_materialized_count() -> int:
```

获取实际物化数量。

返回：当前活动 Control 数量。

<a id="member-gfvirtuallistsyncresult-methods-get_pooled_count"></a>

### `get_pooled_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_pooled_count() -> int:
```

获取当前池内可复用 Control 数量。

返回：parentless 池节点数量。

<a id="member-gfvirtuallistsyncresult-methods-get_created_count"></a>

### `get_created_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_created_count() -> int:
```

获取本轮新建 Control 数量。

返回：factory 成功创建数量。

<a id="member-gfvirtuallistsyncresult-methods-get_reused_count"></a>

### `get_reused_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reused_count() -> int:
```

获取本轮从旧 active 或 pool 复用数量。

返回：复用数量。

<a id="member-gfvirtuallistsyncresult-methods-get_released_count"></a>

### `get_released_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_released_count() -> int:
```

获取本轮离开旧绑定的数量。

返回：已执行 unbind 的旧绑定数量。

<a id="member-gfvirtuallistsyncresult-methods-get_measured_count"></a>

### `get_measured_count`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_measured_count() -> int:
```

获取本轮成功测量的行数量。

返回：测量数量。

<a id="member-gfvirtuallistsyncresult-methods-get_anchor_adjustment"></a>

### `get_anchor_adjustment`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_anchor_adjustment() -> float:
```

获取本轮一次性应用的滚动锚点修正。

返回：主轴滚动调整量。

<a id="member-gfvirtuallistsyncresult-methods-was_truncated"></a>

### `was_truncated`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func was_truncated() -> bool:
```

检查是否因 materialization 上限截断。

返回：目标范围未完整物化时返回 true。

<a id="member-gfvirtuallistsyncresult-methods-get_error_index"></a>

### `get_error_index`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error_index() -> int:
```

获取首个失败条目索引。

返回：没有索引错误时为 -1。

<a id="member-gfvirtuallistsyncresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_error() -> String:
```

获取有界稳定错误说明。

返回：成功时为空。

<a id="member-gfvirtuallistsyncresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func duplicate_result() -> GFVirtualListSyncResult:
```

创建结果的隔离副本。

返回：新结果对象。

<a id="member-gfvirtuallistsyncresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为不含项目数据的诊断字典。

返回：JSON-safe 同步摘要；状态使用 String，范围与索引只使用 JSON 原生容器和整数。

结构：

- `return`: Dictionary with String status; viewport_range and requested_range Dictionaries containing start and end_exclusive ints; materialized_indices Array[int]; revisions and counts in 0..9007199254740991; finite anchor_adjustment; truncated; error_index in -1..9007199254740991; and error.
