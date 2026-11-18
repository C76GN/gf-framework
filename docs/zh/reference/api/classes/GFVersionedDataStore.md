# GFVersionedDataStore

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_versioned_data_store.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

受控写入、原子提交的分页纯数据记录序列。 只有交给此容器的记录参与版本管理。嵌套容器按值隔离，共享引用不保留业务身份。 支持替换、追加与清空；不提供任意位置插删或通用对象图。固定版本不遍历记录。 单线程串行使用；close 后仍须保留存储并推进 collect_garbage，直到回收债务归零。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfversioneddatastore-methods-create) | `static func create(limits: Dictionary = {}) -> GFVersionedDataStore:` |
| 方法 | [`commit`](#member-gfversioneddatastore-methods-commit) | `func commit( replacements: Dictionary, appended: Array = [], expected_revision: int = -1 ) -> Dictionary:` |
| 方法 | [`clear`](#member-gfversioneddatastore-methods-clear) | `func clear() -> Dictionary:` |
| 方法 | [`acquire_snapshot`](#member-gfversioneddatastore-methods-acquire_snapshot) | `func acquire_snapshot() -> GFDataVersion:` |
| 方法 | [`close`](#member-gfversioneddatastore-methods-close) | `func close() -> void:` |
| 方法 | [`collect_garbage`](#member-gfversioneddatastore-methods-collect_garbage) | `func collect_garbage(max_nodes: int = 64) -> int:` |
| 方法 | [`get_statistics`](#member-gfversioneddatastore-methods-get_statistics) | `func get_statistics() -> Dictionary:` |

## 方法

<a id="member-gfversioneddatastore-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(limits: Dictionary = {}) -> GFVersionedDataStore:
```

创建空序列；原始输入通过显式 commit 导入，构造没有隐藏全量复制。

参数：

| 名称 | 说明 |
|---|---|
| `limits` | 正整数限制，未知选项被拒绝。 |

返回：开放存储；非法配置返回 null。

结构：

- `limits`: Dictionary with optional max_records (1000000, at most 2147483647), max_owned_bytes (134217728), max_nodes (2000000), max_versions (16), max_readers (64), max_record_items (4096), max_record_payload_bytes (65536), max_record_depth (32, at most 255), max_record_elapsed_msec (100). Byte accounting includes unique retained nodes, staged input allowance and pending reclamation; it is not process RSS.

<a id="member-gfversioneddatastore-methods-commit"></a>

### `commit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func commit( replacements: Dictionary, appended: Array = [], expected_revision: int = -1 ) -> Dictionary:
```

原子替换已有记录并追加新记录；输入仅需在本次同步调用期间稳定。 每条记录独立隔离；提交失败不改变当前版本或外部输入。大批导入是显式同步成本， 项目可在加载期完成，或以可接受的批次提交；不会自动把活数据当作跨帧稳定源。

参数：

| 名称 | 说明 |
|---|---|
| `replacements` | 已有非负记录位置到新纯数据值的映射。 |
| `appended` | 按顺序追加的记录值。 |
| `expected_revision` | 非负时必须等于当前版本；-1 表示不做乐观版本检查。 |

返回：成功版本或明确失败；失败不消耗版本号。

结构：

- `replacements`: Dictionary[int, Variant], positions must be less than current count; values follow GFDataSnapshot pure-data rules and per-record limits.
- `appended`: Array of pure-data records, each independently isolated.
- `return`: Dictionary with ok: bool, revision: int, error_kind: String; optional record_error: Dictionary from GFDataSnapshot.capture without snapshot.

<a id="member-gfversioneddatastore-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func clear() -> Dictionary:
```

原子清空当前序列；已固定的历史版本保持原内容。

返回：新版本或失败原因；回收由 collect_garbage 推进。

结构：

- `return`: Dictionary with ok: bool, revision: int and error_kind: String.

<a id="member-gfversioneddatastore-methods-acquire_snapshot"></a>

### `acquire_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func acquire_snapshot() -> GFDataVersion:
```

固定当前完整版本，只处理根与元信息，不复制或扫描记录。

返回：独占读取租约；关闭或读者预算耗尽为 null。

<a id="member-gfversioneddatastore-methods-close"></a>

### `close`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func close() -> void:
```

停止写入与新租约，退还当前根；现有租约继续有效。

<a id="member-gfversioneddatastore-methods-collect_garbage"></a>

### `collect_garbage`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func collect_garbage(max_nodes: int = 64) -> int:
```

有界推进失去全部引用的页和记录回收，关闭后仍可调用。

参数：

| 名称 | 说明 |
|---|---|
| `max_nodes` | 本次最多回收的节点数，必须为正。 |

返回：实际回收数量；不会扫描仍被保留的版本。

<a id="member-gfversioneddatastore-methods-get_statistics"></a>

### `get_statistics`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_statistics() -> Dictionary:
```

返回当前版本与全部仍占用预算的存储计量。

返回：纯标量诊断副本，pending_nodes 为零表示当前没有回收债务。

结构：

- `return`: Dictionary with open: bool, revision, count, charged_bytes, peak_bytes, nodes, pending_nodes, versions and readers: int. Caller-owned detached read copies are outside store accounting.
