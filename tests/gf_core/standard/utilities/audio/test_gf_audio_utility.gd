extends GutTest


var _audio: GFAudioUtility
var _pool: GFObjectPoolUtility
var _created_audio_buses: PackedStringArray = PackedStringArray()


class MockAssetUtility:
	extends GFAssetUtility

	var pending: Dictionary = {}

	func load_async(path: String, on_loaded: Callable, _type_hint: String = "", _options: Dictionary = {}) -> void:
		pending[path] = on_loaded

	func finish(path: String, resource: Resource) -> void:
		if not pending.has(path):
			return

		var callback_value: Variant = GFVariantData.get_option_value(pending, path)
		if not (callback_value is Callable):
			return
		var callback: Callable = callback_value
		var _erase_result_25: Variant = pending.erase(path)
		callback.call(resource)


class AssetBackedAudioUtility:
	extends GFAudioUtility

	var mock_asset_util: GFAssetUtility

	func _init(asset_util: GFAssetUtility) -> void:
		mock_asset_util = asset_util

	func _get_asset_util() -> GFAssetUtility:
		return mock_asset_util


class RecordingAudioUtility:
	extends AssetBackedAudioUtility

	var sfx_play_count: int = 0

	func _init(asset_util: GFAssetUtility) -> void:
		super(asset_util)

	func _play_sfx_stream(stream: AudioStream) -> AudioStreamPlayer:
		sfx_play_count += 1
		return super._play_sfx_stream(stream)


class FailingSpatialSettings:
	extends Resource

	func apply_to_2d(_player: AudioStreamPlayer2D) -> bool:
		return false

	func apply_to_3d(_player: AudioStreamPlayer3D) -> bool:
		return false


class MockAudioBackend:
	extends GFAudioBackend

	var setup_called: bool = false
	var disposed: bool = false
	var handle_bgm_paths: bool = false
	var handle_ambient_paths: bool = false
	var played_bgm_paths: PackedStringArray = PackedStringArray()
	var played_ambient_paths: PackedStringArray = PackedStringArray()
	var played_sfx_paths: PackedStringArray = PackedStringArray()
	var posted_events: PackedStringArray = PackedStringArray()
	var handle_posted_events: bool = true
	var parameter_values: Dictionary = {}
	var last_bgm_options: Dictionary = {}
	var handle_spatial_sfx_clips: bool = false
	var spatial_sfx_clip_count: int = 0
	var last_spatial_source: Node = null
	var last_spatial_follow_source: bool = false
	var last_spatial_sfx_options: Dictionary = {}
	var pause_bgm_fade: float = -1.0
	var resume_bgm_position: float = -1.0
	var resume_bgm_fade: float = -1.0
	var seek_bgm_position: float = -1.0
	var bgm_position: float = -1.0
	var bgm_playing: bool = false
	var is_bgm_playing_count: int = 0
	var bgm_paused: bool = false
	var is_bgm_paused_count: int = 0
	var stop_bgm_count: int = 0
	var allow_stop_bgm: bool = true
	var stopped_ambient_channels: PackedStringArray = PackedStringArray()
	var allow_stop_ambient: bool = true
	var stop_ambient_results: Dictionary = {}
	var stop_all_ambient_count: int = 0
	var allow_stop_all_ambient: bool = false
	var backend_ambient_playing: Dictionary = {}
	var is_ambient_playing_count: int = 0
	var stop_all_sfx_fade: float = -1.0
	var external_volume: float = -1.0
	var external_volume_db: float = 0.0
	var external_muted: bool = false
	var external_mute_observable: bool = true
	var handled_mix_snapshot: Dictionary = {}
	var handled_mix_transition: float = -1.0
	var effect_property_requests: Array[Dictionary] = []

	func _init() -> void:
		capabilities.supports_sfx = true
		capabilities.supports_events = true
		capabilities.supports_parameters = true

	func setup(host: Object) -> void:
		super.setup(host)
		setup_called = get_host() == host

	func dispose() -> void:
		disposed = true
		super.dispose()

	func can_handle_path(path: String, channel: StringName, _context: Dictionary = {}) -> bool:
		if channel == &"bgm":
			return handle_bgm_paths and path.begins_with("event://")
		if channel == &"ambient":
			return handle_ambient_paths and path.begins_with("event://")
		return channel == &"sfx" and path.begins_with("event://")

	func can_handle_clip(_clip: GFAudioClip, channel: StringName, context: Dictionary = {}) -> bool:
		return handle_spatial_sfx_clips and channel == &"spatial_sfx" and context.has("source")

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var _append_result_106: Variant = played_bgm_paths.append(path)
		last_bgm_options = options.duplicate(true)
		bgm_playing = true
		return true

	func stop_bgm(_fade_seconds: float = 0.0) -> bool:
		stop_bgm_count += 1
		if allow_stop_bgm:
			bgm_playing = false
			bgm_paused = false
		return allow_stop_bgm

	func pause_bgm(fade_seconds: float = 0.0) -> bool:
		pause_bgm_fade = fade_seconds
		bgm_paused = true
		return true

	func resume_bgm(from_position: float = -1.0, fade_seconds: float = 0.0) -> bool:
		resume_bgm_position = from_position
		resume_bgm_fade = fade_seconds
		bgm_paused = false
		return true

	func seek_bgm(position_seconds: float) -> bool:
		seek_bgm_position = position_seconds
		bgm_position = position_seconds
		return true

	func get_bgm_playback_position() -> float:
		return bgm_position

	func is_bgm_playing() -> bool:
		is_bgm_playing_count += 1
		return bgm_playing

	func is_bgm_paused() -> bool:
		is_bgm_paused_count += 1
		return bgm_paused

	func play_ambient_path(
		path: String,
		channel: StringName = &"default",
		_options: Dictionary = {}
	) -> bool:
		var _append_result_159: Variant = played_ambient_paths.append(path)
		backend_ambient_playing[channel] = true
		return true

	func stop_ambient(channel: StringName = &"default", _fade_seconds: float = 0.0) -> bool:
		var _append_result_164: Variant = stopped_ambient_channels.append(String(channel))
		var handled: bool = (
			GFVariantData.get_option_bool(stop_ambient_results, channel)
			if stop_ambient_results.has(channel)
			else allow_stop_ambient
		)
		if handled:
			backend_ambient_playing[channel] = false
		return handled

	func stop_all_ambient(_fade_seconds: float = 0.0) -> bool:
		stop_all_ambient_count += 1
		if allow_stop_all_ambient:
			for channel_variant: Variant in backend_ambient_playing.keys():
				backend_ambient_playing[channel_variant] = false
		return allow_stop_all_ambient

	func is_ambient_playing(channel: StringName = &"default") -> bool:
		is_ambient_playing_count += 1
		return GFVariantData.get_option_bool(backend_ambient_playing, channel)

	func play_sfx_path(path: String, options: Dictionary = {}) -> GFAudioEmitterHandle:
		var _append_result_133: Variant = played_sfx_paths.append(path)
		return GFAudioEmitterHandle.new(null, Callable(), &"backend", options)

	func play_spatial_sfx_clip(
		_clip: GFAudioClip,
		source: Node,
		follow_source: bool = false,
		options: Dictionary = {}
	) -> GFAudioEmitterHandle:
		spatial_sfx_clip_count += 1
		last_spatial_source = source
		last_spatial_follow_source = follow_source
		last_spatial_sfx_options = options.duplicate(true)
		return GFAudioEmitterHandle.new(null, Callable(), &"spatial_sfx", options)

	func stop_all_sfx(fade_seconds: float = 0.0) -> bool:
		stop_all_sfx_fade = fade_seconds
		return true

	func can_handle_event(event: GFAudioEvent, _options: Dictionary = {}) -> bool:
		return event.event_id != &""

	func post_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:
		var _append_result_156: Variant = posted_events.append(String(event.event_id))
		if not handle_posted_events:
			return null
		return GFAudioEmitterHandle.new(null, Callable(), &"event", options)

	func set_parameter(parameter: GFAudioParameter) -> bool:
		parameter_values[parameter.parameter_id] = parameter.value
		return true

	func set_bus_volume(bus_name: String, volume_linear: float) -> bool:
		if bus_name != "External":
			return false
		external_volume = volume_linear
		return true

	func set_bus_volume_db(bus_name: String, volume_db: float, _transition_seconds: float = 0.0) -> bool:
		if bus_name != "External":
			return false
		external_volume_db = volume_db
		external_volume = db_to_linear(volume_db)
		return true

	func set_bus_mute(bus_name: String, muted: bool) -> bool:
		if bus_name != "External":
			return false
		external_muted = muted
		return true

	func set_bus_effect_property(
		bus_name: String,
		effect_ref: Variant,
		property_name: StringName,
		value: Variant,
		transition_seconds: float = 0.0
	) -> bool:
		if bus_name != "External":
			return false
		effect_property_requests.append({
			"effect_ref": effect_ref,
			"property_name": property_name,
			"value": value,
			"transition_seconds": transition_seconds,
		})
		return true

	func apply_mix_snapshot(snapshot: Dictionary, transition_seconds: float = 0.0) -> bool:
		if not GFVariantData.get_option_bool(snapshot, "backend_only"):
			return false
		handled_mix_snapshot = snapshot.duplicate(true)
		handled_mix_transition = transition_seconds
		return true

	func get_bus_volume(bus_name: String) -> float:
		return external_volume if bus_name == "External" else -1.0

	func get_bus_mute(bus_name: String) -> Variant:
		if bus_name != "External" or not external_mute_observable:
			return null
		return external_muted

	func get_debug_snapshot() -> Dictionary:
		return {
			"played_sfx_count": played_sfx_paths.size(),
			"disposed": disposed,
		}


class ReentrantAudioBackend:
	extends MockAudioBackend

	enum ReentryStage {
		NONE,
		CAN_HANDLE_PATH,
		PLAY_BGM_PATH,
		STOP_BGM,
		STOP_AMBIENT,
		IS_BGM_PLAYING,
		IS_BGM_PAUSED,
	}

	var reentry_stage: ReentryStage = ReentryStage.NONE
	var reentrant_bgm_path: String = "event://music/reentrant"
	var reentrant_ambient_path: String = "event://ambient/reentrant"
	var replacement_backend: GFAudioBackend = null
	var replacement_result: Variant = null
	var reentry_count: int = 0

	func can_handle_path(path: String, channel: StringName, context: Dictionary = {}) -> bool:
		if channel == &"bgm":
			_attempt_reentry(ReentryStage.CAN_HANDLE_PATH)
		return super.can_handle_path(path, channel, context)

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var handled: bool = super.play_bgm_path(path, options)
		_attempt_reentry(ReentryStage.PLAY_BGM_PATH)
		return handled

	func stop_bgm(fade_seconds: float = 0.0) -> bool:
		var handled: bool = super.stop_bgm(fade_seconds)
		_attempt_reentry(ReentryStage.STOP_BGM)
		return handled

	func stop_ambient(channel: StringName = &"default", fade_seconds: float = 0.0) -> bool:
		var handled: bool = super.stop_ambient(channel, fade_seconds)
		_attempt_reentry(ReentryStage.STOP_AMBIENT, channel)
		return handled

	func is_bgm_paused() -> bool:
		var paused: bool = super.is_bgm_paused()
		_attempt_reentry(ReentryStage.IS_BGM_PAUSED)
		return paused

	func is_bgm_playing() -> bool:
		var playing: bool = super.is_bgm_playing()
		_attempt_reentry(ReentryStage.IS_BGM_PLAYING)
		return playing

	func _attempt_reentry(stage: ReentryStage, channel: StringName = &"default") -> void:
		if reentry_stage != stage:
			return
		reentry_stage = ReentryStage.NONE
		reentry_count += 1
		var host_value: Object = get_host()
		if not host_value is GFAudioUtility:
			return
		var host: GFAudioUtility = host_value
		if stage == ReentryStage.STOP_AMBIENT:
			host.play_ambient(reentrant_ambient_path, channel)
		else:
			host.play_bgm(reentrant_bgm_path)
		if replacement_backend != null:
			replacement_result = host.call("set_audio_backend", replacement_backend)


class DisposingBgmQueryBackend:
	extends MockAudioBackend

	var dispose_host_on_playing_query: bool = false

	func is_bgm_playing() -> bool:
		var playing: bool = super.is_bgm_playing()
		if not dispose_host_on_playing_query:
			return playing
		dispose_host_on_playing_query = false
		var host_value: Object = get_host()
		if host_value is GFAudioUtility:
			var host: GFAudioUtility = host_value
			host.dispose()
		return playing


func before_each() -> void:
	_created_audio_buses.clear()
	_ensure_test_audio_bus(GFAudioUtility.BGM_BUS_NAME)
	_ensure_test_audio_bus(GFAudioUtility.SFX_BUS_NAME)

	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch # 提早设置引用以便可以使用 Gf 全局代理
	
	_pool = GFObjectPoolUtility.new()
	await Gf.register_utility(_pool)
	
	_audio = GFAudioUtility.new()
	await Gf.register_utility(_audio)
	
	await Gf.set_architecture(arch) # 正式执行三阶段初始化
	await get_tree().process_frame


func after_each() -> void:
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())
	_remove_created_audio_buses()
	await get_tree().process_frame


func _ensure_test_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return

	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	var _append_result_250: Variant = _created_audio_buses.append(bus_name)


func _remove_created_audio_buses() -> void:
	for index: int in range(_created_audio_buses.size() - 1, -1, -1):
		var bus_name: String = _created_audio_buses[index]
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.remove_bus(bus_index)
	_created_audio_buses.clear()


