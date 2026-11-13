@tool
extends GutTest


const DIFF_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_diff.gd")
const SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")
var _paths: PackedStringArray = []


func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


func test_diff_uses_exact_ids_ignores_order_and_reports_field_names() -> void:
	var before: GFConfigPipelineIR = _ir(
		[
			{ "id": 9007199254740993, "name": "old" },
			{ "id": 2, "name": "same" },
			{ "id": 3, "name": "removed" },
		]
	)
	var after: GFConfigPipelineIR = _ir(
		[
			{ "id": 2, "name": "same" },
			{ "id": 9007199254740993, "name": "new" },
			{ "id": 4, "name": "added" },
		]
	)
	var result: Dictionary = DIFF_SCRIPT.compare(before, after)
	assert_true(GFVariantData.get_option_bool(result, "success"))
	var tables: Array = result["tables"]
	assert_eq(
		tables.size(),
		1
	)
	var table: Dictionary = tables[0]
	assert_false(GFVariantData.get_option_bool(table, "schema_changed"))
	assert_eq(
		GFVariantData.get_option_string(table, "record_comparison"),
		"complete"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(table, "added"),
		PackedStringArray(["2:4"])
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(table, "removed"),
		PackedStringArray(["2:3"])
	)
	assert_eq(
		GFVariantData.get_option_array(table, "changed"),
		[
			{
				"id": "2:9007199254740993",
				"fields": PackedStringArray(["name"]),
			},
		]
	)
	assert_false(JSON.stringify(result).contains('"old"'))
	assert_false(JSON.stringify(result).contains('"new"'))
	assert_eq(
		GFVariantData.get_option_array(
			DIFF_SCRIPT.compare(after, after),
			"tables"
		),
		[]
	)


func test_unstable_identity_is_unknown_and_budget_exhaustion_fails() -> void:
	var ir: GFConfigPipelineIR = _ir(
		[
			{ "id": 1, "name": "a" },
			{ "id": 1, "name": "b" },
		]
	)
	var result: Dictionary = DIFF_SCRIPT.compare(ir, ir)
	assert_true(GFVariantData.get_option_bool(result, "success"))
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(result["tables"][0]),
			"record_comparison"
		),
		"unknown"
	)
	assert_false(
		GFVariantData.get_option_bool(
			DIFF_SCRIPT.compare(
				null,
				_ir(
					[
						{ "id": 1, "name": "a" },
					]
				),
				[],
				{
					"work_limits": { "max_work_units": 1 },
				}
			),
			"success"
		)
	)


func test_reference_impact_uses_both_declarations_and_empty_dependent_tables() -> void:
	var before: GFConfigPipelineIR = _ir(
		[
			{ "id": 1, "name": "old" },
		],
		true
	)
	var after: GFConfigPipelineIR = _ir(
		[
			{ "id": 1, "name": "new" },
		],
		true
	)
	var target: GFConfigPipelineConsumerTarget = GFConfigPipelineConsumerTarget.new()
	target.target_id = &"client"
	target.root_tables = ["owners"]
	target.visible_fields = {
		"owners": ["id", "name"],
		"items": ["id", "name"],
	}
	var result: Dictionary = DIFF_SCRIPT.compare(
		before,
		after,
		[target]
	)
	assert_true(GFVariantData.get_option_bool(result, "success"))
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "affected_tables"),
		PackedStringArray(["items", "owners"])
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "affected_targets"),
		PackedStringArray(["client"])
	)


func test_runner_and_cli_diff_require_baseline_and_write_nothing() -> void:
	var old_profile: String = _profile_path("id,name\n1,old\n")
	var new_profile: String = _profile_path("id,name\n1,new\n2,added\n")
	var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
	assert_false(
		GFVariantData.get_option_bool(
			runner.diff_profile_path(new_profile),
			"success"
		)
	)
	var result: Dictionary = runner.diff_profile_path(
		new_profile,
		{ "baseline_profile": old_profile }
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_false(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(result["input_capture"]),
			"digest"
		).is_empty()
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(
			GFVariantData.as_dictionary(result["diff_report"]["tables"][0]),
			"added"
		),
		PackedStringArray(["2:2"])
	)
	var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
	var cli: Dictionary = command.run(
		[
			"--profile",
			new_profile,
			"--operation",
			"diff",
			"--baseline-profile",
			old_profile,
		]
	)
	assert_true(
		GFVariantData.get_option_bool(cli, "success"),
		str(cli.get("error"))
	)
	assert_false(FileAccess.file_exists(new_profile + ".output.tres"))
	assert_false(FileAccess.file_exists(old_profile + ".output.tres"))


