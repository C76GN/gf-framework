@tool

## GFNodeStateGroup: 管理一组互斥激活的节点状态。
##
## 一个状态组内同一时间只有一个 GFNodeState 处于启用状态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFNodeStateGroup
extends Node


# --- 信号 ---

## 状态加入组后发出。
## [br]
## @api public
## [br]
## @param state: 新加入的状态节点。
signal state_added(state: GFNodeState)

## 状态从组中移除后发出。
## [br]
## @api public
## [br]
## @param state: 被移除的状态节点。
signal state_removed(state: GFNodeState)

## 当前状态切换后发出。
## [br]
## @api public
## [br]
## @param old_state: 切换前的状态；没有旧状态时为 null。
## [br]
## @param new_state: 切换后的状态；状态组停止时可为 null。
signal current_state_changed(old_state: GFNodeState, new_state: GFNodeState)

## 状态切换被守卫阻止后发出。
## [br]
## @api public
## [br]
## @param from_state: 发起切换时的当前状态；没有当前状态时为 null。
## [br]
## @param to_state_name: 被阻止的目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @param reason: 阻止原因，通常为 "exit_guard" 或 "enter_guard"。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
signal transition_blocked(from_state: GFNodeState, to_state_name: StringName, args: Dictionary, reason: String)

## 子状态请求跨组切换时发出。
## [br]
## @api public
## [br]
## @param group_name: 目标状态组名。
## [br]
## @param state_name: 目标状态名。
## [br]
## @param args: 状态切换参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
signal requested_transition(group_name: StringName, state_name: StringName, args: Dictionary)

## 当前状态或暂停栈状态处理状态事件后发出。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param handler_state: 实际处理事件的状态节点。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。
signal state_event_handled(event_id: StringName, handler_state: GFNodeState, payload: Variant)


# --- 常量 ---

# --- 导出变量 ---

## 状态组注册名。为空时使用节点名称。
## [br]
## @api public
@export var group_name: StringName = &"":
	set(value):
		group_name = value
		_queue_configuration_warning_update()

## 初始状态名。
## [br]
## @api public
@export var initial_state: StringName = &"":
	set(value):
		initial_state = value
		_queue_configuration_warning_update()

## 初始状态参数。
## [br]
## @api public
## [br]
## @schema initial_args: 初始状态参数 Dictionary；键和值由初始状态的项目逻辑约定。
@export var initial_args: Dictionary = {}

## ready 时是否自动从子节点加载状态。
## [br]
## @api public
@export var reload_states_on_ready: bool = true

## 初始化后是否自动进入 initial_state。关闭后可通过 start() 手动启动。
## [br]
## @api public
@export var auto_start: bool = true:
	set(value):
		auto_start = value
		_queue_configuration_warning_update()

## 每个状态组保留的历史状态名数量。
## [br]
## @api public
@export_range(1, 256, 1) var history_max_size: int = 32

## push_state 可叠加的最大栈深度。
## [br]
## @api public
@export_range(1, 64, 1) var max_stack_depth: int = 8

## 状态组共享黑板。框架不解释其中字段。
## [br]
## @api public
## [br]
## @schema blackboard: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定。
@export var blackboard: Dictionary = {}


# --- 私有变量 ---

var _states: Dictionary = {}
var _state_keys_by_instance_id: Dictionary = {}
var _current_state: GFNodeState = null
var _state_stack: Array[GFNodeState] = []
var _history: Array[StringName] = []
var _machine_ref: WeakRef = null
var _is_ready: bool = false
var _reload_queued: bool = false
var _transition_serial: int = 0
var _is_exiting_current_state: bool = false
var _has_queued_exit_transition: bool = false
var _queued_exit_state_name: StringName = &""
var _queued_exit_args: Dictionary = {}


# --- Godot 生命周期方法 ---

