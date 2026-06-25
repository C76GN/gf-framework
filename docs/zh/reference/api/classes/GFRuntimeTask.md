# GFRuntimeTask

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_runtime_task.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`6.0.0`

可被运行时调度器管理的通用任务协议。 Runtime task 用于描述“占用一组运行时对象并按帧推进”的行为单元，例如角色默认状态、 临时交互、工具模式或项目自定义流程。任务只声明依赖、生命周期和完成条件，不解释业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`task_id`](#member-gfruntimetask-properties-task_id) | `var task_id: StringName = &""` |
| 属性 | [`requirements`](#member-gfruntimetask-properties-requirements) | `var requirements: Array[Object] = []` |
| 属性 | [`interruptible`](#member-gfruntimetask-properties-interruptible) | `var interruptible: bool = true` |
| 方法 | [`_init`](#member-gfruntimetask-methods-_init) | `func _init(p_requirements: Array[Object] = [], p_interruptible: bool = true) -> void:` |
| 方法 | [`set_requirements`](#member-gfruntimetask-methods-set_requirements) | `func set_requirements(next_requirements: Array[Object]) -> GFRuntimeTask:` |
| 方法 | [`add_requirement`](#member-gfruntimetask-methods-add_requirement) | `func add_requirement(requirement: Object) -> GFRuntimeTask:` |
| 方法 | [`remove_requirement`](#member-gfruntimetask-methods-remove_requirement) | `func remove_requirement(requirement: Object) -> bool:` |
| 方法 | [`clear_requirements`](#member-gfruntimetask-methods-clear_requirements) | `func clear_requirements() -> void:` |
| 方法 | [`get_requirements`](#member-gfruntimetask-methods-get_requirements) | `func get_requirements() -> Array[Object]:` |
| 方法 | [`has_requirement`](#member-gfruntimetask-methods-has_requirement) | `func has_requirement(requirement: Object) -> bool:` |
| 方法 | [`set_interruptible`](#member-gfruntimetask-methods-set_interruptible) | `func set_interruptible(value: bool) -> GFRuntimeTask:` |
| 方法 | [`is_interruptible`](#member-gfruntimetask-methods-is_interruptible) | `func is_interruptible() -> bool:` |
| 方法 | [`is_scheduled`](#member-gfruntimetask-methods-is_scheduled) | `func is_scheduled() -> bool:` |
| 方法 | [`has_initialized`](#member-gfruntimetask-methods-has_initialized) | `func has_initialized() -> bool:` |
| 方法 | [`initialize`](#member-gfruntimetask-methods-initialize) | `func initialize(_scheduler: GFRuntimeTaskScheduler) -> void:` |
| 方法 | [`tick`](#member-gfruntimetask-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfruntimetask-methods-physics_tick) | `func physics_tick(_delta: float) -> void:` |
| 方法 | [`is_finished`](#member-gfruntimetask-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`end`](#member-gfruntimetask-methods-end) | `func end(_interrupted: bool) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimetask-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfruntimetask-properties-task_id"></a>

### `task_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var task_id: StringName = &""
```

调试和诊断用任务标识。

<a id="member-gfruntimetask-properties-requirements"></a>

### `requirements`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var requirements: Array[Object] = []
```

此任务占用的运行时对象。 相同 requirement 同一时间只能被一个任务占用。调度器会忽略已经释放的对象。

<a id="member-gfruntimetask-properties-interruptible"></a>

### `interruptible`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var interruptible: bool = true
```

当其他任务请求相同 requirement 时，当前任务是否允许被中断。

## 方法

<a id="member-gfruntimetask-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func _init(p_requirements: Array[Object] = [], p_interruptible: bool = true) -> void:
```

创建运行时任务。

参数：

| 名称 | 说明 |
|---|---|
| `p_requirements` | 初始占用对象列表。 |
| `p_interruptible` | 任务是否允许被其他任务中断。 |

<a id="member-gfruntimetask-methods-set_requirements"></a>

### `set_requirements`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_requirements(next_requirements: Array[Object]) -> GFRuntimeTask:
```

替换任务占用对象列表。

参数：

| 名称 | 说明 |
|---|---|
| `next_requirements` | 新的占用对象列表。 |

返回：当前任务。

<a id="member-gfruntimetask-methods-add_requirement"></a>

### `add_requirement`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_requirement(requirement: Object) -> GFRuntimeTask:
```

添加一个占用对象。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要添加的占用对象。 |

返回：当前任务。

<a id="member-gfruntimetask-methods-remove_requirement"></a>

### `remove_requirement`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func remove_requirement(requirement: Object) -> bool:
```

移除一个占用对象。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要移除的占用对象。 |

返回：成功移除时返回 true。

<a id="member-gfruntimetask-methods-clear_requirements"></a>

### `clear_requirements`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_requirements() -> void:
```

清空占用对象列表。

<a id="member-gfruntimetask-methods-get_requirements"></a>

### `get_requirements`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_requirements() -> Array[Object]:
```

返回仍然有效的占用对象副本。

返回：仍然有效的占用对象副本。

<a id="member-gfruntimetask-methods-has_requirement"></a>

### `has_requirement`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_requirement(requirement: Object) -> bool:
```

判断任务是否占用指定对象。

参数：

| 名称 | 说明 |
|---|---|
| `requirement` | 要检查的占用对象。 |

返回：任务占用该对象时返回 true。

<a id="member-gfruntimetask-methods-set_interruptible"></a>

### `set_interruptible`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_interruptible(value: bool) -> GFRuntimeTask:
```

设置任务是否可中断。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 是否允许被中断。 |

返回：当前任务。

<a id="member-gfruntimetask-methods-is_interruptible"></a>

### `is_interruptible`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_interruptible() -> bool:
```

判断任务是否可中断。

返回：任务允许被中断时返回 true。

<a id="member-gfruntimetask-methods-is_scheduled"></a>

### `is_scheduled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_scheduled() -> bool:
```

判断任务是否已经进入调度器。

返回：任务已经进入调度器时返回 true。

<a id="member-gfruntimetask-methods-has_initialized"></a>

### `has_initialized`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func has_initialized() -> bool:
```

判断任务本轮调度是否已经初始化。

返回：本轮调度已经完成初始化时返回 true。

<a id="member-gfruntimetask-methods-initialize"></a>

### `initialize`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func initialize(_scheduler: GFRuntimeTaskScheduler) -> void:
```

初始化任务。 调度器会在第一次推进任务前调用此方法。子类可在此读取架构、准备本轮状态或发出开始事件。

参数：

| 名称 | 说明 |
|---|---|
| `_scheduler` | 当前调度器。 |

<a id="member-gfruntimetask-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func tick(_delta: float) -> void:
```

按帧推进任务。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 帧间隔秒数。 |

<a id="member-gfruntimetask-methods-physics_tick"></a>

### `physics_tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func physics_tick(_delta: float) -> void:
```

按物理帧推进任务。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 物理帧间隔秒数。 |

<a id="member-gfruntimetask-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_finished() -> bool:
```

判断任务是否已经完成。 默认任务会在初始化后的第一次检查中完成。需要跨帧运行的任务应重写此方法。

返回：任务已完成时返回 true。

<a id="member-gfruntimetask-methods-end"></a>

### `end`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func end(_interrupted: bool) -> void:
```

结束任务。 [param interrupted] 为 [code]true[/code] 时表示任务被其他任务或调度器取消。

参数：

| 名称 | 说明 |
|---|---|
| `_interrupted` | 为 true 时表示任务被其他任务或调度器取消。 |

<a id="member-gfruntimetask-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

返回任务诊断快照。

返回：任务诊断快照。

结构：

- `return`: Dictionary with task_id, interruptible, scheduled, initialized, and requirement_ids.
