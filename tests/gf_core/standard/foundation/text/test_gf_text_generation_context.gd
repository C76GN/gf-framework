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


func test_replace_tokens_reads_packed_array_indices() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"names": PackedStringArray(["Ada", "Grace"]),
		"scores": PackedInt32Array([7, 9]),
		"bytes": PackedByteArray([65, 66]),
		"points": PackedVector4Array([Vector4(1, 2, 3, 4)]),
	}, {
		"strict_variables": true,
	})

	var output: String = context.replace_tokens("{{ names.1 }} scored {{ scores.1 }} with byte {{ bytes.0 }}.")
	var point_value: Vector4 = context.get_value("points.0", Vector4.ZERO)

	assert_eq(output, "Grace scored 9 with byte 65.", "token 路径应支持 PackedArray 数字下标。")
	assert_eq(point_value, Vector4(1, 2, 3, 4), "get_value() 应支持 PackedVector4Array 下标。")
	assert_false(context.has_value("names.9"), "越界 PackedArray 下标应视为缺失。")
	assert_true(context.get_report().is_ok(), "有效 PackedArray 下标不应产生诊断。")


func test_replace_tokens_uses_value_formatter() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"name": "Ada",
		"score": 7,
	}, {
		"metadata": {
			"prefix": "token",
		},
	})

	var output: String = context.replace_tokens("{{ name }};{{ score }}", {
		"value_formatter": Callable(self, "_format_token_for_test"),
	})

	assert_eq(output, "token:name=Ada;token:score=7", "value_formatter 应接收 token 上下文并决定最终文本。")
	assert_true(context.get_report().is_ok(), "有效 value_formatter 不应产生诊断。")


func test_replace_tokens_reports_invalid_value_formatter() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"name": "Ada",
	})

	var output: String = context.replace_tokens("{{ name }}", {
		"value_formatter": Callable(),
	})

	assert_eq(output, "Ada", "无效 formatter 应回退到默认文本转换。")
	assert_false(context.get_report().is_ok(), "无效 formatter 应进入诊断报告。")
	assert_eq(context.get_report().get_error_count(), 1, "无效 formatter 应产生一个错误。")


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


func test_configure_resets_previous_options_on_reused_context() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({}, {
		"strict_variables": true,
		"max_output_length": 1,
		"indent_text": "  ",
		"metadata": {
			"owner": "first",
		},
	})

	var _reconfigured: GFTextGenerationContext = context.configure({
		"name": "Ada",
	})
	var output: String = context.replace_tokens("{{ missing }}", {
		"missing_text": "?",
	})

	assert_eq(output, "?", "重新 configure 后缺失 token 应按非 strict 默认处理。")
	assert_true(context.get_report().is_ok(), "空 options 重新配置后不应继承 strict 错误策略。")
	assert_eq(context.max_output_length, 0, "空 options 重新配置应重置输出上限。")
	assert_eq(context.indent_text, "\t", "空 options 重新配置应重置缩进文本。")
	assert_true(context.metadata.is_empty(), "空 options 重新配置应重置 metadata。")


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


func test_render_template_repeats_array_items_with_loop_metadata() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": [
			{ "name": "Potion" },
			{ "name": "Ether" },
		],
	})

	var output: String = context.render_template("Items:\n{{ for item in items }}{{ loop.number }}. {{ item.name }}\n{{ end }}Done")

	assert_eq(output, "Items:\n1. Potion\n2. Ether\nDone", "模板循环应按数组顺序渲染条目。")
	assert_true(context.get_report().is_ok(), "有效循环模板不应产生诊断。")


func test_render_template_repeats_additional_packed_array_items() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"bytes": PackedByteArray([1, 2, 3]),
		"points": PackedVector4Array([Vector4.ONE, Vector4.ZERO]),
	})

	var byte_output: String = context.render_template("{{ for byte in bytes }}{{ byte }} {{ end }}")
	var point_output: String = context.render_template("{{ for point in points }}{{ loop.number }}/{{ loop.count }} {{ end }}")

	assert_eq(byte_output, "1 2 3 ", "模板循环应支持 PackedByteArray。")
	assert_eq(point_output, "1/2 2/2 ", "模板循环应支持 PackedVector4Array。")
	assert_true(context.get_report().is_ok(), "有效 PackedArray 循环不应产生诊断。")


