# GFBackgroundWorkTask

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/jobs/gf_background_work_task.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

后台工作记录。 保存后台工作状态、进度、输入数据、结果、错误文本和应用回调。 任务本身不直接启动线程；执行由 GFBackgroundWorkUtility 统一协调。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Kind`](#member-gfbackgroundworktask-enums-kind) | `enum Kind` |
| 枚举 | [`Status`](#member-gfbackgroundworktask-enums-status) | `enum Status` |
| 属性 | [`work_id`](#member-gfbackgroundworktask-properties-work_id) | `var work_id: StringName = &""` |
| 属性 | [`kind`](#member-gfbackgroundworktask-properties-kind) | `var kind: Kind = Kind.CPU` |
| 属性 | [`status`](#member-gfbackgroundworktask-properties-status) | `var status: Status = Status.QUEUED` |
| 属性 | [`priority`](#member-gfbackgroundworktask-properties-priority) | `var priority: int = 0` |
| 属性 | [`input_data`](#member-gfbackgroundworktask-properties-input_data) | `var input_data: Variant = null` |
| 属性 | [`result`](#member-gfbackgroundworktask-properties-result) | `var result: Variant = null` |
| 属性 | [`apply_result`](#member-gfbackgroundworktask-properties-apply_result) | `var apply_result: Variant = null` |
| 属性 | [`error_message`](#member-gfbackgroundworktask-properties-error_message) | `var error_message: String = ""` |
| 属性 | [`progress`](#member-gfbackgroundworktask-properties-progress) | `var progress: float = 0.0` |
| 属性 | [`metadata`](#member-gfbackgroundworktask-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`resource_path`](#member-gfbackgroundworktask-properties-resource_path) | `var resource_path: String = ""` |
| 属性 | [`resource_type_hint`](#member-gfbackgroundworktask-properties-resource_type_hint) | `var resource_type_hint: String = ""` |
| 属性 | [`cancel_requested`](#member-gfbackgroundworktask-properties-cancel_requested) | `var cancel_requested: bool = false` |
| 属性 | [`created_msec`](#member-gfbackgroundworktask-properties-created_msec) | `var created_msec: int = 0` |
| 属性 | [`started_msec`](#member-gfbackgroundworktask-properties-started_msec) | `var started_msec: int = 0` |
| 属性 | [`finished_msec`](#member-gfbackgroundworktask-properties-finished_msec) | `var finished_msec: int = 0` |
| 方法 | [`is_finished`](#member-gfbackgroundworktask-methods-is_finished) | `func is_finished() -> bool:` |
| 方法 | [`get_cancellation_context`](#member-gfbackgroundworktask-methods-get_cancellation_context) | `func get_cancellation_context() -> GFBackgroundWorkContext:` |
| 方法 | [`to_dict`](#member-gfbackgroundworktask-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`kind_name`](#member-gfbackgroundworktask-methods-kind_name) | `static func kind_name(value: Kind) -> String:` |
| 方法 | [`status_name`](#member-gfbackgroundworktask-methods-status_name) | `static func status_name(value: Status) -> String:` |

## 枚举

<a id="member-gfbackgroundworktask-enums-kind"></a>

### `Kind`

- API：`public`

```gdscript
enum Kind {
	## CPU 计算型线程任务。
	CPU,
	## IO 型线程任务。
	IO,
	## ResourceLoader 线程资源加载任务。
	RESOURCE,
}
```

后台工作类型。

<a id="member-gfbackgroundworktask-enums-status"></a>

### `Status`

- API：`public`

```gdscript
enum Status {
	## 已入队，等待启动。
	QUEUED,
	## 正在后台运行或等待资源加载。
	RUNNING,
	## 正在等待主线程应用回调。
	APPLYING,
	## 已成功完成。
	COMPLETED,
	## 已失败。
	FAILED,
	## 已取消。
	CANCELLED,
}
```

后台工作生命周期状态。

## 属性

<a id="member-gfbackgroundworktask-properties-work_id"></a>

### `work_id`

- API：`public`

```gdscript
var work_id: StringName = &""
```

工作 ID。

<a id="member-gfbackgroundworktask-properties-kind"></a>

### `kind`

- API：`public`

```gdscript
var kind: Kind = Kind.CPU
```

工作类型。

<a id="member-gfbackgroundworktask-properties-status"></a>

### `status`

- API：`public`

```gdscript
var status: Status = Status.QUEUED
```

当前状态。

<a id="member-gfbackgroundworktask-properties-priority"></a>

### `priority`

- API：`public`

```gdscript
var priority: int = 0
```

优先级，数值越大越早从等待队列启动。

<a id="member-gfbackgroundworktask-properties-input_data"></a>

### `input_data`

- API：`public`

```gdscript
var input_data: Variant = null
```

工作输入数据。默认应只包含纯 Variant 数据。

结构：

- `input_data`: Variant，复制到工作线程的纯数据载荷；显式允许对象载荷时除外。

<a id="member-gfbackgroundworktask-properties-result"></a>

### `result`

- API：`public`

```gdscript
var result: Variant = null
```

工作结果。线程任务返回值或资源加载结果会写入该字段。

结构：

- `result`: Variant，工作线程结果、资源加载结果或失败载荷。

<a id="member-gfbackgroundworktask-properties-apply_result"></a>

### `apply_result`

- API：`public`

```gdscript
var apply_result: Variant = null
```

主线程应用回调的返回值。

结构：

- `apply_result`: Variant，由可选主线程 apply 回调返回。

<a id="member-gfbackgroundworktask-properties-error_message"></a>

### `error_message`

- API：`public`

```gdscript
var error_message: String = ""
```

错误文本。

<a id="member-gfbackgroundworktask-properties-progress"></a>

### `progress`

- API：`public`

```gdscript
var progress: float = 0.0
```

进度，范围建议为 0.0 到 1.0。

<a id="member-gfbackgroundworktask-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，复制到后台任务中的项目侧元数据。

<a id="member-gfbackgroundworktask-properties-resource_path"></a>

### `resource_path`

- API：`public`

```gdscript
var resource_path: String = ""
```

资源加载路径，仅 RESOURCE 任务使用。

<a id="member-gfbackgroundworktask-properties-resource_type_hint"></a>

### `resource_type_hint`

- API：`public`

```gdscript
var resource_type_hint: String = ""
```

资源类型提示，仅 RESOURCE 任务使用。

<a id="member-gfbackgroundworktask-properties-cancel_requested"></a>

### `cancel_requested`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var cancel_requested: bool = false
```

