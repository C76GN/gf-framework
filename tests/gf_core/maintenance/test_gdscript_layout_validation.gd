## 验证框架 GDScript 文件的 section 布局约束。
extends GutTest


# --- 常量 ---

const SOURCE_ROOT: String = "res://addons/gf"
const TEST_ROOT: String = "res://tests/gf_core"
const SECTION_PREFIX: String = "# --- "
const SECTION_SUFFIX: String = " ---"
const TRIPLE_QUOTE: String = "\"\"\""
const PRIVATE_SECTION_MARKERS: Array[String] = [
	"私有",
	"内部",
	"辅助",
	"private",
	"internal",
	"helper",
]
const LIFECYCLE_SECTION_MARKERS: Array[String] = [
	"生命周期",
	"回调",
	"callback",
	"callbacks",
	"lifecycle",
]
const SIGNAL_CALLBACK_SECTION_MARKERS: Array[String] = [
	"信号处理",
	"信号回调",
	"signal handler",
	"signal callback",
]
const VARIABLE_SECTION_MARKERS: Array[String] = [
	"变量",
	"variable",
]
const VIRTUAL_SECTION_MARKERS: Array[String] = [
	"虚方法",
	"可重写",
	"重写钩子",
	"hook",
	"hooks",
	"protected",
	"virtual",
]
const GODOT_CALLBACK_NAMES: Dictionary = {
	"_can_handle": true,
	"_capture": true,
	"_draw": true,
	"_enter_tree": true,
	"_export_begin": true,
	"_export_end": true,
	"_export_file": true,
	"_exit_tree": true,
	"_get": true,
	"_get_configuration_warnings": true,
	"_get_name": true,
	"_get_property_list": true,
	"_gui_input": true,
	"_has_capture": true,
	"_init": true,
	"_input": true,
	"_notification": true,
	"_parse_begin": true,
	"_parse_category": true,
	"_parse_end": true,
	"_parse_group": true,
	"_parse_property": true,
	"_physics_process": true,
	"_process": true,
	"_property_can_revert": true,
	"_property_get_revert": true,
	"_ready": true,
	"_set": true,
	"_setup_session": true,
	"_shortcut_input": true,
	"_to_string": true,
	"_unhandled_input": true,
	"_unhandled_key_input": true,
	"_update_property": true,
	"_validate_property": true,
}
const SECTION_ORDER_RULES: Array[Dictionary] = [
	{ "markers": ["信号处理", "信号回调", "signal handler", "signal callback"], "rank": 115 },
	{ "markers": ["信号"], "rank": 10 },
	{ "markers": ["枚举"], "rank": 20 },
	{ "markers": ["常量"], "rank": 30 },
	{ "markers": ["导出变量"], "rank": 40 },
	{ "markers": ["公共变量"], "rank": 50 },
	{ "markers": ["私有变量", "私有静态变量"], "rank": 60 },
	{ "markers": ["@onready"], "rank": 70 },
	{ "markers": ["生命周期", "回调", "lifecycle", "callback"], "rank": 80 },
	{ "markers": ["公共方法", "获取方法", "注册方法", "事件系统", "命令", "查询"], "rank": 90 },
	{ "markers": ["虚方法", "可重写", "hook", "virtual"], "rank": 100 },
	{ "markers": ["私有", "内部", "辅助", "private", "internal", "helper"], "rank": 110 },
	{ "markers": ["内部类", "subclass"], "rank": 120 },
]
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_underscore_methods_use_matching_sections() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_underscore_method_section_issues(path))

	assert_eq(issues, [], "下划线方法应放在匹配语义的 section 中：\n%s" % _join_lines(issues))


func test_top_level_private_variables_use_private_sections() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_private_variable_section_issues(path))

	assert_eq(issues, [], "私有变量应放在私有变量 section 中：\n%s" % _join_lines(issues))


func test_public_methods_do_not_use_private_sections() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_public_method_in_private_section_issues(path))

	assert_eq(issues, [], "普通公共方法不应放在私有/辅助 section 中：\n%s" % _join_lines(issues))


