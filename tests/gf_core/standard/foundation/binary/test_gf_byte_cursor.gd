extends GutTest

const GF_BYTE_CURSOR_SCRIPT = preload("res://addons/gf/standard/foundation/binary/gf_byte_cursor.gd")


func test_byte_cursor_reads_and_writes_big_endian_values() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new()
	cursor.write_u8(0x12)
	cursor.write_u16(0x3456)
	cursor.write_u32(0x789abcde)
	var _var_written: bool = cursor.write_var_uint(300)
	cursor.write_utf8("ok")

	var reader: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(cursor.get_bytes())
	assert_eq(reader.read_u8(), 0x12, "u8 应按写入值读取。")
	assert_eq(reader.read_u16(), 0x3456, "默认应按大端读取 u16。")
	assert_eq(reader.read_u32(), 0x789abcde, "默认应按大端读取 u32。")
	assert_eq(reader.read_var_uint(), 300, "varuint 应可往返。")
	assert_eq(reader.read_utf8(2), "ok", "UTF-8 文本应可读取。")
	assert_true(reader.is_eof(), "读取完成后应到达 EOF。")


func test_byte_cursor_reads_little_endian_and_reports_eof() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray(), true)
	cursor.write_u16(0x1234)
	cursor.write_u32(0x01020304)

	var bytes: PackedByteArray = cursor.get_bytes()
	assert_eq(bytes, PackedByteArray([0x34, 0x12, 0x04, 0x03, 0x02, 0x01]), "小端写入应低位在前。")

	var reader: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(bytes, 0, true)
	assert_eq(reader.read_u16(), 0x1234, "小端 u16 应可读取。")
	assert_eq(reader.read_u32(), 0x01020304, "小端 u32 应可读取。")
	assert_eq(reader.read_u8(), 0, "越界读取应返回 0。")
	assert_eq(reader.get_last_error(), ERR_FILE_EOF, "越界读取应记录 EOF 错误。")


func test_byte_cursor_fixed_width_integer_boundaries_match_golden_bytes() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new()
	cursor.write_u8(255)
	cursor.write_i8(-128)
	cursor.write_i8(127)
	cursor.write_u16(65535)
	cursor.write_i16(-32768)
	cursor.write_i16(32767)
	cursor.write_u32(4294967295)
	cursor.write_i32(-2147483648)
	cursor.write_i32(2147483647)

	assert_eq(cursor.get_bytes(), PackedByteArray([
		0xff,
		0x80,
		0x7f,
		0xff, 0xff,
		0x80, 0x00,
		0x7f, 0xff,
		0xff, 0xff, 0xff, 0xff,
		0x80, 0x00, 0x00, 0x00,
		0x7f, 0xff, 0xff, 0xff,
	]), "固定宽度极值应匹配规范大端 two's-complement 字节。")
	assert_eq(cursor.get_last_error(), OK, "全部合法极值写入后应保持成功状态。")

	var reader: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(cursor.get_bytes())
	assert_eq(reader.read_u8(), 255, "u8 最大值应往返。")
	assert_eq(reader.read_i8(), -128, "i8 最小值应往返。")
	assert_eq(reader.read_i8(), 127, "i8 最大值应往返。")
	assert_eq(reader.read_u16(), 65535, "u16 最大值应往返。")
	assert_eq(reader.read_i16(), -32768, "i16 最小值应往返。")
	assert_eq(reader.read_i16(), 32767, "i16 最大值应往返。")
	assert_eq(reader.read_u32(), 4294967295, "u32 最大值应往返。")
	assert_eq(reader.read_i32(), -2147483648, "i32 最小值应往返。")
	assert_eq(reader.read_i32(), 2147483647, "i32 最大值应往返。")


