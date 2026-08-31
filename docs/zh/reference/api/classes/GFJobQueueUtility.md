# GFJobQueueUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_job_queue_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用任务队列工具。 提供等待、激活、完成、失败、取消、进度和调试快照能力。 队列不绑定执行线程或业务语义，具体执行由调用方决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`job_enqueued`](#member-gfjobqueueutility-signals-job_enqueued) | `signal job_enqueued(job: GFJob)` |
| 信号 | [`job_started`](#member-gfjobqueueutility-signals-job_started) | `signal job_started(job: GFJob)` |
| 信号 | [`job_progressed`](#member-gfjobqueueutility-signals-job_progressed) | `signal job_progressed(job: GFJob, progress: float, message: String)` |
| 信号 | [`job_completed`](#member-gfjobqueueutility-signals-job_completed) | `signal job_completed(job: GFJob)` |
| 信号 | [`job_failed`](#member-gfjobqueueutility-signals-job_failed) | `signal job_failed(job: GFJob)` |
| 信号 | [`job_cancelled`](#member-gfjobqueueutility-signals-job_cancelled) | `signal job_cancelled(job: GFJob)` |
| 属性 | [`max_completed_jobs`](#member-gfjobqueueutility-properties-max_completed_jobs) | `var max_completed_jobs: int = 64` |
| 属性 | [`max_failed_jobs`](#member-gfjobqueueutility-properties-max_failed_jobs) | `var max_failed_jobs: int = 64` |
| 属性 | [`max_cancelled_jobs`](#member-gfjobqueueutility-properties-max_cancelled_jobs) | `var max_cancelled_jobs: int = 64` |
| 方法 | [`init`](#member-gfjobqueueutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfjobqueueutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`enqueue`](#member-gfjobqueueutility-methods-enqueue) | `func enqueue( queue_name: StringName = &"default", data: Variant = null, metadata: Dictionary = {}, front: bool = false ) -> GFJob:` |
| 方法 | [`start_next_job`](#member-gfjobqueueutility-methods-start_next_job) | `func start_next_job(queue_name: StringName = &"default") -> GFJob:` |
| 方法 | [`run_next_job`](#member-gfjobqueueutility-methods-run_next_job) | `func run_next_job(queue_name: StringName, processor: Callable) -> GFJob:` |
| 方法 | [`update_job_progress`](#member-gfjobqueueutility-methods-update_job_progress) | `func update_job_progress(job_id: StringName, progress: float, message: String = "") -> bool:` |
| 方法 | [`complete_job`](#member-gfjobqueueutility-methods-complete_job) | `func complete_job(job_id: StringName, result: Variant = null) -> bool:` |
| 方法 | [`fail_job`](#member-gfjobqueueutility-methods-fail_job) | `func fail_job(job_id: StringName, error_message: String = "", result: Variant = null) -> bool:` |
| 方法 | [`cancel_job`](#member-gfjobqueueutility-methods-cancel_job) | `func cancel_job(job_id: StringName) -> bool:` |
| 方法 | [`pause_queue`](#member-gfjobqueueutility-methods-pause_queue) | `func pause_queue(queue_name: StringName = &"default") -> void:` |
| 方法 | [`resume_queue`](#member-gfjobqueueutility-methods-resume_queue) | `func resume_queue(queue_name: StringName = &"default") -> void:` |
| 方法 | [`is_queue_paused`](#member-gfjobqueueutility-methods-is_queue_paused) | `func is_queue_paused(queue_name: StringName = &"default") -> bool:` |
| 方法 | [`get_job`](#member-gfjobqueueutility-methods-get_job) | `func get_job(job_id: StringName) -> GFJob:` |
| 方法 | [`get_waiting_jobs`](#member-gfjobqueueutility-methods-get_waiting_jobs) | `func get_waiting_jobs(queue_name: StringName = &"default") -> Array[GFJob]:` |
| 方法 | [`clear_queue`](#member-gfjobqueueutility-methods-clear_queue) | `func clear_queue(queue_name: StringName = &"default", cancel_jobs: bool = true) -> void:` |
| 方法 | [`clear_all`](#member-gfjobqueueutility-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfjobqueueutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfjobqueueutility-signals-job_enqueued"></a>

### `job_enqueued`

- API：`public`

```gdscript
signal job_enqueued(job: GFJob)
```

任务进入等待队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |

<a id="member-gfjobqueueutility-signals-job_started"></a>

### `job_started`

- API：`public`

```gdscript
signal job_started(job: GFJob)
```

任务开始执行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |

<a id="member-gfjobqueueutility-signals-job_progressed"></a>

### `job_progressed`

- API：`public`

```gdscript
signal job_progressed(job: GFJob, progress: float, message: String)
```

任务进度变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |
| `progress` | 当前进度。 |
| `message` | 进度说明。 |

<a id="member-gfjobqueueutility-signals-job_completed"></a>

### `job_completed`

- API：`public`

```gdscript
signal job_completed(job: GFJob)
```

任务完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |

<a id="member-gfjobqueueutility-signals-job_failed"></a>

### `job_failed`

- API：`public`

```gdscript
signal job_failed(job: GFJob)
```

任务失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |

<a id="member-gfjobqueueutility-signals-job_cancelled"></a>

### `job_cancelled`

- API：`public`

```gdscript
signal job_cancelled(job: GFJob)
```

任务取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `job` | 任务记录。 |

## 属性

<a id="member-gfjobqueueutility-properties-max_completed_jobs"></a>

### `max_completed_jobs`

- API：`public`

```gdscript
var max_completed_jobs: int = 64
```

保留的完成任务数量。

<a id="member-gfjobqueueutility-properties-max_failed_jobs"></a>

### `max_failed_jobs`

- API：`public`

```gdscript
var max_failed_jobs: int = 64
```

保留的失败任务数量。

<a id="member-gfjobqueueutility-properties-max_cancelled_jobs"></a>

### `max_cancelled_jobs`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var max_cancelled_jobs: int = 64
```

保留的取消任务数量。

## 方法

<a id="member-gfjobqueueutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化任务队列工具并清空运行时状态。

<a id="member-gfjobqueueutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放任务队列工具持有的运行时状态。

<a id="member-gfjobqueueutility-methods-enqueue"></a>

### `enqueue`

- API：`public`

```gdscript
func enqueue( queue_name: StringName = &"default", data: Variant = null, metadata: Dictionary = {}, front: bool = false ) -> GFJob:
```

追加一个等待任务。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |
| `data` | 任务输入数据。 |
| `metadata` | 项目自定义元数据。 |
| `front` | 是否插入到队列头部。 |

返回：新任务记录。

结构：

- `data`: Variant，项目侧任务输入载荷。
- `metadata`: Dictionary，复制到新建 GFJob 的元数据。

<a id="member-gfjobqueueutility-methods-start_next_job"></a>

### `start_next_job`

- API：`public`

```gdscript
func start_next_job(queue_name: StringName = &"default") -> GFJob:
```

从队列取出下一个等待任务并标记为执行中。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |

返回：任务记录；没有可执行任务时返回 null。

<a id="member-gfjobqueueutility-methods-run_next_job"></a>

### `run_next_job`

- API：`public`

```gdscript
func run_next_job(queue_name: StringName, processor: Callable) -> GFJob:
```

使用回调立即处理下一个等待任务。回调返回 false 或 ok=false 字典时标记失败。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |
| `processor` | 任务处理回调。 |

返回：被处理的任务；没有可执行任务时返回 null。

<a id="member-gfjobqueueutility-methods-update_job_progress"></a>

### `update_job_progress`

- API：`public`

```gdscript
func update_job_progress(job_id: StringName, progress: float, message: String = "") -> bool:
```

更新任务进度。

参数：

| 名称 | 说明 |
|---|---|
| `job_id` | 任务 ID。 |
| `progress` | 当前进度。 |
| `message` | 进度说明。 |

返回：更新成功返回 true。

<a id="member-gfjobqueueutility-methods-complete_job"></a>

### `complete_job`

- API：`public`

```gdscript
func complete_job(job_id: StringName, result: Variant = null) -> bool:
```

标记任务完成。

参数：

| 名称 | 说明 |
|---|---|
| `job_id` | 任务 ID。 |
| `result` | 任务结果。 |

返回：完成成功返回 true。

结构：

- `result`: Variant，项目侧任务结果载荷。

<a id="member-gfjobqueueutility-methods-fail_job"></a>

### `fail_job`

- API：`public`

```gdscript
func fail_job(job_id: StringName, error_message: String = "", result: Variant = null) -> bool:
```

标记任务失败。

参数：

| 名称 | 说明 |
|---|---|
| `job_id` | 任务 ID。 |
| `error_message` | 错误文本。 |
| `result` | 可选失败结果。 |

返回：标记成功返回 true。

结构：

- `result`: Variant，项目侧失败结果载荷。

<a id="member-gfjobqueueutility-methods-cancel_job"></a>

### `cancel_job`

- API：`public`

```gdscript
func cancel_job(job_id: StringName) -> bool:
```

取消任务。

参数：

| 名称 | 说明 |
|---|---|
| `job_id` | 任务 ID。 |

返回：取消成功返回 true。

<a id="member-gfjobqueueutility-methods-pause_queue"></a>

### `pause_queue`

- API：`public`

```gdscript
func pause_queue(queue_name: StringName = &"default") -> void:
```

暂停指定队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |

<a id="member-gfjobqueueutility-methods-resume_queue"></a>

### `resume_queue`

- API：`public`

```gdscript
func resume_queue(queue_name: StringName = &"default") -> void:
```

恢复指定队列。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |

<a id="member-gfjobqueueutility-methods-is_queue_paused"></a>

### `is_queue_paused`

- API：`public`

```gdscript
func is_queue_paused(queue_name: StringName = &"default") -> bool:
```

检查队列是否暂停。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |

返回：暂停时返回 true。

<a id="member-gfjobqueueutility-methods-get_job"></a>

### `get_job`

- API：`public`

```gdscript
func get_job(job_id: StringName) -> GFJob:
```

获取任务。

参数：

| 名称 | 说明 |
|---|---|
| `job_id` | 任务 ID。 |

返回：任务记录；不存在时返回 null。

<a id="member-gfjobqueueutility-methods-get_waiting_jobs"></a>

### `get_waiting_jobs`

- API：`public`

```gdscript
func get_waiting_jobs(queue_name: StringName = &"default") -> Array[GFJob]:
```

获取队列中的等待任务。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |

返回：等待任务列表副本。

<a id="member-gfjobqueueutility-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue(queue_name: StringName = &"default", cancel_jobs: bool = true) -> void:
```

清空指定队列中的等待任务。

参数：

| 名称 | 说明 |
|---|---|
| `queue_name` | 队列名。 |
| `cancel_jobs` | 是否把等待任务标记为取消。 |

<a id="member-gfjobqueueutility-methods-clear_all"></a>

### `clear_all`

- API：`public`

```gdscript
func clear_all() -> void:
```

清空全部队列与历史任务。

<a id="member-gfjobqueueutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 job_count、queue_count、completed_count、failed_count、cancelled_count，以及以队列名为键的 queues。