func test_private_helper_sections_do_not_return_to_public_sections() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_section_regression_issues(path))

	assert_eq(issues, [], "私有/辅助方法 section 后不应再回到普通公共 section：\n%s" % _join_lines(issues))


func test_class_name_files_document_class_before_class_name() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_class_doc_order_issues(path))

	assert_eq(issues, [], "class_name 文件应先写文件级说明再声明 class_name：\n%s" % _join_lines(issues))


func test_top_level_inner_classes_use_inner_class_sections() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_inner_class_section_issues(path))

	assert_eq(issues, [], "顶层内部类应放在内部类 section 中：\n%s" % _join_lines(issues))


func test_top_level_sections_follow_documented_order() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_section_order_issues(path))

	assert_eq(issues, [], "顶层 section 应遵循 CODING_STYLE.md 的布局顺序：\n%s" % _join_lines(issues))


func test_editor_generation_templates_use_documented_sections() -> void:
	var file: FileAccess = FileAccess.open("res://addons/gf/plugin.gd", FileAccess.READ)
	assert_not_null(file, "应能读取 GF 编辑器插件源码。")
	if file == null:
		return

	var source: String = file.get_as_text()
	file.close()
	var actions_file: FileAccess = FileAccess.open("res://addons/gf/kernel/editor/gf_plugin_actions.gd", FileAccess.READ)
	assert_not_null(actions_file, "应能读取 GF 插件菜单动作源码。")
	if actions_file == null:
		return

	var actions_source: String = actions_file.get_as_text()
	actions_file.close()

	assert_false(source.contains("# --- 私有辅助方法 ---") or actions_source.contains("# --- 私有辅助方法 ---"), "编辑器代码生成模板应使用规范 section 名称。")
	assert_false(_source_contains_lifecycle_template(actions_source, "Godot 生命周期方法"), "GF 模块模板不应把 GF 生命周期误写成 Godot 生命周期。")
	assert_true(source.contains("# --- 私有/辅助方法 ---"), "编辑器代码生成模板应包含私有/辅助方法 section。")
	assert_true(_source_contains_lifecycle_template(actions_source, "GF 生命周期方法"), "编辑器代码生成模板应包含 GF 生命周期 section。")


func test_local_variables_do_not_shadow_node_name_property() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	script_paths.append_array(_collect_gdscript_files(TEST_ROOT))
	var issues: Array[String] = []
	for path: String in script_paths:
		issues.append_array(_collect_local_name_shadow_issues(path))

	assert_eq(issues, [], "局部变量不应命名为 name，以免在 Node 派生脚本和 GUT 测试中遮蔽 Node.name：\n%s" % _join_lines(issues))


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

	var _list_dir_begin_result_209: Variant = dir.list_dir_begin()
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


