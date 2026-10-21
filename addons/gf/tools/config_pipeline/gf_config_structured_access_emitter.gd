# 将正式配置类型编译结果发射为 GDScript 包装类；不提供描述反序列化入口。
extends RefCounted


# --- 常量 ---

## 记录与结构共用既有标量读取契约。
## [br]
## @api private
const _BASE_CLASS: String = "GFConfigRecordAccessBase"


# --- 私有变量 ---

## 当前生成调用的依赖在前、使用者在后的类型计划。
## [br]
## @api private
var _nodes: Array[Dictionary] = []

## 仅在本次生成调用内复用相同完整描述。
## [br]
## @api private
var _by_description: Dictionary = {}

## 与表记录类共享的生成类名占用集合。
## [br]
## @api private
var _used_names: Dictionary = {}


# --- 框架内部方法 ---

## 编译真实 Resource 列并把类型计划挂到已有列记录，拒绝描述字典冒充声明。
## [br]
## @api framework_internal
## [br]
## @layer tools
## [br]
## @param records: 已收集的表记录，包含 source_schema、source_columns 和 columns。
## [br]
## @param options: 正式类型编译器接受的调用期预算。
## [br]
## @return ok 与 issues；失败后调用者不得发射部分源码。
## [br]
## @schema records: Array[Dictionary]，生成器私有调用期记录。
## [br]
## @schema options: Dictionary，可包含 work_budget 或 work_limits。
## [br]
## @schema return: Dictionary，包含 ok:bool 与 issues:PackedStringArray。
func prepare(records: Array[Dictionary], options: Dictionary) -> Dictionary:
	_nodes.clear()
	_by_description.clear()
	_used_names = { _BASE_CLASS: true }
	var issues: PackedStringArray = PackedStringArray()
	var compiler: GFConfigTypeCompiler = GFConfigTypeCompiler.new(options)
	var pending: Array[Dictionary] = []
	for record: Dictionary in records:
		_used_names[record["typed_record_class_name"]] = true
		var source_schema: Variant = record["source_schema"]
		var source_columns: Variant = record["source_columns"]
		if not source_columns is Array:
			continue
		var columns: Array = source_columns
		for source_column: Variant in columns:
			var definition: Variant = _read_type_definition(source_column)
			if definition == null:
				continue
			if (
				not source_schema is GFConfigTableSchema
				or not source_column is GFConfigTableColumn
				or not definition is GFConfigTypeDefinition
			):
				var _admission_issue: bool = issues.append("结构化访问器仅接纳正式 Schema/Column/TypeDefinition Resource，不接受描述字典。")
				continue
			var column: GFConfigTableColumn = source_column
			var field: Dictionary = compiler.compile_column(column)
			pending.append(
				{
					"record": record,
					"field_name": column.field_name,
					"field": field,
				}
			)
	compiler.validate_defaults()
	var report: Dictionary = compiler.get_report()
	if not GFVariantData.get_option_bool(report, "ok"):
		var _compile_issue: bool = issues.append("结构化访问器类型编译失败：%s" % str(report.get("issues", [])))
	if not issues.is_empty():
		return { "ok": false, "issues": issues }
	for entry: Dictionary in pending:
		var field: Dictionary = entry["field"]
		var compiled_type: Dictionary = field["type"]
		var description: Dictionary = compiler.describe_type(compiled_type)
		if description.is_empty() or not GFVariantData.get_option_bool(
			compiler.get_report(),
			"ok"
		):
			var _budget_issue: bool = issues.append("结构化访问器描述不完整或超出预算。")
			break
		var node: Dictionary = _plan_type(description)
		var record: Dictionary = entry["record"]
		var columns: Array = record["columns"]
		var found: bool = false
		for column: Dictionary in columns:
			if column["field_name"] == entry["field_name"]:
				column["structured_node"] = node
				found = true
				break
		if not found:
			var _missing_issue: bool = issues.append("结构化字段未能生成 getter：%s" % str(entry["field_name"]))
	report = compiler.get_report()
	if not GFVariantData.get_option_bool(report, "ok"):
		var _description_issue: bool = issues.append("结构化访问器描述预算失败：%s" % str(report.get("issues", [])))
	return { "ok": issues.is_empty(), "issues": issues }


## 按依赖顺序输出包装类；调用者先输出共用记录基类。
## [br]
## @api framework_internal
## [br]
## @layer tools
## [br]
## @param builder: 当前源码构造器。
func append_classes(builder: GFSourceBuilder) -> void:
	for node: Dictionary in _nodes:
		_append_class(builder, node)


