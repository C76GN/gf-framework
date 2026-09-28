## GFSchemaField: 通用数据字段声明。
##
## 描述一个 Dictionary 字段或数组元素的类型、必填性、空值策略、默认值和可选嵌套 schema。
## 它只表达结构契约，不绑定配置表、黑板、内容包或具体业务字段语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.4.0
class_name GFSchemaField
extends Resource


# --- 枚举 ---

## 字段值类型。
## [br]
## @api public
enum ValueType {
	## 不做类型约束。
	ANY,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数；int 也视为有效。
	FLOAT,
	## String。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## Vector3。
	VECTOR3,
	## Vector3i。
	VECTOR3I,
	## Color。
	COLOR,
	## Dictionary，可选嵌套 GFDictionarySchema。
	DICTIONARY,
	## Array，可选数组元素 GFSchemaField。
	ARRAY,
	## Object。
	OBJECT,
	## Resource。
	RESOURCE,
	## NodePath。
	NODE_PATH,
}


# --- 导出变量 ---

## 字段名。作为数组元素 schema 使用时可为空。
## [br]
## @api public
@export var field_name: StringName = &""

## 字段值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.ANY

## 是否必须出现在所属 Dictionary 中。
## [br]
## @api public
@export var required: bool = false

## 是否允许 null 值。
## [br]
## @api public
@export var allow_null: bool = true

## 默认值。`GFDictionarySchema.apply_defaults()` 会在缺字段且该值可表达时使用；
## 当前 default_value 为 null 且 allow_null 为 false 时视为没有可用默认值。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @schema default_value: Variant default field value.
@export var default_value: Variant = null

## 字典类型字段的嵌套 schema。
## [br]
## @api public
@export var dictionary_schema: GFDictionarySchema = null

## 数组类型字段的元素 schema。
## [br]
## @api public
@export var array_item_schema: GFSchemaField = null

## 可选元数据。GF 不解释其中业务字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary caller-defined schema metadata.
@export var metadata: Dictionary = {}

## 字段级附加校验规则。
## [br]
## 规则在基础类型、空值和嵌套 schema 校验通过后执行，用于表达范围、集合、
## 格式或项目自定义约束，而不把这些策略硬编码进字段类型。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema validation_rules: Array[GFValidationRule] field-level validation rules.
@export var validation_rules: Array[GFValidationRule] = []


# --- 公共方法 ---

## 配置字段声明。
## [br]
## @api public
## [br]
## @param p_field_name: 字段名。
## [br]
## @param p_value_type: 字段值类型。
## [br]
## @param options: 可选配置，支持 required、allow_null、default_value、dictionary_schema、array_item_schema 和 metadata。
## [br]
## @return 当前字段。
## [br]
## @schema options: Dictionary schema field options.
func configure(
	p_field_name: StringName,
	p_value_type: ValueType = ValueType.ANY,
	options: Dictionary = {}
) -> GFSchemaField:
	field_name = p_field_name
	value_type = p_value_type
	required = GFVariantData.get_option_bool(options, "required", required)
	allow_null = GFVariantData.get_option_bool(options, "allow_null", allow_null)
	default_value = GFVariantData.duplicate_variant(GFVariantData.get_option_value(options, "default_value", default_value))
	var dictionary_schema_value: Variant = GFVariantData.get_option_value(options, "dictionary_schema", dictionary_schema)
	if dictionary_schema_value is GFDictionarySchema:
		dictionary_schema = dictionary_schema_value
	var array_item_schema_value: Variant = GFVariantData.get_option_value(options, "array_item_schema", array_item_schema)
	if array_item_schema_value is GFSchemaField:
		array_item_schema = array_item_schema_value
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)
	validation_rules = _read_validation_rules(GFVariantData.get_option_value(options, "validation_rules", validation_rules))
	return self


## 获取稳定字段键。
## [br]
## @api public
## [br]
## @return 字段名。
func get_field_key() -> StringName:
	return field_name


