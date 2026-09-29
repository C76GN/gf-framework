@tool

extends GutTest


# --- 常量 ---

const _PRESET_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_preset.gd")
const _SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")
const _DOCK_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_dock.gd")
const _FORM_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_schema_form.gd")
const _WORKER_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_preview_worker.gd")
const _TASK_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_background_request_task.gd")


# --- 内部类型 ---

class LegacyLocationCopyStage extends GFConfigPipelineValidationStage:
	func _duplicate_row_locations(value: Variant) -> Array:
		return GFVariantData.as_array(GFVariantData.duplicate_variant(value))


class MutatingContextRule extends GFConfigValidationRule:

	func _validate_value(_value: Variant, context: Dictionary, _report: Dictionary) -> void:
		context["line"] = 999
		var values: Array = GFVariantData.as_array(context.get("supported_values"))
		if not values.is_empty():
			values[0] = "changed by callback"


# --- 私有变量 ---

var _root_path: String
var _files: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_root_path = "user://config_workbench_%d" % Time.get_ticks_usec()
	var _mkdir: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_root_path))


func after_each() -> void:
	_remove_tree(_root_path)
	_files.clear()


# --- 测试 ---

func test_preset_is_copied_and_has_explicit_unique_id() -> void:
	var first: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile("res://items.csv")
	var second: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile("res://items.csv")
	assert_true(GFVariantData.get_option_bool(first.sources[0].schema_options, "typed_headers"))
	assert_true(GFVariantData.get_option_bool(first.sources[0].schema_options, "require_unique_id"))
	assert_true(GFVariantData.get_option_bool(first.access_options, "include_typed_records"))
	first.sources[0].schema_options["typed_headers"] = false
	assert_true(GFVariantData.get_option_bool(second.sources[0].schema_options, "typed_headers"))
	assert_eq(first.access_provider_accessor, "null")
	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(first.metadata, "gf_config_preset"), "preset_version"), 1)
	var malformed: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	malformed.sources.append(null)
	assert_true(_PRESET_SCRIPT.make_read_example(malformed).contains("valid table source"))


func test_draft_save_then_export_and_cli_use_same_profile() -> void:
	var source_path: String = _write("items.csv", "id:int!,name:string\n1,Potion\n")
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(source_path, "inventory", _root_path.path_join("generated"))
	assert_true(GFVariantData.get_option_bool(session.get_state(), "dirty"))
	assert_false(GFVariantData.get_option_bool(session.run_operation("build", {}), "success"))
	var path: String = _root_path.path_join("profile.tres")
	assert_true(GFVariantData.get_option_bool(session.save_profile(path), "success"))
	assert_false(GFVariantData.get_option_bool(session.get_state(), "dirty"))
	var result: Dictionary = session.run_operation("export", { "write_manifest": true })
	assert_true(GFVariantData.get_option_bool(result, "success"), str(result.get("error")))
	var profile: GFConfigPipelineProfile = session.get_profile()
	assert_true(FileAccess.file_exists(profile.output_path))
	assert_true(FileAccess.file_exists(profile.access_output_path))
	assert_true(FileAccess.file_exists(profile.output_path + ".manifest.json"))
	var provider: GFResourceConfigProvider = _make_provider(GFVariantData.get_option_dictionary(result, "runner_result").get("database"))
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "name"), "Potion")
	var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
	var cli: Dictionary = command.run(session.make_arguments("export", { "dry_run": true, "write_manifest": true }))
	assert_true(GFVariantData.get_option_bool(cli, "success"))
	var reader: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	assert_true(reader.load_profile(path))
	reader.get_profile().sources[0].table_name = &"different"
	reader.mark_changed()
	assert_eq(session.get_profile().sources[0].table_name, &"")
	var _rewritten_3756: String = _write("items.csv", "id:int!,name:string\n1,Changed\n")
	session.refresh_freshness()
	assert_true(GFVariantData.get_option_bool(session.get_state(), "stale"))


