# GFTimerUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_timer_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

纯代码驱动的全局定时器工具。 通过框架 `tick()` 驱动延时回调，不依赖场景树中的 `Timer` 节点， 因而可直接受到 `GFTimeUtility` 的时间缩放与暂停控制。适用于在 `GFSystem`、`GFModel` 或其他纯逻辑模块中调度一次性、重复或 owner 绑定任务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`init`](#member-gftimerutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gftimerutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gftimerutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`execute_after`](#member-gftimerutility-methods-execute_after) | `func execute_after(delay: float, callback: Callable) -> int:` |
| 方法 | [`execute_after_owned`](#member-gftimerutility-methods-execute_after_owned) | `func execute_after_owned(owner: Object, delay: float, callback: Callable) -> int:` |
| 方法 | [`execute_repeating`](#member-gftimerutility-methods-execute_repeating) | `func execute_repeating( interval: float, callback: Callable, repeat_count: int = -1, initial_delay: float = -1.0 ) -> int:` |
| 方法 | [`execute_repeating_owned`](#member-gftimerutility-methods-execute_repeating_owned) | `func execute_repeating_owned( owner: Object, interval: float, callback: Callable, repeat_count: int = -1, initial_delay: float = -1.0 ) -> int:` |
| 方法 | [`cancel`](#member-gftimerutility-methods-cancel) | `func cancel(handle: int) -> bool:` |
| 方法 | [`cancel_owner`](#member-gftimerutility-methods-cancel_owner) | `func cancel_owner(owner: Object) -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gftimerutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gftimerutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化定时器队列。

<a id="member-gftimerutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

清空定时器队列。

<a id="member-gftimerutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

<a id="member-gftimerutility-methods-execute_after"></a>

### `execute_after`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func execute_after(delay: float, callback: Callable) -> int:
```

在指定延迟后执行一次回调函数。 基于框架 `tick()` 推进计时，因此会自动遵循 `GFTimeUtility` 的暂停与缩放结果。

参数：

| 名称 | 说明 |
|---|---|
| `delay` | 有限延迟时长，单位为秒。 |
| `callback` | 延迟结束后执行的无参回调函数。 |

返回：已排队定时器的句柄；无效回调或立即执行时返回 `0`。

<a id="member-gftimerutility-methods-execute_after_owned"></a>

### `execute_after_owned`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func execute_after_owned(owner: Object, delay: float, callback: Callable) -> int:
```

在指定延迟后执行一次 owner 绑定回调。owner 释放后任务会自动丢弃。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 定时器拥有者。 |
| `delay` | 有限延迟时长，单位为秒。 |
| `callback` | 延迟结束后执行的无参回调函数。 |

返回：已排队定时器的句柄；无效输入或立即执行时返回 `0`。

<a id="member-gftimerutility-methods-execute_repeating"></a>

### `execute_repeating`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func execute_repeating( interval: float, callback: Callable, repeat_count: int = -1, initial_delay: float = -1.0 ) -> int:
```

按固定间隔重复执行回调。

参数：

| 名称 | 说明 |
|---|---|
| `interval` | 有限且大于 0 的重复间隔，单位为秒。 |
| `callback` | 每次触发时执行的无参回调函数。 |
| `repeat_count` | 触发次数；小于 0 表示无限重复。 |
| `initial_delay` | 有限的首次触发延迟；小于 0 时使用 interval。 |

返回：已排队定时器的句柄；无效输入时返回 `0`。

<a id="member-gftimerutility-methods-execute_repeating_owned"></a>

### `execute_repeating_owned`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func execute_repeating_owned( owner: Object, interval: float, callback: Callable, repeat_count: int = -1, initial_delay: float = -1.0 ) -> int:
```

按固定间隔重复执行 owner 绑定回调。owner 释放后任务会自动丢弃。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 定时器拥有者。 |
| `interval` | 有限且大于 0 的重复间隔，单位为秒。 |
| `callback` | 每次触发时执行的无参回调函数。 |
| `repeat_count` | 触发次数；小于 0 表示无限重复。 |
| `initial_delay` | 有限的首次触发延迟；小于 0 时使用 interval。 |

返回：已排队定时器的句柄；无效输入时返回 `0`。

<a id="member-gftimerutility-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel(handle: int) -> bool:
```

取消一个尚未触发的延时任务。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | \`execute_after()\` 返回的定时器句柄。 |

返回：找到并取消任务时返回 `true`。

<a id="member-gftimerutility-methods-cancel_owner"></a>

### `cancel_owner`

- API：`public`

```gdscript
func cancel_owner(owner: Object) -> int:
```

取消指定 owner 绑定的全部待执行任务。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 定时器拥有者。 |

返回：被取消的任务数量。

<a id="member-gftimerutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取定时器工具诊断快照。

返回：诊断快照字典。

结构：

- `return`: Dictionary with `pending_count`, `pending_handles`, `owner_bound_count`, `executing_count`, and `next_timer_id`.
