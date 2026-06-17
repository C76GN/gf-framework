# GFStorageSyncUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用存储后端同步协调器。 该工具只协调两个 GFStorageBackend 的字典数据同步、冲突检测和写回策略。 它不绑定本地/云/平台 SDK，也不替项目定义存档业务结构。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`sync_conflict_detected`](#member-gfstoragesyncutility-signals-sync_conflict_detected) | `signal sync_conflict_detected(report: GFStorageConflictReport)` |
| 信号 | [`sync_conflict_unresolved`](#member-gfstoragesyncutility-signals-sync_conflict_unresolved) | `signal sync_conflict_unresolved(file_name: String, result: Dictionary)` |
| 信号 | [`sync_completed`](#member-gfstoragesyncutility-signals-sync_completed) | `signal sync_completed(file_name: String, result: Dictionary)` |
| 信号 | [`sync_failed`](#member-gfstoragesyncutility-signals-sync_failed) | `signal sync_failed(file_name: String, result: Dictionary)` |
| 枚举 | [`ConflictStrategy`](#member-gfstoragesyncutility-enums-conflictstrategy) | `enum ConflictStrategy` |
| 枚举 | [`SyncStatus`](#member-gfstoragesyncutility-enums-syncstatus) | `enum SyncStatus` |
| 属性 | [`default_conflict_strategy`](#member-gfstoragesyncutility-properties-default_conflict_strategy) | `var default_conflict_strategy: ConflictStrategy = ConflictStrategy.USE_NEWEST` |
| 属性 | [`write_resolved_by_default`](#member-gfstoragesyncutility-properties-write_resolved_by_default) | `var write_resolved_by_default: bool = true` |
| 方法 | [`sync_data`](#member-gfstoragesyncutility-methods-sync_data) | `func sync_data( file_name: String, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`sync_many`](#member-gfstoragesyncutility-methods-sync_many) | `func sync_many( file_names: PackedStringArray, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragesyncutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfstoragesyncutility-signals-sync_conflict_detected"></a>

### `sync_conflict_detected`

- API：`public`

```gdscript
signal sync_conflict_detected(report: GFStorageConflictReport)
```

检测到存储冲突后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 冲突报告。 |

<a id="member-gfstoragesyncutility-signals-sync_conflict_unresolved"></a>

### `sync_conflict_unresolved`

- API：`public`

```gdscript
signal sync_conflict_unresolved(file_name: String, result: Dictionary)
```

单个逻辑文件存在未解决冲突时发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 同步结果字典。 |

结构：

- `result`: Dictionary，由 sync_data() 为未解决冲突返回。

<a id="member-gfstoragesyncutility-signals-sync_completed"></a>

### `sync_completed`

- API：`public`

```gdscript
signal sync_completed(file_name: String, result: Dictionary)
```

单个逻辑文件同步完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 同步结果字典。 |

结构：

- `result`: Dictionary，由 sync_data() 为已完成同步返回。

<a id="member-gfstoragesyncutility-signals-sync_failed"></a>

### `sync_failed`

- API：`public`

```gdscript
signal sync_failed(file_name: String, result: Dictionary)
```

单个逻辑文件同步失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 同步结果字典。 |

结构：

- `result`: Dictionary，由 sync_data() 为失败同步返回。

## 枚举

<a id="member-gfstoragesyncutility-enums-conflictstrategy"></a>

### `ConflictStrategy`

- API：`public`

```gdscript
enum ConflictStrategy {
	## 按后端元数据中的 revision/timestamp 选择更新的一侧；无法判断时保留冲突。
	USE_NEWEST,
	## 冲突时使用 local_backend 的数据。
	USE_LOCAL,
	## 冲突时使用 remote_backend 的数据。
	USE_REMOTE,
	## 只报告冲突，不自动写回。
	MANUAL,
	## 调用 options.resolver 或 options.resolution_callback 生成结果。
	CUSTOM,
}
```

冲突解决策略。

<a id="member-gfstoragesyncutility-enums-syncstatus"></a>

### `SyncStatus`

- API：`public`

```gdscript
enum SyncStatus {
	## 两端数据已经一致。
	UNCHANGED,
	## 已把 local_backend 数据复制到 remote_backend。
	COPIED_LOCAL_TO_REMOTE,
	## 已把 remote_backend 数据复制到 local_backend。
	COPIED_REMOTE_TO_LOCAL,
	## 已用自定义合并结果写回两端。
	MERGED,
	## 存在未解决冲突。
	CONFLICT,
	## 同步失败。
	FAILED,
}
```

同步结果状态。

## 属性

<a id="member-gfstoragesyncutility-properties-default_conflict_strategy"></a>

### `default_conflict_strategy`

- API：`public`

```gdscript
var default_conflict_strategy: ConflictStrategy = ConflictStrategy.USE_NEWEST
```

默认冲突策略。

<a id="member-gfstoragesyncutility-properties-write_resolved_by_default"></a>

### `write_resolved_by_default`

- API：`public`

```gdscript
var write_resolved_by_default: bool = true
```

默认是否把解析出的结果写回后端。关闭后可用于 dry-run。

## 方法

<a id="member-gfstoragesyncutility-methods-sync_data"></a>

### `sync_data`

- API：`public`

```gdscript
func sync_data( file_name: String, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

同步一个逻辑文件。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 同步选项，支持 strategy、write_resolved、write_to_local、write_to_remote、resolver、revision_keys、timestamp_keys。 |

返回：同步结果字典。

结构：

- `options`: Dictionary，包含 strategy: ConflictStrategy、write_resolved: bool、write_to_local: bool、write_to_remote: bool、resolver: Callable、resolution_callback: Callable、revision_keys: Array[String] 和 timestamp_keys: Array[String]。
- `return`: Dictionary，包含 ok、file_name、status、status_name、selected_source、written_backends、conflicts、errors、error、data、metadata、local 和 remote。

<a id="member-gfstoragesyncutility-methods-sync_many"></a>

### `sync_many`

- API：`public`

```gdscript
func sync_many( file_names: PackedStringArray, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

批量同步多个逻辑文件。

参数：

| 名称 | 说明 |
|---|---|
| `file_names` | 逻辑文件名列表。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 传给 sync_data() 的同步选项。 |

返回：批量结果字典。

结构：

- `options`: Dictionary，支持字段与 sync_data() 相同。
- `return`: Dictionary，包含 ok: bool、count: int、results: Array[Dictionary] 和 status_counts: Dictionary。

<a id="member-gfstoragesyncutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取同步工具调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 sync_count、conflict_count、failed_count、default_conflict_strategy 和 write_resolved_by_default。
