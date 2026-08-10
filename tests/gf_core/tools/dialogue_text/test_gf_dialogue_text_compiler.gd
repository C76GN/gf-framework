## 测试 GFDialogueTextCompiler 的严格文本编译和源码加载边界。
extends GutTest

# --- 常量 ---

const GF_DIALOGUE_TEXT_COMPILER_SCRIPT = preload("res://addons/gf/tools/dialogue_text/gf_dialogue_text_compiler.gd")


# --- 测试方法 ---

func test_compiler_builds_dialogue_resource_from_json_text() -> void:
	var source: Dictionary = {
		"format": GF_DIALOGUE_TEXT_COMPILER_SCRIPT.SOURCE_FORMAT,
		"schema_version": GF_DIALOGUE_TEXT_COMPILER_SCRIPT.SOURCE_SCHEMA_VERSION,
		"start_line_id": "intro",
		"metadata": { "chapter": "prologue" },
		"lines": [
			{
				"line_id": "intro",
				"kind": "text",
				"speaker_id": "guide",
				"text": "dialogue.intro",
				"responses": [
					{
						"response_id": "continue",
						"text": "dialogue.continue",
						"next_line_id": "finish",
					},
				],
			},
			{
				"line_id": "finish",
				"kind": "end",
			},
		],
	}
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_text(JSON.stringify(source), {
		"source_path": "res://dialogue/prologue.gf_dialogue.json",
	})
	var resource_value: Variant = GFVariantData.get_option_value(result, "resource")

	assert_true(GFVariantData.get_option_bool(result, "success"), "合法文本应编译成功。")
	assert_true(resource_value is GFDialogueResource, "成功结果应包含 GFDialogueResource。")
	if not (resource_value is GFDialogueResource):
		return
	var resource: GFDialogueResource = resource_value
	var intro: GFDialogueLine = resource.get_line(&"intro")
	assert_eq(resource.start_line_id, &"intro", "编译器应保留起始行。")
	assert_eq(resource.lines.size(), 2, "编译器应构建全部行。")
	assert_not_null(intro, "文本行应可按 ID 获取。")
	assert_eq(intro.speaker_id, &"guide", "编译器应保留抽象 speaker_id。")
	assert_eq(intro.responses[0].next_line_id, &"finish", "响应应保留后继行。")


func test_compiler_reports_json_source_line_and_fails_closed() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_text("{\n  \"format\": \"gf.dialogue\",\n  invalid\n}", {
		"source_path": "res://dialogue/broken.gf_dialogue.json",
	})
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}
	var source_span: Dictionary = GFVariantData.get_option_dictionary(first_issue, "source_span")
	var failed_resource_value: Variant = result.get("resource")

	assert_false(GFVariantData.get_option_bool(result, "success"), "非法 JSON 必须编译失败。")
	assert_true(failed_resource_value == null, "失败结果不得暴露半成品资源。")
	assert_eq(GFVariantData.get_option_string_name(first_issue, "kind"), &"invalid_json", "报告应区分 JSON 语法错误。")
	assert_gt(GFVariantData.get_option_int(source_span, "line"), 0, "JSON 语法错误应保留源码行号。")


func test_compiler_rejects_unknown_structure_fields_and_missing_targets() -> void:
	var source: Dictionary = {
		"format": "gf.dialogue",
		"schema_version": 1,
		"start_line_id": "intro",
		"lines": [
			{
				"line_id": "intro",
				"kind": "text",
				"next_line_id": "missing",
				"quest_id": "business_data_must_use_metadata",
			},
		],
	}
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_text(JSON.stringify(source))
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "未知结构字段或缺失跳转目标应阻断产物。")
	assert_true(_has_issue_kind(issues, &"unknown_field"), "未知字段应提示改用 metadata。")
	assert_true(_has_issue_kind(issues, &"missing_next_line"), "运行时资源校验问题应合并进编译报告。")


func test_compiler_rejects_fractional_schema_version_near_integer() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var source: String = (
		'{"format":"gf.dialogue","schema_version":1.000001,'
		+ '"lines":[{"line_id":"finish","kind":"end"}]}'
	)

	var result: Dictionary = compiler.compile_text(source)
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(result, "success"), "schema 版本必须是精确整数。")
	assert_true(_has_issue_kind(issues, &"unsupported_schema_version"), "近似整数不得绕过 schema 版本门禁。")


