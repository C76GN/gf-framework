## GFTweenPlaybackPlan: 可定位 Tween 的冻结纯值计划。
##
## 采样不读写目标，不持有来源配置。调用方负责时钟、属性提交、标记和完成通知。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFTweenPlaybackPlan
extends RefCounted


# --- 常量 ---

const _EASING_CURVE_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_easing_curve.gd")
const _MAX_STEPS: int = 256
const _MAX_LOOPS: int = 256
const _MAX_EXPANDED_STEPS: int = 4096
const _MAX_CURVE_SAMPLES: int = 65536
const _MAX_CURVE_POINTS: int = 4096


# --- 公共变量 ---

## 整组拒绝原因；非空时计划不包含可采样数据。
## [br]
## @api framework_internal
var error: String = ""

## 完整有限时间轴时长；往返模式包括每个去返周期。
## [br]
## @api framework_internal
var duration_seconds: float = 0.0

## 需要提交的根属性路径；调用方按根值提交，不能与其他写入者共享该根属性。
## [br]
## @api framework_internal
## [br]
## @schema property_names: Array[NodePath]，不含组件子路径的唯一根属性。
var property_names: Array[NodePath] = []

## 播放开始前的根属性纯值快照；修改此对外副本不影响采样。
## [br]
## @api framework_internal
## [br]
## @schema initial_values: Dictionary，String 根属性名到有限 int/float、Vector2、Vector3 或 Color。
var initial_values: Dictionary = {}

## 正向播放的标记时间；回程没有标记，定位不负责发出标记。
## [br]
## @api framework_internal
## [br]
## @schema markers: Array[Dictionary]，每项为 time_seconds: float、index: int（来源步骤索引）、marker_id: StringName；按时间、步骤索引排序。
var markers: Array[Dictionary] = []


# --- 私有变量 ---

var _baseline: Dictionary = {}
var _spans: Array[_Span] = []
var _cycle_seconds: float = 0.0
var _total_seconds: float = 0.0
var _ping_pong: bool = false


# --- 框架内部方法 ---

## 冻结配置和根初值。只接受有限数值、Vector2/3、Color 及其单层组件。
## 每个串行组开始时冻结 from，相对终点为该 from 加偏移；delay 不重新读取外部状态。
## 并行组内同根写入、已知属性别名、零总时长和超出预算的计划整组拒绝。
## [br]
## @api framework_internal
## [br]
## @param config: 包含最多 256 步、1 至 256 次循环且步骤数乘循环数不超过 4096 的配置。
## [br]
## @param target: 只读取属性初值的有效对象；不调用其 setter。
## [br]
## @param ping_pong: true 时一次循环为去程加回程，后续周期从相同初值开始。
## [br]
## @return: 始终返回计划；error 非空表示整组拒绝。
static func capture(
	config: GFTweenActionConfig,
	target: Object,
	ping_pong: bool = false
) -> GFTweenPlaybackPlan:
	var plan: GFTweenPlaybackPlan = GFTweenPlaybackPlan.new()
	if config == null or not is_instance_valid(target):
		return _reject(plan, "Config and target must be valid.")
	if config.steps.is_empty() or config.steps.size() > _MAX_STEPS:
		return _reject(plan, "Playback requires 1 to 256 steps.")
	if config.loop_count < 1 or config.loop_count > _MAX_LOOPS:
		return _reject(plan, "Playback requires 1 to 256 finite loops.")
	if config.steps.size() * config.loop_count > _MAX_EXPANDED_STEPS:
		return _reject(plan, "Expanded playback exceeds 4096 steps.")
	if not is_finite(config.duration_scale) or config.duration_scale < 0.0:
		return _reject(plan, "Duration scale must be finite and nonnegative.")
	var sources: Array[_SourceStep] = []
	var group_roots: Dictionary = {}
	var group_seconds: float = 0.0
	var elapsed_seconds: float = 0.0
	var sample_budget: int = 0
	var point_budget: int = 0
	for index: int in range(config.steps.size()):
		var step: GFTweenActionStep = config.steps[index]
		if step == null:
			return _reject(plan, "Null steps are not supported.")
		if not step.parallel and index > 0:
			elapsed_seconds += group_seconds
			group_seconds = 0.0
			group_roots.clear()
		var source: _SourceStep = _capture_step(step, target, config.duration_scale, index)
		if not source._error.is_empty():
			return _reject(plan, source._error)
		if group_roots.has(source._root_name):
			return _reject(plan, "Parallel steps cannot write the same root property.")
		group_roots[source._root_name] = true
		if not plan._baseline.has(source._root_name):
			plan._baseline[source._root_name] = source._root_initial
			plan.property_names.append(NodePath(source._root_name))
		if _has_alias_conflict(plan._baseline):
			return _reject(plan, "Known property aliases cannot share a playback plan.")
		sample_budget += source._curve_samples
		point_budget += source._curve_points
		if sample_budget > _MAX_CURVE_SAMPLES or point_budget > _MAX_CURVE_POINTS:
			return _reject(plan, "Playback curve data exceeds its capture budget.")
		source._group_start = elapsed_seconds
		group_seconds = maxf(group_seconds, source._delay + source._duration)
		sources.append(source)
	plan._cycle_seconds = elapsed_seconds + group_seconds
	plan._total_seconds = plan._cycle_seconds * float(config.loop_count) * (2.0 if ping_pong else 1.0)
	if not is_finite(plan._total_seconds) or plan._total_seconds <= 0.0:
		return _reject(plan, "Playback duration must be finite and greater than zero.")
	plan._ping_pong = ping_pong
	var state: Dictionary = plan._baseline.duplicate()
	var compiled_loops: int = 1 if ping_pong else config.loop_count
	for loop_index: int in range(compiled_loops):
		for source: _SourceStep in sources:
			var span: _Span = _compile_span(source, state, float(loop_index) * plan._cycle_seconds)
			if not _is_finite_value(span._final_value) or not _is_finite_value(span._delta_value):
				return _reject(plan, "Relative endpoints or interpolation deltas overflow.")
			var root_final: Variant = _with_component(state[source._root_name], source._component, span._final_value)
			if not _is_finite_value(root_final):
				return _reject(plan, "Composed property endpoints overflow their root value.")
			plan._spans.append(span)
			state[source._root_name] = root_final
	for loop_index: int in range(config.loop_count):
		var loop_start: float = float(loop_index) * plan._cycle_seconds * (2.0 if ping_pong else 1.0)
		for source: _SourceStep in sources:
			if source._marker_id != &"":
				plan.markers.append({
					"time_seconds": loop_start + source._group_start + source._delay + source._duration,
					"index": source._index,
					"marker_id": source._marker_id,
				})
	plan.markers.sort_custom(_marker_precedes)
	plan.initial_values = plan._baseline.duplicate()
	plan.duration_seconds = plan._total_seconds
	return plan


