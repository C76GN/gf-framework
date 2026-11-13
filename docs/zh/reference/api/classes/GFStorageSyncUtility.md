# GFStorageSyncUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

以持久化意图和远端条件写入组织记录同步。 只在主线程使用。setup() 后可独立使用；独立使用者须驱动 tick() 处理超时， 并在结束时 dispose()。网络等待不持有项目业务事务。每个记录同时只接纳一个操作。 远端提交前确认意图落盘，提交后确认结果落盘；未知结果只按原操作 ID 查证。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`begin_quiesce`](#member-gfstoragesyncutility-methods-begin_quiesce) | `func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`dispose`](#member-gfstoragesyncutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`setup`](#member-gfstoragesyncutility-methods-setup) | `func setup( transport: GFStorageSyncTransport, journal: GFStorageSyncJournal = null, clock: GFClock = null ) -> bool:` |
| 方法 | [`inspect_support`](#member-gfstoragesyncutility-methods-inspect_support) | `func inspect_support(mode: StringName = &"push", resolution: StringName = &"report") -> Dictionary:` |
| 方法 | [`synchronize`](#member-gfstoragesyncutility-methods-synchronize) | `func synchronize(request: GFStorageSyncRequest) -> GFStorageSyncOperation:` |
| 方法 | [`recover`](#member-gfstoragesyncutility-methods-recover) | `func recover(request: GFStorageSyncRequest) -> GFStorageSyncOperation:` |
| 方法 | [`synchronize_many`](#member-gfstoragesyncutility-methods-synchronize_many) | `func synchronize_many(requests: Array[GFStorageSyncRequest]) -> Array[GFStorageSyncOperation]:` |
| 方法 | [`tick`](#member-gfstoragesyncutility-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfstoragesyncutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfstoragesyncutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

停止接纳并终结所有观察；不声称撤销已发送的远端操作。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 架构关闭作用域。 |

返回：已完成的静默完成源；未知提交保留在持久化日志供后续恢复。

<a id="member-gfstoragesyncutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

释放全部观察和适配器引用，原意图仍由持久化日志拥有。

<a id="member-gfstoragesyncutility-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func setup( transport: GFStorageSyncTransport, journal: GFStorageSyncJournal = null, clock: GFClock = null ) -> bool:
```

一次性装配；只读用途允许 journal 为空。

参数：

| 名称 | 说明 |
|---|---|
| `transport` | 冻结认证会话的远端适配器。 |
| `journal` | 写入与恢复需要的持久化日志。 |
| `clock` | 单调时钟；空时使用系统单调时间。 |

返回：装配成功返回 true；重复装配或关闭后返回 false。

<a id="member-gfstoragesyncutility-methods-inspect_support"></a>

### `inspect_support`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func inspect_support(mode: StringName = &"push", resolution: StringName = &"report") -> Dictionary:
```

只读检查本模式的协议能力与日志要求，不开始网络或日志 IO。 能力来自 Transport 当前声明，不证明服务端实现正确；实际准入会再次检查。 pull、preview 与 push/remote 不需要 Journal；probe 只需要 probe 与 Journal。

参数：

| 名称 | 说明 |
|---|---|
| `mode` | push、pull、preview 或 probe。 |
| `resolution` | report、local 或 remote。 |

返回：模式支持报告，不包含账号或业务数据。

结构：

- `return`: Dictionary with ok:bool,error_kind:StringName,path:String,mode:StringName,resolution:StringName,required_capabilities:PackedStringArray,missing_capabilities:PackedStringArray,journal_required:bool,journal_available:bool.

<a id="member-gfstoragesyncutility-methods-synchronize"></a>

### `synchronize`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func synchronize(request: GFStorageSyncRequest) -> GFStorageSyncOperation:
```

开始一次冻结请求；可能同步完成，观察前应检查 is_completed()。 push 默认报告版本冲突；显式 local 选择使用本次读到的 revision 再执行一次 CAS。 pull/remote 只返回远端候选，由调用方以自己的事务应用。preview 从不写入。 自定义合并使用冲突报告构建新请求，填入实际 revision 和新的 operation_id。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 冻结请求；probe 模式进入 recover()。 |

返回：唯一终态操作；非法输入也返回已拒绝操作。

<a id="member-gfstoragesyncutility-methods-recover"></a>

### `recover`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func recover(request: GFStorageSyncRequest) -> GFStorageSyncOperation:
```

查证原意图的历史结果，绝不重发条件写入。 调用方可先使用 journal.load_intent() 读取完整记录并调用 Request.from_record()。 引擎再次验证日志仍包含同一意图，防止错认操作或跨记录恢复。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 原持久化请求；除观察模式外的规范记录必须一致。 |

返回：查证操作；未知结果和本地 checkpoint 失败仍保留恢复责任。

<a id="member-gfstoragesyncutility-methods-synchronize_many"></a>

### `synchronize_many`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func synchronize_many(requests: Array[GFStorageSyncRequest]) -> Array[GFStorageSyncOperation]:
```

启动相互独立的记录操作，不提供跨记录原子性。

参数：

| 名称 | 说明 |
|---|---|
| `requests` | 最多256个冻结请求；同记录在途竞争逐项拒绝。 |

返回：与输入顺序一致的操作；超限时不启动任何请求，只返回一个 batch_limit 拒绝结果。

<a id="member-gfstoragesyncutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float) -> void:
```

用单调时间终结超时观察，delta 不参与截止时间计算。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 架构传入的帧间隔。 |

<a id="member-gfstoragesyncutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不包含账号、记录键、载荷或 revision 的诊断。

返回：当前观察数量和装配状态。

结构：

- `return`: Dictionary with configured:bool,closed:bool,pending_count:int,phases:Dictionary[StringName,int].
