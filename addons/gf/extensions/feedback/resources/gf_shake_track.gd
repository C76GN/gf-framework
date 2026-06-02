## GFShakeTrack: 通用反馈采样轨道。
##
## 描述一段可组合的反馈偏移轨道，供 GFShakePreset 混合采样。
## 轨道只输出通用 position、rotation_degrees 和 scale 偏移，不绑定目标节点或业务事件。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFShakeTrack
extends Resource


# --- 枚举 ---

## 反馈采样波形。
## [br]
## @api public
enum Waveform {
	## 正弦波，适合可预期的摆动。
	SINE,
	## 逐步随机值，适合短促冲击。
	RANDOM,
	## 平滑随机值，适合持续扰动。
	NOISE,
	## 使用 wave_curve 采样，曲线值 0.5 表示零偏移。
	CURVE,
}

## 轨道混合模式。
## [br]
## @api public
enum BlendMode {
	## 叠加到已有采样上。
	ADD,
	## 覆盖已有采样。
	OVERRIDE,
	## 按分量相乘。
	MULTIPLY,
	## 从已有采样中减去当前轨道。
	SUBTRACT,
	## 与已有采样求平均。
	AVERAGE,
	## 逐分量取最大值。
	MAX,
	## 逐分量取最小值。
	MIN,
}


# --- 导出变量 ---

## 是否启用该轨道。
## [br]
## @api public
@export var enabled: bool = true

## 轨道混合模式。
## [br]
## @api public
@export var blend_mode: BlendMode = BlendMode.ADD

## 轨道采样波形。
## [br]
## @api public
@export var waveform: Waveform = Waveform.NOISE

## 轨道开始进度，范围 0 到 1。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var start_progress: float = 0.0

## 轨道结束进度，范围 0 到 1。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var end_progress: float = 1.0

## 轨道振幅倍率。
## [br]
## @api public
@export_range(0.0, 1000.0, 0.001, "or_greater") var amplitude: float = 1.0

## 每秒采样频率。
## [br]
## @api public
@export_range(0.0, 240.0, 0.001, "or_greater") var frequency: float = 24.0

## 位移轴权重。
## [br]
## @api public
@export var position_axis: Vector3 = Vector3.ONE

## 旋转轴权重，单位度。
## [br]
## @api public
@export var rotation_axis_degrees: Vector3 = Vector3.ZERO

## 缩放偏移轴权重。
## [br]
## @api public
@export var scale_axis: Vector3 = Vector3.ZERO

## 轨道包络曲线。为空时使用线性衰减。
## [br]
## @api public
@export var envelope_curve: Curve = null

## 自定义波形曲线。仅在 waveform 为 CURVE 时使用。
## [br]
## @api public
@export var wave_curve: Curve = null

## 确定性采样种子。
## [br]
## @api public
@export var sample_seed: int = 1

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义轨道元数据；框架会在采样结果中复制透传。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 按预设归一化进度采样轨道。
## [br]
## @api public
## [br]
## @param preset_progress: 预设归一化进度，范围 0 到 1。
## [br]
## @param elapsed_seconds: 预设已播放秒数。
## [br]
## @param strength: 播放强度倍率。
## [br]
## @param phase_offset: 相位偏移。
## [br]
## @return 采样结果字典。
## [br]
## @schema return: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float、progress: float、track_progress: float 与 metadata: Dictionary。
func sample(
	preset_progress: float,
	elapsed_seconds: float,
	strength: float = 1.0,
	phase_offset: float = 0.0
) -> Dictionary:
	if not enabled:
		return zero_sample()

	var range_start: float = clampf(start_progress, 0.0, 1.0)
	var range_end: float = clampf(end_progress, range_start, 1.0)
	var clamped_progress: float = clampf(preset_progress, 0.0, 1.0)
	if clamped_progress < range_start or clamped_progress > range_end:
		return zero_sample()

	var local_progress: float = 1.0
	if range_end > range_start:
		local_progress = (clamped_progress - range_start) / (range_end - range_start)

	var intensity: float = amplitude * maxf(strength, 0.0) * _sample_envelope(local_progress)
	var wave_value: Vector3 = _sample_wave_vector(elapsed_seconds, local_progress, phase_offset) * intensity
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
		"progress": clamped_progress,
		"track_progress": local_progress,
		"metadata": metadata.duplicate(true),
	}


## 创建空采样结果。
## [br]
## @api public
## [br]
## @return 空采样结果字典。
## [br]
## @schema return: Dictionary，包含零值 position、rotation_degrees、scale、intensity、progress、track_progress 与空 metadata。
static func zero_sample() -> Dictionary:
	return {
		"position": Vector3.ZERO,
		"rotation_degrees": Vector3.ZERO,
		"scale": Vector3.ZERO,
		"intensity": 0.0,
		"progress": 1.0,
		"track_progress": 1.0,
		"metadata": {},
	}


