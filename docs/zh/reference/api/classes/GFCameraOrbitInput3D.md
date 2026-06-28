# GFCameraOrbitInput3D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_orbit_input_3d.gd`
- 模块：`Camera`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.23.0`

通用 3D 环绕相机输入桥接节点。 将 GFInputMappingUtility 的可配置动作值或鼠标拖拽转换为 GFCameraOrbitRig3D 的角度和距离增量。 它不创建输入上下文，也不定义项目动作绑定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`UpdateMode`](#member-gfcameraorbitinput3d-enums-updatemode) | `enum UpdateMode` |
| 属性 | [`enabled`](#member-gfcameraorbitinput3d-properties-enabled) | `var enabled: bool = true:` |
| 属性 | [`orbit_rig_path`](#member-gfcameraorbitinput3d-properties-orbit_rig_path) | `var orbit_rig_path: NodePath = NodePath("")` |
| 属性 | [`update_mode`](#member-gfcameraorbitinput3d-properties-update_mode) | `var update_mode: UpdateMode = UpdateMode.IDLE` |
| 属性 | [`use_input_mapping`](#member-gfcameraorbitinput3d-properties-use_input_mapping) | `var use_input_mapping: bool = false` |
| 属性 | [`node_context_path`](#member-gfcameraorbitinput3d-properties-node_context_path) | `var node_context_path: NodePath = NodePath("")` |
| 属性 | [`orbit_action_id`](#member-gfcameraorbitinput3d-properties-orbit_action_id) | `var orbit_action_id: StringName = &"camera_orbit"` |
| 属性 | [`zoom_action_id`](#member-gfcameraorbitinput3d-properties-zoom_action_id) | `var zoom_action_id: StringName = &"camera_zoom"` |
| 属性 | [`orbit_degrees_per_second`](#member-gfcameraorbitinput3d-properties-orbit_degrees_per_second) | `var orbit_degrees_per_second: float = 120.0` |
| 属性 | [`zoom_units_per_second`](#member-gfcameraorbitinput3d-properties-zoom_units_per_second) | `var zoom_units_per_second: float = 8.0` |
| 属性 | [`invert_y`](#member-gfcameraorbitinput3d-properties-invert_y) | `var invert_y: bool = false` |
| 属性 | [`mouse_orbit_enabled`](#member-gfcameraorbitinput3d-properties-mouse_orbit_enabled) | `var mouse_orbit_enabled: bool = false:` |
| 属性 | [`mouse_button`](#member-gfcameraorbitinput3d-properties-mouse_button) | `var mouse_button: MouseButton = MOUSE_BUTTON_RIGHT` |
| 属性 | [`mouse_degrees_per_pixel`](#member-gfcameraorbitinput3d-properties-mouse_degrees_per_pixel) | `var mouse_degrees_per_pixel: float = 0.15` |
| 属性 | [`mouse_zoom_enabled`](#member-gfcameraorbitinput3d-properties-mouse_zoom_enabled) | `var mouse_zoom_enabled: bool = false` |
| 属性 | [`mouse_wheel_step`](#member-gfcameraorbitinput3d-properties-mouse_wheel_step) | `var mouse_wheel_step: float = 1.0` |
| 属性 | [`consume_mouse_input`](#member-gfcameraorbitinput3d-properties-consume_mouse_input) | `var consume_mouse_input: bool = true` |
| 属性 | [`input_mapping_utility`](#member-gfcameraorbitinput3d-properties-input_mapping_utility) | `var input_mapping_utility: GFInputMappingUtility = null` |
| 方法 | [`get_orbit_rig`](#member-gfcameraorbitinput3d-methods-get_orbit_rig) | `func get_orbit_rig() -> GFCameraOrbitRig3D:` |
| 方法 | [`set_input_mapping_utility`](#member-gfcameraorbitinput3d-methods-set_input_mapping_utility) | `func set_input_mapping_utility(utility: GFInputMappingUtility) -> void:` |
| 方法 | [`process_input`](#member-gfcameraorbitinput3d-methods-process_input) | `func process_input(delta: float) -> bool:` |
| 方法 | [`apply_orbit_vector`](#member-gfcameraorbitinput3d-methods-apply_orbit_vector) | `func apply_orbit_vector(value: Vector2, scale: float = 1.0) -> bool:` |
| 方法 | [`apply_zoom_value`](#member-gfcameraorbitinput3d-methods-apply_zoom_value) | `func apply_zoom_value(value: float, scale: float = 1.0) -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfcameraorbitinput3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 枚举

<a id="member-gfcameraorbitinput3d-enums-updatemode"></a>

### `UpdateMode`

- API：`public`

```gdscript
enum UpdateMode {
	## 在 _process 中读取输入。
	IDLE,
	## 在 _physics_process 中读取输入。
	PHYSICS,
	## 只在 process_input() 被显式调用时读取输入。
	MANUAL,
}
```

输入自动处理模式。

## 属性

