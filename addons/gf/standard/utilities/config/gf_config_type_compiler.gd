@tool

## GFConfigTypeCompiler: 单次配置操作拥有的类型编译与值转换会话。
##
## 只在当前会话按 Resource 身份复用完成的节点。节点持有字段与规则副本，
## 不在值转换期间重新读取作者资源；失败节点不进入缓存。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFConfigTypeCompiler
extends RefCounted


# --- 私有变量 ---

## 同一批次共享的工作、字节与深度预算。
## [br]
## @api private
var _budget: GFConfigWorkBudget

## 本次调用提供的来源及转换选项，不跨调用保存。
## [br]
## @api private
var _options: Dictionary = {}

## 仅保存已经完整编译的类型节点。
## [br]
## @api private
var _nodes: Dictionary = {}

## 已冻结的字段按作者资源身份复用，避免逐行重复编译和规则复制。
## [br]
## @api private
var _columns: Dictionary = {}

## 当前定义展开路径，用于区别循环和合法共享子类型。
## [br]
## @api private
var _active: Array[int] = []

## 当前会话的结构及值问题，按发现顺序保留。
## [br]
## @api private
var _issues: Array[Dictionary] = []

## 编译完成后统一校验的字段默认值，避免规则回调夹入定义读取。
## [br]
## @api private
var _default_fields: Array[Dictionary] = []

## 防止同一图中的默认值被各消费入口反复校验。
## [br]
## @api private
var _defaults_validated: bool = false

## 定义问题与各行值问题分开保存，避免一行失败污染后续行准入。
## [br]
## @api private
var _definition_report: Dictionary = {}

## 预算失败仅报告一次，避免超限后继续放大诊断。
## [br]
## @api private
var _budget_reported: bool = false

## 仅供编辑器准入和来源审计使用的作者资源，不参与规范化执行。
## [br]
## @api private
var _source_resources: Array[Resource] = []

## 防止共享资源在来源枚举中重复出现。
## [br]
## @api private
var _source_ids: Dictionary = {}


# --- Godot 生命周期方法 ---

## 绑定调用方预算和上下文；不读取任何类型资源。
## [br]
## @api private
func _init(options: Dictionary = {}) -> void:
	_options = options.duplicate()
	_options[GFConfigElementValidation.SESSION_KEY] = GFConfigElementValidation.from_options(options)
	_budget = GFConfigWorkBudget.from_options(options)


# --- 框架内部方法 ---

## 取得明确传入的调用期会话；未传入时创建独立会话。
## [br]
## @api framework_internal
## [br]
## @param options: 预算与内部会话选项。
## [br]
## @return 当前操作应使用的编译会话。
## [br]
## @schema options: Dictionary，可包含 __gf_config_type_compiler 内部句柄；只能在同一批次调用内传播。
static func from_options(options: Dictionary = {}) -> GFConfigTypeCompiler:
	var supplied: Variant = options.get("__gf_config_type_compiler")
	if supplied is GFConfigTypeCompiler:
		return supplied
	return GFConfigTypeCompiler.new(options)


## 默认值校验前绑定 schema 当前验证上下文，共享元素及路径会话。
##
## 移除编译器句柄，避免调用期选项反向持有当前编译器。
## [br]
## @api framework_internal
## [br]
## @param options: 已创建低限额共享会话的验证选项。
## [br]
## @schema options: Dictionary，来源上下文与 schema 已有元素、资源路径会话；内部编译器键不会保留。
func bind_validation_context(options: Dictionary) -> void:
	_options = _options.merged(options, true)
	var _erased: bool = _options.erase("__gf_config_type_compiler")


## 编译一个类型节点，重用当前会话已经完成的同身份定义。
## [br]
## @api framework_internal
## [br]
## @param definition: 待编译资源。
## [br]
## @param segments: 当前字段路径。
## [br]
## @param depth: 当前结构深度。
## [br]
## @return 编译节点；无效时为空字典，问题保留在会话报告。
## [br]
## @schema segments: Array，String 字段名或 int 数组下标组成的路径。
## [br]
## @schema return: Dictionary，当前会话内部节点，持有隔离字段及规则副本，不作为公开描述输入。
func compile_type(
	definition: GFConfigTypeDefinition,
	segments: Array = [],
	depth: int = 0
) -> Dictionary:
	if not _step(depth, segments):
		return {}
	if definition == null:
		_issue(
			"missing_type_definition",
			"缺少配置类型声明。",
			segments
		)
		return {}
	var identity: int = definition.get_instance_id()
	_track_resource(definition)
	if identity in _active:
		_issue(
			"cyclic_type_definition",
			"配置类型声明存在循环。",
			segments
		)
		return {}
	if _nodes.has(identity):
		return _nodes[identity]
	_active.append(identity)
	var start: int = _issues.size()
	var node: Dictionary = {
		"identity": identity,
		"kind": definition.kind,
		"type_name": definition.type_name,
		"allow_null": definition.allow_null,
		"scalar_type": definition.scalar_type,
	}
	match definition.kind:
		GFConfigTypeDefinition.Kind.SCALAR:
			if not _is_scalar_type(definition.scalar_type):
				_issue(
					"invalid_scalar_type",
					"结构化标量必须使用明确的标量值类型。",
					segments
				)
		GFConfigTypeDefinition.Kind.STRUCT:
			_compile_struct(
				definition,
				node,
				segments,
				depth
			)
		GFConfigTypeDefinition.Kind.ARRAY:
			node["element_type"] = compile_type(
				definition.element_type,
				segments,
				depth + 1
			)
		GFConfigTypeDefinition.Kind.MAP:
			node["map_key_type"] = definition.map_key_type
			if definition.map_key_type not in [
				GFConfigTableColumn.ValueType.STRING,
				GFConfigTableColumn.ValueType.STRING_NAME,
				GFConfigTableColumn.ValueType.INT,
			]:
				_issue(
					"invalid_map_key_type",
					"映射键只支持 String、StringName 或 int。",
					segments
				)
			node["map_value_type"] = compile_type(
				definition.map_value_type,
				segments,
				depth + 1
			)
		GFConfigTypeDefinition.Kind.ENUM:
			_compile_enum(
				definition,
				node,
				segments
			)
		GFConfigTypeDefinition.Kind.POLYMORPHIC:
			_compile_variants(
				definition,
				node,
				segments,
				depth
			)
		_:
			_issue(
				"invalid_type_kind",
				"未知配置类型形状。",
				segments
			)
	_validate_unused_members(definition, segments)
	var _removed: int = _active.pop_back()
	if _has_errors(start):
		return {}
	_nodes[identity] = node
	return node


