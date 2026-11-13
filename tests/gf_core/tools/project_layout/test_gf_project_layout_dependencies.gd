@tool
extends GutTest


const DEPENDENCIES_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_dependencies.gd")
const CAPTURE_SCRIPT = preload("res://addons/gf/tools/project_layout/editor/gf_project_layout_dependency_capture.gd")
const BUILDER_SCRIPT = preload("res://addons/gf/tools/project_layout/editor/gf_project_layout_editor_snapshot_builder.gd")
const CONTRACT_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd")
const SCOPE_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_capture_scope.gd")
const SESSION_SCRIPT = preload("res://addons/gf/tools/project_layout/gf_project_layout_session.gd")
var _paths: PackedStringArray = []
var _roots: PackedStringArray = []


func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for root: String in _roots:
		var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(root))
	_paths.clear()
	_roots.clear()


func test_static_closure_cycles_ownership_and_declared_source_budgets() -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["dependencies"] = _make_dependency_input(snapshot)
	var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	assert_true(
		GFVariantData.get_option_bool(report, "success"),
		str(report.get("issues"))
	)
	var dependency: Dictionary = _dependency(report)
	assert_eq(
		GFVariantData.get_option_array(dependency, "startup_files"),
		["boot.tscn", "items.tres"]
	)
	assert_eq(
		GFVariantData.get_option_int(dependency, "startup_source_bytes"),
		20
	)
	assert_eq(
		GFVariantData.get_option_array(dependency, "unreachable_files"),
		["unused.bin"]
	)
	assert_eq(
		GFVariantData.get_option_array(dependency, "cycles").size(),
		1
	)
	assert_eq(
		GFVariantData.get_option_array(dependency, "duplicate_owners").size(),
		1
	)
	assert_eq(
		GFVariantData.get_option_array(dependency, "cross_owner_edges").size(),
		2
	)
	assert_true(_has_issue(dependency, "startup_source_budget_exceeded"))
	assert_true(_has_issue(dependency, "owner_source_budget_exceeded"))
	assert_eq(
		GFVariantData.get_option_string(dependency, "coverage"),
		"partial"
	)
	var validation: Dictionary = CONTRACT_SCRIPT.new().validate_and_index(report)
	assert_true(
		GFVariantData.get_option_bool(validation, "valid"),
		str(validation)
	)


func test_impact_follows_reverse_edges_but_never_claims_dynamic_coverage() -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["dependencies"] = _make_dependency_input(snapshot)
	var analyzer: GFProjectLayoutAnalyzer = GFProjectLayoutAnalyzer.new()
	var report: Dictionary = analyzer.analyze_snapshot(snapshot)
	var impact: Dictionary = analyzer.analyze_change_impact(
		report,
		{ "kind": "delete", "source_path": "items.tres" }
	)
	assert_eq(
		GFVariantData.get_option_string(impact, "status"),
		"unsafe",
		str(impact)
	)
	assert_true(GFVariantData.get_option_array(impact, "affected_node_ids").has("path:boot.tscn"))
	var is_dependency: Callable = func(id: String) -> bool:
		return id.begins_with("dependency:")
	assert_true(GFVariantData.get_option_array(impact, "evidence_ids").any(is_dependency))
	var unrelated: Dictionary = analyzer.analyze_change_impact(
		report,
		{ "kind": "delete", "source_path": "unused.bin" }
	)
	assert_eq(
		GFVariantData.get_option_string(unrelated, "status"),
		"unknown",
		str(unrelated)
	)


func test_forged_summary_and_stale_scope_digest_are_rejected() -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["dependencies"] = _make_dependency_input(snapshot)
	var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	var dependency: Dictionary = report["graph"]["dependencies"]
	dependency["startup_files"] = []
	assert_false(
		GFVariantData.get_option_bool(
			CONTRACT_SCRIPT.new().validate_and_index(report),
			"valid"
		)
	)
	snapshot["files"] = ["boot.tscn", "items.tres"]
	assert_false(
		GFVariantData.get_option_bool(
			GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot),
			"success"
		)
	)