func _enter_tree() -> void:
	if not child_entered_tree.is_connected(_on_child_entered_tree):
		var _child_entered_connect_error: int = child_entered_tree.connect(_on_child_entered_tree)
	if not child_exiting_tree.is_connected(_on_child_exiting_tree):
		var _child_exiting_connect_error: int = child_exiting_tree.connect(_on_child_exiting_tree)
	_queue_configuration_warning_update()


func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return

	var parent_node: Node = get_parent()
	if parent_node is GFNodeStateMachine:
		return
	_is_ready = true
	initialize()


func _exit_tree() -> void:
	_is_ready = false
	_reload_queued = false
	if child_entered_tree.is_connected(_on_child_entered_tree):
		child_entered_tree.disconnect(_on_child_entered_tree)
	if child_exiting_tree.is_connected(_on_child_exiting_tree):
		child_exiting_tree.disconnect(_on_child_exiting_tree)
	if Engine.is_editor_hint():
		return
	clear_states(false)


# --- Godot 回调方法 ---

func _get_configuration_warnings() -> PackedStringArray:
	var report: GFValidationReport = GFNodeStateMachineValidator.validate_group(self)
	var warnings: PackedStringArray = GFNodeStateMachineValidator.make_configuration_warnings(report)
	return warnings


# --- 公共方法 ---

## 获取状态组注册名。
## [br]
## @api public
## [br]
## @return: 非空 group_name，或节点名称转换出的 StringName。
func get_group_name() -> StringName:
	if group_name != &"":
		return group_name
	return StringName(name)


## 切换到指定状态。
## [br]
## @api public
## [br]
## @param next_state_name: 要切换到的目标状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func transition_to(next_state_name: StringName, args: Dictionary = {}) -> void:
	var next_state: GFNodeState = _get_registered_state(next_state_name)
	if next_state == null:
		_warn_missing_state(next_state_name)
		return

	if _is_exiting_current_state:
		_transition_serial += 1
		_queue_exit_transition(next_state_name, args)
		return

	_transition_serial += 1
	var current_serial: int = _transition_serial
	var previous_state: GFNodeState = _current_state
	var previous_name: StringName = &""
	if previous_state != null:
		previous_name = _get_registered_state_key(previous_state)
	if not _can_transition(previous_state, next_state, next_state_name, previous_name, args):
		return
	if previous_state != null:
		_is_exiting_current_state = true
		previous_state.exit(next_state_name, args)
		previous_state.unregister_owner_events()
		_is_exiting_current_state = false
		var had_queued_transition: bool = _has_queued_exit_transition
		if had_queued_transition:
			var queued_transition: _QueuedExitTransition = _take_queued_exit_transition(next_state_name, args)
			next_state_name = queued_transition._state_name
			args = queued_transition._args
			current_serial = _transition_serial
			next_state = _get_registered_state(next_state_name)
			if next_state == null:
				_current_state = null
				_warn_missing_state(next_state_name)
				return
			if not _can_enter_state(next_state, previous_name, args):
				_current_state = null
				_emit_transition_blocked(previous_state, next_state_name, args, "enter_guard")
				return

	if not _state_stack.is_empty():
		_is_exiting_current_state = true
		_clear_stack(next_state_name, args)
		_is_exiting_current_state = false
		var had_stack_queued_transition: bool = _has_queued_exit_transition
		if had_stack_queued_transition:
			var stack_queued_transition: _QueuedExitTransition = _take_queued_exit_transition(next_state_name, args)
			next_state_name = stack_queued_transition._state_name
			args = stack_queued_transition._args
			current_serial = _transition_serial
			next_state = _get_registered_state(next_state_name)
			if next_state == null:
				_current_state = null
				_warn_missing_state(next_state_name)
				return
			if not _can_enter_state(next_state, previous_name, args):
				_current_state = null
				_emit_transition_blocked(previous_state, next_state_name, args, "enter_guard")
				return

	_current_state = next_state
	_current_state.enter(previous_name, args)
	_push_history(next_state_name)
	if current_serial == _transition_serial and _current_state == next_state:
		current_state_changed.emit(previous_state, _current_state)


