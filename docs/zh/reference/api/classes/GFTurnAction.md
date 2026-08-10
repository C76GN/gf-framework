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
| 属性 | [`action_id`](#member-gfturnaction-properties-action_id) | `var action_id: StringName:` |
| 属性 | [`actor`](#member-gfturnaction-properties-actor) | `var actor: Object:` |
| 属性 | [`targets`](#member-gfturnaction-properties-targets) | `var targets: Array[Object]:` |
| 属性 | [`payload`](#member-gfturnaction-properties-payload) | `var payload: Variant:` |
| 属性 | [`priority`](#member-gfturnaction-properties-priority) | `var priority: int:` |
| 属性 | [`sort_value`](#member-gfturnaction-properties-sort_value) | `var sort_value: float:` |
| 属性 | [`is_cancelled`](#member-gfturnaction-properties-is_cancelled) | `var is_cancelled: bool:` |
| 方法 | [`cancel`](#member-gfturnaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`is_sealed`](#member-gfturnaction-methods-is_sealed) | `func is_sealed() -> bool:` |
| 方法 | [`_resolve`](#member-gfturnaction-methods-_resolve) | `func _resolve(_context: GFTurnContext) -> Variant:` |
| 方法 | [`_inject_dependencies`](#member-gfturnaction-methods-_inject_dependencies) | `func _inject_dependencies(_architecture: GFArchitecture) -> void:` |

## 属性

<a id="member-gfturnaction-properties-action_id"></a>

### `action_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var action_id: StringName:
```

行动标识。

<a id="member-gfturnaction-properties-actor"></a>

### `actor`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var actor: Object:
```

行动发起者。

<a id="member-gfturnaction-properties-targets"></a>

### `targets`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var targets: Array[Object]:
```

行动目标列表。

<a id="member-gfturnaction-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload: Variant:
```

行动载荷，框架只存储并传递，不解释其结构。

结构：

- `payload`: Variant payload consumed by project-specific action resolvers.

<a id="member-gfturnaction-properties-priority"></a>

### `priority`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var priority: int:
```

主排序优先级，值越大越先处理。

<a id="member-gfturnaction-properties-sort_value"></a>

### `sort_value`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var sort_value: float:
```

次排序值。默认比较器中，有限值越大越先处理；NaN 与正负 Infinity 统一排在有限值之后，并按入队顺序稳定处理。自定义比较器自行定义完整总序。

<a id="member-gfturnaction-properties-is_cancelled"></a>

### `is_cancelled`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var is_cancelled: bool:
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

<a id="member-gfturnaction-methods-is_sealed"></a>

### `is_sealed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_sealed() -> bool:
```

查询行动是否已完成或被丢弃。

返回：已离开所属队列且不可再次使用时返回 true。

<a id="member-gfturnaction-methods-_resolve"></a>

### `_resolve`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _resolve(_context: GFTurnContext) -> Variant:
```

解析行动时由 GFTurnFlowSystem 调用。

参数：

| 名称 | 说明 |
|---|---|
| `_context` | 回合上下文。 |

返回：可等待结果。

结构：

- `return`: Variant that is null or a Signal awaited before action resolution completes.

<a id="member-gfturnaction-methods-_inject_dependencies"></a>

### `_inject_dependencies`

- API：`protected`
- 首次版本：`8.0.0`

```gdscript
func _inject_dependencies(_architecture: GFArchitecture) -> void:
```

注入当前 Flow 所属架构。子类只应缓存实际需要的依赖。

参数：

| 名称 | 说明 |
|---|---|
| `_architecture` | 当前架构。 |
