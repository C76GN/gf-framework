## 测试 GFBoundedJsonObjectReader 的公开有界 JSON object 读取契约。
extends GutTest


# --- 常量 ---

const READER_PATH: String = "res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd"
const RES_FIXTURE_PATH: String = "res://tests/gf_core/tmp_bounded_json_object_reader.json"
const USER_FIXTURE_PATH: String = "user://gf_bounded_json_object_reader.json"
const EDITOR_READER = preload("res://addons/gf/kernel/editor/gf_bounded_json_reader.gd")
const EXTENSION_READER = preload(
	"res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd"
)
const REPORT_KEYS: Array[String] = [
	"data",
	"error",
	"error_kind",
	"max_bytes",
	"max_depth",
	"ok",
	"size_bytes",
	"source_path",
]


# --- GUT 生命周期方法 ---

func after_each() -> void:
	_remove_fixture(RES_FIXTURE_PATH)
	_remove_fixture(USER_FIXTURE_PATH)


# --- 测试用例 ---

func test_public_bounded_json_object_reader_is_available() -> void:
	assert_true(
		ResourceLoader.exists(READER_PATH),
		"gf.kernel 应提供项目运行时与工具可复用的公开有界 JSON object reader。"
	)


func test_parse_object_returns_stable_json_safe_report() -> void:
	var text: String = '{"value":7}'
	var report: Dictionary = GFBoundedJsonObjectReader.parse_object(text)
	var encoded: String = JSON.stringify(report)
	var decoded: Variant = JSON.parse_string(encoded)

	assert_true(_option_bool(report, "ok"), "合法 object 文本应读取成功。")
	assert_eq(_sorted_string_keys(report), REPORT_KEYS, "报告字段必须保持固定同构。")
	assert_eq(_option_dictionary(report, "data"), { "value": 7.0 })
	assert_eq(_option_string(report, "source_path"), "", "文本入口不应伪造来源路径。")
	assert_eq(_option_int(report, "size_bytes"), text.to_utf8_buffer().size())
	assert_eq(_option_string(report, "error_kind"), "")
	assert_eq(_option_string(report, "error"), "")
	assert_eq(_option_int(report, "max_bytes"), GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES)
	assert_eq(_option_int(report, "max_depth"), GFBoundedJsonObjectReader.DEFAULT_MAX_DEPTH)
	assert_true(decoded is Dictionary, "报告必须可直接 JSON.stringify/parse 往返。")
	if decoded is Dictionary:
		var decoded_report: Dictionary = decoded
		assert_eq(_sorted_string_keys(decoded_report), REPORT_KEYS)
		assert_true(decoded_report["error_kind"] is String, "error_kind 必须是 JSON 原生 String。")


func test_parse_object_enforces_ascii_and_utf8_byte_boundaries() -> void:
	var ascii_text: String = '{"value":"ascii"}'
	var utf8_text: String = '{"value":"汉字"}'
	var ascii_bytes: int = ascii_text.to_utf8_buffer().size()
	var utf8_bytes: int = utf8_text.to_utf8_buffer().size()
	var ascii_exact: Dictionary = GFBoundedJsonObjectReader.parse_object(
		ascii_text,
		ascii_bytes
	)
	var ascii_over: Dictionary = GFBoundedJsonObjectReader.parse_object(
		ascii_text,
		ascii_bytes - 1
	)
	var utf8_exact: Dictionary = GFBoundedJsonObjectReader.parse_object(
		utf8_text,
		utf8_bytes
	)
	var utf8_over: Dictionary = GFBoundedJsonObjectReader.parse_object(
		utf8_text,
		utf8_bytes - 1
	)

	assert_true(_option_bool(ascii_exact, "ok"), "ASCII 精确字节边界应通过。")
	assert_eq(_option_string(ascii_over, "error_kind"), "payload_too_large")
	assert_true(_option_bool(utf8_exact, "ok"), "多字节 UTF-8 精确字节边界应通过。")
	assert_eq(_option_int(utf8_exact, "size_bytes"), utf8_bytes)
	assert_true(utf8_bytes > utf8_text.length(), "测试输入必须证明字符数不等于 UTF-8 字节数。")
	assert_eq(_option_string(utf8_over, "error_kind"), "payload_too_large")


