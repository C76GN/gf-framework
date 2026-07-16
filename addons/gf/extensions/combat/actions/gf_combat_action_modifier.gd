## GFCombatActionModifier: 通用战斗动作修正器。
##
## 按动作类别和标签过滤后，调整动作数值或操作。它不解释动作业务语义，
## 只负责把一个 GFCombatAction 转换为另一个 GFCombatAction。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFCombatActionModifier
extends Resource


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## 修正器标识。
## [br]
## @api public
@export var modifier_id: StringName = &""

## 非空时，只匹配这些动作类别。
## [br]
## @api public
@export var accepted_action_kinds: Array[StringName] = []

## 始终拒绝匹配的动作类别。
## [br]
## @api public
@export var rejected_action_kinds: Array[StringName] = []

## 非空时，动作必须包含这些标签。
## [br]
## @api public
@export var required_tags: Array[StringName] = []

## 数值加成。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var amount_add: float:
	get:
		return _amount_add
	set(value):
		_amount_add_is_valid = _GF_COMBAT_FINITE_MATH.is_finite_float(value)
		if _amount_add_is_valid:
			_amount_add = value

## 数值乘区。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var amount_multiplier: float:
	get:
		return _amount_multiplier
	set(value):
		_amount_multiplier_is_valid = _GF_COMBAT_FINITE_MATH.is_finite_float(value)
		if _amount_multiplier_is_valid:
			_amount_multiplier = value

## 是否覆盖动作操作。
## [br]
## @api public
@export var override_operation: bool = false

## 覆盖后的动作操作。
## [br]
## @api public
@export var operation: GFCombatAction.Operation = GFCombatAction.Operation.SUBTRACT

## 是否覆盖动作类别。
## [br]
## @api public
@export var override_action_kind: bool = false

## 覆盖后的动作类别。
## [br]
## @api public
@export var action_kind: StringName = &""

## 修正器元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义元数据；应用修正器时复制到动作结果的 modifiers 记录中。
@export var metadata: Dictionary = {}


# --- 私有变量 ---

var _amount_add: float = 0.0
var _amount_add_is_valid: bool = true
var _amount_multiplier: float = 1.0
var _amount_multiplier_is_valid: bool = true


# --- 公共方法 ---

## 检查修正器是否匹配动作。
## [br]
## @api public
## [br]
## @param action: 原始动作。
## [br]
## @return 匹配时返回 true。
func matches(action: GFCombatAction) -> bool:
	if action == null:
		return false
	if rejected_action_kinds.has(action.action_kind):
		return false
	if not accepted_action_kinds.is_empty() and not accepted_action_kinds.has(action.action_kind):
		return false
	for required_tag: StringName in required_tags:
		if not action.tags.has(required_tag):
			return false
	return true


## 检查修正器数值是否可安全参与运算。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 所有数值字段有限时返回 true。
func is_numeric_state_valid() -> bool:
	return (
		_amount_add_is_valid
		and _amount_multiplier_is_valid
		and _GF_COMBAT_FINITE_MATH.is_finite_float(_amount_add)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(_amount_multiplier)
	)


## 应用修正器。
## [br]
## @api public
## [br]
## @param action: 原始动作。
## [br]
## @return 修正后的动作副本。
func apply(action: GFCombatAction) -> GFCombatAction:
	if action == null:
		return null

	var result: GFCombatAction = action.duplicate_action()
	if not matches(action):
		return result
	if not action.is_numeric_state_valid() or not is_numeric_state_valid():
		result.amount = NAN
		return result

	result.amount = (result.amount + amount_add) * amount_multiplier
	if override_operation:
		result.operation = operation
	if override_action_kind:
		result.action_kind = action_kind

	var modifier_metadata: Array = []
	var modifier_metadata_value: Variant = GFVariantData.get_option_value(result.metadata, "modifiers", [])
	modifier_metadata = GFVariantData.to_array(modifier_metadata_value)
	modifier_metadata.append({
		"modifier_id": modifier_id,
		"metadata": metadata.duplicate(true),
	})
	result.metadata["modifiers"] = modifier_metadata
	return result


## 复制修正器。
## [br]
## @api public
## [br]
## @return 新修正器。
func duplicate_modifier() -> GFCombatActionModifier:
	var modifier: GFCombatActionModifier = GFCombatActionModifier.new()
	modifier.modifier_id = modifier_id
	modifier.accepted_action_kinds = accepted_action_kinds.duplicate()
	modifier.rejected_action_kinds = rejected_action_kinds.duplicate()
	modifier.required_tags = required_tags.duplicate()
	modifier.amount_add = amount_add
	modifier.amount_multiplier = amount_multiplier
	modifier._amount_add_is_valid = _amount_add_is_valid
	modifier._amount_multiplier_is_valid = _amount_multiplier_is_valid
	modifier.override_operation = override_operation
	modifier.operation = operation
	modifier.override_action_kind = override_action_kind
	modifier.action_kind = action_kind
	modifier.metadata = metadata.duplicate(true)
	return modifier
