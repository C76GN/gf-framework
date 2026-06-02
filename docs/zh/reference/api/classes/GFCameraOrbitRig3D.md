# GFCameraOrbitRig3D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_orbit_rig_3d.gd`
- 模块：`Camera`
- 继承：`GFCameraRig3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.23.0`

通用 3D 环绕相机 Rig。 基于目标焦点、yaw / pitch 和距离计算期望 Camera3D Transform。 它只描述相机姿态，不处理碰撞、锁定目标、遮挡或具体玩法输入。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`orbit_changed`](#member-gfcameraorbitrig3d-signals-orbit_changed) | `signal orbit_changed(yaw_degrees_value: float, pitch_degrees_value: float, distance_value: float)` |
| 属性 | [`yaw_degrees`](#member-gfcameraorbitrig3d-properties-yaw_degrees) | `var yaw_degrees: float = 0.0:` |
| 属性 | [`pitch_degrees`](#member-gfcameraorbitrig3d-properties-pitch_degrees) | `var pitch_degrees: float = -20.0:` |
| 属性 | [`distance`](#member-gfcameraorbitrig3d-properties-distance) | `var distance: float = 8.0:` |
| 属性 | [`min_distance`](#member-gfcameraorbitrig3d-properties-min_distance) | `var min_distance: float = 1.0:` |
| 属性 | [`max_distance`](#member-gfcameraorbitrig3d-properties-max_distance) | `var max_distance: float = 50.0:` |
| 属性 | [`min_pitch_degrees`](#member-gfcameraorbitrig3d-properties-min_pitch_degrees) | `var min_pitch_degrees: float = -80.0:` |
| 属性 | [`max_pitch_degrees`](#member-gfcameraorbitrig3d-properties-max_pitch_degrees) | `var max_pitch_degrees: float = 80.0:` |
| 属性 | [`look_at_focus`](#member-gfcameraorbitrig3d-properties-look_at_focus) | `var look_at_focus: bool = true` |
| 属性 | [`orbit_up_axis`](#member-gfcameraorbitrig3d-properties-orbit_up_axis) | `var orbit_up_axis: Vector3 = Vector3.UP` |
| 方法 | [`get_focus_position`](#member-gfcameraorbitrig3d-methods-get_focus_position) | `func get_focus_position() -> Vector3:` |
| 方法 | [`get_orbit_direction`](#member-gfcameraorbitrig3d-methods-get_orbit_direction) | `func get_orbit_direction() -> Vector3:` |
| 方法 | [`get_camera_transform`](#member-gfcameraorbitrig3d-methods-get_camera_transform) | `func get_camera_transform() -> Transform3D:` |
| 方法 | [`set_orbit`](#member-gfcameraorbitrig3d-methods-set_orbit) | `func set_orbit(new_yaw_degrees: float, new_pitch_degrees: float, new_distance: float) -> void:` |
| 方法 | [`apply_orbit_delta`](#member-gfcameraorbitrig3d-methods-apply_orbit_delta) | `func apply_orbit_delta(delta_degrees: Vector2) -> void:` |
| 方法 | [`apply_zoom_delta`](#member-gfcameraorbitrig3d-methods-apply_zoom_delta) | `func apply_zoom_delta(delta_distance: float) -> void:` |
| 方法 | [`clamp_orbit`](#member-gfcameraorbitrig3d-methods-clamp_orbit) | `func clamp_orbit() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfcameraorbitrig3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfcameraorbitrig3d-signals-orbit_changed"></a>

### `orbit_changed`

- API：`public`

```gdscript
signal orbit_changed(yaw_degrees_value: float, pitch_degrees_value: float, distance_value: float)
```

环绕参数变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `yaw_degrees_value` | 当前水平角度。 |
| `pitch_degrees_value` | 当前俯仰角度。 |
| `distance_value` | 当前距离。 |

## 属性

<a id="member-gfcameraorbitrig3d-properties-yaw_degrees"></a>

### `yaw_degrees`

- API：`public`

```gdscript
var yaw_degrees: float = 0.0:
```

水平角度，单位度。

<a id="member-gfcameraorbitrig3d-properties-pitch_degrees"></a>

### `pitch_degrees`

- API：`public`

```gdscript
var pitch_degrees: float = -20.0:
```

俯仰角度，单位度。

<a id="member-gfcameraorbitrig3d-properties-distance"></a>

### `distance`

- API：`public`

```gdscript
var distance: float = 8.0:
```

与焦点的距离。

<a id="member-gfcameraorbitrig3d-properties-min_distance"></a>

### `min_distance`

- API：`public`

```gdscript
var min_distance: float = 1.0:
```

最小距离。

<a id="member-gfcameraorbitrig3d-properties-max_distance"></a>

### `max_distance`

- API：`public`

```gdscript
var max_distance: float = 50.0:
```

最大距离。

<a id="member-gfcameraorbitrig3d-properties-min_pitch_degrees"></a>

### `min_pitch_degrees`

- API：`public`

```gdscript
var min_pitch_degrees: float = -80.0:
```

最小俯仰角度。

<a id="member-gfcameraorbitrig3d-properties-max_pitch_degrees"></a>

### `max_pitch_degrees`

- API：`public`

```gdscript
var max_pitch_degrees: float = 80.0:
```

最大俯仰角度。

<a id="member-gfcameraorbitrig3d-properties-look_at_focus"></a>

### `look_at_focus`

- API：`public`

```gdscript
var look_at_focus: bool = true
```

是否让相机始终朝向焦点。

<a id="member-gfcameraorbitrig3d-properties-orbit_up_axis"></a>

### `orbit_up_axis`

- API：`public`

```gdscript
var orbit_up_axis: Vector3 = Vector3.UP
```

环绕相机的上方向。为零向量时回退到 Vector3.UP。

## 方法

<a id="member-gfcameraorbitrig3d-methods-get_focus_position"></a>

### `get_focus_position`

- API：`public`

```gdscript
func get_focus_position() -> Vector3:
```

获取环绕焦点位置。

返回：当前焦点的全局位置。

<a id="member-gfcameraorbitrig3d-methods-get_orbit_direction"></a>

### `get_orbit_direction`

- API：`public`

```gdscript
func get_orbit_direction() -> Vector3:
```

获取从焦点指向相机的单位方向。

返回：环绕方向。

<a id="member-gfcameraorbitrig3d-methods-get_camera_transform"></a>

### `get_camera_transform`

- API：`public`

```gdscript
func get_camera_transform() -> Transform3D:
```

获取当前期望相机 Transform。

返回：期望全局 Transform。

<a id="member-gfcameraorbitrig3d-methods-set_orbit"></a>

### `set_orbit`

- API：`public`

```gdscript
func set_orbit(new_yaw_degrees: float, new_pitch_degrees: float, new_distance: float) -> void:
```

设置环绕参数。

参数：

| 名称 | 说明 |
|---|---|
| `new_yaw_degrees` | 水平角度，单位度。 |
| `new_pitch_degrees` | 俯仰角度，单位度。 |
| `new_distance` | 与焦点的距离。 |

<a id="member-gfcameraorbitrig3d-methods-apply_orbit_delta"></a>

### `apply_orbit_delta`

- API：`public`

```gdscript
func apply_orbit_delta(delta_degrees: Vector2) -> void:
```

应用环绕角度增量。

参数：

| 名称 | 说明 |
|---|---|
| `delta_degrees` | x 为 yaw 增量，y 为 pitch 增量，单位度。 |

<a id="member-gfcameraorbitrig3d-methods-apply_zoom_delta"></a>

### `apply_zoom_delta`

- API：`public`

```gdscript
func apply_zoom_delta(delta_distance: float) -> void:
```

应用距离增量。

参数：

| 名称 | 说明 |
|---|---|
| `delta_distance` | 距离增量；正数拉远，负数拉近。 |

<a id="member-gfcameraorbitrig3d-methods-clamp_orbit"></a>

### `clamp_orbit`

- API：`public`

```gdscript
func clamp_orbit() -> void:
```

按当前上下限夹紧环绕参数。

<a id="member-gfcameraorbitrig3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取环绕 Rig 调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 yaw_degrees、pitch_degrees、distance、focus_position 和 direction。
