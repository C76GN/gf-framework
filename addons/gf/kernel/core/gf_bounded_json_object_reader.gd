## GFBoundedJsonObjectReader: 有界 JSON object 读取器。
##
## 在调用 JSON.parse() 前限制 UTF-8 字节数与对象/数组词法嵌套深度，
## 适合项目运行时、编辑器工具和 headless 工具读取不可信 JSON object 输入。
## 该类不负责恢复 Godot Variant marker；解析后的遍历预算由上层 codec 另行处理。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 11.0.0
class_name GFBoundedJsonObjectReader
extends RefCounted


# --- 常量 ---

## 默认允许的 JSON UTF-8 字节数。
## [br]
## @api public
## [br]
## @since 11.0.0
const DEFAULT_MAX_BYTES: int = 1024 * 1024

## 框架允许的 JSON UTF-8 字节数绝对上限。
## 调用方只能收紧预算，不能越过该上限或关闭字节限制。
## [br]
## @api public
## [br]
## @since 11.0.0
const ABSOLUTE_MAX_BYTES: int = 1024 * 1024

## 默认允许的 JSON 对象/数组词法嵌套深度。
## [br]
## @api public
## [br]
## @since 11.0.0
const DEFAULT_MAX_DEPTH: int = 64

## 框架允许的 JSON 对象/数组词法嵌套深度绝对上限。
## 调用方只能收紧预算，不能越过该上限或关闭深度限制。
## [br]
## @api public
## [br]
## @since 11.0.0
const ABSOLUTE_MAX_DEPTH: int = 64


# --- 公共方法 ---

## 解析有界 JSON object 文本。
## [br]
## max_bytes 与 max_depth 只能收紧框架绝对上限；非正值恢复默认预算，
## 超过绝对上限的值会被钳制。字节与词法深度检查发生在 JSON.parse() 前。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param text: 要解析的 JSON 文本。
## [br]
## @param max_bytes: 调用方请求的最大 UTF-8 字节数。
## [br]
## @param max_depth: 调用方请求的最大对象/数组词法嵌套深度。
## [br]
## @return JSON-safe 读取报告；max_bytes 与 max_depth 为实际生效预算。
## [br]
## 成功时 data 为解析后的 object，error_kind 与 error 为空；失败时 data 为空且
## error_kind 非空。原始 NUL、解码为 U+0000 的字符串转义、数值溢出或解析后
## 出现非有限数字时以 parse_failed 拒绝。
## 文本入口的 source_path 为空，size_bytes 是 UTF-8 输入字节数。
## [br]
## @schema return: Dictionary containing ok: bool, data: Dictionary, source_path: String, size_bytes: int, error_kind: String, error: String, max_bytes: int, and max_depth: int. error_kind is one of "", "open_failed", "payload_too_large", "read_failed", "nesting_too_deep", "parse_failed", or "invalid_root_type".
static func parse_object(
	text: String,
	max_bytes: int = DEFAULT_MAX_BYTES,
	max_depth: int = DEFAULT_MAX_DEPTH
) -> Dictionary:
	var effective_max_bytes: int = _effective_limit(
		max_bytes,
		DEFAULT_MAX_BYTES,
		ABSOLUTE_MAX_BYTES
	)
	var effective_max_depth: int = _effective_limit(
		max_depth,
		DEFAULT_MAX_DEPTH,
		ABSOLUTE_MAX_DEPTH
	)
	return _parse_object_bytes_without_digest(
		text.to_utf8_buffer(),
		"",
		effective_max_bytes,
		effective_max_depth
	)


