## GFSaveProfileTransactionCoordinator: 活动 Profile 身份与跨 Profile 事务协调器。
##
## Coordinator 在完全相同且同序的 Provider 实例拓扑上建立独立 domain，委托
## `GFSaveProfileUtility` 完成 generation、Storage IO、重试与 detached settlement。
## 它不解释业务 payload，也不拥有项目的身份到路径、云同步或恢复选择。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSaveProfileTransactionCoordinator
extends GFUtility


# --- 信号 ---

## 活动 Profile 身份完成原子提交后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param previous_profile_id: 提交前活动 Profile；首次激活时为空。
## [br]
## @param current_profile_id: 提交后活动 Profile。
signal active_profile_changed(
	previous_profile_id: StringName,
	current_profile_id: StringName
)

## 任一事务进入稳定终态时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 不包含持久化 payload 的隔离结果。
signal transaction_completed(result: GFSaveProfileTransactionResult)


# --- 常量 ---

## Domain 尚未建立活动身份。
## [br]
## @api public
## [br]
## @since unreleased
const DOMAIN_STATE_INACTIVE: StringName = &"inactive"

## Domain 已建立一个可直接 save/flush 的活动身份。
## [br]
## @api public
## [br]
## @since unreleased
const DOMAIN_STATE_ACTIVE: StringName = &"active"

## Domain 正在执行一个事务。
## [br]
## @api public
## [br]
## @since unreleased
const DOMAIN_STATE_TRANSACTING: StringName = &"transacting"

## Domain 被 outcome_unknown 或显式故障围栏占用，必须对账。
## [br]
## @api public
## [br]
## @since unreleased
const DOMAIN_STATE_RECONCILIATION_REQUIRED: StringName = &"reconciliation_required"

## Coordinator 已释放。
## [br]
## @api public
## [br]
## @since unreleased
const DOMAIN_STATE_DISPOSED: StringName = &"disposed"

const _STAGE_ACTIVATE_LOAD: StringName = &"activate_load"
const _STAGE_SOURCE_FLUSH: StringName = &"source_flush"
const _STAGE_TARGET_LOAD: StringName = &"target_load"
const _STAGE_RECOVERY_SAVE: StringName = &"recovery_save"
const _STAGE_MUTATION_FLUSH: StringName = &"mutation_flush"
const _STAGE_MUTATION_QUEUED: StringName = &"mutation_queued"
const _STAGE_MUTATION_APPLY: StringName = &"mutation_apply"
const _STAGE_MUTATION_SAVE: StringName = &"mutation_save"
const _STAGE_RECONCILE_LOAD: StringName = &"reconcile_load"
const _MAX_PROFILE_RESULT_EVIDENCE_ERROR_LENGTH: int = 2_048


# --- 私有变量 ---

var _profile_utility: GFSaveProfileUtility = null
var _profile_utility_explicit: bool = false
var _profiles: Dictionary = {}
var _domains: Dictionary = {}
var _domain_id_by_profile: Dictionary = {}
var _recovery_records: Dictionary = {}
var _reconcile_records: Dictionary = {}
var _next_domain_id: int = 1
var _next_transaction_id: int = 1
var _next_lease_id: int = 1
var _disposed: bool = false
var _dispose_requested: bool = false
var _admission_open: bool = true
var _notification_depth: int = 0
var _processing_depth: int = 0
var _pending_domain_ids: PackedInt64Array = PackedInt64Array()
var _quiesce_completion: GFAsyncCompletion = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	tick_enabled = true
	ignore_pause = true
	ignore_time_scale = true


# --- GF 生命周期方法 ---

## 声明底层 Save Profile Utility 依赖。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 仅包含 `GFSaveProfileUtility`。
func get_required_utilities() -> Array[Script]:
	var dependencies: Array[Script] = [GFSaveProfileUtility]
	return dependencies


## 在架构 ready 阶段采用已注册的 Profile Utility。
## [br]
## @api public
## [br]
## @since unreleased
func ready() -> void:
	if _profile_utility_explicit:
		return
	var utility_value: Variant = get_utility(GFSaveProfileUtility)
	if utility_value is GFSaveProfileUtility:
		var profile_utility: GFSaveProfileUtility = utility_value
		_set_profile_utility(profile_utility)


## 开放事务准入；底层 Utility 不可用时失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _scope: 当前激活阶段的取消作用域。
## [br]
## @return 一次性激活完成源。
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _disposed or _profile_utility == null:
		var _failed: bool = completion.fail(
			"GFSaveProfileUtility must be configured before transaction activation."
		)
		return completion
	if _quiesce_completion != null:
		var _failed_quiesced: bool = completion.fail(
			"Save Profile transaction coordinator cannot reactivate after quiesce."
		)
		return completion
	_admission_open = true
	var _succeeded: bool = completion.succeed()
	return completion


## 关闭新事务准入，并等待已接纳事务与 reconcile fence 收敛。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scope: 当前静默阶段的取消作用域。
## [br]
## @return 全部 domain 可安全关闭时完成的一次性完成源。
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	_admission_open = false
	if _quiesce_completion != null:
		return _quiesce_completion
	_quiesce_completion = GFAsyncCompletion.new()
	if scope != null:
		var _bound: bool = _quiesce_completion.bind_cancel_token(scope)
	for domain_value: Variant in _domains.values():
		_update_domain_managed_access(_get_domain_value(domain_value))
	_try_complete_quiesce()
	return _quiesce_completion


## 推进已接纳的同步 Provider mutation 阶段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 未使用；底层 IO 由 Profile Utility 推进。
func tick(_delta: float) -> void:
	if _disposed:
		return
	if not _pending_domain_ids.is_empty():
		var batch: PackedInt64Array = _pending_domain_ids.duplicate()
		_pending_domain_ids = PackedInt64Array()
		for domain_id: int in batch:
			var domain: DomainState = _get_domain(domain_id)
			if domain == null:
				continue
			domain.pending_tick = false
			var transaction: TransactionState = domain.current_transaction
			if transaction != null and transaction.stage == _STAGE_MUTATION_QUEUED:
				_apply_mutation_candidates(domain, transaction)
	_try_complete_quiesce()


## 强制结束未完成事务并释放全部 manager capability。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	_admission_open = false
	if _processing_depth > 0 or _notification_depth > 0:
		_dispose_requested = true
		return
	_dispose_now()


## 释放架构注入依赖。
## [br]
## @api public
## [br]
## @since unreleased
func release_dependencies() -> void:
	_disconnect_profile_utility()
	super.release_dependencies()


# --- 公共方法 ---

## 显式注入底层 Profile Utility，供 standalone 场景与测试使用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_utility: 已配置的底层 Profile Utility。
## [br]
## @return 当前 Coordinator；输入无效或已有受管 Profile 时返回 null。
func setup(
	profile_utility: GFSaveProfileUtility
) -> GFSaveProfileTransactionCoordinator:
	if _disposed or profile_utility == null or not _profiles.is_empty():
		return null
	_profile_utility_explicit = true
	_set_profile_utility(profile_utility)
	return self


## 注册并声明一个受管 Profile。
##
## 完全相同且同序的 Provider 实例序列共享 domain；任意部分重叠或同实例异序
## 会在触碰底层注册前失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile: Profile 声明。
## [br]
## @param migrations: 可选迁移注册表。
## [br]
## @return 底层注册报告，附加 managed 与 provider_domain_id 字段。
## [br]
## @schema return: GFValidationReportDictionary-compatible report with managed and provider_domain_id fields.
func register_profile(
	profile: GFSaveProfile,
	migrations: GFSaveMigrationRegistry = null
) -> Dictionary:
	if _profile_utility == null:
		return _make_registration_failure(
			profile,
			&"profile_utility_unconfigured",
			"GFSaveProfileUtility must be configured before managed registration."
		)
	if not _admission_open or _disposed or _notification_depth > 0:
		return _make_registration_failure(
			profile,
			&"coordinator_busy",
			"Save Profile transaction coordinator is not accepting registrations."
		)
	if profile == null:
		return _profile_utility.register_profile(profile, migrations)
	var topology_check: Dictionary = _inspect_registration_topology(profile.providers)
	if not GFVariantData.get_option_bool(topology_check, "ok", false):
		return _make_registration_failure(
			profile,
			GFVariantData.get_option_string_name(topology_check, "kind"),
			GFVariantData.get_option_string(topology_check, "error")
		)
	var report: Dictionary = _profile_utility.register_profile(profile, migrations)
	if not GFVariantData.get_option_bool(report, "registered", false):
		return report
	var descriptor: Dictionary = (
		_profile_utility.get_profile_descriptor_for_manager_for_framework(
			profile.profile_id
		)
	)
	var permit: RefCounted = _profile_utility.claim_profile_management_for_framework(
		profile.profile_id,
		self
	)
	if descriptor.is_empty() or permit == null:
		if permit != null:
			var _rolled_back_managed: bool = (
				_profile_utility.unregister_profile_for_manager_for_framework(
					profile.profile_id,
					permit
				)
			)
		else:
			var _rolled_back_registration: bool = _profile_utility.unregister_profile(
				profile.profile_id
			)
		return _make_registration_failure(
			profile,
			&"management_claim_failed",
			"Registered Profile could not enter managed ownership."
		)
	var domain: DomainState = _attach_profile_to_domain(
		profile.profile_id,
		descriptor,
		permit,
		GFVariantData.get_option_int(topology_check, "matching_domain_id")
	)
	if domain == null:
		var _released: bool = _profile_utility.release_profile_management_for_framework(
			profile.profile_id,
			permit
		)
		var _unregistered: bool = _profile_utility.unregister_profile(profile.profile_id)
		return _make_registration_failure(
			profile,
			&"domain_attach_failed",
			"Managed Provider domain could not be committed."
		)
	report["managed"] = true
	report["provider_domain_id"] = domain.domain_id
	return report


## 注销一个无活动身份、事务或 fence 的受管 Profile。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 受管 Profile ID。
## [br]
## @return 安全注销成功时返回 true。
func unregister_profile(profile_id: StringName) -> bool:
	var profile: ManagedProfile = _get_profile(profile_id)
	var domain: DomainState = _get_domain_for_profile(profile_id)
	if (
		not _admission_open
		or _disposed
		or _notification_depth > 0
		or profile == null
		or domain == null
		or domain.active_profile_id != &""
		or domain.current_transaction != null
		or domain.reconcile_lease != null
	):
		return false
	if not _profile_utility.unregister_profile_for_manager_for_framework(
		profile_id,
		profile.permit
	):
		return false
	_invalidate_recovery_leases(domain)
	var _profile_erased: bool = _profiles.erase(profile_id)
	var _domain_index_erased: bool = _domain_id_by_profile.erase(profile_id)
	domain.profile_ids.erase(profile_id)
	if domain.profile_ids.is_empty():
		var _domain_erased: bool = _domains.erase(domain.domain_id)
	return true


