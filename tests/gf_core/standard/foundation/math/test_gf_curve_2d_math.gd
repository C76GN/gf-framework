## 测试 GFCurve2DMath 的折线采样、简化和基础形状生成。
extends GutTest


# --- 测试 ---

func test_polyline_length_and_sampling_use_distance_ratio() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(3.0, 4.0),
			Vector2(13.0, 4.0),
		]
	)

	assert_almost_eq(
		GFCurve2DMath.get_polyline_length(points),
		15.0,
		0.001
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(points, 0.0),
		Vector2.ZERO
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(points, 1.0),
		Vector2(13.0, 4.0)
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(
			points,
			5.0 / 15.0
		),
		Vector2(3.0, 4.0)
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(
			points,
			10.0 / 15.0
		),
		Vector2(8.0, 4.0)
	)


func test_polyline_sampling_handles_empty_single_and_degenerate_inputs() -> void:
	assert_eq(
		GFCurve2DMath.sample_polyline(
			PackedVector2Array(),
			0.5
		),
		Vector2.ZERO
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(
			PackedVector2Array([Vector2(2.0, 3.0)]),
			0.5
		),
		Vector2(2.0, 3.0)
	)
	assert_eq(
		GFCurve2DMath.sample_polyline(
			PackedVector2Array([Vector2.ONE, Vector2.ONE]),
			0.5
		),
		Vector2.ONE
	)


func test_sample_polyline_pose_reports_offset_tangent_and_normal() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(10.0, 0.0),
			Vector2(10.0, 10.0),
		]
	)

	var pose: Dictionary = GFCurve2DMath.sample_polyline_pose(points, 0.75)

	assert_true(
		GFVariantData.get_option_bool(pose, "ok"),
		"有效折线应返回姿态报告。"
	)
	assert_eq(
		_option_vector2(pose, "point"),
		Vector2(10.0, 5.0),
		"采样点应按路径长度比例落在第二段。"
	)
	assert_almost_eq(
		GFVariantData.get_option_float(pose, "offset"),
		15.0,
		0.001
	)
	assert_eq(
		GFVariantData.get_option_int(pose, "segment_index"),
		1,
		"segment_index 应指向采样所在原始线段。"
	)
	assert_almost_eq(
		GFVariantData.get_option_float(pose, "segment_ratio"),
		0.5,
		0.001
	)
	assert_eq(
		_option_vector2(pose, "tangent"),
		Vector2.DOWN,
		"第二段切线应朝下。"
	)
	assert_eq(
		_option_vector2(pose, "normal"),
		Vector2.RIGHT,
		"法线应为切线的正交法线。"
	)


func test_project_point_to_polyline_reports_closest_point_and_closed_segment() -> void:
	var open_points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(10.0, 0.0),
			Vector2(10.0, 10.0),
		]
	)
	var closed_points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(10.0, 0.0),
			Vector2(10.0, 10.0),
			Vector2(0.0, 10.0),
		]
	)

	var open_projection: Dictionary = GFCurve2DMath.project_point_to_polyline(
		open_points,
		Vector2(6.0, 3.0)
	)
	var closed_projection: Dictionary = GFCurve2DMath.project_point_to_polyline(
		closed_points,
		Vector2(-2.0, 5.0),
		true
	)

	assert_true(
		GFVariantData.get_option_bool(open_projection, "ok"),
		"有效折线应返回最近投影报告。"
	)
	assert_eq(
		_option_vector2(open_projection, "point"),
		Vector2(6.0, 0.0),
		"最近点应投影到第一段。"
	)
	assert_almost_eq(
		GFVariantData.get_option_float(open_projection, "distance"),
		3.0,
		0.001
	)
	assert_almost_eq(
		GFVariantData.get_option_float(open_projection, "ratio"),
		0.3,
		0.001
	)
	assert_eq(
		_option_vector2(open_projection, "tangent"),
		Vector2.RIGHT
	)

	assert_true(
		GFVariantData.get_option_bool(closed_projection, "ok"),
		"闭合折线应包含末点回首点线段。"
	)
	assert_eq(
		_option_vector2(closed_projection, "point"),
		Vector2(0.0, 5.0),
		"闭合边应能参与最近点计算。"
	)
	assert_eq(
		GFVariantData.get_option_int(closed_projection, "segment_index"),
		3,
		"闭合边索引应为最后一个原始点。"
	)
	assert_almost_eq(
		GFVariantData.get_option_float(closed_projection, "offset"),
		35.0,
		0.001
	)


