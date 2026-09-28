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

## 一个录制事件已被应用。事件索引会先提交再同步发出本信号；handler 可以调用
## start/stop/reset/seek，旧 tick 会在 handler 返回后停止，不再推进新会话。
## [br]
## @api public
## [br]
## @since 11.0.0
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

## 跳周期报告可精确表示的最大整数值，用于限制浮点计算得到的计数。
## [br]
## @api private
## [br]
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

## 下一条待应用事件在当前事件列表中的索引。
## [br]
## @api private
## [br]
var _next_event_index: int = 0

## 当前回放按索引读取的录制事件列表。
## [br]
## @api private
## [br]
var _event_snapshot: Array[Dictionary] = []

## 当前录制采用的有限非负时长。
## [br]
## @api private
## [br]
var _duration_seconds: float = 0.0

## DEFER_EXCESS 策略延后到后续 tick 处理的回放时间。
## [br]
## @api private
## [br]
var _pending_advance_seconds: float = 0.0

## 回放操作代际；同步回调启动或改变会话时用于使旧操作失效。
## [br]
## @api private
## [br]
var _playback_epoch: int = 0


# --- 公共方法 ---

## 开始回放。每次成功调用都会创建新的回放代际；同步回调中启动的新代际不会被
## 旧 tick 的索引、完成状态或后续事件覆盖。
## [br]
## @api public
## [br]
## @since 11.0.0
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

	_playback_epoch += 1
	var operation_epoch: int = _playback_epoch
	var operation_recording: GFInputRecording = next_recording
	var operation_source: GFVirtualInputSource = next_source
	recording = next_recording
	source = next_source
	_event_snapshot = next_recording.get_events()
	_duration_seconds = _normalize_non_negative_time(next_recording.duration_seconds)
	_pending_advance_seconds = 0.0
	is_playing = true
	if restart:
		elapsed_seconds = 0.0
		_next_event_index = 0
		operation_source.clear_all()
		if not _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			true
		):
			return false
	else:
		elapsed_seconds = _normalize_non_negative_time(elapsed_seconds)
		if loop and _duration_seconds > 0.0:
			elapsed_seconds = fmod(elapsed_seconds, _duration_seconds)
		if not _rebuild_source_state_at_elapsed_time(
			operation_epoch,
			operation_recording,
			operation_source,
			true
		):
			return false
	playback_started.emit(operation_recording)
	var _still_current_after_started: bool = _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		true
	)
	return true


## 停止回放。调用会先使当前代际失效，再按需清理 source 和发出停止信号。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param clear_source: 是否清空目标虚拟输入源。
func stop(clear_source: bool = false) -> void:
	_playback_epoch += 1
	var operation_epoch: int = _playback_epoch
	var source_to_clear: GFVirtualInputSource = source
	is_playing = false
	if clear_source and source_to_clear != null:
		source_to_clear.clear_all()
		if _playback_epoch != operation_epoch:
			return
	playback_stopped.emit()


## 重置到起点。
## [br]
## @api public
func reset() -> void:
	_playback_epoch += 1
	var operation_epoch: int = _playback_epoch
	var operation_recording: GFInputRecording = recording
	var operation_source: GFVirtualInputSource = source
	var operation_was_playing: bool = is_playing
	elapsed_seconds = 0.0
	_next_event_index = 0
	_pending_advance_seconds = 0.0
	if operation_source != null:
		operation_source.clear_all()
		var _still_current_after_reset: bool = _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			operation_was_playing
		)


## 推进回放并应用到期事件。一次调用只向进入 tick 时绑定的 recording/source
## 提交；同步回调改变会话或 source 后，剩余到期事件留给新会话或后续显式操作。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param delta: 时间增量，单位秒。
## [br]
## @return 本次应用的事件数量。
func tick(delta: float) -> int:
	if not is_playing or recording == null or source == null:
		return 0

	var operation_epoch: int = _playback_epoch
	var operation_recording: GFInputRecording = recording
	var operation_source: GFVirtualInputSource = source
	var advance_seconds: float = _safe_add_time(
		_get_advance_seconds(delta),
		_pending_advance_seconds
	)
	_pending_advance_seconds = 0.0
	if loop and _duration_seconds > 0.0:
		return _tick_looping(
			advance_seconds,
			operation_epoch,
			operation_recording,
			operation_source
		)
	elapsed_seconds = _safe_add_time(elapsed_seconds, advance_seconds)
	var applied: int = _apply_due_events(
		operation_epoch,
		operation_recording,
		operation_source
	)
	if not _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		true
	):
		return applied
	if _next_event_index >= _event_snapshot.size():
		_handle_end_reached(operation_epoch, operation_recording, operation_source)
	return applied


