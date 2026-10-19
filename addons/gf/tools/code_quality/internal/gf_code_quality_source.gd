# 保留源码位置的只读 GDScript 词法与块结构视图，不加载或执行目标脚本。
extends RefCounted


# --- 常量 ---

## 单文件词法分析的 UTF-8 字节上限。
## [br]
## @api private
const _MAX_BYTES: int = 8 * 1024 * 1024

## 防止异常输入耗尽 token、行与括号栈预算。
## [br]
## @api private
const _MAX_TOKENS: int = 500_000

## 行位置索引的最大条目数。
## [br]
## @api private
const _MAX_LINES: int = 100_000

## 递归语法载体只接受有界深度。
## [br]
## @api private
const _MAX_DEPTH: int = 128

## 最长运算符优先，避免把复合运算拆成改变角色的 token。
## [br]
## @api private
const _OPERATORS: PackedStringArray = [
	"**=",
	"<<=",
	">>=",
	"...",
	"->",
	":=",
	"==",
	"!=",
	"<=",
	">=",
	"+=",
	"-=",
	"*=",
	"/=",
	"%=",
	"&=",
	"|=",
	"^=",
	"**",
	"<<",
	">>",
	"&&",
	"||",
	"..",
]


# --- 框架内部方法 ---

## 扫描源码并保留字符坐标、字面量、注释和独立语句的块归属；失败时不交付完整结构。
## [br]
## @api framework_internal
## [br]
## @param path: 仅用于诊断标识的源码路径。
## [br]
## @param source: 原始源码；本方法不读取文件或调用引擎解析器。
## [br]
## @return 词法视图，complete=false 表示预算或词法闭合失败。
## [br]
## @schema return: Dictionary，包含 path、source、complete、diagnostics、tokens、comments、lines、groups 和 statements；token 为 text/kind/start/end/line/column/end_line/end_column/parent_index，偏移半开且行列从 1 开始。
static func lex_source(path: String, source: String) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	if source.ends_with("\n"):
		var _resize_result: int = lines.resize(lines.size() - 1)
	var view: Dictionary = {
		"path": path,
		"source": source,
		"complete": false,
		"diagnostics": [],
		"tokens": [],
		"comments": [],
		"lines": lines,
		"groups": [],
		"statements": [],
	}
	if source.to_utf8_buffer().size() > _MAX_BYTES or lines.size() > _MAX_LINES:
		_fail(
			view,
			"source_budget",
			1,
			1,
			"Source exceeds the lexical input budget."
		)
		return view
	var starts: PackedInt32Array = [0]
	for character_index: int in source.length():
		if source[character_index] == "\n":
			var _appended_line: bool = starts.append(character_index + 1)
	var tokens: Array[Dictionary] = []
	var comments: Array[Dictionary] = []
	view["tokens"] = tokens
	view["comments"] = comments
	var unicode_name: RegEx = RegEx.new()
	var unicode_compile_error: Error = unicode_name.compile("^(?:([\\p{L}\\p{Nl}])|([\\p{Mn}\\p{Mc}\\p{Nd}\\p{Pc}]))$")
	if unicode_compile_error != OK:
		_fail(
			view,
			"lexical_closure",
			1,
			1,
			"Unicode identifier categories are unavailable."
		)
		return view
	var cursor: int = 0
	while cursor < source.length():
		var character: String = source[cursor]
		if character in [
			" ",
			"\t",
			"\r",
			"\n",
		]:
			cursor += 1
			continue
		var token_end: int = cursor + 1
		var kind: String = "symbol"
		if character == "#":
			token_end = source.find("\n", cursor)
			if token_end < 0:
				token_end = source.length()
			kind = "comment"
		else:
			var quote_start: int = cursor
			if (
				character in [
					"r",
					"&",
					"^",
					"$",
				]
				and cursor + 1 < source.length()
				and source[cursor + 1] in ["\"", "'"]
			):
				quote_start += 1
			if source[quote_start] in ["\"", "'"]:
				var quote: String = source[quote_start]
				var delimiter: String = quote.repeat(3) if source.substr(quote_start, 3) == quote.repeat(3) else quote
				token_end = _string_end(
					source,
					quote_start,
					delimiter
				)
				if token_end < 0:
					var position: Vector2i = _position(starts, cursor)
					_fail(
						view,
						"lexical_closure",
						position.x,
						position.y,
						"String literal is not closed."
					)
					return view
				kind = "string"
			elif _name_character(
				character,
				false,
				unicode_name
			):
				kind = "name"
				while token_end < source.length() and _name_character(
					source[token_end],
					true,
					unicode_name
				):
					token_end += 1
			elif character >= "0" and character <= "9":
				kind = "number"
				token_end = _number_end(source, cursor)
			else:
				for operator: String in _OPERATORS:
					if source.substr(
						cursor,
						operator.length()
					) == operator:
						token_end = cursor + operator.length()
						break
		var token: Dictionary = _make_token(
			source,
			starts,
			cursor,
			token_end,
			kind
		)
		if kind == "comment":
			comments.append(token)
		else:
			tokens.append(token)
		if tokens.size() + comments.size() > _MAX_TOKENS:
			_fail(
				view,
				"source_budget",
				_integer(token["line"]),
				_integer(token["column"]),
				"Token budget exhausted."
			)
			return view
		cursor = token_end
	view["tokens"] = tokens
	view["comments"] = comments
	if not _collect_groups(view):
		return view
	var statements: Array[Dictionary] = _collect_statements(view)
	view["statements"] = statements
	var independent_starts: Dictionary = {}
	for statement: Dictionary in statements:
		independent_starts[statement["start_index"]] = true
	for group: Dictionary in view["groups"]:
		if independent_starts.has(group["open_index"]):
			if group["kind"] == "call":
				group["kind"] = "group"
			elif group["kind"] == "index":
				group["kind"] = "array"
	view["complete"] = true
	return view


