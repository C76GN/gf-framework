## GFHapticUtility: 通用手柄震动播放工具。
##
## 管理命名 channel 上的 `GFHapticPreset` 播放状态，并把合成后的弱/强马达强度
## 路由到玩家席位或手柄设备。项目仍然决定何时播放、如何分组以及玩法语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFHapticUtility
extends GFUtility


# --- 信号 ---

## 震动播放开始时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @param channel: 震动 channel。
## [br]
## @param target_type: 目标类型，见 TargetType。
## [br]
## @param target_id: 玩家索引或设备 ID。
signal haptic_started(haptic_id: int, channel: StringName, target_type: int, target_id: int)

## 震动播放结束时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @param channel: 震动 channel。
## [br]
## @param target_type: 目标类型，见 TargetType。
## [br]
## @param target_id: 玩家索引或设备 ID。
signal haptic_finished(haptic_id: int, channel: StringName, target_type: int, target_id: int)

## 震动播放被停止时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @param channel: 震动 channel。
## [br]
## @param target_type: 目标类型，见 TargetType。
## [br]
## @param target_id: 玩家索引或设备 ID。
signal haptic_stopped(haptic_id: int, channel: StringName, target_type: int, target_id: int)


# --- 枚举 ---

## 震动输出目标类型。
## [br]
## @api public
## [br]
## @since 7.0.0
enum TargetType {
	## 目标是本地玩家索引，通过 GFInputDeviceUtility 解析到手柄设备。
	PLAYER,
	## 目标是 Godot 手柄设备 ID。
	DEVICE,
}

## 活跃震动达到上限时的处理方式。
## [br]
## @api public
## [br]
## @since 7.0.0
enum OverflowPolicy {
	## 跳过新的播放请求。
	SKIP_NEW,
	## 停止最早的播放实例。
	STOP_OLDEST,
}


# --- 公共变量 ---

## 默认 channel。
## [br]
## @api public
## [br]
## @since 7.0.0
var default_channel: StringName = &"default"

## 默认玩家索引。play_haptic() 传入负数时使用该值。
## [br]
## @api public
## [br]
## @since 7.0.0
var default_player_index: int = 0

## 全局震动强度倍率。
## [br]
## @api public
## [br]
## @since 7.0.0
var master_strength: float = 1.0:
	set(value):
		master_strength = maxf(value, 0.0)

## 最大活跃震动数量；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_active_haptics: int = 64

## 达到上限时的处理方式。
## [br]
## @api public
## [br]
## @since 7.0.0
var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST

## tick() 后是否自动把当前采样输出到设备。关闭时，调用方必须在 tick()、stop_haptic()
## 或 clear() 等状态变化后自行调用 apply_current_outputs()，以刷新输出和停止已结束目标。
## [br]
## @api public
## [br]
## @since 7.0.0
var auto_apply_on_tick: bool = true

## 每次输出请求的刷新持续时间，单位秒。
## [br]
## @api public
## [br]
## @since 7.0.0
var output_refresh_seconds: float = 0.05:
	set(value):
		output_refresh_seconds = maxf(value, 0.0)

## 可选输入设备工具。为空时 ready() 会尝试从架构中获取。
## [br]
## @api public
## [br]
## @since 7.0.0
var input_device_utility: GFInputDeviceUtility = null

## 可选震动输出后端。有效时优先于 output_handler 和默认 Input 路由。
## [br]
## @api public
## [br]
## @since 8.0.0
var haptic_backend: Object = null

## 可选输出回调。有效时替代默认 Input/GFInputDeviceUtility 路由。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema output_handler: Callable(target_type: int, target_id: int, weak_magnitude: float, strong_magnitude: float, duration_seconds: float, metadata: Dictionary) -> bool。
var output_handler: Callable = Callable()

## 可选停止回调。有效时替代默认停止路由。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema stop_handler: Callable(target_type: int, target_id: int, metadata: Dictionary) -> bool。
var stop_handler: Callable = Callable()


# --- 私有变量 ---

var _haptic_serial: int = 0
var _active_haptics: Dictionary = {}
var _play_order: PackedInt32Array = PackedInt32Array()
var _channel_strengths: Dictionary = {}
var _last_output_targets: Dictionary = {}
var _is_dispatching_outputs: bool = false


# --- GF 生命周期方法 ---

