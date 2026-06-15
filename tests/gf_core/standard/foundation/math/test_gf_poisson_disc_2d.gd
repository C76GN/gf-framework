## 测试 GFPoissonDisc2D 的确定性二维最小距离采样。
extends GutTest


# --- 常量 ---

const GFPoissonDisc2DBase = preload("res://addons/gf/standard/foundation/math/gf_poisson_disc_2d.gd")


# --- 测试方法 ---

## 验证采样结果都位于区域内，且任意两点满足最小距离。
func test_generate_points_respects_area_and_minimum_distance() -> void:
	var result: Dictionary = GFPoissonDisc2DBase.generate_points(
		Rect2(Vector2.ZERO, Vector2(20.0, 12.0)),
		2.0,
		{ "seed": 42 }
	)

	assert_true(GFVariantData.get_option_bool(result, "ok", false), "有效区域和半径应成功生成。")
	assert_true(GFVariantData.get_option_int(result, "point_count", 0) > 1, "采样结果应包含多个点。")
	_assert_points_inside_area(_get_points(result), GFVariantData.get_option_value(result, "area"))
	_assert_points_separated(_get_points(result), GFVariantData.get_option_float(result, "minimum_distance"))


## 验证相同 seed 和选项会产生稳定结果。
func test_generate_points_is_deterministic_for_same_seed() -> void:
	var options: Dictionary = {
		"seed": 7,
		"candidate_attempts": 12,
		"start_point": Vector2(1.0, 1.0),
	}
	var first: Dictionary = GFPoissonDisc2DBase.generate_points(Rect2(Vector2.ZERO, Vector2(10.0, 10.0)), 1.5, options)
	var second: Dictionary = GFPoissonDisc2DBase.generate_points(Rect2(Vector2.ZERO, Vector2(10.0, 10.0)), 1.5, options)

	assert_eq(_get_points(first), _get_points(second), "相同输入应生成相同点集。")
	assert_eq(_get_points(first)[0], Vector2(1.0, 1.0), "显式 start_point 应作为第一个点。")


## 验证固定随机源的采样 golden，避免实现回退到 Godot RNG 算法。
func test_generate_points_matches_fixed_rng_golden_points() -> void:
	var result: Dictionary = GFPoissonDisc2DBase.generate_points(
		Rect2(Vector2.ZERO, Vector2(10.0, 10.0)),
		1.5,
		{
			"seed": 7,
			"candidate_attempts": 12,
			"start_point": Vector2(1.0, 1.0),
			"max_points": 8,
		}
	)
	var points: PackedVector2Array = _get_points(result)

	assert_true(GFVariantData.get_option_bool(result, "ok", false), "有效输入应成功生成。")
	assert_eq(points.size(), 8, "golden 样本应锁定输出数量。")
	_assert_point_close(points[0], Vector2(1.0, 1.0))
	_assert_point_close(points[1], Vector2(3.20593429, 2.81375337))
	_assert_point_close(points[2], Vector2(4.85753727, 3.47077560))
	_assert_point_close(points[3], Vector2(7.34734821, 4.84586191))
	_assert_point_close(points[4], Vector2(0.74436307, 3.22501755))
	_assert_point_close(points[5], Vector2(5.69364309, 2.01146173))
	_assert_point_close(points[6], Vector2(6.48056173, 0.50330520))
	_assert_point_close(points[7], Vector2(3.93613601, 0.29261178))


## 验证 max_points 会限制输出并报告截断。
func test_generate_points_respects_max_points() -> void:
	var result: Dictionary = GFPoissonDisc2DBase.generate_points(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		1.0,
		{
			"seed": 9,
			"max_points": 5,
		}
	)

	assert_true(GFVariantData.get_option_bool(result, "ok", false), "达到 max_points 是有效截断，不是输入错误。")
	assert_eq(GFVariantData.get_option_int(result, "point_count", 0), 5, "输出点数不应超过 max_points。")
	assert_true(GFVariantData.get_option_bool(result, "truncated", false), "仍有活动点时达到上限应标记截断。")


## 验证无效输入返回结构化失败结果。
func test_generate_points_reports_invalid_input() -> void:
	var invalid_area: Dictionary = GFPoissonDisc2DBase.generate_points(Rect2(Vector2.ZERO, Vector2.ZERO), 1.0)
	var invalid_distance: Dictionary = GFPoissonDisc2DBase.generate_points(Rect2(Vector2.ZERO, Vector2.ONE), 0.0)
	var invalid_start: Dictionary = GFPoissonDisc2DBase.generate_points(
		Rect2(Vector2.ZERO, Vector2.ONE),
		0.2,
		{ "start_point": Vector2(3.0, 3.0) }
	)
	var too_many_grid_cells: Dictionary = GFPoissonDisc2DBase.generate_points(
		Rect2(Vector2.ZERO, Vector2(100.0, 100.0)),
		0.1,
		{ "max_grid_cells": 16 }
	)

	assert_false(GFVariantData.get_option_bool(invalid_area, "ok", true), "空区域应失败。")
	assert_false(GFVariantData.get_option_bool(invalid_distance, "ok", true), "非正最小距离应失败。")
	assert_false(GFVariantData.get_option_bool(invalid_start, "ok", true), "区域外起始点应失败。")
	assert_false(GFVariantData.get_option_bool(too_many_grid_cells, "ok", true), "网格单元超出上限应失败。")
	assert_eq(_get_points(invalid_area), PackedVector2Array(), "失败结果不应携带采样点。")


# --- 私有/辅助方法 ---

func _get_points(result: Dictionary) -> PackedVector2Array:
	var value: Variant = result.get("points", PackedVector2Array())
	if value is PackedVector2Array:
		return value
	return PackedVector2Array()


func _assert_points_inside_area(points: PackedVector2Array, area_value: Variant) -> void:
	var area: Rect2 = Rect2()
	if area_value is Rect2:
		area = area_value
	for point: Vector2 in points:
		assert_true(area.has_point(point), "采样点必须位于区域内。")


func _assert_points_separated(points: PackedVector2Array, minimum_distance: float) -> void:
	var minimum_distance_squared: float = minimum_distance * minimum_distance
	for index: int in range(points.size()):
		for other_index: int in range(index + 1, points.size()):
			assert_true(
				points[index].distance_squared_to(points[other_index]) >= minimum_distance_squared,
				"任意两个采样点之间应满足最小距离。"
			)


func _assert_point_close(actual: Vector2, expected: Vector2) -> void:
	assert_almost_eq(actual.x, expected.x, 0.00001)
	assert_almost_eq(actual.y, expected.y, 0.00001)
