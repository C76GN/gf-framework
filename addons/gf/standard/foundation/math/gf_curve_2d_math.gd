## GFCurve2DMath: Curve2D 与折线的纯算法辅助。
##
## 提供路径长度、归一化采样、点距简化、虚线切分和基础闭合形状生成，
## 不持有节点状态，也不解释碰撞、渲染或编辑器交互语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.19.0
class_name GFCurve2DMath
extends RefCounted


# --- 常量 ---

## 圆弧贝塞尔控制点近似系数。
## [br]
## @api public
const CIRCLE_BEZIER_KAPPA: float = 0.5522847498307936

## 折线与路径辅助用于跳过近零长度的阈值。
## [br]
## @api private
const _DASH_EPSILON: float = 0.00001

## 折线细分未指定 max_points 时使用的默认输出点上限。
## [br]
## @api private
const _DEFAULT_MAX_SUBDIVIDED_POLYLINE_POINTS: int = 8192

## 蜿蜒折线未指定 max_points 时使用的默认输出点上限。
## [br]
## @api private
const _DEFAULT_MAX_MEANDERED_POLYLINE_POINTS: int = 8192

## 用于预检整数点数计算的有符号 64 位最大值。
## [br]
## @api private
const _MAX_INT64: int = 9223372036854775807

## 一次三次曲线投影允许的细分次数硬上限。
## [br]
## @api private
const _MAX_CUBIC_SUBDIVISIONS: int = 4096


# --- 公共方法 ---

## 计算折线总长度。
## [br]
## @api public
## [br]
## @param points: 折线点序列。
## [br]
## @return 折线长度；少于两个点时返回 0。
static func get_polyline_length(points: PackedVector2Array) -> float:
	var length: float = 0.0
	for index: int in range(
		1,
		points.size()
	):
		length += points[index - 1].distance_to(points[index])
	return length


## 按 0 到 1 的比例采样折线。
## [br]
## @api public
## [br]
## @param points: 折线点序列。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param total_length: 可选预计算长度；小于 0 时内部计算。
## [br]
## @return 采样点；空折线返回 Vector2.ZERO。
static func sample_polyline(
	points: PackedVector2Array,
	ratio: float,
	total_length: float = -1.0
) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var clamped_ratio: float = clampf(
		ratio,
		0.0,
		1.0
	)
	if clamped_ratio <= 0.0:
		return points[0]
	if clamped_ratio >= 1.0:
		return points[points.size() - 1]

	var length: float = total_length if total_length >= 0.0 else get_polyline_length(points)
	if length <= 0.0:
		return points[points.size() - 1]

	var target_distance: float = length * clamped_ratio
	var travelled: float = 0.0
	for index: int in range(
		1,
		points.size()
	):
		var from_point: Vector2 = points[index - 1]
		var to_point: Vector2 = points[index]
		var segment_length: float = from_point.distance_to(to_point)
		if segment_length <= 0.0:
			continue

		if travelled + segment_length >= target_distance:
			var segment_ratio: float = (target_distance - travelled) / segment_length
			return from_point.lerp(to_point, segment_ratio)
		travelled += segment_length

	return points[points.size() - 1]


## 按 0 到 1 的比例采样折线姿态。
## [br]
## 该方法返回采样点、路径 offset、当前线段、切线和正交法线，适合节点锚点、
## 路径预览、编辑器手柄或轻量轨迹工具在项目层组合使用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 折线点序列。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param closed: 是否把末点连回首点；少于三个点时不会追加闭合段。
## [br]
## @param total_length: 可选预计算长度；小于 0 时内部计算。
## [br]
## @return 折线姿态报告。
## [br]
## @schema return: Dictionary，包含 ok、point、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、tangent、normal、total_length 和 closed。
static func sample_polyline_pose(
	points: PackedVector2Array,
	ratio: float,
	closed: bool = false,
	total_length: float = -1.0
) -> Dictionary:
	var path_points: PackedVector2Array = _get_polyline_points(points, closed)
	var clamped_ratio: float = clampf(
		ratio,
		0.0,
		1.0
	)
	var report: Dictionary = _make_polyline_pose_report(
		clamped_ratio,
		0.0,
		closed
	)
	if path_points.is_empty():
		return report

	report["point"] = path_points[0]
	if path_points.size() == 1:
		return report

	var length: float = total_length if total_length >= 0.0 else get_polyline_length(path_points)
	report["total_length"] = length
	if length <= _DASH_EPSILON:
		report["point"] = path_points[path_points.size() - 1]
		return report

	return _sample_polyline_pose_at_distance(
		path_points,
		length * clamped_ratio,
		length,
		clamped_ratio,
		closed
	)


## 计算目标点到折线的最近投影。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 折线点序列。
## [br]
## @param target: 要投影到折线上的点。
## [br]
## @param closed: 是否把末点连回首点；少于三个点时不会追加闭合段。
## [br]
## @return 最近投影报告。
## [br]
## @schema return: Dictionary，包含 ok、point、target、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、distance、distance_squared、tangent、normal、total_length 和 closed。
static func project_point_to_polyline(
	points: PackedVector2Array,
	target: Vector2,
	closed: bool = false
) -> Dictionary:
	var path_points: PackedVector2Array = _get_polyline_points(points, closed)
	var report: Dictionary = _make_polyline_projection_report(target, closed)
	if path_points.is_empty():
		return report

	report["point"] = path_points[0]
	if path_points.size() == 1:
		report["distance"] = target.distance_to(path_points[0])
		report["distance_squared"] = target.distance_squared_to(path_points[0])
		return report

	var total_length: float = get_polyline_length(path_points)
	report["total_length"] = total_length
	if total_length <= _DASH_EPSILON:
		report["distance"] = target.distance_to(path_points[0])
		report["distance_squared"] = target.distance_squared_to(path_points[0])
		return report

	var best_report: Dictionary = report
	var best_distance_squared: float = INF
	var travelled: float = 0.0
	for index: int in range(
		1,
		path_points.size()
	):
		var from_point: Vector2 = path_points[index - 1]
		var to_point: Vector2 = path_points[index]
		var segment_vector: Vector2 = to_point - from_point
		var segment_length_squared: float = segment_vector.length_squared()
		if segment_length_squared <= _DASH_EPSILON * _DASH_EPSILON:
			continue

		var segment_length: float = sqrt(segment_length_squared)
		var segment_ratio: float = clampf(
			(target - from_point).dot(segment_vector) / segment_length_squared,
			0.0,
			1.0
		)
		var point: Vector2 = from_point + segment_vector * segment_ratio
		var distance_squared: float = target.distance_squared_to(point)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_report = _make_polyline_projection_success_report(
				target,
				point,
				travelled + segment_length * segment_ratio,
				total_length,
				index - 1,
				segment_ratio,
				from_point,
				to_point,
				distance_squared,
				closed
			)
		travelled += segment_length

	return best_report


