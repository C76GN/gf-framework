## GFPolynomialMath: 通用实数多项式数学工具。
##
## 使用高阶到低阶的系数顺序，例如 x^2 - 5x + 6 表示为 [1, -5, 6]。
## 工具只提供纯计算能力，不解释项目公式、曲线配置或业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFPolynomialMath
extends RefCounted


# --- 常量 ---

## 默认浮点容差。
## [br]
## @api public
const DEFAULT_EPSILON: float = 0.000001

## 默认根合并距离。
## [br]
## @api public
const DEFAULT_ROOT_MERGE_EPSILON: float = 0.00001

## 默认二分迭代次数。
## [br]
## @api public
const DEFAULT_MAX_ITERATIONS: int = 96

## 默认允许的最高次数。
## [br]
## @api public
const DEFAULT_MAX_DEGREE: int = 12


# --- 公共方法 ---

## 移除前导近零系数。
## [br]
## @api public
## [br]
## @param coefficients: 高阶到低阶排列的多项式系数。
## [br]
## @param epsilon: 小于等于该绝对值的前导项会被视为 0。
## [br]
## @return 规范化后的系数；零多项式返回空数组。
## [br]
## @schema coefficients: PackedFloat64Array high-to-low polynomial coefficients.
static func normalize_coefficients(
	coefficients: PackedFloat64Array,
	epsilon: float = DEFAULT_EPSILON
) -> PackedFloat64Array:
	if _has_non_finite_coefficients(coefficients):
		push_error("[GFPolynomialMath] coefficients 必须是有限数字。")
		return PackedFloat64Array()

	var threshold: float = absf(epsilon)
	var start_index: int = 0
	while start_index < coefficients.size() and absf(coefficients[start_index]) <= threshold:
		start_index += 1

	var result: PackedFloat64Array = PackedFloat64Array()
	for index: int in range(start_index, coefficients.size()):
		var _coefficient_appended: bool = result.append(coefficients[index])
	return result


## 使用 Horner 法计算多项式在 x 处的值。
## [br]
## @api public
## [br]
## @param coefficients: 高阶到低阶排列的多项式系数。
## [br]
## @param x: 采样位置。
## [br]
## @return 多项式值；非法输入返回 NAN。
## [br]
## @schema coefficients: PackedFloat64Array high-to-low polynomial coefficients.
static func evaluate(coefficients: PackedFloat64Array, x: float) -> float:
	if _has_non_finite_coefficients(coefficients) or is_nan(x) or is_inf(x):
		push_error("[GFPolynomialMath] evaluate 输入必须是有限数字。")
		return NAN

	var result: float = 0.0
	for coefficient: float in coefficients:
		result = result * x + coefficient
	return result


## 计算导函数系数。
## [br]
## @api public
## [br]
## @param coefficients: 高阶到低阶排列的多项式系数。
## [br]
## @param epsilon: 前导项规范化容差。
## [br]
## @return 导函数系数；常量或零多项式返回空数组。
## [br]
## @schema coefficients: PackedFloat64Array high-to-low polynomial coefficients.
static func derivative(
	coefficients: PackedFloat64Array,
	epsilon: float = DEFAULT_EPSILON
) -> PackedFloat64Array:
	var normalized: PackedFloat64Array = normalize_coefficients(coefficients, epsilon)
	var degree: int = normalized.size() - 1
	if degree <= 0:
		return PackedFloat64Array()

	var result: PackedFloat64Array = PackedFloat64Array()
	for index: int in range(normalized.size() - 1):
		var _coefficient_appended: bool = result.append(normalized[index] * float(degree - index))
	return normalize_coefficients(result, epsilon)


## 根据实根生成多项式系数。
## [br]
## @api public
## [br]
## @param roots: 多项式实根列表，每个根生成一个 (x - root) 因子。
## [br]
## @param leading_coefficient: 最高阶系数。
## [br]
## @return 高阶到低阶排列的系数；leading_coefficient 为 0 时返回空数组。
static func from_roots(
	roots: PackedFloat64Array,
	leading_coefficient: float = 1.0
) -> PackedFloat64Array:
	if is_nan(leading_coefficient) or is_inf(leading_coefficient):
		push_error("[GFPolynomialMath] leading_coefficient 必须是有限数字。")
		return PackedFloat64Array()
	if is_zero_approx(leading_coefficient):
		return PackedFloat64Array()

	var polynomial: PackedFloat64Array = PackedFloat64Array([leading_coefficient])
	for root: float in roots:
		if is_nan(root) or is_inf(root):
			push_error("[GFPolynomialMath] roots 必须是有限数字。")
			return PackedFloat64Array()

		var next_polynomial: PackedFloat64Array = PackedFloat64Array()
		var _resize_result: int = next_polynomial.resize(polynomial.size() + 1)
		for index: int in range(polynomial.size()):
			next_polynomial[index] += polynomial[index]
			next_polynomial[index + 1] -= polynomial[index] * root
		polynomial = next_polynomial

	return polynomial