## 检查输入值是否符合字段声明。
## [br]
## @api public
## [br]
## @param value: 待检查值。
## [br]
## @return 符合声明时返回 true。
## [br]
## @schema value: Variant value to validate.
func is_value_valid(value: Variant) -> bool:
	if value == null:
		return allow_null

	match value_type:
		ValueType.ANY:
			return true
		ValueType.BOOL:
			return value is bool
		ValueType.INT:
			return value is int
		ValueType.FLOAT:
			return value is int or _float_is_finite(value)
		ValueType.STRING:
			return value is String
		ValueType.STRING_NAME:
			return value is StringName
		ValueType.VECTOR2:
			return _vector2_is_finite(value)
		ValueType.VECTOR2I:
			return value is Vector2i
		ValueType.VECTOR3:
			return _vector3_is_finite(value)
		ValueType.VECTOR3I:
			return value is Vector3i
		ValueType.COLOR:
			return _color_is_finite(value)
		ValueType.DICTIONARY:
			return value is Dictionary
		ValueType.ARRAY:
			return value is Array
		ValueType.OBJECT:
			return value is Object
		ValueType.RESOURCE:
			return value is Resource
		ValueType.NODE_PATH:
			return value is NodePath
		_:
			return true


## 将输入值转换为字段要求的类型；转换失败时返回输入值副本。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param value: 输入值。
## [br]
## @return 转换后的值；失败时为输入值副本。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @schema return: Variant coerced value.
func coerce_value(value: Variant) -> Variant:
	var result: Dictionary = try_coerce_value(value)
	if GFVariantData.get_option_bool(result, "ok", false):
		return GFVariantData.get_option_value(result, "value")
	return GFVariantData.duplicate_variant(value)


## 尝试转换输入值并返回转换报告。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 包含 ok、value、message 的转换报告。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @schema return: Dictionary with ok, value, and message.
func try_coerce_value(value: Variant) -> Dictionary:
	if value == null:
		return _make_coerce_result(true, null)

	match value_type:
		ValueType.BOOL:
			return _try_coerce_bool(value)
		ValueType.INT:
			return _try_coerce_int(value)
		ValueType.FLOAT:
			return _try_coerce_float(value)
		ValueType.STRING:
			return _make_coerce_result(true, str(value))
		ValueType.STRING_NAME:
			return _make_coerce_result(true, StringName(str(value)))
		ValueType.VECTOR2:
			return _try_coerce_vector2(value)
		ValueType.VECTOR2I:
			return _try_coerce_vector2i(value)
		ValueType.VECTOR3:
			return _try_coerce_vector3(value)
		ValueType.VECTOR3I:
			return _try_coerce_vector3i(value)
		ValueType.COLOR:
			return _try_coerce_color(value)
		ValueType.DICTIONARY:
			if value is Dictionary:
				return _make_coerce_result(true, GFVariantData.to_dictionary(value))
			return _make_coerce_result(false, {}, "Value cannot be coerced to Dictionary.")
		ValueType.ARRAY:
			if value is Array:
				return _make_coerce_result(true, GFVariantData.to_array(value))
			return _make_coerce_result(false, [], "Value cannot be coerced to Array.")
		ValueType.OBJECT:
			if value is Object:
				return _make_coerce_result(true, value)
			return _make_coerce_result(false, null, "Value cannot be coerced to Object.")
		ValueType.RESOURCE:
			if value is Resource:
				return _make_coerce_result(true, value)
			return _make_coerce_result(false, null, "Value cannot be coerced to Resource.")
		ValueType.NODE_PATH:
			return _make_coerce_result(true, NodePath(str(value)))
		_:
			return _make_coerce_result(true, GFVariantData.duplicate_variant(value))


