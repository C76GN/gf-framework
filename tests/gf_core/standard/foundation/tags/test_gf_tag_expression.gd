## 测试可嵌套标签表达式资源。
extends GutTest


func test_any_expression_matches_nested_queries() -> void:
	var tags: GFTagSet = GFTagSet.new()
	var _tags_set: GFTagSet = tags.set_tags([&"team.enemy", &"state.burning"])
	var burning_enemy: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.enemy", &"state.burning"]))
	var boss: GFTagExpression = GFTagExpression.from_query(_make_query([&"rank.boss"]))
	var children: Array[GFTagExpression] = [burning_enemy, boss]
	var expression: GFTagExpression = GFTagExpression.new().configure_any(children)

	var report: Dictionary = expression.get_match_report(tags)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "任意子表达式满足时 ANY 表达式应通过。")
	assert_eq(GFVariantData.get_option_array(report, "matched_indices"), [0], "报告应记录命中的子表达式索引。")
	assert_eq(GFVariantData.get_option_array(report, "failed_indices"), [1], "报告应记录未命中的子表达式索引。")


func test_all_expression_reports_failed_child() -> void:
	var tags: GFTagSet = GFTagSet.new()
	var _tags_set: GFTagSet = tags.set_tags([&"team.enemy"])
	var enemy: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.enemy"]))
	var visible: GFTagExpression = GFTagExpression.from_query(_make_query([&"state.visible"]))
	var children: Array[GFTagExpression] = [enemy, visible]
	var expression: GFTagExpression = GFTagExpression.new().configure_all(children)

	var report: Dictionary = expression.get_match_report(tags)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "ALL 中任意子表达式失败时整体应失败。")
	assert_eq(GFVariantData.get_option_array(report, "matched_indices"), [0], "报告应保留已满足子表达式。")
	assert_eq(GFVariantData.get_option_array(report, "failed_indices"), [1], "报告应指出失败子表达式。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "child_failed", "失败原因应说明子表达式未满足。")


func test_none_expression_blocks_matching_children() -> void:
	var tags: GFTagSet = GFTagSet.new()
	var _tags_set: GFTagSet = tags.set_tags([&"state.stunned"])
	var stunned: GFTagExpression = GFTagExpression.from_query(_make_query([&"state.stunned"]))
	var children: Array[GFTagExpression] = [stunned]
	var expression: GFTagExpression = GFTagExpression.new().configure_none(children)

	var report: Dictionary = expression.get_match_report(tags)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "NONE 中有子表达式满足时整体应失败。")
	assert_eq(GFVariantData.get_option_array(report, "matched_indices"), [0], "报告应指出阻塞命中的子表达式。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "blocked_child_matched", "失败原因应说明禁止子表达式被命中。")


func test_expression_dictionary_roundtrip_preserves_nested_logic() -> void:
	var enemy: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.enemy"]))
	var ally: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.ally"]))
	var children: Array[GFTagExpression] = [enemy, ally]
	var expression: GFTagExpression = GFTagExpression.new().configure_any(children)

	var restored: GFTagExpression = GFTagExpression.from_dictionary(expression.to_dictionary())

	assert_true(restored.matches([&"team.ally"]), "字典往返后应保留嵌套匹配逻辑。")
	assert_false(restored.matches([&"team.neutral"]), "字典往返后未满足条件仍应失败。")


func test_expression_resource_roundtrip_preserves_typed_children() -> void:
	var child: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.enemy"]))
	var children: Array[GFTagExpression] = [child]
	var expression: GFTagExpression = GFTagExpression.new().configure_all(children)
	var resource_path: String = "user://gf_tag_expression_roundtrip.tres"
	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	var _previous_file_removed: Error = DirAccess.remove_absolute(absolute_path)

	var save_error: Error = ResourceSaver.save(expression, resource_path)
	var loaded_resource: Resource = ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)

	assert_eq(save_error, OK, "标签表达式应能保存为 Resource。")
	assert_true(loaded_resource is GFTagExpression, "资源往返后应恢复 GFTagExpression 类型。")
	if loaded_resource is GFTagExpression:
		var restored: GFTagExpression = loaded_resource
		assert_eq(restored.expressions.size(), 1, "资源往返后应保留子表达式。")
		assert_true(restored.expressions[0] is GFTagExpression, "资源往返后子项应保持表达式类型。")
		assert_true(restored.matches([&"team.enemy"]), "资源往返后应保留嵌套匹配语义。")
	var _resource_file_removed: Error = DirAccess.remove_absolute(absolute_path)


