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


class ImmediateAssetUtility:
	extends GFAssetUtility

	var resource: Resource

	func _init(loaded_resource: Resource) -> void:
		resource = loaded_resource

	func load_async(
		_path: String,
		on_loaded: Callable,
		_type_hint: String = "",
		_options: Dictionary = {}
	) -> void:
		on_loaded.call(resource)


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


class SnapshotGraphResource:
	extends Resource

	@export var payload: Variant = null
	@export var secondary_payload: Variant = null


class CopyingSnapshotResource:
	extends Resource

	var _payload: Array = []

	@export var payload: Array:
		get:
			return _payload
		set(value):
			_payload = value.duplicate()


class CopyingPackedSnapshotResource:
	extends Resource

	var _payload: PackedByteArray = PackedByteArray()

	@export var payload: PackedByteArray:
		get:
			return _payload
		set(value):
			_payload = value.duplicate()


class CoupledSnapshotResource:
	extends Resource

	var _second: int = 0

	@export var first: int = 0
	@export var second: int:
		get:
			return _second
		set(value):
			_second = value
			first = -1


class ReadOnlySnapshotResource:
	extends Resource

	var _locked_value: int = 7

	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": &"locked_value",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY,
		}]

	func _get(property_name: StringName) -> Variant:
		if property_name == &"locked_value":
			return _locked_value
		return null


class NeverDuplicateSnapshotResource:
	extends Resource

	func _get_property_list() -> Array[Dictionary]:
		return [{
			"name": &"never_duplicate_value",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_NEVER_DUPLICATE,
		}]

	func _get(property_name: StringName) -> Variant:
		if property_name == &"never_duplicate_value":
			return 7
		return null


class ExpandingStorageSchemaSnapshotResource:
	extends Resource

	func _get_property_list() -> Array[Dictionary]:
		if has_meta(&"hide_extra_storage"):
			return []
		return [{
			"name": &"extra_storage",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_STORAGE,
		}]

	func _get(property_name: StringName) -> Variant:
		if property_name == &"extra_storage":
			return 9
		return null

	func _set(property_name: StringName, _value: Variant) -> bool:
		return property_name == &"extra_storage"


class MutableDictionaryAudioEffect:
	extends AudioEffectLowPassFilter

	var payload: Dictionary = {}


class MockAudioBackend:
	extends GFAudioBackend

	var setup_called: bool = false
	var disposed: bool = false
	var handle_bgm_paths: bool = false
	var handle_ambient_paths: bool = false
	var handle_bgm_clips: bool = false
	var handle_ambient_clips: bool = false
	var played_bgm_paths: PackedStringArray = PackedStringArray()
	var played_ambient_paths: PackedStringArray = PackedStringArray()
	var played_sfx_paths: PackedStringArray = PackedStringArray()
	var posted_events: PackedStringArray = PackedStringArray()
	var handle_posted_events: bool = true
	var parameter_values: Dictionary = {}
	var parameter_request_count: int = 0
	var state_request_count: int = 0
	var switch_request_count: int = 0
	var last_parameter: GFAudioParameter = null
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
	var mix_snapshot_request_count: int = 0
	var effect_property_requests: Array[Dictionary] = []
	var accept_effect_property_requests: bool = true
	var mutate_effect_property_value: bool = false
	var playback_region_evaluation_count: int = 0
	var playback_region_evaluation_status: GFAudioPlaybackRegionResult.Status = (
		GFAudioPlaybackRegionResult.Status.UNSUPPORTED
	)
	var playback_region_returns_untrusted_fields: bool = false
	var last_evaluated_region: GFAudioPlaybackRegion = null
	var played_bgm_clip_count: int = 0
	var last_bgm_clip: GFAudioClip = null
	var mutate_can_handle_clip_request: bool = false
	var mutate_can_handle_clip_nested_resources: bool = false
	var mutate_evaluate_clip_nested_resources: bool = false
	var mutate_play_bgm_clip_nested_resources: bool = false
	var mutate_can_handle_event_request: bool = false
	var mutate_can_handle_event_nested_resources: bool = false
	var mutate_play_bgm_clip_request: bool = false
	var mutate_post_event_request: bool = false
	var mutate_post_event_nested_resources: bool = false
	var accept_bgm_clip_playback: bool = true
	var played_ambient_clip_count: int = 0
	var last_ambient_clip: GFAudioClip = null
	var last_ambient_options: Dictionary = {}
	var last_posted_event: GFAudioEvent = null
	var last_posted_event_options: Dictionary = {}
	var can_handle_path_count: int = 0
	var can_handle_event_count: int = 0
	var can_handle_event_resource_before: float = -1.0
	var can_handle_event_option_resource_before: float = -1.0
	var post_event_resource_before: float = -1.0
	var post_event_option_resource_before: float = -1.0

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
		can_handle_path_count += 1
		if channel == &"bgm":
			return handle_bgm_paths and path.begins_with("event://")
		if channel == &"ambient":
			return handle_ambient_paths and path.begins_with("event://")
		return channel == &"sfx" and path.begins_with("event://")

	func can_handle_clip(clip: GFAudioClip, channel: StringName, context: Dictionary = {}) -> bool:
		if mutate_can_handle_clip_request:
			clip.playback_region = null
			clip.stream = AudioStreamGenerator.new()
			context.clear()
		if mutate_can_handle_clip_nested_resources:
			_mutate_clip_nested_resources(clip)
		if handle_bgm_clips and channel == &"bgm":
			return true
		if handle_ambient_clips and channel == &"ambient":
			return true
		return handle_spatial_sfx_clips and channel == &"spatial_sfx" and context.has("source")

	func evaluate_playback_region(
		clip: GFAudioClip,
		_channel: StringName,
		region: GFAudioPlaybackRegion,
		_context: Dictionary = {}
	) -> GFAudioPlaybackRegionResult:
		playback_region_evaluation_count += 1
		if mutate_evaluate_clip_nested_resources:
			_mutate_clip_nested_resources(clip)
		last_evaluated_region = region
		var result: GFAudioPlaybackRegionResult = GFAudioPlaybackRegionResult.new()
		result.status = playback_region_evaluation_status
		result.reason = (
			&"backend_region_applied"
			if result.status == GFAudioPlaybackRegionResult.Status.APPLIED
			else &"backend_region_rejected"
		)
		result.start_seconds = region.start_seconds
		result.end_seconds = region.end_seconds
		result.loop_start_seconds = (
			region.start_seconds
			if (
				region.loop_mode != GFAudioPlaybackRegion.LoopMode.DISABLED
				and is_equal_approx(region.loop_start_seconds, -1.0)
			)
			else region.loop_start_seconds
		)
		result.loop_mode = region.loop_mode
		if playback_region_returns_untrusted_fields:
			result.start_seconds = NAN
			result.end_seconds = INF
			result.loop_start_seconds = -99.0
			result.loop_mode = 99
		return result

	func play_bgm_path(path: String, options: Dictionary = {}) -> bool:
		var _append_result_106: Variant = played_bgm_paths.append(path)
		last_bgm_options = options.duplicate(true)
		bgm_playing = true
		return true

	func play_bgm_clip(clip: GFAudioClip, options: Dictionary = {}) -> bool:
		played_bgm_clip_count += 1
		last_bgm_clip = clip
		last_bgm_options = options.duplicate(true)
		if mutate_play_bgm_clip_request:
			clip.playback_region = null
			clip.stream = AudioStreamGenerator.new()
			options.clear()
		if mutate_play_bgm_clip_nested_resources:
			_mutate_clip_nested_resources(clip)
		bgm_playing = true
		return accept_bgm_clip_playback

	func _mutate_clip_nested_resources(clip: GFAudioClip) -> void:
		if clip.stream is AudioStreamWAV:
			var wav_stream: AudioStreamWAV = clip.stream
			wav_stream.mix_rate = 1
			wav_stream.loop_mode = AudioStreamWAV.LOOP_BACKWARD
		if clip.spatial_settings is GFAudioSpatialSettings:
			var spatial_settings: GFAudioSpatialSettings = clip.spatial_settings
			spatial_settings.max_distance_2d = 1.0
		var metadata_resource: GFAudioSpatialSettings = _get_nested_settings_resource(
			clip.metadata
		)
		if metadata_resource != null:
			metadata_resource.max_distance_2d = 1.0

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

	func play_ambient_clip(
		clip: GFAudioClip,
		channel: StringName = &"default",
		options: Dictionary = {}
	) -> bool:
		played_ambient_clip_count += 1
		last_ambient_clip = clip
		last_ambient_options = options.duplicate(true)
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

	func can_handle_event(event: GFAudioEvent, options: Dictionary = {}) -> bool:
		can_handle_event_count += 1
		var can_handle: bool = event.event_id != &""
		if mutate_can_handle_event_request:
			event.clip = null
			event.channel = &"mutated"
			options.clear()
		if mutate_can_handle_event_nested_resources:
			var event_resource: GFAudioSpatialSettings = _get_nested_settings_resource(
				event.metadata
			)
			var option_resource: GFAudioSpatialSettings = _get_nested_settings_resource(
				options
			)
			if event_resource != null:
				can_handle_event_resource_before = event_resource.max_distance_2d
				event_resource.max_distance_2d = 1.0
			if option_resource != null:
				can_handle_event_option_resource_before = option_resource.max_distance_2d
				option_resource.max_distance_2d = 2.0
		return can_handle

	func post_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:
		var _append_result_156: Variant = posted_events.append(String(event.event_id))
		last_posted_event = event
		last_posted_event_options = options.duplicate(true)
		if mutate_post_event_request:
			event.clip = null
			event.channel = &"mutated"
			options.clear()
		if mutate_post_event_nested_resources:
			var event_resource: GFAudioSpatialSettings = _get_nested_settings_resource(
				event.metadata
			)
			var option_resource: GFAudioSpatialSettings = _get_nested_settings_resource(
				options
			)
			if event_resource != null:
				post_event_resource_before = event_resource.max_distance_2d
				event_resource.max_distance_2d = 3.0
			if option_resource != null:
				post_event_option_resource_before = option_resource.max_distance_2d
				option_resource.max_distance_2d = 4.0
		if not handle_posted_events:
			return null
		return GFAudioEmitterHandle.new(null, Callable(), &"event", options)

	func _get_nested_settings_resource(payload: Dictionary) -> GFAudioSpatialSettings:
		var nested_value: Variant = GFVariantData.get_option_value(payload, "nested")
		if not (nested_value is Dictionary):
			return null
		var nested: Dictionary = nested_value
		var resources_value: Variant = GFVariantData.get_option_value(nested, "resources")
		if not (resources_value is Array):
			return null
		var resources: Array = resources_value
		if resources.is_empty():
			return null
		var resource_value: Variant = resources[0]
		if resource_value is GFAudioSpatialSettings:
			var settings: GFAudioSpatialSettings = resource_value
			return settings
		return null

	func set_parameter(parameter: GFAudioParameter) -> bool:
		parameter_request_count += 1
		last_parameter = parameter
		parameter_values[parameter.parameter_id] = parameter.value
		return true

	func set_state(_state: GFAudioState) -> bool:
		state_request_count += 1
		return true

	func set_switch(_audio_switch: GFAudioSwitch) -> bool:
		switch_request_count += 1
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
		if mutate_effect_property_value and value is Dictionary:
			var mutable_value: Dictionary = value
			mutable_value.clear()
			mutable_value["backend_mutated"] = true
		effect_property_requests.append({
			"effect_ref": effect_ref,
			"property_name": property_name,
			"value": value,
			"transition_seconds": transition_seconds,
		})
		return accept_effect_property_requests and bus_name == "External"

	func apply_mix_snapshot(snapshot: Dictionary, transition_seconds: float = 0.0) -> bool:
		mix_snapshot_request_count += 1
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


class OwnedBusAudioBackend:
	extends GFAudioBackend

	var owned_bus_name: String = "Master"
	var volume_db: float = -6.0
	var muted: bool = false
	var handle_volume: bool = true
	var handle_mute: bool = true
	var observe_volume: bool = true
	var observe_mute: bool = true
	var disposed: bool = false
	var bulk_apply_count: int = 0
	var volume_apply_count: int = 0
	var mute_apply_count: int = 0
	var last_transition_seconds: float = -1.0

	func dispose() -> void:
		disposed = true
		super.dispose()

	func apply_mix_snapshot(_snapshot: Dictionary, _transition_seconds: float = 0.0) -> bool:
		bulk_apply_count += 1
		return false

	func set_bus_volume_db(
		bus_name: String,
		target_volume_db: float,
		transition_seconds: float = 0.0
	) -> bool:
		if bus_name != owned_bus_name or not handle_volume:
			return false
		volume_apply_count += 1
		volume_db = target_volume_db
		last_transition_seconds = transition_seconds
		return true

	func set_bus_mute(bus_name: String, target_muted: bool) -> bool:
		if bus_name != owned_bus_name or not handle_mute:
			return false
		mute_apply_count += 1
		muted = target_muted
		return true

	func get_bus_volume(bus_name: String) -> float:
		if bus_name != owned_bus_name or not observe_volume:
			return -1.0
		return db_to_linear(volume_db)

	func get_bus_mute(bus_name: String) -> Variant:
		if bus_name != owned_bus_name or not observe_mute:
			return null
		return muted


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


func test_audio_utility_init_is_idempotent_and_reusable_after_dispose() -> void:
	var original_bgm_player: AudioStreamPlayer = _audio._bgm_player
	var original_fade_player: AudioStreamPlayer = _audio._bgm_fade_player
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)

	_audio.init()
	await get_tree().process_frame

	assert_same(_audio._bgm_player, original_bgm_player, "重复 init 必须保留当前 BGM generation。")
	assert_same(_audio._bgm_fade_player, original_fade_player)
	assert_true(handle.is_valid(), "重复 init 不得先丢账本再遗留活动 SFX。")
	assert_eq(_count_root_audio_players_named("GFBGMPlayer"), 1)
	assert_eq(_count_root_audio_players_named("GFBGMFadePlayer"), 1)
	handle.stop()

	_audio.dispose()
	await get_tree().process_frame
	_audio.init()
	await get_tree().process_frame

	assert_not_same(_audio._bgm_player, original_bgm_player, "dispose 后 init 应创建新生命周期 generation。")
	assert_not_same(_audio._bgm_fade_player, original_fade_player)
	assert_eq(_count_root_audio_players_named("GFBGMPlayer"), 1)
	assert_eq(_count_root_audio_players_named("GFBGMFadePlayer"), 1)


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


func test_play_bgm_with_options_rejects_reserved_region_keys_before_backend_dispatch() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	_audio.play_bgm_with_options("event://music/title", {
		"crossfade_seconds": 0.25,
		"history_key": "title",
		"playback_region": GFAudioPlaybackRegion.new(),
	})
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_push_warning(
		"[GFAudioUtility] play_bgm_with_options 不接受 loop 或 playback_region；"
		+ "请使用 GFAudioClip.playback_region 表达唯一的循环契约。"
	)
	assert_true(backend.played_bgm_paths.is_empty(), "保留的区间键必须在后端派发前被拒绝。")
	assert_true(backend.last_bgm_options.is_empty(), "被拒绝的保留键不得进入后端请求。")
	assert_eq(_audio.get_current_bgm_key(), "", "被拒绝请求不得提交 BGM 历史 key。")
	assert_true(
		GFVariantData.get_option_dictionary(snapshot, "current_bgm_region").is_empty(),
		"被拒绝请求不得留下播放区间状态。"
	)
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"none")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"stopped")


