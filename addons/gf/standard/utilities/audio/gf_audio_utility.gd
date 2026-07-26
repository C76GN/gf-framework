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
const _BGM_SESSION_META: StringName = &"_gf_audio_bgm_session_id"
const _OWNER_NONE: StringName = &"none"
const _OWNER_LOCAL: StringName = &"local"
const _OWNER_BACKEND: StringName = &"backend"
const _STATE_STOPPED: StringName = &"stopped"
const _STATE_LOADING: StringName = &"loading"
const _STATE_PLAYING: StringName = &"playing"
const _STATE_CROSSFADING: StringName = &"crossfading"
const _STATE_PAUSING: StringName = &"pausing"
const _STATE_PAUSED: StringName = &"paused"
const _STATE_STOPPING: StringName = &"stopping"
const _STATE_RETIRING: StringName = &"retiring"


# --- 公共变量 ---

## 普通与空间 SFX 共用的并发播放数量上限；小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
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
var _bgm_generation: int = 0
var _next_bgm_session_id: int = 1
var _bgm_current_session_id: int = 0
var _bgm_incoming_session_id: int = 0
var _bgm_sessions: Dictionary = {}
var _bgm_state: StringName = _STATE_STOPPED
var _bgm_owner: StringName = _OWNER_NONE
var _bgm_fade_serial: int = 0
var _bgm_fade_tween_ref: WeakRef = null
var _bgm_stop_tween_ref: WeakRef = null
var _bgm_pause_serial: int = 0
var _bgm_transport_tween_ref: WeakRef = null
var _bgm_paused: bool = false
var _bgm_pause_volume_db: float = 0.0
var _sfx_lifecycle_serial: int = 0
var _next_playback_session_id: int = 1
var _playback_session_handles: Dictionary = {}
var _playback_sessions: Dictionary = {}
var _missing_bus_warnings: Dictionary = {}
var _active_sfx_players: Array[AudioStreamPlayer] = []
var _active_spatial_sfx_players: Array[Node] = []
var _retiring_sfx_players: Array[AudioStreamPlayer] = []
var _retiring_spatial_sfx_players: Array[Node] = []
var _bgm_history: PackedStringArray = PackedStringArray()
var _current_bgm_key: String = ""
var _current_bgm_loop: Variant = null
var _ambient_players: Dictionary = {}
var _ambient_request_serials: Dictionary = {}
var _ambient_generation_counter: int = 0
var _ambient_sessions: Dictionary = {}
var _ambient_tween_refs: Dictionary = {}
var _audio_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _audio_banks: Dictionary = {}
var _audio_bank_base_values: Dictionary = {}
var _audio_bank_mount_stacks: Dictionary = {}
var _audio_bank_mount_token: int = 0
var _audio_backend: GFAudioBackend = null
var _backend_dispatch_depth: int = 0
var _bus_volume_tween_refs: Dictionary = {}
var _bus_generation_counter: int = 0
var _bus_transaction_generations: Dictionary = {}
var _bus_effect_tween_refs: Dictionary = {}
var _duck_bus_states: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化音频播放器、运行时状态和默认播放根节点。
## [br]
## @api public
func init() -> void:
	if _is_backend_dispatch_in_progress():
		return
	var _duck_buses_restored: bool = _restore_all_ducked_buses_for_lifecycle()
	_bgm_request_serial += 1
	_bgm_generation += 1
	_next_bgm_session_id = maxi(_next_bgm_session_id, 1)
	_bgm_current_session_id = 0
	_bgm_incoming_session_id = 0
	_bgm_sessions.clear()
	_bgm_state = _STATE_STOPPED
	_bgm_owner = _OWNER_NONE
	_bgm_fade_serial += 1
	_bgm_fade_tween_ref = null
	_bgm_stop_tween_ref = null
	_bgm_pause_serial += 1
	_bgm_transport_tween_ref = null
	_bgm_paused = false
	_bgm_pause_volume_db = 0.0
	_sfx_lifecycle_serial += 1
	_next_playback_session_id = maxi(_next_playback_session_id, 1)
	_complete_all_playback_session_handles()
	_playback_session_handles.clear()
	_playback_sessions.clear()
	_missing_bus_warnings.clear()
	_active_sfx_players.clear()
	_active_spatial_sfx_players.clear()
	_retiring_sfx_players.clear()
	_retiring_spatial_sfx_players.clear()
	_bgm_history = PackedStringArray()
	_current_bgm_key = ""
	_current_bgm_loop = null
	_ambient_players.clear()
	_ambient_request_serials.clear()
	_ambient_generation_counter += 1
	_ambient_sessions.clear()
	_ambient_tween_refs.clear()
	_audio_rng.randomize()
	_audio_banks.clear()
	_audio_bank_base_values.clear()
	_audio_bank_mount_stacks.clear()
	_audio_bank_mount_token = 0
	_clear_mix_control_tweens()
	_bus_generation_counter += 1
	_bus_transaction_generations.clear()
	_duck_bus_states.clear()
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
## 后端拒绝停止时会记录 warning，但生命周期仍会强制收敛为终态。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	var backend_stop_succeeded: bool = true
	if _audio_backend != null:
		if _is_backend_dispatch_in_progress():
			backend_stop_succeeded = false
		else:
			backend_stop_succeeded = _stop_backend_owned_sessions()
	if not backend_stop_succeeded:
		push_warning(
			"[GFAudioUtility] dispose 强制终结：后端拒绝停止或正在回调，"
			+ "将解除内部 owner 并继续释放生命周期资源。"
		)
	var _duck_buses_restored: bool = _restore_all_ducked_buses_for_lifecycle()
	_bgm_request_serial += 1
	_bgm_generation += 1
	_bgm_fade_serial += 1
	_bgm_pause_serial += 1
	_cancel_bgm_fade_tween()
	_cancel_bgm_stop_tween()
	_cancel_bgm_transport_tween()
	_sfx_lifecycle_serial += 1
	_bgm_paused = false
	_current_bgm_loop = null
	_stop_all_local_bgm_players()
	_clear_bgm_session_state()
	var backend_cleared: bool = false
	if not _is_backend_dispatch_in_progress():
		backend_cleared = _clear_audio_backend(true)
	if not backend_cleared and _audio_backend != null:
		push_warning(
			"[GFAudioUtility] dispose 强制终结：后端 dispose 回调未完成，"
			+ "已解除内部后端引用。"
		)
		_audio_backend = null
	_release_all_sfx_players(0.0)
	_release_all_spatial_sfx_players(0.0)
	_free_all_ambient_players()
	_complete_all_playback_session_handles()
	_playback_session_handles.clear()
	_playback_sessions.clear()
	_clear_mix_control_tweens()
	if is_instance_valid(_bgm_player):
		_bgm_player.queue_free()
	if is_instance_valid(_bgm_fade_player):
		_bgm_fade_player.queue_free()
	_root = null
	_audio_banks.clear()
	_audio_bank_base_values.clear()
	_audio_bank_mount_stacks.clear()
	_bgm_sessions.clear()
	_bgm_current_session_id = 0
	_bgm_incoming_session_id = 0
	_bgm_state = _STATE_STOPPED
	_bgm_owner = _OWNER_NONE
	_bus_transaction_generations.clear()
	_duck_bus_states.clear()
	
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


## 使用选项播放 BGM。每次请求创建新会话；异步加载、淡变与 finished 回调只可提交所属会话。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 音频资源路径或后端事件路径。
## [br]
## @param options: 支持 crossfade_seconds、history_key、loop、bus_name、volume_db 和 pitch_scale。
## [br]
## @schema options: Dictionary，可包含 crossfade_seconds、history_key、loop、bus_name、volume_db 和 pitch_scale 字段。
func play_bgm_with_options(path: String, options: Dictionary = {}) -> void:
	if _is_backend_dispatch_in_progress():
		return
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
	if path.is_empty():
		stop_bgm(crossfade_seconds)
		return
	var request_serial: int = _begin_bgm_replacement()

	var backend_options: Dictionary = options.duplicate(true)
	backend_options["crossfade_seconds"] = _resolve_bgm_crossfade_seconds(crossfade_seconds)
	backend_options["history_key"] = history_key
	backend_options["bus_name"] = bus_name
	backend_options["volume_db"] = volume_db
	backend_options["pitch_scale"] = pitch_scale
	if _try_backend_play_bgm_path(path, backend_options):
		_commit_backend_bgm_session(request_serial, history_key, loop_override)
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


