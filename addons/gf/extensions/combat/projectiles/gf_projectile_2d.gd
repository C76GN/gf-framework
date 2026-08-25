## GFProjectile2D: 2D projectile scene 内的 dimension-neutral runtime 节点。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFProjectile2D
extends Node


const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


## session 已 ACTIVE 且允许发布 started 时发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param session: 本 runtime 的当前 session。
signal projectile_started(session: GFProjectileSession)

## 当前 session 首次结束时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param session: 已结算 session。
## [br]
## @param reason: `GFProjectileSession.EndReason` 枚举值。
signal projectile_finished(session: GFProjectileSession, reason: int)


var _active_session: GFProjectileSession = null
var _binding: GFProjectileBinding2D = null
var _launch_input: GFProjectileLaunchInput2D = null
var _motion_state: GFProjectileMotionState = null
var _current_body: GFProjectileBodyResult2D = null
var _generation: int = 0
var _launch_claim: GFProjectileLaunchReservation = null
var _managed_retirement_session: GFProjectileSession = null
var _direct_preparing: bool = false
var _prepared_binding: GFProjectileBinding2D = null
var _prepared_input: GFProjectileLaunchInput2D = null
var _prepared_motion: GFProjectileMotion = null
var _prepared_lifetime: GFProjectileLifetimePolicy = null
var _prepared_adapter: GFProjectileBodyAdapter2D = null
var _prepared_state: GFProjectileMotionState = null
var _prepared_body: GFProjectileBodyResult2D = null
var _active_motion: GFProjectileMotion = null
var _active_lifetime: GFProjectileLifetimePolicy = null
var _active_adapter: GFProjectileBodyAdapter2D = null
var _impact_sources: Array[Node] = []
var _impact_callbacks: Array[Callable] = []
var _body_application_session: GFProjectileSession = null
var _terminal_cleanup_pending: bool = false


func _ready() -> void:
	set_physics_process(false)


func _exit_tree() -> void:
	if (
		_active_session != null
		and is_instance_valid(_active_session)
		and _active_session.is_active()
	):
		var session: GFProjectileSession = _active_session
		var root_value: Variant = session.get_instance_root()
		var root_is_exiting: bool = false
		if (
			typeof(root_value) == TYPE_OBJECT
			and is_instance_valid(root_value)
			and root_value is Node
		):
			var root: Node = root_value
			root_is_exiting = not root.is_inside_tree()
		if root_is_exiting:
			var _root_lost: bool = session.finish(
				GFProjectileSession.EndReason.ROOT_LOST
			)
		else:
			# Root/ancestor 的 tree_exiting 信号在 child runtime 的 _exit_tree 之后。
			# 延迟 RUNTIME_LOST 一拍，让真实 ROOT_LOST 保持 first-wins，也避免在
			# Node 的 children lock 内触发 allocator retirement。
			var _deferred_finish: Variant = session.call_deferred(
				&"finish",
				GFProjectileSession.EndReason.RUNTIME_LOST
			)


