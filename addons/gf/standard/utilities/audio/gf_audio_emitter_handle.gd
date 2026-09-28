## GFAudioEmitterHandle: 一次音频播放的轻量控制句柄。
##
## 句柄只包装底层 AudioStreamPlayer 节点的通用生命周期和播放属性，
## 不规定音频事件、混音策略或业务含义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFAudioEmitterHandle
extends RefCounted


# --- 信号 ---

## 句柄绑定到底层播放器时发出。
## [br]
## @api public
## [br]
## @param handle: 当前句柄。
## [br]
## @param player: 绑定的播放器节点。
signal player_attached(handle: GFAudioEmitterHandle, player: Node)

## 句柄主动停止并释放绑定时发出。
## [br]
## @api public
## [br]
## @param handle: 当前句柄。
signal stopped(handle: GFAudioEmitterHandle)


# --- 常量 ---

## 校验播放器与 owner 弱引用是否仍指向有效 Node 的共享工具。
## [br]
## @api private
## [br]
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共变量 ---

## 可选通道标识。框架不解释该字段。
## [br]
## @api public
var channel: StringName = &""

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: 句柄元数据 Dictionary；键和值由调用方或后端约定。
var metadata: Dictionary = {}


# --- 私有变量 ---

## 底层播放器节点的弱引用。
## [br]
## @api private
## [br]
var _player_ref: WeakRef = null

## 底层播放器停止后调用的释放回调。
## [br]
## @api private
## [br]
var _release_callback: Callable = Callable()

## 记录停止已请求，供播放器稍后绑定时补执行。
## [br]
## @api private
## [br]
var _stop_requested: bool = false

## 尚未绑定播放器时等待使用的规范化停止淡出时长。
## [br]
## @api private
## [br]
var _pending_stop_fade_seconds: float = 0.0

## 当前淡出 Tween 的弱引用。
## [br]
## @api private
## [br]
var _fade_tween_ref: WeakRef = null

## 生命周期 owner 节点的弱引用。
## [br]
## @api private
## [br]
var _owner_ref: WeakRef = null

## 连接到 owner.tree_exiting 的回调实例。
## [br]
## @api private
## [br]
var _owner_exit_callback: Callable = Callable()

## owner 退出场景树时请求停止使用的淡出时长。
## [br]
## @api private
## [br]
var _owner_stop_fade_seconds: float = 0.0

## 防止重复发出 stopped 信号的标记。
## [br]
## @api private
## [br]
var _stopped_emitted: bool = false

## 标记句柄是否已进入不可恢复的终态。
## [br]
## @api private
## [br]
var _terminal: bool = false

## 与当前播放器关联的播放会话编号。
## [br]
## @api private
## [br]
var _playback_session_id: int = 0

## 用于确认句柄仍拥有当前播放器会话的回调。
## [br]
## @api private
## [br]
var _session_validator: Callable = Callable()


# --- Godot 生命周期方法 ---

func _init(
	player: Node = null,
	release_callback: Callable = Callable(),
	p_channel: StringName = &"",
	p_metadata: Dictionary = {}
) -> void:
	_release_callback = release_callback
	channel = p_channel
	metadata = p_metadata.duplicate(true)
	if player != null:
		set_player(player)


# --- 公共方法 ---

## 绑定底层播放器。
## [br]
## @api public
## [br]
## @param player: 要绑定的播放器节点。
func set_player(player: Node) -> void:
	if _terminal:
		_release_player(player)
		return

	_player_ref = weakref(player) if player != null else null
	if player != null:
		player_attached.emit(self, player)
	if _stop_requested:
		stop(_pending_stop_fade_seconds)


## 设置释放回调。
## [br]
## @api public
## [br]
## @param release_callback: 停止完成时调用的释放回调。
func set_release_callback(release_callback: Callable) -> void:
	_release_callback = release_callback


