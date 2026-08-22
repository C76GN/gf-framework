extends GutTest

const PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"
const PROFILE_CONTRACT_PATH: String = "res://addons/gf/tools/project_layout/contracts/project_profile_v1.contract.json"
const PROFILE_CONFORMANCE_FIXTURE_PATH: String = "res://tests/gf_core/tools/project_layout/fixtures/profile_conformance_v1.json"
const GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd")
const GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd")
const GF_PROJECT_LAYOUT_PLANNER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_planner.gd")
const GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_profile_compiler.gd")
const GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_validator.gd")
const _PLAN_FIELDS: PackedStringArray = [
	"schema_version",
	"kind",
	"complete",
	"profile_id",
	"source_analysis_digest",
	"contract_digest",
	"project_root",
	"capabilities",
	"steps",
	"blockers",
	"issues",
]
const _PLAN_CAPABILITY_FIELDS: PackedStringArray = [
	"writes_project",
	"planning_scope",
	"supported_rule_kinds",
	"ignored_rule_kinds",
]
const _PLAN_STEP_FIELDS: PackedStringArray = [
	"step_id",
	"kind",
	"relative_path",
	"requires",
	"evidence_ids",
	"preconditions",
	"risk",
]
const _COMPILATION_FIELDS: PackedStringArray = [
	"success",
	"profile",
	"issues",
	"error_count",
	"warning_count",
	"contract_id",
	"contract_digest",
	"capabilities",
]
const _FORBIDDEN_PLAN_FIELDS: PackedStringArray = [
	"apply",
	"command",
	"created_paths",
	"dry_run",
	"operations",
	"rollback_failed_paths",
	"rolled_back_paths",
	"target_path",
]
const _CONFORMANCE_FIXTURE_FIELDS: PackedStringArray = ["fixture_schema_version", "cases"]
const _CONFORMANCE_CASE_FIELDS: PackedStringArray = ["id", "profile", "inventory", "expected"]
const _CONFORMANCE_EXPECTED_FIELDS: PackedStringArray = [
	"strict_contract_valid",
	"reason_code",
	"godot_reason_code",
	"godot_validator_success",
	"godot_planner_complete",
	"godot_validator_reason_codes",
	"godot_planner_reason_codes",
	"godot_validator_issue_kinds",
	"godot_planner_issue_kinds",
	"godot_validator_rule_checked_count",
	"godot_validator_rule_issue_count",
	"godot_validator_rule_severity",
	"python_issue_count",
	"python_runtime_issue_kinds",
	"python_runtime_reason_code",
	"python_runtime_issue_path",
	"excluded_path",
]
const _CONFORMANCE_CASE_IDS: PackedStringArray = [
	"valid_common_profile",
	"unsupported_schema_version",
	"whitespace_profile_id",
	"whitespace_regex",
	"whitespace_string_list_item",
	"invalid_enum_value",
	"positive_integer_wrong_type",
	"mixed_zone_roots",
	"accepted_compatibility_operand",
	"zone_extension_scope",
	"python_only_rule",
	"invalid_naming_regex",
	"unsafe_nested_quantifier_regex",
	"unsafe_dialect_escape_regex",
	"unsafe_non_ascii_class_regex",
	"unsafe_unanchored_quantifier_regex",
	"exact_integer_float",
	"exact_integer_bool",
	"exact_integer_fractional",
	"duplicate_collection_values",
	"naming_regex_search",
	"feature_empty_allowed_subdirs",
	"glob_single_star_segment",
	"glob_leading_double_star_zero_segments",
	"missing_zones",
	"invalid_relative_dot_prefix",
	"invalid_glob_question_mark",
	"glob_leading_double_star_segment_boundary",
	"feature_id_regex_search",
	"multiple_feature_contracts",
	"glob_middle_double_star_zero_and_multi_segments",
	"glob_extension_case_sensitive",
	"extension_canonical_duplicate",
]

var _temporary_roots: Array[String] = []


func before_each() -> void:
	_temporary_roots.clear()


func after_each() -> void:
	for root_path: String in _temporary_roots:
		_remove_directory_tree(root_path)
	_temporary_roots.clear()


func test_feature_cohesive_profile_is_an_explicit_valid_example() -> void:
	assert_true(FileAccess.file_exists(PROFILE_PATH), "Feature 内聚式示例 profile 必须随工具包发布。")
	var profile_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	assert_true(profile_value is Dictionary, "示例 profile 必须是 JSON Dictionary。")
	if not profile_value is Dictionary:
		return
	var profile: Dictionary = profile_value
	assert_eq(GFVariantData.get_option_int(profile, "schema_version"), 1)
	assert_eq(GFVariantData.get_option_string(profile, "id"), "gf.project_layout.feature_cohesive.v1")
	var rule_kinds: PackedStringArray = PackedStringArray()
	for rule_value: Variant in GFVariantData.get_option_array(profile, "rules"):
		if rule_value is Dictionary:
			var rule: Dictionary = rule_value
			var _append_rule_kind: bool = rule_kinds.append(GFVariantData.get_option_string(rule, "kind"))
	assert_true(rule_kinds.has("feature_module_contract"))
	assert_true(rule_kinds.has("generated_boundary"))
	assert_true(rule_kinds.has("bucket_size"))


func test_project_layout_script_uids_round_trip_through_resource_uid() -> void:
	for uid_path: String in [
		"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd.uid",
		"res://addons/gf/tools/project_layout/gf_project_layout_profile_compiler.gd.uid",
		"res://addons/gf/tools/project_layout/gf_project_layout_planner.gd.uid",
	]:
		var uid_text: String = FileAccess.get_file_as_string(uid_path).strip_edges()
		var resource_id: int = ResourceUID.text_to_id(uid_text)
		assert_ne(resource_id, ResourceUID.INVALID_ID, "sidecar 必须是 Godot 可解析的 ResourceUID：%s。" % uid_path)
		assert_eq(ResourceUID.id_to_text(resource_id), uid_text, "ResourceUID 必须稳定 round-trip：%s。" % uid_path)


func test_project_layout_analysis_contract_rejects_minimal_graph_counterexamples() -> void:
	var root_path: String = _make_empty_test_root("analysis_contract")
	_make_directory(root_path.path_join("alpha/child"))
	_write_text(root_path.path_join("alpha/data.txt"), "fixture\n")
	var analysis: Dictionary = _analyze_root(root_path)
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	var baseline: Dictionary = contract.validate_and_index(analysis)
	assert_true(GFVariantData.get_option_bool(baseline, "valid"))
	var counterexample_ids: PackedStringArray = [
		"unknown_field",
		"deleted_node",
		"changed_node",
		"wrong_parent",
		"dangling_evidence",
		"count_mismatch",
		"status_mismatch",
		"boundary_mismatch",
		"digest_mismatch",
		"scope_mismatch",
	]
	for counterexample_id: String in counterexample_ids:
		var poisoned: Dictionary = analysis.duplicate(true)
		_poison_analysis_contract_case(poisoned, counterexample_id, contract)
		var validation: Dictionary = contract.validate_and_index(poisoned)
		assert_false(
			GFVariantData.get_option_bool(validation, "valid"),
			"contract 必须拒绝最小反例：%s。" % counterexample_id
		)
		assert_false(
			GFVariantData.get_option_array(validation, "errors").is_empty(),
			"拒绝结果必须给出结构化原因：%s。" % counterexample_id
		)


func test_project_layout_analysis_contract_uses_weighted_terminal_checkpoint() -> void:
	var root_path: String = _make_empty_test_root("analysis_weighted_checkpoint")
	_make_directory(root_path.path_join("alpha/child"))
	_write_text(root_path.path_join("alpha/data.txt"), "fixture\n")
	var analysis: Dictionary = _analyze_root(root_path)
	var accepting_probe: WeightedCheckpointProbe = WeightedCheckpointProbe.new()
	var accepted: Dictionary = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new().validate_and_index(
			analysis,
			Callable(accepting_probe, "consume")
		)
	)

	assert_true(GFVariantData.get_option_bool(accepted, "valid"))
	assert_gt(accepting_probe.call_count, 1)
	assert_gt(accepting_probe.total_work_units, accepting_probe.call_count)
	assert_true(accepting_probe.all_batches_positive)

	var cancelling_probe: WeightedCheckpointProbe = WeightedCheckpointProbe.new()
	cancelling_probe.stop_after_work_units = 64
	var cancelled: Dictionary = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new().validate_and_index(
			analysis,
			Callable(cancelling_probe, "consume")
		)
	)
	_assert_analysis_contract_checkpoint_terminal(
		cancelled,
		"analysis_contract_cancelled"
	)
	assert_gte(cancelling_probe.total_work_units, 64)

	var invalid_arity: Dictionary = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new().validate_and_index(
			analysis,
			Callable(self, "_planner_never_cancel")
		)
	)
	_assert_analysis_contract_checkpoint_terminal(
		invalid_arity,
		"analysis_contract_checkpoint_invalid"
	)


func test_project_layout_analysis_contract_ids_ignore_unrelated_inventory_and_findings() -> void:
	var root_path: String = _make_empty_test_root("stable_ids")
	_make_directory(root_path.path_join("alpha"))
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var first_analysis: Dictionary = analyzer.analyze_profile(
		_make_required_zones_profile([
			{ "id": "alpha_zone", "root": "missing_alpha" },
			{ "id": "beta_zone", "root": "missing_beta" },
		]),
		{ "root_path": root_path }
	)
	var first_alpha_id: String = _finding_id_for_path(first_analysis, "missing_alpha")
	var first_beta_id: String = _finding_id_for_path(first_analysis, "missing_beta")
	assert_false(first_alpha_id.is_empty())
	assert_false(first_beta_id.is_empty())
	var second_analysis: Dictionary = analyzer.analyze_profile(
		_make_required_zones_profile([
			{ "id": "unrelated_zone", "root": "missing_unrelated" },
			{ "id": "alpha_zone", "root": "missing_alpha" },
			{ "id": "beta_zone", "root": "missing_beta" },
		]),
		{ "root_path": root_path }
	)
	assert_eq(_finding_id_for_path(second_analysis, "missing_alpha"), first_alpha_id)
	assert_eq(_finding_id_for_path(second_analysis, "missing_beta"), first_beta_id)

	var first_edge_id: String = _edge_id_to_path(first_analysis, "alpha")
	_write_text(root_path.path_join("unrelated.txt"), "fixture\n")
	var inventory_changed: Dictionary = analyzer.analyze({ "root_path": root_path })
	assert_eq(_edge_id_to_path(inventory_changed, "alpha"), first_edge_id)


