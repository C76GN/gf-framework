## GFCollisionNarrowphase2D: 纯 2D 凸形状 SAT 精确重叠测试工具。
##
## 使用 Separating Axis Theorem 检测凸多边形和旋转盒是否重叠，并返回相切、
## 穿透深度、法线和最小平移向量。它只做 narrowphase 几何判定，不维护空间索引、
## 不生成 broadphase 候选对，不执行物理响应、接触点求解、命中分发或玩法规则判断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFCollisionNarrowphase2D
extends RefCounted


# --- 常量 ---

## 凸多边形 shape 类型。
## [br]
## @api public
## [br]
## @since 5.0.0
const SHAPE_POLYGON: StringName = &"polygon"

## 几何重叠。
## [br]
## @api public
## [br]
## @since 5.0.0
const REASON_OVERLAP: StringName = &"overlap"

## 几何分离。
## [br]
## @api public
## [br]
## @since 5.0.0
const REASON_SEPARATED: StringName = &"separated"

## 仅边界相切。
## [br]
## @api public
## [br]
## @since 5.0.0
const REASON_TOUCHING: StringName = &"touching"

## shape 无效或不是凸多边形。
## [br]
## @api public
## [br]
## @since 5.0.0
const REASON_INVALID_SHAPE: StringName = &"invalid_shape"

## 默认浮点容差。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_EPSILON: float = 0.00001


# --- 公共方法 ---

## 创建凸多边形 shape 记录。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param points: 多边形顶点，按顺时针或逆时针顺序排列。
## [br]
## @param transform: 写入 shape 前应用到每个顶点的变换。
## [br]
## @param metadata: 调用方附加元数据；SAT 不解释这些字段。
## [br]
## @return shape 字典。
## [br]
## @schema return: Dictionary with `type: StringName`, `points: PackedVector2Array`, and `metadata: Dictionary`.
## [br]
## @schema metadata: Dictionary caller metadata copied by value.
static func make_polygon(
	points: PackedVector2Array,
	transform: Transform2D = Transform2D.IDENTITY,
	metadata: Dictionary = {}
) -> Dictionary:
	var transformed_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		var _point_appended: bool = transformed_points.append(transform * point)
	return {
		"type": SHAPE_POLYGON,
		"points": transformed_points,
		"metadata": metadata.duplicate(true),
	}


