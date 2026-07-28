# GFNetworkLobbyOperationHandle

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_operation_handle.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`10.0.0`

Lobby 操作运行时句柄。 句柄保证请求只能进入一个终态，并把取消、超时、Backend 失败和 SDK 回调统一为 `GFNetworkLobbyOperationResult`。调用方不能直接完成句柄。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfnetworklobbyoperationhandle-signals-completed) | `signal completed(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`cancel_requested`](#member-gfnetworklobbyoperationhandle-signals-cancel_requested) | `signal cancel_requested(reason: StringName)` |
| 方法 | [`get_request`](#member-gfnetworklobbyoperationhandle-methods-get_request) | `func get_request() -> GFNetworkLobbyOperationRequest:` |
| 方法 | [`get_request_id`](#member-gfnetworklobbyoperationhandle-methods-get_request_id) | `func get_request_id() -> StringName:` |
| 方法 | [`is_pending`](#member-gfnetworklobbyoperationhandle-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfnetworklobbyoperationhandle-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfnetworklobbyoperationhandle-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_result`](#member-gfnetworklobbyoperationhandle-methods-get_result) | `func get_result() -> GFNetworkLobbyOperationResult:` |
| 方法 | [`cancel`](#member-gfnetworklobbyoperationhandle-methods-cancel) | `func cancel(reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbyoperationhandle-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworklobbyoperationhandle-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal completed(result: GFNetworkLobbyOperationResult)
```

操作进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 终态结果副本。 |

<a id="member-gfnetworklobbyoperationhandle-signals-cancel_requested"></a>

### `cancel_requested`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal cancel_requested(reason: StringName)
```

操作取消或超时时发出，供 Backend 停止底层调用。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

## 方法

<a id="member-gfnetworklobbyoperationhandle-methods-get_request"></a>

### `get_request`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_request() -> GFNetworkLobbyOperationRequest:
```

获取请求副本。

返回：请求副本。

<a id="member-gfnetworklobbyoperationhandle-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_request_id() -> StringName:
```

获取请求 ID。

返回：请求 ID。

<a id="member-gfnetworklobbyoperationhandle-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_pending() -> bool:
```

检查操作是否仍在等待终态。

返回：等待中返回 true。

<a id="member-gfnetworklobbyoperationhandle-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_completed() -> bool:
```

检查操作是否已经完成。

返回：已有终态结果时返回 true。

<a id="member-gfnetworklobbyoperationhandle-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查操作是否成功。

返回：终态存在且成功时返回 true。

<a id="member-gfnetworklobbyoperationhandle-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_result() -> GFNetworkLobbyOperationResult:
```

获取终态结果副本。

返回：终态结果副本；等待中返回 null。

<a id="member-gfnetworklobbyoperationhandle-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled") -> bool:
```

取消操作。 取消立即成为本地终态。Backend 会先收到 cancel_requested，但迟到 SDK 回调不能覆盖结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |

返回：首次取消成功返回 true。

<a id="member-gfnetworklobbyoperationhandle-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取稳定调试快照。

返回：请求和终态摘要。

结构：

- `return`: Dictionary lobby operation handle snapshot.
