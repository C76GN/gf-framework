extends GutTest

const GF_EXECUTION_REQUIREMENT_SCRIPT = preload("res://addons/gf/standard/common/gf_execution_requirement.gd")


func test_execution_requirement_combines_all_any_and_none_conditions() -> void:
	var requirement: GF_EXECUTION_REQUIREMENT_SCRIPT = GF_EXECUTION_REQUIREMENT_SCRIPT.new()
	var _configured: GF_EXECUTION_REQUIREMENT_SCRIPT = requirement.configure(&"spawn-ready", "Spawn Ready")
	var _ready_condition: Dictionary = requirement.add_value(&"ready", &"ready", true)
	var _asset_condition: Dictionary = requirement.add_presence(&"asset", "asset")
	var _platform_condition: Dictionary = requirement.add_value(&"platform", "platform", "pc", {
		"mode": GF_EXECUTION_REQUIREMENT_SCRIPT.MODE_ANY,
	})
	var _quality_condition: Dictionary = requirement.add_value(&"quality", "quality", "high", {
		"mode": GF_EXECUTION_REQUIREMENT_SCRIPT.MODE_ANY,
	})
	var _blocked_condition: Dictionary = requirement.add_value(&"blocked", "blocked", true, {
		"mode": GF_EXECUTION_REQUIREMENT_SCRIPT.MODE_NONE,
	})

	var report: Dictionary = requirement.evaluate({
		&"ready": true,
		"asset": "res://unit.tscn",
		"platform": "pc",
		"blocked": false,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "all 满足、any 命中、none 未命中时应通过。")
	assert_true(GFVariantData.get_option_bool(report, "all_satisfied"), "all 条件应满足。")
	assert_true(GFVariantData.get_option_bool(report, "any_satisfied"), "any 条件应至少命中一个。")
	assert_true(GFVariantData.get_option_bool(report, "none_clear"), "none 条件命中 false 时应保持 clear。")
	assert_eq(GFVariantData.get_option_array(report, "conditions").size(), 5, "报告应包含每条条件。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 2, "failed_count 保留原始谓词 false 计数。")
	assert_eq(GFVariantData.get_option_int(report, "raw_failed_count"), 2, "raw_failed_count 应明确镜像原始失败计数。")
	assert_eq(GFVariantData.get_option_int(report, "blocking_count"), 0, "通过的 any/none 组合不应产生阻塞计数。")
	assert_eq(GFVariantData.get_option_int(report, "none_matched_count"), 0, "none 未命中时不应计入 none_matched_count。")


func test_execution_requirement_reports_none_matches_as_blocking_count() -> void:
	var requirement: GF_EXECUTION_REQUIREMENT_SCRIPT = GF_EXECUTION_REQUIREMENT_SCRIPT.new()
	var _blocked_condition: Dictionary = requirement.add_value(&"blocked", "blocked", true, {
		"mode": GF_EXECUTION_REQUIREMENT_SCRIPT.MODE_NONE,
	})

	var report: Dictionary = requirement.evaluate({ "blocked": true })

	assert_false(GFVariantData.get_option_bool(report, "ok"), "none 条件命中 true 时 requirement 应失败。")
	assert_false(GFVariantData.get_option_bool(report, "none_clear"), "none 条件命中 true 时 none_clear 应为 false。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 0, "MODE_NONE 命中 true 不是原始谓词失败。")
	assert_eq(GFVariantData.get_option_int(report, "blocking_count"), 1, "MODE_NONE 命中 true 应明确计入阻塞。")
	assert_eq(GFVariantData.get_option_int(report, "none_matched_count"), 1, "MODE_NONE 命中 true 应计入 none_matched_count。")


func test_execution_requirement_reports_predicate_failure() -> void:
	var requirement: GF_EXECUTION_REQUIREMENT_SCRIPT = GF_EXECUTION_REQUIREMENT_SCRIPT.new()
	var _configured: GF_EXECUTION_REQUIREMENT_SCRIPT = requirement.configure(&"budget")
	var _predicate_condition: Dictionary = requirement.add_predicate(&"has-budget", func(context: Dictionary) -> Dictionary:
		var budget: int = GFVariantData.get_option_int(context, "budget")
		return {
			"ok": budget > 0,
			"error": "budget_empty" if budget <= 0 else "",
		}
	)

	var report: Dictionary = requirement.evaluate({ "budget": 0 })
	var condition_reports: Array = GFVariantData.get_option_array(report, "conditions")
	var first_condition: Dictionary = GFVariantData.as_dictionary(condition_reports[0]) if not condition_reports.is_empty() else {}

	assert_false(GFVariantData.get_option_bool(report, "ok"), "谓词失败时 requirement 应失败。")
	assert_eq(GFVariantData.get_option_string(first_condition, "error"), "budget_empty", "谓词错误应进入条件报告。")
	assert_false(requirement.is_satisfied({ "budget": 0 }), "is_satisfied 应复用 evaluate 语义。")