## 初始化震动运行时状态。
## [br]
## @api public
## [br]
## @since 7.0.0
func init() -> void:
	clear()


## 在架构 ready 后补全输入设备工具引用。
## [br]
## @api public
## [br]
## @since 7.0.0
func ready() -> void:
	if input_device_utility != null:
		return
	var utility_object: Object = get_utility(GFInputDeviceUtility)
	if utility_object is GFInputDeviceUtility:
		input_device_utility = utility_object


## 停止全部震动并释放状态。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


## 推进震动播放状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param delta: 本帧时间增量。
func tick(delta: float) -> void:
	if _reject_output_reentrant_mutation("tick"):
		return
	if _active_haptics.is_empty():
		if auto_apply_on_tick and not _last_output_targets.is_empty():
			var _apply_empty_result: Dictionary = apply_current_outputs()
		return

	var finished_ids: PackedInt32Array = PackedInt32Array()
	for haptic_id: int in _active_haptics.keys():
		var state: Dictionary = _get_haptic_state(haptic_id)
		if state.is_empty():
			var _invalid_state_appended: bool = finished_ids.append(haptic_id)
			continue
		state["elapsed_seconds"] = _get_state_float(state, "elapsed_seconds", 0.0) + maxf(delta, 0.0)
		var preset: GFHapticPreset = _get_state_preset(state)
		if preset == null or _get_state_float(state, "elapsed_seconds", 0.0) >= preset.get_duration_seconds():
			var _finished_id_appended: bool = finished_ids.append(haptic_id)

	if auto_apply_on_tick:
		var _apply_before_finish_result: Dictionary = apply_current_outputs()

	for haptic_id: int in finished_ids:
		_finish_haptic(haptic_id)

	if auto_apply_on_tick and not finished_ids.is_empty():
		var _apply_after_finish_result: Dictionary = apply_current_outputs()


# --- 公共方法 ---

## 播放一个玩家震动预设。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 震动 channel；为空时使用 default_channel。
## [br]
## @param preset: 震动预设。
## [br]
## @param player_index: 玩家索引；小于 0 时使用 default_player_index。
## [br]
## @param strength: 播放强度倍率。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @schema metadata: Dictionary，播放实例自定义元数据，会在 get_haptic_info() JSON-safe 快照中复制返回。
## [br]
## @return: 播放实例 ID；无法播放时返回 -1。
func play_haptic(
	channel: StringName,
	preset: GFHapticPreset,
	player_index: int = -1,
	strength: float = 1.0,
	metadata: Dictionary = {}
) -> int:
	if _reject_output_reentrant_mutation("play_haptic"):
		return -1
	var target_id: int = default_player_index if player_index < 0 else player_index
	return _play_haptic_for_target(TargetType.PLAYER, target_id, channel, preset, strength, metadata)


## 播放一个设备震动预设。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 震动 channel；为空时使用 default_channel。
## [br]
## @param preset: 震动预设。
## [br]
## @param device_id: Godot 手柄设备 ID。
## [br]
## @param strength: 播放强度倍率。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @schema metadata: Dictionary，播放实例自定义元数据，会在 get_haptic_info() JSON-safe 快照中复制返回。
## [br]
## @return: 播放实例 ID；无法播放时返回 -1。
func play_haptic_for_device(
	channel: StringName,
	preset: GFHapticPreset,
	device_id: int,
	strength: float = 1.0,
	metadata: Dictionary = {}
) -> int:
	if _reject_output_reentrant_mutation("play_haptic_for_device"):
		return -1
	return _play_haptic_for_target(TargetType.DEVICE, device_id, channel, preset, strength, metadata)


## 停止指定震动实例。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @param emit_stopped: 是否发出停止信号。
## [br]
## @return: 成功停止返回 true。
func stop_haptic(haptic_id: int, emit_stopped: bool = true) -> bool:
	if _reject_output_reentrant_mutation("stop_haptic"):
		return false
	if not _active_haptics.has(haptic_id):
		return false

	var state: Dictionary = _get_haptic_state(haptic_id)
	if state.is_empty():
		return false
	_remove_active_haptic(haptic_id, emit_stopped)
	var _apply_result: Dictionary = apply_current_outputs()
	return true


