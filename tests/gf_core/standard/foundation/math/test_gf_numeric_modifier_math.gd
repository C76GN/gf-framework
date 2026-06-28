## 测试 GFNumericModifierMath 的优先级数值修饰、诊断和 JSON 友好报告。
extends GutTest


# --- 测试 ---

func test_calculate_applies_enabled_modifiers_in_priority_order() -> void:
	var modifiers: Array = [
		GFNumericModifierMath.make_modifier(2.0, GFNumericModifierMath.Operation.MULTIPLY, 10, true, &"double"),
		GFNumericModifierMath.make_modifier(5.0, GFNumericModifierMath.Operation.ADD, 0, true, &"flat"),
		GFNumericModifierMath.make_modifier(3.0, GFNumericModifierMath.Operation.DIVIDE, 20, true, &"third"),
		GFNumericModifierMath.make_modifier(100.0, GFNumericModifierMath.Operation.ADD, -10, false, &"disabled"),
	]

	var report: Dictionary = GFNumericModifierMath.calculate(10.0, modifiers)
	var applied_modifiers: Array = GFVariantData.get_option_array(report, "applied_modifiers")
	var skipped_modifiers: Array = GFVariantData.get_option_array(report, "skipped_modifiers")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效修饰应成功计算。")
	assert_almost_eq(GFVariantData.get_option_float(report, "value"), 10.0, 0.001, "应按 priority 顺序执行 add/multiply/divide。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 3, "启用修饰应进入应用统计。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_count"), 1, "禁用修饰应进入跳过统计。")
	assert_eq(_entry_string(applied_modifiers, 0, "id"), "flat", "较小 priority 应先应用。")
	assert_eq(_entry_string(applied_modifiers, 1, "id"), "double", "同一轮计算应保留排序后的应用顺序。")
	assert_eq(_entry_string(applied_modifiers, 2, "id"), "third", "除法修饰应在最后应用。")
	assert_eq(_entry_string(skipped_modifiers, 0, "reason"), "disabled", "禁用项应说明跳过原因。")


func test_calculate_reports_invalid_modifiers_and_clamps_result() -> void:
	var modifiers: Array = [
		GFNumericModifierMath.make_modifier(0.0, GFNumericModifierMath.Operation.DIVIDE, 0, true, &"zero_divide"),
		GFNumericModifierMath.make_modifier(100.0, GFNumericModifierMath.Operation.ADD, 10, true, &"large_add"),
	]
	var options: Dictionary = {
		"clamp_enabled": true,
		"min_value": 0.0,
		"max_value": 50.0,
	}

	var report: Dictionary = GFNumericModifierMath.calculate(10.0, modifiers, options)
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "有无效修饰时 ok 应为 false。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "除零应报告一个 issue。")
	assert_eq(_entry_string(issues, 0, "kind"), "divide_by_zero", "除零 issue 应明确标记。")
	assert_almost_eq(GFVariantData.get_option_float(report, "unclamped_value"), 110.0, 0.001, "无效除法应跳过，后续修饰仍可执行。")
	assert_almost_eq(GFVariantData.get_option_float(report, "value"), 50.0, 0.001, "启用 clamp 后结果应被限制。")
	assert_true(GFVariantData.get_option_bool(report, "clamped"), "报告应标记本次发生 clamp。")


func test_non_finite_input_is_sanitized_for_json_reports() -> void:
	var modifiers: Array = [
		GFNumericModifierMath.make_modifier(INF, GFNumericModifierMath.Operation.ADD, 0, true, &"bad_value"),
		GFNumericModifierMath.make_modifier(2.0, GFNumericModifierMath.Operation.MULTIPLY, 10, true, &"double"),
	]
	var report: Dictionary = GFNumericModifierMath.calculate(NAN, modifiers, { "fallback_value": 4.0 })
	var json_text: String = JSON.stringify(report)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非有限输入应进入诊断。")
	assert_almost_eq(GFVariantData.get_option_float(report, "value"), 8.0, 0.001, "基础值应回退为 fallback 后继续计算有效修饰。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 2, "基础 NaN 与修饰 INF 都应进入 issue。")
	assert_false(json_text.contains("NaN"), "报告不应把 NaN 交给 JSON.stringify。")
	assert_false(json_text.contains("Infinity"), "报告不应把 Infinity 交给 JSON.stringify。")


func test_normalize_modifier_accepts_text_operation_and_copies_metadata() -> void:
	var metadata: Dictionary = { "tags": ["temporary"] }
	var normalized: Dictionary = GFNumericModifierMath.normalize_modifier({
		"modifier_id": &"boost",
		"value": "3.5",
		"operation": "multiply",
		"priority": 4,
		"enabled": false,
		"metadata": metadata,
	})
	var normalized_metadata: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(normalized, "metadata", {})
	)
	metadata["tags"] = ["changed"]

	assert_eq(GFVariantData.get_option_string_name(normalized, "id"), &"boost", "modifier_id 应规范化为 id。")
	assert_eq(GFVariantData.get_option_int(normalized, "operation"), GFNumericModifierMath.Operation.MULTIPLY, "文本 operation 应被识别。")
	assert_almost_eq(GFVariantData.get_option_float(normalized, "value"), 3.5, 0.001, "字符串数值应转为 float。")
	assert_false(GFVariantData.get_option_bool(normalized, "enabled"), "enabled 应保留。")
	assert_eq(GFVariantData.get_option_array(normalized_metadata, "tags"), ["temporary"], "metadata 应深拷贝。")


# --- 私有/辅助方法 ---

func _entry_string(entries: Array, index: int, key: String) -> String:
	if index < 0 or index >= entries.size():
		return ""

	var entry_variant: Variant = entries[index]
	if entry_variant is Dictionary:
		var entry: Dictionary = entry_variant
		return GFVariantData.get_option_string(entry, key)
	return ""
