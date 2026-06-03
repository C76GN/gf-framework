# GFRemoteCacheUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_remote_cache_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用远程文本与 JSON 缓存工具。 提供 URL 请求、本地 TTL 缓存、失败时陈旧缓存回退和队列化 HTTP 访问。 具体内容类型、字段结构和业务策略由项目层自行决定。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`fetch_completed`](#member-gfremotecacheutility-signals-fetch_completed) | `signal fetch_completed(url: String, result: Dictionary)` |
| 信号 | [`fetch_failed`](#member-gfremotecacheutility-signals-fetch_failed) | `signal fetch_failed(url: String, result: Dictionary)` |
| 属性 | [`cache_dir_name`](#member-gfremotecacheutility-properties-cache_dir_name) | `var cache_dir_name: String = "gf_remote_cache"` |
| 属性 | [`default_ttl_seconds`](#member-gfremotecacheutility-properties-default_ttl_seconds) | `var default_ttl_seconds: int = 86400` |
| 属性 | [`timeout_seconds`](#member-gfremotecacheutility-properties-timeout_seconds) | `var timeout_seconds: float = 20.0` |
| 属性 | [`max_cache_entries`](#member-gfremotecacheutility-properties-max_cache_entries) | `var max_cache_entries: int = 128` |
| 属性 | [`max_pending_requests`](#member-gfremotecacheutility-properties-max_pending_requests) | `var max_pending_requests: int = 64` |
| 属性 | [`cache_key_builder`](#member-gfremotecacheutility-properties-cache_key_builder) | `var cache_key_builder: Callable = Callable()` |
| 方法 | [`init`](#member-gfremotecacheutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfremotecacheutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`fetch_text`](#member-gfremotecacheutility-methods-fetch_text) | `func fetch_text( url: String, callback: Callable = Callable(), ttl_seconds: int = -1, force_refresh: bool = false, headers: PackedStringArray = PackedStringArray() ) -> void:` |
| 方法 | [`fetch_json`](#member-gfremotecacheutility-methods-fetch_json) | `func fetch_json( url: String, callback: Callable = Callable(), ttl_seconds: int = -1, force_refresh: bool = false, headers: PackedStringArray = PackedStringArray() ) -> void:` |
| 方法 | [`has_valid_cache`](#member-gfremotecacheutility-methods-has_valid_cache) | `func has_valid_cache( url: String, ttl_seconds: int = -1, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> bool:` |
| 方法 | [`get_cached_text`](#member-gfremotecacheutility-methods-get_cached_text) | `func get_cached_text( url: String, ttl_seconds: int = -1, headers: PackedStringArray = PackedStringArray() ) -> String:` |
| 方法 | [`remove_cache`](#member-gfremotecacheutility-methods-remove_cache) | `func remove_cache( url: String, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> Error:` |
| 方法 | [`cancel`](#member-gfremotecacheutility-methods-cancel) | `func cancel( url: String, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> int:` |
| 方法 | [`cancel_all`](#member-gfremotecacheutility-methods-cancel_all) | `func cancel_all() -> int:` |
| 方法 | [`clear_cache`](#member-gfremotecacheutility-methods-clear_cache) | `func clear_cache() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfremotecacheutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_start_http_request`](#member-gfremotecacheutility-methods-_start_http_request) | `func _start_http_request(request_data: Dictionary) -> Error:` |
| 方法 | [`_complete_active_request`](#member-gfremotecacheutility-methods-_complete_active_request) | `func _complete_active_request( success: bool, response_code: int, content: String, error: String ) -> void:` |

## 信号

<a id="member-gfremotecacheutility-signals-fetch_completed"></a>

### `fetch_completed`

- API：`public`

```gdscript
signal fetch_completed(url: String, result: Dictionary)
```

请求成功完成时发出。成功使用陈旧缓存回退时也会发出。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 请求 URL。 |
| `result` | 请求结果字典。 |

结构：

- `result`: Dictionary，包含 success、url、content、data、from_cache、stale、response_code 和 error。

<a id="member-gfremotecacheutility-signals-fetch_failed"></a>

### `fetch_failed`

- API：`public`

```gdscript
signal fetch_failed(url: String, result: Dictionary)
```

请求失败且没有可用缓存时发出。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 请求 URL。 |
| `result` | 请求结果字典。 |

结构：

- `result`: Dictionary，包含 success、url、content、data、from_cache、stale、response_code 和 error。

## 属性

<a id="member-gfremotecacheutility-properties-cache_dir_name"></a>

### `cache_dir_name`

- API：`public`

```gdscript
var cache_dir_name: String = "gf_remote_cache"
```

user:// 下的缓存子目录名。

<a id="member-gfremotecacheutility-properties-default_ttl_seconds"></a>

### `default_ttl_seconds`

- API：`public`

```gdscript
var default_ttl_seconds: int = 86400
```

默认缓存有效期，单位秒。单次请求可覆盖。

<a id="member-gfremotecacheutility-properties-timeout_seconds"></a>

### `timeout_seconds`

- API：`public`

```gdscript
var timeout_seconds: float = 20.0
```

HTTP 请求超时时间，单位秒。

<a id="member-gfremotecacheutility-properties-max_cache_entries"></a>

### `max_cache_entries`

- API：`public`

```gdscript
var max_cache_entries: int = 128
```

最大缓存条目数，超过后会按修改时间清理最旧条目。

<a id="member-gfremotecacheutility-properties-max_pending_requests"></a>

### `max_pending_requests`

- API：`public`

```gdscript
var max_pending_requests: int = 64
```

最大等待队列长度。小于等于 0 表示不限制。

<a id="member-gfremotecacheutility-properties-cache_key_builder"></a>

### `cache_key_builder`

- API：`public`

```gdscript
var cache_key_builder: Callable = Callable()
```

自定义缓存 key 构造器。签名为 `func(url: String, headers: PackedStringArray, format: StringName) -> String`。

## 方法

<a id="member-gfremotecacheutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化远程缓存目录并启用暂停无关处理。

<a id="member-gfremotecacheutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

取消等待请求、释放 HTTPRequest 并清理运行时状态。

<a id="member-gfremotecacheutility-methods-fetch_text"></a>

### `fetch_text`

- API：`public`

```gdscript
func fetch_text( url: String, callback: Callable = Callable(), ttl_seconds: int = -1, force_refresh: bool = false, headers: PackedStringArray = PackedStringArray() ) -> void:
```

获取远程文本。callback 签名为 `func(result: Dictionary) -> void`。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `ttl_seconds` | 缓存有效期（秒）。 |
| `force_refresh` | 为 true 时忽略现有缓存并重新请求。 |
| `headers` | HTTP 请求头数组。 |

<a id="member-gfremotecacheutility-methods-fetch_json"></a>

### `fetch_json`

- API：`public`

```gdscript
func fetch_json( url: String, callback: Callable = Callable(), ttl_seconds: int = -1, force_refresh: bool = false, headers: PackedStringArray = PackedStringArray() ) -> void:
```

获取远程 JSON。成功时 result["data"] 为解析结果。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `callback` | 操作完成或事件触发时执行的回调。 |
| `ttl_seconds` | 缓存有效期（秒）。 |
| `force_refresh` | 为 true 时忽略现有缓存并重新请求。 |
| `headers` | HTTP 请求头数组。 |

<a id="member-gfremotecacheutility-methods-has_valid_cache"></a>

### `has_valid_cache`

- API：`public`

```gdscript
func has_valid_cache( url: String, ttl_seconds: int = -1, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> bool:
```

判断 URL 当前是否存在有效缓存。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `ttl_seconds` | 缓存有效期（秒）。 |
| `headers` | HTTP 请求头。 |
| `format` | 缓存格式标识。 |

返回：存在有效缓存时返回 true。

<a id="member-gfremotecacheutility-methods-get_cached_text"></a>

### `get_cached_text`

- API：`public`

```gdscript
func get_cached_text( url: String, ttl_seconds: int = -1, headers: PackedStringArray = PackedStringArray() ) -> String:
```

读取有效文本缓存；不存在或过期时返回空字符串。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `ttl_seconds` | 缓存有效期（秒）。 |
| `headers` | HTTP 请求头。 |

返回：有效缓存文本；不存在或过期时返回空字符串。

<a id="member-gfremotecacheutility-methods-remove_cache"></a>

### `remove_cache`

- API：`public`

```gdscript
func remove_cache( url: String, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> Error:
```

移除指定 URL 的缓存。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `headers` | HTTP 请求头。 |
| `format` | 缓存格式标识。 |

返回：Godot 错误码。

<a id="member-gfremotecacheutility-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel( url: String, headers: PackedStringArray = PackedStringArray(), format: StringName = &"text" ) -> int:
```

取消匹配 URL、headers 与 format 的等待或进行中请求，返回取消数量。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 远程资源 URL。 |
| `headers` | HTTP 请求头。 |
| `format` | 缓存格式标识。 |

返回：已取消的回调数量。

<a id="member-gfremotecacheutility-methods-cancel_all"></a>

### `cancel_all`

- API：`public`

```gdscript
func cancel_all() -> int:
```

取消所有等待或进行中请求，返回取消数量。

返回：已取消的回调数量。

<a id="member-gfremotecacheutility-methods-clear_cache"></a>

### `clear_cache`

- API：`public`

```gdscript
func clear_cache() -> void:
```

清空当前缓存目录。

<a id="member-gfremotecacheutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取远程缓存工具诊断快照。

返回：诊断快照字典。

结构：

- `return`: Dictionary，包含缓存设置、pending_count、active_url、active_cache_key 和 has_active_request。

<a id="member-gfremotecacheutility-methods-_start_http_request"></a>

### `_start_http_request`

- API：`protected`

```gdscript
func _start_http_request(request_data: Dictionary) -> Error:
```

启动底层 HTTP 请求。

参数：

| 名称 | 说明 |
|---|---|
| `request_data` | 请求数据。 |

返回：Godot 错误码。

结构：

- `request_data`: Dictionary，包含 url、headers、ttl_seconds、format、cache_key 和 callbacks。

<a id="member-gfremotecacheutility-methods-_complete_active_request"></a>

### `_complete_active_request`

- API：`protected`

```gdscript
func _complete_active_request( success: bool, response_code: int, content: String, error: String ) -> void:
```

完成当前活动请求，并写入缓存、回退陈旧缓存或分发失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `success` | 底层请求是否成功。 |
| `response_code` | HTTP 响应码。 |
| `content` | 响应文本内容。 |
| `error` | 失败原因。 |