func test_smooth_polyline_curve_builds_relative_bezier_handles() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(6.0, 0.0),
			Vector2(6.0, 6.0),
		]
	)

	var curve: Curve2D = GFCurve2DMath.create_smooth_polyline_curve(points)

	assert_eq(curve.point_count, 3)
	assert_eq(
		curve.get_point_position(0),
		Vector2.ZERO
	)
	assert_eq(
		curve.get_point_out(0),
		Vector2(1.0, 0.0),
		"首点应朝下一点生成开放端控制柄。"
	)
	assert_eq(
		curve.get_point_in(1),
		Vector2(-1.0, -1.0),
		"中间点 in 控制柄应相对锚点反向。"
	)
	assert_eq(
		curve.get_point_out(1),
		Vector2(1.0, 1.0),
		"中间点 out 控制柄应沿路径切线。"
	)
	assert_eq(
		curve.get_point_in(2),
		Vector2(0.0, -1.0),
		"末点应从前一点生成开放端控制柄。"
	)
	assert_eq(
		curve.get_point_out(2),
		Vector2.ZERO
	)


func test_smooth_polyline_curve_closes_without_duplicate_input_endpoint() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(6.0, 0.0),
			Vector2(6.0, 6.0),
			Vector2(0.0, 6.0),
			Vector2.ZERO,
		]
	)

	var curve: Curve2D = GFCurve2DMath.create_smooth_polyline_curve(
		points,
		1.0,
		true
	)

	assert_eq(
		curve.point_count,
		5,
		"闭合输入已有重复首尾点时不应生成额外锚点。"
	)
	assert_eq(
		curve.get_point_position(0),
		Vector2.ZERO
	)
	assert_eq(
		curve.get_point_position(curve.point_count - 1),
		Vector2.ZERO
	)
	assert_eq(
		curve.get_point_out(0),
		Vector2(1.0, -1.0),
		"首点切线应使用闭合前后邻居。"
	)
	assert_eq(
		curve.get_point_in(curve.point_count - 1),
		Vector2(-1.0, 1.0),
		"重复闭合锚点应承接最后一段 in 控制柄。"
	)


func test_smooth_polyline_curve_handles_empty_single_reuse_and_zero_tension() -> void:
	var reusable_curve: Curve2D = Curve2D.new()
	reusable_curve.add_point(Vector2(9.0, 9.0))

	var cleared_curve: Curve2D = GFCurve2DMath.set_smooth_polyline_curve(
		reusable_curve,
		PackedVector2Array()
	)
	var single_curve: Curve2D = GFCurve2DMath.create_smooth_polyline_curve(PackedVector2Array([Vector2(2.0, 3.0)]))
	var straight_curve: Curve2D = GFCurve2DMath.create_smooth_polyline_curve(
		PackedVector2Array(
			[
				Vector2.ZERO,
				Vector2(6.0, 0.0),
				Vector2(6.0, 6.0),
			]
		),
		0.0
	)

	assert_eq(cleared_curve, reusable_curve)
	assert_eq(cleared_curve.point_count, 0)
	assert_eq(single_curve.point_count, 1)
	assert_eq(
		single_curve.get_point_position(0),
		Vector2(2.0, 3.0)
	)
	assert_eq(
		straight_curve.get_point_out(0),
		Vector2.ZERO,
		"零强度应生成无控制柄曲线。"
	)
	assert_eq(
		straight_curve.get_point_in(1),
		Vector2.ZERO
	)


