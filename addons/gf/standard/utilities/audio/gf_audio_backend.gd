## GFAudioBackend: GFAudioUtility 的可插拔音频后端协议。
##
## 默认实现不处理任何请求。项目或扩展可继承它，把部分音频事件转交给
## 外部中间件、平台接口或自定义混音系统；未声明可处理的请求会回退到 Godot 默认播放器。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFAudioBackend
extends RefCounted


# --- 公共变量 ---

## 后端能力声明。
## [br]
## @api public
var capabilities: GFAudioBackendCapability = GFAudioBackendCapability.new()


# --- 私有变量 ---

var _host_ref: WeakRef = null


# --- 公共方法 ---

## 释放后端状态。
## [br]
## @api public
func dispose() -> void:
	_host_ref = null


## 获取宿主音频工具。
## [br]
## @api public
## [br]
## @return: 宿主对象；不存在时返回 null。
func get_host() -> Object:
	return _host_ref.get_ref() if _host_ref != null else null


## 获取后端能力声明副本。
## [br]
## @api public
## [br]
## @return: 后端能力声明。
func get_capabilities() -> GFAudioBackendCapability:
	return capabilities.duplicate_capability() if capabilities != null else GFAudioBackendCapability.new()


## 检查后端是否声明了指定能力。
## [br]
## @api public
## [br]
## @param capability_id: 能力标识。
## [br]
## @return: 支持返回 true。
func has_capability(capability_id: StringName) -> bool:
	return capabilities != null and capabilities.has_capability(capability_id)


## 判断后端是否可处理指定资源路径。
## [br]
## @api public
## [br]
## @param _path: 音频资源路径或后端事件路径。
## [br]
## @param _channel: 通道标识，如 bgm、sfx、ambient。
## [br]
## @param _context: 请求上下文。
## [br]
## @schema _context: 请求上下文 Dictionary；键和值由 GFAudioUtility 或具体后端约定。
## [br]
## @return: 可处理时返回 true。
func can_handle_path(_path: String, _channel: StringName, _context: Dictionary = {}) -> bool:
	return false


## 判断后端是否可处理指定音频片段。
## [br]
## @api public
## [br]
## @param _clip: 音频片段配置。
## [br]
## @param _channel: 通道标识，如 bgm、sfx、ambient。
## [br]
## @param _context: 请求上下文。
## [br]
## @schema _context: 请求上下文 Dictionary；键和值由 GFAudioUtility 或具体后端约定。
## [br]
## @return: 可处理时返回 true。
func can_handle_clip(_clip: GFAudioClip, _channel: StringName, _context: Dictionary = {}) -> bool:
	return false


## 播放 BGM 路径。
## [br]
## @api public
## [br]
## @param _path: 音频资源路径或后端事件路径。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds、loop 和 metadata。
## [br]
## @return: 已处理返回 true。
func play_bgm_path(_path: String, _options: Dictionary = {}) -> bool:
	return false


## 播放 BGM Clip。
## [br]
## @api public
## [br]
## @param _clip: 音频片段配置。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds、loop 和 metadata。
## [br]
## @return: 已处理返回 true。
func play_bgm_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> bool:
	return false


## 停止 BGM。
## [br]
## @api public
## [br]
## @param _fade_seconds: 淡出秒数。
## [br]
## @return: 已处理返回 true。
func stop_bgm(_fade_seconds: float = 0.0) -> bool:
	return false


## 暂停 BGM。
## [br]
## @api public
## [br]
## @param _fade_seconds: 淡出到暂停的秒数。
## [br]
## @return: 已处理返回 true。
func pause_bgm(_fade_seconds: float = 0.0) -> bool:
	return false


## 恢复 BGM。
## [br]
## @api public
## [br]
## @param _from_position: 大于等于 0 时从指定秒数恢复。
## [br]
## @param _fade_seconds: 淡入秒数。
## [br]
## @return: 已处理返回 true。
func resume_bgm(_from_position: float = -1.0, _fade_seconds: float = 0.0) -> bool:
	return false


## 跳转当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @param _position_seconds: 目标秒数。
## [br]
## @return: 已处理返回 true。
func seek_bgm(_position_seconds: float) -> bool:
	return false


