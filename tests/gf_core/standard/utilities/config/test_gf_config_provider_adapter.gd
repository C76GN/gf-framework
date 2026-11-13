extends GutTest


func test_queries_do_not_load_and_explicit_load_is_repeatable() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var calls: Array[int] = [0]
	var loader: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array:
		calls[0] += 1
		return [
			{ "id": 1, "value": calls[0] },
		]
	assert_true(provider.register_table_source(&"items", loader))
	assert_true(_is_null(provider.get_record(&"items", 1)))
	assert_true(provider.has_table_source(&"items"))
	assert_false(provider.has_table(&"items"))
	assert_eq(
		calls[0],
		0
	)
	var prepared: Dictionary = provider.prepare_tables(PackedStringArray(["items"]))
	assert_true(GFVariantData.get_option_bool(prepared, "ok"))
	assert_false(provider.has_table(&"items"))
	var snapshot: GFConfigSnapshot = prepared["snapshot"]
	assert_true(
		GFVariantData.get_option_bool(
			provider.publish_snapshot(snapshot, 0),
			"ok"
		)
	)
	assert_true(
		_value_matches(
			_record(
				provider,
				&"items",
				1
			).get("value"),
			1
		)
	)
	assert_true(
		_value_matches(
			_record(
				provider,
				&"items",
				1
			).get("value"),
			1
		)
	)
	assert_eq(
		calls[0],
		1
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["items"])),
			"ok"
		)
	)
	assert_true(
		_value_matches(
			_record(
				provider,
				&"items",
				1
			).get("value"),
			2
		)
	)
	assert_true(
		_value_matches(
			GFVariantData.as_dictionary(snapshot.get_record(&"items", 1)).get("value"),
			1
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.get_load_report(&"items"),
			"loaded"
		)
	)


func test_dictionary_and_generated_object_capture_isolated_records() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var dictionary_table: Dictionary = {
		7: { "name": "Seven" },
	}
	assert_true(provider.register_table_source(&"dictionary", dictionary_table))
	var generated: GeneratedTable = GeneratedTable.new()
	assert_true(
		provider.register_table_source(
			&"generated",
			generated,
			{
				"record_ids": [10, 20],
			}
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["dictionary", "generated"])),
			"ok"
		)
	)
	dictionary_table[7]["name"] = "Changed"
	assert_true(
		_value_matches(
			_record(
				provider,
				&"dictionary",
				7
			).get("name"),
			"Seven"
		)
	)
	assert_true(
		_value_matches(
			_record(
				provider,
				&"generated",
				20
			).get("name"),
			"Generated 20"
		)
	)
	var result: Dictionary = _record(
		provider,
		&"generated",
		20
	)
	result["name"] = "Changed"
	assert_true(
		_value_matches(
			_record(
				provider,
				&"generated",
				20
			).get("name"),
			"Generated 20"
		)
	)


func test_loader_replacement_rejects_outer_candidate_and_retains_new_source() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var loader: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array:
		var _registered: bool = provider.register_table_source(
			&"items",
			[
				{ "id": 2 },
			]
		)
		return [
			{ "id": 1 },
		]
	assert_true(provider.register_table_source(&"items", loader))
	var result: Dictionary = provider.load_tables(PackedStringArray(["items"]))
	assert_true(
		_value_matches(
			result.get("error_kind"),
			&"source_changed"
		)
	)
	assert_null(provider.get_snapshot())
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["items"])),
			"ok"
		)
	)
	assert_false(_is_null(provider.get_record(&"items", 2)))
	assert_true(_is_null(provider.get_record(&"items", 1)))
	provider.clear_table_sources()


func test_schema_replacement_requires_publication_and_rejects_bad_registration() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var rows: Array = [
		{ "id": 1, "name": "One" },
	]
	var schema: GFConfigTableSchema = GFConfigTableSchema.infer_from_records(&"items", rows)
	assert_true(
		provider.register_table_source(
			&"items",
			rows,
			{ "schema": schema }
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["items"])),
			"ok"
		)
	)
	schema.table_name = &"wrong"
	assert_false(
		provider.register_table_source(
			&"items",
			[],
			{ "schema": schema }
		)
	)
	assert_eq(
		provider.get_schema(&"items").table_name,
		&"items"
	)
	assert_true(
		provider.register_table_source(
			&"items",
			[
				{ "id": 2 },
			]
		)
	)
	assert_false(_is_null(provider.get_record(&"items", 1)))
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["items"])),
			"ok"
		)
	)
	assert_true(_is_null(provider.get_record(&"items", 1)))
	assert_false(provider.get_schema(&"items").has_column(&"name"))


func test_prepare_closes_declared_references_without_loading_unrelated_sources() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var owners: Array = [
		{ "id": 1, "item_id": 8 },
	]
	var schema: GFConfigTableSchema = GFConfigTableSchema.infer_from_records(&"owners", owners)
	var reference: GFConfigTableReference = GFConfigTableReference.new()
	reference.reference_id = &"item"
	reference.source_fields = PackedStringArray(["item_id"])
	reference.target_table_name = &"items"
	reference.target_fields = PackedStringArray(["id"])
	schema.references = [reference]
	assert_true(
		provider.register_table_source(
			&"owners",
			owners,
			{ "schema": schema }
		)
	)
	assert_true(
		provider.register_table_source(
			&"items",
			[
				{ "id": 8 },
			]
		)
	)
	assert_true(
		provider.register_table_source(
			&"later",
			[
				{ "id": 99 },
			]
		)
	)
	var result: Dictionary = provider.load_tables(PackedStringArray(["owners"]))
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(
		provider.get_table_ids(),
		PackedStringArray(["items", "owners"])
	)
	assert_eq(
		provider.get_source_ids(),
		PackedStringArray(
			[
				"items",
				"later",
				"owners",
			]
		)
	)
	assert_true(provider.has_table_source(&"later"))
	assert_false(provider.has_table(&"later"))
	assert_true(
		_value_matches(
			provider.get_load_report(&"missing").get("status"),
			&"missing"
		)
	)


