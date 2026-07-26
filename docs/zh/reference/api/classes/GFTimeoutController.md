# GFTimeoutController

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_timeout_controller.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

可复用的超时取消控制器。 将“超时”建模为取消 token 的一种原因，并提供 start / reset / stop 的可复用生命周期。 它只负责产生超时信号和 token，不执行重试、回滚或业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`timed_out`](#member-gftimeoutcontroller-signals-timed_out) | `signal timed_out(reason: StringName, metadata: Dictionary)` |
| 常量 | [`DEFAULT_TIMEOUT_REASON`](#member-gftimeoutcontroller-constants-default_timeout_reason) | `const DEFAULT_TIMEOUT_REASON: StringName = &"timeout"` |
| 属性 | [`process_always`](#member-gftimeoutcontroller-properties-process_always) | `var process_always: bool = true` |
| 属性 | [`process_in_physics`](#member-gftimeoutcontroller-properties-process_in_physics) | `var process_in_physics: bool = false` |
| 属性 | [`ignore_time_scale`](#member-gftimeoutcontroller-properties-ignore_time_scale) | `var ignore_time_scale: bool = false` |
| 方法 | [`_init`](#member-gftimeoutcontroller-methods-_init) | `func _init(clock: GFClock = null) -> void:` |
| 方法 | [`get_token`](#member-gftimeoutcontroller-methods-get_token) | `func get_token() -> GFCancellationToken:` |
| 方法 | [`set_clock`](#member-gftimeoutcontroller-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gftimeoutcontroller-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`start_seconds`](#member-gftimeoutcontroller-methods-start_seconds) | `func start_seconds( seconds: float, tree: SceneTree = null, reason: StringName = DEFAULT_TIMEOUT_REASON, metadata: Dictionary = {} ) -> GFCancellationToken:` |
| 方法 | [`stop`](#member-gftimeoutcontroller-methods-stop) | `func stop() -> void:` |
| 方法 | [`reset`](#member-gftimeoutcontroller-methods-reset) | `func reset() -> GFCancellationToken:` |
| 方法 | [`cancel`](#member-gftimeoutcontroller-methods-cancel) | `func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`is_cancelled`](#member-gftimeoutcontroller-methods-is_cancelled) | `func is_cancelled() -> bool:` |
| 方法 | [`is_active`](#member-gftimeoutcontroller-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`is_timeout`](#member-gftimeoutcontroller-methods-is_timeout) | `func is_timeout() -> bool:` |
| 方法 | [`get_elapsed_msec`](#member-gftimeoutcontroller-methods-get_elapsed_msec) | `func get_elapsed_msec() -> int:` |
| 方法 | [`dispose`](#member-gftimeoutcontroller-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gftimeoutcontroller-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gftimeoutcontroller-signals-timed_out"></a>

### `timed_out`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal timed_out(reason: StringName, metadata: Dictionary)
```

当前超时计划触发时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 超时取消原因。 |
| `metadata` | 超时上下文。 |

结构：

- `metadata`: Dictionary，包含调用方传入的超时上下文。

## 常量

<a id="member-gftimeoutcontroller-constants-default_timeout_reason"></a>

### `DEFAULT_TIMEOUT_REASON`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_TIMEOUT_REASON: StringName = &"timeout"
```

默认超时原因。

## 属性

<a id="member-gftimeoutcontroller-properties-process_always"></a>

### `process_always`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var process_always: bool = true
```

是否在暂停时继续计时。

<a id="member-gftimeoutcontroller-properties-process_in_physics"></a>

### `process_in_physics`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var process_in_physics: bool = false
```

是否在物理帧中处理超时计时器。

<a id="member-gftimeoutcontroller-properties-ignore_time_scale"></a>

### `ignore_time_scale`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var ignore_time_scale: bool = false
```

是否忽略 Engine.time_scale。

## 方法

<a id="member-gftimeoutcontroller-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func _init(clock: GFClock = null) -> void:
```

创建超时控制器。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 可选单调时钟；为空时使用系统时钟。 |

<a id="member-gftimeoutcontroller-methods-get_token"></a>

### `get_token`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_token() -> GFCancellationToken:
```

获取当前取消 token。

返回：当前超时控制器持有的 token。

<a id="member-gftimeoutcontroller-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

替换耗时统计使用的单调时钟。 活动超时计划期间禁止替换，避免同一次统计跨越不同时间域。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新单调时钟。 |

返回：时钟合法且当前无活动计划时返回 true。

<a id="member-gftimeoutcontroller-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取耗时统计使用的时钟。

返回：当前时钟。

<a id="member-gftimeoutcontroller-methods-start_seconds"></a>

### `start_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func start_seconds( seconds: float, tree: SceneTree = null, reason: StringName = DEFAULT_TIMEOUT_REASON, metadata: Dictionary = {} ) -> GFCancellationToken:
```

启动一个新的超时计划。 每次调用都会终结旧 source 并创建新的 token；旧 token 保持当时的取消状态。

参数：

| 名称 | 说明 |
|---|---|
| `seconds` | 超时时间；小于等于 0 时立即超时。 |
| `tree` | 可选 SceneTree；为空时使用当前主循环。 |
| `reason` | 超时取消原因；为空时使用 timeout。 |
| `metadata` | 超时上下文。 |

返回：当前计划使用的 token。

结构：

- `metadata`: Dictionary，包含调用方定义的超时上下文。

<a id="member-gftimeoutcontroller-methods-stop"></a>

### `stop`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func stop() -> void:
```

停止当前超时计划，不取消旧 token，并把控制器推进到新的空闲 token。

<a id="member-gftimeoutcontroller-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func reset() -> GFCancellationToken:
```

重置为一个未取消 token，并清除超时状态。

返回：重置后的 token。

<a id="member-gftimeoutcontroller-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
```

主动取消当前 token。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 取消上下文。 |

返回：首次取消时返回 true。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gftimeoutcontroller-methods-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_cancelled() -> bool:
```

判断当前 token 是否已取消。

返回：已取消时返回 true。

<a id="member-gftimeoutcontroller-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_active() -> bool:
```

判断当前是否存在待触发的超时计划。

返回：存在活动超时计划时返回 true。

<a id="member-gftimeoutcontroller-methods-is_timeout"></a>

### `is_timeout`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_timeout() -> bool:
```

判断最近一次取消是否来自超时计划。

返回：最近一次取消由超时触发时返回 true。

<a id="member-gftimeoutcontroller-methods-get_elapsed_msec"></a>

### `get_elapsed_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_elapsed_msec() -> int:
```

获取当前超时计划已运行毫秒数。

返回：从 start_seconds 开始经过的毫秒数；未启动时为 0。

<a id="member-gftimeoutcontroller-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func dispose() -> void:
```

释放当前计划和连接。

<a id="member-gftimeoutcontroller-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取超时控制器调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 active、timed_out、timeout_seconds、elapsed_msec、reason、metadata 和 token。
