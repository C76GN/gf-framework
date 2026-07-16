# GFAssetCatalog

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`8.0.0`

通用资产目录。 用稳定 asset_id 管理 `GFAssetCatalogEntry`，提供标签、分类、文本搜索、 摘要、分页和序列化能力。目录只保存可重建的资产索引，不规定项目目录、 内容包、业务分类或导出策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`GROUP_SOURCE_ID`](#member-gfassetcatalog-constants-group_source_id) | `const GROUP_SOURCE_ID: StringName = &"asset_id"` |
| 常量 | [`GROUP_SOURCE_SOURCE_ID`](#member-gfassetcatalog-constants-group_source_source_id) | `const GROUP_SOURCE_SOURCE_ID: StringName = &"source_id"` |
| 常量 | [`GROUP_SOURCE_CATEGORY`](#member-gfassetcatalog-constants-group_source_category) | `const GROUP_SOURCE_CATEGORY: StringName = &"category"` |
| 常量 | [`GROUP_SOURCE_TAGS`](#member-gfassetcatalog-constants-group_source_tags) | `const GROUP_SOURCE_TAGS: StringName = &"tags"` |
| 常量 | [`GROUP_SOURCE_TYPE_HINT`](#member-gfassetcatalog-constants-group_source_type_hint) | `const GROUP_SOURCE_TYPE_HINT: StringName = &"type_hint"` |
| 常量 | [`GROUP_SOURCE_PRIMARY_PATH`](#member-gfassetcatalog-constants-group_source_primary_path) | `const GROUP_SOURCE_PRIMARY_PATH: StringName = &"primary_path"` |
| 常量 | [`GROUP_SOURCE_CACHE_KEY`](#member-gfassetcatalog-constants-group_source_cache_key) | `const GROUP_SOURCE_CACHE_KEY: StringName = &"cache_key"` |
| 常量 | [`GROUP_SOURCE_RESOURCE_ENTRY_ID`](#member-gfassetcatalog-constants-group_source_resource_entry_id) | `const GROUP_SOURCE_RESOURCE_ENTRY_ID: StringName = &"resource_entry_id"` |
| 属性 | [`entries`](#member-gfassetcatalog-properties-entries) | `var entries: Array[GFAssetCatalogEntry] = []` |
| 方法 | [`set_entry`](#member-gfassetcatalog-methods-set_entry) | `func set_entry(entry: GFAssetCatalogEntry) -> bool:` |
| 方法 | [`remove_entry`](#member-gfassetcatalog-methods-remove_entry) | `func remove_entry(asset_id: StringName) -> bool:` |
| 方法 | [`clear`](#member-gfassetcatalog-methods-clear) | `func clear() -> void:` |
| 方法 | [`mark_index_dirty`](#member-gfassetcatalog-methods-mark_index_dirty) | `func mark_index_dirty() -> void:` |
| 方法 | [`rebuild_index`](#member-gfassetcatalog-methods-rebuild_index) | `func rebuild_index() -> void:` |
| 方法 | [`has_entry`](#member-gfassetcatalog-methods-has_entry) | `func has_entry(asset_id: StringName) -> bool:` |
| 方法 | [`get_entry`](#member-gfassetcatalog-methods-get_entry) | `func get_entry(asset_id: StringName) -> GFAssetCatalogEntry:` |
| 方法 | [`get_all_ids`](#member-gfassetcatalog-methods-get_all_ids) | `func get_all_ids() -> PackedStringArray:` |
| 方法 | [`query`](#member-gfassetcatalog-methods-query) | `func query(field_id: StringName, field_value: Variant) -> PackedStringArray:` |
| 方法 | [`query_many`](#member-gfassetcatalog-methods-query_many) | `func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:` |
| 方法 | [`merge_catalog`](#member-gfassetcatalog-methods-merge_catalog) | `func merge_catalog(catalog: GFAssetCatalog, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_search_candidates`](#member-gfassetcatalog-methods-make_search_candidates) | `func make_search_candidates(asset_ids: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:` |
| 方法 | [`search`](#member-gfassetcatalog-methods-search) | `func search(query_text: String, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`make_asset_summary`](#member-gfassetcatalog-methods-make_asset_summary) | `func make_asset_summary(asset_id: StringName, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`make_asset_summaries`](#member-gfassetcatalog-methods-make_asset_summaries) | `func make_asset_summaries(asset_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`search_page`](#member-gfassetcatalog-methods-search_page) | `func search_page( query_text: String, page: int = 1, page_size: int = 50, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`group_asset_ids`](#member-gfassetcatalog-methods-group_asset_ids) | `func group_asset_ids(group_source: StringName = GROUP_SOURCE_ID, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfassetcatalog-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfassetcatalog-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfassetcatalog-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfassetcatalog-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFAssetCatalog:` |

## 常量

<a id="member-gfassetcatalog-constants-group_source_id"></a>

### `GROUP_SOURCE_ID`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_ID: StringName = &"asset_id"
```

按资产 ID 分组。

<a id="member-gfassetcatalog-constants-group_source_source_id"></a>

### `GROUP_SOURCE_SOURCE_ID`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_SOURCE_ID: StringName = &"source_id"
```

按资产来源分组。

<a id="member-gfassetcatalog-constants-group_source_category"></a>

### `GROUP_SOURCE_CATEGORY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_CATEGORY: StringName = &"category"
```

按分类分组。

<a id="member-gfassetcatalog-constants-group_source_tags"></a>

### `GROUP_SOURCE_TAGS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_TAGS: StringName = &"tags"
```

按标签分组。一个资产可进入多个标签组。

<a id="member-gfassetcatalog-constants-group_source_type_hint"></a>

### `GROUP_SOURCE_TYPE_HINT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_TYPE_HINT: StringName = &"type_hint"
```

按主资源类型提示分组。

<a id="member-gfassetcatalog-constants-group_source_primary_path"></a>

### `GROUP_SOURCE_PRIMARY_PATH`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_PRIMARY_PATH: StringName = &"primary_path"
```

按主资源路径分组。

<a id="member-gfassetcatalog-constants-group_source_cache_key"></a>

### `GROUP_SOURCE_CACHE_KEY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_CACHE_KEY: StringName = &"cache_key"
```

按主资源身份缓存键分组。

<a id="member-gfassetcatalog-constants-group_source_resource_entry_id"></a>

### `GROUP_SOURCE_RESOURCE_ENTRY_ID`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const GROUP_SOURCE_RESOURCE_ENTRY_ID: StringName = &"resource_entry_id"
```

按关联资源注册表条目 ID 分组。

## 属性

<a id="member-gfassetcatalog-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var entries: Array[GFAssetCatalogEntry] = []
```

资产目录条目。重复 asset_id 会以后出现的有效条目为准。

结构：

- `entries`: Array[GFAssetCatalogEntry] asset catalog entries.

## 方法

<a id="member-gfassetcatalog-methods-set_entry"></a>

### `set_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func set_entry(entry: GFAssetCatalogEntry) -> bool:
```

添加或替换资产条目。

参数：

| 名称 | 说明 |
|---|---|
| `entry` | 要写入的资产条目。 |

返回：写入成功返回 true。

<a id="member-gfassetcatalog-methods-remove_entry"></a>

### `remove_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func remove_entry(asset_id: StringName) -> bool:
```

移除资产条目。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 资产稳定 ID。 |

返回：移除成功返回 true。

<a id="member-gfassetcatalog-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear() -> void:
```

清空目录。

<a id="member-gfassetcatalog-methods-mark_index_dirty"></a>

### `mark_index_dirty`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func mark_index_dirty() -> void:
```

标记运行时索引需要重建。

<a id="member-gfassetcatalog-methods-rebuild_index"></a>

### `rebuild_index`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func rebuild_index() -> void:
```

立即重建运行时索引。

<a id="member-gfassetcatalog-methods-has_entry"></a>

### `has_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_entry(asset_id: StringName) -> bool:
```

检查资产是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 资产稳定 ID。 |

返回：存在时返回 true。

<a id="member-gfassetcatalog-methods-get_entry"></a>

### `get_entry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_entry(asset_id: StringName) -> GFAssetCatalogEntry:
```

获取资产条目副本。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 资产稳定 ID。 |

返回：条目副本；不存在时返回 null。

<a id="member-gfassetcatalog-methods-get_all_ids"></a>

### `get_all_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_all_ids() -> PackedStringArray:
```

获取全部有效资产 ID。

返回：排序后的资产 ID 列表。

<a id="member-gfassetcatalog-methods-query"></a>

### `query`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
```

按单个字段值查询资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `field_id` | 字段标识。 |
| `field_value` | 字段值。 |

返回：匹配的资产 ID。

结构：

- `field_value`: Variant indexed field value.

<a id="member-gfassetcatalog-methods-query_many"></a>

### `query_many`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
```

按多个字段查询资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `criteria` | 字段到值的查询条件。 |
| `match_all` | true 表示交集查询，false 表示并集查询。 |

返回：匹配的资产 ID。

结构：

- `criteria`: Dictionary from field id to query value.

<a id="member-gfassetcatalog-methods-merge_catalog"></a>

### `merge_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func merge_catalog(catalog: GFAssetCatalog, options: Dictionary = {}) -> Dictionary:
```

合并另一份目录。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 要合并的资产目录。 |
| `options` | 可选项，支持 overwrite。 |

返回：合并报告。

结构：

- `options`: Dictionary with optional overwrite: bool.
- `return`: Dictionary with added_count, replaced_count, skipped_count, and duplicate_ids.

<a id="member-gfassetcatalog-methods-make_search_candidates"></a>

### `make_search_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_search_candidates(asset_ids: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
```

构建可交给 GFTextSearchScorer 的搜索候选。

参数：

| 名称 | 说明 |
|---|---|
| `asset_ids` | 要导出的资产 ID；为空时导出全部有效条目。 |

返回：搜索候选字典数组。

结构：

- `asset_ids`: PackedStringArray selected asset ids.
- `return`: Array[Dictionary] where each candidate contains id, asset_id, title, description, tags, category, primary_path, preview_path, type_hint, source_id, resource_entry_ids, cache_key, and metadata_keywords.

<a id="member-gfassetcatalog-methods-search"></a>

### `search`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func search(query_text: String, options: Dictionary = {}) -> Array[Dictionary]:
```

用通用文本评分器搜索资产。

参数：

| 名称 | 说明 |
|---|---|
| `query_text` | 查询文本。 |
| `options` | 可选项，支持 GFTextSearchScorer.rank_candidates() 的选项，并额外支持 asset_ids。 |

返回：排序后的匹配报告数组。

结构：

- `options`: Dictionary with optional asset_ids plus GFTextSearchScorer rank options.
- `return`: Array[Dictionary] from GFTextSearchScorer.rank_candidates().

<a id="member-gfassetcatalog-methods-make_asset_summary"></a>

### `make_asset_summary`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_asset_summary(asset_id: StringName, options: Dictionary = {}) -> Dictionary:
```

构建资产摘要。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 资产稳定 ID。 |
| `options` | 可选项，支持 include_metadata。 |

返回：资产摘要；不存在时返回空字典。

结构：

- `options`: Dictionary with optional include_metadata: bool.
- `return`: Dictionary with id, asset_id, title, description, tags, category, primary_path, type_hint, preview_path, source_id, resource_entry_ids, cache_key, primary_identity, preview_identity, and optional metadata.

<a id="member-gfassetcatalog-methods-make_asset_summaries"></a>

### `make_asset_summaries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func make_asset_summaries(asset_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {}) -> Array[Dictionary]:
```

批量构建资产摘要。

参数：

| 名称 | 说明 |
|---|---|
| `asset_ids` | 要导出的资产 ID；为空时导出全部有效条目。 |
| `options` | 传给 make_asset_summary() 的摘要选项。 |

返回：资产摘要数组。

结构：

- `asset_ids`: PackedStringArray selected asset ids.
- `options`: Dictionary summary options.
- `return`: Array[Dictionary] where each item is make_asset_summary() output.

<a id="member-gfassetcatalog-methods-search_page"></a>

### `search_page`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func search_page( query_text: String, page: int = 1, page_size: int = 50, options: Dictionary = {} ) -> Dictionary:
```

搜索资产并返回分页报告。

参数：

| 名称 | 说明 |
|---|---|
| `query_text` | 查询文本；为空时默认按资产 ID 列出资产。 |
| `page` | 页码，从 1 开始。 |
| `page_size` | 每页数量，会被规整为至少 1。 |
| `options` | 可选项，支持 search() 选项，并额外支持 empty_query_returns_all、include_summaries 和 summary_options。 |

返回：分页搜索报告。

结构：

- `options`: Dictionary with search options, empty_query_returns_all: bool, include_summaries: bool, and summary_options: Dictionary.
- `return`: Dictionary with query, page, page_size, page_count, total_count, start_index, end_index, has_previous, has_next, results, asset_ids, and summaries.

<a id="member-gfassetcatalog-methods-group_asset_ids"></a>

### `group_asset_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func group_asset_ids(group_source: StringName = GROUP_SOURCE_ID, options: Dictionary = {}) -> Dictionary:
```

按通用来源把资产 ID 分组。

参数：

| 名称 | 说明 |
|---|---|
| `group_source` | 分组来源。 |
| `options` | 可选项，支持 asset_ids、include_empty 和 empty_key。 |

返回：分组字典，key 为分组文本，value 为排序后的资产 ID 列表。

结构：

- `options`: Dictionary with optional asset_ids, include_empty, and empty_key.
- `return`: Dictionary[String, PackedStringArray] grouped asset ids.

<a id="member-gfassetcatalog-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：资产目录诊断信息。

结构：

- `return`: Dictionary with asset_count, indexed_field_count, and ids.

<a id="member-gfassetcatalog-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：资产目录字典。

结构：

- `return`: Dictionary with entries array.

<a id="member-gfassetcatalog-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 资产目录字典。 |

结构：

- `data`: Dictionary with entries array.

<a id="member-gfassetcatalog-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func from_dict(data: Dictionary) -> GFAssetCatalog:
```

从字典创建资产目录。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 资产目录字典。 |

返回：新资产目录。

结构：

- `data`: Dictionary with entries array.
