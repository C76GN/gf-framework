## GFShakePreset: 通用反馈采样预设。
##
## 描述一段可采样的位移、旋转和缩放偏移，不绑定相机、角色、UI 或业务事件。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFShakePreset
extends Resource


# --- 枚举 ---

## 反馈采样波形。
## [br]
## @api public
enum Waveform {
	## 正弦波，适合可预期的摆动。
	SINE,
	## 逐步随机值，适合冲击感。
	RANDOM,
	## 平滑随机值，适合持续扰动。
	NOISE,
	## 使用 wave_curve 采样，曲线值 0.5 表示零偏移。
	CURVE,
}


# --- 导出变量 ---

## 持续时间，单位秒。
## [br]
## @api public
@export_range(0.0, 60.0, 0.001, "or_greater") var duration_seconds: float = 0.25

## 采样振幅倍率。
## [br]
## @api public
@export_range(0.0, 1000.0, 0.001, "or_greater") var amplitude: float = 1.0

## 每秒采样频率。
## [br]
## @api public
@export_range(0.0, 240.0, 0.001, "or_greater") var frequency: float = 24.0

## 波形类型。
## [br]
## @api public
@export var waveform: Waveform = Waveform.NOISE

## 位移轴权重。
## [br]
## @api public
@export var position_axis: Vector3 = Vector3.ONE

## 旋转轴权重，单位度。
## [br]
## @api public
@export var rotation_axis_degrees: Vector3 = Vector3.ZERO

## 缩放偏移轴权重。返回值是叠加到基础 scale 上的偏移。
## [br]
## @api public
@export var scale_axis: Vector3 = Vector3.ZERO

## 包络曲线。为空时使用线性衰减；曲线值越高，当前采样越强。
## [br]
## @api public
@export var decay_curve: Curve = null

## 自定义波形曲线。仅在 waveform 为 CURVE 时使用，曲线值 0.5 表示零偏移。
## [br]
## @api public
@export var wave_curve: Curve = null

## 确定性采样种子。
## [br]
## @api public
@export var sample_seed: int = 1

## 可组合反馈轨道。为空时使用兼容的单波形字段。
## [br]
## @api public
## [br]
## @schema tracks: Array[GFShakeTrack]，按顺序采样并根据每个轨道 blend_mode 合成。
@export var tracks: Array[GFShakeTrack] = []


# --- 公共方法 ---

## 获取有效持续时间。
## [br]
## @api public
## [br]
## @return 持续时间，最小为 0。
func get_duration_seconds() -> float:
	return maxf(duration_seconds, 0.0)


## 按时间采样反馈偏移。
## [br]
## @api public
## [br]
## @param elapsed_seconds: 已经过的秒数。
## [br]
## @param strength: 本次播放强度倍率。
## [br]
## @param phase_offset: 相位偏移，用于同一预设多次播放时错开采样。
## [br]
## @return 采样结果字典。
## [br]
## @schema return: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。
func sample(elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0) -> Dictionary:
	var duration: float = maxf(duration_seconds, 0.0001)
	var progress: float = clampf(elapsed_seconds / duration, 0.0, 1.0)
	return sample_at_progress(progress, elapsed_seconds, strength, phase_offset)


## 按归一化进度采样反馈偏移。
## [br]
## @api public
## [br]
## @param progress: 归一化进度，范围 0 到 1。
## [br]
## @param elapsed_seconds: 已经过的秒数。
## [br]
## @param strength: 本次播放强度倍率。
## [br]
## @param phase_offset: 相位偏移。
## [br]
## @return 采样结果字典。
## [br]
## @schema return: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。
func sample_at_progress(
	progress: float,
	elapsed_seconds: float,
	strength: float = 1.0,
	phase_offset: float = 0.0
) -> Dictionary:
	var normalized_progress: float = clampf(progress, 0.0, 1.0)
	if has_tracks():
		return _sample_tracks(normalized_progress, elapsed_seconds, strength, phase_offset)

	var intensity: float = amplitude * maxf(strength, 0.0) * _sample_envelope(normalized_progress)
	var wave_value: Vector3 = _sample_wave_vector(elapsed_seconds, normalized_progress, phase_offset) * intensity
	return {
		"position": Vector3(
			position_axis.x * wave_value.x,
			position_axis.y * wave_value.y,
			position_axis.z * wave_value.z
		),
		"rotation_degrees": Vector3(
			rotation_axis_degrees.x * wave_value.x,
			rotation_axis_degrees.y * wave_value.y,
			rotation_axis_degrees.z * wave_value.z
		),
		"scale": Vector3(
			scale_axis.x * wave_value.x,
			scale_axis.y * wave_value.y,
			scale_axis.z * wave_value.z
		),
		"intensity": intensity,
		"progress": normalized_progress,
	}


## 添加反馈轨道。
## [br]
## @api public
## [br]
## @param track: 反馈轨道。
## [br]
## @return 添加成功返回 true。
func add_track(track: GFShakeTrack) -> bool:
	if track == null:
		return false
	tracks.append(track)
	return true


## 清空反馈轨道。
## [br]
## @api public
func clear_tracks() -> void:
	tracks.clear()


## 检查是否存在有效轨道。
## [br]
## @api public
## [br]
## @return 存在有效轨道返回 true。
func has_tracks() -> bool:
	for track: GFShakeTrack in tracks:
		if track != null and track.enabled:
			return true
	return false


