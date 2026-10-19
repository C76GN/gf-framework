@tool
extends GutTest

const _ANALYZER_SCRIPT = preload("res://addons/gf/tools/code_quality/gf_code_quality_analyzer.gd")
const _FILES_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_files.gd")
const _TREE_SCRIPT = preload("res://tests/gf_core/support/gf_owned_test_tree_support.gd")
var _root: String = ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path("user://gf-code-quality-%s" % Time.get_ticks_usec())
	assert_eq(
		DirAccess.make_dir_recursive_absolute(_root),
		OK
	)


func after_each() -> void:
	var parent: String = ProjectSettings.globalize_path("user://")
	if _root.begins_with(parent.path_join("gf-code-quality-")):
		assert_eq(
			_TREE_SCRIPT.remove_owned_tree(_root),
			OK
		)
	_root = ""


func test_installing_tool_does_not_select_a_policy_or_write_configuration() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root)
	assert_eq(
		_report_text(report, "status"),
		"unconfigured"
	)
	assert_false(_report_bool(report, "ok"))
	assert_false(_report_bool(report, "complete"))
	assert_eq(
		_report_int(report, "files_failed"),
		0
	)
	assert_false(DirAccess.dir_exists_absolute(_root.path_join(".gf")))


func test_unknown_rules_and_configuration_fields_fail_instead_of_disabling_checks() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	for config: Dictionary in [
		{ "schema_version": 1, "preset": "gf-game@2" },
		{
			"schema_version": 1,
			"rules": { "doc_typo": "error" },
		},
		{
			"schema_version": 1,
			"preset": "gf-game@1",
			"fix": true,
		},
		{
			"schema_version": 1,
			"preset": "gf-game@1",
			"layout": { "line_length": 80 },
		},
	]:
		var report: Dictionary = analyzer.analyze_source(
			"res://source.gd",
			"extends RefCounted\n",
			config
		)
		assert_eq(
			_report_text(report, "status"),
			"incomplete"
		)
		assert_false(_report_bool(report, "ok"))
		assert_eq(
			_report_int(report, "files_failed"),
			0
		)


func test_rule_severity_changes_exit_eligibility_but_keeps_the_diagnostic() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var source: String = "extends RefCounted\n\n\nfunc _work() -> void:\n\tpass\n"
	for level: String in ["error", "warning"]:
		var report: Dictionary = analyzer.analyze_source(
			"res://source.gd",
			source,
			_config("doc_private_summary", level)
		)
		assert_true(_report_bool(report, "complete"))
		assert_eq(
			_report_text(report, "status"),
			"violations"
		)
		assert_eq(
			_report_bool(report, "ok"),
			level == "warning"
		)
		var findings: Array = report["diagnostics"]
		var finding: Dictionary = findings[0]
		assert_eq(
			findings.size(),
			1
		)
		assert_eq(
			_report_text(finding, "severity"),
			level
		)
		assert_eq(
			_report_text(finding, "rule"),
			"doc_private_summary"
		)


func test_explicit_single_rule_does_not_implicitly_enable_other_rules() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var source: String = "extends RefCounted\nvar value=1\n"
	var report: Dictionary = analyzer.analyze_source(
		"res://source.gd",
		source,
		_config("doc_private_summary", "error")
	)
	assert_true(_report_bool(report, "complete"))
	assert_true(_report_bool(report, "ok"))
	var findings: Array = report["diagnostics"]
	assert_eq(findings, [])


func test_empty_rule_selection_is_unconfigured() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_source(
		"res://source.gd",
		"extends RefCounted\n",
		{ "schema_version": 1, "rules": {} }
	)
	assert_eq(
		_report_text(report, "status"),
		"unconfigured"
	)
	assert_false(_report_bool(report, "ok"))


func test_invalid_structure_is_incomplete_even_when_only_documentation_is_enabled() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_source(
		"res://source.gd",
		"extends RefCounted\nvar x = [\n",
		_config("doc_private_summary", "warning")
	)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_eq(
		_report_text(report, "status"),
		"incomplete"
	)
	assert_eq(
		_report_int(report, "files_failed"),
		1
	)


