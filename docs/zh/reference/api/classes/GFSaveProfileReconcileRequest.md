# GFSaveProfileReconcileRequest

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_reconcile_request.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

uncertain 写入对账的一次性请求句柄。 请求只携带调用方纯数据上下文和结果元数据，不携带 Recovery/Reconcile Lease 身份。Lease 必须作为独立类型化参数提交，避免从 Dictionary 恢复所有权。 `create()` 隔离两个元数据字典，调用方可继续修改源数据。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`create`](#member-gfsaveprofilereconcilerequest-methods-create) | `static func create(context: Dictionary = {}, result_metadata: Dictionary = {}) -> GFSaveProfileReconcileRequest:` |
| 方法 | [`is_available`](#member-gfsaveprofilereconcilerequest-methods-is_available) | `func is_available() -> bool:` |
| 方法 | [`is_claimed`](#member-gfsaveprofilereconcilerequest-methods-is_claimed) | `func is_claimed() -> bool:` |

## 方法

<a id="member-gfsaveprofilereconcilerequest-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create(context: Dictionary = {}, result_metadata: Dictionary = {}) -> GFSaveProfileReconcileRequest:
```

创建请求并隔离 context 与 result_metadata 的纯数据快照。 输入必须是有界纯 Variant 数据，不能包含 Callable、Object、Signal、RID 或 循环集合或非有限数。两个字典合计最多 64 层、100000 节点、1 MiB 保守复制预算。 该请求不接受可执行恢复策略或 patch；项目策略应在提交前完成决策。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 对账流程使用的临时纯数据上下文。 |
| `result_metadata` | 只写入当前对账结果的调用方纯数据元数据。 |

返回：可用请求；输入无效时返回 null。

结构：

- `context`: Bounded Dictionary without Callable, Signal, RID, Object, or circular references copied into an isolated snapshot.
- `result_metadata`: Bounded Dictionary without Callable, Signal, RID, Object, or circular references copied into an isolated snapshot.

<a id="member-gfsaveprofilereconcilerequest-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_available() -> bool:
```

检查请求是否仍可由协调器接管。

返回：尚未 claim 时返回 true。

<a id="member-gfsaveprofilereconcilerequest-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_claimed() -> bool:
```

检查请求是否已经被协调器接管。

返回：已成功 claim 时返回 true。
