## GFBuffCheck: Buff 应用检查基类。
##
## 为数据化 Buff 提供通用可组合检查入口。检查只返回是否允许应用和诊断原因，
## 不规定具体玩法、阵营、成本或状态语义。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 6.0.0
class_name GFBuffCheck
extends Resource


# --- 导出变量 ---

## 检查标识，用于诊断或项目侧过滤。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var check_id: StringName = &""

## 项目自定义元数据。GF 不解释其中字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined check metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查 Buff 是否允许应用。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param context: Buff 应用上下文。
## [br]
## @return 检查报告。
## [br]
## @schema context: Dictionary with buff, owner, event, and metadata.
## [br]
## @schema return: Dictionary with ok, reason, check_id, and metadata.
func can_apply(context: Dictionary) -> Dictionary:
	return _normalize_report(_can_apply(context))


# --- 可重写钩子 / 虚方法 ---

## Buff 应用检查钩子。
## [br]
## @api protected
## [br]
## @since 6.0.0
## [br]
## @param _context: Buff 应用上下文。
## [br]
## @return 检查报告。
## [br]
## @schema _context: Dictionary with buff, owner, event, and metadata.
## [br]
## @schema return: Dictionary with optional ok, reason, and metadata.
func _can_apply(_context: Dictionary) -> Dictionary:
	return { "ok": true }


# --- 私有/辅助方法 ---

func _normalize_report(report: Dictionary) -> Dictionary:
	var result: Dictionary = report.duplicate(true)
	result["ok"] = GFVariantData.get_option_bool(result, "ok", true)
	result["reason"] = GFVariantData.get_option_string_name(result, "reason")
	result["check_id"] = check_id
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")
	var _merged_metadata: Dictionary = GFVariantData.merge_dictionary(report_metadata, metadata, false, true)
	result["metadata"] = report_metadata
	return result
