## GFExecutionBudget: 通用执行预算与取消检查器。
##
## 用于给生成器、导入器、批处理或受控规则循环提供统一的步数、深度、
## 输出长度、耗时和取消 token 检查。它不调度任务，也不执行调用方逻辑。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFExecutionBudget
extends RefCounted


# --- 公共变量 ---

## 最大步数；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_steps: int = 0

## 最大嵌套深度；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_depth: int = 0

## 最大输出文本长度；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_output_length: int = 0

## 最大运行毫秒数；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_elapsed_msec: int = 0

## 关联的取消 token；为空时不检查取消状态。
## [br]
## @api public
## [br]
## @since 7.0.0
var cancel_token: GFCancellationToken = null

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary，包含调用方定义的预算上下文。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _started_msec: int = 0
var _clock: GFClock = null
var _steps: int = 0
var _depth: int = 0
var _violated: bool = false
var _violation_reason: StringName = &""
var _violation_message: String = ""
var _violation_span: Variant = null


# --- Godot 生命周期方法 ---

## 创建执行预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 可选配置，支持 max_steps、max_depth、max_output_length、max_elapsed_msec、cancel_token 和 metadata。
## [br]
## @schema options: Dictionary，包含执行预算配置。
## [br]
## @param clock: 可选单调时钟；为空时使用系统时钟。
func _init(options: Dictionary = {}, clock: GFClock = null) -> void:
	_clock = clock if clock != null else GFClock.new()
	var _configured_budget: GFExecutionBudget = configure(options)


# --- 公共方法 ---

## 配置执行预算并重置运行状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 可选配置，支持 max_steps、max_depth、max_output_length、max_elapsed_msec、cancel_token 和 metadata。
## [br]
## @return 当前预算。
## [br]
## @schema options: Dictionary，包含执行预算配置。
func configure(options: Dictionary = {}) -> GFExecutionBudget:
	max_steps = maxi(GFVariantData.get_option_int(options, "max_steps", max_steps), 0)
	max_depth = maxi(GFVariantData.get_option_int(options, "max_depth", max_depth), 0)
	max_output_length = maxi(GFVariantData.get_option_int(options, "max_output_length", max_output_length), 0)
	max_elapsed_msec = maxi(GFVariantData.get_option_int(options, "max_elapsed_msec", max_elapsed_msec), 0)
	metadata = GFVariantData.get_option_dictionary(options, "metadata", metadata)

	var token_value: Variant = GFVariantData.get_option_value(options, "cancel_token", cancel_token)
	cancel_token = _variant_to_cancel_token(token_value)
	reset()
	return self


## 替换预算耗时检查使用的单调时钟并重置计数状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param clock: 新单调时钟。
## [br]
## @return 时钟合法并完成替换时返回 true。
func set_clock(clock: GFClock) -> bool:
	if clock == null:
		return false
	_clock = clock
	reset()
	return true


## 获取预算耗时检查使用的时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前时钟。
func get_clock() -> GFClock:
	return _clock


## 重置计数器和违规状态。
## [br]
## @api public
## [br]
## @since 7.0.0
func reset() -> void:
	_started_msec = _clock.get_monotonic_msec()
	_steps = 0
	_depth = 0
	_violated = false
	_violation_reason = &""
	_violation_message = ""
	_violation_span = null


## 绑定取消 token。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param token: 取消 token。
## [br]
## @return 当前预算。
func bind_cancel_token(token: GFCancellationToken) -> GFExecutionBudget:
	cancel_token = token
	return self


## 消耗执行步数并检查预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param amount: 消耗步数。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 仍在预算内时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func consume_steps(amount: int = 1, source_span: Variant = null) -> bool:
	if not check(source_span):
		return false
	_steps += maxi(amount, 0)
	if max_steps > 0 and _steps > max_steps:
		_mark_violation(&"step_limit_exceeded", "Execution step limit exceeded.", source_span)
		return false
	return check(source_span)


