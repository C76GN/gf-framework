@tool

## GFTweenNumericTimeline: 有界、冻结的纯数值 Tween 时间轴。
##
## 捕获与采样不接受目标对象、Resource、Callable 或业务上下文。调用方负责时钟和提交值。
## 直接 int/float 根属性共享运行时编译核心；任何不支持或越界的成员导致整组拒绝。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFTweenNumericTimeline
extends RefCounted


# --- 常量 ---

## 内部冻结编译器；其类型及可变字段不属于本 facade 的公共返回值。
## [br]
## @api private
const _PLAN_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_playback_plan.gd")

## 属性描述与搜索共用的有界记录校验入口。
## [br]
## @api private
const _RECORDS_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_property_records.gd")


# --- 私有变量 ---

## 捕获失败原因；成功后不再改变。
## [br]
## @api private
var _error: String = ""

## 私有冻结计划；不把其可变字段或曲线引用交给调用方。
## [br]
## @api private
var _plan: GFTweenPlaybackPlan = null

## 与初值一起冻结的硬边界；采样时再次检查，绝不替调用方钳制。
## [br]
## @api private
var _records: Array[Dictionary] = []


# --- 公共方法 ---

## 捕获独立的纯值时间轴；最多 128 步、32 次循环、4096 个展开步骤、120 秒。
## 单个步骤允许零时长，零总时长、并行同根/已知属性别名冲突和未知字段整组拒绝。
## 每个串行组开始时冻结 from，delay 不重新读取值，相对循环按冻结终点累计。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param definition: 闭合时间轴数据，不读取来源配置。
## [br]
## @schema definition: Dictionary，必需 steps: Array[Dictionary]；可选 loop_count: int=1、duration_scale: int/float=1.0、ping_pong: bool=false。步骤必需 property_name: NodePath、target_value: int/float；可选 duration: int/float=0.2、delay: int/float=0.0、as_relative/parallel: bool=false、transition_type: int=Tween.TRANS_CUBIC、ease_type: int=Tween.EASE_OUT、easing_curve_data: Dictionary={}（仅 positions: PackedVector2Array、tangents: PackedVector2Array、modes: PackedInt32Array、bake_resolution: int、value_range: Vector2）。不接受其他字段。
## [br]
## @param properties: 唯一直接数值属性的初值与硬包络；不是 UI slider 范围。
## [br]
## @schema properties: Array[Dictionary]，1 至 32 项，每项闭合 name: String（1..64 字符标识符）、type: int（TYPE_INT/TYPE_FLOAT）、initial: 同型有限 int/float、minimum/maximum: 有限 int/float（minimum < maximum，绝对值不超过 1000000，包含 initial）。
## [br]
## @return: 始终返回时间轴；get_error 非空表示没有部分可采样数据。
static func capture(definition: Dictionary, properties: Array[Dictionary]) -> GFTweenNumericTimeline:
	var timeline: GFTweenNumericTimeline = GFTweenNumericTimeline.new()
	var record_error: String = _RECORDS_SCRIPT.validate_numeric(properties)
	if not record_error.is_empty():
		return _reject(timeline, record_error)
	if not _only_keys(definition, ["steps", "loop_count", "duration_scale", "ping_pong"]):
		return _reject(timeline, "Unknown timeline fields.")
	var steps_value: Variant = definition.get("steps")
	var loops_value: Variant = definition.get("loop_count", 1)
	var scale_value: Variant = definition.get("duration_scale", 1.0)
	var ping_value: Variant = definition.get("ping_pong", false)
	if not (steps_value is Array) or not (loops_value is int) or not (ping_value is bool):
		return _reject(timeline, "Steps, loop count or ping-pong have invalid types.")
	var source_steps: Array = steps_value
	var loops: int = loops_value
	var scale: float = _number(scale_value)
	var ping_pong: bool = ping_value
	if source_steps.is_empty() or source_steps.size() > 128 or loops < 1 or loops > 32 or source_steps.size() * loops > 4096:
		return _reject(timeline, "Numeric timeline exceeds its step or loop budget.")
	if not is_finite(scale) or scale < 0.0:
		return _reject(timeline, "Duration scale must be finite and nonnegative.")
	var baseline: Dictionary = {}
	for record: Dictionary in properties:
		baseline[record["name"]] = record["initial"]
	var data: Array[Dictionary] = []
	var conservative_seconds: float = 0.0
	for value: Variant in source_steps:
		if not (value is Dictionary):
			return _reject(timeline, "Steps must be dictionaries.")
		var step: Dictionary = value
		if not _only_keys(step, ["property_name", "target_value", "duration", "delay", "as_relative", "parallel", "transition_type", "ease_type", "easing_curve_data"]):
			return _reject(timeline, "Unknown numeric step fields.")
		if not (step.get("property_name") is NodePath):
			return _reject(timeline, "Numeric property_name must be a NodePath.")
		var path: NodePath = step["property_name"]
		if not baseline.has(String(path)) or not (step.get("target_value") is int or step.get("target_value") is float):
			return _reject(timeline, "Numeric steps require a declared direct root property and numeric endpoint.")
		var copied: Dictionary = {
			"property_name": path, "target_value": step["target_value"],
			"duration": step.get("duration", 0.2), "delay": step.get("delay", 0.0),
			"as_relative": step.get("as_relative", false), "parallel": step.get("parallel", false),
			"transition_type": step.get("transition_type", Tween.TRANS_CUBIC), "ease_type": step.get("ease_type", Tween.EASE_OUT),
			"easing_curve_data": step.get("easing_curve_data", {}),
		}
		var curve_value: Variant = copied["easing_curve_data"]
		if not (curve_value is Dictionary):
			return _reject(timeline, "Curve data must be a pure dictionary.")
		var curve_data: Dictionary = curve_value
		if not _only_keys(curve_data, ["positions", "tangents", "modes", "bake_resolution", "value_range"]):
			return _reject(timeline, "Unknown curve fields.")
		conservative_seconds += (_number(copied["duration"]) + _number(copied["delay"])) * scale
		if not is_finite(conservative_seconds) or conservative_seconds * float(loops) * (2.0 if ping_pong else 1.0) > 120.0:
			return _reject(timeline, "Numeric timeline exceeds 120 seconds.")
		data.append(copied)
	var plan: GFTweenPlaybackPlan = _PLAN_SCRIPT.capture_data(data, baseline, loops, scale, ping_pong)
	if not plan.error.is_empty():
		return _reject(timeline, plan.error)
	for record: Dictionary in properties:
		var name_text: String = record["name"]
		var envelope: PackedFloat64Array = plan.get_numeric_envelope(name_text)
		# Unused declared properties retain their baseline and still participate in samples.
		if envelope.is_empty() and not plan.initial_values.has(name_text):
			continue
		if envelope.size() != 2 or envelope[0] < _number(record["minimum"]) or envelope[1] > _number(record["maximum"]):
			return _reject(timeline, "Interpolation exceeds the hard envelope for %s." % name_text)
	timeline._records = properties.duplicate(true)
	timeline._plan = plan
	return timeline


