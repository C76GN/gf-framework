## GFNetworkContractField: 网络契约中的单个 payload 字段。
##
## 字段只描述名称、值类型、必填性和默认值，用于生成器、校验器或项目工具，
## 不规定消息含义、权限或同步策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNetworkContractField
extends Resource


# --- 枚举 ---

## 字段值类型。
## [br]
## @api public
enum ValueType {
	## 任意 Variant。
	VARIANT,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector3。
	VECTOR3,
	## Vector2i。
	VECTOR2I,
	## Vector3i。
	VECTOR3I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
	## NodePath。
	NODE_PATH,
	## Object 或 Resource。
	OBJECT,
}


# --- 常量 ---

const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _TRANSPORT_VALUE_VALIDATOR = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")


# --- 导出变量 ---

## 字段稳定名称。
## [br]
## @api public
@export var field_name: StringName = &""

## 编辑器展示名称。
## [br]
## @api public
@export var display_name: String = ""

## 字段值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.VARIANT

## 是否为必填字段。
## [br]
## @api public
@export var required: bool = true

## 是否允许显式 null 值。
## [br]
## @api public
@export var allow_null: bool = false

## 可选默认值。生成器会尽量把可表达的默认值写入生成函数签名。
## [br]
## @api public
## [br]
## @schema default_value: Variant，字段默认值；建议使用与 value_type 匹配的可复制值。
@export var default_value: Variant = null

## Object / Resource 字段的类名提示，仅用于工具校验。
## [br]
## @api public
@export var class_name_hint: StringName = &""

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义字段元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取字段名称。
## [br]
## @api public
## [br]
## @return 字段名称。
func get_field_name() -> StringName:
	return field_name


## 获取展示名称。
## [br]
## @api public
## [br]
## @return 展示名称。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if field_name != &"":
		return String(field_name)
	return "Network Field"


## 获取默认值副本。
## [br]
## @api public
## [br]
## @return 默认值。
## [br]
## @schema return: Variant，default_value 的深拷贝或原始标量值。
func get_default_value() -> Variant:
	return _duplicate_value(default_value)


## 归一化字段值。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 归一化后的值。
## [br]
## @schema value: Variant，待归一化字段值。
## [br]
## @schema return: Variant，字段默认值或输入值的安全副本。
func normalize_value(value: Variant) -> Variant:
	if value == null and default_value != null:
		return get_default_value()
	return _duplicate_value(value)


## 校验字段定义是否完整。
## [br]
## @api public
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_definition() -> Dictionary:
	var issues: Array[Dictionary] = []
	if field_name == &"":
		issues.append(_make_issue("error", "empty_field_name", "Network contract field name is empty."))
	if value_type == ValueType.OBJECT:
		issues.append(_make_issue("error", "object_value_type_not_transport_safe", "Network contract fields must not use Object values across the transport boundary."))
	return _finalize_report(issues)


## 校验字段值是否符合声明类型。
## [br]
## @api public
## [br]
## @param value: 字段值。
## [br]
## @return 校验报告字典。
## [br]
## @schema value: Variant，待校验字段值。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_value(value: Variant) -> Dictionary:
	if value == null:
		if required and not allow_null:
			return _finalize_report([_make_issue("error", "null_not_allowed", "Network contract field does not allow null.")])
		return _finalize_report([])

	var issue: Dictionary = _get_value_type_issue(value)
	if not issue.is_empty():
		return _finalize_report([issue])
	var transport_report: Dictionary = _TRANSPORT_VALUE_VALIDATOR.validate(value)
	if not GFVariantData.get_option_bool(transport_report, "ok"):
		return _finalize_report([_make_issue(
			"error",
			"value_not_transport_safe",
			"Network contract field contains a transport-unsafe value at %s (%s)." % [
				GFVariantData.get_option_string(transport_report, "path", "$"),
				GFVariantData.get_option_string(transport_report, "error", "invalid_value"),
			]
		)])
	return _finalize_report([])


