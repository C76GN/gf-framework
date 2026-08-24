## GFBindingPlan: Installer 使用的显式、顺序、fail-fast required binding 计划。
##
## 声明时冻结每个 Builder 的配置；execute() 仅接纳尚未进入 init/READY 的候选
## Architecture。首个失败会冻结类型化结果、使候选初始化失败并结算 Installer
## scope；成功不会替调用方 complete scope。READY 架构继续使用既有热拓扑 API，
## 不由本计划修改。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFBindingPlan
extends RefCounted


# --- 常量 ---

## 绑定生命周期枚举脚本缓存。
## [br]
## @api framework_internal
## [br]
## @since unreleased
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## Plan 结果脚本缓存。
## [br]
## @api framework_internal
## [br]
## @since unreleased
const GFBindingPlanResultBase = preload("res://addons/gf/kernel/core/gf_binding_plan_result.gd")

const _STATE_BUILDING: int = 0
const _STATE_EXECUTING: int = 1
const _STATE_SETTLING: int = 2
const _STATE_SETTLED: int = 3
const _MAX_BINDING_ID_LENGTH: int = 128
const _MAX_TARGET_PATH_LENGTH: int = 512


# --- 私有变量 ---

var _architecture: GFArchitecture = null
var _entries: Array[RequiredBindingEntry] = []
var _binding_ids: Dictionary = {}
var _declaration_count: int = 0
var _configuration_failure: RequiredBindingEntry = null
var _configuration_failure_has_entry: bool = false
var _configuration_reason: int = GFBindingPlanResultBase.Reason.NONE
var _configuration_detail: String = ""
var _state: int = _STATE_BUILDING
var _terminal_result: GFBindingPlanResult = null


# --- Godot 生命周期方法 ---

func _init(architecture: GFArchitecture) -> void:
	_architecture = architecture


# --- 公共方法 ---

## 追加一个 required singleton entry，并立即冻结 Builder 配置。
## Plan 开始执行后调用保持 no-op；不会修改已经冻结的 entry。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param binding_id: 调用方定义的非空稳定 ID；同一 Plan 内必须唯一，最长 128 字符。
## [br]
## @param builder: 由创建本 Plan 的同一 GFBinder 架构生成的 Builder。
## [br]
## @return 当前 Plan，便于继续声明 entry。
func require_singleton(
	binding_id: StringName,
	builder: GFBindBuilder
) -> GFBindingPlan:
	return _append_required_entry(
		binding_id,
		builder,
		GFBindingLifetimesBase.Lifetime.SINGLETON
	)


## 追加一个 required transient factory entry，并立即冻结 Builder 配置。
## 只有 bind_factory() 的 SELF 或 from_factory() 来源支持 transient。
## Plan 开始执行后调用保持 no-op；不会修改已经冻结的 entry。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param binding_id: 调用方定义的非空稳定 ID；同一 Plan 内必须唯一，最长 128 字符。
## [br]
## @param builder: 由创建本 Plan 的同一 GFBinder 架构生成的 Builder。
## [br]
## @return 当前 Plan，便于继续声明 entry。
func require_transient(
	binding_id: StringName,
	builder: GFBindBuilder
) -> GFBindingPlan:
	return _append_required_entry(
		binding_id,
		builder,
		GFBindingLifetimesBase.Lifetime.TRANSIENT
	)


