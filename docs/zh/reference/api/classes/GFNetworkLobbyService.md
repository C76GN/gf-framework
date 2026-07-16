# GFNetworkLobbyService

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_service.gd`
- 模块：`Network`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

平台中立 lobby 协调服务。 该服务只管理 backend 请求、当前 lobby 快照和信号转发。Steam、微信、LAN 或自建服务 的具体 API 必须由外部或可选 adapter 通过 GFNetworkLobbyBackend 实现。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`lobby_created`](#member-gfnetworklobbyservice-signals-lobby_created) | `signal lobby_created(result: GFNetworkLobbyJoinResult)` |
| 信号 | [`lobbies_queried`](#member-gfnetworklobbyservice-signals-lobbies_queried) | `signal lobbies_queried(lobbies: Array[GFNetworkLobbyDescriptor], metadata: Dictionary)` |
| 信号 | [`lobby_joined`](#member-gfnetworklobbyservice-signals-lobby_joined) | `signal lobby_joined(result: GFNetworkLobbyJoinResult)` |
| 信号 | [`lobby_left`](#member-gfnetworklobbyservice-signals-lobby_left) | `signal lobby_left(lobby_id: String, reason: String)` |
| 信号 | [`lobby_updated`](#member-gfnetworklobbyservice-signals-lobby_updated) | `signal lobby_updated(lobby: GFNetworkLobbyDescriptor)` |
| 信号 | [`member_joined`](#member-gfnetworklobbyservice-signals-member_joined) | `signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)` |
| 信号 | [`member_left`](#member-gfnetworklobbyservice-signals-member_left) | `signal member_left(lobby_id: String, peer_id: int, reason: String)` |
| 信号 | [`invite_received`](#member-gfnetworklobbyservice-signals-invite_received) | `signal invite_received(invite: GFNetworkLobbyInvite)` |
| 信号 | [`backend_error`](#member-gfnetworklobbyservice-signals-backend_error) | `signal backend_error(operation: StringName, error: StringName, details: Dictionary)` |
| 属性 | [`backend`](#member-gfnetworklobbyservice-properties-backend) | `var backend: GFNetworkLobbyBackend = null` |
| 属性 | [`current_lobby`](#member-gfnetworklobbyservice-properties-current_lobby) | `var current_lobby: GFNetworkLobbyDescriptor = null` |
| 方法 | [`tick`](#member-gfnetworklobbyservice-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfnetworklobbyservice-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_backend`](#member-gfnetworklobbyservice-methods-set_backend) | `func set_backend(next_backend: GFNetworkLobbyBackend) -> void:` |
| 方法 | [`create_lobby`](#member-gfnetworklobbyservice-methods-create_lobby) | `func create_lobby(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`query_lobbies`](#member-gfnetworklobbyservice-methods-query_lobbies) | `func query_lobbies(query: GFNetworkLobbyQuery = null, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`join_lobby`](#member-gfnetworklobbyservice-methods-join_lobby) | `func join_lobby(lobby_id: String, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`leave_lobby`](#member-gfnetworklobbyservice-methods-leave_lobby) | `func leave_lobby(lobby_id: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`set_lobby_metadata`](#member-gfnetworklobbyservice-methods-set_lobby_metadata) | `func set_lobby_metadata( metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`set_member_metadata`](#member-gfnetworklobbyservice-methods-set_member_metadata) | `func set_member_metadata( peer_id: int, metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_lobby`](#member-gfnetworklobbyservice-methods-get_lobby) | `func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:` |
| 方法 | [`get_lobbies`](#member-gfnetworklobbyservice-methods-get_lobbies) | `func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbyservice-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworklobbyservice-signals-lobby_created"></a>

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

<a id="member-gfnetworklobbyservice-signals-lobbies_queried"></a>

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

<a id="member-gfnetworklobbyservice-signals-lobby_joined"></a>

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

<a id="member-gfnetworklobbyservice-signals-lobby_left"></a>

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

<a id="member-gfnetworklobbyservice-signals-lobby_updated"></a>

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

<a id="member-gfnetworklobbyservice-signals-member_joined"></a>

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

<a id="member-gfnetworklobbyservice-signals-member_left"></a>

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

<a id="member-gfnetworklobbyservice-signals-invite_received"></a>

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

<a id="member-gfnetworklobbyservice-signals-backend_error"></a>

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

<a id="member-gfnetworklobbyservice-properties-backend"></a>

### `backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var backend: GFNetworkLobbyBackend = null
```

当前 lobby 后端。

<a id="member-gfnetworklobbyservice-properties-current_lobby"></a>

### `current_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var current_lobby: GFNetworkLobbyDescriptor = null
```

当前已加入 lobby。未加入时为 null。

## 方法

<a id="member-gfnetworklobbyservice-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进 lobby 后端轮询。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfnetworklobbyservice-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

关闭后端并清理 lobby 快照。

<a id="member-gfnetworklobbyservice-methods-set_backend"></a>

### `set_backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_backend(next_backend: GFNetworkLobbyBackend) -> void:
```

设置 lobby 后端。

参数：

| 名称 | 说明 |
|---|---|
| `next_backend` | 新后端。 |

<a id="member-gfnetworklobbyservice-methods-create_lobby"></a>

### `create_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func create_lobby(options: Dictionary = {}) -> Dictionary:
```

创建 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `options`: Dictionary backend-defined create options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-query_lobbies"></a>

### `query_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func query_lobbies(query: GFNetworkLobbyQuery = null, options: Dictionary = {}) -> Dictionary:
```

查询 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询条件。 |
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `options`: Dictionary backend-defined query options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-join_lobby"></a>

### `join_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func join_lobby(lobby_id: String, options: Dictionary = {}) -> Dictionary:
```

加入 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `options`: Dictionary backend-defined join options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-leave_lobby"></a>

### `leave_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func leave_lobby(lobby_id: String = "", options: Dictionary = {}) -> Dictionary:
```

离开 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `options`: Dictionary backend-defined leave options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-set_lobby_metadata"></a>

### `set_lobby_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_lobby_metadata( metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> Dictionary:
```

设置当前或指定 lobby metadata。

参数：

| 名称 | 说明 |
|---|---|
| `metadata_patch` | Metadata 更新。 |
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `metadata_patch`: Dictionary lobby metadata patch.
- `options`: Dictionary backend-defined metadata options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-set_member_metadata"></a>

### `set_member_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_member_metadata( peer_id: int, metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> Dictionary:
```

设置当前或指定 lobby 的成员 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 成员 peer 标识。 |
| `metadata_patch` | Metadata 更新。 |
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | 后端选项。 |

返回：请求报告。

结构：

- `metadata_patch`: Dictionary member metadata patch.
- `options`: Dictionary backend-defined metadata options.
- `return`: Dictionary with ok, status, operation, request_id, and error.

<a id="member-gfnetworklobbyservice-methods-get_lobby"></a>

### `get_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
```

获取已知 lobby。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |

返回：Lobby 快照；不存在时返回 null。

<a id="member-gfnetworklobbyservice-methods-get_lobbies"></a>

### `get_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:
```

获取全部已知 lobby 快照。

返回：Lobby 快照列表。

结构：

- `return`: Array[GFNetworkLobbyDescriptor] known lobby snapshots.

<a id="member-gfnetworklobbyservice-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with backend_configured, backend, current_lobby, and known_lobby_count.