func test_parse_object_enforces_lexical_depth_and_ignores_string_delimiters() -> void:
	var depth_three: String = '{"a":[{"b":true}]}'
	var string_delimiters: String = '{"value":"{[\\\"quoted\\\"]}","slash":"\\\\\\\""}'
	var exact: Dictionary = GFBoundedJsonObjectReader.parse_object(
		depth_three,
		GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
		3
	)
	var over: Dictionary = GFBoundedJsonObjectReader.parse_object(
		depth_three,
		GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
		2
	)
	var quoted: Dictionary = GFBoundedJsonObjectReader.parse_object(
		string_delimiters,
		GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
		1
	)

	assert_true(_option_bool(exact, "ok"), "根 object 计为第一层，精确深度应通过。")
	assert_eq(_option_string(over, "error_kind"), "nesting_too_deep")
	assert_true(_option_bool(quoted, "ok"), "字符串内括号、转义引号和反斜杠不应计入深度。")


func test_parse_object_reports_parse_and_root_type_failures() -> void:
	var malformed: Dictionary = GFBoundedJsonObjectReader.parse_object('{"value":')
	var non_finite_number: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1e99999}'
	)
	var underflowing_number: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1e-99999}'
	)
	var zero_with_excessive_exponent: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":0e99999}'
	)
	var finite_large_number: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1e308}'
	)
	var parser_non_finite_number: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1e309}'
	)
	var long_zero_exponent: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1e' + "0".repeat(32 * 1024) + '1}'
	)
	var cancelling_long_mantissa: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":' + "1" + "0".repeat(999) + 'e-700}'
	)
	var extreme_exponent_after_long_mantissa: Dictionary = (
		GFBoundedJsonObjectReader.parse_object(
			'{"value":' + "1" + "0".repeat(10_017) + 'e-99999}'
		)
	)
	var malformed_leading_zero_run: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":' + "0".repeat(600) + '}'
	)
	var malformed_embedded_overflow: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":1-1e99999}'
	)
	var nul_escape_text: String = '{"value":"' + String.chr(92) + 'u0000"}'
	var nul_escape: Dictionary = GFBoundedJsonObjectReader.parse_object(nul_escape_text)
	var escaped_nul_text: String = (
		'{"value":"' + String.chr(92) + String.chr(92) + 'u0000"}'
	)
	var escaped_nul: Dictionary = GFBoundedJsonObjectReader.parse_object(escaped_nul_text)
	var array_root: Dictionary = GFBoundedJsonObjectReader.parse_object("[]")
	var scalar_root: Dictionary = GFBoundedJsonObjectReader.parse_object("7")
	var null_root: Dictionary = GFBoundedJsonObjectReader.parse_object("null")

	assert_eq(_option_string(malformed, "error_kind"), "parse_failed")
	assert_eq(_option_string(non_finite_number, "error_kind"), "parse_failed")
	assert_eq(_option_string(underflowing_number, "error_kind"), "parse_failed")
	assert_eq(_option_string(zero_with_excessive_exponent, "error_kind"), "parse_failed")
	assert_true(_option_bool(finite_large_number, "ok"), "明确有限的大浮点值不得被词法预检误拒绝。")
	assert_eq(
		_option_string(parser_non_finite_number, "error_kind"),
		"parse_failed",
		"词法上安全但解析为非有限浮点的数值必须在报告返回前拒绝。"
	)
	assert_true(_option_bool(long_zero_exponent, "ok"), "长零前缀指数应在线性时间内解析。")
	assert_true(
		_option_bool(cancelling_long_mantissa, "ok"),
		"长尾数与负指数相抵消时不得按显式指数误拒绝。"
	)
	assert_eq(
		_option_string(extreme_exponent_after_long_mantissa, "error_kind"),
		"parse_failed",
		"指数解析的饱和值必须大于绝对字节预算内可抵消的尾数偏移。"
	)
	assert_eq(
		_option_string(malformed_leading_zero_run, "error_kind"),
		"parse_failed",
		"非法长前导零数字必须在 JSON.parse() 前拒绝且不得触发引擎警告。"
	)
	assert_eq(
		_option_string(malformed_embedded_overflow, "error_kind"),
		"parse_failed",
		"畸形数字串中的溢出子串不得绕过纯词法预检。"
	)
	assert_eq(
		_option_string(nul_escape, "error_kind"),
		"parse_failed",
		"解码为 U+0000 的字符串转义必须在 JSON.parse() 前拒绝。"
	)
	assert_true(_option_bool(escaped_nul, "ok"), "转义后的字面 \\u0000 不应误判为 NUL。")
	assert_eq(_option_string(array_root, "error_kind"), "invalid_root_type")
	assert_eq(_option_string(scalar_root, "error_kind"), "invalid_root_type")
	assert_eq(_option_string(null_root, "error_kind"), "invalid_root_type")
	for report: Dictionary in [
		malformed,
		non_finite_number,
		underflowing_number,
		zero_with_excessive_exponent,
		parser_non_finite_number,
		extreme_exponent_after_long_mantissa,
		malformed_leading_zero_run,
		malformed_embedded_overflow,
		nul_escape,
		array_root,
		scalar_root,
		null_root,
	]:
		assert_false(_option_bool(report, "ok"))
		assert_true(_option_dictionary(report, "data").is_empty(), "失败报告不得保留半解析数据。")
		assert_eq(_sorted_string_keys(report), REPORT_KEYS)


