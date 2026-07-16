## GFActivationTransaction: 非代码动态内容的激活事务。
##
## 将“验证、应用、失败回滚、报告”收敛为通用事务流程。它只调度调用方显式传入的
## Callable，不加载脚本、不执行远端载荷，也不规定内容包、配置或资源注册表的业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFActivationTransaction
extends RefCounted


# --- 常量 ---

## 事务尚未准备。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_PENDING: StringName = &"pending"

## 事务已通过验证。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_PREPARED: StringName = &"prepared"

## 事务已提交。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_COMMITTED: StringName = &"committed"

## 事务失败后已执行回滚。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_ROLLED_BACK: StringName = &"rolled_back"

## 事务失败且未完成回滚。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATE_FAILED: StringName = &"failed"

## 同步事务回调返回了异步状态或 Signal。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_ASYNC_CALLBACK_UNSUPPORTED: StringName = &"async_callback_unsupported"

const _DEFAULT_SUBJECT: String = "Activation transaction"


# --- 公共变量 ---

## 事务 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
var transaction_id: StringName = &""

## 报告主题。
## [br]
## @api public
## [br]
## @since 7.0.0
var subject: String = _DEFAULT_SUBJECT

## 当前事务状态。
## [br]
## @api public
## [br]
## @since 7.0.0
var state: StringName = STATE_PENDING

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary caller-defined transaction metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _steps: Array[Dictionary] = []
var _issues: Array[Dictionary] = []


# --- 公共方法 ---

## 配置事务。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_transaction_id: 事务 ID。
## [br]
## @param p_subject: 报告主题。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined transaction metadata.
## [br]
## @return 当前事务。
func configure(
	p_transaction_id: StringName,
	p_subject: String = _DEFAULT_SUBJECT,
	p_metadata: Dictionary = {}
) -> GFActivationTransaction:
	transaction_id = p_transaction_id
	subject = p_subject if not p_subject.strip_edges().is_empty() else _DEFAULT_SUBJECT
	metadata = p_metadata.duplicate(true)
	return self


## 清空事务。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	state = STATE_PENDING
	_steps.clear()
	_issues.clear()
	metadata.clear()


## 添加事务步骤。
## [br]
## apply_callback 与 rollback_callback 的推荐签名为 `func(context: Dictionary) -> Variant`，且必须同步返回。
## validate_callback 可通过 options 传入，签名相同。返回 false、非 OK Error、或 `{ "ok": false }` 会进入失败报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param step_id: 步骤 ID。
## [br]
## @param apply_callback: 应用回调。
## [br]
## @param rollback_callback: 回滚回调。
## [br]
## @param options: 步骤选项，支持 label、metadata、validate_callback 和 rollback_required。
## [br]
## @schema options: Dictionary step metadata.
## [br]
## @return 添加成功返回 true。
func add_step(
	step_id: StringName,
	apply_callback: Callable,
	rollback_callback: Callable = Callable(),
	options: Dictionary = {}
) -> bool:
	if state != STATE_PENDING or step_id == &"" or not apply_callback.is_valid():
		return false
	_steps.append({
		"step_id": step_id,
		"label": GFVariantData.get_option_string(options, "label", String(step_id)),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
		"validate_callback": _get_callable_option(options, "validate_callback"),
		"apply_callback": apply_callback,
		"rollback_callback": rollback_callback,
		"rollback_required": GFVariantData.get_option_bool(options, "rollback_required", true),
		"state": STATE_PENDING,
		"applied": false,
		"rolled_back": false,
		"last_result": {},
	})
	return true


## 验证事务步骤。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 调用方上下文。
## [br]
## @schema context: Dictionary caller-defined activation context.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.
func prepare(context: Dictionary = {}) -> Dictionary:
	_issues.clear()
	for index: int in range(_steps.size()):
		var step: Dictionary = _steps[index]
		var validate_callback: Callable = _get_step_callable(step, "validate_callback")
		if not validate_callback.is_valid():
			continue
		var result: Dictionary = _call_step(validate_callback, context, step, &"validate")
		if not GFVariantData.get_option_bool(result, "ok", true):
			state = STATE_FAILED
			_steps[index] = _set_step_result(step, STATE_FAILED, result)
			return get_report()
		_steps[index] = _set_step_result(step, STATE_PREPARED, result)
	state = STATE_PREPARED
	return get_report()


