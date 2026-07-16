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


# --- 私有变量 ---

var _field_lookup_cache: Dictionary = {}
var _field_lookup_signature: String = ""


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
	_invalidate_field_lookup()
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
	_invalidate_field_lookup()
	return true


## 获取字段声明。
## [br]
## @api public
## [br]
## @param field_name: 字段名。
## [br]
## @return 找到时返回字段声明，否则返回 null。
func get_field(field_name: StringName) -> GFSchemaField:
	var lookup: Dictionary = _get_field_lookup()
	var field_value: Variant = lookup.get(field_name)
	if field_value is GFSchemaField:
		var field: GFSchemaField = field_value
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
	return _get_field_lookup().has(field_name)


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
	_validate_definition_into(report, options, _make_definition_state())
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
	if not definition_report.is_ok():
		return report
	if _is_value_schema_active(options):
		_add_error(
			report,
			&"recursive_schema_value",
			"Schema value validation contains a recursive schema reference.",
			String(schema_id),
			GFVariantData.get_option_string(options, "path"),
			{
				"schema_id": String(schema_id),
			},
			options
		)
		return report
	var value_options: Dictionary = _make_value_validation_options(options)
	_validate_dictionary_values(values, report, value_options)
	return report


## 批量规范化 Dictionary 数组，并汇总行级校验报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param values: 输入数组。
## [br]
## @param options: 可选配置，支持 include_optional、coerce、strip_extra_fields、validate_rows、keep_invalid_rows、path、subject、source_path 和 source。
## [br]
## @return 规范化结果字典。
## [br]
## @schema values: Array[Dictionary] source rows; non-Dictionary rows are reported as invalid_row.
## [br]
## @schema options: Dictionary normalization options.
## [br]
## @schema return: Dictionary with ok, rows, row_count, normalized_count, invalid_row_count, skipped_row_count, and report.
func normalize_dictionary_array(values: Array, options: Dictionary = {}) -> Dictionary:
	var include_optional: bool = GFVariantData.get_option_bool(options, "include_optional", true)
	var should_coerce: bool = GFVariantData.get_option_bool(options, "coerce", true)
	var strip_extra_fields: bool = GFVariantData.get_option_bool(options, "strip_extra_fields", not allow_extra_fields)
	var validate_rows: bool = GFVariantData.get_option_bool(options, "validate_rows", true)
	var keep_invalid_rows: bool = GFVariantData.get_option_bool(options, "keep_invalid_rows", true)
	var report: GFValidationReport = _make_report(options)
	var definition_report: GFValidationReport = validate_definition(options)
	var _merged_definition_report: RefCounted = report.merge(definition_report)
	var normalized_rows: Array[Dictionary] = []
	var invalid_row_count: int = 0
	var skipped_row_count: int = 0

	for index: int in range(values.size()):
		var row_path: String = _make_path(GFVariantData.get_option_string(options, "path"), index)
		var raw_row: Variant = values[index]
		if not (raw_row is Dictionary):
			invalid_row_count += 1
			_add_invalid_row_error(report, index, row_path, raw_row, options)
			if keep_invalid_rows:
				normalized_rows.append({})
			else:
				skipped_row_count += 1
			continue

		var source_row: Dictionary = raw_row
		var row_report: GFValidationReport = null
		var row_options: Dictionary = _make_row_options(options, row_path)
		if validate_rows:
			row_report = _make_report(row_options)
			_add_normalized_key_collision_errors(source_row, row_report, row_options)
		var normalized_row: Dictionary = _normalize_dictionary_row(
			source_row,
			include_optional,
			should_coerce,
			strip_extra_fields,
			row_report,
			row_options
		)
		if validate_rows:
			_validate_dictionary_values(normalized_row, row_report, row_options)
			_validate_normalized_required_source_fields(source_row, normalized_row, row_report, row_options)
			var _merged_row_report: RefCounted = report.merge(row_report, false)
			if not row_report.is_ok():
				invalid_row_count += 1
				if not keep_invalid_rows:
					skipped_row_count += 1
					continue
		normalized_rows.append(normalized_row)

	return {
		"ok": report.is_ok(),
		"rows": normalized_rows,
		"row_count": values.size(),
		"normalized_count": normalized_rows.size(),
		"invalid_row_count": invalid_row_count,
		"skipped_row_count": skipped_row_count,
		"report": report,
	}


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新 schema。
func duplicate_schema() -> GFDictionarySchema:
	return _duplicate_schema(_make_duplicate_state())


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