## 暂停当前状态并叠加进入一个子状态。
## [br]
## @api public
## [br]
## @param next_state_name: 要切换到的目标状态名称。
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func push_state(next_state_name: StringName, args: Dictionary = {}) -> void:
	var next_state: GFNodeState = _get_registered_state(next_state_name)
	if next_state == null:
		_warn_missing_state(next_state_name)
		return

	if _current_state == null:
		transition_to(next_state_name, args)
		return

	if _is_exiting_current_state:
		push_warning("[GFNodeStateGroup] push_state 失败：当前状态正在退出。")
		return

	if _state_stack.size() >= maxi(max_stack_depth, 1):
		push_warning("[GFNodeStateGroup] push_state 失败：状态栈已达到上限。")
		return

	if next_state == _current_state:
		push_warning("[GFNodeStateGroup] push_state 失败：不能将当前状态再次压栈。")
		return

	var previous_state: GFNodeState = _current_state
	var previous_name: StringName = _get_registered_state_key(previous_state)
	if not _can_push_state(previous_state, next_state, next_state_name, previous_name, args):
		return
	_transition_serial += 1
	var push_serial: int = _transition_serial
	previous_state.pause(next_state_name, args)
	if push_serial != _transition_serial or _current_state != previous_state:
		return
	_state_stack.append(previous_state)
	_current_state = next_state
	_current_state.enter(previous_name, args)
	_push_history(next_state_name)
	current_state_changed.emit(previous_state, _current_state)


## 退出当前子状态并恢复上一层状态。
## [br]
## @api public
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
## [br]
## @return: 成功恢复上一层状态时返回 true。
func pop_state(args: Dictionary = {}) -> bool:
	if _state_stack.is_empty():
		return false

	if _current_state == null:
		var fallback_restore_state: GFNodeState = _pop_stack_state()
		_current_state = fallback_restore_state
		if fallback_restore_state != null:
			fallback_restore_state.resume(&"", args)
			_push_history(_get_registered_state_key(fallback_restore_state))
		current_state_changed.emit(null, _current_state)
		return true

	if _is_exiting_current_state:
		push_warning("[GFNodeStateGroup] pop_state 失败：当前状态正在退出。")
		return false

	var previous_state: GFNodeState = _current_state
	var restore_state: GFNodeState = _pop_stack_state()
	if restore_state == null:
		return false

	var previous_name: StringName = _get_registered_state_key(previous_state)
	var restore_name: StringName = _get_registered_state_key(restore_state)
	if not _can_transition(previous_state, restore_state, restore_name, previous_name, args):
		_state_stack.append(restore_state)
		return false

	_transition_serial += 1
	var pop_serial: int = _transition_serial
	_is_exiting_current_state = true
	previous_state.exit(restore_name, args)
	previous_state.unregister_owner_events()

	if _has_queued_exit_transition:
		var queued_transition: _QueuedExitTransition = _take_queued_exit_transition(restore_name, args)
		var queued_state_name: StringName = queued_transition._state_name
		var queued_args: Dictionary = queued_transition._args
		restore_state.exit(queued_state_name, queued_args)
		restore_state.unregister_owner_events()

		queued_transition = _take_queued_exit_transition(queued_state_name, queued_args)
		queued_state_name = queued_transition._state_name
		queued_args = queued_transition._args

		_clear_stack(queued_state_name, queued_args)
		queued_transition = _take_queued_exit_transition(queued_state_name, queued_args)
		queued_state_name = queued_transition._state_name
		queued_args = queued_transition._args

		_is_exiting_current_state = false
		_current_state = null
		if _get_registered_state(queued_state_name) == null:
			_warn_missing_state(queued_state_name)
			current_state_changed.emit(previous_state, _current_state)
			return true
		transition_to(queued_state_name, queued_args)
		return true

	_is_exiting_current_state = false
	_current_state = restore_state
	_current_state.resume(previous_name, args)
	if pop_serial != _transition_serial or _current_state != restore_state:
		return true
	_push_history(restore_name)
	current_state_changed.emit(previous_state, _current_state)
	return true


