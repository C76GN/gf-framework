# GFVirtualInputBridge

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/common/gf_virtual_input_bridge.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

InputMap 与虚拟手柄事件桥接工具。 将触屏按钮、虚拟摇杆或项目自定义输入源写入 Godot InputMap action， 或发送虚拟 joypad button/axis 事件。它不创建 InputMap 动作，也不绑定玩家席位。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`press_action`](#member-gfvirtualinputbridge-methods-press_action) | `static func press_action( action_id: StringName, owner: Object, channel_id: StringName = &"default", strength: float = 1.0 ) -> bool:` |
| 方法 | [`release_action`](#member-gfvirtualinputbridge-methods-release_action) | `static func release_action( action_id: StringName, owner: Object, channel_id: StringName = &"default" ) -> bool:` |
| 方法 | [`release_owner`](#member-gfvirtualinputbridge-methods-release_owner) | `static func release_owner(owner: Object) -> bool:` |
| 方法 | [`clear_all_actions`](#member-gfvirtualinputbridge-methods-clear_all_actions) | `static func clear_all_actions() -> void:` |
| 方法 | [`prune_released_owners`](#member-gfvirtualinputbridge-methods-prune_released_owners) | `static func prune_released_owners() -> int:` |
| 方法 | [`emit_joypad_button`](#member-gfvirtualinputbridge-methods-emit_joypad_button) | `static func emit_joypad_button(device_id: int, button: JoyButton, pressed: bool) -> void:` |
| 方法 | [`emit_joypad_axis`](#member-gfvirtualinputbridge-methods-emit_joypad_axis) | `static func emit_joypad_axis(device_id: int, axis: JoyAxis, value: float) -> void:` |

## 方法

<a id="member-gfvirtualinputbridge-methods-press_action"></a>

### `press_action`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func press_action( action_id: StringName, owner: Object, channel_id: StringName = &"default", strength: float = 1.0 ) -> bool:
```

以指定 owner 身份按下 InputMap action。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | InputMap action 名。 |
| `owner` | 当前虚拟输入来源对象；Node 退出树时自动释放。 |
| `channel_id` | owner 内部的稳定通道 ID。 |
| `strength` | action 强度；非有限值会被视为 0。 |

返回：action 与 owner 有效时返回 true。

<a id="member-gfvirtualinputbridge-methods-release_action"></a>

### `release_action`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func release_action( action_id: StringName, owner: Object, channel_id: StringName = &"default" ) -> bool:
```

释放指定 owner 身份按下的 InputMap action。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | InputMap action 名。 |
| `owner` | 当前虚拟输入来源对象。 |
| `channel_id` | owner 内部的稳定通道 ID。 |

返回：action 与 owner 有效时返回 true。

<a id="member-gfvirtualinputbridge-methods-release_owner"></a>

### `release_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func release_owner(owner: Object) -> bool:
```

释放指定 owner 持有的所有 InputMap action。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 当前虚拟输入来源对象。 |

返回：owner 有效时返回 true。

<a id="member-gfvirtualinputbridge-methods-clear_all_actions"></a>

### `clear_all_actions`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func clear_all_actions() -> void:
```

释放全部由 GF 虚拟输入桥持有的 InputMap action。

<a id="member-gfvirtualinputbridge-methods-prune_released_owners"></a>

### `prune_released_owners`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func prune_released_owners() -> int:
```

清理生命周期已经结束的普通 Object owner。

返回：本次清理的 owner 数量。

<a id="member-gfvirtualinputbridge-methods-emit_joypad_button"></a>

### `emit_joypad_button`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func emit_joypad_button(device_id: int, button: JoyButton, pressed: bool) -> void:
```

发送虚拟手柄按钮事件。

参数：

| 名称 | 说明 |
|---|---|
| `device_id` | 虚拟手柄设备 ID。 |
| `button` | 手柄按钮。 |
| `pressed` | 是否按下。 |

<a id="member-gfvirtualinputbridge-methods-emit_joypad_axis"></a>

### `emit_joypad_axis`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func emit_joypad_axis(device_id: int, axis: JoyAxis, value: float) -> void:
```

发送虚拟手柄轴事件。

参数：

| 名称 | 说明 |
|---|---|
| `device_id` | 虚拟手柄设备 ID。 |
| `axis` | 手柄轴。 |
| `value` | 轴值；会钳制到 -1..1，非有限值会视为 0。 |