func test_create_meandered_polyline_inserts_points_and_anchor_indices() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(10.0, 0.0),
			Vector2(20.0, 0.0),
		]
	)

	var report: Dictionary = GFCurve2DMath.create_meandered_polyline(
		points,
		{ "amplitude": 2.0, "points_per_segment": 1, }
	)

	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"有效折线应返回蜿蜒点列。"
	)
	assert_eq(
		_option_packed_vector2_array(report, "points"),
		PackedVector2Array(
			[
				Vector2.ZERO,
				Vector2(5.0, -2.0),
				Vector2(10.0, 0.0),
				Vector2(15.0, 2.0),
				Vector2(20.0, 0.0),
			]
		)
	)
	assert_eq(
		_option_packed_int32_array(report, "anchor_indices"),
		PackedInt32Array(
			[
				0,
				2,
				4,
			]
		)
	)
	assert_eq(
		GFVariantData.get_option_int(report, "interior_count"),
		2
	)


func test_create_meandered_polyline_clamps_offset_to_segment_length() -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(4.0, 0.0),])

	var report: Dictionary = GFCurve2DMath.create_meandered_polyline(
		points,
		{ "amplitude": 99.0, "points_per_segment": 1, }
	)
	var meandered_points: PackedVector2Array = _option_packed_vector2_array(report, "points")

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		meandered_points.size(),
		3
	)
	assert_eq(
		meandered_points[1],
		Vector2(2.0, -2.0),
		"默认应把偏移限制到线段长度的一半。"
	)


func test_create_meandered_polyline_reports_invalid_inputs() -> void:
	var too_short: Dictionary = GFCurve2DMath.create_meandered_polyline(PackedVector2Array([Vector2.ZERO]))
	var non_finite: Dictionary = GFCurve2DMath.create_meandered_polyline(PackedVector2Array([Vector2.ZERO, Vector2(NAN, 0.0),]))
	var too_many: Dictionary = GFCurve2DMath.create_meandered_polyline(
		PackedVector2Array(
			[
				Vector2.ZERO,
				Vector2.RIGHT,
				Vector2.RIGHT * 2.0,
			]
		),
		{ "points_per_segment": 2, "max_points": 4, }
	)

	assert_false(
		GFVariantData.get_option_bool(too_short, "ok"),
		"少于两个锚点时应返回错误。"
	)
	assert_false(
		GFVariantData.get_option_bool(non_finite, "ok"),
		"非有限坐标不应进入输出点列。"
	)
	assert_false(
		GFVariantData.get_option_bool(too_many, "ok"),
		"超过 max_points 时应返回错误。"
	)
	assert_eq(
		GFVariantData.get_option_int(too_many, "point_count"),
		7,
		"错误报告应暴露预计输出点数。"
	)


func test_create_meandered_polyline_rejects_overflowing_derived_count() -> void:
	var report: Dictionary = GFCurve2DMath.create_meandered_polyline(
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT]),
		{ "points_per_segment": 9_223_372_036_854_775_807, "max_points": 64, }
	)

	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"派生点数溢出不得绕过 max_points。"
	)
	assert_eq(
		GFVariantData.get_option_string(report, "error"),
		"generated point count would exceed max_points."
	)
	assert_true(
		_option_packed_vector2_array(report, "points").is_empty(),
		"失败前不得生成部分点列。"
	)
	assert_gte(
		GFVariantData.get_option_int(report, "point_count"),
		0,
		"失败报告计数不得回绕为负数。"
	)


func test_subdivide_polyline_by_max_segment_length_inserts_even_points_and_anchor_indices() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(10.0, 0.0),
			Vector2(10.0, 5.0),
		]
	)

	var report: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(points, 3.0)

	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"有效折线应返回细分点列。"
	)
	assert_eq(
		_option_packed_vector2_array(report, "points"),
		PackedVector2Array(
			[
				Vector2.ZERO,
				Vector2(2.5, 0.0),
				Vector2(5.0, 0.0),
				Vector2(7.5, 0.0),
				Vector2(10.0, 0.0),
				Vector2(10.0, 2.5),
				Vector2(10.0, 5.0),
			]
		)
	)
	assert_eq(
		_option_packed_int32_array(report, "anchor_indices"),
		PackedInt32Array(
			[
				0,
				4,
				6,
			]
		)
	)
	assert_eq(
		GFVariantData.get_option_int(report, "inserted_count"),
		4
	)
	assert_eq(
		GFVariantData.get_option_int(report, "point_count"),
		7
	)


