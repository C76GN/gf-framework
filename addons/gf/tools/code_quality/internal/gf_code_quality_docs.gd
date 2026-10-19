# Checks declaration documentation and optional section headings on the shared, inert source model.
extends RefCounted


# --- 常量 ---

## 返回稳定文档规则集合，严重级别由调用方配置。
## [br]
## @api private
const _RULE_IDS: PackedStringArray = [
	"doc_public_summary",
	"doc_private_summary",
	"doc_parameters",
	"doc_return",
	"doc_tags",
	"section_order",
]

## 声明关键字仅从 lexer 的真实代码 token 中识别。
## [br]
## @api private
const _DECLARATION_KINDS: PackedStringArray = [
	"class_name",
	"class",
	"func",
	"signal",
	"enum",
	"const",
	"var",
]

## 单个文档分析结果的硬上限，达到时保留不可关闭的预算失败。
## [br]
## @api private
const _MAX_DIAGNOSTICS: int = 10_000


# --- 框架内部方法 ---

## 检查共享源码视图中的真实类成员，不加载或执行目标脚本。
## [br]
## @api framework_internal
## [br]
## @param view: 共享词法器生成的闭合源码视图。
## [br]
## @schema view: Dictionary，沿用 lex_source 视图；读取 complete、tokens、comments、groups 和 statements。
## [br]
## @param options: 宿主传入的规则级别，关闭规则不占用诊断预算。
## [br]
## @schema options: Dictionary，可选 rule_levels: Dictionary[String, String]；off 不产出规则诊断，省略时检查全部文档规则；严重级别由宿主添加。
## [br]
## @return 只包含规则、位置和说明的文档诊断。
## [br]
## @schema return: Array[Dictionary]，每项含 rule、line、column、message，可选 suggestion；位置从 1 开始。
static func analyze(view: Dictionary, options: Dictionary = {}) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if view.get("complete", false) != true:
		return findings
	var levels: Dictionary = _record(options.get("rule_levels", {}))
	var declarations: Array[Dictionary] = _collect_declarations(view)
	for declaration: Dictionary in declarations:
		if _budget_exhausted(findings):
			return findings
		_analyze_declaration(
			declaration,
			findings,
			levels
		)
	if _budget_exhausted(findings):
		return findings
	_analyze_sections(
		view,
		declarations,
		findings,
		levels
	)
	return findings


## 提供可独立设置严重级别的文档规则名副本。
## [br]
## @api framework_internal
## [br]
## @return 本 analyzer 能产生的稳定规则名。
static func get_rule_ids() -> PackedStringArray:
	return _RULE_IDS.duplicate()


# --- 私有/辅助方法 ---

