# GFAsyncWaitSupport: 内部异步等待辅助。
#
# 提供 Signal 安全断开和受 GFTimeUtility 影响的超时增量计算，供流程、序列和动作队列复用。
extends RefCounted


# --- 常量 ---

## 单次等待最多捕获的 Signal 参数数量。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const MAX_CAPTURED_SIGNAL_ARGUMENTS: int = 16


# --- 公共方法 ---

## 安全等待 Signal，并在发射源失效、保护节点离树、取消回调返回 false 或超时时结束等待。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param result_signal: 要等待的 Signal。
## [br]
## @param should_continue: 可选继续等待检查；返回 false 时停止等待。
## [br]
## @param time_utility: 可选时间工具。
## [br]
## @param timeout_seconds: 超时时间；小于等于 0 时不启用。
## [br]
## @param respect_time_scale: 是否跟随暂停和 time_scale。
## [br]
## @param timeout_warning: 超时时输出的 warning；为空时不输出。
## [br]
## @param guard_node: 可选生命周期保护节点。
## [br]
## @return Signal 正常发出或 tree_exited 保护触发时返回 true。
static func await_signal_safely(
	result_signal: Signal,
	should_continue: Callable = Callable(),
	time_utility: GFTimeUtility = null,
	timeout_seconds: float = 30.0,
	respect_time_scale: bool = true,
	timeout_warning: String = "",
	guard_node: Node = null
) -> bool:
	var result: Dictionary = await _await_signal_state_safely(
		result_signal,
		should_continue,
		time_utility,
		timeout_seconds,
		respect_time_scale,
		timeout_warning,
		guard_node,
		false
	)
	return GFVariantData.get_option_bool(result, "completed")


## 安全等待 Signal，并保留 Signal 发射时携带的参数。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param result_signal: 要等待的 Signal。
## [br]
## @param should_continue: 可选继续等待检查；返回 false 时停止等待。
## [br]
## @param time_utility: 可选时间工具。
## [br]
## @param timeout_seconds: 超时时间；小于等于 0 时不启用。
## [br]
## @param respect_time_scale: 是否跟随暂停和 time_scale。
## [br]
## @param timeout_warning: 超时时输出的 warning；为空时不输出。
## [br]
## @param guard_node: 可选生命周期保护节点。
## [br]
## @return 包含 completed 与 args 的等待结果。
## [br]
## @schema return: Dictionary with completed: bool and args: Array.
static func await_signal_payload_safely(
	result_signal: Signal,
	should_continue: Callable = Callable(),
	time_utility: GFTimeUtility = null,
	timeout_seconds: float = 30.0,
	respect_time_scale: bool = true,
	timeout_warning: String = "",
	guard_node: Node = null
) -> Dictionary:
	return await _await_signal_state_safely(
		result_signal,
		should_continue,
		time_utility,
		timeout_seconds,
		respect_time_scale,
		timeout_warning,
		guard_node,
		true
	)


## 计算超时累计增量。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param previous_msec: 上一次采样时间。
## [br]
## @param current_msec: 当前采样时间。
## [br]
## @param time_utility: 可选时间工具。
## [br]
## @param respect_time_scale: 是否跟随暂停和 time_scale。
## [br]
## @return 超时增量毫秒。
static func get_timeout_elapsed_msec(
	previous_msec: int,
	current_msec: int,
	time_utility: GFTimeUtility,
	respect_time_scale: bool
) -> float:
	var elapsed_msec: float = float(current_msec - previous_msec)
	if not respect_time_scale:
		return elapsed_msec
	if time_utility == null:
		return elapsed_msec
	if time_utility.is_paused:
		return 0.0
	return elapsed_msec * time_utility.time_scale


## 创建可忽略 Signal 参数的恢复回调。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param target_signal: 目标信号。
## [br]
## @param callback: 原始无参恢复回调。
## [br]
## @return 可连接到目标信号的回调。
static func make_signal_resume_callable(target_signal: Signal, callback: Callable) -> Callable:
	var argument_count: int = get_signal_argument_count(target_signal)
	if argument_count <= 0:
		return callback
	return callback.unbind(argument_count)


## 获取信号定义中的参数数量。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param target_signal: 目标信号。
## [br]
## @return 参数数量。
static func get_signal_argument_count(target_signal: Signal) -> int:
	if target_signal.is_null():
		return 0
	var target_obj: Object = target_signal.get_object()
	if not is_instance_valid(target_obj):
		return 0

	var target_name: StringName = StringName(target_signal.get_name())
	for signal_info: Dictionary in target_obj.get_signal_list():
		if GFVariantData.get_option_string_name(signal_info, "name", &"") != target_name:
			continue
		var args: Array = GFVariantData.to_array(GFVariantData.get_option_value(signal_info, "args", []))
		return args.size()
	return 0


## 若信号已连接指定回调，则安全断开。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param target_signal: 目标信号。
## [br]
## @param callback: 回调。
static func disconnect_signal_if_connected(target_signal: Signal, callback: Callable) -> void:
	if target_signal.is_null():
		return
	if not is_instance_valid(target_signal.get_object()):
		return
	if target_signal.is_connected(callback):
		target_signal.disconnect(callback)


# --- 私有/辅助方法 ---

