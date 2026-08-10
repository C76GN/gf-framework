# GFTouchButton

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/touch/gf_touch_button.gd`
- 模块：`Standard`
- 继承：`GFTouchControl2D`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用触屏虚拟按钮节点。 可直接发送按下/释放信号，也可映射到 Godot InputMap 动作或虚拟手柄按钮事件。 每次 press 会冻结当时的 action 与虚拟 joypad lane；运行时配置修改从下一次 press 生效。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`button_pressed`](#member-gftouchbutton-signals-button_pressed) | `signal button_pressed` |
| 信号 | [`button_released`](#member-gftouchbutton-signals-button_released) | `signal button_released` |
| 属性 | [`radius`](#member-gftouchbutton-properties-radius) | `var radius: float = 48.0:` |
| 属性 | [`color`](#member-gftouchbutton-properties-color) | `var color: Color = Color(1.0, 1.0, 1.0, 0.3):` |
| 属性 | [`pressed_color`](#member-gftouchbutton-properties-pressed_color) | `var pressed_color: Color = Color(1.0, 1.0, 1.0, 0.65):` |
| 属性 | [`accept_mouse_input`](#member-gftouchbutton-properties-accept_mouse_input) | `var accept_mouse_input: bool = false:` |
| 属性 | [`action_name`](#member-gftouchbutton-properties-action_name) | `var action_name: StringName = &""` |
| 属性 | [`emit_joypad_button`](#member-gftouchbutton-properties-emit_joypad_button) | `var emit_joypad_button: bool = false` |
| 属性 | [`joypad_device_id`](#member-gftouchbutton-properties-joypad_device_id) | `var joypad_device_id: int = -2` |
| 属性 | [`joy_button`](#member-gftouchbutton-properties-joy_button) | `var joy_button: JoyButton = JOY_BUTTON_A` |
| 方法 | [`is_pressed`](#member-gftouchbutton-methods-is_pressed) | `func is_pressed() -> bool:` |
| 方法 | [`release`](#member-gftouchbutton-methods-release) | `func release() -> void:` |

## 信号

<a id="member-gftouchbutton-signals-button_pressed"></a>

### `button_pressed`

- API：`public`

```gdscript
signal button_pressed
```

按钮按下时发出。

<a id="member-gftouchbutton-signals-button_released"></a>

### `button_released`

- API：`public`

```gdscript
signal button_released
```

按钮释放时发出。

## 属性

<a id="member-gftouchbutton-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 48.0:
```

按钮半径。

<a id="member-gftouchbutton-properties-color"></a>

### `color`

- API：`public`

```gdscript
var color: Color = Color(1.0, 1.0, 1.0, 0.3):
```

按钮常态颜色。

<a id="member-gftouchbutton-properties-pressed_color"></a>

### `pressed_color`

- API：`public`

```gdscript
var pressed_color: Color = Color(1.0, 1.0, 1.0, 0.65):
```

按钮按下颜色。

<a id="member-gftouchbutton-properties-accept_mouse_input"></a>

### `accept_mouse_input`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var accept_mouse_input: bool = false:
```

是否允许鼠标左键模拟触屏。默认关闭，避免触屏控件在桌面端隐式接管鼠标输入。 活动 mouse press 期间关闭该选项会先完成当前 press 的 release。

<a id="member-gftouchbutton-properties-action_name"></a>

### `action_name`

- API：`public`

```gdscript
var action_name: StringName = &""
```

映射到 Godot InputMap 的动作名。为空则不映射。

<a id="member-gftouchbutton-properties-emit_joypad_button"></a>

### `emit_joypad_button`

- API：`public`

```gdscript
var emit_joypad_button: bool = false
```

是否额外发送虚拟手柄按钮事件。

<a id="member-gftouchbutton-properties-joypad_device_id"></a>

### `joypad_device_id`

- API：`public`

```gdscript
var joypad_device_id: int = -2
```

虚拟手柄设备 ID。建议使用负数以避开真实手柄。

<a id="member-gftouchbutton-properties-joy_button"></a>

### `joy_button`

- API：`public`

```gdscript
var joy_button: JoyButton = JOY_BUTTON_A
```

对应的手柄按钮。

## 方法

<a id="member-gftouchbutton-methods-is_pressed"></a>

### `is_pressed`

- API：`public`

```gdscript
func is_pressed() -> bool:
```

检查按钮是否处于按下状态。

返回：是否按下。

<a id="member-gftouchbutton-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release() -> void:
```

手动释放按钮。
