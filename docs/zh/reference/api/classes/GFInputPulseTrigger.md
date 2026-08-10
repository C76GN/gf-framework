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

<a id="member-gfinputpulsetrigger-properties-trigger_immediately"></a>

### `trigger_immediately`

- API：`public`

```gdscript
var trigger_immediately: bool = true
```

输入首次变为活跃时是否立即触发。

## 方法

<a id="member-gfinputpulsetrigger-methods-reset_trigger_state"></a>

### `reset_trigger_state`

- API：`public`

```gdscript
func reset_trigger_state(state: Dictionary) -> void:
```

重置输入触发器运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 触发器运行时状态字典。 |

结构：

- `state`: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。

<a id="member-gfinputpulsetrigger-methods-update"></a>

### `update`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态。

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
- `state`: Dictionary，由输入运行时持有，包含 was_active: bool 和 elapsed: float。
