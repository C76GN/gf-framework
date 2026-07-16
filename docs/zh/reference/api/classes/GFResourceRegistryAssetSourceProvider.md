# GFResourceRegistryAssetSourceProvider

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_resource_registry_asset_source_provider.gd`
- 模块：`Standard`
- 继承：`GFAssetCatalogSourceProvider`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

从 GFResourceRegistry 生成资产目录的 provider。 该 provider 把已有资源注册表条目适配为 `GFAssetCatalogEntry`，用于项目从 “稳定资源 ID -> 资源路径” 平滑过渡到更高层的资产目录。字段含义仍由项目定义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`registry`](#member-gfresourceregistryassetsourceprovider-properties-registry) | `var registry: GFResourceRegistry = null` |
| 属性 | [`entry_options`](#member-gfresourceregistryassetsourceprovider-properties-entry_options) | `var entry_options: Dictionary = {}` |
| 方法 | [`configure_registry`](#member-gfresourceregistryassetsourceprovider-methods-configure_registry) | `func configure_registry( p_registry: GFResourceRegistry, p_source_id: StringName = &"resource_registry", options: Dictionary = {} ) -> GFResourceRegistryAssetSourceProvider:` |
| 方法 | [`build_catalog`](#member-gfresourceregistryassetsourceprovider-methods-build_catalog) | `func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:` |
| 方法 | [`get_debug_snapshot`](#member-gfresourceregistryassetsourceprovider-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 属性

<a id="member-gfresourceregistryassetsourceprovider-properties-registry"></a>

### `registry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var registry: GFResourceRegistry = null
```

作为来源的资源注册表。

<a id="member-gfresourceregistryassetsourceprovider-properties-entry_options"></a>

### `entry_options`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var entry_options: Dictionary = {}
```

转换字段选项，传给 GFAssetCatalogEntry.from_resource_registry_entry()。

结构：

- `entry_options`: Dictionary with optional title_fields, description_fields, tag_fields, category_fields, and preview_path_fields.

## 方法

<a id="member-gfresourceregistryassetsourceprovider-methods-configure_registry"></a>

### `configure_registry`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func configure_registry( p_registry: GFResourceRegistry, p_source_id: StringName = &"resource_registry", options: Dictionary = {} ) -> GFResourceRegistryAssetSourceProvider:
```

配置资源注册表来源。

参数：

| 名称 | 说明 |
|---|---|
| `p_registry` | 资源注册表。 |
| `p_source_id` | 来源稳定 ID。 |
| `options` | 可选项，支持 priority 和 entry_options。 |

返回：当前 provider。

结构：

- `options`: Dictionary with optional priority: int and entry_options: Dictionary.

<a id="member-gfresourceregistryassetsourceprovider-methods-build_catalog"></a>

### `build_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
```

构建资产目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项，支持 asset_ids、entry_ids 和 entry_options。 |

返回：来源导出的资产目录。

结构：

- `options`: Dictionary with optional asset_ids, entry_ids, and entry_options.

<a id="member-gfresourceregistryassetsourceprovider-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取来源诊断快照。

返回：来源诊断字典。

结构：

- `return`: Dictionary with source_id, priority, provider_class, registry_entry_count, and has_registry.
