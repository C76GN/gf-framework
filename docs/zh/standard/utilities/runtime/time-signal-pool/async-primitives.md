# 异步取消、等待与进度

`GFCancelToken`、`GFCancelSource`、`GFTimeoutController`、`GFAsyncCompletion`、`GFAsyncWaitUtility`、`GFAsyncChannel`、`GFAsyncProgress`、`GFAsyncFlowTools`、`GFMainThreadDispatchQueue`、`GFDeferredMutationQueue`、`GFExecutionRequirement`、`GFAsyncKeyedGate`、`GFAsyncGateLease`、`GFRequestHandlerRegistry` 和 `GFExecutionLaneDiagnostics` 提供标准层的轻量异步协作原语。它们不绑定 HTTP、不决定业务重试策略，只负责表达取消、超时、一次性终态、等待、事件通道、可节流进度、显式 flow helper、主线程应用回调、延迟状态变更、执行条件、按 key 并发仲裁、单处理器请求调用和通道诊断。

## 定位

当一个流程会跨越多帧、后台任务、下载、编辑器工具或项目自定义 SDK 回调时，项目通常需要同一套取消和终态语义。GF 把这些机制拆成几个小对象：

- `GFCancelSource` 持有取消权，可由用户操作、上游 token、节点离树或超时触发。
- `GFCancelToken` 只读暴露 `is_cancelled()`、原因、metadata 和 `cancelled` 信号。
- `GFTimeoutController` 把可复用超时计划建模为取消 token，可 `start_seconds()`、`stop()` 或 `reset()`。
- `GFAsyncCompletion` 把任意回调流程收敛到 succeeded、failed 或 cancelled 一次性终态。
- `GFAsyncWaitUtility` 以字典结果等待 Godot Signal、帧、延迟、条件或值变化，并支持超时、取消 token、保护节点和 payload 捕获。
- `GFAsyncChannel` 提供多生产者、单消费者的轻量事件通道，可写入、异步读取、关闭和导出调试快照。
- `GFAsyncProgress` 统一 0 到 1 的进度值、消息和 metadata，并可按数值变化或时间间隔节流。
- `GFAsyncFlowTools` 在这些原语之上提供 `retry_async()`、`each_async()` 和 `fold_async()`，返回普通结果字典，不引入新的 Promise 类型。
- `GFMainThreadDispatchQueue` 把后台线程、资源加载或外部回调的最终应用逻辑排回显式派发点，并提供 owner 失效跳过、取消和派发预算。
- `GFDeferredMutationQueue` 收集延迟变更，并在显式 `playback()` 点按 phase、sort key 和记录顺序稳定应用。
- `GFExecutionRequirement` 把执行前置条件归一成 all / any / none 报告，可用于任务、工具按钮、资源流程或项目自定义系统。
- `GFAsyncKeyedGate` 按调用方提供的 key 发放 `GFAsyncGateLease`，用于限制同一资源、槽位或编辑器目标的并发数量。
- `GFRequestHandlerRegistry` 表达单处理器 `invoke()` / `try_invoke()` 契约，避免把查询或命令式请求误建模成多订阅事件。
- `GFExecutionLaneDiagnostics` 记录执行通道的 queued、active、completed、failed、timeout 和 cancelled 计数，供工具、日志或支持报告消费。

## 典型流程

```gdscript
var source := GFCancelSource.new()
source.cancel_after_seconds(5.0, get_tree())
source.cancel_when_node_exits(self)

var completion := GFAsyncCompletion.new()
completion.bind_cancel_token(source.get_token())

var result := await GFAsyncWaitUtility.await_signal_payload(request.completed, {
	"timeout_seconds": 5.0,
	"cancel_token": source.get_token(),
	"guard_node": self,
})

if result.cancelled or result.timed_out:
	completion.cancel(GFVariantData.get_option_string_name(result, "reason", &"timeout"))
elif result.completed:
	completion.succeed(GFVariantData.get_option_array(result, "args"))
else:
	completion.fail("request released")
```

需要复用同一个超时控制器时，不必反复创建 source：

```gdscript
var timeout := GFTimeoutController.new()
var token := timeout.start_seconds(3.0, get_tree(), &"load_timeout", {
	"asset": asset_path,
})

var wait_result := await GFAsyncWaitUtility.wait_until(func() -> bool:
	return loader.is_ready()
, {
	"cancel_token": token,
	"guard_node": self,
})

if timeout.is_timeout():
	print("load timed out")
timeout.reset()
```

帧、延迟、条件和值变化等待使用同一套结果字典：

```gdscript
await GFAsyncWaitUtility.next_frame({ "guard_node": self })
await GFAsyncWaitUtility.delay_seconds(0.2, { "respect_time_scale": false })

var changed := await GFAsyncWaitUtility.wait_until_value_changed(func() -> int:
	return inventory.get_revision()
, { "timeout_seconds": 1.0 })
```

`GFAsyncChannel` 适合把多个回调源合并给一个消费者，不要求生产者知道消费者何时读取：

```gdscript
var channel := GFAsyncChannel.new()

download.finished.connect(func(data: PackedByteArray) -> void:
	channel.try_write({ "type": &"finished", "data": data })
)
download.failed.connect(func(error: String) -> void:
	channel.close(&"failed", { "error": error })
)

var message := await channel.read_async({
	"timeout_seconds": 5.0,
	"guard_node": self,
})
```

进度对象适合连接到 UI、日志或诊断面板：

```gdscript
var progress := GFAsyncProgress.new()
progress.min_delta = 0.05
progress.progressed.connect(func(value: float, message: String, metadata: Dictionary) -> void:
	print("%d%% %s" % [roundi(value * 100.0), message])
)

progress.update(0.25, "download")
progress.complete("ready")
```