func test_play_bgm() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream(stream)
	
	assert_true(_audio._bgm_player.playing, "BGM 应该正在播放。")
	assert_eq(_audio._bgm_player.stream, stream, "BGM 的 Stream 应该对应。")
	
	_audio.play_bgm("")
	assert_false(_audio._bgm_player.playing, "传入空路径应停止播放。")


func test_play_bgm_empty_path_respects_crossfade() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream(stream)

	_audio.play_bgm("", 0.05)

	assert_true(_audio._bgm_player.playing, "传入淡出时间时，空路径停止 BGM 应先执行淡出。")
	await get_tree().create_timer(0.08).timeout
	assert_false(_audio._bgm_player.playing, "淡出完成后 BGM 应停止播放。")


func test_bgm_transport_controls_default_player() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream(stream)

	assert_true(_audio.pause_bgm(), "默认播放器应支持暂停 BGM。")
	assert_true(_audio.is_bgm_paused(), "暂停后查询应返回已暂停。")
	assert_true(_audio._bgm_player.stream_paused, "默认播放器应使用 Godot 的 stream_paused。")
	assert_true(_audio.seek_bgm(0.0), "默认播放器应支持跳转。")
	assert_true(_audio.resume_bgm(-1.0), "默认播放器应支持恢复。")
	assert_false(_audio.is_bgm_paused(), "恢复后查询应返回未暂停。")
	assert_false(_audio._bgm_player.stream_paused, "恢复后应解除 Godot 暂停状态。")
	assert_almost_eq(_audio.get_bgm_playback_position(), 0.0, 0.2, "默认播放器应能查询播放位置。")


func test_bgm_resume_cancels_pending_pause_fade() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream(stream)

	assert_true(_audio.pause_bgm(0.05), "淡出暂停应开始。")
	assert_true(_audio.resume_bgm(-1.0), "淡出尚未完成时也应能立即恢复。")
	await get_tree().create_timer(0.08).timeout

	assert_false(_audio.is_bgm_paused(), "恢复后迟到的暂停 tween 不应再次暂停 BGM。")
	assert_false(_audio._bgm_player.stream_paused, "恢复后底层播放器不应被迟到回调暂停。")
	assert_almost_eq(_audio._bgm_player.volume_db, 0.0, 0.001, "恢复后迟到的暂停 tween 不应把音量留在淡出值。")


func test_bgm_transport_delegates_to_backend() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.bgm_position = 12.5
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/transport")

	assert_true(_audio.pause_bgm(0.2), "后端可接管 BGM 暂停。")
	assert_true(_audio.is_bgm_paused(), "后端暂停状态应暴露给查询接口。")
	assert_true(_audio.resume_bgm(3.0, 0.1), "后端可接管 BGM 恢复。")
	assert_true(_audio.seek_bgm(8.0), "后端可接管 BGM 跳转。")
	assert_almost_eq(backend.pause_bgm_fade, 0.2, 0.001, "暂停淡出时间应传给后端。")
	assert_almost_eq(backend.resume_bgm_position, 3.0, 0.001, "恢复位置应传给后端。")
	assert_almost_eq(backend.resume_bgm_fade, 0.1, 0.001, "恢复淡入时间应传给后端。")
	assert_almost_eq(backend.seek_bgm_position, 8.0, 0.001, "跳转位置应传给后端。")
	assert_almost_eq(_audio.get_bgm_playback_position(), 8.0, 0.001, "播放位置应优先读取后端。")


func test_bgm_paused_query_refreshes_backend_owned_session_state() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/query-state")

	backend.bgm_paused = true
	assert_true(_audio.is_bgm_paused(), "backend-owned BGM 应读取后端当前暂停状态。")
	assert_eq(_audio._bgm_state, &"paused", "后端查询结果应同步收敛内部状态。")

	backend.bgm_paused = false
	assert_false(_audio.is_bgm_paused(), "后端恢复播放后查询不得返回陈旧暂停缓存。")
	assert_eq(_audio._bgm_state, &"playing", "后端恢复结果应同步收敛内部状态。")
	assert_eq(backend.is_bgm_paused_count, 2, "每次稳定查询应且只应派发一次后端调用。")


func test_audio_backend_bgm_playing_query_defaults_fail_closed() -> void:
	var backend: GFAudioBackend = GFAudioBackend.new()
	assert_false(
		backend.is_bgm_playing(),
		"未实现 BGM session 查询的后端必须默认 fail closed。"
	)


func test_backend_bgm_natural_end_converges_snapshot_and_emits_once() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	watch_signals(_audio)
	_audio.play_bgm_with_options("event://music/natural-end", {
		"history_key": "backend-natural-end",
	})
	backend.bgm_playing = false

	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_false(GFVariantData.get_option_bool(snapshot, "bgm_playing", true))
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"stopped")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"none")
	assert_eq(GFVariantData.get_option_string(snapshot, "current_bgm_key"), "")
	assert_signal_emitted_with_parameters(
		_audio,
		"bgm_finished",
		["backend-natural-end"]
	)
	assert_signal_emit_count(_audio, "bgm_finished", 1)

	assert_false(_audio.is_bgm_playing(), "已提交自然结束的会话不得再次查询成 playing。")
	assert_signal_emit_count(_audio, "bgm_finished", 1)
	assert_eq(backend.is_bgm_playing_count, 1, "自然结束提交后不得重复查询旧 backend session。")


func test_backend_bgm_pause_still_counts_as_playing() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/paused")
	assert_true(_audio.pause_bgm(), "测试后端应接受暂停。")

	assert_true(_audio.is_bgm_playing(), "暂停中的 backend BGM session 仍应存在。")
	assert_true(_audio.is_bgm_paused(), "暂停状态应继续由独立查询报告。")
	assert_eq(_audio._bgm_state, &"paused")
	assert_eq(_audio._bgm_owner, &"backend")


func test_play_bgm_with_options_passes_loop_to_backend_and_debug_snapshot() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	_audio.play_bgm_with_options("event://music/title", {
		"crossfade_seconds": 0.25,
		"history_key": "title",
		"loop": false,
	})
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(backend.played_bgm_paths, PackedStringArray(["event://music/title"]), "后端声明可处理时应接管 BGM 路径。")
	assert_false(GFVariantData.get_option_bool(backend.last_bgm_options, "loop"), "loop 覆盖选项应传给后端。")
	assert_almost_eq(GFVariantData.get_option_float(backend.last_bgm_options, "crossfade_seconds"), 0.25, 0.001, "crossfade 应规范化后传给后端。")
	assert_eq(_audio.get_current_bgm_key(), "title", "后端播放也应记录 BGM 历史 key。")
	assert_false(GFVariantData.get_option_bool(snapshot, "current_bgm_loop"), "调试快照应记录当前 loop 覆盖值。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"backend", "调试快照应公开唯一 BGM owner。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"playing", "调试快照应公开 BGM 状态。")
	assert_gt(GFVariantData.get_option_int(snapshot, "bgm_generation"), 0, "调试快照应公开递增的 BGM generation。")


func test_bgm_finished_signal_emits_for_active_player() -> void:
	watch_signals(_audio)
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream_with_settings(stream, GFAudioUtility.BGM_BUS_NAME, 0.0, 1.0, -1.0, "finish-test")

	_audio._bgm_player.finished.emit()

	assert_signal_emitted_with_parameters(_audio, "bgm_finished", ["finish-test"])
	assert_eq(_audio.get_current_bgm_key(), "", "自然结束后当前 BGM key 应清空。")


func test_play_bgm_clip_applies_settings() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"
	clip.volume_db = -6.0
	clip.pitch_scale = 1.25

	_audio.play_bgm_clip(clip)

	assert_eq(_audio._bgm_player.stream, stream, "BGM Clip 应写入对应音频流。")
	assert_eq(_audio._bgm_player.bus, "Master", "BGM Clip 应应用总线配置。")
	assert_almost_eq(_audio._bgm_player.volume_db, -6.0, 0.001, "BGM Clip 应应用音量配置。")
	assert_almost_eq(_audio._bgm_player.pitch_scale, 1.25, 0.001, "BGM Clip 应应用音高配置。")


func test_play_bgm_clip_tracks_history() -> void:
	var first: GFAudioClip = GFAudioClip.new()
	first.path = "res://audio/first.ogg"
	first.stream = AudioStreamGenerator.new()
	var second: GFAudioClip = GFAudioClip.new()
	second.path = "res://audio/second.ogg"
	second.stream = AudioStreamGenerator.new()

	_audio.max_bgm_history = 1
	_audio.play_bgm_clip(first)
	_audio.play_bgm_clip(second)

	var history: PackedStringArray = _audio.get_bgm_history()
	assert_eq(history.size(), 1, "BGM 历史应遵守容量上限。")
	assert_eq(history[0], "res://audio/second.ogg", "历史中应保留最新 BGM key。")
	assert_eq(_audio.get_current_bgm_key(), "res://audio/second.ogg", "当前 BGM key 应指向最新请求。")


func test_play_sfx_and_pool() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var _play_sfx_stream_result_393: Variant = _audio._play_sfx_stream(stream)
	
	var available: int = _pool.get_available_count(_audio._sfx_scene)
	assert_eq(available, 0, "最初分配的播放器应该在使用中。")
	
	var players_in_root: int = 0
	for child: Node in _audio._root.get_children():
		if child is AudioStreamPlayer and child.get_meta("_gf_pool_active", false):
			var player: AudioStreamPlayer = child
			players_in_root += 1
			player.finished.emit()
	
	assert_eq(players_in_root, 1, "应该有一个激活的 SFX 播放器。")
	assert_eq(_pool.get_available_count(_audio._sfx_scene), 1, "SFX 播放器响应 finished 后应该回收到池中。")


func test_play_sfx_without_object_pool_creates_direct_player() -> void:
	var local_arch: GFArchitecture = GFArchitecture.new()
	var audio: GFAudioUtility = GFAudioUtility.new()
	await local_arch.register_utility_instance(audio)
	await local_arch.init()
	await get_tree().process_frame

	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var player: AudioStreamPlayer = audio._play_sfx_stream(stream)

	assert_not_null(player, "未注册对象池时 SFX 仍应创建普通播放器。")
	if player != null:
		assert_eq(player.stream, stream, "普通 SFX 播放器应写入对应音频流。")
		assert_eq(audio._active_sfx_players.size(), 1, "普通 SFX 播放器也应进入活跃列表。")
		assert_false(GFVariantData.to_bool(player.get_meta("_gf_pool_active", false)), "普通 SFX 播放器不应伪装为池化节点。")
		player.finished.emit()
		assert_eq(audio._active_sfx_players.size(), 0, "普通 SFX 播放结束后应移出活跃列表。")
		assert_true(player.is_queued_for_deletion(), "普通 SFX 播放结束后应直接释放节点。")

	local_arch.dispose()
	await get_tree().process_frame


func test_sfx_handle_can_stop_and_release_player() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"

	var handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)

	assert_not_null(handle, "SFX 句柄应被创建。")
	assert_true(handle.is_valid(), "播放后句柄应绑定播放器。")
	assert_eq(_audio._active_sfx_players.size(), 1, "播放后应有一个活跃 SFX 播放器。")

	handle.stop()

	assert_false(handle.is_valid(), "停止后句柄应释放播放器引用。")
	assert_eq(_audio._active_sfx_players.size(), 0, "停止句柄应从活跃 SFX 列表移除播放器。")
	assert_eq(_pool.get_available_count(_audio._sfx_scene), 1, "停止句柄应把播放器归还对象池。")


func test_naturally_finished_sfx_handle_cannot_control_reused_pool_player() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"
	var old_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var old_player: AudioStreamPlayer = old_handle.get_player() as AudioStreamPlayer

	old_player.finished.emit()
	var new_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var reused_player: AudioStreamPlayer = new_handle.get_player() as AudioStreamPlayer

	assert_false(old_handle.is_valid(), "自然结束必须立即终结旧播放句柄。")
	assert_same(reused_player, old_player, "测试应确认对象池复用了同一个播放器节点。")
	old_handle.stop()
	assert_true(new_handle.is_valid(), "旧句柄不得停止复用节点上的新播放 session。")
	assert_eq(_audio._active_sfx_players.size(), 1, "旧句柄操作后新 session 仍应保持活跃。")
	new_handle.stop()


func test_sfx_handle_can_bind_to_owner_exit() -> void:
	var owner_node: Node = Node.new()
	add_child(owner_node)
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"

	var handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	handle.bind_to_owner(owner_node)

	assert_true(handle.is_valid(), "绑定 owner 前应已经持有播放器。")
	owner_node.queue_free()
	await get_tree().process_frame

	assert_false(handle.is_valid(), "owner 退出树时句柄应自动停止并释放播放器。")
	assert_eq(_audio._active_sfx_players.size(), 0, "owner 自动停止后不应残留活跃 SFX。")
	assert_eq(_pool.get_available_count(_audio._sfx_scene), 1, "owner 自动停止后应归还对象池。")


func test_play_sfx_from_bank_applies_clip_settings() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"
	clip.volume_db = -3.0
	clip.pitch_scale = 0.8

	var bank: GFAudioBank = GFAudioBank.new()
	bank.set_clip(&"select", clip)

	_audio.play_sfx_from_bank(bank, &"select")

	assert_eq(_audio._active_sfx_players.size(), 1, "播放 SFX Clip 后应有一个活跃播放器。")
	var player: AudioStreamPlayer = _audio._active_sfx_players[0]
	assert_eq(player.stream, stream, "SFX Clip 应写入对应音频流。")
	assert_eq(player.bus, "Master", "SFX Clip 应应用总线配置。")
	assert_almost_eq(player.volume_db, -3.0, 0.001, "SFX Clip 应应用音量配置。")
	assert_almost_eq(player.pitch_scale, 0.8, 0.001, "SFX Clip 应应用音高配置。")


