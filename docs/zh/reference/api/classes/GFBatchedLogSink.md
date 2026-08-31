# GFBatchedLogSink

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/logging/gf_batched_log_sink.gd`
- 模块：`Standard`
- 继承：`GFLogSink`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

结构化日志批量转发 sink。 该 sink 只负责清洗、缓冲和分批，把实际传输交给 sender_callback 或 batch_ready 信号。 它不绑定任何远端服务、HTTP 协议或业务字段。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`batch_ready`](#member-gfbatchedlogsink-signals-batch_ready) | `signal batch_ready(batch: Array[Dictionary])` |
| 属性 | [`batch_size`](#member-gfbatchedlogsink-properties-batch_size) | `var batch_size: int = 20:` |
| 属性 | [`max_queue_size`](#member-gfbatchedlogsink-properties-max_queue_size) | `var max_queue_size: int = 500:` |
| 属性 | [`flush_interval_msec`](#member-gfbatchedlogsink-properties-flush_interval_msec) | `var flush_interval_msec: int = 1000:` |
| 属性 | [`omit_formatted_text`](#member-gfbatchedlogsink-properties-omit_formatted_text) | `var omit_formatted_text: bool = false` |
| 属性 | [`metadata`](#member-gfbatchedlogsink-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`sender_callback`](#member-gfbatchedlogsink-properties-sender_callback) | `var sender_callback: Callable = Callable()` |
| 方法 | [`get_report_redaction_profile`](#member-gfbatchedlogsink-methods-get_report_redaction_profile) | `func get_report_redaction_profile() -> String:` |
| 方法 | [`init`](#member-gfbatchedlogsink-methods-init) | `func init(_owner: Object) -> void:` |
| 方法 | [`write`](#member-gfbatchedlogsink-methods-write) | `func write(entry: Dictionary) -> void:` |
| 方法 | [`tick`](#member-gfbatchedlogsink-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`flush`](#member-gfbatchedlogsink-methods-flush) | `func flush() -> void:` |
| 方法 | [`shutdown`](#member-gfbatchedlogsink-methods-shutdown) | `func shutdown() -> void:` |
| 方法 | [`get_pending_count`](#member-gfbatchedlogsink-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_dropped_count`](#member-gfbatchedlogsink-methods-get_dropped_count) | `func get_dropped_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfbatchedlogsink-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfbatchedlogsink-signals-batch_ready"></a>

### `batch_ready`

- API：`public`

```gdscript
signal batch_ready(batch: Array[Dictionary])
```

批次准备好时发出。

参数：

| 名称 | 说明 |
|---|---|
| `batch` | 日志批次数组。 |

结构：

- `batch`: Array[Dictionary] of sanitized log entries.

## 属性

<a id="member-gfbatchedlogsink-properties-batch_size"></a>

### `batch_size`

- API：`public`

```gdscript
var batch_size: int = 20:
```

每批最多包含的日志条数。

<a id="member-gfbatchedlogsink-properties-max_queue_size"></a>

### `max_queue_size`

- API：`public`

```gdscript
var max_queue_size: int = 500:
```

队列最多保留的日志条数，超出时丢弃最旧条目。

<a id="member-gfbatchedlogsink-properties-flush_interval_msec"></a>

### `flush_interval_msec`

- API：`public`

```gdscript
var flush_interval_msec: int = 1000:
```

自动 flush 间隔。设为 0 时只按 batch_size 或显式 flush。

<a id="member-gfbatchedlogsink-properties-omit_formatted_text"></a>

### `omit_formatted_text`

- API：`public`

```gdscript
var omit_formatted_text: bool = false
```

是否在转发前移除 text 字段，减少重复载荷。

<a id="member-gfbatchedlogsink-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

发送时附加到批次外层的元数据。

结构：

- `metadata`: Dictionary[String, Variant] copied into each outgoing payload.

<a id="member-gfbatchedlogsink-properties-sender_callback"></a>

### `sender_callback`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var sender_callback: Callable = Callable()
```

项目提供的发送回调，签名为 func(payload: Dictionary) -> Dictionary。

结构：

- `sender_callback`: Callable 接收包含 logs、metadata 和 dropped_count 的 Dictionary，并返回包含必需 ok: bool、可选 accepted: int 与 error: String 的 Dictionary；缺失或类型错误时 fail-closed。

## 方法

<a id="member-gfbatchedlogsink-methods-get_report_redaction_profile"></a>

### `get_report_redaction_profile`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_report_redaction_profile() -> String:
```

使用外发批量日志所需的 privacy 脱敏 profile。

返回：privacy profile 名称。

结构：

- `return`: String naming GFReportValueCodec.REDACTION_PROFILE_PRIVACY.

<a id="member-gfbatchedlogsink-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init(_owner: Object) -> void:
```

初始化 sink。

参数：

| 名称 | 说明 |
|---|---|
| `_owner` | 持有该 sink 的日志工具。 |

<a id="member-gfbatchedlogsink-methods-write"></a>

### `write`

- API：`public`

```gdscript
func write(entry: Dictionary) -> void:
```

写入一条结构化日志。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 日志条目字典。 |

结构：

- `entry`: Dictionary log entry produced by GFLogUtility.

<a id="member-gfbatchedlogsink-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进自动 flush 计时；由持有该 sink 的 GFLogUtility 调用。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）；非有限或非正数不会推进状态。 |

<a id="member-gfbatchedlogsink-methods-flush"></a>

### `flush`

- API：`public`

```gdscript
func flush() -> void:
```

发送当前队列中的一批日志。

<a id="member-gfbatchedlogsink-methods-shutdown"></a>

### `shutdown`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func shutdown() -> void:
```

关闭 sink，并在同步发送持续取得进展时排空全部批次。

<a id="member-gfbatchedlogsink-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`

```gdscript
func get_pending_count() -> int:
```

获取队列中的日志数量。

返回：待发送日志数量。

<a id="member-gfbatchedlogsink-methods-get_dropped_count"></a>

### `get_dropped_count`

- API：`public`

```gdscript
func get_dropped_count() -> int:
```

获取因队列上限丢弃的日志数量。

返回：丢弃数量。

<a id="member-gfbatchedlogsink-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：sink 状态字典。

结构：

- `return`: Dictionary with pending_count, dropped_count, failed_send_count, last_error, batch_size, max_queue_size, flush_interval_msec, and has_sender_callback.