## 冻结字段约束与标量转换入口，使所有行消费同一份声明。
## [br]
## @api framework_internal
## [br]
## @param column: 字段声明。
## [br]
## @param segments: 当前字段路径。
## [br]
## @param depth: 当前结构深度。
## [br]
## @return 隔离字段节点，失败时为空字典。
## [br]
## @schema segments: Array，String 字段名和 int 数组下标。
## [br]
## @schema return: Dictionary，包含字段约束、编译类型、默认值副本及规则副本的会话内部节点。
func compile_column(
	column: GFConfigTableColumn,
	segments: Array = [],
	depth: int = 0
) -> Dictionary:
	if not _step(depth, segments):
		return {}
	if column == null or column.field_name == &"":
		_issue(
			"invalid_struct_field",
			"结构字段声明为空或没有字段名。",
			segments
		)
		return {}
	var identity: int = column.get_instance_id()
	if _columns.has(identity):
		return _columns[identity]
	_track_resource(column)
	var start: int = _issues.size()
	var node: Dictionary = {
		"field_name": column.field_name,
		"value_type": column.value_type,
		"required": column.required,
		"allow_null": column.allow_null,
		"default_value": null,
		"validation_rules": [],
		"element_validation_rules": [],
		"metadata": {},
		"segments": segments.duplicate(),
	}
	if column.type_definition != null:
		node["type"] = compile_type(
			column.type_definition,
			segments,
			depth + 1
		)
		if not column.element_validation_rules.is_empty():
			_issue(
				"structured_element_rules",
				"结构化字段应在元素类型或结构字段上声明约束，不可混用旧逐元素规则。",
				segments
			)
	else:
		var element_issue: Dictionary = GFConfigElementValidation.get_definition_issue(column.value_type, column.element_validation_rules)
		if not element_issue.is_empty():
			var issue_kind: String = element_issue["kind"]
			var issue_message: String = element_issue["message"]
			_issue(
				issue_kind,
				issue_message,
				segments
			)
		if column.value_type < GFConfigTableColumn.ValueType.ANY or column.value_type > GFConfigTableColumn.ValueType.ARRAY:
			_issue(
				"invalid_scalar_type",
				"字段值类型超出已知枚举范围。",
				segments
			)
		node["type"] = {
			"kind": GFConfigTypeDefinition.Kind.SCALAR,
			"scalar_type": column.value_type,
			"allow_null": column.allow_null,
			"type_name": &"",
			"legacy": true,
		}
	node["structured"] = column.type_definition != null
	if _admit_plain(column.default_value, segments):
		node["default_value"] = GFVariantData.duplicate_variant(column.default_value)
	if _admit_plain(column.metadata, segments):
		node["metadata"] = column.metadata.duplicate(true)
	node["validation_rules"] = _copy_rules(column.validation_rules, segments)
	node["element_validation_rules"] = _copy_rules(column.element_validation_rules, segments)
	if _has_errors(start):
		return {}
	_default_fields.append(node)
	_columns[identity] = node
	_defaults_validated = false
	return node


## 在整个图编译完成后校验并规范化非 null 默认值。
## [br]
## @api framework_internal
func validate_defaults() -> void:
	if _defaults_validated:
		return
	_defaults_validated = true
	if _has_errors(0):
		_definition_report = get_report()
		return
	for field: Dictionary in _default_fields:
		if field["default_value"] == null:
			continue
		var segments: Array = field["segments"]
		var normalized: Variant = _normalize_field(
			field,
			field["default_value"],
			segments,
			0,
			true
		)
		field["default_value"] = normalized
		if not _budget.is_ok():
			break
	_definition_report = get_report()


## 返回当前累计问题的独立报告。
## [br]
## @api framework_internal
## [br]
## @return 既有配置校验报告形状。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count、warning_count、table_name 和 row_count。
func get_report() -> Dictionary:
	_record_budget_failure([])
	return _report_since(0)


## 返回定义阶段的问题，不包含先前记录的值错误。
## [br]
## @api framework_internal
## [br]
## @return 定义编译及默认值校验报告。
## [br]
## @schema return: Dictionary，包含 ok、issues、error_count 和 warning_count。
func get_definition_report() -> Dictionary:
	validate_defaults()
	return _definition_report.duplicate(true)


## 在记录深复制前通过同一预算拒绝循环集合和超大输入。
## [br]
## @api framework_internal
## [br]
## @param value: 尚未复制的记录或表。
## [br]
## @return 输入在预算内且没有集合循环时为 true。
## [br]
## @schema value: Variant，沿用 GFConfigWorkBudget 的受限配置值。
func admit_value(value: Variant) -> bool:
	var admitted: bool = _budget.admit_value(value, "structured configuration")
	_record_budget_failure([])
	return admitted


