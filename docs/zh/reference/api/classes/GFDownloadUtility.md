# GFDownloadUtility

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_download_utility.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用文件下载队列。 提供顺序下载、临时文件提交、可选续传、SHA-256 校验、暂停、取消和诊断快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`download_started`](#member-gfdownloadutility-signals-download_started) | `signal download_started(task_id: int, task: GFDownloadTask)` |
| 信号 | [`download_progressed`](#member-gfdownloadutility-signals-download_progressed) | `signal download_progressed(task_id: int, received_bytes: int, total_bytes: int)` |
| 信号 | [`download_completed`](#member-gfdownloadutility-signals-download_completed) | `signal download_completed(task_id: int, result: Dictionary)` |
| 信号 | [`download_failed`](#member-gfdownloadutility-signals-download_failed) | `signal download_failed(task_id: int, result: Dictionary)` |
| 信号 | [`download_cancelled`](#member-gfdownloadutility-signals-download_cancelled) | `signal download_cancelled(task_id: int, result: Dictionary)` |
| 属性 | [`timeout_seconds`](#member-gfdownloadutility-properties-timeout_seconds) | `var timeout_seconds: float = 30.0` |
| 属性 | [`default_temp_suffix`](#member-gfdownloadutility-properties-default_temp_suffix) | `var default_temp_suffix: String = ".download"` |
| 属性 | [`default_segment_suffix`](#member-gfdownloadutility-properties-default_segment_suffix) | `var default_segment_suffix: String = ".segment"` |
| 属性 | [`overwrite_existing`](#member-gfdownloadutility-properties-overwrite_existing) | `var overwrite_existing: bool = true` |
| 属性 | [`emit_progress_interval_seconds`](#member-gfdownloadutility-properties-emit_progress_interval_seconds) | `var emit_progress_interval_seconds: float = 0.1` |
| 属性 | [`default_max_retries`](#member-gfdownloadutility-properties-default_max_retries) | `var default_max_retries: int = 0` |
| 属性 | [`default_retry_delay_seconds`](#member-gfdownloadutility-properties-default_retry_delay_seconds) | `var default_retry_delay_seconds: float = 0.0` |
| 方法 | [`init`](#member-gfdownloadutility-methods-init) | `func init() -> void:` |
| 方法 | [`dispose`](#member-gfdownloadutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`tick`](#member-gfdownloadutility-methods-tick) | `func tick(_delta: float = 0.0) -> void:` |
| 方法 | [`parse_manifest_entries`](#member-gfdownloadutility-methods-parse_manifest_entries) | `static func parse_manifest_entries(data: Variant, options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`enqueue_download`](#member-gfdownloadutility-methods-enqueue_download) | `func enqueue_download( url: String, target_path: String, callback: Callable = Callable(), options: Dictionary = {} ) -> int:` |
| 方法 | [`enqueue_manifest_entries`](#member-gfdownloadutility-methods-enqueue_manifest_entries) | `func enqueue_manifest_entries( entries: Array[Dictionary], target_root: String, callback: Callable = Callable(), options: Dictionary = {} ) -> PackedInt32Array:` |
| 方法 | [`enqueue_manifest`](#member-gfdownloadutility-methods-enqueue_manifest) | `func enqueue_manifest( data: Variant, target_root: String, callback: Callable = Callable(), options: Dictionary = {} ) -> PackedInt32Array:` |
| 方法 | [`cancel`](#member-gfdownloadutility-methods-cancel) | `func cancel(task_id: int, delete_temp: bool = false) -> bool:` |
| 方法 | [`set_paused`](#member-gfdownloadutility-methods-set_paused) | `func set_paused(value: bool) -> void:` |
| 方法 | [`pause`](#member-gfdownloadutility-methods-pause) | `func pause() -> void:` |
| 方法 | [`resume`](#member-gfdownloadutility-methods-resume) | `func resume() -> void:` |
| 方法 | [`is_paused`](#member-gfdownloadutility-methods-is_paused) | `func is_paused() -> bool:` |
| 方法 | [`clear_queue`](#member-gfdownloadutility-methods-clear_queue) | `func clear_queue(cancel_active: bool = false, delete_temp: bool = false) -> void:` |
| 方法 | [`get_active_task`](#member-gfdownloadutility-methods-get_active_task) | `func get_active_task() -> GFDownloadTask:` |
| 方法 | [`get_queued_task_ids`](#member-gfdownloadutility-methods-get_queued_task_ids) | `func get_queued_task_ids() -> PackedInt32Array:` |
| 方法 | [`get_result`](#member-gfdownloadutility-methods-get_result) | `func get_result(task_id: int) -> Dictionary:` |
| 方法 | [`get_task_snapshot`](#member-gfdownloadutility-methods-get_task_snapshot) | `func get_task_snapshot(task_id: int) -> Dictionary:` |
| 方法 | [`get_tasks_progress`](#member-gfdownloadutility-methods-get_tasks_progress) | `func get_tasks_progress(task_ids: PackedInt32Array) -> Dictionary:` |
| 方法 | [`get_debug_snapshot`](#member-gfdownloadutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_start_http_request`](#member-gfdownloadutility-methods-_start_http_request) | `func _start_http_request(request_data: Dictionary) -> Error:` |
| 方法 | [`_complete_active_download`](#member-gfdownloadutility-methods-_complete_active_download) | `func _complete_active_download( success: bool, response_code: int, error: String = "", retryable: bool = false ) -> void:` |

## 信号

<a id="member-gfdownloadutility-signals-download_started"></a>

### `download_started`

- API：`public`

```gdscript
signal download_started(task_id: int, task: GFDownloadTask)
```

下载任务开始时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 下载任务句柄。 |
| `task` | 下载任务快照。 |

<a id="member-gfdownloadutility-signals-download_progressed"></a>

### `download_progressed`

- API：`public`

```gdscript
signal download_progressed(task_id: int, received_bytes: int, total_bytes: int)
```

下载进度更新时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 下载任务句柄。 |
| `received_bytes` | 已接收字节数。 |
| `total_bytes` | 总字节数；未知时为 -1。 |

<a id="member-gfdownloadutility-signals-download_completed"></a>

### `download_completed`

- API：`public`

```gdscript
signal download_completed(task_id: int, result: Dictionary)
```

下载任务成功完成时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 下载任务句柄。 |
| `result` | 下载结果字典。 |

结构：

- `result`: Dictionary，包含任务字段、success、cancelled 和可选完成元数据。

<a id="member-gfdownloadutility-signals-download_failed"></a>

### `download_failed`

- API：`public`

```gdscript
signal download_failed(task_id: int, result: Dictionary)
```

下载任务失败时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 下载任务句柄。 |
| `result` | 下载结果字典。 |

结构：

- `result`: Dictionary，包含任务字段、success、cancelled 和错误详情。

<a id="member-gfdownloadutility-signals-download_cancelled"></a>

### `download_cancelled`

- API：`public`

```gdscript
signal download_cancelled(task_id: int, result: Dictionary)
```

下载任务被取消时发出。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 下载任务句柄。 |
| `result` | 下载结果字典。 |

结构：

- `result`: Dictionary，包含任务字段、success、cancelled 和取消详情。

## 属性

<a id="member-gfdownloadutility-properties-timeout_seconds"></a>

### `timeout_seconds`

- API：`public`

```gdscript
var timeout_seconds: float = 30.0
```

HTTP 请求超时时间，单位秒。

<a id="member-gfdownloadutility-properties-default_temp_suffix"></a>

### `default_temp_suffix`

- API：`public`

```gdscript
var default_temp_suffix: String = ".download"
```

临时文件后缀。

<a id="member-gfdownloadutility-properties-default_segment_suffix"></a>

### `default_segment_suffix`

- API：`public`

```gdscript
var default_segment_suffix: String = ".segment"
```

分段续传临时文件后缀。

<a id="member-gfdownloadutility-properties-overwrite_existing"></a>

### `overwrite_existing`

- API：`public`

```gdscript
var overwrite_existing: bool = true
```

目标文件已存在时默认是否覆盖。

<a id="member-gfdownloadutility-properties-emit_progress_interval_seconds"></a>

### `emit_progress_interval_seconds`

- API：`public`

```gdscript
var emit_progress_interval_seconds: float = 0.1
```

进度信号最小间隔，单位秒。

<a id="member-gfdownloadutility-properties-default_max_retries"></a>

### `default_max_retries`

- API：`public`

```gdscript
var default_max_retries: int = 0
```

默认最大重试次数。

<a id="member-gfdownloadutility-properties-default_retry_delay_seconds"></a>

### `default_retry_delay_seconds`

- API：`public`

```gdscript
var default_retry_delay_seconds: float = 0.0
```

默认重试等待秒数。

## 方法

<a id="member-gfdownloadutility-methods-init"></a>

### `init`

- API：`public`

```gdscript
func init() -> void:
```

初始化下载队列运行时状态并启用暂停无关处理。

<a id="member-gfdownloadutility-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

取消下载、释放 HTTPRequest 并清理运行时状态。

<a id="member-gfdownloadutility-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(_delta: float = 0.0) -> void:
```

驱动下载进度采样。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 为兼容统一 tick 签名而保留的参数。 |

<a id="member-gfdownloadutility-methods-parse_manifest_entries"></a>

### `parse_manifest_entries`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
static func parse_manifest_entries(data: Variant, options: Dictionary = {}) -> Array[Dictionary]:
```

解析下载清单为标准条目列表。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 清单数据，可为 JSON 字符串、条目数组，或包含 files、entries、downloads 字段的字典。 |
| `options` | 解析选项，支持 base_url、headers/default_headers 和 metadata。 |

返回：标准下载条目数组。

结构：

- `data`: Variant，JSON 字符串、Array[Dictionary] 或 Dictionary 清单。
- `options`: Dictionary，可包含 base_url、headers、default_headers 和 metadata。
- `return`: Array[Dictionary]，每个条目包含 url、target_path、headers、metadata 以及可选 expected_sha256、expected_size、resume、overwrite、max_retries、retry_delay_seconds。

<a id="member-gfdownloadutility-methods-enqueue_download"></a>

### `enqueue_download`

- API：`public`

```gdscript
func enqueue_download( url: String, target_path: String, callback: Callable = Callable(), options: Dictionary = {} ) -> int:
```

将下载任务加入队列。

参数：

| 名称 | 说明 |
|---|---|
| `url` | 下载 URL。 |
| `target_path` | 最终写入路径。 |
| `callback` | 完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。 |
| `options` | 可选参数，支持 headers、resume、overwrite、expected_sha256、metadata、temp_path、segment_path、max_retries、retry_delay_seconds。 |

返回：任务句柄；输入无效时返回 0。

结构：

- `options`: Dictionary，可包含 headers、resume、overwrite、expected_sha256、metadata、temp_path、segment_path、max_retries 和 retry_delay_seconds。

<a id="member-gfdownloadutility-methods-enqueue_manifest_entries"></a>

### `enqueue_manifest_entries`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func enqueue_manifest_entries( entries: Array[Dictionary], target_root: String, callback: Callable = Callable(), options: Dictionary = {} ) -> PackedInt32Array:
```

批量加入标准下载清单条目。

参数：

| 名称 | 说明 |
|---|---|
| `entries` | parse_manifest_entries() 返回的标准条目，或兼容字段的条目字典数组。 |
| `target_root` | 相对 target_path 的写入根路径。 |
| `callback` | 每个任务完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。 |
| `options` | 批量默认选项，支持 enqueue_download() 的通用选项。 |

返回：成功入队的任务句柄数组。

结构：

- `entries`: Array[Dictionary]，每个条目至少包含 url 和 target_path/path/file。
- `options`: Dictionary，可包含 headers、resume、overwrite、metadata、max_retries 和 retry_delay_seconds。

<a id="member-gfdownloadutility-methods-enqueue_manifest"></a>

### `enqueue_manifest`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func enqueue_manifest( data: Variant, target_root: String, callback: Callable = Callable(), options: Dictionary = {} ) -> PackedInt32Array:
```

解析并批量加入下载清单。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 清单数据，可为 JSON 字符串、条目数组，或包含 files、entries、downloads 字段的字典。 |
| `target_root` | 相对 target_path 的写入根路径。 |
| `callback` | 每个任务完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。 |
| `options` | 解析和入队选项，解析阶段支持 base_url、headers/default_headers、metadata，入队阶段支持 enqueue_download() 的通用选项。 |

返回：成功入队的任务句柄数组。

结构：

- `data`: Variant，JSON 字符串、Array[Dictionary] 或 Dictionary 清单。
- `options`: Dictionary，可包含 base_url、headers/default_headers、metadata、resume、overwrite、max_retries 和 retry_delay_seconds。

<a id="member-gfdownloadutility-methods-cancel"></a>

### `cancel`

- API：`public`

```gdscript
func cancel(task_id: int, delete_temp: bool = false) -> bool:
```

取消下载任务。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 任务句柄。 |
| `delete_temp` | 是否删除临时文件。 |

返回：找到并取消任务时返回 true。

<a id="member-gfdownloadutility-methods-set_paused"></a>

### `set_paused`

- API：`public`

```gdscript
func set_paused(value: bool) -> void:
```

设置下载队列暂停状态。暂停时不会启动新任务，当前任务会保留临时文件并回到队首。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 是否暂停。 |

<a id="member-gfdownloadutility-methods-pause"></a>

### `pause`

- API：`public`

```gdscript
func pause() -> void:
```

暂停下载队列。

<a id="member-gfdownloadutility-methods-resume"></a>

### `resume`

- API：`public`

```gdscript
func resume() -> void:
```

恢复下载队列。

<a id="member-gfdownloadutility-methods-is_paused"></a>

### `is_paused`

- API：`public`

```gdscript
func is_paused() -> bool:
```

检查下载队列是否暂停。

返回：暂停时返回 true。

<a id="member-gfdownloadutility-methods-clear_queue"></a>

### `clear_queue`

- API：`public`

```gdscript
func clear_queue(cancel_active: bool = false, delete_temp: bool = false) -> void:
```

清空等待队列，可选取消当前任务。

参数：

| 名称 | 说明 |
|---|---|
| `cancel_active` | 是否取消当前任务。 |
| `delete_temp` | 是否删除临时文件。 |

<a id="member-gfdownloadutility-methods-get_active_task"></a>

### `get_active_task`

- API：`public`

```gdscript
func get_active_task() -> GFDownloadTask:
```

获取当前正在下载的任务拷贝。

返回：当前任务；没有任务时返回 null。

<a id="member-gfdownloadutility-methods-get_queued_task_ids"></a>

### `get_queued_task_ids`

- API：`public`

```gdscript
func get_queued_task_ids() -> PackedInt32Array:
```

获取等待队列中的任务 ID。

返回：任务 ID 列表。

<a id="member-gfdownloadutility-methods-get_result"></a>

### `get_result`

- API：`public`

```gdscript
func get_result(task_id: int) -> Dictionary:
```

获取指定任务最近结果。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 任务句柄。 |

返回：结果字典；不存在时返回空字典。

结构：

- `return`: Dictionary，包含最新任务结果；没有结果时为空字典。

<a id="member-gfdownloadutility-methods-get_task_snapshot"></a>

### `get_task_snapshot`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_task_snapshot(task_id: int) -> Dictionary:
```

获取指定任务的当前快照或最终结果。

参数：

| 名称 | 说明 |
|---|---|
| `task_id` | 任务句柄。 |

返回：任务快照；不存在时返回空字典。

结构：

- `return`: Dictionary，运行中或等待中的任务字段，或最终结果字段。

<a id="member-gfdownloadutility-methods-get_tasks_progress"></a>

### `get_tasks_progress`

- API：`public`
- 首次版本：`5.2.0`

```gdscript
func get_tasks_progress(task_ids: PackedInt32Array) -> Dictionary:
```

聚合多个下载任务的进度。

参数：

| 名称 | 说明 |
|---|---|
| `task_ids` | 任务句柄数组。 |

返回：聚合进度字典。

结构：

- `return`: Dictionary，包含 task_count、missing_count、completed_count、failed_count、cancelled_count、running_count、queued_count、terminal_count、finished、success、received_bytes、total_bytes、known_total_bytes、unknown_total_count 和 progress_ratio。

<a id="member-gfdownloadutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取下载工具诊断快照。

返回：诊断快照字典。

结构：

- `return`: Dictionary，包含 paused、queued_count、queued_task_ids、active_task 和 result_count。

<a id="member-gfdownloadutility-methods-_start_http_request"></a>

### `_start_http_request`

- API：`protected`

```gdscript
func _start_http_request(request_data: Dictionary) -> Error:
```

启动底层 HTTP 下载请求。

参数：

| 名称 | 说明 |
|---|---|
| `request_data` | 请求数据。 |

返回：Godot 错误码。

结构：

- `request_data`: Dictionary，包含 task_id、url、headers、download_file 和 resume_offset。

<a id="member-gfdownloadutility-methods-_complete_active_download"></a>

### `_complete_active_download`

- API：`protected`

```gdscript
func _complete_active_download( success: bool, response_code: int, error: String = "", retryable: bool = false ) -> void:
```

完成当前活动下载，并根据结果提交、重试或失败任务。

参数：

| 名称 | 说明 |
|---|---|
| `success` | 底层请求是否成功取得响应体。 |
| `response_code` | HTTP 响应码。 |
| `error` | 失败原因。 |
| `retryable` | 是否允许按任务重试策略重新入队。 |
