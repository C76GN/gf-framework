@tool
extends GutTest


func test_empty_tables_still_require_authorized_reference_closure() -> void:
	var items: GFConfigTableSchema = _schema(
		&"items",
		[
			"id",
			"category",
			"secret",
		]
	)
	var categories: GFConfigTableSchema = _schema(
		&"categories",
		[
			"id",
			"label",
			"secret",
		]
	)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.source_fields = ["category"]
	reference.target_table_name = &"categories"
	items.references = [reference]
	var ir: GFConfigPipelineIR = _ir([items, categories])
	var target: GFConfigPipelineConsumerTarget = _target()
	target.visible_fields = {
		"items": PackedStringArray(["id", "category"]),
	}
	var stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	assert_false(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)
	target.visible_fields["categories"] = PackedStringArray(["id", "label"])
	var result: Dictionary = stage.project_database(ir, target)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "tables"),
		PackedStringArray(["categories", "items"])
	)
	var projected: GFConfigPipelineIR = result["ir"]
	assert_null(projected.get_table(&"items").get_schema().get_column(&"secret"))
	assert_eq(
		projected.get_table(&"categories").get_schema().references.size(),
		0
	)


func test_hidden_reference_does_not_authorize_table_or_values() -> void:
	var items: GFConfigTableSchema = _schema(
		&"items",
		["id", "secret"]
	)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.source_fields = ["secret"]
	reference.target_table_name = &"private"
	items.references = [reference]
	var ir: GFConfigPipelineIR = GFConfigPipelineIR.create(
		&"db",
		"1",
		{ "private": "database secret" }
	)
	var rows: Array[Dictionary] = [
		{
			"id": 1,
			"secret": 77,
			"extra": "private",
		},
	]
	assert_true(
		GFVariantData.get_option_bool(
			ir.add_table(
				GFConfigPipelineTableIR.create(
					&"items",
					"",
					&"json",
					rows,
					items,
					{},
					{ "private": "table secret" }
				)
			),
			"success"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			ir.seal(),
			"success"
		)
	)
	var target: GFConfigPipelineConsumerTarget = _target()
	var stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	var result: Dictionary = stage.materialize_database(
		ir,
		{ "consumer_target": target, "validate_database": false }
	)
	assert_true(
		GFVariantData.get_option_bool(result, "success"),
		str(result)
	)
	var database: GFConfigDatabaseResource = result["database"]
	assert_eq(
		database.get_table_ids(),
		PackedStringArray(["items"])
	)
	var table: GFConfigTableResource = database.get_table_resource(&"items")
	assert_eq(
		table.records,
		[
			{ "id": 1 },
		]
	)
	assert_eq(
		table.schema.references.size(),
		0
	)
	assert_false(table.metadata.has("private"))
	assert_false(database.metadata.has("private"))
	assert_eq(
		ir.get_table(&"items").get_records(),
		rows
	)


func test_partial_composite_reference_and_hidden_target_key_fail() -> void:
	var items: GFConfigTableSchema = _schema(
		&"items",
		[
			"id",
			"a",
			"b",
		]
	)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.source_fields = ["a", "b"]
	reference.target_table_name = &"lookup"
	reference.target_fields = ["a", "b"]
	items.references = [reference]
	var ir: GFConfigPipelineIR = _ir(
		[
			items,
			_schema(
				&"lookup",
				[
					"id",
					"a",
					"b",
				]
			),
		]
	)
	var target: GFConfigPipelineConsumerTarget = _target()
	target.visible_fields = {
		"items": PackedStringArray(["id", "a"]),
		"lookup": PackedStringArray(
			[
				"id",
				"a",
				"b",
			]
		),
	}
	var stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	assert_false(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)
	target.visible_fields["items"] = PackedStringArray(
		[
			"id",
			"a",
			"b",
		]
	)
	target.visible_fields["lookup"] = PackedStringArray(["id", "a"])
	assert_false(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)


func test_cycles_are_finite_and_projected_references_are_validated() -> void:
	var items: GFConfigTableSchema = _schema(
		&"items",
		["id", "other"]
	)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.source_fields = ["other"]
	reference.target_table_name = &"items"
	items.references = [reference]
	var rows: Array[Dictionary] = [
		{ "id": 1, "other": 2 },
	]
	var ir: GFConfigPipelineIR = GFConfigPipelineIR.create()
	assert_true(
		GFVariantData.get_option_bool(
			ir.add_table(
				GFConfigPipelineTableIR.create(
					&"items",
					"",
					&"json",
					rows,
					items
				)
			),
			"success"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			ir.seal(),
			"success"
		)
	)
	var target: GFConfigPipelineConsumerTarget = _target()
	target.visible_fields["items"] = PackedStringArray(["id", "other"])
	var stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	assert_true(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			stage.materialize_database(
				ir,
				{ "consumer_target": target, "validate_database": false }
			),
			"success"
		)
	)


