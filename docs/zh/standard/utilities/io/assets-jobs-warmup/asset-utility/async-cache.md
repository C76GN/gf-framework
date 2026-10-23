# 异步加载与 LRU 缓存

`GFAssetUtility.load_async()` 每次返回独立的 `GFAssetLoadOperation`。请求先选择资源 scope，再等待类型化结果；缓存命中也走同一等待接口。

## 基本用法

```gdscript
var assets := Gf.get_utility(GFAssetUtility) as GFAssetUtility
var scope: GFAssetScope = assets.create_scope(self)
var operation: GFAssetLoadOperation = assets.load_async(
	"res://actors/runtime_actor.tscn", scope, "PackedScene"
)
var result: GFAssetLoadResult = await operation.wait_result_async()
if result.is_successful():
	var resource: Resource = result.get_handle().get_resource()
	if resource is PackedScene:
		add_child(resource.instantiate())
```

scope 从入队延续到成功句柄存活。Node owner 退出树时自动关闭；不绑定 owner 时，应将 scope 保存在成员或局部任务中，并在资源使用结束后调用 `scope.close()`。丢弃最后一个 scope 引用也会关闭它。Utility 仅弱跟踪 scope，不会因跟踪本身永久保留资源。

`wait_result_async()` 同时处理即时与延迟完成，无需检查状态再连接信号。每次等待观察同一个结果和同一个句柄，不增加租约或引用计数。`completed(result)` 是完成事实通知，owner 失效或 scope 关闭都不会阻止终态提交和等待唤醒。业务写回前仍应检查自己的生命周期与资源句柄资格。

`GFAssetLoadResult` 保存单次请求的终态事实。`get_status()` 返回 `SUCCEEDED`、`FAILED` 或 `CANCELLED`；`get_error_code()` 在成功时为 `OK`，取消时为 `ERR_SKIP`，失败时保留具体错误码。成功结果的 `get_handle()` 返回原 scope 持有的同一个句柄。之后关闭 scope 不会改写成功结果，但句柄会失效，因此延迟使用资源前应检查 `handle.is_valid()`。

架构模式需要共享的 `GFResourceBroker`；`ready()` 从 Architecture 解析它。独立使用时显式调用 `setup_standalone_resource_broker()` 或 `set_resource_broker()`。未配置 Broker 时请求返回失败结果；调试快照保留 `ERR_UNCONFIGURED`，不隐式创建无法与 Scene / BackgroundWork 协调的加载通道。

同一资源身份的并发请求可共用物理加载，但每次调用都有独立 operation。类型不兼容、路径无效和服务拒绝都返回终态结果，不返回悬空等待。

## 缓存与持有

LRU 只淘汰无保留资格的缓存项。成功请求的句柄会增加引用计数并 pin 资源；scope 关闭或显式释放句柄后才归还保留。`max_cache_size = 0` 禁用并清空缓存；`pin_cache(path)` 的每次 pin 需要对应一次 `unpin_cache(path)`。

关闭 scope 不销毁调用者已经保存到其他对象的 `Resource` 引用；它撤销的是 GF 管理的持有和交付资格。

## 加载通道与并发上限

Asset lane 决定工作何时提交到 Broker，Broker 统一仲裁 Asset、Scene 与 BackgroundWork 的底层 admission。

```gdscript
var scope: GFAssetScope = assets.create_scope(self)
var operation: GFAssetLoadOperation = assets.load_async(
	"res://levels/chunk_01.tscn",
	scope,
	"PackedScene",
	{"lane_id": &"chunk_streaming", "max_concurrent_loads": 1}
)
var result: GFAssetLoadResult = await operation.wait_result_async()
```

非空 lane 未声明上限时默认串行；`max_concurrent_loads = 0` 不限制并发。`default_max_concurrent_loads` 为未指定的请求提供默认值。排队发出 `asset_load_queued(path, lane_id)`，此时 `is_loading(path)` 为 true，进度为 0。

`preload_group_async()` 设置并发上限且没有显式 lane 时，以 group id 作为 lane。分组是预热与缓存策略，不能替代请求 scope。

## 进度反馈

`asset_load_progress(path, progress)` 与 `get_load_progress(path)` 反映共享加载进度：已缓存为 1，未请求或已取消为 0。该路径级诊断不能用于取消某个消费者；取消应调用该消费者的 operation。