func test_audio_bank_supports_variants_and_fallback() -> void:
	var first: GFAudioClip = GFAudioClip.new()
	first.stream = AudioStreamGenerator.new()
	var second: GFAudioClip = GFAudioClip.new()
	second.stream = AudioStreamGenerator.new()
	second.weight = 3.0

	var bank: GFAudioBank = GFAudioBank.new()
	var clips: Array[GFAudioClip] = [first, second]
	bank.set_clips(&"ui+select", clips)

	assert_eq(bank.get_clip(&"ui+select"), first, "兼容 get_clip 时应返回第一个有效候选。")
	assert_eq(bank.get_clips(&"ui+select").size(), 2, "同一 ID 应可保存多个候选片段。")
	assert_eq(bank.get_clip_with_fallback(&"ui+select+primary"), first, "分层 ID 缺失时应逐级回退。")


func test_audio_bank_resolution_reports_fallback_and_validation() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var missing_clip: GFAudioClip = GFAudioClip.new()
	var bank: GFAudioBank = GFAudioBank.new()
	bank.set_clip(&"ui+select", clip)
	bank.set_clip(&"missing", missing_clip)

	var resolution: Dictionary = bank.resolve_clip(&"ui+select+primary")
	var report: GFValidationReport = bank.validate_bank()

	assert_true(GFVariantData.get_option_bool(resolution, "ok"), "解析报告应标记 fallback 命中成功。")
	assert_true(GFVariantData.get_option_bool(resolution, "fallback_used"), "解析报告应标记使用了 fallback。")
	assert_eq(GFVariantData.get_option_string_name(resolution, "resolved_id"), &"ui+select", "解析报告应记录最终命中的 ID。")
	assert_eq(bank.get_clip_ids(), PackedStringArray(["missing", "ui+select"]), "音频集合应能列出全部片段 ID。")
	assert_eq(report.get_warning_count(), 1, "缺少 stream/path 的片段应进入校验警告。")


func test_audio_bank_resolution_report_has_json_safe_export() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.path = "res://private/click.ogg"
	var bank: GFAudioBank = GFAudioBank.new()
	bank.set_clip(&"ui+select", clip)

	var resolution: Dictionary = bank.resolve_clip(&"ui+select")
	var exported: Dictionary = bank.to_json_compatible_resolution_report(resolution)
	var clip_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(exported, "clip"),
		"__gf_report_value__"
	)
	var json_text: String = JSON.stringify(exported)
	var raw_clip_value: Variant = GFVariantData.get_option_value(resolution, "clip")
	var raw_clip: GFAudioClip = null
	if raw_clip_value is GFAudioClip:
		raw_clip = raw_clip_value

	assert_same(raw_clip, clip, "raw 解析报告应保留运行时 clip。")
	assert_true(GFVariantData.get_option_bool(clip_marker, "redacted"), "JSON-safe 解析报告应脱敏 clip 资源。")
	assert_false(json_text.contains("private/click.ogg"), "JSON-safe 解析报告默认不应泄漏 clip 路径。")


func test_audio_clip_resolve_pitch_without_rng_uses_base_pitch() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.pitch_scale = 1.25
	clip.pitch_random_min = 0.5
	clip.pitch_random_max = 2.0

	assert_almost_eq(clip.resolve_pitch(null), 1.25, 0.001, "未传入 RNG 时应保持基础音高。")


func test_audio_clip_metadata_helpers_copy_nested_values() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	var source_tags: Array[String] = ["ui", "confirm"]

	clip.set_metadata_value("tags", source_tags)
	source_tags.append("mutated")
	clip.set_metadata_value(&"bpm", 120)

	var stored_tags: Array = GFVariantData.as_array(clip.get_metadata_value("tags"))
	var metadata_copy: Dictionary = clip.duplicate_metadata()
	var copied_tags: Array = GFVariantData.as_array(metadata_copy["tags"])
	copied_tags.append("copy_only")
	var bpm_value: int = GFVariantData.to_int(clip.get_metadata_value(&"bpm"))
	var original_tags: Array = GFVariantData.as_array(clip.metadata.get("tags", []))

	assert_true(clip.has_metadata_value("tags"), "元数据 helper 应能查询已有键。")
	assert_eq(stored_tags.size(), 2, "设置元数据时应复制集合值，避免外部数组继续污染片段。")
	assert_eq(bpm_value, 120, "StringName 元数据键应按原键读取。")
	assert_eq(original_tags.size(), 2, "duplicate_metadata 返回值修改不应影响原始元数据。")


func test_registered_audio_bank_event_uses_clip_settings() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"
	clip.pitch_scale = 0.5
	clip.pitch_random_min = 2.0
	clip.pitch_random_max = 2.0

	var bank: GFAudioBank = GFAudioBank.new()
	bank.set_clip(&"confirm", clip)
	_audio.register_audio_bank(&"ui", bank)
	_audio.play_sfx_event(&"confirm", &"ui")

	assert_eq(_audio._active_sfx_players.size(), 1, "事件式 SFX 应复用注册的音频集合。")
	var player: AudioStreamPlayer = _audio._active_sfx_players[0]
	assert_eq(player.stream, stream, "事件式 SFX 应播放对应音频流。")
	assert_almost_eq(player.pitch_scale, 1.0, 0.001, "事件式 SFX 应应用片段音高随机范围。")


func test_audio_bank_mounter_restores_previous_bank() -> void:
	var previous_bank: GFAudioBank = GFAudioBank.new()
	var mounted_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene", previous_bank)

	var mounter: GFAudioBankMounter = GFAudioBankMounter.new()
	mounter.bank_id = &"scene"
	mounter.bank = mounted_bank
	mounter.set_audio_utility(_audio)

	assert_true(mounter.mount(), "挂载器应能注册音频集合。")
	assert_same(_audio.get_audio_bank(&"scene"), mounted_bank, "挂载后应使用新音频集合。")
	assert_true(mounter.unmount(), "卸载应成功。")
	assert_same(_audio.get_audio_bank(&"scene"), previous_bank, "卸载后应恢复旧音频集合。")
	mounter.free()


func test_audio_bank_mounter_keeps_nested_mount_stack_consistent() -> void:
	var base_bank: GFAudioBank = GFAudioBank.new()
	var first_bank: GFAudioBank = GFAudioBank.new()
	var second_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene", base_bank)

	var first_mounter: GFAudioBankMounter = GFAudioBankMounter.new()
	first_mounter.bank_id = &"scene"
	first_mounter.bank = first_bank
	first_mounter.set_audio_utility(_audio)

	var second_mounter: GFAudioBankMounter = GFAudioBankMounter.new()
	second_mounter.bank_id = &"scene"
	second_mounter.bank = second_bank
	second_mounter.set_audio_utility(_audio)

	assert_true(first_mounter.mount(), "第一层挂载应成功。")
	assert_same(_audio.get_audio_bank(&"scene"), first_bank, "第一层挂载后应使用第一层 bank。")
	assert_true(second_mounter.mount(), "第二层挂载应成功。")
	assert_same(_audio.get_audio_bank(&"scene"), second_bank, "第二层挂载后应使用顶层 bank。")

	assert_true(first_mounter.unmount(), "先卸载下层挂载应成功。")
	assert_same(_audio.get_audio_bank(&"scene"), second_bank, "下层卸载不应覆盖仍处于顶层的 bank。")
	assert_true(second_mounter.unmount(), "最后卸载顶层挂载应成功。")
	assert_same(_audio.get_audio_bank(&"scene"), base_bank, "所有挂载卸载后应恢复基础 bank。")

	first_mounter.free()
	second_mounter.free()


func test_audio_bank_mounter_unmounts_original_bank_id_after_id_change() -> void:
	var base_bank: GFAudioBank = GFAudioBank.new()
	var mounted_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene_a", base_bank)

	var mounter: GFAudioBankMounter = GFAudioBankMounter.new()
	mounter.bank_id = &"scene_a"
	mounter.bank = mounted_bank
	mounter.set_audio_utility(_audio)

	assert_true(mounter.mount(), "测试应先成功挂载 scene_a。")
	mounter.bank_id = &"scene_b"

	assert_true(mounter.unmount(), "bank_id 变更后仍应能卸载原始挂载。")
	assert_same(_audio.get_audio_bank(&"scene_a"), base_bank, "卸载应恢复原始 bank ID 的基础 bank。")
	assert_null(_audio.get_audio_bank(&"scene_b"), "新 bank ID 不应误消费旧挂载 token。")
	mounter.free()


func test_audio_backend_can_handle_selected_requests() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	var handle: GFAudioEmitterHandle = _audio.play_sfx_handle("event://ui/click")
	_audio.set_bus_volume("External", 0.25)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var backend_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, "backend_snapshot")

	assert_true(backend.setup_called, "设置后端时应调用 setup。")
	assert_not_null(handle, "后端处理 SFX 时应返回句柄。")
	assert_eq(backend.played_sfx_paths, PackedStringArray(["event://ui/click"]), "声明可处理的路径应交给后端。")
	assert_almost_eq(_audio.get_bus_volume("External"), 0.25, 0.001, "后端可接管自定义总线音量。")
	assert_eq(GFVariantData.get_option_int(backend_snapshot, "played_sfx_count"), 1, "音频工具调试快照应包含后端快照。")

	assert_true(_audio.clear_audio_backend(), "无活动后端通道时应成功清理后端。")
	assert_true(backend.disposed, "清理后端时应调用 dispose。")


func test_audio_backend_receives_spatial_settings_context() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_spatial_sfx_clips = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var settings: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.spatial_settings = settings

	var handle: GFAudioEmitterHandle = _audio.play_sfx_clip_2d_handle(clip, source, true)

	assert_not_null(handle, "后端可处理时空间 SFX 应返回后端句柄。")
	assert_eq(backend.spatial_sfx_clip_count, 1, "空间 SFX 应交给后端处理。")
	assert_same(backend.last_spatial_source, source, "空间 SFX 声源应传给后端。")
	assert_true(backend.last_spatial_follow_source, "follow_source 应传给后端。")
	assert_eq(GFVariantData.get_option_string(backend.last_spatial_sfx_options, "space"), "2d", "空间维度应保留在后端选项中。")
	assert_same(_node_option(backend.last_spatial_sfx_options, "source"), source, "空间上下文应包含声源。")
	assert_same(_resource_option(backend.last_spatial_sfx_options, "spatial_settings"), settings, "空间设置资源应传给后端。")


func test_audio_backend_capabilities_events_and_parameters() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"ui_confirm"
	event.channel = &"sfx"
	var parameter: GFAudioParameter = GFAudioParameter.new()
	parameter.parameter_id = &"intensity"
	parameter.value = 0.75

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	var handled_parameter: bool = _audio.set_audio_parameter(parameter)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var capabilities: Dictionary = GFVariantData.get_option_dictionary(snapshot, "backend_capabilities")

	assert_not_null(handle, "后端处理资源化事件时应返回句柄。")
	assert_eq(backend.posted_events, PackedStringArray(["ui_confirm"]), "资源化事件应转交后端。")
	assert_true(handled_parameter, "声明支持参数的后端应可处理参数写入。")
	assert_almost_eq(GFVariantData.get_option_float(backend.parameter_values, &"intensity"), 0.75, 0.001, "参数值应传给后端。")
	assert_true(GFVariantData.get_option_bool(capabilities, "events"), "调试快照应包含后端事件能力。")
	assert_true(GFVariantData.get_option_bool(capabilities, "parameters"), "调试快照应包含后端参数能力。")


func test_backend_null_event_result_falls_back_to_local_dispatch() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_posted_events = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"ui_local_fallback"
	event.channel = &"sfx"
	event.clip = clip

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event)

	assert_eq(
		backend.posted_events,
		PackedStringArray(["ui_local_fallback"]),
		"后端声明可处理时应先收到事件请求。"
	)
	assert_not_null(handle, "后端返回 null 表示未处理，工具应继续本地事件回退。")
	if handle != null:
		assert_true(handle.is_valid(), "本地事件回退应返回绑定播放器的有效句柄。")
	assert_eq(_audio._active_sfx_players.size(), 1, "本地事件回退应实际创建普通 SFX 会话。")

	var bgm_event: GFAudioEvent = GFAudioEvent.new()
	bgm_event.event_id = &"music_local_fallback"
	bgm_event.channel = &"bgm"
	bgm_event.clip = clip
	var bgm_handle: GFAudioEmitterHandle = _audio.post_audio_event(bgm_event)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_null(bgm_handle, "本地 BGM 事件按 API 契约无需返回 emitter handle。")
	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "bgm_owner"),
		&"local",
		"后端事件返回 null 时，BGM channel 也应继续本地回退。"
	)
	assert_true(_audio._bgm_player.playing, "BGM 事件的本地回退应实际启动播放器。")


func test_audio_catalog_provider_lists_entries() -> void:
	var catalog: GFAudioCatalogProvider = GFAudioCatalogProvider.new()
	catalog.set_entry(&"events", &"ui_confirm", { "group": "ui" })
	catalog.set_entry(&"parameters", &"intensity", { "min": 0.0, "max": 1.0 })
	var parameter_entry: Dictionary = catalog.describe_entry(&"parameters", &"intensity")

	assert_eq(catalog.get_ids(&"events"), PackedStringArray(["ui_confirm"]), "目录应列出事件 ID。")
	assert_eq(GFVariantData.get_option_float(parameter_entry, "max"), 1.0, "目录应返回条目元数据。")