# --- 私有/辅助方法 ---

## 查找字符串闭合，转义字符与跨行载荷始终保持为同一个 token。
## [br]
## @api private
static func _string_end(
	source: String,
	opening: int,
	delimiter: String
) -> int:
	var cursor: int = opening + delimiter.length()
	while cursor < source.length():
		if source[cursor] == "\\":
			cursor += 2
			continue
		if source.substr(
			cursor,
			delimiter.length()
		) == delimiter:
			return cursor + delimiter.length()
		if delimiter.length() == 1 and source[cursor] in ["\r", "\n"]:
			return -1
		cursor += 1
	return -1


## Unicode 标识符沿用 Godot 的字符有效性，不把字符串内容重新解释为名称。
## [br]
## @api private
static func _name_character(
	character: String,
	allow_digit: bool,
	unicode_name: RegEx
) -> bool:
	if (
		character == "_"
		or (
			character >= "a"
			and character <= "z"
		)
		or (
			character >= "A"
			and character <= "Z"
		)
	):
		return true
	if character >= "0" and character <= "9":
		return allow_digit
	if character.unicode_at(0) < 128:
		return false
	var matched: RegExMatch = unicode_name.search(character)
	return (
		matched != null
		and (
			not matched.get_string(1).is_empty()
			or allow_digit
		)
	)


## 数字扫描只消费合法数字载荷；成员访问点和范围标记保留给结构分析。
## [br]
## @api private
static func _number_end(source: String, opening: int) -> int:
	var cursor: int = opening
	if source.substr(cursor, 2).to_lower() in ["0x", "0b"]:
		var hexadecimal: bool = source[cursor + 1].to_lower() == "x"
		cursor += 2
		while cursor < source.length():
			var character: String = source[cursor].to_lower()
			if character == "_" or character in ("0123456789abcdef" if hexadecimal else "01"):
				cursor += 1
			else:
				break
		return cursor
	while cursor < source.length() and source[cursor] in "0123456789_":
		cursor += 1
	if (
		cursor + 1 < source.length()
		and source[cursor] == "."
		and source[cursor + 1] in "0123456789"
	):
		cursor += 1
		while cursor < source.length() and source[cursor] in "0123456789_":
			cursor += 1
	if cursor < source.length() and source[cursor].to_lower() == "e":
		var exponent: int = cursor + 1
		if exponent < source.length() and source[exponent] in ["+", "-"]:
			exponent += 1
		var digit_start: int = exponent
		while exponent < source.length() and source[exponent] in "0123456789_":
			exponent += 1
		if exponent > digit_start:
			cursor = exponent
	return cursor


## 用二分索引把半开字符偏移转换为 1-based 行列。
## [br]
## @api private
static func _position(starts: PackedInt32Array, offset: int) -> Vector2i:
	var low: int = 0
	var high: int = starts.size()
	while low < high:
		var middle: int = (low + high) >> 1
		if starts[middle] <= offset:
			low = middle + 1
		else:
			high = middle
	var row: int = maxi(
		0,
		low - 1
	)
	return Vector2i(
		row + 1,
		offset - starts[row] + 1
	)


