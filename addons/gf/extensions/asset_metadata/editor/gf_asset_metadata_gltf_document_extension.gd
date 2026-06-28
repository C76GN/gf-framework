@tool

## GFAssetMetadataGltfDocumentExtension: 将 glTF extras 桥接为 GF 资产元数据。
##
## 导入节点时只复制通用 extras 数据，不解释字段含义，也不创建业务对象。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFAssetMetadataGltfDocumentExtension
extends GLTFDocumentExtension


# --- 常量 ---

const _GLTF_NODE_EXTRAS_SOURCE: String = "gltf_node_extras"
const _GF_PROVENANCE_KEY: StringName = &"_gf_provenance"


# --- 可重写钩子 / 虚方法 ---

## 导入 glTF 节点时把 json.extras 写入节点元数据。
## [br]
## @api protected
## [br]
## @param _state: glTF 导入状态。
## [br]
## @param _gltf_node: 正在导入的 glTF 节点描述。
## [br]
## @param json: glTF 节点原始 JSON 字典。
## [br]
## @param node: 导入生成的 Godot 节点。
## [br]
## @schema json: Dictionary，可包含 extras 字段；extras 会归一化为资产元数据字典。
## [br]
## @return Godot 错误码。
func _import_node(
	_state: GLTFState,
	_gltf_node: GLTFNode,
	json: Dictionary,
	node: Node
) -> Error:
	if node == null:
		return OK

	if not json.has("extras"):
		_clear_gltf_metadata_if_owned(node)
		return OK

	var metadata: Dictionary = GFAssetMetadataUtility.normalize_metadata(
		GFVariantData.get_option_value(json, "extras")
	)
	if metadata.is_empty():
		_clear_gltf_metadata_if_owned(node)
		return OK

	metadata[_GF_PROVENANCE_KEY] = _make_provenance(metadata)
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA, metadata)
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE, _GLTF_NODE_EXTRAS_SOURCE)
	return OK


# --- 私有/辅助方法 ---

func _clear_gltf_metadata_if_owned(node: Node) -> void:
	if not node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE):
		return
	if GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)) != _GLTF_NODE_EXTRAS_SOURCE:
		return
	if node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA):
		node.remove_meta(GFAssetMetadataUtility.META_ASSET_METADATA)
	node.remove_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)


func _make_provenance(metadata: Dictionary) -> Dictionary:
	var provenance: Dictionary = {
		"source": _GLTF_NODE_EXTRAS_SOURCE,
		"bridge": "GFAssetMetadataGltfDocumentExtension",
	}
	_copy_optional_provenance_field(metadata, provenance, "asset_uid")
	_copy_optional_provenance_field(metadata, provenance, "import_preset")
	_copy_optional_provenance_field(metadata, provenance, "schema_id")
	_copy_optional_provenance_field(metadata, provenance, "schema_version")
	return provenance


func _copy_optional_provenance_field(metadata: Dictionary, provenance: Dictionary, field_name: String) -> void:
	if not metadata.has(field_name):
		return
	var value: Variant = metadata[field_name]
	if value == null:
		return
	provenance[field_name] = GFVariantData.duplicate_variant(value)
