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

## 提供复合输入键各部分的稳定编码。
## [br]
## @api private
## [br]
const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")

## 输入映射复合键当前使用的格式版本前缀。
## [br]
## @api private
## [br]
const _INPUT_KEY_SCHEMA_PREFIX: String = "gf_input_key_v1"


# --- 公共变量 ---

## 是否由内部全局节点自动接收 Godot 输入和应用失焦通知，默认启用。
## 关闭后仍须正常初始化；调用方负责 handle_input_event、tick 和失焦时 clear_input_state。
## 初始化后切换会立即停止旧路由、清理输入状态并保留已启用上下文。
## [br]
## @api public
## [br]
## @since unreleased
var automatic_input_routing: bool = true:
	set(value):
		if automatic_input_routing == value:
			return
		automatic_input_routing = value
		if not _is_initialized:
			return
		_dispatch_epoch += 1
		_release_router()
		_clear_runtime_state(true, &"input_routing_changed")
		_ensure_router()


# --- 私有变量 ---

## 记录 init/dispose 之间的路由生命周期；配置 setter 不得在未初始化或已释放时挂载节点。
## [br]
## @api private
var _is_initialized: bool = false

## 已启用上下文到优先级和激活时间戳的映射。
## [br]
## @api private
## [br]
var _active_contexts: Dictionary = {}

## 按有效上下文顺序构建的运行时映射条目。
## [br]
## @api private
## [br]
var _effective_entries: Array[Dictionary] = []

## 全局绑定键到当前 Vector3 输入贡献的映射。
## [br]
## @api private
## [br]
var _binding_values: Dictionary = {}

## 全局绑定键到动作标识的映射。
## [br]
## @api private
## [br]
var _binding_to_action: Dictionary = {}

## 有玩家归属的全局绑定键到玩家索引的映射。
## [br]
## @api private
## [br]
var _binding_player_indices: Dictionary = {}

## 玩家作用域绑定键到输入贡献的映射。
## [br]
## @api private
## [br]
var _player_binding_values: Dictionary = {}

## 玩家作用域绑定键到动作标识的映射。
## [br]
## @api private
## [br]
var _player_binding_to_action: Dictionary = {}

## 玩家绑定键关联的玩家索引和全局绑定键。
## [br]
## @api private
## [br]
var _player_binding_metadata: Dictionary = {}

## 当前有效动作标识到动作资源的映射。
## [br]
## @api private
## [br]
var _actions: Dictionary = {}

## 当前有效动作的修饰器列表。
## [br]
## @api private
## [br]
var _action_modifiers: Dictionary = {}

## 当前有效动作的触发器列表。
## [br]
## @api private
## [br]
var _action_triggers: Dictionary = {}

## 全局动作触发器各自的运行时状态列表。
## [br]
## @api private
## [br]
var _action_trigger_states: Dictionary = {}

## 当前全局动作值。
## [br]
## @api private
## [br]
var _action_values: Dictionary = {}

## 经触发器评估后的全局动作活跃状态。
## [br]
## @api private
## [br]
var _action_active: Dictionary = {}

## 触发器评估前按阈值计算的全局原始活跃状态。
## [br]
## @api private
## [br]
var _raw_action_active: Dictionary = {}

## 当前帧内全局动作刚开始的标记。
## [br]
## @api private
## [br]
var _just_started: Dictionary = {}

## 当前帧内全局动作刚完成的标记。
## [br]
## @api private
## [br]
var _just_completed: Dictionary = {}

## 全局动作 started/completed 边沿的最近修订号。
## [br]
## @api private
## [br]
var _action_edge_revisions: Dictionary = {}

## 玩家动作 started/completed 边沿的最近修订号。
## [br]
## @api private
## [br]
var _player_action_edge_revisions: Dictionary = {}

## 为全局和玩家动作边沿分配的递增修订号。
## [br]
## @api private
## [br]
var _next_action_edge_revision: int = 0

## 全局动作当前连续活跃时长。
## [br]
## @api private
## [br]
var _action_active_elapsed: Dictionary = {}

## 全局动作最近一次完成时保存的活跃时长。
## [br]
## @api private
## [br]
var _last_completed_duration: Dictionary = {}

## 当前玩家作用域动作值。
## [br]
## @api private
## [br]
var _player_action_values: Dictionary = {}

## 经触发器评估后的玩家动作活跃状态。
## [br]
## @api private
## [br]
var _player_action_active: Dictionary = {}

## 触发器评估前按阈值计算的玩家原始活跃状态。
## [br]
## @api private
## [br]
var _player_raw_action_active: Dictionary = {}

## 玩家动作键关联的玩家索引和动作标识。
## [br]
## @api private
## [br]
var _player_action_metadata: Dictionary = {}

## 玩家动作各触发器的运行时状态列表。
## [br]
## @api private
## [br]
var _player_trigger_states: Dictionary = {}

## 当前帧内玩家动作刚开始的标记。
## [br]
## @api private
## [br]
var _player_just_started: Dictionary = {}

## 当前帧内玩家动作刚完成的标记。
## [br]
## @api private
## [br]
var _player_just_completed: Dictionary = {}

## 玩家动作当前连续活跃时长。
## [br]
## @api private
## [br]
var _player_action_active_elapsed: Dictionary = {}

## 玩家动作最近一次完成时保存的活跃时长。
## [br]
## @api private
## [br]
var _player_last_completed_duration: Dictionary = {}

## 当前采用的可选动作重映射配置。
## [br]
## @api private
## [br]
var _remap_config: GFInputRemapConfig

## 为启用上下文记录激活先后顺序的时间戳计数器。
## [br]
## @api private
## [br]
var _timestamp: int = 0

## 接收输入和窗口焦点通知的内部路由节点。
## [br]
## @api private
## [br]
var _router: _GFInputRouter

## 用于拒绝过期的延迟路由节点挂载请求的序号。
## [br]
## @api private
## [br]
var _router_attach_serial: int = 0

## 当前订阅的输入设备分配工具。
## [br]
## @api private
## [br]
var _input_devices: GFInputDeviceUtility = null

## 是否已排队清除本帧瞬态 started/completed 标记。
## [br]
## @api private
## [br]
var _clear_transient_input_state_queued: bool = false

## 排队清除瞬态状态时记录的引擎帧号。
## [br]
## @api private
## [br]
var _transient_input_state_mark_frame: int = -1

## 输入分发代际；重入回调导致状态重建时使旧分发停止。
## [br]
## @api private
## [br]
var _dispatch_epoch: int = 0

## 虚拟脉冲绑定键到租约记录的映射。
## [br]
## @api private
## [br]
var _virtual_pulse_leases: Dictionary = {}

## 正在修改虚拟脉冲绑定键的重入保护标记。
## [br]
## @api private
## [br]
var _virtual_pulse_mutation_keys: Dictionary = {}

## 批量虚拟脉冲修改的嵌套深度。
## [br]
## @api private
## [br]
var _virtual_pulse_bulk_mutation_depth: int = 0

## 下一个虚拟脉冲租约 ID，从 1 起分配。
## [br]
## @api private
## [br]
var _next_virtual_pulse_lease_id: int = 1


# --- GF 生命周期方法 ---

## 初始化输入映射运行时状态；启用 automatic_input_routing 时挂载输入路由节点。
## [br]
## @api public
## [br]
## @since 3.17.0
func init() -> void:
	_dispatch_epoch += 1
	_is_initialized = true
	ignore_pause = true
	ignore_time_scale = true
	_clear_runtime_state(false, &"mapping_initialized")
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
	_dispatch_epoch += 1
	_is_initialized = false
	_release_router()
	_unbind_input_device_utility()
	_active_contexts.clear()
	_effective_entries.clear()
	_clear_runtime_state(false, &"mapping_disposed")


## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	_bind_input_device_utility()
	_prune_virtual_pulse_leases()
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
		push_error("[GFInputMappingUtility][input_mapping_utility.context_null] Cannot enable_context: context is null.")
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
	var dispatch_epoch: int = _dispatch_epoch
	var event_blocked: bool = false
	for entry: Dictionary in _effective_entries:
		if dispatch_epoch != _dispatch_epoch:
			return
		if event_blocked:
			break

		var matched: bool = _apply_entry_event(entry, event, player_index)
		if dispatch_epoch != _dispatch_epoch:
			return
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
			if dispatch_epoch != _dispatch_epoch:
				return
		if player_index >= 0 and is_action_active_for_player(player_index, action_id):
			player_action_triggered.emit(player_index, action_id, get_action_value_for_player(player_index, action_id))


