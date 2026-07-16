## GFTrait: 通用被动特征数据。
##
## 用于描述“某个来源对某个目标键产生的数值或标记影响”。
## 它不限定属性、伤害、装备等业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTrait
extends Resource


# --- 枚举 ---

## 数值合并方式。
## [br]
## @api public
enum CombineMode {
	## 与当前值相加。
	ADD,

	## 与当前值相乘。
	MULTIPLY,

	## 直接覆盖当前值。
	SET,

	## 取当前值与特征值中的较大值。
	MAX,

	## 取当前值与特征值中的较小值。
	MIN,
}


# --- 导出变量 ---

## 特征标识。
## [br]
## @api public
@export var trait_id: StringName = &""

## 目标键，例如属性名、规则名或项目自定义键。
## [br]
## @api public
@export var target_id: StringName = &""

## 可选分类，用于过滤不同规则域。
## [br]
## @api public
@export var category: StringName = &""

## 数值。
## [br]
## @api public
@export var value: float = 0.0

## 合并方式。
## [br]
## @api public
@export var combine_mode: CombineMode = CombineMode.ADD

## 排序优先级，值越小越先应用。
## [br]
## @api public
@export var priority: int = 0

## 自定义元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目自定义特征元数据；GF 不读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 将当前特征应用到数值上。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param current_value: 当前值。
## [br]
## @return: 应用后的有限值；无效输入或溢出时保留最后一个有限值。
func apply_number(current_value: float) -> float:
	var safe_current: float = current_value if _is_finite_number(current_value) else 0.0
	if not _is_finite_number(value):
		return safe_current
	var result: float = safe_current
	match combine_mode:
		CombineMode.ADD:
			result = safe_current + value
		CombineMode.MULTIPLY:
			result = safe_current * value
		CombineMode.SET:
			result = value
		CombineMode.MAX:
			result = maxf(safe_current, value)
		CombineMode.MIN:
			result = minf(safe_current, value)
	return result if _is_finite_number(result) else safe_current


# --- 私有/辅助方法 ---

func _is_finite_number(number: float) -> bool:
	return not is_nan(number) and not is_inf(number)