func test_source_clear_releases_catalog_but_not_pinned_snapshot() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	assert_true(
		provider.register_table_source(
			&"items",
			[
				{ "id": 1 },
			]
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["items"])),
			"ok"
		)
	)
	var snapshot: GFConfigSnapshot = provider.get_snapshot()
	provider.clear_table_sources()
	assert_true(provider.get_source_ids().is_empty())
	assert_false(_is_null(provider.get_record(&"items", 1)))
	assert_true(
		GFVariantData.get_option_bool(
			provider.update_tables(
				[],
				{
					"removed_tables": PackedStringArray(["items"]),
				}
			),
			"ok"
		)
	)
	assert_true(_is_null(provider.get_record(&"items", 1)))
	assert_false(_is_null(snapshot.get_record(&"items", 1)))


func test_freed_generated_object_rejects_new_capture_but_old_snapshot_survives() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var generated: DisposableTable = DisposableTable.new()
	assert_true(provider.register_table_source(&"generated", generated))
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["generated"])),
			"ok"
		)
	)
	var snapshot: GFConfigSnapshot = provider.get_snapshot()
	generated.free()
	var result: Dictionary = provider.load_tables(PackedStringArray(["generated"]))
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_same(
		provider.get_snapshot(),
		snapshot
	)
	assert_false(_is_null(provider.get_record(&"generated", 1)))


func test_recursive_preparation_invalidates_outer_load() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var loader: Callable = func(_table_name: StringName, _metadata: Dictionary) -> Array:
		var _nested: Dictionary = provider.load_tables(PackedStringArray(["other"]))
		return [
			{ "id": 1 },
		]
	assert_true(provider.register_table_source(&"items", loader))
	assert_true(
		provider.register_table_source(
			&"other",
			[
				{ "id": 2 },
			]
		)
	)
	var result: Dictionary = provider.load_tables(PackedStringArray(["items"]))
	assert_true(
		_value_matches(
			result.get("error_kind"),
			&"reentrant_preparation"
		)
	)
	assert_null(provider.get_snapshot())
	provider.clear_table_sources()


func test_generated_record_projector_and_source_version_are_explicit() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	var record: GeneratedRecord = GeneratedRecord.new()
	var projector: Callable = func(value: Variant) -> Dictionary:
		if not value is GeneratedRecord:
			return {}
		var typed_record: GeneratedRecord = value
		return { "id": typed_record.id, "name": typed_record.label }
	assert_true(
		provider.register_table_source(
			&"items",
			[record],
			{ "record_projector": projector, "content_version": "v2", }
		)
	)
	var wrong: Dictionary = provider.load_tables(
		PackedStringArray(["items"]),
		{ "version": "v1" }
	)
	assert_true(
		_value_matches(
			wrong.get("error_kind"),
			&"content_version_mismatch"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(
				PackedStringArray(["items"]),
				{ "version": "v2" }
			),
			"ok"
		)
	)
	record.label = "Changed"
	assert_true(
		_value_matches(
			_record(
				provider,
				&"items",
				5
			).get("name"),
			"Five"
		)
	)


func test_bad_capture_and_missing_reference_source_do_not_partially_publish() -> void:
	var provider: GFConfigProviderAdapter = GFConfigProviderAdapter.new()
	assert_true(
		provider.register_table_source(
			&"good",
			[
				{ "id": 1 },
			]
		)
	)
	assert_true(
		provider.register_table_source(
			&"bad",
			[1]
		)
	)
	var result: Dictionary = provider.load_tables(PackedStringArray(["good", "bad"]))
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_null(provider.get_snapshot())
	assert_true(
		GFVariantData.get_option_bool(
			provider.load_tables(PackedStringArray(["good"])),
			"ok"
		)
	)
	var previous: GFConfigSnapshot = provider.get_snapshot()
	var missing: Dictionary = provider.load_tables(PackedStringArray(["unknown"]))
	assert_true(
		_value_matches(
			missing.get("error_kind"),
			&"missing_source"
		)
	)
	assert_same(
		provider.get_snapshot(),
		previous
	)


func _record(
	provider: GFConfigProvider,
	table_name: StringName,
	record_id: Variant
) -> Dictionary:
	return GFVariantData.as_dictionary(provider.get_record(table_name, record_id))


func _is_null(value: Variant) -> bool:
	return value == null


func _value_matches(actual: Variant, expected: Variant) -> bool:
	return typeof(actual) == typeof(expected) and actual == expected


class GeneratedTable extends RefCounted:
	func get_record(record_id: Variant) -> Dictionary:
		return { "id": record_id, "name": "Generated %s" % str(record_id) }


class DisposableTable extends Node:
	func get_table() -> Array:
		return [
			{ "id": 1 },
		]


class GeneratedRecord extends RefCounted:
	var id: int = 5
	var label: String = "Five"
