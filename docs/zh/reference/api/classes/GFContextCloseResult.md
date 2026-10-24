# GFContextCloseResult

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_context_close_result.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`unreleased`

节点上下文一次关闭尝试的不可变结果。 closed 表示绑定和自有架构均已关闭，drained 表示全部子上下文和架构正常完成静默工作。 关闭结果不持有 Node；子结果数组在读取边界复制。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`is_closed`](#member-gfcontextcloseresult-methods-is_closed) | `func is_closed() -> bool:` |
| 方法 | [`is_drained`](#member-gfcontextcloseresult-methods-is_drained) | `func is_drained() -> bool:` |
| 方法 | [`get_error_code`](#member-gfcontextcloseresult-methods-get_error_code) | `func get_error_code() -> Error:` |
| 方法 | [`get_error`](#member-gfcontextcloseresult-methods-get_error) | `func get_error() -> String:` |
| 方法 | [`get_architecture_result`](#member-gfcontextcloseresult-methods-get_architecture_result) | `func get_architecture_result() -> GFArchitectureShutdownResult:` |
| 方法 | [`get_child_results`](#member-gfcontextcloseresult-methods-get_child_results) | `func get_child_results() -> Array[GFContextCloseResult]:` |

## 方法

<a id="member-gfcontextcloseresult-methods-is_closed"></a>

### `is_closed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_closed() -> bool:
```

检查本次尝试结束后上下文是否已关闭。

返回：已关闭时返回 true；ERR_BUSY 等拒绝可能仍未关闭。

<a id="member-gfcontextcloseresult-methods-is_drained"></a>

### `is_drained`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_drained() -> bool:
```

检查全部拥有的工作是否正常完成静默关闭。

返回：无强制释放、取消、超时或失败时返回 true。

<a id="member-gfcontextcloseresult-methods-get_error_code"></a>

### `get_error_code`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error_code() -> Error:
```

读取关闭错误码。

返回：首个子关闭或架构关闭错误；正常完成为 OK。

<a id="member-gfcontextcloseresult-methods-get_error"></a>

### `get_error`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_error() -> String:
```

读取关闭错误说明。

返回：失败说明；正常完成为空。

<a id="member-gfcontextcloseresult-methods-get_architecture_result"></a>

### `get_architecture_result`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_architecture_result() -> GFArchitectureShutdownResult:
```

读取自有架构的关闭结果。

返回：自有架构结果的副本；INHERITED 或尚未尝试架构关闭时为 null。

<a id="member-gfcontextcloseresult-methods-get_child_results"></a>

### `get_child_results`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_child_results() -> Array[GFContextCloseResult]:
```

读取直接逻辑子上下文的关闭结果。

返回：独立数组，元素为不可变关闭结果。
