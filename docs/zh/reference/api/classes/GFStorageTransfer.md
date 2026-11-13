# GFStorageTransfer

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_transfer.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

通用存储后端传输协调器。 该工具只协调两个 GFStorageBackend 的字典数据传输、冲突检测和写回策略。 普通 Backend 没有 CAS 或跨端原子性；写入可能部分成功，结果始终明确这些能力边界。 默认只报告冲突。USE_NEWEST 仅是显式元数据选择规则，不保证并发安全或远端 revision 顺序。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`transfer_conflict_detected`](#member-gfstoragetransfer-signals-transfer_conflict_detected) | `signal transfer_conflict_detected(report: GFStorageConflictReport)` |
| 信号 | [`transfer_conflict_unresolved`](#member-gfstoragetransfer-signals-transfer_conflict_unresolved) | `signal transfer_conflict_unresolved(file_name: String, result: Dictionary)` |
| 信号 | [`transfer_completed`](#member-gfstoragetransfer-signals-transfer_completed) | `signal transfer_completed(file_name: String, result: Dictionary)` |
| 信号 | [`transfer_failed`](#member-gfstoragetransfer-signals-transfer_failed) | `signal transfer_failed(file_name: String, result: Dictionary)` |
| 枚举 | [`ConflictStrategy`](#member-gfstoragetransfer-enums-conflictstrategy) | `enum ConflictStrategy` |
| 枚举 | [`TransferStatus`](#member-gfstoragetransfer-enums-transferstatus) | `enum TransferStatus` |
| 属性 | [`default_conflict_strategy`](#member-gfstoragetransfer-properties-default_conflict_strategy) | `var default_conflict_strategy: ConflictStrategy = ConflictStrategy.MANUAL` |
| 属性 | [`write_resolved_by_default`](#member-gfstoragetransfer-properties-write_resolved_by_default) | `var write_resolved_by_default: bool = true` |
| 方法 | [`transfer_data`](#member-gfstoragetransfer-methods-transfer_data) | `func transfer_data( file_name: String, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`transfer_many`](#member-gfstoragetransfer-methods-transfer_many) | `func transfer_many( file_names: PackedStringArray, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragetransfer-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfstoragetransfer-signals-transfer_conflict_detected"></a>

### `transfer_conflict_detected`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transfer_conflict_detected(report: GFStorageConflictReport)
```

检测到存储冲突后发出。

参数：

| 名称 | 说明 |
|---|---|
| `report` | 冲突报告。 |

<a id="member-gfstoragetransfer-signals-transfer_conflict_unresolved"></a>

### `transfer_conflict_unresolved`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transfer_conflict_unresolved(file_name: String, result: Dictionary)
```

单个逻辑文件存在未解决冲突时发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 传输结果字典。 |

结构：

- `result`: Dictionary，由 transfer_data() 为未解决冲突返回。

<a id="member-gfstoragetransfer-signals-transfer_completed"></a>

### `transfer_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transfer_completed(file_name: String, result: Dictionary)
```

单个逻辑文件传输完成后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 传输结果字典。 |

结构：

- `result`: Dictionary，由 transfer_data() 为已完成传输返回。

<a id="member-gfstoragetransfer-signals-transfer_failed"></a>

### `transfer_failed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transfer_failed(file_name: String, result: Dictionary)
```

单个逻辑文件传输失败后发出。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `result` | 传输结果字典。 |

结构：

- `result`: Dictionary，由 transfer_data() 为失败传输返回。

## 枚举

<a id="member-gfstoragetransfer-enums-conflictstrategy"></a>

### `ConflictStrategy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum ConflictStrategy {
	## 按后端元数据中的有限 revision/timestamp 选择更新的一侧；缺失或非有限值无法判断时保留冲突。
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

<a id="member-gfstoragetransfer-enums-transferstatus"></a>

### `TransferStatus`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum TransferStatus {
	## 已选择候选但没有写入任何后端。
	PREVIEW,
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
	## 传输失败。
	FAILED,
}
```

传输结果状态。

## 属性

<a id="member-gfstoragetransfer-properties-default_conflict_strategy"></a>

### `default_conflict_strategy`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var default_conflict_strategy: ConflictStrategy = ConflictStrategy.MANUAL
```

默认冲突策略。

<a id="member-gfstoragetransfer-properties-write_resolved_by_default"></a>

### `write_resolved_by_default`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var write_resolved_by_default: bool = true
```

默认是否把解析出的结果写回后端。关闭后可用于 dry-run。

## 方法

<a id="member-gfstoragetransfer-methods-transfer_data"></a>

### `transfer_data`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func transfer_data( file_name: String, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

传输一个逻辑文件。非法 strategy 在任何后端读取前拒绝；只有确认不存在才填充缺失端。

参数：

| 名称 | 说明 |
|---|---|
| `file_name` | 逻辑文件名。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 传输选项，支持 strategy、write_resolved、write_to_local、write_to_remote、resolver、revision_keys、timestamp_keys。 |

返回：传输结果字典。

结构：

- `options`: Dictionary，包含 strategy: ConflictStrategy、write_resolved: bool、write_to_local: bool、write_to_remote: bool、resolver: Callable、resolution_callback: Callable、revision_keys: Array[String] 和 timestamp_keys: Array[String]。
- `return`: Dictionary，包含 ok、file_name、status、status_name、selected_source、written_backends、conflicts、errors、error、error_kind、path、data、metadata、local、remote，以及恒为 false 的 concurrent_write_protection、cross_backend_atomic。

<a id="member-gfstoragetransfer-methods-transfer_many"></a>

### `transfer_many`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func transfer_many( file_names: PackedStringArray, local_backend: GFStorageBackend, remote_backend: GFStorageBackend, options: Dictionary = {} ) -> Dictionary:
```

批量传输多个逻辑文件。

参数：

| 名称 | 说明 |
|---|---|
| `file_names` | 最多256个逻辑文件名；超限不开始任何传输。 |
| `local_backend` | 本地或主后端。 |
| `remote_backend` | 远端或副后端。 |
| `options` | 传给 transfer_data() 的传输选项。 |

返回：批量结果字典。

结构：

- `options`: Dictionary，支持字段与 transfer_data() 相同。
- `return`: Dictionary，包含 ok: bool、count: int、results: Array[Dictionary] 和 status_counts: Dictionary；批量超限还包含 error:String，count 为0。

<a id="member-gfstoragetransfer-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取传输工具调试快照。

返回：调试快照字典。

结构：

- `return`: Dictionary，包含 transfer_count、conflict_count、failed_count、default_conflict_strategy 和 write_resolved_by_default。
