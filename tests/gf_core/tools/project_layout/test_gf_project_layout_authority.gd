@tool
extends GutTest

const _ANALYZER = preload("res://addons/gf/tools/project_layout/gf_project_layout_analyzer.gd")
const _SESSION = preload("res://addons/gf/tools/project_layout/gf_project_layout_session.gd")
const _READER = preload("res://addons/gf/tools/project_layout/gf_project_layout_profile_reader.gd")
const _SCOPE = preload("res://addons/gf/tools/project_layout/gf_project_layout_capture_scope.gd")
const _BUILDER = preload("res://addons/gf/tools/project_layout/editor/gf_project_layout_editor_snapshot_builder.gd")
const _CONTRACT = preload("res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd")

var _roots: Array[String] = []


class CountingAnalyzer extends GFProjectLayoutAnalyzer:
	var compile_calls: int = 0
	var capture_calls: int = 0

	func compile_profile(profile: Dictionary) -> Dictionary:
		compile_calls += 1
		return super.compile_profile(profile)

	func _scan_project(root_path: String, options: Dictionary, report: Dictionary) -> Dictionary:
		capture_calls += 1
		return super._scan_project(root_path, options, report)


class CountingSession extends GFProjectLayoutSession:
	var analyzer: CountingAnalyzer = CountingAnalyzer.new()

	func _make_analyzer() -> GFProjectLayoutAnalyzer:
		return analyzer


class ExcludedFileAfterBeginBuilder extends GFProjectLayoutEditorSnapshotBuilder:
	var excluded_path: String = ""
	var mutation_error: Error = FAILED

	func begin(root_path: String = "res://", options: Dictionary = {}) -> Error:
		var begin_error: Error = super.begin(root_path, options)
		if begin_error != OK:
			return begin_error
		var file: FileAccess = FileAccess.open(excluded_path, FileAccess.WRITE)
		if file == null:
			mutation_error = FileAccess.get_open_error()
		else:
			mutation_error = OK if file.store_string("excluded root became a file") else ERR_FILE_CANT_WRITE
			file.close()
		return begin_error


func after_each() -> void:
	for root: String in _roots:
		_remove_tree(root)
	_roots.clear()


func test_all_nine_rules_and_optional_zone_filters_execute_in_one_authority() -> void:
	var root: String = _make_root("nine_rules")
	for path: String in ["project.godot", "readme.md", "src/main.GD", "src/notes.md", "src/generated/cache.json", "outside/rogue.gd", "features/ui/other/report.gd", "generated/cache.json"]:
		_write(root.path_join(path), "")
	var profile: Dictionary = _profile()
	profile["zones"] = [{"id": "optional", "roots": ["src"], "required": false, "allow_extensions": ["gd"], "deny_extensions": ["MD"], "exclude": ["src/generated/**"], "severity": "warning"}]
	profile["rules"] = [
		{"id": "exists", "kind": "path_exists", "paths": ["src/main.GD", "src/missing.gd"], "any": true},
		{"id": "roots", "kind": "files_under_roots", "roots": ["src"], "include": ["src/**", "outside/**"], "exclude": ["src/generated/**"], "extensions": ["GD"], "severity": "warning"},
		{"id": "allow", "kind": "extension_allowlist", "roots": ["src"], "exclude": ["src/generated/**"], "extensions": ["gd"], "severity": "warning"},
		{"id": "deny", "kind": "extension_denylist", "roots": ["src"], "extensions": ["md"], "severity": "warning"},
		{"id": "root_files", "kind": "forbid_root_files", "allowed_files": ["project.godot"]},
		{"id": "names", "kind": "naming_convention", "roots": ["src"], "pattern": "^[a-z0-9_./-]+$", "target": "path"},
		{"id": "features", "kind": "feature_module_contract", "roots": ["features"], "required_subdirs": ["scripts"], "allowed_subdirs": ["scripts"], "severity": "warning"},
		{"id": "generated", "kind": "generated_boundary", "include": ["generated/**/*.json"], "roots": ["generated"]},
		{"id": "buckets", "kind": "bucket_size", "roots": ["src"], "max_files": 1},
	]
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER.new()
	var report: Dictionary = analyzer.analyze_profile(profile, {"root_path": root})
	assert_true(_bool(report, "input_complete"))
	assert_true(_bool(report, "evaluation_complete"))
	assert_eq(_array(report, "rule_results").size(), 9)
	assert_eq(_array(_dictionary(report, "capabilities"), "rule_kinds").size(), 9)
	assert_eq(_array(_dictionary(report, "capabilities"), "zone_fields"), ["allow_extensions", "deny_extensions", "exclude", "required", "roots", "severity"])
	for kind: String in ["file_outside_roots", "extension_not_allowed", "extension_denied", "zone_extension_not_allowed", "zone_extension_denied", "forbidden_root_file", "path_naming_mismatch", "unsupported_feature_subdir", "missing_feature_subdir", "bucket_size_exceeded"]:
		assert_true(_has_issue(report, kind), "规则必须真正产生可观察结果：%s" % kind)
	assert_false(_issue_at(report, "zone_extension_not_allowed", "src/generated/cache.json"))
	assert_false(_has_issue(report, "any_path_missing"))
	var contract: _CONTRACT = _CONTRACT.new()
	assert_true(_bool(contract.validate_and_index(report), "valid"))


