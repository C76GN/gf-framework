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
const _EASING_CURVE_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_easing_curve.gd")


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

## 可选原生缓动曲线；设置后覆盖 transition_type/ease_type，按线性时间进度进行 sample_baked。
## 横轴域为 0..1，首尾点必须为 (0,0)/(1,1)，X 严格递增；支持回弹和超调。
## 只接受无脚本、2..256 点、2..1000 烘焙采样的 Curve；坐标、切线与编辑范围须有限，
## 编辑范围须包含 0..1 及全部点值，烘焙输出绝对值不超过 16。创建 Tweener 时捕获独立数据。
## [br]
## @api public
## [br]
## @since unreleased
@export var easing_curve: Curve = null

## 可选步骤标记。非空时 GFConfiguredTweenAction 会在步骤结束后发出 marker_reached；
## 标记通知不会改变相邻步骤声明的并行拓扑。
## [br]
## @api public
## [br]
## @since 11.0.0
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
	var validation_error: String = get_property_validation_error(target)
	if not validation_error.is_empty():
		push_warning("[GFTweenActionStep] 跳过无效 Tween 步骤：%s" % validation_error)
		return null
	var captured_curve: Dictionary = _EASING_CURVE_SCRIPT.capture(easing_curve)
	var curve_error: String = GFVariantData.get_option_string(captured_curve, "error")
	if not curve_error.is_empty():
		push_warning("[GFTweenActionStep] 跳过无效 Tween 步骤：Invalid easing_curve: %s" % curve_error)
		return null
	var curve_data: Dictionary = GFVariantData.get_option_dictionary(captured_curve, "data")

	var effective_scale: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(duration_scale)
	var effective_duration: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
		duration * effective_scale
	)
	var effective_delay: float = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
		delay * effective_scale
	)
	return append_property_tweener(
		tween, target, property_name, target_value, effective_duration, effective_delay,
		as_relative, parallel, transition_type, ease_type, curve_data
	)


## 立即应用步骤目标值；仅校验属性，不采样或校验 easing_curve。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target: 目标对象。
func apply_instant(target: Object) -> void:
	var validation_error: String = get_property_validation_error(target)
	if not validation_error.is_empty():
		push_warning("[GFTweenActionStep] 跳过无效即时步骤：%s" % validation_error)
		return
	if as_relative:
		target.set_indexed(property_name, _resolve_relative_value(target))
	else:
		target.set_indexed(property_name, target_value)


## 创建深拷贝；曲线只复制原生数据，不携带脚本或 metadata。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 新步骤；easing_curve 无效时发出警告并返回 null。
func duplicate_step() -> GFTweenActionStep:
	var copied_curve: Curve = _EASING_CURVE_SCRIPT.duplicate_curve(easing_curve)
	if easing_curve != null and copied_curve == null:
		push_warning("[GFTweenActionStep] 无法复制无效 easing_curve；请先校验步骤。")
		return null
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = property_name
	step.target_value = GFVariantData.duplicate_variant(target_value)
	step.duration = duration
	step.delay = delay
	step.as_relative = as_relative
	step.parallel = parallel
	step.transition_type = transition_type
	step.ease_type = ease_type
	step.easing_curve = copied_curve
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


## 获取当前步骤的属性与 easing_curve 校验错误。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target: 目标对象。
## [br]
## @return 校验通过时返回空字符串。
func get_validation_error(target: Object) -> String:
	var property_error: String = get_property_validation_error(target)
	if not property_error.is_empty():
		return property_error
	var captured_curve: Dictionary = _EASING_CURVE_SCRIPT.capture(easing_curve)
	var curve_error: String = GFVariantData.get_option_string(captured_curve, "error")
	if not curve_error.is_empty():
		return "Invalid easing_curve: %s" % curve_error
	return ""


