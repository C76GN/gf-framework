## 验证定点向量完整归约与逐项兼容配方的可区分结果。
extends GutTest


# --- 常量 ---

const MAX_RAW: int = 9_223_372_036_854_775_807
const ROUNDING_MODES: Array[int] = [
	GFFixedDecimal.RoundingMode.HALF_UP,
	GFFixedDecimal.RoundingMode.HALF_EVEN,
	GFFixedDecimal.RoundingMode.FLOOR,
	GFFixedDecimal.RoundingMode.CEIL,
	GFFixedDecimal.RoundingMode.TRUNCATE,
]


# --- 测试 ---

func test_vector2_squared_length_rounds_complete_sum() -> void:
	var value: GFFixedVector2 = GFFixedVector2.from_raw(
		4,
		4,
		1
	)
	var result: GFFixedDecimal = value.length_squared(1)
	assert_eq(
		result.raw_value,
		3,
		"0.16 + 0.16 应整体舍入为 0.3。"
	)
	assert_eq(result.decimal_places, 1)
	assert_eq(
		value.length_squared().raw_value,
		3
	)


func test_vector3_squared_length_rounds_complete_sum() -> void:
	var value: GFFixedVector3 = GFFixedVector3.from_raw(
		4,
		4,
		4,
		1
	)
	var expected: PackedInt64Array = PackedInt64Array(
		[
			5,
			5,
			4,
			5,
			4,
		]
	)
	for index: int in range(ROUNDING_MODES.size()):
		var result: GFFixedDecimal = value.length_squared(
			1,
			ROUNDING_MODES[index]
		)
		assert_eq(
			result.raw_value,
			expected[index],
			"0.48 只在完整求和后舍入。"
		)
		assert_eq(result.decimal_places, 1)


func test_positive_and_negative_half_ties_use_all_rounding_modes() -> void:
	var positive: PackedInt64Array = PackedInt64Array(
		[
			1,
			0,
			0,
			1,
			0,
		]
	)
	var negative: PackedInt64Array = PackedInt64Array(
		[
			-1,
			0,
			-1,
			0,
			0,
		]
	)
	var left2: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		1
	)
	var right2: GFFixedVector2 = GFFixedVector2.from_raw(
		-5,
		-5,
		1
	)
	var left3: GFFixedVector3 = GFFixedVector3.from_raw(
		5,
		5,
		0,
		1
	)
	var right3: GFFixedVector3 = GFFixedVector3.from_raw(
		-5,
		-5,
		0,
		1
	)
	for index: int in range(ROUNDING_MODES.size()):
		var mode: int = ROUNDING_MODES[index]
		assert_eq(
			left2.length_squared(0, mode).raw_value,
			positive[index]
		)
		assert_eq(
			left2.dot(
				right2,
				0,
				mode
			).raw_value,
			negative[index]
		)
		assert_eq(
			left3.length_squared(0, mode).raw_value,
			positive[index]
		)
		assert_eq(
			left3.dot(
				right3,
				0,
				mode
			).raw_value,
			negative[index]
		)


func test_half_even_ties_keep_even_final_integer_for_both_signs() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		1
	)
	for magnitude: int in [15, 25]:
		for sign_value: int in [-1, 1]:
			var right: GFFixedVector2 = GFFixedVector2.from_raw(
				magnitude * sign_value,
				magnitude * sign_value,
				1
			)
			var result: GFFixedDecimal = left.dot(
				right,
				0,
				GFFixedDecimal.RoundingMode.HALF_EVEN
			)
			assert_eq(
				result.raw_value,
				2 * sign_value,
				"1.5 与 2.5 都向偶数 2 舍入。"
			)


func test_signed_cancellation_happens_before_any_rounding() -> void:
	var left2: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		1
	)
	var right2: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		-5,
		1
	)
	var left3: GFFixedVector3 = GFFixedVector3.from_raw(
		5,
		5,
		5,
		1
	)
	var right3: GFFixedVector3 = GFFixedVector3.from_raw(
		5,
		0,
		-5,
		1
	)
	for mode: int in ROUNDING_MODES:
		assert_eq(
			left2.dot(
				right2,
				0,
				mode
			).raw_value,
			0
		)
		assert_eq(
			left3.dot(
				right3,
				0,
				mode
			).raw_value,
			0
		)


