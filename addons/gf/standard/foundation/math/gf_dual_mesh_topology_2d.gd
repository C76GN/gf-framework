## GFDualMeshTopology2D: 二维 Delaunay / Voronoi 双图拓扑工具。
##
## 从 GFVoronoi2D 的纯数据结果派生点邻接、边到三角形、点到三角形和边界信息。
## 它不生成地图、Mesh、Tile、河流、生态群系或渲染数据，项目层可在这些拓扑之上解释领域语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFDualMeshTopology2D
extends RefCounted


# --- 公共方法 ---

## 从点集构建 Delaunay / Voronoi 拓扑。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param points: 输入点集。
## [br]
## @param options: 可选参数，会传给 GFVoronoi2D.build_voronoi()；另支持 include_cells。
## [br]
## @return 拓扑报告。
## [br]
## @schema options: Dictionary，可包含 GFVoronoi2D options 和 include_cells: bool。
## [br]
## @schema return: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges、hull_points 和可选 cells。
static func build_from_points(points: PackedVector2Array, options: Dictionary = {}) -> Dictionary:
	var voronoi: Dictionary = GFVoronoi2D.build_voronoi(points, options)
	return build_from_voronoi(voronoi, options)


## 从 GFVoronoi2D.build_voronoi() 结果构建双图拓扑。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param voronoi_result: GFVoronoi2D.build_voronoi() 返回的结果字典。
## [br]
## @param options: 可选参数，支持 include_cells。
## [br]
## @return 拓扑报告。
## [br]
## @schema voronoi_result: Dictionary，包含 points、triangles、edges、vertices、cells 等字段。
## [br]
## @schema options: Dictionary，可包含 include_cells: bool。
## [br]
## @schema return: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges、hull_points 和可选 cells。
static func build_from_voronoi(voronoi_result: Dictionary, options: Dictionary = {}) -> Dictionary:
	var topology: Dictionary = build_from_delaunay(voronoi_result, options)
	if not GFVariantData.get_option_bool(topology, "ok", false):
		return topology

	var vertices: PackedVector2Array = _get_packed_vector2_array(voronoi_result, "vertices")
	var triangles: Array[PackedInt32Array] = _get_triangle_array(voronoi_result)
	if vertices.size() == triangles.size():
		topology["triangle_centers"] = vertices
	if GFVariantData.get_option_bool(options, "include_cells", false):
		topology["cells"] = _get_cells(voronoi_result)
	return topology


## 从 GFVoronoi2D.build_delaunay() 结果构建双图拓扑。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delaunay_result: GFVoronoi2D.build_delaunay() 返回的结果字典。
## [br]
## @param _options: 保留给未来扩展的选项。
## [br]
## @return 拓扑报告。
## [br]
## @schema delaunay_result: Dictionary，包含 points、triangles 和可选 edges。
## [br]
## @schema _options: Dictionary，当前未使用。
## [br]
## @schema return: Dictionary，包含 ok、points、triangles、edges、triangle_centers、neighbors_by_point、triangles_by_point、edge_records、triangles_by_edge、hull_edges 和 hull_points。
static func build_from_delaunay(delaunay_result: Dictionary, _options: Dictionary = {}) -> Dictionary:
	if not GFVariantData.get_option_bool(delaunay_result, "ok", false):
		return _make_failure(GFVariantData.get_option_string(delaunay_result, "error", "delaunay result is not ok."))

	var points: PackedVector2Array = _get_packed_vector2_array(delaunay_result, "points")
	var triangles: Array[PackedInt32Array] = _get_triangle_array(delaunay_result)
	var point_count: int = points.size()
	var neighbors_by_point: Array[PackedInt32Array] = _make_empty_packed_array_list(point_count)
	var triangles_by_point: Array[PackedInt32Array] = _make_empty_packed_array_list(point_count)
	var triangles_by_edge: Dictionary = {}
	var invalid_triangle_indices: PackedInt32Array = PackedInt32Array()

	for triangle_index: int in range(triangles.size()):
		var triangle: PackedInt32Array = triangles[triangle_index]
		if not _is_valid_triangle(triangle, point_count):
			var _invalid_appended: bool = invalid_triangle_indices.append(triangle_index)
			continue
		_add_triangle_to_points(triangles_by_point, triangle, triangle_index)
		_add_triangle_neighbors(neighbors_by_point, triangle)
		_add_triangle_edges(triangles_by_edge, triangle, triangle_index)

	var edge_records: Array[Dictionary] = _make_edge_records(triangles_by_edge)
	var edges: Array[PackedInt32Array] = []
	var hull_edges: Array[PackedInt32Array] = []
	var hull_point_lookup: Dictionary = {}
	for edge_record: Dictionary in edge_records:
		var edge: PackedInt32Array = _get_edge_from_record(edge_record)
		if edge.is_empty():
			continue
		edges.append(edge)
		if GFVariantData.get_option_bool(edge_record, "is_hull", false):
			hull_edges.append(edge)
			hull_point_lookup[edge[0]] = true
			hull_point_lookup[edge[1]] = true

	return {
		"ok": invalid_triangle_indices.is_empty(),
		"error": "" if invalid_triangle_indices.is_empty() else "triangles contain invalid point indices.",
		"point_count": point_count,
		"triangle_count": triangles.size(),
		"edge_count": edges.size(),
		"points": points,
		"triangles": triangles,
		"edges": edges,
		"triangle_centers": _make_triangle_centers(points, triangles),
		"neighbors_by_point": neighbors_by_point,
		"triangles_by_point": triangles_by_point,
		"triangles_by_edge": triangles_by_edge,
		"edge_records": edge_records,
		"hull_edges": hull_edges,
		"hull_points": _make_sorted_int_array(hull_point_lookup.keys()),
		"invalid_triangle_indices": invalid_triangle_indices,
	}