func test_byte_cursor_invalid_fixed_width_writes_are_atomic() -> void:
	var cases: Array[Dictionary] = [
		{ "label": "u8 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u8(-1) },
		{ "label": "u8 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u8(256) },
		{ "label": "i8 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i8(-129) },
		{ "label": "i8 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i8(128) },
		{ "label": "u16 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u16(-1) },
		{ "label": "u16 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u16(65536) },
		{ "label": "i16 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i16(-32769) },
		{ "label": "i16 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i16(32768) },
		{ "label": "u32 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u32(-1) },
		{ "label": "u32 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_u32(4294967296) },
		{ "label": "i32 below", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i32(-2147483649) },
		{ "label": "i32 above", "action": func(cursor: GF_BYTE_CURSOR_SCRIPT) -> void: cursor.write_i32(2147483648) },
	]
	for case_data: Dictionary in cases:
		var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xaa]))
		var _position_set: bool = cursor.set_position(1)
		var action: Callable = GFVariantData.get_option_value(case_data, "action", Callable())
		action.call(cursor)
		var label: String = GFVariantData.get_option_string(case_data, "label")

		assert_eq(cursor.get_bytes(), PackedByteArray([0xaa]), "%s 不得修改 bytes。" % label)
		assert_eq(cursor.get_position(), 1, "%s 不得推进 position。" % label)
		assert_eq(cursor.get_last_error(), ERR_INVALID_PARAMETER, "%s 应报告无效参数。" % label)


func test_byte_cursor_write_overwrites_at_current_position() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new()
	cursor.write_bytes(PackedByteArray([1, 2, 3]))
	var _position_set: bool = cursor.set_position(1)

	cursor.write_u8(9)
	cursor.write_bytes(PackedByteArray([7, 8]))

	assert_eq(cursor.get_bytes(), PackedByteArray([1, 9, 7, 8]), "写入应从当前位置覆盖并只在末尾扩展。")
	assert_eq(cursor.get_position(), 4, "写入后游标应位于写入末尾。")


func test_byte_cursor_invalid_read_parameters_do_not_advance() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([1, 2, 3]))
	var result: PackedByteArray = cursor.read_bytes(-1)

	assert_true(result.is_empty(), "负长度读取应返回空字节。")
	assert_eq(cursor.get_position(), 0, "负长度读取不应推进游标。")
	assert_eq(cursor.get_last_error(), ERR_INVALID_PARAMETER, "负长度读取应记录无效参数。")


func test_byte_cursor_varuint_failures_do_not_advance() -> void:
	var truncated: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0x80]))

	assert_eq(truncated.read_var_uint(), 0, "截断 varuint 应返回 0。")
	assert_eq(truncated.get_position(), 0, "截断 varuint 不应推进游标。")
	assert_eq(truncated.get_last_error(), ERR_FILE_EOF, "截断 varuint 应报告 EOF。")

	var overflow: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([
		0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0xff, 0xff, 0x02,
	]))
	assert_eq(overflow.read_var_uint(), 0, "超出可表示范围的 varuint 应返回 0。")
	assert_eq(overflow.get_position(), 0, "溢出 varuint 不应推进游标。")
	assert_eq(overflow.get_last_error(), ERR_PARSE_ERROR, "溢出 varuint 应报告解析错误。")

	var unsigned_64_only: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([
		0x80, 0x80, 0x80, 0x80, 0x80,
		0x80, 0x80, 0x80, 0x80, 0x01,
	]))
	assert_eq(unsigned_64_only.read_var_uint(), 0, "超过 Godot int 范围的 varuint 应被拒绝。")
	assert_eq(unsigned_64_only.get_last_error(), ERR_PARSE_ERROR, "超出 Godot int 范围应报告解析错误。")

	var overlong_zero: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0x80, 0x00]))
	var overlong_report: Dictionary = overlong_zero.try_read_var_uint()
	assert_false(GFVariantData.get_option_bool(overlong_report, "ok"), "overlong varuint 不应被当作合法 0。")
	assert_eq(GFVariantData.get_option_int(overlong_report, "error"), ERR_PARSE_ERROR, "overlong varuint 应报告解析错误。")
	assert_eq(overlong_zero.get_position(), 0, "overlong varuint 失败不应推进游标。")


