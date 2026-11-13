@tool
extends GutTest


const _SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")
var _paths: PackedStringArray = []


func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


func test_preview_is_read_only_and_ids_are_explicit_and_namespace_scoped() -> void:
	var empty: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty()
	var assignments: Dictionary = {
		"items": { "potion": 101 },
		"quests": { "first": 101 },
	}
	var preview: Dictionary = empty.preview(assignments)
	assert_true(
		GFVariantData.get_option_bool(preview, "success"),
		str(preview)
	)
	assert_eq(
		GFVariantData.get_option_array(preview, "changes").size(),
		2
	)
	assert_eq(
		empty.get_id("items", "potion"),
		0
	)
	var registered: GFConfigStableIDRegistry = empty.with_assignments(assignments)
	assert_not_null(registered)
	assert_eq(
		registered.get_id("items", "potion"),
		101
	)
	assert_eq(
		registered.get_id("quests", "first"),
		101
	)
	assignments["items"]["potion"] = 99
	assert_eq(
		registered.get_id("items", "potion"),
		101
	)
	assert_false(
		GFVariantData.get_option_bool(
			registered.preview(assignments),
			"success"
		)
	)


func test_wire_record_requires_actual_string_keys_and_format() -> void:
	var record: Dictionary = GFConfigStableIDRegistry.create_empty().to_record()
	record["format"] = &"gf.config.stable_ids"
	assert_null(GFConfigStableIDRegistry.from_record(record))
	record = {
		&"format": "gf.config.stable_ids",
		"format_version": 1,
		"tables": {},
	}
	assert_null(GFConfigStableIDRegistry.from_record(record))
	record = GFConfigStableIDRegistry.create_empty().to_record()
	record["tables"] = {
		"items": {
			"a": { &"id": "1", "state": "active" },
		},
	}
	assert_null(GFConfigStableIDRegistry.from_record(record))


func test_retired_symbols_and_ids_cannot_be_reused() -> void:
	var initial: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty().with_assignments(
		{
			"items": { "a": 1, "b": 2 },
		}
	)
	var retired: GFConfigStableIDRegistry = initial.with_assignments(
		{
			"items": { "b": 2 },
		}
	)
	assert_eq(
		retired.get_id("items", "a"),
		0
	)
	assert_eq(
		initial.get_id("items", "a"),
		1
	)
	assert_null(
		retired.with_assignments(
			{
				"items": { "a": 3, "b": 2 },
			}
		)
	)
	assert_null(
		retired.with_assignments(
			{
				"items": { "c": 1, "b": 2 },
			}
		)
	)
	var restored: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(JSON.stringify(retired.to_record()))
	assert_not_null(restored)
	assert_null(
		restored.with_assignments(
			{
				"items": { "c": 1 },
			}
		)
	)


func test_strict_records_duplicate_ids_and_invalid_assignments_fail() -> void:
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty()
	assert_null(
		registry.with_assignments(
			{
				"t": { "a": 1, "b": 1 },
			}
		)
	)
	assert_null(
		registry.with_assignments(
			{
				"t": { "a": 1.0 },
			}
		)
	)
	assert_null(
		registry.with_assignments(
			{
				"t": { "a": "1" },
			}
		)
	)
	assert_null(
		registry.with_assignments(
			{
				"t": { " a": 1 },
			}
		)
	)
	assert_null(
		registry.with_assignments(
			{
				"t": { "a": 2147483648 },
			}
		)
	)
	var record: Dictionary = registry.to_record()
	record["tables"] = {
		"t": {
			"a": { "id": "01", "state": "active" },
		},
	}
	assert_null(GFConfigStableIDRegistry.from_record(record))
	record["tables"] = {
		"t": {
			"a": {
				"id": "1",
				"state": "active",
				"extra": true,
			},
		},
	}
	assert_null(GFConfigStableIDRegistry.from_record(record))


