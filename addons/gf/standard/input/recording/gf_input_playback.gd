## GFInputPlayback: 抽象输入录制回放器。
##
## 按时间把 GFInputRecording 中的动作值写入 GFVirtualInputSource，适合测试、
## 复现、教程或 AI 控制桥接。它只回放抽象动作，不模拟具体键鼠或手柄事件。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputPlayback
extends RefCounted


# --- 信号 ---

## 回放开始。
## [br]
## @api public
## [br]
## @param recording: 回放录制。
signal playback_started(recording: GFInputRecording)

## 回放停止。
## [br]
## @api public
signal playback_stopped

## 回放自然完成。
## [br]
## @api public
signal playback_finished

## 一个录制事件已被应用。
## [br]
## @api public
## [br]
## @param event: 事件副本。
## [br]
## @schema event: Dictionary，包含 time_seconds、action_id、value、player_index、source_id 和 metadata。
signal event_applied(event: Dictionary)

## 单帧循环追赶达到预算时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param deferred_seconds: 留待后续 tick 无损处理的秒数。
## [br]
## @param skipped_cycles: 按策略显式跳过的完整周期数。
signal loop_catch_up_limited(deferred_seconds: float, skipped_cycles: int)


# --- 枚举 ---

## 循环回放超出单帧周期预算时的处理策略。
## [br]
## @api public
## [br]
## @since 8.0.0
enum LoopCatchUpPolicy {
	## 保留剩余时间，在后续 tick 继续逐事件处理。
	DEFER_EXCESS,
	## 跳过超预算的完整周期，只重建最终周期状态。
	SKIP_EXCESS_CYCLES,
}


# --- 常量 ---

const _MAX_REPORTED_SKIPPED_CYCLES: float = 9_007_199_254_740_991.0


# --- 公共变量 ---

## 当前录制。
## [br]
## @api public
var recording: GFInputRecording = null

## 目标虚拟输入源。
## [br]
## @api public
var source: GFVirtualInputSource = null

## 回放速度倍率。
## [br]
## @api public
var speed: float = 1.0

## 到达末尾后是否循环。
## [br]
## @api public
var loop: bool = false

## 循环追赶策略。默认无损延后，不静默丢弃事件。
## [br]
## @api public
## [br]
## @since 8.0.0
var loop_catch_up_policy: LoopCatchUpPolicy = LoopCatchUpPolicy.DEFER_EXCESS

## 单次 tick 最多完整推进的循环周期数。
## [br]
## @api public
## [br]
## @since 8.0.0
var max_loop_cycles_per_tick: int = 64:
	set(value):
		max_loop_cycles_per_tick = maxi(value, 1)

## 为 true 时，事件带 player_index 时会写入对应玩家。
## [br]
## @api public
var respect_recorded_player_index: bool = false

## 当前是否正在播放。
## [br]
## @api public
var is_playing: bool = false

## 当前回放时间，单位秒。
## [br]
## @api public
var elapsed_seconds: float = 0.0


# --- 私有变量 ---

var _next_event_index: int = 0
var _event_snapshot: Array[Dictionary] = []
var _duration_seconds: float = 0.0
var _pending_advance_seconds: float = 0.0


# --- 公共方法 ---

## 开始回放。
## [br]
## @api public
## [br]
## @param next_recording: 要回放的录制。
## [br]
## @param next_source: 目标虚拟输入源。
## [br]
## @param restart: 是否从头开始。
## [br]
## @return 成功开始时返回 true。
func start(
	next_recording: GFInputRecording,
	next_source: GFVirtualInputSource,
	restart: bool = true
) -> bool:
	if next_recording == null or next_source == null:
		return false

	recording = next_recording
	source = next_source
	_event_snapshot = next_recording.get_events()
	_duration_seconds = _normalize_non_negative_time(next_recording.duration_seconds)
	_pending_advance_seconds = 0.0
	is_playing = true
	if restart:
		elapsed_seconds = 0.0
		_next_event_index = 0
		source.clear_all()
	else:
		elapsed_seconds = _normalize_non_negative_time(elapsed_seconds)
		if loop and _duration_seconds > 0.0:
			elapsed_seconds = fmod(elapsed_seconds, _duration_seconds)
		_rebuild_source_state_at_elapsed_time()
	playback_started.emit(recording)
	return true


## 停止回放。
## [br]
## @api public
## [br]
## @param clear_source: 是否清空目标虚拟输入源。
func stop(clear_source: bool = false) -> void:
	if clear_source and source != null:
		source.clear_all()
	is_playing = false
	playback_stopped.emit()


## 重置到起点。
## [br]
## @api public
func reset() -> void:
	elapsed_seconds = 0.0
	_next_event_index = 0
	_pending_advance_seconds = 0.0
	if source != null:
		source.clear_all()


## 推进回放并应用到期事件。
## [br]
## @api public
## [br]
## @param delta: 时间增量，单位秒。
## [br]
## @return 本次应用的事件数量。
func tick(delta: float) -> int:
	if not is_playing or recording == null or source == null:
		return 0

	var advance_seconds: float = _safe_add_time(
		_get_advance_seconds(delta),
		_pending_advance_seconds
	)
	_pending_advance_seconds = 0.0
	if loop and _duration_seconds > 0.0:
		return _tick_looping(advance_seconds)
	elapsed_seconds += advance_seconds
	var applied: int = _apply_due_events()
	if _next_event_index >= _event_snapshot.size():
		_handle_end_reached()
	return applied


