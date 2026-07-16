# GFCameraDirector3D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_director_3d.gd`
- 模块：`Camera`
- 继承：`Node`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用 3D 相机编排节点。 Director 从显式路径或分组中收集 GFCameraRig3D，按优先级选择当前 Rig， 并把过渡后的 Transform 应用到 Camera3D。它不规定目标含义、输入来源或业务流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`active_rig_changed`](#member-gfcameradirector3d-signals-active_rig_changed) | `signal active_rig_changed(previous_rig: GFCameraRig3D, new_rig: GFCameraRig3D)` |
| 信号 | [`camera_pose_applied`](#member-gfcameradirector3d-signals-camera_pose_applied) | `signal camera_pose_applied(rig: GFCameraRig3D)` |
| 枚举 | [`UpdateMode`](#member-gfcameradirector3d-enums-updatemode) | `enum UpdateMode` |
| 属性 | [`camera_path`](#member-gfcameradirector3d-properties-camera_path) | `var camera_path: NodePath = NodePath("")` |
| 属性 | [`rig_paths`](#member-gfcameradirector3d-properties-rig_paths) | `var rig_paths: Array[NodePath] = []` |
| 属性 | [`collect_group_rigs`](#member-gfcameradirector3d-properties-collect_group_rigs) | `var collect_group_rigs: bool = true` |
| 属性 | [`rig_group_name`](#member-gfcameradirector3d-properties-rig_group_name) | `var rig_group_name: StringName = &"gf_camera_rig_3d"` |
| 属性 | [`camera_scope_path`](#member-gfcameradirector3d-properties-camera_scope_path) | `var camera_scope_path: NodePath = NodePath("")` |
| 属性 | [`camera_channel`](#member-gfcameradirector3d-properties-camera_channel) | `var camera_channel: StringName = &""` |
| 属性 | [`update_mode`](#member-gfcameradirector3d-properties-update_mode) | `var update_mode: UpdateMode = UpdateMode.IDLE` |
| 属性 | [`default_blend`](#member-gfcameradirector3d-properties-default_blend) | `var default_blend: GFCameraBlend = null` |
| 属性 | [`make_current_on_apply`](#member-gfcameradirector3d-properties-make_current_on_apply) | `var make_current_on_apply: bool = false` |
| 方法 | [`get_camera`](#member-gfcameradirector3d-methods-get_camera) | `func get_camera() -> Camera3D:` |
| 方法 | [`get_active_rig`](#member-gfcameradirector3d-methods-get_active_rig) | `func get_active_rig() -> GFCameraRig3D:` |
| 方法 | [`collect_candidate_rigs`](#member-gfcameradirector3d-methods-collect_candidate_rigs) | `func collect_candidate_rigs() -> Array[GFCameraRig3D]:` |
| 方法 | [`refresh_active_rig`](#member-gfcameradirector3d-methods-refresh_active_rig) | `func refresh_active_rig(force_snap: bool = false) -> GFCameraRig3D:` |
| 方法 | [`set_active_rig`](#member-gfcameradirector3d-methods-set_active_rig) | `func set_active_rig(rig: GFCameraRig3D, force_snap: bool = false) -> bool:` |
| 方法 | [`clear_active_rig_override`](#member-gfcameradirector3d-methods-clear_active_rig_override) | `func clear_active_rig_override(force_snap: bool = false) -> GFCameraRig3D:` |
| 方法 | [`get_debug_snapshot`](#member-gfcameradirector3d-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`process_camera`](#member-gfcameradirector3d-methods-process_camera) | `func process_camera(delta: float) -> bool:` |

## 信号

<a id="member-gfcameradirector3d-signals-active_rig_changed"></a>

### `active_rig_changed`

- API：`public`

```gdscript
signal active_rig_changed(previous_rig: GFCameraRig3D, new_rig: GFCameraRig3D)
```

当前 Rig 变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_rig` | 上一个 Rig。 |
| `new_rig` | 新 Rig。 |

<a id="member-gfcameradirector3d-signals-camera_pose_applied"></a>

### `camera_pose_applied`

- API：`public`

```gdscript
signal camera_pose_applied(rig: GFCameraRig3D)
```

相机姿态应用后发出。

参数：

| 名称 | 说明 |
|---|---|
| `rig` | 当前 Rig。 |

## 枚举

<a id="member-gfcameradirector3d-enums-updatemode"></a>

### `UpdateMode`

- API：`public`

```gdscript
enum UpdateMode {
	## 在 _process 中更新。
	IDLE,
	## 在 _physics_process 中更新。
	PHYSICS,
	## 只在 process_camera() 被显式调用时更新。
	MANUAL,
}
```

Director 自动更新模式。

## 属性

<a id="member-gfcameradirector3d-properties-camera_path"></a>

### `camera_path`

- API：`public`

```gdscript
var camera_path: NodePath = NodePath("")
```

要控制的 Camera3D。

<a id="member-gfcameradirector3d-properties-rig_paths"></a>

### `rig_paths`

- API：`public`

```gdscript
var rig_paths: Array[NodePath] = []
```

显式候选 Rig 路径。

结构：

- `rig_paths`: Array[NodePath]，按顺序保存显式候选 GFCameraRig3D 节点路径。

<a id="member-gfcameradirector3d-properties-collect_group_rigs"></a>

### `collect_group_rigs`

- API：`public`

```gdscript
var collect_group_rigs: bool = true
```

是否按分组收集候选 Rig。

<a id="member-gfcameradirector3d-properties-rig_group_name"></a>

### `rig_group_name`

- API：`public`

```gdscript
var rig_group_name: StringName = &"gf_camera_rig_3d"
```

候选 Rig 分组名。

<a id="member-gfcameradirector3d-properties-camera_scope_path"></a>

### `camera_scope_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var camera_scope_path: NodePath = NodePath("")
```

分组候选 Rig 的收集作用域。为空时使用 Director 父节点。

<a id="member-gfcameradirector3d-properties-camera_channel"></a>

### `camera_channel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var camera_channel: StringName = &""
```

分组候选 Rig 的收集频道。为空时只收集默认频道 Rig。

<a id="member-gfcameradirector3d-properties-update_mode"></a>

### `update_mode`

- API：`public`

```gdscript
var update_mode: UpdateMode = UpdateMode.IDLE
```

自动更新模式。

<a id="member-gfcameradirector3d-properties-default_blend"></a>

### `default_blend`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var default_blend: GFCameraBlend = null
```

默认过渡资源。Rig 没有设置 blend 时使用它。

<a id="member-gfcameradirector3d-properties-make_current_on_apply"></a>

### `make_current_on_apply`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var make_current_on_apply: bool = false
```

应用姿态时是否显式把 Camera3D 设为当前相机。

## 方法

<a id="member-gfcameradirector3d-methods-get_camera"></a>

### `get_camera`

- API：`public`

```gdscript
func get_camera() -> Camera3D:
```

获取当前相机。

返回：Camera3D；不存在时返回 null。

<a id="member-gfcameradirector3d-methods-get_active_rig"></a>

### `get_active_rig`

- API：`public`

```gdscript
func get_active_rig() -> GFCameraRig3D:
```

获取当前激活 Rig。

返回：当前 Rig；没有时返回 null。

<a id="member-gfcameradirector3d-methods-collect_candidate_rigs"></a>

### `collect_candidate_rigs`

- API：`public`

```gdscript
func collect_candidate_rigs() -> Array[GFCameraRig3D]:
```

收集候选 Rig。

返回：候选 Rig 列表。

结构：

- `return`: Array[GFCameraRig3D]，已去重并按优先级排序的候选 Rig。

<a id="member-gfcameradirector3d-methods-refresh_active_rig"></a>

### `refresh_active_rig`

- API：`public`

```gdscript
func refresh_active_rig(force_snap: bool = false) -> GFCameraRig3D:
```

刷新当前激活 Rig。

参数：

| 名称 | 说明 |
|---|---|
| `force_snap` | 为 true 时立即切到新 Rig。 |

返回：当前 Rig。

<a id="member-gfcameradirector3d-methods-set_active_rig"></a>

### `set_active_rig`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_active_rig(rig: GFCameraRig3D, force_snap: bool = false) -> bool:
```

显式设置当前 Rig，并进入手动覆盖模式。 手动覆盖模式下，refresh_active_rig() 不会自动切换到更高优先级 Rig； 调用 clear_active_rig_override() 后才恢复自动选择。

参数：

| 名称 | 说明 |
|---|---|
| `rig` | 新 Rig；可为 null。 |
| `force_snap` | 为 true 时立即切换。 |

返回：设置成功返回 true。

<a id="member-gfcameradirector3d-methods-clear_active_rig_override"></a>

### `clear_active_rig_override`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_active_rig_override(force_snap: bool = false) -> GFCameraRig3D:
```

清除手动 Rig 覆盖，并立即恢复自动选择。

参数：

| 名称 | 说明 |
|---|---|
| `force_snap` | 为 true 时立即切换。 |

返回：自动选择后的当前 Rig。

<a id="member-gfcameradirector3d-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Director 调试快照。

返回：调试快照。

结构：

- `return`: Dictionary，包含 has_camera、has_active_rig、active_rig_path、active_rig_is_manual_override、is_blending 和 last_process。

<a id="member-gfcameradirector3d-methods-process_camera"></a>

### `process_camera`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func process_camera(delta: float) -> bool:
```

推进并应用相机姿态。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 秒。 |

返回：本帧实际应用相机姿态时返回 true；无可用 Rig 时返回 false。