func test_build_and_dry_export_never_register_but_explicit_export_commits() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var build: Dictionary = pipeline.build_profile(profile)
	assert_true(
		GFVariantData.get_option_bool(build, "success"),
		str(build.get("error"))
	)
	assert_false(FileAccess.file_exists(profile.stable_id_registry_path))
	var preview: Dictionary = pipeline.export_profile(
		profile,
		{ "dry_run": true }
	)
	assert_true(
		GFVariantData.get_option_bool(preview, "success"),
		str(preview.get("error"))
	)
	assert_false(FileAccess.file_exists(profile.stable_id_registry_path))
	assert_false(FileAccess.file_exists(profile.output_path))
	assert_false(
		GFVariantData.get_option_bool(
			pipeline.export_profile(profile),
			"success"
		)
	)
	assert_false(FileAccess.file_exists(profile.output_path))
	var exported: Dictionary = pipeline.export_profile(
		profile,
		{ "register_ids": true }
	)
	assert_true(
		GFVariantData.get_option_bool(exported, "success"),
		str(exported.get("error"))
	)
	assert_true(FileAccess.file_exists(profile.output_path))
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(FileAccess.get_file_as_string(profile.stable_id_registry_path))
	assert_not_null(registry)
	if registry != null:
		assert_eq(
			registry.get_id("items", "potion"),
			1
		)
	assert_true(
		GFVariantData.get_option_bool(
			pipeline.export_profile(profile),
			"success"
		)
	)


func test_changed_input_after_preview_blocks_export_without_touching_files() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	assert_true(
		GFVariantData.get_option_bool(
			pipeline.export_profile(
				profile,
				{ "register_ids": true }
			),
			"success"
		)
	)
	var captured: Dictionary = GFConfigPipelineArtifactManifest.new().capture_inputs(profile)
	var old_output: String = FileAccess.get_sha256(profile.output_path)
	var old_registry: String = FileAccess.get_sha256(profile.stable_id_registry_path)
	_write(
		profile.sources[0].source_path,
		"id,symbol,label\n1,potion,changed\n"
	)
	var result: Dictionary = pipeline.export_profile(
		profile,
		{ "expected_input_digest": captured["digest"] }
	)
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_eq(
		FileAccess.get_sha256(profile.output_path),
		old_output
	)
	assert_eq(
		FileAccess.get_sha256(profile.stable_id_registry_path),
		old_registry
	)


func test_registration_uses_full_author_tables_even_when_target_hides_symbols() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var target: GFConfigPipelineConsumerTarget = GFConfigPipelineConsumerTarget.new()
	target.target_id = &"client"
	target.root_tables = ["items"]
	target.visible_fields = {
		"items": PackedStringArray(["id", "label"]),
	}
	target.output_path = profile.output_path
	profile.consumer_targets = [target]
	profile.default_consumer_target = &"client"
	var result: Dictionary = GFConfigPipeline.new().export_profile(
		profile,
		{ "register_ids": true }
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result.get("error"))
	)
	var database: GFConfigDatabaseResource = result["database"]
	if database == null:
		return
	assert_false(database.get_table_resource(&"items").records[0].has("symbol"))
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(FileAccess.get_file_as_string(profile.stable_id_registry_path))
	assert_eq(
		registry.get_id("items", "potion"),
		1
	)


func test_registry_write_failure_rolls_back_both_registry_and_artifact() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	assert_true(
		GFVariantData.get_option_bool(
			pipeline.export_profile(
				profile,
				{ "register_ids": true }
			),
			"success"
		)
	)
	var old_output: String = FileAccess.get_sha256(profile.output_path)
	var old_registry: String = FileAccess.get_sha256(profile.stable_id_registry_path)
	_write(
		profile.sources[0].source_path,
		"id,symbol,label\n1,potion,Potion\n2,ether,Ether\n"
	)
	var _configured: GFConfigPipeline = pipeline.configure_stages(
		null,
		null,
		null,
		null,
		_RejectRegistryCommit.new()
	)
	var result: Dictionary = pipeline.export_profile(
		profile,
		{ "register_ids": true }
	)
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_eq(
		FileAccess.get_sha256(profile.output_path),
		old_output
	)
	assert_eq(
		FileAccess.get_sha256(profile.stable_id_registry_path),
		old_registry
	)


