## 测试安全文本生成上下文。
extends GutTest


func test_replace_tokens_reads_explicit_data_paths() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"player": {
			"name": "Ada",
		},
		"items": ["sword", "shield"],
	}, {
		"strict_variables": true,
	})

	var output: String = context.replace_tokens("Hello {{ player.name }}, take {{ items.1 }}.")

	assert_eq(output, "Hello Ada, take shield.", "token 只应解析纯数据路径。")
	assert_true(context.get_report().is_ok(), "成功替换不应产生诊断。")


func test_missing_token_and_output_limit_are_reported() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({}, {
		"strict_variables": true,
		"max_output_length": 5,
	})

	var output: String = context.replace_tokens("{{ missing }}", {
		"missing_text": "?",
	})
	var appended_first: bool = context.append_text("hello")
	var appended_second: bool = context.append_text("!")

	assert_eq(output, "?", "缺失 token 应使用 missing_text。")
	assert_true(appended_first, "预算内输出应成功。")
	assert_false(appended_second, "超过 max_output_length 应失败。")
	assert_eq(context.get_report().get_error_count(), 2, "缺失变量和输出超限都应进入报告。")


func test_replace_tokens_enforces_output_limit() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"name": "abcdef",
	}, {
		"max_output_length": 5,
	})

	var output: String = context.replace_tokens("{{ name }}")

	assert_eq(output, "", "token 替换结果超过输出上限时不应返回超限文本。")
	assert_false(context.get_report().is_ok(), "replace_tokens 超限应写入诊断报告。")


func test_budget_stops_token_replacement() -> void:
	var budget: GFExecutionBudget = GFExecutionBudget.new({
		"max_steps": 1,
	})
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"a": "A",
		"b": "B",
	}, {
		"budget": budget,
	})

	var output: String = context.replace_tokens("{{ a }} {{ b }}")

	assert_true(output.contains("A"), "预算耗尽前的 token 应被替换。")
	assert_false(context.get_report().is_ok(), "预算耗尽应合并到上下文报告。")
