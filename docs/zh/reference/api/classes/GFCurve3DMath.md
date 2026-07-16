# GFCurve3DMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_curve_3d_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

Curve3D 与 3D 折线的纯算法辅助。 提供路径长度、归一化采样、姿态报告和最近点投影， 不持有节点状态，也不解释车辆、导航、碰撞、渲染或编辑器交互语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_polyline_length`](#member-gfcurve3dmath-methods-get_polyline_length) | `static func get_polyline_length(points: PackedVector3Array) -> float:` |
| 方法 | [`sample_polyline`](#member-gfcurve3dmath-methods-sample_polyline) | `static func sample_polyline( points: PackedVector3Array, ratio: float, total_length: float = -1.0 ) -> Vector3:` |
| 方法 | [`sample_polyline_pose`](#member-gfcurve3dmath-methods-sample_polyline_pose) | `static func sample_polyline_pose( points: PackedVector3Array, ratio: float, closed: bool = false, total_length: float = -1.0, up_hint: Vector3 = Vector3.UP ) -> Dictionary:` |
| 方法 | [`project_point_to_polyline`](#member-gfcurve3dmath-methods-project_point_to_polyline) | `static func project_point_to_polyline( points: PackedVector3Array, target: Vector3, closed: bool = false, up_hint: Vector3 = Vector3.UP ) -> Dictionary:` |
| 方法 | [`sample_curve`](#member-gfcurve3dmath-methods-sample_curve) | `static func sample_curve(curve: Curve3D, ratio: float, cubic: bool = false) -> Vector3:` |
| 方法 | [`sample_curve_pose`](#member-gfcurve3dmath-methods-sample_curve_pose) | `static func sample_curve_pose( curve: Curve3D, ratio: float, cubic: bool = false, tangent_sample_distance: float = -1.0, up_hint: Vector3 = Vector3.UP ) -> Dictionary:` |

## 方法

<a id="member-gfcurve3dmath-methods-get_polyline_length"></a>

### `get_polyline_length`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func get_polyline_length(points: PackedVector3Array) -> float:
```

计算 3D 折线总长度。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |

返回：折线长度；少于两个点时返回 0。

<a id="member-gfcurve3dmath-methods-sample_polyline"></a>

### `sample_polyline`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sample_polyline( points: PackedVector3Array, ratio: float, total_length: float = -1.0 ) -> Vector3:
```

按 0 到 1 的比例采样 3D 折线。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `total_length` | 可选预计算长度；小于 0 时内部计算。 |

返回：采样点；空折线返回 Vector3.ZERO。

<a id="member-gfcurve3dmath-methods-sample_polyline_pose"></a>

### `sample_polyline_pose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sample_polyline_pose( points: PackedVector3Array, ratio: float, closed: bool = false, total_length: float = -1.0, up_hint: Vector3 = Vector3.UP ) -> Dictionary:
```

按 0 到 1 的比例采样 3D 折线姿态。 该方法返回采样点、路径 offset、当前线段、切线、稳定法线和副法线，适合车辆路径、 轨道、编辑器手柄、预览锚点或网格预处理在项目层组合使用。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `closed` | 是否把末点连回首点；少于三个点时不会追加闭合段。 |
| `total_length` | 可选预计算长度；小于 0 时内部计算。 |
| `up_hint` | 用于构建姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。 |

返回：折线姿态报告。

结构：

- `return`: Dictionary，包含 ok、point、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、tangent、normal、binormal、total_length 和 closed。

<a id="member-gfcurve3dmath-methods-project_point_to_polyline"></a>

### `project_point_to_polyline`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func project_point_to_polyline( points: PackedVector3Array, target: Vector3, closed: bool = false, up_hint: Vector3 = Vector3.UP ) -> Dictionary:
```

计算目标点到 3D 折线的最近投影。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |
| `target` | 要投影到折线上的点。 |
| `closed` | 是否把末点连回首点；少于三个点时不会追加闭合段。 |
| `up_hint` | 用于构建投影姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。 |

返回：最近投影报告。

结构：

- `return`: Dictionary，包含 ok、point、target、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、distance、distance_squared、tangent、normal、binormal、total_length 和 closed。

<a id="member-gfcurve3dmath-methods-sample_curve"></a>

### `sample_curve`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sample_curve(curve: Curve3D, ratio: float, cubic: bool = false) -> Vector3:
```

按 0 到 1 的比例采样 Curve3D 的 baked 路径。

参数：

| 名称 | 说明 |
|---|---|
| `curve` | 目标曲线。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `cubic` | 是否使用 Curve3D.sample_baked() 的三次插值。 |

返回：采样点；曲线为空或无点时返回 Vector3.ZERO。

<a id="member-gfcurve3dmath-methods-sample_curve_pose"></a>

### `sample_curve_pose`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sample_curve_pose( curve: Curve3D, ratio: float, cubic: bool = false, tangent_sample_distance: float = -1.0, up_hint: Vector3 = Vector3.UP ) -> Dictionary:
```

按 0 到 1 的比例采样 Curve3D 的 baked 姿态。

参数：

| 名称 | 说明 |
|---|---|
| `curve` | 目标曲线。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `cubic` | 是否使用 Curve3D.sample_baked() 的三次插值。 |
| `tangent_sample_distance` | 切线估算的前后采样距离；小于等于 0 时使用 bake_interval 或路径长度派生值。 |
| `up_hint` | 用于构建姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。 |

返回：曲线姿态报告。

结构：

- `return`: Dictionary，包含 ok、point、offset、ratio、tangent、normal、binormal 和 total_length。
