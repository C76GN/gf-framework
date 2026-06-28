## 测试 GFUuid 的 v4/v7 生成与 canonical UUID 校验。
extends GutTest

# --- 测试方法 ---

func test_generate_v4_returns_canonical_rfc_variant_uuid() -> void:
	var uuid: String = GFUuid.generate_v4()

	assert_eq(uuid.length(), GFUuid.CANONICAL_LENGTH)
	assert_true(GFUuid.is_valid(uuid), "v4 UUID 应满足 canonical 形态。")
	assert_true(GFUuid.is_valid(uuid, 4), "v4 UUID 应通过版本过滤。")
	assert_eq(uuid.substr(14, 1), "4", "v4 UUID 应写入版本位。")
	assert_true(["8", "9", "a", "b"].has(uuid.substr(19, 1)), "UUID 应写入 RFC 4122 variant 位。")


func test_generate_v7_embeds_timestamp_and_version() -> void:
	var uuid: String = GFUuid.generate_v7(0x0123456789ab)

	assert_true(uuid.begins_with("01234567-89ab-7"), "v7 UUID 前 48 位应写入 Unix 毫秒时间戳。")
	assert_true(GFUuid.is_valid(uuid, 7), "v7 UUID 应通过版本过滤。")


func test_generate_v7_clamps_timestamp_to_48_bits() -> void:
	var uuid: String = GFUuid.generate_v7(0x1000000000000)

	assert_true(uuid.begins_with("ffffffff-ffff-7"), "超过 48 位的时间戳应钳制到 v7 可编码上限。")
	assert_true(GFUuid.is_valid(uuid, 7), "钳制后的 v7 UUID 仍应有效。")


func test_generate_v7_same_millisecond_is_strictly_monotonic() -> void:
	var first_uuid: String = GFUuid.generate_v7(0x000000000123)
	var second_uuid: String = GFUuid.generate_v7(0x000000000123)
	var third_uuid: String = GFUuid.generate_v7(0x000000000123)

	assert_true(first_uuid.begins_with("00000000-0123-7"), "同毫秒 v7 仍应写入原时间戳。")
	assert_true(second_uuid.begins_with("00000000-0123-7"), "同毫秒 v7 仍应写入原时间戳。")
	assert_lt(first_uuid, second_uuid, "同一毫秒连续生成的 v7 UUID 应严格递增。")
	assert_lt(second_uuid, third_uuid, "同一毫秒连续生成的 v7 UUID 应持续严格递增。")


func test_is_valid_rejects_invalid_shape_version_and_variant() -> void:
	assert_false(GFUuid.is_valid("not-a-uuid"), "非 canonical 字符串应被拒绝。")
	assert_false(GFUuid.is_valid("01234567-89ab-7cde-7abc-0123456789ab"), "非 RFC variant 应被拒绝。")
	assert_false(GFUuid.is_valid("01234567-89ab-7cde-8abc-0123456789ab", 4), "版本过滤不匹配时应返回 false。")
	assert_true(GFUuid.is_valid("01234567-89ab-7cde-8abc-0123456789ab", 7), "版本过滤匹配时应返回 true。")


func test_is_valid_requires_canonical_lowercase_without_padding() -> void:
	assert_false(GFUuid.is_valid("01234567-89AB-7cde-8abc-0123456789ab"), "canonical UUID 应拒绝大写十六进制。")
	assert_false(GFUuid.is_valid(" 01234567-89ab-7cde-8abc-0123456789ab "), "canonical UUID 应拒绝前后空白。")