是否已请求取消。正在执行的线程任务不会被强行终止。 显式接收 GFBackgroundWorkContext 的 worker 可协作退出；其余 worker 返回后转入取消终态。

<a id="member-gfbackgroundworktask-properties-created_msec"></a>

### `created_msec`

- API：`public`

```gdscript
var created_msec: int = 0
```

创建时间。

<a id="member-gfbackgroundworktask-properties-started_msec"></a>

### `started_msec`

- API：`public`

```gdscript
var started_msec: int = 0
```

开始时间。

<a id="member-gfbackgroundworktask-properties-finished_msec"></a>

### `finished_msec`

- API：`public`

```gdscript
var finished_msec: int = 0
```

结束时间。

## 方法

<a id="member-gfbackgroundworktask-methods-is_finished"></a>

### `is_finished`

- API：`public`

```gdscript
func is_finished() -> bool:
```

当前工作是否已经进入终态。

返回：已完成、失败或取消时返回 true。

<a id="member-gfbackgroundworktask-methods-get_cancellation_context"></a>

### `get_cancellation_context`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancellation_context() -> GFBackgroundWorkContext:
```

获取框架拥有的只读协作取消上下文。

返回：已接纳 CPU/IO 工作的取消上下文；提交被拒绝或 RESOURCE 工作返回 null。

<a id="member-gfbackgroundworktask-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary。

返回：工作字典。

结构：

- `return`: Dictionary，包含 work_id、kind、kind_name、status、status_name、priority、progress、error_message、metadata、资源字段、cancel_requested、时间戳和结果标记。

<a id="member-gfbackgroundworktask-methods-kind_name"></a>

### `kind_name`

- API：`public`

```gdscript
static func kind_name(value: Kind) -> String:
```

获取工作类型名称。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 工作类型枚举值。 |

返回：工作类型名称。

<a id="member-gfbackgroundworktask-methods-status_name"></a>

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
