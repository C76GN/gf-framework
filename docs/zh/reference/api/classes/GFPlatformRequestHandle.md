# GFPlatformRequestHandle

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/platform/gf_platform_request_handle.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`9.0.0`

平台桥接请求运行时句柄。 句柄保证一次请求只进入一个终态，并把取消、超时和 adapter 返回统一为 `GFPlatformBridgeResult`。项目代码只读取句柄，不负责完成句柄。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfplatformrequesthandle-signals-completed) | `signal completed(result: GFPlatformBridgeResult)` |
| 信号 | [`cancel_requested`](#member-gfplatformrequesthandle-signals-cancel_requested) | `signal cancel_requested(reason: StringName)` |
| 方法 | [`get_request`](#member-gfplatformrequesthandle-methods-get_request) | `func get_request() -> GFPlatformBridgeRequest:` |
| 方法 | [`get_request_id`](#member-gfplatformrequesthandle-methods-get_request_id) | `func get_request_id() -> StringName:` |
| 方法 | [`is_pending`](#member-gfplatformrequesthandle-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfplatformrequesthandle-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfplatformrequesthandle-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_result`](#member-gfplatformrequesthandle-methods-get_result) | `func get_result() -> GFPlatformBridgeResult:` |
| 方法 | [`cancel`](#member-gfplatformrequesthandle-methods-cancel) | `func cancel(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfplatformrequesthandle-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfplatformrequesthandle-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal completed(result: GFPlatformBridgeResult)
```

请求进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 请求终态结果。 |

<a id="member-gfplatformrequesthandle-signals-cancel_requested"></a>

### `cancel_requested`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal cancel_requested(reason: StringName)
```

请求取消或超时时发出，供 adapter 停止底层调用。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

## 方法

<a id="member-gfplatformrequesthandle-methods-get_request"></a>

### `get_request`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_request() -> GFPlatformBridgeRequest:
```

获取请求数据副本。

返回：请求数据副本。

<a id="member-gfplatformrequesthandle-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_request_id() -> StringName:
```

获取请求 ID。

返回：请求 ID。

<a id="member-gfplatformrequesthandle-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍在等待终态。

返回：等待中返回 true。

<a id="member-gfplatformrequesthandle-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_completed() -> bool:
```

检查请求是否已经完成。

返回：已有终态结果时返回 true。

<a id="member-gfplatformrequesthandle-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_successful() -> bool:
```

检查请求是否成功。

返回：终态存在且成功时返回 true。

<a id="member-gfplatformrequesthandle-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_result() -> GFPlatformBridgeResult:
```

获取终态结果副本。

返回：终态结果副本；等待中返回 null。

<a id="member-gfplatformrequesthandle-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled") -> bool:
```

取消请求。 取消立即成为本地终态；adapter 会在 `completed` 前收到 `cancel_requested`， 但不能用迟到回调覆盖取消结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：首次取消成功返回 true。

<a id="member-gfplatformrequesthandle-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：包含 request、pending、completed、successful 和脱敏 result 的字典；失败只公开 status 与 has_error，不公开原始 error 或 metadata。

结构：

- `return`: Dictionary with request, pending, completed, successful, and redacted result fields.