func test_compiler_loads_registered_source_text() -> void:
	var source: Dictionary = {
		"format": "gf.dialogue",
		"schema_version": 1,
		"lines": [
			{
				"line_id": "finish",
				"kind": "end",
			},
		],
	}
	var loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
		"max_bytes": 4096,
	})
	assert_true(loader.register_text("dialogue.finish", JSON.stringify(source)), "内存来源应注册成功。")
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_source("dialogue.finish", loader)

	assert_true(GFVariantData.get_option_bool(result, "success"), "编译器应复用受约束源码加载器。")
	assert_eq(GFVariantData.get_option_string(result, "source_path"), "dialogue.finish", "结果应保留逻辑来源。")
	assert_eq(GFVariantData.get_option_int(result, "line_count"), 1, "加载来源应构建全部对话行。")


func test_compiler_rejects_non_strict_json_dialect_before_materialization() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var cases: Array[Dictionary] = [
		{
			"name": "trailing comma",
			"source": '{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"finish","kind":"end",}],}',
			"kind": &"invalid_json",
		},
		{
			"name": "duplicate member",
			"source": '{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"first","line_id":"second","kind":"end"}]}',
			"kind": &"duplicate_field",
		},
		{
			"name": "raw newline in string",
			"source": "{\"format\":\"gf.dialogue\",\"schema_version\":1,\"lines\":[{\"line_id\":\"finish\",\"kind\":\"end\",\"text\":\"raw\nnewline\"}]}",
			"kind": &"invalid_json",
		},
		{
			"name": "non finite number",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"weight":1e99999},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"non_finite_number",
		},
		{
			"name": "underflowing nonzero number",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"weight":1e-99999},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"non_finite_number",
		},
		{
			"name": "subnormal number outside documented domain",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"weight":1e-308},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"non_finite_number",
		},
		{
			"name": "number just above maximum finite float",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"weight":1.7976931348623158e308},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"non_finite_number",
		},
		{
			"name": "integer outside int64",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"count":9223372036854775808},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"number_out_of_range",
		},
		{
			"name": "leading zero",
			"source": '{"format":"gf.dialogue","schema_version":1,"metadata":{"count":01},"lines":[{"line_id":"finish","kind":"end"}]}',
			"kind": &"invalid_json",
		},
		{
			"name": "unpaired high surrogate",
			"source": '{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"finish","kind":"end","text":"\\uD800"}]}',
			"kind": &"invalid_unicode_escape",
		},
		{
			"name": "unpaired low surrogate",
			"source": '{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"finish","kind":"end","text":"\\uDC00"}]}',
			"kind": &"invalid_unicode_escape",
		},
	]

	for case_data: Dictionary in cases:
		var result: Dictionary = compiler.compile_text(GFVariantData.get_option_string(case_data, "source"))
		var issues: Array = _get_issues(result)
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			"严格 JSON 应拒绝：%s。" % GFVariantData.get_option_string(case_data, "name")
		)
		assert_true(
			result.get("resource") == null,
			"严格 JSON 失败不得暴露资源：%s。" % GFVariantData.get_option_string(case_data, "name")
		)
		assert_true(
			_has_issue_kind(issues, GFVariantData.get_option_string_name(case_data, "kind")),
			"严格 JSON 失败 kind 应稳定：%s。" % GFVariantData.get_option_string(case_data, "name")
		)

	var duplicate_result: Dictionary = compiler.compile_text(
		'{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"first","line_id":"second","kind":"end"}]}'
	)
	var duplicate_issue: Dictionary = _find_issue(_get_issues(duplicate_result), &"duplicate_field")
	var duplicate_metadata: Dictionary = GFVariantData.get_option_dictionary(duplicate_issue, "metadata")
	assert_eq(
		GFVariantData.get_option_array(duplicate_metadata, "related_source_spans").size(),
		2,
		"重复 JSON member 必须同时保留首次与冲突 token。"
	)


