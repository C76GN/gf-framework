# HTTP 请求、客户端池与异步批处理

GF 提供请求构建、响应句柄、有界 `HTTPRequest` 客户端池和批处理聚合，但不内置具体远端服务、鉴权、重试、分页或业务 DTO。

## 一次性请求

低频、彼此独立的请求可以直接由 `GFHttpRequestBuilder` 创建临时 `HTTPRequest`：

```gdscript
var builder := GFHttpRequestBuilder.new()
builder.set_url("https://example.com/config")
builder.add_query_parameter("locale", "zh-CN")
builder.set_header("Accept", "application/json")
builder.set_parse_mode(GFHttpRequestBuilder.ParseMode.JSON)
builder.set_max_response_bytes(4 * 1024 * 1024)

var response := builder.execute(get_tree().root)
response.completed.connect(func(result: GFHttpResponse) -> void:
	if not result.is_successful():
		push_warning(result.error)
		return
	print(result.data)
)
```

## 有界客户端池

并发 API、配置刷新或 SDK adapter 不应为每次调用长期创建节点。`GFHttpClientUtility` 复用 `HTTPRequest` worker，并分别限制活动数和等待队列；它属于 `gf.standard.assets` package。

在 Installer 中先配置再注册，架构会在后续生命周期激活它：

```gdscript
func install(architecture: GFArchitecture, scope: GFAsyncScope) -> void:
	var http := GFHttpClientUtility.new()
	http.configure(4, 128)
	if not await architecture.register_utility_instance(http):
		architecture.fail_initialization("GFHttpClientUtility 注册失败。")
		return
	if scope.is_cancel_requested():
		return
```

```gdscript
var http := Gf.get_utility(GFHttpClientUtility, true) as GFHttpClientUtility
if http == null:
	return

var response := http.execute(builder)
response.completed.connect(_on_request_completed)
# response.cancel("screen_closed")
```

客户端会在 `execute()` 时复制 builder 状态，调用方后续修改不会改变已排队请求。活动请求达到上限后进入有界队列；队列满时响应立即以 `queue_full` 失败。Builder 的响应预算 0 表示继承执行传输：一次性 `builder.execute()` 保留 Godot `HTTPRequest` 的无限制默认值，客户端池则默认收敛为 16 MiB；正数设置请求级上限，`UNLIMITED_MAX_RESPONSE_BYTES` 显式关闭限制。超限响应以 `response_body_too_large` 失败，并保留 Godot 原始 `result_code`。`cancel_all()` 保留 worker，`dispose()` 以 `client_disposed` 取消所有请求并释放节点。显式 `request_parent` 退出树时，活动响应以 `request_worker_lost` 终结，不会永久 pending；后续请求不会静默迁移到 `SceneTree.root`。

`get_debug_snapshot()` 提供活动、排队、空闲 worker 和总 worker 数，适合调试面板或运行时诊断。业务重试必须根据幂等性、状态码、退避和取消边界由项目策略实现，不能由通用池自动重放。

## 响应与批处理

`GFHttpResponse` 统一表达 pending、completed、failed 和 cancelled，并保留状态码、headers、文本、原始 bytes、解析数据、错误和 metadata。`get_header()` / `get_header_values()` 按大小写不敏感匹配；`get_headers_dictionary()` 保留重复响应头顺序。

`GFAsyncBatch` 可以聚合多个 `GFHttpResponse`、`GFAsyncCompletion` 或手动条目。它支持 `ALL`、`ANY` 和 `EACH`；新代码优先监听 `settled(report)` 或读取 `get_report()`，以区分成功、失败、取消、超时和完成顺序。`bind_cancel_token()` 绑定外部取消，`set_timeout()` 设置批处理自己的超时。