## 按声明顺序执行 required entry，并在首个失败处停止。
## 仅接纳 pre-init candidate Architecture；READY 架构不会被 claim、失败或修改。
## Plan 是 strict single-execute handle：执行中重入或结算后 replay 均返回
## ALREADY_EXECUTED，且不会触碰重入调用的新 scope 或 Architecture。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scope: 当前 Installer 拥有的异步取消作用域；成功时仍由调用方拥有。
## [br]
## @return 精确 GFBindingPlanResult 终态。
func execute(scope: GFAsyncScope) -> GFBindingPlanResult:
	if _state != _STATE_BUILDING:
		return _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.ALREADY_EXECUTED,
			"Required binding plan has already executed.",
			0
		)
	_state = _STATE_EXECUTING
	if scope == null or scope.is_completed():
		var unavailable_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.SCOPE_UNAVAILABLE,
			"Required binding plan needs an active Installer scope.",
			0
		)
		return _settle_boundary_rejection(unavailable_result, true)
	if _architecture == null:
		var missing_architecture_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.ARCHITECTURE_UNAVAILABLE,
			"Required binding plan architecture is unavailable.",
			0
		)
		return _settle_boundary_rejection(missing_architecture_result, true)
	if not _architecture.can_accept_required_binding_plan_for_framework():
		var closed_architecture_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.ARCHITECTURE_UNAVAILABLE,
			"Architecture admission is closed for required binding plans.",
			0
		)
		return _settle_boundary_rejection(closed_architecture_result, false)
	if scope.is_cancel_requested():
		var pre_cancelled_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.CANCELLED,
			GFBindingPlanResultBase.Phase.CANCELLATION,
			GFBindingPlanResultBase.Reason.SCOPE_CANCELLED,
			"Required binding scope was cancelled: %s" % String(
				scope.get_cancel_reason()
			),
			0
		)
		return _settle_candidate_failure(pre_cancelled_result, scope)
	if _configuration_failure != null:
		var configuration_result: GFBindingPlanResult = null
		if _configuration_failure_has_entry:
			configuration_result = _make_entry_result(
				GFBindingPlanResultBase.Status.INVALID_REQUEST,
				_configuration_failure,
				GFBindingPlanResultBase.Phase.VALIDATION,
				_configuration_reason,
				0,
				_configuration_detail
			)
		else:
			configuration_result = _make_no_entry_result(
				GFBindingPlanResultBase.Status.INVALID_REQUEST,
				GFBindingPlanResultBase.Phase.VALIDATION,
				_configuration_reason,
				_configuration_detail,
				0
			)
		return _settle_candidate_failure(configuration_result, scope)
	if _entries.is_empty():
		var empty_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.INVALID_PLAN,
			"Required binding plan has no entries.",
			0
		)
		return _settle_candidate_failure(empty_result, scope)

	for index: int in range(_entries.size()):
		var entry: RequiredBindingEntry = _entries[index]
		if scope.is_cancel_requested():
			var before_entry_cancelled: GFBindingPlanResult = _make_no_entry_result(
				GFBindingPlanResultBase.Status.CANCELLED,
				GFBindingPlanResultBase.Phase.CANCELLATION,
				GFBindingPlanResultBase.Reason.SCOPE_CANCELLED,
				"Required binding scope was cancelled: %s" % String(
					scope.get_cancel_reason()
				),
				index
			)
			return _settle_candidate_failure(before_entry_cancelled, scope)
		if scope.is_completed():
			var before_entry_completed: GFBindingPlanResult = _make_no_entry_result(
				GFBindingPlanResultBase.Status.INVALID_REQUEST,
				GFBindingPlanResultBase.Phase.VALIDATION,
				GFBindingPlanResultBase.Reason.SCOPE_UNAVAILABLE,
				"Required binding scope completed before entry execution.",
				index
			)
			return _settle_candidate_failure(before_entry_completed, scope)
		if not _architecture.can_accept_required_binding_plan_for_framework():
			var unavailable_entry_result: GFBindingPlanResult = _make_entry_result(
				GFBindingPlanResultBase.Status.INVALID_REQUEST,
				entry,
				GFBindingPlanResultBase.Phase.VALIDATION,
				GFBindingPlanResultBase.Reason.ARCHITECTURE_UNAVAILABLE,
				index,
				"Architecture admission closed before required entry execution."
			)
			return _settle_candidate_failure(unavailable_entry_result, scope)

		var attempt: GFBindBuilder.RequiredBindingAttempt = (
			entry._builder.execute_required_binding_for_framework(entry._lifetime)
		)
		if scope.is_cancel_requested():
			var after_entry_cancelled: GFBindingPlanResult = _make_entry_result(
				GFBindingPlanResultBase.Status.CANCELLED,
				entry,
				GFBindingPlanResultBase.Phase.CANCELLATION,
				GFBindingPlanResultBase.Reason.SCOPE_CANCELLED,
				index + 1,
				"Required binding scope was cancelled: %s" % String(
					scope.get_cancel_reason()
				)
			)
			return _settle_candidate_failure(after_entry_cancelled, scope)
		if scope.is_completed():
			var after_entry_completed: GFBindingPlanResult = _make_entry_result(
				GFBindingPlanResultBase.Status.INVALID_REQUEST,
				entry,
				GFBindingPlanResultBase.Phase.VALIDATION,
				GFBindingPlanResultBase.Reason.SCOPE_UNAVAILABLE,
				index + 1,
				"Required binding scope completed during entry execution."
			)
			return _settle_candidate_failure(after_entry_completed, scope)
		if attempt == null:
			var invalid_attempt_result: GFBindingPlanResult = _make_entry_result(
				GFBindingPlanResultBase.Status.FAILED,
				entry,
				GFBindingPlanResultBase.Phase.REGISTRATION,
				GFBindingPlanResultBase.Reason.REGISTRATION_REJECTED,
				index + 1,
				"Required binding attempt returned no terminal result."
			)
			return _settle_candidate_failure(invalid_attempt_result, scope)
		if not attempt.is_successful_for_framework():
			var attempt_status: int = GFBindingPlanResultBase.Status.FAILED
			if attempt.get_phase_for_framework() == GFBindingPlanResultBase.Phase.VALIDATION:
				attempt_status = GFBindingPlanResultBase.Status.INVALID_REQUEST
			var failed_attempt_result: GFBindingPlanResult = _make_entry_result(
				attempt_status,
				entry,
				attempt.get_phase_for_framework(),
				attempt.get_reason_for_framework(),
				index + 1,
				attempt.get_detail_for_framework()
			)
			return _settle_candidate_failure(failed_attempt_result, scope)
	var success_result: GFBindingPlanResult = _make_no_entry_result(
		GFBindingPlanResultBase.Status.SUCCESS,
		GFBindingPlanResultBase.Phase.NONE,
		GFBindingPlanResultBase.Reason.NONE,
		"",
		_entries.size()
	)
	return _settle_success(success_result)