## token 同时保留原始拼写和完整终点，便于精确诊断而不改写载荷。
## [br]
## @api private
static func _make_token(
	source: String,
	starts: PackedInt32Array,
	opening: int,
	ending: int,
	kind: String
) -> Dictionary:
	var first: Vector2i = _position(starts, opening)
	var last: Vector2i = _position(starts, ending)
	return {
		"text": source.substr(
			opening,
			ending - opening
		),
		"kind": kind,
		"start": opening,
		"end": ending,
		"line": first.x,
		"column": first.y,
		"end_line": last.x,
		"end_column": last.y,
		"parent_index": -1,
	}


## 一次栈遍历确定括号 owner 和直接项；后代逗号不计入父组。
## [br]
## @api private
static func _collect_groups(view: Dictionary) -> bool:
	var tokens: Array[Dictionary] = view["tokens"]
	var groups: Array[Dictionary] = []
	var stack: Array[int] = []
	var openers: String = "([{"
	var closers: String = ")] }".replace(" ", "")
	for token_index: int in tokens.size():
		var token: Dictionary = tokens[token_index]
		var text: String = token["text"]
		token["parent_index"] = stack.back() if not stack.is_empty() else -1
		if token["kind"] != "symbol":
			continue
		if text == "\\":
			if token_index + 1 == tokens.size() or _integer(tokens[token_index + 1]["line"]) != _integer(token["line"]) + 1:
				_fail(
					view,
					"lexical_closure",
					_integer(token["line"]),
					_integer(token["column"]),
					"A continuation must end a continued physical line."
				)
				return false
		if text.length() == 1 and openers.contains(text):
			if stack.size() >= _MAX_DEPTH:
				_fail(
					view,
					"source_budget",
					_integer(token["line"]),
					_integer(token["column"]),
					"Delimiter depth budget exhausted."
				)
				return false
			var group_index: int = groups.size()
			groups.append(
				{
					"open_index": token_index,
					"close_index": -1,
					"parent_index": token["parent_index"],
					"kind": _group_kind(tokens, token_index),
					"items": [],
					"item_start": token_index + 1,
				}
			)
			stack.append(group_index)
		elif text.length() == 1 and closers.contains(text):
			if stack.is_empty():
				_fail(
					view,
					"lexical_closure",
					_integer(token["line"]),
					_integer(token["column"]),
					"Closing delimiter has no matching opener."
				)
				return false
			var group_index: int = stack.back()
			var group: Dictionary = groups[group_index]
			var opening_text: String = tokens[_integer(group["open_index"])]["text"]
			if openers.find(opening_text) != closers.find(text):
				_fail(
					view,
					"lexical_closure",
					_integer(token["line"]),
					_integer(token["column"]),
					"Closing delimiter does not match its opener."
				)
				return false
			var items: Array = group["items"]
			if _integer(group["item_start"]) < token_index:
				items.append(
					Vector2i(
						_integer(group["item_start"]),
						token_index
					)
				)
			var _removed_item_start: bool = group.erase("item_start")
			group["close_index"] = token_index
			var _closed_group: int = stack.pop_back()
		elif text == "," and not stack.is_empty():
			var group: Dictionary = groups[stack.back()]
			var items: Array = group["items"]
			if _integer(group["item_start"]) < token_index:
				items.append(
					Vector2i(
						_integer(group["item_start"]),
						token_index
					)
				)
			group["item_start"] = token_index + 1
	if not stack.is_empty():
		var group: Dictionary = groups[stack[0]]
		var token: Dictionary = tokens[_integer(group["open_index"])]
		_fail(
			view,
			"lexical_closure",
			_integer(token["line"]),
			_integer(token["column"]),
			"Opening delimiter remains unclosed."
		)
		return false
	view["groups"] = groups
	return true