func test_play_bgm_with_options_rejects_unbounded_graphs_before_backend_dispatch() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_paths = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var cyclic_options: Dictionary = {}
	cyclic_options["self"] = cyclic_options
	_audio.play_bgm_with_options(
		"event://music/cyclic-options",
		{"nested": cyclic_options}
	)
	cyclic_options.clear()

	var deep_options: Dictionary = {}
	var deep_cursor: Dictionary = deep_options
	for index: int in range(32):
		var child: Dictionary = {
			"index": index,
		}
		deep_cursor["child"] = child
		deep_cursor = child
	_audio.play_bgm_with_options(
		"event://music/deep-options",
		{"nested": deep_options}
	)

	var oversized_items: Array = []
	for index: int in range(1100):
		oversized_items.append(index)
	_audio.play_bgm_with_options(
		"event://music/oversized-options",
		{"nested": oversized_items}
	)

	assert_eq(
		backend.can_handle_path_count,
		0,
		"不安全 BGM options 图必须在首次后端回调前失败关闭。"
	)
	assert_true(backend.played_bgm_paths.is_empty())
	assert_eq(_audio._bgm_owner, &"none", "失败请求不得提交或替换 BGM owner。")


func test_bgm_finished_signal_emits_for_active_player() -> void:
	watch_signals(_audio)
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "finish-test"
	clip.stream = stream
	clip.bus_name = GFAudioUtility.BGM_BUS_NAME
	var operation: GFBgmStartOperation = _audio.start_bgm_clip(clip, 0.0)
	assert_not_null(operation)
	assert_true(operation.is_completed())
	var result: GFBgmStartResult = operation.get_result()
	assert_not_null(result)
	assert_eq(result.get_status(), GFBgmStartResult.Status.STARTED)
	var session: GFBgmSessionHandle = result.get_session_handle()
	assert_not_null(session)
	watch_signals(session)

	_audio._bgm_player.finished.emit()

	assert_signal_emitted_with_parameters(_audio, "bgm_finished", ["finish-test"])
	assert_eq(_audio.get_current_bgm_key(), "", "自然结束后当前 BGM key 应清空。")
	assert_true(session.is_terminal())
	assert_eq(session.get_end_kind(), GFBgmSessionHandle.EndKind.NATURAL_FINISH)
	assert_signal_emit_count(session, "ended", 1)


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


func test_typed_playback_region_uses_private_streams_across_local_channels() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = 0.2
	var clip: GFAudioClip = _make_test_bgm_clip("shared-region", region)
	var source_stream: AudioStreamWAV = clip.stream as AudioStreamWAV
	var source_2d: Node2D = Node2D.new()
	add_child_autofree(source_2d)

	_audio.play_ambient_clip(clip, &"weather")
	var sfx_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var spatial_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_2d_handle(
		clip,
		source_2d
	)
	var ambient_player: AudioStreamPlayer = _audio._get_ambient_player(&"weather")
	var sfx_player: AudioStreamPlayer = sfx_handle.get_player() as AudioStreamPlayer
	var spatial_player: AudioStreamPlayer2D = (
		spatial_handle.get_player() as AudioStreamPlayer2D
	)
	var ambient_stream: AudioStreamWAV = ambient_player.stream as AudioStreamWAV
	var sfx_stream: AudioStreamWAV = sfx_player.stream as AudioStreamWAV
	var spatial_stream: AudioStreamWAV = spatial_player.stream as AudioStreamWAV
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"ambient_sessions"
	)
	var weather_session: Dictionary = GFVariantData.get_option_dictionary(
		ambient_sessions,
		"weather"
	)
	var session_region: Dictionary = GFVariantData.get_option_dictionary(
		weather_session,
		"playback_region"
	)

	assert_not_same(ambient_stream, source_stream)
	assert_not_same(sfx_stream, source_stream)
	assert_not_same(spatial_stream, source_stream)
	assert_not_same(ambient_stream, sfx_stream, "每次播放请求必须拥有独立流副本。")
	assert_not_same(sfx_stream, spatial_stream, "空间与非空间 SFX 不得共享可变循环状态。")
	assert_eq(ambient_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(sfx_stream.loop_begin, 200)
	assert_eq(spatial_stream.loop_end, 1_999)
	assert_eq(source_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "源流不得被区间准备修改。")
	assert_eq(
		GFVariantData.get_option_string_name(session_region, "status"),
		&"applied",
		"环境音会话快照应保留规范化区间。"
	)


func test_ambient_stop_preserves_region_until_local_fade_reaches_terminal_state() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	region.loop_start_seconds = 0.25
	var clip: GFAudioClip = _make_test_bgm_clip("local-ambient-region", region)
	clip.volume_db = -6.0
	_audio.play_ambient_clip(clip, &"weather")

	_audio.stop_ambient(&"weather", 0.25)
	await get_tree().create_timer(0.08).timeout
	var player: AudioStreamPlayer = _audio._get_ambient_player(&"weather")
	assert_lt(player.volume_db, -6.1, "测试应确认停止淡出已经部分修改播放器增益。")
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var sessions: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	var weather: Dictionary = GFVariantData.get_option_dictionary(sessions, "weather")
	var stopping_region: Dictionary = GFVariantData.get_option_dictionary(
		weather,
		"playback_region"
	)

	assert_eq(GFVariantData.get_option_string_name(weather, "state"), &"stopping")
	assert_eq(GFVariantData.get_option_string_name(weather, "owner"), &"local")
	assert_almost_eq(
		GFVariantData.get_option_float(weather, "target_volume_db"),
		-6.0,
		0.001,
		"非终态会话必须保留原始目标增益。"
	)
	assert_eq(
		GFVariantData.get_option_int(stopping_region, "loop_mode"),
		GFAudioPlaybackRegion.LoopMode.FORWARD,
		"非终态淡出必须保留仍在播放的类型化区间。"
	)

	var replacement_serial: int = _audio._begin_ambient_replacement(&"weather")
	_audio._apply_ambient_request(
		replacement_serial,
		&"weather",
		null,
		"Master",
		0.0,
		1.0,
		0.0
	)
	snapshot = _audio.get_debug_snapshot()
	sessions = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	weather = GFVariantData.get_option_dictionary(sessions, "weather")
	var restored_region: Dictionary = GFVariantData.get_option_dictionary(
		weather,
		"playback_region"
	)
	assert_eq(GFVariantData.get_option_string_name(weather, "state"), &"playing")
	assert_eq(
		GFVariantData.get_option_int(restored_region, "loop_mode"),
		GFAudioPlaybackRegion.LoopMode.FORWARD,
		"淡出被替换请求打断且替换失败时必须恢复原区间诊断。"
	)
	assert_almost_eq(player.volume_db, -6.0, 0.001, "替换失败必须恢复淡出前的目标增益。")
	_audio.stop_ambient(&"weather")


func test_rejected_ambient_region_does_not_cancel_active_stop_fade() -> void:
	var active_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	active_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var active_clip: GFAudioClip = _make_test_bgm_clip("ambient-stop-active", active_region)
	_audio.play_ambient_clip(active_clip, &"weather")
	_audio.stop_ambient(&"weather", 0.25)
	await get_tree().create_timer(0.05).timeout
	var before_session: Dictionary = _audio._get_ambient_session(&"weather")
	var before_generation: int = GFVariantData.get_option_int(before_session, "generation")
	var before_tween_value: Variant = GFVariantData.get_option_value(
		_audio._ambient_tween_refs,
		&"weather"
	)
	var before_tween_ref: WeakRef = null
	if before_tween_value is WeakRef:
		before_tween_ref = before_tween_value
	assert_eq(GFVariantData.get_option_string_name(before_session, "state"), &"stopping")
	assert_not_null(before_tween_ref)

	var rejected_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	rejected_region.start_seconds = 0.1
	var rejected_clip: GFAudioClip = GFAudioClip.new()
	rejected_clip.stream = AudioStreamGenerator.new()
	rejected_clip.playback_region = rejected_region
	_audio.play_ambient_clip(rejected_clip, &"weather")
	var after_session: Dictionary = _audio._get_ambient_session(&"weather")

	assert_eq(
		GFVariantData.get_option_int(after_session, "generation"),
		before_generation,
		"未通过 exact admission 的请求不得替换活动环境音 generation。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(after_session, "state"),
		&"stopping",
		"拒绝请求不得把既有停止淡出恢复为 playing。"
	)
	var after_tween_value: Variant = GFVariantData.get_option_value(
		_audio._ambient_tween_refs,
		&"weather"
	)
	var after_tween_ref: WeakRef = null
	if after_tween_value is WeakRef:
		after_tween_ref = after_tween_value
	assert_same(after_tween_ref, before_tween_ref, "拒绝请求不得取消或替换既有环境音 tween。")

	await get_tree().create_timer(0.25).timeout
	var terminal_session: Dictionary = _audio._get_ambient_session(&"weather")
	assert_eq(GFVariantData.get_option_string_name(terminal_session, "state"), &"stopped")
	assert_eq(GFVariantData.get_option_string_name(terminal_session, "owner"), &"none")


func test_failed_async_ambient_replacement_releases_ended_local_stream() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame

	var original_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var original_clip: GFAudioClip = GFAudioClip.new()
	original_clip.stream = original_stream
	audio.play_ambient_clip(original_clip, &"weather")
	var weather_player: AudioStreamPlayer = audio._get_ambient_player(&"weather")

	audio.play_ambient("res://audio/missing-weather.ogg", &"weather")
	var loading_session: Dictionary = audio._get_ambient_session(&"weather")
	assert_eq(GFVariantData.get_option_string_name(loading_session, "state"), &"loading")
	assert_eq(GFVariantData.get_option_string_name(loading_session, "owner"), &"local")
	assert_eq(GFVariantData.get_option_int(loading_session, "playback_session_id"), 0)
	weather_player.stop()
	weather_player.finished.emit()
	assert_same(
		weather_player.stream,
		original_stream,
		"异步替换等待期间，旧流自然结束应进入失败恢复的终态清理路径。"
	)

	mock_asset.finish("res://audio/missing-weather.ogg", null)
	var weather_session: Dictionary = audio._get_ambient_session(&"weather")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "state"), &"stopped")
	assert_eq(GFVariantData.get_option_string_name(weather_session, "owner"), &"none")
	assert_null(weather_player.stream, "替换加载失败后不得继续持有已经结束的旧流资源。")

	audio.dispose()
	await get_tree().process_frame


func test_backend_ambient_stop_rejection_preserves_active_region_snapshot() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_ambient_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.APPLIED
	backend.allow_stop_ambient = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.2
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region
	_audio.play_ambient_clip(clip, &"weather")

	_audio.stop_ambient(&"weather", 0.1)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var sessions: Dictionary = GFVariantData.get_option_dictionary(snapshot, "ambient_sessions")
	var weather: Dictionary = GFVariantData.get_option_dictionary(sessions, "weather")
	var active_region: Dictionary = GFVariantData.get_option_dictionary(
		weather,
		"playback_region"
	)

	assert_eq(backend.played_ambient_clip_count, 1)
	assert_eq(GFVariantData.get_option_string_name(weather, "state"), &"playing")
	assert_eq(GFVariantData.get_option_string_name(weather, "owner"), &"backend")
	assert_almost_eq(
		GFVariantData.get_option_float(active_region, "start_seconds"),
		0.2,
		0.001,
		"后端拒绝停止时仍活动的区间诊断不得被清空。"
	)
	backend.allow_stop_ambient = true
	_audio.stop_ambient(&"weather")


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


func test_pooled_sfx_reacquire_restores_template_properties() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"
	var first_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var first_player: AudioStreamPlayer = first_handle.get_player() as AudioStreamPlayer
	var baseline_max_polyphony: int = first_player.max_polyphony
	var baseline_mix_target: int = first_player.mix_target
	var baseline_playback_type: int = first_player.playback_type

	first_player.autoplay = true
	first_player.stream_paused = true
	first_player.max_polyphony = baseline_max_polyphony + 6
	first_player.mix_target = AudioStreamPlayer.MIX_TARGET_SURROUND
	first_player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	first_handle.stop()
	# 旧调用方仍持有 raw player；acquire 边界也必须重建模板，不能只在 release 时清理。
	first_player.autoplay = true
	first_player.stream_paused = true
	first_player.max_polyphony = baseline_max_polyphony + 7
	first_player.mix_target = AudioStreamPlayer.MIX_TARGET_CENTER
	first_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM

	var second_handle: GFAudioEmitterHandle = _audio.play_sfx_clip_handle(clip)
	var reused_player: AudioStreamPlayer = second_handle.get_player() as AudioStreamPlayer

	assert_same(reused_player, first_player, "测试必须确认复用了同一池节点。")
	assert_false(reused_player.autoplay, "复用播放器不得继承旧 lease 的 autoplay。")
	assert_false(reused_player.stream_paused, "复用播放器不得继承旧 lease 的暂停状态。")
	assert_eq(
		reused_player.max_polyphony,
		baseline_max_polyphony,
		"复用播放器必须恢复模板 polyphony。"
	)
	assert_eq(reused_player.mix_target, baseline_mix_target, "复用播放器必须恢复模板 mix target。")
	assert_eq(
		reused_player.playback_type,
		baseline_playback_type,
		"复用播放器必须恢复模板 playback type。"
	)
	assert_eq(reused_player.bus, "Master", "本次 clip 的 bus 配置仍应在模板恢复后生效。")
	assert_almost_eq(reused_player.volume_db, 0.0, 0.001)
	assert_almost_eq(reused_player.pitch_scale, 1.0, 0.001)
	second_handle.stop()


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


func test_utility_audio_bank_resolution_preserves_multichar_split_fallback() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var bank: GFAudioBank = GFAudioBank.new()
	bank.fallback_separator = "::"
	bank.set_clip(&"a", clip)

	var bank_resolution: Dictionary = bank.resolve_clip(&"a:::missing")
	var bank_resolution_clip: GFAudioClip = null
	var raw_bank_resolution_clip: Variant = GFVariantData.get_option_value(
		bank_resolution,
		"clip"
	)
	if raw_bank_resolution_clip is GFAudioClip:
		bank_resolution_clip = raw_bank_resolution_clip
	var handle: GFAudioEmitterHandle = _audio.play_sfx_from_bank_handle(
		bank,
		&"a:::missing"
	)

	assert_same(
		bank_resolution_clip,
		clip,
		"GFAudioBank 的既有 split fallback 应命中 a。"
	)
	assert_not_null(
		handle,
		"Utility 的有界 resolver 必须保留 GFAudioBank 的多字符 split fallback 语义。"
	)
	if handle != null:
		assert_true(handle.is_valid(), "命中的 Bank clip 应建立有效播放句柄。")
		handle.stop()


