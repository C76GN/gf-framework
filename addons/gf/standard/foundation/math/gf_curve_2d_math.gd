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

const _DASH_EPSILON: float = 0.00001
const _DEFAULT_MAX_SUBDIVIDED_POLYLINE_POINTS: int = 8192
const _DEFAULT_MAX_MEANDERED_POLYLINE_POINTS: int = 8192


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
	for index: int in range(1, points.size()):
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

	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return points[0]
	if clamped_ratio >= 1.0:
		return points[points.size() - 1]

	var length: float = total_length if total_length >= 0.0 else get_polyline_length(points)
	if length <= 0.0:
		return points[points.size() - 1]

	var target_distance: float = length * clamped_ratio
	var travelled: float = 0.0
	for index: int in range(1, points.size()):
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
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	var report: Dictionary = _make_polyline_pose_report(clamped_ratio, 0.0, closed)
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
	for index: int in range(1, path_points.size()):
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


## 按 0 到 1 的比例采样 Curve2D 的 baked 路径。
## [br]
## @api public
## [br]
## @param curve: 目标曲线。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param cubic: 是否使用 Curve2D.sample_baked() 的三次插值。
## [br]
## @return 采样点；曲线为空或无点时返回 Vector2.ZERO。
static func sample_curve(curve: Curve2D, ratio: float, cubic: bool = false) -> Vector2:
	if curve == null or curve.point_count <= 0:
		return Vector2.ZERO
	if curve.point_count == 1:
		return curve.get_point_position(0)

	var length: float = curve.get_baked_length()
	if length <= 0.0:
		return curve.get_point_position(curve.point_count - 1)

	return curve.sample_baked(length * clampf(ratio, 0.0, 1.0), cubic)


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
	return set_smooth_polyline_curve(Curve2D.new(), points, tension, closed)


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
			var tangent: Vector2 = _get_smooth_curve_tangent(source_points, index, closed_curve, handle_strength)
			var in_handle: Vector2 = -tangent if index > 0 else Vector2.ZERO
			var out_handle: Vector2 = tangent if index < source_points.size() - 1 or closed_curve else Vector2.ZERO
			target_curve.add_point(source_points[index], in_handle, out_handle)

		if closed_curve:
			var first_tangent: Vector2 = _get_smooth_curve_tangent(source_points, 0, true, handle_strength)
			target_curve.add_point(source_points[0], -first_tangent, Vector2.ZERO)

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
	var amplitude: float = GFVariantData.get_option_float(options, "amplitude", 1.0)
	var points_per_segment: int = maxi(GFVariantData.get_option_int(options, "points_per_segment", 1), 0)
	var start_step: int = GFVariantData.get_option_int(options, "start_step", 0)
	var side: int = _normalize_meander_side(GFVariantData.get_option_int(options, "side", 1))
	var alternate: bool = GFVariantData.get_option_bool(options, "alternate", true)
	var clamp_to_segment: bool = GFVariantData.get_option_bool(options, "clamp_to_segment", true)
	var max_points: int = maxi(
		GFVariantData.get_option_int(options, "max_points", _DEFAULT_MAX_MEANDERED_POLYLINE_POINTS),
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
	if is_nan(amplitude) or is_inf(amplitude) or amplitude < 0.0:
		base_report["error"] = "amplitude must be a finite value greater than or equal to zero."
		return base_report

	for index: int in range(source_count):
		if not _is_finite_vector2(points[index]):
			base_report["error"] = "points must only contain finite Vector2 values."
			return base_report

	var expected_count: int = source_count + (source_count - 1) * points_per_segment
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
		maxi(output_points.size() - source_count, 0),
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
	var closed_option: bool = GFVariantData.get_option_bool(options, "closed", false)
	var max_points: int = maxi(
		GFVariantData.get_option_int(options, "max_points", _DEFAULT_MAX_SUBDIVIDED_POLYLINE_POINTS),
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
	if max_segment_length <= _DASH_EPSILON or is_nan(max_segment_length) or is_inf(max_segment_length):
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
	for segment_index: int in range(1, source_points.size()):
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
	for index: int in range(1, points.size()):
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
		_append_source_polyline_segments(visible_segments, points, closed)
		return visible_segments

	var path_points: PackedVector2Array = _get_polyline_points(points, closed)
	var pattern_length: float = dash_length + normalized_gap_length
	var phase: float = fposmod(offset, pattern_length)
	var in_dash: bool = phase < dash_length
	var phase_remaining: float = dash_length - phase if in_dash else pattern_length - phase

	for index: int in range(1, path_points.size()):
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

			var step_length: float = minf(phase_remaining, segment_length - travelled)
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
	if source_points.size() < 3 or radius <= 0.0 or corner_detail <= 0:
		return source_points

	var result: PackedVector2Array = PackedVector2Array()
	var point_count: int = source_points.size()
	for index: int in range(point_count):
		var point: Vector2 = source_points[index]
		var previous_point: Vector2 = source_points[posmod(index - 1, point_count)]
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
	return set_rect_curve(Curve2D.new(), size, radius, offset, rotation)


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
	var half_size: Vector2 = Vector2(absf(size.x), absf(size.y)) * 0.5
	var clamped_radius: Vector2 = Vector2(
		clampf(absf(radius.x), 0.0, half_size.x),
		clampf(absf(radius.y), 0.0, half_size.y)
	)

	target_curve.set_block_signals(true)
	target_curve.clear_points()
	if half_size.x <= 0.0 or half_size.y <= 0.0:
		target_curve.add_point(offset)
	elif clamped_radius == Vector2.ZERO:
		_add_corner_points(target_curve, half_size, offset, rotation)
	else:
		_add_rounded_rect_points(target_curve, half_size, clamped_radius, offset, rotation)
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
	return set_ellipse_curve(Curve2D.new(), size, offset, rotation)


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
	var radius: Vector2 = Vector2(absf(size.x), absf(size.y)) * 0.5

	target_curve.set_block_signals(true)
	target_curve.clear_points()
	if radius.x <= 0.0 or radius.y <= 0.0:
		target_curve.add_point(offset)
	else:
		_add_ellipse_points(target_curve, radius, offset, rotation)
	target_curve.set_block_signals(false)
	target_curve.changed.emit()
	return target_curve


# --- 私有/辅助方法 ---

static func _add_corner_points(curve: Curve2D, half_size: Vector2, offset: Vector2, rotation: float) -> void:
	var top_left: Vector2 = Vector2(-half_size.x, -half_size.y)
	var top_right: Vector2 = Vector2(half_size.x, -half_size.y)
	var bottom_right: Vector2 = Vector2(half_size.x, half_size.y)
	var bottom_left: Vector2 = Vector2(-half_size.x, half_size.y)
	curve.add_point(_transform_point(top_left, offset, rotation))
	curve.add_point(_transform_point(top_right, offset, rotation))
	curve.add_point(_transform_point(bottom_right, offset, rotation))
	curve.add_point(_transform_point(bottom_left, offset, rotation))
	curve.add_point(_transform_point(top_left, offset, rotation))


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

	_add_transformed_point(curve, Vector2(right - rx, top), Vector2.ZERO, Vector2(ox, 0.0), offset, rotation)
	_add_transformed_point(curve, Vector2(right, top + ry), Vector2(0.0, -oy), Vector2.ZERO, offset, rotation)
	_add_transformed_point(curve, Vector2(right, bottom - ry), Vector2.ZERO, Vector2(0.0, oy), offset, rotation)
	_add_transformed_point(curve, Vector2(right - rx, bottom), Vector2(ox, 0.0), Vector2.ZERO, offset, rotation)
	_add_transformed_point(curve, Vector2(left + rx, bottom), Vector2.ZERO, Vector2(-ox, 0.0), offset, rotation)
	_add_transformed_point(curve, Vector2(left, bottom - ry), Vector2(0.0, oy), Vector2.ZERO, offset, rotation)
	_add_transformed_point(curve, Vector2(left, top + ry), Vector2.ZERO, Vector2(0.0, -oy), offset, rotation)
	_add_transformed_point(curve, Vector2(left + rx, top), Vector2(-ox, 0.0), Vector2.ZERO, offset, rotation)
	_add_transformed_point(curve, Vector2(right - rx, top), Vector2.ZERO, Vector2(ox, 0.0), offset, rotation)


static func _add_ellipse_points(
	curve: Curve2D,
	radius: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	var ox: float = radius.x * CIRCLE_BEZIER_KAPPA
	var oy: float = radius.y * CIRCLE_BEZIER_KAPPA
	_add_transformed_point(curve, Vector2(radius.x, 0.0), Vector2.ZERO, Vector2(0.0, oy), offset, rotation)
	_add_transformed_point(curve, Vector2.ZERO + Vector2(0.0, radius.y), Vector2(ox, 0.0), Vector2(-ox, 0.0), offset, rotation)
	_add_transformed_point(curve, Vector2(-radius.x, 0.0), Vector2(0.0, oy), Vector2(0.0, -oy), offset, rotation)
	_add_transformed_point(curve, Vector2(0.0, -radius.y), Vector2(-ox, 0.0), Vector2(ox, 0.0), offset, rotation)
	_add_transformed_point(curve, Vector2(radius.x, 0.0), Vector2(0.0, -oy), Vector2.ZERO, offset, rotation)


static func _add_transformed_point(
	curve: Curve2D,
	position: Vector2,
	in_handle: Vector2,
	out_handle: Vector2,
	offset: Vector2,
	rotation: float
) -> void:
	curve.add_point(
		_transform_point(position, offset, rotation),
		in_handle.rotated(rotation),
		out_handle.rotated(rotation)
	)


static func _transform_point(point: Vector2, offset: Vector2, rotation: float) -> Vector2:
	return point.rotated(rotation) + offset


static func _get_unclosed_polygon_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if result.size() > 1 and result[0] == result[result.size() - 1]:
		result.remove_at(result.size() - 1)
	return result


static func _get_polyline_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if closed and result.size() > 2 and result[0] != result[result.size() - 1]:
		var _first_point_appended: bool = result.append(result[0])
	return result


static func _get_smooth_curve_source_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if closed and result.size() > 1 and result[0] == result[result.size() - 1]:
		result.remove_at(result.size() - 1)
	return result


static func _get_subdivision_source_points(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if closed and result.size() > 1 and result[0] == result[result.size() - 1]:
		result.remove_at(result.size() - 1)
	return result


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
		previous_point = points[posmod(index - 1, point_count)]
		next_point = points[(index + 1) % point_count]
	else:
		if index > 0:
			previous_point = points[index - 1]
		if index < point_count - 1:
			next_point = points[index + 1]
	return (next_point - previous_point) * (handle_strength / 6.0)


static func _append_source_polyline_segments(
	target: Array[PackedVector2Array],
	points: PackedVector2Array,
	closed: bool
) -> void:
	for index: int in range(1, points.size()):
		_append_visible_polyline_segment(target, points[index - 1], points[index])
	if closed and points.size() > 2:
		_append_visible_polyline_segment(target, points[points.size() - 1], points[0])


static func _append_visible_polyline_segment(
	target: Array[PackedVector2Array],
	from_point: Vector2,
	to_point: Vector2
) -> void:
	if from_point.distance_squared_to(to_point) <= _DASH_EPSILON * _DASH_EPSILON:
		return
	target.append(PackedVector2Array([from_point, to_point]))


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
	if points_per_segment <= 0 or amplitude <= 0.0 or segment_length <= _DASH_EPSILON:
		return

	var tangent: Vector2 = segment_vector / segment_length
	var normal: Vector2 = tangent.orthogonal()
	var offset_amount: float = amplitude
	if clamp_to_segment:
		offset_amount = minf(offset_amount, segment_length * 0.5)

	for point_index: int in range(points_per_segment):
		var local_index: int = point_index + 1
		var ratio: float = float(local_index) / float(points_per_segment + 1)
		var meander_sign: int = _get_meander_sign(start_step + point_index, side, alternate)
		var envelope: float = sin(PI * ratio)
		var point: Vector2 = from_point.lerp(to_point, ratio) + normal * offset_amount * float(meander_sign) * envelope
		var _point_appended: bool = target.append(point)


static func _append_subdivided_segment_points(
	target: PackedVector2Array,
	from_point: Vector2,
	to_point: Vector2,
	max_segment_length: float
) -> void:
	var insert_count: int = _get_subdivision_insert_count(from_point, to_point, max_segment_length)
	if insert_count <= 0:
		return

	for step: int in range(1, insert_count + 1):
		var ratio: float = float(step) / float(insert_count + 1)
		var _point_appended: bool = target.append(from_point.lerp(to_point, ratio))


static func _estimate_subdivided_polyline_point_count(
	points: PackedVector2Array,
	max_segment_length: float,
	closed: bool
) -> int:
	var count: int = points.size()
	for index: int in range(1, points.size()):
		count += _get_subdivision_insert_count(points[index - 1], points[index], max_segment_length)
	if closed and points.size() > 2:
		count += _get_subdivision_insert_count(points[points.size() - 1], points[0], max_segment_length)
	return count


static func _get_subdivision_insert_count(
	from_point: Vector2,
	to_point: Vector2,
	max_segment_length: float
) -> int:
	var segment_length: float = from_point.distance_to(to_point)
	if segment_length <= _DASH_EPSILON or segment_length <= max_segment_length:
		return 0

	var piece_count: int = ceili(segment_length / max_segment_length)
	return maxi(piece_count - 1, 0)


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
		var shared_limit: float = maxf(minf(previous_length, next_length) * 0.5, 0.0)
		previous_distance = minf(radius, shared_limit)
		next_distance = previous_distance
	else:
		previous_distance = minf(radius, maxf(previous_length * 0.5, 0.0))
		next_distance = minf(radius, maxf(next_length * 0.5, 0.0))

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


static func _make_polyline_pose_report(ratio: float, total_length: float, closed: bool) -> Dictionary:
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


static func _sample_polyline_pose_at_distance(
	path_points: PackedVector2Array,
	target_distance: float,
	total_length: float,
	ratio: float,
	closed: bool
) -> Dictionary:
	var travelled: float = 0.0
	for index: int in range(1, path_points.size()):
		var from_point: Vector2 = path_points[index - 1]
		var to_point: Vector2 = path_points[index]
		var segment_vector: Vector2 = to_point - from_point
		var segment_length: float = segment_vector.length()
		if segment_length <= _DASH_EPSILON:
			continue

		if travelled + segment_length >= target_distance or index == path_points.size() - 1:
			var local_distance: float = clampf(target_distance - travelled, 0.0, segment_length)
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
		maxi(path_points.size() - 2, 0),
		1.0,
		path_points[maxi(path_points.size() - 2, 0)],
		path_points[path_points.size() - 1],
		closed
	)


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


static func _make_polyline_projection_report(target: Vector2, closed: bool) -> Dictionary:
	var report: Dictionary = _make_polyline_pose_report(0.0, 0.0, closed)
	report["target"] = target
	report["distance"] = INF
	report["distance_squared"] = INF
	return report


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


static func _normalize_meander_side(side: int) -> int:
	return -1 if side < 0 else 1


static func _get_meander_sign(step_index: int, side: int, alternate: bool) -> int:
	if alternate and posmod(step_index, 2) == 1:
		return -side
	return side


static func _is_finite_vector2(point: Vector2) -> bool:
	return not (
		is_nan(point.x)
		or is_nan(point.y)
		or is_inf(point.x)
		or is_inf(point.y)
	)


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
