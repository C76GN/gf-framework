# 有界请求与回复关联

`GFNetworkRequestTracker` 管理发往指定 peer 的本地等待项：分配请求 ID，在收到匹配回复、超时、取消或会话结束时结算 `GFNetworkRequestHandle`。它独立于 `GFNetworkUtility`，不会自动连接网络信号、编码消息或启动计时器。项目 Adapter 决定协议字段和回复类型，再把真实传输 peer、原样回显的请求 ID 与响应数据交给 Tracker。

## 请求与结果

创建 Tracker 时可注入 `GFClock`，并设置等待容量；默认使用 `GFClock`，容量为 64。先调用 `begin_session()`，再调用 `request(peer_id, send, timeout_msec)`。`send` 是同步 Callable，接收一个不透明的 `String` 请求 ID，返回 Godot `Error`。Tracker 先登记等待项再调用它，因此本地回环或同步 Adapter 可以在发送返回前调用 `receive_reply()`。

发送函数必须快速返回，不能在其中 `await`、等待回复或执行长时间阻塞操作。Tracker 的超时检查不能抢占正在执行的发送函数。

主线程中的 `request()` 返回 Handle，准入拒绝也通过已完成的 Handle 表达。非主线程调用不被支持，`request()` 会返回 `null`。Handle 提供 `completed(result)`、`is_completed()`、`is_pending()`、`get_result()`、`cancel()`、`get_request_id()` 和 `get_peer_id()`。同步回复或立即拒绝可能在 `request()` 返回前完成，因此主线程中等待时先检查状态：

```gdscript
var handle: GFNetworkRequestHandle = tracker.request(peer_id, send_request)
if not handle.is_completed():
	var _completed_result: GFNetworkRequestResult = await handle.completed
var result: GFNetworkRequestResult = handle.get_result()
if result.is_successful():
	var response: Variant = result.get_response()
	print(response)
else:
	print(result.get_status(), ": ", result.get_send_error())
```

`GFNetworkRequestResult` 保存一次请求的只读终态。它的 `is_successful()` 只表示收到了合法的匹配回复，不能代表远端业务操作成功。业务拒绝码仍在项目响应中解释。`get_response()` 返回隔离的深拷贝；不要通过修改返回值改变已完成结果。`get_send_error()` 包含发送失败或准入拒绝的 Godot 错误码，不承载项目业务错误码。

## 接入项目网络生命周期

下面的项目脚本可挂到一个 Node 上。节点入树后调用一次 `setup(network)`，并让节点持续处理帧；网络 Utility 仍由原有架构驱动。`status_request`、`status_reply`、`request_id` 和 `response` 都是示例项目协议，需要远端实现相同约定，GF 不保留这些字段名。

```gdscript
class_name ProjectRequestBridge
extends Node


var _network: GFNetworkUtility = null
var _session: GFNetworkSession = null
var _tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()


func _process(_delta: float) -> void:
	_tracker.tick()


func _exit_tree() -> void:
	if _session != null:
		if _session.session_started.is_connected(_on_session_started):
			_session.session_started.disconnect(_on_session_started)
		if _session.session_closed.is_connected(_on_session_closed):
			_session.session_closed.disconnect(_on_session_closed)
	if _network != null:
		if _network.peer_disconnected.is_connected(_on_peer_disconnected):
			_network.peer_disconnected.disconnect(_on_peer_disconnected)
		if _network.message_received.is_connected(_on_message_received):
			_network.message_received.disconnect(_on_message_received)
	_network = null
	_session = null
	_tracker.dispose()


func setup(network: GFNetworkUtility) -> Error:
	if not is_inside_tree() or _network != null:
		return ERR_ALREADY_IN_USE
	if network == null or network.session == null:
		return ERR_UNCONFIGURED
	_network = network
	_session = network.session
	var _started_error: int = _session.session_started.connect(_on_session_started)
	var _closed_error: int = _session.session_closed.connect(_on_session_closed)
	var _peer_error: int = _network.peer_disconnected.connect(_on_peer_disconnected)
	var _message_error: int = _network.message_received.connect(_on_message_received)
	if _session.is_active:
		return _tracker.begin_session()
	return OK


func request_status(peer_id: int) -> GFNetworkRequestHandle:
	var send_request: Callable = func(request_id: String) -> Error:
		if _network == null:
			return ERR_UNCONFIGURED
		var message: GFNetworkMessage = GFNetworkMessage.new(&"status_request", {
			"request_id": request_id,
		})
		return _network.send_message(peer_id, message)
	return _tracker.request(peer_id, send_request, 10_000)


func _on_session_started(_mode: int, _endpoint: String) -> void:
	var error: Error = _tracker.begin_session()
	if error != OK:
		push_error("Request session could not start: %s" % error_string(error))


func _on_session_closed(_reason: String) -> void:
	_tracker.end_session()


func _on_peer_disconnected(peer_id: int) -> void:
	_tracker.disconnect_peer(peer_id)


func _on_message_received(peer_id: int, message: GFNetworkMessage) -> void:
	if message.message_type != &"status_reply":
		return
	var request_id_value: Variant = message.payload.get("request_id")
	if not request_id_value is String:
		return
	var request_id: String = request_id_value
	var _accepted: bool = _tracker.receive_reply(
		peer_id,
		request_id,
		message.payload.get("response")
	)
```

