## GFVirtualInputSource: 可编程虚拟输入源。
##
## 用于测试、回放、AI 控制或项目自定义输入桥接，向 GFInputMappingUtility
## 注入抽象动作值；它不读取 InputMap，也不规定具体设备或玩法语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFVirtualInputSource
extends RefCounted


# --- 枚举 ---

## 同一 source_id、player_index 与 action_id 已存在脉冲时的处理策略。
## [br]
## @api public
## [br]
## @since unreleased
enum PulseReplacementPolicy {
	## 原子交接同一动作贡献，不产生中间释放。
	REPLACE,
	## 保留旧脉冲，并让新句柄立即进入 REJECTED 终态。
	REJECT_NEW,
}


# --- 公共变量 ---

## 虚拟输入源标识。
## [br]
## @api public
var source_id: StringName = &"virtual"

## 玩家索引；小于 0 时只写入全局动作状态。
## [br]
## @api public
var player_index: int = -1


# --- 私有变量 ---

var _input_mapping_ref: WeakRef = null
var _timer_utility_ref: WeakRef = null
var _active_pulses: Dictionary = {}
var _next_pulse_generation: int = 1
var _disposed: bool = false


# --- Godot 生命周期方法 ---

func _init(
	input_mapping: GFInputMappingUtility = null,
	p_source_id: StringName = &"virtual",
	p_player_index: int = -1,
	timer_utility: GFTimerUtility = null
) -> void:
	var _configure_result: GFVirtualInputSource = configure(
		input_mapping,
		p_source_id,
		p_player_index,
		timer_utility
	)


# --- 公共方法 ---

## 配置虚拟输入源。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param input_mapping: 输入映射工具。
## [br]
## @param p_source_id: 虚拟输入源标识。
## [br]
## @param p_player_index: 玩家索引。
## [br]
## @param timer_utility: 可选的脉冲定时器注入。
## [br]
## @return: 当前输入源；dispose 后返回同一终态实例且不修改配置。
func configure(
	input_mapping: GFInputMappingUtility,
	p_source_id: StringName = &"virtual",
	p_player_index: int = -1,
	timer_utility: GFTimerUtility = null
) -> GFVirtualInputSource:
	if _disposed:
		return self
	if _input_mapping_ref != null:
		clear_all()
	_input_mapping_ref = weakref(input_mapping) if input_mapping != null else null
	_timer_utility_ref = weakref(timer_utility) if timer_utility != null else null
	source_id = p_source_id if p_source_id != &"" else &"virtual"
	player_index = p_player_index
	return self


## 替换后续脉冲使用的定时器工具。
## 已启动操作会继续使用其创建时冻结的定时器，不受本次替换影响。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param timer_utility: 可注入的定时器工具；null 会禁用后续 pulse_action()。
## [br]
## @return: 当前输入源；dispose 后返回同一终态实例且不修改配置。
func set_timer_utility(timer_utility: GFTimerUtility) -> GFVirtualInputSource:
	if _disposed:
		return self
	_timer_utility_ref = weakref(timer_utility) if timer_utility != null else null
	return self


## 获取后续脉冲使用的定时器工具。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前注入且仍存活的 GFTimerUtility。
func get_timer_utility() -> GFTimerUtility:
	return _get_timer_utility()


