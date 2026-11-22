## GFVoronoi2D: 通用二维 Delaunay 三角剖分与 Voronoi 图计算工具。
##
## 输入为纯 Vector2 点集，输出结构化 Dictionary 数据。工具不生成 Mesh、Node、场景、
## 地形、材质或编辑器交互，项目层负责解释点和多边形的业务含义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFVoronoi2D
extends RefCounted


# --- 常量 ---

## 默认浮点容差。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_EPSILON: float = 0.000001

## 默认最大输入点数，用于避免误把实时大批量数据交给 O(n²) 纯 GDScript 计算。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_POINTS: int = 512


# --- 公共方法 ---

## 基于点集生成 Delaunay 三角剖分。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param points: 输入点集。
## [br]
## @param options: 可选参数，支持 epsilon 和 max_points。
## [br]
## @return 结构化三角剖分结果。
## [br]
## @schema options: Dictionary with optional epsilon: float and max_points: int.
## [br]
## @schema return: Dictionary with ok: bool, error: String, input_point_count: int, point_count: int, duplicate_count: int, points: PackedVector2Array, triangles: Array[PackedInt32Array], and edges: Array[PackedInt32Array].
static func build_delaunay(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
	var settings: Dictionary = _get_settings(options)
	var epsilon: float = GFVariantData.get_option_float(
		settings,
		"epsilon",
		DEFAULT_EPSILON
	)
	var normalized_result: Dictionary = _normalize_points(points, epsilon)
	if not GFVariantData.get_option_bool(
		normalized_result,
		"ok",
		false
	):
		return _make_failure_result(
			points.size(),
			GFVariantData.get_option_string(
				normalized_result,
				"error",
				""
			)
		)

	var normalized_points: PackedVector2Array = _get_packed_vector2_array(normalized_result, "points")
	var max_points: int = GFVariantData.get_option_int(
		settings,
		"max_points",
		DEFAULT_MAX_POINTS
	)
	if normalized_points.size() > max_points:
		return _make_failure_result(
			points.size(),
			"point_count exceeds max_points."
		)

	var triangles: Array[PackedInt32Array] = _build_delaunay_triangles(normalized_points, epsilon)
	var edges: Array[PackedInt32Array] = _collect_edges(triangles)
	return {
		"ok": true,
		"error": "",
		"input_point_count": points.size(),
		"point_count": normalized_points.size(),
		"duplicate_count": GFVariantData.get_option_int(
			normalized_result,
			"duplicate_count",
			0
		),
		"points": normalized_points,
		"triangles": triangles,
		"edges": edges,
	}


## 基于点集生成 Voronoi 图。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param points: 输入点集。
## [br]
## @param options: 可选参数，支持 epsilon 和 max_points。
## [br]
## @return 结构化 Voronoi 结果。
## [br]
## @schema options: Dictionary with optional epsilon: float and max_points: int.
## [br]
## @schema return: Dictionary with Delaunay fields plus vertices: PackedVector2Array and cells: Array[Dictionary]. Each cell contains point_index: int, point: Vector2, vertex_indices: PackedInt32Array, polygon: PackedVector2Array, and is_open: bool.
static func build_voronoi(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
	var delaunay: Dictionary = build_delaunay(points, options)
	if not GFVariantData.get_option_bool(
		delaunay,
		"ok",
		false
	):
		delaunay["vertices"] = PackedVector2Array()
		delaunay["cells"] = []
		return delaunay

	var epsilon: float = _get_epsilon(options)
	var normalized_points: PackedVector2Array = _get_packed_vector2_array(delaunay, "points")
	var triangles: Array[PackedInt32Array] = _get_triangle_array(delaunay)
	var vertices: PackedVector2Array = _make_voronoi_vertices(
		normalized_points,
		triangles,
		epsilon
	)
	var hull_points: Dictionary = _collect_hull_point_flags(triangles)
	var cells: Array[Dictionary] = _make_voronoi_cells(
		normalized_points,
		triangles,
		vertices,
		hull_points
	)

	delaunay["vertices"] = vertices
	delaunay["cells"] = cells
	return delaunay


# --- 私有/辅助方法 ---

## 组装 epsilon 与最大点数组成的规范化设置。
## [br]
## @api private
## [br]
static func _get_settings(options: Dictionary) -> Dictionary:
	return {
		"epsilon": _get_epsilon(options),
		"max_points": maxi(
			GFVariantData.get_option_int(
				options,
				"max_points",
				DEFAULT_MAX_POINTS
			),
			0
		),
	}


## 返回有限绝对容差，并将其下限限制为默认 epsilon。
## [br]
## @api private
## [br]
static func _get_epsilon(options: Dictionary) -> float:
	var epsilon: float = absf(
		GFVariantData.get_option_float(
			options,
			"epsilon",
			DEFAULT_EPSILON
		)
	)
	if is_nan(epsilon) or is_inf(epsilon):
		return DEFAULT_EPSILON
	return maxf(epsilon, DEFAULT_EPSILON)


## 拒绝非有限点，按 epsilon 量化坐标去重并按 X/Y 顺序规范化点集。
## [br]
## @api private
## [br]
static func _normalize_points(points: PackedVector2Array, epsilon: float) -> Dictionary:
	var normalized: PackedVector2Array = PackedVector2Array()
	var seen: Dictionary = {}
	var duplicate_count: int = 0
	var scale: float = 1.0 / epsilon
	for point: Vector2 in points:
		if not _is_finite_point(point):
			return {
				"ok": false,
				"error": "points must contain finite Vector2 values.",
				"points": PackedVector2Array(),
				"duplicate_count": duplicate_count,
			}

		var quantized_key: Vector2i = Vector2i(
			roundi(point.x * scale),
			roundi(point.y * scale)
		)
		if seen.has(quantized_key):
			duplicate_count += 1
			continue

		seen[quantized_key] = true
		var _point_appended: bool = normalized.append(point)

	var sorted_points: Array[Vector2] = []
	for point: Vector2 in normalized:
		sorted_points.append(point)
	sorted_points.sort_custom(_compare_points)
	return {
		"ok": true,
		"error": "",
		"points": PackedVector2Array(sorted_points),
		"duplicate_count": duplicate_count,
	}


## 使用包含全部输入点的超级三角形逐点插入并整理输出三角形索引。
## [br]
## @api private
## [br]
static func _build_delaunay_triangles(points: PackedVector2Array, epsilon: float) -> Array[PackedInt32Array]:
	if points.size() < 3:
		return []

	var super_points: PackedVector2Array = _make_super_triangle(points)
	var working_points: PackedVector2Array = points.duplicate()
	var _super_a_appended: bool = working_points.append(super_points[0])
	var _super_b_appended: bool = working_points.append(super_points[1])
	var _super_c_appended: bool = working_points.append(super_points[2])

	var super_a: int = points.size()
	var super_b: int = points.size() + 1
	var super_c: int = points.size() + 2
	var first_triangle: Dictionary = _make_triangle(
		super_a,
		super_b,
		super_c,
		working_points,
		epsilon
	)
	if first_triangle.is_empty():
		return []

	# X 近似相等的点按 Y 排序，实际插入顺序的 X 可能局部回退。
	var remaining_min_x: PackedFloat64Array = PackedFloat64Array()
	var _resize_result: int = remaining_min_x.resize(points.size())
	var minimum_x: float = INF
	for index: int in range(
		points.size() - 1,
		-1,
		-1
	):
		minimum_x = minf(
			minimum_x,
			points[index].x
		)
		remaining_min_x[index] = minimum_x

	var active: Array[Dictionary] = [first_triangle]
	var finished: Array[Dictionary] = []
	for point_index: int in range(points.size()):
		_insert_point(
			active,
			finished,
			working_points,
			point_index,
			remaining_min_x[point_index],
			epsilon
		)

	finished.append_array(active)
	var result: Array[PackedInt32Array] = []
	var seen: Dictionary[Vector3i, bool] = {}
	for triangle: Dictionary in finished:
		var indices: PackedInt32Array = triangle["indices"]
		if (
			indices[0] >= points.size()
			or indices[1] >= points.size()
			or indices[2] >= points.size()
		):
			continue

		indices.sort()
		var key: Vector3i = Vector3i(
			indices[0],
			indices[1],
			indices[2]
		)
		if not seen.has(key):
			seen[key] = true
			result.append(indices)

	result.sort_custom(_compare_int_arrays)
	return result


## 将后续点已无法触及的三角形移出扫描范围，再用空腔边界重建受影响的三角形。
## [br]
## @api private
## [br]
static func _insert_point(
	active: Array[Dictionary],
	finished: Array[Dictionary],
	working_points: PackedVector2Array,
	point_index: int,
	minimum_x: float,
	epsilon: float
) -> void:
	var point: Vector2 = working_points[point_index]
	var edge_counts: Dictionary[Vector2i, int] = {}
	var kept: int = 0
	for index: int in range(active.size()):
		var triangle: Dictionary = active[index]
		var center: Vector2 = triangle["circumcenter"]
		var radius_squared: float = triangle["circumradius_squared"]
		var limit_squared: float = radius_squared + epsilon
		# 水平距离用与二维判定相同的 Vector2 精度；严格大于才可排除圆周上的点。
		if minimum_x > center.x and Vector2(minimum_x, center.y).distance_squared_to(center) > limit_squared:
			finished.append(triangle)
		elif point.distance_squared_to(center) <= limit_squared:
			var indices: PackedInt32Array = triangle["indices"]
			_add_triangle_edges(edge_counts, indices)
		else:
			active[kept] = triangle
			kept += 1
	var _resize_result: int = active.resize(kept)

	for edge: Vector2i in _get_boundary_edges(edge_counts):
		var triangle: Dictionary = _make_triangle(
			edge.x,
			edge.y,
			point_index,
			working_points,
			epsilon
		)
		if not triangle.is_empty():
			active.append(triangle)


## 根据输入点包围框中心和跨度生成覆盖点集的三个外接顶点。
## [br]
## @api private
## [br]
static func _make_super_triangle(points: PackedVector2Array) -> PackedVector2Array:
	var min_point: Vector2 = points[0]
	var max_point: Vector2 = points[0]
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)

	var center: Vector2 = (min_point + max_point) * 0.5
	var span: float = maxf(
		max_point.x - min_point.x,
		max_point.y - min_point.y
	)
	var radius: float = maxf(span, 1.0) * 16.0
	return PackedVector2Array(
		[
			center + Vector2(
				0.0,
				-radius * 2.0
			),
			center + Vector2(
				-radius * 2.0,
				radius
			),
			center + Vector2(
				radius * 2.0,
				radius
			),
		]
	)


## 计算三点的外心和外接圆平方半径，近共线或外心非有限时返回空字典。
## [br]
## @api private
## [br]
static func _make_triangle(
	a: int,
	b: int,
	c: int,
	points: PackedVector2Array,
	epsilon: float
) -> Dictionary:
	var point_a: Vector2 = points[a]
	var point_b: Vector2 = points[b]
	var point_c: Vector2 = points[c]
	var denominator: float = (2.0 * (point_a.x * (point_b.y - point_c.y) + point_b.x * (point_c.y - point_a.y) + point_c.x * (point_a.y - point_b.y)))
	if absf(denominator) <= epsilon:
		return {}

	var a_length: float = point_a.length_squared()
	var b_length: float = point_b.length_squared()
	var c_length: float = point_c.length_squared()
	var center: Vector2 = Vector2(
		(a_length * (point_b.y - point_c.y) + b_length * (point_c.y - point_a.y) + c_length * (point_a.y - point_b.y)) / denominator,
		(a_length * (point_c.x - point_b.x) + b_length * (point_a.x - point_c.x) + c_length * (point_b.x - point_a.x)) / denominator
	)
	if not _is_finite_point(center):
		return {}

	return {
		"indices": PackedInt32Array(
			[
				a,
				b,
				c,
			]
		),
		"circumcenter": center,
		"circumradius_squared": center.distance_squared_to(point_a),
	}


## 将三角形的三条无向边加入带出现次数的边表。
## [br]
## @api private
## [br]
static func _add_triangle_edges(edge_counts: Dictionary[Vector2i, int], indices: PackedInt32Array) -> void:
	if indices.size() != 3:
		return

	_add_edge(
		edge_counts,
		indices[0],
		indices[1]
	)
	_add_edge(
		edge_counts,
		indices[1],
		indices[2]
	)
	_add_edge(
		edge_counts,
		indices[2],
		indices[0]
	)


## 将端点升序的无向边计入边表。
## [br]
## @api private
## [br]
static func _add_edge(
	edge_counts: Dictionary[Vector2i, int],
	a: int,
	b: int
) -> void:
	var edge: Vector2i = Vector2i(
		mini(a, b),
		maxi(a, b)
	)
	var previous_count: int = edge_counts.get(edge, 0)
	edge_counts[edge] = previous_count + 1


## 按端点字典序返回只出现一次的边。
## [br]
## @api private
## [br]
static func _get_boundary_edges(edge_counts: Dictionary[Vector2i, int]) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for edge: Vector2i in edge_counts:
		if edge_counts[edge] == 1:
			edges.append(edge)
	edges.sort()
	return edges


## 汇总全部三角形的唯一无向边，按端点字典序输出。
## [br]
## @api private
## [br]
static func _collect_edges(triangles: Array[PackedInt32Array]) -> Array[PackedInt32Array]:
	var edge_counts: Dictionary[Vector2i, int] = {}
	for triangle: PackedInt32Array in triangles:
		_add_triangle_edges(edge_counts, triangle)
	var edges: Array = edge_counts.keys()
	edges.sort()
	var result: Array[PackedInt32Array] = []
	for edge: Vector2i in edges:
		result.append(PackedInt32Array([edge.x, edge.y]))
	return result


## 为每个有效 Delaunay 三角形追加其外接圆圆心作为 Voronoi 顶点。
## [br]
## @api private
## [br]
static func _make_voronoi_vertices(
	points: PackedVector2Array,
	triangles: Array[PackedInt32Array],
	epsilon: float
) -> PackedVector2Array:
	var vertices: PackedVector2Array = PackedVector2Array()
	for triangle: PackedInt32Array in triangles:
		var triangle_data: Dictionary = _make_triangle(
			triangle[0],
			triangle[1],
			triangle[2],
			points,
			epsilon
		)
		if triangle_data.is_empty():
			continue

		var center_variant: Variant = triangle_data.get("circumcenter", Vector2.ZERO)
		if center_variant is Vector2:
			var center: Vector2 = center_variant
			var _vertex_appended: bool = vertices.append(center)

	return vertices


## 从只出现一次的 Delaunay 边标记凸包上的输入点索引。
## [br]
## @api private
## [br]
static func _collect_hull_point_flags(triangles: Array[PackedInt32Array]) -> Dictionary:
	var edge_counts: Dictionary[Vector2i, int] = {}
	for triangle: PackedInt32Array in triangles:
		_add_triangle_edges(edge_counts, triangle)

	var hull_points: Dictionary = {}
	for edge: Vector2i in edge_counts:
		if edge_counts[edge] == 1:
			hull_points[edge.x] = true
			hull_points[edge.y] = true
	return hull_points


## 收集每个点相邻三角形的圆心，按角度排序形成其 Voronoi 多边形。
## [br]
## @api private
## [br]
static func _make_voronoi_cells(
	points: PackedVector2Array,
	triangles: Array[PackedInt32Array],
	vertices: PackedVector2Array,
	hull_points: Dictionary
) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	var incident_triangles: Array[Array] = []
	for _point: Vector2 in points:
		incident_triangles.append([])
	for triangle_index: int in range(
		mini(
			triangles.size(),
			vertices.size()
		)
	):
		for corner: int in triangles[triangle_index]:
			incident_triangles[corner].append(triangle_index)
	for point_index: int in range(points.size()):
		var vertex_entries: Array[Dictionary] = []
		for triangle_index: int in incident_triangles[point_index]:
			var vertex: Vector2 = vertices[triangle_index]
			vertex_entries.append({ "index": triangle_index, "angle": points[point_index].angle_to_point(vertex), })

		vertex_entries.sort_custom(_compare_vertex_entries)
		var vertex_indices: PackedInt32Array = PackedInt32Array()
		var polygon: PackedVector2Array = PackedVector2Array()
		for entry: Dictionary in vertex_entries:
			var vertex_index: int = GFVariantData.get_option_int(
				entry,
				"index",
				-1
			)
			if vertex_index < 0 or vertex_index >= vertices.size():
				continue

			var _index_appended: bool = vertex_indices.append(vertex_index)
			var _point_appended: bool = polygon.append(vertices[vertex_index])

		cells.append(
			{
				"point_index": point_index,
				"point": points[point_index],
				"vertex_indices": vertex_indices,
				"polygon": polygon,
				"is_open": hull_points.has(point_index),
			}
		)
	return cells


## 从字典读取 PackedVector2Array 字段，缺失或类型不符时返回空数组。
## [br]
## @api private
## [br]
static func _get_packed_vector2_array(data: Dictionary, key: String) -> PackedVector2Array:
	var value: Variant = data.get(
		key,
		PackedVector2Array()
	)
	if value is PackedVector2Array:
		return value
	return PackedVector2Array()


## 从报告数组筛选 PackedInt32Array 三角形项。
## [br]
## @api private
## [br]
static func _get_triangle_array(data: Dictionary) -> Array[PackedInt32Array]:
	var raw_value: Variant = data.get("triangles", [])
	var result: Array[PackedInt32Array] = []
	if not raw_value is Array:
		return result

	var raw_array: Array = raw_value
	for value: Variant in raw_array:
		if value is PackedInt32Array:
			var triangle: PackedInt32Array = value
			result.append(triangle)
	return result


## 判断二维点的两个坐标分量均为有限浮点值。
## [br]
## @api private
## [br]
static func _is_finite_point(point: Vector2) -> bool:
	return (
		not is_nan(point.x)
		and not is_nan(point.y)
		and not is_inf(point.x)
		and not is_inf(point.y)
	)


## 报告生成错误并返回字段完整的空三角剖分结果。
## [br]
## @api private
## [br]
static func _make_failure_result(input_point_count: int, error: String) -> Dictionary:
	push_error("[GFVoronoi2D][voronoi2d.generation_failed] Voronoi generation failed: %s." % error)
	return {
		"ok": false,
		"error": error,
		"input_point_count": input_point_count,
		"point_count": 0,
		"duplicate_count": 0,
		"points": PackedVector2Array(),
		"triangles": [],
		"edges": [],
	}


## 按 X 值近似不等时比较 X，否则按 Y 升序比较点。
## [br]
## @api private
## [br]
static func _compare_points(left: Vector2, right: Vector2) -> bool:
	if not is_equal_approx(left.x, right.x):
		return left.x < right.x
	return left.y < right.y


## 按数组元素字典序比较，公共前缀相同时较短数组在前。
## [br]
## @api private
## [br]
static func _compare_int_arrays(left: PackedInt32Array, right: PackedInt32Array) -> bool:
	var count: int = mini(
		left.size(),
		right.size()
	)
	for index: int in range(count):
		if left[index] != right[index]:
			return left[index] < right[index]
	return left.size() < right.size()


## 按角度升序比较 Voronoi 顶点记录，近似同角时按三角形索引排序。
## [br]
## @api private
## [br]
static func _compare_vertex_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_angle: float = GFVariantData.get_option_float(
		left,
		"angle",
		0.0
	)
	var right_angle: float = GFVariantData.get_option_float(
		right,
		"angle",
		0.0
	)
	if not is_equal_approx(left_angle, right_angle):
		return left_angle < right_angle
	return GFVariantData.get_option_int(
		left,
		"index",
		0
	) < GFVariantData.get_option_int(
		right,
		"index",
		0
	)
