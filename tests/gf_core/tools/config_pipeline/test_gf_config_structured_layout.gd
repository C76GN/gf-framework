## 验证结构化表格通过原 Layout 入口形成 raw 记录与物理来源，不替 schema 做类型转换。
extends GutTest


# --- 私有变量 ---

var _paths: Array[String] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for path: String in _paths:
		var _removed: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_paths.clear()


# --- 测试 ---

func test_hierarchical_headers_build_nested_values_without_splitting_literal_dots() -> void:
	var result: Dictionary = _csv(
		"id,stats,stats,literal.dot\n,hp,mp,\none,12,7,kept\n",
		{
			"header_rows": [1, 2],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var records: Array = GFVariantData.get_option_array(result, "data")
	assert_eq(
		records,
		[
			{
				"id": "one",
				"stats": { "hp": "12", "mp": "7" },
				"literal.dot": "kept",
			},
		]
	)
	var locations: Array = GFVariantData.get_option_array(result, "row_locations")
	var location: Dictionary = locations[0]
	var fields: Dictionary = location["fields"]
	var hp: Dictionary = fields["stats.hp"]
	var hp_segments: Variant = hp["field_segments"]
	var hp_segments_match: bool = typeof(hp_segments) == TYPE_ARRAY and hp_segments == ["stats", "hp"]
	assert_true(hp_segments_match)
	var hp_line: Variant = hp["line"]
	var hp_line_matches: bool = typeof(hp_line) == TYPE_INT and hp_line == 3
	assert_true(hp_line_matches)
	var hp_cell: Variant = hp["cell"]
	var hp_cell_matches: bool = typeof(hp_cell) == TYPE_STRING and hp_cell == "B3"
	assert_true(hp_cell_matches)


func test_continuations_append_independent_arrays_maps_and_flush_last_group() -> void:
	var result: Dictionary = _csv(
		"id,kind,label,item,count,map_key,map_value\none,fire,title,gem,2,red,5\n,,title,coin,3,blue,9\ntwo,ice,,ore,4,green,6\n",
		_collection_layout()
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var records: Array = GFVariantData.get_option_array(result, "data")
	assert_eq(
		records,
		[
			{
				"id": "one",
				"kind": "fire",
				"label": "title",
				"items": [
					{ "item": "gem", "count": "2" },
					{ "item": "coin", "count": "3" },
				],
				"weights": { "red": "5", "blue": "9" },
			},
			{
				"id": "two",
				"kind": "ice",
				"items": [
					{ "item": "ore", "count": "4" },
				],
				"weights": { "green": "6" },
			},
		]
	)
	var locations: Array = GFVariantData.get_option_array(result, "row_locations")
	var first: Dictionary = locations[0]
	var fields: Dictionary = first["fields"]
	var second_count: Dictionary = fields["items[1].count"]
	var count_segments: Variant = second_count["field_segments"]
	var expected_segments: Array = [
		"items",
		1,
		"count",
	]
	var count_segments_match: bool = typeof(count_segments) == TYPE_ARRAY and count_segments == expected_segments
	assert_true(count_segments_match)
	var count_cell: Variant = second_count["cell"]
	var count_cell_matches: bool = typeof(count_cell) == TYPE_STRING and count_cell == "E3"
	assert_true(count_cell_matches)
	var first_label: Dictionary = fields["label"]
	var label_cell: Variant = first_label["cell"]
	var label_cell_matches: bool = typeof(label_cell) == TYPE_STRING and label_cell == "C2"
	assert_true(label_cell_matches, "Repeated equal values preserve their first definition.")


func test_continuation_failures_never_return_partial_records() -> void:
	var fixtures: Array[Dictionary] = [
		{ "text": ",fire,,gem,2,red,5\n", "kind": "orphan_layout_continuation" },
		{ "text": "one,fire,first,gem,2,red,5\n,,other,coin,3,blue,9\n", "kind": "conflicting_layout_value" },
		{ "text": "one,fire,,gem,2,red,5\n,,title,coin,3,red,9\n", "kind": "duplicate_layout_map_key" },
		{ "text": "one,fire,,gem,2,,5\n", "kind": "missing_layout_map_key" },
		{ "text": "one,fire,,gem,2,red,5\ntwo,ice,,coin,3,blue,9\none,fire,,ore,4,green,6\n", "kind": "noncontiguous_layout_record" },
	]
	for fixture: Dictionary in fixtures:
		var text: String = fixture["text"]
		var result: Dictionary = _csv(
			"id,kind,label,item,count,map_key,map_value\n" + text,
			_collection_layout()
		)
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			str(result)
		)
		var error_kind: Variant = result.get("error_kind")
		var expected_kind: Variant = fixture["kind"]
		var error_kind_matches: bool = (
			typeof(error_kind) == TYPE_STRING
			and typeof(expected_kind) == TYPE_STRING
			and error_kind == expected_kind
		)
		assert_true(error_kind_matches)
		var rejected_data: Variant = result.get("data")
		assert_true(rejected_data == null)
		assert_eq(
			GFVariantData.get_option_array(result, "row_locations").size(),
			0
		)


func test_empty_cells_are_missing_but_explicit_token_preserves_empty_string() -> void:
	var layout: Dictionary = {
		"empty_string_token": "<empty>",
		"columns": [
			{
				"column": 1,
				"path": ["id"],
			},
			{
				"column": 2,
				"path": ["effect", "kind"],
			},
			{
				"column": 3,
				"path": ["effect", "fire"],
			},
			{
				"column": 4,
				"path": ["effect", "ice"],
			},
			{
				"column": 5,
				"path": ["label"],
			},
		],
	}
	var result: Dictionary = _csv("id,kind,fire,ice,label\none,fire,3,,<empty>\n", layout)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_array(result, "data"),
		[
			{
				"id": "one",
				"effect": { "kind": "fire", "fire": "3" },
				"label": "",
			},
		]
	)


func test_blank_rows_are_explicit_and_unmapped_nonempty_columns_fail() -> void:
	var rejected: Dictionary = _csv("id,value\none,1\n,\ntwo,2\n", {})
	var blank_error_kind: Variant = rejected.get("error_kind")
	var blank_error_kind_matches: bool = typeof(blank_error_kind) == TYPE_STRING and blank_error_kind == "empty_layout_row"
	assert_true(blank_error_kind_matches)
	var accepted: Dictionary = _csv(
		"id,value\none,1\n,\ntwo,2\n",
		{ "blank_rows": "skip" }
	)
	assert_true(
		GFVariantData.get_option_bool(accepted, "success"),
		str(accepted)
	)
	assert_eq(
		GFVariantData.get_option_array(accepted, "data").size(),
		2
	)
	var ignored: Dictionary = _csv(
		"id,comment\none,note\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["id"],
				},
			],
			"ignored_columns": [2],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(ignored, "success"),
		str(ignored)
	)
	var unmapped: Dictionary = _csv(
		"id,extra\none,lost\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["id"],
				},
			],
		}
	)
	var unmapped_error_kind: Variant = unmapped.get("error_kind")
	var unmapped_error_kind_matches: bool = typeof(unmapped_error_kind) == TYPE_STRING and unmapped_error_kind == "unmapped_layout_column"
	assert_true(unmapped_error_kind_matches)
	var unmapped_data: Variant = unmapped.get("data")
	assert_true(unmapped_data == null)