## 求多项式的实根。
## [br]
## @api public
## [br]
## @param coefficients: 高阶到低阶排列的多项式系数。
## [br]
## @param options: 可选参数，支持 epsilon、root_merge_epsilon、max_iterations、max_degree、min_x 和 max_x。
## [br]
## @return 升序排列的实根列表，重复根会按 root_merge_epsilon 合并。
## [br]
## @schema coefficients: PackedFloat64Array high-to-low polynomial coefficients.
## [br]
## @schema options: Dictionary with optional epsilon: float, root_merge_epsilon: float, max_iterations: int, max_degree: int, min_x: float, and max_x: float.
static func real_roots(
	coefficients: PackedFloat64Array,
	options: Dictionary = {}
) -> PackedFloat64Array:
	var epsilon: float = maxf(absf(GFVariantData.get_option_float(options, "epsilon", DEFAULT_EPSILON)), DEFAULT_EPSILON)
	var merge_epsilon: float = maxf(
		absf(GFVariantData.get_option_float(options, "root_merge_epsilon", DEFAULT_ROOT_MERGE_EPSILON)),
		epsilon
	)
	var max_iterations: int = maxi(GFVariantData.get_option_int(options, "max_iterations", DEFAULT_MAX_ITERATIONS), 1)
	var max_degree: int = maxi(GFVariantData.get_option_int(options, "max_degree", DEFAULT_MAX_DEGREE), 1)
	var normalized: PackedFloat64Array = normalize_coefficients(coefficients, epsilon)
	var degree: int = normalized.size() - 1
	if degree <= 0:
		return PackedFloat64Array()
	if degree > max_degree:
		push_error("[GFPolynomialMath] 多项式次数超过 max_degree。")
		return PackedFloat64Array()

	var bound: float = _estimate_root_bound(normalized)
	var min_x: float = _get_option_float_or(options, "min_x", -bound)
	var max_x: float = _get_option_float_or(options, "max_x", bound)
	if is_nan(min_x) or is_nan(max_x) or is_inf(min_x) or is_inf(max_x):
		push_error("[GFPolynomialMath] min_x 和 max_x 必须是有限数字。")
		return PackedFloat64Array()
	if min_x > max_x:
		var swap_value: float = min_x
		min_x = max_x
		max_x = swap_value

	var roots: PackedFloat64Array = _solve_roots_in_range(
		normalized,
		min_x,
		max_x,
		epsilon,
		merge_epsilon,
		max_iterations
	)
	return _unique_sorted_roots(roots, merge_epsilon)


# --- 私有/辅助方法 ---

static func _solve_roots_in_range(
	coefficients: PackedFloat64Array,
	min_x: float,
	max_x: float,
	epsilon: float,
	merge_epsilon: float,
	max_iterations: int
) -> PackedFloat64Array:
	var normalized: PackedFloat64Array = normalize_coefficients(coefficients, epsilon)
	var degree: int = normalized.size() - 1
	if degree <= 0 or absf(max_x - min_x) <= epsilon:
		return PackedFloat64Array()
	if degree == 1:
		return _solve_linear_in_range(normalized, min_x, max_x, epsilon)
	if degree == 2:
		return _solve_quadratic_in_range(normalized, min_x, max_x, epsilon)

	var roots: PackedFloat64Array = PackedFloat64Array()
	var derivative_roots: PackedFloat64Array = _solve_roots_in_range(
		derivative(normalized, epsilon),
		min_x,
		max_x,
		epsilon,
		merge_epsilon,
		max_iterations
	)
	var points: PackedFloat64Array = _make_interval_points(min_x, max_x, derivative_roots, merge_epsilon)

	for point: float in points:
		var value_at_point: float = evaluate(normalized, point)
		if absf(value_at_point) <= epsilon:
			_append_root_if_in_range(roots, point, min_x, max_x, epsilon)

	for index: int in range(points.size() - 1):
		var left: float = points[index]
		var right: float = points[index + 1]
		if absf(right - left) <= epsilon:
			continue

		var left_value: float = evaluate(normalized, left)
		var right_value: float = evaluate(normalized, right)
		if absf(left_value) <= epsilon or absf(right_value) <= epsilon:
			continue
		if _has_sign_change(left_value, right_value):
			var root: float = _bisect_root(
				normalized,
				left,
				right,
				left_value,
				right_value,
				epsilon,
				max_iterations
			)
			_append_root_if_in_range(roots, root, min_x, max_x, epsilon)

	return _unique_sorted_roots(roots, merge_epsilon)


static func _solve_linear_in_range(
	coefficients: PackedFloat64Array,
	min_x: float,
	max_x: float,
	epsilon: float
) -> PackedFloat64Array:
	var a: float = coefficients[0]
	if absf(a) <= epsilon:
		return PackedFloat64Array()

	var root: float = -coefficients[1] / a
	var result: PackedFloat64Array = PackedFloat64Array()
	_append_root_if_in_range(result, root, min_x, max_x, epsilon)
	return result


