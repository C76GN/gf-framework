# GFStorageSyncJournal

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_journal.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

同步意图与提交结果的持久化边界。 完成源成功表示持久化已经确认，不能只表示已排队或内存更新。一个记录只能有一个 未解决意图；不同 operation_id 不得覆盖它。Save 通过现有 Profile 事务实现本接口， 普通记录可以使用自己的持久化适配器。该接口不实现网络、账号认证或第二套业务事务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`persist_intent`](#member-gfstoragesyncjournal-methods-persist_intent) | `func persist_intent(request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`persist_outcome`](#member-gfstoragesyncjournal-methods-persist_outcome) | `func persist_outcome(request: GFStorageSyncRequest, outcome: Dictionary) -> GFAsyncCompletion:` |
| 方法 | [`load_intent`](#member-gfstoragesyncjournal-methods-load_intent) | `func load_intent(record_namespace: String, record_key: String) -> GFAsyncCompletion:` |
| 方法 | [`_persist_intent`](#member-gfstoragesyncjournal-methods-_persist_intent) | `func _persist_intent(_request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`_persist_outcome`](#member-gfstoragesyncjournal-methods-_persist_outcome) | `func _persist_outcome(_request: GFStorageSyncRequest, _outcome: Dictionary) -> GFAsyncCompletion:` |
| 方法 | [`_load_intent`](#member-gfstoragesyncjournal-methods-_load_intent) | `func _load_intent(_record_namespace: String, _record_key: String) -> GFAsyncCompletion:` |

## 方法

<a id="member-gfstoragesyncjournal-methods-persist_intent"></a>

### `persist_intent`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func persist_intent(request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

在远端发送前持久化精确意图；重复相同意图可幂等确认。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 即将发送的冻结请求，包含实际 CAS revision。 |

返回：成功表示意图已持久化；失败或未知时引擎不得发送远端写入。

<a id="member-gfstoragesyncjournal-methods-persist_outcome"></a>

### `persist_outcome`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func persist_outcome(request: GFStorageSyncRequest, outcome: Dictionary) -> GFAsyncCompletion:
```

持久化已查证的操作结果及 checkpoint，再释放对应未解决意图。 写入结果不能覆盖其他 operation_id 的意图；相同结果应支持幂等恢复。失败时必须 保留可恢复证据，不能把已知远端提交误记为未提交。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 原持久化意图。 |
| `outcome` | 已经过协议校验的远端终态。 |

返回：成功表示 checkpoint 已持久化；失败要求保留待恢复状态。

结构：

- `outcome`: Closed Dictionary following GFStorageSyncTransport.conditional_write(); status is committed,conflict or not_committed. Contains namespace,key,operation_id,exists,revision,data; may contain business payload and must not be logged.

<a id="member-gfstoragesyncjournal-methods-load_intent"></a>

### `load_intent`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func load_intent(record_namespace: String, record_key: String) -> GFAsyncCompletion:
```

读取指定记录的未解决意图。

参数：

| 名称 | 说明 |
|---|---|
| `record_namespace` | 稳定命名空间。 |
| `record_key` | 稳定记录键。 |

返回：成功结果为规范意图记录；空字典仅表示确认不存在意图，读取失败不得冒充空。

结构：

- `return`: GFAsyncCompletion success result is Dictionary accepted by GFStorageSyncRequest.from_record(), or empty Dictionary when no unresolved intent exists.

<a id="member-gfstoragesyncjournal-methods-_persist_intent"></a>

### `_persist_intent`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _persist_intent(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

实现持久化意图写入。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 冻结意图。 |

返回：主线程完成源，成功必须表示持久化完成。

<a id="member-gfstoragesyncjournal-methods-_persist_outcome"></a>

### `_persist_outcome`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _persist_outcome(_request: GFStorageSyncRequest, _outcome: Dictionary) -> GFAsyncCompletion:
```

实现已查证结果的幂等持久化。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 原意图。 |
| `_outcome` | 已校验结果。 |

返回：主线程完成源。

结构：

- `_outcome`: Closed transport result described by persist_outcome().

<a id="member-gfstoragesyncjournal-methods-_load_intent"></a>

### `_load_intent`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _load_intent(_record_namespace: String, _record_key: String) -> GFAsyncCompletion:
```

实现未解决意图读取。

参数：

| 名称 | 说明 |
|---|---|
| `_record_namespace` | 稳定命名空间。 |
| `_record_key` | 稳定记录键。 |

返回：主线程完成源，成功值遵守 load_intent() 契约。
