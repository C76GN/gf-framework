## 测试通用校验问题、报告与字典兼容辅助。
extends GutTest


func test_issue_from_dict_preserves_extra_fields() -> void:
	var issue: GFValidationIssue = _issue_from_ref(GFValidationIssue.from_dict({
		"severity": "warn",
		"kind": "missing_field",
		"row_key": 3,
		"field": &"name",
		"message": "Missing field.",
	}))

	var data: Dictionary = issue.to_dict()

	assert_eq(GFVariantData.get_option_string(data, "severity"), "warning", "严重级别应归一为稳定字符串。")
	assert_eq(GFVariantData.get_option_string(data, "kind"), "missing_field", "kind 应作为统计用问题类别。")
	assert_false(data.has("code"), "问题字典不应再输出旧 code 字段。")
	assert_eq(GFVariantData.get_option_int(data, "row_key"), 3, "自定义定位字段应保留。")
	assert_eq(GFVariantData.get_option_string_name(data, "field"), &"name", "StringName 字段应保留。")


func test_report_counts_summary_and_next_action() -> void:
	var report: GFValidationReport = GFValidationReport.new("Sample data")
	var _add_warning_result_25: Variant = report.add_warning(&"optional_missing", "Optional value is missing.", "row_1")
	var _add_error_result_26: Variant = report.add_error(&"invalid_value", "Value is invalid.", "row_2")

	var data: Dictionary = report.to_dict({}, {
		"next_actions": {
			"invalid_value": "Fix the invalid value.",
		},
	})
	var counts: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(data, "issue_counts_by_kind")
	)

	assert_false(GFVariantData.get_option_bool(data, "ok"), "存在错误时报告不应通过。")
	assert_false(GFVariantData.get_option_bool(data, "healthy"), "存在警告或错误时报告不应健康。")
	assert_eq(GFVariantData.get_option_int(data, "error_count"), 1, "应统计错误数量。")
	assert_eq(GFVariantData.get_option_int(data, "warning_count"), 1, "应统计警告数量。")
	assert_eq(GFVariantData.get_option_int(counts, "invalid_value"), 1, "应按 kind 统计问题。")
	assert_eq(GFVariantData.get_option_string(data, "summary"), "Sample data has 1 error(s) and 1 warning(s).", "摘要应使用主题和统计数量。")
	assert_eq(GFVariantData.get_option_string(data, "next_action"), "Fix the invalid value.", "下一步建议应优先使用首个错误的映射。")


func test_report_promotes_selected_warnings_to_errors() -> void:
	var report: GFValidationReport = GFValidationReport.new("Sample data")
	var _add_warning_result_48: Variant = report.add_warning(&"optional_missing", "Optional value is missing.")
	var _add_warning_result_49: Variant = report.add_warning(&"deprecated_value", "Deprecated value.")

	var _promote_warnings_to_errors_result_51: Variant = report.promote_warnings_to_errors(PackedStringArray(["deprecated_value"]))

	assert_eq(report.get_error_count(), 1, "匹配类别的警告应提升为错误。")
	assert_eq(report.get_warning_count(), 1, "未匹配类别的警告应保持警告。")


func test_dictionary_report_finalize_preserves_existing_fields() -> void:
	var report: Dictionary = {
		"row_count": 2,
		"issues": [],
	}
	var _appended_report: Dictionary = GFValidationReportDictionary.append_issue(report, "warning", &"missing_optional", "Optional field is missing.", {
		"row_key": 1,
	})

	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(report, "Config table")
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "只有警告时报告仍可通过。")
	assert_false(GFVariantData.get_option_bool(report, "healthy"), "包含警告时报告不应视为完全健康。")
	assert_eq(GFVariantData.get_option_int(report, "row_count"), 2, "调用方已有统计字段应保留。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "字典报告应计算警告数量。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "字典报告应始终输出问题总数。")
	assert_eq(GFVariantData.get_option_int(issue, "row_key"), 1, "问题附加字段应保留。")


func test_dictionary_report_finalize_normalizes_legacy_issue_fields() -> void:
	var report: Dictionary = {
		"issues": [
			{
				"severity": "warning",
				"code": "legacy_code",
				"type": "legacy_type",
				"message": "Legacy issue.",
				"row_key": 7,
			},
		],
	}

	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(report, "Legacy report")

	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var counts: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(report, "issue_counts_by_kind")
	)
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "unknown", "缺少 kind 的旧问题应归入 unknown，而不是读取旧 code/type。")
	assert_false(issue.has("code"), "字典报告归一化后不应继续输出旧 code 字段。")
	assert_false(issue.has("type"), "字典报告归一化后不应继续输出旧 type 字段。")
	assert_eq(GFVariantData.get_option_int(issue, "row_key"), 7, "自定义定位字段应继续保留。")
	assert_eq(GFVariantData.get_option_int(counts, "unknown"), 1, "统计应使用标准 kind。")