func test_subdivide_polyline_by_max_segment_length_handles_closed_duplicate_endpoint() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(4.0, 0.0),
			Vector2(4.0, 4.0),
			Vector2(0.0, 4.0),
			Vector2.ZERO,
		]
	)

	var report: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(
		points,
		2.0,
		{ "closed": true, }
	)
	var subdivided_points: PackedVector2Array = _option_packed_vector2_array(report, "points")

	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"闭合折线应允许重复末点输入。"
	)
	assert_true(GFVariantData.get_option_bool(report, "closed"))
	assert_eq(
		GFVariantData.get_option_int(report, "source_count"),
		4
	)
	assert_eq(
		subdivided_points.size(),
		8
	)
	assert_eq(
		_option_packed_int32_array(report, "anchor_indices"),
		PackedInt32Array(
			[
				0,
				2,
				4,
				6,
			]
		)
	)
	assert_eq(
		subdivided_points[subdivided_points.size() - 1],
		Vector2(0.0, 2.0),
		"闭合段应只追加中间点，不重复首点。"
	)


func test_subdivide_polyline_by_max_segment_length_reports_invalid_inputs() -> void:
	var too_short: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(
		PackedVector2Array([Vector2.ZERO,]),
		1.0
	)
	var invalid_length: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT,]),
		0.0
	)
	var non_finite: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(
		PackedVector2Array([Vector2.ZERO, Vector2(INF, 0.0),]),
		1.0
	)
	var too_many: Dictionary = GFCurve2DMath.subdivide_polyline_by_max_segment_length(
		PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0),]),
		1.0,
		{ "max_points": 5, }
	)

	assert_false(
		GFVariantData.get_option_bool(too_short, "ok"),
		"少于两个锚点时应返回错误。"
	)
	assert_false(
		GFVariantData.get_option_bool(invalid_length, "ok"),
		"无效最大段长应返回错误。"
	)
	assert_false(
		GFVariantData.get_option_bool(non_finite, "ok"),
		"非有限坐标不应进入输出点列。"
	)
	assert_false(
		GFVariantData.get_option_bool(too_many, "ok"),
		"超过 max_points 时应返回错误。"
	)
	assert_eq(
		GFVariantData.get_option_int(too_many, "point_count"),
		11,
		"错误报告应暴露预计输出点数。"
	)


func test_simplify_polyline_by_distance_keeps_spacing_and_last_point() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(0.1, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.2, 0.0),
			Vector2(2.0, 0.0),
		]
	)

	var simplified: PackedVector2Array = GFCurve2DMath.simplify_polyline_by_distance(points, 0.75)

	assert_eq(
		simplified,
		PackedVector2Array(
			[
				Vector2(0.0, 0.0),
				Vector2(1.0, 0.0),
				Vector2(2.0, 0.0),
			]
		)
	)


func test_make_dashed_polyline_segments_splits_straight_line() -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0)])

	var segments: Array[PackedVector2Array] = GFCurve2DMath.make_dashed_polyline_segments(
		points,
		3.0,
		2.0
	)

	assert_eq(
		segments.size(),
		2
	)
	assert_eq(
		segments[0],
		PackedVector2Array([Vector2.ZERO, Vector2(3.0, 0.0)])
	)
	assert_eq(
		segments[1],
		PackedVector2Array([Vector2(5.0, 0.0), Vector2(8.0, 0.0)])
	)


func test_make_dashed_polyline_segments_continues_pattern_across_corners() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(6.0, 0.0),
			Vector2(6.0, 6.0),
		]
	)

	var segments: Array[PackedVector2Array] = GFCurve2DMath.make_dashed_polyline_segments(
		points,
		8.0,
		2.0
	)

	assert_eq(
		segments.size(),
		3
	)
	assert_eq(
		segments[0],
		PackedVector2Array([Vector2.ZERO, Vector2(6.0, 0.0)])
	)
	assert_eq(
		segments[1],
		PackedVector2Array([Vector2(6.0, 0.0), Vector2(6.0, 2.0)])
	)
	assert_eq(
		segments[2],
		PackedVector2Array([Vector2(6.0, 4.0), Vector2(6.0, 6.0)])
	)


