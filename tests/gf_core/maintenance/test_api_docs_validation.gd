## 验证框架 API 文档注释与函数签名保持同步。
extends GutTest


# --- 常量 ---

const SOURCE_ROOT: String = "res://addons/gf"


# --- 测试用例 ---

func test_documented_params_match_function_signatures() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_param_doc_issues(path))

	assert_eq(issues, [], "API @param 注释应与函数签名双向一致：\n%s" % _join_lines(issues))


func test_private_param_docs_allow_an_ordered_subset() -> void:
	var source: String = "## 维护约束。\n## @api private\n%s\nfunc _normalize(first: int, second: int, third: int) -> void:\n\tpass\n"
	for docs: String in ["", "## @param second: 第二项。", "## @param first: 第一项。\n## @param third: 第三项。"]:
		assert_eq(_collect_param_doc_issues_from_source(source % docs, "private_fixture.gd"), [], "私有文档不要求补齐未说明参数。")


func test_private_param_docs_reject_invalid_present_tags() -> void:
	var source: String = "## 维护约束。\n## @api private\n%s\nfunc _normalize(first: int, second: int, third: int) -> void:\n\tpass\n"
	var cases: Array[Dictionary] = [
		{ "docs": "## @param absent: 未知参数。", "issue": "unknown param" },
		{ "docs": "## @param second: 第二项。\n## @param second: 重复。", "issue": "duplicate param" },
		{ "docs": "## @param third: 第三项。\n## @param first: 第一项。", "issue": "@param order" },
		{ "docs": "## @param second:", "issue": "non-empty description" },
		{ "docs": "## @param second", "issue": "non-empty description" },
		{ "docs": "## @param", "issue": "non-empty description" },
	]
	for test_case: Dictionary in cases:
		var docs: String = str(test_case["docs"])
		var expected_issue: String = str(test_case["issue"])
		var issues: Array[String] = _collect_param_doc_issues_from_source(source % docs, "private_fixture.gd")
		assert_true(_join_lines(issues).contains(expected_issue), "已有私有参数文档必须正确：%s" % _join_lines(issues))


func test_partial_param_exemption_requires_exact_private_visibility() -> void:
	var source: String = "## 维护约束。\n%s\n## @param first: 第一项。\nfunc %s(first: int, second: int) -> void:\n\tpass\n"
	for visibility: String in ["public", "protected", "framework_internal", "layer_internal"]:
		var function_name: String = "_normalize" if visibility == "protected" else "normalize"
		var issues: Array[String] = _collect_param_doc_issues_from_source(source % ["## @api " + visibility, function_name], "contract_fixture.gd")
		assert_true(_join_lines(issues).contains("missing @param for 'second'"), "非私有契约仍要求完整参数文档。")
	for api_docs: String in ["## @api private\n## @api public", "## @api private extra", "## @api private\n## @api: public"]:
		var issues: Array[String] = _collect_param_doc_issues_from_source(source % [api_docs, "_normalize"], "contract_fixture.gd")
		assert_true(_join_lines(issues).contains("missing @param for 'second'"), "含糊的可见性不能进入私有轻量分支。")
	var public_name_issues: Array[String] = _collect_param_doc_issues_from_source(source % ["## @api private", "normalize"], "contract_fixture.gd")
	assert_true(_join_lines(public_name_issues).contains("missing @param for 'second'"), "普通公开名称不能借 private 标签降低参数校验。")


# --- 私有/辅助方法 ---

func _collect_gdscript_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	_collect_gdscript_files_recursive(root_path, result)
	result.sort()
	return result


