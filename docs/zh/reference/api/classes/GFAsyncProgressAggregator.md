# GFAsyncProgressAggregator

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_async_progress_aggregator.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

多任务加权进度聚合器。 用于把调用方定义的多个子任务进度合成为一个 0 到 1 的总进度，并复用 GFAsyncProgress 的数值、消息和时间节流。它只记录和发布进度，不执行任务、 不加载资源，也不决定 UI 平滑或展示策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`progressed`](#member-gfasyncprogressaggregator-signals-progressed) | `signal progressed(value: float, message: String, metadata: Dictionary)` |
| 属性 | [`allow_decrease`](#member-gfasyncprogressaggregator-properties-allow_decrease) | `var allow_decrease: bool = false` |
| 属性 | [`min_delta`](#member-gfasyncprogressaggregator-properties-min_delta) | `var min_delta: float:` |
| 属性 | [`min_interval_msec`](#member-gfasyncprogressaggregator-properties-min_interval_msec) | `var min_interval_msec: int:` |
| 属性 | [`emit_on_message_change`](#member-gfasyncprogressaggregator-properties-emit_on_message_change) | `var emit_on_message_change: bool:` |
| 方法 | [`add_task`](#member-gfasyncprogressaggregator-methods-add_task) | `func add_task(task_key: Variant = null, weight: float = 1.0, task_metadata: Dictionary = {}) -> int:` |
| 方法 | [`has_task`](#member-gfasyncprogressaggregator-methods-has_task) | `func has_task(task_key: Variant) -> bool:` |
| 方法 | [`get_task_index`](#member-gfasyncprogressaggregator-methods-get_task_index) | `func get_task_index(task_key: Variant) -> int:` |
| 方法 | [`set_task_progress`](#member-gfasyncprogressaggregator-methods-set_task_progress) | `func set_task_progress(task_index: int, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`set_task_progress_by_key`](#member-gfasyncprogressaggregator-methods-set_task_progress_by_key) | `func set_task_progress_by_key(task_key: Variant, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`set_task_fraction`](#member-gfasyncprogressaggregator-methods-set_task_fraction) | `func set_task_fraction( task_index: int, completed: float, total: float, message: String = "", task_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`set_task_fraction_by_key`](#member-gfasyncprogressaggregator-methods-set_task_fraction_by_key) | `func set_task_fraction_by_key( task_key: Variant, completed: float, total: float, message: String = "", task_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`complete_task`](#member-gfasyncprogressaggregator-methods-complete_task) | `func complete_task(task_index: int, message: String = "", task_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`complete_task_by_key`](#member-gfasyncprogressaggregator-methods-complete_task_by_key) | `func complete_task_by_key(task_key: Variant, message: String = "", task_metadata: Dictionary = {}) -> bool:` |
| 方法 | [`complete_all`](#member-gfasyncprogressaggregator-methods-complete_all) | `func complete_all(message: String = "", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`reset`](#member-gfasyncprogressaggregator-methods-reset) | `func reset(clear_tasks: bool = false) -> void:` |
| 方法 | [`get_total_progress`](#member-gfasyncprogressaggregator-methods-get_total_progress) | `func get_total_progress() -> float:` |
| 方法 | [`get_task_count`](#member-gfasyncprogressaggregator-methods-get_task_count) | `func get_task_count() -> int:` |
| 方法 | [`is_complete`](#member-gfasyncprogressaggregator-methods-is_complete) | `func is_complete() -> bool:` |
| 方法 | [`get_task_snapshot`](#member-gfasyncprogressaggregator-methods-get_task_snapshot) | `func get_task_snapshot(task_index: int) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfasyncprogressaggregator-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfasyncprogressaggregator-signals-progressed"></a>

### `progressed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal progressed(value: float, message: String, metadata: Dictionary)
```

总进度通过节流条件并对外发布时发出。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 当前总进度，范围 0 到 1。 |
| `message` | 当前进度消息。 |
| `metadata` | 当前进度元数据。 |

结构：

- `metadata`: Dictionary，包含调用方元数据，并补充 total_progress、task_count、total_weight、task_index、task_key、task_progress、task_weight 和 task_metadata 等上下文。

## 属性

<a id="member-gfasyncprogressaggregator-properties-allow_decrease"></a>

### `allow_decrease`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var allow_decrease: bool = false
```

子任务进度是否允许回退。默认 false，用于避免乱序回调造成总进度回跳。

<a id="member-gfasyncprogressaggregator-properties-min_delta"></a>

### `min_delta`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var min_delta: float:
```

触发总进度信号的最小数值变化。设为 0 时任意数值变化都会触发。

<a id="member-gfasyncprogressaggregator-properties-min_interval_msec"></a>

### `min_interval_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var min_interval_msec: int:
```

触发总进度信号的最小时间间隔，单位毫秒。设为 0 时不按时间节流。

<a id="member-gfasyncprogressaggregator-properties-emit_on_message_change"></a>

### `emit_on_message_change`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var emit_on_message_change: bool:
```

消息变化时是否允许触发信号，即使数值变化小于 min_delta。

## 方法

<a id="member-gfasyncprogressaggregator-methods-add_task"></a>

### `add_task`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func add_task(task_key: Variant = null, weight: float = 1.0, task_metadata: Dictionary = {}) -> int:
```

添加一个子任务，并返回任务索引。 如果 task_key 非 null 且已经存在，返回既有任务索引，不修改既有任务。权重会夹到不小于 0。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 可选稳定任务 key；传 null 时创建未命名任务。 |
| `weight` | 任务权重；小于 0 时按 0 处理。 |
| `task_metadata` | 任务元数据。 |

返回：新任务或既有 keyed 任务的索引。

结构：

- `task_key`: Variant，null 表示无名任务；非 null 时必须是 GFVariantKeyCodec 接受的稳定 key。
- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-has_task"></a>

### `has_task`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_task(task_key: Variant) -> bool:
```

判断任务 key 是否已经注册。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 任务 key。 |

返回：key 已注册时返回 true。

结构：

- `task_key`: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。

<a id="member-gfasyncprogressaggregator-methods-get_task_index"></a>

### `get_task_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_task_index(task_key: Variant) -> int:
```

获取任务 key 对应的任务索引。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 任务 key。 |

返回：已注册任务索引；不存在时返回 -1。

结构：

- `task_key`: Variant，必须是 GFVariantKeyCodec 接受的稳定 key。

<a id="member-gfasyncprogressaggregator-methods-set_task_progress"></a>

### `set_task_progress`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_task_progress(task_index: int, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:
```

设置指定任务的 0 到 1 进度。

参数：

| 名称 | 说明 |
|---|---|
| `task_index` | add_task() 返回的任务索引。 |
| `value` | 新任务进度，范围会被夹到 0 到 1。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-set_task_progress_by_key"></a>

### `set_task_progress_by_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_task_progress_by_key(task_key: Variant, value: float, message: String = "", task_metadata: Dictionary = {}) -> bool:
```

通过任务 key 设置 0 到 1 进度。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 任务 key。 |
| `value` | 新任务进度，范围会被夹到 0 到 1。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_key`: Variant，调用方定义的任务 key。
- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-set_task_fraction"></a>

### `set_task_fraction`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_task_fraction( task_index: int, completed: float, total: float, message: String = "", task_metadata: Dictionary = {} ) -> bool:
```

以完成数 / 总数设置指定任务进度。 total 小于等于 0 时按已完成处理，避免未知总量流程永久卡在 0。

参数：

| 名称 | 说明 |
|---|---|
| `task_index` | add_task() 返回的任务索引。 |
| `completed` | 已完成数量。 |
| `total` | 总数量。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-set_task_fraction_by_key"></a>

### `set_task_fraction_by_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_task_fraction_by_key( task_key: Variant, completed: float, total: float, message: String = "", task_metadata: Dictionary = {} ) -> bool:
```

通过任务 key 以完成数 / 总数设置进度。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 任务 key。 |
| `completed` | 已完成数量。 |
| `total` | 总数量。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_key`: Variant，调用方定义的任务 key。
- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-complete_task"></a>

### `complete_task`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func complete_task(task_index: int, message: String = "", task_metadata: Dictionary = {}) -> bool:
```

将指定任务标记为完成。

参数：

| 名称 | 说明 |
|---|---|
| `task_index` | add_task() 返回的任务索引。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-complete_task_by_key"></a>

### `complete_task_by_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func complete_task_by_key(task_key: Variant, message: String = "", task_metadata: Dictionary = {}) -> bool:
```

通过任务 key 标记任务完成。

参数：

| 名称 | 说明 |
|---|---|
| `task_key` | 任务 key。 |
| `message` | 总进度消息。 |
| `task_metadata` | 本次任务元数据，会合并到任务快照。 |

返回：本次更新是否发出了 progressed。

结构：

- `task_key`: Variant，调用方定义的任务 key。
- `task_metadata`: Dictionary，调用方定义的任务上下文。

<a id="member-gfasyncprogressaggregator-methods-complete_all"></a>

### `complete_all`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func complete_all(message: String = "", metadata: Dictionary = {}) -> bool:
```

将所有任务标记为完成，并强制发布总进度 1.0。

参数：

| 名称 | 说明 |
|---|---|
| `message` | 总进度消息。 |
| `metadata` | 完成元数据。 |

返回：是否成功发出 progressed。

结构：

- `metadata`: Dictionary，调用方定义的完成上下文。

<a id="member-gfasyncprogressaggregator-methods-reset"></a>

### `reset`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func reset(clear_tasks: bool = false) -> void:
```

重置聚合器状态，不发出信号。

参数：

| 名称 | 说明 |
|---|---|
| `clear_tasks` | 为 true 时移除全部任务；否则保留任务并把进度归零。 |

<a id="member-gfasyncprogressaggregator-methods-get_total_progress"></a>

### `get_total_progress`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_total_progress() -> float:
```

获取当前加权总进度。 没有正权重任务时返回 1.0，表示当前没有待完成工作。

返回：当前总进度，范围 0 到 1。

<a id="member-gfasyncprogressaggregator-methods-get_task_count"></a>

### `get_task_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_task_count() -> int:
```

获取子任务数量。

返回：当前任务数量。

<a id="member-gfasyncprogressaggregator-methods-is_complete"></a>

### `is_complete`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_complete() -> bool:
```

判断当前加权总进度是否已完成。

返回：总进度为 1.0 时返回 true。

<a id="member-gfasyncprogressaggregator-methods-get_task_snapshot"></a>

### `get_task_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_task_snapshot(task_index: int) -> Dictionary:
```

获取指定任务快照。

参数：

| 名称 | 说明 |
|---|---|
| `task_index` | add_task() 返回的任务索引。 |

返回：任务快照；索引无效时返回空字典。

结构：

- `return`: Dictionary，包含 index、has_key、key、weight、progress 和 metadata。

<a id="member-gfasyncprogressaggregator-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取聚合器调试快照。

返回：聚合器状态快照。

结构：

- `return`: Dictionary，包含 total_progress、total_weight、task_count、is_complete、allow_decrease、tasks 和 progress。