func test_compiler_preserves_valid_unicode_and_finite_float_boundaries() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var source: String = (
		'{"format":"gf.dialogue","schema_version":1,'
		+ '"metadata":{"emoji":"\\uD83D\\uDE00","max_float":1.7976931348623157e308,'
		+ '"min_float":1e-307,"zero":0e99999},'
		+ '"lines":[{"line_id":"finish","kind":"end","text":"é · שלום"}]}'
	)

	var result: Dictionary = compiler.compile_text(source)
	var resource_value: Variant = GFVariantData.get_option_value(result, "resource")

	assert_true(GFVariantData.get_option_bool(result, "success"), "合法 Unicode 与有限浮点边界应编译成功。")
	assert_true(resource_value is GFDialogueResource, "成功结果应返回 Dialogue Resource。")
	if not (resource_value is GFDialogueResource):
		return
	var resource: GFDialogueResource = resource_value
	assert_eq(GFVariantData.get_option_string(resource.metadata, "emoji"), "😀", "代理对必须无损还原为非 BMP 字符。")
	var max_float: float = GFVariantData.get_option_float(resource.metadata, "max_float")
	var min_float: float = GFVariantData.get_option_float(resource.metadata, "min_float")
	assert_false(is_inf(max_float) or is_nan(max_float), "最大有限浮点不得溢出。")
	assert_gt(max_float, 1.0e308, "最大有限浮点应保留数量级。")
	assert_gt(min_float, 0.0, "受支持的最小数量级不得静默下溢为零。")
	assert_eq(GFVariantData.get_option_float(resource.metadata, "zero", 1.0), 0.0, "零值允许任意合法十进制指数。")
	assert_eq(resource.lines[0].text, "é · שלום", "组合字符与 RTL 文本必须逐码点保留。")


func test_compiler_enforces_text_line_response_and_structure_budgets() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var minimal_source: String = JSON.stringify(_make_linear_dialogue_source(1))
	var three_lines_source: String = JSON.stringify(_make_linear_dialogue_source(3))
	var line_result: Dictionary = compiler.compile_text(three_lines_source, { "max_lines": 2 })
	var text_byte_count: int = three_lines_source.to_utf8_buffer().size()
	var text_result: Dictionary = compiler.compile_text(
		three_lines_source,
		{ "max_text_bytes": text_byte_count - 1 }
	)
	var response_source: Dictionary = _make_linear_dialogue_source(1)
	var response_lines: Array = GFVariantData.get_option_array(response_source, "lines")
	var response_line: Dictionary = GFVariantData.as_dictionary(response_lines[0])
	response_line["responses"] = [
		{ "response_id": "a", "text": "A" },
		{ "response_id": "b", "text": "B" },
	]
	response_lines[0] = response_line
	response_source["lines"] = response_lines
	var response_result: Dictionary = compiler.compile_text(
		JSON.stringify(response_source),
		{ "max_responses": 1 }
	)
	var depth_result: Dictionary = compiler.compile_text(minimal_source, { "max_depth": 2 })
	var node_result: Dictionary = compiler.compile_text(minimal_source, { "max_nodes": 13 })
	var string_result: Dictionary = compiler.compile_text(minimal_source, { "max_string_bytes": 13 })

	var budget_results: Array[Dictionary] = [
		line_result,
		text_result,
		response_result,
		depth_result,
		node_result,
		string_result,
	]
	for result: Dictionary in budget_results:
		assert_false(GFVariantData.get_option_bool(result, "success"), "输入预算超限必须失败关闭。")
		assert_true(result.get("resource") == null, "输入预算超限不得暴露半成品资源。")
		assert_eq(GFVariantData.get_option_int(result, "line_count"), 0, "失败结果的 line_count 必须保持原子产物语义。")
		assert_true(_has_issue_kind(_get_issues(result), &"input_budget_exceeded"), "预算错误 kind 应稳定。")

	var exact_budget_results: Array[Dictionary] = [
		compiler.compile_text(three_lines_source, { "max_lines": 3 }),
		compiler.compile_text(three_lines_source, { "max_text_bytes": text_byte_count }),
		compiler.compile_text(JSON.stringify(response_source), { "max_responses": 2 }),
		compiler.compile_text(minimal_source, { "max_depth": 3 }),
		compiler.compile_text(minimal_source, { "max_nodes": 14 }),
		compiler.compile_text(minimal_source, { "max_string_bytes": 14 }),
	]
	for result: Dictionary in exact_budget_results:
		assert_true(GFVariantData.get_option_bool(result, "success"), "预算阈值本身必须保持可用。")


