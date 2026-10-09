## GFLinearProjectileMotion: 2D/3D 对称的直线 intent 策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFLinearProjectileMotion
extends GFProjectileMotion


# --- 常量 ---

## 为线性运动配置和锁定速度提供有限数值检查。
## [br]
## @api private
const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

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


# --- 可重写钩子 / 虚方法 ---

## 以初始二维 body 的基向量和当前配置计算并锁定本次 session 的 world-space 速度。
## 可选的方向单位化发生在局部方向转换之后；之后修改策略配置不会重算该状态的速度。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param _launch_input: 保留基类发射协议参数；直线策略不读取目标或其他发射输入。
## [br]
## @param initial_body: 成功的初始 body 快照；开启局部方向时读取其 transform basis。
## [br]
## @return: 保存锁定速度的 session 状态；body 失效或配置、转换后方向及速度非有限时返回 null。
func _create_state_2d(
	_launch_input: GFProjectileLaunchInput2D,
	initial_body: GFProjectileBodyResult2D
) -> GFProjectileMotionState:
	if (
		initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(speed)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(direction_2d)
	):
		return null
	var state: _LinearState = _LinearState.new()
	var direction: Vector2 = direction_2d
	if use_local_direction:
		var transform_value: Transform2D = initial_body.get_transform()
		direction = transform_value.basis_xform(direction)
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(direction):
		return null
	state._velocity_2d = direction * speed
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(state._velocity_2d):
		return null
	return state


## 以初始三维 body 的基向量和当前配置计算并锁定本次 session 的 world-space 速度。
## 可选的方向单位化发生在局部方向转换之后；之后修改策略配置不会重算该状态的速度。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param _launch_input: 保留基类发射协议参数；直线策略不读取目标或其他发射输入。
## [br]
## @param initial_body: 成功的初始 body 快照；开启局部方向时读取其 transform basis。
## [br]
## @return: 保存锁定速度的 session 状态；body 失效或配置、转换后方向及速度非有限时返回 null。
func _create_state_3d(
	_launch_input: GFProjectileLaunchInput3D,
	initial_body: GFProjectileBodyResult3D
) -> GFProjectileMotionState:
	if (
		initial_body == null
		or not is_instance_valid(initial_body)
		or not initial_body.is_successful()
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(speed)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(direction_3d)
	):
		return null
	var state: _LinearState = _LinearState.new()
	var direction: Vector3 = direction_3d
	if use_local_direction:
		direction = initial_body.get_transform().basis * direction
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector3(direction):
		return null
	state._velocity_3d = direction * speed
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector3(state._velocity_3d):
		return null
	return state


## 将 session 已锁定的二维速度交给 intent 工厂，保持发射时确定的直线航向。
## 不重新读取策略配置，也不修改状态或 body。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param state: 本策略创建的 session 状态；其他状态类型返回 invalid_motion_state。
## [br]
## @param _current_body: 保留基类快照参数；本实现不依赖当前位置或朝向。
## [br]
## @param delta: 原样传给 intent 工厂的帧秒数，必须非负且有限。
## [br]
## @return: 锁定速度的 MOVE；状态失效或速度、时长及位移乘积非法时返回 REJECTED。
func _compute_intent_2d(
	state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult2D,
	delta: float
) -> GFProjectileMotionIntent2D:
	if typeof(state) != TYPE_OBJECT or not is_instance_valid(state) or not state is _LinearState:
		return GFProjectileMotionIntent2D.rejected(&"invalid_motion_state")
	var linear_state: _LinearState = state
	return GFProjectileMotionIntent2D.move(linear_state._velocity_2d, delta)


## 将 session 已锁定的三维速度交给 intent 工厂，保持发射时确定的直线航向。
## 不重新读取策略配置，也不修改状态或 body。
## [br]
## @api protected
## [br]
## @since 11.0.0
## [br]
## @param state: 本策略创建的 session 状态；其他状态类型返回 invalid_motion_state。
## [br]
## @param _current_body: 保留基类快照参数；本实现不依赖当前位置或朝向。
## [br]
## @param delta: 原样传给 intent 工厂的帧秒数，必须非负且有限。
## [br]
## @return: 锁定速度的 MOVE；状态失效或速度、时长及位移乘积非法时返回 REJECTED。
func _compute_intent_3d(
	state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult3D,
	delta: float
) -> GFProjectileMotionIntent3D:
	if typeof(state) != TYPE_OBJECT or not is_instance_valid(state) or not state is _LinearState:
		return GFProjectileMotionIntent3D.rejected(&"invalid_motion_state")
	var linear_state: _LinearState = state
	return GFProjectileMotionIntent3D.move(linear_state._velocity_3d, delta)


# --- 内部类 ---

## 保存一次 projectile session 建立后的 2D 与 3D 锁定速度。
## [br]
## @api private
class _LinearState:
	extends GFProjectileMotionState

	# --- 私有变量 ---

	## 创建 session 状态时确定的二维速度，后续 intent 直接复用。
	## [br]
	## @api private
	var _velocity_2d: Vector2 = Vector2.ZERO

	## 创建 session 状态时确定的三维速度，后续 intent 直接复用。
	## [br]
	## @api private
	var _velocity_3d: Vector3 = Vector3.ZERO
