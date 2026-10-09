## GFHomingProjectileMotion: 使用 LaunchInput target 的 typed 追踪 intent 策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFHomingProjectileMotion
extends GFProjectileMotion


# --- 常量 ---

## 为运动配置、目标偏移和 intent 位移提供有限数值检查。
## [br]
## @api private
const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## world-space 追踪速度。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var speed: float = 0.0

## 视为到达目标的距离；NaN/Inf 会被拒绝，有限负值保持兼容语义并禁用 arrival clamp。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var arrival_distance: float = 0.0

## 是否每帧重新读取 node 目标位置；关闭且目标仍存活时，方向与 arrival clamp 使用 launch 快照。
## 目标失效后会沿锁定方向继续，并禁用旧位置 clamp。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var track_target: bool = true

## 是否在本帧限制移动距离以停在 arrival boundary。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var stop_when_reached: bool = true


# --- 可重写钩子 / 虚方法 ---

## 捕获二维发射目标的位置与初始方向，为本次 session 建立追踪状态。
## 节点目标只保留弱引用；此处记录目标种类，不将无目标直接判为创建失败。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param launch_input: 已冻结的发射输入，提供节点目标或位置目标。
## [br]
## @param initial_body: 成功的初始 body 快照，用于计算指向目标的方向。
## [br]
## @return: 本次 session 独占的状态；输入失效、body 失败或配置及目标偏移非有限时返回 null。
func _create_state_2d(
	launch_input: GFProjectileLaunchInput2D,
	initial_body: GFProjectileBodyResult2D
) -> GFProjectileMotionState:
	if (
		launch_input == null
		or not is_instance_valid(launch_input)
		or initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
		or not _motion_configuration_is_finite()
	):
		return null
	var state: _HomingState = _HomingState.new()
	state._target_kind = launch_input.get_target_kind()
	if state._target_kind == GFProjectileLaunchInput2D.TargetKind.NODE:
		var target: Node2D = launch_input.get_target_node()
		if target != null:
			state._target_ref = weakref(target)
			state._target_position_2d = _get_position_2d(target)
	elif state._target_kind == GFProjectileLaunchInput2D.TargetKind.POSITION:
		state._target_position_2d = launch_input.get_target_position()
	var offset: Vector2 = state._target_position_2d - initial_body.get_position()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(offset):
		return null
	if not offset.is_zero_approx():
		state._locked_direction_2d = offset.normalized()
	return state


## 捕获三维发射目标的位置与初始方向，为本次 session 建立追踪状态。
## 节点目标只保留弱引用；此处记录目标种类，不将无目标直接判为创建失败。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param launch_input: 已冻结的发射输入，提供节点目标或位置目标。
## [br]
## @param initial_body: 成功的初始 body 快照，用于计算指向目标的方向。
## [br]
## @return: 本次 session 独占的状态；输入失效、body 失败或配置及目标偏移非有限时返回 null。
func _create_state_3d(
	launch_input: GFProjectileLaunchInput3D,
	initial_body: GFProjectileBodyResult3D
) -> GFProjectileMotionState:
	if (
		launch_input == null
		or not is_instance_valid(launch_input)
		or initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
		or not _motion_configuration_is_finite()
	):
		return null
	var state: _HomingState = _HomingState.new()
	state._target_kind = launch_input.get_target_kind()
	if state._target_kind == GFProjectileLaunchInput3D.TargetKind.NODE:
		var target: Node3D = launch_input.get_target_node()
		if target != null:
			state._target_ref = weakref(target)
			state._target_position_3d = _get_position_3d(target)
	elif state._target_kind == GFProjectileLaunchInput3D.TargetKind.POSITION:
		state._target_position_3d = launch_input.get_target_position()
	var offset: Vector3 = state._target_position_3d - initial_body.get_position()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector3(offset):
		return null
	if not offset.is_zero_approx():
		state._locked_direction_3d = offset.normalized()
	return state


