# 通过真实 Reader、Layout、Schema、Target 和导出入口验证结构化表格闭环。
extends GutTest


# --- 常量 ---

const _CSV_HEADER: String = "id,hp,type,damage,slow,key,weight\n"
const _CSV_VALID_ROWS: String = "1,10,fire,2.5,,red,3\n,,ice,,4,blue,6\n2,20,fire,1,,green,8\n"


# --- 私有变量 ---

var _paths: Array[String] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


# --- 测试 ---

func test_multiline_csv_build_normalizes_nested_polymorphic_values_and_keeps_origins() -> void:
	var source: GFConfigPipelineTableSource = _source(_CSV_VALID_ROWS)
	var declared: GFConfigTableSchema = source.schema
	var result: Dictionary = GFConfigPipeline.new().build_table(source)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var table: GFConfigTableResource = _table(result)
	assert_not_null(table)
	if table == null:
		return
	assert_eq(
		table.records,
		_expected_records()
	)
	assert_ne(
		table.schema,
		declared,
		"The delivered schema is isolated from the author's mutable declaration."
	)
	var ir: GFConfigPipelineTableIR = _ir(result)
	assert_not_null(ir)
	if ir == null:
		return
	assert_eq(
		ir.get_records(),
		_expected_records()
	)
	var source_map: Dictionary = ir.get_source_map()
	var locations: Array = GFVariantData.get_option_array(source_map, "row_locations")
	assert_eq(
		locations.size(),
		2
	)
	if locations.size() != 2:
		return
	var first: Dictionary = locations[0]
	var fields: Dictionary = first["fields"]
	var second_effect: Dictionary = fields["effects[1].slow"]
	var field_segments: Variant = second_effect["field_segments"]
	var effect_source: Variant = second_effect["source"]
	var effect_line: Variant = second_effect["line"]
	var effect_column: Variant = second_effect["column"]
	var effect_cell: Variant = second_effect["cell"]
	var segments_match: bool = field_segments is Array and field_segments == [
		"effects",
		1,
		"slow",
	]
	var source_matches: bool = effect_source is String and effect_source == source.source_path
	var line_matches: bool = effect_line is int and effect_line == 3
	var column_matches: bool = effect_column is int and effect_column == 5
	var cell_matches: bool = effect_cell is String and effect_cell == "E3"
	assert_true(
		segments_match,
		str(field_segments)
	)
	assert_true(
		source_matches,
		str(effect_source)
	)
	assert_true(
		line_matches,
		str(effect_line)
	)
	assert_true(
		column_matches,
		str(effect_column)
	)
	assert_true(
		cell_matches,
		str(effect_cell)
	)
	var copied: Array[Dictionary] = table.get_records()
	var copied_effects: Array = copied[0]["effects"]
	var copied_first: Dictionary = copied_effects[0]
	copied_first["damage"] = 99.0
	assert_eq(
		table.records,
		_expected_records(),
		"Caller-owned record copies cannot mutate the built resource."
	)
	assert_eq(
		ir.get_records(),
		_expected_records(),
		"The build IR remains independent from consumer copies."
	)


