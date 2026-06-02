# GFWebSocketNetworkBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/backends/gf_websocket_network_backend.gd`
- 模块：`Network`
- 继承：`GFNetworkBackend`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

基于 Godot WebSocketPeer 的网络后端。 只实现 GFNetworkBackend 的 bytes 传输边界，适合浏览器、原生客户端或工具链 之间复用同一套 GFNetworkMessage 序列化流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Mode`](#member-gfwebsocketnetworkbackend-enums-mode) | `enum Mode` |
| 常量 | [`BROADCAST_PEER_ID`](#member-gfwebsocketnetworkbackend-constants-broadcast_peer_id) | `const BROADCAST_PEER_ID: int = -1` |
| 常量 | [`SERVER_PEER_ID`](#member-gfwebsocketnetworkbackend-constants-server_peer_id) | `const SERVER_PEER_ID: int = 1` |
| 属性 | [`max_accepts_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_accepts_per_poll) | `var max_accepts_per_poll: int = 16` |
| 属性 | [`max_packets_per_peer_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_packets_per_peer_per_poll) | `var max_packets_per_peer_per_poll: int = 64` |
| 方法 | [`host`](#member-gfwebsocketnetworkbackend-methods-host) | `func host(options: Dictionary = {}) -> Error:` |
| 方法 | [`connect_to_endpoint`](#member-gfwebsocketnetworkbackend-methods-connect_to_endpoint) | `func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:` |
| 方法 | [`disconnect_backend`](#member-gfwebsocketnetworkbackend-methods-disconnect_backend) | `func disconnect_backend() -> void:` |
| 方法 | [`send_bytes`](#member-gfwebsocketnetworkbackend-methods-send_bytes) | `func send_bytes(peer_id: int, bytes: PackedByteArray, _options: Dictionary = {}) -> Error:` |
| 方法 | [`poll`](#member-gfwebsocketnetworkbackend-methods-poll) | `func poll(_delta: float) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfwebsocketnetworkbackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfwebsocketnetworkbackend-enums-mode"></a>

### `Mode`

- API：`public`

```gdscript
enum Mode { ## 未连接。 DISCONNECTED, ## 作为服务器监听 TCP 并接受 WebSocket 握手。 SERVER, ## 作为客户端连接远端 WebSocket 地址。 CLIENT, }
```

WebSocket 后端运行模式。

## 常量

<a id="member-gfwebsocketnetworkbackend-constants-broadcast_peer_id"></a>

### `BROADCAST_PEER_ID`

- API：`public`

```gdscript
const BROADCAST_PEER_ID: int = -1
```

广播 peer 标识。

<a id="member-gfwebsocketnetworkbackend-constants-server_peer_id"></a>

### `SERVER_PEER_ID`

- API：`public`

```gdscript
const SERVER_PEER_ID: int = 1
```

客户端视角下远端服务器的 peer 标识。

## 属性

<a id="member-gfwebsocketnetworkbackend-properties-max_accepts_per_poll"></a>

### `max_accepts_per_poll`

- API：`public`

```gdscript
var max_accepts_per_poll: int = 16
```

每次 poll 最多接受的 TCP 连接数量。小于等于 0 表示不限制。

<a id="member-gfwebsocketnetworkbackend-properties-max_packets_per_peer_per_poll"></a>

### `max_packets_per_peer_per_poll`

- API：`public`

```gdscript
var max_packets_per_peer_per_poll: int = 64
```

每个 peer 每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。

## 方法

<a id="member-gfwebsocketnetworkbackend-methods-host"></a>

### `host`

- API：`public`

```gdscript
func host(options: Dictionary = {}) -> Error:
```

启动 WebSocket 主机。 支持 options: port, bind_address, supported_protocols。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 操作选项字典。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 port、bind_address、address、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。

<a id="member-gfwebsocketnetworkbackend-methods-connect_to_endpoint"></a>

### `connect_to_endpoint`

- API：`public`

```gdscript
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
```

连接 WebSocket 远端。 endpoint 应为 ws:// 或 wss:// URL。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint` | WebSocket 地址。 |
| `options` | 操作选项字典，支持 tls_options、supported_protocols。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 tls_options、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。

<a id="member-gfwebsocketnetworkbackend-methods-disconnect_backend"></a>

### `disconnect_backend`

- API：`public`

```gdscript
func disconnect_backend() -> void:
```

断开 WebSocket 连接。

<a id="member-gfwebsocketnetworkbackend-methods-send_bytes"></a>

### `send_bytes`

- API：`public`

```gdscript
func send_bytes(peer_id: int, bytes: PackedByteArray, _options: Dictionary = {}) -> Error:
```

发送 bytes。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 目标 peer；服务器模式下 -1 表示广播，客户端模式下可传 1 或 -1。 |
| `bytes` | 要发送的字节数据。 |
| `_options` | 操作选项字典。 |

返回：Godot 错误码。

结构：

- `_options`: Dictionary，保留给后端自定义发送选项。

<a id="member-gfwebsocketnetworkbackend-methods-poll"></a>

### `poll`

- API：`public`

```gdscript
func poll(_delta: float) -> void:
```

轮询 WebSocket 连接、握手和收包。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |

<a id="member-gfwebsocketnetworkbackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 backend、available、mode、mode_name、endpoint、peer_count、open_peer_count、client_state、max_accepts_per_poll、max_packets_per_peer_per_poll。