func test_dependency_receipt_cannot_relabel_a_plain_path_as_another_target() -> void:
	var snapshot: Dictionary = _snapshot()
	var input: Dictionary = _make_dependency_input(snapshot)
	var capture: Dictionary = input["capture"]
	var edge: Dictionary = capture["files"][0]["dependencies"][0]
	edge["target"] = "res://unused.bin"
	var _removed: bool = capture.erase("digest")
	input["capture"] = DEPENDENCIES_SCRIPT.seal_capture(capture)
	snapshot["dependencies"] = input
	assert_false(
		GFVariantData.get_option_bool(
			GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot),
			"success"
		)
	)


func test_missing_targets_and_partial_capture_keep_closure_incomplete() -> void:
	var snapshot: Dictionary = _snapshot()
	var input: Dictionary = _make_dependency_input(snapshot)
	var declaration: Dictionary = input["declaration"]
	declaration["edges"] = [
		{ "from": "boot.tscn", "to": "missing.tres" },
	]
	var capture: Dictionary = input["capture"]
	var _removed: bool = capture.erase("digest")
	capture["status"] = "partial"
	input["capture"] = DEPENDENCIES_SCRIPT.seal_capture(capture)
	snapshot["dependencies"] = input
	var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	assert_true(GFVariantData.get_option_bool(report, "success"))
	var dependency: Dictionary = _dependency(report)
	assert_false(GFVariantData.get_option_bool(dependency, "startup_complete"))
	assert_true(_has_issue(dependency, "dependency_target_unobserved"))
	assert_true(_has_issue(dependency, "startup_path_unobserved"))


func test_runtime_observation_and_declared_edges_preserve_their_provenance() -> void:
	var snapshot: Dictionary = _snapshot()
	var input: Dictionary = {
		"capture": {},
		"declaration": {
			"startup_roots": ["boot.tscn"],
			"edges": [
				{ "from": "boot.tscn", "to": "items.tres" },
			],
		},
		"observations": [
			{
				"from": "items.tres",
				"to": "unused.bin",
				"sample_id": "load-session-1",
				"config_digest": "a".repeat(64),
				"observed_at_msec": 123,
			},
		],
	}
	snapshot["dependencies"] = input
	var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	var dependency: Dictionary = _dependency(report)
	var edges: Array = dependency["edges"]
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(edges[0]),
			"kind"
		),
		"project_declared_dependency"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(edges[1]),
			"kind"
		),
		"runtime_dependency_observation"
	)
	assert_false(GFVariantData.get_option_bool(dependency, "startup_complete"))
	input["observations"] = [
		{
			"from": "items.tres",
			"to": "unused.bin",
			"sample_id": "session",
		},
	]
	assert_false(
		GFVariantData.get_option_bool(
			GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot),
			"success"
		)
	)


func test_profile_dependency_policy_is_compiled_and_applies_without_editor_capture() -> void:
	var analyzer: GFProjectLayoutAnalyzer = GFProjectLayoutAnalyzer.new()
	var profile: Dictionary = {
		"schema_version": 2,
		"id": "dependency-test",
		"zones": [],
		"rules": [],
		"dependency_policy": {
			"startup_roots": ["boot.tscn"],
			"max_startup_files": 0.0,
		},
	}
	var report: Dictionary = analyzer.analyze_profile_snapshot(
		profile,
		_snapshot()
	)
	assert_true(
		GFVariantData.get_option_bool(report, "success"),
		str(report.get("issues"))
	)
	assert_true(
		_has_issue(
			_dependency(report),
			"startup_file_budget_exceeded"
		)
	)
	profile["dependency_policy"] = {
		"startup_roots": ["../escape"],
	}
	assert_false(
		GFVariantData.get_option_bool(
			analyzer.compile_profile(profile),
			"success"
		)
	)


func test_json_snapshot_session_has_same_analysis_and_rejects_ambiguous_numbers() -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["dependencies"] = _make_dependency_input(snapshot)
	var direct: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	var session: GFProjectLayoutSession = SESSION_SCRIPT.new()
	var transported: Dictionary = session.open_snapshot_text(
		JSON.stringify(
			snapshot,
			"",
			true,
			true
		)
	)
	assert_eq(transported, direct)
	assert_eq(
		session.get_analysis(),
		direct
	)
	assert_false(
		GFVariantData.get_option_bool(
			session.open_snapshot_text("{\"schema_version\":2.1}"),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			session.open_snapshot_text("{\"schema_version\":2,\"schema_version\":2}"),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			session.open_snapshot_text("{\"schema_version\":9007199254740992}"),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			session.open_snapshot_text("{\"schema_version\":2.00000000000000000001}"),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			session.open_snapshot_text("{\"schema_version\":2e0}"),
			"success"
		)
	)