func test_declared_exclusions_are_applied_before_count_depth_and_match_editor_capture() -> void:
	var root: String = _make_root("scope")
	_write(root.path_join("src/main.gd"), "")
	_write(root.path_join(".state/notes.md"), "")
	_write(root.path_join("evidence/deep/more/cache.bin"), "")
	var profile: Dictionary = _profile()
	profile["capture_scope"] = _declaration(["src"], [{"path": "evidence", "kind": "generated_evidence"}])
	profile["rules"] = [{"id": "sources", "kind": "bucket_size", "roots": ["src"], "max_files": 1}]
	var options: Dictionary = {"source_root": root, "root_path": root, "max_scanned_files": 2, "max_scanned_directories": 2, "max_scan_depth": 1}
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER.new()
	var direct: Dictionary = analyzer.analyze_profile(profile, options)
	assert_true(_bool(direct, "input_complete"))
	assert_eq(_int(direct, "file_count"), 2)
	assert_eq(_int(direct, "directory_count"), 2)
	var rule: Dictionary = _array(direct, "rule_results")[0]
	assert_eq(_string(rule, "evaluation_status"), "scope_limited")
	assert_eq(_dictionary(rule, "coverage"), {"scope": "declared_included", "excluded_roots": ["evidence"]})
	var contract: _CONTRACT = _CONTRACT.new()
	assert_true(_bool(contract.validate_and_index(direct), "valid"))
	for changed_field: String in ["coverage", "evaluation_status"]:
		var forged: Dictionary = direct.duplicate(true)
		var forged_rule: Dictionary = _array(forged, "rule_results")[0]
		if changed_field == "coverage":
			forged_rule[changed_field] = {"scope": "declared_included", "excluded_roots": []}
		else:
			forged_rule[changed_field] = "complete"
		assert_false(_bool(contract.validate_and_index(forged), "valid"))
	var compilation: Dictionary = analyzer.compile_profile(profile)
	var prepared: Dictionary = _SCOPE.prepare(_dictionary(compilation, "profile"), root, options)
	assert_true(_bool(prepared, "success"))
	var builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
	assert_eq(builder.begin_prepared(root, _dictionary(prepared, "binding"), {"max_scanned_files": 2, "max_scanned_directories": 2, "max_scan_depth": 1}), OK)
	for _iteration: int in range(32):
		if builder.step(8)["status"] != "capturing":
			break
	var snapshot: Dictionary = builder.make_snapshot()
	assert_true(_bool(snapshot, "complete"))
	var frozen: Dictionary = analyzer.analyze_compiled_profile_snapshot(compilation, snapshot)
	assert_true(_bool(frozen, "input_complete"))
	assert_eq(_string(frozen, "input_digest"), _string(direct, "input_digest"))
	assert_eq(_array(frozen, "rule_results"), _array(direct, "rule_results"))


