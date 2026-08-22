@tool
extends GutTest


const _ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd"
)
const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _IMPACT_ANALYZER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_impact_analyzer.gd"
)
const _PLANNER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_planner.gd"
)
const _DOCK_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd"
)
const _BACKGROUND_TASK_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_background_request_task.gd"
)
const _EDITOR_CONTRIBUTION_CATALOG_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_contribution_catalog.gd"
)
const _SNAPSHOT_BUILDER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/editor/gf_project_layout_editor_snapshot_builder.gd"
)
const _VALIDATOR_PATH: String = \
	"res://addons/gf/tools/project_layout/gf_project_layout_validator.gd"
const _WORKER_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/editor/gf_project_layout_scan_worker.gd"
)


func test_project_layout_dock_starts_idle_without_scanning() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	assert_eq(dock.get_state(), GFProjectLayoutDock.STATE_IDLE)
	var result: Dictionary = dock.get_last_result()
	assert_true(_get_dictionary(result, "analysis").is_empty())
	assert_true(_get_dictionary(result, "plan").is_empty())
	assert_true(_get_dictionary(result, "impact").is_empty())
	dock.free()


func test_project_layout_dock_cancels_background_work_without_blocking_the_ui() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var worker: FakeCancelledWorker = FakeCancelledWorker.new()
	var thread: FakeControllableThread = FakeControllableThread.new()
	var task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{ "generation": 1 },
		{ "thread": thread }
	)
	assert_eq(task.start(), OK)
	dock.set(&"_background_task", task)
	dock.set(&"_last_analysis", { "sentinel": true })
	dock.set(&"_last_plan", { "sentinel": true })
	var _set_analyzing_result: Variant = dock.call(
		&"_set_state",
		GFProjectLayoutDock.STATE_ANALYZING,
		"testing"
	)

	dock.cancel_scan()

	assert_true(task.is_cancel_requested())
	assert_eq(worker.cancel_count, 1)
	assert_false(thread.wait_called, "取消按钮不得在主线程同步等待后台任务。")
	assert_eq(dock.get_state(), GFProjectLayoutDock.STATE_CANCELLED)
	var cancelled_result: Dictionary = dock.get_last_result()
	assert_true(_get_dictionary(cancelled_result, "analysis").is_empty())
	assert_true(_get_dictionary(cancelled_result, "plan").is_empty())
	var scan_button_value: Variant = dock.get(&"_scan_button")
	assert_true(scan_button_value is Button)
	var scan_button: Button = null
	if scan_button_value is Button:
		scan_button = scan_button_value
		assert_true(scan_button.disabled, "后台任务真正结束前不得启动重叠扫描。")

	thread.alive = false
	var _process_result: Variant = dock.call(&"_process", 0.0)
	assert_true(thread.wait_called, "线程结束后应在后续帧归属并丢弃取消结果。")
	assert_true(dock.get(&"_background_task") == null)
	if scan_button != null:
		assert_false(scan_button.disabled, "取消任务回收后应重新开放扫描。")
	dock.free()


func test_project_layout_dock_discards_stale_background_generation() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var worker: FakeCancelledWorker = FakeCancelledWorker.new()
	var thread: FakeControllableThread = FakeControllableThread.new()
	var task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{ "generation": 8 },
		{ "thread": thread }
	)
	assert_eq(task.start(), OK)
	dock.set(&"_active_generation", 9)
	dock.set(&"_background_task", task)
	dock.set(&"_last_analysis", { "sentinel": true })
	dock.set(&"_last_plan", { "sentinel": true })
	var _set_analyzing_result: Variant = dock.call(
		&"_set_state",
		GFProjectLayoutDock.STATE_ANALYZING,
		"testing stale generation"
	)
	thread.alive = false

	var _process_result: Variant = dock.call(&"_process", 0.0)

	assert_true(thread.wait_called)
	assert_true(dock.get(&"_background_task") == null)
	assert_eq(dock.get_state(), GFProjectLayoutDock.STATE_CANCELLED)
	var stale_result: Dictionary = dock.get_last_result()
	assert_true(_get_dictionary(stale_result, "analysis").is_empty())
	assert_true(_get_dictionary(stale_result, "plan").is_empty())
	assert_false(dock.is_processing())
	var scan_button_value: Variant = dock.get(&"_scan_button")
	assert_true(scan_button_value is Button)
	if scan_button_value is Button:
		var scan_button: Button = scan_button_value
		assert_false(scan_button.disabled)
	dock.free()


func test_project_layout_dock_adopts_plan_from_the_background_result() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var expected_plan: Dictionary = {
		"schema_version": 1,
		"kind": "project_layout_plan",
		"complete": true,
	}
	var worker: FakeCompletedWorker = FakeCompletedWorker.new()
	worker.result = {
		"schema_version": 1,
		"kind": "project_layout_worker_result",
		"generation": 14,
		"status": "complete",
		"analysis": {
			"input_complete": true,
			"evaluation_complete": true,
			"findings": [],
		},
		"plan": expected_plan,
		"issues": [],
	}
	var thread: FakeControllableThread = FakeControllableThread.new()
	var task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{ "generation": 14 },
		{ "thread": thread }
	)
	assert_eq(task.start(), OK)
	dock.set(&"_active_generation", 14)
	dock.set(&"_background_task", task)
	var _set_analyzing_result: Variant = dock.call(
		&"_set_state",
		GFProjectLayoutDock.STATE_ANALYZING,
		"testing background plan adoption"
	)
	thread.alive = false

	var _process_result: Variant = dock.call(&"_process", 0.0)

	assert_eq(dock.get_state(), GFProjectLayoutDock.STATE_COMPLETE)
	assert_eq(_get_dictionary(dock.get_last_result(), "plan"), expected_plan)
	dock.free()


func test_project_layout_dock_routes_explain_and_impact_queries_off_main_thread() -> void:
	var dock_source: String = _read_text(
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd"
	)
	assert_false(
		dock_source.contains("analyzer.explain_finding("),
		"finding 解释不得在 Dock 主线程重新校验和索引大型 analysis graph。"
	)
	assert_false(
		dock_source.contains("analyzer.analyze_change_impact("),
		"影响模拟不得在 Dock 主线程重新校验和索引大型 analysis graph。"
	)
	assert_true(dock_source.contains("&\"run_query_request\""))
	assert_true(dock_source.contains("configure_query_session("))
	var worker_source: String = _read_text(
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_scan_worker.gd"
	)
	assert_true(worker_source.contains("_QUERY_MAX_WORK_UNITS"))
	assert_true(worker_source.contains("_query_checkpoint_allows"))
	assert_eq(worker_source.count("validate_and_index("), 1)
	assert_true(worker_source.contains("explain_validated_analysis("))
	assert_true(worker_source.contains("analyze_validated_change("))


func test_project_layout_dock_cancels_query_without_waiting_and_discards_stale_result() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var analysis_digest: String = "a".repeat(64)
	dock.set(&"_last_analysis", {
		"input_digest": analysis_digest,
		"sentinel": true,
	})
	var worker: FakeCancelledWorker = FakeCancelledWorker.new()
	var thread: FakeControllableThread = FakeControllableThread.new()
	var task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{ "generation": 22 },
		{ "thread": thread }
	)
	assert_eq(task.start(), OK)
	dock.set(&"_query_task", task)
	dock.set(&"_active_query_generation", 23)
	dock.set(&"_active_query_analysis_digest", analysis_digest)
	var _cancel_result: Variant = dock.call(&"_cancel_active_query", true)

	assert_true(task.is_cancel_requested())
	assert_eq(worker.cancel_count, 1)
	assert_false(thread.wait_called, "查询取消不得在 Dock 主线程等待后台索引退出。")
	thread.alive = false
	var _process_cancelled_result: Variant = dock.call(&"_process", 0.0)
	assert_true(thread.wait_called)
	assert_true(dock.get(&"_query_task") == null)
	assert_true(_get_dictionary(dock.get_last_result(), "analysis").has("sentinel"))

	var stale_worker: FakeCompletedWorker = FakeCompletedWorker.new()
	stale_worker.result = _make_closed_impact_query_result(
		30,
		analysis_digest
	)
	var stale_thread: FakeControllableThread = FakeControllableThread.new()
	var stale_task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		stale_worker,
		{ "generation": 30 },
		{ "thread": stale_thread }
	)
	assert_eq(stale_task.start(), OK)
	dock.set(&"_query_task", stale_task)
	dock.set(&"_active_query_generation", 31)
	stale_thread.alive = false

	var _process_stale_result: Variant = dock.call(&"_process", 0.0)

	assert_true(stale_thread.wait_called)
	assert_true(dock.get(&"_query_task") == null)
	assert_true(_get_dictionary(dock.get_last_result(), "impact").is_empty())
	assert_true(_get_dictionary(dock.get_last_result(), "analysis").has("sentinel"))
	dock.free()


func test_project_layout_dock_rejects_malformed_nested_query_results() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var analysis_digest: String = "b".repeat(64)
	var valid_result: Dictionary = _make_closed_impact_query_result(
		41,
		analysis_digest
	)
	_assert_bool_call_result(
		dock.call(&"_query_result_is_well_formed", valid_result),
		true
	)

	var open_impact: Dictionary = valid_result.duplicate(true)
	var open_impact_payload: Dictionary = _get_dictionary(open_impact, "impact")
	open_impact_payload["validation_index"] = {}
	_assert_bool_call_result(
		dock.call(&"_query_result_is_well_formed", open_impact),
		false
	)

	var open_blocker: Dictionary = valid_result.duplicate(true)
	var open_blocker_payload: Dictionary = _get_dictionary(open_blocker, "impact")
	open_blocker_payload["blockers"] = [{
		"kind": "dependency_coverage_incomplete",
		"path": "",
		"message": "fixture",
		"unexpected": true,
	}]
	_assert_bool_call_result(
		dock.call(&"_query_result_is_well_formed", open_blocker),
		false
	)

	var unsafe_nested: Dictionary = valid_result.duplicate(true)
	var unsafe_impact_payload: Dictionary = _get_dictionary(unsafe_nested, "impact")
	unsafe_impact_payload["affected_node_ids"] = [RefCounted.new()]
	_assert_bool_call_result(
		dock.call(&"_query_result_is_well_formed", unsafe_nested),
		false
	)
	dock.free()


func test_project_layout_dock_exit_cancels_then_joins_query_task() -> void:
	var dock: GFProjectLayoutDock = _DOCK_SCRIPT.new()
	var worker: FakeCancelledWorker = FakeCancelledWorker.new()
	var thread: FakeControllableThread = FakeControllableThread.new()
	var task: GFEditorBackgroundRequestTask = _BACKGROUND_TASK_SCRIPT.new().configure(
		worker,
		{
			"generation": 51,
			"analysis_digest": "c".repeat(64),
			"query_kind": "explain_finding",
			"query": { "finding_id": "fixture" },
		},
		{
			"thread": thread,
			"worker_method": &"run_query_request",
		}
	)
	assert_eq(task.start(), OK)
	dock.set(&"_query_task", task)

	var _exit_result: Variant = dock.call(&"_exit_tree")

	assert_eq(worker.cancel_count, 1)
	assert_true(thread.wait_called)
	assert_false(thread.alive)
	assert_true(dock.get(&"_query_task") == null)
	dock.free()


