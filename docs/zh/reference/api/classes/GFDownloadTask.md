# GFDownloadTask

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_download_task.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用下载任务描述。 只记录下载 URL、目标路径、校验信息和运行状态，不假设下载内容的业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfdownloadtask-enums-status) | `enum Status` |
| 属性 | [`task_id`](#member-gfdownloadtask-properties-task_id) | `var task_id: int = 0` |
| 属性 | [`url`](#member-gfdownloadtask-properties-url) | `var url: String = ""` |
| 属性 | [`target_path`](#member-gfdownloadtask-properties-target_path) | `var target_path: String = ""` |
| 属性 | [`temp_path`](#member-gfdownloadtask-properties-temp_path) | `var temp_path: String = ""` |
| 属性 | [`segment_path`](#member-gfdownloadtask-properties-segment_path) | `var segment_path: String = ""` |
| 属性 | [`headers`](#member-gfdownloadtask-properties-headers) | `var headers: PackedStringArray = PackedStringArray()` |
| 属性 | [`expected_sha256`](#member-gfdownloadtask-properties-expected_sha256) | `var expected_sha256: String = ""` |
| 属性 | [`resume`](#member-gfdownloadtask-properties-resume) | `var resume: bool = true` |
| 属性 | [`overwrite`](#member-gfdownloadtask-properties-overwrite) | `var overwrite: bool = true` |
| 属性 | [`max_retries`](#member-gfdownloadtask-properties-max_retries) | `var max_retries: int = 0` |
| 属性 | [`retry_count`](#member-gfdownloadtask-properties-retry_count) | `var retry_count: int = 0` |
| 属性 | [`retry_delay_seconds`](#member-gfdownloadtask-properties-retry_delay_seconds) | `var retry_delay_seconds: float = 0.0` |
| 属性 | [`retry_not_before_msec`](#member-gfdownloadtask-properties-retry_not_before_msec) | `var retry_not_before_msec: int = 0` |
| 属性 | [`metadata`](#member-gfdownloadtask-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`status`](#member-gfdownloadtask-properties-status) | `var status: Status = Status.QUEUED` |
| 属性 | [`received_bytes`](#member-gfdownloadtask-properties-received_bytes) | `var received_bytes: int = 0` |
| 属性 | [`total_bytes`](#member-gfdownloadtask-properties-total_bytes) | `var total_bytes: int = -1` |
| 属性 | [`response_code`](#member-gfdownloadtask-properties-response_code) | `var response_code: int = 0` |
| 属性 | [`error`](#member-gfdownloadtask-properties-error) | `var error: String = ""` |
| 方法 | [`duplicate_task`](#member-gfdownloadtask-methods-duplicate_task) | `func duplicate_task() -> GFDownloadTask:` |
| 方法 | [`to_dict`](#member-gfdownloadtask-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`get_status_name`](#member-gfdownloadtask-methods-get_status_name) | `static func get_status_name(value: Status) -> String:` |

## 枚举

<a id="member-gfdownloadtask-enums-status"></a>

### `Status`

- API：`public`

```gdscript
enum Status { ## 已加入队列。 QUEUED, ## 正在下载。 RUNNING, ## 已暂停，等待恢复。 PAUSED, ## 已完成。 COMPLETED, ## 已失败。 FAILED, ## 已取消。 CANCELLED, }
```

下载任务状态。

## 属性

<a id="member-gfdownloadtask-properties-task_id"></a>

### `task_id`

- API：`public`

```gdscript
var task_id: int = 0
```

任务句柄。

<a id="member-gfdownloadtask-properties-url"></a>

### `url`

- API：`public`

```gdscript
var url: String = ""
```

下载 URL。

<a id="member-gfdownloadtask-properties-target_path"></a>

### `target_path`

- API：`public`

```gdscript
var target_path: String = ""
```

最终写入路径。

<a id="member-gfdownloadtask-properties-temp_path"></a>

### `temp_path`

- API：`public`

```gdscript
var temp_path: String = ""
```

临时文件路径。

<a id="member-gfdownloadtask-properties-segment_path"></a>

### `segment_path`

- API：`public`

```gdscript
var segment_path: String = ""
```

分段续传文件路径。

<a id="member-gfdownloadtask-properties-headers"></a>

### `headers`

- API：`public`

```gdscript
var headers: PackedStringArray = PackedStringArray()
```

HTTP 请求头。

<a id="member-gfdownloadtask-properties-expected_sha256"></a>

### `expected_sha256`

- API：`public`

```gdscript
var expected_sha256: String = ""
```

期望 SHA-256 校验值。为空时不校验。

<a id="member-gfdownloadtask-properties-resume"></a>

### `resume`

- API：`public`

```gdscript
var resume: bool = true
```

是否允许从临时文件续传。

<a id="member-gfdownloadtask-properties-overwrite"></a>

### `overwrite`

- API：`public`

```gdscript
var overwrite: bool = true
```

目标文件已存在时是否覆盖。

<a id="member-gfdownloadtask-properties-max_retries"></a>

### `max_retries`

- API：`public`

```gdscript
var max_retries: int = 0
```

最大重试次数。

<a id="member-gfdownloadtask-properties-retry_count"></a>

### `retry_count`

- API：`public`

```gdscript
var retry_count: int = 0
```

已执行重试次数。

<a id="member-gfdownloadtask-properties-retry_delay_seconds"></a>

### `retry_delay_seconds`

- API：`public`

```gdscript
var retry_delay_seconds: float = 0.0
```

每次重试前等待的秒数。

<a id="member-gfdownloadtask-properties-retry_not_before_msec"></a>

### `retry_not_before_msec`

- API：`public`

```gdscript
var retry_not_before_msec: int = 0
```

下次可重试的时间戳，单位毫秒。

<a id="member-gfdownloadtask-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目层可附加的任务元数据。

结构：

- `metadata`: Dictionary，复制到下载任务中的项目侧元数据。

<a id="member-gfdownloadtask-properties-status"></a>

### `status`

- API：`public`

```gdscript
var status: Status = Status.QUEUED
```

当前任务状态。

<a id="member-gfdownloadtask-properties-received_bytes"></a>

### `received_bytes`

- API：`public`

```gdscript
var received_bytes: int = 0
```

已接收字节数。

<a id="member-gfdownloadtask-properties-total_bytes"></a>

### `total_bytes`

- API：`public`

```gdscript
var total_bytes: int = -1
```

总字节数；未知时为 -1。

<a id="member-gfdownloadtask-properties-response_code"></a>

### `response_code`

- API：`public`

```gdscript
var response_code: int = 0
```

最近一次 HTTP 响应码。

<a id="member-gfdownloadtask-properties-error"></a>

### `error`

- API：`public`

```gdscript
var error: String = ""
```

失败或取消原因。

## 方法

<a id="member-gfdownloadtask-methods-duplicate_task"></a>

### `duplicate_task`

- API：`public`

```gdscript
func duplicate_task() -> GFDownloadTask:
```

创建同内容拷贝。

返回：新任务。

<a id="member-gfdownloadtask-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

导出任务状态字典。

返回：任务字典。

结构：

- `return`: Dictionary，包含任务标识、路径、请求头、重试设置、metadata、状态、字节计数、响应码和错误信息。

<a id="member-gfdownloadtask-methods-get_status_name"></a>

### `get_status_name`

- API：`public`

```gdscript
static func get_status_name(value: Status) -> String:
```

获取任务状态名称。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 任务状态。 |

返回：状态名称。
