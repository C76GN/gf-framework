# 异步加载与 LRU 缓存

当项目需要按需加载特效、图标、UI 面板或关卡资源，并希望统一处理缓存、并发请求、取消和调试快照时，可以使用 `GFAssetUtility`。

## 基本用法

```gdscript
var assets := Gf.get_utility(GFAssetUtility) as GFAssetUtility

# 异步加载一个带路径的资源。缓存命中时直接返回，
# 如果已有相同请求，则共用同一次加载；如果没有，则发起新的 threaded request。
assets.load_async("res://actors/runtime_actor.tscn", func(res: Resource) -> void:
	var actor_scene := res as PackedScene
	if actor_scene != null:
		add_child(actor_scene.instantiate())
)
```

架构模式必须同时注册一个共享 `GFResourceBroker`；`GFAssetUtility.ready()` 会从
Architecture 解析它。独立使用时显式调用
`setup_standalone_resource_broker()`，或把项目创建的 Broker 传给
`set_resource_broker()`。未配置 Broker 的异步请求会失败关闭，不会隐式创建
无法与 Scene / BackgroundWork 协调的私有加载通道；`load_async()` 的回调会
收到 `null`，调试快照中的 `resource_broker.request_error` 为
`ERR_UNCONFIGURED`。Utility 开始 `dispose()` 后也会先关闭 admission，释放过程
中的同步回调重入不会再创建 Lease。

它内置 LRU 上限。当缓存过大时，会自动清理长期未被提取引用的资源。`max_cache_size = 0` 会禁用并清空缓存；`pin_cache(path)` 会用引用计数锁定关键资源，重复 pin 需要对应次数 `unpin_cache(path)` 后才会重新参与 LRU 淘汰。

```gdscript
assets.max_cache_size = 128
assets.load_async("res://ui/inventory_panel.tscn", _on_panel_loaded, "PackedScene")

assets.pin_cache("res://ui/common_icons.tres")
```

同一路径的并发加载会合并到同一个 threaded request。如果已存在请求或缓存的资源类型与新的 `type_hint` 明显不兼容，回调会收到 `null`。命中缓存时回调会同步执行。

## 加载通道与并发上限

GFAssetUtility 自身的 lane 控制同一资产工作流何时向 Broker 提交请求；Broker 再统一仲裁 Asset、Scene 与 BackgroundWork 的底层 admission。当项目需要控制同类资源的并发数量时，可以在 `load_async()`、`load_handle_async()` 或 `preload_group_async()` 的 options 中传入 `serial_lane_id` / `lane_id` 和 `max_concurrent_loads`。

```gdscript
assets.load_async(
	"res://levels/chunk_01.tscn",
	_on_chunk_loaded,
	"PackedScene",
	{
		"lane_id": &"chunk_streaming",
		"max_concurrent_loads": 1,
	}
)
```

非空通道没有显式上限时会按串行处理；`max_concurrent_loads = 0` 表示不限制并发。`default_max_concurrent_loads` 可为未声明上限的请求提供默认值。被通道限制挡住的请求会进入队列并发出 `asset_load_queued(path, lane_id)`，此时 `is_loading(path)` 仍返回 `true`，`get_load_progress(path)` 返回 `0.0`，直到请求真正开始。

`preload_group_async()` 如果设置了 `max_concurrent_loads` 但没有显式通道，会用 group id 作为加载通道，适合让一个预热组内部受限，同时不影响其他组或单资源请求。

## 进度反馈

需要把加载状态接到 UI 或诊断面板时，可以监听 `asset_load_progress(path, progress)`，也可以用 `get_load_progress(path)` 主动读取最近一次轮询到的进度。已缓存资源返回 `1.0`，无请求或已取消请求返回 `0.0`。

```gdscript
assets.asset_load_progress.connect(func(path: String, progress: float) -> void:
	if path == "res://ui/inventory_panel.tscn":
		loading_bar.value = progress
)

assets.load_async("res://ui/inventory_panel.tscn", _on_panel_loaded, "PackedScene")
```
