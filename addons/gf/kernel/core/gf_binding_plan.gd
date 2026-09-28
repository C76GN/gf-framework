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
## @since 11.0.0
class_name GFBindingPlan
extends RefCounted


# --- 常量 ---

## 绑定生命周期枚举脚本缓存。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
const GFBindingLifetimesBase = preload("res://addons/gf/kernel/core/gf_binding_lifetimes.gd")

## Plan 结果脚本缓存。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
const GFBindingPlanResultBase = preload("res://addons/gf/kernel/core/gf_binding_plan_result.gd")

## Plan 尚可追加 required entry 且尚未执行的状态值。
## [br]
## @api private
const _STATE_BUILDING: int = 0

## Plan 正在顺序执行 required entry 的状态值。
## [br]
## @api private
const _STATE_EXECUTING: int = 1

## Plan 已冻结终态结果、正在清理引用的状态值。
## [br]
## @api private
const _STATE_SETTLING: int = 2

## Plan 已完成终态清理、不可再次执行的状态值。
## [br]
## @api private
const _STATE_SETTLED: int = 3

## required binding ID 的最大字符数。
## [br]
## @api private
const _MAX_BINDING_ID_LENGTH: int = 128

## required binding target path 的最大字符数。
## [br]
## @api private
const _MAX_TARGET_PATH_LENGTH: int = 512


# --- 私有变量 ---

## 创建 Plan 的候选 Architecture；结算完成后清空。
## [br]
## @api private
var _architecture: GFArchitecture = null

## 按声明顺序保存已冻结的 required entry。
## [br]
## @api private
var _entries: Array[RequiredBindingEntry] = []

## 已接纳 binding ID 的集合，用于拒绝重复 ID。
## [br]
## @api private
var _binding_ids: Dictionary = {}

## 已处理声明的序号计数；追加 entry 时先递增并据此分配索引。
## [br]
## @api private
var _declaration_count: int = 0

## 配置阶段首次发现的问题对应的 entry；Plan 级错误时也保存其声明快照。
## [br]
## @api private
var _configuration_failure: RequiredBindingEntry = null

## 标记配置错误是否应关联到具体 entry。
## [br]
## @api private
var _configuration_failure_has_entry: bool = false

## 首个配置错误的结果原因。
## [br]
## @api private
var _configuration_reason: int = GFBindingPlanResultBase.Reason.NONE

## 首个配置错误的详细说明。
## [br]
## @api private
var _configuration_detail: String = ""

## 当前 Plan 执行与终态结算阶段。
## [br]
## @api private
var _state: int = _STATE_BUILDING

## 冻结的终态结果副本。
## [br]
## @api private
var _terminal_result: GFBindingPlanResult = null


# --- Godot 生命周期方法 ---

## 捕获 Binder 提供的候选架构，开始可追加条目的计划；此时不执行绑定或初始化。
## [br]
## @api framework_internal
## [br]
## @param architecture: 本计划稍后提交必需绑定的候选架构。
## [br]
## @return 无返回值。
func _init(architecture: GFArchitecture) -> void:
	_architecture = architecture


# --- 公共方法 ---

