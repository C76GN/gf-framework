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
const _GLTF_OWNED_PAYLOAD_HASH_KEY: StringName = &"gf_asset_metadata_gltf_owned_payload_hash"


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

	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA, metadata)
	node.set_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE, _GLTF_NODE_EXTRAS_SOURCE)
	node.set_meta(_GLTF_OWNED_PAYLOAD_HASH_KEY, _make_payload_hash(metadata))
	return OK


# --- 私有/辅助方法 ---

func _clear_gltf_metadata_if_owned(node: Node) -> void:
	if not node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE):
		_clear_ownership_marker(node)
		return
	if GFVariantData.to_text(node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)) != _GLTF_NODE_EXTRAS_SOURCE:
		_clear_ownership_marker(node)
		return
	if not _has_unchanged_owned_payload(node):
		node.remove_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)
		_clear_ownership_marker(node)
		return
	if node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA):
		node.remove_meta(GFAssetMetadataUtility.META_ASSET_METADATA)
	node.remove_meta(GFAssetMetadataUtility.META_ASSET_METADATA_SOURCE)
	_clear_ownership_marker(node)


func _has_unchanged_owned_payload(node: Node) -> bool:
	if not node.has_meta(_GLTF_OWNED_PAYLOAD_HASH_KEY):
		return false
	if not node.has_meta(GFAssetMetadataUtility.META_ASSET_METADATA):
		return false
	var metadata: Dictionary = GFAssetMetadataUtility.normalize_metadata(
		node.get_meta(GFAssetMetadataUtility.META_ASSET_METADATA)
	)
	return GFVariantData.to_text(node.get_meta(_GLTF_OWNED_PAYLOAD_HASH_KEY)) == _make_payload_hash(metadata)


func _make_payload_hash(metadata: Dictionary) -> String:
	return JSON.stringify(metadata, "", true).sha256_text()


func _clear_ownership_marker(node: Node) -> void:
	if node.has_meta(_GLTF_OWNED_PAYLOAD_HASH_KEY):
		node.remove_meta(_GLTF_OWNED_PAYLOAD_HASH_KEY)