func test_project_layout_dock_is_discovered_through_optional_data_catalog() -> void:
	var report: Dictionary = _EDITOR_CONTRIBUTION_CATALOG_SCRIPT.load_catalog_report(
		"res://addons/gf/gf_builtin_tool_contributions.json"
	)
	assert_true(_get_bool(report, "ok"))
	assert_eq(_get_string(report, "state"), "valid")
	assert_eq(_get_int(report, "loaded_manifest_count"), 1)
	var records: Dictionary = _get_dictionary(report, "records")
	var dock_records: Array = _get_array(records, "dock_records")
	assert_eq(dock_records.size(), 1)
	var dock_record: Dictionary = _get_dictionary_at(dock_records, 0)
	assert_eq(_get_string(dock_record, "owner_package_id"), "gf.tool.project_layout")
	assert_eq(
		_get_string(dock_record, "path"),
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd"
	)


func test_project_layout_dock_and_package_expose_no_apply_surface() -> void:
	var forbidden_fragments: PackedStringArray = [
		"DirAccess.make_dir",
		"DirAccess.remove",
		"ResourceSaver.save",
		"ProjectSettings.save",
		"FileAccess.WRITE",
		"FileAccess.READ_WRITE",
		"\"Apply\"",
		"\"应用\"",
	]
	var script_paths: PackedStringArray = [
		"res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd",
		"res://addons/gf/tools/project_layout/gf_project_layout_planner.gd",
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd",
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_editor_snapshot_builder.gd",
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_scan_worker.gd",
	]
	for script_path: String in script_paths:
		var source: String = _read_text(script_path)
		assert_false(source.is_empty(), "%s 应可读取。" % script_path)
		for forbidden_fragment: String in forbidden_fragments:
			assert_false(
				source.contains(forbidden_fragment),
				"%s 不得包含项目写入入口 %s。" % [script_path, forbidden_fragment]
			)
	var dock_source: String = _read_text(
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_dock.gd"
	)
	assert_false(dock_source.contains("_PLANNER_SCRIPT"))
	assert_false(dock_source.contains(".plan_profile("))
	assert_false(dock_source.contains("var _active_profile: Dictionary"))
	assert_true(dock_source.contains("_get_dictionary(result, \"plan\")"))
	assert_false(
		FileAccess.file_exists(
			"res://addons/gf/tools/project_layout/gf_project_layout_scaffolder.gd"
		),
		"11.0 只读产品不得继续安装 GFProjectLayoutScaffolder。"
	)


func test_project_layout_analyzer_snapshot_is_deterministic_and_scoped() -> void:
	var snapshot: Dictionary = _make_snapshot()
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var first: Dictionary = analyzer.analyze_snapshot(snapshot)
	var second: Dictionary = analyzer.analyze_snapshot(snapshot)
	assert_true(_get_bool(first, "evaluation_complete"))
	assert_true(_get_bool(first, "input_complete"))
	assert_eq(_get_string(first, "input_digest"), _get_string(second, "input_digest"))
	assert_eq(_get_dictionary(first, "graph"), _get_dictionary(second, "graph"))
	var graph: Dictionary = _get_dictionary(first, "graph")
	assert_eq(_get_string(graph, "kind"), "project_layout_graph")
	assert_eq(_get_string(graph, "capture_status"), "complete")
	assert_eq(_get_dictionary(graph, "scope"), _get_dictionary(snapshot, "scope"))
	assert_eq(_get_string(graph, "dependency_coverage"), "filesystem_only")
	assert_eq(_get_array(graph, "nodes").size(), 7, "根节点 + 3 目录 + 3 文件。")
	for node_value: Variant in _get_array(graph, "nodes"):
		assert_true(node_value is Dictionary)
		if node_value is Dictionary:
			var node: Dictionary = node_value
			assert_eq(_get_string(node, "scope"), "project_source")
			assert_eq(_get_string(node, "authority"), "filesystem_inventory")


func test_project_layout_snapshot_scope_changes_digest_and_bounds_profile_rules() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var complete_snapshot: Dictionary = _make_snapshot()
	var complete_analysis: Dictionary = analyzer.analyze_snapshot(
		complete_snapshot
	)
	var reduced_snapshot: Dictionary = complete_snapshot.duplicate(true)
	var reduced_scope: Dictionary = _get_dictionary(reduced_snapshot, "scope")
	reduced_scope["include_hidden"] = false
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.scope_boundary",
		"zones": [{
			"id": "missing_zone",
			"roots": ["never_observed"],
			"required": true,
			"severity": "error",
		}],
		"rules": [],
	}
	var reduced_analysis: Dictionary = analyzer.analyze_profile_snapshot(
		profile,
		reduced_snapshot
	)

	assert_true(_get_bool(complete_analysis, "input_complete"))
	assert_true(_get_bool(reduced_analysis, "success"))
	assert_false(_get_bool(reduced_analysis, "input_complete"))
	assert_ne(
		_get_string(complete_analysis, "input_digest"),
		_get_string(reduced_analysis, "input_digest"),
		"capture scope 必须参与库存摘要。"
	)
	assert_false(
		_finding_kinds(reduced_analysis).has("missing_required_zone_root"),
		"缩小隐藏路径范围后不能把未观察路径断言为确定缺失。"
	)
	var reduced_graph: Dictionary = _get_dictionary(reduced_analysis, "graph")
	assert_false(_get_bool(reduced_graph, "complete"))
	assert_false(
		_get_bool(_get_dictionary(reduced_graph, "scope"), "include_hidden", true)
	)
	var missing_exclusions_snapshot: Dictionary = complete_snapshot.duplicate(true)
	var missing_exclusions_scope: Dictionary = _get_dictionary(
		missing_exclusions_snapshot,
		"scope"
	)
	missing_exclusions_scope["excluded_prefixes"] = []
	var missing_exclusions_analysis: Dictionary = analyzer.analyze_snapshot(
		missing_exclusions_snapshot
	)
	assert_true(_get_bool(missing_exclusions_analysis, "success"))
	assert_false(_get_bool(missing_exclusions_analysis, "input_complete"))
	assert_true(
		_finding_kinds(missing_exclusions_analysis).has(
			"project_source_scope_incomplete"
		),
		"非权威排除集合必须带显式原因，不能静默退化为 UNKNOWN。"
	)
	assert_true(
		_get_array(
			_get_dictionary(
				_get_dictionary(missing_exclusions_analysis, "graph"),
				"scope"
			),
			"excluded_prefixes"
		).is_empty()
	)


func test_project_layout_analyzer_missing_root_has_no_observed_root_evidence() -> void:
	var root_path: String = (
		"res://build/gf_project_layout_tests/missing_%d/nested/leaf"
		% Time.get_ticks_usec()
	)
	assert_false(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path.get_base_dir())),
		"回归夹具必须让中间父目录也不存在。"
	)
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.missing_root",
		"zones": [{
			"id": "missing_zone",
			"roots": ["never_observed"],
			"required": true,
			"severity": "error",
		}],
		"rules": [],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile(
		profile,
		{
			"root_path": root_path,
			"allow_missing_root": true,
		}
	)

	assert_true(_get_bool(analysis, "success"))
	assert_false(_get_bool(analysis, "input_complete"))
	assert_eq(_get_string(analysis, "evaluation_status"), "input_incomplete")
	assert_false(_get_string(analysis, "input_digest").is_empty())
	assert_true(_finding_kinds(analysis).has("root_path_not_observed"))
	assert_false(_finding_kinds(analysis).has("linked_path_not_allowed"))
	assert_false(
		_finding_kinds(analysis).has("analysis_input_resource_limit_exceeded")
	)
	assert_false(_finding_kinds(analysis).has("missing_required_zone_root"))
	var graph: Dictionary = _get_dictionary(analysis, "graph")
	assert_false(_get_bool(graph, "complete"))
	assert_eq(_get_string(graph, "capture_status"), "not_started")
	assert_eq(
		_get_string(_get_dictionary(graph, "scope"), "root_path"),
		root_path
	)
	assert_true(_get_array(graph, "nodes").is_empty())
	assert_true(_get_array(graph, "edges").is_empty())
	assert_true(_get_array(graph, "evidence").is_empty())


func test_project_layout_analyzer_rejects_non_terminal_or_unexplained_partial_snapshot() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var non_terminal_snapshot: Dictionary = _make_snapshot()
	non_terminal_snapshot["complete"] = false
	non_terminal_snapshot["capture_status"] = "capturing"
	var non_terminal_analysis: Dictionary = analyzer.analyze_snapshot(
		non_terminal_snapshot
	)
	assert_false(_get_bool(non_terminal_analysis, "success"))
	assert_true(
		_finding_kinds(non_terminal_analysis).has(
			"invalid_snapshot_capture_status"
		)
	)

	var unexplained_partial_snapshot: Dictionary = _make_snapshot()
	unexplained_partial_snapshot["complete"] = false
	unexplained_partial_snapshot["capture_status"] = "partial"
	var unexplained_partial_analysis: Dictionary = analyzer.analyze_snapshot(
		unexplained_partial_snapshot
	)
	assert_false(_get_bool(unexplained_partial_analysis, "success"))
	assert_true(
		_finding_kinds(unexplained_partial_analysis).has(
			"snapshot_partial_without_capture_issue"
		)
	)


func test_project_layout_analyzer_validates_large_snapshot_with_set_indexes() -> void:
	var directories: Array = []
	var files: Array = []
	for index: int in 6000:
		var directory_path: String = "feature_%05d" % index
		directories.append(directory_path)
		files.append("%s/item.gd" % directory_path)
	var snapshot: Dictionary = _make_snapshot()
	snapshot["directories"] = directories
	snapshot["files"] = files
	var scope: Dictionary = _get_dictionary(snapshot, "scope")
	scope["max_scanned_files"] = 10000
	scope["max_scanned_directories"] = 10000
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(snapshot)

	assert_true(_get_bool(analysis, "success"))
	assert_true(_get_bool(analysis, "input_complete"))
	assert_eq(_get_int(analysis, "file_count"), 6000)
	assert_eq(_get_int(analysis, "directory_count"), 6000)
	assert_eq(
		_get_array(_get_dictionary(analysis, "graph"), "nodes").size(),
		12001
	)


