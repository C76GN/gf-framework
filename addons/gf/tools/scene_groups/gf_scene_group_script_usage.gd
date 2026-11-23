@tool
# 对已保存 GDScript 做词法查询。扫描只处理文本，不加载项目脚本。
extends RefCounted


# --- 常量 ---

## Node 实例的组方法。
## [br]
## @api private
const _NODE_METHODS: PackedStringArray = [
	"add_to_group",
	"remove_from_group",
	"is_in_group",
]

## SceneTree 组方法及组名所在的参数下标。
## [br]
## @api private
const _TREE_METHODS: Dictionary[String, int] = {
	"get_nodes_in_group": 0,
	"get_first_node_in_group": 0,
	"get_node_count_in_group": 0,
	"has_group": 0,
	"call_group": 0,
	"notify_group": 0,
	"set_group": 0,
	"call_group_flags": 1,
	"notify_group_flags": 1,
	"set_group_flags": 1,
}

## 把注释、引号字面量和续行作为完整词元消费，保留物理行号。
## [br]
## @api private
const _TOKEN_PATTERN: String = r"""(?s:[&^r]?"{3}(?:\\.|(?!"{3})[^\\])*+(?:"{3}|\z)|[&^r]?'{3}(?:\\.|(?!'{3})[^\\])*+(?:'{3}|\z))|[&^r]?"(?:\\[^\n]|[^"\\\n])*+"?|[&^r]?'(?:\\[^\n]|[^'\\\n])*+'?|#[^\n]*|\\\n|\n|[\p{L}_][\p{L}\p{N}_]*|[^\s]"""


# --- 私有变量 ---

## 可跨多个文件复用的词法表达式。
## [br]
## @api private
var _lexer: RegEx = RegEx.create_from_string(_TOKEN_PATTERN)

## 全局脚本类到基类名的快照，用于识别继承 Node 的项目类。
## [br]
## @api private
var _bases: Dictionary[String, String] = {}


# --- Godot 生命周期方法 ---

## 缓存编辑器登记的类继承关系。
## [br]
## @api private
func _init() -> void:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		var script_class: StringName = entry["class"]
		var base_class: StringName = entry["base"]
		_bases[String(script_class)] = String(base_class)


# --- 框架内部方法 ---

## 从单个已保存脚本收集有行号的调用，返回至多 capacity 条。
## [br]
## @api framework_internal
## [br]
## @param source: 已通过大小检查的源码。
## [br]
## @param path: 脚本资源路径。
## [br]
## @param capacity: 允许返回的最多记录数。
## [br]
## @return 记录及是否有更多未收录调用。
## [br]
## @schema return: Dictionary 含 rows:Array[Dictionary]、overflow:bool；每行含 group、method、resolution、path、line、digest。
func scan(
	source: String,
	path: String,
	capacity: int
) -> Dictionary:
	var rows: Array[Dictionary] = []
	var result: Dictionary = { "rows": rows, "overflow": false }
	var possible: bool = false
	for method: String in _NODE_METHODS:
		if source.contains(method):
			possible = true
			break
	if not possible:
		for method: String in _TREE_METHODS:
			if source.contains(method):
				possible = true
				break
	if not possible:
		return result
	var statements: Array[Dictionary] = _statements(source)
	var constants: Dictionary = {}
	var member_types: Dictionary = {}
	var member_shadows: Dictionary = {}
	var scope: Dictionary = {}
	var base: String = ""
	for statement: Dictionary in statements:
		var words: PackedStringArray = statement["words"]
		var top: bool = statement["top"]
		if scope.is_empty() or top:
			scope = { "types": {}, "shadows": {} }
		statement["scope"] = scope
		if top and words[0] in ["class_name", "extends"]:
			var extends_at: int = words.find("extends")
			if extends_at >= 0 and extends_at == words.size() - 2:
				base = words[-1]
		var member: bool = (
			top
			and words[0] != "class"
			and not words.has("func")
		)
		var declarations: Dictionary = member_types if member else scope["types"]
		var shadows: Dictionary = member_shadows if member else scope["shadows"]
		_collect_bindings(
			words,
			top,
			constants,
			shadows,
			declarations
		)
	var builtin: String = _native_base(base)
	var in_inner_class: bool = false
	var digest: String = ""
	for statement: Dictionary in statements:
		var words: PackedStringArray = statement["words"]
		var lines: PackedInt32Array = statement["lines"]
		var bindings: Dictionary = statement["scope"]
		var local_types: Dictionary = bindings["types"]
		var local_shadows: Dictionary = bindings["shadows"]
		if statement["top"]:
			in_inner_class = words[0] == "class"
		for index: int in range(words.size() - 1):
			var method: String = words[index]
			var group_method: bool = method in _NODE_METHODS or _TREE_METHODS.has(method)
			if not group_method or words[index + 1] != "(":
				continue
			if index > 0 and words[index - 1] == "func":
				continue
			var receiver: String = _receiver(
				words,
				index,
				method,
				"" if in_inner_class else builtin,
				local_types,
				{} if in_inner_class else member_types
			)
			if receiver == "unrelated":
				continue
			var argument_index: int = _TREE_METHODS.get(method, 0)
			var argument: String = _group_argument(
				words,
				index + 2,
				argument_index
			)
			var group: String = _literal(argument)
			if (
				group.is_empty()
				and constants.has(argument)
				and not local_shadows.has(argument)
				and not member_shadows.has(argument)
				and not in_inner_class
			):
				group = constants[argument]
			var resolution: String = "fixed" if not group.is_empty() else "dynamic_group"
			if receiver == "unknown":
				resolution = "unknown_receiver"
				group = ""
			if rows.size() == capacity:
				result["overflow"] = true
				return result
			if digest.is_empty():
				digest = source.sha256_text()
			rows.append(
				{
					"group": group,
					"method": method,
					"resolution": resolution,
					"path": path,
					"line": lines[index],
					"digest": digest,
				}
			)
	return result