func _physics_process(delta: float) -> void:
	if _active_session == null:
		return
	if not is_instance_valid(_active_session):
		_discard_invalid_active_state()
		return
	if not _active_session.is_active():
		return
	var session: GFProjectileSession = _active_session
	var root: Node = session.get_instance_root()
	var binding_value: Variant = _binding
	var motion_value: Variant = _active_motion
	var adapter_value: Variant = _active_adapter
	if not _step_topology_is_current(session, root, binding_value):
		return
	if not _is_live_object_of_type(motion_value, GFProjectileMotion):
		var _motion_lost: bool = session.finish(GFProjectileSession.EndReason.MOTION_FAILED)
		return
	if not _is_live_object_of_type(adapter_value, GFProjectileBodyAdapter2D):
		var _adapter_lost: bool = session.finish(GFProjectileSession.EndReason.BODY_APPLICATION_FAILED)
		return
	var binding: GFProjectileBinding2D = binding_value
	var motion: GFProjectileMotion = motion_value
	var adapter: GFProjectileBodyAdapter2D = adapter_value
	var current_body_value: Variant = adapter.capture_body(root)
	if not _step_dependencies_are_current(session, root, binding, motion, adapter):
		return
	if not _is_live_object_of_type(current_body_value, GFProjectileBodyResult2D):
		var _capture_failed: bool = session.finish(GFProjectileSession.EndReason.BODY_APPLICATION_FAILED)
		return
	var current_body: GFProjectileBodyResult2D = current_body_value
	var intent_value: Variant = motion.compute_intent_2d(
		_motion_state,
		current_body,
		delta
	)
	if not _step_dependencies_are_current(session, root, binding, motion, adapter):
		return
	if not _is_live_object_of_type(intent_value, GFProjectileMotionIntent2D):
		var _missing_intent: bool = session.finish(
			GFProjectileSession.EndReason.INVALID_MOTION_INTENT
		)
		return
	var intent: GFProjectileMotionIntent2D = intent_value
	if not intent.is_valid():
		var reason: GFProjectileSession.EndReason = GFProjectileSession.EndReason.INVALID_MOTION_INTENT
		if intent.get_failure_reason() == &"target_lost":
			reason = GFProjectileSession.EndReason.TARGET_LOST
		var _intent_failed: bool = session.finish(reason)
		return
	if intent.get_kind() == GFProjectileMotionIntent2D.Kind.FINISH:
		var _motion_finished: bool = session.finish(
			GFProjectileSession.EndReason.MOTION_FINISHED
		)
		return
	_body_application_session = session
	var applied_body_value: Variant = adapter.apply_intent(root, intent)
	var session_survived_application: bool = is_instance_valid(session)
	var finished_during_application: bool = (
		session_survived_application and session.is_finished()
	)
	_body_application_session = null
	if not session_survived_application:
		_discard_invalid_active_state()
		return
	if not finished_during_application:
		if not _step_dependencies_are_current(session, root, binding, motion, adapter):
			_finalize_terminal_cleanup(session)
			return
	elif not _terminal_application_is_owned(session, root, binding, motion, adapter):
		_finalize_terminal_cleanup(session)
		return
	if not _is_live_object_of_type(applied_body_value, GFProjectileBodyResult2D):
		if session.is_active():
			var _apply_failed: bool = session.finish(
				GFProjectileSession.EndReason.BODY_APPLICATION_FAILED
			)
		_finalize_terminal_cleanup(session)
		return
	var applied_body: GFProjectileBodyResult2D = applied_body_value
	var displacement: Vector2 = applied_body.get_actual_displacement()
	if (
		not applied_body.is_successful()
		or not _GF_COMBAT_FINITE_MATH.is_finite_transform2d(applied_body.get_transform())
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(displacement)
	):
		if session.is_active():
			var _application_rejected: bool = session.finish(
				GFProjectileSession.EndReason.BODY_APPLICATION_FAILED
			)
		_finalize_terminal_cleanup(session)
		return
	_current_body = applied_body
	if finished_during_application:
		var _terminal_observed: Error = session.advance_terminal_body_result_for_framework(
			session.get_generation(),
			delta,
			displacement.length()
		)
		_finalize_terminal_cleanup(session)
		return
	session.advance_for_framework(delta, displacement.length())
	_evaluate_lifetime(session)


func _step_topology_is_current(
	session_value: Variant,
	root_value: Variant,
	binding_value: Variant
) -> bool:
	if not _is_live_object_of_type(session_value, GFProjectileSession):
		if _active_session != null and not is_instance_valid(_active_session):
			_discard_invalid_active_state()
		return false
	var session: GFProjectileSession = session_value
	if session != _active_session or not session.is_active():
		return false
	if not _is_live_node(root_value):
		var _root_lost: bool = session.finish(GFProjectileSession.EndReason.ROOT_LOST)
		return false
	var root: Node = root_value
	if session.get_instance_root() != root:
		var _root_identity_lost: bool = session.finish(GFProjectileSession.EndReason.ROOT_LOST)
		return false
	if not _is_live_object_of_type(binding_value, GFProjectileBinding2D):
		var _topology_lost: bool = session.finish(
			GFProjectileSession.EndReason.IMPACT_SOURCE_LOST
		)
		return false
	var binding: GFProjectileBinding2D = binding_value
	if binding != _binding or not binding.is_topology_current_for_framework():
		var _binding_lost: bool = session.finish(
			GFProjectileSession.EndReason.IMPACT_SOURCE_LOST
		)
		return false
	return true


