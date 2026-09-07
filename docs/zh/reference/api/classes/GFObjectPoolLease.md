# GFObjectPoolLease

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/nodes/gf_object_pool_lease.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

一次节点借用的使用权。 归还后立即停止提供节点；物理离树和最终通知由对象池在安全点执行。 每次借用使用新的 Lease，旧 Lease 永远不能归还同一节点的新借用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`settled`](#member-gfobjectpoollease-signals-settled) | `signal settled(reason: StringName)` |
| 枚举 | [`State`](#member-gfobjectpoollease-enums-state) | `enum State` |
| 方法 | [`get_node`](#member-gfobjectpoollease-methods-get_node) | `func get_node() -> Node:` |
| 方法 | [`release`](#member-gfobjectpoollease-methods-release) | `func release() -> bool:` |
| 方法 | [`get_state`](#member-gfobjectpoollease-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_settled`](#member-gfobjectpoollease-methods-is_settled) | `func is_settled() -> bool:` |
| 方法 | [`wait_settled`](#member-gfobjectpoollease-methods-wait_settled) | `func wait_settled() -> StringName:` |
| 方法 | [`get_settlement_reason`](#member-gfobjectpoollease-methods-get_settlement_reason) | `func get_settlement_reason() -> StringName:` |

## 信号

<a id="member-gfobjectpoollease-signals-settled"></a>

### `settled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal settled(reason: StringName)
```

归还、节点丢失或池销毁完成时恰好发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | released、node_lost、pool_disposed 或 capacity_retired。 |

## 枚举

<a id="member-gfobjectpoollease-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`unreleased`

```gdscript
enum State {
	## 调用方仍持有节点使用权。
	ACTIVE,
	## 使用权已撤销，等待安全点清理。
	RELEASE_PENDING,
	## 本次借用已经结束。
	SETTLED,
}
```

本次借用的状态；节点丢失也是 SETTLED，原因由 get_settlement_reason 提供。

## 方法

<a id="member-gfobjectpoollease-methods-get_node"></a>

### `get_node`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_node() -> Node:
```

取得仍由本次借用持有的节点。

返回：ACTIVE 且仍存活的节点；归还、排队删除或丢失后返回 null。

<a id="member-gfobjectpoollease-methods-release"></a>

### `release`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release() -> bool:
```

归还本次借用。首次接纳后立即失去使用权，不支持撤销归还。

返回：本次调用首次接纳归还时为 true；重复或陈旧借用为 false。

<a id="member-gfobjectpoollease-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> State:
```

读取当前借用状态。

返回：当前 State。

<a id="member-gfobjectpoollease-methods-is_settled"></a>

### `is_settled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_settled() -> bool:
```

检查本次借用是否已经结束。

返回：任意终态均返回 true。

<a id="member-gfobjectpoollease-methods-wait_settled"></a>

### `wait_settled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func wait_settled() -> StringName:
```

等待归还完成；已完成时直接返回缓存的原因，允许多次等待。

返回：与 get_settlement_reason 相同的最终原因。

<a id="member-gfobjectpoollease-methods-get_settlement_reason"></a>

### `get_settlement_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_settlement_reason() -> StringName:
```

读取本次借用的最终原因。

返回：未结束时为 pending，未配置时为 unconfigured，否则为 settled 的原因。
