# GFENetNetworkBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/backends/gf_enet_network_backend.gd`
- 模块：`Network`
- 继承：`GFNetworkBackend`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

基于 Godot ENetMultiplayerPeer 的网络后端。 该后端只实现 GFNetworkBackend 的 bytes 传输边界，不定义房间、同步、 RPC 或任何项目消息语义。需要更复杂协议时可以继续继承 GFNetworkBackend。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`BROADCAST_PEER_ID`](#member-gfenetnetworkbackend-constants-broadcast_peer_id) | `const BROADCAST_PEER_ID: int = -1` |
| 属性 | [`max_packets_per_poll`](#member-gfenetnetworkbackend-properties-max_packets_per_poll) | `var max_packets_per_poll: int = 64` |
| 方法 | [`host`](#member-gfenetnetworkbackend-methods-host) | `func host(options: Dictionary = {}) -> Error:` |
| 方法 | [`connect_to_endpoint`](#member-gfenetnetworkbackend-methods-connect_to_endpoint) | `func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:` |
| 方法 | [`disconnect_backend`](#member-gfenetnetworkbackend-methods-disconnect_backend) | `func disconnect_backend() -> void:` |
| 方法 | [`send_bytes`](#member-gfenetnetworkbackend-methods-send_bytes) | `func send_bytes(peer_id: int, bytes: PackedByteArray, options: Dictionary = {}) -> Error:` |
| 方法 | [`poll`](#member-gfenetnetworkbackend-methods-poll) | `func poll(_delta: float) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfenetnetworkbackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfenetnetworkbackend-constants-broadcast_peer_id"></a>

### `BROADCAST_PEER_ID`

- API：`public`

```gdscript
const BROADCAST_PEER_ID: int = -1
```

广播 peer 标识。

## 属性

<a id="member-gfenetnetworkbackend-properties-max_packets_per_poll"></a>

### `max_packets_per_poll`

- API：`public`

```gdscript
var max_packets_per_poll: int = 64
```

每次 poll 最多派发的入站包数量。小于等于 0 表示不限制。

## 方法

<a id="member-gfenetnetworkbackend-methods-host"></a>

### `host`

- API：`public`

```gdscript
func host(options: Dictionary = {}) -> Error:
```

启动 ENet 主机。 支持 options: port, max_clients, max_channels, in_bandwidth, out_bandwidth。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 操作选项字典。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 port、max_clients、max_channels、in_bandwidth、out_bandwidth。

<a id="member-gfenetnetworkbackend-methods-connect_to_endpoint"></a>

### `connect_to_endpoint`

- API：`public`

```gdscript
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
```

连接 ENet 远端。 endpoint 可传 "host:port"，或通过 options.port 传端口。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint` | 网络连接端点。 |
| `options` | 操作选项字典。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 port、max_channels、in_bandwidth、out_bandwidth。

<a id="member-gfenetnetworkbackend-methods-disconnect_backend"></a>

### `disconnect_backend`

- API：`public`

```gdscript
func disconnect_backend() -> void:
```

断开 ENet 连接。

<a id="member-gfenetnetworkbackend-methods-send_bytes"></a>

### `send_bytes`

- API：`public`

```gdscript
func send_bytes(peer_id: int, bytes: PackedByteArray, options: Dictionary = {}) -> Error:
```

发送 bytes。 options 支持 reliable, transfer_mode, channel。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 目标网络 peer 标识。 |
| `bytes` | 要发送的字节数据。 |
| `options` | 操作选项字典。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，支持 reliable、transfer_mode、channel。

<a id="member-gfenetnetworkbackend-methods-poll"></a>

### `poll`

- API：`public`

```gdscript
func poll(_delta: float) -> void:
```

轮询 ENet 事件和收包。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |

<a id="member-gfenetnetworkbackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 backend、available、endpoint、is_server、connection_status、connection_status_name、available_packet_count、max_packets_per_poll。