func _terminal_application_is_owned(
	session_value: Variant,
	root_value: Variant,
	binding_value: Variant,
	motion_value: Variant,
	adapter_value: Variant
) -> bool:
	if (
		not _is_live_object_of_type(session_value, GFProjectileSession)
		or not _is_live_node(root_value)
		or not _is_live_object_of_type(binding_value, GFProjectileBinding2D)
		or not _is_live_object_of_type(motion_value, GFProjectileMotion)
		or not _is_live_object_of_type(adapter_value, GFProjectileBodyAdapter2D)
	):
		return false
	var session: GFProjectileSession = session_value
	return (
		_terminal_cleanup_pending
		and session == _active_session
		and session.is_finished()
		and session.get_runtime() == self
		and binding_value == _binding
		and motion_value == _active_motion
		and adapter_value == _active_adapter
	)


func _step_dependencies_are_current(
	session_value: Variant,
	root_value: Variant,
	binding_value: Variant,
	motion_value: Variant,
	adapter_value: Variant
) -> bool:
	if not _step_topology_is_current(session_value, root_value, binding_value):
		return false
	var session: GFProjectileSession = session_value
	if (
		not _is_live_object_of_type(motion_value, GFProjectileMotion)
		or motion_value != _active_motion
		or not _is_live_object_of_type(_motion_state, GFProjectileMotionState)
	):
		var _motion_lost: bool = session.finish(GFProjectileSession.EndReason.MOTION_FAILED)
		return false
	if (
		not _is_live_object_of_type(adapter_value, GFProjectileBodyAdapter2D)
		or adapter_value != _active_adapter
	):
		var _adapter_lost: bool = session.finish(
			GFProjectileSession.EndReason.BODY_APPLICATION_FAILED
		)
		return false
	return true


## 直接激活一个已验证 binding。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param binding: 指向本 runtime 的 current 2D topology snapshot。
## [br]
## @param launch_input: 可选 typed 输入；runtime 会在用户 callback 前冻结副本。
## [br]
## @return: ACTIVE session；准入、预检或重入失败时返回 null。
func launch(
	binding: GFProjectileBinding2D,
	launch_input: GFProjectileLaunchInput2D = null
) -> GFProjectileSession:
	if _active_session != null and not is_instance_valid(_active_session):
		_discard_invalid_active_state()
	if (
		_active_session != null
		or _launch_claim != null
		or _managed_retirement_session != null
		or _direct_preparing
	):
		return null
	_direct_preparing = true
	var effective_input: GFProjectileLaunchInput2D = _snapshot_input(launch_input, null)
	if not _prepare_launch_payload(binding, effective_input, null):
		_direct_preparing = false
		_clear_prepared_payload()
		return null
	var session: GFProjectileSession = _activate_prepared(binding, _prepared_input)
	_direct_preparing = false
	_clear_prepared_payload()
	if session != null:
		var _barrier_started: Error = session.begin_notification_barrier_for_framework()
		projectile_started.emit(session)
		var _barrier_released: Error = session.release_notification_barrier_for_framework()
	return session


## 返回当前 ACTIVE session。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: ACTIVE session；未激活或已结束时返回 null。
func get_active_session() -> GFProjectileSession:
	return (
		_active_session
		if (
			_active_session != null
			and is_instance_valid(_active_session)
			and _active_session.is_active()
		)
		else null
	)


## 判断 runtime 是否持有 ACTIVE session。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前 session ACTIVE 时为 true。
func is_active() -> bool:
	return (
		_active_session != null
		and is_instance_valid(_active_session)
		and _active_session.is_active()
	)


