# GFStorageSyncTransport

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_transport.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`unreleased`

不依赖具体网络协议的远端版本存储接口。 适配器接收冻结请求并返回主线程完成源。写入必须在远端原子比较 revision，且以 namespace/key/operation_id 幂等地记录提交结果；同一 ID 绑定候选与预期 revision， 不得换载荷重用。mode、timeout 和 local_generation 是本地观察信息，不参与远端提交身份。 probe 查证的是历史操作结果，不能用当前记录相似或本地时钟推断已经提交。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_capabilities`](#member-gfstoragesynctransport-methods-get_capabilities) | `func get_capabilities() -> Dictionary:` |
| 方法 | [`read`](#member-gfstoragesynctransport-methods-read) | `func read(request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`conditional_write`](#member-gfstoragesynctransport-methods-conditional_write) | `func conditional_write(request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`probe`](#member-gfstoragesynctransport-methods-probe) | `func probe(request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`_get_capabilities`](#member-gfstoragesynctransport-methods-_get_capabilities) | `func _get_capabilities() -> Dictionary:` |
| 方法 | [`_read`](#member-gfstoragesynctransport-methods-_read) | `func _read(_request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`_conditional_write`](#member-gfstoragesynctransport-methods-_conditional_write) | `func _conditional_write(_request: GFStorageSyncRequest) -> GFAsyncCompletion:` |
| 方法 | [`_probe`](#member-gfstoragesynctransport-methods-_probe) | `func _probe(_request: GFStorageSyncRequest) -> GFAsyncCompletion:` |

## 方法

<a id="member-gfstoragesynctransport-methods-get_capabilities"></a>

### `get_capabilities`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_capabilities() -> Dictionary:
```

获取适配器声明的能力；非布尔声明视为不支持。

返回：隔离的能力记录。

结构：

- `return`: Closed Dictionary with read:bool,conditional_write:bool,probe:bool.

<a id="member-gfstoragesynctransport-methods-read"></a>

### `read`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func read(request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

读取请求所指定记录的单一版本。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 命名空间、键和本次观察身份。 |

返回：完成源；成功结果必须符合协议字典，失败不得冒充不存在。

结构：

- `return`: GFAsyncCompletion success result is a closed Dictionary with namespace:String,key:String,operation_id:String,status:StringName/String(read),exists:bool,revision:String,data:Dictionary. Existing records require nonempty opaque revision; missing records require empty revision/data.

<a id="member-gfstoragesynctransport-methods-conditional_write"></a>

### `conditional_write`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func conditional_write(request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

对预期 revision 执行一次条件写入。 已提交结果必须与 operation_id 的幂等记录一致。冲突必须返回实际存在状态与 revision；not_committed 只用于能够证明本次没有提交的情况。网络错误通常只能报告 unknown。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 已持久化意图所对应的精确冻结请求。 |

返回：主线程完成源；不能以取消等待冒充远端撤销。

结构：

- `return`: GFAsyncCompletion success result is a closed Dictionary with namespace,key,operation_id,status(committed/conflict/not_committed/unknown),exists:bool,revision:String,data:Dictionary. Committed requires exists=true and nonempty revision; unknown/not_committed carry exists=false,empty revision/data; conflict describes current remote record.

<a id="member-gfstoragesynctransport-methods-probe"></a>

### `probe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func probe(request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

以原 operation_id 查证一次历史提交，永不隐式重发写入。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 原持久化意图。 |

返回：主线程完成源；无法证明结果时报告 unknown。

结构：

- `return`: GFAsyncCompletion success result follows conditional_write(), but status is committed/not_committed/unknown; committed describes the historical commit, not necessarily the latest remote revision.

<a id="member-gfstoragesynctransport-methods-_get_capabilities"></a>

### `_get_capabilities`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _get_capabilities() -> Dictionary:
```

声明实际支持的协议能力。

返回：能力字典，默认不支持任何操作。

结构：

- `return`: Dictionary with read,conditional_write,probe booleans.

<a id="member-gfstoragesynctransport-methods-_read"></a>

### `_read`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _read(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

开始只读请求；实现负责冻结认证会话并在主线程完成。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 冻结输入。 |

返回：符合 read() 契约的完成源。

<a id="member-gfstoragesynctransport-methods-_conditional_write"></a>

### `_conditional_write`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _conditional_write(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

开始一次远端条件提交；不允许退化为无条件覆盖。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 精确持久化意图。 |

返回：符合 conditional_write() 契约的完成源。

<a id="member-gfstoragesynctransport-methods-_probe"></a>

### `_probe`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _probe(_request: GFStorageSyncRequest) -> GFAsyncCompletion:
```

查证原操作的持久化结果。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 原提交身份及候选。 |

返回：符合 probe() 契约的完成源。
