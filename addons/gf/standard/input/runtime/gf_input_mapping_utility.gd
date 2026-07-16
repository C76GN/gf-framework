## GFInputMappingUtility: 资源化输入上下文与动作映射运行时。
##
## 负责把 Godot InputEvent 转换为项目定义的抽象动作状态，并支持上下文优先级、
## 运行时重绑定、动作值查询和一次性触发消费。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputMappingUtility
extends GFUtility


# --- 信号 ---

## 启用上下文变化后发出。
## [br]
## @api public
## [br]
## @param contexts: 当前启用上下文，已按运行时处理顺序排序。
## [br]
## @schema contexts: Array[GFInputContext]，按有效优先级和激活时间戳排序。
signal contexts_changed(contexts: Array[GFInputContext])

## 有效映射变化后发出。
## [br]
## @api public
signal mappings_changed

## 动作值变化时发出。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 新动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal action_value_changed(action_id: StringName, value: Variant)

## 动作从非活跃变为活跃时发出。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 激活时的动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal action_started(action_id: StringName, value: Variant)

## 动作活跃且收到匹配输入事件时发出。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 当前动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal action_triggered(action_id: StringName, value: Variant)

## 动作从活跃变为非活跃时发出。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 完成时的动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal action_completed(action_id: StringName, value: Variant)

## 玩家动作值变化时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 新动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal player_action_value_changed(player_index: int, action_id: StringName, value: Variant)

## 玩家动作从非活跃变为活跃时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 激活时的动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal player_action_started(player_index: int, action_id: StringName, value: Variant)

## 玩家动作活跃且收到匹配输入事件时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 当前动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal player_action_triggered(player_index: int, action_id: StringName, value: Variant)

## 玩家动作从活跃变为非活跃时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 完成时的动作值。
## [br]
## @schema value: Variant，根据动作值类型使用 bool、float、Vector2 或 Vector3。
signal player_action_completed(player_index: int, action_id: StringName, value: Variant)


# --- 常量 ---

const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")
const _INPUT_KEY_SCHEMA_PREFIX: String = "gf_input_key_v1"


# --- 私有变量 ---

var _active_contexts: Dictionary = {}
var _effective_entries: Array[Dictionary] = []
var _binding_values: Dictionary = {}
var _binding_to_action: Dictionary = {}
var _binding_player_indices: Dictionary = {}
var _player_binding_values: Dictionary = {}
var _player_binding_to_action: Dictionary = {}
var _player_binding_metadata: Dictionary = {}
var _actions: Dictionary = {}
var _action_modifiers: Dictionary = {}
var _action_triggers: Dictionary = {}
var _action_trigger_states: Dictionary = {}
var _action_values: Dictionary = {}
var _action_active: Dictionary = {}
var _raw_action_active: Dictionary = {}
var _just_started: Dictionary = {}
var _just_completed: Dictionary = {}
var _action_active_elapsed: Dictionary = {}
var _last_completed_duration: Dictionary = {}
var _player_action_values: Dictionary = {}
var _player_action_active: Dictionary = {}
var _player_raw_action_active: Dictionary = {}
var _player_action_metadata: Dictionary = {}
var _player_trigger_states: Dictionary = {}
var _player_just_started: Dictionary = {}
var _player_just_completed: Dictionary = {}
var _player_action_active_elapsed: Dictionary = {}
var _player_last_completed_duration: Dictionary = {}
var _remap_config: GFInputRemapConfig
var _timestamp: int = 0
var _router: _GFInputRouter
var _router_attach_serial: int = 0
var _input_devices: GFInputDeviceUtility = null
var _clear_transient_input_state_queued: bool = false
var _transient_input_state_mark_frame: int = -1


# --- GF 生命周期方法 ---

## 初始化输入映射运行时状态并挂载输入路由节点。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	ignore_time_scale = true
	_clear_runtime_state()
	_ensure_router()


## 绑定可选的设备分配工具，用于在玩家设备变化时清理运行时输入状态。
## [br]
## @api public
## [br]
## @since 7.0.0
func ready() -> void:
	_bind_input_device_utility()


## 释放输入路由节点并清理全部运行时状态。
## [br]
## @api public
func dispose() -> void:
	_router_attach_serial += 1
	_unbind_input_device_utility()
	_active_contexts.clear()
	_effective_entries.clear()
	_clear_runtime_state()
	if is_instance_valid(_router):
		_router.queue_free()
	_router = null


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	_bind_input_device_utility()
	_clear_transient_input_state_if_queued()
	_advance_active_durations(delta)
	_refresh_triggered_action_states(delta)


# --- 公共方法 ---

## 设置重映射配置。
## [br]
## @api public
## [br]
## @param config: 输入重映射配置；传 null 表示使用默认绑定。
func set_remap_config(config: GFInputRemapConfig) -> void:
	_remap_config = config
	_rebuild_effective_entries()


## 获取当前重映射配置。若不存在且 create_if_missing 为 true，会自动创建。
## [br]
## @api public
## [br]
## @param create_if_missing: 是否在缺失时创建。
## [br]
## @return 重映射配置。
func get_remap_config(create_if_missing: bool = false) -> GFInputRemapConfig:
	if _remap_config == null and create_if_missing:
		_remap_config = GFInputRemapConfig.new()
	return _remap_config


## 启用输入上下文。
## [br]
## @api public
## [br]
## @param context: 输入上下文资源。
## [br]
## @param priority: 优先级，数值越大越先处理。
func enable_context(context: GFInputContext, priority: int = 0) -> void:
	if context == null:
		push_error("[GFInputMappingUtility] enable_context 失败：context 为空。")
		return

	_timestamp += 1
	_active_contexts[context] = {
		"priority": priority,
		"timestamp": _timestamp,
	}
	_rebuild_effective_entries()


## 禁用输入上下文。
## [br]
## @api public
## [br]
## @param context: 输入上下文资源。
func disable_context(context: GFInputContext) -> void:
	if context == null:
		return
	_erase_dictionary_key(_active_contexts, context)
	_rebuild_effective_entries()


## 批量替换当前启用的上下文。
## [br]
## @api public
## [br]
## @param contexts: 输入上下文数组。
## [br]
## @param priority: 批量上下文默认优先级；数组越靠后，同优先级下越先处理。
## [br]
## @schema contexts: Array[GFInputContext]，作为新的活跃 context 集启用。
func set_enabled_contexts(contexts: Array[GFInputContext], priority: int = 0) -> void:
	_active_contexts.clear()
	for context: GFInputContext in contexts:
		if context == null:
			continue
		_timestamp += 1
		_active_contexts[context] = {
			"priority": priority,
			"timestamp": _timestamp,
		}
	_rebuild_effective_entries()


## 清空所有启用上下文。
## [br]
## @api public
func clear_contexts() -> void:
	_active_contexts.clear()
	_rebuild_effective_entries()


## 检查上下文是否启用。
## [br]
## @api public
## [br]
## @param context: 输入上下文资源。
## [br]
## @return 是否启用。
func is_context_enabled(context: GFInputContext) -> bool:
	return _active_contexts.has(context)


