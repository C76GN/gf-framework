# GFAssetCatalogRuntime

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/assets/gf_asset_catalog_runtime.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

owner-scoped 资产目录快照挂载与原子合并服务。 Runtime 只接收已经构建的目录快照或 Provider 输出，按稳定优先级合并并以 revision 发布。 任何无效请求、Provider 失败或严格冲突都不会替换上一份已提交目录。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`catalog_changed`](#member-gfassetcatalogruntime-signals-catalog_changed) | `signal catalog_changed(catalog: GFAssetCatalog, revision: int)` |
| 常量 | [`CONFLICT_REJECT`](#member-gfassetcatalogruntime-constants-conflict_reject) | `const CONFLICT_REJECT: StringName = &"reject"` |
| 常量 | [`CONFLICT_KEEP_HIGH_PRIORITY`](#member-gfassetcatalogruntime-constants-conflict_keep_high_priority) | `const CONFLICT_KEEP_HIGH_PRIORITY: StringName = &"keep_high_priority"` |
| 方法 | [`configure`](#member-gfassetcatalogruntime-methods-configure) | `func configure(conflict_policy: StringName = CONFLICT_REJECT) -> GFAssetCatalogRuntime:` |
| 方法 | [`mount_catalog`](#member-gfassetcatalogruntime-methods-mount_catalog) | `func mount_catalog( owner_id: StringName, mount_id: StringName, catalog: GFAssetCatalog, priority: int = 0, source_id: StringName = &"" ) -> GFAssetCatalogMount:` |
| 方法 | [`mount_provider`](#member-gfassetcatalogruntime-methods-mount_provider) | `func mount_provider( owner_id: StringName, mount_id: StringName, provider: GFAssetCatalogSourceProvider, options: Dictionary = {} ) -> GFAssetCatalogMount:` |
| 方法 | [`replace_mount_catalog`](#member-gfassetcatalogruntime-methods-replace_mount_catalog) | `func replace_mount_catalog(mount: GFAssetCatalogMount, catalog: GFAssetCatalog) -> bool:` |
| 方法 | [`unmount_owner`](#member-gfassetcatalogruntime-methods-unmount_owner) | `func unmount_owner(owner_id: StringName) -> int:` |
| 方法 | [`get_catalog`](#member-gfassetcatalogruntime-methods-get_catalog) | `func get_catalog() -> GFAssetCatalog:` |
| 方法 | [`get_revision`](#member-gfassetcatalogruntime-methods-get_revision) | `func get_revision() -> int:` |
| 方法 | [`get_mounts`](#member-gfassetcatalogruntime-methods-get_mounts) | `func get_mounts() -> Array[GFAssetCatalogMount]:` |
| 方法 | [`get_last_report`](#member-gfassetcatalogruntime-methods-get_last_report) | `func get_last_report() -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfassetcatalogruntime-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfassetcatalogruntime-signals-catalog_changed"></a>

### `catalog_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal catalog_changed(catalog: GFAssetCatalog, revision: int)
```

资产目录成功提交新 revision 后发出。

参数：

| 名称 | 说明 |
|---|---|
| `catalog` | 已提交目录的隔离快照。 |
| `revision` | 新 revision。 |

## 常量

<a id="member-gfassetcatalogruntime-constants-conflict_reject"></a>

### `CONFLICT_REJECT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const CONFLICT_REJECT: StringName = &"reject"
```

任一重复 asset ID 都拒绝整次事务。

<a id="member-gfassetcatalogruntime-constants-conflict_keep_high_priority"></a>

### `CONFLICT_KEEP_HIGH_PRIORITY`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const CONFLICT_KEEP_HIGH_PRIORITY: StringName = &"keep_high_priority"
```

重复 asset ID 显式保留高优先级 Mount 的条目。

## 方法

<a id="member-gfassetcatalogruntime-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure(conflict_policy: StringName = CONFLICT_REJECT) -> GFAssetCatalogRuntime:
```

配置全局 asset ID 冲突政策。

参数：

| 名称 | 说明 |
|---|---|
| `conflict_policy` | CONFLICT_REJECT 或 CONFLICT_KEEP_HIGH_PRIORITY。 |

返回：当前 Runtime；已有 Mount 或政策无效时保持原配置。

<a id="member-gfassetcatalogruntime-methods-mount_catalog"></a>

### `mount_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func mount_catalog( owner_id: StringName, mount_id: StringName, catalog: GFAssetCatalog, priority: int = 0, source_id: StringName = &"" ) -> GFAssetCatalogMount:
```

原子挂载一个资产目录快照。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 非空 owner ID。 |
| `mount_id` | owner scope 内非空稳定 ID。 |
| `catalog` | 要挂载的目录；Runtime 保存深拷贝。 |
| `priority` | 合并优先级，数值越大越先处理。 |
| `source_id` | 可选来源 ID；为空时使用 mount_id。 |

返回：活动 Mount 或带稳定失败状态的非活动 Mount。

<a id="member-gfassetcatalogruntime-methods-mount_provider"></a>

### `mount_provider`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func mount_provider( owner_id: StringName, mount_id: StringName, provider: GFAssetCatalogSourceProvider, options: Dictionary = {} ) -> GFAssetCatalogMount:
```

构建 Provider 快照并原子挂载。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 非空 owner ID。 |
| `mount_id` | owner scope 内稳定 ID。 |
| `provider` | 资产目录来源 Provider。 |
| `options` | 传给 Provider 的构建选项。 |

返回：活动 Mount 或带构建失败状态的非活动 Mount。

结构：

- `options`: Dictionary with provider-defined build options.

<a id="member-gfassetcatalogruntime-methods-replace_mount_catalog"></a>

### `replace_mount_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func replace_mount_catalog(mount: GFAssetCatalogMount, catalog: GFAssetCatalog) -> bool:
```

原子替换一个活动 Mount 的目录快照。

参数：

| 名称 | 说明 |
|---|---|
| `mount` | 当前 Runtime 返回的活动 Mount。 |
| `catalog` | 新目录快照。 |

返回：完整候选成功提交返回 true；失败时保留原 Mount、目录和 revision。

<a id="member-gfassetcatalogruntime-methods-unmount_owner"></a>

### `unmount_owner`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func unmount_owner(owner_id: StringName) -> int:
```

批量释放一个 owner 的全部 Mount，并只提交一个新 revision。

参数：

| 名称 | 说明 |
|---|---|
| `owner_id` | 要释放的 owner ID。 |

返回：释放的 Mount 数量。

<a id="member-gfassetcatalogruntime-methods-get_catalog"></a>

### `get_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_catalog() -> GFAssetCatalog:
```

获取当前已提交资产目录快照。

返回：深拷贝目录。

<a id="member-gfassetcatalogruntime-methods-get_revision"></a>

### `get_revision`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_revision() -> int:
```

获取当前目录 revision。

返回：从 0 开始、仅成功提交时递增的 revision。

<a id="member-gfassetcatalogruntime-methods-get_mounts"></a>

### `get_mounts`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_mounts() -> Array[GFAssetCatalogMount]:
```

获取全部活动 Mount。

返回：按合并顺序排列的 Mount 句柄。

<a id="member-gfassetcatalogruntime-methods-get_last_report"></a>

### `get_last_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_last_report() -> Dictionary:
```

获取最近一次运行时报告。

返回：GFValidationReport 兼容字典副本。

结构：

- `return`: GFValidationReport-compatible Dictionary with conflict_policy, revision, mount_count, asset_count, and issues.

<a id="member-gfassetcatalogruntime-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 JSON-safe 调试快照。

返回：Runtime、Mount 和目录摘要。

结构：

- `return`: Dictionary with conflict_policy, disposed, revision, mount_count, mounts, catalog, and last_report.
