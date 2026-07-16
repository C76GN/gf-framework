## 测试 GFInputDirectionTools 的二维方向处理行为。
extends GutTest


func test_apply_radial_deadzone_rescales_remaining_range() -> void:
	var result: Vector2 = GFInputDirectionTools.apply_radial_deadzone(Vector2(0.6, 0.0), 0.2)

	assert_almost_eq(result.x, 0.5, 0.001, "死区外剩余行程应重映射到 0..1。")
	assert_almost_eq(result.y, 0.0, 0.001)


func test_apply_radial_deadzone_can_preserve_strength_without_rescale() -> void:
	var result: Vector2 = GFInputDirectionTools.apply_radial_deadzone(Vector2(2.0, 0.0), 0.2, false)

	assert_eq(result, Vector2.RIGHT, "不重映射时仍应钳制到单位长度，避免输出超过输入轴范围。")


func test_snap_vector_supports_axis_cardinal_and_eight_way_modes() -> void:
	assert_eq(
		GFInputDirectionTools.snap_vector(
			Vector2(0.0, 1.0),
			GFInputDirectionTools.SnapMode.HORIZONTAL_2
		),
		Vector2.ZERO,
		"纯垂直输入在水平二向模式下应返回零向量。"
	)
	assert_eq(
		GFInputDirectionTools.snap_vector(
			Vector2(-0.2, 0.9),
			GFInputDirectionTools.SnapMode.VERTICAL_2
		),
		Vector2.DOWN,
		"垂直二向模式应忽略水平分量。"
	)
	assert_eq(
		GFInputDirectionTools.snap_vector(
			Vector2(0.4, 0.8),
			GFInputDirectionTools.SnapMode.CARDINAL_4,
			0.1
		),
		Vector2.DOWN,
		"四方向模式应选择主轴。"
	)
	assert_eq(
		GFInputDirectionTools.snap_vector(
			Vector2(0.4, 0.8),
			GFInputDirectionTools.SnapMode.EIGHT_WAY,
			0.1
		),
		Vector2(1.0, 1.0),
		"八方向模式应允许对角输出。"
	)


func test_snap_vector_applies_deadzone_before_discrete_output() -> void:
	var result: Vector2 = GFInputDirectionTools.snap_vector(
		Vector2(0.1, 0.0),
		GFInputDirectionTools.SnapMode.CARDINAL_4,
		0.2
	)

	assert_eq(result, Vector2.ZERO, "死区内输入不应产生离散方向。")


func test_direction_name_vector_and_opposite_mapping() -> void:
	assert_eq(
		GFInputDirectionTools.get_direction_name(GFInputDirectionTools.Direction2D.UP_RIGHT),
		&"up_right"
	)
	assert_eq(
		GFInputDirectionTools.get_direction_from_name(&"down_left"),
		GFInputDirectionTools.Direction2D.DOWN_LEFT
	)
	assert_eq(
		GFInputDirectionTools.get_direction_from_name(&"missing", GFInputDirectionTools.Direction2D.LEFT),
		GFInputDirectionTools.Direction2D.LEFT
	)
	assert_eq(
		GFInputDirectionTools.get_direction_vector(GFInputDirectionTools.Direction2D.DOWN_RIGHT),
		Vector2(1.0, 1.0)
	)
	assert_eq(
		GFInputDirectionTools.get_opposite_direction(GFInputDirectionTools.Direction2D.UP_RIGHT),
		GFInputDirectionTools.Direction2D.DOWN_LEFT
	)


func test_closest_direction_uses_requested_diagonal_policy() -> void:
	assert_eq(
		GFInputDirectionTools.get_closest_direction(Vector2(0.7, -0.7), true),
		GFInputDirectionTools.Direction2D.UP_RIGHT
	)
	assert_eq(
		GFInputDirectionTools.get_closest_direction(Vector2(0.7, -0.7), false),
		GFInputDirectionTools.Direction2D.RIGHT
	)