func test_draft_rejects_external_profile_change_and_existing_save_as() -> void:
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(_write("items.csv", "id:int!\n1\n"), "items", _root_path)
	var path: String = _root_path.path_join("profile.tres")
	assert_true(GFVariantData.get_option_bool(session.save_profile(path), "success"))
	var _rewritten_4274: String = _write("profile.tres", FileAccess.get_file_as_string(path) + "\n; external edit\n")
	assert_false(GFVariantData.get_option_bool(session.run_operation("export", {}), "success"))
	assert_false(FileAccess.file_exists(session.get_profile().output_path))
	session.mark_changed()
	assert_false(GFVariantData.get_option_bool(session.save_profile(path), "success"))
	var occupied: String = _write("occupied.tres", "user text")
	assert_false(GFVariantData.get_option_bool(session.save_profile(occupied), "success"))
	assert_eq(FileAccess.get_file_as_string(occupied), "user text")
	for rejected: String in ["res://addons/gf/workbench_test.tres", "res://.godot/workbench_test.tres", _root_path.path_join("../escaped.tres"), "C:/config_profile.tres"]:
		assert_false(GFVariantData.get_option_bool(session.save_profile(rejected), "success"), rejected)


func test_preset_reapply_is_explicit_and_preserves_nonmanaged_values() -> void:
	var profile: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile("res://items.csv")
	profile.sources[0].schema_options = { "typed_headers": false, "custom": 42 }
	profile.access_options["custom"] = true
	profile.output_path = "res://my/database.tres"
	var explicit_schema: GFConfigTableSchema = GFConfigTableSchema.new()
	explicit_schema.id_field = &"custom_id"
	profile.sources[0].schema = explicit_schema
	assert_gt(_PRESET_SCRIPT.describe_changes(profile).size(), 0)
	assert_false(GFVariantData.get_option_bool(profile.sources[0].schema_options, "typed_headers"))
	_PRESET_SCRIPT.apply_managed_values(profile)
	assert_true(GFVariantData.get_option_bool(profile.sources[0].schema_options, "typed_headers"))
	assert_eq(GFVariantData.get_option_int(profile.sources[0].schema_options, "custom"), 42)
	assert_true(GFVariantData.get_option_bool(profile.access_options, "custom"))
	assert_eq(profile.output_path, "res://my/database.tres")
	assert_same(profile.sources[0].schema, explicit_schema)
	assert_eq(explicit_schema.id_field, &"custom_id")


func test_dry_run_does_not_create_output_directory() -> void:
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(_write("items.csv", "id:int!\n1\n"), "items", _root_path.path_join("absent/generated"))
	assert_true(GFVariantData.get_option_bool(session.save_profile(_root_path.path_join("profile.tres")), "success"))
	var result: Dictionary = session.run_operation("export", { "dry_run": true, "write_manifest": true })
	assert_true(GFVariantData.get_option_bool(result, "success"), str(result))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_root_path.path_join("absent"))))


func test_strict_failure_preserves_honest_written_artifact_status() -> void:
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(_write("items.csv", "id,name\n1,Potion\n"), "items", _root_path.path_join("generated"))
	var profile: GFConfigPipelineProfile = session.get_profile()
	profile.sources[0].infer_schema = false
	profile.sources[0].schema_options.clear()
	profile.access_output_path = ""
	profile.build_options["validate_database"] = false
	assert_true(GFVariantData.get_option_bool(session.save_profile(_root_path.path_join("profile.tres")), "success"))
	var result: Dictionary = session.run_operation("export", { "strict": true })
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_eq(GFVariantData.get_option_int(result, "exit_code"), 1)
	assert_true(GFVariantData.get_option_bool(GFVariantData.get_option_dictionary(result, "runner_result"), "success"), str(result))
	assert_true(GFVariantData.get_option_bool(GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(result, "runner_result"), "save_result"), "written"))
	assert_true(FileAccess.file_exists(profile.output_path))