func _collect_underscore_method_section_issues(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["%s: cannot open file" % path]

	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	var issues: Array[String] = []
	var current_section: String = ""
	var inside_multiline_string: bool = false
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var triple_quote_count: int = _count_substring(raw_line, TRIPLE_QUOTE)
		if inside_multiline_string:
			if triple_quote_count % 2 == 1:
				inside_multiline_string = false
			continue
		if triple_quote_count % 2 == 1:
			inside_multiline_string = true
			continue

		var section_name: String = _parse_section_name(raw_line)
		if not section_name.is_empty():
			current_section = section_name
			continue

		var function_name: String = _parse_top_level_function_name(raw_line)
		if function_name.is_empty() or not function_name.begins_with("_"):
			continue
		if _underscore_method_section_is_valid(function_name, current_section):
			continue

		issues.append("%s:%d %s 位于不匹配的 section：%s" % [
			path,
			line_index + 1,
			function_name,
			_get_section_label(current_section),
		])
	return issues


func _collect_private_variable_section_issues(path: String) -> Array[String]:
	var issues: Array[String] = []
	_scan_top_level_source(path, func(line: String, line_number: int, section_name: String) -> void:
		if _line_starts_private_variable(line) and not _section_is_private_variable_section(section_name):
			issues.append("%s:%d 私有变量位于不匹配的 section：%s" % [
				path,
				line_number,
				_get_section_label(section_name),
			])
	)
	return issues


func _collect_public_method_in_private_section_issues(path: String) -> Array[String]:
	var issues: Array[String] = []
	_scan_top_level_source(path, func(line: String, line_number: int, section_name: String) -> void:
		var function_name: String = _parse_top_level_function_name(line)
		if function_name.is_empty() or function_name.begins_with("_"):
			return
		if _section_is_private_helper_section(section_name):
			issues.append("%s:%d %s 位于私有/辅助 section：%s" % [
				path,
				line_number,
				function_name,
				_get_section_label(section_name),
			])
	)
	return issues


func _collect_section_regression_issues(path: String) -> Array[String]:
	var issues: Array[String] = []
	var state: Dictionary = {
		"private_helper_section_seen": false,
	}
	_scan_top_level_source(path, func(line: String, line_number: int, _section_name: String) -> void:
		var parsed_section: String = _parse_section_name(line)
		if parsed_section.is_empty():
			return

		if GF_VARIANT_ACCESS.get_option_bool(state, "private_helper_section_seen", false) and not _section_is_allowed_after_private_helper_section(parsed_section):
			issues.append("%s:%d section 不应出现在私有/辅助方法 section 之后：%s" % [
				path,
				line_number,
				_get_section_label(parsed_section),
			])
		if _section_is_private_helper_section(parsed_section):
			state["private_helper_section_seen"] = true
	)
	return issues


func _collect_class_doc_order_issues(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["%s: cannot open file" % path]

	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	var first_doc_line: int = -1
	var class_name_line: int = -1
	for line_index: int in range(lines.size()):
		var line: String = _trim_cr(String(lines[line_index])).strip_edges()
		if first_doc_line == -1 and line.begins_with("##"):
			first_doc_line = line_index + 1
		if line.begins_with("class_name "):
			class_name_line = line_index + 1
			break

	if class_name_line == -1:
		return []
	if first_doc_line != -1 and first_doc_line < class_name_line:
		return []
	return ["%s:%d class_name 出现在文件级说明之前" % [path, class_name_line]]


func _collect_inner_class_section_issues(path: String) -> Array[String]:
	var issues: Array[String] = []
	_scan_top_level_source(path, func(line: String, line_number: int, section_name: String) -> void:
		var inner_class_name: String = _parse_top_level_inner_class_name(line)
		if inner_class_name.is_empty():
			return
		if _section_is_inner_class_section(section_name):
			return
		issues.append("%s:%d %s 位于非内部类 section：%s" % [
			path,
			line_number,
			inner_class_name,
			_get_section_label(section_name),
		])
	)
	return issues


func _collect_section_order_issues(path: String) -> Array[String]:
	var issues: Array[String] = []
	var state: Dictionary = {
		"last_rank": -1,
		"last_section": "",
	}
	_scan_top_level_source(path, func(line: String, line_number: int, _section_name: String) -> void:
		var parsed_section: String = _parse_section_name(line)
		if parsed_section.is_empty():
			return

		var rank: int = _get_section_order_rank(parsed_section)
		if rank == -1:
			return

		var last_rank: int = GF_VARIANT_ACCESS.get_option_int(state, "last_rank", -1)
		if last_rank != -1 and rank < last_rank:
			issues.append("%s:%d section 顺序倒退：%s 出现在 %s 之后" % [
				path,
				line_number,
				_get_section_label(parsed_section),
				_get_section_label(GF_VARIANT_ACCESS.get_option_string(state, "last_section")),
			])
		state["last_rank"] = rank
		state["last_section"] = parsed_section
	)
	return issues


func _collect_local_name_shadow_issues(path: String) -> Array[String]:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ["%s: cannot open file" % path]

	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	var issues: Array[String] = []
	var inside_multiline_string: bool = false
	var function_indent: int = -1
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var triple_quote_count: int = _count_substring(raw_line, TRIPLE_QUOTE)
		if inside_multiline_string:
			if triple_quote_count % 2 == 1:
				inside_multiline_string = false
			continue
		if triple_quote_count % 2 == 1:
			inside_multiline_string = true
			continue

		var trimmed: String = raw_line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		var indent: int = _get_indent_level(raw_line)
		if function_indent != -1 and indent <= function_indent:
			function_indent = -1
		if trimmed.begins_with("func ") or trimmed.begins_with("static func "):
			function_indent = indent
			continue
		if function_indent == -1:
			continue
		if not _declares_reserved_local_name(trimmed):
			continue

		issues.append("%s:%d local variable 'name' shadows Node.name; use a semantic name" % [path, line_index + 1])
	return issues


func _scan_top_level_source(path: String, callback: Callable) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		callback.call("cannot open file", 0, "")
		return

	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	var current_section: String = ""
	var inside_multiline_string: bool = false
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var triple_quote_count: int = _count_substring(raw_line, TRIPLE_QUOTE)
		if inside_multiline_string:
			if triple_quote_count % 2 == 1:
				inside_multiline_string = false
			continue
		if triple_quote_count % 2 == 1:
			inside_multiline_string = true
			continue

		var section_name: String = _parse_section_name(raw_line)
		if not section_name.is_empty():
			current_section = section_name
		callback.call(raw_line, line_index + 1, current_section)


func _parse_section_name(line: String) -> String:
	if line.begins_with("\t") or line.begins_with(" "):
		return ""

	var trimmed: String = line.strip_edges()
	if not trimmed.begins_with(SECTION_PREFIX):
		return ""
	if not trimmed.ends_with(SECTION_SUFFIX):
		return ""
	var start_index: int = SECTION_PREFIX.length()
	var content_length: int = trimmed.length() - SECTION_PREFIX.length() - SECTION_SUFFIX.length()
	if content_length <= 0:
		return ""
	return trimmed.substr(start_index, content_length).strip_edges()


func _parse_top_level_function_name(line: String) -> String:
	var signature: String = ""
	if line.begins_with("func "):
		signature = line.substr("func ".length())
	elif line.begins_with("static func "):
		signature = line.substr("static func ".length())
	else:
		return ""

	var open_index: int = signature.find("(")
	if open_index == -1:
		return ""
	return signature.substr(0, open_index).strip_edges()


func _parse_top_level_inner_class_name(line: String) -> String:
	if not line.begins_with("class "):
		return ""
	var signature: String = line.substr("class ".length()).strip_edges()
	if signature.is_empty():
		return ""

	var end_index: int = signature.find(" ")
	var colon_index: int = signature.find(":")
	if end_index == -1 or (colon_index != -1 and colon_index < end_index):
		end_index = colon_index
	if end_index == -1:
		return signature
	return signature.substr(0, end_index).strip_edges()


func _line_starts_private_variable(line: String) -> bool:
	if line.begins_with("var _") or line.begins_with("static var _"):
		return true
	return line.begins_with("@export") and line.contains(" var _")


func _declares_reserved_local_name(trimmed_line: String) -> bool:
	return _starts_with_keyword_identifier(trimmed_line, "var", "name") or _starts_with_keyword_identifier(trimmed_line, "for", "name")


func _starts_with_keyword_identifier(trimmed_line: String, keyword: String, identifier: String) -> bool:
	var prefix: String = "%s %s" % [keyword, identifier]
	if not trimmed_line.begins_with(prefix):
		return false
	if trimmed_line.length() == prefix.length():
		return true

	var next_character: String = trimmed_line[prefix.length()]
	return [" ", "\t", ":", "=", ","].has(next_character)


func _underscore_method_section_is_valid(function_name: String, section_name: String) -> bool:
	if _section_has_marker(section_name, PRIVATE_SECTION_MARKERS):
		return true
	if GODOT_CALLBACK_NAMES.has(function_name):
		return _section_has_marker(section_name, LIFECYCLE_SECTION_MARKERS)
	if function_name.begins_with("_on_"):
		return (
			_section_has_marker(section_name, SIGNAL_CALLBACK_SECTION_MARKERS)
			or _section_has_marker(section_name, VIRTUAL_SECTION_MARKERS)
		)
	return _section_has_marker(section_name, VIRTUAL_SECTION_MARKERS)


func _section_is_private_variable_section(section_name: String) -> bool:
	return (
		_section_has_marker(section_name, PRIVATE_SECTION_MARKERS)
		and _section_has_marker(section_name, VARIABLE_SECTION_MARKERS)
	)


func _section_is_private_helper_section(section_name: String) -> bool:
	return (
		_section_has_marker(section_name, PRIVATE_SECTION_MARKERS)
		and not _section_is_framework_or_layer_internal_section(section_name)
		and not _section_has_marker(section_name, VARIABLE_SECTION_MARKERS)
	)


func _section_is_framework_or_layer_internal_section(section_name: String) -> bool:
	return (
		section_name.contains("框架内部")
		or section_name.contains("层内")
		or section_name.to_lower().contains("framework internal")
		or section_name.to_lower().contains("layer internal")
	)


func _section_is_allowed_after_private_helper_section(section_name: String) -> bool:
	return (
		_section_is_private_helper_section(section_name)
		or _section_has_marker(section_name, SIGNAL_CALLBACK_SECTION_MARKERS)
		or _section_has_marker(section_name, VIRTUAL_SECTION_MARKERS)
		or _section_is_inner_class_section(section_name)
	)


func _section_is_inner_class_section(section_name: String) -> bool:
	var lower_section: String = section_name.to_lower()
	return (
		lower_section.contains("subclass")
		or section_name.contains("内部类")
		or (section_name.contains("内部") and section_name.contains("类"))
	)


func _get_section_order_rank(section_name: String) -> int:
	if _section_is_inner_class_section(section_name):
		return 120

	for rule: Dictionary in SECTION_ORDER_RULES:
		var markers: Array = GF_VARIANT_ACCESS.get_option_array(rule, "markers", [])
		for marker: String in markers:
			if section_name.to_lower().contains(marker.to_lower()):
				return GF_VARIANT_ACCESS.get_option_int(rule, "rank", -1)
	return -1


func _source_contains_lifecycle_template(source: String, section_name: String) -> bool:
	var typed_template: String = "var lifecycle_template: String = \"\"\"# --- %s ---" % section_name
	var inferred_template: String = "var lifecycle_template :" + "= \"\"\"# --- %s ---" % section_name
	return source.contains(typed_template) or source.contains(inferred_template)


func _section_has_marker(section_name: String, markers: Array[String]) -> bool:
	var lower_section: String = section_name.to_lower()
	for marker: String in markers:
		if lower_section.contains(marker.to_lower()):
			return true
	return false


func _count_substring(text: String, needle: String) -> int:
	if needle.is_empty():
		return 0

	var count: int = 0
	var search_from: int = 0
	while search_from < text.length():
		var found_index: int = text.find(needle, search_from)
		if found_index == -1:
			break
		count += 1
		search_from = found_index + needle.length()
	return count


func _trim_cr(text: String) -> String:
	if text.ends_with("\r"):
		return text.substr(0, text.length() - 1)
	return text


func _get_indent_level(line: String) -> int:
	var result: int = 0
	for index: int in range(line.length()):
		var character: String = line[index]
		if character == "\t":
			result += 1
		elif character == " ":
			result += 1
		else:
			break
	return result


func _get_section_label(section_name: String) -> String:
	if section_name.is_empty():
		return "<none>"
	return section_name


func _join_lines(lines: Array[String]) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var _append_result_645: Variant = packed.append(line)
	return "\n".join(packed)
