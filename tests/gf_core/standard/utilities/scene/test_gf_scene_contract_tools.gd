## 测试 GFSceneContractTools 的场景根节点契约检查能力。
extends GutTest


const BASE_SCRIPT: Script = preload("res://tests/gf_core/fixtures/scene_contract/scene_contract_base_node.gd")
const CHILD_SCRIPT: Script = preload("res://tests/gf_core/fixtures/scene_contract/scene_contract_child_node.gd")


func test_check_packed_scene_accepts_matching_root_contract() -> void:
	var scene: PackedScene = _make_scene("SampleContractRoot", PackedStringArray(["scene.contract"]))
	var report: Dictionary = GFSceneContractTools.check_packed_scene(scene, {
		"base_class": "Node2D",
		"base_script": BASE_SCRIPT,
		"required_groups": PackedStringArray(["scene.contract"]),
		"name_suffix": "Root",
		"script_structure": {
			"required_methods": PackedStringArray(["apply_contract_marker", "child_marker"]),
			"required_signals": PackedStringArray(["contract_ready"]),
		},
	}, {
		"scene_path": "res://tests/gf_core/fixtures/scene_contract/sample_contract_scene.tscn",
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "满足契约的场景根节点应通过检查。")
	assert_eq(GFVariantData.get_option_string(report, "root_script_path"), CHILD_SCRIPT.resource_path, "报告应记录实际根脚本路径。")
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "counts")
	assert_eq(GFVariantData.get_option_int(counts, "error_count"), 0, "不应产生错误。")


func test_check_packed_scene_reports_missing_group_and_name_mismatch() -> void:
	var scene: PackedScene = _make_scene("InvalidRoot", PackedStringArray())
	var report: Dictionary = GFSceneContractTools.check_packed_scene(scene, {
		"required_groups": PackedStringArray(["scene.contract"]),
		"name_suffix": "Component",
	})
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不满足契约时应失败。")
	assert_true(_has_issue_kind(issues, "missing_required_group"), "应报告缺失分组。")
	assert_true(_has_issue_kind(issues, "name_suffix_mismatch"), "应报告名称后缀不匹配。")


func test_check_scene_path_reports_missing_scene_without_loading() -> void:
	var report: Dictionary = GFSceneContractTools.check_scene_path(
		"res://tests/gf_core/fixtures/scene_contract/missing_scene.tscn"
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失场景路径应失败。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "scene_missing"), "应报告场景资源缺失。")


func test_scan_scene_paths_uses_scene_extensions_by_default() -> void:
	var paths: PackedStringArray = GFSceneContractTools.scan_scene_paths("res://tests/gf_core/fixtures", {
		"recursive": false,
		"include_addons": true,
	})

	assert_true(paths.has("res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"), "默认应扫描 tscn 场景。")
	assert_false(paths.has("res://tests/gf_core/fixtures/scene_signal_audit_receiver.gd"), "默认不应扫描脚本文件。")


func test_validation_rule_integrates_with_validation_runner_scene_instances() -> void:
	var rule: GFValidationRule = GFSceneContractTools.make_validation_rule({
		"required_groups": PackedStringArray(["scene.contract"]),
		"name_prefix": "Sample",
	})
	var suite: GFValidationSuite = GFValidationSuite.new()
	assert_true(suite.add_rule(rule), "场景契约规则应能加入通用校验套件。")
	var scene: PackedScene = _make_scene("OtherRoot", PackedStringArray())
	var root: Node = scene.instantiate()

	var runner_report: GFValidationReport = GFValidationRunner.new().run_targets([root], suite)
	root.free()

	assert_false(runner_report.is_ok(), "ValidationRunner 应能接收场景契约规则产生的问题。")
	assert_eq(runner_report.get_error_count(), 2, "应聚合缺失分组和名称前缀错误。")


func _make_scene(root_name: String, groups: PackedStringArray) -> PackedScene:
	var root: Node2D = Node2D.new()
	root.name = root_name
	root.set_script(CHILD_SCRIPT)
	for group_name: String in groups:
		root.add_to_group(group_name, true)

	var scene: PackedScene = PackedScene.new()
	var pack_error: Error = scene.pack(root)
	assert_eq(pack_error, OK, "测试场景应能打包。")
	root.free()
	return scene


func _has_issue_kind(issues: Array, issue_kind: String) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == issue_kind:
			return true
	return false