## 按原始 Bézier 参数切分一段二维三次曲线，返回两组绝对控制点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p0: 起点。
## [br]
## @param p1: 起点一侧的绝对控制点。
## [br]
## @param p2: 终点一侧的绝对控制点。
## [br]
## @param p3: 终点。
## [br]
## @param t: 闭区间 [0, 1] 的有限多项式参数。
## [br]
## @return 两段共享切点。非法输入返回空点列。
## [br]
## @schema return: Dictionary，包含 ok: bool、error: String、left/right: PackedVector2Array，各成功点列依次给出四个控制点。
static func split_cubic_bezier(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	t: float
) -> Dictionary:
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	if (
		not p0.is_finite()
		or not p1.is_finite()
		or not p2.is_finite()
		or not p3.is_finite()
		or not is_finite(t)
		or t < 0.0
		or t > 1.0
	):
		return {
			"ok": false,
			"error": "invalid_input",
			"left": left,
			"right": right,
		}
	var controls: Array[PackedFloat64Array] = _cubic_controls(
		p0,
		p1,
		p2,
		p3
	)
	var split: Array[PackedFloat64Array] = _split_cubic_controls(controls, t)
	for index: int in range(4):
		var at: int = index * 2
		var _left_added: bool = left.append(
			Vector2(
				_cubic_coordinate(split[at]),
				_cubic_coordinate(split[at + 1])
			)
		)
		var _right_added: bool = right.append(
			Vector2(
				_cubic_coordinate(split[at + 6]),
				_cubic_coordinate(split[at + 7])
			)
		)
	return {
		"ok": true,
		"error": "",
		"left": left,
		"right": right,
	}


## 在整段三次曲线上搜索目标的最近参数，容差与输入坐标同单位。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p0: 起点。
## [br]
## @param p1: 起点一侧的绝对控制点。
## [br]
## @param p2: 终点一侧的绝对控制点。
## [br]
## @param p3: 终点。
## [br]
## @param target: 同坐标系的查询点。
## [br]
## @param tolerance: 允许的最近距离误差，须有限且非负。
## [br]
## @param max_subdivisions: 整次搜索最多拆分的区间数，取 0..4096；0 只比较端点和初始下界。
## [br]
## @return 成功时给出曲线上实际求值的候选。预算耗尽仍返回候选并通过 converged 标记是否达到容差。
## [br]
## @schema return: Dictionary，包含 ok/converged: bool、error: String、t/distance/error_bound: float、point: Vector2、subdivisions: int。error_bound 约束距离差；t 是原曲线参数。
static func project_point_to_cubic_bezier(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	target: Vector2,
	tolerance: float = 0.01,
	max_subdivisions: int = 256
) -> Dictionary:
	var report: Dictionary = {
		"ok": false,
		"error": "invalid_input",
		"converged": false,
		"t": 0.0,
		"point": Vector2.ZERO,
		"distance": INF,
		"error_bound": INF,
		"subdivisions": 0,
	}
	if (
		not p0.is_finite()
		or not p1.is_finite()
		or not p2.is_finite()
		or not p3.is_finite()
		or not target.is_finite()
		or not is_finite(tolerance)
		or tolerance < 0.0
		or max_subdivisions < 0
		or max_subdivisions > _MAX_CUBIC_SUBDIVISIONS
	):
		return report
	var controls: Array[PackedFloat64Array] = _cubic_controls(
		p0,
		p1,
		p2,
		p3,
		target
	)
	var best_x: PackedFloat64Array = controls[0]
	var best_y: PackedFloat64Array = controls[1]
	var best_t: float = 0.0
	var best_upper: float = _cubic_candidate_upper(best_x, best_y)
	var end_upper: float = _cubic_candidate_upper(
		controls[6],
		controls[7]
	)
	if end_upper < best_upper:
		best_t = 1.0
		best_x = controls[6]
		best_y = controls[7]
		best_upper = end_upper
	var pending: GFPriorityQueue = GFPriorityQueue.new(false)
	if (
		p0 != p1
		or p1 != p2
		or p2 != p3
	):
		_queue_cubic_interval(
			pending,
			controls,
			0.0,
			1.0,
			best_upper
		)
	var subdivisions: int = 0
	var error_bound: float = _cubic_search_gap(best_upper, pending)
	while error_bound > tolerance and subdivisions < max_subdivisions:
		var interval: Dictionary = GFVariantData.to_dictionary(
			pending.pop(),
			{}
		)
		var segment: Array[PackedFloat64Array] = interval["controls"]
		var start: float = interval["start"]
		var end: float = interval["end"]
		var mid: float = (start + end) * 0.5
		if mid == start or mid == end:
			# 相邻可表示参数不能再分，保留弹出前的全局误差界。
			break
		var split: Array[PackedFloat64Array] = _split_cubic_controls(segment, 0.5)
		var upper: float = _cubic_candidate_upper(
			split[6],
			split[7]
		)
		if (
			upper < best_upper
			or (
				upper == best_upper
				and mid < best_t
			)
		):
			best_t = mid
			best_x = split[6]
			best_y = split[7]
			best_upper = upper
		_queue_cubic_interval(
			pending,
			split.slice(0, 8),
			start,
			mid,
			best_upper
		)
		_queue_cubic_interval(
			pending,
			split.slice(6),
			mid,
			end,
			best_upper
		)
		subdivisions += 1
		error_bound = _cubic_search_gap(best_upper, pending)
	report["ok"] = true
	report["error"] = ""
	report["converged"] = error_bound <= tolerance
	report["t"] = best_t
	report["point"] = Vector2(
		_cubic_coordinate(_cubic_add(best_x, target.x)),
		_cubic_coordinate(_cubic_add(best_y, target.y))
	)
	report["distance"] = _cubic_distance(
		_cubic_coordinate(best_x),
		_cubic_coordinate(best_y)
	)
	report["error_bound"] = error_bound
	report["subdivisions"] = subdivisions
	return report


## 按 0 到 1 的比例采样 Curve2D 的 baked 路径。
## [br]
## @api public
## [br]
## @since 3.19.0
## [br]
## @param curve: 目标曲线。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param cubic: 是否使用 Curve2D.sample_baked() 的三次插值。
## [br]
## @return 采样点；曲线为空或无点时返回 Vector2.ZERO。
static func sample_curve(
	curve: Curve2D,
	ratio: float,
	cubic: bool = false
) -> Vector2:
	if curve == null or curve.point_count <= 0:
		return Vector2.ZERO
	if curve.point_count == 1:
		return curve.get_point_position(0)

	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return curve.get_point_position(curve.point_count - 1)

	return curve.sample_baked(
		length * clampf(
			ratio,
			0.0,
			1.0
		),
		cubic
	)


## 创建平滑穿过折线点的 Curve2D。
## [br]
## 该方法使用 Catmull-Rom 风格的三次贝塞尔相对控制柄生成可编辑曲线，
## 适合把手绘轨迹、导入轮廓或路径草图转换为 Godot Curve2D。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 折线点序列。
## [br]
## @param tension: 控制柄强度；1.0 为标准平滑，0.0 会生成无控制柄折线锚点。
## [br]
## @param closed: 是否生成闭合曲线；少于三个点时按开放曲线处理。
## [br]
## @return 新建的 Curve2D。
static func create_smooth_polyline_curve(
	points: PackedVector2Array,
	tension: float = 1.0,
	closed: bool = false
) -> Curve2D:
	return set_smooth_polyline_curve(
		Curve2D.new(),
		points,
		tension,
		closed
	)


