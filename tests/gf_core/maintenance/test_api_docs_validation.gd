## 验证框架 API 文档注释与函数签名保持同步。
extends GutTest


# --- 常量 ---

const SOURCE_ROOT: String = "res://addons/gf"
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const CONTRACT_SOURCES = preload("res://tests/gf_core/maintenance/helpers/gf_comment_contract_sources.gd")
const DIRECTORY_LINK_FIXTURE = preload("res://tests/gf_core/support/gf_test_directory_link_fixture.gd")


# --- 私有变量 ---

var _scan_fixture_paths: Array[String] = []


# --- 生命周期方法 ---

func after_each() -> void:
	# 只反向删除本测试创建的精确条目；先 unlink，绝不递归进入链接目标。
	for index: int in range(_scan_fixture_paths.size() - 1, -1, -1):
		assert_eq(DirAccess.remove_absolute(_scan_fixture_paths[index]), OK, "扫描夹具应按创建顺序反向清理。")
	_scan_fixture_paths.clear()


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


func test_param_scanner_ignores_literal_examples_and_comment_delimiters() -> void:
	for delimiter: String in ['"""', "'''"]:
		var literal: String = "const EXAMPLE = %s\n## @param wrong: 字符串中的示例。\nfunc example(value: int) -> void:\n\tpass\n%s\n" % [delimiter, delimiter]
		assert_eq(_collect_param_doc_issues_from_source(literal, "literal_fixture.gd"), [], "字符串中的文档和声明不是源码契约。")
		var source: String = "# 示例分隔符为 %s\nfunc actual(value: int) -> void: pass\n" % delimiter
		assert_true(_join_lines(_collect_param_doc_issues_from_source(source, "comment_fixture.gd")).contains("missing @param for 'value'"), "注释中的引号不能屏蔽真实函数。")


func test_param_scanner_preserves_signature_boundaries_and_annotations() -> void:
	var source: String = "## @param value: 输入。\n@warning_ignore(\"unused_parameter\") func documented(value: String = \"# ) , (\") -> void: print(\"ignored\")\nfunc missing(next_value: int) -> void: pass\n"
	var issues: Array[String] = _collect_param_doc_issues_from_source(source, "inline_fixture.gd.txt")
	assert_eq(issues.size(), 1, "注解、字符串和单行函数体不能并入参数表。")
	assert_true(_join_lines(issues).contains("missing @param for 'next_value'"), "后续函数仍须独立检查。")
	var multiline: String = "## @param first: 第一项。\n## @param second: 第二项。\n@warning_ignore(\"unused_parameter\")\nfunc multiline(\n\tfirst: String = \"(\", # ) 字符串和注释不影响参数深度\n\tsecond: Dictionary = {\"nested\": [1, 2]},\n) -> void:\n\tpass\n"
	assert_eq(_collect_param_doc_issues_from_source(multiline, "multiline_fixture.gd"), [], "多行函数参数必须在真实配对括号处结束。")
	var multiline_annotation: String = "## @param value: 输入。\n@warning_ignore(\n\t\"unused_parameter\",\n)\nfunc annotated(value: int) -> void: pass\n"
	assert_eq(_collect_param_doc_issues_from_source(multiline_annotation, "annotation_fixture.gd.txt"), [], "多行注解不能切断声明绑定的参数文档。")


func test_comment_source_scan_includes_hidden_regular_sources() -> void:
	var root_path: String = _create_scan_fixture_root()
	var hidden_path: String = _create_scan_fixture_directory(root_path.path_join(".hidden"))
	_hide_scan_fixture_directory(hidden_path)
	var script_path: String = hidden_path.path_join("member.gd")
	var template_path: String = hidden_path.path_join("member.gd.txt")
	_write_scan_fixture_file(script_path)
	_write_scan_fixture_file(template_path)
	_write_scan_fixture_file(hidden_path.path_join("notes.txt"))
	var issues: Array[String] = []
	assert_eq(CONTRACT_SOURCES.collect_files(root_path, issues), [script_path, template_path], "普通隐藏目录中的源码和模板仍必须完整纳入。")
	assert_eq(issues, [], "隐藏属性本身不是扫描错误。")