func test_make_dashed_polyline_segments_supports_offset() -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0)])

	var segments: Array[PackedVector2Array] = GFCurve2DMath.make_dashed_polyline_segments(
		points,
		3.0,
		2.0,
		false,
		2.0
	)

	assert_eq(
		segments.size(),
		3
	)
	assert_eq(
		segments[0],
		PackedVector2Array([Vector2.ZERO, Vector2(1.0, 0.0)])
	)
	assert_eq(
		segments[1],
		PackedVector2Array([Vector2(3.0, 0.0), Vector2(6.0, 0.0)])
	)
	assert_eq(
		segments[2],
		PackedVector2Array([Vector2(8.0, 0.0), Vector2(10.0, 0.0)])
	)


func test_make_dashed_polyline_segments_handles_closed_and_solid_inputs() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2(2.0, 0.0),
			Vector2(2.0, 2.0),
		]
	)

	var segments: Array[PackedVector2Array] = GFCurve2DMath.make_dashed_polyline_segments(
		points,
		1.0,
		0.0,
		true
	)

	assert_eq(
		segments.size(),
		3
	)
	assert_eq(
		segments[0],
		PackedVector2Array([Vector2.ZERO, Vector2(2.0, 0.0)])
	)
	assert_eq(
		segments[1],
		PackedVector2Array([Vector2(2.0, 0.0), Vector2(2.0, 2.0)])
	)
	assert_eq(
		segments[2],
		PackedVector2Array([Vector2(2.0, 2.0), Vector2.ZERO])
	)
	assert_true(
		GFCurve2DMath.make_dashed_polyline_segments(
			points,
			0.0,
			1.0
		).is_empty()
	)


func test_round_polygon_points_generates_corner_anchors_and_samples() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(4.0, 0.0),
			Vector2(4.0, 4.0),
			Vector2(0.0, 4.0),
		]
	)

	var rounded: PackedVector2Array = GFCurve2DMath.round_polygon_points(
		points,
		1.0,
		2
	)

	assert_eq(
		rounded.size(),
		12,
		"每个顶点应输出两侧锚点和细分点。"
	)
	assert_eq(
		rounded[0],
		Vector2(0.0, 1.0),
		"第一个顶点应先输出朝向前一顶点的锚点。"
	)
	assert_eq(
		rounded[2],
		Vector2(1.0, 0.0),
		"第一个顶点应再输出朝向后一顶点的锚点。"
	)
	assert_true(
		rounded[1].x > 0.0 and rounded[1].y > 0.0,
		"细分点应位于圆角内部。"
	)


func test_round_polygon_points_clamps_radius_and_ignores_duplicate_closing_point() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2(0.0, 0.0),
			Vector2(4.0, 0.0),
			Vector2(4.0, 4.0),
			Vector2(0.0, 4.0),
			Vector2(0.0, 0.0),
		]
	)

	var rounded: PackedVector2Array = GFCurve2DMath.round_polygon_points(
		points,
		99.0,
		1
	)

	assert_eq(
		rounded.size(),
		8,
		"重复闭合点不应作为额外顶点参与圆角生成。"
	)
	assert_eq(
		rounded[0],
		Vector2(0.0, 2.0),
		"过大半径应被相邻边长度限制。"
	)
	assert_eq(
		rounded[1],
		Vector2(2.0, 0.0),
		"过大半径应被相邻边长度限制。"
	)


func test_round_polygon_points_returns_unclosed_copy_for_degenerate_inputs() -> void:
	var points: PackedVector2Array = PackedVector2Array(
		[
			Vector2.ZERO,
			Vector2.RIGHT,
			Vector2.ZERO,
		]
	)

	var rounded: PackedVector2Array = GFCurve2DMath.round_polygon_points(
		points,
		0.0,
		8
	)

	assert_eq(
		rounded,
		PackedVector2Array([Vector2.ZERO, Vector2.RIGHT]),
		"无效输入应返回去除重复末点后的副本。"
	)


