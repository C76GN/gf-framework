## GFValidationConstraintRule: 通用约束校验规则资源。
##
## 为 `GFValidationRule` 补齐范围、集合、正则和尺寸这类跨模块常用约束。
## 规则只检查传入值，不解释字段业务语义；调用方可把它挂到 `GFSchemaField`、
## 设置定义、导入计划或项目自己的校验套件中。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFValidationConstraintRule
extends GFValidationRule


# --- 枚举 ---

## 约束类别。
## [br]
## @api public
## [br]
## @since 6.0.0
enum ConstraintKind {
	## 数值范围。
	RANGE,
	## 允许值集合。
	SET,
	## 字符串正则表达式。
	REGEX,
	## String、Array、Dictionary 或 PackedArray 尺寸。
	SIZE,
}


# --- 导出变量 ---

## 约束类别。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var constraint_kind: ConstraintKind = ConstraintKind.RANGE

## 是否检查最小数值。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var has_minimum: bool = false

## 最小数值。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var minimum: float = 0.0

## 最小数值是否包含边界。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var inclusive_minimum: bool = true

## 是否检查最大数值。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var has_maximum: bool = false

## 最大数值。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var maximum: float = 0.0

## 最大数值是否包含边界。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var inclusive_maximum: bool = true

## 允许值集合。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema allowed_values: Array of accepted Variant values.
@export var allowed_values: Array = []

## 字符串集合比较是否区分大小写。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var case_sensitive: bool = true

## 正则表达式。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var pattern: String = ""

## 是否要求正则匹配覆盖整个字符串。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var require_full_match: bool = false

## 是否允许空字符串跳过正则检查。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var allow_empty: bool = true

## 是否检查最小尺寸。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var has_minimum_size: bool = false

## 最小尺寸。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var minimum_size: int = 0

## 是否检查最大尺寸。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var has_maximum_size: bool = false

## 最大尺寸。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var maximum_size: int = 0


# --- 私有变量 ---

var _compiled_pattern: String = ""
var _compiled_regex: RegEx = null
var _compiled_regex_error: Error = OK


# --- 公共方法 ---

## 配置数值范围约束。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_minimum: 最小值。
## [br]
## @param p_maximum: 最大值。
## [br]
## @param options: 可选字段，支持 rule_id、description、enabled、severity、metadata、has_minimum、has_maximum、inclusive_minimum 和 inclusive_maximum。
## [br]
## @schema options: Dictionary range constraint configuration.
## [br]
## @return 当前规则。
func configure_range(
	p_minimum: float,
	p_maximum: float,
	options: Dictionary = {}
) -> GFValidationConstraintRule:
	var _configured_rule: GFValidationRule = configure(
		GFVariantData.get_option_string_name(options, "rule_id", &"range"),
		Callable(),
		options
	)
	constraint_kind = ConstraintKind.RANGE
	has_minimum = GFVariantData.get_option_bool(options, "has_minimum", true)
	minimum = p_minimum
	inclusive_minimum = GFVariantData.get_option_bool(options, "inclusive_minimum", true)
	has_maximum = GFVariantData.get_option_bool(options, "has_maximum", true)
	maximum = p_maximum
	inclusive_maximum = GFVariantData.get_option_bool(options, "inclusive_maximum", true)
	return self


## 配置允许值集合约束。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_allowed_values: 允许值数组。
## [br]
## @schema p_allowed_values: Array of accepted Variant values.
## [br]
## @param options: 可选字段，支持 rule_id、description、enabled、severity、metadata 和 case_sensitive。
## [br]
## @schema options: Dictionary set constraint configuration.
## [br]
## @return 当前规则。
func configure_set(p_allowed_values: Array, options: Dictionary = {}) -> GFValidationConstraintRule:
	var _configured_rule: GFValidationRule = configure(
		GFVariantData.get_option_string_name(options, "rule_id", &"allowed_value"),
		Callable(),
		options
	)
	constraint_kind = ConstraintKind.SET
	allowed_values = p_allowed_values.duplicate(true)
	case_sensitive = GFVariantData.get_option_bool(options, "case_sensitive", true)
	return self


## 配置字符串正则约束。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_pattern: 正则表达式。
## [br]
## @param options: 可选字段，支持 rule_id、description、enabled、severity、metadata、require_full_match 和 allow_empty。
## [br]
## @schema options: Dictionary regex constraint configuration.
## [br]
## @return 当前规则。
func configure_regex(p_pattern: String, options: Dictionary = {}) -> GFValidationConstraintRule:
	var _configured_rule: GFValidationRule = configure(
		GFVariantData.get_option_string_name(options, "rule_id", &"pattern"),
		Callable(),
		options
	)
	constraint_kind = ConstraintKind.REGEX
	pattern = p_pattern
	require_full_match = GFVariantData.get_option_bool(options, "require_full_match", false)
	allow_empty = GFVariantData.get_option_bool(options, "allow_empty", true)
	_clear_regex_cache()
	return self


