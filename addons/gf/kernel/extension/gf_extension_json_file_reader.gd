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
const _HARD_MAX_FILE_BYTES: int = 1024 * 1024
const _HARD_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024
const _HARD_MAX_DEPTH: int = 64
const _HASH_CHUNK_BYTES: int = 64 * 1024


# --- 框架内部方法 ---

## 读取 JSON object 文件并返回稳定报告。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param path: JSON 文件路径。
## [br]
## @param options: 错误文案与 JSON 预算选项；预算只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 empty_path_error、open_error_prefix、read_error_prefix、parse_error_prefix、root_type_error、max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @param budget_state: 同一次发现操作共享的累计读取预算；为空时创建局部预算。
## [br]
## @schema budget_state: Dictionary，由 make_budget_state() 创建并在读取时原地更新。
## [br]
## @return JSON object 读取报告。
## [br]
## @schema return: Dictionary，包含 ok、source_path、data、errors、size_bytes 和 budget_exceeded。
static func read_object_report(
	path: String,
	options: Dictionary = {},
	budget_state: Dictionary = {}
) -> Dictionary:
	_ensure_budget_state(budget_state, options)
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
	var errors: Array[String] = []
	if normalized_path.is_empty():
		errors.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			options,
			"empty_path_error",
			"JSON path is empty"
		))
		return _make_report(false, normalized_path, {}, errors, 0, budget_state)

	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		errors.append("%s: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "open_error_prefix", "could not open JSON"),
			error_string(FileAccess.get_open_error()),
		])
		return _make_report(false, normalized_path, {}, errors, 0, budget_state)

	var size_bytes: int = file.get_length()
	var budget_error: String = _reserve_file_bytes(normalized_path, size_bytes, budget_state)
	if not budget_error.is_empty():
		file.close()
		errors.append(budget_error)
		return _make_report(false, normalized_path, {}, errors, size_bytes, budget_state)
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		errors.append("%s: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "read_error_prefix", "could not read JSON"),
			error_string(read_error),
		])
		return _make_report(false, normalized_path, {}, errors, size_bytes, budget_state)
	if _exceeds_json_depth(
		text,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(budget_state, "max_json_depth", _HARD_MAX_DEPTH)
	):
		errors.append(
			"JSON nesting exceeds max_json_depth=%d: %s"
			% [
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					budget_state,
					"max_json_depth",
					_HARD_MAX_DEPTH
				),
				normalized_path,
			]
		)
		return _make_report(false, normalized_path, {}, errors, size_bytes, budget_state)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		errors.append("%s at line %d: %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "parse_error_prefix", "could not parse JSON"),
			parser.get_error_line(),
			parser.get_error_message(),
		])
		return _make_report(false, normalized_path, {}, errors, size_bytes, budget_state)

	var parsed: Variant = parser.data
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return _make_report(true, normalized_path, data, errors, size_bytes, budget_state)

	errors.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		options,
		"root_type_error",
		"JSON root must be an object"
	))
	return _make_report(false, normalized_path, {}, errors, size_bytes, budget_state)


## 创建一次 JSON 发现操作的共享累计预算。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param options: 可选预算，只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @return: 可传给读取和签名方法的可变预算状态。
## [br]
## @schema return: Dictionary，包含 max_json_file_bytes、max_json_total_bytes、max_json_depth、consumed_bytes 和 budget_exceeded。
static func make_budget_state(options: Dictionary = {}) -> Dictionary:
	var limits: Dictionary = get_limit_policy(options)
	return {
		"max_json_file_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			limits,
			"max_json_file_bytes",
			_HARD_MAX_FILE_BYTES
		),
		"max_json_total_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			limits,
			"max_json_total_bytes",
			_HARD_MAX_TOTAL_BYTES
		),
		"max_json_depth": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			limits,
			"max_json_depth",
			_HARD_MAX_DEPTH
		),
		"consumed_bytes": 0,
		"budget_exceeded": false,
	}


## 获取规范化后的 JSON 硬限制策略。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param options: 可选预算，只能收紧框架硬上限。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @return: 规范化限制。
## [br]
## @schema return: Dictionary，包含 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
static func get_limit_policy(options: Dictionary = {}) -> Dictionary:
	return {
		"max_json_file_bytes": _get_bounded_limit(
			options,
			"max_json_file_bytes",
			_HARD_MAX_FILE_BYTES
		),
		"max_json_total_bytes": _get_bounded_limit(
			options,
			"max_json_total_bytes",
			_HARD_MAX_TOTAL_BYTES
		),
		"max_json_depth": _get_bounded_limit(
			options,
			"max_json_depth",
			_HARD_MAX_DEPTH
		),
	}


