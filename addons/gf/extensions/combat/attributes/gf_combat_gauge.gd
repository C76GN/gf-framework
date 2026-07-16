## GFCombatGauge: 通用可变数值槽。
##
## 用 GFCombatAction 驱动一个带上下限的数值。它可表示生命、护盾、能量、
## 耐久或任意项目自定义资源，但框架不绑定这些业务语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFCombatGauge
extends Node


# --- 信号 ---

## 数值变化时发出。
## [br]
## @api public
## [br]
## @param previous_value: 旧值。
## [br]
## @param current_value: 新值。
signal value_changed(previous_value: float, current_value: float)

## 动作进入自定义校验阶段时发出。
## [br]
## @api public
## [br]
## @param action: 已经应用修正器的动作副本。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema report: Dictionary，包含 ok、reason 和 metadata，可由监听者调整。
signal action_validating(action: GFCombatAction, report: Dictionary)

## 动作成功应用时发出。
## [br]
## @api public
## [br]
## @param result: 应用结果。
signal action_applied(result: GFCombatActionResult)

## 动作被拒绝时发出。
## [br]
## @api public
## [br]
## @param result: 拒绝结果。
signal action_rejected(result: GFCombatActionResult)

## 数值到达下限时发出。
## [br]
## @api public
## [br]
## @param current_value: 当前值。
signal minimum_reached(current_value: float)

## 数值到达上限时发出。
## [br]
## @api public
## [br]
## @param current_value: 当前值。
signal maximum_reached(current_value: float)


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## 数值下限。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var min_value: float:
	get:
		return _min_value
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_float(value):
			_min_value = value

## 数值上限。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var max_value: float:
	get:
		return _max_value
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_float(value):
			_max_value = value

## 当前数值。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var current_value: float:
	get:
		return _current_value
	set(value):
		if _GF_COMBAT_FINITE_MATH.is_finite_float(value):
			_current_value = value

## 非空时，只接受这些动作类别。
## [br]
## @api public
@export var accepted_action_kinds: Array[StringName] = []

## 始终拒绝的动作类别。
## [br]
## @api public
@export var rejected_action_kinds: Array[StringName] = []

## 动作修正器。
## [br]
## @api public
@export var modifiers: Array[GFCombatActionModifier] = []

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义数值槽元数据；默认进入动作校验报告。
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 自定义校验回调，建议签名为 func(action: GFCombatAction, report: Dictionary) -> Variant。
## 返回 bool 可直接决定是否接受；返回 Dictionary 可覆盖 ok、reason、metadata 等报告字段。
## [br]
## @api public
var validation_callback: Callable = Callable()


# --- 私有变量 ---

var _min_value: float = 0.0
var _max_value: float = 100.0
var _current_value: float = 100.0


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_current_value = clampf(_current_value, minf(_min_value, _max_value), maxf(_min_value, _max_value))


# --- 公共方法 ---

## 配置数值槽。
## [br]
## @api public
## [br]
## @param p_min_value: 数值下限。
## [br]
## @param p_max_value: 数值上限。
## [br]
## @param p_current_value: 当前数值。
func configure(p_min_value: float, p_max_value: float, p_current_value: float) -> void:
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(p_min_value)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(p_max_value)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(p_current_value)
	):
		return
	_min_value = p_min_value
	_max_value = p_max_value
	set_value(p_current_value)


## 设置当前数值。
## [br]
## @api public
## [br]
## @param value: 新数值。
func set_value(value: float) -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(value):
		return
	var previous_value: float = current_value
	current_value = clampf(value, minf(min_value, max_value), maxf(min_value, max_value))
	if is_equal_approx(previous_value, current_value):
		return

	value_changed.emit(previous_value, current_value)
	_emit_bound_signals()


## 设置上下限并夹取当前值。
## [br]
## @api public
## [br]
## @param p_min_value: 数值下限。
## [br]
## @param p_max_value: 数值上限。
func set_bounds(p_min_value: float, p_max_value: float) -> void:
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(p_min_value)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(p_max_value)
	):
		return
	_min_value = p_min_value
	_max_value = p_max_value
	set_value(current_value)


## 获取 0 到 1 的当前比例。
## [br]
## @api public
## [br]
## @return 当前比例。
func get_ratio() -> float:
	var low: float = minf(min_value, max_value)
	var high: float = maxf(min_value, max_value)
	if is_equal_approx(high, low):
		return 0.0
	return clampf((current_value - low) / (high - low), 0.0, 1.0)


## 检查动作类别是否可被当前数值槽接收。
## [br]
## @api public
## [br]
## @param action_kind: 动作类别。
## [br]
## @return 可接收时返回 true。
func can_receive_action_kind(action_kind: StringName) -> bool:
	if rejected_action_kinds.has(action_kind):
		return false
	return accepted_action_kinds.is_empty() or accepted_action_kinds.has(action_kind)


## 添加动作修正器。
## [br]
## @api public
## [br]
## @param modifier: 修正器。
func add_modifier(modifier: GFCombatActionModifier) -> void:
	if modifier == null or modifiers.has(modifier):
		return
	modifiers.append(modifier)