func test_utility_audio_bank_resolution_enforces_fallback_step_boundary() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var bank: GFAudioBank = GFAudioBank.new()
	bank.fallback_separator = "::"
	bank.set_clip(&"root", clip)

	var within_budget_id: String = "root"
	for index: int in range(16):
		within_budget_id += "::level%d" % index
	var within_budget_handle: GFAudioEmitterHandle = _audio.play_sfx_from_bank_handle(
		bank,
		StringName(within_budget_id)
	)
	assert_not_null(
		within_budget_handle,
		"第 16 次 fallback 仍应允许命中根 ID。"
	)
	if within_budget_handle != null:
		within_budget_handle.stop()

	var over_budget_id: String = within_budget_id + "::overflow"
	var over_budget_handle: GFAudioEmitterHandle = _audio.play_sfx_from_bank_handle(
		bank,
		StringName(over_budget_id)
	)
	assert_null(
		over_budget_handle,
		"第 17 次 fallback 不得继续解析到根 ID。"
	)


func test_utility_audio_bank_resolution_is_bounded_before_clip_snapshot() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var bank: GFAudioBank = GFAudioBank.new()
	bank.set_clip(&"ui+select", clip)
	var bounded_clip: GFAudioClip = _audio._resolve_bounded_audio_bank_clip(
		bank,
		&"ui+select+primary"
	)
	assert_not_null(bounded_clip)
	assert_not_same(bounded_clip, clip, "命中候选必须先转为受控 clip 快照。")

	var oversized_candidates: Array[GFAudioClip] = []
	for _index: int in range(1025):
		oversized_candidates.append(clip)
	bank.clips[&"crowded"] = oversized_candidates
	assert_null(
		_audio._resolve_bounded_audio_bank_clip(bank, &"crowded"),
		"超限候选列表不得被遍历或抽样。"
	)

	bank.set_clip(&"root", clip)
	var deep_identifier: String = "root"
	for index: int in range(18):
		deep_identifier += "+level%d" % index
	assert_null(
		_audio._resolve_bounded_audio_bank_clip(
			bank,
			StringName(deep_identifier)
		),
		"fallback 层级超过硬上限时不得继续解析到根 ID。"
	)
	assert_null(
		_audio._resolve_bounded_audio_bank_clip(
			bank,
			StringName("x".repeat(1025))
		),
		"超长 clip ID 必须在分割前失败关闭。"
	)

	bank.fallback_separator = "separator-too-long"
	assert_null(
		_audio._resolve_bounded_audio_bank_clip(
			bank,
			&"ui+select+primary"
		),
		"超长 fallback separator 必须在解析前失败关闭。"
	)

	var overflow_first: GFAudioClip = GFAudioClip.new()
	overflow_first.stream = AudioStreamGenerator.new()
	overflow_first.weight = 1.0e308
	var overflow_second: GFAudioClip = GFAudioClip.new()
	overflow_second.stream = AudioStreamGenerator.new()
	overflow_second.weight = 1.0e308
	var overflow_candidates: Array[GFAudioClip] = [
		overflow_first,
		overflow_second,
	]
	bank.set_clips(&"overflow", overflow_candidates)
	assert_null(
		_audio._resolve_bounded_audio_bank_clip(bank, &"overflow"),
		"候选权重求和溢出时必须在随机抽样前失败关闭。"
	)

	var zero_weight: GFAudioClip = GFAudioClip.new()
	zero_weight.stream = AudioStreamGenerator.new()
	zero_weight.weight = 0.0
	var positive_weight: GFAudioClip = GFAudioClip.new()
	positive_weight.stream = AudioStreamGenerator.new()
	positive_weight.weight = 1.0
	var zero_weight_candidates: Array[GFAudioClip] = [
		zero_weight,
		positive_weight,
	]
	bank.set_clips(&"zero_weight", zero_weight_candidates)
	for _sample_index: int in range(128):
		assert_same(
			_audio._select_bounded_audio_bank_clip(bank, &"zero_weight"),
			positive_weight,
			"存在正权重候选时不得命中零权重候选。"
		)


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


func test_audio_bank_retained_mounts_are_globally_bounded_and_atomic() -> void:
	var base_bank: GFAudioBank = GFAudioBank.new()
	var mounted_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene", base_bank)

	var first_token: int = 0
	for index: int in range(1024):
		var token: int = _audio.mount_audio_bank(&"scene", mounted_bank)
		assert_gt(token, 0, "容量内的临时 Bank 挂载必须成功。")
		if index == 0:
			first_token = token

	var token_before_rejection: int = _audio._audio_bank_mount_token
	var retained_before_rejection: int = _audio._audio_bank_retained_mount_count
	var stack_size_before_rejection: int = _audio._get_audio_bank_mount_stack(&"scene").size()
	assert_eq(
		_audio.mount_audio_bank(&"scene", GFAudioBank.new()),
		0,
		"第 1025 个保留挂载必须失败关闭。"
	)
	assert_push_error("[GFAudioUtility] mount_audio_bank 失败：挂载保留容量已达上限。")
	assert_eq(
		_audio._audio_bank_mount_token,
		token_before_rejection,
		"容量拒绝不得消费挂载令牌。"
	)
	assert_eq(
		_audio._audio_bank_retained_mount_count,
		retained_before_rejection,
		"容量拒绝不得改变保留挂载计数。"
	)
	assert_eq(
		_audio._get_audio_bank_mount_stack(&"scene").size(),
		stack_size_before_rejection,
		"容量拒绝不得改写既有挂载栈。"
	)
	assert_same(
		_audio.get_audio_bank(&"scene"),
		mounted_bank,
		"容量拒绝不得替换当前 Bank。"
	)
	var retained_base_bank: GFAudioBank = _audio._get_audio_bank_value(
		GFVariantData.get_option_value(_audio._audio_bank_base_values, &"scene")
	)
	assert_same(
		retained_base_bank,
		base_bank,
		"容量拒绝不得改写基础 Bank。"
	)

	assert_true(_audio.unmount_audio_bank(&"scene", first_token))
	assert_eq(_audio._audio_bank_retained_mount_count, 1023)
	assert_gt(
		_audio.mount_audio_bank(&"scene", mounted_bank),
		0,
		"成功卸载后应立即释放一个挂载容量。"
	)
	assert_eq(_audio._audio_bank_retained_mount_count, 1024)

	var replacement_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene", replacement_bank)
	assert_eq(
		_audio._audio_bank_retained_mount_count,
		0,
		"显式注册替换必须释放同 ID 的全部保留挂载。"
	)
	assert_false(_audio._audio_bank_mount_stacks.has(&"scene"))
	assert_false(_audio._audio_bank_base_values.has(&"scene"))
	assert_same(_audio.get_audio_bank(&"scene"), replacement_bank)

	assert_gt(_audio.mount_audio_bank(&"scene", mounted_bank), 0)
	_audio.clear_audio_banks()
	assert_eq(_audio._audio_bank_retained_mount_count, 0)
	assert_true(_audio._audio_bank_mount_stacks.is_empty())
	assert_true(_audio._audio_bank_base_values.is_empty())
	assert_true(_audio._audio_banks.is_empty())


func test_audio_bank_active_id_capacity_rejects_new_state_atomically() -> void:
	var bank: GFAudioBank = GFAudioBank.new()
	for index: int in range(1024):
		_audio._audio_banks[StringName("bank_%d" % index)] = bank
	assert_eq(_audio._audio_banks.size(), 1024)

	_audio.register_audio_bank(&"overflow", GFAudioBank.new())
	assert_push_error("[GFAudioUtility] register_audio_bank 失败：注册表容量已达上限。")
	assert_false(_audio._audio_banks.has(&"overflow"))
	assert_true(_audio._audio_bank_mount_stacks.is_empty())
	assert_true(_audio._audio_bank_base_values.is_empty())
	assert_eq(_audio._audio_bank_retained_mount_count, 0)

	var token_before_rejection: int = _audio._audio_bank_mount_token
	assert_eq(
		_audio.mount_audio_bank(&"overflow", GFAudioBank.new()),
		0,
		"第 1025 个活动 Bank ID 不得通过临时挂载进入注册表。"
	)
	assert_push_error("[GFAudioUtility] mount_audio_bank 失败：注册表容量已达上限。")
	assert_false(_audio._audio_banks.has(&"overflow"))
	assert_true(_audio._audio_bank_mount_stacks.is_empty())
	assert_true(_audio._audio_bank_base_values.is_empty())
	assert_eq(_audio._audio_bank_mount_token, token_before_rejection)
	assert_eq(_audio._audio_bank_retained_mount_count, 0)
	_audio.clear_audio_banks()


func test_audio_bank_mount_state_converges_on_unregister_init_and_dispose() -> void:
	var base_bank: GFAudioBank = GFAudioBank.new()
	var mounted_bank: GFAudioBank = GFAudioBank.new()
	_audio.register_audio_bank(&"scene", base_bank)
	assert_gt(_audio.mount_audio_bank(&"scene", mounted_bank), 0)
	_audio.unregister_audio_bank(&"scene")
	assert_eq(_audio._audio_bank_retained_mount_count, 0)
	assert_false(_audio._audio_bank_mount_stacks.has(&"scene"))
	assert_false(_audio._audio_bank_base_values.has(&"scene"))
	assert_false(_audio._audio_banks.has(&"scene"))

	var lifecycle_audio: GFAudioUtility = GFAudioUtility.new()
	assert_gt(lifecycle_audio.mount_audio_bank(&"scene", mounted_bank), 0)
	assert_eq(lifecycle_audio._audio_bank_retained_mount_count, 1)
	lifecycle_audio.init()
	assert_eq(
		lifecycle_audio._audio_bank_retained_mount_count,
		0,
		"init 必须清空初始化前残留的保留挂载。"
	)
	assert_true(lifecycle_audio._audio_bank_mount_stacks.is_empty())
	assert_true(lifecycle_audio._audio_bank_base_values.is_empty())
	assert_true(lifecycle_audio._audio_banks.is_empty())

	assert_gt(lifecycle_audio.mount_audio_bank(&"scene", mounted_bank), 0)
	lifecycle_audio.dispose()
	assert_eq(
		lifecycle_audio._audio_bank_retained_mount_count,
		0,
		"dispose 必须收敛非空挂载状态。"
	)
	assert_true(lifecycle_audio._audio_bank_mount_stacks.is_empty())
	assert_true(lifecycle_audio._audio_bank_base_values.is_empty())
	assert_true(lifecycle_audio._audio_banks.is_empty())
	await get_tree().process_frame


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
	var backend_settings: Resource = _resource_option(
		backend.last_spatial_sfx_options,
		"spatial_settings"
	)
	assert_not_same(backend_settings, settings, "后端空间设置必须与调用方资源隔离。")
	if not backend_settings is GFAudioSpatialSettings:
		fail_test("后端空间设置快照必须保持 GFAudioSpatialSettings 类型。")
		return
	var typed_backend_settings: GFAudioSpatialSettings = backend_settings
	assert_almost_eq(
		typed_backend_settings.max_distance_2d,
		settings.max_distance_2d,
		0.001,
		"隔离副本必须保留空间设置内容。"
	)


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


func test_parameter_state_and_switch_requests_are_isolated_and_bounded() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var metadata_resource: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	metadata_resource.max_distance_2d = 720.0
	var parameter: GFAudioParameter = GFAudioParameter.new()
	parameter.parameter_id = &"bounded_parameter"
	parameter.metadata = {
		"resource": metadata_resource,
	}
	assert_true(_audio.set_audio_parameter(parameter))
	assert_not_same(backend.last_parameter, parameter, "参数请求必须隔离 Resource 实例。")
	if backend.last_parameter == null:
		return
	var backend_resource_value: Variant = GFVariantData.get_option_value(
		backend.last_parameter.metadata,
		"resource"
	)
	if not backend_resource_value is GFAudioSpatialSettings:
		fail_test("参数 metadata Resource 快照必须保持具体类型。")
		return
	var backend_resource: GFAudioSpatialSettings = backend_resource_value
	assert_not_same(backend_resource, metadata_resource)
	assert_almost_eq(backend_resource.max_distance_2d, 720.0, 0.001)

	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	var unsafe_parameter: GFAudioParameter = GFAudioParameter.new()
	unsafe_parameter.parameter_id = &"cyclic_parameter"
	unsafe_parameter.metadata = cyclic_metadata
	assert_false(_audio.set_audio_parameter(unsafe_parameter))
	unsafe_parameter.metadata = {}
	cyclic_metadata.clear()

	var deep_metadata: Dictionary = {}
	var deep_cursor: Dictionary = deep_metadata
	for index: int in range(32):
		var child: Dictionary = {
			"index": index,
		}
		deep_cursor["child"] = child
		deep_cursor = child
	var unsafe_state: GFAudioState = GFAudioState.new()
	unsafe_state.group_id = &"deep_state"
	unsafe_state.metadata = deep_metadata
	assert_false(_audio.set_audio_state(unsafe_state))

	var oversized_items: Array = []
	for index: int in range(1100):
		oversized_items.append(index)
	var unsafe_switch: GFAudioSwitch = GFAudioSwitch.new()
	unsafe_switch.group_id = &"oversized_switch"
	unsafe_switch.metadata = {
		"items": oversized_items,
	}
	assert_false(_audio.set_audio_switch(unsafe_switch))

	assert_eq(backend.parameter_request_count, 1)
	assert_eq(backend.state_request_count, 0)
	assert_eq(backend.switch_request_count, 0)


func test_audio_event_rejects_reserved_region_keys_before_backend_dispatch() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"reserved_region"
	event.channel = &"sfx"

	var options_handle: GFAudioEmitterHandle = _audio.post_audio_event(
		event,
		{"playback_region": GFAudioPlaybackRegion.new()}
	)
	assert_push_warning(
		"[GFAudioUtility] post_audio_event 不接受 metadata/options 中的 "
		+ "loop 或 playback_region；请使用 GFAudioClip.playback_region。"
	)
	event.metadata["loop"] = true
	var metadata_handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	assert_push_warning(
		"[GFAudioUtility] post_audio_event 不接受 metadata/options 中的 "
		+ "loop 或 playback_region；请使用 GFAudioClip.playback_region。"
	)

	assert_null(options_handle)
	assert_null(metadata_handle)
	assert_true(backend.posted_events.is_empty(), "保留键不得绕过类型化区间评估进入事件后端。")
	assert_eq(backend.playback_region_evaluation_count, 0, "被拒绝请求不得触发后端区间协商。")