func test_cli_target_and_inspect_match_projected_tables() -> void:
	var path: String = _profile_path("id,name\n1,label\n", true)
	var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
	var result: Dictionary = command.run(
		[
			"--profile",
			path,
			"--operation",
			"inspect",
			"--target",
			"client",
		]
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result.get("error"))
	)
	if not GFVariantData.get_option_bool(result, "success"):
		return
	var runner: Dictionary = result["runner_result"]
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.as_dictionary(runner["schema_report"]),
			"table_count"
		),
		1
	)
	assert_eq(
		GFVariantData.get_option_array(
			GFVariantData.as_dictionary(runner["schema_report"]["tables"][0]["schema"]),
			"columns"
		).size(),
		1
	)
	assert_false(FileAccess.file_exists(path + ".output.tres"))


func test_session_blocks_external_source_changes_until_new_preview() -> void:
	var path: String = _profile_path("id,name\n1,old\n")
	var session: SESSION_SCRIPT = SESSION_SCRIPT.new()
	assert_true(session.load_profile(path))
	assert_true(
		GFVariantData.get_option_bool(
			session.run_operation(
				"export",
				{ "dry_run": true }
			),
			"success"
		)
	)
	var source: String = session.get_profile().sources[0].source_path
	_write(source, "id,name\n1,new\n")
	var blocked: Dictionary = session.run_operation("export", {})
	assert_false(GFVariantData.get_option_bool(blocked, "success"))
	assert_false(FileAccess.file_exists(path + ".output.tres"))
	assert_true(
		GFVariantData.get_option_bool(
			session.run_operation(
				"export",
				{ "dry_run": true }
			),
			"success"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			session.run_operation("export", {}),
			"success"
		)
	)
	assert_true(FileAccess.file_exists(path + ".output.tres"))


func test_changed_only_does_not_bypass_preview_credential() -> void:
	var path: String = _profile_path("id,name\n1,old\n")
	var manifest_path: String = path + ".manifest.json"
	var _tracked: bool = _paths.append(manifest_path)
	var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
	var options: Dictionary = { "changed_only": true, "manifest_path": manifest_path }
	assert_true(
		GFVariantData.get_option_bool(
			runner.export_profile_path(path, options),
			"success"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			runner.export_profile_path(path, options),
			"skipped"
		)
	)
	options["expected_input_digest"] = "stale-preview"
	assert_false(
		GFVariantData.get_option_bool(
			runner.export_profile_path(path, options),
			"success"
		)
	)


func test_closing_profile_discards_preview_credential() -> void:
	var path: String = _profile_path("id,name\n1,old\n")
	var session: SESSION_SCRIPT = SESSION_SCRIPT.new()
	assert_true(session.load_profile(path))
	assert_true(
		GFVariantData.get_option_bool(
			session.run_operation(
				"export",
				{ "dry_run": true }
			),
			"success"
		)
	)
	assert_true(session.make_arguments("export", {}).has("--expected-input-digest"))
	session.clear_profile()
	assert_false(session.make_arguments("export", {}).has("--expected-input-digest"))


func test_input_capture_includes_dictionary_tail_and_blocks_stale_export() -> void:
	var profile: GFConfigPipelineProfile = _input_profile()
	for index: int in range(4097):
		profile.metadata["k%05d" % index] = index
	var helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	var before: Dictionary = helper.capture_inputs(profile)
	assert_true(GFVariantData.get_option_bool(before, "success"))
	profile.metadata["k04096"] = -1
	var after: Dictionary = helper.capture_inputs(profile)
	assert_true(GFVariantData.get_option_bool(after, "success"))
	assert_ne(
		GFVariantData.get_option_string(before, "profile_digest"),
		GFVariantData.get_option_string(after, "profile_digest")
	)
	assert_ne(
		GFVariantData.get_option_string(before, "digest"),
		GFVariantData.get_option_string(after, "digest")
	)
	assert_eq(
		GFVariantData.get_option_string(before, "source_digest"),
		GFVariantData.get_option_string(after, "source_digest")
	)
	var result: Dictionary = GFConfigPipeline.new().export_profile(
		profile,
		{ "expected_input_digest": before["digest"] }
	)
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_false(FileAccess.file_exists(profile.output_path))


