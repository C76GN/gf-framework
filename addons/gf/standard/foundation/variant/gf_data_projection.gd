## GFDataProjection: 显式安全数据投影辅助。
##
## 用于把 Dictionary、Object 或 Resource 的少量字段转换成纯 Variant 数据模型，
## 供生成器、编辑器工具、诊断面板或文本上下文使用。对象投影必须提供字段名单；
## 不会默认暴露宿主对象的全部属性。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFDataProjection
extends RefCounted


# --- 公共方法 ---

## 投影 Dictionary 为安全数据副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param values: 输入字典。
## [br]
## @param options: 可选配置，支持 allowed_fields、rename_fields、schema、max_depth、unsupported、include_null 和 defaults。
## [br]
## @return 投影后的字典。
## [br]
## @schema values: Dictionary，来源数据。
## [br]
## @schema options: Dictionary，包含投影配置。
## [br]
## @schema return: Dictionary，投影后的纯数据。
static func project_dictionary(values: Dictionary, options: Dictionary = {}) -> Dictionary:
	var source_values: Dictionary = values.duplicate(false)
	var schema: GFDictionarySchema = _read_schema(options)
	if schema != null:
		source_values = schema.coerce_dictionary(source_values, GFVariantData.get_option_bool(options, "include_defaults", true))

	var state: Dictionary = _make_state(options)
	var allowed_lookup: Dictionary = _make_allowed_lookup(options, schema)
	var rename_fields: Dictionary = GFVariantData.get_option_dictionary(options, "rename_fields")
	var result: Dictionary = {}
	for key_variant: Variant in source_values.keys():
		var field_name: String = GFVariantData.to_text(key_variant)
		var child_state: Dictionary = _make_child_state(state, key_variant)
		if not allowed_lookup.is_empty() and not allowed_lookup.has(field_name):
			_record_projection_issue("field_not_allowed", source_values[key_variant], child_state)
			continue
		var projected: Dictionary = _project_value(source_values[key_variant], 0, child_state)
		if not GFVariantData.get_option_bool(projected, "ok", false):
			continue

		var output_key: Variant = _rename_key(key_variant, field_name, rename_fields)
		result[output_key] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(projected, "value"))

	var defaults: Dictionary = GFVariantData.get_option_dictionary(options, "defaults")
	if not defaults.is_empty():
		var _merged_defaults: Dictionary = GFVariantData.deep_merge_defaults(result, defaults)
	return result


## 投影 Object 或 Resource 的显式字段。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param object_ref: 输入对象。
## [br]
## @param fields: 要读取的字段名单；为空时不暴露任何字段。
## [br]
## @param options: 可选配置，支持 rename_fields、max_depth、unsupported、include_null 和 defaults。
## [br]
## @return 投影后的字典。
## [br]
## @schema fields: PackedStringArray，显式允许读取的属性名。
## [br]
## @schema options: Dictionary，包含投影配置。
## [br]
## @schema return: Dictionary，投影后的纯数据。
static func project_object(
	object_ref: Object,
	fields: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> Dictionary:
	var defaults: Dictionary = GFVariantData.get_option_dictionary(options, "defaults")
	if object_ref == null:
		return defaults
	if not is_instance_valid(object_ref):
		_record_projection_issue("invalid_object", null, _make_state(options))
		return defaults
	if fields.is_empty():
		return defaults

	var source_values: Dictionary = {}
	for field_name: String in fields:
		if field_name.is_empty():
			continue
		source_values[field_name] = object_ref.get(field_name)

	var dictionary_options: Dictionary = options.duplicate(true)
	dictionary_options["allowed_fields"] = fields
	return project_dictionary(source_values, dictionary_options)


## 投影任意 Variant 值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 输入值。
## [br]
## @param options: 可选配置，支持 max_depth、unsupported 和 include_null。
## [br]
## @return 投影后的值；无法投影且 unsupported 为 drop 时返回 null。
## [br]
## @schema value: Variant，来源值。
## [br]
## @schema options: Dictionary，包含投影配置。
## [br]
## @schema return: Variant，投影后的纯数据。
static func project_value(value: Variant, options: Dictionary = {}) -> Variant:
	var projected: Dictionary = _project_value(value, 0, _make_state(options))
	if GFVariantData.get_option_bool(projected, "ok", false):
		return GFVariantData.get_option_value(projected, "value")
	return null


## 投影数据并返回带报告的结果字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source: Dictionary、Object 或 Resource。
## [br]
## @param options: 可选配置。Object 来源必须提供 fields。
## [br]
## @return 结果字典，包含 ok、data 和 report。
## [br]
## @schema source: Variant，支持 Dictionary 或 Object。
## [br]
## @schema options: Dictionary，包含投影配置。
## [br]
## @schema return: Dictionary，包含投影结果和校验报告。
static func project_with_report(source: Variant, options: Dictionary = {}) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new(
		GFVariantData.get_option_string(options, "subject", "Data projection")
	)
	var data: Dictionary = {}
	var report_options: Dictionary = options.duplicate(true)
	report_options["_projection_report"] = report
	if source is Dictionary:
		var source_dictionary: Dictionary = source
		data = project_dictionary(source_dictionary, report_options)
	elif typeof(source) == TYPE_OBJECT:
		if not is_instance_valid(source):
			var _invalid_object_issue: RefCounted = report.add_warning(
				&"invalid_object",
				"Projection source object is no longer valid."
			)
		else:
			var object_ref: Object = source
			data = project_object(object_ref, _to_packed_string_array(GFVariantData.get_option_value(options, "fields")), report_options)
	else:
		var _unsupported_issue: RefCounted = report.add_error(
			&"unsupported_source",
			"Projection source must be a Dictionary or Object."
		)

	return GFResultDictionary.make(report.is_ok(), {
		GFResultDictionary.KEY_DATA: data,
		"report": report,
	})


# --- 私有/辅助方法 ---

static func _project_value(value: Variant, depth: int, state: Dictionary) -> Dictionary:
	var max_depth: int = GFVariantData.get_option_int(state, "max_depth", 8)
	if max_depth > 0 and depth > max_depth:
		return _handle_unsupported("max_depth_exceeded", value, state)
	if value == null:
		if GFVariantData.get_option_bool(state, "include_null", true):
			return { "ok": true, "value": null }
		return { "ok": false }
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return _project_dictionary_value(dictionary_value, depth, state)
	if value is Array:
		var array_value: Array = value
		return _project_array_value(array_value, depth, state)
	if _is_plain_value(value):
		return {
			"ok": true,
			"value": GFVariantData.duplicate_variant(value),
		}
	return _handle_unsupported("unsupported_value", value, state)


static func _project_dictionary_value(value: Dictionary, depth: int, state: Dictionary) -> Dictionary:
	if _is_container_active(value, state):
		return _handle_unsupported("circular_reference", value, state)

	_push_active_container(value, state)
	var result: Dictionary = {}
	for key_variant: Variant in value.keys():
		if not _is_plain_key(key_variant):
			_record_projection_issue("unsupported_key", key_variant, state)
			continue
		var child_state: Dictionary = _make_child_state(state, key_variant)
		var projected: Dictionary = _project_value(value[key_variant], depth + 1, child_state)
		if GFVariantData.get_option_bool(projected, "ok", false):
			result[key_variant] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(projected, "value"))
	_pop_active_container(state)
	return {
		"ok": true,
		"value": result,
	}