<a id="member-gfcameraorbitinput3d-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var enabled: bool = true:
```

是否启用输入桥接。

<a id="member-gfcameraorbitinput3d-properties-orbit_rig_path"></a>

### `orbit_rig_path`

- API：`public`

```gdscript
var orbit_rig_path: NodePath = NodePath("")
```

要控制的环绕 Rig。为空时使用父节点中的 GFCameraOrbitRig3D。

<a id="member-gfcameraorbitinput3d-properties-update_mode"></a>

### `update_mode`

- API：`public`

```gdscript
var update_mode: UpdateMode = UpdateMode.IDLE
```

自动处理模式。

<a id="member-gfcameraorbitinput3d-properties-use_input_mapping"></a>

### `use_input_mapping`

- API：`public`

```gdscript
var use_input_mapping: bool = false
```

是否从 GFInputMappingUtility 读取动作值。默认关闭，项目应显式启用并配置动作 ID。

<a id="member-gfcameraorbitinput3d-properties-node_context_path"></a>

### `node_context_path`

- API：`public`

```gdscript
var node_context_path: NodePath = NodePath("")
```

可选 GFNodeContext 路径。设置后会从该上下文获取 GFInputMappingUtility。

<a id="member-gfcameraorbitinput3d-properties-orbit_action_id"></a>

### `orbit_action_id`

- API：`public`

```gdscript
var orbit_action_id: StringName = &"camera_orbit"
```

环绕输入动作 ID。动作值应为 Vector2。

<a id="member-gfcameraorbitinput3d-properties-zoom_action_id"></a>

### `zoom_action_id`

- API：`public`

```gdscript
var zoom_action_id: StringName = &"camera_zoom"
```

缩放输入动作 ID。动作值应为 float 或 bool。

<a id="member-gfcameraorbitinput3d-properties-orbit_degrees_per_second"></a>

### `orbit_degrees_per_second`

- API：`public`

```gdscript
var orbit_degrees_per_second: float = 120.0
```

每秒环绕角速度，单位度。

<a id="member-gfcameraorbitinput3d-properties-zoom_units_per_second"></a>

### `zoom_units_per_second`

- API：`public`

```gdscript
var zoom_units_per_second: float = 8.0
```

每秒缩放速度，单位距离。

<a id="member-gfcameraorbitinput3d-properties-invert_y"></a>

### `invert_y`

- API：`public`

```gdscript
var invert_y: bool = false
```

是否反转垂直环绕输入。

<a id="member-gfcameraorbitinput3d-properties-mouse_orbit_enabled"></a>

### `mouse_orbit_enabled`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var mouse_orbit_enabled: bool = false:
```

是否启用鼠标拖拽环绕。默认关闭，避免框架节点隐式接管项目输入。

<a id="member-gfcameraorbitinput3d-properties-mouse_button"></a>

### `mouse_button`

- API：`public`

```gdscript
var mouse_button: MouseButton = MOUSE_BUTTON_RIGHT
```

鼠标拖拽环绕使用的按键。

<a id="member-gfcameraorbitinput3d-properties-mouse_degrees_per_pixel"></a>

### `mouse_degrees_per_pixel`

- API：`public`

```gdscript
var mouse_degrees_per_pixel: float = 0.15
```

鼠标每像素对应的角度。

<a id="member-gfcameraorbitinput3d-properties-mouse_zoom_enabled"></a>

### `mouse_zoom_enabled`

- API：`public`

```gdscript
var mouse_zoom_enabled: bool = false
```

是否启用鼠标滚轮缩放。默认关闭，避免框架节点隐式接管项目输入。

<a id="member-gfcameraorbitinput3d-properties-mouse_wheel_step"></a>

### `mouse_wheel_step`

- API：`public`

```gdscript
var mouse_wheel_step: float = 1.0
```

鼠标滚轮每格缩放距离。

<a id="member-gfcameraorbitinput3d-properties-consume_mouse_input"></a>

### `consume_mouse_input`

- API：`public`

```gdscript
var consume_mouse_input: bool = true
```

鼠标输入被应用后是否标记为已处理。

<a id="member-gfcameraorbitinput3d-properties-input_mapping_utility"></a>

### `input_mapping_utility`

- API：`public`

```gdscript
var input_mapping_utility: GFInputMappingUtility = null
```

显式注入的输入映射工具。为空时尝试从 node_context_path 或父级 GFNodeContext 获取。

## 方法

<a id="member-gfcameraorbitinput3d-methods-get_orbit_rig"></a>

### `get_orbit_rig`

- API：`public`

```gdscript
func get_orbit_rig() -> GFCameraOrbitRig3D:
```

获取当前控制的环绕 Rig。

返回：环绕 Rig；不存在时返回 null。

<a id="member-gfcameraorbitinput3d-methods-set_input_mapping_utility"></a>

### `set_input_mapping_utility`

- API：`public`

```gdscript
func set_input_mapping_utility(utility: GFInputMappingUtility) -> void:
```

显式设置输入映射工具。

参数：

| 名称 | 说明 |
|---|---|
| `utility` | 输入映射工具；传 null 表示回退到上下文查找。 |

<a id="member-gfcameraorbitinput3d-methods-process_input"></a>

### `process_input`

- API：`public`

```gdscript
func process_input(delta: float) -> bool:
```

读取输入映射并推进环绕 Rig。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 本帧时间增量（秒）。 |

返回：应用了任意输入时返回 true。

<a id="member-gfcameraorbitinput3d-methods-apply_orbit_vector"></a>

### `apply_orbit_vector`

- API：`public`

```gdscript
func apply_orbit_vector(value: Vector2, scale: float = 1.0) -> bool:
```

应用二维环绕输入。

参数：

| 名称 | 说明 |
|---|---|
| `value` | x 为 yaw 输入，y 为 pitch 输入。 |
| `scale` | 输入缩放量，通常是每秒速度乘以 delta。 |

返回：成功应用时返回 true。

<a id="member-gfcameraorbitinput3d-methods-apply_zoom_value"></a>

### `apply_zoom_value`

- API：`public`

```gdscript
func apply_zoom_value(value: float, scale: float = 1.0) -> bool:
```

应用一维缩放输入。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 缩放输入；正数拉远，负数拉近。 |
| `scale` | 输入缩放量，通常是每秒速度乘以 delta。 |

返回：成功应用时返回 true。

<a id="member-gfcameraorbitinput3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取输入桥接调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 enabled、update_mode、use_input_mapping、orbit_action_id、zoom_action_id、has_rig 和 has_input_mapping。
