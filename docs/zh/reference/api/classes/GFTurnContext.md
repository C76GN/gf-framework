# GFTurnContext

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/runtime/gf_turn_context.gd`
- 模块：`Turn Based`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

通用回合流程上下文。 只记录参与者、行动、轮次和元数据，不假设生命值、阵营、技能等业务概念。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`actors`](#member-gfturncontext-properties-actors) | `var actors: Array[Object] = []` |
| 属性 | [`actions`](#member-gfturncontext-properties-actions) | `var actions: Array[GFTurnAction] = []` |
| 属性 | [`current_actor`](#member-gfturncontext-properties-current_actor) | `var current_actor: Object = null` |
| 属性 | [`turn_index`](#member-gfturncontext-properties-turn_index) | `var turn_index: int = 0` |
| 属性 | [`round_index`](#member-gfturncontext-properties-round_index) | `var round_index: int = 0` |
| 属性 | [`metadata`](#member-gfturncontext-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_actor`](#member-gfturncontext-methods-add_actor) | `func add_actor(actor: Object) -> void:` |
| 方法 | [`remove_actor`](#member-gfturncontext-methods-remove_actor) | `func remove_actor(actor: Object) -> void:` |
| 方法 | [`clear_actions`](#member-gfturncontext-methods-clear_actions) | `func clear_actions() -> void:` |
| 方法 | [`get_actor_value`](#member-gfturncontext-methods-get_actor_value) | `func get_actor_value(actor: Object, key: StringName, fallback: Variant = null) -> Variant:` |

## 属性

<a id="member-gfturncontext-properties-actors"></a>

### `actors`

- API：`public`

```gdscript
var actors: Array[Object] = []
```

当前流程参与者。

<a id="member-gfturncontext-properties-actions"></a>

### `actions`

- API：`public`

```gdscript
var actions: Array[GFTurnAction] = []
```

当前待处理行动。

<a id="member-gfturncontext-properties-current_actor"></a>

### `current_actor`

- API：`public`

```gdscript
var current_actor: Object = null
```

当前行动主体。

<a id="member-gfturncontext-properties-turn_index"></a>

### `turn_index`

- API：`public`

```gdscript
var turn_index: int = 0
```

当前回合索引。

<a id="member-gfturncontext-properties-round_index"></a>

### `round_index`

- API：`public`

```gdscript
var round_index: int = 0
```

当前轮次索引。

<a id="member-gfturncontext-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据，框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant] project-defined turn flow metadata.

## 方法

<a id="member-gfturncontext-methods-add_actor"></a>

### `add_actor`

- API：`public`

```gdscript
func add_actor(actor: Object) -> void:
```

添加参与者。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象。 |

<a id="member-gfturncontext-methods-remove_actor"></a>

### `remove_actor`

- API：`public`

```gdscript
func remove_actor(actor: Object) -> void:
```

移除参与者。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象。 |

<a id="member-gfturncontext-methods-clear_actions"></a>

### `clear_actions`

- API：`public`

```gdscript
func clear_actions() -> void:
```

清空运行时行动。

<a id="member-gfturncontext-methods-get_actor_value"></a>

### `get_actor_value`

- API：`public`

```gdscript
func get_actor_value(actor: Object, key: StringName, fallback: Variant = null) -> Variant:
```

从参与者读取排序或判定值。 优先调用 `get_turn_value(key, fallback)`，其次读取对象属性。

参数：

| 名称 | 说明 |
|---|---|
| `actor` | 参与者对象。 |
| `key` | 值键。 |
| `fallback` | 读取失败时的兜底值。 |

返回：读取到的值。

结构：

- `fallback`: Variant returned when no actor value can be read.
- `return`: Variant read from get_turn_value(), object property access, or fallback.
