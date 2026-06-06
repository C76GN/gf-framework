## 测试 GFPolynomialMath 的多项式计算、导数、系数生成和实根求解。
extends GutTest


const GF_POLYNOMIAL_MATH = preload("res://addons/gf/standard/foundation/math/gf_polynomial_math.gd")


# --- 测试 ---

func test_evaluate_uses_high_to_low_coefficients() -> void:
	var value: float = GF_POLYNOMIAL_MATH.evaluate(PackedFloat64Array([2.0, -3.0, 1.0]), 4.0)

	assert_almost_eq(value, 21.0, 0.000001, "2x^2 - 3x + 1 在 x=4 时应为 21。")


func test_derivative_returns_high_to_low_coefficients() -> void:
	var derivative: PackedFloat64Array = GF_POLYNOMIAL_MATH.derivative(PackedFloat64Array([3.0, -4.0, 0.0, 8.0]))

	assert_eq(Array(derivative), [9.0, -8.0, 0.0], "3x^3 - 4x^2 + 8 的导数应为 9x^2 - 8x。")


func test_from_roots_builds_polynomial_coefficients() -> void:
	var coefficients: PackedFloat64Array = GF_POLYNOMIAL_MATH.from_roots(PackedFloat64Array([1.0, 2.0, 3.0]))

	_assert_roots_or_coefficients_close(coefficients, PackedFloat64Array([1.0, -6.0, 11.0, -6.0]))


func test_real_roots_solves_linear_polynomial() -> void:
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(PackedFloat64Array([2.0, -4.0]))

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([2.0]))


func test_real_roots_solves_quadratic_polynomial() -> void:
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(PackedFloat64Array([1.0, -5.0, 6.0]))

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([2.0, 3.0]))


func test_real_roots_omits_complex_quadratic_roots() -> void:
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(PackedFloat64Array([1.0, 0.0, 1.0]))

	assert_eq(roots.size(), 0, "x^2 + 1 不应报告实根。")


func test_real_roots_merges_repeated_quadratic_root() -> void:
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(PackedFloat64Array([1.0, -2.0, 1.0]))

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([1.0]))


func test_real_roots_solves_cubic_polynomial() -> void:
	var coefficients: PackedFloat64Array = GF_POLYNOMIAL_MATH.from_roots(PackedFloat64Array([-2.0, 1.0, 3.0]))
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(coefficients)

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([-2.0, 1.0, 3.0]), 0.0001)


func test_real_roots_finds_even_multiplicity_root_from_derivative_point() -> void:
	var coefficients: PackedFloat64Array = GF_POLYNOMIAL_MATH.from_roots(PackedFloat64Array([-2.0, -2.0, 0.5, 4.0]))
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(coefficients, { "epsilon": 0.00001 })

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([-2.0, 0.5, 4.0]), 0.001)


func test_real_roots_can_limit_search_range() -> void:
	var coefficients: PackedFloat64Array = GF_POLYNOMIAL_MATH.from_roots(PackedFloat64Array([-1.0, 1.0, 3.0]))
	var roots: PackedFloat64Array = GF_POLYNOMIAL_MATH.real_roots(coefficients, {
		"min_x": 0.0,
		"max_x": 2.0,
	})

	_assert_roots_or_coefficients_close(roots, PackedFloat64Array([1.0]))


func test_normalize_coefficients_removes_leading_zero_terms() -> void:
	var coefficients: PackedFloat64Array = GF_POLYNOMIAL_MATH.normalize_coefficients(PackedFloat64Array([0.0, 0.00000001, 2.0, -1.0]))

	assert_eq(Array(coefficients), [2.0, -1.0], "前导近零项应被移除。")


# --- 辅助断言 ---

func _assert_roots_or_coefficients_close(
	actual: PackedFloat64Array,
	expected: PackedFloat64Array,
	epsilon: float = 0.000001
) -> void:
	assert_eq(actual.size(), expected.size(), "结果数量应符合预期。")
	for index: int in range(mini(actual.size(), expected.size())):
		var actual_value: float = actual[index]
		var expected_value: float = expected[index]
		assert_almost_eq(actual_value, expected_value, epsilon, "第 %s 项应接近预期值。" % index)
