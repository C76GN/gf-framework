## GFSettingsRecoveryPolicy: 设置加载的显式恢复策略。
##
## 缺失与损坏设置默认严格失败。项目可以显式选择保留当前内存状态，
## 或把有效设置重置为已注册默认值；恢复不会创建或覆盖持久化文件。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFSettingsRecoveryPolicy
extends Resource


# --- 常量 ---

## 不执行自动恢复。
## [br]
## @api public
## [br]
## @since unreleased
const ACTION_FAIL: StringName = &"fail"

## 保留当前有效值和暂存值。
## [br]
## @api public
## [br]
## @since unreleased
const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"

## 使用空 replace 语义恢复已注册默认值。
## [br]
## @api public
## [br]
## @since unreleased
const ACTION_RESET_TO_DEFAULTS: StringName = &"reset_to_defaults"


# --- 导出变量 ---

## 文件缺失时的恢复动作。
## [br]
## @api public
## [br]
## @since unreleased
@export var missing_file_action: StringName = ACTION_FAIL

## 文件损坏或完整性校验失败时的恢复动作。
## [br]
## @api public
## [br]
## @since unreleased
@export var corrupt_file_action: StringName = ACTION_FAIL


# --- 公共方法 ---

## 检查策略自身是否合法。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_policy() -> Dictionary:
	var report: Dictionary = {"issues": []}
	_append_action_issue(report, "missing_file_action", missing_file_action)
	_append_action_issue(report, "corrupt_file_action", corrupt_file_action)
	return GFValidationReportDictionary.finalize_report(report, "Settings recovery policy", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_recovery_action": (
				"Use fail, use_current_state, or reset_to_defaults."
			),
		},
		"fallback_action": "Review the first recovery policy issue.",
		"no_action": "Settings recovery policy is valid.",
	})


# --- 私有/辅助方法 ---

func _append_action_issue(report: Dictionary, path: String, action: StringName) -> void:
	if action in [ACTION_FAIL, ACTION_USE_CURRENT_STATE, ACTION_RESET_TO_DEFAULTS]:
		return
	var _action_issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		&"invalid_recovery_action",
		"Recovery action is not supported.",
		{"path": path, "value": action}
	)
