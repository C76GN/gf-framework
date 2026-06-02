# GFAssetMetadataRecord

[API Reference](../index.md) / [Asset Metadata](../extensions-asset-metadata.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/asset_metadata/resources/gf_asset_metadata_record.gd`
- 模块：`Asset Metadata`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

资产元数据记录。 记录某个导入资产、节点或资源片段上的结构化元数据，不解释字段业务含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`source_path`](#member-gfassetmetadatarecord-properties-source_path) | `var source_path: String = ""` |
| 属性 | [`subject_path`](#member-gfassetmetadatarecord-properties-subject_path) | `var subject_path: NodePath = NodePath(".")` |
| 属性 | [`subject_kind`](#member-gfassetmetadatarecord-properties-subject_kind) | `var subject_kind: StringName = &""` |
| 属性 | [`metadata`](#member-gfassetmetadatarecord-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfassetmetadatarecord-methods-configure) | `func configure( p_source_path: String = "", p_subject_path: NodePath = NodePath("."), p_subject_kind: StringName = &"", p_metadata: Dictionary = {} ) -> GFAssetMetadataRecord:` |
| 方法 | [`is_empty`](#member-gfassetmetadatarecord-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`has_value`](#member-gfassetmetadatarecord-methods-has_value) | `func has_value(key: StringName) -> bool:` |
| 方法 | [`get_value`](#member-gfassetmetadatarecord-methods-get_value) | `func get_value(key: StringName, default_value: Variant = null) -> Variant:` |
| 方法 | [`to_dict`](#member-gfassetmetadatarecord-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfassetmetadatarecord-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`duplicate_record`](#member-gfassetmetadatarecord-methods-duplicate_record) | `func duplicate_record() -> GFAssetMetadataRecord:` |
| 方法 | [`from_dict`](#member-gfassetmetadatarecord-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFAssetMetadataRecord:` |

## 属性

<a id="member-gfassetmetadatarecord-properties-source_path"></a>

### `source_path`

- API：`public`

```gdscript
var source_path: String = ""
```

元数据来源资产路径。

<a id="member-gfassetmetadatarecord-properties-subject_path"></a>

### `subject_path`

- API：`public`

```gdscript
var subject_path: NodePath = NodePath(".")
```

元数据所属对象相对路径。节点树中通常是相对根节点的 NodePath。

<a id="member-gfassetmetadatarecord-properties-subject_kind"></a>

### `subject_kind`

- API：`public`

```gdscript
var subject_kind: StringName = &""
```

元数据所属对象类别，例如 node、resource 或 asset。

<a id="member-gfassetmetadatarecord-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

结构化元数据。框架只复制和查询，不解释业务字段。

结构：

- `metadata`: Dictionary，保存导入资产、节点或资源片段的项目自定义元数据字段。

## 方法

<a id="member-gfassetmetadatarecord-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure( p_source_path: String = "", p_subject_path: NodePath = NodePath("."), p_subject_kind: StringName = &"", p_metadata: Dictionary = {} ) -> GFAssetMetadataRecord:
```

配置记录。

参数：

| 名称 | 说明 |
|---|---|
| `p_source_path` | 来源资产路径。 |
| `p_subject_path` | 所属对象路径。 |
| `p_subject_kind` | 所属对象类别。 |
| `p_metadata` | 结构化元数据。 |

返回：当前记录。

结构：

- `p_metadata`: Dictionary，保存导入资产、节点或资源片段的项目自定义元数据字段。

<a id="member-gfassetmetadatarecord-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查记录是否没有元数据。

返回：没有元数据时返回 true。

<a id="member-gfassetmetadatarecord-methods-has_value"></a>

### `has_value`

- API：`public`

```gdscript
func has_value(key: StringName) -> bool:
```

检查元数据键是否存在。StringName 与 String 形式会被同时识别。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |

返回：存在时返回 true。

<a id="member-gfassetmetadatarecord-methods-get_value"></a>

### `get_value`

- API：`public`

```gdscript
func get_value(key: StringName, default_value: Variant = null) -> Variant:
```

读取元数据值并返回安全副本。

参数：

| 名称 | 说明 |
|---|---|
| `key` | 元数据键。 |
| `default_value` | 缺失时返回的默认值。 |

返回：元数据值副本或默认值。

结构：

- `default_value`: Variant，缺失时返回的调用方默认值，会按 GFVariantData 规则复制。
- `return`: Variant，元数据值副本；缺失时为 default_value 的安全副本。

<a id="member-gfassetmetadatarecord-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为字典。

返回：记录字典副本。

结构：

- `return`: Dictionary，包含 source_path、subject_path、subject_kind 与 metadata 字段。

<a id="member-gfassetmetadatarecord-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

结构：

- `data`: Dictionary，可包含 source_path、subject_path、subject_kind 与 metadata 字段。

<a id="member-gfassetmetadatarecord-methods-duplicate_record"></a>

### `duplicate_record`

- API：`public`

```gdscript
func duplicate_record() -> GFAssetMetadataRecord:
```

创建记录深拷贝。

返回：新记录。

<a id="member-gfassetmetadatarecord-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary) -> GFAssetMetadataRecord:
```

从字典创建记录。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 输入字典。 |

返回：新记录。

结构：

- `data`: Dictionary，可包含 source_path、subject_path、subject_kind 与 metadata 字段。