## 创建 owner-bound 的内部 launch reservation。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param binding: 指向本 runtime 的 current 2D topology snapshot。
## [br]
## @param launch_input: 候选独立的 typed input。
## [br]
## @param retirement_owner: 负责候选 retirement 的 live allocator owner。
## [br]
## @return: 已完成全部用户预检并缓存不可变 payload 的 reservation；失败时返回 null。
func reserve_launch_for_framework(
	binding: GFProjectileBinding2D,
	launch_input: GFProjectileLaunchInput2D,
	retirement_owner: Object
) -> GFProjectileLaunchReservation:
	if _active_session != null and not is_instance_valid(_active_session):
		_discard_invalid_active_state()
	if (
		binding == null
		or not is_instance_valid(binding)
		or not binding.is_valid()
		or not binding.is_current()
		or binding.get_runtime() != self
		or launch_input == null
		or not is_instance_valid(launch_input)
		or not _is_live_owner(retirement_owner)
		or _active_session != null
		or _launch_claim != null
		or _managed_retirement_session != null
	):
		return null
	var reservation: GFProjectileLaunchReservation = GFProjectileLaunchReservation.new()
	var initialize_result: Error = reservation.initialize_for_framework(
		self,
		binding,
		launch_input,
		retirement_owner
	)
	if initialize_result != OK:
		return null
	_launch_claim = reservation
	var effective_input: GFProjectileLaunchInput2D = _snapshot_input(
		launch_input,
		reservation
	)
	if not _prepare_launch_payload(binding, effective_input, reservation):
		release_launch_claim_for_framework(reservation)
		return null
	if reservation.replace_launch_input_for_framework(self, _prepared_input) != OK:
		release_launch_claim_for_framework(reservation)
		return null
	return reservation


## 查询 runtime 是否已被 reservation 占用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 是否存在 reservation、direct prepare 或尚未完成 terminal cleanup 的 session ownership。
func has_launch_claim_for_framework() -> bool:
	return (
		_launch_claim != null
		or _managed_retirement_session != null
		or _direct_preparing
		or (_active_session != null and is_instance_valid(_active_session))
	)


## 校验 reservation identity。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param reservation: 待核对的 reservation identity。
## [br]
## @return: reservation 是否仍独占本 runtime 且 session 尚未 ACTIVE。
func owns_launch_claim_for_framework(reservation: GFProjectileLaunchReservation) -> bool:
	return (
		reservation != null
		and is_instance_valid(reservation)
		and _launch_claim == reservation
		and _active_session == null
	)


## 释放仍由该 reservation 持有的 claim。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param reservation: 只能释放 identity 相同的当前 reservation。
func release_launch_claim_for_framework(reservation: GFProjectileLaunchReservation) -> void:
	if _launch_claim == reservation:
		_launch_claim = null
		_clear_prepared_payload()


## 在 reservation 的无回调消费区激活 session。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param reservation: 当前 ARMED reservation。
## [br]
## @param binding: reserve 阶段冻结的同一 binding。
## [br]
## @param launch_input: reserve 阶段冻结的同一 input snapshot。
## [br]
## @return: 仅通过原子状态转移激活的 session；identity 失效时返回 null。
func consume_launch_reservation_for_framework(
	reservation: GFProjectileLaunchReservation,
	binding: GFProjectileBinding2D,
	launch_input: GFProjectileLaunchInput2D
) -> GFProjectileSession:
	if not owns_launch_claim_for_framework(reservation):
		return null
	var session: GFProjectileSession = _activate_prepared(binding, launch_input)
	if session != null:
		var recorded: Error = reservation.record_activation_for_framework(self, session)
		if recorded != OK:
			var _invalidated: bool = session.finish(
				GFProjectileSession.EndReason.INTERNAL_FAILURE
			)
	release_launch_claim_for_framework(reservation)
	return session


