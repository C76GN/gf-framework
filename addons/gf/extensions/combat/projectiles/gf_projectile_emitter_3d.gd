## GFProjectileEmitter3D: 在安全点借用完整场景，以一次等待原子发射一批 3D projectile。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFProjectileEmitter3D
extends Node3D


# --- 信号 ---

## 单个 root 的 session 已 ACTIVE 且 started 已按稳定顺序发布后发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param projectile_root: allocator 管理的完整实例 root。
## [br]
## @param session: 对应 ACTIVE session。
## [br]
## @param launch_input: 该候选独立的最终 typed input 快照。
signal projectile_emitted(
	projectile_root: Node,
	session: GFProjectileSession,
	launch_input: GFProjectileLaunchInput3D
)

## 本次发射在返回任何 root 前失败时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param reason: 稳定失败原因。
## [br]
## @param details: 有界诊断详情。
## [br]
## @schema details: Dictionary，最多 16 项；键仅限 ok、reason、binding_failure_reason、policy_id、projectile_id、requested_count、emit_count、emitted_count、hard_limit、now_msec、state、published、committed、compensated、rolled_back、remaining_cooldown_seconds、available_charges、required_charges、consumed_charges、emission_count、policy_instance_id、policy_state_generation、policy_enabled；binding_failure_reason 为 GFProjectileBinding.FailureReason；值仅限 null、bool、int、有限 float、String（至多 256 字符）、StringName（至多 128 字符）或 NodePath（至多 256 字符）。
signal projectile_emit_failed(reason: StringName, details: Dictionary)


# --- 常量 ---

## 提供发射变换的有限值校验。
## [br]
## @api private
const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## 未使用 catalog ID 时的直接 typed definition。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var projectile_definition: GFProjectileDefinition3D = null

## 可选 ID 到 typed definition 目录。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var projectile_catalog: GFProjectileCatalog = null

## 调用未指定 ID 时使用的目录 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var default_projectile_id: StringName = &""

## 可选 typed 3D spawn pattern。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var spawn_pattern: GFProjectileSpawnPattern3D = null

## 可选限流、charge 与 cooldown 策略。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var emission_policy: GFProjectileEmissionPolicy = null

## 单次请求的不可绕过候选硬上限。
## [br]
## @api public
## [br]
## @since 8.0.0
@export_range(1, 65536, 1) var hard_projectile_limit_per_request: int = 4096:
	set(value):
		hard_projectile_limit_per_request = clampi(value, 1, 65536)

## null 调用输入的默认值；每次请求和候选均深复制。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var default_launch_input: GFProjectileLaunchInput3D = null

## 相对 emitter 的生成父节点路径；空路径使用当前父节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var spawn_parent_path: NodePath = NodePath("")

# --- 公共变量 ---

## 可选共享对象池；null 时使用发射器私有且不缓存的池。
## 项目负责共享池的生命周期；发射器只归还自己的 Lease。
## [br]
## @api public
## [br]
## @since 3.17.0
var object_pool_utility: GFObjectPoolUtility = null

# --- 私有变量 ---

## 记录 emitter 当前持有的通知屏障层数。
## [br]
## @api private
var _notification_barrier_depth: int = 0

## 跟踪由本 emitter 创建并等待归还的退役记录。
## [br]
## @api private
var _active_retirements: Array[_RetirementRecord] = []

## 标记 emitter 是否已进入释放流程。
## [br]
## @api private
var _is_releasing: bool = false

## 每次开始释放时递增，用于使在途请求的代际检查失效。
## [br]
## @api private
var _release_generation: int = 0

## 阻止同一 emitter 同时执行多个发射事务。
## [br]
## @api private
var _emission_in_progress: bool = false

## 未配置共享池时使用的 emitter 私有池。
## [br]
## @api private
var _private_pool: GFObjectPoolUtility = null

## 保存当前发射事务的诊断阶段。
## [br]
## @api private
var _emission_stage: StringName = &"validation"

## 保存当前发射事务最后记录的失败原因。
## [br]
## @api private
var _emission_failure: StringName = &""

## 保存当前请求经 spawn pattern 解析后的数量。
## [br]
## @api private
var _requested_count: int = 0


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	_is_releasing = false


func _exit_tree() -> void:
	_begin_emitter_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_settle_predelete_retirements()


# --- 公共方法 ---

## 在安全点原子发射一批 3D projectile，并返回唯一终态。
## 请求期间只允许一次在途发射；需要单发时将 emit_count 设为 1。
## 输入、生成位置和配置身份在等待前冻结；等待期间配置变动会取消本次请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param launch_input: 可选 typed 调用输入；容器值复制，目标节点保持弱引用。
## [br]
## @param projectile_id: 可选 catalog ID；空值使用默认配置。
## [br]
## @param emit_count: 正数覆盖 pattern 数量；负值使用 pattern 默认值。
## [br]
## @return: 唯一结果；失败时不交付部分 Session，成功数量可以受发射策略和硬上限限制。
func emit_pattern(
	launch_input: GFProjectileLaunchInput3D = null,
	projectile_id: StringName = &"",
	emit_count: int = -1
) -> GFProjectileEmissionResult:
	if not Thread.is_main_thread():
		return _failure_result(&"validation", &"main_thread_required")
	if _is_releasing or not is_inside_tree() or is_queued_for_deletion():
		return _failure_result(&"validation", &"emitter_released")
	if _emission_in_progress:
		return _failure_result(&"validation", &"emission_in_progress")
	_emission_in_progress = true
	_emission_stage = &"validation"
	_emission_failure = &""
	_requested_count = 0
	var sessions: Array[GFProjectileSession] = await _emit_projectiles_transaction(
		launch_input, projectile_id, emit_count
	)
	_emission_in_progress = false
	if sessions.is_empty():
		return _failure_result(
			_emission_stage,
			_emission_failure if _emission_failure != &"" else &"emitter_released",
			_requested_count
		)
	var result: GFProjectileEmissionResult = GFProjectileEmissionResult.new()
	var _configured: bool = result.configure_for_framework(
		GFProjectileEmissionResult.Status.SUCCEEDED,
		&"completed", &"", _requested_count, sessions
	)
	return result