## 返回本次编译实际读取的作者资源，供编辑器检查脚本及来源闭包。
##
## 返回数组与内部数组隔离，资源本身仍是作者资源；不得作为编译节点使用。
## [br]
## @api framework_internal
## [br]
## @return 已访问的类型、字段和规则资源，按首次访问顺序排列。
func get_source_resources() -> Array[Resource]:
	return _source_resources.duplicate()


## 使用已编译类型规范化一个值，失败不返回部分结果。
## [br]
## @api framework_internal
## [br]
## @param node: 当前会话编译的类型节点。
## [br]
## @param value: 原始输入值。
## [br]
## @param options: 来源路径和转换策略。
## [br]
## @return 当前值的校验报告与独立结果。
## [br]
## @schema node: Dictionary，compile_type 的内部结果。
## [br]
## @schema value: Variant，输入配置值。
## [br]
## @schema options: Dictionary，可包含 coerce_values、field_path、field_segments 及来源位置。
## [br]
## @schema return: Dictionary，报告附加 value 和 message；失败 value 为 null。
func normalize_type(
	node: Dictionary,
	value: Variant,
	options: Dictionary = {}
) -> Dictionary:
	var start: int = _issues.size()
	var previous_options: Dictionary = _options
	_options = _options.merged(options, true)
	var segments: Array = _segments(options)
	var output: Variant = null
	if node.is_empty():
		_issue(
			"invalid_type_definition",
			"配置类型未通过编译。",
			segments
		)
	elif _admit_plain(value, segments):
		output = _normalize_node(
			node,
			value,
			segments,
			0,
			GFVariantData.get_option_bool(
				options,
				"coerce_values",
				true
			)
		)
	var report: Dictionary = _value_report(start, output)
	_options = previous_options
	return report


## 使用字段的空值、规则及类型约束规范化一个值。
## [br]
## @api framework_internal
## [br]
## @param field: 当前会话编译的字段节点。
## [br]
## @param value: 原始字段值。
## [br]
## @param options: 来源路径和转换策略。
## [br]
## @return 当前字段报告，失败 value 为 null。
## [br]
## @schema field: Dictionary，compile_column 的内部结果。
## [br]
## @schema value: Variant，字段原始值。
## [br]
## @schema options: Dictionary，可包含 coerce_values、field_segments 与来源位置。
## [br]
## @schema return: Dictionary，校验报告附加 value 和 message。
func normalize_column(
	field: Dictionary,
	value: Variant,
	options: Dictionary = {}
) -> Dictionary:
	var start: int = _issues.size()
	var previous_options: Dictionary = _options
	_options = _options.merged(options, true)
	var segments: Array = _segments(options)
	var output: Variant = null
	if field.is_empty():
		_issue(
			"invalid_type_definition",
			"配置字段未通过编译。",
			segments
		)
	elif _admit_plain(value, segments):
		output = _normalize_field(
			field,
			value,
			segments,
			0,
			GFVariantData.get_option_bool(
				options,
				"coerce_values",
				true
			)
		)
	var report: Dictionary = _value_report(start, output)
	_options = previous_options
	return report


## 将有效节点转换为纯数据描述，不返回内部规则资源。
## [br]
## @api framework_internal
## [br]
## @param node: 当前会话有效类型节点。
## [br]
## @return 按形状展开的类型描述。
## [br]
## @schema node: Dictionary，compile_type 的内部结果。
## [br]
## @schema return: Dictionary，包含 kind、type_name、allow_null 及形状特定字段。
func describe_type(node: Dictionary) -> Dictionary:
	if node.is_empty() or not _step(0, []):
		return {}
	var start: int = _issues.size()
	var names: Array[String] = [
		"scalar",
		"struct",
		"array",
		"map",
		"enum",
		"polymorphic",
	]
	var result: Dictionary = {
		"kind": names[node["kind"]],
		"type_name": node["type_name"],
		"allow_null": node["allow_null"],
	}
	var kind: int = node["kind"]
	match kind:
		GFConfigTypeDefinition.Kind.SCALAR:
			result["scalar_type"] = node["scalar_type"]
		GFConfigTypeDefinition.Kind.STRUCT:
			var descriptions: Array[Dictionary] = []
			for field: Dictionary in node["fields"]:
				var description: Dictionary = _describe_field(field)
				if description.is_empty():
					return {}
				descriptions.append(description)
			result["fields"] = descriptions
			var base: Dictionary = node["base_type"]
			result["base_type"] = null
			if not base.is_empty():
				result["base_type"] = describe_type(base)
			result["base_type_name"] = base.get("type_name", &"")
		GFConfigTypeDefinition.Kind.ARRAY:
			var element_type: Dictionary = node["element_type"]
			result["element_type"] = describe_type(element_type)
		GFConfigTypeDefinition.Kind.MAP:
			result["map_key_type"] = node["map_key_type"]
			var map_value_type: Dictionary = node["map_value_type"]
			result["map_value_type"] = describe_type(map_value_type)
		GFConfigTypeDefinition.Kind.ENUM:
			var enum_symbols: Dictionary = node["symbols"]
			if not _admit_plain(enum_symbols, []):
				return {}
			result["symbols"] = enum_symbols.duplicate()
		GFConfigTypeDefinition.Kind.POLYMORPHIC:
			result["discriminator"] = node["discriminator"]
			var branches: Array[Dictionary] = []
			for branch: Dictionary in node["variants"]:
				var description: Dictionary = describe_type(branch)
				if description.is_empty():
					return {}
				branches.append(description)
			result["variants"] = branches
	return result if not _has_errors(start) and _budget.is_ok() else {}