## 语法角色只依赖相邻真实 token；关键字成员调用不会被误判成控制头。
## [br]
## @api private
static func _group_kind(tokens: Array[Dictionary], opening: int) -> String:
	var text: String = tokens[opening]["text"]
	var previous: String = tokens[opening - 1]["text"] if opening > 0 else ""
	var member: bool = opening > 1 and tokens[opening - 2]["text"] == "."
	if text == "{":
		if (
			previous == "enum"
			or (
				opening > 1
				and tokens[opening - 2]["text"] == "enum"
			)
		):
			return "enum"
		return "dictionary"
	if text == "[" and previous in ["Array", "Dictionary"]:
		return "type_arguments"
	var same_statement: bool = (
		opening > 0
		and (
			_integer(tokens[opening - 1]["end_line"]) == _integer(tokens[opening]["line"])
			or _integer(tokens[opening]["parent_index"]) >= 0
		)
	)
	if text == "[":
		return "index" if same_statement and _ends_operand(
			tokens,
			opening - 1
		) else "array"
	if opening > 1 and tokens[opening - 2]["text"] == "@":
		return "annotation"
	var declaration_keyword: bool = (
		opening > 1
		and tokens[opening - 2]["text"] in ["func", "signal"]
		and previous not in [
			"if",
			"else",
			"in",
			"is",
			"as",
			"and",
			"or",
			"not",
		]
		and (
			opening < 3
			or tokens[opening - 3]["text"] not in [
				".",
				"/",
				"$",
				"%",
			]
		)
	)
	if (
		(
			previous == "func"
			and not member
		)
		or declaration_keyword
	):
		return "parameters"
	if (
		same_statement
		and (
			member
			or previous == "assert"
			or _ends_operand(
				tokens,
				opening - 1
			)
		)
	):
		return "call"
	return "group"


## 保留一元/控制关键字角色，使其后的括号与数组不会成为调用/索引。
## [br]
## @api private
static func _ends_operand(tokens: Array[Dictionary], index: int) -> bool:
	if index < 0:
		return false
	var token: Dictionary = tokens[index]
	var text: String = token["text"]
	if text in [
		")",
		"]",
		"}",
	] or token["kind"] in ["number", "string"]:
		return true
	if token["kind"] != "name":
		return false
	return (
		(
			index > 0
			and tokens[index - 1]["text"] == "."
		)
		or text not in [
			"if",
			"elif",
			"else",
			"while",
			"for",
			"match",
			"when",
			"return",
			"await",
			"not",
			"and",
			"or",
			"in",
			"is",
			"as",
			"var",
			"const",
			"func",
			"signal",
		]
	)