## 在批次全部 ACTIVE 后发布 started 通知。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param session: 当前 generation 的已激活或 notification-barrier 内已结算 session。
## [br]
## @return: 成功发布 started 时为 OK。
func publish_started_for_framework(session: GFProjectileSession) -> Error:
	if (
		session == null
		or not is_instance_valid(session)
		or session != _active_session
		or session.get_status() == GFProjectileSession.Status.UNCONFIGURED
	):
		return ERR_INVALID_PARAMETER
	projectile_started.emit(session)
	return OK


## 在 allocator handoff 完成前保留 terminal runtime claim。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param session: 当前 ACTIVE session；emitter 将负责其最终 retirement。
## [br]
## @return: 首次建立 managed retirement claim 时为 OK。
func begin_terminal_retirement_for_framework(
	session: GFProjectileSession
) -> Error:
	if (
		session == null
		or not is_instance_valid(session)
		or session != _active_session
		or not session.is_active()
		or _managed_retirement_session != null
	):
		return ERR_INVALID_PARAMETER
	_managed_retirement_session = session
	return OK


## 在 allocator 已接管或 root 已失效后释放 terminal claim。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param session: 建立 claim 的同一 session。
## [br]
## @return: identity 匹配并释放时为 true。
func release_terminal_retirement_for_framework(
	session: GFProjectileSession
) -> bool:
	if session == null or session != _managed_retirement_session:
		return false
	_managed_retirement_session = null
	return true


## 校验 publication callback 返回后仍由本 runtime 持有同一 session/topology。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param session: publication barrier 内的同一 session。
## [br]
## @param instance_root: allocator 记录的同一完整 root。
## [br]
## @return: ACTIVE 或 barrier 内 FINISHED session 的 frozen topology 仍完整时为 true。
func publication_is_current_for_framework(
	session: GFProjectileSession,
	instance_root: Node
) -> bool:
	if (
		session == null
		or not is_instance_valid(session)
		or session != _active_session
		or session.get_status() == GFProjectileSession.Status.UNCONFIGURED
		or instance_root == null
		or not is_instance_valid(instance_root)
		or instance_root.is_queued_for_deletion()
		or session.get_instance_root() != instance_root
		or _managed_retirement_session != session
		or _binding == null
		or not is_instance_valid(_binding)
		or not _binding.is_topology_current_for_framework()
	):
		return false
	return _binding.get_runtime() == self


func _activate_prepared(
	binding: GFProjectileBinding2D,
	launch_input: GFProjectileLaunchInput2D
) -> GFProjectileSession:
	if (
		binding == null
		or not is_instance_valid(binding)
		or binding != _prepared_binding
		or launch_input == null
		or not is_instance_valid(launch_input)
		or launch_input != _prepared_input
		or _prepared_motion == null
		or not is_instance_valid(_prepared_motion)
		or _prepared_adapter == null
		or not is_instance_valid(_prepared_adapter)
		or _prepared_state == null
		or not is_instance_valid(_prepared_state)
		or _prepared_body == null
		or not is_instance_valid(_prepared_body)
		or _active_session != null
	):
		return null
	var root: Node = binding.get_instance_root()
	if not _is_live_node(root) or not binding.is_current():
		return null
	_generation += 1
	var session: GFProjectileSession = GFProjectileSession.new()
	var activate_result: Error = session.activate_for_framework(
		GFProjectileSession.Dimension.TWO_D,
		_generation,
		root,
		self,
		_prepared_adapter,
		launch_input.get_metadata()
	)
	if activate_result != OK:
		return null
	_binding = binding
	_launch_input = launch_input
	_motion_state = _prepared_state
	_current_body = _prepared_body
	_active_motion = _prepared_motion
	_active_lifetime = _prepared_lifetime
	_active_adapter = _prepared_adapter
	_active_session = session
	var finished_callback: Callable = _on_session_finished.bind(_generation)
	var _finished_connected: int = session.finished.connect(
		finished_callback,
		CONNECT_ONE_SHOT
	)
	_connect_impact_sources(binding, _generation)
	set_physics_process(true)
	return session


