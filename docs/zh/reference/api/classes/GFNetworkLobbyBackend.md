# GFNetworkLobbyBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_backend.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`8.0.0`

平台中立 lobby 后端协议。 后端负责把 Steam、微信、自建匹配服、LAN 发现或其他平台能力映射到 GF lobby 事件与请求报告。该基类不执行任何平台调用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`lobby_created`](#member-gfnetworklobbybackend-signals-lobby_created) | `signal lobby_created(result: GFNetworkLobbyJoinResult)` |
| 信号 | [`lobbies_queried`](#member-gfnetworklobbybackend-signals-lobbies_queried) | `signal lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary)` |
| 信号 | [`lobby_joined`](#member-gfnetworklobbybackend-signals-lobby_joined) | `signal lobby_joined(result: GFNetworkLobbyJoinResult)` |
| 信号 | [`lobby_left`](#member-gfnetworklobbybackend-signals-lobby_left) | `signal lobby_left(lobby_id: String, reason: String)` |
| 信号 | [`lobby_updated`](#member-gfnetworklobbybackend-signals-lobby_updated) | `signal lobby_updated(lobby: GFNetworkLobbyDescriptor)` |
| 信号 | [`member_joined`](#member-gfnetworklobbybackend-signals-member_joined) | `signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)` |
| 信号 | [`member_left`](#member-gfnetworklobbybackend-signals-member_left) | `signal member_left(lobby_id: String, peer_id: int, reason: String)` |
| 信号 | [`invite_received`](#member-gfnetworklobbybackend-signals-invite_received) | `signal invite_received(invite: GFNetworkLobbyInvite)` |
| 信号 | [`backend_error`](#member-gfnetworklobbybackend-signals-backend_error) | `signal backend_error(operation: StringName, error: StringName, details: Dictionary)` |
| 属性 | [`backend_id`](#member-gfnetworklobbybackend-properties-backend_id) | `var backend_id: StringName = &""` |
| 方法 | [`create_lobby`](#member-gfnetworklobbybackend-methods-create_lobby) | `func create_lobby(_options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`query_lobbies`](#member-gfnetworklobbybackend-methods-query_lobbies) | `func query_lobbies(_query: GFNetworkLobbyQuery = null, _options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`join_lobby`](#member-gfnetworklobbybackend-methods-join_lobby) | `func join_lobby(_lobby_id: String, _options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`leave_lobby`](#member-gfnetworklobbybackend-methods-leave_lobby) | `func leave_lobby(_lobby_id: String = "", _options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`set_lobby_metadata`](#member-gfnetworklobbybackend-methods-set_lobby_metadata) | `func set_lobby_metadata(_lobby_id: String, _metadata: Dictionary, _options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`set_member_metadata`](#member-gfnetworklobbybackend-methods-set_member_metadata) | `func set_member_metadata( _lobby_id: String, _peer_id: int, _metadata: Dictionary, _options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`poll`](#member-gfnetworklobbybackend-methods-poll) | `func poll(_delta: float) -> void:` |
| 方法 | [`close`](#member-gfnetworklobbybackend-methods-close) | `func close() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbybackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_make_request_report`](#member-gfnetworklobbybackend-methods-_make_request_report) | `func _make_request_report( ok: bool, operation: StringName, error: StringName = &"", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`_emit_lobby_created`](#member-gfnetworklobbybackend-methods-_emit_lobby_created) | `func _emit_lobby_created(result: GFNetworkLobbyJoinResult) -> void:` |
| 方法 | [`_emit_lobbies_queried`](#member-gfnetworklobbybackend-methods-_emit_lobbies_queried) | `func _emit_lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary = {}) -> void:` |
| 方法 | [`_emit_lobby_joined`](#member-gfnetworklobbybackend-methods-_emit_lobby_joined) | `func _emit_lobby_joined(result: GFNetworkLobbyJoinResult) -> void:` |
| 方法 | [`_emit_lobby_left`](#member-gfnetworklobbybackend-methods-_emit_lobby_left) | `func _emit_lobby_left(lobby_id: String, reason: String = "left") -> void:` |
| 方法 | [`_emit_lobby_updated`](#member-gfnetworklobbybackend-methods-_emit_lobby_updated) | `func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:` |
| 方法 | [`_emit_member_joined`](#member-gfnetworklobbybackend-methods-_emit_member_joined) | `func _emit_member_joined(lobby_id: String, member: GFNetworkLobbyMember) -> void:` |
| 方法 | [`_emit_member_left`](#member-gfnetworklobbybackend-methods-_emit_member_left) | `func _emit_member_left(lobby_id: String, peer_id: int, reason: String = "left") -> void:` |
| 方法 | [`_emit_invite_received`](#member-gfnetworklobbybackend-methods-_emit_invite_received) | `func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:` |
| 方法 | [`_emit_backend_error`](#member-gfnetworklobbybackend-methods-_emit_backend_error) | `func _emit_backend_error(operation: StringName, error: StringName, details: Dictionary = {}) -> void:` |

## 信号

<a id="member-gfnetworklobbybackend-signals-lobby_created"></a>

### `lobby_created`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_created(result: GFNetworkLobbyJoinResult)
```

Lobby 创建完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 创建结果。 |

<a id="member-gfnetworklobbybackend-signals-lobbies_queried"></a>

### `lobbies_queried`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary)
```

Lobby 查询完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `lobbies` | Lobby 快照列表。 |
| `metadata` | 查询元数据。 |

结构：

- `lobbies`: Array[GFNetworkLobbyDescriptor] lobby snapshots.
- `metadata`: Dictionary query metadata.

<a id="member-gfnetworklobbybackend-signals-lobby_joined"></a>

### `lobby_joined`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_joined(result: GFNetworkLobbyJoinResult)
```

Lobby 加入完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 加入结果。 |

<a id="member-gfnetworklobbybackend-signals-lobby_left"></a>

### `lobby_left`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_left(lobby_id: String, reason: String)
```

离开 lobby 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-signals-lobby_updated"></a>

### `lobby_updated`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_updated(lobby: GFNetworkLobbyDescriptor)
```

Lobby 快照更新后发出。

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
| `peer_id` | 成员 peer 标识。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-signals-invite_received"></a>

### `invite_received`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal invite_received(invite: GFNetworkLobbyInvite)
```

收到 lobby 邀请后发出。

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

后端操作失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `details` | 错误详情。 |

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

<a id="member-gfnetworklobbybackend-methods-create_lobby"></a>

### `create_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func create_lobby(_options: Dictionary = {}) -> Dictionary:
```

创建 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `_options` | 后端选项。 |

返回：请求报告。异步后端应先返回 accepted，再通过信号发出最终结果。

结构：

- `_options`: Dictionary backend-defined create options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-query_lobbies"></a>

### `query_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func query_lobbies(_query: GFNetworkLobbyQuery = null, _options: Dictionary = {}) -> Dictionary:
```

查询 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `_query` | 查询条件。 |
| `_options` | 后端选项。 |

返回：请求报告。

结构：

- `_options`: Dictionary backend-defined query options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-join_lobby"></a>

### `join_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func join_lobby(_lobby_id: String, _options: Dictionary = {}) -> Dictionary:
```

加入 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `_lobby_id` | Lobby ID。 |
| `_options` | 后端选项。 |

返回：请求报告。

结构：

- `_options`: Dictionary backend-defined join options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-leave_lobby"></a>

### `leave_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func leave_lobby(_lobby_id: String = "", _options: Dictionary = {}) -> Dictionary:
```

离开 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `_lobby_id` | Lobby ID；为空时后端可使用当前 lobby。 |
| `_options` | 后端选项。 |

返回：请求报告。

结构：

- `_options`: Dictionary backend-defined leave options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-set_lobby_metadata"></a>

### `set_lobby_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_lobby_metadata(_lobby_id: String, _metadata: Dictionary, _options: Dictionary = {}) -> Dictionary:
```

设置 lobby metadata。

参数：

| 名称 | 说明 |
|---|---|
| `_lobby_id` | Lobby ID。 |
| `_metadata` | Metadata 更新。 |
| `_options` | 后端选项。 |

返回：请求报告。

结构：

- `_metadata`: Dictionary lobby metadata patch.
- `_options`: Dictionary backend-defined metadata options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-set_member_metadata"></a>

### `set_member_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_member_metadata( _lobby_id: String, _peer_id: int, _metadata: Dictionary, _options: Dictionary = {} ) -> Dictionary:
```

设置成员 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `_lobby_id` | Lobby ID。 |
| `_peer_id` | 成员 peer 标识。 |
| `_metadata` | Metadata 更新。 |
| `_options` | 后端选项。 |

返回：请求报告。

结构：

- `_metadata`: Dictionary member metadata patch.
- `_options`: Dictionary backend-defined metadata options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-poll"></a>

### `poll`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func poll(_delta: float) -> void:
```

后端轮询入口。需要平台 callback pump 的后端可重写。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 帧间隔。 |

<a id="member-gfnetworklobbybackend-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func close() -> void:
```

关闭后端资源。

<a id="member-gfnetworklobbybackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试快照。

结构：

- `return`: Dictionary backend debug snapshot.

<a id="member-gfnetworklobbybackend-methods-_make_request_report"></a>

### `_make_request_report`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _make_request_report( ok: bool, operation: StringName, error: StringName = &"", options: Dictionary = {} ) -> Dictionary:
```

构建请求报告。

参数：

| 名称 | 说明 |
|---|---|
| `ok` | 请求是否被接受。 |
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `options` | 附加字段。 |

返回：请求报告。

结构：

- `options`: Dictionary request report fields.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbybackend-methods-_emit_lobby_created"></a>

### `_emit_lobby_created`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobby_created(result: GFNetworkLobbyJoinResult) -> void:
```

发出 lobby_created 信号。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 创建结果。 |

<a id="member-gfnetworklobbybackend-methods-_emit_lobbies_queried"></a>

### `_emit_lobbies_queried`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary = {}) -> void:
```

发出 lobbies_queried 信号。

参数：

| 名称 | 说明 |
|---|---|
| `lobbies` | Lobby 快照列表。 |
| `metadata` | 查询元数据。 |

结构：

- `lobbies`: Array[GFNetworkLobbyDescriptor] lobby snapshots.
- `metadata`: Dictionary query metadata.

<a id="member-gfnetworklobbybackend-methods-_emit_lobby_joined"></a>

### `_emit_lobby_joined`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobby_joined(result: GFNetworkLobbyJoinResult) -> void:
```

发出 lobby_joined 信号。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 加入结果。 |

<a id="member-gfnetworklobbybackend-methods-_emit_lobby_left"></a>

### `_emit_lobby_left`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobby_left(lobby_id: String, reason: String = "left") -> void:
```

发出 lobby_left 信号。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-methods-_emit_lobby_updated"></a>

### `_emit_lobby_updated`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_lobby_updated(lobby: GFNetworkLobbyDescriptor) -> void:
```

发出 lobby_updated 信号。

参数：

| 名称 | 说明 |
|---|---|
| `lobby` | Lobby 快照。 |

<a id="member-gfnetworklobbybackend-methods-_emit_member_joined"></a>

### `_emit_member_joined`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_member_joined(lobby_id: String, member: GFNetworkLobbyMember) -> void:
```

发出 member_joined 信号。

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
func _emit_member_left(lobby_id: String, peer_id: int, reason: String = "left") -> void:
```

发出 member_left 信号。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `peer_id` | 成员 peer 标识。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbybackend-methods-_emit_invite_received"></a>

### `_emit_invite_received`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_invite_received(invite: GFNetworkLobbyInvite) -> void:
```

发出 invite_received 信号。

参数：

| 名称 | 说明 |
|---|---|
| `invite` | 邀请事件。 |

<a id="member-gfnetworklobbybackend-methods-_emit_backend_error"></a>

### `_emit_backend_error`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _emit_backend_error(operation: StringName, error: StringName, details: Dictionary = {}) -> void:
```

发出 backend_error 信号。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `details` | 错误详情。 |

结构：

- `details`: Dictionary backend-defined error metadata.
