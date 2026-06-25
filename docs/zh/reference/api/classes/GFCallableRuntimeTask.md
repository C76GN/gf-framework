# GFCallableRuntimeTask

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/sequence/gf_callable_runtime_task.gd`
- 模块：`Standard`
- 继承：`GFRuntimeTask`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`6.0.0`

使用 Callable 描述生命周期的运行时任务。 适合把轻量项目逻辑注入 [GFRuntimeTaskScheduler]，而不必为一次性任务创建脚本类。 所有回调都接收当前任务和调度器，便于在闭包之外保持可测试的上下文。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`initialize_callable`](#member-gfcallableruntimetask-properties-initialize_callable) | `var initialize_callable: Callable = Callable()` |
| 属性 | [`tick_callable`](#member-gfcallableruntimetask-properties-tick_callable) | `var tick_callable: Callable = Callable()` |
| 属性 | [`physics_tick_callable`](#member-gfcallableruntimetask-properties-physics_tick_callable) | `var physics_tick_callable: Callable = Callable()` |
| 属性 | [`finished_callable`](#member-gfcallableruntimetask-properties-finished_callable) | `var finished_callable: Callable = Callable()` |
| 属性 | [`end_callable`](#member-gfcallableruntimetask-properties-end_callable) | `var end_callable: Callable = Callable()` |
| 属性 | [`finish_after_initialize`](#member-gfcallableruntimetask-properties-finish_after_initialize) | `var finish_after_initialize: bool = true` |
| 方法 | [`_init`](#member-gfcallableruntimetask-methods-_init) | `func _init( p_initialize_callable: Callable = Callable(), p_tick_callable: Callable = Callable(), p_finished_callable: Callable = Callable(), p_end_callable: Callable = Callable(), p_requirements: Array[Object] = [], p_interruptible: bool = true ) -> void:` |
| 方法 | [`with_physics_tick`](#member-gfcallableruntimetask-methods-with_physics_tick) | `func with_physics_tick(p_physics_tick_callable: Callable) -> GFCallableRuntimeTask:` |
| 方法 | [`initialize`](#member-gfcallableruntimetask-methods-initialize) | `func initialize(scheduler: GFRuntimeTaskScheduler) -> void:` |
| 方法 | [`tick`](#member-gfcallableruntimetask-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`physics_tick`](#member-gfcallableruntimetask-methods-physics_tick) | `func physics_tick(delta: float) -> void:` |
| 方法 | [`is_finished`](#member-gfcallableruntimetask-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`end`](#member-gfcallableruntimetask-methods-end) | `func end(interrupted: bool) -> void:` |

## 属性

<a id="member-gfcallableruntimetask-properties-initialize_callable"></a>

### `initialize_callable`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var initialize_callable: Callable = Callable()
```

初始化回调，签名为 [code]func(task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。

<a id="member-gfcallableruntimetask-properties-tick_callable"></a>

### `tick_callable`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var tick_callable: Callable = Callable()
```

帧推进回调，签名为 [code]func(delta: float, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。

<a id="member-gfcallableruntimetask-properties-physics_tick_callable"></a>

### `physics_tick_callable`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var physics_tick_callable: Callable = Callable()
```

物理帧推进回调，签名为 [code]func(delta: float, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。

<a id="member-gfcallableruntimetask-properties-finished_callable"></a>

### `finished_callable`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var finished_callable: Callable = Callable()
```

完成判断回调，签名为 [code]func(task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> bool[/code]。

<a id="member-gfcallableruntimetask-properties-end_callable"></a>

### `end_callable`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var end_callable: Callable = Callable()
```

结束回调，签名为 [code]func(interrupted: bool, task: GFCallableRuntimeTask, scheduler: GFRuntimeTaskScheduler) -> void[/code]。

<a id="member-gfcallableruntimetask-properties-finish_after_initialize"></a>

### `finish_after_initialize`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var finish_after_initialize: bool = true
```

是否在初始化后立即完成。 设为 [code]false[/code] 时，任务会持续运行直到 [member finished_callable] 返回 [code]true[/code]。

## 方法

<a id="member-gfcallableruntimetask-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func _init( p_initialize_callable: Callable = Callable(), p_tick_callable: Callable = Callable(), p_finished_callable: Callable = Callable(), p_end_callable: Callable = Callable(), p_requirements: Array[Object] = [], p_interruptible: bool = true ) -> void:
```

创建 Callable 运行时任务。

参数：

| 名称 | 说明 |
|---|---|
| `p_initialize_callable` | 初始化回调。 |
| `p_tick_callable` | 帧推进回调。 |
| `p_finished_callable` | 完成判断回调。 |
| `p_end_callable` | 结束回调。 |
| `p_requirements` | 初始占用对象列表。 |
| `p_interruptible` | 任务是否允许被其他任务中断。 |

<a id="member-gfcallableruntimetask-methods-with_physics_tick"></a>

### `with_physics_tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func with_physics_tick(p_physics_tick_callable: Callable) -> GFCallableRuntimeTask:
```

设置物理帧推进回调。

参数：

| 名称 | 说明 |
|---|---|
| `p_physics_tick_callable` | 物理帧推进回调。 |

返回：当前 Callable 任务。

<a id="member-gfcallableruntimetask-methods-initialize"></a>

### `initialize`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func initialize(scheduler: GFRuntimeTaskScheduler) -> void:
```

初始化任务。

参数：

| 名称 | 说明 |
|---|---|
| `scheduler` | 当前调度器。 |

<a id="member-gfcallableruntimetask-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func tick(delta: float) -> void:
```

按帧推进任务。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 帧间隔秒数。 |

<a id="member-gfcallableruntimetask-methods-physics_tick"></a>

### `physics_tick`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func physics_tick(delta: float) -> void:
```

按物理帧推进任务。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 物理帧间隔秒数。 |

<a id="member-gfcallableruntimetask-methods-is_finished"></a>

### `is_finished`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func is_finished() -> bool:
```

判断任务是否已经完成。

返回：任务已完成时返回 true。

<a id="member-gfcallableruntimetask-methods-end"></a>

### `end`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func end(interrupted: bool) -> void:
```

结束任务。

参数：

| 名称 | 说明 |
|---|---|
| `interrupted` | 为 true 时表示任务被其他任务或调度器取消。 |
