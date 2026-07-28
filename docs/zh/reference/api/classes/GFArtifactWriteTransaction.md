# GFArtifactWriteTransaction

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/editor/gf_artifact_write_transaction.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：工具 API (`tool_api`)
- 首次版本：`unreleased`

编辑器与项目工具可复用的多产物文件提交事务。 在显式资源根、文件数量和字节预算内预检文本、字节或临时文件产物， 先把全部内容写入目标同目录的 staging 文件，再逐项替换目标。任一提交 失败时逆序恢复已有目标并删除本次新增目标。该类不解释产物格式、生成器 业务、导入策略或远端发布目标，也不把进程中断或系统崩溃下的多文件 持久化误称为 crash-atomic。GDScript 文件 API 无法固定父目录句柄，因此 allowed_roots 必须位于调用方信任且不会被本机其他进程恶意交换 junction 的目录；实现会在 rename、删除和恢复前后复核可观察的路径、内容与 sidecar 身份，并在漂移时 fail closed，而不是盲目破坏未知文件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`KIND_TEXT`](#member-gfartifactwritetransaction-constants-kind_text) | `const KIND_TEXT: StringName = &"text"` |
| 常量 | [`KIND_BYTES`](#member-gfartifactwritetransaction-constants-kind_bytes) | `const KIND_BYTES: StringName = &"bytes"` |
| 常量 | [`KIND_FILE`](#member-gfartifactwritetransaction-constants-kind_file) | `const KIND_FILE: StringName = &"file"` |
| 常量 | [`DEFAULT_MAX_FILE_COUNT`](#member-gfartifactwritetransaction-constants-default_max_file_count) | `const DEFAULT_MAX_FILE_COUNT: int = 256` |
| 常量 | [`DEFAULT_MAX_FILE_BYTES`](#member-gfartifactwritetransaction-constants-default_max_file_bytes) | `const DEFAULT_MAX_FILE_BYTES: int = 64 * 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_TOTAL_BYTES`](#member-gfartifactwritetransaction-constants-default_max_total_bytes) | `const DEFAULT_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024` |
| 常量 | [`DEFAULT_MAX_BACKUP_BYTES`](#member-gfartifactwritetransaction-constants-default_max_backup_bytes) | `const DEFAULT_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024` |
| 常量 | [`ABSOLUTE_MAX_FILE_COUNT`](#member-gfartifactwritetransaction-constants-absolute_max_file_count) | `const ABSOLUTE_MAX_FILE_COUNT: int = 1024` |
| 常量 | [`ABSOLUTE_MAX_FILE_BYTES`](#member-gfartifactwritetransaction-constants-absolute_max_file_bytes) | `const ABSOLUTE_MAX_FILE_BYTES: int = 64 * 1024 * 1024` |
| 常量 | [`ABSOLUTE_MAX_TOTAL_BYTES`](#member-gfartifactwritetransaction-constants-absolute_max_total_bytes) | `const ABSOLUTE_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024` |
| 常量 | [`ABSOLUTE_MAX_BACKUP_BYTES`](#member-gfartifactwritetransaction-constants-absolute_max_backup_bytes) | `const ABSOLUTE_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024` |
| 常量 | [`ABSOLUTE_MAX_ACTIVE_TRANSACTIONS`](#member-gfartifactwritetransaction-constants-absolute_max_active_transactions) | `const ABSOLUTE_MAX_ACTIVE_TRANSACTIONS: int = 256` |
| 常量 | [`RECOVERY_ACTION_ROLLBACK`](#member-gfartifactwritetransaction-constants-recovery_action_rollback) | `const RECOVERY_ACTION_ROLLBACK: StringName = &"rollback"` |
| 常量 | [`RECOVERY_ACTION_COMPLETE`](#member-gfartifactwritetransaction-constants-recovery_action_complete) | `const RECOVERY_ACTION_COMPLETE: StringName = &"complete"` |
| 方法 | [`make_text_entry`](#member-gfartifactwritetransaction-methods-make_text_entry) | `static func make_text_entry( target_path: String, text: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_bytes_entry`](#member-gfartifactwritetransaction-methods-make_bytes_entry) | `static func make_bytes_entry( target_path: String, bytes: PackedByteArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`make_file_entry`](#member-gfartifactwritetransaction-methods-make_file_entry) | `static func make_file_entry( target_path: String, source_path: String, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`get_preflight_report`](#member-gfartifactwritetransaction-methods-get_preflight_report) | `static func get_preflight_report( entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`commit`](#member-gfartifactwritetransaction-methods-commit) | `static func commit( entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`begin`](#member-gfartifactwritetransaction-methods-begin) | `static func begin( paths: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`rollback`](#member-gfartifactwritetransaction-methods-rollback) | `static func rollback(transaction: Dictionary) -> Dictionary:` |
| 方法 | [`complete`](#member-gfartifactwritetransaction-methods-complete) | `static func complete(transaction: Dictionary) -> Dictionary:` |

## 常量

<a id="member-gfartifactwritetransaction-constants-kind_text"></a>

### `KIND_TEXT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const KIND_TEXT: StringName = &"text"
```

文本产物 entry 类型。

<a id="member-gfartifactwritetransaction-constants-kind_bytes"></a>

### `KIND_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const KIND_BYTES: StringName = &"bytes"
```

字节产物 entry 类型。

<a id="member-gfartifactwritetransaction-constants-kind_file"></a>

### `KIND_FILE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const KIND_FILE: StringName = &"file"
```

已有临时文件产物 entry 类型。

<a id="member-gfartifactwritetransaction-constants-default_max_file_count"></a>

### `DEFAULT_MAX_FILE_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_FILE_COUNT: int = 256
```

默认最大产物数量。

<a id="member-gfartifactwritetransaction-constants-default_max_file_bytes"></a>

### `DEFAULT_MAX_FILE_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_FILE_BYTES: int = 64 * 1024 * 1024
```

默认单产物最大字节数。

<a id="member-gfartifactwritetransaction-constants-default_max_total_bytes"></a>

### `DEFAULT_MAX_TOTAL_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024
```

默认单批产物最大总字节数。

<a id="member-gfartifactwritetransaction-constants-default_max_backup_bytes"></a>

### `DEFAULT_MAX_BACKUP_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DEFAULT_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024
```

默认事务回滚快照最大总字节数。

<a id="member-gfartifactwritetransaction-constants-absolute_max_file_count"></a>

### `ABSOLUTE_MAX_FILE_COUNT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_FILE_COUNT: int = 1024
```

单次事务允许的产物数量绝对上限。

<a id="member-gfartifactwritetransaction-constants-absolute_max_file_bytes"></a>

### `ABSOLUTE_MAX_FILE_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_FILE_BYTES: int = 64 * 1024 * 1024
```

单个产物允许的字节数绝对上限。

<a id="member-gfartifactwritetransaction-constants-absolute_max_total_bytes"></a>

### `ABSOLUTE_MAX_TOTAL_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_TOTAL_BYTES: int = 256 * 1024 * 1024
```

单次事务允许的产物总字节数绝对上限。

<a id="member-gfartifactwritetransaction-constants-absolute_max_backup_bytes"></a>

### `ABSOLUTE_MAX_BACKUP_BYTES`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_BACKUP_BYTES: int = 256 * 1024 * 1024
```

单次事务允许的回滚快照总字节数绝对上限。

<a id="member-gfartifactwritetransaction-constants-absolute_max_active_transactions"></a>

### `ABSOLUTE_MAX_ACTIVE_TRANSACTIONS`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const ABSOLUTE_MAX_ACTIVE_TRANSACTIONS: int = 256
```

同一进程内允许保持 open 的事务绝对上限。

<a id="member-gfartifactwritetransaction-constants-recovery_action_rollback"></a>

### `RECOVERY_ACTION_ROLLBACK`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const RECOVERY_ACTION_ROLLBACK: StringName = &"rollback"
```

恢复报告要求调用 rollback()。

<a id="member-gfartifactwritetransaction-constants-recovery_action_complete"></a>

### `RECOVERY_ACTION_COMPLETE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const RECOVERY_ACTION_COMPLETE: StringName = &"complete"
```

恢复报告要求调用 complete()。

## 方法

<a id="member-gfartifactwritetransaction-methods-make_text_entry"></a>

### `make_text_entry`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func make_text_entry( target_path: String, text: String, options: Dictionary = {} ) -> Dictionary:
```

创建文本产物 entry。

参数：

| 名称 | 说明 |
|---|---|
| `target_path` | 目标 `res://` 或 `user://` 文件路径。 |
| `text` | UTF-8 文本内容。 |
| `options` | 单 entry 选项。 |

返回：可交给 commit() 的 entry 副本。

结构：

- `options`: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
- `return`: Dictionary，包含 kind、target_path、text、overwrite、expected_sha256、artifact_id 和 metadata。

<a id="member-gfartifactwritetransaction-methods-make_bytes_entry"></a>

### `make_bytes_entry`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func make_bytes_entry( target_path: String, bytes: PackedByteArray, options: Dictionary = {} ) -> Dictionary:
```

创建字节产物 entry。

参数：

| 名称 | 说明 |
|---|---|
| `target_path` | 目标 `res://` 或 `user://` 文件路径。 |
| `bytes` | 产物字节；entry 持有隔离副本。 |
| `options` | 单 entry 选项。 |

返回：可交给 commit() 的 entry 副本。

结构：

- `options`: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
- `return`: Dictionary，包含 kind、target_path、bytes、overwrite、expected_sha256、artifact_id 和 metadata。

<a id="member-gfartifactwritetransaction-methods-make_file_entry"></a>

### `make_file_entry`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func make_file_entry( target_path: String, source_path: String, options: Dictionary = {} ) -> Dictionary:
```

创建已有文件产物 entry。 source_path 只在 commit() 期间读取，不会被移动或删除。

参数：

| 名称 | 说明 |
|---|---|
| `target_path` | 目标 `res://` 或 `user://` 文件路径。 |
| `source_path` | 已生成文件路径。 |
| `options` | 单 entry 选项。 |

返回：可交给 commit() 的 entry 副本。

结构：

- `options`: Dictionary，可包含 overwrite、expected_sha256、artifact_id 和 metadata。
- `return`: Dictionary，包含 kind、target_path、source_path、overwrite、expected_sha256、artifact_id 和 metadata。

<a id="member-gfartifactwritetransaction-methods-get_preflight_report"></a>

### `get_preflight_report`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func get_preflight_report( entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

预检一组产物 entry，不创建目录或写入文件。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | make_text_entry()、make_bytes_entry() 或 make_file_entry() 创建的 entry。 |
| `options` | 批次边界选项。 |

返回：JSON-safe 预检报告。

结构：

- `entries`: Array[Dictionary]，每项包含 kind、target_path、对应内容和可选 entry 选项。
- `options`: Dictionary，必须包含非空 allowed_roots；可包含 overwrite_existing、max_file_count、max_file_bytes、max_total_bytes、max_backup_bytes、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 ok、status、entry_count、changed_count、unchanged_count、total_bytes、backup_bytes、issues、entries 和 metadata。

<a id="member-gfartifactwritetransaction-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func commit( entries: Array[Dictionary], options: Dictionary = {} ) -> Dictionary:
```

以运行期补偿事务提交一组产物。 dry_run 为 true 时只执行完整预检。成功写入时全部 staging 文件均已校验， 目标替换失败会触发逆序回滚；回滚不完整会在报告中显式标记。 每个同目录 rename 是独立文件替换，多目标整体不提供 crash atomicity。 提交入口只允许在主线程调用，错误线程会在任何目录或文件写入前失败。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | make_text_entry()、make_bytes_entry() 或 make_file_entry() 创建的 entry。 |
| `options` | 批次边界选项。 |

返回：JSON-safe 提交报告。

结构：

- `entries`: Array[Dictionary]，每项包含 kind、target_path、对应内容和可选 entry 选项。
- `options`: Dictionary，必须包含非空 allowed_roots；可包含 overwrite_existing、max_file_count、max_file_bytes、max_total_bytes、max_backup_bytes、dry_run、scan_filesystem 和 metadata。
- `return`: Dictionary，包含 ok、status、entry_count、written_count、unchanged_count、total_bytes、backup_bytes、rolled_back、rollback_complete、recovery_required、recovery_action、recovery_transaction、issues、reports 和 metadata；recovery_required 为 true 时，调用方必须按 recovery_action 将 recovery_transaction 原样交给 rollback() 或 complete()。

<a id="member-gfartifactwritetransaction-methods-begin"></a>

### `begin`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func begin( paths: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

捕获一组外部写入目标的事务前状态。 适合调用方必须使用 ResourceSaver 或其他专用 materializer 写最终目标的场景。 begin() 成功后，调用方必须且只能调用 complete() 或 rollback() 之一。

参数：

| 名称 | 说明 |
|---|---|
| `paths` | 本次外部事务可能创建或覆盖的完整文件路径。 |
| `options` | 快照边界选项。 |

返回：只能原样交给 complete() 或 rollback() 的完整性校验事务字典；调用方不得改写。

结构：

- `options`: Dictionary，必须包含非空 allowed_roots；可包含 max_file_count、max_backup_bytes 和 metadata。
- `return`: opaque Dictionary，包含 ok、format、format_version、state、transaction_id、transaction_token、entry_count、backup_bytes 和 metadata；不暴露目标或备份路径。

<a id="member-gfartifactwritetransaction-methods-rollback"></a>

### `rollback`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func rollback(transaction: Dictionary) -> Dictionary:
```

逆序恢复 begin() 捕获的全部目标。

参数：

| 名称 | 说明 |
|---|---|
| `transaction` | begin() 返回且处于 open 状态的原始事务字典；任何改写都会失败。 |

返回：回滚报告。

结构：

- `transaction`: Dictionary，符合 gf.artifact_write.transaction@1。
- `return`: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction；recovery_required 为 true 时必须按 recovery_action 使用 recovery_transaction 重试要求的终态动作。

<a id="member-gfartifactwritetransaction-methods-complete"></a>

### `complete`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func complete(transaction: Dictionary) -> Dictionary:
```

完成 begin() 捕获的事务并删除回滚快照。

参数：

| 名称 | 说明 |
|---|---|
| `transaction` | begin() 返回且处于 open 状态的原始事务字典；任何改写都会失败。 |

返回：完成报告。

结构：

- `transaction`: Dictionary，符合 gf.artifact_write.transaction@1。
- `return`: Dictionary，包含 ok、status、restored_paths、failed_paths、issues、recovery_required、recovery_action 和 recovery_transaction；recovery_required 为 true 时 recovery_action 为 complete，必须使用 recovery_transaction 重试 complete()。
