# GFInputChordTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/triggers/gf_input_chord_trigger.gd`
- 模块：`Standard`
- 继承：`GFInputTrigger`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

组合动作触发器。 当前输入活跃且另一个动作也处于活跃状态时触发，不绑定具体按键。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`required_action_id`](#member-gfinputchordtrigger-properties-required_action_id) | `var required_action_id: StringName = &""` |
| 属性 | [`player_scoped`](#member-gfinputchordtrigger-properties-player_scoped) | `var player_scoped: bool = true` |
| 方法 | [`prepare_runtime`](#member-gfinputchordtrigger-methods-prepare_runtime) | `func prepare_runtime( _action_id: StringName, input_runtime: Object, player_index: int, state: Dictionary ) -> void:` |
| 方法 | [`update`](#member-gfinputchordtrigger-methods-update) | `func update(raw_active: bool, _value: Variant, _delta: float, state: Dictionary) -> TriggerState:` |

## 属性

<a id="member-gfinputchordtrigger-properties-required_action_id"></a>

### `required_action_id`

- API：`public`

```gdscript
var required_action_id: StringName = &""
```

需要同时保持活跃的动作标识。

<a id="member-gfinputchordtrigger-properties-player_scoped"></a>

### `player_scoped`

- API：`public`

```gdscript
var player_scoped: bool = true
```

玩家级动作是否只检查同一玩家。

## 方法

<a id="member-gfinputchordtrigger-methods-prepare_runtime"></a>

### `prepare_runtime`

- API：`public`

```gdscript
func prepare_runtime( _action_id: StringName, input_runtime: Object, player_index: int, state: Dictionary ) -> void:
```

准备输入动作运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `_action_id` | 当前输入动作标识，默认实现不直接使用。 |
| `input_runtime` | 输入映射运行时。 |
| `player_index` | 玩家索引。 |
| `state` | 触发器运行时状态字典。 |

结构：

- `state`: Dictionary，由输入运行时持有，包含 input_runtime: Object 和 player_index: int。

<a id="member-gfinputchordtrigger-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(raw_active: bool, _value: Variant, _delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否处于激活状态。 |
| `_value` | 输入值，默认实现不直接使用。 |
| `_delta` | 本帧时间增量（秒），默认实现不直接使用。 |
| `state` | 触发器运行时状态字典。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `state`: Dictionary，由输入运行时持有，包含 input_runtime: Object 和 player_index: int。