func test_project_layout_incomplete_analyses_are_structurally_valid_but_not_operable() -> void:
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var missing_root: String = _track_root(
		"res://build/gf_project_layout_tests/not_started_%d" % Time.get_ticks_usec()
	)
	var not_started: Dictionary = analyzer.analyze({
		"root_path": missing_root,
		"allow_missing_root": true,
	})
	_assert_incomplete_analysis_policy(
		not_started,
		"not_started",
		analyzer,
		planner,
		contract
	)

	var partial_root: String = _make_empty_test_root("partial_contract")
	var partial: Dictionary = analyzer.analyze({
		"root_path": partial_root,
		"include_hidden": false,
	})
	_assert_incomplete_analysis_policy(
		partial,
		"partial",
		analyzer,
		planner,
		contract
	)


func test_profile_conformance_fixture_schema_and_case_ids_are_closed() -> void:
	var fixture: Dictionary = _load_profile_conformance_fixture()
	assert_true(_dictionary_has_exact_fields(fixture, _CONFORMANCE_FIXTURE_FIELDS))
	assert_true(_is_exact_integer_value(fixture.get("fixture_schema_version")))
	assert_eq(_exact_integer_value(fixture.get("fixture_schema_version")), 1)
	var case_ids: PackedStringArray = PackedStringArray()
	for case_value: Variant in GFVariantData.get_option_array(fixture, "cases"):
		assert_true(case_value is Dictionary)
		if not case_value is Dictionary:
			continue
		var fixture_case: Dictionary = case_value
		assert_true(_dictionary_has_exact_fields(fixture_case, _CONFORMANCE_CASE_FIELDS))
		var case_id: String = GFVariantData.get_option_string(fixture_case, "id")
		assert_false(case_id.is_empty())
		assert_false(case_ids.has(case_id), "fixture case ID 不能重复：%s。" % case_id)
		var _append_case_id: bool = case_ids.append(case_id)
		assert_true(fixture_case.get("profile") is Dictionary)
		assert_true(fixture_case.get("inventory") is Array)
		var expected_value: Variant = fixture_case.get("expected")
		assert_true(expected_value is Dictionary)
		if not expected_value is Dictionary:
			continue
		var expected: Dictionary = expected_value
		assert_true(_dictionary_has_only_fields(expected, _CONFORMANCE_EXPECTED_FIELDS))
		for bool_field: String in ["strict_contract_valid", "godot_validator_success", "godot_planner_complete"]:
			assert_true(expected.get(bool_field) is bool, "%s 必须是 bool。" % bool_field)
		for issue_field: String in ["godot_validator_issue_kinds", "godot_planner_issue_kinds"]:
			assert_true(_is_string_array(expected.get(issue_field)), "%s 必须是字符串数组。" % issue_field)
		for optional_array_field: String in [
			"godot_validator_reason_codes",
			"godot_planner_reason_codes",
			"python_runtime_issue_kinds",
		]:
			if expected.has(optional_array_field):
				assert_true(_is_string_array(expected[optional_array_field]))
	assert_eq(case_ids.size(), _CONFORMANCE_CASE_IDS.size())
	for expected_case_id: String in _CONFORMANCE_CASE_IDS:
		assert_true(case_ids.has(expected_case_id), "共享 fixture 缺少 case：%s。" % expected_case_id)


func test_project_layout_compiler_rejects_plan_registry_handler_with_wrong_arity() -> void:
	var compiler: GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT = GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT.new()
	var result: Dictionary = compiler.compile_profile(_make_minimal_feature_profile(), {
		"executor_id": "invalid_plan_fixture",
		"operation": "plan",
		"rule_registry": {
			"feature_module_contract": {
				"handler": Callable(self, "_invalid_registry_handler_arity"),
				"executed_fields": PackedStringArray(["roots"]),
			},
		},
		"unsupported_rule_policy": "schema_only",
		"zone_executed_fields": PackedStringArray(),
	})
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_true(_has_issue_reason_code(
		GFVariantData.get_option_array(result, "issues"),
		"PROJECT_LAYOUT_PROFILE_REGISTRY_INVALID"
	))
	assert_true(GFVariantData.get_option_dictionary(result, "capabilities").is_empty())


func test_project_layout_compilation_binds_the_canonical_contract_digest() -> void:
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(_make_minimal_feature_profile())
	var actual_contract_digest: String = FileAccess.get_sha256(PROFILE_CONTRACT_PATH)

	assert_true(
		GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			actual_contract_digest
		),
		"派生的 canonical digest pin 必须与规范 contract bytes 同步。"
	)
	assert_false(
		GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT.contract_digest_is_canonical_for_framework(
			"0".repeat(64)
		),
		"只有格式正确但不匹配规范 contract bytes 的摘要必须失败关闭。"
	)
	assert_true(GFVariantData.get_option_bool(compilation, "success"))
	assert_true(_dictionary_has_exact_fields(compilation, _COMPILATION_FIELDS))
	assert_eq(
		GFVariantData.get_option_string(compilation, "contract_digest"),
		actual_contract_digest,
		"成功 compilation 必须绑定实际完成解析的 canonical contract bytes。"
	)


func test_project_layout_compiler_resource_limits_are_terminal_and_fail_closed() -> void:
	var compiler: GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT = GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT.new()
	var oversized_rules: Array = []
	var _oversized_resize_result: int = oversized_rules.resize(8_193)
	var oversized_profile: Dictionary = _make_minimal_feature_profile()
	oversized_profile["rules"] = oversized_rules
	var oversized_result: Dictionary = compiler.compile_profile(oversized_profile, {})
	_assert_compiler_resource_limit(oversized_result)

	var diagnostic_rules: Array = []
	var _diagnostic_resize_result: int = diagnostic_rules.resize(256)
	var diagnostic_profile: Dictionary = _make_minimal_feature_profile()
	diagnostic_profile["rules"] = diagnostic_rules
	var diagnostic_result: Dictionary = compiler.compile_profile(
		diagnostic_profile,
		_make_valid_plan_compiler_scope()
	)
	_assert_compiler_resource_limit(diagnostic_result)

	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	var cyclic_profile: Dictionary = _make_minimal_feature_profile()
	cyclic_profile["metadata"] = cyclic_metadata
	var first_cyclic_result: Dictionary = compiler.compile_profile(cyclic_profile, {})
	var second_cyclic_result: Dictionary = compiler.compile_profile(cyclic_profile, {})
	_assert_compiler_resource_limit(first_cyclic_result)
	assert_eq(first_cyclic_result, second_cyclic_result, "循环 profile 的 terminal 结果必须稳定。")


func test_project_layout_analysis_contract_resource_limits_are_terminal_and_bounded() -> void:
	var root_path: String = _make_empty_test_root("analysis_limits")
	var baseline: Dictionary = _analyze_root(root_path)
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)

	var oversized: Dictionary = baseline.duplicate(true)
	var oversized_graph_value: Variant = oversized.get("graph")
	assert_true(oversized_graph_value is Dictionary)
	if not oversized_graph_value is Dictionary:
		return
	var oversized_graph: Dictionary = oversized_graph_value
	var oversized_nodes: Array = []
	var _oversized_resize_result: int = oversized_nodes.resize(50_002)
	oversized_graph["nodes"] = oversized_nodes
	var first_oversized_result: Dictionary = contract.validate_and_index(oversized)
	var second_oversized_result: Dictionary = contract.validate_and_index(oversized)
	_assert_analysis_contract_resource_limit(first_oversized_result)
	assert_eq(first_oversized_result, second_oversized_result, "超量 analysis 的 terminal 结果必须稳定。")

	var diagnostic_heavy: Dictionary = baseline.duplicate(true)
	var diagnostic_graph_value: Variant = diagnostic_heavy.get("graph")
	assert_true(diagnostic_graph_value is Dictionary)
	if not diagnostic_graph_value is Dictionary:
		return
	var diagnostic_graph: Dictionary = diagnostic_graph_value
	var invalid_nodes: Array = []
	var _diagnostic_resize_result: int = invalid_nodes.resize(128)
	diagnostic_graph["nodes"] = invalid_nodes
	_assert_analysis_contract_resource_limit(contract.validate_and_index(diagnostic_heavy))

	var directories: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = PackedStringArray()
	for inventory_index: int in 20_000:
		var _append_directory: bool = directories.append(
			"directory_%05d" % inventory_index
		)
		var _append_file: bool = files.append(
			"file_%05d.gd" % inventory_index
		)
	var inventory: Dictionary = {
		"scope": _make_inventory_scope(root_path),
		"capture_status": "complete",
		"complete": true,
		"root_observed": true,
		"directories": directories,
		"files": files,
	}
	var attachment: Dictionary = contract.build_inventory_attachment(
		root_path,
		inventory
	)
	assert_false(attachment.is_empty(), "真实 20k+20k 库存必须能生成 attachment。")
	var graph: Dictionary = GFVariantData.get_option_dictionary(attachment, "graph")
	assert_eq(GFVariantData.get_option_array(graph, "nodes").size(), 40_001)
	assert_eq(GFVariantData.get_option_array(graph, "edges").size(), 40_000)
	assert_eq(GFVariantData.get_option_array(graph, "evidence").size(), 40_002)
	var maximum_inventory_analysis: Dictionary = _make_analysis_from_inventory_attachment(
		root_path,
		attachment
	)
	var headroom_result: Dictionary = contract.validate_and_index(
		maximum_inventory_analysis
	)
	assert_true(
		GFVariantData.get_option_bool(headroom_result, "valid"),
		"20k files + 20k directories + root 的真实 40001-node graph 必须完整通过 contract。"
	)
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(_make_minimal_feature_profile())
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var maximum_inventory_plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		maximum_inventory_analysis,
		{},
		{
			"cancel_check": Callable(self, "_planner_never_cancel"),
			"max_work_units": GF_PROJECT_LAYOUT_PLANNER_SCRIPT.MAX_WORK_UNITS,
		}
	)
	assert_true(
		GFVariantData.get_option_bool(maximum_inventory_plan, "complete"),
		"Planner 必须为 40001-node production graph 的多轮 contract 验证保留明确余量。"
	)
	assert_false(_has_issue_kind(
		GFVariantData.get_option_array(maximum_inventory_plan, "issues"),
		"planner_resource_limit_exceeded"
	))
	assert_gt(
		GF_PROJECT_LAYOUT_PLANNER_SCRIPT.MAX_WORK_UNITS,
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.MAX_VALIDATION_WORK_UNITS,
		"Planner 总预算必须在完整 analysis 校验硬上限之外保留自身规划余量。"
	)
	var tightened_plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		maximum_inventory_analysis,
		{},
		{
			"cancel_check": Callable(self, "_planner_never_cancel"),
			"max_work_units": 1,
		}
	)
	_assert_planner_resource_limit(tightened_plan)


