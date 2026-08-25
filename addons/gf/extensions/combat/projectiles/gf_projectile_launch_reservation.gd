## GFProjectileLaunchReservation: owner-bound 的 launch 单次预留。
## [br]
## @api framework_internal
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFProjectileLaunchReservation
extends RefCounted


## 定义 reservation 的封闭单向状态。
## [br]
## @api framework_internal
enum State {
	RESERVED = 0,
	ARMED = 1,
	ACTIVATING = 2,
	CONSUMED = 3,
	ABORTED = 4,
	INVALIDATED = 5,
}


var _state: State = State.INVALIDATED
var _runtime_ref: WeakRef = null
var _binding: GFProjectileBinding = null
var _launch_input: Resource = null
var _owner_ref: WeakRef = null
var _owner_id: int = 0
var _activated_session: GFProjectileSession = null


## 读取 reservation 状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 当前封闭状态。
func get_state_for_framework() -> State:
	return _state


## 以创建 reservation 的同一 owner 完成预检。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param owner: 创建 reservation 的同一 live retirement owner。
## [br]
## @return: 成功进入 ARMED 时为 OK；owner 或 claim 失效时返回确定错误。
func arm_for_framework(owner: Object) -> Error:
	if not _is_same_live_owner(owner):
		return ERR_UNAUTHORIZED
	if _state != State.RESERVED:
		return ERR_ALREADY_IN_USE
	if not _is_current_claim():
		_invalidate()
		return ERR_INVALID_DATA
	_state = State.ARMED
	return OK


## 无用户 callback 地把 ARMED reservation 消费为 ACTIVE session。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param owner: 创建 reservation 的同一 live retirement owner。
## [br]
## @return: 原子激活的 session；owner、状态或 topology 失效时返回 null。
func consume_for_framework(owner: Object) -> GFProjectileSession:
	if not _is_same_live_owner(owner) or _state != State.ARMED:
		return null
	if not _is_current_claim():
		_invalidate()
		return null
	_state = State.ACTIVATING
	var runtime: Node = _node_from_ref(_runtime_ref)
	var session_value: Variant = null
	if (
		runtime is GFProjectile2D
		and _binding is GFProjectileBinding2D
		and _launch_input is GFProjectileLaunchInput2D
	):
		var runtime_2d: GFProjectile2D = runtime
		var binding_2d: GFProjectileBinding2D = _binding
		var input_2d: GFProjectileLaunchInput2D = _launch_input
		session_value = runtime_2d.consume_launch_reservation_for_framework(
			self,
			binding_2d,
			input_2d
		)
	elif (
		runtime is GFProjectile3D
		and _binding is GFProjectileBinding3D
		and _launch_input is GFProjectileLaunchInput3D
	):
		var runtime_3d: GFProjectile3D = runtime
		var binding_3d: GFProjectileBinding3D = _binding
		var input_3d: GFProjectileLaunchInput3D = _launch_input
		session_value = runtime_3d.consume_launch_reservation_for_framework(
			self,
			binding_3d,
			input_3d
		)
	if _activated_session != null and is_instance_valid(_activated_session):
		session_value = _activated_session
	if (
		typeof(session_value) != TYPE_OBJECT
		or not is_instance_valid(session_value)
		or not session_value is GFProjectileSession
	):
		_state = State.INVALIDATED
		_release_claim()
		return null
	var session: GFProjectileSession = session_value
	if session.get_status() == GFProjectileSession.Status.UNCONFIGURED:
		_state = State.INVALIDATED
		_release_claim()
		return null
	_state = State.CONSUMED
	return session


## 放弃尚未消费的 reservation；不负责 allocator retirement。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param owner: 创建 reservation 的同一 live retirement owner。
## [br]
## @param _reason: 供调用边界记录的稳定中止原因；reservation 不调用用户代码。
## [br]
## @return: 本调用是否首次中止未消费 reservation。
func abort_for_framework(owner: Object, _reason: StringName) -> bool:
	if not _is_same_live_owner(owner):
		return false
	if _state != State.RESERVED and _state != State.ARMED:
		return false
	_state = State.ABORTED if _state == State.RESERVED else State.INVALIDATED
	_release_claim()
	return true


## 当原 retirement owner 已失效时，由独立 allocator record 失效未消费 claim。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param owner_instance_id: 初始化时冻结的原 owner instance id。
## [br]
## @param _reason: 供 allocator 记录的稳定结算原因；本方法不调用用户代码。
## [br]
## @return: owner identity 匹配、原 owner 已非 live 且状态尚未消费时首次返回 true。
func invalidate_lost_owner_for_framework(
	owner_instance_id: int,
	_reason: StringName
) -> bool:
	if (
		owner_instance_id <= 0
		or owner_instance_id != _owner_id
		or (_state != State.RESERVED and _state != State.ARMED)
	):
		return false
	var owner_value: Variant = _owner_ref.get_ref() if _owner_ref != null else null
	if _owner_is_live(owner_value):
		return false
	_state = State.INVALIDATED
	_release_claim()
	return true