static func _solve_quadratic_in_range(
	coefficients: PackedFloat64Array,
	min_x: float,
	max_x: float,
	epsilon: float
) -> PackedFloat64Array:
	var a: float = coefficients[0]
	if absf(a) <= epsilon:
		return _solve_linear_in_range(PackedFloat64Array([coefficients[1], coefficients[2]]), min_x, max_x, epsilon)

	var b: float = coefficients[1]
	var c: float = coefficients[2]
	var discriminant: float = b * b - 4.0 * a * c
	var result: PackedFloat64Array = PackedFloat64Array()
	if discriminant < -epsilon:
		return result
	if absf(discriminant) <= epsilon:
		_append_root_if_in_range(result, -b / (2.0 * a), min_x, max_x, epsilon)
		return result

	var sqrt_discriminant: float = sqrt(discriminant)
	var denominator: float = 2.0 * a
	_append_root_if_in_range(result, (-b - sqrt_discriminant) / denominator, min_x, max_x, epsilon)
	_append_root_if_in_range(result, (-b + sqrt_discriminant) / denominator, min_x, max_x, epsilon)
	return _unique_sorted_roots(result, epsilon)


static func _bisect_root(
	coefficients: PackedFloat64Array,
	left: float,
	right: float,
	left_value: float,
	right_value: float,
	epsilon: float,
	max_iterations: int
) -> float:
	var min_value: float = left
	var max_value: float = right
	var value_at_min: float = left_value
	var value_at_max: float = right_value

	for _iteration: int in range(max_iterations):
		var midpoint: float = (min_value + max_value) * 0.5
		var value_at_midpoint: float = evaluate(coefficients, midpoint)
		if absf(value_at_midpoint) <= epsilon or absf(max_value - min_value) <= epsilon:
			return midpoint
		if _has_sign_change(value_at_min, value_at_midpoint):
			max_value = midpoint
			value_at_max = value_at_midpoint
		else:
			min_value = midpoint
			value_at_min = value_at_midpoint

	if absf(value_at_min) <= absf(value_at_max):
		return min_value
	return max_value


static func _make_interval_points(
	min_x: float,
	max_x: float,
	inner_points: PackedFloat64Array,
	merge_epsilon: float
) -> PackedFloat64Array:
	var points: PackedFloat64Array = PackedFloat64Array([min_x])
	for point: float in inner_points:
		_append_root_if_in_range(points, point, min_x, max_x, merge_epsilon)
	var _max_point_appended: bool = points.append(max_x)
	return _unique_sorted_roots(points, merge_epsilon)


static func _append_root_if_in_range(
	roots: PackedFloat64Array,
	root: float,
	min_x: float,
	max_x: float,
	epsilon: float
) -> void:
	if is_nan(root) or is_inf(root):
		return
	if root < min_x - epsilon or root > max_x + epsilon:
		return
	var _root_appended: bool = roots.append(clampf(root, min_x, max_x))


static func _unique_sorted_roots(roots: PackedFloat64Array, merge_epsilon: float) -> PackedFloat64Array:
	var sorted_roots: Array[float] = []
	for root: float in roots:
		if not is_nan(root) and not is_inf(root):
			sorted_roots.append(root)
	sorted_roots.sort()

	var result: PackedFloat64Array = PackedFloat64Array()
	for root: float in sorted_roots:
		if result.is_empty():
			var _first_root_appended: bool = result.append(root)
			continue

		var last_index: int = result.size() - 1
		var previous_root: float = result[last_index]
		if absf(root - previous_root) <= merge_epsilon:
			result[last_index] = (previous_root + root) * 0.5
		else:
			var _root_appended: bool = result.append(root)
	return result


static func _estimate_root_bound(coefficients: PackedFloat64Array) -> float:
	if coefficients.size() <= 1:
		return 1.0

	var leading_abs: float = absf(coefficients[0])
	if leading_abs <= DEFAULT_EPSILON:
		return 1.0

	var max_ratio: float = 0.0
	for index: int in range(1, coefficients.size()):
		max_ratio = maxf(max_ratio, absf(coefficients[index]) / leading_abs)
	return maxf(1.0, 1.0 + max_ratio)


static func _has_sign_change(left_value: float, right_value: float) -> bool:
	return (left_value < 0.0 and right_value > 0.0) or (left_value > 0.0 and right_value < 0.0)


static func _get_option_float_or(options: Dictionary, key: String, default_value: float) -> float:
	if not options.has(key):
		return default_value
	return GFVariantData.to_float(options[key], default_value)


static func _has_non_finite_coefficients(coefficients: PackedFloat64Array) -> bool:
	for coefficient: float in coefficients:
		if is_nan(coefficient) or is_inf(coefficient):
			return true
	return false
