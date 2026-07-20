# GFRequestOutboxUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_request_outbox_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用离线请求队列。 负责把项目提交的请求描述持久化、按重试策略重放，并通过 transport_callback 交给项目自己的网络、SDK 或工具链发送。它不内置任何账号、云服务或业务协议。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`request_enqueued`](#member-gfrequestoutboxutility-signals-request_enqueued) | `signal request_enqueued(envelope: GFRequestEnvelope)` |
| 信号 | [`request_started`](#member-gfrequestoutboxutility-signals-request_started) | `signal request_started(envelope: GFRequestEnvelope)` |
| 信号 | [`request_completed`](#member-gfrequestoutboxutility-signals-request_completed) | `signal request_completed(envelope: GFRequestEnvelope, result: Dictionary)` |
| 信号 | [`request_failed`](#member-gfrequestoutboxutility-signals-request_failed) | `signal request_failed(envelope: GFRequestEnvelope, result: Dictionary)` |
| 信号 | [`queue_changed`](#member-gfrequestoutboxutility-signals-queue_changed) | `signal queue_changed(snapshot: Dictionary)` |
| 信号 | [`persistence_failed`](#member-gfrequestoutboxutility-signals-persistence_failed) | `signal persistence_failed(operation: StringName, error: Error, path: String)` |
| 属性 | [`storage_path`](#member-gfrequestoutboxutility-properties-storage_path) | `var storage_path: String = "user://gf_request_outbox.json"` |
| 属性 | [`auto_load_on_init`](#member-gfrequestoutboxutility-properties-auto_load_on_init) | `var auto_load_on_init: bool = true` |
| 属性 | [`auto_persist`](#member-gfrequestoutboxutility-properties-auto_persist) | `var auto_persist: bool = true` |
| 属性 | [`max_queue_size`](#member-gfrequestoutboxutility-properties-max_queue_size) | `var max_queue_size: int = 128` |
| 属性 | [`default_max_attempts`](#member-gfrequestoutboxutility-properties-default_max_attempts) | `var default_max_attempts: int = 3` |
| 属性 | [`retry_delays_msec`](#member-gfrequestoutboxutility-properties-retry_delays_msec) | `var retry_delays_msec: Array[int] = [500, 1000, 2000, 5000]` |
| 属性 | [`keep_failed_requests`](#member-gfrequestoutboxutility-properties-keep_failed_requests) | `var keep_failed_requests: bool = true` |
| 属性 | [`max_failed_requests`](#member-gfrequestoutboxutility-properties-max_failed_requests) | `var max_failed_requests: int = 32` |
| 属性 | [`transport_callback`](#member-gfrequestoutboxutility-properties-transport_callback) | `var transport_callback: Callable = Callable()` |
| 属性 | [`replay_filter`](#member-gfrequestoutboxutility-properties-replay_filter) | `var replay_filter: Callable = Callable()` |
| 方法 | [`init`](#member-gfrequestoutboxutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfrequestoutboxutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`enqueue_request`](#member-gfrequestoutboxutility-methods-enqueue_request) | `func enqueue_request( method: int, url: String, body: Dictionary = {}, headers: PackedStringArray = PackedStringArray(), metadata: Dictionary = {} ) -> GFRequestEnvelope:` |
| 方法 | [`enqueue`](#member-gfrequestoutboxutility-methods-enqueue) | `func enqueue(envelope: GFRequestEnvelope) -> bool:` |
| 方法 | [`replay`](#member-gfrequestoutboxutility-methods-replay) | `func replay(max_count: int = 0) -> Dictionary:` |
| 方法 | [`remove_request`](#member-gfrequestoutboxutility-methods-remove_request) | `func remove_request(request_id: StringName) -> bool:` |
| 方法 | [`clear_queue`](#member-gfrequestoutboxutility-methods-clear_queue) | `func clear_queue() -> void:` |
| 方法 | [`clear_failed_requests`](#member-gfrequestoutboxutility-methods-clear_failed_requests) | `func clear_failed_requests() -> void:` |
| 方法 | [`get_queue_size`](#member-gfrequestoutboxutility-methods-get_queue_size) | `func get_queue_size() -> int:` |
| 方法 | [`get_failed_request_count`](#member-gfrequestoutboxutility-methods-get_failed_request_count) | `func get_failed_request_count() -> int:` |
| 方法 | [`get_pending_requests`](#member-gfrequestoutboxutility-methods-get_pending_requests) | `func get_pending_requests() -> Array[GFRequestEnvelope]:` |
| 方法 | [`get_failed_requests`](#member-gfrequestoutboxutility-methods-get_failed_requests) | `func get_failed_requests() -> Array[GFRequestEnvelope]:` |
| 方法 | [`save_queue`](#member-gfrequestoutboxutility-methods-save_queue) | `func save_queue() -> Error:` |
| 方法 | [`load_queue`](#member-gfrequestoutboxutility-methods-load_queue) | `func load_queue() -> Error:` |
| 方法 | [`get_debug_snapshot`](#member-gfrequestoutboxutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfrequestoutboxutility-signals-request_enqueued"></a>

### `request_enqueued`

- API：`public`

```gdscript
signal request_enqueued(envelope: GFRequestEnvelope)
```

请求成功进入队列。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 请求描述。 |

<a id="member-gfrequestoutboxutility-signals-request_started"></a>

### `request_started`

- API：`public`

```gdscript
signal request_started(envelope: GFRequestEnvelope)
```

请求开始重放。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 请求描述。 |

<a id="member-gfrequestoutboxutility-signals-request_completed"></a>

### `request_completed`

- API：`public`

```gdscript
signal request_completed(envelope: GFRequestEnvelope, result: Dictionary)
```

请求成功完成。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 请求描述。 |
| `result` | transport 返回的结果字典。 |

结构：

- `result`: Dictionary，由 transport_callback 返回；ok 或 success=true 表示完成。

<a id="member-gfrequestoutboxutility-signals-request_failed"></a>

### `request_failed`

- API：`public`

```gdscript
signal request_failed(envelope: GFRequestEnvelope, result: Dictionary)
```

请求失败。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 请求描述。 |
| `result` | transport 返回的结果字典。 |

结构：

- `result`: Dictionary，由 transport_callback 返回，包含 error 或 reason 字段。

<a id="member-gfrequestoutboxutility-signals-queue_changed"></a>

### `queue_changed`

- API：`public`

```gdscript
signal queue_changed(snapshot: Dictionary)
```

队列快照变化。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 调试快照。 |

结构：

- `snapshot`: Dictionary，由 get_debug_snapshot() 返回的调试快照。

<a id="member-gfrequestoutboxutility-signals-persistence_failed"></a>

### `persistence_failed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal persistence_failed(operation: StringName, error: Error, path: String)
```

队列持久化操作失败。

参数：

| 名称 | 说明 |
|---|---|
| `operation` | 失败操作，当前为 save 或 load；load 包含恢复候选提升。 |
| `error` | Godot 错误码。 |
| `path` | 队列持久化路径。 |

## 属性

<a id="member-gfrequestoutboxutility-properties-storage_path"></a>

### `storage_path`

- API：`public`

```gdscript
var storage_path: String = "user://gf_request_outbox.json"
```

队列持久化路径。

<a id="member-gfrequestoutboxutility-properties-auto_load_on_init"></a>

### `auto_load_on_init`

- API：`public`

```gdscript
var auto_load_on_init: bool = true
```

init() 时是否自动读取持久化队列。

<a id="member-gfrequestoutboxutility-properties-auto_persist"></a>

### `auto_persist`

- API：`public`

```gdscript
var auto_persist: bool = true
```

队列变化后是否自动写入 storage_path。

<a id="member-gfrequestoutboxutility-properties-max_queue_size"></a>

### `max_queue_size`

- API：`public`

```gdscript
var max_queue_size: int = 128
```

最大等待队列长度；小于等于 0 表示不限制。

<a id="member-gfrequestoutboxutility-properties-default_max_attempts"></a>

### `default_max_attempts`

- API：`public`

```gdscript
var default_max_attempts: int = 3
```

新入队请求默认最大尝试次数；小于等于 0 表示不限制。

<a id="member-gfrequestoutboxutility-properties-retry_delays_msec"></a>

### `retry_delays_msec`

- API：`public`

```gdscript
var retry_delays_msec: Array[int] = [500, 1000, 2000, 5000]
```

重试延迟序列，单位毫秒；超过长度后复用最后一个值。

结构：

- `retry_delays_msec`: Array，按毫秒记录的重试延迟列表。

<a id="member-gfrequestoutboxutility-properties-keep_failed_requests"></a>

### `keep_failed_requests`

- API：`public`

```gdscript
var keep_failed_requests: bool = true
```

请求耗尽尝试次数后是否保留在失败列表中。

<a id="member-gfrequestoutboxutility-properties-max_failed_requests"></a>

### `max_failed_requests`

- API：`public`

```gdscript
var max_failed_requests: int = 32
```

失败列表最多保留数量；小于等于 0 表示不保留。

<a id="member-gfrequestoutboxutility-properties-transport_callback"></a>

### `transport_callback`

- API：`public`

```gdscript
var transport_callback: Callable = Callable()
```

传输回调，签名为 func(envelope: GFRequestEnvelope) -> Dictionary；也可返回会发出结果值的 Signal。

<a id="member-gfrequestoutboxutility-properties-replay_filter"></a>

### `replay_filter`

- API：`public`

```gdscript
var replay_filter: Callable = Callable()
```

可选重放过滤回调，签名为 func(envelope: GFRequestEnvelope) -> bool。

## 方法

<a id="member-gfrequestoutboxutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化请求 Outbox，并按配置读取持久化队列。

<a id="member-gfrequestoutboxutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

按配置保存队列并清理运行时状态。

<a id="member-gfrequestoutboxutility-methods-enqueue_request"></a>

### `enqueue_request`

- API：`public`

```gdscript
func enqueue_request( method: int, url: String, body: Dictionary = {}, headers: PackedStringArray = PackedStringArray(), metadata: Dictionary = {} ) -> GFRequestEnvelope:
```

创建并入队一个请求。

参数：

| 名称 | 说明 |
|---|---|
| `method` | HTTPClient.Method 数值。 |
| `url` | 请求目标地址或项目自定义端点。 |
| `body` | 请求载荷。 |
| `headers` | 请求 Header。 |
| `metadata` | 项目自定义元数据。 |

返回：入队成功时返回请求描述；失败返回 null。

结构：

- `body`: Dictionary，项目传输层持有的请求载荷。
- `metadata`: Dictionary，随请求持久化的项目侧元数据。

<a id="member-gfrequestoutboxutility-methods-enqueue"></a>

### `enqueue`

- API：`public`

```gdscript
func enqueue(envelope: GFRequestEnvelope) -> bool:
```

入队已有请求描述。

参数：

| 名称 | 说明 |
|---|---|
| `envelope` | 请求描述。 |

返回：入队成功返回 true。

<a id="member-gfrequestoutboxutility-methods-replay"></a>

### `replay`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func replay(max_count: int = 0) -> Dictionary:
```

重放可尝试的请求；恢复出的已耗尽 pending 会直接迁移到失败列表而不再次发送。

参数：

| 名称 | 说明 |
|---|---|
| `max_count` | 最多处理数量；小于等于 0 表示不限制。 |

返回：重放报告。

结构：

- `return`: Dictionary，包含 ok、processed、succeeded、failed、recovered_exhausted、skipped、pending、failed_stored、reason 和 persistence_error。

<a id="member-gfrequestoutboxutility-methods-remove_request"></a>

### `remove_request`

- API：`public`

```gdscript
func remove_request(request_id: StringName) -> bool:
```

移除指定请求。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | 请求标识。 |

返回：移除成功返回 true。

<a id="member-gfrequestoutboxutility-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue() -> void:
```

清空等待队列。

<a id="member-gfrequestoutboxutility-methods-clear_failed_requests"></a>

### `clear_failed_requests`

- API：`public`

```gdscript
func clear_failed_requests() -> void:
```

清空失败请求列表。

<a id="member-gfrequestoutboxutility-methods-get_queue_size"></a>

### `get_queue_size`

- API：`public`

```gdscript
func get_queue_size() -> int:
```

获取等待队列长度。

返回：队列长度。

<a id="member-gfrequestoutboxutility-methods-get_failed_request_count"></a>

### `get_failed_request_count`

- API：`public`

```gdscript
func get_failed_request_count() -> int:
```

获取失败请求数量。

返回：失败请求数量。

<a id="member-gfrequestoutboxutility-methods-get_pending_requests"></a>

### `get_pending_requests`

- API：`public`

```gdscript
func get_pending_requests() -> Array[GFRequestEnvelope]:
```

获取等待请求副本。

返回：请求副本数组。

结构：

- `return`: Array，当前等待重放的 GFRequestEnvelope 副本。

<a id="member-gfrequestoutboxutility-methods-get_failed_requests"></a>

### `get_failed_requests`

- API：`public`

```gdscript
func get_failed_requests() -> Array[GFRequestEnvelope]:
```

获取失败请求副本。

返回：失败请求副本数组。

结构：

- `return`: Array，重试耗尽后保存的 GFRequestEnvelope 副本。

<a id="member-gfrequestoutboxutility-methods-save_queue"></a>

### `save_queue`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func save_queue() -> Error:
```

以同目录临时文件校验、旧文件备份和原子替换保存队列到 storage_path。

返回：Godot 错误码。

<a id="member-gfrequestoutboxutility-methods-load_queue"></a>

### `load_queue`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func load_queue() -> Error:
```

从 storage_path 读取队列；正式文件缺失或损坏时会尝试有效临时文件与备份。

返回：Godot 错误码。

<a id="member-gfrequestoutboxutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含存储设置、队列计数、传输可用性、last_persistence_error、is_persisted 和请求 ID 列表。