static func _project_array_value(value: Array, depth: int, state: Dictionary) -> Dictionary:
	if _is_container_active(value, state):
		return _handle_unsupported("circular_reference", value, state)

	_push_active_container(value, state)
	var result: Array = []
	for index: int in range(value.size()):
		var item: Variant = value[index]
		var child_state: Dictionary = _make_child_state(state, index)
		var projected: Dictionary = _project_value(item, depth + 1, child_state)
		if GFVariantData.get_option_bool(projected, "ok", false):
			result.append(GFVariantData.duplicate_variant(GFVariantData.get_option_value(projected, "value")))
		elif GFVariantData.get_option_bool(state, "preserve_array_shape", true):
			result.append(null)
	_pop_active_container(state)
	return {
		"ok": true,
		"value": result,
	}


static func _handle_unsupported(reason: String, value: Variant, state: Dictionary) -> Dictionary:
	_record_projection_issue(reason, value, state)
	var mode: String = GFVariantData.get_option_string(state, "unsupported", "drop").to_lower()
	match mode:
		"null":
			return { "ok": true, "value": null }
		"string":
			return { "ok": true, "value": GFVariantData.to_text(value, type_string(typeof(value))) }
		"metadata":
			return {
				"ok": true,
				"value": {
					"unsupported": reason,
					"type": type_string(typeof(value)),
				},
			}
		_:
			return { "ok": false }


static func _make_state(options: Dictionary) -> Dictionary:
	return {
		"max_depth": maxi(GFVariantData.get_option_int(options, "max_depth", 8), 0),
		"unsupported": GFVariantData.get_option_string(options, "unsupported", "drop"),
		"include_null": GFVariantData.get_option_bool(options, "include_null", true),
		"preserve_array_shape": GFVariantData.get_option_bool(options, "preserve_array_shape", true),
		"report": _variant_to_validation_report(GFVariantData.get_option_value(options, "_projection_report")),
		"path_segments": [],
		"active_containers": [],
	}


static func _make_allowed_lookup(options: Dictionary, schema: GFDictionarySchema) -> Dictionary:
	var allowed_fields: PackedStringArray = _to_packed_string_array(GFVariantData.get_option_value(options, "allowed_fields"))
	if allowed_fields.is_empty() and schema != null and GFVariantData.get_option_bool(options, "schema_fields_only", false):
		allowed_fields = schema.get_field_names()

	var result: Dictionary = {}
	for field_name: String in allowed_fields:
		if not field_name.is_empty():
			result[field_name] = true
	return result


