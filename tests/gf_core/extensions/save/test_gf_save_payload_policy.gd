## 显式保留政策的值域、投影、稳定身份和删除回归。
extends GutTest


# --- 测试方法 ---

func test_unknown_fields_are_explicit_and_do_not_enter_runtime() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	var source: Dictionary = {
		"coins": 3,
		"future": { "v": 7 },
		"items": [],
	}
	var result: Dictionary = policy.project(source)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	var projection: Dictionary = GFVariantData.get_option_dictionary(result, "projection")
	assert_false(projection.has("future"))
	projection["coins"] = 8
	var merged: Dictionary = policy.merge(
		projection,
		result.get("baseline")
	)
	assert_true(
		_matches(
			merged.get("payload"),
			{
				"coins": 8,
				"future": { "v": 7 },
				"items": [],
			}
		)
	)
	var baseline: Dictionary = GFVariantData.get_option_dictionary(result, "baseline")
	source["future"] = 99
	assert_true(
		_matches(
			baseline.get("future"),
			{ "v": 7 }
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"typo": 3,
					"items": [],
				}
			),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			policy.project({ "coins": "3", "items": [] }),
			"ok"
		)
	)


func test_collection_reorder_keeps_retained_fields_with_identity() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	var source: Dictionary = {
		"coins": 1,
		"items": [
			{ "id": 90, "unreleased": true },
			{
				"id": 1,
				"amount": 2,
				"future": "first",
			},
			{ "id": 91, "unreleased": "middle" },
			{
				"id": 2,
				"amount": 3,
				"future": "second",
			},
			{ "id": 92, "unreleased": "last" },
		],
	}
	var accepted: Dictionary = policy.project(source)
	assert_true(GFVariantData.get_option_bool(accepted, "ok"))
	var projected: Dictionary = GFVariantData.get_option_dictionary(accepted, "projection")
	assert_true(
		_matches(
			projected.get("items"),
			[
				{ "id": 1, "amount": 2 },
				{ "id": 2, "amount": 3 },
			]
		)
	)
	assert_true(
		_matches(
			policy.merge(
				projected,
				accepted.get("baseline")
			).get("payload"),
			source
		)
	)
	projected["items"] = [
		{ "id": 2, "amount": 10 },
		{ "id": 1, "amount": 20 },
	]
	var result: Dictionary = policy.merge(
		projected,
		accepted.get("baseline")
	)
	var payload: Dictionary = GFVariantData.get_option_dictionary(result, "payload")
	assert_true(
		_matches(
			payload.get("items"),
			[
				{ "id": 91, "unreleased": "middle" },
				{
					"id": 2,
					"amount": 10,
					"future": "second",
				},
				{ "id": 90, "unreleased": true },
				{
					"id": 1,
					"amount": 20,
					"future": "first",
				},
				{ "id": 92, "unreleased": "last" },
			]
		)
	)


func test_deleted_known_items_and_explicit_retained_deletions_do_not_resurrect() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	var source: Dictionary = {
		"coins": 1,
		"future": 7,
		"items": [
			{
				"id": 1,
				"amount": 1,
				"future": 2,
			},
			{ "id": 2, "amount": 2 },
			{ "id": 90, "future": 3 },
		],
	}
	var current: Dictionary = {
		"coins": 2,
		"items": [
			{ "id": 1, "amount": 4 },
		],
	}
	var deletions: Dictionary = {
		"": ["future"],
		"/items": [90],
	}
	deletions[GFSavePayloadPolicy.item_path("/items", 1)] = ["future"]
	var result: Dictionary = policy.merge(
		current,
		source,
		deletions
	)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_true(
		_matches(
			result.get("payload"),
			current
		)
	)
	assert_true(
		_matches(
			policy.merge(
				current,
				result.get("baseline")
			).get("payload"),
			current
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			policy.merge(
				current,
				source,
				{
					"/wrong": [1],
				}
			),
			"ok"
		)
	)


func test_duplicate_or_mistyped_identities_fail_before_projection() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"items": [
						{ "id": 1, "amount": 2 },
						{ "id": 1, "amount": 3 },
					],
				}
			),
			"ok"
		)
	)
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"items": [
						{ "id": "90" },
					],
				}
			),
			"ok"
		)
	)
	policy.collections["/items"] = {
		"id_field": "id",
		"active_ids": [1, 2],
		"preserve_unknown": false,
	}
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"items": [
						{ "id": 90 },
					],
				}
			),
			"ok"
		)
	)


func test_policy_copy_isolated_and_invalid_graphs_fail_closed() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	var copied: GFSavePayloadPolicy = policy.duplicate_policy()
	assert_not_null(copied)
	policy.retained_fields.clear()
	policy.schema.dictionary_schema.fields.clear()
	assert_true(
		GFVariantData.get_option_bool(
			copied.project(
				{
					"coins": 1,
					"future": 1,
					"items": [],
				}
			),
			"ok"
		)
	)
	policy = _policy()
	policy.collections.clear()
	assert_false(
		GFVariantData.get_option_bool(
			policy.validate_policy(),
			"ok"
		)
	)
	policy = _policy()
	policy.schema.array_item_schema = policy.schema
	assert_false(
		GFVariantData.get_option_bool(
			policy.validate_policy(),
			"ok"
		)
	)
	policy.schema.array_item_schema = null
	policy.schema.dictionary_schema.coerce_values = true
	assert_false(
		GFVariantData.get_option_bool(
			policy.validate_policy(),
			"ok"
		)
	)