## 创建可编程虚拟输入源。
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @param player_index: 玩家索引；小于 0 时只写入全局动作状态。
## [br]
## @param timer_utility: 可选的虚拟脉冲定时器注入。
## [br]
## @return: 虚拟输入源。
## [br]
## @api public
## [br]
## @since 3.17.0
func create_virtual_source(
	source_id: StringName = &"virtual",
	player_index: int = -1,
	timer_utility: GFTimerUtility = null
) -> GFVirtualInputSource:
	return GFVirtualInputSource.new(self, source_id, player_index, timer_utility)


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
## @return: 写入成功返回 true；非有限数值会被拒绝并保持旧贡献不变。
## [br]
## @api public
## [br]
## @since 2.6.0
## [br]
## @schema value: Variant，要转换为动作运行时向量贡献的 bool、float、Vector2 或 Vector3 值。
func set_virtual_action_value(
	action_id: StringName,
	value: Variant,
	source_id: StringName = &"virtual",
	player_index: int = -1
) -> bool:
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var binding_key: String = _make_virtual_binding_key(source_key, action_id, player_index)
	if (
		_get_registered_action(action_id) == null
		or not _is_virtual_value_finite(value)
		or _virtual_pulse_bulk_mutation_depth > 0
		or _virtual_pulse_mutation_keys.has(binding_key)
	):
		return false
	_virtual_pulse_mutation_keys[binding_key] = true
	var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
	var operation: GFVirtualInputPulseOperation = _get_virtual_pulse_operation(lease_record)
	var lease_removed: bool = lease_record.is_empty()
	if not lease_record.is_empty():
		lease_removed = _remove_virtual_pulse_lease_record(binding_key, lease_record)
	if not lease_removed:
		_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
		return false
	var written: bool = _set_virtual_action_value_raw(
		action_id,
		value,
		source_key,
		player_index
	)
	var released_after_failure: bool = false
	if not written and not lease_record.is_empty():
		var _cleared_failed_override: bool = _clear_virtual_action_raw(
			action_id,
			source_key,
			player_index
		)
		released_after_failure = true
	if operation != null and operation.is_pending():
		var _finished_overridden_pulse: bool = operation.finish_from_mapping_for_framework(
			GFVirtualInputPulseOperation.Status.CANCELLED,
			&"manual_write" if written else &"manual_write_failed",
			released_after_failure
		)
	_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
	return written


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
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var binding_key: String = _make_virtual_binding_key(source_key, action_id, player_index)
	if _virtual_pulse_bulk_mutation_depth > 0 or _virtual_pulse_mutation_keys.has(binding_key):
		return false
	_virtual_pulse_mutation_keys[binding_key] = true
	var terminated_pulse: bool = _terminate_virtual_pulse_lease_by_key(
		binding_key,
		GFVirtualInputPulseOperation.Status.CANCELLED,
		&"manual_clear"
	)
	var changed: bool = false
	if not terminated_pulse:
		changed = _clear_virtual_action_raw(action_id, source_key, player_index)
	_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
	return terminated_pulse or changed


## 清除指定虚拟输入源的所有动作贡献。
## [br]
## @api public
## [br]
## @param source_id: 虚拟输入源标识。
func clear_virtual_source(source_id: StringName = &"virtual") -> void:
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	_virtual_pulse_bulk_mutation_depth += 1
	_terminate_virtual_pulse_leases_for_source(source_key, &"source_cleared")
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
			var dispatch_epoch: int = _dispatch_epoch
			_refresh_action_state(action_id, action)
			if dispatch_epoch != _dispatch_epoch:
				_virtual_pulse_bulk_mutation_depth = maxi(
					_virtual_pulse_bulk_mutation_depth - 1,
					0
				)
				return

	for entry: Dictionary in affected_player_actions.values():
		var action_id: StringName = _get_entry_action_id(entry)
		var action: GFInputAction = _get_registered_action(action_id)
		if action != null:
			var dispatch_epoch: int = _dispatch_epoch
			_refresh_player_action_state(_get_entry_player_index(entry), action_id, action)
			if dispatch_epoch != _dispatch_epoch:
				_virtual_pulse_bulk_mutation_depth = maxi(
					_virtual_pulse_bulk_mutation_depth - 1,
					0
				)
				return
	_virtual_pulse_bulk_mutation_depth = maxi(_virtual_pulse_bulk_mutation_depth - 1, 0)


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


## 获取指定虚拟输入源与玩家身份的状态快照。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_id: 虚拟输入源标识。
## [br]
## @param player_index: 玩家索引；小于 0 时读取仅全局身份。
## [br]
## @return: 玩家作用域快照字典。
## [br]
## @schema return: Dictionary，包含 source_id、player_index 和 actions: Array[Dictionary]，action 条目包含 action_id 与 value。
func get_virtual_source_snapshot_for_player(
	source_id: StringName = &"virtual",
	player_index: int = -1
) -> Dictionary:
	var source_key: StringName = source_id if source_id != &"" else &"virtual"
	var actions: Array[Dictionary] = []
	for key: String in _binding_to_action.keys():
		if (
			_is_virtual_binding_key_for_source(key, source_key)
			and _get_binding_player_index(key) == player_index
		):
			_append_array_value(actions, {
				"action_id": _binding_to_action[key],
				"value": _get_binding_vector_value(key),
			})

	return {
		"source_id": source_key,
		"player_index": player_index,
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
	_dispatch_epoch += 1
	_clear_runtime_state(true, &"input_state_cleared")


## 清空指定玩家动作运行时状态。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
func clear_player_input_state(player_index: int) -> void:
	_dispatch_epoch += 1
	_clear_player_runtime_state(player_index, true)


# --- 框架内部方法 ---

## 返回动作最近一次指定边沿的单调版本，供序列避免重复消费观察窗口中的同一边沿。
## [br]
## @api framework_internal
## [br]
## @layer standard/input
## [br]
## @since 11.0.0
## [br]
## @param action_id: 动作标识。
## [br]
## @param player_index: 玩家索引；负数查询全局时间线。
## [br]
## @param completed: true 查询完成边沿，false 查询开始边沿。
## [br]
## @return 指定边沿版本；尚未发生返回 0。
func get_action_edge_revision_for_framework(
	action_id: StringName,
	player_index: int = -1,
	completed: bool = false
) -> int:
	var revisions: Dictionary = {}
	if player_index >= 0:
		var player_key: String = _make_player_action_key(player_index, action_id)
		revisions = GFVariantData.get_option_dictionary(_player_action_edge_revisions, player_key)
	else:
		revisions = GFVariantData.get_option_dictionary(_action_edge_revisions, action_id)
	return GFVariantData.get_option_int(revisions, "completed" if completed else "started")


## 为类型化虚拟输入脉冲取得稳定输入键的权威 lease 并写入脉冲值。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @layer standard/input
## [br]
## @param operation: 已冻结身份且仍在等待的脉冲句柄。
## [br]
## @param value: 脉冲期间的动作值。
## [br]
## @param replacement_policy: GFVirtualInputSource.PulseReplacementPolicy 枚举值。
## [br]
## @schema value: Variant，动作接受的 bool、float、Vector2 或 Vector3 值。
## [br]
## @return: 当前操作取得 lease 时返回 true；拒绝或失败时返回 false。
func begin_virtual_pulse_lease_for_framework(
	operation: GFVirtualInputPulseOperation,
	value: Variant,
	replacement_policy: GFVirtualInputSource.PulseReplacementPolicy
) -> bool:
	if (
		operation == null
		or not operation.is_pending()
		or not operation.matches_mapping_for_framework(self)
	):
		return false
	var action_id: StringName = operation.get_action_id()
	var source_id: StringName = operation.get_source_id()
	var player_index: int = operation.get_player_index()
	if _get_registered_action(action_id) == null:
		var _failed_action: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"action_not_registered"
		)
		return false
	var binding_key: String = _make_virtual_binding_key(source_id, action_id, player_index)
	if _virtual_pulse_bulk_mutation_depth > 0 or _virtual_pulse_mutation_keys.has(binding_key):
		var _rejected_mutation: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.REJECTED,
			&"input_state_mutation"
		)
		return false

	var previous_record: Dictionary = _get_virtual_pulse_lease(binding_key)
	var previous_operation: GFVirtualInputPulseOperation = _get_virtual_pulse_operation(previous_record)
	var previous_was_pending: bool = (
		previous_operation != null and previous_operation.is_pending()
	)
	if (
		previous_was_pending
		and replacement_policy == GFVirtualInputSource.PulseReplacementPolicy.REJECT_NEW
	):
		var _rejected_existing: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.REJECTED,
			&"pulse_already_active"
		)
		return false

	_virtual_pulse_mutation_keys[binding_key] = true
	var previous_removed: bool = previous_record.is_empty()
	if not previous_record.is_empty():
		previous_removed = _remove_virtual_pulse_lease_record(binding_key, previous_record)
	if not previous_removed:
		_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
		var _failed_conflict: bool = operation.finish_without_lease_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			&"pulse_lease_conflict"
		)
		return false

	var lease_record: Dictionary = _make_virtual_pulse_lease_record(operation)
	_virtual_pulse_leases[binding_key] = lease_record
	if not operation.mark_lease_acquired_for_framework():
		var _removed_unclaimed_lease: bool = _erase_virtual_pulse_lease_if_current(
			binding_key,
			lease_record
		)
		if previous_operation != null and previous_operation.is_pending():
			_virtual_pulse_leases[binding_key] = previous_record
		elif not previous_record.is_empty():
			var _cleared_stale_contribution: bool = _clear_virtual_action_raw(
				action_id,
				source_id,
				player_index
			)
		_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
		return false
	var previous_released: bool = false
	if (
		replacement_policy == GFVirtualInputSource.PulseReplacementPolicy.RETRIGGER
		and not previous_record.is_empty()
	):
		var release_epoch: int = _dispatch_epoch
		previous_released = _clear_virtual_action_raw(action_id, source_id, player_index)
		if (
			release_epoch != _dispatch_epoch
			or not operation.is_pending()
			or not _virtual_pulse_lease_matches_operation(binding_key, operation)
			or previous_was_pending and not previous_operation.is_pending()
		):
			var _aborted_retrigger: bool = _abort_virtual_pulse_lease_admission(
				binding_key,
				lease_record,
				operation,
				&"pulse_lease_conflict"
			)
			if previous_was_pending and previous_operation.is_pending():
				var _finished_previous_after_interruption: bool = (
					previous_operation.finish_from_mapping_for_framework(
						GFVirtualInputPulseOperation.Status.REPLACED,
						&"replaced",
						previous_released
					)
				)
			_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
			return false
	var write_epoch: int = _dispatch_epoch
	var written: bool = _set_virtual_action_value_raw(action_id, value, source_id, player_index)
	if (
		not written
		or write_epoch != _dispatch_epoch
		or not operation.is_pending()
		or not _virtual_pulse_lease_matches_operation(binding_key, operation)
	):
		var _aborted_write: bool = _abort_virtual_pulse_lease_admission(
			binding_key,
			lease_record,
			operation,
			&"pulse_write_failed" if not written else &"pulse_lease_conflict"
		)
		if previous_was_pending and previous_operation.is_pending():
			var _finished_previous_after_failure: bool = previous_operation.finish_from_mapping_for_framework(
				GFVirtualInputPulseOperation.Status.REPLACED,
				&"replaced",
				previous_released
			)
		_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
		return false

	if previous_was_pending:
		var previous_finish_epoch: int = _dispatch_epoch
		var previous_finished: bool = previous_operation.finish_from_mapping_for_framework(
			GFVirtualInputPulseOperation.Status.REPLACED,
			&"replaced",
			previous_released
		)
		if (
			not previous_finished
			or previous_finish_epoch != _dispatch_epoch
			or not operation.is_pending()
			or not _virtual_pulse_lease_matches_operation(binding_key, operation)
		):
			var _aborted_after_previous: bool = _abort_virtual_pulse_lease_admission(
				binding_key,
				lease_record,
				operation,
				&"pulse_lease_conflict"
			)
			_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
			return false
	var lease_is_current: bool = (
		operation.is_pending()
		and _virtual_pulse_lease_matches_operation(binding_key, operation)
	)
	_erase_dictionary_key(_virtual_pulse_mutation_keys, binding_key)
	return lease_is_current


