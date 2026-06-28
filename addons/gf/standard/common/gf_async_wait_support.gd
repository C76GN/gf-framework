# GFAsyncWaitSupport: 内部异步等待辅助。
#
# 提供 Signal 安全断开、payload 捕获、生命周期保护和受 GFTimeUtility 影响的超时增量计算，
# 供流程、序列和动作队列复用。
extends RefCounted


# --- 常量 ---

## 单次等待最多捕获的 Signal 参数数量。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const MAX_CAPTURED_SIGNAL_ARGUMENTS: int = 16

## 等待正常由目标 Signal 完成。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const STATUS_COMPLETED: StringName = &"completed"

## 等待被取消或继续条件终止。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const STATUS_CANCELLED: StringName = &"cancelled"

## 等待因超时结束。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const STATUS_TIMEOUT: StringName = &"timeout"

## 等待因目标、树或保护节点失效结束。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
const STATUS_INVALID: StringName = &"invalid"


# --- 公共方法 ---

## 安全等待 Signal，并返回完整等待状态。
## [br]
## @api framework_internal
## [br]
## @layer standard/common
## [br]
## @param result_signal: 要等待的 Signal。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待状态。
## [br]
## @schema options: Dictionary，可包含 should_continue、should_pause_timeout、time_utility、timeout_seconds、respect_time_scale、timeout_warning、guard_node、tree、process_in_physics、cancel_token 和 capture_payload。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func await_signal_state(result_signal: Signal, options: Dictionary = {}) -> Dictionary:
	if result_signal.is_null():
		return _make_signal_wait_result(STATUS_INVALID, [], &"invalid_signal")

	var target_obj: Object = result_signal.get_object()
	if not is_instance_valid(target_obj):
		return _make_signal_wait_result(STATUS_INVALID, [], &"target_invalid")

	var cancel_token: GFCancelToken = _get_cancel_token(options)
	if cancel_token != null and cancel_token.is_cancelled():
		return _make_signal_wait_result(
			STATUS_CANCELLED,
			[],
			cancel_token.get_reason(),
			cancel_token.get_metadata()
		)

	var completion_state: Dictionary = {
		"completed": false,
		"status": STATUS_COMPLETED,
		"reason": &"",
		"metadata": {},
		"args": [],
	}
	var on_signal_completed: Callable = func() -> void:
		completion_state["completed"] = true
		completion_state["status"] = STATUS_COMPLETED
	var on_target_exited: Callable = func() -> void:
		completion_state["completed"] = true
		completion_state["status"] = STATUS_INVALID
		completion_state["reason"] = &"target_exited"
	var on_guard_exited: Callable = func() -> void:
		completion_state["completed"] = true
		completion_state["status"] = STATUS_INVALID
		completion_state["reason"] = &"guard_exited"
	var capture_payload: bool = GFVariantData.get_option_bool(options, "capture_payload", false)
	var result_callback: Callable = (
		_make_signal_capture_callable(result_signal, completion_state)
		if capture_payload
		else make_signal_resume_callable(result_signal, on_signal_completed)
	)
	var tree_exit_callback: Callable = on_target_exited
	var guard_exit_callback: Callable = on_guard_exited

	var result_connect_result: Error = result_signal.connect(
		result_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if result_connect_result != OK:
		return _make_signal_wait_result(STATUS_INVALID, [], &"connect_failed")

	var tree_exit_signal: Signal = Signal()
	var guard_exit_signal: Signal = Signal()
	if target_obj is Node:
		var target_node: Node = _variant_to_node(target_obj)
		if target_node == null:
			disconnect_signal_if_connected(result_signal, result_callback)
			return _make_signal_wait_result(STATUS_INVALID, [], &"target_invalid")
		if not target_node.is_inside_tree() and result_signal != target_node.tree_exited:
			disconnect_signal_if_connected(result_signal, result_callback)
			return _make_signal_wait_result(STATUS_INVALID, [], &"target_exited")
		if result_signal != target_node.tree_exited:
			tree_exit_callback = make_signal_resume_callable(target_node.tree_exited, on_target_exited)
			var tree_exit_connect_result: Error = target_node.tree_exited.connect(
				tree_exit_callback,
				CONNECT_ONE_SHOT as Object.ConnectFlags
			) as Error
			if tree_exit_connect_result != OK:
				disconnect_signal_if_connected(result_signal, result_callback)
				return _make_signal_wait_result(STATUS_INVALID, [], &"connect_failed")
			tree_exit_signal = target_node.tree_exited

	var guard_node: Node = _get_guard_node(options)
	if guard_node != null and result_signal != guard_node.tree_exited and tree_exit_signal != guard_node.tree_exited:
		if not guard_node.is_inside_tree():
			disconnect_signal_if_connected(result_signal, result_callback)
			disconnect_signal_if_connected(tree_exit_signal, tree_exit_callback)
			return _make_signal_wait_result(STATUS_INVALID, [], &"guard_exited")
		guard_exit_callback = make_signal_resume_callable(guard_node.tree_exited, on_guard_exited)
		var guard_exit_connect_result: Error = guard_node.tree_exited.connect(
			guard_exit_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		if guard_exit_connect_result != OK:
			disconnect_signal_if_connected(result_signal, result_callback)
			disconnect_signal_if_connected(tree_exit_signal, tree_exit_callback)
			return _make_signal_wait_result(STATUS_INVALID, [], &"connect_failed")
		guard_exit_signal = guard_node.tree_exited

	var status: StringName = await _wait_signal_loop(
		result_signal,
		target_obj,
		guard_node,
		cancel_token,
		completion_state,
		options
	)

	disconnect_signal_if_connected(result_signal, result_callback)
	disconnect_signal_if_connected(tree_exit_signal, tree_exit_callback)
	disconnect_signal_if_connected(guard_exit_signal, guard_exit_callback)

	if status == STATUS_TIMEOUT:
		var timeout_warning: String = GFVariantData.get_option_string(options, "timeout_warning")
		if not timeout_warning.is_empty():
			push_warning(timeout_warning)

	var args: Array = GFVariantData.as_array(GFVariantData.get_option_value(completion_state, "args", []))
	if status == STATUS_CANCELLED and cancel_token != null:
		return _make_signal_wait_result(status, args, cancel_token.get_reason(), cancel_token.get_metadata())
	return _make_signal_wait_result(
		status,
		args,
		GFVariantData.get_option_string_name(completion_state, "reason"),
		GFVariantData.get_option_dictionary(completion_state, "metadata")
	)


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
## @param should_pause_timeout: 可选超时暂停检查；返回 true 时本帧不累计 timeout。
## [br]
## @return Signal 正常发出时返回 true。
static func await_signal_safely(
	result_signal: Signal,
	should_continue: Callable = Callable(),
	time_utility: GFTimeUtility = null,
	timeout_seconds: float = 30.0,
	respect_time_scale: bool = true,
	timeout_warning: String = "",
	guard_node: Node = null,
	should_pause_timeout: Callable = Callable()
) -> bool:
	var result: Dictionary = await await_signal_state(result_signal, {
		"should_continue": should_continue,
		"should_pause_timeout": should_pause_timeout,
		"time_utility": time_utility,
		"timeout_seconds": timeout_seconds,
		"respect_time_scale": respect_time_scale,
		"timeout_warning": timeout_warning,
		"guard_node": guard_node,
	})
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
## @param should_pause_timeout: 可选超时暂停检查；返回 true 时本帧不累计 timeout。
## [br]
## @return 包含 completed、status、reason、metadata 与 args 的等待结果。
## [br]
## @schema return: Dictionary with completed: bool, status: StringName, reason: StringName, metadata: Dictionary and args: Array.
static func await_signal_payload_safely(
	result_signal: Signal,
	should_continue: Callable = Callable(),
	time_utility: GFTimeUtility = null,
	timeout_seconds: float = 30.0,
	respect_time_scale: bool = true,
	timeout_warning: String = "",
	guard_node: Node = null,
	should_pause_timeout: Callable = Callable()
) -> Dictionary:
	return await await_signal_state(result_signal, {
		"should_continue": should_continue,
		"should_pause_timeout": should_pause_timeout,
		"time_utility": time_utility,
		"timeout_seconds": timeout_seconds,
		"respect_time_scale": respect_time_scale,
		"timeout_warning": timeout_warning,
		"guard_node": guard_node,
		"capture_payload": true,
	})


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

static func _wait_signal_loop(
	result_signal: Signal,
	target_obj: Object,
	guard_node: Node,
	cancel_token: GFCancelToken,
	completion_state: Dictionary,
	options: Dictionary
) -> StringName:
	var timeout_seconds: float = GFVariantData.get_option_float(options, "timeout_seconds", 0.0)
	var timeout_msec: float = maxf(timeout_seconds, 0.0) * 1000.0
	var elapsed_timeout_msec: float = 0.0
	var last_timeout_msec: int = Time.get_ticks_msec()
	var time_utility: GFTimeUtility = _get_time_utility(options)
	var respect_time_scale: bool = GFVariantData.get_option_bool(options, "respect_time_scale", true)
	var tree: SceneTree = _get_scene_tree(options)
	var process_in_physics: bool = GFVariantData.get_option_bool(options, "process_in_physics", false)
	var should_continue: Callable = _get_callable(options, "should_continue")
	var should_pause_timeout: Callable = _get_callable(options, "should_pause_timeout")

	while not GFVariantData.get_option_bool(completion_state, "completed"):
		if tree == null:
			return STATUS_INVALID
		if cancel_token != null and cancel_token.is_cancelled():
			return STATUS_CANCELLED
		if not is_instance_valid(target_obj):
			completion_state["reason"] = &"target_exited"
			return STATUS_INVALID
		var target_node: Node = _variant_to_node(target_obj)
		if target_node != null and not target_node.is_inside_tree() and result_signal != target_node.tree_exited:
			completion_state["reason"] = &"target_exited"
			return STATUS_INVALID
		if guard_node != null and (not is_instance_valid(guard_node) or not guard_node.is_inside_tree()):
			completion_state["reason"] = &"guard_exited"
			return STATUS_INVALID

		var current_timeout_msec: int = Time.get_ticks_msec()
		if timeout_msec > 0.0:
			var timeout_is_paused: bool = (
				should_pause_timeout.is_valid()
				and GFVariantData.to_bool(should_pause_timeout.call())
			)
			if not timeout_is_paused:
				elapsed_timeout_msec += get_timeout_elapsed_msec(
					last_timeout_msec,
					current_timeout_msec,
					time_utility,
					respect_time_scale
				)
				if elapsed_timeout_msec >= timeout_msec:
					return STATUS_TIMEOUT
		last_timeout_msec = current_timeout_msec

		if should_continue.is_valid() and not GFVariantData.to_bool(should_continue.call()):
			completion_state["reason"] = &"should_continue_false"
			return STATUS_CANCELLED

		await _await_frame(tree, process_in_physics)

	return GFVariantData.get_option_string_name(completion_state, "status", STATUS_COMPLETED)


static func _make_signal_capture_callable(target_signal: Signal, completion_state: Dictionary) -> Callable:
	var argument_count: int = get_signal_argument_count(target_signal)
	var captured_argument_count: int = mini(argument_count, MAX_CAPTURED_SIGNAL_ARGUMENTS)
	if argument_count > MAX_CAPTURED_SIGNAL_ARGUMENTS:
		push_warning("[GFAsyncWaitSupport] 信号 payload 当前最多捕获 %d 个参数。" % MAX_CAPTURED_SIGNAL_ARGUMENTS)

	var capture_callback: Callable = func(
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
		completion_state["status"] = STATUS_COMPLETED
		completion_state["args"] = raw_args.slice(0, captured_argument_count)

	if argument_count > MAX_CAPTURED_SIGNAL_ARGUMENTS:
		return capture_callback.unbind(argument_count - MAX_CAPTURED_SIGNAL_ARGUMENTS)
	return capture_callback


static func _make_signal_wait_result(
	status: StringName,
	args: Array = [],
	reason: StringName = &"",
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"status": status,
		"completed": status == STATUS_COMPLETED,
		"cancelled": status == STATUS_CANCELLED,
		"timed_out": status == STATUS_TIMEOUT,
		"invalid": status == STATUS_INVALID,
		"reason": reason,
		"metadata": metadata.duplicate(true),
		"args": args.duplicate(true),
	}


static func _get_callable(options: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


static func _get_cancel_token(options: Dictionary) -> GFCancelToken:
	var value: Variant = GFVariantData.get_option_value(options, "cancel_token")
	if value is GFCancelToken:
		var token: GFCancelToken = value
		return token
	return null


static func _get_guard_node(options: Dictionary) -> Node:
	return _variant_to_node(GFVariantData.get_option_value(options, "guard_node"))


static func _get_time_utility(options: Dictionary) -> GFTimeUtility:
	var value: Variant = GFVariantData.get_option_value(options, "time_utility")
	if value is GFTimeUtility:
		var time_utility: GFTimeUtility = value
		return time_utility
	return null


static func _get_scene_tree(options: Dictionary) -> SceneTree:
	var value: Variant = GFVariantData.get_option_value(options, "tree")
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return _variant_to_scene_tree(Engine.get_main_loop())


static func _await_frame(tree: SceneTree, use_physics_frame: bool) -> void:
	if use_physics_frame:
		await tree.physics_frame
		return
	await tree.process_frame


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