## 初始化 owner-bound reservation。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param runtime: 持有 launch claim 的 typed runtime。
## [br]
## @param binding: reserve 边界的 topology snapshot。
## [br]
## @param launch_input: reserve 边界冻结的 typed input。
## [br]
## @param retirement_owner: 唯一有权 arm、consume 或 abort 的 live allocator owner。
## [br]
## @return: 初始化结果。
func initialize_for_framework(
	runtime: Node,
	binding: GFProjectileBinding,
	launch_input: Resource,
	retirement_owner: Object
) -> Error:
	if (
		runtime == null
		or not is_instance_valid(runtime)
		or runtime.is_queued_for_deletion()
		or binding == null
		or not is_instance_valid(binding)
		or launch_input == null
		or not is_instance_valid(launch_input)
		or not _owner_is_live(retirement_owner)
	):
		return ERR_INVALID_PARAMETER
	_runtime_ref = weakref(runtime)
	_binding = binding
	_launch_input = launch_input
	_owner_ref = weakref(retirement_owner)
	_owner_id = retirement_owner.get_instance_id()
	_state = State.RESERVED
	return OK


## 由 owning runtime 在 reserve callback 阶段冻结最终 typed input snapshot。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param runtime: 持有 reservation 的同一 runtime。
## [br]
## @param launch_input: 所有 reserve callback 完成后的最终 typed input 快照。
## [br]
## @return: 替换结果；状态或 owner 不匹配时返回错误。
func replace_launch_input_for_framework(
	runtime: Node,
	launch_input: Resource
) -> Error:
	if (
		_state != State.RESERVED
		or launch_input == null
		or not is_instance_valid(launch_input)
	):
		return ERR_INVALID_PARAMETER
	var expected_runtime: Node = _node_from_ref(_runtime_ref)
	if runtime == null or runtime != expected_runtime:
		return ERR_UNAUTHORIZED
	_launch_input = launch_input
	return OK


## 记录 owning runtime 已完成的不可逆 ACTIVE 转移。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param runtime: 持有 reservation 的同一 runtime。
## [br]
## @param session: 已离开 UNCONFIGURED 的同一 runtime session。
## [br]
## @return: 首次记录成功时为 OK；身份或状态不匹配时返回错误。
func record_activation_for_framework(
	runtime: Node,
	session: GFProjectileSession
) -> Error:
	if _state != State.ACTIVATING or _activated_session != null:
		return ERR_ALREADY_IN_USE
	var expected_runtime: Node = _node_from_ref(_runtime_ref)
	if (
		runtime == null
		or runtime != expected_runtime
		or session == null
		or not is_instance_valid(session)
		or session.get_status() == GFProjectileSession.Status.UNCONFIGURED
		or session.get_runtime() != runtime
	):
		return ERR_INVALID_PARAMETER
	_activated_session = session
	return OK


func _is_same_live_owner(owner: Object) -> bool:
	if not _owner_is_live(owner) or _owner_ref == null:
		return false
	var expected: Variant = _owner_ref.get_ref()
	return (
		_owner_is_live(expected)
		and expected == owner
		and owner.get_instance_id() == _owner_id
	)


func _is_current_claim() -> bool:
	if (
		_binding == null
		or not is_instance_valid(_binding)
	):
		return false
	if not _binding.is_current():
		var _binding_invalidated: bool = _binding.fail_for_framework(
			GFProjectileBinding.FailureReason.RESERVATION_INVALIDATED
		)
		return false
	var runtime: Node = _node_from_ref(_runtime_ref)
	var claim_is_current: bool = false
	if runtime is GFProjectile2D:
		var runtime_2d: GFProjectile2D = runtime
		claim_is_current = runtime_2d.owns_launch_claim_for_framework(self)
	elif runtime is GFProjectile3D:
		var runtime_3d: GFProjectile3D = runtime
		claim_is_current = runtime_3d.owns_launch_claim_for_framework(self)
	if not claim_is_current:
		var _claim_invalidated: bool = _binding.fail_for_framework(
			GFProjectileBinding.FailureReason.RESERVATION_INVALIDATED
		)
	return claim_is_current


func _invalidate() -> void:
	_state = State.INVALIDATED
	_release_claim()


func _release_claim() -> void:
	var runtime: Node = _node_from_ref(_runtime_ref)
	if runtime is GFProjectile2D:
		var runtime_2d: GFProjectile2D = runtime
		runtime_2d.release_launch_claim_for_framework(self)
	elif runtime is GFProjectile3D:
		var runtime_3d: GFProjectile3D = runtime
		runtime_3d.release_launch_claim_for_framework(self)


func _node_from_ref(weak_reference: WeakRef) -> Node:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node:
		var node: Node = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


func _owner_is_live(value: Variant) -> bool:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return false
	if value is Node:
		var node: Node = value
		return not node.is_queued_for_deletion()
	return true
