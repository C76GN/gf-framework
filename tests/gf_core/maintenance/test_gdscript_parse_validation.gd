## 验证 GF 源码脚本可被 Godot 解析加载。
extends GutTest


# --- 常量 ---

const SOURCE_ROOT: String = "res://addons/gf"
const TEST_ROOT: String = "res://tests/gf_core"
const KERNEL_CORE_ROOT: String = "res://addons/gf/kernel/core"
const KERNEL_DYNAMIC_BOUNDARY_PATHS: Array[String] = [
	KERNEL_CORE_ROOT,
	"res://addons/gf/kernel/base",
	"res://addons/gf/kernel/extension",
	"res://addons/gf/kernel/editor/gf_plugin_menu.gd",
	"res://addons/gf/kernel/editor/gf_resource_table_editor.gd",
]
const REMOVED_PUBLIC_CLASS_NAMES: Array[String] = [
	"GFShakeAction",
	"GFInputUtility",
	"GFValidationUtility",
	"GFDecimalStringUtility",
	"GFScriptTypeUtility",
	"GFTagUtility",
	"GFTextFitUtility",
	"GFNodeTreeUtility",
	"GFVariantUtility",
	"GFAttribute",
]
const SAVE_RUNTIME_BASE_SCRIPT_PATHS: Array[String] = [
	"res://addons/gf/extensions/save/core/gf_save_scope.gd",
	"res://addons/gf/extensions/save/core/gf_save_source.gd",
	"res://addons/gf/extensions/save/core/gf_save_identity.gd",
]
const DYNAMIC_INFERENCE_TOKENS: Array[String] = [
	"." + "get(",
	".get_script(",
	".get_ref(",
	".call(",
	" load(",
	"ResourceLoader.load(",
	"JSON.parse_string(",
]
const RESERVED_LOCAL_IDENTIFIERS: Array[String] = [
	"reference",
]
const WARNING_CLEAN_SCAN_ROOTS: Array[String] = [
	SOURCE_ROOT,
	TEST_ROOT,
]
const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_gf_source_scripts_load_without_parse_errors() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		var resource: Resource = load(path)
		if resource == null:
			issues.append("%s: load returned null" % path)
			continue
		if not (resource is Script):
			issues.append("%s: loaded resource is not a Script" % path)

	assert_eq(issues, [], "GF 源码脚本应能被 Godot 解析加载：\n%s" % _join_lines(issues))


func test_explicit_object_get_calls_do_not_use_dictionary_defaults() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_object_get_default_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		("显式对象类型只能调用单参数 Object." + "get()；需要默认值时应先转成 Dictionary 或显式判空：\n%s") % _join_lines(issues)
	)


func test_kernel_dynamic_values_are_not_inferred_with_colon_equals() -> void:
	var script_paths: Array[String] = _collect_dynamic_boundary_gdscript_files()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_dynamic_inference_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		("kernel 的核心运行时边界不应从 Variant 或反射边界使用 :"
		+ "= 推断局部类型；请显式声明类型并先收窄：\n%s") % _join_lines(issues)
	)


func test_kernel_dynamic_casts_use_explicit_typed_variables() -> void:
	var script_paths: Array[String] = _collect_dynamic_boundary_gdscript_files()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_dynamic_cast_inference_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		("kernel 的核心运行时边界不应使用 `var value :"
		+ "= dynamic "
		+ "as Type`；请先 `is` 判断或通过强类型 helper 收口：\n%s") % _join_lines(issues)
	)


func test_kernel_reserved_local_identifiers_are_not_reintroduced() -> void:
	var script_paths: Array[String] = _collect_dynamic_boundary_gdscript_files()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_reserved_local_identifier_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		"kernel 的核心运行时边界局部变量和参数不应使用易遮蔽基类 API 的名字：\n%s" % _join_lines(issues)
	)


