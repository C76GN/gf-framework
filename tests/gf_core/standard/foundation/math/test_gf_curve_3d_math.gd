## 测试 GFCurve3DMath 的 3D 折线和 Curve3D 采样报告。
extends GutTest


# --- 常量 ---

const GF_CURVE_3D_MATH_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_curve_3d_math.gd")


# --- 测试 ---

func test_polyline_length_and_sampling_use_distance_ratio() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.0, 0.0, 10.0),
		Vector3(10.0, 0.0, 10.0),
	])

	assert_almost_eq(GF_CURVE_3D_MATH_SCRIPT.get_polyline_length(points), 20.0, 0.001)
	assert_eq(GF_CURVE_3D_MATH_SCRIPT.sample_polyline(points, 0.0), Vector3.ZERO)
	assert_eq(GF_CURVE_3D_MATH_SCRIPT.sample_polyline(points, 1.0), Vector3(10.0, 0.0, 10.0))
	assert_eq(GF_CURVE_3D_MATH_SCRIPT.sample_polyline(points, 0.5), Vector3(0.0, 0.0, 10.0))
	assert_eq(GF_CURVE_3D_MATH_SCRIPT.sample_polyline(points, 0.75), Vector3(5.0, 0.0, 10.0))


func test_polyline_sampling_handles_empty_single_and_degenerate_inputs() -> void:
	assert_eq(GF_CURVE_3D_MATH_SCRIPT.sample_polyline(PackedVector3Array(), 0.5), Vector3.ZERO)
	assert_eq(
		GF_CURVE_3D_MATH_SCRIPT.sample_polyline(PackedVector3Array([Vector3(2.0, 3.0, 4.0)]), 0.5),
		Vector3(2.0, 3.0, 4.0)
	)
	assert_eq(
		GF_CURVE_3D_MATH_SCRIPT.sample_polyline(PackedVector3Array([Vector3.ONE, Vector3.ONE]), 0.5),
		Vector3.ONE
	)


func test_sample_polyline_pose_reports_offset_tangent_and_frame() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.0, 0.0, 10.0),
		Vector3(10.0, 0.0, 10.0),
	])

	var pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_polyline_pose(points, 0.75, false, -1.0, Vector3.UP)

	assert_true(GFVariantData.get_option_bool(pose, "ok"), "有效 3D 折线应返回姿态报告。")
	assert_eq(_option_vector3(pose, "point"), Vector3(5.0, 0.0, 10.0), "采样点应按路径长度比例落在第二段。")
	assert_almost_eq(GFVariantData.get_option_float(pose, "offset"), 15.0, 0.001)
	assert_eq(GFVariantData.get_option_int(pose, "segment_index"), 1, "segment_index 应指向采样所在原始线段。")
	assert_almost_eq(GFVariantData.get_option_float(pose, "segment_ratio"), 0.5, 0.001)
	assert_eq(_option_vector3(pose, "tangent"), Vector3.RIGHT, "第二段切线应朝向 +X。")
	assert_eq(_option_vector3(pose, "normal"), Vector3.UP, "法线应尽量保持 up_hint。")
	assert_almost_eq(_option_vector3(pose, "binormal").length(), 1.0, 0.001)
	assert_almost_eq(_option_vector3(pose, "binormal").dot(Vector3.RIGHT), 0.0, 0.001)
	assert_almost_eq(_option_vector3(pose, "binormal").dot(Vector3.UP), 0.0, 0.001)


func test_sample_polyline_pose_uses_fallback_frame_when_up_parallel_to_tangent() -> void:
	var points: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3.UP * 10.0,
	])

	var pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_polyline_pose(points, 0.5, false, -1.0, Vector3.UP)
	var tangent: Vector3 = _option_vector3(pose, "tangent")
	var normal: Vector3 = _option_vector3(pose, "normal")

	assert_true(GFVariantData.get_option_bool(pose, "ok"), "up_hint 与切线平行时仍应返回有效姿态。")
	assert_eq(tangent, Vector3.UP)
	assert_almost_eq(normal.length(), 1.0, 0.001)
	assert_almost_eq(normal.dot(tangent), 0.0, 0.001)


