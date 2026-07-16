## GFConfigValidationReport: 配置表校验报告构建工具。
##
## 统一创建、合并和补全配置表校验报告，保证 schema、导入器、引用解析和补丁合并使用相同问题结构。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFConfigValidationReport
extends RefCounted


# --- 常量 ---

## 从校验上下文复制到单条 issue 的字段名。
## [br]
## @api public
const CONTEXT_FIELDS: Array[String] = [
	"row_key",
	"field",
	"source",
	"line",
	"column",
	"row_index",
	"column_index",
	"rule_id",
	"value",
	"expected_value",
	"actual_value",
	"supported_values",
	"supported_values_count",
	"supported_values_sample",
	"supported_values_hash",
	"supported_values_truncated",
	"supported_formats",
	"supported_content_types",
]


# --- 公共方法 ---

## 创建空校验报告。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @param row_count: 记录数量。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary，包含 ok、table_name、row_count、error_count、warning_count 和 issues。
func make_report(table_name: StringName = &"", row_count: int = 0) -> Dictionary:
	return {
		"ok": true,
		"table_name": table_name,
		"row_count": row_count,
		"error_count": 0,
		"warning_count": 0,
		"issues": [],
	}


## 创建单错误校验报告。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @param kind: 稳定问题类型。
## [br]
## @param message: 问题描述。
## [br]
## @param context: 可选上下文。
## [br]
## @return 校验报告字典。
## [br]
## @schema context: Dictionary，可包含 row_key、field、source、line、column、row_index、column_index、rule_id、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary，包含一条 error issue。
func make_error_report(
	table_name: StringName,
	kind: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = make_report(table_name)
	add_issue(
		report,
		"error",
		kind,
		table_name,
		_get_context_row_key(context),
		_get_context_field(context),
		message,
		context
	)
	finalize_report(report)
	return report


## 向报告写入一条问题。
## [br]
## @api public
## [br]
## @param report: 目标校验报告。
## [br]
## @param severity: severity 字符串，支持 error 或 warning。
## [br]
## @param kind: 稳定问题类型。
## [br]
## @param table_name: 表名。
## [br]
## @param row_key: 行标识。
## [br]
## @param field_name: 字段名。
## [br]
## @param message: 问题描述。
## [br]
## @param context: 可选上下文。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
## [br]
## @schema row_key: Variant，复制到 issue 中的行标识。
## [br]
## @schema context: Dictionary，可包含 row_key、field、source、line、column、row_index、column_index、rule_id、value、expected_value、actual_value、supported_values、supported_formats 和 supported_content_types 字段。
func add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	table_name: StringName,
	row_key: Variant,
	field_name: StringName,
	message: String,
	context: Dictionary = {}
) -> void:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"table_name": table_name,
		"row_key": row_key,
		"field": field_name,
		"message": message,
	}
	_apply_issue_context(issue, context)
	var issues: Array = _get_issues(report)
	issues.append(issue)
	report["issues"] = issues

	if severity == "warning":
		report["warning_count"] = _get_warning_count(report) + 1
	else:
		report["error_count"] = _get_error_count(report) + 1
		report["ok"] = false


## 合并一份校验报告。
## [br]
## @api public
## [br]
## @param target: 目标报告。
## [br]
## @param source: 来源报告。
## [br]
## @param include_row_count: 为 true 时累加 row_count。
## [br]
## @schema target: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
## [br]
## @schema source: GFConfigValidationReport 兼容 Dictionary，会复制合并到 target。
func merge_report(target: Dictionary, source: Dictionary, include_row_count: bool = false) -> void:
	if include_row_count:
		target["row_count"] = _get_row_count(target) + _get_row_count(source)
	target["error_count"] = _get_error_count(target) + _get_error_count(source)
	target["warning_count"] = _get_warning_count(target) + _get_warning_count(source)
	if not _is_report_ok(source):
		target["ok"] = false

	var target_issues: Array = _get_issues(target)
	for issue_value: Variant in _get_issues(source):
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			target_issues.append(issue.duplicate(true))
	target["issues"] = target_issues


## 根据 error_count 补全 ok 字段。
## [br]
## @api public
## [br]
## @param report: 校验报告。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前方法修改。
func finalize_report(report: Dictionary) -> void:
	report["ok"] = _get_error_count(report) == 0


# --- 私有/辅助方法 ---

func _apply_issue_context(issue: Dictionary, context: Dictionary) -> void:
	for field_name: String in CONTEXT_FIELDS:
		if context.has(field_name):
			issue[field_name] = _sanitize_context_value(context[field_name])


func _get_context_row_key(context: Dictionary) -> Variant:
	return GFVariantData.get_option_value(context, "row_key")


func _get_context_field(context: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(context, "field")


func _get_issues(report: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(report, "issues", []))


func _get_row_count(report: Dictionary) -> int:
	return GFVariantData.get_option_int(report, "row_count")


func _get_error_count(report: Dictionary) -> int:
	return GFVariantData.get_option_int(report, "error_count")


func _get_warning_count(report: Dictionary) -> int:
	return GFVariantData.get_option_int(report, "warning_count")


func _is_report_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", true)


func _sanitize_context_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_INT:
			return value
		TYPE_FLOAT:
			var float_value: float = value
			if is_nan(float_value) or is_inf(float_value):
				return GFVariantJsonCodec.variant_to_json_compatible(float_value)
			return float_value
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		_:
			return GFReportValueCodec.to_json_compatible(value)
