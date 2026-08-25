## GFProjectileMotion: 以 per-session state 计算 typed intent 的移动策略基类。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFProjectileMotion
extends Resource


# --- 公共方法 ---

## 为一次 2D session 创建私有 motion state。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param launch_input: 已冻结的 2D 发射输入。
## [br]
## @param initial_body: reserve 阶段捕获的初始 body 快照。
## [br]
## @return: 仅供该 session 使用的 state；拒绝时返回 null。
func create_state_2d(
	launch_input: GFProjectileLaunchInput2D,
	initial_body: GFProjectileBodyResult2D
) -> GFProjectileMotionState:
	var state: Variant = _create_state_2d(launch_input, initial_body)
	if typeof(state) == TYPE_OBJECT and is_instance_valid(state) and state is GFProjectileMotionState:
		var typed_state: GFProjectileMotionState = state
		return typed_state
	return null


## 为一次 3D session 创建私有 motion state。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param launch_input: 已冻结的 3D 发射输入。
## [br]
## @param initial_body: reserve 阶段捕获的初始 body 快照。
## [br]
## @return: 仅供该 session 使用的 state；拒绝时返回 null。
func create_state_3d(
	launch_input: GFProjectileLaunchInput3D,
	initial_body: GFProjectileBodyResult3D
) -> GFProjectileMotionState:
	var state: Variant = _create_state_3d(launch_input, initial_body)
	if typeof(state) == TYPE_OBJECT and is_instance_valid(state) and state is GFProjectileMotionState:
		var typed_state: GFProjectileMotionState = state
		return typed_state
	return null


## 根据 state 与当前 body 快照计算 2D intent，不直接修改 root。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param state: 当前 session 私有 state。
## [br]
## @param current_body: 当前 body 快照。
## [br]
## @param delta: 本帧秒数。
## [br]
## @return: typed 2D intent。
func compute_intent_2d(
	state: GFProjectileMotionState,
	current_body: GFProjectileBodyResult2D,
	delta: float
) -> GFProjectileMotionIntent2D:
	var intent: Variant = _compute_intent_2d(state, current_body, delta)
	if typeof(intent) == TYPE_OBJECT and is_instance_valid(intent) and intent is GFProjectileMotionIntent2D:
		var typed_intent: GFProjectileMotionIntent2D = intent
		return typed_intent
	return GFProjectileMotionIntent2D.rejected(&"invalid_motion_result")


## 根据 state 与当前 body 快照计算 3D intent，不直接修改 root。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param state: 当前 session 私有 state。
## [br]
## @param current_body: 当前 body 快照。
## [br]
## @param delta: 本帧秒数。
## [br]
## @return: typed 3D intent。
func compute_intent_3d(
	state: GFProjectileMotionState,
	current_body: GFProjectileBodyResult3D,
	delta: float
) -> GFProjectileMotionIntent3D:
	var intent: Variant = _compute_intent_3d(state, current_body, delta)
	if typeof(intent) == TYPE_OBJECT and is_instance_valid(intent) and intent is GFProjectileMotionIntent3D:
		var typed_intent: GFProjectileMotionIntent3D = intent
		return typed_intent
	return GFProjectileMotionIntent3D.rejected(&"invalid_motion_result")


# --- 可重写钩子 / 虚方法 ---

## 实现 2D state 创建策略。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _launch_input: 已冻结的发射输入。
## [br]
## @param _initial_body: 初始 body 快照。
## [br]
## @return: session 私有 state。
## [br]
## @schema return: Variant，必须为 live `GFProjectileMotionState`。
func _create_state_2d(
	_launch_input: GFProjectileLaunchInput2D,
	_initial_body: GFProjectileBodyResult2D
) -> Variant:
	return GFProjectileMotionState.new()


## 实现 3D state 创建策略。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _launch_input: 已冻结的发射输入。
## [br]
## @param _initial_body: 初始 body 快照。
## [br]
## @return: session 私有 state。
## [br]
## @schema return: Variant，必须为 live `GFProjectileMotionState`。
func _create_state_3d(
	_launch_input: GFProjectileLaunchInput3D,
	_initial_body: GFProjectileBodyResult3D
) -> Variant:
	return GFProjectileMotionState.new()


## 实现 2D intent 计算策略。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _state: session 私有 state。
## [br]
## @param _current_body: 当前 body 快照。
## [br]
## @param _delta: 本帧秒数；MOVE intent 必须原样回显该 delta，时间缩放应改写 velocity。
## [br]
## @return: typed 2D intent。
## [br]
## @schema return: Variant，必须为 live `GFProjectileMotionIntent2D`。
func _compute_intent_2d(
	_state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult2D,
	_delta: float
) -> Variant:
	return GFProjectileMotionIntent2D.rejected(&"unsupported_motion_dimension")


## 实现 3D intent 计算策略。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param _state: session 私有 state。
## [br]
## @param _current_body: 当前 body 快照。
## [br]
## @param _delta: 本帧秒数；MOVE intent 必须原样回显该 delta，时间缩放应改写 velocity。
## [br]
## @return: typed 3D intent。
## [br]
## @schema return: Variant，必须为 live `GFProjectileMotionIntent3D`。
func _compute_intent_3d(
	_state: GFProjectileMotionState,
	_current_body: GFProjectileBodyResult3D,
	_delta: float
) -> Variant:
	return GFProjectileMotionIntent3D.rejected(&"unsupported_motion_dimension")