func test_project_layout_analysis_contract_rejects_cyclic_and_deep_finding_contexts() -> void:
	var root_path: String = _make_empty_test_root("analysis_nested_limits")
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var baseline: Dictionary = analyzer.analyze_profile(
		_make_required_zone_profile("missing_zone"),
		{ "root_path": root_path }
	)
	assert_false(GFVariantData.get_option_array(baseline, "findings").is_empty())
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)

	var cyclic: Dictionary = baseline.duplicate(true)
	var cyclic_context: Dictionary = {}
	cyclic_context["self"] = cyclic_context
	_replace_first_finding_context(cyclic, cyclic_context)
	var first_cyclic_result: Dictionary = contract.validate_and_index(cyclic)
	var second_cyclic_result: Dictionary = contract.validate_and_index(cyclic)
	_assert_analysis_contract_resource_limit(first_cyclic_result)
	assert_eq(first_cyclic_result, second_cyclic_result, "循环 context 的 terminal 结果必须稳定。")

	var deep: Dictionary = baseline.duplicate(true)
	var deep_context: Dictionary = {}
	var cursor: Dictionary = deep_context
	for depth_index: int in 70:
		var child: Dictionary = { "depth": depth_index }
		cursor["next"] = child
		cursor = child
	_replace_first_finding_context(deep, deep_context)
	_assert_analysis_contract_resource_limit(contract.validate_and_index(deep))
	var stable_id_deep: Dictionary = baseline.duplicate(true)
	var stable_context: Dictionary = {}
	var stable_cursor: Dictionary = stable_context
	for depth_index: int in 12:
		var stable_child: Dictionary = { "depth": depth_index }
		stable_cursor["next"] = stable_child
		stable_cursor = stable_child
	_replace_first_finding_context(stable_id_deep, stable_context)
	_assert_analysis_contract_resource_limit(
		contract.validate_and_index(stable_id_deep)
	)

	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var cyclic_plan: Dictionary = planner.plan_profile(_make_minimal_feature_profile(), cyclic)
	assert_false(GFVariantData.get_option_bool(cyclic_plan, "complete"))
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(cyclic_plan, "issues"),
		"invalid_source_analysis"
	))
	_assert_closed_plan_schema(cyclic_plan)
	var invalid_source_path_plan: Dictionary = planner.plan_profile_path(
		"res://build/gf_project_layout_tests/must_not_be_loaded.json",
		cyclic
	)
	var invalid_source_path_issues: Array = GFVariantData.get_option_array(
		invalid_source_path_plan,
		"issues"
	)
	assert_true(_has_issue_kind(invalid_source_path_issues, "invalid_source_analysis"))
	assert_false(
		_has_issue_kind(invalid_source_path_issues, "profile_load_failed"),
		"无效 source analysis 后必须在读取 profile 文件前立即返回。"
	)


func test_project_layout_analysis_contract_rejects_non_json_values_before_consumers() -> void:
	var root_path: String = _make_empty_test_root("analysis_non_json")
	var baseline: Dictionary = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new().analyze_profile(
		_make_required_zone_profile("missing_zone"),
		{ "root_path": root_path }
	)
	var invalid_contexts: Array[Dictionary] = [
		{ "payload": RefCounted.new() },
		{ "payload": Callable(self, "_valid_plan_registry_handler") },
		{ "payload": PackedInt32Array([1, 2, 3]) },
		{ 1: "non_string_key" },
	]
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	for invalid_context: Dictionary in invalid_contexts:
		var poisoned: Dictionary = baseline.duplicate(true)
		_replace_first_finding_context(poisoned, invalid_context)
		var first_validation: Dictionary = contract.validate_and_index(poisoned)
		var second_validation: Dictionary = contract.validate_and_index(poisoned)
		_assert_analysis_contract_resource_limit(first_validation)
		assert_eq(first_validation, second_validation)
		_assert_invalid_analysis_consumers_fail_closed(poisoned)
	var poisoned_capabilities: Dictionary = baseline.duplicate(true)
	poisoned_capabilities["capabilities"] = { "payload": RefCounted.new() }
	var capabilities_validation: Dictionary = contract.validate_and_index(
		poisoned_capabilities
	)
	_assert_analysis_contract_resource_limit(capabilities_validation)
	assert_eq(
		capabilities_validation,
		contract.validate_and_index(poisoned_capabilities)
	)
	_assert_invalid_analysis_consumers_fail_closed(poisoned_capabilities)


func test_project_layout_empty_inventory_digest_is_a_resource_terminal() -> void:
	var root_path: String = _make_empty_test_root("analysis_empty_digest")
	var forged: Dictionary = _make_forged_oversized_inventory_analysis(
		root_path,
		1_025
	)
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	var first_validation: Dictionary = contract.validate_and_index(forged)
	var second_validation: Dictionary = contract.validate_and_index(forged)
	_assert_analysis_contract_resource_limit(first_validation)
	assert_eq(first_validation, second_validation)
	_assert_invalid_analysis_consumers_fail_closed(forged)


func test_project_layout_contract_producers_have_intrinsic_resource_limits() -> void:
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	var root_path: String = "res://build/gf_project_layout_tests/producer_limits"
	var scope: Dictionary = _make_inventory_scope(root_path)
	var oversized_files: PackedStringArray = PackedStringArray()
	var _oversized_resize_result: int = oversized_files.resize(20_001)
	var oversized_inventory: Dictionary = {
		"scope": scope,
		"capture_status": "complete",
		"complete": true,
		"root_observed": true,
		"directories": PackedStringArray(),
		"files": oversized_files,
	}
	assert_true(
		contract.build_inventory_attachment(root_path, oversized_inventory).is_empty(),
		"producer 必须在复制、排序和建图前拒绝超量库存。"
	)
	assert_true(
		contract.inventory_digest(
			root_path,
			scope,
			"complete",
			true,
			true,
			PackedStringArray(),
			oversized_files
		).is_empty(),
		"digest 公共入口不能依赖调用方 checkpoint 才有界。"
	)

	var cyclic_scope: Dictionary = _make_inventory_scope(root_path)
	var cyclic_exclusions: Array = [".git", ".godot", ".import"]
	cyclic_exclusions.append(cyclic_scope)
	cyclic_scope["excluded_prefixes"] = cyclic_exclusions
	var cyclic_inventory: Dictionary = oversized_inventory.duplicate(false)
	cyclic_inventory["scope"] = cyclic_scope
	cyclic_inventory["files"] = PackedStringArray()
	var first_cyclic_attachment: Dictionary = contract.build_inventory_attachment(
		root_path,
		cyclic_inventory
	)
	var second_cyclic_attachment: Dictionary = contract.build_inventory_attachment(
		root_path,
		cyclic_inventory
	)
	assert_true(first_cyclic_attachment.is_empty())
	assert_eq(first_cyclic_attachment, second_cyclic_attachment)

	var cyclic_context: Dictionary = {}
	cyclic_context["self"] = cyclic_context
	var cyclic_finding: Dictionary = {
		"severity": "warning",
		"kind": "cyclic_context",
		"path": "",
		"message": "fixture",
		"context": cyclic_context,
		"confidence": "known",
		"evidence_ids": [],
	}
	assert_eq(contract.stable_finding_id(cyclic_finding, 0), "")
	assert_eq(
		contract.stable_finding_id(cyclic_finding, 0),
		contract.stable_finding_id(cyclic_finding, 0),
		"循环 finding 的拒绝结果必须稳定。"
	)
	assert_eq(
		contract.stable_edge_id(
			"contains",
			"path:%s" % "x".repeat(16_384),
			"path:target",
			"project_source"
		),
		"",
		"stable_edge_id 必须在拼接和 hash 前拒绝超长 endpoint。"
	)


func test_project_layout_compiler_rejects_oversized_operation_scope_before_registry_walk() -> void:
	var compiler: GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT = (
		GF_PROJECT_LAYOUT_PROFILE_COMPILER_SCRIPT.new()
	)
	var huge_registry: Dictionary = {}
	for registry_index: int in 65:
		huge_registry["rule_%03d" % registry_index] = {
			"handler": Callable(self, "_valid_plan_registry_handler"),
			"executed_fields": PackedStringArray(),
		}
	var operation_scope: Dictionary = _make_valid_plan_compiler_scope()
	operation_scope["rule_registry"] = huge_registry
	var first_result: Dictionary = compiler.compile_profile(
		_make_minimal_feature_profile(),
		operation_scope
	)
	var second_result: Dictionary = compiler.compile_profile(
		_make_minimal_feature_profile(),
		operation_scope
	)
	_assert_compiler_resource_limit(first_result)
	assert_eq(first_result, second_result, "超量 operation_scope 必须稳定 fail-closed。")


