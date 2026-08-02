# GFArchitectureShutdownResult

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_architecture_shutdown_result.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

架构关闭流程的不可变终态快照。 结果显式区分正常完成、失败、取消、超时、强制释放和重复释放，并以有界、 JSON-safe 的模块条目保留关闭证据。所有集合在写入和读取边界都会重新复制， 调用方不能借由返回值修改已提交终态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Status`](#member-gfarchitectureshutdownresult-enums-status) | `enum Status` |
| 方法 | [`create`](#member-gfarchitectureshutdownresult-methods-create) | `static func create( status: Status, started_at_msec: int, completed_at_msec: int, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], duplicate_request_count: int = 0, error_code: Error = OK, error: String = "", cancel_reason: String = "" ) -> GFArchitectureShutdownResult:` |
| 方法 | [`succeeded`](#member-gfarchitectureshutdownresult-methods-succeeded) | `static func succeeded( module_results: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`failed`](#member-gfarchitectureshutdownresult-methods-failed) | `static func failed( error_code: Error, error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`cancelled`](#member-gfarchitectureshutdownresult-methods-cancelled) | `static func cancelled( reason: String = "cancelled", module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`timed_out`](#member-gfarchitectureshutdownresult-methods-timed_out) | `static func timed_out( error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`forced`](#member-gfarchitectureshutdownresult-methods-forced) | `static func forced( error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`already_disposed`](#member-gfarchitectureshutdownresult-methods-already_disposed) | `static func already_disposed( started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:` |
| 方法 | [`is_successful`](#member-gfarchitectureshutdownresult-methods-is_successful) | `func is_successful() -> bool:` |
| 方法 | [`get_status`](#member-gfarchitectureshutdownresult-methods-get_status) | `func get_status() -> Status:` |
| 方法 | [`get_status_name`](#member-gfarchitectureshutdownresult-methods-get_status_name) | `func get_status_name() -> StringName:` |
| 方法 | [`get_started_at_msec`](#member-gfarchitectureshutdownresult-methods-get_started_at_msec) | `func get_started_at_msec() -> int:` |
| 方法 | [`get_completed_at_msec`](#member-gfarchitectureshutdownresult-methods-get_completed_at_msec) | `func get_completed_at_msec() -> int:` |
| 方法 | [`get_duration_msec`](#member-gfarchitectureshutdownresult-methods-get_duration_msec) | `func get_duration_msec() -> int:` |
| 方法 | [`get_module_results`](#member-gfarchitectureshutdownresult-methods-get_module_results) | `func get_module_results() -> Array[Dictionary]:` |
| 方法 | [`get_unfinished_modules`](#member-gfarchitectureshutdownresult-methods-get_unfinished_modules) | `func get_unfinished_modules() -> Array[Dictionary]:` |
| 方法 | [`get_duplicate_request_count`](#member-gfarchitectureshutdownresult-methods-get_duplicate_request_count) | `func get_duplicate_request_count() -> int:` |
| 方法 | [`get_error_code`](#member-gfarchitectureshutdownresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfarchitectureshutdownresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_cancel_reason`](#member-gfarchitectureshutdownresult-methods-get_cancel_reason) | `func get_cancel_reason() -> String:` |
| 方法 | [`duplicate_result`](#member-gfarchitectureshutdownresult-methods-duplicate_result) | `func duplicate_result() -> GFArchitectureShutdownResult:` |
| 方法 | [`to_dict`](#member-gfarchitectureshutdownresult-methods-to_dict) | `func to_dict() -> Dictionary:` |

## 枚举

<a id="member-gfarchitectureshutdownresult-enums-status"></a>

### `Status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum Status {
	## 所有关闭阶段正常完成。
	SUCCEEDED,
	## 至少一个关闭阶段失败。
	FAILED,
	## 调用方取消了关闭流程。
	CANCELLED,
	## 关闭流程超过了时间预算。
	TIMED_OUT,
	## 框架跳过未完成的静默工作并执行了强制释放。
	FORCED,
	## 架构在本次请求前已经释放。
	ALREADY_DISPOSED,
}
```

架构关闭终态。

## 方法

<a id="member-gfarchitectureshutdownresult-methods-create"></a>

### `create`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func create( status: Status, started_at_msec: int, completed_at_msec: int, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], duplicate_request_count: int = 0, error_code: Error = OK, error: String = "", cancel_reason: String = "" ) -> GFArchitectureShutdownResult:
```

创建一个规范化的架构关闭结果。 模块条目最多各保留 256 项，并且只保留 kind、script、instance_id、status、 reason 和 duration_msec 字段。字符串和非负 duration 会被限制到固定预算； instance_id 保留 Godot 返回的有符号 int 身份值。

参数：

| 名称 | 说明 |
|---|---|
| `status` | `Status` 终态。 |
| `started_at_msec` | 单调开始时间；负值归零。 |
| `completed_at_msec` | 单调完成时间；早于开始时间时收敛到开始时间。 |
| `module_results` | 已进入终态的模块关闭结果。 |
| `unfinished_modules` | 强制释放时仍未完成的模块快照。 |
| `duplicate_request_count` | 复用同一关闭流程的并发重复请求数量。 |
| `error_code` | 关闭错误码；成功终态强制归一为 OK。 |
| `error` | 稳定失败说明；最多保留 2048 个字符。 |
| `cancel_reason` | 取消原因；仅取消终态保留，最多 1024 个字符。 |

返回：新的不可变结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
- `unfinished_modules`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-succeeded"></a>

### `succeeded`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func succeeded( module_results: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建正常完成结果。

参数：

| 名称 | 说明 |
|---|---|
| `module_results` | 已完成的模块关闭结果。 |
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的成功结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-failed"></a>

### `failed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func failed( error_code: Error, error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建失败结果。

参数：

| 名称 | 说明 |
|---|---|
| `error_code` | 关闭错误码。 |
| `error` | 稳定失败说明。 |
| `module_results` | 已完成的模块关闭结果。 |
| `unfinished_modules` | 尚未完成的模块快照。 |
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的失败结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
- `unfinished_modules`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-cancelled"></a>

### `cancelled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func cancelled( reason: String = "cancelled", module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建取消结果。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因。 |
| `module_results` | 已完成的模块关闭结果。 |
| `unfinished_modules` | 尚未完成的模块快照。 |
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的取消结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
- `unfinished_modules`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-timed_out"></a>

### `timed_out`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func timed_out( error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建超时结果。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 稳定超时说明。 |
| `module_results` | 已完成的模块关闭结果。 |
| `unfinished_modules` | 超时时尚未完成的模块快照。 |
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的超时结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
- `unfinished_modules`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-forced"></a>

### `forced`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func forced( error: String, module_results: Array[Dictionary] = [], unfinished_modules: Array[Dictionary] = [], started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建强制释放结果。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 强制释放原因。 |
| `module_results` | 已完成的模块关闭结果。 |
| `unfinished_modules` | 被强制跳过的模块快照。 |
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的强制释放结果。

结构：

- `module_results`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
- `unfinished_modules`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-already_disposed"></a>

### `already_disposed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
static func already_disposed( started_at_msec: int = 0, completed_at_msec: int = 0, duplicate_request_count: int = 0 ) -> GFArchitectureShutdownResult:
```

创建已释放幂等结果。

参数：

| 名称 | 说明 |
|---|---|
| `started_at_msec` | 单调开始时间。 |
| `completed_at_msec` | 单调完成时间。 |
| `duplicate_request_count` | 并发重复请求数量。 |

返回：新的已释放结果。

<a id="member-gfarchitectureshutdownresult-methods-is_successful"></a>

### `is_successful`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_successful() -> bool:
```

检查关闭是否以正常或幂等成功结束。

返回：正常完成或此前已释放时返回 true。

<a id="member-gfarchitectureshutdownresult-methods-get_status"></a>

### `get_status`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status() -> Status:
```

获取关闭终态。

返回：`Status` 终态。

<a id="member-gfarchitectureshutdownresult-methods-get_status_name"></a>

### `get_status_name`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_status_name() -> StringName:
```

获取关闭终态名称。

返回：小写稳定状态名称。

<a id="member-gfarchitectureshutdownresult-methods-get_started_at_msec"></a>

### `get_started_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_started_at_msec() -> int:
```

获取关闭开始时间。

返回：非负单调毫秒时间。

<a id="member-gfarchitectureshutdownresult-methods-get_completed_at_msec"></a>

### `get_completed_at_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_completed_at_msec() -> int:
```

获取关闭完成时间。

返回：不早于开始时间的单调毫秒时间。

<a id="member-gfarchitectureshutdownresult-methods-get_duration_msec"></a>

### `get_duration_msec`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duration_msec() -> int:
```

获取关闭耗时。

返回：非负单调毫秒耗时。

<a id="member-gfarchitectureshutdownresult-methods-get_module_results"></a>

### `get_module_results`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_module_results() -> Array[Dictionary]:
```

获取已完成模块结果的隔离副本。

返回：最多 256 个规范化模块条目。

结构：

- `return`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-get_unfinished_modules"></a>

### `get_unfinished_modules`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_unfinished_modules() -> Array[Dictionary]:
```

获取未完成模块快照的隔离副本。

返回：最多 256 个规范化模块条目。

结构：

- `return`: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.

<a id="member-gfarchitectureshutdownresult-methods-get_duplicate_request_count"></a>

### `get_duplicate_request_count`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_duplicate_request_count() -> int:
```

获取复用同一关闭流程的重复请求数量。

返回：非负重复请求数量。

<a id="member-gfarchitectureshutdownresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

获取关闭错误码。

返回：成功终态为 OK。

<a id="member-gfarchitectureshutdownresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

获取稳定失败说明。

返回：最多 2048 个字符的失败说明。

<a id="member-gfarchitectureshutdownresult-methods-get_cancel_reason"></a>

### `get_cancel_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_cancel_reason() -> String:
```

获取取消原因。

返回：最多 1024 个字符的取消原因；非取消终态为空。

<a id="member-gfarchitectureshutdownresult-methods-duplicate_result"></a>

### `duplicate_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func duplicate_result() -> GFArchitectureShutdownResult:
```

创建隔离结果副本。

返回：新的不可变结果对象。

<a id="member-gfarchitectureshutdownresult-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_dict() -> Dictionary:
```

转换为可报告字典。

返回：关闭终态、时间、模块结果和错误证据的隔离快照。

结构：

- `return`: Dictionary with ok, status, status_name, started_at_msec, completed_at_msec, duration_msec, module_results, unfinished_modules, duplicate_request_count, error_code, error, and cancel_reason.