需要把一小段流程串起来时，可以用 `GFAsyncFlowTools` 保持结果字典协议一致：

```gdscript
var retry_result := await GFAsyncFlowTools.retry_async(func() -> Dictionary:
	return await request_profile_once()
, {
	"attempts": 3,
	"delay_seconds": 0.25,
	"cancel_token": source.get_token(),
})

var import_result := await GFAsyncFlowTools.each_async(files, func(path: String) -> Dictionary:
	return import_one_file(path)
)
```

这些 helper 只负责编排调用、等待 `GFAsyncCompletion` 和归一化 `{ "ok": bool, "value": ..., "error": ... }`。具体是否幂等、失败后是否回滚、延迟是否指数退避、错误是否展示给用户，仍由调用方决定。

后台任务完成后需要回到主线程应用结果时，可以把应用回调交给派发队列，再由系统或工具的 `tick()` 显式派发：

```gdscript
var dispatch_queue := GFMainThreadDispatchQueue.new()
dispatch_queue.init()

dispatch_queue.post_owned(self, func() -> void:
	_apply_loaded_data()
, { "label": "apply_loaded_data" })

dispatch_queue.dispatch(8, 0.002)
```

队列只保证回调在调用 `dispatch()` 的位置执行；它不会自动创建线程，也不会判断回调是否应该重试、回滚或显示 UI。跨线程传入的载荷建议保持为纯数据，节点和资源修改放在派发回调中完成。

需要把一批状态变化延后到帧末、系统阶段末或编辑器 apply 阶段时，用 `GFDeferredMutationQueue` 收集变更，再在明确的 playback 点稳定执行：

```gdscript
var mutations := GFDeferredMutationQueue.new()
mutations.record(func() -> void:
	apply_health_delta(unit_id, -10)
, {
	"phase": &"damage",
	"sort_key": 20,
})
mutations.record(func() -> void:
	remove_destroyed_units()
, {
	"phase": &"cleanup",
	"sort_key": 100,
})

var damage_report := mutations.playback({ "phase": &"damage" })
var cleanup_report := mutations.playback({ "phase": &"cleanup" })
```

队列不理解变更对象是什么，也不替代 UndoRedo、事务或存档系统。它只解决“先收集、后应用、顺序可诊断”的运行时边界。

执行入口需要先判断上下文是否满足时，用 `GFExecutionRequirement` 生成可展示的条件报告：

```gdscript
var requirement := GFExecutionRequirement.new()
requirement.add_value(&"scene_ready", &"scene_ready", true)
requirement.add_presence(&"selected_resource", &"selected_resource")
requirement.add_value(&"not_locked", &"locked", true, {
	"mode": GFExecutionRequirement.MODE_NONE,
})

var report := requirement.evaluate({
	&"scene_ready": true,
	&"selected_resource": resource_id,
	&"locked": false,
})
```

条件集合只读取传入的 `context`。需要更复杂的判断时可以添加谓词，但谓词应保持无副作用，让“能不能执行”和“执行时改变什么”分开。

按 key 限制并发时，gate 只发放租约，不执行任务本身：

```gdscript
var gate := GFAsyncKeyedGate.new()

var first := gate.request_lease(&"profile-save")
var first_lease := GFVariantData.get_option_value(first, "lease") as GFAsyncGateLease

var second := gate.request_lease(&"profile-save")
if GFVariantData.get_option_bool(second, "queued"):
	print("save request queued")

# 业务保存完成后释放租约；gate 会推进同 key 的下一个等待请求。
first_lease.release(&"saved")
```

当一个流程需要“唯一 handler 返回结果”而不是广播事件时，使用请求注册表：

```gdscript
var registry := GFRequestHandlerRegistry.new()
registry.register_handler(&"settings.resolve", func(request: Dictionary) -> Dictionary:
	return {
		"theme": "dark",
		"payload": GFVariantData.get_option_value(request, "payload"),
	}
)

var resolved := registry.invoke(&"settings.resolve", { "scope": "editor" })
if GFVariantData.get_option_bool(resolved, "ok"):
	print(GFVariantData.get_option_value(resolved, "result"))
```

通道诊断可以从任何队列或批处理流程喂入，不要求这些流程使用同一个调度器：

```gdscript
var lanes := GFExecutionLaneDiagnostics.new()
lanes.record_lane_event(&"asset-load", GFExecutionLaneDiagnostics.EVENT_QUEUED)
lanes.record_lane_event(&"asset-load", GFExecutionLaneDiagnostics.EVENT_STARTED)
lanes.record_lane_event(&"asset-load", GFExecutionLaneDiagnostics.EVENT_COMPLETED)

var health := lanes.get_health_snapshot()
```

## 使用边界

这些对象是协议、状态句柄和诊断容器，不是完整任务系统。需要按 requirement 仲裁多任务时使用 `GFRuntimeTaskScheduler`；需要批量聚合 HTTP 或手动异步条目时使用 `GFAsyncBatch`；需要真正的后台线程或 ResourceLoader 加载时使用 `GFBackgroundWorkUtility` 或 `GFAssetUtility`。`GFAsyncFlowTools` 适合局部 retry/each/fold，不替代项目任务队列；`GFMainThreadDispatchQueue` 适合做最终主线程应用点，不替代后台执行器；`GFDeferredMutationQueue` 适合做确定性状态应用点，不替代命令历史或存档事务。需要观察未完成异步句柄时，可在 diagnostics 包中注册并启用 `GFAsyncTrackerUtility`。

`metadata` 始终由调用方定义。GF 会复制字典边界，但不会解释字段，也不会把取消自动变成重试、回滚或 UI 提示。