## 追加一个 required singleton entry，并立即冻结 Builder 配置。
## Plan 开始执行后调用保持 no-op；不会修改已经冻结的 entry。
## [br]
## @api public
## [br]
## @since 11.0.0
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
## @since 11.0.0
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
## @since 11.0.0
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
			"[GFBindingPlan][binding_plan.already_executed] Required binding plan has already executed.",
			0
		)
	_state = _STATE_EXECUTING
	if scope == null or scope.is_completed():
		var unavailable_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.SCOPE_UNAVAILABLE,
			"[GFBindingPlan][binding_plan.scope_unavailable] Required binding plan needs an active Installer scope.",
			0
		)
		return _settle_boundary_rejection(unavailable_result, true)
	if _architecture == null:
		var missing_architecture_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.ARCHITECTURE_UNAVAILABLE,
			"[GFBindingPlan][binding_plan.architecture_unavailable] Required binding plan architecture is unavailable.",
			0
		)
		return _settle_boundary_rejection(missing_architecture_result, true)
	if not _architecture.can_accept_required_binding_plan_for_framework():
		var closed_architecture_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.INVALID_REQUEST,
			GFBindingPlanResultBase.Phase.VALIDATION,
			GFBindingPlanResultBase.Reason.ARCHITECTURE_UNAVAILABLE,
			"[GFBindingPlan][binding_plan.admission_closed] Architecture admission is closed for required binding plans.",
			0
		)
		return _settle_boundary_rejection(closed_architecture_result, false)
	if scope.is_cancel_requested():
		var pre_cancelled_result: GFBindingPlanResult = _make_no_entry_result(
			GFBindingPlanResultBase.Status.CANCELLED,
			GFBindingPlanResultBase.Phase.CANCELLATION,
			GFBindingPlanResultBase.Reason.SCOPE_CANCELLED,
			"[GFBindingPlan][binding_plan.scope_cancelled] Required binding scope was cancelled: %s." % String(
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
			"[GFBindingPlan][binding_plan.entries_empty] Required binding plan has no entries.",
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
				"[GFBindingPlan][binding_plan.scope_cancelled] Required binding scope was cancelled: %s." % String(
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
				"[GFBindingPlan][binding_plan.scope_completed_before_entry] Required binding scope completed before entry execution.",
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
				"[GFBindingPlan][binding_plan.admission_closed_before_entry] Architecture admission closed before required entry execution."
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
				"[GFBindingPlan][binding_plan.scope_cancelled] Required binding scope was cancelled: %s." % String(
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
				"[GFBindingPlan][binding_plan.scope_completed_during_entry] Required binding scope completed during entry execution."
			)
			return _settle_candidate_failure(after_entry_completed, scope)
		if attempt == null:
			var invalid_attempt_result: GFBindingPlanResult = _make_entry_result(
				GFBindingPlanResultBase.Status.FAILED,
				entry,
				GFBindingPlanResultBase.Phase.REGISTRATION,
				GFBindingPlanResultBase.Reason.REGISTRATION_REJECTED,
				index + 1,
				"[GFBindingPlan][binding_plan.attempt_result_missing] Required binding attempt returned no terminal result."
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

## 冻结 Builder 配置并按顺序追加 entry；首次验证失败会保存配置错误供 execute() 返回。
## [br]
## @api private
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
			"[GFBindingPlan][binding_plan.binding_id_invalid] Required binding_id must be non-empty and at most 128 characters.",
			false
		)
		return self
	if target_path.length() > _MAX_TARGET_PATH_LENGTH:
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.INVALID_ENTRY,
			"[GFBindingPlan][binding_plan.target_path_too_long] Required binding target path exceeds 512 characters.",
			false
		)
		return self
	if _binding_ids.has(binding_id):
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.DUPLICATE_BINDING_ID,
			"[GFBindingPlan][binding_plan.binding_id_duplicate] Required binding_id is duplicated: %s." % String(binding_id)
		)
		return self
	if builder == null:
		_freeze_configuration_failure(
			entry,
			GFBindingPlanResultBase.Reason.INVALID_ENTRY,
			"[GFBindingPlan][binding_plan.builder_null] Required binding builder is null.",
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
			"[GFBindingPlan][binding_plan.builder_architecture_mismatch] Required binding builder belongs to another Architecture."
		)
		return self
	entry._builder = frozen_builder
	_binding_ids[binding_id] = true
	_entries.append(entry)
	return self


## 仅保存第一次发现的配置错误及其关联 entry 信息。
## [br]
## @api private
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


## 使用冻结的 entry 元数据构造类型化结果，并在配置失败时记录错误。
## [br]
## @api private
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
		push_error("[GFBindingPlan][binding_plan.entry_result_configuration_failed] Could not construct the terminal entry result; error code: %d." % configured)
	return result


## 构造不关联具体 entry 的 Plan 级类型化结果。
## [br]
## @api private
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
		push_error("[GFBindingPlan][binding_plan.plan_result_configuration_failed] Could not construct the terminal Plan result; error code: %d." % configured)
	return result


## 冻结边界拒绝结果，可选输出错误，然后清理 Plan 并返回结果副本。
## [br]
## @api private
func _settle_boundary_rejection(
	result: GFBindingPlanResult,
	report_error: bool
) -> GFBindingPlanResult:
	_freeze_terminal(result)
	if report_error:
		push_error(result.get_detail())
	_finish_terminal_settlement()
	return result.duplicate_result()


## 冻结候选失败结果、通知 Architecture 失败、取消仍活动的 scope 并清理 Plan。
## [br]
## @api private
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


## 冻结成功结果、清理 Plan，并返回结果副本。
## [br]
## @api private
func _settle_success(result: GFBindingPlanResult) -> GFBindingPlanResult:
	_freeze_terminal(result)
	_finish_terminal_settlement()
	return result.duplicate_result()


## 复制终态结果并将 Plan 切换到结算状态。
## [br]
## @api private
func _freeze_terminal(result: GFBindingPlanResult) -> void:
	_terminal_result = result.duplicate_result()
	_state = _STATE_SETTLING


## 清空 entry、ID 和配置错误引用，解除 Architecture 引用并标记 Plan 已结算。
## [br]
## @api private
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
## @since 11.0.0
class RequiredBindingEntry extends RefCounted:
	# --- 私有变量 ---
	## 条目在计划中的提交序号，失败结果沿用该序号定位原始配置。
	## [br]
	## @api private
	var _index: int = -1

	## 调用方指定的稳定绑定标识，用于失败结果关联与计划内重复检查。
	## [br]
	## @api private
	var _binding_id: StringName = &""

	## 本条目绑定的模块或工厂类别，保存 BindingKind 枚举值。
	## [br]
	## @api private
	var _binding_kind: int = GFBindingPlanResultBase.BindingKind.NONE

	## 捕获的目标脚本路径，仅用于计划条目与结果中的定位信息。
	## [br]
	## @api private
	var _target_path: String = ""

	## 执行本条目时传入 builder 的生命周期选项，非适用场景沿用哨兵值。
	## [br]
	## @api private
	var _lifetime: int = -1

	## 经计划配置校验后冻结的绑定构建器；执行阶段通过它提交必需绑定。
	## [br]
	## @api private
	var _builder: GFBindBuilder = null


	# --- Godot 生命周期方法 ---
	## 捕获条目的原始定位信息与 builder 引用；外层计划完成校验后可替换为冻结的 builder。
	## [br]
	## @api private
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
