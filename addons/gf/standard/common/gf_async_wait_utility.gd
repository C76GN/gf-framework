## GFAsyncWaitUtility: 公共 Signal 等待辅助。
##
## 提供带超时、取消 token、生命周期保护和 payload 捕获的 Signal、帧、延迟和条件等待入口。
## 它只负责等待状态，不创建业务任务，也不替代项目自己的流程编排。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFAsyncWaitUtility
extends RefCounted


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")
const _GF_ASYNC_RESULT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_result_support.gd")

## 等待正常由目标 Signal 完成。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_COMPLETED: StringName = &"completed"

## 等待被取消 token 结束。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_CANCELLED: StringName = &"cancelled"

## 等待因超时结束。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_TIMEOUT: StringName = &"timeout"

## 等待因目标或保护节点失效结束。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVALID: StringName = &"invalid"


# --- 公共方法 ---

## 等待 Signal 发出，不捕获参数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param result_signal: 要等待的 Signal。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale、process_in_physics 和 timeout_warning。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func await_signal(result_signal: Signal, options: Dictionary = {}) -> Dictionary:
	return await _await_signal_state(result_signal, options, false)


## 等待 Signal 发出，并捕获最多 16 个参数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param result_signal: 要等待的 Signal。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale、process_in_physics 和 timeout_warning。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func await_signal_payload(result_signal: Signal, options: Dictionary = {}) -> Dictionary:
	return await _await_signal_state(result_signal, options, true)


## 等待下一帧 process_frame。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility 和 respect_time_scale。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func next_frame(options: Dictionary = {}) -> Dictionary:
	return await _wait_single_frame(false, options)


## 等待下一帧 physics_frame。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility 和 respect_time_scale。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func physics_frame(options: Dictionary = {}) -> Dictionary:
	return await _wait_single_frame(true, options)


## 等待指定秒数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param seconds: 等待秒数；小于等于 0 时立即完成。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func delay_seconds(seconds: float, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _make_wait_state(options)
	var immediate_status: StringName = _get_common_wait_status(state)
	if immediate_status != &"":
		return _make_status_result(immediate_status, state)
	if seconds <= 0.0:
		return _make_result(STATUS_COMPLETED)

	var delay_msec: float = maxf(seconds, 0.0) * 1000.0
	var elapsed_delay_msec: float = 0.0
	var last_delay_msec: int = Time.get_ticks_msec()

	while elapsed_delay_msec < delay_msec:
		var status: StringName = _get_common_wait_status(state)
		if status != &"":
			return _make_status_result(status, state)

		var current_delay_msec: int = Time.get_ticks_msec()
		elapsed_delay_msec += _GF_ASYNC_WAIT_SUPPORT.get_timeout_elapsed_msec(
			last_delay_msec,
			current_delay_msec,
			_state_to_time_utility(state),
			GFVariantData.get_option_bool(state, "respect_time_scale", true)
		)
		last_delay_msec = current_delay_msec
		if elapsed_delay_msec >= delay_msec:
			break

		var tree: SceneTree = _state_to_scene_tree(state)
		await _await_frame(tree, GFVariantData.get_option_bool(state, "process_in_physics"))

	return _make_result(STATUS_COMPLETED)


## 等待 predicate 返回 true。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param predicate: 无参判断回调；返回值会收窄为 bool。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func wait_until(predicate: Callable, options: Dictionary = {}) -> Dictionary:
	if not predicate.is_valid():
		return _make_result(STATUS_INVALID)
	return await _wait_predicate(predicate, true, options)


## 等待 predicate 返回 false。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param predicate: 无参判断回调；返回值会收窄为 bool。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata 和 args。
static func wait_while(predicate: Callable, options: Dictionary = {}) -> Dictionary:
	if not predicate.is_valid():
		return _make_result(STATUS_INVALID)
	return await _wait_predicate(predicate, false, options)


