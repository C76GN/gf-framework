# GFStorageSyncOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/storage/gf_storage_sync_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一次同步观察的取消与唯一终态句柄。 取消只结束调用方等待，不能证明远端停止写入。已发送提交的取消、超时或释放结果 由引擎报告为未知，并通过原操作 ID 恢复；迟到响应不会改变已经交付的终态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfstoragesyncoperation-signals-completed) | `signal completed(result: GFStorageSyncResult)` |
| 方法 | [`is_completed`](#member-gfstoragesyncoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfstoragesyncoperation-methods-get_result) | `func get_result() -> GFStorageSyncResult:` |
| 方法 | [`wait_result_async`](#member-gfstoragesyncoperation-methods-wait_result_async) | `func wait_result_async() -> GFStorageSyncResult:` |
| 方法 | [`cancel_wait`](#member-gfstoragesyncoperation-methods-cancel_wait) | `func cancel_wait() -> bool:` |
| 方法 | [`is_cancel_requested`](#member-gfstoragesyncoperation-methods-is_cancel_requested) | `func is_cancel_requested() -> bool:` |

## 信号

<a id="member-gfstoragesyncoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFStorageSyncResult)
```

进入唯一终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不可变终态。 |

## 方法

<a id="member-gfstoragesyncoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查当前观察是否已经结束。

返回：已交付终态返回 true。

<a id="member-gfstoragesyncoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFStorageSyncResult:
```

获取已封存结果。

返回：终态；等待中为空。

<a id="member-gfstoragesyncoperation-methods-wait_result_async"></a>

### `wait_result_async`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func wait_result_async() -> GFStorageSyncResult:
```

等待唯一终态；已经完成时立即返回，不再次启动同步。

返回：不可变终态。

<a id="member-gfstoragesyncoperation-methods-cancel_wait"></a>

### `cancel_wait`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_wait() -> bool:
```

请求结束调用方等待；不取消远端物理提交。

返回：首次仍在等待的请求返回 true。

<a id="member-gfstoragesyncoperation-methods-is_cancel_requested"></a>

### `is_cancel_requested`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_cancel_requested() -> bool:
```

检查是否曾请求结束等待。

返回：已请求返回 true。