func _prepare_launch_payload(
	binding: GFProjectileBinding2D,
	launch_input: GFProjectileLaunchInput2D,
	reservation: GFProjectileLaunchReservation
) -> bool:
	if (
		binding == null
		or not is_instance_valid(binding)
		or not binding.is_valid()
		or not binding.is_current()
		or binding.get_runtime() != self
		or launch_input == null
		or not is_instance_valid(launch_input)
		or _active_session != null
		or not _preparation_owner_is_current(reservation)
	):
		return false
	var root: Node = binding.get_instance_root()
	var definition: GFProjectileDefinition = binding.get_definition()
	var adapter_value: Resource = binding.get_body_adapter()
	if (
		not _is_live_node(root)
		or definition == null
		or not is_instance_valid(definition)
		or definition.motion == null
		or not is_instance_valid(definition.motion)
		or not _is_live_object_of_type(adapter_value, GFProjectileBodyAdapter2D)
	):
		return false
	var adapter: GFProjectileBodyAdapter2D = adapter_value
	var motion: GFProjectileMotion = definition.motion
	var lifetime: GFProjectileLifetimePolicy = definition.lifetime_policy
	if lifetime != null and not is_instance_valid(lifetime):
		return false
	var initial_body_value: Variant = adapter.capture_body(root)
	if not _preparation_dependencies_are_current(
		reservation,
		binding,
		root,
		definition,
		motion,
		lifetime,
		adapter
	):
		return false
	if not _is_live_object_of_type(initial_body_value, GFProjectileBodyResult2D):
		return false
	var initial_body: GFProjectileBodyResult2D = initial_body_value
	if not initial_body.is_successful():
		return false
	var state_value: Variant = motion.create_state_2d(launch_input, initial_body)
	if not _preparation_dependencies_are_current(
		reservation,
		binding,
		root,
		definition,
		motion,
		lifetime,
		adapter
	):
		return false
	if not _is_live_object_of_type(state_value, GFProjectileMotionState):
		var _state_creation_failed: bool = binding.fail_for_framework(
			GFProjectileBinding.FailureReason.MOTION_STATE_CREATION_FAILED
		)
		return false
	var state: GFProjectileMotionState = state_value
	var frozen_input_value: Variant = launch_input.duplicate_input()
	if not _preparation_dependencies_are_current(
		reservation,
		binding,
		root,
		definition,
		motion,
		lifetime,
		adapter
	):
		return false
	if not _is_live_object_of_type(frozen_input_value, GFProjectileLaunchInput2D):
		return false
	var frozen_input: GFProjectileLaunchInput2D = frozen_input_value
	_prepared_binding = binding
	_prepared_input = frozen_input
	_prepared_motion = motion
	_prepared_lifetime = lifetime
	_prepared_adapter = adapter
	_prepared_state = state
	_prepared_body = initial_body
	return true


func _preparation_dependencies_are_current(
	reservation: GFProjectileLaunchReservation,
	binding_value: Variant,
	root_value: Variant,
	definition_value: Variant,
	motion_value: Variant,
	lifetime_value: Variant,
	adapter_value: Variant
) -> bool:
	if not _preparation_owner_is_current(reservation):
		return false
	if not _is_live_object_of_type(binding_value, GFProjectileBinding2D):
		return false
	var binding: GFProjectileBinding2D = binding_value
	if not binding.is_current() or binding.get_runtime() != self:
		return false
	if not _is_live_node(root_value) or binding.get_instance_root() != root_value:
		return false
	if not _is_live_object_of_type(definition_value, GFProjectileDefinition):
		return false
	var definition: GFProjectileDefinition = definition_value
	if binding.get_definition() != definition:
		return false
	if (
		not _is_live_object_of_type(motion_value, GFProjectileMotion)
		or definition.motion != motion_value
	):
		return false
	if lifetime_value == null:
		if definition.lifetime_policy != null:
			return false
	elif (
		not _is_live_object_of_type(lifetime_value, GFProjectileLifetimePolicy)
		or definition.lifetime_policy != lifetime_value
	):
		return false
	return (
		_is_live_object_of_type(adapter_value, GFProjectileBodyAdapter2D)
		and binding.get_body_adapter() == adapter_value
	)


