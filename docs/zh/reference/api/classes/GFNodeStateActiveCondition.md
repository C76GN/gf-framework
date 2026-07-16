# GFNodeStateActiveCondition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/state_machine/node/gf_node_state_active_condition.gd`
- 模块：`Standard`
- 继承：`GFNodeStateCondition`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

按状态机当前状态判断的节点状态条件。 用于让状态进入或退出守卫依赖同组、跨组或暂停栈中的状态是否处于激活状态。 它只读取状态机运行态，不解释具体业务状态含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`MatchMode`](#member-gfnodestateactivecondition-enums-matchmode) | `enum MatchMode` |
| 属性 | [`state_paths`](#member-gfnodestateactivecondition-properties-state_paths) | `var state_paths: PackedStringArray = PackedStringArray()` |
| 属性 | [`mode`](#member-gfnodestateactivecondition-properties-mode) | `var mode: MatchMode = MatchMode.ANY` |
| 属性 | [`empty_result`](#member-gfnodestateactivecondition-properties-empty_result) | `var empty_result: bool = false` |
| 方法 | [`_evaluate`](#member-gfnodestateactivecondition-methods-_evaluate) | `func _evaluate( state: GFNodeState, _phase: StringName, _peer_state: StringName = &"", _args: Dictionary = {} ) -> bool:` |

## 枚举

<a id="member-gfnodestateactivecondition-enums-matchmode"></a>

### `MatchMode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
enum MatchMode {
	## 任意状态路径处于激活状态即可。
	ANY,
	## 所有状态路径都必须处于激活状态。
	ALL,
	## 所有状态路径都不能处于激活状态。
	NONE,
}
```

状态匹配模式。

## 属性

<a id="member-gfnodestateactivecondition-properties-state_paths"></a>

### `state_paths`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var state_paths: PackedStringArray = PackedStringArray()
```

要检查的状态路径。可使用 "State" 指向同组状态，或 "Group/State" 指向指定状态组。

<a id="member-gfnodestateactivecondition-properties-mode"></a>

### `mode`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var mode: MatchMode = MatchMode.ANY
```

状态匹配模式。

<a id="member-gfnodestateactivecondition-properties-empty_result"></a>

### `empty_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var empty_result: bool = false
```

没有有效状态路径时返回的结果。

## 方法

<a id="member-gfnodestateactivecondition-methods-_evaluate"></a>

### `_evaluate`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _evaluate( state: GFNodeState, _phase: StringName, _peer_state: StringName = &"", _args: Dictionary = {} ) -> bool:
```

条件评估扩展点。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 当前条件所属状态。 |
| `_phase` | 条件阶段，通常为 enter 或 exit。 |
| `_peer_state` | 进入时为来源状态名，退出时为目标状态名。 |
| `_args` | 状态切换参数。 |

返回：状态匹配通过时返回 true。

结构：

- `_args`: 状态切换参数 Dictionary；键和值由调用方约定。