func _collect_gdscript_files_recursive(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_35: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var child_path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gdscript_files_recursive(child_path, result)
		elif entry.ends_with(".gd"):
			result.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _collect_param_doc_issues(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["%s: cannot open file" % path]

	var source: String = file.get_as_text()
	file.close()
	return _collect_param_doc_issues_from_source(source, path)


func _collect_param_doc_issues_from_source(source: String, path: String) -> Array[String]:
	var lines: PackedStringArray = source.split("\n")
	var issues: Array[String] = []
	var doc_lines: Array[String] = []
	var line_index: int = 0
	while line_index < lines.size():
		var line: String = String(lines[line_index])
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("##"):
			doc_lines.append(trimmed)
			line_index += 1
			continue

		if _line_starts_function(trimmed):
			var signature_start_line: int = line_index + 1
			var signature: String = trimmed
			var signature_parenthesis_depth: int = _get_parenthesis_delta(trimmed)
			while signature_parenthesis_depth > 0 and line_index + 1 < lines.size():
				line_index += 1
				var signature_line: String = String(lines[line_index]).strip_edges()
				signature += " " + signature_line
				signature_parenthesis_depth += _get_parenthesis_delta(signature_line)

			var function_name: String = _parse_function_name(signature)
			var actual_params: PackedStringArray = _parse_signature_params(signature)
			var documented_params: PackedStringArray = _parse_documented_params(doc_lines)
			var allows_partial_docs: bool = function_name.begins_with("_") and _has_exact_private_visibility(doc_lines)
			if allows_partial_docs:
				issues.append_array(_collect_private_param_description_issues(doc_lines, path, signature_start_line, function_name))
			if _should_validate_param_docs(function_name, actual_params, documented_params):
				issues.append_array(_collect_function_param_doc_issues(
					path,
					signature_start_line,
					function_name,
					actual_params,
					documented_params,
					allows_partial_docs
				))

		if not trimmed.is_empty():
			doc_lines.clear()
		line_index += 1
	return issues


func _has_exact_private_visibility(doc_lines: Array[String]) -> bool:
	var api_values: Array[String] = []
	for line: String in doc_lines:
		var body: String = line.trim_prefix("##").strip_edges()
		if body == "@api" or body.begins_with("@api ") or body.begins_with("@api:") or body.begins_with("@api\t"):
			api_values.append(body.trim_prefix("@api").strip_edges())
	return api_values.size() == 1 and api_values[0] == "private"


func _collect_private_param_description_issues(
	doc_lines: Array[String],
	path: String,
	line_number: int,
	function_name: String
) -> Array[String]:
	var issues: Array[String] = []
	var regex: RegEx = RegEx.new()
	var _compile_result: Error = regex.compile("^@param\\s+[A-Za-z_]\\w*\\s*:\\s*.+$")
	for line: String in doc_lines:
		var body: String = line.trim_prefix("##").strip_edges()
		if not (body == "@param" or body.begins_with("@param ") or body.begins_with("@param:") or body.begins_with("@param\t")):
			continue
		if regex.search(body.replace("[br]", "").strip_edges()) == null:
			issues.append("%s:%d %s @param requires a target and non-empty description after ':'" % [path, line_number, function_name])
	return issues


func _line_starts_function(trimmed: String) -> bool:
	return trimmed.begins_with("func ") or trimmed.begins_with("static func ")


func _get_parenthesis_delta(text: String) -> int:
	var delta: int = 0
	for i: int in range(text.length()):
		var character: String = text[i]
		if character == "(":
			delta += 1
		elif character == ")":
			delta -= 1
	return delta


func _parse_signature_params(signature: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var open_index: int = signature.find("(")
	var close_index: int = signature.rfind(")")
	if open_index == -1 or close_index == -1 or close_index <= open_index:
		return result

	var args_text: String = signature.substr(open_index + 1, close_index - open_index - 1).strip_edges()
	if args_text.is_empty():
		return result

	for raw_part: String in _split_top_level_arguments(args_text):
		var part: String = raw_part.strip_edges()
		if part.is_empty():
			continue

		var default_index: int = _find_top_level_character(part, "=")
		var without_default: String = part
		if default_index != -1:
			without_default = part.substr(0, default_index).strip_edges()

		var type_index: int = _find_top_level_character(without_default, ":")
		var param_name: String = without_default
		if type_index != -1:
			param_name = without_default.substr(0, type_index).strip_edges()
		if not param_name.is_empty():
			var _append_result_135: Variant = result.append(param_name)
	return result


func _parse_documented_params(doc_lines: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.new()
	var _compile_result_142: Variant = regex.compile("@param\\s+([A-Za-z_]\\w*)\\s*:")
	for line: String in doc_lines:
		for match_result: RegExMatch in regex.search_all(line):
			var _append_result_145: Variant = result.append(match_result.get_string(1))
	return result


func _should_validate_param_docs(
	function_name: String,
	actual_params: PackedStringArray,
	documented_params: PackedStringArray
) -> bool:
	if not documented_params.is_empty():
		return true
	if actual_params.is_empty():
		return false
	return not function_name.begins_with("_")


func _collect_function_param_doc_issues(
	path: String,
	signature_start_line: int,
	function_name: String,
	actual_params: PackedStringArray,
	documented_params: PackedStringArray,
	allow_partial: bool = false
) -> Array[String]:
	var issues: Array[String] = []
	var duplicate_params: PackedStringArray = _collect_duplicate_names(documented_params)
	for duplicate_param: String in duplicate_params:
		issues.append("%s:%d %s documents duplicate param '%s'" % [
			path,
			signature_start_line,
			function_name,
			duplicate_param,
		])

	var expected_params: PackedStringArray = PackedStringArray()
	for actual_param: String in actual_params:
		if documented_params.has(actual_param):
			var _append_expected_result: bool = expected_params.append(actual_param)
		elif not allow_partial:
			issues.append("%s:%d %s missing @param for '%s'" % [
				path,
				signature_start_line,
				function_name,
				actual_param,
			])

	for documented_param: String in documented_params:
		if not actual_params.has(documented_param):
			issues.append("%s:%d %s documents unknown param '%s'" % [
				path,
				signature_start_line,
				function_name,
				documented_param,
			])

	if issues.is_empty() and not _packed_string_arrays_equal(expected_params, documented_params):
		issues.append("%s:%d %s @param order should be [%s] but was [%s]" % [
			path,
			signature_start_line,
			function_name,
			", ".join(expected_params),
			", ".join(documented_params),
		])

	return issues


func _split_top_level_arguments(args_text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var start_index: int = 0
	for i: int in range(args_text.length()):
		if args_text[i] == "," and _is_top_level_character(args_text, i):
			var _append_result_213: Variant = result.append(args_text.substr(start_index, i - start_index))
			start_index = i + 1
	var _append_result_215: Variant = result.append(args_text.substr(start_index))
	return result


func _find_top_level_character(text: String, target: String) -> int:
	for i: int in range(text.length()):
		if text[i] == target and _is_top_level_character(text, i):
			return i
	return -1


func _is_top_level_character(text: String, target_index: int) -> bool:
	var parenthesis_depth: int = 0
	var bracket_depth: int = 0
	var brace_depth: int = 0
	var in_string: bool = false
	var string_delimiter: String = ""
	var escaped: bool = false

	for i: int in range(target_index):
		var character: String = text[i]
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == string_delimiter:
				in_string = false
			continue

		if character == "\"" or character == "'":
			in_string = true
			string_delimiter = character
		elif character == "(":
			parenthesis_depth += 1
		elif character == ")":
			parenthesis_depth -= 1
		elif character == "[":
			bracket_depth += 1
		elif character == "]":
			bracket_depth -= 1
		elif character == "{":
			brace_depth += 1
		elif character == "}":
			brace_depth -= 1

	return (
		not in_string
		and parenthesis_depth == 0
		and bracket_depth == 0
		and brace_depth == 0
	)


func _collect_duplicate_names(names: PackedStringArray) -> PackedStringArray:
	var duplicates: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for param_name: String in names:
		if seen.has(param_name):
			if not duplicates.has(param_name):
				var _append_result_275: Variant = duplicates.append(param_name)
		else:
			seen[param_name] = true
	return duplicates


func _packed_string_arrays_equal(left: PackedStringArray, right: PackedStringArray) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if left[i] != right[i]:
			return false
	return true


func _parse_function_name(signature: String) -> String:
	var regex: RegEx = RegEx.new()
	var _compile_result_292: Variant = regex.compile("(?:static\\s+)?func\\s+(\\w+)")
	var result: RegExMatch = regex.search(signature)
	if result == null:
		return "<unknown>"
	return result.get_string(1)


func _join_lines(lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var _append_result_302: Variant = packed.append(line)
	return "\n".join(packed)
