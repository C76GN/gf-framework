# GFWaitAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_wait_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

动作队列中的通用等待动作。 通过可暂停的帧循环表达一段时间等待，不携带业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`wait_completed`](#member-gfwaitaction-signals-wait_completed) | `signal wait_completed` |
| 属性 | [`seconds`](#member-gfwaitaction-properties-seconds) | `var seconds: float = 0.0` |
| 属性 | [`host_node`](#member-gfwaitaction-properties-host_node) | `var host_node: Node` |
| 属性 | [`process_always`](#member-gfwaitaction-properties-process_always) | `var process_always: bool = true` |
| 属性 | [`process_in_physics`](#member-gfwaitaction-properties-process_in_physics) | `var process_in_physics: bool = false` |
| 属性 | [`ignore_time_scale`](#member-gfwaitaction-properties-ignore_time_scale) | `var ignore_time_scale: bool = false` |
| 方法 | [`execute`](#member-gfwaitaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfwaitaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfwaitaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfwaitaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfwaitaction-methods-finish) | `func finish() -> void:` |

## 信号

<a id="member-gfwaitaction-signals-wait_completed"></a>

### `wait_completed`

- API：`public`

```gdscript
signal wait_completed
```

等待完成时发出。取消后的旧计时器不会触发该信号。

## 属性

<a id="member-gfwaitaction-properties-seconds"></a>

### `seconds`

- API：`public`

```gdscript
var seconds: float = 0.0
```

等待秒数。

<a id="member-gfwaitaction-properties-host_node"></a>

### `host_node`

- API：`public`

```gdscript
var host_node: Node
```

可选宿主节点。存在时优先从该节点获取 SceneTree。

<a id="member-gfwaitaction-properties-process_always"></a>

### `process_always`

- API：`public`

```gdscript
var process_always: bool = true
```

计时器是否在暂停时继续处理。

<a id="member-gfwaitaction-properties-process_in_physics"></a>

### `process_in_physics`

- API：`public`

```gdscript
var process_in_physics: bool = false
```

是否按物理帧处理。

<a id="member-gfwaitaction-properties-ignore_time_scale"></a>

### `ignore_time_scale`

- API：`public`

```gdscript
var ignore_time_scale: bool = false
```

是否忽略 Engine.time_scale。

## 方法

<a id="member-gfwaitaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

启动等待计时器。

返回：需要等待时返回 wait_completed Signal；无需等待或无法获取 SceneTree 时返回 null。

结构：

- `return`: Variant，返回 wait_completed Signal 或 null。

<a id="member-gfwaitaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消当前等待。

<a id="member-gfwaitaction-methods-pause"></a>

### `pause`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func pause() -> void:
```

暂停当前等待。

<a id="member-gfwaitaction-methods-resume"></a>

### `resume`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func resume() -> void:
```

恢复当前等待。

<a id="member-gfwaitaction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即完成当前等待并发出 wait_completed。