func test_byte_cursor_varuint_matches_canonical_golden_bytes_in_both_endian_modes() -> void:
	var cases: Array[Dictionary] = [
		{ "value": 0, "bytes": PackedByteArray([0x00]) },
		{ "value": 127, "bytes": PackedByteArray([0x7f]) },
		{ "value": 128, "bytes": PackedByteArray([0x80, 0x01]) },
		{ "value": 16383, "bytes": PackedByteArray([0xff, 0x7f]) },
		{ "value": 16384, "bytes": PackedByteArray([0x80, 0x80, 0x01]) },
		{
			"value": 9223372036854775807,
			"bytes": PackedByteArray([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f]),
		},
	]
	for case_data: Dictionary in cases:
		var value: int = GFVariantData.get_option_int(case_data, "value")
		var expected_bytes: PackedByteArray = GFVariantData.get_option_value(
			case_data,
			"bytes",
			PackedByteArray()
		)
		for p_little_endian: bool in [false, true]:
			var writer: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(
				PackedByteArray(),
				p_little_endian
			)
			assert_true(writer.write_var_uint(value), "合法 varuint 应成功写入。")
			assert_eq(writer.get_bytes(), expected_bytes, "varuint golden bytes 不应受固定宽度端序影响。")

			var reader: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(
				expected_bytes,
				0,
				p_little_endian
			)
			assert_eq(reader.read_var_uint(), value, "canonical varuint 应在两种端序配置下等价读取。")
			assert_true(reader.is_eof(), "canonical varuint 应消费完整编码。")


func test_byte_cursor_invalid_utf8_does_not_advance() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xc3, 0x28]))

	assert_eq(cursor.read_utf8(2), "", "非法 UTF-8 应返回空字符串。")
	assert_eq(cursor.get_position(), 0, "非法 UTF-8 不应推进游标。")
	assert_eq(cursor.get_last_error(), ERR_PARSE_ERROR, "非法 UTF-8 应报告解析错误。")


func test_byte_cursor_read_limits_and_invalid_offset_are_explicit() -> void:
	var limited: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([1, 2, 3]))
	limited.max_read_byte_count = 2
	assert_false(limited.has_bytes(3), "has_bytes 应包含当前单次读取上限。")
	var bytes: PackedByteArray = limited.read_bytes(3)

	assert_true(bytes.is_empty(), "超过读取上限时不应切片 payload。")
	assert_eq(limited.get_position(), 0, "超过读取上限不应推进游标。")
	assert_eq(limited.get_last_error(), ERR_INVALID_PARAMETER, "超过读取上限应报告无效参数。")

	var invalid_offset: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(PackedByteArray([1, 2, 3]), 99)

	assert_eq(invalid_offset.get_position(), 3, "无效 offset 创建的游标应停在 EOF，而不是回到 0。")
	assert_eq(invalid_offset.get_last_error(), ERR_INVALID_PARAMETER, "无效 offset 应保留错误码。")


func test_byte_cursor_read_limit_covers_fixed_and_variable_width_reads() -> void:
	var fixed: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([1, 2, 3, 4]))
	fixed.max_read_byte_count = 2
	assert_eq(fixed.read_u32(), 0, "固定宽度读取超过上限时应失败。")
	assert_eq(fixed.get_position(), 0, "失败的固定宽度读取不应推进。")
	assert_eq(fixed.get_last_error(), ERR_INVALID_PARAMETER, "固定宽度上限失败应报告无效参数。")

	var variable: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xac, 0x02]))
	variable.max_read_byte_count = 1
	assert_eq(variable.read_var_uint(), 0, "跨越读取上限的 varuint 应失败。")
	assert_eq(variable.get_position(), 0, "失败的 varuint 不应推进。")
	assert_eq(variable.get_last_error(), ERR_INVALID_PARAMETER, "varuint 上限失败应报告无效参数。")


