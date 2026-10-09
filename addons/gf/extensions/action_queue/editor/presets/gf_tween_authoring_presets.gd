@tool

# Tween 创作预设的冻结版本及步骤复制规则；运行时配置不依赖本脚本。
extends RefCounted


# --- 常量 ---

## 精确原生步骤的脚本身份；拒绝自定义子脚本的复制与来源记录读取。
## [br]
## @api private
const _STEP_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_action_step.gd")

## 曲线复制入口，创建独立原生曲线并拒绝不支持的曲线来源。
## [br]
## @api private
const _CURVE_SCRIPT = preload("res://addons/gf/extensions/action_queue/tween/gf_tween_easing_curve.gd")

## 步骤资源上保存预设来源的元数据键；普通自定义元数据不随步骤复制。
## [br]
## @api private
const _META_KEY: StringName = &"_gf_tween_preset"

## 当前可识别的冻结预设版本，未知版本关闭来源恢复能力。
## [br]
## @api private
const _VERSION: int = 1

## 预设基线、覆盖比较和恢复共同管理的字段；自定义 Curve 不属于自动恢复范围。
## [br]
## @api private
const _FIELDS: Array[StringName] = [
	&"property_name", &"target_value", &"duration", &"delay", &"as_relative",
	&"parallel", &"transition_type", &"ease_type", &"marker_id",
]

## 来源记录允许的预设 ID；具体样机适用性仍由创建步骤时检查。
## [br]
## @api private
const _IDS: Array[String] = ["move_by", "scale_to", "rotate_by", "opacity_to"]


# --- 框架内部方法 ---