## 从冻结字段生成只读描述，不执行默认值或业务规则。
## [br]
## @api framework_internal
## [br]
## @param field: 当前会话已编译字段节点。
## [br]
## @return 独立描述；无效节点或预算失败时为空，原因保留在会话报告中。
## [br]
## @schema field: Dictionary，compile_column 的内部结果。
## [br]
## @schema return: Dictionary，包含字段约束、默认值、规则描述及 type_definition 报告。
func describe_column(field: Dictionary) -> Dictionary:
	if field.is_empty() or not _step(0, []):
		return {}
	var result: Dictionary = _describe_field(field)
	return result if _budget.is_ok() else {}


# --- 私有/辅助方法 ---

## 编译基类及本层字段，拒绝重复名并保持基类在前的稳定顺序。
## [br]
## @api private
func _compile_struct(
	definition: GFConfigTypeDefinition,
	node: Dictionary,
	segments: Array,
	depth: int
) -> void:
	var all_fields: Array[Dictionary] = []
	var local_fields: Array[Dictionary] = []
	var base: Dictionary = {}
	var names: Dictionary = {}
	if definition.base_type != null:
		if definition.base_type.kind != GFConfigTypeDefinition.Kind.STRUCT:
			_issue(
				"invalid_base_type",
				"结构只能继承另一结构。",
				segments
			)
		else:
			base = compile_type(
				definition.base_type,
				segments,
				depth + 1
			)
			for field: Dictionary in base.get("fields", []):
				all_fields.append(field)
				names[field["field_name"]] = true
	for column: GFConfigTableColumn in definition.fields:
		if not _step(
			depth + 1,
			segments
		):
			break
		if column == null:
			_issue(
				"invalid_struct_field",
				"结构字段声明为空。",
				segments
			)
			continue
		var field_segments: Array = _child(
			segments,
			str(column.field_name)
		)
		if names.has(column.field_name):
			_issue(
				"duplicate_struct_field",
				"结构字段重复或覆盖了继承字段。",
				field_segments
			)
			continue
		names[column.field_name] = true
		var field: Dictionary = compile_column(
			column,
			field_segments,
			depth + 1
		)
		if not field.is_empty():
			all_fields.append(field)
			local_fields.append(field)
	node["fields"] = all_fields
	node["local_fields"] = local_fields
	node["base_type"] = base


## 检查符号和值都唯一，拒绝隐式数值或空枚举。
## [br]
## @api private
func _compile_enum(
	definition: GFConfigTypeDefinition,
	node: Dictionary,
	segments: Array
) -> void:
	var result: Dictionary = {}
	var values: Dictionary = {}
	if definition.symbols.is_empty():
		_issue(
			"empty_enum",
			"枚举至少需要一个符号。",
			segments
		)
	for key: Variant in definition.symbols:
		if not _step(0, segments):
			break
		if (
			not (
				key is String
				or key is StringName
			)
			or str(key).is_empty()
		):
			_issue(
				"invalid_enum_symbol",
				"枚举符号必须是非空文本。",
				segments
			)
			continue
		var value: Variant = definition.symbols[key]
		if (
			not (value is int)
			or result.has(str(key))
			or values.has(value)
		):
			_issue(
				"invalid_enum_value",
				"枚举符号和整数值必须分别唯一。",
				segments
			)
			continue
		result[str(key)] = value
		values[value] = true
	node["symbols"] = result


## 固定判别字段与分支集合，阻止缺名、重复名和字段冲突。
## [br]
## @api private
func _compile_variants(
	definition: GFConfigTypeDefinition,
	node: Dictionary,
	segments: Array,
	depth: int
) -> void:
	node["discriminator"] = definition.discriminator
	var branches: Array[Dictionary] = []
	var names: Dictionary = {}
	if definition.discriminator == &"" or definition.variants.is_empty():
		_issue(
			"invalid_polymorphic_type",
			"多态类型需要判别字段和至少一个分支。",
			segments
		)
	for resource: Resource in definition.variants:
		if not _step(
			depth + 1,
			segments
		):
			break
		if not (resource is GFConfigTypeDefinition):
			_issue(
				"invalid_polymorphic_branch",
				"多态分支必须是 GFConfigTypeDefinition 结构。",
				segments
			)
			continue
		var variant: GFConfigTypeDefinition = resource
		if variant.kind != GFConfigTypeDefinition.Kind.STRUCT:
			_issue(
				"invalid_polymorphic_branch",
				"多态分支必须是结构。",
				segments
			)
			continue
		if variant.type_name == &"" or names.has(variant.type_name):
			_issue(
				"invalid_polymorphic_name",
				"多态分支名称必须非空且唯一。",
				segments
			)
			continue
		names[variant.type_name] = true
		var branch: Dictionary = compile_type(
			variant,
			segments,
			depth + 1
		)
		for field: Dictionary in branch.get("fields", []):
			if field["field_name"] == definition.discriminator:
				_issue(
					"discriminator_field_collision",
					"判别字段不能与结构字段重名。",
					segments
				)
		branches.append(branch)
	node["variants"] = branches