func test_second_physical_row_type_error_rejects_entire_table_and_locates_original_cell() -> void:
	var source: GFConfigPipelineTableSource = _source("1,10,fire,2.5,,red,3\n,,ice,,not-an-int,blue,6\n2,20,fire,1,,green,8\n")
	var result: Dictionary = GFConfigPipeline.new().build_table(source)
	assert_false(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var failed_table: Variant = result.get("table")
	var failed_ir: Variant = result.get("ir")
	assert_true(
		failed_table == null,
		"Earlier valid rows must not escape a failed build."
	)
	assert_true(failed_ir == null)
	var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
	var issue: Dictionary = _issue_for_path(report, "effects[1].slow")
	assert_false(
		issue.is_empty(),
		str(report)
	)
	var field_segments: Variant = issue.get("field_segments")
	var issue_source: Variant = issue.get("source")
	var issue_line: Variant = issue.get("line")
	var issue_column: Variant = issue.get("column")
	var issue_cell: Variant = issue.get("cell")
	var issue_row: Variant = issue.get("row_index")
	var segments_match: bool = field_segments is Array and field_segments == [
		"effects",
		1,
		"slow",
	]
	var source_matches: bool = issue_source is String and issue_source == source.source_path
	var line_matches: bool = issue_line is int and issue_line == 3
	var column_matches: bool = issue_column is int and issue_column == 5
	var cell_matches: bool = issue_cell is String and issue_cell == "E3"
	var row_matches: bool = issue_row is int and issue_row == 0
	assert_true(
		segments_match,
		str(field_segments)
	)
	assert_true(
		source_matches,
		str(issue_source)
	)
	assert_true(
		line_matches,
		str(issue_line)
	)
	assert_true(
		column_matches,
		str(issue_column)
	)
	assert_true(
		cell_matches,
		str(issue_cell)
	)
	assert_true(row_matches, "Logical record index must not be confused with CSV physical row.")


func test_explicit_recursive_schema_copy_failure_cannot_fall_back_to_inferred_schema() -> void:
	var source: GFConfigPipelineTableSource = _source(_CSV_VALID_ROWS)
	var recursive: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	recursive.kind = GFConfigTypeDefinition.Kind.ARRAY
	recursive.element_type = recursive
	var effects: GFConfigTableColumn = source.schema.get_column(&"effects")
	effects.type_definition = recursive
	source.infer_schema = true
	var with_inference: Dictionary = GFConfigPipeline.new().build_table(source)
	source.infer_schema = false
	var without_inference: Dictionary = GFConfigPipeline.new().build_table(source)
	var records: Array[Dictionary] = []
	records.assign(_expected_records())
	var invalid_ir: GFConfigPipelineTableIR = GFConfigPipelineTableIR.create(
		&"actors",
		source.source_path,
		&"csv",
		records,
		source.schema
	)
	var contract: Dictionary = invalid_ir.validate_contract()
	recursive.element_type = null
	assert_false(
		GFVariantData.get_option_bool(contract, "success"),
		str(contract)
	)
	assert_eq(
		GFVariantData.get_option_string(contract, "error_kind"),
		"schema_copy_failed"
	)
	var copied_ir: GFConfigPipelineTableIR = invalid_ir.duplicate_ir()
	var copied_contract: Dictionary = copied_ir.validate_contract()
	assert_false(
		GFVariantData.get_option_bool(copied_contract, "success"),
		str(copied_contract)
	)
	assert_eq(
		GFVariantData.get_option_string(copied_contract, "error_kind"),
		"schema_copy_failed"
	)
	var materialized: Dictionary = GFConfigPipelineTargetStage.new().materialize_table(copied_ir)
	assert_false(GFVariantData.get_option_bool(materialized, "success"))
	var materialized_table: Variant = materialized.get("table")
	assert_true(materialized_table == null)
	for result: Dictionary in [with_inference, without_inference]:
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			str(result)
		)
		var rejected_table: Variant = result.get("table")
		var rejected_ir: Variant = result.get("ir")
		assert_true(rejected_table == null)
		assert_true(rejected_ir == null)
		assert_eq(
			GFVariantData.get_option_string(result, "error_kind"),
			"schema_copy_failed"
		)
		var report: Dictionary = GFVariantData.get_option_dictionary(result, "report")
		assert_false(
			GFVariantData.get_option_bool(report, "ok"),
			str(report)
		)
		assert_gt(
			GFVariantData.get_option_int(report, "error_count"),
			0,
			"The invalid explicit declaration must remain an error."
		)