func test_disabled_manifest_dry_run_cannot_authorize_id_registration() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var result: Dictionary = GFConfigPipeline.new().export_profile(
		profile,
		{
			"manifest_options": { "dry_run": true },
		}
	)
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_false(FileAccess.file_exists(profile.stable_id_registry_path))
	assert_false(FileAccess.file_exists(profile.output_path))


func test_explicit_restoration_keeps_original_identity_and_is_idempotent() -> void:
	var initial: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty().with_assignments(
		{
			"items": { "potion": 1 },
		}
	)
	var retired: GFConfigStableIDRegistry = initial.with_assignments({})
	var assignments: Dictionary = {
		"items": { "potion": 1 },
	}
	assert_null(retired.with_assignments(assignments))
	var options: Dictionary = {
		"restorations": {
			"items": { "potion": "1" },
		},
	}
	var preview: Dictionary = retired.preview(assignments, options)
	assert_true(GFVariantData.get_option_bool(preview, "success"))
	assert_eq(
		GFVariantData.get_option_array(preview, "changes"),
		[
			{
				"table": "items",
				"symbol": "potion",
				"id": 1,
				"kind": "restore",
			},
		]
	)
	assert_eq(
		retired.get_id("items", "potion"),
		0
	)
	var restored: GFConfigStableIDRegistry = retired.with_assignments(assignments, options)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(
		restored.get_id("items", "potion"),
		1
	)
	var repeated: Dictionary = restored.preview(assignments, options)
	assert_true(GFVariantData.get_option_bool(repeated, "success"))
	assert_true(GFVariantData.get_option_array(repeated, "changes").is_empty())
	assert_null(
		restored.with_assignments(
			{ "items": {} },
			options
		)
	)
	var round_trip: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(JSON.stringify(restored.to_record()))
	assert_not_null(round_trip)
	assert_null(
		restored.with_assignments(
			{
				"items": { "different": 1 },
			}
		)
	)


func test_restoration_rejects_noncanonical_or_different_identity_without_partial_changes() -> void:
	var initial: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty().with_assignments(
		{
			"items": { "potion": 1 },
		}
	)
	var retired: GFConfigStableIDRegistry = initial.with_assignments({})
	var assignments: Dictionary = {
		"items": { "potion": 1, "new_item": 2 },
	}
	for invalid_id: Variant in [
		"01",
		"+1",
		"1.0",
		"2",
		1,
		1.0,
		&"1",
	]:
		var options: Dictionary = {
			"restorations": {
				"items": { "potion": invalid_id },
			},
		}
		var preview: Dictionary = retired.preview(assignments, options)
		assert_false(GFVariantData.get_option_bool(preview, "success"))
		assert_true(GFVariantData.get_option_array(preview, "changes").is_empty())
		assert_null(retired.with_assignments(assignments, options))
	for invalid_restorations: Dictionary in [
		{
			"items": { "other": "1" },
		},
		{
			"other_table": { "potion": "1" },
		},
		{
			"items": { "new_item": "2" },
		},
	]:
		assert_null(
			retired.with_assignments(
				assignments,
				{ "restorations": invalid_restorations }
			)
		)
	assert_eq(
		retired.get_id("items", "potion"),
		0
	)


func test_scoped_reconciliation_preserves_other_tables_and_full_mode_stays_compatible() -> void:
	var initial: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty().with_assignments(
		{
			"items": { "potion": 1 },
			"quests": { "first": 7 },
		}
	)
	var assignments: Dictionary = { "items": {} }
	var options: Dictionary = {
		"scope_tables": ["items"],
	}
	var scoped: GFConfigStableIDRegistry = initial.with_assignments(assignments, options)
	assert_not_null(scoped)
	if scoped == null:
		return
	assert_eq(
		scoped.get_id("items", "potion"),
		0
	)
	assert_eq(
		scoped.get_id("quests", "first"),
		7
	)
	assert_eq(
		GFVariantData.get_option_array(
			initial.preview(assignments, options),
			"changes"
		).size(),
		1
	)
	var full: GFConfigStableIDRegistry = initial.with_assignments(assignments)
	assert_eq(
		full.get_id("quests", "first"),
		0
	)
	var explicit_full: GFConfigStableIDRegistry = initial.with_assignments(
		assignments,
		{ "scope_tables": [] }
	)
	assert_eq(
		explicit_full.to_record(),
		full.to_record()
	)
	assert_null(
		initial.with_assignments(
			assignments,
			{
				"scope_tables": ["items"],
				"restorations": {
					"quests": { "first": "7" },
				},
			}
		)
	)