func test_audio_catalog_provider_ignores_unknown_catalog_ids() -> void:
	var catalog: GFAudioCatalogProvider = GFAudioCatalogProvider.new()

	catalog.set_entry(&"parameter", &"intensity", { "min": 0.0 })
	assert_push_warning("[GFAudioCatalogProvider] 未知音频目录：parameter。")

	assert_eq(catalog.get_ids(&"events"), PackedStringArray(), "未知目录 ID 不应默认写入 events。")
	assert_eq(catalog.get_ids(&"parameter"), PackedStringArray(), "未知目录 ID 查询应返回空列表。")


func test_play_sfx_clip_2d_creates_spatial_player() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"

	var player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)

	assert_not_null(player, "2D 空间 SFX 应创建播放器。")
	assert_eq(player.stream, stream, "2D 空间 SFX 应写入对应音频流。")
	assert_eq(player.bus, "Master", "2D 空间 SFX 应应用总线配置。")
	assert_eq(player.area_mask, 1, "未提供空间设置时 2D 空间 SFX 应保留 GF 默认区域掩码。")
	if is_instance_valid(player):
		player.queue_free()


func test_post_audio_event_spatial_sfx_uses_default_spatial_player() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	var event: GFAudioEvent = GFAudioEvent.new()
	event.channel = &"spatial_sfx"
	event.clip = clip

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event, {
		"source": source,
		"follow_source": true,
	})

	assert_not_null(handle, "带 source 的 spatial_sfx 事件应返回空间播放句柄。")
	assert_true(handle.is_valid(), "默认空间 SFX 播放器应绑定到返回句柄。")
	assert_eq(_audio._active_spatial_sfx_players.size(), 1, "默认 spatial_sfx 事件应创建空间播放器。")
	assert_same(handle.get_player().get_parent(), source, "follow_source=true 时空间播放器应挂到声源下。")
	handle.stop()


func test_spatial_sfx_handle_becomes_terminal_on_natural_finish() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var handle: GFAudioEmitterHandle = _audio.play_sfx_clip_2d_handle(clip, source)
	var player: AudioStreamPlayer2D = handle.get_player() as AudioStreamPlayer2D

	player.finished.emit()

	assert_false(handle.is_valid(), "空间播放自然结束时句柄应同步进入终态。")
	assert_eq(_audio._active_spatial_sfx_players.size(), 0, "自然结束应同步解除空间播放器跟踪。")
	assert_true(player.is_queued_for_deletion(), "自然结束的空间播放器应排队释放。")


func test_play_sfx_clip_3d_preserves_default_area_mask_without_spatial_settings() -> void:
	var source: Node3D = Node3D.new()
	add_child_autofree(source)
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"

	var player: AudioStreamPlayer3D = _audio.play_sfx_clip_3d(clip, source)

	assert_not_null(player, "3D 空间 SFX 应创建播放器。")
	assert_eq(player.stream, stream, "3D 空间 SFX 应写入对应音频流。")
	assert_eq(player.bus, "Master", "3D 空间 SFX 应应用总线配置。")
	assert_eq(player.area_mask, 1, "未提供空间设置时 3D 空间 SFX 应保留 GF 默认区域掩码。")
	if is_instance_valid(player):
		player.queue_free()


func test_play_sfx_clip_2d_falls_back_to_default_area_mask_when_compatible_settings_fail() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.spatial_settings = FailingSpatialSettings.new()

	var player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)

	assert_not_null(player, "兼容空间设置失败时仍应创建播放器。")
	assert_eq(player.area_mask, 1, "兼容空间设置返回 false 时应恢复 GF 默认 area_mask。")
	if is_instance_valid(player):
		player.queue_free()


func test_play_sfx_clip_2d_applies_spatial_settings() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var settings: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	settings.max_polyphony = 3
	settings.panning_strength = 0.5
	settings.area_mask_2d = 5
	settings.playback_type = 1
	settings.max_distance_2d = 512.0
	settings.attenuation_2d = 2.0
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.spatial_settings = settings

	var player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)

	assert_not_null(player, "2D 空间 SFX 应创建播放器。")
	assert_eq(player.max_polyphony, 3, "2D 空间设置应应用 max_polyphony。")
	assert_almost_eq(player.panning_strength, 0.5, 0.001, "2D 空间设置应应用 panning_strength。")
	assert_eq(player.area_mask, 5, "2D 空间设置应应用 area_mask。")
	assert_eq(player.playback_type, 1, "2D 空间设置应应用 playback_type。")
	assert_almost_eq(player.max_distance, 512.0, 0.001, "2D 空间设置应应用 max_distance。")
	assert_almost_eq(player.attenuation, 2.0, 0.001, "2D 空间设置应应用 attenuation。")
	if is_instance_valid(player):
		player.queue_free()


func test_play_sfx_clip_2d_can_follow_source() -> void:
	var source: Node2D = Node2D.new()
	source.global_position = Vector2(10.0, 20.0)
	add_child_autofree(source)
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"

	var player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source, true)

	assert_not_null(player, "跟随模式下仍应创建 2D 空间 SFX 播放器。")
	assert_same(player.get_parent(), source, "跟随模式下播放器应挂到声源节点下。")
	assert_eq(player.position, Vector2.ZERO, "跟随模式下播放器应使用本地零偏移。")
	source.global_position = Vector2(32.0, 48.0)
	assert_eq(player.global_position, source.global_position, "声源移动后播放器应跟随全局位置。")


func test_play_sfx_clip_3d_applies_spatial_settings() -> void:
	var source: Node3D = Node3D.new()
	add_child_autofree(source)
	var settings: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	settings.max_polyphony = 4
	settings.panning_strength = 0.25
	settings.area_mask_3d = 7
	settings.playback_type = 1
	settings.attenuation_model_3d = 2
	settings.unit_size_3d = 4.0
	settings.max_db_3d = 1.5
	settings.max_distance_3d = 30.0
	settings.emission_angle_enabled_3d = true
	settings.emission_angle_degrees_3d = 30.0
	settings.emission_angle_filter_attenuation_db_3d = -10.0
	settings.attenuation_filter_cutoff_hz_3d = 1000.0
	settings.attenuation_filter_db_3d = -12.0
	settings.doppler_tracking_3d = 2
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.spatial_settings = settings

	var player: AudioStreamPlayer3D = _audio.play_sfx_clip_3d(clip, source)

	assert_not_null(player, "3D 空间 SFX 应创建播放器。")
	assert_eq(player.max_polyphony, 4, "3D 空间设置应应用 max_polyphony。")
	assert_almost_eq(player.panning_strength, 0.25, 0.001, "3D 空间设置应应用 panning_strength。")
	assert_eq(player.area_mask, 7, "3D 空间设置应应用 area_mask。")
	assert_eq(player.playback_type, 1, "3D 空间设置应应用 playback_type。")
	assert_eq(player.attenuation_model, 2, "3D 空间设置应应用 attenuation_model。")
	assert_almost_eq(player.unit_size, 4.0, 0.001, "3D 空间设置应应用 unit_size。")
	assert_almost_eq(player.max_db, 1.5, 0.001, "3D 空间设置应应用 max_db。")
	assert_almost_eq(player.max_distance, 30.0, 0.001, "3D 空间设置应应用 max_distance。")
	assert_true(player.emission_angle_enabled, "3D 空间设置应应用 emission_angle_enabled。")
	assert_almost_eq(player.emission_angle_degrees, 30.0, 0.001, "3D 空间设置应应用 emission_angle_degrees。")
	assert_almost_eq(player.emission_angle_filter_attenuation_db, -10.0, 0.001, "3D 空间设置应应用 emission 过滤衰减。")
	assert_almost_eq(player.attenuation_filter_cutoff_hz, 1000.0, 0.001, "3D 空间设置应应用滤波截止频率。")
	assert_almost_eq(player.attenuation_filter_db, -12.0, 0.001, "3D 空间设置应应用滤波衰减。")
	assert_eq(player.doppler_tracking, 2, "3D 空间设置应应用 doppler_tracking。")
	if is_instance_valid(player):
		player.queue_free()


func test_stop_all_sfx_releases_normal_and_spatial_players() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"
	var normal_player: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
	var spatial_player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)

	assert_not_null(normal_player, "测试应先创建普通 SFX 播放器。")
	assert_not_null(spatial_player, "测试应先创建空间 SFX 播放器。")
	assert_eq(_audio._active_sfx_players.size(), 1, "停止前应有普通 SFX 播放器。")
	assert_eq(_audio._active_spatial_sfx_players.size(), 1, "停止前应有空间 SFX 播放器。")

	_audio.stop_all_sfx()
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(_audio._active_sfx_players.size(), 0, "stop_all_sfx 后普通 SFX 列表应清空。")
	assert_eq(_audio._active_spatial_sfx_players.size(), 0, "stop_all_sfx 后空间 SFX 列表应清空。")
	assert_eq(GFVariantData.get_option_int(snapshot, "active_spatial_sfx_count"), 0, "调试快照应同步空间 SFX 数量。")
	assert_eq(_pool.get_available_count(_audio._sfx_scene), 1, "普通 SFX 应归还对象池。")
	if is_instance_valid(spatial_player):
		assert_true(spatial_player.is_queued_for_deletion(), "空间 SFX 应排队释放。")


func test_stop_all_sfx_cancels_pending_async_request_and_delegates_to_backend() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.stop_all_sfx(0.15)
	assert_almost_eq(backend.stop_all_sfx_fade, 0.15, 0.001, "stop_all_sfx 淡出秒数应传给后端。")

	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: RecordingAudioUtility = RecordingAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	audio.play_sfx("res://audio/sfx.ogg")
	audio.stop_all_sfx()
	mock_asset.finish("res://audio/sfx.ogg", AudioStreamGenerator.new())

	assert_eq(audio.sfx_play_count, 0, "stop_all_sfx 后迟到的异步 SFX 不应再播放。")
	audio.dispose()
	await get_tree().process_frame


func test_play_ambient_clip_uses_channel_player() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = stream
	clip.bus_name = "Master"
	clip.volume_db = -4.0
	clip.pitch_scale = 0.9

	_audio.play_ambient_clip(clip, &"rain")

	assert_true(_audio.is_ambient_playing(&"rain"), "播放环境音后指定通道应处于播放状态。")
	var player: AudioStreamPlayer = _audio._get_ambient_player(&"rain")
	assert_eq(player.stream, stream, "环境音通道应写入对应音频流。")
	assert_eq(player.bus, "Master", "环境音应应用总线配置。")
	assert_almost_eq(player.volume_db, -4.0, 0.001, "环境音应应用音量配置。")
	assert_almost_eq(player.pitch_scale, 0.9, 0.001, "环境音应应用音高配置。")

	_audio.stop_ambient(&"rain")
	assert_false(_audio.is_ambient_playing(&"rain"), "停止通道后环境音应结束。")


func test_play_bgm_ignores_stale_async_load() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()

	audio.play_bgm("res://audio/first.ogg")
	audio.play_bgm("res://audio/second.ogg")

	mock_asset.finish("res://audio/second.ogg", second_stream)
	assert_eq(audio._bgm_player.stream, second_stream, "后发起的 BGM 请求完成后应成为当前播放流。")

	mock_asset.finish("res://audio/first.ogg", first_stream)
	assert_eq(audio._bgm_player.stream, second_stream, "旧请求迟到返回时，不应覆盖最新的 BGM。")

	audio.dispose()
	await get_tree().process_frame


func test_stop_bgm_cancels_pending_async_load() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	audio.play_bgm("res://audio/late.ogg")
	audio.stop_bgm()
	mock_asset.finish("res://audio/late.ogg", AudioStreamGenerator.new())

	assert_null(audio._bgm_player.stream, "stop_bgm 后迟到 BGM 异步加载不应恢复播放。")
	assert_false(audio._bgm_player.playing, "stop_bgm 后迟到 BGM 异步加载不应恢复播放。")
	audio.dispose()
	await get_tree().process_frame


func test_play_sfx_ignores_async_load_after_dispose() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: RecordingAudioUtility = RecordingAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	audio.play_sfx("res://audio/sfx.ogg")
	audio.dispose()

	mock_asset.finish("res://audio/sfx.ogg", AudioStreamGenerator.new())

	assert_eq(audio.sfx_play_count, 0, "SFX 异步加载在 Utility 销毁后不应继续播放。")
	await get_tree().process_frame


func test_sfx_handle_stop_before_async_load_prevents_playback() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: RecordingAudioUtility = RecordingAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	var handle: GFAudioEmitterHandle = audio.play_sfx_handle("res://audio/sfx.ogg")
	var stopped_count: Array[int] = [0]
	var _connect_result: Error = handle.stopped.connect(func(_handle: GFAudioEmitterHandle) -> void:
		stopped_count[0] += 1
	) as Error
	handle.stop()
	mock_asset.finish("res://audio/sfx.ogg", AudioStreamGenerator.new())

	assert_true(handle.is_stop_requested(), "异步资源返回前停止句柄应记录停止请求。")
	assert_eq(stopped_count[0], 1, "pending handle 停止时应发出 exactly-once 终态信号。")
	assert_eq(audio.sfx_play_count, 0, "已停止的异步 SFX 请求完成后不应再播放。")
	audio.dispose()
	await get_tree().process_frame


func test_sfx_handle_failed_async_load_emits_terminal_stop() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: RecordingAudioUtility = RecordingAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame
	var stopped_count: Array[int] = [0]

	var handle: GFAudioEmitterHandle = audio.play_sfx_handle("res://audio/missing.ogg")
	var _connect_result: Error = handle.stopped.connect(func(_handle: GFAudioEmitterHandle) -> void:
		stopped_count[0] += 1
	) as Error
	mock_asset.finish("res://audio/missing.ogg", null)

	assert_eq(stopped_count[0], 1, "异步资源缺失时 public handle 应进入可观察终态。")
	assert_false(handle.is_valid(), "异步资源缺失后句柄不应保持 pending 有效状态。")
	assert_eq(audio.sfx_play_count, 0, "异步资源缺失不应尝试播放。")
	audio.dispose()
	await get_tree().process_frame


