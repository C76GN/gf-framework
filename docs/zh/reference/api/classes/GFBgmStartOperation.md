# GFBgmStartOperation

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_bgm_start_operation.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

单次 BGM start request 的类型化 caller Operation。 Operation 只表达“是否已经提交播放会话”的短生命周期终态。成功返回的 `GFBgmSessionHandle` 独立表达后续播放会话生命周期；会话结束不会改写 start 结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfbgmstartoperation-signals-completed) | `signal completed(result: GFBgmStartResult)` |
| 方法 | [`get_request_id`](#member-gfbgmstartoperation-methods-get_request_id) | `func get_request_id() -> int:` |
| 方法 | [`is_pending`](#member-gfbgmstartoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_completed`](#member-gfbgmstartoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfbgmstartoperation-methods-get_result) | `func get_result() -> GFBgmStartResult:` |
| 方法 | [`cancel`](#member-gfbgmstartoperation-methods-cancel) | `func cancel() -> bool:` |

## 信号

<a id="member-gfbgmstartoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal completed(result: GFBgmStartResult)
```

start request 进入唯一 caller 终态时发出一次。 同步 validation/backend/local clip 可能在 typed start 方法返回前完成；调用方必须先查询 `is_completed()`，只在仍 pending 时连接该信号。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 当前请求的隔离终态结果。 |

## 方法

<a id="member-gfbgmstartoperation-methods-get_request_id"></a>

### `get_request_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_request_id() -> int:
```

获取 Audio Utility 分配的请求 ID。

返回：大于零的请求 ID；尚未配置时返回 0。

<a id="member-gfbgmstartoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_pending() -> bool:
```

检查请求是否仍等待 caller 终态。

返回：已配置且尚未完成时返回 true。

<a id="member-gfbgmstartoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_completed() -> bool:
```

检查请求是否已经进入 caller 终态。

返回：已有终态结果时返回 true。

<a id="member-gfbgmstartoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_result() -> GFBgmStartResult:
```

获取 caller 终态结果副本。

返回：已完成时返回隔离结果；等待中返回 null。

<a id="member-gfbgmstartoperation-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel() -> bool:
```

取消等待中的 start request。 返回 true 表示 Audio Utility 首次接受取消 intent；backend dispatch 正在进行时，终态可在 当前 dispatch 收敛后写入。已提交 Session 不受该 Operation 的后续 cancel 影响，必须通过 Session Handle 精确停止。

返回：本次调用首次取消等待请求时返回 true。