func test_project_layout_planner_public_inputs_have_intrinsic_resource_limits() -> void:
	var root_path: String = _make_empty_test_root("planner_public_limits")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var oversized_options: Dictionary = {
		"feature_ids": ["inventory"],
		"include_optional_zones": false,
		"include_optional_feature_subdirs": false,
		"unexpected": false,
	}
	var first_option_plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		source_analysis,
		oversized_options
	)
	var second_option_plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		source_analysis,
		oversized_options
	)
	_assert_planner_resource_limit(first_option_plan)
	assert_eq(first_option_plan, second_option_plan)

	var feature_ids: Array = []
	var _feature_resize_result: int = feature_ids.resize(257)
	feature_ids.fill("inventory")
	_assert_planner_resource_limit(planner.plan_profile(
		_make_minimal_feature_profile(),
		source_analysis,
		{ "feature_ids": feature_ids }
	))
	assert_true(
		planner.make_feature_module_paths(
			_make_minimal_feature_profile(),
			"a".repeat(257)
		).is_empty(),
		"helper 必须在 regex/path 拼接前拒绝超长 feature_id。"
	)
	assert_true(
		planner.make_feature_module_paths(
			_make_candidate_heavy_feature_profile(),
			"inventory"
		).is_empty(),
		"helper 超过候选路径 hard cap 时必须返回空结果。"
	)
	var unique_feature_plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		source_analysis,
		{ "feature_ids": ["inventory"] }
	)
	var duplicate_feature_plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		source_analysis,
		{ "feature_ids": ["inventory", "inventory"] }
	)
	assert_true(
		GFVariantData.get_option_bool(unique_feature_plan, "complete"),
		"单个合法 feature_id 必须生成完整计划。"
	)
	assert_true(
		GFVariantData.get_option_bool(duplicate_feature_plan, "complete"),
		"重复 feature_id 去重后仍必须生成完整计划。"
	)
	assert_eq(
		duplicate_feature_plan,
		unique_feature_plan,
		"重复 feature_ids 必须用有界集合去重并生成完全相同的计划。"
	)


func test_project_layout_impact_and_explainer_bound_public_strings_and_dictionaries() -> void:
	var root_path: String = _make_empty_test_root("consumer_public_limits")
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile(
		_make_required_zone_profile("missing_zone"),
		{ "root_path": root_path }
	)
	var huge_change: Dictionary = {
		"kind": "delete",
		"source_path": "missing_zone",
		"target_path": "",
		"unexpected": "value",
	}
	var first_impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		huge_change
	)
	var second_impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		huge_change
	)
	assert_eq(GFVariantData.get_option_string(first_impact, "status"), "unknown")
	assert_false(GFVariantData.get_option_bool(first_impact, "complete"))
	assert_true(GFVariantData.get_option_dictionary(first_impact, "change").is_empty())
	assert_eq(GFVariantData.get_option_array(first_impact, "issues").size(), 1)
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(first_impact, "issues"),
		"impact_resource_limit_exceeded"
	))
	assert_eq(first_impact, second_impact)
	var unknown_change: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{ "unexpected": "value" }
	)
	assert_eq(GFVariantData.get_option_string(unknown_change, "status"), "unknown")
	assert_true(GFVariantData.get_option_dictionary(unknown_change, "change").is_empty())
	assert_eq(GFVariantData.get_option_array(unknown_change, "issues").size(), 1)
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(unknown_change, "issues"),
		"impact_resource_limit_exceeded"
	))
	var non_string_change: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{
			"kind": "delete",
			"source_path": RefCounted.new(),
			"target_path": "",
		}
	)
	assert_eq(GFVariantData.get_option_string(non_string_change, "status"), "unknown")
	assert_true(GFVariantData.get_option_dictionary(non_string_change, "change").is_empty())
	assert_eq(GFVariantData.get_option_array(non_string_change, "issues").size(), 1)
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(non_string_change, "issues"),
		"impact_resource_limit_exceeded"
	))
	var oversized_digest_analysis: Dictionary = analysis.duplicate(true)
	oversized_digest_analysis["input_digest"] = "d".repeat(16_385)
	var cyclic_analysis: Dictionary = analysis.duplicate(true)
	var cyclic_context: Dictionary = {}
	cyclic_context["self"] = cyclic_context
	_replace_first_finding_context(cyclic_analysis, cyclic_context)
	var invalid_analyses: Array[Dictionary] = [
		{},
		oversized_digest_analysis,
		cyclic_analysis,
	]
	for invalid_analysis: Dictionary in invalid_analyses:
		var invalid_impact: Dictionary = analyzer.analyze_change_impact(
			invalid_analysis,
			{
				"kind": "delete",
				"source_path": "missing_zone",
				"target_path": "",
			}
		)
		assert_eq(GFVariantData.get_option_string(invalid_impact, "status"), "unsafe")
		assert_false(GFVariantData.get_option_bool(invalid_impact, "complete"))
		assert_eq(
			GFVariantData.get_option_string(invalid_impact, "source_analysis_digest"),
			"",
			"未通过 contract 的 analysis 不得把未验证 digest 带入终态。"
		)
		assert_true(GFVariantData.get_option_dictionary(invalid_impact, "change").is_empty())
		var invalid_impact_issues: Array = GFVariantData.get_option_array(
			invalid_impact,
			"issues"
		)
		assert_eq(invalid_impact_issues.size(), 1)
		assert_true(_has_issue_kind(invalid_impact_issues, "invalid_analysis"))
		assert_eq(
			invalid_impact,
			analyzer.analyze_change_impact(
				invalid_analysis,
				{
					"kind": "delete",
					"source_path": "missing_zone",
					"target_path": "",
				}
			),
			"无效、超长或循环 analysis 的拒绝结果必须稳定。"
		)

	var explanation: Dictionary = analyzer.explain_finding(
		analysis,
		"f".repeat(257)
	)
	assert_false(GFVariantData.get_option_bool(explanation, "complete"))
	assert_eq(GFVariantData.get_option_string(explanation, "finding_id"), "")
	assert_eq(GFVariantData.get_option_array(explanation, "issues").size(), 1)
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(explanation, "issues"),
		"explanation_resource_limit_exceeded"
	))


func test_profile_conformance_fixture_godot_expectations_are_consumed() -> void:
	var validator: GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT = GF_PROJECT_LAYOUT_VALIDATOR_SCRIPT.new()
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	for case_id: String in _CONFORMANCE_CASE_IDS:
		var fixture_case: Dictionary = _get_profile_conformance_case(case_id)
		var profile: Dictionary = GFVariantData.get_option_dictionary(fixture_case, "profile")
		var expected: Dictionary = GFVariantData.get_option_dictionary(fixture_case, "expected")
		var root_path: String = _track_root(
			"res://build/gf_project_layout_tests/conformance_%s_%d" % [case_id, Time.get_ticks_usec()]
		)
		_materialize_fixture_inventory(fixture_case, root_path)
		var source_analysis: Dictionary = _analyze_root(root_path)
		var validate_result: Dictionary = validator.validate_profile(profile, { "root_path": root_path })
		var plan: Dictionary = planner.plan_profile(profile, source_analysis)
		_assert_conformance_result(case_id, expected, validate_result, plan)


func test_project_layout_plan_schema_is_closed_relative_and_read_only() -> void:
	var root_path: String = _make_empty_test_root("schema")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var before_digest: String = _tree_digest(root_path)
	var plan: Dictionary = planner.plan_profile_path(PROFILE_PATH, source_analysis, {
		"feature_ids": ["inventory"],
	})
	var after_digest: String = _tree_digest(root_path)

	assert_true(GFVariantData.get_option_bool(plan, "complete"), "合法分析与 profile 应生成完整计划。")
	assert_eq(before_digest, after_digest, "Planner 调用前后项目树摘要必须完全相同。")
	_assert_closed_plan_schema(plan)
	assert_eq(
		GFVariantData.get_option_string(plan, "source_analysis_digest"),
		GFVariantData.get_option_string(source_analysis, "input_digest")
	)
	assert_eq(GFVariantData.get_option_string(plan, "project_root"), root_path)
	assert_eq(GFVariantData.get_option_string(plan, "kind"), "project_layout_plan")
	assert_eq(GFVariantData.get_option_int(plan, "schema_version"), 1)
	var capabilities: Dictionary = GFVariantData.get_option_dictionary(plan, "capabilities")
	assert_false(GFVariantData.get_option_bool(capabilities, "writes_project", true))
	assert_eq(
		GFVariantData.get_option_string(capabilities, "planning_scope"),
		"directory_candidates_only"
	)
	var step_paths: PackedStringArray = _step_paths(plan)
	assert_true(step_paths.has("app"))
	assert_true(step_paths.has("features"))
	assert_true(step_paths.has("features/inventory"))
	assert_true(step_paths.has("features/inventory/scripts"))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path.path_join("app"))))
	assert_false(DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(root_path.path_join("features/inventory/scripts"))
	))
	var feature_step: Dictionary = _find_step(plan, "features/inventory")
	assert_eq(
		GFVariantData.get_option_array(feature_step, "requires"),
		[GFVariantData.get_option_string(_find_step(plan, "features"), "step_id")]
	)
	assert_eq(
		GFVariantData.get_option_array(feature_step, "preconditions"),
		[
			"source_analysis_digest_matches",
			"path_absent_in_source_analysis",
			"ancestor_chain_contains_no_files_in_source_analysis",
		],
		"步骤前置条件必须明确声明其 snapshot 语义。"
	)


func test_project_layout_plan_is_identical_across_dictionary_insertion_orders() -> void:
	var root_path: String = _make_empty_test_root("plan_dictionary_order")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var profile: Dictionary = _make_minimal_feature_profile()
	var options: Dictionary = {
		"feature_ids": ["inventory"],
		"include_optional_zones": true,
		"include_optional_feature_subdirs": false,
	}
	var reordered_profile_value: Variant = _reverse_dictionary_insertion(profile)
	var reordered_analysis_value: Variant = _reverse_dictionary_insertion(source_analysis)
	var reordered_options_value: Variant = _reverse_dictionary_insertion(options)
	assert_true(reordered_profile_value is Dictionary)
	assert_true(reordered_analysis_value is Dictionary)
	assert_true(reordered_options_value is Dictionary)
	if not (
		reordered_profile_value is Dictionary
		and reordered_analysis_value is Dictionary
		and reordered_options_value is Dictionary
	):
		return
	var reordered_profile: Dictionary = reordered_profile_value
	var reordered_analysis: Dictionary = reordered_analysis_value
	var reordered_options: Dictionary = reordered_options_value
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var first_plan: Dictionary = planner.plan_profile(profile, source_analysis, options)
	var second_plan: Dictionary = planner.plan_profile(
		reordered_profile,
		reordered_analysis,
		reordered_options
	)

	assert_true(GFVariantData.get_option_bool(first_plan, "complete"))
	assert_eq(first_plan, second_plan, "语义相同输入不得因 Dictionary 插入顺序产生不同计划。")
	_assert_closed_plan_schema(first_plan)
	_assert_closed_plan_schema(second_plan)