# --- 私有/辅助方法 ---

func _append_required_entry(
	binding_id: StringName,
	builder: GFBindBuilder,
	lifetime: int
) -> GFBindingPlan:
	if _state != _STATE_BUILDING:
		return self
	var entry_index: int = _declaration_count
	_declaration_count += 1
	var binding_kind: int = GFBindingPlanResultBase.BindingKind.NONE
	var target_path: String = ""
	if builder != null:
		binding_kind = builder.get_required_binding_kind_for_framework()
		target_path = builder.get_required_target_path_for_framework()
	var entry: RequiredBindingEntry = RequiredBindingEntry.new(
		entry_index,
		binding_id,
		binding_kind,
		target_path,
		lifetime,
		null
	)
	if _configuration_failure != null:
		return self
	if (
		binding_id == &""
		or String(binding_id).length() > _MAX_BINDING_ID_LENGTH
	):
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.INVALID_ENTRY,
			"Required binding_id must be non-empty and at most 128 characters.",
			false
		)
		return self
	if target_path.length() > _MAX_TARGET_PATH_LENGTH:
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.INVALID_ENTRY,
			"Required binding target path exceeds 512 characters.",
			false
		)
		return self
	if _binding_ids.has(binding_id):
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.DUPLICATE_BINDING_ID,
			"Required binding_id is duplicated: %s" % String(binding_id)
		)
		return self
	if builder == null:
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.INVALID_ENTRY,
			"Required binding builder is null.",
			false
		)
		return self
	var frozen_builder: GFBindBuilder = (
		builder.duplicate_for_required_plan_for_framework(_architecture)
	)
	if frozen_builder == null:
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.BUILDER_OWNERSHIP_MISMATCH,
			"Required binding builder belongs to another Architecture."
		)
		return self
	entry._builder = frozen_builder
	_binding_ids[binding_id] = true
	_entries.append(entry)
	return self


