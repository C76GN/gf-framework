# GFContentPackageQueryResult

[API Reference](../index.md) / [Extensions / Content Package](../extensions-content-package.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/content_package/runtime/gf_content_package_query_result.gd`
- 模块：`Extensions / Content Package`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`10.0.0`

内容包查询的不可变结果快照。 结果区分直接命中与依赖闭包，并保留隔离的 manifest 和验证报告， 调用方不需要从空数组推断查询失败或无匹配。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_COMPLETED`](#member-gfcontentpackagequeryresult-constants-status_completed) | `const STATUS_COMPLETED: StringName = &"completed"` |
| 常量 | [`STATUS_INVALID_QUERY`](#member-gfcontentpackagequeryresult-constants-status_invalid_query) | `const STATUS_INVALID_QUERY: StringName = &"invalid_query"` |
| 常量 | [`STATUS_INVALID_CATALOG`](#member-gfcontentpackagequeryresult-constants-status_invalid_catalog) | `const STATUS_INVALID_CATALOG: StringName = &"invalid_catalog"` |
| 方法 | [`is_successful`](#member-gfcontentpackagequeryresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfcontentpackagequeryresult-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_query_id`](#member-gfcontentpackagequeryresult-methods-get_query_id) | `func get_query_id() -> StringName:` |
| 方法 | [`get_direct_package_ids`](#member-gfcontentpackagequeryresult-methods-get_direct_package_ids) | `func get_direct_package_ids() -> PackedStringArray:` |
| 方法 | [`get_package_ids`](#member-gfcontentpackagequeryresult-methods-get_package_ids) | `func get_package_ids() -> PackedStringArray:` |
| 方法 | [`get_manifest`](#member-gfcontentpackagequeryresult-methods-get_manifest) | `func get_manifest(package_id: StringName) -> GFContentPackageManifest:` |
| 方法 | [`get_manifests`](#member-gfcontentpackagequeryresult-methods-get_manifests) | `func get_manifests() -> Array[GFContentPackageManifest]:` |
| 方法 | [`get_report`](#member-gfcontentpackagequeryresult-methods-get_report) | `func get_report() -> Dictionary:` |
| 方法 | [`to_dict`](#member-gfcontentpackagequeryresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfcontentpackagequeryresult-constants-status_completed"></a>

### `STATUS_COMPLETED`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_COMPLETED: StringName = &"completed"
```

查询成功完成。

<a id="member-gfcontentpackagequeryresult-constants-status_invalid_query"></a>

### `STATUS_INVALID_QUERY`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVALID_QUERY: StringName = &"invalid_query"
```

查询对象为空或无效。

<a id="member-gfcontentpackagequeryresult-constants-status_invalid_catalog"></a>

### `STATUS_INVALID_CATALOG`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const STATUS_INVALID_CATALOG: StringName = &"invalid_catalog"
```

内容包目录依赖图或 manifest 无效。

## 方法

<a id="member-gfcontentpackagequeryresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func is_successful() -> bool:
```

检查查询是否成功完成。

返回：查询成功返回 true；零匹配仍属于成功。

<a id="member-gfcontentpackagequeryresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_status() -> StringName:
```

获取稳定终态状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfcontentpackagequeryresult-methods-get_query_id"></a>

### `get_query_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_query_id() -> StringName:
```

获取查询 ID。

返回：查询稳定 ID。

<a id="member-gfcontentpackagequeryresult-methods-get_direct_package_ids"></a>

### `get_direct_package_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_direct_package_ids() -> PackedStringArray:
```

获取不含自动依赖扩展的直接命中 package ID。

返回：dependency-first 排序的 ID 副本。

<a id="member-gfcontentpackagequeryresult-methods-get_package_ids"></a>

### `get_package_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_package_ids() -> PackedStringArray:
```

获取最终 package ID，包括请求的依赖闭包。

返回：dependency-first 排序的 ID 副本。

<a id="member-gfcontentpackagequeryresult-methods-get_manifest"></a>

### `get_manifest`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_manifest(package_id: StringName) -> GFContentPackageManifest:
```

获取一个命中 manifest 的隔离副本。

参数：

| 名称 | 说明 |
|---|---|
| `package_id` | 内容包 ID。 |

返回：manifest 深拷贝；未命中返回 null。

<a id="member-gfcontentpackagequeryresult-methods-get_manifests"></a>

### `get_manifests`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_manifests() -> Array[GFContentPackageManifest]:
```

获取全部命中 manifest 的隔离副本。

返回：与 get_package_ids() 同序的 manifest 数组。

<a id="member-gfcontentpackagequeryresult-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_report() -> Dictionary:
```

获取验证报告副本。

返回：GFValidationReportDictionary 兼容字典。

结构：

- `return`: GFValidationReportDictionary-compatible Dictionary with query_id, status, direct_package_ids, and package_ids.

<a id="member-gfcontentpackagequeryresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为 JSON-safe 结果摘要。

返回：不包含 Resource 对象的结果字典。

结构：

- `return`: Dictionary with successful, status, query_id, direct_package_ids, package_ids, manifests, and report.
