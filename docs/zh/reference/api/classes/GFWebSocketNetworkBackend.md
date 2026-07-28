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
| 常量 | [`DEFAULT_MAX_CLIENTS`](#member-gfwebsocketnetworkbackend-constants-default_max_clients) | `const DEFAULT_MAX_CLIENTS: int = 32` |
| 常量 | [`ABSOLUTE_MAX_CLIENTS`](#member-gfwebsocketnetworkbackend-constants-absolute_max_clients) | `const ABSOLUTE_MAX_CLIENTS: int = 65_535` |
| 常量 | [`DEFAULT_HANDSHAKE_TIMEOUT_MSEC`](#member-gfwebsocketnetworkbackend-constants-default_handshake_timeout_msec) | `const DEFAULT_HANDSHAKE_TIMEOUT_MSEC: int = 5_000` |
| 常量 | [`ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC`](#member-gfwebsocketnetworkbackend-constants-absolute_max_handshake_timeout_msec) | `const ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC: int = 300_000` |
| 常量 | [`DEFAULT_MAX_ACCEPTS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-default_max_accepts_per_poll) | `const DEFAULT_MAX_ACCEPTS_PER_POLL: int = 16` |
| 常量 | [`ABSOLUTE_MAX_ACCEPTS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-absolute_max_accepts_per_poll) | `const ABSOLUTE_MAX_ACCEPTS_PER_POLL: int = 4096` |
| 常量 | [`DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-default_max_packets_per_peer_per_poll) | `const DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL: int = 64` |
| 常量 | [`ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-absolute_max_packets_per_peer_per_poll) | `const ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL: int = 4096` |
| 常量 | [`DEFAULT_MAX_PACKETS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-default_max_packets_per_poll) | `const DEFAULT_MAX_PACKETS_PER_POLL: int = 512` |
| 常量 | [`ABSOLUTE_MAX_PACKETS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-absolute_max_packets_per_poll) | `const ABSOLUTE_MAX_PACKETS_PER_POLL: int = 16_384` |
| 常量 | [`DEFAULT_MAX_SERVICE_PEERS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-default_max_service_peers_per_poll) | `const DEFAULT_MAX_SERVICE_PEERS_PER_POLL: int = 64` |
| 常量 | [`ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL`](#member-gfwebsocketnetworkbackend-constants-absolute_max_service_peers_per_poll) | `const ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL: int = 4096` |
| 常量 | [`DEFAULT_INBOUND_BUFFER_SIZE`](#member-gfwebsocketnetworkbackend-constants-default_inbound_buffer_size) | `const DEFAULT_INBOUND_BUFFER_SIZE: int = 65_536` |
| 常量 | [`ABSOLUTE_MAX_INBOUND_BUFFER_SIZE`](#member-gfwebsocketnetworkbackend-constants-absolute_max_inbound_buffer_size) | `const ABSOLUTE_MAX_INBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024` |
| 常量 | [`DEFAULT_OUTBOUND_BUFFER_SIZE`](#member-gfwebsocketnetworkbackend-constants-default_outbound_buffer_size) | `const DEFAULT_OUTBOUND_BUFFER_SIZE: int = 65_536` |
| 常量 | [`ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE`](#member-gfwebsocketnetworkbackend-constants-absolute_max_outbound_buffer_size) | `const ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_QUEUED_PACKETS`](#member-gfwebsocketnetworkbackend-constants-default_max_queued_packets) | `const DEFAULT_MAX_QUEUED_PACKETS: int = 1024` |
| 常量 | [`ABSOLUTE_MAX_QUEUED_PACKETS`](#member-gfwebsocketnetworkbackend-constants-absolute_max_queued_packets) | `const ABSOLUTE_MAX_QUEUED_PACKETS: int = 4096` |
| 常量 | [`ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT`](#member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_count) | `const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT: int = 32` |
| 常量 | [`ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES`](#member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_bytes) | `const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES: int = 256` |
| 常量 | [`ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES`](#member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_total_bytes) | `const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES: int = 4096` |
| 属性 | [`max_accepts_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_accepts_per_poll) | `var max_accepts_per_poll: int:` |
| 属性 | [`max_packets_per_peer_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_packets_per_peer_per_poll) | `var max_packets_per_peer_per_poll: int:` |
| 属性 | [`max_packets_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_packets_per_poll) | `var max_packets_per_poll: int:` |
| 属性 | [`max_service_peers_per_poll`](#member-gfwebsocketnetworkbackend-properties-max_service_peers_per_poll) | `var max_service_peers_per_poll: int:` |
| 属性 | [`handshake_timeout_msec`](#member-gfwebsocketnetworkbackend-properties-handshake_timeout_msec) | `var handshake_timeout_msec: int:` |
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
enum Mode {
	## 未连接。
	DISCONNECTED,
	## 作为服务器监听 TCP 并接受 WebSocket 握手。
	SERVER,
	## 作为客户端连接远端 WebSocket 地址。
	CLIENT,
}
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

<a id="member-gfwebsocketnetworkbackend-constants-default_max_clients"></a>

### `DEFAULT_MAX_CLIENTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_CLIENTS: int = 32
```

WebSocket 主机默认允许的远端 peer 数量。 握手中和已打开的 peer 都会占用容量。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_clients"></a>

### `ABSOLUTE_MAX_CLIENTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_CLIENTS: int = 65_535
```

WebSocket 主机允许的远端 peer 绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_handshake_timeout_msec"></a>

### `DEFAULT_HANDSHAKE_TIMEOUT_MSEC`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_HANDSHAKE_TIMEOUT_MSEC: int = 5_000
```

WebSocket 握手默认超时时间（毫秒）。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_handshake_timeout_msec"></a>

### `ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC: int = 300_000
```

WebSocket 握手超时时间绝对上限（毫秒）。

<a id="member-gfwebsocketnetworkbackend-constants-default_max_accepts_per_poll"></a>

### `DEFAULT_MAX_ACCEPTS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_ACCEPTS_PER_POLL: int = 16
```

单次 poll 默认 accept 尝试预算。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_accepts_per_poll"></a>

### `ABSOLUTE_MAX_ACCEPTS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_ACCEPTS_PER_POLL: int = 4096
```

单次 poll accept 尝试预算绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_max_packets_per_peer_per_poll"></a>

### `DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_PACKETS_PER_PEER_PER_POLL: int = 64
```

单个 peer 单次 poll 默认入站包预算。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_packets_per_peer_per_poll"></a>

### `ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL: int = 4096
```

单个 peer 单次 poll 入站包预算绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_max_packets_per_poll"></a>

### `DEFAULT_MAX_PACKETS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_PACKETS_PER_POLL: int = 512
```

单次 poll 默认全局入站包预算。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_packets_per_poll"></a>

### `ABSOLUTE_MAX_PACKETS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_PACKETS_PER_POLL: int = 16_384
```

单次 poll 全局入站包预算绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_max_service_peers_per_poll"></a>

### `DEFAULT_MAX_SERVICE_PEERS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_SERVICE_PEERS_PER_POLL: int = 64
```

单次 poll 默认服务 peer 数量。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_service_peers_per_poll"></a>

### `ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL: int = 4096
```

单次 poll 服务 peer 数量绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_inbound_buffer_size"></a>

### `DEFAULT_INBOUND_BUFFER_SIZE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_INBOUND_BUFFER_SIZE: int = 65_536
```

单个 WebSocket peer 默认入站缓冲区字节数。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_inbound_buffer_size"></a>

### `ABSOLUTE_MAX_INBOUND_BUFFER_SIZE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_INBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024
```

单个 WebSocket peer 入站缓冲区字节数绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_outbound_buffer_size"></a>

### `DEFAULT_OUTBOUND_BUFFER_SIZE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_OUTBOUND_BUFFER_SIZE: int = 65_536
```

单个 WebSocket peer 默认出站缓冲区字节数。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_outbound_buffer_size"></a>

### `ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_OUTBOUND_BUFFER_SIZE: int = 4 * 1024 * 1024
```

单个 WebSocket peer 出站缓冲区字节数绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-default_max_queued_packets"></a>

### `DEFAULT_MAX_QUEUED_PACKETS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_QUEUED_PACKETS: int = 1024
```

单个 WebSocket peer 默认排队包数量。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_queued_packets"></a>

### `ABSOLUTE_MAX_QUEUED_PACKETS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_QUEUED_PACKETS: int = 4096
```

单个 WebSocket peer 排队包数量绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_count"></a>

### `ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_COUNT: int = 32
```

单个 peer 允许声明的 WebSocket 子协议数量绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_bytes"></a>

### `ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_BYTES: int = 256
```

单个 WebSocket 子协议 UTF-8 字节数绝对上限。

<a id="member-gfwebsocketnetworkbackend-constants-absolute_max_supported_protocol_total_bytes"></a>

### `ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_SUPPORTED_PROTOCOL_TOTAL_BYTES: int = 4096
```

单个 peer 全部 WebSocket 子协议 UTF-8 总字节数绝对上限。

## 属性

<a id="member-gfwebsocketnetworkbackend-properties-max_accepts_per_poll"></a>

### `max_accepts_per_poll`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_accepts_per_poll: int:
```

每次 poll 最多尝试接受的 TCP 连接数量。 赋值会钳制到 1..ABSOLUTE_MAX_ACCEPTS_PER_POLL，不能关闭工作预算。

<a id="member-gfwebsocketnetworkbackend-properties-max_packets_per_peer_per_poll"></a>

### `max_packets_per_peer_per_poll`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var max_packets_per_peer_per_poll: int:
```

每个 peer 每次 poll 最多派发的入站包数量。 赋值会钳制到 1..ABSOLUTE_MAX_PACKETS_PER_PEER_PER_POLL，不能关闭工作预算。

<a id="member-gfwebsocketnetworkbackend-properties-max_packets_per_poll"></a>

### `max_packets_per_poll`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_packets_per_poll: int:
```

单次 poll 最多派发的全局入站包数量。 赋值会钳制到 1..ABSOLUTE_MAX_PACKETS_PER_POLL，不能关闭全局工作预算。

<a id="member-gfwebsocketnetworkbackend-properties-max_service_peers_per_poll"></a>

### `max_service_peers_per_poll`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_service_peers_per_poll: int:
```

单次 poll 最多服务的服务器 peer 数量。 赋值会钳制到 1..ABSOLUTE_MAX_SERVICE_PEERS_PER_POLL，轮转游标保证尾部 peer 会在后续 poll 获得服务机会。

<a id="member-gfwebsocketnetworkbackend-properties-handshake_timeout_msec"></a>

### `handshake_timeout_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var handshake_timeout_msec: int:
```

服务器 peer 从 accept 成功到完成 WebSocket 握手的最长时间（毫秒）。 赋值会钳制到 1..ABSOLUTE_MAX_HANDSHAKE_TIMEOUT_MSEC，避免慢握手永久占用 主机容量。每个 poll 仍只在服务 peer 预算内检查超时。

## 方法

<a id="member-gfwebsocketnetworkbackend-methods-host"></a>

### `host`

- API：`public`
- 首次版本：`3.17.0`

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

- `options`: Dictionary，支持 port、bind_address、address、max_clients、max_peers、handshake_timeout_msec、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。port、容量、握手超时和三项 peer 队列参数只接受对应公开上限内的精确正 int；supported_protocols 只接受有界且无重复的合法 WebSocket token，no_delay 必须为 bool；max_clients 优先于 max_peers。

<a id="member-gfwebsocketnetworkbackend-methods-connect_to_endpoint"></a>

### `connect_to_endpoint`

- API：`public`
- 首次版本：`3.17.0`

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

- `options`: Dictionary，支持 tls_options、supported_protocols、inbound_buffer_size、outbound_buffer_size、max_queued_packets、no_delay。三项 peer 队列参数只接受对应公开上限内的精确正 int；supported_protocols 只接受有界且无重复的合法 WebSocket token，no_delay 必须为 bool。

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
- 首次版本：`3.17.0`

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
- 首次版本：`3.17.0`

```gdscript
func poll(_delta: float) -> void:
```

轮询 WebSocket 连接、握手和收包。 每轮会冻结工作预算，并绑定当前会话 generation 与 WebSocket 对象身份； 同步信号回调若执行 disconnect、rehost 或 reconnect，旧轮询会立即停止， 不再消费旧包、派发旧信号或覆盖新会话统计。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |

<a id="member-gfwebsocketnetworkbackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 backend、available、mode、mode_name、endpoint、session_generation、peer_count、open_peer_count、handshaking_peer_count、client_state、server_capacity、容量与连接统计、handshake_timeout_msec、handshake_timeout_count、peer_option_rejection_count、max_accepts_per_poll、max_packets_per_peer_per_poll、max_packets_per_poll、max_service_peers_per_poll、当轮工作用量及各预算耗尽计数。
