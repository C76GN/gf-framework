# GFLifetimeSubscription

[API Reference](../index.md) / [Kernel](../kernel.md) / [类索引](index.md)

- 路径：`addons/gf/kernel/core/gf_lifetime_subscription.gd`
- 模块：`Kernel`
- 继承：`GFSubscriptionToken`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`8.0.0`

绑定 owner 生命周期的订阅句柄。 owner 为 Node 时，节点退出场景树会自动取消订阅；owner 为普通 Object 时， 使用方或订阅源可通过 owner_is_released() 检查弱引用是否已经失效并执行清理。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`_init`](#member-gflifetimesubscription-methods-_init) | `func _init(owner: Object = null, cancel_callback: Callable = Callable(), debug_label: String = "") -> void:` |
| 方法 | [`cancel`](#member-gflifetimesubscription-methods-cancel) | `func cancel() -> bool:` |
| 方法 | [`is_active`](#member-gflifetimesubscription-methods-is_active) | `func is_active() -> bool:` |
| 方法 | [`get_owner`](#member-gflifetimesubscription-methods-get_owner) | `func get_owner() -> Object:` |
| 方法 | [`get_owner_id`](#member-gflifetimesubscription-methods-get_owner_id) | `func get_owner_id() -> int:` |
| 方法 | [`owner_is_released`](#member-gflifetimesubscription-methods-owner_is_released) | `func owner_is_released() -> bool:` |

## 方法

<a id="member-gflifetimesubscription-methods-_init"></a>

### `_init`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func _init(owner: Object = null, cancel_callback: Callable = Callable(), debug_label: String = "") -> void:
```

构造函数。

参数：

| 名称 | 说明 |
|---|---|
| `owner` | 订阅生命周期 owner。 |
| `cancel_callback` | 首次取消时执行的无参清理回调。 |
| `debug_label` | 可选诊断标签。 |

<a id="member-gflifetimesubscription-methods-cancel"></a>

### `cancel`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func cancel() -> bool:
```

取消订阅并解除 owner 自动取消监听。

返回：本次调用是否首次取消了活动订阅。

<a id="member-gflifetimesubscription-methods-is_active"></a>

### `is_active`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func is_active() -> bool:
```

返回订阅是否仍处于活动状态。

返回：token 未取消且 owner 未释放时返回 true。

<a id="member-gflifetimesubscription-methods-get_owner"></a>

### `get_owner`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_owner() -> Object:
```

返回生命周期 owner；未设置或已释放时返回 null。

返回：当前 owner 或 null。

<a id="member-gflifetimesubscription-methods-get_owner_id"></a>

### `get_owner_id`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_owner_id() -> int:
```

返回 owner 的实例 ID；未设置时为 0。

返回：owner 实例 ID。

<a id="member-gflifetimesubscription-methods-owner_is_released"></a>

### `owner_is_released`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func owner_is_released() -> bool:
```

返回 owner 是否已经释放。

返回：owner 曾经设置且当前已无法解析时返回 true。