## 拒绝与形状无关的设置，防止编辑后留下静默无效声明。
## [br]
## @api private
func _validate_unused_members(definition: GFConfigTypeDefinition, segments: Array) -> void:
	if (
		definition.kind != GFConfigTypeDefinition.Kind.STRUCT
		and (
			not definition.fields.is_empty()
			or definition.base_type != null
		)
	):
		_issue(
			"unused_type_member",
			"只有结构可以声明 fields 或 base_type。",
			segments
		)
	if definition.kind != GFConfigTypeDefinition.Kind.ARRAY and definition.element_type != null:
		_issue(
			"unused_type_member",
			"只有数组可以声明 element_type。",
			segments
		)
	if definition.kind != GFConfigTypeDefinition.Kind.MAP and definition.map_value_type != null:
		_issue(
			"unused_type_member",
			"只有映射可以声明 map_value_type。",
			segments
		)
	if definition.kind != GFConfigTypeDefinition.Kind.ENUM and not definition.symbols.is_empty():
		_issue(
			"unused_type_member",
			"只有枚举可以声明 symbols。",
			segments
		)
	if definition.kind != GFConfigTypeDefinition.Kind.POLYMORPHIC and not definition.variants.is_empty():
		_issue(
			"unused_type_member",
			"只有多态类型可以声明 variants。",
			segments
		)


## 先判断字段空值，再递归规范化并用规则副本验证隔离值。
## [br]
## @api private
func _normalize_field(
	field: Dictionary,
	value: Variant,
	segments: Array,
	depth: int,
	coerce: bool
) -> Variant:
	if value == null:
		if not field["allow_null"]:
			_issue(
				"null_value",
				"字段不允许为空。",
				segments
			)
		else:
			var null_rules: Array = field["validation_rules"]
			_run_rules(
				null_rules,
				null,
				segments
			)
		return null
	var node: Dictionary = field["type"]
	var start: int = _issues.size()
	var output: Variant = _normalize_node(
		node,
		value,
		segments,
		depth,
		coerce
	)
	if not _has_errors(start):
		var value_rules: Array = field["validation_rules"]
		_run_rules(
			value_rules,
			output,
			segments
		)
		var element_rules: Array = field["element_validation_rules"]
		if not element_rules.is_empty() and output is Array:
			var elements: Array = output
			_run_element_rules(
				element_rules,
				elements,
				segments
			)
	return output


## 每个节点消费共享预算；容器仅向调用期新集合写入。
## [br]
## @api private
func _normalize_node(
	node: Dictionary,
	value: Variant,
	segments: Array,
	depth: int,
	coerce: bool
) -> Variant:
	if not _step(depth, segments):
		return null
	if value == null:
		if not node["allow_null"]:
			_issue(
				"null_value",
				"类型不允许为空。",
				segments
			)
		return null
	var kind: int = node["kind"]
	match kind:
		GFConfigTypeDefinition.Kind.SCALAR:
			var scalar_type: int = node["scalar_type"]
			return _normalize_scalar(
				scalar_type,
				value,
				segments,
				coerce
			)
		GFConfigTypeDefinition.Kind.ENUM:
			if (
				not (value is int)
				and not (
					coerce
					and (
						value is String
						or value is StringName
					)
					and str(value).is_valid_int()
				)
			):
				_issue(
					"invalid_enum_value",
					"枚举值必须是整数或可转换的整数文本。",
					segments
				)
				return null
			var converted: Variant = _normalize_scalar(
				GFConfigTableColumn.ValueType.INT,
				value,
				segments,
				coerce
			)
			var enum_symbols: Dictionary = node["symbols"]
			if not enum_symbols.values().has(converted):
				_issue(
					"unknown_enum_value",
					"值不属于已声明枚举。",
					segments
				)
			return converted
		GFConfigTypeDefinition.Kind.ARRAY:
			if not (value is Array):
				_issue(
					"invalid_type",
					"数组类型要求 Array。",
					segments
				)
				return null
			var result: Array = []
			var values: Array = value
			var element_type: Dictionary = node["element_type"]
			for index: int in range(values.size()):
				result.append(
					_normalize_node(
						element_type,
						values[index],
						_child(segments, index),
						depth + 1,
						coerce
					)
				)
				if not _budget.is_ok():
					break
			return result
		GFConfigTypeDefinition.Kind.STRUCT:
			return _normalize_struct(
				node,
				value,
				segments,
				depth,
				coerce
			)
		GFConfigTypeDefinition.Kind.MAP:
			return _normalize_map(
				node,
				value,
				segments,
				depth,
				coerce
			)
		GFConfigTypeDefinition.Kind.POLYMORPHIC:
			return _normalize_variant(
				node,
				value,
				segments,
				depth,
				coerce
			)
	return null


## 沿用已有标量转换，严格模式只检查原始类型。
## [br]
## @api private
func _normalize_scalar(
	value_type: int,
	value: Variant,
	segments: Array,
	coerce: bool
) -> Variant:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.value_type = value_type as GFConfigTableColumn.ValueType
	if not coerce:
		if not column.is_value_valid(value):
			_issue(
				"invalid_type",
				"值不符合声明的标量类型。",
				segments
			)
			return null
		return GFVariantData.duplicate_variant(value)
	var report: Dictionary = column.try_coerce_value(value)
	if not report["ok"]:
		var message: String = report["message"]
		_issue(
			"coerce_failed",
			message,
			segments
		)
		return null
	return report["value"]