func test_project_point_to_polyline_reports_closest_point_and_closed_segment() -> void:
	var open_points: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(0.0, 0.0, 10.0),
		Vector3(10.0, 0.0, 10.0),
	])
	var closed_points: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
		Vector3(10.0, 0.0, 10.0),
		Vector3(0.0, 0.0, 10.0),
	])

	var open_projection: Dictionary = GF_CURVE_3D_MATH_SCRIPT.project_point_to_polyline(
		open_points,
		Vector3(2.0, 3.0, 4.0)
	)
	var closed_projection: Dictionary = GF_CURVE_3D_MATH_SCRIPT.project_point_to_polyline(
		closed_points,
		Vector3(-2.0, 3.0, 5.0),
		true
	)

	assert_true(GFVariantData.get_option_bool(open_projection, "ok"), "有效 3D 折线应返回最近投影报告。")
	assert_eq(_option_vector3(open_projection, "point"), Vector3(0.0, 0.0, 4.0), "最近点应投影到第一段。")
	assert_almost_eq(GFVariantData.get_option_float(open_projection, "distance"), sqrt(13.0), 0.001)
	assert_almost_eq(GFVariantData.get_option_float(open_projection, "ratio"), 0.2, 0.001)
	assert_eq(_option_vector3(open_projection, "tangent"), Vector3.BACK)

	assert_true(GFVariantData.get_option_bool(closed_projection, "ok"), "闭合 3D 折线应包含末点回首点线段。")
	assert_eq(_option_vector3(closed_projection, "point"), Vector3(0.0, 0.0, 5.0), "闭合边应能参与最近点计算。")
	assert_eq(GFVariantData.get_option_int(closed_projection, "segment_index"), 3, "闭合边索引应为最后一个原始点。")
	assert_almost_eq(GFVariantData.get_option_float(closed_projection, "offset"), 35.0, 0.001)


func test_curve_sampling_and_pose_use_baked_length() -> void:
	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, 10.0))
	curve.add_point(Vector3(10.0, 0.0, 10.0))

	var point: Vector3 = GF_CURVE_3D_MATH_SCRIPT.sample_curve(curve, 0.75)
	var pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_curve_pose(curve, 0.75, false, 0.1, Vector3.UP)

	assert_true(point.is_equal_approx(Vector3(5.0, 0.0, 10.0)), "Curve3D 采样应按 baked 长度比例取点。")
	assert_true(GFVariantData.get_option_bool(pose, "ok"), "有效 Curve3D 应返回姿态报告。")
	assert_true(_option_vector3(pose, "point").is_equal_approx(Vector3(5.0, 0.0, 10.0)))
	assert_almost_eq(GFVariantData.get_option_float(pose, "offset"), 15.0, 0.001)
	assert_true(_option_vector3(pose, "tangent").is_equal_approx(Vector3.RIGHT))
	assert_eq(_option_vector3(pose, "normal"), Vector3.UP)


func test_curve_pose_handles_empty_single_and_flat_curves() -> void:
	var empty_pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_curve_pose(null, 0.5)
	var single_curve: Curve3D = Curve3D.new()
	var flat_curve: Curve3D = Curve3D.new()
	single_curve.add_point(Vector3(1.0, 2.0, 3.0))
	flat_curve.add_point(Vector3.ONE)
	flat_curve.add_point(Vector3.ONE)

	var single_pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_curve_pose(single_curve, 0.5)
	var flat_pose: Dictionary = GF_CURVE_3D_MATH_SCRIPT.sample_curve_pose(flat_curve, 0.5)

	assert_false(GFVariantData.get_option_bool(empty_pose, "ok"))
	assert_false(GFVariantData.get_option_bool(single_pose, "ok"))
	assert_eq(_option_vector3(single_pose, "point"), Vector3(1.0, 2.0, 3.0))
	assert_false(GFVariantData.get_option_bool(flat_pose, "ok"))
	assert_eq(_option_vector3(flat_pose, "point"), Vector3.ONE)


func _option_vector3(options: Dictionary, key: Variant) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Vector3:
		var point: Vector3 = value
		return point
	return Vector3.ZERO
