# GFJobWorker

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_job_worker.gd`
- 模块：`Standard`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用任务队列消费节点。 从 `GFJobQueueUtility` 中按批次取出等待任务，并交给项目提供的 Callable 处理。 Worker 只管理执行节奏和完成/失败写回，不规定任务数据结构或业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`worker_started`](#member-gfjobworker-signals-worker_started) | `signal worker_started` |
| 信号 | [`worker_stopped`](#member-gfjobworker-signals-worker_stopped) | `signal worker_stopped` |
| 信号 | [`job_processed`](#member-gfjobworker-signals-job_processed) | `signal job_processed(job: GFJob)` |
| 信号 | [`worker_idle`](#member-gfjobworker-signals-worker_idle) | `signal worker_idle` |
| 属性 | [`queue_name`](#member-gfjobworker-properties-queue_name) | `var queue_name: StringName = &"default"` |
| 属性 | [`batch_size`](#member-gfjobworker-properties-batch_size) | `var batch_size: int = 1` |
| 属性 | [`auto_start`](#member-gfjobworker-properties-auto_start) | `var auto_start: bool = true` |
| 属性 | [`process_in_physics`](#member-gfjobworker-properties-process_in_physics) | `var process_in_physics: bool = false` |
| 属性 | [`process_while_paused`](#member-gfjobworker-properties-process_while_paused) | `var process_while_paused: bool = false` |
| 属性 | [`signal_timeout_seconds`](#member-gfjobworker-properties-signal_timeout_seconds) | `var signal_timeout_seconds: float = 30.0` |
| 属性 | [`signal_timeout_respects_time_scale`](#member-gfjobworker-properties-signal_timeout_respects_time_scale) | `var signal_timeout_respects_time_scale: bool = true` |
| 属性 | [`queue_utility`](#member-gfjobworker-properties-queue_utility) | `var queue_utility: GFJobQueueUtility = null` |
| 属性 | [`processor`](#member-gfjobworker-properties-processor) | `var processor: Callable = Callable()` |
| 方法 | [`set_queue_utility`](#member-gfjobworker-methods-set_queue_utility) | `func set_queue_utility(utility: GFJobQueueUtility) -> void:` |
| 方法 | [`set_processor`](#member-gfjobworker-methods-set_processor) | `func set_processor(job_processor: Callable) -> void:` |
| 方法 | [`start`](#member-gfjobworker-methods-start) | `func start() -> void:` |
| 方法 | [`stop`](#member-gfjobworker-methods-stop) | `func stop() -> void:` |
| 方法 | [`is_running`](#member-gfjobworker-methods-is_running) | `func is_running() -> bool:` |
| 方法 | [`process_next_job`](#member-gfjobworker-methods-process_next_job) | `func process_next_job() -> GFJob:` |
| 方法 | [`process_batch`](#member-gfjobworker-methods-process_batch) | `func process_batch() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfjobworker-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfjobworker-signals-worker_started"></a>

### `worker_started`

- API：`public`

```gdscript
signal worker_started
```

Worker 开始运行时发出。

<a id="member-gfjobworker-signals-worker_stopped"></a>

### `worker_stopped`

- API：`public`

```gdscript
signal worker_stopped
```

Worker 停止运行时发出。

<a id="member-gfjobworker-signals-job_processed"></a>

### `job_processed`

- API：`public`

```gdscript
signal job_processed(job: GFJob)
```

任务处理完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 被处理的任务。 |

<a id="member-gfjobworker-signals-worker_idle"></a>

### `worker_idle`

- API：`public`

```gdscript
signal worker_idle
```

没有可处理任务时发出。

## 属性

<a id="member-gfjobworker-properties-queue_name"></a>

### `queue_name`

- API：`public`

```gdscript
var queue_name: StringName = &"default"
```

消费的队列名。

<a id="member-gfjobworker-properties-batch_size"></a>

### `batch_size`

- API：`public`

```gdscript
var batch_size: int = 1
```

每次处理的最大任务数量。

<a id="member-gfjobworker-properties-auto_start"></a>

### `auto_start`

- API：`public`

```gdscript
var auto_start: bool = true
```

ready 后是否自动开始。

<a id="member-gfjobworker-properties-process_in_physics"></a>

### `process_in_physics`

- API：`public`

```gdscript
var process_in_physics: bool = false
```

是否在 physics process 中消费任务。

<a id="member-gfjobworker-properties-process_while_paused"></a>

### `process_while_paused`

- API：`public`

```gdscript
var process_while_paused: bool = false
```

SceneTree 暂停时是否继续处理。

<a id="member-gfjobworker-properties-signal_timeout_seconds"></a>

### `signal_timeout_seconds`

- API：`public`

```gdscript
var signal_timeout_seconds: float = 30.0
```

等待异步任务处理器 Signal 的最长秒数。小于等于 0 时不启用超时。

<a id="member-gfjobworker-properties-signal_timeout_respects_time_scale"></a>

### `signal_timeout_respects_time_scale`

- API：`public`

```gdscript
var signal_timeout_respects_time_scale: bool = true
```

Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。

<a id="member-gfjobworker-properties-queue_utility"></a>

### `queue_utility`

- API：`public`

```gdscript
var queue_utility: GFJobQueueUtility = null
```

可选任务队列工具实例；为空时从全局架构查询。

<a id="member-gfjobworker-properties-processor"></a>

### `processor`

- API：`public`

```gdscript
var processor: Callable = Callable()
```

任务处理器，签名推荐为 `func(job: GFJob) -> Variant`。

## 方法

<a id="member-gfjobworker-methods-set_queue_utility"></a>

### `set_queue_utility`

- API：`public`

```gdscript
func set_queue_utility(utility: GFJobQueueUtility) -> void:
```

设置任务队列工具实例。

参数：

| 名称 | 说明 |
|---|---|
| `utility` | 任务队列工具实例。 |

<a id="member-gfjobworker-methods-set_processor"></a>

### `set_processor`

- API：`public`

```gdscript
func set_processor(job_processor: Callable) -> void:
```

设置任务处理器。

参数：

| 名称 | 说明 |
|---|---|
| `job_processor` | 任务处理器。 |

<a id="member-gfjobworker-methods-start"></a>

### `start`

- API：`public`

```gdscript
func start() -> void:
```

开始消费任务。

<a id="member-gfjobworker-methods-stop"></a>

### `stop`

- API：`public`

```gdscript
func stop() -> void:
```

停止消费任务。

<a id="member-gfjobworker-methods-is_running"></a>

### `is_running`

- API：`public`

```gdscript
func is_running() -> bool:
```

检查 Worker 是否正在运行。

返回：正在运行返回 true。

<a id="member-gfjobworker-methods-process_next_job"></a>

### `process_next_job`

- API：`public`

```gdscript
func process_next_job() -> GFJob:
```

处理一个任务。

返回：被处理的任务；没有任务或不可处理时返回 null。

<a id="member-gfjobworker-methods-process_batch"></a>

### `process_batch`

- API：`public`

```gdscript
func process_batch() -> int:
```

按 batch_size 处理一批任务。

返回：实际处理数量。

<a id="member-gfjobworker-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Worker 调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 running、processing、queue_name、batch_size、has_processor 和 has_queue_utility。
