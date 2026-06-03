# GFCommandSequence

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_command_sequence.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用顺序指令执行器。 可运行 `GFSequenceStep`、`GFCommand` 或任何实现 `execute()` / `resolve()` 的对象。它只负责顺序、等待和架构注入，不规定具体业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`sequence_started`](#member-gfcommandsequence-signals-sequence_started) | `signal sequence_started` |
| 信号 | [`step_started`](#member-gfcommandsequence-signals-step_started) | `signal step_started(index: int, step: Variant)` |
| 信号 | [`step_completed`](#member-gfcommandsequence-signals-step_completed) | `signal step_completed(index: int, step: Variant)` |
| 信号 | [`step_failed`](#member-gfcommandsequence-signals-step_failed) | `signal step_failed(index: int, step: Variant, error: String)` |
| 信号 | [`sequence_completed`](#member-gfcommandsequence-signals-sequence_completed) | `signal sequence_completed` |
| 信号 | [`sequence_failed`](#member-gfcommandsequence-signals-sequence_failed) | `signal sequence_failed(report: Dictionary)` |
| 信号 | [`sequence_cancelled`](#member-gfcommandsequence-signals-sequence_cancelled) | `signal sequence_cancelled` |
| 属性 | [`steps`](#member-gfcommandsequence-properties-steps) | `var steps: Array = []` |
| 属性 | [`context`](#member-gfcommandsequence-properties-context) | `var context: GFSequenceContext` |
| 属性 | [`is_running`](#member-gfcommandsequence-properties-is_running) | `var is_running: bool = false` |
| 属性 | [`signal_timeout_seconds`](#member-gfcommandsequence-properties-signal_timeout_seconds) | `var signal_timeout_seconds: float = 30.0` |
| 属性 | [`signal_timeout_respects_time_scale`](#member-gfcommandsequence-properties-signal_timeout_respects_time_scale) | `var signal_timeout_respects_time_scale: bool = true` |
| 属性 | [`stop_on_error`](#member-gfcommandsequence-properties-stop_on_error) | `var stop_on_error: bool = false` |
| 属性 | [`rollback_on_failure`](#member-gfcommandsequence-properties-rollback_on_failure) | `var rollback_on_failure: bool = false` |
| 属性 | [`last_run_report`](#member-gfcommandsequence-properties-last_run_report) | `var last_run_report: Dictionary = {}` |
| 方法 | [`_init`](#member-gfcommandsequence-methods-_init) | `func _init(p_steps: Array = [], p_context: GFSequenceContext = null) -> void:` |
| 方法 | [`run`](#member-gfcommandsequence-methods-run) | `func run(p_steps: Array = []) -> void:` |
| 方法 | [`cancel`](#member-gfcommandsequence-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`with_signal_timeout`](#member-gfcommandsequence-methods-with_signal_timeout) | `func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFCommandSequence:` |
| 方法 | [`with_failure_policy`](#member-gfcommandsequence-methods-with_failure_policy) | `func with_failure_policy( should_stop_on_error: bool = true, should_rollback_on_failure: bool = false ) -> GFCommandSequence:` |

## 信号

<a id="member-gfcommandsequence-signals-sequence_started"></a>

### `sequence_started`

- API：`public`

```gdscript
signal sequence_started
```

序列开始执行时发出。

<a id="member-gfcommandsequence-signals-step_started"></a>

### `step_started`

- API：`public`

```gdscript
signal step_started(index: int, step: Variant)
```

步骤开始执行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 步骤索引。 |
| `step` | 步骤对象、命令或 Callable。 |

结构：

- `step`: Variant sequence step value.

<a id="member-gfcommandsequence-signals-step_completed"></a>

### `step_completed`

- API：`public`

```gdscript
signal step_completed(index: int, step: Variant)
```

步骤执行完毕时发出。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 步骤索引。 |
| `step` | 步骤对象、命令或 Callable。 |

结构：

- `step`: Variant sequence step value.

<a id="member-gfcommandsequence-signals-step_failed"></a>

### `step_failed`

- API：`public`

```gdscript
signal step_failed(index: int, step: Variant, error: String)
```

步骤报告失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `index` | 步骤索引。 |
| `step` | 步骤对象、命令或 Callable。 |
| `error` | 错误消息。 |

结构：

- `step`: Variant sequence step value.

<a id="member-gfcommandsequence-signals-sequence_completed"></a>

### `sequence_completed`

- API：`public`

```gdscript
signal sequence_completed
```

序列全部执行完成时发出。

<a id="member-gfcommandsequence-signals-sequence_failed"></a>

### `sequence_failed`

- API：`public`

```gdscript
signal sequence_failed(report: Dictionary)
```

序列因步骤失败而停止时发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 运行报告。 |

结构：

- `report`: Dictionary run report.

<a id="member-gfcommandsequence-signals-sequence_cancelled"></a>

### `sequence_cancelled`

- API：`public`

```gdscript
signal sequence_cancelled
```

序列被取消时发出。

## 属性

<a id="member-gfcommandsequence-properties-steps"></a>

### `steps`

- API：`public`

```gdscript
var steps: Array = []
```

默认步骤列表。

结构：

- `steps`: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().

<a id="member-gfcommandsequence-properties-context"></a>

### `context`

- API：`public`

```gdscript
var context: GFSequenceContext
```

序列上下文。

<a id="member-gfcommandsequence-properties-is_running"></a>

### `is_running`

- API：`public`

```gdscript
var is_running: bool = false
```

当前是否正在执行。

<a id="member-gfcommandsequence-properties-signal_timeout_seconds"></a>

### `signal_timeout_seconds`

- API：`public`

```gdscript
var signal_timeout_seconds: float = 30.0
```

等待步骤 Signal 的超时时间（秒）。小于等于 0 时表示不启用超时。

<a id="member-gfcommandsequence-properties-signal_timeout_respects_time_scale"></a>

### `signal_timeout_respects_time_scale`

- API：`public`

```gdscript
var signal_timeout_respects_time_scale: bool = true
```

Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。

<a id="member-gfcommandsequence-properties-stop_on_error"></a>

### `stop_on_error`

- API：`public`

```gdscript
var stop_on_error: bool = false
```

步骤返回失败结果时是否停止后续步骤。

<a id="member-gfcommandsequence-properties-rollback_on_failure"></a>

### `rollback_on_failure`

- API：`public`

```gdscript
var rollback_on_failure: bool = false
```

stop_on_error 生效后，是否对已完成且实现 undo() 的步骤逆序回滚。

<a id="member-gfcommandsequence-properties-last_run_report"></a>

### `last_run_report`

- API：`public`

```gdscript
var last_run_report: Dictionary = {}
```

最近一次运行报告。

结构：

- `last_run_report`: Dictionary run report from the most recent run().

## 方法

<a id="member-gfcommandsequence-methods-_init"></a>

### `_init`

- API：`public`

```gdscript
func _init(p_steps: Array = [], p_context: GFSequenceContext = null) -> void:
```

创建指令序列。

参数：

| 名称 | 说明 |
|---|---|
| `p_steps` | 初始步骤列表。 |
| `p_context` | 初始序列上下文；为空时自动创建。 |

结构：

- `p_steps`: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().

<a id="member-gfcommandsequence-methods-run"></a>

### `run`

- API：`public`

```gdscript
func run(p_steps: Array = []) -> void:
```

运行序列。

参数：

| 名称 | 说明 |
|---|---|
| `p_steps` | 可选临时步骤列表；为空时使用 `steps`。 |

结构：

- `p_steps`: Array of GFSequenceStep, GFCommand, Callable, or objects with execute()/resolve().

<a id="member-gfcommandsequence-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

请求取消序列。当前步骤实现取消入口时会先收到取消请求，正在等待的 Signal 会在下一帧取消检查后停止。

<a id="member-gfcommandsequence-methods-with_signal_timeout"></a>

### `with_signal_timeout`

- API：`public`

```gdscript
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFCommandSequence:
```

设置等待 Signal 的超时时间，并返回自身以便链式调用。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时时间；小于等于 0 时表示不启用超时。 |
| `respect_time_scale` | 是否跟随 GFTimeUtility 的暂停与 time_scale。 |

返回：当前序列。

<a id="member-gfcommandsequence-methods-with_failure_policy"></a>

### `with_failure_policy`

- API：`public`

```gdscript
func with_failure_policy( should_stop_on_error: bool = true, should_rollback_on_failure: bool = false ) -> GFCommandSequence:
```

设置失败处理策略，并返回自身以便链式调用。

参数：

| 名称 | 说明 |
|---|---|
| `should_stop_on_error` | 是否在失败结果后停止。 |
| `should_rollback_on_failure` | 是否逆序调用已完成步骤 undo()。 |

返回：当前序列。
