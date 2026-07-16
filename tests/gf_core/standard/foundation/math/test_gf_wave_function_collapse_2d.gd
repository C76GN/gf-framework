## 测试 GFWaveFunctionCollapse2D 的简单 tiled 约束、确定性、矛盾和输入校验。
extends GutTest


const GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_wave_function_collapse_2d.gd")


# --- 测试 ---

func test_solve_grid_respects_adjacency_rules_and_fixed_cells() -> void:
	var tiles: Array = [&"floor", &"wall"]
	var rules: Array[Dictionary] = [
		{ "from": &"floor", "to": &"wall", "direction": Vector2i.RIGHT },
		{ "from": &"wall", "to": &"floor", "direction": Vector2i.RIGHT },
		{ "from": &"floor", "to": &"wall", "direction": Vector2i.DOWN },
		{ "from": &"wall", "to": &"floor", "direction": Vector2i.DOWN },
	]
	var report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(2, 2),
		tiles,
		rules,
		{
			"seed": 17,
			"fixed_cells": {
				Vector2i.ZERO: &"floor",
			},
		}
	)
	var grid: Dictionary = GFVariantData.get_option_dictionary(report, "grid")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 checkerboard 规则应完成求解。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.STATUS_COMPLETE,
		"成功报告应标记 complete。"
	)
	assert_eq(GFVariantData.get_option_int(report, "collapsed_count"), 4, "全部格子应已坍缩。")
	assert_eq(_option_string_name(grid, Vector2i(0, 0)), &"floor")
	assert_eq(_option_string_name(grid, Vector2i(1, 0)), &"wall")
	assert_eq(_option_string_name(grid, Vector2i(0, 1)), &"wall")
	assert_eq(_option_string_name(grid, Vector2i(1, 1)), &"floor")


func test_solve_grid_is_deterministic_for_same_seed_without_adjacency_constraints() -> void:
	var tiles: Array = [
		{ "id": &"grass", "weight": 3.0 },
		{ "id": &"stone", "weight": 1.0 },
		{ "id": &"water", "weight": 1.0 },
	]
	var rules: Array[Dictionary] = []
	var first_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(5, 4),
		tiles,
		rules,
		{ "seed": 91 }
	)
	var second_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(5, 4),
		tiles,
		rules,
		{ "seed": 91 }
	)

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "无邻接规则时应作为加权随机格生成器完成。")
	assert_eq(
		GFVariantData.get_option_dictionary(first_report, "grid"),
		GFVariantData.get_option_dictionary(second_report, "grid"),
		"相同 seed 和权重应生成稳定结果。"
	)
	assert_eq(GFVariantData.get_option_int(first_report, "cell_count"), 20, "报告应记录总格子数。")
	assert_eq(GFVariantData.get_option_int(first_report, "undecided_count"), 0, "完成后不应有未决 domain。")


func test_solve_grid_reports_contradiction_for_incompatible_fixed_cells() -> void:
	var tiles: Array = [&"floor", &"wall"]
	var rules: Array[Dictionary] = [
		{ "from": &"floor", "to": &"floor", "direction": Vector2i.RIGHT },
		{ "from": &"wall", "to": &"wall", "direction": Vector2i.RIGHT },
	]
	var report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(2, 1),
		tiles,
		rules,
		{
			"fixed_cells": {
				Vector2i(0, 0): &"floor",
				Vector2i(1, 0): &"wall",
			},
		}
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "互斥固定格应返回失败报告。")
	assert_eq(
		GFVariantData.get_option_string_name(report, "status"),
		GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.STATUS_CONTRADICTION,
		"规则矛盾应标记 contradiction。"
	)
	assert_true(
		[
			Vector2i(0, 0),
			Vector2i(1, 0),
		].has(_option_vector2i(report, "contradiction_cell")),
		"报告应指出发生矛盾的格子。"
	)


func test_solve_grid_report_has_json_compatible_export() -> void:
	var report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(1, 1),
		[&"floor"],
		[],
		{
			"fixed_cells": {
				Vector2i.ZERO: &"floor",
			},
		}
	)
	var safe_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.to_json_compatible_report(report)
	var json_text: String = JSON.stringify(safe_report)

	assert_false(json_text.is_empty(), "JSON-safe WFC 报告应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe WFC 报告不应依赖 JSON.stringify 降级非法值。")


func test_solve_grid_rejects_invalid_tile_and_fixed_cell_inputs() -> void:
	var duplicate_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i.ONE,
		["grass", &"grass"],
		[]
	)
	var invalid_fixed_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i.ONE,
		[&"grass"],
		[],
		{
			"fixed_cells": {
				Vector2i(1, 0): &"grass",
			},
		}
	)

	assert_false(GFVariantData.get_option_bool(duplicate_report, "ok"), "归一后重复 tile id 应失败。")
	assert_eq(
		GFVariantData.get_option_string_name(duplicate_report, "status"),
		GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.STATUS_INVALID_INPUT,
		"无效 tile 声明应标记 invalid_input。"
	)
	assert_false(GFVariantData.get_option_bool(invalid_fixed_report, "ok"), "越界固定格应失败。")
	assert_eq(
		GFVariantData.get_option_string_name(invalid_fixed_report, "status"),
		GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.STATUS_INVALID_INPUT,
		"无效 fixed_cells 应标记 invalid_input。"
	)