## 严格拒绝未知字段并在隔离结果中应用可选默认值。
## [br]
## @api private
func _normalize_struct(
	node: Dictionary,
	value: Variant,
	segments: Array,
	depth: int,
	coerce: bool
) -> Variant:
	if not (value is Dictionary):
		_issue(
			"invalid_type",
			"结构类型要求 Dictionary。",
			segments
		)
		return null
	var source: Dictionary = value
	var result: Dictionary = {}
	var declared: Dictionary = {}
	for field: Dictionary in node["fields"]:
		if not _step(
			depth + 1,
			segments
		):
			break
		var name: StringName = field["field_name"]
		declared[name] = true
		var field_segments: Array = _child(
			segments,
			str(name)
		)
		if not source.has(name):
			if field["required"]:
				_issue(
					"missing_required",
					"缺少必填结构字段。",
					field_segments
				)
			if field["default_value"] != null:
				result[name] = _normalize_field(
					field,
					field["default_value"],
					field_segments,
					depth + 1,
					coerce
				)
			continue
		result[name] = _normalize_field(
			field,
			source[name],
			field_segments,
			depth + 1,
			coerce
		)
	for key: Variant in source:
		if not _step(
			depth + 1,
			segments
		):
			break
		if (
			not (
				key is String
				or key is StringName
			)
			or not declared.has(key)
		):
			_issue(
				"extra_field",
				"存在未声明的结构字段。",
				_child(
					segments,
					str(key)
				)
			)
	return result


## 先规范化键并拒绝碰撞，再规范化每个值。
## [br]
## @api private
func _normalize_map(
	node: Dictionary,
	value: Variant,
	segments: Array,
	depth: int,
	coerce: bool
) -> Variant:
	if not (value is Dictionary):
		_issue(
			"invalid_type",
			"映射类型要求 Dictionary。",
			segments
		)
		return null
	var source: Dictionary = value
	var result: Dictionary = {}
	for key: Variant in source:
		if not _step(
			depth + 1,
			segments
		):
			break
		var child_segments: Array = _child(
			segments,
			str(key)
		)
		var start: int = _issues.size()
		var map_key_type: int = node["map_key_type"]
		var normalized_key: Variant = _normalize_scalar(
			map_key_type,
			key,
			child_segments,
			coerce
		)
		if _has_errors(start):
			continue
		if result.has(normalized_key):
			_issue(
				"duplicate_map_key",
				"转换后出现重复的映射键。",
				child_segments
			)
			continue
		var map_value_type: Dictionary = node["map_value_type"]
		result[normalized_key] = _normalize_node(
			map_value_type,
			source[key],
			child_segments,
			depth + 1,
			coerce
		)
	return result


## 判别值必须是已声明的文本名称，移除判别键后验证唯一分支。
## [br]
## @api private
func _normalize_variant(
	node: Dictionary,
	value: Variant,
	segments: Array,
	depth: int,
	coerce: bool
) -> Variant:
	if not (value is Dictionary):
		_issue(
			"invalid_type",
			"多态类型要求 Dictionary。",
			segments
		)
		return null
	var source: Dictionary = value
	var discriminator: StringName = node["discriminator"]
	var tag: Variant = source.get(discriminator)
	if not (tag is String or tag is StringName):
		_issue(
			"missing_discriminator",
			"多态判别字段缺失或不是文本。",
			_child(
				segments,
				str(discriminator)
			)
		)
		return null
	for branch: Dictionary in node["variants"]:
		if not _step(
			depth + 1,
			segments
		):
			return null
		if branch["type_name"] != StringName(str(tag)):
			continue
		var body: Dictionary = source.duplicate()
		var _erased: bool = body.erase(discriminator)
		var converted: Variant = _normalize_struct(
			branch,
			body,
			segments,
			depth + 1,
			coerce
		)
		if converted is Dictionary:
			var result: Dictionary = converted
			result[discriminator] = str(tag)
			return result
		return null
	_issue(
		"unknown_discriminator",
		"没有匹配判别值的多态分支。",
		_child(
			segments,
			str(discriminator)
		)
	)
	return null


## 复制规则后才保存，调用期间不再读取作者资源。
## [br]
## @api private
func _copy_rules(rules: Array[GFConfigValidationRule], segments: Array) -> Array[GFConfigValidationRule]:
	var copied: Array[GFConfigValidationRule] = []
	for rule: GFConfigValidationRule in rules:
		if not _step(0, segments):
			break
		if rule == null:
			_issue(
				"null_validation_rule",
				"字段校验规则为空。",
				segments
			)
			continue
		_track_resource(rule)
		if not GFConfigTypeCopier.admit_rule_copy(rule, _budget):
			_record_budget_failure(segments)
			break
		if not _is_plain(rule.metadata, segments):
			continue
		var duplicate_rule: GFConfigValidationRule = rule.duplicate_rule()
		if duplicate_rule == null:
			_issue(
				"invalid_validation_rule",
				"字段规则无法复制。",
				segments
			)
			continue
		copied.append(duplicate_rule)
	return copied


## 规则只接触值副本，并将完整字段路径附加到既有报告。
## [br]
## @api private
func _run_rules(
	rules: Array,
	value: Variant,
	segments: Array,
	element_index: int = -1
) -> void:
	for rule_value: Variant in rules:
		if not _step(0, segments):
			return
		if not (rule_value is GFConfigValidationRule):
			continue
		var rule: GFConfigValidationRule = rule_value
		var context: Dictionary = _make_rule_context(segments)
		if element_index >= 0:
			context["element_index"] = element_index
		var report: Dictionary = rule.validate_value(
			GFVariantData.duplicate_variant(value),
			context
		)
		for issue_value: Variant in report.get("issues", []):
			if issue_value is Dictionary:
				var source_issue: Dictionary = issue_value
				var issue: Dictionary = source_issue.duplicate(true)
				issue["field_path"] = _path_text(segments)
				issue["field_segments"] = segments.duplicate()
				_enrich_location(issue, segments)
				_issues.append(issue)