## 校验字段值并返回报告。
## [br]
## @api public
## [br]
## @param value: 待校验值。
## [br]
## @param context: 可选上下文，支持 subject、path、key 和 schema_id。
## [br]
## @return 校验报告。
## [br]
## @schema value: Variant value to validate.
## [br]
## @schema context: Dictionary validation context.
func validate_value(value: Variant, context: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(_make_subject(context), {
		"schema_id": GFVariantData.get_option_string(context, "schema_id"),
	})
	var definition_schema: GFDictionarySchema = GFDictionarySchema.new()
	definition_schema._validate_field_definition_into(self, report, context)
	if not report.is_ok():
		return report
	_validate_value_into(value, report, context)
	return report


## 添加字段级校验规则。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param rule: 校验规则。
## [br]
## @return 添加成功返回 true。
func add_validation_rule(rule: GFValidationRule) -> bool:
	if rule == null:
		return false
	validation_rules.append(rule)
	return true


## 获取启用的字段级校验规则。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 规则数组副本。
func get_enabled_validation_rules() -> Array[GFValidationRule]:
	var result: Array[GFValidationRule] = []
	for rule: GFValidationRule in validation_rules:
		if rule != null and rule.enabled:
			result.append(rule)
	return result


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新字段声明。
func duplicate_field() -> GFSchemaField:
	return _duplicate_field_with_context({
		"schemas": {},
		"fields": {},
	})


## 导出字段声明摘要。
## [br]
## @api public
## [br]
## @return 字段声明字典。
## [br]
## @schema return: Dictionary schema field description.
func describe() -> Dictionary:
	return {
		"field_name": field_name,
		"value_type": value_type,
		"value_type_name": value_type_to_name(value_type),
		"required": required,
		"allow_null": allow_null,
		"default_value": GFVariantData.duplicate_variant(default_value),
		"has_dictionary_schema": dictionary_schema != null,
		"has_array_item_schema": array_item_schema != null,
		"metadata": metadata.duplicate(true),
		"validation_rules": _describe_validation_rules(),
	}


## 将字段类型转换为稳定名称。
## [br]
## @api public
## [br]
## @param type_id: 字段类型。
## [br]
## @return 类型名称。
static func value_type_to_name(type_id: ValueType) -> String:
	match type_id:
		ValueType.BOOL:
			return "bool"
		ValueType.INT:
			return "int"
		ValueType.FLOAT:
			return "float"
		ValueType.STRING:
			return "string"
		ValueType.STRING_NAME:
			return "string_name"
		ValueType.VECTOR2:
			return "vector2"
		ValueType.VECTOR2I:
			return "vector2i"
		ValueType.VECTOR3:
			return "vector3"
		ValueType.VECTOR3I:
			return "vector3i"
		ValueType.COLOR:
			return "color"
		ValueType.DICTIONARY:
			return "dictionary"
		ValueType.ARRAY:
			return "array"
		ValueType.OBJECT:
			return "object"
		ValueType.RESOURCE:
			return "resource"
		ValueType.NODE_PATH:
			return "node_path"
		_:
			return "any"


# --- 框架内部方法 ---

# 将字段校验结果写入传入报告。仅供 GF schema 组合内部调用。
## 将字段值检查追加到报告；空值、非有限数值和类型错误各自提前结束，合法值继续执行嵌套 schema 与字段规则。此入口不负责类型转换。
## [br]
## @api framework_internal
## [br]
## @layer standard/foundation/schema
## [br]
## @param value: 按当前字段定义检查的值。
## [br]
## @param report: 接收字段及嵌套问题的报告。
## [br]
## @param context: 字段路径、问题键、来源及递归检测上下文。
## [br]
## @schema value: 由 value_type 指定的值类型；null 是否允许由 allow_null 决定。
## [br]
## @schema context: 可含 path、key、subject、schema_id、source_path/source、line、column 及嵌套校验传递的内部活动状态。
func _validate_value_into(value: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if value == null:
		if allow_null:
			return
		_add_error(report, &"null_value", "Value cannot be null.", context, null, "non_null", null)
		return
	if _is_non_finite_numeric_value(value):
		_add_error(
			report,
			&"non_finite_value",
			"Numeric schema values must contain only finite components.",
			context,
			value,
			"finite_numeric_value",
			typeof(value)
		)
		return

	if not is_value_valid(value):
		_add_error(
			report,
			&"invalid_type",
			"Value type does not match schema field.",
			context,
			value,
			value_type_to_name(value_type),
			typeof(value)
		)
		return

	if value_type == ValueType.DICTIONARY and dictionary_schema != null:
		var dictionary_value: Dictionary = GFVariantData.as_dictionary(value)
		var nested_report: GFValidationReport = dictionary_schema.validate_dictionary(dictionary_value, _make_nested_context(context))
		var _merged_dictionary_report: RefCounted = report.merge(nested_report)
	elif value_type == ValueType.ARRAY and array_item_schema != null:
		_validate_array_items(GFVariantData.as_array(value), report, context)

	_validate_rules_into(value, report, context)


## 按共享身份映射复制字段图；先登记副本再递归复制字典和数组子定义，避免循环并保留共享身份。默认值走 Variant 复制入口，元数据深复制，规则逐项调用 duplicate_rule。
## [br]
## @api framework_internal
## [br]
## @layer standard/foundation/schema
## [br]
## @param state: 本次图复制共享并原地更新的身份映射。
## [br]
## @return: 字段副本；已有映射时复用同一副本。
## [br]
## @schema state: 包含 fields 和 schemas 字典，以源字段/schema 实例 ID 索引对应副本。
func _duplicate_field_with_context(state: Dictionary) -> GFSchemaField:
	var field_key: int = get_instance_id()
	var visited_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "fields", {}))
	if visited_fields.has(field_key):
		var existing_field: Variant = visited_fields[field_key]
		if existing_field is GFSchemaField:
			return existing_field

	var field: GFSchemaField = GFSchemaField.new()
	visited_fields[field_key] = field
	state["fields"] = visited_fields
	field.field_name = field_name
	field.value_type = value_type
	field.required = required
	field.allow_null = allow_null
	field.default_value = GFVariantData.duplicate_variant(default_value)
	field.dictionary_schema = null
	if dictionary_schema != null:
		field.dictionary_schema = dictionary_schema._duplicate_schema(state)
	field.array_item_schema = null
	if array_item_schema != null:
		field.array_item_schema = array_item_schema._duplicate_field_with_context(state)
	field.metadata = metadata.duplicate(true)
	for rule: GFValidationRule in validation_rules:
		field.validation_rules.append(rule.duplicate_rule() if rule != null else null)
	return field