## 播放资源化 BGM 配置。后端与本地播放器按请求结果原子交接唯一通道所有权。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param clip: 音频片段配置。
## [br]
## @param crossfade_seconds: 淡入淡出秒数；小于 0 时使用默认值。
func play_bgm_clip(clip: GFAudioClip, crossfade_seconds: float = -1.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
	if clip == null or not clip.has_source():
		return

	var request_serial: int = _begin_bgm_replacement()
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
		_commit_backend_bgm_session(request_serial, history_key, null)
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


## 停止当前 BGM。淡出只绑定当前会话，后续替换会使旧完成回调失效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param fade_seconds: 淡出秒数。
func stop_bgm(fade_seconds: float = 0.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var previous_state: StringName = _bgm_state
	var previous_paused: bool = _bgm_paused
	_bgm_request_serial += 1
	_bgm_generation += 1
	var operation_generation: int = _bgm_generation
	_bgm_pause_serial += 1
	_cancel_bgm_fade_tween()
	_cancel_bgm_stop_tween()
	_cancel_bgm_transport_tween()
	_bgm_paused = false
	if _bgm_owner == _OWNER_BACKEND:
		if not _notify_backend_stop_bgm(safe_fade):
			_bgm_state = previous_state
			_bgm_paused = previous_paused
			return
		_stop_all_local_bgm_players()
		_clear_bgm_session_state()
		return

	_cancel_bgm_incoming_session()
	_current_bgm_key = ""
	_current_bgm_loop = null
	var session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var player: AudioStreamPlayer = _get_bgm_session_player(session)
	if _bgm_owner != _OWNER_LOCAL or not is_instance_valid(player):
		_stop_all_local_bgm_players()
		_clear_bgm_session_state()
		return

	_bgm_state = _STATE_STOPPING
	player.stream_paused = false
	_start_bgm_session_stop(player, _bgm_current_session_id, operation_generation, safe_fade)


## 暂停当前 BGM。仅 playing 状态可进入 pausing/paused，非法重复操作返回 false。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param fade_seconds: 淡出到暂停的秒数。
## [br]
## @return: 成功暂停或后端已处理时返回 true。
func pause_bgm(fade_seconds: float = 0.0) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	if _bgm_state != _STATE_PLAYING:
		return false
	if _bgm_owner == _OWNER_BACKEND:
		var expected_backend: GFAudioBackend = _audio_backend
		var expected_request_serial: int = _bgm_request_serial
		var expected_generation: int = _bgm_generation
		var backend_result: Dictionary = _dispatch_backend_call(
			&"pause_bgm",
			[safe_fade],
			expected_backend
		)
		if (
			not _backend_dispatch_returned_true(backend_result)
			or expected_request_serial != _bgm_request_serial
			or expected_generation != _bgm_generation
			or _bgm_owner != _OWNER_BACKEND
			or _audio_backend != expected_backend
		):
			return false
		_bgm_generation += 1
		_bgm_pause_serial += 1
		_bgm_state = _STATE_PAUSED
		_bgm_paused = true
		return true
	if _bgm_owner != _OWNER_LOCAL:
		return false

	var session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var player: AudioStreamPlayer = _get_bgm_session_player(session)
	if not is_instance_valid(player) or player.stream == null or not player.playing:
		return false

	_bgm_generation += 1
	var operation_generation: int = _bgm_generation
	_bgm_pause_serial += 1
	var pause_serial: int = _bgm_pause_serial
	_cancel_bgm_transport_tween()
	_bgm_state = _STATE_PAUSING
	_bgm_paused = false
	_bgm_pause_volume_db = GFVariantData.get_option_float(session, "target_volume_db", player.volume_db)
	if safe_fade > 0.0:
		var tween: Tween = _fade_player_volume(player, SILENCE_VOLUME_DB, safe_fade)
		if tween != null:
			_bgm_transport_tween_ref = weakref(tween)
			_connect_signal_checked(
				tween.finished,
				_apply_bgm_pause.bind(
					operation_generation,
					pause_serial,
					_bgm_current_session_id,
					player
				),
				CONNECT_ONE_SHOT
			)
			return true

	_apply_bgm_pause(operation_generation, pause_serial, _bgm_current_session_id, player)
	return true


## 恢复当前 BGM。仅 paused 或尚未完成的 pausing 状态可恢复，已停止会话不会被复活。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param from_position: 大于等于 0 时从指定秒数恢复。
## [br]
## @param fade_seconds: 淡入秒数。
## [br]
## @return: 成功恢复或后端已处理时返回 true。
func resume_bgm(from_position: float = -1.0, fade_seconds: float = 0.0) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	var normalized_position: float = _finite_or_default(from_position, -1.0)
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var safe_position: float = maxf(normalized_position, 0.0)
	var was_pausing: bool = _bgm_state == _STATE_PAUSING
	if _bgm_state != _STATE_PAUSED and not was_pausing:
		return false
	if _bgm_owner == _OWNER_BACKEND:
		var expected_backend: GFAudioBackend = _audio_backend
		var expected_request_serial: int = _bgm_request_serial
		var expected_generation: int = _bgm_generation
		var backend_result: Dictionary = _dispatch_backend_call(
			&"resume_bgm",
			[normalized_position, safe_fade],
			expected_backend
		)
		if (
			not _backend_dispatch_returned_true(backend_result)
			or expected_request_serial != _bgm_request_serial
			or expected_generation != _bgm_generation
			or _bgm_owner != _OWNER_BACKEND
			or _audio_backend != expected_backend
		):
			return false
		_bgm_generation += 1
		_bgm_pause_serial += 1
		_bgm_state = _STATE_PLAYING
		_bgm_paused = false
		return true
	if _bgm_owner != _OWNER_LOCAL:
		return false

	var session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var player: AudioStreamPlayer = _get_bgm_session_player(session)
	if (
		not is_instance_valid(player)
		or player.stream == null
		or (not was_pausing and not player.stream_paused)
	):
		return false

	_bgm_generation += 1
	var operation_generation: int = _bgm_generation
	_bgm_pause_serial += 1
	var resume_serial: int = _bgm_pause_serial
	_cancel_bgm_transport_tween()
	var target_volume: float = GFVariantData.get_option_float(
		session,
		"target_volume_db",
		_bgm_pause_volume_db
	)
	if normalized_position >= 0.0:
		player.seek(safe_position)
	player.stream_paused = false
	_bgm_state = _STATE_PLAYING
	_bgm_paused = false
	if safe_fade > 0.0:
		player.volume_db = SILENCE_VOLUME_DB
		var tween: Tween = _fade_player_volume(player, target_volume, safe_fade)
		if tween != null:
			_bgm_transport_tween_ref = weakref(tween)
			_connect_signal_checked(
				tween.finished,
				_clear_bgm_transport_tween.bind(operation_generation, resume_serial),
				CONNECT_ONE_SHOT
			)
	else:
		player.volume_db = target_volume
	return true


## 跳转当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @param position_seconds: 目标秒数。
## [br]
## @return: 成功跳转或后端已处理时返回 true。
func seek_bgm(position_seconds: float) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	if not _is_finite_float(position_seconds):
		return false
	var safe_position: float = maxf(position_seconds, 0.0)
	if _bgm_owner == _OWNER_BACKEND:
		var expected_backend: GFAudioBackend = _audio_backend
		var expected_request_serial: int = _bgm_request_serial
		var expected_generation: int = _bgm_generation
		var backend_result: Dictionary = _dispatch_backend_call(
			&"seek_bgm",
			[safe_position],
			expected_backend
		)
		return (
			_backend_dispatch_returned_true(backend_result)
			and expected_request_serial == _bgm_request_serial
			and expected_generation == _bgm_generation
			and _bgm_owner == _OWNER_BACKEND
			and _audio_backend == expected_backend
		)

	if _bgm_owner != _OWNER_LOCAL or _bgm_state == _STATE_STOPPED:
		return false
	var player: AudioStreamPlayer = _get_bgm_session_player(_get_bgm_session(_bgm_current_session_id))
	if not is_instance_valid(player) or player.stream == null:
		return false

	player.seek(safe_position)
	return true


## 获取当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @return: 当前播放秒数；无可查询播放器时返回 0。
func get_bgm_playback_position() -> float:
	if _bgm_owner == _OWNER_BACKEND and _audio_backend != null:
		var backend_position: float = _backend_dispatch_float(
			_dispatch_backend_call(&"get_bgm_playback_position", [], _audio_backend),
			-1.0
		)
		if backend_position >= 0.0:
			return backend_position

	if _bgm_owner != _OWNER_LOCAL:
		return 0.0
	var player: AudioStreamPlayer = _get_bgm_session_player(_get_bgm_session(_bgm_current_session_id))
	if not is_instance_valid(player) or player.stream == null:
		return 0.0
	return player.get_playback_position()


## 查询当前 BGM session 是否仍存在。暂停中的 BGM 仍视为 playing。
## backend-owned 会话会查询后端，并在稳定 identity 下提交自然结束终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前 BGM 正在播放、淡变或暂停时返回 true。
func is_bgm_playing() -> bool:
	if _bgm_owner == _OWNER_BACKEND:
		if _audio_backend == null or _bgm_state == _STATE_STOPPED:
			return false
		if _is_backend_dispatch_in_progress():
			return true

		var expected_backend: GFAudioBackend = _audio_backend
		var expected_request_serial: int = _bgm_request_serial
		var expected_generation: int = _bgm_generation
		var expected_state: StringName = _bgm_state
		var expected_history_key: String = _current_bgm_key
		var backend_result: Dictionary = _dispatch_backend_call(
			&"is_bgm_playing",
			[],
			expected_backend
		)
		if (
			not _backend_dispatch_completed(backend_result)
			or not _is_backend_bgm_session_current(
				expected_backend,
				expected_request_serial,
				expected_generation,
				expected_state,
				expected_history_key
			)
		):
			return (
				_bgm_owner == _OWNER_BACKEND
				and _audio_backend != null
				and _bgm_state != _STATE_STOPPED
			)
		if _backend_dispatch_returned_true(backend_result):
			return true
		_commit_backend_bgm_natural_end(expected_history_key)
		return false

	if _bgm_owner != _OWNER_LOCAL or _bgm_state == _STATE_STOPPED:
		return false
	for session_id: int in [_bgm_current_session_id, _bgm_incoming_session_id]:
		var player: AudioStreamPlayer = _get_bgm_session_player(_get_bgm_session(session_id))
		if (
			is_instance_valid(player)
			and player.stream != null
			and (player.playing or player.stream_paused)
		):
			return true
	return false


## 查询当前 BGM 是否暂停。
## [br]
## @api public
## [br]
## @return: 暂停时返回 true。
func is_bgm_paused() -> bool:
	if _bgm_owner != _OWNER_BACKEND or _audio_backend == null:
		return _bgm_state == _STATE_PAUSED
	if _is_backend_dispatch_in_progress():
		return _bgm_paused

	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _bgm_request_serial
	var expected_generation: int = _bgm_generation
	var backend_result: Dictionary = _dispatch_backend_call(
		&"is_bgm_paused",
		[],
		expected_backend
	)
	if (
		not _backend_dispatch_completed(backend_result)
		or _audio_backend != expected_backend
		or _bgm_request_serial != expected_request_serial
		or _bgm_generation != expected_generation
		or _bgm_owner != _OWNER_BACKEND
	):
		return _bgm_paused

	var backend_paused: bool = _backend_dispatch_returned_true(backend_result)
	_bgm_paused = backend_paused
	_bgm_state = _STATE_PAUSED if backend_paused else _STATE_PLAYING
	return backend_paused


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


## 设置可插拔音频后端。传入 null 时恢复默认 Godot 播放路径；替换前会停止旧后端通道，
## 并按原 owner 恢复、清除所有活跃 duck 作用域。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param backend: 音频后端。
## [br]
## @return: 后端已设置；旧通道停止、duck 基准恢复、dispose 或 setup 未完成时返回 false。
func set_audio_backend(backend: GFAudioBackend) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	if _audio_backend == backend:
		return true
	if not _stop_backend_owned_sessions():
		return false
	if not _restore_ducked_buses_for_backend_transition(_audio_backend):
		return false
	if not _clear_audio_backend(true):
		return false
	_audio_backend = backend
	if _audio_backend != null:
		var setup_result: Dictionary = _dispatch_backend_call(&"setup", [self], _audio_backend)
		if not _backend_dispatch_completed(setup_result):
			return false
	return true


## 获取当前音频后端。
## [br]
## @api public
## [br]
## @return: 音频后端；未设置时返回 null。
func get_audio_backend() -> GFAudioBackend:
	return _audio_backend


## 清除当前音频后端。清除前会停止由该后端拥有的 BGM 与环境音会话，
## 并恢复、清除绑定当前 local/backend owner 的活跃 duck 作用域。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param dispose_backend: 是否调用后端 dispose()。
## [br]
## @return: 后端已清除；通道停止、duck 基准恢复或 backend dispose 未完成时返回 false。
func clear_audio_backend(dispose_backend: bool = true) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	if _audio_backend == null:
		return true
	if not _stop_backend_owned_sessions():
		return false
	if not _restore_ducked_buses_for_backend_transition(_audio_backend):
		return false
	return _clear_audio_backend(dispose_backend)


## 发布资源化音频事件。
## [br]
## @api public
## [br]
## @since 3.3.0
## [br]
## @param event: 音频事件资源。
## [br]
## @param options: 请求选项。
## [br]
## @return: 后端或 SFX 控制句柄；本地 BGM/环境音已发布或请求失败时返回 null。
## [br]
## @schema options: Dictionary，作为事件请求附加选项，会与 GFAudioEvent.to_request_options() 的结果合并。
func post_audio_event(event: GFAudioEvent, options: Dictionary = {}) -> GFAudioEmitterHandle:
	if _is_backend_dispatch_in_progress():
		return null
	if event == null or not event.has_request():
		return null
	var request_options: Dictionary = event.to_request_options(options)
	var expected_backend: GFAudioBackend = _audio_backend
	if expected_backend != null:
		var can_handle_result: Dictionary = _dispatch_backend_call(
			&"can_handle_event",
			[event, request_options],
			expected_backend
		)
		if not _backend_dispatch_completed(can_handle_result) or _audio_backend != expected_backend:
			return null
		if _backend_dispatch_returned_true(can_handle_result):
			var post_result: Dictionary = _dispatch_backend_call(
				&"post_event",
				[event, request_options],
				expected_backend
			)
			if not _backend_dispatch_completed(post_result) or _audio_backend != expected_backend:
				return null
			var backend_handle: GFAudioEmitterHandle = _backend_dispatch_handle(post_result)
			if backend_handle != null:
				return backend_handle

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
	if _is_backend_dispatch_in_progress():
		return false
	return _backend_dispatch_returned_true(
		_dispatch_backend_call(&"set_parameter", [parameter], _audio_backend)
	)


## 写入音频状态。
## [br]
## @api public
## [br]
## @param state: 状态请求。
## [br]
## @return: 后端已处理返回 true。
func set_audio_state(state: GFAudioState) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	return _backend_dispatch_returned_true(
		_dispatch_backend_call(&"set_state", [state], _audio_backend)
	)


## 写入音频开关。
## [br]
## @api public
## [br]
## @param audio_switch: 开关请求。
## [br]
## @return: 后端已处理返回 true。
func set_audio_switch(audio_switch: GFAudioSwitch) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	return _backend_dispatch_returned_true(
		_dispatch_backend_call(&"set_switch", [audio_switch], _audio_backend)
	)


## 播放环境音。每次替换都会先递增通道 generation，使旧加载和淡变回调失效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 音频资源路径。
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡入秒数。
func play_ambient(path: String, channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
	if path.is_empty():
		stop_ambient(channel, fade_seconds)
		return

	var request_serial: int = _begin_ambient_replacement(channel)
	if _try_backend_play_ambient_path(path, channel, {
		"fade_seconds": _finite_non_negative_or_zero(fade_seconds),
		"bus_name": BGM_BUS_NAME,
		"volume_db": 0.0,
		"pitch_scale": 1.0,
	}):
		_commit_backend_ambient_session(channel, request_serial)
		return

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		var stream: AudioStream = _get_audio_stream_value(load(path))
		_apply_ambient_request(request_serial, channel, stream, BGM_BUS_NAME, 0.0, 1.0, fade_seconds)
	else:
		var on_loaded: Callable = func(res: Resource) -> void:
			_apply_ambient_request(request_serial, channel, _get_audio_stream_value(res), BGM_BUS_NAME, 0.0, 1.0, fade_seconds)
		asset_util.load_async(path, on_loaded)


## 播放资源化环境音配置。每个通道在本地播放器与后端之间只保留一个 owner。
## [br]
## @api public
## [br]
## @since 8.0.0
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
	if _is_backend_dispatch_in_progress():
		return
	if clip == null or not clip.has_source():
		return

	var request_serial: int = _begin_ambient_replacement(channel)
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
		_commit_backend_ambient_session(channel, request_serial)
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


## 停止指定环境音通道。淡出完成只能终结调用时绑定的通道 generation。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param channel: 环境音通道。
## [br]
## @param fade_seconds: 淡出秒数。
func stop_ambient(channel: StringName = &"default", fade_seconds: float = 0.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var request_serial: int = _begin_ambient_replacement(channel)
	var session: Dictionary = _get_ambient_session(channel)
	var owner: StringName = GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
	if owner == _OWNER_BACKEND:
		if not _notify_backend_stop_ambient(channel, safe_fade):
			_set_ambient_session(channel, request_serial, _STATE_PLAYING, _OWNER_BACKEND, 0)
			return
		_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)
		return
	if owner != _OWNER_LOCAL:
		_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)
		return

	var player: AudioStreamPlayer = _get_ambient_player(channel)
	var playback_session_id: int = GFVariantData.get_option_int(session, "playback_session_id")
	_set_ambient_session(channel, request_serial, _STATE_STOPPING, _OWNER_LOCAL, playback_session_id)
	_start_ambient_session_stop(channel, request_serial, playback_session_id, player, safe_fade)


## 停止所有环境音通道。后端拥有的通道优先批量停止，失败时逐通道回退。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param fade_seconds: 淡出秒数。
func stop_all_ambient(fade_seconds: float = 0.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var channel_set: Dictionary = {}
	for channel_variant: Variant in _ambient_players.keys():
		channel_set[channel_variant] = true
	for channel_variant: Variant in _ambient_sessions.keys():
		channel_set[channel_variant] = true
	var channels: Array[StringName] = []
	var backend_channels: Array[StringName] = []
	for channel_variant: Variant in channel_set.keys():
		var channel: StringName = GFVariantData.to_string_name(channel_variant)
		channels.append(channel)
		var session: Dictionary = _get_ambient_session(channel)
		if GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE) == _OWNER_BACKEND:
			backend_channels.append(channel)
	channels.sort_custom(_is_string_name_lexically_before)
	backend_channels.sort_custom(_is_string_name_lexically_before)

	var backend_bulk_succeeded: bool = _try_backend_stop_all_ambient(
		backend_channels,
		safe_fade
	)
	for channel: StringName in channels:
		if backend_bulk_succeeded and backend_channels.has(channel):
			continue
		stop_ambient(channel, safe_fade)


## 检查环境音通道是否正在播放。
## [br]
## @api public
## [br]
## @param channel: 环境音通道。
## [br]
## @return: 正在播放时返回 true。
func is_ambient_playing(channel: StringName = &"default") -> bool:
	_converge_inactive_local_ambient_session(channel)
	var session: Dictionary = _get_ambient_session(channel)
	var owner: StringName = GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
	var state: StringName = GFVariantData.get_option_string_name(session, "state", _STATE_STOPPED)
	if owner == _OWNER_BACKEND:
		if state != _STATE_PLAYING or _audio_backend == null:
			return false
		var expected_backend: GFAudioBackend = _audio_backend
		var expected_generation: int = GFVariantData.get_option_int(session, "generation")
		var backend_result: Dictionary = _dispatch_backend_call(
			&"is_ambient_playing",
			[channel],
			expected_backend
		)
		if (
			not _backend_dispatch_completed(backend_result)
			or not _is_backend_ambient_session_current(
				channel,
				expected_generation,
				expected_backend
			)
		):
			return false
		if _backend_dispatch_returned_true(backend_result):
			return true
		var stopped_generation: int = _next_ambient_request_serial(channel)
		_set_ambient_session(channel, stopped_generation, _STATE_STOPPED, _OWNER_NONE, 0)
		return false
	if owner != _OWNER_LOCAL or state == _STATE_STOPPED:
		return false
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	return is_instance_valid(player) and player.playing


## 停止全部普通 SFX 与空间 SFX。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出秒数。
func stop_all_sfx(fade_seconds: float = 0.0) -> void:
	if _is_backend_dispatch_in_progress():
		return
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
	if _is_backend_dispatch_in_progress():
		return null
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
	if _is_backend_dispatch_in_progress():
		return null
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
	if _is_backend_dispatch_in_progress():
		return null
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
	if _is_backend_dispatch_in_progress():
		return null
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


## 获取环境音通道的控制句柄。句柄绑定当前播放 session，通道替换后旧句柄自动终结。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param channel: 环境音通道。
## [br]
## @return: 控制句柄；通道不存在时返回 null。
func get_ambient_handle(channel: StringName = &"default") -> GFAudioEmitterHandle:
	_converge_inactive_local_ambient_session(channel)
	var session: Dictionary = _get_ambient_session(channel)
	if (
		GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE) != _OWNER_LOCAL
		or GFVariantData.get_option_string_name(session, "state", _STATE_STOPPED) != _STATE_PLAYING
	):
		return null
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	var playback_session_id: int = GFVariantData.get_option_int(session, "playback_session_id")
	if not _is_playback_session_current(player, playback_session_id):
		return null
	var handle: GFAudioEmitterHandle = GFAudioEmitterHandle.new(null, Callable(), channel)
	_attach_handle_to_playback_session(
		handle,
		player,
		Callable(self, "_release_ambient_session").bind(channel)
	)
	return handle


## 设置音频总线 dB 音量。增益与静音作为同一代事务提交，后发操作会使旧 tween 失效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bus_name: 总线名称，如 "Master", "BGM", "SFX"。
## [br]
## @param volume_db: 目标 dB 音量；小于等于 SILENCE_VOLUME_DB 时会静音该总线。
## [br]
## @param transition_seconds: 平滑过渡秒数；小于等于 0 时立即应用。
## [br]
## @return: 成功应用或已交给后端处理时返回 true。
func set_bus_volume_db(bus_name: String, volume_db: float, transition_seconds: float = 0.0) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	if not _is_finite_float(volume_db) or not _is_finite_float(transition_seconds):
		return false
	var transaction_generation: int = _begin_bus_transaction(bus_name)
	if _backend_dispatch_returned_true(
		_dispatch_backend_call(
			&"set_bus_volume_db",
			[bus_name, volume_db, transition_seconds],
			_audio_backend
		)
	):
		return true

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("[GFAudioUtility] 无法找到音轨总线: " + bus_name)
		return false

	var target_db: float = maxf(volume_db, SILENCE_VOLUME_DB)
	return _start_local_bus_mix_transaction(
		bus_name,
		bus_index,
		target_db,
		target_db <= SILENCE_VOLUME_DB,
		transition_seconds,
		transaction_generation
	)


## 获取音频总线 dB 音量。
## [br]
## @api public
## [br]
## @param bus_name: 总线名称。
## [br]
## @return: dB 音量；总线不存在时返回 SILENCE_VOLUME_DB。
func get_bus_volume_db(bus_name: String) -> float:
	if _audio_backend != null:
		var backend_result: Dictionary = _dispatch_backend_call(
			&"get_bus_volume",
			[bus_name],
			_audio_backend
		)
		var backend_volume: float = _backend_dispatch_float(backend_result, -1.0)
		if backend_volume >= 0.0:
			return linear_to_db(maxf(backend_volume, 0.000001))

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return SILENCE_VOLUME_DB
	return AudioServer.get_bus_volume_db(bus_index)


## 设置音频总线静音状态，并取消同一总线上尚未提交的旧增益事务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bus_name: 总线名称。
## [br]
## @param muted: 是否静音。
## [br]
## @return: 成功应用或已交给后端处理时返回 true。
func set_bus_mute(bus_name: String, muted: bool) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	var _transaction_generation: int = _begin_bus_transaction(bus_name)
	if _backend_dispatch_returned_true(
		_dispatch_backend_call(&"set_bus_mute", [bus_name, muted], _audio_backend)
	):
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
	if _is_backend_dispatch_in_progress():
		return false
	if not _is_finite_float(transition_seconds):
		return false
	if _is_numeric_variant(value) and not _is_finite_numeric_variant(value):
		return false
	if _backend_dispatch_returned_true(
		_dispatch_backend_call(
			&"set_bus_effect_property",
			[bus_name, effect_ref, property_name, value, transition_seconds],
			_audio_backend
		)
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


## 捕获当前总线混音快照。原始增益与静音状态独立保存，静音不会覆盖增益值。
## [br]
## @api public
## [br]
## @since 8.0.0
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
		var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
		buses[bus_name] = {
			"volume_db": volume_db,
			"volume_linear": db_to_linear(volume_db),
			"muted": muted,
		}
	return {
		_MIX_SNAPSHOT_BUSES_KEY: buses,
	}


## 应用混音快照。先尝试 backend bulk 接管；拒绝后按字段 backend-first，
## 仅把明确未处理的增益或静音字段作为单个 local generation 事务回退。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param snapshot: 混音快照。
## [br]
## @schema snapshot: Dictionary，可包含 buses 字典和 effects 数组；buses 条目支持数值型 volume_db 简写，或包含 volume_db、volume_linear、muted 的字典；effects 条目支持 bus、effect、property、value、transition_seconds。
## [br]
## @param transition_seconds: 默认平滑过渡秒数；单个效果条目可覆盖。
## [br]
## @return: 应用报告。
## [br]
## @schema return: Dictionary，包含 ok、applied、failed 和 warnings 字段；backend identity 漂移、字段无本地回退目标或输入无效会进入 failed。
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
	if _is_backend_dispatch_in_progress():
		_append_mix_failure(report, "", "backend_reentry", "后端回调期间拒绝重入混音事务。")
		report["ok"] = false
		return report
	var expected_backend: GFAudioBackend = _audio_backend
	if expected_backend != null:
		var bulk_result: Dictionary = _dispatch_backend_call(
			&"apply_mix_snapshot",
			[snapshot, transition_seconds],
			expected_backend
		)
		if not _backend_dispatch_completed(bulk_result):
			_append_mix_failure(
				report,
				"",
				"backend_identity_changed",
				"混音快照 backend identity 在 bulk 派发期间发生变化。"
			)
			report["ok"] = false
			return report
		if _backend_dispatch_returned_true(bulk_result):
			return {
				"ok": true,
				"applied": PackedStringArray(["backend"]),
				"failed": [],
				"warnings": [],
			}

	_apply_mix_snapshot_buses(
		GFVariantData.get_option_value(snapshot, _MIX_SNAPSHOT_BUSES_KEY, {}),
		transition_seconds,
		report,
		expected_backend
	)
	_apply_mix_snapshot_effects(GFVariantData.get_option_value(snapshot, _MIX_SNAPSHOT_EFFECTS_KEY, []), transition_seconds, report)
	report["ok"] = _get_report_array(report, "failed").is_empty()
	return report


## 按比例压低总线音量。配置 backend 时优先捕获其同名总线，并把 owner/backend identity
## 固定到整个作用域生命周期；否则回退本地总线。每个总线采用活跃作用域中的最强衰减。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bus_name: 总线名称。
## [br]
## @param amount: 压低强度，0.0 不变化，1.0 最多压低 18 dB。
## [br]
## @param transition_seconds: 平滑过渡秒数。
## [br]
## @param duck_id: 同一总线上的压低作用域标识。
## [br]
## @return: 成功应用时返回 true；backend 只暴露部分基准字段或 owner setter 拒绝时失败关闭。
func duck_bus(
	bus_name: String = BGM_BUS_NAME,
	amount: float = 0.5,
	transition_seconds: float = 0.25,
	duck_id: StringName = &"default"
) -> bool:
	if _is_backend_dispatch_in_progress():
		return false
	if not _is_finite_float(amount) or not _is_finite_float(transition_seconds):
		return false
	var state: Dictionary = _get_duck_bus_state(bus_name)
	var state_was_created: bool = state.is_empty()
	if state_was_created:
		state = _capture_duck_bus_base_state(bus_name)
		if not GFVariantData.get_option_bool(state, "ok"):
			return false
		state["scopes"] = {}
	var scopes: Dictionary = GFVariantData.get_option_dictionary(state, "scopes")
	var had_previous_scope: bool = scopes.has(duck_id)
	var previous_amount: Variant = scopes.get(duck_id)
	scopes[duck_id] = clampf(amount, 0.0, 1.0)
	state["scopes"] = scopes
	_duck_bus_states[bus_name] = state
	if _apply_duck_bus_state(bus_name, transition_seconds):
		return true
	if state_was_created:
		_erase_dictionary_key(_duck_bus_states, bus_name)
	elif had_previous_scope:
		scopes[duck_id] = previous_amount
		state["scopes"] = scopes
		_duck_bus_states[bus_name] = state
	else:
		var _scope_erased: bool = scopes.erase(duck_id)
		state["scopes"] = scopes
		_duck_bus_states[bus_name] = state
	return false


## 释放一个 duck_bus() 作用域，并根据剩余作用域重新计算；结果与释放顺序无关。
## [br]
## @api public
## [br]
## @since 8.0.0
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
	if _is_backend_dispatch_in_progress():
		return false
	if not _is_finite_float(transition_seconds):
		return false
	var state: Dictionary = _get_duck_bus_state(bus_name)
	if state.is_empty():
		return false
	var scopes: Dictionary = GFVariantData.get_option_dictionary(state, "scopes")
	if not scopes.has(duck_id):
		return false
	var released_amount: Variant = scopes[duck_id]
	var _scope_erased: bool = scopes.erase(duck_id)
	state["scopes"] = scopes
	_duck_bus_states[bus_name] = state
	if _apply_duck_bus_state(bus_name, transition_seconds):
		if scopes.is_empty():
			_erase_dictionary_key(_duck_bus_states, bus_name)
		return true
	scopes[duck_id] = released_amount
	state["scopes"] = scopes
	_duck_bus_states[bus_name] = state
	return false


## 设置音频总线线性音量，并以新事务取代同一总线上的未完成过渡。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param bus_name: 总线名称，如 "Master", "BGM", "SFX"
## [br]
## @param volume_linear: 线性音量 (0.0 到 1.0)
func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	if _is_backend_dispatch_in_progress():
		return
	if not _is_finite_float(volume_linear):
		return
	var transaction_generation: int = _begin_bus_transaction(bus_name)
	if _backend_dispatch_returned_true(
		_dispatch_backend_call(&"set_bus_volume", [bus_name, volume_linear], _audio_backend)
	):
		return

	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var target_db: float = (
			SILENCE_VOLUME_DB
			if volume_linear <= 0.0
			else linear_to_db(minf(volume_linear, 1.0))
		)
		var _applied: bool = _start_local_bus_mix_transaction(
			bus_name,
			bus_idx,
			target_db,
			volume_linear <= 0.0,
			0.0,
			transaction_generation
		)
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
		var backend_result: Dictionary = _dispatch_backend_call(
			&"get_bus_volume",
			[bus_name],
			_audio_backend
		)
		var backend_volume: float = _backend_dispatch_float(backend_result, -1.0)
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
## @since 8.0.0
## [br]
## @return: 调试快照。
## [br]
## @schema return: Dictionary，包含 backend、backend_snapshot、backend_capabilities、current_bgm_key、current_bgm_loop、bgm_state、bgm_owner、bgm_generation、bgm_playing、bgm_paused、bgm_position、bgm_history、active_sfx_count、active_spatial_sfx_count、max_sfx_players、ambient_channels、ambient_sessions、audio_bank_count、ducked_bus_count 和 active_mix_tween_count 字段。
func get_debug_snapshot() -> Dictionary:
	_prune_inactive_sfx_players()
	_prune_inactive_spatial_sfx_players()
	var bgm_playing: bool = is_bgm_playing()
	var ambient_channels: PackedStringArray = PackedStringArray()
	var ambient_session_snapshot: Dictionary = {}
	for channel_variant: Variant in _ambient_sessions.keys():
		var channel: String = GFVariantData.to_text(channel_variant)
		if is_ambient_playing(StringName(channel)):
			_append_packed_string(ambient_channels, channel)
		var session: Dictionary = _get_ambient_session(StringName(channel))
		ambient_session_snapshot[channel] = {
			"generation": GFVariantData.get_option_int(session, "generation"),
			"state": String(GFVariantData.get_option_string_name(session, "state", _STATE_STOPPED)),
			"owner": String(GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)),
			"playback_session_id": GFVariantData.get_option_int(session, "playback_session_id"),
		}
	ambient_channels.sort()

	var backend_snapshot: Dictionary = {}
	var backend_capabilities: Dictionary = {}
	var backend_name: String = ""
	if _audio_backend != null:
		var expected_backend: GFAudioBackend = _audio_backend
		var backend_script: Script = _get_script_value(expected_backend.get_script())
		backend_name = backend_script.resource_path if backend_script != null else expected_backend.get_class()
		var snapshot_result: Dictionary = _dispatch_backend_call(
			&"get_debug_snapshot",
			[],
			expected_backend
		)
		if _backend_dispatch_completed(snapshot_result):
			backend_snapshot = _backend_dispatch_dictionary(snapshot_result)
		var capabilities_result: Dictionary = _dispatch_backend_call(
			&"get_capabilities",
			[],
			expected_backend
		)
		var capabilities_value: Variant = GFVariantData.get_option_value(
			capabilities_result,
			"value"
		)
		if _backend_dispatch_completed(capabilities_result) and capabilities_value is GFAudioBackendCapability:
			var capabilities: GFAudioBackendCapability = capabilities_value
			backend_capabilities = capabilities.to_dictionary()

	return {
		"backend": backend_name,
		"backend_snapshot": backend_snapshot,
		"backend_capabilities": backend_capabilities,
		"current_bgm_key": _current_bgm_key,
		"current_bgm_loop": _current_bgm_loop,
		"bgm_state": String(_bgm_state),
		"bgm_owner": String(_bgm_owner),
		"bgm_generation": _bgm_generation,
		"bgm_playing": bgm_playing,
		"bgm_paused": is_bgm_paused(),
		"bgm_position": get_bgm_playback_position(),
		"bgm_history": get_bgm_history(),
		"active_sfx_count": _get_tracked_normal_sfx_count(),
		"active_spatial_sfx_count": _get_tracked_spatial_sfx_count(),
		"max_sfx_players": max_sfx_players,
		"ambient_channels": ambient_channels,
		"ambient_sessions": ambient_session_snapshot,
		"audio_bank_count": _audio_banks.size(),
		"ducked_bus_count": _duck_bus_states.size(),
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


func _is_backend_dispatch_in_progress() -> bool:
	return _backend_dispatch_depth > 0


func _dispatch_backend_call(
	method_name: StringName,
	arguments: Array,
	expected_backend: GFAudioBackend
) -> Dictionary:
	if (
		expected_backend == null
		or _is_backend_dispatch_in_progress()
		or _audio_backend != expected_backend
	):
		return {
			"called": false,
			"backend_current": _audio_backend == expected_backend,
			"value": null,
		}
	_backend_dispatch_depth += 1
	var value: Variant = expected_backend.callv(method_name, arguments)
	_backend_dispatch_depth -= 1
	return {
		"called": true,
		"backend_current": _audio_backend == expected_backend,
		"value": value,
	}


func _backend_dispatch_completed(result: Dictionary) -> bool:
	return (
		GFVariantData.get_option_bool(result, "called")
		and GFVariantData.get_option_bool(result, "backend_current")
	)


func _backend_dispatch_returned_true(result: Dictionary) -> bool:
	if not _backend_dispatch_completed(result):
		return false
	var value: Variant = GFVariantData.get_option_value(result, "value")
	return value is bool and value


func _backend_dispatch_float(result: Dictionary, default_value: float) -> float:
	if not _backend_dispatch_completed(result):
		return default_value
	var value: Variant = GFVariantData.get_option_value(result, "value")
	if not _is_numeric_variant(value):
		return default_value
	return GFVariantData.to_float(value, default_value)


func _backend_dispatch_dictionary(result: Dictionary) -> Dictionary:
	if not _backend_dispatch_completed(result):
		return {}
	var value: Variant = GFVariantData.get_option_value(result, "value")
	return GFVariantData.as_dictionary(value)


func _backend_dispatch_handle(result: Dictionary) -> GFAudioEmitterHandle:
	if not _backend_dispatch_completed(result):
		return null
	var value: Variant = GFVariantData.get_option_value(result, "value")
	if value is GFAudioEmitterHandle:
		var handle: GFAudioEmitterHandle = value
		return handle
	return null


func _notify_backend_stop_bgm(fade_seconds: float) -> bool:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _bgm_request_serial
	var expected_generation: int = _bgm_generation
	var expected_owner: StringName = _bgm_owner
	if expected_backend == null:
		return false
	var result: Dictionary = _dispatch_backend_call(
		&"stop_bgm",
		[_finite_non_negative_or_zero(fade_seconds)],
		expected_backend
	)
	return (
		_backend_dispatch_returned_true(result)
		and _audio_backend == expected_backend
		and _bgm_request_serial == expected_request_serial
		and _bgm_generation == expected_generation
		and _bgm_owner == expected_owner
	)


func _notify_backend_stop_ambient(channel: StringName, fade_seconds: float) -> bool:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _get_ambient_request_serial(channel)
	var expected_session: Dictionary = _get_ambient_session(channel)
	var expected_owner: StringName = GFVariantData.get_option_string_name(
		expected_session,
		"owner",
		_OWNER_NONE
	)
	if expected_backend == null:
		return false
	var result: Dictionary = _dispatch_backend_call(
		&"stop_ambient",
		[channel, _finite_non_negative_or_zero(fade_seconds)],
		expected_backend
	)
	var current_session: Dictionary = _get_ambient_session(channel)
	return (
		_backend_dispatch_returned_true(result)
		and _audio_backend == expected_backend
		and _get_ambient_request_serial(channel) == expected_request_serial
		and GFVariantData.get_option_string_name(
			current_session,
			"owner",
			_OWNER_NONE
		) == expected_owner
	)


func _notify_backend_stop_all_sfx(fade_seconds: float) -> void:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_lifecycle_serial: int = _sfx_lifecycle_serial
	if expected_backend == null:
		return
	var handled: bool = _backend_dispatch_returned_true(
		_dispatch_backend_call(
			&"stop_all_sfx",
			[_finite_non_negative_or_zero(fade_seconds)],
			expected_backend
		)
	)
	if _audio_backend != expected_backend or _sfx_lifecycle_serial != expected_lifecycle_serial:
		return
	if handled:
		return


func _forget_audio_handle(handle: GFAudioEmitterHandle) -> void:
	if handle == null:
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


func _begin_bus_transaction(bus_name: String) -> int:
	_bus_generation_counter += 1
	var generation: int = _bus_generation_counter
	_bus_transaction_generations[bus_name] = generation
	_kill_bus_volume_tween(bus_name)
	return generation


func _is_bus_transaction_current(bus_name: String, generation: int) -> bool:
	return generation > 0 and GFVariantData.to_int(
		_bus_transaction_generations.get(bus_name)
	) == generation


func _start_local_bus_mix_transaction(
	bus_name: String,
	bus_index: int,
	volume_db: float,
	muted: bool,
	transition_seconds: float,
	generation: int
) -> bool:
	if bus_index < 0 or not _is_bus_transaction_current(bus_name, generation):
		return false
	var target_db: float = maxf(volume_db, SILENCE_VOLUME_DB)
	if transition_seconds <= 0.0:
		_apply_bus_gain_db(bus_index, target_db)
		AudioServer.set_bus_mute(bus_index, muted)
		return true

	var was_muted: bool = AudioServer.is_bus_mute(bus_index)
	var start_db: float = AudioServer.get_bus_volume_db(bus_index)
	if was_muted and not muted:
		_apply_bus_gain_db(bus_index, SILENCE_VOLUME_DB)
		AudioServer.set_bus_mute(bus_index, false)
		start_db = SILENCE_VOLUME_DB

	var tween: Tween = _create_tween_or_null()
	if tween == null:
		_apply_bus_gain_db(bus_index, target_db)
		AudioServer.set_bus_mute(bus_index, muted)
		return true

	_bus_volume_tween_refs[bus_name] = weakref(tween)
	_add_tween_method(
		tween,
		Callable(self, "_apply_bus_volume_tween_value").bind(bus_name, generation),
		start_db,
		target_db,
		maxf(transition_seconds, 0.0)
	)
	_connect_signal_checked(
		tween.finished,
		Callable(self, "_finish_bus_volume_tween").bind(
			bus_name,
			generation,
			target_db,
			muted
		),
		CONNECT_ONE_SHOT
	)
	return true


func _apply_bus_gain_db(bus_index: int, volume_db: float) -> void:
	if bus_index < 0 or not _is_finite_float(volume_db):
		return
	var target_db: float = maxf(volume_db, SILENCE_VOLUME_DB)
	AudioServer.set_bus_volume_db(bus_index, target_db)


func _apply_bus_volume_tween_value(
	value: float,
	bus_name: String,
	generation: int
) -> void:
	if not _is_finite_float(value) or not _is_bus_transaction_current(bus_name, generation):
		return
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		_apply_bus_gain_db(bus_index, value)


func _finish_bus_volume_tween(
	bus_name: String,
	generation: int,
	target_db: float,
	muted: bool
) -> void:
	if not _is_bus_transaction_current(bus_name, generation):
		return
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		_apply_bus_gain_db(bus_index, target_db)
		AudioServer.set_bus_mute(bus_index, muted)
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
	for bus_name_variant: Variant in _bus_transaction_generations.keys():
		var bus_name: String = GFVariantData.to_text(bus_name_variant)
		_bus_generation_counter += 1
		_bus_transaction_generations[bus_name] = _bus_generation_counter
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


func _apply_mix_snapshot_buses(
	bus_payload: Variant,
	transition_seconds: float,
	report: Dictionary,
	expected_backend: GFAudioBackend
) -> void:
	if not (bus_payload is Dictionary):
		if bus_payload != null:
			_append_mix_warning(report, "buses 字段必须是 Dictionary。")
		return

	var buses: Dictionary = GFVariantData.as_dictionary(bus_payload)
	for bus_key: Variant in buses.keys():
		var bus_name: String = str(bus_key)
		var bus_entry: Variant = buses[bus_key]
		if bus_entry is Dictionary:
			_apply_mix_snapshot_bus_entry(
				bus_name,
				GFVariantData.as_dictionary(bus_entry),
				transition_seconds,
				report,
				expected_backend
			)
		elif _is_numeric_variant(bus_entry):
			_apply_mix_snapshot_bus_entry(
				bus_name,
				{ "volume_db": GFVariantData.to_float(bus_entry) },
				transition_seconds,
				report,
				expected_backend
			)
		else:
			_append_mix_failure(report, bus_name, "invalid_bus_entry", "总线快照条目必须是 Dictionary 或数值。")


func _apply_mix_snapshot_bus_entry(
	bus_name: String,
	entry: Dictionary,
	transition_seconds: float,
	report: Dictionary,
	expected_backend: GFAudioBackend
) -> void:
	var entry_transition: float = GFVariantData.get_option_float(entry, "transition_seconds", transition_seconds)
	if not _is_finite_float(entry_transition):
		_append_mix_failure(report, bus_name, "non_finite_transition", "总线过渡时间必须是有限值。")
		return
	var has_volume: bool = entry.has("volume_db") or entry.has("volume_linear")
	var has_mute: bool = entry.has("muted")
	if not has_volume and not has_mute:
		_append_mix_warning(report, "总线 %s 的快照条目没有可应用字段。" % bus_name)
		return

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	var target_db: float = AudioServer.get_bus_volume_db(bus_index) if bus_index >= 0 else 0.0
	if entry.has("volume_db"):
		target_db = GFVariantData.to_float(entry["volume_db"])
		if not _is_finite_float(target_db):
			_append_mix_failure(report, bus_name, "non_finite_volume", "总线音量必须是有限值。")
			return
	elif entry.has("volume_linear"):
		var linear_volume: float = GFVariantData.to_float(entry["volume_linear"])
		if not _is_finite_float(linear_volume):
			_append_mix_failure(report, bus_name, "non_finite_volume", "线性总线音量必须是有限值。")
			return
		linear_volume = maxf(linear_volume, 0.0)
		target_db = SILENCE_VOLUME_DB if linear_volume <= 0.0 else linear_to_db(linear_volume)

	var target_muted: bool = (
		GFVariantData.to_bool(entry["muted"])
		if has_mute
		else (AudioServer.is_bus_mute(bus_index) if bus_index >= 0 else false)
	)

	var backend_volume_handled: bool = false
	if has_volume and expected_backend != null:
		var volume_result: Dictionary = _dispatch_backend_call(
			&"set_bus_volume_db",
			[bus_name, target_db, entry_transition],
			expected_backend
		)
		if not _backend_dispatch_completed(volume_result):
			_append_mix_failure(
				report,
				bus_name,
				"backend_identity_changed",
				"设置总线音量时 backend identity 发生变化。"
			)
			return
		backend_volume_handled = _backend_dispatch_returned_true(volume_result)

	var backend_mute_handled: bool = false
	if has_mute and expected_backend != null:
		var mute_result: Dictionary = _dispatch_backend_call(
			&"set_bus_mute",
			[bus_name, target_muted],
			expected_backend
		)
		if not _backend_dispatch_completed(mute_result):
			_append_mix_failure(
				report,
				bus_name,
				"backend_identity_changed",
				"设置总线静音时 backend identity 发生变化。"
			)
			return
		backend_mute_handled = _backend_dispatch_returned_true(mute_result)

	if backend_volume_handled:
		_append_mix_applied(report, "bus:%s:volume_db" % bus_name)
	if backend_mute_handled:
		_append_mix_applied(report, "bus:%s:muted" % bus_name)

	var apply_local_volume: bool = has_volume and not backend_volume_handled
	var apply_local_mute: bool = has_mute and not backend_mute_handled
	if not apply_local_volume and not apply_local_mute:
		return
	if bus_index < 0:
		if apply_local_volume:
			_append_mix_failure(report, bus_name, "missing_bus", "无法设置总线音量。")
		if apply_local_mute:
			_append_mix_failure(report, bus_name, "missing_bus", "无法设置总线静音状态。")
		return

	var local_target_db: float = (
		target_db
		if apply_local_volume
		else AudioServer.get_bus_volume_db(bus_index)
	)
	var local_target_muted: bool = (
		target_muted
		if apply_local_mute
		else AudioServer.is_bus_mute(bus_index)
	)
	var transaction_generation: int = _begin_bus_transaction(bus_name)
	if not _start_local_bus_mix_transaction(
		bus_name,
		bus_index,
		local_target_db,
		local_target_muted,
		entry_transition,
		transaction_generation
	):
		_append_mix_failure(report, bus_name, "missing_bus", "无法应用总线混音状态。")
		return
	if apply_local_volume:
		_append_mix_applied(report, "bus:%s:volume_db" % bus_name)
	if apply_local_mute:
		_append_mix_applied(report, "bus:%s:muted" % bus_name)


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


func _get_duck_bus_state(bus_name: String) -> Dictionary:
	var state_value: Variant = _duck_bus_states.get(bus_name)
	if state_value is Dictionary:
		var state: Dictionary = state_value
		return state
	return {}


func _capture_duck_bus_base_state(bus_name: String) -> Dictionary:
	if _is_backend_dispatch_in_progress():
		return { "ok": false }
	var expected_backend: GFAudioBackend = _audio_backend
	if expected_backend != null:
		var volume_result: Dictionary = _dispatch_backend_call(
			&"get_bus_volume",
			[bus_name],
			expected_backend
		)
		if not _backend_dispatch_completed(volume_result):
			return { "ok": false }
		var mute_result: Dictionary = _dispatch_backend_call(
			&"get_bus_mute",
			[bus_name],
			expected_backend
		)
		if not _backend_dispatch_completed(mute_result):
			return { "ok": false }
		var volume_value: Variant = GFVariantData.get_option_value(volume_result, "value")
		var mute_value: Variant = GFVariantData.get_option_value(mute_result, "value")
		var backend_volume_observed: bool = (
			_is_numeric_variant(volume_value)
			and _is_finite_numeric_variant(volume_value)
			and GFVariantData.to_float(volume_value) >= 0.0
		)
		var backend_mute_observed: bool = mute_value is bool
		if backend_volume_observed != backend_mute_observed:
			return { "ok": false }
		if backend_volume_observed:
			var base_linear: float = GFVariantData.to_float(volume_value)
			return {
				"ok": true,
				"owner": _OWNER_BACKEND,
				"backend": expected_backend,
				"base_db": (
					SILENCE_VOLUME_DB
					if base_linear <= 0.0
					else maxf(linear_to_db(base_linear), SILENCE_VOLUME_DB)
				),
				"base_muted": mute_value,
			}

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return { "ok": false }
	return {
		"ok": true,
		"owner": _OWNER_LOCAL,
		"backend": null,
		"base_db": AudioServer.get_bus_volume_db(bus_index),
		"base_muted": AudioServer.is_bus_mute(bus_index),
	}


func _get_duck_state_backend(state: Dictionary) -> GFAudioBackend:
	var backend_value: Variant = GFVariantData.get_option_value(state, "backend")
	if backend_value is GFAudioBackend:
		var backend: GFAudioBackend = backend_value
		return backend
	return null


func _apply_backend_duck_bus_mix_state(
	bus_name: String,
	state: Dictionary,
	target_db: float,
	target_muted: bool,
	transition_seconds: float
) -> bool:
	var expected_backend: GFAudioBackend = _get_duck_state_backend(state)
	if expected_backend == null or _audio_backend != expected_backend:
		return false
	var mute_result: Dictionary = _dispatch_backend_call(
		&"set_bus_mute",
		[bus_name, target_muted],
		expected_backend
	)
	if not _backend_dispatch_returned_true(mute_result) or _audio_backend != expected_backend:
		return false
	var volume_result: Dictionary = _dispatch_backend_call(
		&"set_bus_volume_db",
		[bus_name, target_db, transition_seconds],
		expected_backend
	)
	return _backend_dispatch_returned_true(volume_result) and _audio_backend == expected_backend


func _apply_duck_bus_mix_state(
	bus_name: String,
	state: Dictionary,
	target_db: float,
	target_muted: bool,
	transition_seconds: float
) -> bool:
	var owner: StringName = GFVariantData.get_option_string_name(
		state,
		"owner",
		_OWNER_NONE
	)
	if owner == _OWNER_BACKEND:
		return _apply_backend_duck_bus_mix_state(
			bus_name,
			state,
			target_db,
			target_muted,
			transition_seconds
		)
	if owner != _OWNER_LOCAL:
		return false

	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false
	var generation: int = _begin_bus_transaction(bus_name)
	return _start_local_bus_mix_transaction(
		bus_name,
		bus_index,
		target_db,
		target_muted,
		transition_seconds,
		generation
	)


func _restore_ducked_buses_for_backend_transition(expected_backend: GFAudioBackend) -> bool:
	var bus_names: PackedStringArray = PackedStringArray()
	for bus_name_value: Variant in _duck_bus_states.keys():
		var bus_name: String = GFVariantData.to_text(bus_name_value)
		var state: Dictionary = _get_duck_bus_state(bus_name)
		var owner: StringName = GFVariantData.get_option_string_name(
			state,
			"owner",
			_OWNER_NONE
		)
		if owner == _OWNER_BACKEND and _get_duck_state_backend(state) != expected_backend:
			return false
		if owner != _OWNER_BACKEND and owner != _OWNER_LOCAL:
			return false
		_append_packed_string(bus_names, bus_name)
	bus_names.sort()
	for bus_name: String in bus_names:
		var state: Dictionary = _get_duck_bus_state(bus_name)
		if not _restore_duck_bus_base_for_lifecycle(bus_name, state):
			return false
		_erase_dictionary_key(_duck_bus_states, bus_name)
	return true


func _apply_duck_bus_state(bus_name: String, transition_seconds: float) -> bool:
	var state: Dictionary = _get_duck_bus_state(bus_name)
	if state.is_empty():
		return false
	var scopes: Dictionary = GFVariantData.get_option_dictionary(state, "scopes")
	var strongest_amount: float = 0.0
	for amount_value: Variant in scopes.values():
		strongest_amount = maxf(
			strongest_amount,
			clampf(GFVariantData.to_float(amount_value), 0.0, 1.0)
		)
	var base_db: float = GFVariantData.get_option_float(state, "base_db", SILENCE_VOLUME_DB)
	var target_db: float = base_db - strongest_amount * 18.0
	return _apply_duck_bus_mix_state(
		bus_name,
		state,
		target_db,
		GFVariantData.get_option_bool(state, "base_muted"),
		transition_seconds
	)


func _restore_all_ducked_buses_for_lifecycle() -> bool:
	if _duck_bus_states.is_empty():
		return true
	var bus_names: PackedStringArray = PackedStringArray()
	for bus_name_variant: Variant in _duck_bus_states.keys():
		_append_packed_string(bus_names, GFVariantData.to_text(bus_name_variant))
	bus_names.sort()

	var restored_all: bool = true
	for bus_name: String in bus_names:
		var state: Dictionary = _get_duck_bus_state(bus_name)
		if state.is_empty() or _restore_duck_bus_base_for_lifecycle(bus_name, state):
			continue
		restored_all = false
		push_warning(
			"[GFAudioUtility] 生命周期清理无法恢复 duck 总线 \"%s\" 的基准混音。"
			% bus_name
		)
	return restored_all


func _restore_duck_bus_base_for_lifecycle(bus_name: String, state: Dictionary) -> bool:
	var base_db: float = GFVariantData.get_option_float(state, "base_db", SILENCE_VOLUME_DB)
	var base_muted: bool = GFVariantData.get_option_bool(state, "base_muted")
	return _apply_duck_bus_mix_state(
		bus_name,
		state,
		base_db,
		base_muted,
		0.0
	)


func _clear_audio_backend(dispose_backend: bool) -> bool:
	if _audio_backend == null:
		return true
	var expected_backend: GFAudioBackend = _audio_backend
	if dispose_backend:
		var dispose_result: Dictionary = _dispatch_backend_call(
			&"dispose",
			[],
			expected_backend
		)
		if not _backend_dispatch_completed(dispose_result):
			return false
	_audio_backend = null
	return true


func _stop_backend_owned_sessions() -> bool:
	if _audio_backend == null:
		return true
	if _is_backend_dispatch_in_progress():
		return false
	var expected_backend: GFAudioBackend = _audio_backend
	var backend_owns_bgm: bool = _bgm_owner == _OWNER_BACKEND
	var backend_ambient_channels: Array[StringName] = []
	for channel_variant: Variant in _ambient_sessions.keys():
		var channel: StringName = GFVariantData.to_string_name(channel_variant)
		var session: Dictionary = _get_ambient_session(channel)
		if GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE) != _OWNER_BACKEND:
			continue
		backend_ambient_channels.append(channel)
	backend_ambient_channels.sort_custom(_is_string_name_lexically_before)

	if backend_owns_bgm:
		if not _notify_backend_stop_bgm(0.0):
			return false
		_bgm_request_serial += 1
		_bgm_generation += 1
		_clear_bgm_session_state()
		_current_bgm_key = ""
		_current_bgm_loop = null
	for channel: StringName in backend_ambient_channels:
		if _audio_backend != expected_backend:
			return false
		var session: Dictionary = _get_ambient_session(channel)
		if GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE) != _OWNER_BACKEND:
			return false
		if not _notify_backend_stop_ambient(channel, 0.0):
			return false
		var generation: int = _next_ambient_request_serial(channel)
		_set_ambient_session(channel, generation, _STATE_STOPPED, _OWNER_NONE, 0)
	return _audio_backend == expected_backend