## 获取指定受管 Profile 所在 domain 的活动身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 用于定位 Provider domain 的任一受管 Profile ID。
## [br]
## @return 活动 Profile ID；domain 未激活或 Profile 不存在时为空。
func get_active_profile_id(profile_id: StringName) -> StringName:
	var domain: DomainState = _get_domain_for_profile(profile_id)
	return domain.active_profile_id if domain != null else &""


## 获取无载荷 domain 调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 用于定位 Provider domain 的任一受管 Profile ID。
## [br]
## @return domain 状态、活动身份、generation、epoch 与事务/lease ID。
## [br]
## @schema return: Payload-free Dictionary with domain_id, state, active_profile_id, profile_ids, domain_generation, transaction_epoch, transaction_id, reconcile_lease_id, quiescing, and disposed fields.
func get_domain_state_snapshot(profile_id: StringName) -> Dictionary:
	var domain: DomainState = _get_domain_for_profile(profile_id)
	if domain == null:
		return {}
	return {
		"domain_id": domain.domain_id,
		"state": domain.state,
		"active_profile_id": domain.active_profile_id,
		"profile_ids": _string_name_array_to_packed(domain.profile_ids),
		"domain_generation": domain.domain_generation,
		"transaction_epoch": domain.transaction_epoch,
		"transaction_id": (
			domain.current_transaction.operation.get_transaction_id()
			if domain.current_transaction != null
			else 0
		),
		"reconcile_lease_id": (
			domain.reconcile_lease.get_lease_id()
			if domain.reconcile_lease != null
			else 0
		),
		"quiescing": not _admission_open,
		"disposed": _disposed,
	}


## 严格读取一个已存在存档并建立首次活动身份。
##
## missing/corrupt 不会应用低层 `ACTION_USE_CURRENT_STATE`；结果分别返回只能用于
## `bootstrap_profile()` 或 `adopt_profile()` 的类型化 Recovery Lease。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 已注册受管 Profile ID。
## [br]
## @param context: 迁移与 Provider apply 临时上下文。
## [br]
## @param metadata: 仅写入外层事务结果的调用方元数据。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @schema metadata: Dictionary with caller-defined result metadata.
## [br]
## @return 类型化 activate 操作。
func activate_profile(
	profile_id: StringName,
	context: Dictionary = {},
	metadata: Dictionary = {}
) -> GFSaveProfileTransactionOperation:
	var profile: ManagedProfile = _get_profile(profile_id)
	var domain: DomainState = _get_domain_for_profile(profile_id)
	var admission: Dictionary = _get_domain_admission_failure(domain)
	if profile == null or domain == null:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed Profile is not registered.",
			_STAGE_ACTIVATE_LOAD,
			metadata
		)
	if not admission.is_empty():
		return _reject_from_admission(
			GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
			&"",
			profile_id,
			admission,
			_STAGE_ACTIVATE_LOAD,
			metadata
		)
	if domain.active_profile_id != &"":
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_ALREADY_ACTIVE,
			ERR_ALREADY_IN_USE,
			"Provider domain already has an active Profile.",
			_STAGE_ACTIVATE_LOAD,
			metadata
		)
	if not profile.load_enabled:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Target Profile does not support load.",
			_STAGE_ACTIVATE_LOAD,
			metadata
		)
	var transaction: TransactionState = _begin_domain_transaction(
		domain,
		GFSaveProfileTransactionOperation.OPERATION_ACTIVATE,
		&"",
		profile_id,
		metadata
	)
	transaction.context = context.duplicate(true)
	transaction.stage = _STAGE_ACTIVATE_LOAD
	_start_strict_load(domain, transaction, profile_id)
	return transaction.operation


## 从当前活动 Profile 原子切换到同一 Provider domain 的目标 Profile。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param target_profile_id: 同一 domain 内的目标 Profile ID。
## [br]
## @param context: 目标读取的迁移与 Provider 临时上下文。
## [br]
## @param metadata: 仅写入外层事务结果的调用方元数据。
## [br]
## @schema context: Dictionary with caller-defined ephemeral operation data.
## [br]
## @schema metadata: Dictionary with caller-defined result metadata.
## [br]
## @return 类型化 switch 操作。
func switch_profile(
	target_profile_id: StringName,
	context: Dictionary = {},
	metadata: Dictionary = {}
) -> GFSaveProfileTransactionOperation:
	var target: ManagedProfile = _get_profile(target_profile_id)
	var domain: DomainState = _get_domain_for_profile(target_profile_id)
	var source_id: StringName = domain.active_profile_id if domain != null else &""
	var admission: Dictionary = _get_domain_admission_failure(domain)
	if target == null or domain == null:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			&"",
			target_profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed target Profile is not registered.",
			_STAGE_SOURCE_FLUSH,
			metadata
		)
	if not admission.is_empty():
		return _reject_from_admission(
			GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			source_id,
			target_profile_id,
			admission,
			_STAGE_SOURCE_FLUSH,
			metadata
		)
	if source_id == &"":
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			&"",
			target_profile_id,
			GFSaveProfileTransactionResult.STATUS_INACTIVE,
			ERR_UNCONFIGURED,
			"Provider domain has no active source Profile.",
			_STAGE_SOURCE_FLUSH,
			metadata
		)
	if source_id == target_profile_id:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			source_id,
			target_profile_id,
			GFSaveProfileTransactionResult.STATUS_ALREADY_ACTIVE,
			ERR_ALREADY_IN_USE,
			"Target Profile is already active.",
			_STAGE_SOURCE_FLUSH,
			metadata
		)
	var source: ManagedProfile = _get_profile(source_id)
	if source == null or not source.save_enabled or not target.load_enabled:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_SWITCH,
			source_id,
			target_profile_id,
			GFSaveProfileTransactionResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Source flush or target load capability is disabled.",
			_STAGE_SOURCE_FLUSH,
			metadata
		)
	var transaction: TransactionState = _begin_domain_transaction(
		domain,
		GFSaveProfileTransactionOperation.OPERATION_SWITCH,
		source_id,
		target_profile_id,
		metadata
	)
	transaction.context = context.duplicate(true)
	transaction.stage = _STAGE_SOURCE_FLUSH
	_start_flush(domain, transaction, source_id)
	return transaction.operation


## 使用 activate 返回的 missing lease 创建存档并首次激活。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param lease: 尚未过期的 missing Recovery Lease。
## [br]
## @param request: 当前 Provider 状态的保存请求；null 表示空元数据。
## [br]
## @return 类型化 bootstrap 操作；拒绝不会 claim lease 或 request。
func bootstrap_profile(
	lease: GFSaveProfileRecoveryLease,
	request: GFSaveProfileRequest = null
) -> GFSaveProfileTransactionOperation:
	return _start_recovery_save(
		GFSaveProfileTransactionOperation.OPERATION_BOOTSTRAP,
		GFSaveProfileRecoveryLease.REASON_MISSING,
		lease,
		request
	)


## 使用 activate 返回的 corrupt lease 明确覆盖损坏存档并首次激活。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param lease: 尚未过期的 corrupt Recovery Lease。
## [br]
## @param request: 当前 Provider 状态的保存请求；null 表示空元数据。
## [br]
## @return 类型化 adopt 操作；拒绝不会 claim lease 或 request。
func adopt_profile(
	lease: GFSaveProfileRecoveryLease,
	request: GFSaveProfileRequest = null
) -> GFSaveProfileTransactionOperation:
	return _start_recovery_save(
		GFSaveProfileTransactionOperation.OPERATION_ADOPT,
		GFSaveProfileRecoveryLease.REASON_CORRUPT,
		lease,
		request
	)


## 事务化应用一个或多个完整 section replacement 并持久化活动 Profile。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_id: 当前 domain 的活动 Profile ID。
## [br]
## @param request: 一次性候选与元数据请求。
## [br]
## @return 类型化 mutate-and-persist 操作；边界拒绝不会 claim request。
func mutate_and_persist(
	profile_id: StringName,
	request: GFSaveProfileMutationRequest
) -> GFSaveProfileTransactionOperation:
	var profile: ManagedProfile = _get_profile(profile_id)
	var domain: DomainState = _get_domain_for_profile(profile_id)
	var admission: Dictionary = _get_domain_admission_failure(domain)
	if profile == null or domain == null:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed Profile is not registered.",
			_STAGE_MUTATION_FLUSH
		)
	if not admission.is_empty():
		return _reject_from_admission(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			admission,
			_STAGE_MUTATION_FLUSH
		)
	if domain.active_profile_id != profile_id:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INACTIVE,
			ERR_UNCONFIGURED,
			"Mutation target is not the active Profile.",
			_STAGE_MUTATION_FLUSH
		)
	if not profile.save_enabled:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Mutation target does not support save.",
			_STAGE_MUTATION_FLUSH
		)
	var request_check: Dictionary = _validate_mutation_request(profile, request)
	if not GFVariantData.get_option_bool(request_check, "ok", false):
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_DATA,
			GFVariantData.get_option_string(
				request_check,
				"error",
				"Mutation request is invalid."
			),
			_STAGE_MUTATION_FLUSH
		)
	var claim: Dictionary = request.claim_for_framework()
	if claim.is_empty():
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_PARAMETER,
			"Mutation request could not be claimed.",
			_STAGE_MUTATION_FLUSH
		)
	var transaction: TransactionState = _begin_domain_transaction(
		domain,
		GFSaveProfileTransactionOperation.OPERATION_MUTATE_AND_PERSIST,
		profile_id,
		profile_id,
		_get_dictionary_claim(claim, "result_metadata")
	)
	transaction.context = _get_dictionary_claim(claim, "context")
	transaction.document_metadata = _get_dictionary_claim(claim, "document_metadata")
	transaction.mutation_records = _get_dictionary_array_claim(claim, "mutations")
	transaction.stage = _STAGE_MUTATION_FLUSH
	_start_flush(domain, transaction, profile_id)
	return transaction.operation


