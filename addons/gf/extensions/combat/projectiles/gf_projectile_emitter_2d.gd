## GFProjectileEmitter2D: 以两阶段事务发射 typed 2D projectile definition。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFProjectileEmitter2D
extends Node2D


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
	launch_input: GFProjectileLaunchInput2D
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


class _RetirementRecord:
	extends Node

	var _root: Node = null
	var _root_instance_id: int = 0
	var _scene: PackedScene = null
	var _pool: GFObjectPoolUtility = null
	var _session: GFProjectileSession = null
	var _reservation: GFProjectileLaunchReservation = null
	var _retirement_owner_id: int = 0
	var _retired: bool = false
	var _retirement_claimed: bool = false
	var _root_tree_exiting: bool = false
	var _force_deferred_pool: bool = false
	var _settled_callback: Callable = Callable()

	func _configure(
		projectile_scene: PackedScene,
		pool: GFObjectPoolUtility,
		settled_callback: Callable,
		retirement_owner_id: int
	) -> void:
		_scene = projectile_scene
		_pool = pool
		_settled_callback = settled_callback
		_retirement_owner_id = retirement_owner_id

	func _bind_root(projectile_root: Node) -> Error:
		if (
			_retirement_claimed
			or projectile_root == null
			or not is_instance_valid(projectile_root)
			or projectile_root.is_queued_for_deletion()
		):
			return ERR_INVALID_PARAMETER
		if _root != null and _root != projectile_root:
			return ERR_ALREADY_IN_USE
		_root = projectile_root
		_root_instance_id = projectile_root.get_instance_id()
		if not _root.tree_exiting.is_connected(_on_root_tree_exiting):
			var connected: int = _root.tree_exiting.connect(
				_on_root_tree_exiting,
				CONNECT_ONE_SHOT
			)
			if connected != OK:
				return connected as Error
		return OK

	func _bind_session(active_session: GFProjectileSession) -> Error:
		if (
			_retirement_claimed
			or active_session == null
			or not is_instance_valid(active_session)
			or _session != null
		):
			return ERR_INVALID_PARAMETER
		_session = active_session
		_reservation = null
		var connected: int = _session.finished.connect(
			_on_session_finished,
			CONNECT_ONE_SHOT
		)
		if connected != OK:
			return connected as Error
		return OK

	func _bind_reservation(reservation: GFProjectileLaunchReservation) -> Error:
		if (
			_retirement_claimed
			or reservation == null
			or not is_instance_valid(reservation)
			or _reservation != null
			or _session != null
		):
			return ERR_INVALID_PARAMETER
		_reservation = reservation
		return OK

	func _defer_pool_retirement() -> void:
		_force_deferred_pool = true

	func _retire(force_deferred_pool: bool = false) -> void:
		if _retirement_claimed:
			return
		_retirement_claimed = true
		_force_deferred_pool = _force_deferred_pool or force_deferred_pool
		var root_requires_deferred_settlement: bool = (
			_root_tree_exiting
			or _root == null
			or not is_instance_valid(_root)
			or _root.is_queued_for_deletion()
			or not _root.is_inside_tree()
		)
		if (
			root_requires_deferred_settlement
			or (
				_pool != null
				and is_instance_valid(_pool)
				and _force_deferred_pool
			)
		):
			call_deferred(&"_settle_now")
			return
		_settle_now()

	func _settle_now() -> void:
		if _retired:
			return
		_retired = true
		var managed_session: GFProjectileSession = _session
		var projectile_root: Node = _root
		var projectile_root_id: int = _root_instance_id
		var projectile_scene: PackedScene = _scene
		var pool: GFObjectPoolUtility = _pool
		_release_unconsumed_reservation()
		if pool != null and is_instance_valid(pool):
			if projectile_root != null and is_instance_valid(projectile_root):
				var released_to_pool: bool = pool.release_for_framework(
					projectile_root,
					projectile_scene
				)
				if not released_to_pool and not projectile_root.is_queued_for_deletion():
					projectile_root.queue_free()
			elif projectile_root_id > 0:
				var _lost_retired: bool = pool.retire_lost_lease_for_framework(
					projectile_scene,
					projectile_root_id
				)
		elif (
			projectile_root != null
			and is_instance_valid(projectile_root)
			and not projectile_root.is_queued_for_deletion()
		):
			projectile_root.queue_free()
		_release_terminal_claim(managed_session)
		_root = null
		_root_instance_id = 0
		_scene = null
		_pool = null
		_session = null
		_reservation = null
		_retirement_owner_id = 0
		if _settled_callback.is_valid():
			var _settled: Variant = _settled_callback.call(self)
		_settled_callback = Callable()
		queue_free()

	func _release_terminal_claim(managed_session: GFProjectileSession) -> void:
		if managed_session == null or not is_instance_valid(managed_session):
			return
		var runtime_value: Node = managed_session.get_runtime()
		if runtime_value is GFProjectile2D:
			var runtime: GFProjectile2D = runtime_value
			var _released: bool = runtime.release_terminal_retirement_for_framework(
				managed_session
			)

	func _release_unconsumed_reservation() -> void:
		if _reservation == null or not is_instance_valid(_reservation):
			return
		var _invalidated: bool = _reservation.invalidate_lost_owner_for_framework(
			_retirement_owner_id,
			&"allocator_owner_lost"
		)

	func _on_root_tree_exiting() -> void:
		_root_tree_exiting = true
		_force_deferred_pool = true
		if _session != null and is_instance_valid(_session) and _session.is_active():
			var _finished: bool = _session.finish(
				GFProjectileSession.EndReason.ROOT_LOST
			)
		elif _session == null:
			_retire(true)

	func _on_session_finished(
		_finished_session: GFProjectileSession,
		_reason: int
	) -> void:
		var root_is_exiting: bool = (
			_root == null
			or not is_instance_valid(_root)
			or not _root.is_inside_tree()
		)
		_retire(_force_deferred_pool or _root_tree_exiting or root_is_exiting)