func _try_backend_stop_all_ambient(
	backend_channels: Array[StringName],
	fade_seconds: float
) -> bool:
	if backend_channels.is_empty() or _audio_backend == null:
		return backend_channels.is_empty()
	if _is_backend_dispatch_in_progress():
		return false

	var expected_backend: GFAudioBackend = _audio_backend
	var expected_generations: Dictionary = {}
	for channel: StringName in backend_channels:
		var session: Dictionary = _get_ambient_session(channel)
		var generation: int = GFVariantData.get_option_int(session, "generation")
		if not _is_backend_ambient_session_current(channel, generation, expected_backend):
			return false
		expected_generations[channel] = generation

	var bulk_result: Dictionary = _dispatch_backend_call(
		&"stop_all_ambient",
		[fade_seconds],
		expected_backend
	)
	if not _backend_dispatch_returned_true(bulk_result):
		return false
	for channel: StringName in backend_channels:
		var expected_generation: int = GFVariantData.get_option_int(
			expected_generations,
			channel
		)
		if not _is_backend_ambient_session_current(
			channel,
			expected_generation,
			expected_backend
		):
			return false

	for channel: StringName in backend_channels:
		var stopped_generation: int = _next_ambient_request_serial(channel)
		_set_ambient_session(channel, stopped_generation, _STATE_STOPPED, _OWNER_NONE, 0)
	return true


