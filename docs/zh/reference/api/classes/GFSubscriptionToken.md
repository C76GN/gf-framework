# GFSubscriptionToken

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_subscription_token.gd`
- 模块：`Kernel`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

可取消订阅的通用运行时句柄。 订阅创建方应返回该句柄，由调用方在不再需要监听时调用 cancel()。 cancel() 是幂等的，首次取消会执行注册的清理回调，后续调用只返回 false。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfsubscriptiontoken-methods-_init) | `func _init(cancel_callback: Callable = Callable(), debug_label: String = "") -> void:` |
| 方法 | [`cancel`](#member-gfsubscriptiontoken-methods-cancel) | `func cancel() -> bool:` |
| 方法 | [`is_active`](#member-gfsubscriptiontoken-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_debug_label`](#member-gfsubscriptiontoken-methods-get_debug_label) | `func get_debug_label() -> String:` |

## 方法

<a id="member-gfsubscriptiontoken-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func _init(cancel_callback: Callable = Callable(), debug_label: String = "") -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `cancel_callback` | 首次取消时执行的无参清理回调。 |
| `debug_label` | 可选诊断标签。 |

<a id="member-gfsubscriptiontoken-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel() -> bool:
```

取消订阅并执行清理回调。

返回：本次调用是否首次取消了活动订阅。

<a id="member-gfsubscriptiontoken-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_active() -> bool:
```

返回订阅是否仍处于活动状态。

返回：活动时返回 true。

<a id="member-gfsubscriptiontoken-methods-get_debug_label"></a>

### `get_debug_label`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_debug_label() -> String:
```

返回诊断标签。

返回：创建订阅时传入的诊断标签。