func test_project_layout_public_analyzer_rejects_oversized_admission_inputs_once() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var oversized_options: Dictionary = {
		"field_0": true,
		"field_1": true,
		"field_2": true,
		"field_3": true,
		"field_4": true,
		"field_5": true,
		"field_6": true,
	}
	_assert_analysis_admission_terminal(analyzer.analyze(oversized_options))
	_assert_analysis_admission_terminal(analyzer.analyze({
		"root_path": "res://%s" % "a".repeat(20000),
	}))
	_assert_analysis_admission_terminal(analyzer.analyze_profile_path(
		"res://%s.json" % "p".repeat(20000)
	))
	_assert_analysis_admission_terminal(analyzer.analyze({
		"max_scanned_files": 20001,
	}))
	_assert_analysis_admission_terminal(analyzer.analyze({
		"max_scanned_directories": 20001,
	}))
	_assert_analysis_admission_terminal(analyzer.analyze({
		"max_scan_depth": 33,
	}))
	var oversized_profile_analysis: Dictionary = analyzer.analyze_profile({
		"schema_version": 1,
		"id": "profile_%s" % "i".repeat(20000),
		"zones": [],
		"rules": [],
	})
	assert_false(_get_bool(oversized_profile_analysis, "success"))
	assert_eq(_get_string(oversized_profile_analysis, "profile_id"), "")
	assert_true(_get_array(oversized_profile_analysis, "rule_results").is_empty())
	assert_eq(_get_array(oversized_profile_analysis, "findings").size(), 1)
	assert_eq(
		_finding_kinds(oversized_profile_analysis),
		PackedStringArray(["profile_compile_resource_limit_exceeded"])
	)


func test_project_layout_public_analyzer_rejects_oversized_or_cyclic_snapshot_once() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var oversized_files: Array = []
	var _oversized_resize_result: int = oversized_files.resize(20001)
	var oversized_snapshot: Dictionary = _make_snapshot()
	oversized_snapshot["files"] = oversized_files
	_assert_analysis_admission_terminal(analyzer.analyze_snapshot(oversized_snapshot))

	var oversized_path_snapshot: Dictionary = _make_snapshot()
	oversized_path_snapshot["files"] = ["a".repeat(16385)]
	oversized_path_snapshot["directories"] = []
	_assert_analysis_admission_terminal(
		analyzer.analyze_snapshot(oversized_path_snapshot)
	)
	var oversized_text_snapshot: Dictionary = _make_snapshot()
	var oversized_text_issues: Array = []
	var large_message: String = "界".repeat(16000)
	for index: int in 350:
		oversized_text_issues.append({
			"severity": "error",
			"kind": "large_%03d" % index,
			"path": "",
			"message": large_message,
		})
	oversized_text_snapshot["issues"] = oversized_text_issues
	_assert_analysis_admission_terminal(
		analyzer.analyze_snapshot(oversized_text_snapshot)
	)

	var cyclic_snapshot: Dictionary = _make_snapshot()
	var cyclic_issues: Array = []
	cyclic_issues.append({
		"severity": "error",
		"kind": "cycle",
		"path": "",
		"message": cyclic_issues,
	})
	cyclic_snapshot["issues"] = cyclic_issues
	_assert_analysis_admission_terminal(analyzer.analyze_snapshot(cyclic_snapshot))


func test_project_layout_snapshot_builder_rejects_oversized_options_before_scan() -> void:
	var oversized_field_builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	var begin_error: Error = oversized_field_builder.begin("res://", {
		"field_0": true,
		"field_1": true,
		"field_2": true,
		"field_3": true,
		"field_4": true,
	})
	assert_eq(begin_error, ERR_INVALID_PARAMETER)
	assert_eq(_get_array(oversized_field_builder.get_progress(), "issues").size(), 1)
	assert_eq(
		_issue_kinds(oversized_field_builder.get_progress()),
		PackedStringArray(["snapshot_builder_resource_limit_exceeded"])
	)

	for budget_options: Dictionary in [
		{ "max_scanned_files": 20001 },
		{ "max_scanned_directories": 20001 },
		{ "max_scan_depth": 33 },
	]:
		var budget_builder: GFProjectLayoutEditorSnapshotBuilder = \
			_SNAPSHOT_BUILDER_SCRIPT.new()
		assert_eq(
			budget_builder.begin("res://", budget_options),
			ERR_INVALID_PARAMETER
		)
		assert_eq(_get_array(budget_builder.get_progress(), "issues").size(), 1)
		assert_eq(
			_issue_kinds(budget_builder.get_progress()),
			PackedStringArray(["snapshot_builder_resource_limit_exceeded"])
		)


func test_project_layout_snapshot_builder_only_publishes_analyzable_terminal_states() -> void:
	var idle_builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_true(idle_builder.make_snapshot().is_empty())

	var root_path: String = \
		"res://build/gf_project_layout_tests/builder_terminal_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join("item.gd"), "extends RefCounted\n")
	var capturing_builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(capturing_builder.begin(root_path), OK)
	assert_true(capturing_builder.make_snapshot().is_empty())
	capturing_builder.cancel()
	var _cancel_progress: Dictionary = capturing_builder.step(1)
	assert_eq(capturing_builder.get_status(), "cancelled")
	assert_true(capturing_builder.make_snapshot().is_empty())

	var failed_builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(
		failed_builder.begin("res://", { "max_scan_depth": 33 }),
		ERR_INVALID_PARAMETER
	)
	assert_eq(failed_builder.get_status(), "failed")
	assert_true(failed_builder.make_snapshot().is_empty())
	_remove_directory_tree(root_path)


func test_project_layout_inventory_ceiling_flows_through_background_analysis_and_plan() -> void:
	var directories: Array = []
	var files: Array = []
	for index: int in 20000:
		var directory_path: String = "ceiling_%05d" % index
		directories.append(directory_path)
		files.append("%s/item.gd" % directory_path)
	var snapshot: Dictionary = _make_snapshot()
	snapshot["directories"] = directories
	snapshot["files"] = files

	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.inventory_ceiling",
		"zones": [],
		"rules": [],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(profile)
	assert_true(_get_bool(compilation, "success"))
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var worker_result: Dictionary = worker.run_request({
		"generation": 40001,
		"snapshot": snapshot,
		"profile_compilation_present": true,
		"profile_compilation": compilation,
		"plan_options": {},
	})
	assert_eq(_get_string(worker_result, "status"), "complete")
	assert_true(_get_array(worker_result, "issues").is_empty())
	var analysis: Dictionary = _get_dictionary(worker_result, "analysis")
	assert_true(_get_bool(analysis, "success"))
	assert_true(_get_bool(analysis, "input_complete"))
	assert_true(_get_bool(analysis, "evaluation_complete"))
	assert_eq(_get_int(analysis, "directory_count"), 20000)
	assert_eq(_get_int(analysis, "file_count"), 20000)
	var graph: Dictionary = _get_dictionary(analysis, "graph")
	assert_eq(_get_array(graph, "nodes").size(), 40001)
	assert_eq(_get_array(graph, "edges").size(), 40000)
	assert_eq(_get_array(graph, "evidence").size(), 40002)

	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var validation: Dictionary = contract.validate_and_index(analysis)
	assert_true(_get_bool(validation, "valid"))

	var plan: Dictionary = _get_dictionary(worker_result, "plan")
	assert_true(_get_bool(plan, "complete"))
	assert_true(_get_array(plan, "issues").is_empty())
	assert_eq(
		_get_string(plan, "contract_digest"),
		_get_string(compilation, "contract_digest")
	)


func test_project_layout_analyzer_large_set_indexes_stay_linear() -> void:
	var directories: PackedStringArray = PackedStringArray()
	var allowed_subdirs: Array = []
	for index: int in 20000:
		var child_id: String = "child_%05d" % index
		var _append_directory: bool = directories.append(
			"features/%s" % child_id
		)
		allowed_subdirs.append(child_id)
	var analyzer: ChildDirectoryProbeAnalyzer = ChildDirectoryProbeAnalyzer.new()
	var direct_children: PackedStringArray = analyzer.collect_direct_children(
		{ "directories": directories },
		"features"
	)
	assert_eq(direct_children.size(), 20000)
	var allowed: PackedStringArray = analyzer.collect_allowed_subdirs({
		"_feature_contract_rules_by_root": {
			"features": [{ "allowed_subdirs": allowed_subdirs }],
		},
	})
	assert_eq(allowed.size(), 20000)


func test_project_layout_analyzer_rejects_snapshot_without_parent_closure() -> void:
	var snapshot: Dictionary = {
		"schema_version": 1,
		"kind": "project_layout_snapshot",
		"root_path": "res://",
		"scope": _make_scope("res://"),
		"complete": true,
		"capture_status": "complete",
		"files": ["features/inventory/item.gd"],
		"directories": [],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(snapshot)
	assert_false(_get_bool(analysis, "success"))
	assert_false(_get_bool(analysis, "evaluation_complete"))
	assert_true(_finding_kinds(analysis).has("snapshot_parent_not_observed"))
	assert_true(_get_array(_get_dictionary(analysis, "graph"), "edges").is_empty())


func test_project_layout_analyzer_preserves_partial_capture_reason() -> void:
	var snapshot: Dictionary = _make_snapshot()
	snapshot["complete"] = false
	snapshot["capture_status"] = "partial"
	snapshot["issues"] = [{
		"severity": "error",
		"kind": "linked_path_not_allowed",
		"path": "vendor/shared",
		"message": "项目库存不会穿过链接。",
	}]
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(snapshot)
	assert_true(_get_bool(analysis, "success"), "捕获不完整应降级结论，而不是丢弃可用库存。")
	assert_false(_get_bool(analysis, "evaluation_complete"))
	assert_true(_finding_kinds(analysis).has("linked_path_not_allowed"))
	assert_false(_get_array(_get_dictionary(analysis, "graph"), "nodes").is_empty())


func test_project_layout_analyzer_does_not_apply_profile_to_partial_inventory() -> void:
	var snapshot: Dictionary = _make_snapshot()
	snapshot["complete"] = false
	snapshot["capture_status"] = "partial"
	snapshot["issues"] = [{
		"severity": "error",
		"kind": "scan_budget_reached",
		"path": "features",
		"message": "测试库存只捕获了部分路径。",
	}]
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.partial",
		"zones": [{
			"id": "missing_zone",
			"roots": ["never_observed"],
			"required": true,
			"severity": "error",
		}],
		"rules": [],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile_snapshot(profile, snapshot)
	assert_false(_get_bool(analysis, "evaluation_complete"))
	assert_true(_finding_kinds(analysis).has("scan_budget_reached"))
	assert_false(
		_finding_kinds(analysis).has("missing_required_zone_root"),
		"不完整库存不能把未观察到的目录误报为确定缺失。"
	)


func test_project_layout_analyzer_rejects_complete_snapshot_with_capture_error() -> void:
	var snapshot: Dictionary = _make_snapshot()
	snapshot["capture_status"] = "complete"
	snapshot["issues"] = [{
		"severity": "error",
		"kind": "directory_scan_failed",
		"path": "features",
		"message": "测试捕获错误。",
	}]
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(snapshot)
	assert_false(_get_bool(analysis, "success"))
	assert_false(_get_bool(analysis, "evaluation_complete"))
	assert_true(_finding_kinds(analysis).has("snapshot_complete_with_capture_error"))


func test_project_layout_missing_finding_uses_complete_inventory_evidence() -> void:
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.absence_evidence",
		"zones": [{
			"id": "missing_zone",
			"roots": ["not_present"],
			"required": true,
			"severity": "warning",
		}],
		"rules": [],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile_snapshot(profile, _make_snapshot())
	var finding: Dictionary = _finding_by_kind(analysis, "missing_required_zone_root")
	assert_false(finding.is_empty())
	assert_false(_get_array(finding, "evidence_ids").is_empty())
	var explanation: Dictionary = analyzer.explain_finding(
		analysis,
		_get_string(finding, "finding_id")
	)
	assert_true(_get_bool(explanation, "complete"))
	assert_eq(_get_string(explanation, "certainty"), "known")
	assert_false(_get_array(explanation, "evidence").is_empty())


func test_project_layout_analyzer_applies_profile_without_second_scanner() -> void:
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.read_only",
		"zones": [],
		"rules": [{
			"id": "root_files",
			"kind": "forbid_root_files",
			"severity": "warning",
			"allowed_files": [],
		}],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile_snapshot(
		profile,
		_make_snapshot()
	)
	assert_true(_get_bool(analysis, "evaluation_complete"))
	assert_true(_finding_kinds(analysis).has("forbidden_root_file"))
	assert_eq(
		_get_string(_get_dictionary(analysis, "effects"), "writes_project"),
		"",
		"effects.writes_project 是 bool，不应伪装成文本。"
	)
	assert_false(
		_get_bool(_get_dictionary(analysis, "effects"), "writes_project", true)
	)


func test_project_layout_validator_is_only_analyzer_compatibility_facade() -> void:
	var source: String = _read_text(_VALIDATOR_PATH)
	assert_true(source.contains("gf_project_layout_analyzer.gd"))
	assert_true(source.contains("@deprecated 11.0.0"))
	assert_false(source.contains("func _scan_project"))
	assert_false(source.contains("func _make_rule_registry"))
	assert_false(source.contains("_SUPPORTED_RULE_KINDS"))


func test_project_layout_impact_stays_unknown_without_dependency_coverage() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(_make_snapshot())
	var impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{
			"kind": "delete",
			"source_path": "features/inventory",
		}
	)
	assert_true(_get_bool(impact, "complete"))
	assert_eq(_get_string(impact, "status"), "unknown")
	assert_true(_blocker_kinds(impact).has("dependency_coverage_incomplete"))
	assert_false(_get_bool(_get_dictionary(impact, "effects"), "writes_project", true))