func _is_backend_ambient_session_current(
	channel: StringName,
	expected_generation: int,
	expected_backend: GFAudioBackend
) -> bool:
	var session: Dictionary = _get_ambient_session(channel)
	return (
		expected_backend != null
		and _audio_backend == expected_backend
		and _get_ambient_request_serial(channel) == expected_generation
		and GFVariantData.get_option_int(session, "generation") == expected_generation
		and GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
		== _OWNER_BACKEND
		and GFVariantData.get_option_string_name(session, "state", _STATE_STOPPED)
		== _STATE_PLAYING
	)


func _is_string_name_lexically_before(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)


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
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _bgm_request_serial
	var expected_generation: int = _bgm_generation
	var expected_owner: StringName = _bgm_owner
	if expected_backend == null:
		return false
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_path",
		[path, &"bgm", options],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or _audio_backend != expected_backend
		or _bgm_request_serial != expected_request_serial
		or _bgm_generation != expected_generation
		or _bgm_owner != expected_owner
	):
		return false
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_bgm_path",
		[path, options],
		expected_backend
	)
	return (
		_backend_dispatch_returned_true(play_result)
		and _audio_backend == expected_backend
		and _bgm_request_serial == expected_request_serial
		and _bgm_generation == expected_generation
		and _bgm_owner == expected_owner
	)


