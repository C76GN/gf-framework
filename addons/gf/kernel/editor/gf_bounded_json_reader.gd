@tool

# 有界 JSON 对象读取器。
#
# 在 JSON.parse() 前先限制 UTF-8 字节量和词法嵌套深度，避免编辑器清单把
# 未受控输入直接交给解析器。该脚本没有 class_name，只供 kernel/editor 内部预加载。
extends RefCounted


# --- 框架内部方法 ---

## 读取并解析有界 JSON 对象文件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param path: 要读取的 res:// 或 user:// JSON 文件路径。
## [br]
## @param max_bytes: 读取前允许的最大文件字节数。
## [br]
## @param max_depth: 解析前允许的最大对象/数组嵌套深度。
## [br]
## @return: 包含 ok、data、error_kind、error 的结果。
## [br]
## @schema return: Dictionary，包含 ok、data、error_kind 和 error。
static func read_object(path: String, max_bytes: int, max_depth: int) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_error(
			&"open_failed",
			"JSON 文件无法打开：%s (%s)" % [
				path,
				error_string(FileAccess.get_open_error()),
			]
		)
	if file.get_length() > max_bytes:
		file.close()
		return _make_error(
			&"payload_too_large",
			"JSON 文件超过 %d 字节上限：%s" % [max_bytes, path]
		)
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return _make_error(
			&"read_failed",
			"JSON 文件读取失败：%s (%s)" % [path, error_string(read_error)]
		)
	return parse_object(text, max_bytes, max_depth)


## 解析有界 JSON 对象文本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param text: 要解析的 JSON 文本。
## [br]
## @param max_bytes: 允许的最大 UTF-8 字节数。
## [br]
## @param max_depth: 允许的最大对象/数组嵌套深度。
## [br]
## @return: 包含 ok、data、error_kind、error 的结果。
## [br]
## @schema return: Dictionary，包含 ok、data、error_kind 和 error。
static func parse_object(text: String, max_bytes: int, max_depth: int) -> Dictionary:
	if text.to_utf8_buffer().size() > max_bytes:
		return _make_error(
			&"payload_too_large",
			"JSON 文本超过 %d 字节上限。" % max_bytes
		)
	if _exceeds_json_depth(text, max_depth):
		return _make_error(
			&"nesting_too_deep",
			"JSON 嵌套深度超过 %d 层上限。" % max_depth
		)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		return _make_error(
			&"parse_failed",
			"JSON 解析失败（第 %d 行）：%s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			]
		)
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _make_error(&"invalid_root_type", "JSON 根节点必须是对象。")
	var data: Dictionary = parsed
	return {
		"ok": true,
		"data": data,
		"error_kind": &"",
		"error": "",
	}


# --- 私有/辅助方法 ---

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


static func _make_error(error_kind: StringName, message: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error_kind": error_kind,
		"error": message,
	}