## 等待 getter 返回值发生变化。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param getter: 无参取值回调。
## [br]
## @param options: 等待选项。
## [br]
## @return 等待结果；完成时包含 previous_value 和 value。
## [br]
## @schema options: Dictionary，可包含 timeout_seconds、cancel_token、guard_node、tree、time_utility、respect_time_scale 和 process_in_physics。
## [br]
## @schema return: Dictionary，包含 status、completed、cancelled、timed_out、invalid、reason、metadata、args、previous_value 和 value。
static func wait_until_value_changed(getter: Callable, options: Dictionary = {}) -> Dictionary:
	if not getter.is_valid():
		return _make_result(STATUS_INVALID)

	var state: Dictionary = _make_wait_state(options)
	var immediate_status: StringName = _get_common_wait_status(state)
	if immediate_status != &"":
		return _make_status_result(immediate_status, state)

	var previous_value: Variant = GFVariantData.duplicate_variant(getter.call())

	while true:
		var status: StringName = _get_common_wait_status(state)
		if status != &"":
			return _make_status_result(status, state)

		var current_value: Variant = getter.call()
		if not _values_equal(previous_value, current_value):
			return _make_result(
				STATUS_COMPLETED,
				[],
				&"",
				{},
				{
					"previous_value": GFVariantData.duplicate_variant(previous_value),
					"value": GFVariantData.duplicate_variant(current_value),
				}
			)

		var tree: SceneTree = _state_to_scene_tree(state)
		await _await_frame(tree, GFVariantData.get_option_bool(state, "process_in_physics"))
	return _make_result(STATUS_INVALID)


# --- 私有/辅助方法 ---

static func _wait_single_frame(use_physics_frame: bool, options: Dictionary) -> Dictionary:
	var frame_options: Dictionary = options.duplicate(true)
	frame_options["process_in_physics"] = use_physics_frame
	var state: Dictionary = _make_wait_state(frame_options)
	var status: StringName = _get_common_wait_status(state)
	if status != &"":
		return _make_status_result(status, state)

	var tree: SceneTree = _state_to_scene_tree(state)
	await _await_frame(tree, use_physics_frame)

	status = _get_common_wait_status(state)
	if status != &"":
		return _make_status_result(status, state)
	return _make_result(STATUS_COMPLETED)


static func _wait_predicate(predicate: Callable, desired_value: bool, options: Dictionary) -> Dictionary:
	var state: Dictionary = _make_wait_state(options)
	while true:
		var status: StringName = _get_common_wait_status(state)
		if status != &"":
			return _make_status_result(status, state)

		if GFVariantData.to_bool(predicate.call()) == desired_value:
			return _make_result(STATUS_COMPLETED)

		var tree: SceneTree = _state_to_scene_tree(state)
		await _await_frame(tree, GFVariantData.get_option_bool(state, "process_in_physics"))
	return _make_result(STATUS_INVALID)


static func _make_wait_state(options: Dictionary) -> Dictionary:
	var timeout_seconds: float = GFVariantData.get_option_float(options, "timeout_seconds", 0.0)
	return {
		"tree": _get_scene_tree(options),
		"cancel_token": _get_cancel_token(options),
		"guard_node": _get_guard_node(options),
		"time_utility": _get_time_utility(options),
		"respect_time_scale": GFVariantData.get_option_bool(options, "respect_time_scale", true),
		"process_in_physics": GFVariantData.get_option_bool(options, "process_in_physics", false),
		"timeout_msec": maxf(timeout_seconds, 0.0) * 1000.0,
		"elapsed_timeout_msec": 0.0,
		"last_timeout_msec": Time.get_ticks_msec(),
	}


static func _get_common_wait_status(state: Dictionary) -> StringName:
	var tree: SceneTree = _state_to_scene_tree(state)
	if tree == null:
		return STATUS_INVALID

	var cancel_token: GFCancelToken = _state_to_cancel_token(state)
	if cancel_token != null and cancel_token.is_cancelled():
		return STATUS_CANCELLED

	var guard_node: Node = _state_to_guard_node(state)
	if guard_node != null and (not is_instance_valid(guard_node) or not guard_node.is_inside_tree()):
		return STATUS_INVALID

	var timeout_msec: float = GFVariantData.get_option_float(state, "timeout_msec", 0.0)
	if timeout_msec <= 0.0:
		return &""

	var last_timeout_msec: int = GFVariantData.get_option_int(state, "last_timeout_msec", Time.get_ticks_msec())
	var current_timeout_msec: int = Time.get_ticks_msec()
	var elapsed_timeout_msec: float = GFVariantData.get_option_float(state, "elapsed_timeout_msec", 0.0)
	elapsed_timeout_msec += _GF_ASYNC_WAIT_SUPPORT.get_timeout_elapsed_msec(
		last_timeout_msec,
		current_timeout_msec,
		_state_to_time_utility(state),
		GFVariantData.get_option_bool(state, "respect_time_scale", true)
	)
	state["elapsed_timeout_msec"] = elapsed_timeout_msec
	state["last_timeout_msec"] = current_timeout_msec
	if elapsed_timeout_msec >= timeout_msec:
		return STATUS_TIMEOUT
	return &""