func test_preserved_values_obey_native_value_and_byte_limits() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"future": Resource.new(),
					"items": [],
				}
			),
			"ok"
		)
	)
	var cyclic: Array = []
	cyclic.append(cyclic)
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"future": cyclic,
					"items": [],
				}
			),
			"ok"
		)
	)
	cyclic.clear()
	policy.max_bytes = 4096
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"future": "x".repeat(5000),
					"items": [],
				}
			),
			"ok"
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			policy.project(
				{
					"coins": 1,
					"future": Vector2(2, 3),
					"items": [],
				}
			),
			"ok"
		)
	)


func test_payload_measurement_uses_the_same_budget_without_exposing_projection() -> void:
	var policy: GFSavePayloadPolicy = GFSavePayloadPolicy.new()
	policy.schema = _field(&"root", GFSchemaField.ValueType.STRING)
	policy.max_bytes = 1024
	var valid: Dictionary = policy.measure_payload("safe")
	assert_true(GFVariantData.get_option_bool(valid, "ok"))
	assert_false(valid.has("projection"))
	assert_false(valid.has("baseline"))
	var limits: Dictionary = policy.get_limits()
	limits["max_bytes"] = 1000000
	assert_eq(policy.max_bytes, 1024)
	var oversized: String = "a".repeat(4096)
	var measured: Dictionary = policy.measure_payload(oversized)
	assert_false(GFVariantData.get_option_bool(measured, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(measured, "error_kind"),
		&"payload_budget_exceeded"
	)
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(oversized),
			"ok"
		)
	)
	var cycle: Dictionary = {}
	cycle["self"] = cycle
	assert_false(
		GFVariantData.get_option_bool(
			policy.measure_payload(cycle),
			"ok"
		)
	)
	cycle.clear()


func test_scalar_payload_needs_no_dictionary_wrapper() -> void:
	var policy: GFSavePayloadPolicy = GFSavePayloadPolicy.new()
	policy.schema = _field(&"root", GFSchemaField.ValueType.INT)
	var result: Dictionary = policy.project(8)
	assert_true(GFVariantData.get_option_bool(result, "ok"))
	assert_true(
		_matches(
			policy.merge(
				9,
				result.get("baseline")
			).get("payload"),
			9
		)
	)


func test_reactivated_content_is_validated_before_entering_runtime() -> void:
	var policy: GFSavePayloadPolicy = _policy()
	var payload: Dictionary = {
		"coins": 1,
		"items": [
			{
				"id": 90,
				"amount": 3,
				"future": "kept",
			},
		],
	}
	var old: Dictionary = policy.project(payload)
	assert_true(GFVariantData.get_option_bool(old, "ok"))
	var old_projection: Dictionary = GFVariantData.get_option_dictionary(old, "projection")
	assert_true(GFVariantData.get_option_array(old_projection, "items").is_empty())
	policy.collections["/items"] = {
		"id_field": "id",
		"active_ids": [
			1,
			2,
			90,
		],
		"preserve_unknown": true,
	}
	var activated: Dictionary = policy.project(old.get("baseline"))
	assert_true(GFVariantData.get_option_bool(activated, "ok"))
	var active_projection: Dictionary = GFVariantData.get_option_dictionary(activated, "projection")
	assert_true(
		_matches(
			active_projection.get("items"),
			[
				{ "id": 90, "amount": 3 },
			]
		)
	)
	payload["items"] = [
		{ "id": 90, "amount": "wrong" },
	]
	assert_false(
		GFVariantData.get_option_bool(
			policy.project(payload),
			"ok"
		)
	)


# --- 私有/辅助方法 ---

func _policy() -> GFSavePayloadPolicy:
	var policy: GFSavePayloadPolicy = GFSavePayloadPolicy.new()
	var root: GFDictionarySchema = GFDictionarySchema.new()
	var row: GFDictionarySchema = GFDictionarySchema.new()
	row.fields = [_field(&"id", GFSchemaField.ValueType.INT), _field(&"amount", GFSchemaField.ValueType.INT)]
	var item: GFSchemaField = _field(&"item", GFSchemaField.ValueType.DICTIONARY)
	item.dictionary_schema = row
	var items: GFSchemaField = _field(&"items", GFSchemaField.ValueType.ARRAY)
	items.array_item_schema = item
	root.fields = [_field(&"coins", GFSchemaField.ValueType.INT), items]
	policy.schema = _field(&"root", GFSchemaField.ValueType.DICTIONARY)
	policy.schema.dictionary_schema = root
	policy.retained_fields = {
		"": PackedStringArray(["future"]),
		"/items/*": PackedStringArray(["future"]),
	}
	policy.collections = {
		"/items": {
			"id_field": "id",
			"active_ids": [1, 2],
			"preserve_unknown": true,
		},
	}
	return policy


func _field(field_name: StringName, type: GFSchemaField.ValueType) -> GFSchemaField:
	return GFSchemaField.new().configure(
		field_name,
		type,
		{ "required": true, "allow_null": false }
	)


func _matches(left: Variant, right: Variant) -> bool:
	return left == right