func test_sfx_capacity_can_skip_new_requests() -> void:
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW

	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()

	var _play_sfx_stream_result_904: Variant = _audio._play_sfx_stream(first_stream)
	var _play_sfx_stream_result_905: Variant = _audio._play_sfx_stream(second_stream)

	assert_eq(_audio._active_sfx_players.size(), 1, "SFX 达到上限后应只保留一个播放器。")
	assert_eq(_audio._active_sfx_players[0].stream, first_stream, "跳过策略不应替换正在播放的 SFX。")


func test_sfx_capacity_skip_marks_returned_handle_terminal() -> void:
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW
	var first_clip: GFAudioClip = GFAudioClip.new()
	first_clip.stream = AudioStreamGenerator.new()
	var skipped_clip: GFAudioClip = GFAudioClip.new()
	skipped_clip.stream = AudioStreamGenerator.new()
	var _first_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(first_clip)

	var skipped_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(skipped_clip)
	await get_tree().process_frame

	assert_eq(_audio._active_sfx_players.size(), 1, "跳过策略不应创建第二个播放器。")
	assert_true(skipped_handle.is_stop_requested(), "被容量策略跳过的 handle 应进入终态请求状态。")
	assert_false(skipped_handle.is_valid(), "被容量策略跳过的 handle 不应保持有效。")


func test_sfx_capacity_can_stop_oldest_request() -> void:
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.STOP_OLDEST

	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()

	var _play_sfx_stream_result_918: Variant = _audio._play_sfx_stream(first_stream)
	var _play_sfx_stream_result_919: Variant = _audio._play_sfx_stream(second_stream)

	assert_eq(_audio._active_sfx_players.size(), 1, "替换策略也应遵守 SFX 数量上限。")
	assert_eq(_audio._active_sfx_players[0].stream, second_stream, "替换策略应让新的 SFX 接管播放器。")


func test_bus_volume_db_snapshot_and_duck_restore() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)

	assert_true(_audio.set_bus_volume_db("Master", -6.0), "应能直接设置总线 dB 音量。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -6.0, 0.001, "dB 音量读取应返回当前值。")
	assert_false(AudioServer.is_bus_mute(bus_idx), "设置可听音量时应解除静音。")

	var snapshot: Dictionary = _audio.capture_mix_snapshot(PackedStringArray(["Master"]))
	var buses: Dictionary = GFVariantData.get_option_dictionary(snapshot, "buses")
	var master: Dictionary = GFVariantData.get_option_dictionary(buses, "Master")
	assert_almost_eq(GFVariantData.get_option_float(master, "volume_db"), -6.0, 0.001, "快照应记录总线 dB 音量。")

	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "duck_bus 应按比例压低总线。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -15.0, 0.001, "0.5 duck 默认应压低 9 dB。")
	assert_true(_audio.restore_ducked_bus("Master", 0.0, &"dialogue"), "restore_ducked_bus 应恢复记录的基准。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -6.0, 0.001, "恢复后应回到 duck 前音量。")

	var report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": {
				"volume_db": original_db,
				"muted": original_muted,
			},
		},
	})
	assert_true(GFVariantData.get_option_bool(report, "ok"), "应用总线快照应返回成功报告。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), original_db, 0.001, "快照应恢复原始 dB。")
	assert_eq(AudioServer.is_bus_mute(bus_idx), original_muted, "快照应恢复原始静音状态。")


func test_mix_snapshot_can_apply_bus_effect_property() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var effect_count_before: int = AudioServer.get_bus_effect_count(bus_idx)
	var effect: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	effect.resource_name = "GFTestLowPass"
	AudioServer.add_bus_effect(bus_idx, effect)

	var report: Dictionary = _audio.apply_mix_snapshot({
		"effects": [
			{
				"bus": "Master",
				"effect": "lowpass",
				"property": "cutoff_hz",
				"value": 1200.0,
			},
		],
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "效果快照应用成功时报告应为 ok。")
	assert_almost_eq(effect.cutoff_hz, 1200.0, 0.001, "效果属性应被写入。")

	while AudioServer.get_bus_effect_count(bus_idx) > effect_count_before:
		AudioServer.remove_bus_effect(bus_idx, AudioServer.get_bus_effect_count(bus_idx) - 1)


func test_audio_backend_can_handle_mix_controls() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	assert_true(_audio.set_bus_volume_db("External", -3.0), "后端可接管 dB 总线音量。")
	assert_true(_audio.set_bus_mute("External", true), "后端可接管总线静音。")
	assert_true(_audio.set_bus_effect_property("External", "lowpass", &"cutoff_hz", 900.0, 0.2), "后端可接管效果属性。")
	var report: Dictionary = _audio.apply_mix_snapshot({ "backend_only": true }, 0.3)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "后端处理混音快照时应返回成功报告。")
	assert_almost_eq(backend.external_volume_db, -3.0, 0.001, "dB 音量应传给后端。")
	assert_true(backend.external_muted, "静音状态应传给后端。")
	assert_eq(backend.effect_property_requests.size(), 1, "效果属性请求应传给后端。")
	assert_almost_eq(backend.handled_mix_transition, 0.3, 0.001, "快照过渡时间应传给后端。")


func test_mix_controls_reject_non_finite_values_before_backend_or_engine_write() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	var volume_ok: bool = _audio.set_bus_volume_db("External", NAN)
	var effect_ok: bool = _audio.set_bus_effect_property("External", 0, &"cutoff_hz", INF, 0.1)
	var report: Dictionary = _audio.apply_mix_snapshot({ "backend_only": true }, NAN)

	assert_false(volume_ok, "NaN 总线音量必须在后端调用前被拒绝。")
	assert_false(effect_ok, "Infinity 效果数值必须在后端调用前被拒绝。")
	assert_eq(backend.effect_property_requests.size(), 0, "无效效果值不得触发后端副作用。")
	assert_true(backend.handled_mix_snapshot.is_empty(), "无效过渡时间不得交给后端。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效快照过渡应返回失败报告。")


func test_bgm_requests_sanitize_non_finite_values_before_backend_calls() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	_audio.play_bgm_with_options("event://music", {
		"crossfade_seconds": INF,
		"volume_db": NAN,
		"pitch_scale": INF,
	})
	var pause_ok: bool = _audio.pause_bgm(INF)
	var resume_ok: bool = _audio.resume_bgm(NAN, INF)
	var seek_ok: bool = _audio.seek_bgm(INF)

	assert_eq(GFVariantData.get_option_float(backend.last_bgm_options, "volume_db"), 0.0, "后端不得接收 NaN BGM 音量。")
	assert_eq(GFVariantData.get_option_float(backend.last_bgm_options, "pitch_scale"), 1.0, "后端不得接收 Infinity BGM pitch。")
	var backend_crossfade: float = GFVariantData.get_option_float(backend.last_bgm_options, "crossfade_seconds")
	assert_true(not is_nan(backend_crossfade) and not is_inf(backend_crossfade), "后端 crossfade 必须有限。")
	assert_true(pause_ok, "后端应能处理归一化后的暂停请求。")
	assert_eq(backend.pause_bgm_fade, 0.0, "非有限暂停淡出应归一化为 0。")
	assert_true(resume_ok, "后端应能处理归一化后的恢复请求。")
	assert_eq(backend.resume_bgm_position, -1.0, "非有限恢复位置应回退为继续当前位置语义。")
	assert_eq(backend.resume_bgm_fade, 0.0, "非有限恢复淡入应归一化为 0。")
	assert_false(seek_ok, "非有限 seek 应在调用后端前被拒绝。")
	assert_eq(backend.seek_bgm_position, -1.0, "被拒绝的 seek 不得触发后端副作用。")


func test_stale_bgm_stop_fade_cannot_stop_replacement_session() -> void:
	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_clip: GFAudioClip = GFAudioClip.new()
	second_clip.stream = second_stream

	_audio._play_bgm_stream_with_settings(first_stream, "Master", -3.0, 1.0, 0.0, "first")
	_audio.stop_bgm(0.05)
	_audio.play_bgm_clip(second_clip, 0.0)
	await get_tree().create_timer(0.08).timeout

	assert_same(_audio._bgm_player.stream, second_stream, "旧 stop fade 完成时不得清理复用播放器上的新 BGM 会话。")
	assert_true(_audio._bgm_player.playing, "旧 stop fade 完成时不得停止新 BGM 会话。")


func test_bgm_crossfade_finished_signal_belongs_to_outgoing_session() -> void:
	watch_signals(_audio)
	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()

	_audio._play_bgm_stream_with_settings(first_stream, "Master", -3.0, 1.0, 0.0, "first")
	_audio._play_bgm_stream_with_settings(second_stream, "Master", -6.0, 1.0, 0.05, "second")
	var outgoing_player: AudioStreamPlayer = _audio._bgm_player
	var incoming_player: AudioStreamPlayer = _audio._bgm_fade_player

	outgoing_player.finished.emit()
	assert_signal_emitted_with_parameters(_audio, "bgm_finished", ["first"])
	assert_eq(_audio.get_current_bgm_key(), "second", "旧会话结束不得清空交叉淡入中的新会话 key。")

	await get_tree().create_timer(0.08).timeout
	assert_same(_audio._bgm_player, incoming_player, "交叉淡入应原子提交仍有效的 incoming 会话。")
	assert_true(_audio._bgm_player.playing, "提交后的 incoming 会话应保持播放。")


func test_bgm_crossfade_does_not_commit_finished_incoming_session() -> void:
	var first_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()

	_audio._play_bgm_stream_with_settings(first_stream, "Master", -3.0, 1.0, 0.0, "first", true)
	_audio._play_bgm_stream_with_settings(second_stream, "Master", -6.0, 1.0, 0.05, "second", false)
	var outgoing_player: AudioStreamPlayer = _audio._bgm_player
	var incoming_player: AudioStreamPlayer = _audio._bgm_fade_player

	incoming_player.stop()
	incoming_player.finished.emit()
	await get_tree().create_timer(0.08).timeout

	assert_same(_audio._bgm_player, outgoing_player, "incoming 提前结束时不得提交已停止播放器。")
	assert_true(outgoing_player.playing, "incoming 失败时应恢复仍有效的 outgoing 会话。")
	assert_eq(_audio.get_current_bgm_key(), "first", "incoming 失败后当前 key 应回到仍在播放的 outgoing 会话。")
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_true(GFVariantData.get_option_bool(snapshot, "current_bgm_loop"), "incoming 失败后 loop 应恢复为 outgoing session 的值。")


func test_stop_during_crossfade_clears_terminal_key_and_loop() -> void:
	_audio._play_bgm_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-3.0,
		1.0,
		0.0,
		"outgoing",
		true
	)
	_audio._play_bgm_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-6.0,
		1.0,
		0.05,
		"incoming",
		false
	)

	_audio.stop_bgm(0.05)
	assert_eq(_audio.get_current_bgm_key(), "", "crossfade 中 stop 应立即清空当前 key。")
	await get_tree().create_timer(0.08).timeout
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"stopped", "淡出完成后应进入 stopped。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"none", "淡出完成后不应残留 owner。")
	assert_eq(GFVariantData.get_option_string(snapshot, "current_bgm_key"), "", "终态不得恢复 outgoing key。")
	assert_eq(typeof(GFVariantData.get_option_value(snapshot, "current_bgm_loop")), TYPE_NIL, "终态不得恢复 outgoing loop。")


func test_bgm_pause_state_preserves_original_gain_and_rejects_illegal_transitions() -> void:
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	_audio._play_bgm_stream_with_settings(stream, "Master", -6.0, 1.0, 0.0, "pause-state")

	assert_true(_audio.pause_bgm(0.05), "playing 会话应进入 pausing。")
	await get_tree().create_timer(0.02).timeout
	assert_false(_audio.pause_bgm(0.05), "pausing 中重复 pause 应 fail closed，且不得覆盖原始增益。")
	await get_tree().create_timer(0.06).timeout
	assert_true(_audio.resume_bgm(-1.0, 0.0), "paused 会话应允许 resume。")
	assert_almost_eq(_audio._bgm_player.volume_db, -6.0, 0.001, "resume 应恢复首次 pause 前的目标增益。")

	_audio.stop_bgm()
	assert_false(_audio.resume_bgm(), "stopped 会话不得被 resume 复活。")

	_audio._play_bgm_stream_with_settings(stream, "Master", -6.0, 1.0, 0.0, "natural-end")
	_audio._bgm_player.stop()
	_audio._bgm_player.finished.emit()
	assert_false(_audio.resume_bgm(), "自然结束会话不得被 resume 复活。")


func test_bus_gain_and_mute_share_one_generation_guarded_transaction() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)

	AudioServer.set_bus_volume_db(bus_idx, -6.0)
	AudioServer.set_bus_mute(bus_idx, false)
	assert_true(_audio.set_bus_volume_db("Master", -24.0, 0.05), "测试应启动总线增益 tween。")
	assert_true(_audio.set_bus_mute("Master", true), "显式 mute 应开启更新一代的总线事务。")
	await get_tree().create_timer(0.08).timeout
	assert_true(AudioServer.is_bus_mute(bus_idx), "旧增益 tween 的完成回调不得撤销显式 mute。")

	AudioServer.set_bus_volume_db(bus_idx, -6.0)
	AudioServer.set_bus_mute(bus_idx, true)
	assert_true(_audio.set_bus_volume_db("Master", -3.0, 0.05), "静音总线应支持平滑恢复。")
	assert_false(AudioServer.is_bus_mute(bus_idx), "可听增益过渡开始后应解除静音。")
	assert_lte(AudioServer.get_bus_volume_db(bus_idx), -79.9, "解除静音前必须先把原始增益写到静音下限，避免瞬时爆音。")
	await get_tree().create_timer(0.08).timeout
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), -3.0, 0.001, "有效事务应提交目标增益。")
	assert_false(AudioServer.is_bus_mute(bus_idx), "有效事务应提交目标 mute 状态。")

	AudioServer.set_bus_volume_db(bus_idx, original_db)
	AudioServer.set_bus_mute(bus_idx, original_muted)


