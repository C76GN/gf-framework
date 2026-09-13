# GFInputPulseTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/triggers/gf_input_pulse_trigger.gd`
- 模块：`Standard`
- 继承：`GFInputTrigger`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

周期脉冲触发器。 输入持续活跃时按固定间隔触发一次，可用于连发、菜单重复导航等通用场景。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`interval_seconds`](#member-gfinputpulsetrigger-properties-interval_seconds) | `var interval_seconds: float = 0.1:` |
| 属性 | [`initial_delay_seconds`](#member-gfinputpulsetrigger-properties-initial_delay_seconds) | `var initial_delay_seconds: float = -1.0:` |
| 属性 | [`trigger_immediately`](#member-gfinputpulsetrigger-properties-trigger_immediately) | `var trigger_immediately: bool = true` |
| 方法 | [`reset_trigger_state`](#member-gfinputpulsetrigger-methods-reset_trigger_state) | `func reset_trigger_state(state: Dictionary) -> void:` |
| 方法 | [`update`](#member-gfinputpulsetrigger-methods-update) | `func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:` |

## 属性

<a id="member-gfinputpulsetrigger-properties-interval_seconds"></a>

### `interval_seconds`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var interval_seconds: float = 0.1:
```

脉冲间隔秒数。非有限赋值会被拒绝并保留最后有效值。

<a id="member-gfinputpulsetrigger-properties-initial_delay_seconds"></a>

### `initial_delay_seconds`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var initial_delay_seconds: float = -1.0:
```

首次周期脉冲的等待秒数，从输入激活时开始计时；有限负值统一存为 -1，表示使用 interval_seconds。 0 表示激活时触发一次，并与 trigger_immediately 的脉冲合并，随后等待完整周期。 非有限赋值会被拒绝并保留最后有效值。

<a id="member-gfinputpulsetrigger-properties-trigger_immediately"></a>

### `trigger_immediately`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var trigger_immediately: bool = true
```

输入首次变为活跃时是否立即触发；initial_delay_seconds 为 0 时始终在激活时触发一次。

## 方法

<a id="member-gfinputpulsetrigger-methods-reset_trigger_state"></a>

### `reset_trigger_state`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func reset_trigger_state(state: Dictionary) -> void:
```

重置输入触发器运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 触发器运行时状态字典。 |

结构：

- `state`: Dictionary，由输入运行时按动作和玩家隔离持有，包含 was_active: bool、initial_wait_pending: bool 和 elapsed: float。

<a id="member-gfinputpulsetrigger-methods-update"></a>

### `update`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态；每次最多返回一个脉冲，跨期只保留周期余数，不补发历史脉冲。 激活时产生即时脉冲会忽略当次 delta；否则首次等待消费当次 delta。 持续活跃期间只有有限正 delta 才能触发新的脉冲，事件刷新不会重复触发。 首次等待仅在等待阶段读取，周期每次读取；修改共享配置会影响引用它的动作，但不会共享计时进度。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否处于激活状态。 |
| `_value` | 输入值，默认实现不直接使用。 |
| `delta` | 本帧时间增量（秒）；NaN/Infinity 或负数按 0 处理，不污染状态。 |
| `state` | 触发器运行时状态字典。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `state`: Dictionary，由输入运行时按动作和玩家隔离持有，包含 was_active: bool、initial_wait_pending: bool 和 elapsed: float；elapsed 表示首次等待已用时间或周期余数。
