## GFSourceTextPatchTools: 源码文本范围补丁工具。
##
## 用于把编辑器工具、生成器或迁移脚本产生的 line/character 范围 edit 应用到
## 单个文本字符串。范围形状可与 LSP text edit 相同，但 character 使用 Godot String
## 字符索引，不是 LSP UTF-16 code unit 坐标。该类只处理纯文本和结构化报告，
## 不写文件、不调用 LSP、不扫描项目，也不解释重命名、符号或业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSourceTextPatchTools
extends RefCounted


# --- 常量 ---

## edit 记录结构无效。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_INVALID_EDIT: StringName = &"invalid_edit"

## edit 范围越过文本行或列边界。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_RANGE_OUT_OF_BOUNDS: StringName = &"range_out_of_bounds"

## edit 起点在终点之后。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_INVALID_RANGE: StringName = &"invalid_range"

## edit 范围互相重叠或同一位置存在顺序不明确的插入。
## [br]
## @api public
## [br]
## @since 8.0.0
const ERROR_OVERLAPPING_EDITS: StringName = &"overlapping_edits"


# --- 公共方法 ---

## 构建零基 line/character 范围字典。
## [br]
## character 按 Godot String 字符索引计算，不是 UTF-8 字节偏移，也不是 LSP UTF-16 code unit。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param start_line: 起始行，零基。
## [br]
## @param start_character: 起始列，零基。
## [br]
## @param end_line: 结束行，零基。
## [br]
## @param end_character: 结束列，零基。
## [br]
## @return 范围字典。
## [br]
## @schema return: Dictionary，包含 start/end 位置字典。
static func make_range(
	start_line: int,
	start_character: int,
	end_line: int,
	end_character: int
) -> Dictionary:
	return {
		"start": {
			"line": start_line,
			"character": start_character,
		},
		"end": {
			"line": end_line,
			"character": end_character,
		},
	}


## 构建替换 edit 字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param start_line: 起始行，零基。
## [br]
## @param start_character: 起始列，零基。
## [br]
## @param end_line: 结束行，零基。
## [br]
## @param end_character: 结束列，零基。
## [br]
## @param text: 替换文本；空字符串表示删除。
## [br]
## @param metadata: 调用方元数据。
## [br]
## @return edit 字典。
## [br]
## @schema metadata: Dictionary copied into the edit metadata field.
## [br]
## @schema return: Dictionary，包含 range、text 和 metadata。
static func make_replacement_edit(
	start_line: int,
	start_character: int,
	end_line: int,
	end_character: int,
	text: String,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"range": make_range(start_line, start_character, end_line, end_character),
		"text": text,
		"metadata": metadata.duplicate(true),
	}


## 校验文本 edit 集合。
## [br]
## 支持 `range.start.line/character` + `range.end.line/character` 与扁平
## `start_line/start_character/end_line/end_character` 两种范围写法。该范围是 LSP-shaped，
## 但 character 使用 Godot String 字符索引。替换文本可使用 `text`、`newText`、
## `new_text` 或 `replacement` 字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_text: 原始文本。
## [br]
## @param edits: edit 字典数组。
## [br]
## @param options: 校验选项，支持 include_edits 和 metadata。
## [br]
## @return 校验报告。
## [br]
## @schema edits: Array of Dictionary text edits.
## [br]
## @schema options: Dictionary，可包含 include_edits 和 metadata。
## [br]
## @schema return: Dictionary，包含 ok、error、edit_count、valid_edit_count、line_count、issues、issue_count、source_sha256、metadata 和可选 edits。
static func validate_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_text_edits(source_text, edits, options)
	var issues: Array[Dictionary] = _get_issue_array(normalized)
	var result: Dictionary = {
		"ok": issues.is_empty(),
		"error": _first_issue_kind(issues),
		"edit_count": edits.size(),
		"valid_edit_count": _get_edit_array(normalized).size(),
		"line_count": GFVariantData.get_option_int(normalized, "line_count"),
		"issues": issues,
		"issue_count": issues.size(),
		"source_sha256": source_text.sha256_text(),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
	}
	if GFVariantData.get_option_bool(options, "include_edits", true):
		result["edits"] = _get_edit_array(normalized)
	return result