func test_mix_snapshot_preserves_raw_gain_and_mute_independently() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)

	AudioServer.set_bus_volume_db(bus_idx, -12.0)
	AudioServer.set_bus_mute(bus_idx, true)
	var snapshot: Dictionary = _audio.capture_mix_snapshot(PackedStringArray(["Master"]))
	var buses: Dictionary = GFVariantData.get_option_dictionary(snapshot, "buses")
	var master: Dictionary = GFVariantData.get_option_dictionary(buses, "Master")
	assert_almost_eq(GFVariantData.get_option_float(master, "volume_db"), -12.0, 0.001, "静音快照仍应保存独立的原始增益。")
	assert_gt(GFVariantData.get_option_float(master, "volume_linear"), 0.0, "线性增益不得被 mute 状态覆盖为零。")
	assert_true(GFVariantData.get_option_bool(master, "muted"), "mute 状态应独立保存。")

	AudioServer.set_bus_volume_db(bus_idx, -2.0)
	AudioServer.set_bus_mute(bus_idx, false)
	var report: Dictionary = _audio.apply_mix_snapshot(snapshot, 0.05)
	await get_tree().create_timer(0.08).timeout
	assert_true(GFVariantData.get_option_bool(report, "ok"), "独立增益和 mute 应能作为一个快照事务应用。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), -12.0, 0.001, "快照应恢复原始增益。")
	assert_true(AudioServer.is_bus_mute(bus_idx), "快照应恢复独立 mute 状态。")

	AudioServer.set_bus_volume_db(bus_idx, original_db)
	AudioServer.set_bus_mute(bus_idx, original_muted)


func test_duck_scopes_share_stable_base_and_release_order_is_independent() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)
	AudioServer.set_bus_volume_db(bus_idx, -6.0)
	AudioServer.set_bus_mute(bus_idx, false)

	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "第一作用域应创建稳定基准。")
	assert_true(_audio.duck_bus("Master", 0.25, 0.0, &"notification"), "第二作用域应复用同一稳定基准。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -15.0, 0.001, "并存作用域应采用最强 attenuation，而非把已 duck 音量当新基准。")

	assert_true(_audio.restore_ducked_bus("Master", 0.0, &"dialogue"), "释放较强作用域应成功。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -10.5, 0.001, "释放顺序不应丢失仍活跃的较弱作用域。")
	assert_true(_audio.restore_ducked_bus("Master", 0.0, &"notification"), "释放最后作用域应成功。")
	assert_almost_eq(_audio.get_bus_volume_db("Master"), -6.0, 0.001, "最后作用域释放后应恢复稳定基准。")

	AudioServer.set_bus_volume_db(bus_idx, original_db)
	AudioServer.set_bus_mute(bus_idx, original_muted)


func test_backend_duck_lifecycle_restores_observed_muted_base() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.external_volume_db = -6.0
	backend.external_volume = db_to_linear(backend.external_volume_db)
	backend.external_muted = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	assert_true(
		_audio.duck_bus("External", 0.5, 0.0, &"dialogue"),
		"可观测 mute 基线的 backend 总线应允许 duck。"
	)
	assert_true(backend.external_muted, "duck 只调整 gain，不应改变原有 backend mute。")
	_audio.dispose()

	assert_almost_eq(backend.external_volume_db, -6.0, 0.001, "生命周期清理应恢复 backend 基准增益。")
	assert_true(backend.external_muted, "生命周期清理应恢复观测到的 backend 原始静音状态。")


func test_backend_duck_fails_closed_when_base_mute_is_not_observable() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.external_volume_db = -6.0
	backend.external_volume = db_to_linear(backend.external_volume_db)
	backend.external_muted = true
	backend.external_mute_observable = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	assert_false(
		_audio.duck_bus("External", 0.5, 0.0, &"dialogue"),
		"无法观测 backend mute 基线时不得猜测 false 后开始 duck。"
	)
	assert_almost_eq(backend.external_volume_db, -6.0, 0.001, "失败关闭不得修改 backend 增益。")
	assert_true(backend.external_muted, "失败关闭不得修改 backend 静音状态。")
	assert_eq(
		GFVariantData.get_option_int(_audio.get_debug_snapshot(), "ducked_bus_count"),
		0,
		"失败关闭不得登记不可恢复的 duck 状态。"
	)


func test_architecture_dispose_forces_audio_terminal_state_and_restores_duck_bus() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)
	AudioServer.set_bus_volume_db(bus_idx, -7.0)
	AudioServer.set_bus_mute(bus_idx, true)
	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"))

	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/dispose")
	_audio.play_ambient("event://ambient/dispose", &"weather")
	backend.allow_stop_bgm = false
	backend.allow_stop_ambient = false
	var bgm_player: AudioStreamPlayer = _audio._bgm_player
	var bgm_fade_player: AudioStreamPlayer = _audio._bgm_fade_player

	var architecture: GFArchitecture = Gf.get_architecture()
	architecture.dispose()

	assert_push_warning(
		"[GFAudioUtility] dispose 强制终结：后端拒绝停止或正在回调，"
		+ "将解除内部 owner 并继续释放生命周期资源。"
	)
	assert_true(architecture.is_disposed(), "架构 dispose 不得被音频后端拒绝卡住。")
	assert_true(backend.disposed, "生命周期终结仍应 dispose 当前后端。")
	assert_null(_audio.get_audio_backend(), "生命周期终结后不得保留后端引用。")
	assert_eq(_audio._bgm_owner, &"none", "生命周期终结必须清除 BGM owner。")
	assert_eq(_audio._bgm_state, &"stopped", "生命周期终结必须收敛 BGM 状态。")
	assert_true(_audio._ambient_sessions.is_empty(), "生命周期终结必须清空环境音会话。")
	assert_true(_audio._playback_session_handles.is_empty(), "生命周期终结必须清空播放句柄。")
	assert_true(_audio._duck_bus_states.is_empty(), "生命周期终结必须清空 duck 作用域。")
	assert_null(_audio._root, "生命周期终结必须解除根节点引用。")
	assert_true(bgm_player.is_queued_for_deletion(), "BGM 根播放器应进入释放流程。")
	assert_true(bgm_fade_player.is_queued_for_deletion(), "BGM 淡变播放器应进入释放流程。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_idx), -7.0, 0.001, "dispose 前应恢复 duck 基准增益。")
	assert_true(AudioServer.is_bus_mute(bus_idx), "dispose 前应恢复 duck 基准静音状态。")

	AudioServer.set_bus_volume_db(bus_idx, original_db)
	AudioServer.set_bus_mute(bus_idx, original_muted)
	assert_true(
		await Gf.set_architecture(GFArchitecture.new()),
		"架构级 dispose 集成测试结束后应恢复测试隔离架构。"
	)


func test_bgm_backend_and_local_playback_switch_owner_atomically() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	var first_clip: GFAudioClip = GFAudioClip.new()
	first_clip.stream = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_clip: GFAudioClip = GFAudioClip.new()
	second_clip.stream = second_stream

	_audio.play_bgm_clip(first_clip)
	var local_player: AudioStreamPlayer = _audio._bgm_player
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/backend")
	assert_false(local_player.playing, "后端成功接管 BGM 前必须原子停止本地 owner。")

	_audio.play_bgm_clip(second_clip)
	assert_eq(backend.stop_bgm_count, 1, "回退本地播放前必须停止后端 owner。")
	assert_same(_audio._bgm_player.stream, second_stream, "后端释放 owner 后本地会话应接管。")
	assert_true(_audio._bgm_player.playing, "同一时刻只能有本地接管后的 BGM 会话播放。")


func test_backend_to_local_owner_switch_fails_closed_when_backend_cannot_stop() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/backend")
	_audio.play_ambient("event://ambient/backend", &"weather")
	assert_true(_audio.pause_bgm(), "测试应先把后端 BGM 置为 paused。")
	backend.allow_stop_bgm = false
	backend.allow_stop_ambient = false

	var local_clip: GFAudioClip = GFAudioClip.new()
	local_clip.stream = AudioStreamGenerator.new()
	_audio.play_bgm_clip(local_clip)
	_audio.play_ambient_clip(local_clip, &"weather")
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	var weather_session: Dictionary = GFVariantData.get_option_dictionary(ambient_sessions, "weather")

	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"backend", "后端无法停止时 BGM 切换必须 fail closed。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"paused", "失败的 owner 切换应恢复后端原有 paused 状态。")
	assert_false(_audio._bgm_player.playing, "后端 owner 未释放时不得启动本地 BGM。")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "owner"), &"backend", "后端无法停止时环境音切换必须 fail closed。")
	var local_ambient_player: AudioStreamPlayer = _audio._get_ambient_player(&"weather")
	assert_true(local_ambient_player == null or not local_ambient_player.playing, "后端 owner 未释放时不得启动本地环境音。")
	backend.allow_stop_bgm = true
	backend.allow_stop_ambient = true


func test_ambient_replacement_invalidates_load_switches_owner_and_binds_handle_to_session() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_paths = true
	audio.init()
	await get_tree().process_frame

	audio.play_ambient("res://audio/pending-rain.ogg", &"weather")
	assert_true(audio.set_audio_backend(backend), "测试后端应成功绑定。")
	audio.play_ambient("event://ambient/wind", &"weather")
	mock_asset.finish("res://audio/pending-rain.ogg", AudioStreamGenerator.new())
	var weather_player: AudioStreamPlayer = audio._get_ambient_player(&"weather")
	assert_true(weather_player == null or not weather_player.playing, "任何 ambient replacement 都必须先失效旧异步加载。")

	var first_clip: GFAudioClip = GFAudioClip.new()
	first_clip.stream = AudioStreamGenerator.new()
	var second_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var second_clip: GFAudioClip = GFAudioClip.new()
	second_clip.stream = second_stream
	audio.play_ambient_clip(first_clip, &"weather")
	assert_eq(backend.stopped_ambient_channels.count("weather"), 1, "本地回退接管前必须停止该通道的后端 owner。")
	var old_handle: GFAudioEmitterHandle = audio.get_ambient_handle(&"weather")
	audio.play_ambient_clip(second_clip, &"weather")
	var current_player: AudioStreamPlayer = audio._get_ambient_player(&"weather")
	old_handle.stop()
	var snapshot: Dictionary = audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	var weather_session: Dictionary = GFVariantData.get_option_dictionary(ambient_sessions, "weather")

	assert_false(old_handle.is_valid(), "ambient replacement 应终结旧 session 句柄。")
	assert_same(current_player.stream, second_stream, "旧 ambient 句柄不得停止复用播放器上的新 session。")
	assert_true(current_player.playing, "旧 ambient 句柄操作后新 session 应继续播放。")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "owner"), &"local", "环境音快照应公开通道 owner。")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "state"), &"playing", "环境音快照应公开通道状态。")
	assert_gt(GFVariantData.get_option_int(weather_session, "playback_session_id"), 0, "本地环境音快照应公开 session ID。")
	audio.dispose()
	await get_tree().process_frame


func test_all_ambient_handles_for_one_session_become_terminal_together() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	_audio.play_ambient_clip(clip, &"weather")

	var first_handle: GFAudioEmitterHandle = _audio.get_ambient_handle(&"weather")
	var second_handle: GFAudioEmitterHandle = _audio.get_ambient_handle(&"weather")
	assert_not_null(first_handle, "第一个环境音句柄应绑定当前会话。")
	assert_not_null(second_handle, "第二个环境音句柄应绑定同一会话。")
	assert_true(first_handle.is_valid())
	assert_true(second_handle.is_valid())

	_audio.stop_ambient(&"weather")

	assert_true(first_handle.is_terminal(), "会话停止必须终结第一个外部句柄。")
	assert_true(second_handle.is_terminal(), "会话停止必须终结同 session 的全部句柄。")
	assert_false(first_handle.is_valid())
	assert_false(second_handle.is_valid())


func test_external_ambient_stop_converges_each_public_observation_path() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()

	_audio.play_ambient_clip(clip, &"weather")
	var weather_handle: GFAudioEmitterHandle = _audio.get_ambient_handle(&"weather")
	var weather_player: AudioStreamPlayer = weather_handle.get_player() as AudioStreamPlayer
	weather_player.stop()
	assert_false(_audio.is_ambient_playing(&"weather"), "播放查询应识别外部停止的本地环境音。")
	assert_true(weather_handle.is_terminal(), "播放查询应同步终结外部停止会话的旧句柄。")

	_audio.play_ambient_clip(clip, &"forest")
	var forest_handle: GFAudioEmitterHandle = _audio.get_ambient_handle(&"forest")
	var forest_player: AudioStreamPlayer = forest_handle.get_player() as AudioStreamPlayer
	forest_player.stop()
	assert_null(
		_audio.get_ambient_handle(&"forest"),
		"句柄查询应收敛外部停止的本地环境音，而不是返回陈旧会话。"
	)
	assert_true(forest_handle.is_terminal(), "句柄查询应同步终结被收敛会话的旧句柄。")

	_audio.play_ambient_clip(clip, &"cave")
	var cave_handle: GFAudioEmitterHandle = _audio.get_ambient_handle(&"cave")
	var cave_player: AudioStreamPlayer = cave_handle.get_player() as AudioStreamPlayer
	cave_player.stop()
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	var cave_session: Dictionary = GFVariantData.get_option_dictionary(ambient_sessions, "cave")
	assert_true(cave_handle.is_terminal(), "调试快照应同步终结外部停止会话的旧句柄。")
	assert_eq(
		GFVariantData.get_option_string_name(cave_session, "state"),
		&"stopped",
		"调试快照应把外部停止的本地环境音收敛到 stopped。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(cave_session, "owner"),
		&"none",
		"调试快照应清除外部停止环境音的本地 owner。"
	)
	assert_eq(
		GFVariantData.get_option_int(cave_session, "playback_session_id"),
		0,
		"调试快照不应保留外部停止环境音的会话 ID。"
	)