func test_xlsx_preview_sheet_cached_formula_and_typed_header_location() -> void:
	var path: String = _write_xlsx("power:float")
	var options: Dictionary = { "sheet_name": "Balance", "header_row": 2 }
	var preview: Dictionary = _WORKER_SCRIPT.new().run_request({ "source_path": path, "parse_options": options, "source_format": "xlsx", "table_name": "items" })
	assert_true(GFVariantData.get_option_bool(preview, "success"), str(preview))
	assert_eq(GFVariantData.get_option_string(preview, "sheet_name"), "Balance")
	assert_eq(str(preview["data"][0]["power:float"]), "4")
	var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(path).sources[0]
	source.parse_options = options
	assert_true(GFVariantData.get_option_bool(GFConfigPipeline.new().build_table(source), "success"))
	var profile: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile(path, "xlsx", _root_path.path_join("generated"))
	profile.sources[0].parse_options = options
	var exported: Dictionary = GFConfigPipeline.new().export_profile(profile)
	assert_true(GFVariantData.get_option_bool(exported, "success"), str(exported))
	var provider: GFResourceConfigProvider = _make_provider(exported.get("database"))
	assert_eq(GFVariantData.get_option_float(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "power"), 4.0)
	var _rewritten_8555: String = _write_xlsx("power:unknown")
	var failed: Dictionary = GFConfigPipeline.new().build_table(source)
	assert_false(GFVariantData.get_option_bool(failed, "success"))
	assert_eq(GFVariantData.get_option_int(_first_issue(failed), "line"), 2)
	assert_eq(GFVariantData.get_option_int(_first_issue(failed), "column"), 2)


func test_sample_is_create_only_and_exports_readable_records() -> void:
	var created: Dictionary = _PRESET_SCRIPT.create_sample(_root_path)
	assert_true(GFVariantData.get_option_bool(created, "ok"), str(created))
	var source_path: String = _root_path.path_join("data/config/items.csv")
	var baseline: String = FileAccess.get_sha256(source_path)
	assert_false(GFVariantData.get_option_bool(_PRESET_SCRIPT.create_sample(_root_path), "ok"))
	assert_eq(FileAccess.get_sha256(source_path), baseline)
	var result: Dictionary = GFConfigPipelineRunner.new().export_profile_path(GFVariantData.get_option_string(created, "profile_path"))
	assert_true(GFVariantData.get_option_bool(result, "success"), str(result.get("error")))
	var provider: GFResourceConfigProvider = _make_provider(result.get("database"))
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(provider.get_record(&"items", 1)), "name"), "Potion")
	assert_true(FileAccess.file_exists(GFVariantData.get_option_string(created, "scene_path")))
	var scene: PackedScene = load(GFVariantData.get_option_string(created, "scene_path"))
	var label: Label = scene.instantiate()
	add_child_autofree(label)
	assert_true(label.text.contains("Potion"))


func test_typed_header_error_uses_physical_header_and_original_column() -> void:
	var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile("res://items.csv").sources[0]
	source.parse_options = { "header_row": 2, "comment_column_prefixes": ["#"] }
	var result: Dictionary = GFConfigPipeline.new().build_table_from_text(source, "note\n#note,id:int!,power:unknown\na,1,2\n")
	assert_false(GFVariantData.get_option_bool(result, "success"))
	var issue: Dictionary = result["report"]["issues"][0]
	assert_eq(GFVariantData.get_option_int(issue, "line"), 2)
	assert_eq(GFVariantData.get_option_int(issue, "column"), 3)
	assert_eq(GFVariantData.get_option_string_name(issue, "field"), &"power:unknown")


