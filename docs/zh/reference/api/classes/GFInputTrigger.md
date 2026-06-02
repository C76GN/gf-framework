# GFInputTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/triggers/gf_input_trigger.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

输入动作触发器基类。 触发器只决定“原始输入活跃后何时视为动作活跃”，不修改输入值。运行时状态由 GFInputMappingUtility 传入的 Dictionary 保存，因此同一资源可被多个上下文复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`TriggerState`](#member-gfinputtrigger-enums-triggerstate) | `enum TriggerState` |
| 方法 | [`reset_trigger_state`](#member-gfinputtrigger-methods-reset_trigger_state) | `func reset_trigger_state(state: Dictionary) -> void:` |
| 方法 | [`prepare_runtime`](#member-gfinputtrigger-methods-prepare_runtime) | `func prepare_runtime( _action_id: StringName, _input_runtime: Object, _player_index: int, _state: Dictionary ) -> void:` |
| 方法 | [`update`](#member-gfinputtrigger-methods-update) | `func update(raw_active: bool, _value: Variant, _delta: float, _state: Dictionary) -> TriggerState:` |
| 方法 | [`duplicate_trigger`](#member-gfinputtrigger-methods-duplicate_trigger) | `func duplicate_trigger() -> GFInputTrigger:` |

## 枚举

<a id="member-gfinputtrigger-enums-triggerstate"></a>

### `TriggerState`

- API：`public`

```gdscript
enum TriggerState { ## 输入未达到触发条件。 INACTIVE, ## 输入正在等待触发条件，例如长按计时中。 ONGOING, ## 输入已满足触发条件。 TRIGGERED, }
```

触发器本次更新后的动作状态。

## 方法

<a id="member-gfinputtrigger-methods-reset_trigger_state"></a>

### `reset_trigger_state`

- API：`public`

```gdscript
func reset_trigger_state(state: Dictionary) -> void:
```

重置运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 由调用方保存的状态字典。 |

结构：

- `state`: Dictionary，由输入运行时为当前 trigger 实例持有。

<a id="member-gfinputtrigger-methods-prepare_runtime"></a>

### `prepare_runtime`

- API：`public`

```gdscript
func prepare_runtime( _action_id: StringName, _input_runtime: Object, _player_index: int, _state: Dictionary ) -> void:
```

更新前注入运行时上下文。

参数：

| 名称 | 说明 |
|---|---|
| `_action_id` | 当前动作标识。 |
| `_input_runtime` | 输入映射运行时。 |
| `_player_index` | 玩家索引；全局动作传 -1。 |
| `_state` | 该触发器的运行时状态。 |

结构：

- `_state`: Dictionary，由输入运行时为当前 trigger 实例持有。

<a id="member-gfinputtrigger-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(raw_active: bool, _value: Variant, _delta: float, _state: Dictionary) -> TriggerState:
```

更新触发器状态。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否活跃。 |
| `_value` | 当前动作值。 |
| `_delta` | 本次更新经过的秒数；事件驱动刷新时可能为 0。 |
| `_state` | 该触发器的运行时状态。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `_state`: Dictionary，由输入运行时为当前 trigger 实例持有。

<a id="member-gfinputtrigger-methods-duplicate_trigger"></a>

### `duplicate_trigger`

- API：`public`

```gdscript
func duplicate_trigger() -> GFInputTrigger:
```

创建运行时副本。

返回：触发器副本。
