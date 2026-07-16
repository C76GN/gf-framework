# GFAssetCatalogSourceRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog_source_registry.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

资产目录来源注册表。 通过显式 provider 汇聚多个资产来源，生成可重建的 `GFAssetCatalog`。 它只处理来源注册、优先级、合并和诊断，不规定项目目录结构或素材分类体系。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`register_source`](#member-gfassetcatalogsourceregistry-methods-register_source) | `func register_source(provider: GFAssetCatalogSourceProvider, options: Dictionary = {}) -> bool:` |
| 方法 | [`unregister_source`](#member-gfassetcatalogsourceregistry-methods-unregister_source) | `func unregister_source(provider: GFAssetCatalogSourceProvider) -> bool:` |
| 方法 | [`clear_sources`](#member-gfassetcatalogsourceregistry-methods-clear_sources) | `func clear_sources() -> void:` |
| 方法 | [`has_source_id`](#member-gfassetcatalogsourceregistry-methods-has_source_id) | `func has_source_id(source_id: StringName) -> bool:` |
| 方法 | [`get_source_records`](#member-gfassetcatalogsourceregistry-methods-get_source_records) | `func get_source_records() -> Array[Dictionary]:` |
| 方法 | [`build_catalog`](#member-gfassetcatalogsourceregistry-methods-build_catalog) | `func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:` |
| 方法 | [`build_catalog_report`](#member-gfassetcatalogsourceregistry-methods-build_catalog_report) | `func build_catalog_report(options: Dictionary = {}) -> Dictionary:` |

## 方法

<a id="member-gfassetcatalogsourceregistry-methods-register_source"></a>

### `register_source`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_source(provider: GFAssetCatalogSourceProvider, options: Dictionary = {}) -> bool:
```

注册资产来源 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 资产来源 provider。 |
| `options` | 可选项，支持 source_id 和 priority 覆盖。 |

返回：注册成功返回 true。

结构：

- `options`: Dictionary with optional source_id: StringName/String and priority: int.

<a id="member-gfassetcatalogsourceregistry-methods-unregister_source"></a>

### `unregister_source`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_source(provider: GFAssetCatalogSourceProvider) -> bool:
```

注销资产来源 provider。

参数：

| 名称 | 说明 |
|---|---|
| `provider` | 已注册的 provider。 |

返回：找到并移除时返回 true。

<a id="member-gfassetcatalogsourceregistry-methods-clear_sources"></a>

### `clear_sources`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func clear_sources() -> void:
```

清空全部来源。

<a id="member-gfassetcatalogsourceregistry-methods-has_source_id"></a>

### `has_source_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_source_id(source_id: StringName) -> bool:
```

检查来源 ID 是否已注册。

参数：

| 名称 | 说明 |
|---|---|
| `source_id` | 来源稳定 ID。 |

返回：存在返回 true。

<a id="member-gfassetcatalogsourceregistry-methods-get_source_records"></a>

### `get_source_records`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_source_records() -> Array[Dictionary]:
```

获取来源摘要记录。

返回：来源摘要数组。

结构：

- `return`: Array[Dictionary] where each item contains source_id, priority, provider_class, and index.

<a id="member-gfassetcatalogsourceregistry-methods-build_catalog"></a>

### `build_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_catalog(options: Dictionary = {}) -> GFAssetCatalog:
```

构建合并后的资产目录。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项，支持 provider_options、overwrite 和 source_ids。 |

返回：合并后的资产目录。

结构：

- `options`: Dictionary with optional provider_options: Dictionary, overwrite: bool, and source_ids: PackedStringArray.

<a id="member-gfassetcatalogsourceregistry-methods-build_catalog_report"></a>

### `build_catalog_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func build_catalog_report(options: Dictionary = {}) -> Dictionary:
```

构建 JSON-safe 资产目录诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 可选项，传给 build_catalog()。 |

返回：资产目录报告。

结构：

- `options`: Dictionary build options.
- `return`: Dictionary with ok, source_count, entry_count, sources, catalog_data, and issues.