## 绑定一个拥有者节点，节点退出树时自动停止当前播放。
## [br]
## @api public
## [br]
## @param owner: 生命周期拥有者。
## [br]
## @param fade_seconds: 自动停止时使用的淡出秒数。
func bind_to_owner(owner: Node, fade_seconds: float = 0.0) -> void:
	_disconnect_owner_exit()
	if owner == null:
		return

	_owner_ref = weakref(owner)
	_owner_stop_fade_seconds = _finite_non_negative_or_zero(fade_seconds)
	_owner_exit_callback = Callable(self, "_on_owner_tree_exiting")
	if not owner.tree_exiting.is_connected(_owner_exit_callback):
		var _connect_error: Error = owner.tree_exiting.connect(_owner_exit_callback) as Error


## 取消拥有者生命周期绑定。
## [br]
## @api public
func unbind_owner() -> void:
	_disconnect_owner_exit()


## 获取底层播放器。
## [br]
## @api public
## [br]
## @return: 播放器节点；不存在或已释放时返回 null。
func get_player() -> Node:
	if _terminal or _player_ref == null:
		return null
	var player: Node = _INSTANCE_GUARD._get_live_node_from_ref(_player_ref)
	if player != null and not _owns_playback_session(player):
		_complete_terminal(false)
		return null
	return player


## 检查句柄是否仍绑定有效播放器。
## [br]
## @api public
## [br]
## @return: 有效时返回 true。
func is_valid() -> bool:
	return get_player() != null


## 检查该句柄是否已经收到停止请求。
## [br]
## @api public
## [br]
## @return: 已请求停止时返回 true。
func is_stop_requested() -> bool:
	return _stop_requested


## 检查播放会话是否已经进入终态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 已自然完成、失败或停止时返回 true。
func is_terminal() -> bool:
	return _terminal


## 检查播放器是否正在播放。
## [br]
## @api public
## [br]
## @return: 正在播放时返回 true。
func is_playing() -> bool:
	var player: Node = get_player()
	return _is_player_playing(player)


## 停止播放；传入淡出秒数时先淡出再释放。
## [br]
## @api public
## [br]
## @param fade_seconds: 淡出秒数。
func stop(fade_seconds: float = 0.0) -> void:
	if _terminal:
		return
	_stop_requested = true
	_pending_stop_fade_seconds = _finite_non_negative_or_zero(fade_seconds)
	var player: Node = get_player()
	if player == null:
		_finish_stop(null)
		return

	if _pending_stop_fade_seconds > 0.0 and _is_player_playing(player):
		fade_to(-80.0, _pending_stop_fade_seconds)
		var tween: Tween = _get_fade_tween()
		if tween != null:
			var _connect_result_186: Variant = tween.finished.connect(
				_finish_stop.bind(player),
				CONNECT_ONE_SHOT as Object.ConnectFlags
			)
			return

	_finish_stop(player)


## 淡入淡出到指定音量。
## [br]
## @api public
## [br]
## @param volume_db: 目标音量，单位 dB。
## [br]
## @param fade_seconds: 淡入淡出秒数。
func fade_to(volume_db: float, fade_seconds: float) -> void:
	if not _is_finite_float(volume_db) or not _is_finite_float(fade_seconds):
		return
	var player: Node = get_player()
	if player == null:
		return
	_kill_fade_tween()
	if fade_seconds <= 0.0:
		player.set("volume_db", volume_db)
		return

	var tween: Tween = player.create_tween()
	_fade_tween_ref = weakref(tween)
	var _tween_property_result_209: Variant = tween.tween_property(player, "volume_db", volume_db, maxf(fade_seconds, 0.0))


## 设置当前音量。
## [br]
## @api public
## [br]
## @param volume_db: 音量，单位 dB。
func set_volume_db(volume_db: float) -> void:
	if not _is_finite_float(volume_db):
		return
	var player: Node = get_player()
	if player != null:
		player.set("volume_db", volume_db)


## 获取当前音量。
## [br]
## @api public
## [br]
## @return: 音量，单位 dB；无播放器时返回 0。
func get_volume_db() -> float:
	var player: Node = get_player()
	return _get_player_volume_db(player)


