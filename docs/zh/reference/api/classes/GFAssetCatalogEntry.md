# GFAssetCatalogEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

通用资产目录条目。 用稳定 asset_id 描述一个可被项目工具检索、预览和审计的资产。 条目可以引用一个主资源、一个预览资源和多条资源注册表条目，但不解释资产业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`asset_id`](#member-gfassetcatalogentry-properties-asset_id) | `var asset_id: StringName = &""` |
| 属性 | [`title`](#member-gfassetcatalogentry-properties-title) | `var title: String = ""` |
| 属性 | [`description`](#member-gfassetcatalogentry-properties-description) | `var description: String = ""` |
| 属性 | [`tags`](#member-gfassetcatalogentry-properties-tags) | `var tags: PackedStringArray = PackedStringArray()` |
| 属性 | [`category`](#member-gfassetcatalogentry-properties-category) | `var category: StringName = &""` |
| 属性 | [`primary_path`](#member-gfassetcatalogentry-properties-primary_path) | `var primary_path: String = ""` |
| 属性 | [`type_hint`](#member-gfassetcatalogentry-properties-type_hint) | `var type_hint: String = ""` |
| 属性 | [`preview_path`](#member-gfassetcatalogentry-properties-preview_path) | `var preview_path: String = ""` |
| 属性 | [`resource_entry_ids`](#member-gfassetcatalogentry-properties-resource_entry_ids) | `var resource_entry_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`source_id`](#member-gfassetcatalogentry-properties-source_id) | `var source_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfassetcatalogentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfassetcatalogentry-methods-configure) | `func configure( p_asset_id: StringName, p_primary_path: String = "", options: Dictionary = {} ) -> GFAssetCatalogEntry:` |
| 方法 | [`is_valid_entry`](#member-gfassetcatalogentry-methods-is_valid_entry) | `func is_valid_entry() -> bool:` |
| 方法 | [`duplicate_entry`](#member-gfassetcatalogentry-methods-duplicate_entry) | `func duplicate_entry() -> GFAssetCatalogEntry:` |
| 方法 | [`get_primary_identity`](#member-gfassetcatalogentry-methods-get_primary_identity) | `func get_primary_identity() -> GFResourceIdentity:` |
| 方法 | [`get_preview_identity`](#member-gfassetcatalogentry-methods-get_preview_identity) | `func get_preview_identity() -> GFResourceIdentity:` |
| 方法 | [`get_cache_key`](#member-gfassetcatalogentry-methods-get_cache_key) | `func get_cache_key() -> String:` |
| 方法 | [`to_dict`](#member-gfassetcatalogentry-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfassetcatalogentry-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFAssetCatalogEntry:` |
| 方法 | [`from_resource_registry_entry`](#member-gfassetcatalogentry-methods-from_resource_registry_entry) | `static func from_resource_registry_entry( registry_entry: GFResourceRegistryEntry, options: Dictionary = {} ) -> GFAssetCatalogEntry:` |

## 属性

<a id="member-gfassetcatalogentry-properties-asset_id"></a>

### `asset_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var asset_id: StringName = &""
```

资产稳定 ID。推荐由项目或 source provider 明确生成，不应直接等同资源路径。

<a id="member-gfassetcatalogentry-properties-title"></a>

### `title`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var title: String = ""
```

面向工具 UI 的显示标题；为空时可回退到 asset_id 或资源 basename。

<a id="member-gfassetcatalogentry-properties-description"></a>

### `description`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var description: String = ""
```

面向工具 UI 的简短说明或备注。

<a id="member-gfassetcatalogentry-properties-tags"></a>

### `tags`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var tags: PackedStringArray = PackedStringArray()
```

通用标签。标签只用于检索、筛选和分组，不携带业务含义。

<a id="member-gfassetcatalogentry-properties-category"></a>

### `category`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var category: StringName = &""
```

通用分类。项目可自行决定分类体系；GF 只按文本索引。

<a id="member-gfassetcatalogentry-properties-primary_path"></a>

### `primary_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var primary_path: String = ""
```

主资源路径。用于预览、打开、加载或关联 GFResourceRegistry 条目。

<a id="member-gfassetcatalogentry-properties-type_hint"></a>

### `type_hint`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var type_hint: String = ""
```

主资源类型提示。

<a id="member-gfassetcatalogentry-properties-preview_path"></a>

### `preview_path`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var preview_path: String = ""
```

可选预览资源路径。为空时工具可尝试主资源或 preview provider。

<a id="member-gfassetcatalogentry-properties-resource_entry_ids"></a>

### `resource_entry_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var resource_entry_ids: PackedStringArray = PackedStringArray()
```

关联的 GFResourceRegistry 条目 ID 列表。

<a id="member-gfassetcatalogentry-properties-source_id"></a>

### `source_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var source_id: StringName = &""
```

资产来源 ID，例如 provider、catalog 文件或项目工具来源。

<a id="member-gfassetcatalogentry-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。GF 复制和序列化该字典，但不解释字段含义。

结构：

- `metadata`: Dictionary with project-defined asset metadata.

## 方法

<a id="member-gfassetcatalogentry-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure( p_asset_id: StringName, p_primary_path: String = "", options: Dictionary = {} ) -> GFAssetCatalogEntry:
```

配置条目并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_asset_id` | 资产稳定 ID。 |
| `p_primary_path` | 主资源路径。 |
| `options` | 可选项，支持 title、description、tags、category、type_hint、preview_path、resource_entry_ids、source_id 和 metadata。 |

返回：当前条目。

结构：

- `options`: Dictionary with optional title, description, tags, category, type_hint, preview_path, resource_entry_ids, source_id, and metadata.

<a id="member-gfassetcatalogentry-methods-is_valid_entry"></a>

### `is_valid_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_valid_entry() -> bool:
```

检查条目是否有稳定资产 ID。

返回：条目可被 catalog 使用时返回 true。

<a id="member-gfassetcatalogentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_entry() -> GFAssetCatalogEntry:
```

创建条目副本。

返回：条目副本。

<a id="member-gfassetcatalogentry-methods-get_primary_identity"></a>

### `get_primary_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_primary_identity() -> GFResourceIdentity:
```

获取主资源身份。

返回：主资源身份；主路径为空时仍返回以 asset_id 为后备 cache key 的身份。

<a id="member-gfassetcatalogentry-methods-get_preview_identity"></a>

### `get_preview_identity`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_preview_identity() -> GFResourceIdentity:
```

获取预览资源身份。

返回：预览资源身份；预览路径为空时返回 null。

<a id="member-gfassetcatalogentry-methods-get_cache_key"></a>

### `get_cache_key`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cache_key() -> String:
```

获取推荐缓存键。

返回：主资源身份 cache_key 或 asset_id 后备键。

<a id="member-gfassetcatalogentry-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：条目字典。

结构：

- `return`: Dictionary with asset_id, title, description, tags, category, primary_path, type_hint, preview_path, resource_entry_ids, source_id, metadata, cache_key, primary_identity, and preview_identity.

<a id="member-gfassetcatalogentry-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFAssetCatalogEntry:
```

从字典创建条目。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 条目字典。 |

返回：新条目。

结构：

- `data`: Dictionary with optional asset_id, id, title, description, tags, category, primary_path, resource_path, type_hint, preview_path, resource_entry_ids, source_id, and metadata.

<a id="member-gfassetcatalogentry-methods-from_resource_registry_entry"></a>

### `from_resource_registry_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_resource_registry_entry( registry_entry: GFResourceRegistryEntry, options: Dictionary = {} ) -> GFAssetCatalogEntry:
```

从资源注册表条目创建资产条目。

参数：

| 名称 | 说明 |
|---|---|
| `registry_entry` | 资源注册表条目。 |
| `options` | 可选项，支持 source_id、metadata_fields 和 field override。 |

返回：新资产条目；资源条目无效时返回 null。

结构：

- `options`: Dictionary with optional source_id and fields used by make_entry_summary().