func _freeze_configuration_failure(
	entry: RequiredBindingEntry,
	reason: int,
	detail: String,
	has_entry: bool = true
) -> void:
	if _configuration_failure != null:
		return
	_configuration_failure = entry
	_configuration_failure_has_entry = has_entry
	_configuration_reason = reason
	_configuration_detail = detail


func _make_entry_result(
	status: int,
	entry: RequiredBindingEntry,
	phase: int,
	reason: int,
	executed_count: int,
	detail: String
) -> GFBindingPlanResult:
	var result: GFBindingPlanResult = GFBindingPlanResultBase.new()
	var configured: Error = result.configure_for_framework(
		status,
		entry._binding_kind,
		phase,
		reason,
		entry._index,
		entry._binding_id,
		entry._target_path,
		entry._lifetime,
		executed_count,
		detail
	)
	if configured != OK:
		push_error("[GFBindingPlan] 无法构造 entry 终态，错误码：%d。" % configured)
	return result


func _make_no_entry_result(
	status: int,
	phase: int,
	reason: int,
	detail: String,
	executed_count: int
) -> GFBindingPlanResult:
	var result: GFBindingPlanResult = GFBindingPlanResultBase.new()
	var configured: Error = result.configure_for_framework(
		status,
		GFBindingPlanResultBase.BindingKind.NONE,
		phase,
		reason,
		-1,
		&"",
		"",
		-1,
		executed_count,
		detail
	)
	if configured != OK:
		push_error("[GFBindingPlan] 无法构造 Plan 终态，错误码：%d。" % configured)
	return result


func _settle_boundary_rejection(
	result: GFBindingPlanResult,
	report_error: bool
) -> GFBindingPlanResult:
	_freeze_terminal(result)
	if report_error:
		push_error(result.get_detail())
	_finish_terminal_settlement()
	return result.duplicate_result()


func _settle_candidate_failure(
	result: GFBindingPlanResult,
	scope: GFAsyncScope
) -> GFBindingPlanResult:
	_freeze_terminal(result)
	_architecture.fail_initialization(result.get_detail())
	if scope != null and scope.is_active():
		var _cancelled_scope: bool = scope.cancel(result.get_detail())
	_finish_terminal_settlement()
	return result.duplicate_result()


func _settle_success(result: GFBindingPlanResult) -> GFBindingPlanResult:
	_freeze_terminal(result)
	_finish_terminal_settlement()
	return result.duplicate_result()


func _freeze_terminal(result: GFBindingPlanResult) -> void:
	_terminal_result = result.duplicate_result()
	_state = _STATE_SETTLING


func _finish_terminal_settlement() -> void:
	_entries.clear()
	_binding_ids.clear()
	_configuration_failure = null
	_configuration_failure_has_entry = false
	_configuration_reason = GFBindingPlanResultBase.Reason.NONE
	_configuration_detail = ""
	_architecture = null
	_state = _STATE_SETTLED


# --- 内部类（内部状态类型） ---

## 单个 required binding 的冻结声明。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class RequiredBindingEntry extends RefCounted:
	var _index: int = -1
	var _binding_id: StringName = &""
	var _binding_kind: int = GFBindingPlanResultBase.BindingKind.NONE
	var _target_path: String = ""
	var _lifetime: int = -1
	var _builder: GFBindBuilder = null


	func _init(
		entry_index: int,
		entry_binding_id: StringName,
		entry_binding_kind: int,
		entry_target_path: String,
		entry_lifetime: int,
		entry_builder: GFBindBuilder
	) -> void:
		_index = entry_index
		_binding_id = entry_binding_id
		_binding_kind = entry_binding_kind
		_target_path = entry_target_path
		_lifetime = entry_lifetime
		_builder = entry_builder