# --- 私有/辅助方法 ---

## 按 value_type 检查浮点数、向量或颜色中是否含 NaN/INF 分量。
## [br]
## @api private
func _is_non_finite_numeric_value(value: Variant) -> bool:
	match value_type:
		ValueType.FLOAT:
			return value is float and not _float_is_finite(value)
		ValueType.VECTOR2:
			return value is Vector2 and not _vector2_is_finite(value)
		ValueType.VECTOR3:
			return value is Vector3 and not _vector3_is_finite(value)
		ValueType.COLOR:
			return value is Color and not _color_is_finite(value)
	return false


## 仅对 float Variant 检查 is_finite；其他类型返回 false。
## [br]
## @api private
func _float_is_finite(value: Variant) -> bool:
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value)


## 确认值为 Vector2 后检查两个分量均有限。
## [br]
## @api private
func _vector2_is_finite(value: Variant) -> bool:
	if not value is Vector2:
		return false
	var vector: Vector2 = value
	return is_finite(vector.x) and is_finite(vector.y)


## 确认值为 Vector3 后检查三个分量均有限。
## [br]
## @api private
func _vector3_is_finite(value: Variant) -> bool:
	if not value is Vector3:
		return false
	var vector: Vector3 = value
	return is_finite(vector.x) and is_finite(vector.y) and is_finite(vector.z)