## 应用文本 edit 集合。
## [br]
## edit 会先按原始文本范围校验并按 offset 倒序应用，因此调用方不需要预先排序。
## 范围字段可使用 LSP-shaped 字典，但 character 始终是 Godot String 字符索引。
## 如果存在越界、重叠或结构错误，返回 ok=false，text 保持为原始文本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source_text: 原始文本。
## [br]
## @param edits: edit 字典数组。
## [br]
## @param options: 应用选项，支持 include_edits 和 metadata。
## [br]
## @return 应用报告。
## [br]
## @schema edits: Array of Dictionary text edits.
## [br]
## @schema options: Dictionary，可包含 include_edits 和 metadata。
## [br]
## @schema return: Dictionary，包含 ok、error、text、changed、edit_count、applied_count、line_count、issues、issue_count、source_sha256、result_sha256、metadata 和可选 edits。
static func apply_text_edits(source_text: String, edits: Array, options: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = _normalize_text_edits(source_text, edits, options)
	var issues: Array[Dictionary] = _get_issue_array(normalized)
	var normalized_edits: Array[Dictionary] = _get_edit_array(normalized)
	if not issues.is_empty():
		return _make_apply_report(source_text, source_text, edits.size(), 0, normalized_edits, normalized, options)

	var sorted_edits: Array[Dictionary] = normalized_edits.duplicate(true)
	sorted_edits.sort_custom(Callable(GFSourceTextPatchTools, "_compare_edits_descending"))
	var result_text: String = source_text
	for edit: Dictionary in sorted_edits:
		var start_offset: int = GFVariantData.get_option_int(edit, "start_offset")
		var end_offset: int = GFVariantData.get_option_int(edit, "end_offset")
		var replacement_text: String = GFVariantData.get_option_string(edit, "text")
		result_text = (
			result_text.substr(0, start_offset)
			+ replacement_text
			+ result_text.substr(end_offset)
		)

	return _make_apply_report(
		source_text,
		result_text,
		edits.size(),
		normalized_edits.size(),
		normalized_edits,
		normalized,
		options
	)


# --- 私有/辅助方法 ---

static func _normalize_text_edits(source_text: String, edits: Array, _options: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	var normalized_edits: Array[Dictionary] = []
	var line_map: Array[Dictionary] = _build_line_map(source_text)

	for index: int in range(edits.size()):
		var raw_edit: Variant = edits[index]
		if not raw_edit is Dictionary:
			issues.append(_make_issue(
				ERROR_INVALID_EDIT,
				index,
				"Edit must be a Dictionary.",
				{ "field": "edit" }
			))
			continue

		var edit: Dictionary = raw_edit
		if not _edit_has_range(edit):
			issues.append(_make_issue(
				ERROR_INVALID_EDIT,
				index,
				"Edit is missing a range.",
				{ "field": "range" }
			))
			continue
		if not _edit_has_text(edit):
			issues.append(_make_issue(
				ERROR_INVALID_EDIT,
				index,
				"Edit is missing replacement text.",
				{ "field": "text" }
			))
			continue

		var start_position: Dictionary = _read_position(edit, true)
		var end_position: Dictionary = _read_position(edit, false)
		var start_offset_report: Dictionary = _position_to_offset(line_map, start_position)
		var end_offset_report: Dictionary = _position_to_offset(line_map, end_position)
		if not GFVariantData.get_option_bool(start_offset_report, "ok"):
			issues.append(_make_range_issue(index, "start", start_position, start_offset_report))
			continue
		if not GFVariantData.get_option_bool(end_offset_report, "ok"):
			issues.append(_make_range_issue(index, "end", end_position, end_offset_report))
			continue

		var start_offset: int = GFVariantData.get_option_int(start_offset_report, "offset")
		var end_offset: int = GFVariantData.get_option_int(end_offset_report, "offset")
		if start_offset > end_offset:
			issues.append(_make_issue(
				ERROR_INVALID_RANGE,
				index,
				"Edit start must not be after end.",
				{
					"start_offset": start_offset,
					"end_offset": end_offset,
				}
			))
			continue

		normalized_edits.append({
			"index": index,
			"start_line": GFVariantData.get_option_int(start_position, "line"),
			"start_character": GFVariantData.get_option_int(start_position, "character"),
			"end_line": GFVariantData.get_option_int(end_position, "line"),
			"end_character": GFVariantData.get_option_int(end_position, "character"),
			"start_offset": start_offset,
			"end_offset": end_offset,
			"text": _read_edit_text(edit),
			"metadata": GFVariantData.get_option_dictionary(edit, "metadata").duplicate(true),
		})

	_append_overlap_issues(normalized_edits, issues)

	return {
		"edits": normalized_edits,
		"issues": issues,
		"line_count": line_map.size(),
	}


static func _build_line_map(source_text: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var line_start: int = 0
	var index: int = 0
	while index < source_text.length():
		var character: String = source_text.substr(index, 1)
		if character == "\r":
			lines.append({ "start": line_start, "end": index })
			if index + 1 < source_text.length() and source_text.substr(index + 1, 1) == "\n":
				index += 2
			else:
				index += 1
			line_start = index
			continue
		if character == "\n":
			lines.append({ "start": line_start, "end": index })
			index += 1
			line_start = index
			continue
		index += 1
	lines.append({ "start": line_start, "end": source_text.length() })
	return lines


static func _position_to_offset(line_map: Array[Dictionary], position: Dictionary) -> Dictionary:
	var line: int = GFVariantData.get_option_int(position, "line", -1)
	var character: int = GFVariantData.get_option_int(position, "character", -1)
	if line < 0 or line >= line_map.size():
		return {
			"ok": false,
			"reason": ERROR_RANGE_OUT_OF_BOUNDS,
			"line_count": line_map.size(),
			"line": line,
			"character": character,
		}

	var line_record: Dictionary = line_map[line]
	var line_start: int = GFVariantData.get_option_int(line_record, "start")
	var line_end: int = GFVariantData.get_option_int(line_record, "end")
	var line_length: int = line_end - line_start
	if character < 0 or character > line_length:
		return {
			"ok": false,
			"reason": ERROR_RANGE_OUT_OF_BOUNDS,
			"line": line,
			"character": character,
			"line_length": line_length,
		}

	return {
		"ok": true,
		"offset": line_start + character,
		"line": line,
		"character": character,
		"line_length": line_length,
	}


static func _edit_has_range(edit: Dictionary) -> bool:
	if edit.has("range") or edit.has(&"range"):
		return true
	if edit.has("start") or edit.has(&"start") or edit.has("end") or edit.has(&"end"):
		return true
	return (
		_has_any_key(edit, PackedStringArray(["start_line", "start_row"]))
		and _has_any_key(edit, PackedStringArray(["end_line", "end_row"]))
	)


static func _edit_has_text(edit: Dictionary) -> bool:
	return (
		edit.has("text")
		or edit.has(&"text")
		or edit.has("newText")
		or edit.has(&"newText")
		or edit.has("new_text")
		or edit.has(&"new_text")
		or edit.has("replacement")
		or edit.has(&"replacement")
	)


static func _read_edit_text(edit: Dictionary) -> String:
	if edit.has("text") or edit.has(&"text"):
		return GFVariantData.get_option_string(edit, "text")
	if edit.has("newText") or edit.has(&"newText"):
		return GFVariantData.get_option_string(edit, "newText")
	if edit.has("new_text") or edit.has(&"new_text"):
		return GFVariantData.get_option_string(edit, "new_text")
	return GFVariantData.get_option_string(edit, "replacement")


static func _read_position(edit: Dictionary, is_start: bool) -> Dictionary:
	var key: String = "start" if is_start else "end"
	var edit_range: Dictionary = GFVariantData.get_option_dictionary(edit, "range")
	if not edit_range.is_empty():
		return _normalize_position(GFVariantData.get_option_value(edit_range, key, {}))
	if edit.has(key) or edit.has(StringName(key)):
		return _normalize_position(GFVariantData.get_option_value(edit, key, {}))

	var line_key: String = "%s_line" % key
	var character_key: String = "%s_character" % key
	return {
		"line": _read_first_int(edit, PackedStringArray([line_key, "%s_row" % key]), -1),
		"character": _read_first_int(
			edit,
			PackedStringArray([character_key, "%s_column" % key, "%s_col" % key]),
			-1
		),
	}


static func _normalize_position(value: Variant) -> Dictionary:
	if value is Vector2i:
		var vector: Vector2i = value
		return {
			"line": vector.x,
			"character": vector.y,
		}
	if value is Dictionary:
		var data: Dictionary = value
		return {
			"line": _read_first_int(data, PackedStringArray(["line", "row"]), -1),
			"character": _read_first_int(data, PackedStringArray(["character", "column", "col"]), -1),
		}
	return {
		"line": -1,
		"character": -1,
	}


static func _append_overlap_issues(edits: Array[Dictionary], issues: Array[Dictionary]) -> void:
	var sorted_edits: Array[Dictionary] = edits.duplicate(true)
	sorted_edits.sort_custom(Callable(GFSourceTextPatchTools, "_compare_edits_ascending"))
	var previous: Dictionary = {}
	for edit: Dictionary in sorted_edits:
		if previous.is_empty():
			previous = edit
			continue

		var start_offset: int = GFVariantData.get_option_int(edit, "start_offset")
		var end_offset: int = GFVariantData.get_option_int(edit, "end_offset")
		var previous_start: int = GFVariantData.get_option_int(previous, "start_offset")
		var previous_end: int = GFVariantData.get_option_int(previous, "end_offset")
		var is_same_start: bool = start_offset == previous_start
		var overlaps_previous: bool = start_offset < previous_end or is_same_start
		if overlaps_previous:
			issues.append(_make_issue(
				ERROR_OVERLAPPING_EDITS,
				GFVariantData.get_option_int(edit, "index"),
				"Edit overlaps another edit.",
				{
					"start_offset": start_offset,
					"end_offset": end_offset,
					"previous_index": GFVariantData.get_option_int(previous, "index"),
					"previous_start_offset": previous_start,
					"previous_end_offset": previous_end,
				}
			))
		if end_offset > previous_end:
			previous = edit


static func _make_apply_report(
	source_text: String,
	result_text: String,
	edit_count: int,
	applied_count: int,
	edits: Array[Dictionary],
	normalized: Dictionary,
	options: Dictionary
) -> Dictionary:
	var issues: Array[Dictionary] = _get_issue_array(normalized)
	var result: Dictionary = {
		"ok": issues.is_empty(),
		"error": _first_issue_kind(issues),
		"text": result_text,
		"changed": source_text != result_text,
		"edit_count": edit_count,
		"applied_count": applied_count,
		"line_count": GFVariantData.get_option_int(normalized, "line_count"),
		"issues": issues,
		"issue_count": issues.size(),
		"source_sha256": source_text.sha256_text(),
		"result_sha256": result_text.sha256_text(),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
	}
	if GFVariantData.get_option_bool(options, "include_edits", true):
		result["edits"] = edits.duplicate(true)
	return result


static func _make_range_issue(
	index: int,
	field: String,
	position: Dictionary,
	offset_report: Dictionary
) -> Dictionary:
	return _make_issue(
		GFVariantData.get_option_string_name(offset_report, "reason", ERROR_RANGE_OUT_OF_BOUNDS),
		index,
		"Edit range position is outside source text.",
		{
			"field": field,
			"line": GFVariantData.get_option_int(position, "line", -1),
			"character": GFVariantData.get_option_int(position, "character", -1),
			"line_count": GFVariantData.get_option_int(offset_report, "line_count", -1),
			"line_length": GFVariantData.get_option_int(offset_report, "line_length", -1),
		}
	)


static func _make_issue(kind: StringName, index: int, message: String, fields: Dictionary = {}) -> Dictionary:
	var issue: Dictionary = {
		"kind": kind,
		"index": index,
		"message": message,
	}
	for key: Variant in fields.keys():
		issue[key] = GFVariantData.duplicate_variant(fields[key], true)
	return issue


static func _get_issue_array(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_issues: Array = GFVariantData.get_option_array(report, "issues")
	for value: Variant in raw_issues:
		if value is Dictionary:
			var issue: Dictionary = value
			result.append(issue.duplicate(true))
	return result


static func _get_edit_array(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_edits: Array = GFVariantData.get_option_array(report, "edits")
	for value: Variant in raw_edits:
		if value is Dictionary:
			var edit: Dictionary = value
			result.append(edit.duplicate(true))
	return result


static func _first_issue_kind(issues: Array[Dictionary]) -> StringName:
	if issues.is_empty():
		return &""
	return GFVariantData.get_option_string_name(issues[0], "kind")


static func _has_any_key(data: Dictionary, keys: PackedStringArray) -> bool:
	for key: String in keys:
		if data.has(key) or data.has(StringName(key)):
			return true
	return false


static func _read_first_int(data: Dictionary, keys: PackedStringArray, default_value: int = 0) -> int:
	for key: String in keys:
		if data.has(key) or data.has(StringName(key)):
			return GFVariantData.get_option_int(data, key, default_value)
	return default_value


static func _compare_edits_ascending(left: Dictionary, right: Dictionary) -> bool:
	var left_start: int = GFVariantData.get_option_int(left, "start_offset")
	var right_start: int = GFVariantData.get_option_int(right, "start_offset")
	if left_start == right_start:
		return GFVariantData.get_option_int(left, "index") < GFVariantData.get_option_int(right, "index")
	return left_start < right_start


static func _compare_edits_descending(left: Dictionary, right: Dictionary) -> bool:
	var left_start: int = GFVariantData.get_option_int(left, "start_offset")
	var right_start: int = GFVariantData.get_option_int(right, "start_offset")
	if left_start == right_start:
		return GFVariantData.get_option_int(left, "index") > GFVariantData.get_option_int(right, "index")
	return left_start > right_start
