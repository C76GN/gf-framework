# GFNodeStateCondition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_condition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

节点状态的可复用进入/退出条件资源。 条件只负责判断状态切换是否允许，不直接执行切换或修改状态机结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`condition_id`](#member-gfnodestatecondition-properties-condition_id) | `var condition_id: StringName = &""` |
| 属性 | [`invert`](#member-gfnodestatecondition-properties-invert) | `var invert: bool = false` |
| 属性 | [`metadata`](#member-gfnodestatecondition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`evaluate`](#member-gfnodestatecondition-methods-evaluate) | `func evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:` |
| 方法 | [`_evaluate`](#member-gfnodestatecondition-methods-_evaluate) | `func _evaluate( _state: GFNodeState, _phase: StringName, _peer_state: StringName = &"", _args: Dictionary = {} ) -> bool:` |

## 属性

<a id="member-gfnodestatecondition-properties-condition_id"></a>

### `condition_id`

- API：`public`

```gdscript
var condition_id: StringName = &""
```

条件标识，便于调试或项目工具识别。

<a id="member-gfnodestatecondition-properties-invert"></a>

### `invert`

- API：`public`

```gdscript
var invert: bool = false
```

是否反转 evaluate() 的结果。

<a id="member-gfnodestatecondition-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。

结构：

- `metadata`: 项目自定义元数据 Dictionary；键和值由项目侧约定。

## 方法

<a id="member-gfnodestatecondition-methods-evaluate"></a>

### `evaluate`

- API：`public`

```gdscript
func evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:
```

评估条件。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前条件所属状态。 |
| `phase` | 条件阶段，通常为 enter 或 exit。 |
| `peer_state` | 进入时为来源状态名，退出时为目标状态名。 |
| `args` | 状态切换参数。 |

返回：条件通过时返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestatecondition-methods-_evaluate"></a>

### `_evaluate`

- API：`protected`

```gdscript
func _evaluate( _state: GFNodeState, _phase: StringName, _peer_state: StringName = &"", _args: Dictionary = {} ) -> bool:
```

条件评估扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | 当前条件所属状态。 |
| `_phase` | 条件阶段，通常为 enter 或 exit。 |
| `_peer_state` | 进入时为来源状态名，退出时为目标状态名。 |
| `_args` | 状态切换参数。 |

返回：条件通过时返回 true。

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。
