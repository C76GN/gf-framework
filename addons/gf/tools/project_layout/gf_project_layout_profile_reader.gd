# Layout 的严格 JSON 字节语法入口；不解释任何 Profile 规则。
extends RefCounted


# --- 常量 ---

## 复用 kernel 有限字节、深度、UTF-8 与数值安全读取。
## [br]
## @api private
const _JSON_READER_SCRIPT = preload("res://addons/gf/kernel/core/gf_bounded_json_object_reader.gd")

## 来源父链资格与规范表示共用 scope 核心。
## [br]
## @api private
const _SCOPE_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_capture_scope.gd")


# --- 私有变量 ---

## 本次有界文本，解析结束由下一请求覆盖；不保存项目对象。
## [br]
## @api private
var _text: String = ""

## 严格词法游标，每个字符仅在有界输入内访问。
## [br]
## @api private
var _cursor: int = 0

## 结构值预算，限制宽 JSON 的后续语法工作。
## [br]
## @api private
var _values: int = 0


# --- 框架内部方法 ---

## 解析严格 Profile JSON，拒绝重复键、孤立 surrogate、非 JSON 语法与超预算输入。
## [br]
## @api framework_internal
## [br]
## @param text: 已从实际 bytes 严格 UTF-8 解码的有界文本。
## [br]
## @return 闭合 success、profile 和 error；失败没有 partial profile。
## [br]
## @schema return: Dictionary，精确包含 success: bool、profile: Dictionary 和 error: String。
func parse_text(text: String) -> Dictionary:
	if text.length() > 1_048_576 or text.to_utf8_buffer().size() > 1_048_576:
		return _failure("Profile JSON 超过 1 MiB 字节预算。")
	_text = text
	_cursor = 0
	_values = 0
	var valid: bool = _parse_value(0)
	_skip_space()
	valid = valid and _cursor == _text.length()
	_text = ""
	if not valid:
		return _failure("Profile JSON 必须为严格有界 JSON；不接受重复键、孤立 surrogate 或宽松语法。")
	var parsed: Dictionary = _JSON_READER_SCRIPT.parse_object(text)
	if not parsed["ok"]:
		var error: String = parsed["error"]
		return _failure(error)
	return {"success": true, "profile": parsed["data"], "error": ""}


## 有界读取实际文件，再由相同严格文本入口准入；读取期间长度与原始 bytes 必须稳定。
## [br]
## @api framework_internal
## [br]
## @param path: 实际 Profile 文件路径。
## [br]
## @return 闭合 success、profile、error 和 text；失败没有来源内容。
## [br]
## @schema return: Dictionary，精确包含 success: bool、profile: Dictionary、error: String 和 text: String。
func read_path(path: String) -> Dictionary:
	if path.length() > 16_384 or not _SCOPE_SCRIPT.root_is_canonical(path) or _SCOPE_SCRIPT.path_crosses_link(path):
		return {"success": false, "profile": {}, "error": "Profile 文件路径不规范或穿过链接。", "text": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "profile": {}, "error": "Profile 文件无法只读打开。", "text": ""}
	var size: int = file.get_length()
	if size > 1_048_576:
		return {"success": false, "profile": {}, "error": "Profile 文件超过 1 MiB 字节预算。", "text": ""}
	var bytes: PackedByteArray = file.get_buffer(size + 1)
	if bytes.size() != size or file.get_length() != size or _SCOPE_SCRIPT.path_crosses_link(path):
		return {"success": false, "profile": {}, "error": "Profile 文件读取期间发生变化。", "text": ""}
	if not _utf8_is_valid(bytes):
		return {"success": false, "profile": {}, "error": "Profile 文件不是严格 UTF-8。", "text": ""}
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"success": false, "profile": {}, "error": "Profile 文件不是严格 UTF-8。", "text": ""}
	var parsed: Dictionary = parse_text(text)
	parsed["text"] = text if parsed["success"] else ""
	return parsed


# --- 私有/辅助方法 ---

