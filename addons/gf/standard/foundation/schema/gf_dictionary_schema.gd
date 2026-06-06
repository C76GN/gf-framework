## GFDictionarySchema: 通用 Dictionary 结构声明与校验器。
##
## 为任意 Dictionary 提供字段声明、默认值补齐、类型转换、嵌套结构校验和定义自检。
## 它只描述数据形态，不包含配置表索引、跨表引用、内容包启用策略或游戏业务规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.4.0
class_name GFDictionarySchema
extends Resource


# --- 导出变量 ---

## Schema 标识。为空时可由调用方自行决定报告主题。
## [br]
## @api public
@export var schema_id: StringName = &""

## 字段声明列表。
## [br]
## @api public
## [br]
## @schema fields: Array[GFSchemaField] declared Dictionary fields.
@export var fields: Array[GFSchemaField] = []

## 是否允许包含 schema 未声明的字段。
## [br]
## @api public
@export var allow_extra_fields: bool = true

## 是否在校验前按字段声明尝试类型转换。
## [br]
## @api public
@export var coerce_values: bool = false

## 启用 coerce_values 时，转换失败是否作为校验错误。
## [br]
## @api public
@export var fail_on_coerce_error: bool = true

## 可选元数据。GF 不解释其中业务字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary caller-defined schema metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置 schema。
## [br]
## @api public
## [br]
## @param p_schema_id: Schema 标识。
## [br]
## @param p_fields: 字段声明列表。
## [br]
## @param options: 可选配置，支持 allow_extra_fields、coerce_values、fail_on_coerce_error 和 metadata。
## [br]
## @return 当前 schema。
## [br]
## @schema p_fields: Array[GFSchemaField] declared Dictionary fields.
## [br]
## @schema options: Dictionary schema options.
func configure(
	p_schema_id: StringName,
	p_fields: Array[GFSchemaField] = [],
	options: Dictionary = {}
) -> GFDictionarySchema:
	schema_id = p_schema_id
	fields = []
	for field: GFSchemaField in p_fields:
		fields.append(field)
	allow_extra_fields = GFVariantData.get_option_bool(options, "allow_extra_fields", allow_extra_fields)
	coerce_values = GFVariantData.get_option_bool(options, "coerce_values", coerce_values)
	fail_on_coerce_error = GFVariantData.get_option_bool(options, "fail_on_coerce_error", fail_on_coerce_error)
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)
	return self


## 添加字段声明。
## [br]
## @api public
## [br]
## @param field: 字段声明。
## [br]
## @return 添加成功返回 true。
func add_field(field: GFSchemaField) -> bool:
	if field == null or field.get_field_key() == &"" or has_field(field.get_field_key()):
		return false
	fields.append(field)
	return true


## 获取字段声明。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 找到时返回字段声明，否则返回 null。
func get_field(field_name: StringName) -> GFSchemaField:
	for field: GFSchemaField in fields:
		if field != null and field.get_field_key() == field_name:
			return field
	return null


## 检查字段声明是否存在。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 存在返回 true。
func has_field(field_name: StringName) -> bool:
	return get_field(field_name) != null


## 获取当前 schema 的字段名列表。
## [br]
## @api public
## [br]
## @return 排序后的字段名。
func get_field_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for field: GFSchemaField in fields:
		if field != null and field.get_field_key() != &"":
			var _append_result: bool = result.append(String(field.get_field_key()))
	result.sort()
	return result


