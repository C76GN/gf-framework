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


func test_none_expression_fails_closed_for_invalid_children() -> void:
	var null_expression: GFTagExpression = GFTagExpression.new()
	null_expression.operator = GFTagExpression.Operator.NONE
	null_expression.expressions.append(null)
	var foreign_expression: GFTagExpression = GFTagExpression.new()
	foreign_expression.operator = GFTagExpression.Operator.NONE
	foreign_expression.expressions.append(Resource.new())
	var cyclic_expression: GFTagExpression = GFTagExpression.new()
	cyclic_expression.operator = GFTagExpression.Operator.NONE
	cyclic_expression.expressions.append(cyclic_expression)

	for expression: GFTagExpression in [null_expression, foreign_expression, cyclic_expression]:
		var report: Dictionary = expression.get_match_report([])
		assert_false(GFVariantData.get_option_bool(report, "ok", true), "NONE 不得把非法子表达式解释为普通未命中。")
		assert_false(GFVariantData.get_option_bool(report, "valid", true), "报告应区分结构无效与合法未命中。")
		assert_eq(GFVariantData.get_option_array(report, "invalid_indices"), [0], "报告应保留非法子表达式索引。")

	cyclic_expression.expressions.clear()


func test_any_expression_does_not_ignore_invalid_children_after_a_match() -> void:
	var unconditional_match: GFTagExpression = GFTagExpression.new()
	var expression: GFTagExpression = GFTagExpression.new()
	expression.operator = GFTagExpression.Operator.ANY
	expression.expressions.append(unconditional_match)
	expression.expressions.append(Resource.new())

	var report: Dictionary = expression.get_match_report([])

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "ANY 存在非法子项时不得因另一项命中而失败开放。")
	assert_false(GFVariantData.get_option_bool(report, "valid", true), "ANY 应把结构有效性与 matched 分开。")
	assert_eq(GFVariantData.get_option_array(report, "matched_indices"), [0], "报告仍应保留合法命中证据。")
	assert_eq(GFVariantData.get_option_array(report, "invalid_indices"), [1], "报告应指出被拒绝的非法子项。")


func test_expression_dictionary_distinguishes_missing_and_unknown_operator() -> void:
	var missing_operator: GFTagExpression = GFTagExpression.from_dictionary({})
	var unknown_text: GFTagExpression = GFTagExpression.from_dictionary({
		"operator": "deny_typo",
	})
	var unknown_number: GFTagExpression = GFTagExpression.from_dictionary({
		"operator": 99,
	})

	assert_true(missing_operator.matches([]), "缺失 operator 应保留既有 QUERY 默认。")
	for expression: GFTagExpression in [unknown_text, unknown_number]:
		var report: Dictionary = expression.get_match_report([])
		assert_false(GFVariantData.get_option_bool(report, "ok", true), "字段存在但 operator 非法时必须失败关闭。")
		assert_false(GFVariantData.get_option_bool(report, "valid", true), "未知 operator 应标记结构无效。")
		assert_eq(GFVariantData.get_option_string(report, "reason"), "unknown_operator", "未知 operator 应有稳定原因。")


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
	assert_false(GFVariantData.get_option_bool(report, "valid", true), "循环子节点应使父表达式结构无效。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_child", "循环子节点应按无效结构汇总。")
	expression.expressions.clear()
	copy.expressions.clear()


func test_expression_match_report_fails_closed_at_depth_limit() -> void:
	var root: GFTagExpression = GFTagExpression.new()
	var current: GFTagExpression = root
	for _index: int in range(48):
		current.operator = GFTagExpression.Operator.ALL
		var child: GFTagExpression = GFTagExpression.new()
		current.expressions.append(child)
		current = child

	var report: Dictionary = root.get_match_report([])
	var cursor: Dictionary = report
	var found_depth_limit: bool = false
	for _index: int in range(48):
		if GFVariantData.get_option_string(cursor, "reason") == "depth_limit_exceeded":
			found_depth_limit = true
			break
		var child_reports_value: Variant = cursor.get("child_reports", [])
		if not child_reports_value is Array:
			break
		var child_reports: Array = child_reports_value
		if child_reports.is_empty():
			break
		var child_report_value: Variant = child_reports[0]
		if not child_report_value is Dictionary:
			break
		cursor = child_report_value

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "过深表达式不得继续递归或匹配通过。")
	assert_false(GFVariantData.get_option_bool(report, "valid", true), "过深表达式应标记结构无效。")
	assert_true(found_depth_limit, "嵌套报告应保留 depth_limit_exceeded 根因。")
	root.expressions.clear()


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