## 根据二维目标与当前 body 计算追踪 intent，只更新状态中的锁定方向，不移动节点。
## 追踪开启时重新读取节点位置，目标丢失则拒绝；关闭追踪后目标丢失时，
## 已有的非零锁定方向可继续使用，并禁用旧目标位置的到达截短。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param state: 本策略创建的 session 状态；其他状态类型会被拒绝。
## [br]
## @param current_body: 成功的当前 body 快照，提供计算距离所需的位置。
## [br]
## @param delta: 本帧秒数；有限非正值生成零速度、零时长 intent，非有限值被拒绝。
## [br]
## @return: 按到达设置截短路程后的 MOVE；状态、目标或数值无效时返回带原因的 REJECTED。
func _compute_intent_2d(
	state: GFProjectileMotionState,
	current_body: GFProjectileBodyResult2D,
	delta: float
) -> GFProjectileMotionIntent2D:
	if (
		typeof(state) != TYPE_OBJECT
		or not is_instance_valid(state)
		or not state is _HomingState
		or current_body == null
		or not is_instance_valid(current_body)
		or not current_body.is_successful()
		or not _motion_configuration_is_finite()
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
	):
		return GFProjectileMotionIntent2D.rejected(&"invalid_motion_state")
	var homing_state: _HomingState = state
	var target_position: Vector2 = homing_state._target_position_2d
	var has_target: bool = homing_state._target_kind != GFProjectileLaunchInput2D.TargetKind.NONE
	var locked_target_lost: bool = false
	if homing_state._target_kind == GFProjectileLaunchInput2D.TargetKind.NODE:
		var target: Node2D = _node_2d_from_ref(homing_state._target_ref)
		if target == null:
			if track_target:
				return GFProjectileMotionIntent2D.rejected(&"target_lost")
			has_target = not homing_state._locked_direction_2d.is_zero_approx()
			locked_target_lost = has_target
		elif track_target:
			target_position = _get_position_2d(target)
	if not has_target:
		return GFProjectileMotionIntent2D.rejected(&"target_lost")
	var offset: Vector2 = target_position - current_body.get_position()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(offset):
		return GFProjectileMotionIntent2D.rejected(&"non_finite_motion_configuration")
	var direction: Vector2 = homing_state._locked_direction_2d
	if track_target or direction.is_zero_approx():
		direction = offset.normalized() if not offset.is_zero_approx() else Vector2.ZERO
		homing_state._locked_direction_2d = direction
	return _make_intent_2d(direction, offset.length(), delta, not locked_target_lost)


## 根据三维目标与当前 body 计算追踪 intent，只更新状态中的锁定方向，不移动节点。
## 追踪开启时重新读取节点位置，目标丢失则拒绝；关闭追踪后目标丢失时，
## 已有的非零锁定方向可继续使用，并禁用旧目标位置的到达截短。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param state: 本策略创建的 session 状态；其他状态类型会被拒绝。
## [br]
## @param current_body: 成功的当前 body 快照，提供计算距离所需的位置。
## [br]
## @param delta: 本帧秒数；有限非正值生成零速度、零时长 intent，非有限值被拒绝。
## [br]
## @return: 按到达设置截短路程后的 MOVE；状态、目标或数值无效时返回带原因的 REJECTED。
func _compute_intent_3d(
	state: GFProjectileMotionState,
	current_body: GFProjectileBodyResult3D,
	delta: float
) -> GFProjectileMotionIntent3D:
	if (
		typeof(state) != TYPE_OBJECT
		or not is_instance_valid(state)
		or not state is _HomingState
		or current_body == null
		or not is_instance_valid(current_body)
		or not current_body.is_successful()
		or not _motion_configuration_is_finite()
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
	):
		return GFProjectileMotionIntent3D.rejected(&"invalid_motion_state")
	var homing_state: _HomingState = state
	var target_position: Vector3 = homing_state._target_position_3d
	var has_target: bool = homing_state._target_kind != GFProjectileLaunchInput3D.TargetKind.NONE
	var locked_target_lost: bool = false
	if homing_state._target_kind == GFProjectileLaunchInput3D.TargetKind.NODE:
		var target: Node3D = _node_3d_from_ref(homing_state._target_ref)
		if target == null:
			if track_target:
				return GFProjectileMotionIntent3D.rejected(&"target_lost")
			has_target = not homing_state._locked_direction_3d.is_zero_approx()
			locked_target_lost = has_target
		elif track_target:
			target_position = _get_position_3d(target)
	if not has_target:
		return GFProjectileMotionIntent3D.rejected(&"target_lost")
	var offset: Vector3 = target_position - current_body.get_position()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector3(offset):
		return GFProjectileMotionIntent3D.rejected(&"non_finite_motion_configuration")
	var direction: Vector3 = homing_state._locked_direction_3d
	if track_target or direction.is_zero_approx():
		direction = offset.normalized() if not offset.is_zero_approx() else Vector3.ZERO
		homing_state._locked_direction_3d = direction
	return _make_intent_3d(direction, offset.length(), delta, not locked_target_lost)


