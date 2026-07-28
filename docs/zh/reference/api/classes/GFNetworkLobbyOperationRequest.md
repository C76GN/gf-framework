# GFNetworkLobbyOperationRequest

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_lobby_operation_request.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`10.0.0`

Lobby 操作请求。 将创建、查询、加入、离开和 metadata 更新统一为可关联、可复制的请求值对象。 Provider 专属参数只能放入 provider_options，不能泄漏到项目领域模型。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`OP_CREATE_LOBBY`](#member-gfnetworklobbyoperationrequest-constants-op_create_lobby) | `const OP_CREATE_LOBBY: StringName = &"create_lobby"` |
| 常量 | [`OP_QUERY_LOBBIES`](#member-gfnetworklobbyoperationrequest-constants-op_query_lobbies) | `const OP_QUERY_LOBBIES: StringName = &"query_lobbies"` |
| 常量 | [`OP_JOIN_LOBBY`](#member-gfnetworklobbyoperationrequest-constants-op_join_lobby) | `const OP_JOIN_LOBBY: StringName = &"join_lobby"` |
| 常量 | [`OP_LEAVE_LOBBY`](#member-gfnetworklobbyoperationrequest-constants-op_leave_lobby) | `const OP_LEAVE_LOBBY: StringName = &"leave_lobby"` |
| 常量 | [`OP_SET_LOBBY_METADATA`](#member-gfnetworklobbyoperationrequest-constants-op_set_lobby_metadata) | `const OP_SET_LOBBY_METADATA: StringName = &"set_lobby_metadata"` |
| 常量 | [`OP_SET_MEMBER_METADATA`](#member-gfnetworklobbyoperationrequest-constants-op_set_member_metadata) | `const OP_SET_MEMBER_METADATA: StringName = &"set_member_metadata"` |
| 属性 | [`request_id`](#member-gfnetworklobbyoperationrequest-properties-request_id) | `var request_id: StringName = &""` |
| 属性 | [`operation`](#member-gfnetworklobbyoperationrequest-properties-operation) | `var operation: StringName = &""` |
| 属性 | [`lobby_id`](#member-gfnetworklobbyoperationrequest-properties-lobby_id) | `var lobby_id: String = ""` |
| 属性 | [`peer_id`](#member-gfnetworklobbyoperationrequest-properties-peer_id) | `var peer_id: int = 0` |
| 属性 | [`query`](#member-gfnetworklobbyoperationrequest-properties-query) | `var query: GFNetworkLobbyQuery = null` |
| 属性 | [`payload`](#member-gfnetworklobbyoperationrequest-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`provider_options`](#member-gfnetworklobbyoperationrequest-properties-provider_options) | `var provider_options: Dictionary = {}` |
| 属性 | [`timeout_msec`](#member-gfnetworklobbyoperationrequest-properties-timeout_msec) | `var timeout_msec: int = 0` |
| 属性 | [`metadata`](#member-gfnetworklobbyoperationrequest-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfnetworklobbyoperationrequest-methods-configure) | `func configure( p_request_id: StringName, p_operation: StringName, options: Dictionary = {} ) -> GFNetworkLobbyOperationRequest:` |
| 方法 | [`is_valid`](#member-gfnetworklobbyoperationrequest-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`to_dict`](#member-gfnetworklobbyoperationrequest-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworklobbyoperationrequest-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_request`](#member-gfnetworklobbyoperationrequest-methods-duplicate_request) | `func duplicate_request() -> GFNetworkLobbyOperationRequest:` |
| 方法 | [`get_supported_operations`](#member-gfnetworklobbyoperationrequest-methods-get_supported_operations) | `static func get_supported_operations() -> PackedStringArray:` |
| 方法 | [`from_dict`](#member-gfnetworklobbyoperationrequest-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationRequest:` |

## 常量

<a id="member-gfnetworklobbyoperationrequest-constants-op_create_lobby"></a>

### `OP_CREATE_LOBBY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_CREATE_LOBBY: StringName = &"create_lobby"
```

创建 Lobby 操作。

<a id="member-gfnetworklobbyoperationrequest-constants-op_query_lobbies"></a>

### `OP_QUERY_LOBBIES`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_QUERY_LOBBIES: StringName = &"query_lobbies"
```

查询 Lobby 操作。

<a id="member-gfnetworklobbyoperationrequest-constants-op_join_lobby"></a>

### `OP_JOIN_LOBBY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_JOIN_LOBBY: StringName = &"join_lobby"
```

加入 Lobby 操作。

<a id="member-gfnetworklobbyoperationrequest-constants-op_leave_lobby"></a>

### `OP_LEAVE_LOBBY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_LEAVE_LOBBY: StringName = &"leave_lobby"
```

离开 Lobby 操作。

<a id="member-gfnetworklobbyoperationrequest-constants-op_set_lobby_metadata"></a>

### `OP_SET_LOBBY_METADATA`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_SET_LOBBY_METADATA: StringName = &"set_lobby_metadata"
```

更新 Lobby metadata 操作。

<a id="member-gfnetworklobbyoperationrequest-constants-op_set_member_metadata"></a>

### `OP_SET_MEMBER_METADATA`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const OP_SET_MEMBER_METADATA: StringName = &"set_member_metadata"
```

更新成员 metadata 操作。

## 属性

<a id="member-gfnetworklobbyoperationrequest-properties-request_id"></a>

### `request_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var request_id: StringName = &""
```

请求稳定 ID。

<a id="member-gfnetworklobbyoperationrequest-properties-operation"></a>

### `operation`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var operation: StringName = &""
```

操作类型。

<a id="member-gfnetworklobbyoperationrequest-properties-lobby_id"></a>

### `lobby_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var lobby_id: String = ""
```

目标 Lobby ID。

<a id="member-gfnetworklobbyoperationrequest-properties-peer_id"></a>

### `peer_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var peer_id: int = 0
```

目标成员 peer ID。

<a id="member-gfnetworklobbyoperationrequest-properties-query"></a>

### `query`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var query: GFNetworkLobbyQuery = null
```

查询操作的过滤条件。

<a id="member-gfnetworklobbyoperationrequest-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var payload: Dictionary = {}
```

操作载荷，例如 metadata patch。

结构：

- `payload`: Dictionary operation payload.

<a id="member-gfnetworklobbyoperationrequest-properties-provider_options"></a>

### `provider_options`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var provider_options: Dictionary = {}
```

Provider 专属调用选项。

结构：

- `provider_options`: Dictionary external provider options.

<a id="member-gfnetworklobbyoperationrequest-properties-timeout_msec"></a>

### `timeout_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var timeout_msec: int = 0
```

超时时间，单位毫秒；0 表示由 Service 默认值决定或不限制。

<a id="member-gfnetworklobbyoperationrequest-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方元数据。

结构：

- `metadata`: Dictionary caller-defined request metadata.

## 方法

<a id="member-gfnetworklobbyoperationrequest-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_request_id: StringName, p_operation: StringName, options: Dictionary = {} ) -> GFNetworkLobbyOperationRequest:
```

配置 Lobby 操作请求。

参数：

| 名称 | 说明 |
|---|---|
| `p_request_id` | 请求 ID。 |
| `p_operation` | 操作类型常量。 |
| `options` | 可包含 lobby_id、peer_id、query、payload、provider_options、timeout_msec 和 metadata。 |

返回：当前请求。

结构：

- `options`: Dictionary lobby operation request fields.

<a id="member-gfnetworklobbyoperationrequest-methods-is_valid"></a>

### `is_valid`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_valid() -> bool:
```

检查请求字段是否满足对应操作的最小契约。

返回：请求可派发时返回 true。

<a id="member-gfnetworklobbyoperationrequest-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：Lobby 操作请求字典。

结构：

- `return`: Dictionary lobby operation request.

<a id="member-gfnetworklobbyoperationrequest-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用请求字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 操作请求字典。 |

结构：

- `data`: Dictionary lobby operation request.

<a id="member-gfnetworklobbyoperationrequest-methods-duplicate_request"></a>

### `duplicate_request`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_request() -> GFNetworkLobbyOperationRequest:
```

创建请求深拷贝。

返回：新请求。

<a id="member-gfnetworklobbyoperationrequest-methods-get_supported_operations"></a>

### `get_supported_operations`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func get_supported_operations() -> PackedStringArray:
```

获取全部支持的操作 ID。

返回：固定操作 ID 集合。

<a id="member-gfnetworklobbyoperationrequest-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkLobbyOperationRequest:
```

从字典创建请求。

参数：

| 名称 | 说明 |
|---|---|
| `data` | Lobby 操作请求字典。 |

返回：新请求。

结构：

- `data`: Dictionary lobby operation request.
