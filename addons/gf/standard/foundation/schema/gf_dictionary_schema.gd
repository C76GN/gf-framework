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


# --- 常量 ---

## schema 与 field 递归定义预检允许的最大活动深度。
## [br]
## @api private
const _MAX_DEFINITION_DEPTH: int = 64


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

## 按字段 StringName 键缓存首个有效字段声明。
## [br]
## @api private
var _field_lookup_cache: Dictionary = {}

## 与缓存对应的字段顺序、实例 ID 和键签名；字段集合变化时触发重建。
## [br]
## @api private
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
## @since 4.4.0
## [br]
## @param include_optional: 为 true 时包含非必填字段。
## [br]
## 只写入可表达的默认值：default_value 非 null，或字段允许 null。没有可用默认值的
## non-nullable 字段保持缺失，不会被注入一个随后无法通过 schema 的 null。
## [br]
## @return 默认数据字典。
## [br]
## @schema return: Dictionary default values.
func build_defaults(include_optional: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue
		if not _should_fill_row_default(field, include_optional):
			continue
		result[field.get_field_key()] = field.coerce_value(field.default_value)
	return result


## 为输入 Dictionary 补齐默认值。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param values: 输入字典。
## [br]
## @param include_optional: 为 true 时补齐非必填字段。
## [br]
## @param should_coerce: 为 true 时按字段声明转换已有值和默认值。
## [br]
## 只为缺失字段写入可表达的默认值；没有可用默认值的 non-nullable 字段保持缺失。
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
		if not _should_fill_row_default(field, include_optional):
			continue
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

## 为单个字段建立新的定义递归状态，选择显式路径或字段名作为根路径，并把嵌套定义问题追加到调用方报告。
## [br]
## @api framework_internal
## [br]
## @layer standard/foundation/schema
## [br]
## @param field: 要检查的有效字段定义，调用方须提供非空实例。
## [br]
## @param report: 接收新增问题的报告，不会先清空。
## [br]
## @param options: 路径、主题和来源等校验上下文。
## [br]
## @schema options: 可含 path、subject、source_path/source、line 和 column；path 缺省时使用字段名。
func _validate_field_definition_into(
	field: GFSchemaField,
	report: GFValidationReport,
	options: Dictionary
) -> void:
	var field_path: String = GFVariantData.get_option_string(options, "path", String(field.field_name))
	_validate_nested_field_definition(field, report, field_path, options, _make_definition_state())


## 在共享活动身份集合中校验当前 schema 的字段与嵌套定义；回边、空字段、空名称和重名写入报告，进入前登记当前 schema，正常遍历后移除其活动标记。
## [br]
## @api framework_internal
## [br]
## @layer standard/foundation/schema
## [br]
## @param report: 追加定义问题的报告。
## [br]
## @param options: 当前定义位置和诊断上下文。
## [br]
## @param state: 同一次递归校验共享并原地更新的活动集合。
## [br]
## @schema options: 可含 path、subject、source_path/source、line 和 column；嵌套检查按字段位置派生上下文。
## [br]
## @schema state: 包含 active_schemas 与 active_fields 字典，键为当前递归路径上的实例 ID；用于检测回边和活动深度。
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
		var field_path: String = _make_definition_field_path(field_key, root_path)
		if _can_visit_definition(field, report, field_path, options, state):
			_validate_nested_field_definition(field, report, field_path, options, state)
	_pop_active_schema(state, self)


## 通过共享实例映射复制 schema 图；先登记新副本再复制字段，使回边与共享引用指向同一副本，空字段保留原位置。
## [br]
## @api framework_internal
## [br]
## @layer standard/foundation/schema
## [br]
## @param state: 本次图复制共享并原地更新的身份映射。
## [br]
## @return: 当前 schema 的副本；已经访问过时返回此前登记的同一副本。
## [br]
## @schema state: 包含 schemas 和 fields 字典，分别把源 schema/field 实例 ID 映射到对应副本。
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

## 选择调用方 subject、schema_id 或类名作为主题，并附加 schema 标识和元数据。
## [br]
## @api private
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


## 按字段声明尝试转换现有值或可用默认值，并按配置把转换失败写为 warning 或 error。
## 返回键已规范化且包含尝试转换结果的字典。
## [br]
## @api private
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


## 检查规范化键冲突、必填字段和值约束，并在禁止额外字段时报告未声明键。
## 开启 coerce_values 时使用转换后的值校验，但仍用原始键集合检查必填字段是否真实提供。
## [br]
## @api private
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


## 将输入字典的键转换为 StringName，并复制各自的值。
## [br]
## @api private
func _normalize_keys(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in values.keys():
		result[GFVariantData.to_string_name(key_variant)] = GFVariantData.duplicate_variant(values[key_variant])
	return result


## 检测多个原始键规范化到同一 StringName 的情况，并为每个冲突键只追加一次错误。
## [br]
## @api private
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


## 以原始 Variant 类型名和 GFVariantData 文本形式描述来源键。
## [br]
## @api private
func _describe_source_key(key_variant: Variant) -> String:
	return "%s:%s" % [
		type_string(typeof(key_variant)),
		GFVariantData.to_text(key_variant),
	]


## 按当前字段签名返回缓存查找表；失效时按字段顺序重建，每个键保留首个声明。
## [br]
## @api private
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


## 生成包含字段位置、实例 ID 和 field key 的签名，用于发现查找表结构变化。
## [br]
## @api private
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


## 清空字段查找缓存并重置签名，使下次读取时重新构建。
## [br]
## @api private
func _invalidate_field_lookup() -> void:
	_field_lookup_cache.clear()
	_field_lookup_signature = ""


## 规范化一行字段键，按选项转换已有值和默认值，并可去除未声明字段。
## [br]
## @api private
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


## 转换字段值；成功时返回转换值，失败时可记录错误并返回来源值的副本。
## [br]
## @api private
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


## 必填字段始终允许填默认值；可选字段仅在 include_optional 为 true 时处理。
## 有非 null 默认值或字段允许 null 时返回 true。
## [br]
## @api private
func _should_fill_row_default(field: GFSchemaField, include_optional: bool) -> bool:
	if not field.required and not include_optional:
		return false
	if field.default_value != null:
		return true
	return field.allow_null


## 检查规范化结果中出现、但来源字典未实际提供的必填字段，并追加缺失错误。
## [br]
## @api private
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


## 只复制声明字段中实际存在的值，形成移除额外字段后的字典。
## [br]
## @api private
func _strip_extra_fields(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: GFSchemaField in fields:
		if field == null or field.get_field_key() == &"":
			continue
		var field_key: StringName = field.get_field_key()
		if values.has(field_key):
			result[field_key] = GFVariantData.duplicate_variant(values[field_key])
	return result


## 深拷贝行级选项并设置 path；缺少 subject 且 schema 有 ID 时补入该 ID。
## [br]
## @api private
func _make_row_options(options: Dictionary, row_path: String) -> Dictionary:
	var row_options: Dictionary = options.duplicate(true)
	row_options["path"] = row_path
	if not row_options.has("subject") and schema_id != &"":
		row_options["subject"] = String(schema_id)
	return row_options


## 为不是 Dictionary 的数组项追加 invalid_row 错误及其索引、路径和值类型。
## [br]
## @api private
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


## 深拷贝字段校验选项，并加入 schema_id、字段键、字段路径和默认主题。
## [br]
## @api private
func _make_field_context(field_key: StringName, options: Dictionary) -> Dictionary:
	var context: Dictionary = options.duplicate(true)
	context["schema_id"] = String(schema_id)
	context["key"] = field_key
	context["path"] = _make_field_path(field_key, options)
	if not context.has("subject") and schema_id != &"":
		context["subject"] = String(schema_id)
	return context


## 将字段键接到可选根路径；根路径为空时只返回字段键。
## [br]
## @api private
func _make_field_path(field_key: StringName, options: Dictionary) -> String:
	var root_path: String = GFVariantData.get_option_string(options, "path")
	if root_path.is_empty():
		return String(field_key)
	return root_path.path_join(String(field_key))


## 将数组行索引追加到基础路径；基础路径为空时生成 [index]。
## [br]
## @api private
func _make_path(base_path: String, index: int) -> String:
	return "%s[%d]" % [base_path, index] if not base_path.is_empty() else "[%d]" % index


## 将字段键接到 schema 定义校验的可选根路径。
## [br]
## @api private
func _make_definition_field_path(field_key: StringName, root_path: String) -> String:
	if root_path.is_empty():
		return String(field_key)
	return root_path.path_join(String(field_key))


## 生成含 schema_id 和 field_index 的定义错误元数据。
## [br]
## @api private
func _make_definition_metadata(index: int) -> Dictionary:
	return {
		"schema_id": String(schema_id),
		"field_index": index,
	}


## 跟踪当前字段并校验其嵌套 Dictionary schema 或数组项 schema 定义。
## 已活动字段形成循环时报告错误，未超深度时递归检查子 schema，最后移除活动标记。
## [br]
## @api private
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
		if _can_visit_definition(field.dictionary_schema, report, field_path, options, state):
			var nested_options: Dictionary = _make_nested_definition_options(field_path, options)
			var nested_report: GFValidationReport = field.dictionary_schema._make_report(nested_options)
			field.dictionary_schema._validate_definition_into(nested_report, nested_options, state)
			var _merged_dictionary_definition: RefCounted = report.merge(nested_report)
	elif field.value_type == GFSchemaField.ValueType.ARRAY and field.array_item_schema != null:
		if _can_visit_definition(field.array_item_schema, report, "%s[]" % field_path, options, state):
			_validate_array_item_definition(field.array_item_schema, report, field_path, options, state)
	_pop_active_field(state, field)


## 在 field_path 后追加 []，跟踪数组项字段，并递归检查其字典或数组 schema。
## [br]
## @api private
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
		if _can_visit_definition(item_schema.dictionary_schema, report, item_path, options, state):
			var nested_dictionary_options: Dictionary = _make_nested_definition_options(item_path, options)
			var nested_dictionary_report: GFValidationReport = item_schema.dictionary_schema._make_report(nested_dictionary_options)
			item_schema.dictionary_schema._validate_definition_into(nested_dictionary_report, nested_dictionary_options, state)
			var _merged_array_dictionary_definition: RefCounted = report.merge(nested_dictionary_report)
	elif item_schema.value_type == GFSchemaField.ValueType.ARRAY and item_schema.array_item_schema != null:
		if _can_visit_definition(item_schema.array_item_schema, report, "%s[]" % item_path, options, state):
			_validate_array_item_definition(item_schema.array_item_schema, report, item_path, options, state)
	_pop_active_field(state, item_schema)


## 允许循环身份交由专用循环分支处理；否则检查 schema 与 field 活动路径总深度。
## 超过上限时追加 schema_depth_exceeded 并返回 false。
## [br]
## @api private
func _can_visit_definition(
	definition: Resource,
	report: GFValidationReport,
	path: String,
	options: Dictionary,
	state: Dictionary
) -> bool:
	var active_schemas: Dictionary = GFVariantData.get_option_dictionary(state, "active_schemas")
	var active_fields: Dictionary = GFVariantData.get_option_dictionary(state, "active_fields")
	var definition_id: int = definition.get_instance_id()
	# 已活动的 identity 交给既有循环分支，保留 circular_schema / circular_field_schema。
	if active_schemas.has(definition_id) or active_fields.has(definition_id):
		return true
	var depth: int = active_schemas.size() + active_fields.size() + 1
	if depth <= _MAX_DEFINITION_DEPTH:
		return true
	_add_error(
		report,
		&"schema_depth_exceeded",
		"Schema definition exceeds the maximum active definition depth.",
		path,
		path,
		{
			"schema_id": String(schema_id),
			"depth": depth,
			"max_depth": _MAX_DEFINITION_DEPTH,
		},
		options
	)
	return false


## 深拷贝嵌套定义选项并设置子路径；缺少 subject 且 schema 有 ID 时补入 schema ID。
## [br]
## @api private
func _make_nested_definition_options(field_path: String, options: Dictionary) -> Dictionary:
	var nested_options: Dictionary = options.duplicate(true)
	nested_options["path"] = field_path
	if not nested_options.has("subject") and schema_id != &"":
		nested_options["subject"] = String(schema_id)
	return nested_options


## 通过 report.add_error 追加问题，并将上下文中的来源位置和主题应用到问题对象。
## [br]
## @api private
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


## 对 GFValidationIssue 补入 source_path、行、列和 subject；source_path 为空时可回退到 source。
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


## 创建用于定义递归校验的活动 schema/field 集合。
## [br]
## @api private
func _make_definition_state() -> Dictionary:
	return {
		"active_schemas": {},
		"active_fields": {},
	}


## 创建用于递归深拷贝的 schema/field 身份映射。
## [br]
## @api private
func _make_duplicate_state() -> Dictionary:
	return {
		"schemas": {},
		"fields": {},
	}


## 深拷贝值校验选项，并在 active_value_schemas 中标记当前 schema 实例。
## [br]
## @api private
func _make_value_validation_options(options: Dictionary) -> Dictionary:
	var value_options: Dictionary = options.duplicate(true)
	var active_schemas: Dictionary = GFVariantData.get_option_dictionary(value_options, "active_value_schemas")
	active_schemas = active_schemas.duplicate(true)
	active_schemas[get_instance_id()] = true
	value_options["active_value_schemas"] = active_schemas
	return value_options


## 检查当前 schema 实例是否已在值校验的 active_value_schemas 中。
## [br]
## @api private
func _is_value_schema_active(options: Dictionary) -> bool:
	var active_schemas: Dictionary = GFVariantData.get_option_dictionary(options, "active_value_schemas")
	return active_schemas.has(get_instance_id())


## 检查 schema 实例 ID 是否已存在于定义校验状态的活动 schema 集合。
## [br]
## @api private
func _is_schema_active(state: Dictionary, schema: GFDictionarySchema) -> bool:
	if schema == null:
		return false
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	return active_schemas.has(schema.get_instance_id())


## 将 schema 实例 ID 加入定义校验的活动集合。
## [br]
## @api private
func _push_active_schema(state: Dictionary, schema: GFDictionarySchema) -> void:
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	active_schemas[schema.get_instance_id()] = true
	state["active_schemas"] = active_schemas


## 从定义校验的活动 schema 集合移除实例 ID。
## [br]
## @api private
func _pop_active_schema(state: Dictionary, schema: GFDictionarySchema) -> void:
	var active_schemas: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_schemas", {}))
	var _erased_schema: bool = active_schemas.erase(schema.get_instance_id())
	state["active_schemas"] = active_schemas


## 检查 field 实例 ID 是否已存在于定义校验状态的活动 field 集合。
## [br]
## @api private
func _is_field_active(state: Dictionary, field: GFSchemaField) -> bool:
	if field == null:
		return false
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	return active_fields.has(field.get_instance_id())


## 将 field 实例 ID 加入定义校验的活动集合。
## [br]
## @api private
func _push_active_field(state: Dictionary, field: GFSchemaField) -> void:
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	active_fields[field.get_instance_id()] = true
	state["active_fields"] = active_fields


## 从定义校验的活动 field 集合移除实例 ID。
## [br]
## @api private
func _pop_active_field(state: Dictionary, field: GFSchemaField) -> void:
	var active_fields: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(state, "active_fields", {}))
	var _erased_field: bool = active_fields.erase(field.get_instance_id())
	state["active_fields"] = active_fields


## 报告 field schema 循环引用，并附带字段键、路径和 schema ID。
## [br]
## @api private
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