func test_game_preset_requires_private_summary_without_framework_tags() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var source: String = "extends RefCounted\n\n\n## 处理待执行动作。\nfunc _work() -> void:\n\tpass\n"
	var report: Dictionary = analyzer.analyze_source(
		"res://source.gd",
		source,
		{ "schema_version": 1, "preset": "gf-game@1" }
	)
	assert_true(
		_report_bool(report, "ok"),
		str(report["diagnostics"])
	)
	var missing: Dictionary = analyzer.analyze_source(
		"res://source.gd",
		source.replace("## 处理待执行动作。\n", ""),
		{ "schema_version": 1, "preset": "gf-game@1" }
	)
	assert_true(_has_rule(missing, "doc_private_summary"))


func test_scan_respects_directory_boundaries_and_is_read_only() -> void:
	_write("scripts/main.gd", "extends RefCounted\nvar _value: int = 1\n")
	_write("scripts/vendor/ignored.gd", "unterminated [")
	_write("scripts/vendor_game/main.gd", "extends RefCounted\nvar _value: int = 1\n")
	var config: Dictionary = _config("doc_private_summary", "error")
	config["include"] = ["res://scripts"]
	config["exclude"] = ["res://scripts/vendor"]
	var before: String = FileAccess.get_file_as_string(_root.path_join("scripts/main.gd"))
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root, config)
	assert_true(_report_bool(report, "complete"))
	assert_eq(
		_report_int(report, "files_checked"),
		2
	)
	var hashes: Dictionary = report["source_hashes"]
	assert_true(hashes.has("res://scripts/vendor_game/main.gd"))
	assert_false(hashes.has("res://scripts/vendor/ignored.gd"))
	assert_eq(
		FileAccess.get_file_as_string(_root.path_join("scripts/main.gd")),
		before
	)
	assert_false(DirAccess.dir_exists_absolute(_root.path_join(".gf")))


func test_project_config_and_explicit_config_produce_the_same_diagnostics() -> void:
	_write("main.gd", "extends RefCounted\nvar _value: int = 1\n")
	var config: Dictionary = _config("doc_private_summary", "error")
	_write(
		".gf/code_quality.json",
		JSON.stringify(config)
	)
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var explicit_report: Dictionary = analyzer.analyze_project(_root, config)
	var loaded_report: Dictionary = analyzer.analyze_project(_root)
	assert_eq(explicit_report, loaded_report)


func test_project_scan_includes_hidden_source_files_and_directories() -> void:
	_write("scripts/.hidden.gd", "[")
	_write("scripts/.private/broken.gd", "[")
	if OS.get_name() == "Windows":
		for path: String in ["scripts/.hidden.gd", "scripts/.private"]:
			assert_eq(
				FileAccess.set_hidden_attribute(
					_root.path_join(path),
					true
				),
				OK
			)
	var config: Dictionary = _config("doc_private_summary", "error")
	config["include"] = ["res://scripts"]
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root, config)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_eq(
		_report_int(report, "files_checked"),
		2
	)
	assert_eq(
		_report_int(report, "files_failed"),
		2
	)
	var hashes: Dictionary = report["source_hashes"]
	assert_true(hashes.has("res://scripts/.hidden.gd"))
	assert_true(hashes.has("res://scripts/.private/broken.gd"))


func test_missing_included_directory_is_incomplete() -> void:
	var config: Dictionary = _config("doc_private_summary", "error")
	config["include"] = ["res://missing"]
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root, config)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_true(_has_rule(report, "source_read"))
	assert_eq(
		_report_int(report, "files_failed"),
		0
	)


func test_cancelled_scan_never_publishes_success() -> void:
	_write("main.gd", "extends RefCounted\n")
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(
		_root,
		_config("doc_private_summary", "error"),
		func() -> bool:
			return true
	)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_true(_has_rule(report, "analysis_cancelled"))
	assert_eq(
		_report_int(report, "files_failed"),
		0
	)


func test_changed_source_during_scan_invalidates_result() -> void:
	_write("a.gd", "extends RefCounted\n")
	_write("b.gd", "extends RefCounted\n")
	var visits: Array[int] = [0]
	var probe: Callable = func() -> bool:
		visits[0] += 1
		_write(
			"a.gd",
			"extends RefCounted\n# edit %s\n" % visits[0]
		)
		return false
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(
		_root,
		_config("doc_private_summary", "error"),
		probe
	)
	assert_false(_report_bool(report, "complete"))
	assert_true(_has_rule(report, "source_changed"))