func test_warning_clean_scripts_do_not_shadow_global_class_names() -> void:
	var script_paths: Array[String] = _collect_warning_clean_gdscript_files()
	var class_names_by_name: Dictionary = _collect_class_names_by_name()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_global_class_name_shadow_issues(path, _read_text(path), class_names_by_name, issues)

	assert_eq(
		issues,
		[],
		("GF 源码和测试常量不应与全局 class_name 同名；脚本 preload/load 别名应使用 `_SCRIPT`、`_BASE` "
		+ "或全大写语义名，避免 SHADOWED_GLOBAL_IDENTIFIER：\n%s") % _join_lines(issues)
	)


func test_warning_clean_scripts_do_not_use_unchecked_gf_class_casts() -> void:
	var script_paths: Array[String] = _collect_warning_clean_gdscript_files()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_unchecked_gf_class_cast_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		("GF 源码和测试不应直接使用 GF 类强转；请先用 `is` 收窄并赋值给强类型局部变量，"
		+ "避免 UNSAFE_CAST：\n%s") % _join_lines(issues)
	)


func test_warning_clean_scripts_do_not_instantiate_script_typed_values() -> void:
	var script_paths: Array[String] = _collect_warning_clean_gdscript_files()
	var issues: Array[String] = []
	for path: String in script_paths:
		_collect_script_typed_new_issues(path, _read_text(path), issues)

	assert_eq(
		issues,
		[],
		("GF 源码和测试不应对 `Script` 类型变量直接 `.new()`；需要实例化时先 `is GDScript` "
		+ "收窄成 `GDScript`，避免 UNSAFE_METHOD_ACCESS：\n%s") % _join_lines(issues)
	)


func test_save_runtime_base_scripts_do_not_force_tool_annotation() -> void:
	var issues: Array[String] = []
	for path: String in SAVE_RUNTIME_BASE_SCRIPT_PATHS:
		var source: String = _read_text(path).strip_edges()
		if source.begins_with("@tool"):
			issues.append(path)

	assert_eq(
		issues,
		[],
		"项目常继承的 Save 运行时基类不应声明 @tool，避免要求用户业务脚本也声明 @tool：\n%s" % _join_lines(issues)
	)


func test_removed_public_class_names_do_not_remain_in_runtime_source() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var issues: Array[String] = []
	for path: String in script_paths:
		var source: String = _read_text(path)
		for removed_class_name: String in REMOVED_PUBLIC_CLASS_NAMES:
			if _contains_identifier(source, removed_class_name):
				issues.append("%s contains removed class name %s" % [path, removed_class_name])

	assert_eq(
		issues,
		[],
		"`addons/gf` 运行时代码不应保留已移除公开类名的副本。"
	)


func test_public_class_names_are_unique() -> void:
	var script_paths: Array[String] = _collect_gdscript_files(SOURCE_ROOT)
	var paths_by_class_name: Dictionary = {}
	var regex: RegEx = RegEx.new()
	var _compile_result_153: Variant = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in script_paths:
		var source: String = _read_text(path)
		for match_result: RegExMatch in regex.search_all(source):
			var discovered_class_name: String = match_result.get_string(1)
			if not paths_by_class_name.has(discovered_class_name):
				paths_by_class_name[discovered_class_name] = []
			var paths: Array = GF_VARIANT_ACCESS.get_option_array(paths_by_class_name, discovered_class_name, [])
			paths.append(path)
			paths_by_class_name[discovered_class_name] = paths

	var issues: Array[String] = []
	for discovered_class_name: String in paths_by_class_name.keys():
		var paths: Array = GF_VARIANT_ACCESS.get_option_array(paths_by_class_name, discovered_class_name, [])
		if paths.size() > 1:
			issues.append("%s declared in %s" % [discovered_class_name, _join_string_values(paths)])

	assert_eq(issues, [], "公开 class_name 必须唯一，避免重复脚本污染 Godot 全局类型表：\n%s" % _join_lines(issues))