## 结束指定操作仍持有的权威 lease，并只释放匹配 generation 的贡献。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @layer standard/input
## [br]
## @param operation: 请求进入终态的脉冲句柄。
## [br]
## @param status: COMPLETED、CANCELLED、REPLACED 或 FAILED 终态。
## [br]
## @param reason: 稳定终态原因。
## [br]
## @return: 当前句柄仍持有匹配 lease 且已完成释放时返回 true。
func finish_virtual_pulse_lease_for_framework(
	operation: GFVirtualInputPulseOperation,
	status: GFVirtualInputPulseOperation.Status,
	reason: StringName
) -> bool:
	if operation == null or status in [
		GFVirtualInputPulseOperation.Status.PENDING,
		GFVirtualInputPulseOperation.Status.REJECTED,
	]:
		return false
	var binding_key: String = _make_virtual_binding_key(
		operation.get_source_id(),
		operation.get_action_id(),
		operation.get_player_index()
	)
	var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
	if not _virtual_pulse_lease_record_matches_operation(lease_record, operation):
		return false
	var released: bool = _release_virtual_pulse_lease_record(binding_key, lease_record)
	var _finished: bool = operation.finish_from_mapping_for_framework(status, reason, released)
	return true


# --- 私有/辅助方法 ---

## 从字典移除指定键。
## [br]
## @api private
## [br]
func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


## 将一个值追加到目标数组。
## [br]
## @api private
## [br]
func _append_array_value(target: Array, value: Variant) -> void:
	target.append(value)


## 验证并规范化虚拟动作值后写入全局及可选玩家绑定贡献，再刷新对应动作状态。
## 全局刷新触发新的分发代际时会跳过后续玩家刷新。
## [br]
## @api private
## [br]
func _set_virtual_action_value_raw(
	action_id: StringName,
	value: Variant,
	source_id: StringName,
	player_index: int
) -> bool:
	var action: GFInputAction = _get_registered_action(action_id)
	if action == null:
		return false
	if not _is_virtual_value_finite(value):
		return false
	var contribution: Vector3 = _coerce_virtual_value_to_vector(value, action.value_type)
	if not _is_finite_vector3(contribution):
		return false
	contribution = _limit_finite_vector_to_unit_length(contribution)
	var binding_key: String = _make_virtual_binding_key(source_id, action_id, player_index)
	_binding_values[binding_key] = contribution
	_binding_to_action[binding_key] = action_id
	if player_index >= 0:
		_binding_player_indices[binding_key] = player_index
	else:
		_erase_dictionary_key(_binding_player_indices, binding_key)
	if player_index >= 0:
		var player_binding_key: String = _make_player_binding_key(player_index, binding_key)
		_register_player_binding_metadata(player_binding_key, player_index, binding_key)
		_player_binding_values[player_binding_key] = contribution
		_player_binding_to_action[player_binding_key] = action_id

	var dispatch_epoch: int = _dispatch_epoch
	_refresh_action_state(action_id, action)
	if dispatch_epoch != _dispatch_epoch:
		return true
	if player_index >= 0:
		_refresh_player_action_state(player_index, action_id, action)
	return true


## 删除指定虚拟来源、动作和玩家作用域的贡献及索引，并刷新仍注册的动作状态。
## 返回是否存在过待清除贡献。
## [br]
## @api private
## [br]
func _clear_virtual_action_raw(
	action_id: StringName,
	source_id: StringName,
	player_index: int
) -> bool:
	var binding_key: String = _make_virtual_binding_key(source_id, action_id, player_index)
	var changed: bool = _binding_values.has(binding_key)
	_erase_dictionary_key(_binding_values, binding_key)
	_erase_dictionary_key(_binding_to_action, binding_key)
	_erase_dictionary_key(_binding_player_indices, binding_key)
	if player_index >= 0:
		var player_binding_key: String = _make_player_binding_key(player_index, binding_key)
		changed = _player_binding_values.has(player_binding_key) or changed
		_erase_dictionary_key(_player_binding_values, player_binding_key)
		_erase_dictionary_key(_player_binding_to_action, player_binding_key)
		_erase_dictionary_key(_player_binding_metadata, player_binding_key)

	var action: GFInputAction = _get_registered_action(action_id)
	if action != null:
		var dispatch_epoch: int = _dispatch_epoch
		_refresh_action_state(action_id, action)
		if dispatch_epoch != _dispatch_epoch:
			return changed
		if player_index >= 0:
			_refresh_player_action_state(player_index, action_id, action)
	return changed


## 为虚拟脉冲操作生成租约记录，保存弱引用、实例 ID、代际、来源、玩家和动作标识。
## [br]
## @api private
## [br]
func _make_virtual_pulse_lease_record(operation: GFVirtualInputPulseOperation) -> Dictionary:
	return {
		"lease_id": _take_next_virtual_pulse_lease_id(),
		"operation_ref": weakref(operation),
		"operation_id": operation.get_instance_id(),
		"generation": operation.get_generation(),
		"source_id": operation.get_source_id(),
		"player_index": operation.get_player_index(),
		"action_id": operation.get_action_id(),
	}


## 读取虚拟脉冲租约；对应值不是 Dictionary 时返回空字典。
## [br]
## @api private
## [br]
func _get_virtual_pulse_lease(binding_key: String) -> Dictionary:
	var record_value: Variant = GFVariantData.get_option_value(_virtual_pulse_leases, binding_key)
	if record_value is Dictionary:
		var lease_record: Dictionary = record_value
		return lease_record
	return {}


## 解析租约中的弱引用，并核对操作类型、实例 ID 和代际；引用或身份不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_virtual_pulse_operation(lease_record: Dictionary) -> GFVirtualInputPulseOperation:
	var operation_ref_value: Variant = GFVariantData.get_option_value(lease_record, "operation_ref")
	if not (operation_ref_value is WeakRef):
		return null
	var operation_ref: WeakRef = operation_ref_value
	var operation_value: Variant = operation_ref.get_ref()
	if not (operation_value is GFVirtualInputPulseOperation):
		return null
	var operation: GFVirtualInputPulseOperation = operation_value
	if (
		operation.get_instance_id() != GFVariantData.get_option_int(lease_record, "operation_id", 0)
		or operation.get_generation() != GFVariantData.get_option_int(lease_record, "generation", 0)
	):
		return null
	return operation


