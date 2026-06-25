## GFBuffRecipe: 数据化 Buff 配方。
##
## 描述如何创建一个运行时 GFBuff，包括通用生命周期参数、属性修饰器、标签、检查和效果。
## 配方不包含具体战斗业务规则；项目可通过 GFBuffEffect / GFBuffCheck 子类扩展。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFBuffRecipe
extends Resource


# --- 导出变量 ---

## 运行时 Buff ID。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var id: StringName = &""

## 运行时 Buff 持续时间。-1 表示永久。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var duration: float = 0.0

## 初始层数。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var stacks: int = 1

## 最大层数。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var max_stacks: int = 1

## 重复添加时的层数策略。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var stack_mode: GFBuff.StackMode = GFBuff.StackMode.ADD_STACK

## 重复添加时的持续时间刷新策略。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var duration_refresh_policy: GFBuff.DurationRefreshPolicy = GFBuff.DurationRefreshPolicy.RESET_TO_NEW_DURATION

## 周期 Tick 间隔。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var tick_interval_seconds: float = 0.0

## 单次 update 最多补偿 tick 次数。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var max_periodic_ticks_per_update: int = 8

## 持续时间耗尽时是否由 CombatSystem 移除。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var remove_on_expire: bool = true

## 可选 Buff 脚本。为空时创建基础 GFBuff。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var buff_script: Script = null

## Buff 附带的标签。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var tags: Array[StringName] = []

## Buff 附带的属性修饰器字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema modifier_entries: Array[Dictionary]，每项包含 type、value、attribute_id 和 source_id。
@export var modifier_entries: Array[Dictionary] = []

## Buff 应用前检查。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var checks: Array[GFBuffCheck] = []

## Buff 生命周期效果。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var effects: Array[GFBuffEffect] = []

## 项目自定义元数据。GF 不解释其中字段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined buff metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 创建运行时 Buff。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param owner: Buff 拥有者。
## [br]
## @param context: 创建上下文。
## [br]
## @return 新 Buff；配方无效时仍返回基础 Buff，诊断可通过 get_validation_report() 获取。
## [br]
## @schema context: Dictionary，可包含 metadata 作为运行时附加元数据。
func create_buff(owner: Object = null, context: Dictionary = {}) -> GFBuff:
	var buff: GFBuff = _instantiate_buff()
	buff.setup(id, duration, owner)
	buff.stacks = maxi(stacks, 1)
	buff.max_stacks = maxi(max_stacks, 1)
	buff.stack_mode = stack_mode
	buff.duration_refresh_policy = duration_refresh_policy
	buff.tick_interval_seconds = tick_interval_seconds
	buff.max_periodic_ticks_per_update = max_periodic_ticks_per_update
	buff.remove_on_expire = remove_on_expire
	buff.tags = tags.duplicate()
	buff.modifiers = _make_modifiers()
	buff.checks = _duplicate_checks()
	buff.effects = _duplicate_effects()
	buff.metadata = metadata.duplicate(true)
	var context_metadata: Dictionary = GFVariantData.get_option_dictionary(context, "metadata")
	var _metadata_merged: Dictionary = GFVariantData.merge_dictionary(buff.metadata, context_metadata, true, true)
	return buff


## 获取配方诊断报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, issues, summary, and next_action.
func get_validation_report() -> Dictionary:
	var report: Dictionary = {
		"subject": "Buff recipe",
		"buff_id": id,
		"issues": [],
	}
	if id == &"":
		var _id_issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_buff_id",
			"buff id is required",
			{ "field": &"id" }
		)
	if max_stacks < 1:
		var _stack_issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_max_stacks",
			"max_stacks must be greater than zero",
			{ "field": &"max_stacks", "actual_value": max_stacks }
		)
	if buff_script != null and _instantiate_script_buff(buff_script) == null:
		var _script_issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_buff_script",
			"buff_script must create a GFBuff instance",
			{ "field": &"buff_script" }
		)
	return GFValidationReportDictionary.finalize_report(report, "Buff recipe", {
		"fallback_action": "Review the first buff recipe issue.",
		"no_action": "Buff recipe is valid.",
	})


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 配方字典。
## [br]
## @schema return: Dictionary with generic buff recipe fields.
func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"duration": duration,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"stack_mode": stack_mode,
		"duration_refresh_policy": duration_refresh_policy,
		"tick_interval_seconds": tick_interval_seconds,
		"max_periodic_ticks_per_update": max_periodic_ticks_per_update,
		"remove_on_expire": remove_on_expire,
		"tags": tags.duplicate(),
		"modifier_entries": _copy_modifier_entries(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _instantiate_buff() -> GFBuff:
	var scripted: GFBuff = _instantiate_script_buff(buff_script)
	if scripted != null:
		return scripted
	return GFBuff.new()


func _instantiate_script_buff(script: Script) -> GFBuff:
	if script == null:
		return null
	var instance_value: Variant = script.call("new")
	if instance_value is GFBuff:
		var buff: GFBuff = instance_value
		return buff
	return null


func _make_modifiers() -> Array[GFModifier]:
	var result: Array[GFModifier] = []
	for entry: Dictionary in modifier_entries:
		var modifier: GFModifier = GFModifier.from_dictionary(entry)
		if modifier != null:
			result.append(modifier)
	return result


func _duplicate_checks() -> Array[GFBuffCheck]:
	var result: Array[GFBuffCheck] = []
	for check: GFBuffCheck in checks:
		if check == null:
			continue
		var duplicate_value: Resource = check.duplicate(true)
		if duplicate_value is GFBuffCheck:
			var duplicate_check: GFBuffCheck = duplicate_value
			result.append(duplicate_check)
		else:
			result.append(check)
	return result


func _duplicate_effects() -> Array[GFBuffEffect]:
	var result: Array[GFBuffEffect] = []
	for effect: GFBuffEffect in effects:
		if effect == null:
			continue
		var duplicate_value: Resource = effect.duplicate(true)
		if duplicate_value is GFBuffEffect:
			var duplicate_effect: GFBuffEffect = duplicate_value
			result.append(duplicate_effect)
		else:
			result.append(effect)
	return result


func _copy_modifier_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in modifier_entries:
		result.append(entry.duplicate(true))
	return result