func test_gdscript_uid_files_are_unique_and_match_scripts() -> void:
	var uid_paths: Array[String] = _collect_files_with_suffix(SOURCE_ROOT, ".gd.uid")
	var path_by_uid: Dictionary = {}
	var issues: Array[String] = []
	for uid_path: String in uid_paths:
		var script_path: String = uid_path.substr(0, uid_path.length() - ".uid".length())
		if not FileAccess.file_exists(script_path):
			issues.append("%s has no matching script %s" % [uid_path, script_path])

		var uid: String = _read_text(uid_path).strip_edges()
		if uid.is_empty():
			issues.append("%s has empty uid" % uid_path)
			continue
		if not uid.begins_with("uid://"):
			issues.append("%s has invalid uid %s" % [uid_path, uid])
			continue
		if path_by_uid.has(uid):
			issues.append("%s duplicates uid from %s" % [uid_path, GF_VARIANT_ACCESS.to_text(path_by_uid[uid])])
		else:
			path_by_uid[uid] = uid_path

	assert_eq(issues, [], "GDScript UID 文件必须和脚本一一对应，且 UID 不应重复：\n%s" % _join_lines(issues))


# --- 私有/辅助方法 ---

func _collect_gdscript_files(root_path: String) -> Array[String]:
	var result: Array[String] = []
	_collect_gdscript_files_recursive(root_path, result)
	result.sort()
	return result


func _collect_dynamic_boundary_gdscript_files() -> Array[String]:
	var result: Array[String] = []
	for scan_path: String in KERNEL_DYNAMIC_BOUNDARY_PATHS:
		if scan_path.ends_with(".gd"):
			if not result.has(scan_path):
				result.append(scan_path)
			continue
		for path: String in _collect_gdscript_files(scan_path):
			if not result.has(path):
				result.append(path)
	result.sort()
	return result


func _collect_warning_clean_gdscript_files() -> Array[String]:
	var result: Array[String] = []
	for scan_root: String in WARNING_CLEAN_SCAN_ROOTS:
		for path: String in _collect_gdscript_files(scan_root):
			if not result.has(path):
				result.append(path)
	result.sort()
	return result