func test_project_layout_impact_rejects_spoofed_coverage_and_descendant_target() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(_make_snapshot())
	var spoofed: Dictionary = analysis.duplicate(true)
	var spoofed_graph: Dictionary = _get_dictionary(spoofed, "graph")
	spoofed_graph["dependency_coverage"] = "complete"
	var spoofed_impact: Dictionary = analyzer.analyze_change_impact(
		spoofed,
		{ "kind": "delete", "source_path": "features/inventory" }
	)
	assert_eq(_get_string(spoofed_impact, "status"), "unsafe")
	assert_true(_issue_kinds(spoofed_impact).has("invalid_analysis"))

	var nested_target_impact: Dictionary = analyzer.analyze_change_impact(
		analysis,
		{
			"kind": "move",
			"source_path": "features",
			"target_path": "features/inventory/new_home",
		}
	)
	assert_eq(_get_string(nested_target_impact, "status"), "unsafe")
	assert_true(_blocker_kinds(nested_target_impact).has("target_inside_source"))


func test_project_layout_explanation_preserves_evidence_and_never_applies() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.explain_real_finding",
		"zones": [{
			"id": "missing_zone",
			"roots": ["missing/required_zone"],
			"required": true,
			"severity": "warning",
		}],
		"rules": [],
	}
	var analysis: Dictionary = analyzer.analyze_profile_snapshot(
		profile,
		_make_snapshot()
	)
	var finding: Dictionary = _finding_by_kind(
		analysis,
		"missing_required_zone_root"
	)
	assert_false(finding.is_empty())
	var explanation: Dictionary = analyzer.explain_finding(
		analysis,
		_get_string(finding, "finding_id")
	)
	assert_true(_get_bool(explanation, "complete"))
	assert_eq(_get_string(explanation, "certainty"), "known")
	assert_false(_get_array(explanation, "evidence").is_empty())
	assert_false(
		_get_bool(_get_dictionary(explanation, "effects"), "writes_project", true)
	)


func test_project_layout_snapshot_builder_captures_in_bounded_steps() -> void:
	var builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(
		builder.begin("res://tests/gf_core/tools/project_layout"),
		OK
	)
	var step_count: int = 0
	while not builder.is_finished() and step_count < 1000:
		var progress: Dictionary = builder.step(3)
		assert_true(_get_int(progress, "file_count") >= 0)
		step_count += 1
	assert_true(builder.is_finished())
	assert_eq(builder.get_status(), "complete")
	var snapshot: Dictionary = builder.make_snapshot()
	assert_true(_get_bool(snapshot, "complete"))
	assert_true(
		_string_array(_get_array(snapshot, "files")).has(
			"test_gf_project_layout_tool_package.gd"
		)
		)


func test_project_layout_snapshot_builder_defaults_to_complete_project_source_scope() -> void:
	var root_path: String = "res://build/gf_project_layout_tests/scope_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join(".config/tool.json"), "{}\n")
	_write_text(root_path.path_join(".git/internal"), "ignored\n")
	_write_text(root_path.path_join(".godot/internal"), "ignored\n")
	_write_text(root_path.path_join(".import/internal"), "ignored\n")
	var builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(builder.begin(root_path), OK)
	var guard: int = 0
	while not builder.is_finished() and guard < 128:
		var _progress: Dictionary = builder.step(4)
		guard += 1
	var snapshot: Dictionary = builder.make_snapshot()
	var files: PackedStringArray = _string_array(_get_array(snapshot, "files"))
	var scope: Dictionary = _get_dictionary(snapshot, "scope")

	assert_eq(builder.get_status(), "complete")
	assert_true(files.has(".config/tool.json"))
	assert_false(files.has(".git/internal"))
	assert_false(files.has(".godot/internal"))
	assert_false(files.has(".import/internal"))
	assert_true(_get_bool(scope, "include_hidden"))
	assert_eq(
		_get_array(scope, "excluded_prefixes"),
		[".git", ".godot", ".import"]
	)
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(snapshot)
	assert_true(_get_bool(analysis, "input_complete"))
	_remove_directory_tree(root_path)


func test_project_layout_analyzer_applies_hidden_scope_to_directory_enumeration() -> void:
	var root_path: String = \
		"res://build/gf_project_layout_tests/analyzer_hidden_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join(".config/tool.json"), "{}\n")
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()

	var complete_analysis: Dictionary = analyzer.analyze({ "root_path": root_path })
	assert_true(_get_bool(complete_analysis, "input_complete"))
	assert_eq(_get_int(complete_analysis, "file_count"), 1)
	assert_eq(_get_int(complete_analysis, "directory_count"), 1)

	var visible_analysis: Dictionary = analyzer.analyze({
		"root_path": root_path,
		"include_hidden": false,
	})
	assert_false(_get_bool(visible_analysis, "input_complete"))
	assert_eq(_get_int(visible_analysis, "file_count"), 0)
	assert_eq(_get_int(visible_analysis, "directory_count"), 0)
	var visible_graph: Dictionary = _get_dictionary(visible_analysis, "graph")
	assert_false(_get_bool(_get_dictionary(visible_graph, "scope"), "include_hidden", true))
	_remove_directory_tree(root_path)


func test_project_layout_snapshot_builder_rejects_escape_and_bounds_empty_directories() -> void:
	var rejected_builder: GFProjectLayoutEditorSnapshotBuilder = \
		_SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(rejected_builder.begin("res://../outside"), ERR_INVALID_PARAMETER)
	assert_eq(rejected_builder.begin("user://outside"), ERR_INVALID_PARAMETER)
	assert_eq(rejected_builder.begin("res://foo//bar"), ERR_INVALID_PARAMETER)
	assert_eq(rejected_builder.begin("res://foo/./bar"), ERR_INVALID_PARAMETER)
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	for invalid_root: String in [
		"user://outside",
		"res://foo//bar",
		"res://foo/./bar",
		"C:/outside",
	]:
		var invalid_analysis: Dictionary = analyzer.analyze({
			"root_path": invalid_root,
			"allow_missing_root": true,
		})
		assert_false(_get_bool(invalid_analysis, "success"))
		assert_true(_finding_kinds(invalid_analysis).has("unsupported_root_path"))

	var root_path: String = "res://build/gf_project_layout_tests/bounded_%d" % Time.get_ticks_usec()
	var absolute_root: String = ProjectSettings.globalize_path(root_path)
	var _make_root_error: Error = DirAccess.make_dir_recursive_absolute(absolute_root)
	var child_names: PackedStringArray = ["a", "b", "c", "d"]
	for child_name: String in child_names:
		var _make_child_error: Error = DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(root_path.path_join(child_name))
		)
	var builder: GFProjectLayoutEditorSnapshotBuilder = _SNAPSHOT_BUILDER_SCRIPT.new()
	assert_eq(builder.begin(root_path), OK)
	var guard: int = 0
	while _get_int(builder.get_progress(), "directory_count") < child_names.size() and guard < 32:
		var _progress: Dictionary = builder.step(1)
		guard += 1
	assert_eq(_get_int(builder.get_progress(), "directory_count"), child_names.size())
	var before_pending: int = _get_int(builder.get_progress(), "pending_directory_count")
	var _bounded_progress: Dictionary = builder.step(1)
	var after_pending: int = _get_int(builder.get_progress(), "pending_directory_count")
	assert_true(before_pending >= 3)
	assert_eq(after_pending, before_pending - 1, "一次 step(1) 最多打开一个空目录。")
	builder.cancel()
	var _cancel_progress: Dictionary = builder.step(1)
	for child_name: String in child_names:
		var _remove_child_error: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(root_path.path_join(child_name))
		)
	var _remove_root_error: Error = DirAccess.remove_absolute(absolute_root)


func test_project_layout_snapshot_builder_rechecks_link_chain_after_open() -> void:
	var root_path: String = "res://build/gf_project_layout_tests/builder_link_swap_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join("outside_canary.gd"), "extends RefCounted\n")
	var builder: LinkSwapSnapshotBuilder = LinkSwapSnapshotBuilder.new()
	builder.reject_on_probe_call = 3

	assert_eq(builder.begin(root_path), OK)
	var _progress: Dictionary = builder.step(8)
	var snapshot: Dictionary = builder.make_snapshot()

	assert_eq(builder.get_status(), "partial")
	assert_eq(builder.probed_paths.size(), 3)
	for probed_path: String in builder.probed_paths:
		assert_eq(probed_path, root_path)
	assert_true(_issue_kinds(snapshot).has("linked_path_not_allowed"))
	assert_false(
		_string_array(_get_array(snapshot, "files")).has("outside_canary.gd"),
		"打开后的链复核拒绝时不得枚举或收录目标目录条目。"
	)
	_remove_directory_tree(root_path)


