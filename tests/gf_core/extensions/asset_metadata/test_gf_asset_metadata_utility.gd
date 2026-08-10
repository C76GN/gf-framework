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
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_eq(GFVariantData.get_option_string(normalized, "kind"), "asset", "schema 默认值应补齐 metadata。")
	assert_eq(GFVariantData.get_option_int(normalized, "priority"), 4, "schema 应按字段声明转换 metadata。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "严格校验应基于 raw metadata，required 字段缺失不能被默认值掩盖。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_required")

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


func test_write_without_source_clears_stale_source_marker() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()
	var _first_record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "imported" }, {
		"metadata_source": "importer",
	})
	var _replacement_record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "manual" })

	assert_true(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA))
	assert_false(
		node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE),
		"没有显式来源的新写入必须清理旧来源，避免错误归属。"
	)

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


func test_empty_metadata_clears_marker_unless_explicitly_marked_scanned_empty() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var node: Node = Node.new()

	var _record: GFAssetMetadataRecord = utility.write_object_metadata(node, { "kind": "asset" }, {
		"metadata_source": "scan",
	})
	var _empty_record: GFAssetMetadataRecord = utility.write_object_metadata(node, {})

	assert_false(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "默认写入空 metadata 应删除旧 marker。")
	assert_false(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE), "默认写入空 metadata 应删除旧 source marker。")
	assert_eq(
		utility.get_object_metadata_state(node),
		GFAssetMetadataUtility.METADATA_STATE_ABSENT,
		"默认空 metadata 应表达为 absent。"
	)
	assert_false(utility.has_object_metadata(node), "默认空 metadata 不应被 has_object_metadata 视为存在。")

	var _marked_record: GFAssetMetadataRecord = utility.write_object_metadata(node, {}, {
		"mark_scanned_empty": true,
	})

	assert_true(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "显式 opt-in 时应保留空扫描 marker。")
	assert_eq(
		utility.get_object_metadata_state(node),
		GFAssetMetadataUtility.METADATA_STATE_EMPTY,
		"显式空扫描 marker 应表达为 empty。"
	)
	assert_true(utility.has_object_metadata(node), "显式空扫描 marker 应被视为存在状态。")

	node.free()


func test_collect_node_tree_preserves_explicit_scanned_empty_record() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var root: Node = Node.new()
	var _record: GFAssetMetadataRecord = utility.write_object_metadata(root, {}, {
		"mark_scanned_empty": true,
	})

	var records: Array[GFAssetMetadataRecord] = utility.collect_node_tree(root)

	assert_eq(records.size(), 1, "显式空扫描结果不能在收集阶段退化为 absent。")
	assert_true(records[0].metadata.is_empty())

	root.free()


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
	var issue_kinds: Array[String] = []
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		issue_kinds.append(GFVariantData.get_option_string(issue, "kind"))

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未知字段应被 schema 校验报告。")
	assert_true(issue_kinds.has("extra_field"), "未知字段应被 schema 校验报告。")

	node.free()


func test_build_node_tree_report_reports_missing_root() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var report: Dictionary = utility.build_node_tree_report(null)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少 root 时报告应失败。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1)
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_root")


func test_build_node_tree_report_defaults_to_json_safe_entries() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var root: Node = Node.new()
	var texture: Resource = Resource.new()
	var _record: GFAssetMetadataRecord = utility.write_object_metadata(root, {
		"position": Vector2(1.0, 2.0),
		"bad_number": NAN,
		"preview": texture,
	})

	var report: Dictionary = utility.build_node_tree_report(root)
	var entries: Array = GFVariantData.get_option_array(report, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])
	var metadata: Dictionary = GFVariantData.get_option_dictionary(first_entry, "metadata")
	var encoded_position: Dictionary = GFVariantData.get_option_dictionary(metadata, "position")
	var encoded_bad_number: Dictionary = GFVariantData.get_option_dictionary(metadata, "bad_number")
	var encoded_preview: Dictionary = GFVariantData.get_option_dictionary(metadata, "preview")
	var preview_marker: Dictionary = GFVariantData.get_option_dictionary(
		encoded_preview,
		"__gf_report_value__"
	)

	assert_true(encoded_position.has(GFVariantJsonCodec.JSON_MARKER_KEY), "Vector2 元数据应编码为 JSON-safe typed marker。")
	assert_true(encoded_bad_number.has(GFVariantJsonCodec.JSON_MARKER_KEY), "NaN 元数据应编码为 JSON-safe typed marker。")
	assert_true(metadata.has("preview"), "Resource 字段应保留字段名。")
	assert_eq(
		GFVariantData.get_option_string(preview_marker, "type"),
		"Object",
		"Resource 应由统一报告编码器保留为脱敏 marker。"
	)
	var json_text: String = JSON.stringify(report)
	assert_true(JSON.parse_string(json_text) is Dictionary, "节点树报告应可真实 JSON stringify/parse round-trip。")

	root.free()


func test_build_node_tree_report_reports_max_nodes_truncation() -> void:
	var utility: GFAssetMetadataUtility = GFAssetMetadataUtility.new()
	var root: Node = Node.new()
	root.name = "Root"
	var first_child: Node = Node.new()
	first_child.name = "First"
	var second_child: Node = Node.new()
	second_child.name = "Second"
	root.add_child(first_child)
	root.add_child(second_child)
	var _root_record: GFAssetMetadataRecord = utility.write_object_metadata(root, { "kind": "root" })
	var _first_record: GFAssetMetadataRecord = utility.write_object_metadata(first_child, { "kind": "first" })
	var _second_record: GFAssetMetadataRecord = utility.write_object_metadata(second_child, { "kind": "second" })

	var report: Dictionary = utility.build_node_tree_report(root, { "max_nodes": 2 })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "截断不是数据错误，应通过报告字段表达。")
	assert_true(GFVariantData.get_option_bool(report, "truncated"), "达到 max_nodes 时报告应标记 truncated。")
	assert_eq(GFVariantData.get_option_int(report, "visited_node_count"), 2, "visited_node_count 应反映扫描预算。")
	assert_eq(GFVariantData.get_option_int(report, "max_nodes"), 2, "报告应保留 max_nodes。")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 2, "entry_count 应只统计已访问节点。")

	root.free()


func test_extension_installer_registers_asset_metadata_utility() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var installer_script: Script = load("res://addons/gf/extensions/asset_metadata/extension.gd")
	var installer_value: Variant = installer_script.call(&"new")
	assert_true(installer_value is GFInstaller, "Asset Metadata installer 脚本应创建 GFInstaller。")
	var installer: GFInstaller = installer_value

	installer.install(architecture, GFAsyncScope.new())

	assert_not_null(
		architecture.get_local_utility(GFAssetMetadataUtility),
		"Asset Metadata installer 应注册 GFAssetMetadataUtility。"
	)