## 沿用旧一维元素准入和共享额度，不向元素规则传递嵌套集合。
## [br]
## @api private
func _run_element_rules(
	rules: Array,
	elements: Array,
	segments: Array
) -> void:
	var enabled_rules: Array[GFConfigValidationRule] = []
	for value: Variant in rules:
		if value is GFConfigValidationRule:
			var rule: GFConfigValidationRule = value
			if rule.enabled:
				enabled_rules.append(rule)
	if enabled_rules.is_empty():
		return
	var session: GFConfigElementValidation = GFConfigElementValidation.from_options(_options)
	if not session.reserve(
		elements.size(),
		enabled_rules.size()
	):
		_issue(
			"element_validation_budget_exhausted",
			"数组字段超过本次剩余元素或规则调用预算，未执行该字段的元素规则。",
			segments
		)
		_issues[-1]["expected_value"] = "remaining element and rule-call budgets"
		return
	for index: int in range(elements.size()):
		var child_segments: Array = _child(segments, index)
		if not GFConfigElementValidation.is_value_supported(elements[index]):
			_issue(
				"invalid_element_validation_value",
				"元素必须为单层值，不接受集合、对象或可执行引用。",
				child_segments
			)
			_issues[-1]["element_index"] = index
			_issues[-1]["actual_value"] = type_string(typeof(elements[index]))
			continue
		_run_rules(
			enabled_rules,
			elements[index],
			child_segments,
			index
		)


## 只向规则传递独立诊断值；不暴露编译器、预算或整表来源映射。
##
## 资源路径检查沿用既有共享会话，使重复路径仍受同一批次限额约束。
## [br]
## @api private
func _make_rule_context(segments: Array) -> Dictionary:
	var context: Dictionary = {}
	for key: String in GFConfigValidationReport.CONTEXT_FIELDS:
		if _options.has(key):
			context[key] = GFVariantData.duplicate_variant(_options[key])
	if _options.has("table_name"):
		context["table_name"] = _options["table_name"]
	var path_session_key: StringName = &"__gf_config_resource_path_validation_session"
	if _options.has(path_session_key):
		context[path_session_key] = _options[path_session_key]
	context["field_path"] = _path_text(segments)
	context["field_segments"] = segments.duplicate()
	if not segments.is_empty():
		context["field"] = StringName(str(segments[0]))
	_enrich_location(context, segments)
	return context


## 描述字段时只保留规则的公开描述及纯类型描述。
## [br]
## @api private
func _describe_field(field: Dictionary) -> Dictionary:
	if not _step(0, []):
		return {}
	if not _admit_plain(
		field["default_value"],
		[]
	) or not _admit_plain(
		field["metadata"],
		[]
	):
		return {}
	var start: int = _issues.size()
	var validation_rules: Array = field["validation_rules"]
	var element_validation_rules: Array = field["element_validation_rules"]
	var result: Dictionary = {
		"field_name": field["field_name"],
		"value_type": field["value_type"],
		"required": field["required"],
		"allow_null": field["allow_null"],
		"default_value": GFVariantData.duplicate_variant(field["default_value"]),
		"metadata": GFVariantData.duplicate_variant(field["metadata"]),
		"validation_rules": _describe_rules(validation_rules),
		"element_validation_rules": _describe_rules(element_validation_rules),
		"type_definition": null,
	}
	if field["structured"]:
		var field_type: Dictionary = field["type"]
		var definition: Dictionary = describe_type(field_type)
		var report: Dictionary = _report_since(start)
		report["definition"] = definition if report["ok"] else {}
		result["type_definition"] = report
	return result if not _has_errors(start) and _budget.is_ok() else {}


