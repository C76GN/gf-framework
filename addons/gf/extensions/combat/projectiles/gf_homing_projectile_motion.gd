## GFHomingProjectileMotion: 使用 LaunchInput target 的 typed 追踪 intent 策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFHomingProjectileMotion
extends GFProjectileMotion


class _HomingState:
	extends GFProjectileMotionState

	var _target_kind: int = 0
	var _target_ref: WeakRef = null
	var _target_position_2d: Vector2 = Vector2.ZERO
	var _target_position_3d: Vector3 = Vector3.ZERO
	var _locked_direction_2d: Vector2 = Vector2.ZERO
	var _locked_direction_3d: Vector3 = Vector3.ZERO


## world-space 追踪速度。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var speed: float = 0.0

## 视为到达目标的非负距离。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var arrival_distance: float = 0.0

## 是否每帧重新读取 node 目标位置。
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
	if not offset.is_zero_approx():
		state._locked_direction_2d = offset.normalized()
	return state


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
	if not offset.is_zero_approx():
		state._locked_direction_3d = offset.normalized()
	return state


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
	):
		return GFProjectileMotionIntent2D.rejected(&"invalid_motion_state")
	var homing_state: _HomingState = state
	var target_position: Vector2 = homing_state._target_position_2d
	var has_target: bool = homing_state._target_kind != GFProjectileLaunchInput2D.TargetKind.NONE
	if homing_state._target_kind == GFProjectileLaunchInput2D.TargetKind.NODE:
		var target: Node2D = _node_2d_from_ref(homing_state._target_ref)
		if target == null:
			if track_target:
				return GFProjectileMotionIntent2D.rejected(&"target_lost")
			has_target = not homing_state._locked_direction_2d.is_zero_approx()
		else:
			target_position = _get_position_2d(target)
	if not has_target:
		return GFProjectileMotionIntent2D.rejected(&"target_lost")
	var offset: Vector2 = target_position - current_body.get_position()
	var direction: Vector2 = homing_state._locked_direction_2d
	if track_target or direction.is_zero_approx():
		direction = offset.normalized() if not offset.is_zero_approx() else Vector2.ZERO
		homing_state._locked_direction_2d = direction
	return _make_intent_2d(direction, offset.length(), delta)


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
	):
		return GFProjectileMotionIntent3D.rejected(&"invalid_motion_state")
	var homing_state: _HomingState = state
	var target_position: Vector3 = homing_state._target_position_3d
	var has_target: bool = homing_state._target_kind != GFProjectileLaunchInput3D.TargetKind.NONE
	if homing_state._target_kind == GFProjectileLaunchInput3D.TargetKind.NODE:
		var target: Node3D = _node_3d_from_ref(homing_state._target_ref)
		if target == null:
			if track_target:
				return GFProjectileMotionIntent3D.rejected(&"target_lost")
			has_target = not homing_state._locked_direction_3d.is_zero_approx()
		else:
			target_position = _get_position_3d(target)
	if not has_target:
		return GFProjectileMotionIntent3D.rejected(&"target_lost")
	var offset: Vector3 = target_position - current_body.get_position()
	var direction: Vector3 = homing_state._locked_direction_3d
	if track_target or direction.is_zero_approx():
		direction = offset.normalized() if not offset.is_zero_approx() else Vector3.ZERO
		homing_state._locked_direction_3d = direction
	return _make_intent_3d(direction, offset.length(), delta)


func _make_intent_2d(
	direction: Vector2,
	distance: float,
	delta: float
) -> GFProjectileMotionIntent2D:
	if delta <= 0.0:
		return GFProjectileMotionIntent2D.move(Vector2.ZERO, maxf(delta, 0.0))
	var travel_distance: float = speed * delta
	if stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))
	return GFProjectileMotionIntent2D.move(direction * (travel_distance / delta), delta)


func _make_intent_3d(
	direction: Vector3,
	distance: float,
	delta: float
) -> GFProjectileMotionIntent3D:
	if delta <= 0.0:
		return GFProjectileMotionIntent3D.move(Vector3.ZERO, maxf(delta, 0.0))
	var travel_distance: float = speed * delta
	if stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))
	return GFProjectileMotionIntent3D.move(direction * (travel_distance / delta), delta)


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


func _get_position_3d(node: Node3D) -> Vector3:
	return node.global_position if node.is_inside_tree() else node.position


func _get_position_2d(node: Node2D) -> Vector2:
	return node.global_position if node.is_inside_tree() else node.position