## 提交事务，失败时自动回滚已应用步骤。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 调用方上下文。
## [br]
## @schema context: Dictionary caller-defined activation context.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.
func commit(context: Dictionary = {}) -> Dictionary:
	if state == STATE_COMMITTED:
		return get_report()
	if state == STATE_ROLLED_BACK or state == STATE_FAILED:
		_append_transaction_issue_once(
			&"transaction_not_reusable",
			"activation transaction must be cleared before it can be committed again"
		)
		return get_report()

	var prepare_report: Dictionary = prepare(context)
	if not GFVariantData.get_option_bool(prepare_report, "ok", true):
		return prepare_report

	for index: int in range(_steps.size()):
		var step: Dictionary = _steps[index]
		var apply_callback: Callable = _get_step_callable(step, "apply_callback")
		var result: Dictionary = _call_step(apply_callback, context, step, &"apply")
		if not GFVariantData.get_option_bool(result, "ok", true):
			_steps[index] = _set_step_result(step, STATE_FAILED, result)
			_rollback_applied_steps(context)
			state = STATE_ROLLED_BACK if _all_applied_steps_rolled_back() else STATE_FAILED
			return get_report()
		step["applied"] = true
		_steps[index] = _set_step_result(step, STATE_COMMITTED, result)
	state = STATE_COMMITTED
	return get_report()


## 显式回滚已应用步骤。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param context: 调用方上下文。
## [br]
## @schema context: Dictionary caller-defined activation context.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.
func rollback(context: Dictionary = {}) -> Dictionary:
	_rollback_applied_steps(context)
	state = STATE_ROLLED_BACK if _all_applied_steps_rolled_back() else STATE_FAILED
	return get_report()


## 获取事务报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 报告选项，支持 fallback_action、no_action 和 warnings_as_errors。
## [br]
## @schema options: Dictionary report options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, transaction_id, state, steps, issues, summary, and next_action.
func get_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"subject": subject,
		"transaction_id": transaction_id,
		"state": state,
		"step_count": _steps.size(),
		"steps": _copy_step_summaries(),
		"issues": _copy_issues(),
		"metadata": metadata.duplicate(true),
	}
	return GFValidationReportDictionary.finalize_report(report, subject, {
		"fallback_action": GFVariantData.get_option_string(options, "fallback_action", "Review the first activation transaction issue."),
		"no_action": GFVariantData.get_option_string(options, "no_action", "Activation transaction is healthy."),
		"warnings_as_errors": GFVariantData.get_option_bool(options, "warnings_as_errors", false),
	})


## 检查步骤是否已应用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param step_id: 步骤 ID。
## [br]
## @return 已应用返回 true。
func is_step_applied(step_id: StringName) -> bool:
	for step: Dictionary in _steps:
		if GFVariantData.get_option_string_name(step, "step_id") == step_id:
			return GFVariantData.get_option_bool(step, "applied")
	return false


# --- 私有/辅助方法 ---

func _rollback_applied_steps(context: Dictionary) -> void:
	for index: int in range(_steps.size() - 1, -1, -1):
		var step: Dictionary = _steps[index]
		if not GFVariantData.get_option_bool(step, "applied") or GFVariantData.get_option_bool(step, "rolled_back"):
			continue
		var rollback_callback: Callable = _get_step_callable(step, "rollback_callback")
		if rollback_callback.is_valid():
			var result: Dictionary = _call_step(rollback_callback, context, step, &"rollback")
			if not GFVariantData.get_option_bool(result, "ok", true):
				_steps[index] = _set_step_result(step, STATE_FAILED, result)
				continue
		elif GFVariantData.get_option_bool(step, "rollback_required", true):
			var missing_result: Dictionary = _make_step_result(
				false,
				&"missing_rollback_callback",
				"activation transaction step has no rollback callback",
				step,
				&"rollback"
			)
			_merge_result_issues(missing_result)
			_steps[index] = _set_step_result(step, STATE_FAILED, missing_result)
			continue
		step["rolled_back"] = true
		step["state"] = STATE_ROLLED_BACK
		_steps[index] = step


func _call_step(callback: Callable, context: Dictionary, step: Dictionary, phase: StringName) -> Dictionary:
	if not callback.is_valid():
		var invalid_result: Dictionary = _make_step_result(false, &"invalid_callback", "activation transaction callback is invalid", step, phase)
		_merge_result_issues(invalid_result)
		return invalid_result
	var value: Variant = callback.call(context.duplicate(true))
	var result: Dictionary = _normalize_callback_result(value, step, phase)
	_merge_result_issues(result)
	return result


