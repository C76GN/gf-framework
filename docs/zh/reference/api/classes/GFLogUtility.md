# GFLogUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/logging/gf_log_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

集中式日志系统。 取代原生 print / push_error，提供分级日志（DEBUG → FATAL）， 每条日志同时写入本地按日期命名的日志文件，进入内存环形缓存， 并通过信号和可插拔 sink 广播结构化日志条目。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`log_emitted`](#member-gflogutility-signals-log_emitted) | `signal log_emitted(level: int, tag: String, message: String)` |
| 信号 | [`log_entry_emitted`](#member-gflogutility-signals-log_entry_emitted) | `signal log_entry_emitted(entry: Dictionary)` |
| 信号 | [`previous_crash_detected`](#member-gflogutility-signals-previous_crash_detected) | `signal previous_crash_detected(marker: Dictionary)` |
| 枚举 | [`LogLevel`](#member-gflogutility-enums-loglevel) | `enum LogLevel` |
| 属性 | [`max_log_files`](#member-gflogutility-properties-max_log_files) | `var max_log_files: int:` |
| 属性 | [`flush_interval_msec`](#member-gflogutility-properties-flush_interval_msec) | `var flush_interval_msec: int = 250` |
| 属性 | [`flush_immediately`](#member-gflogutility-properties-flush_immediately) | `var flush_immediately: bool = false` |
| 属性 | [`min_level`](#member-gflogutility-properties-min_level) | `var min_level: int = LogLevel.DEBUG` |
| 属性 | [`max_memory_entries`](#member-gflogutility-properties-max_memory_entries) | `var max_memory_entries: int:` |
| 属性 | [`crash_marker_enabled`](#member-gflogutility-properties-crash_marker_enabled) | `var crash_marker_enabled: bool = true` |
| 属性 | [`trace_id`](#member-gflogutility-properties-trace_id) | `var trace_id: String = ""` |
| 方法 | [`init`](#member-gflogutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gflogutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`debug`](#member-gflogutility-methods-debug) | `func debug(tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`debug_lazy`](#member-gflogutility-methods-debug_lazy) | `func debug_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:` |
| 方法 | [`info`](#member-gflogutility-methods-info) | `func info(tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`info_lazy`](#member-gflogutility-methods-info_lazy) | `func info_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:` |
| 方法 | [`warn`](#member-gflogutility-methods-warn) | `func warn(tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`warn_lazy`](#member-gflogutility-methods-warn_lazy) | `func warn_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:` |
| 方法 | [`error`](#member-gflogutility-methods-error) | `func error(tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`error_lazy`](#member-gflogutility-methods-error_lazy) | `func error_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:` |
| 方法 | [`fatal`](#member-gflogutility-methods-fatal) | `func fatal(tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`fatal_lazy`](#member-gflogutility-methods-fatal_lazy) | `func fatal_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:` |
| 方法 | [`log`](#member-gflogutility-methods-log) | `func log(level: int, tag: String, msg: String, context: Dictionary = {}) -> void:` |
| 方法 | [`set_trace_id`](#member-gflogutility-methods-set_trace_id) | `func set_trace_id(value: String) -> void:` |
| 方法 | [`get_trace_id`](#member-gflogutility-methods-get_trace_id) | `func get_trace_id() -> String:` |
| 方法 | [`set_global_context`](#member-gflogutility-methods-set_global_context) | `func set_global_context(context: Dictionary) -> void:` |
| 方法 | [`set_global_context_provider`](#member-gflogutility-methods-set_global_context_provider) | `func set_global_context_provider(provider: Callable) -> void:` |
| 方法 | [`clear_global_context`](#member-gflogutility-methods-clear_global_context) | `func clear_global_context() -> void:` |
| 方法 | [`get_global_context`](#member-gflogutility-methods-get_global_context) | `func get_global_context() -> Dictionary:` |
| 方法 | [`was_previous_shutdown_clean`](#member-gflogutility-methods-was_previous_shutdown_clean) | `func was_previous_shutdown_clean() -> bool:` |
| 方法 | [`get_previous_crash_marker`](#member-gflogutility-methods-get_previous_crash_marker) | `func get_previous_crash_marker() -> Dictionary:` |
| 方法 | [`set_tag_muted`](#member-gflogutility-methods-set_tag_muted) | `func set_tag_muted(tag: String, muted: bool) -> void:` |
| 方法 | [`is_tag_muted`](#member-gflogutility-methods-is_tag_muted) | `func is_tag_muted(tag: String) -> bool:` |
| 方法 | [`add_sink`](#member-gflogutility-methods-add_sink) | `func add_sink(sink: GFLogSink) -> void:` |
| 方法 | [`remove_sink`](#member-gflogutility-methods-remove_sink) | `func remove_sink(sink: GFLogSink, shutdown: bool = true) -> void:` |
| 方法 | [`clear_sinks`](#member-gflogutility-methods-clear_sinks) | `func clear_sinks(shutdown: bool = true) -> void:` |
| 方法 | [`get_sinks`](#member-gflogutility-methods-get_sinks) | `func get_sinks() -> Array[GFLogSink]:` |
| 方法 | [`flush_sinks`](#member-gflogutility-methods-flush_sinks) | `func flush_sinks() -> void:` |
| 方法 | [`get_recent_entries`](#member-gflogutility-methods-get_recent_entries) | `func get_recent_entries(count: int = -1) -> Array[Dictionary]:` |
| 方法 | [`get_entries`](#member-gflogutility-methods-get_entries) | `func get_entries(offset: int = 0, count: int = -1) -> Array[Dictionary]:` |
| 方法 | [`get_memory_sequence`](#member-gflogutility-methods-get_memory_sequence) | `func get_memory_sequence() -> int:` |
| 方法 | [`get_entries_since`](#member-gflogutility-methods-get_entries_since) | `func get_entries_since(since_sequence: int, limit: int = -1) -> Dictionary:` |
| 方法 | [`get_memory_entry_count`](#member-gflogutility-methods-get_memory_entry_count) | `func get_memory_entry_count() -> int:` |
| 方法 | [`get_dropped_memory_entry_count`](#member-gflogutility-methods-get_dropped_memory_entry_count) | `func get_dropped_memory_entry_count() -> int:` |
| 方法 | [`get_log_file_path`](#member-gflogutility-methods-get_log_file_path) | `func get_log_file_path() -> String:` |
| 方法 | [`clear_memory_entries`](#member-gflogutility-methods-clear_memory_entries) | `func clear_memory_entries() -> void:` |
| 方法 | [`sanitize_log_value`](#member-gflogutility-methods-sanitize_log_value) | `static func sanitize_log_value(value: Variant) -> Variant:` |

## 信号

<a id="member-gflogutility-signals-log_emitted"></a>

### `log_emitted`

- API：`public`

```gdscript
signal log_emitted(level: int, tag: String, message: String)
```

每次打印日志时发出，供 UI 控制台等消费者捕捉。

参数：

| 名称 | 说明 |
|---|---|
| `level` | LogLevel 枚举值。 |
| `tag` | 日志标签。 |
| `message` | 日志内容。 |

<a id="member-gflogutility-signals-log_entry_emitted"></a>

### `log_entry_emitted`

- API：`public`

```gdscript
signal log_entry_emitted(entry: Dictionary)
```

每次打印日志时发出完整结构化条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 日志条目副本。 |

结构：

- `entry`: Dictionary log entry with timestamp, unix_time, ticks_msec, trace_id, level, level_name, tag, message, context, and text.

<a id="member-gflogutility-signals-previous_crash_detected"></a>

### `previous_crash_detected`

- API：`public`

```gdscript
signal previous_crash_detected(marker: Dictionary)
```

初始化时检测到上次运行未干净关闭后发出。

参数：

| 名称 | 说明 |
|---|---|
| `marker` | 上次运行留下的标记数据。 |

结构：

- `marker`: Dictionary crash marker with trace_id, started_at, and ticks_msec when available.

## 枚举

<a id="member-gflogutility-enums-loglevel"></a>

### `LogLevel`

- API：`public`

```gdscript
enum LogLevel {
	## 调试信息
	DEBUG,
	## 一般信息
	INFO,
	## 警告
	WARN,
	## 错误
	ERROR,
	## 致命错误
	FATAL,
}
```

日志等级，数值越大越严重。

## 属性

<a id="member-gflogutility-properties-max_log_files"></a>

### `max_log_files`

- API：`public`

```gdscript
var max_log_files: int:
```

最多保留的日志文件数量。

<a id="member-gflogutility-properties-flush_interval_msec"></a>

### `flush_interval_msec`

- API：`public`

```gdscript
var flush_interval_msec: int = 250
```

日志文件自动 flush 间隔。设为 0 时每条日志都立即 flush。

<a id="member-gflogutility-properties-flush_immediately"></a>

### `flush_immediately`

- API：`public`

```gdscript
var flush_immediately: bool = false
```

是否强制每条日志立即 flush。高可靠日志可开启，默认关闭以减少高频 IO。

<a id="member-gflogutility-properties-min_level"></a>

### `min_level`

- API：`public`

```gdscript
var min_level: int = LogLevel.DEBUG
```

最小输出等级。低于该等级的日志不会打印、写文件或发信号。

<a id="member-gflogutility-properties-max_memory_entries"></a>

### `max_memory_entries`

- API：`public`

```gdscript
var max_memory_entries: int:
```

内存中最多保留的最近日志条数。设为 0 可关闭内存缓存。

<a id="member-gflogutility-properties-crash_marker_enabled"></a>

### `crash_marker_enabled`

- API：`public`

```gdscript
var crash_marker_enabled: bool = true
```

是否写入运行中标记，用于下一次启动时判断上次是否未干净关闭。

<a id="member-gflogutility-properties-trace_id"></a>

### `trace_id`

- API：`public`

```gdscript
var trace_id: String = ""
```

当前日志 trace id。为空时 init() 会生成一个短 id。

## 方法

<a id="member-gflogutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

第一阶段初始化：创建日志目录、打开日志文件、清理旧文件。

<a id="member-gflogutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

销毁时关闭文件句柄。

<a id="member-gflogutility-methods-debug"></a>

### `debug`

- API：`public`

```gdscript
func debug(tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出 DEBUG 级别日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签（如模块名）。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-debug_lazy"></a>

### `debug_lazy`

- API：`public`

```gdscript
func debug_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
```

延迟输出 DEBUG 级别日志。只有日志未被过滤时才调用 message_builder。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `message_builder` | 延迟构造日志消息的回调。 |
| `context_builder` | 延迟构造结构化上下文的回调。 |

<a id="member-gflogutility-methods-info"></a>

### `info`

- API：`public`

```gdscript
func info(tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出 INFO 级别日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-info_lazy"></a>

### `info_lazy`

- API：`public`

```gdscript
func info_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
```

延迟输出 INFO 级别日志。只有日志未被过滤时才调用 message_builder。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `message_builder` | 延迟构造日志消息的回调。 |
| `context_builder` | 延迟构造结构化上下文的回调。 |

<a id="member-gflogutility-methods-warn"></a>

### `warn`

- API：`public`

```gdscript
func warn(tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出 WARN 级别日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-warn_lazy"></a>

### `warn_lazy`

- API：`public`

```gdscript
func warn_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
```

延迟输出 WARN 级别日志。只有日志未被过滤时才调用 message_builder。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `message_builder` | 延迟构造日志消息的回调。 |
| `context_builder` | 延迟构造结构化上下文的回调。 |

<a id="member-gflogutility-methods-error"></a>

### `error`

- API：`public`

```gdscript
func error(tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出 ERROR 级别日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-error_lazy"></a>

### `error_lazy`

- API：`public`

```gdscript
func error_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
```

延迟输出 ERROR 级别日志。只有日志未被过滤时才调用 message_builder。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `message_builder` | 延迟构造日志消息的回调。 |
| `context_builder` | 延迟构造结构化上下文的回调。 |

<a id="member-gflogutility-methods-fatal"></a>

### `fatal`

- API：`public`

```gdscript
func fatal(tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出 FATAL 级别日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-fatal_lazy"></a>

### `fatal_lazy`

- API：`public`

```gdscript
func fatal_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
```

延迟输出 FATAL 级别日志。只有日志未被过滤时才调用 message_builder。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |
| `message_builder` | 延迟构造日志消息的回调。 |
| `context_builder` | 延迟构造结构化上下文的回调。 |

<a id="member-gflogutility-methods-log"></a>

### `log`

- API：`public`

```gdscript
func log(level: int, tag: String, msg: String, context: Dictionary = {}) -> void:
```

输出指定等级日志。

参数：

| 名称 | 说明 |
|---|---|
| `level` | LogLevel 枚举值。 |
| `tag` | 日志标签。 |
| `msg` | 日志内容。 |
| `context` | 结构化上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] structured context merged into the log entry.

<a id="member-gflogutility-methods-set_trace_id"></a>

### `set_trace_id`

- API：`public`

```gdscript
func set_trace_id(value: String) -> void:
```

设置当前 trace id。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 新 trace id；为空时会重新生成。 |

<a id="member-gflogutility-methods-get_trace_id"></a>

### `get_trace_id`

- API：`public`

```gdscript
func get_trace_id() -> String:
```

获取当前 trace id。

返回：trace id 字符串。

<a id="member-gflogutility-methods-set_global_context"></a>

### `set_global_context`

- API：`public`

```gdscript
func set_global_context(context: Dictionary) -> void:
```

设置全局日志上下文字典。每条日志都会合并该字典，单条日志上下文优先级更高。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 全局上下文字典。 |

结构：

- `context`: Dictionary[String, Variant] sanitized global context merged into every log entry.

<a id="member-gflogutility-methods-set_global_context_provider"></a>

### `set_global_context_provider`

- API：`public`

```gdscript
func set_global_context_provider(provider: Callable) -> void:
```

设置全局日志上下文提供者。每条日志输出时会调用一次，返回 Dictionary 时参与合并。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 上下文提供者，签名为 `func() -> Dictionary`。 |

<a id="member-gflogutility-methods-clear_global_context"></a>

### `clear_global_context`

- API：`public`

```gdscript
func clear_global_context() -> void:
```

清空全局日志上下文和上下文提供者。

<a id="member-gflogutility-methods-get_global_context"></a>

### `get_global_context`

- API：`public`

```gdscript
func get_global_context() -> Dictionary:
```

获取全局日志上下文字典副本。

返回：全局上下文字典副本。

结构：

- `return`: Dictionary[String, Variant] sanitized global context.

<a id="member-gflogutility-methods-was_previous_shutdown_clean"></a>

### `was_previous_shutdown_clean`

- API：`public`

```gdscript
func was_previous_shutdown_clean() -> bool:
```

获取上次运行是否干净关闭。

返回：没有检测到运行中标记时返回 true。

<a id="member-gflogutility-methods-get_previous_crash_marker"></a>

### `get_previous_crash_marker`

- API：`public`

```gdscript
func get_previous_crash_marker() -> Dictionary:
```

获取上次未干净关闭时留下的标记数据。

返回：crash marker 副本。

结构：

- `return`: Dictionary crash marker with trace_id, started_at, and ticks_msec when available.

<a id="member-gflogutility-methods-set_tag_muted"></a>

### `set_tag_muted`

- API：`public`

```gdscript
func set_tag_muted(tag: String, muted: bool) -> void:
```

动态设置是否忽略特定标签的日志。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 要静音的标签。 |
| `muted` | 是否静音。如果为 true，该 tag 的日志将不再打印及记录。 |

<a id="member-gflogutility-methods-is_tag_muted"></a>

### `is_tag_muted`

- API：`public`

```gdscript
func is_tag_muted(tag: String) -> bool:
```

检查指定标签是否被静音。

参数：

| 名称 | 说明 |
|---|---|
| `tag` | 日志标签。 |

返回：已静音时返回 true。

<a id="member-gflogutility-methods-add_sink"></a>

### `add_sink`

- API：`public`

```gdscript
func add_sink(sink: GFLogSink) -> void:
```

注册日志 sink。

参数：

| 名称 | 说明 |
|---|---|
| `sink` | 要注册的 sink 实例。 |

<a id="member-gflogutility-methods-remove_sink"></a>

### `remove_sink`

- API：`public`

```gdscript
func remove_sink(sink: GFLogSink, shutdown: bool = true) -> void:
```

注销日志 sink。

参数：

| 名称 | 说明 |
|---|---|
| `sink` | 要注销的 sink 实例。 |
| `shutdown` | 是否调用 sink.shutdown()。 |

<a id="member-gflogutility-methods-clear_sinks"></a>

### `clear_sinks`

- API：`public`

```gdscript
func clear_sinks(shutdown: bool = true) -> void:
```

清空所有日志 sink。

参数：

| 名称 | 说明 |
|---|---|
| `shutdown` | 是否调用每个 sink 的 shutdown()。 |

<a id="member-gflogutility-methods-get_sinks"></a>

### `get_sinks`

- API：`public`

```gdscript
func get_sinks() -> Array[GFLogSink]:
```

获取已注册日志 sink。

返回：sink 列表副本。

<a id="member-gflogutility-methods-flush_sinks"></a>

### `flush_sinks`

- API：`public`

```gdscript
func flush_sinks() -> void:
```

刷新所有日志 sink。

<a id="member-gflogutility-methods-get_recent_entries"></a>

### `get_recent_entries`

- API：`public`

```gdscript
func get_recent_entries(count: int = -1) -> Array[Dictionary]:
```

获取最近的内存日志条目。

参数：

| 名称 | 说明 |
|---|---|
| `count` | 读取数量；小于 0 表示全部。 |

返回：从旧到新的日志条目数组。

结构：

- `return`: Array[Dictionary] of log entries from oldest to newest.

<a id="member-gflogutility-methods-get_entries"></a>

### `get_entries`

- API：`public`

```gdscript
func get_entries(offset: int = 0, count: int = -1) -> Array[Dictionary]:
```

按偏移读取内存日志条目。

参数：

| 名称 | 说明 |
|---|---|
| `offset` | 从最旧条目开始的偏移。 |
| `count` | 读取数量；小于 0 表示直到末尾。 |

返回：从旧到新的日志条目数组。

结构：

- `return`: Array[Dictionary] of log entries from oldest to newest.

<a id="member-gflogutility-methods-get_memory_sequence"></a>

### `get_memory_sequence`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_memory_sequence() -> int:
```

获取内存日志的下一个序列游标。 该值随每条通过过滤的日志递增，可作为 get_entries_since() 的 since_sequence。

返回：下一条日志将使用的序列号。

<a id="member-gflogutility-methods-get_entries_since"></a>

### `get_entries_since`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_entries_since(since_sequence: int, limit: int = -1) -> Dictionary:
```

按序列游标读取新增内存日志。 适合诊断 UI、远端采集器或支持报告面板轮询日志缓存，而不需要每次重新读取全部最近日志。

参数：

| 名称 | 说明 |
|---|---|
| `since_sequence` | 调用方上次保存的 next_sequence；表示下一条想读取的日志序列。 |
| `limit` | 最多返回的条目数量；小于 0 表示读取所有可用条目。 |

返回：增量读取报告。

结构：

- `return`: Dictionary with requested_sequence, oldest_sequence, next_sequence, current_sequence, entries, truncated, has_more, missed_count, and dropped_count fields.

<a id="member-gflogutility-methods-get_memory_entry_count"></a>

### `get_memory_entry_count`

- API：`public`

```gdscript
func get_memory_entry_count() -> int:
```

获取当前内存日志条目数量。

返回：条目数量。

<a id="member-gflogutility-methods-get_dropped_memory_entry_count"></a>

### `get_dropped_memory_entry_count`

- API：`public`

```gdscript
func get_dropped_memory_entry_count() -> int:
```

获取因内存上限被丢弃的日志条目数量。

返回：丢弃数量。

<a id="member-gflogutility-methods-get_log_file_path"></a>

### `get_log_file_path`

- API：`public`

```gdscript
func get_log_file_path() -> String:
```

获取当前日志文件路径。

返回：日志文件路径。

<a id="member-gflogutility-methods-clear_memory_entries"></a>

### `clear_memory_entries`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_memory_entries() -> void:
```

清空内存日志缓存。 已分配的序列游标不会重置；调用方仍可用 get_memory_sequence() 继续进行增量读取。

<a id="member-gflogutility-methods-sanitize_log_value"></a>

### `sanitize_log_value`

- API：`public`

```gdscript
static func sanitize_log_value(value: Variant) -> Variant:
```

清洗任意值，使它适合进入结构化日志和 JSON sink。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要清洗的值。 |

返回：清洗后的值。

结构：

- `value`: Variant log context value to sanitize.
- `return`: Variant JSON-compatible value with object metadata, truncated strings, and circular references marked.