func test_rect_curve_is_closed_and_reusable() -> void:
	var curve: Curve2D = Curve2D.new()
	var returned: Curve2D = GFCurve2DMath.set_rect_curve(
		curve,
		Vector2(10.0, 4.0)
	)

	assert_eq(returned, curve)
	assert_eq(curve.point_count, 5)
	assert_eq(
		curve.get_point_position(0),
		Vector2(-5.0, -2.0)
	)
	assert_eq(
		curve.get_point_position(curve.point_count - 1),
		curve.get_point_position(0)
	)
	assert_eq(
		GFCurve2DMath.sample_curve(curve, 0.5),
		Vector2(5.0, 2.0)
	)


func test_rounded_rect_curve_clamps_radius() -> void:
	var curve: Curve2D = GFCurve2DMath.create_rect_curve(
		Vector2(10.0, 4.0),
		Vector2(99.0, 99.0)
	)

	assert_eq(curve.point_count, 9)
	assert_eq(
		curve.get_point_position(0),
		Vector2(0.0, -2.0)
	)
	assert_eq(
		curve.get_point_position(curve.point_count - 1),
		curve.get_point_position(0)
	)


func test_ellipse_curve_is_closed_and_centered() -> void:
	var curve: Curve2D = GFCurve2DMath.create_ellipse_curve(
		Vector2(10.0, 4.0),
		Vector2(1.0, 2.0)
	)

	assert_eq(curve.point_count, 5)
	assert_eq(
		curve.get_point_position(0),
		Vector2(6.0, 2.0)
	)
	assert_eq(
		curve.get_point_position(curve.point_count - 1),
		curve.get_point_position(0)
	)
	assert_true(curve.get_baked_length() > 0.0)


func test_cubic_split_preserves_both_parameterized_subcurves() -> void:
	var p0: Vector2 = Vector2(-10.0, 30.0)
	var p1: Vector2 = Vector2(80.0, -45.0)
	var p2: Vector2 = Vector2(-25.0, 75.0)
	var p3: Vector2 = Vector2(60.0, 12.0)
	for t: float in [
		0.0,
		0.19,
		0.5,
		0.83,
		1.0,
	]:
		var cut: Dictionary = GFCurve2DMath.split_cubic_bezier(
			p0,
			p1,
			p2,
			p3,
			t
		)
		assert_true(GFVariantData.get_option_bool(cut, "ok"))
		var left: PackedVector2Array = cut["left"]
		var right: PackedVector2Array = cut["right"]
		assert_eq(
			left.size(),
			4
		)
		assert_eq(
			right.size(),
			4
		)
		assert_eq(
			left[0],
			p0
		)
		assert_eq(
			left[3],
			right[0]
		)
		assert_eq(
			right[3],
			p3
		)
		for sample: int in range(17):
			var u: float = float(sample) / 16.0
			var expected_left: Vector2 = p0.bezier_interpolate(
				p1,
				p2,
				p3,
				t * u
			)
			var expected_right: Vector2 = p0.bezier_interpolate(
				p1,
				p2,
				p3,
				t + (1.0 - t) * u
			)
			assert_lt(
				expected_left.distance_to(
					left[0].bezier_interpolate(
						left[1],
						left[2],
						left[3],
						u
					)
				),
				0.00003
			)
			assert_lt(
				expected_right.distance_to(
					right[0].bezier_interpolate(
						right[1],
						right[2],
						right[3],
						u
					)
				),
				0.00003
			)