func test_compiler_bounds_diagnostics_and_rejects_invalid_limit_options() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var diagnostic_source: String = (
		'{"format":"gf.dialogue","schema_version":1,"unknown_a":1,"unknown_b":2,'
		+ '"unknown_c":3,"lines":[{"line_id":"finish","kind":"end"}]}'
	)
	var diagnostic_result: Dictionary = compiler.compile_text(
		diagnostic_source,
		{ "max_diagnostics": 2 }
	)
	var diagnostic_issues: Array = _get_issues(diagnostic_result)
	assert_eq(diagnostic_issues.size(), 2, "诊断总数必须受 max_diagnostics 硬约束。")
	assert_eq(
		GFVariantData.get_option_string_name(GFVariantData.as_dictionary(diagnostic_issues[-1]), "kind"),
		&"diagnostic_budget_exceeded",
		"最后一个诊断槽应明确说明截断原因。"
	)

	var invalid_options: Array[Dictionary] = [
		{ "max_lines": 0 },
		{ "max_lines": -1 },
		{ "max_depth": 65 },
		{ "max_nodes": 1.5 },
		{ "max_responses": true },
	]
	for options: Dictionary in invalid_options:
		var result: Dictionary = compiler.compile_text(diagnostic_source, options)
		assert_false(GFVariantData.get_option_bool(result, "success"), "非法预算选项必须失败关闭。")
		assert_true(_has_issue_kind(_get_issues(result), &"invalid_compile_option"), "非法预算选项应返回稳定 kind。")


func test_compile_source_requires_loader_read_budget_no_larger_than_compile_budget() -> void:
	var source: String = JSON.stringify(_make_linear_dialogue_source(1))
	var unbounded_loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
	})
	var _registered_unbounded: bool = unbounded_loader.register_text("dialogue.finish", source)
	var oversized_loader: GFSourceTextLoader = GFSourceTextLoader.new("", {
		"allow_file_access": false,
		"max_bytes": 8192,
	})
	var _registered_oversized: bool = oversized_loader.register_text("dialogue.finish", source)
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var unbounded_result: Dictionary = compiler.compile_source("dialogue.finish", unbounded_loader)
	var oversized_result: Dictionary = compiler.compile_source(
		"dialogue.finish",
		oversized_loader,
		{ "max_text_bytes": 4096 }
	)

	var loader_results: Array[Dictionary] = [unbounded_result, oversized_result]
	for result: Dictionary in loader_results:
		assert_false(GFVariantData.get_option_bool(result, "success"), "loader 必须先建立不大于编译预算的读取上限。")
		assert_true(_has_issue_kind(_get_issues(result), &"unsafe_source_loader_budget"), "loader 预算拒绝 kind 应稳定。")


