## GFHapticPreset: 通用手柄震动采样预设。
##
## 描述一段弱/强马达强度曲线，不绑定命中、相机、角色、UI 或具体玩法事件。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 7.0.0
class_name GFHapticPreset
extends Resource


# --- 导出变量 ---

## 持续时间，单位秒。
## [br]
## @api public
## [br]
## @since 7.0.0
@export_range(0.0, 60.0, 0.001, "or_greater") var duration_seconds: float = 0.25

## 低频马达基础强度，范围 0 到 1。
## [br]
## @api public
## [br]
## @since 7.0.0
@export_range(0.0, 1.0, 0.001) var weak_magnitude: float = 0.5

## 高频马达基础强度，范围 0 到 1。
## [br]
## @api public
## [br]
## @since 7.0.0
@export_range(0.0, 1.0, 0.001) var strong_magnitude: float = 0.5

## 预设整体强度倍率。
## [br]
## @api public
## [br]
## @since 7.0.0
@export_range(0.0, 4.0, 0.001, "or_greater") var intensity: float = 1.0

## 低频马达强度曲线。为空时使用恒定 1.0。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var weak_curve: Curve = null

## 高频马达强度曲线。为空时使用恒定 1.0。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var strong_curve: Curve = null


# --- 公共方法 ---

## 获取有效持续时间。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 持续时间，最小为 0。
func get_duration_seconds() -> float:
	return maxf(duration_seconds, 0.0)


## 按时间采样震动强度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param elapsed_seconds: 已经过的秒数。
## [br]
## @param strength: 本次播放强度倍率。
## [br]
## @return: 震动采样结果。
## [br]
## @schema return: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。
func sample(elapsed_seconds: float, strength: float = 1.0) -> Dictionary:
	var duration: float = maxf(duration_seconds, 0.0001)
	var progress: float = clampf(elapsed_seconds / duration, 0.0, 1.0)
	return sample_at_progress(progress, strength)


## 按归一化进度采样震动强度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param progress: 归一化进度，范围 0 到 1。
## [br]
## @param strength: 本次播放强度倍率。
## [br]
## @return: 震动采样结果。
## [br]
## @schema return: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。
func sample_at_progress(progress: float, strength: float = 1.0) -> Dictionary:
	var normalized_progress: float = clampf(progress, 0.0, 1.0)
	var sample_strength: float = maxf(strength, 0.0) * maxf(intensity, 0.0)
	var weak_value: float = clampf(weak_magnitude, 0.0, 1.0) * _sample_curve(weak_curve, normalized_progress) * sample_strength
	var strong_value: float = clampf(strong_magnitude, 0.0, 1.0) * _sample_curve(strong_curve, normalized_progress) * sample_strength
	return {
		"weak_magnitude": clampf(weak_value, 0.0, 1.0),
		"strong_magnitude": clampf(strong_value, 0.0, 1.0),
		"intensity": clampf(maxf(weak_value, strong_value), 0.0, 1.0),
		"progress": normalized_progress,
	}


## 创建空震动采样结果。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return: 空震动采样结果。
## [br]
## @schema return: Dictionary，包含零值 weak_magnitude、strong_magnitude、intensity 与 progress。
static func zero_sample() -> Dictionary:
	return {
		"weak_magnitude": 0.0,
		"strong_magnitude": 0.0,
		"intensity": 0.0,
		"progress": 1.0,
	}


## 合并多个震动采样。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param samples: 震动采样数组。
## [br]
## @schema samples: Array[Dictionary]，每项包含 weak_magnitude、strong_magnitude、intensity 与 progress。
## [br]
## @return: 合并后的震动采样。
## [br]
## @schema return: Dictionary，包含合并后的 weak_magnitude、strong_magnitude、intensity 与 progress。
static func combine_samples(samples: Array[Dictionary]) -> Dictionary:
	var weak_total: float = 0.0
	var strong_total: float = 0.0
	var max_intensity: float = 0.0
	var max_progress: float = 0.0
	for sample_data: Dictionary in samples:
		weak_total += GFVariantData.get_option_float(sample_data, "weak_magnitude", 0.0)
		strong_total += GFVariantData.get_option_float(sample_data, "strong_magnitude", 0.0)
		max_intensity = maxf(max_intensity, GFVariantData.get_option_float(sample_data, "intensity", 0.0))
		max_progress = maxf(max_progress, GFVariantData.get_option_float(sample_data, "progress", 0.0))
	var weak_output: float = clampf(weak_total, 0.0, 1.0)
	var strong_output: float = clampf(strong_total, 0.0, 1.0)
	return {
		"weak_magnitude": weak_output,
		"strong_magnitude": strong_output,
		"intensity": clampf(maxf(maxf(weak_output, strong_output), max_intensity), 0.0, 1.0),
		"progress": max_progress,
	}


# --- 私有/辅助方法 ---

func _sample_curve(curve: Curve, progress: float) -> float:
	if curve == null:
		return 1.0
	return clampf(curve.sample_baked(progress), 0.0, 1.0)
