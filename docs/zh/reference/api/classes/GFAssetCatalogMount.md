# GFAssetCatalogMount

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog_mount.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

资产目录运行时挂载的生命周期句柄。 句柄保存提交时的目录快照、owner、mount ID、来源和 revision， 并提供幂等显式卸载入口。失败请求也返回带稳定状态与报告的非活动句柄。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATUS_ACTIVE`](#member-gfassetcatalogmount-constants-status_active) | `const STATUS_ACTIVE: StringName = &"active"` |
| 常量 | [`STATUS_UNMOUNTED`](#member-gfassetcatalogmount-constants-status_unmounted) | `const STATUS_UNMOUNTED: StringName = &"unmounted"` |
| 常量 | [`STATUS_CONFLICT`](#member-gfassetcatalogmount-constants-status_conflict) | `const STATUS_CONFLICT: StringName = &"conflict"` |
| 常量 | [`STATUS_BUILD_FAILED`](#member-gfassetcatalogmount-constants-status_build_failed) | `const STATUS_BUILD_FAILED: StringName = &"build_failed"` |
| 常量 | [`STATUS_DUPLICATE_MOUNT`](#member-gfassetcatalogmount-constants-status_duplicate_mount) | `const STATUS_DUPLICATE_MOUNT: StringName = &"duplicate_mount"` |
| 常量 | [`STATUS_INVALID_REQUEST`](#member-gfassetcatalogmount-constants-status_invalid_request) | `const STATUS_INVALID_REQUEST: StringName = &"invalid_request"` |
| 常量 | [`STATUS_DISPOSED`](#member-gfassetcatalogmount-constants-status_disposed) | `const STATUS_DISPOSED: StringName = &"disposed"` |
| 方法 | [`is_active`](#member-gfassetcatalogmount-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_status`](#member-gfassetcatalogmount-methods-get_status) | `func get_status() -> StringName:` |
| 方法 | [`get_owner_id`](#member-gfassetcatalogmount-methods-get_owner_id) | `func get_owner_id() -> StringName:` |
| 方法 | [`get_mount_id`](#member-gfassetcatalogmount-methods-get_mount_id) | `func get_mount_id() -> StringName:` |
| 方法 | [`get_source_id`](#member-gfassetcatalogmount-methods-get_source_id) | `func get_source_id() -> StringName:` |
| 方法 | [`get_priority`](#member-gfassetcatalogmount-methods-get_priority) | `func get_priority() -> int:` |
| 方法 | [`get_revision`](#member-gfassetcatalogmount-methods-get_revision) | `func get_revision() -> int:` |
| 方法 | [`get_catalog`](#member-gfassetcatalogmount-methods-get_catalog) | `func get_catalog() -> GFAssetCatalog:` |
| 方法 | [`get_report`](#member-gfassetcatalogmount-methods-get_report) | `func get_report() -> Dictionary:` |
| 方法 | [`unmount`](#member-gfassetcatalogmount-methods-unmount) | `func unmount() -> bool:` |
| 方法 | [`to_dict`](#member-gfassetcatalogmount-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 常量

<a id="member-gfassetcatalogmount-constants-status_active"></a>

### `STATUS_ACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_ACTIVE: StringName = &"active"
```

Mount 已提交且仍活动。

<a id="member-gfassetcatalogmount-constants-status_unmounted"></a>

### `STATUS_UNMOUNTED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_UNMOUNTED: StringName = &"unmounted"
```

Mount 已由调用方或 owner scope 释放。

<a id="member-gfassetcatalogmount-constants-status_conflict"></a>

### `STATUS_CONFLICT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_CONFLICT: StringName = &"conflict"
```

Mount 与已提交资产 ID 冲突。

<a id="member-gfassetcatalogmount-constants-status_build_failed"></a>

### `STATUS_BUILD_FAILED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_BUILD_FAILED: StringName = &"build_failed"
```

Provider 未能构建目录。

<a id="member-gfassetcatalogmount-constants-status_duplicate_mount"></a>

### `STATUS_DUPLICATE_MOUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_DUPLICATE_MOUNT: StringName = &"duplicate_mount"
```

同一 owner 已存在相同 mount ID。

<a id="member-gfassetcatalogmount-constants-status_invalid_request"></a>

### `STATUS_INVALID_REQUEST`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"
```

Mount 请求缺少 owner、mount ID 或有效目录。

<a id="member-gfassetcatalogmount-constants-status_disposed"></a>

### `STATUS_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATUS_DISPOSED: StringName = &"disposed"
```

所属 Runtime 已释放。

## 方法

<a id="member-gfassetcatalogmount-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_active() -> bool:
```

检查 Mount 是否仍在 Runtime 中活动。

返回：活动返回 true。

<a id="member-gfassetcatalogmount-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> StringName:
```

获取稳定终态状态。

返回：`STATUS_*` 常量之一。

<a id="member-gfassetcatalogmount-methods-get_owner_id"></a>

### `get_owner_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_owner_id() -> StringName:
```

获取 owner ID。

返回：Mount owner ID。

<a id="member-gfassetcatalogmount-methods-get_mount_id"></a>

### `get_mount_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_mount_id() -> StringName:
```

获取 owner scope 内稳定 mount ID。

返回：Mount ID。

<a id="member-gfassetcatalogmount-methods-get_source_id"></a>

### `get_source_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_source_id() -> StringName:
```

获取来源 ID。

返回：Provider 来源 ID；直接目录 Mount 默认等于 mount ID。

<a id="member-gfassetcatalogmount-methods-get_priority"></a>

### `get_priority`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_priority() -> int:
```

获取 Mount 优先级。

返回：合并优先级。

<a id="member-gfassetcatalogmount-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_revision() -> int:
```

获取最近一次提交该 Mount 的 Runtime revision。

返回：非负 revision。

<a id="member-gfassetcatalogmount-methods-get_catalog"></a>

### `get_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_catalog() -> GFAssetCatalog:
```

获取 Mount 自身的资产目录快照。

返回：深拷贝目录。

<a id="member-gfassetcatalogmount-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_report() -> Dictionary:
```

获取 Mount 请求或提交报告。

返回：GFValidationReport 兼容字典副本。

结构：

- `return`: GFValidationReport-compatible Dictionary with status, owner_id, mount_id, source_id, priority, and revision.

<a id="member-gfassetcatalogmount-methods-unmount"></a>

### `unmount`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func unmount() -> bool:
```

从所属 Runtime 卸载当前 Mount。

返回：本次调用完成卸载返回 true；已终态返回 false。

<a id="member-gfassetcatalogmount-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为 JSON-safe 诊断摘要。

返回：Mount 摘要。

结构：

- `return`: Dictionary with active, status, owner_id, mount_id, source_id, priority, revision, token, asset_ids, and report.