func test_hard_protection_rejects_parent_child_alias_and_profile_exclusions_before_capture() -> void:
	var root: String = _make_root("protected")
	var cases: Array[Dictionary] = [
		{"required": ["src"], "excluded": "src/child"},
		{"required": ["src/child"], "excluded": "src"},
		{"required": ["src"], "excluded": "SRC"},
		{"required": [], "excluded": ".gf"},
		{"required": [], "excluded": "project.godot"},
		{"required": [], "excluded": "addons/gf"},
	]
	for entry: Dictionary in cases:
		var profile: Dictionary = _profile()
		profile["capture_scope"] = _declaration(_array(entry, "required"), [{"path": entry["excluded"], "kind": "disposable"}])
		var analyzer: CountingAnalyzer = CountingAnalyzer.new()
		var report: Dictionary = analyzer.analyze_profile(profile, {"source_root": root, "root_path": root})
		assert_false(_bool(report, "input_complete"))
		assert_true(_has_issue(report, "capture_scope_invalid"))
		assert_eq(analyzer.capture_calls, 0)
	for rule: Dictionary in [{"id": "entry", "kind": "path_exists", "paths": ["src/main.gd"]}, {"id": "features", "kind": "feature_module_contract", "roots": ["src"]}]:
		var profile: Dictionary = _profile()
		profile["rules"] = [rule]
		profile["capture_scope"] = _declaration([], [{"path": "src", "kind": "disposable"}])
		var analyzer: CountingAnalyzer = CountingAnalyzer.new()
		var report: Dictionary = analyzer.analyze_profile(profile, {"source_root": root, "root_path": root})
		assert_false(_bool(report, "input_complete"))
		assert_eq(analyzer.capture_calls, 0)
	var named_profile: String = root.path_join("policy.json")
	var source_profile: Dictionary = _profile()
	source_profile["capture_scope"] = _declaration([], [{"path": "policy.json", "kind": "disposable"}])
	_write(named_profile, JSON.stringify(source_profile))
	var session: GFProjectLayoutSession = _SESSION.new()
	assert_false(_bool(session.open_profile_text(JSON.stringify(source_profile), named_profile, {"source_root": root, "root_path": root}), "input_complete"))


func test_fixed_state_exclusions_cannot_hide_any_required_source_before_capture() -> void:
	var root: String = _make_root("fixed_protected")
	for fixed_root: String in [".git", ".godot", ".import"]:
		var required_path: String = fixed_root.path_join("src")
		_write(root.path_join(required_path).path_join("entry.gd"), "")
		for declaration_path: String in [fixed_root, required_path, fixed_root.to_upper()]:
			assert_false(_bool(_SCOPE.normalize_declaration(_declaration([declaration_path], [])), "success"), declaration_path)
		var required_profile: Dictionary = _profile()
		required_profile["capture_scope"] = _declaration([required_path], [])
		var required_analyzer: CountingAnalyzer = CountingAnalyzer.new()
		var required_report: Dictionary = required_analyzer.analyze_profile(required_profile, {"source_root": root, "root_path": root})
		assert_false(_bool(required_report, "input_complete"))
		assert_true(_has_issue(required_report, "invalid_capture_scope"))
		assert_eq(required_analyzer.capture_calls, 0)
		for profile: Dictionary in _profiles_requiring_path(required_path):
			var analyzer: CountingAnalyzer = CountingAnalyzer.new()
			var profile_report: Dictionary = analyzer.analyze_profile(profile, {"source_root": root, "root_path": root})
			assert_false(_bool(profile_report, "input_complete"))
			assert_true(_has_issue(profile_report, "capture_scope_invalid"))
			assert_eq(analyzer.compile_calls, 1)
			assert_eq(analyzer.capture_calls, 0)
		var profile_path: String = root.path_join(fixed_root).path_join("policy.json")
		var text: String = JSON.stringify(_profile())
		_write(profile_path, text)
		var session: CountingSession = CountingSession.new()
		var source_report: Dictionary = session.open_profile_text(text, profile_path, {"source_root": root, "root_path": root})
		assert_false(_bool(source_report, "input_complete"))
		assert_true(_has_issue(source_report, "capture_scope_invalid"))
		assert_eq(session.analyzer.compile_calls, 1)
		assert_eq(session.analyzer.capture_calls, 0)