## 进入一层嵌套并检查深度预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 仍在预算内时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func enter_depth(source_span: Variant = null) -> bool:
	if not check(source_span):
		return false
	_depth += 1
	if max_depth > 0 and _depth > max_depth:
		_mark_violation(&"depth_limit_exceeded", "Execution depth limit exceeded.", source_span)
		return false
	return true


## 退出一层嵌套。
## [br]
## @api public
## [br]
## @since 7.0.0
func exit_depth() -> void:
	_depth = maxi(_depth - 1, 0)


## 检查输出长度预算。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param output_length: 当前或即将写入后的输出长度。
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 仍在预算内时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func check_output_length(output_length: int, source_span: Variant = null) -> bool:
	if not check(source_span):
		return false
	if max_output_length > 0 and output_length > max_output_length:
		_mark_violation(&"output_limit_exceeded", "Output length limit exceeded.", source_span)
		return false
	return true


## 检查取消、耗时和既有违规状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_span: 可选源码定位。
## [br]
## @return 仍可继续执行时返回 true。
## [br]
## @schema source_span: Variant，可传 GFSourceSpan 或兼容字典。
func check(source_span: Variant = null) -> bool:
	if _violated:
		return false
	if cancel_token != null and cancel_token.is_cancel_requested():
		_mark_violation(&"cancelled", "Execution was cancelled.", source_span)
		return false
	if max_elapsed_msec > 0 and get_elapsed_msec() > max_elapsed_msec:
		_mark_violation(&"time_limit_exceeded", "Execution time limit exceeded.", source_span)
		return false
	return true


## 检查预算是否已经违规。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已违规时返回 true。
func is_exceeded() -> bool:
	return _violated


## 获取已消耗步数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已消耗步数。
func get_steps() -> int:
	return _steps


## 获取当前嵌套深度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前嵌套深度。
func get_depth() -> int:
	return _depth


## 获取已运行毫秒数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 从最近一次 reset 起经过的毫秒数。
func get_elapsed_msec() -> int:
	return maxi(_clock.get_monotonic_msec() - _started_msec, 0)


## 获取违规原因。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 稳定违规原因。
func get_violation_reason() -> StringName:
	return _violation_reason


## 获取违规说明。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 违规说明。
func get_violation_message() -> String:
	return _violation_message


## 创建预算违规报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param subject: 报告主题。
## [br]
## @return 校验报告。
func make_report(subject: String = "Execution budget") -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(subject, {
		"budget": get_debug_snapshot(),
	})
	if not _violated:
		return report
	if _is_source_span_like(_violation_span):
		var _source_issue: RefCounted = report.add_source_error(
			_violation_reason,
			_violation_message,
			_violation_span,
			null,
			"",
			metadata
		)
	else:
		var _issue: RefCounted = report.add_error(_violation_reason, _violation_message, null, "", metadata)
	return report


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 预算状态字典。
## [br]
## @schema return: Dictionary，包含预算限制、计数器、取消状态和违规信息。
func get_debug_snapshot() -> Dictionary:
	return {
		"max_steps": max_steps,
		"max_depth": max_depth,
		"max_output_length": max_output_length,
		"max_elapsed_msec": max_elapsed_msec,
		"steps": _steps,
		"depth": _depth,
		"elapsed_msec": get_elapsed_msec(),
		"has_cancel_token": cancel_token != null,
		"cancelled": cancel_token != null and cancel_token.is_cancel_requested(),
		"exceeded": _violated,
		"violation_reason": _violation_reason,
		"violation_message": _violation_message,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _mark_violation(reason: StringName, message: String, source_span: Variant) -> void:
	if _violated:
		return
	_violated = true
	_violation_reason = reason
	_violation_message = message
	_violation_span = GFVariantData.duplicate_variant(source_span)


static func _variant_to_cancel_token(value: Variant) -> GFCancellationToken:
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
		return token
	return null


static func _is_source_span_like(value: Variant) -> bool:
	return value is GFSourceSpan or value is Dictionary
