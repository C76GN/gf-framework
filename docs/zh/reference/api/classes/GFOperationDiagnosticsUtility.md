# GFOperationDiagnosticsUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_operation_diagnostics_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

通用操作诊断时间线。 记录开发工具、运行时服务或项目流程的操作、阶段耗时和异常事件，并提供有界历史、健康快照和可复制摘要。 该工具只保存结构化诊断数据，不绑定编辑器 UI、远程服务、外部协议或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_OPERATIONS`](#member-gfoperationdiagnosticsutility-constants-default_max_operations) | `const DEFAULT_MAX_OPERATIONS: int = 100` |
| 常量 | [`DEFAULT_MAX_INCIDENTS`](#member-gfoperationdiagnosticsutility-constants-default_max_incidents) | `const DEFAULT_MAX_INCIDENTS: int = 200` |
| 常量 | [`DEFAULT_MAX_STATE_TRACE_ENTRIES`](#member-gfoperationdiagnosticsutility-constants-default_max_state_trace_entries) | `const DEFAULT_MAX_STATE_TRACE_ENTRIES: int = 64` |
| 常量 | [`DEFAULT_SLOW_OPERATION_THRESHOLD_MS`](#member-gfoperationdiagnosticsutility-constants-default_slow_operation_threshold_ms) | `const DEFAULT_SLOW_OPERATION_THRESHOLD_MS: float = 1200.0` |
| 常量 | [`SEVERITY_INFO`](#member-gfoperationdiagnosticsutility-constants-severity_info) | `const SEVERITY_INFO: StringName = &"info"` |
| 常量 | [`SEVERITY_WARNING`](#member-gfoperationdiagnosticsutility-constants-severity_warning) | `const SEVERITY_WARNING: StringName = &"warning"` |
| 常量 | [`SEVERITY_ERROR`](#member-gfoperationdiagnosticsutility-constants-severity_error) | `const SEVERITY_ERROR: StringName = &"error"` |
| 常量 | [`SEVERITY_CRITICAL`](#member-gfoperationdiagnosticsutility-constants-severity_critical) | `const SEVERITY_CRITICAL: StringName = &"critical"` |
| 常量 | [`STATE_PENDING`](#member-gfoperationdiagnosticsutility-constants-state_pending) | `const STATE_PENDING: StringName = &"pending"` |
| 常量 | [`STATE_RUNNING`](#member-gfoperationdiagnosticsutility-constants-state_running) | `const STATE_RUNNING: StringName = &"running"` |
| 常量 | [`STATE_WAITING_FOR_USER`](#member-gfoperationdiagnosticsutility-constants-state_waiting_for_user) | `const STATE_WAITING_FOR_USER: StringName = &"waiting_for_user"` |
| 常量 | [`STATE_RETRYING`](#member-gfoperationdiagnosticsutility-constants-state_retrying) | `const STATE_RETRYING: StringName = &"retrying"` |
| 常量 | [`STATE_SUCCEEDED`](#member-gfoperationdiagnosticsutility-constants-state_succeeded) | `const STATE_SUCCEEDED: StringName = &"succeeded"` |
| 常量 | [`STATE_FAILED`](#member-gfoperationdiagnosticsutility-constants-state_failed) | `const STATE_FAILED: StringName = &"failed"` |
| 常量 | [`STATE_CANCELLED`](#member-gfoperationdiagnosticsutility-constants-state_cancelled) | `const STATE_CANCELLED: StringName = &"cancelled"` |
| 属性 | [`max_operations`](#member-gfoperationdiagnosticsutility-properties-max_operations) | `var max_operations: int = DEFAULT_MAX_OPERATIONS:` |
| 属性 | [`max_incidents`](#member-gfoperationdiagnosticsutility-properties-max_incidents) | `var max_incidents: int = DEFAULT_MAX_INCIDENTS:` |
| 属性 | [`max_state_trace_entries`](#member-gfoperationdiagnosticsutility-properties-max_state_trace_entries) | `var max_state_trace_entries: int = DEFAULT_MAX_STATE_TRACE_ENTRIES:` |
| 属性 | [`slow_operation_threshold_ms`](#member-gfoperationdiagnosticsutility-properties-slow_operation_threshold_ms) | `var slow_operation_threshold_ms: float = DEFAULT_SLOW_OPERATION_THRESHOLD_MS` |
| 方法 | [`dispose`](#member-gfoperationdiagnosticsutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`clear`](#member-gfoperationdiagnosticsutility-methods-clear) | `func clear() -> void:` |
| 方法 | [`begin_operation`](#member-gfoperationdiagnosticsutility-methods-begin_operation) | `func begin_operation(operation_type: StringName, options: Dictionary = {}) -> StringName:` |
| 方法 | [`record_completed_operation`](#member-gfoperationdiagnosticsutility-methods-record_completed_operation) | `func record_completed_operation( operation_type: StringName, duration_ms: float, success: bool = true, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`record_phase`](#member-gfoperationdiagnosticsutility-methods-record_phase) | `func record_phase( operation_id: StringName, phase_id: StringName, duration_ms: float, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`record_phase_from_ticks`](#member-gfoperationdiagnosticsutility-methods-record_phase_from_ticks) | `func record_phase_from_ticks( operation_id: StringName, phase_id: StringName, started_ticks_usec: int, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`record_state_snapshot`](#member-gfoperationdiagnosticsutility-methods-record_state_snapshot) | `func record_state_snapshot( operation_id: StringName, state_id: StringName, status: StringName = STATE_RUNNING, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`finish_operation`](#member-gfoperationdiagnosticsutility-methods-finish_operation) | `func finish_operation(operation_id: StringName, success: bool = true, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`record_incident`](#member-gfoperationdiagnosticsutility-methods-record_incident) | `func record_incident( severity: StringName, code: StringName, message: String = "", options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`record_async_snapshot`](#member-gfoperationdiagnosticsutility-methods-record_async_snapshot) | `func record_async_snapshot( operation_type: StringName, snapshot: Dictionary, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`has_operation`](#member-gfoperationdiagnosticsutility-methods-has_operation) | `func has_operation(operation_id: StringName) -> bool:` |
| 方法 | [`get_operation`](#member-gfoperationdiagnosticsutility-methods-get_operation) | `func get_operation(operation_id: StringName) -> Dictionary:` |
| 方法 | [`get_operation_state_trace`](#member-gfoperationdiagnosticsutility-methods-get_operation_state_trace) | `func get_operation_state_trace(operation_id: StringName, limit: int = 0) -> Array[Dictionary]:` |
| 方法 | [`get_operations`](#member-gfoperationdiagnosticsutility-methods-get_operations) | `func get_operations(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`get_incidents`](#member-gfoperationdiagnosticsutility-methods-get_incidents) | `func get_incidents(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`get_timeline`](#member-gfoperationdiagnosticsutility-methods-get_timeline) | `func get_timeline(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`get_health_snapshot`](#member-gfoperationdiagnosticsutility-methods-get_health_snapshot) | `func get_health_snapshot(limit: int = 5) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfoperationdiagnosticsutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`build_copy_text`](#member-gfoperationdiagnosticsutility-methods-build_copy_text) | `func build_copy_text(snapshot: Dictionary = {}) -> String:` |

## 常量

<a id="member-gfoperationdiagnosticsutility-constants-default_max_operations"></a>

### `DEFAULT_MAX_OPERATIONS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_OPERATIONS: int = 100
```

默认保留的操作数量。

<a id="member-gfoperationdiagnosticsutility-constants-default_max_incidents"></a>

### `DEFAULT_MAX_INCIDENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_INCIDENTS: int = 200
```

默认保留的异常事件数量。

<a id="member-gfoperationdiagnosticsutility-constants-default_max_state_trace_entries"></a>

### `DEFAULT_MAX_STATE_TRACE_ENTRIES`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_STATE_TRACE_ENTRIES: int = 64
```

单个操作默认保留的状态轨迹数量。

<a id="member-gfoperationdiagnosticsutility-constants-default_slow_operation_threshold_ms"></a>

### `DEFAULT_SLOW_OPERATION_THRESHOLD_MS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_SLOW_OPERATION_THRESHOLD_MS: float = 1200.0
```

默认慢操作阈值，单位毫秒。

<a id="member-gfoperationdiagnosticsutility-constants-severity_info"></a>

### `SEVERITY_INFO`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const SEVERITY_INFO: StringName = &"info"
```

信息级事件。

<a id="member-gfoperationdiagnosticsutility-constants-severity_warning"></a>

### `SEVERITY_WARNING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const SEVERITY_WARNING: StringName = &"warning"
```

警告级事件。

<a id="member-gfoperationdiagnosticsutility-constants-severity_error"></a>

### `SEVERITY_ERROR`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const SEVERITY_ERROR: StringName = &"error"
```

错误级事件。

<a id="member-gfoperationdiagnosticsutility-constants-severity_critical"></a>

### `SEVERITY_CRITICAL`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const SEVERITY_CRITICAL: StringName = &"critical"
```

严重错误级事件。

<a id="member-gfoperationdiagnosticsutility-constants-state_pending"></a>

### `STATE_PENDING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_PENDING: StringName = &"pending"
```

操作状态：等待开始或排队中。

<a id="member-gfoperationdiagnosticsutility-constants-state_running"></a>

### `STATE_RUNNING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_RUNNING: StringName = &"running"
```

操作状态：正在运行。

<a id="member-gfoperationdiagnosticsutility-constants-state_waiting_for_user"></a>

### `STATE_WAITING_FOR_USER`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_WAITING_FOR_USER: StringName = &"waiting_for_user"
```

操作状态：等待用户或上层流程做出决策。

<a id="member-gfoperationdiagnosticsutility-constants-state_retrying"></a>

### `STATE_RETRYING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_RETRYING: StringName = &"retrying"
```

操作状态：正在重试。

<a id="member-gfoperationdiagnosticsutility-constants-state_succeeded"></a>

### `STATE_SUCCEEDED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_SUCCEEDED: StringName = &"succeeded"
```

操作状态：已成功。

<a id="member-gfoperationdiagnosticsutility-constants-state_failed"></a>

### `STATE_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_FAILED: StringName = &"failed"
```

操作状态：已失败。

<a id="member-gfoperationdiagnosticsutility-constants-state_cancelled"></a>

### `STATE_CANCELLED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_CANCELLED: StringName = &"cancelled"
```

操作状态：已取消。

## 属性

<a id="member-gfoperationdiagnosticsutility-properties-max_operations"></a>

### `max_operations`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_operations: int = DEFAULT_MAX_OPERATIONS:
```

最多保留的操作记录数量。设置为 0 时不保留操作历史。

<a id="member-gfoperationdiagnosticsutility-properties-max_incidents"></a>

### `max_incidents`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_incidents: int = DEFAULT_MAX_INCIDENTS:
```

最多保留的异常事件数量。设置为 0 时不保留异常历史。

<a id="member-gfoperationdiagnosticsutility-properties-max_state_trace_entries"></a>

### `max_state_trace_entries`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_state_trace_entries: int = DEFAULT_MAX_STATE_TRACE_ENTRIES:
```

单个操作最多保留的状态轨迹数量。设置为 0 时不保留状态轨迹。

<a id="member-gfoperationdiagnosticsutility-properties-slow_operation_threshold_ms"></a>

### `slow_operation_threshold_ms`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var slow_operation_threshold_ms: float = DEFAULT_SLOW_OPERATION_THRESHOLD_MS
```

超过该耗时的完成操作会在健康快照中计入慢操作，单位毫秒。小于 0 时禁用慢操作统计。

## 方法

<a id="member-gfoperationdiagnosticsutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

清理所有已记录的诊断数据。

<a id="member-gfoperationdiagnosticsutility-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空操作和异常历史，并重置序列。

<a id="member-gfoperationdiagnosticsutility-methods-begin_operation"></a>

### `begin_operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func begin_operation(operation_type: StringName, options: Dictionary = {}) -> StringName:
```

开始记录一个操作。

参数：

| 名称 | 说明 |
|---|---|
| `operation_type` | 操作类型，建议使用稳定的命名空间标识。 |
| `options` | 可选参数，支持 operation_id、component、label、metadata 和 started_ticks_usec。 |

返回：操作 ID；operation_type 为空时返回空 StringName。

结构：

- `options`: Dictionary，支持 operation_id、component、label、metadata 和 started_ticks_usec。

<a id="member-gfoperationdiagnosticsutility-methods-record_completed_operation"></a>

### `record_completed_operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_completed_operation( operation_type: StringName, duration_ms: float, success: bool = true, options: Dictionary = {} ) -> Dictionary:
```

直接记录一个已完成操作。

参数：

| 名称 | 说明 |
|---|---|
| `operation_type` | 操作类型。 |
| `duration_ms` | 操作耗时，单位毫秒。 |
| `success` | 操作是否成功。 |
| `options` | 可选参数，支持 operation_id、component、label、metadata、anomaly_codes、started_ticks_usec 和 ended_ticks_usec。 |

返回：操作记录副本；operation_type 为空时返回空字典。

结构：

- `options`: Dictionary，支持 operation_id、component、label、metadata、anomaly_codes、started_ticks_usec 和 ended_ticks_usec。
- `return`: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。

<a id="member-gfoperationdiagnosticsutility-methods-record_phase"></a>

### `record_phase`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_phase( operation_id: StringName, phase_id: StringName, duration_ms: float, options: Dictionary = {} ) -> Dictionary:
```

为已有操作记录一个阶段耗时。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | begin_operation() 返回的操作 ID。 |
| `phase_id` | 阶段标识。 |
| `duration_ms` | 阶段耗时，单位毫秒。 |
| `options` | 可选参数，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。 |

返回：阶段记录副本；操作或阶段不存在时返回空字典。

结构：

- `options`: Dictionary，支持 component、label、metadata、started_ticks_usec 和 ended_ticks_usec。
- `return`: Dictionary，包含 phase_id、component、label、duration_ms、started_ticks_usec、ended_ticks_usec 和 metadata。

<a id="member-gfoperationdiagnosticsutility-methods-record_phase_from_ticks"></a>

### `record_phase_from_ticks`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_phase_from_ticks( operation_id: StringName, phase_id: StringName, started_ticks_usec: int, options: Dictionary = {} ) -> Dictionary:
```

使用 Godot tick 起点记录一个阶段耗时。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | begin_operation() 返回的操作 ID。 |
| `phase_id` | 阶段标识。 |
| `started_ticks_usec` | 阶段开始时的 Time.get_ticks_usec()。 |
| `options` | 可选参数，支持 component、label、metadata 和 ended_ticks_usec。 |

返回：阶段记录副本；操作或阶段不存在时返回空字典。

结构：

- `options`: Dictionary，支持 component、label、metadata 和 ended_ticks_usec。
- `return`: Dictionary，包含 phase_id、component、label、duration_ms、started_ticks_usec、ended_ticks_usec 和 metadata。

<a id="member-gfoperationdiagnosticsutility-methods-record_state_snapshot"></a>

### `record_state_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_state_snapshot( operation_id: StringName, state_id: StringName, status: StringName = STATE_RUNNING, options: Dictionary = {} ) -> Dictionary:
```

为已有操作记录一个状态快照。 状态快照用于表达长流程当前阶段、重试次数、进度、是否等待用户决策和错误信息。 它只写入结构化诊断，不决定业务如何重试、下载、弹窗或恢复。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | begin_operation() 返回的操作 ID。 |
| `state_id` | 调用方定义的稳定状态 ID。 |
| `status` | 状态，建议使用 STATE_* 常量。 |
| `options` | 可选参数，支持 component、label、attempt、max_attempts、progress、progress_current、progress_total、user_action_required、error、metadata、seen_ticks_usec。 |

返回：状态快照副本；操作或状态不存在时返回空字典。

结构：

- `options`: Dictionary，支持 component、label、attempt、max_attempts、progress、progress_current、progress_total、user_action_required、error、metadata、seen_ticks_usec。
- `return`: Dictionary，包含 state_id、status、attempt、max_attempts、progress、user_action_required、error 和 metadata。

<a id="member-gfoperationdiagnosticsutility-methods-finish_operation"></a>

### `finish_operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func finish_operation(operation_id: StringName, success: bool = true, options: Dictionary = {}) -> Dictionary:
```

结束一个操作并写入最终状态。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | begin_operation() 返回的操作 ID。 |
| `success` | 操作是否成功。 |
| `options` | 可选参数，支持 metadata、anomaly_codes、ended_ticks_usec 和 duration_ms。 |

返回：完整操作记录副本；操作不存在时返回空字典。

结构：

- `options`: Dictionary，支持 metadata、anomaly_codes、ended_ticks_usec 和 duration_ms。
- `return`: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。

<a id="member-gfoperationdiagnosticsutility-methods-record_incident"></a>

### `record_incident`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_incident( severity: StringName, code: StringName, message: String = "", options: Dictionary = {} ) -> Dictionary:
```

记录一个异常事件；同类事件会聚合 occurrence_count 并更新时间。

参数：

| 名称 | 说明 |
|---|---|
| `severity` | 事件等级，建议使用 SEVERITY_INFO / WARNING / ERROR / CRITICAL。 |
| `code` | 稳定事件代码。 |
| `message` | 面向维护者的简短说明。 |
| `options` | 可选参数，支持 category、component、phase、recoverable、suggested_action 和 metadata。 |

返回：异常事件记录副本；code 为空时返回空字典。

结构：

- `options`: Dictionary，支持 category、component、phase、recoverable、suggested_action 和 metadata。
- `return`: Dictionary，包含 incident_id、severity、category、code、message、component、phase、occurrence_count、recoverable、suggested_action 和 metadata。

<a id="member-gfoperationdiagnosticsutility-methods-record_async_snapshot"></a>

### `record_async_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func record_async_snapshot( operation_type: StringName, snapshot: Dictionary, options: Dictionary = {} ) -> Dictionary:
```

将异步对象的状态快照记录为操作诊断。

参数：

| 名称 | 说明 |
|---|---|
| `operation_type` | 操作类型，建议使用稳定的命名空间标识。 |
| `snapshot` | 异步对象提供的状态快照。 |
| `options` | 可选参数，支持 operation_id、component、label、metadata、duration_ms 和 incident_message。 |

返回：操作记录副本；operation_type 为空时返回空字典。

结构：

- `snapshot`: Dictionary，可包含 completed、success、failed、cancelled、timed_out、status、status_name、duration_msec、duration_ms、error、reason、cancel_reason 和 metadata。
- `options`: Dictionary，支持 operation_id、component、label、metadata、duration_ms 和 incident_message。
- `return`: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。

<a id="member-gfoperationdiagnosticsutility-methods-has_operation"></a>

### `has_operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_operation(operation_id: StringName) -> bool:
```

检查操作是否仍在历史中。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 操作 ID。 |

返回：存在返回 true。

<a id="member-gfoperationdiagnosticsutility-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_operation(operation_id: StringName) -> Dictionary:
```

获取单个操作记录副本。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 操作 ID。 |

返回：操作记录副本；不存在时返回空字典。

结构：

- `return`: Dictionary，包含 operation_id、operation_type、component、state、duration_ms、phases、anomaly_codes 和 metadata 等字段。

<a id="member-gfoperationdiagnosticsutility-methods-get_operation_state_trace"></a>

### `get_operation_state_trace`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_operation_state_trace(operation_id: StringName, limit: int = 0) -> Array[Dictionary]:
```

获取单个操作的状态轨迹。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 操作 ID。 |
| `limit` | 最大返回数量；小于等于 0 时返回全部状态。 |

返回：状态快照数组，按记录顺序返回。

结构：

- `return`: Array[Dictionary] state snapshot records.

<a id="member-gfoperationdiagnosticsutility-methods-get_operations"></a>

### `get_operations`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_operations(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
```

获取操作历史。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部匹配记录。 |
| `filters` | 过滤条件，支持 operation_type、component、state 和 success。 |

返回：操作记录数组，按最近更新倒序排列。

结构：

- `filters`: Dictionary，支持 operation_type、component、state 和 success。
- `return`: Array[Dictionary]，每个元素是操作记录副本。

<a id="member-gfoperationdiagnosticsutility-methods-get_incidents"></a>

### `get_incidents`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_incidents(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
```

获取异常事件历史。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部匹配记录。 |
| `filters` | 过滤条件，支持 severity、category、component、phase 和 code。 |

返回：异常事件数组，按最近更新倒序排列。

结构：

- `filters`: Dictionary，支持 severity、category、component、phase 和 code。
- `return`: Array[Dictionary]，每个元素是异常事件记录副本。

<a id="member-gfoperationdiagnosticsutility-methods-get_timeline"></a>

### `get_timeline`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_timeline(limit: int = 0, filters: Dictionary = {}) -> Array[Dictionary]:
```

获取合并后的操作和异常时间线。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最大返回数量；小于等于 0 时返回全部匹配记录。 |
| `filters` | 过滤条件，支持 entry_type、operation_type、severity、category、component、phase、state、success 和 code。 |

返回：时间线记录数组，按最近更新倒序排列。

结构：

- `filters`: Dictionary，支持 entry_type、operation_type、severity、category、component、phase、state、success 和 code。
- `return`: Array[Dictionary]，每个元素是操作或异常事件记录副本。

<a id="member-gfoperationdiagnosticsutility-methods-get_health_snapshot"></a>

### `get_health_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_health_snapshot(limit: int = 5) -> Dictionary:
```

生成健康快照。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | recent_operations 与 recent_incidents 的最大数量。 |

返回：健康快照字典。

结构：

- `return`: Dictionary，包含 status、operation_count、incident_count、open_operation_count、failed_operation_count、slow_operation_count、recent_operations、recent_incidents 和 slowest_operation。

<a id="member-gfoperationdiagnosticsutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 history 上限、计数、健康快照和最近时间线。

<a id="member-gfoperationdiagnosticsutility-methods-build_copy_text"></a>

### `build_copy_text`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func build_copy_text(snapshot: Dictionary = {}) -> String:
```

构建适合复制到 issue、日志或支持报告的纯文本摘要。

参数：

| 名称 | 说明 |
|---|---|
| `snapshot` | 可选健康快照；为空时现场采集 get_health_snapshot()。 |

返回：纯文本摘要。

结构：

- `snapshot`: Dictionary，get_health_snapshot() 返回结构。