func test_project_layout_analyzer_rechecks_link_chain_after_open() -> void:
	var root_path: String = "res://build/gf_project_layout_tests/analyzer_link_swap_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join("outside_canary.gd"), "extends RefCounted\n")
	var analyzer: LinkSwapAnalyzer = LinkSwapAnalyzer.new()
	analyzer.reject_on_probe_call = 3

	var analysis: Dictionary = analyzer.analyze({ "root_path": root_path })

	assert_false(_get_bool(analysis, "input_complete"))
	assert_eq(_get_int(analysis, "file_count"), 0)
	assert_eq(analyzer.probed_paths.size(), 3)
	for probed_path: String in analyzer.probed_paths:
		assert_eq(probed_path, root_path)
	assert_true(_finding_kinds(analysis).has("linked_path_not_allowed"))
	_remove_directory_tree(root_path)


func test_project_layout_analyzer_direct_scan_resource_failure_is_terminal() -> void:
	var root_path: String = \
		"res://build/gf_project_layout_tests/analyzer_path_cap_%d" % Time.get_ticks_usec()
	_write_text(root_path.path_join("item.gd"), "extends RefCounted\n")
	var analyzer: OversizedJoinAnalyzer = OversizedJoinAnalyzer.new()
	var analysis: Dictionary = analyzer.analyze({ "root_path": root_path })
	_assert_analysis_admission_terminal(analysis)
	var invalid_join_analyzer: InvalidJoinAnalyzer = InvalidJoinAnalyzer.new()
	var rejected_attachment: Dictionary = invalid_join_analyzer.analyze({
		"root_path": root_path,
	})
	_assert_analysis_admission_terminal(rejected_attachment)
	_remove_directory_tree(root_path)


func test_project_layout_worker_is_data_only_and_cooperatively_cancelled() -> void:
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var worker_source: String = _read_text(
		"res://addons/gf/tools/project_layout/editor/gf_project_layout_scan_worker.gd"
	)
	assert_false(worker_source.contains("FileAccess"))
	assert_false(worker_source.contains("DirAccess"))
	assert_false(worker_source.contains("analyze_profile_snapshot("))
	assert_true(worker_source.contains("plan_compiled_profile_analysis("))
	assert_eq(worker_source.count("\"cancel_check\": cancel_check"), 2)
	assert_true(worker_source.contains("_PLANNER_SCRIPT.MAX_WORK_UNITS"))
	var result: Dictionary = worker.run_request({
		"generation": 7,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
	})
	assert_eq(_get_int(result, "generation"), 7)
	assert_eq(_get_string(result, "status"), "complete")
	assert_eq(
		_sorted_dictionary_keys(result),
		PackedStringArray([
			"analysis",
			"generation",
			"issues",
			"kind",
			"plan",
			"schema_version",
			"status",
		])
	)
	assert_eq(
		_get_string(_get_dictionary(result, "analysis"), "kind"),
		"project_layout_analysis"
	)
	assert_true(_get_dictionary(result, "plan").is_empty())
	assert_true(_is_strict_data_only(result))
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile({
		"schema_version": 1,
		"id": "test.worker_compilation",
		"zones": [{
			"id": "app",
			"roots": ["app"],
			"required": true,
			"severity": "error",
		}],
		"rules": [],
	})
	assert_true(_is_lower_sha256(_get_string(compilation, "contract_digest")))
	var compiled_result: Dictionary = worker.run_request({
		"generation": 71,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": true,
		"profile_compilation": compilation,
		"plan_options": {},
	})
	assert_eq(_get_string(compiled_result, "status"), "complete")
	assert_eq(
		_get_string(_get_dictionary(compiled_result, "analysis"), "profile_id"),
		"test.worker_compilation"
	)
	var compiled_analysis: Dictionary = _get_dictionary(
		compiled_result,
		"analysis"
	)
	var plan: Dictionary = _get_dictionary(compiled_result, "plan")
	assert_eq(_get_string(plan, "kind"), "project_layout_plan")
	assert_true(_get_bool(plan, "complete"))
	assert_eq(_get_string(plan, "profile_id"), "test.worker_compilation")
	assert_eq(
		_get_string(plan, "source_analysis_digest"),
		_get_string(compiled_analysis, "input_digest")
	)
	assert_eq(
		_get_string(plan, "contract_digest"),
		_get_string(compilation, "contract_digest")
	)
	assert_eq(
		_sorted_dictionary_keys(plan),
		PackedStringArray([
			"blockers",
			"capabilities",
			"complete",
			"contract_digest",
			"issues",
			"kind",
			"profile_id",
			"project_root",
			"schema_version",
			"source_analysis_digest",
			"steps",
		])
	)
	var steps: Array = _get_array(plan, "steps")
	assert_eq(steps.size(), 1)
	var step: Dictionary = _get_dictionary_at(steps, 0)
	assert_eq(_get_string(step, "relative_path"), "app")
	assert_eq(
		_sorted_dictionary_keys(step),
		PackedStringArray([
			"evidence_ids",
			"kind",
			"preconditions",
			"relative_path",
			"requires",
			"risk",
			"step_id",
		])
	)
	assert_true(_is_strict_data_only(compiled_result))
	var malformed: Dictionary = worker.run_request({
		"generation": 8,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
		"unexpected": true,
	})
	assert_eq(_get_string(malformed, "status"), "failed")
	assert_true(_issue_kinds(malformed).has("invalid_worker_request"))
	var oversized_worker_snapshot: Dictionary = _make_snapshot()
	var oversized_worker_root: String = "res://%s" % "w".repeat(16385)
	oversized_worker_snapshot["root_path"] = oversized_worker_root
	var oversized_worker_scope: Dictionary = _get_dictionary(
		oversized_worker_snapshot,
		"scope"
	)
	oversized_worker_scope["root_path"] = oversized_worker_root
	var oversized_worker_result: Dictionary = worker.run_request({
		"generation": 81,
		"snapshot": oversized_worker_snapshot,
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
	})
	assert_eq(_get_string(oversized_worker_result, "status"), "failed")
	assert_eq(
		_issue_kinds(oversized_worker_result),
		PackedStringArray(["invalid_snapshot"])
	)
	worker.cancel()
	var cancelled: Dictionary = worker.run_request({
		"generation": 9,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
	})
	assert_eq(_get_string(cancelled, "status"), "cancelled")
	assert_true(_get_dictionary(cancelled, "analysis").is_empty())
	assert_true(_get_dictionary(cancelled, "plan").is_empty())
	assert_true(_is_strict_data_only(cancelled))


func test_project_layout_worker_query_is_generation_bound_closed_and_data_only() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_profile_snapshot(
		{
			"schema_version": 1,
			"id": "test.background_query",
			"zones": [{
				"id": "missing_zone",
				"roots": ["missing/required_zone"],
				"required": true,
				"severity": "warning",
			}],
			"rules": [],
		},
		_make_snapshot()
	)
	var finding: Dictionary = _finding_by_kind(
		analysis,
		"missing_required_zone_root"
	)
	assert_false(finding.is_empty())
	var analysis_digest: String = _get_string(analysis, "input_digest")
	assert_true(_is_lower_sha256(analysis_digest))
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var configured_worker: GFProjectLayoutScanWorker = worker.configure_query_session(
		analysis,
		201,
		analysis_digest
	)
	assert_eq(configured_worker, worker)
	var explanation_result: Dictionary = worker.run_query_request({
		"generation": 201,
		"analysis_digest": analysis_digest,
		"query_kind": "explain_finding",
		"query": { "finding_id": _get_string(finding, "finding_id") },
	})
	assert_eq(_get_string(explanation_result, "status"), "complete")
	assert_eq(
		_sorted_dictionary_keys(explanation_result),
		PackedStringArray([
			"analysis_digest",
			"explanation",
			"generation",
			"impact",
			"issues",
			"kind",
			"query_kind",
			"schema_version",
			"status",
		])
	)
	var explanation: Dictionary = _get_dictionary(
		explanation_result,
		"explanation"
	)
	assert_eq(_get_string(explanation, "kind"), "project_layout_explanation")
	assert_true(_get_bool(explanation, "complete"))
	assert_false(
		_get_bool(_get_dictionary(explanation, "effects"), "writes_project", true)
	)
	assert_true(_get_dictionary(explanation_result, "impact").is_empty())
	assert_true(_is_strict_data_only(explanation_result))

	var impact_result: Dictionary = worker.run_query_request({
		"generation": 201,
		"analysis_digest": analysis_digest,
		"query_kind": "analyze_change_impact",
		"query": {
			"kind": "delete",
			"source_path": "features/inventory",
			"target_path": "",
		},
	})
	assert_eq(_get_string(impact_result, "status"), "complete")
	var impact: Dictionary = _get_dictionary(impact_result, "impact")
	assert_eq(_get_string(impact, "kind"), "project_layout_impact")
	assert_eq(_get_string(impact, "source_analysis_digest"), analysis_digest)
	assert_true(_get_dictionary(impact_result, "explanation").is_empty())
	assert_false(
		_get_bool(_get_dictionary(impact, "effects"), "writes_project", true)
	)
	assert_true(_is_strict_data_only(impact_result))

	var stale_result: Dictionary = worker.run_query_request({
		"generation": 202,
		"analysis_digest": analysis_digest,
		"query_kind": "explain_finding",
		"query": { "finding_id": _get_string(finding, "finding_id") },
	})
	assert_eq(_get_string(stale_result, "status"), "failed")
	assert_eq(_issue_kinds(stale_result), PackedStringArray(["query_session_mismatch"]))
	assert_true(_get_dictionary(stale_result, "explanation").is_empty())
	assert_true(_get_dictionary(stale_result, "impact").is_empty())

	var open_request_result: Dictionary = worker.run_query_request({
		"generation": 201,
		"analysis_digest": analysis_digest,
		"query_kind": "explain_finding",
		"query": { "finding_id": _get_string(finding, "finding_id") },
		"unexpected": true,
	})
	assert_eq(_get_string(open_request_result, "status"), "failed")
	assert_eq(
		_issue_kinds(open_request_result),
		PackedStringArray(["invalid_query_request"])
	)
	assert_true(_is_strict_data_only(open_request_result))

	var cancelled_worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var _configured_cancelled_worker: GFProjectLayoutScanWorker = (
		cancelled_worker.configure_query_session(analysis, 203, analysis_digest)
	)
	cancelled_worker.cancel()
	var cancelled_result: Dictionary = cancelled_worker.run_query_request({
		"generation": 203,
		"analysis_digest": analysis_digest,
		"query_kind": "explain_finding",
		"query": { "finding_id": _get_string(finding, "finding_id") },
	})
	assert_eq(_get_string(cancelled_result, "status"), "cancelled")
	assert_true(_get_dictionary(cancelled_result, "explanation").is_empty())
	assert_true(_get_dictionary(cancelled_result, "impact").is_empty())
	assert_true(_get_array(cancelled_result, "issues").is_empty())

	var limited_worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	limited_worker.set(&"_query_work_units", 16_000_000)
	_assert_bool_call_result(
		limited_worker.call(&"_query_checkpoint_allows", 1),
		false
	)
	var terminal_value: Variant = limited_worker.call(
		&"_make_query_result",
		204,
		analysis_digest,
		"explain_finding"
	)
	assert_true(terminal_value is Dictionary)
	if terminal_value is Dictionary:
		var terminal: Dictionary = terminal_value
		terminal["explanation"] = { "must_not_escape": true }
		_assert_bool_call_result(
			limited_worker.call(&"_apply_query_terminal", terminal),
			true
		)
		assert_eq(_get_string(terminal, "status"), "failed")
		assert_true(_get_dictionary(terminal, "explanation").is_empty())
		assert_true(_get_dictionary(terminal, "impact").is_empty())
		assert_eq(
			_issue_kinds(terminal),
			PackedStringArray(["query_work_budget_exhausted"])
		)


