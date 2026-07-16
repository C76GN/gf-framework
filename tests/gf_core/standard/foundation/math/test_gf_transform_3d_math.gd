## 测试 GFTransform3DMath 的平面反射纯算法。
extends GutTest


# --- 测试 ---

func test_reflect_point_uses_plane_normal_and_point() -> void:
	var reflected: Vector3 = GFTransform3DMath.reflect_point(
		Vector3(4.0, 2.0, -3.0),
		Vector3.RIGHT,
		Vector3(1.0, 0.0, 0.0)
	)

	assert_true(_vector3_is_equal_approx(reflected, Vector3(-2.0, 2.0, -3.0)), "点应按 x=1 平面反射。")


func test_reflect_direction_ignores_plane_offset() -> void:
	var reflected: Vector3 = GFTransform3DMath.reflect_direction(
		Vector3(2.0, -3.0, 4.0),
		Vector3.RIGHT * 3.0
	)

	assert_true(_vector3_is_equal_approx(reflected, Vector3(-2.0, -3.0, 4.0)), "方向应只受法线影响。")


func test_make_reflection_transform_matches_point_reflection() -> void:
	var reflection_transform: Transform3D = GFTransform3DMath.make_reflection_transform(
		Vector3.UP,
		Vector3(0.0, 2.0, 0.0)
	)
	var point: Vector3 = Vector3(1.0, 5.0, -2.0)
	var transformed_point: Vector3 = reflection_transform * point
	var reflected_point: Vector3 = GFTransform3DMath.reflect_point(point, Vector3.UP, Vector3(0.0, 2.0, 0.0))

	assert_true(_vector3_is_equal_approx(transformed_point, reflected_point), "反射 Transform 应与点反射结果一致。")
	assert_true(_vector3_is_equal_approx(transformed_point, Vector3(1.0, -1.0, -2.0)), "点应按 y=2 平面反射。")


func test_reflect_transform_reflects_origin_and_basis_axes() -> void:
	var source: Transform3D = Transform3D(
		Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK),
		Vector3(3.0, 2.0, 1.0)
	)
	var reflected: Transform3D = GFTransform3DMath.reflect_transform(source, Vector3.RIGHT, Vector3.ZERO)

	assert_true(_vector3_is_equal_approx(reflected.origin, Vector3(-3.0, 2.0, 1.0)), "Transform 原点应被反射。")
	assert_true(_vector3_is_equal_approx(reflected.basis.x, Vector3.LEFT), "局部 X 轴应被反射。")
	assert_true(_vector3_is_equal_approx(reflected.basis.y, Vector3.UP), "局部 Y 轴应保持。")
	assert_true(_vector3_is_equal_approx(reflected.basis.z, Vector3.BACK), "局部 Z 轴应保持。")


func test_zero_plane_normal_returns_identity_or_original_values() -> void:
	var point: Vector3 = Vector3(1.0, 2.0, 3.0)
	var direction: Vector3 = Vector3(4.0, 5.0, 6.0)
	var transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(7.0, 8.0, 9.0))

	assert_eq(GFTransform3DMath.make_reflection_transform(Vector3.ZERO, point), Transform3D.IDENTITY, "零法线无法定义平面。")
	assert_eq(GFTransform3DMath.reflect_point(point, Vector3.ZERO, Vector3.ZERO), point, "零法线应返回原点值。")
	assert_eq(GFTransform3DMath.reflect_direction(direction, Vector3.ZERO), direction, "零法线应返回原方向。")
	assert_eq(GFTransform3DMath.reflect_transform(transform, Vector3.ZERO, Vector3.ZERO), transform, "零法线应返回原 Transform。")


func test_intersect_ray_plane_reports_position_distance_and_facing_normal() -> void:
	var report: Dictionary = GFTransform3DMath.intersect_ray_plane(
		Vector3(0.0, 5.0, 0.0),
		Vector3.DOWN * 4.0,
		Vector3.UP,
		Vector3.ZERO
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "向下射线应命中 XZ 平面。")
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"", "命中时 reason 应为空。")
	assert_true(_vector3_is_equal_approx(GFVariantData.get_option_vector3(report, "position"), Vector3.ZERO), "交点应位于原点。")
	assert_true(_vector3_is_equal_approx(GFVariantData.get_option_vector3(report, "normal"), Vector3.UP), "法线应朝向射线来源。")
	assert_almost_eq(GFVariantData.get_option_float(report, "distance"), 5.0, 0.001, "距离应使用归一化射线方向。")