## 解析本次发射使用的 typed 3D definition。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param projectile_id: 可选 catalog ID。
## [br]
## @return: 匹配的 3D definition；缺失或维度不匹配时返回 null。
func resolve_projectile_definition(
	projectile_id: StringName = &""
) -> GFProjectileDefinition3D:
	if projectile_catalog != null and projectile_id != &"":
		var catalog_definition: GFProjectileDefinition = projectile_catalog.get_definition(projectile_id)
		if catalog_definition is GFProjectileDefinition3D:
			var typed_definition: GFProjectileDefinition3D = catalog_definition
			return typed_definition
		return null
	return projectile_definition


## 解析完整实例 root 的生成父节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: configured parent、emitter parent 或 tree 内 emitter；不可用时返回 null。
func resolve_spawn_parent() -> Node:
	if spawn_parent_path != NodePath(""):
		var configured_parent: Node = get_node_or_null(spawn_parent_path)
		if configured_parent != null:
			return configured_parent
	var parent: Node = get_parent()
	return parent if parent != null else (self if is_inside_tree() else null)


# --- 私有/辅助方法 ---

## 依次执行请求校验、批量获取、绑定、预留、deferred commit、激活与发布。
## [br]
## @api private
func _emit_projectiles_transaction(
	launch_input: GFProjectileLaunchInput3D,
	projectile_id: StringName,
	emit_count: int
) -> Array[GFProjectileSession]:
	var emitter_lifetime_ref: WeakRef = weakref(self)
	var retirement_owner_id: int = get_instance_id()
	var request_release_generation: int = _release_generation
	var effective_id: StringName = projectile_id if projectile_id != &"" else default_projectile_id
	var definition: GFProjectileDefinition3D = resolve_projectile_definition(effective_id)
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if not _request_is_current(request_release_generation):
		_emit_failure(&"emitter_released", {})
		return []
	if definition == null or not is_instance_valid(definition):
		_emit_failure(&"missing_definition", { "projectile_id": effective_id })
		return []
	var definition_scene: PackedScene = definition.scene
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if definition_scene == null or not is_instance_valid(definition_scene):
		_emit_failure(&"missing_definition", { "projectile_id": effective_id })
		return []
	var merged_input: GFProjectileLaunchInput3D = _merge_launch_input(
		launch_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if merged_input == null or not _request_is_current(request_release_generation):
		var input_failure_reason: StringName = (
			&"launch_input_invalidated"
			if _request_is_current(request_release_generation)
			else &"emitter_released"
		)
		_emit_failure(input_failure_reason, {})
		return []
	var requested_count: int = _resolve_requested_count(emit_count)
	_requested_count = requested_count
	_emission_stage = &"policy"
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if not _request_is_current(request_release_generation):
		_emit_failure(&"emitter_released", {})
		return []
	var task: GFProjectileEmissionTask = GFProjectileEmissionTask.new()
	var _configured: GFProjectileEmissionTask = task.configure(
		self,
		emission_policy,
		effective_id,
		merged_input.get_metadata(),
		requested_count,
		hard_projectile_limit_per_request,
		int(Time.get_ticks_msec())
	)
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	var prepare_report: Dictionary = task.prepare()
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if not _request_is_current(request_release_generation):
		_abort_precommit([], [], task, &"emitter_released")
		return []
	if not GFVariantData.get_option_bool(prepare_report, "ok", false):
		_emit_failure(
			GFVariantData.get_option_string_name(prepare_report, "reason", &"emission_policy_blocked"),
			prepare_report
		)
		return []
	var allowed_count: int = task.get_allowed_count()
	var transforms: Array[Transform3D] = _get_spawn_transforms(merged_input, allowed_count)
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if not _request_is_current(request_release_generation):
		_abort_precommit([], [], task, &"emitter_released")
		return []
	transforms = _filter_finite_transforms(transforms)
	if transforms.size() > allowed_count:
		transforms = transforms.slice(0, allowed_count)
	if transforms.is_empty():
		var empty_rollback: Dictionary = task.rollback(&"empty_spawn_pattern")
		_emit_failure(&"empty_spawn_pattern", empty_rollback)
		return []
	var definition_snapshot: _DefinitionSnapshot = _capture_definition_snapshot(definition)
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if definition_snapshot == null:
		_abort_precommit([], [], task, &"invalid_definition")
		return []
	var projectile_scene: PackedScene = definition_snapshot._scene
	var spawn_parent: Node = resolve_spawn_parent()
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	var parent_fence_reason: StringName = _precommit_fence_failure_reason(
		request_release_generation,
		definition_snapshot,
		spawn_parent
	)
	if parent_fence_reason != &"":
		_abort_precommit([], [], task, parent_fence_reason)
		return []

	var roots: Array[Node] = []
	var inputs: Array[GFProjectileLaunchInput3D] = []
	var records: Array[_RetirementRecord] = []
	var pool_snapshot: GFObjectPoolUtility = object_pool_utility
	if pool_snapshot == null:
		if _private_pool == null:
			_private_pool = GFObjectPoolUtility.new()
			_private_pool.max_available_per_scene = -1
		pool_snapshot = _private_pool
	_emission_stage = &"allocation"
	var acquisitions: Array[GFObjectPoolAcquireResult] = await pool_snapshot.acquire_batch_for_framework(
		projectile_scene, spawn_parent, transforms.size(), merged_input.get_metadata(), self
	)
	if not _request_is_current(request_release_generation):
		for acquisition: GFObjectPoolAcquireResult in acquisitions:
			if acquisition.is_successful():
				var _released: bool = acquisition.get_lease().release()
		_abort_precommit([], [], task, &"emitter_released")
		return []
	if acquisitions.is_empty() or not acquisitions[0].is_successful():
		var allocation_reason: StringName = (
			acquisitions[0].get_reason() if not acquisitions.is_empty() else &"instantiate_failed"
		)
		_abort_precommit([], [], task, allocation_reason)
		return []
	for acquisition: GFObjectPoolAcquireResult in acquisitions:
		var record: _RetirementRecord = _bind_acquired_candidate(
			acquisition.get_lease(), pool_snapshot
		)
		records.append(record)
	_emission_stage = &"prepare"
	for index: int in range(transforms.size()):
		var record: _RetirementRecord = records[index]
		var spawn_transform: Transform3D = transforms[index]
		var acquired_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if acquired_fence_reason != &"":
			_abort_precommit([], records, task, acquired_fence_reason)
			return []
		if not _record_root_is_live(record):
			_abort_precommit([], records, task, &"instantiate_failed")
			return []
		_apply_spawn_transform(record._root, spawn_transform)
		if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
			return []
		var placement_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if placement_fence_reason != &"":
			_abort_precommit([], records, task, placement_fence_reason)
			return []
		if not _record_root_is_live(record):
			_abort_precommit([], records, task, &"placement_invalidated")
			return []
		var candidate_input_value: Variant = merged_input.duplicate_input()
		if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
			return []
		if (
			typeof(candidate_input_value) != TYPE_OBJECT
			or not is_instance_valid(candidate_input_value)
			or not candidate_input_value is GFProjectileLaunchInput3D
		):
			_abort_precommit([], records, task, &"launch_input_invalidated")
			return []
		var candidate_input: GFProjectileLaunchInput3D = candidate_input_value
		roots.append(record._root)
		inputs.append(candidate_input)

	var reservations: Array[GFProjectileLaunchReservation] = []
	for index: int in range(roots.size()):
		var binding_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if binding_fence_reason != &"":
			_abort_precommit(reservations, records, task, binding_fence_reason)
			return []
		var binding: GFProjectileBinding3D = definition.bind_instance(roots[index])
		if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
			return []
		var bound_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if bound_fence_reason != &"":
			_abort_precommit(reservations, records, task, bound_fence_reason)
			return []
		if binding == null or not binding.is_valid():
			var binding_failure_reason: int = (
				binding.get_failure_reason()
				if binding != null
				else GFProjectileBinding.FailureReason.INTERNAL_FAILURE
			)
			_abort_precommit(
				reservations,
				records,
				task,
				&"binding_failed",
				{ "binding_failure_reason": binding_failure_reason }
			)
			return []
		var runtime_value: Node = binding.get_runtime()
		if not runtime_value is GFProjectile3D:
			_abort_precommit(reservations, records, task, &"runtime_unavailable")
			return []
		var runtime: GFProjectile3D = runtime_value
		var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
			binding,
			inputs[index],
			self
		)
		if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
			if reservation != null and is_instance_valid(reservation):
				var _invalidated_owner: bool = (
					reservation.invalidate_lost_owner_for_framework(
						retirement_owner_id,
						&"allocator_owner_lost"
					)
				)
			return []
		if reservation != null:
			reservations.append(reservation)
			if records[index]._bind_reservation(reservation) != OK:
				_abort_precommit(reservations, records, task, &"reservation_owner_failed")
				return []
		var reserved_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if reserved_fence_reason != &"":
			_abort_precommit(reservations, records, task, reserved_fence_reason)
			return []
		if reservation == null:
			_abort_precommit(reservations, records, task, &"reservation_failed")
			return []

	for reservation: GFProjectileLaunchReservation in reservations:
		var arm_result: Error = reservation.arm_for_framework(self)
		var armed_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if armed_fence_reason != &"":
			_abort_precommit(reservations, records, task, armed_fence_reason)
			return []
		if arm_result != OK:
			_abort_precommit(reservations, records, task, &"reservation_invalidated")
			return []

	var commit_fence_reason: StringName = _precommit_fence_failure_reason(
		request_release_generation,
		definition_snapshot,
		spawn_parent
	)
	if commit_fence_reason != &"":
		_abort_precommit(reservations, records, task, commit_fence_reason)
		return []
	_emission_stage = &"commit"
	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(roots.size())
	if not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref):
		if receipt != null and is_instance_valid(receipt):
			var _compensated_lost_owner: Dictionary = (
				receipt.compensate_for_framework(&"emitter_released")
			)
		return []
	if receipt != null and not _request_is_current(request_release_generation):
		_abort_committed_pre_activation(
			receipt,
			reservations,
			records,
			&"emitter_released"
		)
		return []
	if receipt == null:
		var commit_failure_reason: StringName = (
			&"emission_commit_failed"
			if _request_is_current(request_release_generation)
			else &"emitter_released"
		)
		_abort_precommit(reservations, records, task, commit_failure_reason)
		return []

	_emission_stage = &"activation"
	var sessions: Array[GFProjectileSession] = []
	for reservation: GFProjectileLaunchReservation in reservations:
		var session: GFProjectileSession = reservation.consume_for_framework(self)
		var session_was_activated: bool = (
			session != null
			and is_instance_valid(session)
			and session.get_status() != GFProjectileSession.Status.UNCONFIGURED
		)
		var session_is_active: bool = (
			session_was_activated
			and session.is_active()
		)
		if session_was_activated:
			sessions.append(session)
		if not _request_is_current(request_release_generation):
			_handle_activation_failure(receipt, reservations, sessions, records)
			_emit_failure(&"emitter_released", {})
			return []
		if session_is_active and not _sessions_are_current(sessions, records):
			_handle_activation_failure(receipt, reservations, sessions, records)
			_emit_failure(&"activation_invalidated", {})
			return []
		if not session_is_active:
			_handle_activation_failure(receipt, reservations, sessions, records)
			_emit_failure(&"activation_failed", {})
			return []

	var receipt_activation_result: Error = receipt.mark_activated_for_framework()
	if (
		receipt_activation_result != OK
		or not _request_is_current(request_release_generation)
		or not _sessions_are_current(sessions, records)
	):
		_handle_active_failure(sessions, records)
		var activation_failure_reason: StringName = &"activation_invalidated"
		if receipt_activation_result != OK:
			activation_failure_reason = &"receipt_activation_failed"
		elif not _request_is_current(request_release_generation):
			activation_failure_reason = &"emitter_released"
		_emit_failure(
			activation_failure_reason,
			{}
		)
		return []
	_notification_barrier_depth += 1
	for index: int in range(sessions.size()):
		var barrier_result: Error = sessions[index].begin_notification_barrier_for_framework()
		if (
			barrier_result != OK
			or not _request_is_current(request_release_generation)
			or not _sessions_are_current(sessions, records)
		):
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			var barrier_failure_reason: StringName = &"activation_invalidated"
			if barrier_result != OK:
				barrier_failure_reason = &"notification_barrier_failed"
			elif not _request_is_current(request_release_generation):
				barrier_failure_reason = &"emitter_released"
			_emit_failure(
				barrier_failure_reason,
				{}
			)
			return []
		var runtime_value: Node = sessions[index].get_runtime()
		var retirement_claim_result: Error = ERR_INVALID_PARAMETER
		if runtime_value is GFProjectile3D:
			var runtime: GFProjectile3D = runtime_value
			retirement_claim_result = runtime.begin_terminal_retirement_for_framework(
				sessions[index]
			)
		if (
			retirement_claim_result != OK
			or not _request_is_current(request_release_generation)
			or not _sessions_are_current(sessions, records)
		):
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			var claim_failure_reason: StringName = &"terminal_claim_failed"
			if not _request_is_current(request_release_generation):
				claim_failure_reason = &"emitter_released"
			_emit_failure(claim_failure_reason, {})
			return []
		var connected: int = records[index]._bind_session(sessions[index])
		if connected != OK:
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			_emit_failure(&"terminal_subscription_failed", {})
			return []
	_emission_stage = &"publication"
	var publish_report: Dictionary = receipt.publish_for_framework()
	var emitter_after_publish_value: Variant = emitter_lifetime_ref.get_ref()
	if (
		typeof(emitter_after_publish_value) != TYPE_OBJECT
		or not is_instance_valid(emitter_after_publish_value)
	):
		return []
	if not GFVariantData.get_option_bool(publish_report, "ok", false):
		_handle_active_failure(sessions, records)
		_release_session_barriers(sessions)
		_release_notification_barrier()
		_emit_failure(&"emission_publish_failed", publish_report)
		return []
	var released_during_publication: bool = false
	for index: int in range(sessions.size()):
		if not _publication_sessions_are_current(sessions, records):
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			_emit_failure(&"publication_invalidated", {})
			return []
		released_during_publication = (
			_observe_publication_release(request_release_generation)
			or released_during_publication
		)
		var runtime_value: Node = sessions[index].get_runtime()
		if runtime_value is GFProjectile3D:
			var runtime: GFProjectile3D = runtime_value
			var _started: Error = runtime.publish_started_for_framework(sessions[index])
		var emitter_after_started_value: Variant = emitter_lifetime_ref.get_ref()
		if (
			typeof(emitter_after_started_value) != TYPE_OBJECT
			or not is_instance_valid(emitter_after_started_value)
		):
			return []
		if not _publication_sessions_are_current(sessions, records):
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			_emit_failure(&"publication_invalidated", {})
			return []
		released_during_publication = (
			_observe_publication_release(request_release_generation)
			or released_during_publication
		)
		projectile_emitted.emit(roots[index], sessions[index], inputs[index])
		var emitter_after_emitted_value: Variant = emitter_lifetime_ref.get_ref()
		if (
			typeof(emitter_after_emitted_value) != TYPE_OBJECT
			or not is_instance_valid(emitter_after_emitted_value)
		):
			return []
		if not _publication_sessions_are_current(sessions, records):
			_handle_active_failure(sessions, records)
			_release_session_barriers(sessions)
			_release_notification_barrier()
			_emit_failure(&"publication_invalidated", {})
			return []
		released_during_publication = (
			_observe_publication_release(request_release_generation)
			or released_during_publication
		)
	_release_session_barriers(sessions)
	var emitter_after_terminal_value: Variant = emitter_lifetime_ref.get_ref()
	if (
		typeof(emitter_after_terminal_value) != TYPE_OBJECT
		or not is_instance_valid(emitter_after_terminal_value)
	):
		return []
	released_during_publication = (
		_observe_publication_release(request_release_generation)
		or released_during_publication
	)
	_release_notification_barrier()
	released_during_publication = (
		_observe_publication_release(request_release_generation)
		or released_during_publication
	)
	if released_during_publication:
		_emit_failure(&"emitter_released", {})
		return []
	return sessions


