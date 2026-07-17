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
	})
	assert_true(loader.register_text("dialogue.finish", JSON.stringify(source)), "内存来源应注册成功。")
	var compiler: GF_DIALOGUE_TEXT_COMPILER_SCRIPT = GF_DIALOGUE_TEXT_COMPILER_SCRIPT.new()

	var result: Dictionary = compiler.compile_source("dialogue.finish", loader)

	assert_true(GFVariantData.get_option_bool(result, "success"), "编译器应复用受约束源码加载器。")
	assert_eq(GFVariantData.get_option_string(result, "source_path"), "dialogue.finish", "结果应保留逻辑来源。")
	assert_eq(GFVariantData.get_option_int(result, "line_count"), 1, "加载来源应构建全部对话行。")


# --- 私有/辅助方法 ---

func _has_issue_kind(issues: Array, expected_kind: StringName) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == expected_kind:
			return true
	return false
