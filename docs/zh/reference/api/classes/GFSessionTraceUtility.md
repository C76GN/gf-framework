# GFSessionTraceUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_session_trace_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

有界的运行时会话轨迹记录器。 项目必须先显式注册通道，才能记录输入、路由、存档、网络或其他语义事件。 轨迹只保存经过技术脱敏和字节预算约束的结构化数据，不扫描场景树、节点属性或业务状态。 项目仍需通过字段白名单排除账号、令牌和其他无法由通用编码器识别的业务秘密。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`session_started`](#member-gfsessiontraceutility-signals-session_started) | `signal session_started(session_id: StringName, context: Dictionary)` |
| 信号 | [`session_stopped`](#member-gfsessiontraceutility-signals-session_stopped) | `signal session_stopped(summary: Dictionary)` |
| 信号 | [`event_recorded`](#member-gfsessiontraceutility-signals-event_recorded) | `signal event_recorded(event: Dictionary)` |
| 信号 | [`event_rejected`](#member-gfsessiontraceutility-signals-event_rejected) | `signal event_rejected(channel_id: StringName, event_id: StringName, reason: StringName)` |
| 常量 | [`DEFAULT_MAX_EVENTS`](#member-gfsessiontraceutility-constants-default_max_events) | `const DEFAULT_MAX_EVENTS: int = 512` |
| 常量 | [`DEFAULT_MAX_EVENT_BUFFER_BYTES`](#member-gfsessiontraceutility-constants-default_max_event_buffer_bytes) | `const DEFAULT_MAX_EVENT_BUFFER_BYTES: int = 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_EVENT_BYTES`](#member-gfsessiontraceutility-constants-default_max_event_bytes) | `const DEFAULT_MAX_EVENT_BYTES: int = 16 * 1024` |
| 常量 | [`DEFAULT_MAX_CHANNELS`](#member-gfsessiontraceutility-constants-default_max_channels) | `const DEFAULT_MAX_CHANNELS: int = 32` |
| 常量 | [`DEFAULT_MAX_SNAPSHOT_PROVIDERS`](#member-gfsessiontraceutility-constants-default_max_snapshot_providers) | `const DEFAULT_MAX_SNAPSHOT_PROVIDERS: int = 32` |
| 常量 | [`DEFAULT_MAX_JOURNAL_EVENTS`](#member-gfsessiontraceutility-constants-default_max_journal_events) | `const DEFAULT_MAX_JOURNAL_EVENTS: int = 2048` |
| 常量 | [`REJECT_SESSION_INACTIVE`](#member-gfsessiontraceutility-constants-reject_session_inactive) | `const REJECT_SESSION_INACTIVE: StringName = &"session_inactive"` |
| 常量 | [`REJECT_UNKNOWN_CHANNEL`](#member-gfsessiontraceutility-constants-reject_unknown_channel) | `const REJECT_UNKNOWN_CHANNEL: StringName = &"unknown_channel"` |
| 常量 | [`REJECT_CHANNEL_DISABLED`](#member-gfsessiontraceutility-constants-reject_channel_disabled) | `const REJECT_CHANNEL_DISABLED: StringName = &"channel_disabled"` |
| 常量 | [`REJECT_INVALID_EVENT_ID`](#member-gfsessiontraceutility-constants-reject_invalid_event_id) | `const REJECT_INVALID_EVENT_ID: StringName = &"invalid_event_id"` |
| 常量 | [`REJECT_EVENT_TOO_LARGE`](#member-gfsessiontraceutility-constants-reject_event_too_large) | `const REJECT_EVENT_TOO_LARGE: StringName = &"event_too_large"` |
| 常量 | [`REJECT_INVALID_PROVIDER`](#member-gfsessiontraceutility-constants-reject_invalid_provider) | `const REJECT_INVALID_PROVIDER: StringName = &"invalid_provider"` |
| 常量 | [`REJECT_PROVIDER_REENTRANT`](#member-gfsessiontraceutility-constants-reject_provider_reentrant) | `const REJECT_PROVIDER_REENTRANT: StringName = &"provider_reentrant"` |
| 属性 | [`max_events`](#member-gfsessiontraceutility-properties-max_events) | `var max_events: int = DEFAULT_MAX_EVENTS:` |
| 属性 | [`max_event_buffer_bytes`](#member-gfsessiontraceutility-properties-max_event_buffer_bytes) | `var max_event_buffer_bytes: int = DEFAULT_MAX_EVENT_BUFFER_BYTES:` |
| 属性 | [`max_event_bytes`](#member-gfsessiontraceutility-properties-max_event_bytes) | `var max_event_bytes: int = DEFAULT_MAX_EVENT_BYTES:` |
| 属性 | [`max_channels`](#member-gfsessiontraceutility-properties-max_channels) | `var max_channels: int = DEFAULT_MAX_CHANNELS:` |
| 属性 | [`max_snapshot_providers`](#member-gfsessiontraceutility-properties-max_snapshot_providers) | `var max_snapshot_providers: int = DEFAULT_MAX_SNAPSHOT_PROVIDERS:` |
| 属性 | [`max_journal_events`](#member-gfsessiontraceutility-properties-max_journal_events) | `var max_journal_events: int = DEFAULT_MAX_JOURNAL_EVENTS:` |
| 属性 | [`redaction_profile`](#member-gfsessiontraceutility-properties-redaction_profile) | `var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY` |
| 方法 | [`dispose`](#member-gfsessiontraceutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`start_session`](#member-gfsessiontraceutility-methods-start_session) | `func start_session( requested_session_id: StringName = &"", context: Dictionary = {}, options: Dictionary = {} ) -> StringName:` |
| 方法 | [`stop_session`](#member-gfsessiontraceutility-methods-stop_session) | `func stop_session(reason: StringName = &"completed") -> Dictionary:` |
| 方法 | [`clear`](#member-gfsessiontraceutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`register_channel`](#member-gfsessiontraceutility-methods-register_channel) | `func register_channel(channel_id: StringName, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_channel`](#member-gfsessiontraceutility-methods-unregister_channel) | `func unregister_channel(channel_id: StringName) -> bool:` |
| 方法 | [`has_channel`](#member-gfsessiontraceutility-methods-has_channel) | `func has_channel(channel_id: StringName) -> bool:` |
| 方法 | [`set_channel_enabled`](#member-gfsessiontraceutility-methods-set_channel_enabled) | `func set_channel_enabled(channel_id: StringName, enabled: bool) -> bool:` |
| 方法 | [`get_channel_catalog`](#member-gfsessiontraceutility-methods-get_channel_catalog) | `func get_channel_catalog() -> Dictionary:` |
| 方法 | [`record_event`](#member-gfsessiontraceutility-methods-record_event) | `func record_event( channel_id: StringName, event_id: StringName, payload: Variant = null, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`register_snapshot_provider`](#member-gfsessiontraceutility-methods-register_snapshot_provider) | `func register_snapshot_provider( provider_id: StringName, channel_id: StringName, provider: Callable, options: Dictionary = {} ) -> bool:` |
| 方法 | [`unregister_snapshot_provider`](#member-gfsessiontraceutility-methods-unregister_snapshot_provider) | `func unregister_snapshot_provider(provider_id: StringName) -> bool:` |
| 方法 | [`capture_snapshot_provider`](#member-gfsessiontraceutility-methods-capture_snapshot_provider) | `func capture_snapshot_provider(provider_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_snapshot_provider_catalog`](#member-gfsessiontraceutility-methods-get_snapshot_provider_catalog) | `func get_snapshot_provider_catalog() -> Dictionary:` |
| 方法 | [`configure_journal_sink`](#member-gfsessiontraceutility-methods-configure_journal_sink) | `func configure_journal_sink(sink: GFLogSink, options: Dictionary = {}) -> bool:` |
| 方法 | [`flush_journal`](#member-gfsessiontraceutility-methods-flush_journal) | `func flush_journal() -> void:` |
| 方法 | [`clear_journal_sink`](#member-gfsessiontraceutility-methods-clear_journal_sink) | `func clear_journal_sink(shutdown: bool = false) -> void:` |
| 方法 | [`get_events`](#member-gfsessiontraceutility-methods-get_events) | `func get_events(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`build_snapshot`](#member-gfsessiontraceutility-methods-build_snapshot) | `func build_snapshot(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfsessiontraceutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfsessiontraceutility-signals-session_started"></a>

### `session_started`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal session_started(session_id: StringName, context: Dictionary)
```

会话开始后发出。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 当前会话标识。 |
| `context` | 已脱敏的会话上下文副本。 |

结构：

- `context`: Dictionary，由项目定义并经过 GFReportValueCodec 隐私脱敏和预算限制。

<a id="member-gfsessiontraceutility-signals-session_stopped"></a>

### `session_stopped`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal session_stopped(summary: Dictionary)
```

会话停止后发出。

参数：

| 名称 | 说明 |
|---|---|
| `summary` | 不含完整事件载荷的停止摘要。 |

结构：

- `summary`: Dictionary，包含 session_id、active、stop_reason、event_count、event_bytes、dropped_event_count、rejected_event_count、journal_event_count 和 journal_dropped_event_count。

<a id="member-gfsessiontraceutility-signals-event_recorded"></a>

### `event_recorded`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal event_recorded(event: Dictionary)
```

事件成功进入有界轨迹后发出。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 已脱敏的事件副本。 |

结构：

- `event`: Dictionary，包含 schema_version、session_id、sequence、elapsed_usec、simulation_tick、channel_id、event_id、include_in_snapshot、payload 和 metadata。

<a id="member-gfsessiontraceutility-signals-event_rejected"></a>

### `event_rejected`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal event_rejected(channel_id: StringName, event_id: StringName, reason: StringName)
```

事件被明确拒绝后发出。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 请求记录的通道标识。 |
| `event_id` | 请求记录的事件标识。 |
| `reason` | 稳定拒绝原因。 |

## 常量

<a id="member-gfsessiontraceutility-constants-default_max_events"></a>

### `DEFAULT_MAX_EVENTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_EVENTS: int = 512
```

默认最多保留的内存事件数量。

<a id="member-gfsessiontraceutility-constants-default_max_event_buffer_bytes"></a>

### `DEFAULT_MAX_EVENT_BUFFER_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_EVENT_BUFFER_BYTES: int = 1024 * 1024
```

默认内存事件缓冲总字节预算。

<a id="member-gfsessiontraceutility-constants-default_max_event_bytes"></a>

### `DEFAULT_MAX_EVENT_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_EVENT_BYTES: int = 16 * 1024
```

默认单个事件字节预算。

<a id="member-gfsessiontraceutility-constants-default_max_channels"></a>

### `DEFAULT_MAX_CHANNELS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_CHANNELS: int = 32
```

默认最多允许注册的通道数量。

<a id="member-gfsessiontraceutility-constants-default_max_snapshot_providers"></a>

### `DEFAULT_MAX_SNAPSHOT_PROVIDERS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_SNAPSHOT_PROVIDERS: int = 32
```

默认最多允许注册的同步快照 provider 数量。

<a id="member-gfsessiontraceutility-constants-default_max_journal_events"></a>

### `DEFAULT_MAX_JOURNAL_EVENTS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_JOURNAL_EVENTS: int = 2048
```

默认单次会话最多写入 journal 的事件数量。

<a id="member-gfsessiontraceutility-constants-reject_session_inactive"></a>

### `REJECT_SESSION_INACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_SESSION_INACTIVE: StringName = &"session_inactive"
```

拒绝原因：当前没有活动会话。

<a id="member-gfsessiontraceutility-constants-reject_unknown_channel"></a>

### `REJECT_UNKNOWN_CHANNEL`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_UNKNOWN_CHANNEL: StringName = &"unknown_channel"
```

拒绝原因：通道未显式注册。

<a id="member-gfsessiontraceutility-constants-reject_channel_disabled"></a>

### `REJECT_CHANNEL_DISABLED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_CHANNEL_DISABLED: StringName = &"channel_disabled"
```

拒绝原因：通道当前被禁用。

<a id="member-gfsessiontraceutility-constants-reject_invalid_event_id"></a>

### `REJECT_INVALID_EVENT_ID`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_INVALID_EVENT_ID: StringName = &"invalid_event_id"
```

拒绝原因：事件标识为空。

<a id="member-gfsessiontraceutility-constants-reject_event_too_large"></a>

### `REJECT_EVENT_TOO_LARGE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_EVENT_TOO_LARGE: StringName = &"event_too_large"
```

拒绝原因：单个事件或总轨迹预算无法容纳事件。

<a id="member-gfsessiontraceutility-constants-reject_invalid_provider"></a>

### `REJECT_INVALID_PROVIDER`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_INVALID_PROVIDER: StringName = &"invalid_provider"
```

拒绝原因：快照 provider 不存在或失效。

<a id="member-gfsessiontraceutility-constants-reject_provider_reentrant"></a>

### `REJECT_PROVIDER_REENTRANT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REJECT_PROVIDER_REENTRANT: StringName = &"provider_reentrant"
```

拒绝原因：快照 provider 发生重入调用。

## 属性

<a id="member-gfsessiontraceutility-properties-max_events"></a>

### `max_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_events: int = DEFAULT_MAX_EVENTS:
```

最多保留的内存事件数量。0 表示不保留新事件。

<a id="member-gfsessiontraceutility-properties-max_event_buffer_bytes"></a>

### `max_event_buffer_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_event_buffer_bytes: int = DEFAULT_MAX_EVENT_BUFFER_BYTES:
```

内存事件缓冲总字节预算。会话上下文和有界目录 metadata 不计入该预算。 0 表示不保留新事件。

<a id="member-gfsessiontraceutility-properties-max_event_bytes"></a>

### `max_event_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_event_bytes: int = DEFAULT_MAX_EVENT_BYTES:
```

单个事件字节预算；小于最小安全包络时会提升到最小值。

<a id="member-gfsessiontraceutility-properties-max_channels"></a>

### `max_channels`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_channels: int = DEFAULT_MAX_CHANNELS:
```

最多允许注册的通道数量。降低上限不会隐式删除既有通道。

<a id="member-gfsessiontraceutility-properties-max_snapshot_providers"></a>

### `max_snapshot_providers`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_snapshot_providers: int = DEFAULT_MAX_SNAPSHOT_PROVIDERS:
```

最多允许注册的同步快照 provider 数量。降低上限不会隐式删除既有 provider。

<a id="member-gfsessiontraceutility-properties-max_journal_events"></a>

### `max_journal_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_journal_events: int = DEFAULT_MAX_JOURNAL_EVENTS:
```

单次会话最多写入 journal 的事件数量。0 表示禁用 journal 写入。

<a id="member-gfsessiontraceutility-properties-redaction_profile"></a>

### `redaction_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY
```

默认报告脱敏 profile。默认使用 privacy，不应为线上玩家数据改成 debug。

## 方法

<a id="member-gfsessiontraceutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

停止活动会话、刷新 journal 并释放所有注册数据。

<a id="member-gfsessiontraceutility-methods-start_session"></a>

### `start_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func start_session( requested_session_id: StringName = &"", context: Dictionary = {}, options: Dictionary = {} ) -> StringName:
```

开始新的会话。已有活动会话会先以 restarted 原因停止。

参数：

| 名称 | 说明 |
|---|---|
| `requested_session_id` | 可选的非敏感本地会话标识；为空时自动生成。该字段不会识别账号、令牌等业务秘密。 |
| `context` | 项目显式提供的会话上下文。 |
| `options` | 可选参数，支持 started_ticks_usec。 |

返回：实际会话标识。

结构：

- `context`: Dictionary，由项目定义；进入轨迹前会使用当前 redaction_profile 和字节预算编码。
- `options`: Dictionary，started_ticks_usec 可用于固定时钟或测试。

<a id="member-gfsessiontraceutility-methods-stop_session"></a>

### `stop_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func stop_session(reason: StringName = &"completed") -> Dictionary:
```

停止当前会话并返回不含完整事件载荷的摘要。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 项目定义的停止原因。 |

返回：会话摘要。

结构：

- `return`: Dictionary，包含 session_id、active、stop_reason、event_count、event_bytes、dropped_event_count、rejected_event_count、journal_event_count 和 journal_dropped_event_count。

<a id="member-gfsessiontraceutility-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear() -> void:
```

清空内存事件和计数，但保留通道、provider、journal 与当前会话配置。

<a id="member-gfsessiontraceutility-methods-register_channel"></a>

### `register_channel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_channel(channel_id: StringName, options: Dictionary = {}) -> bool:
```

注册一个允许记录的事件通道。未知通道始终 fail closed。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 稳定通道标识。 |
| `options` | 通道选项。 |

返回：注册或更新成功时返回 true。

结构：

- `options`: Dictionary，可包含 enabled、include_in_snapshot、max_events、max_event_bytes 和 metadata；0 上限表示仅使用全局限制。

<a id="member-gfsessiontraceutility-methods-unregister_channel"></a>

### `unregister_channel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func unregister_channel(channel_id: StringName) -> bool:
```

注销事件通道。既有事件不会被删除。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |

返回：通道此前存在时返回 true。

<a id="member-gfsessiontraceutility-methods-has_channel"></a>

### `has_channel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_channel(channel_id: StringName) -> bool:
```

检查通道是否已显式注册。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |

返回：已注册时返回 true。

<a id="member-gfsessiontraceutility-methods-set_channel_enabled"></a>

### `set_channel_enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func set_channel_enabled(channel_id: StringName, enabled: bool) -> bool:
```

启用或禁用已注册通道。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 通道标识。 |
| `enabled` | 新状态。 |

返回：通道存在并更新成功时返回 true。

<a id="member-gfsessiontraceutility-methods-get_channel_catalog"></a>

### `get_channel_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_channel_catalog() -> Dictionary:
```

获取不含回调或事件载荷的通道目录。

返回：以通道 ID 为键的配置副本。

结构：

- `return`: Dictionary[StringName, Dictionary]，子字典包含 enabled、include_in_snapshot、max_events、max_event_bytes、event_count 和 metadata。

<a id="member-gfsessiontraceutility-methods-record_event"></a>

### `record_event`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func record_event( channel_id: StringName, event_id: StringName, payload: Variant = null, options: Dictionary = {} ) -> Dictionary:
```

记录一个显式通道事件。

参数：

| 名称 | 说明 |
|---|---|
| `channel_id` | 已注册通道标识。 |
| `event_id` | 项目定义的稳定事件标识。 |
| `payload` | 项目显式提供的事件载荷。 |
| `options` | 记录选项。 |

返回：结构化记录结果。

结构：

- `payload`: Variant，由项目定义；进入轨迹前会按当前 redaction_profile 和单事件字节预算编码为 JSON-safe 值。
- `options`: Dictionary，可包含 ticks_usec、simulation_tick 和 metadata；metadata 会与通道 metadata 合并后脱敏。
- `return`: Dictionary，成功时包含 ok、event 和 dropped_event_count；失败时包含 ok=false 与 reason。

<a id="member-gfsessiontraceutility-methods-register_snapshot_provider"></a>

### `register_snapshot_provider`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_snapshot_provider( provider_id: StringName, channel_id: StringName, provider: Callable, options: Dictionary = {} ) -> bool:
```

注册一个由项目显式触发的同步快照 provider。 Provider 必须是无参数、快速、同步且不会修改游戏状态的 Callable；GF 不会自动轮询它。

参数：

| 名称 | 说明 |
|---|---|
| `provider_id` | provider 稳定标识。 |
| `channel_id` | provider 结果写入的已注册通道。 |
| `provider` | 无参数同步 Callable。 |
| `options` | provider 选项。 |

返回：注册或更新成功时返回 true。

结构：

- `options`: Dictionary，可包含 enabled、event_id 和 metadata。

<a id="member-gfsessiontraceutility-methods-unregister_snapshot_provider"></a>

### `unregister_snapshot_provider`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func unregister_snapshot_provider(provider_id: StringName) -> bool:
```

注销同步快照 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider_id` | provider 标识。 |

返回：provider 此前存在时返回 true。

<a id="member-gfsessiontraceutility-methods-capture_snapshot_provider"></a>

### `capture_snapshot_provider`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func capture_snapshot_provider(provider_id: StringName, options: Dictionary = {}) -> Dictionary:
```

显式调用一个同步快照 provider 并把结果记录为事件。

参数：

| 名称 | 说明 |
|---|---|
| `provider_id` | provider 标识。 |
| `options` | 传给 record_event() 的 ticks_usec、simulation_tick 和附加 metadata。 |

返回：record_event() 结构化结果。

结构：

- `options`: Dictionary，可包含 ticks_usec、simulation_tick 和 metadata。
- `return`: Dictionary，成功时包含 ok、event 和 dropped_event_count；失败时包含 ok=false 与 reason。

<a id="member-gfsessiontraceutility-methods-get_snapshot_provider_catalog"></a>

### `get_snapshot_provider_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_snapshot_provider_catalog() -> Dictionary:
```

获取同步快照 provider 目录，不包含 Callable 本身。

返回：以 provider ID 为键的配置副本。

结构：

- `return`: Dictionary[StringName, Dictionary]，子字典包含 channel_id、event_id、enabled 和 metadata。

<a id="member-gfsessiontraceutility-methods-configure_journal_sink"></a>

### `configure_journal_sink`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure_journal_sink(sink: GFLogSink, options: Dictionary = {}) -> bool:
```

配置可选 journal sink。GF 不会默认创建文件或上传边界。 当前 redaction_profile 必须不弱于 sink 声明的输出 profile；运行期若被改弱，后续 journal 事件会 fail closed。 若使用专用 GFJsonLineLogSink，可通过 options.initialize 与 shutdown_on_dispose 让当前工具拥有其生命周期。

参数：

| 名称 | 说明 |
|---|---|
| `sink` | 接收已脱敏事件的 sink；传入 null 表示清除。 |
| `options` | journal 生命周期选项。 |

返回：sink 的输出 profile 与当前轨迹 profile 兼容且配置成功，或已成功清除时返回 true。

结构：

- `options`: Dictionary，可包含 initialize、shutdown_on_dispose 和 flush_after_write。

<a id="member-gfsessiontraceutility-methods-flush_journal"></a>

### `flush_journal`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func flush_journal() -> void:
```

刷新当前 journal sink。

<a id="member-gfsessiontraceutility-methods-clear_journal_sink"></a>

### `clear_journal_sink`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear_journal_sink(shutdown: bool = false) -> void:
```

清除 journal sink，并可选关闭其资源。

参数：

| 名称 | 说明 |
|---|---|
| `shutdown` | 是否调用 sink.shutdown()。 |

<a id="member-gfsessiontraceutility-methods-get_events"></a>

### `get_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_events(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
```

获取过滤后的事件副本。limit 保留最新 N 条并维持时间顺序。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；0 表示不限制。 |
| `filters` | 可选过滤器。 |

返回：事件副本数组。

结构：

- `filters`: Dictionary，可包含 channel_id、event_id、min_sequence、max_sequence 和 include_hidden_channels。
- `return`: Array[Dictionary]，元素遵循 event_recorded 的事件 schema。

<a id="member-gfsessiontraceutility-methods-build_snapshot"></a>

### `build_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func build_snapshot(options: Dictionary = {}) -> Dictionary:
```

构建适合诊断快照或支持报告分区的结构化轨迹。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 快照选项。 |

返回：有界轨迹快照。

结构：

- `options`: Dictionary，可包含 limit、filters、include_context、include_channel_catalog 和 include_provider_catalog。
- `return`: Dictionary，包含 schema_version、summary、events，并按选项包含 context、channel_catalog 和 provider_catalog。

<a id="member-gfsessiontraceutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含完整事件载荷的调试快照。

返回：当前容量、计数和 journal 状态。

结构：

- `return`: Dictionary，包含 summary、channel_count、provider_count、max_events、max_event_buffer_bytes、max_event_bytes、max_journal_events、journal_configured 和 rejections_by_reason。