## 判断指定绑定键当前租约是否解析为给定操作。
## [br]
## @api private
## [br]
func _virtual_pulse_lease_matches_operation(
	binding_key: String,
	operation: GFVirtualInputPulseOperation
) -> bool:
	return _virtual_pulse_lease_record_matches_operation(
		_get_virtual_pulse_lease(binding_key),
		operation
	)


## 判断租约记录非空且其有效操作与给定操作相同。
## [br]
## @api private
## [br]
func _virtual_pulse_lease_record_matches_operation(
	lease_record: Dictionary,
	operation: GFVirtualInputPulseOperation
) -> bool:
	return (
		not lease_record.is_empty()
		and operation != null
		and _get_virtual_pulse_operation(lease_record) == operation
	)


## 仅当当前记录与传入记录具有相同正租约 ID 和弱引用目标时，才删除绑定键并返回 true。
## [br]
## @api private
## [br]
func _erase_virtual_pulse_lease_if_current(binding_key: String, lease_record: Dictionary) -> bool:
	var current_record: Dictionary = _get_virtual_pulse_lease(binding_key)
	var current_ref: Variant = GFVariantData.get_option_value(current_record, "operation_ref")
	var expected_ref: Variant = GFVariantData.get_option_value(lease_record, "operation_ref")
	if (
		GFVariantData.get_option_int(current_record, "lease_id", 0) <= 0
		or GFVariantData.get_option_int(current_record, "lease_id", 0)
		!= GFVariantData.get_option_int(lease_record, "lease_id", 0)
		or not (current_ref is WeakRef)
		or not (expected_ref is WeakRef)
	):
		return false
	var current_operation_ref: WeakRef = current_ref
	var expected_operation_ref: WeakRef = expected_ref
	if current_operation_ref.get_ref() != expected_operation_ref.get_ref():
		return false
	_erase_dictionary_key(_virtual_pulse_leases, binding_key)
	return true


## 取得当前租约 ID 后递增计数；溢出为非正数时将下一个 ID 重置为 1。
## [br]
## @api private
## [br]
func _take_next_virtual_pulse_lease_id() -> int:
	var lease_id: int = _next_virtual_pulse_lease_id
	_next_virtual_pulse_lease_id += 1
	if _next_virtual_pulse_lease_id <= 0:
		_next_virtual_pulse_lease_id = 1
	return lease_id


## 按绑定键和记录身份条件移除虚拟脉冲租约。
## [br]
## @api private
## [br]
func _remove_virtual_pulse_lease_record(binding_key: String, lease_record: Dictionary) -> bool:
	return _erase_virtual_pulse_lease_if_current(binding_key, lease_record)


## 移除仍匹配的租约后，按记录中的来源、动作和玩家清除对应虚拟输入贡献。
## [br]
## @api private
## [br]
func _release_virtual_pulse_lease_record(binding_key: String, lease_record: Dictionary) -> bool:
	if not _remove_virtual_pulse_lease_record(binding_key, lease_record):
		return false
	var action_id: StringName = GFVariantData.get_option_string_name(lease_record, "action_id")
	var source_id: StringName = GFVariantData.get_option_string_name(lease_record, "source_id")
	var player_index: int = GFVariantData.get_option_int(lease_record, "player_index", -1)
	return _clear_virtual_action_raw(action_id, source_id, player_index)


## 处理租约准入失败：尝试释放本记录，并在操作仍待处理时以 FAILED 和给定原因结束操作。
## 返回贡献释放结果。
## [br]
## @api private
## [br]
func _abort_virtual_pulse_lease_admission(
	binding_key: String,
	lease_record: Dictionary,
	operation: GFVirtualInputPulseOperation,
	reason: StringName
) -> bool:
	var released: bool = _release_virtual_pulse_lease_record(binding_key, lease_record)
	if operation != null and operation.is_pending():
		var _finished: bool = operation.finish_from_mapping_for_framework(
			GFVirtualInputPulseOperation.Status.FAILED,
			reason,
			released
		)
	return released


## 按绑定键读取并终止租约；找到记录时先尝试释放，再结束仍待处理的操作。
## [br]
## @api private
## [br]
func _terminate_virtual_pulse_lease_by_key(
	binding_key: String,
	status: GFVirtualInputPulseOperation.Status,
	reason: StringName
) -> bool:
	var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
	if lease_record.is_empty():
		return false
	var operation: GFVirtualInputPulseOperation = _get_virtual_pulse_operation(lease_record)
	var released: bool = _release_virtual_pulse_lease_record(binding_key, lease_record)
	if operation != null and operation.is_pending():
		var _finished: bool = operation.finish_from_mapping_for_framework(status, reason, released)
	return released


## 遍历当前租约键快照，取消 source_id 匹配的租约。
## [br]
## @api private
## [br]
func _terminate_virtual_pulse_leases_for_source(source_id: StringName, reason: StringName) -> void:
	var binding_keys: Array = _virtual_pulse_leases.keys()
	for binding_key_value: Variant in binding_keys:
		var binding_key: String = GFVariantData.to_text(binding_key_value)
		var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
		if GFVariantData.get_option_string_name(lease_record, "source_id") != source_id:
			continue
		var _terminated: bool = _terminate_virtual_pulse_lease_by_key(
			binding_key,
			GFVirtualInputPulseOperation.Status.CANCELLED,
			reason
		)


## 遍历当前租约键快照，取消 player_index 匹配的租约。
## [br]
## @api private
## [br]
func _terminate_virtual_pulse_leases_for_player(player_index: int, reason: StringName) -> void:
	var binding_keys: Array = _virtual_pulse_leases.keys()
	for binding_key_value: Variant in binding_keys:
		var binding_key: String = GFVariantData.to_text(binding_key_value)
		var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
		if GFVariantData.get_option_int(lease_record, "player_index", -1) != player_index:
			continue
		var _terminated: bool = _terminate_virtual_pulse_lease_by_key(
			binding_key,
			GFVirtualInputPulseOperation.Status.CANCELLED,
			reason
		)


## 遍历当前租约键快照并尝试取消每条租约，随后清空租约字典。
## [br]
## @api private
## [br]
func _terminate_all_virtual_pulse_leases(reason: StringName) -> void:
	var binding_keys: Array = _virtual_pulse_leases.keys()
	for binding_key_value: Variant in binding_keys:
		var binding_key: String = GFVariantData.to_text(binding_key_value)
		var _terminated: bool = _terminate_virtual_pulse_lease_by_key(
			binding_key,
			GFVirtualInputPulseOperation.Status.CANCELLED,
			reason
		)
	_virtual_pulse_leases.clear()


## 检查每条租约对应的操作；操作引用失效或已完成时释放记录，其余操作轮询生命周期。
## [br]
## @api private
## [br]
func _prune_virtual_pulse_leases() -> void:
	var binding_keys: Array = _virtual_pulse_leases.keys()
	for binding_key_value: Variant in binding_keys:
		var binding_key: String = GFVariantData.to_text(binding_key_value)
		var lease_record: Dictionary = _get_virtual_pulse_lease(binding_key)
		if lease_record.is_empty():
			continue
		var operation: GFVirtualInputPulseOperation = _get_virtual_pulse_operation(lease_record)
		if operation == null or operation.is_completed():
			var _released_stale: bool = _release_virtual_pulse_lease_record(binding_key, lease_record)
			continue
		var _still_pending: bool = operation.poll_lifecycle_for_framework()


## 将 Variant 收窄为 Node；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_node_value(value: Variant) -> Node:
	if value is Node:
		return value
	return null


## 将 Variant 收窄为 SceneTree；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_scene_tree_value(value: Variant) -> SceneTree:
	if value is SceneTree:
		return value
	return null


## 将 Variant 收窄为 GFInputAction；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_action_value(value: Variant) -> GFInputAction:
	if value is GFInputAction:
		return value
	return null


## 将 Variant 收窄为 GFInputBinding；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_binding_value(value: Variant) -> GFInputBinding:
	if value is GFInputBinding:
		return value
	return null


## 将 Variant 收窄为 GFInputContext；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_context_value(value: Variant) -> GFInputContext:
	if value is GFInputContext:
		return value
	return null


## 将 Variant 收窄为 InputEvent；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_event_value(value: Variant) -> InputEvent:
	if value is InputEvent:
		return value
	return null


## 将 Variant 收窄为 GFInputTrigger；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_trigger_value(value: Variant) -> GFInputTrigger:
	if value is GFInputTrigger:
		return value
	return null


## 将 Variant 收窄为 GFInputDeviceUtility；不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_device_utility_value(value: Variant) -> GFInputDeviceUtility:
	if value is GFInputDeviceUtility:
		return value
	return null


## 按动作标识读取注册动作并收窄类型；不存在或类型不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_registered_action(action_id: StringName) -> GFInputAction:
	return _get_input_action_value(GFVariantData.get_option_value(_actions, action_id))


