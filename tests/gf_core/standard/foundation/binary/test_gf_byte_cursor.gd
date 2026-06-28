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


func test_byte_cursor_invalid_utf8_does_not_advance() -> void:
	var cursor: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([0xc3, 0x28]))

	assert_eq(cursor.read_utf8(2), "", "非法 UTF-8 应返回空字符串。")
	assert_eq(cursor.get_position(), 0, "非法 UTF-8 不应推进游标。")
	assert_eq(cursor.get_last_error(), ERR_PARSE_ERROR, "非法 UTF-8 应报告解析错误。")


func test_byte_cursor_read_limits_and_invalid_offset_are_explicit() -> void:
	var limited: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.new(PackedByteArray([1, 2, 3]))
	limited.max_read_byte_count = 2
	var bytes: PackedByteArray = limited.read_bytes(3)

	assert_true(bytes.is_empty(), "超过读取上限时不应切片 payload。")
	assert_eq(limited.get_position(), 0, "超过读取上限不应推进游标。")
	assert_eq(limited.get_last_error(), ERR_INVALID_PARAMETER, "超过读取上限应报告无效参数。")

	var invalid_offset: GF_BYTE_CURSOR_SCRIPT = GF_BYTE_CURSOR_SCRIPT.from_bytes(PackedByteArray([1, 2, 3]), 99)

	assert_eq(invalid_offset.get_position(), 3, "无效 offset 创建的游标应停在 EOF，而不是回到 0。")
	assert_eq(invalid_offset.get_last_error(), ERR_INVALID_PARAMETER, "无效 offset 应保留错误码。")


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