# --- 私有/辅助方法 ---

## 在括号之外按换行和分号分隔语句，记录每个词元的原始行。
## [br]
## @api private
func _statements(source: String) -> Array[Dictionary]:
	var statements: Array[Dictionary] = []
	var words: PackedStringArray = []
	var lines: PackedInt32Array = []
	var line: int = 1
	var line_start: int = 0
	var depth: int = 0
	var top: bool = false
	for token: RegExMatch in _lexer.search_all(source):
		var word: String = token.get_string()
		if word.begins_with("#"):
			continue
		if word == "\n" or word == ";":
			if depth == 0 and not words.is_empty():
				statements.append(
					{
						"words": words,
						"lines": lines,
						"top": top,
					}
				)
				words = []
				lines = []
		elif word != "\\\n":
			if words.is_empty():
				top = token.get_start() == line_start
			var _added: bool = words.append(word)
			var _line_added: bool = lines.append(line)
			if word in [
				"(",
				"[",
				"{",
			]:
				depth += 1
			elif word in [
				")",
				"]",
				"}",
			]:
				depth = maxi(
					0,
					depth - 1
				)
		var newlines: int = word.count("\n")
		if newlines > 0:
			line += newlines
			line_start = token.get_start() + word.rfind("\n") + 1
	if not words.is_empty():
		statements.append(
			{
				"words": words,
				"lines": lines,
				"top": top,
			}
		)
	return statements


## 仅采纳文件顶层直接赋字符串的常量，同名局部声明或参数令名字失去确定性。
## [br]
## @api private
func _collect_bindings(
	words: PackedStringArray,
	top: bool,
	constants: Dictionary,
	shadows: Dictionary,
	types: Dictionary
) -> void:
	var is_constant: bool = (
		top
		and words[0] == "const"
		and words.size() >= 4
	)
	if is_constant:
		var equals: int = words.find("=")
		var name_key: String = words[1]
		if constants.has(name_key):
			shadows[name_key] = true
		if equals == words.size() - 2:
			constants[name_key] = _literal(words[-1])
	var in_parameters: bool = false
	var depth: int = 0
	for index: int in range(
		1,
		words.size()
	):
		var previous: String = words[index - 1]
		var own_constant: bool = is_constant and index == 1
		if previous in [
			"const",
			"var",
			"for",
		] and not own_constant:
			shadows[words[index]] = true
			if top and not words.has("func"):
				_remember_type(
					words,
					index,
					types
				)
			else:
				types[words[index]] = ""
		var named_function: bool = index >= 2 and words[index - 2] == "func"
		var function_name: bool = named_function or previous == "func"
		if words[index] == "(" and function_name:
			in_parameters = true
			depth = 0
		if in_parameters:
			if previous in ["(", ","] and depth == 1:
				shadows[words[index]] = true
				if top:
					_remember_type(
						words,
						index,
						types
					)
				else:
					types[words[index]] = ""
			if words[index] == "(":
				depth += 1
			elif words[index] == ")":
				depth -= 1
				in_parameters = depth > 0