## 从有效映射条目读取 action 并收窄类型。
## [br]
## @api private
## [br]
func _get_entry_action(entry: Dictionary) -> GFInputAction:
	return _get_input_action_value(GFVariantData.get_option_value(entry, "action"))


## 读取有效映射条目的动作标识。
## [br]
## @api private
## [br]
func _get_entry_action_id(entry: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(entry, "action_id")


## 读取有效映射条目的玩家索引；字段缺失时返回 -1。
## [br]
## @api private
## [br]
func _get_entry_player_index(entry: Dictionary) -> int:
	return GFVariantData.get_option_int(entry, "player_index", -1)


## 读取有效映射条目的绑定信息数组。
## [br]
## @api private
## [br]
func _get_entry_bindings(entry: Dictionary) -> Array:
	return GFVariantData.get_option_array(entry, "bindings")


## 从绑定信息读取 binding 并收窄类型。
## [br]
## @api private
## [br]
func _get_binding_info_binding(binding_info: Dictionary) -> GFInputBinding:
	return _get_input_binding_value(GFVariantData.get_option_value(binding_info, "binding"))


## 读取绑定信息中的复合键字符串。
## [br]
## @api private
## [br]
func _get_binding_info_key(binding_info: Dictionary) -> String:
	return GFVariantData.get_option_string(binding_info, "key")


## 读取上下文在 _active_contexts 中保存的元数据。
## [br]
## @api private
## [br]
func _get_context_meta(context: GFInputContext) -> Dictionary:
	return GFVariantData.get_option_dictionary(_active_contexts, context)


## 读取上下文元数据中的优先级。
## [br]
## @api private
## [br]
func _get_context_priority(context_meta: Dictionary) -> int:
	return GFVariantData.get_option_int(context_meta, "priority")


## 读取上下文元数据中的激活时间戳。
## [br]
## @api private
## [br]
func _get_context_timestamp(context_meta: Dictionary) -> int:
	return GFVariantData.get_option_int(context_meta, "timestamp")


## 读取绑定贡献向量；键缺失时返回零向量。
## [br]
## @api private
## [br]
func _get_binding_vector_value(binding_key: String) -> Vector3:
	return GFVariantData.get_option_vector3(_binding_values, binding_key, Vector3.ZERO)


## 读取绑定对应的动作标识。
## [br]
## @api private
## [br]
func _get_binding_action_id(binding_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_binding_to_action, binding_key)


## 读取绑定对应的玩家索引；没有玩家映射时返回 -1。
## [br]
## @api private
## [br]
func _get_binding_player_index(binding_key: String) -> int:
	return GFVariantData.get_option_int(_binding_player_indices, binding_key, -1)


## 读取玩家作用域绑定对应的动作标识。
## [br]
## @api private
## [br]
func _get_player_binding_action_id(binding_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_player_binding_to_action, binding_key)


## 读取全局动作是否活跃。
## [br]
## @api private
## [br]
func _get_action_active(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_action_active, action_id)


## 读取全局动作当前活跃时长。
## [br]
## @api private
## [br]
func _get_action_active_elapsed(action_id: StringName) -> float:
	return GFVariantData.get_option_float(_action_active_elapsed, action_id)


## 读取全局动作值；缺失时按值类型生成默认值。
## [br]
## @api private
## [br]
func _get_action_value_or_default(action_id: StringName, value_type: GFInputAction.ValueType) -> Variant:
	return GFVariantData.get_option_value(_action_values, action_id, _default_value_for_type(value_type))


## 读取全局动作阈值判定得到的原始活跃状态。
## [br]
## @api private
## [br]
func _get_raw_action_active(action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(_raw_action_active, action_id)


## 读取全局动作触发器数组。
## [br]
## @api private
## [br]
func _get_action_triggers(action_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_action_triggers, action_id, []))


## 读取全局动作修饰器数组。
## [br]
## @api private
## [br]
func _get_action_modifiers(action_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_action_modifiers, action_id, []))


## 按玩家索引和动作标识读取玩家动作活跃状态。
## [br]
## @api private
## [br]
func _get_player_action_active(player_index: int, action_id: StringName) -> bool:
	return GFVariantData.get_option_bool(
		_player_action_active,
		_make_player_action_key(player_index, action_id)
	)


## 按复合玩家动作键读取活跃状态。
## [br]
## @api private
## [br]
func _get_player_action_active_by_key(player_action_key: String) -> bool:
	return GFVariantData.get_option_bool(_player_action_active, player_action_key)


## 按复合玩家动作键读取当前活跃时长。
## [br]
## @api private
## [br]
func _get_player_action_active_elapsed(player_action_key: String) -> float:
	return GFVariantData.get_option_float(_player_action_active_elapsed, player_action_key)


## 读取玩家动作值；缺失时按值类型生成默认值。
## [br]
## @api private
## [br]
func _get_player_action_value_or_default(player_action_key: String, value_type: GFInputAction.ValueType) -> Variant:
	return GFVariantData.get_option_value(
		_player_action_values,
		player_action_key,
		_default_value_for_type(value_type)
	)


## 读取玩家动作阈值判定得到的原始活跃状态。
## [br]
## @api private
## [br]
func _get_player_raw_action_active(player_action_key: String) -> bool:
	return GFVariantData.get_option_bool(_player_raw_action_active, player_action_key)


## 若主循环可用则创建内部路由节点，设置输入和失焦回调，并以延迟调用请求挂载。
## [br]
## @api private
## [br]
func _ensure_router() -> void:
	if not _is_initialized or not automatic_input_routing or is_instance_valid(_router):
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


## 立即断开旧节点回调并使延迟挂载失效，再排队释放节点；同帧输入不得继续转发。
## [br]
## @api private
func _release_router() -> void:
	_router_attach_serial += 1
	var previous_router: _GFInputRouter = _router
	_router = null
	if not is_instance_valid(previous_router):
		return
	previous_router._input_callback = Callable()
	previous_router._focus_lost_callback = Callable()
	previous_router.set_process_input(false)
	previous_router.queue_free()


## 校验延迟挂载请求的序号、目标路由及节点状态后，将路由节点加入 SceneTree 根节点。
## 若主循环已不可用则释放节点并清空当前路由引用。
## [br]
## @api private
## [br]
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


## 按启用上下文重建有效映射、动作资源、修饰器和触发器；过滤无效数据并应用重映射覆盖。
## 清理旧运行时状态后会发出 contexts_changed，再在代际未变化时发出 mappings_changed。
## [br]
## @api private
## [br]
func _rebuild_effective_entries() -> void:
	_dispatch_epoch += 1
	var rebuild_epoch: int = _dispatch_epoch
	_clear_runtime_state(true, &"mapping_rebuilt")
	if rebuild_epoch != _dispatch_epoch:
		return
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
			if not _action_thresholds_are_valid(mapping.action):
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
	if rebuild_epoch != _dispatch_epoch:
		return
	mappings_changed.emit()


## 按优先级降序、同优先级按最近激活时间戳降序返回有效上下文。
## [br]
## @api private
## [br]
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


## 将匹配映射条目的绑定贡献写入全局及可选玩家状态，并刷新对应动作值。
## 至少一个绑定匹配时返回 true。
## [br]
## @api private
## [br]
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
		var dispatch_epoch: int = _dispatch_epoch
		_refresh_action_state(action_id, action)
		if dispatch_epoch != _dispatch_epoch:
			return true
		if player_index >= 0:
			_refresh_player_action_state(player_index, action_id, action)

	return matched


## 重新计算全局动作值、原始活跃度和触发器结果，并按值变化或活跃边沿发出对应信号。
## 值变化信号回调改变分发代际时会停止旧刷新。
## [br]
## @api private
## [br]
func _refresh_action_state(action_id: StringName, action: GFInputAction) -> void:
	var dispatch_epoch: int = _dispatch_epoch
	var previous_value: Variant = GFVariantData.get_option_value(
		_action_values,
		action_id,
		_default_value_for_type(action.value_type)
	)
	var previous_active: bool = _get_action_active(action_id)
	var next_value: Variant = _calculate_action_value(action_id, action.value_type)
	var raw_active: bool = _is_value_active(
		next_value,
		action,
		_get_raw_action_active(action_id)
	)
	var next_active: bool = _evaluate_action_triggers(action_id, raw_active, next_value, 0.0)

	_action_values[action_id] = next_value
	_action_active[action_id] = next_active
	_raw_action_active[action_id] = raw_active

	if not _values_equal(previous_value, next_value):
		action_value_changed.emit(action_id, next_value)
		if dispatch_epoch != _dispatch_epoch:
			return

	if not previous_active and next_active:
		_mark_action_just_started(action_id)
		_action_active_elapsed[action_id] = 0.0
		action_started.emit(action_id, next_value)
	elif previous_active and not next_active:
		_mark_action_just_completed(action_id)
		_last_completed_duration[action_id] = _get_action_active_elapsed(action_id)
		_erase_dictionary_key(_action_active_elapsed, action_id)
		action_completed.emit(action_id, next_value)


