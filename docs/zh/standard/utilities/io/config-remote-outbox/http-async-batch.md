# HTTP 请求构建与异步批处理

这一页说明通用 HTTP 请求字典、Godot `HTTPRequest` 执行结果和异步批处理聚合。GF 不内置远端服务、鉴权、重试、分页或业务 DTO。

## 通用 HTTP 请求构建 (`GFHttpRequestBuilder` / `GFHttpResponse` / `GFAsyncBatch`)

当项目需要轻量构建 HTTP 请求，但不希望把具体 API、鉴权、账号或服务端字段写进框架时，可以用 `GFHttpRequestBuilder` 整理 URL、query、headers、body、timeout 和响应解析策略。它既能输出普通请求字典，供项目自己的传输层使用，也能用 Godot `HTTPRequest` 直接执行：

```gdscript
var builder := GFHttpRequestBuilder.new()
builder.set_url("https://example.com/config")
builder.add_query_parameter("locale", "zh-CN")
builder.set_header("Accept", "application/json")
builder.set_parse_mode(GFHttpRequestBuilder.ParseMode.JSON)

var response := builder.execute(get_tree().root)
response.completed.connect(func(result: GFHttpResponse) -> void:
	if not result.is_successful():
		push_warning(result.error)
		return
	print(result.data)
)
```

`GFHttpResponse` 统一表达 pending、completed、failed 和 cancelled 状态，并保留状态码、headers、文本、原始 bytes、解析数据、错误和 metadata。读取响应头时优先使用 `get_header()` / `get_header_values()`，它们会按大小写不敏感方式匹配名称；需要审计或转交给自定义传输层时，可用 `get_headers_dictionary()` 生成小写 header 名到值列表的字典，重复响应头会按原始顺序保留。

`GFAsyncBatch` 可等待一组响应或手动标记的异步条目完成，适合编辑器工具、配置刷新、轻量诊断命令或项目自己的 SDK 包装层聚合结果。它支持 `CompletionPolicy.ALL`、`ANY` 和 `EACH` 三种完成策略：ALL 要求全部成功，ANY 在任一成功时完成，EACH 会等待每个条目进入终态并形成 all-settled 报告。

批处理仍会发出旧式 `completed(results)`，新代码优先监听 `settled(report)` 或调用 `get_report()`，以区分成功、失败、取消、超时、首个完成项和条目完成顺序。需要从外部统一取消时，可用 `bind_cancel_token()`；需要批处理自己超时时，可用 `set_timeout()`。

GF 不内置任何远端服务、重试策略、签名、分页或业务 DTO；这些策略应放在项目层或可选扩展中。