## 创建旋转盒 shape 记录。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param center: 盒中心点。
## [br]
## @param size: 盒尺寸；负尺寸会按绝对值处理。
## [br]
## @param rotation_radians: 盒的旋转角度，单位为弧度。
## [br]
## @param metadata: 调用方附加元数据；SAT 不解释这些字段。
## [br]
## @return shape 字典。
## [br]
## @schema return: Dictionary with `type: StringName`, `points: PackedVector2Array`, and `metadata: Dictionary`.
## [br]
## @schema metadata: Dictionary caller metadata copied by value.
static func make_box(
	center: Vector2,
	size: Vector2,
	rotation_radians: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	var half_size: Vector2 = Vector2(absf(size.x), absf(size.y)) * 0.5
	var local_points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	var transform: Transform2D = Transform2D(rotation_radians, center)
	return make_polygon(local_points, transform, metadata)


## 检查点序列是否构成凸多边形。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param points: 多边形顶点，按顺时针或逆时针顺序排列。
## [br]
## @param epsilon: 浮点容差。
## [br]
## @return 顶点数量充足、面积非零且没有凹角时返回 true。
static func is_convex_polygon(points: PackedVector2Array, epsilon: float = DEFAULT_EPSILON) -> bool:
	var resolved_epsilon: float = maxf(epsilon, 0.0)
	if points.size() < 3:
		return false
	if absf(_signed_polygon_area(points)) <= resolved_epsilon:
		return false

	var winding_sign: int = 0
	for index: int in range(points.size()):
		var previous_point: Vector2 = points[index]
		var current_point: Vector2 = points[(index + 1) % points.size()]
		var next_point: Vector2 = points[(index + 2) % points.size()]
		var cross: float = (current_point - previous_point).cross(next_point - current_point)
		if absf(cross) <= resolved_epsilon:
			continue

		var current_sign: int = 1 if cross > 0.0 else -1
		if winding_sign == 0:
			winding_sign = current_sign
		elif winding_sign != current_sign:
			return false
	return winding_sign != 0


## 把凸多边形投影到轴上。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param points: 多边形顶点。
## [br]
## @param axis: 投影轴；会先归一化。
## [br]
## @return 投影区间。
## [br]
## @schema return: Dictionary with `valid: bool`, `min: float`, `max: float`, and `axis: Vector2`.
static func project_polygon(points: PackedVector2Array, axis: Vector2) -> Dictionary:
	var normalized_axis: Vector2 = axis.normalized()
	if points.size() == 0 or normalized_axis == Vector2.ZERO:
		return _make_projection(false, 0.0, 0.0, Vector2.ZERO)

	var minimum: float = points[0].dot(normalized_axis)
	var maximum: float = minimum
	for index: int in range(1, points.size()):
		var projection: float = points[index].dot(normalized_axis)
		minimum = minf(minimum, projection)
		maximum = maxf(maximum, projection)
	return _make_projection(true, minimum, maximum, normalized_axis)


## 使用 SAT 检查两个凸多边形是否重叠。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param a_points: 第一个凸多边形顶点。
## [br]
## @param b_points: 第二个凸多边形顶点。
## [br]
## @param options: 可选控制，支持 `include_touching` 与 `epsilon`。
## [br]
## @return SAT 重叠报告。
## [br]
## @schema options: Dictionary with optional `include_touching: bool` and `epsilon: float`.
## [br]
## @schema return: Dictionary with `overlap: bool`, `touching: bool`, `reason: StringName`, `penetration_depth: float`, `normal: Vector2`, `minimum_translation: Vector2`, and `axis_count: int`.
static func test_polygon_overlap(
	a_points: PackedVector2Array,
	b_points: PackedVector2Array,
	options: Dictionary = {}
) -> Dictionary:
	var epsilon: float = _get_epsilon(options)
	if not is_convex_polygon(a_points, epsilon) or not is_convex_polygon(b_points, epsilon):
		return _make_result(false, false, REASON_INVALID_SHAPE)

	var axes: PackedVector2Array = _collect_sat_axes(a_points, b_points, epsilon)
	if axes.size() == 0:
		return _make_result(false, false, REASON_INVALID_SHAPE)

	var include_touching: bool = GFVariantData.get_option_bool(options, "include_touching", false)
	var best_axis: Vector2 = Vector2.ZERO
	var minimum_overlap: float = INF
	var touching: bool = false
	for axis: Vector2 in axes:
		var a_projection: Dictionary = project_polygon(a_points, axis)
		var b_projection: Dictionary = project_polygon(b_points, axis)
		var a_minimum: float = GFVariantData.get_option_float(a_projection, "min")
		var a_maximum: float = GFVariantData.get_option_float(a_projection, "max")
		var b_minimum: float = GFVariantData.get_option_float(b_projection, "min")
		var b_maximum: float = GFVariantData.get_option_float(b_projection, "max")
		if a_maximum < b_minimum - epsilon or b_maximum < a_minimum - epsilon:
			return _make_result(false, false, REASON_SEPARATED, 0.0, axis, Vector2.ZERO, axes.size())

		var axis_overlap: float = minf(a_maximum, b_maximum) - maxf(a_minimum, b_minimum)
		if axis_overlap <= epsilon:
			touching = true
			if not include_touching:
				return _make_result(false, true, REASON_TOUCHING, 0.0, axis, Vector2.ZERO, axes.size())
			axis_overlap = 0.0

		if axis_overlap < minimum_overlap:
			minimum_overlap = axis_overlap
			best_axis = axis

	if minimum_overlap == INF:
		minimum_overlap = 0.0
	if best_axis == Vector2.ZERO:
		best_axis = Vector2.RIGHT

	best_axis = _orient_axis_from_a_to_b(best_axis, a_points, b_points)
	var minimum_translation: Vector2 = best_axis * minimum_overlap
	return _make_result(
		true,
		touching,
		REASON_TOUCHING if touching else REASON_OVERLAP,
		minimum_overlap,
		best_axis,
		minimum_translation,
		axes.size()
	)


## 使用 SAT 检查两个 shape 是否重叠。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param a_shape: 第一个 shape，建议由 `make_polygon()` 或 `make_box()` 创建。
## [br]
## @param b_shape: 第二个 shape，建议由 `make_polygon()` 或 `make_box()` 创建。
## [br]
## @param options: 可选控制，支持 `include_touching` 与 `epsilon`。
## [br]
## @return SAT 重叠报告。
## [br]
## @schema a_shape: Dictionary with `type: StringName` and `points: PackedVector2Array`.
## [br]
## @schema b_shape: Dictionary with `type: StringName` and `points: PackedVector2Array`.
## [br]
## @schema options: Dictionary with optional `include_touching: bool` and `epsilon: float`.
## [br]
## @schema return: Dictionary with `overlap: bool`, `touching: bool`, `reason: StringName`, `penetration_depth: float`, `normal: Vector2`, `minimum_translation: Vector2`, and `axis_count: int`.
static func test_shapes_overlap(
	a_shape: Dictionary,
	b_shape: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if (
		GFVariantData.get_option_string_name(a_shape, "type") != SHAPE_POLYGON
		or GFVariantData.get_option_string_name(b_shape, "type") != SHAPE_POLYGON
	):
		return _make_result(false, false, REASON_INVALID_SHAPE)

	return test_polygon_overlap(
		_get_shape_points(a_shape),
		_get_shape_points(b_shape),
		options
	)


# --- 私有/辅助方法 ---

static func _get_epsilon(options: Dictionary) -> float:
	return maxf(GFVariantData.get_option_float(options, "epsilon", DEFAULT_EPSILON), 0.0)


static func _make_projection(valid: bool, minimum: float, maximum: float, axis: Vector2) -> Dictionary:
	return {
		"valid": valid,
		"min": minimum,
		"max": maximum,
		"axis": axis,
	}


static func _make_result(
	overlap: bool,
	touching: bool,
	reason: StringName,
	penetration_depth: float = 0.0,
	normal: Vector2 = Vector2.ZERO,
	minimum_translation: Vector2 = Vector2.ZERO,
	axis_count: int = 0
) -> Dictionary:
	return {
		"overlap": overlap,
		"touching": touching,
		"reason": reason,
		"penetration_depth": penetration_depth,
		"normal": normal,
		"minimum_translation": minimum_translation,
		"axis_count": axis_count,
	}


static func _signed_polygon_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for index: int in range(points.size()):
		var current_point: Vector2 = points[index]
		var next_point: Vector2 = points[(index + 1) % points.size()]
		area += current_point.cross(next_point)
	return area * 0.5


static func _collect_sat_axes(
	a_points: PackedVector2Array,
	b_points: PackedVector2Array,
	epsilon: float
) -> PackedVector2Array:
	var axes: PackedVector2Array = PackedVector2Array()
	_append_polygon_axes(a_points, axes, epsilon)
	_append_polygon_axes(b_points, axes, epsilon)
	return axes


static func _append_polygon_axes(
	points: PackedVector2Array,
	axes: PackedVector2Array,
	epsilon: float
) -> void:
	for index: int in range(points.size()):
		var current_point: Vector2 = points[index]
		var next_point: Vector2 = points[(index + 1) % points.size()]
		var edge: Vector2 = next_point - current_point
		if edge.length_squared() <= epsilon * epsilon:
			continue

		var axis: Vector2 = Vector2(-edge.y, edge.x).normalized()
		if not _has_equivalent_axis(axes, axis, epsilon):
			var _axis_appended: bool = axes.append(axis)


static func _has_equivalent_axis(axes: PackedVector2Array, axis: Vector2, epsilon: float) -> bool:
	for existing_axis: Vector2 in axes:
		if absf(existing_axis.dot(axis)) >= 1.0 - epsilon:
			return true
	return false


static func _orient_axis_from_a_to_b(
	axis: Vector2,
	a_points: PackedVector2Array,
	b_points: PackedVector2Array
) -> Vector2:
	var centroid_delta: Vector2 = _polygon_centroid(b_points) - _polygon_centroid(a_points)
	if centroid_delta.dot(axis) < 0.0:
		return -axis
	return axis


static func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	if points.size() == 0:
		return Vector2.ZERO

	var result: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		result += point
	return result / float(points.size())


static func _get_shape_points(shape: Dictionary) -> PackedVector2Array:
	var points_value: Variant = GFVariantData.get_option_value(shape, "points", PackedVector2Array())
	if points_value is PackedVector2Array:
		var packed_points: PackedVector2Array = points_value
		return packed_points
	if points_value is Array:
		var raw_points: Array = points_value
		var points: PackedVector2Array = PackedVector2Array()
		for point_value: Variant in raw_points:
			if point_value is Vector2:
				var point: Vector2 = point_value
				var _point_appended: bool = points.append(point)
		return points
	return PackedVector2Array()