## 构建稳定边键。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param a: 第一个点索引。
## [br]
## @param b: 第二个点索引。
## [br]
## @return 稳定边键。
static func make_edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


## 获取指定点的邻接点索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param topology: build_from_* 返回的拓扑报告。
## [br]
## @param point_index: 点索引。
## [br]
## @return 邻接点索引。
## [br]
## @schema topology: Dictionary，build_from_* 返回的拓扑报告。
static func get_point_neighbors(topology: Dictionary, point_index: int) -> PackedInt32Array:
	var neighbors_by_point: Array[PackedInt32Array] = _get_packed_int_array_list(topology, "neighbors_by_point")
	if point_index < 0 or point_index >= neighbors_by_point.size():
		return PackedInt32Array()
	return neighbors_by_point[point_index].duplicate()


## 获取指定边关联的三角形索引。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param topology: build_from_* 返回的拓扑报告。
## [br]
## @param a: 第一个点索引。
## [br]
## @param b: 第二个点索引。
## [br]
## @return 共享该边的三角形索引。
## [br]
## @schema topology: Dictionary，build_from_* 返回的拓扑报告。
static func get_edge_triangles(topology: Dictionary, a: int, b: int) -> PackedInt32Array:
	var triangles_by_edge: Dictionary = GFVariantData.get_option_dictionary(topology, "triangles_by_edge")
	var value: Variant = GFVariantData.get_option_value(triangles_by_edge, make_edge_key(a, b), PackedInt32Array())
	if value is PackedInt32Array:
		var triangles: PackedInt32Array = value
		return triangles.duplicate()
	return PackedInt32Array()


# --- 私有/辅助方法 ---

static func _make_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"point_count": 0,
		"triangle_count": 0,
		"edge_count": 0,
		"points": PackedVector2Array(),
		"triangles": [],
		"edges": [],
		"triangle_centers": PackedVector2Array(),
		"neighbors_by_point": [],
		"triangles_by_point": [],
		"triangles_by_edge": {},
		"edge_records": [],
		"hull_edges": [],
		"hull_points": PackedInt32Array(),
		"invalid_triangle_indices": PackedInt32Array(),
	}


static func _make_empty_packed_array_list(count: int) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for _index: int in range(maxi(count, 0)):
		result.append(PackedInt32Array())
	return result


static func _is_valid_triangle(triangle: PackedInt32Array, point_count: int) -> bool:
	if triangle.size() != 3:
		return false
	for point_index: int in triangle:
		if point_index < 0 or point_index >= point_count:
			return false
	return true


static func _add_triangle_to_points(
	triangles_by_point: Array[PackedInt32Array],
	triangle: PackedInt32Array,
	triangle_index: int
) -> void:
	for point_index: int in triangle:
		var triangle_indices: PackedInt32Array = triangles_by_point[point_index]
		var _appended: bool = triangle_indices.append(triangle_index)
		triangles_by_point[point_index] = triangle_indices


static func _add_triangle_neighbors(neighbors_by_point: Array[PackedInt32Array], triangle: PackedInt32Array) -> void:
	_add_neighbor_pair(neighbors_by_point, triangle[0], triangle[1])
	_add_neighbor_pair(neighbors_by_point, triangle[1], triangle[2])
	_add_neighbor_pair(neighbors_by_point, triangle[2], triangle[0])


static func _add_neighbor_pair(neighbors_by_point: Array[PackedInt32Array], a: int, b: int) -> void:
	var a_neighbors: PackedInt32Array = neighbors_by_point[a]
	if not _packed_int_array_has(a_neighbors, b):
		var _a_appended: bool = a_neighbors.append(b)
		a_neighbors.sort()
		neighbors_by_point[a] = a_neighbors

	var b_neighbors: PackedInt32Array = neighbors_by_point[b]
	if not _packed_int_array_has(b_neighbors, a):
		var _b_appended: bool = b_neighbors.append(a)
		b_neighbors.sort()
		neighbors_by_point[b] = b_neighbors