## 创建空采样结果。
## [br]
## @api public
## [br]
## @return 空采样结果字典。
## [br]
## @schema return: Dictionary，包含零值 position、rotation_degrees、scale、intensity 与 progress。
static func zero_sample() -> Dictionary:
	return {
		"position": Vector3.ZERO,
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ZERO,
		"intensity": 0.0,
		"progress": 1.0,
	}


## 合并多个反馈采样。
## [br]
## @api public
## [br]
## @param samples: 采样结果数组。
## [br]
## @schema samples: Array[Dictionary]，每项包含 position、rotation_degrees、scale、intensity 与 progress。
## [br]
## @return 合并后的采样结果。
## [br]
## @schema return: Dictionary，合并后的反馈采样，包含 position、rotation_degrees、scale、intensity 与 progress。
static func combine_samples(samples: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = zero_sample()
	var max_intensity: float = 0.0
	var max_progress: float = 0.0
	for sample_data: Dictionary in samples:
		result["position"] = _read_sample_vector3(result, "position") + _read_sample_vector3(sample_data, "position")
		result["rotation_degrees"] = _read_sample_vector3(result, "rotation_degrees") + _read_sample_vector3(sample_data, "rotation_degrees")
		result["scale"] = _read_sample_vector3(result, "scale") + _read_sample_vector3(sample_data, "scale")
		max_intensity = maxf(max_intensity, GFVariantData.get_option_float(sample_data, "intensity", 0.0))
		max_progress = maxf(max_progress, GFVariantData.get_option_float(sample_data, "progress", 0.0))
	result["intensity"] = max_intensity
	result["progress"] = max_progress
	return result


# --- 私有/辅助方法 ---

func _sample_envelope(progress: float) -> float:
	if decay_curve != null:
		return maxf(decay_curve.sample_baked(progress), 0.0)
	return 1.0 - progress


func _sample_tracks(
	progress: float,
	elapsed_seconds: float,
	strength: float,
	phase_offset: float
) -> Dictionary:
	var result: Dictionary = zero_sample()
	result["progress"] = progress
	var has_track_sample: bool = false
	for track: GFShakeTrack in tracks:
		if track == null or not track.enabled:
			continue
		var track_sample: Dictionary = track.sample(progress, elapsed_seconds, strength, phase_offset)
		if not has_track_sample:
			if _is_zero_sample(track_sample):
				continue
			result = track_sample.duplicate(true)
			has_track_sample = true
		else:
			result = GFShakeTrack.blend_sample(result, track_sample, track.blend_mode)
	result["progress"] = progress
	return result


func _sample_wave_vector(elapsed_seconds: float, progress: float, phase_offset: float) -> Vector3:
	match waveform:
		Waveform.SINE:
			var phase: float = (elapsed_seconds * maxf(frequency, 0.0) + phase_offset) * TAU
			return Vector3(
				sin(phase),
				sin(phase + TAU / 3.0),
				sin(phase + TAU * 2.0 / 3.0)
			)
		Waveform.RANDOM:
			var step: int = GFVariantData.to_int(floor(elapsed_seconds * maxf(frequency, 1.0)))
			return Vector3(
				_hash_noise(step, sample_seed + 11),
				_hash_noise(step, sample_seed + 37),
				_hash_noise(step, sample_seed + 73)
			)
		Waveform.CURVE:
			var curve_value: float = 0.5
			if wave_curve != null:
				curve_value = wave_curve.sample_baked(progress)
			var mapped: float = clampf(curve_value, 0.0, 1.0) * 2.0 - 1.0
			return Vector3(mapped, mapped, mapped)
		_:
			return _sample_noise_vector(elapsed_seconds)


func _sample_noise_vector(elapsed_seconds: float) -> Vector3:
	var sample_frequency: float = maxf(frequency, 1.0)
	var cursor: float = elapsed_seconds * sample_frequency
	var step: int = GFVariantData.to_int(floor(cursor))
	var blend: float = smoothstep(0.0, 1.0, cursor - float(step))
	return Vector3(
		lerpf(_hash_noise(step, sample_seed + 11), _hash_noise(step + 1, sample_seed + 11), blend),
		lerpf(_hash_noise(step, sample_seed + 37), _hash_noise(step + 1, sample_seed + 37), blend),
		lerpf(_hash_noise(step, sample_seed + 73), _hash_noise(step + 1, sample_seed + 73), blend)
	)


func _hash_noise(step: int, salt: int) -> float:
	var value: int = int(step * 1103515245 + salt * 12345 + sample_seed * 2654435761)
	value = value ^ (value >> 13)
	value = value * 1274126177
	value = value ^ (value >> 16)
	var normalized: float = float(value & 0x7fffffff) / float(0x7fffffff)
	return normalized * 2.0 - 1.0


static func _read_sample_vector3(sample_data: Dictionary, key: Variant) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(sample_data, key, Vector3.ZERO)
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


static func _is_zero_sample(sample_data: Dictionary) -> bool:
	return (
		_read_sample_vector3(sample_data, "position") == Vector3.ZERO
		and _read_sample_vector3(sample_data, "rotation_degrees") == Vector3.ZERO
		and _read_sample_vector3(sample_data, "scale") == Vector3.ZERO
		and is_zero_approx(GFVariantData.get_option_float(sample_data, "intensity", 0.0))
	)