func test_transposed_layout_keeps_physical_cell_coordinates() -> void:
	var result: Dictionary = _csv(
		"id,one,two\nhp,12,20\n",
		{ "orientation": "columns" }
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_array(result, "data"),
		[
			{ "id": "one", "hp": "12" },
			{ "id": "two", "hp": "20" },
		]
	)
	var rows: Array = GFVariantData.get_option_array(result, "row_locations")
	var second: Dictionary = rows[1]
	var fields: Dictionary = second["fields"]
	var hp: Dictionary = fields["hp"]
	var hp_line: Variant = hp["line"]
	var hp_line_matches: bool = typeof(hp_line) == TYPE_INT and hp_line == 2
	assert_true(hp_line_matches)
	var hp_column: Variant = hp["column"]
	var hp_column_matches: bool = typeof(hp_column) == TYPE_INT and hp_column == 3
	assert_true(hp_column_matches)
	var hp_cell: Variant = hp["cell"]
	var hp_cell_matches: bool = typeof(hp_cell) == TYPE_STRING and hp_cell == "C2"
	assert_true(hp_cell_matches)


func test_quoted_csv_newlines_do_not_create_implicit_blank_records() -> void:
	var result: Dictionary = _csv("id,text\none,\"first\nsecond\"\ntwo,last\n", {})
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_array(result, "data"),
		[
			{ "id": "one", "text": "first\nsecond" },
			{ "id": "two", "text": "last" },
		]
	)
	var locations: Array = GFVariantData.get_option_array(result, "row_locations")
	var last: Dictionary = locations[1]
	var last_line: Variant = last["line"]
	var last_line_matches: bool = typeof(last_line) == TYPE_INT and last_line == 4
	assert_true(last_line_matches)