监听的是 `GFNetworkSession.session_closed`，不能只监听 `GFNetworkUtility.disconnected`。替换或清空 backend 也会关闭旧 Session，这时必须结束旧等待项；重新开始会话后，旧请求 ID 不能匹配新请求。单个 peer 离开时，`disconnect_peer()` 只结算该 peer 的等待项。

`begin_session()` 会先结算旧等待项，再开启新会话。旧请求的完成监听者若在此期间调用 `end_session()` 或 `dispose()`，此次开启返回 `ERR_UNAVAILABLE` 并保持关闭；不会在监听者返回后重新打开。`end_session()` 只中止此次开启，之后可以显式再次开启；`dispose()` 则不可逆。

示例节点离树时精准解绑自己的连接，再调用不可逆的 `dispose()`；不要把同一个 Tracker 用于节点重新入树后的新生命周期。需要重新绑定另一个 Network Utility 时，销毁旧桥接节点并创建新的节点。项目若替换 `network.session` 对象，也须重新建立接线。Tracker 的全部状态入口都必须在 Godot 主线程调用；工作线程中的 Adapter 应先把结果转交主线程，不能仅依靠同一工作线程内串行执行。

接收路径使用 `message_received` 提供的 `peer_id`，不要用 payload 自报身份替代。项目仍需配置[消息契约与入站校验](../network-contracts.md)，并在服务端验证权限。Tracker 的关联检查不能替代这些规则。

## 容量、时间与响应预算

| 边界 | 行为 |
|---|---|
| 等待容量 | 构造参数 `max_pending` 为 1–4096，默认 64；满额请求立即拒绝，不调用发送函数。 |
| 单请求超时 | `timeout_msec` 为 1–86,400,000 毫秒，默认 10,000 毫秒。 |
| 截止时刻 | 回复、取消、发送返回及 `tick()` 执行时，当前时间达到或超过 deadline 则优先以 `timed_out` 结算。回复校验与隔离副本准备均计入等待时间，副本准备完成后再次检查截止时刻，通过后才提交 `received`。关闭会话和 `dispose()` 使用各自显式生命周期事件的终态。 |
| 响应预算 | 最大深度 16、节点数 4096、保守估算的传输值字节预算 65,536；Object、循环引用、非有限数及超限响应被拒绝，匹配的请求以 `invalid_response` 结算。类型化容器的类型元数据也会检查，声明对象类型的容器即使为空也被拒绝。 |

定期调用 `tick()` 扫描到期等待项。不调用它会延迟无回复请求的超时通知，因此应放在持续运行的节点或项目 System 中；它不是后台线程或硬实时计时器。时钟引用在构造时固定，不会因构造而推进或修改时钟；测试可注入 `GFManualClock`，不需要实际等待十秒来验证超时。

上述字节预算是对传输值的保守估算，不是某种 serializer 输出包大小的精确计数。它约束 Tracker 保存的纯值快照，不代替 transport 的包体限制、解码预算或项目字段校验。`get_pending_count()` 可用于观察当前等待量，`get_debug_snapshot()` 用于诊断，不应据此绕过请求入口的容量检查。

## 关联与取消边界

请求 ID 必须当作不透明字符串原样传输和回显，不得截断、转为数字、自行复用或依赖内部格式。重复回复、旧会话 ID、已结束请求以及错误 peer 都不能再次完成等待项。

`cancel()` 只取消本地等待；它不会发送远端取消消息，也不撤回服务器已经执行的操作。会话结束、peer 断开和 Tracker 释放同样不能证明远端业务已停止。需要取消协议、幂等键、自动重试、重连补偿或业务错误映射时，由项目 Adapter 明确实现。

普通 HTTP 请求继续使用标准库 `GFHttpRequestBuilder` 或 `GFHttpClientUtility`；这里处理的是项目多人传输协议中的请求与回复关联。