## 采样冻结时间轴。越界有限时间钳制到端点；非有限时间或拒绝计划返回空字典。
## 不写目标、不执行标记或业务回调；返回值可由调用方独立修改。
## [br]
## @api framework_internal
## [br]
## @param time_seconds: 从本轮开始计算的有限秒数。
## [br]
## @return: 根属性值快照；失败返回空字典。
## [br]
## @schema return: Dictionary，String 根属性名到有限 int/float、Vector2、Vector3 或 Color。
func sample(time_seconds: float) -> Dictionary:
	if not error.is_empty() or _spans.is_empty() or not is_finite(time_seconds):
		return {}
	var sample_time: float = clampf(time_seconds, 0.0, _total_seconds)
	if _ping_pong:
		if sample_time == _total_seconds:
			return _baseline.duplicate()
		sample_time = fmod(sample_time, _cycle_seconds * 2.0)
		if sample_time > _cycle_seconds:
			sample_time = _cycle_seconds * 2.0 - sample_time
	var values: Dictionary = _baseline.duplicate()
	for span: _Span in _spans:
		if sample_time < span._group_start:
			break
		var value: Variant = _sample_span(span, sample_time)
		if not _is_finite_value(value):
			return {}
		var root_value: Variant = _with_component(values[span._root_name], span._component, value)
		if not _is_finite_value(root_value):
			return {}
		values[span._root_name] = root_value
	return values


# --- 私有/辅助方法 ---

static func _reject(plan: GFTweenPlaybackPlan, message: String) -> GFTweenPlaybackPlan:
	plan.error = message
	plan.duration_seconds = 0.0
	plan.property_names.clear()
	plan.initial_values.clear()
	plan.markers.clear()
	plan._baseline.clear()
	plan._spans.clear()
	return plan