## 以流式 SHA-256 生成受同一预算约束的文件身份。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param path: JSON 文件路径。
## [br]
## @param options: JSON 预算选项。
## [br]
## @schema options: Dictionary，支持 max_json_file_bytes、max_json_total_bytes 和 max_json_depth。
## [br]
## @param budget_state: 同一次发现操作共享的累计读取预算。
## [br]
## @schema budget_state: Dictionary，由 make_budget_state() 创建并在读取时原地更新。
## [br]
## @return: 有界文件签名。
## [br]
## @schema return: Dictionary，包含 ok、source_path、exists、size_bytes、content_sha256、errors 和 budget_exceeded。
static func make_file_signature(
	path: String,
	options: Dictionary = {},
	budget_state: Dictionary = {}
) -> Dictionary:
	_ensure_budget_state(budget_state, options)
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
	var result: Dictionary = {
		"ok": true,
		"source_path": normalized_path,
		"exists": false,
		"size_bytes": 0,
		"content_sha256": "",
		"errors": [],
		"budget_exceeded": false,
	}
	if normalized_path.is_empty() or not FileAccess.file_exists(normalized_path):
		return result

	result["exists"] = true
	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		result["ok"] = false
		result["errors"] = [
			"could not open JSON signature: %s" % error_string(FileAccess.get_open_error()),
		]
		return result

	var size_bytes: int = file.get_length()
	result["size_bytes"] = size_bytes
	var budget_error: String = _reserve_file_bytes(normalized_path, size_bytes, budget_state)
	if not budget_error.is_empty():
		file.close()
		result["ok"] = false
		result["errors"] = [budget_error]
		result["budget_exceeded"] = true
		return result

	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		file.close()
		result["ok"] = false
		result["errors"] = ["could not initialize JSON signature hash: %s" % error_string(start_error)]
		return result
	while file.get_position() < size_bytes:
		var chunk_size: int = mini(_HASH_CHUNK_BYTES, size_bytes - file.get_position())
		var chunk: PackedByteArray = file.get_buffer(chunk_size)
		if file.get_error() != OK or chunk.size() != chunk_size:
			var read_error: Error = file.get_error()
			file.close()
			result["ok"] = false
			result["errors"] = [
				"could not read JSON signature: %s"
				% error_string(read_error if read_error != OK else ERR_FILE_CORRUPT),
			]
			return result
		var update_error: Error = context.update(chunk)
		if update_error != OK:
			file.close()
			result["ok"] = false
			result["errors"] = [
				"could not update JSON signature hash: %s" % error_string(update_error),
			]
			return result
	file.close()
	result["content_sha256"] = context.finish().hex_encode()
	return result


# --- 私有/辅助方法 ---

static func _ensure_budget_state(budget_state: Dictionary, options: Dictionary) -> void:
	var option_limits: Dictionary = get_limit_policy(options)
	var state_limits: Dictionary = get_limit_policy(budget_state)
	budget_state["max_json_file_bytes"] = mini(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			option_limits,
			"max_json_file_bytes",
			_HARD_MAX_FILE_BYTES
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			state_limits,
			"max_json_file_bytes",
			_HARD_MAX_FILE_BYTES
		)
	)
	budget_state["max_json_total_bytes"] = mini(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			option_limits,
			"max_json_total_bytes",
			_HARD_MAX_TOTAL_BYTES
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			state_limits,
			"max_json_total_bytes",
			_HARD_MAX_TOTAL_BYTES
		)
	)
	budget_state["max_json_depth"] = mini(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			option_limits,
			"max_json_depth",
			_HARD_MAX_DEPTH
		),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			state_limits,
			"max_json_depth",
			_HARD_MAX_DEPTH
		)
	)
	var consumed_bytes: int = maxi(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(budget_state, "consumed_bytes"),
		0
	)
	budget_state["consumed_bytes"] = consumed_bytes
	budget_state["budget_exceeded"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(budget_state, "budget_exceeded")
		or consumed_bytes > _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			budget_state,
			"max_json_total_bytes",
			_HARD_MAX_TOTAL_BYTES
		)
	)


static func _get_bounded_limit(options: Dictionary, key: String, hard_limit: int) -> int:
	var requested_limit: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		key,
		hard_limit
	)
	if requested_limit <= 0:
		return hard_limit
	return mini(requested_limit, hard_limit)


static func _reserve_file_bytes(path: String, size_bytes: int, budget_state: Dictionary) -> String:
	var max_file_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		budget_state,
		"max_json_file_bytes",
		_HARD_MAX_FILE_BYTES
	)
	if size_bytes > max_file_bytes:
		budget_state["budget_exceeded"] = true
		return "JSON file exceeds max_json_file_bytes=%d: %s (%d bytes)" % [
			max_file_bytes,
			path,
			size_bytes,
		]
	var consumed_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		budget_state,
		"consumed_bytes"
	)
	var max_total_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		budget_state,
		"max_json_total_bytes",
		_HARD_MAX_TOTAL_BYTES
	)
	if size_bytes > max_total_bytes - consumed_bytes:
		budget_state["budget_exceeded"] = true
		return "JSON discovery exceeds max_json_total_bytes=%d: %s (%d + %d bytes)" % [
			max_total_bytes,
			path,
			consumed_bytes,
			size_bytes,
		]
	budget_state["consumed_bytes"] = consumed_bytes + size_bytes
	return ""


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


static func _make_report(
	ok: bool,
	source_path: String,
	data: Dictionary,
	errors: Array[String],
	size_bytes: int,
	budget_state: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"source_path": source_path,
		"data": data.duplicate(true),
		"errors": errors.duplicate(),
		"size_bytes": size_bytes,
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			budget_state,
			"budget_exceeded"
		),
	}
