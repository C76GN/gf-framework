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

var _player_ref: WeakRef = null
var _release_callback: Callable = Callable()
var _stop_requested: bool = false
var _pending_stop_fade_seconds: float = 0.0
var _fade_tween_ref: WeakRef = null
var _owner_ref: WeakRef = null
var _owner_exit_callback: Callable = Callable()
var _owner_stop_fade_seconds: float = 0.0


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
	_owner_stop_fade_seconds = maxf(fade_seconds, 0.0)
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
	if _player_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_player_ref)


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
	_stop_requested = true
	_pending_stop_fade_seconds = maxf(fade_seconds, 0.0)
	var player: Node = get_player()
	if player == null:
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
	var player: Node = get_player()
	if player == null:
		return
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
## @return: 调试快照。
## [br]
## @schema return: 调试快照 Dictionary，包含 valid、playing、channel、volume_db、pitch_scale、owner_valid 和 metadata 字段。
func get_debug_snapshot() -> Dictionary:
	var player: Node = get_player()
	return {
		"valid": player != null,
		"playing": _is_player_playing(player),
		"channel": String(channel),
		"volume_db": _get_player_volume_db(player),
		"pitch_scale": _get_player_pitch_scale(player),
		"owner_valid": _get_owner() != null,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _finish_stop(player: Node) -> void:
	if player == null:
		_player_ref = null
		_disconnect_owner_exit()
		stopped.emit(self)
		return

	if is_instance_valid(player) and player.has_method("stop"):
		player.call("stop")
	if is_instance_valid(player) and _release_callback.is_valid():
		_release_callback.call(player)
	_player_ref = null
	_disconnect_owner_exit()
	stopped.emit(self)


func _get_owner() -> Node:
	if _owner_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(_owner_ref)


func _get_fade_tween() -> Tween:
	if _fade_tween_ref == null:
		return null
	var value: Variant = _fade_tween_ref.get_ref()
	if value is Tween:
		var tween: Tween = value
		return tween
	return null


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


func _disconnect_owner_exit() -> void:
	var owner: Node = _get_owner()
	if owner != null and _owner_exit_callback.is_valid():
		if owner.tree_exiting.is_connected(_owner_exit_callback):
			owner.tree_exiting.disconnect(_owner_exit_callback)
	_owner_ref = null
	_owner_exit_callback = Callable()
	_owner_stop_fade_seconds = 0.0


func _on_owner_tree_exiting() -> void:
	var fade_seconds: float = _owner_stop_fade_seconds
	_owner_ref = null
	_owner_exit_callback = Callable()
	_owner_stop_fade_seconds = 0.0
	stop(fade_seconds)
