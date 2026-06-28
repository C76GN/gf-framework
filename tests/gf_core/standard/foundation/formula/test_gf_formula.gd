## 测试 GFFormula、GFFormulaParameter 与 GFFormulaSet 的通用计算能力。
extends GutTest


# --- 辅助类 ---

class ValueFormula extends GFFormula:
	var key: StringName = &""

	func _init(p_key: StringName = &"", p_fallback: Variant = 0.0) -> void:
		key = p_key
		fallback_value = p_fallback

	func calculate(parameter: GFFormulaParameter = null) -> Variant:
		if parameter == null:
			return fallback_value
		return parameter.get_value(key, fallback_value)


# --- 测试方法 ---

## 验证公式参数容器可链式写入并复制。
func test_formula_parameter_stores_values() -> void:
	var source: Object = Object.new()
	var target: Object = Object.new()
	var parameter: GFFormulaParameter = GFFormulaParameter.new(source, target).set_value(&"power", 12)
	var copy: GFFormulaParameter = parameter.duplicate_parameter()

	assert_eq(parameter.source, source, "参数应保留 source。")
	assert_eq(parameter.target, target, "参数应保留 target。")
	assert_eq(GFVariantData.to_int(parameter.get_value(&"power")), 12, "应能读取写入的参数。")
	assert_eq(GFVariantData.to_int(copy.get_value(&"power")), 12, "复制后的参数应保留数值。")

	source.free()
	target.free()


func test_formula_parameter_isolates_collection_values() -> void:
	var source_stats: Dictionary = { "tags": ["base"] }
	var parameter: GFFormulaParameter = GFFormulaParameter.new().set_value(&"stats", source_stats)
	var raw_source_tags: Variant = source_stats["tags"]
	var source_tags: Array = raw_source_tags if raw_source_tags is Array else []
	source_tags.append("source_mutation")

	var first_read: Dictionary = GFVariantData.as_dictionary(parameter.get_value(&"stats", {}))
	var raw_first_read_tags: Variant = first_read["tags"]
	var first_read_tags: Array = raw_first_read_tags if raw_first_read_tags is Array else []
	first_read_tags.append("read_mutation")
	var second_read: Dictionary = GFVariantData.as_dictionary(parameter.get_value(&"stats", {}))

	assert_eq(GFVariantData.as_array(second_read["tags"]), ["base"], "set_value 与 get_value 都应隔离集合引用。")


## 验证公式类型转换使用稳定兜底。
func test_formula_type_helpers() -> void:
	var formula: ValueFormula = ValueFormula.new(&"value", "3.5")
	var parameter: GFFormulaParameter = GFFormulaParameter.new().set_value(&"value", "4.25")

	assert_almost_eq(formula.calculate_float(parameter), 4.25, 0.001, "字符串数值应可转为 float。")
	assert_eq(formula.calculate_int(parameter), 4, "int helper 应四舍五入。")
	assert_true(ValueFormula.new(&"flag", false).calculate_bool(
		GFFormulaParameter.new().set_value(&"flag", "true")
	), "字符串 true 应可转为 bool。")


## 验证非法数字字符串不会静默变成 0。
func test_formula_float_uses_fallback_for_invalid_string() -> void:
	var formula: ValueFormula = ValueFormula.new(&"value", 0.0)
	var parameter: GFFormulaParameter = GFFormulaParameter.new().set_value(&"value", "not-a-number")

	assert_almost_eq(formula.calculate_float(parameter, -3.5), -3.5, 0.001, "非法数字字符串应返回 fallback。")


func test_formula_numeric_helpers_reject_nan_and_inf() -> void:
	var formula: ValueFormula = ValueFormula.new(&"value", 0.0)

	assert_almost_eq(
		formula.calculate_float(GFFormulaParameter.new().set_value(&"value", NAN), -3.5),
		-3.5,
		0.001,
		"NaN 应返回 float fallback。"
	)
	assert_eq(
		formula.calculate_int(GFFormulaParameter.new().set_value(&"value", INF), -7),
		-7,
		"INF 应返回 int fallback。"
	)
	assert_false(
		formula.calculate_bool(GFFormulaParameter.new().set_value(&"value", INF), false),
		"INF 不应被 bool helper 当作 true。"
	)


## 验证公式集合按 StringName 调度公式。
func test_formula_set_calculates_registered_formula() -> void:
	var formula_set: GFFormulaSet = GFFormulaSet.new()
	formula_set.set_formula(&"score", ValueFormula.new(&"score", 0))

	var parameter: GFFormulaParameter = GFFormulaParameter.new().set_value(&"score", 99)

	assert_true(formula_set.has_formula(&"score"), "注册后应能查询到公式。")
	assert_eq(GFVariantData.to_int(formula_set.calculate(&"score", parameter)), 99, "应调用对应公式。")
	assert_eq(GFVariantData.to_int(formula_set.calculate(&"missing", parameter, -1)), -1, "缺失公式应返回 fallback。")