## 捕获当前属性值；仅校验属性，不采样或校验 easing_curve。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target: 目标对象。
## [br]
## @return 属性值；步骤无效时返回 null。
## [br]
## @schema return: Variant，目标属性的深拷贝值；步骤无效时为 null。
func capture_initial_value(target: Object) -> Variant:
	if not get_property_validation_error(target).is_empty():
		return null
	return GFVariantData.duplicate_variant(target.get_indexed(property_name))


# --- 框架内部方法 ---

## 校验可读写属性和值，供即时终点应用和初值恢复使用，不要求插值曲线有效。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param target: 要读取或写入的目标对象。
## [br]
## @return: 属性校验通过时为空字符串，否则为错误原因。
func get_property_validation_error(target: Object) -> String:
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
	if not as_relative and not _are_tween_values_compatible(
		target.get_indexed(property_name), target_value
	):
		return "Tween value type mismatch for property: %s" % String(property_name)
	return ""


## 以调用方已校验的属性数据构建原生 Tweener，不读取配置资源或添加标记回调。
## [br]
## @api framework_internal
## [br]
## @param tween: 接收步骤的有效 Tween。
## [br]
## @param target: 属性目标；属性存在性与值兼容性由调用方预先校验。
## [br]
## @param p_property_name: 要缓动的属性路径。
## [br]
## @param p_target_value: 已校验的目标值或相对偏移。
## [br]
## @param effective_duration: 已完成时长缩放的有限非负持续时间。
## [br]
## @param effective_delay: 已完成时长缩放的有限非负延迟。
## [br]
## @param p_as_relative: 是否将目标值解释为相对偏移。
## [br]
## @param p_parallel: 是否与前一个步骤并行。
## [br]
## @param p_transition_type: 已校验的过渡类型。
## [br]
## @param p_ease_type: 已校验的缓动类型。
## [br]
## @param easing_curve_data: 已捕获的曲线纯值数据；空字典沿用预设缓动。
## [br]
## @return: 新建的属性 Tweener；Tween 或目标失效、创建失败时为 null。
## [br]
## @schema p_target_value: Variant，调用方已确认与目标属性兼容的值。
## [br]
## @schema easing_curve_data: Dictionary，空或包含 positions: PackedVector2Array、tangents: PackedVector2Array、modes: PackedInt32Array、bake_resolution: int、value_range: Vector2，由内部曲线捕获器校验生成。
static func append_property_tweener(
	tween: Tween,
	target: Object,
	p_property_name: NodePath,
	p_target_value: Variant,
	effective_duration: float,
	effective_delay: float,
	p_as_relative: bool,
	p_parallel: bool,
	p_transition_type: Tween.TransitionType,
	p_ease_type: Tween.EaseType,
	easing_curve_data: Dictionary = {}
) -> PropertyTweener:
	if not is_instance_valid(tween) or not is_instance_valid(target):
		return null
	var interpolator: Callable = _EASING_CURVE_SCRIPT.create_interpolator(easing_curve_data)
	if not easing_curve_data.is_empty() and not interpolator.is_valid():
		return null
	if p_parallel:
		var _parallel_result: Tween = tween.parallel()
	var tweener: PropertyTweener = tween.tween_property(
		target, p_property_name, p_target_value, effective_duration
	)
	if tweener == null:
		return null
	if interpolator.is_valid():
		var _curve_result: PropertyTweener = tweener.set_trans(Tween.TRANS_LINEAR).set_custom_interpolator(interpolator)
	else:
		var _ease_result: PropertyTweener = tweener.set_trans(p_transition_type).set_ease(p_ease_type)
	if effective_delay > 0.0:
		var _delay_result: PropertyTweener = tweener.set_delay(effective_delay)
	if p_as_relative:
		var _relative_result: PropertyTweener = tweener.as_relative()
	return tweener


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


func _are_tween_values_compatible(current_value: Variant, next_value: Variant) -> bool:
	if (
		(current_value is float or current_value is int)
		and (next_value is float or next_value is int)
	):
		return true
	return typeof(current_value) == typeof(next_value)


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
