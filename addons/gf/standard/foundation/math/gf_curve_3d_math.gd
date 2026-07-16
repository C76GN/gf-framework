## GFCurve3DMath: Curve3D 与 3D 折线的纯算法辅助。
##
## 提供路径长度、归一化采样、姿态报告和最近点投影，
## 不持有节点状态，也不解释车辆、导航、碰撞、渲染或编辑器交互语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFCurve3DMath
extends RefCounted


# --- 常量 ---

const _EPSILON: float = 0.00001
const _EPSILON_SQUARED: float = _EPSILON * _EPSILON


# --- 公共方法 ---

## 计算 3D 折线总长度。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 折线点序列。
## [br]
## @return 折线长度；少于两个点时返回 0。
static func get_polyline_length(points: PackedVector3Array) -> float:
	var length: float = 0.0
	for index: int in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


## 按 0 到 1 的比例采样 3D 折线。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 折线点序列。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param total_length: 可选预计算长度；小于 0 时内部计算。
## [br]
## @return 采样点；空折线返回 Vector3.ZERO。
static func sample_polyline(
	points: PackedVector3Array,
	ratio: float,
	total_length: float = -1.0
) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]

	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	if clamped_ratio <= 0.0:
		return points[0]
	if clamped_ratio >= 1.0:
		return points[points.size() - 1]

	var length: float = total_length if total_length >= 0.0 else get_polyline_length(points)
	if length <= _EPSILON:
		return points[points.size() - 1]

	var target_distance: float = length * clamped_ratio
	var travelled: float = 0.0
	for index: int in range(1, points.size()):
		var from_point: Vector3 = points[index - 1]
		var to_point: Vector3 = points[index]
		var segment_length: float = from_point.distance_to(to_point)
		if segment_length <= _EPSILON:
			continue

		if travelled + segment_length >= target_distance:
			var segment_ratio: float = (target_distance - travelled) / segment_length
			return from_point.lerp(to_point, segment_ratio)
		travelled += segment_length

	return points[points.size() - 1]


## 按 0 到 1 的比例采样 3D 折线姿态。
## [br]
## 该方法返回采样点、路径 offset、当前线段、切线、稳定法线和副法线，适合车辆路径、
## 轨道、编辑器手柄、预览锚点或网格预处理在项目层组合使用。
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
## @param up_hint: 用于构建姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。
## [br]
## @return 折线姿态报告。
## [br]
## @schema return: Dictionary，包含 ok、point、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、tangent、normal、binormal、total_length 和 closed。
static func sample_polyline_pose(
	points: PackedVector3Array,
	ratio: float,
	closed: bool = false,
	total_length: float = -1.0,
	up_hint: Vector3 = Vector3.UP
) -> Dictionary:
	var path_points: PackedVector3Array = _get_polyline_points(points, closed)
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	var report: Dictionary = _make_polyline_pose_report(clamped_ratio, 0.0, closed)
	if path_points.is_empty():
		return report

	report["point"] = path_points[0]
	if path_points.size() == 1:
		return report

	var length: float = total_length if total_length >= 0.0 else get_polyline_length(path_points)
	report["total_length"] = length
	if length <= _EPSILON:
		report["point"] = path_points[path_points.size() - 1]
		return report

	return _sample_polyline_pose_at_distance(
		path_points,
		length * clamped_ratio,
		length,
		clamped_ratio,
		closed,
		up_hint
	)