func test_project_layout_planner_consumes_analyzer_compilation_without_reloading_contract() -> void:
	var root_path: String = _make_empty_test_root("compiled_plan")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(_make_minimal_feature_profile())
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		source_analysis,
		{ "feature_ids": ["inventory"] },
		{}
	)

	assert_true(GFVariantData.get_option_bool(plan, "complete"))
	assert_eq(
		GFVariantData.get_option_string(plan, "contract_digest"),
		GFVariantData.get_option_string(compilation, "contract_digest"),
		"计划必须直接继承已验证 compilation 的 contract digest。"
	)
	assert_true(_step_paths(plan).has("features/inventory/scripts"))
	_assert_closed_plan_schema(plan)


func test_project_layout_planner_compiled_entry_is_cooperatively_cancellable() -> void:
	var root_path: String = _make_empty_test_root("compiled_cancel")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(_make_minimal_feature_profile())
	var cancellation_probe: PlannerCancellationProbe = PlannerCancellationProbe.new()
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		source_analysis,
		{ "feature_ids": ["inventory"] },
		{
			"cancel_check": Callable(cancellation_probe, "should_cancel"),
			"max_work_units": 262_144,
		}
	)

	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(plan, "issues"), "planning_cancelled"))
	assert_true(GFVariantData.get_option_array(plan, "steps").is_empty())
	assert_true(cancellation_probe.check_count > 0)
	_assert_closed_plan_schema(plan)


func test_project_layout_analyzer_and_planner_reject_noncanonical_contract_digest() -> void:
	var root_path: String = _make_empty_test_root("invalid_contract_digest")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(_make_minimal_feature_profile())
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	for forged_digest: String in ["not-a-sha256", "0".repeat(64)]:
		var forged_compilation: Dictionary = compilation.duplicate(true)
		forged_compilation["contract_digest"] = forged_digest
		var analyzer_report: Dictionary = analyzer.analyze_compiled_profile_snapshot(
			forged_compilation,
			_make_empty_snapshot(root_path)
		)
		var plan: Dictionary = planner.plan_compiled_profile_analysis(
			forged_compilation,
			source_analysis
		)

		assert_false(GFVariantData.get_option_bool(analyzer_report, "evaluation_complete"))
		assert_true(_has_issue_kind(
			GFVariantData.get_option_array(analyzer_report, "issues"),
			"invalid_profile_compilation"
		))
		assert_false(GFVariantData.get_option_bool(plan, "complete"))
		assert_true(_has_issue_kind(
			GFVariantData.get_option_array(plan, "issues"),
			"invalid_profile_compilation"
		))
		assert_eq(GFVariantData.get_option_string(plan, "contract_digest"), "")


func test_project_layout_plan_omits_existing_directories_without_writing() -> void:
	var root_path: String = _make_empty_test_root("existing")
	_make_directory(root_path.path_join("app"))
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var before_digest: String = _tree_digest(root_path)
	var plan: Dictionary = planner.plan_example_profile(source_analysis)

	assert_true(GFVariantData.get_option_bool(plan, "complete"))
	assert_false(_step_paths(plan).has("app"), "已存在目录不应产生步骤。")
	assert_eq(_tree_digest(root_path), before_digest)
	_assert_closed_plan_schema(plan)


func test_project_layout_planner_preserves_schema_only_rule_policy() -> void:
	var fixture_case: Dictionary = _get_profile_conformance_case("python_only_rule")
	var profile: Dictionary = GFVariantData.get_option_dictionary(fixture_case, "profile")
	var root_path: String = _make_empty_test_root("schema_only")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_profile(profile, source_analysis)

	assert_true(GFVariantData.get_option_bool(plan, "complete"), "schema-only 规划不应执行普通验证规则。")
	assert_false(_has_issue_kind(GFVariantData.get_option_array(plan, "issues"), "unsupported_rule_kind"))
	var capabilities: Dictionary = GFVariantData.get_option_dictionary(plan, "capabilities")
	assert_eq(
		GFVariantData.get_option_array(capabilities, "supported_rule_kinds"),
		["feature_module_contract"],
		"capability 应披露 Planner 支持的 registry，不虚报当前 profile 已执行规则。"
	)
	assert_eq(
		GFVariantData.get_option_array(capabilities, "ignored_rule_kinds"),
		["path_exists"],
		"schema-only 完成态必须显式披露未执行规则。"
	)


func test_project_layout_planner_unions_overlapping_feature_contract_paths() -> void:
	var fixture_case: Dictionary = _get_profile_conformance_case("multiple_feature_contracts")
	var profile: Dictionary = GFVariantData.get_option_dictionary(fixture_case, "profile")
	var root_path: String = _make_empty_test_root("feature_union")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var helper_paths: PackedStringArray = planner.make_feature_module_paths(profile, "inventory")
	var plan: Dictionary = planner.plan_profile(profile, source_analysis, {
		"feature_ids": ["inventory"],
	})
	var step_paths: PackedStringArray = _step_paths(plan)

	for expected_path: String in [
		"features/inventory",
		"features/inventory/scripts",
		"features/inventory/assets",
	]:
		assert_true(helper_paths.has(expected_path), "helper 缺少并集路径：%s。" % expected_path)
		assert_true(step_paths.has(expected_path), "计划缺少并集路径：%s。" % expected_path)
	assert_eq(_count_string(helper_paths, "features/inventory"), 1)
	assert_true(GFVariantData.get_option_bool(plan, "complete"))


func test_project_layout_planner_rejects_non_portable_feature_ids_before_steps() -> void:
	var root_path: String = _make_empty_test_root("portable_ids")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var profile: Dictionary = _make_minimal_feature_profile()
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	for feature_id: String in ["../escape", "bad/name", "con", "COM1.txt", "inventory."]:
		assert_true(
			planner.make_feature_module_paths(profile, feature_id).is_empty(),
			"不可移植 ID 不得产生 helper 路径：%s。" % feature_id
		)
		var plan: Dictionary = planner.plan_profile(profile, source_analysis, {
			"feature_ids": [feature_id],
		})
		assert_false(GFVariantData.get_option_bool(plan, "complete"))
		assert_true(GFVariantData.get_option_array(plan, "steps").is_empty())
		assert_true(_has_issue_kind(GFVariantData.get_option_array(plan, "issues"), "invalid_feature_id"))
		_assert_closed_plan_schema(plan)


func test_project_layout_frozen_graph_reports_blocking_file_without_writing() -> void:
	var root_path: String = _make_empty_test_root("blocked")
	_write_text(root_path.path_join("blocked"), "fixture\n")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var before_digest: String = _tree_digest(root_path)
	var plan: Dictionary = planner.plan_profile(
		_make_required_zone_profile("blocked/child"),
		source_analysis
	)

	assert_true(GFVariantData.get_option_bool(plan, "complete"), "完整冻结图即使发现 blocker 也应保持 complete。")
	assert_true(_has_blocker_kind(plan, "path_blocked_by_file"))
	assert_true(GFVariantData.get_option_array(plan, "steps").is_empty())
	assert_eq(_tree_digest(root_path), before_digest)
	_assert_closed_plan_schema(plan)


func test_project_layout_plan_is_determined_only_by_the_frozen_analysis_graph() -> void:
	var root_path: String = _make_empty_test_root("frozen_graph")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(
		_make_required_zone_profile("blocked/child")
	)
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var before_mutation_plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		source_analysis
	)
	_write_text(root_path.path_join("blocked"), "changed after analysis\n")
	var before_digest: String = _tree_digest(root_path)
	var after_mutation_plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		source_analysis
	)

	assert_true(GFVariantData.get_option_bool(before_mutation_plan, "complete"))
	assert_eq(
		after_mutation_plan,
		before_mutation_plan,
		"同一 compilation 与冻结 graph 的计划不得受捕获后的 live FS 变化影响。"
	)
	assert_true(_step_paths(after_mutation_plan).has("blocked/child"))
	assert_false(_has_blocker_kind(after_mutation_plan, "candidate_path_state_changed"))
	assert_eq(_tree_digest(root_path), before_digest)


func test_project_layout_planner_rejects_incomplete_analysis_and_write_options() -> void:
	var root_path: String = _make_empty_test_root("invalid_input")
	var source_analysis: Dictionary = _analyze_root(root_path)
	source_analysis["evaluation_complete"] = false
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_profile(_make_minimal_feature_profile(), source_analysis, {
		"root_path": root_path,
		"dry_run": true,
	})

	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(plan, "issues"), "incomplete_source_analysis"))
	assert_true(_has_issue_kind(GFVariantData.get_option_array(plan, "issues"), "unsupported_option"))
	_assert_closed_plan_schema(plan)


func test_project_layout_planner_reports_do_not_retain_hostile_variant_values() -> void:
	var root_path: String = _make_empty_test_root("hostile")
	var source_analysis: Dictionary = _analyze_root(root_path)
	var hostile_node: Node = Node.new()
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_profile(_make_minimal_feature_profile(), source_analysis, {
		"feature_ids": [hostile_node],
	})
	hostile_node.free()

	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_false(_contains_unsafe_report_value(plan), "Planner 报告不得保留调用方 Object 或非有限数。")


func _assert_compiler_resource_limit(result: Dictionary) -> void:
	var issues: Array = GFVariantData.get_option_array(result, "issues")
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_eq(issues.size(), 1, "资源超限只能产生一条 terminal diagnostic。")
	assert_true(_has_issue_kind(issues, "profile_compile_resource_limit_exceeded"))
	assert_true(_has_issue_reason_code(
		issues,
		"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED"
	))
	assert_eq(GFVariantData.get_option_int(result, "error_count"), 1)
	assert_eq(GFVariantData.get_option_int(result, "warning_count"), 0)
	assert_true(GFVariantData.get_option_dictionary(result, "profile").is_empty())
	assert_true(GFVariantData.get_option_dictionary(result, "capabilities").is_empty())


