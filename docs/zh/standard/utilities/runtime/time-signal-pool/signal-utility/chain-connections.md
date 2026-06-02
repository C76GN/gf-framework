# 链式连接

```gdscript
var signals := Gf.get_utility(GFSignalUtility) as GFSignalUtility

signals.connect_signal(
	button.pressed,
	func(panel_id: String) -> void:
		_open_panel(panel_id),
	self,
	["inventory"]
).once()

signals.connect_signal(slider.value_changed, func(value: float) -> void:
	_update_volume(value)
, self).filter(func(value: float) -> bool:
	return value >= 0.0
).debounce(0.05)

# 节点或对象销毁前也可以按 owner 一次性断开
signals.disconnect_owner(self)
```

`filter()`、`map()`、`delay()`、`debounce()`、`throttle()`、`skip()`、`take()`、`scan()` 会按链式顺序执行。

`delay()` 会保留每一次通过前置步骤的触发，并在等待后继续传递；`debounce()` 才会在静默期内丢弃旧触发，只让最后一次继续。

`first()` 是 `take(1)` 的语义糖，`start_with(value)` 可立即向链路注入一次初始值。

`connect_any()` 可把多个 Signal 接到同一个回调，返回的连接列表可交给 `disconnect_connections()` 批量断开。

`connect_once()` 或 `once()` 会在首次成功触发后自动断开并从工具追踪中移除。

`connect_signal()` 返回的链式对象类型是 `GFSignalConnection`，通常不需要手动保存。只有需要主动 `disconnect_signal()`、延迟追加操作或查询连接状态时才保留引用。

## 生命周期与限制

连接会用弱引用追踪 owner。`prune_invalid_connections()` 会清理 owner、信号源或回调目标已经失效的连接。

当前连接包装器、异步等待 payload 捕获、`GFSignalBridgeBinding` 和运行时信号探针最多收集 16 个信号参数。超过这个数量的极少数自定义信号应直接使用 Godot 原生连接，或自行封装 payload。

`delay()` / `debounce()` 使用 SceneTree 计时器或帧等待做信号层等待。`throttle()` 使用系统毫秒时间做信号层节流，适合 UI、编辑器工具和轻量运行时事件。这些链式操作不是 `GFTimerUtility` 的替代品，也不会表达 GF 逻辑时间组的暂停语义。