## 以默认输入为基础，将可选调用输入的目标和 metadata 合并到本次快照。
## [br]
## @api private
func _merge_launch_input(
	call_input: GFProjectileLaunchInput3D,
	request_release_generation: int,
	emitter_lifetime_ref: WeakRef
) -> GFProjectileLaunchInput3D:
	var result: GFProjectileLaunchInput3D = _snapshot_external_launch_input(
		default_launch_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if result == null:
		return null
	if call_input == null:
		return result
	var call_snapshot: GFProjectileLaunchInput3D = _snapshot_external_launch_input(
		call_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if call_snapshot == null:
		return null
	match call_snapshot.get_target_kind():
		GFProjectileLaunchInput3D.TargetKind.NODE:
			result.set_target_node(call_snapshot.get_target_node())
		GFProjectileLaunchInput3D.TargetKind.POSITION:
			result.set_target_position(call_snapshot.get_target_position())
		_:
			result.set_target_none()
	var metadata: Dictionary = result.get_metadata()
	var call_metadata: Dictionary = call_snapshot.get_metadata()
	for key: Variant in call_metadata.keys():
		metadata[key] = call_metadata[key]
	result.set_metadata(metadata)
	return result


## 校验外部输入的目标类型与代际边界，并读取为新的 typed 输入对象。
## [br]
## @api private
func _snapshot_external_launch_input(
	source: GFProjectileLaunchInput3D,
	request_release_generation: int,
	emitter_lifetime_ref: WeakRef
) -> GFProjectileLaunchInput3D:
	var result: GFProjectileLaunchInput3D = GFProjectileLaunchInput3D.new()
	if source == null:
		return result
	if not is_instance_valid(source):
		return null
	var kind_value: Variant = source.call(&"get_target_kind")
	if (
		not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref)
		or not is_instance_valid(source)
		or not _request_is_current(request_release_generation)
		or typeof(kind_value) != TYPE_INT
	):
		return null
	var kind: int = kind_value
	match kind:
		GFProjectileLaunchInput3D.TargetKind.NODE:
			var target_value: Variant = source.call(&"get_target_node")
			if (
				not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref)
				or not is_instance_valid(source)
				or not _request_is_current(request_release_generation)
			):
				return null
			if target_value == null:
				result.set_target_none()
			elif (
				typeof(target_value) == TYPE_OBJECT
				and is_instance_valid(target_value)
				and target_value is Node3D
			):
				var target: Node3D = target_value
				if target.is_queued_for_deletion():
					return null
				result.set_target_node(target)
			else:
				return null
		GFProjectileLaunchInput3D.TargetKind.POSITION:
			var position_value: Variant = source.call(&"get_target_position")
			if (
				not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref)
				or not is_instance_valid(source)
				or not _request_is_current(request_release_generation)
				or typeof(position_value) != TYPE_VECTOR3
			):
				return null
			var target_position: Vector3 = position_value
			result.set_target_position(target_position)
		GFProjectileLaunchInput3D.TargetKind.NONE:
			result.set_target_none()
		_:
			return null
	var metadata_value: Variant = source.call(&"get_metadata")
	if (
		not GFProjectileEmitter3D._lifetime_ref_is_live(emitter_lifetime_ref)
		or not is_instance_valid(source)
		or not _request_is_current(request_release_generation)
		or typeof(metadata_value) != TYPE_DICTIONARY
	):
		return null
	var metadata: Dictionary = metadata_value
	result.set_metadata(metadata)
	return result


