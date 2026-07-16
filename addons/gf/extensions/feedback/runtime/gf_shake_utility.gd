## GFShakeUtility: 通用反馈播放与采样工具。
##
## 管理命名 channel 上的 `GFShakePreset` 播放状态，项目可按需把采样结果应用到
## Camera、Node2D、Node3D、Control 或任意自定义表现对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFShakeUtility
extends GFUtility


# --- 信号 ---

## 反馈播放开始时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @param channel: 反馈 channel。
signal shake_started(shake_id: int, channel: StringName)

## 反馈播放结束时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @param channel: 反馈 channel。
signal shake_finished(shake_id: int, channel: StringName)

## 反馈播放被停止时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @param channel: 反馈 channel。
signal shake_stopped(shake_id: int, channel: StringName)


# --- 枚举 ---

## 活跃反馈达到上限时的处理方式。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @since 3.17.0
var default_channel: StringName = &"default"

## 最大活跃反馈数量；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_active_shakes: int = 64

## 达到上限时的处理方式。
## [br]
## @api public
## [br]
## @since 3.17.0
var overflow_policy: OverflowPolicy = OverflowPolicy.STOP_OLDEST

## 是否为每次播放随机化相位。
## [br]
## @api public
## [br]
## @since 3.17.0
var randomize_phase: bool = true


# --- 私有变量 ---

var _shake_serial: int = 0
var _active_shakes: Dictionary = {}
var _play_order: PackedInt32Array = PackedInt32Array()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# --- GF 生命周期方法 ---

## 初始化反馈运行时状态和随机源。
## [br]
## @api public
## [br]
## @since 3.17.0
func init() -> void:
	clear()
	_rng.randomize()


## 释放全部反馈播放状态。
## [br]
## @api public
## [br]
## @since 3.17.0
func dispose() -> void:
	clear()


## 推进反馈播放状态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param delta: 本帧时间增量。
func tick(delta: float) -> void:
	if _active_shakes.is_empty():
		return
	var safe_delta: float = maxf(delta, 0.0) if is_finite(delta) else 0.0

	var finished_ids: PackedInt32Array = PackedInt32Array()
	for shake_id: int in _active_shakes.keys():
		var state: Dictionary = _get_shake_state(shake_id)
		if state.is_empty():
			var _invalid_state_id_appended: bool = finished_ids.append(shake_id)
			continue
		var previous_elapsed: float = _get_state_float(state, "elapsed_seconds", 0.0)
		var next_elapsed: float = previous_elapsed + safe_delta
		if not is_finite(next_elapsed):
			next_elapsed = previous_elapsed
		var preset: GFShakePreset = _get_state_preset(state)
		if preset == null:
			var _finished_id_appended: bool = finished_ids.append(shake_id)
			continue
		var duration: float = preset.get_duration_seconds()
		if next_elapsed >= duration:
			if previous_elapsed <= 0.0 and safe_delta > 0.0:
				state["elapsed_seconds"] = duration * 0.25
				continue
			var _finished_id_appended: bool = finished_ids.append(shake_id)
		else:
			state["elapsed_seconds"] = next_elapsed

	for shake_id: int in finished_ids:
		_finish_shake(shake_id)


# --- 公共方法 ---

## 播放一个反馈预设。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param channel: 反馈 channel；为空时使用 default_channel。
## [br]
## @param preset: 反馈预设。
## [br]
## @param strength: 播放强度倍率。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @schema metadata: Dictionary，播放实例自定义元数据，会在 get_shake_info() JSON-safe 快照中复制返回。
## [br]
## @return: 播放实例 ID；无法播放时返回 -1。
func play_shake(
	channel: StringName,
	preset: GFShakePreset,
	strength: float = 1.0,
	metadata: Dictionary = {}
) -> int:
	if preset == null or preset.get_duration_seconds() <= 0.0:
		return -1
	if not _reserve_capacity():
		return -1

	_shake_serial += 1
	var shake_id: int = _shake_serial
	var effective_channel: StringName = _resolve_channel(channel)
	_active_shakes[shake_id] = {
		"id": shake_id,
		"channel": effective_channel,
		"preset": preset,
		"strength": maxf(strength, 0.0) if is_finite(strength) else 0.0,
		"elapsed_seconds": 0.0,
		"phase_offset": _rng.randf() if randomize_phase else 0.0,
		"metadata": metadata.duplicate(true),
	}
	var _play_order_appended: bool = _play_order.append(shake_id)
	shake_started.emit(shake_id, effective_channel)
	return shake_id


## 停止指定反馈实例。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @param emit_stopped: 是否发出停止信号。
## [br]
## @return: 成功停止返回 true。
func stop_shake(shake_id: int, emit_stopped: bool = true) -> bool:
	if not _active_shakes.has(shake_id):
		return false

	var state: Dictionary = _get_shake_state(shake_id)
	var channel: StringName = _get_state_channel(state)
	_erase_active_shake(shake_id)
	var order_index: int = _play_order.find(shake_id)
	if order_index >= 0:
		_play_order.remove_at(order_index)
	if emit_stopped:
		shake_stopped.emit(shake_id, channel)
	return true


## 停止指定 channel 上的全部反馈实例。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param channel: 反馈 channel；为空时使用 default_channel。
## [br]
## @return: 停止数量。
func stop_channel(channel: StringName) -> int:
	var effective_channel: StringName = _resolve_channel(channel)
	var stopped_count: int = 0
	for shake_id: int in _active_shakes.keys():
		var state: Dictionary = _get_shake_state(shake_id)
		if not state.is_empty() and _get_state_channel(state) == effective_channel:
			if stop_shake(shake_id):
				stopped_count += 1
	return stopped_count