## 在 late generation 证据收敛后严格重载 lease 指定 Profile 并解除 fence。
##
## waiting lease 返回 `reconcile_pending`，且不 claim lease/request；调用方可在
## `GFSaveProfileReconcileLease.settled` 后用同一 lease 与新请求重试。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param lease: 当前 Coordinator 持有的 Reconcile Lease。
## [br]
## @param request: 一次性 reconcile context 与结果元数据。
## [br]
## @return 类型化 reconcile 操作。
func reconcile_profile(
	lease: GFSaveProfileReconcileLease,
	request: GFSaveProfileReconcileRequest = null
) -> GFSaveProfileTransactionOperation:
	var record: Dictionary = _get_reconcile_record(lease)
	var profile_id: StringName = (
		lease.get_reconcile_profile_id()
		if lease != null
		else &""
	)
	var domain: DomainState = (
		_get_domain(lease.get_domain_id())
		if lease != null
		else null
	)
	if record.is_empty() or domain == null or domain.reconcile_lease != lease:
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_LEASE,
			ERR_INVALID_PARAMETER,
			"Reconcile Lease is not owned by this Coordinator.",
			_STAGE_RECONCILE_LOAD
		)
	_refresh_reconcile_lease(domain, lease)
	if lease.is_waiting():
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_RECONCILE_PENDING,
			ERR_BUSY,
			"Detached write evidence has not reached a terminal state.",
			_STAGE_RECONCILE_LOAD,
			{},
			null,
			lease
		)
	var quiesce_continuation: bool = (
		not _disposed
		and not _dispose_requested
		and not _admission_open
		and _quiesce_completion != null
		and _quiesce_completion.is_pending()
	)
	if (
		(_disposed or _dispose_requested or not _admission_open)
			and not quiesce_continuation
		or _notification_depth > 0
		or domain.current_transaction != null
	):
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_BUSY,
			ERR_BUSY,
			"Provider domain is not accepting reconciliation.",
			_STAGE_RECONCILE_LOAD,
			{}
		)
	var owned_request: GFSaveProfileReconcileRequest = request
	if owned_request == null:
		owned_request = GFSaveProfileReconcileRequest.take_ownership({}, {})
	if owned_request == null or not owned_request.is_available():
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_PARAMETER,
			"Reconcile request is invalid or already claimed.",
			_STAGE_RECONCILE_LOAD,
			{}
		)
	var lease_claim: Dictionary = lease.claim_for_framework(
		profile_id,
		domain.domain_id,
		domain.domain_generation,
		domain.transaction_epoch
	)
	if lease_claim.is_empty():
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_LEASE,
			ERR_INVALID_PARAMETER,
			"Reconcile Lease fence no longer matches the Provider domain.",
			_STAGE_RECONCILE_LOAD,
			{}
		)
	var request_claim: Dictionary = owned_request.claim_for_framework()
	if request_claim.is_empty():
		var _released_lease: bool = lease.release_reconcile_for_framework()
		return _reject_transaction(
			GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
			profile_id,
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_PARAMETER,
			"Reconcile request could not be claimed.",
			_STAGE_RECONCILE_LOAD,
			{}
		)
	var transaction: TransactionState = _begin_reconcile_transaction(
		domain,
		lease,
		_get_dictionary_claim(request_claim, "result_metadata")
	)
	transaction.context = _get_dictionary_claim(request_claim, "context")
	transaction.stage = _STAGE_RECONCILE_LOAD
	_start_strict_load(domain, transaction, profile_id)
	return transaction.operation


# --- 私有/辅助方法（底层操作编排） ---

func _start_strict_load(
	domain: DomainState,
	transaction: TransactionState,
	profile_id: StringName
) -> void:
	var profile: ManagedProfile = _get_profile(profile_id)
	if profile == null or _profile_utility == null:
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed load target is unavailable.",
			transaction.stage
		)
		return
	var operation: GFSaveProfileOperation = (
		_profile_utility.load_profile_strict_for_manager_for_framework(
			profile_id,
			transaction.context,
			{},
			profile.permit
		)
	)
	_observe_profile_operation(domain, transaction, operation)


func _start_flush(
	domain: DomainState,
	transaction: TransactionState,
	profile_id: StringName
) -> void:
	var profile: ManagedProfile = _get_profile(profile_id)
	if profile == null or _profile_utility == null:
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed flush source is unavailable.",
			transaction.stage
		)
		return
	var operation: GFSaveProfileOperation = (
		_profile_utility.flush_profile_for_manager_for_framework(
			profile_id,
			{},
			profile.permit
		)
	)
	transaction.write_admitted = (
		operation != null
		and not operation.is_completed()
		and operation.get_requested_generation() > 0
	)
	_observe_profile_operation(domain, transaction, operation)


func _start_save(
	domain: DomainState,
	transaction: TransactionState,
	profile_id: StringName,
	request: GFSaveProfileRequest
) -> void:
	var profile: ManagedProfile = _get_profile(profile_id)
	if profile == null or _profile_utility == null:
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			ERR_DOES_NOT_EXIST,
			"Managed save target is unavailable.",
			transaction.stage
		)
		return
	var operation: GFSaveProfileOperation = (
		_profile_utility.save_profile_for_manager_for_framework(
			profile_id,
			request,
			profile.permit,
			transaction.mutation_candidates
		)
	)
	transaction.write_admitted = request != null and request.is_claimed()
	transaction.mutation_candidates.clear()
	_observe_profile_operation(domain, transaction, operation)


func _observe_profile_operation(
	domain: DomainState,
	transaction: TransactionState,
	operation: GFSaveProfileOperation
) -> void:
	if operation == null:
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_CANT_CREATE,
			"GFSaveProfileUtility returned no operation.",
			transaction.stage
		)
		return
	transaction.profile_operation = operation
	if operation.is_completed():
		_on_profile_operation_completed(
			operation.get_result(),
			domain.domain_id,
			transaction.operation.get_transaction_id()
		)
		return
	var callback: Callable = Callable(self, "_on_profile_operation_completed").bind(
		domain.domain_id,
		transaction.operation.get_transaction_id()
	)
	transaction.profile_callback = callback
	var _connected: Error = operation.completed.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


func _handle_activate_load_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var evidence: Dictionary = _make_profile_result_evidence(result)
	if result.is_successful() and result.get_status() == GFSaveProfileResult.STATUS_LOADED:
		_commit_active_profile(domain, transaction.target_profile_id)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_ACTIVATED,
			OK,
			"",
			_STAGE_ACTIVATE_LOAD,
			evidence
		)
		return
	if result.get_status() in [
		GFSaveProfileResult.STATUS_MISSING,
		GFSaveProfileResult.STATUS_CORRUPT,
	]:
		var reason: StringName = (
			GFSaveProfileRecoveryLease.REASON_MISSING
			if result.get_status() == GFSaveProfileResult.STATUS_MISSING
			else GFSaveProfileRecoveryLease.REASON_CORRUPT
		)
		var lease: GFSaveProfileRecoveryLease = _create_recovery_lease(
			domain,
			transaction,
			reason
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_RECOVERY_REQUIRED,
			result.get_error_code(),
			"Explicit Bootstrap or Adopt is required before activation.",
			_STAGE_ACTIVATE_LOAD,
			evidence,
			[],
			lease
		)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_ROLLBACK_FAILED:
		var reconcile: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.target_profile_id,
			result,
			true
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED,
			result.get_error_code(),
			result.get_error(),
			_STAGE_ACTIVATE_LOAD,
			evidence,
			result.get_rollback_errors(),
			null,
			reconcile
		)
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_TARGET_LOAD_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_ACTIVATE_LOAD,
		evidence,
		result.get_rollback_errors()
	)


func _handle_switch_flush_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var evidence: Dictionary = _make_profile_result_evidence(result)
	if result.is_successful():
		transaction.stage_evidence["source_flush"] = evidence
		transaction.stage = _STAGE_TARGET_LOAD
		_start_strict_load(domain, transaction, transaction.target_profile_id)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN:
		var lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.source_profile_id,
			result
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN,
			result.get_error_code(),
			result.get_error(),
			_STAGE_SOURCE_FLUSH,
			evidence,
			[],
			null,
			lease
		)
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_SOURCE_FLUSH_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_SOURCE_FLUSH,
		evidence
	)


func _handle_switch_target_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var evidence: Dictionary = {
		"source_flush": GFVariantData.get_option_dictionary(
			transaction.stage_evidence,
			"source_flush"
		),
		"target_load": _make_profile_result_evidence(result),
	}
	if result.is_successful() and result.get_status() == GFSaveProfileResult.STATUS_LOADED:
		_commit_active_profile(domain, transaction.target_profile_id)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_SWITCHED,
			OK,
			"",
			_STAGE_TARGET_LOAD,
			evidence
		)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_ROLLBACK_FAILED:
		var lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.source_profile_id,
			result,
			true
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED,
			result.get_error_code(),
			result.get_error(),
			_STAGE_TARGET_LOAD,
			evidence,
			result.get_rollback_errors(),
			null,
			lease
		)
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_TARGET_LOAD_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_TARGET_LOAD,
		evidence,
		result.get_rollback_errors()
	)


func _handle_recovery_save_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	transaction.result_metadata = result.get_metadata()
	var evidence: Dictionary = _make_profile_result_evidence(result)
	if result.is_successful():
		_commit_active_profile(domain, transaction.target_profile_id)
		var status: StringName = (
			GFSaveProfileTransactionResult.STATUS_BOOTSTRAPPED
			if transaction.operation.get_operation()
				== GFSaveProfileTransactionOperation.OPERATION_BOOTSTRAP
			else GFSaveProfileTransactionResult.STATUS_ADOPTED
		)
		_finish_domain_transaction(
			domain,
			transaction,
			status,
			OK,
			"",
			_STAGE_RECOVERY_SAVE,
			evidence
		)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN:
		var lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.target_profile_id,
			result
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN,
			result.get_error_code(),
			result.get_error(),
			_STAGE_RECOVERY_SAVE,
			evidence,
			[],
			null,
			lease
		)
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_RECOVERY_SAVE,
		evidence
	)


func _handle_mutation_flush_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var evidence: Dictionary = _make_profile_result_evidence(result)
	if result.is_successful():
		transaction.stage_evidence["flush"] = evidence
		transaction.stage = _STAGE_MUTATION_QUEUED
		_enqueue_domain_tick(domain)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN:
		var lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.source_profile_id,
			result
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN,
			result.get_error_code(),
			result.get_error(),
			_STAGE_MUTATION_FLUSH,
			evidence,
			[],
			null,
			lease
		)
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_MUTATION_FLUSH,
		evidence
	)