## 输出一个已编译字段的类型 getter，读取值后封装独立集合副本。
## [br]
## @api framework_internal
## [br]
## @layer tools
## [br]
## @param builder: 当前源码构造器。
## [br]
## @param column: 字段名、已分配 getter 名称与 structured_node。
## [br]
## @schema column: Dictionary，包含 field_name、getter_name 和 structured_node。
func append_field_getter(builder: GFSourceBuilder, column: Dictionary) -> void:
	var node: Dictionary = column["structured_node"]
	builder.blank(2)
	builder.doc("读取 `%s` 的类型投影；集合包装拥有独立快照。" % str(column["field_name"]))
	builder.line(
		"func %s() -> %s:"
		% [column["getter_name"], node["return_type"]]
	)
	builder.indent()
	_append_value_return(
		builder,
		node,
		"get_value(%s)" % _literal(str(column["field_name"]))
	)
	builder.dedent()


# --- 私有/辅助方法 ---

## 只读属性值，不调用外部对象的 describe 或自定义 getter 方法。
## [br]
## @api private
func _read_type_definition(column: Variant) -> Variant:
	if column is Dictionary:
		var dictionary: Dictionary = column
		return dictionary.get("type_definition")
	if column is Object:
		var object: Object = column
		for property: Dictionary in object.get_property_list():
			if property["name"] == &"type_definition":
				return object.get(&"type_definition")
	return null


## 对已通过正式编译器的有限纯描述建立共享节点，不再次解释校验规则。
## [br]
## @api private
func _plan_type(description: Dictionary) -> Dictionary:
	var signature: String = var_to_str(description)
	if _by_description.has(signature):
		return _by_description[signature]
	var kind: String = description["kind"]
	var node: Dictionary = { "kind": kind, "description": description }
	_by_description[signature] = node
	if kind == "scalar":
		var scalar_type: int = description["scalar_type"]
		node.merge(_scalar_info(scalar_type))
		return node
	var suggested_name: String = str(description["type_name"])
	if suggested_name.is_empty():
		suggested_name = kind
	var class_name_value: String = _unique(
		"ConfigType%s" % _identifier(suggested_name).to_pascal_case(),
		_used_names
	)
	node["class_name"] = class_name_value
	node["return_type"] = "int" if kind == "enum" else class_name_value
	if kind == "struct":
		var base_description: Variant = description["base_type"]
		var inherited: Dictionary = {}
		node["base_class"] = _BASE_CLASS
		if base_description is Dictionary:
			var base_dictionary: Dictionary = base_description
			var base_node: Dictionary = _plan_type(base_dictionary)
			node["base_class"] = base_node["class_name"]
			var base_fields: Array = base_dictionary["fields"]
			for field: Dictionary in base_fields:
				inherited[field["field_name"]] = true
		var getters: Dictionary = _reserved_getters()
		var fields: Array = description["fields"]
		var planned_fields: Array[Dictionary] = []
		for field: Dictionary in fields:
			var getter: String = _unique(
				"get_%s" % _identifier(str(field["field_name"])),
				getters
			)
			if inherited.has(field["field_name"]):
				continue
			var field_type: Dictionary
			var type_report: Variant = field["type_definition"]
			if type_report is Dictionary:
				var typed_report: Dictionary = type_report
				var field_description: Dictionary = typed_report["definition"]
				field_type = _plan_type(field_description)
			else:
				var value_type: int = field["value_type"]
				field_type = _scalar_info(value_type)
				field_type["kind"] = "scalar"
			planned_fields.append(
				{
					"field_name": field["field_name"],
					"getter_name": getter,
					"structured_node": field_type,
				}
			)
		node["fields"] = planned_fields
	elif kind == "array":
		var element_description: Dictionary = description["element_type"]
		node["element"] = _plan_type(element_description)
	elif kind == "map":
		var value_description: Dictionary = description["map_value_type"]
		node["element"] = _plan_type(value_description)
		var map_key_type: int = description["map_key_type"]
		var key_info: Dictionary = _scalar_info(map_key_type)
		node["key_type"] = key_info["return_type"]
	elif kind == "polymorphic":
		var branches: Array[Dictionary] = []
		var used_methods: Dictionary = {}
		var variants: Array = description["variants"]
		for variant: Dictionary in variants:
			branches.append(
				{
					"tag": str(variant["type_name"]),
					"method": _unique(
						"as_%s" % _identifier(str(variant["type_name"])),
						used_methods
					),
					"node": _plan_type(variant),
				}
			)
		node["branches"] = branches
	_nodes.append(node)
	return node