static func _capture_step(step: GFTweenActionStep, target: Object, scale: float, index: int) -> _SourceStep:
	var source: _SourceStep = _SourceStep.new()
	var parts: PackedStringArray = String(step.property_name).split(":")
	if parts.size() < 1 or parts.size() > 2 or parts[0].is_empty() or parts[0].contains("/"):
		source._error = "Playback requires a root property with at most one component."
		return source
	source._root_name = parts[0]
	if parts.size() == 2:
		if parts[1].is_empty():
			source._error = "Property components cannot be empty."
			return source
		source._component = StringName(parts[1])
	var found: bool = false
	for property_info: Dictionary in target.get_property_list():
		if GFVariantData.get_option_string(property_info, "name") == source._root_name:
			found = true
			break
	if not found:
		source._error = "Playback root property does not exist."
		return source
	source._root_initial = target.get(source._root_name)
	var current: Variant = _component_value(source._root_initial, source._component)
	if not _is_finite_value(source._root_initial) or not _is_finite_value(current):
		source._error = "Playback initial values and components must be supported finite values."
		return source
	if not _is_finite_value(step.target_value) or not _compatible(current, step.target_value):
		source._error = "Playback endpoint types must match supported finite initial values."
		return source
	source._duration = step.duration * scale
	source._delay = step.delay * scale
	if not is_finite(source._duration) or not is_finite(source._delay) or source._duration < 0.0 or source._delay < 0.0:
		source._error = "Playback duration and delay must be finite and nonnegative."
		return source
	if step.transition_type < Tween.TRANS_LINEAR or step.transition_type > Tween.TRANS_SPRING:
		source._error = "Unknown Tween transition."
		return source
	if step.ease_type < Tween.EASE_IN or step.ease_type > Tween.EASE_OUT_IN:
		source._error = "Unknown Tween ease."
		return source
	var captured: Dictionary = _EASING_CURVE_SCRIPT.capture(step.easing_curve)
	source._error = GFVariantData.get_option_string(captured, "error")
	if not source._error.is_empty():
		return source
	var data: Dictionary = GFVariantData.get_option_dictionary(captured, "data")
	source._curve = _EASING_CURVE_SCRIPT.create_curve(data)
	source._curve_samples = _EASING_CURVE_SCRIPT.get_sample_count(data)
	source._curve_points = _EASING_CURVE_SCRIPT.get_point_count(data)
	# 原生 PropertyTweener 先把数值终点转换为属性初值的数值类型。
	source._target_value = _with_component(current, &"", step.target_value)
	source._relative = step.as_relative
	source._transition = step.transition_type
	source._easing_mode = step.ease_type
	source._marker_id = step.marker_id
	source._index = index
	return source


static func _compile_span(source: _SourceStep, state: Dictionary, loop_start: float) -> _Span:
	var span: _Span = _Span.new()
	span._root_name = source._root_name
	span._component = source._component
	span._initial_value = _component_value(state[source._root_name], source._component)
	span._final_value = _add_values(span._initial_value, source._target_value) if source._relative else source._target_value
	span._delta_value = _subtract_values(span._final_value, span._initial_value)
	span._group_start = loop_start + source._group_start
	span._delay = source._delay
	span._duration = source._duration
	span._transition = source._transition
	span._easing_mode = source._easing_mode
	span._curve = source._curve
	return span


static func _sample_span(span: _Span, time_seconds: float) -> Variant:
	var elapsed: float = time_seconds - span._group_start - span._delay
	if elapsed < 0.0:
		return span._initial_value
	if span._duration == 0.0 or elapsed >= span._duration:
		return span._final_value
	if span._curve != null:
		var sampled_progress: float = span._curve.sample_baked(elapsed / span._duration)
		return Tween.interpolate_value(span._initial_value, span._delta_value, sampled_progress, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	return Tween.interpolate_value(span._initial_value, span._delta_value, elapsed, span._duration, span._transition, span._easing_mode)


static func _marker_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_time: float = GFVariantData.get_option_float(left, "time_seconds")
	var right_time: float = GFVariantData.get_option_float(right, "time_seconds")
	if left_time == right_time:
		return GFVariantData.get_option_int(left, "index") < GFVariantData.get_option_int(right, "index")
	return left_time < right_time


static func _has_alias_conflict(values: Dictionary) -> bool:
	if values.has("position") and values.has("global_position"):
		return true
	if values.has("scale") and values.has("global_scale"):
		return true
	var rotation_names: Array[String] = ["rotation", "rotation_degrees", "global_rotation", "global_rotation_degrees", "quaternion"]
	var rotation_count: int = 0
	for rotation_name: String in rotation_names:
		if values.has(rotation_name):
			rotation_count += 1
	return rotation_count > 1


static func _compatible(left: Variant, right: Variant) -> bool:
	if (left is int or left is float) and (right is int or right is float):
		return true
	return typeof(left) == typeof(right)


static func _number(value: Variant) -> float:
	if value is float:
		var floating: float = value
		return floating
	if value is int:
		var integer: int = value
		return float(integer)
	return NAN


static func _is_finite_value(value: Variant) -> bool:
	if value is float or value is int:
		return is_finite(_number(value))
	if value is Vector2:
		var vector: Vector2 = value
		return vector.is_finite()
	if value is Vector3:
		var vector: Vector3 = value
		return vector.is_finite()
	if value is Color:
		var color: Color = value
		return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)
	return false