## 添加状态节点。
## [br]
## @api public
## [br]
## @param state: 状态节点。
func add_state(state: GFNodeState) -> void:
	if state == null:
		return

	var key: StringName = state.get_state_name()
	if _states.has(key):
		push_warning("[GFNodeStateGroup] 状态已存在，已忽略重复添加：%s" % key)
		return

	state.setup(_get_machine(), self)
	if not state.requested_transition.is_connected(_on_state_requested_transition):
		var _transition_connect_error: int = state.requested_transition.connect(_on_state_requested_transition)
	_states[key] = state
	_state_keys_by_instance_id[state.get_instance_id()] = key
	state.initialize()
	state_added.emit(state)


## 移除状态节点。
## [br]
## @api public
## [br]
## @param state: 状态节点。
## [br]
## @return: 成功移除已注册状态时返回 true。
func remove_state(state: GFNodeState) -> bool:
	if state == null:
		return false

	var key: StringName = _get_registered_state_key(state)
	if not _states.has(key):
		return false
	if _current_state == state:
		_remove_current_state(state, key)
	else:
		_remove_from_stack(state)
	if state.requested_transition.is_connected(_on_state_requested_transition):
		state.requested_transition.disconnect(_on_state_requested_transition)
	state.unregister_owner_events()
	var _erased_state: bool = _states.erase(key)
	var _erased_state_key: bool = _state_keys_by_instance_id.erase(state.get_instance_id())
	state_removed.emit(state)
	return true


## 获取状态。
## [br]
## @api public
## [br]
## @param query_state_name: 目标名称。
## [br]
## @return: 注册名对应的状态节点；不存在时返回 null。
func get_state(query_state_name: StringName) -> GFNodeState:
	return _get_registered_state(query_state_name)


## 获取当前状态。
## [br]
## @api public
## [br]
## @return: 当前激活状态；未启动或已停止时返回 null。
func get_current_state() -> GFNodeState:
	return _current_state


## 获取当前状态名。
## [br]
## @api public
## [br]
## @return: 当前激活状态名；未启动或已停止时返回空 StringName。
func get_current_state_name() -> StringName:
	if _current_state == null:
		return &""
	return _get_registered_state_key(_current_state)


## 获取状态切换历史。
## [br]
## @api public
## [br]
## @return: 最近进入过的状态名列表。
## [br]
## @schema return: 状态历史 Array[StringName]，按进入顺序排列。
func get_state_history() -> Array[StringName]:
	var result: Array[StringName] = []
	for state_name: StringName in _history:
		result.append(state_name)
	return result


## 获取当前暂停栈深度。
## [br]
## @api public
## [br]
## @return: 当前暂停栈深度。
func get_stack_depth() -> int:
	return _state_stack.size()


## 获取状态组共享黑板。
## [br]
## @api public
## [br]
## @return: 黑板字典。
## [br]
## @schema return: 状态组共享黑板 Dictionary；键和值由项目状态逻辑约定，调用方可直接修改。
func get_blackboard() -> Dictionary:
	return blackboard


## 从当前状态开始向暂停栈上抛状态事件。
## [br]
## @api public
## [br]
## @param event_id: 状态事件标识。
## [br]
## @param payload: 状态事件载荷。
## [br]
## @schema payload: 状态事件载荷；具体结构由 event_id 和项目逻辑约定。
## [br]
## @return: 有状态处理该事件时返回 true。
func dispatch_state_event(event_id: StringName, payload: Variant = null) -> bool:
	var candidates: Array[GFNodeState] = _get_event_dispatch_candidates()
	for state: GFNodeState in candidates:
		if state.handle_state_event(event_id, payload):
			state_event_handled.emit(event_id, state, payload)
			return true
	return false


