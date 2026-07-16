# 通用分析事件

这一页说明 `GFAnalyticsUtility` 的本地队列、dry-run、批量 flush 和自定义传输 hook。事件命名、字段规范、隐私策略和服务端协议由项目层负责。

## 通用分析事件 (`GFAnalyticsUtility`)

**应用场景：** 当你需要在项目内统一记录调试指标、玩家流程节点或运行时事件，并希望先在本地 dry-run，之后再按需接入 HTTP 端点时，可以使用该工具。

`GFAnalyticsUtility` 默认不会在 endpoint 为空时访问网络，`flush()` 会以 dry-run 成功完成，便于测试和本地开发保持同一套调用路径。它会为设备生成并持久化匿名 client id，同时每次运行生成新的 session id。

```gdscript
var analytics := Gf.get_utility(GFAnalyticsUtility) as GFAnalyticsUtility
analytics.config.auto_capture_context = true
analytics.config.batch_size = 20

analytics.identify("client-id")
analytics.track(&"screen_opened", {
	"screen": "inventory",
})

# endpoint_url 为空时为本地 dry-run；配置后会按 JSON 批量 POST
analytics.config.endpoint_url = "https://example.com/events"
analytics.flush()
```

如果项目需要接入自定义 SDK 或不同服务端协议，可以使用传输 hook，而不是修改工具内部：

```gdscript
analytics.payload_builder = func(batch: Array) -> Dictionary:
	return {
		"events": batch,
		"schema": "v1",
	}

analytics.transport_callback = func(payload: Dictionary) -> Dictionary:
	# 项目层自行发送 payload，也可以只写入本地调试管线。
	return { "success": true, "accepted": (payload["events"] as Array).size() }
```

配置项放在 `GFAnalyticsConfig` 中，包括 `endpoint_url`、`headers`、`batch_size`、`max_queue_size`、`flush_interval_seconds`、`app_version`、`persist_client_id`、`client_id_storage_path`、`flush_on_shutdown` 和 `compress_payload`。`compress_payload` 为 `true` 时，内置 HTTP 上报会使用 gzip 压缩 JSON 请求体并添加 `Content-Encoding: gzip`；项目自己的服务端必须支持该编码。自定义 `headers` 会过滤空 header 名和包含 CR/LF 的键值，避免把外部字符串直接拼成非法 HTTP 头；启用压缩时，自定义 `Content-Encoding` 会被忽略，以保证 header 与请求体一致。`transport_callback` 是同步 hook，必须直接返回结果字典；如需异步 SDK，应在项目层做缓冲，再把 GF 队列视为本地入口。项目层仍然负责决定事件命名、字段规范和隐私策略。

flush 失败时，本批事件会按原顺序放回队列前端，并发出 `flush_failed` / `flush_completed`；失败回灌后仍会重新执行 `max_queue_size` 限制，避免离线或接口故障时无限占用内存。正常 `track()` 超过上限时会丢弃最早事件；失败批次回灌超过上限时会优先保留刚失败的批次。关闭时的 `flush_on_shutdown` 是尽力触发，不会等待 HTTP 请求完成；关键埋点应由项目层在重要流程点主动 `flush()` 并监听结果。Gf AutoLoad 的 `_exit_tree()` 正在同步释放架构时，Analytics 关闭监听会登记延迟释放而不重入修改 `SceneTree.root`。`capture_context()` 只采集平台、Godot 版本、屏幕尺寸、语言和时区等通用信息，涉及账号、设备指纹或隐私字段的内容必须由项目层显式添加。