# --- 私有/辅助方法 ---

## 校验运动输入后计算 2D 速度；可选按到达距离截短本帧路程，非正 delta 返回零速度 intent。
## [br]
## @api private
func _make_intent_2d(
	direction: Vector2,
	distance: float,
	delta: float,
	clamp_to_target: bool
) -> GFProjectileMotionIntent2D:
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector2(direction)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(distance)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
	):
		return GFProjectileMotionIntent2D.rejected(&"non_finite_motion_configuration")
	if delta <= 0.0:
		return GFProjectileMotionIntent2D.move(Vector2.ZERO, maxf(delta, 0.0))
	var travel_distance: float = speed * delta
	if clamp_to_target and stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(travel_distance):
		return GFProjectileMotionIntent2D.rejected(&"non_finite_motion_configuration")
	return GFProjectileMotionIntent2D.move(direction * (travel_distance / delta), delta)


## 校验运动输入后计算 3D 速度；可选按到达距离截短本帧路程，非正 delta 返回零速度 intent。
## [br]
## @api private
func _make_intent_3d(
	direction: Vector3,
	distance: float,
	delta: float,
	clamp_to_target: bool
) -> GFProjectileMotionIntent3D:
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector3(direction)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(distance)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
	):
		return GFProjectileMotionIntent3D.rejected(&"non_finite_motion_configuration")
	if delta <= 0.0:
		return GFProjectileMotionIntent3D.move(Vector3.ZERO, maxf(delta, 0.0))
	var travel_distance: float = speed * delta
	if clamp_to_target and stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(travel_distance):
		return GFProjectileMotionIntent3D.rejected(&"non_finite_motion_configuration")
	return GFProjectileMotionIntent3D.move(direction * (travel_distance / delta), delta)


## 检查 speed 与 arrival_distance 是否均为有限浮点数。
## [br]
## @api private
func _motion_configuration_is_finite() -> bool:
	return (
		_GF_COMBAT_FINITE_MATH.is_finite_float(speed)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(arrival_distance)
	)


## 从 WeakRef 读取仍可用且未排队删除的 Node2D；其他状态返回 null。
## [br]
## @api private
func _node_2d_from_ref(weak_reference: WeakRef) -> Node2D:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node2D:
		var node: Node2D = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


## 从 WeakRef 读取仍可用且未排队删除的 Node3D；其他状态返回 null。
## [br]
## @api private
func _node_3d_from_ref(weak_reference: WeakRef) -> Node3D:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node3D:
		var node: Node3D = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null


## 节点在场景树内时读取 global_position，否则读取本地 position。
## [br]
## @api private
func _get_position_3d(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


## 节点在场景树内时读取 global_position，否则读取本地 position。
## [br]
## @api private
func _get_position_2d(node: Node2D) -> Vector2:
	return node.global_position if node.is_inside_tree() else node.position


# --- 内部类 ---

## 保存单个 projectile session 的目标种类、弱引用、目标位置快照和锁定方向。
## [br]
## @api private
class _HomingState:
	extends GFProjectileMotionState

	# --- 私有变量 ---

	## 启动输入的目标种类，用于区分无目标、位置快照与节点追踪。
	## [br]
	## @api private
	var _target_kind: int = 0

	## 节点目标的弱引用；读取失效后由 track_target 决定拒绝或沿锁定方向继续。
	## [br]
	## @api private
	var _target_ref: WeakRef = null

	## 启动时捕获的二维目标位置；动态追踪时会在计算中重新读取节点位置。
	## [br]
	## @api private
	var _target_position_2d: Vector2 = Vector2.ZERO

	## 启动时捕获的三维目标位置；动态追踪时会在计算中重新读取节点位置。
	## [br]
	## @api private
	var _target_position_3d: Vector3 = Vector3.ZERO

	## 已计算的二维方向，用于不追踪目标时保持航向。
	## [br]
	## @api private
	var _locked_direction_2d: Vector2 = Vector2.ZERO

	## 已计算的三维方向，用于不追踪目标时保持航向。
	## [br]
	## @api private
	var _locked_direction_3d: Vector3 = Vector3.ZERO