## 获取已启用上下文，按实际处理顺序返回。
## [br]
## @api public
## [br]
## @return 上下文数组。
## [br]
## @schema return: Array[GFInputContext]，按有效优先级和激活时间戳排序。
func get_enabled_contexts() -> Array[GFInputContext]:
	return _get_sorted_contexts()


## 手动处理输入事件。通常由内部路由节点自动调用，也可用于测试或自定义输入桥接。
## [br]
## @api public
## [br]
## @param event: Godot 输入事件。
func handle_input_event(event: InputEvent) -> void:
	if event == null or _should_ignore_event(event):
		return

	var player_index: int = _resolve_player_index(event)
	if player_index < 0 and _input_event_requires_device_assignment(event):
		return
	var event_blocked: bool = false
	for entry: Dictionary in _effective_entries:
		if event_blocked:
			continue

		var matched: bool = _apply_entry_event(entry, event, player_index)
		if not matched:
			continue

		var action: GFInputAction = _get_entry_action(entry)
		if action == null:
			continue
		var action_id: StringName = action.get_action_id()
		var value: Variant = get_action_value(action_id)
		if action.block_lower_priority_actions and is_action_active(action_id):
			event_blocked = true

		if is_action_active(action_id):
			action_triggered.emit(action_id, value)
		if player_index >= 0 and is_action_active_for_player(player_index, action_id):
			player_action_triggered.emit(player_index, action_id, get_action_value_for_player(player_index, action_id))


## 创建可编程虚拟输入源。
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @param player_index: 玩家索引；小于 0 时只写入全局动作状态。
## [br]
## @return 虚拟输入源。
## [br]
## @api public
func create_virtual_source(
	source_id: StringName = &"virtual",
	player_index: int = -1
) -> GFVirtualInputSource:
	return GFVirtualInputSource.new(self, source_id, player_index)


## 写入虚拟动作值。
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 动作值。
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @param player_index: 玩家索引；小于 0 时只写入全局动作状态。
## [br]
## @return 写入成功返回 true。
## [br]
## @api public
## [br]
## @schema value: Variant，要转换为动作运行时向量贡献的 bool、float、Vector2 或 Vector3 值。
func set_virtual_action_value(
	action_id: StringName,
	value: Variant,
	source_id: StringName = &"virtual",
	player_index: int = -1
) -> bool:
	var action: GFInputAction = _get_registered_action(action_id)
	if action == null:
		return false

	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var contribution: Vector3 = _coerce_virtual_value_to_vector(value, action.value_type)
	var binding_key: String = _make_virtual_binding_key(source_key, action_id, player_index)
	_binding_values[binding_key] = contribution
	_binding_to_action[binding_key] = action_id
	if player_index >= 0:
		_binding_player_indices[binding_key] = player_index
	else:
		_erase_dictionary_key(_binding_player_indices, binding_key)
	_refresh_action_state(action_id, action)

	if player_index >= 0:
		var player_binding_key: String = _make_player_binding_key(player_index, binding_key)
		_register_player_binding_metadata(player_binding_key, player_index, binding_key)
		_player_binding_values[player_binding_key] = contribution
		_player_binding_to_action[player_binding_key] = action_id
		_refresh_player_action_state(player_index, action_id, action)

	return true


## 清除虚拟动作值。
## [br]
## @param action_id: 动作标识。
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @param player_index: 玩家索引；小于 0 时只清除全局动作状态。
## [br]
## @return 清除成功返回 true。
## [br]
## @api public
func clear_virtual_action(
	action_id: StringName,
	source_id: StringName = &"virtual",
	player_index: int = -1
) -> bool:
	var action: GFInputAction = _get_registered_action(action_id)
	if action == null:
		return false

	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var binding_key: String = _make_virtual_binding_key(source_key, action_id, player_index)
	var changed: bool = _binding_values.has(binding_key)
	_erase_dictionary_key(_binding_values, binding_key)
	_erase_dictionary_key(_binding_to_action, binding_key)
	_erase_dictionary_key(_binding_player_indices, binding_key)
	_refresh_action_state(action_id, action)

	if player_index >= 0:
		var player_binding_key: String = _make_player_binding_key(player_index, binding_key)
		changed = _player_binding_values.has(player_binding_key) or changed
		_erase_dictionary_key(_player_binding_values, player_binding_key)
		_erase_dictionary_key(_player_binding_to_action, player_binding_key)
		_erase_dictionary_key(_player_binding_metadata, player_binding_key)
		_refresh_player_action_state(player_index, action_id, action)

	return changed


## 清除指定虚拟输入源的所有动作贡献。
## [br]
## @api public
## [br]
## @param source_id: 虚拟输入源标识。
func clear_virtual_source(source_id: StringName = &"virtual") -> void:
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var affected_actions: Dictionary = {}
	var affected_player_actions: Dictionary = {}

	for key: String in _binding_to_action.keys():
		if not _is_virtual_binding_key_for_source(key, source_key):
			continue
		var action_id: StringName = GFVariantData.to_string_name(_binding_to_action[key])
		affected_actions[action_id] = true
		_erase_dictionary_key(_binding_values, key)
		_erase_dictionary_key(_binding_to_action, key)
		_erase_dictionary_key(_binding_player_indices, key)

	for key: String in _player_binding_to_action.keys():
		var source_part: String = _get_player_source_binding_key(key)
		if not _is_virtual_binding_key_for_source(source_part, source_key):
			continue
		var action_id: StringName = GFVariantData.to_string_name(_player_binding_to_action[key])
		var player_index: int = _get_player_index_from_binding_key(key)
		affected_player_actions[_make_player_action_key(player_index, action_id)] = {
			"player_index": player_index,
			"action_id": action_id,
		}
		_erase_dictionary_key(_player_binding_values, key)
		_erase_dictionary_key(_player_binding_to_action, key)
		_erase_dictionary_key(_player_binding_metadata, key)

	for action_id: StringName in affected_actions.keys():
		var action: GFInputAction = _get_registered_action(action_id)
		if action != null:
			_refresh_action_state(action_id, action)

	for entry: Dictionary in affected_player_actions.values():
		var action_id: StringName = _get_entry_action_id(entry)
		var action: GFInputAction = _get_registered_action(action_id)
		if action != null:
			_refresh_player_action_state(_get_entry_player_index(entry), action_id, action)


## 获取虚拟输入源状态快照。
## [br]
## @api public
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @return 快照字典。
## [br]
## @schema return: Dictionary，包含 source_id 和 actions: Array[Dictionary]，action 条目包含 action_id 与 value。
func get_virtual_source_snapshot(source_id: StringName = &"virtual") -> Dictionary:
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var actions: Array[Dictionary] = []
	for key: String in _binding_to_action.keys():
		if _is_virtual_binding_key_for_source(key, source_key):
			_append_array_value(actions, {
				"action_id": _binding_to_action[key],
				"value": _get_binding_vector_value(key),
			})

	return {
		"source_id": source_key,
		"actions": actions,
	}


## 获取动作当前值。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return bool、float、Vector2 或 Vector3，取决于动作值类型。
## [br]
## @schema return: Variant，根据动作值类型返回 bool、float、Vector2、Vector3 或 null。
func get_action_value(action_id: StringName) -> Variant:
	if _action_values.has(action_id):
		return _action_values[action_id]

	var action: GFInputAction = _get_registered_action(action_id)
	if action == null:
		return null
	return _default_value_for_type(action.value_type)


