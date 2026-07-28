# GFNetworkLobbyService

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_service.gd`
- 模块：`Network`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

平台中立 Lobby 操作协调服务。 Service 统一生成请求 ID、管理单调超时、取消 Backend 替换时的等待操作，并维护 Lobby 快照。Steam、小游戏、LAN 或自建服务 API 只能存在于外部 Backend Adapter。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`operation_started`](#member-gfnetworklobbyservice-signals-operation_started) | `signal operation_started(request: GFNetworkLobbyOperationRequest)` |
| 信号 | [`operation_completed`](#member-gfnetworklobbyservice-signals-operation_completed) | `signal operation_completed(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobby_created`](#member-gfnetworklobbyservice-signals-lobby_created) | `signal lobby_created(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobbies_queried`](#member-gfnetworklobbyservice-signals-lobbies_queried) | `signal lobbies_queried(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobby_joined`](#member-gfnetworklobbyservice-signals-lobby_joined) | `signal lobby_joined(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobby_left`](#member-gfnetworklobbyservice-signals-lobby_left) | `signal lobby_left(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobby_metadata_set`](#member-gfnetworklobbyservice-signals-lobby_metadata_set) | `signal lobby_metadata_set(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`member_metadata_set`](#member-gfnetworklobbyservice-signals-member_metadata_set) | `signal member_metadata_set(result: GFNetworkLobbyOperationResult)` |
| 信号 | [`lobby_updated`](#member-gfnetworklobbyservice-signals-lobby_updated) | `signal lobby_updated(lobby: GFNetworkLobbyDescriptor)` |
| 信号 | [`member_joined`](#member-gfnetworklobbyservice-signals-member_joined) | `signal member_joined(lobby_id: String, member: GFNetworkLobbyMember)` |
| 信号 | [`member_left`](#member-gfnetworklobbyservice-signals-member_left) | `signal member_left(lobby_id: String, peer_id: int, reason: String)` |
| 信号 | [`invite_received`](#member-gfnetworklobbyservice-signals-invite_received) | `signal invite_received(invite: GFNetworkLobbyInvite)` |
| 信号 | [`backend_error`](#member-gfnetworklobbyservice-signals-backend_error) | `signal backend_error(operation: StringName, error: StringName, details: Dictionary)` |
| 属性 | [`backend`](#member-gfnetworklobbyservice-properties-backend) | `var backend: GFNetworkLobbyBackend:` |
| 属性 | [`current_lobby`](#member-gfnetworklobbyservice-properties-current_lobby) | `var current_lobby: GFNetworkLobbyDescriptor = null` |
| 属性 | [`default_timeout_msec`](#member-gfnetworklobbyservice-properties-default_timeout_msec) | `var default_timeout_msec: int = 15000` |
| 方法 | [`ready`](#member-gfnetworklobbyservice-methods-ready) | `func ready() -> void:` |
| 方法 | [`tick`](#member-gfnetworklobbyservice-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfnetworklobbyservice-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_backend`](#member-gfnetworklobbyservice-methods-set_backend) | `func set_backend(next_backend: GFNetworkLobbyBackend) -> bool:` |
| 方法 | [`set_clock`](#member-gfnetworklobbyservice-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gfnetworklobbyservice-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`create_lobby`](#member-gfnetworklobbyservice-methods-create_lobby) | `func create_lobby(options: Dictionary = {}) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`query_lobbies`](#member-gfnetworklobbyservice-methods-query_lobbies) | `func query_lobbies( query: GFNetworkLobbyQuery = null, options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`join_lobby`](#member-gfnetworklobbyservice-methods-join_lobby) | `func join_lobby( lobby_id: String, options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`leave_lobby`](#member-gfnetworklobbyservice-methods-leave_lobby) | `func leave_lobby( lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`set_lobby_metadata`](#member-gfnetworklobbyservice-methods-set_lobby_metadata) | `func set_lobby_metadata( metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`set_member_metadata`](#member-gfnetworklobbyservice-methods-set_member_metadata) | `func set_member_metadata( peer_id: int, metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`invoke_operation`](#member-gfnetworklobbyservice-methods-invoke_operation) | `func invoke_operation( request: GFNetworkLobbyOperationRequest ) -> GFNetworkLobbyOperationHandle:` |
| 方法 | [`cancel_operation`](#member-gfnetworklobbyservice-methods-cancel_operation) | `func cancel_operation( request_id: StringName, reason: StringName = &"cancelled" ) -> bool:` |
| 方法 | [`get_lobby`](#member-gfnetworklobbyservice-methods-get_lobby) | `func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:` |
| 方法 | [`get_lobbies`](#member-gfnetworklobbyservice-methods-get_lobbies) | `func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworklobbyservice-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworklobbyservice-signals-operation_started"></a>

### `operation_started`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal operation_started(request: GFNetworkLobbyOperationRequest)
```

操作提交给 Backend 前发出。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 请求副本。 |

<a id="member-gfnetworklobbyservice-signals-operation_completed"></a>

### `operation_completed`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal operation_completed(result: GFNetworkLobbyOperationResult)
```

任意 Lobby 操作进入终态后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 终态结果副本。 |

<a id="member-gfnetworklobbyservice-signals-lobby_created"></a>

### `lobby_created`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_created(result: GFNetworkLobbyOperationResult)
```

创建 Lobby 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 创建操作终态。 |

<a id="member-gfnetworklobbyservice-signals-lobbies_queried"></a>

### `lobbies_queried`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobbies_queried(result: GFNetworkLobbyOperationResult)
```

查询 Lobby 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 查询操作终态。 |

<a id="member-gfnetworklobbyservice-signals-lobby_joined"></a>

### `lobby_joined`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_joined(result: GFNetworkLobbyOperationResult)
```

加入 Lobby 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 加入操作终态。 |

<a id="member-gfnetworklobbyservice-signals-lobby_left"></a>

### `lobby_left`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal lobby_left(result: GFNetworkLobbyOperationResult)
```

离开 Lobby 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 离开操作终态。 |

<a id="member-gfnetworklobbyservice-signals-lobby_metadata_set"></a>

### `lobby_metadata_set`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal lobby_metadata_set(result: GFNetworkLobbyOperationResult)
```

Lobby metadata 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | Metadata 操作终态。 |

<a id="member-gfnetworklobbyservice-signals-member_metadata_set"></a>

### `member_metadata_set`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal member_metadata_set(result: GFNetworkLobbyOperationResult)
```

成员 metadata 操作完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | Metadata 操作终态。 |

<a id="member-gfnetworklobbyservice-signals-lobby_updated"></a>

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
| `peer_id` | 成员 peer ID。 |
| `reason` | 离开原因。 |

<a id="member-gfnetworklobbyservice-signals-invite_received"></a>

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

<a id="member-gfnetworklobbyservice-signals-backend_error"></a>

### `backend_error`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal backend_error(operation: StringName, error: StringName, details: Dictionary)
```

Backend 出现不属于具体请求的错误时发出。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 操作标识。 |
| `error` | 错误标识。 |
| `details` | 已脱敏错误详情。 |

结构：

- `details`: Dictionary backend-defined error metadata.

## 属性

<a id="member-gfnetworklobbyservice-properties-backend"></a>

### `backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var backend: GFNetworkLobbyBackend:
```

当前 Lobby Backend。

<a id="member-gfnetworklobbyservice-properties-current_lobby"></a>

### `current_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var current_lobby: GFNetworkLobbyDescriptor = null
```

当前已加入 Lobby；未加入时为 null。

<a id="member-gfnetworklobbyservice-properties-default_timeout_msec"></a>

### `default_timeout_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var default_timeout_msec: int = 15000
```

未显式传入 timeout_msec 时的操作超时；0 表示不限制。

## 方法

<a id="member-gfnetworklobbyservice-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func ready() -> void:
```

在架构中自动采用已注册 GFTimeProvider 的底层时钟。

<a id="member-gfnetworklobbyservice-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进 Backend callback pump 并处理操作超时。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始帧间隔。 |

<a id="member-gfnetworklobbyservice-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

取消全部操作、关闭 Backend 并清理快照。

<a id="member-gfnetworklobbyservice-methods-set_backend"></a>

### `set_backend`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_backend(next_backend: GFNetworkLobbyBackend) -> bool:
```

设置 Lobby Backend。 替换前会先取消旧 Backend 的全部等待操作，再断开事件并关闭旧资源。

参数：

| 名称 | 说明 |
|---|---|
| `next_backend` | 新 Backend；null 表示清除。 |

返回：Backend 可采用当前时钟并已设置时返回 true。

<a id="member-gfnetworklobbyservice-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

设置操作超时和耗时使用的统一单调时钟。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新时钟。 |

返回：时钟有效且当前没有等待操作时返回 true。

<a id="member-gfnetworklobbyservice-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取当前时钟。

返回：当前时钟。

<a id="member-gfnetworklobbyservice-methods-create_lobby"></a>

### `create_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func create_lobby(options: Dictionary = {}) -> GFNetworkLobbyOperationHandle:
```

创建 Lobby。

参数：

| 名称 | 说明 |
|---|---|
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `options`: Dictionary lobby create options.

<a id="member-gfnetworklobbyservice-methods-query_lobbies"></a>

### `query_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func query_lobbies( query: GFNetworkLobbyQuery = null, options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:
```

查询 Lobby。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 查询条件。 |
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `options`: Dictionary lobby query options.

<a id="member-gfnetworklobbyservice-methods-join_lobby"></a>

### `join_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func join_lobby( lobby_id: String, options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:
```

加入 Lobby。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `options`: Dictionary lobby join options.

<a id="member-gfnetworklobbyservice-methods-leave_lobby"></a>

### `leave_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func leave_lobby( lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:
```

离开当前或指定 Lobby。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `options`: Dictionary lobby leave options.

<a id="member-gfnetworklobbyservice-methods-set_lobby_metadata"></a>

### `set_lobby_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_lobby_metadata( metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:
```

更新当前或指定 Lobby metadata。

参数：

| 名称 | 说明 |
|---|---|
| `metadata_patch` | Metadata patch。 |
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `metadata_patch`: Dictionary lobby metadata patch.
- `options`: Dictionary lobby metadata options.

<a id="member-gfnetworklobbyservice-methods-set_member_metadata"></a>

### `set_member_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_member_metadata( peer_id: int, metadata_patch: Dictionary, lobby_id: String = "", options: Dictionary = {} ) -> GFNetworkLobbyOperationHandle:
```

更新当前或指定 Lobby 的成员 metadata。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 成员 peer ID。 |
| `metadata_patch` | Metadata patch。 |
| `lobby_id` | Lobby ID；为空时使用 current_lobby。 |
| `options` | Provider 选项；保留 request_id、timeout_msec 和 metadata 作为 Service 字段。 |

返回：一次性操作句柄。

结构：

- `metadata_patch`: Dictionary member metadata patch.
- `options`: Dictionary member metadata options.

<a id="member-gfnetworklobbyservice-methods-invoke_operation"></a>

### `invoke_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func invoke_operation( request: GFNetworkLobbyOperationRequest ) -> GFNetworkLobbyOperationHandle:
```

提交完整 Lobby 操作请求。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 完整请求。 |

返回：一次性操作句柄。

<a id="member-gfnetworklobbyservice-methods-cancel_operation"></a>

### `cancel_operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func cancel_operation( request_id: StringName, reason: StringName = &"cancelled" ) -> bool:
```

取消等待中的操作。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | 请求 ID。 |
| `reason` | 取消原因。 |

返回：找到并首次取消返回 true。

<a id="member-gfnetworklobbyservice-methods-get_lobby"></a>

### `get_lobby`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
```

获取已知 Lobby 快照。

参数：

| 名称 | 说明 |
|---|---|
| `lobby_id` | Lobby ID。 |

返回：找到时返回快照副本，否则返回 null。

<a id="member-gfnetworklobbyservice-methods-get_lobbies"></a>

### `get_lobbies`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_lobbies() -> Array[GFNetworkLobbyDescriptor]:
```

获取全部已知 Lobby 快照。

返回：按 Lobby ID 排序的快照副本。

结构：

- `return`: Array[GFNetworkLobbyDescriptor] known lobby snapshots.

<a id="member-gfnetworklobbyservice-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Service 调试快照。

返回：不包含 provider 选项和 metadata 的摘要。

结构：

- `return`: Dictionary lobby service debug snapshot.