## 创建默认 Dictionary。
## [br]
## @api public
## [br]
## @param include_optional: 为 true 时包含非必填字段。
## [br]
## @return 默认数据字典。
## [br]
## @schema return: Dictionary default values.
func build_defaults(include_optional: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue
		if field.required or include_optional:
			result[field.get_field_key()] = field.coerce_value(field.default_value)
	return result


## 为输入 Dictionary 补齐默认值。
## [br]
## @api public
## [br]
## @param values: 输入字典。
## [br]
## @param include_optional: 为 true 时补齐非必填字段。
## [br]
## @param should_coerce: 为 true 时按字段声明转换已有值和默认值。
## [br]
## @return 补齐后的新字典。
## [br]
## @schema values: Dictionary source values.
## [br]
## @schema return: Dictionary normalized values.
func apply_defaults(values: Dictionary, include_optional: bool = true, should_coerce: bool = true) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue

		var field_key: StringName = field.get_field_key()
		if result.has(field_key):
			if should_coerce:
				result[field_key] = field.coerce_value(result[field_key])
			continue
		if field.required or include_optional:
			if should_coerce:
				result[field_key] = field.coerce_value(field.default_value)
			else:
				result[field_key] = GFVariantData.duplicate_variant(field.default_value)
	return result


## 按字段声明转换 Dictionary。
## [br]
## @api public
## [br]
## @param values: 输入字典。
## [br]
## @param include_defaults: 为 true 时同时补默认值。
## [br]
## @return 转换后的新字典。
## [br]
## @schema values: Dictionary source values.
## [br]
## @schema return: Dictionary coerced values.
func coerce_dictionary(values: Dictionary, include_defaults: bool = true) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	if include_defaults:
		result = apply_defaults(values, include_defaults, false)
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"" or not result.has(field.get_field_key()):
			continue
		result[field.get_field_key()] = field.coerce_value(result[field.get_field_key()])
	return result


## 校验 schema 自身声明。
## [br]
## @api public
## [br]
## @param options: 可选上下文，支持 subject、source_path 和 source。
## [br]
## @return 校验报告。
## [br]
## @schema options: Dictionary validation context.
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = _make_report(options)
	var root_path: String = GFVariantData.get_option_string(options, "path")
	var seen_fields: Dictionary = {}
	for index: int in range(fields.size()):
		var field: GFSchemaField = fields[index]
		if field == null:
			var _null_issue: RefCounted = report.add_error(&"null_field", "Schema field is null.", index, _make_path(root_path, index), _make_definition_metadata(index))
			continue

		var field_key: StringName = field.get_field_key()
		if field_key == &"":
			var _empty_issue: RefCounted = report.add_error(&"empty_field_name", "Schema field name is empty.", index, _make_path(root_path, index), _make_definition_metadata(index))
			continue
		if seen_fields.has(field_key):
			var _duplicate_issue: RefCounted = report.add_error(&"duplicate_field_name", "Schema field name is duplicated.", field_key, _make_definition_field_path(field_key, root_path), _make_definition_metadata(index))
		seen_fields[field_key] = true
		_validate_nested_field_definition(field, report, _make_definition_field_path(field_key, root_path), options)
	return report


## 校验 Dictionary 数据。
## [br]
## @api public
## [br]
## @param values: 输入字典。
## [br]
## @param options: 可选上下文，支持 subject、path、source_path 和 source。
## [br]
## @return 校验报告。
## [br]
## @schema values: Dictionary source values.
## [br]
## @schema options: Dictionary validation context.
func validate_dictionary(values: Dictionary, options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = _make_report(options)
	var definition_report: GFValidationReport = validate_definition(options)
	var _merged_definition_report: RefCounted = report.merge(definition_report)
	var working_values: Dictionary = _normalize_keys(values)
	if coerce_values:
		working_values = _coerce_values_for_validation(values, report, options)
	var declared_fields: Dictionary = {}

	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue

		var field_key: StringName = field.get_field_key()
		declared_fields[field_key] = true
		if not working_values.has(field_key):
			if field.required:
				_add_error(
					report,
					&"missing_required",
					"Required field is missing.",
					field_key,
					_make_field_path(field_key, options),
					{
						"schema_id": String(schema_id),
						"field_name": String(field_key),
						"expected_value": "present",
						"actual_value": "missing",
					},
					options
				)
			continue

		var field_context: Dictionary = _make_field_context(field_key, options)
		field._validate_value_into(working_values[field_key], report, field_context)

	if not allow_extra_fields:
		for key_variant: Variant in working_values.keys():
			var field_key: StringName = GFVariantData.to_string_name(key_variant)
			if declared_fields.has(field_key):
				continue
			_add_error(
				report,
				&"extra_field",
				"Dictionary contains an undeclared field.",
				field_key,
				_make_field_path(field_key, options),
				{
					"schema_id": String(schema_id),
					"field_name": String(field_key),
					"actual_value": GFVariantData.duplicate_variant(working_values[key_variant]),
					"expected_value": "declared_field",
				},
				options
			)
	return report


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新 schema。
func duplicate_schema() -> GFDictionarySchema:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = schema_id
	schema.allow_extra_fields = allow_extra_fields
	schema.coerce_values = coerce_values
	schema.fail_on_coerce_error = fail_on_coerce_error
	schema.metadata = metadata.duplicate(true)
	for field: GFSchemaField in fields:
		if field == null:
			schema.fields.append(null)
		else:
			schema.fields.append(field.duplicate_field())
	return schema


## 导出 schema 摘要。
## [br]
## @api public
## [br]
## @return schema 字典。
## [br]
## @schema return: Dictionary schema description.
func describe() -> Dictionary:
	var field_descriptions: Array[Dictionary] = []
	for field: GFSchemaField in fields:
		if field != null:
			field_descriptions.append(field.describe())
	return {
		"schema_id": schema_id,
		"fields": field_descriptions,
		"allow_extra_fields": allow_extra_fields,
		"coerce_values": coerce_values,
		"fail_on_coerce_error": fail_on_coerce_error,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_report(options: Dictionary) -> GFValidationReport:
	var subject: String = GFVariantData.get_option_string(options, "subject")
	if subject.is_empty() and schema_id != &"":
		subject = String(schema_id)
	if subject.is_empty():
		subject = "GFDictionarySchema"
	return GFValidationReport.new(subject, {
		"schema_id": String(schema_id),
		"schema_metadata": metadata.duplicate(true),
	})


func _coerce_values_for_validation(values: Dictionary, report: GFValidationReport, options: Dictionary) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue

		var field_key: StringName = field.get_field_key()
		var has_value: bool = result.has(field_key)
		if not has_value and field.default_value == null:
			continue

		var source_value: Variant = field.default_value
		if has_value:
			source_value = result[field_key]
		var coerce_result: Dictionary = field.try_coerce_value(source_value)
		result[field_key] = GFVariantData.get_option_value(coerce_result, "value")
		if GFVariantData.get_option_bool(coerce_result, "ok", false):
			continue

		var severity: GFValidationIssue.Severity = GFValidationIssue.Severity.WARNING
		if fail_on_coerce_error:
			severity = GFValidationIssue.Severity.ERROR
		var issue_metadata: Dictionary = {
			"schema_id": String(schema_id),
			"field_name": String(field_key),
			"expected_value": GFSchemaField.value_type_to_name(field.value_type),
			"actual_value": GFVariantData.duplicate_variant(source_value),
		}
		var issue: RefCounted = report.add_issue(GFValidationIssue.new(
			severity,
			&"coerce_failed",
			GFVariantData.get_option_string(coerce_result, "message", "Value coercion failed."),
			field_key,
			_make_field_path(field_key, options),
			issue_metadata
		))
		_apply_context_to_issue(issue, options)
	return result


func _normalize_keys(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in values.keys():
		result[GFVariantData.to_string_name(key_variant)] = GFVariantData.duplicate_variant(values[key_variant])
	return result


func _make_field_context(field_key: StringName, options: Dictionary) -> Dictionary:
	var context: Dictionary = options.duplicate(true)
	context["schema_id"] = String(schema_id)
	context["key"] = field_key
	context["path"] = _make_field_path(field_key, options)
	if not context.has("subject") and schema_id != &"":
		context["subject"] = String(schema_id)
	return context


func _make_field_path(field_key: StringName, options: Dictionary) -> String:
	var root_path: String = GFVariantData.get_option_string(options, "path")
	if root_path.is_empty():
		return String(field_key)
	return root_path.path_join(String(field_key))


func _make_path(base_path: String, index: int) -> String:
	return "%s[%d]" % [base_path, index] if not base_path.is_empty() else "[%d]" % index


func _make_definition_field_path(field_key: StringName, root_path: String) -> String:
	if root_path.is_empty():
		return String(field_key)
	return root_path.path_join(String(field_key))


func _make_definition_metadata(index: int) -> Dictionary:
	return {
		"schema_id": String(schema_id),
		"field_index": index,
	}


func _validate_nested_field_definition(
	field: GFSchemaField,
	report: GFValidationReport,
	field_path: String,
	options: Dictionary
) -> void:
	if field.value_type == GFSchemaField.ValueType.DICTIONARY and field.dictionary_schema != null:
		var nested_report: GFValidationReport = field.dictionary_schema.validate_definition(_make_nested_definition_options(field_path, options))
		var _merged_dictionary_definition: RefCounted = report.merge(nested_report)
	elif field.value_type == GFSchemaField.ValueType.ARRAY and field.array_item_schema != null:
		_validate_array_item_definition(field.array_item_schema, report, field_path, options)


func _validate_array_item_definition(
	item_schema: GFSchemaField,
	report: GFValidationReport,
	field_path: String,
	options: Dictionary
) -> void:
	var item_path: String = "%s[]" % field_path
	if item_schema.value_type == GFSchemaField.ValueType.DICTIONARY and item_schema.dictionary_schema != null:
		var nested_dictionary_report: GFValidationReport = item_schema.dictionary_schema.validate_definition(_make_nested_definition_options(item_path, options))
		var _merged_array_dictionary_definition: RefCounted = report.merge(nested_dictionary_report)
	elif item_schema.value_type == GFSchemaField.ValueType.ARRAY and item_schema.array_item_schema != null:
		_validate_array_item_definition(item_schema.array_item_schema, report, item_path, options)


func _make_nested_definition_options(field_path: String, options: Dictionary) -> Dictionary:
	var nested_options: Dictionary = options.duplicate(true)
	nested_options["path"] = field_path
	if not nested_options.has("subject") and schema_id != &"":
		nested_options["subject"] = String(schema_id)
	return nested_options


func _add_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	issue_key: Variant,
	path: String,
	issue_metadata: Dictionary,
	options: Dictionary
) -> void:
	var issue: RefCounted = report.add_error(kind, message, issue_key, path, issue_metadata)
	_apply_context_to_issue(issue, options)


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