## 获取动作当前二维向量值。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 二维向量值；三维轴会返回 x/y 分量。
func get_action_vector(action_id: StringName) -> Vector2:
	var vector: Vector3 = _calculate_action_vector3(action_id)
	return Vector2(vector.x, vector.y)


## 获取动作当前三维向量值。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 三维向量值；非三维动作的 z 分量为 0。
func get_action_vector3(action_id: StringName) -> Vector3:
	return _calculate_action_vector3(action_id)


## 检查动作是否活跃。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否活跃。
func is_action_active(action_id: StringName) -> bool:
	return _get_action_active(action_id)


## 检查动作是否在当前帧刚刚开始。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否刚开始。
func was_action_just_started(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_just_started, action_id)


## 检查动作是否在当前帧刚刚结束。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否刚结束。
func was_action_just_completed(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_just_completed, action_id)


## 获取动作最近一次结束前的持续活跃时间。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 持续秒数。
func get_last_completed_duration(action_id: StringName) -> float:
	return GFVariantData.get_option_float(_last_completed_duration, action_id)


## 消费一次刚开始的动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 成功消费返回 true。
func consume_action(action_id: StringName) -> bool:
	if not was_action_just_started(action_id):
		return false
	_erase_dictionary_key(_just_started, action_id)
	return true


## 获取指定玩家动作当前值。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return bool、float、Vector2 或 Vector3，取决于动作值类型。
## [br]
## @schema return: Variant，根据动作值类型返回 bool、float、Vector2、Vector3 或 null。
func get_action_value_for_player(player_index: int, action_id: StringName) -> Variant:
	var key: String = _make_player_action_key(player_index, action_id)
	if _player_action_values.has(key):
		return _player_action_values[key]

	var action: GFInputAction = _get_registered_action(action_id)
	if action == null:
		return null
	return _default_value_for_type(action.value_type)


## 获取指定玩家动作当前二维向量值。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 二维向量值；三维轴会返回 x/y 分量。
func get_action_vector_for_player(player_index: int, action_id: StringName) -> Vector2:
	var vector: Vector3 = _calculate_player_action_vector3(player_index, action_id)
	return Vector2(vector.x, vector.y)


## 获取指定玩家动作当前三维向量值。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 三维向量值；非三维动作的 z 分量为 0。
func get_action_vector3_for_player(player_index: int, action_id: StringName) -> Vector3:
	return _calculate_player_action_vector3(player_index, action_id)


## 检查指定玩家动作是否活跃。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否活跃。
func is_action_active_for_player(player_index: int, action_id: StringName) -> bool:
	return _get_player_action_active(player_index, action_id)


## 检查指定玩家动作是否在当前帧刚刚开始。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否刚开始。
func was_action_just_started_for_player(player_index: int, action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_player_just_started, _make_player_action_key(player_index, action_id))


## 检查指定玩家动作是否在当前帧刚刚结束。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 是否刚结束。
func was_action_just_completed_for_player(player_index: int, action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_player_just_completed, _make_player_action_key(player_index, action_id))


## 获取指定玩家动作最近一次结束前的持续活跃时间。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 持续秒数。
func get_last_completed_duration_for_player(player_index: int, action_id: StringName) -> float:
	return GFVariantData.get_option_float(_player_last_completed_duration, _make_player_action_key(player_index, action_id))


## 消费指定玩家的一次刚开始动作。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 成功消费返回 true。
func consume_action_for_player(player_index: int, action_id: StringName) -> bool:
	var key: String = _make_player_action_key(player_index, action_id)
	if not GFVariantData.get_option_bool(_player_just_started, key):
		return false
	_erase_dictionary_key(_player_just_started, key)
	return true


## 设置某个绑定的运行时覆盖。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
## [br]
## @param input_event: 新输入事件。
func set_binding_override(
	context_id: StringName,
	action_id: StringName,
	binding_index: int,
	input_event: InputEvent
) -> void:
	get_remap_config(true).set_binding(context_id, action_id, binding_index, input_event)
	_rebuild_effective_entries()


## 显式解绑某个绑定。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:
	get_remap_config(true).unbind(context_id, action_id, binding_index)
	_rebuild_effective_entries()


## 清除某个绑定覆盖。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
func clear_binding_override(context_id: StringName, action_id: StringName, binding_index: int) -> void:
	if _remap_config != null:
		_remap_config.clear_binding(context_id, action_id, binding_index)
		_rebuild_effective_entries()


## 获取可重绑条目。
## [br]
## @api public
## [br]
## @param context_filter: 可选上下文过滤。
## [br]
## @param display_category_filter: 可选显示分类过滤。
## [br]
## @return 条目字典数组。
## [br]
## @schema return: Array[Dictionary]，包含 context、context_id、mapping、action、action_id、binding、binding_index、display_name、display_category 和 event 字段。
func get_remappable_items(
	context_filter: StringName = &"",
	display_category_filter: String = ""
) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for context: GFInputContext in _get_sorted_contexts():
		var context_id: StringName = context.get_context_id()
		if context_filter != &"" and context_id != context_filter:
			continue

		for mapping: GFInputMapping in context.mappings:
			if mapping == null or mapping.action == null or not mapping.action.remappable:
				continue
			if not display_category_filter.is_empty() and mapping.get_display_category() != display_category_filter:
				continue

			for index: int in range(mapping.bindings.size()):
				var binding: GFInputBinding = mapping.bindings[index]
				if binding == null or not binding.remappable:
					continue
				_append_array_value(items, {
					"context": context,
					"context_id": context_id,
					"mapping": mapping,
					"action": mapping.action,
					"action_id": mapping.get_action_id(),
					"binding": binding,
					"binding_index": index,
					"display_name": mapping.get_display_name(),
					"display_category": mapping.get_display_category(),
					"event": _get_effective_event(context_id, mapping.get_action_id(), index, binding),
				})
	return items


## 清空所有动作运行时状态。
## [br]
## @api public
func clear_input_state() -> void:
	_clear_runtime_state(true)


## 清空指定玩家动作运行时状态。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
func clear_player_input_state(player_index: int) -> void:
	_clear_player_runtime_state(player_index, true)


# --- 私有/辅助方法 ---

func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _append_array_value(target: Array, value: Variant) -> void:
	target.append(value)


func _get_node_value(value: Variant) -> Node:
	if value is Node:
		return value
	return null


func _get_scene_tree_value(value: Variant) -> SceneTree:
	if value is SceneTree:
		return value
	return null


func _get_input_action_value(value: Variant) -> GFInputAction:
	if value is GFInputAction:
		return value
	return null


func _get_input_binding_value(value: Variant) -> GFInputBinding:
	if value is GFInputBinding:
		return value
	return null


func _get_input_context_value(value: Variant) -> GFInputContext:
	if value is GFInputContext:
		return value
	return null


func _get_input_event_value(value: Variant) -> InputEvent:
	if value is InputEvent:
		return value
	return null


func _get_input_trigger_value(value: Variant) -> GFInputTrigger:
	if value is GFInputTrigger:
		return value
	return null


