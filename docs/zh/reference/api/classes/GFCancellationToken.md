# GFCancellationToken

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_cancellation_token.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

表示异步流程是否已被请求取消的只读令牌。 长时间运行的安装器、后台任务或分帧流程应在 await 或外部回调之间检查该令牌， 并在收到取消请求后停止继续写回已失效的生命周期。取消只能由拥有者对象触发， 调用方通过 token 读取原因、元数据和取消时间。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`cancel_requested`](#member-gfcancellationtoken-signals-cancel_requested) | `signal cancel_requested(reason: StringName)` |
| 方法 | [`is_cancel_requested`](#member-gfcancellationtoken-methods-is_cancel_requested) | `func is_cancel_requested() -> bool:` |
| 方法 | [`get_cancel_reason`](#member-gfcancellationtoken-methods-get_cancel_reason) | `func get_cancel_reason() -> StringName:` |
| 方法 | [`get_cancel_metadata`](#member-gfcancellationtoken-methods-get_cancel_metadata) | `func get_cancel_metadata() -> Dictionary:` |
| 方法 | [`get_cancel_requested_msec`](#member-gfcancellationtoken-methods-get_cancel_requested_msec) | `func get_cancel_requested_msec() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfcancellationtoken-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfcancellationtoken-signals-cancel_requested"></a>

### `cancel_requested`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal cancel_requested(reason: StringName)
```

当取消请求首次到达时发出。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 稳定取消原因。 |

## 方法

<a id="member-gfcancellationtoken-methods-is_cancel_requested"></a>

### `is_cancel_requested`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_cancel_requested() -> bool:
```

返回是否已经收到取消请求。

返回：已请求取消时返回 true。

<a id="member-gfcancellationtoken-methods-get_cancel_reason"></a>

### `get_cancel_reason`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cancel_reason() -> StringName:
```

返回取消原因。

返回：首次取消请求提供的原因；未取消时为空 StringName。

<a id="member-gfcancellationtoken-methods-get_cancel_metadata"></a>

### `get_cancel_metadata`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cancel_metadata() -> Dictionary:
```

返回取消元数据副本。

返回：取消元数据副本。

结构：

- `return`: Dictionary，包含取消拥有者提供的上下文。

<a id="member-gfcancellationtoken-methods-get_cancel_requested_msec"></a>

### `get_cancel_requested_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_cancel_requested_msec() -> int:
```

返回取消请求发生时的 Time.get_ticks_msec()。

返回：取消请求发生时的毫秒 tick；未取消时为 0。

<a id="member-gfcancellationtoken-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取取消状态快照。

返回：取消状态快照。

结构：

- `return`: Dictionary，包含 cancel_requested、reason、metadata 和 cancel_requested_msec。
