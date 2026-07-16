# GFProtocolAckLedger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/io/gf_protocol_ack_ledger.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`7.0.0`

通用协议确认账本。 记录任意协议的待确认 packet/request ID、确认结果、失败和过期状态。 它不实现具体网络协议，也不规定 ID 生成、重传策略或连接生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`STATE_PENDING`](#member-gfprotocolackledger-constants-state_pending) | `const STATE_PENDING: StringName = &"pending"` |
| 常量 | [`STATE_ACKED`](#member-gfprotocolackledger-constants-state_acked) | `const STATE_ACKED: StringName = &"acked"` |
| 常量 | [`STATE_FAILED`](#member-gfprotocolackledger-constants-state_failed) | `const STATE_FAILED: StringName = &"failed"` |
| 常量 | [`STATE_EXPIRED`](#member-gfprotocolackledger-constants-state_expired) | `const STATE_EXPIRED: StringName = &"expired"` |
| 属性 | [`timeout_msec`](#member-gfprotocolackledger-properties-timeout_msec) | `var timeout_msec: int = 0:` |
| 属性 | [`max_entries`](#member-gfprotocolackledger-properties-max_entries) | `var max_entries: int = 256` |
| 属性 | [`max_attempts`](#member-gfprotocolackledger-properties-max_attempts) | `var max_attempts: int = 0:` |
| 属性 | [`retry_interval_msec`](#member-gfprotocolackledger-properties-retry_interval_msec) | `var retry_interval_msec: int = 0:` |
| 属性 | [`incoming_window_size`](#member-gfprotocolackledger-properties-incoming_window_size) | `var incoming_window_size: int = 256:` |
| 属性 | [`metadata`](#member-gfprotocolackledger-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`clear`](#member-gfprotocolackledger-methods-clear) | `func clear() -> void:` |
| 方法 | [`register_packet`](#member-gfprotocolackledger-methods-register_packet) | `func register_packet(packet_id: Variant, entry_metadata: Dictionary = {}, now_msec: int = -1) -> bool:` |
| 方法 | [`acknowledge_packet`](#member-gfprotocolackledger-methods-acknowledge_packet) | `func acknowledge_packet(packet_id: Variant, result: Variant = null, now_msec: int = -1) -> bool:` |
| 方法 | [`fail_packet`](#member-gfprotocolackledger-methods-fail_packet) | `func fail_packet(packet_id: Variant, error: String = "", result: Variant = null, now_msec: int = -1) -> bool:` |
| 方法 | [`expire_pending`](#member-gfprotocolackledger-methods-expire_pending) | `func expire_pending(now_msec: int = -1) -> Dictionary:` |
| 方法 | [`record_packet_attempt`](#member-gfprotocolackledger-methods-record_packet_attempt) | `func record_packet_attempt( packet_id: Variant, now_msec: int = -1, retry_delay_msec: int = -1 ) -> bool:` |
| 方法 | [`get_retry_ready_ids`](#member-gfprotocolackledger-methods-get_retry_ready_ids) | `func get_retry_ready_ids(now_msec: int = -1, limit: int = 0) -> Array:` |
| 方法 | [`get_attempt_count`](#member-gfprotocolackledger-methods-get_attempt_count) | `func get_attempt_count(packet_id: Variant) -> int:` |
| 方法 | [`accept_incoming_packet`](#member-gfprotocolackledger-methods-accept_incoming_packet) | `func accept_incoming_packet( packet_id: Variant, sequence: int = -1, channel: StringName = &"default", now_msec: int = -1 ) -> Dictionary:` |
| 方法 | [`has_incoming_packet`](#member-gfprotocolackledger-methods-has_incoming_packet) | `func has_incoming_packet(packet_id: Variant) -> bool:` |
| 方法 | [`remove_packet`](#member-gfprotocolackledger-methods-remove_packet) | `func remove_packet(packet_id: Variant) -> bool:` |
| 方法 | [`has_packet`](#member-gfprotocolackledger-methods-has_packet) | `func has_packet(packet_id: Variant) -> bool:` |
| 方法 | [`is_pending`](#member-gfprotocolackledger-methods-is_pending) | `func is_pending(packet_id: Variant) -> bool:` |
| 方法 | [`get_packet`](#member-gfprotocolackledger-methods-get_packet) | `func get_packet(packet_id: Variant) -> Dictionary:` |
| 方法 | [`get_packets`](#member-gfprotocolackledger-methods-get_packets) | `func get_packets(state_filter: StringName = &"") -> Array[Dictionary]:` |
| 方法 | [`get_pending_ids`](#member-gfprotocolackledger-methods-get_pending_ids) | `func get_pending_ids() -> Array:` |
| 方法 | [`get_count`](#member-gfprotocolackledger-methods-get_count) | `func get_count() -> int:` |
| 方法 | [`get_pending_count`](#member-gfprotocolackledger-methods-get_pending_count) | `func get_pending_count() -> int:` |
| 方法 | [`get_debug_snapshot`](#member-gfprotocolackledger-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 常量

<a id="member-gfprotocolackledger-constants-state_pending"></a>

### `STATE_PENDING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_PENDING: StringName = &"pending"
```

条目等待确认。

<a id="member-gfprotocolackledger-constants-state_acked"></a>

### `STATE_ACKED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_ACKED: StringName = &"acked"
```

条目已经确认。

<a id="member-gfprotocolackledger-constants-state_failed"></a>

### `STATE_FAILED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_FAILED: StringName = &"failed"
```

条目失败。

<a id="member-gfprotocolackledger-constants-state_expired"></a>

### `STATE_EXPIRED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATE_EXPIRED: StringName = &"expired"
```

条目等待超时。

## 属性

<a id="member-gfprotocolackledger-properties-timeout_msec"></a>

### `timeout_msec`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var timeout_msec: int = 0:
```

新条目的默认等待超时；小于等于 0 时不自动过期。

<a id="member-gfprotocolackledger-properties-max_entries"></a>

### `max_entries`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_entries: int = 256
```

最大记录数量；小于等于 0 时不限制。

<a id="member-gfprotocolackledger-properties-max_attempts"></a>

### `max_attempts`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var max_attempts: int = 0:
```

最大发送尝试次数；小于等于 0 时不限制。

<a id="member-gfprotocolackledger-properties-retry_interval_msec"></a>

### `retry_interval_msec`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var retry_interval_msec: int = 0:
```

默认重试间隔；小于等于 0 时不自动进入 retry-ready。

<a id="member-gfprotocolackledger-properties-incoming_window_size"></a>

### `incoming_window_size`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var incoming_window_size: int = 256:
```

入站去重窗口大小；小于等于 0 时不记录入站包 ID。

<a id="member-gfprotocolackledger-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var metadata: Dictionary = {}
```

调用方自定义元数据。

结构：

- `metadata`: Dictionary[String, Variant] copied into debug snapshots.

## 方法

<a id="member-gfprotocolackledger-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部记录。

<a id="member-gfprotocolackledger-methods-register_packet"></a>

### `register_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_packet(packet_id: Variant, entry_metadata: Dictionary = {}, now_msec: int = -1) -> bool:
```

注册一个待确认条目。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |
| `entry_metadata` | 条目元数据。 |
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：注册成功返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.
- `entry_metadata`: Dictionary copied into the ledger entry.

<a id="member-gfprotocolackledger-methods-acknowledge_packet"></a>

### `acknowledge_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func acknowledge_packet(packet_id: Variant, result: Variant = null, now_msec: int = -1) -> bool:
```

标记条目确认成功。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |
| `result` | 确认结果。 |
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：状态成功变更时返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.
- `result`: Variant copied into the ledger entry.

<a id="member-gfprotocolackledger-methods-fail_packet"></a>

### `fail_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func fail_packet(packet_id: Variant, error: String = "", result: Variant = null, now_msec: int = -1) -> bool:
```

标记条目失败。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |
| `error` | 失败说明。 |
| `result` | 失败结果。 |
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：状态成功变更时返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.
- `result`: Variant copied into the ledger entry.

<a id="member-gfprotocolackledger-methods-expire_pending"></a>

### `expire_pending`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func expire_pending(now_msec: int = -1) -> Dictionary:
```

让超过 deadline 的待确认条目进入 expired 状态。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：过期报告。

结构：

- `return`: Dictionary with expired_count, expired_ids, pending_count, and state_counts.

<a id="member-gfprotocolackledger-methods-record_packet_attempt"></a>

### `record_packet_attempt`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func record_packet_attempt( packet_id: Variant, now_msec: int = -1, retry_delay_msec: int = -1 ) -> bool:
```

记录一次发送尝试，并根据 retry interval 计算下次重试时间。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |
| `retry_delay_msec` | 本次尝试后的重试延迟；小于 0 时使用 retry_interval_msec。 |

返回：发送尝试被记录时返回 true；超过 max_attempts 时条目进入 failed。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-get_retry_ready_ids"></a>

### `get_retry_ready_ids`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_retry_ready_ids(now_msec: int = -1, limit: int = 0) -> Array:
```

获取已经到达重试时间的待确认 ID。

参数：

| 名称 | 说明 |
|---|---|
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |
| `limit` | 最大返回数量；小于等于 0 表示不限制。 |

返回：待重试 ID 数组。

结构：

- `return`: Array[Variant] copied from pending ledger entries whose next_retry_msec is due.

<a id="member-gfprotocolackledger-methods-get_attempt_count"></a>

### `get_attempt_count`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_attempt_count(packet_id: Variant) -> int:
```

获取条目的发送尝试次数。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：条目不存在时返回 0。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-accept_incoming_packet"></a>

### `accept_incoming_packet`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func accept_incoming_packet( packet_id: Variant, sequence: int = -1, channel: StringName = &"default", now_msec: int = -1 ) -> Dictionary:
```

接收入站包并执行去重与可选顺序检查。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |
| `sequence` | 可选严格递增序号；小于 0 时不执行顺序检查。 |
| `channel` | 顺序检查通道。 |
| `now_msec` | 当前时间；小于 0 时使用 Time.get_ticks_msec()。 |

返回：入站接收报告。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.
- `return`: Dictionary with ok, accepted, duplicate, out_of_order, reason, id, sequence, channel, and last_sequence.

<a id="member-gfprotocolackledger-methods-has_incoming_packet"></a>

### `has_incoming_packet`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func has_incoming_packet(packet_id: Variant) -> bool:
```

判断入站包 ID 是否已经在去重窗口中出现。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：已出现时返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-remove_packet"></a>

### `remove_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func remove_packet(packet_id: Variant) -> bool:
```

移除指定条目。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：移除成功返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-has_packet"></a>

### `has_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_packet(packet_id: Variant) -> bool:
```

检查条目是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：存在返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func is_pending(packet_id: Variant) -> bool:
```

检查条目是否仍待确认。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：待确认返回 true。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.

<a id="member-gfprotocolackledger-methods-get_packet"></a>

### `get_packet`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_packet(packet_id: Variant) -> Dictionary:
```

获取条目副本。

参数：

| 名称 | 说明 |
|---|---|
| `packet_id` | 协议层稳定 ID。 |

返回：条目副本；不存在时返回空字典。

结构：

- `packet_id`: Non-empty String/StringName or int stable protocol packet id.
- `return`: Dictionary with id, state, timestamps, deadline_msec, result, error, and metadata.

<a id="member-gfprotocolackledger-methods-get_packets"></a>

### `get_packets`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_packets(state_filter: StringName = &"") -> Array[Dictionary]:
```

按状态获取条目副本。

参数：

| 名称 | 说明 |
|---|---|
| `state_filter` | 状态过滤；为空时返回所有条目。 |

返回：条目数组。

结构：

- `return`: Array[Dictionary] of ledger entry copies.

<a id="member-gfprotocolackledger-methods-get_pending_ids"></a>

### `get_pending_ids`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_ids() -> Array:
```

获取待确认 ID 列表。

返回：待确认 ID 数组。

结构：

- `return`: Array[Variant] copied from pending ledger entries.

<a id="member-gfprotocolackledger-methods-get_count"></a>

### `get_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_count() -> int:
```

获取总记录数。

返回：总记录数。

<a id="member-gfprotocolackledger-methods-get_pending_count"></a>

### `get_pending_count`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_pending_count() -> int:
```

获取待确认记录数。

返回：待确认记录数。

<a id="member-gfprotocolackledger-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取调试快照。

返回：调试快照。

结构：

- `return`: Dictionary with count, pending_count, state_counts, ids, timeout_msec, max_entries, and metadata.
