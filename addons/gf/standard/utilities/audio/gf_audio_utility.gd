## GFAudioUtility: 全局音频管理器。
##
## 管理 BGM 和 SFX 的播放与音量。
## 注册 GFObjectPoolUtility 时会复用 AudioStreamPlayer，未注册时使用普通播放器。
## 支持通过 GFAssetUtility 异步加载音频资源。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFAudioUtility
extends GFUtility


# --- 信号 ---

## 当前 BGM 自然播放结束时发出。
## [br]
## @api public
## [br]
## @param history_key: 播放请求记录的 BGM key。
signal bgm_finished(history_key: String)


# --- 枚举 ---

## SFX 超出并发上限时的处理策略。
## [br]
## @api public
enum SFXOverflowPolicy {
	## 跳过新的 SFX 请求。
	SKIP_NEW,
	## 停止最早播放的 SFX，并播放新的请求。
	STOP_OLDEST,
}


# --- 常量 ---

## 默认 BGM 音频总线名。
## [br]
## @api public
const BGM_BUS_NAME: String = "BGM"

## 默认 SFX 音频总线名。
## [br]
## @api public
const SFX_BUS_NAME: String = "SFX"

## GF 默认视为静音下限的 dB 值。
## [br]
## @api public
const SILENCE_VOLUME_DB: float = -80.0

const _FALLBACK_BUS_NAME: String = "Master"
const _APPLY_SPATIAL_SETTINGS_2D_METHOD: StringName = &"apply_to_2d"
const _APPLY_SPATIAL_SETTINGS_3D_METHOD: StringName = &"apply_to_3d"
const _DEFAULT_SPATIAL_AREA_MASK: int = 1
const _MIX_SNAPSHOT_BUSES_KEY: String = "buses"
const _MIX_SNAPSHOT_EFFECTS_KEY: String = "effects"
const _PLAYBACK_SESSION_META: StringName = &"_gf_audio_playback_session_id"


# --- 公共变量 ---

## 同时播放的 SFX 数量上限；小于等于 0 表示不限制。
## [br]
## @api public
var max_sfx_players: int = 32

## SFX 超出并发上限时采用的处理策略。
## [br]
## @api public
var sfx_overflow_policy: SFXOverflowPolicy = SFXOverflowPolicy.SKIP_NEW

## 默认 BGM 淡入淡出秒数。单次播放传入负数时使用该值。
## [br]
## @api public
var bgm_crossfade_seconds: float = 0.0

## BGM 历史记录最大数量。
## [br]
## @api public
var max_bgm_history: int = 16


# --- 私有变量 ---

var _bgm_player: AudioStreamPlayer
var _bgm_fade_player: AudioStreamPlayer
var _sfx_scene: PackedScene
var _root: Node
var _bgm_request_serial: int = 0
var _bgm_fade_serial: int = 0
var _bgm_fade_tween_ref: WeakRef = null
var _bgm_pause_serial: int = 0
var _bgm_transport_tween_ref: WeakRef = null
var _bgm_paused: bool = false
var _bgm_pause_volume_db: float = 0.0
var _sfx_lifecycle_serial: int = 0
var _next_playback_session_id: int = 1
var _playback_session_handles: Dictionary = {}
var _missing_bus_warnings: Dictionary = {}
var _active_sfx_players: Array[AudioStreamPlayer] = []
var _active_spatial_sfx_players: Array[Node] = []
var _bgm_history: PackedStringArray = PackedStringArray()
var _current_bgm_key: String = ""
var _current_bgm_loop: Variant = null
var _ambient_players: Dictionary = {}
var _ambient_request_serials: Dictionary = {}
var _audio_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _audio_banks: Dictionary = {}
var _audio_bank_base_values: Dictionary = {}
var _audio_bank_mount_stacks: Dictionary = {}
var _audio_bank_mount_token: int = 0
var _audio_backend: GFAudioBackend = null
var _bus_volume_tween_refs: Dictionary = {}
var _bus_effect_tween_refs: Dictionary = {}
var _duck_base_bus_volumes_db: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化音频播放器、运行时状态和默认播放根节点。
## [br]
## @api public
func init() -> void:
	_bgm_request_serial = 0
	_bgm_fade_serial = 0
	_bgm_fade_tween_ref = null
	_bgm_pause_serial = 0
	_bgm_transport_tween_ref = null
	_bgm_paused = false
	_bgm_pause_volume_db = 0.0
	_sfx_lifecycle_serial += 1
	_next_playback_session_id = 1
	_playback_session_handles.clear()
	_missing_bus_warnings.clear()
	_active_sfx_players.clear()
	_active_spatial_sfx_players.clear()
	_bgm_history = PackedStringArray()
	_current_bgm_key = ""
	_current_bgm_loop = null
	_ambient_players.clear()
	_ambient_request_serials.clear()
	_audio_rng.randomize()
	_audio_banks.clear()
	_audio_bank_base_values.clear()
	_audio_bank_mount_stacks.clear()
	_audio_bank_mount_token = 0
	_clear_mix_control_tweens()
	_duck_base_bus_volumes_db.clear()
	# 动态创建用于可选池化的 SFX 播放器模版
	var player_template: AudioStreamPlayer = AudioStreamPlayer.new()
	_sfx_scene = PackedScene.new()
	_pack_scene_template(_sfx_scene, player_template)
	player_template.free()
	
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "GFBGMPlayer"
	_bgm_player.bus = _resolve_bus_name(BGM_BUS_NAME)
	_connect_signal_checked(_bgm_player.finished, _on_bgm_player_finished.bind(_bgm_player))
	_bgm_fade_player = AudioStreamPlayer.new()
	_bgm_fade_player.name = "GFBGMFadePlayer"
	_bgm_fade_player.bus = _resolve_bus_name(BGM_BUS_NAME)
	_connect_signal_checked(_bgm_fade_player.finished, _on_bgm_player_finished.bind(_bgm_fade_player))
	
	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		_root = tree.root
		_root.call_deferred("add_child", _bgm_player)
		_root.call_deferred("add_child", _bgm_fade_player)


## 释放播放器、后端、环境音和 SFX 运行时状态。
## [br]
## @api public
func dispose() -> void:
	_bgm_request_serial += 1
	_bgm_fade_serial += 1
	_bgm_pause_serial += 1
	_cancel_bgm_fade_tween()
	_cancel_bgm_transport_tween()
	_sfx_lifecycle_serial += 1
	_bgm_paused = false
	_current_bgm_loop = null
	_clear_audio_backend(true)
	_release_all_sfx_players(0.0)
	_release_all_spatial_sfx_players(0.0)
	_playback_session_handles.clear()
	_free_all_ambient_players()
	_clear_mix_control_tweens()
	if is_instance_valid(_bgm_player):
		_bgm_player.queue_free()
	if is_instance_valid(_bgm_fade_player):
		_bgm_fade_player.queue_free()
	_root = null
	_audio_banks.clear()
	_audio_bank_base_values.clear()
	_audio_bank_mount_stacks.clear()
	_duck_base_bus_volumes_db.clear()
	
	# SFX 节点已由 _release_all_sfx_players() 统一释放。


# --- 公共方法 ---

## 播放 BGM（背景音乐）
## [br]
## @api public
## [br]
## @param path: 音频资源的路径
## [br]
## @param crossfade_seconds: 淡入淡出秒数；小于 0 时使用默认值。
func play_bgm(path: String, crossfade_seconds: float = -1.0) -> void:
	play_bgm_with_options(path, {
		"crossfade_seconds": crossfade_seconds,
	})


## 使用选项播放 BGM。
## [br]
## @api public
## [br]
## @param path: 音频资源路径或后端事件路径。
## [br]
## @param options: 支持 crossfade_seconds、history_key、loop、bus_name、volume_db 和 pitch_scale。
## [br]
## @schema options: Dictionary，可包含 crossfade_seconds、history_key、loop、bus_name、volume_db 和 pitch_scale 字段。
func play_bgm_with_options(path: String, options: Dictionary = {}) -> void:
	_bgm_request_serial += 1
	_bgm_pause_serial += 1
	_bgm_paused = false
	var request_serial: int = _bgm_request_serial
	var crossfade_seconds: float = _finite_or_default(
		GFVariantData.get_option_float(options, "crossfade_seconds", -1.0),
		-1.0
	)
	var history_key: String = path
	if options.has("history_key"):
		history_key = GFVariantData.to_text(options["history_key"])
	var bus_name: String = BGM_BUS_NAME
	if options.has("bus_name"):
		bus_name = GFVariantData.to_text(options["bus_name"], BGM_BUS_NAME)
	var volume_db: float = _finite_or_default(GFVariantData.get_option_float(options, "volume_db", 0.0), 0.0)
	var pitch_scale: float = _finite_or_default(GFVariantData.get_option_float(options, "pitch_scale", 1.0), 1.0)
	var loop_override: Variant = GFVariantData.get_option_value(options, "loop") if options.has("loop") else null
	_current_bgm_loop = loop_override
	if path.is_empty():
		stop_bgm(crossfade_seconds)
		return

	var backend_options: Dictionary = options.duplicate(true)
	backend_options["crossfade_seconds"] = _resolve_bgm_crossfade_seconds(crossfade_seconds)
	backend_options["history_key"] = history_key
	backend_options["bus_name"] = bus_name
	backend_options["volume_db"] = volume_db
	backend_options["pitch_scale"] = pitch_scale
	if _try_backend_play_bgm_path(path, backend_options):
		_record_bgm_history(history_key)
		return
		
	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(path))
		_apply_bgm_request_with_settings(
			request_serial,
			stream,
			bus_name,
			volume_db,
			pitch_scale,
			crossfade_seconds,
			history_key,
			loop_override
		)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_bgm_request_with_settings(
				request_serial,
				_get_audio_stream_value(res),
				bus_name,
				volume_db,
				pitch_scale,
				crossfade_seconds,
				history_key,
				loop_override
			)
		asset_util.load_async(path, on_loaded)


## 播放资源化 BGM 配置。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param crossfade_seconds: 淡入淡出秒数；小于 0 时使用默认值。
func play_bgm_clip(clip: GFAudioClip, crossfade_seconds: float = -1.0) -> void:
	if clip == null or not clip.has_source():
		return

	_bgm_request_serial += 1
	_bgm_pause_serial += 1
	_bgm_paused = false
	_current_bgm_loop = null
	var request_serial: int = _bgm_request_serial
	var bus_name: String = clip.resolve_bus(BGM_BUS_NAME)
	var volume_db: float = _finite_or_default(clip.volume_db, 0.0)
	var pitch_scale: float = _finite_or_default(clip.resolve_pitch(_audio_rng), 1.0)
	var history_key: String = _get_clip_history_key(clip)
	var backend_options: Dictionary = {
		"crossfade_seconds": _resolve_bgm_crossfade_seconds(crossfade_seconds),
		"bus_name": bus_name,
		"volume_db": volume_db,
		"pitch_scale": pitch_scale,
		"history_key": history_key,
	}

	if _try_backend_play_bgm_clip(clip, backend_options):
		_record_bgm_history(history_key)
		return

	if clip.stream != null:
		_apply_bgm_request_with_settings(
			request_serial,
			clip.stream,
			bus_name,
			volume_db,
			pitch_scale,
			crossfade_seconds,
			history_key
		)
		return

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(clip.path))
		_apply_bgm_request_with_settings(
			request_serial,
			stream,
			bus_name,
			volume_db,
			pitch_scale,
			crossfade_seconds,
			history_key
		)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_bgm_request_with_settings(
				request_serial,
				_get_audio_stream_value(res),
				bus_name,
				volume_db,
				pitch_scale,
				crossfade_seconds,
				history_key
			)
		asset_util.load_async(clip.path, on_loaded)


## 从音频集合播放 BGM。
## [br]
## @api public
## [br]
## @param bank: 音频集合。
## [br]
## @param clip_id: 片段标识。
## [br]
## @param crossfade_seconds: 淡入淡出秒数；小于 0 时使用默认值。
func play_bgm_from_bank(bank: GFAudioBank, clip_id: StringName, crossfade_seconds: float = -1.0) -> void:
	if bank == null:
		return

	play_bgm_clip(bank.get_clip_with_fallback(clip_id, _audio_rng), crossfade_seconds)


## 按事件 ID 播放注册音频集合中的 BGM。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param crossfade_seconds: 淡入淡出秒数；小于 0 时使用默认值。
func play_bgm_event(
	event_id: StringName,
	bank_id: StringName = &"",
	crossfade_seconds: float = -1.0
) -> void:
	play_bgm_clip(_get_registered_clip(event_id, bank_id), crossfade_seconds)


## 停止当前 BGM。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出秒数。
func stop_bgm(fade_seconds: float = 0.0) -> void:
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	_bgm_request_serial += 1
	_notify_backend_stop_bgm(safe_fade)
	_cancel_bgm_crossfade_playback()
	_bgm_pause_serial += 1
	_cancel_bgm_transport_tween()
	_bgm_paused = false
	_current_bgm_key = ""
	_current_bgm_loop = null
	if is_instance_valid(_bgm_player):
		_bgm_player.stream_paused = false
		_stop_player(_bgm_player, safe_fade)
		_schedule_bgm_stop_fallback(_bgm_player, _bgm_request_serial, safe_fade)
	if is_instance_valid(_bgm_fade_player):
		_bgm_fade_player.stream_paused = false
		_bgm_fade_player.stop()