func _normalize_callback_result(value: Variant, step: Dictionary, phase: StringName) -> Dictionary:
	if _is_async_callback_result(value):
		return _make_step_result(
			false,
			KIND_ASYNC_CALLBACK_UNSUPPORTED,
			"activation transaction callbacks must be synchronous",
			step,
			phase,
			_make_async_callback_data(value)
		)
	if value == null:
		return _make_step_result(true, &"ok", "", step, phase)
	if value is bool:
		var bool_value: bool = value
		return _make_step_result(bool_value, &"ok" if bool_value else &"callback_failed", "", step, phase)
	if value is int:
		var error_code: int = value
		return _make_step_result(error_code == OK, &"ok" if error_code == OK else &"callback_error", error_string(error_code), step, phase, {
			"error_code": error_code,
		})
	if value is Dictionary:
		var value_dictionary: Dictionary = value
		var result: Dictionary = value_dictionary.duplicate(true)
		if not result.has("ok"):
			result["ok"] = GFVariantData.get_option_bool(result, "success", true)
		if not result.has("phase"):
			result["phase"] = phase
		if not result.has("step_id"):
			result["step_id"] = GFVariantData.get_option_string_name(step, "step_id")
		if not GFVariantData.get_option_bool(result, "ok", true) and GFVariantData.get_option_array(result, "issues").is_empty():
			var _issue: Dictionary = GFValidationReportDictionary.append_issue(
				result,
				GFVariantData.get_option_string_name(result, "severity", &"error"),
				GFVariantData.get_option_string_name(result, "kind", &"callback_failed"),
				GFVariantData.get_option_string(result, "message", "activation transaction callback failed"),
				{
					"step_id": GFVariantData.get_option_string_name(step, "step_id"),
					"phase": phase,
				}
			)
		return result
	return _make_step_result(true, &"ok", "", step, phase, {
		"value": GFVariantData.duplicate_variant(value),
	})


static func _is_async_callback_result(value: Variant) -> bool:
	if typeof(value) == TYPE_SIGNAL:
		return true
	if not (value is Object):
		return false
	var object_value: Object = value
	if not is_instance_valid(object_value):
		return false
	if object_value.get_class() == "GDScriptFunctionState":
		return true
	return object_value.has_method("resume") and object_value.has_signal("completed")


static func _make_async_callback_data(value: Variant) -> Dictionary:
	var data: Dictionary = {
		"value_type": type_string(typeof(value)),
	}
	if value is Object:
		var object_value: Object = value
		if is_instance_valid(object_value):
			data["class"] = object_value.get_class()
	return data


func _make_step_result(
	ok: bool,
	kind: StringName,
	message: String,
	step: Dictionary,
	phase: StringName,
	data: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"step_id": GFVariantData.get_option_string_name(step, "step_id"),
		"phase": phase,
		"issues": [],
		"data": data.duplicate(true),
	}
	if not ok:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			result,
			"error",
			kind,
			message if not message.is_empty() else "activation transaction step failed",
			{
				"step_id": GFVariantData.get_option_string_name(step, "step_id"),
				"phase": phase,
			}
		)
	return result


func _merge_result_issues(result: Dictionary) -> void:
	for issue_value: Variant in GFVariantData.get_option_array(result, "issues"):
		var issue: Dictionary = GFValidationReportDictionary.issue_to_dict(issue_value)
		if issue.is_empty():
			continue
		_issues.append(issue)


func _set_step_result(step: Dictionary, next_state: StringName, result: Dictionary) -> Dictionary:
	var updated: Dictionary = step.duplicate(true)
	updated["state"] = next_state
	updated["last_result"] = result.duplicate(true)
	return updated


func _copy_step_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step: Dictionary in _steps:
		result.append({
			"step_id": GFVariantData.get_option_string_name(step, "step_id"),
			"label": GFVariantData.get_option_string(step, "label"),
			"state": GFVariantData.get_option_string_name(step, "state", STATE_PENDING),
			"applied": GFVariantData.get_option_bool(step, "applied"),
			"rolled_back": GFVariantData.get_option_bool(step, "rolled_back"),
			"rollback_required": GFVariantData.get_option_bool(step, "rollback_required", true),
			"metadata": GFVariantData.get_option_dictionary(step, "metadata"),
			"last_result": GFVariantData.get_option_dictionary(step, "last_result"),
		})
	return result


func _copy_issues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue: Dictionary in _issues:
		result.append(issue.duplicate(true))
	return result


func _all_applied_steps_rolled_back() -> bool:
	for step: Dictionary in _steps:
		if GFVariantData.get_option_bool(step, "applied") and not GFVariantData.get_option_bool(step, "rolled_back"):
			return false
	return true


static func _get_callable_option(options: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


static func _get_step_callable(step: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(step, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _append_transaction_issue_once(kind: StringName, message: String) -> void:
	for issue: Dictionary in _issues:
		if GFVariantData.get_option_string(issue, "kind") == String(kind):
			return
	var report: Dictionary = { "issues": [] }
	var issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		{
			"transaction_id": transaction_id,
			"state": state,
		}
	)
	_issues.append(issue)
