## 测试 GFCollisionNarrowphase2D 的凸多边形 SAT、相切策略和旋转盒 shape。
extends GutTest


# --- 常量 ---

const GF_COLLISION_NARROWPHASE_2D = preload("res://addons/gf/standard/foundation/math/gf_collision_narrowphase_2d.gd")
const GF_COLLISION_BROADPHASE_2D = preload("res://addons/gf/standard/foundation/math/gf_collision_broadphase_2d.gd")


# --- 测试 ---

func test_make_box_builds_convex_polygon_and_copies_metadata() -> void:
	var metadata: Dictionary = { "team": "red" }
	var shape: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(
		Vector2(4.0, 6.0),
		Vector2(-2.0, 4.0),
		PI * 0.25,
		metadata
	)
	metadata["team"] = "blue"

	var points: PackedVector2Array = _shape_points(shape)

	assert_eq(GFVariantData.get_option_string_name(shape, "type"), GF_COLLISION_NARROWPHASE_2D.SHAPE_POLYGON)
	assert_eq(points.size(), 4, "旋转盒 shape 应生成四个顶点。")
	assert_true(GF_COLLISION_NARROWPHASE_2D.is_convex_polygon(points), "旋转盒顶点应构成凸多边形。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(shape, "metadata"), "team"), "red")


func test_project_polygon_reports_axis_interval() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(2.0, 1.0),
		Vector2(0.0, 1.0),
	])

	var projection: Dictionary = GF_COLLISION_NARROWPHASE_2D.project_polygon(points, Vector2.RIGHT)

	assert_true(GFVariantData.get_option_bool(projection, "valid"), "有效轴应产生投影区间。")
	assert_almost_eq(GFVariantData.get_option_float(projection, "min"), 0.0, 0.001)
	assert_almost_eq(GFVariantData.get_option_float(projection, "max"), 2.0, 0.001)


func test_sat_overlap_returns_penetration_depth_normal_and_mtv() -> void:
	var left: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2.ZERO, Vector2(2.0, 2.0))
	var right: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(1.5, 0.0), Vector2(2.0, 2.0))

	var report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(left, right)
	var normal: Vector2 = GFVariantData.get_option_vector2(report, "normal")
	var minimum_translation: Vector2 = GFVariantData.get_option_vector2(report, "minimum_translation")

	assert_true(GFVariantData.get_option_bool(report, "overlap"), "相交盒应报告 overlap。")
	assert_false(GFVariantData.get_option_bool(report, "touching"), "有穿透时不应标记为 touching。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), GF_COLLISION_NARROWPHASE_2D.REASON_OVERLAP)
	assert_almost_eq(GFVariantData.get_option_float(report, "penetration_depth"), 0.5, 0.001)
	assert_almost_eq(normal.x, 1.0, 0.001, "法线应从 A 指向 B。")
	assert_almost_eq(normal.y, 0.0, 0.001)
	assert_almost_eq(minimum_translation.x, 0.5, 0.001)
	assert_almost_eq(minimum_translation.y, 0.0, 0.001)


func test_sat_reports_separated_shapes() -> void:
	var left: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2.ZERO, Vector2(2.0, 2.0))
	var right: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(4.0, 0.0), Vector2(1.0, 1.0))

	var report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(left, right)

	assert_false(GFVariantData.get_option_bool(report, "overlap"), "分离盒不应报告 overlap。")
	assert_false(GFVariantData.get_option_bool(report, "touching"), "存在间隙时不应报告 touching。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), GF_COLLISION_NARROWPHASE_2D.REASON_SEPARATED)


func test_touching_policy_is_explicit() -> void:
	var left: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2.ZERO, Vector2(2.0, 2.0))
	var right: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(2.0, 0.0), Vector2(2.0, 2.0))

	var default_report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(left, right)
	var touching_report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(
		left,
		right,
		{ "include_touching": true }
	)

	assert_false(GFVariantData.get_option_bool(default_report, "overlap"), "默认不把仅边界相切算作 overlap。")
	assert_true(GFVariantData.get_option_bool(default_report, "touching"), "默认仍应报告 touching 状态。")
	assert_eq(GFVariantData.get_option_string_name(default_report, "reason"), GF_COLLISION_NARROWPHASE_2D.REASON_TOUCHING)
	assert_true(GFVariantData.get_option_bool(touching_report, "overlap"), "开启 include_touching 后相切应算作 overlap。")
	assert_true(GFVariantData.get_option_bool(touching_report, "touching"), "include_touching 后仍应保留 touching 标记。")
	assert_almost_eq(GFVariantData.get_option_float(touching_report, "penetration_depth"), 0.0, 0.001)