func test_invalid_target_names_and_fields_are_not_coerced_or_shared() -> void:
	var target: GFConfigPipelineConsumerTarget = _target()
	var captured: Dictionary = target.capture()
	assert_true(GFVariantData.get_option_bool(captured, "success"))
	target.visible_fields["items"] = PackedStringArray(["id", "secret"])
	assert_eq(
		GFVariantData.get_option_packed_string_array(
			GFVariantData.as_dictionary(captured["target"]["visible_fields"]),
			"items"
		),
		PackedStringArray(["id"])
	)
	target.visible_fields["items"] = ["id"]
	assert_true(
		GFVariantData.get_option_bool(
			target.capture(),
			"success"
		)
	)
	target.visible_fields["items"] = ["id", 1]
	assert_false(
		GFVariantData.get_option_bool(
			target.capture(),
			"success"
		)
	)
	target.visible_fields["items"] = PackedStringArray(["id", "id"])
	assert_false(
		GFVariantData.get_option_bool(
			target.capture(),
			"success"
		)
	)
	target.visible_fields["items"] = PackedStringArray(["id"])
	target.target_id = &" client "
	assert_false(
		GFVariantData.get_option_bool(
			target.capture(),
			"success"
		)
	)


func test_missing_schema_unknown_fields_and_inferred_schema_fail() -> void:
	var target: GFConfigPipelineConsumerTarget = _target()
	var stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
	var ir: GFConfigPipelineIR = _ir(
		[
			_schema(
				&"items",
				["other"]
			),
		]
	)
	assert_false(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)
	ir = GFConfigPipelineIR.create()
	assert_true(
		GFVariantData.get_option_bool(
			ir.add_table(
				GFConfigPipelineTableIR.create(
					&"items",
					"",
					&"json",
					[],
					_schema(
						&"items",
						["id"]
					),
					{},
					{ "schema_origin": "inferred" }
				)
			),
			"success"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			ir.seal(),
			"success"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			stage.project_database(ir, target),
			"success"
		)
	)


func test_profile_requires_selection_and_keeps_target_paths_isolated() -> void:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var client: GFConfigPipelineConsumerTarget = _target()
	var server: GFConfigPipelineConsumerTarget = _target()
	server.target_id = &"server"
	server.output_path = "user://server.tres"
	profile.consumer_targets = [client, server]
	assert_false(
		GFVariantData.get_option_bool(
			profile.resolve_consumer(),
			"success"
		)
	)
	var resolved: Dictionary = profile.resolve_consumer({ "target": "client" })
	assert_true(GFVariantData.get_option_bool(resolved, "success"))
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(resolved["options"]),
			"output_path"
		),
		client.output_path
	)
	var frozen: GFConfigPipelineConsumerTarget = resolved["target"]
	client.visible_fields = {}
	assert_true(
		GFVariantData.get_option_bool(
			frozen.capture(),
			"success"
		)
	)
	client.visible_fields = {
		"items": PackedStringArray(["id"]),
	}
	server.output_path = client.output_path
	assert_false(
		GFVariantData.get_option_bool(
			profile.resolve_consumer({ "target": "client" }),
			"success"
		)
	)


func test_target_output_aliases_and_cross_role_collisions_fail() -> void:
	var profile: GFConfigPipelineProfile = GFConfigPipelineProfile.new()
	var client: GFConfigPipelineConsumerTarget = _target()
	var server: GFConfigPipelineConsumerTarget = _target()
	server.target_id = &"server"
	profile.consumer_targets = [client, server]
	for alias: String in [
		" user://client.tres ",
		"user://Client.tres",
		"user://./client.tres",
	]:
		server.output_path = alias
		assert_false(
			GFVariantData.get_option_bool(
				profile.resolve_consumer({ "target": "client" }),
				"success"
			),
			alias
		)
	server.output_path = "user://server.tres"
	client.access_output_path = "user://client.gd"
	server.access_output_path = " user://Client.gd "
	assert_false(
		GFVariantData.get_option_bool(
			profile.resolve_consumer({ "target": "client" }),
			"success"
		)
	)
	server.access_output_path = "user://server.gd"
	assert_false(
		GFVariantData.get_option_bool(
			profile.resolve_consumer({ "target": "client", "output_path": "user://SERVER.tres" }),
			"success"
		)
	)


func _schema(table: StringName, names: PackedStringArray) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table
	for field_name: String in names:
		var column: GFConfigTableColumn = GFConfigTableColumn.new()
		column.field_name = StringName(field_name)
		column.value_type = GFConfigTableColumn.ValueType.INT
		schema.columns.append(column)
	return schema


func _ir(schemas: Array[GFConfigTableSchema]) -> GFConfigPipelineIR:
	var result: GFConfigPipelineIR = GFConfigPipelineIR.create()
	for schema: GFConfigTableSchema in schemas:
		assert_true(
			GFVariantData.get_option_bool(
				result.add_table(
					GFConfigPipelineTableIR.create(
						schema.table_name,
						"",
						&"json",
						[],
						schema
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


func _target() -> GFConfigPipelineConsumerTarget:
	var result: GFConfigPipelineConsumerTarget = GFConfigPipelineConsumerTarget.new()
	result.target_id = &"client"
	result.root_tables = ["items"]
	result.visible_fields = {
		"items": PackedStringArray(["id"]),
	}
	result.output_path = "user://client.tres"
	return result