static func _make_status_result(status: StringName, state: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var cancel_token: GFCancelToken = _state_to_cancel_token(state)
	if status == STATUS_CANCELLED and cancel_token != null:
		return _make_result(status, [], cancel_token.get_reason(), cancel_token.get_metadata(), extra)
	return _make_result(status, [], &"", {}, extra)


static func _await_signal_state(result_signal: Signal, options: Dictionary, capture_payload: bool) -> Dictionary:
	var signal_options: Dictionary = options.duplicate(true)
	signal_options["capture_payload"] = capture_payload
	var wait_state: Dictionary = await _GF_ASYNC_WAIT_SUPPORT.await_signal_state(result_signal, signal_options)
	var status: StringName = GFVariantData.get_option_string_name(wait_state, "status", STATUS_INVALID)
	return _make_result(
		status,
		GFVariantData.get_option_array(wait_state, "args"),
		GFVariantData.get_option_string_name(wait_state, "reason"),
		GFVariantData.get_option_dictionary(wait_state, "metadata")
	)


static func _make_result(
	status: StringName,
	args: Array = [],
	reason: StringName = &"",
	metadata: Dictionary = {},
	extra: Dictionary = {}
) -> Dictionary:
	return _GF_ASYNC_RESULT_SUPPORT.make_wait_result(
		status,
		status == STATUS_COMPLETED,
		status == STATUS_CANCELLED,
		status == STATUS_TIMEOUT,
		status == STATUS_INVALID,
		args,
		reason,
		metadata,
		extra
	)


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
	return _get_main_scene_tree()


static func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _state_to_scene_tree(state: Dictionary) -> SceneTree:
	var value: Variant = GFVariantData.get_option_value(state, "tree")
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null


static func _state_to_cancel_token(state: Dictionary) -> GFCancelToken:
	var value: Variant = GFVariantData.get_option_value(state, "cancel_token")
	if value is GFCancelToken:
		var token: GFCancelToken = value
		return token
	return null


static func _state_to_guard_node(state: Dictionary) -> Node:
	return _variant_to_node(GFVariantData.get_option_value(state, "guard_node"))


static func _state_to_time_utility(state: Dictionary) -> GFTimeUtility:
	var value: Variant = GFVariantData.get_option_value(state, "time_utility")
	if value is GFTimeUtility:
		var time_utility: GFTimeUtility = value
		return time_utility
	return null


static func _await_frame(tree: SceneTree, use_physics_frame: bool) -> void:
	if use_physics_frame:
		await tree.physics_frame
		return
	await tree.process_frame


static func _values_equal(left: Variant, right: Variant) -> bool:
	if left == null and right == null:
		return true
	if typeof(left) != typeof(right):
		return false
	if left is float:
		var left_float: float = left
		var right_float: float = right
		return is_equal_approx(left_float, right_float)
	if left is Vector2:
		var left_v2: Vector2 = left
		var right_v2: Vector2 = right
		return left_v2.is_equal_approx(right_v2)
	if left is Vector3:
		var left_v3: Vector3 = left
		var right_v3: Vector3 = right
		return left_v3.is_equal_approx(right_v3)
	if left is Color:
		var left_color: Color = left
		var right_color: Color = right
		return (
			is_equal_approx(left_color.r, right_color.r)
			and is_equal_approx(left_color.g, right_color.g)
			and is_equal_approx(left_color.b, right_color.b)
			and is_equal_approx(left_color.a, right_color.a)
		)
	return left == right