func test_fractional_products_accumulate_before_truncation() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		6,
		6,
		1
	)
	var right: GFFixedVector2 = GFFixedVector2.from_raw(
		1,
		1,
		0
	)
	var result: GFFixedDecimal = left.dot(
		right,
		0,
		GFFixedDecimal.RoundingMode.TRUNCATE
	)
	assert_eq(
		result.raw_value,
		1,
		"两个 0.6 的精确和为 1.2，而不是逐项截断后的零。"
	)


func test_mixed_precision_and_default_target_keep_higher_input_precision() -> void:
	var left2: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		1
	)
	var right2: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		2
	)
	var result2: GFFixedDecimal = left2.dot(right2)
	assert_eq(result2.raw_value, 5)
	assert_eq(result2.decimal_places, 2)
	assert_eq(
		left2.dot(right2, -1).raw_value,
		5
	)
	var left3: GFFixedVector3 = GFFixedVector3.from_raw(
		5,
		5,
		0,
		1
	)
	var right3: GFFixedVector3 = GFFixedVector3.from_raw(
		5,
		5,
		0,
		2
	)
	var result3: GFFixedDecimal = left3.dot(right3)
	assert_eq(result3.raw_value, 5)
	assert_eq(result3.decimal_places, 2)


func test_product_overflow_can_cancel_into_representable_final_result() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		MAX_RAW,
		MAX_RAW,
		0
	)
	var right: GFFixedVector2 = GFFixedVector2.from_raw(
		2,
		-3,
		0
	)
	assert_eq(
		left.dot(right).raw_value,
		-MAX_RAW
	)
	var swapped: GFFixedVector2 = GFFixedVector2.from_raw(
		-3,
		2,
		0
	)
	assert_eq(
		left.dot(swapped).raw_value,
		-MAX_RAW
	)


func test_vector3_partial_sum_overflow_does_not_prevent_later_cancellation() -> void:
	var left: GFFixedVector3 = GFFixedVector3.from_raw(
		MAX_RAW,
		MAX_RAW,
		MAX_RAW,
		0
	)
	var right: GFFixedVector3 = GFFixedVector3.from_raw(
		1,
		1,
		-1,
		0
	)
	assert_eq(
		left.dot(right).raw_value,
		MAX_RAW
	)


func test_maximum_raw_products_cancel_at_maximum_input_precision() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		MAX_RAW,
		MAX_RAW,
		18
	)
	var right: GFFixedVector2 = GFFixedVector2.from_raw(
		MAX_RAW,
		-MAX_RAW,
		18
	)
	var result: GFFixedDecimal = left.dot(right, 18)
	assert_eq(result.raw_value, 0)
	assert_eq(result.decimal_places, 18)


func test_upscaling_happens_after_wide_cancellation() -> void:
	var left: GFFixedVector3 = GFFixedVector3.from_raw(
		MAX_RAW,
		MAX_RAW,
		1,
		0
	)
	var right: GFFixedVector3 = GFFixedVector3.from_raw(
		1,
		-1,
		1,
		0
	)
	var result: GFFixedDecimal = left.dot(right, 18)
	assert_eq(result.raw_value, 1_000_000_000_000_000_000)
	assert_eq(result.decimal_places, 18)


func test_only_final_overflow_emits_one_dot_saturation_error() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		MAX_RAW,
		MAX_RAW,
		0
	)
	for sign_value: int in [-1, 1]:
		var right: GFFixedVector2 = GFFixedVector2.from_raw(
			2 * sign_value,
			2 * sign_value,
			0
		)
		assert_eq(
			left.dot(right).raw_value,
			MAX_RAW * sign_value
		)
		assert_push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The dot result exceeds the representable range and was clamped.")


