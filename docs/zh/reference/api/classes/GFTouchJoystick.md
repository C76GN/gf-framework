# GFTouchJoystick

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/touch/gf_touch_joystick.gd`
- 模块：`Standard`
- 继承：`Node2D`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用触屏虚拟摇杆节点。 可直接发出摇杆向量信号，也可选择映射到 Godot InputMap 动作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`direction_changed`](#member-gftouchjoystick-signals-direction_changed) | `signal direction_changed(direction: Vector2)` |
| 信号 | [`joystick_pressed`](#member-gftouchjoystick-signals-joystick_pressed) | `signal joystick_pressed` |
| 信号 | [`joystick_released`](#member-gftouchjoystick-signals-joystick_released) | `signal joystick_released` |
| 枚举 | [`PositionMode`](#member-gftouchjoystick-enums-positionmode) | `enum PositionMode` |
| 枚举 | [`OutputMode`](#member-gftouchjoystick-enums-outputmode) | `enum OutputMode` |
| 属性 | [`radius`](#member-gftouchjoystick-properties-radius) | `var radius: float = 64.0:` |
| 属性 | [`knob_radius_ratio`](#member-gftouchjoystick-properties-knob_radius_ratio) | `var knob_radius_ratio: float = 3.0:` |
| 属性 | [`color`](#member-gftouchjoystick-properties-color) | `var color: Color = Color(1.0, 1.0, 1.0, 0.35):` |
| 属性 | [`draw_interaction_zone`](#member-gftouchjoystick-properties-draw_interaction_zone) | `var draw_interaction_zone: bool = false:` |
| 属性 | [`deadzone`](#member-gftouchjoystick-properties-deadzone) | `var deadzone: float = 0.1` |
| 属性 | [`output_mode`](#member-gftouchjoystick-properties-output_mode) | `var output_mode: OutputMode = OutputMode.ANALOG` |
| 属性 | [`position_mode`](#member-gftouchjoystick-properties-position_mode) | `var position_mode: PositionMode = PositionMode.FIXED:` |
| 属性 | [`interaction_radius`](#member-gftouchjoystick-properties-interaction_radius) | `var interaction_radius: float = 160.0:` |
| 属性 | [`use_active_region`](#member-gftouchjoystick-properties-use_active_region) | `var use_active_region: bool = false` |
| 属性 | [`active_region`](#member-gftouchjoystick-properties-active_region) | `var active_region: Rect2 = Rect2()` |
| 属性 | [`release_outside_active_region`](#member-gftouchjoystick-properties-release_outside_active_region) | `var release_outside_active_region: bool = true` |
| 属性 | [`action_left`](#member-gftouchjoystick-properties-action_left) | `var action_left: StringName = &""` |
| 属性 | [`action_right`](#member-gftouchjoystick-properties-action_right) | `var action_right: StringName = &""` |
| 属性 | [`action_up`](#member-gftouchjoystick-properties-action_up) | `var action_up: StringName = &""` |
| 属性 | [`action_down`](#member-gftouchjoystick-properties-action_down) | `var action_down: StringName = &""` |
| 属性 | [`emit_joypad_motion`](#member-gftouchjoystick-properties-emit_joypad_motion) | `var emit_joypad_motion: bool = false` |
| 属性 | [`joypad_device_id`](#member-gftouchjoystick-properties-joypad_device_id) | `var joypad_device_id: int = -2` |
| 属性 | [`joy_axis_x`](#member-gftouchjoystick-properties-joy_axis_x) | `var joy_axis_x: JoyAxis = JOY_AXIS_LEFT_X` |
| 属性 | [`joy_axis_y`](#member-gftouchjoystick-properties-joy_axis_y) | `var joy_axis_y: JoyAxis = JOY_AXIS_LEFT_Y` |
| 方法 | [`get_direction`](#member-gftouchjoystick-methods-get_direction) | `func get_direction() -> Vector2:` |
| 方法 | [`release`](#member-gftouchjoystick-methods-release) | `func release() -> void:` |

## 信号

<a id="member-gftouchjoystick-signals-direction_changed"></a>

### `direction_changed`

- API：`public`

```gdscript
signal direction_changed(direction: Vector2)
```

摇杆向量变化时发出。向量已应用死区并保留模拟强度。

参数：

| 名称 | 说明 |
|---|---|
| `direction` | 已应用死区并保留模拟强度的摇杆向量。 |

<a id="member-gftouchjoystick-signals-joystick_pressed"></a>

### `joystick_pressed`

- API：`public`

```gdscript
signal joystick_pressed
```

摇杆按下时发出。

<a id="member-gftouchjoystick-signals-joystick_released"></a>

### `joystick_released`

- API：`public`

```gdscript
signal joystick_released
```

摇杆释放时发出。

## 枚举

<a id="member-gftouchjoystick-enums-positionmode"></a>

### `PositionMode`

- API：`public`

```gdscript
enum PositionMode {
	## 摇杆中心保持在场景中摆放的位置。
	FIXED,
	## 初次触摸时摇杆中心移动到触点，释放后回到原位置。
	RELATIVE,
	## 初次触摸时摇杆中心移动到触点，拖动超过半径时中心跟随触点。
	FOLLOW,
}
```

摇杆定位模式。

<a id="member-gftouchjoystick-enums-outputmode"></a>

### `OutputMode`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
enum OutputMode {
	## 输出连续模拟向量。
	ANALOG,
	## 输出四方向离散向量。
	DPAD_4,
	## 输出八方向离散向量。
	DPAD_8,
}
```

