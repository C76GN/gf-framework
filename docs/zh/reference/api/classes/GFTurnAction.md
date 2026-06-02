# GFTurnAction

[API Reference](../index.md) / [Turn Based](../extensions-turn-based.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/turn_based/runtime/gf_turn_action.gd`
- 模块：`Turn Based`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`3.17.0`

通用回合行动基类。 行动只描述“谁执行、对谁执行、排序值与载荷”，具体效果由子类重写 `_resolve()`。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`action_id`](#member-gfturnaction-properties-action_id) | `var action_id: StringName = &""` |
| 属性 | [`actor`](#member-gfturnaction-properties-actor) | `var actor: Object = null` |
| 属性 | [`targets`](#member-gfturnaction-properties-targets) | `var targets: Array[Object] = []` |
| 属性 | [`payload`](#member-gfturnaction-properties-payload) | `var payload: Variant = null` |
| 属性 | [`priority`](#member-gfturnaction-properties-priority) | `var priority: int = 0` |
| 属性 | [`sort_value`](#member-gfturnaction-properties-sort_value) | `var sort_value: float = 0.0` |
| 属性 | [`is_cancelled`](#member-gfturnaction-properties-is_cancelled) | `var is_cancelled: bool = false` |
| 方法 | [`cancel`](#member-gfturnaction-methods-cancel) | `func cancel() -> void:` |

## 属性

<a id="member-gfturnaction-properties-action_id"></a>

### `action_id`

- API：`public`

```gdscript
var action_id: StringName = &""
```

行动标识。

<a id="member-gfturnaction-properties-actor"></a>

### `actor`

- API：`public`

```gdscript
var actor: Object = null
```

行动发起者。

<a id="member-gfturnaction-properties-targets"></a>

### `targets`

- API：`public`

```gdscript
var targets: Array[Object] = []
```

行动目标列表。

<a id="member-gfturnaction-properties-payload"></a>

### `payload`

- API：`public`

```gdscript
var payload: Variant = null
```

行动载荷，框架只存储并传递，不解释其结构。

结构：

- `payload`: Variant payload consumed by project-specific action resolvers.

<a id="member-gfturnaction-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

主排序优先级，值越大越先处理。

<a id="member-gfturnaction-properties-sort_value"></a>

### `sort_value`

- API：`public`

```gdscript
var sort_value: float = 0.0
```

次排序值，值越大越先处理。

<a id="member-gfturnaction-properties-is_cancelled"></a>

### `is_cancelled`

- API：`public`

```gdscript
var is_cancelled: bool = false
```

是否已取消。

## 方法

<a id="member-gfturnaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消行动。