static func _await_signal_state_safely(
	result_signal: Signal,
	should_continue: Callable,
	time_utility: GFTimeUtility,
	timeout_seconds: float,
	respect_time_scale: bool,
	timeout_warning: String,
	guard_node: Node,
	capture_payload: bool
) -> Dictionary:
	if result_signal.is_null():
		return {
			"completed": false,
			"args": [],
		}

	var target_obj: Object = result_signal.get_object()
	if not is_instance_valid(target_obj):
		return {
			"completed": false,
			"args": [],
		}

	var completion_state: Dictionary = {
		"completed": false,
		"args": [],
	}
	var on_resume: Callable = func() -> void:
		completion_state["completed"] = true
	var result_callback: Callable = _make_signal_capture_callable(result_signal, completion_state) if capture_payload else make_signal_resume_callable(result_signal, on_resume)
	var tree_exit_callback: Callable = on_resume
	var guard_exit_callback: Callable = on_resume

	var _result_connect_result: int = result_signal.connect(
		result_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)

	var tree_exit_signal: Signal = Signal()
	var guard_exit_signal: Signal = Signal()
	if target_obj is Node:
		var node: Node = _variant_to_node(target_obj)
		if not node.is_inside_tree() and result_signal != node.tree_exited:
			disconnect_signal_if_connected(result_signal, result_callback)
			return completion_state
		if result_signal != node.tree_exited:
			tree_exit_callback = make_signal_resume_callable(node.tree_exited, on_resume)
			var _tree_exit_connect_result: int = node.tree_exited.connect(
				tree_exit_callback,
				CONNECT_ONE_SHOT as Object.ConnectFlags
			)
			tree_exit_signal = node.tree_exited

	if is_instance_valid(guard_node) and result_signal != guard_node.tree_exited and tree_exit_signal != guard_node.tree_exited:
		if not guard_node.is_inside_tree():
			disconnect_signal_if_connected(result_signal, result_callback)
			disconnect_signal_if_connected(tree_exit_signal, tree_exit_callback)
			return completion_state
		guard_exit_callback = make_signal_resume_callable(guard_node.tree_exited, on_resume)
		var _guard_exit_connect_result: int = guard_node.tree_exited.connect(
			guard_exit_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)
		guard_exit_signal = guard_node.tree_exited

	var timeout_msec: float = maxf(timeout_seconds, 0.0) * 1000.0
	var elapsed_timeout_msec: float = 0.0
	var last_timeout_msec: int = Time.get_ticks_msec()
	var timed_out: bool = false
	var tree: SceneTree = _variant_to_scene_tree(Engine.get_main_loop())

	while not GFVariantData.get_option_bool(completion_state, "completed"):
		if tree == null:
			break

		var current_timeout_msec: int = Time.get_ticks_msec()
		if timeout_msec > 0.0:
			elapsed_timeout_msec += get_timeout_elapsed_msec(
				last_timeout_msec,
				current_timeout_msec,
				time_utility,
				respect_time_scale
			)
			if elapsed_timeout_msec >= timeout_msec:
				timed_out = true
				break
		last_timeout_msec = current_timeout_msec

		if should_continue.is_valid() and not GFVariantData.to_bool(should_continue.call()):
			break
		if not is_instance_valid(target_obj):
			break
		var target_node: Node = _variant_to_node(target_obj)
		if target_node != null and not target_node.is_inside_tree():
			break
		if guard_node != null and (not is_instance_valid(guard_node) or not guard_node.is_inside_tree()):
			break
		await tree.process_frame

	disconnect_signal_if_connected(result_signal, result_callback)
	disconnect_signal_if_connected(tree_exit_signal, tree_exit_callback)
	disconnect_signal_if_connected(guard_exit_signal, guard_exit_callback)

	if timed_out and not timeout_warning.is_empty():
		push_warning(timeout_warning)
	return completion_state


static func _make_signal_capture_callable(target_signal: Signal, completion_state: Dictionary) -> Callable:
	var argument_count: int = get_signal_argument_count(target_signal)
	if argument_count > MAX_CAPTURED_SIGNAL_ARGUMENTS:
		push_warning("[GFAsyncWaitSupport] 信号 payload 当前最多捕获 %d 个参数。" % MAX_CAPTURED_SIGNAL_ARGUMENTS)
		return make_signal_resume_callable(target_signal, func() -> void:
			completion_state["completed"] = true
			completion_state["args"] = []
		)

	return func(
		arg1: Variant = null,
		arg2: Variant = null,
		arg3: Variant = null,
		arg4: Variant = null,
		arg5: Variant = null,
		arg6: Variant = null,
		arg7: Variant = null,
		arg8: Variant = null,
		arg9: Variant = null,
		arg10: Variant = null,
		arg11: Variant = null,
		arg12: Variant = null,
		arg13: Variant = null,
		arg14: Variant = null,
		arg15: Variant = null,
		arg16: Variant = null
	) -> void:
		var raw_args: Array = [
			arg1,
			arg2,
			arg3,
			arg4,
			arg5,
			arg6,
			arg7,
			arg8,
			arg9,
			arg10,
			arg11,
			arg12,
			arg13,
			arg14,
			arg15,
			arg16,
		]
		completion_state["completed"] = true
		completion_state["args"] = raw_args.slice(0, mini(argument_count, raw_args.size()))


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _variant_to_scene_tree(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null
