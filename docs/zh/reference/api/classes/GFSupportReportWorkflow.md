# GFSupportReportWorkflow

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_support_report_workflow.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

支持报告构建、提交与离线重放协调器。 组合 GFSupportReportUtility 与 GFRequestOutboxUtility，提供“先直接提交，失败或离线时入队， 之后通过调用方传入的 transport 重放”的通用工作流。它不绑定任何工单系统、账号、网络 SDK 或 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`workflow_report_built`](#member-gfsupportreportworkflow-signals-workflow_report_built) | `signal workflow_report_built(report: Dictionary)` |
| 信号 | [`workflow_report_submitted`](#member-gfsupportreportworkflow-signals-workflow_report_submitted) | `signal workflow_report_submitted(report: Dictionary, result: Dictionary)` |
| 信号 | [`workflow_report_queued`](#member-gfsupportreportworkflow-signals-workflow_report_queued) | `signal workflow_report_queued(report: Dictionary, envelope: GFRequestEnvelope)` |
| 信号 | [`workflow_replay_completed`](#member-gfsupportreportworkflow-signals-workflow_replay_completed) | `signal workflow_replay_completed(result: Dictionary)` |
| 属性 | [`support_report_utility`](#member-gfsupportreportworkflow-properties-support_report_utility) | `var support_report_utility: GFSupportReportUtility = null` |
| 属性 | [`request_outbox`](#member-gfsupportreportworkflow-properties-request_outbox) | `var request_outbox: GFRequestOutboxUtility = null` |
| 属性 | [`transport_callback`](#member-gfsupportreportworkflow-properties-transport_callback) | `var transport_callback: Callable = Callable()` |
| 属性 | [`request_url`](#member-gfsupportreportworkflow-properties-request_url) | `var request_url: String = "gf://support-report"` |
| 属性 | [`queue_on_submit_failure`](#member-gfsupportreportworkflow-properties-queue_on_submit_failure) | `var queue_on_submit_failure: bool = true` |
| 属性 | [`queue_when_transport_missing`](#member-gfsupportreportworkflow-properties-queue_when_transport_missing) | `var queue_when_transport_missing: bool = true` |
| 属性 | [`auto_wire_outbox_transport`](#member-gfsupportreportworkflow-properties-auto_wire_outbox_transport) | `var auto_wire_outbox_transport: bool = true` |
| 属性 | [`session_metadata`](#member-gfsupportreportworkflow-properties-session_metadata) | `var session_metadata: Dictionary = {}` |
| 方法 | [`dispose`](#member-gfsupportreportworkflow-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`setup`](#member-gfsupportreportworkflow-methods-setup) | `func setup( report_utility: GFSupportReportUtility = null, outbox: GFRequestOutboxUtility = null ) -> GFSupportReportWorkflow:` |
| 方法 | [`set_transport`](#member-gfsupportreportworkflow-methods-set_transport) | `func set_transport(callback: Callable) -> GFSupportReportWorkflow:` |
| 方法 | [`set_session_metadata`](#member-gfsupportreportworkflow-methods-set_session_metadata) | `func set_session_metadata(metadata: Dictionary, merge_existing: bool = false) -> GFSupportReportWorkflow:` |
| 方法 | [`build_report`](#member-gfsupportreportworkflow-methods-build_report) | `func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`submit_report`](#member-gfsupportreportworkflow-methods-submit_report) | `func submit_report(description: String = "", options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`submit_built_report`](#member-gfsupportreportworkflow-methods-submit_built_report) | `func submit_built_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`queue_report`](#member-gfsupportreportworkflow-methods-queue_report) | `func queue_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`replay_queued`](#member-gfsupportreportworkflow-methods-replay_queued) | `func replay_queued(max_count: int = 0) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfsupportreportworkflow-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfsupportreportworkflow-signals-workflow_report_built"></a>

### `workflow_report_built`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal workflow_report_built(report: Dictionary)
```

工作流构建支持报告后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 已构建的支持报告。 |

结构：

- `report`: Dictionary，GFSupportReportUtility.build_report() 返回结构。

<a id="member-gfsupportreportworkflow-signals-workflow_report_submitted"></a>

### `workflow_report_submitted`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal workflow_report_submitted(report: Dictionary, result: Dictionary)
```

工作流直接提交支持报告成功后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 已提交的支持报告。 |
| `result` | 提交结果。 |

结构：

- `report`: Dictionary，GFSupportReportUtility.build_report() 返回结构。
- `result`: Dictionary，包含 ok、value、error、metadata。

<a id="member-gfsupportreportworkflow-signals-workflow_report_queued"></a>

### `workflow_report_queued`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal workflow_report_queued(report: Dictionary, envelope: GFRequestEnvelope)
```

工作流把支持报告写入离线队列后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 已入队的支持报告。 |
| `envelope` | 入队请求描述。 |

结构：

- `report`: Dictionary，GFSupportReportUtility.build_report() 返回结构。

<a id="member-gfsupportreportworkflow-signals-workflow_replay_completed"></a>

### `workflow_replay_completed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal workflow_replay_completed(result: Dictionary)
```

工作流完成一次离线队列重放后发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 重放报告。 |

结构：

- `result`: Dictionary，GFRequestOutboxUtility.replay() 返回结构。

## 属性

<a id="member-gfsupportreportworkflow-properties-support_report_utility"></a>

### `support_report_utility`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var support_report_utility: GFSupportReportUtility = null
```

底层支持报告工具。为空时会按需创建。

<a id="member-gfsupportreportworkflow-properties-request_outbox"></a>

### `request_outbox`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var request_outbox: GFRequestOutboxUtility = null
```

可选离线请求队列。为空时 workflow 只尝试直接提交。

<a id="member-gfsupportreportworkflow-properties-transport_callback"></a>

### `transport_callback`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var transport_callback: Callable = Callable()
```

直接提交或重放时使用的传输回调，建议签名为 func(report: Dictionary, options: Dictionary) -> Variant。

<a id="member-gfsupportreportworkflow-properties-request_url"></a>

### `request_url`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var request_url: String = "gf://support-report"
```

离线队列请求目标。它只是逻辑端点，项目可按自己的传输层解释。

<a id="member-gfsupportreportworkflow-properties-queue_on_submit_failure"></a>

### `queue_on_submit_failure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var queue_on_submit_failure: bool = true
```

直接提交失败时是否尝试写入 request_outbox。

<a id="member-gfsupportreportworkflow-properties-queue_when_transport_missing"></a>

### `queue_when_transport_missing`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var queue_when_transport_missing: bool = true
```

缺少 transport_callback 时是否尝试写入 request_outbox。

<a id="member-gfsupportreportworkflow-properties-auto_wire_outbox_transport"></a>

### `auto_wire_outbox_transport`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var auto_wire_outbox_transport: bool = true
```

设置 transport_callback 后是否自动把 request_outbox.transport_callback 指向本工作流。

<a id="member-gfsupportreportworkflow-properties-session_metadata"></a>

### `session_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var session_metadata: Dictionary = {}
```

每次构建报告都会合并的会话元数据。调用 build_report() 时传入的 metadata 优先生效。

结构：

- `session_metadata`: Dictionary，项目自定义诊断上下文。

## 方法

<a id="member-gfsupportreportworkflow-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func dispose() -> void:
```

释放工作流运行时状态。

<a id="member-gfsupportreportworkflow-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func setup( report_utility: GFSupportReportUtility = null, outbox: GFRequestOutboxUtility = null ) -> GFSupportReportWorkflow:
```

配置底层报告工具与离线队列。

参数：

| 名称 | 说明 |
|---|---|
| `report_utility` | 支持报告工具；为空时保持现有值。 |
| `outbox` | 离线请求队列；为空时保持现有值。 |

返回：当前工作流。

<a id="member-gfsupportreportworkflow-methods-set_transport"></a>

### `set_transport`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_transport(callback: Callable) -> GFSupportReportWorkflow:
```

设置直接提交与离线重放使用的传输回调。

参数：

| 名称 | 说明 |
|---|---|
| `callback` | 传输回调，建议签名为 func(report: Dictionary, options: Dictionary) -> Variant。 |

返回：当前工作流。

<a id="member-gfsupportreportworkflow-methods-set_session_metadata"></a>

### `set_session_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_session_metadata(metadata: Dictionary, merge_existing: bool = false) -> GFSupportReportWorkflow:
```

设置会话元数据。

参数：

| 名称 | 说明 |
|---|---|
| `metadata` | 新元数据。 |
| `merge_existing` | 为 true 时合并到现有 session_metadata；为 false 时替换。 |

返回：当前工作流。

结构：

- `metadata`: Dictionary，项目自定义诊断上下文。

<a id="member-gfsupportreportworkflow-methods-build_report"></a>

### `build_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:
```

构建支持报告，并自动合并 session_metadata。

参数：

| 名称 | 说明 |
|---|---|
| `description` | 用户描述或问题摘要。 |
| `options` | GFSupportReportUtility.build_report() 选项。 |

返回：支持报告字典。

结构：

- `options`: Dictionary，支持 GFSupportReportUtility.build_report() 的全部选项。
- `return`: Dictionary，GFSupportReportUtility.build_report() 返回结构。

<a id="member-gfsupportreportworkflow-methods-submit_report"></a>

### `submit_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func submit_report(description: String = "", options: Dictionary = {}) -> Dictionary:
```

构建并提交支持报告。

参数：

| 名称 | 说明 |
|---|---|
| `description` | 用户描述或问题摘要。 |
| `options` | 提交选项，支持 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。 |

返回：工作流结果。

结构：

- `options`: Dictionary，包含构建选项以及 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
- `return`: Dictionary，包含 ok、status、report、submit_result、queue_result、error。

<a id="member-gfsupportreportworkflow-methods-submit_built_report"></a>

### `submit_built_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func submit_built_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

提交已经构建好的支持报告。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 支持报告字典。 |
| `options` | 提交选项，支持 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。 |

返回：工作流结果。

结构：

- `report`: Dictionary，GFSupportReportUtility.build_report() 返回结构。
- `options`: Dictionary，包含 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
- `return`: Dictionary，包含 ok、status、report、submit_result、queue_result、error。

<a id="member-gfsupportreportworkflow-methods-queue_report"></a>

### `queue_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func queue_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将支持报告写入离线请求队列。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 支持报告字典。 |
| `options` | 入队选项，支持 request_url、headers、request_metadata、transport_options、max_attempts、idempotency_key。 |

返回：入队结果。

结构：

- `report`: Dictionary，GFSupportReportUtility.build_report() 返回结构。
- `options`: Dictionary，包含 request_url、headers、request_metadata、transport_options、max_attempts、idempotency_key。
- `return`: Dictionary，包含 ok、status、envelope、error。

<a id="member-gfsupportreportworkflow-methods-replay_queued"></a>

### `replay_queued`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func replay_queued(max_count: int = 0) -> Dictionary:
```

重放离线支持报告队列。

参数：

| 名称 | 说明 |
|---|---|
| `max_count` | 最多处理数量；小于等于 0 表示不限制。 |

返回：重放报告。

结构：

- `return`: Dictionary，GFRequestOutboxUtility.replay() 返回结构；缺少 outbox 时包含 ok=false 和 reason。

<a id="member-gfsupportreportworkflow-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取工作流调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含工具配置、计数和 outbox 快照。
