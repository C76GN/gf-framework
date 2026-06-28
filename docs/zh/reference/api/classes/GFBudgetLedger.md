# GFBudgetLedger

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/budget/gf_budget_ledger.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

通用资源预算账本。 用于记录一组抽象资源的容量、可用量和消耗结果。 资源含义由项目决定，框架只提供预算检查、消费、释放和快照。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`budget_changed`](#member-gfbudgetledger-signals-budget_changed) | `signal budget_changed(budget_id: StringName, available: float, capacity: float)` |
| 信号 | [`budget_consumed`](#member-gfbudgetledger-signals-budget_consumed) | `signal budget_consumed(budget_id: StringName, amount: float)` |
| 信号 | [`budget_rejected`](#member-gfbudgetledger-signals-budget_rejected) | `signal budget_rejected(budget_id: StringName, amount: float, reason: String)` |
| 信号 | [`budgets_cleared`](#member-gfbudgetledger-signals-budgets_cleared) | `signal budgets_cleared(budget_ids: PackedStringArray)` |
| 方法 | [`set_capacity`](#member-gfbudgetledger-methods-set_capacity) | `func set_capacity(budget_id: StringName, capacity: float, reset_available: bool = true) -> void:` |
| 方法 | [`set_available`](#member-gfbudgetledger-methods-set_available) | `func set_available(budget_id: StringName, available: float) -> void:` |
| 方法 | [`get_capacity`](#member-gfbudgetledger-methods-get_capacity) | `func get_capacity(budget_id: StringName) -> float:` |
| 方法 | [`get_available`](#member-gfbudgetledger-methods-get_available) | `func get_available(budget_id: StringName) -> float:` |
| 方法 | [`can_consume`](#member-gfbudgetledger-methods-can_consume) | `func can_consume(budget_id: StringName, amount: float) -> bool:` |
| 方法 | [`consume`](#member-gfbudgetledger-methods-consume) | `func consume(budget_id: StringName, amount: float, metadata: Dictionary = {}) -> Dictionary:` |
| 方法 | [`release`](#member-gfbudgetledger-methods-release) | `func release(budget_id: StringName, amount: float) -> void:` |
| 方法 | [`reset`](#member-gfbudgetledger-methods-reset) | `func reset(budget_id: StringName = &"") -> void:` |
| 方法 | [`clear`](#member-gfbudgetledger-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_snapshot`](#member-gfbudgetledger-methods-get_snapshot) | `func get_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfbudgetledger-signals-budget_changed"></a>

### `budget_changed`

- API：`public`

```gdscript
signal budget_changed(budget_id: StringName, available: float, capacity: float)
```

资源预算变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `available` | 当前可用量。 |
| `capacity` | 当前容量。 |

<a id="member-gfbudgetledger-signals-budget_consumed"></a>

### `budget_consumed`

- API：`public`

```gdscript
signal budget_consumed(budget_id: StringName, amount: float)
```

资源消费成功后发出。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `amount` | 消费数量。 |

<a id="member-gfbudgetledger-signals-budget_rejected"></a>

### `budget_rejected`

- API：`public`

```gdscript
signal budget_rejected(budget_id: StringName, amount: float, reason: String)
```

资源消费被拒绝后发出。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `amount` | 请求数量。 |
| `reason` | 拒绝原因。 |

<a id="member-gfbudgetledger-signals-budgets_cleared"></a>

### `budgets_cleared`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal budgets_cleared(budget_ids: PackedStringArray)
```

所有预算清空后发出。

参数：

| 名称 | 说明 |
|---|---|
| `budget_ids` | 被清空的预算标识列表。 |

## 方法

<a id="member-gfbudgetledger-methods-set_capacity"></a>

### `set_capacity`

- API：`public`

```gdscript
func set_capacity(budget_id: StringName, capacity: float, reset_available: bool = true) -> void:
```

设置预算容量，并可选重置可用量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `capacity` | 容量。 |
| `reset_available` | 是否把可用量重置为容量。 |

<a id="member-gfbudgetledger-methods-set_available"></a>

### `set_available`

- API：`public`

```gdscript
func set_available(budget_id: StringName, available: float) -> void:
```

设置当前可用量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `available` | 可用量。 |

<a id="member-gfbudgetledger-methods-get_capacity"></a>

### `get_capacity`

- API：`public`

```gdscript
func get_capacity(budget_id: StringName) -> float:
```

获取容量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |

返回：容量；不存在时返回 0。

<a id="member-gfbudgetledger-methods-get_available"></a>

### `get_available`

- API：`public`

```gdscript
func get_available(budget_id: StringName) -> float:
```

获取可用量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |

返回：可用量；不存在时返回 0。

<a id="member-gfbudgetledger-methods-can_consume"></a>

### `can_consume`

- API：`public`

```gdscript
func can_consume(budget_id: StringName, amount: float) -> bool:
```

是否有足够预算。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `amount` | 请求数量。 |

返回：预算足够时返回 true。

<a id="member-gfbudgetledger-methods-consume"></a>

### `consume`

- API：`public`

```gdscript
func consume(budget_id: StringName, amount: float, metadata: Dictionary = {}) -> Dictionary:
```

尝试消费预算。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `amount` | 消费数量。 |
| `metadata` | 调用方附加信息。 |

返回：消费结果字典。

结构：

- `metadata`: Dictionary copied into the consume result.
- `return`: Dictionary with ok, budget_id, amount, reason, available, capacity, and metadata.

<a id="member-gfbudgetledger-methods-release"></a>

### `release`

- API：`public`

```gdscript
func release(budget_id: StringName, amount: float) -> void:
```

释放预算，可用量不会超过容量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识。 |
| `amount` | 释放数量。 |

<a id="member-gfbudgetledger-methods-reset"></a>

### `reset`

- API：`public`

```gdscript
func reset(budget_id: StringName = &"") -> void:
```

将一个或全部预算重置为容量。

参数：

| 名称 | 说明 |
|---|---|
| `budget_id` | 预算标识；为空时重置全部。 |

<a id="member-gfbudgetledger-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有预算。

<a id="member-gfbudgetledger-methods-get_snapshot"></a>

### `get_snapshot`

- API：`public`

```gdscript
func get_snapshot() -> Dictionary:
```

获取预算快照。

返回：预算字典副本。

结构：

- `return`: Dictionary from budget id to capacity and available values.