## 暂停当前 BGM。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出到暂停的秒数。
## [br]
## @return: 成功暂停或后端已处理时返回 true。
func pause_bgm(fade_seconds: float = 0.0) -> bool:
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	_cancel_bgm_crossfade_playback()
	_cancel_bgm_transport_tween()
	if _audio_backend != null and _audio_backend.pause_bgm(safe_fade):
		_bgm_paused = true
		return true

	if not is_instance_valid(_bgm_player) or _bgm_player.stream == null:
		return false

	_bgm_pause_serial += 1
	var pause_serial: int = _bgm_pause_serial
	_bgm_paused = true
	_bgm_pause_volume_db = _bgm_player.volume_db
	if safe_fade > 0.0 and _bgm_player.playing:
		var tween: Tween = _fade_player_volume(_bgm_player, -80.0, safe_fade)
		if tween != null:
			_bgm_transport_tween_ref = weakref(tween)
			_connect_signal_checked(tween.finished, _apply_bgm_pause.bind(pause_serial, _bgm_player), CONNECT_ONE_SHOT)
			return true

	_apply_bgm_pause(pause_serial, _bgm_player)
	return true


## 恢复当前 BGM。
## [br]
## @api public
## [br]
## @param from_position: 大于等于 0 时从指定秒数恢复。
## [br]
## @param fade_seconds: 淡入秒数。
## [br]
## @return: 成功恢复或后端已处理时返回 true。
func resume_bgm(from_position: float = -1.0, fade_seconds: float = 0.0) -> bool:
	var normalized_position: float = _finite_or_default(from_position, -1.0)
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var safe_position: float = maxf(normalized_position, 0.0)
	_cancel_bgm_transport_tween()
	if _audio_backend != null and _audio_backend.resume_bgm(normalized_position, safe_fade):
		_bgm_paused = false
		return true

	if not is_instance_valid(_bgm_player) or _bgm_player.stream == null:
		return false

	_bgm_pause_serial += 1
	var resume_serial: int = _bgm_pause_serial
	var target_volume: float = _bgm_pause_volume_db if _bgm_paused else _bgm_player.volume_db
	if normalized_position >= 0.0:
		_bgm_player.seek(safe_position)
	_bgm_player.stream_paused = false
	if not _bgm_player.playing:
		_bgm_player.play(safe_position if normalized_position >= 0.0 else 0.0)
	_bgm_paused = false
	if safe_fade > 0.0:
		_bgm_player.volume_db = -80.0
		var tween: Tween = _fade_player_volume(_bgm_player, target_volume, safe_fade)
		if tween != null:
			_bgm_transport_tween_ref = weakref(tween)
			_connect_signal_checked(tween.finished, _clear_bgm_transport_tween.bind(resume_serial), CONNECT_ONE_SHOT)
	else:
		_bgm_player.volume_db = target_volume
	return true


## 跳转当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @param position_seconds: 目标秒数。
## [br]
## @return: 成功跳转或后端已处理时返回 true。
func seek_bgm(position_seconds: float) -> bool:
	if not _is_finite_float(position_seconds):
		return false
	var safe_position: float = maxf(position_seconds, 0.0)
	if _audio_backend != null and _audio_backend.seek_bgm(safe_position):
		return true

	if not is_instance_valid(_bgm_player) or _bgm_player.stream == null:
		return false

	_bgm_player.seek(safe_position)
	return true


## 获取当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @return: 当前播放秒数；无可查询播放器时返回 0。
func get_bgm_playback_position() -> float:
	if _audio_backend != null:
		var backend_position: float = _audio_backend.get_bgm_playback_position()
		if backend_position >= 0.0:
			return backend_position

	if not is_instance_valid(_bgm_player) or _bgm_player.stream == null:
		return 0.0
	return _bgm_player.get_playback_position()


## 查询当前 BGM 是否暂停。
## [br]
## @api public
## [br]
## @return: 暂停时返回 true。
func is_bgm_paused() -> bool:
	if _audio_backend != null and _audio_backend.is_bgm_paused():
		return true
	if is_instance_valid(_bgm_player) and _bgm_player.stream_paused:
		return true
	return _bgm_paused


## 获取 BGM 播放历史。
## [br]
## @api public
## [br]
## @return: 从旧到新的历史 key。
func get_bgm_history() -> PackedStringArray:
	return PackedStringArray(_bgm_history)


## 获取当前 BGM key。
## [br]
## @api public
## [br]
## @return: 当前 BGM key；无播放时为空。
func get_current_bgm_key() -> String:
	return _current_bgm_key


## 清空 BGM 历史。
## [br]
## @api public
func clear_bgm_history() -> void:
	_bgm_history = PackedStringArray()


## 注册一个全局音频集合，供事件式播放接口使用。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
## [br]
## @param bank: 音频集合。
func register_audio_bank(bank_id: StringName, bank: GFAudioBank) -> void:
	if bank_id == &"":
		push_error("[GFAudioUtility] register_audio_bank 失败：bank_id 为空。")
		return
	_erase_dictionary_key(_audio_bank_base_values, bank_id)
	_erase_dictionary_key(_audio_bank_mount_stacks, bank_id)
	if bank == null:
		_erase_dictionary_key(_audio_banks, bank_id)
		return
	_audio_banks[bank_id] = bank


## 移除一个全局音频集合。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
func unregister_audio_bank(bank_id: StringName) -> void:
	_erase_dictionary_key(_audio_bank_base_values, bank_id)
	_erase_dictionary_key(_audio_bank_mount_stacks, bank_id)
	_erase_dictionary_key(_audio_banks, bank_id)


## 清空全局音频集合注册表。
## [br]
## @api public
func clear_audio_banks() -> void:
	_audio_bank_base_values.clear()
	_audio_bank_mount_stacks.clear()
	_audio_banks.clear()


## 挂载一个临时音频集合，并返回用于卸载的挂载令牌。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
## [br]
## @param bank: 音频集合。
## [br]
## @param restore_previous_bank: 卸载顶层挂载时是否恢复同 ID 的上一层音频集合。
## [br]
## @return: 挂载令牌；失败时返回 0。
func mount_audio_bank(
	bank_id: StringName,
	bank: GFAudioBank,
	restore_previous_bank: bool = true
) -> int:
	if bank_id == &"":
		push_error("[GFAudioUtility] mount_audio_bank 失败：bank_id 为空。")
		return 0
	if bank == null:
		push_error("[GFAudioUtility] mount_audio_bank 失败：bank 为空。")
		return 0

	if not _audio_bank_mount_stacks.has(bank_id):
		if _audio_banks.has(bank_id):
			_audio_bank_base_values[bank_id] = _audio_banks[bank_id]
		var new_stack: Array[Dictionary] = []
		_audio_bank_mount_stacks[bank_id] = new_stack

	_audio_bank_mount_token += 1
	var token: int = _audio_bank_mount_token
	var stack: Array = _get_audio_bank_mount_stack(bank_id)
	_append_array_item(stack, {
		"token": token,
		"bank": bank,
		"restore_previous_bank": restore_previous_bank,
	})
	_audio_banks[bank_id] = bank
	return token


## 卸载由 mount_audio_bank() 创建的临时音频集合。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
## [br]
## @param mount_token: mount_audio_bank() 返回的挂载令牌。
## [br]
## @return: 找到并卸载对应挂载时返回 true。
func unmount_audio_bank(bank_id: StringName, mount_token: int) -> bool:
	if bank_id == &"" or mount_token <= 0:
		return false
	if not _audio_bank_mount_stacks.has(bank_id):
		return false

	var stack: Array = _get_audio_bank_mount_stack(bank_id)
	var remove_index: int = -1
	for index: int in range(stack.size() - 1, -1, -1):
		var entry: Dictionary = GFVariantData.as_dictionary(stack[index])
		if _get_mount_entry_token(entry) == mount_token:
			remove_index = index
			break
	if remove_index == -1:
		return false

	var removed_entry: Dictionary = GFVariantData.as_dictionary(stack[remove_index])
	var was_top: bool = remove_index == stack.size() - 1
	stack.remove_at(remove_index)
	if was_top:
		_restore_audio_bank_after_unmount(bank_id, stack, _get_mount_entry_restore_previous(removed_entry))
	if stack.is_empty():
		_erase_dictionary_key(_audio_bank_mount_stacks, bank_id)
		_erase_dictionary_key(_audio_bank_base_values, bank_id)
	return true


## 获取全局音频集合。
## [br]
## @api public
## [br]
## @param bank_id: 音频集合标识。
## [br]
## @return: 音频集合；不存在时返回 null。
func get_audio_bank(bank_id: StringName) -> GFAudioBank:
	return _get_audio_bank_by_id(bank_id)


## 设置可插拔音频后端。传入 null 时恢复默认 Godot 播放路径。
## [br]
## @api public
## [br]
## @param backend: 音频后端。
func set_audio_backend(backend: GFAudioBackend) -> void:
	if _audio_backend == backend:
		return
	_clear_audio_backend(true)
	_audio_backend = backend
	if _audio_backend != null:
		_audio_backend.setup(self)


## 获取当前音频后端。
## [br]
## @api public
## [br]
## @return: 音频后端；未设置时返回 null。
func get_audio_backend() -> GFAudioBackend:
	return _audio_backend


## 清除当前音频后端。
## [br]
## @api public
## [br]
## @param dispose_backend: 是否调用后端 dispose()。
func clear_audio_backend(dispose_backend: bool = true) -> void:
	_clear_audio_backend(dispose_backend)


## 发布资源化音频事件。
## [br]
## @api public
## [br]
## @param event: 音频事件资源。
## [br]
## @param options: 请求选项。
## [br]
## @return: 控制句柄；不需要或无法返回句柄时返回 null。
## [br]
## @schema options: Dictionary，作为事件请求附加选项，会与 GFAudioEvent.to_request_options() 的结果合并。
func post_audio_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:
	if event == null or not event.has_request():
		return null
	var request_options: Dictionary = event.to_request_options(options)
	if _audio_backend != null and _audio_backend.can_handle_event(event, request_options):
		return _audio_backend.post_event(event, request_options)

	match event.channel:
		&"bgm":
			_post_bgm_event(event, request_options)
			return null
		&"ambient":
			_post_ambient_event(event, request_options)
			return null
		&"spatial_sfx":
			return _post_spatial_sfx_event(event, request_options)
		_:
			return _post_sfx_event(event)


## 写入音频参数。
## [br]
## @api public
## [br]
## @param parameter: 参数请求。
## [br]
## @return: 后端已处理返回 true。
func set_audio_parameter(parameter: GFAudioParameter) -> bool:
	return _audio_backend != null and _audio_backend.set_parameter(parameter)


## 写入音频状态。
## [br]
## @api public
## [br]
## @param state: 状态请求。
## [br]
## @return: 后端已处理返回 true。
func set_audio_state(state: GFAudioState) -> bool:
	return _audio_backend != null and _audio_backend.set_state(state)


## 写入音频开关。
## [br]
## @api public
## [br]
## @param audio_switch: 开关请求。
## [br]
## @return: 后端已处理返回 true。
func set_audio_switch(audio_switch: GFAudioSwitch) -> bool:
	return _audio_backend != null and _audio_backend.set_switch(audio_switch)


## 播放环境音。
## [br]
## @api public
## [br]
## @param path: 音频资源路径。
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡入秒数。
func play_ambient(path: String, channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
	if path.is_empty():
		stop_ambient(channel, fade_seconds)
		return

	if _try_backend_play_ambient_path(path, channel, {
		"fade_seconds": _finite_non_negative_or_zero(fade_seconds),
		"bus_name": BGM_BUS_NAME,
		"volume_db": 0.0,
		"pitch_scale": 1.0,
	}):
		return

	var request_serial: int = _next_ambient_request_serial(channel)
	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(path))
		_apply_ambient_request(request_serial, channel, stream, BGM_BUS_NAME, 0.0, 1.0, fade_seconds)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_ambient_request(request_serial, channel, _get_audio_stream_value(res), BGM_BUS_NAME, 0.0, 1.0, fade_seconds)
		asset_util.load_async(path, on_loaded)


## 播放资源化环境音配置。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡入秒数。
func play_ambient_clip(
	clip: GFAudioClip,
	channel: StringName = &"default",
	fade_seconds: float = 0.0
) -> void:
	if clip == null or not clip.has_source():
		return

	var request_serial: int = _next_ambient_request_serial(channel)
	var bus_name: String = clip.resolve_bus(BGM_BUS_NAME)
	var volume_db: float = _finite_or_default(clip.volume_db, 0.0)
	var pitch_scale: float = _finite_or_default(clip.resolve_pitch(_audio_rng), 1.0)
	var backend_options: Dictionary = {
		"fade_seconds": _finite_non_negative_or_zero(fade_seconds),
		"bus_name": bus_name,
		"volume_db": volume_db,
		"pitch_scale": pitch_scale,
	}

	if _try_backend_play_ambient_clip(clip, channel, backend_options):
		return

	if clip.stream != null:
		_apply_ambient_request(request_serial, channel, clip.stream, bus_name, volume_db, pitch_scale, fade_seconds)
		return

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(clip.path))
		_apply_ambient_request(request_serial, channel, stream, bus_name, volume_db, pitch_scale, fade_seconds)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_ambient_request(request_serial, channel, _get_audio_stream_value(res), bus_name, volume_db, pitch_scale, fade_seconds)
		asset_util.load_async(clip.path, on_loaded)