## 读取并解析有界 JSON object 文件。
## [br]
## 入口规范化资源路径，最多读取实际字节预算加一字节，并使用同一份原始 bytes
## 完成大小、UTF-8、词法深度和 JSON object 校验。支持 Godot FileAccess 可读取的
## res:// 与 user:// 等路径。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param path: 要读取的 JSON 文件路径。
## [br]
## @param max_bytes: 调用方请求的最大 UTF-8 字节数。
## [br]
## @param max_depth: 调用方请求的最大对象/数组词法嵌套深度。
## [br]
## @return JSON-safe 读取报告；max_bytes 与 max_depth 为实际生效预算。
## [br]
## 成功时 data 为解析后的 object，error_kind 与 error 为空；失败时 data 为空且
## error_kind 非空。source_path 为规范化路径；size_bytes 为已观测的原始文件字节数。
## read_failed 同时覆盖 I/O 错误、读取期长度漂移与无效 UTF-8；原始 NUL、
## 解码为 U+0000 的字符串转义、数值溢出或解析后出现非有限数字时以
## parse_failed 拒绝。
## [br]
## @schema return: Dictionary containing ok: bool, data: Dictionary, source_path: String, size_bytes: int, error_kind: String, error: String, max_bytes: int, and max_depth: int. error_kind is one of "", "open_failed", "payload_too_large", "read_failed", "nesting_too_deep", "parse_failed", or "invalid_root_type".
static func read_object(
	path: String,
	max_bytes: int = DEFAULT_MAX_BYTES,
	max_depth: int = DEFAULT_MAX_DEPTH
) -> Dictionary:
	var report: Dictionary = read_object_with_content_sha256(
		path,
		max_bytes,
		max_depth
	)
	var _digest_removed: bool = report.erase("content_sha256")
	return report


# --- 框架内部方法 ---

## 读取有界 JSON object，并返回与完成解析的同一份原始 bytes 的 SHA-256。
##
## 该入口供框架内部把已验证对象与其内容身份绑定；不会为摘要再次打开或读取文件。
## 公开 read_object() 继续保留原有八字段报告。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param path: 要读取的 JSON 文件路径。
## [br]
## @param max_bytes: 调用方请求的最大 UTF-8 字节数。
## [br]
## @param max_depth: 调用方请求的最大对象/数组词法嵌套深度。
## [br]
## @return: 有界读取报告；content_sha256 仅在取得完整原始 bytes 后非空。
## [br]
## @schema return: Dictionary containing the public read_object fields plus content_sha256: String.
static func read_object_with_content_sha256(
	path: String,
	max_bytes: int = DEFAULT_MAX_BYTES,
	max_depth: int = DEFAULT_MAX_DEPTH
) -> Dictionary:
	var report: Dictionary = _read_object_report(path, max_bytes, max_depth)
	if not report.has("content_sha256"):
		report["content_sha256"] = ""
	return report


# --- 私有/辅助方法 ---

static func _read_object_report(
	path: String,
	max_bytes: int,
	max_depth: int
) -> Dictionary:
	var effective_max_bytes: int = _effective_limit(
		max_bytes,
		DEFAULT_MAX_BYTES,
		ABSOLUTE_MAX_BYTES
	)
	var effective_max_depth: int = _effective_limit(
		max_depth,
		DEFAULT_MAX_DEPTH,
		ABSOLUTE_MAX_DEPTH
	)
	var normalized_path: String = GFPathTools.normalize_resource_path(path)
	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return _make_report(
			false,
			{},
			normalized_path,
			0,
			"open_failed",
			"JSON 文件无法打开：%s (%s)" % [
				normalized_path,
				error_string(FileAccess.get_open_error()),
			],
			effective_max_bytes,
			effective_max_depth
		)

	var declared_size_bytes: int = file.get_length()
	if declared_size_bytes > effective_max_bytes:
		file.close()
		return _make_report(
			false,
			{},
			normalized_path,
			declared_size_bytes,
			"payload_too_large",
			"JSON 文件超过 %d 字节上限：%s" % [
				effective_max_bytes,
				normalized_path,
			],
			effective_max_bytes,
			effective_max_depth
		)

	var bytes: PackedByteArray = file.get_buffer(effective_max_bytes + 1)
	var read_error: Error = file.get_error()
	var observed_size_bytes: int = file.get_length()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return _make_report(
			false,
			{},
			normalized_path,
			bytes.size(),
			"read_failed",
			"JSON 文件读取失败：%s (%s)" % [
				normalized_path,
				error_string(read_error),
			],
			effective_max_bytes,
			effective_max_depth
		)
	if bytes.size() > effective_max_bytes or observed_size_bytes > effective_max_bytes:
		return _make_report(
			false,
			{},
			normalized_path,
			maxi(bytes.size(), observed_size_bytes),
			"payload_too_large",
			"JSON 文件超过 %d 字节上限：%s" % [
				effective_max_bytes,
				normalized_path,
			],
			effective_max_bytes,
			effective_max_depth
		)
	if observed_size_bytes != bytes.size():
		return _make_report(
			false,
			{},
			normalized_path,
			bytes.size(),
			"read_failed",
			"JSON 文件读取期间发生变化：%s" % normalized_path,
			effective_max_bytes,
			effective_max_depth
		)
	return _parse_object_bytes(
		bytes,
		normalized_path,
		effective_max_bytes,
		effective_max_depth
	)


