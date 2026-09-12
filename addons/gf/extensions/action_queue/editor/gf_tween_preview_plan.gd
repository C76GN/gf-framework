@tool

## GFTweenPreviewPlan: 编辑器预览使用的受限 Tween 数据快照。
##
## 只读取精确基类配置和步骤的字段，不调用来源资源的实例方法。
## 标记通知与运行时时钟选项不进入计划；调用方负责独立预览目标和播放生命周期。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
class_name GFTweenPreviewPlan
extends RefCounted


# --- 常量 ---

const _CONFIG_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd")
const _STEP_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd")
const _MAX_STEPS: int = 128
const _MAX_LOOPS: int = 32
const _MAX_SECONDS: float = 120.0
const _MAX_VALUE_MAGNITUDE: float = 1000000.0


# --- 公共变量 ---

## 整组拒绝原因；空字符串表示计划可执行，拒绝时 steps 为空。
## [br]
## @api framework_internal
var error: String = ""

## 已通过校验并与来源资源脱离的属性步骤。
## [br]
## @api framework_internal
## [br]
## @schema steps: Array[Dictionary]，每项包含 property_name: NodePath、target_value: 有限数值或 Vector2/Vector3/Color、duration: float、delay: float、as_relative: bool、parallel: bool、transition_type: int、ease_type: int；duration 与 delay 已完成缩放。
var steps: Array[Dictionary] = []

## 有限播放次数，成功计划取值为 1 至 32。
## [br]
## @api framework_internal
var loop_count: int = 1

## 正常完成时是否恢复预览基线；停止和复位由预览控制器单独处理。
## [br]
## @api framework_internal
var restore_on_finish: bool = false

## 实际时间轴总时长；每个并行组取最大延迟加时长，串行组求和后乘有限循环次数。
## 全零时长计划为 0，并沿用瞬时步骤只应用一轮的预览语义。
## [br]
## @api framework_internal
## [br]
## @since unreleased
var duration_seconds: float = 0.0


# --- 框架内部方法 ---

## 捕获完整预览计划；任一步骤不支持时整组拒绝，不改写来源资源。
## [br]
## @api framework_internal
## [br]
## @param config: 精确使用 GFTweenActionConfig 脚本的资源；子类与其他脚本均拒绝。
## [br]
## @param target_kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @return: 始终返回计划，通过 error 判断成功；失败计划没有部分可执行步骤。
static func capture(config: Resource, target_kind: int) -> GFTweenPreviewPlan:
	var plan: GFTweenPreviewPlan = GFTweenPreviewPlan.new()
	var properties: Dictionary = get_properties(target_kind)
	if properties.is_empty():
		return _reject(plan, "未知预览目标类型。")
	if not _has_exact_script(config, _CONFIG_SCRIPT):
		return _reject(plan, "只支持使用 GFTweenActionConfig 原始脚本的配置资源。")

	var steps_value: Variant = config.get(&"steps")
	if not (steps_value is Array):
		return _reject(plan, "配置 steps 必须是数组。")
	var source_steps: Array = steps_value
	if source_steps.is_empty() or source_steps.size() > _MAX_STEPS:
		return _reject(plan, "预览需要 1 至 %d 个步骤。" % _MAX_STEPS)

	var loop_value: Variant = config.get(&"loop_count")
	if not (loop_value is int):
		return _reject(plan, "loop_count 必须是整数。")
	var loops: int = loop_value
	if loops < 1 or loops > _MAX_LOOPS:
		return _reject(plan, "预览只支持 1 至 %d 次有限循环。" % _MAX_LOOPS)
	plan.loop_count = loops

	var scale_value: Variant = config.get(&"duration_scale")
	var duration_scale: float = _read_number(scale_value)
	if not is_finite(duration_scale) or duration_scale < 0.0:
		return _reject(plan, "duration_scale 必须是有限非负数。")
	var restore_value: Variant = config.get(&"restore_initial_values_on_finish")
	if not (restore_value is bool):
		return _reject(plan, "restore_initial_values_on_finish 必须是布尔值。")
	var restore_finish: bool = restore_value
	plan.restore_on_finish = restore_finish

	var total_seconds: float = 0.0
	var completed_groups_seconds: float = 0.0
	var current_group_seconds: float = 0.0
	for index: int in range(source_steps.size()):
		var step_value: Variant = source_steps[index]
		if not (step_value is Resource):
			return _reject(plan, "步骤 %d 必须是非空 GFTweenActionStep 资源。" % index)
		var source_step: Resource = step_value
		var step_error: String = _capture_step(plan, source_step, properties, duration_scale)
		if not step_error.is_empty():
			return _reject(plan, "步骤 %d：%s" % [index, step_error])
		var captured_step: Dictionary = plan.steps[plan.steps.size() - 1]
		var duration_value: Variant = captured_step["duration"]
		var delay_value: Variant = captured_step["delay"]
		var effective_duration: float = _read_number(duration_value)
		var effective_delay: float = _read_number(delay_value)
		total_seconds += effective_duration + effective_delay
		if not is_finite(total_seconds) or total_seconds * float(loops) > _MAX_SECONDS:
			return _reject(plan, "全部步骤持续时间与延迟的保守累计值乘循环次数不能超过 120 秒。")
		var parallel_value: Variant = captured_step["parallel"]
		var parallel: bool = false
		if parallel_value is bool:
			parallel = parallel_value
		if not parallel and index > 0:
			completed_groups_seconds += current_group_seconds
			current_group_seconds = 0.0
		current_group_seconds = maxf(current_group_seconds, effective_duration + effective_delay)
	plan.duration_seconds = (completed_groups_seconds + current_group_seconds) * float(loops)
	return plan


