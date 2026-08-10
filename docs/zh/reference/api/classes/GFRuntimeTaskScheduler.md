# GFRuntimeTaskScheduler

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_runtime_task_scheduler.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

按 requirement 仲裁运行时任务的调度器。 调度器负责维护正在运行的 [GFRuntimeTask]、处理 requirement 冲突、执行可中断任务、 并在 requirement 空闲时恢复默认任务。它只提供通用生命周期与资源占用语义，不绑定输入、 动画、角色控制器或项目业务状态。 每次成功 schedule 都分配新的内部 generation；所有用户回调返回后都会复核该 generation， 因此旧生命周期不能继续推进或结束在回调中重新调度的同一对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`task_scheduled`](#member-gfruntimetaskscheduler-signals-task_scheduled) | `signal task_scheduled(task: GFRuntimeTask)` |
| 信号 | [`task_rejected`](#member-gfruntimetaskscheduler-signals-task_rejected) | `signal task_rejected(task: GFRuntimeTask, reason: StringName)` |
| 信号 | [`task_completed`](#member-gfruntimetaskscheduler-signals-task_completed) | `signal task_completed(task: GFRuntimeTask)` |
| 信号 | [`task_cancelled`](#member-gfruntimetaskscheduler-signals-task_cancelled) | `signal task_cancelled(task: GFRuntimeTask)` |
| 常量 | [`REJECTION_SCHEDULER_BUSY`](#member-gfruntimetaskscheduler-constants-rejection_scheduler_busy) | `const REJECTION_SCHEDULER_BUSY: StringName = &"scheduler_busy"` |
| 属性 | [`auto_schedule_default_tasks`](#member-gfruntimetaskscheduler-properties-auto_schedule_default_tasks) | `var auto_schedule_default_tasks: bool = true` |
| 方法 | [`_init`](#member-gfruntimetaskscheduler-methods-_init) | `func _init() -> void:` |
| 方法 | [`schedule`](#member-gfruntimetaskscheduler-methods-schedule) | `func schedule(task: GFRuntimeTask) -> bool:` |
| 方法 | [`cancel`](#member-gfruntimetaskscheduler-methods-cancel) | `func cancel(task: GFRuntimeTask) -> bool:` |
| 方法 | [`cancel_all`](#member-gfruntimetaskscheduler-methods-cancel_all) | `func cancel_all() -> void:` |
| 方法 | [`register_default_task`](#member-gfruntimetaskscheduler-methods-register_default_task) | `func register_default_task(requirement: Object, task: GFRuntimeTask) -> bool:` |
| 方法 | [`unregister_default_task`](#member-gfruntimetaskscheduler-methods-unregister_default_task) | `func unregister_default_task(requirement: Object) -> bool:` |
| 方法 | [`get_default_task`](#member-gfruntimetaskscheduler-methods-get_default_task) | `func get_default_task(requirement: Object) -> GFRuntimeTask:` |
| 方法 | [`is_scheduled`](#member-gfruntimetaskscheduler-methods-is_scheduled) | `func is_scheduled(task: GFRuntimeTask) -> bool:` |
| 方法 | [`is_requirement_available`](#member-gfruntimetaskscheduler-methods-is_requirement_available) | `func is_requirement_available(requirement: Object) -> bool:` |
| 方法 | [`get_task_for_requirement`](#member-gfruntimetaskscheduler-methods-get_task_for_requirement) | `func get_task_for_requirement(requirement: Object) -> GFRuntimeTask:` |
| 方法 | [`get_active_tasks`](#member-gfruntimetaskscheduler-methods-get_active_tasks) | `func get_active_tasks() -> Array[GFRuntimeTask]:` |
| 方法 | [`tick`](#member-gfruntimetaskscheduler-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfruntimetaskscheduler-methods-physics_tick) | `func physics_tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfruntimetaskscheduler-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimetaskscheduler-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfruntimetaskscheduler-signals-task_scheduled"></a>

### `task_scheduled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal task_scheduled(task: GFRuntimeTask)
```

任务成功进入调度器时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 成功进入调度器的任务。 |

<a id="member-gfruntimetaskscheduler-signals-task_rejected"></a>

### `task_rejected`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal task_rejected(task: GFRuntimeTask, reason: StringName)
```

任务因为冲突或无效参数被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 被拒绝的任务。 |
| `reason` | 拒绝原因。 |

<a id="member-gfruntimetaskscheduler-signals-task_completed"></a>

### `task_completed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal task_completed(task: GFRuntimeTask)
```

任务正常完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 正常完成的任务。 |

<a id="member-gfruntimetaskscheduler-signals-task_cancelled"></a>

### `task_cancelled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
signal task_cancelled(task: GFRuntimeTask)
```

任务被取消或中断时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 被取消或中断的任务。 |

## 常量

<a id="member-gfruntimetaskscheduler-constants-rejection_scheduler_busy"></a>

### `REJECTION_SCHEDULER_BUSY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REJECTION_SCHEDULER_BUSY: StringName = &"scheduler_busy"
```

调度器正在提交另一项任务所有权变更时的拒绝原因。

## 属性

<a id="member-gfruntimetaskscheduler-properties-auto_schedule_default_tasks"></a>

### `auto_schedule_default_tasks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var auto_schedule_default_tasks: bool = true
```

Requirement 空闲时是否自动调度已注册的默认任务。

## 方法

<a id="member-gfruntimetaskscheduler-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func _init() -> void:
```

创建运行时任务调度器。

<a id="member-gfruntimetaskscheduler-methods-schedule"></a>

### `schedule`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func schedule(task: GFRuntimeTask) -> bool:
```

调度一个任务。 若任务 requirement 被不可中断任务占用，本方法返回 [code]false[/code] 并发出 [signal task_rejected]。若冲突任务可中断，调度器会先取消冲突任务再调度新任务。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 要调度的任务。 |

返回：成功进入调度器或已在调度器中时返回 true。

<a id="member-gfruntimetaskscheduler-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func cancel(task: GFRuntimeTask) -> bool:
```

取消一个任务。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 要取消的任务。 |

返回：成功取消时返回 true。

<a id="member-gfruntimetaskscheduler-methods-cancel_all"></a>

### `cancel_all`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func cancel_all() -> void:
```

取消所有任务。

<a id="member-gfruntimetaskscheduler-methods-register_default_task"></a>

### `register_default_task`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func register_default_task(requirement: Object, task: GFRuntimeTask) -> bool:
```

注册 requirement 空闲时应运行的默认任务。 默认任务会自动添加该 requirement。若任务需要占用更多对象，可在注册前或注册后继续 调用 [method GFRuntimeTask.add_requirement]。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 空闲时应恢复默认任务的对象。 |
| `task` | 默认任务。 |

返回：注册成功时返回 true。

<a id="member-gfruntimetaskscheduler-methods-unregister_default_task"></a>

### `unregister_default_task`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func unregister_default_task(requirement: Object) -> bool:
```

注销 requirement 的默认任务。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要注销默认任务的对象。 |

返回：注销成功时返回 true。

<a id="member-gfruntimetaskscheduler-methods-get_default_task"></a>

### `get_default_task`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_default_task(requirement: Object) -> GFRuntimeTask:
```

返回 requirement 的默认任务。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要查询默认任务的对象。 |

返回：requirement 对应的默认任务；不存在时返回 null。

<a id="member-gfruntimetaskscheduler-methods-is_scheduled"></a>

### `is_scheduled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_scheduled(task: GFRuntimeTask) -> bool:
```

判断任务是否正在调度器中运行。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 要检查的任务。 |

返回：任务正在调度器中运行时返回 true。

<a id="member-gfruntimetaskscheduler-methods-is_requirement_available"></a>

### `is_requirement_available`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_requirement_available(requirement: Object) -> bool:
```

判断 requirement 是否空闲。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要检查的对象。 |

返回：requirement 当前没有任务占用时返回 true。

<a id="member-gfruntimetaskscheduler-methods-get_task_for_requirement"></a>

### `get_task_for_requirement`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_task_for_requirement(requirement: Object) -> GFRuntimeTask:
```

返回当前占用 requirement 的任务。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要查询占用任务的对象。 |

返回：当前占用 requirement 的任务；不存在时返回 null。

<a id="member-gfruntimetaskscheduler-methods-get_active_tasks"></a>

### `get_active_tasks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_active_tasks() -> Array[GFRuntimeTask]:
```

返回当前活动任务副本。

返回：当前活动任务副本。

<a id="member-gfruntimetaskscheduler-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进活动任务。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 帧间隔秒数。 |

<a id="member-gfruntimetaskscheduler-methods-physics_tick"></a>

### `physics_tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func physics_tick(delta: float) -> void:
```

推进活动任务的物理帧逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 物理帧间隔秒数。 |

<a id="member-gfruntimetaskscheduler-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func dispose() -> void:
```

释放调度器持有的任务。

<a id="member-gfruntimetaskscheduler-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

返回调度器诊断快照。

返回：调度器诊断快照。

结构：

- `return`: Dictionary with active_tasks, requirement_owner_ids, and default_requirement_ids.
