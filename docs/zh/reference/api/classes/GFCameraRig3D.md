# GFCameraRig3D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_rig_3d.gd`
- 模块：`Camera`
- 继承：`Node3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 3D 相机姿态提供节点。 Rig 只计算期望 Camera3D Transform，不直接控制 Camera3D。 项目可用多个 Rig 表达不同视角，再交给 GFCameraDirector3D 按优先级选择。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`active_changed`](#member-gfcamerarig3d-signals-active_changed) | `signal active_changed(active: bool)` |
| 信号 | [`priority_changed`](#member-gfcamerarig3d-signals-priority_changed) | `signal priority_changed(priority: int)` |
| 属性 | [`active`](#member-gfcamerarig3d-properties-active) | `var active: bool = true:` |
| 属性 | [`priority`](#member-gfcamerarig3d-properties-priority) | `var priority: int = 0:` |
| 属性 | [`target_path`](#member-gfcamerarig3d-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`look_at_target_path`](#member-gfcamerarig3d-properties-look_at_target_path) | `var look_at_target_path: NodePath = NodePath("")` |
| 属性 | [`offset`](#member-gfcamerarig3d-properties-offset) | `var offset: Vector3 = Vector3.ZERO` |
| 属性 | [`offset_follows_rotation`](#member-gfcamerarig3d-properties-offset_follows_rotation) | `var offset_follows_rotation: bool = false` |
| 属性 | [`use_target_rotation`](#member-gfcamerarig3d-properties-use_target_rotation) | `var use_target_rotation: bool = true` |
| 属性 | [`look_at_enabled`](#member-gfcamerarig3d-properties-look_at_enabled) | `var look_at_enabled: bool = false` |
| 属性 | [`up_axis`](#member-gfcamerarig3d-properties-up_axis) | `var up_axis: Vector3 = Vector3.UP` |
| 属性 | [`rotation_degrees_offset`](#member-gfcamerarig3d-properties-rotation_degrees_offset) | `var rotation_degrees_offset: Vector3 = Vector3.ZERO` |
| 属性 | [`blend`](#member-gfcamerarig3d-properties-blend) | `var blend: GFCameraBlend = null` |
| 属性 | [`group_name`](#member-gfcamerarig3d-properties-group_name) | `var group_name: StringName = &"gf_camera_rig_3d":` |
| 属性 | [`camera_scope_path`](#member-gfcamerarig3d-properties-camera_scope_path) | `var camera_scope_path: NodePath = NodePath("")` |
| 属性 | [`camera_channel`](#member-gfcamerarig3d-properties-camera_channel) | `var camera_channel: StringName = &""` |
| 属性 | [`metadata`](#member-gfcamerarig3d-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_target_node`](#member-gfcamerarig3d-methods-get_target_node) | `func get_target_node() -> Node3D:` |
| 方法 | [`get_look_at_target_node`](#member-gfcamerarig3d-methods-get_look_at_target_node) | `func get_look_at_target_node() -> Node3D:` |
| 方法 | [`get_camera_transform`](#member-gfcamerarig3d-methods-get_camera_transform) | `func get_camera_transform() -> Transform3D:` |
| 方法 | [`get_camera_scope_node`](#member-gfcamerarig3d-methods-get_camera_scope_node) | `func get_camera_scope_node() -> Node:` |
| 方法 | [`is_available`](#member-gfcamerarig3d-methods-is_available) | `func is_available() -> bool:` |

## 信号

<a id="member-gfcamerarig3d-signals-active_changed"></a>

### `active_changed`

- API：`public`

```gdscript
signal active_changed(active: bool)
```

Rig 激活状态变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `active` | 当前是否激活。 |

<a id="member-gfcamerarig3d-signals-priority_changed"></a>

### `priority_changed`

- API：`public`

```gdscript
signal priority_changed(priority: int)
```

Rig 优先级变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `priority` | 当前优先级。 |

## 属性

<a id="member-gfcamerarig3d-properties-active"></a>

### `active`

- API：`public`

```gdscript
var active: bool = true:
```

是否参与 Director 选择。

<a id="member-gfcamerarig3d-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0:
```

选择优先级。数值越大越优先。

<a id="member-gfcamerarig3d-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = NodePath("")
```

可选跟随目标。为空时使用 Rig 自身的全局姿态。

<a id="member-gfcamerarig3d-properties-look_at_target_path"></a>

### `look_at_target_path`

- API：`public`

```gdscript
var look_at_target_path: NodePath = NodePath("")
```

可选朝向目标。look_at_enabled 为 true 时生效。

<a id="member-gfcamerarig3d-properties-offset"></a>

### `offset`

- API：`public`

```gdscript
var offset: Vector3 = Vector3.ZERO
```

位置偏移。

<a id="member-gfcamerarig3d-properties-offset_follows_rotation"></a>

### `offset_follows_rotation`

- API：`public`

```gdscript
var offset_follows_rotation: bool = false
```

偏移是否跟随目标旋转。

<a id="member-gfcamerarig3d-properties-use_target_rotation"></a>

### `use_target_rotation`

- API：`public`

```gdscript
var use_target_rotation: bool = true
```

是否读取目标旋转。

<a id="member-gfcamerarig3d-properties-look_at_enabled"></a>

### `look_at_enabled`

- API：`public`

```gdscript
var look_at_enabled: bool = false
```

是否朝向 look_at_target_path。

<a id="member-gfcamerarig3d-properties-up_axis"></a>

### `up_axis`

- API：`public`

```gdscript
var up_axis: Vector3 = Vector3.UP
```

look_at 使用的上方向。为零向量时会回退到 Vector3.UP。

<a id="member-gfcamerarig3d-properties-rotation_degrees_offset"></a>

### `rotation_degrees_offset`

- API：`public`

```gdscript
var rotation_degrees_offset: Vector3 = Vector3.ZERO
```

额外旋转偏移，单位度。

<a id="member-gfcamerarig3d-properties-blend"></a>

### `blend`

- API：`public`

```gdscript
var blend: GFCameraBlend = null
```

进入该 Rig 时使用的过渡。为空时使用 Director 默认过渡。

<a id="member-gfcamerarig3d-properties-group_name"></a>

### `group_name`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var group_name: StringName = &"gf_camera_rig_3d":
```

自动加入的分组名。Director 可按该分组收集候选。

<a id="member-gfcamerarig3d-properties-camera_scope_path"></a>

### `camera_scope_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var camera_scope_path: NodePath = NodePath("")
```

相机选择作用域。为空时使用 Rig 父节点；Director 只会从相同作用域收集分组 Rig。

<a id="member-gfcamerarig3d-properties-camera_channel"></a>

### `camera_channel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var camera_channel: StringName = &""
```

相机选择频道。为空表示默认频道；Director 配置非空频道时只收集同频道 Rig。

<a id="member-gfcamerarig3d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目自定义元数据；框架不会读取或改写其中字段。

## 方法

<a id="member-gfcamerarig3d-methods-get_target_node"></a>

### `get_target_node`

- API：`public`

```gdscript
func get_target_node() -> Node3D:
```

获取跟随目标。

返回：目标 Node3D；不存在时返回 null。

<a id="member-gfcamerarig3d-methods-get_look_at_target_node"></a>

### `get_look_at_target_node`

- API：`public`

```gdscript
func get_look_at_target_node() -> Node3D:
```

获取朝向目标。

返回：目标 Node3D；不存在时返回 null。

<a id="member-gfcamerarig3d-methods-get_camera_transform"></a>

### `get_camera_transform`

- API：`public`

```gdscript
func get_camera_transform() -> Transform3D:
```

获取当前期望相机 Transform。

返回：期望全局 Transform。

<a id="member-gfcamerarig3d-methods-get_camera_scope_node"></a>

### `get_camera_scope_node`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_camera_scope_node() -> Node:
```

获取相机选择作用域节点。

返回：作用域节点；显式路径为空时返回父节点。

<a id="member-gfcamerarig3d-methods-is_available"></a>

### `is_available`

- API：`public`

```gdscript
func is_available() -> bool:
```

检查 Rig 是否可被选择。

返回：可用时返回 true。
