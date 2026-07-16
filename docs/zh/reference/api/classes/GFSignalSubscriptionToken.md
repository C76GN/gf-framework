# GFSignalSubscriptionToken

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_signal_subscription_token.gd`
- 模块：`Kernel`
- 继承：`GFSubscriptionToken`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

管理 Godot Signal 连接的订阅句柄。 该句柄把 Signal 连接视为需要显式释放的资源；调用 cancel() 会幂等断开连接。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gfsignalsubscriptiontoken-methods-_init) | `func _init( source_signal: Signal = Signal(), callback: Callable = Callable(), flags: int = 0, debug_label: String = "" ) -> void:` |
| 方法 | [`connect_owned`](#member-gfsignalsubscriptiontoken-methods-connect_owned) | `static func connect_owned( source_signal: Signal, owner: Object, callback: Callable, flags: int = 0, debug_label: String = "" ) -> GFLifetimeSubscription:` |
| 方法 | [`get_source_id`](#member-gfsignalsubscriptiontoken-methods-get_source_id) | `func get_source_id() -> int:` |
| 方法 | [`get_signal_name`](#member-gfsignalsubscriptiontoken-methods-get_signal_name) | `func get_signal_name() -> StringName:` |

## 方法

<a id="member-gfsignalsubscriptiontoken-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func _init( source_signal: Signal = Signal(), callback: Callable = Callable(), flags: int = 0, debug_label: String = "" ) -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接的 Godot Signal。 |
| `callback` | Signal 触发时调用的回调。 |
| `flags` | Godot Signal 连接标记。 |
| `debug_label` | 可选诊断标签。 |

<a id="member-gfsignalsubscriptiontoken-methods-connect_owned"></a>

### `connect_owned`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func connect_owned( source_signal: Signal, owner: Object, callback: Callable, flags: int = 0, debug_label: String = "" ) -> GFLifetimeSubscription:
```

创建绑定 owner 生命周期的 Signal 订阅。 owner 为 Node 时，节点退出场景树会自动取消订阅；其他 Object owner 仍可通过返回的句柄手动取消。

参数：

| 名称 | 说明 |
|---|---|
| `source_signal` | 要连接的 Godot Signal。 |
| `owner` | 订阅生命周期 owner。 |
| `callback` | Signal 触发时调用的回调。 |
| `flags` | Godot Signal 连接标记。 |
| `debug_label` | 可选诊断标签。 |

返回：绑定 owner 生命周期的订阅句柄；参数无效或连接失败时返回非活动句柄。

<a id="member-gfsignalsubscriptiontoken-methods-get_source_id"></a>

### `get_source_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_source_id() -> int:
```

返回 Signal 来源对象实例 ID；无有效来源时为 0。

返回：Signal 来源对象实例 ID。

<a id="member-gfsignalsubscriptiontoken-methods-get_signal_name"></a>

### `get_signal_name`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_signal_name() -> StringName:
```

返回 Signal 名称；无有效来源时为空。

返回：Signal 名称。