func test_backend_ambient_natural_end_converges_owned_session() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_ambient("event://ambient/weather", &"weather")
	var generation_before: int = _audio._get_ambient_request_serial(&"weather")

	backend.backend_ambient_playing[&"weather"] = false
	assert_false(_audio.is_ambient_playing(&"weather"), "后端自然结束后查询应返回 false。")

	var session: Dictionary = _audio._get_ambient_session(&"weather")
	assert_eq(
		GFVariantData.get_option_string_name(session, "state"),
		&"stopped",
		"稳定身份查询确认自然结束后应提交 stopped。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(session, "owner"),
		&"none",
		"稳定身份查询确认自然结束后应解除 backend owner。"
	)
	assert_gt(
		GFVariantData.get_option_int(session, "generation"),
		generation_before,
		"自然结束提交应生成新的环境音 generation。"
	)
	assert_eq(backend.is_ambient_playing_count, 1, "自然结束查询应且只应派发一次后端调用。")


func test_stop_all_ambient_uses_backend_bulk_stop_and_commits_all_channels() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_paths = true
	backend.allow_stop_ambient = false
	backend.allow_stop_all_ambient = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_ambient("event://ambient/weather", &"weather")
	_audio.play_ambient("event://ambient/wind", &"wind")

	_audio.stop_all_ambient(0.25)

	assert_eq(backend.stop_all_ambient_count, 1, "backend-owned 通道应优先使用一次 bulk stop。")
	assert_true(
		backend.stopped_ambient_channels.is_empty(),
		"bulk stop 成功后不得重复逐通道停止。"
	)
	for channel: StringName in [&"weather", &"wind"]:
		var session: Dictionary = _audio._get_ambient_session(channel)
		assert_eq(GFVariantData.get_option_string_name(session, "state"), &"stopped")
		assert_eq(GFVariantData.get_option_string_name(session, "owner"), &"none")


func test_stop_all_ambient_falls_back_per_channel_and_keeps_partial_truth() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_paths = true
	backend.allow_stop_all_ambient = false
	backend.stop_ambient_results[&"weather"] = true
	backend.stop_ambient_results[&"wind"] = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_ambient("event://ambient/weather", &"weather")
	_audio.play_ambient("event://ambient/wind", &"wind")

	_audio.stop_all_ambient()

	assert_eq(backend.stop_all_ambient_count, 1, "bulk stop 拒绝时仍应先尝试一次。")
	assert_eq(
		backend.stopped_ambient_channels,
		PackedStringArray(["weather", "wind"]),
		"bulk stop 失败后应按稳定通道顺序逐通道回退。"
	)
	var weather_session: Dictionary = _audio._get_ambient_session(&"weather")
	var wind_session: Dictionary = _audio._get_ambient_session(&"wind")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "owner"), &"none")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "state"), &"stopped")
	assert_eq(
		GFVariantData.get_option_string_name(wind_session, "owner"),
		&"backend",
		"拒绝逐通道停止的会话必须保留真实 backend owner。"
	)
	assert_eq(GFVariantData.get_option_string_name(wind_session, "state"), &"playing")

	backend.stop_ambient_results[&"wind"] = true


func test_dispose_invalidates_old_channel_callbacks_and_bus_transactions() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame
	watch_signals(audio)

	audio._play_bgm_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-3.0,
		1.0,
		0.0,
		"old-session"
	)
	var old_bgm_player: AudioStreamPlayer = audio._bgm_player
	audio.play_ambient("res://audio/old-pending.ogg", &"weather")
	assert_true(audio.set_bus_volume_db("Master", -30.0, 0.05), "测试应启动旧生命周期的总线事务。")

	audio.dispose()
	old_bgm_player.finished.emit()
	audio.init()
	await get_tree().process_frame
	audio._play_bgm_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-6.0,
		1.0,
		0.0,
		"new-session"
	)
	var new_ambient_clip: GFAudioClip = GFAudioClip.new()
	var new_ambient_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	new_ambient_clip.stream = new_ambient_stream
	audio.play_ambient_clip(new_ambient_clip, &"weather")
	assert_true(audio.set_bus_volume_db("Master", -4.0), "新生命周期应提交更新一代的总线事务。")

	mock_asset.finish("res://audio/old-pending.ogg", AudioStreamGenerator.new())
	await get_tree().create_timer(0.08).timeout

	assert_eq(audio.get_current_bgm_key(), "new-session", "dispose 前的 finished 回调不得清理新 BGM session。")
	assert_signal_not_emitted(audio, "bgm_finished", "dispose 前的 finished 回调不得发出属于新生命周期的终态信号。")
	var ambient_player: AudioStreamPlayer = audio._get_ambient_player(&"weather")
	assert_same(ambient_player.stream, new_ambient_stream, "dispose 前的异步环境音加载不得覆盖新 generation。")
	assert_true(ambient_player.playing, "dispose 前的环境音回调不得停止新 session。")
	assert_almost_eq(audio.get_bus_volume_db("Master"), -4.0, 0.001, "dispose 前的总线 tween 不得覆盖新事务。")
	audio.dispose()
	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)
	await get_tree().process_frame


func test_normal_and_spatial_sfx_share_one_capacity_budget() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var spatial_clip: GFAudioClip = GFAudioClip.new()
	spatial_clip.stream = AudioStreamGenerator.new()
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW

	var spatial_player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(spatial_clip, source)
	var skipped_normal: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
	assert_not_null(spatial_player, "预算空闲时空间 SFX 应先占用统一容量。")
	assert_null(skipped_normal, "空间 SFX 已占满预算时普通 SFX 必须被跳过。")
	_audio.stop_all_sfx()

	var normal_player: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
	var skipped_spatial: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(spatial_clip, source)
	assert_not_null(normal_player, "预算空闲时普通 SFX 应先占用统一容量。")
	assert_null(skipped_spatial, "普通 SFX 已占满预算时空间 SFX 必须被跳过。")


func test_stop_oldest_sfx_policy_uses_global_session_order() -> void:
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var spatial_clip: GFAudioClip = GFAudioClip.new()
	spatial_clip.stream = AudioStreamGenerator.new()
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.STOP_OLDEST

	var old_spatial: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(spatial_clip, source)
	var new_normal: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())

	assert_not_null(new_normal, "STOP_OLDEST 应允许新普通 SFX 接管统一容量。")
	assert_eq(_audio._active_spatial_sfx_players.size(), 0, "全局最旧的空间 SFX 应被释放。")
	assert_true(old_spatial.is_queued_for_deletion(), "被统一容量淘汰的空间播放器应进入释放流程。")


func test_sfx_fade_release_keeps_normal_and_spatial_capacity_reserved_until_completion() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW

	var normal_player: AudioStreamPlayer = _audio._play_sfx_stream(clip.stream)
	assert_not_null(normal_player, "普通 SFX 应先占用唯一容量。")
	_audio.stop_all_sfx(0.05)
	var normal_fade_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(normal_fade_snapshot, "active_sfx_count"),
		1,
		"普通 SFX 淡出完成前仍应计入调试数量。"
	)
	assert_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"普通 SFX 淡出完成前不得提前释放容量。"
	)
	await get_tree().create_timer(0.08).timeout
	var normal_replacement: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
	assert_not_null(normal_replacement, "普通 SFX 淡出完成后应释放容量。")
	_audio.stop_all_sfx()
	await get_tree().process_frame

	var spatial_player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)
	assert_not_null(spatial_player, "空间 SFX 应先占用唯一容量。")
	_audio.stop_all_sfx(0.05)
	var spatial_fade_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(spatial_fade_snapshot, "active_spatial_sfx_count"),
		1,
		"空间 SFX 淡出完成前仍应计入调试数量。"
	)
	assert_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"空间 SFX 淡出完成前不得提前释放容量。"
	)
	await get_tree().create_timer(0.08).timeout
	assert_not_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"空间 SFX 淡出完成后应释放容量。"
	)


func test_second_stop_kills_retiring_fade_before_normal_player_pool_reuse() -> void:
	var original_player: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-6.0,
		1.0
	)
	assert_not_null(original_player, "测试应先取得普通 SFX 池播放器。")
	_audio.stop_all_sfx(0.05)
	await get_tree().create_timer(0.02).timeout

	_audio.stop_all_sfx(0.0)
	var reused_player: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-3.0,
		1.0
	)
	assert_same(reused_player, original_player, "二次立即 stop 后应允许安全复用同一池播放器。")
	assert_almost_eq(reused_player.volume_db, -3.0, 0.001, "复用时应应用新会话音量。")
	await get_tree().create_timer(0.06).timeout
	assert_true(reused_player.playing, "旧 retiring tween 完成时不得停止复用后的新会话。")
	assert_almost_eq(reused_player.volume_db, -3.0, 0.001, "旧 retiring tween 不得继续改写复用播放器音量。")


func test_stop_oldest_kills_retiring_fade_before_normal_player_pool_reuse() -> void:
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.STOP_OLDEST
	var original_player: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-6.0,
		1.0
	)
	assert_not_null(original_player, "测试应先取得占满容量的普通 SFX 播放器。")
	_audio.stop_all_sfx(0.05)
	await get_tree().create_timer(0.02).timeout

	var reused_player: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-2.0,
		1.0
	)
	assert_same(reused_player, original_player, "STOP_OLDEST 应强制终结最旧 retiring 会话并安全复用播放器。")
	assert_almost_eq(reused_player.volume_db, -2.0, 0.001, "复用时应应用新会话音量。")
	await get_tree().create_timer(0.06).timeout
	assert_true(reused_player.playing, "被 STOP_OLDEST 取消的旧 tween 不得停止新会话。")
	assert_almost_eq(reused_player.volume_db, -2.0, 0.001, "被取消的旧 tween 不得改写复用播放器音量。")


func test_external_stop_completes_normal_and_spatial_sfx_sessions_before_reuse() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW

	var normal_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var normal_player: AudioStreamPlayer = normal_handle.get_player() as AudioStreamPlayer
	assert_not_null(normal_player, "普通 SFX 句柄应绑定播放器。")
	normal_player.stop()
	var normal_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_false(normal_handle.is_valid(), "外部 stop 后普通 SFX 句柄应进入终态。")
	assert_eq(
		GFVariantData.get_option_int(normal_snapshot, "active_sfx_count"),
		0,
		"外部 stop 后普通 SFX 账本应完成。"
	)
	assert_not_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"普通 SFX 外部 stop 后应允许新请求使用容量。"
	)
	_audio.stop_all_sfx()
	await get_tree().process_frame

	var spatial_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_2d_handle(clip, source)
	var spatial_player: AudioStreamPlayer2D = spatial_handle.get_player() as AudioStreamPlayer2D
	assert_not_null(spatial_player, "空间 SFX 句柄应绑定播放器。")
	spatial_player.stop()
	var spatial_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_false(spatial_handle.is_valid(), "外部 stop 后空间 SFX 句柄应进入终态。")
	assert_eq(
		GFVariantData.get_option_int(spatial_snapshot, "active_spatial_sfx_count"),
		0,
		"外部 stop 后空间 SFX 账本应完成。"
	)
	assert_not_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"空间 SFX 外部 stop 后应允许新请求使用容量。"
	)


func test_external_stop_finishes_retiring_normal_and_spatial_sessions_immediately() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	_audio.max_sfx_players = 1
	_audio.sfx_overflow_policy = GFAudioUtility.SFXOverflowPolicy.SKIP_NEW

	var normal_player: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		clip.stream,
		"Master",
		-6.0,
		1.0
	)
	_audio.stop_all_sfx(0.2)
	normal_player.stop()
	var normal_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(normal_snapshot, "active_sfx_count"),
		0,
		"retiring 普通 SFX 被外部停止后应立即释放容量。"
	)
	var normal_replacement: AudioStreamPlayer = _audio._play_sfx_stream_with_settings(
		AudioStreamGenerator.new(),
		"Master",
		-2.0,
		1.0
	)
	assert_same(normal_replacement, normal_player, "外部停止的 retiring 普通播放器应可立即安全复用。")
	if normal_replacement != null:
		await get_tree().create_timer(0.22).timeout
		assert_true(normal_replacement.playing, "已终结会话的旧 retiring tween 不得停止新普通 SFX。")
		assert_almost_eq(
			normal_replacement.volume_db,
			-2.0,
			0.001,
			"已终结会话的旧 retiring tween 不得改写新普通 SFX 音量。"
		)
	_audio.stop_all_sfx()
	await get_tree().process_frame

	var spatial_player: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source)
	_audio.stop_all_sfx(0.2)
	spatial_player.stop()
	var spatial_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(spatial_snapshot, "active_spatial_sfx_count"),
		0,
		"retiring 空间 SFX 被外部停止后应立即释放容量。"
	)
	assert_not_null(
		_audio._play_sfx_stream(AudioStreamGenerator.new()),
		"外部停止 retiring 空间 SFX 后，新请求应立即获得统一容量。"
	)