func test_scope_requires_exact_tables_and_never_treats_missing_table_as_empty() -> void:
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty()
	var assignments: Dictionary = {
		"items": { "potion": 1 },
	}
	for invalid_options: Dictionary in [
		{
			"scope_tables": ["items", "quests"],
		},
		{
			"scope_tables": ["items", "items"],
		},
		{
			"scope_tables": [&"items"],
		},
		{
			"scope_tables": [" items"],
		},
		{ "scope_tables": "items" },
		{ "restorations": [] },
		{ "strict": false },
	]:
		var preview: Dictionary = registry.preview(assignments, invalid_options)
		assert_false(GFVariantData.get_option_bool(preview, "success"))
		assert_true(GFVariantData.get_option_array(preview, "changes").is_empty())
	assert_null(
		registry.with_assignments(
			{
				"items": { "potion": 1 },
				"quests": { "first": 7 },
			},
			{
				"scope_tables": ["items"],
			}
		)
	)


func test_profile_scope_and_restoration_are_copied_and_change_input_fingerprints() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	var helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	var original: Dictionary = helper.capture_inputs(profile)
	var original_manifest: Dictionary = helper.make_manifest("", profile)
	profile.stable_id_scope_tables = ["items"]
	var scoped: Dictionary = helper.capture_inputs(profile)
	var scoped_manifest: Dictionary = helper.make_manifest("", profile)
	profile.stable_id_restorations = {
		"items": { "potion": "1" },
	}
	var restoring: Dictionary = helper.capture_inputs(profile)
	var restoring_manifest: Dictionary = helper.make_manifest("", profile)
	for capture: Dictionary in [
		original,
		scoped,
		restoring,
	]:
		assert_true(GFVariantData.get_option_bool(capture, "success"))
	assert_ne(
		GFVariantData.get_option_string(original, "digest"),
		GFVariantData.get_option_string(scoped, "digest")
	)
	assert_ne(
		GFVariantData.get_option_string(scoped, "digest"),
		GFVariantData.get_option_string(restoring, "digest")
	)
	assert_ne(
		GFVariantData.get_option_string(original_manifest, "profile_digest"),
		GFVariantData.get_option_string(scoped_manifest, "profile_digest")
	)
	assert_ne(
		GFVariantData.get_option_string(scoped_manifest, "profile_digest"),
		GFVariantData.get_option_string(restoring_manifest, "profile_digest")
	)
	var copied: GFConfigPipelineProfile = profile.duplicate_profile()
	assert_not_null(copied)
	if copied == null:
		return
	profile.stable_id_scope_tables.clear()
	profile.stable_id_restorations["items"]["potion"] = "2"
	assert_eq(
		copied.stable_id_scope_tables,
		["items"]
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(copied.stable_id_restorations, "items"),
			"potion"
		),
		"1"
	)


func test_profile_restoration_preview_and_export_keep_unselected_tables() -> void:
	var profile: GFConfigPipelineProfile = _profile_with_retired_potion()
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var old_registry: String = FileAccess.get_sha256(profile.stable_id_registry_path)
	var build: Dictionary = pipeline.build_profile(profile)
	assert_true(GFVariantData.get_option_bool(build, "success"))
	var plan: Dictionary = GFVariantData.get_option_dictionary(build, "stable_id_plan")
	var changes: Array = GFVariantData.get_option_array(plan, "changes")
	assert_eq(
		changes.size(),
		1
	)
	if changes.size() == 1:
		var change: Dictionary = changes[0]
		assert_eq(
			GFVariantData.get_option_string(change, "kind"),
			"restore"
		)
	assert_true(
		GFVariantData.get_option_bool(
			pipeline.export_profile(
				profile,
				{ "dry_run": true, "register_ids": true }
			),
			"success"
		)
	)
	assert_eq(
		FileAccess.get_sha256(profile.stable_id_registry_path),
		old_registry
	)
	assert_false(FileAccess.file_exists(profile.output_path))
	assert_false(
		GFVariantData.get_option_bool(
			pipeline.export_profile(profile),
			"success"
		)
	)
	var exported: Dictionary = pipeline.export_profile(
		profile,
		{ "register_ids": true }
	)
	assert_true(
		GFVariantData.get_option_bool(exported, "success"),
		str(exported.get("error"))
	)
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(FileAccess.get_file_as_string(profile.stable_id_registry_path))
	assert_eq(
		registry.get_id("items", "potion"),
		1
	)
	assert_eq(
		registry.get_id("quests", "first"),
		7
	)
	assert_true(
		GFVariantData.get_option_bool(
			pipeline.export_profile(profile),
			"success"
		)
	)


