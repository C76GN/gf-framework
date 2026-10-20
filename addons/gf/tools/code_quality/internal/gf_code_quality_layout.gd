# 基于共享词法/块视图的只读结构布局检查，不生成补丁或写回源码。
extends RefCounted


# --- 常量 ---

## 诊断上限防止不合规大文件产生无界报告。
## [br]
## @api private
const _MAX_DIAGNOSTICS: int = 20_000

## 布局规则使用稳定 ID，入口负责应用项目严重级别。
## [br]
## @api private
const _RULES: PackedStringArray = [
	"text_format",
	"statement_separator",
	"inline_body",
	"list_layout",
	"declaration_parameter_layout",
	"annotation_parameter_layout",
	"annotation_binding_layout",
	"enum_layout",
	"dictionary_entry_layout",
	"dictionary_spacing",
	"trailing_comma",
	"multiline_items",
	"closing_delimiter",
	"continuation_indentation",
	"condition_layout",
	"nested_ternary",
	"simple_string_layout",
	"simple_format_layout",
	"format_layout",
	"argument_group_layout",
	"call_group_layout",
	"atomic_group_layout",
	"cast_layout",
	"expression_layout",
	"index_layout",
	"chain_layout",
	"token_spacing",
	"suite_indentation",
	"section_spacing",
	"definition_spacing",
	"member_block_spacing",
	"member_doc_binding",
	"match_pattern_layout",
	"lambda_argument_separator",
]

## 真实二元 token 与标点角色分别处理，避免破坏节点路径和一元运算。
## [br]
## @api private
const _BINARY: PackedStringArray = [
	"=",
	":=",
	"+=",
	"-=",
	"*=",
	"/=",
	"%=",
	"**=",
	"<<=",
	">>=",
	"&=",
	"|=",
	"^=",
	"+",
	"-",
	"*",
	"/",
	"%",
	"**",
	"<<",
	">>",
	"&",
	"|",
	"^",
	"==",
	"!=",
	"<",
	">",
	"<=",
	">=",
	"&&",
	"||",
	"->",
]

## 字段注解与声明绑定；文件和分组元数据不套用字段规则。
## [br]
## @api private
const _FIELD_ANNOTATIONS: PackedStringArray = [
	"export",
	"export_range",
	"export_enum",
	"export_flags",
	"export_exp_easing",
	"export_file",
	"export_dir",
	"export_global_file",
	"export_global_dir",
	"export_multiline",
	"export_placeholder",
	"export_color_no_alpha",
	"export_node_path",
	"export_storage",
	"export_custom",
	"export_tool_button",
	"export_flags_2d_render",
	"export_flags_3d_render",
	"export_flags_2d_physics",
	"export_flags_3d_physics",
	"export_flags_2d_navigation",
	"export_flags_3d_navigation",
	"onready",
]


# --- 框架内部方法 ---

## 返回本检查器实际执行的稳定规则，供配置准入和报告覆盖使用。
## [br]
## @api framework_internal
## [br]
## @return 布局规则 ID 的独立副本。
static func get_rule_ids() -> PackedStringArray:
	return _RULES.duplicate()


## 依结构检查完整词法视图；不完整输入只转交原失败，不猜测后续布局。
## [br]
## @api framework_internal
## [br]
## @param view: gf_code_quality_source.lex_source 返回的完整视图。
## [br]
## @param options: 最大同行项数、章节前空行和定义间空行配置。
## [br]
## @return 只读诊断，不包含源码改写或执行结果。
## [br]
## @schema view: Dictionary，必须具有 complete、source、lines、tokens、comments、groups、statements 和 diagnostics 字段。
## [br]
## @schema options: Dictionary，可选 max_inline_items、section_blank_lines_before 和 definition_blank_lines，默认分别为 2、2、2；内部 rule_levels 为已准入的规则严重级别字典，off 规则不占诊断预算。
## [br]
## @schema return: Array[Dictionary]，每项具有 rule、line、column、message，可选 suggestion。
static func analyze(view: Dictionary, options: Dictionary = {}) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	if not _boolean(view.get("complete", false)):
		for issue: Dictionary in view.get("diagnostics", []):
			diagnostics.append(issue.duplicate(true))
		return diagnostics
	var context: Dictionary = _context(view, options)
	_check_text(context, diagnostics)
	_check_statements(context, diagnostics)
	_plan_groups(context)
	_check_expressions(context, diagnostics)
	_check_groups(context, diagnostics)
	_check_spacing(context, diagnostics)
	_check_member_spacing(context, diagnostics)
	return diagnostics


# --- 私有/辅助方法 ---

## 内部视图的整数先作类型收窄，避免 Variant 直接参与索引或有类型调用。
## [br]
## @api private
static func _integer(value: Variant) -> int:
	if value is int:
		return value
	return 0


## 配置和词法完成标记只接受真实 bool，其他值不视为开启。
## [br]
## @api private
static func _boolean(value: Variant) -> bool:
	if value is bool:
		return value
	return false


## 内部结构字段经类型收窄后才能调用 Dictionary 方法。
## [br]
## @api private
static func _dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


## 清单字段保留原数组引用，只收窄调用类型而不复制或改变元素。
## [br]
## @api private
static func _array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


## 将共享视图中的半开 token 边界收窄成有类型的跨度。
## [br]
## @api private
static func _span(start: Variant, ending: Variant) -> Vector2i:
	return Vector2i(
		_integer(start),
		_integer(ending)
	)


## 同一文件只构建一次 owner/位置索引，规则不重复扫描原始字符串。
## [br]
## @api private
static func _context(view: Dictionary, options: Dictionary) -> Dictionary:
	var original_groups: Array[Dictionary] = view["groups"]
	var groups: Array[Dictionary] = original_groups.duplicate(true)
	var tokens: Array[Dictionary] = view["tokens"]
	var openings: Dictionary = {}
	var closings: Dictionary = {}
	var nested_containers: Dictionary = {}
	for index: int in groups.size():
		openings[groups[index]["open_index"]] = index
		closings[groups[index]["close_index"]] = index
	var first_by_line: Dictionary = {}
	var node_tokens: Dictionary = {}
	var statement_starts: Dictionary = {}
	var lambda_starts: PackedInt32Array = []
	var lambda_by_parent: Dictionary = {}
	var ordered_starts: PackedInt32Array = []
	for statement: Dictionary in view["statements"]:
		statement_starts[statement["start_index"]] = true
		var _packed_append_1: bool = ordered_starts.append(_integer(statement["start_index"]))
		if statement["kind"] == "lambda":
			var _packed_append_2: bool = lambda_starts.append(_integer(statement["start_index"]))
			var parent: int = statement["lexical_parent"]
			if not lambda_by_parent.has(parent):
				lambda_by_parent[parent] = []
			_array(lambda_by_parent[parent]).append(statement)
	for index: int in tokens.size():
		var token: Dictionary = tokens[index]
		if not first_by_line.has(token["line"]):
			first_by_line[token["line"]] = index
		if token["kind"] != "symbol" or token["text"] not in ["$", "%"]:
			continue
		if (
			token["text"] == "%"
			and not statement_starts.has(index)
			and _operand(
				tokens,
				index - 1,
				node_tokens
			)
		):
			continue
		node_tokens[index] = true
		var cursor: int = index + 1
		var expect_segment: bool = true
		while cursor < tokens.size() and tokens[cursor]["line"] == token["line"]:
			var segment: Dictionary = tokens[cursor]
			if segment["text"] == "%" and expect_segment:
				pass
			elif segment["text"] in ["/", ":"]:
				if (
					segment["text"] == ":"
					and (
						cursor + 1 >= tokens.size()
						or tokens[cursor + 1]["start"] != segment["end"]
					)
				):
					break
				expect_segment = true
			elif segment["kind"] in [
				"name",
				"number",
				"string",
			] and expect_segment:
				expect_segment = false
			else:
				break
			node_tokens[cursor] = true
			cursor += 1
	for group: Dictionary in groups:
		var opening: int = group["open_index"]
		if opening > 0 and node_tokens.has(opening - 1):
			if tokens[opening]["text"] == "[":
				group["kind"] = "index"
			elif tokens[opening]["text"] == "(":
				group["kind"] = "call"
	for index: int in groups.size():
		if groups[index]["kind"] in ["array", "dictionary"] and not _array(groups[index]["items"]).is_empty():
			var parent: int = groups[index]["parent_index"]
			while parent >= 0:
				nested_containers[parent] = true
				parent = groups[parent]["parent_index"]
	var comment_starts: PackedInt32Array = []
	var comment_lines: Dictionary = {}
	var lines: PackedStringArray = view["lines"]
	for comment: Dictionary in view["comments"]:
		var _packed_append_3: bool = comment_starts.append(_integer(comment["start"]))
		if _integer(comment["column"]) == _prefix_length(lines[_integer(comment["line"]) - 1]) + 1:
			comment_lines[comment["line"]] = comment["text"]
	var rule_levels: Dictionary = options.get("rule_levels", {})
	return {
		"view": view,
		"tokens": tokens,
		"groups": groups,
		"openings": openings,
		"closings": closings,
		"first_by_line": first_by_line,
		"node_tokens": node_tokens,
		"comment_starts": comment_starts,
		"comment_lines": comment_lines,
		"states": {},
		"nested_containers": nested_containers,
		"boolean_counts": {},
		"expanded_boolean_domains": {},
		"expanded_conditional_domains": {},
		"value_domains": {},
		"lambda_starts": lambda_starts,
		"lambda_by_parent": lambda_by_parent,
		"ordered_starts": ordered_starts,
		"max_inline": _integer(options.get("max_inline_items", 2)),
		"section_blanks": _integer(options.get("section_blank_lines_before", 2)),
		"definition_blanks": _integer(options.get("definition_blank_lines", 2)),
		"seen": {},
		"rule_levels": rule_levels,
	}