## 只输出规则描述，不把可执行资源泄漏到生成计划。
## [br]
## @api private
func _describe_rules(rules: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule_value: Variant in rules:
		if not _step(0, []):
			break
		if rule_value is GFConfigValidationRule:
			var rule: GFConfigValidationRule = rule_value
			if not GFConfigTypeCopier.admit_rule_copy(rule, _budget):
				_record_budget_failure([])
				break
			var description: Dictionary = rule.describe()
			if not _admit_plain(description, []):
				break
			result.append(description)
	return result


## 既有预算先拒绝循环及超大值，随后拒绝配置结构中的对象。
## [br]
## @api private
func _admit_plain(value: Variant, segments: Array) -> bool:
	if not _budget.admit_value(
		value,
		_path_text(segments)
	):
		_record_budget_failure(segments)
		return false
	return _is_plain(value, segments)


## 已有预算确认无环后检查集合内所有值不含运行时对象。
## [br]
## @api private
func _is_plain(value: Variant, segments: Array) -> bool:
	if not _step(0, segments):
		return false
	if typeof(value) in [
		TYPE_OBJECT,
		TYPE_CALLABLE,
		TYPE_SIGNAL,
		TYPE_RID,
	]:
		_issue(
			"unsupported_structured_value",
			"结构化配置不接受对象或运行时句柄。",
			segments
		)
		return false
	if value is Array:
		var values: Array = value
		for index: int in range(values.size()):
			if not _is_plain(
				values[index],
				_child(segments, index)
			):
				return false
	if value is Dictionary:
		var values: Dictionary = value
		for key: Variant in values:
			if not _is_plain(key, segments) or not _is_plain(
				values[key],
				_child(
					segments,
					str(key)
				)
			):
				return false
	return true


## 每步先检查深度再消费工作预算，失败只保留一个预算问题。
## [br]
## @api private
func _step(depth: int, segments: Array) -> bool:
	if _budget.check_depth(
		depth,
		_path_text(segments)
	) and _budget.consume_work(
		1,
		_path_text(segments)
	):
		return true
	_record_budget_failure(segments)
	return false


## 将共享预算的失败转换成普通配置问题，不重新开始预算。
## [br]
## @api private
func _record_budget_failure(segments: Array) -> void:
	if _budget.is_ok() or _budget_reported:
		return
	_budget_reported = true
	var report: Dictionary = _budget.get_report()
	var error_kind: String = report["error_kind"]
	var message: String = report["error"]
	_issue(
		error_kind,
		message,
		segments
	)


## 构造不包含原始大值的定位问题。
## [br]
## @api private
func _issue(
	kind: String,
	message: String,
	segments: Array
) -> void:
	var issue: Dictionary = {
		"severity": "error",
		"kind": kind,
		"message": message,
		"field": StringName(str(segments[0])) if not segments.is_empty() else &"",
		"field_path": _path_text(segments),
		"field_segments": segments.duplicate(),
	}
	for key: String in [
		"table_name",
		"row_key",
		"source",
		"line",
		"column",
		"row_index",
		"column_index",
		"sheet_name",
		"sheet_path",
		"cell",
	]:
		if _options.has(key):
			issue[key] = _options[key]
	_enrich_location(issue, segments)
	_issues.append(issue)


## 按完整叶路径匹配布局来源，不把嵌套失败错误定位到顶层首列。
## [br]
## @api private
func _enrich_location(issue: Dictionary, segments: Array) -> void:
	var locations_value: Variant = _options.get("row_locations")
	if not (locations_value is Array):
		return
	var locations: Array = locations_value
	var row_index: int = GFVariantData.get_option_int(
		_options,
		"row_index",
		-1
	)
	if (
		row_index < 0
		or row_index >= locations.size()
		or not (locations[row_index] is Dictionary)
	):
		return
	var row: Dictionary = locations[row_index]
	var fields_value: Variant = row.get("fields")
	if not (fields_value is Dictionary):
		return
	var fields: Dictionary = fields_value
	var location_value: Variant = fields.get(_path_text(segments))
	if not (location_value is Dictionary):
		return
	var location: Dictionary = location_value
	for key: String in [
		"source",
		"line",
		"column",
		"column_index",
		"sheet_name",
		"sheet_path",
		"cell",
	]:
		if location.has(key):
			issue[key] = location[key]


## 只检查当前操作新产生的问题，允许同批次继续报告后续行。
## [br]
## @api private
func _has_errors(start: int) -> bool:
	for index: int in range(
		start,
		_issues.size()
	):
		if _issues[index].get("severity", "error") != "warning":
			return true
	return false


## 复制当前操作的问题片段，避免调用者修改内部诊断。
## [br]
## @api private
func _report_since(start: int) -> Dictionary:
	var issues: Array[Dictionary] = []
	var errors: int = 0
	var warnings: int = 0
	for index: int in range(
		start,
		_issues.size()
	):
		var issue: Dictionary = _issues[index]
		issues.append(issue.duplicate(true))
		if issue.get("severity", "error") == "warning":
			warnings += 1
		else:
			errors += 1
	return {
		"ok": errors == 0,
		"issues": issues,
		"error_count": errors,
		"warning_count": warnings,
		"table_name": _options.get("table_name", &""),
		"row_count": 0,
	}


## 失败时抹去内部构造的结果，避免外部误用半成品。
## [br]
## @api private
func _value_report(start: int, output: Variant) -> Dictionary:
	_record_budget_failure([])
	var report: Dictionary = _report_since(start if _budget.is_ok() else 0)
	report["value"] = output if report["ok"] else null
	report["message"] = "" if report["ok"] else "结构化配置值无效。"
	return report


## 保留显式路径片段；没有片段时用顶层字段作为起点。
## [br]
## @api private
func _segments(options: Dictionary) -> Array:
	var supplied: Variant = options.get("field_segments", [])
	if supplied is Array:
		var supplied_segments: Array = supplied
		if not supplied_segments.is_empty():
			return supplied_segments.duplicate()
	var field: StringName = GFVariantData.get_option_string_name(options, "field")
	return [str(field)] if field != &"" else []


## 复制路径后追加一段，兄弟分支之间不共享可变路径。
## [br]
## @api private
func _child(segments: Array, segment: Variant) -> Array:
	var result: Array = segments.duplicate()
	result.append(segment)
	return result


## 用字段点号与数组下标产生可读路径，特殊名称保留 JSON 引号。
## [br]
## @api private
func _path_text(segments: Array) -> String:
	var result: String = ""
	for segment: Variant in segments:
		if segment is int:
			result += "[%d]" % segment
		elif str(segment).is_valid_identifier():
			result += ("." if not result.is_empty() else "") + str(segment)
		else:
			result += "[%s]" % JSON.stringify(str(segment))
	return result


## 结构化标量不允许通过 ANY 或无元素定义的容器逃逸类型检查。
## [br]
## @api private
func _is_scalar_type(value_type: int) -> bool:
	return value_type >= GFConfigTableColumn.ValueType.BOOL and value_type <= GFConfigTableColumn.ValueType.COLOR


## 只登记实际读取的资源，避免生成器另做无界资源图遍历。
## [br]
## @api private
func _track_resource(resource: Resource) -> void:
	var identity: int = resource.get_instance_id()
	if not _source_ids.has(identity):
		_source_ids[identity] = true
		_source_resources.append(resource)
