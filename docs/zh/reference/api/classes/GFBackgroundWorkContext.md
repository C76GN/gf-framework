# GFBackgroundWorkContext

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_background_work_context.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

CPU/IO worker 的线程安全只读协作取消句柄。 Utility 为已接纳的 CPU/IO work record 建立并由 Task 持有。 opt-in 时作为 worker 第二参数；无需 release，终态、clear、dispose 后仍可读且不延长 Utility/线程寿命。 自行 new() 得到未绑定对象，不能作为取消入口。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CancellationReason`](#member-gfbackgroundworkcontext-enums-cancellationreason) | `enum CancellationReason` |
| 方法 | [`get_work_id`](#member-gfbackgroundworkcontext-methods-get_work_id) | `func get_work_id() -> StringName:` |
| 方法 | [`is_cancel_requested`](#member-gfbackgroundworkcontext-methods-is_cancel_requested) | `func is_cancel_requested() -> bool:` |
| 方法 | [`get_cancel_reason`](#member-gfbackgroundworkcontext-methods-get_cancel_reason) | `func get_cancel_reason() -> CancellationReason:` |
| 方法 | [`get_cancel_requested_msec`](#member-gfbackgroundworkcontext-methods-get_cancel_requested_msec) | `func get_cancel_requested_msec() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfbackgroundworkcontext-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`cancellation_reason_name`](#member-gfbackgroundworkcontext-methods-cancellation_reason_name) | `static func cancellation_reason_name(reason: CancellationReason) -> String:` |

## 枚举

<a id="member-gfbackgroundworkcontext-enums-cancellationreason"></a>

### `CancellationReason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum CancellationReason {
	## 尚未请求取消。
	NONE = 0,
	## cancel_work() 请求取消。
	CANCEL_WORK = 1,
	## cancel_all() 请求取消。
	CANCEL_ALL = 2,
	## clear_all() 请求取消并清空任务。
	CLEAR_ALL = 3,
	## GFBackgroundWorkUtility.dispose() 请求取消。
	UTILITY_DISPOSED = 4,
}
```

框架拥有的稳定取消原因。

## 方法

<a id="member-gfbackgroundworkcontext-methods-get_work_id"></a>

### `get_work_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_work_id() -> StringName:
```

返回所属工作的稳定 ID。

返回：建立上下文时从 work record 冻结的工作 ID。

<a id="member-gfbackgroundworkcontext-methods-is_cancel_requested"></a>

### `is_cancel_requested`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_cancel_requested() -> bool:
```

返回是否已经收到取消请求。

返回：已请求取消时返回 true。

<a id="member-gfbackgroundworkcontext-methods-get_cancel_reason"></a>

### `get_cancel_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancel_reason() -> CancellationReason:
```

返回稳定取消原因。

返回：首次取消请求提供的原因；未取消时为 NONE。

<a id="member-gfbackgroundworkcontext-methods-get_cancel_requested_msec"></a>

### `get_cancel_requested_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancel_requested_msec() -> int:
```

返回首次取消请求发生时的 Time.get_ticks_msec()。

返回：首次取消请求的毫秒 tick；未取消时为 0。

<a id="member-gfbackgroundworkcontext-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取纯数据取消状态快照。

返回：同一锁采样的取消状态快照。

结构：

- `return`: Dictionary，精确包含 work_id: String、cancel_requested: bool、cancel_reason: int、cancel_reason_name: String 和 cancel_requested_msec: int。

<a id="member-gfbackgroundworkcontext-methods-cancellation_reason_name"></a>

### `cancellation_reason_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func cancellation_reason_name(reason: CancellationReason) -> String:
```

获取取消原因名称。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：稳定的小写原因名称。