func test_intersect_ray_plane_rejects_parallel_and_beyond_max_distance() -> void:
	var parallel_report: Dictionary = GFTransform3DMath.intersect_ray_plane(
		Vector3.ZERO,
		Vector3.RIGHT,
		Vector3.UP,
		Vector3.ZERO
	)
	var distance_report: Dictionary = GFTransform3DMath.intersect_ray_plane(
		Vector3(0.0, 5.0, 0.0),
		Vector3.DOWN,
		Vector3.UP,
		Vector3.ZERO,
		3.0
	)

	assert_false(GFVariantData.get_option_bool(parallel_report, "ok"), "平行射线不应报告命中。")
	assert_eq(GFVariantData.get_option_string_name(parallel_report, "reason"), &"parallel", "平行失败应有稳定 reason。")
	assert_false(GFVariantData.get_option_bool(distance_report, "ok"), "超过最大距离不应报告命中。")
	assert_eq(GFVariantData.get_option_string_name(distance_report, "reason"), &"beyond_max_distance", "距离失败应有稳定 reason。")


func test_make_basis_from_up_and_z_hint_handles_parallel_hint() -> void:
	var basis: Basis = GFTransform3DMath.make_basis_from_up_and_z_hint(Vector3.UP, Vector3.UP)

	assert_true(_vector3_is_equal_approx(basis.y, Vector3.UP), "局部 Y 轴应贴合法线。")
	assert_almost_eq(basis.x.length(), 1.0, 0.001, "局部 X 轴应归一化。")
	assert_almost_eq(basis.z.length(), 1.0, 0.001, "局部 Z 轴应归一化。")
	assert_almost_eq(absf(basis.y.dot(basis.z)), 0.0, 0.001, "局部 Y/Z 轴应正交。")


func test_scale_axis_mode_locks_interpolation_weights() -> void:
	var weight: Vector3 = Vector3(0.25, 0.5, 0.75)
	var locked_weight: Vector3 = GFTransform3DMath.apply_scale_axis_mode(
		weight,
		GFTransform3DMath.ScaleAxisMode.LOCK_XY
	)
	var scale: Vector3 = GFTransform3DMath.interpolate_scale(
		Vector3(1.0, 10.0, 100.0),
		Vector3(5.0, 20.0, 300.0),
		weight,
		GFTransform3DMath.ScaleAxisMode.LOCK_XY
	)

	assert_true(_vector3_is_equal_approx(locked_weight, Vector3(0.25, 0.25, 0.75)), "LOCK_XY 应让 X/Y 共用 X 权重。")
	assert_true(_vector3_is_equal_approx(scale, Vector3(2.0, 12.5, 250.0)), "缩放插值应使用轴锁后的权重。")
	assert_true(
		_vector3_is_equal_approx(
			GFTransform3DMath.apply_scale_axis_mode(weight, GFTransform3DMath.ScaleAxisMode.UNIFORM),
			Vector3(0.25, 0.25, 0.25)
		),
		"UNIFORM 应让所有轴共用 X 权重。"
	)


func test_snap_point_to_plane_grid_preserves_normal_distance() -> void:
	var report: Dictionary = GFTransform3DMath.snap_point_to_plane_grid(
		Vector3(1.26, 2.5, 2.74),
		Vector3.UP,
		0.5
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效平面和步长应吸附成功。")
	assert_true(_vector3_is_equal_approx(GFVariantData.get_option_vector3(report, "point"), Vector3(1.5, 2.5, 2.5)), "点应只沿平面切向网格吸附。")
	assert_almost_eq(GFVariantData.get_option_float(report, "normal_distance"), 2.5, 0.001, "法线距离应保留。")


func test_snap_point_to_plane_grid_respects_plane_origin() -> void:
	var report: Dictionary = GFTransform3DMath.snap_point_to_plane_grid(
		Vector3(1.26, 0.0, 2.74),
		Vector3.UP,
		0.5,
		Vector3(0.25, 0.0, 0.25)
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效平面和原点应吸附成功。")
	assert_true(_vector3_is_equal_approx(GFVariantData.get_option_vector3(report, "point"), Vector3(1.25, 0.0, 2.75)), "网格原点应偏移吸附坐标。")


func test_move_local_point_to_world_offsets_transform_origin() -> void:
	var transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	var adjusted: Transform3D = GFTransform3DMath.move_local_point_to_world(
		transform,
		Vector3(0.0, -2.0, 0.0),
		Vector3(1.0, 3.0, 4.0)
	)

	assert_true(_vector3_is_equal_approx(adjusted * Vector3(0.0, -2.0, 0.0), Vector3(1.0, 3.0, 4.0)), "指定本地锚点应落到目标世界点。")
	assert_true(_vector3_is_equal_approx(adjusted.origin, Vector3(1.0, 5.0, 4.0)), "Transform 原点应按锚点差值平移。")


# --- 私有/辅助方法 ---

func _vector3_is_equal_approx(left: Vector3, right: Vector3) -> bool:
	return left.is_equal_approx(right)
