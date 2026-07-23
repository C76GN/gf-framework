# GFNetworkUtility

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/runtime/gf_network_utility.gd`
- 模块：`Network`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

可插拔网络后端运行时。 负责把通用 GFNetworkMessage 编码后交给后端发送，并将后端收到的 bytes 解码为消息信号。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`message_received`](#member-gfnetworkutility-signals-message_received) | `signal message_received(peer_id: int, message: GFNetworkMessage)` |
| 信号 | [`message_rejected`](#member-gfnetworkutility-signals-message_rejected) | `signal message_rejected(peer_id: int, reason: String, details: Dictionary)` |
| 信号 | [`connected`](#member-gfnetworkutility-signals-connected) | `signal connected` |
| 信号 | [`disconnected`](#member-gfnetworkutility-signals-disconnected) | `signal disconnected(reason: String)` |
| 信号 | [`peer_connected`](#member-gfnetworkutility-signals-peer_connected) | `signal peer_connected(peer_id: int)` |
| 信号 | [`peer_disconnected`](#member-gfnetworkutility-signals-peer_disconnected) | `signal peer_disconnected(peer_id: int)` |
| 信号 | [`transport_metrics_sampled`](#member-gfnetworkutility-signals-transport_metrics_sampled) | `signal transport_metrics_sampled(metrics: GFNetworkTransportMetrics)` |
| 属性 | [`backend`](#member-gfnetworkutility-properties-backend) | `var backend: GFNetworkBackend:` |
| 属性 | [`serializer`](#member-gfnetworkutility-properties-serializer) | `var serializer: GFNetworkSerializer = GFNetworkSerializer.new()` |
| 属性 | [`validator`](#member-gfnetworkutility-properties-validator) | `var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()` |
| 属性 | [`session`](#member-gfnetworkutility-properties-session) | `var session: GFNetworkSession = GFNetworkSession.new()` |
| 属性 | [`connect_timeout_msec`](#member-gfnetworkutility-properties-connect_timeout_msec) | `var connect_timeout_msec: int = 15000` |
| 属性 | [`transport_metrics_sample_interval_msec`](#member-gfnetworkutility-properties-transport_metrics_sample_interval_msec) | `var transport_metrics_sample_interval_msec: int = 1000` |
| 属性 | [`max_transport_metric_samples`](#member-gfnetworkutility-properties-max_transport_metric_samples) | `var max_transport_metric_samples: int:` |
| 方法 | [`ready`](#member-gfnetworkutility-methods-ready) | `func ready() -> void:` |
| 方法 | [`tick`](#member-gfnetworkutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfnetworkutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_backend`](#member-gfnetworkutility-methods-set_backend) | `func set_backend(next_backend: GFNetworkBackend) -> void:` |
| 方法 | [`register_channel`](#member-gfnetworkutility-methods-register_channel) | `func register_channel(channel: GFNetworkChannel) -> void:` |
| 方法 | [`unregister_channel`](#member-gfnetworkutility-methods-unregister_channel) | `func unregister_channel(channel_id: StringName) -> void:` |
| 方法 | [`get_channel`](#member-gfnetworkutility-methods-get_channel) | `func get_channel(channel_id: StringName) -> GFNetworkChannel:` |
| 方法 | [`get_channel_ids`](#member-gfnetworkutility-methods-get_channel_ids) | `func get_channel_ids() -> PackedStringArray:` |
| 方法 | [`clear_channels`](#member-gfnetworkutility-methods-clear_channels) | `func clear_channels() -> void:` |
| 方法 | [`host`](#member-gfnetworkutility-methods-host) | `func host(options: Dictionary = {}) -> Error:` |
| 方法 | [`connect_to_endpoint`](#member-gfnetworkutility-methods-connect_to_endpoint) | `func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:` |
| 方法 | [`disconnect_network`](#member-gfnetworkutility-methods-disconnect_network) | `func disconnect_network() -> void:` |
| 方法 | [`send_message`](#member-gfnetworkutility-methods-send_message) | `func send_message(peer_id: int, message: GFNetworkMessage, options: Dictionary = {}) -> Error:` |
| 方法 | [`send_message_on_channel`](#member-gfnetworkutility-methods-send_message_on_channel) | `func send_message_on_channel( peer_id: int, message: GFNetworkMessage, channel_id: StringName, options: Dictionary = {} ) -> Error:` |
| 方法 | [`capture_transport_metrics`](#member-gfnetworkutility-methods-capture_transport_metrics) | `func capture_transport_metrics() -> GFNetworkTransportMetrics:` |
| 方法 | [`get_transport_metric_samples`](#member-gfnetworkutility-methods-get_transport_metric_samples) | `func get_transport_metric_samples() -> Array[GFNetworkTransportMetrics]:` |
| 方法 | [`clear_transport_metric_samples`](#member-gfnetworkutility-methods-clear_transport_metric_samples) | `func clear_transport_metric_samples() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfnetworkutility-signals-message_received"></a>

### `message_received`

- API：`public`

```gdscript
signal message_received(peer_id: int, message: GFNetworkMessage)
```

收到消息后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 发送方 peer 标识。 |
| `message` | 解码后的网络消息。 |

<a id="member-gfnetworkutility-signals-message_rejected"></a>

### `message_rejected`

- API：`public`

```gdscript
signal message_rejected(peer_id: int, reason: String, details: Dictionary)
```

消息校验失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 关联 peer 标识。 |
| `reason` | 拒绝原因。 |
| `details` | 校验或解码详情。 |

结构：

- `details`: Dictionary，包含 ok、errors 或 error/data 等诊断字段。

<a id="member-gfnetworkutility-signals-connected"></a>

### `connected`

- API：`public`

```gdscript
signal connected
```

后端连接成功后发出。

<a id="member-gfnetworkutility-signals-disconnected"></a>

### `disconnected`

- API：`public`

```gdscript
signal disconnected(reason: String)
```

后端断开后发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 断开原因。 |

<a id="member-gfnetworkutility-signals-peer_connected"></a>

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

<a id="member-gfnetworkutility-signals-peer_disconnected"></a>

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

<a id="member-gfnetworkutility-signals-transport_metrics_sampled"></a>

### `transport_metrics_sampled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transport_metrics_sampled(metrics: GFNetworkTransportMetrics)
```

采集到传输指标快照后发出。

参数：

| 名称 | 说明 |
|---|---|
| `metrics` | 指标快照副本。 |

## 属性

<a id="member-gfnetworkutility-properties-backend"></a>

### `backend`

- API：`public`
- 首次版本：`3.6.0`

```gdscript
var backend: GFNetworkBackend:
```

当前网络后端。

<a id="member-gfnetworkutility-properties-serializer"></a>

### `serializer`

- API：`public`

```gdscript
var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
```

消息编码器。

<a id="member-gfnetworkutility-properties-validator"></a>

### `validator`

- API：`public`

```gdscript
var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()
```

消息校验器。

<a id="member-gfnetworkutility-properties-session"></a>

### `session`

- API：`public`

```gdscript
var session: GFNetworkSession = GFNetworkSession.new()
```

当前会话状态。

<a id="member-gfnetworkutility-properties-connect_timeout_msec"></a>

### `connect_timeout_msec`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var connect_timeout_msec: int = 15000
```

客户端连接超时时间，单位毫秒。小于等于 0 表示不主动超时。

<a id="member-gfnetworkutility-properties-transport_metrics_sample_interval_msec"></a>

### `transport_metrics_sample_interval_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var transport_metrics_sample_interval_msec: int = 1000
```

自动传输指标采样间隔，单位毫秒；小于等于 0 表示禁用自动采样。

<a id="member-gfnetworkutility-properties-max_transport_metric_samples"></a>

### `max_transport_metric_samples`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_transport_metric_samples: int:
```

内存中最多保留的传输指标快照数量；小于等于 0 表示不保留。

## 方法

<a id="member-gfnetworkutility-methods-ready"></a>

### `ready`

- API：`public`

```gdscript
func ready() -> void:
```

注册网络诊断快照贡献。

<a id="member-gfnetworkutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gfnetworkutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放后端、通道和诊断贡献。

<a id="member-gfnetworkutility-methods-set_backend"></a>

### `set_backend`

- API：`public`

```gdscript
func set_backend(next_backend: GFNetworkBackend) -> void:
```

设置网络后端。

参数：

| 名称 | 说明 |
|---|---|
| `next_backend` | 新后端。 |

<a id="member-gfnetworkutility-methods-register_channel"></a>

### `register_channel`

- API：`public`

```gdscript
func register_channel(channel: GFNetworkChannel) -> void:
```

注册网络通道。

参数：

| 名称 | 说明 |
|---|---|
| `channel` | 通道资源。 |

<a id="member-gfnetworkutility-methods-unregister_channel"></a>

### `unregister_channel`

- API：`public`

```gdscript
func unregister_channel(channel_id: StringName) -> void:
```

注销网络通道。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |

<a id="member-gfnetworkutility-methods-get_channel"></a>

### `get_channel`

- API：`public`

```gdscript
func get_channel(channel_id: StringName) -> GFNetworkChannel:
```

获取网络通道。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |

返回：通道资源。

<a id="member-gfnetworkutility-methods-get_channel_ids"></a>

### `get_channel_ids`

- API：`public`

```gdscript
func get_channel_ids() -> PackedStringArray:
```

获取已注册通道标识。

返回：排序后的通道标识。

<a id="member-gfnetworkutility-methods-clear_channels"></a>

### `clear_channels`

- API：`public`

```gdscript
func clear_channels() -> void:
```

清空网络通道。

<a id="member-gfnetworkutility-methods-host"></a>

### `host`

- API：`public`

```gdscript
func host(options: Dictionary = {}) -> Error:
```

启动主机。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 后端选项。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，传给 session.start_host() 和 backend.host() 的后端选项。

<a id="member-gfnetworkutility-methods-connect_to_endpoint"></a>

### `connect_to_endpoint`

- API：`public`

```gdscript
func connect_to_endpoint(endpoint: String, options: Dictionary = {}) -> Error:
```

连接远端。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint` | 远端地址。 |
| `options` | 后端选项。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，传给 session.start_client() 和 backend.connect_to_endpoint() 的后端选项。

<a id="member-gfnetworkutility-methods-disconnect_network"></a>

### `disconnect_network`

- API：`public`

```gdscript
func disconnect_network() -> void:
```

断开连接。

<a id="member-gfnetworkutility-methods-send_message"></a>

### `send_message`

- API：`public`

```gdscript
func send_message(peer_id: int, message: GFNetworkMessage, options: Dictionary = {}) -> Error:
```

发送消息。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 目标 peer；后端可约定 -1 表示广播。 |
| `message` | 消息载体。 |
| `options` | 后端发送选项。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，传给 backend.send_bytes() 的发送选项。

<a id="member-gfnetworkutility-methods-send_message_on_channel"></a>

### `send_message_on_channel`

- API：`public`

```gdscript
func send_message_on_channel( peer_id: int, message: GFNetworkMessage, channel_id: StringName, options: Dictionary = {} ) -> Error:
```

通过指定通道发送消息。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 目标 peer；后端可约定 -1 表示广播。 |
| `message` | 消息载体。 |
| `channel_id` | 通道标识。 |
| `options` | 后端发送选项覆盖。 |

返回：Godot 错误码。

结构：

- `options`: Dictionary，覆盖 GFNetworkChannel.build_send_options() 的发送选项。

<a id="member-gfnetworkutility-methods-capture_transport_metrics"></a>

### `capture_transport_metrics`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_transport_metrics() -> GFNetworkTransportMetrics:
```

立即采集一次当前 Backend 的传输指标。

返回：指标快照；未配置 Backend 时返回 null。

<a id="member-gfnetworkutility-methods-get_transport_metric_samples"></a>

### `get_transport_metric_samples`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_transport_metric_samples() -> Array[GFNetworkTransportMetrics]:
```

获取按时间排序的传输指标历史副本。

返回：最旧到最新的指标快照。

结构：

- `return`: Array[GFNetworkTransportMetrics] bounded metric samples.

<a id="member-gfnetworkutility-methods-clear_transport_metric_samples"></a>

### `clear_transport_metric_samples`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear_transport_metric_samples() -> void:
```

清空传输指标历史。

<a id="member-gfnetworkutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取网络工具调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary including backend, session, channels, validator, and transport metrics.