## 确认值为 Color 后检查 RGBA 四个分量均有限。
## [br]
## @api private
func _color_is_finite(value: Variant) -> bool:
	if not value is Color:
		return false
	var color: Color = value
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)


## 为数组中的每项生成索引上下文，并委托 array_item_schema 校验。
## [br]
## @api private
func _validate_array_items(values: Array, report: GFValidationReport, context: Dictionary) -> void:
	for index: int in range(values.size()):
		var item_context: Dictionary = _make_array_item_context(context, index)
		array_item_schema._validate_value_into(values[index], report, item_context)


## 逐个执行非空校验规则并把规则报告合并到字段报告。
## [br]
## @api private
func _validate_rules_into(value: Variant, report: GFValidationReport, context: Dictionary) -> void:
	for rule: GFValidationRule in validation_rules:
		if rule == null:
			continue
		var rule_context: Dictionary = _make_rule_context(context)
		var rule_report: GFValidationReport = rule.validate(value, rule_context)
		_merge_rule_report(report, rule_report, rule_context)


## 深拷贝上下文，并在缺失时填入 subject、字段 path 和 key。
## [br]
## @api private
func _make_rule_context(context: Dictionary) -> Dictionary:
	var rule_context: Dictionary = context.duplicate(true)
	if not rule_context.has("subject"):
		rule_context["subject"] = _make_subject(context)
	if not rule_context.has("path") and field_name != &"":
		rule_context["path"] = String(field_name)
	if not rule_context.has("key") and field_name != &"":
		rule_context["key"] = field_name
	return rule_context


## 忽略空报告和非 GFValidationIssue 项；为缺少 path、key、subject 的规则问题补齐上下文后合并。
## [br]
## @api private
func _merge_rule_report(report: GFValidationReport, rule_report: GFValidationReport, context: Dictionary) -> void:
	if rule_report == null:
		return
	for issue_ref: RefCounted in rule_report.issues:
		if not (issue_ref is GFValidationIssue):
			continue
		var issue: GFValidationIssue = issue_ref
		if issue.path.is_empty():
			issue.path = GFVariantData.get_option_string(context, "path", String(field_name))
		if issue.key == null:
			issue.key = GFVariantData.duplicate_variant(
				GFVariantData.get_option_value(context, "key", field_name)
			)
		if issue.subject.is_empty():
			issue.subject = GFVariantData.get_option_string(context, "subject", _make_subject(context))
		var _rule_issue: RefCounted = report.add_issue(issue)


## 按 subject、schema_id、field_name 的顺序选择主题，均缺失时使用 GFSchemaField。
## [br]
## @api private
func _make_subject(context: Dictionary) -> String:
	var subject: String = GFVariantData.get_option_string(context, "subject")
	if not subject.is_empty():
		return subject
	var schema_id: String = GFVariantData.get_option_string(context, "schema_id")
	if not schema_id.is_empty():
		return schema_id
	if field_name != &"":
		return String(field_name)
	return "GFSchemaField"


## 深拷贝嵌套上下文，并将 subject 设为当前字段的解析主题。
## [br]
## @api private
func _make_nested_context(context: Dictionary) -> Dictionary:
	var nested_context: Dictionary = context.duplicate(true)
	nested_context["subject"] = _make_subject(context)
	return nested_context


## 深拷贝数组项上下文，设置索引路径和 key；空根路径时使用 [index]。
## [br]
## @api private
func _make_array_item_context(context: Dictionary, index: int) -> Dictionary:
	var item_context: Dictionary = context.duplicate(true)
	var path: String = GFVariantData.get_option_string(context, "path")
	item_context["path"] = "%s[%d]" % [path, index] if not path.is_empty() else "[%d]" % index
	item_context["key"] = index
	return item_context