func test_type_row_error_preserves_physical_row_after_comment_filtering() -> void:
	var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile("res://items.csv").sources[0]
	source.schema_options["typed_header_type_row"] = true
	source.parse_options = { "comment_row_prefixes": ["#"] }
	var result: Dictionary = GFConfigPipeline.new().build_table_from_text(source, "id,power\n#comment\nint!,unknown\n1,2\n")
	assert_false(GFVariantData.get_option_bool(result, "success"))
	var issue: Dictionary = result["report"]["issues"][0]
	assert_eq(GFVariantData.get_option_int(issue, "line"), 3)
	assert_eq(GFVariantData.get_option_int(issue, "column"), 2)


func test_preset_rejects_duplicate_ids_after_conversion() -> void:
	var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile("res://items.csv").sources[0]
	var result: Dictionary = GFConfigPipeline.new().build_table_from_text(source, "id:int!,name:string\n01,First\n1,Second\n")
	assert_false(GFVariantData.get_option_bool(result, "success"))
	var issues: Array = result["report"]["issues"]
	assert_true(issues.any(func(issue: Dictionary) -> bool: return issue.get("kind") == "duplicate_id" and issue.get("line") == 3))


func test_location_copy_matches_previous_report_and_preserves_layout_input() -> void:
	var path: String = _write("items.csv", "id:int!,power:float\n1,2.5\n1,3.0\n")
	var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(path).sources[0]
	var layout: Dictionary = GFConfigPipelineLayoutStage.new().decode_source(source, GFConfigPipelineReaderStage.new().read_source(source))
	var before: Dictionary = layout.duplicate(true)
	var expected: Dictionary = LegacyLocationCopyStage.new().compile_table(source, layout)
	var actual: Dictionary = GFConfigPipelineValidationStage.new().compile_table(source, layout)
	var equal_reports: bool = actual.get("report") == expected.get("report")
	var input_unchanged: bool = layout == before
	assert_true(equal_reports)
	assert_true(input_unchanged)
	assert_eq(GFVariantData.get_option_int(_first_issue(actual), "line"), 3)


func test_internal_row_view_does_not_expose_caller_context_to_rules() -> void:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.require_unique_id = true
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = &"id"
	column.value_type = GFConfigTableColumn.ValueType.INT
	column.validation_rules.append(MutatingContextRule.new())
	schema.columns.append(column)
	var options: Dictionary = { "supported_values": ["original"], "row_locations": [{ "line": 2, "fields": { "id": { "column": 1 } } }, { "line": 3, "fields": { "id": { "column": 1 } } }] }
	var before: Dictionary = options.duplicate(true)
	var report: Dictionary = schema.validate_table([{ "id": 1 }, { "id": 1 }], options)
	var unchanged: bool = options == before
	assert_true(unchanged)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var duplicate_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	assert_eq(GFVariantData.get_option_int(duplicate_issue, "line"), 3)
	assert_eq(GFVariantData.get_option_int(duplicate_issue, "column"), 1)


func test_schema_form_edits_draft_column_index_and_reference() -> void:
	var profile: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile("res://items.csv")
	var form: _FORM_SCRIPT = _FORM_SCRIPT.new()
	add_child_autofree(form)
	form.configure(profile, profile.sources[0])
	var create: Button = form.find_child("CreateSchema", true, false)
	create.pressed.emit()
	var add: Button = form.find_child("AddDefinition", true, false)
	add.pressed.emit()
	assert_eq(profile.sources[0].schema.columns.size(), 1)
	var name_field: GFEditorValueField = form.find_child("FieldName", true, false)
	name_field.value_changed.emit(&"id")
	assert_eq(profile.sources[0].schema.columns[0].field_name, &"id")
	var section: OptionButton = form.find_child("SchemaSection", true, false)
	section.select(1)
	section.item_selected.emit(1)
	add.pressed.emit()
	assert_eq(profile.sources[0].schema.indexes.size(), 1)
	profile.sources[0].schema.columns.append(null)
	section.select(2)
	section.item_selected.emit(2)
	add.pressed.emit()
	assert_eq(profile.sources[0].schema.references.size(), 1)
	assert_not_null(form.find_child("TargetTable", true, false))
	await get_tree().process_frame