func test_budget_values_can_only_tighten_absolute_limits() -> void:
	var oversized: Dictionary = GFBoundedJsonObjectReader.parse_object(
		"{}",
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_BYTES + 1,
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_DEPTH + 1
	)
	var zero: Dictionary = GFBoundedJsonObjectReader.parse_object("{}", 0, 0)
	var negative: Dictionary = GFBoundedJsonObjectReader.parse_object("{}", -1, -1)
	var tightened: Dictionary = GFBoundedJsonObjectReader.parse_object("{}", 2, 1)

	for report: Dictionary in [oversized, zero, negative]:
		assert_eq(_option_int(report, "max_bytes"), GFBoundedJsonObjectReader.ABSOLUTE_MAX_BYTES)
		assert_eq(_option_int(report, "max_depth"), GFBoundedJsonObjectReader.ABSOLUTE_MAX_DEPTH)
	assert_true(_option_bool(tightened, "ok"), "正数小预算应精确收紧。")
	assert_eq(_option_int(tightened, "max_bytes"), 2)
	assert_eq(_option_int(tightened, "max_depth"), 1)

	var oversized_payload: String = "x".repeat(
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_BYTES + 1
	)
	for requested_bytes: int in [
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_BYTES + 1024,
		0,
		-1,
	]:
		var payload_report: Dictionary = GFBoundedJsonObjectReader.parse_object(
			oversized_payload,
			requested_bytes
		)
		assert_eq(
			_option_string(payload_report, "error_kind"),
			"payload_too_large",
			"超大、零或负预算都不得绕过绝对字节上限。"
		)

	var exact_depth_text: String = '{"value":' + "[".repeat(63) + "0" + "]".repeat(63) + "}"
	var excessive_depth_text: String = '{"value":' + "[".repeat(64) + "0" + "]".repeat(64) + "}"
	var exact_depth_report: Dictionary = GFBoundedJsonObjectReader.parse_object(
		exact_depth_text,
		GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_DEPTH
	)
	assert_true(_option_bool(exact_depth_report, "ok"), "精确 64 层边界应通过。")
	for requested_depth: int in [
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_DEPTH + 64,
		0,
		-1,
	]:
		var depth_report: Dictionary = GFBoundedJsonObjectReader.parse_object(
			excessive_depth_text,
			GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
			requested_depth
		)
		assert_eq(
			_option_string(depth_report, "error_kind"),
			"nesting_too_deep",
			"超大、零或负预算都不得绕过绝对深度上限。"
		)
	var malformed_overdepth: Dictionary = GFBoundedJsonObjectReader.parse_object(
		'{"value":' + "[".repeat(64),
		GFBoundedJsonObjectReader.DEFAULT_MAX_BYTES,
		GFBoundedJsonObjectReader.ABSOLUTE_MAX_DEPTH
	)
	assert_eq(
		_option_string(malformed_overdepth, "error_kind"),
		"nesting_too_deep",
		"词法深度准入必须先于 JSON.parse() 处理畸形输入。"
	)


