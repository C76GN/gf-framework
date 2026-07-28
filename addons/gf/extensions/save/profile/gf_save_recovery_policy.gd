## GFSaveRecoveryPolicy: Save Profile 的显式恢复与有界重试政策。
##
## 缺失和损坏数据默认失败；项目必须显式选择保留当前内存状态。
## 重试只接受列出的临时错误，并受有限延迟序列约束。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 10.0.0
class_name GFSaveRecoveryPolicy
extends Resource


# --- 常量 ---

## 不执行自动恢复。
## [br]
## @api public
## [br]
## @since 10.0.0
const ACTION_FAIL: StringName = &"fail"

## 保留当前内存状态，不写入或替换原文件。
## [br]
## @api public
## [br]
## @since 10.0.0
const ACTION_USE_CURRENT_STATE: StringName = &"use_current_state"


# --- 导出变量 ---

## 文件缺失时的恢复动作。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var missing_file_action: StringName = ACTION_FAIL

## 文件损坏或完整性校验失败时的恢复动作。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var corrupt_file_action: StringName = ACTION_FAIL

## 每次临时失败后的有限重试延迟，单位毫秒。
##
## 第一个元素用于首次失败后的重试；数组耗尽后操作进入失败终态。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var retry_delays_msec: PackedInt32Array = PackedInt32Array()

## 允许重试的 Godot Error 码。
## [br]
## @api public
## [br]
## @since 10.0.0
@export var transient_error_codes: PackedInt32Array = PackedInt32Array([
	ERR_BUSY,
	ERR_CANT_OPEN,
	ERR_FILE_CANT_OPEN,
	ERR_FILE_CANT_WRITE,
	ERR_TIMEOUT,
	ERR_UNAVAILABLE,
])

## 单次底层 IO 的最大等待时间，单位毫秒。
##
## 超时后读取可安全失败；写入因无法取消而进入 outcome-unknown，策略仍可选择
## 使用同一不可变文档重试。
## [br]
## @api public
## [br]
## @since 10.0.0
@export_range(1, 2_147_483_647, 1) var io_timeout_msec: int = 30_000


# --- 公共方法 ---

## 检查策略自身是否合法。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 结构化校验报告。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with issues, counts, summary, and next_actions.
func validate_policy() -> Dictionary:
	var report: Dictionary = {"issues": []}
	_append_action_issue(report, "missing_file_action", missing_file_action)
	_append_action_issue(report, "corrupt_file_action", corrupt_file_action)
	if io_timeout_msec <= 0:
		var _timeout_issue: Variant = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_io_timeout",
			"IO timeout must be positive milliseconds.",
			{"path": "io_timeout_msec", "value": io_timeout_msec}
		)
	for index: int in range(retry_delays_msec.size()):
		if retry_delays_msec[index] <= 0:
			var _delay_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_retry_delay",
				"Retry delays must be positive milliseconds.",
				{"path": "retry_delays_msec.%d" % index, "value": retry_delays_msec[index]}
			)
	var seen_errors: Dictionary = {}
	for index: int in range(transient_error_codes.size()):
		var error_code: int = transient_error_codes[index]
		if error_code <= OK or seen_errors.has(error_code):
			var _error_issue: Variant = GFValidationReportDictionary.append_issue(
				report,
				"error",
				&"invalid_transient_error",
				"Transient error codes must be unique non-OK Error values.",
				{"path": "transient_error_codes.%d" % index, "value": error_code}
			)
		seen_errors[error_code] = true
	return GFValidationReportDictionary.finalize_report(report, "Save recovery policy", {
		"include_issue_count": true,
		"next_actions": {
			"invalid_recovery_action": "Use fail or use_current_state.",
			"invalid_retry_delay": "Use a finite sequence of positive millisecond delays.",
			"invalid_transient_error": "Remove OK, invalid values, and duplicate error codes.",
			"invalid_io_timeout": "Use a finite positive IO timeout.",
		},
		"fallback_action": "Review the first recovery policy issue.",
		"no_action": "Save recovery policy is valid.",
	})


## 检查指定错误在当前失败次数后是否可以重试。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param error_code: 本次失败的 Godot Error 码。
## [br]
## @param failed_attempt_count: 已失败尝试次数，从 1 开始。
## [br]
## @return 错误为临时错误且仍有延迟槽位时返回 true。
func can_retry(error_code: Error, failed_attempt_count: int) -> bool:
	return (
		failed_attempt_count > 0
		and failed_attempt_count <= retry_delays_msec.size()
		and transient_error_codes.has(int(error_code))
	)


## 获取指定失败次数后的重试延迟。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param failed_attempt_count: 已失败尝试次数，从 1 开始。
## [br]
## @return 对应延迟；没有重试槽位时返回 -1。
func get_retry_delay_msec(failed_attempt_count: int) -> int:
	var index: int = failed_attempt_count - 1
	if index < 0 or index >= retry_delays_msec.size():
		return -1
	return retry_delays_msec[index]


# --- 私有/辅助方法 ---

func _append_action_issue(report: Dictionary, path: String, action: StringName) -> void:
	if action in [ACTION_FAIL, ACTION_USE_CURRENT_STATE]:
		return
	var _action_issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		&"invalid_recovery_action",
		"Recovery action is not supported.",
		{"path": path, "value": action}
	)