## 识别完整头和独立正文语句；参数/字典内的冒号不创建代码块。
## [br]
## @api private
static func _collect_statements(view: Dictionary) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = view["tokens"]
	var groups: Array[Dictionary] = view["groups"]
	var lines: PackedStringArray = view["lines"]
	var starts: Array[int] = []
	var start_set: Dictionary = {}
	var lambda_headers: Dictionary = {}
	var lambda_limits: Dictionary = {}
	var lambda_indents: Dictionary = {}
	var lambda_scope_indents: Dictionary = {}
	var active_lambdas: Array[int] = []
	var group_by_open: Dictionary = {}
	for group: Dictionary in groups:
		group_by_open[group["open_index"]] = group
	for index: int in tokens.size():
		var token: Dictionary = tokens[index]
		while not active_lambdas.is_empty():
			var active: int = active_lambdas.back()
			if _integer(lambda_limits[active]) <= index:
				var _closed_lambda: int = active_lambdas.pop_back()
			else:
				break
		var lambda_end: int = _lambda_header_end(
			tokens,
			group_by_open,
			index
		)
		if lambda_end >= 0:
			lambda_headers[index] = lambda_end
			var domain_end: int = _item_domain_end(
				tokens,
				groups,
				index
			)
			lambda_limits[index] = domain_end
			var lambda_indent: int = _indent(lines[_integer(token["line"]) - 1])
			var lambda_scope_indent: int = _scope_indent(lines[_integer(token["line"]) - 1])
			if lambda_end < domain_end and _integer(tokens[lambda_end]["line"]) > _integer(tokens[lambda_end - 1]["end_line"]):
				var body_indent: int = _indent(lines[_integer(tokens[lambda_end]["line"]) - 1])
				var body_scope_indent: int = _scope_indent(lines[_integer(tokens[lambda_end]["line"]) - 1])
				if body_indent >= lambda_indent:
					lambda_indent = mini(
						lambda_indent,
						maxi(
							0,
							body_indent - 1
						)
					)
				lambda_scope_indent = mini(
					lambda_scope_indent,
					maxi(
						0,
						body_scope_indent - 1
					)
				)
			lambda_indents[index] = lambda_indent
			lambda_scope_indents[index] = lambda_scope_indent
			starts.append(index)
			start_set[index] = true
			active_lambdas.append(index)
		var first_on_line: bool = index == 0 or _integer(tokens[index - 1]["end_line"]) < _integer(token["line"])
		var after_separator: bool = (
			index > 0
			and tokens[index - 1]["text"] == ";"
			and tokens[index - 1]["parent_index"] == token["parent_index"]
		)
		if (
			not (
				first_on_line
				or after_separator
			)
			or token["text"] in [
				")",
				"]",
				"}",
				".",
				"as",
			]
		):
			continue
		if index > 0 and tokens[index - 1]["text"] == "\\":
			continue
		if _integer(token["parent_index"]) < 0:
			if not start_set.has(index):
				starts.append(index)
				start_set[index] = true
		else:
			for lambda_index: int in active_lambdas:
				var lambda_token: Dictionary = tokens[lambda_index]
				if (
					_integer(lambda_headers[lambda_index]) <= index
					and index < _integer(lambda_limits[lambda_index])
					and lambda_token["parent_index"] == token["parent_index"]
					and (
						_scope_indent(lines[_integer(token["line"]) - 1]) > _integer(lambda_scope_indents[lambda_index])
						or after_separator
					)
				):
					starts.append(index)
					start_set[index] = true
					break
	starts.sort()
	var next_by_parent: Dictionary = {}
	var endings: Dictionary = {}
	for ordinal: int in range(
		starts.size() - 1,
		-1,
		-1
	):
		var opening: int = starts[ordinal]
		var parent: int = tokens[opening]["parent_index"]
		var boundary: int = _item_domain_end(
			tokens,
			groups,
			opening
		)
		endings[opening] = next_by_parent.get(parent, boundary)
		endings[opening] = mini(
			_integer(endings[opening]),
			boundary
		)
		next_by_parent[parent] = opening
	var result: Array[Dictionary] = []
	var owners: Array[int] = []
	for ordinal: int in starts.size():
		var opening: int = starts[ordinal]
		var first: Dictionary = tokens[opening]
		var ending: int = endings[opening]
		var header_end: int = ending
		var kind: String = "lambda" if lambda_headers.has(opening) else str(first["text"])
		if kind == "static" and opening + 1 < ending:
			kind = tokens[opening + 1]["text"]
		var indent: int = _indent(lines[_integer(first["line"]) - 1])
		var scope_indent: int = _scope_indent(lines[_integer(first["line"]) - 1])
		if lambda_indents.has(opening):
			indent = lambda_indents[opening]
			scope_indent = lambda_scope_indents[opening]
		while not owners.is_empty():
			var owner: Dictionary = result[owners.back()]
			var owner_header_end: int = owner["header_end_index"]
			var inline_body: bool = opening >= owner_header_end and _integer(first["line"]) == _integer(tokens[owner_header_end - 1]["end_line"])
			if (
				(
					scope_indent > _integer(owner["scope_indent"])
					or inline_body
				)
				and (
					_integer(owner["lexical_parent"]) < 0
					or _inside_group(
						groups,
						_integer(first["parent_index"]),
						_integer(owner["lexical_parent"])
					)
				)
			):
				break
			var _closed_owner: int = owners.pop_back()
		var match_arm: bool = not owners.is_empty() and result[owners.back()]["kind"] == "match"
		var block: bool = false
		if lambda_headers.has(opening):
			header_end = lambda_headers[opening]
			block = true
		else:
			var loop_iterable_seen: bool = false
			for index: int in range(opening, ending):
				if (
					kind == "for"
					and tokens[index]["text"] == "in"
					and tokens[index]["parent_index"] == first["parent_index"]
				):
					loop_iterable_seen = true
				if (
					tokens[index]["text"] == ":"
					and tokens[index]["parent_index"] == first["parent_index"]
					and (
						kind != "for"
						or loop_iterable_seen
					)
					and (
						match_arm
						or kind in [
							"func",
							"class",
							"if",
							"elif",
							"else",
							"while",
							"for",
							"match",
							"get",
							"set",
						]
						or index + 1 == ending
					)
				):
					header_end = index + 1
					block = true
					if match_arm:
						kind = "match_arm"
					break
		var statement: Dictionary = {
			"start_index": opening,
			"end_index": ending,
			"header_end_index": header_end,
			"indent": indent,
			"scope_indent": scope_indent,
			"owner_index": owners.back() if not owners.is_empty() else -1,
			"kind": kind,
			"block": block,
			"lexical_parent": first["parent_index"],
		}
		result.append(statement)
		if block:
			owners.append(result.size() - 1)
	return result