func test_backend_applies_typed_playback_region_after_per_request_evaluation() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.APPLIED
	backend.playback_region_returns_untrusted_fields = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.25
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "backend-region"
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region

	_audio.play_bgm_clip(clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var current_region: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"current_bgm_region"
	)
	var capabilities: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"backend_capabilities"
	)

	assert_eq(backend.playback_region_evaluation_count, 1, "非 no-op 区间必须逐请求评估。")
	assert_eq(backend.played_bgm_clip_count, 1, "只有 APPLIED 结果可进入后端播放。")
	assert_not_same(backend.last_bgm_clip, clip, "后端必须接收会话私有片段快照。")
	assert_not_same(backend.last_evaluated_region, region, "后端必须评估会话私有区间快照。")
	assert_almost_eq(backend.last_evaluated_region.start_seconds, 0.25, 0.001)
	assert_almost_eq(
		backend.last_evaluated_region.loop_start_seconds,
		0.25,
		0.001,
		"后端评估只能接收验证结果重建的规范区间。"
	)
	assert_almost_eq(
		backend.last_bgm_clip.playback_region.loop_start_seconds,
		0.25,
		0.001,
		"后端执行只能接收规范化后的 clip 快照。"
	)
	var backend_option_value: Variant = GFVariantData.get_option_value(
		backend.last_bgm_options,
		"playback_region"
	)
	var backend_option_region: GFAudioPlaybackRegion = null
	if backend_option_value is GFAudioPlaybackRegion:
		backend_option_region = backend_option_value
	assert_not_null(backend_option_region)
	assert_almost_eq(
		backend_option_region.loop_start_seconds,
		0.25,
		0.001,
		"后端执行上下文必须与规范化 clip 使用同一区间语义。"
	)
	assert_almost_eq(region.loop_start_seconds, -1.0, 0.001, "调用方资源不得被规范化过程修改。")
	assert_almost_eq(GFVariantData.get_option_float(current_region, "start_seconds"), 0.25, 0.001)
	assert_eq(
		GFVariantData.get_option_int(current_region, "loop_mode"),
		GFAudioPlaybackRegion.LoopMode.FORWARD,
		"后端 APPLIED 结果的有效区间字段不能覆盖已验证的请求快照。"
	)
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"backend")
	assert_true(
		GFVariantData.get_option_bool(capabilities, "playback_region_contract"),
		"调试快照应公开后端实现了区间协商协议。"
	)


func test_backend_clip_callbacks_cannot_mutate_authoritative_region_or_local_fallback() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.APPLIED
	backend.mutate_can_handle_clip_request = true
	backend.mutate_play_bgm_clip_request = true
	backend.accept_bgm_clip_playback = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var clip: GFAudioClip = _make_test_bgm_clip("mutating-backend-clip", region)
	var source_stream: AudioStreamWAV = clip.stream

	_audio.play_bgm_clip(clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var current_region: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"current_bgm_region"
	)
	var local_stream: AudioStreamWAV = _audio._bgm_player.stream

	assert_eq(backend.playback_region_evaluation_count, 1, "probe 改写副本不得绕过逐请求协商。")
	assert_eq(backend.played_bgm_clip_count, 1, "APPLIED 后应尝试一次独立的执行副本。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")
	assert_not_same(local_stream, source_stream, "后端执行拒绝后，本地回退仍应使用权威请求的私有流。")
	assert_eq(local_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_almost_eq(
		GFVariantData.get_option_float(current_region, "loop_start_seconds"),
		0.1,
		0.001
	)
	assert_same(clip.stream, source_stream, "后端不得通过探测或执行参数反向修改调用方 clip。")
	assert_not_null(clip.playback_region)


func test_backend_clip_callbacks_cannot_mutate_nested_stream_or_spatial_settings() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.APPLIED
	backend.mutate_can_handle_clip_nested_resources = true
	backend.mutate_evaluate_clip_nested_resources = true
	backend.accept_bgm_clip_playback = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var clip: GFAudioClip = _make_test_bgm_clip("nested-mutation-isolation", region)
	var source_stream: AudioStreamWAV = clip.stream
	var source_spatial_settings: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	source_spatial_settings.max_distance_2d = 640.0
	clip.spatial_settings = source_spatial_settings
	var source_metadata_resource: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	source_metadata_resource.max_distance_2d = 960.0
	clip.metadata["nested"] = {
		"resources": [source_metadata_resource],
	}

	_audio.play_bgm_clip(clip)
	var local_stream: AudioStreamWAV = _audio._bgm_player.stream
	var backend_stream: AudioStreamWAV = backend.last_bgm_clip.stream
	var backend_spatial_settings_value: Resource = backend.last_bgm_clip.spatial_settings
	if not backend_spatial_settings_value is GFAudioSpatialSettings:
		fail_test("后端 BGM 空间设置快照必须保持 GFAudioSpatialSettings 类型。")
		return
	var backend_spatial_settings: GFAudioSpatialSettings = backend_spatial_settings_value
	var backend_metadata_resource: GFAudioSpatialSettings = (
		backend._get_nested_settings_resource(backend.last_bgm_clip.metadata)
	)

	assert_eq(source_stream.mix_rate, 1_000, "probe 不得修改调用方持有的 AudioStream。")
	assert_eq(source_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_almost_eq(source_spatial_settings.max_distance_2d, 640.0, 0.001)
	assert_almost_eq(
		source_metadata_resource.max_distance_2d,
		960.0,
		0.001,
		"probe 与评估回调不得修改 clip metadata 内嵌 Resource。"
	)
	assert_eq(backend_stream.mix_rate, 1_000, "执行回调必须收到独立于 probe 的流快照。")
	assert_eq(backend_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_almost_eq(
		backend_spatial_settings.max_distance_2d,
		640.0,
		0.001,
		"执行回调必须收到独立于 probe 的空间设置快照。"
	)
	assert_almost_eq(
		backend_metadata_resource.max_distance_2d,
		960.0,
		0.001,
		"执行回调必须收到独立于 probe 的 metadata Resource 快照。"
	)
	assert_eq(local_stream.mix_rate, 1_000, "本地回退不得继承 backend probe 的嵌套资源修改。")
	assert_eq(local_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)

	backend.mutate_can_handle_clip_nested_resources = false
	backend.mutate_evaluate_clip_nested_resources = false
	backend.mutate_play_bgm_clip_nested_resources = true
	_audio.play_bgm_clip(clip)
	var second_local_stream: AudioStreamWAV = _audio._bgm_player.stream
	var mutated_backend_stream: AudioStreamWAV = backend.last_bgm_clip.stream
	var mutated_backend_spatial_settings_value: Resource = backend.last_bgm_clip.spatial_settings
	if not mutated_backend_spatial_settings_value is GFAudioSpatialSettings:
		fail_test("后端执行快照必须保持 GFAudioSpatialSettings 类型。")
		return
	var mutated_backend_spatial_settings: GFAudioSpatialSettings = (
		mutated_backend_spatial_settings_value
	)
	var mutated_backend_metadata_resource: GFAudioSpatialSettings = (
		backend._get_nested_settings_resource(backend.last_bgm_clip.metadata)
	)

	assert_eq(source_stream.mix_rate, 1_000, "执行回调不得修改调用方持有的 AudioStream。")
	assert_eq(source_stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	assert_almost_eq(source_spatial_settings.max_distance_2d, 640.0, 0.001)
	assert_almost_eq(
		source_metadata_resource.max_distance_2d,
		960.0,
		0.001,
		"执行回调不得修改 clip metadata 内嵌 Resource。"
	)
	assert_eq(mutated_backend_stream.mix_rate, 1, "执行回调应只能修改自己的流快照。")
	assert_eq(mutated_backend_stream.loop_mode, AudioStreamWAV.LOOP_BACKWARD)
	assert_almost_eq(
		mutated_backend_spatial_settings.max_distance_2d,
		1.0,
		0.001,
		"执行回调应只能修改自己的空间设置快照。"
	)
	assert_almost_eq(
		mutated_backend_metadata_resource.max_distance_2d,
		1.0,
		0.001,
		"执行回调应只能修改自己的 metadata Resource 快照。"
	)
	assert_eq(second_local_stream.mix_rate, 1_000, "本地回退不得继承 backend 执行回调的修改。")
	assert_eq(second_local_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)


func test_backend_event_callbacks_cannot_mutate_authoritative_region_or_local_fallback() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.APPLIED
	backend.mutate_can_handle_event_request = true
	backend.mutate_post_event_request = true
	backend.handle_posted_events = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	var clip: GFAudioClip = _make_test_bgm_clip("mutating-backend-event", region)
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"mutating_event"
	event.channel = &"sfx"
	event.clip = clip

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	var player_node: Node = handle.get_player() if handle != null else null
	var player: AudioStreamPlayer = null
	if player_node is AudioStreamPlayer:
		player = player_node

	assert_eq(backend.playback_region_evaluation_count, 1, "event probe 改写副本不得绕过区间协商。")
	assert_eq(backend.posted_events, PackedStringArray(["mutating_event"]))
	assert_not_null(handle, "后端返回未处理时应使用未被污染的权威 event 本地回退。")
	assert_not_null(player)
	var local_stream: AudioStreamWAV = player.stream
	assert_eq(local_stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(event.channel, &"sfx")
	assert_same(event.clip, clip)
	assert_not_null(event.clip.playback_region)


func test_backend_event_callbacks_receive_isolated_nested_resource_options() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.mutate_can_handle_event_nested_resources = true
	backend.mutate_post_event_nested_resources = true
	backend.handle_posted_events = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var event_resource: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	event_resource.max_distance_2d = 640.0
	var option_resource: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	option_resource.max_distance_2d = 720.0
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"nested_resource_options"
	event.channel = &"sfx"
	event.clip = clip
	event.metadata["nested"] = {
		"resources": [event_resource],
	}

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event, {
		"nested": {
			"resources": [option_resource],
		},
	})

	assert_not_null(handle, "后端未接管时应继续使用未污染的权威事件做本地回退。")
	assert_almost_eq(event_resource.max_distance_2d, 640.0, 0.001)
	assert_almost_eq(option_resource.max_distance_2d, 720.0, 0.001)
	assert_almost_eq(
		backend.can_handle_event_resource_before,
		640.0,
		0.001,
		"probe event 应看到隔离前的权威 metadata 值。"
	)
	assert_almost_eq(
		backend.can_handle_event_option_resource_before,
		720.0,
		0.001,
		"probe options 应看到隔离前的调用方值。"
	)
	assert_almost_eq(
		backend.post_event_resource_before,
		640.0,
		0.001,
		"执行 event 快照不得继承 probe 对 Resource 的改写。"
	)
	assert_almost_eq(
		backend.post_event_option_resource_before,
		720.0,
		0.001,
		"执行 options 快照不得继承 probe 对 Resource 的改写。"
	)


func test_backend_event_metadata_and_option_graphs_fail_closed_before_callback() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"unsafe_option_graph"
	event.channel = &"sfx"
	event.clip = clip
	var cyclic_options: Dictionary = {}
	cyclic_options["self"] = cyclic_options

	var cyclic_handle: GFAudioEmitterHandle = _audio.post_audio_event(
		event,
		{"nested": cyclic_options}
	)
	var deep_options: Dictionary = {}
	var deep_cursor: Dictionary = deep_options
	for index: int in range(32):
		var child: Dictionary = {
			"index": index,
		}
		deep_cursor["child"] = child
		deep_cursor = child
	var deep_handle: GFAudioEmitterHandle = _audio.post_audio_event(
		event,
		{"nested": deep_options}
	)
	var oversized_items: Array = []
	for index: int in range(1100):
		oversized_items.append(index)
	var oversized_handle: GFAudioEmitterHandle = _audio.post_audio_event(
		event,
		{"nested": oversized_items}
	)

	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	event.metadata = {
		"nested": cyclic_metadata,
	}
	var cyclic_metadata_handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	event.metadata = {}
	cyclic_metadata.clear()

	var deep_metadata: Dictionary = {}
	var deep_metadata_cursor: Dictionary = deep_metadata
	for index: int in range(32):
		var metadata_child: Dictionary = {
			"index": index,
		}
		deep_metadata_cursor["child"] = metadata_child
		deep_metadata_cursor = metadata_child
	event.metadata = {
		"nested": deep_metadata,
	}
	var deep_metadata_handle: GFAudioEmitterHandle = _audio.post_audio_event(event)

	event.metadata = {
		"nested": oversized_items,
	}
	var oversized_metadata_handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	event.metadata = {}

	assert_null(cyclic_handle)
	assert_null(deep_handle)
	assert_null(oversized_handle)
	assert_null(cyclic_metadata_handle)
	assert_null(deep_metadata_handle)
	assert_null(oversized_metadata_handle)
	assert_eq(
		backend.can_handle_event_count,
		0,
		"不安全 metadata/options 图必须在首次后端回调前失败关闭。"
	)
	assert_true(backend.posted_events.is_empty())
	assert_eq(_audio._active_sfx_players.size(), 0, "失败关闭不得偷偷进入本地播放回退。")


func test_backend_resource_graph_snapshot_preserves_isolated_repeated_references() -> void:
	var shared_resource: SnapshotGraphResource = SnapshotGraphResource.new()
	shared_resource.payload = "source"
	var shared_array: Array[SnapshotGraphResource] = [shared_resource]
	var root_resource: SnapshotGraphResource = SnapshotGraphResource.new()
	root_resource.payload = {
		"left": shared_array,
		"right": shared_array,
	}
	root_resource.secondary_payload = shared_resource

	var result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": root_resource,
	})
	assert_true(_audio._backend_request_snapshot_succeeded(result))
	var options_snapshot: Dictionary = _audio._get_backend_request_snapshot_dictionary(result)
	var root_value: Variant = GFVariantData.get_option_value(options_snapshot, "resource")
	if not root_value is SnapshotGraphResource:
		fail_test("资源图快照必须保持具体 Resource 类型。")
		return
	var root_snapshot: SnapshotGraphResource = root_value
	var payload_value: Variant = root_snapshot.payload
	if not payload_value is Dictionary:
		fail_test("资源图快照必须保持 Dictionary 属性。")
		return
	var payload_snapshot: Dictionary = payload_value
	var left_value: Variant = GFVariantData.get_option_value(payload_snapshot, "left")
	var right_value: Variant = GFVariantData.get_option_value(payload_snapshot, "right")
	if not left_value is Array or not right_value is Array:
		fail_test("资源图快照必须保持 Array 属性。")
		return
	var left_snapshot: Array = left_value
	var right_snapshot: Array = right_value
	var nested_snapshot_value: Variant = left_snapshot[0] if not left_snapshot.is_empty() else null
	if not nested_snapshot_value is SnapshotGraphResource:
		fail_test("资源图快照必须保持嵌套 Resource 类型。")
		return
	var nested_snapshot: SnapshotGraphResource = nested_snapshot_value
	var secondary_snapshot_value: Variant = root_snapshot.secondary_payload
	if not secondary_snapshot_value is SnapshotGraphResource:
		fail_test("重复 Resource 引用必须保持具体类型。")
		return
	var secondary_snapshot: SnapshotGraphResource = secondary_snapshot_value

	assert_not_same(root_snapshot, root_resource)
	assert_same(left_snapshot, right_snapshot, "重复集合引用必须映射到同一份受控快照。")
	assert_true(left_snapshot.is_same_typed(shared_array), "类型化集合的元素契约必须保持。")
	assert_same(
		nested_snapshot,
		secondary_snapshot,
		"重复 Resource 引用必须映射到同一份受控快照。"
	)
	assert_not_same(nested_snapshot, shared_resource)
	nested_snapshot.payload = "backend"
	assert_eq(
		GFVariantData.to_text(shared_resource.payload),
		"source",
		"后端快照不得反向修改调用方 Resource。"
	)


func test_backend_resource_graph_cycles_depth_and_items_fail_closed() -> void:
	var cyclic_resource: SnapshotGraphResource = SnapshotGraphResource.new()
	cyclic_resource.payload = cyclic_resource
	var cyclic_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": cyclic_resource,
	})
	cyclic_resource.payload = null

	var deep_root: SnapshotGraphResource = SnapshotGraphResource.new()
	var deep_cursor: SnapshotGraphResource = deep_root
	for index: int in range(32):
		var child: SnapshotGraphResource = SnapshotGraphResource.new()
		child.secondary_payload = index
		deep_cursor.payload = child
		deep_cursor = child
	var deep_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": deep_root,
	})

	var oversized_resource: SnapshotGraphResource = SnapshotGraphResource.new()
	var oversized_items: Array = []
	for index: int in range(1100):
		oversized_items.append(index)
	oversized_resource.payload = oversized_items
	var oversized_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": oversized_resource,
	})
	var read_only_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": ReadOnlySnapshotResource.new(),
	})

	assert_false(_audio._backend_request_snapshot_succeeded(cyclic_result))
	assert_false(_audio._backend_request_snapshot_succeeded(deep_result))
	assert_false(_audio._backend_request_snapshot_succeeded(oversized_result))
	assert_false(_audio._backend_request_snapshot_succeeded(read_only_result))


