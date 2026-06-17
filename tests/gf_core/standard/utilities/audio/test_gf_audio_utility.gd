extends GutTest


var _audio: GFAudioUtility
var _pool: GFObjectPoolUtility
var _created_audio_buses: PackedStringArray = PackedStringArray()


class MockAssetUtility:
	extends GFAssetUtility

	var pending: Dictionary = {}

	func load_async(path: String, on_loaded: Callable, _type_hint: String = "") -> void:
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


class MockAudioBackend:
	extends GFAudioBackend

	var setup_called: bool = false
	var disposed: bool = false
	var handle_bgm_paths: bool = false
	var played_bgm_paths: PackedStringArray = PackedStringArray()
	var played_sfx_paths: PackedStringArray = PackedStringArray()
	var posted_events: PackedStringArray = PackedStringArray()
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
	var bgm_paused: bool = false
	var stop_all_sfx_fade: float = -1.0
	var external_volume: float = -1.0
	var external_volume_db: float = 0.0
	var external_muted: bool = false
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
		return channel == &"sfx" and path.begins_with("event://")

	func can_handle_clip(_clip: GFAudioClip, channel: StringName, context: Dictionary = {}) -> bool:
		return handle_spatial_sfx_clips and channel == &"spatial_sfx" and context.has("source")

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var _append_result_106: Variant = played_bgm_paths.append(path)
		last_bgm_options = options.duplicate(true)
		return true

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

	func is_bgm_paused() -> bool:
		return bgm_paused

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

	func get_debug_snapshot() -> Dictionary:
		return {
			"played_sfx_count": played_sfx_paths.size(),
			"disposed": disposed,
		}


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
	backend.bgm_position = 12.5
	_audio.set_audio_backend(backend)

	assert_true(_audio.pause_bgm(0.2), "后端可接管 BGM 暂停。")
	assert_true(_audio.is_bgm_paused(), "后端暂停状态应暴露给查询接口。")
	assert_true(_audio.resume_bgm(3.0, 0.1), "后端可接管 BGM 恢复。")
	assert_true(_audio.seek_bgm(8.0), "后端可接管 BGM 跳转。")
	assert_almost_eq(backend.pause_bgm_fade, 0.2, 0.001, "暂停淡出时间应传给后端。")
	assert_almost_eq(backend.resume_bgm_position, 3.0, 0.001, "恢复位置应传给后端。")
	assert_almost_eq(backend.resume_bgm_fade, 0.1, 0.001, "恢复淡入时间应传给后端。")
	assert_almost_eq(backend.seek_bgm_position, 8.0, 0.001, "跳转位置应传给后端。")
	assert_almost_eq(_audio.get_bgm_playback_position(), 8.0, 0.001, "播放位置应优先读取后端。")


func test_play_bgm_with_options_passes_loop_to_backend_and_debug_snapshot() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	_audio.set_audio_backend(backend)

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


func test_audio_backend_can_handle_selected_requests() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	_audio.set_audio_backend(backend)

	var handle: GFAudioEmitterHandle = _audio.play_sfx_handle("event://ui/click")
	_audio.set_bus_volume("External", 0.25)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var backend_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, "backend_snapshot")

	assert_true(backend.setup_called, "设置后端时应调用 setup。")
	assert_not_null(handle, "后端处理 SFX 时应返回句柄。")
	assert_eq(backend.played_sfx_paths, PackedStringArray(["event://ui/click"]), "声明可处理的路径应交给后端。")
	assert_almost_eq(_audio.get_bus_volume("External"), 0.25, 0.001, "后端可接管自定义总线音量。")
	assert_eq(GFVariantData.get_option_int(backend_snapshot, "played_sfx_count"), 1, "音频工具调试快照应包含后端快照。")

	_audio.clear_audio_backend()
	assert_true(backend.disposed, "清理后端时应调用 dispose。")


func test_audio_backend_receives_spatial_settings_context() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_spatial_sfx_clips = true
	_audio.set_audio_backend(backend)
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
	_audio.set_audio_backend(backend)
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


func test_audio_catalog_provider_lists_entries() -> void:
	var catalog: GFAudioCatalogProvider = GFAudioCatalogProvider.new()
	catalog.set_entry(&"events", &"ui_confirm", { "group": "ui" })
	catalog.set_entry(&"parameters", &"intensity", { "min": 0.0, "max": 1.0 })
	var parameter_entry: Dictionary = catalog.describe_entry(&"parameters", &"intensity")

	assert_eq(catalog.get_ids(&"events"), PackedStringArray(["ui_confirm"]), "目录应列出事件 ID。")
	assert_eq(GFVariantData.get_option_float(parameter_entry, "max"), 1.0, "目录应返回条目元数据。")


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
	_audio.set_audio_backend(backend)
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
	handle.stop()
	mock_asset.finish("res://audio/sfx.ogg", AudioStreamGenerator.new())

	assert_true(handle.is_stop_requested(), "异步资源返回前停止句柄应记录停止请求。")
	assert_eq(audio.sfx_play_count, 0, "已停止的异步 SFX 请求完成后不应再播放。")
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
	_audio.set_audio_backend(backend)

	assert_true(_audio.set_bus_volume_db("External", -3.0), "后端可接管 dB 总线音量。")
	assert_true(_audio.set_bus_mute("External", true), "后端可接管总线静音。")
	assert_true(_audio.set_bus_effect_property("External", "lowpass", &"cutoff_hz", 900.0, 0.2), "后端可接管效果属性。")
	var report: Dictionary = _audio.apply_mix_snapshot({ "backend_only": true }, 0.3)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "后端处理混音快照时应返回成功报告。")
	assert_almost_eq(backend.external_volume_db, -3.0, 0.001, "dB 音量应传给后端。")
	assert_true(backend.external_muted, "静音状态应传给后端。")
	assert_eq(backend.effect_property_requests.size(), 1, "效果属性请求应传给后端。")
	assert_almost_eq(backend.handled_mix_transition, 0.3, 0.001, "快照过渡时间应传给后端。")


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