static func _rename_key(source_key: Variant, field_name: String, rename_fields: Dictionary) -> Variant:
	if rename_fields.has(field_name):
		return GFVariantData.get_option_value(rename_fields, field_name)
	var field_key: StringName = StringName(field_name)
	if rename_fields.has(field_key):
		return GFVariantData.get_option_value(rename_fields, field_key)
	return source_key


static func _read_schema(options: Dictionary) -> GFDictionarySchema:
	var schema_value: Variant = GFVariantData.get_option_value(options, "schema")
	if schema_value is GFDictionarySchema:
		var schema: GFDictionarySchema = schema_value
		return schema
	return null


static func _is_plain_key(value: Variant) -> bool:
	return value is String or value is StringName or value is int


static func _is_plain_value(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return (
		value_type == TYPE_BOOL
		or value_type == TYPE_INT
		or value_type == TYPE_FLOAT
		or value_type == TYPE_STRING
		or value_type == TYPE_STRING_NAME
		or value_type == TYPE_VECTOR2
		or value_type == TYPE_VECTOR2I
		or value_type == TYPE_VECTOR3
		or value_type == TYPE_VECTOR3I
		or value_type == TYPE_VECTOR4
		or value_type == TYPE_VECTOR4I
		or value_type == TYPE_RECT2
		or value_type == TYPE_RECT2I
		or value_type == TYPE_COLOR
		or value_type == TYPE_PACKED_BYTE_ARRAY
		or value_type == TYPE_PACKED_INT32_ARRAY
		or value_type == TYPE_PACKED_INT64_ARRAY
		or value_type == TYPE_PACKED_FLOAT32_ARRAY
		or value_type == TYPE_PACKED_FLOAT64_ARRAY
		or value_type == TYPE_PACKED_STRING_ARRAY
		or value_type == TYPE_PACKED_VECTOR2_ARRAY
		or value_type == TYPE_PACKED_VECTOR3_ARRAY
		or value_type == TYPE_PACKED_COLOR_ARRAY
	)


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			var text: String = GFVariantData.to_text(item)
			if not text.is_empty():
				var _append_result: bool = result.append(text)
	elif value is String or value is StringName:
		var text_value: String = GFVariantData.to_text(value)
		if not text_value.is_empty():
			var _append_single_result: bool = result.append(text_value)
	return result


static func _is_container_active(value: Variant, state: Dictionary) -> bool:
	var active_containers: Array = _get_active_containers(state)
	for item: Variant in active_containers:
		if is_same(item, value):
			return true
	return false


static func _push_active_container(value: Variant, state: Dictionary) -> void:
	var active_containers: Array = _get_active_containers(state)
	active_containers.append(value)
	state["active_containers"] = active_containers


static func _pop_active_container(state: Dictionary) -> void:
	var active_containers: Array = _get_active_containers(state)
	if active_containers.is_empty():
		return
	active_containers.remove_at(active_containers.size() - 1)
	state["active_containers"] = active_containers


static func _get_active_containers(state: Dictionary) -> Array:
	var active_value: Variant = GFVariantData.get_option_value(state, "active_containers", [])
	if active_value is Array:
		var active_array: Array = active_value
		return active_array
	var active_containers: Array = []
	state["active_containers"] = active_containers
	return active_containers


static func _make_child_state(state: Dictionary, path_segment: Variant) -> Dictionary:
	var child_state: Dictionary = state.duplicate(false)
	var path_segments: Array = GFVariantData.get_option_array(state, "path_segments")
	path_segments.append(path_segment)
	child_state["path_segments"] = path_segments
	return child_state


static func _record_projection_issue(reason: String, value: Variant, state: Dictionary) -> void:
	var report: GFValidationReport = _variant_to_validation_report(GFVariantData.get_option_value(state, "report"))
	if report == null:
		return
	var path_segments: Array = GFVariantData.get_option_array(state, "path_segments")
	var issue_path: String = _format_projection_path(path_segments)
	var issue_key: Variant = path_segments[path_segments.size() - 1] if not path_segments.is_empty() else null
	var _issue: RefCounted = report.add_warning(
		StringName(reason),
		"Projection dropped a value.",
		issue_key,
		issue_path,
		{
			"reason": reason,
			"value_type": type_string(typeof(value)),
		}
	)


static func _format_projection_path(path_segments: Array) -> String:
	var path_text: String = ""
	for segment: Variant in path_segments:
		if segment is int:
			var segment_index: int = segment
			path_text += "[%d]" % segment_index
			continue
		var key_text: String = GFVariantData.to_text(segment)
		if key_text.is_empty():
			continue
		if path_text.is_empty():
			path_text = key_text
		else:
			path_text += "." + key_text
	return path_text


static func _variant_to_validation_report(value: Variant) -> GFValidationReport:
	if value is GFValidationReport:
		var report: GFValidationReport = value
		return report
	return null
