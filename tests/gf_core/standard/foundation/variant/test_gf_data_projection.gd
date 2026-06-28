## 测试显式安全数据投影。
extends GutTest


func test_dictionary_projection_filters_and_sanitizes_values() -> void:
	var node: Node = Node.new()
	node.name = "UnsafeNode"

	var projected: Dictionary = GFDataProjection.project_dictionary({
		"id": 7,
		"title": "Potion",
		"node": node,
		"nested": {
			"enabled": true,
			"owner": node,
		},
		"array": [1, node, "tail"],
	}, {
		"allowed_fields": PackedStringArray(["id", "nested", "array"]),
		"unsupported": "null",
	})

	var nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(projected, "nested"))
	var array: Array = GFVariantData.as_array(GFVariantData.get_option_value(projected, "array"))

	assert_true(projected.has("id"), "允许字段应保留。")
	assert_false(projected.has("title"), "未在 allowlist 中的字段应剔除。")
	assert_false(projected.has("node"), "未允许的 Object 字段不应暴露。")
	assert_eq(GFVariantData.get_option_int(projected, "id"), 7, "标量字段应保留。")
	assert_true(GFVariantData.get_option_bool(nested, "enabled"), "嵌套纯数据应保留。")
	assert_true(GFVariantData.get_option_value(nested, "owner") == null, "嵌套 Object 应按 unsupported=null 处理。")
	assert_eq(array.size(), 3, "数组默认应保留形状。")
	assert_true(array[1] == null, "数组中的 Object 应替换为 null。")

	node.free()


func test_projection_with_report_records_dropped_paths() -> void:
	var node: Node = Node.new()
	node.name = "DroppedNode"

	var result: Dictionary = GFDataProjection.project_with_report({
		"safe": 1,
		"node": node,
		"nested": {
			"owner": node,
		},
		"array": [node],
	}, {
		"unsupported": "drop",
	})
	var report: GFValidationReport = _as_report(GFVariantData.get_option_value(result, "report"))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "投影 drop unsupported 时数据结果可继续使用。")
	assert_not_null(report, "project_with_report 应返回诊断报告。")
	assert_true(report != null and report.get_warning_count() >= 3, "被 drop 的字段应进入 warning 诊断。")
	assert_true(report != null and _has_issue_path(report, "node"), "顶层被 drop 字段应记录路径。")
	assert_true(report != null and _has_issue_path(report, "nested.owner"), "嵌套被 drop 字段应记录路径。")
	assert_true(report != null and _has_issue_path(report, "array[0]"), "数组中被 drop 项应记录路径。")

	node.free()


func test_object_projection_requires_explicit_fields() -> void:
	var node: Node = Node.new()
	node.name = "ProjectedNode"

	var empty_projection: Dictionary = GFDataProjection.project_object(node)
	var projected: Dictionary = GFDataProjection.project_object(node, PackedStringArray(["name"]), {
		"rename_fields": {
			"name": "node_name",
		},
	})

	assert_true(empty_projection.is_empty(), "没有显式字段时不应暴露 Object 属性。")
	assert_eq(
		GFVariantData.get_option_string(projected, "node_name"),
		"ProjectedNode",
		"显式字段应允许重命名后输出。"
	)

	node.free()


func test_projection_reports_freed_object_without_property_access() -> void:
	var node: Node = Node.new()
	node.name = "FreedNode"
	node.free()

	var result: Dictionary = GFDataProjection.project_with_report(node, {
		"fields": PackedStringArray(["name"]),
	})
	var report: GFValidationReport = _as_report(GFVariantData.get_option_value(result, "report"))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "释放后的对象应降级为空数据而不是让投影失败。")
	assert_not_null(report, "释放对象诊断应写入报告。")
	assert_true(report != null and _has_issue_kind(report, "invalid_object"), "释放后的对象应产生稳定诊断类别。")


func test_projection_reports_circular_dictionary_and_array() -> void:
	var circular_dictionary: Dictionary = {}
	circular_dictionary["self"] = circular_dictionary
	var circular_array: Array = []
	circular_array.append(circular_array)

	var result: Dictionary = GFDataProjection.project_with_report({
		"dictionary": circular_dictionary,
		"array": circular_array,
	}, {
		"unsupported": "metadata",
	})
	var data: Dictionary = GFVariantData.get_option_dictionary(result, "data")
	var projected_dictionary: Dictionary = GFVariantData.get_option_dictionary(data, "dictionary")
	var projected_array: Array = GFVariantData.get_option_array(data, "array")
	var dictionary_marker: Dictionary = GFVariantData.get_option_dictionary(projected_dictionary, "self")
	var array_marker: Dictionary = GFVariantData.as_dictionary(projected_array[0])
	var report: GFValidationReport = _as_report(GFVariantData.get_option_value(result, "report"))

	assert_true(GFVariantData.get_option_bool(result, "ok"), "循环结构应降级为可消费数据。")
	assert_eq(GFVariantData.get_option_string(dictionary_marker, "unsupported"), "circular_reference", "循环字典应写入元数据标记。")
	assert_eq(GFVariantData.get_option_string(array_marker, "unsupported"), "circular_reference", "循环数组应写入元数据标记。")
	assert_not_null(report, "循环结构应写入诊断报告。")
	assert_true(report != null and _has_issue_kind(report, "circular_reference"), "循环结构应产生稳定诊断类别。")


func _has_issue_path(report: GFValidationReport, path: String) -> bool:
	for issue_ref: RefCounted in report.issues:
		if issue_ref is GFValidationIssue:
			var issue: GFValidationIssue = issue_ref
			if issue.path == path:
				return true
	return false


func _has_issue_kind(report: GFValidationReport, kind: String) -> bool:
	for issue_ref: RefCounted in report.issues:
		if issue_ref is GFValidationIssue:
			var issue: GFValidationIssue = issue_ref
			if String(issue.kind) == kind:
				return true
	return false


func _as_report(value: Variant) -> GFValidationReport:
	if value is GFValidationReport:
		var report: GFValidationReport = value
		return report
	return null