class _DefinitionSnapshot:
	extends RefCounted

	var _definition: GFProjectileDefinition2D = null
	var _scene: PackedScene = null
	var _runtime_path: NodePath = NodePath("")
	var _impact_source_paths: Array[NodePath] = []
	var _motion: GFProjectileMotion = null
	var _lifetime: GFProjectileLifetimePolicy = null
	var _body_adapter: GFProjectileBodyAdapter2D = null

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


const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


## 未使用 catalog ID 时的直接 typed definition。
## [br]
## @api public
## [br]
## @since unreleased
@export var projectile_definition: GFProjectileDefinition2D = null

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

## 可选 typed 2D spawn pattern。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var spawn_pattern: GFProjectileSpawnPattern2D = null

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
## @since unreleased
@export var default_launch_input: GFProjectileLaunchInput2D = null

## 相对 emitter 的生成父节点路径；空路径使用当前父节点。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_node_path("Node") var spawn_parent_path: NodePath = NodePath("")

## 是否从 `object_pool_utility` 获取和归还完整实例 root。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var use_object_pool: bool = false


## pool 模式使用的 allocator；项目代码负责配置与生命周期。
## [br]
## @api public
## [br]
## @since 3.17.0
var object_pool_utility: GFObjectPoolUtility = null
var _notification_barrier_depth: int = 0
var _active_retirements: Array[_RetirementRecord] = []
var _is_releasing: bool = false
var _release_generation: int = 0
var _emission_in_progress: bool = false


func _enter_tree() -> void:
	_is_releasing = false


func _exit_tree() -> void:
	_begin_emitter_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_settle_predelete_retirements()


## 原子发射一个 2D projectile。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param launch_input: 可选 typed 调用输入。
## [br]
## @param projectile_id: 可选 catalog ID；空值使用默认配置。
## [br]
## @return: ACTIVE session 对应的完整 root；失败时返回 null。
func emit_projectile(
	launch_input: GFProjectileLaunchInput2D = null,
	projectile_id: StringName = &""
) -> Node:
	var roots: Array[Node] = emit_projectiles(launch_input, projectile_id, 1)
	return roots[0] if not roots.is_empty() else null


