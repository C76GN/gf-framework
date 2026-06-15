## 测试 GFVoronoi2D 的 Delaunay 三角剖分与 Voronoi 图结构。
extends GutTest


# --- 常量 ---

const GF_VORONOI_2D = preload("res://addons/gf/standard/foundation/math/gf_voronoi_2d.gd")


# --- 测试 ---

func test_delaunay_builds_single_triangle_for_three_points() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_delaunay(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
	]))

	assert_true(GFVariantData.get_option_bool(result, "ok", false))
	assert_eq(GFVariantData.get_option_int(result, "point_count", 0), 3)
	assert_eq(_get_triangles(result).size(), 1)
	assert_eq(_get_edges(result).size(), 3)


func test_delaunay_deduplicates_points_by_epsilon() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_delaunay(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0000002, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
	]))

	assert_true(GFVariantData.get_option_bool(result, "ok", false))
	assert_eq(GFVariantData.get_option_int(result, "point_count", 0), 3)
	assert_eq(GFVariantData.get_option_int(result, "duplicate_count", 0), 1)
	assert_eq(_get_triangles(result).size(), 1)


func test_delaunay_omits_collinear_triangles() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_delaunay(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(3.0, 0.0),
	]))

	assert_true(GFVariantData.get_option_bool(result, "ok", false))
	assert_eq(_get_triangles(result).size(), 0)
	assert_eq(_get_edges(result).size(), 0)


func test_delaunay_rejects_non_finite_points() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_delaunay(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2.INF,
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
	]))

	assert_push_error("[GFVoronoi2D] points must contain finite Vector2 values.")
	assert_false(GFVariantData.get_option_bool(result, "ok", true), "非法点集应返回结构化失败。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "points must contain finite Vector2 values.")
	assert_eq(_get_triangles(result).size(), 0)


func test_delaunay_respects_max_points_after_deduplication() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_delaunay(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
	]), {
		"max_points": 2,
	})

	assert_push_error("[GFVoronoi2D] point_count exceeds max_points.")
	assert_false(GFVariantData.get_option_bool(result, "ok", true), "超过 max_points 时应失败。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "point_count exceeds max_points.")
	assert_eq(GFVariantData.get_option_int(result, "input_point_count", 0), 4)
	assert_eq(_get_triangles(result).size(), 0)


func test_voronoi_marks_center_cell_as_closed() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_voronoi(PackedVector2Array([
		Vector2(-1.0, -1.0),
		Vector2(1.0, -1.0),
		Vector2(1.0, 1.0),
		Vector2(-1.0, 1.0),
		Vector2.ZERO,
	]))

	assert_true(GFVariantData.get_option_bool(result, "ok", false))
	assert_true(_get_vertices(result).size() >= 4)

	var center_cell: Dictionary = _find_cell(result, Vector2.ZERO)
	assert_false(center_cell.is_empty(), "应为中心点生成 cell。")
	assert_false(GFVariantData.get_option_bool(center_cell, "is_open", true), "中心点不在凸包上，应生成闭合 cell。")
	assert_true(_get_polygon(center_cell).size() >= 3, "闭合 cell 应包含可排序的 Voronoi 顶点。")


func test_voronoi_marks_hull_cells_as_open() -> void:
	var result: Dictionary = GF_VORONOI_2D.build_voronoi(PackedVector2Array([
		Vector2(-1.0, -1.0),
		Vector2(1.0, -1.0),
		Vector2(1.0, 1.0),
		Vector2(-1.0, 1.0),
		Vector2.ZERO,
	]))

	assert_true(GFVariantData.get_option_bool(result, "ok", false))
	var hull_cell: Dictionary = _find_cell(result, Vector2(-1.0, -1.0))
	assert_false(hull_cell.is_empty(), "应为凸包点生成 cell。")
	assert_true(GFVariantData.get_option_bool(hull_cell, "is_open", false), "凸包点 cell 应标记为开放。")


# --- 私有/辅助方法 ---

func _get_triangles(result: Dictionary) -> Array:
	return GFVariantData.get_option_array(result, "triangles", [])


func _get_edges(result: Dictionary) -> Array:
	return GFVariantData.get_option_array(result, "edges", [])


func _get_vertices(result: Dictionary) -> PackedVector2Array:
	var vertices: Variant = result.get("vertices", PackedVector2Array())
	if vertices is PackedVector2Array:
		return vertices
	return PackedVector2Array()


func _get_polygon(cell: Dictionary) -> PackedVector2Array:
	var polygon: Variant = cell.get("polygon", PackedVector2Array())
	if polygon is PackedVector2Array:
		return polygon
	return PackedVector2Array()


func _find_cell(result: Dictionary, point: Vector2) -> Dictionary:
	for cell: Variant in GFVariantData.get_option_array(result, "cells", []):
		if not cell is Dictionary:
			continue

		var cell_data: Dictionary = cell
		var cell_point: Variant = cell_data.get("point", Vector2.INF)
		if cell_point is Vector2:
			var cell_position: Vector2 = cell_point
			if cell_position.is_equal_approx(point):
				return cell_data
	return {}