## 从音频集合播放环境音。
## [br]
## @api public
## [br]
## @param bank: 音频集合。
## [br]
## @param clip_id: 片段标识。
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡入秒数。
func play_ambient_from_bank(
	bank: GFAudioBank,
	clip_id: StringName,
	channel: StringName = &"default",
	fade_seconds: float = 0.0
) -> void:
	if bank == null:
		return

	play_ambient_clip(bank.get_clip_with_fallback(clip_id, _audio_rng), channel, fade_seconds)


## 按事件 ID 播放注册音频集合中的环境音。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param channel: 环境音通道。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param fade_seconds: 淡入秒数。
func play_ambient_event(
	event_id: StringName,
	channel: StringName = &"default",
	bank_id: StringName = &"",
	fade_seconds: float = 0.0
) -> void:
	play_ambient_clip(_get_registered_clip(event_id, bank_id), channel, fade_seconds)


## 停止指定环境音通道。
## [br]
## @api public
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡出秒数。
func stop_ambient(channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
	_notify_backend_stop_ambient(channel, fade_seconds)
	_invalidate_ambient_request(channel)
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	if player != null:
		_stop_player(player, fade_seconds)


## 停止所有环境音通道。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出秒数。
func stop_all_ambient(fade_seconds: float = 0.0) -> void:
	_notify_backend_stop_all_ambient(fade_seconds)
	var channels: Array = _ambient_players.keys()
	for channel_variant: Variant in channels:
		stop_ambient(GFVariantData.to_string_name(channel_variant), fade_seconds)


## 检查环境音通道是否正在播放。
## [br]
## @api public
## [br]
## @param channel: 环境音通道。
## [br]
## @return: 正在播放时返回 true。
func is_ambient_playing(channel: StringName = &"default") -> bool:
	if _audio_backend != null and _audio_backend.is_ambient_playing(channel):
		return true
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	return is_instance_valid(player) and player.playing


## 停止全部普通 SFX 与空间 SFX。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出秒数。
func stop_all_sfx(fade_seconds: float = 0.0) -> void:
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	_notify_backend_stop_all_sfx(safe_fade)
	_sfx_lifecycle_serial += 1
	_release_all_sfx_players(safe_fade)
	_release_all_spatial_sfx_players(safe_fade)


## 播放 SFX（音效），自动从池中分配播放器
## [br]
## @api public
## [br]
## @param path: 音频资源的路径
func play_sfx(path: String) -> void:
	_forget_audio_handle(play_sfx_handle(path))


## 播放 SFX 并返回控制句柄。
## [br]
## @api public
## [br]
## @param path: 音频资源的路径。
## [br]
## @return: 控制句柄；路径为空时返回 null。
func play_sfx_handle(path: String) -> GFAudioEmitterHandle:
	if path.is_empty():
		return null

	var backend_handle: GFAudioEmitterHandle = _try_backend_play_sfx_path(path, {
		"bus_name": SFX_BUS_NAME,
		"volume_db": 0.0,
		"pitch_scale": 1.0,
	})
	if backend_handle != null:
		return backend_handle

	var handle: GFAudioEmitterHandle = GFAudioEmitterHandle.new()
	var request_serial: int = _sfx_lifecycle_serial
	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(path))
		_apply_sfx_request(request_serial, stream, handle)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_sfx_request(request_serial, _get_audio_stream_value(res), handle)
		asset_util.load_async(path, on_loaded)
	return handle


## 播放资源化 SFX 配置。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
func play_sfx_clip(clip: GFAudioClip) -> void:
	_forget_audio_handle(play_sfx_clip_handle(clip))


## 播放资源化 SFX 配置并返回控制句柄。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @return: 控制句柄；片段无播放来源时返回 null。
func play_sfx_clip_handle(clip: GFAudioClip) -> GFAudioEmitterHandle:
	if clip == null or not clip.has_source():
		return null

	var handle: GFAudioEmitterHandle = GFAudioEmitterHandle.new()
	var request_serial: int = _sfx_lifecycle_serial
	var bus_name: String = clip.resolve_bus(SFX_BUS_NAME)
	var volume_db: float = _finite_or_default(clip.volume_db, 0.0)
	var pitch_scale: float = _finite_or_default(clip.resolve_pitch(_audio_rng), 1.0)
	var backend_handle: GFAudioEmitterHandle = _try_backend_play_sfx_clip(clip, {
		"bus_name": bus_name,
		"volume_db": volume_db,
		"pitch_scale": pitch_scale,
	})
	if backend_handle != null:
		return backend_handle

	if clip.stream != null:
		_apply_sfx_request_with_settings(request_serial, clip.stream, bus_name, volume_db, pitch_scale, handle)
		return handle

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(clip.path))
		_apply_sfx_request_with_settings(request_serial, stream, bus_name, volume_db, pitch_scale, handle)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_sfx_request_with_settings(
				request_serial,
				_get_audio_stream_value(res),
				bus_name,
				volume_db,
				pitch_scale,
				handle
			)
		asset_util.load_async(clip.path, on_loaded)
	return handle


## 从音频集合播放 SFX。
## [br]
## @api public
## [br]
## @param bank: 音频集合。
## [br]
## @param clip_id: 片段标识。
func play_sfx_from_bank(bank: GFAudioBank, clip_id: StringName) -> void:
	_forget_audio_handle(play_sfx_from_bank_handle(bank, clip_id))


## 从音频集合播放 SFX 并返回控制句柄。
## [br]
## @api public
## [br]
## @param bank: 音频集合。
## [br]
## @param clip_id: 片段标识。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_from_bank_handle(bank: GFAudioBank, clip_id: StringName) -> GFAudioEmitterHandle:
	if bank == null:
		return null

	return play_sfx_clip_handle(bank.get_clip_with_fallback(clip_id, _audio_rng))


## 按事件 ID 播放注册音频集合中的 SFX。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
func play_sfx_event(event_id: StringName, bank_id: StringName = &"") -> void:
	_forget_audio_handle(play_sfx_event_handle(event_id, bank_id))


## 按事件 ID 播放注册音频集合中的 SFX 并返回控制句柄。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_event_handle(event_id: StringName, bank_id: StringName = &"") -> GFAudioEmitterHandle:
	return play_sfx_clip_handle(_get_registered_clip(event_id, bank_id))


## 按事件 ID 在 2D 节点位置播放注册音频集合中的 SFX。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param source: 2D 声源节点。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 创建的播放器；无法播放时返回 null。
func play_sfx_event_2d(
	event_id: StringName,
	source: Node2D,
	bank_id: StringName = &"",
	follow_source: bool = false
) -> AudioStreamPlayer2D:
	return play_sfx_clip_2d(_get_registered_clip(event_id, bank_id), source, follow_source)


## 按事件 ID 在 2D 节点位置播放注册音频集合中的 SFX，并返回控制句柄。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param source: 2D 声源节点。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_event_2d_handle(
	event_id: StringName,
	source: Node2D,
	bank_id: StringName = &"",
	follow_source: bool = false
) -> GFAudioEmitterHandle:
	return play_sfx_clip_2d_handle(_get_registered_clip(event_id, bank_id), source, follow_source)


## 按事件 ID 在 3D 节点位置播放注册音频集合中的 SFX。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param source: 3D 声源节点。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 创建的播放器；无法播放时返回 null。
func play_sfx_event_3d(
	event_id: StringName,
	source: Node3D,
	bank_id: StringName = &"",
	follow_source: bool = false
) -> AudioStreamPlayer3D:
	return play_sfx_clip_3d(_get_registered_clip(event_id, bank_id), source, follow_source)


## 按事件 ID 在 3D 节点位置播放注册音频集合中的 SFX，并返回控制句柄。
## [br]
## @api public
## [br]
## @param event_id: 音频事件标识。
## [br]
## @param source: 3D 声源节点。
## [br]
## @param bank_id: 音频集合标识；为空时搜索全部注册集合。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_event_3d_handle(
	event_id: StringName,
	source: Node3D,
	bank_id: StringName = &"",
	follow_source: bool = false
) -> GFAudioEmitterHandle:
	return play_sfx_clip_3d_handle(_get_registered_clip(event_id, bank_id), source, follow_source)


## 在 2D 节点位置播放资源化 SFX 配置。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param source: 2D 声源节点。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 创建的播放器；无法播放时返回 null。
func play_sfx_clip_2d(
	clip: GFAudioClip,
	source: Node2D,
	follow_source: bool = false
) -> AudioStreamPlayer2D:
	var player: Node = _play_spatial_sfx_clip(clip, source, follow_source)
	if player is AudioStreamPlayer2D:
		return player
	return null


## 在 2D 节点位置播放资源化 SFX 配置，并返回控制句柄。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param source: 2D 声源节点。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_clip_2d_handle(
	clip: GFAudioClip,
	source: Node2D,
	follow_source: bool = false
) -> GFAudioEmitterHandle:
	var backend_handle: GFAudioEmitterHandle = _try_backend_play_spatial_sfx_clip(clip, source, follow_source, {
		"space": "2d",
	})
	if backend_handle != null:
		return backend_handle

	var player: Node = _play_spatial_sfx_clip(clip, source, follow_source)
	if player == null or player.is_queued_for_deletion():
		return null
	var handle: GFAudioEmitterHandle = GFAudioEmitterHandle.new()
	_attach_handle_to_playback_session(handle, player, Callable(self, "_release_spatial_sfx_session"))
	if follow_source:
		handle.bind_to_owner(source)
	return handle


## 在 3D 节点位置播放资源化 SFX 配置。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param source: 3D 声源节点。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 创建的播放器；无法播放时返回 null。
func play_sfx_clip_3d(
	clip: GFAudioClip,
	source: Node3D,
	follow_source: bool = false
) -> AudioStreamPlayer3D:
	var player: Node = _play_spatial_sfx_clip(clip, source, follow_source)
	if player is AudioStreamPlayer3D:
		return player
	return null


## 在 3D 节点位置播放资源化 SFX 配置，并返回控制句柄。
## [br]
## @api public
## [br]
## @param clip: 音频片段配置。
## [br]
## @param source: 3D 声源节点。
## [br]
## @param follow_source: 为 true 时播放器会作为 source 子节点跟随移动。
## [br]
## @return: 控制句柄；无法播放时返回 null。
func play_sfx_clip_3d_handle(
	clip: GFAudioClip,
	source: Node3D,
	follow_source: bool = false
) -> GFAudioEmitterHandle:
	var backend_handle: GFAudioEmitterHandle = _try_backend_play_spatial_sfx_clip(clip, source, follow_source, {
		"space": "3d",
	})
	if backend_handle != null:
		return backend_handle

	var player: Node = _play_spatial_sfx_clip(clip, source, follow_source)
	if player == null or player.is_queued_for_deletion():
		return null
	var handle: GFAudioEmitterHandle = GFAudioEmitterHandle.new()
	_attach_handle_to_playback_session(handle, player, Callable(self, "_release_spatial_sfx_session"))
	if follow_source:
		handle.bind_to_owner(source)
	return handle


## 获取环境音通道的控制句柄。
## [br]
## @api public
## [br]
## @param channel: 环境音通道。
## [br]
## @return: 控制句柄；通道不存在时返回 null。
func get_ambient_handle(channel: StringName = &"default") -> GFAudioEmitterHandle:
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	if not is_instance_valid(player):
		return null
	return GFAudioEmitterHandle.new(player, Callable(self, "_stop_audio_player"), channel)


## 设置音频总线 dB 音量。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称，如 "Master", "BGM", "SFX"。
## [br]
## @param volume_db: 目标 dB 音量；小于等于 SILENCE_VOLUME_DB 时会静音该总线。
## [br]
## @param transition_seconds: 平滑过渡秒数；小于等于 0 时立即应用。
## [br]
## @return: 成功应用或已交给后端处理时返回 true。
func set_bus_volume_db(bus_name: String, volume_db: float, transition_seconds: float = 0.0) -> bool:
	if not _is_finite_float(volume_db) or not _is_finite_float(transition_seconds):
		return false
	if _audio_backend != null and _audio_backend.set_bus_volume_db(bus_name, volume_db, transition_seconds):
		return true

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[GFAudioUtility] 无法找到音轨总线: " + bus_name)
		return false

	var target_db: float = maxf(volume_db, SILENCE_VOLUME_DB)
	_kill_bus_volume_tween(bus_name)
	if transition_seconds <= 0.0:
		_apply_bus_volume_db(bus_index, target_db)
		return true

	if target_db > SILENCE_VOLUME_DB:
		AudioServer.set_bus_mute(bus_index, false)

	var start_db: float = SILENCE_VOLUME_DB if AudioServer.is_bus_mute(bus_index) else AudioServer.get_bus_volume_db(bus_index)
	var tween: Tween = _create_tween_or_null()
	if tween == null:
		_apply_bus_volume_db(bus_index, target_db)
		return true

	_bus_volume_tween_refs[bus_name] = weakref(tween)
	_add_tween_method(
		tween,
		Callable(self, "_apply_bus_volume_tween_value").bind(bus_name),
		start_db,
		target_db,
		maxf(transition_seconds, 0.0)
	)
	_connect_signal_checked(
		tween.finished,
		Callable(self, "_finish_bus_volume_tween").bind(bus_name, target_db),
		CONNECT_ONE_SHOT
	)
	return true


