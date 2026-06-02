# GFJob

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_job.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用异步/分帧任务记录。 只保存任务状态、进度、输入数据、结果和错误文本，不绑定具体业务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfjob-enums-status) | `enum Status` |
| 属性 | [`job_id`](#member-gfjob-properties-job_id) | `var job_id: StringName = &""` |
| 属性 | [`queue_name`](#member-gfjob-properties-queue_name) | `var queue_name: StringName = &"default"` |
| 属性 | [`status`](#member-gfjob-properties-status) | `var status: Status = Status.WAITING` |
| 属性 | [`data`](#member-gfjob-properties-data) | `var data: Variant = null` |
| 属性 | [`result`](#member-gfjob-properties-result) | `var result: Variant = null` |
| 属性 | [`error_message`](#member-gfjob-properties-error_message) | `var error_message: String = ""` |
| 属性 | [`progress`](#member-gfjob-properties-progress) | `var progress: float = 0.0` |
| 属性 | [`metadata`](#member-gfjob-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`created_msec`](#member-gfjob-properties-created_msec) | `var created_msec: int = 0` |
| 属性 | [`started_msec`](#member-gfjob-properties-started_msec) | `var started_msec: int = 0` |
| 属性 | [`finished_msec`](#member-gfjob-properties-finished_msec) | `var finished_msec: int = 0` |
| 方法 | [`is_finished`](#member-gfjob-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`to_dict`](#member-gfjob-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`status_name`](#member-gfjob-methods-status_name) | `static func status_name(value: Status) -> String:` |

## 枚举

<a id="member-gfjob-enums-status"></a>

### `Status`

- API：`public`

```gdscript
enum Status { ## 已入队，尚未开始执行。 WAITING, ## 正在执行。 ACTIVE, ## 已成功完成。 COMPLETED, ## 已失败。 FAILED, ## 已取消。 CANCELLED, }
```

任务生命周期状态。

## 属性

<a id="member-gfjob-properties-job_id"></a>

### `job_id`

- API：`public`

```gdscript
var job_id: StringName = &""
```

任务 ID。

<a id="member-gfjob-properties-queue_name"></a>

### `queue_name`

- API：`public`

```gdscript
var queue_name: StringName = &"default"
```

队列名。

<a id="member-gfjob-properties-status"></a>

### `status`

- API：`public`

```gdscript
var status: Status = Status.WAITING
```

当前状态。

<a id="member-gfjob-properties-data"></a>

### `data`

- API：`public`

```gdscript
var data: Variant = null
```

任务输入数据。框架不解释该字段。

结构：

- `data`: Variant，项目侧任务输入载荷。

<a id="member-gfjob-properties-result"></a>

### `result`

- API：`public`

```gdscript
var result: Variant = null
```

任务结果。框架不解释该字段。

结构：

- `result`: Variant，项目侧任务结果载荷。

<a id="member-gfjob-properties-error_message"></a>

### `error_message`

- API：`public`

```gdscript
var error_message: String = ""
```

错误文本。

<a id="member-gfjob-properties-progress"></a>

### `progress`

- API：`public`

```gdscript
var progress: float = 0.0
```

进度，范围建议为 0.0 到 1.0。

<a id="member-gfjob-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，复制到任务中的项目侧元数据。

<a id="member-gfjob-properties-created_msec"></a>

### `created_msec`

- API：`public`

```gdscript
var created_msec: int = 0
```

创建时间。

<a id="member-gfjob-properties-started_msec"></a>

### `started_msec`

- API：`public`

```gdscript
var started_msec: int = 0
```

开始时间。

<a id="member-gfjob-properties-finished_msec"></a>

### `finished_msec`

- API：`public`

```gdscript
var finished_msec: int = 0
```

结束时间。

## 方法

<a id="member-gfjob-methods-is_finished"></a>

### `is_finished`

- API：`public`

```gdscript
func is_finished() -> bool:
```

当前任务是否已经进入终态。

返回：已完成、失败或取消时返回 true。

<a id="member-gfjob-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：任务字典。

结构：

- `return`: Dictionary，包含 job_id、queue_name、status、status_name、progress、error_message、metadata、时间戳和 has_result。

<a id="member-gfjob-methods-status_name"></a>

### `status_name`

- API：`public`

```gdscript
static func status_name(value: Status) -> String:
```

获取状态名称。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 状态枚举值。 |

返回：状态名称。