## 二分定位当前直接参数或容器项的末端，lambda 头和正文共用同一边界。
## [br]
## @api private
static func _item_domain_end(
	tokens: Array[Dictionary],
	groups: Array[Dictionary],
	opening: int
) -> int:
	var parent: int = tokens[opening]["parent_index"]
	if parent < 0:
		return tokens.size()
	var group: Dictionary = groups[parent]
	var items: Array = group["items"]
	var low: int = 0
	var high: int = items.size()
	while low < high:
		var middle: int = (low + high) >> 1
		var item: Vector2i = items[middle]
		if item.y <= opening:
			low = middle + 1
		else:
			high = middle
	if low < items.size():
		var item: Vector2i = items[low]
		if item.x <= opening and opening < item.y:
			return item.y
	return _integer(group["close_index"])


## 匿名与命名 lambda 头只接受参数、有限类型后缀和冒号，不跨过后续关键字搜索。
## [br]
## @api private
static func _lambda_header_end(
	tokens: Array[Dictionary],
	openings: Dictionary,
	index: int
) -> int:
	if (
		tokens[index]["text"] != "func"
		or (
			index > 0
			and tokens[index - 1]["text"] == "."
		)
	):
		return -1
	var parameter_start: int = index + 1
	if parameter_start < tokens.size() and tokens[parameter_start]["kind"] == "name":
		if (
			_integer(tokens[index]["parent_index"]) < 0
			and (
				index == 0
				or _integer(tokens[index - 1]["end_line"]) < _integer(tokens[index]["line"])
				or tokens[index - 1]["text"] not in [
					"=",
					":=",
					"return",
					",",
					":",
				]
			)
		):
			return -1
		parameter_start += 1
	if not openings.has(parameter_start):
		return -1
	var parameters: Dictionary = openings[parameter_start]
	if tokens[parameter_start]["text"] != "(":
		return -1
	var cursor: int = _integer(parameters["close_index"]) + 1
	if cursor < tokens.size() and tokens[cursor]["text"] == "->":
		cursor += 1
		if cursor >= tokens.size() or tokens[cursor]["kind"] != "name":
			return -1
		cursor += 1
		while (
			cursor + 1 < tokens.size()
			and tokens[cursor]["text"] == "."
			and tokens[cursor + 1]["kind"] == "name"
		):
			cursor += 2
		if openings.has(cursor) and tokens[cursor]["text"] == "[":
			cursor = _integer(openings[cursor]["close_index"]) + 1
	return cursor + 1 if cursor < tokens.size() and tokens[cursor]["text"] == ":" else -1


## 比较 lexical owner 的祖先链，避免匿名函数结束后污染后续调用。
## [br]
## @api private
static func _inside_group(
	groups: Array[Dictionary],
	child: int,
	parent: int
) -> bool:
	var cursor: int = child
	while cursor >= 0:
		if cursor == parent:
			return true
		cursor = groups[cursor]["parent_index"]
	return false


## 空格缩进仍建立可诊断的块视图，具体违规交给布局规则报告。
## [br]
## @api private
static func _indent(line: String) -> int:
	var result: int = 0
	var spaces: int = 0
	for character: String in line:
		if character == "\t":
			result += 1
		elif character == " ":
			spaces += 1
		else:
			break
	return result + (spaces >> 2)


## 块归属保留每个空格的宽度，避免未启用布局规则时把短空格缩进截断为同级。
## [br]
## @api private
static func _scope_indent(line: String) -> int:
	var result: int = 0
	for character: String in line:
		if character == "\t":
			result += 4
		elif character == " ":
			result += 1
		else:
			break
	return result


## 所有不完整输入都返回稳定失败诊断，而不是空的问题列表。
## [br]
## @api private
static func _fail(
	view: Dictionary,
	rule: String,
	line: int,
	column: int,
	message: String
) -> void:
	var diagnostics: Array = view["diagnostics"]
	diagnostics.append(
		{
			"rule": rule,
			"line": line,
			"column": column,
			"message": message,
		}
	)


## ��ȡ���ʷ������ɵ�����������λ�ã�ȱʧ�������Ԫ����ʹ����ֵ��
## [br]
## @api private
static func _integer(value: Variant) -> int:
	if value is int:
		var integer: int = value
		return integer
	return 0
