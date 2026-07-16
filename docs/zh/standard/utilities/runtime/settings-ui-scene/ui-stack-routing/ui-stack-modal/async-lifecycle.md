# 生命周期与异步加载

`GFUIUtility` 在关闭、替换和异步加载时维护面板栈一致性。项目层可以复用这些状态信号，但不应把业务页面历史写入 UI 栈本身。

## 关闭与释放

`pop_panel()`、`clear_layer()` 和替换层入口会先把旧面板从 UI 根节点移除，再按需释放实例，因此关闭后的面板会立即脱离 `GFUILayer_*`。默认 `pop_panel()` 会释放面板；`pop_panel(layer, false)` 只移除但不释放，适合项目层自行复用实例。如果面板被外部 `queue_free()`，工具会在 `tree_exited` 后从栈中移除并恢复下层面板。

## 异步请求保护

`push_panel_async()` 和 `replace_layer_async()` 会优先使用 `GFAssetUtility`，未注册时回退同步加载。同步 fallback 与真正异步路径共享同一 terminal 流程，都会清理 pending 请求并发出 finished。每个 UI 层都有单调 operation intent：`pop_panel()`、`clear_layer()`、push、replace 或释放工具后，较旧回调都会被忽略，旧 replace 不会在新 push 已完成后清掉新面板。同一层级同一路径的重复异步压栈请求会在资源返回前合并，避免按钮连点时叠出多层相同面板。

## 加载状态信号

异步加载的视觉 Loading 属于项目 UI。框架不创建默认遮罩、进度条或转场动画，但会通过信号报告请求状态：

- `panel_async_load_started`：报告 `push` / `replace` 请求开始。
- `panel_async_load_finished`：报告请求结束，状态为 `AsyncPanelLoadStatus.OPENED`、`FAILED` 或 `CANCELLED`。
- `has_pending_async_panel()`：查询指定层级是否仍有等待资源回调的请求。
- `get_pending_async_panel_requests()`：返回当前 pending 请求快照。

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