## 配置尺寸约束。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_minimum_size: 最小尺寸。
## [br]
## @param p_maximum_size: 最大尺寸。
## [br]
## @param options: 可选字段，支持 rule_id、description、enabled、severity、metadata、has_minimum_size 和 has_maximum_size。
## [br]
## @schema options: Dictionary size constraint configuration.
## [br]
## @return 当前规则。
func configure_size(
	p_minimum_size: int,
	p_maximum_size: int,
	options: Dictionary = {}
) -> GFValidationConstraintRule:
	var _configured_rule: GFValidationRule = configure(
		GFVariantData.get_option_string_name(options, "rule_id", &"size"),
		Callable(),
		options
	)
	constraint_kind = ConstraintKind.SIZE
	has_minimum_size = GFVariantData.get_option_bool(options, "has_minimum_size", true)
	minimum_size = maxi(p_minimum_size, 0)
	has_maximum_size = GFVariantData.get_option_bool(options, "has_maximum_size", true)
	maximum_size = maxi(p_maximum_size, 0)
	return self


## 创建当前约束规则的配置副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 新规则。
func duplicate_rule() -> GFValidationRule:
	var rule: GFValidationConstraintRule = GFValidationConstraintRule.new()
	rule.rule_id = rule_id
	rule.description = description
	rule.target_kind = target_kind
	rule.enabled = enabled
	rule.severity = severity
	rule.metadata = metadata.duplicate(true)
	rule.callback = callback
	rule.constraint_kind = constraint_kind
	rule.has_minimum = has_minimum
	rule.minimum = minimum
	rule.inclusive_minimum = inclusive_minimum
	rule.has_maximum = has_maximum
	rule.maximum = maximum
	rule.inclusive_maximum = inclusive_maximum
	rule.allowed_values = allowed_values.duplicate(true)
	rule.case_sensitive = case_sensitive
	rule.pattern = pattern
	rule.require_full_match = require_full_match
	rule.allow_empty = allow_empty
	rule.has_minimum_size = has_minimum_size
	rule.minimum_size = minimum_size
	rule.has_maximum_size = has_maximum_size
	rule.maximum_size = maximum_size
	return rule


## 导出规则摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 规则描述字典。
## [br]
## @schema return: Dictionary validation constraint rule descriptor.
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["constraint_kind"] = constraint_kind
	result["constraint_kind_name"] = constraint_kind_to_name(constraint_kind)
	result["has_minimum"] = has_minimum
	result["minimum"] = minimum
	result["inclusive_minimum"] = inclusive_minimum
	result["has_maximum"] = has_maximum
	result["maximum"] = maximum
	result["inclusive_maximum"] = inclusive_maximum
	result["allowed_values"] = allowed_values.duplicate(true)
	result["case_sensitive"] = case_sensitive
	result["pattern"] = pattern
	result["require_full_match"] = require_full_match
	result["allow_empty"] = allow_empty
	result["has_minimum_size"] = has_minimum_size
	result["minimum_size"] = minimum_size
	result["has_maximum_size"] = has_maximum_size
	result["maximum_size"] = maximum_size
	return result


## 将约束类别转换为稳定名称。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param value: 约束类别。
## [br]
## @return 类别名称。
static func constraint_kind_to_name(value: ConstraintKind) -> String:
	match value:
		ConstraintKind.SET:
			return "set"
		ConstraintKind.REGEX:
			return "regex"
		ConstraintKind.SIZE:
			return "size"
		_:
			return "range"


# --- 可重写钩子 / 虚方法 ---

## 执行约束校验逻辑。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _target: 待校验值。
## [br]
## @schema _target: Variant validation target.
## [br]
## @param _report: 当前规则报告。
## [br]
## @param _context: 调用方上下文。
## [br]
## @schema _context: Dictionary validation context.
## [br]
## @return 约束校验结果。
## [br]
## @schema return: Variant validation hook result.
func _validate(_target: Variant, _report: GFValidationReport, _context: Dictionary) -> Variant:
	match constraint_kind:
		ConstraintKind.SET:
			_validate_set(_target, _report, _context)
		ConstraintKind.REGEX:
			_validate_regex(_target, _report, _context)
		ConstraintKind.SIZE:
			_validate_size(_target, _report, _context)
		_:
			_validate_range(_target, _report, _context)
	return null