func test_backend_packed_array_snapshot_is_isolated_memoized_and_bounded() -> void:
	var packed_values: Array = [
		PackedByteArray([1]),
		PackedInt32Array([2]),
		PackedInt64Array([3]),
		PackedFloat32Array([4.0]),
		PackedFloat64Array([5.0]),
		PackedStringArray(["six"]),
		PackedVector2Array([Vector2.ONE]),
		PackedVector3Array([Vector3.ONE]),
		PackedColorArray([Color.WHITE]),
		PackedVector4Array([Vector4.ONE]),
	]
	for packed_value: Variant in packed_values:
		var packed_result: Dictionary = _audio._try_snapshot_backend_request_value(
			packed_value,
			true
		)
		assert_true(
			_audio._backend_request_snapshot_succeeded(packed_result),
			"所有 Godot Packed Array 类型都必须通过受控分派。"
		)
		var packed_snapshot: Variant = GFVariantData.get_option_value(
			packed_result,
			"value"
		)
		assert_eq(typeof(packed_snapshot), typeof(packed_value))
		assert_true(GFVariantData.values_equal(packed_snapshot, packed_value))

	var shared_bytes: PackedByteArray = PackedByteArray([1, 2, 3, 4])
	var root_resource: SnapshotGraphResource = SnapshotGraphResource.new()
	root_resource.payload = {
		"left": shared_bytes,
		"right": shared_bytes,
	}
	root_resource.secondary_payload = shared_bytes
	var result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": root_resource,
	})
	assert_true(_audio._backend_request_snapshot_succeeded(result))
	var options_snapshot: Dictionary = _audio._get_backend_request_snapshot_dictionary(result)
	var root_value: Variant = GFVariantData.get_option_value(options_snapshot, "resource")
	if not root_value is SnapshotGraphResource:
		fail_test("Packed Array 所在 Resource 必须保持具体类型。")
		return
	var root_snapshot: SnapshotGraphResource = root_value
	var payload_value: Variant = root_snapshot.payload
	if not payload_value is Dictionary:
		fail_test("Packed Array 所在 Dictionary 必须保持类型。")
		return
	var payload_snapshot: Dictionary = payload_value
	var left_value: Variant = GFVariantData.get_option_value(payload_snapshot, "left")
	var right_value: Variant = GFVariantData.get_option_value(payload_snapshot, "right")
	var secondary_value: Variant = root_snapshot.secondary_payload
	if (
		not left_value is PackedByteArray
		or not right_value is PackedByteArray
		or not secondary_value is PackedByteArray
	):
		fail_test("PackedByteArray 快照必须保持类型。")
		return
	var left_snapshot: PackedByteArray = left_value
	var right_snapshot: PackedByteArray = right_value
	var secondary_snapshot: PackedByteArray = secondary_value
	assert_same(left_snapshot, right_snapshot, "重复 Packed Array 引用必须复用受控副本。")
	assert_same(left_snapshot, secondary_snapshot, "Resource 属性也必须复用同一受控副本。")
	left_snapshot[0] = 9
	assert_eq(shared_bytes[0], 1, "后端修改 Packed Array 快照不得污染调用方。")

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.data = PackedByteArray([5, 6, 7, 8])
	var wav_result: Dictionary = _audio._try_snapshot_backend_request_value(wav, true)
	assert_true(_audio._backend_request_snapshot_succeeded(wav_result))
	var wav_value: Variant = GFVariantData.get_option_value(wav_result, "value")
	if not wav_value is AudioStreamWAV:
		fail_test("AudioStreamWAV 快照必须保持具体类型。")
		return
	var wav_snapshot: AudioStreamWAV = wav_value
	var changed_data: PackedByteArray = wav_snapshot.data
	changed_data[0] = 42
	wav_snapshot.data = changed_data
	assert_eq(wav.data[0], 5, "原生 setter 复制 Packed Array 时仍必须保持隔离。")

	var element_state: Dictionary = _audio._new_backend_request_snapshot_state()
	element_state["remaining_packed_elements"] = 2
	var element_result: Dictionary = _audio._snapshot_backend_request_value(
		PackedByteArray([1, 2, 3]),
		true,
		element_state,
		0
	)
	var byte_state: Dictionary = _audio._new_backend_request_snapshot_state()
	byte_state["remaining_bytes"] = 4
	var byte_result: Dictionary = _audio._snapshot_backend_request_value(
		PackedVector2Array([Vector2.ONE]),
		true,
		byte_state,
		0
	)
	assert_false(_audio._backend_request_snapshot_succeeded(element_result))
	assert_false(_audio._backend_request_snapshot_succeeded(byte_result))
	assert_eq(
		_audio._get_backend_snapshot_packed_element_bytes(TYPE_PACKED_VECTOR2_ARRAY),
		16,
		"Vector2 必须按双精度构建上限保守计入硬字节预算。"
	)
	assert_eq(
		_audio._get_backend_snapshot_packed_element_bytes(TYPE_PACKED_VECTOR3_ARRAY),
		24,
		"Vector3 必须按双精度构建上限保守计入硬字节预算。"
	)
	assert_eq(
		_audio._get_backend_snapshot_packed_element_bytes(TYPE_PACKED_VECTOR4_ARRAY),
		32,
		"Vector4 必须按双精度构建上限保守计入硬字节预算。"
	)

	var string_name_state: Dictionary = _audio._new_backend_request_snapshot_state()
	string_name_state["remaining_bytes"] = 3
	var string_name_result: Dictionary = _audio._snapshot_backend_request_value(
		&"x",
		true,
		string_name_state,
		0
	)
	assert_false(
		_audio._backend_request_snapshot_succeeded(string_name_result),
		"StringName 也必须受保守 UTF-32 值字节预算约束。"
	)

	var clip_state: Dictionary = _audio._new_backend_request_snapshot_state()
	clip_state["remaining_bytes"] = 7
	var bounded_clip: GFAudioClip = GFAudioClip.new()
	bounded_clip.path = "a"
	bounded_clip.bus_name = "b"
	assert_null(
		_audio._snapshot_audio_clip_with_state(
			bounded_clip,
			null,
			true,
			clip_state,
			0
		),
		"手工 clip 字段不得绕过值字节预算。"
	)

	var event_state: Dictionary = _audio._new_backend_request_snapshot_state()
	event_state["remaining_bytes"] = 7
	var bounded_event: GFAudioEvent = GFAudioEvent.new()
	bounded_event.event_id = &"ab"
	bounded_event.channel = &""
	bounded_event.ambient_channel = &""
	assert_null(
		_audio._snapshot_audio_event_with_state(
			bounded_event,
			null,
			true,
			event_state,
			0
		),
		"手工 event StringName 字段不得绕过值字节预算。"
	)


func test_backend_resource_setters_cannot_break_snapshot_graph_contract() -> void:
	var copying_resource: CopyingSnapshotResource = CopyingSnapshotResource.new()
	copying_resource.payload = [1, 2, 3]
	var copying_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": copying_resource,
	})
	var copying_packed_resource: CopyingPackedSnapshotResource = (
		CopyingPackedSnapshotResource.new()
	)
	copying_packed_resource.payload = PackedByteArray([1, 2, 3])
	var copying_packed_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": copying_packed_resource,
	})
	var coupled_resource: CoupledSnapshotResource = CoupledSnapshotResource.new()
	coupled_resource.second = 9
	coupled_resource.first = 7
	var coupled_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": coupled_resource,
	})
	var never_duplicate_resource: NeverDuplicateSnapshotResource = (
		NeverDuplicateSnapshotResource.new()
	)
	var never_duplicate_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": never_duplicate_resource,
	})
	var expanding_schema_resource: ExpandingStorageSchemaSnapshotResource = (
		ExpandingStorageSchemaSnapshotResource.new()
	)
	expanding_schema_resource.set_meta(&"hide_extra_storage", true)
	var expanding_schema_result: Dictionary = _audio._try_snapshot_audio_options({
		"resource": expanding_schema_resource,
	})

	assert_false(
		_audio._backend_request_snapshot_succeeded(copying_result),
		"复制引用属性的 setter 会破坏别名契约，必须失败关闭。"
	)
	assert_false(
		_audio._backend_request_snapshot_succeeded(copying_packed_result),
		"脚本 Packed Array setter 复制受控副本时也必须失败关闭。"
	)
	assert_false(
		_audio._backend_request_snapshot_succeeded(coupled_result),
		"后置 setter 改写先前属性时，最终一致性复核必须失败关闭。"
	)
	assert_false(
		_audio._backend_request_snapshot_succeeded(never_duplicate_result),
		"PROPERTY_USAGE_NEVER_DUPLICATE 属性必须失败关闭。"
	)
	assert_false(
		_audio._backend_request_snapshot_succeeded(expanding_schema_result),
		"目标实例新增 storage 属性时必须在 getter 暴露前失败关闭。"
	)


func test_backend_clip_and_event_snapshots_preserve_shared_resource_identity() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region
	clip.metadata["region"] = region
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"shared_snapshot_identity"
	event.clip = clip
	event.metadata["clip"] = clip

	var normalized_region: GFAudioPlaybackRegion = region.duplicate_region()
	var authoritative_snapshot: GFAudioEvent = _audio._snapshot_audio_event(
		event,
		normalized_region,
		false
	)
	assert_not_null(authoritative_snapshot)
	if authoritative_snapshot == null or authoritative_snapshot.clip == null:
		return
	var authoritative_metadata_clip_value: Variant = GFVariantData.get_option_value(
		authoritative_snapshot.metadata,
		"clip"
	)
	var authoritative_metadata_region_value: Variant = (
		GFVariantData.get_option_value(
			authoritative_snapshot.clip.metadata,
			"region"
		)
	)
	if (
		not authoritative_metadata_clip_value is GFAudioClip
		or not authoritative_metadata_region_value is GFAudioPlaybackRegion
	):
		fail_test("权威中间快照必须保持重复 Resource 的具体类型。")
		return
	var authoritative_metadata_clip: GFAudioClip = (
		authoritative_metadata_clip_value
	)
	var authoritative_metadata_region: GFAudioPlaybackRegion = (
		authoritative_metadata_region_value
	)
	assert_same(
		authoritative_metadata_clip,
		authoritative_snapshot.clip,
		"权威中间快照也必须保持 event metadata 的 clip 别名。"
	)
	assert_same(
		authoritative_metadata_region,
		authoritative_snapshot.clip.playback_region,
		"权威中间快照必须把原区间与规范化区间映射到同一副本。"
	)

	var snapshot: GFAudioEvent = _audio._snapshot_audio_event(
		authoritative_snapshot,
		authoritative_snapshot.clip.playback_region,
		true
	)

	assert_not_null(snapshot)
	if snapshot == null or snapshot.clip == null:
		return
	var metadata_clip_value: Variant = GFVariantData.get_option_value(
		snapshot.metadata,
		"clip"
	)
	var metadata_region_value: Variant = GFVariantData.get_option_value(
		snapshot.clip.metadata,
		"region"
	)
	if (
		not metadata_clip_value is GFAudioClip
		or not metadata_region_value is GFAudioPlaybackRegion
	):
		fail_test("重复 Resource 引用必须保持具体类型。")
		return
	var metadata_clip: GFAudioClip = metadata_clip_value
	var metadata_region: GFAudioPlaybackRegion = metadata_region_value
	assert_same(
		metadata_clip,
		snapshot.clip,
		"event metadata 中的重复 clip 引用必须复用手工快照。"
	)
	assert_same(
		metadata_region,
		snapshot.clip.playback_region,
		"clip metadata 中的重复区间引用必须复用受控 Resource 快照。"
	)


func test_backend_snapshot_cycles_and_depth_fail_closed_without_replacing_bgm() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var active_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var active_clip: GFAudioClip = GFAudioClip.new()
	active_clip.path = "active-before-snapshot-rejection"
	active_clip.stream = active_stream
	backend.handle_bgm_clips = false
	_audio.play_bgm_clip(active_clip)
	backend.handle_bgm_clips = true

	var cyclic_clip: GFAudioClip = GFAudioClip.new()
	cyclic_clip.path = "cyclic-snapshot"
	cyclic_clip.stream = AudioStreamGenerator.new()
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	cyclic_clip.metadata = cyclic_metadata
	_audio.play_bgm_clip(cyclic_clip)

	var deep_clip: GFAudioClip = GFAudioClip.new()
	deep_clip.path = "deep-snapshot"
	deep_clip.stream = AudioStreamGenerator.new()
	var deep_root: Dictionary = {}
	var deep_cursor: Dictionary = deep_root
	for index: int in range(32):
		var child: Dictionary = {
			"index": index,
		}
		deep_cursor["child"] = child
		deep_cursor = child
	deep_clip.metadata = deep_root
	_audio.play_bgm_clip(deep_clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(backend.played_bgm_clip_count, 0, "循环或过深快照不得进入任何后端回调。")
	assert_same(_audio._bgm_player.stream, active_stream, "快照拒绝不得替换当前本地 BGM。")
	assert_true(_audio._bgm_player.playing)
	assert_eq(_audio.get_current_bgm_key(), "active-before-snapshot-rejection")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"playing")


