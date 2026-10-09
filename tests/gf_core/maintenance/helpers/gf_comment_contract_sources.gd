## 为注释契约测试提供统一源码清单和保持原内容的模板展开。
extends RefCounted


# --- 常量 ---

const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const INTEGRATION_SNIPPET_PATH: String = "res://addons/gf/tools/project_bootstrap/templates/empty_project/integration_snippet.gd.txt"


# --- 私有变量 ---

static var _native_virtual_methods: Dictionary = {}


# --- 公共方法 ---

static func collect_files(root_path: String, issues: Array[String] = []) -> Array[String]:
	var result: Array[String] = []
	if not _validate_unlinked_root(root_path, issues):
		return result
	_collect_files_recursive(root_path, result, issues)
	result.sort()
	return result


static func render_source(source: String, path: String) -> String:
	if not path.ends_with(".gd.txt"):
		return source
	# 使用生成器接受的字面量替换；不删除原始模板行或为声明合成可见性。
	var rendered: String = source.replace("{DatabasePath}", '"res://comment_contract_fixture.tres"')
	rendered = rendered.replace("{TableName}", '"comment_contract_fixture"')
	rendered = rendered.replace("__ROOT__", "res://comment_contract_fixture")
	if path == INTEGRATION_SNIPPET_PATH:
		# 此资源的消费合同是插入现有 Node 异步函数体；完整保留片段并提供该语法上下文。
		var wrapped: String = "extends Node\n\n# --- 私有/辅助方法 ---\n\n## 承载原样集成片段的测试函数。\n## [br]\n## @api private\nfunc _integration_fixture() -> void:\n"
		for line: String in rendered.split("\n"):
			wrapped += "\t" + line + "\n"
		return wrapped
	return rendered


static func is_native_virtual(base_type: String, method_name: String) -> bool:
	if not ClassDB.class_exists(base_type):
		return false
	# _init 是 GDScript 构造协议，不在 ClassDB 的虚方法清单中。
	if method_name == "_init":
		return true
	if not _native_virtual_methods.has(base_type):
		var virtual_methods: Dictionary = {}
		for method: Dictionary in ClassDB.class_get_method_list(base_type):
			if (GF_VARIANT_ACCESS.get_option_int(method, "flags") & METHOD_FLAG_VIRTUAL) != 0:
				virtual_methods[GF_VARIANT_ACCESS.get_option_string(method, "name")] = true
		_native_virtual_methods[base_type] = virtual_methods
	var methods: Dictionary = _native_virtual_methods[base_type]
	return methods.has(method_name)


static func lex_line(line: String, multiline_delimiter: String = "") -> Dictionary:
	var code: String = ""
	var quote: String = multiline_delimiter
	var index: int = 0
	while index < line.length():
		var character: String = line[index]
		if not quote.is_empty():
			if character == "\\" and index + 1 < line.length():
				code += "  "
				index += 2
				continue
			if line.substr(index, quote.length()) == quote:
				code += " ".repeat(quote.length())
				index += quote.length()
				quote = ""
				continue
			code += " "
		elif character == "#":
			code += " ".repeat(line.length() - index)
			break
		elif character == "\"" or character == "'":
			quote = character.repeat(3) if line.substr(index, 3) == character.repeat(3) else character
			code += " ".repeat(quote.length())
			index += quote.length()
			continue
		else:
			code += character
		index += 1
	return {
		"code": code,
		"starts_in_multiline": not multiline_delimiter.is_empty(),
		"multiline_delimiter": quote if quote.length() == 3 else "",
	}


# --- 私有/辅助方法 ---

static func _validate_unlinked_root(root_path: String, issues: Array[String]) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(root_path).replace("\\", "/")
	if not absolute_path.is_absolute_path():
		var current_directory: DirAccess = DirAccess.open(".")
		if current_directory == null:
			issues.append("%s: cannot resolve comment-contract source root" % root_path)
			return false
		absolute_path = current_directory.get_current_dir().path_join(absolute_path)
	absolute_path = absolute_path.simplify_path()
	while absolute_path.ends_with("/") and absolute_path != "/" and not absolute_path.ends_with(":/"):
		absolute_path = absolute_path.trim_suffix("/")
	var components: Array[String] = []
	while not absolute_path.get_file().is_empty():
		components.push_front(absolute_path)
		var parent_path: String = absolute_path.get_base_dir()
		if parent_path.ends_with(":"):
			parent_path += "/"
		if parent_path == absolute_path:
			issues.append("%s: cannot resolve comment-contract source ancestry" % root_path)
			return false
		absolute_path = parent_path
	# 自卷根向下检查，避免先打开已经穿过链接的更深层父目录。
	for component_path: String in components:
		var parent_path: String = component_path.get_base_dir()
		if parent_path.ends_with(":"):
			parent_path += "/"
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory == null:
			issues.append("%s: cannot inspect comment-contract source parent" % component_path)
			return false
		if parent_directory.is_link(component_path.get_file()):
			issues.append("%s: linked comment-contract source is not allowed" % component_path)
			return false
		if not parent_directory.dir_exists(component_path.get_file()):
			issues.append("%s: comment-contract source directory is unavailable" % component_path)
			return false
	return true


static func _collect_files_recursive(root_path: String, result: Array[String], issues: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		issues.append("%s: cannot enumerate comment-contract sources (error %d)" % [root_path, DirAccess.get_open_error()])
		return
	directory.include_hidden = true
	directory.include_navigational = false
	var begin_result: Error = directory.list_dir_begin()
	if begin_result != OK:
		issues.append("%s: cannot begin comment-contract enumeration (error %d)" % [root_path, begin_result])
		return
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var path: String = root_path.path_join(entry)
		# Windows 的 is_link 检测 REPARSE_POINT，包含 junction；不得先递归或接纳文件。
		if directory.is_link(entry):
			issues.append("%s: linked comment-contract source is not allowed" % path)
		elif directory.current_is_dir():
			_collect_files_recursive(path, result, issues)
		elif entry.ends_with(".gd") or entry.ends_with(".gd.txt"):
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