## 汇总动作的全局绑定贡献，长度超过 1 时归一化，再应用动作修饰器。
## [br]
## @api private
## [br]
func _calculate_action_vector3(action_id: StringName) -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for key: String in _binding_values.keys():
		if _get_binding_action_id(key) == action_id:
			total += GFVariantData.to_vector3(_binding_values[key])
	if total.length() > 1.0:
		total = total.normalized()
	return _apply_mapping_modifiers(action_id, total)


## 汇总指定玩家和动作的绑定贡献，长度超过 1 时归一化，再应用动作修饰器。
## [br]
## @api private
## [br]
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


## 计算全局动作向量并按动作值类型转换为公开动作值。
## [br]
## @api private
## [br]
func _calculate_action_value(action_id: StringName, value_type: GFInputAction.ValueType) -> Variant:
	var vector: Vector3 = _calculate_action_vector3(action_id)
	return _calculate_value_from_vector(vector, value_type)


## 计算指定玩家的动作向量并按动作值类型转换为动作值。
## [br]
## @api private
## [br]
func _calculate_player_action_value(
	player_index: int,
	action_id: StringName,
	value_type: GFInputAction.ValueType
) -> Variant:
	var vector: Vector3 = _calculate_player_action_vector3(player_index, action_id)
	return _calculate_value_from_vector(vector, value_type)


## 将 Vector3 按值类型转换为 bool、限幅 float、Vector2、Vector3 或不支持时的 null。
## [br]
## @api private
## [br]
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


## 返回指定动作值类型的零值；未知类型返回 null。
## [br]
## @api private
## [br]
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


## 判断动作值是否活跃；轴类型根据此前原始活跃状态选择释放或激活阈值。
## [br]
## @api private
## [br]
func _is_value_active(value: Variant, action: GFInputAction, was_raw_active: bool) -> bool:
	if action.value_type == GFInputAction.ValueType.BOOL:
		return GFVariantData.to_bool(value)
	var threshold: float = (
		action.release_threshold
		if was_raw_active
		else action.activation_threshold
	)
	var magnitude: float = 0.0
	match action.value_type:
		GFInputAction.ValueType.AXIS_1D:
			magnitude = absf(GFVariantData.to_float(value))
		GFInputAction.ValueType.AXIS_2D:
			magnitude = GFVariantData.to_vector2(value).length()
		GFInputAction.ValueType.AXIS_3D:
			magnitude = GFVariantData.to_vector3(value).length()
		_:
			return false
	return magnitude > 0.0 and magnitude >= threshold


## 布尔动作阈值不参与校验；轴动作要求阈值有限且满足 0 ≤ release ≤ activation ≤ 1。
## [br]
## @api private
## [br]
func _action_thresholds_are_valid(action: GFInputAction) -> bool:
	if action.value_type == GFInputAction.ValueType.BOOL:
		return true
	var activation_threshold: float = action.activation_threshold
	var release_threshold: float = action.release_threshold
	return (
		not is_nan(activation_threshold)
		and not is_inf(activation_threshold)
		and activation_threshold >= 0.0
		and activation_threshold <= 1.0
		and not is_nan(release_threshold)
		and not is_inf(release_threshold)
		and release_threshold >= 0.0
		and release_threshold <= activation_threshold
	)


## 浮点数及同类型向量使用近似比较，其他 Variant 使用等值比较。
## [br]
## @api private
## [br]
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


## 标记全局动作在当前瞬态窗口内刚开始，记录边沿修订号并排队下一帧清除。
## [br]
## @api private
## [br]
func _mark_action_just_started(action_id: StringName) -> void:
	_just_started[action_id] = true
	_record_action_edge_revision(_action_edge_revisions, action_id, false)
	_queue_clear_transient_input_state()


## 标记全局动作在当前瞬态窗口内刚完成，记录边沿修订号并排队下一帧清除。
## [br]
## @api private
## [br]
func _mark_action_just_completed(action_id: StringName) -> void:
	_just_completed[action_id] = true
	_record_action_edge_revision(_action_edge_revisions, action_id, true)
	_queue_clear_transient_input_state()


## 标记玩家动作刚开始，登记玩家动作元数据、边沿修订号并排队清除瞬态标记。
## [br]
## @api private
## [br]
func _mark_player_action_just_started(player_index: int, action_id: StringName) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	_player_just_started[key] = true
	_record_action_edge_revision(_player_action_edge_revisions, key, false)
	_queue_clear_transient_input_state()


## 标记玩家动作刚完成，登记玩家动作元数据、边沿修订号并排队清除瞬态标记。
## [br]
## @api private
## [br]
func _mark_player_action_just_completed(player_index: int, action_id: StringName) -> void:
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	_player_just_completed[key] = true
	_record_action_edge_revision(_player_action_edge_revisions, key, true)
	_queue_clear_transient_input_state()


## 分配新的动作边沿修订号，并写入 key 对应的 started 或 completed 修订号。
## [br]
## @api private
## [br]
func _record_action_edge_revision(records: Dictionary, key: Variant, completed: bool) -> void:
	_next_action_edge_revision += 1
	var revisions: Dictionary = GFVariantData.get_option_dictionary(records, key)
	revisions["completed" if completed else "started"] = _next_action_edge_revision
	records[key] = revisions


## 标记瞬态动作边沿待清除，并记录当前引擎帧号。
## [br]
## @api private
## [br]
func _queue_clear_transient_input_state() -> void:
	_clear_transient_input_state_queued = true
	_transient_input_state_mark_frame = Engine.get_process_frames()


## 仅在进入记录帧之后清除全局和玩家 started/completed 标记，并重置排队信息。
## [br]
## @api private
## [br]
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


## 终止所有虚拟脉冲并清空全局和玩家绑定、动作、计时及触发器状态。
## emit_completed 为 true 时先收集活跃动作，清理后仅对仍未被新分发或边沿修订取代的完成事件发信号。
## [br]
## @api private
## [br]
func _clear_runtime_state(
	emit_completed: bool = false,
	pulse_reason: StringName = &"input_state_cleared"
) -> void:
	var clear_epoch: int = _dispatch_epoch
	_virtual_pulse_bulk_mutation_depth += 1
	_terminate_all_virtual_pulse_leases(pulse_reason)
	var completed_actions: Dictionary = {}
	var completed_player_actions: Array[Dictionary] = []
	if emit_completed:
		for action_id: StringName in _action_active.keys():
			if _get_action_active(action_id) and _actions.has(action_id):
				var action: GFInputAction = _get_registered_action(action_id)
				if action != null:
					completed_actions[action_id] = _default_value_for_type(action.value_type)
		for player_action_key: String in _player_action_active.keys():
			if not _get_player_action_active_by_key(player_action_key):
				continue
			var player_index: int = _get_player_index_from_action_key(player_action_key)
			var action_id: StringName = _get_player_action_id_from_key(player_action_key)
			if player_index < 0 or action_id == &"":
				continue
			var action: GFInputAction = _get_registered_action(action_id)
			if action != null:
				completed_player_actions.append({
					"player_index": player_index,
					"action_id": action_id,
					"value": _default_value_for_type(action.value_type),
				})

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
	_action_edge_revisions.clear()
	_player_action_edge_revisions.clear()
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
	var completion_revision: int = _next_action_edge_revision
	_virtual_pulse_bulk_mutation_depth = maxi(_virtual_pulse_bulk_mutation_depth - 1, 0)
	for action_id: StringName in completed_actions:
		if not _can_emit_cleared_action_completion(action_id, -1, clear_epoch, completion_revision):
			continue
		action_completed.emit(action_id, completed_actions[action_id])
	for record: Dictionary in completed_player_actions:
		var player_index: int = GFVariantData.get_option_int(record, "player_index")
		var action_id: StringName = GFVariantData.get_option_string_name(record, "action_id")
		if not _can_emit_cleared_action_completion(action_id, player_index, clear_epoch, completion_revision):
			continue
		player_action_completed.emit(
			player_index,
			action_id,
			GFVariantData.get_option_value(record, "value")
		)


