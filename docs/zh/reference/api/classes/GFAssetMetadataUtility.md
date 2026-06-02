# GFAssetMetadataUtility

[API Reference](../index.md) / [Asset Metadata](../extensions-asset-metadata.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/asset_metadata/runtime/gf_asset_metadata_utility.gd`
- 模块：`Asset Metadata`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

资产元数据收集与查询工具。 统一管理导入资产元数据在 Object metadata 中的存储键、复制规则和节点树收集流程。 它不解释任何项目字段；业务语义应由项目代码或项目扩展消费。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`META_ASSET_METADATA`](#member-gfassetmetadatautility-constants-meta_asset_metadata) | `const META_ASSET_METADATA: StringName = &"gf_asset_metadata"` |
| 常量 | [`META_ASSET_METADATA_SOURCE`](#member-gfassetmetadatautility-constants-meta_asset_metadata_source) | `const META_ASSET_METADATA_SOURCE: StringName = &"gf_asset_metadata_source"` |
| 方法 | [`normalize_metadata`](#member-gfassetmetadatautility-methods-normalize_metadata) | `static func normalize_metadata(value: Variant) -> Dictionary:` |
| 方法 | [`write_object_metadata`](#member-gfassetmetadatautility-methods-write_object_metadata) | `func write_object_metadata( target: Object, metadata: Dictionary, options: Dictionary = {} ) -> GFAssetMetadataRecord:` |
| 方法 | [`read_object_metadata`](#member-gfassetmetadatautility-methods-read_object_metadata) | `func read_object_metadata(target: Object, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`has_object_metadata`](#member-gfassetmetadatautility-methods-has_object_metadata) | `func has_object_metadata(target: Object, options: Dictionary = {}) -> bool:` |
| 方法 | [`clear_object_metadata`](#member-gfassetmetadatautility-methods-clear_object_metadata) | `func clear_object_metadata(target: Object, options: Dictionary = {}) -> void:` |
| 方法 | [`collect_node_tree`](#member-gfassetmetadatautility-methods-collect_node_tree) | `func collect_node_tree(root: Node, options: Dictionary = {}) -> Array[GFAssetMetadataRecord]:` |
| 方法 | [`collect_node_tree_dicts`](#member-gfassetmetadatautility-methods-collect_node_tree_dicts) | `func collect_node_tree_dicts(root: Node, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`build_node_tree_report`](#member-gfassetmetadatautility-methods-build_node_tree_report) | `func build_node_tree_report(root: Node, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfassetmetadatautility-constants-meta_asset_metadata"></a>

### `META_ASSET_METADATA`

- API：`public`

```gdscript
const META_ASSET_METADATA: StringName = &"gf_asset_metadata"
```

Object metadata 中保存 GF 资产元数据的默认键。

<a id="member-gfassetmetadatautility-constants-meta_asset_metadata_source"></a>

### `META_ASSET_METADATA_SOURCE`

- API：`public`

```gdscript
const META_ASSET_METADATA_SOURCE: StringName = &"gf_asset_metadata_source"
```

Object metadata 中保存元数据来源说明的默认键。

## 方法

<a id="member-gfassetmetadatautility-methods-normalize_metadata"></a>

### `normalize_metadata`

- API：`public`

```gdscript
static func normalize_metadata(value: Variant) -> Dictionary:
```

将任意导入元数据归一为 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 输入元数据。Dictionary 会深拷贝；其他非 null 值会保存在 value 字段中。 |

返回：归一化后的元数据字典。

结构：

- `value`: Variant，Dictionary 会深拷贝；其他非 null 值会保存为 { "value": value }。
- `return`: Dictionary，归一化后的资产元数据字段。

<a id="member-gfassetmetadatautility-methods-write_object_metadata"></a>

### `write_object_metadata`

- API：`public`

```gdscript
func write_object_metadata( target: Object, metadata: Dictionary, options: Dictionary = {} ) -> GFAssetMetadataRecord:
```

写入对象资产元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标 Object。 |
| `metadata` | 结构化元数据。 |
| `options` | 可选项，支持 metadata_key、source_path、subject_path、subject_kind、metadata_source。 |

返回：写入后的记录；目标无效时返回 null。

结构：

- `metadata`: Dictionary，要写入 Object metadata 的结构化资产元数据字段。
- `options`: Dictionary，可包含 metadata_key、source_path、subject_path、subject_kind 与 metadata_source。

<a id="member-gfassetmetadatautility-methods-read_object_metadata"></a>

### `read_object_metadata`

- API：`public`

```gdscript
func read_object_metadata(target: Object, options: Dictionary = {}) -> Dictionary:
```

读取对象资产元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标 Object。 |
| `options` | 可选项，支持 metadata_key 或 metadata_keys。 |

返回：元数据字典副本；不存在时返回空字典。

结构：

- `options`: Dictionary，可包含 metadata_key 或 metadata_keys。
- `return`: Dictionary，读取到的结构化资产元数据字段。

<a id="member-gfassetmetadatautility-methods-has_object_metadata"></a>

### `has_object_metadata`

- API：`public`

```gdscript
func has_object_metadata(target: Object, options: Dictionary = {}) -> bool:
```

检查对象是否带有资产元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标 Object。 |
| `options` | 可选项，支持 metadata_key 或 metadata_keys。 |

返回：存在资产元数据时返回 true。

结构：

- `options`: Dictionary，可包含 metadata_key 或 metadata_keys。

<a id="member-gfassetmetadatautility-methods-clear_object_metadata"></a>

### `clear_object_metadata`

- API：`public`

```gdscript
func clear_object_metadata(target: Object, options: Dictionary = {}) -> void:
```

清除对象资产元数据。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 目标 Object。 |
| `options` | 可选项，支持 metadata_key 或 metadata_keys。 |

结构：

- `options`: Dictionary，可包含 metadata_key、metadata_keys 与 clear_source。

<a id="member-gfassetmetadatautility-methods-collect_node_tree"></a>

### `collect_node_tree`

- API：`public`

```gdscript
func collect_node_tree(root: Node, options: Dictionary = {}) -> Array[GFAssetMetadataRecord]:
```

收集节点树中的资产元数据记录。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 节点树根节点。 |
| `options` | 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth。 |

返回：资产元数据记录列表。

结构：

- `options`: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。

<a id="member-gfassetmetadatautility-methods-collect_node_tree_dicts"></a>

### `collect_node_tree_dicts`

- API：`public`

```gdscript
func collect_node_tree_dicts(root: Node, options: Dictionary = {}) -> Array[Dictionary]:
```

收集节点树中的资产元数据记录字典。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 节点树根节点。 |
| `options` | 可选项，支持 metadata_key、metadata_keys、source_path、subject_kind、max_depth。 |

返回：资产元数据记录字典列表。

结构：

- `options`: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。
- `return`: Array[Dictionary]，每一项包含 source_path、subject_path、subject_kind 与 metadata 字段。

<a id="member-gfassetmetadatautility-methods-build_node_tree_report"></a>

### `build_node_tree_report`

- API：`public`

```gdscript
func build_node_tree_report(root: Node, options: Dictionary = {}) -> Dictionary:
```

构建节点树资产元数据报告。

参数：

| 名称 | 说明 |
|---|---|
| `root` | 节点树根节点。 |
| `options` | 可选项，支持 collect_node_tree() 的参数。 |

返回：报告字典。

结构：

- `options`: Dictionary，可包含 metadata_key、metadata_keys、source_path、subject_kind 与 max_depth。
- `return`: Dictionary，包含 ok、healthy、summary、next_action、source_path、entry_count、entries 与 issues。