func test_compiler_semantic_issues_preserve_json_pointer_and_source_spans() -> void:
	var source: String = """{
  \"format\": \"gf.dialogue\",
  \"schema_version\": 1,
  \"lines\": [
    {
      \"line_id\": \"duplicate\",
      \"kind\": \"text\",
      \"unknown.field[0]~/value\": true
    },
    {
      \"line_id\": \"duplicate\",
      \"kind\": \"text\",
      \"next_line_id\": \"missing\"
    }
  ]
}"""
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_text(source, {
		"source_path": "res://dialogue/provenance.gf_dialogue.json",
	})
	var issues: Array = _get_issues(result)
	var unknown_issue: Dictionary = _find_issue(issues, &"unknown_field")
	var duplicate_issue: Dictionary = _find_issue(issues, &"duplicate_line_id")
	var missing_issue: Dictionary = _find_issue(issues, &"missing_next_line")

	assert_false(GFVariantData.get_option_bool(result, "success"), "语义错误必须阻断产物。")
	assert_eq(
		GFVariantData.get_option_string(unknown_issue, "path"),
		"#/lines/0/unknown.field%5B0%5D~0~1value",
		"特殊字段名应使用无歧义、日志安全的 URI fragment JSON Pointer。"
	)
	var semantic_issues: Array[Dictionary] = [unknown_issue, duplicate_issue, missing_issue]
	for issue: Dictionary in semantic_issues:
		var span: Dictionary = GFVariantData.get_option_dictionary(issue, "source_span")
		assert_gt(GFVariantData.get_option_int(span, "line"), 0, "语义错误应保留源码行号。")
		assert_gt(GFVariantData.get_option_int(span, "column"), 0, "语义错误应保留源码列号。")
		assert_true(GFVariantData.get_option_string(issue, "path").begins_with("#/lines/"), "语义路径应是 JSON Pointer。")
	var duplicate_metadata: Dictionary = GFVariantData.get_option_dictionary(duplicate_issue, "metadata")
	assert_eq(
		GFVariantData.get_option_array(duplicate_metadata, "related_source_spans").size(),
		2,
		"重复 ID 应同时定位首次与冲突声明。"
	)
	assert_eq(GFVariantData.get_option_int(result, "line_count"), 0, "语义失败不得报告已产出行数。")
	assert_eq(
		GFVariantData.get_option_string(GFVariantData.get_option_dictionary(duplicate_issue, "source_span"), "source_path"),
		"res://dialogue/provenance.gf_dialogue.json",
		"本地制作期报告必须保留可跳转的逻辑来源路径。"
	)


func test_compiler_maps_repeated_runtime_issues_to_distinct_source_tokens() -> void:
	var source: String = """{
  \"format\": \"gf.dialogue\",
  \"schema_version\": 1,
  \"lines\": [
    {
      \"line_id\": \"choice\",
      \"kind\": \"text\",
      \"next_line_id\": \"missing\",
      \"responses\": [
        {\"response_id\": \"same\", \"next_line_id\": \"missing\"},
        {\"response_id\": \"same\"}
      ]
    }
  ]
}"""
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_text(source)
	var issues: Array = _get_issues(result)
	var missing_issues: Array[Dictionary] = _find_issues(issues, &"missing_next_line")
	var duplicate_issue: Dictionary = _find_issue(issues, &"duplicate_response_id")

	assert_eq(missing_issues.size(), 2, "同一目标的两个缺失引用必须各自保留诊断。")
	if missing_issues.size() == 2:
		assert_eq(
			GFVariantData.get_option_string(missing_issues[0], "path"),
			"#/lines/0/next_line_id",
			"首个缺失引用应定位行级字段。"
		)
		assert_eq(
			GFVariantData.get_option_string(missing_issues[1], "path"),
			"#/lines/0/responses/0/next_line_id",
			"第二个缺失引用应定位响应字段，而不是复用首个位置。"
		)
	assert_eq(
		GFVariantData.get_option_string(duplicate_issue, "path"),
		"#/lines/0/responses/1/response_id",
		"重复响应 ID 应定位冲突声明。"
	)
	assert_eq(
		GFVariantData.get_option_array(
			GFVariantData.get_option_dictionary(duplicate_issue, "metadata"),
			"related_source_spans"
		).size(),
		2,
		"重复响应 ID 应保留两处声明位置。"
	)


func test_compiler_preserves_runtime_owned_next_action() -> void:
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var result: Dictionary = compiler.compile_text(
		'{"format":"gf.dialogue","schema_version":1,"lines":[{"line_id":"start","kind":"text","next_line_id":"missing"}]}'
	)
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")

	assert_eq(
		GFVariantData.get_option_string(report, "next_action"),
		"Create the referenced dialogue line or update the transition id.",
		"仅含 runtime 校验问题时应保留 runtime owner 给出的具体修复建议。"
	)


