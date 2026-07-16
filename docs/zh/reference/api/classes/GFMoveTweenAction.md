# GFMoveTweenAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_move_tween_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用节点移动 Tween 动作。 将目标节点的指定位置属性缓动到目标值，适合卡牌、棋子、UI 面板等 常见表现动作。默认等待 Tween 完成后队列才会继续。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfmovetweenaction-properties-target) | `var target: Node` |
| 属性 | [`target_position`](#member-gfmovetweenaction-properties-target_position) | `var target_position: Variant` |
| 属性 | [`duration`](#member-gfmovetweenaction-properties-duration) | `var duration: float:` |
| 属性 | [`property_name`](#member-gfmovetweenaction-properties-property_name) | `var property_name: NodePath = ^"position"` |
| 属性 | [`transition_type`](#member-gfmovetweenaction-properties-transition_type) | `var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC` |
| 属性 | [`ease_type`](#member-gfmovetweenaction-properties-ease_type) | `var ease_type: Tween.EaseType = Tween.EASE_OUT` |
| 方法 | [`execute`](#member-gfmovetweenaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfmovetweenaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfmovetweenaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfmovetweenaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfmovetweenaction-methods-finish) | `func finish() -> void:` |
| 方法 | [`get_wait_guard_node`](#member-gfmovetweenaction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |

## 属性

<a id="member-gfmovetweenaction-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: Node
```

被移动的目标节点。

<a id="member-gfmovetweenaction-properties-target_position"></a>

### `target_position`

- API：`public`

```gdscript
var target_position: Variant
```

要写入的位置值，通常为 Vector2 或 Vector3。

结构：

- `target_position`: Variant，可写入 property_name 的目标位置值，通常为 Vector2、Vector3 或 float。

<a id="member-gfmovetweenaction-properties-duration"></a>

### `duration`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var duration: float:
```

Tween 持续时间。

<a id="member-gfmovetweenaction-properties-property_name"></a>

### `property_name`

- API：`public`

```gdscript
var property_name: NodePath = ^"position"
```

要缓动的属性名。

<a id="member-gfmovetweenaction-properties-transition_type"></a>

### `transition_type`

- API：`public`

```gdscript
var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC
```

Tween 过渡类型。

<a id="member-gfmovetweenaction-properties-ease_type"></a>

### `ease_type`

- API：`public`

```gdscript
var ease_type: Tween.EaseType = Tween.EASE_OUT
```

Tween 缓动类型。

## 方法

<a id="member-gfmovetweenaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行移动 Tween。

返回：需要等待时返回内部完成 Signal；目标无效、配置无效或瞬时写入时返回 null。

结构：

- `return`: Variant，返回内部完成 Signal 或 null。

<a id="member-gfmovetweenaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消当前 Tween 并释放等待者。

<a id="member-gfmovetweenaction-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停当前 Tween。

<a id="member-gfmovetweenaction-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复当前 Tween。

<a id="member-gfmovetweenaction-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish() -> void:
```

立即推进并完成当前 Tween。

<a id="member-gfmovetweenaction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`

```gdscript
func get_wait_guard_node() -> Node:
```

获取用于保护等待生命周期的目标节点。

返回：有效目标节点；无效时返回 null。