func test_cubic_projection_returns_parameter_and_distinguishes_exhaustion() -> void:
	var origin: Vector2 = Vector2.ZERO
	var end: Vector2 = Vector2(100.0, 0.0)
	var target: Vector2 = Vector2(50.0, 0.0)
	var result: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		origin,
		origin,
		origin,
		end,
		target,
		0.000001
	)
	assert_true(GFVariantData.get_option_bool(result, "converged"))
	assert_almost_eq(
		GFVariantData.get_option_float(result, "t"),
		pow(
			0.5,
			1.0 / 3.0
		),
		0.000001
	)
	assert_lte(
		GFVariantData.get_option_float(result, "distance"),
		0.000001
	)
	var limited: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		origin,
		origin,
		origin,
		end,
		target,
		0.000001,
		1
	)
	assert_true(GFVariantData.get_option_bool(limited, "ok"))
	assert_false(
		GFVariantData.get_option_bool(
			limited,
			"converged",
			true
		)
	)
	assert_eq(
		GFVariantData.get_option_int(limited, "subdivisions"),
		1
	)
	assert_eq(
		GFVariantData.get_option_vector2(limited, "point"),
		Vector2(12.5, 0.0)
	)
	assert_eq(
		GFVariantData.get_option_float(limited, "error_bound"),
		37.5
	)
	var endpoint: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		origin,
		origin,
		origin,
		end,
		end,
		0.0,
		0
	)
	assert_eq(
		GFVariantData.get_option_float(endpoint, "t"),
		1.0
	)
	assert_true(GFVariantData.get_option_bool(endpoint, "converged"))
	var constant: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		end,
		end,
		end,
		end,
		target,
		0.0,
		0
	)
	assert_eq(
		GFVariantData.get_option_float(constant, "t"),
		0.0
	)
	assert_eq(
		GFVariantData.get_option_float(constant, "distance"),
		50.0
	)
	assert_true(GFVariantData.get_option_bool(constant, "converged"))


func test_cubic_projection_searches_competing_minima_and_handles_self_intersection() -> void:
	# y=1-x² 对原点的最小距离为 sqrt(3)/2，最近点分居两侧。
	var arch: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		Vector2(-1.0, 0.0),
		Vector2(
			-1.0 / 3.0,
			4.0 / 3.0
		),
		Vector2(
			1.0 / 3.0,
			4.0 / 3.0
		),
		Vector2(1.0, 0.0),
		Vector2.ZERO,
		0.0001,
		2048
	)
	assert_true(GFVariantData.get_option_bool(arch, "converged"))
	assert_almost_eq(
		GFVariantData.get_option_float(arch, "distance"),
		sqrt(3.0) * 0.5,
		0.0001
	)
	assert_lte(
		GFVariantData.get_option_float(arch, "error_bound"),
		0.0001
	)
	var target: Vector2 = Vector2.ZERO
	var loop: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		Vector2(9.0, -18.0),
		Vector2(-7.0, 26.0),
		Vector2(-7.0, -26.0),
		Vector2(9.0, 18.0),
		target,
		0.0
	)
	assert_true(GFVariantData.get_option_bool(loop, "converged"))
	assert_eq(
		GFVariantData.get_option_float(loop, "distance"),
		0.0
	)
	assert_eq(
		GFVariantData.get_option_float(loop, "t"),
		0.25
	)


func test_cubic_split_and_projection_keep_a_small_representable_term_after_cancellation() -> void:
	var large: float = 1152921504606846976.0
	var p0: Vector2 = Vector2(large, 0.0)
	var p1: Vector2 = Vector2.RIGHT
	var p2: Vector2 = Vector2.ZERO
	var p3: Vector2 = -p0
	var half: Dictionary = GFCurve2DMath.split_cubic_bezier(
		p0,
		p1,
		p2,
		p3,
		0.5
	)
	var left: PackedVector2Array = half["left"]
	var right: PackedVector2Array = half["right"]
	assert_eq(
		left[3],
		Vector2(0.375, 0.0)
	)
	assert_eq(
		left[3],
		right[0]
	)
	var quarter: Dictionary = GFCurve2DMath.split_cubic_bezier(
		p0,
		p1,
		p2,
		27.0 * p3,
		0.25
	)
	var quarter_left: PackedVector2Array = quarter["left"]
	assert_eq(
		quarter_left[3],
		Vector2(
			27.0 / 64.0,
			0.0
		)
	)
	var hit: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		p0,
		p1,
		p2,
		p3,
		Vector2.ZERO
	)
	assert_true(GFVariantData.get_option_bool(hit, "ok"))
	assert_false(
		GFVariantData.get_option_bool(
			hit,
			"converged",
			true
		)
	)
	assert_eq(
		GFVariantData.get_option_float(hit, "t"),
		0.5
	)
	assert_eq(
		GFVariantData.get_option_float(hit, "distance"),
		0.375
	)
	assert_gte(
		GFVariantData.get_option_float(hit, "error_bound"),
		0.375
	)