func _assert_analysis_contract_resource_limit(result: Dictionary) -> void:
	var errors: Array = GFVariantData.get_option_array(result, "errors")
	assert_false(GFVariantData.get_option_bool(result, "valid"))
	assert_eq(errors.size(), 1, "analysis 超限只能产生一条 terminal validation error。")
	assert_true(_has_issue_kind(errors, "analysis_contract_resource_limit_exceeded"))
	assert_eq(GFVariantData.get_option_string(result, "capture_status"), "")
	assert_false(GFVariantData.get_option_bool(result, "complete"))
	var index: Dictionary = GFVariantData.get_option_dictionary(result, "index")
	assert_eq(index.size(), 5)
	for index_value: Variant in index.values():
		assert_true(index_value is Dictionary)
		if index_value is Dictionary:
			var index_dictionary: Dictionary = index_value
			assert_true(index_dictionary.is_empty(), "terminal validation 不得保留部分索引。")


func _assert_analysis_contract_checkpoint_terminal(
	result: Dictionary,
	expected_kind: String
) -> void:
	var errors: Array = GFVariantData.get_option_array(result, "errors")
	assert_false(GFVariantData.get_option_bool(result, "valid"))
	assert_eq(errors.size(), 1)
	assert_true(_has_issue_kind(errors, expected_kind))
	assert_eq(GFVariantData.get_option_string(result, "capture_status"), "")
	assert_false(GFVariantData.get_option_bool(result, "complete"))
	var index: Dictionary = GFVariantData.get_option_dictionary(result, "index")
	assert_eq(index.size(), 5)
	for index_value: Variant in index.values():
		assert_true(index_value is Dictionary)
		if index_value is Dictionary:
			var index_dictionary: Dictionary = index_value
			assert_true(index_dictionary.is_empty())


func _assert_planner_resource_limit(plan: Dictionary) -> void:
	_assert_closed_plan_schema(plan)
	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_true(GFVariantData.get_option_array(plan, "steps").is_empty())
	assert_true(GFVariantData.get_option_array(plan, "blockers").is_empty())
	var issues: Array = GFVariantData.get_option_array(plan, "issues")
	assert_eq(issues.size(), 1, "Planner 超限只能产生一条 terminal diagnostic。")
	assert_true(_has_issue_kind(issues, "planner_resource_limit_exceeded"))


func _replace_first_finding_context(analysis: Dictionary, context: Dictionary) -> void:
	for collection_name: String in ["issues", "findings"]:
		var values_value: Variant = analysis.get(collection_name)
		if not values_value is Array:
			continue
		var values: Array = values_value
		if values.is_empty() or not values[0] is Dictionary:
			continue
		var finding: Dictionary = values[0]
		finding["context"] = context


func _reverse_dictionary_insertion(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var dictionary_result: Dictionary = {}
		var keys: Array = dictionary_value.keys()
		for key_index: int in range(keys.size() - 1, -1, -1):
			var key: Variant = keys[key_index]
			dictionary_result[key] = _reverse_dictionary_insertion(dictionary_value[key])
		return dictionary_result
	if value is Array:
		var array_value: Array = value
		var array_result: Array = []
		for item: Variant in array_value:
			array_result.append(_reverse_dictionary_insertion(item))
		return array_result
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	return value


func _poison_analysis_contract_case(
	analysis: Dictionary,
	counterexample_id: String,
	contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT
) -> void:
	var graph_value: Variant = analysis.get("graph")
	var graph: Dictionary = graph_value if graph_value is Dictionary else {}
	if counterexample_id == "unknown_field":
		analysis["unexpected"] = true
		return
	if counterexample_id == "deleted_node":
		var nodes_value: Variant = graph.get("nodes")
		var nodes: Array = nodes_value if nodes_value is Array else []
		var node_index: int = _node_index_for_path(nodes, "alpha/child")
		if node_index >= 0:
			nodes.remove_at(node_index)
		return
	if counterexample_id == "changed_node":
		var node: Dictionary = _node_for_path(graph, "alpha/data.txt")
		node["node_kind"] = "directory"
		return
	if counterexample_id == "wrong_parent":
		var edge: Dictionary = _edge_to_node_id(graph, "path:alpha/child")
		edge["from_node_id"] = "path:."
		edge["edge_id"] = contract.stable_edge_id(
			"contains",
			"path:.",
			"path:alpha/child",
			"project_source"
		)
		return
	if counterexample_id == "dangling_evidence":
		var root_node: Dictionary = _node_for_path(graph, ".")
		root_node["evidence_ids"] = ["evidence:missing"]
		return
	if counterexample_id == "count_mismatch":
		analysis["file_count"] = GFVariantData.get_option_int(analysis, "file_count") + 1
		return
	if counterexample_id == "status_mismatch":
		graph["capture_status"] = "partial"
		return
	if counterexample_id == "boundary_mismatch":
		var boundary: Dictionary = _inventory_boundary(graph)
		boundary["file_count"] = GFVariantData.get_option_int(boundary, "file_count") + 1
		return
	if counterexample_id == "digest_mismatch":
		analysis["input_digest"] = "0".repeat(64)
		return
	if counterexample_id == "scope_mismatch":
		var scope_value: Variant = graph.get("scope")
		var scope: Dictionary = scope_value if scope_value is Dictionary else {}
		scope["root_path"] = "res://different_root"


func _assert_incomplete_analysis_policy(
	analysis: Dictionary,
	expected_status: String,
	analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT,
	planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT,
	contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT
) -> void:
	var validation: Dictionary = contract.validate_and_index(analysis)
	assert_true(GFVariantData.get_option_bool(validation, "valid"))
	assert_eq(GFVariantData.get_option_string(validation, "capture_status"), expected_status)
	assert_false(GFVariantData.get_option_bool(validation, "complete"))
	var findings: Array = GFVariantData.get_option_array(analysis, "findings")
	assert_false(findings.is_empty())
	if not findings.is_empty() and findings[0] is Dictionary:
		var finding: Dictionary = findings[0]
		var explanation: Dictionary = analyzer.explain_finding(
			analysis,
			GFVariantData.get_option_string(finding, "finding_id")
		)
		assert_true(GFVariantData.get_option_bool(explanation, "complete"))
	var impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{ "kind": "delete", "source_path": "unobserved" }
	)
	assert_eq(GFVariantData.get_option_string(impact, "status"), "unknown")
	assert_false(GFVariantData.get_option_bool(impact, "complete"))
	var plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		analysis
	)
	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_true(
		_has_issue_kind(
			GFVariantData.get_option_array(plan, "issues"),
			"incomplete_source_analysis"
		)
	)


func _make_required_zones_profile(entries: Array) -> Dictionary:
	var zones: Array = []
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		zones.append({
			"id": GFVariantData.get_option_string(entry, "id"),
			"roots": [GFVariantData.get_option_string(entry, "root")],
			"required": true,
			"severity": "warning",
		})
	return {
		"schema_version": 1,
		"id": "stable_finding_fixture",
		"zones": zones,
		"rules": [],
	}


func _finding_id_for_path(analysis: Dictionary, path: String) -> String:
	for finding_value: Variant in GFVariantData.get_option_array(analysis, "findings"):
		if not finding_value is Dictionary:
			continue
		var finding: Dictionary = finding_value
		if GFVariantData.get_option_string(finding, "path") == path:
			return GFVariantData.get_option_string(finding, "finding_id")
	return ""


func _edge_id_to_path(analysis: Dictionary, path: String) -> String:
	var graph_value: Variant = analysis.get("graph")
	var graph: Dictionary = graph_value if graph_value is Dictionary else {}
	var node: Dictionary = _node_for_path(graph, path)
	var node_id: String = GFVariantData.get_option_string(node, "node_id")
	return GFVariantData.get_option_string(_edge_to_node_id(graph, node_id), "edge_id")


func _node_index_for_path(nodes: Array, path: String) -> int:
	for node_index: int in nodes.size():
		var node_value: Variant = nodes[node_index]
		if node_value is Dictionary:
			var node: Dictionary = node_value
			if GFVariantData.get_option_string(node, "relative_path") == path:
				return node_index
	return -1


func _node_for_path(graph: Dictionary, path: String) -> Dictionary:
	var nodes_value: Variant = graph.get("nodes")
	var nodes: Array = nodes_value if nodes_value is Array else []
	for node_value: Variant in nodes:
		if node_value is Dictionary:
			var node: Dictionary = node_value
			if GFVariantData.get_option_string(node, "relative_path") == path:
				return node
	return {}


func _edge_to_node_id(graph: Dictionary, node_id: String) -> Dictionary:
	var edges_value: Variant = graph.get("edges")
	var edges: Array = edges_value if edges_value is Array else []
	for edge_value: Variant in edges:
		if edge_value is Dictionary:
			var edge: Dictionary = edge_value
			if GFVariantData.get_option_string(edge, "to_node_id") == node_id:
				return edge
	return {}


func _inventory_boundary(graph: Dictionary) -> Dictionary:
	var evidence_items_value: Variant = graph.get("evidence")
	var evidence_items: Array = (
		evidence_items_value if evidence_items_value is Array else []
	)
	for evidence_value: Variant in evidence_items:
		if evidence_value is Dictionary:
			var evidence: Dictionary = evidence_value
			if GFVariantData.get_option_string(evidence, "kind") == "filesystem_inventory_boundary":
				return evidence
	return {}


func _track_root(root_path: String) -> String:
	_temporary_roots.append(root_path)
	return root_path


func _make_empty_test_root(label: String) -> String:
	var root_path: String = _track_root(
		"res://build/gf_project_layout_tests/planner_%s_%d" % [label, Time.get_ticks_usec()]
	)
	_make_directory(root_path)
	return root_path


func _analyze_root(root_path: String) -> Dictionary:
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var source_analysis: Dictionary = analyzer.analyze({ "root_path": root_path })
	assert_true(GFVariantData.get_option_bool(source_analysis, "evaluation_complete"))
	assert_true(GFVariantData.get_option_bool(source_analysis, "input_complete"))
	assert_eq(GFVariantData.get_option_string(source_analysis, "kind"), "project_layout_analysis")
	return source_analysis


func _make_empty_snapshot(root_path: String) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_snapshot",
		"root_path": root_path,
		"scope": _make_inventory_scope(root_path),
		"complete": true,
		"capture_status": "complete",
		"files": [],
		"directories": [],
		"issues": [],
	}