## 停止指定 channel 上的全部震动实例。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 震动 channel；为空时使用 default_channel。
## [br]
## @return: 停止数量。
func stop_channel(channel: StringName) -> int:
	if _reject_output_reentrant_mutation("stop_channel"):
		return 0
	var effective_channel: StringName = _resolve_channel(channel)
	var stopped_count: int = 0
	for haptic_id: int in _active_haptics.keys():
		var state: Dictionary = _get_haptic_state(haptic_id)
		if not state.is_empty() and _get_state_channel(state) == effective_channel:
			_remove_active_haptic(haptic_id, true)
			stopped_count += 1
	var _apply_result: Dictionary = apply_current_outputs()
	return stopped_count


## 停止指定玩家的全部震动实例。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param player_index: 玩家索引。
## [br]
## @return: 停止数量。
func stop_player(player_index: int) -> int:
	return _stop_target(TargetType.PLAYER, player_index, false)


## 停止指定设备的全部震动实例。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param device_id: Godot 手柄设备 ID。
## [br]
## @return: 停止数量。
func stop_device(device_id: int) -> int:
	return _stop_target(TargetType.DEVICE, device_id, true)


## 清空全部震动实例并停止上次输出过的目标。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	if _reject_output_reentrant_mutation("clear"):
		return
	_active_haptics.clear()
	_play_order = PackedInt32Array()
	_is_dispatching_outputs = true
	var stop_result: Dictionary = _stop_missing_outputs({})
	_is_dispatching_outputs = false
	_last_output_targets = GFVariantData.get_option_dictionary(stop_result, "pending_targets")


## 检查震动实例是否仍在播放。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @return: 正在播放返回 true。
func is_haptic_active(haptic_id: int) -> bool:
	return _active_haptics.has(haptic_id)


## 获取活跃震动数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 可选 channel；为空时统计全部。
## [br]
## @return: 活跃震动数量。
func get_active_haptic_count(channel: StringName = &"") -> int:
	if channel == &"":
		return _active_haptics.size()

	var count: int = 0
	for state_variant: Variant in _active_haptics.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if not state.is_empty() and _get_state_channel(state) == channel:
			count += 1
	return count


## 设置 channel 强度倍率。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 震动 channel；为空时使用 default_channel。
## [br]
## @param strength: 强度倍率；小于 0 时按 0 处理。
func set_channel_strength(channel: StringName, strength: float) -> void:
	if _reject_output_reentrant_mutation("set_channel_strength"):
		return
	_channel_strengths[_resolve_channel(channel)] = maxf(strength, 0.0)


## 获取 channel 强度倍率。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param channel: 震动 channel；为空时使用 default_channel。
## [br]
## @return: 强度倍率。
func get_channel_strength(channel: StringName) -> float:
	var value: Variant = GFVariantData.get_option_value(_channel_strengths, _resolve_channel(channel), 1.0)
	return GFVariantData.to_float(value, 1.0)


## 清空全部 channel 强度覆盖。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_channel_strengths() -> void:
	if _reject_output_reentrant_mutation("clear_channel_strengths"):
		return
	_channel_strengths.clear()


## 采样指定玩家当前的合成震动。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param player_index: 玩家索引。
## [br]
## @param channel: 可选 channel；为空时合成该玩家全部 channel。
## [br]
## 返回玩家最终路由到的物理输出视图；映射到设备后会与该设备的直接震动合并。
## [br]
## @return: 合成震动采样。
## [br]
## @schema return: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。
func sample_player(player_index: int, channel: StringName = &"") -> Dictionary:
	return _sample_target(TargetType.PLAYER, player_index, channel)


## 采样指定设备当前的合成震动。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param device_id: Godot 手柄设备 ID。
## [br]
## @param channel: 可选 channel；为空时合成该设备全部 channel。
## [br]
## 返回设备最终物理输出视图，包含映射到该设备的玩家震动。
## [br]
## @return: 合成震动采样。
## [br]
## @schema return: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。
func sample_device(device_id: int, channel: StringName = &"") -> Dictionary:
	return _sample_target(TargetType.DEVICE, device_id, channel)


