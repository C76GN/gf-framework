## GFFormula: 资源化公式基类。
##
## 公式是纯计算策略，不持有运行时生命周期。
## 项目可继承并重写 `calculate()`，也可通过 `calculate_float()`、
## `calculate_int()` 和 `calculate_bool()` 获得稳定的类型兜底。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFFormula
extends Resource


# --- 导出变量 ---

## 当子类没有返回有效数值时使用的兜底结果。
## [br]
## @api public
## [br]
## @schema fallback_value: Variant default formula result.
@export var fallback_value: Variant = 0.0


# --- 公共方法 ---

## 执行公式计算。
## [br]
## @api public
## [br]
## @param _parameter: 公式参数容器。
## [br]
## @return 公式结果。子类应重写该方法。
## [br]
## @schema return: Variant formula result.
func calculate(_parameter: GFFormulaParameter = null) -> Variant:
	return fallback_value


## 以 float 形式执行公式。
## [br]
## @api public
## [br]
## @param parameter: 公式参数容器。
## [br]
## @param fallback: 结果无法转为数字时使用的兜底值。
## [br]
## @return float 结果。
func calculate_float(parameter: GFFormulaParameter = null, fallback: float = 0.0) -> float:
	var result: Variant = calculate(parameter)
	if typeof(result) == TYPE_INT or typeof(result) == TYPE_FLOAT:
		return _finite_or_fallback(GFVariantData.to_float(result), fallback)
	if typeof(result) == TYPE_BOOL:
		return 1.0 if result else 0.0
	if typeof(result) == TYPE_STRING or typeof(result) == TYPE_STRING_NAME:
		var text: String = GFVariantData.to_text(result).strip_edges()
		if text.is_valid_float():
			return _finite_or_fallback(text.to_float(), fallback)
		return fallback
	return fallback


## 以 int 形式执行公式。
## [br]
## @api public
## [br]
## @param parameter: 公式参数容器。
## [br]
## @param fallback: 结果无法转为数字时使用的兜底值。
## [br]
## @return int 结果。
func calculate_int(parameter: GFFormulaParameter = null, fallback: int = 0) -> int:
	return GFVariantData.to_int(round(calculate_float(parameter, float(fallback))))


## 以 bool 形式执行公式。
## [br]
## @api public
## [br]
## @param parameter: 公式参数容器。
## [br]
## @param fallback: 结果无法转为布尔语义时使用的兜底值。
## [br]
## @return bool 结果。
func calculate_bool(parameter: GFFormulaParameter = null, fallback: bool = false) -> bool:
	var result: Variant = calculate(parameter)
	if typeof(result) == TYPE_BOOL:
		return GFVariantData.to_bool(result)
	if typeof(result) == TYPE_INT or typeof(result) == TYPE_FLOAT:
		var numeric_value: float = GFVariantData.to_float(result)
		if is_nan(numeric_value) or is_inf(numeric_value):
			return fallback
		return numeric_value != 0.0
	if typeof(result) == TYPE_STRING or typeof(result) == TYPE_STRING_NAME:
		var text: String = GFVariantData.to_text(result).to_lower()
		if text == "true" or text == "yes" or text == "1":
			return true
		if text == "false" or text == "no" or text == "0":
			return false
	return fallback


# --- 私有/辅助方法 ---

static func _finite_or_fallback(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value