## 解码前验证 UTF-8，防止 native decoder 对非法输入发出非结构化诊断。
## [br]
## @api private
func _utf8_is_valid(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var first: int = bytes[index]
		if first < 0x80:
			index += 1
			continue
		var count: int = 2 if first >= 0xC2 and first <= 0xDF else 3 if first >= 0xE0 and first <= 0xEF else 4 if first >= 0xF0 and first <= 0xF4 else 0
		if count == 0 or index + count > bytes.size():
			return false
		var second: int = bytes[index + 1]
		if (first == 0xE0 and second < 0xA0) or (first == 0xED and second > 0x9F) or (first == 0xF0 and second < 0x90) or (first == 0xF4 and second > 0x8F):
			return false
		for offset: int in range(1, count):
			if bytes[index + offset] < 0x80 or bytes[index + offset] > 0xBF:
				return false
		index += count
	return true

## JSON grammar value；数值有限性由 kernel reader 最终复核。
## [br]
## @api private
func _parse_value(depth: int) -> bool:
	_values += 1
	_skip_space()
	if depth > 64 or _values > 65_536 or _cursor >= _text.length():
		return false
	var first: String = _text[_cursor]
	if first == "{":
		_cursor += 1
		_skip_space()
		var keys: Dictionary = {}
		if _take("}"):
			return true
		while _cursor < _text.length():
			var key_start: int = _cursor
			if not _parse_string():
				return false
			var key_value: Variant = JSON.parse_string(_text.substr(key_start, _cursor - key_start))
			if not key_value is String:
				return false
			var key: String = key_value
			if keys.has(key):
				return false
			keys[key] = true
			_skip_space()
			if not _take(":") or not _parse_value(depth + 1):
				return false
			_skip_space()
			if _take("}"):
				return true
			if not _take(","):
				return false
			_skip_space()
		return false
	if first == "[":
		_cursor += 1
		_skip_space()
		if _take("]"):
			return true
		while _cursor < _text.length():
			if not _parse_value(depth + 1):
				return false
			_skip_space()
			if _take("]"):
				return true
			if not _take(","):
				return false
		return false
	if first == "\"":
		return _parse_string()
	for literal: String in ["true", "false", "null"]:
		if _text.substr(_cursor, literal.length()) == literal:
			_cursor += literal.length()
			return true
	return _parse_number()


## 检查 JSON 字符串转义，UTF-16 high surrogate 必须紧随有效 low surrogate。
## [br]
## @api private
func _parse_string() -> bool:
	if not _take("\""):
		return false
	while _cursor < _text.length():
		var codepoint: int = _text.unicode_at(_cursor)
		_cursor += 1
		if codepoint == 34:
			return true
		if codepoint < 32 or codepoint >= 0xD800 and codepoint <= 0xDFFF:
			return false
		if codepoint != 92:
			continue
		if _cursor >= _text.length():
			return false
		var escape: String = _text[_cursor]
		_cursor += 1
		if escape in "\"\\/bfnrt":
			continue
		if escape != "u":
			return false
		var unicode_value: int = _parse_hex_quad()
		if unicode_value < 0:
			return false
		if unicode_value >= 0xD800 and unicode_value <= 0xDBFF:
			if not _take("\\") or not _take("u"):
				return false
			var low: int = _parse_hex_quad()
			if low < 0xDC00 or low > 0xDFFF:
				return false
		elif unicode_value >= 0xDC00 and unicode_value <= 0xDFFF:
			return false
	return false


## 有界读取四个 hex 字符，错误不交给 Godot JSON 发出原生诊断。
## [br]
## @api private
func _parse_hex_quad() -> int:
	if _cursor + 4 > _text.length():
		return -1
	var value: int = 0
	for offset: int in range(4):
		var digit: String = _text[_cursor + offset].to_lower()
		var index: int = "0123456789abcdef".find(digit)
		if index < 0:
			return -1
		value = value * 16 + index
	_cursor += 4
	return value


## JSON number grammar 拒绝前导零、缺失小数或指数数字和非标准常量。
## [br]
## @api private
func _parse_number() -> bool:
	var _minus: bool = _take("-")
	if not _take("0"):
		if _cursor >= _text.length() or not _text[_cursor] in "123456789":
			return false
		_skip_digits()
	if _take("."):
		var fraction_start: int = _cursor
		_skip_digits()
		if fraction_start == _cursor:
			return false
	if _take("e") or _take("E"):
		var _plus: bool = _take("+") or _take("-")
		var exponent_start: int = _cursor
		_skip_digits()
		if exponent_start == _cursor:
			return false
	return true


## 数字扫描在输入字节预算内单调推进。
## [br]
## @api private
func _skip_digits() -> void:
	while _cursor < _text.length() and _text[_cursor] in "0123456789":
		_cursor += 1


## 只接受 JSON 的四个空白字符。
## [br]
## @api private
func _skip_space() -> void:
	while _cursor < _text.length() and _text[_cursor] in " \t\r\n":
		_cursor += 1


## 只有精确匹配才消费一个字符。
## [br]
## @api private
func _take(character: String) -> bool:
	if _cursor < _text.length() and _text[_cursor] == character:
		_cursor += 1
		return true
	return false


## 严格字节准入拒绝不得保留可继续编译的候选 profile。
## [br]
## @api private
func _failure(error: String) -> Dictionary:
	return {"success": false, "profile": {}, "error": error}