## 设置当前音高。
## [br]
## @api public
## [br]
## @param pitch_scale: 音高缩放。
func set_pitch_scale(pitch_scale: float) -> void:
	if not _is_finite_float(pitch_scale):
		return
	var player: Node = get_player()
	if player != null:
		player.set("pitch_scale", pitch_scale)


## 获取当前音高。
## [br]
## @api public
## [br]
## @return: 音高缩放；无播放器时返回 1。
func get_pitch_scale() -> float:
	var player: Node = get_player()
	return _get_player_pitch_scale(player)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return: 调试快照。
## [br]
## @schema return: 调试快照 Dictionary，包含 valid、terminal、playing、channel、volume_db、pitch_scale、owner_valid 和 metadata 字段。
func get_debug_snapshot() -> Dictionary:
	var player: Node = get_player()
	return {
		"valid": player != null,
		"terminal": _terminal,
		"playing": _is_player_playing(player),
		"channel": String(channel),
		"volume_db": _get_player_volume_db(player),
		"pitch_scale": _get_player_pitch_scale(player),
		"owner_valid": _get_owner() != null,
		"metadata": metadata.duplicate(true),
	}




# --- 框架内部方法 ---

## 由音频工具绑定池播放器的本次会话身份及校验器，阻止旧句柄控制复用后的播放器。
## [br]
## @api framework_internal
## [br]
## @param session_id: 播放会话标识，负值规范化为零。
## [br]
## @param validator: 接收播放器和会话标识并返回是否仍拥有该播放的回调。
func _set_playback_session(session_id: int, validator: Callable) -> void:
	_playback_session_id = maxi(session_id, 0)
	_session_validator = validator




## 仅接受当前正数会话标识的自然完成通知；进入终态时不额外发送主动停止信号。
## [br]
## @api framework_internal
## [br]
## @param session_id: 音频工具正在结束的播放会话标识。
func _complete_playback_session(session_id: int) -> void:
	if session_id <= 0 or session_id != _playback_session_id:
		return
	_complete_terminal(false)


# --- 私有/辅助方法 ---

## 完成停止收尾；播放器仍属当前会话时先释放，再进入终态并发出停止信号。
## [br]
## @api private
## [br]
func _finish_stop(player: Node) -> void:
	if _terminal:
		return
	_kill_fade_tween()
	if player == null:
		_complete_terminal(false)
		_emit_stopped_once()
		return
	if not _owns_playback_session(player):
		_complete_terminal(false)
		return

	_release_player(player)
	_complete_terminal(false)
	_emit_stopped_once()


## 仅在会话归属仍有效时停止播放器并调用释放回调。
## [br]
## @api private
## [br]
func _release_player(player: Node) -> void:
	if player == null:
		return
	if not _owns_playback_session(player):
		return
	if is_instance_valid(player) and player.has_method("stop"):
		player.call("stop")
	if is_instance_valid(player) and _release_callback.is_valid():
		_release_callback.call(player)


## 使用标记确保 stopped 信号最多发出一次。
## [br]
## @api private
## [br]
func _emit_stopped_once() -> void:
	if _stopped_emitted:
		return
	_stopped_emitted = true
	stopped.emit(self)






## 首次进入终态时清理淡出、播放器会话与 owner 连接，并可选发信号。
## [br]
## @api private
## [br]
func _complete_terminal(emit_stopped: bool) -> void:
	if _terminal:
		return
	_terminal = true
	_kill_fade_tween()
	_player_ref = null
	_playback_session_id = 0
	_session_validator = Callable()
	_disconnect_owner_exit()
	if emit_stopped:
		_emit_stopped_once()


## 没有有效会话验证器时视为仍拥有播放器，否则采用验证器结果。
## [br]
## @api private
## [br]
func _owns_playback_session(player: Node) -> bool:
	if _playback_session_id <= 0 or not _session_validator.is_valid():
		return true
	return GFVariantData.to_bool(_session_validator.call(player))