## 输出枚举符号、结构继承或容器/判别分支包装，不借用 provider 集合。
## [br]
## @api private
func _append_class(builder: GFSourceBuilder, node: Dictionary) -> void:
	var kind: String = node["kind"]
	var description: Dictionary = node["description"]
	builder.doc("配置类型 `%s` 的独立数据包装。" % str(description["type_name"]))
	builder.line("class %s:" % node["class_name"])
	builder.indent()
	if kind == "enum":
		builder.line("extends RefCounted")
		var symbols: Dictionary = description["symbols"]
		var used: Dictionary = {}
		for symbol: Variant in symbols:
			builder.line(
				"const %s: int = %s"
				% [
					_unique(
						"VALUE_%s" % _identifier(str(symbol)).to_upper(),
						used
					),
					str(symbols[symbol]),
				]
			)
	elif kind == "struct":
		builder.line("extends %s" % node["base_class"])
		builder.blank(2)
		builder.line("func _init(value: Dictionary = {}) -> void:")
		builder.indent()
		builder.line("data = value.duplicate(true)")
		builder.dedent()
		var fields: Array = node["fields"]
		for field: Dictionary in fields:
			append_field_getter(builder, field)
	elif kind == "array" or kind == "map":
		_append_container(builder, node)
	elif kind == "polymorphic":
		builder.line("extends %s" % _BASE_CLASS)
		builder.blank(2)
		builder.line("func _init(value: Dictionary = {}) -> void:")
		builder.indent()
		builder.line("data = value.duplicate(true)")
		builder.dedent()
		builder.blank(2)
		builder.line("func get_kind() -> StringName:")
		builder.indent()
		builder.line("return get_string_name(%s)" % _literal(str(description["discriminator"])))
		builder.dedent()
		var branches: Array = node["branches"]
		for branch: Dictionary in branches:
			var branch_node: Dictionary = branch["node"]
			builder.blank(2)
			builder.line(
				"func %s() -> %s:"
				% [branch["method"], branch_node["return_type"]]
			)
			builder.indent()
			builder.line("if get_kind() != StringName(%s):" % _literal(str(branch["tag"])))
			builder.indent()
			builder.line("return null")
			builder.dedent()
			builder.line("return %s.new(data)" % branch_node["class_name"])
			builder.dedent()
	builder.dedent()
	builder.blank(2)


## 生成容器存在性与空值查询，以及返回副本的集合导出。
## [br]
## @api private
func _append_container(builder: GFSourceBuilder, node: Dictionary) -> void:
	var array_kind: bool = node["kind"] == "array"
	var storage_type: String = "Array" if array_kind else "Dictionary"
	var empty_literal: String = "[]" if array_kind else "{}"
	var key_type: String = "int" if array_kind else str(node["key_type"])
	var element: Dictionary = node["element"]
	builder.line("extends RefCounted")
	builder.blank()
	builder.line(
		"var _values: %s = %s"
		% [storage_type, empty_literal]
	)
	builder.blank(2)
	builder.line(
		"func _init(values: %s = %s) -> void:"
		% [storage_type, empty_literal]
	)
	builder.indent()
	builder.line("_values = values.duplicate(true)")
	builder.dedent()
	builder.blank(2)
	builder.line("func size() -> int:")
	builder.indent()
	builder.line("return _values.size()")
	builder.dedent()
	builder.blank(2)
	builder.line("func has(key: %s) -> bool:" % key_type)
	builder.indent()
	builder.line("return key >= 0 and key < _values.size()" if array_kind else "return _values.has(key)")
	builder.dedent()
	builder.blank(2)
	builder.line("func is_null(key: %s) -> bool:" % key_type)
	builder.indent()
	builder.line("return not has(key) or _values[key] == null")
	builder.dedent()
	builder.blank(2)
	builder.line(
		"func %s(key: %s) -> %s:"
		% [
			"get_at" if array_kind else "get_value",
			key_type,
			element["return_type"],
		]
	)
	builder.indent()
	_append_value_return(
		builder,
		element,
		"_values[key] if has(key) else null"
	)
	builder.dedent()
	builder.blank(2)
	builder.line(
		"func %s() -> %s:"
		% ["to_array" if array_kind else "to_dictionary", storage_type]
	)
	builder.indent()
	builder.line("return _values.duplicate(true)")
	builder.dedent()