## 获取音频总线 dB 音量。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @return: dB 音量；总线不存在时返回 SILENCE_VOLUME_DB。
func get_bus_volume_db(bus_name: String) -> float:
	if _audio_backend != null:
		var backend_volume: float = _audio_backend.get_bus_volume(bus_name)
		if backend_volume >= 0.0:
			return linear_to_db(maxf(backend_volume, 0.000001))

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return SILENCE_VOLUME_DB
	return AudioServer.get_bus_volume_db(bus_index)


## 设置音频总线静音状态。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @param muted: 是否静音。
## [br]
## @return: 成功应用或已交给后端处理时返回 true。
func set_bus_mute(bus_name: String, muted: bool) -> bool:
	if _audio_backend != null and _audio_backend.set_bus_mute(bus_name, muted):
		return true

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[GFAudioUtility] 无法找到音轨总线: " + bus_name)
		return false
	AudioServer.set_bus_mute(bus_index, muted)
	return true


## 设置音频总线效果属性。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @param effect_ref: 效果索引、resource_name、类名或类名片段。
## [br]
## @schema effect_ref: int 表示效果索引；String/StringName 会匹配效果 resource_name、get_class() 或类名片段。
## [br]
## @param property_name: 要写入的效果属性名。
## [br]
## @param value: 目标属性值。
## [br]
## @schema value: 目标属性值；数值属性可按 transition_seconds 平滑过渡，其他类型会立即应用。
## [br]
## @param transition_seconds: 平滑过渡秒数；小于等于 0 时立即应用。
## [br]
## @return: 成功应用或已交给后端处理时返回 true。
func set_bus_effect_property(
	bus_name: String,
	effect_ref: Variant,
	property_name: StringName,
	value: Variant,
	transition_seconds: float = 0.0
) -> bool:
	if not _is_finite_float(transition_seconds):
		return false
	if _is_numeric_variant(value) and not _is_finite_numeric_variant(value):
		return false
	if (
		_audio_backend != null
		and _audio_backend.set_bus_effect_property(bus_name, effect_ref, property_name, value, transition_seconds)
	):
		return true

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[GFAudioUtility] 无法找到音轨总线: " + bus_name)
		return false
	var effect_index: int = _resolve_bus_effect_index(bus_index, effect_ref)
	if effect_index < 0:
		push_warning("[GFAudioUtility] 无法在总线 %s 找到音频效果: %s" % [bus_name, str(effect_ref)])
		return false
	var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
	if effect == null or not _object_has_property(effect, property_name):
		push_warning("[GFAudioUtility] 音频效果缺少属性: %s.%s" % [str(effect_ref), String(property_name)])
		return false

	var tween_key: String = "%s:%d:%s" % [bus_name, effect_index, String(property_name)]
	_kill_bus_effect_tween(tween_key)
	if transition_seconds <= 0.0 or not _is_numeric_variant(value):
		effect.set(String(property_name), value)
		return true

	var start_value: Variant = _get_object_property(effect, property_name)
	if not _is_numeric_variant(start_value):
		effect.set(String(property_name), value)
		return true

	var tween: Tween = _create_tween_or_null()
	if tween == null:
		effect.set(String(property_name), value)
		return true

	_bus_effect_tween_refs[tween_key] = weakref(tween)
	_add_tween_method(
		tween,
		Callable(self, "_apply_bus_effect_tween_value").bind(effect, property_name),
		GFVariantData.to_float(start_value),
		GFVariantData.to_float(value),
		maxf(transition_seconds, 0.0)
	)
	_connect_signal_checked(
		tween.finished,
		Callable(self, "_finish_bus_effect_tween").bind(tween_key, effect, property_name, value),
		CONNECT_ONE_SHOT
	)
	return true


## 捕获当前总线混音快照。
## [br]
## @api public
## [br]
## @param bus_names: 要捕获的总线名；为空时捕获全部 Godot 总线。
## [br]
## @return: 混音快照。
## [br]
## @schema return: Dictionary，包含 buses 字典；每个总线条目包含 volume_db、volume_linear 和 muted。
func capture_mix_snapshot(bus_names: PackedStringArray = PackedStringArray()) -> Dictionary:
	var names: PackedStringArray = bus_names
	if names.is_empty():
		names = PackedStringArray()
		for bus_index: int in range(AudioServer.get_bus_count()):
			_append_packed_string(names, AudioServer.get_bus_name(bus_index))

	var buses: Dictionary = {}
	for bus_name: String in names:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		var muted: bool = AudioServer.is_bus_mute(bus_index)
		var volume_db: float = SILENCE_VOLUME_DB if muted else AudioServer.get_bus_volume_db(bus_index)
		buses[bus_name] = {
			"volume_db": volume_db,
			"volume_linear": 0.0 if muted else db_to_linear(volume_db),
			"muted": muted,
		}
	return {
		_MIX_SNAPSHOT_BUSES_KEY: buses,
	}


## 应用混音快照。
## [br]
## @api public
## [br]
## @param snapshot: 混音快照。
## [br]
## @schema snapshot: Dictionary，可包含 buses 字典和 effects 数组；buses 条目支持 volume_db、volume_linear、muted，effects 条目支持 bus、effect、property、value、transition_seconds。
## [br]
## @param transition_seconds: 默认平滑过渡秒数；单个效果条目可覆盖。
## [br]
## @return: 应用报告。
## [br]
## @schema return: Dictionary，包含 ok、applied、failed 和 warnings 字段。
func apply_mix_snapshot(snapshot: Dictionary, transition_seconds: float = 0.0) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"applied": PackedStringArray(),
		"failed": [],
		"warnings": [],
	}
	if not _is_finite_float(transition_seconds):
		_append_mix_failure(report, "", "non_finite_transition", "混音快照过渡时间必须是有限值。")
		report["ok"] = false
		return report
	if _audio_backend != null and _audio_backend.apply_mix_snapshot(snapshot, transition_seconds):
		return {
			"ok": true,
			"applied": PackedStringArray(["backend"]),
			"failed": [],
			"warnings": [],
		}

	_apply_mix_snapshot_buses(GFVariantData.get_option_value(snapshot, _MIX_SNAPSHOT_BUSES_KEY, {}), transition_seconds, report)
	_apply_mix_snapshot_effects(GFVariantData.get_option_value(snapshot, _MIX_SNAPSHOT_EFFECTS_KEY, []), transition_seconds, report)
	report["ok"] = _get_report_array(report, "failed").is_empty()
	return report


## 按比例压低总线音量，并记住恢复基准。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @param amount: 压低强度，0.0 不变化，1.0 最多压低 18 dB。
## [br]
## @param transition_seconds: 平滑过渡秒数。
## [br]
## @param duck_id: 同一总线上的压低作用域标识。
## [br]
## @return: 成功应用时返回 true。
func duck_bus(
	bus_name: String = BGM_BUS_NAME,
	amount: float = 0.5,
	transition_seconds: float = 0.25,
	duck_id: StringName = &"default"
) -> bool:
	var duck_key: String = _make_duck_key(bus_name, duck_id)
	var recorded_base: bool = false
	if not _duck_base_bus_volumes_db.has(duck_key):
		_duck_base_bus_volumes_db[duck_key] = get_bus_volume_db(bus_name)
		recorded_base = true
	var base_db: float = GFVariantData.to_float(_duck_base_bus_volumes_db[duck_key])
	var target_db: float = base_db - clampf(amount, 0.0, 1.0) * 18.0
	if set_bus_volume_db(bus_name, target_db, transition_seconds):
		return true
	if recorded_base:
		_erase_dictionary_key(_duck_base_bus_volumes_db, duck_key)
	return false


## 恢复被 duck_bus() 压低的总线。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @param transition_seconds: 平滑过渡秒数。
## [br]
## @param duck_id: 同一总线上的压低作用域标识。
## [br]
## @return: 找到恢复基准并开始恢复时返回 true。
func restore_ducked_bus(
	bus_name: String = BGM_BUS_NAME,
	transition_seconds: float = 0.25,
	duck_id: StringName = &"default"
) -> bool:
	var duck_key: String = _make_duck_key(bus_name, duck_id)
	if not _duck_base_bus_volumes_db.has(duck_key):
		return false
	var base_db: float = GFVariantData.to_float(_duck_base_bus_volumes_db[duck_key])
	_erase_dictionary_key(_duck_base_bus_volumes_db, duck_key)
	return set_bus_volume_db(bus_name, base_db, transition_seconds)


## 设置音频总线音量
## [br]
## @api public
## [br]
## @param bus_name: 总线名称，如 "Master", "BGM", "SFX"
## [br]
## @param volume_linear: 线性音量 (0.0 到 1.0)
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	if not _is_finite_float(volume_linear):
		return
	if _audio_backend != null and _audio_backend.set_bus_volume(bus_name, volume_linear):
		return

	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		_kill_bus_volume_tween(bus_name)
		if volume_linear <= 0.0:
			_apply_bus_volume_db(bus_idx, SILENCE_VOLUME_DB)
			return
		var db: float = linear_to_db(minf(volume_linear, 1.0))
		_apply_bus_volume_db(bus_idx, db)
	else:
		push_warning("[GFAudioUtility] 无法找到音轨总线: " + bus_name)


## 获取音频总线音量
## [br]
## @api public
## [br]
## @param bus_name: 总线名称
## [br]
## @return: 线性音量 (0.0 到 1.0)
func get_bus_volume(bus_name: String) -> float:
	if _audio_backend != null:
		var backend_volume: float = _audio_backend.get_bus_volume(bus_name)
		if backend_volume >= 0.0:
			return backend_volume

	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if AudioServer.is_bus_mute(bus_idx):
			return 0.0
		return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	return 0.0


## 获取音频工具调试快照。
## [br]
## @api public
## [br]
## @return: 调试快照。
## [br]
## @schema return: Dictionary，包含 backend、backend_snapshot、backend_capabilities、current_bgm_key、current_bgm_loop、bgm_paused、bgm_position、bgm_history、active_sfx_count、active_spatial_sfx_count、max_sfx_players、ambient_channels、audio_bank_count、ducked_bus_count 和 active_mix_tween_count 字段。
func get_debug_snapshot() -> Dictionary:
	_prune_inactive_sfx_players()
	_prune_inactive_spatial_sfx_players()
	var ambient_channels: PackedStringArray = PackedStringArray()
	for channel_variant: Variant in _ambient_players.keys():
		var channel: String = GFVariantData.to_text(channel_variant)
		if is_ambient_playing(StringName(channel)):
			_append_packed_string(ambient_channels, channel)
	ambient_channels.sort()

	var backend_snapshot: Dictionary = {}
	var backend_capabilities: Dictionary = {}
	var backend_name: String = ""
	if _audio_backend != null:
		var backend_script: Script = _get_script_value(_audio_backend.get_script())
		backend_name = backend_script.resource_path if backend_script != null else _audio_backend.get_class()
		backend_snapshot = _audio_backend.get_debug_snapshot()
		backend_capabilities = _audio_backend.get_capabilities().to_dictionary()

	return {
		"backend": backend_name,
		"backend_snapshot": backend_snapshot,
		"backend_capabilities": backend_capabilities,
		"current_bgm_key": _current_bgm_key,
		"current_bgm_loop": _current_bgm_loop,
		"bgm_paused": is_bgm_paused(),
		"bgm_position": get_bgm_playback_position(),
		"bgm_history": get_bgm_history(),
		"active_sfx_count": _active_sfx_players.size(),
		"active_spatial_sfx_count": _active_spatial_sfx_players.size(),
		"max_sfx_players": max_sfx_players,
		"ambient_channels": ambient_channels,
		"audio_bank_count": _audio_banks.size(),
		"ducked_bus_count": _duck_base_bus_volumes_db.size(),
		"active_mix_tween_count": _bus_volume_tween_refs.size() + _bus_effect_tween_refs.size(),
	}


# --- 私有/辅助方法 ---

func _pack_scene_template(scene: PackedScene, template: Node) -> void:
	var error: Error = scene.pack(template)
	if error != OK:
		push_error("[GFAudioUtility] 创建播放器模板场景失败：%s" % error_string(error))


func _connect_signal_checked(source_signal: Signal, callback: Callable, flags: int = 0) -> void:
	if source_signal.is_null():
		push_warning("[GFAudioUtility] Signal 连接失败：Signal 为空。")
		return
	if not callback.is_valid():
		push_warning("[GFAudioUtility] Signal 连接失败：Callable 无效。")
		return
	if source_signal.is_connected(callback):
		return

	var error: Error = source_signal.connect(callback, flags as Object.ConnectFlags) as Error
	if error != OK:
		push_warning("[GFAudioUtility] Signal 连接失败：%s" % error_string(error))


