# GFVisualAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_visual_action.gd`
- 模块：`Action Queue`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

视觉表现动作的抽象基类。 继承自 RefCounted，代表一个具体的、可 await 的表现动作单元， 如移动动画、卡牌翻面、粒子爆炸等。 通过将每个视觉动作封装为独立对象，GFActionQueueSystem 可以严格按序 或并行地消费它们，从而彻底隔离底层逻辑时序与 UI 表现时序。 子类必须重写 execute() 以实现具体的视觉逻辑： - 若动作是瞬时的（无需等待），直接执行并返回 null。 - 若动作需要等待（如 Tween/动画），返回一个 Signal， 外部可 await 此 Signal 以知悉动作结束。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`CompletionMode`](#member-gfvisualaction-enums-completionmode) | `enum CompletionMode` |
| 属性 | [`completion_mode`](#member-gfvisualaction-properties-completion_mode) | `var completion_mode: CompletionMode = CompletionMode.AUTO` |
| 属性 | [`signal_timeout_seconds`](#member-gfvisualaction-properties-signal_timeout_seconds) | `var signal_timeout_seconds: float:` |
| 属性 | [`signal_timeout_respects_time_scale`](#member-gfvisualaction-properties-signal_timeout_respects_time_scale) | `var signal_timeout_respects_time_scale: bool = true` |
| 方法 | [`execute`](#member-gfvisualaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`is_valid`](#member-gfvisualaction-methods-is_valid) | `func is_valid() -> bool:` |
| 方法 | [`can_execute`](#member-gfvisualaction-methods-can_execute) | `func can_execute() -> bool:` |
| 方法 | [`as_fire_and_forget`](#member-gfvisualaction-methods-as_fire_and_forget) | `func as_fire_and_forget() -> GFVisualAction:` |
| 方法 | [`as_wait_for_signal`](#member-gfvisualaction-methods-as_wait_for_signal) | `func as_wait_for_signal() -> GFVisualAction:` |
| 方法 | [`cancel`](#member-gfvisualaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfvisualaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfvisualaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfvisualaction-methods-finish) | `func finish() -> void:` |
| 方法 | [`get_wait_guard_node`](#member-gfvisualaction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |
| 方法 | [`with_signal_timeout`](#member-gfvisualaction-methods-with_signal_timeout) | `func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFVisualAction:` |
| 方法 | [`should_wait_for_result`](#member-gfvisualaction-methods-should_wait_for_result) | `func should_wait_for_result(result: Variant) -> bool:` |
| 方法 | [`await_result_safely`](#member-gfvisualaction-methods-await_result_safely) | `func await_result_safely(result: Variant, should_continue: Callable = Callable()) -> void:` |

## 枚举

<a id="member-gfvisualaction-enums-completionmode"></a>

### `CompletionMode`

- API：`public`

```gdscript
enum CompletionMode {
	## 自动模式：返回 Signal 时等待，否则视为立即完成。
	AUTO,
	## 显式等待：语义上声明本动作需要等待返回的 Signal。
	WAIT_FOR_SIGNAL,
	## 发出即走：即使 execute() 返回 Signal，队列也不会等待。
	FIRE_AND_FORGET,
}
```

队列如何处理 execute() 的返回值。

## 属性

<a id="member-gfvisualaction-properties-completion_mode"></a>

### `completion_mode`

- API：`public`

```gdscript
var completion_mode: CompletionMode = CompletionMode.AUTO
```

动作完成模式。默认自动等待 Signal，返回 null 则继续。

<a id="member-gfvisualaction-properties-signal_timeout_seconds"></a>

### `signal_timeout_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var signal_timeout_seconds: float:
```

等待 Signal 的超时时间（秒）。小于等于 0 时表示不启用超时。

<a id="member-gfvisualaction-properties-signal_timeout_respects_time_scale"></a>

### `signal_timeout_respects_time_scale`

- API：`public`

```gdscript
var signal_timeout_respects_time_scale: bool = true
```

Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。

## 方法

<a id="member-gfvisualaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行此视觉动作。子类必须重写此方法。

返回：瞬时动作返回 null；需要等待的动作返回一个 Signal 供 await。

结构：

- `return`: Variant，瞬时动作返回 null；需要等待的动作返回 Signal。

<a id="member-gfvisualaction-methods-is_valid"></a>

### `is_valid`

- API：`public`

```gdscript
func is_valid() -> bool:
```

判断动作在入队消费时是否仍然有效。 子类可根据目标节点、战斗目标或运行时状态决定是否跳过。

返回：有效返回 true。

<a id="member-gfvisualaction-methods-can_execute"></a>

### `can_execute`

- API：`public`

```gdscript
func can_execute() -> bool:
```

判断动作是否可以执行。默认委托 is_valid()，便于子类覆盖更明确的语义。

返回：可以执行返回 true。

<a id="member-gfvisualaction-methods-as_fire_and_forget"></a>

### `as_fire_and_forget`

- API：`public`

```gdscript
func as_fire_and_forget() -> GFVisualAction:
```

将动作标记为显式 fire-and-forget，并返回自身以便链式调用。

返回：当前动作实例。

<a id="member-gfvisualaction-methods-as_wait_for_signal"></a>

### `as_wait_for_signal`

- API：`public`

```gdscript
func as_wait_for_signal() -> GFVisualAction:
```

将动作标记为显式等待 Signal，并返回自身以便链式调用。

返回：当前动作实例。

<a id="member-gfvisualaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

请求取消动作。基础实现不做处理；持有 Tween、Timer、信号连接或外部任务的自定义动作应重写。

<a id="member-gfvisualaction-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

请求暂停动作。基础实现不做处理；可暂停动作应重写。

<a id="member-gfvisualaction-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

请求恢复动作。基础实现不做处理；可暂停动作应重写。

<a id="member-gfvisualaction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

请求立即完成动作。基础实现委托 cancel()；需要区分取消和完成的动作应重写。

<a id="member-gfvisualaction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`

```gdscript
func get_wait_guard_node() -> Node:
```

返回用于保护 Signal 等待生命周期的节点。 Tween 等非 Node 信号可通过该节点的 tree_exited 提前结束等待。

返回：等待保护节点；没有时返回 null。

<a id="member-gfvisualaction-methods-with_signal_timeout"></a>

### `with_signal_timeout`

- API：`public`

```gdscript
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFVisualAction:
```

设置等待 Signal 的超时时间，并返回自身以便链式调用。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时时间；小于等于 0 时表示不启用超时。 |
| `respect_time_scale` | 是否跟随 GFTimeUtility 的暂停与 time_scale。 |

返回：当前动作实例。

<a id="member-gfvisualaction-methods-should_wait_for_result"></a>

### `should_wait_for_result`

- API：`public`

```gdscript
func should_wait_for_result(result: Variant) -> bool:
```

根据当前完成模式判断队列是否应该等待 execute() 的返回值。

参数：

| 名称 | 说明 |
|---|---|
| `result` | execute() 返回值。 |

返回：应等待返回 true。

结构：

- `result`: Variant，由 execute() 返回，通常为 Signal 或 null。

<a id="member-gfvisualaction-methods-await_result_safely"></a>

### `await_result_safely`

- API：`public`

```gdscript
func await_result_safely(result: Variant, should_continue: Callable = Callable()) -> void:
```

安全等待 execute() 返回的 Signal。 当发射源失效或 Node 提前退出树时，会自动结束等待，避免队列永久卡死。

参数：

| 名称 | 说明 |
|---|---|
| `result` | execute() 返回值。 |
| `should_continue` | 可选取消检查回调；返回 false 时立即停止等待。 |

结构：

- `result`: Variant，由 execute() 返回，等待时必须是 Signal。