## 把当前采样输出到所有活跃目标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param duration_seconds: 输出请求持续时间；小于 0 时使用 output_refresh_seconds。
## [br]
## @return: 输出报告。
## [br]
## @schema return: JSON-safe Dictionary，包含 applied_count、stopped_count、failed_stop_count、applied、stopped 与 failed_stops。
func apply_current_outputs(duration_seconds: float = -1.0) -> Dictionary:
	if _reject_output_reentrant_mutation("apply_current_outputs"):
		return _to_report_dictionary(_make_empty_output_report())
	_is_dispatching_outputs = true
	var duration: float = output_refresh_seconds if duration_seconds < 0.0 else maxf(duration_seconds, 0.0)
	var target_records: Dictionary = _get_active_target_records()
	var current_output_targets: Dictionary = {}
	var applied: Array[Dictionary] = []
	for target_key: String in target_records.keys():
		var target_record: Dictionary = _get_dictionary_value(target_records, target_key)
		var target_type: int = GFVariantData.get_option_int(target_record, "target_type", TargetType.PLAYER)
		var target_id: int = GFVariantData.get_option_int(target_record, "target_id", -1)
		var sample: Dictionary = _sample_output_target(target_key, &"")
		var weak_value: float = GFVariantData.get_option_float(sample, "weak_magnitude", 0.0)
		var strong_value: float = GFVariantData.get_option_float(sample, "strong_magnitude", 0.0)
		if weak_value <= 0.0 and strong_value <= 0.0:
			continue
		var metadata: Dictionary = _make_output_metadata(target_key, target_type, target_id, sample)
		var applied_ok: bool = _start_output(target_type, target_id, weak_value, strong_value, duration, metadata)
		if not applied_ok:
			continue
		current_output_targets[target_key] = {
			"target_type": target_type,
			"target_id": target_id,
			"metadata": metadata,
		}
		applied.append({
			"target_type": target_type,
			"target_id": target_id,
			"weak_magnitude": weak_value,
			"strong_magnitude": strong_value,
			"duration_seconds": duration,
			"metadata": metadata,
		})

	var stop_result: Dictionary = _stop_missing_outputs(current_output_targets)
	var stopped: Array[Dictionary] = _get_dictionary_array(stop_result, "stopped")
	var failed_stops: Array[Dictionary] = _get_dictionary_array(stop_result, "failed_stops")
	var next_output_targets: Dictionary = GFVariantData.get_option_dictionary(stop_result, "pending_targets")
	for target_key: String in current_output_targets.keys():
		next_output_targets[target_key] = _get_dictionary_value(current_output_targets, target_key)
	_last_output_targets = next_output_targets
	_is_dispatching_outputs = false
	var report: Dictionary = {
		"applied_count": applied.size(),
		"stopped_count": stopped.size(),
		"failed_stop_count": failed_stops.size(),
		"applied": applied,
		"stopped": stopped,
		"failed_stops": failed_stops,
	}
	return _to_report_dictionary(report)


## 获取指定震动实例的只读快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param haptic_id: 播放实例 ID。
## [br]
## @return: 播放实例快照。
## [br]
## @schema return: JSON-safe Dictionary，包含 id、channel、target_type、target_id、elapsed_seconds、duration_seconds、strength 与 metadata；实例不存在时为空。
func get_haptic_info(haptic_id: int) -> Dictionary:
	var state: Dictionary = _get_haptic_state(haptic_id)
	if state.is_empty():
		return {}
	var preset: GFHapticPreset = _get_state_preset(state)
	return _to_report_dictionary({
		"id": haptic_id,
		"channel": _get_state_channel(state),
		"target_type": _get_state_target_type(state),
		"target_id": _get_state_target_id(state),
		"elapsed_seconds": _get_state_float(state, "elapsed_seconds", 0.0),
		"duration_seconds": preset.get_duration_seconds() if preset != null else 0.0,
		"strength": _get_state_float(state, "strength", 1.0),
		"metadata": _get_state_metadata_copy(state),
	})


## 获取震动系统调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 调试快照。
## [br]
## @schema return: JSON-safe Dictionary，包含 active_count、max_active_haptics、channels、targets、play_order 与 last_output_targets。
func get_debug_snapshot() -> Dictionary:
	var channels: Dictionary = {}
	var targets: Dictionary = {}
	for state_variant: Variant in _active_haptics.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if state.is_empty():
			continue
		var channel: String = String(_get_state_channel(state))
		channels[channel] = GFVariantData.get_option_int(channels, channel) + 1
		var target_key: String = _make_target_key(_get_state_target_type(state), _get_state_target_id(state))
		targets[target_key] = GFVariantData.get_option_int(targets, target_key) + 1
	return _to_report_dictionary({
		"active_count": _active_haptics.size(),
		"max_active_haptics": max_active_haptics,
		"channels": channels,
		"targets": targets,
		"play_order": _play_order,
		"last_output_targets": _last_output_targets.duplicate(true),
	})