func test_dictionary_report_finalize_drops_invalid_issue_entries_from_counts() -> void:
	var report: Dictionary = {
		"issues": [
			{
				"severity": "warning",
				"kind": "valid_warning",
				"message": "Valid issue.",
			},
			{},
			"invalid",
			42,
		],
	}

	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(report, "Mixed report")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_eq(issues.size(), 1, "无效 issue 条目应在 finalize 后移除。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "issue_count 应只统计有效问题。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "有效警告仍应计数。")
	assert_eq(GFVariantData.get_option_int(counts, "valid_warning"), 1, "kind 统计不应包含无效条目。")


func test_dictionary_report_can_treat_warnings_as_errors() -> void:
	var report: Dictionary = {
		"issues": [
			{
				"severity": "warning",
				"kind": "missing_optional",
				"message": "Optional field is missing.",
			},
		],
	}

	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(report, "Config table", {
		"warnings_as_errors": true,
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "启用 warnings_as_errors 后警告应使报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "提升后的警告应计入错误数量。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 0, "提升后的警告不应再计入警告数量。")


func test_dictionary_report_merge_report_copies_issues_and_selected_fields() -> void:
	var target: Dictionary = {
		"subject": "Combined scan",
		"issues": [
			{
				"severity": "warning",
				"kind": "slow_path",
				"message": "Path is slow.",
			},
		],
	}
	var source: Dictionary = {
		"package_count": 2,
		"ignored_count": 5,
		"ordered_package_ids": PackedStringArray(["base", "feature"]),
		"issues": [
			{
				"severity": "error",
				"kind": "missing_dependency",
				"message": "Dependency is missing.",
				"path": "packages.feature.dependencies",
				"metadata": {
					"source": "catalog",
				},
			},
		],
	}

	var _merged_report: Dictionary = GFValidationReportDictionary.merge_report(target, source, {
		"copy_fields": PackedStringArray(["package_count", "ordered_package_ids"]),
	})
	var _finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(target, "Combined scan")
	var target_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(target, "issues"))
	var source_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(source, "issues"))
	var copied_issue: Dictionary = GFVariantData.as_dictionary(target_issues[1])
	var copied_metadata: Dictionary = GFVariantData.get_option_dictionary(copied_issue, "metadata")
	var ordered_package_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(target, "ordered_package_ids")

	assert_eq(target_issues.size(), 2, "合并报告应追加来源问题。")
	assert_eq(source_issues.size(), 1, "合并不应修改来源报告。")
	assert_eq(GFVariantData.get_option_string(copied_issue, "kind"), "missing_dependency", "来源问题应保持稳定 kind。")
	assert_eq(GFVariantData.get_option_string(copied_metadata, "source"), "catalog", "来源问题 metadata 应被深拷贝保留。")
	assert_eq(GFVariantData.get_option_int(target, "package_count"), 2, "copy_fields 指定字段应复制到目标报告。")
	assert_eq(Array(ordered_package_ids), ["base", "feature"], "PackedStringArray 字段应复制为副本。")
	assert_false(target.has("ignored_count"), "未列入 copy_fields 的统计字段不应隐式复制。")
	assert_false(GFVariantData.get_option_bool(target, "ok"), "合并后的错误问题应在 finalize 后让报告失败。")


func test_dictionary_report_merge_report_is_safe_for_self_and_shared_issue_arrays() -> void:
	var shared_issues: Array = [
		{
			"severity": "warning",
			"kind": "shared_issue",
			"message": "Shared issue.",
		},
	]
	var report: Dictionary = {
		"issues": shared_issues,
		"package_count": 1,
	}

	var _self_merge: Dictionary = GFValidationReportDictionary.merge_report(report, report, {
		"copy_fields": PackedStringArray(["package_count"]),
	})
	assert_eq(shared_issues.size(), 1, "报告与自身合并必须是幂等空操作。")

	var wrapper: Dictionary = {
		"issues": shared_issues,
		"package_count": 2,
	}
	var _shared_array_merge: Dictionary = GFValidationReportDictionary.merge_report(report, wrapper, {
		"copy_fields": PackedStringArray(["package_count"]),
	})

	assert_eq(shared_issues.size(), 1, "不同报告共享同一 issues 数组时不得边遍历边追加导致无限增长。")
	assert_eq(GFVariantData.get_option_int(report, "package_count"), 2, "跳过同源 issues 后仍应复制显式选择的其他字段。")