func _collect_gdscript_files_recursive(root_path: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_225: Variant = dir.list_dir_begin()
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


func _collect_files_with_suffix(root_path: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	_collect_files_with_suffix_recursive(root_path, suffix, result)
	result.sort()
	return result


func _collect_files_with_suffix_recursive(root_path: String, suffix: String, result: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result_250: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var child_path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_files_with_suffix_recursive(child_path, suffix, result)
		elif entry.ends_with(suffix):
			result.append(child_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _join_lines(values: Array[String]) -> String:
	if values.is_empty():
		return ""

	var packed: PackedStringArray = PackedStringArray()
	for value: String in values:
		var _append_result_278: Variant = packed.append(value)
	return "\n".join(packed)


func _join_string_values(values: Array) -> String:
	if values.is_empty():
		return ""

	var packed: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var _append_result_288: Variant = packed.append(GF_VARIANT_ACCESS.to_text(value))
	return ", ".join(packed)


func _collect_object_get_default_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var global_types: Dictionary = {}
	var scope_types: Dictionary = {}
	var receiver_regex: RegEx = RegEx.new()
	var _compile_result_297: Variant = receiver_regex.compile("\\b([A-Za-z_]\\w*)\\." + "get\\(")
	var declaration_regex: RegEx = RegEx.new()
	var _compile_result_299: Variant = declaration_regex.compile("\\bvar\\s+([A-Za-z_]\\w*)\\s*:\\s*([A-Za-z_]\\w*)")
	var cast_declaration_regex: RegEx = RegEx.new()
	var _compile_result_301: Variant = cast_declaration_regex.compile("\\bvar\\s+([A-Za-z_]\\w*)\\s*:" + "=.*\\bas\\s+([A-Za-z_]\\w*)")
	var for_regex: RegEx = RegEx.new()
	var _compile_result_303: Variant = for_regex.compile("\\bfor\\s+([A-Za-z_]\\w*)\\s*:\\s*([A-Za-z_]\\w*)\\s+in\\b")

	var in_function: bool = false
	for i: int in range(lines.size()):
		var line: String = String(lines[i])
		var stripped: String = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue

		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			in_function = true
			scope_types = global_types.duplicate()
			var signature: String = line
			var signature_index: int = i + 1
			while not signature.contains(")") and signature_index < lines.size():
				signature += "\n" + String(lines[signature_index])
				signature_index += 1
			_add_typed_parameters(signature, scope_types)
		elif not in_function:
			_add_typed_declaration(line, declaration_regex, global_types)

		if in_function:
			_add_typed_declaration(line, declaration_regex, scope_types)
			_add_typed_declaration(line, cast_declaration_regex, scope_types)
			_add_typed_declaration(line, for_regex, scope_types)

		for match_result: RegExMatch in receiver_regex.search_all(line):
			var receiver: String = match_result.get_string(1)
			if not scope_types.has(receiver):
				continue
			var type_name: String = GF_VARIANT_ACCESS.to_text(scope_types[receiver])
			if not _is_object_get_default_risk_type(type_name):
				continue
			if _get_call_has_default_argument(lines, i, match_result.get_start()):
				issues.append(("%s:%d uses %s." + "get() with a Dictionary-style default on %s") % [
					path,
					i + 1,
					receiver,
					type_name,
				])


func _collect_dynamic_inference_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if not _line_declares_colon_equals_local(trimmed):
			continue
		for token: String in DYNAMIC_INFERENCE_TOKENS:
			if trimmed.contains(token):
				issues.append("%s:%d infers from dynamic boundary `%s`: %s" % [
					path,
					line_index + 1,
					token,
					trimmed,
				])
				break


func _collect_dynamic_cast_inference_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var cast_regex: RegEx = RegEx.new()
	var _compile_result_372: Variant = cast_regex.compile("\\bvar\\s+([A-Za-z_]\\w*)\\s*:" + "=.*\\bas\\s+(Object|Script|Array|Dictionary|Callable|PackedStringArray|WeakRef|GF[A-Za-z_]\\w*)\\b")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if cast_regex.search(trimmed) != null:
			issues.append("%s:%d uses inferred dynamic cast: %s" % [path, line_index + 1, trimmed])


func _collect_global_class_name_shadow_issues(
	path: String,
	source: String,
	class_names_by_name: Dictionary,
	issues: Array[String]
) -> void:
	var lines: PackedStringArray = source.split("\n")
	var preload_const_regex: RegEx = RegEx.new()
	var _compile_result_396: Variant = preload_const_regex.compile("^\\s*const\\s+([A-Za-z_]\\w*)\\s*=\\s*(preload|load)\\s*\\(")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		var code_line: String = _strip_inline_strings_and_comments(raw_line)
		var code_trimmed: String = code_line.strip_edges()
		if code_trimmed.is_empty():
			continue

		var match_result: RegExMatch = preload_const_regex.search(code_line)
		if match_result == null:
			continue

		var const_name: String = match_result.get_string(1)
		if not class_names_by_name.has(const_name):
			continue

		var class_path: String = GF_VARIANT_ACCESS.to_text(class_names_by_name[const_name])
		if class_path == path:
			continue
		issues.append("%s:%d const `%s` shadows class_name from %s" % [
			path,
			line_index + 1,
			const_name,
			class_path,
		])


func _collect_unchecked_gf_class_cast_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var cast_regex: RegEx = RegEx.new()
	var _compile_result_432: Variant = cast_regex.compile("\\bas\\s+(GF[A-Za-z_]\\w*)\\b")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		var code_line: String = _strip_inline_strings_and_comments(raw_line)
		var code_trimmed: String = code_line.strip_edges()
		if code_trimmed.is_empty():
			continue

		for match_result: RegExMatch in cast_regex.search_all(code_trimmed):
			var cast_type: String = match_result.get_string(1)
			var cast_type_end: int = match_result.get_end(1)
			if cast_type_end < code_trimmed.length() and code_trimmed[cast_type_end] == ".":
				continue
			issues.append("%s:%d uses unchecked GF class cast `%s`: %s" % [
				path,
				line_index + 1,
				cast_type,
				trimmed,
			])


func _collect_script_typed_new_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var script_declaration_regex: RegEx = RegEx.new()
	var _compile_result_463: Variant = script_declaration_regex.compile("\\bvar\\s+([A-Za-z_]\\w*)\\s*:\\s*Script\\b")
	var script_variable_lines: Dictionary = {}
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		var code_line: String = _strip_inline_strings_and_comments(raw_line)
		var code_trimmed: String = code_line.strip_edges()
		if code_trimmed.is_empty():
			continue
		if code_trimmed.begins_with("func ") or code_trimmed.begins_with("static func "):
			script_variable_lines = {}

		var declaration_match: RegExMatch = script_declaration_regex.search(code_trimmed)
		if declaration_match != null:
			script_variable_lines[declaration_match.get_string(1)] = line_index + 1

		for variable_name: String in script_variable_lines.keys():
			if code_trimmed.contains("%s.new(" % variable_name):
				issues.append("%s:%d calls `.new()` on Script-typed variable `%s`: %s" % [
					path,
					line_index + 1,
					variable_name,
					trimmed,
				])


func _collect_reserved_local_identifier_issues(path: String, source: String, issues: Array[String]) -> void:
	var lines: PackedStringArray = source.split("\n")
	var multiline_string_delimiter: String = ""
	for line_index: int in range(lines.size()):
		var raw_line: String = _trim_cr(String(lines[line_index]))
		var trimmed: String = raw_line.strip_edges()
		multiline_string_delimiter = _update_multiline_string_delimiter(trimmed, multiline_string_delimiter)
		if not multiline_string_delimiter.is_empty():
			continue
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		for identifier: String in RESERVED_LOCAL_IDENTIFIERS:
			if _declares_local_or_parameter_identifier(trimmed, identifier):
				issues.append("%s:%d uses reserved identifier `%s`: %s" % [
					path,
					line_index + 1,
					identifier,
					trimmed,
				])


func _line_declares_colon_equals_local(trimmed: String) -> bool:
	return trimmed.begins_with("var ") and trimmed.contains(":" + "=")


func _declares_local_or_parameter_identifier(trimmed: String, identifier: String) -> bool:
	if _starts_with_keyword_identifier(trimmed, "var", identifier):
		return true
	if _starts_with_keyword_identifier(trimmed, "for", identifier):
		return true
	if trimmed.begins_with("func ") or trimmed.begins_with("static func "):
		return _signature_has_parameter_identifier(trimmed, identifier)
	return false


func _signature_has_parameter_identifier(signature: String, identifier: String) -> bool:
	var open_index: int = signature.find("(")
	var close_index: int = signature.rfind(")")
	if open_index == -1 or close_index <= open_index:
		return false

	var parameters_text: String = signature.substr(open_index + 1, close_index - open_index - 1)
	for raw_parameter: String in parameters_text.split(","):
		var parameter_text: String = raw_parameter.strip_edges()
		if parameter_text.is_empty():
			continue
		if _starts_with_identifier(parameter_text, identifier):
			return true
	return false


func _starts_with_identifier(text: String, identifier: String) -> bool:
	if not text.begins_with(identifier):
		return false
	if text.length() == identifier.length():
		return true

	var next_character: String = text[identifier.length()]
	return [" ", "\t", ":", "=", ","].has(next_character)


func _starts_with_keyword_identifier(trimmed: String, keyword: String, identifier: String) -> bool:
	var prefix: String = "%s %s" % [keyword, identifier]
	if not trimmed.begins_with(prefix):
		return false
	if trimmed.length() == prefix.length():
		return true

	var next_character: String = trimmed[prefix.length()]
	return [" ", "\t", ":", "=", ","].has(next_character)


func _update_multiline_string_delimiter(trimmed: String, current_delimiter: String) -> String:
	if not current_delimiter.is_empty():
		if trimmed.contains(current_delimiter):
			return ""
		return current_delimiter
	if trimmed.contains("\"\"\""):
		return "\"\"\""
	if trimmed.contains("'''"):
		return "'''"
	return ""


func _trim_cr(text: String) -> String:
	if text.ends_with("\r"):
		return text.substr(0, text.length() - 1)
	return text


func _strip_inline_strings_and_comments(line: String) -> String:
	var result: String = ""
	var in_string: bool = false
	var escaped: bool = false
	var string_delimiter: String = ""
	for index: int in range(line.length()):
		var character: String = line[index]
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == string_delimiter:
				in_string = false
				string_delimiter = ""
			result += " "
			continue
		if character == "#":
			break
		if character == "\"" or character == "'":
			in_string = true
			string_delimiter = character
			result += " "
			continue
		result += character
	return result


func _add_typed_parameters(signature: String, types: Dictionary) -> void:
	var param_regex: RegEx = RegEx.new()
	var _compile_result_478: Variant = param_regex.compile("\\b([A-Za-z_]\\w*)\\s*:\\s*([A-Za-z_]\\w*)")
	for match_result: RegExMatch in param_regex.search_all(signature):
		types[match_result.get_string(1)] = match_result.get_string(2)


func _add_typed_declaration(line: String, regex: RegEx, types: Dictionary) -> void:
	var match_result: RegExMatch = regex.search(line)
	if match_result == null:
		return
	types[match_result.get_string(1)] = match_result.get_string(2)


func _collect_class_names_by_name() -> Dictionary:
	var class_names_by_name: Dictionary = {}
	var class_name_regex: RegEx = RegEx.new()
	var _compile_result_502: Variant = class_name_regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in _collect_gdscript_files(SOURCE_ROOT):
		var source: String = _read_text(path)
		var match_result: RegExMatch = class_name_regex.search(source)
		if match_result == null:
			continue
		class_names_by_name[match_result.get_string(1)] = path
	return class_names_by_name


func _get_call_has_default_argument(lines: PackedStringArray, start_line: int, start_column: int) -> bool:
	var line: String = String(lines[start_line])
	var open_index: int = line.find("(", start_column)
	if open_index < 0:
		return false

	var depth: int = 1
	var in_string: bool = false
	var escaped: bool = false
	for line_index: int in range(start_line, mini(start_line + 8, lines.size())):
		var text: String = String(lines[line_index])
		var column: int = open_index + 1 if line_index == start_line else 0
		while column < text.length():
			var character: String = text[column]
			if in_string:
				if escaped:
					escaped = false
				elif character == "\\":
					escaped = true
				elif character == "\"":
					in_string = false
			elif character == "\"":
				in_string = true
			elif character == "(":
				depth += 1
			elif character == ")":
				depth -= 1
				if depth == 0:
					return false
			elif character == "," and depth == 1:
				return true
			column += 1
	return false


func _is_object_get_default_risk_type(type_name: String) -> bool:
	if type_name in [
		"Variant",
		"Dictionary",
		"Array",
		"bool",
		"int",
		"float",
		"String",
		"StringName",
	]:
		return false
	if type_name.begins_with("Packed"):
		return false
	return (
		type_name in [
			"Object",
			"Node",
			"Resource",
			"RefCounted",
			"Script",
			"Control",
			"CanvasItem",
			"WeakRef",
		]
		or type_name.begins_with("Editor")
		or type_name.begins_with("GF")
	)


func _contains_identifier(source: String, identifier: String) -> bool:
	var regex: RegEx = RegEx.new()
	var _compile_result_557: Variant = regex.compile("(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])" % identifier)
	return regex.search(source) != null