func test_dock_exposes_complete_workflow_without_writing_settings() -> void:
	var before: Variant = ProjectSettings.get_setting("gf/config_pipeline/default_profile_path", null)
	var dock: VBoxContainer = _DOCK_SCRIPT.new()
	add_child_autofree(dock)
	for control_name: String in ["NewProfile", "CreateSample", "SaveProfile", "Sources", "SchemaEditor", "DataPreview", "Validate", "DryRun", "Export", "CopyCli", "ReadExample", "RecoverTransaction"]:
		assert_not_null(dock.find_child(control_name, true, false), control_name)
	var setting_unchanged: bool = ProjectSettings.get_setting("gf/config_pipeline/default_profile_path", null) == before
	assert_true(setting_unchanged)


func test_dock_reports_unsaved_profile_for_workspace_refresh_without_saving_on_revoke() -> void:
	var dock: _DOCK_SCRIPT = _DOCK_SCRIPT.new()
	add_child_autofree(dock)
	assert_true(dock.has_method("has_unsaved_workspace_changes"), "工作区刷新前必须能够发现配置草稿。")
	if not dock.has_method("has_unsaved_workspace_changes"):
		return
	var session_value: Variant = dock.get("_session")
	assert_true(session_value is _SESSION_SCRIPT)
	if not (session_value is _SESSION_SCRIPT):
		return
	var session: _SESSION_SCRIPT = session_value
	assert_false(dock.has_unsaved_workspace_changes())
	session.create_profile(_write("items.csv", "id:int!\n1\n"), "retained", _root_path.path_join("generated"))
	assert_true(dock.has_unsaved_workspace_changes())
	var path: String = _root_path.path_join("profile.tres")
	assert_false(FileAccess.file_exists(path), "发现草稿不应保存 Profile。")
	assert_true(GFVariantData.get_option_bool(session.save_profile(path), "success"))
	assert_false(dock.has_unsaved_workspace_changes())
	var saved_digest: String = FileAccess.get_sha256(path)
	var profile: GFConfigPipelineProfile = session.get_profile()
	profile.version = "unsaved revision"
	session.mark_changed()
	dock.set_editor_context(null)
	assert_same(session.get_profile(), profile)
	assert_true(dock.has_unsaved_workspace_changes())
	assert_eq(FileAccess.get_sha256(path), saved_digest, "撤销上下文只保留内存草稿，不隐式保存。")
	session.clear_profile()
	assert_false(dock.has_unsaved_workspace_changes())
	await get_tree().process_frame


func test_preview_worker_is_pure_bounded_and_cancellable() -> void:
	var path: String = _write("items.csv", "id:int!,name:string\n1,Potion\n")
	var request: Dictionary = { "generation": 7, "source_path": path, "source_format": "csv", "table_name": "items", "parse_options": {} }
	var task: GFEditorBackgroundRequestTask = _TASK_SCRIPT.new()
	var _configured: GFEditorBackgroundRequestTask = task.configure(_WORKER_SCRIPT.new(), request)
	assert_eq(task.start(), OK)
	while task.is_running():
		await get_tree().process_frame
	var result: Dictionary = task.wait_to_finish()
	assert_true(GFVariantData.get_option_bool(result, "success"))
	assert_eq(GFVariantData.get_option_int(result, "generation"), 7)
	assert_eq(GFVariantData.to_text(result["data"][0]["name:string"]), "Potion")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(result, "source_receipt"), "sha256"), FileAccess.get_sha256(path))
	var cancelled: _WORKER_SCRIPT = _WORKER_SCRIPT.new()
	cancelled.cancel()
	assert_true(GFVariantData.get_option_bool(cancelled.run_request(request), "cancelled"))