## 终止指定玩家的虚拟脉冲，移除玩家绑定及动作状态，并刷新受影响的全局动作。
## 可选记录原活跃玩家动作，清理后通过代际和边沿修订检查再发完成信号。
## [br]
## @api private
## [br]
func _clear_player_runtime_state(player_index: int, emit_completed: bool = false) -> void:
	var clear_epoch: int = _dispatch_epoch
	_virtual_pulse_bulk_mutation_depth += 1
	_terminate_virtual_pulse_leases_for_player(player_index, &"player_state_cleared")
	var affected_actions: Dictionary = {}
	var completed_actions: Dictionary = {}
	if emit_completed:
		for player_action_key: String in _player_action_active.keys():
			if _get_player_index_from_action_key(player_action_key) != player_index:
				continue
			if not _get_player_action_active_by_key(player_action_key):
				continue
			var action_id: StringName = _get_player_action_id_from_key(player_action_key)
			var action: GFInputAction = _get_registered_action(action_id)
			if action != null:
				completed_actions[action_id] = _default_value_for_type(action.value_type)

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
		_erase_dictionary_key(_player_action_edge_revisions, key)
		_erase_dictionary_key(_player_action_active_elapsed, key)
		_erase_dictionary_key(_player_last_completed_duration, key)

	var completion_revision: int = _next_action_edge_revision
	for action_id: StringName in affected_actions.keys():
		var action: GFInputAction = _get_registered_action(action_id)
		if action != null:
			_refresh_action_state(action_id, action)
	_virtual_pulse_bulk_mutation_depth = maxi(_virtual_pulse_bulk_mutation_depth - 1, 0)
	for action_id: StringName in completed_actions:
		if not _can_emit_cleared_action_completion(action_id, player_index, clear_epoch, completion_revision):
			continue
		player_action_completed.emit(player_index, action_id, completed_actions[action_id])


## 仅当清理期间分发代际未变且该动作开始与完成边沿修订均未超过清理快照时允许发完成信号。
## [br]
## @api private
## [br]
func _can_emit_cleared_action_completion(
	action_id: StringName,
	player_index: int,
	clear_epoch: int,
	completion_revision: int
) -> bool:
	# 回调内 start 后再 complete 仍已换代，不能仅凭当前 inactive 复用旧通知。
	return (
		clear_epoch == _dispatch_epoch
		and get_action_edge_revision_for_framework(action_id, player_index) <= completion_revision
		and get_action_edge_revision_for_framework(action_id, player_index, true) <= completion_revision
	)


## 若重映射配置存在该绑定记录则返回覆盖事件（可为空），否则返回基础绑定事件。
## [br]
## @api private
## [br]
func _get_effective_event(
	context_id: StringName,
	action_id: StringName,
	binding_index: int,
	binding: GFInputBinding
) -> InputEvent:
	if _remap_config != null and _remap_config.has_binding(context_id, action_id, binding_index):
		return _remap_config.get_bound_event_or_null(context_id, action_id, binding_index)
	return binding.input_event


## 将上下文、动作和绑定索引编码为绑定复合键。
## [br]
## @api private
## [br]
func _make_binding_key(context_id: StringName, action_id: StringName, binding_index: int) -> String:
	return _make_compound_key(["binding", context_id, action_id, binding_index])


## 将玩家索引和基础绑定键编码为玩家绑定复合键。
## [br]
## @api private
## [br]
func _make_player_binding_key(player_index: int, binding_key: String) -> String:
	return _make_compound_key(["player_binding", player_index, binding_key])


## 保存玩家绑定键对应的玩家索引和基础绑定键。
## [br]
## @api private
## [br]
func _register_player_binding_metadata(key: String, player_index: int, binding_key: String) -> void:
	_player_binding_metadata[key] = {
		"player_index": player_index,
		"binding_key": binding_key,
	}


## 将虚拟来源、玩家索引和动作标识编码为虚拟绑定复合键。
## [br]
## @api private
## [br]
func _make_virtual_binding_key(source_id: StringName, action_id: StringName, player_index: int = -1) -> String:
	return _make_compound_key(["virtual", source_id, player_index, action_id])


## 将基础绑定键和事件来源身份编码为一次物理输入来源键。
## [br]
## @api private
## [br]
func _make_source_binding_key(binding_key: String, event: InputEvent) -> String:
	return _make_compound_key(["source_binding", binding_key, _make_event_source_key(event)])


## 将玩家索引和动作标识编码为玩家动作复合键。
## [br]
## @api private
## [br]
func _make_player_action_key(player_index: int, action_id: StringName) -> String:
	return _make_compound_key(["player_action", player_index, action_id])


## 保存玩家动作复合键对应的玩家索引和动作标识。
## [br]
## @api private
## [br]
func _register_player_action_metadata(key: String, player_index: int, action_id: StringName) -> void:
	_player_action_metadata[key] = {
		"player_index": player_index,
		"action_id": action_id,
	}


## 从玩家绑定元数据中读取基础绑定键。
## [br]
## @api private
## [br]
func _get_player_source_binding_key(player_binding_key: String) -> String:
	return GFVariantData.get_option_string(_get_player_binding_metadata(player_binding_key), "binding_key")


## 从玩家绑定元数据读取玩家索引；缺失时返回 -1。
## [br]
## @api private
## [br]
func _get_player_index_from_binding_key(player_binding_key: String) -> int:
	return GFVariantData.get_option_int(_get_player_binding_metadata(player_binding_key), "player_index", -1)


## 从玩家动作元数据读取玩家索引；缺失时返回 -1。
## [br]
## @api private
## [br]
func _get_player_index_from_action_key(player_action_key: String) -> int:
	return GFVariantData.get_option_int(_get_player_action_metadata(player_action_key), "player_index", -1)


## 从玩家动作元数据读取动作标识。
## [br]
## @api private
## [br]
func _get_player_action_id_from_key(player_action_key: String) -> StringName:
	return GFVariantData.get_option_string_name(_get_player_action_metadata(player_action_key), "action_id")