## 获取当前 BGM 播放位置。
## [br]
## @api public
## [br]
## @return: 播放秒数；负数表示后端不处理该查询。
func get_bgm_playback_position() -> float:
	return -1.0


## 查询 BGM session 是否仍存在。
## 暂停中的 BGM 仍应返回 true；接管 BGM 的项目后端必须覆写该方法。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return: BGM 正在播放或暂停时返回 true；默认 fail closed 返回 false。
func is_bgm_playing() -> bool:
	return false


## 查询 BGM 是否暂停。
## [br]
## @api public
## [br]
## @return: 已暂停返回 true。
func is_bgm_paused() -> bool:
	return false


## 播放环境音路径。
## [br]
## @api public
## [br]
## @param _path: 音频资源路径或后端事件路径。
## [br]
## @param _channel: 环境音通道。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds 和 metadata。
## [br]
## @return: 已处理返回 true。
func play_ambient_path(_path: String, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:
	return false


## 播放环境音 Clip。
## [br]
## @api public
## [br]
## @param _clip: 音频片段配置。
## [br]
## @param _channel: 环境音通道。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、fade_seconds 和 metadata。
## [br]
## @return: 已处理返回 true。
func play_ambient_clip(_clip: GFAudioClip, _channel: StringName = &"default", _options: Dictionary = {}) -> bool:
	return false


## 停止环境音通道。
## [br]
## @api public
## [br]
## @param _channel: 环境音通道。
## [br]
## @param _fade_seconds: 淡出秒数。
## [br]
## @return: 已处理返回 true。
func stop_ambient(_channel: StringName = &"default", _fade_seconds: float = 0.0) -> bool:
	return false


## 停止全部环境音。
## [br]
## @api public
## [br]
## @param _fade_seconds: 淡出秒数。
## [br]
## @return: 已处理返回 true。
func stop_all_ambient(_fade_seconds: float = 0.0) -> bool:
	return false


## 查询环境音通道是否播放中。
## [br]
## @api public
## [br]
## @param _channel: 环境音通道。
## [br]
## @return: 后端通道正在播放时返回 true。
func is_ambient_playing(_channel: StringName = &"default") -> bool:
	return false


## 播放 SFX 路径。
## [br]
## @api public
## [br]
## @param _path: 音频资源路径或后端事件路径。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel 和 metadata。
## [br]
## @return: 控制句柄；未处理返回 null。
func play_sfx_path(_path: String, _options: Dictionary = {}) -> GFAudioEmitterHandle:
	return null


## 播放 SFX Clip。
## [br]
## @api public
## [br]
## @param _clip: 音频片段配置。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel 和 metadata。
## [br]
## @return: 控制句柄；未处理返回 null。
func play_sfx_clip(_clip: GFAudioClip, _options: Dictionary = {}) -> GFAudioEmitterHandle:
	return null


## 停止全部 SFX。
## [br]
## @api public
## [br]
## @param _fade_seconds: 淡出秒数。
## [br]
## @return: 已处理返回 true。
func stop_all_sfx(_fade_seconds: float = 0.0) -> bool:
	return false


## 播放空间 SFX Clip。
## [br]
## @api public
## [br]
## @param _clip: 音频片段配置。
## [br]
## @param _source: 2D 或 3D 声源节点。
## [br]
## @param _follow_source: 是否跟随声源。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；常见字段包含 volume_db、pitch_scale、owner、channel、follow_source、spatial_settings 和 metadata。
## [br]
## @return: 控制句柄；未处理返回 null。
func play_spatial_sfx_clip(
	_clip: GFAudioClip,
	_source: Node,
	_follow_source: bool = false,
	_options: Dictionary = {}
) -> GFAudioEmitterHandle:
	return null


## 判断后端是否可处理资源化音频事件。
## [br]
## @api public
## [br]
## @param _event: 音频事件。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；键和值由 GFAudioUtility 或具体后端约定。
## [br]
## @return: 可处理时返回 true。
func can_handle_event(_event: GFAudioEvent, _options: Dictionary = {}) -> bool:
	return false


## 发布资源化音频事件。
## [br]
## @api public
## [br]
## @since 3.3.0
## [br]
## @param _event: 音频事件。
## [br]
## @param _options: 请求选项。
## [br]
## @schema _options: 请求选项 Dictionary；键和值由 GFAudioUtility 或具体后端约定。
## [br]
## @return: 控制句柄；未处理返回 null，GFAudioUtility 会继续本地回退。已处理但不暴露原生播放器时仍须返回非 null 句柄。
func post_event(_event: GFAudioEvent, _options: Dictionary = {}) -> GFAudioEmitterHandle:
	return null


## 设置音频参数。
## [br]
## @api public
## [br]
## @param _parameter: 参数请求。
## [br]
## @return: 已处理返回 true。
func set_parameter(_parameter: GFAudioParameter) -> bool:
	return false


## 设置音频状态。
## [br]
## @api public
## [br]
## @param _state: 状态请求。
## [br]
## @return: 已处理返回 true。
func set_state(_state: GFAudioState) -> bool:
	return false


## 设置音频开关。
## [br]
## @api public
## [br]
## @param _switch: 开关请求。
## [br]
## @return: 已处理返回 true。
func set_switch(_switch: GFAudioSwitch) -> bool:
	return false


## 设置总线音量。
## [br]
## @api public
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @param _volume_linear: 线性音量。
## [br]
## @return: 已处理返回 true。
func set_bus_volume(_bus_name: String, _volume_linear: float) -> bool:
	return false


## 设置总线 dB 音量。
## [br]
## @api public
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @param _volume_db: dB 音量。
## [br]
## @param _transition_seconds: 平滑过渡秒数。
## [br]
## @return: 已处理返回 true。
func set_bus_volume_db(_bus_name: String, _volume_db: float, _transition_seconds: float = 0.0) -> bool:
	return false


## 设置总线静音状态。
## [br]
## @api public
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @param _muted: 是否静音。
## [br]
## @return: 已处理返回 true。
func set_bus_mute(_bus_name: String, _muted: bool) -> bool:
	return false


## 设置总线效果属性。
## [br]
## @api public
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @param _effect_ref: 效果索引、名称或后端自定义效果引用。
## [br]
## @schema _effect_ref: int/String/StringName 或后端自定义引用。
## [br]
## @param _property_name: 效果属性名。
## [br]
## @param _value: 属性值。
## [br]
## @schema _value: 属性值 Variant；键和值由后端或 GFAudioUtility 约定。
## [br]
## @param _transition_seconds: 平滑过渡秒数。
## [br]
## @return: 已处理返回 true。
func set_bus_effect_property(
	_bus_name: String,
	_effect_ref: Variant,
	_property_name: StringName,
	_value: Variant,
	_transition_seconds: float = 0.0
) -> bool:
	return false


## 应用混音快照。
## [br]
## @api public
## [br]
## @param _snapshot: 混音快照。
## [br]
## @schema _snapshot: Dictionary，可包含 buses 和 effects 字段，或后端自定义字段。
## [br]
## @param _transition_seconds: 默认平滑过渡秒数。
## [br]
## @return: 已处理返回 true。
func apply_mix_snapshot(_snapshot: Dictionary, _transition_seconds: float = 0.0) -> bool:
	return false


## 获取总线音量。返回负数表示未处理。
## [br]
## @api public
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @return: 线性音量；负数表示后端不处理该总线。
func get_bus_volume(_bus_name: String) -> float:
	return -1.0


## 获取总线静音状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param _bus_name: 总线名或后端通道名。
## [br]
## @return: 已处理时返回 bool；无法观测该总线时返回 null。
## [br]
## @schema return: bool 或 null；null 表示后端不处理该总线的静音查询。
func get_bus_mute(_bus_name: String) -> Variant:
	return null


## 获取后端调试快照。
## [br]
## @api public
## [br]
## @return: 调试数据。
## [br]
## @schema return: 调试快照 Dictionary；键和值由具体后端约定。
func get_debug_snapshot() -> Dictionary:
	return {}


# --- 框架内部方法 ---

## 由 GFAudioUtility 调用，绑定宿主音频工具。
## [br]
## @api framework_internal
## [br]
## @param host: GFAudioUtility 实例。
func setup(host: Object) -> void:
	_host_ref = weakref(host) if host != null else null
