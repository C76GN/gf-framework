## 测试 GFDependencyGraphTools 的字符串依赖排序与诊断。
extends GutTest


# --- 测试用例 ---

func test_sort_dependency_first_orders_dependencies_before_dependents() -> void:
	var dependency_map: Dictionary = {
		"feature": PackedStringArray(["base"]),
		"patch": PackedStringArray(["feature"]),
		"base": PackedStringArray(),
	}
	var report: Dictionary = GFDependencyGraphTools.sort_dependency_first(
		PackedStringArray(["patch", "feature", "base"]),
		dependency_map
	)
	var ordered_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "ordered_ids")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "完整依赖图应为健康状态。")
	assert_eq(Array(ordered_ids), ["base", "feature", "patch"], "排序结果应让依赖先于依赖方。")


func test_sort_dependency_first_reports_missing_dependencies_once() -> void:
	var dependency_map: Dictionary = {
		"feature": PackedStringArray(["base", "base"]),
	}
	var report: Dictionary = GFDependencyGraphTools.sort_dependency_first(
		PackedStringArray(["feature"]),
		dependency_map
	)
	var missing_dependencies: Array = GFVariantData.get_option_array(report, "missing_dependencies")
	var missing_entry: Dictionary = GFVariantData.as_dictionary(missing_dependencies[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失依赖应让依赖图诊断失败。")
	assert_eq(missing_dependencies.size(), 1, "同一节点的同一缺失依赖只应报告一次。")
	assert_eq(GFVariantData.get_option_string(missing_entry, "node_id"), "feature", "缺失依赖应记录来源节点。")
	assert_eq(GFVariantData.get_option_string(missing_entry, "dependency_id"), "base", "缺失依赖应记录目标 ID。")


func test_sort_dependency_first_reports_missing_root_ids() -> void:
	var dependency_map: Dictionary = {
		"base": PackedStringArray(),
	}
	var report: Dictionary = GFDependencyGraphTools.sort_dependency_first(
		PackedStringArray(["feature", "base"]),
		dependency_map
	)
	var missing_root_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "missing_root_ids")
	var ordered_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "ordered_ids")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未知根节点应让依赖图诊断失败。")
	assert_eq(Array(missing_root_ids), ["feature"], "未知根节点应进入 missing_root_ids。")
	assert_eq(GFVariantData.get_option_int(report, "missing_root_count", -1), 1, "未知根节点数量应进入计数字段。")
	assert_eq(Array(ordered_ids), ["base"], "有效根节点仍应被排序。")


func test_sort_dependency_first_normalizes_packed_string_dependencies() -> void:
	var dependency_map: Dictionary = {
		"feature": PackedStringArray([" base ", "base", ""]),
		"base": PackedStringArray(),
	}
	var report: Dictionary = GFDependencyGraphTools.sort_dependency_first(
		PackedStringArray(["feature"]),
		dependency_map
	)
	var ordered_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "ordered_ids")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "PackedStringArray 依赖值应裁剪空白、过滤空值并去重。")
	assert_eq(Array(ordered_ids), ["base", "feature"], "规范化后的 PackedStringArray 依赖仍应保持依赖优先顺序。")


func test_sort_dependency_first_reports_closed_cycle_path() -> void:
	var dependency_map: Dictionary = {
		"a": PackedStringArray(["b"]),
		"b": PackedStringArray(["c"]),
		"c": PackedStringArray(["a"]),
	}
	var report: Dictionary = GFDependencyGraphTools.sort_dependency_first(
		PackedStringArray(["a", "b", "c"]),
		dependency_map
	)
	var dependency_cycles: Array = GFVariantData.get_option_array(report, "dependency_cycles")
	var cycle: PackedStringArray = _get_packed_string_array(dependency_cycles[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "循环依赖应让依赖图诊断失败。")
	assert_eq(Array(cycle), ["a", "b", "c", "a"], "循环路径应包含闭合节点，便于诊断显示。")


# --- 私有/辅助方法 ---

func _get_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var typed_value: PackedStringArray = value
		return typed_value
	return PackedStringArray()