# --- 框架内部方法 ---

func _validate_definition_into(report: GFValidationReport, options: Dictionary, state: Dictionary) -> void:
	var root_path: String = GFVariantData.get_option_string(options, "path")
	if _is_schema_active(state, self):
		var _circular_schema_issue: RefCounted = report.add_error(
			&"circular_schema",
			"Schema definition contains a circular reference.",
			String(schema_id),
			root_path,
			{
				"schema_id": String(schema_id),
			}
		)
		return

	_push_active_schema(state, self)
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
		_validate_nested_field_definition(field, report, _make_definition_field_path(field_key, root_path), options, state)
	_pop_active_schema(state, self)


func _duplicate_schema(state: Dictionary) -> GFDictionarySchema:
	var schema_key: int = get_instance_id()
	var visited_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "schemas", {}))
	if visited_schemas.has(schema_key):
		var existing_schema: Variant = visited_schemas[schema_key]
		if existing_schema is GFDictionarySchema:
			return existing_schema

	var schema: GFDictionarySchema = GFDictionarySchema.new()
	visited_schemas[schema_key] = schema
	state["schemas"] = visited_schemas
	schema.schema_id = schema_id
	schema.allow_extra_fields = allow_extra_fields
	schema.coerce_values = coerce_values
	schema.fail_on_coerce_error = fail_on_coerce_error
	schema.metadata = metadata.duplicate(true)
	for field: GFSchemaField in fields:
		if field == null:
			schema.fields.append(null)
		else:
			schema.fields.append(field._duplicate_field_with_context(state))
	return schema


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


func _validate_dictionary_values(values: Dictionary, report: GFValidationReport, options: Dictionary) -> void:
	_add_normalized_key_collision_errors(values, report, options)
	var source_values: Dictionary = _normalize_keys(values)
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
		if field.required and not source_values.has(field_key):
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


