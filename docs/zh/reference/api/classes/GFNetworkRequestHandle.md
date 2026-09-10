# GFNetworkRequestHandle

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/runtime/gf_network_request_handle.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

网络请求关联的本地等待句柄。 句柄弱引用关联器，只允许关联器提交终态。批量清理可以先提交全部结果， 再逐个发布 completed；取消只结束本地等待，不撤销服务器操作。 状态变更和信号发布只允许在主线程执行。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfnetworkrequesthandle-signals-completed) | `signal completed(result: GFNetworkRequestResult)` |
| 方法 | [`get_request_id`](#member-gfnetworkrequesthandle-methods-get_request_id) | `func get_request_id() -> String:` |
| 方法 | [`get_peer_id`](#member-gfnetworkrequesthandle-methods-get_peer_id) | `func get_peer_id() -> int:` |
| 方法 | [`is_pending`](#member-gfnetworkrequesthandle-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfnetworkrequesthandle-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`is_successful`](#member-gfnetworkrequesthandle-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_result`](#member-gfnetworkrequesthandle-methods-get_result) | `func get_result() -> GFNetworkRequestResult:` |
| 方法 | [`cancel`](#member-gfnetworkrequesthandle-methods-cancel) | `func cancel() -> bool:` |

## 信号

<a id="member-gfnetworkrequesthandle-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFNetworkRequestResult)
```

关联器发布已提交的终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不可变的请求终态，回复通过 getter 取得隔离副本。 |

## 方法

<a id="member-gfnetworkrequesthandle-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> String:
```

获取关联请求 ID。

返回：请求 ID；尚未配置时为空。

<a id="member-gfnetworkrequesthandle-methods-get_peer_id"></a>

### `get_peer_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_peer_id() -> int:
```

获取请求绑定的目标 peer。

返回：请求的目标 peer；尚未配置时为 -1。

<a id="member-gfnetworkrequesthandle-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍在等待终态。

返回：已配置且尚未提交终态时返回 true。

<a id="member-gfnetworkrequesthandle-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查请求是否已提交终态。

返回：已提交结果时返回 true；不表示 completed 已经派发。

<a id="member-gfnetworkrequesthandle-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查请求是否收到匹配回复。

返回：已提交 received 终态时返回 true；不判断业务成功。

<a id="member-gfnetworkrequesthandle-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFNetworkRequestResult:
```

获取不可变的终态结果。

返回：已提交的同一结果对象；尚未提交时为 null。

<a id="member-gfnetworkrequesthandle-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> bool:
```

取消本地请求等待。 关联器负责截止时间优先级及 pending 移除。关联器已经不存在时提交 disposed， 不发送任何远程取消消息；已提交终态或非主线程调用不产生变化。

返回：本次调用首次终结等待时返回 true。