func test_byte_cursor_multi_byte_writes_are_atomic_under_write_limit() -> void:
	var fixed: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xaa]))
	var _fixed_position: bool = fixed.set_position(1)
	fixed.max_write_byte_count = 2
	fixed.write_u32(0x01020304)
	assert_eq(fixed.get_bytes(), PackedByteArray([0xaa]), "失败的多字节整数写入不应留下前缀字节。")
	assert_eq(fixed.get_position(), 1, "失败的多字节整数写入不应推进 position。")
	assert_eq(fixed.get_last_error(), ERR_INVALID_PARAMETER, "写入上限失败应可诊断。")

	var variable: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xbb]))
	var _variable_position: bool = variable.set_position(1)
	variable.max_write_byte_count = 1
	assert_false(variable.write_var_uint(300), "多字节 varuint 超过写入上限时应失败。")
	assert_eq(variable.get_bytes(), PackedByteArray([0xbb]), "失败 varuint 不应留下半编码。")
	assert_eq(variable.get_position(), 1, "失败 varuint 不应推进 position。")

	var text: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xcc]))
	var _text_position: bool = text.set_position(1)
	text.max_write_byte_count = 3
	assert_false(text.write_var_utf8("abcd"), "长度前缀与 payload 合计超过上限时应整体失败。")
	assert_eq(text.get_bytes(), PackedByteArray([0xcc]), "失败 var UTF-8 不应留下长度前缀。")
	assert_eq(text.get_position(), 1, "失败 var UTF-8 不应推进 position。")

	var plain_text: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xdd]))
	var _plain_position: bool = plain_text.set_position(1)
	plain_text.max_write_byte_count = 3
	plain_text.write_utf8("abcd")
	assert_eq(plain_text.get_bytes(), PackedByteArray([0xdd]), "可由字符数确定的超限 UTF-8 应在编码前原子拒绝。")
	assert_eq(plain_text.get_position(), 1, "失败 UTF-8 不应推进 position。")
	assert_eq(plain_text.get_last_error(), ERR_INVALID_PARAMETER, "超限 UTF-8 应报告无效参数。")


func test_byte_cursor_var_utf8_direct_write_preserves_overwrite_semantics() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xaa, 0xbb, 0xcc, 0xdd]))
	var _position_set: bool = cursor.set_position(1)
	cursor.max_write_byte_count = 2

	assert_true(cursor.write_var_utf8("A"), "prefix + payload 恰好命中写入上限时应成功。")
	assert_eq(cursor.get_bytes(), PackedByteArray([0xaa, 0x01, 0x41, 0xdd]), "分段直写应覆盖字段范围并保留后缀。")
	assert_eq(cursor.get_position(), 3, "分段直写应提交 prefix + payload 的完整位置。")
	assert_eq(cursor.get_last_error(), OK, "成功分段写入应清除旧错误。")


func test_byte_cursor_try_read_reports_failure_without_ambiguous_default() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0x12]))

	var first: Dictionary = cursor.try_read_u16()
	var second: Dictionary = cursor.try_read_u8()

	assert_false(GFVariantData.get_option_bool(first, "ok"), "try_read_u16 应报告失败。")
	assert_eq(GFVariantData.get_option_int(first, "error"), ERR_FILE_EOF, "失败报告应包含错误码。")
	assert_eq(GFVariantData.get_option_int(first, "position"), 0, "失败报告应包含起始位置。")
	assert_eq(GFVariantData.get_option_int(first, "next_position"), 0, "失败读取不应推进位置。")
	assert_true(GFVariantData.get_option_bool(second, "ok"), "失败后仍应能读取同一字节。")
	assert_eq(GFVariantData.get_option_int(second, "value"), 0x12, "后续读取应拿到原字节。")