func test_fixed_state_protection_is_rechecked_by_later_profile_and_snapshot_consumers() -> void:
	var root: String = _make_root("fixed_consumer")
	_write(root.path_join("src/main.gd"), "")
	for fixed_root: String in [".git", ".godot", ".import"]:
		_write(root.path_join(fixed_root).path_join("src/entry.gd"), "")
	var builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
	assert_eq(builder.begin(root, {"source_root": root}), OK)
	for _iteration: int in range(16):
		if builder.step(8)["status"] != "capturing":
			break
	var snapshot: Dictionary = builder.make_snapshot()
	assert_true(_bool(snapshot, "complete"))
	assert_eq(_array(snapshot, "files"), ["src/main.gd"])
	var observation_analyzer: GFProjectLayoutAnalyzer = _ANALYZER.new()
	assert_true(_bool(observation_analyzer.analyze_snapshot(snapshot), "input_complete"))
	var prepared: Dictionary = _SCOPE.prepare({}, root, {"source_root": root})
	assert_true(_bool(prepared, "success"))
	var binding: Dictionary = _dictionary(prepared, "binding")
	for fixed_root: String in [".git", ".godot", ".import"]:
		var required_path: String = fixed_root.path_join("src")
		for profile: Dictionary in _profiles_requiring_path(required_path):
			var analyzer: CountingAnalyzer = CountingAnalyzer.new()
			var report: Dictionary = analyzer.analyze_profile_snapshot(profile, snapshot)
			assert_false(_bool(report, "input_complete"))
			assert_true(_has_issue(report, "capture_scope_invalid"))
			assert_eq(analyzer.compile_calls, 1)
			assert_eq(analyzer.capture_calls, 0)
		var forged_binding: Dictionary = _binding_with_extra_protection(binding, required_path)
		assert_false(_SCOPE.binding_is_valid(forged_binding), "有效 digest 不能授权隐藏硬保护根。")
		var rejected_builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
		assert_eq(rejected_builder.begin_prepared(root, forged_binding), ERR_INVALID_PARAMETER)
		assert_eq(_int(rejected_builder.get_progress(), "file_count"), 0)
		assert_eq(rejected_builder.make_snapshot(), {})
		var forged_snapshot: Dictionary = snapshot.duplicate(true)
		var forged_scope: Dictionary = _dictionary(forged_snapshot, "scope")
		for field: String in ["protected_roots", "policy_digest"]:
			forged_scope[field] = forged_binding[field]
		var rejected_report: Dictionary = observation_analyzer.analyze_snapshot(forged_snapshot)
		assert_false(_bool(rejected_report, "input_complete"))
		assert_true(_has_issue(rejected_report, "invalid_snapshot_scope_binding"))


func test_scope_declaration_is_closed_and_cannot_reanchor_or_merge_options() -> void:
	for path: String in ["../escape", "./cache", "a//b", "res://cache", "C:/cache", "a\\b", "cache/**", "cache.", "NUL", "com1", "cache "]:
		assert_false(_bool(_SCOPE.normalize_declaration(_declaration([], [{"path": path, "kind": "disposable"}])), "success"), path)
	for paths: Array in [["cache", "cache/sub"], ["cache", "CACHE"], [".godot", "cache"]]:
		var excluded: Array = []
		for path: String in paths:
			excluded.append({"path": path, "kind": "disposable"})
		assert_false(_bool(_SCOPE.normalize_declaration(_declaration([], excluded)), "success"))
	var root: String = _make_root("mapping")
	var profile: Dictionary = _profile()
	profile["capture_scope"] = _declaration([], [{"path": "evidence", "kind": "disposable"}])
	assert_false(_bool(_SCOPE.prepare(profile, root.path_join("sub"), {"source_root": root}), "success"))
	assert_false(_bool(_SCOPE.prepare(profile, root, {"source_root": root, "capture_scope": _declaration([], [])}), "success"))
	var equal_scope: Dictionary = _declaration([], [{"path": "evidence", "kind": "disposable"}])
	assert_true(_bool(_SCOPE.prepare(profile, root, {"source_root": root, "capture_scope": equal_scope}), "success"))
	var invalid: Dictionary = equal_scope.duplicate(true)
	invalid["extra"] = true
	assert_false(_bool(_SCOPE.normalize_declaration(invalid), "success"))


func test_excluded_missing_root_drift_and_wrong_type_fail_closed() -> void:
	var root: String = _make_root("drift")
	_write(root.path_join("src/main.gd"), "")
	var scope: Dictionary = _declaration([], [{"path": "evidence", "kind": "disposable"}])
	var builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
	assert_eq(builder.begin(root, {"source_root": root, "capture_scope": scope}), OK)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join("evidence"))), OK)
	for _iteration: int in range(16):
		if builder.step(8)["status"] != "capturing":
			break
	assert_false(_bool(builder.make_snapshot(), "complete"))
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join("evidence"))), OK)
	_write(root.path_join("evidence"), "file")
	assert_eq(builder.begin(root, {"source_root": root, "capture_scope": scope}), ERR_INVALID_PARAMETER)