static func _parse_object_bytes(
	bytes: PackedByteArray,
	source_path: String,
	max_bytes: int,
	max_depth: int
) -> Dictionary:
	var report: Dictionary = _parse_object_bytes_without_digest(
		bytes,
		source_path,
		max_bytes,
		max_depth
	)
	report["content_sha256"] = _content_sha256(bytes)
	return report


static func _parse_object_bytes_without_digest(
	bytes: PackedByteArray,
	source_path: String,
	max_bytes: int,
	max_depth: int
) -> Dictionary:
	var size_bytes: int = bytes.size()
	if size_bytes > max_bytes:
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"payload_too_large",
			"JSON 输入超过 %d 字节上限。" % max_bytes,
			max_bytes,
			max_depth
		)

	if bytes.has(0):
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"parse_failed",
			"JSON 输入不得包含原始 NUL 字节。",
			max_bytes,
			max_depth
		)
	if not _is_valid_utf8(bytes):
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"read_failed",
			"JSON 输入不是有效 UTF-8。",
			max_bytes,
			max_depth
		)
	var text: String = bytes.get_string_from_utf8()
	if _exceeds_json_depth(text, max_depth):
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"nesting_too_deep",
			"JSON 嵌套深度超过 %d 层上限。" % max_depth,
			max_bytes,
			max_depth
		)
	var normalized_number_fragments: PackedStringArray = (
		_normalize_json_numbers_for_parser(text)
	)
	if normalized_number_fragments.is_empty():
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"parse_failed",
			"JSON 数字超出有限值范围。",
			max_bytes,
			max_depth
		)
	var parser_text: String = "".join(normalized_number_fragments)
	if _contains_json_nul_escape(text):
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"parse_failed",
			"JSON 字符串转义不得解码为 U+0000。",
			max_bytes,
			max_depth
		)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(parser_text)
	if parse_error != OK:
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"parse_failed",
			"JSON 解析失败（第 %d 行）：%s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			],
			max_bytes,
			max_depth
		)
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"invalid_root_type",
			"JSON 根节点必须是对象。",
			max_bytes,
			max_depth
		)
	var data: Dictionary = parsed
	if not _has_only_json_safe_numbers(data):
		return _make_report(
			false,
			{},
			source_path,
			size_bytes,
			"parse_failed",
			"JSON 数字必须是有限值。",
			max_bytes,
			max_depth
		)
	return _make_report(
		true,
		data,
		source_path,
		size_bytes,
		"",
		"",
		max_bytes,
		max_depth
	)