# --- 私有/辅助方法 ---

func _validate_range(target: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if _has_invalid_range_configuration():
		_add_constraint_issue(
			report,
			&"range_invalid_configuration",
			"Range constraint configuration is invalid.",
			context,
			target,
			_describe_range(),
			null
		)
		return
	if not _is_numeric(target):
		_add_constraint_issue(
			report,
			&"range_invalid_type",
			"Value must be numeric for range constraint.",
			context,
			target,
			_describe_range(),
			_typeof_name(target)
		)
		return

	var value: float = GFVariantData.to_float(target, 0.0)
	if not _is_finite_number(value):
		_add_constraint_issue(
			report,
			&"range_non_finite",
			"Value must be finite for range constraint.",
			context,
			target,
			_describe_range(),
			value
		)
		return
	if not _is_in_range(value):
		_add_constraint_issue(
			report,
			&"range_out_of_bounds",
			"Value is outside the allowed range.",
			context,
			target,
			_describe_range(),
			value
		)


func _validate_set(target: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if allowed_values.is_empty():
		_add_constraint_issue(
			report,
			&"set_invalid_configuration",
			"Allowed value set cannot be empty.",
			context,
			target,
			allowed_values.duplicate(true),
			target
		)
		return
	for allowed_value: Variant in allowed_values:
		if _values_match(target, allowed_value):
			return
	_add_constraint_issue(
		report,
		&"value_not_allowed",
		"Value is not in the allowed set.",
		context,
		target,
		allowed_values.duplicate(true),
		target
	)


func _validate_regex(target: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if not _is_text_like(target):
		_add_constraint_issue(
			report,
			&"regex_invalid_type",
			"Value must be text for regex constraint.",
			context,
			target,
			"String or StringName",
			_typeof_name(target)
		)
		return
	var text: String = GFVariantData.to_text(target)
	if allow_empty and text.is_empty():
		return
	var regex: RegEx = _get_regex()
	if regex == null:
		_add_constraint_issue(
			report,
			&"regex_invalid_configuration",
			"Regex pattern cannot be compiled.",
			context,
			target,
			pattern,
			_compiled_regex_error
		)
		return
	var match_result: RegExMatch = regex.search(text)
	if match_result == null:
		_add_constraint_issue(
			report,
			&"regex_mismatch",
			"Text does not match the required pattern.",
			context,
			target,
			pattern,
			text
		)
		return
	if require_full_match and (match_result.get_start() != 0 or match_result.get_end() != text.length()):
		_add_constraint_issue(
			report,
			&"regex_mismatch",
			"Text does not fully match the required pattern.",
			context,
			target,
			pattern,
			text
		)


func _validate_size(target: Variant, report: GFValidationReport, context: Dictionary) -> void:
	if _has_invalid_size_configuration():
		_add_constraint_issue(
			report,
			&"size_invalid_configuration",
			"Size constraint configuration is invalid.",
			context,
			target,
			_describe_size_range(),
			null
		)
		return
	var size: int = _get_value_size(target)
	if size < 0:
		_add_constraint_issue(
			report,
			&"size_invalid_type",
			"Value must have a size for size constraint.",
			context,
			target,
			"String, Array, Dictionary, or PackedArray",
			_typeof_name(target)
		)
		return
	if not _is_size_in_range(size):
		_add_constraint_issue(
			report,
			&"size_out_of_bounds",
			"Value size is outside the allowed range.",
			context,
			target,
			_describe_size_range(),
			size
		)


func _add_constraint_issue(
	report: GFValidationReport,
	fallback_kind: StringName,
	message: String,
	context: Dictionary,
	actual_value: Variant,
	expected_value: Variant,
	actual_state: Variant
) -> void:
	var issue_metadata: Dictionary = metadata.duplicate(true)
	issue_metadata["rule_id"] = String(rule_id)
	issue_metadata["constraint_kind"] = constraint_kind_to_name(constraint_kind)
	issue_metadata["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	issue_metadata["actual_value"] = GFVariantData.duplicate_variant(actual_value)
	issue_metadata["actual_state"] = GFVariantData.duplicate_variant(actual_state)
	var issue_key: Variant = GFVariantData.get_option_value(context, "key")
	var issue_path: String = GFVariantData.get_option_string(context, "path")
	var issue: GFValidationIssue = GFValidationIssue.new(
		severity,
		_get_constraint_issue_kind(fallback_kind),
		message,
		issue_key,
		issue_path,
		issue_metadata
	)
	issue.subject = GFVariantData.get_option_string(context, "subject", String(rule_id))
	issue.source_path = GFVariantData.get_option_string(context, "source_path", issue.source_path)
	if issue.source_path.is_empty():
		issue.source_path = GFVariantData.get_option_string(context, "source", issue.source_path)
	issue.line = GFVariantData.get_option_int(context, "line", issue.line)
	issue.column = GFVariantData.get_option_int(context, "column", issue.column)
	var _added_issue: RefCounted = report.add_issue(issue)


func _get_constraint_issue_kind(fallback_kind: StringName) -> StringName:
	return rule_id if rule_id != &"" else fallback_kind


func _is_numeric(value: Variant) -> bool:
	return value is int or value is float


func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _is_text_like(value: Variant) -> bool:
	return value is String or value is StringName


func _values_match(left: Variant, right: Variant) -> bool:
	if case_sensitive:
		return left == right
	if _is_text_like(left) and _is_text_like(right):
		return GFVariantData.to_text(left).to_lower() == GFVariantData.to_text(right).to_lower()
	return left == right


func _is_in_range(value: float) -> bool:
	if has_minimum:
		if inclusive_minimum:
			if value < minimum:
				return false
		elif value <= minimum:
			return false
	if has_maximum:
		if inclusive_maximum:
			if value > maximum:
				return false
		elif value >= maximum:
			return false
	return true


func _has_invalid_range_configuration() -> bool:
	if has_minimum and not _is_finite_number(minimum):
		return true
	if has_maximum and not _is_finite_number(maximum):
		return true
	if has_minimum and has_maximum:
		if minimum > maximum:
			return true
		if minimum == maximum and (not inclusive_minimum or not inclusive_maximum):
			return true
	return false


func _describe_range() -> Dictionary:
	return {
		"has_minimum": has_minimum,
		"minimum": minimum,
		"inclusive_minimum": inclusive_minimum,
		"has_maximum": has_maximum,
		"maximum": maximum,
		"inclusive_maximum": inclusive_maximum,
	}


func _get_regex() -> RegEx:
	if pattern.is_empty():
		_compiled_pattern = pattern
		_compiled_regex = null
		_compiled_regex_error = ERR_INVALID_PARAMETER
		return null
	if _compiled_regex != null and _compiled_pattern == pattern:
		return _compiled_regex
	_compiled_pattern = pattern
	_compiled_regex = RegEx.new()
	_compiled_regex_error = _compiled_regex.compile(pattern)
	if _compiled_regex_error != OK:
		_compiled_regex = null
	return _compiled_regex


func _clear_regex_cache() -> void:
	_compiled_pattern = ""
	_compiled_regex = null
	_compiled_regex_error = OK


func _get_value_size(value: Variant) -> int:
	if value is String or value is StringName:
		return GFVariantData.to_text(value).length()
	if value is Array:
		var array: Array = value
		return array.size()
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.size()
	if value is PackedByteArray:
		var packed_bytes: PackedByteArray = value
		return packed_bytes.size()
	if value is PackedInt32Array:
		var packed_int32: PackedInt32Array = value
		return packed_int32.size()
	if value is PackedInt64Array:
		var packed_int64: PackedInt64Array = value
		return packed_int64.size()
	if value is PackedFloat32Array:
		var packed_float32: PackedFloat32Array = value
		return packed_float32.size()
	if value is PackedFloat64Array:
		var packed_float64: PackedFloat64Array = value
		return packed_float64.size()
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return packed_strings.size()
	if value is PackedVector2Array:
		var packed_vector2: PackedVector2Array = value
		return packed_vector2.size()
	if value is PackedVector3Array:
		var packed_vector3: PackedVector3Array = value
		return packed_vector3.size()
	if value is PackedColorArray:
		var packed_colors: PackedColorArray = value
		return packed_colors.size()
	if value is PackedVector4Array:
		var packed_vector4: PackedVector4Array = value
		return packed_vector4.size()
	return -1


func _is_size_in_range(size: int) -> bool:
	if has_minimum_size and size < minimum_size:
		return false
	if has_maximum_size and size > maximum_size:
		return false
	return true


func _has_invalid_size_configuration() -> bool:
	return has_minimum_size and has_maximum_size and minimum_size > maximum_size


func _describe_size_range() -> Dictionary:
	return {
		"has_minimum_size": has_minimum_size,
		"minimum_size": minimum_size,
		"has_maximum_size": has_maximum_size,
		"maximum_size": maximum_size,
	}


func _typeof_name(value: Variant) -> String:
	return type_string(typeof(value))
