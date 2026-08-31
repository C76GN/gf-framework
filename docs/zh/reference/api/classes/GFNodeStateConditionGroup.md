# GFNodeStateConditionGroup

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_condition_group.gd`
- 模块：`Standard`
- 继承：`GFNodeStateCondition`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

节点状态条件组合资源。 用于把多个 GFNodeStateCondition 或兼容 evaluate() 的 Resource 组合为 ALL / ANY / NONE 判断。 条件组只返回布尔结果，不直接切换状态或修改状态机结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`MatchMode`](#member-gfnodestateconditiongroup-enums-matchmode) | `enum MatchMode` |
| 属性 | [`mode`](#member-gfnodestateconditiongroup-properties-mode) | `var mode: MatchMode = MatchMode.ALL` |
| 属性 | [`conditions`](#member-gfnodestateconditiongroup-properties-conditions) | `var conditions: Array[Resource] = []` |
| 属性 | [`empty_result`](#member-gfnodestateconditiongroup-properties-empty_result) | `var empty_result: bool = true` |
| 方法 | [`evaluate`](#member-gfnodestateconditiongroup-methods-evaluate) | `func evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:` |
| 方法 | [`_evaluate`](#member-gfnodestateconditiongroup-methods-_evaluate) | `func _evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:` |

## 枚举

<a id="member-gfnodestateconditiongroup-enums-matchmode"></a>

### `MatchMode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum MatchMode {
	## 所有有效条件都必须通过。
	ALL,
	## 任意有效条件通过即可。
	ANY,
	## 所有有效条件都不能通过。
	NONE,
}
```

条件组合模式。

## 属性

<a id="member-gfnodestateconditiongroup-properties-mode"></a>

### `mode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var mode: MatchMode = MatchMode.ALL
```

条件组合模式。

<a id="member-gfnodestateconditiongroup-properties-conditions"></a>

### `conditions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var conditions: Array[Resource] = []
```

子条件资源。null 或没有 evaluate() 方法的资源会被忽略。

结构：

- `conditions`: Array[Resource]，元素为 GFNodeStateCondition 或兼容 evaluate(state, phase, peer_state, args) 的 Resource。

<a id="member-gfnodestateconditiongroup-properties-empty_result"></a>

### `empty_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var empty_result: bool = true
```

没有有效子条件时返回的结果。

## 方法

<a id="member-gfnodestateconditiongroup-methods-evaluate"></a>

### `evaluate`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:
```

评估条件组。递归条件图出现循环、超过深度或工作量上限时始终失败，invert 不会反转该失败。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前条件所属状态。 |
| `phase` | 条件阶段，通常为 enter 或 exit。 |
| `peer_state` | 进入时为来源状态名，退出时为目标状态名。 |
| `args` | 状态切换参数。 |

返回：条件图有效且组合结果通过时返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。

<a id="member-gfnodestateconditiongroup-methods-_evaluate"></a>

### `_evaluate`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _evaluate( state: GFNodeState, phase: StringName, peer_state: StringName = &"", args: Dictionary = {} ) -> bool:
```

条件评估扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前条件所属状态。 |
| `phase` | 条件阶段，通常为 enter 或 exit。 |
| `peer_state` | 进入时为来源状态名，退出时为目标状态名。 |
| `args` | 状态切换参数。 |

返回：条件组通过时返回 true。

结构：

- `args`: 状态切换参数 Dictionary；键和值由调用方约定。