static func _content_sha256(bytes: PackedByteArray) -> String:
	var hashing_context: HashingContext = HashingContext.new()
	if hashing_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing_context.update(bytes) != OK:
		return ""
	var digest_bytes: PackedByteArray = hashing_context.finish()
	if digest_bytes.size() != 32:
		return ""
	return digest_bytes.hex_encode()


static func _effective_limit(requested: int, fallback: int, absolute_maximum: int) -> int:
	if requested <= 0:
		return fallback
	return mini(requested, absolute_maximum)


static func _exceeds_json_depth(text: String, max_depth: int) -> bool:
	var depth: int = 0
	var in_string: bool = false
	var escaped: bool = false
	for index: int in text.length():
		var codepoint: int = text.unicode_at(index)
		if in_string:
			if escaped:
				escaped = false
			elif codepoint == 92:
				escaped = true
			elif codepoint == 34:
				in_string = false
			continue
		if codepoint == 34:
			in_string = true
		elif codepoint == 123 or codepoint == 91:
			depth += 1
			if depth > max_depth:
				return true
		elif codepoint == 125 or codepoint == 93:
			depth = maxi(depth - 1, 0)
	return false


static func _normalize_json_numbers_for_parser(text: String) -> PackedStringArray:
	var fragments: PackedStringArray = PackedStringArray()
	var unchanged_start: int = 0
	var index: int = 0
	var in_string: bool = false
	var escaped: bool = false
	while index < text.length():
		var codepoint: int = text.unicode_at(index)
		if in_string:
			if escaped:
				escaped = false
			elif codepoint == 92:
				escaped = true
			elif codepoint == 34:
				in_string = false
			index += 1
			continue
		if codepoint == 34:
			in_string = true
			index += 1
			continue
		if codepoint == 45 or (codepoint >= 48 and codepoint <= 57):
			var end_index: int = _scan_json_number_candidate_end(text, index)
			var token: String = text.substr(index, end_index - index)
			if not _json_number_token_is_structurally_valid(token):
				return PackedStringArray()
			var normalized_token: String = _normalize_json_number_token(token)
			if normalized_token.is_empty():
				return PackedStringArray()
			if normalized_token != token:
				var _append_unchanged: bool = fragments.append(
					text.substr(unchanged_start, index - unchanged_start)
				)
				var _append_normalized: bool = fragments.append(normalized_token)
				unchanged_start = end_index
			index = end_index
			continue
		index += 1
	var _append_tail: bool = fragments.append(text.substr(unchanged_start))
	return fragments


static func _contains_json_nul_escape(text: String) -> bool:
	var index: int = 0
	var in_string: bool = false
	while index < text.length():
		var codepoint: int = text.unicode_at(index)
		if not in_string:
			if codepoint == 34:
				in_string = true
			index += 1
			continue
		if codepoint == 34:
			in_string = false
			index += 1
			continue
		if codepoint != 92:
			index += 1
			continue
		if index + 5 < text.length() and text.unicode_at(index + 1) == 117:
			var is_nul_escape: bool = true
			for offset: int in range(2, 6):
				if text.unicode_at(index + offset) != 48:
					is_nul_escape = false
					break
			if is_nul_escape:
				return true
		index += 2
	return false


static func _scan_json_number_candidate_end(text: String, start_index: int) -> int:
	var index: int = start_index
	while index < text.length():
		var codepoint: int = text.unicode_at(index)
		if (
			_is_ascii_digit(codepoint)
			or codepoint == 43
			or codepoint == 45
			or codepoint == 46
			or codepoint == 69
			or codepoint == 101
		):
			index += 1
			continue
		break
	return index


