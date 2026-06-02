# GFShakeReceiver3D

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/nodes/gf_shake_receiver_3d.gd`
- 模块：`Feedback`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

将反馈采样应用到 Node3D 的通用接收器。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_path`](#member-gfshakereceiver3d-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`channel`](#member-gfshakereceiver3d-properties-channel) | `var channel: StringName = &"default"` |
| 属性 | [`apply_position`](#member-gfshakereceiver3d-properties-apply_position) | `var apply_position: bool = true` |
| 属性 | [`apply_rotation`](#member-gfshakereceiver3d-properties-apply_rotation) | `var apply_rotation: bool = true` |
| 属性 | [`apply_scale`](#member-gfshakereceiver3d-properties-apply_scale) | `var apply_scale: bool = false` |
| 属性 | [`capture_on_ready`](#member-gfshakereceiver3d-properties-capture_on_ready) | `var capture_on_ready: bool = true` |
| 属性 | [`restore_on_exit`](#member-gfshakereceiver3d-properties-restore_on_exit) | `var restore_on_exit: bool = true` |
| 属性 | [`utility`](#member-gfshakereceiver3d-properties-utility) | `var utility: GFShakeUtility = null` |
| 方法 | [`set_utility`](#member-gfshakereceiver3d-methods-set_utility) | `func set_utility(shake_utility: GFShakeUtility) -> void:` |
| 方法 | [`get_target`](#member-gfshakereceiver3d-methods-get_target) | `func get_target() -> Node3D:` |
| 方法 | [`capture_base_transform`](#member-gfshakereceiver3d-methods-capture_base_transform) | `func capture_base_transform() -> bool:` |
| 方法 | [`apply_current_sample`](#member-gfshakereceiver3d-methods-apply_current_sample) | `func apply_current_sample() -> bool:` |
| 方法 | [`reset_to_base`](#member-gfshakereceiver3d-methods-reset_to_base) | `func reset_to_base() -> bool:` |

## 属性

<a id="member-gfshakereceiver3d-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = NodePath("")
```

目标 Node3D 路径；为空时优先使用自身，其次使用父节点。

<a id="member-gfshakereceiver3d-properties-channel"></a>

### `channel`

- API：`public`

```gdscript
var channel: StringName = &"default"
```

采样 channel。

<a id="member-gfshakereceiver3d-properties-apply_position"></a>

### `apply_position`

- API：`public`

```gdscript
var apply_position: bool = true
```

是否应用 position 偏移。

<a id="member-gfshakereceiver3d-properties-apply_rotation"></a>

### `apply_rotation`

- API：`public`

```gdscript
var apply_rotation: bool = true
```

是否应用 rotation_degrees 偏移。

<a id="member-gfshakereceiver3d-properties-apply_scale"></a>

### `apply_scale`

- API：`public`

```gdscript
var apply_scale: bool = false
```

是否应用 scale 偏移。

<a id="member-gfshakereceiver3d-properties-capture_on_ready"></a>

### `capture_on_ready`

- API：`public`

```gdscript
var capture_on_ready: bool = true
```

ready 时是否记录基础变换。

<a id="member-gfshakereceiver3d-properties-restore_on_exit"></a>

### `restore_on_exit`

- API：`public`

```gdscript
var restore_on_exit: bool = true
```

退出树时是否恢复基础变换。

<a id="member-gfshakereceiver3d-properties-utility"></a>

### `utility`

- API：`public`

```gdscript
var utility: GFShakeUtility = null
```

可选反馈工具实例；为空时从全局架构查询。

## 方法

<a id="member-gfshakereceiver3d-methods-set_utility"></a>

### `set_utility`

- API：`public`

```gdscript
func set_utility(shake_utility: GFShakeUtility) -> void:
```

设置反馈工具实例。

参数：

| 名称 | 说明 |
|---|---|
| `shake_utility` | 反馈工具实例。 |

<a id="member-gfshakereceiver3d-methods-get_target"></a>

### `get_target`

- API：`public`

```gdscript
func get_target() -> Node3D:
```

获取当前目标节点。

返回：目标 Node3D；不存在时返回 null。

<a id="member-gfshakereceiver3d-methods-capture_base_transform"></a>

### `capture_base_transform`

- API：`public`

```gdscript
func capture_base_transform() -> bool:
```

记录当前目标基础变换。

返回：记录成功返回 true。

<a id="member-gfshakereceiver3d-methods-apply_current_sample"></a>

### `apply_current_sample`

- API：`public`

```gdscript
func apply_current_sample() -> bool:
```

应用当前 channel 采样。

返回：应用成功返回 true。

<a id="member-gfshakereceiver3d-methods-reset_to_base"></a>

### `reset_to_base`

- API：`public`

```gdscript
func reset_to_base() -> bool:
```

恢复目标基础变换。

返回：恢复成功返回 true。
