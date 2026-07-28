## GFShaderInterfaceSnapshot: 可持久化的 Shader uniform 接口快照。
##
## 从 Shader 反射结果捕获稳定排序的 uniform 声明，并用同一份数据校验参数集合
## 或比较接口漂移。快照只保存公开接口字段，不保存 shader 源码、材质当前值、
## 渲染后端产物或项目视觉语义。直接 new() 的实例保持未配置，必须经 capture()
## 或 from_dict() 建立后再使用。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 10.0.0
class_name GFShaderInterfaceSnapshot
extends Resource


# --- 常量 ---

## 当前快照字典 schema 版本。
## [br]
## @api public
## [br]
## @since 10.0.0
const CURRENT_SCHEMA_VERSION: int = 1

const _KIND_INTERFACE_MODE_INVALID: StringName = &"shader_interface_mode_invalid"
const _KIND_INTERFACE_MODE_MISMATCH: StringName = &"shader_interface_mode_mismatch"
const _KIND_INTERFACE_SCHEMA_VERSION_UNSUPPORTED: StringName = &"shader_interface_schema_version_unsupported"
const _KIND_INTERFACE_SNAPSHOT_MISSING: StringName = &"shader_interface_snapshot_missing"
const _KIND_PARAMETER_CLASS_MISMATCH: StringName = &"shader_parameter_class_mismatch"
const _KIND_PARAMETER_DUPLICATE: StringName = &"shader_parameter_duplicate"
const _KIND_PARAMETER_EXTRA: StringName = &"shader_parameter_extra"
const _KIND_PARAMETER_MISSING: StringName = &"shader_parameter_missing"
const _KIND_PARAMETER_NAME_INVALID: StringName = &"shader_parameter_name_invalid"
const _KIND_PARAMETER_TYPE_MISMATCH: StringName = &"shader_parameter_type_mismatch"
const _KIND_UNIFORM_DUPLICATE: StringName = &"shader_uniform_duplicate"
const _KIND_UNIFORM_EXTRA: StringName = &"shader_uniform_extra"
const _KIND_UNIFORM_INVALID: StringName = &"shader_uniform_invalid"
const _KIND_UNIFORM_MISSING: StringName = &"shader_uniform_missing"
const _KIND_UNIFORM_SIGNATURE_MISMATCH: StringName = &"shader_uniform_signature_mismatch"
const _SEVERITY_ERROR: String = "error"
const _SEVERITY_IGNORE: String = "ignore"
const _SEVERITY_INFO: String = "info"
const _SEVERITY_WARNING: String = "warning"
const _SIGNATURE_FIELDS: PackedStringArray = [
	"type",
	"class_name",
	"hint",
	"hint_string",
]


# --- 私有变量 ---

@export_storage var _configured: bool = false
@export_storage var _schema_version: int = 0
@export_storage var _shader_mode: int = -1
@export_storage var _uniforms: Array[Dictionary] = []:
	set(value):
		_uniforms = _normalize_uniform_entries(value)


# --- 公共方法 ---

## 从 Shader 当前反射接口创建快照。
## [br]
## 参数分组提示不会进入快照；uniform 会按名称和签名稳定排序。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param shader: 要捕获的 Shader；为空时返回 null。
## [br]
## @return 新快照，或 null。
static func capture(shader: Shader) -> GFShaderInterfaceSnapshot:
	if shader == null:
		return null

	var uniform_entries: Array[Dictionary] = []
	for uniform_value: Variant in shader.get_shader_uniform_list(false):
		uniform_entries.append(_normalize_uniform_value(uniform_value))
	return _make_snapshot(CURRENT_SCHEMA_VERSION, shader.get_mode(), uniform_entries)


## 从字典创建快照。
## [br]
## 输入会被深复制并规范化，但不会强转字段类型；不支持的 schema、缺失数组和
## 无效条目由 validate_definition() 报告。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param data: 快照字典。
## [br]
## @schema data: Dictionary，包含 schema_version、shader_mode 和 uniforms；uniform 字段为 name、type、class_name、hint、hint_string、usage。
## [br]
## @return 新快照。
static func from_dict(data: Dictionary) -> GFShaderInterfaceSnapshot:
	var uniform_entries: Array[Dictionary] = []
	var uniforms_value: Variant = _get_field_value(data, "uniforms")
	if uniforms_value is Array:
		var uniform_values: Array = uniforms_value
		for uniform_value: Variant in uniform_values:
			uniform_entries.append(_normalize_uniform_value(uniform_value))
	else:
		uniform_entries.append(_make_invalid_uniform_entry())
	return _make_snapshot(
		_get_strict_int_field(data, "schema_version", 0),
		_get_strict_int_field(data, "shader_mode", -1),
		uniform_entries
	)