func test_prepared_capture_rejects_failed_second_identity_qualification() -> void:
	var root: String = _make_root("prepared_drift")
	_write(root.path_join("src/main.gd"), "")
	var scope: Dictionary = _declaration(["src"], [{"path": "evidence", "kind": "disposable"}])
	var prepared: Dictionary = _SCOPE.prepare({}, root, {"source_root": root, "capture_scope": scope})
	assert_true(_bool(prepared, "success"))
	var binding: Dictionary = _dictionary(prepared, "binding")
	assert_true(_bool(_SCOPE.capture_root_states(binding), "success"))
	var builder: ExcludedFileAfterBeginBuilder = ExcludedFileAfterBeginBuilder.new()
	builder.excluded_path = root.path_join("evidence")
	assert_eq(builder.begin_prepared(root, binding), ERR_INVALID_PARAMETER)
	assert_eq(builder.mutation_error, OK, "首次准入成功后实际将缺失排除根变为文件。")
	var failed_identity: Dictionary = _SCOPE.capture_root_states(binding)
	assert_false(_bool(failed_identity, "success"))
	assert_eq(_SCOPE.capture_root_states(binding), failed_identity, "持续相同的失败不能成为 complete 的有效基线。")
	assert_eq(builder.get_status(), "failed")
	assert_true(_has_issue(builder.get_progress(), "capture_scope_identity_invalid"))
	assert_eq(_int(builder.get_progress(), "pending_directory_count"), 0)
	assert_eq(_int(builder.step(64), "file_count"), 0)
	assert_eq(builder.make_snapshot(), {})


func test_exclusion_identity_uses_actual_literal_entry_spelling() -> void:
	var root: String = _make_root("literal_case")
	_write(root.path_join("src/main.gd"), "")
	_write(root.path_join("Cache/evidence.txt"), "")
	var declaration: Dictionary = _declaration(["src"], [{"path": "cache", "kind": "disposable"}])
	var profile: Dictionary = _profile()
	profile["capture_scope"] = declaration
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER.new()
	var report: Dictionary = analyzer.analyze_profile(profile, {"root_path": root, "source_root": root})
	var builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root.path_join("cache"))):
		assert_false(_bool(report, "input_complete"))
		assert_eq(_int(report, "file_count"), 0)
		assert_true(_has_issue(report, "capture_scope_identity_invalid"))
		assert_eq(builder.begin(root, {"source_root": root, "capture_scope": declaration}), ERR_INVALID_PARAMETER)
	else:
		assert_true(_bool(report, "input_complete"))
		assert_eq(_int(report, "file_count"), 2, "大小写敏感文件系统上的 Cache 不得因不存在的 cache 声明而隐藏。")
	profile["capture_scope"] = _declaration(["src"], [{"path": "Cache", "kind": "disposable"}])
	var exact: Dictionary = analyzer.analyze_profile(profile, {"root_path": root, "source_root": root})
	assert_true(_bool(exact, "input_complete"))
	assert_eq(_int(exact, "file_count"), 1)