func test_input_capture_includes_array_and_packed_array_tails() -> void:
	var profile: GFConfigPipelineProfile = _input_profile()
	var values: Array[int] = []
	for index: int in range(4097):
		values.append(index)
	var helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	for items: Variant in [values, PackedInt32Array(values)]:
		profile.metadata = { "items": items }
		var before: Dictionary = helper.capture_inputs(profile)
		assert_true(GFVariantData.get_option_bool(before, "success"))
		profile.metadata["items"][4096] = -1
		var after: Dictionary = helper.capture_inputs(profile)
		assert_true(GFVariantData.get_option_bool(after, "success"))
		assert_ne(
			GFVariantData.get_option_string(before, "digest"),
			GFVariantData.get_option_string(after, "digest")
		)


func test_input_capture_rejects_declarations_exceeding_digest_budget() -> void:
	var profile: GFConfigPipelineProfile = _input_profile()
	profile.metadata = { "large": "x".repeat(4 * 1024 * 1024) }
	var captured: Dictionary = GFConfigPipelineArtifactManifest.new().capture_inputs(profile)
	assert_false(GFVariantData.get_option_bool(captured, "success"))
	assert_eq(
		GFVariantData.get_option_string(captured, "digest"),
		""
	)
	assert_false(GFVariantData.get_option_string(captured, "error").is_empty())
	assert_false(
		GFVariantData.get_option_bool(
			GFVariantData.get_option_dictionary(captured, "scan_report"),
			"success"
		)
	)


func _input_profile() -> GFConfigPipelineProfile:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = (
		"user://gf_input_capture_%d_%d.csv"
		% [Time.get_ticks_usec(), _paths.size()]
	)
	source.schema = _schema(&"items")
	profile.sources = [source]
	profile.output_path = source.source_path + ".output.tres"
	_paths.append_array([source.source_path, profile.output_path])
	_write(source.source_path, "id,name\n1,item\n")
	return profile


func _ir(rows: Array[Dictionary], with_dependents: bool = false) -> GFConfigPipelineIR:
	var result: GFConfigPipelineIR = GFConfigPipelineIR.create(&"db")
	assert_true(
		GFVariantData.get_option_bool(
			result.add_table(
				GFConfigPipelineTableIR.create(
					&"items",
					"",
					&"json",
					rows,
					_schema(&"items")
				)
			),
			"success"
		)
	)
	if with_dependents:
		var owner_schema: GFConfigTableSchema = _schema(&"owners")
		var ref: GFConfigTableReference = GFConfigTableReference.new()
		ref.source_fields = ["id"]
		ref.target_table_name = &"items"
		owner_schema.references = [ref]
		assert_true(
			GFVariantData.get_option_bool(
				result.add_table(
					GFConfigPipelineTableIR.create(
						&"owners",
						"",
						&"json",
						[],
						owner_schema
					)
				),
				"success"
			)
		)
	assert_true(
		GFVariantData.get_option_bool(
			result.seal(),
			"success"
		)
	)
	return result


func _schema(table_name: StringName) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	schema.coerce_values = true
	for field: String in ["id", "name"]:
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		column.field_name = StringName(field)
		column.value_type = GFConfigTableColumn.ValueType.INT if field == "id" else GFConfigTableColumn.ValueType.STRING
		schema.columns.append(column)
	return schema


func _profile_path(csv: String, with_target: bool = false) -> String:
	var path: String = (
		"user://gf_diff_%d_%d.tres"
		% [Time.get_ticks_usec(), _paths.size()]
	)
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = path + ".csv"
	source.schema = _schema(&"items")
	profile.sources = [source]
	profile.output_path = path + ".output.tres"
	if with_target:
		var target: GFConfigPipelineConsumerTarget = GFConfigPipelineConsumerTarget.new()
		target.target_id = &"client"
		target.root_tables = ["items"]
		target.visible_fields = {
			"items": ["id"],
		}
		target.output_path = profile.output_path
		profile.consumer_targets = [target]
	_paths.append_array(
		[
			path,
			source.source_path,
			profile.output_path,
		]
	)
	_write(source.source_path, csv)
	assert_eq(
		ResourceSaver.save(profile, path),
		OK
	)
	return path


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var _written: bool = file.store_string(content)
		file.close()