func test_path_traversal_and_control_characters_are_configuration_errors() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	for path: String in [
		"res://../outside",
		"res://scripts/../outside",
		"res://scripts\nother",
	]:
		var config: Dictionary = _config("doc_private_summary", "error")
		config["include"] = [path]
		var report: Dictionary = analyzer.analyze_project(_root, config)
		assert_eq(
			_report_text(report, "status"),
			"incomplete"
		)
		assert_eq(
			_report_int(report, "files_checked"),
			0
		)


func test_invalid_utf8_fails_without_analyzing_partial_text() -> void:
	var file: FileAccess = FileAccess.open(
		_root.path_join("invalid.gd"),
		FileAccess.WRITE
	)
	assert_not_null(file)
	assert_true(file.store_buffer(PackedByteArray([0xc0, 0xaf])))
	file.close()
	var capture: Dictionary = _FILES_SCRIPT.read_text(
		_root.path_join("invalid.gd"),
		2
	)
	assert_false(_report_bool(capture, "ok"))
	assert_eq(
		_report_int(capture, "size_bytes"),
		2
	)
	assert_eq(
		_report_int(capture, "consumed_bytes"),
		2
	)
	assert_eq(
		_report_text(capture, "text"),
		""
	)
	var rejected: Dictionary = _FILES_SCRIPT.read_text(
		_root.path_join("invalid.gd"),
		1
	)
	assert_false(_report_bool(rejected, "ok"))
	assert_eq(
		_report_int(rejected, "size_bytes"),
		2
	)
	assert_eq(
		_report_int(rejected, "consumed_bytes"),
		0
	)
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(
		_root,
		_config("doc_private_summary", "error")
	)
	assert_false(_report_bool(report, "complete"))
	assert_eq(
		_report_int(report, "files_checked"),
		0
	)
	assert_true(_has_rule(report, "source_read"))
	assert_eq(
		_report_int(report, "files_failed"),
		1
	)


func test_oversized_file_is_one_file_budget_failure() -> void:
	_write(
		"oversized.gd",
		"#" + "x".repeat(4 * 1024 * 1024)
	)
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(
		_root,
		_config("doc_private_summary", "warning")
	)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_eq(
		_report_int(report, "files_checked"),
		0
	)
	assert_eq(
		_report_int(report, "files_failed"),
		1
	)
	assert_true(_has_rule(report, "analysis_budget"))
	assert_false(_has_rule(report, "source_read"))
	var diagnostics: Array = report["diagnostics"]
	assert_eq(
		diagnostics.size(),
		1
	)


func _config(rule: String, level: String) -> Dictionary:
	return {
		"schema_version": 1,
		"rules": { rule: level },
		"exclude": [],
	}


func test_diagnostic_budget_cannot_be_disabled_or_report_a_complete_scan() -> void:
	var source: String = "extends RefCounted\n"
	for index: int in range(10_010):
		source += "var _value_%d: int = 0\n" % index
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_source(
		"res://many_members.gd",
		source,
		_config("doc_private_summary", "warning")
	)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_true(_has_rule(report, "analysis_budget"))
	var diagnostics: Array = report["diagnostics"]
	assert_eq(
		diagnostics.size(),
		10_000
	)
	assert_false(_ANALYZER_SCRIPT.get_rule_ids().has("analysis_budget"))
	assert_eq(
		_report_int(report, "files_failed"),
		1
	)


func test_project_diagnostic_budget_counts_one_failed_file_once() -> void:
	var source: String = "extends RefCounted\n"
	for index: int in range(10_010):
		source += "var _value_%d: int = 0\n" % index
	_write("a.gd", source)
	_write("b.gd", "extends RefCounted\n")
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(
		_root,
		_config("doc_private_summary", "warning")
	)
	assert_false(_report_bool(report, "complete"))
	assert_false(_report_bool(report, "ok"))
	assert_eq(
		_report_int(report, "files_checked"),
		1
	)
	assert_eq(
		_report_int(report, "files_failed"),
		1
	)
	var diagnostics: Array = report["diagnostics"]
	assert_eq(
		diagnostics.size(),
		10_000
	)
	var budget_count: int = 0
	for issue: Dictionary in diagnostics:
		if issue["rule"] == "analysis_budget":
			budget_count += 1
	assert_eq(budget_count, 1)


