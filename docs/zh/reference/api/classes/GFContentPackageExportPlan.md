# GFContentPackageExportPlan

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/runtime/gf_content_package_export_plan.gd`
- 模块：`Extensions / Content Package`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

内容包导出计划。 从 GFContentPackageManifest 或 GFContentPackageCatalog 构建可审计的资源条目列表， 供编辑器工具、构建脚本或项目安装器决定后续打包方式。本类只生成计划和诊断，不写 zip、不改 remap、 不规定项目目录结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`package_id`](#member-gfcontentpackageexportplan-properties-package_id) | `var package_id: StringName = &""` |
| 属性 | [`version`](#member-gfcontentpackageexportplan-properties-version) | `var version: String = ""` |
| 属性 | [`root_path`](#member-gfcontentpackageexportplan-properties-root_path) | `var root_path: String = ""` |
| 属性 | [`entries`](#member-gfcontentpackageexportplan-properties-entries) | `var entries: Array[Dictionary] = []` |
| 属性 | [`issues`](#member-gfcontentpackageexportplan-properties-issues) | `var issues: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfcontentpackageexportplan-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`clear`](#member-gfcontentpackageexportplan-methods-clear) | `func clear() -> void:` |
| 方法 | [`add_entry`](#member-gfcontentpackageexportplan-methods-add_entry) | `func add_entry( source_path: String, archive_path: String = "", role: StringName = &"resource", entry_metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`build_from_manifest`](#member-gfcontentpackageexportplan-methods-build_from_manifest) | `func build_from_manifest( manifest: GFContentPackageManifest, options: Dictionary = {} ) -> GFContentPackageExportPlan:` |
| 方法 | [`build_from_catalog`](#member-gfcontentpackageexportplan-methods-build_from_catalog) | `func build_from_catalog( catalog: GFContentPackageCatalog, options: Dictionary = {} ) -> GFContentPackageExportPlan:` |
| 方法 | [`get_validation_report`](#member-gfcontentpackageexportplan-methods-get_validation_report) | `func get_validation_report() -> Dictionary:` |
| 方法 | [`to_dictionary`](#member-gfcontentpackageexportplan-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`from_manifest`](#member-gfcontentpackageexportplan-methods-from_manifest) | `static func from_manifest( manifest: GFContentPackageManifest, options: Dictionary = {} ) -> GFContentPackageExportPlan:` |
| 方法 | [`from_catalog`](#member-gfcontentpackageexportplan-methods-from_catalog) | `static func from_catalog( catalog: GFContentPackageCatalog, options: Dictionary = {} ) -> GFContentPackageExportPlan:` |

## 属性

<a id="member-gfcontentpackageexportplan-properties-package_id"></a>

### `package_id`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var package_id: StringName = &""
```

计划关联的主内容包 ID。

<a id="member-gfcontentpackageexportplan-properties-version"></a>

### `version`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var version: String = ""
```

计划关联的主内容包版本。

<a id="member-gfcontentpackageexportplan-properties-root_path"></a>

### `root_path`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var root_path: String = ""
```

计划关联的内容包根目录。

<a id="member-gfcontentpackageexportplan-properties-entries"></a>

### `entries`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var entries: Array[Dictionary] = []
```

导出条目列表。

结构：

- `entries`: Array[Dictionary]，每项包含 source_path、archive_path、role、resource_key、package_id、type_hint 和 metadata。

<a id="member-gfcontentpackageexportplan-properties-issues"></a>

### `issues`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var issues: Array[Dictionary] = []
```

计划诊断问题。

结构：

- `issues`: Array[Dictionary] GFValidationReportDictionary-compatible issue payloads.

<a id="member-gfcontentpackageexportplan-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary project-defined export metadata.

## 方法

<a id="member-gfcontentpackageexportplan-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear() -> void:
```

清空计划。

<a id="member-gfcontentpackageexportplan-methods-add_entry"></a>

### `add_entry`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func add_entry( source_path: String, archive_path: String = "", role: StringName = &"resource", entry_metadata: Dictionary = {} ) -> bool:
```

添加导出条目。

参数：

| 名称 | 说明 |
|---|---|
| `source_path` | 源资源路径。 |
| `archive_path` | 归档内路径；为空时按 root_path 推导相对路径。 |
| `role` | 条目角色，例如 manifest、resource 或 dependency。 |
| `entry_metadata` | 条目元数据。 |

返回：成功加入返回 true。

结构：

- `entry_metadata`: Dictionary project-defined entry metadata.

<a id="member-gfcontentpackageexportplan-methods-build_from_manifest"></a>

### `build_from_manifest`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func build_from_manifest( manifest: GFContentPackageManifest, options: Dictionary = {} ) -> GFContentPackageExportPlan:
```

从单个内容包 manifest 构建计划。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 内容包 manifest。 |
| `options` | 构建选项。 |

返回：当前计划。

结构：

- `options`: Dictionary，可包含 include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。

<a id="member-gfcontentpackageexportplan-methods-build_from_catalog"></a>

### `build_from_catalog`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func build_from_catalog( catalog: GFContentPackageCatalog, options: Dictionary = {} ) -> GFContentPackageExportPlan:
```

从内容包目录构建多包计划。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 内容包目录。 |
| `options` | 构建选项。 |

返回：当前计划。

结构：

- `options`: Dictionary，可包含 package_ids、include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。

<a id="member-gfcontentpackageexportplan-methods-get_validation_report"></a>

### `get_validation_report`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func get_validation_report() -> Dictionary:
```

获取导出计划诊断报告。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, healthy, entries, entry_count, issues, summary, and next_action.

<a id="member-gfcontentpackageexportplan-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为可序列化字典。

返回：计划字典。

结构：

- `return`: Dictionary with package_id, version, root_path, entries, issues, and metadata.

<a id="member-gfcontentpackageexportplan-methods-from_manifest"></a>

### `from_manifest`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_manifest( manifest: GFContentPackageManifest, options: Dictionary = {} ) -> GFContentPackageExportPlan:
```

从 manifest 创建计划。

参数：

| 名称 | 说明 |
|---|---|
| `manifest` | 内容包 manifest。 |
| `options` | 构建选项，见 build_from_manifest()。 |

返回：新计划。

结构：

- `options`: Dictionary，可包含 include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。

<a id="member-gfcontentpackageexportplan-methods-from_catalog"></a>

### `from_catalog`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func from_catalog( catalog: GFContentPackageCatalog, options: Dictionary = {} ) -> GFContentPackageExportPlan:
```

从 catalog 创建计划。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 内容包目录。 |
| `options` | 构建选项，见 build_from_catalog()。 |

返回：新计划。

结构：

- `options`: Dictionary，可包含 package_ids、include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。