## 委托 spawn pattern 解析数量；未配置 pattern 时正数照用，其余默认为 1。
## [br]
## @api private
func _resolve_requested_count(emit_count: int) -> int:
	if spawn_pattern != null:
		return spawn_pattern.resolve_spawn_count(emit_count)
	return emit_count if emit_count > 0 else 1


## 委托 spawn pattern 生成变换；未配置时重复使用 emitter 的当前全局变换。
## [br]
## @api private
func _get_spawn_transforms(
	launch_input: GFProjectileLaunchInput3D,
	emit_count: int
) -> Array[Transform3D]:
	if spawn_pattern != null:
		return spawn_pattern.get_spawn_transforms(self, launch_input, emit_count)
	var result: Array[Transform3D] = []
	for _index: int in range(maxi(emit_count, 0)):
		result.append(global_transform)
	return result


## 只保留有限的 3D 变换。
## [br]
## @api private
func _filter_finite_transforms(values: Array[Transform3D]) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for value: Transform3D in values:
		if _GF_COMBAT_FINITE_MATH.is_finite_transform3d(value):
			result.append(value)
	return result


## 检查弱引用当前是否指向有效的 GFProjectileEmitter3D 实例。
## [br]
## @api private
static func _lifetime_ref_is_live(emitter_lifetime_ref: WeakRef) -> bool:
	if emitter_lifetime_ref == null:
		return false
	var emitter_value: Variant = emitter_lifetime_ref.get_ref()
	return (
		typeof(emitter_value) == TYPE_OBJECT
		and is_instance_valid(emitter_value)
		and emitter_value is GFProjectileEmitter3D
	)