func test_background_preflight_rejects_over_budget_and_counts_keyed_json() -> void:
	var rows: Dictionary = {}
	for index: int in range(2001):
		rows[str(index)] = { "id": index, "value": index }
	var path: String = _write("items.json", JSON.stringify(rows))
	var source: Dictionary = { "source_path": path, "source_format": "json", "table_name": "items", "parse_options": {} }
	var preview: Dictionary = _WORKER_SCRIPT.new().run_request(source)
	assert_eq(GFVariantData.get_option_int(preview, "record_count"), 2001)
	assert_eq(GFVariantData.get_option_array(preview, "data").size(), 100)
	var preflight: Dictionary = _WORKER_SCRIPT.new().run_request({ "generation": 3, "sources": [source] })
	assert_false(GFVariantData.get_option_bool(preflight, "success"))
	assert_eq(GFVariantData.get_option_int(preflight, "generation"), 3)


func test_actual_pipeline_budget_is_cumulative_and_cli_rejects_before_writing() -> void:
	var first: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(_write("a.csv", "id:int!,name:string\n1,A\n")).sources[0]
	var second: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(_write("b.csv", "id:int!,name:string\n1,B\n")).sources[0]
	var result: Dictionary = GFConfigPipeline.new().build_database([first, second], { "max_validation_cells": 3 })
	assert_false(GFVariantData.get_option_bool(result, "success"))
	assert_eq(GFVariantData.get_option_string(_first_issue(result), "kind"), "validation_cell_budget_exceeded")
	var profile: GFConfigPipelineProfile = _PRESET_SCRIPT.make_profile(first.source_path, "budget", _root_path.path_join("generated"))
	profile.sources.append(second)
	var profile_path: String = _root_path.path_join("profile.tres")
	assert_eq(ResourceSaver.save(profile, profile_path), OK)
	var command: GFConfigPipelineCommand = GFConfigPipelineCommand.new()
	var cli: Dictionary = command.run(["--profile", profile_path, "--max-validation-cells", "3", "--max-source-bytes", "200"])
	assert_false(GFVariantData.get_option_bool(cli, "success"))
	assert_false(FileAccess.file_exists(profile.output_path))
	assert_false(GFVariantData.get_option_bool(command.run(["--profile", profile_path, "--max-validation-cells", "bad"]), "success"))


func test_reference_form_survives_save_and_reports_missing_target_location() -> void:
	var source_path: String = _write("items.csv", "id,owner\n1,99\n")
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(source_path, "references", _root_path.path_join("generated"))
	var profile: GFConfigPipelineProfile = session.get_profile()
	var source: GFConfigPipelineTableSource = profile.sources[0]
	source.schema_options["typed_headers"] = false
	source.schema = GFConfigTableSchema.new()
	source.schema.coerce_values = true
	for field_name: StringName in [&"id", &"owner"]:
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		column.field_name = field_name
		column.value_type = GFConfigTableColumn.ValueType.INT
		source.schema.columns.append(column)
	var target: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(_write("owners.csv", "id:int!\n2\n")).sources[0]
	profile.sources.append(target)
	var form: _FORM_SCRIPT = _FORM_SCRIPT.new()
	add_child_autofree(form)
	form.configure(profile, source)
	var section: OptionButton = form.find_child("SchemaSection", true, false)
	section.select(2)
	section.item_selected.emit(2)
	var add: Button = form.find_child("AddDefinition", true, false)
	add.pressed.emit()
	var fields: GFEditorValueField = form.find_child("SourceFields", true, false)
	fields.value_changed.emit("owner")
	var target_picker: OptionButton = form.find_child("TargetTable", true, false)
	target_picker.select(2)
	target_picker.item_selected.emit(2)
	assert_true(GFVariantData.get_option_bool(session.save_profile(_root_path.path_join("references.tres")), "success"))
	var reopened: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	assert_true(reopened.load_profile(_root_path.path_join("references.tres")))
	assert_eq(reopened.get_profile().sources[0].schema.references[0].source_fields, PackedStringArray(["owner"]))
	assert_eq(reopened.get_profile().sources[0].schema.references[0].target_table_name, &"owners")
	var result: Dictionary = reopened.run_operation("build", {})
	assert_false(GFVariantData.get_option_bool(result, "success"))
	var issue: Dictionary = _first_issue(GFVariantData.get_option_dictionary(result, "runner_result"))
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "missing_reference")
	assert_eq(GFVariantData.get_option_string(issue, "source"), source_path)
	assert_eq(GFVariantData.get_option_int(issue, "line"), 2)
	assert_eq(GFVariantData.get_option_int(issue, "column"), 2)
	assert_false(FileAccess.file_exists(profile.output_path))
	await get_tree().process_frame