## 记录声明的原生接收者类型；同名声明或不明确的类型只保留为未知。
## [br]
## @api private
func _remember_type(
	words: PackedStringArray,
	index: int,
	types: Dictionary
) -> void:
	var key: String = words[index]
	var builtin: String = ""
	if (
		not types.has(key)
		and index + 2 < words.size()
		and words[index + 1] == ":"
	):
		builtin = _native_base(words[index + 2])
	types[key] = builtin


## 不实例化脚本，沿全局类声明找到原生类型。路径继承无法证明时保留候选。
## [br]
## @api private
func _native_base(base: String) -> String:
	var seen: Dictionary = {}
	while _bases.has(base) and not seen.has(base):
		seen[base] = true
		base = _bases[base]
	return base if ClassDB.class_exists(base) else ""


## 区分 self、已声明类型的变量和 Node.get_tree()，未知对象只进入待确认列表。
## [br]
## @api private
func _receiver(
	words: PackedStringArray,
	index: int,
	method: String,
	builtin: String,
	types: Dictionary,
	members: Dictionary
) -> String:
	var expected: String = "Node" if method in _NODE_METHODS else "SceneTree"
	var receiver: String = builtin
	if index > 0 and words[index - 1] == ".":
		var dot: int = index - 1
		if index >= 4 and words.slice(
			index - 4,
			index
		) == PackedStringArray(
			[
				"get_tree",
				"(",
				")",
				".",
			]
		):
			if expected != "SceneTree":
				return "unknown"
			expected = "Node"
			dot = index - 5
			if dot < 0 or words[dot] != ".":
				dot = -1
		if dot >= 0:
			if dot == 0:
				return "unknown"
			var name_key: String = words[dot - 1]
			if name_key != "self":
				if dot >= 2 and words[dot - 2] in [
					".",
					"$",
					"%",
				]:
					return "unknown"
				receiver = types.get(
					name_key,
					members.get(name_key, "")
				)
	if receiver.is_empty():
		return "unknown"
	if ClassDB.is_parent_class(receiver, expected):
		return "known"
	if ClassDB.is_parent_class(expected, receiver):
		return "unknown"
	return "unrelated"


## 跳过 flags 等前置参数的完整表达式，仅返回独立的组名词元。
## [br]
## @api private
func _group_argument(
	words: PackedStringArray,
	start: int,
	wanted: int
) -> String:
	var depth: int = 0
	var argument: int = 0
	var first: int = start
	for index: int in range(
		start,
		words.size()
	):
		var word: String = words[index]
		if depth == 0 and word in [",", ")"]:
			if argument == wanted:
				return words[first] if first + 1 == index else ""
			if word == ")":
				break
			argument += 1
			first = index + 1
		elif word in [
			"(",
			"[",
			"{",
		]:
			depth += 1
		elif word in [
			")",
			"]",
			"}",
		]:
			depth -= 1
	return ""


## 解码完整的单行字面量，无法确定含义的转义保留为动态。
## [br]
## @api private
func _literal(word: String) -> String:
	var raw: bool = word.begins_with("r")
	var quoted: String = word.trim_prefix("r") if raw else word.trim_prefix("&")
	if quoted.length() < 2 or quoted.contains("\n"):
		return ""
	var mark: String = quoted.left(1)
	if (
		mark not in ["\"", "'"]
		or not quoted.ends_with(mark)
		or quoted.begins_with(mark.repeat(3))
	):
		return ""
	var content: String = quoted.substr(
		1,
		quoted.length() - 2
	)
	if not content.contains("\\"):
		return content
	if raw:
		return content if not content.contains(mark) else ""
	var value: String = ""
	var index: int = 0
	while index < content.length():
		var character: String = content[index]
		index += 1
		if character != "\\":
			value += character
			continue
		if index == content.length():
			return ""
		var escaped: String = content[index]
		index += 1
		if escaped in ["u", "U"]:
			var width: int = 4 if escaped == "u" else 6
			var digits: String = content.substr(index, width)
			if digits.length() != width or not digits.is_valid_hex_number(false):
				return ""
			var codepoint: int = digits.hex_to_int()
			var surrogate: bool = codepoint >= 0xd800 and codepoint <= 0xdfff
			if (
				codepoint <= 0
				or codepoint > 0x10ffff
				or surrogate
			):
				return ""
			value += String.chr(codepoint)
			index += width
		elif escaped in [
			"\\",
			"'",
			"\"",
			"a",
			"b",
			"f",
			"n",
			"r",
			"t",
			"v",
		]:
			value += ("\\" + escaped).c_unescape()
		else:
			return ""
	return value