func test_render_template_passes_value_formatter_to_loop_tokens() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": [
			{ "name": "Potion" },
			{ "name": "Ether" },
		],
	})

	var output: String = context.render_template("{{ for item in items }}{{ item.name }}:{{ loop.number }};{{ end }}", {
		"value_formatter": Callable(self, "_wrap_token_for_test"),
	})

	assert_eq(output, "[item.name=Potion]:[loop.number=1];[item.name=Ether]:[loop.number=2];", "render_template 应把 formatter 传递给循环体 token。")
	assert_true(context.get_report().is_ok(), "循环体 formatter 不应破坏模板诊断。")


func test_render_template_supports_nested_loops() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"groups": [
			{
				"name": "A",
				"items": ["one", "two"],
			},
			{
				"name": "B",
				"items": ["three"],
			},
		],
	})

	var output: String = context.render_template("{{ for group in groups }}{{ group.name }}:{{ for item in group.items }} {{ item }}{{ end }}\n{{ end }}")

	assert_eq(output, "A: one two\nB: three\n", "嵌套循环应使用各自 scope 渲染。")
	assert_true(context.get_report().is_ok(), "有效嵌套循环不应产生诊断。")


func test_render_template_ignores_comment_directives() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"name": "Ada",
		"items": ["one", "two"],
	})

	var output: String = context.render_template(
		"Hello{{ comment generated marker }} {{ name }}" +
		"{{ for item in items }}{{ comment current item }}:{{ item }}{{ end }}" +
		"{{ comment }}."
	)

	assert_eq(output, "Hello Ada:one:two.", "comment 指令应从模板输出中移除，且不影响普通 token 和循环 scope。")
	assert_true(context.get_report().is_ok(), "有效 comment 指令不应产生诊断。")


func test_render_template_enforces_replacement_limit_across_fragments() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"a": "A",
		"b": "B",
	})

	var output: String = context.render_template("{{ a }}{{ comment split }}{{ b }}", {
		"max_replacements": 1,
	})
	var issue_counts: Dictionary = context.get_report().get_issue_counts_by_kind()

	assert_eq(output, "A{{ b }}", "comment 分片不能重置一次 render 的 replacement 预算。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "replacement_limit_exceeded"), 1, "超出全局替换预算应只写入一个稳定 issue。")


func test_render_template_renders_empty_blocks_for_falsey_data() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": [],
		"lookup": {},
		"title": "",
		"enabled": false,
		"packed": PackedStringArray(),
	})

	var output: String = context.render_template(
		"{{ empty items }}items{{ end_empty }}|" +
		"{{ empty lookup }}lookup{{ end_empty }}|" +
		"{{ empty title }}title{{ end_empty }}|" +
		"{{ empty enabled }}disabled{{ end_empty }}|" +
		"{{ empty packed }}packed{{ end_empty }}"
	)

	assert_eq(output, "items|lookup|title|disabled|packed", "empty 块应覆盖空集合、空文本和 false。")
	assert_true(context.get_report().is_ok(), "有效 empty 块不应产生诊断。")


func test_render_template_skips_empty_blocks_for_present_data() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": ["Potion"],
		"lookup": { "id": 1 },
		"title": "Shop",
		"enabled": true,
		"count": 0,
	})

	var output: String = context.render_template(
		"{{ empty items }}items{{ end_empty }}|" +
		"{{ empty lookup }}lookup{{ end_empty }}|" +
		"{{ empty title }}title{{ end_empty }}|" +
		"{{ empty enabled }}disabled{{ end_empty }}|" +
		"{{ empty count }}zero{{ end_empty }}done"
	)

	assert_eq(output, "||||done", "非空集合、非空文本、true 和数字 0 不应触发 empty 块。")
	assert_true(context.get_report().is_ok(), "跳过 empty 块不应产生诊断。")


