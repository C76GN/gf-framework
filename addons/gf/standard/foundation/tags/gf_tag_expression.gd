## GFTagExpression: 可嵌套标签查询表达式资源。
##
## 在 GFTagQuery 的 all/any/none 单层查询之上提供组合表达式，适合描述
## “任意一组条件成立”“全部子条件成立”或“没有子条件成立”等通用标签规则。
## 它只组合查询结果，不维护全局标签表，也不规定标签业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.18.0
class_name GFTagExpression
extends Resource


# --- 枚举 ---

## 表达式运算类型。
## [br]
## @api public
enum Operator {
	## 使用 query 作为叶子查询。
	QUERY,
	## 全部子表达式都满足。
	ALL,
	## 任意子表达式满足。
	ANY,
	## 没有子表达式满足。
	NONE,
}


# --- 常量 ---

const _MAX_RESTORE_DEPTH: int = 128


# --- 导出变量 ---

## 当前表达式运算类型。
## [br]
## @api public
@export var operator: Operator = Operator.QUERY

## 叶子标签查询。operator 为 QUERY 时使用；为空时视为无条件通过。
## [br]
## @api public
@export var query: GFTagQuery = null

## 子表达式列表。operator 为 ALL、ANY 或 NONE 时使用。
## [br]
## @api public
## [br]
## @schema expressions: Array[GFTagExpression]，按数组顺序参与组合判断。
@export var expressions: Array[GFTagExpression] = []


# --- 公共方法 ---

## 检查表达式是否为空。
## [br]
## @api public
## [br]
## @return 无叶子查询且无子表达式时返回 true。
func is_empty() -> bool:
	if operator == Operator.QUERY:
		return query == null or query.is_empty()
	return expressions.is_empty()


## 匹配标签源。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter through GFTagQuery.
## [br]
## @return 表达式满足时返回 true。
func matches(source: Variant) -> bool:
	var report: Dictionary = get_match_report(source)
	return GFVariantData.get_option_bool(report, "ok", false)


## 获取匹配报告。
## [br]
## @api public
## [br]
## @param source: 标签源。
## [br]
## @schema source: Variant accepted by GFTagSourceAdapter through GFTagQuery.
## [br]
## @return 匹配报告。
## [br]
## @schema return: Dictionary，包含 ok、operator、query_report、child_reports、matched_indices、failed_indices、reason 等字段。
func get_match_report(source: Variant) -> Dictionary:
	return _get_match_report(source, [])


## 配置为叶子查询表达式。
## [br]
## @api public
## [br]
## @param tag_query: 标签查询资源。
## [br]
## @return 当前表达式。
func configure_query(tag_query: GFTagQuery) -> GFTagExpression:
	operator = Operator.QUERY
	query = tag_query
	expressions.clear()
	return self