func test_external_stop_pool_reuse_keeps_one_normal_finished_callback() -> void:
	var player: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
	assert_not_null(player, "测试应先取得普通 SFX 池播放器。")

	for cycle: int in range(3):
		assert_eq(
			player.finished.get_connections().size(),
			1,
			"每个普通 SFX 会话只应保留当前 generation 的一个 finished 回调。"
		)
		player.stop()
		var _snapshot: Dictionary = _audio.get_debug_snapshot()
		assert_eq(
			player.finished.get_connections().size(),
			0,
			"普通 SFX session 终结并归池前应显式断开当前 finished 回调。"
		)
		var reused_player: AudioStreamPlayer = _audio._play_sfx_stream(AudioStreamGenerator.new())
		assert_same(
			reused_player,
			player,
			"第 %d 次外部停止后应复用同一普通 SFX 池播放器。" % (cycle + 1)
		)
		player = reused_player


func test_backend_can_handle_and_play_callbacks_reject_reentrant_host_mutation() -> void:
	var replacement_backend: MockAudioBackend = MockAudioBackend.new()
	var backend: ReentrantAudioBackend = ReentrantAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.replacement_backend = replacement_backend
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.CAN_HANDLE_PATH
	_audio.play_bgm("event://music/can-handle-outer")
	assert_eq(
		backend.played_bgm_paths,
		PackedStringArray(["event://music/can-handle-outer"]),
		"can_handle 回调中的重入播放必须 fail closed。"
	)
	assert_same(_audio.get_audio_backend(), backend, "can_handle 回调中的后端替换必须 fail closed。")
	assert_false(
		GFVariantData.to_bool(backend.replacement_result, true),
		"重入 set_audio_backend 应明确返回 false。"
	)
	assert_false(replacement_backend.setup_called, "被拒绝的重入替换不得 setup 新后端。")

	backend.replacement_result = null
	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.PLAY_BGM_PATH
	_audio.play_bgm("event://music/play-outer")
	assert_eq(
		backend.played_bgm_paths,
		PackedStringArray([
			"event://music/can-handle-outer",
			"event://music/play-outer",
		]),
		"play 回调中的重入播放不得产生第二个后端副作用。"
	)
	assert_eq(_audio.get_current_bgm_key(), "event://music/play-outer", "外层请求应保持当前会话。")
	assert_same(_audio.get_audio_backend(), backend, "play 回调中的后端替换必须 fail closed。")
	assert_false(
		GFVariantData.to_bool(backend.replacement_result, true),
		"play 回调中的重入替换应明确返回 false。"
	)


func test_backend_bgm_pause_query_rejects_reentrant_host_mutation() -> void:
	var replacement_backend: MockAudioBackend = MockAudioBackend.new()
	var backend: ReentrantAudioBackend = ReentrantAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.bgm_paused = true
	backend.replacement_backend = replacement_backend
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/query-outer")

	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.IS_BGM_PAUSED
	assert_true(_audio.is_bgm_paused(), "稳定的外层后端查询结果应正常返回。")

	assert_eq(backend.reentry_count, 1, "查询回调应触发一次测试重入。")
	assert_eq(
		backend.played_bgm_paths,
		PackedStringArray(["event://music/query-outer"]),
		"暂停查询回调中的重入播放必须 fail closed。"
	)
	assert_same(_audio.get_audio_backend(), backend, "暂停查询回调中的后端替换必须 fail closed。")
	assert_false(
		GFVariantData.to_bool(backend.replacement_result, true),
		"暂停查询回调中的重入替换应明确返回 false。"
	)
	assert_false(replacement_backend.setup_called, "被拒绝的重入替换不得 setup 新后端。")


func test_backend_bgm_playing_query_rejects_reentrant_host_mutation() -> void:
	var replacement_backend: MockAudioBackend = MockAudioBackend.new()
	var backend: ReentrantAudioBackend = ReentrantAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.replacement_backend = replacement_backend
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/query-playing")

	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.IS_BGM_PLAYING
	assert_true(_audio.is_bgm_playing(), "稳定的外层 playing 查询结果应正常返回。")

	assert_eq(backend.reentry_count, 1, "playing 查询回调应触发一次测试重入。")
	assert_eq(backend.is_bgm_playing_count, 1, "回调内查询不得递归派发后端。")
	assert_eq(
		backend.played_bgm_paths,
		PackedStringArray(["event://music/query-playing"]),
		"playing 查询回调中的重入播放必须 fail closed。"
	)
	assert_same(_audio.get_audio_backend(), backend, "playing 查询回调中的后端替换必须 fail closed。")
	assert_false(
		GFVariantData.to_bool(backend.replacement_result, true),
		"playing 查询回调中的重入替换应明确返回 false。"
	)
	assert_false(replacement_backend.setup_called, "被拒绝的重入替换不得 setup 新后端。")


func test_backend_bgm_playing_query_does_not_commit_stale_result_after_dispose() -> void:
	var backend: DisposingBgmQueryBackend = DisposingBgmQueryBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	watch_signals(_audio)
	_audio.play_bgm_with_options("event://music/stale-playing", {
		"history_key": "stale-playing",
	})
	backend.dispose_host_on_playing_query = true

	assert_false(_audio.is_bgm_playing(), "查询回调终结 Utility 后不得提交陈旧 playing 结果。")
	assert_push_warning(
		"[GFAudioUtility] dispose 强制终结：后端拒绝停止或正在回调，"
		+ "将解除内部 owner 并继续释放生命周期资源。"
	)
	assert_push_warning(
		"[GFAudioUtility] dispose 强制终结：后端 dispose 回调未完成，"
		+ "已解除内部后端引用。"
	)
	assert_null(_audio.get_audio_backend(), "陈旧查询结果不得复活已释放后端。")
	assert_eq(_audio._bgm_owner, &"none")
	assert_eq(_audio._bgm_state, &"stopped")
	assert_signal_emit_count(_audio, "bgm_finished", 0)


func test_backend_stop_callbacks_reject_reentrant_bgm_and_ambient_replacements() -> void:
	var backend: ReentrantAudioBackend = ReentrantAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/backend")
	_audio.play_ambient("event://ambient/backend", &"weather")

	var local_bgm_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var local_bgm_clip: GFAudioClip = GFAudioClip.new()
	local_bgm_clip.stream = local_bgm_stream
	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.STOP_BGM
	_audio.play_bgm_clip(local_bgm_clip)
	assert_eq(
		backend.played_bgm_paths,
		PackedStringArray(["event://music/backend"]),
		"stop_bgm 回调中的重入播放必须 fail closed。"
	)
	assert_same(_audio._bgm_player.stream, local_bgm_stream, "外层本地 BGM 替换应完成。")
	var bgm_snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_string_name(bgm_snapshot, "bgm_owner"), &"local")

	var local_ambient_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var local_ambient_clip: GFAudioClip = GFAudioClip.new()
	local_ambient_clip.stream = local_ambient_stream
	backend.reentry_stage = ReentrantAudioBackend.ReentryStage.STOP_AMBIENT
	_audio.play_ambient_clip(local_ambient_clip, &"weather")
	assert_eq(
		backend.played_ambient_paths,
		PackedStringArray(["event://ambient/backend"]),
		"stop_ambient 回调中的同通道重入播放必须 fail closed。"
	)
	var ambient_snapshot: Dictionary = _audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(
		ambient_snapshot,
		"ambient_sessions"
	)
	var weather_session: Dictionary = GFVariantData.get_option_dictionary(
		ambient_sessions,
		"weather"
	)
	assert_eq(GFVariantData.get_option_string_name(weather_session, "owner"), &"local")
	assert_same(_audio._get_ambient_player(&"weather").stream, local_ambient_stream)


func test_backend_detach_and_replace_retry_but_dispose_forces_terminal_state() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/backend")
	_audio.play_ambient("event://ambient/backend", &"weather")
	backend.allow_stop_bgm = false
	backend.allow_stop_ambient = false

	var clear_result: Variant = _audio.call("clear_audio_backend", false)
	assert_true(clear_result is bool, "clear_audio_backend 应返回明确 bool。")
	assert_false(GFVariantData.to_bool(clear_result, true), "拒绝停止时 clear 应返回 false。")
	assert_same(_audio.get_audio_backend(), backend, "clear 失败必须保留原后端。")
	assert_false(backend.disposed, "clear 失败不得 dispose 原后端。")

	var replacement_backend: MockAudioBackend = MockAudioBackend.new()
	var replace_result: Variant = _audio.call("set_audio_backend", replacement_backend)
	assert_true(replace_result is bool, "set_audio_backend 应返回明确 bool。")
	assert_false(GFVariantData.to_bool(replace_result, true), "拒绝停止时 replace 应返回 false。")
	assert_same(_audio.get_audio_backend(), backend, "replace 失败必须保留原后端。")
	assert_false(replacement_backend.setup_called, "replace 失败不得 setup 新后端。")

	_audio.dispose()
	assert_push_warning(
		"[GFAudioUtility] dispose 强制终结：后端拒绝停止或正在回调，"
		+ "将解除内部 owner 并继续释放生命周期资源。"
	)
	assert_null(_audio.get_audio_backend(), "dispose 必须解除后端引用。")
	assert_true(backend.disposed, "dispose 必须继续释放拒绝停止的后端。")
	assert_eq(_audio._bgm_owner, &"none", "dispose 必须清除 backend BGM owner。")
	assert_eq(_audio._bgm_state, &"stopped", "dispose 必须收敛 BGM 状态。")
	assert_true(_audio._ambient_sessions.is_empty(), "dispose 必须清除 backend ambient owner。")


func test_backend_detach_fails_when_an_owned_ambient_channel_rejects_stop() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_ambient("event://ambient/backend", &"weather")
	backend.allow_stop_ambient = false

	assert_false(_audio.clear_audio_backend(), "任一 backend-owned 环境音拒绝停止时不得卸载后端。")
	assert_same(_audio.get_audio_backend(), backend, "环境音停止失败必须保留原后端。")
	var failed_snapshot: Dictionary = _audio.get_debug_snapshot()
	var failed_sessions: Dictionary = GFVariantData.get_option_dictionary(
		failed_snapshot,
		"ambient_sessions"
	)
	var failed_weather: Dictionary = GFVariantData.get_option_dictionary(
		failed_sessions,
		"weather"
	)
	assert_eq(GFVariantData.get_option_string_name(failed_weather, "owner"), &"backend")
	assert_false(backend.disposed, "环境音停止失败不得 dispose 后端。")

	backend.allow_stop_ambient = true
	assert_true(_audio.clear_audio_backend(), "所有 backend-owned 通道成功停止后应允许卸载。")
	assert_null(_audio.get_audio_backend(), "成功卸载后不应残留后端引用。")
	assert_true(backend.disposed, "成功卸载应 dispose 后端。")


func test_backend_detach_commits_each_confirmed_stop_before_later_failure() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	backend.handle_ambient_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	_audio.play_bgm("event://music/backend")
	_audio.play_ambient("event://ambient/backend", &"weather")
	backend.allow_stop_ambient = false

	assert_false(
		_audio.clear_audio_backend(),
		"后续环境音停止失败时，本次后端卸载仍应 fail closed。"
	)
	var failed_snapshot: Dictionary = _audio.get_debug_snapshot()
	var failed_sessions: Dictionary = GFVariantData.get_option_dictionary(
		failed_snapshot,
		"ambient_sessions"
	)
	var failed_weather: Dictionary = GFVariantData.get_option_dictionary(
		failed_sessions,
		"weather"
	)
	assert_same(_audio.get_audio_backend(), backend, "部分停止失败不得卸载或 dispose 后端。")
	assert_false(backend.disposed, "部分停止失败不得 dispose 后端。")
	assert_eq(
		GFVariantData.get_option_string_name(failed_snapshot, "bgm_state"),
		&"stopped",
		"已由后端确认停止的 BGM 应立即提交内部 stopped 状态。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(failed_snapshot, "bgm_owner"),
		&"none",
		"已由后端确认停止的 BGM 不应继续保留 backend owner。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(failed_weather, "owner"),
		&"backend",
		"拒绝停止的环境音通道应继续由原后端拥有。"
	)
	assert_eq(backend.stop_bgm_count, 1, "第一次卸载应且只应停止一次 backend-owned BGM。")

	backend.allow_stop_ambient = true
	assert_true(_audio.clear_audio_backend(), "剩余 backend-owned 通道停止成功后应完成卸载。")
	assert_eq(backend.stop_bgm_count, 1, "重试只应处理仍由后端拥有的会话，不得重复停止 BGM。")
	assert_true(backend.disposed, "全部剩余会话停止后应 dispose 后端。")


func test_bus_volume() -> void:
	# "Master" 是默认存在的总线
	var bus_idx: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_idx)
	var original_muted: bool = AudioServer.is_bus_mute(bus_idx)

	_audio.set_bus_volume("Master", 0.5)
	assert_almost_eq(_audio.get_bus_volume("Master"), 0.5, 0.05, "音量设置取回应该近乎一致。")

	_audio.set_bus_volume("Master", 0.0)
	assert_true(AudioServer.is_bus_mute(bus_idx), "设置 0.0 时应真正静音总线。")
	assert_eq(_audio.get_bus_volume("Master"), 0.0, "静音总线读取音量应返回 0.0。")

	AudioServer.set_bus_volume_db(bus_idx, original_db)
	AudioServer.set_bus_mute(bus_idx, original_muted)


func _node_option(options: Dictionary, key: Variant) -> Node:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Node:
		var node: Node = value
		return node
	return null


func _resource_option(options: Dictionary, key: Variant) -> Resource:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Resource:
		var resource: Resource = value
		return resource
	return null