## 将已有 Curve2D 改写为平滑穿过折线点的曲线。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param curve: 要写入的曲线；为空时会创建新曲线。
## [br]
## @param points: 折线点序列。
## [br]
## @param tension: 控制柄强度；1.0 为标准平滑，0.0 会生成无控制柄折线锚点。
## [br]
## @param closed: 是否生成闭合曲线；少于三个点时按开放曲线处理。
## [br]
## @return 写入后的 Curve2D。
static func set_smooth_polyline_curve(
	curve: Curve2D,
	points: PackedVector2Array,
	tension: float = 1.0,
	closed: bool = false
) -> Curve2D:
	var target_curve: Curve2D = curve if curve != null else Curve2D.new()
	var source_points: PackedVector2Array = _get_smooth_curve_source_points(points, closed)
	var closed_curve: bool = closed and source_points.size() > 2
	var handle_strength: float = maxf(tension, 0.0)

	target_curve.set_block_signals(true)
	target_curve.clear_points()
	if source_points.size() == 1:
		target_curve.add_point(source_points[0])
	elif source_points.size() > 1:
		for index: int in range(source_points.size()):
			var tangent: Vector2 = _get_smooth_curve_tangent(
				source_points,
				index,
				closed_curve,
				handle_strength
			)
			var in_handle: Vector2 = -tangent if index > 0 else Vector2.ZERO
			var out_handle: Vector2 = tangent if index < source_points.size() - 1 or closed_curve else Vector2.ZERO
			target_curve.add_point(
				source_points[index],
				in_handle,
				out_handle
			)

		if closed_curve:
			var first_tangent: Vector2 = _get_smooth_curve_tangent(
				source_points,
				0,
				true,
				handle_strength
			)
			target_curve.add_point(
				source_points[0],
				-first_tangent,
				Vector2.ZERO
			)

	target_curve.set_block_signals(false)
	target_curve.changed.emit()
	return target_curve


## 为折线锚点生成带侧向摆动的插值点序列。
## [br]
## 该方法只处理几何数据：输入锚点保持原顺序，输出会保留每个原始锚点
## 在新点列中的索引，便于调用方把 cell id、宽度、标签或其他业务数据
## 按锚点重新关联到生成后的路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 原始折线锚点。
## [br]
## @param options: 生成选项。
## [br]
## @return 蜿蜒折线生成报告。
## [br]
## @schema options: Dictionary，可包含 amplitude: float 侧向偏移量、points_per_segment: int 每段插入点数、start_step: int 起始交替步、side: int 初始侧向符号、alternate: bool 是否按插入点交替左右、clamp_to_segment: bool 是否把偏移限制到线段长度的一半、max_points: int 最大输出点数。
## [br]
## @schema return: Dictionary，包含 ok、error、points、anchor_indices、source_count、point_count、interior_count、amplitude、points_per_segment、start_step、side、alternate、clamp_to_segment 和 max_points。
static func create_meandered_polyline(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
	var source_count: int = points.size()
	var amplitude: float = GFVariantData.get_option_float(
		options,
		"amplitude",
		1.0
	)
	var points_per_segment: int = maxi(
		GFVariantData.get_option_int(
			options,
			"points_per_segment",
			1
		),
		0
	)
	var start_step: int = GFVariantData.get_option_int(
		options,
		"start_step",
		0
	)
	var side: int = _normalize_meander_side(
		GFVariantData.get_option_int(
			options,
			"side",
			1
		)
	)
	var alternate: bool = GFVariantData.get_option_bool(
		options,
		"alternate",
		true
	)
	var clamp_to_segment: bool = GFVariantData.get_option_bool(
		options,
		"clamp_to_segment",
		true
	)
	var max_points: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_points",
			_DEFAULT_MAX_MEANDERED_POLYLINE_POINTS
		),
		1
	)
	var base_report: Dictionary = _make_meandered_polyline_report(
		false,
		"",
		PackedVector2Array(),
		PackedInt32Array(),
		source_count,
		0,
		0,
		amplitude,
		points_per_segment,
		start_step,
		side,
		alternate,
		clamp_to_segment,
		max_points
	)
	if source_count < 2:
		base_report["error"] = "points must contain at least two anchors."
		return base_report
	if (
		is_nan(amplitude)
		or is_inf(amplitude)
		or amplitude < 0.0
	):
		base_report["error"] = "amplitude must be a finite value greater than or equal to zero."
		return base_report

	for index: int in range(source_count):
		if not _is_finite_vector2(points[index]):
			base_report["error"] = "points must only contain finite Vector2 values."
			return base_report

	var segment_count: int = source_count - 1
	if points_per_segment > _divide_truncated(
		_MAX_INT64 - source_count,
		segment_count
	):
		base_report["error"] = "generated point count would exceed max_points."
		base_report["point_count"] = _MAX_INT64
		return base_report

	var expected_count: int = source_count + segment_count * points_per_segment
	if expected_count > max_points:
		base_report["error"] = "generated point count would exceed max_points."
		base_report["point_count"] = expected_count
		return base_report

	var output_points: PackedVector2Array = PackedVector2Array()
	var anchor_indices: PackedInt32Array = PackedInt32Array()
	var _first_anchor_appended: bool = output_points.append(points[0])
	var _first_anchor_index_appended: bool = anchor_indices.append(0)
	for segment_index: int in range(source_count - 1):
		var from_point: Vector2 = points[segment_index]
		var to_point: Vector2 = points[segment_index + 1]
		_append_meandered_segment_points(
			output_points,
			from_point,
			to_point,
			amplitude,
			points_per_segment,
			start_step + segment_index * points_per_segment,
			side,
			alternate,
			clamp_to_segment
		)
		var _anchor_appended: bool = output_points.append(to_point)
		var _anchor_index_appended: bool = anchor_indices.append(output_points.size() - 1)

	return _make_meandered_polyline_report(
		true,
		"",
		output_points,
		anchor_indices,
		source_count,
		output_points.size(),
		maxi(
			output_points.size() - source_count,
			0
		),
		amplitude,
		points_per_segment,
		start_step,
		side,
		alternate,
		clamp_to_segment,
		max_points
	)


