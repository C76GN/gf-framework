# GFRuntimeTaskGroup

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_runtime_task_group.gd`
- 模块：`Standard`
- 继承：`GFRuntimeTask`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`6.0.0`

组合多个运行时任务的复合任务。 任务组用于把多个 [GFRuntimeTask] 编排为顺序、等待全部或等待任一完成的流程。 子任务在组内部推进，不会单独注册到外层调度器；外层调度器只看到一个占用聚合后的任务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Mode`](#member-gfruntimetaskgroup-enums-mode) | `enum Mode` |
| 常量 | [`REJECTION_CHILD_SCHEDULED`](#member-gfruntimetaskgroup-constants-rejection_child_scheduled) | `const REJECTION_CHILD_SCHEDULED: StringName = &"group_child_scheduled"` |
| 常量 | [`REJECTION_PARALLEL_REQUIREMENT_CONFLICT`](#member-gfruntimetaskgroup-constants-rejection_parallel_requirement_conflict) | `const REJECTION_PARALLEL_REQUIREMENT_CONFLICT: StringName = &"group_parallel_requirement_conflict"` |
| 属性 | [`cancel_remaining_on_finish`](#member-gfruntimetaskgroup-properties-cancel_remaining_on_finish) | `var cancel_remaining_on_finish: bool = true` |
| 方法 | [`_init`](#member-gfruntimetaskgroup-methods-_init) | `func _init(p_tasks: Array[GFRuntimeTask] = [], p_mode: Mode = Mode.SEQUENCE) -> void:` |
| 方法 | [`set_tasks`](#member-gfruntimetaskgroup-methods-set_tasks) | `func set_tasks(next_tasks: Array[GFRuntimeTask]) -> bool:` |
| 方法 | [`set_mode`](#member-gfruntimetaskgroup-methods-set_mode) | `func set_mode(next_mode: Mode) -> bool:` |
| 方法 | [`get_mode`](#member-gfruntimetaskgroup-methods-get_mode) | `func get_mode() -> Mode:` |
| 方法 | [`add_task`](#member-gfruntimetaskgroup-methods-add_task) | `func add_task(task: GFRuntimeTask) -> GFRuntimeTaskGroup:` |
| 方法 | [`remove_task`](#member-gfruntimetaskgroup-methods-remove_task) | `func remove_task(task: GFRuntimeTask) -> bool:` |
| 方法 | [`rebuild_requirements`](#member-gfruntimetaskgroup-methods-rebuild_requirements) | `func rebuild_requirements() -> void:` |
| 方法 | [`get_requirements`](#member-gfruntimetaskgroup-methods-get_requirements) | `func get_requirements() -> Array[Object]:` |
| 方法 | [`get_tasks`](#member-gfruntimetaskgroup-methods-get_tasks) | `func get_tasks() -> Array[GFRuntimeTask]:` |
| 方法 | [`initialize`](#member-gfruntimetaskgroup-methods-initialize) | `func initialize(scheduler: GFRuntimeTaskScheduler) -> void:` |
| 方法 | [`tick`](#member-gfruntimetaskgroup-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfruntimetaskgroup-methods-physics_tick) | `func physics_tick(delta: float) -> void:` |
| 方法 | [`is_finished`](#member-gfruntimetaskgroup-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`end`](#member-gfruntimetaskgroup-methods-end) | `func end(interrupted: bool) -> void:` |

## 枚举

<a id="member-gfruntimetaskgroup-enums-mode"></a>

### `Mode`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
enum Mode {
	## 按顺序执行，每次只推进一个子任务。
	SEQUENCE,
	## 同时推进所有子任务，全部完成后任务组完成。
	PARALLEL_ALL,
	## 同时推进所有子任务，任一完成后任务组完成。
	PARALLEL_RACE,
}
```

子任务推进模式。

## 常量

<a id="member-gfruntimetaskgroup-constants-rejection_child_scheduled"></a>

### `REJECTION_CHILD_SCHEDULED`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REJECTION_CHILD_SCHEDULED: StringName = &"group_child_scheduled"
```

子任务已被其他调度器或任务组持有时的拒绝原因。

<a id="member-gfruntimetaskgroup-constants-rejection_parallel_requirement_conflict"></a>

### `REJECTION_PARALLEL_REQUIREMENT_CONFLICT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const REJECTION_PARALLEL_REQUIREMENT_CONFLICT: StringName = &"group_parallel_requirement_conflict"
```

并行任务组存在组内 requirement 冲突时的拒绝原因。

## 属性

<a id="member-gfruntimetaskgroup-properties-cancel_remaining_on_finish"></a>

### `cancel_remaining_on_finish`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var cancel_remaining_on_finish: bool = true
```

[method get_mode] 为 [enum Mode.PARALLEL_RACE] 时，首个子任务完成后是否中断其他子任务。

## 方法

<a id="member-gfruntimetaskgroup-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func _init(p_tasks: Array[GFRuntimeTask] = [], p_mode: Mode = Mode.SEQUENCE) -> void:
```

创建运行时任务组。

参数：

| 名称 | 说明 |
|---|---|
| `p_tasks` | 初始子任务列表。 |
| `p_mode` | 子任务推进模式。 |

<a id="member-gfruntimetaskgroup-methods-set_tasks"></a>

### `set_tasks`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_tasks(next_tasks: Array[GFRuntimeTask]) -> bool:
```

原子替换子任务列表，并重建任务组 requirement。

参数：

| 名称 | 说明 |
|---|---|
| `next_tasks` | 新的子任务列表；不接受空值、重复实例或已调度任务。 |

返回：全部校验通过并完成替换时返回 true。

<a id="member-gfruntimetaskgroup-methods-set_mode"></a>

### `set_mode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_mode(next_mode: Mode) -> bool:
```

设置子任务推进模式。

参数：

| 名称 | 说明 |
|---|---|
| `next_mode` | 新的推进模式。 |

返回：模式有效、任务组未锁定且现有子任务满足新模式约束时返回 true。

<a id="member-gfruntimetaskgroup-methods-get_mode"></a>

### `get_mode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_mode() -> Mode:
```

返回子任务推进模式。

返回：当前推进模式。

<a id="member-gfruntimetaskgroup-methods-add_task"></a>

### `add_task`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_task(task: GFRuntimeTask) -> GFRuntimeTaskGroup:
```

添加子任务，并把子任务 requirement 合并到任务组。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 要添加的子任务。 |

返回：当前任务组。

<a id="member-gfruntimetaskgroup-methods-remove_task"></a>

### `remove_task`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func remove_task(task: GFRuntimeTask) -> bool:
```

移除子任务并重建任务组 requirement。

参数：

| 名称 | 说明 |
|---|---|
| `task` | 要移除的子任务。 |

返回：成功移除时返回 true。

<a id="member-gfruntimetaskgroup-methods-rebuild_requirements"></a>

### `rebuild_requirements`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func rebuild_requirements() -> void:
```

重建任务组 requirement 聚合。

<a id="member-gfruntimetaskgroup-methods-get_requirements"></a>

### `get_requirements`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_requirements() -> Array[Object]:
```

返回当前子任务聚合后的占用对象副本。

返回：仍然有效的占用对象副本。

<a id="member-gfruntimetaskgroup-methods-get_tasks"></a>

### `get_tasks`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_tasks() -> Array[GFRuntimeTask]:
```

返回子任务副本。

返回：子任务副本。

<a id="member-gfruntimetaskgroup-methods-initialize"></a>

### `initialize`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
```

初始化任务组。

参数：

| 名称 | 说明 |
|---|---|
| `scheduler` | 当前调度器。 |

<a id="member-gfruntimetaskgroup-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func tick(delta: float) -> void:
```

按帧推进任务组。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 帧间隔秒数。 |

<a id="member-gfruntimetaskgroup-methods-physics_tick"></a>

### `physics_tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func physics_tick(delta: float) -> void:
```

按物理帧推进任务组。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 物理帧间隔秒数。 |

<a id="member-gfruntimetaskgroup-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_finished() -> bool:
```

判断任务组是否已经完成。

返回：任务组已完成时返回 true。

<a id="member-gfruntimetaskgroup-methods-end"></a>

### `end`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func end(interrupted: bool) -> void:
```

结束任务组。

参数：

| 名称 | 说明 |
|---|---|
| `interrupted` | 为 true 时表示任务组被其他任务或调度器取消。 |
