# GFSaveProfileRecoveryLease

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_recovery_lease.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`unreleased`

缺失或损坏 Profile 的一次性恢复授权。 Lease 由失败的 activate 操作创建，并绑定创建时的事务、Profile、Provider domain generation 与 lifecycle epoch。bootstrap/adopt 必须原样提交同一 Lease； domain 或 epoch 前进后，旧 Lease 会失效，不能把陈旧恢复决定应用到新状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`REASON_MISSING`](#member-gfsaveprofilerecoverylease-constants-reason_missing) | `const REASON_MISSING: StringName = &"missing"` |
| 常量 | [`REASON_CORRUPT`](#member-gfsaveprofilerecoverylease-constants-reason_corrupt) | `const REASON_CORRUPT: StringName = &"corrupt"` |
| 常量 | [`STATE_AVAILABLE`](#member-gfsaveprofilerecoverylease-constants-state_available) | `const STATE_AVAILABLE: StringName = &"available"` |
| 常量 | [`STATE_CLAIMED`](#member-gfsaveprofilerecoverylease-constants-state_claimed) | `const STATE_CLAIMED: StringName = &"claimed"` |
| 常量 | [`STATE_STALE`](#member-gfsaveprofilerecoverylease-constants-state_stale) | `const STATE_STALE: StringName = &"stale"` |
| 方法 | [`get_lease_id`](#member-gfsaveprofilerecoverylease-methods-get_lease_id) | `func get_lease_id() -> int:` |
| 方法 | [`get_transaction_id`](#member-gfsaveprofilerecoverylease-methods-get_transaction_id) | `func get_transaction_id() -> int:` |
| 方法 | [`get_profile_id`](#member-gfsaveprofilerecoverylease-methods-get_profile_id) | `func get_profile_id() -> StringName:` |
| 方法 | [`get_reason`](#member-gfsaveprofilerecoverylease-methods-get_reason) | `func get_reason() -> StringName:` |
| 方法 | [`get_domain_id`](#member-gfsaveprofilerecoverylease-methods-get_domain_id) | `func get_domain_id() -> int:` |
| 方法 | [`get_domain_generation`](#member-gfsaveprofilerecoverylease-methods-get_domain_generation) | `func get_domain_generation() -> int:` |
| 方法 | [`get_epoch`](#member-gfsaveprofilerecoverylease-methods-get_epoch) | `func get_epoch() -> int:` |
| 方法 | [`get_state`](#member-gfsaveprofilerecoverylease-methods-get_state) | `func get_state() -> StringName:` |
| 方法 | [`is_available`](#member-gfsaveprofilerecoverylease-methods-is_available) | `func is_available() -> bool:` |
| 方法 | [`is_claimed`](#member-gfsaveprofilerecoverylease-methods-is_claimed) | `func is_claimed() -> bool:` |
| 方法 | [`is_stale`](#member-gfsaveprofilerecoverylease-methods-is_stale) | `func is_stale() -> bool:` |

## 常量

<a id="member-gfsaveprofilerecoverylease-constants-reason_missing"></a>

### `REASON_MISSING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_MISSING: StringName = &"missing"
```

激活目标没有持久化文档。

<a id="member-gfsaveprofilerecoverylease-constants-reason_corrupt"></a>

### `REASON_CORRUPT`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const REASON_CORRUPT: StringName = &"corrupt"
```

激活目标文档损坏或完整性无效。

<a id="member-gfsaveprofilerecoverylease-constants-state_available"></a>

### `STATE_AVAILABLE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_AVAILABLE: StringName = &"available"
```

Lease 尚未被恢复操作消费。

<a id="member-gfsaveprofilerecoverylease-constants-state_claimed"></a>

### `STATE_CLAIMED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_CLAIMED: StringName = &"claimed"
```

Lease 已被一个恢复操作消费。

<a id="member-gfsaveprofilerecoverylease-constants-state_stale"></a>

### `STATE_STALE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const STATE_STALE: StringName = &"stale"
```

Lease 的 domain generation 或 lifecycle epoch 已过期。

## 方法

<a id="member-gfsaveprofilerecoverylease-methods-get_lease_id"></a>

### `get_lease_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_lease_id() -> int:
```

获取 Utility 生命周期内唯一的 Lease ID。

返回：正整数 Lease ID；未配置时为 0。

<a id="member-gfsaveprofilerecoverylease-methods-get_transaction_id"></a>

### `get_transaction_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_transaction_id() -> int:
```

获取产生当前 Lease 的事务 ID。

返回：正整数事务 ID；未配置时为 0。

<a id="member-gfsaveprofilerecoverylease-methods-get_profile_id"></a>

### `get_profile_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_profile_id() -> StringName:
```

获取待恢复 Profile ID。

返回：Profile ID。

<a id="member-gfsaveprofilerecoverylease-methods-get_reason"></a>

### `get_reason`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_reason() -> StringName:
```

获取恢复原因。

返回：`REASON_MISSING` 或 `REASON_CORRUPT`。

<a id="member-gfsaveprofilerecoverylease-methods-get_domain_id"></a>

### `get_domain_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_domain_id() -> int:
```

获取运行时 Provider domain ID。

返回：Utility 生命周期内唯一的正整数 domain ID。

<a id="member-gfsaveprofilerecoverylease-methods-get_domain_generation"></a>

### `get_domain_generation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_domain_generation() -> int:
```

获取 Lease 创建时的 domain generation。

返回：正整数 domain generation。

<a id="member-gfsaveprofilerecoverylease-methods-get_epoch"></a>

### `get_epoch`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_epoch() -> int:
```

获取 Lease 创建时的 Utility lifecycle epoch。

返回：正整数 lifecycle epoch。

<a id="member-gfsaveprofilerecoverylease-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_state() -> StringName:
```

获取当前 Lease 状态。

返回：`STATE_*` 常量之一。

<a id="member-gfsaveprofilerecoverylease-methods-is_available"></a>

### `is_available`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_available() -> bool:
```

检查 Lease 是否仍可由 bootstrap/adopt 消费。

返回：可用时返回 true。

<a id="member-gfsaveprofilerecoverylease-methods-is_claimed"></a>

### `is_claimed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_claimed() -> bool:
```

检查 Lease 是否已经被消费。

返回：已 claim 时返回 true。

<a id="member-gfsaveprofilerecoverylease-methods-is_stale"></a>

### `is_stale`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func is_stale() -> bool:
```

检查 Lease 是否已经过期。

返回：已标记 stale 或从未有效配置时返回 true。