func test_project_layout_worker_completes_maximum_inventory_impact_query() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(
		_make_large_snapshot(20_000)
	)
	assert_true(_get_bool(analysis, "evaluation_complete"))
	assert_eq(
		_get_array(_get_dictionary(analysis, "graph"), "nodes").size(),
		40_001
	)
	var analysis_digest: String = _get_string(analysis, "input_digest")
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var _configured_worker: GFProjectLayoutScanWorker = worker.configure_query_session(
		analysis,
		211,
		analysis_digest
	)
	var request: Dictionary = {
		"generation": 211,
		"analysis_digest": analysis_digest,
		"query_kind": "analyze_change_impact",
		"query": {
			"kind": "delete",
			"source_path": ".",
			"target_path": "",
		},
	}
	var result: Dictionary = worker.run_query_request(request)

	assert_eq(_get_string(result, "status"), "complete")
	var impact: Dictionary = _get_dictionary(result, "impact")
	assert_eq(_get_string(impact, "status"), "unsafe")
	assert_eq(
		_get_array(impact, "affected_node_ids").size(),
		40_001
	)
	assert_eq(_get_array(impact, "evidence_ids").size(), 40_001)
	assert_true(_get_dictionary(result, "explanation").is_empty())
	assert_true(_is_strict_data_only(result))


func test_project_layout_impact_checkpoint_stops_after_validation_during_traversal() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var analysis: Dictionary = analyzer.analyze_snapshot(_make_large_snapshot(512))
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var validation: Dictionary = contract.validate_and_index(analysis)
	assert_true(_get_bool(validation, "valid"))
	var checkpoint: WeightedQueryCheckpoint = WeightedQueryCheckpoint.new()
	checkpoint.stop_after_work_units = 128
	var impact_analyzer: _IMPACT_ANALYZER_SCRIPT = _IMPACT_ANALYZER_SCRIPT.new()
	var impact: Dictionary = impact_analyzer.analyze_validated_change(
		analysis,
		validation,
		{
			"kind": "delete",
			"source_path": ".",
			"target_path": "",
		},
		Callable(checkpoint, "consume")
	)

	assert_false(_get_bool(impact, "complete"))
	assert_eq(_get_string(impact, "status"), "unknown")
	assert_eq(_issue_kinds(impact), PackedStringArray(["impact_checkpoint_stopped"]))
	assert_true(_get_array(impact, "affected_node_ids").is_empty())
	assert_true(_get_array(impact, "blockers").is_empty())
	assert_true(_get_array(impact, "evidence_ids").is_empty())
	assert_gte(checkpoint.total_work_units, 128)
	assert_gt(checkpoint.call_count, 64)


func test_project_layout_worker_rejects_open_options_and_forged_compilation_digest() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile({
		"schema_version": 1,
		"id": "test.worker_digest",
		"zones": [],
		"rules": [],
	})
	assert_true(_get_bool(compilation, "success"))
	assert_true(_is_lower_sha256(_get_string(compilation, "contract_digest")))
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var missing_options: Dictionary = worker.run_request({
		"generation": 91,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": true,
		"profile_compilation": compilation,
	})
	assert_eq(_get_string(missing_options, "status"), "failed")
	assert_eq(
		_issue_kinds(missing_options),
		PackedStringArray(["invalid_worker_request"])
	)

	var object_option: Node = Node.new()
	var invalid_options: Dictionary = worker.run_request({
		"generation": 92,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": true,
		"profile_compilation": compilation,
		"plan_options": { "feature_ids": [object_option] },
	})
	assert_eq(_get_string(invalid_options, "status"), "failed")
	assert_eq(
		_issue_kinds(invalid_options),
		PackedStringArray(["invalid_plan_options"])
	)
	assert_true(_get_dictionary(invalid_options, "analysis").is_empty())
	assert_true(_get_dictionary(invalid_options, "plan").is_empty())
	object_option.free()

	var uppercase_digest: Dictionary = compilation.duplicate(true)
	uppercase_digest["contract_digest"] = "A".repeat(64)
	var noncanonical_digest: Dictionary = compilation.duplicate(true)
	noncanonical_digest["contract_digest"] = "0".repeat(64)
	var missing_digest: Dictionary = compilation.duplicate(true)
	var _digest_removed: bool = missing_digest.erase("contract_digest")
	for forged_compilation: Dictionary in [
		uppercase_digest,
		noncanonical_digest,
		missing_digest,
	]:
		var rejected: Dictionary = worker.run_request({
			"generation": 93,
			"snapshot": _make_snapshot(),
			"profile_compilation_present": true,
			"profile_compilation": forged_compilation,
			"plan_options": {},
		})
		assert_eq(_get_string(rejected, "status"), "failed")
		assert_true(_get_dictionary(rejected, "analysis").is_empty())
		assert_true(_get_dictionary(rejected, "plan").is_empty())
		assert_false(_get_array(rejected, "issues").is_empty())
		assert_true(_is_strict_data_only(rejected))


func test_project_layout_background_planning_cancels_after_entering_work() -> void:
	var zones: Array = []
	for index: int in 128:
		zones.append({
			"id": "optional_%03d" % index,
			"roots": ["optional_%03d" % index],
			"required": false,
			"severity": "warning",
		})
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile({
		"schema_version": 1,
		"id": "test.background_planning_cancel",
		"zones": zones,
		"rules": [],
	})
	assert_true(_get_bool(compilation, "success"))
	var analysis: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		compilation,
		_make_snapshot()
	)
	assert_true(_get_bool(analysis, "evaluation_complete"))
	var cancel_probe: CancelAfterChecks = CancelAfterChecks.new()
	cancel_probe.cancel_after = 2
	var planner: GFProjectLayoutPlanner = _PLANNER_SCRIPT.new()
	var plan: Dictionary = planner.plan_compiled_profile_analysis(
		compilation,
		analysis,
		{ "include_optional_zones": true },
		{
			"cancel_check": Callable(cancel_probe, "should_cancel"),
			"max_work_units": 262_144,
		}
	)
	assert_true(cancel_probe.call_count >= 2, "取消必须发生在 Planner 已进入有界工作后。")
	assert_false(_get_bool(plan, "complete"))
	assert_true(_get_array(plan, "steps").is_empty())
	assert_true(_get_array(plan, "blockers").is_empty())
	assert_eq(_issue_kinds(plan), PackedStringArray(["planning_cancelled"]))
	assert_true(_is_strict_data_only(plan))


func test_project_layout_worker_applies_text_envelopes_per_payload() -> void:
	var shared_text: String = "界".repeat(8000)
	var within_limit_payload: Array = []
	for _within_index: int in 698:
		within_limit_payload.append(shared_text)
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var combined_result: Dictionary = worker.run_request({
		"generation": 82,
		"snapshot": { "payload": within_limit_payload },
		"profile_compilation_present": true,
		"profile_compilation": { "payload": within_limit_payload },
		"plan_options": {},
	})
	assert_eq(_get_string(combined_result, "status"), "failed")
	assert_false(_issue_kinds(combined_result).has("invalid_snapshot"))
	assert_true(_get_dictionary(combined_result, "analysis").is_empty())
	assert_true(_get_dictionary(combined_result, "plan").is_empty())

	var over_limit_payload: Array = []
	for _over_index: int in 700:
		over_limit_payload.append(shared_text)
	var rejected_compilation: Dictionary = worker.run_request({
		"generation": 83,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": true,
		"profile_compilation": { "payload": over_limit_payload },
		"plan_options": {},
	})
	assert_eq(_get_string(rejected_compilation, "status"), "failed")
	assert_eq(
		_issue_kinds(rejected_compilation),
		PackedStringArray(["invalid_profile_compilation"])
	)
	var rejected_snapshot: Dictionary = worker.run_request({
		"generation": 84,
		"snapshot": { "payload": over_limit_payload },
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
	})
	assert_eq(_get_string(rejected_snapshot, "status"), "failed")
	assert_eq(
		_issue_kinds(rejected_snapshot),
		PackedStringArray(["invalid_snapshot"])
	)


func test_project_layout_analyzer_stops_during_evaluation_and_reports_budgets() -> void:
	var snapshot: Dictionary = _make_large_snapshot(512)
	var cancel_probe: CancelAfterChecks = CancelAfterChecks.new()
	cancel_probe.cancel_after = 2
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var cancelled: Dictionary = analyzer.analyze_snapshot_for_framework(
		snapshot,
		{
			"cancel_check": Callable(cancel_probe, "should_cancel"),
			"max_work_units": 2000000,
			"max_findings": 1024,
		}
	)
	assert_true(cancel_probe.call_count >= 2, "取消必须发生在 Analyzer 已处理中，而不是只在入口前。")
	assert_false(_get_bool(cancelled, "evaluation_complete"))
	assert_eq(_get_string(cancelled, "evaluation_status"), "evaluation_cancelled")
	assert_true(_finding_kinds(cancelled).has("evaluation_cancelled"))
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var cancelled_validation: Dictionary = contract.validate_and_index(cancelled)
	assert_true(_get_bool(cancelled_validation, "valid"), "取消结果仍必须满足闭合 analysis contract。")

	var no_cancel_probe: CancelAfterChecks = CancelAfterChecks.new()
	no_cancel_probe.cancel_after = 1_000_000
	var work_limited: Dictionary = analyzer.analyze_snapshot_for_framework(
		snapshot,
		{
			"cancel_check": Callable(no_cancel_probe, "should_cancel"),
			"max_work_units": 10,
			"max_findings": 1024,
		}
	)
	assert_false(_get_bool(work_limited, "evaluation_complete"))
	assert_eq(
		_get_string(work_limited, "evaluation_status"),
		"evaluation_work_budget_exhausted"
	)
	assert_eq(
		_finding_kinds(work_limited).count("evaluation_work_budget_exhausted"),
		1
	)


