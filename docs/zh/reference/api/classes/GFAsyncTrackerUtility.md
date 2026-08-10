# GFAsyncTrackerUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_async_tracker_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

可选异步句柄追踪工具。 默认关闭。启用后可登记异步完成源、通道、超时控制器或项目自定义句柄， 并通过弱引用生成活动句柄快照，帮助诊断未完成、未释放或异常停留的异步流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`async_handle_tracked`](#member-gfasynctrackerutility-signals-async_handle_tracked) | `signal async_handle_tracked(tracking_id: int, label: StringName)` |
| 信号 | [`async_handle_untracked`](#member-gfasynctrackerutility-signals-async_handle_untracked) | `signal async_handle_untracked(tracking_id: int, label: StringName)` |
| 常量 | [`DEFAULT_MAX_STACK_TRACE_CHARS`](#member-gfasynctrackerutility-constants-default_max_stack_trace_chars) | `const DEFAULT_MAX_STACK_TRACE_CHARS: int = 4000` |
| 常量 | [`DEFAULT_MAX_SNAPSHOT_ENTRIES`](#member-gfasynctrackerutility-constants-default_max_snapshot_entries) | `const DEFAULT_MAX_SNAPSHOT_ENTRIES: int = 64` |
| 常量 | [`DEFAULT_MAX_PROVIDER_CALLS`](#member-gfasynctrackerutility-constants-default_max_provider_calls) | `const DEFAULT_MAX_PROVIDER_CALLS: int = 32` |
| 属性 | [`tracking_enabled`](#member-gfasynctrackerutility-properties-tracking_enabled) | `var tracking_enabled: bool = false` |
| 属性 | [`stack_trace_enabled`](#member-gfasynctrackerutility-properties-stack_trace_enabled) | `var stack_trace_enabled: bool = false` |
| 属性 | [`max_stack_trace_chars`](#member-gfasynctrackerutility-properties-max_stack_trace_chars) | `var max_stack_trace_chars: int = DEFAULT_MAX_STACK_TRACE_CHARS:` |
| 属性 | [`max_snapshot_entries`](#member-gfasynctrackerutility-properties-max_snapshot_entries) | `var max_snapshot_entries: int = DEFAULT_MAX_SNAPSHOT_ENTRIES:` |
| 方法 | [`dispose`](#member-gfasynctrackerutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`track_handle`](#member-gfasynctrackerutility-methods-track_handle) | `func track_handle( handle: Object, label: StringName = &"", metadata: Dictionary = {}, snapshot_provider: Callable = Callable() ) -> int:` |
| 方法 | [`untrack_id`](#member-gfasynctrackerutility-methods-untrack_id) | `func untrack_id(tracking_id: int) -> bool:` |
| 方法 | [`untrack_handle`](#member-gfasynctrackerutility-methods-untrack_handle) | `func untrack_handle(handle: Object) -> int:` |
| 方法 | [`clear_invalid`](#member-gfasynctrackerutility-methods-clear_invalid) | `func clear_invalid() -> int:` |
| 方法 | [`clear`](#member-gfasynctrackerutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`check_and_reset_dirty`](#member-gfasynctrackerutility-methods-check_and_reset_dirty) | `func check_and_reset_dirty() -> bool:` |
| 方法 | [`refresh_snapshot`](#member-gfasynctrackerutility-methods-refresh_snapshot) | `func refresh_snapshot(tracking_id: int) -> Dictionary:` |
| 方法 | [`refresh_snapshots`](#member-gfasynctrackerutility-methods-refresh_snapshots) | `func refresh_snapshots(max_provider_calls: int = DEFAULT_MAX_PROVIDER_CALLS) -> Dictionary:` |
| 方法 | [`get_active_records`](#member-gfasynctrackerutility-methods-get_active_records) | `func get_active_records(include_invalid: bool = false) -> Array[Dictionary]:` |
| 方法 | [`get_debug_snapshot`](#member-gfasynctrackerutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasynctrackerutility-signals-async_handle_tracked"></a>

### `async_handle_tracked`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal async_handle_tracked(tracking_id: int, label: StringName)
```

句柄被登记时发出。

参数：

| 名称 | 说明 |
|---|---|
| `tracking_id` | 追踪 ID。 |
| `label` | 追踪标签。 |

<a id="member-gfasynctrackerutility-signals-async_handle_untracked"></a>

### `async_handle_untracked`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal async_handle_untracked(tracking_id: int, label: StringName)
```

句柄被移除追踪时发出。

参数：

| 名称 | 说明 |
|---|---|
| `tracking_id` | 追踪 ID。 |
| `label` | 追踪标签。 |

## 常量

<a id="member-gfasynctrackerutility-constants-default_max_stack_trace_chars"></a>

### `DEFAULT_MAX_STACK_TRACE_CHARS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_STACK_TRACE_CHARS: int = 4000
```

默认堆栈文本最大长度。

<a id="member-gfasynctrackerutility-constants-default_max_snapshot_entries"></a>

### `DEFAULT_MAX_SNAPSHOT_ENTRIES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_SNAPSHOT_ENTRIES: int = 64
```

单个 provider 快照默认最多保留的顶层条目数。

<a id="member-gfasynctrackerutility-constants-default_max_provider_calls"></a>

### `DEFAULT_MAX_PROVIDER_CALLS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_PROVIDER_CALLS: int = 32
```

单次批量刷新默认最多调用的 provider 数量。

## 属性

<a id="member-gfasynctrackerutility-properties-tracking_enabled"></a>

### `tracking_enabled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var tracking_enabled: bool = false
```

是否启用追踪。关闭时 track_handle 直接返回 0。

<a id="member-gfasynctrackerutility-properties-stack_trace_enabled"></a>

### `stack_trace_enabled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var stack_trace_enabled: bool = false
```

是否在登记时捕获调用堆栈。

<a id="member-gfasynctrackerutility-properties-max_stack_trace_chars"></a>

### `max_stack_trace_chars`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_stack_trace_chars: int = DEFAULT_MAX_STACK_TRACE_CHARS:
```

单条堆栈文本最大长度。

<a id="member-gfasynctrackerutility-properties-max_snapshot_entries"></a>

### `max_snapshot_entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_snapshot_entries: int = DEFAULT_MAX_SNAPSHOT_ENTRIES:
```

单个 provider 快照最多保留的顶层条目数。

## 方法

<a id="member-gfasynctrackerutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

清除所有追踪记录。

<a id="member-gfasynctrackerutility-methods-track_handle"></a>

### `track_handle`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func track_handle( handle: Object, label: StringName = &"", metadata: Dictionary = {}, snapshot_provider: Callable = Callable() ) -> int:
```

登记一个异步句柄。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待追踪对象。 |
| `label` | 稳定标签；为空时使用 handle.get_class()。 |
| `metadata` | 追踪上下文。 |
| `snapshot_provider` | 可选无参快照回调；返回值会收窄为 Dictionary。 |

返回：追踪 ID；未启用或 handle 为空时返回 0。

结构：

- `metadata`: Dictionary，包含调用方定义的追踪上下文。

<a id="member-gfasynctrackerutility-methods-untrack_id"></a>

### `untrack_id`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func untrack_id(tracking_id: int) -> bool:
```

按追踪 ID 取消登记。

参数：

| 名称 | 说明 |
|---|---|
| `tracking_id` | 追踪 ID。 |

返回：成功移除时返回 true。

<a id="member-gfasynctrackerutility-methods-untrack_handle"></a>

### `untrack_handle`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func untrack_handle(handle: Object) -> int:
```

移除指定对象的所有追踪记录。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待移除对象。 |

返回：移除数量。

<a id="member-gfasynctrackerutility-methods-clear_invalid"></a>

### `clear_invalid`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear_invalid() -> int:
```

清除已经失效的弱引用记录。

返回：清除数量。

<a id="member-gfasynctrackerutility-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空所有追踪记录。

<a id="member-gfasynctrackerutility-methods-check_and_reset_dirty"></a>

### `check_and_reset_dirty`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func check_and_reset_dirty() -> bool:
```

判断是否存在未读取的追踪变更，并重置 dirty 标记。

返回：自上次调用以来有追踪变化时返回 true。

<a id="member-gfasynctrackerutility-methods-refresh_snapshot"></a>

### `refresh_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func refresh_snapshot(tracking_id: int) -> Dictionary:
```

显式刷新一条追踪记录的 provider 快照。 读取 API 不会调用外部 provider；调用方应在可控调度点主动刷新。

参数：

| 名称 | 说明 |
|---|---|
| `tracking_id` | 待刷新的追踪 ID。 |

返回：刷新报告。

结构：

- `return`: Dictionary，包含 ok、tracking_id、refreshed、error、entry_count、truncated、stale 和 attempted_msec。

<a id="member-gfasynctrackerutility-methods-refresh_snapshots"></a>

### `refresh_snapshots`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func refresh_snapshots(max_provider_calls: int = DEFAULT_MAX_PROVIDER_CALLS) -> Dictionary:
```

按稳定 ID 顺序批量刷新 provider 快照。

参数：

| 名称 | 说明 |
|---|---|
| `max_provider_calls` | 本次最多调用的 provider 数量；小于等于 0 时不调用。 |

返回：批量刷新报告。

结构：

- `return`: Dictionary，包含 ok、provider_call_count、refreshed_count、failed_count、pending_count、truncated 和 reports。

<a id="member-gfasynctrackerutility-methods-get_active_records"></a>

### `get_active_records`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_active_records(include_invalid: bool = false) -> Array[Dictionary]:
```

获取活动追踪记录快照。

参数：

| 名称 | 说明 |
|---|---|
| `include_invalid` | 是否包含弱引用已失效的记录。 |

返回：追踪记录数组。

结构：

- `return`: Array[Dictionary]，每项包含 tracking_id、label、valid、age_msec、metadata、snapshot_entry_count、snapshot_truncated、snapshot_stale、snapshot_attempted_msec、snapshot_refreshed_msec 和可选 snapshot、snapshot_error、stack_trace。

<a id="member-gfasynctrackerutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取追踪调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 enabled、active_count、invalid_count、dirty 和 records。
