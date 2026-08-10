# Extensions / Content Package API

模块：`extensions/content_package`

## 类别概览

| 类别 | 类 | 成员 | 方法 |
|---|---:|---:|---:|
| [运行时服务](#category-runtime_service) | 3 | 49 | 41 |
| [协议与扩展点](#category-protocol) | 1 | 3 | 3 |
| [资源定义](#category-resource_definition) | 1 | 28 | 12 |
| [值对象](#category-value_object) | 2 | 29 | 15 |

## 类

<a id="category-runtime_service"></a>

### 运行时服务

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFContentPackageCatalog`](classes/GFContentPackageCatalog.md#gfcontentpackagecatalog) | `RefCounted` | `addons/gf/extensions/content_package/runtime/gf_content_package_catalog.gd` |
| [`GFContentPackageExportPlan`](classes/GFContentPackageExportPlan.md#gfcontentpackageexportplan) | `RefCounted` | `addons/gf/extensions/content_package/runtime/gf_content_package_export_plan.gd` |
| [`GFContentPackageUtility`](classes/GFContentPackageUtility.md#gfcontentpackageutility) | `GFUtility` | `addons/gf/extensions/content_package/runtime/gf_content_package_utility.gd` |

<a id="category-protocol"></a>

### 协议与扩展点

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFContentPackageAssetCatalogProvider`](classes/GFContentPackageAssetCatalogProvider.md#gfcontentpackageassetcatalogprovider) | `GFAssetCatalogSourceProvider` | `addons/gf/extensions/content_package/runtime/gf_content_package_asset_catalog_provider.gd` |

<a id="category-resource_definition"></a>

### 资源定义

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFContentPackageManifest`](classes/GFContentPackageManifest.md#gfcontentpackagemanifest) | `Resource` | `addons/gf/extensions/content_package/resources/gf_content_package_manifest.gd` |

<a id="category-value_object"></a>

### 值对象

| 类 | 继承 | 源文件 |
|---|---|---|
| [`GFContentPackageQuery`](classes/GFContentPackageQuery.md#gfcontentpackagequery) | `Resource` | `addons/gf/extensions/content_package/resources/gf_content_package_query.gd` |
| [`GFContentPackageQueryResult`](classes/GFContentPackageQueryResult.md#gfcontentpackagequeryresult) | `RefCounted` | `addons/gf/extensions/content_package/runtime/gf_content_package_query_result.gd` |