## 以两阶段事务原子发射一批 2D projectile。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param launch_input: 可选 typed 调用输入。
## [br]
## @param projectile_id: 可选 catalog ID；空值使用默认配置。
## [br]
## @param emit_count: 正数覆盖 pattern 数量；负值使用 pattern 默认值。
## [br]
## @return: 全批 ACTIVE 的完整 root；事务失败或发布期间 emitter release 时返回空数组。
## callback 内 `remove_child()`、`queue_free()` 或 `call_deferred("free")` 均保持完整
## started、emitted、finished 顺序与 exact retirement。Godot 原生禁止在对象自身 public call
## 或 signal emission 锁内同步 `free()`；该非法输入不属于本方法的支持契约。
## [br]
## @schema return: Array[Node]，按 spawn transform 稳定顺序排列的 allocator-managed root。
func emit_projectiles(
	launch_input: GFProjectileLaunchInput2D = null,
	projectile_id: StringName = &"",
	emit_count: int = -1
) -> Array[Node]:
	if _is_releasing or _emission_in_progress or is_queued_for_deletion():
		return []
	_emission_in_progress = true
	var emitter_lifetime_ref: WeakRef = weakref(self)
	var result: Array[Node] = _emit_projectiles_transaction(
		launch_input,
		projectile_id,
		emit_count
	)
	var emitter_after_transaction_value: Variant = emitter_lifetime_ref.get_ref()
	if (
		typeof(emitter_after_transaction_value) == TYPE_OBJECT
		and is_instance_valid(emitter_after_transaction_value)
		and emitter_after_transaction_value is GFProjectileEmitter2D
	):
		var emitter_after_transaction: GFProjectileEmitter2D = (
			emitter_after_transaction_value
		)
		emitter_after_transaction._emission_in_progress = false
	return result