static func _json_number_token_is_structurally_valid(token: String) -> bool:
	var index: int = 0
	if token.is_empty():
		return false
	if token.unicode_at(index) == 45:
		index += 1
		if index >= token.length():
			return false
	var first_integer_digit: int = token.unicode_at(index)
	if first_integer_digit == 48:
		index += 1
		if index < token.length() and _is_ascii_digit(token.unicode_at(index)):
			return false
	elif first_integer_digit >= 49 and first_integer_digit <= 57:
		index += 1
		while index < token.length() and _is_ascii_digit(token.unicode_at(index)):
			index += 1
	else:
		return false
	if index < token.length() and token.unicode_at(index) == 46:
		index += 1
		var fraction_start: int = index
		while index < token.length() and _is_ascii_digit(token.unicode_at(index)):
			index += 1
		if index == fraction_start:
			return false
	if index < token.length():
		var exponent_marker: int = token.unicode_at(index)
		if exponent_marker != 69 and exponent_marker != 101:
			return false
		index += 1
		if index < token.length():
			var exponent_sign: int = token.unicode_at(index)
			if exponent_sign == 43 or exponent_sign == 45:
				index += 1
		var exponent_start: int = index
		while index < token.length() and _is_ascii_digit(token.unicode_at(index)):
			index += 1
		if index == exponent_start:
			return false
	return index == token.length()


static func _normalize_json_number_token(token: String) -> String:
	var parser_would_warn: bool = (
		_json_number_token_triggers_parser_exponent_warning(token)
	)
	var is_negative: bool = token.begins_with("-")
	var unsigned_token: String = token.trim_prefix("-")
	var exponent_index: int = unsigned_token.find("e")
	if exponent_index < 0:
		exponent_index = unsigned_token.find("E")
	var mantissa: String = unsigned_token
	var exponent: int = 0
	if exponent_index >= 0:
		mantissa = unsigned_token.substr(0, exponent_index)
		exponent = _parse_bounded_decimal_exponent(
			unsigned_token.substr(exponent_index + 1)
		)
	var decimal_index: int = mantissa.find(".")
	var integer_digits: String = mantissa
	var fraction_digits: String = ""
	if decimal_index >= 0:
		integer_digits = mantissa.substr(0, decimal_index)
		fraction_digits = mantissa.substr(decimal_index + 1)
	var combined_digits: String = integer_digits + fraction_digits
	var first_significant_index: int = -1
	for digit_index: int in combined_digits.length():
		if combined_digits.unicode_at(digit_index) != 48:
			first_significant_index = digit_index
			break
	if first_significant_index < 0:
		return "" if parser_would_warn else token
	if not parser_would_warn and first_significant_index < 18:
		return token

	var significant_count: int = mini(
		18,
		combined_digits.length() - first_significant_index
	)
	var significant_digits: String = combined_digits.substr(
		first_significant_index,
		significant_count
	)
	var scientific_exponent: int = (
		exponent
		+ integer_digits.length()
		- first_significant_index
		- 1
	)
	var normalized: String = "-" if is_negative else ""
	normalized += significant_digits.substr(0, 1)
	if significant_digits.length() > 1:
		normalized += "." + significant_digits.substr(1)
	normalized += "e" + str(scientific_exponent)
	if _json_number_token_triggers_parser_exponent_warning(normalized):
		return ""
	return normalized


static func _json_number_token_triggers_parser_exponent_warning(token: String) -> bool:
	var unsigned_token: String = token.trim_prefix("-")
	var exponent_index: int = unsigned_token.find("e")
	if exponent_index < 0:
		exponent_index = unsigned_token.find("E")
	var mantissa: String = unsigned_token
	var exponent: int = 0
	if exponent_index >= 0:
		mantissa = unsigned_token.substr(0, exponent_index)
		exponent = _parse_bounded_decimal_exponent(
			unsigned_token.substr(exponent_index + 1)
		)
	var decimal_index: int = mantissa.find(".")
	var integer_digits: String = mantissa
	var fraction_digits: String = ""
	if decimal_index >= 0:
		integer_digits = mantissa.substr(0, decimal_index)
		fraction_digits = mantissa.substr(decimal_index + 1)
	var combined_digits: String = integer_digits + fraction_digits
	var mantissa_size: int = combined_digits.length()
	var decimal_point: int = integer_digits.length()
	var fractional_exponent: int = (
		decimal_point - 18 if mantissa_size > 18 else decimal_point - mantissa_size
	)
	var effective_exponent: int = fractional_exponent + exponent
	return absi(effective_exponent) > 511


