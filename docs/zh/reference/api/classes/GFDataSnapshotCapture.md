# GFDataSnapshotCapture

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/variant/gf_data_snapshot_capture.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`12.0.0`

从固定版本记录源按共享帧预算构造完整快照。 一个 step 是一条有界记录，不是一个任意大小的对象图。帧额度耗尽仅暂停， 累计数据、工作时间和生命期超限失败。失败输出逐条清理，完成前不交付快照。 创建时接管 source；调用方不得再读取或释放它。会话只在调用线程串行推进。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`begin`](#member-gfdatasnapshotcapture-methods-begin) | `static func begin( source: GFDataSnapshotSource, limits: Dictionary = {}, clock: GFClock = null ) -> GFDataSnapshotCapture:` |
| 方法 | [`advance`](#member-gfdatasnapshotcapture-methods-advance) | `func advance(budget: GFExecutionBudget) -> String:` |
| 方法 | [`cancel`](#member-gfdatasnapshotcapture-methods-cancel) | `func cancel() -> void:` |
| 方法 | [`get_snapshot`](#member-gfdatasnapshotcapture-methods-get_snapshot) | `func get_snapshot() -> GFDataSnapshot:` |
| 方法 | [`get_report`](#member-gfdatasnapshotcapture-methods-get_report) | `func get_report() -> Dictionary:` |

## 方法

<a id="member-gfdatasnapshotcapture-methods-begin"></a>

### `begin`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
static func begin( source: GFDataSnapshotSource, limits: Dictionary = {}, clock: GFClock = null ) -> GFDataSnapshotCapture:
```

接管一个已经固定版本的源；不读取全部记录，不隐藏初始化复制。

参数：

| 名称 | 说明 |
|---|---|
| `source` | 本次调用独占的租约，成功与失败都会接管其释放责任。 |
| `limits` | 有限捕获限制，未知字段被拒绝。 |
| `clock` | 可选单调时钟，用于确定性预算测试；为空时使用系统时钟。 |

返回：会话；非法输入产生已失败会话，报告说明原因。

结构：

- `limits`: Dictionary with optional positive max_records (1000000), max_items (1000000), max_payload_bytes (67108864), max_depth (64, at most 256), max_record_items (4096), max_record_payload_bytes (65536), max_work_msec (30000), max_age_msec (120000). Per-record limits bound the admitted unit; adapter callbacks must themselves be bounded.

<a id="member-gfdatasnapshotcapture-methods-advance"></a>

### `advance`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func advance(budget: GFExecutionBudget) -> String:
```

消费调用方共享的本帧预算，或分步清理失败输出。不会重置预算。

参数：

| 名称 | 说明 |
|---|---|
| `budget` | 本帧共享额度，一个 step 对应一条记录或一次清理；调用方每帧重置一次。 |

返回：pending、ready、failed 或 cancelled；失败不一定已物理 settled。

<a id="member-gfdatasnapshotcapture-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func cancel() -> void:
```

请求取消；若适配器正在读取，只在它返回后停止并释放。

<a id="member-gfdatasnapshotcapture-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_snapshot() -> GFDataSnapshot:
```

取得完整成功快照，不允许获取部分输出。

返回：ready 时的唯一快照；否则为 null。

<a id="member-gfdatasnapshotcapture-methods-get_report"></a>

### `get_report`

- API：`public`
- 首次版本：`12.0.0`

```gdscript
func get_report() -> Dictionary:
```

报告逻辑结果与物理结算状态，调用不会推进操作。

返回：标量状态和累计计量副本。

结构：

- `return`: Dictionary with state, error_kind: String, settled: bool, processed_records, total_records, source_revision, items, payload_bytes, work_msec: int. Ready transfers the lease to the result; failed settlement requires advance with a fresh budget.
