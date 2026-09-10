# GFNetworkRequestResult

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/runtime/gf_network_request_result.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

网络请求关联的一次性只读终态。 received 只表示收到匹配请求身份与 peer 的回复，不表示业务操作成功。 回复由关联器先完成有界传输值校验；结果保留隔离副本，读取时再次复制集合。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_RECEIVED`](#member-gfnetworkrequestresult-constants-status_received) | `const STATUS_RECEIVED: StringName = &"received"` |
| 常量 | [`STATUS_SEND_FAILED`](#member-gfnetworkrequestresult-constants-status_send_failed) | `const STATUS_SEND_FAILED: StringName = &"send_failed"` |
| 常量 | [`STATUS_TIMED_OUT`](#member-gfnetworkrequestresult-constants-status_timed_out) | `const STATUS_TIMED_OUT: StringName = &"timed_out"` |
| 常量 | [`STATUS_CANCELLED`](#member-gfnetworkrequestresult-constants-status_cancelled) | `const STATUS_CANCELLED: StringName = &"cancelled"` |
| 常量 | [`STATUS_SESSION_CLOSED`](#member-gfnetworkrequestresult-constants-status_session_closed) | `const STATUS_SESSION_CLOSED: StringName = &"session_closed"` |
| 常量 | [`STATUS_PEER_DISCONNECTED`](#member-gfnetworkrequestresult-constants-status_peer_disconnected) | `const STATUS_PEER_DISCONNECTED: StringName = &"peer_disconnected"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfnetworkrequestresult-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 常量 | [`STATUS_REJECTED`](#member-gfnetworkrequestresult-constants-status_rejected) | `const STATUS_REJECTED: StringName = &"rejected"` |
| 常量 | [`STATUS_INVALID_RESPONSE`](#member-gfnetworkrequestresult-constants-status_invalid_response) | `const STATUS_INVALID_RESPONSE: StringName = &"invalid_response"` |
| 方法 | [`get_request_id`](#member-gfnetworkrequestresult-methods-get_request_id) | `func get_request_id() -> String:` |
| 方法 | [`get_peer_id`](#member-gfnetworkrequestresult-methods-get_peer_id) | `func get_peer_id() -> int:` |
| 方法 | [`get_status`](#member-gfnetworkrequestresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`is_successful`](#member-gfnetworkrequestresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_response`](#member-gfnetworkrequestresult-methods-get_response) | `func get_response() -> Variant:` |
| 方法 | [`get_send_error`](#member-gfnetworkrequestresult-methods-get_send_error) | `func get_send_error() -> Error:` |

## 常量

<a id="member-gfnetworkrequestresult-constants-status_received"></a>

### `STATUS_RECEIVED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_RECEIVED: StringName = &"received"
```

已收到匹配的回复；不解释回复中的业务结果。

<a id="member-gfnetworkrequestresult-constants-status_send_failed"></a>

### `STATUS_SEND_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SEND_FAILED: StringName = &"send_failed"
```

发送入口返回错误，且请求尚未进入其他终态。

<a id="member-gfnetworkrequestresult-constants-status_timed_out"></a>

### `STATUS_TIMED_OUT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_TIMED_OUT: StringName = &"timed_out"
```

已达到本地单调截止时间。

<a id="member-gfnetworkrequestresult-constants-status_cancelled"></a>

### `STATUS_CANCELLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CANCELLED: StringName = &"cancelled"
```

调用方已取消本地等待；不代表服务器操作被撤销。

<a id="member-gfnetworkrequestresult-constants-status_session_closed"></a>

### `STATUS_SESSION_CLOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_SESSION_CLOSED: StringName = &"session_closed"
```

所属会话已关闭或被替换。

<a id="member-gfnetworkrequestresult-constants-status_peer_disconnected"></a>

### `STATUS_PEER_DISCONNECTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_PEER_DISCONNECTED: StringName = &"peer_disconnected"
```

目标 peer 的连接已失效。

<a id="member-gfnetworkrequestresult-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

所属关联器已释放或不再存在。

<a id="member-gfnetworkrequestresult-constants-status_rejected"></a>

### `STATUS_REJECTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_REJECTED: StringName = &"rejected"
```

请求未通过参数、会话或容量准入检查。

<a id="member-gfnetworkrequestresult-constants-status_invalid_response"></a>

### `STATUS_INVALID_RESPONSE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_RESPONSE: StringName = &"invalid_response"
```

匹配身份的回复未通过有界传输值校验。

## 方法

<a id="member-gfnetworkrequestresult-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> String:
```

获取关联请求 ID。

返回：请求 ID；尚未配置时为空。

<a id="member-gfnetworkrequestresult-methods-get_peer_id"></a>

### `get_peer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_peer_id() -> int:
```

获取请求绑定的目标 peer。

返回：请求的目标 peer；尚未配置时为 -1。

<a id="member-gfnetworkrequestresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定终态。

返回：STATUS_* 常量之一；尚未配置时为 STATUS_REJECTED。

<a id="member-gfnetworkrequestresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查是否收到匹配回复。

返回：已配置且状态为 received 时返回 true；不判断业务成功。

<a id="member-gfnetworkrequestresult-methods-get_response"></a>

### `get_response`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_response() -> Variant:
```

获取回复的隔离副本。

返回：回复副本；非 received 终态或尚未配置时为 null。

结构：

- `return`: Variant，由关联器校验的有界纯传输值；不含 Object、Callable、Signal、RID、循环容器或非有限数，集合深拷贝。

<a id="member-gfnetworkrequestresult-methods-get_send_error"></a>

### `get_send_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_send_error() -> Error:
```

获取发送或准入阶段的错误码。

返回：关联器记录的发送或准入错误码；请求未发送也可能携带拒绝原因，无错误时为 OK。