func _load_profile_conformance_fixture() -> Dictionary:
	assert_true(FileAccess.file_exists(PROFILE_CONFORMANCE_FIXTURE_PATH))
	var fixture_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PROFILE_CONFORMANCE_FIXTURE_PATH)
	)
	assert_true(fixture_value is Dictionary)
	if not fixture_value is Dictionary:
		return {}
	var fixture: Dictionary = fixture_value
	return fixture


func _get_profile_conformance_case(case_id: String) -> Dictionary:
	for case_value: Variant in GFVariantData.get_option_array(
		_load_profile_conformance_fixture(),
		"cases"
	):
		if not case_value is Dictionary:
			continue
		var fixture_case: Dictionary = case_value
		if GFVariantData.get_option_string(fixture_case, "id") == case_id:
			return fixture_case
	assert_true(false, "共享 profile conformance fixture 缺少 case：%s。" % case_id)
	return {}


func _materialize_fixture_inventory(fixture_case: Dictionary, root_path: String) -> void:
	_make_directory(root_path)
	for path_value: Variant in GFVariantData.get_option_array(fixture_case, "inventory"):
		if path_value is String:
			var relative_path: String = path_value
			_write_text(root_path.path_join(relative_path), "fixture\n")


func _assert_conformance_result(
	case_id: String,
	expected: Dictionary,
	validate_result: Dictionary,
	plan: Dictionary
) -> void:
	assert_eq(
		GFVariantData.get_option_bool(validate_result, "success"),
		GFVariantData.get_option_bool(expected, "godot_validator_success"),
		"validator success 与 fixture 不一致：%s。" % case_id
	)
	assert_eq(
		GFVariantData.get_option_bool(plan, "complete"),
		GFVariantData.get_option_bool(expected, "godot_planner_complete"),
		"planner complete 与 fixture 不一致：%s。" % case_id
	)
	var validate_issues: Array = GFVariantData.get_option_array(validate_result, "issues")
	var plan_issues: Array = GFVariantData.get_option_array(plan, "issues")
	if expected.has("reason_code"):
		var shared_reason_code: String = GFVariantData.get_option_string(expected, "reason_code")
		assert_true(_has_issue_reason_code(validate_issues, shared_reason_code), "validator 缺少 reason：%s。" % case_id)
		assert_true(_has_issue_reason_code(plan_issues, shared_reason_code), "planner 缺少 reason：%s。" % case_id)
	if expected.has("godot_reason_code"):
		var godot_reason_code: String = GFVariantData.get_option_string(expected, "godot_reason_code")
		assert_true(_has_issue_reason_code(validate_issues, godot_reason_code), "validator 缺少 Godot reason：%s。" % case_id)
		assert_true(_has_issue_reason_code(plan_issues, godot_reason_code), "planner 缺少 Godot reason：%s。" % case_id)
	_assert_issue_reason_codes(
		validate_issues,
		GFVariantData.get_option_array(expected, "godot_validator_reason_codes"),
		expected.has("godot_validator_reason_codes"),
		"validator",
		case_id
	)
	_assert_issue_reason_codes(
		plan_issues,
		GFVariantData.get_option_array(expected, "godot_planner_reason_codes"),
		expected.has("godot_planner_reason_codes"),
		"planner",
		case_id
	)
	_assert_issue_kind_multiset(
		validate_issues,
		GFVariantData.get_option_array(expected, "godot_validator_issue_kinds"),
		"validator",
		case_id
	)
	_assert_issue_kind_multiset(
		plan_issues,
		GFVariantData.get_option_array(expected, "godot_planner_issue_kinds"),
		"planner",
		case_id
	)


func _assert_issue_reason_codes(
	issues: Array,
	expected_reason_codes: Array,
	expectation_present: bool,
	executor_name: String,
	case_id: String
) -> void:
	if not expectation_present:
		return
	var actual_reason_codes: PackedStringArray = _issue_reason_codes(issues)
	var expected_codes: PackedStringArray = PackedStringArray()
	for reason_value: Variant in expected_reason_codes:
		if reason_value is String:
			var reason_code: String = reason_value
			var _append_reason: bool = expected_codes.append(reason_code)
	actual_reason_codes.sort()
	expected_codes.sort()
	assert_eq(
		actual_reason_codes,
		expected_codes,
		"%s reason-code 集合与 fixture 不一致：%s。" % [executor_name, case_id]
	)


func _assert_issue_kind_multiset(
	issues: Array,
	expected_kinds: Array,
	executor_name: String,
	case_id: String
) -> void:
	var actual_issue_kinds: PackedStringArray = _issue_kinds(issues)
	var expected_issue_kinds: PackedStringArray = PackedStringArray()
	for kind_value: Variant in expected_kinds:
		if kind_value is String:
			var issue_kind: String = kind_value
			var _append_kind: bool = expected_issue_kinds.append(issue_kind)
	actual_issue_kinds.sort()
	expected_issue_kinds.sort()
	assert_eq(
		actual_issue_kinds,
		expected_issue_kinds,
		"%s issue-kind 多重集合与 fixture 不一致：%s。" % [executor_name, case_id]
	)


func _assert_closed_plan_schema(plan: Dictionary) -> void:
	assert_true(_dictionary_has_exact_fields(plan, _PLAN_FIELDS), "计划顶层字段必须精确闭合。")
	var capabilities: Dictionary = GFVariantData.get_option_dictionary(plan, "capabilities")
	assert_true(_dictionary_has_exact_fields(capabilities, _PLAN_CAPABILITY_FIELDS))
	var writes_project_value: Variant = capabilities.get("writes_project")
	assert_true(writes_project_value is bool)
	if writes_project_value is bool:
		var writes_project: bool = writes_project_value
		assert_false(writes_project)
	assert_eq(
		GFVariantData.get_option_string(capabilities, "planning_scope"),
		"directory_candidates_only"
	)
	assert_true(capabilities.get("supported_rule_kinds") is Array)
	assert_true(capabilities.get("ignored_rule_kinds") is Array)
	for forbidden_field: String in _FORBIDDEN_PLAN_FIELDS:
		assert_false(plan.has(forbidden_field), "计划不得暴露写入协议字段：%s。" % forbidden_field)
	for step_value: Variant in GFVariantData.get_option_array(plan, "steps"):
		assert_true(step_value is Dictionary)
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		assert_true(_dictionary_has_exact_fields(step, _PLAN_STEP_FIELDS), "step 字段必须精确闭合。")
		var relative_path: String = GFVariantData.get_option_string(step, "relative_path")
		assert_false(relative_path.is_empty())
		assert_false(relative_path.contains("://"), "step 只能包含相对路径。")
		assert_false(relative_path.is_absolute_path(), "step 不能包含绝对路径。")
		assert_false(_path_has_parent_segment(relative_path), "step 不能越过项目根。")
		for forbidden_field: String in _FORBIDDEN_PLAN_FIELDS:
			assert_false(step.has(forbidden_field), "step 不得暴露写入协议字段：%s。" % forbidden_field)