func _emit_projectiles_transaction(
	launch_input: GFProjectileLaunchInput2D,
	projectile_id: StringName,
	emit_count: int
) -> Array[Node]:
	var emitter_lifetime_ref: WeakRef = weakref(self)
	var retirement_owner_id: int = get_instance_id()
	var request_release_generation: int = _release_generation
	var effective_id: StringName = projectile_id if projectile_id != &"" else default_projectile_id
	var definition: GFProjectileDefinition2D = resolve_projectile_definition(effective_id)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if not _request_is_current(request_release_generation):
		_emit_failure(&"emitter_released", {})
		return []
	if definition == null or not is_instance_valid(definition):
		_emit_failure(&"missing_definition", { "projectile_id": effective_id })
		return []
	var definition_scene: PackedScene = definition.scene
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if definition_scene == null or not is_instance_valid(definition_scene):
		_emit_failure(&"missing_definition", { "projectile_id": effective_id })
		return []
	var merged_input: GFProjectileLaunchInput2D = _merge_launch_input(
		launch_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	var prepare_report: Dictionary = task.prepare()
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	var transforms: Array[Transform2D] = _get_spawn_transforms(merged_input, allowed_count)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return []
	if definition_snapshot == null:
		_abort_precommit([], [], task, &"invalid_definition")
		return []
	var projectile_scene: PackedScene = definition_snapshot._scene
	var spawn_parent: Node = resolve_spawn_parent()
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	var inputs: Array[GFProjectileLaunchInput2D] = []
	var records: Array[_RetirementRecord] = []
	var pool_snapshot: GFObjectPoolUtility = (
		object_pool_utility
		if use_object_pool and is_instance_valid(object_pool_utility)
		else null
	)
	if use_object_pool and pool_snapshot == null:
		_abort_precommit([], [], task, &"pool_unavailable")
		return []
	for spawn_transform: Transform2D in transforms:
		var allocation_fence_reason: StringName = _precommit_fence_failure_reason(
			request_release_generation,
			definition_snapshot,
			spawn_parent
		)
		if allocation_fence_reason != &"":
			_abort_precommit([], records, task, allocation_fence_reason)
			return []
		var record: _RetirementRecord = _allocate_candidate(
			projectile_scene,
			spawn_parent,
			pool_snapshot
		)
		if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
			return []
		if record == null:
			_abort_precommit([], records, task, &"instantiate_failed")
			return []
		records.append(record)
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
		if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
		if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
			return []
		if (
			typeof(candidate_input_value) != TYPE_OBJECT
			or not is_instance_valid(candidate_input_value)
			or not candidate_input_value is GFProjectileLaunchInput2D
		):
			_abort_precommit([], records, task, &"launch_input_invalidated")
			return []
		var candidate_input: GFProjectileLaunchInput2D = candidate_input_value
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
		var binding: GFProjectileBinding2D = definition.bind_instance(roots[index])
		if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
		if not runtime_value is GFProjectile2D:
			_abort_precommit(reservations, records, task, &"runtime_unavailable")
			return []
		var runtime: GFProjectile2D = runtime_value
		var reservation: GFProjectileLaunchReservation = runtime.reserve_launch_for_framework(
			binding,
			inputs[index],
			self
		)
		if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
	var receipt: GFProjectileEmissionReceipt = task.commit_deferred_for_framework(roots.size())
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
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
		if runtime_value is GFProjectile2D:
			var runtime: GFProjectile2D = runtime_value
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
	if not _publication_sessions_are_current(sessions, records):
		_handle_active_failure(sessions, records)
		_release_session_barriers(sessions)
		_release_notification_barrier()
		_emit_failure(&"publication_invalidated", {})
		return []
	var released_during_publication: bool = _observe_publication_release(
		request_release_generation
	)
	for index: int in range(sessions.size()):
		var runtime_value: Node = sessions[index].get_runtime()
		if runtime_value is GFProjectile2D:
			var runtime: GFProjectile2D = runtime_value
			var _started: Error = runtime.publish_started_for_framework(sessions[index])
		var emitter_after_started_value: Variant = emitter_lifetime_ref.get_ref()
		if (
			typeof(emitter_after_started_value) != TYPE_OBJECT
			or not is_instance_valid(emitter_after_started_value)
		):
			return []
		if not _publication_candidate_is_current(sessions[index], records[index]):
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
		if not _publication_candidate_is_current(sessions[index], records[index]):
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
	return roots


## 解析本次发射使用的 typed 2D definition。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param projectile_id: 可选 catalog ID。
## [br]
## @return: 匹配的 2D definition；缺失或维度不匹配时返回 null。
func resolve_projectile_definition(
	projectile_id: StringName = &""
) -> GFProjectileDefinition2D:
	if projectile_catalog != null and projectile_id != &"":
		var catalog_definition: GFProjectileDefinition = projectile_catalog.get_definition(projectile_id)
		if catalog_definition is GFProjectileDefinition2D:
			var typed_definition: GFProjectileDefinition2D = catalog_definition
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


## 预热指定 definition 的 pool 实例。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param count: 要预热的正数量。
## [br]
## @param projectile_id: 可选 catalog ID。
## [br]
## @return: 是否已向配置的 pool 提交预热。
func prewarm_projectiles(count: int, projectile_id: StringName = &"") -> bool:
	if (
		count <= 0
		or object_pool_utility == null
		or not is_instance_valid(object_pool_utility)
		or _is_releasing
		or _emission_in_progress
		or is_queued_for_deletion()
	):
		return false
	_emission_in_progress = true
	var emitter_lifetime_ref: WeakRef = weakref(self)
	var request_release_generation: int = _release_generation
	var pool: GFObjectPoolUtility = object_pool_utility
	var effective_id: StringName = projectile_id if projectile_id != &"" else default_projectile_id
	var definition: GFProjectileDefinition2D = resolve_projectile_definition(effective_id)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return false
	var spawn_parent: Node = resolve_spawn_parent()
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return false
	var projectile_scene: PackedScene = (
		definition.scene
		if definition != null and is_instance_valid(definition)
		else null
	)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return false
	if (
		definition == null
		or not is_instance_valid(definition)
		or projectile_scene == null
		or not is_instance_valid(projectile_scene)
		or spawn_parent == null
		or not is_instance_valid(spawn_parent)
		or spawn_parent.is_queued_for_deletion()
		or not is_instance_valid(pool)
		or pool != object_pool_utility
		or not _request_is_current(request_release_generation)
	):
		_emission_in_progress = false
		return false
	pool.prewarm(projectile_scene, spawn_parent, count)
	if not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref):
		return false
	var succeeded: bool = (
		_request_is_current(request_release_generation)
		and is_instance_valid(pool)
		and pool == object_pool_utility
	)
	_emission_in_progress = false
	return succeeded