func test_project_layout_analyzer_runtime_can_only_tighten_absolute_budgets() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var no_cancel_probe: CancelAfterChecks = CancelAfterChecks.new()
	no_cancel_probe.cancel_after = 1000000
	for runtime: Dictionary in [
		{
			"cancel_check": Callable(no_cancel_probe, "should_cancel"),
			"max_work_units": 2_000_001,
			"max_findings": 1_024,
		},
		{
			"cancel_check": Callable(no_cancel_probe, "should_cancel"),
			"max_work_units": 2_000_000,
			"max_findings": 1_025,
		},
	]:
		var rejected: Dictionary = analyzer.analyze_snapshot_for_framework(
			_make_snapshot(),
			runtime
		)
		assert_false(_get_bool(rejected, "evaluation_complete"))
		assert_eq(
			_get_string(rejected, "evaluation_status"),
			"evaluation_runtime_invalid"
		)
		assert_eq(_get_array(rejected, "findings").size(), 1)
		assert_eq(
			_finding_kinds(rejected),
			PackedStringArray(["evaluation_runtime_invalid"])
		)
		assert_true(_get_array(rejected, "rule_results").is_empty())


func test_project_layout_analyzer_reserves_one_terminal_finding_slot() -> void:
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.finding_budget",
		"zones": [],
		"rules": [{
			"id": "naming",
			"kind": "naming_convention",
			"severity": "warning",
			"roots": [],
			"exclude": [],
			"pattern": "^never_matches$",
			"target": "path",
		}],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(profile)
	var no_cancel_probe: CancelAfterChecks = CancelAfterChecks.new()
	no_cancel_probe.cancel_after = 1000000
	var limited: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		compilation,
		_make_snapshot(),
		{
			"cancel_check": Callable(no_cancel_probe, "should_cancel"),
			"max_work_units": 2000000,
			"max_findings": 4,
		}
	)
	assert_eq(_get_array(limited, "findings").size(), 4)
	assert_eq(
		_finding_kinds(limited).count("evaluation_finding_budget_exhausted"),
		1
	)
	assert_eq(
		_get_string(limited, "evaluation_status"),
		"evaluation_finding_budget_exhausted"
	)
	var contract: _ANALYSIS_CONTRACT_SCRIPT = _ANALYSIS_CONTRACT_SCRIPT.new()
	var limited_validation: Dictionary = contract.validate_and_index(limited)
	assert_true(
		_get_bool(limited_validation, "valid"),
		"finding budget 结果仍必须满足闭合 analysis contract。"
	)

	var terminal_only: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		compilation,
		_make_snapshot(),
		{
			"cancel_check": Callable(no_cancel_probe, "should_cancel"),
			"max_work_units": 2000000,
			"max_findings": 1,
		}
	)
	assert_eq(_get_array(terminal_only, "findings").size(), 1)
	assert_eq(
		_finding_kinds(terminal_only),
		PackedStringArray(["evaluation_finding_budget_exhausted"])
	)


func test_project_layout_analyzer_rejects_forged_compilation_without_execution() -> void:
	var profile: Dictionary = {
		"schema_version": 1,
		"id": "test.compilation_boundary",
		"zones": [],
		"rules": [{
			"id": "root_files",
			"kind": "forbid_root_files",
			"severity": "warning",
			"allowed_files": [],
		}, {
			"id": "naming",
			"kind": "naming_convention",
			"severity": "warning",
			"roots": ["src"],
			"exclude": ["**/*.generated.gd"],
			"pattern": "^.*$",
			"target": "path",
		}],
	}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var compilation: Dictionary = analyzer.compile_profile(profile)
	var valid_analysis: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		compilation,
		_make_snapshot()
	)
	assert_true(_get_bool(valid_analysis, "evaluation_complete"))

	var forged_rule: Dictionary = compilation.duplicate(true)
	var forged_profile: Dictionary = _get_dictionary(forged_rule, "profile")
	var forged_rules: Array = _get_array(forged_profile, "rules")
	var first_rule: Dictionary = _get_dictionary_at(forged_rules, 0)
	first_rule["kind"] = "evil"
	var rejected_rule: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_rule,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_rule, "success"))
	assert_true(_finding_kinds(rejected_rule).has("invalid_profile_compilation"))
	assert_true(_get_array(rejected_rule, "rule_results").is_empty())

	var forged_relative_path: Dictionary = compilation.duplicate(true)
	var path_profile: Dictionary = _get_dictionary(forged_relative_path, "profile")
	var path_rules: Array = _get_array(path_profile, "rules")
	var path_rule: Dictionary = _get_dictionary_at(path_rules, 0)
	path_rule["allowed_files"] = ["../outside"]
	var rejected_relative_path: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_relative_path,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_relative_path, "success"))
	assert_true(_finding_kinds(rejected_relative_path).has("invalid_profile_compilation"))

	var forged_glob: Dictionary = compilation.duplicate(true)
	var glob_profile: Dictionary = _get_dictionary(forged_glob, "profile")
	var glob_rules: Array = _get_array(glob_profile, "rules")
	var glob_rule: Dictionary = {}
	for candidate_value: Variant in glob_rules:
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value
		if _get_string(candidate, "id") == "naming":
			glob_rule = candidate
			break
	assert_false(glob_rule.is_empty())
	glob_rule["exclude"] = ["***"]
	var rejected_glob: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_glob,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_glob, "success"))
	assert_true(_finding_kinds(rejected_glob).has("invalid_profile_compilation"))

	var forged_capability: Dictionary = compilation.duplicate(true)
	var capabilities: Dictionary = _get_dictionary(forged_capability, "capabilities")
	capabilities["executor_id"] = "evil"
	var rejected_capability: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_capability,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_capability, "success"))
	assert_true(_finding_kinds(rejected_capability).has("invalid_profile_compilation"))

	var forged_count: Dictionary = compilation.duplicate(true)
	forged_count["error_count"] = 1
	var rejected_count: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_count,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_count, "success"))
	assert_true(_finding_kinds(rejected_count).has("invalid_profile_compilation"))
	assert_true(_get_array(rejected_count, "rule_results").is_empty())

	var forged_top_level: Dictionary = compilation.duplicate(true)
	forged_top_level["unexpected"] = true
	var rejected_top_level: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		forged_top_level,
		_make_snapshot()
	)
	assert_false(_get_bool(rejected_top_level, "success"))
	assert_true(_finding_kinds(rejected_top_level).has("invalid_profile_compilation"))

	var failed_compilation: Dictionary = analyzer.compile_profile({
		"schema_version": 1,
		"zones": [],
		"rules": [],
	})
	assert_false(_get_bool(failed_compilation, "success"))
	var failed_analysis: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		failed_compilation,
		_make_snapshot()
	)
	assert_false(_get_bool(failed_analysis, "success"))
	assert_true(_finding_kinds(failed_analysis).has("missing_profile_id"))
	assert_false(_finding_kinds(failed_analysis).has("invalid_profile_compilation"))
	assert_true(_get_array(failed_analysis, "rule_results").is_empty())


func test_project_layout_analyzer_rejects_unbounded_compilation_before_validation() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var oversized_compilation: Dictionary = {
		"payload": "c".repeat(16385),
	}
	_assert_analysis_admission_terminal(
		analyzer.analyze_compiled_profile_snapshot(
			oversized_compilation,
			_make_snapshot()
		)
	)

	var compilation: Dictionary = analyzer.compile_profile({
		"schema_version": 1,
		"id": "test.cyclic_compilation",
		"zones": [],
		"rules": [],
	})
	var compiled_profile: Dictionary = _get_dictionary(compilation, "profile")
	var cyclic_metadata: Dictionary = {}
	cyclic_metadata["self"] = cyclic_metadata
	compiled_profile["metadata"] = cyclic_metadata
	_assert_analysis_admission_terminal(
		analyzer.analyze_compiled_profile_snapshot(
			compilation,
			_make_snapshot()
		)
	)


func test_project_layout_compiler_success_is_strict_worker_safe_json() -> void:
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER_SCRIPT.new()
	var node_metadata: Node = Node.new()
	var non_string_key_metadata: Dictionary = {}
	non_string_key_metadata[1] = "value"
	var invalid_metadata_values: Array = [
		node_metadata,
		Callable(self, "_read_text"),
		PackedInt32Array([1, 2, 3]),
		non_string_key_metadata,
		{ "vector": Vector2.ONE },
		{ "string_name": StringName("value") },
		{ "object_array": [node_metadata] },
		{ "number": INF },
	]
	for invalid_metadata: Variant in invalid_metadata_values:
		var invalid_profile: Dictionary = {
			"schema_version": 1,
			"id": "test.non_json_metadata",
			"zones": [],
			"rules": [],
			"metadata": invalid_metadata,
		}
		var first_compilation: Dictionary = analyzer.compile_profile(invalid_profile)
		var second_compilation: Dictionary = analyzer.compile_profile(invalid_profile)
		_assert_profile_compile_resource_terminal(first_compilation)
		assert_eq(first_compilation, second_compilation)

	var shared_text: String = "界".repeat(8_000)
	var near_limit_payload: Array = []
	for _near_limit_index: int in 698:
		near_limit_payload.append(shared_text)
	var nested_metadata: Dictionary = { "leaf": "safe" }
	for _nested_depth: int in 40:
		nested_metadata = { "child": nested_metadata }
	var valid_profile: Dictionary = {
		"schema_version": 1,
		"id": "test.json_metadata",
		"zones": [],
		"rules": [],
		"metadata": {
			"enabled": true,
			"threshold": 1.5,
			"labels": ["safe", null, 3],
			"nested": nested_metadata,
			"payload": near_limit_payload,
		},
	}
	var compilation: Dictionary = analyzer.compile_profile(valid_profile)
	assert_true(_get_bool(compilation, "success"))
	var analysis: Dictionary = analyzer.analyze_compiled_profile_snapshot(
		compilation,
		_make_snapshot()
	)
	assert_true(_get_bool(analysis, "success"))
	assert_true(_get_bool(analysis, "evaluation_complete"))
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var worker_result: Dictionary = worker.run_request({
		"generation": 85,
		"snapshot": _make_snapshot(),
		"profile_compilation_present": true,
		"profile_compilation": compilation,
		"plan_options": {},
	})
	assert_eq(_get_string(worker_result, "status"), "complete")
	assert_true(_get_array(worker_result, "issues").is_empty())

	var oversized_payload: Array = []
	for _oversized_index: int in 700:
		oversized_payload.append(shared_text)
	var oversized_profile: Dictionary = valid_profile.duplicate(false)
	oversized_profile["metadata"] = { "payload": oversized_payload }
	_assert_profile_compile_resource_terminal(
		analyzer.compile_profile(oversized_profile)
	)
	node_metadata.free()


func test_project_layout_worker_cancels_a_real_thread_safely() -> void:
	var worker: GFProjectLayoutScanWorker = _WORKER_SCRIPT.new()
	var request: Dictionary = {
		"generation": 21,
		"snapshot": _make_large_snapshot(12000),
		"profile_compilation_present": false,
		"profile_compilation": {},
		"plan_options": {},
	}
	var thread: Thread = Thread.new()
	assert_eq(thread.start(Callable(worker, "run_request").bind(request)), OK)
	OS.delay_msec(1)
	worker.cancel()
	var result_value: Variant = thread.wait_to_finish()
	assert_true(result_value is Dictionary)
	if result_value is Dictionary:
		var result: Dictionary = result_value
		assert_eq(_get_string(result, "status"), "cancelled")


