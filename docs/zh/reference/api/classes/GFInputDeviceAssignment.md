# GFInputDeviceAssignment

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/runtime/gf_input_device_assignment.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

玩家与输入设备的通用映射。 仅描述设备归属，不绑定任何具体输入动作。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`DeviceType`](#member-gfinputdeviceassignment-enums-devicetype) | `enum DeviceType` |
| 属性 | [`player_index`](#member-gfinputdeviceassignment-properties-player_index) | `var player_index: int = 0` |
| 属性 | [`device_type`](#member-gfinputdeviceassignment-properties-device_type) | `var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE` |
| 属性 | [`device_id`](#member-gfinputdeviceassignment-properties-device_id) | `var device_id: int = 0` |
| 属性 | [`metadata`](#member-gfinputdeviceassignment-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`duplicate_assignment`](#member-gfinputdeviceassignment-methods-duplicate_assignment) | `func duplicate_assignment() -> GFInputDeviceAssignment:` |

## 枚举

<a id="member-gfinputdeviceassignment-enums-devicetype"></a>

### `DeviceType`

- API：`public`

```gdscript
enum DeviceType { ## 键盘与鼠标作为一个本地输入设备。 KEYBOARD_MOUSE, ## Godot 手柄设备。 JOYPAD, ## 触控输入设备。 TOUCH, ## AI 或自动化输入来源。 AI, ## 项目自定义输入设备。 CUSTOM, }
```

输入设备类型。

## 属性

<a id="member-gfinputdeviceassignment-properties-player_index"></a>

### `player_index`

- API：`public`

```gdscript
var player_index: int = 0
```

玩家或本地席位索引。

<a id="member-gfinputdeviceassignment-properties-device_type"></a>

### `device_type`

- API：`public`

```gdscript
var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE
```

设备类型。

<a id="member-gfinputdeviceassignment-properties-device_id"></a>

### `device_id`

- API：`public`

```gdscript
var device_id: int = 0
```

Godot 输入设备 ID。键鼠通常为 0，虚拟/AI 可使用 -1。

<a id="member-gfinputdeviceassignment-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

自定义元数据。

结构：

- `metadata`: Dictionary，当前分配的项目侧元数据。

## 方法

<a id="member-gfinputdeviceassignment-methods-duplicate_assignment"></a>

### `duplicate_assignment`

- API：`public`

```gdscript
func duplicate_assignment() -> GFInputDeviceAssignment:
```

创建一个浅拷贝。

返回：新的设备映射。