func test_explicit_array_paths_reject_holes_and_structural_conflicts() -> void:
	var valid: Dictionary = _csv(
		"a,b\nfirst,second\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["values", 0],
				},
				{
					"column": 2,
					"path": ["values", 1],
				},
			],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(valid, "success"),
		str(valid)
	)
	assert_eq(
		GFVariantData.get_option_array(valid, "data"),
		[
			{
				"values": ["first", "second"],
			},
		]
	)
	var hole: Dictionary = _csv(
		"a\nfirst\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["values", 1000000],
				},
			],
		}
	)
	var hole_error_kind: Variant = hole.get("error_kind")
	var hole_error_kind_matches: bool = typeof(hole_error_kind) == TYPE_STRING and hole_error_kind == "sparse_layout_array"
	assert_true(hole_error_kind_matches)
	var hole_data: Variant = hole.get("data")
	assert_true(hole_data == null)
	var conflict: Dictionary = _csv(
		"a,b\n,\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["value"],
				},
				{
					"column": 2,
					"path": ["value", "child"],
				},
			],
		}
	)
	var conflict_error_kind: Variant = conflict.get("error_kind")
	var conflict_error_kind_matches: bool = typeof(conflict_error_kind) == TYPE_STRING and conflict_error_kind == "conflicting_layout_paths"
	assert_true(conflict_error_kind_matches, "Empty data cannot hide an invalid mapping.")


func test_invalid_binding_and_shared_work_budget_fail_closed() -> void:
	var typo: Dictionary = _csv(
		"id\none\n",
		{ "colums": [] }
	)
	var typo_error_kind: Variant = typo.get("error_kind")
	var typo_error_kind_matches: bool = typeof(typo_error_kind) == TYPE_STRING and typo_error_kind == "invalid_layout_option"
	assert_true(typo_error_kind_matches)
	var duplicate_binding: Dictionary = _csv(
		"id\none\n",
		{
			"columns": [
				{
					"column": 1,
					"path": ["a"],
				},
				{
					"column": 1,
					"path": ["b"],
				},
			],
		}
	)
	var duplicate_error_kind: Variant = duplicate_binding.get("error_kind")
	var duplicate_error_kind_matches: bool = typeof(duplicate_error_kind) == TYPE_STRING and duplicate_error_kind == "invalid_layout_column"
	assert_true(duplicate_error_kind_matches)
	var limited: Dictionary = _csv(
		"id,value\none,1\ntwo,2\n",
		{},
		{ "max_work_units": 20 }
	)
	assert_false(GFVariantData.get_option_bool(limited, "success"))
	var limited_data: Variant = limited.get("data")
	assert_true(limited_data == null)
	assert_true(limited.has("budget_report"))