## 计算目标点到 3D 折线的最近投影。
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
## @param up_hint: 用于构建投影姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。
## [br]
## @return 最近投影报告。
## [br]
## @schema return: Dictionary，包含 ok、point、target、offset、ratio、segment_index、segment_ratio、segment_from、segment_to、distance、distance_squared、tangent、normal、binormal、total_length 和 closed。
static func project_point_to_polyline(
	points: PackedVector3Array,
	target: Vector3,
	closed: bool = false,
	up_hint: Vector3 = Vector3.UP
) -> Dictionary:
	var path_points: PackedVector3Array = _get_polyline_points(points, closed)
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
	if total_length <= _EPSILON:
		report["distance"] = target.distance_to(path_points[0])
		report["distance_squared"] = target.distance_squared_to(path_points[0])
		return report

	var best_report: Dictionary = report
	var best_distance_squared: float = INF
	var travelled: float = 0.0
	for index: int in range(1, path_points.size()):
		var from_point: Vector3 = path_points[index - 1]
		var to_point: Vector3 = path_points[index]
		var segment_vector: Vector3 = to_point - from_point
		var segment_length_squared: float = segment_vector.length_squared()
		if segment_length_squared <= _EPSILON_SQUARED:
			continue

		var segment_length: float = sqrt(segment_length_squared)
		var segment_ratio: float = clampf(
			(target - from_point).dot(segment_vector) / segment_length_squared,
			0.0,
			1.0
		)
		var point: Vector3 = from_point + segment_vector * segment_ratio
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
				closed,
				up_hint
			)
		travelled += segment_length

	return best_report


## 按 0 到 1 的比例采样 Curve3D 的 baked 路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param curve: 目标曲线。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param cubic: 是否使用 Curve3D.sample_baked() 的三次插值。
## [br]
## @return 采样点；曲线为空或无点时返回 Vector3.ZERO。
static func sample_curve(curve: Curve3D, ratio: float, cubic: bool = false) -> Vector3:
	if curve == null:
		return Vector3.ZERO

	var point_count: int = curve.get_point_count()
	if point_count <= 0:
		return Vector3.ZERO
	if point_count == 1:
		return curve.get_point_position(0)
	if not _has_nonzero_curve_anchor_span(curve):
		return curve.get_point_position(point_count - 1)

	var length: float = curve.get_baked_length()
	if length <= _EPSILON:
		return curve.get_point_position(point_count - 1)

	return curve.sample_baked(length * clampf(ratio, 0.0, 1.0), cubic)


## 按 0 到 1 的比例采样 Curve3D 的 baked 姿态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param curve: 目标曲线。
## [br]
## @param ratio: 归一化采样位置；会被限制在 0 到 1。
## [br]
## @param cubic: 是否使用 Curve3D.sample_baked() 的三次插值。
## [br]
## @param tangent_sample_distance: 切线估算的前后采样距离；小于等于 0 时使用 bake_interval 或路径长度派生值。
## [br]
## @param up_hint: 用于构建姿态帧的上方向提示；与切线平行或为零时会使用稳定垂直方向。
## [br]
## @return 曲线姿态报告。
## [br]
## @schema return: Dictionary，包含 ok、point、offset、ratio、tangent、normal、binormal 和 total_length。
static func sample_curve_pose(
	curve: Curve3D,
	ratio: float,
	cubic: bool = false,
	tangent_sample_distance: float = -1.0,
	up_hint: Vector3 = Vector3.UP
) -> Dictionary:
	var clamped_ratio: float = clampf(ratio, 0.0, 1.0)
	var report: Dictionary = _make_curve_pose_report(clamped_ratio, 0.0)
	if curve == null:
		return report

	var point_count: int = curve.get_point_count()
	if point_count <= 0:
		return report

	report["point"] = curve.get_point_position(0)
	if point_count == 1:
		return report
	if not _has_nonzero_curve_anchor_span(curve):
		report["point"] = curve.get_point_position(point_count - 1)
		return report

	var length: float = curve.get_baked_length()
	report["total_length"] = length
	if length <= _EPSILON:
		report["point"] = curve.get_point_position(point_count - 1)
		return report

	var offset: float = length * clamped_ratio
	var point: Vector3 = curve.sample_baked(offset, cubic)
	var tangent: Vector3 = _sample_curve_tangent(
		curve,
		offset,
		length,
		cubic,
		tangent_sample_distance
	)
	if tangent.length_squared() <= _EPSILON_SQUARED:
		tangent = _fallback_curve_tangent_from_points(curve)

	return _make_curve_pose_success_report(point, offset, length, clamped_ratio, tangent, up_hint)


