# GFNetworkBackend

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/backends/gf_network_backend.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

网络后端抽象基类。 后端负责具体传输协议，框架层只依赖该统一接口与信号。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`connected`](#member-gfnetworkbackend-signals-connected) | `signal connected` |
| 信号 | [`disconnected`](#member-gfnetworkbackend-signals-disconnected) | `signal disconnected(reason: String)` |
| 信号 | [`peer_connected`](#member-gfnetworkbackend-signals-peer_connected) | `signal peer_connected(peer_id: int)` |
| 信号 | [`peer_disconnected`](#member-gfnetworkbackend-signals-peer_disconnected) | `signal peer_disconnected(peer_id: int)` |
| 信号 | [`message_received`](#member-gfnetworkbackend-signals-message_received) | `signal message_received(peer_id: int, bytes: PackedByteArray)` |
| 方法 | [`host`](#member-gfnetworkbackend-methods-host) | `func host(_options: Dictionary = {}) -> Error:` |
| 方法 | [`connect_to_endpoint`](#member-gfnetworkbackend-methods-connect_to_endpoint) | `func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:` |
| 方法 | [`disconnect_backend`](#member-gfnetworkbackend-methods-disconnect_backend) | `func disconnect_backend() -> void:` |
| 方法 | [`send_bytes`](#member-gfnetworkbackend-methods-send_bytes) | `func send_bytes(_peer_id: int, _bytes: PackedByteArray, _options: Dictionary = {}) -> Error:` |
| 方法 | [`poll`](#member-gfnetworkbackend-methods-poll) | `func poll(_delta: float) -> void:` |
| 方法 | [`is_backend_connected`](#member-gfnetworkbackend-methods-is_backend_connected) | `func is_backend_connected() -> bool:` |
| 方法 | [`get_session_bootstrap`](#member-gfnetworkbackend-methods-get_session_bootstrap) | `func get_session_bootstrap() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkbackend-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`get_transport_metrics`](#member-gfnetworkbackend-methods-get_transport_metrics) | `func get_transport_metrics() -> GFNetworkTransportMetrics:` |
| 方法 | [`_enrich_transport_metrics`](#member-gfnetworkbackend-methods-_enrich_transport_metrics) | `func _enrich_transport_metrics(_metrics: GFNetworkTransportMetrics) -> void:` |
| 方法 | [`_record_transport_packet_sent`](#member-gfnetworkbackend-methods-_record_transport_packet_sent) | `func _record_transport_packet_sent(byte_count: int) -> void:` |
| 方法 | [`_reset_transport_metrics`](#member-gfnetworkbackend-methods-_reset_transport_metrics) | `func _reset_transport_metrics() -> void:` |

## 信号

<a id="member-gfnetworkbackend-signals-connected"></a>

### `connected`

- API：`public`

```gdscript
signal connected
```

连接成功后发出。

<a id="member-gfnetworkbackend-signals-disconnected"></a>

### `disconnected`

- API：`public`

```gdscript
signal disconnected(reason: String)
```

断开连接后发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 断开原因。 |

<a id="member-gfnetworkbackend-signals-peer_connected"></a>

### `peer_connected`

- API：`public`

```gdscript
signal peer_connected(peer_id: int)
```

远端节点连接后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 远端 peer 标识。 |

<a id="member-gfnetworkbackend-signals-peer_disconnected"></a>

### `peer_disconnected`

- API：`public`

```gdscript
signal peer_disconnected(peer_id: int)
```

远端节点断开后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 远端 peer 标识。 |

<a id="member-gfnetworkbackend-signals-message_received"></a>

### `message_received`

- API：`public`

```gdscript
signal message_received(peer_id: int, bytes: PackedByteArray)
```

收到原始消息 bytes 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 远端 peer 标识。 |
| `bytes` | 原始消息 bytes。 |

## 方法

<a id="member-gfnetworkbackend-methods-host"></a>

### `host`

- API：`public`

```gdscript
func host(_options: Dictionary = {}) -> Error:
```

启动主机。

参数：

| 名称 | 说明 |
|---|---|
| `_options` | 后端自定义选项。 |

返回：Godot 错误码。

结构：

- `_options`: Dictionary，后端自定义启动选项。

<a id="member-gfnetworkbackend-methods-connect_to_endpoint"></a>

### `connect_to_endpoint`

- API：`public`

```gdscript
func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:
```

连接远端。

参数：

| 名称 | 说明 |
|---|---|
| `_endpoint` | 远端地址。 |
| `_options` | 后端自定义选项。 |

返回：Godot 错误码。

结构：

- `_options`: Dictionary，后端自定义连接选项。

<a id="member-gfnetworkbackend-methods-disconnect_backend"></a>

### `disconnect_backend`

- API：`public`

```gdscript
func disconnect_backend() -> void:
```

断开连接。

<a id="member-gfnetworkbackend-methods-send_bytes"></a>

### `send_bytes`

- API：`public`

```gdscript
func send_bytes(_peer_id: int, _bytes: PackedByteArray, _options: Dictionary = {}) -> Error:
```

发送 bytes。

参数：

| 名称 | 说明 |
|---|---|
| `_peer_id` | 目标 peer；后端可约定 -1 表示广播。 |
| `_bytes` | 消息 bytes。 |
| `_options` | 后端自定义发送选项。 |

返回：Godot 错误码。

结构：

- `_options`: Dictionary，后端自定义发送选项。

<a id="member-gfnetworkbackend-methods-poll"></a>

### `poll`

- API：`public`

```gdscript
func poll(_delta: float) -> void:
```

后端轮询入口。需要轮询的后端可重写。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 帧间隔。 |

<a id="member-gfnetworkbackend-methods-is_backend_connected"></a>

### `is_backend_connected`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_backend_connected() -> bool:
```

检查 Backend 是否已建立连接。

返回：已收到连接终态且尚未断开时返回 true。

<a id="member-gfnetworkbackend-methods-get_session_bootstrap"></a>

### `get_session_bootstrap`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_session_bootstrap() -> Dictionary:
```

获取已建立外部连接的会话接管信息。 普通 Backend 返回空字典，由 `host()` / `connect_to_endpoint()` 建立 Session； 接管外部 Peer 的 Backend 可返回 mode、endpoint、local_peer_id 和 metadata。

返回：可选会话接管字段。

结构：

- `return`: Dictionary with optional mode, endpoint, local_peer_id, and metadata.

<a id="member-gfnetworkbackend-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取后端调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 backend、available 以及后端自定义状态字段。

<a id="member-gfnetworkbackend-methods-get_transport_metrics"></a>

### `get_transport_metrics`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_transport_metrics() -> GFNetworkTransportMetrics:
```

获取当前传输指标快照。 基类统一统计成功发送和已派发接收的 bytes/packet 数。具体后端可通过 `_enrich_transport_metrics` 补充 RTT、丢包率或队列等可选指标。

返回：当前指标快照；未知指标不会出现在快照中。

<a id="member-gfnetworkbackend-methods-_enrich_transport_metrics"></a>

### `_enrich_transport_metrics`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _enrich_transport_metrics(_metrics: GFNetworkTransportMetrics) -> void:
```

向基础指标快照写入后端特有指标。

参数：

| 名称 | 说明 |
|---|---|
| `_metrics` | 可追加已知指标的快照。 |

<a id="member-gfnetworkbackend-methods-_record_transport_packet_sent"></a>

### `_record_transport_packet_sent`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _record_transport_packet_sent(byte_count: int) -> void:
```

记录一次成功发送。

参数：

| 名称 | 说明 |
|---|---|
| `byte_count` | 已交给传输层的字节数。 |

<a id="member-gfnetworkbackend-methods-_reset_transport_metrics"></a>

### `_reset_transport_metrics`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _reset_transport_metrics() -> void:
```

重置当前连接的累计传输指标。