func _preparation_owner_is_current(
	reservation: GFProjectileLaunchReservation
) -> bool:
	if reservation == null:
		return _direct_preparing and _launch_claim == null
	return _launch_claim == reservation and not _direct_preparing


func _clear_prepared_payload() -> void:
	_prepared_binding = null
	_prepared_input = null
	_prepared_motion = null
	_prepared_lifetime = null
	_prepared_adapter = null
	_prepared_state = null
	_prepared_body = null


func _snapshot_input(
	launch_input: GFProjectileLaunchInput2D,
	reservation: GFProjectileLaunchReservation
) -> GFProjectileLaunchInput2D:
	var result: GFProjectileLaunchInput2D = GFProjectileLaunchInput2D.new()
	if launch_input == null:
		return result
	if not is_instance_valid(launch_input):
		return null
	var kind_value: Variant = launch_input.call(&"get_target_kind")
	if (
		not _input_snapshot_boundary_is_current(launch_input, reservation)
		or typeof(kind_value) != TYPE_INT
	):
		return null
	var kind: int = kind_value
	match kind:
		GFProjectileLaunchInput2D.TargetKind.NODE:
			var target_value: Variant = launch_input.call(&"get_target_node")
			if not _input_snapshot_boundary_is_current(launch_input, reservation):
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
			var position_value: Variant = launch_input.call(&"get_target_position")
			if (
				not _input_snapshot_boundary_is_current(launch_input, reservation)
				or typeof(position_value) != TYPE_VECTOR2
			):
				return null
			var position: Vector2 = position_value
			result.set_target_position(position)
		GFProjectileLaunchInput2D.TargetKind.NONE:
			result.set_target_none()
		_:
			return null
	var metadata_value: Variant = launch_input.call(&"get_metadata")
	if (
		not _input_snapshot_boundary_is_current(launch_input, reservation)
		or typeof(metadata_value) != TYPE_DICTIONARY
	):
		return null
	var metadata: Dictionary = metadata_value
	result.set_metadata(metadata)
	return result


func _input_snapshot_boundary_is_current(
	launch_input_value: Variant,
	reservation: GFProjectileLaunchReservation
) -> bool:
	return (
		_is_live_object_of_type(launch_input_value, GFProjectileLaunchInput2D)
		and not is_queued_for_deletion()
		and _preparation_owner_is_current(reservation)
	)


func _connect_impact_sources(binding: GFProjectileBinding2D, generation: int) -> void:
	_disconnect_impact_sources()
	for source_node: Node in binding.get_impact_sources():
		var callback: Callable = _on_impact_accepted.bind(generation)
		var connected: int = ERR_INVALID_PARAMETER
		if source_node is GFHitBox2D:
			var hit_box: GFHitBox2D = source_node
			connected = hit_box.hit_accepted.connect(callback)
		elif source_node is GFHitScan2D:
			var hit_scan: GFHitScan2D = source_node
			connected = hit_scan.hit_accepted.connect(callback)
		if connected == OK:
			_impact_sources.append(source_node)
			_impact_callbacks.append(callback)


func _disconnect_impact_sources() -> void:
	for index: int in range(mini(_impact_sources.size(), _impact_callbacks.size())):
		var source: Node = _impact_sources[index]
		var callback: Callable = _impact_callbacks[index]
		if not is_instance_valid(source):
			continue
		if source is GFHitBox2D:
			var hit_box: GFHitBox2D = source
			if hit_box.hit_accepted.is_connected(callback):
				hit_box.hit_accepted.disconnect(callback)
		elif source is GFHitScan2D:
			var hit_scan: GFHitScan2D = source
			if hit_scan.hit_accepted.is_connected(callback):
				hit_scan.hit_accepted.disconnect(callback)
	_impact_sources.clear()
	_impact_callbacks.clear()


