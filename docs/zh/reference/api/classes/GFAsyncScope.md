# GFAsyncScope

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_async_scope.gd`
- 模块：`Kernel`
- 继承：`GFCancellationToken`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

由生命周期拥有者控制的可取消异步作用域。 作用域继承自 GFCancellationToken，可直接传给需要只读取消检查的流程。 注册的清理回调会在 cancel() 时按后进先出顺序执行；complete() 表示流程正常结束并清空清理回调。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`get_token`](#member-gfasyncscope-methods-get_token) | `func get_token() -> GFCancellationToken:` |
| 方法 | [`is_active`](#member-gfasyncscope-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`is_completed`](#member-gfasyncscope-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`register_cleanup`](#member-gfasyncscope-methods-register_cleanup) | `func register_cleanup(cleanup_callback: Callable) -> bool:` |
| 方法 | [`unregister_cleanup`](#member-gfasyncscope-methods-unregister_cleanup) | `func unregister_cleanup(cleanup_callback: Callable) -> void:` |
| 方法 | [`cancel`](#member-gfasyncscope-methods-cancel) | `func cancel(reason: String = "", metadata: Dictionary = {}) -> bool:` |
| 方法 | [`complete`](#member-gfasyncscope-methods-complete) | `func complete() -> void:` |

## 方法

<a id="member-gfasyncscope-methods-get_token"></a>

### `get_token`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_token() -> GFCancellationToken:
```

返回当前作用域的只读取消令牌视图。

返回：当前作用域自身，可作为 GFCancellationToken 使用。

<a id="member-gfasyncscope-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_active() -> bool:
```

返回作用域是否仍处于活动状态。

返回：未 complete 且未 cancel 时返回 true。

<a id="member-gfasyncscope-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_completed() -> bool:
```

返回作用域是否已经正常完成。

返回：complete() 被调用后返回 true。

<a id="member-gfasyncscope-methods-register_cleanup"></a>

### `register_cleanup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func register_cleanup(cleanup_callback: Callable) -> bool:
```

注册取消时执行的清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `cleanup_callback` | 取消时执行的无参 Callable。 |

返回：注册成功、或已取消时即时执行成功，返回 true；无效回调或已完成作用域返回 false。

<a id="member-gfasyncscope-methods-unregister_cleanup"></a>

### `unregister_cleanup`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func unregister_cleanup(cleanup_callback: Callable) -> void:
```

注销取消清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `cleanup_callback` | 要移除的清理回调。 |

<a id="member-gfasyncscope-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel(reason: String = "", metadata: Dictionary = {}) -> bool:
```

请求取消当前作用域，并执行已注册的清理回调。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 取消原因。 |
| `metadata` | 取消上下文。 |

返回：本次调用是否首次触发取消。

结构：

- `metadata`: Dictionary，包含调用方定义的取消上下文。

<a id="member-gfasyncscope-methods-complete"></a>

### `complete`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func complete() -> void:
```

标记异步作用域已正常完成，并丢弃取消清理回调。
