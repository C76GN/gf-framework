# GFInputVirtualCursorModifier

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/modifiers/gf_input_virtual_cursor_modifier.gd`
- 模块：`Standard`
- 继承：`GFInputModifier`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

虚拟光标输入修饰器。 将二维输入视为速度并积分为一个位置值。它只维护抽象坐标，不访问 Viewport、 Control 或具体 UI 节点。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`initial_position`](#member-gfinputvirtualcursormodifier-properties-initial_position) | `var initial_position: Vector2 = Vector2(0.5, 0.5)` |
| 属性 | [`speed`](#member-gfinputvirtualcursormodifier-properties-speed) | `var speed: Vector2 = Vector2.ONE` |
| 属性 | [`apply_delta_time`](#member-gfinputvirtualcursormodifier-properties-apply_delta_time) | `var apply_delta_time: bool = true` |
| 属性 | [`clamp_to_rect`](#member-gfinputvirtualcursormodifier-properties-clamp_to_rect) | `var clamp_to_rect: bool = true` |
| 属性 | [`clamp_rect`](#member-gfinputvirtualcursormodifier-properties-clamp_rect) | `var clamp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)` |
| 属性 | [`idle_threshold`](#member-gfinputvirtualcursormodifier-properties-idle_threshold) | `var idle_threshold: float = 0.0` |
| 属性 | [`reset_when_idle`](#member-gfinputvirtualcursormodifier-properties-reset_when_idle) | `var reset_when_idle: bool = false` |
| 属性 | [`position`](#member-gfinputvirtualcursormodifier-properties-position) | `var position: Vector2 = Vector2(0.5, 0.5)` |
| 方法 | [`modify`](#member-gfinputvirtualcursormodifier-methods-modify) | `func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:` |
| 方法 | [`modify_3d`](#member-gfinputvirtualcursormodifier-methods-modify_3d) | `func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:` |
| 方法 | [`reset_position`](#member-gfinputvirtualcursormodifier-methods-reset_position) | `func reset_position() -> GFInputVirtualCursorModifier:` |
| 方法 | [`duplicate_modifier`](#member-gfinputvirtualcursormodifier-methods-duplicate_modifier) | `func duplicate_modifier() -> GFInputModifier:` |

## 属性

<a id="member-gfinputvirtualcursormodifier-properties-initial_position"></a>

### `initial_position`

- API：`public`

```gdscript
var initial_position: Vector2 = Vector2(0.5, 0.5)
```

初始位置。

<a id="member-gfinputvirtualcursormodifier-properties-speed"></a>

### `speed`

- API：`public`

```gdscript
var speed: Vector2 = Vector2.ONE
```

每秒移动速度倍率。

<a id="member-gfinputvirtualcursormodifier-properties-apply_delta_time"></a>

### `apply_delta_time`

- API：`public`

```gdscript
var apply_delta_time: bool = true
```

是否按真实经过时间缩放输入。

<a id="member-gfinputvirtualcursormodifier-properties-clamp_to_rect"></a>

### `clamp_to_rect`

- API：`public`

```gdscript
var clamp_to_rect: bool = true
```

是否将位置限制在 clamp_rect 内。

<a id="member-gfinputvirtualcursormodifier-properties-clamp_rect"></a>

### `clamp_rect`

- API：`public`

```gdscript
var clamp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)
```

可用位置范围。

<a id="member-gfinputvirtualcursormodifier-properties-idle_threshold"></a>

### `idle_threshold`

- API：`public`

```gdscript
var idle_threshold: float = 0.0
```

输入低于该长度时视为空闲。

<a id="member-gfinputvirtualcursormodifier-properties-reset_when_idle"></a>

### `reset_when_idle`

- API：`public`

```gdscript
var reset_when_idle: bool = false
```

空闲时是否回到 initial_position。

<a id="member-gfinputvirtualcursormodifier-properties-position"></a>

### `position`

- API：`public`

```gdscript
var position: Vector2 = Vector2(0.5, 0.5)
```

当前虚拟光标位置。

## 方法

<a id="member-gfinputvirtualcursormodifier-methods-modify"></a>

### `modify`

- API：`public`

```gdscript
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
```

修改二维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `_event` | 原始输入事件，默认实现不直接使用。 |
| `_action` | 当前输入动作配置，默认实现不直接使用。 |

返回：更新后的虚拟光标位置。

<a id="member-gfinputvirtualcursormodifier-methods-modify_3d"></a>

### `modify_3d`

- API：`public`

```gdscript
func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:
```

修改三维输入值。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 要写入或修改的值。 |
| `event` | 原始输入事件，默认实现不直接使用。 |
| `action` | 当前输入动作配置，默认实现不直接使用。 |

返回：包含虚拟光标 X/Y 和原 Z 分量的三维值。

<a id="member-gfinputvirtualcursormodifier-methods-reset_position"></a>

### `reset_position`

- API：`public`

```gdscript
func reset_position() -> GFInputVirtualCursorModifier:
```

重置虚拟光标位置。

返回：当前修饰器。

<a id="member-gfinputvirtualcursormodifier-methods-duplicate_modifier"></a>

### `duplicate_modifier`

- API：`public`

```gdscript
func duplicate_modifier() -> GFInputModifier:
```

创建运行时副本。

返回：修饰器副本。
