# 2D 曲线与折线

`GFCurve2DMath` 提供围绕 `Curve2D` 与 `PackedVector2Array` 的纯算法辅助，适合复用在导入器、编辑器工具、路径预览、轨迹采样、平滑路径生成、折线细分、虚线预处理、路径锚点和 UI/玩法之间的几何预处理。

## 定位

这个工具只处理几何数据本身：折线长度、按归一化比例采样、折线姿态报告、最近点投影、由折线生成平滑 `Curve2D`、折线侧向摆动插值、按最大段长细分、按最小点距简化、按 dash/gap 切出可见线段、闭合多边形圆角化，以及生成闭合矩形或椭圆曲线。它不负责绘制、碰撞、导航、多边形布尔运算、SVG 解析或节点创建。

## 常见流程

```gdscript
var points := PackedVector2Array([
	Vector2(0, 0),
	Vector2(64, 0),
	Vector2(64, 48),
])

var length := GFCurve2DMath.get_polyline_length(points)
var midpoint := GFCurve2DMath.sample_polyline(points, 0.5, length)
var pose := GFCurve2DMath.sample_polyline_pose(points, 0.5)
var projection := GFCurve2DMath.project_point_to_polyline(points, mouse_local_position)
var smooth_curve := GFCurve2DMath.create_smooth_polyline_curve(points, 1.0)
var meandered := GFCurve2DMath.create_meandered_polyline(points, {
	"amplitude": 6.0,
	"points_per_segment": 1,
})
var subdivided := GFCurve2DMath.subdivide_polyline_by_max_segment_length(points, 8.0)
var compact := GFCurve2DMath.simplify_polyline_by_distance(points, 4.0)
var dashed := GFCurve2DMath.make_dashed_polyline_segments(points, 12.0, 6.0)
var rounded := GFCurve2DMath.round_polygon_points(points, 8.0, 6)
```

基础闭合形状可以直接生成，也可以复用已有 `Curve2D`：

```gdscript
var rect_curve := GFCurve2DMath.create_rect_curve(Vector2(128, 64), Vector2(12, 12))
var ellipse_curve := Curve2D.new()
GFCurve2DMath.set_ellipse_curve(ellipse_curve, Vector2(64, 64), Vector2(32, 32))
```

## 在指向处保形切分三次曲线

`project_point_to_cubic_bezier(p0, p1, p2, p3, target, tolerance, max_subdivisions)` 查询同一坐标系中的目标点。`p1` 和 `p2` 是绝对控制点。使用 Godot 的相对控制柄时，分别将出柄加到起点、入柄加到终点。为按像素拾取，可以先把四个点都转换到视口坐标，再将求得的参数传给原坐标系中的切分操作。

```gdscript
var hit := GFCurve2DMath.project_point_to_cubic_bezier(p0, p1, p2, p3, mouse_position, 0.01, 256)
if hit.ok and hit.converged:
    var cut := GFCurve2DMath.split_cubic_bezier(p0, p1, p2, p3, hit.t)
    var left: PackedVector2Array = cut.left
    var right: PackedVector2Array = cut.right
    # left[3] 和 right[0] 是共享锚点，每组四个点保留对应子段的形状。
```

投影以已求值候选到目标的距离作上界，以剩余子段控制点包围盒到目标的距离作下界。`error_bound` 约束所选参数与全局最优参数之间的距离差，单位与输入坐标相同。`converged` 表示达到了指定容差。预算是整次调用的二分次数，范围为 0 至 4096，默认 256，默认距离容差为 0.01。预算为 0 时比较两端点。预算或浮点参数分辨率用尽时，仍可读取最佳已知的 `point`、`t`、`distance` 和实际 `subdivisions`。

投影在目标的局部坐标系中计算。细分保留双精度运算舍入的低位，随后两项大数相消时仍可还原小偏移。`distance` 按曲线在返回参数处的位置求得，`point` 按 Godot 的 `Vector2` 精度输出。因此在大坐标下，即使输出点舍入到目标坐标，仍可能有可测的距离误差。

`t` 是原始三次多项式参数。直线形状的 `x(t) = 100t³` 在长度一半处对应 `t ≈ 0.7937`。自交曲线可能有多个同距解，固定输入及预算使用稳定搜索顺序。四个点重合时取 `t = 0`。切分接受闭区间 [0, 1] 内的有限参数，两端也可切分。两项操作均以 `ok = false` 和 `error` 报告无效输入。

## 使用边界

`sample_curve()` 基于 `Curve2D` 的 baked 路径长度采样，适合运行时取点、预览和轻量工具。需要严格曲线拟合、SVG path 完整导入、拓扑清理或碰撞轮廓生成时，应在项目工具层或专门扩展中实现。

`sample_polyline_pose()` 和 `project_point_to_polyline()` 返回纯数据报告，字段包括 `point`、`offset`、`ratio`、`segment_index`、`segment_ratio`、`tangent`、`normal` 和 `total_length`。这适合把节点挂到路径上、让手柄沿折线移动、计算标签位置或构建编辑器预览；宽度、材质、旋转偏移、碰撞体和节点生命周期仍由调用方处理。

`create_smooth_polyline_curve()` / `set_smooth_polyline_curve()` 使用 Catmull-Rom 风格的相对贝塞尔控制柄，让生成的 `Curve2D` 穿过输入折线点。它适合把手绘轨迹、导入轮廓、路径草图或编辑器画刷点列转换为可编辑曲线；`tension = 0.0` 时只写入无控制柄锚点，`closed = true` 时会去掉输入中重复的末尾首点并追加闭合锚点。

`create_meandered_polyline()` 会在相邻锚点之间插入带侧向偏移的中间点，并返回 `anchor_indices`，让调用方知道每个原始锚点落在输出点列的哪个位置。它适合把路线、拖拽轨迹、视觉连线或预览路径做成更自然的折线，但不会解释路径代表的业务含义。`amplitude` 控制偏移距离，`points_per_segment` 控制每段插入点数，默认会把偏移限制到线段长度的一半以避免短线段过冲；派生点数会在乘法和分配前与 `max_points` 比较，超限时不生成部分点列。需要保持精确中心线、物理路径或导航路径时，应继续使用原始折线。

`subdivide_polyline_by_max_segment_length()` 会在过长线段中插入等距点，并返回 `anchor_indices`，让调用方继续追踪每个原始锚点在输出点列中的位置。它适合导入路径预处理、手绘点列稳定化、视觉连线重采样，以及需要先把链条拆成较短段再交给项目侧算法处理的场景。`closed = true` 时会把末点连回首点，并忽略输入中重复的末尾首点；函数不会执行生长模拟、拓扑合并、曲率保持或最少控制点拟合。

`simplify_polyline_by_distance()` 只按点距过滤，不会进行 Douglas-Peucker、曲率保持或贝塞尔拟合。它的目标是稳定、可预测地减少密集采样点，而不是生成最少控制点。

`make_dashed_polyline_segments()` 返回可见线段数据，每项都是两个点组成的 `PackedVector2Array`。函数会让 dash/gap 相位沿整条折线连续推进，并在折线顶点处拆分线段，避免渲染方把转角连成斜线。它不采样颜色、宽度、材质或动画状态；这些仍由调用方根据自己的绘制方式处理。

`round_polygon_points()` 只返回新的 `PackedVector2Array`，不改写 `Polygon2D`、`CollisionPolygon2D`、`Curve2D` 或材质数据。输入多边形不需要重复末点；如果传入了重复闭合点，函数会先忽略它，再按相邻边长度限制每个顶点的圆角半径。
