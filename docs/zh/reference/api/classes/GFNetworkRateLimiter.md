# GFNetworkRateLimiter

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_rate_limiter.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用令牌桶限流器。 可用于限制消息发送频率，避免某类同步或 RPC 过量发送。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`capacity`](#member-gfnetworkratelimiter-properties-capacity) | `var capacity: float = 10.0:` |
| 属性 | [`refill_per_second`](#member-gfnetworkratelimiter-properties-refill_per_second) | `var refill_per_second: float = 10.0:` |
| 方法 | [`tick`](#member-gfnetworkratelimiter-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`consume`](#member-gfnetworkratelimiter-methods-consume) | `func consume(amount: float = 1.0) -> bool:` |
| 方法 | [`get_tokens`](#member-gfnetworkratelimiter-methods-get_tokens) | `func get_tokens() -> float:` |
| 方法 | [`reset`](#member-gfnetworkratelimiter-methods-reset) | `func reset() -> void:` |

## 属性

<a id="member-gfnetworkratelimiter-properties-capacity"></a>

### `capacity`

- API：`public`

```gdscript
var capacity: float = 10.0:
```

令牌桶容量。

<a id="member-gfnetworkratelimiter-properties-refill_per_second"></a>

### `refill_per_second`

- API：`public`

```gdscript
var refill_per_second: float = 10.0:
```

每秒恢复令牌数。

## 方法

<a id="member-gfnetworkratelimiter-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(delta: float) -> void:
```

推进限流器时间。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 秒数。 |

<a id="member-gfnetworkratelimiter-methods-consume"></a>

### `consume`

- API：`public`

```gdscript
func consume(amount: float = 1.0) -> bool:
```

尝试消费令牌。

参数：

| 名称 | 说明 |
|---|---|
| `amount` | 令牌数量。 |

返回：成功消费返回 true。

<a id="member-gfnetworkratelimiter-methods-get_tokens"></a>

### `get_tokens`

- API：`public`

```gdscript
func get_tokens() -> float:
```

获取当前令牌数。

返回：令牌数。

<a id="member-gfnetworkratelimiter-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置令牌桶。
