## GFCombatAction: 通用战斗动作数据。
##
## 表达一次对目标系统可解释的数值动作。框架只保存动作类别、操作、数值、
## 标签和元数据，不规定伤害、治疗、阵营或生命值语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFCombatAction
extends Resource


# --- 枚举 ---

## 数值操作类型。
## [br]
## @api public
enum Operation {
	## 增加目标值。
	ADD,
	## 减少目标值。
	SUBTRACT,
	## 直接设置目标值。
	SET,
}


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## 动作标识。
## [br]
## @api public
@export var action_id: StringName = &""

## 动作类别，由项目定义。
## [br]
## @api public
@export var action_kind: StringName = &""

## 数值操作。
## [br]
## @api public
@export var operation: Operation = Operation.SUBTRACT

## 动作数值。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var amount: float:
	get:
		return _amount
	set(value):
		_amount_is_valid = _GF_COMBAT_FINITE_MATH.is_finite_float(value)
		if _amount_is_valid:
			_amount = value

## 动作标签，由项目定义。
## [br]
## @api public
@export var tags: Array[StringName] = []

## 项目自定义 payload。
## [br]
## @api public
## [br]
## @schema payload: Variant，可保存项目自定义动作载荷；框架只复制并透传。
@export var payload: Variant = null

## 项目自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义元数据；框架只复制并透传。
@export var metadata: Dictionary = {}


# --- 私有变量 ---

var _amount: float = 0.0
var _amount_is_valid: bool = true


# --- 公共方法 ---

## 复制动作。
## [br]
## @api public
## [br]
## @return 新动作。
func duplicate_action() -> GFCombatAction:
	var action: GFCombatAction = GFCombatAction.new()
	action.action_id = action_id
	action.action_kind = action_kind
	action.operation = operation
	action.amount = amount
	action._amount_is_valid = _amount_is_valid
	action.tags = tags.duplicate()
	action.payload = GFVariantData.duplicate_variant(payload)
	action.metadata = metadata.duplicate(true)
	return action


## 设置动作标识并返回自身。
## [br]
## @api public
## [br]
## @param value: 动作标识。
## [br]
## @return 当前动作。
func with_action_id(value: StringName) -> GFCombatAction:
	action_id = value
	return self


## 设置动作类别并返回自身。
## [br]
## @api public
## [br]
## @param value: 动作类别。
## [br]
## @return 当前动作。
func with_kind(value: StringName) -> GFCombatAction:
	action_kind = value
	return self


## 设置数值操作并返回自身。
## [br]
## @api public
## [br]
## @param value: 数值操作。
## [br]
## @return 当前动作。
func with_operation(value: Operation) -> GFCombatAction:
	operation = value
	return self


## 设置动作数值并返回自身。
## [br]
## @api public
## [br]
## @param value: 动作数值。
## [br]
## @return 当前动作。
func with_amount(value: float) -> GFCombatAction:
	amount = value
	return self


## 检查动作数值是否可安全参与运算。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 最近一次 amount 写入有效且当前值有限时返回 true。
func is_numeric_state_valid() -> bool:
	return _amount_is_valid and _GF_COMBAT_FINITE_MATH.is_finite_float(_amount)


## 设置动作标签并返回自身。
## [br]
## @api public
## [br]
## @param value: 动作标签。
## [br]
## @return 当前动作。
func with_tags(value: Array[StringName]) -> GFCombatAction:
	tags = value.duplicate()
	return self


## 设置 payload 并返回自身。
## [br]
## @api public
## [br]
## @param value: 载荷。
## [br]
## @return 当前动作。
## [br]
## @schema value: Variant，可保存项目自定义动作载荷；框架只复制并透传。
func with_payload(value: Variant) -> GFCombatAction:
	payload = GFVariantData.duplicate_variant(value)
	return self


## 设置元数据并返回自身。
## [br]
## @api public
## [br]
## @param value: 元数据。
## [br]
## @return 当前动作。
## [br]
## @schema value: Dictionary，项目自定义元数据；框架只复制并透传。
func with_metadata(value: Dictionary) -> GFCombatAction:
	metadata = value.duplicate(true)
	return self


## 转为字典。
## [br]
## @api public
## [br]
## @return 字典快照。
## [br]
## @schema return: Dictionary，包含 action_id、action_kind、operation、amount、tags、payload 和 metadata。
func to_dict() -> Dictionary:
	return {
		"action_id": action_id,
		"action_kind": action_kind,
		"operation": operation,
		"amount": amount,
		"tags": tags.duplicate(),
		"payload": GFVariantData.duplicate_variant(payload),
		"metadata": metadata.duplicate(true),
	}


## 转为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 报告字典快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dict().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dict(), options)
