## 测试 GFAssetMetadataRecord 的复制与字典转换。
extends GutTest


func test_record_duplicates_metadata() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configure_result_7: Variant = record.configure("res://assets/tree.glb", NodePath("Root/Branch"), &"node", {
		"nested": {
			"hp": 3,
		},
	})

	var duplicated_record: GFAssetMetadataRecord = record.duplicate_record()
	var duplicated_nested: Dictionary = GFVariantData.get_option_dictionary(duplicated_record.metadata, "nested")
	duplicated_nested["hp"] = 9

	var record_nested: Dictionary = GFVariantData.get_option_dictionary(record.metadata, "nested")
	assert_eq(GFVariantData.get_option_int(record_nested, "hp"), 3, "记录副本不应共享嵌套 metadata。")
	assert_eq(duplicated_record.source_path, "res://assets/tree.glb")
	assert_eq(duplicated_record.subject_path, NodePath("Root/Branch"))
	assert_eq(duplicated_record.subject_kind, &"node")


func test_get_value_supports_string_name_and_string_keys() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	record.metadata = {
		"group": "environment",
		&"tags": ["forest"],
	}

	var tags: Array = record.get_value(&"tags")
	tags.append("changed")

	assert_true(record.has_value(&"group"), "StringName 查询应能读取 String 键。")
	assert_eq(GFVariantData.to_text(record.get_value(&"group")), "environment")
	assert_eq(GFVariantData.get_option_array(record.metadata, &"tags").size(), 1, "读取集合值时应返回副本。")


func test_apply_dict_ignores_non_dictionary_metadata() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	record.apply_dict({
		"source_path": "res://asset.glb",
		"subject_path": "Node",
		"subject_kind": "node",
		"metadata": "bad",
	})

	assert_eq(record.source_path, "res://asset.glb")
	assert_eq(record.subject_path, NodePath("Node"))
	assert_eq(record.subject_kind, &"node")
	assert_true(record.metadata.is_empty(), "非 Dictionary metadata 不应进入记录。")


func test_apply_dict_replaces_existing_fields_instead_of_patch_merging() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configured_record: GFAssetMetadataRecord = record.configure("res://assets/old.glb", NodePath("Old"), &"node", {
		"old": true,
	})

	record.apply_dict({
		"metadata": "bad",
	})

	assert_eq(record.source_path, "", "缺失 source_path 时 apply_dict 应按完整替换清空旧值。")
	assert_eq(record.subject_path, NodePath("."), "缺失 subject_path 时 apply_dict 应回到默认根路径。")
	assert_eq(record.subject_kind, &"", "缺失 subject_kind 时 apply_dict 应清空旧类别。")
	assert_true(record.metadata.is_empty(), "坏 metadata 输入不应保留旧 metadata。")


func test_source_path_is_canonicalized_for_records() -> void:
	var record: GFAssetMetadataRecord = GFAssetMetadataRecord.new()
	var _configure_result: GFAssetMetadataRecord = record.configure(
		"res://assets/../assets\\tree.glb",
		NodePath("."),
		&"asset",
		{}
	)

	assert_eq(record.source_path, "res://assets/tree.glb", "记录 source_path 应规范化分隔符和 . / .. 片段。")