func test_backend_without_region_contract_falls_back_to_private_local_stream() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = _make_test_bgm_clip("local-region-fallback", region)
	var source_stream: AudioStream = clip.stream

	_audio.play_bgm_clip(clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var current_region: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"current_bgm_region"
	)

	assert_eq(backend.playback_region_evaluation_count, 0, "缺少协议能力时不得调用逐请求评估。")
	assert_eq(backend.played_bgm_clip_count, 0, "未声明区间协议的后端不得接管非 no-op 请求。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")
	assert_not_same(_audio._bgm_player.stream, source_stream, "本地回退必须播放私有流副本。")
	assert_almost_eq(GFVariantData.get_option_float(current_region, "start_seconds"), 0.1, 0.001)


func test_backend_region_evaluation_requires_explicit_applied_status() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.NONE
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = _make_test_bgm_clip("backend-none-fallback", region)

	_audio.play_bgm_clip(clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(backend.playback_region_evaluation_count, 1)
	assert_eq(backend.played_bgm_clip_count, 0, "NONE 不能被误认为后端已接受区间。")
	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "bgm_owner"),
		&"local",
		"未显式 APPLIED 时应继续尝试精确的本地实现。"
	)

	_audio.stop_bgm()
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.VALID
	_audio.play_bgm_clip(clip)
	snapshot = _audio.get_debug_snapshot()
	assert_eq(backend.playback_region_evaluation_count, 2)
	assert_eq(backend.played_bgm_clip_count, 0, "VALID 只表示结构有效，不能被后端当作已应用。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")


func test_backend_invalid_region_evaluation_rejects_before_any_playback() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.INVALID
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	watch_signals(_audio)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.25
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region

	_audio.play_bgm_clip(clip)
	var rejection: Dictionary = _audio.get_last_playback_region_rejection()

	assert_eq(backend.playback_region_evaluation_count, 1)
	assert_eq(backend.played_bgm_clip_count, 0, "INVALID 评估不得进入后端播放。")
	assert_null(_audio._bgm_player.stream, "INVALID 评估不得继续本地回退。")
	assert_eq(
		GFVariantData.get_option_string_name(rejection, "status"),
		&"invalid"
	)
	assert_eq(
		GFVariantData.get_option_string_name(rejection, "reason"),
		&"backend_region_rejected"
	)
	assert_signal_emitted_with_parameters(
		_audio,
		"playback_region_rejected",
		[&"bgm", &"backend_region_rejected"]
	)


func test_backend_region_rejection_preserves_active_bgm_and_ambient_sessions() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var active_bgm_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var active_bgm_clip: GFAudioClip = GFAudioClip.new()
	active_bgm_clip.path = "active-bgm"
	active_bgm_clip.stream = active_bgm_stream
	var active_ambient_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var active_ambient_clip: GFAudioClip = GFAudioClip.new()
	active_ambient_clip.stream = active_ambient_stream
	_audio.play_bgm_clip(active_bgm_clip)
	_audio.play_ambient_clip(active_ambient_clip, &"weather")
	var ambient_before: Dictionary = _audio._get_ambient_session(&"weather")
	var ambient_generation_before: int = GFVariantData.get_option_int(
		ambient_before,
		"generation"
	)

	backend.handle_bgm_clips = true
	backend.handle_ambient_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.INVALID
	var rejected_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	rejected_region.start_seconds = 0.25
	var rejected_clip: GFAudioClip = GFAudioClip.new()
	rejected_clip.stream = AudioStreamGenerator.new()
	rejected_clip.playback_region = rejected_region
	_audio.play_bgm_clip(rejected_clip)
	_audio.play_ambient_clip(rejected_clip, &"weather")
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var ambient_sessions: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"ambient_sessions"
	)
	var weather: Dictionary = GFVariantData.get_option_dictionary(
		ambient_sessions,
		"weather"
	)

	assert_same(_audio._bgm_player.stream, active_bgm_stream)
	assert_true(_audio._bgm_player.playing)
	assert_eq(_audio.get_current_bgm_key(), "active-bgm")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"playing")
	assert_same(_audio._get_ambient_player(&"weather").stream, active_ambient_stream)
	assert_eq(
		GFVariantData.get_option_int(weather, "generation"),
		ambient_generation_before,
		"后端逐请求拒绝不得开始环境音 replacement transaction。"
	)
	assert_eq(GFVariantData.get_option_string_name(weather, "owner"), &"local")
	assert_eq(GFVariantData.get_option_string_name(weather, "state"), &"playing")
	assert_eq(backend.playback_region_evaluation_count, 2)
	assert_eq(backend.played_bgm_clip_count, 0)
	assert_eq(backend.played_ambient_clip_count, 0)


func test_custom_event_region_rejection_bounds_diagnostic_channel_but_preserves_signal() -> void:
	watch_signals(_audio)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = NAN
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"custom_invalid_region"
	event.channel = StringName("project-channel\nprivate")
	event.clip = clip

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	var rejection: Dictionary = _audio.get_last_playback_region_rejection()

	assert_null(handle)
	assert_eq(
		GFVariantData.get_option_string_name(rejection, "channel"),
		&"custom",
		"稳定诊断不得复制项目自定义通道值。"
	)
	assert_signal_emitted_with_parameters(
		_audio,
		"playback_region_rejected",
		[event.channel, &"non_finite_start"]
	)


func test_custom_event_local_prepare_rejection_preserves_original_channel() -> void:
	watch_signals(_audio)
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region
	var event: GFAudioEvent = GFAudioEvent.new()
	event.event_id = &"custom_unsupported_region"
	event.channel = &"project_audio_preview"
	event.clip = clip

	var handle: GFAudioEmitterHandle = _audio.post_audio_event(event)
	var rejection: Dictionary = _audio.get_last_playback_region_rejection()

	assert_not_null(handle)
	assert_true(handle.is_terminal(), "同步 prepare 拒绝后返回的控制句柄必须已经终结。")
	assert_eq(
		GFVariantData.get_option_string_name(rejection, "channel"),
		&"custom",
		"持久诊断应收敛项目自定义通道。"
	)
	assert_signal_emitted_with_parameters(
		_audio,
		"playback_region_rejected",
		[event.channel, &"stream_type_unsupported"]
	)


func test_bgm_region_rejection_signal_cannot_clobber_reentrant_replacement() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.handle_bgm_clips = true
	backend.capabilities.supports_playback_region_contract = true
	backend.playback_region_evaluation_status = GFAudioPlaybackRegionResult.Status.INVALID
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var rejected_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	rejected_region.start_seconds = 0.25
	var rejected_clip: GFAudioClip = GFAudioClip.new()
	rejected_clip.stream = AudioStreamGenerator.new()
	rejected_clip.playback_region = rejected_region
	var replacement_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var replacement_clip: GFAudioClip = GFAudioClip.new()
	replacement_clip.path = "replacement"
	replacement_clip.stream = replacement_stream
	var on_rejected: Callable = func(
		_channel: StringName,
		_reason: StringName
	) -> void:
		backend.handle_bgm_clips = false
		_audio.play_bgm_clip(replacement_clip)
	var _connected_1205: Error = _audio.playback_region_rejected.connect(
		on_rejected,
		CONNECT_ONE_SHOT
	) as Error

	_audio.play_bgm_clip(rejected_clip)
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_same(_audio._bgm_player.stream, replacement_stream)
	assert_eq(_audio.get_current_bgm_key(), "replacement")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"local")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"playing")


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


func test_inline_spatial_region_prepare_rejection_returns_null() -> void:
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.playback_region = region
	var source_2d: Node2D = Node2D.new()
	var source_3d: Node3D = Node3D.new()
	add_child_autofree(source_2d)
	add_child_autofree(source_3d)

	var player_2d: AudioStreamPlayer2D = _audio.play_sfx_clip_2d(clip, source_2d)
	var player_3d: AudioStreamPlayer3D = _audio.play_sfx_clip_3d(clip, source_3d)

	assert_null(player_2d, "同步 2D 区间准备失败必须遵守 null-on-failure 契约。")
	assert_null(player_3d, "同步 3D 区间准备失败必须遵守 null-on-failure 契约。")
	assert_eq(
		_audio._active_spatial_sfx_players.size(),
		0,
		"同步拒绝不得留下已排队释放但仍被视为活动的空间播放器。"
	)


func test_immediate_asset_callback_spatial_region_rejection_returns_null() -> void:
	var immediate_asset: ImmediateAssetUtility = ImmediateAssetUtility.new(
		AudioStreamGenerator.new()
	)
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(immediate_asset)
	audio.init()
	await get_tree().process_frame
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "res://audio/immediate-unsupported.ogg"
	clip.playback_region = region
	var source_2d: Node2D = Node2D.new()
	var source_3d: Node3D = Node3D.new()
	add_child_autofree(source_2d)
	add_child_autofree(source_3d)

	var player_2d: AudioStreamPlayer2D = audio.play_sfx_clip_2d(clip, source_2d)
	var handle_3d: GFAudioEmitterHandle = audio.play_sfx_clip_3d_handle(
		clip,
		source_3d
	)

	assert_null(player_2d, "同步 AssetUtility 回调拒绝 2D 区间时必须返回 null。")
	assert_null(handle_3d, "同步 AssetUtility 回调拒绝 3D 区间时不得创建失效句柄。")
	assert_eq(audio._active_spatial_sfx_players.size(), 0)
	assert_eq(audio._retiring_spatial_sfx_players.size(), 0)
	assert_eq(audio._playback_sessions.size(), 0)
	audio.dispose()
	await get_tree().process_frame


func test_delayed_asset_callback_spatial_region_rejection_terminates_handle_once() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame
	var region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	region.start_seconds = 0.1
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "res://audio/delayed-unsupported.ogg"
	clip.playback_region = region
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var handle: GFAudioEmitterHandle = audio.play_sfx_clip_2d_handle(clip, source)
	var stopped_count: Array[int] = [0]
	var _connect_result: Error = handle.stopped.connect(
		func(_handle: GFAudioEmitterHandle) -> void:
			stopped_count[0] += 1
	) as Error
	var player: Node = handle.get_player()

	assert_true(handle.is_valid())
	assert_eq(audio._active_spatial_sfx_players.size(), 1)
	mock_asset.finish(clip.path, AudioStreamGenerator.new())

	assert_false(handle.is_valid(), "异步区间拒绝后句柄必须进入终态。")
	assert_true(handle.is_terminal(), "异步区间拒绝必须提交唯一终态。")
	assert_eq(stopped_count[0], 0, "非主动停止的加载拒绝不得伪造 stopped 信号。")
	assert_eq(audio._active_spatial_sfx_players.size(), 0)
	assert_eq(audio._retiring_spatial_sfx_players.size(), 0)
	assert_eq(audio._playback_sessions.size(), 0)
	assert_true(player.is_queued_for_deletion())
	audio.dispose()
	await get_tree().process_frame


func test_stopped_spatial_handle_rejects_late_asset_callback() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "res://audio/stopped-before-load.ogg"
	var source: Node2D = Node2D.new()
	add_child_autofree(source)
	var handle: GFAudioEmitterHandle = audio.play_sfx_clip_2d_handle(clip, source)
	var player: AudioStreamPlayer2D = handle.get_player() as AudioStreamPlayer2D
	var stopped_count: Array[int] = [0]
	var _connect_result: Error = handle.stopped.connect(
		func(_handle: GFAudioEmitterHandle) -> void:
			stopped_count[0] += 1
	) as Error

	handle.stop()
	mock_asset.finish(clip.path, AudioStreamGenerator.new())

	assert_true(handle.is_terminal())
	assert_eq(stopped_count[0], 1, "主动停止只允许发出一次 stopped。")
	assert_true(player.is_queued_for_deletion())
	assert_null(player.stream, "迟到回调不得把流重新写入已终结播放器。")
	assert_false(player.playing, "迟到回调不得启动已终结播放器。")
	assert_eq(audio._active_spatial_sfx_players.size(), 0)
	assert_eq(audio._retiring_spatial_sfx_players.size(), 0)
	assert_eq(audio._playback_sessions.size(), 0)
	audio.dispose()
	await get_tree().process_frame


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


func test_stopped_ambient_player_cache_is_bounded() -> void:
	_audio.max_idle_ambient_players = 2
	var clip: GFAudioClip = GFAudioClip.new()
	clip.stream = AudioStreamGenerator.new()
	clip.bus_name = "Master"
	_audio.play_ambient_clip(clip, &"active")
	var active_player: AudioStreamPlayer = _audio._get_ambient_player(&"active")

	for index: int in range(5):
		var channel: StringName = StringName("idle_%d" % index)
		_audio.play_ambient_clip(clip, channel)
		_audio.stop_ambient(channel)

	var snapshot: Dictionary = _audio.get_debug_snapshot()
	assert_true(is_instance_valid(active_player), "活跃 channel 不得被空闲缓存淘汰。")
	assert_true(active_player.playing)
	assert_eq(_audio._ambient_players.size(), 3, "一个活跃播放器加两个近期空闲播放器应构成稳定上限。")
	assert_eq(_audio._ambient_idle_channels.size(), 2)
	assert_false(_audio._ambient_players.has(&"idle_0"), "最旧的停止 channel 应被淘汰。")
	assert_false(_audio._ambient_players.has(&"idle_1"))
	assert_false(_audio._ambient_players.has(&"idle_2"))
	assert_true(_audio._ambient_players.has(&"idle_3"), "最近停止的 channel 应保留。")
	assert_true(_audio._ambient_players.has(&"idle_4"))
	assert_eq(GFVariantData.get_option_int(snapshot, "cached_ambient_player_count"), 3)
	assert_eq(GFVariantData.get_option_int(snapshot, "idle_ambient_player_count"), 2)
	assert_eq(GFVariantData.get_option_int(snapshot, "max_idle_ambient_players"), 2)


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


func test_mix_snapshot_rejects_invalid_payload_shapes() -> void:
	var cases: Array[Dictionary] = [
		{
			"snapshot": {"buses": []},
			"reason": "invalid_buses_payload",
		},
		{
			"snapshot": {"effects": 42},
			"reason": "invalid_effects_payload",
		},
		{
			"snapshot": {"effects": {"Master": 42}},
			"reason": "invalid_effect_group",
		},
	]
	for test_case: Dictionary in cases:
		var report: Dictionary = _audio.apply_mix_snapshot(
			GFVariantData.get_option_dictionary(test_case, "snapshot")
		)
		var failed: Array = GFVariantData.get_option_array(report, "failed")
		var applied: PackedStringArray = GFVariantData.get_option_packed_string_array(
			report,
			"applied"
		)

		assert_false(
			GFVariantData.get_option_bool(report, "ok"),
			"结构错误的混音快照不得报告成功。"
		)
		assert_eq(failed.size(), 1, "每个结构错误应生成一个稳定失败条目。")
		if not failed.is_empty() and failed[0] is Dictionary:
			var failed_entry: Dictionary = failed[0]
			assert_eq(
				GFVariantData.get_option_string(failed_entry, "reason"),
				GFVariantData.get_option_string(test_case, "reason")
			)
		assert_true(applied.is_empty(), "结构错误不得产生已应用字段。")

	var empty_report: Dictionary = _audio.apply_mix_snapshot({})
	var explicit_empty_report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {},
		"effects": [],
	})
	assert_true(GFVariantData.get_option_bool(empty_report, "ok"), "空快照仍应是合法 no-op。")
	assert_true(
		GFVariantData.get_option_bool(explicit_empty_report, "ok"),
		"显式空容器仍应是合法 no-op。"
	)


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