func _apply_mutation_candidates(
	domain: DomainState,
	transaction: TransactionState
) -> void:
	if (
		domain.current_transaction != transaction
		or transaction.stage != _STAGE_MUTATION_QUEUED
	):
		return
	transaction.stage = _STAGE_MUTATION_APPLY
	_begin_processing()
	var candidates: Array[GFSaveSection] = []
	for record: Dictionary in transaction.mutation_records:
		var section_id: StringName = GFVariantData.get_option_string_name(
			record,
			"section_id"
		)
		var schema_version: int = GFVariantData.get_option_int(record, "schema_version")
		var metadata: Dictionary = GFVariantData.get_option_dictionary(record, "metadata")
		var candidate: GFSaveSection = GFSaveSection.new().configure(
			section_id,
			schema_version,
			GFVariantData.get_option_value(record, "payload"),
			metadata
		)
		candidates.append(candidate)
		record.clear()
	transaction.mutation_records.clear()
	var profile: ManagedProfile = _get_profile(transaction.target_profile_id)
	var apply_result: Dictionary = (
		_profile_utility.apply_profile_candidates_for_manager_for_framework(
			transaction.target_profile_id,
			candidates,
			transaction.context,
			profile.permit if profile != null else null
		)
		if _profile_utility != null
		else {}
	)
	if not GFVariantData.get_option_bool(apply_result, "ok", false):
		candidates.clear()
		var rollback_errors: Array[GFSaveRollbackFailure] = _read_rollback_errors(
			GFVariantData.get_option_value(apply_result, "rollback_errors", [])
		)
		var failure_stage: StringName = GFVariantData.get_option_string_name(
			apply_result,
			"failure_stage"
		)
		var status: StringName = (
			GFSaveProfileTransactionResult.STATUS_SNAPSHOT_FAILED
			if failure_stage == &"snapshot"
			else GFSaveProfileTransactionResult.STATUS_APPLY_FAILED
		)
		var lease: GFSaveProfileReconcileLease = null
		if not rollback_errors.is_empty():
			status = GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED
			lease = _create_reconcile_fence(
				domain,
				transaction,
				transaction.target_profile_id,
				null,
				true
			)
		transaction.forced_rollback_errors = rollback_errors
		_finish_domain_transaction(
			domain,
			transaction,
			status,
			_get_error_code(apply_result, "error_code", ERR_INVALID_DATA),
			GFVariantData.get_option_string(
				apply_result,
				"error",
				"Mutation candidate apply failed."
			),
			_STAGE_MUTATION_APPLY,
			{
				"failure_stage": failure_stage,
				"failed_section_id": GFVariantData.get_option_string_name(
					apply_result,
					"failed_section_id"
				),
			},
			rollback_errors,
			null,
			lease,
			GFVariantData.get_option_string_name(apply_result, "failed_section_id")
		)
		_end_processing()
		return
	var provider_ids: PackedStringArray = _get_packed_string_array(
		GFVariantData.get_option_value(apply_result, "provider_ids")
	)
	var snapshots: Dictionary = GFVariantData.get_option_dictionary(
		apply_result,
		"snapshots"
	)
	if _dispose_requested:
		transaction.forced_rollback_errors = (
			_profile_utility.rollback_profile_candidates_for_manager_for_framework(
				transaction.target_profile_id,
				provider_ids,
				snapshots,
				transaction.context,
				profile.permit if profile != null else null
			)
			if _profile_utility != null
			else _make_management_rollback_failures(provider_ids)
		)
		candidates.clear()
		snapshots.clear()
		_end_processing()
		return
	transaction.mutation_provider_ids = provider_ids
	transaction.mutation_snapshots = snapshots
	transaction.mutation_candidates = candidates
	var save_request: GFSaveProfileRequest = GFSaveProfileRequest.take_ownership(
		transaction.document_metadata,
		transaction.context.duplicate(true),
		{}
	)
	transaction.document_metadata = {}
	_end_processing()
	if transaction.operation.is_completed():
		return
	transaction.stage = _STAGE_MUTATION_SAVE
	_start_save(domain, transaction, transaction.target_profile_id, save_request)


func _handle_mutation_save_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var evidence: Dictionary = {
		"flush": GFVariantData.get_option_dictionary(
			transaction.stage_evidence,
			"flush"
		),
		"save": _make_profile_result_evidence(result),
	}
	if result.is_successful():
		transaction.mutation_snapshots.clear()
		transaction.mutation_provider_ids = PackedStringArray()
		domain.domain_generation += 1
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_MUTATED,
			OK,
			"",
			_STAGE_MUTATION_SAVE,
			evidence
		)
		return
	if result.get_status() == GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN:
		transaction.mutation_snapshots.clear()
		transaction.mutation_provider_ids = PackedStringArray()
		var unknown_lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.target_profile_id,
			result
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN,
			result.get_error_code(),
			result.get_error(),
			_STAGE_MUTATION_SAVE,
			evidence,
			[],
			null,
			unknown_lease
		)
		return
	_begin_processing()
	var profile: ManagedProfile = _get_profile(transaction.target_profile_id)
	var rollback_errors: Array[GFSaveRollbackFailure] = (
		_profile_utility.rollback_profile_candidates_for_manager_for_framework(
			transaction.target_profile_id,
			transaction.mutation_provider_ids,
			transaction.mutation_snapshots,
			transaction.context,
			profile.permit if profile != null else null
		)
		if _profile_utility != null
		else _make_management_rollback_failures(
			transaction.mutation_provider_ids
		)
	)
	transaction.mutation_snapshots.clear()
	transaction.mutation_provider_ids = PackedStringArray()
	if not rollback_errors.is_empty():
		var rollback_lease: GFSaveProfileReconcileLease = _create_reconcile_fence(
			domain,
			transaction,
			transaction.target_profile_id,
			result,
			true
		)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_ROLLBACK_FAILED,
			result.get_error_code(),
			"Mutation persistence failed and runtime rollback was incomplete.",
			_STAGE_MUTATION_SAVE,
			evidence,
			rollback_errors,
			null,
			rollback_lease
		)
		_end_processing()
		return
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_PERSIST_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_MUTATION_SAVE,
		evidence
	)
	_end_processing()


func _handle_reconcile_load_result(
	domain: DomainState,
	transaction: TransactionState,
	result: GFSaveProfileResult
) -> void:
	var lease: GFSaveProfileReconcileLease = transaction.reconcile_lease
	var evidence: Dictionary = _make_profile_result_evidence(result)
	if result.is_successful() and result.get_status() == GFSaveProfileResult.STATUS_LOADED:
		var previous: StringName = domain.active_profile_id
		domain.active_profile_id = transaction.target_profile_id
		domain.domain_generation += 1
		var _resolved: bool = lease.mark_resolved_for_framework({
			"state": &"reloaded",
			"profile_id": transaction.target_profile_id,
			"profile_result": evidence,
		})
		var _record_erased: bool = _reconcile_records.erase(lease.get_lease_id())
		domain.reconcile_lease = null
		if previous != domain.active_profile_id:
			_emit_active_profile_changed(previous, domain.active_profile_id)
		_finish_domain_transaction(
			domain,
			transaction,
			GFSaveProfileTransactionResult.STATUS_RECONCILED,
			OK,
			"",
			_STAGE_RECONCILE_LOAD,
			evidence,
			[],
			null,
			lease
		)
		return
	var _released: bool = lease.release_reconcile_for_framework()
	_finish_domain_transaction(
		domain,
		transaction,
		GFSaveProfileTransactionResult.STATUS_RECONCILE_FAILED,
		result.get_error_code(),
		result.get_error(),
		_STAGE_RECONCILE_LOAD,
		evidence,
		result.get_rollback_errors(),
		null,
		lease
	)


# --- 私有/辅助方法（事务建立与终态） ---

func _start_recovery_save(
	operation_kind: StringName,
	expected_reason: StringName,
	lease: GFSaveProfileRecoveryLease,
	request: GFSaveProfileRequest
) -> GFSaveProfileTransactionOperation:
	var profile_id: StringName = lease.get_profile_id() if lease != null else &""
	var profile: ManagedProfile = _get_profile(profile_id)
	var domain: DomainState = _get_domain_for_profile(profile_id)
	var record: Dictionary = _get_recovery_record(lease)
	if (
		lease == null
		or record.is_empty()
		or profile == null
		or domain == null
		or lease.get_reason() != expected_reason
		or not lease.is_available()
	):
		return _reject_transaction(
			operation_kind,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_LEASE,
			ERR_INVALID_PARAMETER,
			"Recovery Lease is invalid, stale, or has the wrong recovery reason.",
			_STAGE_RECOVERY_SAVE
		)
	var admission: Dictionary = _get_domain_admission_failure(domain)
	if not admission.is_empty():
		return _reject_from_admission(
			operation_kind,
			&"",
			profile_id,
			admission,
			_STAGE_RECOVERY_SAVE
		)
	if domain.active_profile_id != &"":
		return _reject_transaction(
			operation_kind,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_ALREADY_ACTIVE,
			ERR_ALREADY_IN_USE,
			"Provider domain already has an active Profile.",
			_STAGE_RECOVERY_SAVE
		)
	if not profile.save_enabled:
		return _reject_transaction(
			operation_kind,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_UNSUPPORTED_OPERATION,
			ERR_UNAVAILABLE,
			"Recovery target does not support save.",
			_STAGE_RECOVERY_SAVE
		)
	if request != null and not request.is_available_for_framework():
		return _reject_transaction(
			operation_kind,
			&"",
			profile_id,
			GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
			ERR_INVALID_PARAMETER,
			"Recovery save request is uninitialized or was already claimed.",
			_STAGE_RECOVERY_SAVE
		)
	var owned_request: GFSaveProfileRequest = request
	if owned_request == null:
		owned_request = GFSaveProfileRequest.take_ownership({}, {}, {})
	_begin_processing()
	var profile_operation: GFSaveProfileOperation = (
		_profile_utility.save_profile_for_manager_for_framework(
			profile_id,
			owned_request,
			profile.permit
		)
		if _profile_utility != null
		else null
	)
	var save_admitted: bool = (
		profile_operation != null
		and owned_request.is_claimed()
		and profile_operation.get_requested_generation() > 0
	)
	if not save_admitted:
		var rejected_operation: GFSaveProfileTransactionOperation = (
			_reject_recovery_save_admission(
				operation_kind,
				profile_id,
				profile_operation
			)
		)
		_end_processing()
		return rejected_operation
	var lease_claim: Dictionary = lease.claim_for_framework(
		profile_id,
		domain.domain_id,
		domain.domain_generation,
		domain.transaction_epoch
	)
	# 底层成功准入只会同步 claim request 与入队，不会执行 Provider 或开放回调；
	# 因此同一调用栈内、同一 recovery record 的 Lease claim 失败属于内部不变量破坏。
	if lease_claim.is_empty():
		push_error(
			"[GFSaveProfileTransactionCoordinator] Admitted recovery lease could not commit."
		)
	var _record_erased: bool = _recovery_records.erase(lease.get_lease_id())
	var transaction: TransactionState = _begin_domain_transaction(
		domain,
		operation_kind,
		&"",
		profile_id,
		{}
	)
	transaction.stage = _STAGE_RECOVERY_SAVE
	transaction.write_admitted = true
	_observe_profile_operation(domain, transaction, profile_operation)
	_end_processing()
	return transaction.operation


