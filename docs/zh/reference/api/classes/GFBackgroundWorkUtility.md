# GFBackgroundWorkUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_background_work_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

纯数据后台工作协调器。 统一协调 CPU/IO 线程工作、ResourceLoader 线程加载和主线程应用回调。 默认只允许纯 Variant 输入数据，避免后台线程直接触碰 Node、Resource 或 Callable。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`work_queued`](#member-gfbackgroundworkutility-signals-work_queued) | `signal work_queued(task: GFBackgroundWorkTask)` |
| 信号 | [`work_started`](#member-gfbackgroundworkutility-signals-work_started) | `signal work_started(task: GFBackgroundWorkTask)` |
| 信号 | [`work_progressed`](#member-gfbackgroundworkutility-signals-work_progressed) | `signal work_progressed(task: GFBackgroundWorkTask, progress: float, message: String)` |
| 信号 | [`work_completed`](#member-gfbackgroundworkutility-signals-work_completed) | `signal work_completed(task: GFBackgroundWorkTask)` |
| 信号 | [`work_failed`](#member-gfbackgroundworkutility-signals-work_failed) | `signal work_failed(task: GFBackgroundWorkTask)` |
| 信号 | [`work_cancelled`](#member-gfbackgroundworkutility-signals-work_cancelled) | `signal work_cancelled(task: GFBackgroundWorkTask)` |
| 信号 | [`work_applied`](#member-gfbackgroundworkutility-signals-work_applied) | `signal work_applied(task: GFBackgroundWorkTask)` |
| 属性 | [`max_threaded_tasks`](#member-gfbackgroundworkutility-properties-max_threaded_tasks) | `var max_threaded_tasks: int = 2:` |
| 属性 | [`max_apply_per_tick`](#member-gfbackgroundworkutility-properties-max_apply_per_tick) | `var max_apply_per_tick: int = 8:` |
| 属性 | [`max_apply_seconds_per_tick`](#member-gfbackgroundworkutility-properties-max_apply_seconds_per_tick) | `var max_apply_seconds_per_tick: float = 0.0:` |
| 属性 | [`max_finished_tasks`](#member-gfbackgroundworkutility-properties-max_finished_tasks) | `var max_finished_tasks: int = 128:` |
| 属性 | [`allow_object_payloads`](#member-gfbackgroundworkutility-properties-allow_object_payloads) | `var allow_object_payloads: bool = false` |
| 方法 | [`init`](#member-gfbackgroundworkutility-methods-init) | `func init() -> void:` |
| 方法 | [`tick`](#member-gfbackgroundworkutility-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`dispose`](#member-gfbackgroundworkutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`submit_cpu_work`](#member-gfbackgroundworkutility-methods-submit_cpu_work) | `func submit_cpu_work( worker: Callable, input_data: Variant = null, apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:` |
| 方法 | [`submit_io_work`](#member-gfbackgroundworkutility-methods-submit_io_work) | `func submit_io_work( worker: Callable, input_data: Variant = null, apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:` |
| 方法 | [`submit_resource_load`](#member-gfbackgroundworkutility-methods-submit_resource_load) | `func submit_resource_load( path: String, type_hint: String = "", apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:` |
| 方法 | [`cancel_work`](#member-gfbackgroundworkutility-methods-cancel_work) | `func cancel_work(work_id: StringName) -> bool:` |
| 方法 | [`cancel_all`](#member-gfbackgroundworkutility-methods-cancel_all) | `func cancel_all() -> void:` |
| 方法 | [`pause`](#member-gfbackgroundworkutility-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfbackgroundworkutility-methods-resume) | `func resume() -> void:` |
| 方法 | [`is_paused`](#member-gfbackgroundworkutility-methods-is_paused) | `func is_paused() -> bool:` |
| 方法 | [`update_work_progress`](#member-gfbackgroundworkutility-methods-update_work_progress) | `func update_work_progress(work_id: StringName, progress: float, message: String = "") -> bool:` |
| 方法 | [`get_task`](#member-gfbackgroundworkutility-methods-get_task) | `func get_task(work_id: StringName) -> GFBackgroundWorkTask:` |
| 方法 | [`clear_finished_tasks`](#member-gfbackgroundworkutility-methods-clear_finished_tasks) | `func clear_finished_tasks() -> void:` |
| 方法 | [`clear_all`](#member-gfbackgroundworkutility-methods-clear_all) | `func clear_all() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfbackgroundworkutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfbackgroundworkutility-signals-work_queued"></a>

### `work_queued`

- API：`public`

```gdscript
signal work_queued(task: GFBackgroundWorkTask)
```

工作进入等待队列时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

<a id="member-gfbackgroundworkutility-signals-work_started"></a>

### `work_started`

- API：`public`

```gdscript
signal work_started(task: GFBackgroundWorkTask)
```

工作开始执行时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

<a id="member-gfbackgroundworkutility-signals-work_progressed"></a>

### `work_progressed`

- API：`public`

```gdscript
signal work_progressed(task: GFBackgroundWorkTask, progress: float, message: String)
```

工作进度变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |
| `progress` | 当前进度。 |
| `message` | 进度说明。 |

<a id="member-gfbackgroundworkutility-signals-work_completed"></a>

### `work_completed`

- API：`public`

```gdscript
signal work_completed(task: GFBackgroundWorkTask)
```

工作完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

<a id="member-gfbackgroundworkutility-signals-work_failed"></a>

### `work_failed`

- API：`public`

```gdscript
signal work_failed(task: GFBackgroundWorkTask)
```

工作失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

<a id="member-gfbackgroundworkutility-signals-work_cancelled"></a>

### `work_cancelled`

- API：`public`

```gdscript
signal work_cancelled(task: GFBackgroundWorkTask)
```

工作取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

<a id="member-gfbackgroundworkutility-signals-work_applied"></a>

### `work_applied`

- API：`public`

```gdscript
signal work_applied(task: GFBackgroundWorkTask)
```

工作结果已在主线程应用时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 工作记录。 |

## 属性

<a id="member-gfbackgroundworkutility-properties-max_threaded_tasks"></a>

### `max_threaded_tasks`

- API：`public`

```gdscript
var max_threaded_tasks: int = 2:
```

同时运行的 CPU/IO 线程任务上限。

<a id="member-gfbackgroundworkutility-properties-max_apply_per_tick"></a>

### `max_apply_per_tick`

- API：`public`

```gdscript
var max_apply_per_tick: int = 8:
```

单帧最多执行多少个主线程应用回调。

<a id="member-gfbackgroundworkutility-properties-max_apply_seconds_per_tick"></a>

### `max_apply_seconds_per_tick`

- API：`public`

```gdscript
var max_apply_seconds_per_tick: float = 0.0:
```

单帧主线程应用回调的最大秒数。小于等于 0 时不启用时间预算；启用时每帧仍至少尝试一个应用回调。

<a id="member-gfbackgroundworkutility-properties-max_finished_tasks"></a>

### `max_finished_tasks`

- API：`public`

```gdscript
var max_finished_tasks: int = 128:
```

最多保留多少个终态任务用于调试快照；设为 0 时不保留历史。

<a id="member-gfbackgroundworkutility-properties-allow_object_payloads"></a>

### `allow_object_payloads`

- API：`public`

```gdscript
var allow_object_payloads: bool = false
```

是否默认允许 Object、Resource、Callable、Signal 或 RID 进入线程 payload。 仅迁移旧项目或明确自行保证线程安全时才建议开启。

## 方法

<a id="member-gfbackgroundworkutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化后台工作协调器并启用暂停无关处理。

<a id="member-gfbackgroundworkutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

推进后台工作完成检查与主线程应用。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 为兼容统一 tick 签名而保留的参数。 |

<a id="member-gfbackgroundworkutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

取消未完成工作、等待线程结束并清理运行时状态。

<a id="member-gfbackgroundworkutility-methods-submit_cpu_work"></a>

### `submit_cpu_work`

- API：`public`

```gdscript
func submit_cpu_work( worker: Callable, input_data: Variant = null, apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:
```

提交 CPU 纯数据后台工作。

参数：

| 名称 | 说明 |
|---|---|
| `worker` | 后台线程回调，签名推荐为 func(input_data: Variant) -> Variant。 |
| `input_data` | 输入数据。默认只允许纯 Variant 容器和值。 |
| `apply_callback` | 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。 |
| `options` | 可选配置，支持 id、priority、metadata、front、allow_object_payloads。 |

返回：工作记录；参数无效时返回 failed 状态任务。

结构：

- `input_data`: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
- `options`: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool 和 allow_object_payloads: bool。

<a id="member-gfbackgroundworkutility-methods-submit_io_work"></a>

### `submit_io_work`

- API：`public`

```gdscript
func submit_io_work( worker: Callable, input_data: Variant = null, apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:
```

提交 IO 纯数据后台工作。

参数：

| 名称 | 说明 |
|---|---|
| `worker` | 后台线程回调，签名推荐为 func(input_data: Variant) -> Variant。 |
| `input_data` | 输入数据。默认只允许纯 Variant 容器和值。 |
| `apply_callback` | 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。 |
| `options` | 可选配置，支持 id、priority、metadata、front、allow_object_payloads。 |

返回：工作记录；参数无效时返回 failed 状态任务。

结构：

- `input_data`: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。
- `options`: Dictionary，包含 id: StringName/String、priority: int、metadata: Dictionary、front: bool 和 allow_object_payloads: bool。

<a id="member-gfbackgroundworkutility-methods-submit_resource_load"></a>

### `submit_resource_load`

- API：`public`

```gdscript
func submit_resource_load( path: String, type_hint: String = "", apply_callback: Callable = Callable(), options: Dictionary = {} ) -> GFBackgroundWorkTask:
```

提交 ResourceLoader 后台资源加载。

参数：

| 名称 | 说明 |
|---|---|
| `path` | 资源路径。 |
| `type_hint` | 可选资源类型提示。 |
| `apply_callback` | 主线程应用回调，签名推荐为 func(task: GFBackgroundWorkTask) -> Variant。 |
| `options` | 可选配置，支持 id、priority、metadata。 |

返回：工作记录；参数无效或请求失败时返回 failed 状态任务。

结构：

- `options`: Dictionary，包含 id: StringName/String、priority: int 和 metadata: Dictionary。

<a id="member-gfbackgroundworkutility-methods-cancel_work"></a>

### `cancel_work`

- API：`public`

```gdscript
func cancel_work(work_id: StringName) -> bool:
```

取消指定工作。

参数：

| 名称 | 说明 |
|---|---|
| `work_id` | 工作 ID。 |

返回：取消成功返回 true。

<a id="member-gfbackgroundworkutility-methods-cancel_all"></a>

### `cancel_all`

- API：`public`

```gdscript
func cancel_all() -> void:
```

取消全部未完成工作。

<a id="member-gfbackgroundworkutility-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停启动新的 CPU/IO 线程工作；已运行和资源加载中的工作会继续推进。

<a id="member-gfbackgroundworkutility-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复启动新的 CPU/IO 线程工作。

<a id="member-gfbackgroundworkutility-methods-is_paused"></a>

### `is_paused`

- API：`public`

```gdscript
func is_paused() -> bool:
```

检查是否暂停。

返回：暂停时返回 true。

<a id="member-gfbackgroundworkutility-methods-update_work_progress"></a>

### `update_work_progress`

- API：`public`

```gdscript
func update_work_progress(work_id: StringName, progress: float, message: String = "") -> bool:
```

更新工作进度。

参数：

| 名称 | 说明 |
|---|---|
| `work_id` | 工作 ID。 |
| `progress` | 当前进度。 |
| `message` | 进度说明。 |

返回：更新成功返回 true。

<a id="member-gfbackgroundworkutility-methods-get_task"></a>

### `get_task`

- API：`public`

```gdscript
func get_task(work_id: StringName) -> GFBackgroundWorkTask:
```

获取工作。

参数：

| 名称 | 说明 |
|---|---|
| `work_id` | 工作 ID。 |

返回：工作记录；不存在时返回 null。

<a id="member-gfbackgroundworkutility-methods-clear_finished_tasks"></a>

### `clear_finished_tasks`

- API：`public`

```gdscript
func clear_finished_tasks() -> void:
```

清理已完成的历史工作记录。

<a id="member-gfbackgroundworkutility-methods-clear_all"></a>

### `clear_all`

- API：`public`

```gdscript
func clear_all() -> void:
```

清空全部工作。调用前应确保不再需要正在执行的线程结果。

<a id="member-gfbackgroundworkutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含任务计数、queued_ids、running_thread_ids、resource_paths、apply_ids、finished_ids、暂停状态和 apply 时间预算。
