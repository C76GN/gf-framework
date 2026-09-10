# GFNetworkRequestTracker

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/runtime/gf_network_request_tracker.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

可选的有界网络请求关联器。 主线程显式驱动会话、请求与回复，不拥有传输后端，不解释业务成功或自动重试。 send 回调同步接收必须原样回显的请求 ID；适配器识别回复后传入真实传输 peer。 使用独立单调时钟；调用方须定期 tick，并在退出时 dispose。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfnetworkrequesttracker-methods-_init) | `func _init(clock: GFClock = null, max_pending: int = 64) -> void:` |
| 方法 | [`dispose`](#member-gfnetworkrequesttracker-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`begin_session`](#member-gfnetworkrequesttracker-methods-begin_session) | `func begin_session() -> Error:` |
| 方法 | [`end_session`](#member-gfnetworkrequesttracker-methods-end_session) | `func end_session() -> void:` |
| 方法 | [`disconnect_peer`](#member-gfnetworkrequesttracker-methods-disconnect_peer) | `func disconnect_peer(peer_id: int) -> void:` |
| 方法 | [`request`](#member-gfnetworkrequesttracker-methods-request) | `func request( peer_id: int, send: Callable, timeout_msec: int = 10000 ) -> GFNetworkRequestHandle:` |
| 方法 | [`receive_reply`](#member-gfnetworkrequesttracker-methods-receive_reply) | `func receive_reply(peer_id: int, request_id: String, response: Variant = null) -> bool:` |
| 方法 | [`tick`](#member-gfnetworkrequesttracker-methods-tick) | `func tick() -> void:` |
| 方法 | [`get_pending_count`](#member-gfnetworkrequesttracker-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfnetworkrequesttracker-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfnetworkrequesttracker-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func _init(clock: GFClock = null, max_pending: int = 64) -> void:
```

创建关联器；时钟与容量在此生命周期内固定。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 同步、无副作用的单调时钟；null 使用系统 GFClock。 |
| `max_pending` | 在途上限，必须为 1 至 4096；无效配置无法开始会话。 |

<a id="member-gfnetworkrequesttracker-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

不可逆地关闭准入并终结所有在途请求，不关闭共享网络工具。

<a id="member-gfnetworkrequesttracker-methods-begin_session"></a>

### `begin_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_session() -> Error:
```

开始新会话，先以 session_closed 终结旧请求，再允许新请求。 清理通知期间不允许重入开启会话；若监听者结束会话或 dispose，本次开启也失败。

返回：成功为 OK；非主线程、已释放或开启期间被关闭为 ERR_UNAVAILABLE，清理中为 ERR_BUSY，无效配置为 ERR_INVALID_PARAMETER。

<a id="member-gfnetworkrequesttracker-methods-end_session"></a>

### `end_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func end_session() -> void:
```

结束当前会话；批量提交所有旧终态后才发通知。

<a id="member-gfnetworkrequesttracker-methods-disconnect_peer"></a>

### `disconnect_peer`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func disconnect_peer(peer_id: int) -> void:
```

终结指定 peer 的在途请求，不影响其他 peer。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 实际传输 peer，必须大于 0。 |

<a id="member-gfnetworkrequesttracker-methods-request"></a>

### `request`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func request( peer_id: int, send: Callable, timeout_msec: int = 10000 ) -> GFNetworkRequestHandle:
```

登记请求，再同步调用 send(request_id) 进行项目编码与发送。 回调只在本次调用栈内使用，返回 Godot Error。同步回复可能使返回句柄已经完成； 已提交的终态优先于回调随后返回的错误。准入失败不调用 send。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 单一目标 peer，必须大于 0，不接受广播。 |
| `send` | 同步 Callable，接收不透明 String 请求 ID 并返回 Error；不得 await。 |
| `timeout_msec` | 单调超时，1 至 86400000 毫秒，不允许无限等待。 |

返回：在途或已完成句柄；非主线程返回 null 且不发送。

<a id="member-gfnetworkrequesttracker-methods-receive_reply"></a>

### `receive_reply`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func receive_reply(peer_id: int, request_id: String, response: Variant = null) -> bool:
```

接收适配器已识别的回复，不处理普通广播、业务错误码或协议字段。 错 peer、未知或重复 ID 不改变请求。截止时刻已到则先超时。 无效回复终结为 invalid_response；不会保留部分值或截断后冒充成功。

参数：

| 名称 | 说明 |
|---|---|
| `peer_id` | 来自传输回调的真实 peer，不使用载荷自报身份。 |
| `request_id` | 协议原样回显的完整请求 ID。 |
| `response` | 需要保留的回复值，可为 null。 |

返回：本次提交 received 终态时为 true；其他情况为 false。

结构：

- `response`: Variant，传输安全纯值；拒绝 Object、Callable、Signal、RID、循环和非有限数，限制深度 16、节点 4096、估算传输字节 65536。

<a id="member-gfnetworkrequesttracker-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick() -> void:
```

按单调截止时间终结到期请求；不推进传输或时钟，不重入驱动。 本次到期集合在通知前全部提交；监听者新建的请求留待下一次 tick。

<a id="member-gfnetworkrequesttracker-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_pending_count() -> int:
```

获取尚未提交终态的请求数；到期请求在 tick 或终态入口处理。

返回：在途数量。

<a id="member-gfnetworkrequesttracker-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不包含关联 ID、业务载荷或发送回调的诊断快照。

返回：当前关联器状态。

结构：

- `return`: Dictionary，包含 active、disposed、pending_count、max_pending。