# --- 私有/辅助方法 ---

static func _get_polyline_points(points: PackedVector3Array, closed: bool) -> PackedVector3Array:
	var result: PackedVector3Array = points.duplicate()
	if closed and result.size() > 2 and result[0] != result[result.size() - 1]:
		var _first_point_appended: bool = result.append(result[0])
	return result


static func _has_nonzero_curve_anchor_span(curve: Curve3D) -> bool:
	var point_count: int = curve.get_point_count()
	var first_point: Vector3 = curve.get_point_position(0)
	for index: int in range(1, point_count):
		if first_point.distance_squared_to(curve.get_point_position(index)) > _EPSILON_SQUARED:
			return true
	return false


static func _make_polyline_pose_report(ratio: float, total_length: float, closed: bool) -> Dictionary:
	return {
		"ok": false,
		"point": Vector3.ZERO,
		"offset": 0.0,
		"ratio": ratio,
		"segment_index": -1,
		"segment_ratio": 0.0,
		"segment_from": Vector3.ZERO,
		"segment_to": Vector3.ZERO,
		"tangent": Vector3.ZERO,
		"normal": Vector3.ZERO,
		"binormal": Vector3.ZERO,
		"total_length": total_length,
		"closed": closed,
	}


static func _sample_polyline_pose_at_distance(
	path_points: PackedVector3Array,
	target_distance: float,
	total_length: float,
	ratio: float,
	closed: bool,
	up_hint: Vector3
) -> Dictionary:
	var travelled: float = 0.0
	for index: int in range(1, path_points.size()):
		var from_point: Vector3 = path_points[index - 1]
		var to_point: Vector3 = path_points[index]
		var segment_vector: Vector3 = to_point - from_point
		var segment_length: float = segment_vector.length()
		if segment_length <= _EPSILON:
			continue

		if travelled + segment_length >= target_distance or index == path_points.size() - 1:
			var local_distance: float = clampf(target_distance - travelled, 0.0, segment_length)
			var segment_ratio: float = local_distance / segment_length
			var point: Vector3 = from_point + segment_vector.normalized() * local_distance
			return _make_polyline_pose_success_report(
				point,
				travelled + local_distance,
				total_length,
				ratio,
				index - 1,
				segment_ratio,
				from_point,
				to_point,
				closed,
				up_hint
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
		closed,
		up_hint
	)


static func _make_polyline_pose_success_report(
	point: Vector3,
	offset: float,
	total_length: float,
	ratio: float,
	segment_index: int,
	segment_ratio: float,
	segment_from: Vector3,
	segment_to: Vector3,
	closed: bool,
	up_hint: Vector3
) -> Dictionary:
	var tangent: Vector3 = (segment_to - segment_from).normalized()
	var normal: Vector3 = _make_stable_normal(tangent, up_hint)
	var binormal: Vector3 = _make_stable_binormal(tangent, normal)
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
		"normal": normal,
		"binormal": binormal,
		"total_length": total_length,
		"closed": closed,
	}


static func _make_polyline_projection_report(target: Vector3, closed: bool) -> Dictionary:
	var report: Dictionary = _make_polyline_pose_report(0.0, 0.0, closed)
	report["target"] = target
	report["distance"] = INF
	report["distance_squared"] = INF
	return report


static func _make_polyline_projection_success_report(
	target: Vector3,
	point: Vector3,
	offset: float,
	total_length: float,
	segment_index: int,
	segment_ratio: float,
	segment_from: Vector3,
	segment_to: Vector3,
	distance_squared: float,
	closed: bool,
	up_hint: Vector3
) -> Dictionary:
	var report: Dictionary = _make_polyline_pose_success_report(
		point,
		offset,
		total_length,
		offset / total_length if total_length > _EPSILON else 0.0,
		segment_index,
		segment_ratio,
		segment_from,
		segment_to,
		closed,
		up_hint
	)
	report["target"] = target
	report["distance"] = sqrt(distance_squared)
	report["distance_squared"] = distance_squared
	return report