func test_byte_cursor_json_compatible_read_report_keeps_raw_bytes_separate() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([1, 2, 3]))

	var report: Dictionary = cursor.try_read_bytes(2)
	var safe_report: Dictionary = GF_BYTE_CURSOR_SCRIPT.to_json_compatible_read_report(report)
	var json_text: String = JSON.stringify(safe_report)
	var parsed: Variant = JSON.parse_string(json_text)

	assert_true(GFVariantData.get_option_value(report, "value") is PackedByteArray, "功能型读取报告应保留原始 PackedByteArray。")
	assert_false(GFVariantData.get_option_value(safe_report, "value") is PackedByteArray, "JSON-safe 报告不应直接暴露 PackedByteArray。")
	assert_false(json_text.is_empty(), "JSON-safe 读取报告应可被 JSON.stringify 序列化。")
	assert_true(json_text.contains("PackedByteArray"), "JSON-safe 读取报告应以类型化 marker 表达字节数组。")
	assert_true(parsed is Dictionary, "JSON-safe 报告必须能被 JSON.parse_string() 恢复为 Dictionary。")
	if parsed is Dictionary:
		var parsed_report: Dictionary = parsed
		var encoded_value: Dictionary = GFVariantData.get_option_dictionary(parsed_report, "value")
		var marker: Dictionary = GFVariantData.get_option_dictionary(encoded_value, "__gf_report_value__")
		var marker_items: Array = GFVariantData.get_option_array(marker, "items")
		assert_eq(GFVariantData.get_option_string(marker, "type"), "PackedArray", "字节值应使用稳定报告 marker。")
		assert_eq(
			GFVariantData.get_option_string(marker, "collection_type"),
			"PackedByteArray",
			"字节 marker 应保留原集合类型。"
		)
		assert_eq(GFVariantData.get_option_int(marker, "count"), 2, "字节 marker 应保留完整长度。")
		assert_eq(marker_items.size(), 2, "未截断字节 marker 应保留全部 items。")
		if marker_items.size() == 2:
			assert_eq(GFVariantData.to_int(marker_items[0]), 1, "字节 marker 应保留首字节。")
			assert_eq(GFVariantData.to_int(marker_items[1]), 2, "字节 marker 应保留末字节。")


func test_byte_cursor_var_utf8_round_trips_and_rolls_back_on_invalid_payload() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new()
	var _written: bool = cursor.write_var_utf8("你好")
	var reader: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(cursor.get_bytes())

	assert_eq(reader.read_var_utf8(), "你好", "var 长度 UTF-8 应可往返。")
	assert_true(reader.is_eof(), "读取 var UTF-8 后应到达末尾。")

	var invalid: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([2, 0xc3, 0x28]))
	var report: Dictionary = invalid.try_read_var_utf8()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非法 UTF-8 payload 应报告失败。")
	assert_eq(invalid.get_position(), 0, "var UTF-8 payload 失败时应回滚长度读取。")
	assert_eq(invalid.get_last_error(), ERR_PARSE_ERROR, "非法 payload 应保留解析错误。")

	var oversized: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([3, 0x61, 0x62, 0x63]))
	oversized.max_read_byte_count = 2
	var oversized_report: Dictionary = oversized.try_read_var_utf8()

	assert_false(GFVariantData.get_option_bool(oversized_report, "ok"), "var UTF-8 长度超过上限应失败。")
	assert_eq(oversized.get_position(), 0, "长度超过上限时应回滚长度读取。")
	assert_eq(oversized.get_last_error(), ERR_INVALID_PARAMETER, "长度超过上限应保留错误码。")