## 获取快照 schema 版本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return schema 版本。
func get_schema_version() -> int:
	return _schema_version


## 获取捕获时的 Shader 模式。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Shader.Mode 对应整数。
func get_shader_mode() -> int:
	return _shader_mode


## 获取稳定排序的 uniform 条目深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return uniform 条目数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 name、type、class_name、hint、hint_string 和 usage。
func get_uniforms() -> Array[Dictionary]:
	return _duplicate_uniform_entries(_uniforms)


## 获取稳定排序的 uniform 名。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return uniform 名数组。
## [br]
## @schema return: Array[StringName]，按名称稳定排序。
func get_uniform_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for uniform: Dictionary in _uniforms:
		var parameter_name: StringName = GFVariantData.get_option_string_name(
			uniform,
			"name",
			&""
		)
		if parameter_name != &"":
			result.append(parameter_name)
	return result


## 检查接口是否声明 uniform。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param parameter_name: uniform 名。
## [br]
## @return 已声明时返回 true。
func has_uniform(parameter_name: StringName) -> bool:
	return not get_uniform(parameter_name).is_empty()


## 获取 uniform 条目深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param parameter_name: uniform 名。
## [br]
## @return uniform 条目；不存在时返回空字典。
## [br]
## @schema return: Dictionary，包含 name、type、class_name、hint、hint_string 和 usage。
func get_uniform(parameter_name: StringName) -> Dictionary:
	if parameter_name == &"":
		return {}
	for uniform: Dictionary in _uniforms:
		if GFVariantData.get_option_string_name(uniform, "name", &"") == parameter_name:
			return uniform.duplicate(true)
	return {}


## 检查一个值是否符合已声明 uniform 类型。
## [br]
## 数字类型严格匹配，不做 int/float 隐式转换；Object 参数会继续检查资源类。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param parameter_name: uniform 名。
## [br]
## @param value: 候选值。
## [br]
## @param options: 支持 allow_null_object，默认 true。
## [br]
## @schema value: Variant shader parameter value.
## [br]
## @schema options: Dictionary，allow_null_object 控制 TYPE_OBJECT uniform 是否接受 null。
## [br]
## @return 已声明且值兼容时返回 true。
func accepts_parameter_value(
	parameter_name: StringName,
	value: Variant,
	options: Dictionary = {}
) -> bool:
	if not validate_definition().is_ok():
		return false
	var uniform: Dictionary = get_uniform(parameter_name)
	if uniform.is_empty():
		return false
	return _get_value_mismatch_kind(
		uniform,
		value,
		GFVariantData.get_option_bool(options, "allow_null_object", true)
	) == &""