## 为已获取的 lease 建立退役记录，将记录挂到 SceneTree 根并纳入本 emitter 跟踪。
## [br]
## @api private
func _bind_acquired_candidate(
	lease: GFObjectPoolLease,
	pool: GFObjectPoolUtility
) -> _RetirementRecord:
	var record: _RetirementRecord = _RetirementRecord.new()
	record.name = &"GFProjectileRetirementRecord3D"
	record.process_mode = Node.PROCESS_MODE_DISABLED
	record._configure(lease, pool, _on_retirement_record_settled, get_instance_id())
	get_tree().root.add_child(record)
	_active_retirements.append(record)
	return record


## 创建并配置带阶段、原因及已解析请求数的失败终态。
## [br]
## @api private
static func _failure_result(
	stage: StringName,
	reason: StringName,
	requested_count: int = 0
) -> GFProjectileEmissionResult:
	var result: GFProjectileEmissionResult = GFProjectileEmissionResult.new()
	var _configured: bool = result.configure_for_framework(
		GFProjectileEmissionResult.Status.FAILED, stage, reason, requested_count, []
	)
	return result


## 检查退役记录的 root 仍有效，并且仍是其 lease 当前管理的节点。
## [br]
## @api private
func _record_root_is_live(record: _RetirementRecord) -> bool:
	return (
		record != null
		and record._root != null
		and is_instance_valid(record._root)
		and not record._root.is_queued_for_deletion()
		and record._lease.get_node() == record._root
	)


## 捕获 definition 的场景、路径及策略身份快照，仅返回仍与原声明一致的快照。
## [br]
## @api private
func _capture_definition_snapshot(
	definition: GFProjectileDefinition3D
) -> _DefinitionSnapshot:
	if (
		definition == null
		or not is_instance_valid(definition)
		or definition.scene == null
		or not is_instance_valid(definition.scene)
		or definition.motion == null
		or not is_instance_valid(definition.motion)
		or definition.body_adapter == null
		or not is_instance_valid(definition.body_adapter)
		or (
			definition.lifetime_policy != null
			and not is_instance_valid(definition.lifetime_policy)
		)
	):
		return null
	var snapshot: _DefinitionSnapshot = _DefinitionSnapshot.new()
	snapshot._definition = definition
	snapshot._scene = definition.scene
	snapshot._runtime_path = definition.runtime_path
	snapshot._impact_source_paths = definition.impact_source_paths.duplicate()
	snapshot._motion = definition.motion
	snapshot._lifetime = definition.lifetime_policy
	snapshot._body_adapter = definition.body_adapter
	return snapshot if snapshot._is_current() else null


## 检查请求代际、definition 快照和 spawn parent，并返回首个失效原因。
## [br]
## @api private
func _precommit_fence_failure_reason(
	start_generation: int,
	definition_snapshot: _DefinitionSnapshot,
	spawn_parent: Node
) -> StringName:
	if not _request_is_current(start_generation):
		return &"emitter_released"
	if definition_snapshot == null or not definition_snapshot._is_current():
		return &"definition_changed"
	if (
		spawn_parent == null
		or not is_instance_valid(spawn_parent)
		or spawn_parent.is_queued_for_deletion()
		or not spawn_parent.is_inside_tree()
	):
		return &"spawn_parent_lost"
	return &""


