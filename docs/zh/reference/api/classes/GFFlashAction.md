# GFFlashAction

[API Reference](../index.md) / [Action Queue](../extensions-action-queue.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/action_queue/actions/gf_flash_action.gd`
- 模块：`Action Queue`
- 继承：`GFVisualAction`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 CanvasItem 闪色动作。 将目标节点的颜色属性短暂切到指定颜色，再恢复为原始值。 默认等待 Tween 完成后队列才会继续。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target`](#member-gfflashaction-properties-target) | `var target: CanvasItem` |
| 属性 | [`flash_color`](#member-gfflashaction-properties-flash_color) | `var flash_color: Color = Color.WHITE` |
| 属性 | [`duration`](#member-gfflashaction-properties-duration) | `var duration: float = 0.12` |
| 属性 | [`property_name`](#member-gfflashaction-properties-property_name) | `var property_name: NodePath = ^"modulate"` |
| 方法 | [`execute`](#member-gfflashaction-methods-execute) | `func execute() -> Variant:` |
| 方法 | [`cancel`](#member-gfflashaction-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`pause`](#member-gfflashaction-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfflashaction-methods-resume) | `func resume() -> void:` |
| 方法 | [`finish`](#member-gfflashaction-methods-finish) | `func finish() -> void:` |
| 方法 | [`get_wait_guard_node`](#member-gfflashaction-methods-get_wait_guard_node) | `func get_wait_guard_node() -> Node:` |

## 属性

<a id="member-gfflashaction-properties-target"></a>

### `target`

- API：`public`

```gdscript
var target: CanvasItem
```

需要闪色的目标节点。

<a id="member-gfflashaction-properties-flash_color"></a>

### `flash_color`

- API：`public`

```gdscript
var flash_color: Color = Color.WHITE
```

闪色时写入的颜色。

<a id="member-gfflashaction-properties-duration"></a>

### `duration`

- API：`public`

```gdscript
var duration: float = 0.12
```

闪色总时长。

<a id="member-gfflashaction-properties-property_name"></a>

### `property_name`

- API：`public`

```gdscript
var property_name: NodePath = ^"modulate"
```

要缓动的颜色属性名。

## 方法

<a id="member-gfflashaction-methods-execute"></a>

### `execute`

- API：`public`

```gdscript
func execute() -> Variant:
```

执行闪色 Tween。

返回：需要等待时返回内部完成 Signal；目标无效、属性无效或瞬时写入时返回 null。

结构：

- `return`: Variant，返回内部完成 Signal 或 null。

<a id="member-gfflashaction-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel() -> void:
```

取消当前 Tween 并释放等待者。

<a id="member-gfflashaction-methods-pause"></a>

### `pause`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func pause() -> void:
```

暂停当前闪色 Tween。

<a id="member-gfflashaction-methods-resume"></a>

### `resume`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func resume() -> void:
```

恢复当前闪色 Tween。

<a id="member-gfflashaction-methods-finish"></a>

### `finish`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func finish() -> void:
```

立即结束当前闪色动作并恢复原色。

<a id="member-gfflashaction-methods-get_wait_guard_node"></a>

### `get_wait_guard_node`

- API：`public`

```gdscript
func get_wait_guard_node() -> Node:
```

获取用于保护等待生命周期的目标节点。

返回：有效目标节点；无效时返回 null。