# --- 私有/辅助方法 ---

func _play_haptic_for_target(
	target_type: int,
	target_id: int,
	channel: StringName,
	preset: GFHapticPreset,
	strength: float,
	metadata: Dictionary
) -> int:
	if preset == null or preset.get_duration_seconds() <= 0.0:
		return -1
	if target_id < 0:
		return -1
	if not _reserve_capacity():
		return -1

	_haptic_serial += 1
	var haptic_id: int = _haptic_serial
	var effective_channel: StringName = _resolve_channel(channel)
	_active_haptics[haptic_id] = {
		"id": haptic_id,
		"channel": effective_channel,
		"target_type": target_type,
		"target_id": target_id,
		"preset": preset,
		"strength": maxf(strength, 0.0),
		"elapsed_seconds": 0.0,
		"metadata": metadata.duplicate(true),
	}
	var _play_order_appended: bool = _play_order.append(haptic_id)
	haptic_started.emit(haptic_id, effective_channel, target_type, target_id)
	return haptic_id


func _reserve_capacity() -> bool:
	if max_active_haptics <= 0 or _active_haptics.size() < max_active_haptics:
		return true
	if overflow_policy == OverflowPolicy.SKIP_NEW:
		return false
	while _active_haptics.size() >= max_active_haptics and not _play_order.is_empty():
		var _stopped_oldest: bool = stop_haptic(_play_order[0])
	return _active_haptics.size() < max_active_haptics


func _finish_haptic(haptic_id: int) -> void:
	if not _active_haptics.has(haptic_id):
		return
	var state: Dictionary = _get_haptic_state(haptic_id)
	var channel: StringName = _get_state_channel(state)
	var target_type: int = _get_state_target_type(state)
	var target_id: int = _get_state_target_id(state)
	_erase_active_haptic(haptic_id)
	_remove_from_play_order(haptic_id)
	haptic_finished.emit(haptic_id, channel, target_type, target_id)


func _stop_target(target_type: int, target_id: int, match_output_route: bool) -> int:
	var operation: String = "stop_device" if match_output_route else "stop_player"
	if _reject_output_reentrant_mutation(operation):
		return 0
	var stopped_count: int = 0
	for haptic_id: int in _active_haptics.keys():
		var state: Dictionary = _get_haptic_state(haptic_id)
		if state.is_empty():
			continue
		var matches_target: bool = (
			_get_state_target_type(state) == target_type
			and _get_state_target_id(state) == target_id
		)
		if match_output_route:
			var output_record: Dictionary = _make_output_target_record(
				_get_state_target_type(state),
				_get_state_target_id(state)
			)
			matches_target = (
				GFVariantData.get_option_int(output_record, "target_type", -1) == TargetType.DEVICE
				and GFVariantData.get_option_int(output_record, "target_id", -1) == target_id
			)
		if not matches_target:
			continue
		_remove_active_haptic(haptic_id, true)
		stopped_count += 1
	var _apply_result: Dictionary = apply_current_outputs()
	return stopped_count


func _sample_target(target_type: int, target_id: int, channel: StringName) -> Dictionary:
	return _sample_output_target(_make_output_target_key(target_type, target_id), channel)


func _sample_output_target(output_target_key: String, channel: StringName) -> Dictionary:
	var samples: Array[Dictionary] = []
	var effective_channel: StringName = _resolve_channel(channel)
	for state_variant: Variant in _active_haptics.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if state.is_empty():
			continue
		if _make_output_target_key(_get_state_target_type(state), _get_state_target_id(state)) != output_target_key:
			continue
		var state_channel: StringName = _get_state_channel(state)
		if channel != &"" and state_channel != effective_channel:
			continue
		var preset: GFHapticPreset = _get_state_preset(state)
		if preset == null:
			continue
		var state_strength: float = (
			_get_state_float(state, "strength", 1.0)
			* master_strength
			* get_channel_strength(state_channel)
		)
		samples.append(preset.sample(_get_state_float(state, "elapsed_seconds", 0.0), state_strength))
	return GFHapticPreset.combine_samples(samples)