## 检查每个已激活 session 与对应退役记录中的 root/runtime 是否仍有效。
## [br]
## @api private
func _sessions_are_current(
	sessions: Array[GFProjectileSession],
	records: Array[_RetirementRecord]
) -> bool:
	if sessions.size() > records.size():
		return false
	for index: int in range(sessions.size()):
		var session: GFProjectileSession = sessions[index]
		if (
			session == null
			or not is_instance_valid(session)
			or not session.is_active()
			or not _record_root_is_live(records[index])
			or session.get_instance_root() != records[index]._root
		):
			return false
		var runtime: Node = session.get_runtime()
		if runtime == null or not is_instance_valid(runtime) or runtime.is_queued_for_deletion():
			return false
	return true


## 要求 session 数与退役记录数相同，并逐项检查发布资格。
## [br]
## @api private
func _publication_sessions_are_current(
	sessions: Array[GFProjectileSession],
	records: Array[_RetirementRecord]
) -> bool:
	if sessions.size() != records.size():
		return false
	for index: int in range(sessions.size()):
		if not _publication_candidate_is_current(sessions[index], records[index]):
			return false
	return true


## 检查一个 session 与退役记录身份一致，并由 runtime 校验发布拓扑。
## [br]
## @api private
func _publication_candidate_is_current(
	session: GFProjectileSession,
	record: _RetirementRecord
) -> bool:
	if (
		session == null
		or not is_instance_valid(session)
		or record == null
		or not is_instance_valid(record)
		or record._retired
		or record._session != session
		or not _record_root_is_live(record)
	):
		return false
	var runtime_value: Node = session.get_runtime()
	if not runtime_value is GFProjectile3D:
		return false
	var runtime: GFProjectile3D = runtime_value
	return runtime.publication_is_current_for_framework(session, record._root)


## 对 Node3D root 设置指定全局变换；其他节点类型不执行写入。
## [br]
## @api private
func _apply_spawn_transform(root: Node, spawn_transform: Transform3D) -> void:
	if root is Node3D:
		var root_3d: Node3D = root
		root_3d.global_transform = spawn_transform


## 终止尚未提交的事务：中止 reservations、退役 records、回滚 task 并发出失败信号。
## [br]
## @api private
func _abort_precommit(
	reservations: Array[GFProjectileLaunchReservation],
	records: Array[_RetirementRecord],
	task: GFProjectileEmissionTask,
	reason: StringName,
	details: Dictionary = {}
) -> void:
	for reservation: GFProjectileLaunchReservation in reservations:
		var _aborted: bool = reservation.abort_for_framework(self, reason)
	for record: _RetirementRecord in records:
		_retire_now(record)
	var _rolled_back: Dictionary = task.rollback(reason)
	_emit_failure(reason, details)


## 在 session 激活前中止已 deferred commit 的事务，并请求 receipt 补偿。
## [br]
## @api private
func _abort_committed_pre_activation(
	receipt: GFProjectileEmissionReceipt,
	reservations: Array[GFProjectileLaunchReservation],
	records: Array[_RetirementRecord],
	reason: StringName
) -> void:
	for reservation: GFProjectileLaunchReservation in reservations:
		var _aborted: bool = reservation.abort_for_framework(self, reason)
	var _compensated: Dictionary = receipt.compensate_for_framework(reason)
	for record: _RetirementRecord in records:
		_retire_now(record)
	_emit_failure(reason, {})


## 清理激活阶段失败；没有已激活 session 时同时请求 receipt 补偿。
## [br]
## @api private
func _handle_activation_failure(
	receipt: GFProjectileEmissionReceipt,
	reservations: Array[GFProjectileLaunchReservation],
	sessions: Array[GFProjectileSession],
	records: Array[_RetirementRecord]
) -> void:
	for reservation: GFProjectileLaunchReservation in reservations:
		var _aborted: bool = reservation.abort_for_framework(
			self,
			&"activation_failed"
		)
	if sessions.is_empty():
		var _compensated: Dictionary = receipt.compensate_for_framework(&"activation_failed")
	_handle_active_failure(sessions, records)


## 以 INTERNAL_FAILURE 结束仍 active 的 session，并退役对应记录。
## [br]
## @api private
func _handle_active_failure(
	sessions: Array[GFProjectileSession],
	records: Array[_RetirementRecord]
) -> void:
	for session: GFProjectileSession in sessions:
		if session != null and is_instance_valid(session) and session.is_active():
			var _finished: bool = session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE)
	for record: _RetirementRecord in records:
		_retire(record)


## 仅当记录仍有效时调用其退役方法；null 或已释放实例会被忽略。
## [br]
## @api private
## [br]
func _retire(record: _RetirementRecord) -> void:
	if record != null and is_instance_valid(record):
		record._retire()


## 将记录转交统一的退役入口。
## [br]
## @api private
func _retire_now(record: _RetirementRecord) -> void:
	_retire(record)


## 减少 emitter 通知屏障深度，并将结果限制为非负数。
## [br]
## @api private
func _release_notification_barrier() -> void:
	_notification_barrier_depth = maxi(_notification_barrier_depth - 1, 0)


## 为数组中的有效 session 释放通知屏障。
## [br]
## @api private
func _release_session_barriers(sessions: Array[GFProjectileSession]) -> void:
	for session: GFProjectileSession in sessions:
		if session != null and is_instance_valid(session):
			var _released: Error = session.release_notification_barrier_for_framework()


## 只启动一次释放代际，处置私有池并结束或退役尚在跟踪的记录。
## [br]
## @api private
func _begin_emitter_release() -> void:
	if _is_releasing:
		return
	_is_releasing = true
	_release_generation += 1
	if _private_pool != null:
		if _notification_barrier_depth > 0:
			_private_pool.dispose.call_deferred()
		else:
			_private_pool.dispose()
		_private_pool = null
	var records: Array[_RetirementRecord] = _active_retirements.duplicate()
	for record: _RetirementRecord in records:
		if record == null or not is_instance_valid(record):
			continue
		var session: GFProjectileSession = record._session
		if session != null and is_instance_valid(session) and session.is_active():
			var _finished: bool = session.finish(
				GFProjectileSession.EndReason.EMITTER_RELEASED
			)
		elif session == null:
			record._retire()