## 读取玩家绑定键对应的元数据字典。
## [br]
## @api private
## [br]
func _get_player_binding_metadata(player_binding_key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(_player_binding_metadata, player_binding_key)


## 读取玩家动作键对应的元数据字典。
## [br]
## @api private
## [br]
func _get_player_action_metadata(player_action_key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(_player_action_metadata, player_action_key)


## 解码绑定键并核对其组成类型为 virtual 且来源部分等于 source_id。
## [br]
## @api private
## [br]
func _is_virtual_binding_key_for_source(binding_key: String, source_id: StringName) -> bool:
	var parts: PackedStringArray = _decode_compound_key(binding_key)
	return (
		parts.size() == 4
		and _compound_key_part_equals(parts, 0, "virtual")
		and _compound_key_part_equals(parts, 1, source_id)
	)


## 将各键部分编码为带长度前缀的 token，并用版本前缀和分隔符组成复合键。
## 任一部分无法生成 token 时返回空字符串。
## [br]
## @api private
## [br]
func _make_compound_key(parts: Array) -> String:
	var segments: PackedStringArray = PackedStringArray()
	var _prefix_appended: bool = segments.append(_INPUT_KEY_SCHEMA_PREFIX)
	for part: Variant in parts:
		var token: String = _make_key_part_token(part)
		if token.is_empty():
			return ""
		var _segment_appended: bool = segments.append("%d:%s" % [token.length(), token])
	return "|".join(segments)


## 校验复合键版本前缀和每段长度后解码 token；格式不合法时返回空数组。
## [br]
## @api private
## [br]
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


## 检查索引有效且对应 token 与 value 生成的键部分相同。
## [br]
## @api private
## [br]
func _compound_key_part_equals(parts: PackedStringArray, index: int, value: Variant) -> bool:
	if index < 0 or index >= parts.size():
		return false
	var token: String = _make_key_part_token(value)
	return not token.is_empty() and parts[index] == token


## 委托键编码器生成单个复合键部分的 token。
## [br]
## @api private
## [br]
func _make_key_part_token(value: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(value)


## 按动作值类型把虚拟值转换为 Vector3；标量轴分量被限制到 [-1, 1]，不匹配类型按分支规则转零或提取分量。
## [br]
## @api private
## [br]
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


## 检查 float、Vector2 和 Vector3 分量是否有限；其他 Variant 类型不在此处拒绝。
## [br]
## @api private
## [br]
func _is_virtual_value_finite(value: Variant) -> bool:
	if value is float:
		var float_value: float = value
		return not is_nan(float_value) and not is_inf(float_value)
	if value is Vector2:
		var vector2_value: Vector2 = value
		return (
			not is_nan(vector2_value.x)
			and not is_inf(vector2_value.x)
			and not is_nan(vector2_value.y)
			and not is_inf(vector2_value.y)
		)
	if value is Vector3:
		var vector3_value: Vector3 = value
		return _is_finite_vector3(vector3_value)
	return true


## 检查 Vector3 的三个分量均不是 NaN 或无穷值。
## [br]
## @api private
## [br]
func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_inf(value.x)
		and not is_nan(value.y)
		and not is_inf(value.y)
		and not is_nan(value.z)
		and not is_inf(value.z)
	)


## 将有限向量限制到单位长度以内；分量较大时先按最大分量缩放以避免直接计算长度溢出。
## [br]
## @api private
## [br]
func _limit_finite_vector_to_unit_length(value: Vector3) -> Vector3:
	var max_component: float = maxf(absf(value.x), maxf(absf(value.y), absf(value.z)))
	if max_component <= 1.0:
		return value.normalized() if value.length_squared() > 1.0 else value
	var scaled: Vector3 = value / max_component
	var scaled_length: float = scaled.length()
	if scaled_length <= 0.0 or is_nan(scaled_length) or is_inf(scaled_length):
		return Vector3.ZERO
	return scaled / scaled_length


## 用非负 delta 累加当前活跃的全局和玩家动作时长。
## [br]
## @api private
## [br]
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


## 仅忽略键盘 echo 事件。
## [br]
## @api private
## [br]
func _should_ignore_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		return key_event.echo
	return false


## 按手柄设备、触摸设备与索引或默认键鼠来源生成事件来源键。
## [br]
## @api private
## [br]
func _make_event_source_key(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "joypad:%d" % event.device
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		return "touch:%d:%d" % [touch_event.device, touch_event.index]
	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		return "touch:%d:%d" % [drag_event.device, drag_event.index]
	return "keyboard_mouse"


## 重新计算玩家动作值、阈值活跃度和触发器结果，保存状态并按变化或边沿发信号。
## 值变化信号回调使分发代际改变时停止旧刷新。
## [br]
## @api private
## [br]
func _refresh_player_action_state(
	player_index: int,
	action_id: StringName,
	action: GFInputAction
) -> void:
	var dispatch_epoch: int = _dispatch_epoch
	var key: String = _make_player_action_key(player_index, action_id)
	_register_player_action_metadata(key, player_index, action_id)
	var previous_value: Variant = _get_player_action_value_or_default(key, action.value_type)
	var previous_active: bool = _get_player_action_active_by_key(key)
	var next_value: Variant = _calculate_player_action_value(player_index, action_id, action.value_type)
	var raw_active: bool = _is_value_active(
		next_value,
		action,
		_get_player_raw_action_active(key)
	)
	var next_active: bool = _evaluate_player_action_triggers(player_index, action_id, raw_active, next_value, 0.0)

	_player_action_values[key] = next_value
	_player_action_active[key] = next_active
	_player_raw_action_active[key] = raw_active

	if not _values_equal(previous_value, next_value):
		player_action_value_changed.emit(player_index, action_id, next_value)
		if dispatch_epoch != _dispatch_epoch:
			return

	if not previous_active and next_active:
		_mark_player_action_just_started(player_index, action_id)
		_player_action_active_elapsed[key] = 0.0
		player_action_started.emit(player_index, action_id, next_value)
	elif previous_active and not next_active:
		_mark_player_action_just_completed(player_index, action_id)
		_player_last_completed_duration[key] = _get_player_action_active_elapsed(key)
		_erase_dictionary_key(_player_action_active_elapsed, key)
		player_action_completed.emit(player_index, action_id, next_value)


## 通过当前输入设备工具处理事件并解析玩家索引；工具不可用时返回 -1。
## [br]
## @api private
## [br]
func _resolve_player_index(event: InputEvent) -> int:
	var devices: GFInputDeviceUtility = _get_input_device_utility()
	if devices == null:
		return -1
	return devices.handle_input_event(event)


## 设备工具存在且事件为键盘、鼠标、触摸或手柄事件时要求设备分配。
## [br]
## @api private
## [br]
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


## 读取玩家设备死区；玩家索引无效或设备工具不可用时返回 -1。
## [br]
## @api private
## [br]
func _get_player_deadzone(player_index: int) -> float:
	if player_index < 0:
		return -1.0

	var devices: GFInputDeviceUtility = _get_input_device_utility()
	if devices == null:
		return -1.0
	return devices.get_player_deadzone(player_index, -1.0)


## 用本帧 delta 重评所有已配置全局及玩家触发器的动作活跃状态。
## [br]
## @api private
## [br]
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


## 更新全局触发器评估后的活跃状态，并在开始或完成边沿记录瞬态标记、时长和对应信号。
## [br]
## @api private
## [br]
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


## 更新玩家触发器评估后的活跃状态，并在开始或完成边沿记录玩家标记、时长和对应信号。
## [br]
## @api private
## [br]
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


## 使用全局动作的触发器配置和运行时状态评估 raw_active。
## [br]
## @api private
## [br]
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


## 登记玩家动作元数据后，使用玩家作用域触发器状态评估 raw_active。
## [br]
## @api private
## [br]
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


## 按顺序更新触发器状态；任一触发器返回 INACTIVE 时为 false，存在 ONGOING 时最终为 false，否则为 true。
## [br]
## @api private
## [br]
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


## 懒创建并返回指定全局动作的触发器状态数组。
## [br]
## @api private
## [br]
func _get_action_trigger_states(action_id: StringName) -> Array:
	if not _action_trigger_states.has(action_id):
		var states: Array = []
		_action_trigger_states[action_id] = states
	return GFVariantData.as_array(_action_trigger_states[action_id])


## 懒创建并返回指定玩家动作的触发器状态数组。
## [br]
## @api private
## [br]
func _get_player_trigger_states(player_action_key: String) -> Array:
	if not _player_trigger_states.has(player_action_key):
		var states: Array = []
		_player_trigger_states[player_action_key] = states
	return GFVariantData.as_array(_player_trigger_states[player_action_key])


## 清空全局和玩家动作的触发器运行时状态。
## [br]
## @api private
## [br]
func _reset_all_trigger_states() -> void:
	_action_trigger_states.clear()
	_player_trigger_states.clear()


## 依次应用动作修饰器；三维动作调用 modify_3d，其他动作处理 xy 并保留原 z 分量。
## [br]
## @api private
## [br]
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


## 忽略空修饰器并调用各修饰器的 duplicate_modifier，收集非空结果。
## [br]
## @api private
## [br]
func _duplicate_modifiers(modifiers: Array[GFInputModifier]) -> Array[GFInputModifier]:
	var result: Array[GFInputModifier] = []
	for modifier: GFInputModifier in modifiers:
		if modifier == null:
			continue
		var duplicate_modifier: GFInputModifier = modifier.duplicate_modifier()
		if duplicate_modifier != null:
			_append_array_value(result, duplicate_modifier)
	return result


## 过滤空触发器并按原顺序加入结果数组。
## [br]
## @api private
## [br]
func _duplicate_triggers(triggers: Array[GFInputTrigger]) -> Array[GFInputTrigger]:
	var result: Array[GFInputTrigger] = []
	for trigger: GFInputTrigger in triggers:
		if trigger == null:
			continue
		_append_array_value(result, trigger)
	return result


## 发现架构中的设备工具发生变化时切换引用，并订阅其设备分配诊断信号。
## [br]
## @api private
## [br]
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


## 断开当前设备工具的诊断事件订阅并清空工具引用。
## [br]
## @api private
## [br]
func _unbind_input_device_utility() -> void:
	if _input_devices == null:
		return
	if _input_devices.assignment_event_recorded.is_connected(_on_input_assignment_event_recorded):
		_input_devices.assignment_event_recorded.disconnect(_on_input_assignment_event_recorded)
	_input_devices = null


## 从设备分配记录读取有效玩家索引，并清除该玩家运行时输入状态。
## [br]
## @api private
## [br]
func _clear_player_state_from_assignment_record(record: Dictionary) -> void:
	if record.is_empty():
		return
	var player_index: int = GFVariantData.get_option_int(record, "player_index", -1)
	if player_index < 0:
		return
	_clear_player_runtime_state(player_index, true)


## 读取 displaced_player_indices 并清理其中每个非负玩家索引的运行时输入状态。
## [br]
## @api private
## [br]
func _clear_displaced_player_states(metadata: Dictionary) -> void:
	var displaced_players: Array = GFVariantData.get_option_array(metadata, "displaced_player_indices")
	for player_value: Variant in displaced_players:
		var player_index: int = GFVariantData.to_int(player_value, -1)
		if player_index >= 0:
			_clear_player_runtime_state(player_index, true)


## 从架构读取 GFInputDeviceUtility；架构不存在或工具类型不匹配时返回 null。
## [br]
## @api private
## [br]
func _get_input_device_utility() -> GFInputDeviceUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null
	return _get_input_device_utility_value(arch.get_utility(GFInputDeviceUtility))


# --- 信号处理函数 ---

## 分配变更先推进 dispatch epoch，使在途派发失效；再清除受影响玩家状态或全部输入状态。
## [br]
## @api private
func _on_input_assignment_event_recorded(event_record: Dictionary) -> void:
	var event_type: StringName = GFVariantData.get_option_string_name(event_record, "event_type")
	if event_type in [
		&"assignment_removed",
		&"assignment_set",
		&"assignments_cleared",
		&"assignments_refreshed",
	]:
		_dispatch_epoch += 1
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


# --- 内部类 ---

## 随主循环接收输入并在应用失焦时转发回调的内部路由节点。
## [br]
## @api private
## [br]
class _GFInputRouter extends Node:
	# --- 私有变量 ---

	## 同文件 Utility 安装的输入转发委托，收到 Godot _input 后同步调用。
	## [br]
	## @api private
	var _input_callback: Callable

	## 应用失焦时清理 Utility 输入状态的委托；失效时忽略通知。
	## [br]
	## @api private
	var _focus_lost_callback: Callable

	# --- Godot 生命周期方法 ---

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode


	func _input(event: InputEvent) -> void:
		if _input_callback.is_valid():
			_input_callback.call(event)


	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _focus_lost_callback.is_valid():
			_focus_lost_callback.call()