func test_render_template_supports_empty_blocks_inside_loops() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"groups": [
			{
				"name": "A",
				"items": [],
			},
			{
				"name": "B",
				"items": ["one", "two"],
			},
		],
	})

	var output: String = context.render_template(
		"{{ for group in groups }}" +
		"{{ group.name }}:" +
		"{{ empty group.items }}none{{ end_empty }}" +
		"{{ for item in group.items }}{{ item }} {{ end }};" +
		"{{ end }}"
	)

	assert_eq(output, "A:none;B:one two ;", "empty 块应在循环 scope 内读取当前项路径。")
	assert_true(context.get_report().is_ok(), "循环内 empty 块不应产生诊断。")


func test_render_template_reports_missing_empty_end() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": [],
	})

	var output: String = context.render_template("{{ empty items }}No items")

	assert_eq(output, "", "缺少 end_empty 的空态块不应输出不完整块。")
	assert_false(context.get_report().is_ok(), "缺少 end_empty 应进入诊断报告。")
	assert_eq(context.get_report().get_error_count(), 1, "缺少 end_empty 应产生一个错误。")


func test_render_template_reports_strict_missing_empty_path() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({}, {
		"strict_variables": true,
	})

	var output: String = context.render_template("{{ empty missing }}Fallback{{ end_empty }}")

	assert_eq(output, "Fallback", "缺失路径可作为空态渲染，但 strict 模式应保留诊断。")
	assert_false(context.get_report().is_ok(), "strict 模式下缺失 empty 路径应进入诊断。")
	assert_eq(context.get_report().get_error_count(), 1, "缺失 empty 路径应产生一个错误。")


func test_render_template_reports_missing_loop_end() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": ["one"],
	})

	var output: String = context.render_template("{{ for item in items }}{{ item }}")

	assert_eq(output, "", "缺少 end 的循环不应输出不完整块。")
	assert_false(context.get_report().is_ok(), "缺少 end 应进入诊断报告。")
	assert_eq(context.get_report().get_error_count(), 1, "缺少 end 应产生一个错误。")


func test_render_template_reports_non_iterable_loop_source() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"item": "Potion",
	})

	var output: String = context.render_template("{{ for entry in item }}{{ entry }}{{ end }}")

	assert_eq(output, "", "非数组循环来源不应渲染。")
	assert_false(context.get_report().is_ok(), "非数组循环来源应进入诊断报告。")


func test_render_template_enforces_loop_item_limit() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": ["one", "two", "three"],
	})

	var output: String = context.render_template("{{ for item in items }}{{ item }}{{ end }}", {
		"max_loop_items": 2,
	})

	assert_eq(output, "", "超过循环项上限时不应渲染循环体。")
	assert_false(context.get_report().is_ok(), "超过循环项上限应进入诊断报告。")


func test_render_template_enforces_output_limit_across_loop_iterations() -> void:
	var context: GFTextGenerationContext = GFTextGenerationContext.new({
		"items": ["one", "two", "three"],
	}, {
		"max_output_length": 4,
	})

	var output: String = context.render_template("{{ for item in items }}xx{{ end }}")

	assert_eq(output, "xxxx", "循环累积输出超限时应保留已验证的前缀。")
	assert_false(context.get_report().is_ok(), "循环累积输出超限应进入诊断报告。")


func _format_token_for_test(format_context: Dictionary) -> Variant:
	var data_path: String = GFVariantData.get_option_string(format_context, "path")
	var token_value: Variant = GFVariantData.get_option_value(format_context, "value")
	var fallback_text: String = GFVariantData.get_option_string(format_context, "fallback_text")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(format_context, "metadata")
	var prefix_text: String = GFVariantData.get_option_string(metadata, "prefix", "token")
	return "%s:%s=%s" % [prefix_text, data_path, GFVariantData.to_text(token_value, fallback_text)]


func _wrap_token_for_test(format_context: Dictionary) -> Variant:
	var data_path: String = GFVariantData.get_option_string(format_context, "path")
	var token_value: Variant = GFVariantData.get_option_value(format_context, "value")
	var fallback_text: String = GFVariantData.get_option_string(format_context, "fallback_text")
	return "[%s=%s]" % [data_path, GFVariantData.to_text(token_value, fallback_text)]