func test_comment_source_scan_rejects_directory_links() -> void:
	var root_path: String = _create_scan_fixture_root()
	var outside_path: String = _create_scan_fixture_directory(root_path.path_join("outside"))
	var leaf_path: String = _create_scan_fixture_directory(outside_path.path_join("leaf"))
	_write_scan_fixture_file(leaf_path.path_join("escaped.gd"))
	var link_kinds: Array[bool] = [false]
	if OS.get_name() == "Windows":
		link_kinds.append(true)
	for force_junction: bool in link_kinds:
		var scan_path: String = _create_scan_fixture_directory(root_path.path_join("scan_%s" % force_junction))
		var hidden_path: String = _create_scan_fixture_directory(scan_path.path_join(".hidden"))
		_hide_scan_fixture_directory(hidden_path)
		var local_path: String = scan_path.path_join("local.gd")
		_write_scan_fixture_file(local_path)
		var link_path: String = hidden_path.path_join("linked")
		if not _create_scan_fixture_directory_link(outside_path, link_path, force_junction):
			continue
		var issues: Array[String] = []
		var paths: Array[String] = CONTRACT_SOURCES.collect_files(scan_path, issues)
		assert_eq(paths, [local_path], "隐藏祖先下的链接不能把外部声明纳入扫描。")
		assert_true(_join_lines(issues).contains(link_path), "拒绝链接必须报告具体路径，不能静默忽略。")
		for linked_root: String in [link_path, link_path.path_join("leaf")]:
			issues.clear()
			assert_eq(CONTRACT_SOURCES.collect_files(linked_root, issues), [], "扫描根自身或祖先为链接时必须拒绝。")
			assert_true(_join_lines(issues).contains(link_path), "祖先链检查必须指出链接边界。")


func test_comment_source_scan_rejects_file_links() -> void:
	var root_path: String = _create_scan_fixture_root()
	var outside_file: String = root_path.path_join("outside.gd")
	_write_scan_fixture_file(outside_file)
	var scan_path: String = _create_scan_fixture_directory(root_path.path_join("scan"))
	var directory: DirAccess = DirAccess.open(scan_path)
	assert_not_null(directory)
	if directory == null:
		return
	var link_path: String = scan_path.path_join("linked.gd")
	var link_error: Error = directory.create_link(outside_file, link_path)
	if link_error != OK:
		assert_eq(OS.get_name(), "Windows", "POSIX 必须能创建真实文件符号链接。")
		assert_eq(link_error, FAILED, "Windows 无建链权限时只接受平台建链失败，不提权或掩盖路径错误。")
		return
	_scan_fixture_paths.append(link_path)
	var issues: Array[String] = []
	assert_eq(CONTRACT_SOURCES.collect_files(scan_path, issues), [], "源码文件链接不能把外部文件纳入扫描。")
	assert_true(_join_lines(issues).contains(link_path), "拒绝文件链接必须报告具体路径。")


func test_comment_source_scan_rejects_ancestor_cycle_links() -> void:
	var root_path: String = _create_scan_fixture_root()
	var hidden_path: String = _create_scan_fixture_directory(root_path.path_join(".hidden"))
	_hide_scan_fixture_directory(hidden_path)
	var local_path: String = root_path.path_join("local.gd")
	_write_scan_fixture_file(local_path)
	var link_path: String = hidden_path.path_join("back_to_root")
	if not _create_scan_fixture_directory_link(root_path, link_path, OS.get_name() == "Windows"):
		return
	var issues: Array[String] = []
	assert_eq(CONTRACT_SOURCES.collect_files(root_path, issues), [local_path], "回指祖先的真实链接必须在递归前拒绝，不能展开循环。")
	assert_eq(issues.size(), 1, "循环链接只报告自身，不重复展开祖先。")
	assert_true(_join_lines(issues).contains(link_path), "循环错误必须指向被拒绝的链接。")


# --- 私有/辅助方法 ---

