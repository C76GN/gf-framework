# GFAssetCollection

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_collection.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

有序资产 ID 集合。 集合只保存稳定 `asset_id`、展示信息和调用方元数据，不持有已加载资源， 也不规定目录、分类、预览或业务用途。调用方可以用 `GFAssetCatalog` 解析条目，并在使用前获得缺失、重复和无效 ID 的完整性报告。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`collection_id`](#member-gfassetcollection-properties-collection_id) | `var collection_id: StringName = &""` |
| 属性 | [`title`](#member-gfassetcollection-properties-title) | `var title: String = ""` |
| 属性 | [`description`](#member-gfassetcollection-properties-description) | `var description: String = ""` |
| 属性 | [`asset_ids`](#member-gfassetcollection-properties-asset_ids) | `var asset_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfassetcollection-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfassetcollection-methods-configure) | `func configure( p_collection_id: StringName, p_asset_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFAssetCollection:` |
| 方法 | [`add_asset_id`](#member-gfassetcollection-methods-add_asset_id) | `func add_asset_id(asset_id: StringName, index: int = -1) -> bool:` |
| 方法 | [`remove_asset_id`](#member-gfassetcollection-methods-remove_asset_id) | `func remove_asset_id(asset_id: StringName) -> bool:` |
| 方法 | [`move_asset_id`](#member-gfassetcollection-methods-move_asset_id) | `func move_asset_id(asset_id: StringName, target_index: int) -> bool:` |
| 方法 | [`has_asset_id`](#member-gfassetcollection-methods-has_asset_id) | `func has_asset_id(asset_id: StringName) -> bool:` |
| 方法 | [`resolve_entries`](#member-gfassetcollection-methods-resolve_entries) | `func resolve_entries(catalog: GFAssetCatalog) -> Array[GFAssetCatalogEntry]:` |
| 方法 | [`validate_against`](#member-gfassetcollection-methods-validate_against) | `func validate_against(catalog: GFAssetCatalog) -> GFValidationReport:` |
| 方法 | [`duplicate_collection`](#member-gfassetcollection-methods-duplicate_collection) | `func duplicate_collection() -> GFAssetCollection:` |
| 方法 | [`to_dict`](#member-gfassetcollection-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfassetcollection-methods-apply_dict) | `func apply_dict(data: Dictionary) -> void:` |
| 方法 | [`from_dict`](#member-gfassetcollection-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFAssetCollection:` |

## 属性

<a id="member-gfassetcollection-properties-collection_id"></a>

### `collection_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var collection_id: StringName = &""
```

集合稳定 ID。

<a id="member-gfassetcollection-properties-title"></a>

### `title`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var title: String = ""
```

集合展示标题。

<a id="member-gfassetcollection-properties-description"></a>

### `description`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var description: String = ""
```

集合用途说明。

<a id="member-gfassetcollection-properties-asset_ids"></a>

### `asset_ids`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var asset_ids: PackedStringArray = PackedStringArray()
```

按调用方期望顺序保存的稳定资产 ID。

<a id="member-gfassetcollection-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据；框架不解释其中字段。

结构：

- `metadata`: Dictionary，包含调用方自定义且可序列化的集合元数据。

## 方法

<a id="member-gfassetcollection-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( p_collection_id: StringName, p_asset_ids: PackedStringArray = PackedStringArray(), options: Dictionary = {} ) -> GFAssetCollection:
```

配置集合。

参数：

| 名称 | 说明 |
|---|---|
| `p_collection_id` | 集合稳定 ID。 |
| `p_asset_ids` | 有序资产 ID。 |
| `options` | 可选 title、description 和 metadata。 |

返回：当前集合。

结构：

- `options`: Dictionary，包含 title: String、description: String 和 metadata: Dictionary。

<a id="member-gfassetcollection-methods-add_asset_id"></a>

### `add_asset_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func add_asset_id(asset_id: StringName, index: int = -1) -> bool:
```

在指定位置添加资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 要添加的稳定资产 ID。 |
| `index` | 插入位置；负数或超出末尾时追加。 |

返回：成功添加时返回 true；空 ID 或重复 ID 返回 false。

<a id="member-gfassetcollection-methods-remove_asset_id"></a>

### `remove_asset_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func remove_asset_id(asset_id: StringName) -> bool:
```

移除首次出现的资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 要移除的稳定资产 ID。 |

返回：找到并移除时返回 true。

<a id="member-gfassetcollection-methods-move_asset_id"></a>

### `move_asset_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func move_asset_id(asset_id: StringName, target_index: int) -> bool:
```

移动资产 ID 到新的有序位置。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 要移动的稳定资产 ID。 |
| `target_index` | 移除原位置后使用的目标下标；自动钳制到有效范围。 |

返回：找到并完成移动时返回 true。

<a id="member-gfassetcollection-methods-has_asset_id"></a>

### `has_asset_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func has_asset_id(asset_id: StringName) -> bool:
```

检查集合是否包含资产 ID。

参数：

| 名称 | 说明 |
|---|---|
| `asset_id` | 要查询的稳定资产 ID。 |

返回：至少出现一次时返回 true。

<a id="member-gfassetcollection-methods-resolve_entries"></a>

### `resolve_entries`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func resolve_entries(catalog: GFAssetCatalog) -> Array[GFAssetCatalogEntry]:
```

按集合顺序解析存在于目录中的资产条目。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 用于解析稳定资产 ID 的目录。 |

返回：已解析条目；缺失、空或重复 ID 被跳过。

<a id="member-gfassetcollection-methods-validate_against"></a>

### `validate_against`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_against(catalog: GFAssetCatalog) -> GFValidationReport:
```

对照资产目录校验集合完整性。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 用于解析稳定资产 ID 的目录。 |

返回：包含缺失、重复、空 ID 和有序解析摘要的通用校验报告。

<a id="member-gfassetcollection-methods-duplicate_collection"></a>

### `duplicate_collection`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_collection() -> GFAssetCollection:
```

创建集合深拷贝。

返回：新集合实例。

<a id="member-gfassetcollection-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为可序列化字典。

返回：集合字段深拷贝。

结构：

- `return`: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。

<a id="member-gfassetcollection-methods-apply_dict"></a>

### `apply_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func apply_dict(data: Dictionary) -> void:
```

从字典应用集合字段。

参数：

| 名称 | 说明 |
|---|---|
| `data` | GFAssetCollection.to_dict() 输出或兼容字段。 |

结构：

- `data`: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。

<a id="member-gfassetcollection-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func from_dict(data: Dictionary) -> GFAssetCollection:
```

从字典创建集合。

参数：

| 名称 | 说明 |
|---|---|
| `data` | GFAssetCollection.to_dict() 输出或兼容字段。 |

返回：新集合实例。

结构：

- `data`: Dictionary，包含 collection_id、title、description、asset_ids 和 metadata。