## 跳转到指定时间。
## [br]
## @api public
## [br]
## @param time_seconds: 目标时间，单位秒。
func seek(time_seconds: float) -> void:
	_playback_epoch += 1
	var operation_epoch: int = _playback_epoch
	var operation_recording: GFInputRecording = recording
	var operation_source: GFVirtualInputSource = source
	var operation_was_playing: bool = is_playing
	elapsed_seconds = _normalize_non_negative_time(time_seconds)
	if loop and _duration_seconds > 0.0:
		elapsed_seconds = fmod(elapsed_seconds, _duration_seconds)
	_pending_advance_seconds = 0.0
	var _rebuilt: bool = _rebuild_source_state_at_elapsed_time(
		operation_epoch,
		operation_recording,
		operation_source,
		operation_was_playing
	)


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

## 顺序处理已到期事件；先递增事件索引，再应用事件并发出 event_applied，且在同步回调后验证原回放代际。
## 返回本次成功应用的事件数；回调改变状态时立即停止旧 tick。
## [br]
## @api private
## [br]
func _apply_due_events(
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource
) -> int:
	var applied: int = 0
	while (
		_is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			true
		)
		and _next_event_index < _event_snapshot.size()
	):
		var event: Dictionary = _event_snapshot[_next_event_index]
		if _get_event_time_seconds(event) > elapsed_seconds + 0.0001:
			break
		_next_event_index += 1
		if _apply_event(event, operation_source):
			applied += 1
			if not _is_playback_state_current(
				operation_epoch,
				operation_recording,
				operation_source,
				true
			):
				return applied
			event_applied.emit(GFVariantData.to_dictionary(event))
			if not _is_playback_state_current(
				operation_epoch,
				operation_recording,
				operation_source,
				true
			):
				return applied
	return applied


## 将单条录制事件写入目标虚拟输入源；无效目标或空动作标识不应用，按配置选择玩家专属或普通写入。
## [br]
## @api private
## [br]
func _apply_event(event: Dictionary, target_source: GFVirtualInputSource) -> bool:
	if target_source == null:
		return false
	var action_id: StringName = _get_event_action_id(event)
	if action_id == &"":
		return false

	var value: Variant = _get_event_value(event)
	var player_index: int = _get_event_player_index(event)
	var applied: bool = false
	if respect_recorded_player_index and player_index >= 0:
		applied = target_source.set_action_value_for_player(action_id, value, player_index)
	else:
		applied = target_source.set_action_value(action_id, value)
	return applied


## 在当前回放状态仍有效且事件已全部处理时，使代际失效、标记停止并发出自然完成信号。
## [br]
## @api private
## [br]
func _handle_end_reached(
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource
) -> void:
	if not _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		true
	):
		return
	_playback_epoch += 1
	is_playing = false
	playback_finished.emit()


## 找到首个时间晚于目标时间的事件索引；目标时间之前或相等的事件视为已到期。
## recording 为空时返回 0。
## [br]
## @api private
## [br]
func _find_next_event_index(time_seconds: float) -> int:
	if recording == null:
		return 0
	for index: int in range(_event_snapshot.size()):
		if _get_event_time_seconds(_event_snapshot[index]) > time_seconds:
			return index
	return _event_snapshot.size()


## 清空目标源并重放截至 elapsed_seconds 的事件以重建状态，同时在清源和每次写入后验证操作代际。
## recording 或 source 为空时只更新事件游标并返回状态是否仍有效。
## [br]
## @api private
## [br]
func _rebuild_source_state_at_elapsed_time(
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource,
	operation_was_playing: bool
) -> bool:
	_next_event_index = 0
	if operation_recording == null:
		return _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			operation_was_playing
		)
	if operation_source == null:
		_next_event_index = _find_next_event_index(elapsed_seconds)
		return _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			operation_was_playing
		)
	operation_source.clear_all()
	if not _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		operation_was_playing
	):
		return false
	while _next_event_index < _event_snapshot.size():
		var event: Dictionary = _event_snapshot[_next_event_index]
		if _get_event_time_seconds(event) > elapsed_seconds + 0.0001:
			break
		_next_event_index += 1
		var _applied: bool = _apply_event(event, operation_source)
		if not _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			operation_was_playing
		):
			return false
	return true