func test_cubic_split_next_to_an_endpoint_preserves_the_short_remainder() -> void:
	# 这里的原曲线是 x(t) = 3b(1-t)²t，短子段的两个非零控制点可以独立算出。
	var b: float = 972556992512.0
	var offset: float = pow(2.0, -53.0)
	var t: float = 1.0 - offset
	var cut: Dictionary = GFCurve2DMath.split_cubic_bezier(
		Vector2.ZERO,
		Vector2(b, 0.0),
		Vector2.ZERO,
		Vector2.ZERO,
		t
	)
	var left: PackedVector2Array = cut["left"]
	var right: PackedVector2Array = cut["right"]
	assert_eq(
		left[2],
		Vector2(
			2.0 * b * offset * t,
			0.0
		)
	)
	assert_eq(
		right[0],
		Vector2(
			3.0 * b * offset * offset * t,
			0.0
		)
	)
	assert_eq(
		right[1],
		Vector2(
			b * offset * offset,
			0.0
		)
	)


func test_cubic_projection_large_translation_preserves_the_distance_at_the_returned_parameter() -> void:
	# x=2^60 + 2^42*t³。最接近根的 binary64 参数仍留下可用有理数独立复算的距离。
	var origin: Vector2 = Vector2(1152921504606846976.0, 0.0)
	var end: Vector2 = Vector2(1152925902653358080.0, 0.0)
	var target: Vector2 = Vector2(1152923703630102528.0, 0.0)
	var hit: Dictionary = GFCurve2DMath.project_point_to_cubic_bezier(
		origin,
		origin,
		origin,
		end,
		target,
		0.0
	)
	assert_true(GFVariantData.get_option_bool(hit, "ok"))
	assert_false(
		GFVariantData.get_option_bool(
			hit,
			"converged",
			true
		)
	)
	assert_eq(
		GFVariantData.get_option_float(hit, "t"),
		0.7937005259840998
	)
	assert_almost_eq(
		GFVariantData.get_option_float(hit, "distance"),
		0.000451704408678414,
		1.0e-15
	)
	assert_gte(
		GFVariantData.get_option_float(hit, "error_bound"),
		0.000451704408678414
	)
	assert_eq(
		GFVariantData.get_option_vector2(hit, "point"),
		target
	)


func test_cubic_operations_reject_invalid_domains() -> void:
	var p: Vector2 = Vector2.ZERO
	for t: float in [
		-0.01,
		1.01,
		INF,
		NAN,
	]:
		var invalid: Dictionary = GFCurve2DMath.split_cubic_bezier(
			p,
			p,
			p,
			p,
			t
		)
		assert_false(
			GFVariantData.get_option_bool(
				invalid,
				"ok",
				true
			)
		)
		assert_eq(
			_option_packed_vector2_array(invalid, "left"),
			PackedVector2Array()
		)
	var bad_point: Vector2 = Vector2(INF, 0.0)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.split_cubic_bezier(
				p,
				bad_point,
				p,
				p,
				0.5
			),
			"ok",
			true
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.project_point_to_cubic_bezier(
				p,
				p,
				p,
				p,
				bad_point
			),
			"ok",
			true
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.project_point_to_cubic_bezier(
				p,
				p,
				p,
				p,
				p,
				-0.1
			),
			"ok",
			true
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.project_point_to_cubic_bezier(
				p,
				p,
				p,
				p,
				p,
				INF
			),
			"ok",
			true
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.project_point_to_cubic_bezier(
				p,
				p,
				p,
				p,
				p,
				1.0,
				-1
			),
			"ok",
			true
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			GFCurve2DMath.project_point_to_cubic_bezier(
				p,
				p,
				p,
				p,
				p,
				1.0,
				4097
			),
			"ok",
			true
		)
	)


func _option_vector2(options: Dictionary, key: Variant) -> Vector2:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Vector2:
		var point: Vector2 = value
		return point
	return Vector2.ZERO


func _option_packed_vector2_array(options: Dictionary, key: Variant) -> PackedVector2Array:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is PackedVector2Array:
		var points: PackedVector2Array = value
		return points
	return PackedVector2Array()


func _option_packed_int32_array(options: Dictionary, key: Variant) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is PackedInt32Array:
		var indices: PackedInt32Array = value
		return indices
	return PackedInt32Array()