## 返回捕获拒绝原因；空字符串表示成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 拒绝说明。
func get_error() -> String:
	return _error


## 返回冻结的完整有限时间轴时长。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为正有限秒数，失败为零。
func get_duration_seconds() -> float:
	return _plan.duration_seconds if _plan != null else 0.0


## 返回全部声明属性的独立初值快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 初值；拒绝时间轴返回空字典。
## [br]
## @schema return: Dictionary，String 直接属性名映射到声明类型的 int/float。
func get_initial_values() -> Dictionary:
	var values: Dictionary = {}
	if _plan != null:
		for record: Dictionary in _records:
			values[record["name"]] = record["initial"]
	return values


## 采样独立数值快照。有限越界时间收窄到端点；非有限时间或任何越界输出返回空字典。
## 不执行标记、完成回调或持久化；整数遵循运行时 PropertyTweener 的转换语义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param time_seconds: 有限采样秒数。
## [br]
## @return: 全部声明属性值；失败没有部分输出。
## [br]
## @schema return: Dictionary，String 直接属性名映射到声明类型的有限 int/float，全部处于对应硬边界内；失败为空。
func sample(time_seconds: float) -> Dictionary:
	if _plan == null or not is_finite(time_seconds):
		return {}
	var sampled: Dictionary = _plan.sample(time_seconds)
	if sampled.is_empty():
		return {}
	var values: Dictionary = get_initial_values()
	for record: Dictionary in _records:
		var name_text: String = record["name"]
		if sampled.has(name_text):
			values[name_text] = sampled[name_text]
		var number: float = _number(values[name_text])
		if not is_finite(number) or number < _number(record["minimum"]) or number > _number(record["maximum"]):
			return {}
	return values


# --- 私有/辅助方法 ---

## 原子拒绝，不保留编译器或描述记录。
## [br]
## @api private
static func _reject(timeline: GFTweenNumericTimeline, message: String) -> GFTweenNumericTimeline:
	timeline._error = message
	timeline._plan = null
	timeline._records.clear()
	return timeline


## 检查闭合字典键名，拒绝非 String 键及未知键。
## [br]
## @api private
static func _only_keys(data: Dictionary, allowed: Array[String]) -> bool:
	for key: Variant in data:
		if not (key is String) or not allowed.has(key):
			return false
	return true


## 只将有限数值候选转换为浮点值；其他类型返回 NAN。
## [br]
## @api private
static func _number(value: Variant) -> float:
	if value is int:
		var integer: int = value
		return float(integer)
	if value is float:
		var floating: float = value
		return floating
	return NAN