## 移除动作修正器。
## [br]
## @api public
## [br]
## @param modifier: 修正器。
func remove_modifier(modifier: GFCombatActionModifier) -> void:
	modifiers.erase(modifier)


## 清空动作修正器。
## [br]
## @api public
func clear_modifiers() -> void:
	modifiers.clear()


## 应用动作。
## [br]
## @api public
## [br]
## @param action: 原始动作。
## [br]
## @return 应用结果。
func apply_action(action: GFCombatAction) -> GFCombatActionResult:
	if action == null:
		var null_result: GFCombatActionResult = GFCombatActionResult.make_failure(&"null_action", null, current_value, metadata)
		action_rejected.emit(null_result)
		return null_result
	if not action.is_numeric_state_valid():
		var numeric_result: GFCombatActionResult = GFCombatActionResult.make_failure(
			&"non_finite_action",
			action,
			current_value,
			metadata
		)
		action_rejected.emit(numeric_result)
		return numeric_result

	if not can_receive_action_kind(action.action_kind):
		var kind_result: GFCombatActionResult = GFCombatActionResult.make_failure(&"unaccepted_kind", action, current_value, metadata)
		action_rejected.emit(kind_result)
		return kind_result

	var final_action: GFCombatAction = _apply_modifiers(action)
	if final_action == null or not final_action.is_numeric_state_valid():
		var modifier_result: GFCombatActionResult = GFCombatActionResult.make_failure(
			&"non_finite_modified_action",
			action,
			current_value,
			metadata
		)
		if final_action != null:
			modifier_result.action = final_action.duplicate_action()
		action_rejected.emit(modifier_result)
		return modifier_result
	var validation_report: Dictionary = _validate_action(final_action)
	if not GFVariantData.get_option_bool(validation_report, "ok", true):
		var rejected_metadata: Dictionary = _get_report_metadata(validation_report)
		var rejected_result: GFCombatActionResult = GFCombatActionResult.make_failure(
			GFVariantData.get_option_string_name(validation_report, "reason", &"rejected"),
			action,
			current_value,
			rejected_metadata
		)
		rejected_result.action = final_action.duplicate_action()
		action_rejected.emit(rejected_result)
		return rejected_result

	var previous_value: float = current_value
	var next_value: float = _calculate_next_value(final_action)
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(next_value):
		var overflow_result: GFCombatActionResult = GFCombatActionResult.make_failure(
			&"non_finite_result",
			action,
			current_value,
			metadata
		)
		overflow_result.action = final_action.duplicate_action()
		action_rejected.emit(overflow_result)
		return overflow_result
	set_value(next_value)

	var applied_metadata: Dictionary = _get_report_metadata(validation_report)
	var applied_result: GFCombatActionResult = GFCombatActionResult.make_success(
		action,
		final_action,
		previous_value,
		current_value,
		applied_metadata
	)
	action_applied.emit(applied_result)
	return applied_result


# --- 私有/辅助方法 ---

func _apply_modifiers(action: GFCombatAction) -> GFCombatAction:
	var result: GFCombatAction = action.duplicate_action()
	for modifier: GFCombatActionModifier in modifiers:
		if modifier == null:
			continue
		result = modifier.apply(result)
	return result


func _validate_action(action: GFCombatAction) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"reason": &"accepted",
		"metadata": metadata.duplicate(true),
	}
	action_validating.emit(action.duplicate_action(), report)
	if validation_callback.is_valid():
		var callback_result: Variant = validation_callback.call(action.duplicate_action(), report.duplicate(true))
		_merge_validation_result(report, callback_result)
	return report


func _merge_validation_result(report: Dictionary, value: Variant) -> void:
	if value is bool:
		report["ok"] = GFVariantData.to_bool(value)
		if not GFVariantData.to_bool(value):
			report["reason"] = &"validation_failed"
		return
	if not (value is Dictionary):
		return

	var value_dict: Dictionary = GFVariantData.as_dictionary(value)
	if value_dict.has("ok"):
		report["ok"] = GFVariantData.get_option_bool(value_dict, "ok")
	if value_dict.has("reason"):
		report["reason"] = GFVariantData.get_option_string_name(value_dict, "reason")
	var value_metadata: Dictionary = GFVariantData.get_option_dictionary(value_dict, "metadata")
	if not value_metadata.is_empty():
		var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")
		for key: Variant in value_metadata.keys():
			report_metadata[key] = GFVariantData.duplicate_variant(value_metadata[key])
		report["metadata"] = report_metadata


func _calculate_next_value(action: GFCombatAction) -> float:
	match action.operation:
		GFCombatAction.Operation.ADD:
			return current_value + action.amount
		GFCombatAction.Operation.SET:
			return action.amount
		_:
			return current_value - action.amount


func _get_report_metadata(report: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(report, "metadata")


func _emit_bound_signals() -> void:
	var low: float = minf(min_value, max_value)
	var high: float = maxf(min_value, max_value)
	if is_equal_approx(current_value, low):
		minimum_reached.emit(current_value)
	if is_equal_approx(current_value, high):
		maximum_reached.emit(current_value)
