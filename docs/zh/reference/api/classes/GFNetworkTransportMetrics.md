# GFNetworkTransportMetrics

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/runtime/gf_network_transport_metrics.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

网络传输指标快照。 指标只在显式写入后才视为已知，避免用 0 混淆“真实为零”与“后端不支持”。 内置指标覆盖流量、包数、连接时长、队列、延迟、抖动和丢包率；Adapter 也可以写入命名稳定的自定义非负指标。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`BYTES_SENT`](#member-gfnetworktransportmetrics-constants-bytes_sent) | `const BYTES_SENT: StringName = &"bytes_sent"` |
| 常量 | [`BYTES_RECEIVED`](#member-gfnetworktransportmetrics-constants-bytes_received) | `const BYTES_RECEIVED: StringName = &"bytes_received"` |
| 常量 | [`PACKETS_SENT`](#member-gfnetworktransportmetrics-constants-packets_sent) | `const PACKETS_SENT: StringName = &"packets_sent"` |
| 常量 | [`PACKETS_RECEIVED`](#member-gfnetworktransportmetrics-constants-packets_received) | `const PACKETS_RECEIVED: StringName = &"packets_received"` |
| 常量 | [`CONNECTION_AGE_MSEC`](#member-gfnetworktransportmetrics-constants-connection_age_msec) | `const CONNECTION_AGE_MSEC: StringName = &"connection_age_msec"` |
| 常量 | [`ROUND_TRIP_TIME_MSEC`](#member-gfnetworktransportmetrics-constants-round_trip_time_msec) | `const ROUND_TRIP_TIME_MSEC: StringName = &"round_trip_time_msec"` |
| 常量 | [`JITTER_MSEC`](#member-gfnetworktransportmetrics-constants-jitter_msec) | `const JITTER_MSEC: StringName = &"jitter_msec"` |
| 常量 | [`PACKET_LOSS_RATIO`](#member-gfnetworktransportmetrics-constants-packet_loss_ratio) | `const PACKET_LOSS_RATIO: StringName = &"packet_loss_ratio"` |
| 常量 | [`SEND_QUEUE_PACKETS`](#member-gfnetworktransportmetrics-constants-send_queue_packets) | `const SEND_QUEUE_PACKETS: StringName = &"send_queue_packets"` |
| 常量 | [`RECEIVE_QUEUE_PACKETS`](#member-gfnetworktransportmetrics-constants-receive_queue_packets) | `const RECEIVE_QUEUE_PACKETS: StringName = &"receive_queue_packets"` |
| 属性 | [`sample_time_msec`](#member-gfnetworktransportmetrics-properties-sample_time_msec) | `var sample_time_msec: int = 0` |
| 属性 | [`sample_window_msec`](#member-gfnetworktransportmetrics-properties-sample_window_msec) | `var sample_window_msec: int = 0` |
| 方法 | [`set_metric`](#member-gfnetworktransportmetrics-methods-set_metric) | `func set_metric(metric_id: StringName, value: float) -> bool:` |
| 方法 | [`clear_metric`](#member-gfnetworktransportmetrics-methods-clear_metric) | `func clear_metric(metric_id: StringName) -> bool:` |
| 方法 | [`has_metric`](#member-gfnetworktransportmetrics-methods-has_metric) | `func has_metric(metric_id: StringName) -> bool:` |
| 方法 | [`get_metric`](#member-gfnetworktransportmetrics-methods-get_metric) | `func get_metric(metric_id: StringName, default_value: float = 0.0) -> float:` |
| 方法 | [`get_metric_ids`](#member-gfnetworktransportmetrics-methods-get_metric_ids) | `func get_metric_ids() -> PackedStringArray:` |
| 方法 | [`merge_from`](#member-gfnetworktransportmetrics-methods-merge_from) | `func merge_from(other: GFNetworkTransportMetrics) -> void:` |
| 方法 | [`to_dict`](#member-gfnetworktransportmetrics-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfnetworktransportmetrics-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_metrics`](#member-gfnetworktransportmetrics-methods-duplicate_metrics) | `func duplicate_metrics() -> GFNetworkTransportMetrics:` |
| 方法 | [`from_dict`](#member-gfnetworktransportmetrics-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFNetworkTransportMetrics:` |

## 常量

<a id="member-gfnetworktransportmetrics-constants-bytes_sent"></a>

### `BYTES_SENT`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const BYTES_SENT: StringName = &"bytes_sent"
```

已发送字节数。

<a id="member-gfnetworktransportmetrics-constants-bytes_received"></a>

### `BYTES_RECEIVED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const BYTES_RECEIVED: StringName = &"bytes_received"
```

已接收字节数。

<a id="member-gfnetworktransportmetrics-constants-packets_sent"></a>

### `PACKETS_SENT`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const PACKETS_SENT: StringName = &"packets_sent"
```

已发送包数。

<a id="member-gfnetworktransportmetrics-constants-packets_received"></a>

### `PACKETS_RECEIVED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const PACKETS_RECEIVED: StringName = &"packets_received"
```

已接收包数。

<a id="member-gfnetworktransportmetrics-constants-connection_age_msec"></a>

### `CONNECTION_AGE_MSEC`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const CONNECTION_AGE_MSEC: StringName = &"connection_age_msec"
```

当前连接时长，单位毫秒。

<a id="member-gfnetworktransportmetrics-constants-round_trip_time_msec"></a>

### `ROUND_TRIP_TIME_MSEC`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const ROUND_TRIP_TIME_MSEC: StringName = &"round_trip_time_msec"
```

往返延迟，单位毫秒。

<a id="member-gfnetworktransportmetrics-constants-jitter_msec"></a>

### `JITTER_MSEC`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const JITTER_MSEC: StringName = &"jitter_msec"
```

延迟抖动，单位毫秒。

<a id="member-gfnetworktransportmetrics-constants-packet_loss_ratio"></a>

### `PACKET_LOSS_RATIO`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const PACKET_LOSS_RATIO: StringName = &"packet_loss_ratio"
```

丢包率，取值范围为 0 到 1。

<a id="member-gfnetworktransportmetrics-constants-send_queue_packets"></a>

### `SEND_QUEUE_PACKETS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const SEND_QUEUE_PACKETS: StringName = &"send_queue_packets"
```

发送队列包数。

<a id="member-gfnetworktransportmetrics-constants-receive_queue_packets"></a>

### `RECEIVE_QUEUE_PACKETS`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const RECEIVE_QUEUE_PACKETS: StringName = &"receive_queue_packets"
```

接收队列包数。

## 属性

<a id="member-gfnetworktransportmetrics-properties-sample_time_msec"></a>

### `sample_time_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var sample_time_msec: int = 0
```

采样单调时间戳，单位毫秒。

<a id="member-gfnetworktransportmetrics-properties-sample_window_msec"></a>

### `sample_window_msec`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var sample_window_msec: int = 0
```

统计窗口长度，单位毫秒；0 表示累计值或未知窗口。

## 方法

<a id="member-gfnetworktransportmetrics-methods-set_metric"></a>

### `set_metric`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func set_metric(metric_id: StringName, value: float) -> bool:
```

写入一个已知指标。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 非空稳定指标 ID。 |
| `value` | 有限非负值；packet_loss_ratio 额外限制在 0 到 1。 |

返回：指标合法并已写入时返回 true。

<a id="member-gfnetworktransportmetrics-methods-clear_metric"></a>

### `clear_metric`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_metric(metric_id: StringName) -> bool:
```

移除一个指标，使其恢复为未知。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标 ID。 |

返回：指标原本存在时返回 true。

<a id="member-gfnetworktransportmetrics-methods-has_metric"></a>

### `has_metric`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func has_metric(metric_id: StringName) -> bool:
```

检查指标是否已知。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标 ID。 |

返回：指标存在时返回 true。

<a id="member-gfnetworktransportmetrics-methods-get_metric"></a>

### `get_metric`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_metric(metric_id: StringName, default_value: float = 0.0) -> float:
```

获取指标值。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标 ID。 |
| `default_value` | 指标未知时的返回值。 |

返回：指标值或默认值。

<a id="member-gfnetworktransportmetrics-methods-get_metric_ids"></a>

### `get_metric_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_metric_ids() -> PackedStringArray:
```

获取排序后的已知指标 ID。

返回：已知指标 ID。

<a id="member-gfnetworktransportmetrics-methods-merge_from"></a>

### `merge_from`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func merge_from(other: GFNetworkTransportMetrics) -> void:
```

合并另一个快照中的已知指标。

参数：

| 名称 | 说明 |
|---|---|
| `other` | 指标来源。 |

<a id="member-gfnetworktransportmetrics-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为 JSON 安全字典。

返回：指标快照字典。

结构：

- `return`: Dictionary with sample_time_msec, sample_window_msec, and metrics.

<a id="member-gfnetworktransportmetrics-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用指标快照。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 指标快照字典。 |

结构：

- `data`: Dictionary with sample_time_msec, sample_window_msec, and metrics.

<a id="member-gfnetworktransportmetrics-methods-duplicate_metrics"></a>

### `duplicate_metrics`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func duplicate_metrics() -> GFNetworkTransportMetrics:
```

创建快照深拷贝。

返回：新指标快照。

<a id="member-gfnetworktransportmetrics-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFNetworkTransportMetrics:
```

从字典创建指标快照。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 指标快照字典。 |

返回：新指标快照。

结构：

- `data`: Dictionary with sample_time_msec, sample_window_msec, and metrics.