func _get_active_target_records() -> Dictionary:
	var result: Dictionary = {}
	for state_variant: Variant in _active_haptics.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if state.is_empty():
			continue
		var target_type: int = _get_state_target_type(state)
		var target_id: int = _get_state_target_id(state)
		var output_record: Dictionary = _make_output_target_record(target_type, target_id)
		result[GFVariantData.get_option_string(output_record, "target_key")] = output_record
	return result


func _start_output(
	target_type: int,
	target_id: int,
	weak_magnitude: float,
	strong_magnitude: float,
	duration_seconds: float,
	metadata: Dictionary
) -> bool:
	if haptic_backend != null and haptic_backend.has_method("start_output"):
		return GFVariantData.to_bool(haptic_backend.call(
			"start_output",
			target_type,
			target_id,
			weak_magnitude,
			strong_magnitude,
			duration_seconds,
			metadata
		), false)
	if output_handler.is_valid():
		return GFVariantData.to_bool(output_handler.call(
			target_type,
			target_id,
			weak_magnitude,
			strong_magnitude,
			duration_seconds,
			metadata
		), false)

	match target_type:
		TargetType.PLAYER:
			if input_device_utility == null:
				return false
			return input_device_utility.start_vibration_for_player(
				target_id,
				weak_magnitude,
				strong_magnitude,
				duration_seconds
			)
		TargetType.DEVICE:
			if target_id < 0 or not Input.get_connected_joypads().has(target_id):
				return false
			Input.start_joy_vibration(target_id, weak_magnitude, strong_magnitude, duration_seconds)
			return true
		_:
			return false


func _stop_output(target_type: int, target_id: int, metadata: Dictionary) -> bool:
	if haptic_backend != null and haptic_backend.has_method("stop_output"):
		return GFVariantData.to_bool(haptic_backend.call("stop_output", target_type, target_id, metadata), false)
	if stop_handler.is_valid():
		return GFVariantData.to_bool(stop_handler.call(target_type, target_id, metadata), false)

	match target_type:
		TargetType.PLAYER:
			if input_device_utility == null:
				return false
			return input_device_utility.stop_vibration_for_player(target_id)
		TargetType.DEVICE:
			if target_id < 0 or not Input.get_connected_joypads().has(target_id):
				return false
			Input.stop_joy_vibration(target_id)
			return true
		_:
			return false


func _stop_missing_outputs(current_output_targets: Dictionary) -> Dictionary:
	var stopped: Array[Dictionary] = []
	var failed_stops: Array[Dictionary] = []
	var pending_targets: Dictionary = {}
	for target_key: String in _last_output_targets.keys():
		if current_output_targets.has(target_key):
			continue
		var target_record: Dictionary = _get_dictionary_value(_last_output_targets, target_key)
		var target_type: int = GFVariantData.get_option_int(target_record, "target_type", TargetType.PLAYER)
		var target_id: int = GFVariantData.get_option_int(target_record, "target_id", -1)
		var metadata: Dictionary = GFVariantData.get_option_dictionary(target_record, "metadata")
		if _stop_output(target_type, target_id, metadata):
			stopped.append({
				"target_type": target_type,
				"target_id": target_id,
				"metadata": metadata,
			})
		else:
			var failed_report: Dictionary = {
				"target_type": target_type,
				"target_id": target_id,
				"metadata": metadata,
				"reason": "stop_failed",
			}
			failed_stops.append(failed_report)
			pending_targets[target_key] = target_record.duplicate(true)
	return {
		"stopped": stopped,
		"failed_stops": failed_stops,
		"pending_targets": pending_targets,
	}