摇杆输出模式。

## 属性

<a id="member-gftouchjoystick-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 64.0:
```

摇杆半径。

<a id="member-gftouchjoystick-properties-knob_radius_ratio"></a>

### `knob_radius_ratio`

- API：`public`

```gdscript
var knob_radius_ratio: float = 3.0:
```

摇杆手柄半径比例。

<a id="member-gftouchjoystick-properties-color"></a>

### `color`

- API：`public`

```gdscript
var color: Color = Color(1.0, 1.0, 1.0, 0.35):
```

摇杆颜色。

<a id="member-gftouchjoystick-properties-draw_interaction_zone"></a>

### `draw_interaction_zone`

- API：`public`

```gdscript
var draw_interaction_zone: bool = false:
```

是否绘制相对摇杆交互范围。

<a id="member-gftouchjoystick-properties-deadzone"></a>

### `deadzone`

- API：`public`

```gdscript
var deadzone: float = 0.1
```

输入死区，范围 0 到 1。

<a id="member-gftouchjoystick-properties-output_mode"></a>

### `output_mode`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var output_mode: OutputMode = OutputMode.ANALOG
```

输出模式。ANALOG 保留模拟强度，DPAD_4 / DPAD_8 输出离散方向。

<a id="member-gftouchjoystick-properties-position_mode"></a>

### `position_mode`

- API：`public`

```gdscript
var position_mode: PositionMode = PositionMode.FIXED:
```

摇杆定位模式。

<a id="member-gftouchjoystick-properties-interaction_radius"></a>

### `interaction_radius`

- API：`public`

```gdscript
var interaction_radius: float = 160.0:
```

相对模式下允许开始触控的交互半径。

<a id="member-gftouchjoystick-properties-use_active_region"></a>

### `use_active_region`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var use_active_region: bool = false
```

是否限制触摸起点必须位于 active_region 内。

<a id="member-gftouchjoystick-properties-active_region"></a>

### `active_region`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var active_region: Rect2 = Rect2()
```

允许开始触控的屏幕区域，使用 viewport 像素坐标。

<a id="member-gftouchjoystick-properties-release_outside_active_region"></a>

### `release_outside_active_region`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var release_outside_active_region: bool = true
```

拖动离开 active_region 时是否自动释放。

<a id="member-gftouchjoystick-properties-action_left"></a>

### `action_left`

- API：`public`

```gdscript
var action_left: StringName = &""
```

左方向动作名。为空则不映射。

<a id="member-gftouchjoystick-properties-action_right"></a>

### `action_right`

- API：`public`

```gdscript
var action_right: StringName = &""
```

右方向动作名。为空则不映射。

<a id="member-gftouchjoystick-properties-action_up"></a>

### `action_up`

- API：`public`

```gdscript
var action_up: StringName = &""
```

上方向动作名。为空则不映射。

<a id="member-gftouchjoystick-properties-action_down"></a>

### `action_down`

- API：`public`

```gdscript
var action_down: StringName = &""
```

下方向动作名。为空则不映射。

<a id="member-gftouchjoystick-properties-emit_joypad_motion"></a>

### `emit_joypad_motion`

- API：`public`

```gdscript
var emit_joypad_motion: bool = false
```

是否额外发送虚拟手柄轴事件。

<a id="member-gftouchjoystick-properties-joypad_device_id"></a>

### `joypad_device_id`

- API：`public`

```gdscript
var joypad_device_id: int = -2
```

虚拟手柄设备 ID。建议使用负数以避开真实手柄。

<a id="member-gftouchjoystick-properties-joy_axis_x"></a>

### `joy_axis_x`

- API：`public`

```gdscript
var joy_axis_x: JoyAxis = JOY_AXIS_LEFT_X
```

X 轴对应的手柄轴。

<a id="member-gftouchjoystick-properties-joy_axis_y"></a>

### `joy_axis_y`

- API：`public`

```gdscript
var joy_axis_y: JoyAxis = JOY_AXIS_LEFT_Y
```

Y 轴对应的手柄轴。

## 方法

<a id="member-gftouchjoystick-methods-get_direction"></a>

### `get_direction`

- API：`public`

```gdscript
func get_direction() -> Vector2:
```

获取当前摇杆向量。

返回：已应用死区并保留模拟强度的摇杆向量。

<a id="member-gftouchjoystick-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release() -> void:
```

手动释放摇杆并清理动作状态。