## 返回预览目标的完整初值；每次返回独立字典，不含相互覆盖的角度别名。
## [br]
## @api framework_internal
## [br]
## @param kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @return: 目标初值字典；未知类型返回空字典。
## [br]
## @schema return: Dictionary，String 属性名映射到 float、Vector2、Vector3 或 Color 初值；2D 为 position/rotation/scale/modulate/self_modulate，UI 另有 size/pivot_offset，3D 为 position/rotation/scale。
static func get_initial_values(kind: int) -> Dictionary:
	if kind == 2:
		return {
			"position": Vector3.ZERO,
			"rotation": Vector3.ZERO,
			"scale": Vector3.ONE,
		}
	if kind != 0 and kind != 1:
		return {}
	var values: Dictionary = {
		"position": Vector2.ZERO,
		"rotation": 0.0,
		"scale": Vector2.ONE,
		"modulate": Color.WHITE,
		"self_modulate": Color.WHITE,
	}
	if kind == 1:
		values["size"] = Vector2(64.0, 64.0)
		values["pivot_offset"] = Vector2(32.0, 32.0)
	return values


## 返回允许预览的顶层属性与其基线值，用于约束目标类型及合法分量路径。
## [br]
## @api framework_internal
## [br]
## @param kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @return: 属性白名单；未知类型返回空字典。
## [br]
## @schema return: Dictionary，字段同 get_initial_values()，另外包含 rotation_degrees 的 float 或 Vector3 基线值。
static func get_properties(kind: int) -> Dictionary:
	var properties: Dictionary = get_initial_values(kind)
	if properties.is_empty():
		return properties
	if kind == 2:
		properties["rotation_degrees"] = Vector3.ZERO
	else:
		properties["rotation_degrees"] = 0.0
	return properties


## 校验完整属性初值，复用计划的类型、有限值与幅度约束。
## [br]
## @api framework_internal
## [br]
## @param property_name: get_initial_values() 中的完整属性名；不接受分量或角度别名。
## [br]
## @param value: 候选初值。
## [br]
## @param kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @return: 合法时为空字符串，否则为拒绝原因。
## [br]
## @schema value: Variant，须与基线同型或为兼容的 int/float，所有数值分量有限且绝对值不超过 1000000。
static func validate_initial_value(property_name: StringName, value: Variant, kind: int) -> String:
	var initial_values: Dictionary = get_initial_values(kind)
	var property_text: String = String(property_name)
	if not initial_values.has(property_text):
		return "不支持该预览初值属性。"
	return _validate_value(value, initial_values[property_text])


# --- 私有/辅助方法 ---

static func _reject(plan: GFTweenPreviewPlan, message: String) -> GFTweenPreviewPlan:
	plan.steps.clear()
	plan.error = message
	return plan


static func _has_exact_script(resource: Resource, expected_script: Script) -> bool:
	if not is_instance_valid(resource):
		return false
	var script_value: Variant = resource.get_script()
	if not (script_value is Script):
		return false
	var resource_script: Script = script_value
	return resource_script == expected_script