## 启动一次有界虚拟动作脉冲。
##
## owner 与 cancellation_token 均可省略；同时提供时采用 OR 语义。返回句柄冻结
## 当前 Mapping、source_id、player_index 和 action_id，Source 后续重配不会改写旧操作。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param action_id: 已注册的抽象动作标识。
## [br]
## @param value: 脉冲期间的动作值。
## [br]
## @param duration_seconds: 非负且有限的脉冲时长；0 会同步释放。
## [br]
## @param owner: 可选生命周期 owner；Node 离树或普通 Object 释放后取消。
## [br]
## @param cancellation_token: 可选取消 token。
## [br]
## @param replacement_policy: 同一稳定输入键已有脉冲时的策略。
## [br]
## @schema value: Variant，GFInputMappingUtility 接受的 bool、float、Vector2 或 Vector3 动作值。
## [br]
## @schema owner: Variant，null 或仍有效的 Object；无效及已释放对象会在写入前失败。
## [br]
## @return: 类型化脉冲句柄；输入无效时返回立即 FAILED 的句柄。
func pulse_action(
	action_id: StringName,
	value: Variant = true,
	duration_seconds: float = 0.1,
	owner: Variant = null,
	cancellation_token: GFCancellationToken = null,
	replacement_policy: PulseReplacementPolicy = PulseReplacementPolicy.REPLACE
) -> GFVirtualInputPulseOperation:
	var generation: int = _take_next_pulse_generation()
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	var frozen_source_id: StringName = source_id if source_id != &"" else &"virtual"
	var operation: GFVirtualInputPulseOperation = GFVirtualInputPulseOperation.new()
	_active_pulses[generation] = operation
	var owner_object: Object = null
	var owner_invalid: bool = false
	if typeof(owner) != TYPE_NIL:
		if not is_instance_valid(owner):
			owner_invalid = true
		elif owner is Object:
			owner_object = owner
		else:
			owner_invalid = true
	if owner_invalid:
		owner_object = self
	var token_for_configuration: GFCancellationToken = (
		null if owner_invalid else cancellation_token
	)
	var configured: bool = operation.configure_for_framework(
		input_mapping,
		self,
		generation,
		frozen_source_id,
		player_index,
		action_id,
		duration_seconds,
		owner_object,
		token_for_configuration
	)
	if not configured:
		var _removed_unconfigured: bool = _active_pulses.erase(generation)
		return operation
	if owner_invalid and operation.is_pending():
		var _failed_owner: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"invalid_owner_lifecycle"
		)
	if not operation.is_pending():
		return operation
	if _disposed:
		var _failed_disposed: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"source_disposed"
		)
		return operation
	if input_mapping == null:
		var _failed_mapping: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"mapping_unavailable"
		)
		return operation
	if action_id == &"":
		var _failed_action: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"invalid_action_id"
		)
		return operation
	if duration_seconds < 0.0 or is_nan(duration_seconds) or is_inf(duration_seconds):
		var _failed_duration: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"invalid_duration"
		)
		return operation
	if replacement_policy not in [PulseReplacementPolicy.REPLACE, PulseReplacementPolicy.REJECT_NEW]:
		var _failed_policy: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"invalid_replacement_policy"
		)
		return operation
	var timer_utility: GFTimerUtility = _get_timer_utility()
	if timer_utility == null:
		var _failed_timer: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"timer_unavailable"
		)
		return operation

	var lease_acquired: bool = input_mapping.begin_virtual_pulse_lease_for_framework(
		operation,
		value,
		replacement_policy
	)
	if not lease_acquired or not operation.is_pending():
		return operation
	if not operation.arm_timer_for_framework(timer_utility):
		var _failed_schedule: bool = input_mapping.finish_virtual_pulse_lease_for_framework(
			operation,
			GFVirtualInputPulseOperation.Status.FAILED,
			&"timer_schedule_failed"
		)
	return operation


## 写入动作值。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 动作值。
## [br]
## @schema value: Variant，GFInputMappingUtility 接受的动作值，通常为 bool、float、Vector2 或 Vector3。
## [br]
## @return 写入成功返回 true。
func set_action_value(action_id: StringName, value: Variant) -> bool:
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping == null:
		return false
	return GFVariantData.to_bool(input_mapping.call("set_virtual_action_value", action_id, value, source_id, player_index))


## 为指定玩家写入动作值。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 动作值。
## [br]
## @param next_player_index: 玩家索引。
## [br]
## @schema value: Variant，GFInputMappingUtility 接受的动作值，通常为 bool、float、Vector2 或 Vector3。
## [br]
## @return 写入成功返回 true。
func set_action_value_for_player(action_id: StringName, value: Variant, next_player_index: int) -> bool:
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping == null:
		return false
	return GFVariantData.to_bool(input_mapping.call("set_virtual_action_value", action_id, value, source_id, next_player_index))


## 按下布尔动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param strength: 输入强度。
## [br]
## @return 写入成功返回 true。
func press(action_id: StringName, strength: float = 1.0) -> bool:
	return set_action_value(action_id, maxf(strength, 0.0))


## 释放动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 写入成功返回 true。
func release(action_id: StringName) -> bool:
	return set_action_value(action_id, false)


## 写入一维轴动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 一维轴值。
## [br]
## @return 写入成功返回 true。
func set_axis_1d(action_id: StringName, value: float) -> bool:
	return set_action_value(action_id, value)