## 按最大线段长度自适应细分折线。
## [br]
## 该方法只在线段过长时插入等距中间点，并返回原始锚点在输出点列中的索引。
## 它适合路径导入预处理、手绘曲线稳定化、增长模拟前的链条细分或视觉连线采样。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 原始折线锚点。
## [br]
## @param max_segment_length: 输出中任一非退化线段的最大长度。
## [br]
## @param options: 细分选项。
## [br]
## @schema options: Dictionary，可包含 closed: bool 是否把末点连回首点、max_points: int 最大输出点数。
## [br]
## @return 细分报告。
## [br]
## @schema return: Dictionary，包含 ok、error、points、anchor_indices、source_count、point_count、inserted_count、max_segment_length、closed 和 max_points。
static func subdivide_polyline_by_max_segment_length(
	points: PackedVector2Array,
	max_segment_length: float,
	options: Dictionary = {}
) -> Dictionary:
	var closed_option: bool = GFVariantData.get_option_bool(
		options,
		"closed",
		false
	)
	var max_points: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_points",
			_DEFAULT_MAX_SUBDIVIDED_POLYLINE_POINTS
		),
		1
	)
	var source_points: PackedVector2Array = _get_subdivision_source_points(points, closed_option)
	var closed_path: bool = closed_option and source_points.size() > 2
	var base_report: Dictionary = _make_subdivided_polyline_report(
		false,
		"",
		PackedVector2Array(),
		PackedInt32Array(),
		source_points.size(),
		0,
		0,
		max_segment_length,
		closed_path,
		max_points
	)
	if source_points.size() < 2:
		base_report["error"] = "points must contain at least two anchors."
		return base_report
	if (
		max_segment_length <= _DASH_EPSILON
		or is_nan(max_segment_length)
		or is_inf(max_segment_length)
	):
		base_report["error"] = "max_segment_length must be a finite positive value."
		return base_report

	for index: int in range(source_points.size()):
		if not _is_finite_vector2(source_points[index]):
			base_report["error"] = "points must only contain finite Vector2 values."
			return base_report

	var expected_count: int = _estimate_subdivided_polyline_point_count(
		source_points,
		max_segment_length,
		closed_path
	)
	if expected_count > max_points:
		base_report["error"] = "generated point count would exceed max_points."
		base_report["point_count"] = expected_count
		return base_report

	var output_points: PackedVector2Array = PackedVector2Array()
	var anchor_indices: PackedInt32Array = PackedInt32Array()
	var _first_anchor_appended: bool = output_points.append(source_points[0])
	var _first_anchor_index_appended: bool = anchor_indices.append(0)
	for segment_index: int in range(
		1,
		source_points.size()
	):
		_append_subdivided_segment_points(
			output_points,
			source_points[segment_index - 1],
			source_points[segment_index],
			max_segment_length
		)
		var _anchor_appended: bool = output_points.append(source_points[segment_index])
		var _anchor_index_appended: bool = anchor_indices.append(output_points.size() - 1)

	if closed_path:
		_append_subdivided_segment_points(
			output_points,
			source_points[source_points.size() - 1],
			source_points[0],
			max_segment_length
		)

	return _make_subdivided_polyline_report(
		true,
		"",
		output_points,
		anchor_indices,
		source_points.size(),
		output_points.size(),
		output_points.size() - source_points.size(),
		max_segment_length,
		closed_path,
		max_points
	)


## 按最小点距简化折线，适合压缩手绘、采样或导入得到的密集点。
## [br]
## @api public
## [br]
## @param points: 原始折线点序列。
## [br]
## @param min_distance: 相邻保留点的最小距离；小于等于 0 时返回原始副本。
## [br]
## @param keep_last: 是否始终保留末点。
## [br]
## @return 简化后的折线点序列。
static func simplify_polyline_by_distance(
	points: PackedVector2Array,
	min_distance: float,
	keep_last: bool = true
) -> PackedVector2Array:
	if points.size() <= 2 or min_distance <= 0.0:
		return points.duplicate()

	var simplified: PackedVector2Array = PackedVector2Array()
	var _first_point_appended: bool = simplified.append(points[0])
	var min_distance_squared: float = min_distance * min_distance
	for index: int in range(
		1,
		points.size()
	):
		if points[index].distance_squared_to(simplified[simplified.size() - 1]) >= min_distance_squared:
			var _point_appended: bool = simplified.append(points[index])

	var last_point: Vector2 = points[points.size() - 1]
	if keep_last and simplified[simplified.size() - 1] != last_point:
		var _last_point_appended: bool = simplified.append(last_point)
	return simplified


## 按 dash/gap 模式把折线切分为可见线段。
## [br]
## @api public
## [br]
## @param points: 折线点序列。
## [br]
## @param dash_length: 每段可见长度；小于等于 0 或接近 0 时返回空数组。
## [br]
## @param gap_length: 每段间隔长度；小于等于 0 或接近 0 时返回原折线的非零长度段。
## [br]
## @param closed: 是否把末点连回首点；少于三个点时不会追加闭合段。
## [br]
## @param offset: 沿路径推进 dash/gap 模式的偏移距离，可用于滚动或动画。
## [br]
## @return 可见线段数组；每项是包含起点和终点的 PackedVector2Array。
## [br]
## @schema return: Array[PackedVector2Array]，每项包含 from/to 两个 Vector2，顶点处会拆分以避免跨角连线。
static func make_dashed_polyline_segments(
	points: PackedVector2Array,
	dash_length: float,
	gap_length: float,
	closed: bool = false,
	offset: float = 0.0
) -> Array[PackedVector2Array]:
	var visible_segments: Array[PackedVector2Array] = []
	if points.size() < 2 or dash_length <= _DASH_EPSILON:
		return visible_segments

	var normalized_gap_length: float = maxf(gap_length, 0.0)
	if normalized_gap_length <= _DASH_EPSILON:
		_append_source_polyline_segments(
			visible_segments,
			points,
			closed
		)
		return visible_segments

	var path_points: PackedVector2Array = _get_polyline_points(points, closed)
	var pattern_length: float = dash_length + normalized_gap_length
	var phase: float = fposmod(offset, pattern_length)
	var in_dash: bool = phase < dash_length
	var phase_remaining: float = dash_length - phase if in_dash else pattern_length - phase

	for index: int in range(
		1,
		path_points.size()
	):
		var from_point: Vector2 = path_points[index - 1]
		var to_point: Vector2 = path_points[index]
		var segment_vector: Vector2 = to_point - from_point
		var segment_length: float = segment_vector.length()
		if segment_length <= _DASH_EPSILON:
			continue

		var segment_direction: Vector2 = segment_vector / segment_length
		var travelled: float = 0.0
		while travelled < segment_length - _DASH_EPSILON:
			if phase_remaining <= _DASH_EPSILON:
				in_dash = not in_dash
				phase_remaining = dash_length if in_dash else normalized_gap_length
				continue

			var step_length: float = minf(
				phase_remaining,
				segment_length - travelled
			)
			if step_length <= _DASH_EPSILON:
				break

			if in_dash:
				_append_visible_polyline_segment(
					visible_segments,
					from_point + segment_direction * travelled,
					from_point + segment_direction * (travelled + step_length)
				)
			travelled += step_length
			phase_remaining -= step_length

	return visible_segments


## 为闭合多边形生成圆角点序列。
## [br]
## @api public
## [br]
## @param points: 多边形顶点序列；不要求末点重复，若末点重复会忽略。
## [br]
## @param radius: 每个顶点两侧的圆角裁切距离；会按相邻边长度限制。
## [br]
## @param corner_detail: 每个圆角的细分数量；1 表示只输出两侧锚点。
## [br]
## @param uniform_corners: 是否用相邻两边的较短可用距离统一限制圆角。
## [br]
## @return 圆角化后的多边形点序列；无效输入会返回去除重复末点后的原始点副本。
static func round_polygon_points(
	points: PackedVector2Array,
	radius: float,
	corner_detail: int = 8,
	uniform_corners: bool = true
) -> PackedVector2Array:
	var source_points: PackedVector2Array = _get_unclosed_polygon_points(points)
	if (
		source_points.size() < 3
		or radius <= 0.0
		or corner_detail <= 0
	):
		return source_points

	var result: PackedVector2Array = PackedVector2Array()
	var point_count: int = source_points.size()
	for index: int in range(point_count):
		var point: Vector2 = source_points[index]
		var previous_point: Vector2 = source_points[
			posmod(
				index - 1,
				point_count
			)
		]
		var next_point: Vector2 = source_points[(index + 1) % point_count]
		_append_rounded_polygon_corner(
			result,
			point,
			previous_point,
			next_point,
			radius,
			corner_detail,
			uniform_corners
		)
	return result