func test_expand_transformed_adjacency_rules_rotates_direction_and_tile_ids() -> void:
	var expansion: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.expand_transformed_adjacency_rules(
		[
			{
				"from": &"road_e",
				"to": &"road_e",
				"direction": Vector2i.RIGHT,
				"bidirectional": false,
			},
		],
		[
			{
				"transform": GFGridTransform2D.Transform.IDENTITY,
				"tile_remaps": {
					&"road_e": &"road_e",
				},
			},
			{
				"transform": GFGridTransform2D.Transform.ROTATE_90,
				"tile_remaps": {
					&"road_e": &"road_s",
				},
			},
		]
	)
	var expanded_rules: Array[Dictionary] = _rules_from_report(expansion)
	var rotated_rule: Dictionary = _rule_at(expanded_rules, 1)
	var solve_report: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.solve_grid(
		Vector2i(1, 2),
		[&"road_e", &"road_s"],
		expanded_rules,
		{
			"fixed_cells": {
				Vector2i.ZERO: &"road_s",
			},
			"bidirectional_rules": false,
		}
	)
	var grid: Dictionary = GFVariantData.get_option_dictionary(solve_report, "grid")

	assert_true(GFVariantData.get_option_bool(expansion, "ok"), "有效规则变换应成功。")
	assert_eq(GFVariantData.get_option_int(expansion, "expanded_count"), 2, "两个变换应生成两条规则。")
	assert_eq(_option_string_name(rotated_rule, "from"), &"road_s", "tile id 应按 remap 变换。")
	assert_eq(_option_vector2i(rotated_rule, "direction"), Vector2i.DOWN, "向右规则旋转 90 度后应变为向下。")
	assert_false(GFVariantData.get_option_bool(rotated_rule, "bidirectional", true), "bidirectional 字段应保留。")
	assert_true(GFVariantData.get_option_bool(solve_report, "ok"), "展开后的规则应可直接用于求解。")
	assert_eq(_option_string_name(grid, Vector2i(1, 0)), &"", "非网格格子不应出现在结果中。")
	assert_eq(_option_string_name(grid, Vector2i(0, 1)), &"road_s", "向下规则应约束相邻格。")


func test_expand_transformed_adjacency_rules_deduplicates_and_can_skip_unknown_remaps() -> void:
	var duplicated_expansion: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.expand_transformed_adjacency_rules(
		[
			{
				"from": "a",
				"to": "b",
				"direction": "right",
			},
		],
		[
			{ "transform": "identity" },
			{ "transform": GFGridTransform2D.Transform.IDENTITY },
		]
	)
	var skipped_expansion: Dictionary = GF_WAVE_FUNCTION_COLLAPSE_2D_SCRIPT.expand_transformed_adjacency_rules(
		[
			{
				"from": &"a",
				"to": &"b",
				"direction": Vector2i.RIGHT,
			},
		],
		[
			{
				"transform": GFGridTransform2D.Transform.ROTATE_90,
				"tile_remaps": {
					&"a": &"a_s",
				},
			},
		],
		{ "preserve_unknown_remaps": false }
	)

	assert_true(GFVariantData.get_option_bool(duplicated_expansion, "ok"), "重复变换应通过去重收敛。")
	assert_eq(GFVariantData.get_option_int(duplicated_expansion, "expanded_count"), 1, "重复规则只应保留一条。")
	assert_eq(GFVariantData.get_option_int(duplicated_expansion, "duplicate_count"), 1, "重复统计应记录被丢弃规则。")
	assert_true(GFVariantData.get_option_bool(skipped_expansion, "ok"), "缺失 remap 可以按选项跳过。")
	assert_eq(GFVariantData.get_option_int(skipped_expansion, "expanded_count"), 0, "缺失 remap 时不应生成半变换规则。")
	assert_eq(GFVariantData.get_option_int(skipped_expansion, "skipped_count"), 1, "跳过统计应保留。")


func _rules_from_report(report: Dictionary) -> Array[Dictionary]:
	var values: Array = GFVariantData.get_option_array(report, "rules")
	var rules: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			var rule: Dictionary = value
			rules.append(rule)
	return rules


func _rule_at(rules: Array[Dictionary], index: int) -> Dictionary:
	if index < 0 or index >= rules.size():
		return {}
	return rules[index]


func _option_vector2i(options: Dictionary, key: String) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO


func _option_string_name(options: Dictionary, key: Variant) -> StringName:
	return GFVariantData.to_string_name(GFVariantData.get_option_value(options, key), &"")
