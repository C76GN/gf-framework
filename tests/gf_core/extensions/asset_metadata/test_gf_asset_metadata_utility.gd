## 测试 GFAssetMetadataUtility 的对象读写和节点树收集。
extends GutTest


func test_write_and_read_object_metadata_use_safe_copies() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()
	var source_metadata: Dictionary = {
		"nested": {
			"value": 1,
		},
	}

	var record: GFAssetMetadataRecord = utility.write_object_metadata(node, source_metadata, {
		"source_path": "res://assets/item.glb",
		"subject_path": "Item",
		"subject_kind": &"node",
		"metadata_source": "test",
	})
	source_metadata["nested"]["value"] = 9
	var read_metadata: Dictionary = utility.read_object_metadata(node)
	var read_nested: Dictionary = GFVariantData.get_option_dictionary(read_metadata, "nested")
	read_nested["value"] = 7

	assert_true(utility.has_object_metadata(node), "写入后对象应带有资产元数据。")
	var stored_metadata: Dictionary = GFVariantData.as_dictionary(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA))
	var stored_nested: Dictionary = GFVariantData.get_option_dictionary(stored_metadata, "nested")
	assert_eq(GFVariantData.get_option_int(stored_nested, "value"), 1, "对象 metadata 应保存输入副本。")
	assert_eq(record.source_path, "res://assets/item.glb")
	assert_eq(record.subject_path, NodePath("Item"))
	assert_eq(record.subject_kind, &"node")
	assert_eq(GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)), "test")

	node.free()


func test_collect_node_tree_returns_relative_paths() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var root: Node = Node.new()
	root.name = "Root"
	var branch: Node = Node.new()
	branch.name = "Branch"
	var leaf: Node = Node.new()
	leaf.name = "Leaf"
	root.add_child(branch)
	branch.add_child(leaf)
	var _write_object_metadata_result_47: Variant = utility.write_object_metadata(root, { "root": true })
	var _write_object_metadata_result_48: Variant = utility.write_object_metadata(leaf, { "leaf": true })

	var records: Array[GFAssetMetadataRecord] = utility.collect_node_tree(root, {
		"source_path": "res://assets/tree.glb",
	})

	assert_eq(records.size(), 2, "应收集根节点和子节点元数据。")
	assert_eq(records[0].source_path, "res://assets/tree.glb")
	assert_eq(records[0].subject_path, NodePath("."))
	assert_eq(records[1].subject_path, NodePath("Branch/Leaf"))
	assert_eq(GFVariantData.get_option_bool(records[1].metadata, "leaf"), true)

	root.free()


func test_collect_node_tree_respects_custom_keys_and_depth() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var root: Node = Node.new()
	var child: Node = Node.new()
	root.add_child(child)
	child.set_meta(&"custom_metadata", {
		"kind": "child",
	})

	var no_depth_records: Array[GFAssetMetadataRecord] = utility.collect_node_tree(root, {
		"metadata_keys": [&"custom_metadata"],
		"max_depth": 0,
	})
	var records: Array[GFAssetMetadataRecord] = utility.collect_node_tree(root, {
		"metadata_keys": [&"custom_metadata"],
		"max_depth": 1,
	})

	assert_true(no_depth_records.is_empty(), "max_depth 为 0 时不应进入子节点。")
	assert_eq(records.size(), 1, "自定义 metadata key 应可被收集。")
	assert_eq(GFVariantData.get_option_string(records[0].metadata, "kind"), "child")

	root.free()