## 校验快照 schema、Shader 模式、uniform 字段和重复名称。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param options: 支持 subject 和 metadata。
## [br]
## @schema options: Dictionary，subject 覆盖报告主题，metadata 为调用方报告元数据。
## [br]
## @return 标准校验报告。
func validate_definition(options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = _make_report(
		options,
		"Shader interface snapshot"
	)
	report.metadata["schema_version"] = _schema_version
	report.metadata["shader_mode"] = _shader_mode
	report.extra_fields["uniform_count"] = _uniforms.size()
	if not _configured:
		var _missing_snapshot_issue: RefCounted = report.add_error(
			_KIND_INTERFACE_SNAPSHOT_MISSING,
			"Shader interface snapshot has not been captured or imported."
		)
		return report

	if _schema_version != CURRENT_SCHEMA_VERSION:
		var _schema_issue: RefCounted = report.add_error(
			_KIND_INTERFACE_SCHEMA_VERSION_UNSUPPORTED,
			"Shader interface snapshot schema version is unsupported.",
			_schema_version,
			"schema_version",
			{
				"expected": CURRENT_SCHEMA_VERSION,
				"actual": _schema_version,
			}
		)
	if not _is_valid_shader_mode(_shader_mode):
		var _mode_issue: RefCounted = report.add_error(
			_KIND_INTERFACE_MODE_INVALID,
			"Shader interface snapshot mode is invalid.",
			_shader_mode,
			"shader_mode"
		)

	var seen_names: Dictionary = {}
	for uniform_index: int in range(_uniforms.size()):
		var uniform: Dictionary = _uniforms[uniform_index]
		var uniform_path: String = "uniforms[%d]" % uniform_index
		if (
			not _has_uniform_schema_fields(uniform)
			or not _has_valid_uniform_field_types(uniform)
		):
			var _malformed_issue: RefCounted = report.add_error(
				_KIND_UNIFORM_INVALID,
				"Shader uniform entry fields do not match the snapshot schema.",
				uniform_index,
				uniform_path
			)
			continue

		var parameter_name: StringName = GFVariantData.get_option_string_name(
			uniform,
			"name",
			&""
		)
		var value_type: int = GFVariantData.get_option_int(uniform, "type", TYPE_NIL)
		if parameter_name == &"" or value_type <= TYPE_NIL or value_type >= TYPE_MAX:
			var _invalid_issue: RefCounted = report.add_error(
				_KIND_UNIFORM_INVALID,
				"Shader uniform entry must declare a non-empty name and valid Variant type.",
				parameter_name,
				uniform_path,
				{
					"type": value_type,
				}
			)
			continue

		var parameter_key: String = String(parameter_name)
		if seen_names.has(parameter_key):
			var _duplicate_issue: RefCounted = report.add_error(
				_KIND_UNIFORM_DUPLICATE,
				"Shader interface snapshot contains a duplicate uniform.",
				parameter_name,
				uniform_path
			)
		seen_names[parameter_key] = true
	return report


## 根据快照校验参数字典。
## [br]
## Profile 默认按部分覆盖处理，因此缺失 uniform 默认忽略；未知参数和错型值默认报错。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param parameters: uniform 名到参数值的映射。
## [br]
## @param options: 支持 subject、metadata、missing_severity、extra_severity、type_mismatch_severity 和 allow_null_object。
## [br]
## @schema parameters: Dictionary[StringName|String, Variant] shader parameter values.
## [br]
## @schema options: Dictionary，severity 可为 ignore、info、warning 或 error；missing 默认 ignore，extra/type mismatch 默认 error；allow_null_object 默认 true。
## [br]
## @return 标准校验报告。
func validate_parameters(
	parameters: Dictionary,
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = _make_report(
		options,
		"Shader parameter contract"
	)
	var definition_report: GFValidationReport = validate_definition({
		"subject": report.subject,
	})
	var _definition_merged: RefCounted = report.merge(definition_report, false)
	if not definition_report.is_ok():
		return report

	var missing_severity: String = _get_severity_option(
		options,
		"missing_severity",
		_SEVERITY_IGNORE
	)
	var extra_severity: String = _get_severity_option(
		options,
		"extra_severity",
		_SEVERITY_ERROR
	)
	var type_mismatch_severity: String = _get_severity_option(
		options,
		"type_mismatch_severity",
		_SEVERITY_ERROR
	)
	var allow_null_object: bool = GFVariantData.get_option_bool(
		options,
		"allow_null_object",
		true
	)
	var normalized_parameters: Dictionary = {}
	var parameter_names: PackedStringArray = PackedStringArray()
	for raw_key: Variant in parameters.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name == &"":
			var _name_issue: RefCounted = report.add_error(
				_KIND_PARAMETER_NAME_INVALID,
				"Shader parameter names must be non-empty String or StringName values.",
				GFVariantData.to_text(raw_key),
				"parameters"
			)
			continue

		var parameter_key: String = String(parameter_name)
		if normalized_parameters.has(parameter_key):
			var _duplicate_issue: RefCounted = report.add_error(
				_KIND_PARAMETER_DUPLICATE,
				"Shader parameter dictionary contains an equivalent duplicate name.",
				parameter_name,
				"parameters.%s" % parameter_key
			)
			continue
		normalized_parameters[parameter_key] = parameters[raw_key]
		var _name_appended: bool = parameter_names.append(parameter_key)
	parameter_names.sort()

	var declared_parameters: Dictionary = _uniform_map(_uniforms)
	var missing_count: int = 0
	var matched_count: int = 0
	var type_mismatch_count: int = 0
	for parameter_name: StringName in get_uniform_names():
		var parameter_key: String = String(parameter_name)
		if not normalized_parameters.has(parameter_key):
			missing_count += 1
			_add_issue_by_severity(
				report,
				missing_severity,
				_KIND_PARAMETER_MISSING,
				"Shader parameter is missing from the supplied values.",
				parameter_name,
				"parameters.%s" % parameter_key
			)
			continue

		matched_count += 1
		var uniform: Dictionary = GFVariantData.get_option_dictionary(
			declared_parameters,
			parameter_key
		)
		var parameter_value: Variant = normalized_parameters[parameter_key]
		var mismatch_kind: StringName = _get_value_mismatch_kind(
			uniform,
			parameter_value,
			allow_null_object
		)
		if mismatch_kind == &"":
			continue
		type_mismatch_count += 1
		_add_issue_by_severity(
			report,
			type_mismatch_severity,
			mismatch_kind,
			"Shader parameter value does not match the declared uniform type.",
			parameter_name,
			"parameters.%s" % parameter_key,
			_make_type_mismatch_metadata(uniform, parameter_value)
		)

	var extra_count: int = 0
	for parameter_key: String in parameter_names:
		if declared_parameters.has(parameter_key):
			continue
		extra_count += 1
		_add_issue_by_severity(
			report,
			extra_severity,
			_KIND_PARAMETER_EXTRA,
			"Shader parameter is not declared by the interface snapshot.",
			StringName(parameter_key),
			"parameters.%s" % parameter_key
		)

	report.extra_fields["declared_count"] = declared_parameters.size()
	report.extra_fields["supplied_count"] = parameters.size()
	report.extra_fields["matched_count"] = matched_count
	report.extra_fields["missing_count"] = missing_count
	report.extra_fields["extra_count"] = extra_count
	report.extra_fields["type_mismatch_count"] = type_mismatch_count
	return report


## 比较期望快照与实际快照。
## [br]
## 当前快照作为 expected；actual 缺失和签名变化默认报错，新增 uniform 默认 warning。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param actual: 实际接口快照。
## [br]
## @param options: 支持 subject、metadata、mode_mismatch_severity、missing_severity、extra_severity、signature_severity 和 usage_severity。
## [br]
## @schema options: Dictionary，severity 可为 ignore、info、warning 或 error；mode/missing/signature 默认 error，extra/usage 默认 warning。
## [br]
## @return 标准校验报告。
func compare_with(
	actual: GFShaderInterfaceSnapshot,
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = _make_report(
		options,
		"Shader interface comparison"
	)
	if actual == null:
		var _missing_snapshot_issue: RefCounted = report.add_error(
			_KIND_INTERFACE_SNAPSHOT_MISSING,
			"Actual shader interface snapshot is missing."
		)
		return report

	var expected_definition: GFValidationReport = validate_definition()
	var actual_definition: GFValidationReport = actual.validate_definition()
	var _expected_merged: RefCounted = report.merge(expected_definition, false)
	var _actual_merged: RefCounted = report.merge(actual_definition, false)
	if not expected_definition.is_ok() or not actual_definition.is_ok():
		return report

	var mode_severity: String = _get_severity_option(
		options,
		"mode_mismatch_severity",
		_SEVERITY_ERROR
	)
	var missing_severity: String = _get_severity_option(
		options,
		"missing_severity",
		_SEVERITY_ERROR
	)
	var extra_severity: String = _get_severity_option(
		options,
		"extra_severity",
		_SEVERITY_WARNING
	)
	var signature_severity: String = _get_severity_option(
		options,
		"signature_severity",
		_SEVERITY_ERROR
	)
	var usage_severity: String = _get_severity_option(
		options,
		"usage_severity",
		_SEVERITY_WARNING
	)
	if _shader_mode != actual.get_shader_mode():
		_add_issue_by_severity(
			report,
			mode_severity,
			_KIND_INTERFACE_MODE_MISMATCH,
			"Shader interface modes differ.",
			actual.get_shader_mode(),
			"shader_mode",
			{
				"expected": _shader_mode,
				"actual": actual.get_shader_mode(),
			}
		)

	var expected_uniforms: Dictionary = _uniform_map(_uniforms)
	var actual_uniforms: Dictionary = _uniform_map(actual.get_uniforms())
	var expected_names: PackedStringArray = _sorted_dictionary_keys(expected_uniforms)
	var actual_names: PackedStringArray = _sorted_dictionary_keys(actual_uniforms)
	var matched_count: int = 0
	var missing_count: int = 0
	var extra_count: int = 0
	var signature_mismatch_count: int = 0
	for parameter_key: String in expected_names:
		if not actual_uniforms.has(parameter_key):
			missing_count += 1
			_add_issue_by_severity(
				report,
				missing_severity,
				_KIND_UNIFORM_MISSING,
				"Expected shader uniform is missing from the actual interface.",
				StringName(parameter_key),
				"uniforms.%s" % parameter_key
			)
			continue

		matched_count += 1
		var expected_uniform: Dictionary = GFVariantData.get_option_dictionary(
			expected_uniforms,
			parameter_key
		)
		var actual_uniform: Dictionary = GFVariantData.get_option_dictionary(
			actual_uniforms,
			parameter_key
		)
		var changed_fields: Array[String] = _changed_uniform_fields(
			expected_uniform,
			actual_uniform,
			_SIGNATURE_FIELDS
		)
		if not changed_fields.is_empty():
			signature_mismatch_count += 1
			_add_issue_by_severity(
				report,
				signature_severity,
				_KIND_UNIFORM_SIGNATURE_MISMATCH,
				"Shader uniform signature differs from the expected interface.",
				StringName(parameter_key),
				"uniforms.%s" % parameter_key,
				_make_signature_mismatch_metadata(
					expected_uniform,
					actual_uniform,
					changed_fields
				)
			)
		if expected_uniform["usage"] != actual_uniform["usage"]:
			signature_mismatch_count += 1
			_add_issue_by_severity(
				report,
				usage_severity,
				_KIND_UNIFORM_SIGNATURE_MISMATCH,
				"Shader uniform usage flags differ from the expected interface.",
				StringName(parameter_key),
				"uniforms.%s" % parameter_key,
				_make_signature_mismatch_metadata(
					expected_uniform,
					actual_uniform,
					["usage"]
				)
			)

	for parameter_key: String in actual_names:
		if expected_uniforms.has(parameter_key):
			continue
		extra_count += 1
		_add_issue_by_severity(
			report,
			extra_severity,
			_KIND_UNIFORM_EXTRA,
			"Actual shader interface declares an additional uniform.",
			StringName(parameter_key),
			"uniforms.%s" % parameter_key
		)

	report.extra_fields["expected_count"] = expected_uniforms.size()
	report.extra_fields["actual_count"] = actual_uniforms.size()
	report.extra_fields["matched_count"] = matched_count
	report.extra_fields["missing_count"] = missing_count
	report.extra_fields["extra_count"] = extra_count
	report.extra_fields["signature_mismatch_count"] = signature_mismatch_count
	return report


## 将 Shader 当前接口与本快照比较。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param shader: 实际 Shader。
## [br]
## @param options: 传给 compare_with() 的报告和 severity 选项。
## [br]
## @schema options: Dictionary compare_with() options.
## [br]
## @return 标准校验报告。
func validate_shader(
	shader: Shader,
	options: Dictionary = {}
) -> GFValidationReport:
	return compare_with(capture(shader), options)


## 创建快照深拷贝。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 新快照。
func duplicate_snapshot() -> GFShaderInterfaceSnapshot:
	return _make_snapshot(
		_schema_version,
		_shader_mode,
		_uniforms,
		_configured
	)


## 转换为稳定排序的快照字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 快照字典。
## [br]
## @schema return: Dictionary，包含 schema_version、shader_mode 和 uniforms。
func to_dict() -> Dictionary:
	return {
		"schema_version": _schema_version,
		"shader_mode": _shader_mode,
		"uniforms": _duplicate_uniform_entries(_uniforms),
	}


# --- 私有/辅助方法 ---

static func _make_snapshot(
	schema_version: int,
	shader_mode: int,
	uniform_entries: Array[Dictionary],
	configured: bool = true
) -> GFShaderInterfaceSnapshot:
	var snapshot: GFShaderInterfaceSnapshot = GFShaderInterfaceSnapshot.new()
	snapshot._schema_version = schema_version
	snapshot._shader_mode = shader_mode
	snapshot._uniforms = uniform_entries
	snapshot._configured = configured
	return snapshot


static func _normalize_uniform_entries(
	uniform_entries: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uniform: Dictionary in uniform_entries:
		result.append(_normalize_uniform_value(uniform))
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return _uniform_sort_key(left) < _uniform_sort_key(right)
	)
	return result


static func _normalize_uniform_value(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return _make_invalid_uniform_entry()
	var uniform: Dictionary = value
	if (
		not _has_uniform_schema_fields(uniform)
		or not _has_valid_uniform_field_types(uniform)
	):
		return _make_invalid_uniform_entry()

	var name_value: Variant = _get_field_value(uniform, "name")
	var type_value: Variant = _get_field_value(uniform, "type")
	var class_name_value: Variant = _get_field_value(uniform, "class_name")
	var hint_value: Variant = _get_field_value(uniform, "hint")
	var hint_string_value: Variant = _get_field_value(uniform, "hint_string")
	var usage_value: Variant = _get_field_value(uniform, "usage")

	return {
		"name": _to_strict_string_name(name_value),
		"type": _to_strict_int(type_value),
		"class_name": _to_strict_string_name(class_name_value),
		"hint": _to_strict_int(hint_value),
		"hint_string": _to_strict_string(hint_string_value),
		"usage": _to_strict_int(usage_value),
	}


static func _make_invalid_uniform_entry() -> Dictionary:
	return {
		"name": &"",
		"type": TYPE_NIL,
		"class_name": &"",
		"hint": PROPERTY_HINT_NONE,
		"hint_string": "",
		"usage": PROPERTY_USAGE_DEFAULT,
	}


static func _has_uniform_schema_fields(uniform: Dictionary) -> bool:
	for field_name: String in [
		"name",
		"type",
		"class_name",
		"hint",
		"hint_string",
		"usage",
	]:
		if not _has_field(uniform, field_name):
			return false
	return true


static func _has_valid_uniform_field_types(uniform: Dictionary) -> bool:
	return (
		_is_string_name_value(_get_field_value(uniform, "name"))
		and typeof(_get_field_value(uniform, "type")) == TYPE_INT
		and _is_string_name_value(_get_field_value(uniform, "class_name"))
		and typeof(_get_field_value(uniform, "hint")) == TYPE_INT
		and _is_string_value(_get_field_value(uniform, "hint_string"))
		and typeof(_get_field_value(uniform, "usage")) == TYPE_INT
	)


static func _has_field(data: Dictionary, field_name: String) -> bool:
	return data.has(field_name) or data.has(StringName(field_name))


static func _get_field_value(data: Dictionary, field_name: String) -> Variant:
	if data.has(field_name):
		return data[field_name]
	var string_name_field: StringName = StringName(field_name)
	if data.has(string_name_field):
		return data[string_name_field]
	return null


static func _get_strict_int_field(
	data: Dictionary,
	field_name: String,
	default_value: int
) -> int:
	var value: Variant = _get_field_value(data, field_name)
	return _to_strict_int(value) if typeof(value) == TYPE_INT else default_value


static func _is_string_name_value(value: Variant) -> bool:
	return value is String or value is StringName


static func _is_string_value(value: Variant) -> bool:
	return value is String


static func _to_strict_string_name(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return &""


static func _to_strict_string(value: Variant) -> String:
	if value is String:
		var text_value: String = value
		return text_value
	return ""


static func _to_strict_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var int_value: int = value
		return int_value
	return 0


static func _uniform_sort_key(uniform: Dictionary) -> String:
	return "%s\u001f%010d\u001f%s\u001f%010d\u001f%s\u001f%010d" % [
		GFVariantData.get_option_string(uniform, "name"),
		GFVariantData.get_option_int(uniform, "type", TYPE_NIL),
		GFVariantData.get_option_string(uniform, "class_name"),
		GFVariantData.get_option_int(uniform, "hint", PROPERTY_HINT_NONE),
		GFVariantData.get_option_string(uniform, "hint_string"),
		GFVariantData.get_option_int(uniform, "usage", PROPERTY_USAGE_DEFAULT),
	]


static func _duplicate_uniform_entries(
	uniform_entries: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uniform: Dictionary in uniform_entries:
		result.append(uniform.duplicate(true))
	return result


static func _is_valid_shader_mode(shader_mode: int) -> bool:
	match shader_mode:
		Shader.MODE_SPATIAL:
			return true
		Shader.MODE_CANVAS_ITEM:
			return true
		Shader.MODE_PARTICLES:
			return true
		Shader.MODE_SKY:
			return true
		Shader.MODE_FOG:
			return true
		Shader.MODE_TEXTURE_BLIT:
			return true
		_:
			return false


static func _make_report(
	options: Dictionary,
	default_subject: String
) -> GFValidationReport:
	return GFValidationReport.new(
		GFVariantData.get_option_string(options, "subject", default_subject),
		GFVariantData.get_option_dictionary(options, "metadata")
	)


static func _variant_to_parameter_name(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return &""


static func _get_value_mismatch_kind(
	uniform: Dictionary,
	value: Variant,
	allow_null_object: bool
) -> StringName:
	var expected_type: int = GFVariantData.get_option_int(uniform, "type", TYPE_NIL)
	var actual_type: int = typeof(value)
	if expected_type != TYPE_OBJECT:
		return &"" if actual_type == expected_type else _KIND_PARAMETER_TYPE_MISMATCH
	if value == null:
		return &"" if allow_null_object else _KIND_PARAMETER_TYPE_MISMATCH
	if actual_type != TYPE_OBJECT or not (value is Object):
		return _KIND_PARAMETER_TYPE_MISMATCH

	var object_value: Object = value
	if not is_instance_valid(object_value):
		return _KIND_PARAMETER_CLASS_MISMATCH
	var expected_class_name: String = _get_expected_object_class(uniform)
	if expected_class_name.is_empty() or object_value.is_class(expected_class_name):
		return &""
	return _KIND_PARAMETER_CLASS_MISMATCH


static func _get_expected_object_class(uniform: Dictionary) -> String:
	var class_name_hint: String = GFVariantData.get_option_string(
		uniform,
		"class_name"
	).strip_edges()
	if not class_name_hint.is_empty():
		return class_name_hint
	var hint_string: String = GFVariantData.get_option_string(
		uniform,
		"hint_string"
	).strip_edges()
	if hint_string.is_empty():
		return ""
	return hint_string.split(",", false, 1)[0].strip_edges()


static func _make_type_mismatch_metadata(
	uniform: Dictionary,
	value: Variant
) -> Dictionary:
	var expected_type: int = GFVariantData.get_option_int(uniform, "type", TYPE_NIL)
	var actual_type: int = typeof(value)
	return {
		"expected_type": expected_type,
		"expected_type_name": type_string(expected_type),
		"actual_type": actual_type,
		"actual_type_name": type_string(actual_type),
		"expected_class_name": _get_expected_object_class(uniform),
	}


static func _get_severity_option(
	options: Dictionary,
	option_name: String,
	default_value: String
) -> String:
	var severity: String = GFVariantData.get_option_string(
		options,
		option_name,
		default_value
	).strip_edges().to_lower()
	if [
		_SEVERITY_IGNORE,
		_SEVERITY_INFO,
		_SEVERITY_WARNING,
		_SEVERITY_ERROR,
	].has(severity):
		return severity
	return default_value


static func _add_issue_by_severity(
	report: GFValidationReport,
	severity: String,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	match severity:
		_SEVERITY_IGNORE:
			return
		_SEVERITY_INFO:
			var _info_issue: RefCounted = report.add_info(
				kind,
				message,
				key,
				path,
				metadata
			)
		_SEVERITY_WARNING:
			var _warning_issue: RefCounted = report.add_warning(
				kind,
				message,
				key,
				path,
				metadata
			)
		_:
			var _error_issue: RefCounted = report.add_error(
				kind,
				message,
				key,
				path,
				metadata
			)


static func _uniform_map(uniform_entries: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for uniform: Dictionary in uniform_entries:
		var parameter_name: StringName = GFVariantData.get_option_string_name(
			uniform,
			"name",
			&""
		)
		if parameter_name != &"":
			result[String(parameter_name)] = uniform.duplicate(true)
	return result


static func _sorted_dictionary_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _key_appended: bool = result.append(GFVariantData.to_text(raw_key))
	result.sort()
	return result


static func _changed_uniform_fields(
	expected: Dictionary,
	actual: Dictionary,
	field_names: PackedStringArray
) -> Array[String]:
	var result: Array[String] = []
	for field_name: String in field_names:
		if expected[field_name] != actual[field_name]:
			result.append(field_name)
	return result


static func _make_signature_mismatch_metadata(
	expected: Dictionary,
	actual: Dictionary,
	changed_fields: Array[String]
) -> Dictionary:
	return {
		"changed_fields": changed_fields.duplicate(),
		"expected": expected.duplicate(true),
		"actual": actual.duplicate(true),
	}