func test_byte_cursor_var_utf8_read_limit_counts_prefix_and_payload() -> void:
	var limited: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0x01, 0x61]))
	limited.max_read_byte_count = 1

	var rejected: Dictionary = limited.try_read_var_utf8()

	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "单次读取预算必须同时包含长度前缀和 payload。")
	assert_eq(GFVariantData.get_option_int(rejected, "error"), ERR_INVALID_PARAMETER, "组合读取超限应报告无效参数。")
	assert_eq(GFVariantData.get_option_int(rejected, "position"), 0, "失败报告应保留字段起点。")
	assert_eq(GFVariantData.get_option_int(rejected, "next_position"), 0, "失败报告不得发布部分推进。")
	assert_eq(limited.get_position(), 0, "组合读取超限时游标必须原子回滚。")

	var exact: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0x01, 0x61]))
	exact.max_read_byte_count = 2
	var accepted: Dictionary = exact.try_read_var_utf8()

	assert_true(GFVariantData.get_option_bool(accepted, "ok"), "prefix + payload 恰好命中上限时应成功。")
	assert_eq(GFVariantData.get_option_string(accepted, "value"), "a", "成功报告应返回原文本。")
	assert_eq(GFVariantData.get_option_int(accepted, "next_position"), 2, "成功报告应推进完整字段长度。")
	assert_eq(exact.get_position(), 2, "成功读取应提交完整字段位置。")

	var two_byte_prefix: PackedByteArray = PackedByteArray()
	var _resized: Error = two_byte_prefix.resize(130) as Error
	two_byte_prefix[0] = 0x80
	two_byte_prefix[1] = 0x01
	for index: int in range(2, two_byte_prefix.size()):
		two_byte_prefix[index] = 0x61
	var second_boundary: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(two_byte_prefix)
	second_boundary.max_read_byte_count = 129
	var second_rejected: Dictionary = second_boundary.try_read_var_utf8()

	assert_false(GFVariantData.get_option_bool(second_rejected, "ok"), "多字节前缀也必须进入组合预算。")
	assert_eq(second_boundary.get_position(), 0, "多字节前缀超限时必须回滚。")

	second_boundary.max_read_byte_count = 130
	var second_accepted: Dictionary = second_boundary.try_read_var_utf8()
	assert_true(GFVariantData.get_option_bool(second_accepted, "ok"), "多字节前缀组合长度恰好命中上限时应成功。")
	assert_eq(
		GFVariantData.get_option_string(second_accepted, "value").length(),
		128,
		"多字节前缀成功读取应返回完整 payload。"
	)


func test_byte_cursor_last_error_describes_only_the_most_recent_operation() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new()

	cursor.write_u8(256)
	assert_eq(cursor.get_last_error(), ERR_INVALID_PARAMETER, "失败 void 写入应立即暴露错误。")
	assert_eq(cursor.get_position(), 0, "失败 void 写入不得推进。")

	cursor.write_u8(1)
	assert_eq(cursor.get_last_error(), OK, "后续成功操作应按最近错误契约清除旧错误。")
	assert_eq(cursor.get_bytes(), PackedByteArray([1]), "后续合法写入应独立提交。")


func test_byte_cursor_utf8_validator_covers_unicode_scalar_boundaries() -> void:
	var valid_sequences: Array[PackedByteArray] = [
		PackedByteArray([0xc2, 0x80]),
		PackedByteArray([0xdf, 0xbf]),
		PackedByteArray([0xe0, 0xa0, 0x80]),
		PackedByteArray([0xed, 0x9f, 0xbf]),
		PackedByteArray([0xee, 0x80, 0x80]),
		PackedByteArray([0xf0, 0x90, 0x80, 0x80]),
		PackedByteArray([0xf4, 0x8f, 0xbf, 0xbf]),
	]
	for bytes: PackedByteArray in valid_sequences:
		var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(bytes)
		var _decoded: String = cursor.read_utf8(bytes.size())
		assert_eq(cursor.get_last_error(), OK, "合法 Unicode scalar 边界应通过 UTF-8 校验。")
		assert_true(cursor.is_eof(), "合法 UTF-8 应完整推进。")

	var invalid_sequences: Array[PackedByteArray] = [
		PackedByteArray([0x80]),
		PackedByteArray([0xc0, 0x80]),
		PackedByteArray([0xe0, 0x9f, 0xbf]),
		PackedByteArray([0xed, 0xa0, 0x80]),
		PackedByteArray([0xf0, 0x8f, 0xbf, 0xbf]),
		PackedByteArray([0xf4, 0x90, 0x80, 0x80]),
		PackedByteArray([0xf5, 0x80, 0x80, 0x80]),
		PackedByteArray([0xe2, 0x82]),
	]
	for bytes: PackedByteArray in invalid_sequences:
		var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(bytes)
		assert_eq(cursor.read_utf8(bytes.size()), "", "非法 UTF-8 不应产生文本。")
		assert_eq(cursor.get_last_error(), ERR_PARSE_ERROR, "非法 UTF-8 应报告解析错误。")
		assert_eq(cursor.get_position(), 0, "非法 UTF-8 不应推进 position。")