func test_object_metadata_can_use_dictionary_schema() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = &"asset_metadata"
	schema.coerce_values = true
	schema.allow_extra_fields = false
	var _kind_added: bool = schema.add_field(GFSchemaField.new().configure(&"kind", GFSchemaField.ValueType.STRING, {
		"required": true,
		"allow_null": false,
		"default_value": "asset",
	}))
	var _priority_added: bool = schema.add_field(GFSchemaField.new().configure(&"priority", GFSchemaField.ValueType.INT, {
		"default_value": 0,
	}))
	var _write_metadata_result: GFAssetMetadataRecord = utility.write_object_metadata(node, {
		"priority": "4",
	})

	var normalized: Dictionary = utility.read_object_metadata_with_schema(node, schema)
	var report: Dictionary = utility.validate_object_metadata(node, schema)

	assert_eq(GFVariantData.get_option_string(normalized, "kind"), "asset", "schema 默认值应补齐 metadata。")
	assert_eq(GFVariantData.get_option_int(normalized, "priority"), 4, "schema 应按字段声明转换 metadata。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "按 schema 补默认值和转换后应通过校验。")

	node.free()


func test_validate_object_metadata_reports_missing_target() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.allow_extra_fields = true

	var report: Dictionary = utility.validate_object_metadata(null, schema)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少目标对象时 schema 默认值不应掩盖错误。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_target")


func test_metadata_source_is_scoped_per_metadata_key() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()

	var _default_record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "default" }, {
		"metadata_source": "default_source",
	})
	var _custom_record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "custom" }, {
		"metadata_key": &"custom_metadata",
		"metadata_source": "custom_source",
	})

	assert_eq(
		GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)),
		"default_source",
		"写入自定义 metadata key 不应覆盖默认 key 的 source。"
	)
	assert_eq(
		GFVariantData.to_text(node.get_meta(&"gf_asset_metadata_source__637573746f6d5f6d65746164617461")),
		"custom_source",
		"自定义 metadata key 应拥有独立 source。"
	)

	utility.clear_object_metadata(node, { "metadata_key": &"custom_metadata" })

	assert_true(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "清理自定义 key 不应删除默认 metadata。")
	assert_eq(
		GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)),
		"default_source",
		"清理自定义 key 不应删除默认 metadata 的 source。"
	)
	assert_false(node.has_meta(&"gf_asset_metadata_source__637573746f6d5f6d65746164617461"), "清理自定义 key 应删除对应 source。")

	node.free()


func test_empty_singular_metadata_key_falls_back_to_default_key() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()

	var _record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "asset" }, {
		"metadata_key": "",
	})

	assert_true(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "空 metadata_key 应回退默认 key。")
	assert_false(node.get_meta_list().has(&""), "空 metadata_key 不应创建空 Object metadata。")

	node.free()


func test_validate_object_metadata_reports_unknown_fields_after_schema_normalization() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	schema.schema_id = &"asset_metadata"
	schema.coerce_values = true
	schema.allow_extra_fields = false
	var _kind_added: bool = schema.add_field(GFSchemaField.new().configure(&"kind", GFSchemaField.ValueType.STRING, {
		"required": true,
		"default_value": "asset",
	}))
	var _priority_added: bool = schema.add_field(GFSchemaField.new().configure(&"priority", GFSchemaField.ValueType.INT, {
		"default_value": 0,
	}))
	var _record: GFAssetMetadataRecord = utility.write_object_metadata(node, {
		"priority": "4",
		"legacy": true,
	})

	var report: Dictionary = utility.validate_object_metadata(node, schema)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未知字段应被 schema 校验报告。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "extra_field")

	node.free()


func test_build_node_tree_report_reports_missing_root() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var report: Dictionary = utility.build_node_tree_report(null)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少 root 时报告应失败。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1)
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_root")


func test_extension_installer_registers_asset_metadata_utility() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer_script: Script = load("res://addons/gf/extensions/asset_metadata/extension.gd")
	var installer_value: Variant = installer_script.call(&"new")
	assert_true(installer_value is GFInstaller, "Asset Metadata installer 脚本应创建 GFInstaller。")
	var installer: GFInstaller = installer_value

	installer.install(architecture)

	assert_not_null(
		architecture.get_local_utility(GFAssetMetadataUtility),
		"Asset Metadata installer 应注册 GFAssetMetadataUtility。"
	)