## 只收集文件或内部类的直接成员，排除函数、属性访问器及控制流局部声明。
## [br]
## @api private
static func _collect_declarations(view: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tokens: Array = _array(view, "tokens")
	var statements: Array = _array(view, "statements")
	var comments: Dictionary = _comments_by_line(view)
	var value_returns: Dictionary = _value_return_owners(statements, tokens)
	var groups: Dictionary = {}
	for group_value: Variant in _array(view, "groups"):
		var group: Dictionary = _record(group_value)
		groups[
			_integer(
				group,
				"open_index",
				-1
			)
		] = group
	var native_bases: Dictionary = {}
	for statement_index: int in statements.size():
		var statement: Dictionary = _record(statements[statement_index])
		var owner: int = _integer(
			statement,
			"owner_index",
			-1
		)
		if not _is_class_scope(
			owner,
			statements,
			tokens
		):
			continue
		var declaration_index: int = _declaration_token(statement, tokens)
		if declaration_index < 0 or declaration_index + 1 >= tokens.size():
			continue
		var token: Dictionary = _record(tokens[declaration_index])
		var kind: String = _text(token)
		var declaration_name: String = _text(_record(tokens[declaration_index + 1]))
		if kind == "enum" and declaration_name == "{":
			declaration_name = "enum"
		var first_token: Dictionary = _record(tokens[_integer(statement, "start_index")])
		var anchor: int = _integer(
			first_token,
			"line",
			1
		)
		var indent_column: int = _integer(
			first_token,
			"column",
			1
		)
		var documentation: PackedStringArray = _bound_documentation(
			comments,
			anchor,
			indent_column
		)
		var previous: int = statement_index - 1
		while documentation.is_empty() and previous >= 0:
			var preceding: Dictionary = _record(statements[previous])
			if _integer(
				preceding,
				"owner_index",
				-1
			) != owner or not _is_member_annotation(preceding, tokens):
				break
			var preceding_last: Dictionary = _record(tokens[_integer(preceding, "end_index") - 1])
			if _integer(preceding_last, "end_line") != anchor - 1:
				break
			anchor = _integer(
				_record(tokens[_integer(preceding, "start_index")]),
				"line",
				anchor
			)
			documentation = _bound_documentation(
				comments,
				anchor,
				indent_column
			)
			previous -= 1
		var declaration: Dictionary = {
			"kind": kind,
			"name": declaration_name,
			"line": _integer(
				token,
				"line",
				1
			),
			"column": _integer(
				token,
				"column",
				1
			),
			"owner": owner,
			"indent_column": indent_column,
			"statement_index": statement_index,
			"documentation": documentation,
			"parameters": PackedStringArray(),
			"returns_value": false,
			"callback": false,
		}
		if kind in ["func", "signal"]:
			var signature: Dictionary = _signature(
				view,
				groups,
				statement,
				declaration_index,
				value_returns.has(statement_index)
			)
			declaration["parameters"] = signature["parameters"]
			declaration["returns_value"] = signature["returns_value"]
			if kind == "func":
				if not native_bases.has(owner):
					native_bases[owner] = _native_base(
						owner,
						statements,
						tokens
					)
				var native_base: StringName = native_bases[owner]
				declaration["callback"] = _is_native_callback(declaration_name, native_base)
		result.append(declaration)
		if kind == "enum":
			result.append_array(
				_enum_members(
					view,
					groups,
					declaration,
					declaration_index,
					comments
				)
			)
	return result


## 跳过行内注解的参数组后定位声明关键字，不把字符串或默认表达式当成员。
## [br]
## @api private
static func _declaration_token(statement: Dictionary, tokens: Array) -> int:
	var index: int = _integer(statement, "start_index")
	var end: int = _integer(statement, "end_index")
	var depth: int = 0
	while index < end and index < tokens.size():
		var token: Dictionary = _record(tokens[index])
		var text: String = _text(token)
		if text in [
			"(",
			"[",
			"{",
		]:
			depth += 1
		elif text in [
			")",
			"]",
			"}",
		]:
			depth -= 1
		elif (
			depth == 0
			and token.get("kind", "") == "name"
			and _DECLARATION_KINDS.has(text)
		):
			return index
		index += 1
	return -1


## 只有绑定单个成员的注解可以传递文档，文件和检查器分组元数据不归属后续声明。
## [br]
## @api private
static func _is_member_annotation(statement: Dictionary, tokens: Array) -> bool:
	var start: int = _integer(statement, "start_index")
	return (
		start + 1 < tokens.size()
		and _text(_record(tokens[start])) == "@"
		and _declaration_token(statement, tokens) < 0
		and not _text(_record(tokens[start + 1])) in [
			"tool",
			"icon",
			"static_unload",
			"export_category",
			"export_group",
			"export_subgroup",
		]
	)


## 共享 owner 链必须完全由内部类组成，才能属于真实类成员作用域。
## [br]
## @api private
static func _is_class_scope(
	owner: int,
	statements: Array,
	tokens: Array
) -> bool:
	var remaining: int = statements.size() + 1
	while (
		owner >= 0
		and owner < statements.size()
		and remaining > 0
	):
		var parent: Dictionary = _record(statements[owner])
		var declaration: int = _declaration_token(parent, tokens)
		if declaration < 0 or _text(_record(tokens[declaration])) != "class":
			return false
		owner = _integer(
			parent,
			"owner_index",
			-1
		)
		remaining -= 1
	return owner == -1


## 按行索引 lexer 已识别的注释，字符串内容不会进入该索引。
## [br]
## @api private
static func _comments_by_line(view: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in _array(view, "comments"):
		var comment: Dictionary = _record(value)
		result[_integer(comment, "line")] = comment
	return result


## 只绑定紧邻声明或其注解组、且缩进相同的连续文档注释。
## [br]
## @api private
static func _bound_documentation(
	comments: Dictionary,
	anchor: int,
	column: int
) -> PackedStringArray:
	var result: PackedStringArray = []
	var line: int = anchor - 1
	while comments.has(line):
		var comment: Dictionary = _record(comments[line])
		var text: String = _text(comment)
		if not text.begins_with("##") or _integer(
			comment,
			"column",
			1
		) != column:
			break
		var _insert_result: int = result.insert(
			0,
			text.substr(2).strip_edges()
		)
		line -= 1
	return result


## 使用共享括号组提取有序参数，嵌套默认值和多行签名不参与按逗号误切。
## [br]
## @api private
static func _signature(
	view: Dictionary,
	groups: Dictionary,
	statement: Dictionary,
	declaration_index: int,
	inferred_return: bool
) -> Dictionary:
	var parameters: PackedStringArray = []
	var tokens: Array = _array(view, "tokens")
	var end: int = _integer(
		statement,
		"header_end_index",
		_integer(statement, "end_index")
	)
	var opening: int = declaration_index + 2
	var group: Dictionary = _record(groups.get(opening, {}))
	var closing: int = _integer(
		group,
		"close_index",
		opening
	)
	for item_value: Variant in _array(group, "items"):
		if item_value is Vector2i:
			var item: Vector2i = item_value
			if item.x < item.y and item.x < tokens.size():
				var _append_result: bool = parameters.append(_text(_record(tokens[item.x])))
	var returns_value: bool = inferred_return
	for index: int in range(
		end,
		mini(
			_integer(statement, "end_index") - 1,
			tokens.size() - 1
		)
	):
		if _text(_record(tokens[index])) == "return":
			returns_value = true
	for index: int in range(
		closing + 1,
		mini(
			end - 1,
			tokens.size() - 1
		)
	):
		if _text(_record(tokens[index])) == "->":
			returns_value = _text(_record(tokens[index + 1])) != "void"
			break
	return { "parameters": parameters, "returns_value": returns_value }


## 枚举项也是类级具名成员，其说明只绑定到项自身而不继承枚举摘要。
## [br]
## @api private
static func _enum_members(
	view: Dictionary,
	groups: Dictionary,
	declaration: Dictionary,
	declaration_index: int,
	comments: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var tokens: Array = _array(view, "tokens")
	var opening: int = declaration_index + 1
	if _text(_record(tokens[opening])) != "{":
		opening += 1
	var group: Dictionary = _record(groups.get(opening, {}))
	for item_value: Variant in _array(group, "items"):
		if not item_value is Vector2i:
			continue
		var item: Vector2i = item_value
		if item.x >= item.y or item.x >= tokens.size():
			continue
		var token: Dictionary = _record(tokens[item.x])
		result.append(
			{
				"kind": "enum_value",
				"name": _text(token),
				"line": _integer(
					token,
					"line",
					1
				),
				"column": _integer(
					token,
					"column",
					1
				),
				"owner": declaration["statement_index"],
				"documentation": _bound_documentation(
					comments,
					_integer(
						token,
						"line",
						1
					),
					_integer(
						token,
						"column",
						1
					)
				),
			}
		)
	return result


## 无显式返回类型时仅依据所属函数的真实 return 语句推断值返回，跳过嵌套 lambda。
## [br]
## @api private
static func _value_return_owners(statements: Array, tokens: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in statements:
		var statement: Dictionary = _record(value)
		var start: int = _integer(statement, "start_index")
		if (
			start >= tokens.size()
			or _text(_record(tokens[start])) != "return"
			or _integer(statement, "end_index") <= start + 1
		):
			continue
		var owner: int = _integer(
			statement,
			"owner_index",
			-1
		)
		var remaining: int = statements.size() + 1
		while (
			owner >= 0
			and owner < statements.size()
			and remaining > 0
		):
			var parent: Dictionary = _record(statements[owner])
			var end: int = mini(
				_integer(
					parent,
					"header_end_index",
					_integer(parent, "end_index")
				),
				tokens.size()
			)
			var found_function: bool = false
			for index: int in range(
				_integer(parent, "start_index"),
				end
			):
				if _text(_record(tokens[index])) == "func":
					found_function = true
					if _declaration_token(parent, tokens) == index:
						result[owner] = true
					break
			if found_function:
				break
			owner = _integer(
				parent,
				"owner_index",
				-1
			)
			remaining -= 1
	return result


## 仅向 ClassDB 查询可信原生基类；不解析或加载目标项目的继承脚本。
## [br]
## @api private
static func _native_base(
	owner: int,
	statements: Array,
	tokens: Array
) -> StringName:
	var candidates: Array = statements if owner < 0 else [statements[owner]]
	for value: Variant in candidates:
		var statement: Dictionary = _record(value)
		if owner < 0 and _integer(
			statement,
			"owner_index",
			-1
		) >= 0:
			continue
		var start: int = _integer(statement, "start_index")
		var end: int = mini(
			_integer(
				statement,
				"header_end_index",
				_integer(statement, "end_index")
			),
			tokens.size()
		)
		for index: int in range(
			start,
			end - 1
		):
			if _text(_record(tokens[index])) == "extends":
				var candidate: StringName = StringName(_text(_record(tokens[index + 1])))
				if ClassDB.class_exists(candidate):
					return candidate
				return &"RefCounted"
	return &"RefCounted"


## 构造器和可信原生虚方法只要求回调职责，不套用对外参数完整性要求。
## [br]
## @api private
static func _is_native_callback(method_name: String, native_base: StringName) -> bool:
	if method_name == "_init":
		return true
	for method: Dictionary in ClassDB.class_get_method_list(native_base):
		if method.get("name", "") == method_name and (_integer(method, "flags") & METHOD_FLAG_VIRTUAL) != 0:
			return true
	return false


## 每个绑定文档分别验证职责、参数、返回说明和已出现标签，不要求 GF 专属标签存在。
## [br]
## @api private
static func _analyze_declaration(
	declaration: Dictionary,
	findings: Array[Dictionary],
	levels: Dictionary
) -> void:
	var documentation: PackedStringArray = declaration["documentation"]
	var tags: Dictionary = _parse_documentation(documentation)
	var api: String = _first_tag(tags, "api")
	var is_private: bool = (
		api == "private"
		or (
			api.is_empty()
			and _text(declaration, "name").begins_with("_")
		)
	)
	var callback: bool = declaration.get("callback", false) == true
	if callback:
		is_private = true
	if _first_tag(tags, "summary").is_empty():
		_add(
			findings,
			levels,
			"doc_private_summary" if is_private else "doc_public_summary",
			declaration,
			"声明缺少简短职责说明。",
			"在声明及其注解之前添加说明用途和约束的 ## 注释。"
		)
	_analyze_tags(
		declaration,
		tags,
		findings,
		levels
	)
	if _budget_exhausted(findings) or not _text(declaration, "kind") in ["func", "signal"]:
		return
	var parameters: PackedStringArray = declaration["parameters"]
	var documented: Array = _array(tags, "param")
	var seen: PackedStringArray = []
	var previous_index: int = -1
	for value: Variant in documented:
		if _budget_exhausted(findings):
			return
		var text: String = value
		var separator: int = text.find(":")
		var name: String = text.substr(0, separator).strip_edges() if separator >= 0 else text.strip_edges()
		var description: String = text.substr(separator + 1).strip_edges() if separator >= 0 else ""
		var parameter_index: int = parameters.find(name)
		if (
			parameter_index < 0
			or seen.has(name)
			or parameter_index <= previous_index
			or description.is_empty()
		):
			_add(
				findings,
				levels,
				"doc_parameters",
				declaration,
				"@param 必须按签名顺序描述真实且不重复的参数，并提供非空说明。"
			)
		var _append_result: bool = seen.append(name)
		previous_index = parameter_index
	if (
		not is_private
		and not callback
		and seen != parameters
	):
		_add(
			findings,
			levels,
			"doc_parameters",
			declaration,
			"对外入口需要按签名完整说明参数。"
		)
	var returns: Array = _array(tags, "return")
	var returns_value: bool = declaration.get("returns_value", false) == true
	if (
		returns.size() > 1
		or (
			returns.size() == 1
			and _first_tag(tags, "return").is_empty()
		)
	):
		_add(
			findings,
			levels,
			"doc_return",
			declaration,
			"@return 说明必须唯一且非空。"
		)
	elif not returns.is_empty() and not returns_value:
		_add(
			findings,
			levels,
			"doc_return",
			declaration,
			"无返回值的声明不应包含 @return 标签。"
		)
	elif (
		returns_value
		and not is_private
		and not callback
		and returns.is_empty()
	):
		_add(
			findings,
			levels,
			"doc_return",
			declaration,
			"对外入口需要说明返回值及失败约定。"
		)


## 连续正文绑定到参数等说明标签；单行元标签之后仍可写摘要，并排除示例代码块。
## [br]
## @api private
static func _parse_documentation(documentation: PackedStringArray) -> Dictionary:
	var tags: Dictionary = {}
	var summary: PackedStringArray = []
	var in_code: bool = false
	var active_tag: String = ""
	for line: String in documentation:
		if (
			line.begins_with("```")
			or line.begins_with("[codeblock")
			or line == "[/codeblock]"
		):
			in_code = not in_code
			continue
		if in_code:
			continue
		if line.begins_with("@"):
			var space: int = line.find(" ")
			var tab: int = line.find("\t")
			if (
				tab >= 0
				and (
					space < 0
					or tab < space
				)
			):
				space = tab
			var key: String = line.substr(
				1,
				space - 1
			) if space >= 0 else line.substr(1)
			var value: String = line.substr(space + 1).strip_edges() if space >= 0 else ""
			if not tags.has(key):
				tags[key] = []
			var values: Array = tags[key]
			values.append(value)
			active_tag = "" if key in [
				"api",
				"since",
				"layer",
				"category",
			] else key
		elif not line.is_empty() and line != "[br]":
			if active_tag.is_empty():
				var _append_result: bool = summary.append(line)
			else:
				var values: Array = tags[active_tag]
				var previous: String = values[-1]
				values[-1] = (previous + " " + line).strip_edges()
	tags["summary"] = [" ".join(summary)]
	return tags


## 只约束已有元标签的非空、唯一和可见性值，不引入默认必填或自定义标签禁令。
## [br]
## @api private
static func _analyze_tags(
	declaration: Dictionary,
	tags: Dictionary,
	findings: Array[Dictionary],
	levels: Dictionary
) -> void:
	for key: String in [
		"api",
		"since",
		"layer",
		"category",
	]:
		if _budget_exhausted(findings):
			return
		var values: Array = _array(tags, key)
		if (
			values.size() > 1
			or (
				values.size() == 1
				and _first_tag(tags, key).is_empty()
			)
		):
			_add(
				findings,
				levels,
				"doc_tags",
				declaration,
				"已有 @%s 标签必须唯一且非空。" % key
			)
	var api: String = _first_tag(tags, "api")
	if not api.is_empty() and not api in [
		"public",
		"protected",
		"private",
		"framework_internal",
		"layer_internal",
	]:
		_add(
			findings,
			levels,
			"doc_tags",
			declaration,
			"@api 可见性值无法识别。"
		)
	if (
		not _text(declaration, "kind") in ["func", "signal"]
		and (
			tags.has("param")
			or tags.has("return")
		)
	):
		_add(
			findings,
			levels,
			"doc_tags",
			declaration,
			"参数和返回标签只能绑定到函数或信号。"
		)


## 只校验实际存在的通用章节顺序；缺少章节和 GF 生命周期章节均不构成错误。
## [br]
## @api private
static func _analyze_sections(
	view: Dictionary,
	declarations: Array[Dictionary],
	findings: Array[Dictionary],
	levels: Dictionary
) -> void:
	if not _rule_enabled(levels, "section_order"):
		return
	var columns: Dictionary = {}
	for value: Variant in _array(view, "comments"):
		var comment: Dictionary = _record(value)
		var column: int = _integer(
			comment,
			"column",
			1
		)
		if not columns.has(column):
			columns[column] = []
		var column_comments: Array = columns[column]
		column_comments.append(comment)
	var scopes: Dictionary = {}
	for declaration: Dictionary in declarations:
		var owner: int = _integer(
			declaration,
			"owner",
			-1
		)
		if not scopes.has(owner):
			scopes[owner] = []
		var members: Array = scopes[owner]
		members.append(declaration)
	for owner_value: Variant in scopes:
		if _budget_exhausted(findings):
			return
		var owner: int = owner_value
		var members: Array = scopes[owner]
		var first: Dictionary = _record(members[0])
		var column: int = _integer(
			first,
			"indent_column",
			_integer(
				first,
				"column",
				1
			)
		)
		var comments: Array = _array(columns, column)
		var start_line: int = _scope_start_line(view, owner)
		var previous_rank: int = -1
		var comment_index: int = 0
		var current_rank: int = -1
		for member_value: Variant in members:
			if _budget_exhausted(findings):
				return
			var member: Dictionary = _record(member_value)
			while comment_index < comments.size():
				if _budget_exhausted(findings):
					return
				var comment: Dictionary = _record(comments[comment_index])
				if _integer(comment, "line") >= _integer(member, "line"):
					break
				comment_index += 1
				if _integer(comment, "line") <= start_line:
					continue
				var rank: int = _section_rank(_text(comment))
				if rank < 0:
					continue
				if rank < previous_rank:
					_add(
						findings,
						levels,
						"section_order",
						comment,
						"已出现的通用章节发生顺序回退。"
					)
				previous_rank = rank
				current_rank = rank
			if _text(member, "kind") == "func":
				var is_private: bool = _text(member, "name").begins_with("_")
				if (
					(
						is_private
						and current_rank == 8
						and member.get("callback", false) != true
					)
					or (
						not is_private
						and current_rank == 11
					)
				):
					_add(
						findings,
						levels,
						"section_order",
						member,
						"函数可见性与当前公共或私有方法章节不一致。"
					)
			elif _text(member, "kind") == "var":
				var private_variable: bool = _text(member, "name").begins_with("_")
				if (
					(
						private_variable
						and current_rank == 4
					)
					or (
						not private_variable
						and current_rank == 5
					)
				):
					_add(
						findings,
						levels,
						"section_order",
						member,
						"变量可见性与当前公共或私有变量章节不一致。"
					)
		var end_line: int = _scope_end_line(view, owner)
		while comment_index < comments.size():
			if _budget_exhausted(findings):
				return
			var comment: Dictionary = _record(comments[comment_index])
			if _integer(comment, "line") >= end_line:
				break
			comment_index += 1
			var rank: int = _section_rank(_text(comment))
			if rank < 0:
				continue
			if rank < previous_rank:
				_add(
					findings,
					levels,
					"section_order",
					comment,
					"已出现的通用章节发生顺序回退。"
				)
			previous_rank = rank


## 内部类的章节不能继承其声明之前的同缩进注释。
## [br]
## @api private
static func _scope_start_line(view: Dictionary, owner: int) -> int:
	if owner < 0:
		return 0
	var statements: Array = _array(view, "statements")
	var tokens: Array = _array(view, "tokens")
	var statement: Dictionary = _record(statements[owner])
	return _integer(
		_record(tokens[_integer(statement, "start_index")]),
		"line"
	)


## 以下一个同级 statement 约束内部类的章节范围，根作用域覆盖整个文件。
## [br]
## @api private
static func _scope_end_line(view: Dictionary, owner: int) -> int:
	if owner < 0:
		return 2_147_483_647
	var statements: Array = _array(view, "statements")
	var tokens: Array = _array(view, "tokens")
	var indent: int = _integer(
		_record(statements[owner]),
		"indent"
	)
	for index: int in range(
		owner + 1,
		statements.size()
	):
		var statement: Dictionary = _record(statements[index])
		if _integer(statement, "indent") <= indent:
			return _integer(
				_record(tokens[_integer(statement, "start_index")]),
				"line"
			)
	return 2_147_483_647


## 识别已有中英文章节基名；未知自定义标题不被强制改成 GF 专有名称。
## [br]
## @api private
static func _section_rank(text: String) -> int:
	if not text.begins_with("# ---") or not text.ends_with("---"):
		return -1
	var label: String = text.substr(
		5,
		text.length() - 8
	).strip_edges().to_lower()
	var categories: Array[PackedStringArray] = [
		["信号", "signals"],
		["枚举", "enums"],
		["常量", "constants"],
		[
			"导出变量",
			"export",
			"@export",
		],
		["公共变量", "public variables"],
		["私有变量", "private variables"],
		["@onready", "onready"],
		[
			"godot 生命周期",
			"godot 回调",
			"生命周期",
			"lifecycle",
			"callbacks",
			"gf 生命周期",
		],
		["公共方法", "public methods"],
		[
			"可重写钩子",
			"protected",
			"hooks",
		],
		[
			"框架内部方法",
			"层内方法",
			"internal methods",
		],
		[
			"私有/辅助方法",
			"private helpers",
			"private methods",
		],
		[
			"信号处理函数",
			"信号回调函数",
			"signal callbacks",
		],
		[
			"内部类",
			"inner classes",
			"subclasses",
		],
	]
	var best_rank: int = -1
	var best_length: int = 0
	for rank: int in categories.size():
		for marker: String in categories[rank]:
			if label.begins_with(marker) and marker.length() > best_length:
				best_rank = rank
				best_length = marker.length()
	return best_rank


## 只产出启用规则的诊断，达到硬上限时以唯一预算失败替代最后一项。
## [br]
## @api private
static func _add(
	findings: Array[Dictionary],
	levels: Dictionary,
	rule: String,
	position: Dictionary,
	message: String,
	suggestion: String = ""
) -> void:
	if not _rule_enabled(levels, rule) or _budget_exhausted(findings):
		return
	var exhausted: bool = findings.size() == _MAX_DIAGNOSTICS - 1
	var finding: Dictionary = {
		"rule": "analysis_budget" if exhausted else rule,
		"line": _integer(
			position,
			"line",
			1
		),
		"column": _integer(
			position,
			"column",
			1
		),
		"message": "文档诊断达到 10000 项上限，检查未完成。" if exhausted else message,
	}
	if not exhausted and not suggestion.is_empty():
		finding["suggestion"] = suggestion
	findings.append(finding)


## 规则关闭只影响该规则的诊断，预算失败始终保留。
## [br]
## @api private
static func _rule_enabled(levels: Dictionary, rule: String) -> bool:
	return rule == "analysis_budget" or levels.get(rule, "error") != "off"


## 所有产出入口都遵守同一上限，循环可以立即停止后续分析。
## [br]
## @api private
static func _budget_exhausted(findings: Array[Dictionary]) -> bool:
	return findings.size() >= _MAX_DIAGNOSTICS


## 收窄源码模型中的对象记录，畸形项按空记录处理。
## [br]
## @api private
static func _record(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## 收窄数组字段，避免在 Variant 上调用集合方法。
## [br]
## @api private
static func _array(record: Dictionary, key: Variant) -> Array:
	var value: Variant = record.get(key, [])
	return value if value is Array else []


## 读取词法文本或字符串模型字段。
## [br]
## @api private
static func _text(record: Dictionary, key: String = "text") -> String:
	var value: Variant = record.get(key, "")
	return value if value is String else ""


## 读取模型中的整数位置，保留调用方提供的缺省值。
## [br]
## @api private
static func _integer(
	record: Dictionary,
	key: String,
	fallback: int = 0
) -> int:
	var value: Variant = record.get(key, fallback)
	return value if value is int else fallback


## 读取首个已经词法收集的标签值。
## [br]
## @api private
static func _first_tag(tags: Dictionary, key: String) -> String:
	var values: Array = _array(tags, key)
	if values.is_empty():
		return ""
	var value: Variant = values[0]
	return value if value is String else ""
