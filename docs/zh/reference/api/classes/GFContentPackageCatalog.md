# GFContentPackageCatalog

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/runtime/gf_content_package_catalog.gd`
- 模块：`Extensions / Content Package`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`4.4.0`

内容包集合与依赖图诊断。 管理一组 GFContentPackageManifest，提供包查询、依赖顺序、重复/缺失/循环依赖报告， 并可把内容包资源键映射注册到 GFResourceResolverUtility。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`clear`](#member-gfcontentpackagecatalog-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_manifest`](#member-gfcontentpackagecatalog-methods-add_manifest) | `func add_manifest(manifest: GFContentPackageManifest) -> bool:` |
| 方法 | [`set_manifests`](#member-gfcontentpackagecatalog-methods-set_manifests) | `func set_manifests(manifests: Array[GFContentPackageManifest]) -> GFContentPackageCatalog:` |
| 方法 | [`remove_manifest`](#member-gfcontentpackagecatalog-methods-remove_manifest) | `func remove_manifest(package_id: StringName) -> bool:` |
| 方法 | [`has_package`](#member-gfcontentpackagecatalog-methods-has_package) | `func has_package(package_id: StringName) -> bool:` |
| 方法 | [`get_manifest`](#member-gfcontentpackagecatalog-methods-get_manifest) | `func get_manifest(package_id: StringName) -> GFContentPackageManifest:` |
| 方法 | [`duplicate_catalog`](#member-gfcontentpackagecatalog-methods-duplicate_catalog) | `func duplicate_catalog() -> GFContentPackageCatalog:` |
| 方法 | [`get_package_ids`](#member-gfcontentpackagecatalog-methods-get_package_ids) | `func get_package_ids() -> PackedStringArray:` |
| 方法 | [`get_ordered_package_ids`](#member-gfcontentpackagecatalog-methods-get_ordered_package_ids) | `func get_ordered_package_ids() -> PackedStringArray:` |
| 方法 | [`query_packages`](#member-gfcontentpackagecatalog-methods-query_packages) | `func query_packages( query: GFContentPackageQuery, options: Dictionary = {} ) -> GFContentPackageQueryResult:` |
| 方法 | [`get_graph_report`](#member-gfcontentpackagecatalog-methods-get_graph_report) | `func get_graph_report(options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`register_resources`](#member-gfcontentpackagecatalog-methods-register_resources) | `func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfcontentpackagecatalog-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfcontentpackagecatalog-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空目录。

<a id="member-gfcontentpackagecatalog-methods-add_manifest"></a>

### `add_manifest`

- API：`public`

```gdscript
func add_manifest(manifest: GFContentPackageManifest) -> bool:
```

注册内容包 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 内容包 manifest。 |

返回：注册成功返回 true；重复或空 ID 返回 false。

<a id="member-gfcontentpackagecatalog-methods-set_manifests"></a>

### `set_manifests`

- API：`public`

```gdscript
func set_manifests(manifests: Array[GFContentPackageManifest]) -> GFContentPackageCatalog:
```

批量替换内容包 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `manifests` | manifest 列表。 |

返回：当前目录。

结构：

- `manifests`: Array[GFContentPackageManifest]，无效项会被忽略或进入诊断。

<a id="member-gfcontentpackagecatalog-methods-remove_manifest"></a>

### `remove_manifest`

- API：`public`

```gdscript
func remove_manifest(package_id: StringName) -> bool:
```

移除内容包 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 内容包 ID。 |

返回：移除成功返回 true。

<a id="member-gfcontentpackagecatalog-methods-has_package"></a>

### `has_package`

- API：`public`

```gdscript
func has_package(package_id: StringName) -> bool:
```

检查内容包是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 内容包 ID。 |

返回：存在返回 true。

<a id="member-gfcontentpackagecatalog-methods-get_manifest"></a>

### `get_manifest`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_manifest(package_id: StringName) -> GFContentPackageManifest:
```

获取内容包 manifest。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 内容包 ID。 |

返回：manifest 深拷贝；不存在时返回 null。

<a id="member-gfcontentpackagecatalog-methods-duplicate_catalog"></a>

### `duplicate_catalog`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func duplicate_catalog() -> GFContentPackageCatalog:
```

创建目录深拷贝。

返回：与当前依赖图和重复 ID 状态一致的新目录。

<a id="member-gfcontentpackagecatalog-methods-get_package_ids"></a>

### `get_package_ids`

- API：`public`

```gdscript
func get_package_ids() -> PackedStringArray:
```

获取内容包 ID 列表。

返回：按注册顺序排列的内容包 ID。

<a id="member-gfcontentpackagecatalog-methods-get_ordered_package_ids"></a>

### `get_ordered_package_ids`

- API：`public`

```gdscript
func get_ordered_package_ids() -> PackedStringArray:
```

获取按依赖优先排序的内容包 ID。

返回：依赖包先于依赖方出现的内容包 ID 列表。

<a id="member-gfcontentpackagecatalog-methods-query_packages"></a>

### `query_packages`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func query_packages( query: GFContentPackageQuery, options: Dictionary = {} ) -> GFContentPackageQueryResult:
```

查询有效内容包并返回隔离结果。

参数：

| 名称 | 说明 |
|---|---|
| `query` | 通用内容包查询。 |
| `options` | manifest 和依赖图校验选项。 |

返回：类型化查询终态；目录无效时不返回部分结果。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。

<a id="member-gfcontentpackagecatalog-methods-get_graph_report"></a>

### `get_graph_report`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func get_graph_report(options: Dictionary = {}) -> Dictionary:
```

获取依赖图和 manifest 诊断报告。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 校验选项，透传给 GFContentPackageManifest。 |

返回：GFValidationReportDictionary 兼容报告。

结构：

- `options`: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。

<a id="member-gfcontentpackagecatalog-methods-register_resources"></a>

### `register_resources`

- API：`public`
- 首次版本：`4.4.0`

```gdscript
func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:
```

把内容包资源键注册到资源解析器。

参数：

| 名称 | 说明 |
|---|---|
| `resolver` | 标准资源解析器。 |
| `options` | 注册选项。`base_priority` 默认为 0；校验选项透传给 manifest。 |

返回：GFValidationReportDictionary 兼容报告，并包含 registered_count。

结构：

- `options`: Dictionary，可包含 base_priority: int、check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
- `return`: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 registered_count。

<a id="member-gfcontentpackagecatalog-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：目录快照。

结构：

- `return`: Dictionary，包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。