func _reject_recovery_save_admission(
	operation_kind: StringName,
	profile_id: StringName,
	profile_operation: GFSaveProfileOperation
) -> GFSaveProfileTransactionOperation:
	var status: StringName = GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST
	var error_code: Error = ERR_CANT_CREATE
	var error: String = "GFSaveProfileUtility did not admit the recovery save."
	var result: GFSaveProfileResult = (
		profile_operation.get_result()
		if profile_operation != null and profile_operation.is_completed()
		else null
	)
	if result != null:
		error_code = result.get_error_code()
		error = result.get_error()
		match result.get_status():
			GFSaveProfileResult.STATUS_BUSY:
				status = GFSaveProfileTransactionResult.STATUS_BUSY
			GFSaveProfileResult.STATUS_INVALID_PROFILE:
				status = GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE
			GFSaveProfileResult.STATUS_UNSUPPORTED_OPERATION:
				status = GFSaveProfileTransactionResult.STATUS_UNSUPPORTED_OPERATION
			GFSaveProfileResult.STATUS_DISPOSED:
				status = GFSaveProfileTransactionResult.STATUS_DISPOSED
			_:
				status = GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST
	return _reject_transaction(
		operation_kind,
		&"",
		profile_id,
		status,
		error_code,
		error,
		_STAGE_RECOVERY_SAVE
	)


func _begin_domain_transaction(
	domain: DomainState,
	operation_kind: StringName,
	source_profile_id: StringName,
	target_profile_id: StringName,
	metadata: Dictionary
) -> TransactionState:
	_invalidate_recovery_leases(domain)
	domain.transaction_epoch += 1
	var transaction: TransactionState = _make_transaction_state(
		operation_kind,
		source_profile_id,
		target_profile_id,
		domain.active_profile_id,
		metadata
	)
	domain.current_transaction = transaction
	domain.state = DOMAIN_STATE_TRANSACTING
	_update_domain_managed_access(domain)
	return transaction


func _begin_reconcile_transaction(
	domain: DomainState,
	lease: GFSaveProfileReconcileLease,
	metadata: Dictionary
) -> TransactionState:
	var profile_id: StringName = lease.get_reconcile_profile_id()
	var transaction: TransactionState = _make_transaction_state(
		GFSaveProfileTransactionOperation.OPERATION_RECONCILE,
		profile_id,
		profile_id,
		domain.active_profile_id,
		metadata
	)
	transaction.reconcile_lease = lease
	domain.current_transaction = transaction
	domain.state = DOMAIN_STATE_TRANSACTING
	_update_domain_managed_access(domain)
	return transaction


func _make_transaction_state(
	operation_kind: StringName,
	source_profile_id: StringName,
	target_profile_id: StringName,
	active_profile_before: StringName,
	metadata: Dictionary
) -> TransactionState:
	var transaction: TransactionState = TransactionState.new()
	var operation: GFSaveProfileTransactionOperation = (
		GFSaveProfileTransactionOperation.new()
	)
	var transaction_id: int = _next_transaction_id
	_next_transaction_id += 1
	var started_at_msec: int = Time.get_ticks_msec()
	var _configured: bool = operation.configure_for_framework(
		operation_kind,
		transaction_id,
		source_profile_id,
		target_profile_id,
		started_at_msec
	)
	var _started: bool = operation.start_for_framework()
	transaction.operation = operation
	transaction.source_profile_id = source_profile_id
	transaction.target_profile_id = target_profile_id
	transaction.active_profile_before = active_profile_before
	transaction.result_metadata = metadata.duplicate(true)
	return transaction


func _finish_domain_transaction(
	domain: DomainState,
	transaction: TransactionState,
	status: StringName,
	error_code: Error,
	error: String,
	phase: StringName,
	stage_evidence: Dictionary = {},
	rollback_errors: Array[GFSaveRollbackFailure] = [],
	recovery_lease: GFSaveProfileRecoveryLease = null,
	reconcile_lease: GFSaveProfileReconcileLease = null,
	failed_section_id: StringName = &""
) -> void:
	if transaction == null or transaction.operation == null:
		return
	if transaction.operation.is_completed():
		return
	var active_after: StringName = (
		domain.active_profile_id
		if domain != null
		else transaction.active_profile_before
	)
	var result: GFSaveProfileTransactionResult = GFSaveProfileTransactionResult.new()
	var configured: bool = result.configure_for_framework({
		"status": status,
		"operation": transaction.operation.get_operation(),
		"transaction_id": transaction.operation.get_transaction_id(),
		"source_profile_id": transaction.source_profile_id,
		"target_profile_id": transaction.target_profile_id,
		"active_profile_before": transaction.active_profile_before,
		"active_profile_after": active_after,
		"phase": phase,
		"error_code": int(error_code),
		"error": error,
		"failed_section_id": failed_section_id,
		"rollback_errors": rollback_errors,
		"stage_evidence": stage_evidence,
		"recovery_lease": recovery_lease,
		"reconcile_lease": reconcile_lease,
		"metadata": transaction.result_metadata,
		"started_at_msec": transaction.operation.get_started_at_msec_for_framework(),
		"completed_at_msec": Time.get_ticks_msec(),
	})
	if not configured:
		push_error("[GFSaveProfileTransactionCoordinator] Invalid terminal result contract.")
		result = GFSaveProfileTransactionResult.new()
		configured = result.configure_for_framework({
			"status": GFSaveProfileTransactionResult.STATUS_DISPOSED,
			"operation": transaction.operation.get_operation(),
			"transaction_id": transaction.operation.get_transaction_id(),
			"source_profile_id": transaction.source_profile_id,
			"target_profile_id": transaction.target_profile_id,
			"active_profile_before": transaction.active_profile_before,
			"active_profile_after": active_after,
			"phase": &"terminal_contract",
			"error_code": int(ERR_BUG),
			"error": "Transaction terminal contract validation failed.",
			"failed_section_id": &"",
			"rollback_errors": [],
			"stage_evidence": {},
			"recovery_lease": null,
			"reconcile_lease": reconcile_lease,
			"metadata": {},
			"started_at_msec": (
				transaction.operation.get_started_at_msec_for_framework()
			),
			"completed_at_msec": Time.get_ticks_msec(),
		})
	if not configured:
		push_error(
			"[GFSaveProfileTransactionCoordinator] Fallback terminal contract failed."
		)
		return
	if domain != null and domain.current_transaction == transaction:
		domain.current_transaction = null
		domain.pending_tick = false
		domain.state = (
			DOMAIN_STATE_RECONCILIATION_REQUIRED
			if domain.reconcile_lease != null
			else (
				DOMAIN_STATE_ACTIVE
				if domain.active_profile_id != &""
				else DOMAIN_STATE_INACTIVE
			)
		)
		_update_domain_managed_access(domain)
	_disconnect_transaction_profile_operation(transaction)
	transaction.clear_payload_for_framework()
	var completed: bool = transaction.operation.complete_for_framework(result)
	if completed:
		_notification_depth += 1
		transaction_completed.emit(result.duplicate_result())
		var _emitted: bool = transaction.operation.emit_completed_for_framework()
		_notification_depth -= 1
	if _dispose_requested and _processing_depth == 0 and _notification_depth == 0:
		_dispose_now()
		return
	_try_complete_quiesce()


func _reject_transaction(
	operation_kind: StringName,
	source_profile_id: StringName,
	target_profile_id: StringName,
	status: StringName,
	error_code: Error,
	error: String,
	phase: StringName,
	metadata: Dictionary = {},
	recovery_lease: GFSaveProfileRecoveryLease = null,
	reconcile_lease: GFSaveProfileReconcileLease = null
) -> GFSaveProfileTransactionOperation:
	var domain: DomainState = _get_domain_for_profile(target_profile_id)
	if domain == null:
		domain = _get_domain_for_profile(source_profile_id)
	var active_before: StringName = domain.active_profile_id if domain != null else &""
	var transaction: TransactionState = _make_transaction_state(
		operation_kind,
		source_profile_id,
		target_profile_id,
		active_before,
		metadata
	)
	_finish_domain_transaction(
		null,
		transaction,
		status,
		error_code,
		error,
		phase,
		{},
		[],
		recovery_lease,
		reconcile_lease
	)
	return transaction.operation


func _reject_from_admission(
	operation_kind: StringName,
	source_profile_id: StringName,
	target_profile_id: StringName,
	admission: Dictionary,
	phase: StringName,
	metadata: Dictionary = {}
) -> GFSaveProfileTransactionOperation:
	return _reject_transaction(
		operation_kind,
		source_profile_id,
		target_profile_id,
		GFVariantData.get_option_string_name(
			admission,
			"status",
			GFSaveProfileTransactionResult.STATUS_BUSY
		),
		_get_error_code(admission, "error_code", ERR_BUSY),
		GFVariantData.get_option_string(
			admission,
			"error",
			"Provider domain is busy."
		),
		phase,
		metadata
	)


# --- 私有/辅助方法（Domain 与 Lease 管理） ---

func _commit_active_profile(domain: DomainState, profile_id: StringName) -> void:
	if domain == null or domain.active_profile_id == profile_id:
		return
	var previous_profile_id: StringName = domain.active_profile_id
	domain.active_profile_id = profile_id
	domain.domain_generation += 1
	_invalidate_recovery_leases(domain)
	_emit_active_profile_changed(previous_profile_id, profile_id)


func _emit_active_profile_changed(
	previous_profile_id: StringName,
	current_profile_id: StringName
) -> void:
	_notification_depth += 1
	active_profile_changed.emit(previous_profile_id, current_profile_id)
	_notification_depth -= 1


func _create_recovery_lease(
	domain: DomainState,
	transaction: TransactionState,
	reason: StringName
) -> GFSaveProfileRecoveryLease:
	var lease: GFSaveProfileRecoveryLease = GFSaveProfileRecoveryLease.new()
	var configured: bool = lease.configure_for_framework(
		_next_lease_id,
		transaction.operation.get_transaction_id(),
		transaction.target_profile_id,
		reason,
		domain.domain_id,
		domain.domain_generation,
		domain.transaction_epoch
	)
	if not configured:
		return null
	_next_lease_id += 1
	_recovery_records[lease.get_lease_id()] = {
		"lease": lease,
		"domain_id": domain.domain_id,
		"reason": reason,
	}
	return lease


func _create_reconcile_fence(
	domain: DomainState,
	transaction: TransactionState,
	profile_id: StringName,
	profile_result: GFSaveProfileResult = null,
	force_ready: bool = false
) -> GFSaveProfileReconcileLease:
	if domain == null or transaction == null or profile_id == &"":
		return null
	var request_ids: PackedInt64Array = PackedInt64Array()
	var generation: int = 0
	if profile_result != null:
		request_ids = profile_result.get_storage_request_ids()
		generation = profile_result.get_requested_generation()
	elif transaction.profile_operation != null:
		generation = transaction.profile_operation.get_requested_generation()
	var initial_evidence: Dictionary = {}
	if _profile_utility != null and generation > 0:
		initial_evidence = _profile_utility.get_generation_evidence_for_framework(
			profile_id,
			generation
		)
		if request_ids.is_empty():
			request_ids = _get_int64_array(
				GFVariantData.get_option_value(
					initial_evidence,
					"storage_request_ids"
				)
			)
	var lease: GFSaveProfileReconcileLease = GFSaveProfileReconcileLease.new()
	var configured: bool = lease.configure_for_framework(
		_next_lease_id,
		transaction.operation.get_transaction_id(),
		transaction.operation.get_operation(),
		profile_id,
		transaction.source_profile_id,
		transaction.target_profile_id,
		domain.domain_id,
		domain.domain_generation,
		domain.transaction_epoch,
		request_ids
	)
	if not configured:
		return null
	_next_lease_id += 1
	domain.reconcile_lease = lease
	domain.state = DOMAIN_STATE_RECONCILIATION_REQUIRED
	_reconcile_records[lease.get_lease_id()] = {
		"lease": lease,
		"domain_id": domain.domain_id,
		"profile_id": profile_id,
		"generation": generation,
	}
	_update_domain_managed_access(domain)
	if force_ready:
		var _marked_memory_ready: bool = _mark_reconcile_ready(lease, {
			"state": &"memory_state_uncertain",
			"profile_id": profile_id,
			"generation": generation,
		})
	else:
		_refresh_reconcile_lease(domain, lease)
	return lease