## 将轨道采样混合到当前采样。
## [br]
## @api public
## [br]
## @param base_sample: 当前合成采样。
## [br]
## @param track_sample: 轨道采样。
## [br]
## @param mode: 混合模式。
## [br]
## @schema base_sample: Dictionary，包含 position、rotation_degrees、scale、intensity 与 progress 字段的当前合成采样。
## [br]
## @schema track_sample: Dictionary，包含 position、rotation_degrees、scale、intensity 与 progress 字段的轨道采样。
## [br]
## @return 合成后的采样。
## [br]
## @schema return: Dictionary，合并后的反馈采样，包含 position、rotation_degrees、scale、intensity 与 progress。
static func blend_sample(base_sample: Dictionary, track_sample: Dictionary, mode: BlendMode) -> Dictionary:
	var result: Dictionary = _normalize_sample(base_sample)
	var next_sample: Dictionary = _normalize_sample(track_sample)
	var position: Vector3 = _get_sample_vector3(result, "position", Vector3.ZERO)
	var rotation_degrees: Vector3 = _get_sample_vector3(result, "rotation_degrees", Vector3.ZERO)
	var scale: Vector3 = _get_sample_vector3(result, "scale", Vector3.ZERO)
	var next_position: Vector3 = _get_sample_vector3(next_sample, "position", Vector3.ZERO)
	var next_rotation_degrees: Vector3 = _get_sample_vector3(next_sample, "rotation_degrees", Vector3.ZERO)
	var next_scale: Vector3 = _get_sample_vector3(next_sample, "scale", Vector3.ZERO)
	match mode:
		BlendMode.OVERRIDE:
			position = next_position
			rotation_degrees = next_rotation_degrees
			scale = next_scale
		BlendMode.MULTIPLY:
			position *= next_position
			rotation_degrees *= next_rotation_degrees
			scale *= next_scale
		BlendMode.SUBTRACT:
			position -= next_position
			rotation_degrees -= next_rotation_degrees
			scale -= next_scale
		BlendMode.AVERAGE:
			position = (position + next_position) * 0.5
			rotation_degrees = (rotation_degrees + next_rotation_degrees) * 0.5
			scale = (scale + next_scale) * 0.5
		BlendMode.MAX:
			position = _vector3_max(position, next_position)
			rotation_degrees = _vector3_max(rotation_degrees, next_rotation_degrees)
			scale = _vector3_max(scale, next_scale)
		BlendMode.MIN:
			position = _vector3_min(position, next_position)
			rotation_degrees = _vector3_min(rotation_degrees, next_rotation_degrees)
			scale = _vector3_min(scale, next_scale)
		_:
			position += next_position
			rotation_degrees += next_rotation_degrees
			scale += next_scale

	result["position"] = position
	result["rotation_degrees"] = rotation_degrees
	result["scale"] = scale
	result["intensity"] = maxf(
		_get_sample_float(result, "intensity", 0.0),
		_get_sample_float(next_sample, "intensity", 0.0)
	)
	result["progress"] = maxf(
		_get_sample_float(result, "progress", 0.0),
		_get_sample_float(next_sample, "progress", 0.0)
	)
	return result


# --- 私有/辅助方法 ---

static func _normalize_sample(sample_data: Dictionary) -> Dictionary:
	return {
		"position": _get_sample_vector3(sample_data, "position", Vector3.ZERO),
		"rotation_degrees": _get_sample_vector3(sample_data, "rotation_degrees", Vector3.ZERO),
		"scale": _get_sample_vector3(sample_data, "scale", Vector3.ZERO),
		"intensity": _get_sample_float(sample_data, "intensity", 0.0),
		"progress": _get_sample_float(sample_data, "progress", 0.0),
	}


static func _get_sample_vector3(sample_data: Dictionary, key: String, default_value: Vector3) -> Vector3:
	return GFVariantData.get_option_vector3(sample_data, key, default_value)


static func _get_sample_float(sample_data: Dictionary, key: String, default_value: float) -> float:
	return GFVariantData.get_option_float(sample_data, key, default_value)


static func _vector3_max(left: Vector3, right: Vector3) -> Vector3:
	return Vector3(
		maxf(left.x, right.x),
		maxf(left.y, right.y),
		maxf(left.z, right.z)
	)


static func _vector3_min(left: Vector3, right: Vector3) -> Vector3:
	return Vector3(
		minf(left.x, right.x),
		minf(left.y, right.y),
		minf(left.z, right.z)
	)


func _sample_envelope(progress: float) -> float:
	if envelope_curve != null:
		return maxf(envelope_curve.sample_baked(progress), 0.0)
	return 1.0 - progress


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
			var step: int = floori(elapsed_seconds * maxf(frequency, 1.0))
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
	var step: int = floori(cursor)
	var blend: float = smoothstep(0.0, 1.0, cursor - float(step))
	return Vector3(
		lerpf(_hash_noise(step, sample_seed + 11), _hash_noise(step + 1, sample_seed + 11), blend),
		lerpf(_hash_noise(step, sample_seed + 37), _hash_noise(step + 1, sample_seed + 37), blend),
		lerpf(_hash_noise(step, sample_seed + 73), _hash_noise(step + 1, sample_seed + 73), blend)
	)


func _hash_noise(step: int, salt: int) -> float:
	var value: int = step * 1103515245 + salt * 12345 + sample_seed * 2654435761
	value = value ^ (value >> 13)
	value = value * 1274126177
	value = value ^ (value >> 16)
	var normalized: float = float(value & 0x7fffffff) / float(0x7fffffff)
	return normalized * 2.0 - 1.0