func test_expression_dictionary_roundtrip_preserves_null_children() -> void:
	var enemy: GFTagExpression = GFTagExpression.from_query(_make_query([&"team.enemy"]))
	var children: Array[GFTagExpression] = [enemy, null]
	var expression: GFTagExpression = GFTagExpression.new().configure_all(children)

	var restored: GFTagExpression = GFTagExpression.from_dictionary(expression.to_dictionary())
	var report: Dictionary = restored.get_match_report([&"team.enemy"])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "null 子表达式往返后仍应按失败处理。")
	assert_eq(GFVariantData.get_option_array(report, "matched_indices"), [0], "非空子表达式应保留原索引。")
	assert_eq(GFVariantData.get_option_array(report, "failed_indices"), [1], "null 子表达式不应在序列化时被静默丢弃。")


func test_expression_treats_non_expression_resources_as_invalid_children() -> void:
	var expression: GFTagExpression = GFTagExpression.new()
	expression.operator = GFTagExpression.Operator.ALL
	expression.expressions.append(Resource.new())

	var report: Dictionary = expression.get_match_report([&"team.enemy"])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非 GFTagExpression 资源不得被解释为有效子表达式。")
	assert_eq(GFVariantData.get_option_array(report, "failed_indices"), [0], "非法资源应保留原索引并按失败处理。")


func test_expression_dictionary_serialization_marks_cycles() -> void:
	var expression: GFTagExpression = GFTagExpression.new()
	expression.operator = GFTagExpression.Operator.ALL
	expression.expressions.append(expression)

	var data: Dictionary = expression.to_dictionary()
	var serialized_children: Array = GFVariantData.get_option_array(data, "expressions")

	assert_eq(serialized_children.size(), 1, "循环子表达式应留下显式占位诊断。")
	assert_true(
		GFVariantData.get_option_bool(GFVariantData.as_dictionary(serialized_children[0]), "cycle_detected"),
		"循环序列化应显式标记 cycle_detected。"
	)
	expression.expressions.clear()


func test_expression_from_dictionary_guards_cyclic_dictionaries() -> void:
	var data: Dictionary = {
		"operator": "all",
		"query": {},
		"expressions": [],
	}
	data["expressions"] = [data]

	var restored: GFTagExpression = GFTagExpression.from_dictionary(data)
	var report: Dictionary = restored.get_match_report([&"team.enemy"])

	assert_eq(restored.expressions.size(), 1, "循环字典应保留一个子表达式占位。")
	assert_eq(restored.expressions[0], null, "循环字典子节点应恢复为空表达式占位。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "循环字典恢复后不应误判通过。")
	data["expressions"] = []
	data.clear()


func test_expression_duplicate_preserves_cycle_guard() -> void:
	var expression: GFTagExpression = GFTagExpression.new()
	expression.operator = GFTagExpression.Operator.ALL
	expression.expressions.append(expression)

	var copy: GFTagExpression = expression.duplicate_expression()
	var report: Dictionary = copy.get_match_report([&"team.enemy"])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "复制循环表达式不应无限递归或误判通过。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "child_failed", "循环子节点失败应汇总为子表达式失败。")
	expression.expressions.clear()
	copy.expressions.clear()


func test_expression_cycle_guard_reports_failure() -> void:
	var expression: GFTagExpression = GFTagExpression.new()
	expression.operator = GFTagExpression.Operator.ALL
	var visited: Array[int] = [expression.get_instance_id()]

	var report: Dictionary = GFVariantData.as_dictionary(
		expression.call("_get_match_report", [&"team.enemy"], visited)
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "循环表达式不应无限递归或通过。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "cycle_detected", "循环应进入诊断报告。")


# --- 私有/辅助方法 ---

func _make_query(required_all: Array[StringName]) -> GFTagQuery:
	var query: GFTagQuery = GFTagQuery.new()
	query.all_tags = required_all
	return query
