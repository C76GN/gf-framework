## 测试 GFScriptStructureTools 的脚本结构描述和契约检查能力。
extends GutTest

const SAMPLE_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/script_structure/gf_script_structure_sample.gd"
const CHILD_SCRIPT_PATH: String = "res://tests/gf_core/fixtures/script_structure/subdir/gf_script_structure_child.gd"


func test_describe_script_reports_public_members_without_private_members() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var report: Dictionary = GFScriptStructureTools.describe_script(target_script)
	var constants: Array = GFVariantData.get_option_array(report, "constants")
	var methods: Array = GFVariantData.get_option_array(report, "methods")
	var properties: Array = GFVariantData.get_option_array(report, "properties")
	var signals: Array = GFVariantData.get_option_array(report, "signals")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "脚本描述不应失败。")
	assert_eq(GFVariantData.get_option_string(report, "script_path"), SAMPLE_SCRIPT_PATH, "应记录脚本路径。")
	assert_eq(GFVariantData.get_option_string(report, "instance_base_type"), "RefCounted", "应记录 Godot 实例基类。")
	assert_true(_has_named_record(constants, "SAMPLE_ID"), "应包含公开常量。")
	assert_true(_has_named_record(methods, "apply_delta"), "应包含公开方法。")
	assert_false(_has_named_record(methods, "_hidden_method"), "默认不应暴露私有方法。")
	assert_true(_has_named_record(properties, "public_value"), "应包含脚本变量属性。")
	assert_false(_has_named_record(properties, "_private_value"), "默认不应暴露私有属性。")
	assert_true(_has_named_record(signals, "sample_changed"), "应包含公开信号。")


func test_describe_script_can_include_private_members_and_constant_values() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var report: Dictionary = GFScriptStructureTools.describe_script(target_script, {
		"include_private_members": true,
		"include_constant_values": true,
	})
	var constants: Array = GFVariantData.get_option_array(report, "constants")
	var methods: Array = GFVariantData.get_option_array(report, "methods")
	var properties: Array = GFVariantData.get_option_array(report, "properties")
	var constant_record: Dictionary = _find_named_record(constants, "SAMPLE_ID")

	assert_true(_has_named_record(methods, "_hidden_method"), "开启选项后应包含私有方法。")
	assert_true(_has_named_record(properties, "_private_value"), "开启选项后应包含私有属性。")
	assert_eq(GFVariantData.get_option_string_name(constant_record, "value"), &"sample", "开启选项后应保留常量值。")


func test_check_script_structure_accepts_valid_contract() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var report: Dictionary = GFScriptStructureTools.check_script_structure(target_script, {
		"base_class": "RefCounted",
		"can_instantiate": true,
		"required_constants": PackedStringArray(["SAMPLE_ID"]),
		"required_methods": [
			{
				"name": "apply_delta",
				"argument_count": 1,
			},
		],
		"required_properties": [
			{
				"name": "public_value",
				"type": TYPE_INT,
			},
		],
		"required_signals": [
			{
				"name": "sample_changed",
				"argument_count": 1,
			},
		],
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "满足结构声明的脚本应通过。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(report, "counts"), "error_count"), 0, "不应产生错误。")


func test_check_script_structure_reports_missing_and_mismatched_members() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var report: Dictionary = GFScriptStructureTools.check_script_structure(target_script, {
		"base_class": "Node",
		"required_methods": [
			{
				"name": "missing_method",
				"argument_count": 2,
			},
			{
				"name": "apply_delta",
				"argument_count": 2,
			},
		],
	})
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不满足结构声明时应失败。")
	assert_true(_has_issue_kind(issues, "base_class_mismatch"), "应报告基类不匹配。")
	assert_true(_has_issue_kind(issues, "missing_method"), "应报告缺失方法。")
	assert_true(_has_issue_kind(issues, "method_argument_count_mismatch"), "应报告方法参数数量不匹配。")


func test_check_script_structure_accepts_base_script_chain() -> void:
	var sample_script: Script = load(SAMPLE_SCRIPT_PATH)
	var child_script: Script = load(CHILD_SCRIPT_PATH)
	var report: Dictionary = GFScriptStructureTools.check_script_structure(child_script, {
		"base_script": sample_script,
		"required_methods": PackedStringArray(["child_marker", "apply_delta"]),
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "子脚本应满足父脚本和继承方法声明。")


func test_scan_script_paths_orders_parent_directory_before_child_directory() -> void:
	var paths: PackedStringArray = GFScriptStructureTools.scan_script_paths(
		"res://tests/gf_core/fixtures/script_structure",
		{
			"recursive": true,
			"extensions": PackedStringArray(["gd"]),
		}
	)

	assert_true(paths.has(SAMPLE_SCRIPT_PATH), "应扫描根目录脚本。")
	assert_true(paths.has(CHILD_SCRIPT_PATH), "应扫描子目录脚本。")
	assert_lt(paths.find(SAMPLE_SCRIPT_PATH), paths.find(CHILD_SCRIPT_PATH), "父目录脚本应排在子目录脚本前。")


func test_format_method_signature_preserves_types_and_defaults() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var method: Dictionary = _find_raw_method(target_script, "build_label")
	var report: Dictionary = GFScriptStructureTools.format_method_signature(method)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效方法元数据应能格式化签名。")
	assert_eq(
		GFVariantData.get_option_string(report, "signature"),
		"func build_label(name: String = \"sample\", count: int = 1) -> String",
		"签名应保留参数类型、默认值和返回类型。"
	)
	assert_eq(GFVariantData.get_option_string(report, "return_type_name"), "String", "应暴露格式化后的返回类型。")


func test_format_method_stub_generates_default_return_body() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var method: Dictionary = _find_raw_method(target_script, "apply_delta")
	var report: Dictionary = GFScriptStructureTools.format_method_stub(method)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效方法元数据应能格式化方法桩。")
	assert_eq(
		GFVariantData.get_option_string(report, "stub"),
		"func apply_delta(delta: int) -> int:\n\treturn 0\n",
		"int 返回值的方法桩应生成安全默认返回。"
	)


func test_format_method_stub_accepts_custom_body_lines() -> void:
	var target_script: Script = load(SAMPLE_SCRIPT_PATH)
	var method: Dictionary = _find_raw_method(target_script, "apply_delta")
	var report: Dictionary = GFScriptStructureTools.format_method_stub(method, {
		"body_lines": PackedStringArray(["return delta"]),
		"indent": "    ",
		"include_trailing_newline": false,
	})

	assert_eq(
		GFVariantData.get_option_string(report, "stub"),
		"func apply_delta(delta: int) -> int:\n    return delta",
		"调用方应能控制方法桩主体、缩进和末尾换行。"
	)


func _has_named_record(records: Array, record_name: String) -> bool:
	return not _find_named_record(records, record_name).is_empty()


func _find_named_record(records: Array, record_name: String) -> Dictionary:
	for record_value: Variant in records:
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if GFVariantData.get_option_string(record, "name") == record_name:
			return record
	return {}


func _find_raw_method(target_script: Script, method_name: String) -> Dictionary:
	for method_value: Variant in target_script.get_script_method_list():
		var method: Dictionary = GFVariantData.as_dictionary(method_value)
		if GFVariantData.get_option_string(method, "name") == method_name:
			return method
	return {}


func _has_issue_kind(issues: Array, issue_kind: String) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == issue_kind:
			return true
	return false