func _try_backend_play_bgm_clip(clip: GFAudioClip, options: Dictionary) -> bool:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _bgm_request_serial
	var expected_generation: int = _bgm_generation
	var expected_owner: StringName = _bgm_owner
	if expected_backend == null:
		return false
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_clip",
		[clip, &"bgm", options],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or _audio_backend != expected_backend
		or _bgm_request_serial != expected_request_serial
		or _bgm_generation != expected_generation
		or _bgm_owner != expected_owner
	):
		return false
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_bgm_clip",
		[clip, options],
		expected_backend
	)
	return (
		_backend_dispatch_returned_true(play_result)
		and _audio_backend == expected_backend
		and _bgm_request_serial == expected_request_serial
		and _bgm_generation == expected_generation
		and _bgm_owner == expected_owner
	)


func _try_backend_play_ambient_path(path: String, channel: StringName, options: Dictionary) -> bool:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _get_ambient_request_serial(channel)
	var expected_session: Dictionary = _get_ambient_session(channel)
	var expected_owner: StringName = GFVariantData.get_option_string_name(
		expected_session,
		"owner",
		_OWNER_NONE
	)
	if expected_backend == null:
		return false
	var context: Dictionary = options.duplicate(true)
	context["ambient_channel"] = channel
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_path",
		[path, &"ambient", context],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or not _is_ambient_backend_request_current(
			channel,
			expected_request_serial,
			expected_owner,
			expected_backend
		)
	):
		return false
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_ambient_path",
		[path, channel, options],
		expected_backend
	)
	return (
		_backend_dispatch_returned_true(play_result)
		and _is_ambient_backend_request_current(
			channel,
			expected_request_serial,
			expected_owner,
			expected_backend
		)
	)


func _try_backend_play_ambient_clip(clip: GFAudioClip, channel: StringName, options: Dictionary) -> bool:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_request_serial: int = _get_ambient_request_serial(channel)
	var expected_session: Dictionary = _get_ambient_session(channel)
	var expected_owner: StringName = GFVariantData.get_option_string_name(
		expected_session,
		"owner",
		_OWNER_NONE
	)
	if expected_backend == null:
		return false
	var context: Dictionary = options.duplicate(true)
	context["ambient_channel"] = channel
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_clip",
		[clip, &"ambient", context],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or not _is_ambient_backend_request_current(
			channel,
			expected_request_serial,
			expected_owner,
			expected_backend
		)
	):
		return false
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_ambient_clip",
		[clip, channel, options],
		expected_backend
	)
	return (
		_backend_dispatch_returned_true(play_result)
		and _is_ambient_backend_request_current(
			channel,
			expected_request_serial,
			expected_owner,
			expected_backend
		)
	)


func _is_ambient_backend_request_current(
	channel: StringName,
	expected_request_serial: int,
	expected_owner: StringName,
	expected_backend: GFAudioBackend
) -> bool:
	var session: Dictionary = _get_ambient_session(channel)
	return (
		_audio_backend == expected_backend
		and _get_ambient_request_serial(channel) == expected_request_serial
		and GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
		== expected_owner
	)