static func _make_curve_pose_report(ratio: float, total_length: float) -> Dictionary:
	return {
		"ok": false,
		"point": Vector3.ZERO,
		"offset": 0.0,
		"ratio": ratio,
		"tangent": Vector3.ZERO,
		"normal": Vector3.ZERO,
		"binormal": Vector3.ZERO,
		"total_length": total_length,
	}


static func _make_curve_pose_success_report(
	point: Vector3,
	offset: float,
	total_length: float,
	ratio: float,
	tangent: Vector3,
	up_hint: Vector3
) -> Dictionary:
	var normalized_tangent: Vector3 = tangent.normalized()
	var normal: Vector3 = _make_stable_normal(normalized_tangent, up_hint)
	var binormal: Vector3 = _make_stable_binormal(normalized_tangent, normal)
	return {
		"ok": true,
		"point": point,
		"offset": offset,
		"ratio": ratio,
		"tangent": normalized_tangent,
		"normal": normal,
		"binormal": binormal,
		"total_length": total_length,
	}


static func _sample_curve_tangent(
	curve: Curve3D,
	offset: float,
	total_length: float,
	cubic: bool,
	tangent_sample_distance: float
) -> Vector3:
	var sample_distance: float = tangent_sample_distance
	if sample_distance <= _EPSILON:
		sample_distance = maxf(curve.bake_interval, total_length * 0.001)
	sample_distance = clampf(sample_distance, _EPSILON, total_length)

	var before_offset: float = maxf(0.0, offset - sample_distance)
	var after_offset: float = minf(total_length, offset + sample_distance)
	if is_equal_approx(before_offset, after_offset):
		before_offset = maxf(0.0, offset - sample_distance)
		after_offset = minf(total_length, before_offset + sample_distance)

	var before_point: Vector3 = curve.sample_baked(before_offset, cubic)
	var after_point: Vector3 = curve.sample_baked(after_offset, cubic)
	var tangent: Vector3 = after_point - before_point
	if tangent.length_squared() <= _EPSILON_SQUARED:
		return Vector3.ZERO
	return tangent.normalized()


static func _fallback_curve_tangent_from_points(curve: Curve3D) -> Vector3:
	var point_count: int = curve.get_point_count()
	for index: int in range(1, point_count):
		var segment_vector: Vector3 = curve.get_point_position(index) - curve.get_point_position(index - 1)
		if segment_vector.length_squared() > _EPSILON_SQUARED:
			return segment_vector.normalized()
	return Vector3.ZERO


static func _make_stable_normal(tangent: Vector3, up_hint: Vector3) -> Vector3:
	if tangent.length_squared() <= _EPSILON_SQUARED:
		return Vector3.ZERO

	var projected_up: Vector3 = up_hint - tangent * up_hint.dot(tangent)
	if projected_up.length_squared() > _EPSILON_SQUARED:
		return projected_up.normalized()
	return _make_perpendicular_unit(tangent)


static func _make_stable_binormal(tangent: Vector3, normal: Vector3) -> Vector3:
	if tangent.length_squared() <= _EPSILON_SQUARED or normal.length_squared() <= _EPSILON_SQUARED:
		return Vector3.ZERO

	var binormal: Vector3 = tangent.cross(normal)
	if binormal.length_squared() <= _EPSILON_SQUARED:
		return _make_perpendicular_unit(tangent)
	return binormal.normalized()


static func _make_perpendicular_unit(direction: Vector3) -> Vector3:
	var axis: Vector3 = Vector3.RIGHT
	if absf(direction.normalized().dot(axis)) > 0.9:
		axis = Vector3.UP

	var perpendicular: Vector3 = direction.cross(axis)
	if perpendicular.length_squared() <= _EPSILON_SQUARED:
		perpendicular = direction.cross(Vector3.FORWARD)
	if perpendicular.length_squared() <= _EPSILON_SQUARED:
		return Vector3.ZERO
	return perpendicular.normalized()