## 描述字段契约。
## [br]
## @api public
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含 field_name、display_name、value_type、required、allow_null、default_value、class_name_hint、metadata。
func describe() -> Dictionary:
	return {
		"field_name": field_name,
		"display_name": get_display_name(),
		"value_type": value_type,
		"required": required,
		"allow_null": allow_null,
		"default_value": get_default_value(),
		"class_name_hint": class_name_hint,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_value_type_issue(value: Variant) -> Dictionary:
	match value_type:
		ValueType.BOOL:
			if not (value is bool):
				return _make_type_issue("bool")
		ValueType.INT:
			if typeof(value) != TYPE_INT:
				return _make_type_issue("int")
		ValueType.FLOAT:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				return _make_type_issue("float")
		ValueType.STRING:
			if not (value is String):
				return _make_type_issue("String")
		ValueType.STRING_NAME:
			if not (value is StringName):
				return _make_type_issue("StringName")
		ValueType.VECTOR2:
			if not (value is Vector2):
				return _make_type_issue("Vector2")
		ValueType.VECTOR3:
			if not (value is Vector3):
				return _make_type_issue("Vector3")
		ValueType.VECTOR2I:
			if not (value is Vector2i):
				return _make_type_issue("Vector2i")
		ValueType.VECTOR3I:
			if not (value is Vector3i):
				return _make_type_issue("Vector3i")
		ValueType.COLOR:
			if not (value is Color):
				return _make_type_issue("Color")
		ValueType.DICTIONARY:
			if not (value is Dictionary):
				return _make_type_issue("Dictionary")
		ValueType.ARRAY:
			if not (value is Array):
				return _make_type_issue("Array")
		ValueType.NODE_PATH:
			if not (value is NodePath):
				return _make_type_issue("NodePath")
		ValueType.OBJECT:
			return _make_issue("error", "object_value_type_not_transport_safe", "Network contract fields must not use Object values across the transport boundary.")
		_:
			pass
	return {}


func _object_matches_class_hint(value: Object) -> bool:
	if value == null or class_name_hint == &"":
		return true

	var hint: String = String(class_name_hint)
	if value.is_class(hint):
		return true

	var script: Script = _get_script_value(value.get_script())
	while script != null:
		if String(script.get_global_name()) == hint or script.resource_path == hint:
			return true
		script = script.get_base_script()
	return false


func _make_type_issue(expected_type: String) -> Dictionary:
	return _make_issue("error", "type_mismatch", "Network contract field expected %s." % expected_type)


func _make_issue(severity: String, kind: String, message: String) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"field_name": field_name,
		"message": message,
	}
	if field_name != &"":
		issue["path"] = String(field_name)
	return issue


func _finalize_report(issues: Array[Dictionary]) -> Dictionary:
	var report: Dictionary = {
		"subject": "Network contract field",
		"field_name": field_name,
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract field", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
	})


func _get_validation_next_actions() -> Dictionary:
	return {
		"empty_field_name": "Assign every network contract field a stable field_name.",
		"null_not_allowed": "Provide a value or allow null for this network contract field.",
		"type_mismatch": "Send a value matching the declared network contract field type.",
		"class_name_mismatch": "Send an Object or Resource matching class_name_hint.",
		"object_value_type_not_transport_safe": "Use a transport-safe identifier, Dictionary, Array, NodePath, StringName, or numeric value instead of Object.",
		"value_not_transport_safe": "Remove nested Object, Callable, Signal, RID, circular containers, non-finite numbers, or over-budget values.",
	}


func _duplicate_value(value: Variant) -> Variant:
	if value is Dictionary:
		return GFVariantData.as_dictionary(value).duplicate(true)
	if value is Array:
		return GFVariantData.as_array(value).duplicate(true)
	if value is PackedStringArray:
		var string_array: PackedStringArray = value
		return string_array.duplicate()
	if value is PackedByteArray:
		var byte_array: PackedByteArray = value
		return byte_array.duplicate()
	if value is PackedFloat32Array:
		var float32_array: PackedFloat32Array = value
		return float32_array.duplicate()
	if value is PackedFloat64Array:
		var float64_array: PackedFloat64Array = value
		return float64_array.duplicate()
	if value is PackedInt32Array:
		var int32_array: PackedInt32Array = value
		return int32_array.duplicate()
	if value is PackedInt64Array:
		var int64_array: PackedInt64Array = value
		return int64_array.duplicate()
	return value


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null
