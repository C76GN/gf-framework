## GFValidationRule: 通用校验规则资源。
##
## 通过 Callable 或子类钩子校验任意对象、资源、节点或数据。规则只负责把问题写入
## GFValidationReport，不约定项目脚本方法名，也不内置业务字段语义。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFValidationRule
extends Resource


# --- 枚举 ---

## 规则适用的目标类型。
## [br]
## @api public
enum TargetKind {
	## 接受任意目标。
	ANY,
	## 接受 Node。
	NODE,
	## 接受 Resource。
	RESOURCE,
	## 接受 PackedScene。
	PACKED_SCENE,
	## 接受 Dictionary。
	DICTIONARY,
	## 接受 Array。
	ARRAY,
	## 接受 Object。
	OBJECT,
}


# --- 导出变量 ---

## 规则唯一标识。推荐使用稳定的 snake_case 或点分层级标识。
## [br]
## @api public
@export var rule_id: StringName = &""

## 面向工具或报告的规则说明。
## [br]
## @api public
@export_multiline var description: String = ""

## 规则适用的目标类型。
## [br]
## @api public
@export var target_kind: TargetKind = TargetKind.ANY

## 是否启用该规则。
## [br]
## @api public
@export var enabled: bool = true

## 当 Callable 或钩子返回 false / 非空字符串时使用的默认严重级别。
## [br]
## @api public
@export var severity: GFValidationIssue.Severity = GFValidationIssue.Severity.ERROR

## 可选元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary of caller-defined rule metadata.
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 可选校验回调，签名为 func(target: Variant, report: GFValidationReport, context: Dictionary) -> Variant。
## [br]
## @api public
var callback: Callable = Callable()


# --- 公共方法 ---

## 配置规则并返回自身。
## [br]
## @api public
## [br]
## @param p_rule_id: 规则标识。
## [br]
## @param p_callback: 可选校验回调。
## [br]
## @param options: 可选字段，支持 description、target_kind、enabled、severity、metadata。
## [br]
## @schema options: Dictionary rule configuration overrides.
## [br]
## @return 当前规则。
func configure(
	p_rule_id: StringName,
	p_callback: Callable = Callable(),
	options: Dictionary = {}
) -> GFValidationRule:
	rule_id = p_rule_id
	callback = p_callback
	description = GFVariantData.get_option_string(options, "description", description)
	target_kind = _target_kind_from_int(GFVariantData.to_int(GFVariantData.get_option_value(options, "target_kind", target_kind), target_kind))
	enabled = GFVariantData.get_option_bool(options, "enabled", enabled)
	severity = GFValidationIssue.normalize_severity(GFVariantData.get_option_value(options, "severity", severity))
	var metadata_value: Variant = GFVariantData.get_option_value(options, "metadata", metadata)
	metadata = GFVariantData.as_dictionary(metadata_value).duplicate(true)
	return self


## 检查规则是否适用于目标。
## [br]
## @api public
## [br]
## @param target: 待校验目标。
## [br]
## @schema target: Variant validation target.
## [br]
## @param context: 调用方上下文。
## [br]
## @schema context: Dictionary validation context.
## [br]
## @return 适用时返回 true。
func applies_to(target: Variant, context: Dictionary = {}) -> bool:
	if not enabled:
		return false
	if GFVariantData.get_option_bool(context, "skip_rule_kind_check", false):
		return true
	return _target_kind_matches(target, target_kind)


