## 测试 GFFixedVector2 / GFFixedVector3 的定点运算与稳定序列化。
extends GutTest


# --- 常量 ---

const GF_FIXED_VECTOR2 = preload("res://addons/gf/standard/foundation/numeric/gf_fixed_vector2.gd")
const GF_FIXED_VECTOR3 = preload("res://addons/gf/standard/foundation/numeric/gf_fixed_vector3.gd")


# --- 测试 ---

func test_vector2_from_decimal_strings_keeps_raw_components() -> void:
	var value: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("1.25", "-2.50", 2)

	assert_eq(value.raw_x, 125)
	assert_eq(value.raw_y, -250)
	assert_eq(value.decimal_places, 2)
	assert_eq(value.get_x_decimal().to_decimal_string(), "1.25")
	assert_eq(value.get_y_decimal().to_decimal_string(), "-2.50")


func test_vector2_add_rescales_and_dot_uses_fixed_decimal() -> void:
	var left: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("1.2", "0.5", 1)
	var right: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("0.35", "2.00", 2)

	var sum: GF_FIXED_VECTOR2 = left.add(right)
	var dot: GFFixedDecimal = left.dot(right, 3)

	assert_eq(sum.decimal_places, 2, "加法应对齐到较高小数位。")
	assert_eq(sum.raw_x, 155)
	assert_eq(sum.raw_y, 250)
	assert_eq(dot.to_decimal_string(), "1.420", "点积应通过 GFFixedDecimal 固定舍入。")


func test_vector2_multiply_scalar_and_length_squared() -> void:
	var value: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("1.50", "-2.00", 2)
	var scalar: GFFixedDecimal = GFFixedDecimal.from_string("0.5", 1)
	var scaled: GF_FIXED_VECTOR2 = value.multiply_scalar(scalar, 2)
	var length_squared: GFFixedDecimal = GF_FIXED_VECTOR2.from_decimal_strings("3", "4", 0).length_squared(0)

	assert_eq(scaled.get_x_decimal().to_decimal_string(), "0.75")
	assert_eq(scaled.get_y_decimal().to_decimal_string(), "-1.00")
	assert_eq(length_squared.to_decimal_string(), "25")


func test_vector2_dict_roundtrips_through_json() -> void:
	var source: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.new(
		9_223_372_036_854_775_000,
		-9_223_372_036_854_775_000,
		18
	)
	var encoded: Dictionary = source.to_dict()
	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var restored: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_dict(parsed)

	assert_eq(GFVariantData.get_option_string(encoded, "raw_x"), "9223372036854775000")
	assert_eq(GFVariantData.get_option_string(encoded, "raw_y"), "-9223372036854775000")
	assert_true(restored.equals_exact(source), "JSON 往返应保持 raw 分量和小数位。")


func test_vector2_serialization_normalizes_mutated_decimal_places() -> void:
	var value: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.new(1, 2, 2)
	value.decimal_places = 30

	var data: Dictionary = value.to_dict()
	var bytes: PackedByteArray = value.to_bytes()

	assert_push_error("[GFFixedVector2] decimal_places 超出上限 18，已自动钳制。")
	assert_push_error("[GFFixedVector2] decimal_places 超出上限 18，已自动钳制。")
	assert_eq(GFVariantData.get_option_int(data, "decimal_places"), GFFixedDecimal.MAX_DECIMAL_PLACES)
	assert_eq(bytes[5], GFFixedDecimal.MAX_DECIMAL_PLACES)


func test_vector2_bytes_match_golden_big_endian_format() -> void:
	var value: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.new(-12_345, 678, 3)

	assert_eq(value.to_bytes(), PackedByteArray([
		71, 70, 70, 50,
		1,
		3,
		1, 0, 0, 0, 0, 0, 0, 48, 57,
		0, 0, 0, 0, 0, 0, 0, 2, 166,
	]))


func test_vector2_rejects_unknown_serialized_format() -> void:
	var value: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("1.00", "2.00", 2)
	var applied_dict: bool = value.apply_dict({
		"type": "other",
		"version": 1,
		"raw_x": "100",
		"raw_y": "200",
		"decimal_places": 2,
	})
	var applied_bytes: bool = value.apply_bytes(PackedByteArray([
		71, 70, 70, 50,
		2,
		3,
		0, 0, 0, 0, 0, 0, 0, 0, 1,
		0, 0, 0, 0, 0, 0, 0, 0, 2,
	]))

	assert_false(applied_dict)
	assert_push_error("[GFFixedVector2] 不支持的状态字典格式。")
	assert_false(applied_bytes)
	assert_push_error("[GFFixedVector2] 不支持的字节序列格式。")
	assert_eq(value.raw_x, 0)
	assert_eq(value.raw_y, 0)
	assert_eq(value.decimal_places, 2)


func test_vector3_from_decimal_strings_and_dot() -> void:
	var left: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_decimal_strings("1.00", "2.00", "3.00", 2)
	var right: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_decimal_strings("-2.00", "0.50", "4.00", 2)

	var dot: GFFixedDecimal = left.dot(right, 2)
	var length_squared: GFFixedDecimal = GF_FIXED_VECTOR3.from_decimal_strings("1", "2", "2", 0).length_squared(0)

	assert_eq(dot.to_decimal_string(), "11.00")
	assert_eq(length_squared.to_decimal_string(), "9")


