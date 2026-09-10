# GFCameraFramingRig2D

[API Reference](../index.md) / [Camera](../extensions-camera.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/camera/nodes/gf_camera_framing_rig_2d.gd`
- 模块：`Camera`
- 继承：`GFCameraRig2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

根据显式目标锚点计算共同入镜的二维相机姿态。 目标位置按期望相机旋转投影，再由实际 Camera2D 输出 Viewport 的尺寸计算统一缩放。 只计算锚点，不推断精灵、碰撞或项目对象的外形；目标路径的选择和维护属于调用方。 复用基础 Rig 的 active、priority、作用域、blend、offset 和旋转偏移。 单目标字段 target_path、use_target_rotation 与固定 zoom 不参与群体取景。 fits 仅表示期望姿态下的锚点几何，不能保证混合途中、原生限位、拖拽或平滑后的画面。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`target_paths`](#member-gfcameraframingrig2d-properties-target_paths) | `var target_paths: Array[NodePath] = []` |
| 属性 | [`viewport_margin`](#member-gfcameraframingrig2d-properties-viewport_margin) | `var viewport_margin: Vector2 = Vector2(16.0, 16.0)` |
| 属性 | [`min_zoom`](#member-gfcameraframingrig2d-properties-min_zoom) | `var min_zoom: float = 0.1` |
| 属性 | [`max_zoom`](#member-gfcameraframingrig2d-properties-max_zoom) | `var max_zoom: float = 10.0` |
| 属性 | [`min_extent`](#member-gfcameraframingrig2d-properties-min_extent) | `var min_extent: Vector2 = Vector2.ONE` |
| 方法 | [`get_framing_report`](#member-gfcameraframingrig2d-methods-get_framing_report) | `func get_framing_report(camera: Camera2D) -> Dictionary:` |
| 方法 | [`get_camera_pose`](#member-gfcameraframingrig2d-methods-get_camera_pose) | `func get_camera_pose(camera: Camera2D = null) -> Dictionary:` |
| 方法 | [`is_available`](#member-gfcameraframingrig2d-methods-is_available) | `func is_available() -> bool:` |

## 属性

<a id="member-gfcameraframingrig2d-properties-target_paths"></a>

### `target_paths`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var target_paths: Array[NodePath] = []
```

相对于本 Rig 的目标路径；每次求值重新解析，最多 256 项。 缺失、离树、排队释放和重复的目标被忽略；没有有效目标时 Rig 不可选。

结构：

- `target_paths`: Array[NodePath]，每项指向与输出 Viewport 世界画布一致的 Node2D 锚点。

<a id="member-gfcameraframingrig2d-properties-viewport_margin"></a>

### `viewport_margin`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var viewport_margin: Vector2 = Vector2(16.0, 16.0)
```

输出 Viewport 左右、上下各自保留的像素边距；必须有限且位于 0 到 1000000。

<a id="member-gfcameraframingrig2d-properties-min_zoom"></a>

### `min_zoom`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var min_zoom: float = 0.1
```

最小统一缩放；必须位于 0.0001 到 max_zoom。约束导致真实锚点超出边距区域时 fits 为 false。

<a id="member-gfcameraframingrig2d-properties-max_zoom"></a>

### `max_zoom`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_zoom: float = 10.0
```

最大统一缩放；必须位于 min_zoom 到 1000000。

<a id="member-gfcameraframingrig2d-properties-min_extent"></a>

### `min_extent`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var min_extent: Vector2 = Vector2.ONE
```

相机轴坐标内最小世界宽高；各分量必须有限、大于零且不超过 1000000。 单目标、重合目标或共线目标以此避免零尺寸除法。

## 方法

<a id="member-gfcameraframingrig2d-methods-get_framing_report"></a>

### `get_framing_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_framing_report(camera: Camera2D) -> Dictionary:
```

计算实际 Camera2D 对应的共同入镜报告，不修改相机、目标或 Viewport。 camera.custom_viewport 为 Viewport 时使用它，否则使用 camera.get_viewport()。 只支持中心锚定模式；ignore_rotation 生效时按零角计算，原生 offset 会反向补偿。 bounds 表示旋转到期望相机轴后的原始目标包围矩形；边距使用输出 Viewport 像素。 自身 basis 必须有限且非退化；不修改相机缩放来补救无法应用的旋转。 目标与输出世界画布不一致、非有限数值、配置越界或无可用尺寸均明确失败。

参数：

| 名称 | 说明 |
|---|---|
| `camera` | 将接收姿态的、已入树且自身 basis 有限非退化、父变换可逆的 Camera2D。 |

返回：纯值报告；ok 为 true 时可应用，fits 独立判断真实锚点能否入镜，不把 min_extent 的人为留白视为目标。

结构：

- `return`: Dictionary，包含 ok: bool、reason: StringName、target_count: int、ignored_target_count: int、viewport_size: Vector2、bounds: Rect2、position: Vector2、rotation: float、zoom: float、required_zoom: float、fits: bool 和 zoom_limited: bool。失败时不提供可应用的姿态。

<a id="member-gfcameraframingrig2d-methods-get_camera_pose"></a>

### `get_camera_pose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_camera_pose(camera: Camera2D = null) -> Dictionary:
```

获取共同入镜的期望姿态，供现有 Director 选择和混合。

参数：

| 名称 | 说明 |
|---|---|
| `camera` | 实际接收姿态的 Camera2D；未提供时明确失败，不猜测全局 Viewport。 |

返回：有效时返回姿态；失败返回空字典，细节可通过 get_framing_report() 查询。

结构：

- `return`: Dictionary，成功包含 position: Vector2、rotation: float、zoom: Vector2 与 rig: GFCameraFramingRig2D；失败为空。

<a id="member-gfcameraframingrig2d-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_available() -> bool:
```

检查配置和目标是否允许 Director 选择本 Rig。 输出 Camera2D 的尺寸、画布与变换在计算姿态时进一步验证。

返回：已入树、启用、配置有效且至少有一个有效锚点时返回 true。
