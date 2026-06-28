# GFManualTimerQueue

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/time/gf_manual_timer_queue.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

手动 tick 驱动的确定性计时队列。 用整数 tick 调度一次性回调，适合回放、模拟、服务器步进、测试或编辑器批处理。 队列不读取引擎时间，也不创建 Timer 节点；调用方显式调用 advance_to() 或 advance_by() 推进时间。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_callbacks_per_advance`](#member-gfmanualtimerqueue-properties-max_callbacks_per_advance) | `var max_callbacks_per_advance: int = 1024:` |
| 方法 | [`schedule_at`](#member-gfmanualtimerqueue-methods-schedule_at) | `func schedule_at(target_tick: int, callback: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`schedule_after`](#member-gfmanualtimerqueue-methods-schedule_after) | `func schedule_after(delay_ticks: int, callback: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`schedule_at_owned`](#member-gfmanualtimerqueue-methods-schedule_at_owned) | `func schedule_at_owned(owner: Object, target_tick: int, callback: Callable, options: Dictionary = {}) -> int:` |
| 方法 | [`advance_to`](#member-gfmanualtimerqueue-methods-advance_to) | `func advance_to(target_tick: int, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`advance_by`](#member-gfmanualtimerqueue-methods-advance_by) | `func advance_by(delta_ticks: int, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`cancel`](#member-gfmanualtimerqueue-methods-cancel) | `func cancel(handle: int) -> bool:` |
| 方法 | [`cancel_owner`](#member-gfmanualtimerqueue-methods-cancel_owner) | `func cancel_owner(owner: Object) -> int:` |
| 方法 | [`clear`](#member-gfmanualtimerqueue-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_current_tick`](#member-gfmanualtimerqueue-methods-get_current_tick) | `func get_current_tick() -> int:` |
| 方法 | [`get_pending_count`](#member-gfmanualtimerqueue-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfmanualtimerqueue-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfmanualtimerqueue-properties-max_callbacks_per_advance"></a>

### `max_callbacks_per_advance`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_callbacks_per_advance: int = 1024:
```

单次 advance 最多执行多少个回调，避免同 tick 回调递归排队导致无限循环。

## 方法

<a id="member-gfmanualtimerqueue-methods-schedule_at"></a>

### `schedule_at`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func schedule_at(target_tick: int, callback: Callable, options: Dictionary = {}) -> int:
```

在绝对 tick 上调度回调。

参数：

| 名称 | 说明 |
|---|---|
| `target_tick` | 目标 tick；小于当前 tick 时会归一到当前 tick。 |
| `callback` | 到期后执行的回调。 |
| `options` | 调度选项，支持 owner、metadata、label 和 front。 |

返回：计时器句柄；callback 无效时返回 0。

结构：

- `options`: Dictionary，可包含 owner: Object、metadata: Dictionary、label: String、front: bool。

<a id="member-gfmanualtimerqueue-methods-schedule_after"></a>

### `schedule_after`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func schedule_after(delay_ticks: int, callback: Callable, options: Dictionary = {}) -> int:
```

在当前 tick 之后延迟若干 tick 调度回调。

参数：

| 名称 | 说明 |
|---|---|
| `delay_ticks` | 延迟 tick 数；小于 0 时按 0 处理。 |
| `callback` | 到期后执行的回调。 |
| `options` | 调度选项，支持 owner、metadata、label 和 front。 |

返回：计时器句柄；callback 无效时返回 0。

结构：

- `options`: Dictionary，可包含 owner: Object、metadata: Dictionary、label: String、front: bool。

<a id="member-gfmanualtimerqueue-methods-schedule_at_owned"></a>

### `schedule_at_owned`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func schedule_at_owned(owner: Object, target_tick: int, callback: Callable, options: Dictionary = {}) -> int:
```

在绝对 tick 上调度 owner 绑定回调。owner 释放后回调会被跳过。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 计时器拥有者。 |
| `target_tick` | 目标 tick；小于当前 tick 时会归一到当前 tick。 |
| `callback` | 到期后执行的回调。 |
| `options` | 调度选项，支持 metadata、label 和 front。 |

返回：计时器句柄；参数无效时返回 0。

结构：

- `options`: Dictionary，可包含 metadata: Dictionary、label: String、front: bool。

<a id="member-gfmanualtimerqueue-methods-advance_to"></a>

### `advance_to`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func advance_to(target_tick: int, options: Dictionary = {}) -> Dictionary:
```

推进到指定绝对 tick，并执行所有到期回调。

参数：

| 名称 | 说明 |
|---|---|
| `target_tick` | 目标 tick，不能小于当前 tick。 |
| `options` | 推进选项，支持 max_callbacks。 |

返回：推进报告。

结构：

- `options`: Dictionary，可包含 max_callbacks: int。
- `return`: Dictionary，包含 ok、status、from_tick、target_tick、current_tick、executed_count、failed_count、skipped_owner_count、truncated 和 pending_count。

<a id="member-gfmanualtimerqueue-methods-advance_by"></a>

### `advance_by`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func advance_by(delta_ticks: int, options: Dictionary = {}) -> Dictionary:
```

按相对 tick 推进队列。

参数：

| 名称 | 说明 |
|---|---|
| `delta_ticks` | 推进 tick 数；小于 0 时返回错误报告。 |
| `options` | 推进选项，支持 max_callbacks。 |

返回：推进报告。

结构：

- `options`: Dictionary，可包含 max_callbacks: int。
- `return`: Dictionary，结构同 advance_to()。

<a id="member-gfmanualtimerqueue-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel(handle: int) -> bool:
```

取消一个尚未执行的计时器。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | schedule_at() 返回的计时器句柄。 |

返回：找到并取消时返回 true。

<a id="member-gfmanualtimerqueue-methods-cancel_owner"></a>

### `cancel_owner`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func cancel_owner(owner: Object) -> int:
```

取消指定 owner 绑定的全部待执行计时器。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 计时器拥有者。 |

返回：取消数量。

<a id="member-gfmanualtimerqueue-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空队列和统计。

<a id="member-gfmanualtimerqueue-methods-get_current_tick"></a>

### `get_current_tick`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_current_tick() -> int:
```

获取当前 tick。

返回：当前 tick。

<a id="member-gfmanualtimerqueue-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_count() -> int:
```

获取待执行计时器数量。

返回：待执行数量。

<a id="member-gfmanualtimerqueue-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 current_tick、pending_count、next_due_tick、pending_handles、executed_count、cancelled_count、failed_count 和 skipped_owner_count。