func _try_backend_play_sfx_path(path: String, options: Dictionary) -> GFAudioEmitterHandle:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_lifecycle_serial: int = _sfx_lifecycle_serial
	if expected_backend == null:
		return null
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_path",
		[path, &"sfx", options],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or _audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_sfx_path",
		[path, options],
		expected_backend
	)
	if (
		_audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	return _backend_dispatch_handle(play_result)


func _try_backend_play_sfx_clip(clip: GFAudioClip, options: Dictionary) -> GFAudioEmitterHandle:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_lifecycle_serial: int = _sfx_lifecycle_serial
	if expected_backend == null:
		return null
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_clip",
		[clip, &"sfx", options],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or _audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_sfx_clip",
		[clip, options],
		expected_backend
	)
	if (
		_audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	return _backend_dispatch_handle(play_result)


func _try_backend_play_spatial_sfx_clip(
	clip: GFAudioClip,
	source: Node,
	follow_source: bool,
	options: Dictionary
) -> GFAudioEmitterHandle:
	var expected_backend: GFAudioBackend = _audio_backend
	var expected_lifecycle_serial: int = _sfx_lifecycle_serial
	if expected_backend == null:
		return null
	var context: Dictionary = options.duplicate(true)
	context["follow_source"] = follow_source
	context["source"] = source
	context["spatial_settings"] = _get_clip_spatial_settings(clip)
	var can_handle_result: Dictionary = _dispatch_backend_call(
		&"can_handle_clip",
		[clip, &"spatial_sfx", context],
		expected_backend
	)
	if (
		not _backend_dispatch_returned_true(can_handle_result)
		or _audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	var play_result: Dictionary = _dispatch_backend_call(
		&"play_spatial_sfx_clip",
		[clip, source, follow_source, context],
		expected_backend
	)
	if (
		_audio_backend != expected_backend
		or _sfx_lifecycle_serial != expected_lifecycle_serial
	):
		return null
	return _backend_dispatch_handle(play_result)


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
	if _is_backend_dispatch_in_progress():
		return null
	if clip == null or not clip.has_source() or not is_instance_valid(source):
		return null
	if not _ensure_sfx_capacity_available():
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
		_set_playback_session_state(player_2d, playback_session_id, _STATE_PLAYING)
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
		_set_playback_session_state(player_3d, playback_session_id, _STATE_PLAYING)
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

	var request_serial: int = _begin_bgm_replacement()
	_commit_local_bgm_request(
		request_serial,
		stream,
		bus_name,
		volume_db,
		pitch_scale,
		crossfade_seconds,
		history_key,
		loop_override
	)


func _begin_bgm_replacement() -> int:
	_bgm_request_serial += 1
	_bgm_generation += 1
	_bgm_pause_serial += 1
	_cancel_bgm_stop_tween()
	_cancel_bgm_transport_tween()
	_bgm_paused = false
	if _bgm_state == _STATE_CROSSFADING:
		_abort_bgm_incoming_session(false)
	_bgm_state = _STATE_LOADING
	return _bgm_request_serial


func _commit_backend_bgm_session(
	request_serial: int,
	history_key: String,
	loop_override: Variant
) -> void:
	if request_serial != _bgm_request_serial:
		return
	if _bgm_owner == _OWNER_LOCAL:
		_stop_all_local_bgm_players()
	_bgm_owner = _OWNER_BACKEND
	_bgm_state = _STATE_PLAYING
	_current_bgm_loop = loop_override
	_record_bgm_history(history_key)


func _is_backend_bgm_session_current(
	expected_backend: GFAudioBackend,
	expected_request_serial: int,
	expected_generation: int,
	expected_state: StringName,
	expected_history_key: String
) -> bool:
	return (
		expected_backend != null
		and _audio_backend == expected_backend
		and _bgm_owner == _OWNER_BACKEND
		and _bgm_request_serial == expected_request_serial
		and _bgm_generation == expected_generation
		and _bgm_state == expected_state
		and _current_bgm_key == expected_history_key
	)


func _commit_backend_bgm_natural_end(history_key: String) -> void:
	_bgm_request_serial += 1
	_bgm_generation += 1
	_bgm_fade_serial += 1
	_bgm_pause_serial += 1
	_cancel_bgm_fade_tween()
	_cancel_bgm_stop_tween()
	_cancel_bgm_transport_tween()
	_stop_all_local_bgm_players()
	_clear_bgm_session_state()
	if not history_key.is_empty():
		bgm_finished.emit(history_key)


func _commit_local_bgm_request(
	request_serial: int,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	crossfade_seconds: float,
	history_key: String,
	loop_override: Variant = null
) -> void:
	if request_serial != _bgm_request_serial:
		return
	if stream == null or not is_instance_valid(_bgm_player):
		_restore_bgm_state_after_failed_request()
		return

	if _bgm_owner == _OWNER_BACKEND:
		if not _notify_backend_stop_bgm(0.0):
			_restore_bgm_state_after_failed_request()
			return
		_clear_bgm_session_state()
	_bgm_owner = _OWNER_LOCAL
	_current_bgm_loop = loop_override
	var prepared_stream: AudioStream = _prepare_bgm_stream(stream, loop_override)
	var fade_seconds: float = _resolve_bgm_crossfade_seconds(crossfade_seconds)
	var current_session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var current_player: AudioStreamPlayer = _get_bgm_session_player(current_session)
	if (
		fade_seconds > 0.0
		and is_instance_valid(current_player)
		and current_player.playing
		and current_player.stream != null
	):
		_record_bgm_history(history_key)
		_start_bgm_crossfade(
			request_serial,
			prepared_stream,
			bus_name,
			volume_db,
			pitch_scale,
			fade_seconds,
			history_key,
			loop_override
		)
		return

	_stop_all_local_bgm_players()
	_bgm_owner = _OWNER_LOCAL
	_apply_player_settings(_bgm_player, prepared_stream, bus_name, volume_db, pitch_scale)
	_bgm_current_session_id = _create_bgm_session(
		_bgm_player,
		request_serial,
		history_key,
		volume_db,
		loop_override,
		&"current"
	)
	_bgm_player.play()
	_bgm_state = _STATE_PLAYING
	_record_bgm_history(history_key)


func _apply_bgm_request(
	request_serial: int,
	stream: AudioStream,
	crossfade_seconds: float = -1.0,
	history_key: String = "",
	loop_override: Variant = null
) -> void:
	if request_serial != _bgm_request_serial:
		return

	_commit_local_bgm_request(
		request_serial,
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

	_commit_local_bgm_request(
		request_serial,
		stream,
		bus_name,
		volume_db,
		pitch_scale,
		crossfade_seconds,
		history_key,
		loop_override
	)


func _start_bgm_crossfade(
	request_serial: int,
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	pitch_scale: float,
	fade_seconds: float,
	history_key: String,
	loop_override: Variant
) -> void:
	if not is_instance_valid(_bgm_fade_player):
		_stop_all_local_bgm_players()
		_bgm_owner = _OWNER_LOCAL
		_apply_player_settings(_bgm_player, stream, bus_name, volume_db, pitch_scale)
		_bgm_current_session_id = _create_bgm_session(
			_bgm_player,
			request_serial,
			history_key,
			volume_db,
			loop_override,
			&"current"
		)
		_bgm_player.play()
		_bgm_state = _STATE_PLAYING
		return

	_bgm_fade_serial += 1
	var fade_serial: int = _bgm_fade_serial
	var operation_generation: int = _bgm_generation
	var outgoing_session_id: int = _bgm_current_session_id
	_set_bgm_session_role(outgoing_session_id, &"outgoing")
	_remove_bgm_session_for_player(_bgm_fade_player, true)
	_apply_player_settings(_bgm_fade_player, stream, bus_name, -80.0, pitch_scale)
	_bgm_incoming_session_id = _create_bgm_session(
		_bgm_fade_player,
		request_serial,
		history_key,
		volume_db,
		loop_override,
		&"incoming"
	)
	var incoming_session_id: int = _bgm_incoming_session_id
	_bgm_fade_player.play()
	_bgm_state = _STATE_CROSSFADING

	var tween: Tween = _create_tween_or_null()
	if tween == null:
		_complete_bgm_crossfade(
			operation_generation,
			fade_serial,
			outgoing_session_id,
			incoming_session_id,
			volume_db
		)
		return

	_bgm_fade_tween_ref = weakref(tween)
	_add_tween_property(tween, _bgm_player, "volume_db", -80.0, fade_seconds)
	var parallel_tween: Tween = tween.parallel()
	_add_tween_property(parallel_tween, _bgm_fade_player, "volume_db", volume_db, fade_seconds)
	var finished_callback: Callable = func() -> void:
		_complete_bgm_crossfade(
			operation_generation,
			fade_serial,
			outgoing_session_id,
			incoming_session_id,
			volume_db
		)
	_connect_signal_checked(tween.finished, finished_callback, CONNECT_ONE_SHOT)


func _complete_bgm_crossfade(
	operation_generation: int,
	fade_serial: int,
	outgoing_session_id: int,
	incoming_session_id: int,
	target_volume_db: float
) -> void:
	if (
		operation_generation != _bgm_generation
		or fade_serial != _bgm_fade_serial
		or incoming_session_id != _bgm_incoming_session_id
		or _bgm_state != _STATE_CROSSFADING
		or _bgm_owner != _OWNER_LOCAL
	):
		return
	var incoming_session: Dictionary = _get_bgm_session(incoming_session_id)
	var incoming_player: AudioStreamPlayer = _get_bgm_session_player(incoming_session)
	if not is_instance_valid(incoming_player) or not incoming_player.playing:
		_abort_bgm_incoming_session(true)
		return

	_bgm_fade_tween_ref = null
	var outgoing_session: Dictionary = _get_bgm_session(outgoing_session_id)
	var outgoing_player: AudioStreamPlayer = _get_bgm_session_player(outgoing_session)
	if not is_instance_valid(outgoing_player):
		outgoing_player = _bgm_player
	if is_instance_valid(outgoing_player):
		outgoing_player.stop()
		outgoing_player.stream_paused = false
	_remove_bgm_session(outgoing_session_id, false)
	var previous_player: AudioStreamPlayer = _bgm_player
	_bgm_player = incoming_player
	_bgm_player.stream_paused = false
	_bgm_player.volume_db = target_volume_db
	_bgm_fade_player = previous_player
	_bgm_fade_player.stream_paused = false
	_bgm_fade_player.volume_db = 0.0
	_bgm_current_session_id = incoming_session_id
	_bgm_incoming_session_id = 0
	_set_bgm_session_role(incoming_session_id, &"current")
	_bgm_state = _STATE_PLAYING
	_current_bgm_key = GFVariantData.get_option_string(incoming_session, "history_key")
	_current_bgm_loop = GFVariantData.get_option_value(incoming_session, "loop_override")


func _apply_bgm_pause(
	operation_generation: int,
	pause_serial: int,
	playback_session_id: int,
	player: AudioStreamPlayer
) -> void:
	if (
		operation_generation != _bgm_generation
		or pause_serial != _bgm_pause_serial
		or playback_session_id != _bgm_current_session_id
		or _bgm_state != _STATE_PAUSING
	):
		return
	if (
		not is_instance_valid(player)
		or player.stream == null
		or not _is_bgm_player_session_current(player, playback_session_id)
	):
		return

	_bgm_transport_tween_ref = null
	player.stream_paused = true
	_bgm_state = _STATE_PAUSED
	_bgm_paused = true


func _create_bgm_session(
	player: AudioStreamPlayer,
	request_serial: int,
	history_key: String,
	target_volume_db: float,
	loop_override: Variant,
	role: StringName
) -> int:
	if not is_instance_valid(player):
		return 0
	_remove_bgm_session_for_player(player, false)
	var session_id: int = _next_bgm_session_id
	_next_bgm_session_id += 1
	_bgm_sessions[session_id] = {
		"id": session_id,
		"request_serial": request_serial,
		"history_key": history_key,
		"target_volume_db": target_volume_db,
		"loop_override": loop_override,
		"role": role,
		"player": player,
	}
	player.set_meta(_BGM_SESSION_META, session_id)
	return session_id


func _get_bgm_session(session_id: int) -> Dictionary:
	var session_value: Variant = _bgm_sessions.get(session_id)
	if session_value is Dictionary:
		var session: Dictionary = session_value
		return session
	return {}


func _get_bgm_session_player(session: Dictionary) -> AudioStreamPlayer:
	var player_value: Variant = GFVariantData.get_option_value(session, "player")
	if player_value is AudioStreamPlayer:
		var player: AudioStreamPlayer = player_value
		return player
	return null


func _set_bgm_session_role(session_id: int, role: StringName) -> void:
	var session: Dictionary = _get_bgm_session(session_id)
	if session.is_empty():
		return
	session["role"] = role
	_bgm_sessions[session_id] = session


func _remove_bgm_session(session_id: int, stop_player: bool) -> void:
	if session_id <= 0:
		return
	var session: Dictionary = _get_bgm_session(session_id)
	var player: AudioStreamPlayer = _get_bgm_session_player(session)
	if is_instance_valid(player):
		if stop_player:
			player.stream_paused = false
			player.stop()
		if GFVariantData.to_int(player.get_meta(_BGM_SESSION_META, 0)) == session_id:
			player.remove_meta(_BGM_SESSION_META)
	var _session_erased: bool = _bgm_sessions.erase(session_id)
	if _bgm_current_session_id == session_id:
		_bgm_current_session_id = 0
	if _bgm_incoming_session_id == session_id:
		_bgm_incoming_session_id = 0


func _remove_bgm_session_for_player(player: AudioStreamPlayer, stop_player: bool) -> void:
	if not is_instance_valid(player):
		return
	var session_id: int = GFVariantData.to_int(player.get_meta(_BGM_SESSION_META, 0))
	if session_id > 0:
		_remove_bgm_session(session_id, stop_player)


func _is_bgm_player_session_current(player: AudioStreamPlayer, session_id: int) -> bool:
	return (
		session_id > 0
		and is_instance_valid(player)
		and GFVariantData.to_int(player.get_meta(_BGM_SESSION_META, 0)) == session_id
		and not _get_bgm_session(session_id).is_empty()
	)


func _abort_bgm_incoming_session(_incoming_finished: bool) -> void:
	_bgm_fade_serial += 1
	_cancel_bgm_fade_tween()
	var incoming_session_id: int = _bgm_incoming_session_id
	if incoming_session_id > 0:
		_remove_bgm_session(incoming_session_id, true)
	_bgm_incoming_session_id = 0

	var outgoing_session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var outgoing_player: AudioStreamPlayer = _get_bgm_session_player(outgoing_session)
	if is_instance_valid(outgoing_player) and outgoing_player.playing:
		outgoing_player.volume_db = GFVariantData.get_option_float(
			outgoing_session,
			"target_volume_db",
			outgoing_player.volume_db
		)
		_set_bgm_session_role(_bgm_current_session_id, &"current")
		_current_bgm_key = GFVariantData.get_option_string(outgoing_session, "history_key")
		_current_bgm_loop = GFVariantData.get_option_value(outgoing_session, "loop_override")
		_bgm_state = _STATE_PLAYING
		return

	if _bgm_current_session_id > 0:
		_remove_bgm_session(_bgm_current_session_id, true)
	_bgm_current_session_id = 0
	_bgm_owner = _OWNER_NONE
	_bgm_state = _STATE_STOPPED
	_current_bgm_key = ""
	_current_bgm_loop = null


func _cancel_bgm_incoming_session() -> void:
	if _bgm_incoming_session_id > 0 or _bgm_state == _STATE_CROSSFADING:
		_abort_bgm_incoming_session(false)


func _restore_bgm_state_after_failed_request() -> void:
	var current_session: Dictionary = _get_bgm_session(_bgm_current_session_id)
	var current_player: AudioStreamPlayer = _get_bgm_session_player(current_session)
	if (
		_bgm_owner == _OWNER_LOCAL
		and is_instance_valid(current_player)
		and current_player.stream != null
		and (current_player.playing or current_player.stream_paused)
	):
		_bgm_state = _STATE_PAUSED if current_player.stream_paused else _STATE_PLAYING
		_bgm_paused = current_player.stream_paused
		if not current_player.stream_paused:
			current_player.volume_db = GFVariantData.get_option_float(
				current_session,
				"target_volume_db",
				current_player.volume_db
			)
		_current_bgm_key = GFVariantData.get_option_string(current_session, "history_key")
		_current_bgm_loop = GFVariantData.get_option_value(current_session, "loop_override")
		return
	if _bgm_owner == _OWNER_BACKEND:
		_bgm_paused = _backend_dispatch_returned_true(
			_dispatch_backend_call(&"is_bgm_paused", [], _audio_backend)
		)
		_bgm_state = _STATE_PAUSED if _bgm_paused else _STATE_PLAYING
		return
	_clear_bgm_session_state()
	_current_bgm_key = ""
	_current_bgm_loop = null


func _stop_all_local_bgm_players() -> void:
	_cancel_bgm_fade_tween()
	_cancel_bgm_stop_tween()
	_cancel_bgm_transport_tween()
	for player: AudioStreamPlayer in [_bgm_player, _bgm_fade_player]:
		if not is_instance_valid(player):
			continue
		player.stream_paused = false
		player.stop()
		if player.has_meta(_BGM_SESSION_META):
			player.remove_meta(_BGM_SESSION_META)
	_bgm_sessions.clear()
	_bgm_current_session_id = 0
	_bgm_incoming_session_id = 0


func _clear_bgm_session_state() -> void:
	for player: AudioStreamPlayer in [_bgm_player, _bgm_fade_player]:
		if is_instance_valid(player) and player.has_meta(_BGM_SESSION_META):
			player.remove_meta(_BGM_SESSION_META)
	_bgm_sessions.clear()
	_bgm_current_session_id = 0
	_bgm_incoming_session_id = 0
	_bgm_owner = _OWNER_NONE
	_bgm_state = _STATE_STOPPED
	_bgm_paused = false
	_current_bgm_key = ""
	_current_bgm_loop = null


func _start_bgm_session_stop(
	player: AudioStreamPlayer,
	session_id: int,
	operation_generation: int,
	fade_seconds: float
) -> void:
	if not _is_bgm_player_session_current(player, session_id):
		_clear_bgm_session_state()
		return
	if fade_seconds <= 0.0 or not player.playing:
		_finish_bgm_session_stop(operation_generation, session_id, player)
		return

	var tween: Tween = _fade_player_volume(player, SILENCE_VOLUME_DB, fade_seconds)
	if tween == null:
		_finish_bgm_session_stop(operation_generation, session_id, player)
		return
	_bgm_stop_tween_ref = weakref(tween)
	_connect_signal_checked(
		tween.finished,
		_finish_bgm_session_stop.bind(operation_generation, session_id, player),
		CONNECT_ONE_SHOT
	)
	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		var timer: SceneTreeTimer = tree.create_timer(fade_seconds)
		_connect_signal_checked(
			timer.timeout,
			_finish_bgm_session_stop.bind(operation_generation, session_id, player),
			CONNECT_ONE_SHOT
		)


func _finish_bgm_session_stop(
	operation_generation: int,
	session_id: int,
	player: AudioStreamPlayer
) -> void:
	if (
		operation_generation != _bgm_generation
		or _bgm_state != _STATE_STOPPING
		or session_id != _bgm_current_session_id
		or not _is_bgm_player_session_current(player, session_id)
	):
		return
	_bgm_stop_tween_ref = null
	player.stop()
	_remove_bgm_session(session_id, false)
	_clear_bgm_session_state()


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
	_current_bgm_key = history_key
	if history_key.is_empty():
		return

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
	_ambient_generation_counter += 1
	var next_serial: int = _ambient_generation_counter
	_ambient_request_serials[channel] = next_serial
	return next_serial


func _begin_ambient_replacement(channel: StringName) -> int:
	var request_serial: int = _next_ambient_request_serial(channel)
	_cancel_ambient_tween(channel)
	var session: Dictionary = _get_ambient_session(channel)
	var owner: StringName = GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
	var playback_session_id: int = GFVariantData.get_option_int(session, "playback_session_id")
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	if playback_session_id > 0 and _is_playback_session_current(player, playback_session_id):
		_disconnect_ambient_finished_callback(channel, player, playback_session_id)
		_invalidate_playback_session(player, playback_session_id)
	_set_ambient_session(channel, request_serial, _STATE_LOADING, owner, 0)
	return request_serial


func _commit_backend_ambient_session(channel: StringName, request_serial: int) -> void:
	if request_serial != _get_ambient_request_serial(channel):
		return
	var session: Dictionary = _get_ambient_session(channel)
	var previous_owner: StringName = GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
	if previous_owner == _OWNER_LOCAL:
		var player: AudioStreamPlayer = _get_ambient_player(channel)
		if is_instance_valid(player):
			player.stop()
	_set_ambient_session(channel, request_serial, _STATE_PLAYING, _OWNER_BACKEND, 0)


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

	if stream == null:
		_restore_ambient_state_after_failed_request(channel, request_serial)
		return

	var previous_session: Dictionary = _get_ambient_session(channel)
	var previous_owner: StringName = GFVariantData.get_option_string_name(
		previous_session,
		"owner",
		_OWNER_NONE
	)
	if previous_owner == _OWNER_BACKEND:
		if not _notify_backend_stop_ambient(channel, 0.0):
			_restore_ambient_state_after_failed_request(channel, request_serial)
			return
	var player: AudioStreamPlayer = _get_or_create_ambient_player(channel)
	if player == null:
		_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)
		return

	player.stop()
	var safe_fade: float = _finite_non_negative_or_zero(fade_seconds)
	var should_fade: bool = safe_fade > 0.0
	_apply_player_settings(player, stream, bus_name, -80.0 if should_fade else volume_db, pitch_scale)
	var playback_session_id: int = _begin_playback_session(player)
	var finished_callback: Callable = _get_ambient_finished_callback(channel, player, playback_session_id)
	_connect_signal_checked(player.finished, finished_callback, CONNECT_ONE_SHOT)
	player.play()
	_set_playback_session_state(player, playback_session_id, _STATE_PLAYING)
	_set_ambient_session(
		channel,
		request_serial,
		_STATE_PLAYING,
		_OWNER_LOCAL,
		playback_session_id
	)
	if should_fade:
		var tween: Tween = _fade_player_volume(player, volume_db, safe_fade)
		if tween != null:
			_ambient_tween_refs[channel] = weakref(tween)
			_connect_signal_checked(
				tween.finished,
				_finish_ambient_fade.bind(channel, request_serial, playback_session_id),
				CONNECT_ONE_SHOT
			)


func _restore_ambient_state_after_failed_request(channel: StringName, request_serial: int) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	var owner: StringName = GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE)
	if owner == _OWNER_BACKEND:
		_set_ambient_session(channel, request_serial, _STATE_PLAYING, _OWNER_BACKEND, 0)
		return
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	if owner == _OWNER_LOCAL and is_instance_valid(player) and player.playing:
		var playback_session_id: int = _begin_playback_session(player)
		var finished_callback: Callable = _get_ambient_finished_callback(
			channel,
			player,
			playback_session_id
		)
		_connect_signal_checked(player.finished, finished_callback, CONNECT_ONE_SHOT)
		_set_playback_session_state(player, playback_session_id, _STATE_PLAYING)
		_set_ambient_session(
			channel,
			request_serial,
			_STATE_PLAYING,
			_OWNER_LOCAL,
			playback_session_id
		)
		return
	_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)