func test_scope_or_restoration_changes_reject_old_preview_without_writes() -> void:
	var profile: GFConfigPipelineProfile = _profile_with_retired_potion()
	var captured: Dictionary = GFConfigPipelineArtifactManifest.new().capture_inputs(profile)
	assert_true(GFVariantData.get_option_bool(captured, "success"))
	var old_registry: String = FileAccess.get_sha256(profile.stable_id_registry_path)
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	profile.stable_id_scope_tables = []
	var changed_scope: Dictionary = pipeline.export_profile(
		profile,
		{ "register_ids": true, "expected_input_digest": captured["digest"] }
	)
	assert_false(GFVariantData.get_option_bool(changed_scope, "success"))
	profile.stable_id_scope_tables = ["items"]
	profile.stable_id_restorations = {}
	var changed_restoration: Dictionary = pipeline.export_profile(
		profile,
		{ "register_ids": true, "expected_input_digest": captured["digest"] }
	)
	assert_false(GFVariantData.get_option_bool(changed_restoration, "success"))
	assert_false(FileAccess.file_exists(profile.output_path))
	assert_eq(
		FileAccess.get_sha256(profile.stable_id_registry_path),
		old_registry
	)


func test_restoration_commit_failure_and_declaration_mutation_roll_back_artifacts() -> void:
	for mutate_declaration: bool in [false, true]:
		var profile: GFConfigPipelineProfile = _profile_with_retired_potion()
		var old_registry: String = FileAccess.get_sha256(profile.stable_id_registry_path)
		var commit_stage: GFConfigPipelineCommitStage = _RejectRegistryCommit.new()
		if mutate_declaration:
			var mutating_stage: _MutateRestorationCommit = _MutateRestorationCommit.new()
			mutating_stage.source_profile = profile
			commit_stage = mutating_stage
		var pipeline: GFConfigPipeline = GFConfigPipeline.new()
		var _configured: GFConfigPipeline = pipeline.configure_stages(
			null,
			null,
			null,
			null,
			commit_stage
		)
		var result: Dictionary = pipeline.export_profile(
			profile,
			{ "register_ids": true }
		)
		assert_false(GFVariantData.get_option_bool(result, "success"))
		assert_false(FileAccess.file_exists(profile.output_path))
		assert_eq(
			FileAccess.get_sha256(profile.stable_id_registry_path),
			old_registry
		)


