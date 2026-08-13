# GFObjectPoolPrewarmOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_prewarm_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次异步对象池预热请求句柄。 Operation 冻结请求身份并跟踪最终有效的容量准入和实时进度，只接受一个类型化终态。同步校验、 零工作或同步退化请求可能在入口返回前完成；调用方应先查询 `is_completed()`。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`progressed`](#member-gfobjectpoolprewarmoperation-signals-progressed) | `signal progressed(operation: GFObjectPoolPrewarmOperation)` |
| 信号 | [`completed`](#member-gfobjectpoolprewarmoperation-signals-completed) | `signal completed(result: GFObjectPoolPrewarmResult)` |
| 方法 | [`cancel`](#member-gfobjectpoolprewarmoperation-methods-cancel) | `func cancel() -> bool:` |
| 方法 | [`get_request_id`](#member-gfobjectpoolprewarmoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`get_scene`](#member-gfobjectpoolprewarmoperation-methods-get_scene) | `func get_scene() -> PackedScene:` |
| 方法 | [`get_scene_identity`](#member-gfobjectpoolprewarmoperation-methods-get_scene_identity) | `func get_scene_identity() -> String:` |
| 方法 | [`is_pending`](#member-gfobjectpoolprewarmoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfobjectpoolprewarmoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_requested_count`](#member-gfobjectpoolprewarmoperation-methods-get_requested_count) | `func get_requested_count() -> int:` |
| 方法 | [`get_admitted_count`](#member-gfobjectpoolprewarmoperation-methods-get_admitted_count) | `func get_admitted_count() -> int:` |
| 方法 | [`get_created_count`](#member-gfobjectpoolprewarmoperation-methods-get_created_count) | `func get_created_count() -> int:` |
| 方法 | [`get_skipped_count`](#member-gfobjectpoolprewarmoperation-methods-get_skipped_count) | `func get_skipped_count() -> int:` |
| 方法 | [`get_cancelled_count`](#member-gfobjectpoolprewarmoperation-methods-get_cancelled_count) | `func get_cancelled_count() -> int:` |
| 方法 | [`get_failed_count`](#member-gfobjectpoolprewarmoperation-methods-get_failed_count) | `func get_failed_count() -> int:` |
| 方法 | [`get_processed_count`](#member-gfobjectpoolprewarmoperation-methods-get_processed_count) | `func get_processed_count() -> int:` |
| 方法 | [`get_remaining_count`](#member-gfobjectpoolprewarmoperation-methods-get_remaining_count) | `func get_remaining_count() -> int:` |
| 方法 | [`get_progress_ratio`](#member-gfobjectpoolprewarmoperation-methods-get_progress_ratio) | `func get_progress_ratio() -> float:` |
| 方法 | [`get_result`](#member-gfobjectpoolprewarmoperation-methods-get_result) | `func get_result() -> GFObjectPoolPrewarmResult:` |
| 方法 | [`get_debug_snapshot`](#member-gfobjectpoolprewarmoperation-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfobjectpoolprewarmoperation-signals-progressed"></a>

### `progressed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal progressed(operation: GFObjectPoolPrewarmOperation)
```

已处理数量增加时发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 当前规范 Operation。 |

<a id="member-gfobjectpoolprewarmoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFObjectPoolPrewarmResult)
```

请求进入唯一终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 当前请求的隔离终态结果。 |

## 方法

<a id="member-gfobjectpoolprewarmoperation-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> bool:
```

取消等待中的请求。

返回：Utility 首次接受 caller 取消时返回 true。

<a id="member-gfobjectpoolprewarmoperation-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Utility 内唯一请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfobjectpoolprewarmoperation-methods-get_scene"></a>

### `get_scene`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_scene() -> PackedScene:
```

获取仍存活的 PackedScene。

返回：请求场景；已释放时返回 null。

<a id="member-gfobjectpoolprewarmoperation-methods-get_scene_identity"></a>

### `get_scene_identity`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_scene_identity() -> String:
```

获取冻结的场景身份。

返回：资源路径或实例 ID 身份。

<a id="member-gfobjectpoolprewarmoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍等待终态。

返回：已配置且未完成时返回 true。

<a id="member-gfobjectpoolprewarmoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查请求是否已经进入终态。

返回：已完成时返回 true。

<a id="member-gfobjectpoolprewarmoperation-methods-get_requested_count"></a>

### `get_requested_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_requested_count() -> int:
```

获取请求数量。

返回：非负请求数量。

<a id="member-gfobjectpoolprewarmoperation-methods-get_admitted_count"></a>

### `get_admitted_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_admitted_count() -> int:
```

获取当前有效的容量准入数量。

返回：非负且不大于 requested 的数量；运行期容量复核可在终态前减少该值。

<a id="member-gfobjectpoolprewarmoperation-methods-get_created_count"></a>

### `get_created_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_created_count() -> int:
```

获取成功创建数量。

返回：已提交节点数量。

<a id="member-gfobjectpoolprewarmoperation-methods-get_skipped_count"></a>

### `get_skipped_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_skipped_count() -> int:
```

获取未获准入或因运行期容量复核而跳过的数量。

返回：`requested - admitted`。

<a id="member-gfobjectpoolprewarmoperation-methods-get_cancelled_count"></a>

### `get_cancelled_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancelled_count() -> int:
```

获取取消数量。

返回：当前已归类取消的单位数。

<a id="member-gfobjectpoolprewarmoperation-methods-get_failed_count"></a>

### `get_failed_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_failed_count() -> int:
```

获取失败数量。

返回：当前已归类失败的单位数。

<a id="member-gfobjectpoolprewarmoperation-methods-get_processed_count"></a>

### `get_processed_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_processed_count() -> int:
```

获取已处理数量。

返回：created、skipped、cancelled 与 failed 的总和。

<a id="member-gfobjectpoolprewarmoperation-methods-get_remaining_count"></a>

### `get_remaining_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_remaining_count() -> int:
```

获取尚未进入 disposition 的数量。

返回：`requested - processed`。

<a id="member-gfobjectpoolprewarmoperation-methods-get_progress_ratio"></a>

### `get_progress_ratio`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_progress_ratio() -> float:
```

获取标准化进度。

返回：0.0 到 1.0；零工作为 1.0。

<a id="member-gfobjectpoolprewarmoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFObjectPoolPrewarmResult:
```

获取终态结果副本。

返回：已完成结果；等待中返回 null。

<a id="member-gfobjectpoolprewarmoperation-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：请求身份、实时计数、进度和可选终态。

结构：

- `return`: Exact Dictionary with request_id, scene_identity, pending, completed, requested_count, admitted_count, created_count, skipped_count, cancelled_count, failed_count, processed_count, remaining_count, progress_ratio, and result fields.