func _finish_ambient_fade(
	channel: StringName,
	request_serial: int,
	playback_session_id: int
) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	if (
		request_serial != _get_ambient_request_serial(channel)
		or GFVariantData.get_option_int(session, "playback_session_id") != playback_session_id
	):
		return
	_erase_dictionary_key(_ambient_tween_refs, channel)


func _start_ambient_session_stop(
	channel: StringName,
	request_serial: int,
	playback_session_id: int,
	player: AudioStreamPlayer,
	fade_seconds: float
) -> void:
	if not is_instance_valid(player):
		_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)
		return
	if playback_session_id > 0:
		_disconnect_ambient_finished_callback(channel, player, playback_session_id)
		_complete_playback_session_handle(playback_session_id)
	if fade_seconds <= 0.0 or not player.playing:
		_finish_ambient_session_stop(channel, request_serial, playback_session_id, player)
		return
	var tween: Tween = _fade_player_volume(player, SILENCE_VOLUME_DB, fade_seconds)
	if tween == null:
		_finish_ambient_session_stop(channel, request_serial, playback_session_id, player)
		return
	_ambient_tween_refs[channel] = weakref(tween)
	_connect_signal_checked(
		tween.finished,
		_finish_ambient_session_stop.bind(channel, request_serial, playback_session_id, player),
		CONNECT_ONE_SHOT
	)


func _finish_ambient_session_stop(
	channel: StringName,
	request_serial: int,
	playback_session_id: int,
	player: AudioStreamPlayer
) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	if (
		request_serial != _get_ambient_request_serial(channel)
		or GFVariantData.get_option_string_name(session, "state", _STATE_STOPPED) != _STATE_STOPPING
	):
		return
	_erase_dictionary_key(_ambient_tween_refs, channel)
	if is_instance_valid(player):
		player.stop()
		if playback_session_id > 0:
			_invalidate_playback_session(player, playback_session_id)
	_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)


func _release_ambient_session(
	player: Node,
	channel: StringName,
	playback_session_id: int
) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	if (
		GFVariantData.get_option_int(session, "playback_session_id") != playback_session_id
		or not _is_playback_session_current(player, playback_session_id)
	):
		return
	_cancel_ambient_tween(channel)
	var request_serial: int = _get_ambient_request_serial(channel)
	_set_ambient_session(
		channel,
		request_serial,
		_STATE_STOPPING,
		_OWNER_LOCAL,
		playback_session_id
	)
	_finish_ambient_session_stop(
		channel,
		request_serial,
		playback_session_id,
		_get_audio_stream_player_value(player)
	)


func _on_ambient_player_finished(
	channel: StringName,
	player: AudioStreamPlayer,
	playback_session_id: int
) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	if (
		GFVariantData.get_option_int(session, "playback_session_id") != playback_session_id
		or not _is_playback_session_current(player, playback_session_id)
	):
		return
	_cancel_ambient_tween(channel)
	_invalidate_playback_session(player, playback_session_id)
	_set_ambient_session(
		channel,
		_get_ambient_request_serial(channel),
		_STATE_STOPPED,
		_OWNER_NONE,
		0
	)


func _get_ambient_finished_callback(
	channel: StringName,
	player: AudioStreamPlayer,
	playback_session_id: int
) -> Callable:
	return _on_ambient_player_finished.bind(channel, player, playback_session_id)


func _disconnect_ambient_finished_callback(
	channel: StringName,
	player: AudioStreamPlayer,
	playback_session_id: int
) -> void:
	if not is_instance_valid(player) or playback_session_id <= 0:
		return
	var callback: Callable = _get_ambient_finished_callback(channel, player, playback_session_id)
	if player.finished.is_connected(callback):
		player.finished.disconnect(callback)


func _get_ambient_session(channel: StringName) -> Dictionary:
	var session_value: Variant = _ambient_sessions.get(channel)
	if session_value is Dictionary:
		var session: Dictionary = session_value
		return session
	return {}


func _converge_inactive_local_ambient_session(channel: StringName) -> void:
	var session: Dictionary = _get_ambient_session(channel)
	var request_serial: int = _get_ambient_request_serial(channel)
	var state: StringName = GFVariantData.get_option_string_name(
		session,
		"state",
		_STATE_STOPPED
	)
	if (
		GFVariantData.get_option_int(session, "generation") != request_serial
		or GFVariantData.get_option_string_name(session, "owner", _OWNER_NONE) != _OWNER_LOCAL
		or (state != _STATE_PLAYING and state != _STATE_STOPPING)
	):
		return

	var playback_session_id: int = GFVariantData.get_option_int(session, "playback_session_id")
	if playback_session_id <= 0:
		return
	var player: AudioStreamPlayer = _get_ambient_player(channel)
	if is_instance_valid(player):
		if not _is_playback_session_current(player, playback_session_id) or player.playing:
			return
	_cancel_ambient_tween(channel)
	if is_instance_valid(player):
		_disconnect_ambient_finished_callback(channel, player, playback_session_id)
		_invalidate_playback_session(player, playback_session_id)
	else:
		_complete_playback_session_handle(playback_session_id)
		_erase_playback_session(playback_session_id)
	_set_ambient_session(channel, request_serial, _STATE_STOPPED, _OWNER_NONE, 0)


func _set_ambient_session(
	channel: StringName,
	generation: int,
	state: StringName,
	owner: StringName,
	playback_session_id: int
) -> void:
	_ambient_sessions[channel] = {
		"generation": generation,
		"state": state,
		"owner": owner,
		"playback_session_id": playback_session_id,
	}


func _cancel_ambient_tween(channel: StringName) -> void:
	if not _ambient_tween_refs.has(channel):
		return
	_kill_tween_ref(_get_weak_ref_value(_ambient_tween_refs[channel]))
	_erase_dictionary_key(_ambient_tween_refs, channel)


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
	for channel_variant: Variant in _ambient_players.keys():
		var channel: StringName = GFVariantData.to_string_name(channel_variant)
		_cancel_ambient_tween(channel)
		var session: Dictionary = _get_ambient_session(channel)
		var playback_session_id: int = GFVariantData.get_option_int(session, "playback_session_id")
		var player: AudioStreamPlayer = _get_ambient_player(channel)
		if playback_session_id > 0 and _is_playback_session_current(player, playback_session_id):
			_disconnect_ambient_finished_callback(channel, player, playback_session_id)
			_invalidate_playback_session(player, playback_session_id)
	for player_variant: Variant in _ambient_players.values():
		var player: AudioStreamPlayer = _get_audio_stream_player_value(player_variant)
		if is_instance_valid(player):
			player.stream_paused = false
			player.stop()
			player.queue_free()
	_ambient_players.clear()
	_ambient_request_serials.clear()
	_ambient_sessions.clear()
	_ambient_tween_refs.clear()


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


func _cancel_bgm_stop_tween() -> void:
	_kill_tween_ref(_bgm_stop_tween_ref)
	_bgm_stop_tween_ref = null


func _cancel_bgm_transport_tween() -> void:
	_kill_tween_ref(_bgm_transport_tween_ref)
	_bgm_transport_tween_ref = null


func _clear_bgm_transport_tween(operation_generation: int, pause_serial: int) -> void:
	if operation_generation == _bgm_generation and pause_serial == _bgm_pause_serial:
		_bgm_transport_tween_ref = null


func _kill_tween_ref(tween_ref: WeakRef) -> void:
	if tween_ref == null:
		return

	var tween: Tween = _get_tween_value(tween_ref.get_ref())
	if tween != null and tween.is_valid():
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

	if not _ensure_sfx_capacity_available():
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
		_set_playback_session_state(player, playback_session_id, _STATE_PLAYING)
	return player