func test_vector3_add_and_multiply_scalar_use_fixed_decimal() -> void:
	var left: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_decimal_strings("1.2", "0.5", "-3.0", 1)
	var right: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_decimal_strings("0.35", "2.00", "1.25", 2)
	var scalar: GFFixedDecimal = GFFixedDecimal.from_string("-0.5", 1)

	var sum: GF_FIXED_VECTOR3 = left.add(right)
	var scaled: GF_FIXED_VECTOR3 = right.multiply_scalar(scalar, 2)

	assert_eq(sum.decimal_places, 2, "三维加法应对齐到较高小数位。")
	assert_eq(sum.raw_x, 155)
	assert_eq(sum.raw_y, 250)
	assert_eq(sum.raw_z, -175)
	assert_eq(scaled.get_x_decimal().to_decimal_string(), "-0.18")
	assert_eq(scaled.get_y_decimal().to_decimal_string(), "-1.00")
	assert_eq(scaled.get_z_decimal().to_decimal_string(), "-0.63")


func test_vector3_dict_roundtrips_through_json() -> void:
	var source: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.new(
		9_223_372_036_854_775_000,
		-9_223_372_036_854_775_000,
		1_234_567_890_123_456_789,
		18
	)
	var encoded: Dictionary = source.to_dict()
	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(JSON.stringify(encoded)))
	var restored: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_dict(parsed)

	assert_eq(GFVariantData.get_option_string(encoded, "raw_x"), "9223372036854775000")
	assert_eq(GFVariantData.get_option_string(encoded, "raw_y"), "-9223372036854775000")
	assert_eq(GFVariantData.get_option_string(encoded, "raw_z"), "1234567890123456789")
	assert_true(restored.equals_exact(source), "JSON 往返应保持三维 raw 分量和小数位。")


func test_vector3_serialization_normalizes_mutated_decimal_places() -> void:
	var value: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.new(1, 2, 3, 2)
	value.decimal_places = 30

	var data: Dictionary = value.to_dict()
	var bytes: PackedByteArray = value.to_bytes()

	assert_push_error("[GFFixedVector3] decimal_places 超出上限 18，已自动钳制。")
	assert_push_error("[GFFixedVector3] decimal_places 超出上限 18，已自动钳制。")
	assert_eq(GFVariantData.get_option_int(data, "decimal_places"), GFFixedDecimal.MAX_DECIMAL_PLACES)
	assert_eq(bytes[5], GFFixedDecimal.MAX_DECIMAL_PLACES)


func test_vector3_bytes_match_golden_big_endian_format() -> void:
	var value: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.new(-12, 34, -56, 1)

	assert_eq(value.to_bytes(), PackedByteArray([
		71, 70, 70, 51,
		1,
		1,
		1, 0, 0, 0, 0, 0, 0, 0, 12,
		0, 0, 0, 0, 0, 0, 0, 0, 34,
		1, 0, 0, 0, 0, 0, 0, 0, 56,
	]))


func test_vector3_rejects_unknown_serialized_format() -> void:
	var value: GF_FIXED_VECTOR3 = GF_FIXED_VECTOR3.from_decimal_strings("1", "2", "3", 0)
	var applied: bool = value.apply_bytes(PackedByteArray([
		71, 70, 70, 51,
		2,
		1,
		0, 0, 0, 0, 0, 0, 0, 0, 1,
		0, 0, 0, 0, 0, 0, 0, 0, 2,
		0, 0, 0, 0, 0, 0, 0, 0, 3,
	]))

	assert_false(applied)
	assert_push_error("[GFFixedVector3] 不支持的字节序列格式。")
	assert_eq(value.raw_x, 0)
	assert_eq(value.raw_y, 0)
	assert_eq(value.raw_z, 0)
	assert_eq(value.decimal_places, 2)


func test_vector_serialization_rejects_malformed_raw_and_byte_edges() -> void:
	var vector2: GF_FIXED_VECTOR2 = GF_FIXED_VECTOR2.from_decimal_strings("1", "2", 0)
	var invalid_raw_applied: bool = vector2.apply_dict({
		"type": "gf.fixed_vector2",
		"version": 1,
		"raw_x": "1.25",
		"raw_y": "2",
		"decimal_places": 2,
	})
	var invalid_places_applied: bool = vector2.apply_dict({
		"type": "gf.fixed_vector2",
		"version": 1,
		"raw_x": "1",
		"raw_y": "2",
		"decimal_places": 19,
	})
	var invalid_sign_applied: bool = vector2.apply_bytes(PackedByteArray([
		71, 70, 70, 50,
		1,
		2,
		2, 0, 0, 0, 0, 0, 0, 0, 1,
		0, 0, 0, 0, 0, 0, 0, 0, 2,
	]))
	var overflow_magnitude_applied: bool = vector2.apply_bytes(PackedByteArray([
		71, 70, 70, 50,
		1,
		2,
		0, 128, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 2,
	]))

	assert_false(invalid_raw_applied)
	assert_push_error("[GFFixedVector2] 不支持的状态字典格式。")
	assert_false(invalid_places_applied)
	assert_push_error("[GFFixedVector2] 不支持的状态字典格式。")
	assert_false(invalid_sign_applied)
	assert_push_error("[GFFixedVector2] 不支持的字节序列格式。")
	assert_false(overflow_magnitude_applied)
	assert_push_error("[GFFixedVector2] 不支持的字节序列格式。")