func _make_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_snapshot",
		"root_path": "res://",
		"scope": _make_scope("res://"),
		"complete": true,
		"capture_status": "complete",
		"directories": [
			"features",
			"features/inventory",
			"features/inventory/scripts",
		],
		"files": [
			"project.godot",
			"features/inventory/feature_manifest.json",
			"features/inventory/scripts/inventory_service.gd",
		],
	}


func _make_large_snapshot(entry_count: int) -> Dictionary:
	var directories: Array = []
	var files: Array = []
	for index: int in entry_count:
		var directory_path: String = "entry_%05d" % index
		directories.append(directory_path)
		files.append("%s/item.gd" % directory_path)
	var snapshot: Dictionary = _make_snapshot()
	snapshot["directories"] = directories
	snapshot["files"] = files
	var scope: Dictionary = _get_dictionary(snapshot, "scope")
	scope["max_scanned_files"] = maxi(entry_count, 20000)
	scope["max_scanned_directories"] = maxi(entry_count, 20000)
	return snapshot


func _make_closed_impact_query_result(
	generation: int,
	analysis_digest: String
) -> Dictionary:
	return {
		"schema_version": 1,
		"kind": "project_layout_query_result",
		"generation": generation,
		"analysis_digest": analysis_digest,
		"query_kind": "analyze_change_impact",
		"status": "complete",
		"explanation": {},
		"impact": {
			"schema_version": 1,
			"kind": "project_layout_impact",
			"complete": true,
			"status": "unknown",
			"source_analysis_digest": analysis_digest,
			"change": {
				"kind": "delete",
				"source_path": ".",
				"target_path": "",
			},
			"affected_node_ids": ["path:."],
			"blockers": [{
				"kind": "dependency_coverage_incomplete",
				"path": "",
				"message": "fixture",
			}],
			"evidence_ids": [],
			"issues": [],
			"effects": { "writes_project": false },
		},
		"issues": [],
	}


func _make_scope(root_path: String) -> Dictionary:
	return {
		"kind": "project_source",
		"root_path": root_path,
		"include_hidden": true,
		"excluded_prefixes": [".git", ".godot", ".import"],
		"max_scanned_files": 20000,
		"max_scanned_directories": 20000,
		"max_scan_depth": 32,
	}


func _assert_analysis_admission_terminal(analysis: Dictionary) -> void:
	assert_false(_get_bool(analysis, "success"))
	assert_false(_get_bool(analysis, "input_complete"))
	assert_false(_get_bool(analysis, "evaluation_complete"))
	assert_eq(_get_string(analysis, "root_path"), "res://")
	assert_eq(_get_string(analysis, "profile_id"), "")
	assert_true(_get_string(analysis, "input_digest").length() <= 64)
	assert_true(_get_array(analysis, "rule_results").is_empty())
	assert_eq(_get_array(analysis, "findings").size(), 1)
	assert_eq(
		_finding_kinds(analysis),
		PackedStringArray(["analysis_input_resource_limit_exceeded"])
	)


func _assert_profile_compile_resource_terminal(compilation: Dictionary) -> void:
	assert_false(_get_bool(compilation, "success"))
	assert_true(_get_dictionary(compilation, "profile").is_empty())
	assert_true(_get_dictionary(compilation, "capabilities").is_empty())
	assert_eq(_get_string(compilation, "contract_id"), "")
	assert_eq(_get_int(compilation, "error_count"), 1)
	assert_eq(_get_int(compilation, "warning_count"), 0)
	assert_eq(_get_array(compilation, "issues").size(), 1)
	assert_eq(
		_issue_kinds(compilation),
		PackedStringArray(["profile_compile_resource_limit_exceeded"])
	)


func _blocker_kinds(report: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for blocker_value: Variant in _get_array(report, "blockers"):
		if blocker_value is Dictionary:
			var blocker: Dictionary = blocker_value
			var blocker_kind: String = _get_string(blocker, "kind")
			if not blocker_kind.is_empty():
				var _append_kind: bool = result.append(blocker_kind)
	return result


func _finding_by_kind(report: Dictionary, finding_kind: String) -> Dictionary:
	for finding_value: Variant in _get_array(report, "findings"):
		if finding_value is Dictionary:
			var finding: Dictionary = finding_value
			if _get_string(finding, "kind") == finding_kind:
				return finding
	return {}


func _finding_kinds(report: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for finding_value: Variant in _get_array(report, "findings"):
		if finding_value is Dictionary:
			var finding: Dictionary = finding_value
			var finding_kind: String = _get_string(finding, "kind")
			if not finding_kind.is_empty():
				var _append_kind: bool = result.append(finding_kind)
	return result


func _issue_kinds(report: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for issue_value: Variant in _get_array(report, "issues"):
		if issue_value is Dictionary:
			var issue: Dictionary = issue_value
			var issue_kind: String = _get_string(issue, "kind")
			if not issue_kind.is_empty():
				var _append_kind: bool = result.append(issue_kind)
	return result


func _string_array(values: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		if value is String:
			var text: String = value
			var _append_text: bool = result.append(text)
	return result


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _write_text(path: String, content: String) -> void:
	var create_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(path.get_base_dir())
	)
	assert_eq(create_error, OK)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	var _store_result: bool = file.store_string(content)


func _remove_directory_tree(root_path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		var _remove_file_error: Error = DirAccess.remove_absolute(
			absolute_path.path_join(file_name)
		)
	for directory_name: String in directory.get_directories():
		_remove_directory_tree(root_path.path_join(directory_name))
	var _remove_directory_error: Error = DirAccess.remove_absolute(absolute_path)


func _assert_bool_call_result(value: Variant, expected: bool) -> void:
	assert_true(value is bool)
	if value is bool:
		var actual: bool = value
		assert_eq(actual, expected)


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	var value: Variant = source.get(key, default_value)
	return value if value is bool else default_value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value


func _get_array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _get_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


func _get_dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	return value if value is Dictionary else {}


func _sorted_dictionary_keys(source: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_value: Variant in source.keys():
		if not key_value is String:
			continue
		var key: String = key_value
		var _append_key: bool = result.append(key)
	result.sort()
	return result


func _is_lower_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character_index: int in value.length():
		var codepoint: int = value.unicode_at(character_index)
		if (
			(codepoint < 48 or codepoint > 57)
			and (codepoint < 97 or codepoint > 102)
		):
			return false
	return true


func _is_strict_data_only(value: Variant) -> bool:
	var pending_values: Array = [value]
	var visited_count: int = 0
	while not pending_values.is_empty():
		visited_count += 1
		if visited_count > 500_000:
			return false
		var current_value: Variant = pending_values.pop_back()
		if (
			current_value == null
			or current_value is bool
			or current_value is int
			or current_value is String
		):
			continue
		if current_value is float:
			var float_value: float = current_value
			if not is_finite(float_value):
				return false
			continue
		if current_value is PackedStringArray:
			continue
		if current_value is Array:
			var array_value: Array = current_value
			for item: Variant in array_value:
				pending_values.append(item)
			continue
		if current_value is Dictionary:
			var dictionary_value: Dictionary = current_value
			for key_value: Variant in dictionary_value.keys():
				if not key_value is String:
					return false
				pending_values.append(dictionary_value[key_value])
			continue
		return false
	return true


# --- 内部测试类 ---

class FakeCancelledWorker extends RefCounted:
	var cancel_count: int = 0


	func run_request(request: Dictionary) -> Dictionary:
		return {
			"schema_version": 1,
			"kind": "project_layout_worker_result",
			"generation": request.get("generation", -1),
			"status": "cancelled",
			"analysis": {},
			"plan": {},
			"issues": [],
		}


	func run_query_request(request: Dictionary) -> Dictionary:
		return {
			"schema_version": 1,
			"kind": "project_layout_query_result",
			"generation": request.get("generation", -1),
			"analysis_digest": request.get("analysis_digest", ""),
			"query_kind": request.get("query_kind", ""),
			"status": "cancelled",
			"explanation": {},
			"impact": {},
			"issues": [],
		}


	func cancel() -> void:
		cancel_count += 1


class FakeCompletedWorker extends RefCounted:
	var result: Dictionary = {}


	func run_request(_request: Dictionary) -> Dictionary:
		return result.duplicate(true)


	func cancel() -> void:
		pass


class FakeControllableThread extends RefCounted:
	var alive: bool = true
	var wait_called: bool = false
	var work_callable: Callable = Callable()


	func start(callable_value: Callable) -> Error:
		work_callable = callable_value
		return OK


	func is_alive() -> bool:
		return alive


	func wait_to_finish() -> Variant:
		wait_called = true
		alive = false
		return work_callable.call() if work_callable.is_valid() else null


class CancelAfterChecks extends RefCounted:
	var cancel_after: int = 1
	var call_count: int = 0


	func should_cancel() -> bool:
		call_count += 1
		return call_count >= cancel_after


class WeightedQueryCheckpoint extends RefCounted:
	var stop_after_work_units: int = 1
	var total_work_units: int = 0
	var call_count: int = 0


	func consume(work_units: int) -> bool:
		call_count += 1
		total_work_units += work_units
		return total_work_units < stop_after_work_units


class LinkSwapSnapshotBuilder extends _SNAPSHOT_BUILDER_SCRIPT:
	var reject_on_probe_call: int = -1
	var probed_paths: PackedStringArray = PackedStringArray()


	func _path_crosses_link(path: String) -> bool:
		var _append_path: bool = probed_paths.append(path)
		return probed_paths.size() == reject_on_probe_call


class LinkSwapAnalyzer extends _ANALYZER_SCRIPT:
	var reject_on_probe_call: int = -1
	var probed_paths: PackedStringArray = PackedStringArray()


	func _path_crosses_link(path: String) -> bool:
		var _append_path: bool = probed_paths.append(path)
		return probed_paths.size() == reject_on_probe_call


class OversizedJoinAnalyzer extends _ANALYZER_SCRIPT:
	func _join_relative_path(_base_path: String, _entry_name: String) -> String:
		return "p".repeat(16380)


class InvalidJoinAnalyzer extends _ANALYZER_SCRIPT:
	func _join_relative_path(_base_path: String, _entry_name: String) -> String:
		return "../outside"


class ChildDirectoryProbeAnalyzer extends _ANALYZER_SCRIPT:
	func collect_direct_children(
		scan: Dictionary,
		root: String
	) -> PackedStringArray:
		return _get_direct_child_directories(scan, root, {})


	func collect_allowed_subdirs(scan: Dictionary) -> PackedStringArray:
		return _feature_allowed_subdirs_for_root(
			scan,
			"features",
			PackedStringArray(),
			{}
		)
