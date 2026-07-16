## 测试 Delaunay / Voronoi 双图拓扑工具。
extends GutTest


# --- 测试 ---

func test_dual_mesh_topology_builds_neighbors_and_hull_edges() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	])

	var topology: Dictionary = GFDualMeshTopology2D.build_from_points(points)
	var hull_points: PackedInt32Array = _get_packed_int_array(topology, "hull_points")
	var edge_records: Array = GFVariantData.get_option_array(topology, "edge_records")
	var triangle_centers: PackedVector2Array = _get_packed_vector2_array(topology, "triangle_centers")

	assert_true(GFVariantData.get_option_bool(topology, "ok"), "有效点集应构建拓扑。")
	assert_eq(GFVariantData.get_option_int(topology, "point_count"), 4, "拓扑应保留点数量。")
	assert_eq(hull_points.size(), 4, "正方形四个点都应位于边界。")
	assert_gt(edge_records.size(), 0, "拓扑应包含边记录。")
	assert_eq(triangle_centers.size(), GFVariantData.get_option_int(topology, "triangle_count"), "每个三角形应有一个中心点。")
	assert_true(_has_hull_edge(edge_records), "至少应存在一条只关联一个三角形的边界边。")


func test_dual_mesh_topology_reads_edge_triangles_and_neighbors() -> void:
	var delaunay: Dictionary = {
		"ok": true,
		"points": PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(0.0, 1.0),
		]),
		"triangles": [
			PackedInt32Array([0, 1, 2]),
		],
	}

	var topology: Dictionary = GFDualMeshTopology2D.build_from_delaunay(delaunay)
	var neighbors: PackedInt32Array = GFDualMeshTopology2D.get_point_neighbors(topology, 0)
	var edge_triangles: PackedInt32Array = GFDualMeshTopology2D.get_edge_triangles(topology, 0, 1)

	assert_eq(neighbors, PackedInt32Array([1, 2]), "点邻接应按稳定顺序输出。")
	assert_eq(edge_triangles, PackedInt32Array([0]), "边应能查询关联三角形。")
	assert_eq(GFDualMeshTopology2D.make_edge_key(2, 0), "0:2", "边键应与输入顺序无关。")


# --- 私有/辅助方法 ---

func _has_hull_edge(edge_records: Array) -> bool:
	for edge_value: Variant in edge_records:
		var edge_record: Dictionary = GFVariantData.as_dictionary(edge_value)
		if GFVariantData.get_option_bool(edge_record, "is_hull", false):
			return true
	return false


func _get_packed_int_array(source: Dictionary, key: String) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(source, key, PackedInt32Array())
	if value is PackedInt32Array:
		var packed: PackedInt32Array = value
		return packed
	return PackedInt32Array()


func _get_packed_vector2_array(source: Dictionary, key: String) -> PackedVector2Array:
	var value: Variant = GFVariantData.get_option_value(source, key, PackedVector2Array())
	if value is PackedVector2Array:
		var packed: PackedVector2Array = value
		return packed
	return PackedVector2Array()
