# GFCameraRig2D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_rig_2d.gd`
- 模块：`Camera`
- 继承：`Node2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用 2D 相机姿态提供节点。 Rig 只计算期望相机位置、旋转和缩放，不直接控制 Camera2D。 项目可用多个 Rig 表达不同视角，再交给 GFCameraDirector2D 按优先级选择。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`active_changed`](#member-gfcamerarig2d-signals-active_changed) | `signal active_changed(active: bool)` |
| 信号 | [`priority_changed`](#member-gfcamerarig2d-signals-priority_changed) | `signal priority_changed(priority: int)` |
| 属性 | [`active`](#member-gfcamerarig2d-properties-active) | `var active: bool = true:` |
| 属性 | [`priority`](#member-gfcamerarig2d-properties-priority) | `var priority: int = 0:` |
| 属性 | [`target_path`](#member-gfcamerarig2d-properties-target_path) | `var target_path: NodePath = NodePath("")` |
| 属性 | [`offset`](#member-gfcamerarig2d-properties-offset) | `var offset: Vector2 = Vector2.ZERO` |
| 属性 | [`offset_follows_rotation`](#member-gfcamerarig2d-properties-offset_follows_rotation) | `var offset_follows_rotation: bool = false` |
| 属性 | [`use_target_rotation`](#member-gfcamerarig2d-properties-use_target_rotation) | `var use_target_rotation: bool = true` |
| 属性 | [`rotation_degrees_offset`](#member-gfcamerarig2d-properties-rotation_degrees_offset) | `var rotation_degrees_offset: float = 0.0` |
| 属性 | [`zoom`](#member-gfcamerarig2d-properties-zoom) | `var zoom: Vector2 = Vector2.ONE` |
| 属性 | [`blend`](#member-gfcamerarig2d-properties-blend) | `var blend: GFCameraBlend = null` |
| 属性 | [`group_name`](#member-gfcamerarig2d-properties-group_name) | `var group_name: StringName = &"gf_camera_rig_2d"` |
| 属性 | [`metadata`](#member-gfcamerarig2d-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`get_target_node`](#member-gfcamerarig2d-methods-get_target_node) | `func get_target_node() -> Node2D:` |
| 方法 | [`get_camera_pose`](#member-gfcamerarig2d-methods-get_camera_pose) | `func get_camera_pose() -> Dictionary:` |
| 方法 | [`is_available`](#member-gfcamerarig2d-methods-is_available) | `func is_available() -> bool:` |

## 信号

<a id="member-gfcamerarig2d-signals-active_changed"></a>

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

<a id="member-gfcamerarig2d-signals-priority_changed"></a>

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

<a id="member-gfcamerarig2d-properties-active"></a>

### `active`

- API：`public`

```gdscript
var active: bool = true:
```

是否参与 Director 选择。

<a id="member-gfcamerarig2d-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0:
```

选择优先级。数值越大越优先。

<a id="member-gfcamerarig2d-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: NodePath = NodePath("")
```

可选跟随目标。为空时使用 Rig 自身的全局姿态。

<a id="member-gfcamerarig2d-properties-offset"></a>

### `offset`

- API：`public`

```gdscript
var offset: Vector2 = Vector2.ZERO
```

位置偏移。

<a id="member-gfcamerarig2d-properties-offset_follows_rotation"></a>

### `offset_follows_rotation`

- API：`public`

```gdscript
var offset_follows_rotation: bool = false
```

偏移是否跟随目标旋转。

<a id="member-gfcamerarig2d-properties-use_target_rotation"></a>

### `use_target_rotation`

- API：`public`

```gdscript
var use_target_rotation: bool = true
```

是否读取目标旋转。

<a id="member-gfcamerarig2d-properties-rotation_degrees_offset"></a>

### `rotation_degrees_offset`

- API：`public`

```gdscript
var rotation_degrees_offset: float = 0.0
```

额外旋转偏移，单位度。

<a id="member-gfcamerarig2d-properties-zoom"></a>

### `zoom`

- API：`public`

```gdscript
var zoom: Vector2 = Vector2.ONE
```

期望相机缩放。

<a id="member-gfcamerarig2d-properties-blend"></a>

### `blend`

- API：`public`

```gdscript
var blend: GFCameraBlend = null
```

进入该 Rig 时使用的过渡。为空时使用 Director 默认过渡。

<a id="member-gfcamerarig2d-properties-group_name"></a>

### `group_name`

- API：`public`

```gdscript
var group_name: StringName = &"gf_camera_rig_2d"
```

自动加入的分组名。Director 可按该分组收集候选。

<a id="member-gfcamerarig2d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目自定义元数据；框架不会读取或改写其中字段。

## 方法

<a id="member-gfcamerarig2d-methods-get_target_node"></a>

### `get_target_node`

- API：`public`

```gdscript
func get_target_node() -> Node2D:
```

获取跟随目标。

返回：目标 Node2D；不存在时返回 null。

<a id="member-gfcamerarig2d-methods-get_camera_pose"></a>

### `get_camera_pose`

- API：`public`

```gdscript
func get_camera_pose() -> Dictionary:
```

获取当前期望相机姿态。

返回：包含 position、rotation、zoom 和 rig 的字典。

结构：

- `return`: Dictionary，包含 position: Vector2、rotation: float、zoom: Vector2 与 rig: GFCameraRig2D。

<a id="member-gfcamerarig2d-methods-is_available"></a>

### `is_available`

- API：`public`

```gdscript
func is_available() -> bool:
```

检查 Rig 是否可被选择。

返回：可用时返回 true。