## 创建闭合矩形 Curve2D。
## [br]
## @api public
## [br]
## @param size: 矩形尺寸。
## [br]
## @param radius: 圆角半径；会限制到尺寸的一半。
## [br]
## @param offset: 曲线中心偏移。
## [br]
## @param rotation: 曲线旋转弧度。
## [br]
## @return 新建的 Curve2D。
static func create_rect_curve(
	size: Vector2,
	radius: Vector2 = Vector2.ZERO,
	offset: Vector2 = Vector2.ZERO,
	rotation: float = 0.0
) -> Curve2D:
	return set_rect_curve(
		Curve2D.new(),
		size,
		radius,
		offset,
		rotation
	)


## 将已有 Curve2D 改写为闭合矩形。
## [br]
## @api public
## [br]
## @param curve: 要写入的曲线；为空时会创建新曲线。
## [br]
## @param size: 矩形尺寸。
## [br]
## @param radius: 圆角半径；会限制到尺寸的一半。
## [br]
## @param offset: 曲线中心偏移。
## [br]
## @param rotation: 曲线旋转弧度。
## [br]
## @return 写入后的 Curve2D。
static func set_rect_curve(
	curve: Curve2D,
	size: Vector2,
	radius: Vector2 = Vector2.ZERO,
	offset: Vector2 = Vector2.ZERO,
	rotation: float = 0.0
) -> Curve2D:
	var target_curve: Curve2D = curve if curve != null else Curve2D.new()
	var half_size: Vector2 = Vector2(
		absf(size.x),
		absf(size.y)
	) * 0.5
	var clamped_radius: Vector2 = Vector2(
		clampf(
			absf(radius.x),
			0.0,
			half_size.x
		),
		clampf(
			absf(radius.y),
			0.0,
			half_size.y
		)
	)

	target_curve.set_block_signals(true)
	target_curve.clear_points()
	if half_size.x <= 0.0 or half_size.y <= 0.0:
		target_curve.add_point(offset)
	elif clamped_radius == Vector2.ZERO:
		_add_corner_points(
			target_curve,
			half_size,
			offset,
			rotation
		)
	else:
		_add_rounded_rect_points(
			target_curve,
			half_size,
			clamped_radius,
			offset,
			rotation
		)
	target_curve.set_block_signals(false)
	target_curve.changed.emit()
	return target_curve


## 创建闭合椭圆 Curve2D。
## [br]
## @api public
## [br]
## @param size: 椭圆外接框尺寸。
## [br]
## @param offset: 曲线中心偏移。
## [br]
## @param rotation: 曲线旋转弧度。
## [br]
## @return 新建的 Curve2D。
static func create_ellipse_curve(
	size: Vector2,
	offset: Vector2 = Vector2.ZERO,
	rotation: float = 0.0
) -> Curve2D:
	return set_ellipse_curve(
		Curve2D.new(),
		size,
		offset,
		rotation
	)


## 将已有 Curve2D 改写为闭合椭圆。
## [br]
## @api public
## [br]
## @param curve: 要写入的曲线；为空时会创建新曲线。
## [br]
## @param size: 椭圆外接框尺寸。
## [br]
## @param offset: 曲线中心偏移。
## [br]
## @param rotation: 曲线旋转弧度。
## [br]
## @return 写入后的 Curve2D。
static func set_ellipse_curve(
	curve: Curve2D,
	size: Vector2,
	offset: Vector2 = Vector2.ZERO,
	rotation: float = 0.0
) -> Curve2D:
	var target_curve: Curve2D = curve if curve != null else Curve2D.new()
	var radius: Vector2 = Vector2(
		absf(size.x),
		absf(size.y)
	) * 0.5

	target_curve.set_block_signals(true)
	target_curve.clear_points()
	if radius.x <= 0.0 or radius.y <= 0.0:
		target_curve.add_point(offset)
	else:
		_add_ellipse_points(
			target_curve,
			radius,
			offset,
			rotation
		)
	target_curve.set_block_signals(false)
	target_curve.changed.emit()
	return target_curve


# --- 私有/辅助方法 ---

## 按旋转与偏移写入矩形四角，并重复首点闭合曲线。
## [br]
## @api private
static func _add_corner_points(
	curve: Curve2D,
	half_size: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	var top_left: Vector2 = Vector2(-half_size.x, -half_size.y)
	var top_right: Vector2 = Vector2(half_size.x, -half_size.y)
	var bottom_right: Vector2 = Vector2(half_size.x, half_size.y)
	var bottom_left: Vector2 = Vector2(-half_size.x, half_size.y)
	curve.add_point(
		_transform_point(
			top_left,
			offset,
			rotation
		)
	)
	curve.add_point(
		_transform_point(
			top_right,
			offset,
			rotation
		)
	)
	curve.add_point(
		_transform_point(
			bottom_right,
			offset,
			rotation
		)
	)
	curve.add_point(
		_transform_point(
			bottom_left,
			offset,
			rotation
		)
	)
	curve.add_point(
		_transform_point(
			top_left,
			offset,
			rotation
		)
	)


## 用圆弧近似控制柄写入圆角矩形各段，最后重复首点闭合曲线。
## [br]
## @api private
static func _add_rounded_rect_points(
	curve: Curve2D,
	half_size: Vector2,
	radius: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	var left: float = -half_size.x
	var right: float = half_size.x
	var top: float = -half_size.y
	var bottom: float = half_size.y
	var rx: float = radius.x
	var ry: float = radius.y
	var ox: float = rx * CIRCLE_BEZIER_KAPPA
	var oy: float = ry * CIRCLE_BEZIER_KAPPA

	_add_transformed_point(
		curve,
		Vector2(
			right - rx,
			top
		),
		Vector2.ZERO,
		Vector2(ox, 0.0),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			right,
			top + ry
		),
		Vector2(0.0, -oy),
		Vector2.ZERO,
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			right,
			bottom - ry
		),
		Vector2.ZERO,
		Vector2(0.0, oy),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			right - rx,
			bottom
		),
		Vector2(ox, 0.0),
		Vector2.ZERO,
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			left + rx,
			bottom
		),
		Vector2.ZERO,
		Vector2(-ox, 0.0),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			left,
			bottom - ry
		),
		Vector2(0.0, oy),
		Vector2.ZERO,
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			left,
			top + ry
		),
		Vector2.ZERO,
		Vector2(0.0, -oy),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			left + rx,
			top
		),
		Vector2(-ox, 0.0),
		Vector2.ZERO,
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(
			right - rx,
			top
		),
		Vector2.ZERO,
		Vector2(ox, 0.0),
		offset,
		rotation
	)


