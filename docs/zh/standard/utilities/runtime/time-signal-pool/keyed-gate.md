# 按 Key 的异步租约门禁

`GFAsyncKeyedGate` 按调用方提供的稳定 key 发放 `GFAsyncGateLease`。它只仲裁是否允许执行，不创建线程、不运行任务，也不解释 key 的业务含义；账号、存档、模态 UI、回放或编辑器事务可以共享同一套并发边界。

## 等待模式

需要排队时使用 `request_lease()`，或用 `wait_for_lease_async()` 直接等待终态：

```gdscript
var gate: GFAsyncKeyedGate = GFAsyncKeyedGate.new()
var first: Dictionary = gate.request_lease(&"profile-save")
var first_value: Variant = GFVariantData.get_option_value(first, "lease")
if not (first_value is GFAsyncGateLease):
	return
var first_lease: GFAsyncGateLease = first_value

var second: Dictionary = gate.request_lease(&"profile-save")
if GFVariantData.get_option_bool(second, "queued"):
	print("save request queued")

# 业务保存完成后释放租约；gate 会推进同 key 的下一个 waiter。
first_lease.release(&"saved")
```

Gate 同时限制全局 active lease、等待总量、单 key 等待量和 tracked key 基数；各容量、每 key 并发与单次推进工作量都钳制到公开绝对上限。全局槽位耗尽时，新请求进入有界链式 FIFO；释放后按稳定 key slot 游标轮转。每个 slot（包括空 slot）以及被处理的取消、超时请求都会消耗 `max_pump_work_items`，一整轮无进展即停止，避免无界同步扫描或主循环 livelock。

## Fail-fast 模式

调用方必须在繁忙时立即返回时使用 `try_request_lease()`：

```gdscript
var attempt: Dictionary = gate.try_request_lease(&"profile-save")
if GFVariantData.get_option_string_name(attempt, "status") == GFAsyncKeyedGate.STATUS_BUSY:
	return

var lease_value: Variant = GFVariantData.get_option_value(attempt, "lease")
if lease_value is GFAsyncGateLease:
	var lease: GFAsyncGateLease = lease_value
	# 完成本次工作后调用 lease.release()。
```

fail-fast 请求只有在当前主线程调用点能够立即提交，并且不会越过既有 waiter、公平推进周期或 acquire/release 通知边界时才取得租约。`STATUS_BUSY` 不分配请求 ID 或 `GFAsyncCompletion`，不进入队列、不发请求生命周期信号，也不改变公平游标；`get_debug_snapshot().busy_count` 只累计这种即时未取得次数。

返回状态是闭合契约：

- `STATUS_ACQUIRED`：请求已提交，返回正数 request ID、`GFAsyncGateLease` 和已经成功完成的 `GFAsyncCompletion`。
- `STATUS_BUSY`：容量、同 key waiter 或未完成的公平/通知边界阻止即时提交；request ID 为 `0`，且没有 lease 或 completion。
- `STATUS_CANCELLED`：gate 原本可以即时提交，但 `cancel_token` 在租约提交前胜出；该请求按真实取消终态记录，且没有 lease 或 completion。
- `STATUS_INVALID`：调用线程、key 或取消订阅无效；不进入等待队列，也没有 lease 或 completion。

其它 key 上仅因自身 per-key 上限而暂时不可执行的 waiter，不会占用空闲全局槽位；但只要 gate 已经启动旧 waiter 的有界公平推进周期，新 fail-fast 请求就返回 busy，不能在 continuation 之前窃取槽位。所有 fail-fast 返回都满足 `queued=false`。

## 取消、超时与通知

`request_lease()` 不执行全队列过期扫描。调用方应在帧循环或明确边界调用 `expire_waiting_requests()` / `expire_active_leases()`；两种扫描都使用持久 slot 游标，并受 `max_pump_work_items` 限制。`clear()` 会先事务式摘除调用开始时已有的等待项和 lease，再执行通知和有界推进。

同一个 `GFCancellationToken` 在 Gate 内只建立一份 signal 订阅并维护 request-id 集合。主线程取消会先摘除该 token 的全部等待项，再发 completion 与 Gate signal；worker 取消在投递到主线程时线性化，权威 lease 提交前还会再次确认 token 状态。

Gate 同时校验 lease ID 与对象身份。acquire、release、cancel 和 timeout 共用可嵌套通知边界：权威状态和诊断事件先提交，通知中的释放延迟到最外层结束。释放前已有的 waiter 保持优先级，通知中新请求不能窃取刚释放的槽位；终态 lease 会断开 owning gate callback。

## 使用边界

降低容量不会撤销既有 lease 或驱逐 waiter，只会阻止继续接纳或激活，直到状态回落到新上限内。Gate 不负责业务回滚、重试或任务取消；调用方必须把 lease 释放放进自身成功、失败和取消的共同终态路径。