func test_strict_json_rejects_duplicates_surrogates_nonfinite_and_invalid_utf8() -> void:
	var reader: _READER = _READER.new()
	for text: String in ["{\"schema_version\":2,\"schema_version\":2}", "{\"a\":1,\"\\u0061\":2}", "{\"id\":\"\\ud800\"}", "{\"id\":\"\\udc00\"}", "{\"id\":\"\\ud800x\"}", "{\"\\ud800\":\"key\"}", "{\"values\":[\"\\udc00\"]}", "{\"nested\":{\"value\":\"\\ud800\"}}", "{\"x\":1e9999}", "{\"x\":01}", "{\"x\":+1}", "{\"x\":.1}", "{\"x\":1.}", "{\"x\":true,}", "[{}]", "{\"x\":NaN}"]:
		var rejected: Dictionary = reader.parse_text(text)
		assert_false(_bool(rejected, "success"), text)
		assert_eq(_dictionary(rejected, "profile"), {})
	assert_true(_bool(reader.parse_text("{\"id\":\"\\ud83d\\ude80\",\"value\":1.0}"), "success"))
	assert_false(_bool(reader.parse_text(" ".repeat(1_048_577)), "success"))
	var root: String = _make_root("utf8")
	var path: String = root.path_join("policy.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	assert_true(file.store_buffer(PackedByteArray([0x7B, 0x22, 0xED, 0xA0, 0x80, 0x22, 0x3A, 0x31, 0x7D])))
	file.close()
	assert_false(_bool(reader.read_path(path), "success"))
	_write(path, " ".repeat(1_048_577))
	assert_false(_bool(reader.read_path(path), "success"))


func test_profile_failures_do_not_capture_and_file_source_must_match_actual_text() -> void:
	var root: String = _make_root("admission")
	var analyzer: CountingAnalyzer = CountingAnalyzer.new()
	var profile: Dictionary = _profile()
	profile["unknown"] = true
	assert_false(_bool(analyzer.analyze_profile(profile, {"root_path": root}), "input_complete"))
	assert_eq(analyzer.capture_calls, 0)
	var valid: Dictionary = _profile()
	var source_path: String = root.path_join("policy.json")
	var text: String = JSON.stringify(valid)
	_write(source_path, text)
	var session: CountingSession = CountingSession.new()
	assert_false(_bool(session.open_profile_text(text + " ", source_path, {"source_root": root, "root_path": root}), "input_complete"))
	assert_eq(session.analyzer.compile_calls, 0)
	assert_eq(session.analyzer.capture_calls, 0)
	assert_true(_bool(session.open_profile_text(text, source_path, {"source_root": root, "root_path": root}), "input_complete"))
	assert_eq(session.analyzer.compile_calls, 1)
	assert_eq(session.analyzer.capture_calls, 1)
	var outside: String = _make_root("outside").path_join("policy.json")
	_write(outside, text)
	assert_false(_bool(session.open_profile_text(text, outside, {"source_root": root, "root_path": root}), "input_complete"))
	assert_eq(session.analyzer.compile_calls, 1)


func test_session_queries_reuse_one_compile_and_owned_validation_index() -> void:
	var root: String = _make_root("session")
	_write(root.path_join("src/main.gd"), "")
	var session: CountingSession = CountingSession.new()
	var profile: Dictionary = _profile()
	profile["rules"] = [{"id": "entry", "kind": "path_exists", "paths": ["src/missing.gd"], "severity": "warning"}]
	var exported: Dictionary = session.open_profile(profile, {"root_path": root})
	assert_true(_bool(exported, "evaluation_complete"))
	var findings: Array = _array(exported, "findings")
	assert_eq(findings.size(), 1)
	var finding: Dictionary = findings[0]
	var digest: String = exported["input_digest"]
	var first_index: Dictionary = session.get_owned_validation_for_framework()
	assert_true(_bool(first_index, "valid"))
	exported["root_path"] = "spoof"
	profile["rules"] = []
	for _iteration: int in range(3):
		assert_true(_bool(session.plan(), "complete"))
		assert_true(_bool(session.explain(_string(finding, "finding_id")), "complete"))
		var impact: Dictionary = session.impact({"kind": "delete", "source_path": "src/main.gd", "target_path": ""})
		assert_eq(_string(impact, "status"), "unknown")
		assert_eq(_string(impact, "source_analysis_digest"), digest)
		assert_true(is_same(first_index, session.get_owned_validation_for_framework()))
	assert_eq(session.analyzer.compile_calls, 1)
	assert_eq(session.analyzer.capture_calls, 1)
	session.close()
	assert_eq(session.get_analysis(), {})
	assert_false(_bool(session.plan(), "complete"))
	assert_false(_bool(session.explain(_string(finding, "finding_id")), "complete"))


func test_snapshot_identity_tampering_and_later_required_protection_are_rejected() -> void:
	var root: String = _make_root("consumer")
	_write(root.path_join("src/main.gd"), "")
	var scope: Dictionary = _declaration([], [{"path": "evidence", "kind": "disposable"}])
	var builder: GFProjectLayoutEditorSnapshotBuilder = _BUILDER.new()
	assert_eq(builder.begin(root, {"source_root": root, "capture_scope": scope}), OK)
	for _iteration: int in range(16):
		if builder.step(8)["status"] != "capturing":
			break
	var snapshot: Dictionary = builder.make_snapshot()
	var analyzer: GFProjectLayoutAnalyzer = _ANALYZER.new()
	assert_true(_bool(analyzer.analyze_snapshot(snapshot), "input_complete"))
	var profile: Dictionary = _profile()
	profile["capture_scope"] = scope
	profile["rules"] = [{"id": "required", "kind": "path_exists", "paths": ["src/main.gd"]}]
	assert_true(_bool(analyzer.analyze_profile_snapshot(profile, snapshot), "input_complete"))
	profile["rules"] = [{"id": "required", "kind": "path_exists", "paths": ["evidence/entry.gd"]}]
	assert_false(_bool(analyzer.analyze_profile_snapshot(profile, snapshot), "input_complete"))
	for field: String in ["source_root", "profile_source_path", "policy_digest"]:
		var changed: Dictionary = snapshot.duplicate(true)
		var changed_scope: Dictionary = _dictionary(changed, "scope")
		changed_scope[field] = "spoof"
		assert_false(_bool(analyzer.analyze_snapshot(changed), "input_complete"), field)
	var changed_generation: Dictionary = snapshot.duplicate(true)
	changed_generation["generation"] = 99
	assert_false(_bool(analyzer.analyze_snapshot(changed_generation), "input_complete"))
	var old_schema: Dictionary = snapshot.duplicate(true)
	old_schema["schema_version"] = 1
	assert_false(_bool(analyzer.analyze_snapshot(old_schema), "input_complete"))


func _profile() -> Dictionary:
	return {"schema_version": 2, "id": "authority.fixture", "zones": [], "rules": []}


func _declaration(required: Array, excluded: Array) -> Dictionary:
	return {"schema_version": 1, "root_path": "res://", "required_roots": required, "excluded_roots": excluded}


func _profiles_requiring_path(path: String) -> Array[Dictionary]:
	var zone_profile: Dictionary = _profile()
	zone_profile["zones"] = [{"id": "required", "roots": [path], "required": true}]
	var path_profile: Dictionary = _profile()
	path_profile["rules"] = [{"id": "entry", "kind": "path_exists", "paths": [path.path_join("entry.gd")]}]
	var feature_profile: Dictionary = _profile()
	feature_profile["rules"] = [{"id": "feature", "kind": "feature_module_contract", "roots": [path], "required_subdirs": ["scripts"]}]
	return [zone_profile, path_profile, feature_profile]


func _binding_with_extra_protection(binding: Dictionary, protected_path: String) -> Dictionary:
	var changed: Dictionary = binding.duplicate(true)
	var protected: Array = _array(changed, "protected_roots").duplicate()
	protected.append(protected_path)
	protected.sort()
	changed["protected_roots"] = protected
	var digest_input: Dictionary = {}
	for field: String in ["capture_scope", "source_root", "root_path", "protected_roots", "profile_source_path", "excluded_prefixes"]:
		digest_input[field] = changed[field]
	changed["policy_digest"] = JSON.stringify(digest_input).sha256_text()
	return changed


func _make_root(label: String) -> String:
	var root: String = "res://build/gf_project_layout_tests/authority_%s_%d" % [label, Time.get_ticks_usec()]
	_roots.append(root)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root)), OK)
	return root