## 判断指定状态是否为当前状态或暂停栈中的状态。
## [br]
## @api public
## [br]
## @param query_state_name: 目标名称。
## [br]
## @return: 指定状态位于当前状态或暂停栈中时返回 true。
func is_in_state(query_state_name: StringName) -> bool:
	if get_current_state_name() == query_state_name:
		return true

	for state: GFNodeState in _state_stack:
		if _get_registered_state_key(state) == query_state_name:
			return true

	return false


## 重启当前状态；若当前没有状态，则尝试进入初始状态。
## [br]
## @api public
## [br]
## @param args: 状态切换时传递的可选参数。
## [br]
## @schema args: 状态切换参数 Dictionary；键和值由调用方约定。
func restart(args: Dictionary = {}) -> void:
	if _current_state == null:
		start(args)
		return

	transition_to(get_current_state_name(), args)


## 进入初始状态。若已有当前状态则保持不变。
## [br]
## @api public
## [br]
## @param args: 启动时传给初始状态的参数；为空时使用 initial_args。
## [br]
## @schema args: 启动参数 Dictionary；为空时使用 initial_args。
func start(args: Dictionary = {}) -> void:
	if _current_state != null or initial_state == &"":
		return

	transition_to(initial_state, args if not args.is_empty() else initial_args)


## 停止当前激活状态，但保留已注册状态节点。
## [br]
## @api public
func stop() -> void:
	_exit_active_states_for_clear()
	_current_state = null
	_state_stack.clear()
	_history.clear()
	_is_exiting_current_state = false
	_clear_queued_exit_transition()


## 获取所有状态。
## [br]
## @api public
## [br]
## @return: 已注册状态节点列表。
## [br]
## @schema return: 已注册 GFNodeState 节点数组。
func get_states() -> Array[GFNodeState]:
	var result: Array[GFNodeState] = []
	for state: GFNodeState in _states.values():
		result.append(state)
	return result


## 获取状态组调试快照。
## [br]
## @api public
## [br]
## @return: 包含当前状态、暂停栈、历史、注册状态和黑板副本的字典。
## [br]
## @schema return: 调试快照 Dictionary，包含 group_name、current_state、stack、history、states 和 blackboard 字段。
func get_state_snapshot() -> Dictionary:
	return {
		"group_name": get_group_name(),
		"current_state": get_current_state_name(),
		"stack": _get_stack_state_names(),
		"history": get_state_history(),
		"states": _get_registered_state_names(),
		"blackboard": blackboard.duplicate(true),
	}


## 从状态组快照恢复当前状态、暂停栈、历史与黑板。
## [br]
## @api framework_internal
## [br]
## @since 6.0.0
## [br]
## @param snapshot: get_state_snapshot() 返回的状态组快照。
## [br]
## @schema snapshot: Dictionary，包含 current_state、stack、history 和 blackboard 字段。
func restore_state_snapshot(snapshot: Dictionary) -> void:
	stop()
	blackboard = GFVariantData.get_option_dictionary(snapshot, "blackboard").duplicate(true)

	var stack_names: Array = GFVariantData.get_option_array(snapshot, "stack")
	for stack_name_value: Variant in stack_names:
		var stack_state_name: StringName = GFVariantData.to_string_name(stack_name_value)
		if stack_state_name == &"" or _get_registered_state(stack_state_name) == null:
			continue
		if _current_state == null:
			transition_to(stack_state_name, {})
		elif get_current_state_name() != stack_state_name:
			push_state(stack_state_name, {})

	var current_state_name: StringName = GFVariantData.get_option_string_name(snapshot, "current_state")
	if current_state_name != &"" and _get_registered_state(current_state_name) != null:
		if _current_state == null:
			transition_to(current_state_name, {})
		elif get_current_state_name() != current_state_name:
			push_state(current_state_name, {})

	_history.clear()
	for history_value: Variant in GFVariantData.get_option_array(snapshot, "history"):
		var history_name: StringName = GFVariantData.to_string_name(history_value)
		if history_name != &"" and _get_registered_state(history_name) != null:
			_history.append(history_name)
	_trim_history()


