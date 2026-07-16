## GFCameraBlend: 通用相机过渡资源。
##
## 描述两个相机姿态之间的时间和缓动方式，不绑定具体相机节点、
## 目标选择规则、反馈效果或场景业务。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFCameraBlend
extends Resource


# --- 导出变量 ---

## 过渡持续时间，单位秒。小于等于 0 时表示立即切换。
## [br]
## @api public
## [br]
## @since 3.17.0
@export_range(0.0, 60.0, 0.001, "or_greater") var duration_seconds: float:
	get:
		return _duration_seconds
	set(value):
		if is_finite(value):
			_duration_seconds = maxf(value, 0.0)

## Tween 过渡类型。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var transition_type: Tween.TransitionType:
	get:
		return _transition_type
	set(value):
		_transition_type = value if _is_valid_transition_type(value) else Tween.TRANS_LINEAR

## Tween 缓动类型。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var ease_type: Tween.EaseType:
	get:
		return _ease_type
	set(value):
		_ease_type = value if _is_valid_ease_type(value) else Tween.EASE_IN_OUT


# --- 私有变量 ---

var _duration_seconds: float = 0.35
var _transition_type: Tween.TransitionType = Tween.TRANS_SINE
var _ease_type: Tween.EaseType = Tween.EASE_IN_OUT


# --- 公共方法 ---

## 是否为立即切换。
## [br]
## @api public
## [br]
## @return 持续时间小于等于 0 时返回 true。
func is_instant() -> bool:
	return duration_seconds <= 0.0 or not _is_finite_float(duration_seconds)


## 按已过时间采样 0..1 权重。
## [br]
## @api public
## [br]
## @param elapsed_seconds: 已过时间。
## [br]
## @return 缓动后的权重。
func sample_weight(elapsed_seconds: float) -> float:
	if is_instant():
		return 1.0
	var safe_elapsed: float = elapsed_seconds if _is_finite_float(elapsed_seconds) else 0.0
	var clamped_elapsed: float = clampf(safe_elapsed, 0.0, duration_seconds)
	return clampf(GFVariantData.to_float(Tween.interpolate_value(
		0.0,
		1.0,
		clamped_elapsed,
		duration_seconds,
		transition_type,
		ease_type
	)), 0.0, 1.0)


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新过渡资源。
func duplicate_blend() -> GFCameraBlend:
	var blend: GFCameraBlend = GFCameraBlend.new()
	blend.duration_seconds = duration_seconds
	blend.transition_type = transition_type
	blend.ease_type = ease_type
	return blend


# --- 私有/辅助方法 ---

func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _is_valid_transition_type(value: int) -> bool:
	return value in [
		Tween.TRANS_LINEAR,
		Tween.TRANS_SINE,
		Tween.TRANS_QUINT,
		Tween.TRANS_QUART,
		Tween.TRANS_QUAD,
		Tween.TRANS_EXPO,
		Tween.TRANS_ELASTIC,
		Tween.TRANS_CUBIC,
		Tween.TRANS_CIRC,
		Tween.TRANS_BOUNCE,
		Tween.TRANS_BACK,
		Tween.TRANS_SPRING,
	]


func _is_valid_ease_type(value: int) -> bool:
	return value in [
		Tween.EASE_IN,
		Tween.EASE_OUT,
		Tween.EASE_IN_OUT,
		Tween.EASE_OUT_IN,
	]