## 跳转到指定时间。
## [br]
## @api public
## [br]
## @param time_seconds: 目标时间，单位秒。
func seek(time_seconds: float) -> void:
	elapsed_seconds = _normalize_non_negative_time(time_seconds)
	if loop and _duration_seconds > 0.0:
		elapsed_seconds = fmod(elapsed_seconds, _duration_seconds)
	_pending_advance_seconds = 0.0
	_rebuild_source_state_at_elapsed_time()


## 检查是否已到达末尾。
## [br]
## @api public
## [br]
## @return 到达末尾时返回 true。
func is_finished() -> bool:
	return recording == null or _next_event_index >= _event_snapshot.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @schema return: Dictionary，包含 is_playing、elapsed_seconds、speed、loop、respect_recorded_player_index、next_event_index、event_count 和 source_id。
## [br]
## @return 调试快照。
func get_debug_snapshot() -> Dictionary:
	return {
		"is_playing": is_playing,
		"elapsed_seconds": elapsed_seconds,
		"speed": speed,
		"loop": loop,
		"respect_recorded_player_index": respect_recorded_player_index,
		"next_event_index": _next_event_index,
		"event_count": _event_snapshot.size(),
		"duration_seconds": _duration_seconds,
		"pending_advance_seconds": _pending_advance_seconds,
		"loop_catch_up_policy": loop_catch_up_policy,
		"max_loop_cycles_per_tick": max_loop_cycles_per_tick,
		"source_id": source.source_id if source != null else &"",
	}


# --- 私有/辅助方法 ---

func _apply_due_events() -> int:
	var applied: int = 0
	while _next_event_index < _event_snapshot.size():
		var event: Dictionary = _event_snapshot[_next_event_index]
		if _get_event_time_seconds(event) > elapsed_seconds + 0.0001:
			break
		if _apply_event(event):
			applied += 1
		_next_event_index += 1
	return applied


func _apply_event(event: Dictionary, emit_event_signal: bool = true) -> bool:
	var action_id: StringName = _get_event_action_id(event)
	if action_id == &"":
		return false

	var value: Variant = _get_event_value(event)
	var player_index: int = _get_event_player_index(event)
	var applied: bool = false
	if respect_recorded_player_index and player_index >= 0:
		applied = source.set_action_value_for_player(action_id, value, player_index)
	else:
		applied = source.set_action_value(action_id, value)
	if applied and emit_event_signal:
		event_applied.emit(GFVariantData.to_dictionary(event))
	return applied


func _handle_end_reached() -> void:
	is_playing = false
	playback_finished.emit()


func _find_next_event_index(time_seconds: float) -> int:
	if recording == null:
		return 0
	for index: int in range(_event_snapshot.size()):
		if _get_event_time_seconds(_event_snapshot[index]) > time_seconds:
			return index
	return _event_snapshot.size()


func _rebuild_source_state_at_elapsed_time() -> void:
	_next_event_index = 0
	if recording == null:
		return
	if source == null:
		_next_event_index = _find_next_event_index(elapsed_seconds)
		return
	source.clear_all()
	while _next_event_index < _event_snapshot.size():
		var event: Dictionary = _event_snapshot[_next_event_index]
		if _get_event_time_seconds(event) > elapsed_seconds + 0.0001:
			break
		var _applied: bool = _apply_event(event, false)
		_next_event_index += 1


func _tick_looping(advance_seconds: float) -> int:
	var applied: int = _apply_due_events()
	var remaining: float = advance_seconds
	var completed_cycles: int = 0
	while remaining > 0.0:
		var time_to_end: float = maxf(_duration_seconds - elapsed_seconds, 0.0)
		if remaining < time_to_end:
			elapsed_seconds += remaining
			applied += _apply_due_events()
			return applied

		elapsed_seconds = _duration_seconds
		applied += _apply_due_events()
		remaining = maxf(remaining - time_to_end, 0.0)
		completed_cycles += 1
		_begin_loop_cycle()

		if completed_cycles >= max_loop_cycles_per_tick and remaining >= _duration_seconds:
			if loop_catch_up_policy == LoopCatchUpPolicy.DEFER_EXCESS:
				_pending_advance_seconds = remaining
				applied += _apply_due_events()
				loop_catch_up_limited.emit(_pending_advance_seconds, 0)
				return applied
			var skipped_cycles_float: float = floor(remaining / _duration_seconds)
			var skipped_cycles: int = int(minf(
				skipped_cycles_float,
				_MAX_REPORTED_SKIPPED_CYCLES
			))
			remaining = fmod(remaining, _duration_seconds)
			loop_catch_up_limited.emit(0.0, skipped_cycles)

		applied += _apply_due_events()
	return applied


func _begin_loop_cycle() -> void:
	elapsed_seconds = 0.0
	_next_event_index = 0
	if source != null:
		source.clear_all()


func _get_advance_seconds(delta: float) -> float:
	if is_nan(delta) or is_inf(delta) or is_nan(speed) or is_inf(speed):
		return 0.0
	var result: float = maxf(delta, 0.0) * maxf(speed, 0.0)
	return result if not is_nan(result) and not is_inf(result) else 0.0


func _normalize_non_negative_time(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)


func _safe_add_time(left: float, right: float) -> float:
	var result: float = left + right
	if is_nan(result) or is_inf(result):
		return maxf(left, right)
	return maxf(result, 0.0)


func _get_event_time_seconds(event: Dictionary) -> float:
	return GFVariantData.get_option_float(event, "time_seconds")


func _get_event_action_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "action_id")


func _get_event_value(event: Dictionary) -> Variant:
	return GFVariantData.get_option_value(event, "value", false)


func _get_event_player_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, "player_index", -1)