func test_source_growth_after_preflight_is_rejected_before_export() -> void:
	var source_path: String = _write("growing.csv", "id:int!,value:int\n1,1\n")
	var session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
	session.create_profile(source_path, "growth", _root_path.path_join("generated"))
	assert_true(GFVariantData.get_option_bool(session.save_profile(_root_path.path_join("growth.tres")), "success"))
	var preflight: Dictionary = _WORKER_SCRIPT.new().run_request({ "generation": 1, "sources": [{ "source_path": source_path, "source_format": "csv", "table_name": "growing", "parse_options": {} }] })
	assert_true(GFVariantData.get_option_bool(preflight, "success"))
	var lines: PackedStringArray = ["id:int!,value:int"]
	for row: int in range(2001):
		var _appended: bool = lines.append("%d,%d" % [row, row])
	var _rewritten: String = _write("growing.csv", "\n".join(lines))
	var result: Dictionary = session.run_operation("export", { "write_manifest": true })
	assert_false(GFVariantData.get_option_bool(result, "success"))
	var issue: Dictionary = _first_issue(GFVariantData.get_option_dictionary(result, "runner_result"))
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "validation_cell_budget_exceeded")
	assert_false(FileAccess.file_exists(session.get_profile().output_path))
	assert_false(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_root_path.path_join("generated"))))


# --- 私有/辅助方法 ---

func _make_provider(value: Variant) -> GFResourceConfigProvider:
	if value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = value
		return GFResourceConfigProvider.from_database(database)
	return null


func _first_issue(result: Dictionary) -> Dictionary:
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	return GFVariantData.as_dictionary(issues[0]) if not issues.is_empty() else {}


func _write(file_name: String, text: String) -> String:
	var path: String = _root_path.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _stored: bool = file.store_string(text)
	file.close()
	_files.append(path)
	return path


func _write_xlsx(power_header: String) -> String:
	var path: String = _root_path.path_join("items.xlsx")
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(packer.open(path), OK)
	var entries: Dictionary = {
		"xl/workbook.xml": '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Balance" sheetId="1" r:id="rId1"/></sheets></workbook>',
		"xl/_rels/workbook.xml.rels": '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
		"xl/worksheets/sheet1.xml": '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Notes</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>id:int!</t></is></c><c r="B2" t="inlineStr"><is><t>%s</t></is></c></row><row r="3"><c r="A3"><v>1</v></c><c r="B3"><f>2+2</f><v>4</v></c></row></sheetData></worksheet>' % power_header,
	}
	for entry_path: String in entries:
		assert_eq(packer.start_file(entry_path), OK)
		assert_eq(packer.write_file(GFVariantData.to_text(entries[entry_path]).to_utf8_buffer()), OK)
		assert_eq(packer.close_file(), OK)
	assert_eq(packer.close(), OK)
	return path


func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		var _remove_file: Error = directory.remove(file_name)
	for directory_name: String in directory.get_directories():
		_remove_tree(path.path_join(directory_name))
	var _remove_directory: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