## 清空状态。
## [br]
## @api public
## [br]
## @param free_states: 为 true 时同时释放已移除的状态节点。
func clear_states(free_states: bool = false) -> void:
	var states: Array[GFNodeState] = get_states()
	stop()
	_states.clear()
	_state_keys_by_instance_id.clear()
	for state: GFNodeState in states:
		if state.requested_transition.is_connected(_on_state_requested_transition):
			state.requested_transition.disconnect(_on_state_requested_transition)
		state.unregister_owner_events()
		state_removed.emit(state)
		if free_states:
			_queue_free_detached(state)


## 从子节点重新加载状态。
## [br]
## @api public
func reload_states_from_children() -> void:
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return

	clear_states()
	for child: Node in get_children():
		var child_state: GFNodeState = _node_as_state(child)
		if child_state != null:
			add_state(child_state)


# --- 框架内部方法 ---

## 初始化状态组，并在状态机托管模式下注入所属状态机。
## [br]
## @api framework_internal
## [br]
## @param machine: 所属节点状态机；独立状态组初始化时可为 null。
## [br]
## @param start_initial_state: 本次初始化是否允许自动进入 initial_state。
func initialize(machine: Object = null, start_initial_state: bool = true) -> void:
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return

	_is_ready = true
	if machine != null:
		_machine_ref = weakref(machine)
		_setup_existing_states()
	if reload_states_on_ready:
		reload_states_from_children()
	if auto_start and start_initial_state:
		start()


# --- 私有/辅助方法 ---

func _get_machine() -> Object:
	if _machine_ref == null:
		return null
	return _machine_ref.get_ref()