## 配置为全部子表达式都满足。
## [br]
## @api public
## [br]
## @param child_expressions: 子表达式列表。
## [br]
## @return 当前表达式。
## [br]
## @schema child_expressions: Array[GFTagExpression]，null 项会在匹配时按失败处理。
func configure_all(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
	operator = Operator.ALL
	query = null
	expressions = child_expressions.duplicate()
	return self


## 配置为任意子表达式满足。
## [br]
## @api public
## [br]
## @param child_expressions: 子表达式列表。
## [br]
## @return 当前表达式。
## [br]
## @schema child_expressions: Array[GFTagExpression]，null 项会在匹配时按失败处理。
func configure_any(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
	operator = Operator.ANY
	query = null
	expressions = child_expressions.duplicate()
	return self


## 配置为没有子表达式满足。
## [br]
## @api public
## [br]
## @param child_expressions: 子表达式列表。
## [br]
## @return 当前表达式。
## [br]
## @schema child_expressions: Array[GFTagExpression]，null 项会在匹配时按失败处理。
func configure_none(child_expressions: Array[GFTagExpression]) -> GFTagExpression:
	operator = Operator.NONE
	query = null
	expressions = child_expressions.duplicate()
	return self


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新表达式。
func duplicate_expression() -> GFTagExpression:
	return _duplicate_expression({})


## 导出为字典。
## [br]
## @api public
## [br]
## @return 表达式字典。
## [br]
## @schema return: Dictionary serialized tag expression.
func to_dictionary() -> Dictionary:
	return _to_dictionary({})


## 从字典创建表达式。
## [br]
## @api public
## [br]
## @param data: 表达式字典。
## [br]
## @schema data: Dictionary serialized tag expression.
## [br]
## @return 新表达式。
static func from_dictionary(data: Dictionary) -> GFTagExpression:
	var expression: GFTagExpression = _from_dictionary(data, [], 0)
	return expression if expression != null else GFTagExpression.new()


## 以查询资源创建叶子表达式。
## [br]
## @api public
## [br]
## @param tag_query: 标签查询资源。
## [br]
## @return 新表达式。
static func from_query(tag_query: GFTagQuery) -> GFTagExpression:
	return GFTagExpression.new().configure_query(tag_query)


# --- 私有/辅助方法 ---

static func _from_dictionary(data: Dictionary, visited: Array, depth: int) -> GFTagExpression:
	if depth > _MAX_RESTORE_DEPTH or _visited_contains_dictionary(visited, data):
		return null

	var expression: GFTagExpression = GFTagExpression.new()
	visited.append(data)
	expression.operator = _operator_from_variant(GFVariantData.get_option_value(data, "operator", Operator.QUERY))
	var query_data: Dictionary = _get_raw_dictionary(data, "query")
	if not query_data.is_empty():
		expression.query = GFTagQuery.from_dictionary(query_data)
	var child_values: Array = _get_raw_array(data, "expressions")
	for child_variant: Variant in child_values:
		if child_variant is Dictionary:
			var child_dictionary: Dictionary = child_variant
			if GFVariantData.get_option_bool(child_dictionary, "null_expression"):
				expression.expressions.append(null)
			elif GFVariantData.get_option_bool(child_dictionary, "cycle_detected"):
				expression.expressions.append(null)
			else:
				expression.expressions.append(_from_dictionary(child_dictionary, visited, depth + 1))
	var _removed_visit: Variant = visited.pop_back()
	return expression


static func _get_raw_dictionary(data: Dictionary, key: String) -> Dictionary:
	if data.has(key):
		var value: Variant = data[key]
		if value is Dictionary:
			return value

	var string_name_key: StringName = StringName(key)
	if data.has(string_name_key):
		var named_value: Variant = data[string_name_key]
		if named_value is Dictionary:
			return named_value

	return {}


static func _get_raw_array(data: Dictionary, key: String) -> Array:
	if data.has(key):
		var value: Variant = data[key]
		if value is Array:
			return value

	var string_name_key: StringName = StringName(key)
	if data.has(string_name_key):
		var named_value: Variant = data[string_name_key]
		if named_value is Array:
			return named_value

	return []


func _duplicate_expression(visited: Dictionary) -> GFTagExpression:
	var instance_id: int = get_instance_id()
	if visited.has(instance_id):
		var existing: Variant = visited[instance_id]
		if existing is GFTagExpression:
			return existing

	var copy: GFTagExpression = _instantiate_expression()
	visited[instance_id] = copy
	copy.operator = operator
	copy.query = query.duplicate_query() if query != null else null
	for expression: GFTagExpression in expressions:
		copy.expressions.append(expression._duplicate_expression(visited) if expression != null else null)
	return copy


func _to_dictionary(visited: Dictionary) -> Dictionary:
	var instance_id: int = get_instance_id()
	if visited.has(instance_id):
		return _make_cycle_dictionary()
	visited[instance_id] = true

	var child_dictionaries: Array[Dictionary] = []
	for expression: GFTagExpression in expressions:
		child_dictionaries.append(_make_null_dictionary() if expression == null else expression._to_dictionary(visited))
	var _removed_visit: bool = visited.erase(instance_id)

	return {
		"operator": _operator_to_string(operator),
		"query": query.to_dictionary() if query != null else {},
		"expressions": child_dictionaries,
	}


func _get_match_report(source: Variant, visited: Array[int]) -> Dictionary:
	var instance_id: int = get_instance_id()
	if visited.has(instance_id):
		return {
			"ok": false,
			"operator": _operator_to_string(operator),
			"reason": "cycle_detected",
			"query_report": {},
			"child_reports": [],
			"matched_indices": [],
			"failed_indices": [],
		}

	visited.append(instance_id)
	var report: Dictionary
	match operator:
		Operator.QUERY:
			report = _get_query_match_report(source)
		Operator.ALL:
			report = _get_children_match_report(source, visited, true, false)
		Operator.ANY:
			report = _get_children_match_report(source, visited, false, true)
		Operator.NONE:
			report = _get_none_match_report(source, visited)
		_:
			report = {
				"ok": false,
				"operator": "unknown",
				"reason": "unknown_operator",
				"query_report": {},
				"child_reports": [],
				"matched_indices": [],
				"failed_indices": [],
			}
	visited.pop_back()
	return report


func _get_query_match_report(source: Variant) -> Dictionary:
	var query_report: Dictionary = query.get_match_report(source) if query != null else { "ok": true }
	var ok: bool = GFVariantData.get_option_bool(query_report, "ok", false)
	return {
		"ok": ok,
		"operator": _operator_to_string(operator),
		"reason": "" if ok else "query_failed",
		"query_report": query_report,
		"child_reports": [],
		"matched_indices": [],
		"failed_indices": [],
	}


func _get_children_match_report(
	source: Variant,
	visited: Array[int],
	require_all: bool,
	empty_value: bool
) -> Dictionary:
	var child_reports: Array[Dictionary] = []
	var matched_indices: Array[int] = []
	var failed_indices: Array[int] = []
	for index: int in range(expressions.size()):
		var child: GFTagExpression = expressions[index]
		var child_report: Dictionary = _get_null_child_report() if child == null else child._get_match_report(source, visited)
		child_reports.append(child_report)
		if GFVariantData.get_option_bool(child_report, "ok", false):
			matched_indices.append(index)
		else:
			failed_indices.append(index)

	var ok: bool = empty_value if expressions.is_empty() else (
		failed_indices.is_empty() if require_all else not matched_indices.is_empty()
	)
	return {
		"ok": ok,
		"operator": _operator_to_string(operator),
		"reason": "" if ok else ("child_failed" if require_all else "no_child_matched"),
		"query_report": {},
		"child_reports": child_reports,
		"matched_indices": matched_indices,
		"failed_indices": failed_indices,
	}


func _get_none_match_report(source: Variant, visited: Array[int]) -> Dictionary:
	var child_reports: Array[Dictionary] = []
	var matched_indices: Array[int] = []
	var failed_indices: Array[int] = []
	for index: int in range(expressions.size()):
		var child: GFTagExpression = expressions[index]
		var child_report: Dictionary = _get_null_child_report() if child == null else child._get_match_report(source, visited)
		child_reports.append(child_report)
		if GFVariantData.get_option_bool(child_report, "ok", false):
			matched_indices.append(index)
		else:
			failed_indices.append(index)

	var ok: bool = matched_indices.is_empty()
	return {
		"ok": ok,
		"operator": _operator_to_string(operator),
		"reason": "" if ok else "blocked_child_matched",
		"query_report": {},
		"child_reports": child_reports,
		"matched_indices": matched_indices,
		"failed_indices": failed_indices,
	}


func _get_null_child_report() -> Dictionary:
	return {
		"ok": false,
		"operator": "null",
		"reason": "null_expression",
		"query_report": {},
		"child_reports": [],
		"matched_indices": [],
		"failed_indices": [],
	}


static func _make_null_dictionary() -> Dictionary:
	return {
		"operator": "null",
		"query": {},
		"expressions": [],
		"null_expression": true,
	}


static func _make_cycle_dictionary() -> Dictionary:
	return {
		"operator": "cycle",
		"query": {},
		"expressions": [],
		"cycle_detected": true,
	}


static func _operator_to_string(value: int) -> String:
	match value:
		Operator.QUERY:
			return "query"
		Operator.ALL:
			return "all"
		Operator.ANY:
			return "any"
		Operator.NONE:
			return "none"
		_:
			return "unknown"


static func _operator_from_variant(value: Variant) -> Operator:
	if value is int:
		var numeric: int = GFVariantData.to_int(value, Operator.QUERY)
		match numeric:
			Operator.QUERY:
				return Operator.QUERY
			Operator.ALL:
				return Operator.ALL
			Operator.ANY:
				return Operator.ANY
			Operator.NONE:
				return Operator.NONE

	var text: String = GFVariantData.to_text(value).to_lower()
	match text:
		"query":
			return Operator.QUERY
		"all":
			return Operator.ALL
		"any":
			return Operator.ANY
		"none":
			return Operator.NONE
		_:
			return Operator.QUERY


static func _visited_contains_dictionary(visited: Array, data: Dictionary) -> bool:
	for entry: Variant in visited:
		if entry is Dictionary and is_same(entry, data):
			return true
	return false


func _instantiate_expression() -> GFTagExpression:
	var script_value: Variant = get_script()
	if script_value is Script:
		var script: Script = script_value
		var instance: Variant = script.call("new")
		if instance is GFTagExpression:
			var expression: GFTagExpression = instance
			return expression
	return GFTagExpression.new()
