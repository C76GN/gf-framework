# 生命周期与异步加载

`GFUIUtility` 在关闭、替换和异步加载时维护面板栈一致性。项目层可以复用这些状态信号，但不应把业务页面历史写入 UI 栈本身。

## 关闭与释放

`pop_panel()`、`clear_layer()` 和替换层入口会先把旧面板从 UI 根节点移除，再按需释放实例，因此关闭后的面板会立即脱离 `GFUILayer_*`。默认 `pop_panel()` 会释放面板；`pop_panel(layer, false)` 只移除但不释放，适合项目层自行复用实例。如果面板被外部 `queue_free()`，工具会在 `tree_exited` 后从栈中移除并恢复下层面板。

## 项目页面会话

页面节点仍存在，不代表先前的请求仍有资格更新页面。复用同一节点时，项目可为每次明确开始的业务会话创建 `GFAsyncScope`，并在关闭、替换或放弃该会话时取消。被上层面板遮挡、暂停或临时隐藏是否结束会话由项目决定；不要把每次 `visible` 变化自动解释成新会话。

下面是项目 Controller 的局部用法，不要求新增页面基类。先发布新 scope，再取消旧 scope，并在清理回调返回后复核身份，避免旧清理重入开启另一会话时被外层流程覆盖：

```gdscript
var _presentation_scope: GFAsyncScope = null


func begin_presentation() -> GFAsyncScope:
	var previous_scope: GFAsyncScope = _presentation_scope
	var next_scope: GFAsyncScope = GFAsyncScope.new()
	_presentation_scope = next_scope
	if previous_scope != null:
		var _cancelled: bool = previous_scope.cancel("presentation_replaced")
	if _presentation_scope != next_scope or not next_scope.is_active():
		return null
	return next_scope
```

调用方必须处理 `null`；每个异步请求捕获返回的 scope，并在每次 `await` 或外部回调后、写入页面前核对它仍是当前 scope 且 `is_active()`。关闭时先清空当前引用，再取消捕获的旧 scope。清理回调只释放该旧会话拥有的订阅、计时器和表现任务，不通过当前成员反查并清理新会话资源。

`register_cleanup()` 适合登记会话取消时的清理；`complete()` 表示正常完成并丢弃这些回调，不会替代取消清理。scope 取消不会回滚已经提交的业务状态，也不会自动关闭面板。Router 的 owner/scope 只约束面板提交前，完整边界见 [UI 路由与导航历史](../ui-router.md#提交前生命周期取消)。需要关闭已提交面板时，项目应显式调用 UI 栈 API。

## 异步请求保护

`push_panel_async()` 和 `replace_layer_async()` 会优先使用 `GFAssetUtility`，未注册时回退同步加载。同步 fallback 与真正异步路径共享同一 terminal 流程，都会返回 `GFUIPanelAsyncOperation`、清理 pending 请求并发出终态。每个句柄冻结同一 `GFUIUtility` 实例内全局单调且跨 `init()` / `dispose()` 不复用的 UI serial，以及 path、layer 和 `push` / `replace` operation；成功面板仅由句柄弱引用，关闭面板后不会因为观察句柄而延长节点生命周期。

每个 UI 层仍有独立的 operation intent：`pop_panel()`、`clear_layer()`、push、replace 或释放工具后，较旧回调都会被忽略，旧 replace 不会在新 push 已完成后清掉新面板。同一层级同一路径的重复异步压栈请求会在资源返回前合并并返回同一句柄，避免按钮连点时叠出多层相同面板。

完成路径先释放请求自己的资源 scope，并在释放回调后重新确认请求和面板仍有效。释放回调重入 `clear_layer()` 或 `dispose()` 时请求取消；直接释放成功面板时请求失败。随后同时移除请求表和 push 去重索引，再完成精确句柄，最后发送全局 telemetry。因此终态回调内可以安全地提交同层同路径的新请求，旧回调也不能命中新句柄；资源释放回调也不会使请求永久停留在 PENDING 或重复完成。

## 类型化终态

需要把一次请求与终态精确关联时，优先观察返回的 `GFUIPanelAsyncOperation`，不要用 path/layer 猜测某条全局 finished 信号属于哪个调用。句柄只进入一个 `AsyncPanelLoadStatus.OPENED`、`FAILED` 或 `CANCELLED` 终态；迟到资源回调不能覆盖或重复发出终态。

由于未注册 `GFAssetUtility` 时同步 fallback 可能在 async 方法返回前完成，请把必须可靠接收的回调作为最后一个 `completion_callback` 参数传入。UI 会在 started telemetry 和任何完成路径之前连接该回调；回调参数就是当前句柄，不要在回调中读取尚未完成赋值的外部局部变量：

```gdscript
func _on_settings_loaded(operation: GFUIPanelAsyncOperation) -> void:
	match operation.get_status():
		GFUIUtility.AsyncPanelLoadStatus.OPENED:
			var panel: Node = operation.get_panel()
			if panel != null:
				configure_opened_settings(panel)
		GFUIUtility.AsyncPanelLoadStatus.CANCELLED:
			handle_settings_cancelled(operation.get_serial())

var operation: GFUIPanelAsyncOperation = ui_util.push_panel_async(
	"res://ui/settings_panel.tscn",
	GFUIUtility.Layer.POPUP,
	Callable(),
	_on_settings_loaded
)
if operation == null:
	handle_request_rejected()
```

普通请求代码优先使用 `wait_result_async()`，同时处理立即完成与异步完成，省去重复连接和终态检查。
等待结果仍是同一个弱面板句柄，不延长面板生命期：

```gdscript
func observe_panel_operation(operation: GFUIPanelAsyncOperation) -> void:
	if operation == null:
		return
	var completed_operation: GFUIPanelAsyncOperation = await operation.wait_result_async()
	consume_panel_terminal_once(completed_operation)
```

## 全局加载 telemetry

异步加载的视觉 Loading 属于项目 UI。框架不创建默认遮罩、进度条或转场动画，但会保留全局信号用于汇总诊断与 Loading 计数。这些信号没有 serial，不应用作单次请求的相关性协议：

- `panel_async_load_started`：报告 `push` / `replace` 请求开始。
- `panel_async_load_finished`：报告请求结束，状态为 `AsyncPanelLoadStatus.OPENED`、`FAILED` 或 `CANCELLED`。
- `has_pending_async_panel()`：查询指定层级是否仍有等待资源回调的请求。
- `get_pending_async_panel_requests()`：返回当前 pending 请求快照，其中 `operation_handle` 保留精确类型化身份。

常见做法是只在同层没有 pending 请求时关闭项目自己的 loading 面板：

```gdscript
ui_util.panel_async_load_started.connect(func(_path: String, layer: int, _operation: StringName) -> void:
	if layer == GFUIUtility.Layer.POPUP:
		show_popup_loading()
)

ui_util.panel_async_load_finished.connect(func(
	_path: String,
	layer: int,
	_operation: StringName,
	_status: int,
	_panel: Node
) -> void:
	if layer == GFUIUtility.Layer.POPUP and not ui_util.has_pending_async_panel(layer):
		hide_popup_loading()
)
```

`panel_opened`、`panel_closed` 和 `navigation_changed` 适合把 UI 栈变化同步给焦点系统、音效、诊断面板或项目自己的路由层。`get_panel_stack()`、`get_stack_count()`、`is_panel_open()` 和 `get_debug_snapshot()` 只返回当前栈状态，不保存业务历史；route id 到面板场景的通用映射见 [UI 路由与导航历史](../ui-router.md)。