## 在对象删除通知中结算全部退役记录、释放 session 屏障并清空跟踪列表。
## [br]
## @api private
func _settle_predelete_retirements() -> void:
	var records: Array[_RetirementRecord] = _active_retirements.duplicate()
	for record: _RetirementRecord in records:
		if record == null or not is_instance_valid(record):
			continue
		var session: GFProjectileSession = record._session
		if session != null and is_instance_valid(session):
			if session.is_active():
				var _finished: bool = session.finish(
					GFProjectileSession.EndReason.EMITTER_RELEASED
				)
			var _barrier_released: Error = (
				session.release_notification_barrier_for_framework()
			)
		record._retire()
	_active_retirements.clear()


## 观察发布期间的删除状态；必要时先启动释放，再比较释放代际。
## [br]
## @api private
func _observe_publication_release(start_generation: int) -> bool:
	if is_queued_for_deletion() and not _is_releasing:
		_begin_emitter_release()
	return _release_generation != start_generation


## 确认 emitter 未释放且请求开始代际仍匹配。
## [br]
## @api private
func _request_is_current(start_generation: int) -> bool:
	if is_queued_for_deletion() and not _is_releasing:
		_begin_emitter_release()
	return not _is_releasing and _release_generation == start_generation


## 保存失败原因并发出限制长度与内容的失败信号。
## [br]
## @api private
func _emit_failure(reason: StringName, details: Dictionary) -> void:
	_emission_failure = reason
	projectile_emit_failed.emit(
		StringName(String(reason).left(128)),
		_bounded_failure_details(details)
	)


