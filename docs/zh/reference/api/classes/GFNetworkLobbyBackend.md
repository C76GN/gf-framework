# GFNetworkLobbyBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_backend.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

平台中立 Lobby 后端协议。 后端只负责把 Steam、小游戏、自建匹配服、LAN 或其他 provider 的异步调用 映射到强类型操作句柄。请求 ID、单终态、取消和迟到回调保护由基类统一拥有。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`lobby_updated`](#member-gfnetworklobbybackend-signals-lobby_updated) | `signal lobby_updated(lobby: GFNetworkLobbyDescriptor)` |
| 信号 | [`member_joined`](#member-gfnetworklobbybackend-signals-member_joined) | `signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)` |
| 信号 | [`member_left`](#member-gfnetworklobbybackend-signals-member_left) | `signal member_left(lobby_id: String, peer_id: int, reason: String)` |
| 信号 | [`invite_received`](#member-gfnetworklobbybackend-signals-invite_received) | `signal invite_received(invite: GFNetworkLobbyInvite)` |
| 信号 | [`backend_error`](#member-gfnetworklobbybackend-signals-backend_error) | `signal backend_error(operation: StringName, error: StringName, details: Dictionary)` |
| 属性 | [`backend_id`](#member-gfnetworklobbybackend-properties-backend_id) | `var backend_id: StringName = &""` |
| 方法 | [`invoke_operation`](#member-gfnetworklobbybackend-methods-invoke_operation) | `func invoke_operation( request: GFNetworkLobbyOperationRequest ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`poll`](#member-gfnetworklobbybackend-methods-poll) | `func poll(delta: float) -> void:` |
| 方法 | [`close`](#member-gfnetworklobbybackend-methods-close) | `func close() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbybackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_dispatch_operation`](#member-gfnetworklobbybackend-methods-_dispatch_operation) | `func _dispatch_operation( _request: GFNetworkLobbyOperationRequest, _handle: GFNetworkLobbyOperationHandle ) -> bool:` |
| 方法 | [`_cancel_operation`](#member-gfnetworklobbybackend-methods-_cancel_operation) | `func _cancel_operation( _handle: GFNetworkLobbyOperationHandle, _reason: StringName ) -> void:` |
| 方法 | [`_release_operation`](#member-gfnetworklobbybackend-methods-_release_operation) | `func _release_operation(handle: GFNetworkLobbyOperationHandle) -> bool:` |
| 方法 | [`_poll`](#member-gfnetworklobbybackend-methods-_poll) | `func _poll(_delta: float) -> void:` |
| 方法 | [`_close`](#member-gfnetworklobbybackend-methods-_close) | `func _close() -> void:` |
| 方法 | [`_succeed_operation`](#member-gfnetworklobbybackend-methods-_succeed_operation) | `func _succeed_operation( handle: GFNetworkLobbyOperationHandle, options: Dictionary = {} ) -> bool:` |
| 方法 | [`_fail_operation`](#member-gfnetworklobbybackend-methods-_fail_operation) | `func _fail_operation( handle: GFNetworkLobbyOperationHandle, error: StringName, message: String = "", metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`_emit_lobby_updated`](#member-gfnetworklobbybackend-methods-_emit_lobby_updated) | `func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:` |
| 方法 | [`_emit_member_joined`](#member-gfnetworklobbybackend-methods-_emit_member_joined) | `func _emit_member_joined( lobby_id: String, member: GFNetworkLobbyMember ) -> void:` |
| 方法 | [`_emit_member_left`](#member-gfnetworklobbybackend-methods-_emit_member_left) | `func _emit_member_left( lobby_id: String, peer_id: int, reason: String = "left" ) -> void:` |
| 方法 | [`_emit_invite_received`](#member-gfnetworklobbybackend-methods-_emit_invite_received) | `func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:` |
| 方法 | [`_emit_backend_error`](#member-gfnetworklobbybackend-methods-_emit_backend_error) | `func _emit_backend_error( operation: StringName, error: StringName, details: Dictionary = {} ) -> void:` |

## 信号

<a id="member-gfnetworklobbybackend-signals-lobby_updated"></a>

### `lobby_updated`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_updated(lobby: GFNetworkLobbyDescriptor)
```

Lobby 快照发生非请求驱动的更新后发出。

参数：

| 名称 | 说明 |
|---|---|
| `lobby` | Lobby 快照。 |

<a id="member-gfnetworklobbybackend-signals-member_joined"></a>

### `member_joined`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)
```

成员加入后发出。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `member` | 成员快照。 |

<a id="member-gfnetworklobbybackend-signals-member_left"></a>

### `member_left`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal member_left(lobby_id: String, peer_id: int, reason: String)
```

成员离开后发出。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `peer_id` | 成员 peer ID。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-signals-invite_received"></a>

### `invite_received`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal invite_received(invite: GFNetworkLobbyInvite)
```

收到 Lobby 邀请后发出。

参数：

| 名称 | 说明 |
|---|---|
| `invite` | 邀请事件。 |

<a id="member-gfnetworklobbybackend-signals-backend_error"></a>

### `backend_error`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal backend_error(operation: StringName, error: StringName, details: Dictionary)
```

后端出现不属于具体请求的错误时发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `details` | 已脱敏错误详情。 |

结构：

- `details`: Dictionary backend-defined error metadata.

## 属性

<a id="member-gfnetworklobbybackend-properties-backend_id"></a>

### `backend_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var backend_id: StringName = &""
```

后端稳定标识。

## 方法

<a id="member-gfnetworklobbybackend-methods-invoke_operation"></a>

### `invoke_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func invoke_operation( request: GFNetworkLobbyOperationRequest ) -> GFNetworkLobbyOperationHandle:
```

提交 Lobby 操作。 外部 Adapter 不得重写该入口，只实现 `_dispatch_operation`。基类会在调用 provider 前建立取消与完成监听，保证同步回调也不会逃逸生命周期管理。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 完整操作请求。 |

返回：一次性操作句柄；输入和派发失败也返回终态句柄。

<a id="member-gfnetworklobbybackend-methods-poll"></a>

### `poll`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func poll(delta: float) -> void:
```

推进需要 callback pump 的平台 SDK。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 未缩放帧间隔。 |

<a id="member-gfnetworklobbybackend-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func close() -> void:
```

取消全部等待操作并关闭 provider 资源。

<a id="member-gfnetworklobbybackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：不包含请求载荷的后端摘要。

结构：

- `return`: Dictionary lobby backend debug snapshot.

<a id="member-gfnetworklobbybackend-methods-_dispatch_operation"></a>

### `_dispatch_operation`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _dispatch_operation( _request: GFNetworkLobbyOperationRequest, _handle: GFNetworkLobbyOperationHandle ) -> bool:
```

派发 provider 操作。 实现应保存 request_id 与底层调用的关联，并在回调中调用 `_succeed_operation` 或 `_fail_operation`。返回 false 表示请求未被接受。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 请求副本。 |
| `_handle` | 由基类拥有的操作句柄。 |

返回：请求被 provider 接受时返回 true。

<a id="member-gfnetworklobbybackend-methods-_cancel_operation"></a>

### `_cancel_operation`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _cancel_operation( _handle: GFNetworkLobbyOperationHandle, _reason: StringName ) -> void:
```

处理取消或超时通知。

参数：

| 名称 | 说明 |
|---|---|
| `_handle` | 已进入取消或超时终态的句柄。 |
| `_reason` | 取消原因。 |

<a id="member-gfnetworklobbybackend-methods-_release_operation"></a>

### `_release_operation`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _release_operation(handle: GFNetworkLobbyOperationHandle) -> bool:
```

确认底层 Provider 操作已经停止并释放请求租约。 Handle 本地取消或超时不会提前释放 request_id。Backend 应在 Provider 确认 取消后调用本方法；迟到成功或失败回调会自动释放。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 底层工作已经停止的操作句柄。 |

返回：当前 Backend 仍持有该租约并已释放时返回 true。

<a id="member-gfnetworklobbybackend-methods-_poll"></a>

### `_poll`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _poll(_delta: float) -> void:
```

推进底层 callback pump。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 未缩放帧间隔。 |

<a id="member-gfnetworklobbybackend-methods-_close"></a>

### `_close`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _close() -> void:
```

释放底层 provider 资源。

<a id="member-gfnetworklobbybackend-methods-_succeed_operation"></a>

### `_succeed_operation`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _succeed_operation( handle: GFNetworkLobbyOperationHandle, options: Dictionary = {} ) -> bool:
```

成功完成操作。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待完成句柄。 |
| `options` | 可包含 status、lobby、lobbies、lobby_id 和 metadata。 |

返回：首次完成成功返回 true；迟到或重复回调返回 false。

结构：

- `options`: Dictionary successful lobby operation fields.

<a id="member-gfnetworklobbybackend-methods-_fail_operation"></a>

### `_fail_operation`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _fail_operation( handle: GFNetworkLobbyOperationHandle, error: StringName, message: String = "", metadata: Dictionary = {} ) -> bool:
```

失败完成操作。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待完成句柄。 |
| `error` | 稳定失败原因。 |
| `message` | 人读说明。 |
| `metadata` | 已脱敏失败元数据。 |

返回：首次完成成功返回 true；迟到或重复回调返回 false。

结构：

- `metadata`: Dictionary backend-defined failure metadata.

<a id="member-gfnetworklobbybackend-methods-_emit_lobby_updated"></a>

### `_emit_lobby_updated`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
```

发出 Lobby 更新事件。

参数：

| 名称 | 说明 |
|---|---|
| `lobby` | Lobby 快照。 |

<a id="member-gfnetworklobbybackend-methods-_emit_member_joined"></a>

### `_emit_member_joined`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_member_joined( lobby_id: String, member: GFNetworkLobbyMember ) -> void:
```

发出成员加入事件。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `member` | 成员快照。 |

<a id="member-gfnetworklobbybackend-methods-_emit_member_left"></a>

### `_emit_member_left`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_member_left( lobby_id: String, peer_id: int, reason: String = "left" ) -> void:
```

发出成员离开事件。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `peer_id` | 成员 peer ID。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-methods-_emit_invite_received"></a>

### `_emit_invite_received`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:
```

发出邀请事件。

参数：

| 名称 | 说明 |
|---|---|
| `invite` | 邀请事件。 |

<a id="member-gfnetworklobbybackend-methods-_emit_backend_error"></a>

### `_emit_backend_error`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_backend_error( operation: StringName, error: StringName, details: Dictionary = {} ) -> void:
```

发出非请求错误事件。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `details` | 已脱敏错误详情。 |

结构：

- `details`: Dictionary backend-defined error metadata.