## 将单个运行时值收窄为声明类型；无值时对象返回 null，标量返回明确默认值。
## [br]
## @api private
func _append_value_return(
	builder: GFSourceBuilder,
	node: Dictionary,
	expression: String
) -> void:
	var kind: String = node["kind"]
	var return_type: String = node["return_type"]
	builder.line("var value: Variant = %s" % expression)
	if kind == "scalar" or kind == "enum":
		if return_type == "Variant":
			builder.line("if value is Dictionary:")
			builder.indent()
			builder.line("var dictionary_value: Dictionary = value")
			builder.line("return dictionary_value.duplicate(true)")
			builder.dedent()
			builder.line("if value is Array:")
			builder.indent()
			builder.line("var array_value: Array = value")
			builder.line("return array_value.duplicate(true)")
			builder.dedent()
			builder.line("return value")
			return
		if return_type == "float":
			builder.line("if value is int:")
			builder.indent()
			builder.line("var integer_value: int = value")
			builder.line("return float(integer_value)")
			builder.dedent()
		builder.line("if value is %s:" % return_type)
		builder.indent()
		builder.line("var typed_value: %s = value" % return_type)
		builder.line("return typed_value.duplicate(true)" if return_type == "Array" or return_type == "Dictionary" else "return typed_value")
		builder.dedent()
		builder.line("return %s" % ("0" if kind == "enum" else str(node["default"])))
	else:
		var collection_type: String = "Array" if kind == "array" else "Dictionary"
		builder.line("if not value is %s:" % collection_type)
		builder.indent()
		builder.line("return null")
		builder.dedent()
		builder.line("var collection: %s = value" % collection_type)
		builder.line("return %s.new(collection)" % node["class_name"])


## 按既有 Column.ValueType 映射 GDScript 类型及空值默认量。
## [br]
## @api private
func _scalar_info(value_type: int) -> Dictionary:
	var types: Array[String] = [
		"Variant",
		"bool",
		"int",
		"float",
		"String",
		"StringName",
		"Vector2",
		"Vector2i",
		"Color",
		"Dictionary",
		"Array",
	]
	var defaults: Array[String] = [
		"null",
		"false",
		"0",
		"0.0",
		"\"\"",
		"&\"\"",
		"Vector2.ZERO",
		"Vector2i.ZERO",
		"Color.WHITE",
		"{}",
		"[]",
	]
	return { "return_type": types[value_type], "default": defaults[value_type] }


## 预占继承基类及 Object 的 get_ 方法，防止字段 getter 改写不同签名。
## [br]
## @api private
func _reserved_getters() -> Dictionary:
	var result: Dictionary = {}
	for method: String in [
		"get_value",
		"get_bool",
		"get_int",
		"get_float",
		"get_string",
		"get_string_name",
		"get_vector2",
		"get_vector2i",
		"get_color",
		"get_dictionary",
		"get_array",
		"get_class",
		"get_instance_id",
		"get_meta",
		"get_property_list",
		"get_script",
		"get_signal_list",
		"get_method_list",
		"get_signal_connection_list",
		"get_incoming_connections",
		"get_reference_count",
	]:
		result[method] = true
	return result


## 为任意作者名称保留稳定 ASCII 标识符；无法形成标识符时使用内容摘要。
## [br]
## @api private
func _identifier(value: String) -> String:
	var result: String = ""
	for index: int in range(value.length()):
		var character: String = value.substr(index, 1).to_lower()
		var code: int = character.unicode_at(0)
		if (
			(
				code >= 97
				and code <= 122
			)
			or (
				code >= 48
				and code <= 57
			)
		):
			result += character
		elif not result.ends_with("_"):
			result += "_"
	result = result.trim_prefix("_").trim_suffix("_")
	if result.is_empty():
		result = "value_%s" % value.sha256_text().substr(0, 12)
	return result


## 在当前命名空间分配稳定、不覆盖既有符号的名称。
## [br]
## @api private
func _unique(base_name: String, used: Dictionary) -> String:
	var candidate: String = base_name
	var suffix: int = 2
	while used.has(candidate):
		candidate = (
			"%s_%d"
			% [base_name, suffix]
		)
		suffix += 1
	used[candidate] = true
	return candidate


## 将原始字段名或判别值序列化为有效 GDScript 字符串字面量。
## [br]
## @api private
func _literal(value: String) -> String:
	return "\"%s\"" % value.c_escape()