## 写入二维轴动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 二维轴值。
## [br]
## @return 写入成功返回 true。
func set_axis_2d(action_id: StringName, value: Vector2) -> bool:
	return set_action_value(action_id, value)


## 写入三维轴动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 三维轴值。
## [br]
## @return 写入成功返回 true。
func set_axis_3d(action_id: StringName, value: Vector3) -> bool:
	return set_action_value(action_id, value)


## 清除指定动作贡献。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 清除成功返回 true。
func clear_action(action_id: StringName) -> bool:
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping == null:
		return false
	return GFVariantData.to_bool(input_mapping.call("clear_virtual_action", action_id, source_id, player_index))


## 清除指定玩家的动作贡献。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param next_player_index: 玩家索引。
## [br]
## @return 清除成功返回 true。
func clear_action_for_player(action_id: StringName, next_player_index: int) -> bool:
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping == null:
		return false
	return GFVariantData.to_bool(input_mapping.call("clear_virtual_action", action_id, source_id, next_player_index))


## 清除当前虚拟源的所有动作贡献。
## [br]
## @api public
func clear_all() -> void:
	_cancel_active_pulses(&"source_cleared")
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping != null:
		input_mapping.call("clear_virtual_source", source_id)


## 取消全部 Source-owned 脉冲、清除当前 source_id 贡献并释放依赖引用。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_cancel_active_pulses(&"source_disposed")
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping != null:
		input_mapping.clear_virtual_source(source_id)
	_input_mapping_ref = null
	_timer_utility_ref = null


## 获取当前虚拟源快照。
## [br]
## @api public
## [br]
## @schema return: Dictionary，包含 source_id: StringName、player_index: int，以及当前虚拟输入贡献的 actions: Array[Dictionary]。
## [br]
## @return 快照字典。
func get_snapshot() -> Dictionary:
	var input_mapping: GFInputMappingUtility = _get_input_mapping()
	if input_mapping == null:
		return {
			"source_id": source_id,
			"player_index": player_index,
			"actions": [],
		}
	var snapshot: Variant = input_mapping.call("get_virtual_source_snapshot", source_id)
	return GFVariantData.to_dictionary(snapshot)


# --- 框架内部方法 ---

## 由 GFVirtualInputPulseOperation 在首次终态后移除 Source 强引用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @layer standard/input
## [br]
## @param generation: 操作创建时的 Source generation。
## [br]
## @param operation: 已完成操作。
func notify_pulse_operation_completed_for_framework(
	generation: int,
	operation: GFVirtualInputPulseOperation
) -> void:
	var current: GFVirtualInputPulseOperation = _get_pulse_operation(generation)
	if current == operation:
		var _removed: bool = _active_pulses.erase(generation)


# --- 私有/辅助方法 ---

func _get_input_mapping() -> GFInputMappingUtility:
	if _input_mapping_ref == null:
		return null
	var input_mapping: Variant = _input_mapping_ref.get_ref()
	if input_mapping is GFInputMappingUtility:
		return input_mapping
	return null


func _get_timer_utility() -> GFTimerUtility:
	if _timer_utility_ref == null:
		return null
	var timer_value: Variant = _timer_utility_ref.get_ref()
	if timer_value is GFTimerUtility:
		var timer_utility: GFTimerUtility = timer_value
		return timer_utility
	return null


func _take_next_pulse_generation() -> int:
	var generation: int = _next_pulse_generation
	_next_pulse_generation += 1
	if _next_pulse_generation <= 0:
		_next_pulse_generation = 1
	return generation


func _cancel_active_pulses(reason: StringName) -> void:
	var operations: Array = _active_pulses.values()
	for operation_value: Variant in operations:
		var operation: GFVirtualInputPulseOperation = _variant_to_pulse_operation(operation_value)
		if operation != null and operation.is_pending():
			var _cancelled: bool = operation.cancel(reason)
	_active_pulses.clear()


func _get_pulse_operation(generation: int) -> GFVirtualInputPulseOperation:
	return _variant_to_pulse_operation(GFVariantData.get_option_value(_active_pulses, generation))


func _variant_to_pulse_operation(value: Variant) -> GFVirtualInputPulseOperation:
	if value is GFVirtualInputPulseOperation:
		var operation: GFVirtualInputPulseOperation = value
		return operation
	return null