func test_merged_headers_and_multiple_sheets_keep_anchor_and_data_origins() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "First",
				"xml": _sheet(
					[
						[
							"id",
							"stats",
							"",
						],
						[
							"",
							"hp",
							"mp",
						],
						[
							"same",
							"12",
							"7",
						],
					],
					"<mergeCells><mergeCell ref=\"B1:C1\"/></mergeCells>"
				),
			},
			{
				"name": "Second",
				"xml": _sheet(
					[
						[
							"id",
							"stats",
							"",
						],
						[
							"",
							"hp",
							"mp",
						],
						[
							"same",
							"20",
							"9",
						],
					],
					"<mergeCells><mergeCell ref=\"B1:C1\"/></mergeCells>"
				),
			},
		]
	)
	var result: Dictionary = _xlsx_decode(
		path,
		{
			"layout": {
				"header_rows": [1, 2],
			},
			"sheet_names": ["First", "Second"],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_array(result, "data"),
		[
			{
				"id": "same",
				"stats": { "hp": "12", "mp": "7" },
			},
			{
				"id": "same",
				"stats": { "hp": "20", "mp": "9" },
			},
		],
		"Cross-sheet duplicate IDs are left to the authoritative schema."
	)
	var locations: Array = GFVariantData.get_option_array(result, "row_locations")
	var second: Dictionary = locations[1]
	var fields: Dictionary = second["fields"]
	var mp: Dictionary = fields["stats.mp"]
	var mp_sheet_name: Variant = mp["sheet_name"]
	var mp_sheet_name_matches: bool = typeof(mp_sheet_name) == TYPE_STRING and mp_sheet_name == "Second"
	assert_true(mp_sheet_name_matches)
	var mp_sheet_path: Variant = mp["sheet_path"]
	var mp_sheet_path_matches: bool = typeof(mp_sheet_path) == TYPE_STRING and mp_sheet_path == "xl/worksheets/sheet2.xml"
	assert_true(mp_sheet_path_matches)
	var mp_cell: Variant = mp["cell"]
	var mp_cell_matches: bool = typeof(mp_cell) == TYPE_STRING and mp_cell == "C3"
	assert_true(mp_cell_matches)
	var header: Dictionary = result["header_location"]
	var header_fields: Dictionary = header["fields"]
	var mp_header: Dictionary = header_fields["stats.mp"]
	var ancestors: Array = mp_header["header_locations"]
	var group: Dictionary = ancestors[0]
	var group_cell: Variant = group["cell"]
	var group_cell_matches: bool = typeof(group_cell) == TYPE_STRING and group_cell == "B1"
	assert_true(group_cell_matches, "Merged group labels retain the original anchor.")


func test_xlsx_merge_in_data_and_failed_later_sheet_return_no_partial_rows() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "Good",
				"xml": _sheet(
					[
						["id", "value"],
						["one", "1"],
					]
				),
			},
			{
				"name": "Bad",
				"xml": _sheet(
					[
						["id", "value"],
						["two", "2"],
					],
					"<mergeCells><mergeCell ref=\"A2:B2\"/></mergeCells>"
				),
			},
		]
	)
	var result: Dictionary = _xlsx_decode(
		path,
		{
			"layout": {},
			"sheet_names": ["Good", "Bad"],
		}
	)
	var error_kind: Variant = result.get("error_kind")
	var error_kind_matches: bool = typeof(error_kind) == TYPE_STRING and error_kind == "layout_merge_outside_header"
	assert_true(error_kind_matches)
	var rejected_data: Variant = result.get("data")
	assert_true(rejected_data == null)
	var missing: Dictionary = _xlsx_decode(
		path,
		{
			"layout": {},
			"sheet_names": ["Good", "Missing"],
		}
	)
	var missing_error_kind: Variant = missing.get("error_kind")
	var missing_error_kind_matches: bool = typeof(missing_error_kind) == TYPE_STRING and missing_error_kind == "invalid_sheet_selection"
	assert_true(missing_error_kind_matches)
	var missing_data: Variant = missing.get("data")
	assert_true(missing_data == null)


