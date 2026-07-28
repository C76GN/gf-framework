# GFContentPackageAssetCatalogProvider

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/runtime/gf_content_package_asset_catalog_provider.gd`
- 模块：`Extensions / Content Package`
- 继承：`GFAssetCatalogSourceProvider`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`10.0.0`

内容包目录到通用资产目录的适配器。 Provider 持有内容包目录快照，通过可选 GFContentPackageQuery 选择 manifest， 再把资源映射转换为 GFAssetCatalogEntry。它不挂载目录、不下载内容，也不解释业务分类。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`configure_catalog`](#member-gfcontentpackageassetcatalogprovider-methods-configure_catalog) | `func configure_catalog( catalog: GFContentPackageCatalog, p_source_id: StringName = &"content_packages", query: GFContentPackageQuery = null, options: Dictionary = {} ) -> GFContentPackageAssetCatalogProvider:` |
| 方法 | [`build_catalog`](#member-gfcontentpackageassetcatalogprovider-methods-build_catalog) | `func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:` |
| 方法 | [`get_debug_snapshot`](#member-gfcontentpackageassetcatalogprovider-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfcontentpackageassetcatalogprovider-methods-configure_catalog"></a>

### `configure_catalog`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure_catalog( catalog: GFContentPackageCatalog, p_source_id: StringName = &"content_packages", query: GFContentPackageQuery = null, options: Dictionary = {} ) -> GFContentPackageAssetCatalogProvider:
```

配置内容包目录快照和可选查询。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 内容包目录；Provider 保存其深拷贝。 |
| `p_source_id` | 资产来源 ID。 |
| `query` | 可选内容包查询；为空时选择全部有效包。 |
| `options` | Provider 配置选项，支持 priority。 |

返回：当前 Provider。

结构：

- `options`: Dictionary with optional priority: int.

<a id="member-gfcontentpackageassetcatalogprovider-methods-build_catalog"></a>

### `build_catalog`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
```

构建资产目录快照。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选字段映射，支持 title_fields、description_fields、tag_fields、category_fields 和 preview_path_fields。 |

返回：转换后的资产目录；内容包目录无效时返回 null。

结构：

- `options`: Dictionary with optional PackedStringArray field-name lists for title_fields, description_fields, tag_fields, category_fields, and preview_path_fields.

<a id="member-gfcontentpackageassetcatalogprovider-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 Provider 诊断快照。

返回：来源、内容包目录和查询摘要。

结构：

- `return`: Dictionary with source_id, priority, provider_class, content_catalog, and query.
