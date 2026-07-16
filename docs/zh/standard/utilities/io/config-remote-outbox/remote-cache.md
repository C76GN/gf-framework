# 远程文本与 JSON 缓存

这一页说明 `GFRemoteCacheUtility` 如何处理轻量 HTTP 拉取、本地 TTL 缓存、失败回退和队列合并。它适合公告、远程索引和轻量配置，不适合作为大文件下载器或实时 API 客户端。

## 远程文本与 JSON 缓存 (`GFRemoteCacheUtility`)

**应用场景：** 当项目需要拉取公告、轻量配置、远程索引或工具数据时，可以使用该工具统一处理 HTTP 请求、本地 TTL 缓存和失败回退。它只处理通用文本/JSON，不绑定具体业务结构。

```gdscript
var remote_cache := Gf.get_utility(GFRemoteCacheUtility) as GFRemoteCacheUtility
remote_cache.default_ttl_seconds = 3600

remote_cache.fetch_json("https://example.com/config.json", func(result: Dictionary) -> void:
	if not bool(result["success"]):
		push_warning(result["error"])
		return

	var data := result["data"] as Dictionary
	print(data)
)
```

`fetch_text()` 与 `fetch_json()` 的回调都接收统一结果字典：`success`、`url`、`content`、`data`、`from_cache`、`stale`、`response_code` 和 `error`。当强制刷新失败但本地仍有旧缓存时，结果会以 `success = true`、`from_cache = true`、`stale = true` 返回，项目层可以自行决定是否展示旧内容或提示网络状态。

缓存文件位于 `user://<cache_dir_name>/`，文件名由 URL、请求格式和 headers 组合出的缓存 key 的 MD5 派生，写入时会先提交到临时文件，再替换最终缓存文件，避免刷新中断污染旧缓存。超过 `max_cache_entries` 后按修改时间删除最旧条目。项目可以用 `has_valid_cache()` / `get_cached_text()` 只读文本缓存，用 `remove_cache()` 清理单个缓存 key，用 `clear_cache()` 清空整个缓存目录；需要语言、账号态或 AB 分组等自定义维度时，可以提供 `cache_key_builder`。自定义 builder 返回空文本时会退回默认 key，不会让不同 URL 合并到空身份。JSON 请求会先解析成功再写入缓存，避免远程服务短暂返回坏 JSON 后污染 TTL 缓存；强制刷新失败或新 JSON 解析失败但本地有可用旧缓存时，仍可返回 `stale = true` 的旧内容。

该工具串行处理内部请求队列，适合轻量公告和配置拉取，不适合作为大文件下载器或实时 API 客户端。相同缓存 key 的并发请求会合并到同一个 HTTP 请求；`max_pending_requests` 限制等待队列长度，`max_response_bytes` 同时限制 HTTP body、内存文本和本地缓存文件大小，超限响应不会写入缓存。`cancel(url, headers, format)` 可取消匹配请求，`cancel_all()` 可清空等待和当前请求。`get_debug_snapshot()` 会报告缓存目录、TTL、响应预算、队列数量和当前 active URL，便于和 `GFDiagnosticsUtility` 一起定位远程配置刷新问题。缓存写入仍使用同步 `FileAccess`，项目不应把它用于大文件下载或每帧高频刷新。