func test_disabled_rule_families_and_rules_do_not_consume_diagnostic_budget() -> void:
	var private_source: String = "extends RefCounted\n"
	var public_source: String = "extends RefCounted\n"
	for index: int in range(10_010):
		private_source += "var _value_%d: int = 0\n" % index
		public_source += "var value_%d=0\n" % index
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	for fixture: Dictionary in [
		{ "source": private_source, "rule": "token_spacing" },
		{ "source": public_source, "rule": "doc_private_summary" },
	]:
		var source: String = fixture["source"]
		var rule: String = fixture["rule"]
		var report: Dictionary = analyzer.analyze_source(
			"res://many_members.gd",
			source,
			_config(rule, "error")
		)
		assert_true(_report_bool(report, "complete"))
		assert_true(_report_bool(report, "ok"))
		assert_eq(
			_report_int(report, "files_checked"),
			1
		)
		assert_eq(
			_report_int(report, "files_failed"),
			0
		)
		var diagnostics: Array = report["diagnostics"]
		assert_eq(diagnostics, [])


func test_case_insensitive_scope_alias_cannot_bypass_exclusions_or_duplicate_files() -> void:
	var directory: DirAccess = DirAccess.open(_root)
	assert_not_null(directory)
	if directory == null or directory.is_case_sensitive(_root):
		return
	_write("scripts/main.gd", "extends RefCounted\n")
	_write("scripts/vendor/broken.gd", "[")
	_write("addons/broken.gd", "[")
	_write(".godot/broken.gd", "[")
	var config: Dictionary = _config("doc_private_summary", "error")
	config["include"] = [
		"res://SCRIPTS",
		"res://scripts",
		"res://AdDoNs",
		"res://.GoDoT",
	]
	config["exclude"] = ["res://scripts/vendor", "res://addons"]
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root, config)
	assert_true(
		_report_bool(report, "ok"),
		str(report["diagnostics"])
	)
	assert_eq(
		_report_int(report, "files_checked"),
		1
	)


func test_case_sensitive_scope_keeps_distinct_directory_names_and_exclusions() -> void:
	var directory: DirAccess = DirAccess.open(_root)
	assert_not_null(directory)
	if directory == null or not directory.is_case_sensitive(_root):
		return
	_write("scripts/main.gd", "extends RefCounted\n")
	_write("Scripts/main.gd", "extends RefCounted\n")
	var config: Dictionary = _config("doc_private_summary", "error")
	config["include"] = ["res://scripts", "res://Scripts"]
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	var report: Dictionary = analyzer.analyze_project(_root, config)
	assert_true(
		_report_bool(report, "ok"),
		str(report["diagnostics"])
	)
	assert_eq(
		_report_int(report, "files_checked"),
		2
	)
	config["exclude"] = ["res://scripts/main.gd"]
	report = analyzer.analyze_project(_root, config)
	assert_true(
		_report_bool(report, "ok"),
		str(report["diagnostics"])
	)
	assert_eq(
		_report_int(report, "files_checked"),
		1
	)
	var hashes: Dictionary = report["source_hashes"]
	assert_true(hashes.has("res://Scripts/main.gd"))
	assert_false(hashes.has("res://scripts/main.gd"))


func test_ambiguous_scope_aliases_are_rejected() -> void:
	var analyzer: GFCodeQualityAnalyzer = _ANALYZER_SCRIPT.new()
	for path: String in [
		"res://scripts.",
		"res://scripts/.",
		"res://scripts/..",
		"res://scripts|other",
	]:
		var config: Dictionary = _config("doc_private_summary", "error")
		config["include"] = [path]
		var report: Dictionary = analyzer.analyze_project(_root, config)
		assert_eq(
			_report_text(report, "status"),
			"incomplete"
		)
		assert_eq(
			_report_int(report, "files_checked"),
			0
		)


func _report_bool(report: Dictionary, key: String) -> bool:
	var value: bool = report[key]
	return value


func _report_int(report: Dictionary, key: String) -> int:
	var value: int = report[key]
	return value


func _report_text(report: Dictionary, key: String) -> String:
	var value: String = report[key]
	return value


func _has_rule(report: Dictionary, rule: String) -> bool:
	for issue: Dictionary in report["diagnostics"]:
		if issue["rule"] == rule:
			return true
	return false


func _write(relative: String, text: String) -> void:
	var path: String = _root.path_join(relative)
	assert_eq(
		DirAccess.make_dir_recursive_absolute(path.get_base_dir()),
		OK
	)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		assert_true(file.store_string(text))
		file.close()
