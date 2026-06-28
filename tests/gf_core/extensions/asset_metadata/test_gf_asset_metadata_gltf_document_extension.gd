## 测试 GFAssetMetadataGltfDocumentExtension 的 glTF extras 桥接。
extends GutTest


func test_import_node_copies_gltf_extras_to_asset_metadata() -> void:
	var extension: GFAssetMetadataGltfDocumentExtension = GFAssetMetadataGltfDocumentExtension.new()
	var node: Node = Node.new()
	var extras: Dictionary = {
		"authoring_id": "door_01",
		"asset_uid": "uid://door",
		"schema_id": "prop_metadata",
		"schema_version": 2,
		"nested": {
			"locked": true,
		},
	}

	var error: Error = extension._import_node(null, null, { "extras": extras }, node)
	extras["nested"]["locked"] = false
	var metadata: Dictionary = GFVariantData.as_dictionary(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA))
	var nested_metadata: Dictionary = GFVariantData.get_option_dictionary(metadata, "nested")
	var provenance: Dictionary = GFVariantData.get_option_dictionary(metadata, "_gf_provenance")

	assert_eq(error, OK)
	assert_eq(GFVariantData.get_option_string(metadata, "authoring_id"), "door_01")
	assert_eq(GFVariantData.get_option_bool(nested_metadata, "locked"), true, "导入 metadata 应深拷贝。")
	assert_eq(GFVariantData.get_option_string(provenance, "source"), "gltf_node_extras", "导入 metadata 应包含 GF provenance source。")
	assert_eq(GFVariantData.get_option_string(provenance, "asset_uid"), "uid://door", "extras 中的 asset_uid 应进入 provenance。")
	assert_eq(GFVariantData.get_option_string(provenance, "schema_id"), "prop_metadata", "extras 中的 schema_id 应进入 provenance。")
	assert_eq(GFVariantData.get_option_int(provenance, "schema_version"), 2, "extras 中的 schema_version 应进入 provenance。")
	assert_eq(GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)), "gltf_node_extras")

	node.free()


func test_import_node_ignores_nodes_without_extras() -> void:
	var extension: GFAssetMetadataGltfDocumentExtension = GFAssetMetadataGltfDocumentExtension.new()
	var node: Node = Node.new()

	var error: Error = extension._import_node(null, null, {}, node)

	assert_eq(error, OK)
	assert_false(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA))

	node.free()


func test_import_node_clears_previous_gltf_metadata_when_extras_are_missing() -> void:
	var extension: GFAssetMetadataGltfDocumentExtension = GFAssetMetadataGltfDocumentExtension.new()
	var node: Node = Node.new()
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA, { "old": true })
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE, "gltf_node_extras")

	var error: Error = extension._import_node(null, null, {}, node)

	assert_eq(error, OK)
	assert_false(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "缺失 extras 时应清理之前由 glTF extras 写入的 metadata。")
	assert_false(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE), "缺失 extras 时应清理对应 source。")

	node.free()


func test_import_node_preserves_non_gltf_metadata_when_extras_are_missing() -> void:
	var extension: GFAssetMetadataGltfDocumentExtension = GFAssetMetadataGltfDocumentExtension.new()
	var node: Node = Node.new()
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA, { "manual": true })
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE, "manual")

	var error: Error = extension._import_node(null, null, {}, node)

	assert_eq(error, OK)
	assert_true(node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA), "非 glTF source 的 metadata 不应被导入桥接清理。")
	assert_eq(GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)), "manual")

	node.free()