## 在循环模式下消费本次推进时间，跨越录制末尾时重置周期，并按预算延后剩余时间或跳过完整周期。
## 事件与追赶限制信号发出后都会检查代际，避免旧 tick 继续修改回调启动的新回放。
## [br]
## @api private
## [br]
func _tick_looping(
	advance_seconds: float,
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource
) -> int:
	var applied: int = _apply_due_events(
		operation_epoch,
		operation_recording,
		operation_source
	)
	if not _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		true
	):
		return applied
	var remaining: float = advance_seconds
	var completed_cycles: int = 0
	while remaining > 0.0:
		var time_to_end: float = maxf(_duration_seconds - elapsed_seconds, 0.0)
		if remaining < time_to_end:
			elapsed_seconds += remaining
			applied += _apply_due_events(
				operation_epoch,
				operation_recording,
				operation_source
			)
			return applied

		elapsed_seconds = _duration_seconds
		applied += _apply_due_events(
			operation_epoch,
			operation_recording,
			operation_source
		)
		if not _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			true
		):
			return applied
		remaining = maxf(remaining - time_to_end, 0.0)
		completed_cycles += 1
		if not _begin_loop_cycle(
			operation_epoch,
			operation_recording,
			operation_source
		):
			return applied

		if completed_cycles >= max_loop_cycles_per_tick and remaining >= _duration_seconds:
			if loop_catch_up_policy == LoopCatchUpPolicy.DEFER_EXCESS:
				_pending_advance_seconds = remaining
				applied += _apply_due_events(
					operation_epoch,
					operation_recording,
					operation_source
				)
				if not _is_playback_state_current(
					operation_epoch,
					operation_recording,
					operation_source,
					true
				):
					return applied
				loop_catch_up_limited.emit(_pending_advance_seconds, 0)
				var _still_current_after_limit: bool = _is_playback_state_current(
					operation_epoch,
					operation_recording,
					operation_source,
					true
				)
				return applied
			var skipped_cycles_float: float = floor(remaining / _duration_seconds)
			var skipped_cycles: int = int(minf(
				skipped_cycles_float,
				_MAX_REPORTED_SKIPPED_CYCLES
			))
			remaining = fmod(remaining, _duration_seconds)
			loop_catch_up_limited.emit(0.0, skipped_cycles)
			if not _is_playback_state_current(
				operation_epoch,
				operation_recording,
				operation_source,
				true
			):
				return applied

		applied += _apply_due_events(
			operation_epoch,
			operation_recording,
			operation_source
		)
		if not _is_playback_state_current(
			operation_epoch,
			operation_recording,
			operation_source,
			true
		):
			return applied
	return applied


## 开始一个循环周期：时间和事件索引归零，清空目标输入源，然后确认原回放仍有效。
## [br]
## @api private
## [br]
func _begin_loop_cycle(
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource
) -> bool:
	elapsed_seconds = 0.0
	_next_event_index = 0
	if operation_source != null:
		operation_source.clear_all()
	return _is_playback_state_current(
		operation_epoch,
		operation_recording,
		operation_source,
		true
	)


## 将 delta 和 speed 转成有限非负推进秒数；任一输入无效或乘积非有限时返回 0。
## [br]
## @api private
## [br]
func _get_advance_seconds(delta: float) -> float:
	if is_nan(delta) or is_inf(delta) or is_nan(speed) or is_inf(speed):
		return 0.0
	var result: float = maxf(delta, 0.0) * maxf(speed, 0.0)
	return result if not is_nan(result) and not is_inf(result) else 0.0


## 将时间规范为有限非负值；NaN、无穷值转换为 0。
## [br]
## @api private
## [br]
func _normalize_non_negative_time(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)


## 安全相加两个时间值；结果非有限时返回两者较大值，否则将结果下限钳为 0。
## [br]
## @api private
## [br]
func _safe_add_time(left: float, right: float) -> float:
	var result: float = left + right
	if is_nan(result) or is_inf(result):
		return maxf(left, right)
	return maxf(result, 0.0)


## 校验操作代际、录制对象、输入源和播放状态是否仍与操作开始时一致。
## 若代际未变但录制或输入源引用已被替换，会递增代际并停止播放；其他失配只返回 false。
## [br]
## @api private
## [br]
func _is_playback_state_current(
	operation_epoch: int,
	operation_recording: GFInputRecording,
	operation_source: GFVirtualInputSource,
	operation_was_playing: bool
) -> bool:
	var is_current: bool = (
		_playback_epoch == operation_epoch
		and recording == operation_recording
		and source == operation_source
		and is_playing == operation_was_playing
	)
	if is_current:
		return true
	if (
		_playback_epoch == operation_epoch
		and (recording != operation_recording or source != operation_source)
	):
		_playback_epoch += 1
		is_playing = false
	return false


## 读取事件的 time_seconds 字段并转换为 float。
## [br]
## @api private
## [br]
func _get_event_time_seconds(event: Dictionary) -> float:
	return GFVariantData.get_option_float(event, "time_seconds")


## 读取事件的 action_id 字段并转换为 StringName。
## [br]
## @api private
## [br]
func _get_event_action_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "action_id")


## 读取事件的 value 字段并保留其 Variant 值。
## [br]
## @api private
## [br]
func _get_event_value(event: Dictionary) -> Variant:
	return GFVariantData.get_option_value(event, "value", false)


## 读取事件的 player_index 字段；缺少字段时返回 -1。
## [br]
## @api private
## [br]
func _get_event_player_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, "player_index", -1)