func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())), OK)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		assert_true(file.store_string(text))
		file.close()


func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	assert_eq(directory.list_dir_begin(), OK)
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name not in [".", ".."]:
			var child: String = path.path_join(entry_name)
			if directory.current_is_dir():
				_remove_tree(child)
			else:
				var _remove_file: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
		entry_name = directory.get_next()
	directory.list_dir_end()
	var _remove_root: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _has_issue(report: Dictionary, kind: String) -> bool:
	for value: Variant in _array(report, "issues"):
		if value is Dictionary:
			var issue: Dictionary = value
			if issue.get("kind") == kind:
				return true
	return false


func _issue_at(report: Dictionary, kind: String, path: String) -> bool:
	for value: Variant in _array(report, "issues"):
		if value is Dictionary:
			var issue: Dictionary = value
			if issue.get("kind") == kind and issue.get("path") == path:
				return true
	return false


func _array(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value if value is Array else []


func _dictionary(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value if value is Dictionary else {}


func _bool(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key)
	assert_true(value is bool, "字段 %s 必须存在且为 bool。" % key)
	if value is bool:
		var typed_value: bool = value
		return typed_value
	return false


func _int(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key)
	assert_true(value is int, "字段 %s 必须存在且为 int。" % key)
	if value is int:
		var typed_value: int = value
		return typed_value
	return -1


func _string(source: Dictionary, key: String) -> String:
	var value: Variant = source.get(key)
	assert_true(value is String, "字段 %s 必须存在且为 String。" % key)
	if value is String:
		var typed_value: String = value
		return typed_value
	return ""