## 生成有界诊断字典：限制项目数、键集合、值类型和字符串长度。
## [br]
## @api private
func _bounded_failure_details(details: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value: Variant in details.keys():
		if result.size() >= 16:
			break
		var key_text: String = ""
		if typeof(key_value) == TYPE_STRING:
			var string_key: String = key_value
			key_text = string_key
		elif typeof(key_value) == TYPE_STRING_NAME:
			var name_key: StringName = key_value
			key_text = String(name_key)
		elif typeof(key_value) == TYPE_NODE_PATH:
			var path_key: NodePath = key_value
			key_text = String(path_key)
		else:
			continue
		var value: Variant = details[key_value]
		if (
			typeof(value) != TYPE_NIL
			and typeof(value) != TYPE_BOOL
			and typeof(value) != TYPE_INT
			and typeof(value) != TYPE_FLOAT
			and typeof(value) != TYPE_STRING
			and typeof(value) != TYPE_STRING_NAME
			and typeof(value) != TYPE_NODE_PATH
		):
			continue
		var key: StringName = StringName(key_text.left(64))
		if not _failure_detail_key_is_allowed(key):
			continue
		if typeof(value) == TYPE_STRING:
			var string_value: String = value
			result[key] = string_value.left(256)
		elif typeof(value) == TYPE_STRING_NAME:
			var name_value: StringName = value
			result[key] = StringName(String(name_value).left(128))
		elif typeof(value) == TYPE_NODE_PATH:
			var path_value: NodePath = value
			result[key] = NodePath(String(path_value).left(256))
		elif typeof(value) == TYPE_FLOAT:
			var float_value: float = value
			if is_finite(float_value):
				result[key] = float_value
		else:
			result[key] = value
	return result


## 判断失败详情键是否属于对外允许的固定白名单。
## [br]
## @api private
func _failure_detail_key_is_allowed(key: StringName) -> bool:
	return key in [
		&"ok",
		&"reason",
		&"binding_failure_reason",
		&"policy_id",
		&"projectile_id",
		&"requested_count",
		&"emit_count",
		&"emitted_count",
		&"hard_limit",
		&"now_msec",
		&"state",
		&"published",
		&"committed",
		&"compensated",
		&"rolled_back",
		&"remaining_cooldown_seconds",
		&"available_charges",
		&"required_charges",
		&"consumed_charges",
		&"emission_count",
		&"policy_instance_id",
		&"policy_state_generation",
		&"policy_enabled",
	]


# --- 信号处理函数 ---

## 结算回调只从当前 emitter 的退役集合移除该记录。
## [br]
## @api private
func _on_retirement_record_settled(record: _RetirementRecord) -> void:
	_active_retirements.erase(record)


# --- 内部类 ---

## 关联一次池 lease、root、reservation 或 session，并负责一次性退役与结算。
## [br]
## @api private
class _RetirementRecord:
	extends Node

	# --- 私有变量 ---

	## 租约对应的实例根节点；结算时清空，退出树可触发退役。
	## [br]
	## @api private
	var _root: Node = null

	## 持有到结算完成的对象池租约，退役时请求 release。
	## [br]
	## @api private
	var _lease: GFObjectPoolLease = null

	## 配置时保留的池引用，随结算一同清空。
	## [br]
	## @api private
	var _pool: GFObjectPoolUtility = null

	## 已绑定的发射 session；与未消费 reservation 互斥。
	## [br]
	## @api private
	var _session: GFProjectileSession = null

	## 尚未转为 session 的发射预留；失去退役 owner 时使其失效。
	## [br]
	## @api private
	var _reservation: GFProjectileLaunchReservation = null

	## 使未消费预留失效时必须匹配的退役 owner 标识。
	## [br]
	## @api private
	var _retirement_owner_id: int = 0

	## 结算是否已经开始；在释放引用和通知前置位，防止重复结算。
	## [br]
	## @api private
	var _retired: bool = false

	## 是否已经请求退役；在释放租约前置位，阻止重复 release 和新绑定。
	## [br]
	## @api private
	var _retirement_claimed: bool = false

	## 结算时通知 emitter 移除记录的回调；调用后清空。
	## [br]
	## @api private
	var _settled_callback: Callable = Callable()


	# --- 私有/辅助方法 ---

	## 捕获租约、池和 owner 身份，并单次订阅租约结算与根节点退出树通知。
	## [br]
	## @api private
	func _configure(
		lease: GFObjectPoolLease,
		pool: GFObjectPoolUtility,
		settled_callback: Callable,
		retirement_owner_id: int
	) -> void:
		_lease = lease
		_pool = pool
		_root = lease.get_node()
		_settled_callback = settled_callback
		_retirement_owner_id = retirement_owner_id
		var _settlement_connected: int = lease.settled.connect(_on_lease_settled, CONNECT_ONE_SHOT)
		if _root != null:
			var _exit_connected: int = _root.tree_exiting.connect(
				_on_root_tree_exiting, CONNECT_ONE_SHOT
			)


	## 在尚未退役且未绑定 session 时接管给定 session，清除预留引用并单次订阅其完成信号。
	## [br]
	## @api private
	func _bind_session(active_session: GFProjectileSession) -> Error:
		if _retirement_claimed or active_session == null or _session != null:
			return ERR_INVALID_PARAMETER
		_session = active_session
		_reservation = null
		return _session.finished.connect(_on_session_finished, CONNECT_ONE_SHOT) as Error


	## 仅在尚未退役且没有 session 或预留时接管 reservation，否则返回 ERR_INVALID_PARAMETER。
	## [br]
	## @api private
	func _bind_reservation(reservation: GFProjectileLaunchReservation) -> Error:
		if _retirement_claimed or reservation == null or _reservation != null or _session != null:
			return ERR_INVALID_PARAMETER
		_reservation = reservation
		return OK


	## 先取得一次性退役资格并断开根退出回调，再使未消费预留失效和释放租约；租约已结算时立即结算记录。
	## [br]
	## @api private
	func _retire() -> void:
		if _retirement_claimed:
			return
		_retirement_claimed = true
		if is_instance_valid(_root) and _root.tree_exiting.is_connected(_on_root_tree_exiting):
			_root.tree_exiting.disconnect(_on_root_tree_exiting)
		_release_unconsumed_reservation()
		var _released: bool = _lease.release()
		if _lease.is_settled():
			_settle_now()


	## 先标记已结算，再释放预留与 session 的终态退役占用，清空持有引用并通知 emitter，最后排队删除记录。
	## [br]
	## @api private
	func _settle_now() -> void:
		if _retired:
			return
		_retired = true
		_release_unconsumed_reservation()
		if _session != null:
			var runtime_value: Node = _session.get_runtime()
			if runtime_value is GFProjectile3D:
				var runtime: GFProjectile3D = runtime_value
				var _released: bool = runtime.release_terminal_retirement_for_framework(_session)
		_root = null
		_lease = null
		_pool = null
		_session = null
		_reservation = null
		if _settled_callback.is_valid():
			var _settled: Variant = _settled_callback.call(self)
		_settled_callback = Callable()
		queue_free()


	## 按精确 owner 标识使尚未消费的 reservation 失效，并清除本记录引用。
	## [br]
	## @api private
	func _release_unconsumed_reservation() -> void:
		if _reservation != null:
			var _invalidated: bool = _reservation.invalidate_lost_owner_for_framework(
				_retirement_owner_id, &"allocator_owner_lost"
			)
			_reservation = null


	# --- 信号处理函数 ---

	## 租约结算时，以 ROOT_LOST 结束仍活跃的 session，随后幂等结算记录。
	## [br]
	## @api private
	func _on_lease_settled(_reason: StringName) -> void:
		if _session != null and _session.is_active():
			var _finished: bool = _session.finish(GFProjectileSession.EndReason.ROOT_LOST)
		_settle_now()


	## 根节点退出时结束仍活跃的 session；没有活跃 session 时直接发起退役。
	## [br]
	## @api private
	func _on_root_tree_exiting() -> void:
		if _session != null and _session.is_active():
			var _finished: bool = _session.finish(GFProjectileSession.EndReason.ROOT_LOST)
		else:
			_retire()


	## session 终结后发起一次性退役，不依赖具体结束原因。
	## [br]
	## @api private
	func _on_session_finished(_finished_session: GFProjectileSession, _reason: int) -> void:
		_retire()


## 保存 3D definition 的关键资源与路径身份，供发射提交前重复校验。
## [br]
## @api private
class _DefinitionSnapshot:
	extends RefCounted

	# --- 私有变量 ---

	## 发射预检捕获的定义资源引用，供提交前核对配置。
	## [br]
	## @api private
	var _definition: GFProjectileDefinition3D = null

	## 捕获的场景资源身份；校验时要求定义仍指向同一资源。
	## [br]
	## @api private
	var _scene: PackedScene = null

	## 捕获的 runtime 路径值，供提交前比较。
	## [br]
	## @api private
	var _runtime_path: NodePath = NodePath("")

	## 捕获的命中来源路径序列，供提交前按数组值比较。
	## [br]
	## @api private
	var _impact_source_paths: Array[NodePath] = []

	## 捕获的运动策略资源身份，不复制策略内容。
	## [br]
	## @api private
	var _motion: GFProjectileMotion = null

	## 捕获的可空生命周期策略资源身份。
	## [br]
	## @api private
	var _lifetime: GFProjectileLifetimePolicy = null

	## 捕获的 body adapter 资源身份，校验时还要求实例有效。
	## [br]
	## @api private
	var _body_adapter: GFProjectileBodyAdapter3D = null


	# --- 私有/辅助方法 ---

	## 复核定义及必要资源仍有效，且场景、路径与策略引用仍匹配捕获值；不检查资源内部属性是否变化。
	## [br]
	## @api private
	func _is_current() -> bool:
		return (
			_definition != null
			and is_instance_valid(_definition)
			and _scene != null
			and is_instance_valid(_scene)
			and _definition.scene == _scene
			and _definition.runtime_path == _runtime_path
			and _definition.impact_source_paths == _impact_source_paths
			and _motion != null
			and is_instance_valid(_motion)
			and _definition.motion == _motion
			and _definition.lifetime_policy == _lifetime
			and (_lifetime == null or is_instance_valid(_lifetime))
			and _body_adapter != null
			and is_instance_valid(_body_adapter)
			and _definition.body_adapter == _body_adapter
		)