func _refresh_reconcile_lease(
	domain: DomainState,
	lease: GFSaveProfileReconcileLease
) -> void:
	if (
		domain == null
		or lease == null
		or not lease.is_waiting()
		or domain.reconcile_lease != lease
	):
		return
	var record: Dictionary = _get_reconcile_record(lease)
	if record.is_empty():
		return
	var profile_id: StringName = GFVariantData.get_option_string_name(
		record,
		"profile_id"
	)
	var generation: int = GFVariantData.get_option_int(record, "generation")
	if generation <= 0 or _profile_utility == null:
		return
	var evidence: Dictionary = _profile_utility.get_generation_evidence_for_framework(
		profile_id,
		generation
	)
	var evidence_state: StringName = GFVariantData.get_option_string_name(
		evidence,
		"state"
	)
	if evidence_state not in [&"persisted", &"failed", &"unresolved"]:
		return
	var _marked_ready: bool = _mark_reconcile_ready(lease, evidence)


func _mark_reconcile_ready(
	lease: GFSaveProfileReconcileLease,
	evidence: Dictionary
) -> bool:
	if lease == null:
		return false
	_notification_depth += 1
	var marked: bool = lease.mark_ready_for_framework(evidence)
	_notification_depth -= 1
	return marked


func _mark_reconcile_disposed(
	lease: GFSaveProfileReconcileLease
) -> bool:
	if lease == null:
		return false
	_notification_depth += 1
	var marked: bool = lease.mark_disposed_unresolved_for_framework()
	_notification_depth -= 1
	return marked


func _invalidate_recovery_leases(domain: DomainState) -> void:
	if domain == null:
		return
	var stale_ids: PackedInt64Array = PackedInt64Array()
	for lease_id_value: Variant in _recovery_records.keys():
		if typeof(lease_id_value) != TYPE_INT:
			continue
		var lease_id: int = lease_id_value
		var record: Dictionary = GFVariantData.as_dictionary(
			GFVariantData.get_option_value(_recovery_records, lease_id)
		)
		if GFVariantData.get_option_int(record, "domain_id") != domain.domain_id:
			continue
		var lease_value: Variant = GFVariantData.get_option_value(record, "lease")
		if lease_value is GFSaveProfileRecoveryLease:
			var lease: GFSaveProfileRecoveryLease = lease_value
			var _marked_stale: bool = lease.mark_stale_for_framework()
		var _appended: bool = stale_ids.append(lease_id)
	for lease_id: int in stale_ids:
		var _erased: bool = _recovery_records.erase(lease_id)


func _get_recovery_record(lease: GFSaveProfileRecoveryLease) -> Dictionary:
	if lease == null:
		return {}
	var record: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(_recovery_records, lease.get_lease_id())
	)
	return record if GFVariantData.get_option_value(record, "lease") == lease else {}


func _get_reconcile_record(lease: GFSaveProfileReconcileLease) -> Dictionary:
	if lease == null:
		return {}
	var record: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(_reconcile_records, lease.get_lease_id())
	)
	return record if GFVariantData.get_option_value(record, "lease") == lease else {}


func _get_domain_admission_failure(domain: DomainState) -> Dictionary:
	if domain == null:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_INVALID_PROFILE,
			"error_code": int(ERR_DOES_NOT_EXIST),
			"error": "Managed Provider domain does not exist.",
		}
	if _disposed:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_DISPOSED,
			"error_code": int(ERR_UNAVAILABLE),
			"error": "Save Profile transaction coordinator is disposed.",
		}
	if not _admission_open:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_BUSY,
			"error_code": int(ERR_BUSY),
			"error": "Save Profile transaction coordinator is quiescing.",
		}
	if _notification_depth > 0:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_BUSY,
			"error_code": int(ERR_BUSY),
			"error": "Reentrant transaction admission is not allowed from a callback.",
		}
	if domain.current_transaction != null:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_BUSY,
			"error_code": int(ERR_BUSY),
			"error": "Provider domain already has a running transaction.",
		}
	if domain.reconcile_lease != null:
		return {
			"status": GFSaveProfileTransactionResult.STATUS_BUSY,
			"error_code": int(ERR_BUSY),
			"error": "Provider domain requires explicit reconciliation.",
		}
	return {}


func _inspect_registration_topology(
	providers: Array[GFSaveSectionProvider]
) -> Dictionary:
	var provider_instance_ids: PackedInt64Array = PackedInt64Array()
	for provider: GFSaveSectionProvider in providers:
		if provider == null:
			return {
				"ok": false,
				"kind": &"invalid_provider_topology",
				"error": "Provider topology cannot contain a null Provider.",
			}
		var instance_id: int = provider.get_instance_id()
		if instance_id == 0:
			return {
				"ok": false,
				"kind": &"invalid_provider_topology",
				"error": "Provider topology contains an invalid instance identity.",
			}
		var _appended: bool = provider_instance_ids.append(instance_id)
	var matching_domain_id: int = 0
	for domain_value: Variant in _domains.values():
		var domain: DomainState = _get_domain_value(domain_value)
		if domain == null:
			continue
		if _int64_arrays_equal(
			domain.provider_instance_ids,
			provider_instance_ids
		):
			matching_domain_id = domain.domain_id
			continue
		if _int64_arrays_overlap(
			domain.provider_instance_ids,
			provider_instance_ids
		):
			return {
				"ok": false,
				"kind": &"overlapping_provider_domain",
				"error": (
					"Provider instances overlap an existing domain without an exact "
					+ "ordered topology match."
				),
			}
	return {
		"ok": true,
		"matching_domain_id": matching_domain_id,
		"provider_instance_ids": provider_instance_ids,
	}


func _attach_profile_to_domain(
	profile_id: StringName,
	descriptor: Dictionary,
	permit: RefCounted,
	matching_domain_id: int
) -> DomainState:
	if profile_id == &"" or permit == null or _profiles.has(profile_id):
		return null
	var providers: Array[GFSaveSectionProvider] = _read_providers(
		GFVariantData.get_option_value(descriptor, "providers")
	)
	if providers.is_empty():
		return null
	var domain: DomainState = _get_domain(matching_domain_id)
	if domain == null:
		domain = DomainState.new()
		domain.domain_id = _next_domain_id
		_next_domain_id += 1
		for provider: GFSaveSectionProvider in providers:
			var instance_id: int = provider.get_instance_id()
			var _appended_id: bool = domain.provider_instance_ids.append(instance_id)
		_domains[domain.domain_id] = domain
	var profile: ManagedProfile = ManagedProfile.new()
	profile.profile_id = profile_id
	profile.schema_id = GFVariantData.get_option_string_name(descriptor, "schema_id")
	profile.schema_version = GFVariantData.get_option_int(descriptor, "schema_version")
	profile.save_enabled = GFVariantData.get_option_bool(descriptor, "save_enabled")
	profile.load_enabled = GFVariantData.get_option_bool(descriptor, "load_enabled")
	profile.providers = providers
	profile.permit = permit
	profile.domain_id = domain.domain_id
	domain.profile_ids.append(profile_id)
	_profiles[profile_id] = profile
	_domain_id_by_profile[profile_id] = domain.domain_id
	_update_domain_managed_access(domain)
	return domain


func _validate_mutation_request(
	profile: ManagedProfile,
	request: GFSaveProfileMutationRequest
) -> Dictionary:
	if profile == null or request == null:
		return {"ok": false, "error": "Mutation request is required."}
	var inspection: Dictionary = request.inspect_for_framework()
	if not GFVariantData.get_option_bool(inspection, "available", false):
		return {"ok": false, "error": "Mutation request is not available."}
	var descriptors: Array = GFVariantData.get_option_array(inspection, "mutations")
	if descriptors.is_empty():
		return {"ok": false, "error": "Mutation request must contain a section."}
	var provider_by_id: Dictionary = {}
	for provider: GFSaveSectionProvider in profile.providers:
		if provider != null:
			provider_by_id[provider.section_id] = provider
	var seen_ids: Dictionary = {}
	for descriptor_value: Variant in descriptors:
		var descriptor: Dictionary = GFVariantData.as_dictionary(descriptor_value)
		var section_id: StringName = GFVariantData.get_option_string_name(
			descriptor,
			"section_id"
		)
		if section_id == &"" or seen_ids.has(section_id):
			return {
				"ok": false,
				"error": "Mutation section IDs must be non-empty and unique.",
			}
		seen_ids[section_id] = true
		var provider_value: Variant = GFVariantData.get_option_value(
			provider_by_id,
			section_id
		)
		if not provider_value is GFSaveSectionProvider:
			return {
				"ok": false,
				"error": "Mutation section is not owned by the target Profile.",
			}
		var provider: GFSaveSectionProvider = provider_value
		if (
			not provider.save_enabled
			or not provider.load_enabled
			or provider.schema_version
				!= GFVariantData.get_option_int(descriptor, "schema_version")
		):
			return {
				"ok": false,
				"error": (
					"Mutation section must match a readable and writable Provider schema."
				),
			}
	return {"ok": true}


func _update_domain_managed_access(domain: DomainState) -> void:
	if domain == null or _profile_utility == null:
		return
	var allow_active_direct_operations: bool = (
		_admission_open
		and not _disposed
		and not _dispose_requested
		and domain.state == DOMAIN_STATE_ACTIVE
		and domain.current_transaction == null
		and domain.reconcile_lease == null
	)
	for profile_id: StringName in domain.profile_ids:
		var profile: ManagedProfile = _get_profile(profile_id)
		if profile == null or profile.permit == null:
			continue
		var access: int = GFSaveProfileUtility.MANAGED_ACCESS_BLOCKED
		if allow_active_direct_operations and profile_id == domain.active_profile_id:
			access = GFSaveProfileUtility.MANAGED_ACCESS_SAVE_FLUSH
		var _updated: bool = _profile_utility.set_profile_managed_access_for_framework(
			profile_id,
			profile.permit,
			access
		)