func _create_scan_fixture_root() -> String:
	return _create_scan_fixture_directory(ProjectSettings.globalize_path(
		"user://comment_contract_scan_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	))


func _create_scan_fixture_directory(path: String) -> String:
	var create_error: Error = DirAccess.make_dir_absolute(path)
	assert_eq(create_error, OK, "扫描夹具必须创建独立目录：%s" % path)
	if create_error == OK:
		_scan_fixture_paths.append(path)
	return path


func _write_scan_fixture_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "扫描夹具必须能写入普通文件。")
	if file != null:
		assert_true(file.store_string("extends RefCounted\n"), "扫描夹具必须完整写入内容。")
		file.close()
		_scan_fixture_paths.append(path)


func _hide_scan_fixture_directory(path: String) -> void:
	if OS.get_name() == "Windows":
		assert_eq(FileAccess.set_hidden_attribute(path, true), OK, "Windows 夹具必须设置真实隐藏属性。")


func _create_scan_fixture_directory_link(target_path: String, link_path: String, force_junction: bool) -> bool:
	var link_error: Error = FAILED
	if force_junction:
		# Windows junction 无需符号链接权限；强制覆盖，不能因 Developer Mode 改成 symlink。
		for path: String in [target_path, link_path]:
			for character: String in ["\"", "\r", "\n", "%", "!"]:
				if path.contains(character):
					assert_true(false, "junction 夹具路径不得含 cmd 展开字符。")
					return false
		var command_output: Array = []
		var exit_code: int = OS.execute("cmd.exe", PackedStringArray([
			"/d", "/s", "/c", 'mklink /J "%s" "%s"' % [link_path, target_path],
		]), command_output, true, false)
		if exit_code == 0 and DirAccess.dir_exists_absolute(link_path):
			link_error = OK
	else:
		link_error = DIRECTORY_LINK_FIXTURE.create(target_path, link_path)
	assert_eq(link_error, OK, "必须建立真实目录符号链接或 Windows junction；不得提权或跳过。")
	if link_error != OK:
		return false
	_scan_fixture_paths.append(link_path)
	var parent_directory: DirAccess = DirAccess.open(link_path.get_base_dir())
	assert_not_null(parent_directory)
	if parent_directory == null:
		return false
	assert_true(parent_directory.is_link(link_path.get_file()), "当前 Godot 必须把真实 junction/symlink 识别为 link；不满足时门禁失败。")
	return true


func _collect_gdscript_files(root_path: String) -> Array[String]:
	var issues: Array[String] = []
	var paths: Array[String] = CONTRACT_SOURCES.collect_files(root_path, issues)
	assert_eq(issues, [], "完整扫描必须能枚举每个目录：%s" % _join_lines(issues))
	return paths


func _collect_param_doc_issues(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["%s: cannot open file" % path]

	var source: String = file.get_as_text()
	file.close()
	return _collect_param_doc_issues_from_source(source, path)


func _collect_param_doc_issues_from_source(source: String, path: String) -> Array[String]:
	source = CONTRACT_SOURCES.render_source(source, path)
	var lines: PackedStringArray = source.split("\n")
	var issues: Array[String] = []
	var doc_lines: Array[String] = []
	var line_index: int = 0
	var multiline_delimiter: String = ""
	while line_index < lines.size():
		var line: String = String(lines[line_index])
		var trimmed: String = line.strip_edges()
		var lexical: Dictionary = CONTRACT_SOURCES.lex_line(line, multiline_delimiter)
		multiline_delimiter = GF_VARIANT_ACCESS.get_option_string(lexical, "multiline_delimiter")
		var structure: String = GF_VARIANT_ACCESS.get_option_string(lexical, "code").strip_edges()
		if GF_VARIANT_ACCESS.get_option_bool(lexical, "starts_in_multiline"):
			doc_lines.clear()
			line_index += 1
			continue
		if trimmed.begins_with("##"):
			doc_lines.append(trimmed)
			line_index += 1
			continue

		var function_header: String = _strip_signature_annotations(structure)
		while function_header.begins_with("@") and function_header.contains("(") and _find_signature_close(function_header) == -1 and line_index + 1 < lines.size():
			line_index += 1
			lexical = CONTRACT_SOURCES.lex_line(String(lines[line_index]), multiline_delimiter)
			multiline_delimiter = GF_VARIANT_ACCESS.get_option_string(lexical, "multiline_delimiter")
			structure += " " + GF_VARIANT_ACCESS.get_option_string(lexical, "code").strip_edges()
			function_header = _strip_signature_annotations(structure)
		if _line_starts_function(function_header):
			var signature_start_line: int = line_index + 1
			var signature: String = function_header
			while _find_signature_close(signature) == -1 and line_index + 1 < lines.size():
				line_index += 1
				lexical = CONTRACT_SOURCES.lex_line(String(lines[line_index]), multiline_delimiter)
				multiline_delimiter = GF_VARIANT_ACCESS.get_option_string(lexical, "multiline_delimiter")
				signature += " " + GF_VARIANT_ACCESS.get_option_string(lexical, "code").strip_edges()

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

		if not trimmed.is_empty() and not (structure.begins_with("@") and function_header.is_empty()):
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


func _strip_signature_annotations(structure: String) -> String:
	var remaining: String = structure
	while remaining.begins_with("@"):
		var index: int = 1
		while index < remaining.length() and (remaining[index].is_valid_identifier() or remaining[index].is_valid_int()):
			index += 1
		if index < remaining.length() and remaining[index] == "(":
			var close_index: int = _find_signature_close(remaining.substr(index))
			if close_index == -1:
				return remaining
			index += close_index + 1
		remaining = remaining.substr(index).strip_edges()
	return remaining


func _find_signature_close(text: String) -> int:
	var open_index: int = text.find("(")
	if open_index == -1:
		return -1
	var delta: int = 0
	for i: int in range(open_index, text.length()):
		var character: String = text[i]
		if character == "(":
			delta += 1
		elif character == ")":
			delta -= 1
			if delta == 0:
				return i
	return -1


func _parse_signature_params(signature: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var open_index: int = signature.find("(")
	var close_index: int = _find_signature_close(signature)
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
