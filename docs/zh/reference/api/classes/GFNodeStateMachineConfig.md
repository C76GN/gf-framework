# GFNodeStateMachineConfig

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_machine_config.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

节点状态机可复用配置资源。 适合把初始状态、历史容量和栈深度等通用运行策略做成资源复用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`initial_state`](#member-gfnodestatemachineconfig-properties-initial_state) | `var initial_state: StringName = &""` |
| 属性 | [`initial_args`](#member-gfnodestatemachineconfig-properties-initial_args) | `var initial_args: Dictionary = {}` |
| 属性 | [`history_max_size`](#member-gfnodestatemachineconfig-properties-history_max_size) | `var history_max_size: int = 32:` |
| 属性 | [`max_stack_depth`](#member-gfnodestatemachineconfig-properties-max_stack_depth) | `var max_stack_depth: int = 8:` |

## 属性

<a id="member-gfnodestatemachineconfig-properties-initial_state"></a>

### `initial_state`

- API：`public`

```gdscript
var initial_state: StringName = &""
```

内部状态组初始状态名。

<a id="member-gfnodestatemachineconfig-properties-initial_args"></a>

### `initial_args`

- API：`public`

```gdscript
var initial_args: Dictionary = {}
```

内部状态组初始状态参数。

结构：

- `initial_args`: 初始状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatemachineconfig-properties-history_max_size"></a>

### `history_max_size`

- API：`public`

```gdscript
var history_max_size: int = 32:
```

每个状态组保留的历史状态名数量。

<a id="member-gfnodestatemachineconfig-properties-max_stack_depth"></a>

### `max_stack_depth`

- API：`public`

```gdscript
var max_stack_depth: int = 8:
```

push_state 可叠加的最大栈深度。