func test_dictionary_report_filter_issues_uses_ignores_and_preserves_source() -> void:
	var report: Dictionary = {
		"subject": "Project scan",
		"issues": [
			{
				"severity": "error",
				"kind": "missing_script",
				"message": "Script is missing.",
				"path": "res://levels/broken.tscn",
			},
			{
				"severity": "warning",
				"kind": "large_texture",
				"message": "Texture is large.",
				"path": "res://textures/big.png",
			},
		],
	}

	var filtered: Dictionary = GFValidationReportDictionary.filter_issues(report, {
		"ignored_kinds": PackedStringArray(["missing_script"]),
	})
	var source_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(report, "issues"))
	var filtered_issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(filtered, "issues"))
	var remaining_issue: Dictionary = GFVariantData.as_dictionary(filtered_issues[0])

	assert_eq(source_issues.size(), 2, "过滤应返回副本，不应修改源报告。")
	assert_eq(filtered_issues.size(), 1, "匹配忽略类别的问题应被移除。")
	assert_eq(GFVariantData.get_option_string(remaining_issue, "kind"), "large_texture", "未匹配的问题应保留。")
	assert_true(GFVariantData.get_option_bool(filtered, "ok"), "只剩警告时过滤后的报告应可通过。")
	assert_eq(GFVariantData.get_option_int(filtered, "original_issue_count"), 2, "过滤摘要应记录原始问题数。")
	assert_eq(GFVariantData.get_option_int(filtered, "filtered_issue_count"), 1, "过滤摘要应记录移除数量。")


func test_dictionary_report_filter_issues_supports_baseline_fingerprints_and_globs() -> void:
	var report: Dictionary = {
		"issues": [
			{
				"severity": "error",
				"kind": "broken_reference",
				"message": "Missing resource.",
				"path": "res://content/legacy_scene.tscn",
				"key": "icon",
			},
			{
				"severity": "warning",
				"kind": "unused_file",
				"message": "File appears unused.",
				"path": "res://generated/cache/old.png",
			},
			{
				"severity": "error",
				"kind": "missing_export_preset",
				"message": "No export preset.",
				"path": "res://export_presets.cfg",
			},
		],
	}
	var baseline_issue: Dictionary = {
		"severity": "error",
		"kind": "broken_reference",
		"message": "Missing resource.",
		"path": "res://content/legacy_scene.tscn",
		"key": "icon",
	}
	var fingerprint: String = GFValidationReportDictionary.make_issue_fingerprint(baseline_issue)

	var filtered: Dictionary = GFValidationReportDictionary.filter_issues(report, {
		"baseline_fingerprints": PackedStringArray([fingerprint]),
		"ignored_path_patterns": PackedStringArray(["res://generated/**"]),
	})
	var issues: Array = GFVariantData.as_array(GFVariantData.get_option_value(filtered, "issues"))
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_eq(issues.size(), 1, "基线指纹和路径通配忽略应同时生效。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "missing_export_preset", "未进入基线或忽略路径的问题应保留。")
	assert_false(GFVariantData.get_option_bool(filtered, "ok"), "剩余错误应继续让报告失败。")


func test_issue_fingerprint_is_independent_of_dictionary_insertion_order() -> void:
	var key_a: Dictionary = {}
	key_a["id"] = "entry"
	key_a["locale"] = "zh"
	var key_b: Dictionary = {}
	key_b["locale"] = "zh"
	key_b["id"] = "entry"
	var issue_a: Dictionary = { "kind": "invalid_entry", "key": key_a }
	var issue_b: Dictionary = { "kind": "invalid_entry", "key": key_b }

	assert_eq(
		GFValidationReportDictionary.make_issue_fingerprint(issue_a),
		GFValidationReportDictionary.make_issue_fingerprint(issue_b),
		"语义相同的结构化 issue key 应产生稳定指纹。"
	)


func test_issue_fingerprint_rejects_runtime_identity_values() -> void:
	var runtime_owner: RefCounted = RefCounted.new()
	var issue: Dictionary = {
		"severity": "error",
		"kind": "runtime_owner",
		"message": "Runtime owner is not stable across processes.",
		"key": runtime_owner,
	}

	var fingerprint: String = GFValidationReportDictionary.make_issue_fingerprint(issue)

	assert_eq(fingerprint, "", "包含运行时对象身份的 issue 不得生成跨进程不稳定的基线指纹。")
	assert_false(fingerprint.contains("RefCounted#"), "指纹不得泄漏或依赖运行时实例 ID。")


func test_validation_report_exports_json_compatible_dict() -> void:
	var report: GFValidationReport = GFValidationReport.new("Runtime report")
	var _error: RefCounted = report.add_error(&"bad_runtime_value", "Runtime value is unsafe.", Vector2i(1, 2), "", {
		"owner": self,
		"value": NAN,
	})

	var data: Dictionary = report.to_json_compatible_dict()
	var json_text: String = JSON.stringify(data)

	assert_false(json_text.contains(":null"), "JSON-safe 报告不应把 NaN 直接交给 JSON.stringify。")
	assert_true(json_text.contains("__gf_report_value__"), "JSON-safe 报告应脱敏运行时对象。")
	assert_false(data.is_empty(), "JSON-safe 报告应保留标准报告字段。")


# --- 私有/辅助方法 ---

func _issue_from_ref(value: RefCounted) -> GFValidationIssue:
	if value is GFValidationIssue:
		var issue: GFValidationIssue = value
		return issue
	return null
