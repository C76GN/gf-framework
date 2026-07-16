## GFTweenActionStep: 配置化 Tween 属性步骤。
##
## 描述一个目标对象属性如何缓动，不绑定具体节点或业务动作。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTweenActionStep
extends Resource


# --- 常量 ---

const _ACTION_TIME_POLICY = preload("res://addons/gf/extensions/action_queue/core/gf_action_time_policy.gd")


# --- 导出变量 ---

## 要缓动的属性路径。
## [br]
## @api public
@export var property_name: NodePath = ^"position"

## 目标值。
## [br]
## @api public
## [br]
## @schema target_value: Variant，可写入 property_name 的目标值；相对步骤中会与当前值相加。
@export var target_value: Variant = null

## 步骤持续时间。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var duration: float:
	get:
		return _duration
	set(value):
		_duration = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(value)

## 步骤延迟。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var delay: float:
	get:
		return _delay
	set(value):
		_delay = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(value)

## 是否相对当前值偏移。
## [br]
## @api public
@export var as_relative: bool = false

## 是否与前一个步骤并行。
## [br]
## @api public
@export var parallel: bool = false

## Tween 过渡类型。
## [br]
## @api public
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

## Tween 缓动类型。
## [br]
## @api public
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

## 可选步骤标记。非空时 GFConfiguredTweenAction 会在步骤结束后发出 marker_reached。
## [br]
## @api public
@export var marker_id: StringName = &""


# --- 私有变量 ---

var _duration: float = 0.2
var _delay: float = 0.0


# --- 公共方法 ---

## 追加到 Tween。
## [br]
## @api public
## [br]
## @param tween: 目标 Tween。
## [br]
## @param target: 目标对象。
## [br]
## @param duration_scale: 时长缩放。
## [br]
## @return 创建的 Tweener。
## [br]
## @schema return: Variant，成功时为 PropertyTweener；无效时为 null。
func append_to_tween(tween: Tween, target: Object, duration_scale: float = 1.0) -> Variant:
	if tween == null:
		return null
	var validation_error: String = get_validation_error(target)
	if not validation_error.is_empty():
		push_warning("[GFTweenActionStep] 跳过无效 Tween 步骤：%s" % validation_error)
		return null

	if parallel:
		var _parallel_result_88: Variant = tween.parallel()

	var effective_scale: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(duration_scale)
	var effective_duration: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
		duration * effective_scale
	)
	var effective_delay: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
		delay * effective_scale
	)
	var tweener: PropertyTweener = tween.tween_property(target, property_name, target_value, effective_duration)
	var _set_ease_result_94: Variant = tweener.set_trans(transition_type).set_ease(ease_type)
	if effective_delay > 0.0:
		var _set_delay_result_96: Variant = tweener.set_delay(effective_delay)
	if as_relative:
		var _as_relative_result_98: Variant = tweener.as_relative()
	return tweener


## 立即应用步骤目标值。
## [br]
## @api public
## [br]
## @param target: 目标对象。
func apply_instant(target: Object) -> void:
	var validation_error: String = get_validation_error(target)
	if not validation_error.is_empty():
		push_warning("[GFTweenActionStep] 跳过无效即时步骤：%s" % validation_error)
		return
	if as_relative:
		target.set_indexed(property_name, _resolve_relative_value(target))
	else:
		target.set_indexed(property_name, target_value)


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新步骤。
func duplicate_step() -> GFTweenActionStep:
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = property_name
	step.target_value = GFVariantData.duplicate_variant(target_value)
	step.duration = duration
	step.delay = delay
	step.as_relative = as_relative
	step.parallel = parallel
	step.transition_type = transition_type
	step.ease_type = ease_type
	step.marker_id = marker_id
	return step


## 检查目标对象是否能应用当前步骤。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @return 可应用时返回 true。
func can_apply_to(target: Object) -> bool:
	return get_validation_error(target).is_empty()


## 获取当前步骤对目标对象的校验错误。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @return 校验通过时返回空字符串。
func get_validation_error(target: Object) -> String:
	if not is_instance_valid(target):
		return "Target is invalid."
	if property_name.is_empty():
		return "Property name is empty."

	var root_property: String = _get_root_property_name()
	if root_property.is_empty():
		return "Property name is empty."
	if not _has_property(target, root_property):
		return "Property not found: %s" % root_property
	if as_relative and not _can_resolve_relative_value(target):
		return "Relative value type mismatch for property: %s" % String(property_name)
	return ""


## 捕获当前属性值。
## [br]
## @api public
## [br]
## @param target: 目标对象。
## [br]
## @return 属性值；步骤无效时返回 null。
## [br]
## @schema return: Variant，目标属性的深拷贝值；步骤无效时为 null。
func capture_initial_value(target: Object) -> Variant:
	if not get_validation_error(target).is_empty():
		return null
	return GFVariantData.duplicate_variant(target.get_indexed(property_name))


# --- 私有/辅助方法 ---

func _resolve_relative_value(target: Object) -> Variant:
	var current_value: Variant = target.get_indexed(property_name)
	if current_value is float or current_value is int:
		return GFVariantData.to_float(current_value) + GFVariantData.to_float(target_value)
	if current_value is Vector2 and target_value is Vector2:
		return _get_vector2_value(current_value) + _get_vector2_value(target_value)
	if current_value is Vector3 and target_value is Vector3:
		return _get_vector3_value(current_value) + _get_vector3_value(target_value)
	if current_value is Color and target_value is Color:
		return _get_color_value(current_value) + _get_color_value(target_value)
	return target_value


func _can_resolve_relative_value(target: Object) -> bool:
	var current_value: Variant = target.get_indexed(property_name)
	return (
		(current_value is float or current_value is int)
		and (target_value is float or target_value is int)
	) or (
		current_value is Vector2
		and target_value is Vector2
	) or (
		current_value is Vector3
		and target_value is Vector3
	) or (
		current_value is Color
		and target_value is Color
	)


func _get_root_property_name() -> String:
	var path_text: String = String(property_name)
	var separator_index: int = path_text.find(":")
	if separator_index >= 0:
		return path_text.substr(0, separator_index)
	return path_text


func _has_property(target: Object, property: String) -> bool:
	for property_info: Dictionary in target.get_property_list():
		if GFVariantData.get_option_string(property_info, "name") == property:
			return true
	return false


func _get_vector2_value(value: Variant) -> Vector2:
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	return Vector2.ZERO


func _get_vector3_value(value: Variant) -> Vector3:
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


func _get_color_value(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	return Color.WHITE