## 以四段三次贝塞尔圆弧近似椭圆，并重复首点闭合曲线。
## [br]
## @api private
static func _add_ellipse_points(
	curve: Curve2D,
	radius: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	var ox: float = radius.x * CIRCLE_BEZIER_KAPPA
	var oy: float = radius.y * CIRCLE_BEZIER_KAPPA
	_add_transformed_point(
		curve,
		Vector2(radius.x, 0.0),
		Vector2.ZERO,
		Vector2(0.0, oy),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2.ZERO + Vector2(0.0, radius.y),
		Vector2(ox, 0.0),
		Vector2(-ox, 0.0),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(-radius.x, 0.0),
		Vector2(0.0, oy),
		Vector2(0.0, -oy),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(0.0, -radius.y),
		Vector2(-ox, 0.0),
		Vector2(ox, 0.0),
		offset,
		rotation
	)
	_add_transformed_point(
		curve,
		Vector2(radius.x, 0.0),
		Vector2(0.0, -oy),
		Vector2.ZERO,
		offset,
		rotation
	)


## 将点位置与相对控制柄按旋转、偏移变换后追加到 Curve2D。
## [br]
## @api private
static func _add_transformed_point(
	curve: Curve2D,
	position: Vector2,
	in_handle: Vector2,
	out_handle: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	curve.add_point(
		_transform_point(
			position,
			offset,
			rotation
		),
		in_handle.rotated(rotation),
		out_handle.rotated(rotation)
	)


## 先旋转点，再加上位置偏移。
## [br]
## @api private
static func _transform_point(
	point: Vector2,
	offset: Vector2,
	rotation: float
) -> Vector2:
	return point.rotated(rotation) + offset


## 复制顶点数组，并在末点重复首点时移除该闭合副本。
## [br]
## @api private
static func _get_unclosed_polygon_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if result.size() > 1 and result[0] == result[result.size() - 1]:
		result.remove_at(result.size() - 1)
	return result


## 复制折线点列；闭合且至少三个点时，必要时追加首点形成闭合线段。
## [br]
## @api private
static func _get_polyline_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if (
		closed
		and result.size() > 2
		and result[0] != result[result.size() - 1]
	):
		var _first_point_appended: bool = result.append(result[0])
	return result


## 复制平滑曲线输入，并在闭合模式下移除重复的末尾首点。
## [br]
## @api private
static func _get_smooth_curve_source_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if (
		closed
		and result.size() > 1
		and result[0] == result[result.size() - 1]
	):
		result.remove_at(result.size() - 1)
	return result


## 复制细分输入，并在闭合模式下移除重复的末尾首点。
## [br]
## @api private
static func _get_subdivision_source_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if (
		closed
		and result.size() > 1
		and result[0] == result[result.size() - 1]
	):
		result.remove_at(result.size() - 1)
	return result


## 按开放端点或闭合邻点差计算节点的相对平滑控制柄。
## [br]
## @api private
static func _get_smooth_curve_tangent(
	points: PackedVector2Array,
	index: int,
	closed: bool,
	handle_strength: float
) -> Vector2:
	var point_count: int = points.size()
	var previous_point: Vector2 = points[index]
	var next_point: Vector2 = points[index]
	if closed:
		previous_point = points[
			posmod(
				index - 1,
				point_count
			)
		]
		next_point = points[(index + 1) % point_count]
	else:
		if index > 0:
			previous_point = points[index - 1]
		if index < point_count - 1:
			next_point = points[index + 1]
	return (next_point - previous_point) * (handle_strength / 6.0)


## 将源折线的非零相邻线段追加到结果，并按条件加入闭合边。
## [br]
## @api private
static func _append_source_polyline_segments(
	target: Array[PackedVector2Array],
	points: PackedVector2Array,
	closed: bool
) -> void:
	for index: int in range(
		1,
		points.size()
	):
		_append_visible_polyline_segment(
			target,
			points[index - 1],
			points[index]
		)
	if closed and points.size() > 2:
		_append_visible_polyline_segment(
			target,
			points[points.size() - 1],
			points[0]
		)


## 跳过近零线段，否则追加仅含起点和终点的折线段。
## [br]
## @api private
static func _append_visible_polyline_segment(
	target: Array[PackedVector2Array],
	from_point: Vector2,
	to_point: Vector2
) -> void:
	if from_point.distance_squared_to(to_point) <= _DASH_EPSILON * _DASH_EPSILON:
		return
	target.append(PackedVector2Array([from_point, to_point]))


## 沿单段等距插入侧向摆动点，并可将偏移限制为段长的一半。
## [br]
## @api private
static func _append_meandered_segment_points(
	target: PackedVector2Array,
	from_point: Vector2,
	to_point: Vector2,
	amplitude: float,
	points_per_segment: int,
	start_step: int,
	side: int,
	alternate: bool,
	clamp_to_segment: bool
) -> void:
	var segment_vector: Vector2 = to_point - from_point
	var segment_length: float = segment_vector.length()
	if (
		points_per_segment <= 0
		or amplitude <= 0.0
		or segment_length <= _DASH_EPSILON
	):
		return

	var tangent: Vector2 = segment_vector / segment_length
	var normal: Vector2 = tangent.orthogonal()
	var offset_amount: float = amplitude
	if clamp_to_segment:
		offset_amount = minf(
			offset_amount,
			segment_length * 0.5
		)

	for point_index: int in range(points_per_segment):
		var local_index: int = point_index + 1
		var ratio: float = float(local_index) / float(points_per_segment + 1)
		var meander_sign: int = _get_meander_sign(
			start_step + point_index,
			side,
			alternate
		)
		var envelope: float = sin(PI * ratio)
		var point: Vector2 = from_point.lerp(to_point, ratio) + normal * offset_amount * float(meander_sign) * envelope
		var _point_appended: bool = target.append(point)


## 按细分插入数在单段内部追加等距线性插值点。
## [br]
## @api private
static func _append_subdivided_segment_points(
	target: PackedVector2Array,
	from_point: Vector2,
	to_point: Vector2,
	max_segment_length: float
) -> void:
	var insert_count: int = _get_subdivision_insert_count(
		from_point,
		to_point,
		max_segment_length
	)
	if insert_count <= 0:
		return

	for step: int in range(
		1,
		insert_count + 1
	):
		var ratio: float = float(step) / float(insert_count + 1)
		var _point_appended: bool = target.append(from_point.lerp(to_point, ratio))


## 预估开放或闭合细分路径的输出点总数，包含各段待插入点。
## [br]
## @api private
static func _estimate_subdivided_polyline_point_count(
	points: PackedVector2Array,
	max_segment_length: float,
	closed: bool
) -> int:
	var count: int = points.size()
	for index: int in range(
		1,
		points.size()
	):
		count += _get_subdivision_insert_count(
			points[index - 1],
			points[index],
			max_segment_length
		)
	if closed and points.size() > 2:
		count += _get_subdivision_insert_count(
			points[points.size() - 1],
			points[0],
			max_segment_length
		)
	return count


## 返回超过长度上限的线段需要插入的内部点数。
## [br]
## @api private
static func _get_subdivision_insert_count(
	from_point: Vector2,
	to_point: Vector2,
	max_segment_length: float
) -> int:
	var segment_length: float = from_point.distance_to(to_point)
	if segment_length <= _DASH_EPSILON or segment_length <= max_segment_length:
		return 0

	var piece_count: int = ceili(segment_length / max_segment_length)
	return maxi(
		piece_count - 1,
		0
	)


## 按相邻边长限制圆角锚点，并在两锚点之间追加三次贝塞尔采样点。
## [br]
## @api private
static func _append_rounded_polygon_corner(
	target: PackedVector2Array,
	point: Vector2,
	previous_point: Vector2,
	next_point: Vector2,
	radius: float,
	corner_detail: int,
	uniform_corners: bool
) -> void:
	var previous_length: float = point.distance_to(previous_point)
	var next_length: float = point.distance_to(next_point)
	if previous_length <= 0.0 or next_length <= 0.0:
		var _point_appended: bool = target.append(point)
		return

	var previous_distance: float = radius
	var next_distance: float = radius
	if uniform_corners:
		var shared_limit: float = maxf(
			minf(previous_length, next_length) * 0.5,
			0.0
		)
		previous_distance = minf(radius, shared_limit)
		next_distance = previous_distance
	else:
		previous_distance = minf(
			radius,
			maxf(
				previous_length * 0.5,
				0.0
			)
		)
		next_distance = minf(
			radius,
			maxf(
				next_length * 0.5,
				0.0
			)
		)

	if previous_distance <= 0.0 or next_distance <= 0.0:
		var _point_appended: bool = target.append(point)
		return

	var anchor_previous: Vector2 = point + point.direction_to(previous_point) * previous_distance
	var anchor_next: Vector2 = point + point.direction_to(next_point) * next_distance
	var _previous_appended: bool = target.append(anchor_previous)
	for step: int in range(1, corner_detail):
		var ratio: float = float(step) / float(corner_detail)
		var corner_point: Vector2 = anchor_previous.bezier_interpolate(
			point.lerp(anchor_previous, 0.5),
			point.lerp(anchor_next, 0.5),
			anchor_next,
			ratio
		)
		var _corner_appended: bool = target.append(corner_point)
	var _next_appended: bool = target.append(anchor_next)


## 创建失败态姿态报告，并初始化点、段、切线及法线字段。
## [br]
## @api private
static func _make_polyline_pose_report(
	ratio: float,
	total_length: float,
	closed: bool
) -> Dictionary:
	return {
		"ok": false,
		"point": Vector2.ZERO,
		"offset": 0.0,
		"ratio": ratio,
		"segment_index": -1,
		"segment_ratio": 0.0,
		"segment_from": Vector2.ZERO,
		"segment_to": Vector2.ZERO,
		"tangent": Vector2.ZERO,
		"normal": Vector2.ZERO,
		"total_length": total_length,
		"closed": closed,
	}


## 沿累计弧长定位线段并组装对应采样姿态；跳过近零线段。
## [br]
## @api private
static func _sample_polyline_pose_at_distance(
	path_points: PackedVector2Array,
	target_distance: float,
	total_length: float,
	ratio: float,
	closed: bool
) -> Dictionary:
	var travelled: float = 0.0
	for index: int in range(
		1,
		path_points.size()
	):
		var from_point: Vector2 = path_points[index - 1]
		var to_point: Vector2 = path_points[index]
		var segment_vector: Vector2 = to_point - from_point
		var segment_length: float = segment_vector.length()
		if segment_length <= _DASH_EPSILON:
			continue

		if travelled + segment_length >= target_distance or index == path_points.size() - 1:
			var local_distance: float = clampf(
				target_distance - travelled,
				0.0,
				segment_length
			)
			var segment_ratio: float = local_distance / segment_length
			var point: Vector2 = from_point + segment_vector.normalized() * local_distance
			return _make_polyline_pose_success_report(
				point,
				travelled + local_distance,
				total_length,
				ratio,
				index - 1,
				segment_ratio,
				from_point,
				to_point,
				closed
			)
		travelled += segment_length

	return _make_polyline_pose_success_report(
		path_points[path_points.size() - 1],
		total_length,
		total_length,
		ratio,
		maxi(
			path_points.size() - 2,
			0
		),
		1.0,
		path_points[
			maxi(
				path_points.size() - 2,
				0
			)
		],
		path_points[path_points.size() - 1],
		closed
	)


## 组装成功姿态报告，并由所在段方向计算单位切线与正交法线。
## [br]
## @api private
static func _make_polyline_pose_success_report(
	point: Vector2,
	offset: float,
	total_length: float,
	ratio: float,
	segment_index: int,
	segment_ratio: float,
	segment_from: Vector2,
	segment_to: Vector2,
	closed: bool
) -> Dictionary:
	var tangent: Vector2 = (segment_to - segment_from).normalized()
	return {
		"ok": true,
		"point": point,
		"offset": offset,
		"ratio": ratio,
		"segment_index": segment_index,
		"segment_ratio": segment_ratio,
		"segment_from": segment_from,
		"segment_to": segment_to,
		"tangent": tangent,
		"normal": tangent.orthogonal(),
		"total_length": total_length,
		"closed": closed,
	}


## 创建投影搜索的初始失败报告，并写入目标点和无限初始距离。
## [br]
## @api private
static func _make_polyline_projection_report(target: Vector2, closed: bool) -> Dictionary:
	var report: Dictionary = _make_polyline_pose_report(
		0.0,
		0.0,
		closed
	)
	report["target"] = target
	report["distance"] = INF
	report["distance_squared"] = INF
	return report


## 在姿态成功报告上补入投影目标及距离和平方距离。
## [br]
## @api private
static func _make_polyline_projection_success_report(
	target: Vector2,
	point: Vector2,
	offset: float,
	total_length: float,
	segment_index: int,
	segment_ratio: float,
	segment_from: Vector2,
	segment_to: Vector2,
	distance_squared: float,
	closed: bool
) -> Dictionary:
	var report: Dictionary = _make_polyline_pose_success_report(
		point,
		offset,
		total_length,
		offset / total_length if total_length > _DASH_EPSILON else 0.0,
		segment_index,
		segment_ratio,
		segment_from,
		segment_to,
		closed
	)
	report["target"] = target
	report["distance"] = sqrt(distance_squared)
	report["distance_squared"] = distance_squared
	return report


## 将负侧向归一为 -1，其余输入归一为 1。
## [br]
## @api private
static func _normalize_meander_side(side: int) -> int:
	return -1 if side < 0 else 1


## 在交替模式下按步数奇偶翻转侧向符号。
## [br]
## @api private
static func _get_meander_sign(
	step_index: int,
	side: int,
	alternate: bool
) -> int:
	if alternate and posmod(step_index, 2) == 1:
		return -side
	return side


## 执行整数除法，供生成点数上限的溢出预检使用。
## [br]
## @api private
static func _divide_truncated(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return numerator / denominator


## 各坐标使用由小到大、有效位不重叠的浮点展开。投影在目标局部坐标系中进行。
## [br]
## @api private
static func _cubic_controls(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	origin: Vector2 = Vector2.ZERO
) -> Array[PackedFloat64Array]:
	var controls: Array[PackedFloat64Array] = []
	for point: Vector2 in [
		p0,
		p1,
		p2,
		p3,
	]:
		controls.append(
			_cubic_add(
				PackedFloat64Array([point.x]),
				-origin.x
			)
		)
		controls.append(
			_cubic_add(
				PackedFloat64Array([point.y]),
				-origin.y
			)
		)
	return controls


## 用 TwoSum 逐项加一个标量；高位舍入掉的低位保留下来，随后发生相消时仍能恢复。
## [br]
## @api private
static func _cubic_add(parts: PackedFloat64Array, term: float) -> PackedFloat64Array:
	if term == 0.0:
		return parts
	var result: PackedFloat64Array = PackedFloat64Array()
	var carry: float = term
	for part: float in parts:
		var total: float = carry + part
		var virtual_part: float = total - carry
		var remainder: float = (carry - (total - virtual_part)) + (part - virtual_part)
		if remainder != 0.0:
			var _kept: bool = result.append(remainder)
		carry = total
	if carry != 0.0 or result.is_empty():
		var _last: bool = result.append(carry)
	return result


## 中点只需相加后按二的幂缩放。其余参数用 a + t(b-a)，通过 Dekker 乘积分解保留低位。
## [br]
## @api private
static func _cubic_lerp(
	a: PackedFloat64Array,
	b: PackedFloat64Array,
	t: float
) -> PackedFloat64Array:
	if t == 0.0:
		return a
	if t == 1.0:
		return b
	if t > 0.5:
		return _cubic_lerp(
			b,
			a,
			1.0 - t
		)
	if t == 0.5:
		var added: PackedFloat64Array = a
		for term: float in b:
			added = _cubic_add(added, term)
		var half: PackedFloat64Array = added.duplicate()
		for index: int in range(half.size()):
			half[index] *= 0.5
		return half
	var delta: PackedFloat64Array = b
	for term: float in a:
		delta = _cubic_add(delta, -term)
	var t_high: float = _cubic_high_part(t)
	var t_low: float = t - t_high
	var result: PackedFloat64Array = a
	for term: float in delta:
		var term_high: float = _cubic_high_part(term)
		var term_low: float = term - term_high
		var product: float = term * t
		var remainder: float = term_low * t_low - (((product - term_high * t_high) - term_low * t_high) - term_high * t_low)
		result = _cubic_add(
			_cubic_add(result, remainder),
			product
		)
	return result


## 用 2^27 + 1 将 binary64 尾数拆成两个可精确相乘的部分。
## [br]
## @api private
static func _cubic_high_part(value: float) -> float:
	var scaled: float = 134217729.0 * value
	return scaled - (scaled - value)


## De Casteljau 三角形的外侧依次给出两段控制点，共享切点只保留一份。
## [br]
## @api private
static func _split_cubic_controls(controls: Array[PackedFloat64Array], t: float) -> Array[PackedFloat64Array]:
	var split: Array[PackedFloat64Array] = []
	var _resized: int = split.resize(14)
	var row: Array[PackedFloat64Array] = controls
	for level: int in range(4):
		var last: int = row.size() - 2
		for axis: int in range(2):
			split[2 * level + axis] = row[axis]
			split[12 - 2 * level + axis] = row[last + axis]
		var next_row: Array[PackedFloat64Array] = []
		for index: int in range(last):
			next_row.append(
				_cubic_lerp(
					row[index],
					row[index + 2],
					t
				)
			)
		row = next_row
	return split


## 从低到高累加展开。默认返回有符号坐标，方向 −1/+1 返回其绝对值的下界/上界。
## 求界时累积每次 TwoSum 的实际舍入余量，避免大数相消后高位仍含大量尾零。
## [br]
## @api private
static func _cubic_coordinate(parts: PackedFloat64Array, direction: int = 0) -> float:
	var value: float = parts[0]
	var uncertainty: float = 0.0
	for index: int in range(
		1,
		parts.size()
	):
		var part: float = parts[index]
		var total: float = part + value
		if direction != 0:
			var virtual_value: float = total - part
			var remainder: float = (part - (total - virtual_value)) + (value - virtual_value)
			if remainder != 0.0:
				uncertainty += absf(remainder)
				uncertainty += uncertainty * 2.220446049250313e-16
		value = total
	if direction == 0:
		return value
	if uncertainty == 0.0:
		return absf(value)
	var bound: float = absf(value) + float(direction) * uncertainty
	return maxf(
		0.0,
		bound + float(direction) * absf(bound) * 2.220446049250313e-16
	)


## 缩放后求二范数；轴上距离精确，其余按 direction 向外覆盖舍入误差。
## [br]
## @api private
static func _cubic_distance(
	dx: float,
	dy: float,
	direction: int = 0
) -> float:
	var larger: float = maxf(
		absf(dx),
		absf(dy)
	)
	var smaller: float = minf(
		absf(dx),
		absf(dy)
	)
	if smaller == 0.0:
		return larger
	var ratio: float = smaller / larger
	var length: float = larger * sqrt(1.0 + ratio * ratio)
	return length + float(direction) * length * 8.881784197001252e-16


## 已求值参数到目标的距离上界，用来判断何时可以结束搜索。
## [br]
## @api private
static func _cubic_candidate_upper(x: PackedFloat64Array, y: PackedFloat64Array) -> float:
	return _cubic_distance(
		_cubic_coordinate(x, 1),
		_cubic_coordinate(y, 1),
		1
	)


## 计算原点到控制点包围盒在单个坐标轴上的距离下界。
## [br]
## @api private
static func _cubic_axis_gap(controls: Array[PackedFloat64Array], axis: int) -> float:
	var side: float = signf(_cubic_coordinate(controls[axis]))
	var gap: float = INF
	for index: int in range(
		axis,
		controls.size(),
		2
	):
		var parts: PackedFloat64Array = controls[index]
		if side == 0.0 or signf(_cubic_coordinate(parts)) != side:
			return 0.0
		gap = minf(
			gap,
			_cubic_coordinate(parts, -1)
		)
	return gap


## 以未剪枝区间的最小下界估计全局距离差，并将差值向上取界。
## [br]
## @api private
static func _cubic_search_gap(upper: float, pending: GFPriorityQueue) -> float:
	var lower: float = minf(
		upper,
		pending.peek_priority(upper)
	)
	return _cubic_coordinate(
		_cubic_add(
			PackedFloat64Array([upper]),
			-lower
		),
		1
	)


## 控制点凸包覆盖整段曲线，盒到查询原点的保守距离用于优先遍历和区间剪枝。
## [br]
## @api private
static func _queue_cubic_interval(
	pending: GFPriorityQueue,
	controls: Array[PackedFloat64Array],
	start: float,
	end: float,
	best_upper: float
) -> void:
	var lower: float = _cubic_distance(
		_cubic_axis_gap(controls, 0),
		_cubic_axis_gap(controls, 1),
		-1
	)
	if lower < best_upper:
		var _queued: bool = pending.push(
			{
				"controls": controls,
				"start": start,
				"end": end,
			},
			lower
		)


## 当 Vector2 任一分量为 NaN 或无穷大时返回 false。
## [br]
## @api private
static func _is_finite_vector2(point: Vector2) -> bool:
	return not (
		is_nan(point.x)
		or is_nan(point.y)
		or is_inf(point.x)
		or is_inf(point.y)
	)


## 组装蜿蜒折线结果与其输入、输出数量和生成选项字段。
## [br]
## @api private
static func _make_meandered_polyline_report(
	ok: bool,
	error: String,
	points: PackedVector2Array,
	anchor_indices: PackedInt32Array,
	source_count: int,
	point_count: int,
	interior_count: int,
	amplitude: float,
	points_per_segment: int,
	start_step: int,
	side: int,
	alternate: bool,
	clamp_to_segment: bool,
	max_points: int
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"points": points,
		"anchor_indices": anchor_indices,
		"source_count": source_count,
		"point_count": point_count,
		"interior_count": interior_count,
		"amplitude": amplitude,
		"points_per_segment": points_per_segment,
		"start_step": start_step,
		"side": side,
		"alternate": alternate,
		"clamp_to_segment": clamp_to_segment,
		"max_points": max_points,
	}


## 组装折线细分结果与其输入、输出数量和限制字段。
## [br]
## @api private
static func _make_subdivided_polyline_report(
	ok: bool,
	error: String,
	points: PackedVector2Array,
	anchor_indices: PackedInt32Array,
	source_count: int,
	point_count: int,
	inserted_count: int,
	max_segment_length: float,
	closed: bool,
	max_points: int
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"points": points,
		"anchor_indices": anchor_indices,
		"source_count": source_count,
		"point_count": point_count,
		"inserted_count": inserted_count,
		"max_segment_length": max_segment_length,
		"closed": closed,
		"max_points": max_points,
	}