func _merge_launch_input(
	call_input: GFProjectileLaunchInput2D,
	request_release_generation: int,
	emitter_lifetime_ref: WeakRef
) -> GFProjectileLaunchInput2D:
	var result: GFProjectileLaunchInput2D = _snapshot_external_launch_input(
		default_launch_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if result == null:
		return null
	if call_input == null:
		return result
	var call_snapshot: GFProjectileLaunchInput2D = _snapshot_external_launch_input(
		call_input,
		request_release_generation,
		emitter_lifetime_ref
	)
	if call_snapshot == null:
		return null
	match call_snapshot.get_target_kind():
		GFProjectileLaunchInput2D.TargetKind.NODE:
			result.set_target_node(call_snapshot.get_target_node())
		GFProjectileLaunchInput2D.TargetKind.POSITION:
			result.set_target_position(call_snapshot.get_target_position())
		_:
			result.set_target_none()
	var metadata: Dictionary = result.get_metadata()
	var call_metadata: Dictionary = call_snapshot.get_metadata()
	for key: Variant in call_metadata.keys():
		metadata[key] = call_metadata[key]
	result.set_metadata(metadata)
	return result


func _snapshot_external_launch_input(
	source: GFProjectileLaunchInput2D,
	request_release_generation: int,
	emitter_lifetime_ref: WeakRef
) -> GFProjectileLaunchInput2D:
	var result: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	if source == null:
		return result
	if not is_instance_valid(source):
		return null
	var kind_value: Variant = source.call(&"get_target_kind")
	if (
		not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref)
		or not is_instance_valid(source)
		or not _request_is_current(request_release_generation)
		or typeof(kind_value) != TYPE_INT
	):
		return null
	var kind: int = kind_value
	match kind:
		GFProjectileLaunchInput2D.TargetKind.NODE:
			var target_value: Variant = source.call(&"get_target_node")
			if (
				not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref)
				or not is_instance_valid(source)
				or not _request_is_current(request_release_generation)
			):
				return null
			if target_value == null:
				result.set_target_none()
			elif (
				typeof(target_value) == TYPE_OBJECT
				and is_instance_valid(target_value)
				and target_value is Node2D
			):
				var target: Node2D = target_value
				if target.is_queued_for_deletion():
					return null
				result.set_target_node(target)
			else:
				return null
		GFProjectileLaunchInput2D.TargetKind.POSITION:
			var position_value: Variant = source.call(&"get_target_position")
			if (
				not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref)
				or not is_instance_valid(source)
				or not _request_is_current(request_release_generation)
				or typeof(position_value) != TYPE_VECTOR2
			):
				return null
			var target_position: Vector2 = position_value
			result.set_target_position(target_position)
		GFProjectileLaunchInput2D.TargetKind.NONE:
			result.set_target_none()
		_:
			return null
	var metadata_value: Variant = source.call(&"get_metadata")
	if (
		not GFProjectileEmitter2D._lifetime_ref_is_live(emitter_lifetime_ref)
		or not is_instance_valid(source)
		or not _request_is_current(request_release_generation)
		or typeof(metadata_value) != TYPE_DICTIONARY
	):
		return null
	var metadata: Dictionary = metadata_value
	result.set_metadata(metadata)
	return result


func _resolve_requested_count(emit_count: int) -> int:
	if spawn_pattern != null:
		return spawn_pattern.resolve_spawn_count(emit_count)
	return emit_count if emit_count > 0 else 1


func _get_spawn_transforms(
	launch_input: GFProjectileLaunchInput2D,
	emit_count: int
) -> Array[Transform2D]:
	if spawn_pattern != null:
		return spawn_pattern.get_spawn_transforms(self, launch_input, emit_count)
	var result: Array[Transform2D] = []
	for _index: int in range(maxi(emit_count, 0)):
		result.append(global_transform)
	return result


func _filter_finite_transforms(values: Array[Transform2D]) -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for value: Transform2D in values:
		if _GF_COMBAT_FINITE_MATH.is_finite_transform2d(value):
			result.append(value)
	return result


static func _lifetime_ref_is_live(emitter_lifetime_ref: WeakRef) -> bool:
	if emitter_lifetime_ref == null:
		return false
	var emitter_value: Variant = emitter_lifetime_ref.get_ref()
	return (
		typeof(emitter_value) == TYPE_OBJECT
		and is_instance_valid(emitter_value)
		and emitter_value is GFProjectileEmitter2D
	)


