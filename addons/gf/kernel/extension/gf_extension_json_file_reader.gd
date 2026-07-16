## GFExtensionJsonFileReader: GF 扩展 JSON object 文件读取报告辅助。
##
## 统一 manifest、preset 和扩展工具贡献文件的 JSON object 读取、错误报告和路径规范化逻辑。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
class_name GFExtensionJsonFileReader
extends RefCounted


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 框架内部方法 ---

## 读取 JSON object 文件并返回稳定报告。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param path: JSON 文件路径。
## [br]
## @param options: 错误文案选项。
## [br]
## @schema options: Dictionary，支持 empty_path_error、open_error_prefix、read_error_prefix、parse_error_prefix 和 root_type_error。
## [br]
## @return JSON object 读取报告。
## [br]
## @schema return: Dictionary，包含 ok、source_path、data 和 errors。
static func read_object_report(path: String, options: Dictionary = {}) -> Dictionary:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
	var errors: Array[String] = []
	if normalized_path.is_empty():
		errors.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"empty_path_error",
			"JSON path is empty"
		))
		return _make_report(false, normalized_path, {}, errors)

	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		errors.append("%s: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "open_error_prefix", "could not open JSON"),
			error_string(FileAccess.get_open_error()),
		])
		return _make_report(false, normalized_path, {}, errors)

	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		errors.append("%s: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "read_error_prefix", "could not read JSON"),
			error_string(read_error),
		])
		return _make_report(false, normalized_path, {}, errors)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		errors.append("%s at line %d: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "parse_error_prefix", "could not parse JSON"),
			parser.get_error_line(),
			parser.get_error_message(),
		])
		return _make_report(false, normalized_path, {}, errors)

	var parsed: Variant = parser.data
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return _make_report(true, normalized_path, data, errors)

	errors.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		options,
		"root_type_error",
		"JSON root must be an object"
	))
	return _make_report(false, normalized_path, {}, errors)


# --- 私有/辅助方法 ---

static func _make_report(ok: bool, source_path: String, data: Dictionary, errors: Array[String]) -> Dictionary:
	return {
		"ok": ok,
		"source_path": source_path,
		"data": data.duplicate(true),
		"errors": errors.duplicate(),
	}