func _notify_backend_stop_bgm(fade_seconds: float) -> void:
	if _audio_backend == null:
		return
	var handled: bool = _audio_backend.stop_bgm(_finite_non_negative_or_zero(fade_seconds))
	if handled:
		return


func _notify_backend_stop_ambient(channel: StringName, fade_seconds: float) -> void:
	if _audio_backend == null:
		return
	var handled: bool = _audio_backend.stop_ambient(channel, _finite_non_negative_or_zero(fade_seconds))
	if handled:
		return


func _notify_backend_stop_all_ambient(fade_seconds: float) -> void:
	if _audio_backend == null:
		return
	var handled: bool = _audio_backend.stop_all_ambient(_finite_non_negative_or_zero(fade_seconds))
	if handled:
		return


func _notify_backend_stop_all_sfx(fade_seconds: float) -> void:
	if _audio_backend == null:
		return
	var handled: bool = _audio_backend.stop_all_sfx(_finite_non_negative_or_zero(fade_seconds))
	if handled:
		return


func _invalidate_ambient_request(channel: StringName) -> void:
	var serial: int = _next_ambient_request_serial(channel)
	if serial <= 0:
		return


func _forget_audio_handle(handle: GFAudioEmitterHandle) -> void:
	if handle == null:
		return


func _forget_tween(tween: Tween) -> void:
	if tween == null:
		return


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var removed: bool = target.erase(key)
	if removed:
		return


func _append_array_item(target: Array, value: Variant) -> void:
	target.append(value)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop
	return tree


func _get_audio_bank_mount_stack(bank_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_audio_bank_mount_stacks, bank_id, []))


func _get_mount_entry_token(entry: Dictionary) -> int:
	return GFVariantData.get_option_int(entry, "token", 0)


func _get_mount_entry_restore_previous(entry: Dictionary) -> bool:
	return GFVariantData.get_option_bool(entry, "restore_previous_bank", true)


func _get_audio_bank_by_id(bank_id: StringName) -> GFAudioBank:
	return _get_audio_bank_value(GFVariantData.get_option_value(_audio_banks, bank_id))


func _get_ambient_player(channel: StringName) -> AudioStreamPlayer:
	return _get_audio_stream_player_value(GFVariantData.get_option_value(_ambient_players, channel))


func _get_report_array(report: Dictionary, key: Variant) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(report, key, []))


func _get_ambient_request_serial(channel: StringName) -> int:
	return GFVariantData.get_option_int(_ambient_request_serials, channel, 0)


func _get_object_property(object: Object, property_name: StringName, default_value: Variant = null) -> Variant:
	if object == null or property_name == &"":
		return default_value
	var value: Variant = object.get_indexed(NodePath(String(property_name)))
	return default_value if value == null else value


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	return PackedStringArray()


func _get_audio_stream_value(value: Variant) -> AudioStream:
	if value is AudioStream:
		return value
	return null


func _get_audio_bank_value(value: Variant) -> GFAudioBank:
	if value is GFAudioBank:
		return value
	return null


func _get_audio_stream_player_value(value: Variant) -> AudioStreamPlayer:
	if value is AudioStreamPlayer:
		return value
	return null


func _get_weak_ref_value(value: Variant) -> WeakRef:
	if value is WeakRef:
		return value
	return null


func _get_tween_value(value: Variant) -> Tween:
	if value is Tween:
		return value
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _add_tween_method(
	tween: Tween,
	method: Callable,
	from_value: Variant,
	to_value: Variant,
	duration_seconds: float
) -> void:
	if tween == null or not method.is_valid() or not _is_finite_float(duration_seconds):
		return
	var tweener: Variant = tween.tween_method(method, from_value, to_value, maxf(duration_seconds, 0.0))
	if tweener == null:
		push_warning("[GFAudioUtility] Tween 方法步骤创建失败。")


func _add_tween_property(
	tween: Tween,
	target: Object,
	property_name: String,
	final_value: Variant,
	duration_seconds: float
) -> void:
	if tween == null or target == null or not _is_finite_float(duration_seconds):
		return
	var tweener: Variant = tween.tween_property(
		target,
		NodePath(property_name),
		final_value,
		maxf(duration_seconds, 0.0)
	)
	if tweener == null:
		push_warning("[GFAudioUtility] Tween 属性步骤创建失败。")


func _add_tween_callback(tween: Tween, callback: Callable) -> void:
	if tween == null or not callback.is_valid():
		return
	var tweener: Variant = tween.tween_callback(callback)
	if tweener == null:
		push_warning("[GFAudioUtility] Tween 回调步骤创建失败。")


func _apply_bus_volume_db(bus_index: int, volume_db: float) -> void:
	if bus_index < 0 or not _is_finite_float(volume_db):
		return
	var target_db: float = maxf(volume_db, SILENCE_VOLUME_DB)
	AudioServer.set_bus_volume_db(bus_index, target_db)
	AudioServer.set_bus_mute(bus_index, target_db <= SILENCE_VOLUME_DB)


func _apply_bus_volume_tween_value(value: float, bus_name: String) -> void:
	if not _is_finite_float(value):
		return
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, value)


func _finish_bus_volume_tween(bus_name: String, target_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		_apply_bus_volume_db(bus_index, target_db)
	_erase_dictionary_key(_bus_volume_tween_refs, bus_name)


func _apply_bus_effect_tween_value(value: float, effect: Object, property_name: StringName) -> void:
	if effect != null and _is_finite_float(value):
		effect.set(String(property_name), value)


func _finish_bus_effect_tween(
	tween_key: String,
	effect: Object,
	property_name: StringName,
	value: Variant
) -> void:
	if effect != null:
		effect.set(String(property_name), value)
	_erase_dictionary_key(_bus_effect_tween_refs, tween_key)


func _clear_mix_control_tweens() -> void:
	for tween_ref: WeakRef in _bus_volume_tween_refs.values():
		_kill_tween_ref(tween_ref)
	for tween_ref: WeakRef in _bus_effect_tween_refs.values():
		_kill_tween_ref(tween_ref)
	_bus_volume_tween_refs.clear()
	_bus_effect_tween_refs.clear()


func _kill_bus_volume_tween(bus_name: String) -> void:
	if not _bus_volume_tween_refs.has(bus_name):
		return
	_kill_tween_ref(_get_weak_ref_value(_bus_volume_tween_refs[bus_name]))
	_erase_dictionary_key(_bus_volume_tween_refs, bus_name)


func _kill_bus_effect_tween(tween_key: String) -> void:
	if not _bus_effect_tween_refs.has(tween_key):
		return
	_kill_tween_ref(_get_weak_ref_value(_bus_effect_tween_refs[tween_key]))
	_erase_dictionary_key(_bus_effect_tween_refs, tween_key)


func _resolve_bus_effect_index(bus_index: int, effect_ref: Variant) -> int:
	if typeof(effect_ref) == TYPE_INT:
		var index: int = GFVariantData.to_int(effect_ref, -1)
		return index if index >= 0 and index < AudioServer.get_bus_effect_count(bus_index) else -1

	var expected: String = _normalize_effect_match_text(str(effect_ref))
	if expected.is_empty():
		return -1
	for index: int in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, index)
		if _effect_matches_ref(effect, expected):
			return index
	return -1


func _effect_matches_ref(effect: Object, expected: String) -> bool:
	if effect == null:
		return false
	var names: PackedStringArray = PackedStringArray()
	_append_packed_string(names, _normalize_effect_match_text(effect.get_class()))
	if effect is Resource:
		var resource: Resource = effect
		_append_packed_string(names, _normalize_effect_match_text(resource.resource_name))
	for effect_name: String in names:
		if effect_name == expected or (not expected.is_empty() and effect_name.find(expected) >= 0):
			return true
	return false


func _normalize_effect_match_text(value: String) -> String:
	return value.to_lower().replace("audioeffect", "").replace("filter", "").replace("_", "").replace(" ", "")


func _object_has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property: Dictionary in object.get_property_list():
		if GFVariantData.get_option_string_name(property, "name", &"") == property_name:
			return true
	return false