func _on_bgm_player_finished(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	var session_id: int = GFVariantData.to_int(player.get_meta(_BGM_SESSION_META, 0))
	var session: Dictionary = _get_bgm_session(session_id)
	if session.is_empty():
		return
	var history_key: String = GFVariantData.get_option_string(session, "history_key")
	var role: StringName = GFVariantData.get_option_string_name(session, "role", &"")

	if role == &"incoming" and session_id == _bgm_incoming_session_id:
		player.stop()
		_abort_bgm_incoming_session(true)
	elif role == &"outgoing" and _bgm_state == _STATE_CROSSFADING:
		player.stop()
		_remove_bgm_session(session_id, false)
	elif session_id == _bgm_current_session_id:
		player.stop()
		_remove_bgm_session(session_id, false)
		_clear_bgm_session_state()
		_current_bgm_key = ""
		_current_bgm_loop = null
		_bgm_paused = false
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
	_prune_inactive_spatial_sfx_players()
	return _get_tracked_sfx_count() >= max_sfx_players


func _ensure_sfx_capacity_available() -> bool:
	while _is_sfx_capacity_full():
		if sfx_overflow_policy != SFXOverflowPolicy.STOP_OLDEST:
			return false
		var active_count_before: int = _get_tracked_sfx_count()
		_stop_oldest_sfx()
		var active_count_after: int = _get_tracked_sfx_count()
		if active_count_after >= active_count_before:
			return false
	return true


func _get_tracked_sfx_count() -> int:
	return _get_tracked_normal_sfx_count() + _get_tracked_spatial_sfx_count()


func _get_tracked_normal_sfx_count() -> int:
	return _active_sfx_players.size() + _retiring_sfx_players.size()


func _get_tracked_spatial_sfx_count() -> int:
	return _active_spatial_sfx_players.size() + _retiring_spatial_sfx_players.size()


func _track_sfx_player(player: AudioStreamPlayer) -> void:
	_prune_inactive_sfx_players()
	if not _active_sfx_players.has(player):
		_active_sfx_players.append(player)


func _untrack_sfx_player(player: AudioStreamPlayer) -> void:
	_active_sfx_players.erase(player)


func _track_retiring_sfx_player(player: AudioStreamPlayer) -> void:
	_untrack_sfx_player(player)
	if is_instance_valid(player) and not _retiring_sfx_players.has(player):
		_retiring_sfx_players.append(player)


func _track_spatial_sfx_player(player: Node) -> void:
	_prune_inactive_spatial_sfx_players()
	if is_instance_valid(player) and not _active_spatial_sfx_players.has(player):
		_active_spatial_sfx_players.append(player)


func _untrack_spatial_sfx_player(player: Node) -> void:
	_active_spatial_sfx_players.erase(player)


func _track_retiring_spatial_sfx_player(player: Node) -> void:
	_untrack_spatial_sfx_player(player)
	if is_instance_valid(player) and not _retiring_spatial_sfx_players.has(player):
		_retiring_spatial_sfx_players.append(player)


func _stop_oldest_sfx() -> void:
	_prune_inactive_sfx_players()
	_prune_inactive_spatial_sfx_players()
	var oldest_player: Node = null
	var oldest_session_id: int = 0
	for normal_player: AudioStreamPlayer in _active_sfx_players:
		var normal_session_id: int = _get_playback_session_id(normal_player)
		if normal_session_id > 0 and (oldest_session_id == 0 or normal_session_id < oldest_session_id):
			oldest_player = normal_player
			oldest_session_id = normal_session_id
	for retiring_normal_player: AudioStreamPlayer in _retiring_sfx_players:
		var retiring_normal_session_id: int = _get_playback_session_id(retiring_normal_player)
		if (
			retiring_normal_session_id > 0
			and (
				oldest_session_id == 0
				or retiring_normal_session_id < oldest_session_id
			)
		):
			oldest_player = retiring_normal_player
			oldest_session_id = retiring_normal_session_id
	for spatial_player: Node in _active_spatial_sfx_players:
		var spatial_session_id: int = _get_playback_session_id(spatial_player)
		if spatial_session_id > 0 and (oldest_session_id == 0 or spatial_session_id < oldest_session_id):
			oldest_player = spatial_player
			oldest_session_id = spatial_session_id
	for retiring_spatial_player: Node in _retiring_spatial_sfx_players:
		var retiring_spatial_session_id: int = _get_playback_session_id(retiring_spatial_player)
		if (
			retiring_spatial_session_id > 0
			and (
				oldest_session_id == 0
				or retiring_spatial_session_id < oldest_session_id
			)
		):
			oldest_player = retiring_spatial_player
			oldest_session_id = retiring_spatial_session_id
	if oldest_player == null:
		return
	if oldest_player is AudioStreamPlayer:
		var normal_player: AudioStreamPlayer = oldest_player
		_release_sfx_player(normal_player, 0.0)
	else:
		_release_spatial_sfx_player(oldest_player, 0.0)


func _begin_playback_session(player: Node) -> int:
	if not is_instance_valid(player):
		return 0
	var previous_session_id: int = _get_playback_session_id(player)
	if previous_session_id > 0:
		_complete_playback_session_handle(previous_session_id)
		_erase_playback_session(previous_session_id)
	var playback_session_id: int = _next_playback_session_id
	_next_playback_session_id += 1
	player.set_meta(_PLAYBACK_SESSION_META, playback_session_id)
	_playback_sessions[playback_session_id] = {
		"player_ref": weakref(player),
		"state": _STATE_LOADING,
		"retiring_tween_ref": null,
	}
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
	var handle_refs: Array = _get_playback_session_handle_refs(playback_session_id)
	handle_refs.append(weakref(handle))
	_playback_session_handles[playback_session_id] = handle_refs
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
	if (
		playback_session_id <= 0
		or not is_instance_valid(player)
		or _get_playback_session_id(player) != playback_session_id
	):
		return false
	var session: Dictionary = _get_playback_session(playback_session_id)
	var player_ref_value: Variant = GFVariantData.get_option_value(session, "player_ref")
	if not player_ref_value is WeakRef:
		return false
	var player_ref: WeakRef = player_ref_value
	return player_ref.get_ref() == player


func _get_playback_session(playback_session_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(_playback_sessions.get(playback_session_id))


func _get_playback_session_state(playback_session_id: int) -> StringName:
	return GFVariantData.get_option_string_name(
		_get_playback_session(playback_session_id),
		"state",
		_STATE_STOPPED
	)


func _set_playback_session_state(
	player: Node,
	playback_session_id: int,
	state: StringName
) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	var session: Dictionary = _get_playback_session(playback_session_id)
	session["state"] = state
	_playback_sessions[playback_session_id] = session


func _set_playback_session_retiring_tween(
	player: Node,
	playback_session_id: int,
	tween: Tween
) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	var session: Dictionary = _get_playback_session(playback_session_id)
	session["retiring_tween_ref"] = weakref(tween) if tween != null else null
	_playback_sessions[playback_session_id] = session


func _kill_playback_session_retiring_tween(playback_session_id: int) -> void:
	var session: Dictionary = _get_playback_session(playback_session_id)
	var tween_ref_value: Variant = GFVariantData.get_option_value(
		session,
		"retiring_tween_ref"
	)
	if tween_ref_value is WeakRef:
		var tween_ref: WeakRef = tween_ref_value
		_kill_tween_ref(tween_ref)
	if not session.is_empty():
		session["retiring_tween_ref"] = null
		_playback_sessions[playback_session_id] = session


func _erase_playback_session(playback_session_id: int) -> void:
	_kill_playback_session_retiring_tween(playback_session_id)
	var _session_erased: bool = _playback_sessions.erase(playback_session_id)


func _complete_playback_session_handle(playback_session_id: int) -> void:
	var handle_refs: Array = _get_playback_session_handle_refs(playback_session_id)
	var _handle_erased: bool = _playback_session_handles.erase(playback_session_id)
	for handle_ref_value: Variant in handle_refs:
		if not handle_ref_value is WeakRef:
			continue
		var handle_ref: WeakRef = handle_ref_value
		var handle_value: Variant = handle_ref.get_ref()
		if handle_value is GFAudioEmitterHandle:
			var handle: GFAudioEmitterHandle = handle_value
			handle._complete_playback_session(playback_session_id)


func _get_playback_session_handle_refs(playback_session_id: int) -> Array:
	var handle_refs_value: Variant = _playback_session_handles.get(playback_session_id)
	var handle_refs: Array = []
	if handle_refs_value is Array:
		for handle_ref_value: Variant in GFVariantData.as_array(handle_refs_value):
			if not handle_ref_value is WeakRef:
				continue
			var handle_ref: WeakRef = handle_ref_value
			if handle_ref.get_ref() != null:
				handle_refs.append(handle_ref)
	elif handle_refs_value is WeakRef:
		var legacy_handle_ref: WeakRef = handle_refs_value
		if legacy_handle_ref.get_ref() != null:
			handle_refs.append(legacy_handle_ref)
	return handle_refs


func _complete_all_playback_session_handles() -> void:
	var playback_session_ids: Array = _playback_session_handles.keys()
	playback_session_ids.sort()
	for playback_session_id_value: Variant in playback_session_ids:
		_complete_playback_session_handle(GFVariantData.to_int(playback_session_id_value))
	_playback_session_handles.clear()


func _invalidate_playback_session(player: Node, playback_session_id: int) -> void:
	if not _is_playback_session_current(player, playback_session_id):
		return
	_complete_playback_session_handle(playback_session_id)
	_erase_playback_session(playback_session_id)
	player.remove_meta(_PLAYBACK_SESSION_META)


func _release_all_sfx_players(fade_seconds: float = 0.0) -> void:
	_prune_inactive_sfx_players()
	var players: Array[AudioStreamPlayer] = _active_sfx_players.duplicate()
	if _finite_non_negative_or_zero(fade_seconds) <= 0.0:
		for retiring_player: AudioStreamPlayer in _retiring_sfx_players:
			if not players.has(retiring_player):
				players.append(retiring_player)
	for player: AudioStreamPlayer in players:
		_release_sfx_player(player, fade_seconds)


func _release_all_spatial_sfx_players(fade_seconds: float = 0.0) -> void:
	_prune_inactive_spatial_sfx_players()
	var players: Array[Node] = _active_spatial_sfx_players.duplicate()
	if _finite_non_negative_or_zero(fade_seconds) <= 0.0:
		for retiring_player: Node in _retiring_spatial_sfx_players:
			if not players.has(retiring_player):
				players.append(retiring_player)
	for player: Node in players:
		_release_spatial_sfx_player(player, fade_seconds)


func _release_sfx_player(player: AudioStreamPlayer, fade_seconds: float = 0.0) -> void:
	if not is_instance_valid(player):
		return

	var playback_session_id: int = _get_playback_session_id(player)
	if playback_session_id <= 0:
		return
	var safe_fade_seconds: float = _finite_non_negative_or_zero(fade_seconds)
	if _retiring_sfx_players.has(player):
		if safe_fade_seconds <= 0.0:
			_finish_release_sfx_player(player, playback_session_id)
		return
	_track_retiring_sfx_player(player)
	_set_playback_session_state(player, playback_session_id, _STATE_RETIRING)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_sfx_finished_callback(player, playback_session_id)
	if safe_fade_seconds > 0.0 and player.playing:
		var tween: Tween = _fade_player_volume(player, -80.0, safe_fade_seconds)
		if tween != null:
			_set_playback_session_retiring_tween(player, playback_session_id, tween)
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

	_kill_playback_session_retiring_tween(playback_session_id)
	_untrack_sfx_player(player)
	_retiring_sfx_players.erase(player)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_sfx_finished_callback(player, playback_session_id)
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
	var safe_fade_seconds: float = _finite_non_negative_or_zero(fade_seconds)
	if _retiring_spatial_sfx_players.has(player):
		if safe_fade_seconds <= 0.0:
			_finish_release_spatial_sfx_player(player, playback_session_id)
		return
	_track_retiring_spatial_sfx_player(player)
	_set_playback_session_state(player, playback_session_id, _STATE_RETIRING)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_spatial_sfx_finished_callback(player, playback_session_id)
	if safe_fade_seconds > 0.0 and _is_audio_node_playing(player):
		var tween: Tween = _fade_audio_node_volume(player, -80.0, safe_fade_seconds)
		if tween != null:
			_set_playback_session_retiring_tween(player, playback_session_id, tween)
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

	_kill_playback_session_retiring_tween(playback_session_id)
	_untrack_spatial_sfx_player(player)
	_retiring_spatial_sfx_players.erase(player)
	_complete_playback_session_handle(playback_session_id)
	_disconnect_spatial_sfx_finished_callback(player, playback_session_id)
	_invalidate_playback_session(player, playback_session_id)
	if player.has_method("stop"):
		player.call("stop")
	player.queue_free()


func _prune_inactive_sfx_players() -> void:
	for i: int in range(_active_sfx_players.size() - 1, -1, -1):
		var player: AudioStreamPlayer = _active_sfx_players[i]
		if not is_instance_valid(player):
			_active_sfx_players.remove_at(i)
			continue
		var playback_session_id: int = _get_playback_session_id(player)
		if player.is_queued_for_deletion() or playback_session_id <= 0:
			if playback_session_id > 0:
				_invalidate_playback_session(player, playback_session_id)
			_active_sfx_players.remove_at(i)
			continue
		if (
			_get_playback_session_state(playback_session_id) == _STATE_PLAYING
			and not player.playing
		):
			_finish_release_sfx_player(player, playback_session_id)
	for retiring_index: int in range(_retiring_sfx_players.size() - 1, -1, -1):
		var retiring_player: AudioStreamPlayer = _retiring_sfx_players[retiring_index]
		if not is_instance_valid(retiring_player):
			_retiring_sfx_players.remove_at(retiring_index)
			continue
		var retiring_session_id: int = _get_playback_session_id(retiring_player)
		if (
			retiring_player.is_queued_for_deletion()
			or retiring_session_id <= 0
			or not _is_playback_session_current(retiring_player, retiring_session_id)
		):
			if retiring_session_id > 0:
				_invalidate_playback_session(retiring_player, retiring_session_id)
			_retiring_sfx_players.remove_at(retiring_index)
			continue
		if not retiring_player.playing:
			_finish_release_sfx_player(retiring_player, retiring_session_id)
	_prune_orphaned_playback_sessions()


func _prune_inactive_spatial_sfx_players() -> void:
	for i: int in range(_active_spatial_sfx_players.size() - 1, -1, -1):
		var player: Node = _active_spatial_sfx_players[i]
		if not is_instance_valid(player):
			_active_spatial_sfx_players.remove_at(i)
			continue
		var playback_session_id: int = _get_playback_session_id(player)
		if player.is_queued_for_deletion() or playback_session_id <= 0:
			if playback_session_id > 0:
				_invalidate_playback_session(player, playback_session_id)
			_active_spatial_sfx_players.remove_at(i)
			continue
		if (
			_get_playback_session_state(playback_session_id) == _STATE_PLAYING
			and not _is_audio_node_playing(player)
		):
			_finish_release_spatial_sfx_player(player, playback_session_id)
	for retiring_index: int in range(_retiring_spatial_sfx_players.size() - 1, -1, -1):
		var retiring_player: Node = _retiring_spatial_sfx_players[retiring_index]
		if not is_instance_valid(retiring_player):
			_retiring_spatial_sfx_players.remove_at(retiring_index)
			continue
		var retiring_session_id: int = _get_playback_session_id(retiring_player)
		if (
			retiring_player.is_queued_for_deletion()
			or retiring_session_id <= 0
			or not _is_playback_session_current(retiring_player, retiring_session_id)
		):
			if retiring_session_id > 0:
				_invalidate_playback_session(retiring_player, retiring_session_id)
			_retiring_spatial_sfx_players.remove_at(retiring_index)
			continue
		if not _is_audio_node_playing(retiring_player):
			_finish_release_spatial_sfx_player(retiring_player, retiring_session_id)
	_prune_orphaned_playback_sessions()


func _prune_orphaned_playback_sessions() -> void:
	var playback_session_ids: Array = _playback_sessions.keys()
	for playback_session_id_value: Variant in playback_session_ids:
		var playback_session_id: int = GFVariantData.to_int(playback_session_id_value)
		var session: Dictionary = _get_playback_session(playback_session_id)
		var player_ref_value: Variant = GFVariantData.get_option_value(session, "player_ref")
		if player_ref_value is WeakRef:
			var player_ref: WeakRef = player_ref_value
			if player_ref.get_ref() != null:
				continue
		_complete_playback_session_handle(playback_session_id)
		_erase_playback_session(playback_session_id)


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


func _disconnect_sfx_finished_callback(
	player: AudioStreamPlayer,
	playback_session_id: int
) -> void:
	if not is_instance_valid(player) or playback_session_id <= 0:
		return
	var finished_callback: Callable = _get_sfx_finished_callback(player, playback_session_id)
	if player.finished.is_connected(finished_callback):
		player.finished.disconnect(finished_callback)


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