static func _parse_bounded_decimal_exponent(token: String) -> int:
	var saturation_limit: int = ABSOLUTE_MAX_BYTES + 1024
	var exponent_sign: int = 1
	var index: int = 0
	if token.begins_with("+"):
		index = 1
	elif token.begins_with("-"):
		exponent_sign = -1
		index = 1
	while index < token.length() and token.unicode_at(index) == 48:
		index += 1
	if index >= token.length():
		return 0
	var value: int = 0
	while index < token.length():
		var digit: int = token.unicode_at(index) - 48
		value = value * 10 + digit
		if value >= saturation_limit:
			return exponent_sign * saturation_limit
		index += 1
	return exponent_sign * value


static func _is_ascii_digit(codepoint: int) -> bool:
	return codepoint >= 48 and codepoint <= 57


static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first <= 0x7f:
			index += 1
			continue
		if first >= 0xc2 and first <= 0xdf:
			if not _has_utf8_continuations(bytes, index, 1):
				return false
			index += 2
			continue
		if first == 0xe0:
			if not _has_utf8_second_byte(bytes, index, 0xa0, 0xbf, 2):
				return false
			index += 3
			continue
		if (first >= 0xe1 and first <= 0xec) or (first >= 0xee and first <= 0xef):
			if not _has_utf8_continuations(bytes, index, 2):
				return false
			index += 3
			continue
		if first == 0xed:
			if not _has_utf8_second_byte(bytes, index, 0x80, 0x9f, 2):
				return false
			index += 3
			continue
		if first == 0xf0:
			if not _has_utf8_second_byte(bytes, index, 0x90, 0xbf, 3):
				return false
			index += 4
			continue
		if first >= 0xf1 and first <= 0xf3:
			if not _has_utf8_continuations(bytes, index, 3):
				return false
			index += 4
			continue
		if first == 0xf4:
			if not _has_utf8_second_byte(bytes, index, 0x80, 0x8f, 3):
				return false
			index += 4
			continue
		return false
	return true


static func _has_only_json_safe_numbers(value: Variant) -> bool:
	if value is float:
		var number: float = value
		return is_finite(number)
	if value is Array:
		var values: Array = value
		for child: Variant in values:
			if not _has_only_json_safe_numbers(child):
				return false
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value
		for child: Variant in dictionary.values():
			if not _has_only_json_safe_numbers(child):
				return false
	return true


static func _has_utf8_second_byte(
	bytes: PackedByteArray,
	index: int,
	minimum_second: int,
	maximum_second: int,
	continuation_count: int
) -> bool:
	if index + continuation_count >= bytes.size():
		return false
	var second: int = bytes[index + 1]
	if second < minimum_second or second > maximum_second:
		return false
	for offset: int in range(2, continuation_count + 1):
		var continuation: int = bytes[index + offset]
		if continuation < 0x80 or continuation > 0xbf:
			return false
	return true


static func _has_utf8_continuations(
	bytes: PackedByteArray,
	index: int,
	continuation_count: int
) -> bool:
	return _has_utf8_second_byte(
		bytes,
		index,
		0x80,
		0xbf,
		continuation_count
	)


static func _make_report(
	ok: bool,
	data: Dictionary,
	source_path: String,
	size_bytes: int,
	error_kind: String,
	error: String,
	max_bytes: int,
	max_depth: int
) -> Dictionary:
	return {
		"ok": ok,
		"data": data.duplicate(true),
		"source_path": source_path,
		"size_bytes": maxi(size_bytes, 0),
		"error_kind": error_kind,
		"error": error,
		"max_bytes": max_bytes,
		"max_depth": max_depth,
	}