static func _capture_step(
	plan: GFTweenPreviewPlan,
	source: Resource,
	properties: Dictionary,
	duration_scale: float
) -> String:
	if not _has_exact_script(source, _STEP_SCRIPT):
		return "只支持使用 GFTweenActionStep 原始脚本的步骤资源。"
	var path_value: Variant = source.get(&"property_name")
	if not (path_value is NodePath):
		return "property_name 必须是 NodePath。"
	var property_path: NodePath = path_value
	var baseline: Variant = _get_property_baseline(property_path, properties)
	if baseline == null:
		return "不支持属性路径 %s；仅允许白名单属性及其单层数值分量。" % String(property_path)
	var target_value: Variant = source.get(&"target_value")
	var value_error: String = _validate_value(target_value, baseline)
	if not value_error.is_empty():
		return value_error

	var duration: float = _read_number(source.get(&"duration"))
	var delay: float = _read_number(source.get(&"delay"))
	if not is_finite(duration) or duration < 0.0 or not is_finite(delay) or delay < 0.0:
		return "duration 和 delay 必须是有限非负数。"
	var effective_duration: float = duration * duration_scale
	var effective_delay: float = delay * duration_scale
	if not is_finite(effective_duration) or not is_finite(effective_delay):
		return "缩放后的 duration 和 delay 必须是有限数。"

	var relative_value: Variant = source.get(&"as_relative")
	var parallel_value: Variant = source.get(&"parallel")
	if not (relative_value is bool) or not (parallel_value is bool):
		return "as_relative 和 parallel 必须是布尔值。"
	var relative: bool = relative_value
	var parallel: bool = parallel_value
	var transition_value: Variant = source.get(&"transition_type")
	var ease_value: Variant = source.get(&"ease_type")
	if not (transition_value is int) or not (ease_value is int):
		return "transition_type 和 ease_type 必须是合法枚举整数。"
	var transition: int = transition_value
	var ease_kind: int = ease_value
	if transition < Tween.TRANS_LINEAR or transition > Tween.TRANS_SPRING:
		return "transition_type 超出合法枚举范围。"
	if ease_kind < Tween.EASE_IN or ease_kind > Tween.EASE_OUT_IN:
		return "ease_type 超出合法枚举范围。"

	plan.steps.append({
		"property_name": property_path,
		"target_value": target_value,
		"duration": effective_duration,
		"delay": effective_delay,
		"as_relative": relative,
		"parallel": parallel,
		"transition_type": transition,
		"ease_type": ease_kind,
	})
	return ""


static func _get_property_baseline(property_path: NodePath, properties: Dictionary) -> Variant:
	var parts: PackedStringArray = String(property_path).split(":")
	if parts.is_empty() or parts.size() > 2 or not properties.has(parts[0]):
		return null
	var baseline: Variant = properties[parts[0]]
	if parts.size() == 1:
		return baseline
	var component: String = parts[1]
	if baseline is Vector2 and (component == "x" or component == "y"):
		return 0.0
	if baseline is Vector3 and (component == "x" or component == "y" or component == "z"):
		return 0.0
	if baseline is Color and (component == "r" or component == "g" or component == "b" or component == "a"):
		return 0.0
	return null


static func _validate_value(value: Variant, baseline: Variant) -> String:
	if baseline is float:
		if not (value is int) and not (value is float):
			return "目标值必须是与属性兼容的数值。"
	elif typeof(value) != typeof(baseline):
		return "目标值类型必须与预览属性一致。"
	if not _is_bounded_value(value):
		return "目标值必须有限，且各数值分量的绝对值不超过 1000000。"
	return ""


static func _read_number(value: Variant) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return NAN


static func _is_bounded_number(value: float) -> bool:
	return is_finite(value) and absf(value) <= _MAX_VALUE_MAGNITUDE


static func _is_bounded_value(value: Variant) -> bool:
	if value is float or value is int:
		return _is_bounded_number(_read_number(value))
	if value is Vector2:
		var vector: Vector2 = value
		return _is_bounded_number(vector.x) and _is_bounded_number(vector.y)
	if value is Vector3:
		var vector: Vector3 = value
		return _is_bounded_number(vector.x) and _is_bounded_number(vector.y) and _is_bounded_number(vector.z)
	if value is Color:
		var color: Color = value
		return (
			_is_bounded_number(color.r) and _is_bounded_number(color.g)
			and _is_bounded_number(color.b) and _is_bounded_number(color.a)
		)
	return false