func _make_registration_failure(
	profile: GFSaveProfile,
	kind: StringName,
	error: String
) -> Dictionary:
	var report: Dictionary = {"issues": []}
	var _issue: Variant = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		error,
		{"path": "coordinator"}
	)
	report["registered"] = false
	report["managed"] = false
	report["provider_domain_id"] = 0
	report["profile_id"] = profile.profile_id if profile != null else &""
	report["schema_id"] = (
		profile.get_effective_schema_id()
		if profile != null
		else &""
	)
	report["canonical_file_name"] = ""
	return GFValidationReportDictionary.finalize_report(
		report,
		"Managed Save profile registration",
		{
			"include_issue_count": true,
			"fallback_action": "Resolve the managed Profile registration issue.",
			"no_action": "Managed Save Profile registration is valid.",
		}
	)


func _make_profile_result_evidence(result: GFSaveProfileResult) -> Dictionary:
	if result == null:
		return {}
	return {
		"status": result.get_status(),
		"operation": result.get_operation(),
		"profile_id": result.get_profile_id(),
		"requested_generation": result.get_requested_generation(),
		"persisted_generation": result.get_persisted_generation(),
		"attempt_count": result.get_attempt_count(),
		"coalesced": result.was_coalesced(),
		"recovered": result.was_recovered(),
		"recovery_action": result.get_recovery_action(),
		"failed_section_id": result.get_failed_section_id(),
		"error_code": int(result.get_error_code()),
		"error": result.get_error().left(
			_MAX_PROFILE_RESULT_EVIDENCE_ERROR_LENGTH
		),
		"duration_msec": result.get_duration_msec(),
		"preparation_duration_msec": result.get_preparation_duration_msec(),
		"storage_duration_msec": result.get_storage_duration_msec(),
		"preparation_work_units": result.get_preparation_work_units(),
		"storage_request_ids": result.get_storage_request_ids(),
	}


func _enqueue_domain_tick(domain: DomainState) -> void:
	if domain == null or domain.pending_tick:
		return
	domain.pending_tick = true
	var _appended: bool = _pending_domain_ids.append(domain.domain_id)


# --- 私有/辅助方法（依赖与关闭） ---

func _dispose_now() -> void:
	if _disposed:
		return
	_disposed = true
	_dispose_requested = false
	for domain_value: Variant in _domains.values():
		var domain: DomainState = _get_domain_value(domain_value)
		if domain == null:
			continue
		_dispose_domain(domain)
	_domains.clear()
	_profiles.clear()
	_domain_id_by_profile.clear()
	_recovery_records.clear()
	_reconcile_records.clear()
	_pending_domain_ids = PackedInt64Array()
	_disconnect_profile_utility()
	_try_complete_quiesce()


func _set_profile_utility(profile_utility: GFSaveProfileUtility) -> void:
	if _profile_utility == profile_utility:
		return
	_disconnect_profile_utility()
	_profile_utility = profile_utility
	if _profile_utility == null:
		return
	var callback: Callable = Callable(
		self,
		"_on_profile_generation_evidence_changed"
	)
	if not _profile_utility.profile_generation_evidence_changed.is_connected(callback):
		var _connected: Error = (
			_profile_utility.profile_generation_evidence_changed.connect(callback)
			as Error
		)


func _disconnect_profile_utility() -> void:
	if _profile_utility == null:
		return
	var callback: Callable = Callable(
		self,
		"_on_profile_generation_evidence_changed"
	)
	if _profile_utility.profile_generation_evidence_changed.is_connected(callback):
		_profile_utility.profile_generation_evidence_changed.disconnect(callback)
	_profile_utility = null


func _disconnect_transaction_profile_operation(
	transaction: TransactionState
) -> void:
	if transaction == null:
		return
	if (
		transaction.profile_operation != null
		and transaction.profile_callback.is_valid()
		and transaction.profile_operation.completed.is_connected(
			transaction.profile_callback
		)
	):
		transaction.profile_operation.completed.disconnect(
			transaction.profile_callback
		)
	transaction.profile_callback = Callable()
	transaction.profile_operation = null


func _dispose_domain(domain: DomainState) -> void:
	if domain == null or domain.state == DOMAIN_STATE_DISPOSED:
		return
	var transaction: TransactionState = domain.current_transaction
	if transaction != null and not transaction.operation.is_completed():
		var write_outcome_uncertain: bool = transaction.write_admitted
		var lease: GFSaveProfileReconcileLease = transaction.reconcile_lease
		if write_outcome_uncertain and lease == null:
			var reconcile_profile_id: StringName = transaction.source_profile_id
			if transaction.stage in [_STAGE_RECOVERY_SAVE, _STAGE_MUTATION_SAVE]:
				reconcile_profile_id = transaction.target_profile_id
			lease = _create_reconcile_fence(
				domain,
				transaction,
				reconcile_profile_id
			)
		var load_apply_uncertain: bool = transaction.stage in [
			_STAGE_ACTIVATE_LOAD,
			_STAGE_TARGET_LOAD,
		]
		if load_apply_uncertain and lease == null:
			var load_reconcile_profile_id: StringName = (
				transaction.source_profile_id
				if transaction.stage == _STAGE_TARGET_LOAD
				else transaction.target_profile_id
			)
			lease = _create_reconcile_fence(
				domain,
				transaction,
				load_reconcile_profile_id,
				null,
				true
			)
		if lease == null and not transaction.forced_rollback_errors.is_empty():
			lease = _create_reconcile_fence(
				domain,
				transaction,
				transaction.target_profile_id,
				null,
				true
			)
		if lease != null:
			var _marked_disposed: bool = _mark_reconcile_disposed(lease)
		_finish_domain_transaction(
			domain,
			transaction,
			(
				GFSaveProfileTransactionResult.STATUS_OUTCOME_UNKNOWN
				if write_outcome_uncertain
				else GFSaveProfileTransactionResult.STATUS_DISPOSED
			),
			ERR_UNAVAILABLE,
			"Save Profile transaction coordinator was disposed.",
			transaction.stage,
			{},
			transaction.forced_rollback_errors,
			null,
			lease
		)
	if domain.reconcile_lease != null:
		var reconcile_lease: GFSaveProfileReconcileLease = domain.reconcile_lease
		var _disposed_lease: bool = _mark_reconcile_disposed(reconcile_lease)
		var _record_erased: bool = _reconcile_records.erase(
			reconcile_lease.get_lease_id()
		)
		domain.reconcile_lease = null
	_invalidate_recovery_leases(domain)
	domain.state = DOMAIN_STATE_DISPOSED
	for profile_id: StringName in domain.profile_ids:
		var profile: ManagedProfile = _get_profile(profile_id)
		if profile == null or profile.permit == null or _profile_utility == null:
			continue
		var _blocked: bool = _profile_utility.set_profile_managed_access_for_framework(
			profile_id,
			profile.permit,
			GFSaveProfileUtility.MANAGED_ACCESS_BLOCKED
		)
		var _abandoned: bool = _profile_utility.abandon_profile_management_for_framework(
			profile_id,
			profile.permit
		)
		profile.permit = null


func _try_complete_quiesce() -> void:
	if (
		_quiesce_completion == null
		or not _quiesce_completion.is_pending()
		or _processing_depth > 0
		or _notification_depth > 0
	):
		return
	for domain_value: Variant in _domains.values():
		var domain: DomainState = _get_domain_value(domain_value)
		if (
			domain != null
			and (
				domain.current_transaction != null
				or domain.reconcile_lease != null
				or domain.pending_tick
			)
		):
			return
		if domain != null and _domain_has_unsettled_profile_work(domain):
			return
	var _succeeded: bool = _quiesce_completion.succeed()


func _domain_has_unsettled_profile_work(domain: DomainState) -> bool:
	if domain == null:
		return false
	if _profile_utility == null:
		return true
	for profile_id: StringName in domain.profile_ids:
		var snapshot: Dictionary = _profile_utility.get_profile_state_snapshot(
			profile_id
		)
		if snapshot.is_empty():
			continue
		if (
			GFVariantData.get_option_string_name(snapshot, "state")
				!= GFSaveProfileUtility.STATE_IDLE
			or GFVariantData.get_option_int(snapshot, "save_queue_size") > 0
			or GFVariantData.get_option_int(snapshot, "load_queue_size") > 0
			or GFVariantData.get_option_int(snapshot, "flush_queue_size") > 0
			or GFVariantData.get_option_int(snapshot, "current_generation") > 0
			or GFVariantData.get_option_int(snapshot, "detached_write_count") > 0
			or GFVariantData.get_option_bool(snapshot, "schedule_enqueued")
			or GFVariantData.get_option_bool(snapshot, "preparation_enqueued")
		):
			return true
	return false


func _begin_processing() -> void:
	_processing_depth += 1


func _end_processing() -> void:
	_processing_depth = maxi(_processing_depth - 1, 0)
	if _processing_depth == 0 and _dispose_requested:
		_dispose_now()


# --- 私有/辅助方法（类型与集合辅助） ---

func _get_profile(profile_id: StringName) -> ManagedProfile:
	return _get_profile_value(GFVariantData.get_option_value(_profiles, profile_id))


func _get_profile_value(value: Variant) -> ManagedProfile:
	if value is ManagedProfile:
		var profile: ManagedProfile = value
		return profile
	return null


func _get_domain(domain_id: int) -> DomainState:
	return _get_domain_value(GFVariantData.get_option_value(_domains, domain_id))


func _get_domain_value(value: Variant) -> DomainState:
	if value is DomainState:
		var domain: DomainState = value
		return domain
	return null


func _get_domain_for_profile(profile_id: StringName) -> DomainState:
	return _get_domain(
		GFVariantData.get_option_int(_domain_id_by_profile, profile_id)
	)


func _read_providers(value: Variant) -> Array[GFSaveSectionProvider]:
	var providers: Array[GFSaveSectionProvider] = []
	if not value is Array:
		return providers
	var values: Array = value
	for entry: Variant in values:
		if entry is GFSaveSectionProvider:
			var provider: GFSaveSectionProvider = entry
			providers.append(provider)
	return providers