func test_read_object_supports_res_and_user_paths_with_exact_size() -> void:
	var text: String = '{"source":"file"}'
	_write_text_fixture(RES_FIXTURE_PATH, text)
	_write_text_fixture(USER_FIXTURE_PATH, text)
	var res_report: Dictionary = GFBoundedJsonObjectReader.read_object(
		RES_FIXTURE_PATH,
		text.to_utf8_buffer().size()
	)
	var user_report: Dictionary = GFBoundedJsonObjectReader.read_object(
		USER_FIXTURE_PATH.replace("/", "\\"),
		text.to_utf8_buffer().size()
	)
	var over_report: Dictionary = GFBoundedJsonObjectReader.read_object(
		USER_FIXTURE_PATH,
		text.to_utf8_buffer().size() - 1
	)

	assert_true(_option_bool(res_report, "ok"), "res:// 文件应能在精确边界读取。")
	assert_true(_option_bool(user_report, "ok"), "user:// 文件应能从规范化路径读取。")
	assert_eq(_option_string(res_report, "source_path"), RES_FIXTURE_PATH)
	assert_eq(_option_string(user_report, "source_path"), USER_FIXTURE_PATH)
	assert_eq(_option_int(user_report, "size_bytes"), text.to_utf8_buffer().size())
	assert_eq(_option_string(over_report, "error_kind"), "payload_too_large")


func test_read_object_reports_missing_and_invalid_utf8_inputs() -> void:
	var missing: Dictionary = GFBoundedJsonObjectReader.read_object(USER_FIXTURE_PATH)

	assert_eq(_option_string(missing, "error_kind"), "open_failed")
	assert_eq(_option_string(missing, "source_path"), USER_FIXTURE_PATH)
	var invalid_sequences: Array[PackedByteArray] = [
		PackedByteArray([0x80]),
		PackedByteArray([0xc0, 0xaf]),
		PackedByteArray([0xed, 0xa0, 0x80]),
		PackedByteArray([0xf4, 0x90, 0x80, 0x80]),
		PackedByteArray([0xe2, 0x82]),
	]
	for invalid_sequence: PackedByteArray in invalid_sequences:
		_write_bytes_fixture(USER_FIXTURE_PATH, invalid_sequence)
		var invalid_utf8: Dictionary = GFBoundedJsonObjectReader.read_object(USER_FIXTURE_PATH)
		assert_eq(_option_string(invalid_utf8, "error_kind"), "read_failed")
		assert_eq(_option_int(invalid_utf8, "size_bytes"), invalid_sequence.size())
		assert_true(_option_dictionary(invalid_utf8, "data").is_empty())

	var nul_truncated_bytes: PackedByteArray = PackedByteArray([0x7b, 0x7d, 0x00, 0x5b, 0x5d])
	_write_bytes_fixture(USER_FIXTURE_PATH, nul_truncated_bytes)
	var nul_report: Dictionary = GFBoundedJsonObjectReader.read_object(USER_FIXTURE_PATH)
	assert_eq(_option_string(nul_report, "error_kind"), "parse_failed")
	assert_eq(_option_int(nul_report, "size_bytes"), nul_truncated_bytes.size())
	assert_true(_option_dictionary(nul_report, "data").is_empty())


