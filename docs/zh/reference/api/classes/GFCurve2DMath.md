# GFCurve2DMath

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_curve_2d_math.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.19.0`

Curve2D 与折线的纯算法辅助。 提供路径长度、归一化采样、点距简化、虚线切分和基础闭合形状生成， 不持有节点状态，也不解释碰撞、渲染或编辑器交互语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`CIRCLE_BEZIER_KAPPA`](#member-gfcurve2dmath-constants-circle_bezier_kappa) | `const CIRCLE_BEZIER_KAPPA: float = 0.5522847498307936` |
| 方法 | [`get_polyline_length`](#member-gfcurve2dmath-methods-get_polyline_length) | `static func get_polyline_length(points: PackedVector2Array) -> float:` |
| 方法 | [`sample_polyline`](#member-gfcurve2dmath-methods-sample_polyline) | `static func sample_polyline( points: PackedVector2Array, ratio: float, total_length: float = -1.0 ) -> Vector2:` |
| 方法 | [`sample_curve`](#member-gfcurve2dmath-methods-sample_curve) | `static func sample_curve(curve: Curve2D, ratio: float, cubic: bool = false) -> Vector2:` |
| 方法 | [`simplify_polyline_by_distance`](#member-gfcurve2dmath-methods-simplify_polyline_by_distance) | `static func simplify_polyline_by_distance( points: PackedVector2Array, min_distance: float, keep_last: bool = true ) -> PackedVector2Array:` |
| 方法 | [`make_dashed_polyline_segments`](#member-gfcurve2dmath-methods-make_dashed_polyline_segments) | `static func make_dashed_polyline_segments( points: PackedVector2Array, dash_length: float, gap_length: float, closed: bool = false, offset: float = 0.0 ) -> Array[PackedVector2Array]:` |
| 方法 | [`round_polygon_points`](#member-gfcurve2dmath-methods-round_polygon_points) | `static func round_polygon_points( points: PackedVector2Array, radius: float, corner_detail: int = 8, uniform_corners: bool = true ) -> PackedVector2Array:` |
| 方法 | [`create_rect_curve`](#member-gfcurve2dmath-methods-create_rect_curve) | `static func create_rect_curve( size: Vector2, radius: Vector2 = Vector2.ZERO, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:` |
| 方法 | [`set_rect_curve`](#member-gfcurve2dmath-methods-set_rect_curve) | `static func set_rect_curve( curve: Curve2D, size: Vector2, radius: Vector2 = Vector2.ZERO, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:` |
| 方法 | [`create_ellipse_curve`](#member-gfcurve2dmath-methods-create_ellipse_curve) | `static func create_ellipse_curve( size: Vector2, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:` |
| 方法 | [`set_ellipse_curve`](#member-gfcurve2dmath-methods-set_ellipse_curve) | `static func set_ellipse_curve( curve: Curve2D, size: Vector2, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:` |

## 常量

<a id="member-gfcurve2dmath-constants-circle_bezier_kappa"></a>

### `CIRCLE_BEZIER_KAPPA`

- API：`public`

```gdscript
const CIRCLE_BEZIER_KAPPA: float = 0.5522847498307936
```

圆弧贝塞尔控制点近似系数。

## 方法

<a id="member-gfcurve2dmath-methods-get_polyline_length"></a>

### `get_polyline_length`

- API：`public`

```gdscript
static func get_polyline_length(points: PackedVector2Array) -> float:
```

计算折线总长度。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |

返回：折线长度；少于两个点时返回 0。

<a id="member-gfcurve2dmath-methods-sample_polyline"></a>

### `sample_polyline`

- API：`public`

```gdscript
static func sample_polyline( points: PackedVector2Array, ratio: float, total_length: float = -1.0 ) -> Vector2:
```

按 0 到 1 的比例采样折线。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `total_length` | 可选预计算长度；小于 0 时内部计算。 |

返回：采样点；空折线返回 Vector2.ZERO。

<a id="member-gfcurve2dmath-methods-sample_curve"></a>

### `sample_curve`

- API：`public`

```gdscript
static func sample_curve(curve: Curve2D, ratio: float, cubic: bool = false) -> Vector2:
```

按 0 到 1 的比例采样 Curve2D 的 baked 路径。

参数：

| 名称 | 说明 |
|---|---|
| `curve` | 目标曲线。 |
| `ratio` | 归一化采样位置；会被限制在 0 到 1。 |
| `cubic` | 是否使用 Curve2D.sample_baked() 的三次插值。 |

返回：采样点；曲线为空或无点时返回 Vector2.ZERO。

<a id="member-gfcurve2dmath-methods-simplify_polyline_by_distance"></a>

### `simplify_polyline_by_distance`

- API：`public`

```gdscript
static func simplify_polyline_by_distance( points: PackedVector2Array, min_distance: float, keep_last: bool = true ) -> PackedVector2Array:
```

按最小点距简化折线，适合压缩手绘、采样或导入得到的密集点。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 原始折线点序列。 |
| `min_distance` | 相邻保留点的最小距离；小于等于 0 时返回原始副本。 |
| `keep_last` | 是否始终保留末点。 |

返回：简化后的折线点序列。

<a id="member-gfcurve2dmath-methods-make_dashed_polyline_segments"></a>

### `make_dashed_polyline_segments`

- API：`public`

```gdscript
static func make_dashed_polyline_segments( points: PackedVector2Array, dash_length: float, gap_length: float, closed: bool = false, offset: float = 0.0 ) -> Array[PackedVector2Array]:
```

按 dash/gap 模式把折线切分为可见线段。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 折线点序列。 |
| `dash_length` | 每段可见长度；小于等于 0 或接近 0 时返回空数组。 |
| `gap_length` | 每段间隔长度；小于等于 0 或接近 0 时返回原折线的非零长度段。 |
| `closed` | 是否把末点连回首点；少于三个点时不会追加闭合段。 |
| `offset` | 沿路径推进 dash/gap 模式的偏移距离，可用于滚动或动画。 |

返回：可见线段数组；每项是包含起点和终点的 PackedVector2Array。

结构：

- `return`: Array[PackedVector2Array]，每项包含 from/to 两个 Vector2，顶点处会拆分以避免跨角连线。

<a id="member-gfcurve2dmath-methods-round_polygon_points"></a>

### `round_polygon_points`

- API：`public`

```gdscript
static func round_polygon_points( points: PackedVector2Array, radius: float, corner_detail: int = 8, uniform_corners: bool = true ) -> PackedVector2Array:
```

为闭合多边形生成圆角点序列。

参数：

| 名称 | 说明 |
|---|---|
| `points` | 多边形顶点序列；不要求末点重复，若末点重复会忽略。 |
| `radius` | 每个顶点两侧的圆角裁切距离；会按相邻边长度限制。 |
| `corner_detail` | 每个圆角的细分数量；1 表示只输出两侧锚点。 |
| `uniform_corners` | 是否用相邻两边的较短可用距离统一限制圆角。 |

返回：圆角化后的多边形点序列；无效输入会返回去除重复末点后的原始点副本。

<a id="member-gfcurve2dmath-methods-create_rect_curve"></a>

### `create_rect_curve`

- API：`public`

```gdscript
static func create_rect_curve( size: Vector2, radius: Vector2 = Vector2.ZERO, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:
```

创建闭合矩形 Curve2D。

参数：

| 名称 | 说明 |
|---|---|
| `size` | 矩形尺寸。 |
| `radius` | 圆角半径；会限制到尺寸的一半。 |
| `offset` | 曲线中心偏移。 |
| `rotation` | 曲线旋转弧度。 |

返回：新建的 Curve2D。

<a id="member-gfcurve2dmath-methods-set_rect_curve"></a>

### `set_rect_curve`

- API：`public`

```gdscript
static func set_rect_curve( curve: Curve2D, size: Vector2, radius: Vector2 = Vector2.ZERO, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:
```

将已有 Curve2D 改写为闭合矩形。

参数：

| 名称 | 说明 |
|---|---|
| `curve` | 要写入的曲线；为空时会创建新曲线。 |
| `size` | 矩形尺寸。 |
| `radius` | 圆角半径；会限制到尺寸的一半。 |
| `offset` | 曲线中心偏移。 |
| `rotation` | 曲线旋转弧度。 |

返回：写入后的 Curve2D。

<a id="member-gfcurve2dmath-methods-create_ellipse_curve"></a>

### `create_ellipse_curve`

- API：`public`

```gdscript
static func create_ellipse_curve( size: Vector2, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:
```

创建闭合椭圆 Curve2D。

参数：

| 名称 | 说明 |
|---|---|
| `size` | 椭圆外接框尺寸。 |
| `offset` | 曲线中心偏移。 |
| `rotation` | 曲线旋转弧度。 |

返回：新建的 Curve2D。

<a id="member-gfcurve2dmath-methods-set_ellipse_curve"></a>

### `set_ellipse_curve`

- API：`public`

```gdscript
static func set_ellipse_curve( curve: Curve2D, size: Vector2, offset: Vector2 = Vector2.ZERO, rotation: float = 0.0 ) -> Curve2D:
```

将已有 Curve2D 改写为闭合椭圆。

参数：

| 名称 | 说明 |
|---|---|
| `curve` | 要写入的曲线；为空时会创建新曲线。 |
| `size` | 椭圆外接框尺寸。 |
| `offset` | 曲线中心偏移。 |
| `rotation` | 曲线旋转弧度。 |

返回：写入后的 Curve2D。
