## GFConfigValidationRule: 导表校验规则基类。
##
## 用于把字段、记录或整表校验拆成可组合 Resource，便于项目按需声明范围、
## 正则、资源路径或本地化 key 等规则，而不把业务表结构写进框架。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFConfigValidationRule
extends Resource


# --- 枚举 ---

## 校验问题严重级别。
## [br]
## @api public
enum IssueSeverity {
	## 警告，不阻止报告通过。
	WARNING,
	## 错误，会让报告失败。
	ERROR,
}


# --- 常量 ---

const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")


# --- 导出变量 ---

## 规则稳定标识。为空时使用规则类型默认标识。
## [br]
## @api public
@export var rule_id: StringName = &""

## 是否启用当前规则。
## [br]
## @api public
@export var enabled: bool = true

## 规则触发时写入报告的严重级别。
## [br]
## @api public
@export var severity: IssueSeverity = IssueSeverity.ERROR

## 值为 null 时是否直接跳过值校验。
## [br]
## @api public
@export var allow_null: bool = true

## 可选元数据，供编辑器或项目工具扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存编辑器或项目层附加到当前规则的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定规则标识。
## [br]
## @api public
## [br]
## @return 规则标识。
func get_rule_id() -> StringName:
	if rule_id != &"":
		return rule_id
	return _get_default_rule_id()


## 校验单个字段值。
## [br]
## @api public
## [br]
## @param value: 待校验值。
## [br]
## @param context: 可选上下文，支持 table_name、row_key、field、source、line、column、value、expected_value、actual_value 和 supported_values 等字段。
## [br]
## @return 校验报告字典。
## [br]
## @schema value: Variant，来自配置表或项目导入器的字段值。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line、column、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_value(value: Variant, context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(context)
	if not enabled:
		return report
	if value == null and allow_null:
		return report
	if value == null:
		var issue_context: Dictionary = context.duplicate(true)
		issue_context["value"] = null
		issue_context["actual_value"] = null
		issue_context["expected_value"] = "non_null"
		_add_issue(report, issue_context, "null_value", "值不允许为空。")
		_finalize_report(report)
		return report

	_validate_value(value, context, report)
	_finalize_report(report)
	return report


## 校验单条记录。
## [br]
## @api public
## [br]
## @param record: 待校验记录。
## [br]
## @param context: 可选上下文，支持 table_name、row_key、source、line。
## [br]
## @return 校验报告字典。
## [br]
## @schema record: Dictionary，正在校验的配置记录。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、source 和 line 字段。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_record(record: Dictionary, context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(context)
	if not enabled:
		return report
	_validate_record(record, context, report)
	_finalize_report(report)
	return report


## 校验整张表。
## [br]
## @api public
## [br]
## @param rows: 规范化行列表，每项通常包含 row_key、record 和 row_index。
## [br]
## @param context: 可选上下文，支持 table_name、source。
## [br]
## @return 校验报告字典。
## [br]
## @schema rows: Array[Dictionary]，元素通常包含 row_key、record 和 row_index。
## [br]
## @schema context: Dictionary，可包含 table_name 和 source 字段。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_table(rows: Array[Dictionary], context: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report(context)
	if not enabled:
		return report
	_validate_table(rows, context, report)
	_finalize_report(report)
	return report


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新规则。
func duplicate_rule() -> GFConfigValidationRule:
	return _variant_to_validation_rule(duplicate(true))


## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含 rule_id、enabled、severity、allow_null、metadata 和 script_path。
func describe() -> Dictionary:
	return {
		"rule_id": get_rule_id(),
		"enabled": enabled,
		"severity": _severity_to_string(),
		"allow_null": allow_null,
		"metadata": metadata.duplicate(true),
		"script_path": get_script().resource_path if get_script() != null else "",
	}


# --- 可重写钩子 / 虚方法 ---

## 返回当前规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"validation_rule"


## 校验单个字段值。
## [br]
## @api protected
## [br]
## @param _value: 待校验值。
## [br]
## @param _context: 校验上下文。
## [br]
## @param _report: 当前校验报告。
## [br]
## @schema _value: Variant，来自配置表或项目导入器的字段值。
## [br]
## @schema _context: Dictionary，可包含 table_name、row_key、field、source、line、column、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。
## [br]
## @schema _report: GFConfigValidationReport 兼容 Dictionary，会被规则修改。
func _validate_value(_value: Variant, _context: Dictionary, _report: Dictionary) -> void:
	pass


## 校验单条记录。
## [br]
## @api protected
## [br]
## @param _record: 待校验记录。
## [br]
## @param _context: 校验上下文。
## [br]
## @param _report: 当前校验报告。
## [br]
## @schema _record: Dictionary，正在校验的配置记录。
## [br]
## @schema _context: Dictionary，可包含 table_name、row_key、source 和 line 字段。
## [br]
## @schema _report: GFConfigValidationReport 兼容 Dictionary，会被规则修改。
func _validate_record(_record: Dictionary, _context: Dictionary, _report: Dictionary) -> void:
	pass


## 校验整张表。
## [br]
## @api protected
## [br]
## @param _rows: 规范化行列表。
## [br]
## @param _context: 校验上下文。
## [br]
## @param _report: 当前校验报告。
## [br]
## @schema _rows: Array[Dictionary]，元素通常包含 row_key、record 和 row_index。
## [br]
## @schema _context: Dictionary，可包含 table_name 和 source 字段。
## [br]
## @schema _report: GFConfigValidationReport 兼容 Dictionary，会被规则修改。
func _validate_table(_rows: Array[Dictionary], _context: Dictionary, _report: Dictionary) -> void:
	pass


## 向当前报告追加一个带规则上下文的问题。
## [br]
## @api protected
## [br]
## @param report: 当前校验报告。
## [br]
## @param context: 校验上下文。
## [br]
## @param kind: 稳定问题类型。
## [br]
## @param message: 面向工具或开发者的说明文本。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前辅助方法修改。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
func _add_issue(report: Dictionary, context: Dictionary, kind: String, message: String) -> void:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["rule_id"] = get_rule_id()
	_CONFIG_VALIDATION_REPORT.new().add_issue(
		report,
		_severity_to_string(),
		kind,
		GFVariantData.get_option_string_name(context, "table_name", &""),
		GFVariantData.get_option_value(context, "row_key", null),
		GFVariantData.get_option_string_name(context, "field", &""),
		message,
		issue_context
	)


## 生成可比较的 Variant 稳定字符串键。
## [br]
## @api protected
## [br]
## @param value: 要转换为比较键的值。
## [br]
## @return 包含 Variant 类型和值文本的比较键。
## [br]
## @schema value: Variant，用于集合或默认值校验规则比较的值。
func _make_variant_key(value: Variant) -> String:
	return "%d:%s" % [typeof(value), var_to_str(value)]


# --- 私有/辅助方法 ---

func _make_report(context: Dictionary) -> Dictionary:
	return _CONFIG_VALIDATION_REPORT.new().make_report(
		GFVariantData.get_option_string_name(context, "table_name", &"")
	)


func _finalize_report(report: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().finalize_report(report)


func _severity_to_string() -> String:
	return "warning" if severity == IssueSeverity.WARNING else "error"


func _variant_to_validation_rule(value: Variant) -> GFConfigValidationRule:
	if value is GFConfigValidationRule:
		var rule: GFConfigValidationRule = value
		return rule
	return null
