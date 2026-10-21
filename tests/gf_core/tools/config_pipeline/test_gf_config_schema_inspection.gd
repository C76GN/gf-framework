@tool

## 验证只读结构检查复用真实构建结果，并保持失败与来源身份边界。
extends GutTest


# --- 私有变量 ---

var _paths: Array[String] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


# --- 测试 ---

func test_inspect_reports_effective_schema_receipt_and_version_without_writing() -> void:
	var profile_path: String = _make_profile("id:int!,title:string\n7,not-in-schema-report\n")
	var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
	var result: Dictionary = command.run(
		PackedStringArray(
			[
				"--profile",
				profile_path,
				"--operation",
				"inspect",
				"--json",
			]
		)
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var runner_result: Dictionary = result["runner_result"]
	var schema_report: Dictionary = runner_result["schema_report"]
	var reported_version: Variant = schema_report["version"]
	var version_matches: bool = typeof(reported_version) == TYPE_STRING and reported_version == "balance-2026"
	assert_true(version_matches)
	var table_count: Variant = schema_report["table_count"]
	var table_count_matches: bool = typeof(table_count) == TYPE_INT and table_count == 1
	assert_true(table_count_matches)
	var table: Dictionary = schema_report["tables"][0]
	var table_name: Variant = table["table_name"]
	var table_name_matches: bool = typeof(table_name) == TYPE_STRING_NAME and table_name == &"items"
	assert_true(table_name_matches)
	var record_count: Variant = table["record_count"]
	var record_count_matches: bool = typeof(record_count) == TYPE_INT and record_count == 1
	assert_true(record_count_matches)
	var schema: Dictionary = table["schema"]
	var schema_origin: Variant = table["schema_origin"]
	var schema_origin_matches: bool = typeof(schema_origin) == TYPE_STRING and schema_origin == "typed_headers"
	assert_true(schema_origin_matches)
	var field_name: Variant = schema["columns"][0]["field_name"]
	var field_name_matches: bool = typeof(field_name) == TYPE_STRING_NAME and field_name == &"id"
	assert_true(field_name_matches)
	var value_type: Variant = schema["columns"][0]["value_type"]
	var value_type_matches: bool = typeof(value_type) == TYPE_INT and value_type == GFConfigTableColumn.ValueType.INT
	assert_true(value_type_matches)
	var required: Variant = schema["columns"][0]["required"]
	var required_matches: bool = typeof(required) == TYPE_BOOL and required == true
	assert_true(required_matches)
	var source_receipt: Dictionary = table["source_receipt"]
	var header_location: Dictionary = table["header_location"]
	assert_false(source_receipt.is_empty())
	var header_line: Variant = header_location["line"]
	var header_line_matches: bool = typeof(header_line) == TYPE_INT and header_line == 1
	assert_true(header_line_matches)
	assert_false(runner_result.has("database"))
	assert_false(command.make_output_text(result).contains("not-in-schema-report"))
	assert_false(FileAccess.file_exists(profile_path + ".database.tres"))
	assert_false(FileAccess.file_exists(profile_path + ".access.gd"))
	assert_false(FileAccess.file_exists(profile_path + ".manifest.json"))


func test_inspect_failure_does_not_advertise_partial_effective_schema() -> void:
	var profile_path: String = _make_profile("id:int!,title:string\ninvalid,broken\n")
	var result: Dictionary = GFConfigPipelineRunner.new().inspect_profile_path(
		profile_path,
		{
			"validate_schema": false,
			"validate_database": false,
			"build_options": { "validate_schema": false, "validate_database": false },
		}
	)
	var success: Variant = result["success"]
	var failed: bool = typeof(success) == TYPE_BOOL and success == false
	assert_true(failed)
	var operation: Variant = result["operation"]
	var operation_matches: bool = typeof(operation) == TYPE_STRING_NAME and operation == &"inspect"
	assert_true(operation_matches)
	var schema_report: Dictionary = result["schema_report"]
	assert_true(schema_report.is_empty())
	var error_count: Variant = result["report"]["error_count"]
	var errors_reported: bool = typeof(error_count) == TYPE_INT and error_count > 0
	assert_true(errors_reported)
	assert_false(FileAccess.file_exists(profile_path + ".database.tres"))


func test_inspect_missing_profile_preserves_failure_details() -> void:
	var result: Dictionary = GFConfigPipelineRunner.new().inspect_profile_path("user://gf_schema_inspection_missing_%d.tres" % Time.get_ticks_usec())
	var success: Variant = result["success"]
	var failed: bool = typeof(success) == TYPE_BOOL and success == false
	assert_true(failed)
	var error_code: Variant = result["error_code"]
	var failure_code_reported: bool = typeof(error_code) == TYPE_INT and error_code != OK
	assert_true(failure_code_reported)
	assert_false(GFVariantData.get_option_string(result, "error").is_empty())
	var schema_report: Dictionary = result["schema_report"]
	assert_true(schema_report.is_empty())


func test_inspect_rejects_cyclic_overrides_before_recursive_copy() -> void:
	var profile_path: String = _make_profile("id:int!,title:string\n7,valid\n")
	for option_name: String in ["metadata", "parse_options"]:
		for nested: bool in [false, true]:
			var cyclic: Dictionary = {}
			cyclic["self"] = cyclic
			var overrides: Dictionary = { option_name: cyclic, "validate_schema": false }
			var options: Dictionary = { "build_options": overrides } if nested else overrides
			var result: Dictionary = GFConfigPipelineRunner.new().inspect_profile_path(profile_path, options)
			cyclic.clear()
			var success: Variant = result["success"]
			var failed: bool = typeof(success) == TYPE_BOOL and success == false
			assert_true(failed)
			assert_true(GFVariantData.get_option_dictionary(result, "schema_report").is_empty())
			var error_count: Variant = result["report"]["error_count"]
			var errors_reported: bool = typeof(error_count) == TYPE_INT and error_count > 0
			assert_true(errors_reported)
			var validation_switch: Variant = overrides["validate_schema"]
			var validation_switch_unchanged: bool = typeof(validation_switch) == TYPE_BOOL and validation_switch == false
			assert_true(validation_switch_unchanged, "Inspection must not mutate the caller's validation switches.")
			assert_false(FileAccess.file_exists(profile_path + ".database.tres"))


func test_inspect_rejects_over_budget_overrides_without_writing() -> void:
	var profile_path: String = _make_profile("id:int!,title:string\n7,valid\n")
	var options: Dictionary = {
		"build_options": {
			"metadata": { "payload": "x".repeat(4096) },
		},
		"work_limits": { "max_value_bytes": 256 },
	}
	var result: Dictionary = GFConfigPipelineRunner.new().inspect_profile_path(profile_path, options)
	var success: Variant = result["success"]
	var failed: bool = typeof(success) == TYPE_BOOL and success == false
	assert_true(failed)
	assert_true(GFVariantData.get_option_dictionary(result, "schema_report").is_empty())
	var error_count: Variant = result["report"]["error_count"]
	var errors_reported: bool = typeof(error_count) == TYPE_INT and error_count > 0
	assert_true(errors_reported)
	assert_false(FileAccess.file_exists(profile_path + ".database.tres"))


# --- 私有/辅助方法 ---

func _make_profile(csv: String) -> String:
	var prefix: String = "user://gf_schema_inspection_%d" % Time.get_ticks_usec()
	var source_path: String = prefix + ".csv"
	var profile_path: String = prefix + ".tres"
	_paths.append(source_path)
	_paths.append(profile_path)
	_paths.append(profile_path + ".database.tres")
	_paths.append(profile_path + ".access.gd")
	_paths.append(profile_path + ".manifest.json")
	var file: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return ""
	var _stored: bool = file.store_string(csv)
	file.close()
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = source_path
	source.schema_options = { "typed_headers": true }
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"inspection"
	profile.database_id = &"fixture"
	profile.version = "balance-2026"
	profile.sources = [source]
	profile.output_path = profile_path + ".database.tres"
	profile.access_output_path = profile_path + ".access.gd"
	assert_eq(
		ResourceSaver.save(profile, profile_path),
		OK
	)
	return profile_path