func test_internal_adapters_preserve_legacy_report_shapes() -> void:
	var editor_success: Dictionary = EDITOR_READER.parse_object("{}", 16, 2)
	var editor_failure: Dictionary = EDITOR_READER.parse_object("[]", 16, 2)
	var editor_default_budget: Dictionary = EDITOR_READER.parse_object("{}", 0, 0)
	var text: String = '{"adapter":true}'
	_write_text_fixture(USER_FIXTURE_PATH, text)
	var extension_budget: Dictionary = EXTENSION_READER.make_budget_state({
		"max_json_total_bytes": text.to_utf8_buffer().size(),
	})
	var extension_success: Dictionary = EXTENSION_READER.read_object_report(
		USER_FIXTURE_PATH,
		{},
		extension_budget
	)
	var extension_exhausted: Dictionary = EXTENSION_READER.read_object_report(
		USER_FIXTURE_PATH,
		{},
		extension_budget
	)
	var nested_text: String = '{"outer":{"inner":true}}'
	_write_text_fixture(USER_FIXTURE_PATH, nested_text)
	var extension_depth_budget: Dictionary = EXTENSION_READER.make_budget_state({
		"max_json_total_bytes": nested_text.to_utf8_buffer().size(),
		"max_json_depth": 1,
	})
	var extension_depth_failure: Dictionary = EXTENSION_READER.read_object_report(
		USER_FIXTURE_PATH,
		{},
		extension_depth_budget
	)

	assert_eq(
		_sorted_string_keys(editor_success),
		["data", "error", "error_kind", "ok"],
		"kernel/editor adapter 必须保留既有四字段报告。"
	)
	assert_true(editor_success["error_kind"] is StringName, "旧 editor kind 仍应是 StringName。")
	assert_eq(_sorted_string_keys(editor_failure), _sorted_string_keys(editor_success))
	assert_true(
		_option_bool(editor_default_budget, "ok"),
		"editor adapter 的非正预算应沿用公共 primitive 的默认硬上限。"
	)
	assert_true(_option_bool(extension_success, "ok"), "预算内 extension adapter 应成功。")
	assert_eq(
		_sorted_string_keys(extension_success),
		["budget_exceeded", "data", "errors", "ok", "size_bytes", "source_path"],
		"kernel/extension adapter 必须保留既有六字段报告。"
	)
	assert_eq(
		_option_int(extension_budget, "consumed_bytes"),
		text.to_utf8_buffer().size(),
		"extension 累计预算必须按公共 reader 观测到的同一份字节结算。"
	)
	assert_false(_option_bool(extension_exhausted, "ok"), "累计预算耗尽后不得再次读取。")
	assert_true(_option_bool(extension_exhausted, "budget_exceeded"))
	assert_eq(
		_option_int(extension_exhausted, "size_bytes"),
		0,
		"累计预算已耗尽时必须在读取和 JSON.parse 前失败。"
	)
	assert_true(
		_option_string_array(extension_exhausted, "errors").any(
			func(message: String) -> bool: return message.contains("max_json_total_bytes")
		),
		"耗尽分支必须保留稳定累计预算诊断。"
	)
	assert_false(_option_bool(extension_depth_failure, "ok"))
	assert_true(
		_option_bool(extension_depth_failure, "budget_exceeded"),
		"extension adapter 的词法深度超限必须持久传播共享预算状态。"
	)


# --- 私有/辅助方法 ---

func _write_text_fixture(path: String, text: String) -> void:
	_write_bytes_fixture(path, text.to_utf8_buffer())


func _write_bytes_fixture(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试 fixture 必须可写：%s" % path)
	if file == null:
		return
	var stored: bool = file.store_buffer(bytes)
	var write_error: Error = file.get_error()
	file.close()
	assert_true(stored, "测试 fixture 的全部 bytes 必须完成写入。")
	assert_eq(write_error, OK, "测试 fixture 写入必须成功。")


func _remove_fixture(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_path)
		assert_eq(remove_error, OK, "测试 fixture 清理必须成功：%s" % path)


func _sorted_string_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_key: Variant in dictionary.keys():
		assert_true(raw_key is String, "JSON-safe report key 必须是 String。")
		if raw_key is String:
			var key: String = raw_key
			result.append(key)
	result.sort()
	return result


func _option_bool(options: Dictionary, key: String, default_value: bool = false) -> bool:
	if options.has(key) and options[key] is bool:
		var value: bool = options[key]
		return value
	return default_value


func _option_int(options: Dictionary, key: String, default_value: int = 0) -> int:
	if options.has(key) and options[key] is int:
		var value: int = options[key]
		return value
	return default_value


func _option_string(options: Dictionary, key: String, default_value: String = "") -> String:
	if options.has(key) and options[key] is String:
		var value: String = options[key]
		return value
	return default_value


func _option_dictionary(options: Dictionary, key: String) -> Dictionary:
	if options.has(key) and options[key] is Dictionary:
		var value: Dictionary = options[key]
		return value
	return {}


func _option_string_array(options: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	if not options.has(key) or not options[key] is Array:
		return result
	var values: Array = options[key]
	for raw_value: Variant in values:
		if raw_value is String:
			var value: String = raw_value
			result.append(value)
	return result