## 构造包含字段元数据和上下文位置的错误，并把 source、行列及主题信息应用到 issue。
## [br]
## @api private
func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	context: Dictionary,
	actual_value: Variant = null,
	expected_value: Variant = null,
	actual_type: Variant = null
) -> void:
	var issue_metadata: Dictionary = metadata.duplicate(true)
	issue_metadata["schema_id"] = GFVariantData.get_option_string(context, "schema_id")
	issue_metadata["field_name"] = String(field_name)
	issue_metadata["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	issue_metadata["actual_value"] = GFVariantData.duplicate_variant(actual_value)
	issue_metadata["actual_type"] = GFVariantData.duplicate_variant(actual_type)
	var issue_key: Variant = GFVariantData.get_option_value(context, "key", field_name)
	var issue_path: String = GFVariantData.get_option_string(context, "path", String(field_name))
	var issue: RefCounted = report.add_error(kind, message, issue_key, issue_path, issue_metadata)
	_apply_context_to_issue(issue, context)


## 对 GFValidationIssue 应用来源路径、行、列和主题；source_path 为空时可用 source 补入。
## 非 GFValidationIssue 输入不作修改。
## [br]
## @api private
func _apply_context_to_issue(issue: RefCounted, context: Dictionary) -> void:
	if not (issue is GFValidationIssue):
		return
	var validation_issue: GFValidationIssue = issue
	validation_issue.source_path = GFVariantData.get_option_string(context, "source_path", validation_issue.source_path)
	if validation_issue.source_path.is_empty():
		validation_issue.source_path = GFVariantData.get_option_string(context, "source", validation_issue.source_path)
	validation_issue.line = GFVariantData.get_option_int(context, "line", validation_issue.line)
	validation_issue.column = GFVariantData.get_option_int(context, "column", validation_issue.column)
	validation_issue.subject = GFVariantData.get_option_string(context, "subject", validation_issue.subject)


## 统一返回转换成功标记、转换值和诊断消息。
## [br]
## @api private
func _make_coerce_result(ok: bool, coerced_value: Variant, message: String = "") -> Dictionary:
	return {
		"ok": ok,
		"value": coerced_value,
		"message": message,
	}


## 只接收 Array 输入，并从中筛选 GFValidationRule 项。
## [br]
## @api private
func _read_validation_rules(value: Variant) -> Array[GFValidationRule]:
	var result: Array[GFValidationRule] = []
	if not (value is Array):
		return result
	var source_rules: Array = value
	for rule_variant: Variant in source_rules:
		if rule_variant is GFValidationRule:
			var rule: GFValidationRule = rule_variant
			result.append(rule)
	return result


## 为每条规则生成 describe() 字典；null 规则保留为 valid=false 项。
## [br]
## @api private
func _describe_validation_rules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule: GFValidationRule in validation_rules:
		if rule == null:
			result.append({
				"valid": false,
			})
			continue
		result.append(rule.describe())
	return result


## 将 bool、数值或 true/false、1/0、yes/no、on/off 文本转换为 bool。
## [br]
## @api private
func _try_coerce_bool(value: Variant) -> Dictionary:
	if value is bool:
		var bool_value: bool = value
		return _make_coerce_result(true, bool_value)
	if value is int or value is float:
		return _make_coerce_result(true, GFVariantData.to_float(value, 0.0) != 0.0)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			return _make_coerce_result(true, true)
		if text in ["false", "0", "no", "off"]:
			return _make_coerce_result(true, false)
	return _make_coerce_result(false, false, "Value cannot be coerced to bool.")


## 将 int、bool、有限 float 或有效整数文本转换为 int；其他输入返回失败结果。
## [br]
## @api private
func _try_coerce_int(value: Variant) -> Dictionary:
	if value is int or value is bool:
		return _make_coerce_result(true, GFVariantData.to_int(value, 0))
	if value is float:
		var float_value: float = GFVariantData.to_float(value, 0.0)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0, "Value cannot be coerced to int.")
		return _make_coerce_result(true, int(float_value))
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if text.is_valid_int():
			return _make_coerce_result(true, text.to_int())
	return _make_coerce_result(false, 0, "Value cannot be coerced to int.")


