## GFFormulaSet: 按键管理资源化公式的轻量集合。
##
## 适合把一组项目公式集中到配置资源里，再由 System 或 Utility
## 按 `StringName` 获取并计算。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFFormulaSet
extends Resource


# --- 导出变量 ---

## 公式表。Key 推荐为 StringName，Value 应为 GFFormula。
## [br]
## @api public
## [br]
## @schema formulas: Dictionary keyed by StringName or String with GFFormula resources.
@export var formulas: Dictionary = {}


# --- 公共方法 ---

## 注册或替换一个公式。
## [br]
## @api public
## [br]
## @param formula_id: 公式标识。
## [br]
## @param formula: 公式资源。
func set_formula(formula_id: StringName, formula: GFFormula) -> void:
	if formula_id == &"":
		push_error("[GFFormulaSet][formula_set.formula_id_empty] Cannot set_formula: formula_id is empty.")
		return
	if formula == null:
		var _erase_result_39: Variant = formulas.erase(formula_id)
		return
	formulas[formula_id] = formula


## 获取一个公式。
## [br]
## @api public
## [br]
## @param formula_id: 公式标识。
## [br]
## @return 公式资源；不存在时返回 null。
func get_formula(formula_id: StringName) -> GFFormula:
	return _variant_to_formula(GFVariantData.get_option_value(formulas, formula_id))


## 检查是否存在指定公式。
## [br]
## @api public
## [br]
## @param formula_id: 公式标识。
## [br]
## @return 存在时返回 true。
func has_formula(formula_id: StringName) -> bool:
	return formulas.has(formula_id) and formulas[formula_id] is GFFormula


## 计算指定公式。
## [br]
## @api public
## [br]
## @param formula_id: 公式标识。
## [br]
## @param parameter: 公式参数。
## [br]
## @param fallback: 公式不存在时返回的结果。
## [br]
## @schema fallback: Variant result returned when formula_id is absent.
## [br]
## @return 公式结果或 fallback。
## [br]
## @schema return: Variant formula result or fallback.
func calculate(formula_id: StringName, parameter: GFFormulaParameter = null, fallback: Variant = null) -> Variant:
	var formula: GFFormula = get_formula(formula_id)
	if formula == null:
		return fallback
	return formula.calculate(parameter)


# --- 私有/辅助方法 ---

func _variant_to_formula(value: Variant) -> GFFormula:
	if value is GFFormula:
		var formula: GFFormula = value
		return formula
	return null