func _normalize_keys(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in values.keys():
		result[GFVariantData.to_string_name(key_variant)] = GFVariantData.duplicate_variant(values[key_variant])
	return result


func _add_normalized_key_collision_errors(
	values: Dictionary,
	report: GFValidationReport,
	options: Dictionary
) -> void:
	if report == null:
		return
	var seen_keys: Dictionary = {}
	var reported_keys: Dictionary = {}
	for key_variant: Variant in values.keys():
		var field_key: StringName = GFVariantData.to_string_name(key_variant)
		if not seen_keys.has(field_key):
			seen_keys[field_key] = _describe_source_key(key_variant)
			continue
		if reported_keys.has(field_key):
			continue
		reported_keys[field_key] = true
		_add_error(
			report,
			&"duplicate_field_key",
			"Dictionary contains multiple source keys that normalize to the same schema field.",
			field_key,
			_make_field_path(field_key, options),
			{
				"schema_id": String(schema_id),
				"field_name": String(field_key),
				"first_key": GFVariantData.get_option_string(seen_keys, field_key),
				"duplicate_key": _describe_source_key(key_variant),
			},
			options
		)


func _describe_source_key(key_variant: Variant) -> String:
	return "%s:%s" % [
		type_string(typeof(key_variant)),
		GFVariantData.to_text(key_variant),
	]


func _get_field_lookup() -> Dictionary:
	var signature: String = _make_field_lookup_signature()
	if signature == _field_lookup_signature:
		return _field_lookup_cache

	var lookup: Dictionary = {}
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue
		var field_key: StringName = field.get_field_key()
		if not lookup.has(field_key):
			lookup[field_key] = field
	_field_lookup_cache = lookup
	_field_lookup_signature = signature
	return _field_lookup_cache


func _make_field_lookup_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for index: int in range(fields.size()):
		var field: GFSchemaField = fields[index]
		if field == null:
			var _append_null: bool = parts.append("%d:null" % index)
			continue
		var _append_field: bool = parts.append("%d:%d:%s" % [
			index,
			field.get_instance_id(),
			String(field.get_field_key()),
		])
	return "|".join(parts)


func _invalidate_field_lookup() -> void:
	_field_lookup_cache.clear()
	_field_lookup_signature = ""


func _normalize_dictionary_row(
	values: Dictionary,
	include_optional: bool,
	should_coerce: bool,
	strip_extra_fields: bool,
	report: GFValidationReport,
	options: Dictionary
) -> Dictionary:
	var result: Dictionary = _normalize_keys(values)
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue

		var field_key: StringName = field.get_field_key()
		if result.has(field_key):
			if should_coerce:
				result[field_key] = _coerce_row_value(field, result[field_key], report, options)
			continue
		if not _should_fill_row_default(field, include_optional):
			continue
		if should_coerce:
			result[field_key] = _coerce_row_value(field, field.default_value, report, options)
		else:
			result[field_key] = GFVariantData.duplicate_variant(field.default_value)
	if strip_extra_fields:
		result = _strip_extra_fields(result)
	return result


func _coerce_row_value(
	field: GFSchemaField,
	source_value: Variant,
	report: GFValidationReport,
	options: Dictionary
) -> Variant:
	var coerce_result: Dictionary = field.try_coerce_value(source_value)
	if GFVariantData.get_option_bool(coerce_result, "ok", false):
		return GFVariantData.get_option_value(coerce_result, "value")

	var field_key: StringName = field.get_field_key()
	if report != null:
		_add_error(
			report,
			&"coerce_failed",
			GFVariantData.get_option_string(coerce_result, "message", "Value coercion failed."),
			field_key,
			_make_field_path(field_key, options),
			{
				"schema_id": String(schema_id),
				"field_name": String(field_key),
				"expected_value": GFSchemaField.value_type_to_name(field.value_type),
				"actual_value": GFVariantData.duplicate_variant(source_value),
			},
			options
		)
	return GFVariantData.duplicate_variant(source_value)


func _should_fill_row_default(field: GFSchemaField, include_optional: bool) -> bool:
	if not field.required and not include_optional:
		return false
	if field.default_value != null:
		return true
	return field.allow_null


func _validate_normalized_required_source_fields(
	source_values: Dictionary,
	normalized_values: Dictionary,
	report: GFValidationReport,
	options: Dictionary
) -> void:
	var source_keys: Dictionary = _normalize_keys(source_values)
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"" or not field.required:
			continue

		var field_key: StringName = field.get_field_key()
		if source_keys.has(field_key) or not normalized_values.has(field_key):
			continue
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


func _strip_extra_fields(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue
		var field_key: StringName = field.get_field_key()
		if values.has(field_key):
			result[field_key] = GFVariantData.duplicate_variant(values[field_key])
	return result


func _make_row_options(options: Dictionary, row_path: String) -> Dictionary:
	var row_options: Dictionary = options.duplicate(true)
	row_options["path"] = row_path
	if not row_options.has("subject") and schema_id != &"":
		row_options["subject"] = String(schema_id)
	return row_options


func _add_invalid_row_error(
	report: GFValidationReport,
	index: int,
	row_path: String,
	row_value: Variant,
	options: Dictionary
) -> void:
	_add_error(
		report,
		&"invalid_row",
		"Dictionary array row is not a Dictionary.",
		index,
		row_path,
		{
			"schema_id": String(schema_id),
			"row_index": index,
			"expected_value": "Dictionary",
			"actual_value": GFVariantData.duplicate_variant(row_value),
			"actual_type": typeof(row_value),
		},
		options
	)


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
	options: Dictionary,
	state: Dictionary
) -> void:
	if _is_field_active(state, field):
		_add_definition_cycle_error(report, field, field_path)
		return
	_push_active_field(state, field)
	if field.value_type == GFSchemaField.ValueType.DICTIONARY and field.dictionary_schema != null:
		var nested_options: Dictionary = _make_nested_definition_options(field_path, options)
		var nested_report: GFValidationReport = field.dictionary_schema._make_report(nested_options)
		field.dictionary_schema._validate_definition_into(nested_report, nested_options, state)
		var _merged_dictionary_definition: RefCounted = report.merge(nested_report)
	elif field.value_type == GFSchemaField.ValueType.ARRAY and field.array_item_schema != null:
		_validate_array_item_definition(field.array_item_schema, report, field_path, options, state)
	_pop_active_field(state, field)


func _validate_array_item_definition(
	item_schema: GFSchemaField,
	report: GFValidationReport,
	field_path: String,
	options: Dictionary,
	state: Dictionary
) -> void:
	var item_path: String = "%s[]" % field_path
	if _is_field_active(state, item_schema):
		_add_definition_cycle_error(report, item_schema, item_path)
		return
	_push_active_field(state, item_schema)
	if item_schema.value_type == GFSchemaField.ValueType.DICTIONARY and item_schema.dictionary_schema != null:
		var nested_dictionary_options: Dictionary = _make_nested_definition_options(item_path, options)
		var nested_dictionary_report: GFValidationReport = item_schema.dictionary_schema._make_report(nested_dictionary_options)
		item_schema.dictionary_schema._validate_definition_into(nested_dictionary_report, nested_dictionary_options, state)
		var _merged_array_dictionary_definition: RefCounted = report.merge(nested_dictionary_report)
	elif item_schema.value_type == GFSchemaField.ValueType.ARRAY and item_schema.array_item_schema != null:
		_validate_array_item_definition(item_schema.array_item_schema, report, item_path, options, state)
	_pop_active_field(state, item_schema)


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


func _make_definition_state() -> Dictionary:
	return {
		"active_schemas": {},
		"active_fields": {},
	}


func _make_duplicate_state() -> Dictionary:
	return {
		"schemas": {},
		"fields": {},
	}


func _make_value_validation_options(options: Dictionary) -> Dictionary:
	var value_options: Dictionary = options.duplicate(true)
	var active_schemas: Dictionary = GFVariantData.get_option_dictionary(value_options, "active_value_schemas")
	active_schemas = active_schemas.duplicate(true)
	active_schemas[get_instance_id()] = true
	value_options["active_value_schemas"] = active_schemas
	return value_options


func _is_value_schema_active(options: Dictionary) -> bool:
	var active_schemas: Dictionary = GFVariantData.get_option_dictionary(options, "active_value_schemas")
	return active_schemas.has(get_instance_id())


func _is_schema_active(state: Dictionary, schema: GFDictionarySchema) -> bool:
	if schema == null:
		return false
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	return active_schemas.has(schema.get_instance_id())


func _push_active_schema(state: Dictionary, schema: GFDictionarySchema) -> void:
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	active_schemas[schema.get_instance_id()] = true
	state["active_schemas"] = active_schemas


func _pop_active_schema(state: Dictionary, schema: GFDictionarySchema) -> void:
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	var _erased_schema: bool = active_schemas.erase(schema.get_instance_id())
	state["active_schemas"] = active_schemas


func _is_field_active(state: Dictionary, field: GFSchemaField) -> bool:
	if field == null:
		return false
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	return active_fields.has(field.get_instance_id())


func _push_active_field(state: Dictionary, field: GFSchemaField) -> void:
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	active_fields[field.get_instance_id()] = true
	state["active_fields"] = active_fields


func _pop_active_field(state: Dictionary, field: GFSchemaField) -> void:
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	var _erased_field: bool = active_fields.erase(field.get_instance_id())
	state["active_fields"] = active_fields


func _add_definition_cycle_error(report: GFValidationReport, field: GFSchemaField, field_path: String) -> void:
	var field_key: StringName = field.get_field_key() if field != null else &""
	var _circular_field_issue: RefCounted = report.add_error(
		&"circular_field_schema",
		"Schema field definition contains a circular reference.",
		field_key,
		field_path,
		{
			"schema_id": String(schema_id),
			"field_name": String(field_key),
		}
	)