func _get_dictionary_claim(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(source, key)
	return value if value is Dictionary else {}


func _get_dictionary_array_claim(
	source: Dictionary,
	key: String
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var value: Variant = GFVariantData.get_option_value(source, key)
	if not value is Array:
		return records
	var values: Array = value
	for entry: Variant in values:
		if entry is Dictionary:
			var record: Dictionary = entry
			records.append(record)
	return records


func _read_rollback_errors(value: Variant) -> Array[GFSaveRollbackFailure]:
	var errors: Array[GFSaveRollbackFailure] = []
	if not value is Array:
		return errors
	var values: Array = value
	for entry: Variant in values:
		if entry is GFSaveRollbackFailure:
			var failure: GFSaveRollbackFailure = entry
			errors.append(failure)
	return errors


func _make_management_rollback_failures(
	provider_ids: PackedStringArray
) -> Array[GFSaveRollbackFailure]:
	var failures: Array[GFSaveRollbackFailure] = []
	for index: int in range(provider_ids.size() - 1, -1, -1):
		var failure: GFSaveRollbackFailure = GFSaveRollbackFailure.new()
		var _configured: bool = failure.configure_for_framework(
			StringName(provider_ids[index]),
			ERR_UNAVAILABLE
		)
		failures.append(failure)
	return failures


func _get_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		var values: Array = value
		for entry: Variant in values:
			if entry is String:
				var string_value: String = entry
				var _appended_string: bool = result.append(string_value)
			elif entry is StringName:
				var string_name_value: StringName = entry
				var _appended_name: bool = result.append(String(string_name_value))
	return result


func _get_int64_array(value: Variant) -> PackedInt64Array:
	if value is PackedInt64Array:
		var packed: PackedInt64Array = value
		return packed.duplicate()
	var result: PackedInt64Array = PackedInt64Array()
	if value is Array:
		var values: Array = value
		for entry: Variant in values:
			if typeof(entry) == TYPE_INT:
				var integer_value: int = entry
				var _appended: bool = result.append(integer_value)
	return result


func _string_name_array_to_packed(values: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: StringName in values:
		var _appended: bool = result.append(String(value))
	return result


func _int64_arrays_equal(
	left: PackedInt64Array,
	right: PackedInt64Array
) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true


func _int64_arrays_overlap(
	left: PackedInt64Array,
	right: PackedInt64Array
) -> bool:
	for value: int in left:
		if right.has(value):
			return true
	return false


func _get_error_code(
	source: Dictionary,
	key: String,
	fallback: Error
) -> Error:
	return GFVariantData.get_option_int(source, key, int(fallback)) as Error


# --- 信号处理函数 ---

func _on_profile_operation_completed(
	result: GFSaveProfileResult,
	domain_id: int,
	transaction_id: int
) -> void:
	if _disposed:
		return
	var domain: DomainState = _get_domain(domain_id)
	var transaction: TransactionState = (
		domain.current_transaction
		if domain != null
		else null
	)
	if (
		domain == null
		or transaction == null
		or transaction.operation.get_transaction_id() != transaction_id
		or result == null
	):
		return
	_disconnect_transaction_profile_operation(transaction)
	transaction.write_admitted = (
		result.get_status() == GFSaveProfileResult.STATUS_OUTCOME_UNKNOWN
	)
	match transaction.stage:
		_STAGE_ACTIVATE_LOAD:
			_handle_activate_load_result(domain, transaction, result)
		_STAGE_SOURCE_FLUSH:
			_handle_switch_flush_result(domain, transaction, result)
		_STAGE_TARGET_LOAD:
			_handle_switch_target_result(domain, transaction, result)
		_STAGE_RECOVERY_SAVE:
			_handle_recovery_save_result(domain, transaction, result)
		_STAGE_MUTATION_FLUSH:
			_handle_mutation_flush_result(domain, transaction, result)
		_STAGE_MUTATION_SAVE:
			_handle_mutation_save_result(domain, transaction, result)
		_STAGE_RECONCILE_LOAD:
			_handle_reconcile_load_result(domain, transaction, result)
		_:
			_finish_domain_transaction(
				domain,
				transaction,
				GFSaveProfileTransactionResult.STATUS_INVALID_REQUEST,
				ERR_BUG,
				"Transaction entered an invalid Profile operation stage.",
				transaction.stage
			)


func _on_profile_generation_evidence_changed(
	profile_id: StringName,
	generation: int
) -> void:
	if _disposed:
		return
	var records: Array = _reconcile_records.values()
	for record_value: Variant in records:
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if (
			GFVariantData.get_option_string_name(record, "profile_id") != profile_id
			or GFVariantData.get_option_int(record, "generation") != generation
		):
			continue
		var lease_value: Variant = GFVariantData.get_option_value(record, "lease")
		if not lease_value is GFSaveProfileReconcileLease:
			continue
		var lease: GFSaveProfileReconcileLease = lease_value
		_refresh_reconcile_lease(_get_domain(lease.get_domain_id()), lease)
	if _dispose_requested and _processing_depth == 0 and _notification_depth == 0:
		_dispose_now()
	else:
		_try_complete_quiesce()


# --- 内部类（内部状态类型） ---

## 单个受管 Profile 的已校验注册描述与 Utility 管理能力。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class ManagedProfile extends RefCounted:
	## 受管 Profile 的稳定 ID。
	## [br]
	## @api framework_internal
	var profile_id: StringName = &""

	## 注册时锁定的文档 schema ID。
	## [br]
	## @api framework_internal
	var schema_id: StringName = &""

	## 注册时锁定的文档 schema 版本。
	## [br]
	## @api framework_internal
	var schema_version: int = 0

	## 该 Profile 是否允许持久化操作。
	## [br]
	## @api framework_internal
	var save_enabled: bool = false

	## 该 Profile 是否允许严格读取操作。
	## [br]
	## @api framework_internal
	var load_enabled: bool = false

	## 注册时锁定的有序 Provider 实例序列。
	## [br]
	## @api framework_internal
	var providers: Array[GFSaveSectionProvider] = []

	## 底层 Profile Utility 发放的 opaque 管理 capability。
	## [br]
	## @api framework_internal
	var permit: RefCounted = null

	## 所属 Provider 拓扑 domain 的稳定 ID。
	## [br]
	## @api framework_internal
	var domain_id: int = 0


## 共享同一有序 Provider 实例拓扑的 Profile 事务隔离状态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class DomainState extends RefCounted:
	## domain 的稳定运行时 ID。
	## [br]
	## @api framework_internal
	var domain_id: int = 0

	## 用于精确拓扑匹配的有序 Provider 实例 ID。
	## [br]
	## @api framework_internal
	var provider_instance_ids: PackedInt64Array = PackedInt64Array()

	## 当前注册到该 domain 的 Profile ID。
	## [br]
	## @api framework_internal
	var profile_ids: Array[StringName] = []

	## 当前内存权威状态对应的 Profile ID；空值表示未激活。
	## [br]
	## @api framework_internal
	var active_profile_id: StringName = &""

	## domain 当前的事务状态机状态。
	## [br]
	## @api framework_internal
	var state: StringName = DOMAIN_STATE_INACTIVE

	## 每次权威内存或激活身份提交后递增的 domain 代际。
	## [br]
	## @api framework_internal
	var domain_generation: int = 1

	## 每次接纳 domain 事务时递增的事务 epoch。
	## [br]
	## @api framework_internal
	var transaction_epoch: int = 0

	## 当前独占 domain 的事务状态。
	## [br]
	## @api framework_internal
	var current_transaction: TransactionState = null

	## 当前封锁 domain 的对账 Lease。
	## [br]
	## @api framework_internal
	var reconcile_lease: GFSaveProfileReconcileLease = null

	## 当前 domain 是否已排入一次 mutation tick。
	## [br]
	## @api framework_internal
	var pending_tick: bool = false


## 单个已接纳 Profile 事务从建立到终态的隔离运行状态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class TransactionState extends RefCounted:
	## 向调用方暴露的类型化事务操作句柄。
	## [br]
	## @api framework_internal
	var operation: GFSaveProfileTransactionOperation = null

	## 事务源 Profile ID；不需要源 Profile 时为空。
	## [br]
	## @api framework_internal
	var source_profile_id: StringName = &""

	## 事务目标 Profile ID。
	## [br]
	## @api framework_internal
	var target_profile_id: StringName = &""

	## 事务接纳前的激活 Profile ID。
	## [br]
	## @api framework_internal
	var active_profile_before: StringName = &""

	## 当前事务阶段。
	## [br]
	## @api framework_internal
	var stage: StringName = &""

	## 从类型化请求转移到该事务的项目上下文。
	## [br]
	## @api framework_internal
	## [br]
	## @schema context: Dictionary with caller-defined ephemeral operation data.
	var context: Dictionary = {}

	## mutation 持久化时转移给保存请求的文档元数据。
	## [br]
	## @api framework_internal
	## [br]
	## @schema document_metadata: Dictionary accepted by the Save persisted-value contract.
	var document_metadata: Dictionary = {}

	## 构造事务终态结果时附带的元数据。
	## [br]
	## @api framework_internal
	## [br]
	## @schema result_metadata: Dictionary with caller-defined result metadata.
	var result_metadata: Dictionary = {}

	## 当前由底层 Profile Utility 执行的操作句柄。
	## [br]
	## @api framework_internal
	var profile_operation: GFSaveProfileOperation = null

	## 当前底层操作的一次性完成回调。
	## [br]
	## @api framework_internal
	var profile_callback: Callable = Callable()

	## 从 mutation 请求转移的 section 全量替换描述。
	## [br]
	## @api framework_internal
	## [br]
	## @schema mutation_records: Array[Dictionary] whose entries contain section_id, schema_version, payload, and metadata.
	var mutation_records: Array[Dictionary] = []

	## 已应用到内存且等待精确持久化的 section 候选值。
	## [br]
	## @api framework_internal
	var mutation_candidates: Array[GFSaveSection] = []

	## mutation 按稳定 Provider 顺序实际触及的 section ID。
	## [br]
	## @api framework_internal
	var mutation_provider_ids: PackedStringArray = PackedStringArray()

	## 按 section ID 索引的 mutation 应用前 Provider 快照。
	## [br]
	## @api framework_internal
	## [br]
	## @schema mutation_snapshots: Internal Dictionary keyed by section ID with GFSaveSection values.
	var mutation_snapshots: Dictionary = {}

	## 在多阶段事务中保留的有界前置阶段证据。
	## [br]
	## @api framework_internal
	## [br]
	## @schema stage_evidence: Dictionary keyed by stage name with bounded payload-free Profile result evidence.
	var stage_evidence: Dictionary = {}

	## 与当前对账事务绑定的 Lease。
	## [br]
	## @api framework_internal
	var reconcile_lease: GFSaveProfileReconcileLease = null

	## 强制回滚阶段收集的 Provider 失败。
	## [br]
	## @api framework_internal
	var forced_rollback_errors: Array[GFSaveRollbackFailure] = []

	## 底层写入是否已获准，用于区分 disposed 与 outcome-unknown。
	## [br]
	## @api framework_internal
	var write_admitted: bool = false

	## 在终态提交前清空不应跨操作生命期保留的请求与 mutation payload。
	## [br]
	## @api framework_internal
	func clear_payload_for_framework() -> void:
		context.clear()
		document_metadata.clear()
		result_metadata.clear()
		for record: Dictionary in mutation_records:
			record.clear()
		mutation_records.clear()
		mutation_candidates.clear()
		mutation_provider_ids = PackedStringArray()
		mutation_snapshots.clear()