func test_xlsx_continuation_does_not_cross_sheet_boundary() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "First",
				"xml": _sheet(
					[
						["id", "value"],
						["one", "1"],
					]
				),
			},
			{
				"name": "Second",
				"xml": _sheet(
					[
						["id", "value"],
						["", "2"],
					]
				),
			},
		]
	)
	var result: Dictionary = _xlsx_decode(
		path,
		{
			"layout": { "record_key_column": 1 },
			"sheet_names": ["First", "Second"],
		}
	)
	var error_kind: Variant = result.get("error_kind")
	var error_kind_matches: bool = typeof(error_kind) == TYPE_STRING and error_kind == "orphan_layout_continuation"
	assert_true(error_kind_matches)
	var rejected_data: Variant = result.get("data")
	assert_true(rejected_data == null)


func test_xlsx_sheet_selection_preserves_requested_order_and_physical_origins() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "First",
				"xml": _sheet(
					[
						["id"],
						["one"],
					]
				),
			},
			{
				"name": "Second",
				"xml": _sheet(
					[
						["id"],
						["two"],
					]
				),
			},
		]
	)
	var result: Dictionary = _xlsx_decode(
		path,
		{
			"layout": {},
			"sheet_names": ["Second", "First"],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_array(result, "data"),
		[
			{ "id": "two" },
			{ "id": "one" },
		]
	)
	var locations: Array = GFVariantData.get_option_array(result, "row_locations")
	var first: Dictionary = locations[0]
	var second: Dictionary = locations[1]
	var first_source: Variant = first["source"]
	var first_source_matches: bool = typeof(first_source) == TYPE_STRING and first_source == path
	assert_true(first_source_matches)
	var first_sheet_name: Variant = first["sheet_name"]
	var first_sheet_name_matches: bool = typeof(first_sheet_name) == TYPE_STRING and first_sheet_name == "Second"
	assert_true(first_sheet_name_matches)
	var first_sheet_path: Variant = first["sheet_path"]
	var first_sheet_path_matches: bool = typeof(first_sheet_path) == TYPE_STRING and first_sheet_path == "xl/worksheets/sheet2.xml"
	assert_true(first_sheet_path_matches)
	var first_cell: Variant = first["cell"]
	var first_cell_matches: bool = typeof(first_cell) == TYPE_STRING and first_cell == "A2"
	assert_true(first_cell_matches)
	var first_row_index: Variant = first["row_index"]
	var first_row_index_matches: bool = typeof(first_row_index) == TYPE_INT and first_row_index == 0
	assert_true(first_row_index_matches)
	var second_sheet_name: Variant = second["sheet_name"]
	var second_sheet_name_matches: bool = typeof(second_sheet_name) == TYPE_STRING and second_sheet_name == "First"
	assert_true(second_sheet_name_matches)
	var second_row_index: Variant = second["row_index"]
	var second_row_index_matches: bool = typeof(second_row_index) == TYPE_INT and second_row_index == 1
	assert_true(second_row_index_matches)


func test_xlsx_sheet_selection_rejects_requested_duplicates_and_ambiguous_names() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "Duplicate",
				"xml": _sheet(
					[
						["id"],
						["one"],
					]
				),
			},
			{
				"name": "Duplicate",
				"xml": _sheet(
					[
						["id"],
						["two"],
					]
				),
			},
			{
				"name": "Unique",
				"xml": _sheet(
					[
						["id"],
						["three"],
					]
				),
			},
		]
	)
	var unique: Dictionary = _xlsx_decode(
		path,
		{
			"layout": {},
			"sheet_names": ["Unique"],
		}
	)
	assert_true(
		GFVariantData.get_option_bool(unique, "success"),
		str(unique)
	)
	assert_eq(
		GFVariantData.get_option_array(unique, "data"),
		[
			{ "id": "three" },
		]
	)
	for names: Array in [
		["Duplicate"],
		["Unique", "Unique"],
	]:
		var rejected: Dictionary = _xlsx_decode(
			path,
			{ "layout": {}, "sheet_names": names }
		)
		assert_false(
			GFVariantData.get_option_bool(rejected, "success"),
			str(rejected)
		)
		var error_kind: Variant = rejected.get("error_kind")
		var error_kind_matches: bool = typeof(error_kind) == TYPE_STRING and error_kind == "invalid_sheet_selection"
		assert_true(error_kind_matches)
		var rejected_source: Variant = rejected.get("source")
		var rejected_source_matches: bool = typeof(rejected_source) == TYPE_STRING and rejected_source == path
		assert_true(rejected_source_matches)
		var rejected_data: Variant = rejected.get("data")
		assert_true(rejected_data == null)
		assert_true(GFVariantData.get_option_array(rejected, "row_locations").is_empty())