func test_dependency_work_cancellation_publishes_no_partial_summary() -> void:
	var snapshot: Dictionary = _snapshot()
	var scope: Dictionary = snapshot["scope"]
	var files: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "files")
	var stopped: Callable = func() -> bool:
		return false
	assert_true(
		DEPENDENCIES_SCRIPT.analyze(
			_make_dependency_input(snapshot),
			DEPENDENCIES_SCRIPT.inventory_key(scope, files),
			"res://",
			files,
			stopped
		).is_empty()
	)


func test_uid_precedence_fallback_and_invalid_dependency_records() -> void:
	var id: int = ResourceUID.create_id()
	var text: String = ResourceUID.id_to_text(id)
	var raw: String = text + "::::res://fallback.tres"
	assert_eq(
		GFVariantData.get_option_string(
			CAPTURE_SCRIPT.decode_dependency(raw),
			"resolution"
		),
		"fallback"
	)
	ResourceUID.add_id(id, "res://resolved.tres")
	assert_eq(
		GFVariantData.get_option_string(
			CAPTURE_SCRIPT.decode_dependency(raw),
			"target"
		),
		"res://resolved.tres"
	)
	ResourceUID.remove_id(id)
	assert_eq(
		GFVariantData.get_option_string(
			CAPTURE_SCRIPT.decode_dependency("res://../escape.tres"),
			"resolution"
		),
		"unresolved"
	)
	assert_eq(
		GFVariantData.get_option_string(
			CAPTURE_SCRIPT.decode_dependency("uid://a::Resource::res://fallback.tres"),
			"resolution"
		),
		"unresolved"
	)


func test_editor_capture_reads_resource_dependencies_without_loading_and_obeys_budget() -> void:
	var root: String = _make_files()
	var builder: GFProjectLayoutEditorSnapshotBuilder = BUILDER_SCRIPT.new()
	assert_eq(
		builder.begin(
			root,
			{ "source_root": root, "capture_dependencies": true }
		),
		OK
	)
	for _index: int in range(100):
		var _progress: Dictionary = builder.step(2)
		if builder.is_finished():
			break
	var snapshot: Dictionary = builder.make_snapshot()
	assert_false(snapshot.is_empty())
	assert_false(ResourceLoader.has_cached(root.path_join("boot.tscn")))
	assert_false(ResourceLoader.has_cached(root.path_join("items.tres")))
	var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
	assert_true(
		GFVariantData.get_option_bool(report, "success"),
		str(report.get("issues"))
	)
	assert_eq(
		GFVariantData.get_option_array(
			_dependency(report),
			"edges"
		).size(),
		1
	)
	var capture: CAPTURE_SCRIPT = CAPTURE_SCRIPT.new()
	assert_true(
		capture.begin(
			snapshot,
			{ "max_files": 1 }
		)
	)
	for _index: int in range(20):
		if capture.step(1):
			break
	assert_eq(
		GFVariantData.get_option_string(
			capture.get_capture(),
			"status"
		),
		"partial"
	)
	assert_eq(
		GFVariantData.get_option_array(
			capture.get_capture(),
			"files"
		).size(),
		1
	)


func test_mutated_source_during_capture_is_stale_and_static_edges_are_not_used() -> void:
	var root: String = _make_files()
	var snapshot: Dictionary = _snapshot(root)
	var capture: CAPTURE_SCRIPT = CAPTURE_SCRIPT.new()
	assert_true(capture.begin(snapshot))
	assert_false(capture.step(1))
	_write(
		root.path_join("boot.tscn"),
		"[gd_scene format=3]\n[node name=\"Changed\" type=\"Node\"]\n"
	)
	for _index: int in range(20):
		if capture.step(1):
			break
	assert_eq(
		GFVariantData.get_option_string(
			capture.get_capture(),
			"status"
		),
		"stale"
	)
	snapshot["dependencies"] = {
		"capture": capture.get_capture(),
		"declaration": {
			"startup_roots": ["boot.tscn"],
		},
		"observations": [],
	}
	var dependency: Dictionary = _dependency(GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot))
	assert_true(GFVariantData.get_option_array(dependency, "edges").is_empty())
	assert_false(GFVariantData.get_option_bool(dependency, "startup_complete"))


