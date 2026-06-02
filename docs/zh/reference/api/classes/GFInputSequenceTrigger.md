# GFInputSequenceTrigger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/sequences/gf_input_sequence_trigger.gd`
- 模块：`Standard`
- 继承：`GFInputTrigger`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

动作序列触发器。 按顺序观察一组前置动作的 just-started 状态，全部完成后当前输入活跃时触发。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`required_action_ids`](#member-gfinputsequencetrigger-properties-required_action_ids) | `var required_action_ids: Array[StringName] = []` |
| 属性 | [`branches`](#member-gfinputsequencetrigger-properties-branches) | `var branches: Array[GFInputSequenceBranch] = []` |
| 属性 | [`max_gap_seconds`](#member-gfinputsequencetrigger-properties-max_gap_seconds) | `var max_gap_seconds: float = 0.4:` |
| 属性 | [`player_scoped`](#member-gfinputsequencetrigger-properties-player_scoped) | `var player_scoped: bool = true` |
| 方法 | [`reset_trigger_state`](#member-gfinputsequencetrigger-methods-reset_trigger_state) | `func reset_trigger_state(state: Dictionary) -> void:` |
| 方法 | [`prepare_runtime`](#member-gfinputsequencetrigger-methods-prepare_runtime) | `func prepare_runtime( _action_id: StringName, input_runtime: Object, player_index: int, state: Dictionary ) -> void:` |
| 方法 | [`update`](#member-gfinputsequencetrigger-methods-update) | `func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:` |

## 属性

<a id="member-gfinputsequencetrigger-properties-required_action_ids"></a>

### `required_action_ids`

- API：`public`

```gdscript
var required_action_ids: Array[StringName] = []
```

当前动作触发前必须依次开始的动作列表。

结构：

- `required_action_ids`: Array[StringName] of action ids that must start in order before this trigger can fire.

<a id="member-gfinputsequencetrigger-properties-branches"></a>

### `branches`

- API：`public`

```gdscript
var branches: Array[GFInputSequenceBranch] = []
```

可选输入序列分支。非空时优先使用分支配置，required_action_ids 保持兼容旧资源。

<a id="member-gfinputsequencetrigger-properties-max_gap_seconds"></a>

### `max_gap_seconds`

- API：`public`

```gdscript
var max_gap_seconds: float = 0.4:
```

相邻步骤允许的最大间隔。小于等于 0 表示不限制。

<a id="member-gfinputsequencetrigger-properties-player_scoped"></a>

### `player_scoped`

- API：`public`

```gdscript
var player_scoped: bool = true
```

玩家级动作是否只检查同一玩家。

## 方法

<a id="member-gfinputsequencetrigger-methods-reset_trigger_state"></a>

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

- `state`: Dictionary，由输入运行时持有，包含 sequence_index、gap_elapsed、completed 和 branch_states。

<a id="member-gfinputsequencetrigger-methods-prepare_runtime"></a>

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

<a id="member-gfinputsequencetrigger-methods-update"></a>

### `update`

- API：`public`

```gdscript
func update(raw_active: bool, _value: Variant, delta: float, state: Dictionary) -> TriggerState:
```

更新运行时状态。

参数：

| 名称 | 说明 |
|---|---|
| `raw_active` | 原始输入是否处于激活状态。 |
| `_value` | 输入值，默认实现不直接使用。 |
| `delta` | 本帧时间增量（秒）。 |
| `state` | 触发器运行时状态字典。 |

返回：触发状态。

结构：

- `_value`: Variant，由当前输入映射产生的动作值。
- `state`: Dictionary，由输入运行时持有，包含分支进度字段。