func test_xlsx_sheet_selection_respects_shared_remaining_budget_before_reading_sheets() -> void:
	var path: String = _xlsx(
		[
			{
				"name": "First",
				"xml": _sheet(
					[
						["id"],
						["one"],
					]
				),
			},
			{
				"name": "Second",
				"xml": _sheet(
					[
						["id"],
						["two"],
					]
				),
			},
		]
	)
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"structured"
	source.source_path = path
	source.parse_options = {
		"layout": {},
		"sheet_names": ["Second", "First"],
	}
	for remaining: int in [1, 3]:
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.new()
		var options: Dictionary = { "work_budget": budget }
		var read_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source, options)
		assert_true(
			GFVariantData.get_option_bool(read_result, "success"),
			str(read_result)
		)
		var stage: _RemainingSelectionBudgetLayout = _RemainingSelectionBudgetLayout.new()
		stage.remaining_work = remaining
		var result: Dictionary = stage.decode_source(
			source,
			read_result,
			options
		)
		assert_true(stage.remaining_reserved)
		assert_false(
			GFVariantData.get_option_bool(result, "success"),
			str(result)
		)
		var error_kind: Variant = result.get("error_kind")
		var error_kind_matches: bool = typeof(error_kind) == TYPE_STRING and error_kind == "config_work_limit_exceeded"
		assert_true(error_kind_matches)
		var rejected_source: Variant = result.get("source")
		var rejected_source_matches: bool = typeof(rejected_source) == TYPE_STRING and rejected_source == path
		assert_true(rejected_source_matches)
		var rejected_data: Variant = result.get("data")
		assert_true(rejected_data == null)
		assert_true(GFVariantData.get_option_array(result, "row_locations").is_empty())
		assert_eq(
			stage.worksheet_reads,
			0,
			"Selection must fail before reading any worksheet."
		)
		assert_false(
			budget.is_ok(),
			"Selection must consume the caller's existing budget."
		)
		var report: Dictionary = GFVariantData.get_option_dictionary(result, "budget_report")
		var expected_context: String = "layout.xlsx_sheet_name_index" if remaining == 1 else "layout.xlsx_sheet_selection"
		var reported_context: Variant = report.get("context")
		var reported_context_matches: bool = typeof(reported_context) == TYPE_STRING and reported_context == expected_context
		assert_true(reported_context_matches)


# --- 私有/辅助方法 ---

func _csv(
	text: String,
	layout: Dictionary,
	limits: Dictionary = {}
) -> Dictionary:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"structured"
	source.source_format = &"csv"
	source.source_path = "user://structured.csv"
	source.parse_options = { "layout": layout }
	var options: Dictionary = {}
	if not limits.is_empty():
		options["work_limits"] = limits
	return GFConfigPipelineLayoutStage.new().decode_source(
		source,
		{
			"success": true,
			"payload_kind": "text",
			"text": text,
			"source_receipt": {},
		},
		options
	)


