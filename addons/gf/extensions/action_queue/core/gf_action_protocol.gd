extends RefCounted


# --- 常量 ---

const _COMPLETION_MODE_FIRE_AND_FORGET: int = 2
const _DEFAULT_SIGNAL_TIMEOUT_SECONDS: float = 30.0
const _DEFAULT_SIGNAL_TIMEOUT_RESPECTS_TIME_SCALE: bool = true
const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")
const _ACTION_TIME_POLICY = preload("res://addons/gf/extensions/action_queue/core/gf_action_time_policy.gd")


# --- 层内方法 ---

## 判断对象是否符合动作队列所需的最小协议。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 待检查的动作对象。
## [br]
## @return 符合协议时返回 true。
static func is_action_valid(action: Object) -> bool:
	return is_instance_valid(action) and action.has_method("execute")


## 注入当前动作执行所在的架构。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
## [br]
## @param architecture: 当前架构。
static func inject_dependencies(action: Object, architecture: GFArchitecture) -> void:
	if is_action_valid(action) and action.has_method("inject_dependencies"):
		action.call("inject_dependencies", architecture)


## 判断动作是否可以执行。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
## [br]
## @return 可以执行返回 true。
static func can_execute(action: Object) -> bool:
	if not is_action_valid(action):
		return false
	if action.has_method("can_execute"):
		return GFVariantData.to_bool(action.call("can_execute"))
	if action.has_method("is_valid"):
		return GFVariantData.to_bool(action.call("is_valid"))
	return true


## 执行动作对象。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
## [br]
## @return execute() 返回值。
## [br]
## @schema return: Variant，由动作 execute() 返回，可能是 Signal、null 或项目自定义值。
static func execute(action: Object) -> Variant:
	if not is_action_valid(action):
		return null
	return action.call("execute")


## 将动作切换为发出即走模式。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
static func set_fire_and_forget(action: Object) -> void:
	if is_instance_valid(action) and _has_property(action, "completion_mode"):
		action.set("completion_mode", _COMPLETION_MODE_FIRE_AND_FORGET)


## 请求取消动作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
static func cancel(action: Object) -> void:
	_call_optional(action, "cancel")


## 请求暂停动作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
static func pause(action: Object) -> void:
	_call_optional(action, "pause")


## 请求恢复动作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
static func resume(action: Object) -> void:
	_call_optional(action, "resume")


## 请求立即完成动作。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
static func finish(action: Object) -> void:
	if is_instance_valid(action) and action.has_method("finish"):
		action.call("finish")
	else:
		cancel(action)


## 判断动作执行结果是否需要等待。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
## [br]
## @param result: execute() 返回值。
## [br]
## @return 需要等待返回 true。
## [br]
## @schema result: Variant，由动作 execute() 返回，可能是 Signal、null 或项目自定义值。
static func should_wait_for_result(action: Object, result: Variant) -> bool:
	if not is_action_valid(action):
		return false
	if action.has_method("should_wait_for_result"):
		return GFVariantData.to_bool(action.call("should_wait_for_result", result))
	if (
		_has_property(action, "completion_mode")
		and GFVariantData.to_int(GFObjectPropertyTools.read_property(action, ^"completion_mode")) == _COMPLETION_MODE_FIRE_AND_FORGET
	):
		return false
	return result is Signal


## 安全等待动作返回的 Signal。
## [br]
## @api layer_internal
## [br]
## @layer extensions/action_queue
## [br]
## @param action: 动作对象。
## [br]
## @param result: execute() 返回值。
## [br]
## @param should_continue: 可选取消检查回调；返回 false 时停止等待。
## [br]
## @param should_pause_timeout: 可选超时暂停检查；返回 true 时暂停 timeout 计时。
## [br]
## @param architecture: 当前架构，用于读取时间缩放工具。
## [br]
## @schema result: Variant，由动作 execute() 返回，等待时必须是 Signal。
static func await_result_safely(
	action: Object,
	result: Variant,
	should_continue: Callable = Callable(),
	should_pause_timeout: Callable = Callable(),
	architecture: GFArchitecture = null
) -> void:
	if not should_wait_for_result(action, result):
		return

	var signal_result: Signal = result
	await _GF_ASYNC_WAIT_SUPPORT.await_signal_safely(
		signal_result,
		should_continue,
		_get_time_utility(architecture),
		_get_signal_timeout_seconds(action),
		_get_signal_timeout_respects_time_scale(action),
		"[GFActionQueueSystem] 等待动作 Signal 超时，队列将继续执行后续动作。",
		_get_wait_guard_node(action),
		should_pause_timeout
	)


# --- 私有/辅助方法 ---

static func _call_optional(action: Object, method_name: StringName) -> void:
	if is_instance_valid(action) and action.has_method(method_name):
		action.call(method_name)


static func _has_property(action: Object, property_name: StringName) -> bool:
	if not is_instance_valid(action):
		return false
	for property_info: Dictionary in action.get_property_list():
		if GFVariantData.get_option_string_name(property_info, "name") == property_name:
			return true
	return false


static func _get_wait_guard_node(action: Object) -> Node:
	if is_instance_valid(action) and action.has_method("get_wait_guard_node"):
		return _get_node_value(action.call("get_wait_guard_node"))
	return null


static func _get_signal_timeout_seconds(action: Object) -> float:
	if _has_property(action, "signal_timeout_seconds"):
		return _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
			GFVariantData.to_float(
				GFObjectPropertyTools.read_property(action, ^"signal_timeout_seconds")
			),
			_DEFAULT_SIGNAL_TIMEOUT_SECONDS
		)
	return _DEFAULT_SIGNAL_TIMEOUT_SECONDS


static func _get_signal_timeout_respects_time_scale(action: Object) -> bool:
	if _has_property(action, "signal_timeout_respects_time_scale"):
		return GFVariantData.to_bool(
			GFObjectPropertyTools.read_property(action, ^"signal_timeout_respects_time_scale"),
			_DEFAULT_SIGNAL_TIMEOUT_RESPECTS_TIME_SCALE
		)
	return _DEFAULT_SIGNAL_TIMEOUT_RESPECTS_TIME_SCALE


static func _get_time_utility(architecture: GFArchitecture) -> GFTimeUtility:
	if architecture == null:
		architecture = GFAutoload.get_architecture_or_null()
	if architecture == null:
		return null
	return _get_time_utility_value(architecture.get_utility(GFTimeUtility))


static func _get_node_value(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _get_time_utility_value(value: Variant) -> GFTimeUtility:
	if value is GFTimeUtility:
		var utility: GFTimeUtility = value
		return utility
	return null