func test_null_other_keeps_receiver_precision_even_with_explicit_target() -> void:
	var left2: GFFixedVector2 = GFFixedVector2.from_raw(
		4,
		4,
		3
	)
	var result2: GFFixedDecimal = left2.dot(null, 0)
	assert_eq(result2.raw_value, 0)
	assert_eq(result2.decimal_places, 3)
	var left3: GFFixedVector3 = GFFixedVector3.from_raw(
		4,
		4,
		4,
		3
	)
	var result3: GFFixedDecimal = left3.dot(null, 0)
	assert_eq(result3.raw_value, 0)
	assert_eq(result3.decimal_places, 3)


func test_legacy_vector2_recipe_keeps_component_rounding_and_null_contract() -> void:
	var value: GFFixedVector2 = GFFixedVector2.from_raw(
		4,
		4,
		1
	)
	var result: GFFixedDecimal = _legacy_dot2(value, value)
	assert_eq(result.raw_value, 4)
	assert_eq(result.decimal_places, 1)
	assert_eq(
		_legacy_dot2(
			value,
			null,
			0
		).decimal_places,
		1
	)
	var half: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		5,
		1
	)
	var reversed: GFFixedVector2 = GFFixedVector2.from_raw(
		5,
		-5,
		1
	)
	assert_eq(
		_legacy_dot2(
			half,
			reversed,
			0,
			GFFixedDecimal.RoundingMode.FLOOR
		).raw_value,
		-1
	)


func test_legacy_vector2_recipe_keeps_each_multiply_saturation() -> void:
	var left: GFFixedVector2 = GFFixedVector2.from_raw(
		MAX_RAW,
		MAX_RAW,
		0
	)
	var right: GFFixedVector2 = GFFixedVector2.from_raw(
		2,
		-3,
		0
	)
	assert_eq(
		_legacy_dot2(left, right).raw_value,
		0
	)
	assert_push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The multiply result exceeds the representable range and was clamped.")
	assert_push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The multiply result exceeds the representable range and was clamped.")


func test_legacy_vector3_recipe_keeps_left_associative_saturation() -> void:
	var left: GFFixedVector3 = GFFixedVector3.from_raw(
		MAX_RAW,
		MAX_RAW,
		MAX_RAW,
		0
	)
	var right: GFFixedVector3 = GFFixedVector3.from_raw(
		1,
		1,
		-1,
		0
	)
	assert_eq(
		_legacy_dot3(left, right).raw_value,
		0
	)
	assert_push_error("[GFFixedDecimal][fixed_decimal.result_clamped] The add result exceeds the representable range and was clamped.")
	assert_eq(
		_legacy_dot3(
			left,
			null,
			2
		).decimal_places,
		0
	)


# --- 私有/辅助方法 ---

## 项目兼容配方：保留旧 2D 逐项量化及空参数合同。
func _legacy_dot2(
	left: GFFixedVector2,
	right: GFFixedVector2,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if right == null:
		return GFFixedDecimal.new(0, left.decimal_places)
	var x_product: GFFixedDecimal = left.get_x_decimal().multiply(
		right.get_x_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var y_product: GFFixedDecimal = left.get_y_decimal().multiply(
		right.get_y_decimal(),
		target_decimal_places,
		rounding_mode
	)
	return x_product.add(y_product)


## 项目兼容配方：先完成全部乘法，再按 X+Y、加 Z 的旧顺序归约。
func _legacy_dot3(
	left: GFFixedVector3,
	right: GFFixedVector3,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if right == null:
		return GFFixedDecimal.new(0, left.decimal_places)
	var x_product: GFFixedDecimal = left.get_x_decimal().multiply(
		right.get_x_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var y_product: GFFixedDecimal = left.get_y_decimal().multiply(
		right.get_y_decimal(),
		target_decimal_places,
		rounding_mode
	)
	var z_product: GFFixedDecimal = left.get_z_decimal().multiply(
		right.get_z_decimal(),
		target_decimal_places,
		rounding_mode
	)
	return x_product.add(y_product).add(z_product)