static func _component_value(value: Variant, component: StringName) -> Variant:
	if component == &"":
		return value
	if value is Vector2 and component in [&"x", &"y"]:
		var vector: Vector2 = value
		return vector[0 if component == &"x" else 1]
	if value is Vector3 and component in [&"x", &"y", &"z"]:
		var vector: Vector3 = value
		return vector[[&"x", &"y", &"z"].find(component)]
	if value is Color and component in [&"r", &"g", &"b", &"a"]:
		var color: Color = value
		return color[[&"r", &"g", &"b", &"a"].find(component)]
	return null


static func _with_component(value: Variant, component: StringName, next: Variant) -> Variant:
	if component == &"":
		if value is int:
			if next is int:
				return next
			var number: float = _number(next)
			if not is_finite(number) or number >= 9223372036854775808.0 or number < -9223372036854775808.0:
				return null
			return int(number)
		if value is float:
			return _number(next)
		return next
	if value is Vector2:
		var vector: Vector2 = value
		vector[0 if component == &"x" else 1] = _number(next)
		return vector
	if value is Vector3:
		var vector: Vector3 = value
		vector[[&"x", &"y", &"z"].find(component)] = _number(next)
		return vector
	if value is Color:
		var color: Color = value
		color[[&"r", &"g", &"b", &"a"].find(component)] = _number(next)
		return color
	return null


static func _add_values(left: Variant, right: Variant) -> Variant:
	if left is int and right is int:
		var left_integer: int = left
		var right_integer: int = right
		var sum: int = left_integer + right_integer
		if (left_integer > 0 and right_integer > 0 and sum < 0) or (left_integer < 0 and right_integer < 0 and sum >= 0):
			return null
		return sum
	if (left is int or left is float) and (right is int or right is float):
		return _number(left) + _number(right)
	if left is Vector2 and right is Vector2:
		var left_vector: Vector2 = left
		var right_vector: Vector2 = right
		return left_vector + right_vector
	if left is Vector3 and right is Vector3:
		var left_vector: Vector3 = left
		var right_vector: Vector3 = right
		return left_vector + right_vector
	if left is Color and right is Color:
		var left_color: Color = left
		var right_color: Color = right
		return left_color + right_color
	return null


static func _subtract_values(left: Variant, right: Variant) -> Variant:
	if left is int and right is int:
		var left_integer: int = left
		var right_integer: int = right
		var difference: int = left_integer - right_integer
		if (left_integer >= 0 and right_integer < 0 and difference < 0) or (left_integer < 0 and right_integer > 0 and difference >= 0):
			return null
		return difference
	if (left is int or left is float) and (right is int or right is float):
		return _number(left) - _number(right)
	if left is Vector2 and right is Vector2:
		var left_vector: Vector2 = left
		var right_vector: Vector2 = right
		return left_vector - right_vector
	if left is Vector3 and right is Vector3:
		var left_vector: Vector3 = left
		var right_vector: Vector3 = right
		return left_vector - right_vector
	if left is Color and right is Color:
		var left_color: Color = left
		var right_color: Color = right
		return left_color - right_color
	return null


# --- 内部类 ---

class _SourceStep extends RefCounted:
	var _error: String = ""
	var _root_name: String = ""
	var _component: StringName = &""
	var _root_initial: Variant
	var _target_value: Variant
	var _relative: bool = false
	var _group_start: float = 0.0
	var _delay: float = 0.0
	var _duration: float = 0.0
	var _transition: Tween.TransitionType = Tween.TRANS_LINEAR
	var _easing_mode: Tween.EaseType = Tween.EASE_IN
	var _curve: Curve = null
	var _curve_samples: int = 0
	var _curve_points: int = 0
	var _marker_id: StringName = &""
	var _index: int = 0


class _Span extends RefCounted:
	var _root_name: String = ""
	var _component: StringName = &""
	var _initial_value: Variant
	var _final_value: Variant
	var _delta_value: Variant
	var _group_start: float = 0.0
	var _delay: float = 0.0
	var _duration: float = 0.0
	var _transition: Tween.TransitionType = Tween.TRANS_LINEAR
	var _easing_mode: Tween.EaseType = Tween.EASE_IN
	var _curve: Curve = null