## 将 int、bool、有限 float 或有效浮点文本转换为有限 float。
## [br]
## @api private
func _try_coerce_float(value: Variant) -> Dictionary:
	if value is float or value is int or value is bool:
		var float_value: float = GFVariantData.to_float(value, 0.0)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0.0, "Value cannot be coerced to float.")
		return _make_coerce_result(true, float_value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if text.is_valid_float():
			return _make_coerce_result(true, text.to_float())
	return _make_coerce_result(false, 0.0, "Value cannot be coerced to float.")


## 保留 Vector2，或把 Vector2i/数字集合转换为 Vector2。
## [br]
## @api private
func _try_coerce_vector2(value: Variant) -> Dictionary:
	if value is Vector2:
		return _make_coerce_result(true, value)
	if value is Vector2i:
		var vector2i: Vector2i = value
		return _make_coerce_result(true, Vector2(vector2i.x, vector2i.y))
	return _coerce_vector_from_collection(value, 2, false)


## 保留 Vector2i；把 Vector2 或由字典/数组转换出的 Vector2 分量四舍五入为 Vector2i。
## [br]
## @api private
func _try_coerce_vector2i(value: Variant) -> Dictionary:
	if value is Vector2i:
		return _make_coerce_result(true, value)
	if value is Vector2:
		var vector2: Vector2 = value
		return _make_coerce_result(true, Vector2i(roundi(vector2.x), roundi(vector2.y)))
	var result: Dictionary = _coerce_vector_from_collection(value, 2, true)
	if GFVariantData.get_option_bool(result, "ok", false):
		var vector: Vector2 = _variant_to_vector2(GFVariantData.get_option_value(result, "value"), Vector2.ZERO)
		result["value"] = Vector2i(roundi(vector.x), roundi(vector.y))
	return result


## 保留 Vector3，或把 Vector3i/数字集合转换为 Vector3。
## [br]
## @api private
func _try_coerce_vector3(value: Variant) -> Dictionary:
	if value is Vector3:
		return _make_coerce_result(true, value)
	if value is Vector3i:
		var vector3i: Vector3i = value
		return _make_coerce_result(true, Vector3(vector3i.x, vector3i.y, vector3i.z))
	return _coerce_vector_from_collection(value, 3, false)


## 保留 Vector3i；把 Vector3 或由字典/数组转换出的 Vector3 分量四舍五入为 Vector3i。
## [br]
## @api private
func _try_coerce_vector3i(value: Variant) -> Dictionary:
	if value is Vector3i:
		return _make_coerce_result(true, value)
	if value is Vector3:
		var vector3: Vector3 = value
		return _make_coerce_result(true, Vector3i(roundi(vector3.x), roundi(vector3.y), roundi(vector3.z)))
	var result: Dictionary = _coerce_vector_from_collection(value, 3, true)
	if GFVariantData.get_option_bool(result, "ok", false):
		var vector: Vector3 = _variant_to_vector3(GFVariantData.get_option_value(result, "value"), Vector3.ZERO)
		result["value"] = Vector3i(roundi(vector.x), roundi(vector.y), roundi(vector.z))
	return result


## 保留 Color，解析有效 HTML 颜色文本，或从 r/g/b/a 字典与数组读取数值通道。
## 集合缺少 alpha 时默认值为 1.0。
## [br]
## @api private
func _try_coerce_color(value: Variant) -> Dictionary:
	if value is Color:
		return _make_coerce_result(true, value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if text.begins_with("#") and Color.html_is_valid(text):
			return _make_coerce_result(true, Color.html(text))
		return _make_coerce_result(false, Color.WHITE, "Value cannot be coerced to Color.")

	var channels: Dictionary = _read_numeric_fields(value, ["r", "g", "b", "a"], 3, 1.0)
	if not GFVariantData.get_option_bool(channels, "ok", false):
		return _make_coerce_result(false, Color.WHITE, "Value cannot be coerced to Color.")
	var values: Array = GFVariantData.get_option_array(channels, "values")
	return _make_coerce_result(
		true,
		Color(
			GFVariantData.to_float(values[0], 0.0),
			GFVariantData.to_float(values[1], 0.0),
			GFVariantData.to_float(values[2], 0.0),
			GFVariantData.to_float(values[3], 1.0)
		)
	)


## 从字典或数组读取所需的 x/y[/z] 数值并构造 Vector2/Vector3；失败时返回对应零向量。
## 当前实现不使用 _integer 参数，整数向量由调用方随后取整。
## [br]
## @api private
func _coerce_vector_from_collection(value: Variant, size: int, _integer: bool) -> Dictionary:
	var all_fields: Array[String] = ["x", "y", "z"]
	var fields: Array[String] = []
	for index: int in range(mini(size, all_fields.size())):
		fields.append(all_fields[index])
	var channels: Dictionary = _read_numeric_fields(value, fields, size, 0.0)
	if not GFVariantData.get_option_bool(channels, "ok", false):
		var fallback_value: Variant = Vector3.ZERO
		if size != 3:
			fallback_value = Vector2.ZERO
		return _make_coerce_result(false, fallback_value, "Value cannot be coerced to Vector.")

	var values: Array = GFVariantData.get_option_array(channels, "values")
	if size == 3:
		return _make_coerce_result(
			true,
			Vector3(
				GFVariantData.to_float(values[0], 0.0),
				GFVariantData.to_float(values[1], 0.0),
				GFVariantData.to_float(values[2], 0.0)
			)
		)
	return _make_coerce_result(
		true,
		Vector2(
			GFVariantData.to_float(values[0], 0.0),
			GFVariantData.to_float(values[1], 0.0)
		)
	)


## 从字典字段或数组元素逐项转换有限数值；长度不足或任一项转换失败时返回 ok=false。
## 字典可对 required_size 之后的字段使用 default_last；数组缺少的尾项也使用该默认值。
## [br]
## @api private
func _read_numeric_fields(value: Variant, field_names: Array, required_size: int, default_last: float) -> Dictionary:
	var values: Array[float] = []
	if value is Dictionary:
		var data: Dictionary = value
		for index: int in range(field_names.size()):
			var numeric_field_name: String = GFVariantData.to_text(field_names[index], "")
			var fallback_value: Variant = null
			if index >= required_size:
				fallback_value = default_last
			var coerced: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, numeric_field_name, fallback_value))
			if not GFVariantData.get_option_bool(coerced, "ok", false):
				return { "ok": false, "values": [] }
			values.append(GFVariantData.get_option_float(coerced, "value", 0.0))
		return { "ok": true, "values": values }
	if value is Array:
		var array: Array = value
		if array.size() < required_size:
			return { "ok": false, "values": [] }
		for index: int in range(field_names.size()):
			var raw_value: Variant = default_last
			if index < array.size():
				raw_value = array[index]
			var coerced: Dictionary = _try_coerce_float(raw_value)
			if not GFVariantData.get_option_bool(coerced, "ok", false):
				return { "ok": false, "values": [] }
			values.append(GFVariantData.get_option_float(coerced, "value", 0.0))
		return { "ok": true, "values": values }
	return { "ok": false, "values": [] }


## 返回 Vector2 输入本身，否则返回给定回退向量。
## [br]
## @api private
func _variant_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return fallback


## 返回 Vector3 输入本身，否则返回给定回退向量。
## [br]
## @api private
func _variant_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		var vector_value: Vector3 = value
		return vector_value
	return fallback
