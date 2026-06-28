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

## 默认值。`GFDictionarySchema.apply_defaults()` 会在缺字段时使用。
## [br]
## @api public
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
			return value is float or value is int
		ValueType.STRING:
			return value is String
		ValueType.STRING_NAME:
			return value is StringName
		ValueType.VECTOR2:
			return value is Vector2
		ValueType.VECTOR2I:
			return value is Vector2i
		ValueType.VECTOR3:
			return value is Vector3
		ValueType.VECTOR3I:
			return value is Vector3i
		ValueType.COLOR:
			return value is Color
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


## 将输入值转换为字段要求的类型。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 转换后的值。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @schema return: Variant coerced value.
func coerce_value(value: Variant) -> Variant:
	return GFVariantData.get_option_value(try_coerce_value(value), "value")


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
func _validate_value_into(value: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if value == null:
		if allow_null:
			return
		_add_error(report, &"null_value", "Value cannot be null.", context, null, "non_null", null)
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

func _validate_array_items(values: Array, report: GFValidationReport, context: Dictionary) -> void:
	for index: int in range(values.size()):
		var item_context: Dictionary = _make_array_item_context(context, index)
		array_item_schema._validate_value_into(values[index], report, item_context)


func _validate_rules_into(value: Variant, report: GFValidationReport, context: Dictionary) -> void:
	for rule: GFValidationRule in validation_rules:
		if rule == null:
			continue
		var rule_context: Dictionary = _make_rule_context(context)
		var rule_report: GFValidationReport = rule.validate(value, rule_context)
		_merge_rule_report(report, rule_report, rule_context)


func _make_rule_context(context: Dictionary) -> Dictionary:
	var rule_context: Dictionary = context.duplicate(true)
	if not rule_context.has("subject"):
		rule_context["subject"] = _make_subject(context)
	if not rule_context.has("path") and field_name != &"":
		rule_context["path"] = String(field_name)
	if not rule_context.has("key") and field_name != &"":
		rule_context["key"] = field_name
	return rule_context


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
			issue.key = GFVariantData.get_option_value(context, "key", field_name)
		if issue.subject.is_empty():
			issue.subject = GFVariantData.get_option_string(context, "subject", _make_subject(context))
		var _rule_issue: RefCounted = report.add_issue(issue)


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


func _make_nested_context(context: Dictionary) -> Dictionary:
	var nested_context: Dictionary = context.duplicate(true)
	nested_context["subject"] = _make_subject(context)
	return nested_context


func _make_array_item_context(context: Dictionary, index: int) -> Dictionary:
	var item_context: Dictionary = context.duplicate(true)
	var path: String = GFVariantData.get_option_string(context, "path")
	item_context["path"] = "%s[%d]" % [path, index] if not path.is_empty() else "[%d]" % index
	item_context["key"] = index
	return item_context


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


func _make_coerce_result(ok: bool, coerced_value: Variant, message: String = "") -> Dictionary:
	return {
		"ok": ok,
		"value": coerced_value,
		"message": message,
	}


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


func _try_coerce_vector2(value: Variant) -> Dictionary:
	if value is Vector2:
		return _make_coerce_result(true, value)
	if value is Vector2i:
		var vector2i: Vector2i = value
		return _make_coerce_result(true, Vector2(vector2i.x, vector2i.y))
	return _coerce_vector_from_collection(value, 2, false)


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


func _try_coerce_vector3(value: Variant) -> Dictionary:
	if value is Vector3:
		return _make_coerce_result(true, value)
	if value is Vector3i:
		var vector3i: Vector3i = value
		return _make_coerce_result(true, Vector3(vector3i.x, vector3i.y, vector3i.z))
	return _coerce_vector_from_collection(value, 3, false)


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


func _try_coerce_color(value: Variant) -> Dictionary:
	if value is Color:
		return _make_coerce_result(true, value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if Color.html_is_valid(text):
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


func _variant_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return fallback


func _variant_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		var vector_value: Vector3 = value
		return vector_value
	return fallback
