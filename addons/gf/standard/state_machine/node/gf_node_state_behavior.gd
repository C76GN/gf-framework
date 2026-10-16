## GFNodeStateBehavior: 节点状态的可复用生命周期行为资源。
##
## 行为资源可挂到 GFNodeState 上复用进入、退出、暂停、恢复和事件处理逻辑。
## 它不替代状态脚本；状态脚本仍负责业务状态的主要控制权。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNodeStateBehavior
extends Resource


# --- 导出变量 ---

## 行为标识，便于调试或项目工具识别。
## [br]
## @api public
@export var behavior_id: StringName = &""

## 是否启用该行为。
## [br]
## @api public
@export var enabled: bool = true

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: 项目自定义元数据 Dictionary；键和值由项目侧约定。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 初始化行为。
## [br]
## @api public
## [br]
## @param state: 行为所属状态。
func initialize(state: GFNodeState) -> void:
	if enabled:
		_initialize(state)


## 状态进入后调用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 行为所属状态。
## [br]
## @param previous_state: 来源状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func enter(
	state: GFNodeState,
	previous_state: StringName = &"",
	args: Dictionary = {}
) -> void:
	if enabled:
		_enter(
			state,
			previous_state,
			args
		)


## 状态退出前调用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 行为所属状态。
## [br]
## @param next_state: 目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func exit(
	state: GFNodeState,
	next_state: StringName = &"",
	args: Dictionary = {}
) -> void:
	if enabled:
		_exit(
			state,
			next_state,
			args
		)


## 状态被栈式子状态覆盖时调用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 行为所属状态。
## [br]
## @param next_state: 目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func pause(
	state: GFNodeState,
	next_state: StringName = &"",
	args: Dictionary = {}
) -> void:
	if enabled:
		_pause(
			state,
			next_state,
			args
		)


## 状态从栈式子状态恢复后调用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 行为所属状态。
## [br]
## @param previous_state: 来源状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func resume(
	state: GFNodeState,
	previous_state: StringName = &"",
	args: Dictionary = {}
) -> void:
	if enabled:
		_resume(
			state,
			previous_state,
			args
		)


## 处理状态事件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param state: 行为所属状态。
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: 状态事件载荷；具体类型由 event_id 和项目约定决定。
## [br]
## @return 已处理返回 true。
func handle_state_event(
	state: GFNodeState,
	event_id: StringName,
	payload: Variant = null
) -> bool:
	if not enabled:
		return false
	return _handle_state_event(
		state,
		event_id,
		payload
	)


# --- 可重写钩子 / 虚方法 ---

## 行为初始化扩展点。
## [br]
## @api protected
## [br]
## @param _state: 行为所属状态。
func _initialize(_state: GFNodeState) -> void:
	pass


## 状态进入行为扩展点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _state: 行为所属状态。
## [br]
## @param _previous_state: 来源状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _enter(
	_state: GFNodeState,
	_previous_state: StringName = &"",
	_args: Dictionary = {}
) -> void:
	pass


## 状态退出行为扩展点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _state: 行为所属状态。
## [br]
## @param _next_state: 目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _exit(
	_state: GFNodeState,
	_next_state: StringName = &"",
	_args: Dictionary = {}
) -> void:
	pass


## 状态暂停行为扩展点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _state: 行为所属状态。
## [br]
## @param _next_state: 目标状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _pause(
	_state: GFNodeState,
	_next_state: StringName = &"",
	_args: Dictionary = {}
) -> void:
	pass


## 状态恢复行为扩展点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _state: 行为所属状态。
## [br]
## @param _previous_state: 来源状态名。
## [br]
## @param _args: 状态切换参数。
## [br]
## @schema _args: 状态切换参数 Dictionary；键和值由调用方约定。
func _resume(
	_state: GFNodeState,
	_previous_state: StringName = &"",
	_args: Dictionary = {}
) -> void:
	pass


## 状态事件行为扩展点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _state: 行为所属状态。
## [br]
## @param _event_id: 状态事件标识。
## [br]
## @param _payload: 状态事件载荷。
## [br]
## @schema _payload: 状态事件载荷；具体类型由 _event_id 和项目约定决定。
## [br]
## @return: 已处理返回 true。
func _handle_state_event(
	_state: GFNodeState,
	_event_id: StringName,
	_payload: Variant = null
) -> bool:
	return false
