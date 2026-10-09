@tool

# 有界读取来源的纯值签名，只用于显示已捕获预览是否过期，不执行资源方法。
extends RefCounted


# --- 常量 ---

## 仅接受此精确脚本的配置，避免通过自定义脚本属性读取执行未知逻辑。
## [br]
## @api private
const _CONFIG_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_config.gd")

## 步骤快照的精确脚本边界；其他 Resource 只记录拒绝标记。
## [br]
## @api private
const _STEP_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd")

## 按此固定顺序捕获影响播放策略的根字段，以数组值比较判断来源是否变化。
## [br]
## @api private
const _CONFIG_FIELDS: Array[StringName] = [
	&"duration_scale", &"loop_count", &"enable_playback_control", &"ping_pong",
	&"ignore_time_scale", &"process_mode", &"pause_mode",
	&"restore_initial_values_on_cancel", &"restore_initial_values_on_finish",
]

## 步骤纯值签名的字段顺序；曲线数据另行受点数预算约束地读取。
## [br]
## @api private
const _STEP_FIELDS: Array[StringName] = [
	&"property_name", &"target_value", &"duration", &"delay", &"as_relative",
	&"parallel", &"transition_type", &"ease_type", &"marker_id",
]


# --- 框架内部方法 ---

## 返回至多 128 步、4096 曲线点的纯值签名；不烘焙曲线。
## [br]
## @api framework_internal
## [br]
## @param config: 精确原生配置，null 或其他脚本产生拒绝签名。
## [br]
## @return: 可按值比较的来源签名；不含资源引用。
## [br]
## @schema return: Array，依次保存根字段纯值与步骤字段/原生曲线坐标、切线、模式的嵌套 Array；拒绝项以 String 标记表示。
static func capture(config: Resource) -> Array:
	var result: Array = []
	if config == null or config.get_script() != _CONFIG_SCRIPT:
		return ["unsupported_config"]
	for field: StringName in _CONFIG_FIELDS:
		result.append(config.get(field))
	var value: Variant = config.get(&"steps")
	if not value is Array:
		return ["unsupported_steps"]
	var steps: Array = value
	if steps.size() > 128:
		return ["step_budget", steps.size()]
	var point_budget: int = 4096
	for step_value: Variant in steps:
		if not step_value is Resource:
			result.append("missing_step")
			continue
		var step: Resource = step_value
		if step.get_script() != _STEP_SCRIPT:
			result.append("unsupported_step")
			continue
		var fields: Array = []
		for field: StringName in _STEP_FIELDS:
			var field_value: Variant = step.get(field)
			if typeof(field_value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_NODE_PATH, TYPE_STRING_NAME]:
				fields.append(field_value)
			else:
				fields.append("unsupported_value")
		var curve_value: Variant = step.get(&"easing_curve")
		if curve_value is Curve:
			var curve: Curve = curve_value
			if curve.get_script() != null or curve.get_point_count() > point_budget:
				fields.append("unsupported_curve")
			else:
				point_budget -= curve.get_point_count()
				fields.append([curve.min_domain, curve.max_domain, curve.min_value, curve.max_value, curve.bake_resolution])
				for index: int in range(curve.get_point_count()):
					fields.append([curve.get_point_position(index), curve.get_point_left_tangent(index), curve.get_point_right_tangent(index), curve.get_point_left_mode(index), curve.get_point_right_mode(index)])
		else:
			fields.append(null)
		result.append(fields)
	return result
