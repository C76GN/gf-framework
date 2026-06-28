# GFNetworkReconnectPolicy

[API Reference](../index.md) / [Network](../extensions-network.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/network/session/gf_network_reconnect_policy.gd`
- 模块：`Network`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用重连退避策略。 记录重连尝试次数，并按预设延迟序列返回下一次等待时间。它不依赖具体网络后端。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`delays_msec`](#member-gfnetworkreconnectpolicy-properties-delays_msec) | `var delays_msec: Array[int] = [500, 1000, 2000, 5000]` |
| 属性 | [`max_attempts`](#member-gfnetworkreconnectpolicy-properties-max_attempts) | `var max_attempts: int = 0` |
| 属性 | [`jitter_ratio`](#member-gfnetworkreconnectpolicy-properties-jitter_ratio) | `var jitter_ratio: float = 0.0:` |
| 方法 | [`reset`](#member-gfnetworkreconnectpolicy-methods-reset) | `func reset() -> void:` |
| 方法 | [`has_attempts_remaining`](#member-gfnetworkreconnectpolicy-methods-has_attempts_remaining) | `func has_attempts_remaining() -> bool:` |
| 方法 | [`get_next_delay_msec`](#member-gfnetworkreconnectpolicy-methods-get_next_delay_msec) | `func get_next_delay_msec() -> int:` |
| 方法 | [`record_success`](#member-gfnetworkreconnectpolicy-methods-record_success) | `func record_success() -> void:` |
| 方法 | [`set_jitter_seed`](#member-gfnetworkreconnectpolicy-methods-set_jitter_seed) | `func set_jitter_seed(seed_value: int) -> void:` |
| 方法 | [`get_attempt_count`](#member-gfnetworkreconnectpolicy-methods-get_attempt_count) | `func get_attempt_count() -> int:` |

## 属性

<a id="member-gfnetworkreconnectpolicy-properties-delays_msec"></a>

### `delays_msec`

- API：`public`

```gdscript
var delays_msec: Array[int] = [500, 1000, 2000, 5000]
```

重连延迟序列，单位毫秒。

结构：

- `delays_msec`: Array[int]，按尝试次数索引的重连延迟毫秒数。

<a id="member-gfnetworkreconnectpolicy-properties-max_attempts"></a>

### `max_attempts`

- API：`public`

```gdscript
var max_attempts: int = 0
```

最大尝试次数。小于等于 0 表示无限尝试。

<a id="member-gfnetworkreconnectpolicy-properties-jitter_ratio"></a>

### `jitter_ratio`

- API：`public`

```gdscript
var jitter_ratio: float = 0.0:
```

抖动比例。0 表示不抖动，0.2 表示在 ±20% 内随机偏移。

## 方法

<a id="member-gfnetworkreconnectpolicy-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset() -> void:
```

重置尝试计数。

<a id="member-gfnetworkreconnectpolicy-methods-has_attempts_remaining"></a>

### `has_attempts_remaining`

- API：`public`

```gdscript
func has_attempts_remaining() -> bool:
```

检查是否还允许继续尝试。

返回：允许返回 true。

<a id="member-gfnetworkreconnectpolicy-methods-get_next_delay_msec"></a>

### `get_next_delay_msec`

- API：`public`

```gdscript
func get_next_delay_msec() -> int:
```

记录一次失败并返回下一次等待时长。

返回：下一次等待时长；没有尝试空间时返回 -1。

<a id="member-gfnetworkreconnectpolicy-methods-record_success"></a>

### `record_success`

- API：`public`

```gdscript
func record_success() -> void:
```

记录一次成功并清空尝试计数。

<a id="member-gfnetworkreconnectpolicy-methods-set_jitter_seed"></a>

### `set_jitter_seed`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func set_jitter_seed(seed_value: int) -> void:
```

设置 jitter 使用的确定性随机种子。

参数：

| 名称 | 说明 |
|---|---|
| `seed_value` | 初始种子；0 会映射到 GFDeterministicRandom 的稳定默认种子。 |

<a id="member-gfnetworkreconnectpolicy-methods-get_attempt_count"></a>

### `get_attempt_count`

- API：`public`

```gdscript
func get_attempt_count() -> int:
```

获取已经消费的失败尝试次数。

返回：尝试次数。