func test_compiler_reports_are_deterministic_and_crlf_aware() -> void:
	var source: String = (
		"{\r\n"
		+ "  \"format\": \"gf.dialogue\",\r\n"
		+ "  \"schema_version\": 1,\r\n"
		+ "  \"lines\": [\r\n"
		+ "    {\"line_id\": \"finish\", \"kind\": \"end\", \"非法/field\": true}\r\n"
		+ "  ]\r\n"
		+ "}"
	)
	var options: Dictionary = { "source_path": "res://dialogue/deterministic.gf_dialogue.json" }
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var first: Dictionary = compiler.compile_text(source, options)
	var second: Dictionary = compiler.compile_text(source, options)
	var first_report: Dictionary = GFVariantData.get_option_dictionary(first, "report")
	var second_report: Dictionary = GFVariantData.get_option_dictionary(second, "report")
	var issue: Dictionary = _find_issue(GFVariantData.get_option_array(first_report, "issues"), &"unknown_field")
	var span: Dictionary = GFVariantData.get_option_dictionary(issue, "source_span")

	assert_eq(first_report, second_report, "相同输入与选项必须产生完全稳定的报告投影。")
	assert_eq(
		GFVariantData.get_option_string(first, "content_hash"),
		GFVariantData.get_option_string(second, "content_hash"),
		"相同 source bytes 必须产生稳定 content_hash。"
	)
	assert_eq(GFVariantData.get_option_int(span, "line"), 5, "CRLF 必须按一个逻辑换行计算来源行号。")
	assert_eq(
		GFVariantData.get_option_string(issue, "path"),
		"#/lines/0/%E9%9D%9E%E6%B3%95~1field",
		"非 ASCII 与斜杠字段名必须稳定编码为 URI fragment JSON Pointer。"
	)


func test_compiler_report_projection_is_json_safe_and_has_specific_next_actions() -> void:
	var unsafe_object: RefCounted = RefCounted.new()
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()
	var result: Dictionary = compiler.compile_text('{"format":"gf.dialogue","schema_version":1,"lines":"bad"}', {
		"source_path": "res://dialogue/report.gf_dialogue.json",
		"metadata": {
			"object": unsafe_object,
			"not_a_number": NAN,
			"cycle": cyclic_metadata,
			"bytes": PackedByteArray([1, 2, 3]),
		},
	})
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")

	assert_false(_contains_unsafe_json_value(report, []), "编译报告投影不得包含 Object、循环或非有限浮点。")
	assert_ne(
		GFVariantData.get_option_string(report, "next_action"),
		"Review the first reported issue.",
		"compiler 自有错误应由稳定 issue catalog 提供具体 next action。"
	)
	var encoded: String = JSON.stringify(report)
	assert_true(JSON.parse_string(encoded) is Dictionary, "JSON-safe 报告应可真实 stringify/parse 往返。")


# --- 私有/辅助方法 ---

func _has_issue_kind(issues: Array, expected_kind: StringName) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == expected_kind:
			return true
	return false


func _get_issues(result: Dictionary) -> Array:
	return GFVariantData.get_option_array(GFVariantData.get_option_dictionary(result, "report"), "issues")


func _find_issue(issues: Array, expected_kind: StringName) -> Dictionary:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == expected_kind:
			return issue
	return {}


func _find_issues(issues: Array, expected_kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == expected_kind:
			result.append(issue)
	return result


func _make_linear_dialogue_source(line_count: int) -> Dictionary:
	var lines: Array[Dictionary] = []
	for index: int in range(line_count):
		var line: Dictionary = {
			"line_id": "line_%d" % index,
			"kind": "end" if index == line_count - 1 else "jump",
		}
		if index < line_count - 1:
			line["jump_line_id"] = "line_%d" % (index + 1)
		lines.append(line)
	return {
		"format": "gf.dialogue",
		"schema_version": 1,
		"start_line_id": "line_0",
		"lines": lines,
	}


func _contains_unsafe_json_value(value: Variant, visited: Array[Variant] = []) -> bool:
	if value is float:
		var number: float = value
		return is_nan(number) or is_inf(number)
	if value is Object:
		return true
	if value is Array:
		var array_value: Array = value
		if _contains_same_value(visited, array_value):
			return true
		visited.append(array_value)
		for item: Variant in array_value:
			if _contains_unsafe_json_value(item, visited):
				return true
		return false
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if _contains_same_value(visited, dictionary_value):
			return true
		visited.append(dictionary_value)
		for key_value: Variant in dictionary_value.keys():
			if not (key_value is String) or _contains_unsafe_json_value(dictionary_value[key_value], visited):
				return true
	return false


func _contains_same_value(values: Array[Variant], candidate: Variant) -> bool:
	for value: Variant in values:
		if is_same(value, candidate):
			return true
	return false