func _step_paths(plan: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for step_value: Variant in GFVariantData.get_option_array(plan, "steps"):
		if step_value is Dictionary:
			var step: Dictionary = step_value
			var _append_step_path: bool = result.append(
				GFVariantData.get_option_string(step, "relative_path")
			)
	return result


func _find_step(plan: Dictionary, relative_path: String) -> Dictionary:
	for step_value: Variant in GFVariantData.get_option_array(plan, "steps"):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if GFVariantData.get_option_string(step, "relative_path") == relative_path:
			return step
	return {}


func _has_blocker_kind(plan: Dictionary, kind: String) -> bool:
	for blocker_value: Variant in GFVariantData.get_option_array(plan, "blockers"):
		if blocker_value is Dictionary:
			var blocker: Dictionary = blocker_value
			if GFVariantData.get_option_string(blocker, "kind") == kind:
				return true
	return false


func _issue_reason_codes(issues: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if issue.has("reason_code"):
			var _append_reason_code: bool = result.append(
				GFVariantData.get_option_string(issue, "reason_code")
			)
	return result


func _issue_kinds(issues: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			var _append_issue_kind: bool = result.append(
				GFVariantData.get_option_string(issue, "kind")
			)
	return result


func _dictionary_has_only_fields(data: Dictionary, allowed_fields: PackedStringArray) -> bool:
	for field_value: Variant in data.keys():
		var field_name: String = field_value if field_value is String else ""
		if field_name.is_empty() or not allowed_fields.has(field_name):
			return false
	return true


func _dictionary_has_exact_fields(data: Dictionary, expected_fields: PackedStringArray) -> bool:
	return data.size() == expected_fields.size() and _dictionary_has_only_fields(data, expected_fields)


func _is_string_array(value: Variant) -> bool:
	if not (value is Array or value is PackedStringArray):
		return false
	if value is PackedStringArray:
		return true
	var values: Array = value
	for item: Variant in values:
		if not item is String:
			return false
	return true


func _is_exact_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


func _exact_integer_value(value: Variant) -> int:
	if value is int:
		var integer_value: int = value
		return integer_value
	if value is float and _is_exact_integer_value(value):
		var float_value: float = value
		return int(float_value)
	return 0


func _make_minimal_feature_profile() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "minimal_feature_fixture",
		"zones": [],
		"rules": [{
			"id": "features",
			"kind": "feature_module_contract",
			"roots": ["features"],
			"feature_id_pattern": "^[a-z][a-z0-9_]*$",
			"required_subdirs": ["scripts"],
			"allowed_subdirs": ["scripts"],
			"severity": "error",
		}],
	}


func _make_candidate_heavy_feature_profile() -> Dictionary:
	var roots: Array = []
	var subdirectories: Array = []
	for item_index: int in 33:
		roots.append("features_%02d" % item_index)
		subdirectories.append("part_%02d" % item_index)
	return {
		"schema_version": 1,
		"id": "candidate_heavy_fixture",
		"zones": [],
		"rules": [{
			"id": "features",
			"kind": "feature_module_contract",
			"roots": roots,
			"feature_id_pattern": "^[a-z][a-z0-9_]*$",
			"required_subdirs": subdirectories,
			"allowed_subdirs": subdirectories.duplicate(),
			"severity": "error",
		}],
	}


func _make_inventory_scope(root_path: String) -> Dictionary:
	return {
		"kind": "project_source",
		"root_path": root_path,
		"include_hidden": true,
		"excluded_prefixes": [".git", ".godot", ".import"],
		"max_scanned_files": 20_000,
		"max_scanned_directories": 20_000,
		"max_scan_depth": 32,
	}


func _make_analysis_from_inventory_attachment(
	root_path: String,
	attachment: Dictionary
) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_analysis",
		"evaluation_status": "complete",
		"evaluation_complete": true,
		"input_complete": true,
		"success": true,
		"profile_id": "",
		"root_path": root_path,
		"input_digest": GFVariantData.get_option_string(attachment, "input_digest"),
		"file_count": GFVariantData.get_option_int(attachment, "file_count"),
		"directory_count": GFVariantData.get_option_int(attachment, "directory_count"),
		"graph": GFVariantData.get_option_dictionary(attachment, "graph"),
		"issues": [],
		"findings": [],
		"error_count": 0,
		"warning_count": 0,
		"info_count": 0,
		"rule_results": [],
		"capabilities": {},
		"effects": { "writes_project": false },
	}


func _make_forged_oversized_inventory_analysis(
	root_path: String,
	directory_count: int
) -> Dictionary:
	var contract: GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT = (
		GF_PROJECT_LAYOUT_ANALYSIS_CONTRACT_SCRIPT.new()
	)
	var scope: Dictionary = _make_inventory_scope(root_path)
	var attachment: Dictionary = contract.build_inventory_attachment(
		root_path,
		{
			"scope": scope,
			"capture_status": "complete",
			"complete": true,
			"root_observed": true,
			"directories": [],
			"files": [],
		}
	)
	var analysis: Dictionary = _make_analysis_from_inventory_attachment(
		root_path,
		attachment
	)
	var graph_value: Variant = analysis.get("graph")
	var graph: Dictionary = graph_value if graph_value is Dictionary else {}
	var nodes_value: Variant = graph.get("nodes")
	var edges_value: Variant = graph.get("edges")
	var evidence_value: Variant = graph.get("evidence")
	var nodes: Array = nodes_value if nodes_value is Array else []
	var edges: Array = edges_value if edges_value is Array else []
	var evidence: Array = evidence_value if evidence_value is Array else []
	var boundary_value: Variant = evidence.pop_back()
	var boundary: Dictionary = boundary_value if boundary_value is Dictionary else {}
	for directory_index: int in directory_count:
		var suffix: String = "%04d" % directory_index
		var relative_path: String = "d".repeat(16_379 - suffix.length()) + suffix
		var node_id: String = "path:%s" % relative_path
		var evidence_id: String = "evidence:%s" % (
			"%s\n%s" % ["directory", relative_path]
		).sha256_text().substr(0, 16)
		nodes.append({
			"node_id": node_id,
			"node_kind": "directory",
			"relative_path": relative_path,
			"scope": "project_source",
			"authority": "filesystem_inventory",
			"completeness": "observed",
			"evidence_ids": [evidence_id],
		})
		evidence.append({
			"evidence_id": evidence_id,
			"kind": "filesystem_inventory",
			"root_path": root_path,
			"relative_path": relative_path,
			"scope": "project_source",
			"authority": "filesystem_inventory",
			"observed": true,
		})
		edges.append({
			"edge_id": contract.stable_edge_id(
				"contains",
				"path:.",
				node_id,
				"project_source"
			),
			"edge_kind": "contains",
			"from_node_id": "path:.",
			"to_node_id": node_id,
			"scope": "project_source",
			"evidence_ids": [evidence_id],
		})
	boundary["evidence_id"] = "evidence:inventory:"
	boundary["capture_scope"] = scope.duplicate(true)
	boundary["file_count"] = 0
	boundary["directory_count"] = directory_count
	boundary["input_digest"] = ""
	evidence.append(boundary)
	analysis["input_digest"] = ""
	analysis["directory_count"] = directory_count
	return analysis


func _assert_invalid_analysis_consumers_fail_closed(analysis: Dictionary) -> void:
	var planner: GF_PROJECT_LAYOUT_PLANNER_SCRIPT = GF_PROJECT_LAYOUT_PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_profile(
		_make_minimal_feature_profile(),
		analysis
	)
	assert_false(GFVariantData.get_option_bool(plan, "complete"))
	assert_eq(GFVariantData.get_option_string(plan, "profile_id"), "")
	assert_eq(GFVariantData.get_option_string(plan, "source_analysis_digest"), "")
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(plan, "issues"),
		"invalid_source_analysis"
	))
	var analyzer: GF_PROJECT_LAYOUT_ANALYZER_SCRIPT = GF_PROJECT_LAYOUT_ANALYZER_SCRIPT.new()
	var impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{ "kind": "delete", "source_path": "missing_zone", "target_path": "" }
	)
	assert_false(GFVariantData.get_option_bool(impact, "complete"))
	assert_eq(GFVariantData.get_option_string(impact, "status"), "unsafe")
	assert_eq(GFVariantData.get_option_string(impact, "source_analysis_digest"), "")
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(impact, "issues"),
		"invalid_analysis"
	))
	var explanation: Dictionary = analyzer.explain_finding(
		analysis,
		"finding:missing"
	)
	assert_false(GFVariantData.get_option_bool(explanation, "complete"))
	assert_true(_has_issue_kind(
		GFVariantData.get_option_array(explanation, "issues"),
		"invalid_analysis"
	))


func _make_valid_plan_compiler_scope() -> Dictionary:
	return {
		"executor_id": "resource_limit_fixture",
		"operation": "plan",
		"rule_registry": {
			"feature_module_contract": {
				"handler": Callable(self, "_valid_plan_registry_handler"),
				"executed_fields": PackedStringArray(["roots"]),
			},
		},
		"unsupported_rule_policy": "schema_only",
		"zone_executed_fields": PackedStringArray(),
	}


func _make_required_zone_profile(relative_root: String) -> Dictionary:
	return {
		"schema_version": 1,
		"id": "required_zone_fixture",
		"zones": [{
			"id": "required",
			"roots": [relative_root],
			"required": true,
			"severity": "error",
		}],
		"rules": [],
	}


func _invalid_registry_handler_arity(_rule: Dictionary) -> void:
	pass


func _valid_plan_registry_handler(
	_rule: Dictionary,
	_candidate_paths: PackedStringArray,
	_plan: Dictionary
) -> void:
	pass


func _planner_never_cancel() -> bool:
	return false


func _make_directory(path: String) -> void:
	var create_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path)
	)
	assert_eq(create_result, OK, "测试应能创建目录 fixture。")


func _write_text(path: String, text: String) -> void:
	_make_directory(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入文本 fixture。")
	if file == null:
		return
	var _store_string_result: bool = file.store_string(text)


func _tree_digest(root_path: String) -> String:
	var records: PackedStringArray = PackedStringArray()
	_collect_tree_records(root_path, "", records)
	records.sort()
	return "\n".join(records).sha256_text()


func _collect_tree_records(
	root_path: String,
	relative_path: String,
	records: PackedStringArray
) -> void:
	var logical_path: String = root_path if relative_path.is_empty() else root_path.path_join(relative_path)
	var directory: DirAccess = DirAccess.open(ProjectSettings.globalize_path(logical_path))
	if directory == null:
		return
	for directory_name: String in directory.get_directories():
		var child_relative_path: String = (
			directory_name
			if relative_path.is_empty()
			else relative_path.path_join(directory_name)
		)
		var _append_directory: bool = records.append("directory:%s" % child_relative_path)
		_collect_tree_records(root_path, child_relative_path, records)
	for file_name: String in directory.get_files():
		var child_relative_path: String = (
			file_name
			if relative_path.is_empty()
			else relative_path.path_join(file_name)
		)
		var file_path: String = root_path.path_join(child_relative_path)
		var _append_file: bool = records.append(
			"file:%s:%s" % [child_relative_path, FileAccess.get_sha256(file_path)]
		)


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			if GFVariantData.get_option_string(issue, "kind") == kind:
				return true
	return false


func _has_issue_reason_code(issues: Array, reason_code: String) -> bool:
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if GFVariantData.get_option_string(issue, "reason_code") == reason_code:
			return true
	return false


func _contains_unsafe_report_value(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return true
	if value is Object:
		return true
	if value is float:
		var float_value: float = value
		return not is_finite(float_value)
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if _contains_unsafe_report_value(item, depth + 1):
				return true
	elif value is Dictionary:
		var dictionary_value: Dictionary = value
		for key_value: Variant in dictionary_value.keys():
			if (
				_contains_unsafe_report_value(key_value, depth + 1)
				or _contains_unsafe_report_value(dictionary_value[key_value], depth + 1)
			):
				return true
	return false


func _count_string(values: PackedStringArray, expected_value: String) -> int:
	var count: int = 0
	for value: String in values:
		if value == expected_value:
			count += 1
	return count


func _path_has_parent_segment(path: String) -> bool:
	for segment: String in path.replace("\\", "/").split("/", false):
		if segment == "..":
			return true
	return false


func _remove_directory_tree(root_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		var _remove_file_result: Error = DirAccess.remove_absolute(
			absolute_path.path_join(file_name)
		)
	for directory_name: String in directory.get_directories():
		if directory.is_link(directory_name):
			var _remove_link_result: Error = DirAccess.remove_absolute(
				absolute_path.path_join(directory_name)
			)
		else:
			_remove_directory_tree(root_path.path_join(directory_name))
	var _remove_directory_result: Error = DirAccess.remove_absolute(absolute_path)


# --- 内部类 ---

class PlannerCancellationProbe extends RefCounted:
	var check_count: int = 0


	func should_cancel() -> bool:
		check_count += 1
		return true


class WeightedCheckpointProbe extends RefCounted:
	var stop_after_work_units: int = -1
	var total_work_units: int = 0
	var call_count: int = 0
	var all_batches_positive: bool = true


	func consume(work_units: int) -> bool:
		call_count += 1
		all_batches_positive = all_batches_positive and work_units > 0
		total_work_units += work_units
		return (
			stop_after_work_units < 0
			or total_work_units < stop_after_work_units
		)