func test_mix_snapshot_and_effect_values_are_isolated_and_bounded() -> void:
	var backend: MockAudioBackend = MockAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	var effect_resource: GFAudioSpatialSettings = GFAudioSpatialSettings.new()
	effect_resource.max_distance_2d = 880.0
	assert_true(
		_audio.set_bus_effect_property(
			"External",
			0,
			&"custom_resource",
			effect_resource
		)
	)
	assert_eq(backend.effect_property_requests.size(), 1)
	var effect_request: Dictionary = backend.effect_property_requests[0]
	var backend_effect_value: Variant = GFVariantData.get_option_value(
		effect_request,
		"value"
	)
	if not backend_effect_value is GFAudioSpatialSettings:
		fail_test("效果属性 Resource 值必须保持具体类型。")
		return
	var backend_effect_resource: GFAudioSpatialSettings = backend_effect_value
	assert_not_same(backend_effect_resource, effect_resource)

	var cyclic_effect_value: Dictionary = {}
	cyclic_effect_value["self"] = cyclic_effect_value
	assert_false(
		_audio.set_bus_effect_property(
			"External",
			0,
			&"unsafe_value",
			cyclic_effect_value
		)
	)
	cyclic_effect_value.clear()
	assert_eq(
		backend.effect_property_requests.size(),
		1,
		"不安全 effect value 不得进入 backend。"
	)

	var cyclic_snapshot: Dictionary = {}
	cyclic_snapshot["self"] = cyclic_snapshot
	var cyclic_report: Dictionary = _audio.apply_mix_snapshot(cyclic_snapshot)
	cyclic_snapshot.clear()

	var deep_snapshot: Dictionary = {}
	var deep_cursor: Dictionary = deep_snapshot
	for index: int in range(32):
		var child: Dictionary = {
			"index": index,
		}
		deep_cursor["child"] = child
		deep_cursor = child
	var deep_report: Dictionary = _audio.apply_mix_snapshot({
		"nested": deep_snapshot,
	})

	var oversized_items: Array = []
	for index: int in range(1100):
		oversized_items.append(index)
	var oversized_report: Dictionary = _audio.apply_mix_snapshot({
		"nested": oversized_items,
	})
	var shared_identity_report: Dictionary = _audio.apply_mix_snapshot({
		"callback": Callable(self, "get_name"),
	})

	assert_false(GFVariantData.get_option_bool(cyclic_report, "ok"))
	assert_false(GFVariantData.get_option_bool(deep_report, "ok"))
	assert_false(GFVariantData.get_option_bool(oversized_report, "ok"))
	assert_false(GFVariantData.get_option_bool(shared_identity_report, "ok"))
	assert_eq(
		backend.mix_snapshot_request_count,
		0,
		"不安全 mix snapshot 必须在首次 backend 回调前失败关闭。"
	)


func test_bus_effect_fallback_uses_pristine_value_after_backend_rejection() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var effect_count_before: int = AudioServer.get_bus_effect_count(bus_index)
	var effect: MutableDictionaryAudioEffect = MutableDictionaryAudioEffect.new()
	effect.resource_name = "GFMutableDictionaryEffect"
	AudioServer.add_bus_effect(bus_index, effect)

	var backend: MockAudioBackend = MockAudioBackend.new()
	backend.accept_effect_property_requests = false
	backend.mutate_effect_property_value = true
	assert_true(_audio.set_audio_backend(backend))

	var caller_value: Dictionary = {
		"nested": {
			"label": "pristine",
		},
	}
	assert_true(
		_audio.set_bus_effect_property(
			"Master",
			effect_count_before,
			&"payload",
			caller_value
		),
		"后端拒绝效果属性后应使用隔离的本地回退。"
	)
	assert_eq(backend.effect_property_requests.size(), 1)
	var backend_value: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(backend.effect_property_requests[0], "value")
	)
	assert_true(
		GFVariantData.get_option_bool(backend_value, "backend_mutated"),
		"测试后端应已改写自己的请求副本。"
	)
	assert_false(effect.payload.has("backend_mutated"))
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(effect.payload, "nested"),
			"label"
		),
		"pristine",
		"本地效果必须收到后端不可见的权威值副本。"
	)
	assert_not_same(effect.payload, caller_value)
	assert_false(caller_value.has("backend_mutated"))

	while AudioServer.get_bus_effect_count(bus_index) > effect_count_before:
		AudioServer.remove_bus_effect(
			bus_index,
			AudioServer.get_bus_effect_count(bus_index) - 1
		)


func test_mix_snapshot_fallback_routes_same_name_bus_fields_to_backend_first() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	backend.volume_db = -4.0
	backend.muted = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	AudioServer.set_bus_volume_db(bus_index, -2.0)
	AudioServer.set_bus_mute(bus_index, false)

	var report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": {
				"volume_db": -16.0,
				"muted": true,
			},
		},
	}, 0.2)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "逐字段 backend fallback 全部接管时应成功。")
	assert_eq(backend.bulk_apply_count, 1, "完整快照应先且仅先尝试一次 backend bulk 接管。")
	assert_eq(backend.volume_apply_count, 1, "bulk 拒绝后应把同名总线增益交给 backend。")
	assert_eq(backend.mute_apply_count, 1, "bulk 拒绝后应把同名总线 mute 交给 backend。")
	assert_almost_eq(backend.volume_db, -16.0, 0.001, "backend 应接收目标增益。")
	assert_true(backend.muted, "backend 应接收目标 mute。")
	assert_almost_eq(backend.last_transition_seconds, 0.2, 0.001, "逐字段 backend 增益应收到快照过渡时间。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -2.0, 0.001, "backend 接管的增益不得写入同名本地总线。")
	assert_false(AudioServer.is_bus_mute(bus_index), "backend 接管的 mute 不得写入同名本地总线。")

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


func test_backend_owned_mix_snapshot_fields_do_not_cancel_local_transition() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_volume_db(bus_index, -2.0)
	AudioServer.set_bus_mute(bus_index, false)
	assert_true(_audio.set_bus_volume_db("Master", -20.0, 0.05), "测试应先启动本地增益 transition。")
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	var report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": {
				"volume_db": -12.0,
				"muted": true,
			},
		},
	})
	var transition_completed: bool = await _wait_for_bus_volume_target(
		bus_index,
		-20.0
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "backend 全接管的逐字段 fallback 应成功。")
	assert_almost_eq(backend.volume_db, -12.0, 0.001, "快照增益应由 backend 接管。")
	assert_true(backend.muted, "快照 mute 应由 backend 接管。")
	assert_true(transition_completed, "本地 transition 应在有界帧预算内完成。")
	assert_almost_eq(
		AudioServer.get_bus_volume_db(bus_index),
		-20.0,
		0.001,
		"backend 全接管时不得取消无关的同名本地 transition。"
	)

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


func test_backend_owned_numeric_mix_snapshot_does_not_cancel_local_transition() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_volume_db(bus_index, -2.0)
	AudioServer.set_bus_mute(bus_index, false)
	assert_true(_audio.set_bus_volume_db("Master", -20.0, 0.05), "测试应先启动本地增益 transition。")
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	var report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": -12.0,
		},
	})
	var transition_completed: bool = await _wait_for_bus_volume_target(
		bus_index,
		-20.0
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "数值简写的 backend fallback 应成功。")
	assert_almost_eq(backend.volume_db, -12.0, 0.001, "数值简写增益应由 backend 接管。")
	assert_true(transition_completed, "本地 transition 应在有界帧预算内完成。")
	assert_almost_eq(
		AudioServer.get_bus_volume_db(bus_index),
		-20.0,
		0.001,
		"backend 接管数值简写时不得取消无关的同名本地 transition。"
	)

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


func test_mix_snapshot_fallback_applies_only_backend_rejected_fields_locally() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	backend.handle_volume = true
	backend.handle_mute = false
	backend.volume_db = -4.0
	backend.muted = false
	AudioServer.set_bus_volume_db(bus_index, -2.0)
	AudioServer.set_bus_mute(bus_index, false)
	var backend_volume_report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": {
				"volume_db": -12.0,
				"muted": true,
			},
		},
	})

	assert_true(GFVariantData.get_option_bool(backend_volume_report, "ok"), "backend 增益与本地 mute 的部分接管应成功。")
	assert_almost_eq(backend.volume_db, -12.0, 0.001, "backend 应接管其接受的增益字段。")
	assert_true(AudioServer.is_bus_mute(bus_index), "backend 拒绝的 mute 字段应回退本地。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -2.0, 0.001, "本地 mute fallback 不得覆盖 backend 接管的增益字段。")

	backend.handle_volume = false
	backend.handle_mute = true
	backend.volume_db = -5.0
	backend.muted = false
	AudioServer.set_bus_volume_db(bus_index, -3.0)
	AudioServer.set_bus_mute(bus_index, false)
	var backend_mute_report: Dictionary = _audio.apply_mix_snapshot({
		"buses": {
			"Master": {
				"volume_db": -18.0,
				"muted": true,
			},
		},
	})

	assert_true(GFVariantData.get_option_bool(backend_mute_report, "ok"), "本地增益与 backend mute 的部分接管应成功。")
	assert_true(backend.muted, "backend 应接管其接受的 mute 字段。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -18.0, 0.001, "backend 拒绝的增益字段应回退本地。")
	assert_false(AudioServer.is_bus_mute(bus_index), "本地增益 fallback 不得覆盖 backend 接管的 mute 字段。")

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


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


func test_bgm_stop_fallback_reuses_one_cancellable_timer() -> void:
	var fallback_timer: Timer = null
	for cycle: int in range(5):
		_audio._play_bgm_stream(AudioStreamGenerator.new())
		_audio.stop_bgm(3600.0)
		var current_timer: Timer = _audio._bgm_stop_fallback_timer
		assert_not_null(current_timer, "长 fade 应建立可取消 fallback。")
		if current_timer == null:
			return
		if fallback_timer == null:
			fallback_timer = current_timer
		else:
			assert_same(current_timer, fallback_timer, "replacement 不得累计新的长寿命 timer。")
		assert_false(current_timer.is_stopped(), "当前 stop session 的 fallback 应处于计时状态。")

		_audio._play_bgm_stream(AudioStreamGenerator.new())
		assert_true(current_timer.is_stopped(), "replacement 必须主动取消旧 fallback。")

	assert_eq(
		_count_root_nodes_named("GFBGMStopFallbackTimer"),
		1,
		"任意时刻最多保留一个 utility-owned fallback timer。"
	)
	_audio.dispose()
	assert_null(_audio._bgm_stop_fallback_timer, "dispose 必须释放 fallback owner 引用。")
	assert_true(fallback_timer.is_queued_for_deletion(), "dispose 必须释放 fallback Timer 节点。")
	_audio.init()
	await get_tree().process_frame


func test_rejected_bgm_region_does_not_cancel_active_crossfade() -> void:
	var first_clip: GFAudioClip = GFAudioClip.new()
	first_clip.path = "crossfade-first"
	first_clip.stream = AudioStreamGenerator.new()
	var incoming_clip: GFAudioClip = GFAudioClip.new()
	incoming_clip.path = "crossfade-incoming"
	incoming_clip.stream = AudioStreamGenerator.new()
	_audio.play_bgm_clip(first_clip, 0.0)
	_audio.play_bgm_clip(incoming_clip, 0.5)
	var incoming_session_id: int = _audio._bgm_incoming_session_id
	var incoming_player: AudioStreamPlayer = _audio._get_bgm_session_player(
		_audio._get_bgm_session(incoming_session_id)
	)
	assert_gt(incoming_session_id, 0)
	assert_true(incoming_player.playing)

	var rejected_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	rejected_region.start_seconds = 0.1
	var rejected_clip: GFAudioClip = GFAudioClip.new()
	rejected_clip.path = "crossfade-rejected"
	rejected_clip.stream = AudioStreamGenerator.new()
	rejected_clip.playback_region = rejected_region
	_audio.play_bgm_clip(rejected_clip, 0.0)
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "bgm_state"),
		&"crossfading",
		"未通过 exact admission 的请求不得终止现有 crossfade。"
	)
	assert_eq(_audio._bgm_incoming_session_id, incoming_session_id)
	assert_same(
		_audio._get_bgm_session_player(_audio._get_bgm_session(incoming_session_id)),
		incoming_player
	)
	assert_true(incoming_player.playing)
	assert_eq(
		_audio.get_current_bgm_key(),
		"crossfade-incoming",
		"拒绝请求不得把公开 key 回滚到 outgoing 会话。"
	)


func test_async_bgm_clip_admission_keeps_active_crossfade_until_commit() -> void:
	var mock_asset: MockAssetUtility = MockAssetUtility.new()
	var audio: AssetBackedAudioUtility = AssetBackedAudioUtility.new(mock_asset)
	audio.init()
	await get_tree().process_frame
	var first_clip: GFAudioClip = GFAudioClip.new()
	first_clip.path = "async-crossfade-first"
	first_clip.stream = AudioStreamGenerator.new()
	var incoming_clip: GFAudioClip = GFAudioClip.new()
	incoming_clip.path = "async-crossfade-incoming"
	incoming_clip.stream = AudioStreamGenerator.new()
	audio.play_bgm_clip(first_clip, 0.0)
	audio.play_bgm_clip(incoming_clip, 0.5)
	var incoming_session_id: int = audio._bgm_incoming_session_id

	var pending_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	pending_region.start_seconds = 0.1
	var pending_clip: GFAudioClip = GFAudioClip.new()
	pending_clip.path = "res://audio/pending-unsupported.ogg"
	pending_clip.playback_region = pending_region
	audio.play_bgm_clip(pending_clip, 0.0)

	assert_eq(audio._bgm_incoming_session_id, incoming_session_id)
	assert_eq(audio._bgm_state, &"crossfading")
	assert_true(mock_asset.pending.has(pending_clip.path))

	mock_asset.finish(pending_clip.path, AudioStreamGenerator.new())
	assert_eq(
		audio._bgm_incoming_session_id,
		incoming_session_id,
		"异步加载后 exact admission 拒绝仍不得取消活动 incoming session。"
	)
	assert_eq(audio._bgm_state, &"crossfading")
	assert_eq(audio.get_current_bgm_key(), "async-crossfade-incoming")

	audio.dispose()
	await get_tree().process_frame