func test_capture_wire_values_reject_string_name_aliases() -> void:
	for field: String in [
		"kind",
		"inventory_digest",
		"status",
		"digest",
		"method",
		"root_path",
		"path",
		"resolution",
	]:
		var snapshot: Dictionary = _snapshot()
		var input: Dictionary = _make_dependency_input(snapshot)
		var capture: Dictionary = input["capture"]
		if field in ["method", "root_path"]:
			var provenance: Dictionary = capture["provenance"]
			var source_text: String = provenance[field]
			provenance[field] = StringName(source_text)
		elif field == "path":
			var file_entry: Dictionary = capture["files"][0]
			var path_text: String = file_entry[field]
			file_entry[field] = StringName(path_text)
		elif field == "resolution":
			capture["files"][0]["dependencies"][0][field] = &"path"
		else:
			capture[field] = StringName(GFVariantData.get_option_string(capture, field))
		if field != "digest":
			var _removed: bool = capture.erase("digest")
			input["capture"] = DEPENDENCIES_SCRIPT.seal_capture(capture)
		snapshot["dependencies"] = input
		var report: Dictionary = GFProjectLayoutAnalyzer.new().analyze_snapshot(snapshot)
		assert_false(
			GFVariantData.get_option_bool(report, "success"),
			field
		)


func test_frozen_resource_paths_replay_against_captured_source_root() -> void:
	for logical_root: String in ["res://", "res://content"]:
		var foreign_root: String = ProjectSettings.globalize_path("user://foreign_layout_project").replace("\\", "/")
		var physical: String = foreign_root if logical_root == "res://" else foreign_root.path_join("content")
		var prepared: Dictionary = SCOPE_SCRIPT.prepare(
			{},
			physical,
			{ "source_root": foreign_root, "profile_source_path": physical.path_join("profile.json"), }
		)
		assert_true(GFVariantData.get_option_bool(prepared, "success"))
		var binding: Dictionary = prepared["binding"]
		binding["root_path"] = logical_root
		binding["profile_source_path"] = logical_root.path_join("profile.json")
		var _removed: bool = binding.erase("policy_digest")
		binding["policy_digest"] = JSON.stringify(binding).sha256_text()
		assert_true(SCOPE_SCRIPT.binding_is_valid(binding))
		assert_false(
			GFVariantData.get_option_bool(
				SCOPE_SCRIPT.capture_root_states(binding),
				"success"
			)
		)
		var snapshot: Dictionary = _snapshot()
		snapshot["root_path"] = logical_root
		var scope: Dictionary = snapshot["scope"]
		scope.merge(binding, true)
		var session: GFProjectLayoutSession = SESSION_SCRIPT.new()
		var result: Dictionary = session.open_snapshot_text(JSON.stringify(snapshot))
		assert_true(
			GFVariantData.get_option_bool(result, "success"),
			str(result)
		)


func test_absolute_capture_subroot_keeps_resource_profile_source_replayable() -> void:
	var resource_root: String = "res://tests/gf_core/tools/project_layout/fixtures"
	var profile_path: String = resource_root.path_join("profile_conformance_v2.json")
	var capture_root: String = ProjectSettings.globalize_path(resource_root).replace("\\", "/")
	var builder: GFProjectLayoutEditorSnapshotBuilder = BUILDER_SCRIPT.new()
	var error: Error = builder.begin(
		capture_root,
		{ "source_root": "res://", "profile_source_path": profile_path }
	)
	assert_eq(error, OK)
	if error != OK:
		return
	for _index: int in range(100):
		var _progress: Dictionary = builder.step(64)
		if builder.is_finished():
			break
	var snapshot: Dictionary = builder.make_snapshot()
	assert_false(snapshot.is_empty())
	var scope: Dictionary = GFVariantData.get_option_dictionary(snapshot, "scope")
	assert_has(
		GFVariantData.get_option_array(scope, "protected_roots"),
		"profile_conformance_v2.json"
	)
	var session: GFProjectLayoutSession = SESSION_SCRIPT.new()
	var result: Dictionary = session.open_snapshot_text(JSON.stringify(snapshot))
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)


