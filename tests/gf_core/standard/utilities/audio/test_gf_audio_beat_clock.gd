## 测试 GFAudioBeatClock 的节拍采样、边界事件和量化。
extends GutTest


# --- 测试方法 ---

## 验证时钟会把播放时间映射为 beat 和 measure 快照。
func test_audio_beat_clock_samples_position() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(120.0, 4, 0.0)

	var snapshot: Dictionary = clock.sample(1.25)

	assert_eq(GFVariantData.get_option_int(snapshot, "beat_index"), 2, "120 BPM 时 1.25 秒应落在第 2 个 beat。")
	assert_eq(GFVariantData.get_option_int(snapshot, "beat_in_measure"), 2, "每小节 4 拍时第 2 个 beat 应在小节内索引 2。")
	assert_eq(GFVariantData.get_option_int(snapshot, "measure_index"), 0, "1.25 秒仍在第 0 小节。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "beat_progress"), 0.5, 0.001, "1.25 秒应处于当前 beat 中点。")


## 验证 update 会补发越过的 beat 和 measure 边界。
func test_audio_beat_clock_emits_crossed_boundaries() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(120.0, 4, 0.0)
	var beats: Array[int] = []
	var measures: Array[int] = []
	var _beat_connected: Error = clock.beat_reached.connect(func(beat_index: int, _beat_in_measure: int, _position_seconds: float) -> void:
		beats.append(beat_index)
	) as Error
	var _measure_connected: Error = clock.measure_reached.connect(func(measure_index: int, _beat_index: int, _position_seconds: float) -> void:
		measures.append(measure_index)
	) as Error

	var _initial_snapshot: Dictionary = clock.update(0.0)
	var _later_snapshot: Dictionary = clock.update(2.1)

	assert_eq(beats, [1, 2, 3, 4], "从第 0 拍推进到第 4 拍时应补发中间边界。")
	assert_eq(measures, [1], "第 4 拍是第 1 小节起点。")


## 验证边界回调中修改状态不会被 update 结尾覆盖。
func test_audio_beat_clock_boundary_callback_can_reset_state() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(120.0, 4, 0.0)
	var reset_done: Array[bool] = [false]
	var _beat_connected: Error = clock.beat_reached.connect(func(_beat_index: int, _beat_in_measure: int, _position_seconds: float) -> void:
		if reset_done[0]:
			return
		reset_done[0] = true
		var _reset_snapshot: Dictionary = clock.reset(0.0)
	) as Error

	var _initial_snapshot: Dictionary = clock.update(0.0)
	var _later_snapshot: Dictionary = clock.update(2.1)

	assert_true(reset_done[0], "推进时应触发至少一个 beat 回调。")
	assert_almost_eq(clock.get_last_position_seconds(), 0.0, 0.001, "回调中的 reset 不应被 update 末尾覆盖。")


## 验证同一次 update 内的边界位置使用采样时的节拍参数。
func test_audio_beat_clock_boundary_positions_use_sampled_timing() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(120.0, 4, 0.0)
	var positions: Array[float] = []
	var _beat_connected: Error = clock.beat_reached.connect(func(beat_index: int, _beat_in_measure: int, position_seconds: float) -> void:
		positions.append(position_seconds)
		if beat_index == 1:
			clock.configure(60.0, 4, 1.0, false)
	) as Error

	var _initial_snapshot: Dictionary = clock.update(0.0)
	var _later_snapshot: Dictionary = clock.update(2.1)

	assert_eq(positions.size(), 4, "推进到第 4 拍应发出 4 个 beat 边界。")
	assert_almost_eq(positions[0], 0.5, 0.001, "第 1 拍位置应使用采样时的 BPM。")
	assert_almost_eq(positions[1], 1.0, 0.001, "后续边界不应被回调中修改 BPM 影响。")
	assert_almost_eq(positions[2], 1.5, 0.001, "后续边界不应被回调中修改 offset 影响。")
	assert_almost_eq(positions[3], 2.0, 0.001, "同一 update 内的边界时间应一致。")


## 验证 reset 会建立当前位置但不发出历史边界。
func test_audio_beat_clock_reset_skips_past_boundaries() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(60.0, 4, 0.0)
	var beat_state: Dictionary = {"count": 0}
	var _beat_connected: Error = clock.beat_reached.connect(func(_beat_index: int, _beat_in_measure: int, _position_seconds: float) -> void:
		beat_state["count"] = GFVariantData.to_int(beat_state.get("count", 0), 0) + 1
	) as Error

	var _reset_snapshot: Dictionary = clock.reset(8.0)
	var _update_snapshot: Dictionary = clock.update(8.1)

	assert_eq(GFVariantData.to_int(beat_state.get("count", 0), 0), 0, "reset 后短距离推进不应补发 reset 前的历史 beat。")
	assert_true(clock.has_last_position(), "reset 后应有上一帧状态。")


## 验证时钟可从外部位置来源采样。
func test_audio_beat_clock_updates_from_source() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	var current_position: float = 0.75
	clock.configure(120.0, 4, 0.0)
	clock.set_position_source(func() -> float:
		return current_position
	)

	var snapshot: Dictionary = clock.update_from_source()

	assert_eq(GFVariantData.get_option_int(snapshot, "beat_index"), 1, "位置来源返回 0.75 秒时应落在第 1 个 beat。")
	assert_almost_eq(clock.get_last_position_seconds(), 0.75, 0.001, "update_from_source 应刷新上一帧时间。")


## 验证 offset 和量化保持通用时间网格语义。
func test_audio_beat_clock_quantizes_with_offset() -> void:
	var clock: GFAudioBeatClock = GFAudioBeatClock.new()
	clock.configure(120.0, 4, 0.25)

	assert_almost_eq(clock.quantize_position(0.1), 0.25, 0.001, "offset 后最近 beat 边界应回到 0.25 秒。")
	assert_almost_eq(clock.quantize_position(0.76, 2, GFAudioBeatClock.QuantizeMode.FLOOR), 0.75, 0.001, "细分量化 floor 应使用 half-beat 网格。")