## 清空全部反馈实例。
## [br]
## @api public
## [br]
## @since 3.17.0
func clear() -> void:
	_active_shakes.clear()
	_play_order = PackedInt32Array()


## 检查反馈实例是否仍在播放。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @return: 正在播放返回 true。
func is_shake_active(shake_id: int) -> bool:
	return _active_shakes.has(shake_id)


## 获取活跃反馈数量。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param channel: 可选 channel；为空时统计全部。
## [br]
## @return: 活跃反馈数量。
func get_active_shake_count(channel: StringName = &"") -> int:
	if channel == &"":
		return _active_shakes.size()

	var count: int = 0
	for state_variant: Variant in _active_shakes.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if not state.is_empty() and _get_state_channel(state) == channel:
			count += 1
	return count


## 采样指定 channel 当前的合成反馈。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param channel: 反馈 channel；为空时使用 default_channel。
## [br]
## @return: 合成采样结果。
## [br]
## @schema return: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。
func sample_channel(channel: StringName = &"") -> Dictionary:
	var effective_channel: StringName = _resolve_channel(channel)
	var samples: Array[Dictionary] = []
	for state_variant: Variant in _active_shakes.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if state.is_empty() or _get_state_channel(state) != effective_channel:
			continue
		var preset: GFShakePreset = _get_state_preset(state)
		if preset == null:
			continue
		samples.append(preset.sample(
			_get_state_float(state, "elapsed_seconds", 0.0),
			_get_state_float(state, "strength", 1.0),
			_get_state_float(state, "phase_offset", 0.0)
		))
	return GFShakePreset.combine_samples(samples)


## 采样多个 channel 当前的合成反馈。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param channels: 反馈 channel 列表。
## [br]
## @return: 合成采样结果。
## [br]
## @schema return: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。
func sample_channels(channels: PackedStringArray) -> Dictionary:
	var samples: Array[Dictionary] = []
	for channel: String in channels:
		samples.append(sample_channel(StringName(channel)))
	return GFShakePreset.combine_samples(samples)


## 获取指定反馈实例的只读快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param shake_id: 播放实例 ID。
## [br]
## @return: 播放实例快照。
## [br]
## @schema return: JSON-safe Dictionary，包含 id、channel、elapsed_seconds、duration_seconds、strength 与 metadata；实例不存在时为空。
func get_shake_info(shake_id: int) -> Dictionary:
	var state: Dictionary = _get_shake_state(shake_id)
	if state.is_empty():
		return {}
	var preset: GFShakePreset = _get_state_preset(state)
	return _to_report_dictionary({
		"id": shake_id,
		"channel": _get_state_channel(state),
		"elapsed_seconds": _get_state_float(state, "elapsed_seconds", 0.0),
		"duration_seconds": preset.get_duration_seconds() if preset != null else 0.0,
		"strength": _get_state_float(state, "strength", 1.0),
		"metadata": _get_state_metadata_copy(state),
	})


## 获取反馈系统调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 调试快照。
## [br]
## @schema return: JSON-safe Dictionary，包含 active_count、max_active_shakes、channels 与 play_order。
func get_debug_snapshot() -> Dictionary:
	var channels: Dictionary = {}
	for state_variant: Variant in _active_shakes.values():
		var state: Dictionary = GFVariantData.as_dictionary(state_variant)
		if state.is_empty():
			continue
		var channel: String = String(_get_state_channel(state))
		channels[channel] = _get_channel_count(channels, channel) + 1
	return _to_report_dictionary({
		"active_count": _active_shakes.size(),
		"max_active_shakes": max_active_shakes,
		"channels": channels,
		"play_order": _play_order,
	})


# --- 私有/辅助方法 ---

func _reserve_capacity() -> bool:
	if max_active_shakes <= 0 or _active_shakes.size() < max_active_shakes:
		return true
	if overflow_policy == OverflowPolicy.SKIP_NEW:
		return false
	while _active_shakes.size() >= max_active_shakes and not _play_order.is_empty():
		var _stopped_oldest: bool = stop_shake(_play_order[0])
	return _active_shakes.size() < max_active_shakes


func _finish_shake(shake_id: int) -> void:
	if not _active_shakes.has(shake_id):
		return
	var state: Dictionary = _get_shake_state(shake_id)
	var channel: StringName = _get_state_channel(state)
	_erase_active_shake(shake_id)
	var order_index: int = _play_order.find(shake_id)
	if order_index >= 0:
		_play_order.remove_at(order_index)
	shake_finished.emit(shake_id, channel)


func _resolve_channel(channel: StringName) -> StringName:
	return default_channel if channel == &"" else channel


func _erase_active_shake(shake_id: int) -> void:
	var _removed: bool = _active_shakes.erase(shake_id)


func _get_shake_state(shake_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_active_shakes, shake_id))


func _get_state_preset(state: Dictionary) -> GFShakePreset:
	var value: Variant = GFVariantData.get_option_value(state, "preset")
	if value is GFShakePreset:
		var preset: GFShakePreset = value
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


func _get_state_float(state: Dictionary, key: String, default_value: float) -> float:
	var value: float = GFVariantData.get_option_float(state, key, default_value)
	return value if is_finite(value) else default_value


func _get_state_metadata_copy(state: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(state, "metadata")


func _to_report_dictionary(value: Dictionary) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(value, {
		"path_redaction": "basename",
	})


func _get_channel_count(channels: Dictionary, channel: String) -> int:
	return GFVariantData.get_option_int(channels, channel)