func _get_input_device_utility_value(value: Variant) -> GFInputDeviceUtility:
	if value is GFInputDeviceUtility:
		return value
	return null


func _get_registered_action(action_id: StringName) -> GFInputAction:
	return _get_input_action_value(GFVariantData.get_option_value(_actions, action_id))


func _get_entry_action(entry: Dictionary) -> GFInputAction:
	return _get_input_action_value(GFVariantData.get_option_value(entry, "action"))


func _get_entry_action_id(entry: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(entry, "action_id")


func _get_entry_player_index(entry: Dictionary) -> int:
	return GFVariantData.get_option_int(entry, "player_index", -1)


func _get_entry_bindings(entry: Dictionary) -> Array:
	return GFVariantData.get_option_array(entry, "bindings")


func _get_binding_info_binding(binding_info: Dictionary) -> GFInputBinding:
	return _get_input_binding_value(GFVariantData.get_option_value(binding_info, "binding"))


func _get_binding_info_key(binding_info: Dictionary) -> String:
	return GFVariantData.get_option_string(binding_info, "key")


func _get_context_meta(context: GFInputContext) -> Dictionary:
	return GFVariantData.get_option_dictionary(_active_contexts, context)


func _get_context_priority(context_meta: Dictionary) -> int:
	return GFVariantData.get_option_int(context_meta, "priority")


func _get_context_timestamp(context_meta: Dictionary) -> int:
	return GFVariantData.get_option_int(context_meta, "timestamp")


func _get_binding_vector_value(binding_key: String) -> Vector3:
	return GFVariantData.get_option_vector3(_binding_values, binding_key, Vector3.ZERO)


func _get_binding_action_id(binding_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_binding_to_action, binding_key)


func _get_binding_player_index(binding_key: String) -> int:
	return GFVariantData.get_option_int(_binding_player_indices, binding_key, -1)


func _get_player_binding_action_id(binding_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_player_binding_to_action, binding_key)


func _get_action_active(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_action_active, action_id)


func _get_action_active_elapsed(action_id: StringName) -> float:
	return GFVariantData.get_option_float(_action_active_elapsed, action_id)


func _get_action_value_or_default(action_id: StringName, value_type: GFInputAction.ValueType) -> Variant:
	return GFVariantData.get_option_value(_action_values, action_id, _default_value_for_type(value_type))


func _get_raw_action_active(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_raw_action_active, action_id)


func _get_action_triggers(action_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_action_triggers, action_id, []))


func _get_action_modifiers(action_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_action_modifiers, action_id, []))