## 返回适用于选定样机的冻结预设记录。
## [br]
## @api framework_internal
## [br]
## @param kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @return: 可选预设列表。
## [br]
## @schema return: Array[Dictionary]，每项包含 String id 与 String label。
static func get_records(kind: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = [
		{"id": "move_by", "label": "移动偏移"},
		{"id": "scale_to", "label": "缩放到目标值"},
		{"id": "rotate_by", "label": "旋转偏移"},
	]
	if kind != 2:
		records.append({"id": "opacity_to", "label": "透明度到目标值"})
	return records


## 创建独立步骤。预设只管理步骤字段，不修改配置循环等根属性。
## [br]
## @api framework_internal
## [br]
## @param preset_id: get_records 返回的预设 ID。
## [br]
## @param kind: 0 为 2D，1 为 UI，2 为 3D。
## [br]
## @param version: 冻结版本；当前只支持 1。
## [br]
## @return: 独立步骤数组；参数不支持时为空。
static func create_steps(preset_id: String, kind: int, version: int = 1) -> Array[GFTweenActionStep]:
	var result: Array[GFTweenActionStep] = []
	if version != _VERSION or not _IDS.has(preset_id) or kind < 0 or kind > 2:
		return result
	if preset_id == "opacity_to" and kind == 2:
		return result
	var step: GFTweenActionStep = GFTweenActionStep.new()
	match preset_id:
		"move_by":
			step.property_name = ^"position"
			step.target_value = Vector2(80.0, 0.0)
			if kind == 2:
				step.target_value = Vector3(1.0, 0.0, 0.0)
			step.as_relative = true
		"scale_to":
			step.property_name = ^"scale"
			step.target_value = Vector2.ONE * 1.2
			if kind == 2:
				step.target_value = Vector3.ONE * 1.2
		"rotate_by":
			step.property_name = ^"rotation"
			step.target_value = PI / 4.0
			if kind == 2:
				step.target_value = Vector3(0.0, PI / 4.0, 0.0)
			step.as_relative = true
		"opacity_to":
			step.property_name = ^"modulate:a"
			step.target_value = 0.0
	var baseline: Dictionary = {}
	for field: StringName in _FIELDS:
		baseline[String(field)] = step.get(field)
	step.set_meta(_META_KEY, {
		"schema_version": 1, "preset_id": preset_id, "preset_version": version,
		"managed_fields": _FIELDS.duplicate(), "baseline": baseline,
	})
	result.append(step)
	return result


## 复制原生步骤和曲线；只额外保留经过验证的预设来源纯数据。
## [br]
## @api framework_internal
## [br]
## @param source: 精确原生步骤资源。
## [br]
## @return: 独立步骤与曲线；步骤类型或曲线无效时为 null。
static func copy_step(source: GFTweenActionStep) -> GFTweenActionStep:
	if source == null or source.get_script() != _STEP_SCRIPT:
		return null
	var curve: Curve = _CURVE_SCRIPT.duplicate_curve(source.easing_curve)
	if source.easing_curve != null and curve == null:
		return null
	var copied: GFTweenActionStep = GFTweenActionStep.new()
	for field: StringName in _FIELDS:
		copied.set(field, source.get(field))
	copied.easing_curve = curve
	copied.resource_name = source.resource_name
	copied.resource_local_to_scene = source.resource_local_to_scene
	var provenance: Dictionary = get_provenance(source)
	if not provenance.is_empty():
		copied.set_meta(_META_KEY, provenance)
	return copied


## 读取受限来源记录，未知或畸形记录仅关闭恢复能力。
## [br]
## @api framework_internal
## [br]
## @param step: 待读取来源的原生步骤。
## [br]
## @return: 通过验证的独立来源记录；未知或无效时为空。
## [br]
## @schema return: Dictionary，空或 schema_version/preset_version: int、preset_id: String、managed_fields: Array[StringName]、baseline: String 字段名到受管字段纯值的 Dictionary。
static func get_provenance(step: GFTweenActionStep) -> Dictionary:
	if step == null or step.get_script() != _STEP_SCRIPT:
		return {}
	var value: Variant = step.get_meta(_META_KEY, {})
	if not value is Dictionary:
		return {}
	var record: Dictionary = value
	if record.size() != 5:
		return {}
	if record.get("schema_version") != 1 or not record.get("schema_version") is int:
		return {}
	var preset_id: Variant = record.get("preset_id")
	var version: Variant = record.get("preset_version")
	var managed: Variant = record.get("managed_fields")
	var baseline_value: Variant = record.get("baseline")
	if not preset_id is String or not version is int or not managed is Array or not baseline_value is Dictionary:
		return {}
	if version != _VERSION or not _IDS.has(preset_id) or managed != _FIELDS:
		return {}
	var baseline: Dictionary = baseline_value
	if baseline.size() != _FIELDS.size():
		return {}
	for field: StringName in _FIELDS:
		var item: Variant = baseline.get(String(field))
		if not _is_field_value(field, item):
			return {}
	return record.duplicate(true)


## 返回被显式覆盖的受管字段；不把自定义 Curve 当作可自动清空的预设字段。
## [br]
## @api framework_internal
## [br]
## @param step: 带有效预设来源的步骤。
## [br]
## @return: 当前值与应用时基线不同的受管字段名。
static func get_overrides(step: GFTweenActionStep) -> Array[StringName]:
	var fields: Array[StringName] = []
	var baseline: GFTweenActionStep = _get_baseline(step)
	if baseline == null:
		return fields
	for field: StringName in _FIELDS:
		if step.get(field) != baseline.get(field):
			fields.append(field)
	return fields


## 恢复一个受管字段或全部受管字段，返回新步骤；不写来源对象。
## [br]
## @api framework_internal
## [br]
## @param source: 带有效来源的原生步骤。
## [br]
## @param field: 要恢复的受管字段；空名称恢复全部受管字段。
## [br]
## @return: 恢复后的独立步骤；来源、字段或曲线无效时为 null。
static func restore_step(source: GFTweenActionStep, field: StringName = &"") -> GFTweenActionStep:
	var baseline: GFTweenActionStep = _get_baseline(source)
	var copied: GFTweenActionStep = copy_step(source)
	if baseline == null or copied == null or (field != &"" and not _FIELDS.has(field)):
		return null
	for managed_field: StringName in _FIELDS:
		if field == &"" or field == managed_field:
			copied.set(managed_field, baseline.get(managed_field))
	return copied


# --- 私有/辅助方法 ---

## 从已验证来源记录重建独立的受管字段基线；记录无效时返回 null，不修改原步骤。
## [br]
## @api private
static func _get_baseline(step: GFTweenActionStep) -> GFTweenActionStep:
	var record: Dictionary = get_provenance(step)
	if record.is_empty():
		return null
	var baseline: Dictionary = record["baseline"]
	var restored: GFTweenActionStep = GFTweenActionStep.new()
	for field: StringName in _FIELDS:
		restored.set(field, baseline[String(field)])
	return restored


## 验证来源基线字段的类型、有限数值和长度界限；未知字段返回 false。
## 此处不证明属性路径可用于某个样机，实际预览仍须执行自身准入检查。
## [br]
## @api private
static func _is_field_value(field: StringName, value: Variant) -> bool:
	match field:
		&"property_name":
			if value is NodePath:
				var path: NodePath = value
				return String(path).length() <= 256
		&"marker_id":
			if value is StringName:
				var marker: StringName = value
				return String(marker).length() <= 256
		&"as_relative", &"parallel":
			return value is bool
		&"transition_type":
			return value is int and value >= Tween.TRANS_LINEAR and value <= Tween.TRANS_SPRING
		&"ease_type":
			return value is int and value >= Tween.EASE_IN and value <= Tween.EASE_OUT_IN
		&"duration", &"delay":
			return (value is float or value is int) and is_finite(_number(value)) and _number(value) >= 0.0
		&"target_value":
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


## 将整数或浮点数收窄为 float；其他类型返回 NAN，供有限数值检查拒绝。
## [br]
## @api private
static func _number(value: Variant) -> float:
	if value is float:
		var number: float = value
		return number
	if value is int:
		var number: int = value
		return float(number)
	return NAN