func test_export_reload_freshness_and_failed_rebuild_preserve_last_valid_artifacts() -> void:
	var source: GFConfigPipelineTableSource = _source(_CSV_VALID_ROWS)
	var profile_path: String = _path("profile.tres")
	var output_path: String = _path("database.tres")
	var manifest_path: String = _path("manifest.json")
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	profile.profile_id = &"structured"
	profile.database_id = &"structured"
	profile.sources = [source]
	profile.output_path = output_path
	assert_eq(
		ResourceSaver.save(profile, profile_path),
		OK
	)
	var options: Dictionary = { "changed_only": true, "manifest_path": manifest_path }
	var runner: GFConfigPipelineRunner = GFConfigPipelineRunner.new()
	var first: Dictionary = runner.export_profile_path(profile_path, options)
	assert_true(
		GFVariantData.get_option_bool(first, "success"),
		str(first)
	)
	assert_false(GFVariantData.get_option_bool(first, "skipped"))
	var loaded: Resource = ResourceLoader.load(
		output_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_true(loaded is GFConfigDatabaseResource)
	if not loaded is GFConfigDatabaseResource:
		return
	var database: GFConfigDatabaseResource = loaded
	var table: GFConfigTableResource = database.get_table_resource(&"actors")
	assert_not_null(table)
	if table == null:
		return
	assert_eq(
		table.records,
		_expected_records()
	)
	var second: Dictionary = runner.export_profile_path(profile_path, options)
	assert_true(
		GFVariantData.get_option_bool(second, "success"),
		str(second)
	)
	assert_true(
		GFVariantData.get_option_bool(second, "skipped"),
		"Identical source, schema, layout and compiler dependencies should be fresh."
	)
	var freshness: Dictionary = GFVariantData.get_option_dictionary(second, "freshness_report")
	assert_true(GFVariantData.get_option_bool(freshness, "fresh"))
	var output_before: PackedByteArray = FileAccess.get_file_as_bytes(output_path)
	var manifest_before: PackedByteArray = FileAccess.get_file_as_bytes(manifest_path)
	_write(
		source.source_path,
		_CSV_HEADER + "1,10,fire,2.5,,red,3\n,,ice,,bad,blue,6\n"
	)
	var failed: Dictionary = runner.export_profile_path(profile_path, options)
	assert_false(
		GFVariantData.get_option_bool(failed, "success"),
		str(failed)
	)
	assert_false(
		GFVariantData.get_option_bool(failed, "skipped"),
		"Changed source must not reuse an older successful artifact."
	)
	assert_eq(
		FileAccess.get_file_as_bytes(output_path),
		output_before
	)
	assert_eq(
		FileAccess.get_file_as_bytes(manifest_path),
		manifest_before
	)


# --- 私有/辅助方法 ---

func _source(rows: String) -> GFConfigPipelineTableSource:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"actors"
	source.source_path = _path("source.csv")
	_write(
		source.source_path,
		_CSV_HEADER + rows
	)
	source.schema = _schema()
	source.parse_options = {
		"layout": {
			"record_key_column": 1,
			"columns": [
				{
					"column": 1,
					"path": ["id"],
				},
				{
					"column": 2,
					"path": ["stats", "hp"],
				},
			],
			"collections": [
				{
					"kind": "array",
					"path": ["effects"],
					"columns": [
						{
							"column": 3,
							"path": ["type"],
						},
						{
							"column": 4,
							"path": ["damage"],
						},
						{
							"column": 5,
							"path": ["slow"],
						},
					],
				},
				{
					"kind": "map",
					"path": ["weights"],
					"key_column": 6,
					"columns": [
						{ "column": 7, "path": [] },
					],
				},
			],
		},
	}
	return source


func _schema() -> GFConfigTableSchema:
	var stats: GFConfigTypeDefinition = _struct(&"Stats")
	stats.fields = [_column(&"hp", GFConfigTableColumn.ValueType.INT)]
	var fire: GFConfigTypeDefinition = _struct(&"fire")
	fire.fields = [_column(&"damage", GFConfigTableColumn.ValueType.FLOAT)]
	var ice: GFConfigTypeDefinition = _struct(&"ice")
	ice.fields = [_column(&"slow", GFConfigTableColumn.ValueType.INT)]
	var polymorphic: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	polymorphic.kind = GFConfigTypeDefinition.Kind.POLYMORPHIC
	polymorphic.variants = [fire, ice]
	var effects: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	effects.kind = GFConfigTypeDefinition.Kind.ARRAY
	effects.element_type = polymorphic
	var integer: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	integer.scalar_type = GFConfigTableColumn.ValueType.INT
	var weights: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	weights.kind = GFConfigTypeDefinition.Kind.MAP
	weights.map_value_type = integer
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = &"actors"
	schema.id_field = &"id"
	schema.require_unique_id = true
	schema.coerce_values = true
	schema.allow_extra_fields = false
	schema.columns = [
		_column(&"id", GFConfigTableColumn.ValueType.INT),
		_structured_column(&"stats", stats),
		_structured_column(&"effects", effects),
		_structured_column(&"weights", weights),
	]
	return schema


func _struct(type_name: StringName) -> GFConfigTypeDefinition:
	var result: GFConfigTypeDefinition = GFConfigTypeDefinition.new()
	result.kind = GFConfigTypeDefinition.Kind.STRUCT
	result.type_name = type_name
	return result


func _column(field_name: StringName, value_type: GFConfigTableColumn.ValueType) -> GFConfigTableColumn:
	var result: GFConfigTableColumn = GFConfigTableColumn.new()
	result.field_name = field_name
	result.value_type = value_type
	result.required = true
	result.allow_null = false
	return result


func _structured_column(field_name: StringName, definition: GFConfigTypeDefinition) -> GFConfigTableColumn:
	var result: GFConfigTableColumn = _column(field_name, GFConfigTableColumn.ValueType.ANY)
	result.type_definition = definition
	return result


func _expected_records() -> Array:
	return [
		{
			"id": 1,
			"stats": { "hp": 10 },
			"effects": [
				{ "type": "fire", "damage": 2.5 },
				{ "type": "ice", "slow": 4 },
			],
			"weights": { "red": 3, "blue": 6 },
		},
		{
			"id": 2,
			"stats": { "hp": 20 },
			"effects": [
				{ "type": "fire", "damage": 1.0 },
			],
			"weights": { "green": 8 },
		},
	]


func _table(result: Dictionary) -> GFConfigTableResource:
	var value: Variant = result.get("table")
	if value is GFConfigTableResource:
		return value
	return null


func _ir(result: Dictionary) -> GFConfigPipelineTableIR:
	var value: Variant = result.get("ir")
	if value is GFConfigPipelineTableIR:
		return value
	return null


func _issue_for_path(report: Dictionary, path: String) -> Dictionary:
	for value: Variant in GFVariantData.get_option_array(report, "issues"):
		if value is Dictionary:
			var issue: Dictionary = value
			if GFVariantData.get_option_string(issue, "field_path") == path:
				return issue
	return {}


func _path(suffix: String) -> String:
	var path: String = (
		"user://gf_structured_pipeline_%d_%d_%s"
		% [
			Time.get_ticks_usec(),
			_paths.size(),
			suffix,
		]
	)
	_paths.append(path)
	return path


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		var stored: bool = file.store_string(content)
		assert_true(stored)
		file.close()