func _to_report_dictionary(value: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(value, {
		"path_redaction": "basename",
	})


func _make_output_metadata(output_target_key: String, target_type: int, target_id: int, sample: Dictionary) -> Dictionary:
	var active_ids: PackedInt32Array = PackedInt32Array()
	var channels: PackedStringArray = PackedStringArray()
	for state_variant: Variant in _active_haptics.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if (
			state.is_empty()
			or _make_output_target_key(_get_state_target_type(state), _get_state_target_id(state)) != output_target_key
		):
			continue
		var _id_appended: bool = active_ids.append(GFVariantData.get_option_int(state, "id", -1))
		var channel_text: String = String(_get_state_channel(state))
		if not channels.has(channel_text):
			var _channel_appended: bool = channels.append(channel_text)
	return {
		"target_type": target_type,
		"target_id": target_id,
		"haptic_ids": active_ids,
		"channels": channels,
		"sample": sample.duplicate(true),
	}


func _resolve_channel(channel: StringName) -> StringName:
	return default_channel if channel == &"" else channel


func _erase_active_haptic(haptic_id: int) -> void:
	var _removed: bool = _active_haptics.erase(haptic_id)


func _remove_from_play_order(haptic_id: int) -> void:
	var order_index: int = _play_order.find(haptic_id)
	if order_index >= 0:
		_play_order.remove_at(order_index)


func _remove_active_haptic(haptic_id: int, emit_stopped: bool) -> void:
	var state: Dictionary = _get_haptic_state(haptic_id)
	if state.is_empty():
		return
	var channel: StringName = _get_state_channel(state)
	var target_type: int = _get_state_target_type(state)
	var target_id: int = _get_state_target_id(state)
	_erase_active_haptic(haptic_id)
	_remove_from_play_order(haptic_id)
	if emit_stopped:
		haptic_stopped.emit(haptic_id, channel, target_type, target_id)


func _get_haptic_state(haptic_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_active_haptics, haptic_id))


func _get_state_preset(state: Dictionary) -> GFHapticPreset:
	var value: Variant = GFVariantData.get_option_value(state, "preset")
	if value is GFHapticPreset:
		var preset: GFHapticPreset = value
		return preset
	return null


func _get_state_channel(state: Dictionary) -> StringName:
	var value: Variant = GFVariantData.get_option_value(state, "channel", default_channel)
	if value is StringName:
		var channel: StringName = value
		return channel
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return default_channel


func _get_state_target_type(state: Dictionary) -> int:
	return GFVariantData.get_option_int(state, "target_type", TargetType.PLAYER)


func _get_state_target_id(state: Dictionary) -> int:
	return GFVariantData.get_option_int(state, "target_id", -1)


func _get_state_float(state: Dictionary, key: String, default_value: float) -> float:
	return GFVariantData.get_option_float(state, key, default_value)


func _get_state_metadata_copy(state: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(state, "metadata")


func _make_target_key(target_type: int, target_id: int) -> String:
	return "%d:%d" % [target_type, target_id]


func _make_output_target_key(target_type: int, target_id: int) -> String:
	var output_record: Dictionary = _make_output_target_record(target_type, target_id)
	return GFVariantData.get_option_string(output_record, "target_key")


func _make_output_target_record(target_type: int, target_id: int) -> Dictionary:
	if target_type == TargetType.PLAYER:
		var assignment: GFInputDeviceAssignment = _get_player_joypad_assignment(target_id)
		if assignment != null:
			return {
				"target_key": _make_target_key(TargetType.DEVICE, assignment.device_id),
				"target_type": TargetType.DEVICE,
				"target_id": assignment.device_id,
			}
	return {
		"target_key": _make_target_key(target_type, target_id),
		"target_type": target_type,
		"target_id": target_id,
	}


func _get_player_joypad_assignment(player_index: int) -> GFInputDeviceAssignment:
	if input_device_utility == null:
		return null
	var assignment: GFInputDeviceAssignment = input_device_utility.get_assignment(player_index)
	if assignment == null or assignment.device_type != GFInputDeviceAssignment.DeviceType.JOYPAD or assignment.device_id < 0:
		return null
	return assignment


func _get_dictionary_value(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is Dictionary:
		var result: Dictionary = value
		return result
	return {}


func _get_dictionary_array(source: Dictionary, key: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in GFVariantData.get_option_array(source, key):
		if item is Dictionary:
			var dictionary_item: Dictionary = item
			result.append(dictionary_item)
	return result


func _make_empty_output_report() -> Dictionary:
	return {
		"applied_count": 0,
		"stopped_count": 0,
		"failed_stop_count": 0,
		"applied": [],
		"stopped": [],
		"failed_stops": [],
	}


func _reject_output_reentrant_mutation(operation: String) -> bool:
	if not _is_dispatching_outputs:
		return false
	push_error(
		"[GFHapticUtility] %s 失败：输出后端或回调执行期间不允许同步修改震动状态。请在当前输出结束后再修改。"
		% operation
	)
	return true
