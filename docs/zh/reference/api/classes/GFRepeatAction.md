# GFRepeatAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_repeat_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

按工厂重复创建并执行队列动作。 每轮通过 action_factory 创建一个新的动作对象，避免复用同一个动作实例时 残留 Tween、Timer 或节点引用状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`repeat_completed`](#member-gfrepeataction-signals-repeat_completed) | `signal repeat_completed` |
| 常量 | [`DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME`](#member-gfrepeataction-constants-default_max_immediate_iterations_per_frame) | `const DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME: int = 256` |
| 属性 | [`action_factory`](#member-gfrepeataction-properties-action_factory) | `var action_factory: Callable` |
| 属性 | [`repeat_count`](#member-gfrepeataction-properties-repeat_count) | `var repeat_count: int = 1` |
| 属性 | [`max_immediate_iterations_per_frame`](#member-gfrepeataction-properties-max_immediate_iterations_per_frame) | `var max_immediate_iterations_per_frame: int = DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME` |
| 方法 | [`execute`](#member-gfrepeataction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfrepeataction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfrepeataction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfrepeataction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfrepeataction-methods-finish) | `func finish() -> void:` |

## 信号

<a id="member-gfrepeataction-signals-repeat_completed"></a>

### `repeat_completed`

- API：`public`

```gdscript
signal repeat_completed
```

重复流程结束时发出。

## 常量

<a id="member-gfrepeataction-constants-default_max_immediate_iterations_per_frame"></a>

### `DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME`

- API：`public`

```gdscript
const DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME: int = 256
```

单帧最多连续执行的瞬时重复次数，避免无限重复的瞬时动作锁住主线程。

## 属性

<a id="member-gfrepeataction-properties-action_factory"></a>

### `action_factory`

- API：`public`

```gdscript
var action_factory: Callable
```

动作工厂。每次调用应返回一个动作对象；返回 null 会结束重复。

<a id="member-gfrepeataction-properties-repeat_count"></a>

### `repeat_count`

- API：`public`

```gdscript
var repeat_count: int = 1
```

重复次数。0 表示无限重复，直到 cancel()、finish() 或工厂返回 null。

<a id="member-gfrepeataction-properties-max_immediate_iterations_per_frame"></a>

### `max_immediate_iterations_per_frame`

- API：`public`

```gdscript
var max_immediate_iterations_per_frame: int = DEFAULT_MAX_IMMEDIATE_ITERATIONS_PER_FRAME
```

单帧最多连续执行的瞬时重复次数。小于 1 时按 1 处理。

## 方法

<a id="member-gfrepeataction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

启动重复执行流程。

返回：action_factory 有效时返回 repeat_completed Signal；无效时返回 null。

结构：

- `return`: Variant，返回 repeat_completed Signal 或 null。

<a id="member-gfrepeataction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消重复流程并取消当前动作。

<a id="member-gfrepeataction-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停重复流程和当前动作。

<a id="member-gfrepeataction-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复重复流程和当前动作。

<a id="member-gfrepeataction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即完成重复流程并释放等待者。
