# GFAssetMetadataGltfDocumentExtension

[API Reference](../index.md) / [Asset Metadata](../extensions-asset-metadata.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/asset_metadata/editor/gf_asset_metadata_gltf_document_extension.gd`
- 模块：`Asset Metadata`
- 继承：`GLTFDocumentExtension`
- API：`public`
- 类别：编辑器 API (`editor_api`)
- 首次版本：`3.17.0`

将 glTF extras 桥接为 GF 资产元数据。 导入节点时只复制通用 extras 数据，不解释字段含义，也不创建业务对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_import_node`](#member-gfassetmetadatagltfdocumentextension-methods-_import_node) | `func _import_node( _state: GLTFState, _gltf_node: GLTFNode, json: Dictionary, node: Node ) -> Error:` |

## 方法

<a id="member-gfassetmetadatagltfdocumentextension-methods-_import_node"></a>

### `_import_node`

- API：`protected`

```gdscript
func _import_node( _state: GLTFState, _gltf_node: GLTFNode, json: Dictionary, node: Node ) -> Error:
```

导入 glTF 节点时把 json.extras 写入节点元数据。

参数：

| 名称 | 说明 |
|---|---|
| `_state` | glTF 导入状态。 |
| `_gltf_node` | 正在导入的 glTF 节点描述。 |
| `json` | glTF 节点原始 JSON 字典。 |
| `node` | 导入生成的 Godot 节点。 |

返回：Godot 错误码。

结构：

- `json`: Dictionary，可包含 extras 字段；extras 会归一化为资产元数据字典。