func test_replaced_crossfade_outgoing_finish_does_not_emit_natural_signal() -> void:
	watch_signals(_audio)
	var first_clip: GFAudioClip = _make_test_bgm_clip(
		"first",
		GFAudioPlaybackRegion.new()
	)
	first_clip.volume_db = -3.0
	var second_clip: GFAudioClip = _make_test_bgm_clip(
		"second",
		GFAudioPlaybackRegion.new()
	)
	second_clip.volume_db = -6.0
	var first_operation: GFBgmStartOperation = _audio.start_bgm_clip(first_clip, 0.0)
	var first_result: GFBgmStartResult = first_operation.get_result()
	var first_session: GFBgmSessionHandle = first_result.get_session_handle()
	assert_not_null(first_session)
	watch_signals(first_session)
	var second_operation: GFBgmStartOperation = _audio.start_bgm_clip(second_clip, 0.05)
	var second_result: GFBgmStartResult = second_operation.get_result()
	var second_session: GFBgmSessionHandle = second_result.get_session_handle()
	assert_not_null(second_session)
	var outgoing_player: AudioStreamPlayer = _audio._bgm_player
	var incoming_player: AudioStreamPlayer = _audio._bgm_fade_player

	assert_true(first_session.is_terminal())
	assert_eq(first_session.get_end_kind(), GFBgmSessionHandle.EndKind.REPLACED)
	assert_signal_emit_count(first_session, "ended", 1)
	outgoing_player.finished.emit()
	assert_signal_emit_count(first_session, "ended", 1)
	assert_signal_emit_count(_audio, "bgm_finished", 0)
	assert_true(second_session.is_active())
	assert_eq(_audio.get_current_bgm_key(), "second", "旧会话结束不得清空交叉淡入中的新会话 key。")

	await get_tree().create_timer(0.08).timeout
	assert_same(_audio._bgm_player, incoming_player, "交叉淡入应原子提交仍有效的 incoming 会话。")
	assert_true(_audio._bgm_player.playing, "提交后的 incoming 会话应保持播放。")


func test_post_commit_incoming_failure_does_not_revive_outgoing() -> void:
	watch_signals(_audio)
	var first_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	first_region.start_seconds = 0.1
	first_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	first_region.loop_start_seconds = 0.25
	var first_clip: GFAudioClip = _make_test_bgm_clip("first", first_region)
	var second_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	second_region.start_seconds = 0.4
	second_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	second_region.loop_start_seconds = 0.5
	var second_clip: GFAudioClip = _make_test_bgm_clip("second", second_region)

	var first_operation: GFBgmStartOperation = _audio.start_bgm_clip(first_clip, 0.0)
	var first_result: GFBgmStartResult = first_operation.get_result()
	var first_session: GFBgmSessionHandle = first_result.get_session_handle()
	assert_not_null(first_session)
	watch_signals(first_session)
	var second_operation: GFBgmStartOperation = _audio.start_bgm_clip(second_clip, 0.05)
	var second_result: GFBgmStartResult = second_operation.get_result()
	var second_session: GFBgmSessionHandle = second_result.get_session_handle()
	assert_not_null(second_session)
	watch_signals(second_session)
	var outgoing_player: AudioStreamPlayer = _audio._bgm_player
	var incoming_player: AudioStreamPlayer = _audio._bgm_fade_player

	incoming_player.stop()
	await get_tree().create_timer(0.08).timeout

	assert_true(first_session.is_terminal())
	assert_eq(first_session.get_end_kind(), GFBgmSessionHandle.EndKind.REPLACED)
	assert_signal_emit_count(first_session, "ended", 1)
	assert_true(second_session.is_terminal())
	assert_eq(second_session.get_end_kind(), GFBgmSessionHandle.EndKind.PLAYBACK_FAILED)
	assert_signal_emit_count(second_session, "ended", 1)
	assert_false(outgoing_player.playing, "已终结的 outgoing 会话不得在 incoming 失败后复活。")
	assert_false(incoming_player.playing)
	assert_eq(_audio.get_current_bgm_key(), "", "post-commit incoming 失败必须清空当前 key。")
	var snapshot: Dictionary = _audio.get_debug_snapshot()
	var current_region: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"current_bgm_region"
	)
	assert_true(current_region.is_empty(), "post-commit incoming 失败必须清空播放区间。")
	assert_signal_emit_count(_audio, "bgm_finished", 0)


func test_stop_during_crossfade_clears_terminal_key_and_playback_region() -> void:
	var outgoing_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	outgoing_region.loop_mode = GFAudioPlaybackRegion.LoopMode.FORWARD
	outgoing_region.loop_start_seconds = 0.25
	var incoming_region: GFAudioPlaybackRegion = GFAudioPlaybackRegion.new()
	incoming_region.start_seconds = 0.5
	_audio.play_bgm_clip(_make_test_bgm_clip("outgoing", outgoing_region), 0.0)
	_audio.play_bgm_clip(_make_test_bgm_clip("incoming", incoming_region), 0.05)

	_audio.stop_bgm(0.05)
	assert_eq(_audio.get_current_bgm_key(), "", "crossfade 中 stop 应立即清空当前 key。")
	await get_tree().create_timer(0.08).timeout
	var snapshot: Dictionary = _audio.get_debug_snapshot()

	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_state"), &"stopped", "淡出完成后应进入 stopped。")
	assert_eq(GFVariantData.get_option_string_name(snapshot, "bgm_owner"), &"none", "淡出完成后不应残留 owner。")
	assert_eq(GFVariantData.get_option_string(snapshot, "current_bgm_key"), "", "终态不得恢复 outgoing key。")
	assert_true(
		GFVariantData.get_option_dictionary(snapshot, "current_bgm_region").is_empty(),
		"终态不得恢复 outgoing 播放区间。"
	)


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


func test_backend_duck_scope_update_failure_preserves_existing_duck() -> void:
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	backend.volume_db = -6.0
	backend.muted = false
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")
	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "初始 backend duck 应成功。")
	assert_almost_eq(backend.volume_db, -15.0, 0.001, "初始作用域应建立已应用状态。")

	backend.handle_volume = false
	assert_false(
		_audio.duck_bus("Master", 0.75, 0.0, &"notification"),
		"backend 拒绝增益更新时新增作用域应失败。"
	)
	assert_almost_eq(backend.volume_db, -15.0, 0.001, "增益更新失败不得把已有 duck 恢复为 base。")
	var state: Dictionary = GFVariantData.get_option_dictionary(_audio._duck_bus_states, "Master")
	var scopes: Dictionary = GFVariantData.get_option_dictionary(state, "scopes")
	assert_true(scopes.has(&"dialogue"), "失败后应保留原有作用域。")
	assert_false(scopes.has(&"notification"), "失败后不得登记未应用的新作用域。")

	backend.handle_volume = true
	backend.handle_mute = false
	var volume_apply_count: int = backend.volume_apply_count
	assert_false(
		_audio.duck_bus("Master", 0.75, 0.0, &"notification"),
		"backend 拒绝 mute 保持请求时新增作用域应失败。"
	)
	assert_eq(backend.volume_apply_count, volume_apply_count, "mute 失败后不得继续写入增益。")
	assert_almost_eq(backend.volume_db, -15.0, 0.001, "mute 失败不得破坏已有 duck。")

	backend.handle_mute = true
	assert_true(_audio.restore_ducked_bus("Master", 0.0, &"dialogue"), "恢复 setter 后应能释放原有作用域。")
	assert_almost_eq(backend.volume_db, -6.0, 0.001, "最终应恢复稳定 backend 基准。")


func test_same_name_backend_owns_duck_capture_apply_restore_and_dispose() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_volume_db(bus_index, -2.0)
	AudioServer.set_bus_mute(bus_index, false)
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	backend.volume_db = -6.0
	backend.muted = true
	assert_true(_audio.set_audio_backend(backend), "测试后端应成功绑定。")

	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "同名 backend 总线应接管 duck。")
	assert_almost_eq(backend.volume_db, -15.0, 0.001, "duck 应从 backend 观测到的基准增益计算。")
	assert_true(backend.muted, "duck 应保留 backend 观测到的 mute 基准。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -2.0, 0.001, "backend-owned duck 不得修改同名本地增益。")
	assert_false(AudioServer.is_bus_mute(bus_index), "backend-owned duck 不得修改同名本地 mute。")

	assert_true(_audio.restore_ducked_bus("Master", 0.0, &"dialogue"), "同名 backend 总线应恢复记录的 owner。")
	assert_almost_eq(backend.volume_db, -6.0, 0.001, "显式 restore 应恢复 backend 基准增益。")
	assert_true(backend.muted, "显式 restore 应恢复 backend 基准 mute。")

	assert_true(_audio.duck_bus("Master", 0.25, 0.0, &"notification"), "dispose 前应再次建立 backend-owned duck。")
	_audio.dispose()

	assert_almost_eq(backend.volume_db, -6.0, 0.001, "dispose 应在释放 backend 前恢复其基准增益。")
	assert_true(backend.muted, "dispose 应在释放 backend 前恢复其基准 mute。")
	assert_true(backend.disposed, "恢复 duck 后应正常 dispose backend。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -2.0, 0.001, "dispose 不得误恢复同名本地增益。")
	assert_false(AudioServer.is_bus_mute(bus_index), "dispose 不得误恢复同名本地 mute。")

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


func test_backend_replacement_restores_duck_to_recorded_backend_identity() -> void:
	var original_backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	original_backend.volume_db = -6.0
	original_backend.muted = false
	var replacement_backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	replacement_backend.volume_db = -3.0
	replacement_backend.muted = true
	assert_true(_audio.set_audio_backend(original_backend), "原 backend 应成功绑定。")
	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "原 backend 应接管 duck。")
	assert_almost_eq(original_backend.volume_db, -15.0, 0.001, "替换前原 backend 应处于 duck 状态。")

	assert_true(_audio.set_audio_backend(replacement_backend), "替换 backend 前应恢复原 owner。")

	assert_almost_eq(original_backend.volume_db, -6.0, 0.001, "替换时应恢复记录在原 backend 上的基准增益。")
	assert_false(original_backend.muted, "替换时应恢复记录在原 backend 上的基准 mute。")
	assert_true(original_backend.disposed, "原 backend 恢复完成后才可 dispose。")
	assert_same(_audio.get_audio_backend(), replacement_backend, "替换完成后应绑定新 backend identity。")
	assert_almost_eq(replacement_backend.volume_db, -3.0, 0.001, "旧 duck 不得应用到新 backend。")
	assert_true(replacement_backend.muted, "旧 duck 不得覆盖新 backend 的 mute。")
	assert_eq(
		GFVariantData.get_option_int(_audio.get_debug_snapshot(), "ducked_bus_count"),
		0,
		"完成 owner 切换后不得保留绑定旧 backend 的 duck 状态。"
	)


func test_configuring_backend_restores_active_local_duck_before_owner_transition() -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	var original_db: float = AudioServer.get_bus_volume_db(bus_index)
	var original_muted: bool = AudioServer.is_bus_mute(bus_index)
	AudioServer.set_bus_volume_db(bus_index, -6.0)
	AudioServer.set_bus_mute(bus_index, false)
	assert_true(_audio.duck_bus("Master", 0.5, 0.0, &"dialogue"), "本地总线应先建立 duck。")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -15.0, 0.001, "本地 duck 应已生效。")
	var backend: OwnedBusAudioBackend = OwnedBusAudioBackend.new()
	backend.volume_db = -3.0
	backend.muted = true

	assert_true(_audio.set_audio_backend(backend), "配置 backend 前应收敛旧 local owner。")

	assert_almost_eq(AudioServer.get_bus_volume_db(bus_index), -6.0, 0.001, "owner 切换前应恢复本地基准。")
	assert_false(AudioServer.is_bus_mute(bus_index), "owner 切换前应恢复本地 mute。")
	assert_almost_eq(backend.volume_db, -3.0, 0.001, "旧 local duck 不得迁移到新 backend。")
	assert_true(backend.muted, "旧 local duck 不得覆盖新 backend mute。")
	assert_eq(
		GFVariantData.get_option_int(_audio.get_debug_snapshot(), "ducked_bus_count"),
		0,
		"owner 切换完成后不得保留绑定旧 local owner 的 duck 状态。"
	)

	AudioServer.set_bus_volume_db(bus_index, original_db)
	AudioServer.set_bus_mute(bus_index, original_muted)


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


func test_dispose_tolerates_both_root_owned_bgm_players_freed_first() -> void:
	var bgm_player: AudioStreamPlayer = _audio._bgm_player
	var bgm_fade_player: AudioStreamPlayer = _audio._bgm_fade_player
	bgm_player.free()
	bgm_fade_player.free()

	_audio.dispose()

	assert_null(_audio._bgm_player, "双播放器先于 Utility 释放后应清除主播放器引用。")
	assert_null(_audio._bgm_fade_player, "双播放器先于 Utility 释放后应清除淡变播放器引用。")
	assert_eq(_audio._bgm_state, &"stopped", "root-first teardown 后 BGM 状态必须收敛。")


func test_dispose_tolerates_one_root_owned_bgm_player_freed_first() -> void:
	var bgm_player: AudioStreamPlayer = _audio._bgm_player
	var bgm_fade_player: AudioStreamPlayer = _audio._bgm_fade_player
	bgm_player.free()

	_audio.dispose()

	assert_null(_audio._bgm_player, "已提前释放的播放器引用应清除。")
	assert_null(_audio._bgm_fade_player, "仍存活的播放器进入释放流程后也应解除引用。")
	assert_true(bgm_fade_player.is_queued_for_deletion(), "仍存活的淡变播放器应进入释放流程。")


func test_dispose_is_idempotent_after_bgm_players_are_released() -> void:
	_audio.dispose()
	await get_tree().process_frame

	_audio.dispose()

	assert_null(_audio._bgm_player, "重复 dispose 不得保留已释放的主播放器引用。")
	assert_null(_audio._bgm_fade_player, "重复 dispose 不得保留已释放的淡变播放器引用。")
	assert_eq(_audio._bgm_owner, &"none", "重复 dispose 后 BGM owner 必须保持终态。")


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
	assert_eq(backend.stop_bgm_count, 1, "延迟 dispose 应在查询回调退出后恰好停止一次后端 BGM。")
	assert_true(backend.disposed, "延迟 dispose 应在查询回调退出后完成后端释放。")
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


func _make_test_bgm_clip(
	history_key: String,
	playback_region: GFAudioPlaybackRegion
) -> GFAudioClip:
	var sample_bytes: PackedByteArray = PackedByteArray()
	var _resize_error_3237: Error = sample_bytes.resize(2_000) as Error
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 1_000
	stream.stereo = false
	stream.data = sample_bytes
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = history_key
	clip.stream = stream
	clip.playback_region = playback_region
	return clip


func _wait_for_bus_volume_target(
	bus_index: int,
	expected_db: float,
	max_frames: int = 240
) -> bool:
	for _frame_index: int in range(max_frames):
		if absf(AudioServer.get_bus_volume_db(bus_index) - expected_db) <= 0.001:
			return true
		await get_tree().process_frame
	return absf(AudioServer.get_bus_volume_db(bus_index) - expected_db) <= 0.001


func _count_root_audio_players_named(player_name: String) -> int:
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child is AudioStreamPlayer and child.name == player_name:
			count += 1
	return count


func _count_root_nodes_named(node_name: String) -> int:
	var count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == node_name:
			count += 1
	return count