func _is_numeric_variant(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


func _is_finite_numeric_variant(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var float_value: float = value
		return _is_finite_float(float_value)
	return false


func _finite_or_default(value: float, default_value: float) -> float:
	return value if _is_finite_float(value) else default_value


func _finite_non_negative_or_zero(value: float) -> float:
	return maxf(value, 0.0) if _is_finite_float(value) else 0.0


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _apply_mix_snapshot_buses(bus_payload: Variant, transition_seconds: float, report: Dictionary) -> void:
	if not (bus_payload is Dictionary):
		if bus_payload != null:
			_append_mix_warning(report, "buses 字段必须是 Dictionary。")
		return

	var buses: Dictionary = GFVariantData.as_dictionary(bus_payload)
	for bus_key: Variant in buses.keys():
		var bus_name: String = str(bus_key)
		var bus_entry: Variant = buses[bus_key]
		if bus_entry is Dictionary:
			_apply_mix_snapshot_bus_entry(bus_name, GFVariantData.as_dictionary(bus_entry), transition_seconds, report)
		elif _is_numeric_variant(bus_entry):
			if _apply_mix_snapshot_bus_volume_db(bus_name, GFVariantData.to_float(bus_entry), transition_seconds, report):
				continue
		else:
			_append_mix_failure(report, bus_name, "invalid_bus_entry", "总线快照条目必须是 Dictionary 或数值。")


func _apply_mix_snapshot_bus_entry(
	bus_name: String,
	entry: Dictionary,
	transition_seconds: float,
	report: Dictionary
) -> void:
	var entry_transition: float = GFVariantData.get_option_float(entry, "transition_seconds", transition_seconds)
	var applied_any: bool = false
	if not _is_finite_float(entry_transition):
		_append_mix_failure(report, bus_name, "non_finite_transition", "总线过渡时间必须是有限值。")
		return
	if entry.has("volume_db"):
		var volume_db: float = GFVariantData.to_float(entry["volume_db"])
		if not _is_finite_float(volume_db):
			_append_mix_failure(report, bus_name, "non_finite_volume", "总线音量必须是有限值。")
		else:
			applied_any = _apply_mix_snapshot_bus_volume_db(bus_name, volume_db, entry_transition, report) or applied_any
	elif entry.has("volume_linear"):
		var linear_volume: float = GFVariantData.to_float(entry["volume_linear"])
		if not _is_finite_float(linear_volume):
			_append_mix_failure(report, bus_name, "non_finite_volume", "线性总线音量必须是有限值。")
		else:
			linear_volume = maxf(linear_volume, 0.0)
			var db: float = SILENCE_VOLUME_DB if linear_volume <= 0.0 else linear_to_db(linear_volume)
			applied_any = _apply_mix_snapshot_bus_volume_db(bus_name, db, entry_transition, report) or applied_any

	if entry.has("muted"):
		if set_bus_mute(bus_name, GFVariantData.to_bool(entry["muted"])):
			_append_mix_applied(report, "bus:%s:muted" % bus_name)
			applied_any = true
		else:
			_append_mix_failure(report, bus_name, "missing_bus", "无法设置总线静音状态。")

	if not applied_any:
		_append_mix_warning(report, "总线 %s 的快照条目没有可应用字段。" % bus_name)


func _apply_mix_snapshot_bus_volume_db(
	bus_name: String,
	volume_db: float,
	transition_seconds: float,
	report: Dictionary
) -> bool:
	if set_bus_volume_db(bus_name, volume_db, transition_seconds):
		_append_mix_applied(report, "bus:%s:volume_db" % bus_name)
		return true
	_append_mix_failure(report, bus_name, "missing_bus", "无法设置总线音量。")
	return false


func _apply_mix_snapshot_effects(effect_payload: Variant, transition_seconds: float, report: Dictionary) -> void:
	if effect_payload == null:
		return
	if effect_payload is Array:
		var effect_entries: Array = GFVariantData.as_array(effect_payload)
		for entry: Variant in effect_entries:
			if entry is Dictionary:
				_apply_mix_snapshot_effect_entry(GFVariantData.as_dictionary(entry), transition_seconds, report)
			else:
				_append_mix_failure(report, "", "invalid_effect_entry", "effects 数组元素必须是 Dictionary。")
		return
	if effect_payload is Dictionary:
		var effect_map: Dictionary = GFVariantData.as_dictionary(effect_payload)
		for bus_key: Variant in effect_map.keys():
			var bus_effects: Variant = effect_map[bus_key]
			if bus_effects is Array:
				var bus_effect_entries: Array = GFVariantData.as_array(bus_effects)
				for entry: Variant in bus_effect_entries:
					if entry is Dictionary:
						var effect_entry: Dictionary = GFVariantData.as_dictionary(entry).duplicate(true)
						effect_entry["bus"] = str(bus_key)
						_apply_mix_snapshot_effect_entry(effect_entry, transition_seconds, report)
			elif bus_effects is Dictionary:
				var single_entry: Dictionary = GFVariantData.as_dictionary(bus_effects).duplicate(true)
				single_entry["bus"] = str(bus_key)
				_apply_mix_snapshot_effect_entry(single_entry, transition_seconds, report)
		return
	_append_mix_warning(report, "effects 字段必须是 Array 或 Dictionary。")


func _apply_mix_snapshot_effect_entry(entry: Dictionary, transition_seconds: float, report: Dictionary) -> void:
	var bus_name: String = GFVariantData.get_option_string(entry, "bus", "")
	var property_name: StringName = GFVariantData.get_option_string_name(entry, "property", &"")
	if bus_name.is_empty() or property_name == &"" or not entry.has("value"):
		_append_mix_failure(report, bus_name, "invalid_effect_entry", "效果条目必须包含 bus、property 和 value。")
		return
	var effect_ref: Variant = GFVariantData.get_option_value(entry, "effect", 0)
	var entry_transition: float = GFVariantData.get_option_float(entry, "transition_seconds", transition_seconds)
	if not _is_finite_float(entry_transition):
		_append_mix_failure(report, bus_name, "non_finite_transition", "效果过渡时间必须是有限值。")
		return
	if _is_numeric_variant(entry["value"]) and not _is_finite_numeric_variant(entry["value"]):
		_append_mix_failure(report, bus_name, "non_finite_effect_value", "效果数值必须是有限值。")
		return
	if set_bus_effect_property(bus_name, effect_ref, property_name, entry["value"], entry_transition):
		_append_mix_applied(report, "effect:%s:%s:%s" % [bus_name, str(effect_ref), String(property_name)])
	else:
		_append_mix_failure(report, bus_name, "effect_failed", "无法设置效果属性。")


func _append_mix_applied(report: Dictionary, value: String) -> void:
	var applied: PackedStringArray = _get_packed_string_array_value(
		GFVariantData.get_option_value(report, "applied", PackedStringArray())
	)
	_append_packed_string(applied, value)
	report["applied"] = applied


func _append_mix_warning(report: Dictionary, message: String) -> void:
	var warnings: Array = _get_report_array(report, "warnings")
	_append_array_item(warnings, message)
	report["warnings"] = warnings


func _append_mix_failure(report: Dictionary, bus_name: String, reason: String, message: String) -> void:
	var failed: Array = _get_report_array(report, "failed")
	_append_array_item(failed, {
		"bus": bus_name,
		"reason": reason,
		"message": message,
	})
	report["failed"] = failed


func _make_duck_key(bus_name: String, duck_id: StringName) -> String:
	return "%s:%s" % [bus_name, String(duck_id)]


func _clear_audio_backend(dispose_backend: bool) -> void:
	if _audio_backend == null:
		return
	if dispose_backend:
		_audio_backend.dispose()
	_audio_backend = null


func _restore_audio_bank_after_unmount(
	bank_id: StringName,
	stack: Array,
	restore_previous_bank: bool
) -> void:
	if not restore_previous_bank:
		_erase_dictionary_key(_audio_banks, bank_id)
		return
	if not stack.is_empty():
		var top_entry: Dictionary = GFVariantData.as_dictionary(stack[stack.size() - 1])
		var top_bank: GFAudioBank = _get_audio_bank_value(GFVariantData.get_option_value(top_entry, "bank"))
		if top_bank != null:
			_audio_banks[bank_id] = top_bank
			return
	if _audio_bank_base_values.has(bank_id):
		var base_bank: GFAudioBank = _get_audio_bank_value(_audio_bank_base_values[bank_id])
		if base_bank != null:
			_audio_banks[bank_id] = base_bank
			return
	_erase_dictionary_key(_audio_banks, bank_id)


func _try_backend_play_bgm_path(path: String, options: Dictionary) -> bool:
	if _audio_backend == null:
		return false
	if not _audio_backend.can_handle_path(path, &"bgm", options):
		return false
	return _audio_backend.play_bgm_path(path, options)


func _try_backend_play_bgm_clip(clip: GFAudioClip, options: Dictionary) -> bool:
	if _audio_backend == null:
		return false
	if not _audio_backend.can_handle_clip(clip, &"bgm", options):
		return false
	return _audio_backend.play_bgm_clip(clip, options)


func _try_backend_play_ambient_path(path: String, channel: StringName, options: Dictionary) -> bool:
	if _audio_backend == null:
		return false
	var context: Dictionary = options.duplicate(true)
	context["ambient_channel"] = channel
	if not _audio_backend.can_handle_path(path, &"ambient", context):
		return false
	return _audio_backend.play_ambient_path(path, channel, options)


func _try_backend_play_ambient_clip(clip: GFAudioClip, channel: StringName, options: Dictionary) -> bool:
	if _audio_backend == null:
		return false
	var context: Dictionary = options.duplicate(true)
	context["ambient_channel"] = channel
	if not _audio_backend.can_handle_clip(clip, &"ambient", context):
		return false
	return _audio_backend.play_ambient_clip(clip, channel, options)


func _try_backend_play_sfx_path(path: String, options: Dictionary) -> GFAudioEmitterHandle:
	if _audio_backend == null:
		return null
	if not _audio_backend.can_handle_path(path, &"sfx", options):
		return null
	return _audio_backend.play_sfx_path(path, options)


func _try_backend_play_sfx_clip(clip: GFAudioClip, options: Dictionary) -> GFAudioEmitterHandle:
	if _audio_backend == null:
		return null
	if not _audio_backend.can_handle_clip(clip, &"sfx", options):
		return null
	return _audio_backend.play_sfx_clip(clip, options)


func _try_backend_play_spatial_sfx_clip(
	clip: GFAudioClip,
	source: Node,
	follow_source: bool,
	options: Dictionary
) -> GFAudioEmitterHandle:
	if _audio_backend == null:
		return null
	var context: Dictionary = options.duplicate(true)
	context["follow_source"] = follow_source
	context["source"] = source
	context["spatial_settings"] = _get_clip_spatial_settings(clip)
	if not _audio_backend.can_handle_clip(clip, &"spatial_sfx", context):
		return null
	return _audio_backend.play_spatial_sfx_clip(clip, source, follow_source, context)


func _post_bgm_event(event: GFAudioEvent, options: Dictionary) -> void:
	var fade_seconds: float = GFVariantData.get_option_float(options, "fade_seconds", 0.0)
	if event.clip != null:
		play_bgm_clip(event.clip, fade_seconds)
	elif event.event_id != &"":
		play_bgm_event(event.event_id, event.bank_id, fade_seconds)
	elif not event.path.is_empty():
		play_bgm(event.path, fade_seconds)


func _post_ambient_event(event: GFAudioEvent, options: Dictionary) -> void:
	var fade_seconds: float = GFVariantData.get_option_float(options, "fade_seconds", 0.0)
	if event.clip != null:
		play_ambient_clip(event.clip, event.ambient_channel, fade_seconds)
	elif event.event_id != &"":
		play_ambient_event(event.event_id, event.ambient_channel, event.bank_id, fade_seconds)
	elif not event.path.is_empty():
		play_ambient(event.path, event.ambient_channel, fade_seconds)


func _post_sfx_event(event: GFAudioEvent) -> GFAudioEmitterHandle:
	if event.clip != null:
		return play_sfx_clip_handle(event.clip)
	if event.event_id != &"":
		return play_sfx_event_handle(event.event_id, event.bank_id)
	if not event.path.is_empty():
		return play_sfx_handle(event.path)
	return null


func _post_spatial_sfx_event(event: GFAudioEvent, options: Dictionary) -> GFAudioEmitterHandle:
	var source: Node = _get_node_option(options, "source")
	if source == null:
		return null

	var follow_source: bool = GFVariantData.get_option_bool(options, "follow_source", false)
	if event.clip != null:
		return _play_spatial_sfx_event_clip(event.clip, source, follow_source)
	if event.event_id != &"":
		return _play_spatial_sfx_event_clip(_get_registered_clip(event.event_id, event.bank_id), source, follow_source)
	if event.path.is_empty():
		return null

	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = event.path
	return _play_spatial_sfx_event_clip(clip, source, follow_source)


func _play_spatial_sfx_event_clip(clip: GFAudioClip, source: Node, follow_source: bool) -> GFAudioEmitterHandle:
	if source is Node2D:
		var source_2d: Node2D = source
		return play_sfx_clip_2d_handle(clip, source_2d, follow_source)
	if source is Node3D:
		var source_3d: Node3D = source
		return play_sfx_clip_3d_handle(clip, source_3d, follow_source)
	return null


func _get_node_option(options: Dictionary, key: Variant) -> Node:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Node:
		var node: Node = value
		return node
	return null


func _get_registered_clip(event_id: StringName, bank_id: StringName = &"") -> GFAudioClip:
	if event_id == &"":
		return null
	if bank_id != &"":
		var bank: GFAudioBank = get_audio_bank(bank_id)
		return bank.get_clip_with_fallback(event_id, _audio_rng) if bank != null else null

	var bank_ids: PackedStringArray = PackedStringArray()
	for key: Variant in _audio_banks.keys():
		_append_packed_string(bank_ids, GFVariantData.to_text(key))
	bank_ids.sort()
	for key_text: String in bank_ids:
		var bank: GFAudioBank = _get_audio_bank_by_id(StringName(key_text))
		if bank == null:
			continue
		var clip: GFAudioClip = bank.get_clip_with_fallback(event_id, _audio_rng)
		if clip != null:
			return clip
	return null


func _play_spatial_sfx_clip(clip: GFAudioClip, source: Node, follow_source: bool = false) -> Node:
	if clip == null or not clip.has_source() or not is_instance_valid(source):
		return null

	var parent: Node = source if follow_source else _get_spatial_sfx_parent(source)
	if parent == null:
		return null

	var player: Node = null
	if source is Node3D:
		player = AudioStreamPlayer3D.new()
	elif source is Node2D:
		player = AudioStreamPlayer2D.new()
	else:
		return null

	player.name = "GFSpatialSFXPlayer"
	parent.add_child(player)
	var _playback_session_id: int = _begin_playback_session(player)
	if player is AudioStreamPlayer3D:
		var player_3d: AudioStreamPlayer3D = player
		if follow_source:
			player_3d.position = Vector3.ZERO
		else:
			var source_3d: Node3D = source
			player_3d.global_position = source_3d.global_position
	elif player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player
		if follow_source:
			player_2d.position = Vector2.ZERO
		else:
			var source_2d: Node2D = source
			player_2d.global_position = source_2d.global_position
	_track_spatial_sfx_player(player)

	var request_serial: int = _sfx_lifecycle_serial
	var bus_name: String = clip.resolve_bus(SFX_BUS_NAME)
	var volume_db: float = _finite_or_default(clip.volume_db, 0.0)
	var pitch_scale: float = _finite_or_default(clip.resolve_pitch(_audio_rng), 1.0)
	var spatial_settings: Resource = _get_clip_spatial_settings(clip)
	if clip.stream != null:
		_apply_spatial_sfx_request(
			request_serial,
			player,
			clip.stream,
			bus_name,
			volume_db,
			pitch_scale,
			spatial_settings
		)
		return player

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(clip.path))
		_apply_spatial_sfx_request(
			request_serial,
			player,
			stream,
			bus_name,
			volume_db,
			pitch_scale,
			spatial_settings
		)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			var loaded_stream: AudioStream = _get_audio_stream_value(res)
			_apply_spatial_sfx_request(
				request_serial,
				player,
				loaded_stream,
				bus_name,
				volume_db,
				pitch_scale,
				spatial_settings
			)
		asset_util.load_async(clip.path, on_loaded)
	return player


func _apply_spatial_sfx_request(
	request_serial: int,
	player: Node,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	spatial_settings: Resource = null
) -> void:
	if request_serial != _sfx_lifecycle_serial:
		_release_spatial_sfx_player(player, 0.0)
		return
	if stream == null or not is_instance_valid(player):
		_release_spatial_sfx_player(player, 0.0)
		return

	if player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player
		player_2d.bus = _resolve_bus_name(bus_name)
		player_2d.volume_db = _finite_or_default(volume_db, 0.0)
		player_2d.pitch_scale = _finite_or_default(pitch_scale, 1.0)
		player_2d.stream = stream
		_apply_spatial_settings_2d(player_2d, spatial_settings)
		var playback_session_id: int = _get_playback_session_id(player_2d)
		var finished_callback: Callable = _get_spatial_sfx_finished_callback(player_2d, playback_session_id)
		if not player_2d.finished.is_connected(finished_callback):
			_connect_signal_checked(player_2d.finished, finished_callback, CONNECT_ONE_SHOT)
		player_2d.play()
	elif player is AudioStreamPlayer3D:
		var player_3d: AudioStreamPlayer3D = player
		player_3d.bus = _resolve_bus_name(bus_name)
		player_3d.volume_db = _finite_or_default(volume_db, 0.0)
		player_3d.pitch_scale = _finite_or_default(pitch_scale, 1.0)
		player_3d.stream = stream
		_apply_spatial_settings_3d(player_3d, spatial_settings)
		var playback_session_id: int = _get_playback_session_id(player_3d)
		var finished_callback: Callable = _get_spatial_sfx_finished_callback(player_3d, playback_session_id)
		if not player_3d.finished.is_connected(finished_callback):
			_connect_signal_checked(player_3d.finished, finished_callback, CONNECT_ONE_SHOT)
		player_3d.play()
	else:
		_release_spatial_sfx_player(player, 0.0)


func _get_clip_spatial_settings(clip: GFAudioClip) -> Resource:
	if clip == null or clip.spatial_settings == null:
		return null
	if (
		not clip.spatial_settings.has_method(_APPLY_SPATIAL_SETTINGS_2D_METHOD)
		and not clip.spatial_settings.has_method(_APPLY_SPATIAL_SETTINGS_3D_METHOD)
	):
		return null
	return clip.spatial_settings


func _apply_spatial_settings_2d(player: AudioStreamPlayer2D, spatial_settings: Resource) -> void:
	if spatial_settings != null and spatial_settings.has_method(_APPLY_SPATIAL_SETTINGS_2D_METHOD):
		var apply_result: Variant = spatial_settings.call(_APPLY_SPATIAL_SETTINGS_2D_METHOD, player)
		if not (apply_result is bool) or GFVariantData.to_bool(apply_result):
			return

	player.area_mask = _DEFAULT_SPATIAL_AREA_MASK


func _apply_spatial_settings_3d(player: AudioStreamPlayer3D, spatial_settings: Resource) -> void:
	if spatial_settings != null and spatial_settings.has_method(_APPLY_SPATIAL_SETTINGS_3D_METHOD):
		var apply_result: Variant = spatial_settings.call(_APPLY_SPATIAL_SETTINGS_3D_METHOD, player)
		if not (apply_result is bool) or GFVariantData.to_bool(apply_result):
			return

	player.area_mask = _DEFAULT_SPATIAL_AREA_MASK


func _get_spatial_sfx_parent(source: Node) -> Node:
	var tree: SceneTree = source.get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return _root if is_instance_valid(_root) else source


func _play_bgm_stream(stream: AudioStream) -> void:
	_play_bgm_stream_with_settings(stream, BGM_BUS_NAME, 0.0, 1.0)


func _play_bgm_stream_with_settings(
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	crossfade_seconds: float = -1.0,
	history_key: String = "",
	loop_override: Variant = null
) -> void:
	if stream == null or not is_instance_valid(_bgm_player):
		return

	_cancel_bgm_crossfade_playback()
	_cancel_bgm_transport_tween()
	_bgm_pause_serial += 1
	_bgm_paused = false
	_record_bgm_history(history_key)
	var prepared_stream: AudioStream = _prepare_bgm_stream(stream, loop_override)
	var fade_seconds: float = _resolve_bgm_crossfade_seconds(crossfade_seconds)
	if fade_seconds > 0.0 and _bgm_player.playing and _bgm_player.stream != null:
		_start_bgm_crossfade(prepared_stream, bus_name, volume_db, pitch_scale, fade_seconds)
		return

	_apply_player_settings(_bgm_player, prepared_stream, bus_name, volume_db, pitch_scale)
	_bgm_player.play()


func _apply_bgm_request(
	request_serial: int,
	stream: AudioStream,
	crossfade_seconds: float = -1.0,
	history_key: String = "",
	loop_override: Variant = null
) -> void:
	if request_serial != _bgm_request_serial:
		return

	_play_bgm_stream_with_settings(
		stream,
		BGM_BUS_NAME,
		0.0,
		1.0,
		crossfade_seconds,
		history_key,
		loop_override
	)


func _apply_bgm_request_with_settings(
	request_serial: int,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	crossfade_seconds: float = -1.0,
	history_key: String = "",
	loop_override: Variant = null
) -> void:
	if request_serial != _bgm_request_serial:
		return

	_play_bgm_stream_with_settings(
		stream,
		bus_name,
		volume_db,
		pitch_scale,
		crossfade_seconds,
		history_key,
		loop_override
	)


func _start_bgm_crossfade(
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	fade_seconds: float
) -> void:
	if not is_instance_valid(_bgm_fade_player):
		_apply_player_settings(_bgm_player, stream, bus_name, volume_db, pitch_scale)
		_bgm_player.play()
		return

	_bgm_fade_serial += 1
	var fade_serial: int = _bgm_fade_serial
	_apply_player_settings(_bgm_fade_player, stream, bus_name, -80.0, pitch_scale)
	_bgm_fade_player.play()

	var tween: Tween = _create_tween_or_null()
	if tween == null:
		_complete_bgm_crossfade(fade_serial, volume_db)
		return

	_bgm_fade_tween_ref = weakref(tween)
	_add_tween_property(tween, _bgm_player, "volume_db", -80.0, fade_seconds)
	var parallel_tween: Tween = tween.parallel()
	_add_tween_property(parallel_tween, _bgm_fade_player, "volume_db", volume_db, fade_seconds)
	var finished_callback: Callable = func() -> void:
		_complete_bgm_crossfade(fade_serial, volume_db)
	_connect_signal_checked(tween.finished, finished_callback, CONNECT_ONE_SHOT)


func _complete_bgm_crossfade(fade_serial: int, target_volume_db: float) -> void:
	if fade_serial != _bgm_fade_serial:
		return
	if not is_instance_valid(_bgm_player) or not is_instance_valid(_bgm_fade_player):
		return

	_bgm_fade_tween_ref = null
	_bgm_player.stop()
	_bgm_player.stream_paused = false
	var previous_player: AudioStreamPlayer = _bgm_player
	_bgm_player = _bgm_fade_player
	_bgm_player.stream_paused = false
	_bgm_player.volume_db = target_volume_db
	_bgm_fade_player = previous_player
	_bgm_fade_player.stream_paused = false
	_bgm_fade_player.volume_db = 0.0


func _apply_bgm_pause(pause_serial: int, player: AudioStreamPlayer) -> void:
	if pause_serial != _bgm_pause_serial:
		return
	if not is_instance_valid(player) or player.stream == null:
		return

	_bgm_transport_tween_ref = null
	player.stream_paused = true


func _apply_player_settings(
	player: AudioStreamPlayer,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float
) -> void:
	player.bus = _resolve_bus_name(bus_name)
	player.volume_db = _finite_or_default(volume_db, 0.0)
	player.pitch_scale = _finite_or_default(pitch_scale, 1.0)
	player.stream = stream
	player.stream_paused = false


func _prepare_bgm_stream(stream: AudioStream, loop_override: Variant = null) -> AudioStream:
	if stream == null or typeof(loop_override) != TYPE_BOOL:
		return stream

	var duplicated: AudioStream = _get_audio_stream_value(stream.duplicate())
	if duplicated == null:
		return stream
	if _try_set_stream_loop(duplicated, GFVariantData.to_bool(loop_override)):
		return duplicated
	return stream


func _try_set_stream_loop(stream: AudioStream, loop_enabled: bool) -> bool:
	if stream == null:
		return false

	for property_info: Dictionary in stream.get_property_list():
		var property_name: String = GFVariantData.get_option_string(property_info, "name", "")
		if property_name == "loop":
			stream.set("loop", loop_enabled)
			return true
		if property_name == "loop_mode":
			var current_mode: int = GFVariantData.to_int(_get_object_property(stream, &"loop_mode"))
			stream.set("loop_mode", maxi(current_mode, 1) if loop_enabled else 0)
			return true
	return false


func _resolve_bgm_crossfade_seconds(crossfade_seconds: float) -> float:
	var requested_seconds: float = _finite_or_default(crossfade_seconds, -1.0)
	var seconds: float = bgm_crossfade_seconds if requested_seconds < 0.0 else requested_seconds
	return _finite_non_negative_or_zero(seconds)


func _record_bgm_history(history_key: String) -> void:
	if history_key.is_empty():
		return

	_current_bgm_key = history_key
	if _bgm_history.is_empty() or _bgm_history[_bgm_history.size() - 1] != history_key:
		_append_packed_string(_bgm_history, history_key)

	var limit: int = maxi(max_bgm_history, 0)
	while limit > 0 and _bgm_history.size() > limit:
		_bgm_history.remove_at(0)
	if limit == 0:
		_bgm_history = PackedStringArray()


func _get_clip_history_key(clip: GFAudioClip) -> String:
	if clip == null:
		return ""
	if not clip.path.is_empty():
		return clip.path
	if not clip.resource_path.is_empty():
		return clip.resource_path
	return "clip:%d" % clip.get_instance_id()


func _next_ambient_request_serial(channel: StringName) -> int:
	var next_serial: int = _get_ambient_request_serial(channel) + 1
	_ambient_request_serials[channel] = next_serial
	return next_serial


func _apply_ambient_request(
	request_serial: int,
	channel: StringName,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	fade_seconds: float
) -> void:
	if request_serial != _get_ambient_request_serial(channel):
		return

	_play_ambient_stream_with_settings(channel, stream, bus_name, volume_db, pitch_scale, fade_seconds)


func _play_ambient_stream_with_settings(
	channel: StringName,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	fade_seconds: float
) -> void:
	if stream == null:
		return

	var player: AudioStreamPlayer = _get_or_create_ambient_player(channel)
	if player == null:
		return

	var should_fade: bool = fade_seconds > 0.0
	_apply_player_settings(player, stream, bus_name, -80.0 if should_fade else volume_db, pitch_scale)
	player.play()
	if should_fade:
		_forget_tween(_fade_player_volume(player, volume_db, fade_seconds))


func _get_or_create_ambient_player(channel: StringName) -> AudioStreamPlayer:
	var existing: AudioStreamPlayer = _get_ambient_player(channel)
	if is_instance_valid(existing):
		return existing
	if not is_instance_valid(_root):
		return null

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "GFAmbientPlayer_%s" % String(channel)
	player.bus = _resolve_bus_name(BGM_BUS_NAME)
	_root.add_child(player)
	_ambient_players[channel] = player
	return player


func _free_all_ambient_players() -> void:
	for player_variant: Variant in _ambient_players.values():
		var player: AudioStreamPlayer = _get_audio_stream_player_value(player_variant)
		if is_instance_valid(player):
			player.queue_free()
	_ambient_players.clear()
	_ambient_request_serials.clear()


func _stop_player(player: AudioStreamPlayer, fade_seconds: float) -> void:
	if not is_instance_valid(player):
		return
	if fade_seconds <= 0.0 or not player.playing:
		player.stop()
		return

	var tween: Tween = _create_tween_or_null()
	if tween == null:
		player.volume_db = -80.0
		player.stop()
		return

	_add_tween_property(tween, player, "volume_db", -80.0, maxf(fade_seconds, 0.0))
	_add_tween_callback(tween, func() -> void:
		if is_instance_valid(player):
			player.stop()
	)


func _schedule_bgm_stop_fallback(player: AudioStreamPlayer, request_serial: int, fade_seconds: float) -> void:
	if fade_seconds <= 0.0 or not is_instance_valid(player):
		return

	var tree: SceneTree = _get_scene_tree()
	if tree == null:
		return

	var timer: SceneTreeTimer = tree.create_timer(_finite_non_negative_or_zero(fade_seconds))
	_connect_signal_checked(timer.timeout, func() -> void:
		if request_serial != _bgm_request_serial:
			return
		if player != _bgm_player:
			return
		if is_instance_valid(player):
			player.stop()
	)


func _fade_player_volume(player: AudioStreamPlayer, volume_db: float, fade_seconds: float) -> Tween:
	if not _is_finite_float(volume_db) or not _is_finite_float(fade_seconds):
		return null
	var tween: Tween = _create_tween_or_null()
	if tween == null:
		player.volume_db = volume_db
		return null

	_add_tween_property(tween, player, "volume_db", volume_db, maxf(fade_seconds, 0.0))
	return tween


func _create_tween_or_null() -> Tween:
	if is_instance_valid(_root):
		return _root.create_tween()
	return null


func _cancel_bgm_fade_tween() -> void:
	_kill_tween_ref(_bgm_fade_tween_ref)
	_bgm_fade_tween_ref = null


func _cancel_bgm_crossfade_playback() -> void:
	_bgm_fade_serial += 1
	_cancel_bgm_fade_tween()
	if is_instance_valid(_bgm_fade_player):
		_bgm_fade_player.stream_paused = false
		_bgm_fade_player.stop()


func _cancel_bgm_transport_tween() -> void:
	_kill_tween_ref(_bgm_transport_tween_ref)
	_bgm_transport_tween_ref = null


func _clear_bgm_transport_tween(pause_serial: int) -> void:
	if pause_serial == _bgm_pause_serial:
		_bgm_transport_tween_ref = null


func _kill_tween_ref(tween_ref: WeakRef) -> void:
	if tween_ref == null:
		return

	var tween: Tween = _get_tween_value(tween_ref.get_ref())
	if tween != null:
		tween.kill()


func _apply_sfx_request(
	request_serial: int,
	stream: AudioStream,
	handle: GFAudioEmitterHandle = null
) -> void:
	if request_serial != _sfx_lifecycle_serial:
		if handle != null:
			handle.stop(0.0)
		return
	if handle != null and handle.is_stop_requested():
		return
	if stream == null:
		if handle != null:
			handle.stop(0.0)
		return

	var player: AudioStreamPlayer = _play_sfx_stream(stream)
	if handle != null:
		if player == null:
			handle.stop(0.0)
		else:
			_attach_handle_to_playback_session(handle, player, Callable(self, "_release_sfx_session"))


func _apply_sfx_request_with_settings(
	request_serial: int,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	handle: GFAudioEmitterHandle = null
) -> void:
	if request_serial != _sfx_lifecycle_serial:
		if handle != null:
			handle.stop(0.0)
		return
	if handle != null and handle.is_stop_requested():
		return
	if stream == null:
		if handle != null:
			handle.stop(0.0)
		return

	var player: AudioStreamPlayer = _play_sfx_stream_with_settings(stream, bus_name, volume_db, pitch_scale)
	if handle != null:
		if player == null:
			handle.stop(0.0)
		else:
			_attach_handle_to_playback_session(handle, player, Callable(self, "_release_sfx_session"))


func _play_sfx_stream(stream: AudioStream) -> AudioStreamPlayer:
	return _play_sfx_stream_with_settings(stream, SFX_BUS_NAME, 0.0, 1.0)


func _play_sfx_stream_with_settings(
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float
) -> AudioStreamPlayer:
	if stream == null or not is_instance_valid(_root):
		return null

	if _is_sfx_capacity_full():
		if sfx_overflow_policy == SFXOverflowPolicy.STOP_OLDEST:
			_stop_oldest_sfx()
		else:
			return null

	var pool: GFObjectPoolUtility = _get_pool_util()
	var player: AudioStreamPlayer = null
	if pool != null:
		player = _get_audio_stream_player_value(pool.acquire(_sfx_scene, _root))
	else:
		player = AudioStreamPlayer.new()
		player.name = "GFSFXPlayer"
		_root.add_child(player)

	if player != null:
		var playback_session_id: int = _begin_playback_session(player)
		player.bus = _resolve_bus_name(bus_name)
		player.volume_db = _finite_or_default(volume_db, 0.0)
		player.pitch_scale = _finite_or_default(pitch_scale, 1.0)
		player.stream = stream
		var finished_callback: Callable = _get_sfx_finished_callback(player, playback_session_id)
		if not player.finished.is_connected(finished_callback):
			_connect_signal_checked(player.finished, finished_callback, CONNECT_ONE_SHOT)
		_track_sfx_player(player)
		player.play()
	return player


func _stop_audio_player(player: Node) -> void:
	if is_instance_valid(player) and player.has_method("stop"):
		player.call("stop")


func _on_bgm_player_finished(player: AudioStreamPlayer) -> void:
	if player != _bgm_player:
		return

	var history_key: String = _current_bgm_key
	_bgm_paused = false
	_current_bgm_key = ""
	_current_bgm_loop = null
	if not history_key.is_empty():
		bgm_finished.emit(history_key)


func _on_sfx_finished(player: AudioStreamPlayer, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	_finish_release_sfx_player(player, playback_session_id)


func _on_spatial_sfx_finished(player: Node, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	_finish_release_spatial_sfx_player(player, playback_session_id)


func _get_asset_util() -> GFAssetUtility:
	var arch: Object = _get_architecture_or_null()
	if arch != null and arch.has_method("get_utility"):
		var util_value: Variant = arch.call("get_utility", GFAssetUtility)
		if util_value is GFAssetUtility:
			return util_value
	return null


func _get_pool_util() -> GFObjectPoolUtility:
	var arch: Object = _get_architecture_or_null()
	if arch != null and arch.has_method("get_utility"):
		var util_value: Variant = arch.call("get_utility", GFObjectPoolUtility)
		if util_value is GFObjectPoolUtility:
			return util_value
	return null


func _resolve_bus_name(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name

	if not _missing_bus_warnings.has(bus_name):
		_missing_bus_warnings[bus_name] = true
		push_warning("[GFAudioUtility] 无法找到音轨总线: %s，已回退到 %s。" % [bus_name, _FALLBACK_BUS_NAME])
	return _FALLBACK_BUS_NAME


func _is_sfx_capacity_full() -> bool:
	if max_sfx_players <= 0:
		return false

	_prune_inactive_sfx_players()
	return _active_sfx_players.size() >= max_sfx_players


func _track_sfx_player(player: AudioStreamPlayer) -> void:
	_prune_inactive_sfx_players()
	if not _active_sfx_players.has(player):
		_active_sfx_players.append(player)


func _untrack_sfx_player(player: AudioStreamPlayer) -> void:
	_active_sfx_players.erase(player)


func _track_spatial_sfx_player(player: Node) -> void:
	_prune_inactive_spatial_sfx_players()
	if is_instance_valid(player) and not _active_spatial_sfx_players.has(player):
		_active_spatial_sfx_players.append(player)


func _untrack_spatial_sfx_player(player: Node) -> void:
	_active_spatial_sfx_players.erase(player)


func _stop_oldest_sfx() -> void:
	_prune_inactive_sfx_players()
	if _active_sfx_players.is_empty():
		return

	var player: AudioStreamPlayer = _get_audio_stream_player_value(_active_sfx_players.pop_front())
	_release_sfx_player(player, 0.0)


func _begin_playback_session(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	var previous_session_id: int = _get_playback_session_id(player)
	if previous_session_id > 0:
		_complete_playback_session_handle(previous_session_id)
		var _previous_handle_erased: bool = _playback_session_handles.erase(previous_session_id)
	var playback_session_id: int = _next_playback_session_id
	_next_playback_session_id += 1
	player.set_meta(_PLAYBACK_SESSION_META, playback_session_id)
	return playback_session_id


func _attach_handle_to_playback_session(
	handle: GFAudioEmitterHandle,
	player: Node,
	release_callback: Callable
) -> void:
	if handle == null or not is_instance_valid(player):
		return
	var playback_session_id: int = _get_playback_session_id(player)
	if playback_session_id <= 0:
		handle.stop(0.0)
		return
	handle.set_release_callback(release_callback.bind(playback_session_id))
	handle._set_playback_session(
		playback_session_id,
		Callable(self, "_is_playback_session_current").bind(playback_session_id)
	)
	_playback_session_handles[playback_session_id] = weakref(handle)
	handle.set_player(player)


func _release_sfx_session(player: Node, playback_session_id: int) -> void:
	if player is AudioStreamPlayer:
		var stream_player: AudioStreamPlayer = player
		if _is_playback_session_current(stream_player, playback_session_id):
			_release_sfx_player(stream_player, 0.0)


func _release_spatial_sfx_session(player: Node, playback_session_id: int) -> void:
	if _is_playback_session_current(player, playback_session_id):
		_release_spatial_sfx_player(player, 0.0)


func _get_playback_session_id(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	return GFVariantData.to_int(player.get_meta(_PLAYBACK_SESSION_META, 0))


func _is_playback_session_current(player: Node, playback_session_id: int) -> bool:
	return (
		playback_session_id > 0
		and is_instance_valid(player)
		and _get_playback_session_id(player) == playback_session_id
	)


func _complete_playback_session_handle(playback_session_id: int) -> void:
	var handle_ref_value: Variant = _playback_session_handles.get(playback_session_id)
	if handle_ref_value is WeakRef:
		var handle_ref: WeakRef = handle_ref_value
		var handle_value: Variant = handle_ref.get_ref()
		if handle_value is GFAudioEmitterHandle:
			var handle: GFAudioEmitterHandle = handle_value
			handle._complete_playback_session(playback_session_id)
	var _handle_erased: bool = _playback_session_handles.erase(playback_session_id)


func _invalidate_playback_session(player: Node, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	_complete_playback_session_handle(playback_session_id)
	player.remove_meta(_PLAYBACK_SESSION_META)


func _release_all_sfx_players(fade_seconds: float = 0.0) -> void:
	_prune_inactive_sfx_players()
	var players: Array[AudioStreamPlayer] = _active_sfx_players.duplicate()
	_active_sfx_players.clear()
	for player: AudioStreamPlayer in players:
		_release_sfx_player(player, fade_seconds)


func _release_all_spatial_sfx_players(fade_seconds: float = 0.0) -> void:
	_prune_inactive_spatial_sfx_players()
	var players: Array[Node] = _active_spatial_sfx_players.duplicate()
	_active_spatial_sfx_players.clear()
	for player: Node in players:
		_release_spatial_sfx_player(player, fade_seconds)


func _release_sfx_player(player: AudioStreamPlayer, fade_seconds: float = 0.0) -> void:
	if not is_instance_valid(player):
		return

	var playback_session_id: int = _get_playback_session_id(player)
	if playback_session_id <= 0:
		return
	_untrack_sfx_player(player)
	_complete_playback_session_handle(playback_session_id)
	var finished_callback: Callable = _get_sfx_finished_callback(player, playback_session_id)
	if player.finished.is_connected(finished_callback):
		player.finished.disconnect(finished_callback)
	var safe_fade_seconds: float = _finite_non_negative_or_zero(fade_seconds)
	if safe_fade_seconds > 0.0 and player.playing:
		var tween: Tween = _fade_player_volume(player, -80.0, safe_fade_seconds)
		if tween != null:
			_connect_signal_checked(
				tween.finished,
				_finish_release_sfx_player.bind(player, playback_session_id),
				CONNECT_ONE_SHOT
			)
			return

	_finish_release_sfx_player(player, playback_session_id)


func _finish_release_sfx_player(player: AudioStreamPlayer, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return

	_untrack_sfx_player(player)
	_complete_playback_session_handle(playback_session_id)
	_invalidate_playback_session(player, playback_session_id)
	player.stop()
	_reset_sfx_player_for_reuse(player)

	var pool: GFObjectPoolUtility = _get_pool_util()
	if pool != null and is_instance_valid(_sfx_scene):
		pool.release(player, _sfx_scene)
	else:
		player.queue_free()


func _release_spatial_sfx_player(player: Node, fade_seconds: float = 0.0) -> void:
	if not is_instance_valid(player):
		return

	var playback_session_id: int = _get_playback_session_id(player)
	if playback_session_id <= 0:
		return
	_untrack_spatial_sfx_player(player)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_spatial_sfx_finished_callback(player, playback_session_id)
	var safe_fade_seconds: float = _finite_non_negative_or_zero(fade_seconds)
	if safe_fade_seconds > 0.0 and _is_audio_node_playing(player):
		var tween: Tween = _fade_audio_node_volume(player, -80.0, safe_fade_seconds)
		if tween != null:
			_connect_signal_checked(
				tween.finished,
				_finish_release_spatial_sfx_player.bind(player, playback_session_id),
				CONNECT_ONE_SHOT
			)
			return

	_finish_release_spatial_sfx_player(player, playback_session_id)


func _finish_release_spatial_sfx_player(player: Node, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return

	_untrack_spatial_sfx_player(player)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_spatial_sfx_finished_callback(player, playback_session_id)
	_invalidate_playback_session(player, playback_session_id)
	if player.has_method("stop"):
		player.call("stop")
	player.queue_free()


func _prune_inactive_sfx_players() -> void:
	for i: int in range(_active_sfx_players.size() - 1, -1, -1):
		var player: AudioStreamPlayer = _active_sfx_players[i]
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			_active_sfx_players.remove_at(i)


func _prune_inactive_spatial_sfx_players() -> void:
	for i: int in range(_active_spatial_sfx_players.size() - 1, -1, -1):
		var player: Node = _active_spatial_sfx_players[i]
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			_active_spatial_sfx_players.remove_at(i)


func _reset_sfx_player_for_reuse(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return

	player.stop()
	player.stream = null
	player.bus = _resolve_bus_name(SFX_BUS_NAME)
	player.volume_db = 0.0
	player.pitch_scale = 1.0


func _get_sfx_finished_callback(player: AudioStreamPlayer, playback_session_id: int) -> Callable:
	return _on_sfx_finished.bind(player, playback_session_id)


func _get_spatial_sfx_finished_callback(player: Node, playback_session_id: int) -> Callable:
	return _on_spatial_sfx_finished.bind(player, playback_session_id)


func _disconnect_spatial_sfx_finished_callback(player: Node, playback_session_id: int) -> void:
	var finished_callback: Callable = _get_spatial_sfx_finished_callback(player, playback_session_id)
	if player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player
		if player_2d.finished.is_connected(finished_callback):
			player_2d.finished.disconnect(finished_callback)
	elif player is AudioStreamPlayer3D:
		var player_3d: AudioStreamPlayer3D = player
		if player_3d.finished.is_connected(finished_callback):
			player_3d.finished.disconnect(finished_callback)


func _is_audio_node_playing(player: Node) -> bool:
	if player is AudioStreamPlayer:
		var stream_player: AudioStreamPlayer = player
		return stream_player.playing
	if player is AudioStreamPlayer2D:
		var player_2d: AudioStreamPlayer2D = player
		return player_2d.playing
	if player is AudioStreamPlayer3D:
		var player_3d: AudioStreamPlayer3D = player
		return player_3d.playing
	return false


func _fade_audio_node_volume(player: Node, volume_db: float, fade_seconds: float) -> Tween:
	if not _is_finite_float(volume_db) or not _is_finite_float(fade_seconds):
		return null
	var tween: Tween = _create_tween_or_null()
	if tween == null:
		player.set("volume_db", volume_db)
		return null

	_add_tween_property(tween, player, "volume_db", volume_db, maxf(fade_seconds, 0.0))
	return tween