func test_concave_or_degenerate_polygons_are_rejected() -> void:
	var concave: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(2.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(2.0, 2.0),
		Vector2(0.0, 2.0),
	])
	var degenerate: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(2.0, 0.0),
	])
	var convex: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])

	var report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_polygon_overlap(concave, convex)

	assert_false(GF_COLLISION_NARROWPHASE_2D.is_convex_polygon(concave), "凹多边形不应通过凸性校验。")
	assert_false(GF_COLLISION_NARROWPHASE_2D.is_convex_polygon(degenerate), "共线退化多边形不应通过凸性校验。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), GF_COLLISION_NARROWPHASE_2D.REASON_INVALID_SHAPE)


func test_rotated_boxes_can_overlap_through_shape_api() -> void:
	var first: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2.ZERO, Vector2(3.0, 1.0), PI * 0.25)
	var second: Dictionary = GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(0.6, 0.0), Vector2(3.0, 1.0), -PI * 0.25)

	var report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(first, second)

	assert_true(GFVariantData.get_option_bool(report, "overlap"), "旋转盒应通过 shape API 做 SAT 重叠测试。")
	assert_gt(GFVariantData.get_option_int(report, "axis_count"), 0, "SAT 报告应记录参与测试的轴数量。")


func test_broadphase_candidates_are_filtered_by_narrowphase_sat() -> void:
	var shapes: Array[Dictionary] = [
		GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(0.0, 0.0), Vector2(2.0, 2.0)),
		GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(0.75, 0.0), Vector2(2.0, 2.0)),
		GF_COLLISION_NARROWPHASE_2D.make_polygon(PackedVector2Array([
			Vector2(10.0, 0.0),
			Vector2(12.0, 0.0),
			Vector2(10.0, 2.0),
		])),
		GF_COLLISION_NARROWPHASE_2D.make_polygon(PackedVector2Array([
			Vector2(13.5, 1.5),
			Vector2(13.5, 3.5),
			Vector2(11.5, 3.5),
		])),
		GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(20.0, 0.0), Vector2(2.0, 2.0)),
		GF_COLLISION_NARROWPHASE_2D.make_box(Vector2(22.0, 0.0), Vector2(2.0, 2.0)),
	]
	var bodies: Array = []
	for index: int in range(shapes.size()):
		bodies.append(GF_COLLISION_BROADPHASE_2D.make_body(index, _shape_bounds(shapes[index])))

	var candidate_pairs: Array[Dictionary] = GF_COLLISION_BROADPHASE_2D.find_pairs_sap(
		bodies,
		{ "include_touching": true }
	)
	var overlap_keys: Array[String] = []
	var touching_keys: Array[String] = []
	var separated_keys: Array[String] = []
	for pair: Dictionary in candidate_pairs:
		var a_index: int = GFVariantData.get_option_int(pair, "a_index")
		var b_index: int = GFVariantData.get_option_int(pair, "b_index")
		var key: String = "%d:%d" % [a_index, b_index]
		var report: Dictionary = GF_COLLISION_NARROWPHASE_2D.test_shapes_overlap(
			shapes[a_index],
			shapes[b_index],
			{ "include_touching": true }
		)
		if GFVariantData.get_option_bool(report, "overlap"):
			overlap_keys.append(key)
		if GFVariantData.get_option_bool(report, "touching"):
			touching_keys.append(key)
		if GFVariantData.get_option_string_name(report, "reason") == GF_COLLISION_NARROWPHASE_2D.REASON_SEPARATED:
			separated_keys.append(key)

	assert_eq(_pair_index_keys(candidate_pairs), ["0:1", "2:3", "4:5"], "broadphase 只输出 AABB 候选，不承诺几何精确碰撞。")
	assert_eq(overlap_keys, ["0:1", "4:5"], "narrowphase 应保留真实重叠和按策略纳入的相切 pair。")
	assert_eq(touching_keys, ["4:5"], "touching 策略应由 narrowphase 明确报告。")
	assert_eq(separated_keys, ["2:3"], "AABB false positive 应由 SAT 精确判定过滤。")


func _shape_points(shape: Dictionary) -> PackedVector2Array:
	var points_value: Variant = GFVariantData.get_option_value(shape, "points", PackedVector2Array())
	if points_value is PackedVector2Array:
		var points: PackedVector2Array = points_value
		return points
	return PackedVector2Array()


func _shape_bounds(shape: Dictionary) -> Rect2:
	var points: PackedVector2Array = _shape_points(shape)
	if points.size() == 0:
		return Rect2()

	var min_x: float = points[0].x
	var min_y: float = points[0].y
	var max_x: float = points[0].x
	var max_y: float = points[0].y
	for index: int in range(1, points.size()):
		var point: Vector2 = points[index]
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _pair_index_keys(pairs: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for pair: Dictionary in pairs:
		result.append("%d:%d" % [
			GFVariantData.get_option_int(pair, "a_index"),
			GFVariantData.get_option_int(pair, "b_index"),
		])
	result.sort()
	return result