func _get_player_action_active(player_index: int, action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(
		_player_action_active,
		_make_player_action_key(player_index, action_id)
	)


func _get_player_action_active_by_key(player_action_key: String) -> bool:
	return GFVariantData.get_option_bool(_player_action_active, player_action_key)


func _get_player_action_active_elapsed(player_action_key: String) -> float:
	return GFVariantData.get_option_float(_player_action_active_elapsed, player_action_key)


func _get_player_action_value_or_default(player_action_key: String, value_type: GFInputAction.ValueType) -> Variant:
	return GFVariantData.get_option_value(
		_player_action_values,
		player_action_key,
		_default_value_for_type(value_type)
	)


func _get_player_raw_action_active(player_action_key: String) -> bool:
	return GFVariantData.get_option_bool(_player_raw_action_active, player_action_key)


func _ensure_router() -> void:
	if is_instance_valid(_router):
		return

	var tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if tree == null:
		return

	_router = _GFInputRouter.new()
	_router.name = "GFInputMappingRouter"
	_router._input_callback = Callable(self, "handle_input_event")
	_router._focus_lost_callback = Callable(self, "clear_input_state")
	_router_attach_serial += 1
	call_deferred("_attach_router_to_root", _router, _router_attach_serial)


func _attach_router_to_root(router_variant: Variant, attach_serial: int) -> void:
	if not is_instance_valid(router_variant):
		return

	var router: Node = _get_node_value(router_variant)
	if router == null:
		return
	if attach_serial != _router_attach_serial or router != _router:
		if is_instance_valid(router):
			router.queue_free()
		return

	if (not is_instance_valid(router)
		or router.is_queued_for_deletion()
		or router.is_inside_tree()
	):
		return

	var tree: SceneTree = _get_scene_tree_value(Engine.get_main_loop())
	if tree == null:
		_router = null
		router.queue_free()
		return

	tree.root.add_child(router)


func _rebuild_effective_entries() -> void:
	_clear_runtime_state(true)
	_effective_entries.clear()
	_actions.clear()
	_action_modifiers.clear()
	_action_triggers.clear()

	for context: GFInputContext in _get_sorted_contexts():
		var context_id: StringName = context.get_context_id()
		if context_id == &"":
			continue

		for mapping: GFInputMapping in context.mappings:
			if mapping == null or mapping.action == null:
				continue

			var action_id: StringName = mapping.get_action_id()
			if action_id == &"":
				continue

			var bindings: Array[Dictionary] = []
			for index: int in range(mapping.bindings.size()):
				var base_binding: GFInputBinding = mapping.bindings[index]
				if base_binding == null:
					continue

				var binding: GFInputBinding = base_binding.duplicate_binding()
				if binding == null:
					continue
				if _remap_config != null and _remap_config.has_binding(context_id, action_id, index):
					var override_event: InputEvent = _remap_config.get_bound_event_or_null(context_id, action_id, index)
					if override_event == null:
						continue
					var duplicated_event: InputEvent = _get_input_event_value(override_event.duplicate(true))
					if duplicated_event == null:
						continue
					binding.input_event = duplicated_event

				_append_array_value(bindings, {
					"binding": binding,
					"key": _make_binding_key(context_id, action_id, index),
				})

			if not _actions.has(action_id):
				_actions[action_id] = mapping.action
				_action_modifiers[action_id] = _duplicate_modifiers(mapping.modifiers)
				_action_triggers[action_id] = _duplicate_triggers(mapping.triggers)
			_append_array_value(_effective_entries, {
				"context": context,
				"mapping": mapping,
				"action": mapping.action,
				"action_id": action_id,
				"bindings": bindings,
			})

	contexts_changed.emit(get_enabled_contexts())
	mappings_changed.emit()


func _get_sorted_contexts() -> Array[GFInputContext]:
	var contexts: Array[GFInputContext] = []
	for context_variant: Variant in _active_contexts.keys():
		var context: GFInputContext = _get_input_context_value(context_variant)
		if context != null:
			_append_array_value(contexts, context)

	contexts.sort_custom(func(left: GFInputContext, right: GFInputContext) -> bool:
		var left_meta: Dictionary = _get_context_meta(left)
		var right_meta: Dictionary = _get_context_meta(right)
		var left_priority: int = _get_context_priority(left_meta)
		var right_priority: int = _get_context_priority(right_meta)
		if left_priority != right_priority:
			return left_priority > right_priority
		return _get_context_timestamp(left_meta) > _get_context_timestamp(right_meta)
	)
	return contexts


func _apply_entry_event(entry: Dictionary, event: InputEvent, player_index: int) -> bool:
	var matched: bool = false
	var action: GFInputAction = _get_entry_action(entry)
	var action_id: StringName = _get_entry_action_id(entry)
	if action == null or action_id == &"":
		return false
	for binding_info_value: Variant in _get_entry_bindings(entry):
		var binding_info: Dictionary = GFVariantData.as_dictionary(binding_info_value)
		var binding: GFInputBinding = _get_binding_info_binding(binding_info)
		if binding == null or not binding.matches_event(event):
			continue

		var binding_key: String = _get_binding_info_key(binding_info)
		var key: String = _make_source_binding_key(binding_key, event)
		var contribution: Vector3 = binding.get_contribution(event, action.value_type, _get_player_deadzone(player_index))
		_binding_values[key] = contribution
		_binding_to_action[key] = action_id
		if player_index >= 0:
			_binding_player_indices[key] = player_index
			var player_binding_key: String = _make_player_binding_key(player_index, key)
			_register_player_binding_metadata(player_binding_key, player_index, key)
			_player_binding_values[player_binding_key] = contribution
			_player_binding_to_action[player_binding_key] = action_id
		else:
			_erase_dictionary_key(_binding_player_indices, key)
		matched = true

	if matched:
		_refresh_action_state(action_id, action)
		if player_index >= 0:
			_refresh_player_action_state(player_index, action_id, action)

	return matched


func _refresh_action_state(action_id: StringName, action: GFInputAction) -> void:
	var previous_value: Variant = GFVariantData.get_option_value(
		_action_values,
		action_id,
		_default_value_for_type(action.value_type)
	)
	var previous_active: bool = _get_action_active(action_id)
	var next_value: Variant = _calculate_action_value(action_id, action.value_type)
	var raw_active: bool = _is_value_active(next_value, action)
	var next_active: bool = _evaluate_action_triggers(action_id, raw_active, next_value, 0.0)

	_action_values[action_id] = next_value
	_action_active[action_id] = next_active
	_raw_action_active[action_id] = raw_active

	if not _values_equal(previous_value, next_value):
		action_value_changed.emit(action_id, next_value)

	if not previous_active and next_active:
		_mark_action_just_started(action_id)
		_action_active_elapsed[action_id] = 0.0
		action_started.emit(action_id, next_value)
	elif previous_active and not next_active:
		_mark_action_just_completed(action_id)
		_last_completed_duration[action_id] = _get_action_active_elapsed(action_id)
		_erase_dictionary_key(_action_active_elapsed, action_id)
		action_completed.emit(action_id, next_value)


func _calculate_action_vector3(action_id: StringName) -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for key: String in _binding_values.keys():
		if _get_binding_action_id(key) == action_id:
			total += GFVariantData.to_vector3(_binding_values[key])
	if total.length() > 1.0:
		total = total.normalized()
	return _apply_mapping_modifiers(action_id, total)


func _calculate_player_action_vector3(player_index: int, action_id: StringName) -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for key: String in _player_binding_values.keys():
		if _get_player_index_from_binding_key(key) != player_index:
			continue
		if _get_player_binding_action_id(key) == action_id:
			total += GFVariantData.to_vector3(_player_binding_values[key])
	if total.length() > 1.0:
		total = total.normalized()
	return _apply_mapping_modifiers(action_id, total)


func _calculate_action_value(action_id: StringName, value_type: GFInputAction.ValueType) -> Variant:
	var vector: Vector3 = _calculate_action_vector3(action_id)
	return _calculate_value_from_vector(vector, value_type)


func _calculate_player_action_value(
	player_index: int,
	action_id: StringName,
	value_type: GFInputAction.ValueType
) -> Variant:
	var vector: Vector3 = _calculate_player_action_vector3(player_index, action_id)
	return _calculate_value_from_vector(vector, value_type)


func _calculate_value_from_vector(vector: Vector3, value_type: GFInputAction.ValueType) -> Variant:
	match value_type:
		GFInputAction.ValueType.BOOL:
			return vector.length() > 0.0
		GFInputAction.ValueType.AXIS_1D:
			return clampf(vector.x, -1.0, 1.0)
		GFInputAction.ValueType.AXIS_2D:
			return Vector2(vector.x, vector.y)
		GFInputAction.ValueType.AXIS_3D:
			return vector
		_:
			return null


func _default_value_for_type(value_type: GFInputAction.ValueType) -> Variant:
	match value_type:
		GFInputAction.ValueType.BOOL:
			return false
		GFInputAction.ValueType.AXIS_1D:
			return 0.0
		GFInputAction.ValueType.AXIS_2D:
			return Vector2.ZERO
		GFInputAction.ValueType.AXIS_3D:
			return Vector3.ZERO
		_:
			return null


func _is_value_active(value: Variant, action: GFInputAction) -> bool:
	match action.value_type:
		GFInputAction.ValueType.BOOL:
			return GFVariantData.to_bool(value)
		GFInputAction.ValueType.AXIS_1D:
			return absf(GFVariantData.to_float(value)) >= action.activation_threshold
		GFInputAction.ValueType.AXIS_2D:
			return GFVariantData.to_vector2(value).length() >= action.activation_threshold
		GFInputAction.ValueType.AXIS_3D:
			return GFVariantData.to_vector3(value).length() >= action.activation_threshold
		_:
			return false


func _values_equal(left: Variant, right: Variant) -> bool:
	if left is float or right is float:
		return is_equal_approx(GFVariantData.to_float(left), GFVariantData.to_float(right))
	if left is Vector2 and right is Vector2:
		var left_vector2: Vector2 = left
		var right_vector2: Vector2 = right
		return left_vector2.is_equal_approx(right_vector2)
	if left is Vector3 and right is Vector3:
		var left_vector3: Vector3 = left
		var right_vector3: Vector3 = right
		return left_vector3.is_equal_approx(right_vector3)
	return left == right


func _mark_action_just_started(action_id: StringName) -> void:
	_just_started[action_id] = true
	_queue_clear_transient_input_state()


func _mark_action_just_completed(action_id: StringName) -> void:
	_just_completed[action_id] = true
	_queue_clear_transient_input_state()


func _mark_player_action_just_started(player_index: int, action_id: StringName) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	_player_just_started[key] = true
	_queue_clear_transient_input_state()


func _mark_player_action_just_completed(player_index: int, action_id: StringName) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	_player_just_completed[key] = true
	_queue_clear_transient_input_state()


func _queue_clear_transient_input_state() -> void:
	_clear_transient_input_state_queued = true
	_transient_input_state_mark_frame = Engine.get_process_frames()


func _clear_transient_input_state_if_queued() -> void:
	if not _clear_transient_input_state_queued:
		return
	if Engine.get_process_frames() <= _transient_input_state_mark_frame:
		return

	_just_started.clear()
	_just_completed.clear()
	_player_just_started.clear()
	_player_just_completed.clear()
	_clear_transient_input_state_queued = false
	_transient_input_state_mark_frame = -1


func _clear_runtime_state(emit_completed: bool = false) -> void:
	if emit_completed:
		for action_id: StringName in _action_active.keys():
			if _get_action_active(action_id) and _actions.has(action_id):
				var action: GFInputAction = _get_registered_action(action_id)
				if action != null:
					action_completed.emit(action_id, _default_value_for_type(action.value_type))
		for player_action_key: String in _player_action_active.keys():
			if not _get_player_action_active_by_key(player_action_key):
				continue
			var player_index: int = _get_player_index_from_action_key(player_action_key)
			var action_id: StringName = _get_player_action_id_from_key(player_action_key)
			if player_index < 0 or action_id == &"":
				continue
			var action: GFInputAction = _get_registered_action(action_id)
			if action != null:
				player_action_completed.emit(player_index, action_id, _default_value_for_type(action.value_type))

	_binding_values.clear()
	_binding_to_action.clear()
	_binding_player_indices.clear()
	_player_binding_values.clear()
	_player_binding_to_action.clear()
	_player_binding_metadata.clear()
	_action_values.clear()
	_action_active.clear()
	_raw_action_active.clear()
	_just_started.clear()
	_just_completed.clear()
	_action_active_elapsed.clear()
	_last_completed_duration.clear()
	_player_action_values.clear()
	_player_action_active.clear()
	_player_raw_action_active.clear()
	_player_action_metadata.clear()
	_player_just_started.clear()
	_player_just_completed.clear()
	_player_action_active_elapsed.clear()
	_player_last_completed_duration.clear()
	_clear_transient_input_state_queued = false
	_transient_input_state_mark_frame = -1
	_reset_all_trigger_states()


func _clear_player_runtime_state(player_index: int, emit_completed: bool = false) -> void:
	var affected_actions: Dictionary = {}
	if emit_completed:
		for player_action_key: String in _player_action_active.keys():
			if _get_player_index_from_action_key(player_action_key) != player_index:
				continue
			if not _get_player_action_active_by_key(player_action_key):
				continue
			var action_id: StringName = _get_player_action_id_from_key(player_action_key)
			var action: GFInputAction = _get_registered_action(action_id)
			if action != null:
				player_action_completed.emit(player_index, action_id, _default_value_for_type(action.value_type))

	for key: String in _binding_player_indices.keys():
		if _get_binding_player_index(key) != player_index:
			continue
		var action_id: StringName = _get_binding_action_id(key)
		if action_id != &"":
			affected_actions[action_id] = true
		_erase_dictionary_key(_binding_values, key)
		_erase_dictionary_key(_binding_to_action, key)
		_erase_dictionary_key(_binding_player_indices, key)

	for key: String in _player_binding_values.keys():
		if _get_player_index_from_binding_key(key) != player_index:
			continue
		_erase_dictionary_key(_player_binding_values, key)
		_erase_dictionary_key(_player_binding_to_action, key)
		_erase_dictionary_key(_player_binding_metadata, key)
	for key: String in _player_action_values.keys():
		if _get_player_index_from_action_key(key) != player_index:
			continue
		_erase_dictionary_key(_player_action_values, key)
		_erase_dictionary_key(_player_action_active, key)
		_erase_dictionary_key(_player_raw_action_active, key)
		_erase_dictionary_key(_player_action_metadata, key)
		_erase_dictionary_key(_player_trigger_states, key)
		_erase_dictionary_key(_player_just_started, key)
		_erase_dictionary_key(_player_just_completed, key)
		_erase_dictionary_key(_player_action_active_elapsed, key)
		_erase_dictionary_key(_player_last_completed_duration, key)

	for action_id: StringName in affected_actions.keys():
		var action: GFInputAction = _get_registered_action(action_id)
		if action != null:
			_refresh_action_state(action_id, action)


func _get_effective_event(
	context_id: StringName,
	action_id: StringName,
	binding_index: int,
	binding: GFInputBinding
) -> InputEvent:
	if _remap_config != null and _remap_config.has_binding(context_id, action_id, binding_index):
		return _remap_config.get_bound_event_or_null(context_id, action_id, binding_index)
	return binding.input_event


func _make_binding_key(context_id: StringName, action_id: StringName, binding_index: int) -> String:
	return _make_compound_key(["binding", context_id, action_id, binding_index])


func _make_player_binding_key(player_index: int, binding_key: String) -> String:
	return _make_compound_key(["player_binding", player_index, binding_key])


func _register_player_binding_metadata(key: String, player_index: int, binding_key: String) -> void:
	_player_binding_metadata[key] = {
		"player_index": player_index,
		"binding_key": binding_key,
	}


func _make_virtual_binding_key(source_id: StringName, action_id: StringName, player_index: int = -1) -> String:
	return _make_compound_key(["virtual", source_id, player_index, action_id])


func _make_source_binding_key(binding_key: String, event: InputEvent) -> String:
	return _make_compound_key(["source_binding", binding_key, _make_event_source_key(event)])


func _make_player_action_key(player_index: int, action_id: StringName) -> String:
	return _make_compound_key(["player_action", player_index, action_id])


func _register_player_action_metadata(key: String, player_index: int, action_id: StringName) -> void:
	_player_action_metadata[key] = {
		"player_index": player_index,
		"action_id": action_id,
	}


func _get_player_source_binding_key(player_binding_key: String) -> String:
	return GFVariantData.get_option_string(_get_player_binding_metadata(player_binding_key), "binding_key")


func _get_player_index_from_binding_key(player_binding_key: String) -> int:
	return GFVariantData.get_option_int(_get_player_binding_metadata(player_binding_key), "player_index", -1)


func _get_player_index_from_action_key(player_action_key: String) -> int:
	return GFVariantData.get_option_int(_get_player_action_metadata(player_action_key), "player_index", -1)


func _get_player_action_id_from_key(player_action_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_get_player_action_metadata(player_action_key), "action_id")


func _get_player_binding_metadata(player_binding_key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(_player_binding_metadata, player_binding_key)


func _get_player_action_metadata(player_action_key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(_player_action_metadata, player_action_key)


func _is_virtual_binding_key_for_source(binding_key: String, source_id: StringName) -> bool:
	var parts: PackedStringArray = _decode_compound_key(binding_key)
	return (
		parts.size() == 4
		and _compound_key_part_equals(parts, 0, "virtual")
		and _compound_key_part_equals(parts, 1, source_id)
	)


func _make_compound_key(parts: Array) -> String:
	var segments: PackedStringArray = PackedStringArray()
	var _prefix_appended: bool = segments.append(_INPUT_KEY_SCHEMA_PREFIX)
	for part: Variant in parts:
		var token: String = _make_key_part_token(part)
		if token.is_empty():
			return ""
		var _segment_appended: bool = segments.append("%d:%s" % [token.length(), token])
	return "|".join(segments)


func _decode_compound_key(key: String) -> PackedStringArray:
	var prefix: String = "%s|" % _INPUT_KEY_SCHEMA_PREFIX
	if not key.begins_with(prefix):
		return PackedStringArray()

	var parts: PackedStringArray = PackedStringArray()
	var cursor: int = prefix.length()
	while cursor < key.length():
		var separator_index: int = key.find(":", cursor)
		if separator_index < 0:
			return PackedStringArray()
		var length_text: String = key.substr(cursor, separator_index - cursor)
		if length_text.is_empty() or not length_text.is_valid_int():
			return PackedStringArray()
		var token_length: int = int(length_text)
		var token_start: int = separator_index + 1
		var token_end: int = token_start + token_length
		if token_length < 0 or token_end > key.length():
			return PackedStringArray()
		var _part_appended: bool = parts.append(key.substr(token_start, token_length))
		cursor = token_end
		if cursor == key.length():
			break
		if key.substr(cursor, 1) != "|":
			return PackedStringArray()
		cursor += 1
	return parts


func _compound_key_part_equals(parts: PackedStringArray, index: int, value: Variant) -> bool:
	if index < 0 or index >= parts.size():
		return false
	var token: String = _make_key_part_token(value)
	return not token.is_empty() and parts[index] == token


func _make_key_part_token(value: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(value)


func _coerce_virtual_value_to_vector(value: Variant, value_type: GFInputAction.ValueType) -> Vector3:
	if value == null:
		return Vector3.ZERO

	match value_type:
		GFInputAction.ValueType.BOOL:
			if value is bool:
				return Vector3(1.0 if GFVariantData.to_bool(value) else 0.0, 0.0, 0.0)
			if value is Vector2:
				return Vector3(1.0 if GFVariantData.to_vector2(value).length() > 0.0 else 0.0, 0.0, 0.0)
			if value is Vector3:
				return Vector3(1.0 if GFVariantData.to_vector3(value).length() > 0.0 else 0.0, 0.0, 0.0)
			return Vector3(1.0 if absf(GFVariantData.to_float(value)) > 0.0 else 0.0, 0.0, 0.0)
		GFInputAction.ValueType.AXIS_1D:
			if value is Vector2:
				var vector2_value: Vector2 = value
				return Vector3(vector2_value.x, 0.0, 0.0)
			if value is Vector3:
				var vector3_value: Vector3 = value
				return Vector3(vector3_value.x, 0.0, 0.0)
			return Vector3(clampf(GFVariantData.to_float(value), -1.0, 1.0), 0.0, 0.0)
		GFInputAction.ValueType.AXIS_2D:
			if value is Vector2:
				var vector2_value: Vector2 = value
				return Vector3(vector2_value.x, vector2_value.y, 0.0)
			if value is Vector3:
				var vector3_value: Vector3 = value
				return Vector3(vector3_value.x, vector3_value.y, 0.0)
			return Vector3(clampf(GFVariantData.to_float(value), -1.0, 1.0), 0.0, 0.0)
		GFInputAction.ValueType.AXIS_3D:
			if value is Vector3:
				return value
			if value is Vector2:
				var vector2_value: Vector2 = value
				return Vector3(vector2_value.x, vector2_value.y, 0.0)
			return Vector3(clampf(GFVariantData.to_float(value), -1.0, 1.0), 0.0, 0.0)
	return Vector3.ZERO


func _advance_active_durations(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if safe_delta <= 0.0:
		return

	for action_id: StringName in _action_active.keys():
		if _get_action_active(action_id):
			_action_active_elapsed[action_id] = _get_action_active_elapsed(action_id) + safe_delta

	for player_action_key: String in _player_action_active.keys():
		if _get_player_action_active_by_key(player_action_key):
			_player_action_active_elapsed[player_action_key] = (
				_get_player_action_active_elapsed(player_action_key) + safe_delta
			)


func _should_ignore_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.echo
	return false


func _make_event_source_key(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "joypad:%d" % event.device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d" % event.device
	return "keyboard_mouse"


func _refresh_player_action_state(
	player_index: int,
	action_id: StringName,
	action: GFInputAction
) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	var previous_value: Variant = _get_player_action_value_or_default(key, action.value_type)
	var previous_active: bool = _get_player_action_active_by_key(key)
	var next_value: Variant = _calculate_player_action_value(player_index, action_id, action.value_type)
	var raw_active: bool = _is_value_active(next_value, action)
	var next_active: bool = _evaluate_player_action_triggers(player_index, action_id, raw_active, next_value, 0.0)

	_player_action_values[key] = next_value
	_player_action_active[key] = next_active
	_player_raw_action_active[key] = raw_active

	if not _values_equal(previous_value, next_value):
		player_action_value_changed.emit(player_index, action_id, next_value)

	if not previous_active and next_active:
		_mark_player_action_just_started(player_index, action_id)
		_player_action_active_elapsed[key] = 0.0
		player_action_started.emit(player_index, action_id, next_value)
	elif previous_active and not next_active:
		_mark_player_action_just_completed(player_index, action_id)
		_player_last_completed_duration[key] = _get_player_action_active_elapsed(key)
		_erase_dictionary_key(_player_action_active_elapsed, key)
		player_action_completed.emit(player_index, action_id, next_value)


func _resolve_player_index(event: InputEvent) -> int:
	var devices: GFInputDeviceUtility = _get_input_device_utility()
	if devices == null:
		return -1
	return devices.handle_input_event(event)


func _input_event_requires_device_assignment(event: InputEvent) -> bool:
	if _get_input_device_utility() == null:
		return false
	return (
		event is InputEventKey
		or event is InputEventMouse
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventJoypadButton
		or event is InputEventJoypadMotion
	)


func _get_player_deadzone(player_index: int) -> float:
	if player_index < 0:
		return -1.0

	var devices: GFInputDeviceUtility = _get_input_device_utility()
	if devices == null:
		return -1.0
	return devices.get_player_deadzone(player_index, -1.0)


func _refresh_triggered_action_states(delta: float) -> void:
	if _action_triggers.is_empty():
		return

	for action_id_variant: Variant in _action_triggers.keys():
		var action_id: StringName = GFVariantData.to_string_name(action_id_variant)
		var triggers: Array = _get_action_triggers(action_id)
		if triggers.is_empty():
			continue
		var action: GFInputAction = _get_registered_action(action_id)
		if action == null:
			continue
		var value: Variant = _get_action_value_or_default(action_id, action.value_type)
		var raw_active: bool = _get_raw_action_active(action_id)
		_set_action_active_from_triggers(action_id, action, value, raw_active, delta)

	for player_key_variant: Variant in _player_raw_action_active.keys():
		var player_key: String = GFVariantData.to_text(player_key_variant)
		var player_index: int = _get_player_index_from_action_key(player_key)
		var action_id: StringName = _get_player_action_id_from_key(player_key)
		if player_index < 0 or action_id == &"":
			continue
		var action: GFInputAction = _get_registered_action(action_id)
		if action == null:
			continue
		var value: Variant = _get_player_action_value_or_default(player_key, action.value_type)
		var raw_active: bool = _get_player_raw_action_active(player_key)
		_set_player_action_active_from_triggers(player_index, action_id, action, value, raw_active, delta)


func _set_action_active_from_triggers(
	action_id: StringName,
	action: GFInputAction,
	value: Variant,
	raw_active: bool,
	delta: float
) -> void:
	var previous_active: bool = _get_action_active(action_id)
	var next_active: bool = _evaluate_action_triggers(action_id, raw_active, value, delta)
	_action_active[action_id] = next_active
	if not previous_active and next_active:
		_mark_action_just_started(action_id)
		_action_active_elapsed[action_id] = 0.0
		action_started.emit(action_id, value)
	elif previous_active and not next_active:
		_mark_action_just_completed(action_id)
		_last_completed_duration[action_id] = _get_action_active_elapsed(action_id)
		_erase_dictionary_key(_action_active_elapsed, action_id)
		action_completed.emit(action_id, _default_value_for_type(action.value_type))


func _set_player_action_active_from_triggers(
	player_index: int,
	action_id: StringName,
	action: GFInputAction,
	value: Variant,
	raw_active: bool,
	delta: float
) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	var previous_active: bool = _get_player_action_active_by_key(key)
	var next_active: bool = _evaluate_player_action_triggers(player_index, action_id, raw_active, value, delta)
	_player_action_active[key] = next_active
	if not previous_active and next_active:
		_mark_player_action_just_started(player_index, action_id)
		_player_action_active_elapsed[key] = 0.0
		player_action_started.emit(player_index, action_id, value)
	elif previous_active and not next_active:
		_mark_player_action_just_completed(player_index, action_id)
		_player_last_completed_duration[key] = _get_player_action_active_elapsed(key)
		_erase_dictionary_key(_player_action_active_elapsed, key)
		player_action_completed.emit(player_index, action_id, _default_value_for_type(action.value_type))


func _evaluate_action_triggers(
	action_id: StringName,
	raw_active: bool,
	value: Variant,
	delta: float
) -> bool:
	return _evaluate_triggers(
		action_id,
		-1,
		_get_action_triggers(action_id),
		_get_action_trigger_states(action_id),
		raw_active,
		value,
		delta
	)


func _evaluate_player_action_triggers(
	player_index: int,
	action_id: StringName,
	raw_active: bool,
	value: Variant,
	delta: float
) -> bool:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	return _evaluate_triggers(
		action_id,
		player_index,
		_get_action_triggers(action_id),
		_get_player_trigger_states(key),
		raw_active,
		value,
		delta
	)


func _evaluate_triggers(
	action_id: StringName,
	player_index: int,
	triggers: Array,
	states: Array,
	raw_active: bool,
	value: Variant,
	delta: float
) -> bool:
	if triggers.is_empty():
		return raw_active

	var any_ongoing: bool = false
	for index: int in range(triggers.size()):
		var trigger: GFInputTrigger = _get_input_trigger_value(triggers[index])
		if trigger == null:
			continue
		while states.size() <= index:
			_append_array_value(states, {})
		var state: Dictionary = GFVariantData.as_dictionary(states[index])
		trigger.prepare_runtime(action_id, self, player_index, state)
		var trigger_state: int = trigger.update(raw_active, value, delta, state)
		if trigger_state == GFInputTrigger.TriggerState.INACTIVE:
			return false
		if trigger_state == GFInputTrigger.TriggerState.ONGOING:
			any_ongoing = true

	return not any_ongoing


func _get_action_trigger_states(action_id: StringName) -> Array:
	if not _action_trigger_states.has(action_id):
		var states: Array = []
		_action_trigger_states[action_id] = states
	return GFVariantData.as_array(_action_trigger_states[action_id])


func _get_player_trigger_states(player_action_key: String) -> Array:
	if not _player_trigger_states.has(player_action_key):
		var states: Array = []
		_player_trigger_states[player_action_key] = states
	return GFVariantData.as_array(_player_trigger_states[player_action_key])


func _reset_all_trigger_states() -> void:
	_action_trigger_states.clear()
	_player_trigger_states.clear()


func _apply_mapping_modifiers(action_id: StringName, value: Vector3) -> Vector3:
	var modifiers: Array = _get_action_modifiers(action_id)
	var action: GFInputAction = _get_registered_action(action_id)
	var result: Vector3 = value
	for modifier: GFInputModifier in modifiers:
		if modifier != null:
			if action != null and action.value_type == GFInputAction.ValueType.AXIS_3D:
				result = modifier.modify_3d(result, null, action)
			else:
				var modified: Vector2 = modifier.modify(Vector2(result.x, result.y), null, action)
				result = Vector3(modified.x, modified.y, result.z)
	return result


func _duplicate_modifiers(modifiers: Array[GFInputModifier]) -> Array[GFInputModifier]:
	var result: Array[GFInputModifier] = []
	for modifier: GFInputModifier in modifiers:
		if modifier == null:
			continue
		var duplicate_modifier: GFInputModifier = modifier.duplicate_modifier()
		if duplicate_modifier != null:
			_append_array_value(result, duplicate_modifier)
	return result


func _duplicate_triggers(triggers: Array[GFInputTrigger]) -> Array[GFInputTrigger]:
	var result: Array[GFInputTrigger] = []
	for trigger: GFInputTrigger in triggers:
		if trigger == null:
			continue
		_append_array_value(result, trigger)
	return result


func _bind_input_device_utility() -> void:
	var devices: GFInputDeviceUtility = _get_input_device_utility()
	if devices == _input_devices:
		return

	_unbind_input_device_utility()
	_input_devices = devices
	if _input_devices == null:
		return
	if not _input_devices.assignment_event_recorded.is_connected(_on_input_assignment_event_recorded):
		var _connect_result: int = _input_devices.assignment_event_recorded.connect(_on_input_assignment_event_recorded)


func _unbind_input_device_utility() -> void:
	if _input_devices == null:
		return
	if _input_devices.assignment_event_recorded.is_connected(_on_input_assignment_event_recorded):
		_input_devices.assignment_event_recorded.disconnect(_on_input_assignment_event_recorded)
	_input_devices = null


func _on_input_assignment_event_recorded(event_record: Dictionary) -> void:
	var event_type: StringName = GFVariantData.get_option_string_name(event_record, "event_type")
	match event_type:
		&"assignment_removed":
			_clear_player_state_from_assignment_record(
				GFVariantData.get_option_dictionary(event_record, "previous_assignment")
			)
		&"assignment_set":
			_clear_player_state_from_assignment_record(
				GFVariantData.get_option_dictionary(event_record, "previous_assignment")
			)
			_clear_displaced_player_states(GFVariantData.get_option_dictionary(event_record, "metadata"))
			_clear_player_state_from_assignment_record(
				GFVariantData.get_option_dictionary(event_record, "assignment")
			)
		&"assignments_cleared", &"assignments_refreshed":
			clear_input_state()


func _clear_player_state_from_assignment_record(record: Dictionary) -> void:
	if record.is_empty():
		return
	var player_index: int = GFVariantData.get_option_int(record, "player_index", -1)
	if player_index < 0:
		return
	_clear_player_runtime_state(player_index, true)


func _clear_displaced_player_states(metadata: Dictionary) -> void:
	var displaced_players: Array = GFVariantData.get_option_array(metadata, "displaced_player_indices")
	for player_value: Variant in displaced_players:
		var player_index: int = GFVariantData.to_int(player_value, -1)
		if player_index >= 0:
			_clear_player_runtime_state(player_index, true)


func _get_input_device_utility() -> GFInputDeviceUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null
	return _get_input_device_utility_value(arch.get_utility(GFInputDeviceUtility))


# --- 内部类 ---

class _GFInputRouter extends Node:
	var _input_callback: Callable
	var _focus_lost_callback: Callable

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode


	func _input(event: InputEvent) -> void:
		if _input_callback.is_valid():
			_input_callback.call(event)


	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _focus_lost_callback.is_valid():
			_focus_lost_callback.call()
