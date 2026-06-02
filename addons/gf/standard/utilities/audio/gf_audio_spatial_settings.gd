## GFAudioSpatialSettings: 空间音效播放器参数。
##
## 只描述 Godot 2D/3D 空间播放器的通用衰减、距离、区域、复音和播放类型参数。
## 该资源可挂到 `GFAudioClip.spatial_settings`，仅在空间 SFX 播放路径中应用。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.19.0
class_name GFAudioSpatialSettings
extends Resource


# --- 导出变量 ---

## 最大同时复音数量。
## [br]
## @api public
@export_range(1, 128, 1, "or_greater") var max_polyphony: int = 1

## 声像强度。
## [br]
## @api public
@export_range(0.0, 3.0, 0.01, "or_greater") var panning_strength: float = 1.0

## 播放类型。0 为 Default，1 为 Stream，2 为 Sample。
## [br]
## @api public
@export_enum("Default", "Stream", "Sample") var playback_type: int = 0

## 2D 音频区域掩码。
## [br]
## @api public
@export_flags_2d_physics var area_mask_2d: int = 1

## 2D 最大传播距离，单位像素。
## [br]
## @api public
@export_range(1.0, 4096.0, 1.0, "or_greater", "exp", "suffix:px") var max_distance_2d: float = 2000.0

## 2D 衰减强度。
## [br]
## @api public
@export_exp_easing("attenuation") var attenuation_2d: float = 1.0

## 3D 衰减模型。0 为 Inverse，1 为 Inverse Square，2 为 Logarithmic，3 为 Disabled。
## [br]
## @api public
@export_enum("Inverse", "Inverse Square", "Logarithmic", "Disabled") var attenuation_model_3d: int = 0

## 3D 音频区域掩码。
## [br]
## @api public
@export_flags_3d_physics var area_mask_3d: int = 1

## 3D 单位尺寸。
## [br]
## @api public
@export_range(0.1, 100.0, 0.01, "or_greater") var unit_size_3d: float = 10.0

## 3D 最大增益，单位 dB。
## [br]
## @api public
@export_range(-24.0, 6.0, 0.1, "suffix:dB") var max_db_3d: float = 3.0

## 3D 最大传播距离，0 表示不限制。
## [br]
## @api public
@export_range(0.0, 4096.0, 0.01, "or_greater", "suffix:m") var max_distance_3d: float = 0.0

## 是否启用 3D 发射角过滤。
## [br]
## @api public
@export var emission_angle_enabled_3d: bool = false

## 3D 发射角角度。
## [br]
## @api public
@export_range(0.1, 90.0, 0.1, "degrees") var emission_angle_degrees_3d: float = 45.0

## 3D 发射角外的衰减，单位 dB。
## [br]
## @api public
@export_range(-80.0, 0.0, 0.1, "suffix:dB") var emission_angle_filter_attenuation_db_3d: float = -12.0

## 3D 距离衰减滤波截止频率。
## [br]
## @api public
@export_range(1.0, 20500.0, 1.0, "suffix:Hz") var attenuation_filter_cutoff_hz_3d: float = 5000.0

## 3D 距离衰减滤波增益，单位 dB。
## [br]
## @api public
@export_range(-80.0, 0.0, 0.1, "suffix:dB") var attenuation_filter_db_3d: float = -24.0

## 3D 多普勒追踪模式。0 为 Disabled，1 为 Idle，2 为 Physics。
## [br]
## @api public
@export_enum("Disabled", "Idle", "Physics") var doppler_tracking_3d: int = 0


# --- 公共方法 ---

## 将设置应用到 2D 空间播放器。
## [br]
## @api public
## [br]
## @param player: 目标 2D 空间播放器。
## [br]
## @return: 成功应用时返回 true。
func apply_to_2d(player: AudioStreamPlayer2D) -> bool:
	if player == null:
		return false

	player.max_polyphony = maxi(max_polyphony, 1)
	player.panning_strength = maxf(panning_strength, 0.0)
	player.area_mask = area_mask_2d
	player.playback_type = _to_playback_type(playback_type)
	player.max_distance = maxf(max_distance_2d, 0.0)
	player.attenuation = maxf(attenuation_2d, 0.0)
	return true


## 将设置应用到 3D 空间播放器。
## [br]
## @api public
## [br]
## @param player: 目标 3D 空间播放器。
## [br]
## @return: 成功应用时返回 true。
func apply_to_3d(player: AudioStreamPlayer3D) -> bool:
	if player == null:
		return false

	player.max_polyphony = maxi(max_polyphony, 1)
	player.panning_strength = maxf(panning_strength, 0.0)
	player.area_mask = area_mask_3d
	player.playback_type = _to_playback_type(playback_type)
	player.attenuation_model = _to_attenuation_model(attenuation_model_3d)
	player.unit_size = maxf(unit_size_3d, 0.01)
	player.max_db = clampf(max_db_3d, -80.0, 24.0)
	player.max_distance = maxf(max_distance_3d, 0.0)
	player.emission_angle_enabled = emission_angle_enabled_3d
	player.emission_angle_degrees = clampf(emission_angle_degrees_3d, 0.1, 180.0)
	player.emission_angle_filter_attenuation_db = clampf(emission_angle_filter_attenuation_db_3d, -80.0, 0.0)
	player.attenuation_filter_cutoff_hz = clampf(attenuation_filter_cutoff_hz_3d, 1.0, 20500.0)
	player.attenuation_filter_db = clampf(attenuation_filter_db_3d, -80.0, 0.0)
	player.doppler_tracking = _to_doppler_tracking(doppler_tracking_3d)
	return true


# --- 私有/辅助方法 ---

func _to_playback_type(value: int) -> AudioServer.PlaybackType:
	match clampi(value, 0, 2):
		AudioServer.PLAYBACK_TYPE_STREAM:
			return AudioServer.PLAYBACK_TYPE_STREAM
		AudioServer.PLAYBACK_TYPE_SAMPLE:
			return AudioServer.PLAYBACK_TYPE_SAMPLE
		_:
			return AudioServer.PLAYBACK_TYPE_DEFAULT


func _to_attenuation_model(value: int) -> AudioStreamPlayer3D.AttenuationModel:
	match clampi(value, 0, 3):
		AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE:
			return AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC:
			return AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		AudioStreamPlayer3D.ATTENUATION_DISABLED:
			return AudioStreamPlayer3D.ATTENUATION_DISABLED
		_:
			return AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE


func _to_doppler_tracking(value: int) -> AudioStreamPlayer3D.DopplerTracking:
	match clampi(value, 0, 2):
		AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP:
			return AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP:
			return AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		_:
			return AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