func _queue_free_detached(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


func _get_event_dispatch_candidates() -> Array[GFNodeState]:
	var result: Array[GFNodeState] = []
	if _current_state != null:
		result.append(_current_state)
	for index: int in range(_state_stack.size() - 1, -1, -1):
		var state: GFNodeState = _get_stack_state_at(index)
		if state != null and is_instance_valid(state):
			result.append(state)
	return result


func _get_stack_state_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for state: GFNodeState in _state_stack:
		if state != null:
			result.append(_get_registered_state_key(state))
	return result


func _get_registered_state_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for state_name: StringName in _states.keys():
		result.append(state_name)
	return result


func _setup_existing_states() -> void:
	for state: GFNodeState in _states.values():
		state.setup(_get_machine(), self)


func _exit_active_states_for_clear() -> void:
	var current_state: GFNodeState = _current_state
	var stacked_states: Array[GFNodeState] = _copy_state_stack()
	_is_exiting_current_state = true
	if current_state != null:
		current_state.exit(&"", {})
		current_state.unregister_owner_events()
	for state: GFNodeState in stacked_states:
		if state != null and state != current_state:
			state.exit(&"", {})
			state.unregister_owner_events()
	_is_exiting_current_state = false
	_clear_queued_exit_transition()


func _is_node_state(node: Node) -> bool:
	return _node_as_state(node) != null


func _node_as_state(node: Node) -> GFNodeState:
	if node is GFNodeState:
		return node
	return null


func _get_registered_state(state_name: StringName) -> GFNodeState:
	var state_value: Variant = GFVariantData.get_option_value(_states, state_name)
	if state_value is GFNodeState:
		return state_value
	return null


func _get_registered_state_key(state: GFNodeState) -> StringName:
	if state == null:
		return &""
	var key_value: Variant = GFVariantData.get_option_value(
		_state_keys_by_instance_id,
		state.get_instance_id(),
		state.get_state_name()
	)
	return GFVariantData.to_string_name(key_value)


func _get_stack_state_at(index: int) -> GFNodeState:
	if index < 0 or index >= _state_stack.size():
		return null
	var state_value: Variant = _state_stack[index]
	if state_value is GFNodeState:
		return state_value
	return null


func _pop_stack_state() -> GFNodeState:
	if _state_stack.is_empty():
		return null
	var state_value: Variant = _state_stack.pop_back()
	if state_value is GFNodeState:
		return state_value
	return null


func _copy_state_stack() -> Array[GFNodeState]:
	var result: Array[GFNodeState] = []
	for state: GFNodeState in _state_stack:
		result.append(state)
	return result


func _warn_missing_state(state_name: StringName) -> void:
	push_warning("[GFNodeStateGroup] 切换失败，未找到状态：%s" % state_name)


func _can_transition(
	previous_state: GFNodeState,
	next_state: GFNodeState,
	next_state_name: StringName,
	previous_state_name: StringName,
	args: Dictionary
) -> bool:
	if not _can_exit_state(previous_state, next_state_name, args):
		_emit_transition_blocked(previous_state, next_state_name, args, "exit_guard")
		return false
	if not _can_enter_state(next_state, previous_state_name, args):
		_emit_transition_blocked(previous_state, next_state_name, args, "enter_guard")
		return false
	return true


func _can_push_state(
	previous_state: GFNodeState,
	next_state: GFNodeState,
	next_state_name: StringName,
	previous_state_name: StringName,
	args: Dictionary
) -> bool:
	if not _can_enter_state(next_state, previous_state_name, args):
		_emit_transition_blocked(previous_state, next_state_name, args, "enter_guard")
		return false
	return true


func _can_exit_state(state: GFNodeState, next_state_name: StringName, args: Dictionary) -> bool:
	if state == null:
		return true
	return state.can_exit(next_state_name, args)


func _can_enter_state(state: GFNodeState, previous_state_name: StringName, args: Dictionary) -> bool:
	if state == null:
		return true
	return state.can_enter(previous_state_name, args)


func _emit_transition_blocked(from_state: GFNodeState, to_state_name: StringName, args: Dictionary, reason: String) -> void:
	transition_blocked.emit(from_state, to_state_name, args.duplicate(true), reason)


func _push_history(state_name: StringName) -> void:
	_history.append(state_name)
	_trim_history()


func _trim_history() -> void:
	var max_size: int = maxi(history_max_size, 1)
	while _history.size() > max_size:
		_history.pop_front()


func _clear_stack(next_state_name: StringName, args: Dictionary) -> void:
	while not _state_stack.is_empty():
		var state: GFNodeState = _pop_stack_state()
		if state != null and is_instance_valid(state):
			state.exit(next_state_name, args)
			state.unregister_owner_events()


func _queue_exit_transition(state_name: StringName, args: Dictionary) -> void:
	_has_queued_exit_transition = true
	_queued_exit_state_name = state_name
	_queued_exit_args = args


func _clear_queued_exit_transition() -> void:
	_has_queued_exit_transition = false
	_queued_exit_state_name = &""
	_queued_exit_args = {}


func _take_queued_exit_transition(default_state_name: StringName, default_args: Dictionary) -> _QueuedExitTransition:
	if not _has_queued_exit_transition:
		return _QueuedExitTransition.new(default_state_name, default_args)

	var result: _QueuedExitTransition = _QueuedExitTransition.new(_queued_exit_state_name, _queued_exit_args)
	_clear_queued_exit_transition()
	return result


func _remove_current_state(state: GFNodeState, state_name: StringName) -> void:
	var previous_state: GFNodeState = _current_state
	var restore_state: GFNodeState = _peek_stack_restore_state(state)
	var restore_name: StringName = &""
	if restore_state != null:
		restore_name = _get_registered_state_key(restore_state)

	_transition_serial += 1
	var remove_serial: int = _transition_serial
	_is_exiting_current_state = true
	state.exit(restore_name, {})
	state.unregister_owner_events()

	if _has_queued_exit_transition:
		var queued_transition: _QueuedExitTransition = _take_queued_exit_transition(restore_name, {})
		var queued_state_name: StringName = queued_transition._state_name
		var queued_args: Dictionary = queued_transition._args
		_current_state = null
		if queued_state_name == state_name or _get_registered_state(queued_state_name) == null:
			_is_exiting_current_state = false
			_warn_missing_state(queued_state_name)
			current_state_changed.emit(previous_state, _current_state)
			return
		_clear_stack(queued_state_name, queued_args)

		queued_transition = _take_queued_exit_transition(queued_state_name, queued_args)
		queued_state_name = queued_transition._state_name
		queued_args = queued_transition._args

		_is_exiting_current_state = false
		if queued_state_name == state_name or _get_registered_state(queued_state_name) == null:
			_warn_missing_state(queued_state_name)
			current_state_changed.emit(previous_state, _current_state)
			return
		transition_to(queued_state_name, queued_args)
		return

	_is_exiting_current_state = false
	_current_state = _pop_stack_restore_state(state)
	if _current_state != null:
		var restored_name: StringName = _get_registered_state_key(_current_state)
		_current_state.resume(state_name, {})
		if remove_serial != _transition_serial or _current_state == null or _get_registered_state_key(_current_state) != restored_name:
			return
		_push_history(restored_name)
	current_state_changed.emit(previous_state, _current_state)


func _peek_stack_restore_state(excluded_state: GFNodeState) -> GFNodeState:
	for index: int in range(_state_stack.size() - 1, -1, -1):
		var state: GFNodeState = _get_stack_state_at(index)
		if _is_valid_stack_restore_state(state, excluded_state):
			return state
	return null


func _pop_stack_restore_state(excluded_state: GFNodeState) -> GFNodeState:
	while not _state_stack.is_empty():
		var state: GFNodeState = _pop_stack_state()
		if _is_valid_stack_restore_state(state, excluded_state):
			return state
	return null


func _is_valid_stack_restore_state(state: GFNodeState, excluded_state: GFNodeState) -> bool:
	if state == null or state == excluded_state or not is_instance_valid(state):
		return false
	var state_name: StringName = _get_registered_state_key(state)
	return _get_registered_state(state_name) == state


func _remove_from_stack(state: GFNodeState) -> void:
	var index: int = _state_stack.find(state)
	while index != -1:
		_state_stack.remove_at(index)
		index = _state_stack.find(state)


func _on_state_requested_transition(
	target_group_name: StringName,
	target_state_name: StringName,
	args: Dictionary
) -> void:
	if target_group_name == &"" or target_group_name == get_group_name():
		transition_to(target_state_name, args)
	else:
		requested_transition.emit(target_group_name, target_state_name, args)


func _queue_reload_from_children() -> void:
	if not _is_ready or not reload_states_on_ready or _reload_queued:
		return

	_reload_queued = true
	call_deferred("_reload_from_children_deferred")


func _queue_configuration_warning_update() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("update_configuration_warnings")


func _reload_from_children_deferred() -> void:
	_reload_queued = false
	if Engine.is_editor_hint():
		_queue_configuration_warning_update()
		return
	if _is_ready and reload_states_on_ready:
		reload_states_from_children()
		if auto_start:
			start()


func _on_child_entered_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		if _is_node_state(child):
			_queue_configuration_warning_update()
		return

	if _is_node_state(child):
		_queue_reload_from_children()


func _on_child_exiting_tree(child: Node) -> void:
	if Engine.is_editor_hint():
		if _is_node_state(child):
			_queue_configuration_warning_update()
		return

	if _is_node_state(child):
		_queue_reload_from_children()


# --- 内部类 ---

class _QueuedExitTransition:
	var _state_name: StringName = &""
	var _args: Dictionary = {}

	func _init(p_state_name: StringName = &"", p_args: Dictionary = {}) -> void:
		_state_name = p_state_name
		_args = p_args
