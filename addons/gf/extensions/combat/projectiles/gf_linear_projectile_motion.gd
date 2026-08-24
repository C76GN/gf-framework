## GFLinearProjectileMotion: 2D/3D 对称的直线 intent 策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFLinearProjectileMotion
extends GFProjectileMotion


class _LinearState:
	extends GFProjectileMotionState

	var _velocity_2d: Vector2 = Vector2.ZERO
	var _velocity_3d: Vector3 = Vector3.ZERO


## world-space 运动速度。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var speed: float = 0.0

## 2D 基础方向。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var direction_2d: Vector2 = Vector2.RIGHT

## 3D 基础方向。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var direction_3d: Vector3 = Vector3.FORWARD

## 是否按初始 body basis 将基础方向转换到 world-space。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var use_local_direction: bool = true

## 是否在乘以 speed 前单位化方向。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var normalize_direction: bool = true


func _create_state_2d(
	_launch_input: GFProjectileLaunchInput2D,
	initial_body: GFProjectileBodyResult2D
) -> GFProjectileMotionState:
	if (
		initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
	):
		return null
	var state: _LinearState = _LinearState.new()
	var direction: Vector2 = direction_2d
	if use_local_direction:
		var transform_value: Transform2D = initial_body.get_transform()
		direction = transform_value.basis_xform(direction)
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()
	state._velocity_2d = direction * speed
	return state


func _create_state_3d(
	_launch_input: GFProjectileLaunchInput3D,
	initial_body: GFProjectileBodyResult3D
) -> GFProjectileMotionState:
	if (
		initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
	):
		return null
	var state: _LinearState = _LinearState.new()
	var direction: Vector3 = direction_3d
	if use_local_direction:
		direction = initial_body.get_transform().basis * direction
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()
	state._velocity_3d = direction * speed
	return state


func _compute_intent_2d(
	state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult2D,
	delta: float
) -> GFProjectileMotionIntent2D:
	if typeof(state) != TYPE_OBJECT or not is_instance_valid(state) or not state is _LinearState:
		return GFProjectileMotionIntent2D.rejected(&"invalid_motion_state")
	var linear_state: _LinearState = state
	return GFProjectileMotionIntent2D.move(linear_state._velocity_2d, delta)


func _compute_intent_3d(
	state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult3D,
	delta: float
) -> GFProjectileMotionIntent3D:
	if typeof(state) != TYPE_OBJECT or not is_instance_valid(state) or not state is _LinearState:
		return GFProjectileMotionIntent3D.rejected(&"invalid_motion_state")
	var linear_state: _LinearState = state
	return GFProjectileMotionIntent3D.move(linear_state._velocity_3d, delta)