func _collection_layout() -> Dictionary:
	return {
		"record_key_column": 1,
		"columns": [
			{
				"column": 1,
				"path": ["id"],
			},
			{
				"column": 2,
				"path": ["kind"],
			},
			{
				"column": 3,
				"path": ["label"],
			},
		],
		"collections": [
			{
				"kind": "array",
				"path": ["items"],
				"columns": [
					{
						"column": 4,
						"path": ["item"],
					},
					{
						"column": 5,
						"path": ["count"],
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
	}


func _xlsx_decode(path: String, parse_options: Dictionary) -> Dictionary:
	var source: GFConfigPipelineTableSource = GFConfigPipelineTableSource.new()
	source.table_name = &"structured"
	source.source_path = path
	source.parse_options = parse_options
	var read_result: Dictionary = GFConfigPipelineReaderStage.new().read_source(source)
	return GFConfigPipelineLayoutStage.new().decode_source(source, read_result)


func _sheet(rows: Array, suffix: String = "") -> String:
	var xml: String = "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>"
	for index: int in range(rows.size()):
		var row: Array = rows[index]
		xml += "<row r=\"%d\">" % (index + 1)
		for column: int in range(row.size()):
			var text: String = row[column]
			if text.is_empty():
				continue
			var address: String = String.chr(65 + column) + str(index + 1)
			xml += (
				"<c r=\"%s\" t=\"inlineStr\"><is><t>%s</t></is></c>"
				% [address, text.xml_escape()]
			)
		xml += "</row>"
	return xml + "</sheetData>" + suffix + "</worksheet>"


func _xlsx(sheets: Array[Dictionary]) -> String:
	var path: String = (
		"user://gf_structured_%d_%d.xlsx"
		% [Time.get_ticks_usec(), _paths.size()]
	)
	_paths.append(path)
	var entries: Dictionary = {}
	var workbook: String = "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>"
	var relationships: String = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
	for index: int in range(sheets.size()):
		var sheet: Dictionary = sheets[index]
		var sheet_name: String = sheet["name"]
		workbook += (
			"<sheet name=\"%s\" sheetId=\"%d\" r:id=\"rId%d\"/>"
			% [
				sheet_name.xml_escape(),
				index + 1,
				index + 1,
			]
		)
		relationships += (
			"<Relationship Id=\"rId%d\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet%d.xml\"/>"
			% [index + 1, index + 1]
		)
		entries["xl/worksheets/sheet%d.xml" % (index + 1)] = sheet["xml"]
	entries["xl/workbook.xml"] = workbook + "</sheets></workbook>"
	entries["xl/_rels/workbook.xml.rels"] = relationships + "</Relationships>"
	var packer: ZIPPacker = ZIPPacker.new()
	assert_eq(
		packer.open(path),
		OK
	)
	for entry_path: String in entries:
		var content: String = entries[entry_path]
		assert_eq(
			packer.start_file(entry_path),
			OK
		)
		assert_eq(
			packer.write_file(content.to_utf8_buffer()),
			OK
		)
		assert_eq(
			packer.close_file(),
			OK
		)
	assert_eq(
		packer.close(),
		OK
	)
	return path


# --- 内部类 ---

## 保留真实归档及工作簿读取，仅在进入选表前缩小已有预算的剩余额度。
class _RemainingSelectionBudgetLayout extends GFConfigPipelineLayoutStage:
	var remaining_work: int = 0
	var remaining_reserved: bool = false
	var worksheet_reads: int = 0


	func _read_xlsx_workbook_sheets(
		archive_session: Dictionary,
		files: PackedStringArray,
		options: Dictionary
	) -> Dictionary:
		var result: Dictionary = super._read_xlsx_workbook_sheets(
			archive_session,
			files,
			options
		)
		if not GFVariantData.get_option_bool(result, "success"):
			return result
		var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
		var report: Dictionary = budget.get_report()
		var limits: Dictionary = report["limits"]
		var usage: Dictionary = report["usage"]
		var max_work_units: int = limits["max_work_units"]
		var used_work_units: int = usage["work_units"]
		var available: int = max_work_units - used_work_units
		if available >= remaining_work:
			remaining_reserved = budget.consume_work(
				available - remaining_work,
				"test.selection_preceding_work"
			)
		return result


	func _zip_read_bytes(
		archive_session: Dictionary,
		files: PackedStringArray,
		path: String,
		max_bytes: int
	) -> Dictionary:
		if path.begins_with("xl/worksheets/"):
			worksheet_reads += 1
		return super._zip_read_bytes(
			archive_session,
			files,
			path,
			max_bytes
		)