## 通过实例保护工具解析 owner 弱引用。
## [br]
## @api private
## [br]
func _get_owner() -> Node:
	if _owner_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_owner_ref)


## 将淡出 Tween 弱引用解析为有效类型，其他情况返回 null。
## [br]
## @api private
## [br]
func _get_fade_tween() -> Tween:
	if _fade_tween_ref == null:
		return null
	var value: Variant = _fade_tween_ref.get_ref()
	if value is Tween:
		var tween: Tween = value
		return tween
	return null


## 终止仍有效的淡出 Tween 并清空其弱引用。
## [br]
## @api private
## [br]
func _kill_fade_tween() -> void:
	var tween: Tween = _get_fade_tween()
	if tween != null and tween.is_valid():
		tween.kill()
	_fade_tween_ref = null


## 读取 2D、3D 或普通 AudioStreamPlayer 的 playing 状态。
## [br]
## @api private
## [br]
func _is_player_playing(player: Node) -> bool:
	if player is AudioStreamPlayer:
		var audio_player: AudioStreamPlayer = player
		return audio_player.playing
	if player is AudioStreamPlayer2D:
		var audio_player_2d: AudioStreamPlayer2D = player
		return audio_player_2d.playing
	if player is AudioStreamPlayer3D:
		var audio_player_3d: AudioStreamPlayer3D = player
		return audio_player_3d.playing
	return false


## 读取三类内置播放器的 dB 音量；其他节点回退到 0。
## [br]
## @api private
## [br]
func _get_player_volume_db(player: Node) -> float:
	if player is AudioStreamPlayer:
		var audio_player: AudioStreamPlayer = player
		return audio_player.volume_db
	if player is AudioStreamPlayer2D:
		var audio_player_2d: AudioStreamPlayer2D = player
		return audio_player_2d.volume_db
	if player is AudioStreamPlayer3D:
		var audio_player_3d: AudioStreamPlayer3D = player
		return audio_player_3d.volume_db
	return 0.0


## 读取三类内置播放器的 pitch scale；其他节点回退到 1。
## [br]
## @api private
## [br]
func _get_player_pitch_scale(player: Node) -> float:
	if player is AudioStreamPlayer:
		var audio_player: AudioStreamPlayer = player
		return audio_player.pitch_scale
	if player is AudioStreamPlayer2D:
		var audio_player_2d: AudioStreamPlayer2D = player
		return audio_player_2d.pitch_scale
	if player is AudioStreamPlayer3D:
		var audio_player_3d: AudioStreamPlayer3D = player
		return audio_player_3d.pitch_scale
	return 1.0


## 断开仍连接的 owner 退出信号并清空 owner 及其淡出设置。
## [br]
## @api private
## [br]
func _disconnect_owner_exit() -> void:
	var owner: Node = _get_owner()
	if owner != null and _owner_exit_callback.is_valid():
		if owner.tree_exiting.is_connected(_owner_exit_callback):
			owner.tree_exiting.disconnect(_owner_exit_callback)
	_owner_ref = null
	_owner_exit_callback = Callable()
	_owner_stop_fade_seconds = 0.0




## 有限值夹到零以上；NaN 或无穷值转换为零。
## [br]
## @api private
## [br]
func _finite_non_negative_or_zero(value: float) -> float:
	return maxf(value, 0.0) if _is_finite_float(value) else 0.0


## 检查浮点值既非 NaN 也非正负无穷。
## [br]
## @api private
## [br]
func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


# --- 信号处理函数 ---

## 先清除所有者弱引用、退出回调与淡出设置，再按捕获的淡出时长停止，避免停止期间重复沿用旧所有者状态。
## [br]
## @api private
func _on_owner_tree_exiting() -> void:
	var fade_seconds: float = _owner_stop_fade_seconds
	_owner_ref = null
	_owner_exit_callback = Callable()
	_owner_stop_fade_seconds = 0.0
	stop(fade_seconds)
