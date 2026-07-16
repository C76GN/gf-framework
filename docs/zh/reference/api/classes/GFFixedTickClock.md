# GFFixedTickClock

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/simulation/gf_fixed_tick_clock.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

固定步长 tick 时钟。 用于网络同步、重放、确定性逻辑或任意固定频率调度；它只计算 tick 推进，不执行项目规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`ticks_advanced`](#member-gffixedtickclock-signals-ticks_advanced) | `signal ticks_advanced(previous_tick: int, current_tick: int, step_count: int)` |
| 信号 | [`tick_loop_started`](#member-gffixedtickclock-signals-tick_loop_started) | `signal tick_loop_started(previous_tick: int, target_tick: int, step_count: int)` |
| 信号 | [`tick_started`](#member-gffixedtickclock-signals-tick_started) | `signal tick_started(tick: int, tick_seconds: float)` |
| 信号 | [`tick_finished`](#member-gffixedtickclock-signals-tick_finished) | `signal tick_finished(tick: int, tick_seconds: float)` |
| 信号 | [`tick_loop_finished`](#member-gffixedtickclock-signals-tick_loop_finished) | `signal tick_loop_finished(previous_tick: int, current_tick: int, step_count: int)` |
| 信号 | [`tick_budget_exhausted`](#member-gffixedtickclock-signals-tick_budget_exhausted) | `signal tick_budget_exhausted(available_steps: int, processed_steps: int, remaining_seconds: float)` |
| 属性 | [`tick_rate`](#member-gffixedtickclock-properties-tick_rate) | `var tick_rate: float = 30.0:` |
| 属性 | [`current_tick`](#member-gffixedtickclock-properties-current_tick) | `var current_tick: int = 0` |
| 属性 | [`accumulator_seconds`](#member-gffixedtickclock-properties-accumulator_seconds) | `var accumulator_seconds: float = 0.0:` |
| 属性 | [`max_steps_per_update`](#member-gffixedtickclock-properties-max_steps_per_update) | `var max_steps_per_update: int = 8` |
| 属性 | [`drop_excess_time_on_budget_hit`](#member-gffixedtickclock-properties-drop_excess_time_on_budget_hit) | `var drop_excess_time_on_budget_hit: bool = true` |
| 方法 | [`configure`](#member-gffixedtickclock-methods-configure) | `func configure(p_tick_rate: float, p_max_steps_per_update: int = -1) -> void:` |
| 方法 | [`reset`](#member-gffixedtickclock-methods-reset) | `func reset(start_tick: int = 0) -> void:` |
| 方法 | [`advance`](#member-gffixedtickclock-methods-advance) | `func advance(delta_seconds: float) -> int:` |
| 方法 | [`step_once`](#member-gffixedtickclock-methods-step_once) | `func step_once() -> int:` |
| 方法 | [`get_tick_seconds`](#member-gffixedtickclock-methods-get_tick_seconds) | `func get_tick_seconds() -> float:` |
| 方法 | [`get_interpolation_alpha`](#member-gffixedtickclock-methods-get_interpolation_alpha) | `func get_interpolation_alpha() -> float:` |
| 方法 | [`get_tick_factor`](#member-gffixedtickclock-methods-get_tick_factor) | `func get_tick_factor() -> float:` |
| 方法 | [`get_lag_seconds`](#member-gffixedtickclock-methods-get_lag_seconds) | `func get_lag_seconds() -> float:` |
| 方法 | [`to_dict`](#member-gffixedtickclock-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gffixedtickclock-methods-from_dict) | `func from_dict(data: Dictionary) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gffixedtickclock-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gffixedtickclock-signals-ticks_advanced"></a>

### `ticks_advanced`

- API：`public`

```gdscript
signal ticks_advanced(previous_tick: int, current_tick: int, step_count: int)
```

tick 推进后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_tick` | 推进前 tick。 |
| `current_tick` | 推进后 tick。 |
| `step_count` | 本轮推进 tick 数。 |

<a id="member-gffixedtickclock-signals-tick_loop_started"></a>

### `tick_loop_started`

- API：`public`

```gdscript
signal tick_loop_started(previous_tick: int, target_tick: int, step_count: int)
```

固定 tick 循环开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_tick` | 循环前 tick。 |
| `target_tick` | 本轮预算内预计推进到的 tick。 |
| `step_count` | 本轮要处理的 tick 数。 |

<a id="member-gffixedtickclock-signals-tick_started"></a>

### `tick_started`

- API：`public`

```gdscript
signal tick_started(tick: int, tick_seconds: float)
```

单个固定 tick 开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 正在处理的 tick。 |
| `tick_seconds` | 单个 tick 的秒数。 |

<a id="member-gffixedtickclock-signals-tick_finished"></a>

### `tick_finished`

- API：`public`

```gdscript
signal tick_finished(tick: int, tick_seconds: float)
```

单个固定 tick 结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `tick` | 已处理完成的 tick。 |
| `tick_seconds` | 单个 tick 的秒数。 |

<a id="member-gffixedtickclock-signals-tick_loop_finished"></a>

### `tick_loop_finished`

- API：`public`

```gdscript
signal tick_loop_finished(previous_tick: int, current_tick: int, step_count: int)
```

固定 tick 循环结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_tick` | 循环前 tick。 |
| `current_tick` | 循环后 tick。 |
| `step_count` | 本轮实际处理的 tick 数。 |

<a id="member-gffixedtickclock-signals-tick_budget_exhausted"></a>

### `tick_budget_exhausted`

- API：`public`

```gdscript
signal tick_budget_exhausted(available_steps: int, processed_steps: int, remaining_seconds: float)
```

由于单次预算限制而未处理所有可用 tick 时发出。

参数：

| 名称 | 说明 |
|---|---|
| `available_steps` | 本轮可用 tick 数。 |
| `processed_steps` | 本轮实际处理 tick 数。 |
| `remaining_seconds` | 预算处理后的累积剩余秒数。 |

## 属性

<a id="member-gffixedtickclock-properties-tick_rate"></a>

### `tick_rate`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var tick_rate: float = 30.0:
```

每秒 tick 数。

<a id="member-gffixedtickclock-properties-current_tick"></a>

### `current_tick`

- API：`public`

```gdscript
var current_tick: int = 0
```

当前 tick。

<a id="member-gffixedtickclock-properties-accumulator_seconds"></a>

### `accumulator_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var accumulator_seconds: float = 0.0:
```

累积但尚未消费的时间。

<a id="member-gffixedtickclock-properties-max_steps_per_update"></a>

### `max_steps_per_update`

- API：`public`

```gdscript
var max_steps_per_update: int = 8
```

单次 advance() 最多推进的 tick 数；小于等于 0 表示不限制。

<a id="member-gffixedtickclock-properties-drop_excess_time_on_budget_hit"></a>

### `drop_excess_time_on_budget_hit`

- API：`public`

```gdscript
var drop_excess_time_on_budget_hit: bool = true
```

达到单次预算上限时是否丢弃过量累积时间，避免长时间追帧。

## 方法

<a id="member-gffixedtickclock-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(p_tick_rate: float, p_max_steps_per_update: int = -1) -> void:
```

配置时钟。

参数：

| 名称 | 说明 |
|---|---|
| `p_tick_rate` | 每秒 tick 数。 |
| `p_max_steps_per_update` | 单次 advance() 最大步数；小于 0 表示保留原值。 |

<a id="member-gffixedtickclock-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset(start_tick: int = 0) -> void:
```

重置时钟。

参数：

| 名称 | 说明 |
|---|---|
| `start_tick` | 起始 tick。 |

<a id="member-gffixedtickclock-methods-advance"></a>

### `advance`

- API：`public`

```gdscript
func advance(delta_seconds: float) -> int:
```

推进时钟并返回应执行的固定步数。

参数：

| 名称 | 说明 |
|---|---|
| `delta_seconds` | 本次累积的真实时间。 |

返回：应执行的固定 tick 数。

<a id="member-gffixedtickclock-methods-step_once"></a>

### `step_once`

- API：`public`

```gdscript
func step_once() -> int:
```

手动推进一个 tick。

返回：推进后的当前 tick。

<a id="member-gffixedtickclock-methods-get_tick_seconds"></a>

### `get_tick_seconds`

- API：`public`

```gdscript
func get_tick_seconds() -> float:
```

获取单个 tick 的秒数。

返回：tick 秒数。

<a id="member-gffixedtickclock-methods-get_interpolation_alpha"></a>

### `get_interpolation_alpha`

- API：`public`

```gdscript
func get_interpolation_alpha() -> float:
```

获取插值 alpha。

返回：0 到 1 的累积时间比例。

<a id="member-gffixedtickclock-methods-get_tick_factor"></a>

### `get_tick_factor`

- API：`public`

```gdscript
func get_tick_factor() -> float:
```

获取当前 tick 插值比例。

返回：0 到 1 的累积时间比例。

<a id="member-gffixedtickclock-methods-get_lag_seconds"></a>

### `get_lag_seconds`

- API：`public`

```gdscript
func get_lag_seconds() -> float:
```

获取当前累积延迟秒数。

返回：累积但尚未消费的时间。

<a id="member-gffixedtickclock-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转为字典。

返回：时钟状态字典。

结构：

- `return`: Dictionary，包含 tick_rate、current_tick、accumulator_seconds、max_steps_per_update、drop_excess_time_on_budget_hit。

<a id="member-gffixedtickclock-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
func from_dict(data: Dictionary) -> void:
```

从字典恢复。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 时钟状态字典。 |

结构：

- `data`: Dictionary，包含 tick_rate、current_tick、accumulator_seconds、max_steps_per_update、drop_excess_time_on_budget_hit。

<a id="member-gffixedtickclock-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试信息字典。

结构：

- `return`: Dictionary，包含 to_dict() 字段以及 tick_seconds、interpolation_alpha、tick_factor、lag_seconds。