func _evaluate_lifetime(session: GFProjectileSession) -> void:
	if (
		not _is_live_object_of_type(session, GFProjectileSession)
		or session != _active_session
		or not session.is_active()
	):
		return
	if _active_lifetime == null:
		return
	var lifetime_policy: GFProjectileLifetimePolicy = _active_lifetime
	var root_value: Variant = session.get_instance_root()
	var binding_value: Variant = _binding
	var reason_value: Variant = lifetime_policy.call(&"get_end_reason", session)
	if not _step_topology_is_current(session, root_value, binding_value):
		return
	if lifetime_policy != _active_lifetime:
		return
	if typeof(reason_value) != TYPE_INT:
		var _invalid_reason: bool = session.finish(
			GFProjectileSession.EndReason.INTERNAL_FAILURE
		)
		return
	var reason_int: int = reason_value
	if (
		reason_int < GFProjectileSession.EndReason.NONE
		or reason_int > GFProjectileSession.EndReason.INTERNAL_FAILURE
	):
		var _out_of_range_reason: bool = session.finish(
			GFProjectileSession.EndReason.INTERNAL_FAILURE
		)
		return
	var reason: GFProjectileSession.EndReason = reason_int as GFProjectileSession.EndReason
	if reason != GFProjectileSession.EndReason.NONE:
		var _finished: bool = session.finish(reason)


func _on_impact_accepted(
	_context: GFCombatHitContext,
	_receiver: Object,
	_report: Dictionary,
	generation: int
) -> void:
	if (
		_active_session == null
		or not is_instance_valid(_active_session)
		or not _active_session.is_active()
	):
		return
	var session: GFProjectileSession = _active_session
	if generation != session.get_generation():
		return
	var binding_value: Variant = _binding
	if not _step_topology_is_current(
		session,
		session.get_instance_root(),
		binding_value
	):
		return
	session.accept_impact_for_framework()
	_evaluate_lifetime(session)


func _on_session_finished(
	finished_session: GFProjectileSession,
	reason: int,
	generation: int
) -> void:
	if _active_session != finished_session or generation != finished_session.get_generation():
		return
	_disconnect_impact_sources()
	set_physics_process(false)
	if _body_application_session == finished_session:
		_terminal_cleanup_pending = true
	projectile_finished.emit(finished_session, reason)
	if _body_application_session != finished_session:
		_clear_active_session(finished_session)


func _finalize_terminal_cleanup(session_value: Variant) -> void:
	if (
		not _is_live_object_of_type(session_value, GFProjectileSession)
		or not _terminal_cleanup_pending
		or session_value != _active_session
	):
		return
	var session: GFProjectileSession = session_value
	_terminal_cleanup_pending = false
	_clear_active_session(session)


func _clear_active_session(finished_session: GFProjectileSession) -> void:
	_binding = null
	_launch_input = null
	_motion_state = null
	_current_body = null
	_active_motion = null
	_active_lifetime = null
	_active_adapter = null
	if _active_session == finished_session:
		_active_session = null


func _discard_invalid_active_state() -> void:
	_disconnect_impact_sources()
	set_physics_process(false)
	_active_session = null
	_binding = null
	_launch_input = null
	_motion_state = null
	_current_body = null
	_active_motion = null
	_active_lifetime = null
	_active_adapter = null
	_body_application_session = null
	_terminal_cleanup_pending = false


func _is_live_node(value: Variant) -> bool:
	if (
		typeof(value) != TYPE_OBJECT
		or not is_instance_valid(value)
		or not value is Node
	):
		return false
	var node: Node = value
	return not node.is_queued_for_deletion()


func _is_live_owner(value: Variant) -> bool:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return false
	if value is Node:
		var node: Node = value
		return not node.is_queued_for_deletion()
	return true


func _is_live_object_of_type(value: Variant, expected_type: Variant) -> bool:
	return (
		typeof(value) == TYPE_OBJECT
		and is_instance_valid(value)
		and is_instance_of(value, expected_type)
	)