## 只检查结构行的缩进与尾空格，跨行字符串的真实载荷不会作为代码。
## [br]
## @api private
static func _check_text(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var view: Dictionary = context["view"]
	var source: String = view["source"]
	var lines: PackedStringArray = view["lines"]
	var comment_lines: Dictionary = context["comment_lines"]
	if source.begins_with("\uFEFF"):
		_add(
			context,
			diagnostics,
			"text_format",
			1,
			1,
			"UTF-8 BOM is not allowed."
		)
	if source.contains("\r"):
		_add(
			context,
			diagnostics,
			"text_format",
			1,
			1,
			"Use LF line endings."
		)
	if not source.is_empty() and not source.ends_with("\n"):
		_add(
			context,
			diagnostics,
			"text_format",
			maxi(
				1,
				lines.size()
			),
			1,
			"End source with LF."
		)
	var literal_prefix_lines: Dictionary = {}
	var literal_suffix_lines: Dictionary = {}
	for token: Dictionary in context["tokens"]:
		if token["kind"] == "string" and token["line"] != token["end_line"]:
			for line: int in range(
				_integer(token["line"]) + 1,
				_integer(token["end_line"]) + 1
			):
				literal_prefix_lines[line] = true
			for line: int in range(
				_integer(token["line"]),
				_integer(token["end_line"])
			):
				literal_suffix_lines[line] = true
	for index: int in lines.size():
		var line: String = lines[index]
		var prefix: String = line.substr(
			0,
			line.length() - line.strip_edges(true, false).length()
		)
		if (
			not literal_prefix_lines.has(index + 1)
			and prefix.contains(" ")
			and not line.strip_edges().is_empty()
		):
			_add(
				context,
				diagnostics,
				"text_format",
				index + 1,
				1,
				"Use Tabs for structural indentation."
			)
		if (
			(
				line.ends_with(" ")
				or line.ends_with("\t")
			)
			and not comment_lines.has(index + 1)
			and not literal_suffix_lines.has(index + 1)
		):
			_add(
				context,
				diagnostics,
				"text_format",
				index + 1,
				line.length(),
				"Remove trailing structural whitespace."
			)


## 正文归属和冒号由源码模型给出；没有依赖关键字正则或行长。
## [br]
## @api private
static func _check_statements(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var view: Dictionary = context["view"]
	var tokens: Array[Dictionary] = context["tokens"]
	var statements: Array[Dictionary] = view["statements"]
	for token: Dictionary in tokens:
		if token["kind"] == "symbol" and token["text"] == ";":
			_at(
				context,
				diagnostics,
				"statement_separator",
				token,
				"Use one independent statement per line."
			)
	for statement: Dictionary in statements:
		var opening: int = statement["start_index"]
		var first: Dictionary = tokens[opening]
		var owner_index: int = statement["owner_index"]
		var expected: int = _integer(statements[owner_index]["indent"]) + 1 if owner_index >= 0 else 0
		if statement["kind"] != "lambda" and _integer(statement["indent"]) != expected:
			_at(
				context,
				diagnostics,
				"suite_indentation",
				first,
				"Indent a direct suite statement by exactly one Tab."
			)
		var header_end: int = statement["header_end_index"]
		if (
			_boolean(statement["block"])
			and header_end < _integer(statement["end_index"])
			and tokens[header_end]["line"] == tokens[header_end - 1]["line"]
		):
			_at(
				context,
				diagnostics,
				"inline_body",
				tokens[header_end],
				"Put a suite body on its own indented line."
			)
		if statement["kind"] == "as":
			_at(
				context,
				diagnostics,
				"cast_layout",
				first,
				"Attach a cast to its operand's closing line."
			)
		if (
			owner_index >= 0
			and statements[owner_index]["kind"] == "match"
			and _integer(first["line"]) != _integer(
				tokens[
					maxi(
						opening,
						header_end - 1
					)
				]["end_line"]
			)
		):
			for index: int in _direct(
				context,
				opening,
				header_end
			):
				var next_pattern: int = index + 1
				while next_pattern < header_end and tokens[next_pattern]["text"] == "\\":
					next_pattern += 1
				if (
					tokens[index]["text"] == ","
					and next_pattern < header_end
					and tokens[index]["end_line"] == tokens[next_pattern]["line"]
				):
					_at(
						context,
						diagnostics,
						"match_pattern_layout",
						tokens[next_pattern],
						"Keep one direct match pattern on each continued header line."
					)


## 先决定后代的规范布局，旧换行不能成为父级永久保留的理由。
## [br]
## @api private
static func _plan_groups(context: Dictionary) -> void:
	var groups: Array[Dictionary] = context["groups"]
	var states: Dictionary = context["states"]
	for number: int in range(
		groups.size() - 1,
		-1,
		-1
	):
		var group: Dictionary = groups[number]
		var opening: int = group["open_index"]
		var closing: int = group["close_index"]
		var kind: String = group["kind"]
		var items: Array = group["items"]
		if _barrier(
			context,
			opening,
			closing + 1
		):
			states[number] = "preserve"
			continue
		var expanded: bool = false
		if kind == "enum":
			expanded = not items.is_empty()
		elif kind in [
			"call",
			"parameters",
			"array",
			"dictionary",
		]:
			expanded = items.size() > _integer(context["max_inline"])
			if kind == "call" and items.size() == 2:
				for item: Vector2i in items:
					expanded = expanded or not _atomic(
						context,
						item.x,
						item.y
					)
			for item: Vector2i in items:
				var span: Vector2i = _value_span(
					context,
					item,
					kind
				)
				expanded = expanded or _span_expanded(
					context,
					span.x,
					span.y
				)
				if kind == "dictionary":
					var separator: int = _separator(
						context,
						item.x,
						item.y,
						[":", "="]
					)
					if separator >= 0:
						expanded = expanded or _span_expanded(
							context,
							item.x,
							separator
						)
			if kind in ["array", "dictionary"] and _dictionary(context["nested_containers"]).has(number):
				expanded = true
		elif kind in [
			"group",
			"index",
			"annotation",
		]:
			expanded = _span_expanded(
				context,
				opening + 1,
				closing
			)
			if (
				kind in ["group", "index"]
				and closing > opening + 1
				and context["tokens"][closing - 1]["text"] == ","
			):
				states[number] = "preserve"
				continue
		elif kind == "type_arguments":
			states[number] = "preserve"
			continue
		states[number] = "expanded" if expanded else "inline"


## 列表、表达式载体和索引采用同一后代计划，但保留各自逗号规则。
## [br]
## @api private
static func _check_groups(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var groups: Array[Dictionary] = context["groups"]
	var states: Dictionary = context["states"]
	for number: int in groups.size():
		var group: Dictionary = groups[number]
		var opening: int = group["open_index"]
		var closing: int = group["close_index"]
		var opener: Dictionary = tokens[opening]
		var closer: Dictionary = tokens[closing]
		var kind: String = group["kind"]
		var state: String = states[number]
		var multiline: bool = opener["line"] != closer["end_line"]
		var rule: String = "list_layout"
		if kind == "parameters":
			rule = "declaration_parameter_layout"
		elif kind == "annotation":
			rule = "annotation_parameter_layout"
		elif kind == "enum":
			rule = "enum_layout"
		elif kind == "group":
			rule = "atomic_group_layout" if _atomic(
				context,
				opening + 1,
				closing
			) else "expression_layout"
		elif kind in ["index", "type_arguments"]:
			rule = "index_layout"
		if state == "inline" and multiline:
			_at(
				context,
				diagnostics,
				rule,
				opener,
				"Keep this complete structural unit on one line."
			)
		if state == "expanded":
			var items: Array = group["items"]
			var previous_end: int = opener["end_line"]
			for item: Vector2i in items:
				if _integer(tokens[item.x]["line"]) <= previous_end:
					_at(
						context,
						diagnostics,
						rule,
						tokens[item.x],
						"Start each direct item below its opener or previous item."
					)
				previous_end = tokens[item.y - 1]["end_line"]
			if _integer(closer["line"]) <= previous_end:
				_at(
					context,
					diagnostics,
					"closing_delimiter",
					closer,
					"Close an expanded structural layer below its final item."
				)
		if state != "inline" and multiline:
			_check_expanded_indentation(
				context,
				group,
				diagnostics
			)
			var previous_item_end: int = opener["end_line"]
			for item: Vector2i in group["items"]:
				if (
					_integer(tokens[item.x]["line"]) <= previous_item_end
					and (
						tokens[item.x]["text"] != "\\"
						or kind != "group"
					)
				):
					_at(
						context,
						diagnostics,
						"multiline_items",
						tokens[item.x],
						"Keep each multiline direct item on its own line."
					)
				previous_item_end = tokens[item.y - 1]["end_line"]
			if (
				state == "preserve"
				and _integer(closer["line"]) <= previous_item_end
				and kind in [
					"call",
					"array",
					"dictionary",
					"enum",
				]
			):
				_at(
					context,
					diagnostics,
					"closing_delimiter",
					closer,
					"Close a multiline structural layer below its last item."
				)
				_at(
					context,
					diagnostics,
					"continuation_indentation",
					closer,
					"Align the multiline closing delimiter with its structural owner."
				)
		if (
			multiline
			and closing + 1 < tokens.size()
			and tokens[closing + 1]["line"] == closer["line"]
		):
			var suffix: String = tokens[closing + 1]["text"]
			if suffix not in [
				",",
				":",
				")",
				"]",
				"}",
				".",
				"[",
				"(",
				"as",
				"if",
				"else",
				"and",
				"or",
				"in",
				"is",
				"not",
			] and suffix not in _BINARY:
				_at(
					context,
					diagnostics,
					"closing_delimiter",
					closer,
					"Keep only a proven expression suffix on a multiline closing line."
				)
		if (
			kind in ["array", "dictionary"]
			and multiline
			and closing > opening + 1
			and tokens[closing - 1]["text"] != ","
		):
			_at(
				context,
				diagnostics,
				"trailing_comma",
				tokens[closing - 1],
				"Keep the final comma in a multiline container."
			)
		if kind == "dictionary":
			_check_dictionary(
				context,
				group,
				diagnostics
			)
		if kind == "call":
			for item: Vector2i in group["items"]:
				_check_argument_wrapper(
					context,
					item,
					diagnostics
				)
			if (
				_call_is_nested(context, number)
				and multiline
				and tokens[closing - 1]["text"] != ","
			):
				var items: Array = group["items"]
				if not items.is_empty():
					var final_item: Vector2i = items.back()
					for statement: Dictionary in _dictionary(context["lambda_by_parent"]).get(number, []):
						if (
							statement["kind"] == "lambda"
							and _integer(statement["start_index"]) >= final_item.x
							and _integer(statement["start_index"]) < final_item.y
							and _integer(statement["lexical_parent"]) == number
						):
							_at(
								context,
								diagnostics,
								"lambda_argument_separator",
								tokens[closing - 1],
								"Terminate a nested call's final multiline lambda argument with a comma."
							)
							break


## 展开层的直接项与闭合缩进一层；嵌套值从其自己的 opener 继续判断。
## [br]
## @api private
static func _check_expanded_indentation(
	context: Dictionary,
	group: Dictionary,
	diagnostics: Array[Dictionary]
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var lines: PackedStringArray = context["view"]["lines"]
	var opening: int = group["open_index"]
	var closing: int = group["close_index"]
	var base: int = _indent(lines[_integer(tokens[opening]["line"]) - 1])
	for item: Vector2i in group["items"]:
		var token: Dictionary = tokens[item.x]
		if (
			token["line"] != tokens[opening]["line"]
			and _first_on_line(context, item.x)
			and _indent(lines[_integer(token["line"]) - 1]) != base + 1
		):
			_at(
				context,
				diagnostics,
				"continuation_indentation",
				token,
				"Indent a direct continuation item by one Tab."
			)
	var closer: Dictionary = tokens[closing]
	if _first_on_line(context, closing) and _indent(lines[_integer(closer["line"]) - 1]) != base:
		_at(
			context,
			diagnostics,
			"continuation_indentation",
			closer,
			"Align the closing delimiter with its structural owner."
		)
	if (
		closing > 0
		and tokens[closing - 1]["text"] in [
			")",
			"]",
			"}",
		]
		and tokens[closing - 1]["end_line"] == closer["line"]
	):
		var other: int = _dictionary(context["closings"]).get(
			closing - 1,
			-1
		)
		if other >= 0 and context["states"][other] == "expanded":
			_at(
				context,
				diagnostics,
				"closing_delimiter",
				closer,
				"Give each expanded closing layer its own line."
			)


## 字典的键、分隔符和值开头始终同行；不吸收值内部的结构。
## [br]
## @api private
static func _check_dictionary(
	context: Dictionary,
	group: Dictionary,
	diagnostics: Array[Dictionary]
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var source: String = context["view"]["source"]
	var opening: int = group["open_index"]
	var closing: int = group["close_index"]
	for item: Vector2i in group["items"]:
		var separator: int = _separator(
			context,
			item.x,
			item.y,
			[":", "="]
		)
		if separator < 0 or separator + 1 >= item.y:
			continue
		if (
			tokens[item.x]["line"] == tokens[separator - 1]["end_line"]
			and not _barrier(
				context,
				item.x,
				separator + 2
			)
			and (
				tokens[item.x]["line"] != tokens[separator]["line"]
				or tokens[separator]["line"] != tokens[separator + 1]["line"]
			)
		):
			_at(
				context,
				diagnostics,
				"dictionary_entry_layout",
				tokens[separator],
				"Keep the dictionary key, separator and value's first token on one line."
			)
	if tokens[opening]["line"] == tokens[closing]["line"] and closing > opening + 1:
		var prefix: String = source.substr(
			_integer(tokens[opening]["end"]),
			_integer(tokens[opening + 1]["start"]) - _integer(tokens[opening]["end"])
		)
		var suffix: String = source.substr(
			_integer(tokens[closing - 1]["end"]),
			_integer(tokens[closing]["start"]) - _integer(tokens[closing - 1]["end"])
		)
		if prefix != " " or suffix != " ":
			_at(
				context,
				diagnostics,
				"dictionary_spacing",
				tokens[opening],
				"Use one inner space in a nonempty inline dictionary."
			)


## 完整参数已有续行载体时，拒绝多余的整段表达式 wrapper，保留优先级子组。
## [br]
## @api private
static func _check_argument_wrapper(
	context: Dictionary,
	item: Vector2i,
	diagnostics: Array[Dictionary]
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var number: int = _dictionary(context["openings"]).get(item.x, -1)
	if number < 0:
		return
	var group: Dictionary = context["groups"][number]
	if (
		group["kind"] != "group"
		or _integer(group["close_index"]) != item.y - 1
		or tokens[item.x]["line"] == tokens[item.y - 1]["line"]
		or _barrier(
			context,
			item.x,
			item.y
		)
	):
		return
	if (
		_boolean_count(
			context,
			item.x + 1,
			item.y - 1
		) > _integer(context["max_inline"])
		or _contains_direct(
			context,
			item.x + 1,
			item.y - 1,
			[
				"if",
				"func",
				"await",
				"as",
			]
		)
		or _contains_lambda(
			context,
			item.x,
			item.y
		)
	):
		return
	if not _atomic(
		context,
		item.x + 1,
		item.y - 1
	):
		_at(
			context,
			diagnostics,
			"argument_group_layout",
			tokens[item.x],
			"The whole argument already has the call's continuation carrier."
		)


## 每个完整表达式域独立计布尔/条件项，字典键值与参数默认值分别分析。
## [br]
## @api private
static func _check_expressions(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var domains: Array[Vector2i] = []
	for group: Dictionary in context["groups"]:
		if group["kind"] in ["enum", "type_arguments"]:
			continue
		for item: Vector2i in group["items"]:
			if group["kind"] == "dictionary":
				var separator: int = _separator(
					context,
					item.x,
					item.y,
					[":", "="]
				)
				if separator >= 0:
					domains.append(_span(item.x, separator))
					domains.append(
						_span(
							separator + 1,
							item.y
						)
					)
			elif group["kind"] == "parameters":
				var separator: int = _separator(
					context,
					item.x,
					item.y,
					["="]
				)
				if separator >= 0:
					domains.append(
						_span(
							separator + 1,
							item.y
						)
					)
			else:
				domains.append(item)
	for statement: Dictionary in context["view"]["statements"]:
		var span: Vector2i = _statement_value(context, statement)
		if span.x < span.y:
			domains.append(span)
			if statement["kind"] == "return" or _separator(
				context,
				_integer(statement["start_index"]),
				_integer(statement["header_end_index"]),
				["=", ":="]
			) >= 0:
				context["value_domains"][span] = true
	for domain: Vector2i in domains:
		if domain.x >= domain.y or _contains_direct(
			context,
			domain.x,
			domain.y,
			["func"]
		):
			continue
		_check_domain(
			context,
			domain,
			diagnostics
		)
	for index: int in tokens.size():
		if (
			_keyword(
				context,
				index,
				"as"
			)
			and index > 0
			and tokens[index - 1]["end_line"] != tokens[index]["line"]
			and not _barrier(
				context,
				index - 1,
				index + 1
			)
		):
			_at(
				context,
				diagnostics,
				"cast_layout",
				tokens[index],
				"Attach as Type to its operand's closing line."
			)
		if (
			tokens[index]["text"] == "."
			and tokens[index]["kind"] == "symbol"
			and index > 0
			and index + 1 < tokens.size()
			and (
				tokens[index - 1]["end_line"] != tokens[index]["line"]
				or tokens[index]["line"] != tokens[index + 1]["line"]
			)
			and not _barrier(
				context,
				index - 1,
				index + 2
			)
		):
			_at(
				context,
				diagnostics,
				"chain_layout",
				tokens[index],
				"Attach member access to its receiver's closing line."
			)


## 域分析不猜变量类型；只对可机械证明的字符串与语法运算提出布局要求。
## [br]
## @api private
static func _check_domain(
	context: Dictionary,
	domain: Vector2i,
	diagnostics: Array[Dictionary]
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var start: int = domain.x
	var ending: int = domain.y
	var physical_barrier: bool = _barrier(
		context,
		start,
		ending
	)
	var direct: Array[int] = _direct(
		context,
		start,
		ending
	)
	var terms: int = _boolean_count(
		context,
		start,
		ending
	)
	var ternaries: int = 0
	var string_chain: bool = false
	var addition: bool = false
	var chain_valid: bool = true
	var operand_start: int = start
	var conditional_if: int = -1
	var conditional_else: int = -1
	for index: int in direct:
		if _keyword(
			context,
			index,
			"if"
		):
			ternaries += 1
			conditional_if = index
		if _keyword(
			context,
			index,
			"else"
		):
			conditional_else = index
		if tokens[index]["text"] == "+" and tokens[index]["kind"] == "symbol":
			addition = true
			var atom: Vector2i = _ungroup(
				context,
				operand_start,
				index
			)
			chain_valid = chain_valid and _string_atom(
				context,
				atom.x,
				atom.y
			)
			string_chain = string_chain or _ordinary_string(
				context,
				atom.x,
				atom.y
			)
			operand_start = index + 1
	if addition:
		var atom: Vector2i = _ungroup(
			context,
			operand_start,
			ending
		)
		chain_valid = chain_valid and _string_atom(
			context,
			atom.x,
			atom.y
		)
		string_chain = string_chain or _ordinary_string(
			context,
			atom.x,
			atom.y
		)
	if ternaries > 1:
		_at(
			context,
			diagnostics,
			"nested_ternary",
			tokens[start],
			"Give nested conditional expressions explicit structural layers."
		)
	if ternaries == 1 and conditional_else > conditional_if:
		for index: int in direct:
			var number: int = _dictionary(context["openings"]).get(index, -1)
			if number >= 0:
				var child: Dictionary = context["groups"][number]
				if child["kind"] == "group" and _conditional_depth(
					context,
					index + 1,
					_integer(child["close_index"])
				) > 0:
					context["states"][number] = "expanded"
					context["expanded_conditional_domains"][
						_span(
							index + 1,
							child["close_index"]
						)
					] = true
					if tokens[index]["line"] == tokens[_integer(child["close_index"])]["end_line"]:
						_at(
							context,
							diagnostics,
							"nested_ternary",
							tokens[index],
							"Expand the nested conditional in its own precedence layer."
						)
		for slot: Vector2i in [
			_span(start, conditional_if),
			_span(
				conditional_if + 1,
				conditional_else
			),
			_span(
				conditional_else + 1,
				ending
			),
		]:
			if slot.x < slot.y:
				_check_domain(
					context,
					slot,
					diagnostics
				)
	elif terms > _integer(context["max_inline"]):
		_check_boolean_layer(
			context,
			start,
			ending,
			diagnostics
		)
	var multiline: bool = tokens[start]["line"] != tokens[ending - 1]["end_line"]
	if (
		addition
		and chain_valid
		and string_chain
		and multiline
		and not physical_barrier
	):
		_at(
			context,
			diagnostics,
			"simple_string_layout",
			tokens[start],
			"Keep a complete flat string addition chain on one line."
		)
	var percent: int = _separator(
		context,
		start,
		ending,
		["%"]
	)
	if percent >= 0 and _format_template(
		context,
		start,
		percent
	):
		var right: Vector2i = _ungroup(
			context,
			percent + 1,
			ending
		)
		var array_number: int = _dictionary(context["openings"]).get(right.x, -1)
		if (
			array_number >= 0
			and context["groups"][array_number]["kind"] == "array"
			and _integer(context["groups"][array_number]["close_index"]) == right.y - 1
		):
			if tokens[percent - 1]["end_line"] == tokens[percent]["line"]:
				_at(
					context,
					diagnostics,
					"format_layout",
					tokens[percent],
					"Put array-based string formatting below its template."
				)
			else:
				var lines: PackedStringArray = context["view"]["lines"]
				if _indent(lines[_integer(tokens[start]["line"]) - 1]) != _indent(lines[_integer(tokens[percent]["line"]) - 1]):
					_at(
						context,
						diagnostics,
						"format_layout",
						tokens[percent],
						"Align the formatting operator with its template's structural line."
					)
			if _integer(tokens[start]["parent_index"]) < 0:
				_at(
					context,
					diagnostics,
					"format_layout",
					tokens[start],
					"Use a necessary continuation carrier around this array-based format value."
				)
		elif (
			_atomic(
				context,
				percent + 1,
				ending
			)
			and multiline
			and not physical_barrier
		):
			_at(
				context,
				diagnostics,
				"simple_format_layout",
				tokens[start],
				"Keep a string format with one atomic value on one line."
			)
	if (
		multiline
		and terms <= _integer(context["max_inline"])
		and not _span_expanded(
			context,
			start,
			ending
		)
		and not physical_barrier
		and not _contains_lambda(
			context,
			start,
			ending
		)
	):
		_at(
			context,
			diagnostics,
			"expression_layout",
			tokens[start],
			"Keep a complete expression on one line when all children fit its structural policy."
		)
	var wrapper: int = _dictionary(context["openings"]).get(start, -1)
	if wrapper >= 0:
		var group: Dictionary = context["groups"][wrapper]
		if (
			group["kind"] == "group"
			and _integer(group["close_index"]) == ending - 1
			and _dictionary(context["value_domains"]).has(domain)
			and not physical_barrier
			and not _call_scope_barrier(
				context,
				start,
				ending
			)
			and not _contains_lambda(
				context,
				start,
				ending
			)
		):
			var inner: Vector2i = _ungroup(
				context,
				start,
				ending
			)
			if _whole_call_value(
				context,
				inner.x,
				inner.y
			):
				_at(
					context,
					diagnostics,
					"call_group_layout",
					tokens[start],
					"Do not wrap a complete call value in an extra group."
				)
		elif (
			group["kind"] == "group"
			and _integer(group["close_index"]) < ending - 1
			and _dictionary(context["value_domains"]).has(domain)
			and not physical_barrier
		):
			if _whole_call_value(
				context,
				start,
				ending
			):
				_at(
					context,
					diagnostics,
					"cast_layout",
					tokens[start],
					"Do not wrap a direct call operand only to cast its result."
				)


## 复杂布尔域逐层展开，调用、容器及匿名函数的内部条件不混入父层。
## [br]
## @api private
static func _check_boolean_layer(
	context: Dictionary,
	start: int,
	ending: int,
	diagnostics: Array[Dictionary]
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	context["expanded_boolean_domains"][_span(start, ending)] = true
	if start < ending:
		var parent: int = tokens[start]["parent_index"]
		if parent >= 0:
			var carrier: Dictionary = context["groups"][parent]
			if (
				carrier["kind"] == "group"
				and _integer(carrier["open_index"]) == start - 1
				and _integer(carrier["close_index"]) == ending
			):
				context["states"][parent] = "expanded"
	var direct: Array[int] = _direct(
		context,
		start,
		ending
	)
	var operators: Array[int] = []
	for index: int in direct:
		if (
			_keyword(
				context,
				index,
				"and"
			)
			or _keyword(
				context,
				index,
				"or"
			)
			or tokens[index]["text"] in ["&&", "||"]
		):
			operators.append(index)
	if not operators.is_empty():
		var previous: int = start
		for index: int in operators:
			if tokens[index]["line"] == tokens[previous]["end_line"]:
				_at(
					context,
					diagnostics,
					"condition_layout",
					tokens[index],
					"Put each Boolean branch on a separate structural line."
				)
			previous = index + 1
		if _integer(tokens[start]["parent_index"]) < 0:
			_at(
				context,
				diagnostics,
				"condition_layout",
				tokens[start],
				"Use a necessary grouping carrier for this expanded Boolean value."
			)
	for index: int in direct:
		var number: int = _dictionary(context["openings"]).get(index, -1)
		if number >= 0:
			var group: Dictionary = context["groups"][number]
			if group["kind"] == "group" and _boolean_count(
				context,
				index + 1,
				_integer(group["close_index"])
			) > 1:
				_check_boolean_layer(
					context,
					index + 1,
					_integer(group["close_index"]),
					diagnostics
				)


## 空白检查按 token 的二元、一元、节点路径和标点角色执行。
## [br]
## @api private
static func _check_spacing(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	var nodes: Dictionary = context["node_tokens"]
	for index: int in tokens.size():
		var token: Dictionary = tokens[index]
		var text: String = token["text"]
		if nodes.has(index):
			continue
		var binary: bool = (
			(
				text in _BINARY
				and token["kind"] == "symbol"
			)
			or (
				_keyword(
					context,
					index,
					text
				)
				and text in [
					"and",
					"or",
					"as",
					"is",
					"in",
				]
			)
		)
		if binary:
			var previous: int = index - 1
			while previous >= 0 and tokens[previous]["text"] == "\\":
				previous -= 1
			var unary: bool = text in ["+", "-"] and not _operand(
				tokens,
				previous,
				nodes
			)
			if index > 0 and not unary:
				_gap(
					context,
					diagnostics,
					index - 1,
					index,
					" "
				)
			if index + 1 < tokens.size():
				_gap(
					context,
					diagnostics,
					index,
					index + 1,
					"" if unary else " "
				)
		if (
			token["kind"] == "symbol"
			and text in ["!", "~"]
			and index + 1 < tokens.size()
		):
			_gap(
				context,
				diagnostics,
				index,
				index + 1,
				""
			)
		if (
			_keyword(
				context,
				index,
				text
			)
			and text in [
				"return",
				"await",
				"not",
				"if",
				"elif",
				"while",
				"match",
				"when",
				"else",
				"for",
			]
			and index + 1 < tokens.size()
			and tokens[index + 1]["text"] not in [
				":",
				",",
				")",
				"]",
				"}",
			]
		):
			_gap(
				context,
				diagnostics,
				index,
				index + 1,
				" "
			)
		if token["kind"] == "symbol" and text in [
			":",
			",",
			".",
		]:
			if index > 0:
				_gap(
					context,
					diagnostics,
					index - 1,
					index,
					""
				)
			if index + 1 < tokens.size():
				var next_text: String = tokens[index + 1]["text"]
				var next_is_dictionary: bool = (
					next_text == "}"
					and _dictionary(context["closings"]).has(index + 1)
					and context["groups"][_integer(context["closings"][index + 1])]["kind"] == "dictionary"
				)
				_gap(
					context,
					diagnostics,
					index,
					index + 1,
					"" if text == "."
					or (
						next_text in [
							")",
							"]",
							"}",
						]
						and not next_is_dictionary
					) else " "
				)
		if _dictionary(context["openings"]).has(index):
			var group: Dictionary = context["groups"][_integer(context["openings"][index])]
			if group["kind"] in [
				"call",
				"parameters",
				"annotation",
				"index",
				"type_arguments",
			] and index > 0:
				_gap(
					context,
					diagnostics,
					index - 1,
					index,
					""
				)
			if index + 1 < _integer(group["close_index"]):
				_gap(
					context,
					diagnostics,
					index,
					index + 1,
					" " if group["kind"] == "dictionary" else ""
				)
			else:
				_gap(
					context,
					diagnostics,
					index,
					_integer(group["close_index"]),
					""
				)
		if _dictionary(context["closings"]).has(index) and index > 0:
			var group: Dictionary = context["groups"][_integer(context["closings"][index])]
			if _integer(group["open_index"]) < index - 1:
				_gap(
					context,
					diagnostics,
					index - 1,
					index,
					" " if group["kind"] == "dictionary" else ""
				)


## 章节、成员与文档块间距只在真实成员作用域内检查。
## [br]
## @api private
static func _check_member_spacing(context: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var view: Dictionary = context["view"]
	var lines: PackedStringArray = view["lines"]
	var comments: Array[Dictionary] = view["comments"]
	var tokens: Array[Dictionary] = context["tokens"]
	for comment: Dictionary in comments:
		var text: String = comment["text"]
		var line: int = comment["line"]
		if text.begins_with("##"):
			var next_line: int = line
			while next_line < lines.size() and lines[next_line].strip_edges().is_empty():
				next_line += 1
			if (
				next_line > line
				and next_line < lines.size()
				and not lines[next_line].strip_edges().begins_with("#")
			):
				_at(
					context,
					diagnostics,
					"member_doc_binding",
					comment,
					"Attach a documentation block directly to its declaration."
				)
		if not text.begins_with("# --- ") or not text.ends_with(" ---"):
			continue
		if _integer(comment["column"]) != _prefix_length(lines[line - 1]) + 1 or not _member_comment(context, comment):
			continue
		if line > 1 and _blank_before(lines, line) != _integer(context["section_blanks"]):
			_at(
				context,
				diagnostics,
				"section_spacing",
				comment,
				"Keep the configured blank lines before a member section."
			)
		var following: int = line
		while following < lines.size() and lines[following].strip_edges().is_empty():
			following += 1
		if (
			following < lines.size()
			and _indent(lines[following]) == _indent(lines[line - 1])
			and not lines[following].strip_edges().begins_with("# --- ")
			and following - line != 1
		):
			_at(
				context,
				diagnostics,
				"section_spacing",
				comment,
				"Keep one blank line after a member section."
			)
	var statements: Array[Dictionary] = view["statements"]
	var previous_member: Dictionary = {}
	var comment_lines: Dictionary = context["comment_lines"]
	var annotation_start: int = 0
	var annotation_count: int = 0
	for statement: Dictionary in statements:
		if statement["kind"] == "lambda":
			continue
		var owner: int = statement["owner_index"]
		if owner >= 0 and statements[owner]["kind"] != "class":
			continue
		var opening: int = statement["start_index"]
		var token: Dictionary = tokens[opening]
		var line: int = token["line"]
		var kind: String = _member_kind(context, statement)
		var doc_start: int = annotation_start if annotation_start > 0 else line
		var documented: bool = false
		while doc_start > 1 and comment_lines.has(doc_start - 1):
			var preceding_comment: String = comment_lines[doc_start - 1]
			if preceding_comment.begins_with("# --- "):
				break
			documented = documented or preceding_comment.begins_with("##")
			doc_start -= 1
		context["preceding_annotations"] = annotation_count
		_check_annotation_binding(
			context,
			statement,
			diagnostics
		)
		if kind == "annotation":
			if (
				opening + 1 < tokens.size()
				and tokens[opening + 1]["text"] in [
					"tool",
					"icon",
					"static_unload",
					"export_category",
					"export_group",
					"export_subgroup",
				]
			):
				# 与文档绑定一致：文件和分组元数据不能成为后续成员的注解前缀。
				annotation_start = 0
				annotation_count = 0
				continue
			if opening + 1 < tokens.size() and tokens[opening + 1]["text"] in _FIELD_ANNOTATIONS:
				annotation_count += 1
			if annotation_start == 0:
				annotation_start = line
			continue
		annotation_start = 0
		annotation_count = 0
		if (
			kind in [
				"func",
				"class",
				"enum",
			]
			and doc_start > 1
			and not previous_member.is_empty()
			and previous_member["kind"] in [
				"func",
				"class",
				"enum",
			]
			and previous_member["owner_index"] == owner
		):
			var before: int = doc_start - _blank_before(lines, doc_start) - 2
			if (
				before >= 0
				and not lines[before].strip_edges().begins_with("# --- ")
				and _blank_before(lines, doc_start) != _integer(context["definition_blanks"])
			):
				_at(
					context,
					diagnostics,
					"definition_spacing",
					token,
					"Keep the configured blank lines between member definitions."
				)
		if (
			not previous_member.is_empty()
			and kind in [
				"var",
				"const",
				"signal",
			]
			and previous_member["kind"] in [
				"var",
				"const",
				"signal",
			]
			and previous_member["owner_index"] == owner
		):
			var previous_end: int = tokens[_integer(previous_member["end_index"]) - 1]["end_line"]
			if _boolean(previous_member["block"]):
				var last_line: int = doc_start - 2
				while last_line >= previous_end and lines[last_line].strip_edges().is_empty():
					last_line -= 1
				if not lines[last_line].strip_edges().begins_with("#"):
					previous_end = last_line + 1
			var gap: int = doc_start - previous_end - 1
			if gap >= 0:
				var only_blanks: bool = true
				for between: int in range(
					previous_end,
					doc_start - 1
				):
					only_blanks = only_blanks and lines[between].strip_edges().is_empty()
				var expected: int = 1 if documented else 0
				var single_line_members: bool = tokens[_integer(previous_member["start_index"])]["line"] == tokens[_integer(previous_member["end_index"]) - 1]["end_line"] and token["line"] == tokens[_integer(statement["end_index"]) - 1]["end_line"]
				if (
					only_blanks
					and gap != expected
					and (
						documented
						or _boolean(previous_member.get("documented", false))
						or single_line_members
					)
				):
					_at(
						context,
						diagnostics,
						"member_block_spacing",
						token,
						"Separate documented data members by one blank line and adjacent plain data members by none."
					)
		previous_member = statement.duplicate()
		previous_member["kind"] = kind
		previous_member["documented"] = documented


## 一个字段注解可以与声明直接绑定，多注解和真实注释屏障保留原关联。
## [br]
## @api private
static func _check_annotation_binding(
	context: Dictionary,
	statement: Dictionary,
	diagnostics: Array[Dictionary]
) -> void:
	if _integer(context.get("preceding_annotations", 0)) > 0:
		return
	var tokens: Array[Dictionary] = context["tokens"]
	var opening: int = statement["start_index"]
	if (
		tokens[opening]["text"] != "@"
		or opening + 1 >= tokens.size()
		or tokens[opening + 1]["text"] not in _FIELD_ANNOTATIONS
	):
		return
	var ending: int = opening + 2
	if _dictionary(context["openings"]).has(ending):
		ending = _integer(context["groups"][_integer(context["openings"][ending])]["close_index"]) + 1
	if (
		ending < tokens.size()
		and tokens[ending]["text"] in ["var", "const"]
		and tokens[ending - 1]["end_line"] != tokens[ending]["line"]
		and not _barrier(
			context,
			opening,
			ending + 1
		)
	):
		_at(
			context,
			diagnostics,
			"annotation_binding_layout",
			tokens[opening],
			"Attach the single field annotation to its declaration."
		)


## 章节只属于文件或类成员区，调用参数与函数正文中的同形说明仍是普通注释。
## [br]
## @api private
static func _member_comment(context: Dictionary, comment: Dictionary) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	for group: Dictionary in context["groups"]:
		if _integer(tokens[_integer(group["open_index"])]["start"]) < _integer(comment["start"]) and _integer(tokens[_integer(group["close_index"])]["end"]) > _integer(comment["end"]):
			return false
	var statements: Array[Dictionary] = context["view"]["statements"]
	for statement: Dictionary in statements:
		if _integer(tokens[_integer(statement["start_index"])]["line"]) > _integer(comment["line"]):
			var owner: int = statement["owner_index"]
			return owner < 0 or statements[owner]["kind"] == "class"
	return _integer(comment["column"]) == 1


## 注解和 static 是声明头元数据，不改变成员本身的间距分类。
## [br]
## @api private
static func _member_kind(context: Dictionary, statement: Dictionary) -> String:
	var tokens: Array[Dictionary] = context["tokens"]
	var cursor: int = statement["start_index"]
	var ending: int = statement["header_end_index"]
	while cursor < ending and tokens[cursor]["text"] == "@":
		cursor += 2
		if _dictionary(context["openings"]).has(cursor):
			cursor = _integer(context["groups"][_integer(context["openings"][cursor])]["close_index"]) + 1
	if cursor >= ending:
		return "annotation"
	if tokens[cursor]["text"] == "static":
		cursor += 1
	return str(tokens[cursor]["text"]) if cursor < ending else ""


## 按完整语句 owner 提取表达式；声明类型和循环变量不参与值计项。
## [br]
## @api private
static func _statement_value(context: Dictionary, statement: Dictionary) -> Vector2i:
	var start: int = statement["start_index"]
	var ending: int = statement["header_end_index"]
	var tokens: Array[Dictionary] = context["tokens"]
	var kind: String = statement["kind"]
	if _boolean(statement["block"]) and ending > start:
		ending -= 1
	while ending > start and tokens[ending - 1]["text"] in [",", ";"]:
		ending -= 1
	if kind in [
		"if",
		"elif",
		"while",
		"match",
		"return",
	]:
		start += 1
	elif kind == "for":
		var separator: int = _separator(
			context,
			start,
			ending,
			["in"]
		)
		start = separator + 1 if separator >= 0 else ending
	elif kind == "match_arm":
		var separator: int = _separator(
			context,
			start,
			ending,
			["when"]
		)
		start = separator + 1 if separator >= 0 else ending
	elif kind in [
		"func",
		"class",
		"lambda",
		"enum",
		"signal",
		"@",
		"extends",
		"class_name",
	]:
		start = ending
	else:
		var assignment: int = _separator(
			context,
			start,
			ending,
			[
				"=",
				":=",
				"+=",
				"-=",
				"*=",
				"/=",
				"%=",
				"&=",
				"|=",
				"^=",
				"<<=",
				">>=",
				"**=",
			]
		)
		if assignment >= 0:
			start = assignment + 1
		elif kind in [
			"var",
			"const",
			"static",
		]:
			start = ending
	return _span(start, ending)


## 默认参数的类型元数据与字典键不会错误计入值的展开条件。
## [br]
## @api private
static func _value_span(
	context: Dictionary,
	item: Vector2i,
	kind: String
) -> Vector2i:
	if kind in ["parameters", "dictionary"]:
		var separator: int = _separator(
			context,
			item.x,
			item.y,
			["="] if kind == "parameters" else [":", "="]
		)
		if separator >= 0:
			return _span(
				separator + 1,
				item.y
			)
		if kind == "parameters":
			return _span(item.y, item.y)
	return item


## 子组计划、完整布尔层和数组格式化共同决定外层是否需要续行。
## [br]
## @api private
static func _span_expanded(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	if start >= ending:
		return false
	if _dictionary(context["expanded_boolean_domains"]).has(_span(start, ending)) or _dictionary(context["expanded_conditional_domains"]).has(_span(start, ending)):
		return true
	if _conditional_depth(
		context,
		start,
		ending
	) > 1:
		return true
	if _boolean_count(
		context,
		start,
		ending
	) > _integer(context["max_inline"]):
		return true
	var tokens: Array[Dictionary] = context["tokens"]
	for index: int in _direct(
		context,
		start,
		ending
	):
		var number: int = _dictionary(context["openings"]).get(index, -1)
		if number >= 0:
			var group: Dictionary = context["groups"][number]
			var state: String = _dictionary(context["states"]).get(number, "inline")
			if (
				state == "expanded"
				or (
					state == "preserve"
					and tokens[index]["line"] != tokens[_integer(group["close_index"])]["end_line"]
				)
			):
				return true
		if _keyword(
			context,
			index,
			"func"
		):
			return true
	var percent: int = _separator(
		context,
		start,
		ending,
		["%"]
	)
	if percent >= 0:
		var right: Vector2i = _ungroup(
			context,
			percent + 1,
			ending
		)
		var number: int = _dictionary(context["openings"]).get(right.x, -1)
		if number >= 0 and context["groups"][number]["kind"] == "array":
			return _format_template(
				context,
				start,
				percent
			) or tokens[start]["line"] != tokens[ending - 1]["end_line"]
	return false


## 条件表达式的层数只穿过普通分组，不把数组项或调用参数混入同一条件。
## [br]
## @api private
static func _conditional_depth(
	context: Dictionary,
	start: int,
	ending: int
) -> int:
	var own: int = 0
	var child_depth: int = 0
	for index: int in _direct(
		context,
		start,
		ending
	):
		if _keyword(
			context,
			index,
			"if"
		):
			own += 1
		var number: int = _dictionary(context["openings"]).get(index, -1)
		if number >= 0:
			var group: Dictionary = context["groups"][number]
			if group["kind"] == "group":
				child_depth = maxi(
					child_depth,
					_conditional_depth(
						context,
						index + 1,
						_integer(group["close_index"])
					)
				)
	return own + child_depth


## 完整调用 wrapper 遇到条件选择或 await 时保留原有边界，不扩张已证明的窄规则。
## [br]
## @api private
static func _call_scope_barrier(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	for index: int in range(start, ending):
		if (
			_keyword(
				context,
				index,
				"if"
			)
			or _keyword(
				context,
				index,
				"else"
			)
			or _keyword(
				context,
				index,
				"await"
			)
		):
			return true
	return false


## lambda 正文是独立语句域，外层 wrapper 与折叠规则不得越过这个边界。
## [br]
## @api private
static func _contains_lambda(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var starts: PackedInt32Array = context["lambda_starts"]
	var low: int = 0
	var high: int = starts.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if starts[middle] < start:
			low = middle + 1
		else:
			high = middle
	return low < starts.size() and starts[low] < ending


## 只证明名称/成员链的完整普通调用，可带明确的直接 cast 后缀。
## [br]
## @api private
static func _whole_call_value(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	if start >= ending:
		return false
	var cursor: int = start
	var wrapper: int = _dictionary(context["openings"]).get(start, -1)
	if wrapper >= 0 and context["groups"][wrapper]["kind"] == "group":
		var wrapper_end: int = _integer(context["groups"][wrapper]["close_index"]) + 1
		var inner: Vector2i = _ungroup(
			context,
			start,
			wrapper_end
		)
		if not _whole_call_value(
			context,
			inner.x,
			inner.y
		):
			return false
		cursor = wrapper_end
	else:
		if tokens[start]["kind"] != "name":
			return false
		cursor = start + 1
		while (
			cursor + 1 < ending
			and tokens[cursor]["text"] == "."
			and tokens[cursor + 1]["kind"] == "name"
		):
			cursor += 2
		var number: int = _dictionary(context["openings"]).get(cursor, -1)
		if number < 0 or context["groups"][number]["kind"] != "call":
			return false
		cursor = _integer(context["groups"][number]["close_index"]) + 1
	if cursor == ending:
		return true
	if (
		cursor + 1 >= ending
		or not _keyword(
			context,
			cursor,
			"as"
		)
		or tokens[cursor + 1]["kind"] != "name"
	):
		return false
	cursor += 2
	while (
		cursor + 1 < ending
		and tokens[cursor]["text"] == "."
		and tokens[cursor + 1]["kind"] == "name"
	):
		cursor += 2
	if (
		cursor < ending
		and _dictionary(context["openings"]).has(cursor)
		and context["groups"][_integer(context["openings"][cursor])]["kind"] == "type_arguments"
	):
		cursor = _integer(context["groups"][_integer(context["openings"][cursor])]["close_index"]) + 1
	return cursor == ending


## 直接 token 遍历跳过后代组；每个元素只在其实际 owner 下计项。
## [br]
## @api private
static func _direct(
	context: Dictionary,
	start: int,
	ending: int
) -> Array[int]:
	var result: Array[int] = []
	var cursor: int = start
	while cursor < ending:
		result.append(cursor)
		var number: int = _dictionary(context["openings"]).get(cursor, -1)
		if number >= 0 and _integer(context["groups"][number]["close_index"]) < ending:
			cursor = _integer(context["groups"][number]["close_index"]) + 1
		else:
			cursor += 1
	return result


## 完整逻辑组递归参与布尔叶计数，其他语法 owner 独立计数。
## [br]
## @api private
static func _boolean_count(
	context: Dictionary,
	start: int,
	ending: int
) -> int:
	var key: Vector2i = _span(start, ending)
	var cache: Dictionary = context["boolean_counts"]
	if cache.has(key):
		return cache[key]
	var operators: int = 0
	var nested: int = 0
	var tokens: Array[Dictionary] = context["tokens"]
	var direct: Array[int] = _direct(
		context,
		start,
		ending
	)
	var conditional_if: int = -1
	var conditional_else: int = -1
	for index: int in direct:
		if _keyword(
			context,
			index,
			"if"
		):
			conditional_if = index
		if _keyword(
			context,
			index,
			"else"
		):
			conditional_else = index
	if conditional_if >= 0 and conditional_else > conditional_if:
		var conditional_count: int = maxi(
			_boolean_count(
				context,
				start,
				conditional_if
			),
			maxi(
				_boolean_count(
					context,
					conditional_if + 1,
					conditional_else
				),
				_boolean_count(
					context,
					conditional_else + 1,
					ending
				)
			)
		)
		cache[key] = conditional_count
		return conditional_count
	for index: int in direct:
		if _keyword(
			context,
			index,
			"func"
		):
			return 0
		if (
			_keyword(
				context,
				index,
				"and"
			)
			or _keyword(
				context,
				index,
				"or"
			)
			or tokens[index]["text"] in ["&&", "||"]
		):
			operators += 1
		var number: int = _dictionary(context["openings"]).get(index, -1)
		if number >= 0:
			var group: Dictionary = context["groups"][number]
			if group["kind"] == "group":
				nested += maxi(
					0,
					_boolean_count(
						context,
						index + 1,
						_integer(group["close_index"])
					) - 1
				)
	var result: int = operators + nested + 1 if start < ending else 0
	cache[key] = result
	return result


## 字符串/注释屏障只约束所属区域，不豁免独立后代的检查。
## [br]
## @api private
static func _barrier(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	if start >= ending:
		return false
	var comments: PackedInt32Array = context["comment_starts"]
	var low: int = 0
	var high: int = comments.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if comments[middle] < _integer(tokens[start]["start"]):
			low = middle + 1
		else:
			high = middle
	if low < comments.size() and comments[low] < _integer(tokens[ending - 1]["end"]):
		return true
	for index: int in range(start, ending):
		if (
			tokens[index]["text"] == "\\"
			or (
				tokens[index]["kind"] == "string"
				and tokens[index]["line"] != tokens[index]["end_line"]
			)
		):
			return true
	return false


## 共享原子定义只包含字面量、名称/成员链、空容器、一层一元和原有分组。
## [br]
## @api private
static func _atomic(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	if start >= ending:
		return false
	var tokens: Array[Dictionary] = context["tokens"]
	var span: Vector2i = _ungroup(
		context,
		start,
		ending
	)
	start = span.x
	ending = span.y
	if start >= ending:
		return false
	if tokens[start]["text"] in [
		"+",
		"-",
		"~",
		"!",
		"not",
	] and start + 1 < ending:
		start += 1
	if ending - start == 1:
		return tokens[start]["kind"] in [
			"name",
			"number",
			"string",
		] and tokens[start]["line"] == tokens[start]["end_line"]
	var number: int = _dictionary(context["openings"]).get(start, -1)
	if number >= 0 and _integer(context["groups"][number]["close_index"]) == ending - 1:
		return context["groups"][number]["kind"] in ["array", "dictionary"] and _array(context["groups"][number]["items"]).is_empty()
	if tokens[start]["kind"] != "name":
		return false
	var cursor: int = start + 1
	while cursor < ending:
		if (
			cursor + 1 >= ending
			or tokens[cursor]["text"] != "."
			or tokens[cursor + 1]["kind"] != "name"
		):
			return false
		cursor += 2
	return true


## 只拆完整包裹域的分组，不越过真正的运算优先级边界。
## [br]
## @api private
static func _ungroup(
	context: Dictionary,
	start: int,
	ending: int
) -> Vector2i:
	while start < ending:
		var number: int = _dictionary(context["openings"]).get(start, -1)
		if number < 0:
			break
		var group: Dictionary = context["groups"][number]
		if group["kind"] != "group" or _integer(group["close_index"]) != ending - 1:
			break
		start += 1
		ending -= 1
	return _span(start, ending)


## 简单拼接不接受数字、布尔、节点路径或无法证明的调用/索引项。
## [br]
## @api private
static func _string_atom(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	if _ordinary_string(
		context,
		start,
		ending
	):
		return true
	var tokens: Array[Dictionary] = context["tokens"]
	return (
		start < ending
		and tokens[start]["kind"] == "name"
		and tokens[start]["text"] not in [
			"true",
			"false",
			"null",
		]
		and _atomic(
			context,
			start,
			ending
		)
	)


## StringName、NodePath 和节点引用前缀不被误认成普通字符串模板。
## [br]
## @api private
static func _ordinary_string(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	return (
		ending - start == 1
		and tokens[start]["kind"] == "string"
		and tokens[start]["line"] == tokens[start]["end_line"]
		and not str(tokens[start]["text"]).begins_with("&")
		and not str(tokens[start]["text"]).begins_with("^")
		and not str(tokens[start]["text"]).begins_with("$")
	)


## 格式化左项必须是可证明的单行字符串或平坦字符串加法链。
## [br]
## @api private
static func _ordinary_string_span(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var span: Vector2i = _ungroup(
		context,
		start,
		ending
	)
	if _ordinary_string(
		context,
		span.x,
		span.y
	):
		return true
	var tokens: Array[Dictionary] = context["tokens"]
	var anchor: bool = false
	var operand_start: int = span.x
	var addition: bool = false
	for index: int in _direct(
		context,
		span.x,
		span.y
	):
		if tokens[index]["text"] != "+" or tokens[index]["kind"] != "symbol":
			continue
		addition = true
		var atom: Vector2i = _ungroup(
			context,
			operand_start,
			index
		)
		if not _string_atom(
			context,
			atom.x,
			atom.y
		):
			return false
		anchor = anchor or _ordinary_string(
			context,
			atom.x,
			atom.y
		)
		operand_start = index + 1
	var last: Vector2i = _ungroup(
		context,
		operand_start,
		span.y
	)
	return (
		addition
		and _string_atom(
			context,
			last.x,
			last.y
		)
		and (
			anchor
			or _ordinary_string(
				context,
				last.x,
				last.y
			)
		)
	)


## 模板来源允许完整调用结果，但不把包含算术的未知变量表达式猜成字符串。
## [br]
## @api private
static func _format_template(
	context: Dictionary,
	start: int,
	ending: int
) -> bool:
	var span: Vector2i = _ungroup(
		context,
		start,
		ending
	)
	if (
		_ordinary_string(
			context,
			span.x,
			span.y
		)
		or (
			span.x != start
			and _ordinary_string_span(
				context,
				start,
				ending
			)
		)
	):
		return true
	var tokens: Array[Dictionary] = context["tokens"]
	if span.x >= span.y:
		return false
	var closing: int = _dictionary(context["closings"]).get(
		span.y - 1,
		-1
	)
	if closing < 0 or context["groups"][closing]["kind"] != "call":
		return false
	for index: int in _direct(
		context,
		span.x,
		span.y
	):
		var number: int = _dictionary(context["openings"]).get(index, -1)
		if number >= 0:
			if context["groups"][number]["kind"] not in ["call", "index"]:
				return false
		elif (
			not _dictionary(context["node_tokens"]).has(index)
			and tokens[index]["text"] != "."
			and tokens[index]["kind"] not in ["name", "string"]
		):
			return false
	return true


## lambda 正文重启独立表达式 owner；只有该正文内真正嵌套的调用需要尾逗号。
## [br]
## @api private
static func _call_is_nested(context: Dictionary, number: int) -> bool:
	var group: Dictionary = context["groups"][number]
	var parent: int = group["parent_index"]
	if parent < 0:
		return false
	var starts: PackedInt32Array = context["ordered_starts"]
	var low: int = 0
	var high: int = starts.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if starts[middle] <= _integer(group["open_index"]):
			low = middle + 1
		else:
			high = middle
	if low == 0:
		return true
	var statements: Array[Dictionary] = context["view"]["statements"]
	var statement: Dictionary = statements[low - 1]
	if _integer(statement["lexical_parent"]) == parent and statement["kind"] != "lambda":
		var owner: int = statement["owner_index"]
		while owner >= 0:
			if statements[owner]["kind"] == "lambda":
				return false
			owner = statements[owner]["owner_index"]
	return true


## 关键字成员和节点路径片段保持名称身份，不参与表达式分支判断。
## [br]
## @api private
static func _keyword(
	context: Dictionary,
	index: int,
	word: String
) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	return (
		tokens[index]["kind"] == "name"
		and tokens[index]["text"] == word
		and not _dictionary(context["node_tokens"]).has(index)
		and (
			index == 0
			or tokens[index - 1]["text"] != "."
		)
	)


## 查找域内直接分隔符，不把类型泛型与后代容器的符号当作当前分隔。
## [br]
## @api private
static func _separator(
	context: Dictionary,
	start: int,
	ending: int,
	values: Array
) -> int:
	var tokens: Array[Dictionary] = context["tokens"]
	for index: int in _direct(
		context,
		start,
		ending
	):
		if tokens[index]["text"] in values and not _dictionary(context["node_tokens"]).has(index):
			return index
	return -1


## 危险语法屏障按直接 owner 查找，不因后代使用 await 等结构误伤外层。
## [br]
## @api private
static func _contains_direct(
	context: Dictionary,
	start: int,
	ending: int,
	values: Array
) -> bool:
	for index: int in _direct(
		context,
		start,
		ending
	):
		for value: String in values:
			if _keyword(
				context,
				index,
				value
			):
				return true
	return false


## 运算符左侧的结束角色决定正负号及百分号是一元、二元还是节点访问。
## [br]
## @api private
static func _operand(
	tokens: Array[Dictionary],
	index: int,
	nodes: Dictionary
) -> bool:
	if index < 0:
		return false
	var token: Dictionary = tokens[index]
	if (
		nodes.has(index)
		or token["kind"] in ["number", "string"]
		or token["text"] in [
			")",
			"]",
			"}",
		]
	):
		return true
	return (
		token["kind"] == "name"
		and (
			(
				index > 0
				and tokens[index - 1]["text"] == "."
			)
			or token["text"] not in [
				"return",
				"await",
				"not",
				"if",
				"elif",
				"else",
				"for",
				"while",
				"match",
				"when",
				"and",
				"or",
				"in",
				"is",
				"as",
				"var",
				"const",
				"func",
				"signal",
				"class",
				"extends",
			]
		)
	)


## 仅比较同一物理行的空白间隙，注释与跨行载荷从不作为空白替换目标。
## [br]
## @api private
static func _gap(
	context: Dictionary,
	diagnostics: Array[Dictionary],
	left: int,
	right: int,
	expected: String
) -> void:
	var tokens: Array[Dictionary] = context["tokens"]
	if tokens[left]["end_line"] != tokens[right]["line"]:
		return
	var source: String = context["view"]["source"]
	var gap: String = source.substr(
		_integer(tokens[left]["end"]),
		_integer(tokens[right]["start"]) - _integer(tokens[left]["end"])
	)
	if gap.strip_edges().is_empty() and gap != expected:
		_at(
			context,
			diagnostics,
			"token_spacing",
			tokens[right],
			"Use spacing appropriate to the token's structural role."
		)


## 首 token 索引判断续行是否有自己的可检查缩进。
## [br]
## @api private
static func _first_on_line(context: Dictionary, index: int) -> bool:
	var tokens: Array[Dictionary] = context["tokens"]
	var lines: PackedStringArray = context["view"]["lines"]
	var token: Dictionary = tokens[index]
	return _integer(context["first_by_line"][token["line"]]) == index and _integer(token["column"]) == _prefix_length(lines[_integer(token["line"]) - 1]) + 1


## 结构缩进以 Tab 层数计；空格缩进另由 text_format 报告。
## [br]
## @api private
static func _indent(line: String) -> int:
	var cursor: int = 0
	while cursor < line.length() and line[cursor] == "\t":
		cursor += 1
	return cursor


## 返回整段水平缩进长度，供确认章节注释确为独占成员行。
## [br]
## @api private
static func _prefix_length(line: String) -> int:
	return line.length() - line.strip_edges(true, false).length()


## 只统计紧邻目标行的空白行，不穿过说明或文档正文。
## [br]
## @api private
static func _blank_before(lines: PackedStringArray, line: int) -> int:
	var cursor: int = line - 2
	var result: int = 0
	while cursor >= 0 and lines[cursor].strip_edges().is_empty():
		result += 1
		cursor -= 1
	return result


## token 定位统一从源码视图读取，避免规则自行计算错误的字符列。
## [br]
## @api private
static func _at(
	context: Dictionary,
	diagnostics: Array[Dictionary],
	rule: String,
	token: Dictionary,
	message: String
) -> void:
	_add(
		context,
		diagnostics,
		rule,
		_integer(token["line"]),
		_integer(token["column"]),
		message
	)


## 相同位置/规则去重，并用一个明确的预算失败替代无界诊断。
## [br]
## @api private
static func _add(
	context: Dictionary,
	diagnostics: Array[Dictionary],
	rule: String,
	line: int,
	column: int,
	message: String
) -> void:
	var levels: Dictionary = context["rule_levels"]
	if rule != "analysis_budget" and levels.get(rule, "error") == "off":
		return
	var key: String = (
		"%s:%d:%d"
		% [
			rule,
			line,
			column,
		]
	)
	var seen: Dictionary = context["seen"]
	if seen.has(key):
		return
	seen[key] = true
	if diagnostics.size() == _MAX_DIAGNOSTICS:
		diagnostics.append(
			{
				"rule": "analysis_budget",
				"line": line,
				"column": column,
				"message": "Diagnostic budget exhausted.",
			}
		)
	elif diagnostics.size() < _MAX_DIAGNOSTICS:
		diagnostics.append(
			{
				"rule": rule,
				"line": line,
				"column": column,
				"message": message,
			}
		)