static func _add_triangle_edges(
	triangles_by_edge: Dictionary,
	triangle: PackedInt32Array,
	triangle_index: int
) -> void:
	_add_edge_triangle(triangles_by_edge, triangle[0], triangle[1], triangle_index)
	_add_edge_triangle(triangles_by_edge, triangle[1], triangle[2], triangle_index)
	_add_edge_triangle(triangles_by_edge, triangle[2], triangle[0], triangle_index)


static func _add_edge_triangle(triangles_by_edge: Dictionary, a: int, b: int, triangle_index: int) -> void:
	var key: String = make_edge_key(a, b)
	var triangle_indices: PackedInt32Array = PackedInt32Array()
	var value: Variant = GFVariantData.get_option_value(triangles_by_edge, key, PackedInt32Array())
	if value is PackedInt32Array:
		triangle_indices = value
	if not _packed_int_array_has(triangle_indices, triangle_index):
		var _appended: bool = triangle_indices.append(triangle_index)
		triangle_indices.sort()
	triangles_by_edge[key] = triangle_indices


static func _make_edge_records(triangles_by_edge: Dictionary) -> Array[Dictionary]:
	var keys: PackedStringArray = PackedStringArray()
	for key: Variant in triangles_by_edge.keys():
		var _key_appended: bool = keys.append(GFVariantData.to_text(key))
	keys.sort()

	var result: Array[Dictionary] = []
	for key: String in keys:
		var edge: PackedInt32Array = _edge_from_key(key)
		if edge.size() != 2:
			continue
		var triangle_indices: PackedInt32Array = PackedInt32Array()
		var value: Variant = GFVariantData.get_option_value(triangles_by_edge, key, PackedInt32Array())
		if value is PackedInt32Array:
			triangle_indices = value
		result.append({
			"key": key,
			"a": edge[0],
			"b": edge[1],
			"edge": edge,
			"triangles": triangle_indices.duplicate(),
			"is_hull": triangle_indices.size() == 1,
		})
	return result


static func _edge_from_key(key: String) -> PackedInt32Array:
	var parts: PackedStringArray = key.split(":", false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return PackedInt32Array()
	return PackedInt32Array([parts[0].to_int(), parts[1].to_int()])


static func _get_edge_from_record(edge_record: Dictionary) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(edge_record, "edge", PackedInt32Array())
	if value is PackedInt32Array:
		var edge: PackedInt32Array = value
		return edge.duplicate()
	return PackedInt32Array()


static func _make_triangle_centers(
	points: PackedVector2Array,
	triangles: Array[PackedInt32Array]
) -> PackedVector2Array:
	var centers: PackedVector2Array = PackedVector2Array()
	for triangle: PackedInt32Array in triangles:
		if not _is_valid_triangle(triangle, points.size()):
			var _invalid_center_appended: bool = centers.append(Vector2.ZERO)
			continue
		var center: Vector2 = (points[triangle[0]] + points[triangle[1]] + points[triangle[2]]) / 3.0
		var _center_appended: bool = centers.append(center)
	return centers


static func _make_sorted_int_array(values: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for value: Variant in values:
		if value is int:
			var index_value: int = value
			var _appended: bool = result.append(index_value)
	result.sort()
	return result


static func _packed_int_array_has(values: PackedInt32Array, target: int) -> bool:
	for value: int in values:
		if value == target:
			return true
	return false


static func _get_packed_vector2_array(data: Dictionary, key: String) -> PackedVector2Array:
	var value: Variant = GFVariantData.get_option_value(data, key, PackedVector2Array())
	if value is PackedVector2Array:
		var points: PackedVector2Array = value
		return points
	return PackedVector2Array()


static func _get_triangle_array(data: Dictionary) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	var value: Variant = GFVariantData.get_option_value(data, "triangles", [])
	if not (value is Array):
		return result
	var raw_array: Array = value
	for item: Variant in raw_array:
		if item is PackedInt32Array:
			var triangle: PackedInt32Array = item
			result.append(triangle)
	return result


static func _get_packed_int_array_list(data: Dictionary, key: String) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	var value: Variant = GFVariantData.get_option_value(data, key, [])
	if not (value is Array):
		return result
	var raw_array: Array = value
	for item: Variant in raw_array:
		if item is PackedInt32Array:
			var item_array: PackedInt32Array = item
			result.append(item_array)
	return result


static func _get_cells(data: Dictionary) -> Array:
	var value: Variant = GFVariantData.get_option_value(data, "cells", [])
	if value is Array:
		var cells: Array = value
		return cells.duplicate(true)
	return []