func _snapshot(root: String = "res://") -> Dictionary:
	var prepared: Dictionary = SCOPE_SCRIPT.prepare(
		{},
		root,
		{ "source_root": root }
	)
	var scope: Dictionary = GFVariantData.get_option_dictionary(prepared, "binding")
	scope.merge(
		{
			"kind": "project_source",
			"include_hidden": true,
			"max_scanned_files": 20000,
			"max_scanned_directories": 20000,
			"max_scan_depth": 32,
		}
	)
	return {
		"schema_version": 2,
		"kind": "project_layout_snapshot",
		"root_path": root,
		"scope": scope,
		"complete": true,
		"capture_status": "complete",
		"directories": [],
		"files": [
			"boot.tscn",
			"items.tres",
			"unused.bin",
		],
	}


func _make_dependency_input(snapshot: Dictionary) -> Dictionary:
	var scope: Dictionary = snapshot["scope"]
	var files: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "files")
	var capture: Dictionary = {
		"schema_version": 1,
		"kind": "resource_dependency_capture",
		"inventory_digest": DEPENDENCIES_SCRIPT.inventory_key(scope, files),
		"status": "captured",
		"provenance": {
			"method": "ResourceLoader.get_dependencies",
			"engine_version": "fixture",
			"root_path": "res://",
		},
		"files": [],
		"issues": [],
	}
	var entries: Array = capture["files"]
	for path: String in files:
		var edges: Array = []
		if path == "boot.tscn":
			edges.append(CAPTURE_SCRIPT.decode_dependency("res://items.tres"))
		elif path == "items.tres":
			edges.append(CAPTURE_SCRIPT.decode_dependency("res://boot.tscn"))
		entries.append(
			{
				"path": path,
				"sha256": "a".repeat(64),
				"bytes": 10,
				"dependencies": edges,
			}
		)
	return {
		"capture": DEPENDENCIES_SCRIPT.seal_capture(capture),
		"declaration": {
			"startup_roots": ["boot.tscn"],
			"max_startup_source_bytes": 19,
			"owners": [
				{
					"id": "bootstrap",
					"roots": ["boot.tscn"],
					"max_source_bytes": 9,
				},
				{
					"id": "content",
					"roots": ["items.tres"],
					"max_source_bytes": -1,
				},
				{
					"id": "shared",
					"roots": ["items.tres"],
					"max_source_bytes": -1,
				},
			],
		},
		"observations": [],
	}


func _dependency(report: Dictionary) -> Dictionary:
	var graph: Dictionary = GFVariantData.get_option_dictionary(report, "graph")
	return GFVariantData.get_option_dictionary(graph, "dependencies")


func _has_issue(report: Dictionary, kind: String) -> bool:
	for issue: Dictionary in GFVariantData.get_option_array(report, "issues"):
		if issue.get("kind") == kind:
			return true
	return false


func _make_files() -> String:
	var root: String = "res://build/gf_project_layout_tests/dependencies_%d" % Time.get_ticks_usec()
	assert_eq(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)),
		OK
	)
	var _appended: bool = _roots.append(root)
	_write(
		root.path_join("boot.tscn"),
		"[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Resource\" path=\"%s/items.tres\" id=\"1\"]\n[node name=\"Root\" type=\"Node\"]\nmetadata/item = ExtResource(\"1\")\n" % root
	)
	_write(
		root.path_join("items.tres"),
		"[gd_resource type=\"Resource\" format=3]\n[resource]\n"
	)
	_write(
		root.path_join("unused.bin"),
		"unused"
	)
	return root


func _write(path: String, text: String) -> void:
	if not _paths.has(path):
		var _appended: bool = _paths.append(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		assert_true(file.store_string(text))
		file.close()