func test_saved_profile_restoration_reaches_workbench_command_runner_and_manifest() -> void:
	var profile: GFConfigPipelineProfile = _profile_with_retired_potion()
	var path: String = profile.output_path + ".profile.tres"
	var manifest_path: String = profile.output_path + ".manifest.json"
	_paths.append_array([path, manifest_path])
	assert_eq(
		ResourceSaver.save(profile, path),
		OK
	)
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	assert_true(session.load_profile(path))
	assert_eq(
		session.get_profile().stable_id_scope_tables,
		["items"]
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(
				session.get_profile().stable_id_restorations,
				"items"
			),
			"potion"
		),
		"1"
	)
	var preview: Dictionary = session.run_operation(
		"export",
		{ "dry_run": true }
	)
	assert_true(
		GFVariantData.get_option_bool(preview, "success"),
		str(preview)
	)
	assert_true(session.make_arguments("register-ids", {}).has("--expected-input-digest"))
	var registered: Dictionary = session.run_operation(
		"register-ids",
		{ "write_manifest": true }
	)
	assert_true(
		GFVariantData.get_option_bool(registered, "success"),
		str(registered)
	)
	var repeated: Dictionary = GFConfigPipelineCommand.new().run(
		session.make_arguments(
			"export",
			{ "changed_only": true, "write_manifest": true }
		)
	)
	assert_true(GFVariantData.get_option_bool(repeated, "success"))
	assert_true(
		GFVariantData.get_option_bool(
			GFVariantData.get_option_dictionary(repeated, "runner_result"),
			"skipped"
		)
	)
	var registry: GFConfigStableIDRegistry = GFConfigStableIDRegistry.from_json(FileAccess.get_file_as_string(profile.stable_id_registry_path))
	assert_eq(
		registry.get_id("items", "potion"),
		1
	)
	assert_eq(
		registry.get_id("quests", "first"),
		7
	)


func test_stable_id_scope_and_restoration_require_an_enabled_registry() -> void:
	var profile: GFConfigPipelineProfile = _profile()
	profile.stable_id_registry_path = ""
	profile.stable_id_bindings = {}
	profile.stable_id_scope_tables = ["items"]
	assert_false(
		GFVariantData.get_option_bool(
			GFConfigPipeline.new().build_profile(profile),
			"success"
		)
	)
	profile.stable_id_scope_tables = []
	profile.stable_id_restorations = {
		"items": { "potion": "1" },
	}
	assert_false(
		GFVariantData.get_option_bool(
			GFConfigPipeline.new().build_profile(profile),
			"success"
		)
	)


func _profile_with_retired_potion() -> GFConfigPipelineProfile:
	var profile: GFConfigPipelineProfile = _profile()
	var initial: GFConfigStableIDRegistry = GFConfigStableIDRegistry.create_empty().with_assignments(
		{
			"items": { "potion": 1 },
			"quests": { "first": 7 },
		}
	)
	var retired: GFConfigStableIDRegistry = initial.with_assignments(
		{ "items": {} },
		{
			"scope_tables": ["items"],
		}
	)
	_write(
		profile.stable_id_registry_path,
		JSON.stringify(retired.to_record())
	)
	profile.stable_id_scope_tables = ["items"]
	profile.stable_id_restorations = {
		"items": { "potion": "1" },
	}
	return profile


func _profile() -> GFConfigPipelineProfile:
	var prefix: String = (
		"user://gf_stable_%d_%d"
		% [Time.get_ticks_usec(), _paths.size()]
	)
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"items"
	source.source_path = prefix + ".csv"
	source.schema = GFConfigTableSchema.new()
	source.schema.table_name = &"items"
	source.schema.coerce_values = true
	source.schema.require_unique_id = true
	for field_name: String in [
		"id",
		"symbol",
		"label",
	]:
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		column.field_name = StringName(field_name)
		column.value_type = GFConfigTableColumn.ValueType.INT if field_name == "id" else GFConfigTableColumn.ValueType.STRING
		column.required = true
		source.schema.columns.append(column)
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.sources = [source]
	profile.output_path = prefix + ".tres"
	profile.stable_id_registry_path = prefix + ".ids.json"
	profile.stable_id_bindings = {
		"items": { "symbol_field": "symbol", "id_field": "id" },
	}
	_paths.append_array(
		[
			source.source_path,
			profile.output_path,
			profile.stable_id_registry_path,
		]
	)
	_write(source.source_path, "id,symbol,label\n1,potion,Potion\n")
	return profile


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var _written: bool = file.store_string(content)
		file.close()


class _RejectRegistryCommit extends GFConfigPipelineCommitStage:
	func write_stable_ids(plan: Dictionary) -> bool:
		var _written: bool = super.write_stable_ids(plan)
		return false


class _MutateRestorationCommit extends GFConfigPipelineCommitStage:
	var source_profile: GFConfigPipelineProfile


	func write_stable_ids(plan: Dictionary) -> bool:
		var written: bool = super.write_stable_ids(plan)
		source_profile.stable_id_restorations = {}
		return written