## 执行规则并返回报告。
## [br]
## @api public
## [br]
## @param target: 待校验目标。
## [br]
## @schema target: Variant validation target.
## [br]
## @param context: 调用方上下文。
## [br]
## @schema context: Dictionary validation context.
## [br]
## @return 校验报告。
func validate(target: Variant, context: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(_make_subject(context), {
		"rule_id": String(rule_id),
	})
	if not applies_to(target, context):
		return report

	if not metadata.is_empty():
		report.metadata["rule_metadata"] = metadata.duplicate(true)

	var hook_result: Variant = _validate(target, report, context)
	_apply_result(report, hook_result, context)
	if callback.is_valid():
		var callback_result: Variant = callback.call(target, report, context.duplicate(true))
		_apply_result(report, callback_result, context)
	return report


## 创建当前规则的浅配置副本。
## [br]
## @api public
## [br]
## @return 新规则。
func duplicate_rule() -> GFValidationRule:
	var rule: GFValidationRule = GFValidationRule.new()
	rule.rule_id = rule_id
	rule.description = description
	rule.target_kind = target_kind
	rule.enabled = enabled
	rule.severity = severity
	rule.metadata = metadata.duplicate(true)
	rule.callback = callback
	return rule


## 导出规则摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 规则描述字典。
## [br]
## @schema return: Dictionary validation rule descriptor.
func describe() -> Dictionary:
	return {
		"valid": true,
		"rule_id": rule_id,
		"description": description,
		"target_kind": target_kind,
		"enabled": enabled,
		"severity": severity,
		"severity_name": GFValidationIssue.severity_to_string(severity),
		"metadata": metadata.duplicate(true),
	}


# --- 可重写钩子 / 虚方法 ---

## 执行子类自定义校验逻辑。
## [br]
## @api protected
## [br]
## @param _target: 待校验目标。
## [br]
## @schema _target: Variant validation target.
## [br]
## @param _report: 当前规则报告，可直接写入问题。
## [br]
## @param _context: 调用方上下文。
## [br]
## @schema _context: Dictionary validation context.
## [br]
## @return 自定义校验结果；支持 null、GFValidationReport、Dictionary、Array、bool、String 或 StringName。
## [br]
## @schema return: Variant validation hook result accepted by _apply_result.
func _validate(_target: Variant, _report: GFValidationReport, _context: Dictionary) -> Variant:
	return null


# --- 私有/辅助方法 ---

func _apply_result(report: GFValidationReport, value: Variant, context: Dictionary) -> void:
	if value == null:
		return
	if value is GFValidationReport:
		var _merged_report: RefCounted = report.merge(value)
		return
	if value is Dictionary:
		var _merged_dictionary_report: RefCounted = report.merge(value)
		return
	if value is Array:
		var issues: Array = value
		for issue: Variant in issues:
			_add_issue_if_valid(report, issue)
		return
	if value is bool:
		if not GFVariantData.to_bool(value):
			_add_issue_if_valid(report, _make_issue("Validation rule failed.", context))
		return
	if value is String or value is StringName:
		var message: String = GFVariantData.to_text(value)
		if not message.is_empty():
			_add_issue_if_valid(report, _make_issue(message, context))


func _make_issue(message: String, context: Dictionary) -> GFValidationIssue:
	var issue: GFValidationIssue = GFValidationIssue.new(severity, _get_issue_kind(), message)
	issue.subject = _make_subject(context)
	issue.key = GFVariantData.get_option_value(context, "key", issue.key)
	issue.path = GFVariantData.get_option_string(context, "path", issue.path)
	issue.source_path = GFVariantData.get_option_string(context, "source_path", issue.source_path)
	if issue.source_path.is_empty():
		issue.source_path = GFVariantData.get_option_string(context, "source", issue.source_path)
	issue.line = GFVariantData.get_option_int(context, "line", issue.line)
	issue.column = GFVariantData.get_option_int(context, "column", issue.column)
	if not metadata.is_empty():
		issue.metadata = metadata.duplicate(true)
	return issue


func _get_issue_kind() -> StringName:
	return rule_id if rule_id != &"" else &"validation_rule_failed"


func _make_subject(context: Dictionary) -> String:
	var subject: String = GFVariantData.get_option_string(context, "subject")
	if not subject.is_empty():
		return subject
	if rule_id != &"":
		return String(rule_id)
	return "GFValidationRule"


func _target_kind_matches(target: Variant, kind: TargetKind) -> bool:
	match kind:
		TargetKind.NODE:
			return target is Node
		TargetKind.RESOURCE:
			return target is Resource
		TargetKind.PACKED_SCENE:
			return target is PackedScene
		TargetKind.DICTIONARY:
			return target is Dictionary
		TargetKind.ARRAY:
			return target is Array
		TargetKind.OBJECT:
			return target is Object
		_:
			return true


func _add_issue_if_valid(report: GFValidationReport, issue: Variant) -> void:
	var _added_issue: RefCounted = report.add_issue(issue)


static func _target_kind_from_int(value: int) -> TargetKind:
	match clampi(value, TargetKind.ANY, TargetKind.OBJECT):
		TargetKind.NODE:
			return TargetKind.NODE
		TargetKind.RESOURCE:
			return TargetKind.RESOURCE
		TargetKind.PACKED_SCENE:
			return TargetKind.PACKED_SCENE
		TargetKind.DICTIONARY:
			return TargetKind.DICTIONARY
		TargetKind.ARRAY:
			return TargetKind.ARRAY
		TargetKind.OBJECT:
			return TargetKind.OBJECT
		_:
			return TargetKind.ANY