func _allocate_candidate(
	scene: PackedScene,
	spawn_parent: Node,
	pool: GFObjectPoolUtility
) -> _RetirementRecord:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.root == null:
		return null
	var record: _RetirementRecord = _RetirementRecord.new()
	record.name = &"GFProjectileRetirementRecord2D"
	record.process_mode = Node.PROCESS_MODE_DISABLED
	record._configure(scene, pool, _on_retirement_record_settled, get_instance_id())
	scene_tree.root.add_child(record)
	_active_retirements.append(record)
	var root_value: Variant = null
	if pool != null:
		if not is_instance_valid(pool):
			record._retire()
			return null
		root_value = pool.acquire(scene, spawn_parent, record._bind_root)
	else:
		root_value = scene.instantiate()
	if (
		typeof(root_value) != TYPE_OBJECT
		or not is_instance_valid(root_value)
		or not root_value is Node
	):
		record._retire()
		return null
	var root: Node = root_value
	if record._bind_root(root) != OK:
		record._retire()
		return null
	if (
		pool == null
		and is_instance_valid(spawn_parent)
		and not spawn_parent.is_queued_for_deletion()
		and not root.is_queued_for_deletion()
	):
		spawn_parent.add_child(root)
	return record


func _record_root_is_live(record: _RetirementRecord) -> bool:
	return (
		record != null
		and record._root != null
		and is_instance_valid(record._root)
		and not record._root.is_queued_for_deletion()
	)


func _capture_definition_snapshot(
	definition: GFProjectileDefinition2D
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
	):
		return &"spawn_parent_lost"
	return &""


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
	if not runtime_value is GFProjectile2D:
		return false
	var runtime: GFProjectile2D = runtime_value
	return runtime.publication_is_current_for_framework(session, record._root)


func _apply_spawn_transform(root: Node, spawn_transform: Transform2D) -> void:
	if root is Node2D:
		var root_2d: Node2D = root
		root_2d.global_transform = spawn_transform


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


func _handle_active_failure(
	sessions: Array[GFProjectileSession],
	records: Array[_RetirementRecord]
) -> void:
	for session: GFProjectileSession in sessions:
		if session != null and is_instance_valid(session) and session.is_active():
			var _finished: bool = session.finish(GFProjectileSession.EndReason.INTERNAL_FAILURE)
	for record: _RetirementRecord in records:
		_retire(record)


func _retire(record: _RetirementRecord) -> void:
	if record != null and is_instance_valid(record):
		record._retire()


func _retire_now(record: _RetirementRecord) -> void:
	_retire(record)


func _release_notification_barrier() -> void:
	_notification_barrier_depth = maxi(_notification_barrier_depth - 1, 0)


func _release_session_barriers(sessions: Array[GFProjectileSession]) -> void:
	for session: GFProjectileSession in sessions:
		if session != null and is_instance_valid(session):
			var _released: Error = session.release_notification_barrier_for_framework()


func _begin_emitter_release() -> void:
	if _is_releasing:
		return
	_is_releasing = true
	_release_generation += 1
	var records: Array[_RetirementRecord] = _active_retirements.duplicate()
	for record: _RetirementRecord in records:
		if record == null or not is_instance_valid(record):
			continue
		record._defer_pool_retirement()
		var session: GFProjectileSession = record._session
		if session != null and is_instance_valid(session) and session.is_active():
			var _finished: bool = session.finish(
				GFProjectileSession.EndReason.EMITTER_RELEASED
			)
		elif session == null:
			record._retire(true)


func _settle_predelete_retirements() -> void:
	var records: Array[_RetirementRecord] = _active_retirements.duplicate()
	for record: _RetirementRecord in records:
		if record == null or not is_instance_valid(record):
			continue
		record._defer_pool_retirement()
		var session: GFProjectileSession = record._session
		if session != null and is_instance_valid(session):
			if session.is_active():
				var _finished: bool = session.finish(
					GFProjectileSession.EndReason.EMITTER_RELEASED
				)
			var _barrier_released: Error = (
				session.release_notification_barrier_for_framework()
			)
		record._retire(true)
	_active_retirements.clear()


func _on_retirement_record_settled(record: _RetirementRecord) -> void:
	_active_retirements.erase(record)


func _observe_publication_release(start_generation: int) -> bool:
	if is_queued_for_deletion() and not _is_releasing:
		_begin_emitter_release()
	return _release_generation != start_generation


func _request_is_current(start_generation: int) -> bool:
	if is_queued_for_deletion() and not _is_releasing:
		_begin_emitter_release()
	return not _is_releasing and _release_generation == start_generation


func _emit_failure(reason: StringName, details: Dictionary) -> void:
	projectile_emit_failed.emit(
		StringName(String(reason).left(128)),
		_bounded_failure_details(details)
	)


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
