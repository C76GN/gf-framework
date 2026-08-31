# GFSaveProfileReconcileLease

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_reconcile_lease.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

outcome_unknown 的持续所有权与对账围栏。 Lease 保留同一对象身份，直到所有相关底层请求 late-settle 并由显式 reconcile 操作解除 domain 围栏。结果副本不会复制 Lease；因此调用方连接 `settled`、 轮询状态和提交对账时观察的是同一条生命周期。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`settled`](#member-gfsaveprofilereconcilelease-signals-settled) | `signal settled(lease: GFSaveProfileReconcileLease, state: StringName)` |
| 常量 | [`STATE_WAITING`](#member-gfsaveprofilereconcilelease-constants-state_waiting) | `const STATE_WAITING: StringName = &"waiting"` |
| 常量 | [`STATE_READY`](#member-gfsaveprofilereconcilelease-constants-state_ready) | `const STATE_READY: StringName = &"ready"` |
| 常量 | [`STATE_RECONCILING`](#member-gfsaveprofilereconcilelease-constants-state_reconciling) | `const STATE_RECONCILING: StringName = &"reconciling"` |
| 常量 | [`STATE_RESOLVED`](#member-gfsaveprofilereconcilelease-constants-state_resolved) | `const STATE_RESOLVED: StringName = &"resolved"` |
| 常量 | [`STATE_DISPOSED_UNRESOLVED`](#member-gfsaveprofilereconcilelease-constants-state_disposed_unresolved) | `const STATE_DISPOSED_UNRESOLVED: StringName = &"disposed_unresolved"` |
| 方法 | [`get_lease_id`](#member-gfsaveprofilereconcilelease-methods-get_lease_id) | `func get_lease_id() -> int:` |
| 方法 | [`get_transaction_id`](#member-gfsaveprofilereconcilelease-methods-get_transaction_id) | `func get_transaction_id() -> int:` |
| 方法 | [`get_operation`](#member-gfsaveprofilereconcilelease-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_reconcile_profile_id`](#member-gfsaveprofilereconcilelease-methods-get_reconcile_profile_id) | `func get_reconcile_profile_id() -> StringName:` |
| 方法 | [`get_source_profile_id`](#member-gfsaveprofilereconcilelease-methods-get_source_profile_id) | `func get_source_profile_id() -> StringName:` |
| 方法 | [`get_target_profile_id`](#member-gfsaveprofilereconcilelease-methods-get_target_profile_id) | `func get_target_profile_id() -> StringName:` |
| 方法 | [`get_domain_id`](#member-gfsaveprofilereconcilelease-methods-get_domain_id) | `func get_domain_id() -> int:` |
| 方法 | [`get_domain_generation`](#member-gfsaveprofilereconcilelease-methods-get_domain_generation) | `func get_domain_generation() -> int:` |
| 方法 | [`get_epoch`](#member-gfsaveprofilereconcilelease-methods-get_epoch) | `func get_epoch() -> int:` |
| 方法 | [`get_storage_request_ids`](#member-gfsaveprofilereconcilelease-methods-get_storage_request_ids) | `func get_storage_request_ids() -> PackedInt64Array:` |
| 方法 | [`get_state`](#member-gfsaveprofilereconcilelease-methods-get_state) | `func get_state() -> StringName:` |
| 方法 | [`is_waiting`](#member-gfsaveprofilereconcilelease-methods-is_waiting) | `func is_waiting() -> bool:` |
| 方法 | [`is_ready`](#member-gfsaveprofilereconcilelease-methods-is_ready) | `func is_ready() -> bool:` |
| 方法 | [`is_terminal`](#member-gfsaveprofilereconcilelease-methods-is_terminal) | `func is_terminal() -> bool:` |
| 方法 | [`get_settlement_evidence`](#member-gfsaveprofilereconcilelease-methods-get_settlement_evidence) | `func get_settlement_evidence() -> Dictionary:` |
| 方法 | [`get_resolution_evidence`](#member-gfsaveprofilereconcilelease-methods-get_resolution_evidence) | `func get_resolution_evidence() -> Dictionary:` |

## 信号

<a id="member-gfsaveprofilereconcilelease-signals-settled"></a>

### `settled`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal settled(lease: GFSaveProfileReconcileLease, state: StringName)
```

Lease 首次离开 waiting 时发出。 正常 late settlement 进入 ready；Utility 先释放则进入 disposed_unresolved。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 当前同一身份 Lease。 |
| `state` | \`STATE_READY\` 或 \`STATE_DISPOSED_UNRESOLVED\`。 |

## 常量

<a id="member-gfsaveprofilereconcilelease-constants-state_waiting"></a>

### `STATE_WAITING`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_WAITING: StringName = &"waiting"
```

仍在等待至少一个底层请求 late-settle。

<a id="member-gfsaveprofilereconcilelease-constants-state_ready"></a>

### `STATE_READY`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_READY: StringName = &"ready"
```

已取得有界 settlement evidence，可以开始显式对账。

<a id="member-gfsaveprofilereconcilelease-constants-state_reconciling"></a>

### `STATE_RECONCILING`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_RECONCILING: StringName = &"reconciling"
```

一个 reconcile 操作已经接管 Lease。

<a id="member-gfsaveprofilereconcilelease-constants-state_resolved"></a>

### `STATE_RESOLVED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_RESOLVED: StringName = &"resolved"
```

对账已经完成，Provider domain 围栏可以释放。

<a id="member-gfsaveprofilereconcilelease-constants-state_disposed_unresolved"></a>

### `STATE_DISPOSED_UNRESOLVED`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const STATE_DISPOSED_UNRESOLVED: StringName = &"disposed_unresolved"
```

Utility 已释放，但不确定副作用尚未完成对账。

## 方法

<a id="member-gfsaveprofilereconcilelease-methods-get_lease_id"></a>

### `get_lease_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_lease_id() -> int:
```

获取 Utility 生命周期内唯一的 Lease ID。

返回：正整数 Lease ID；未配置时为 0。

<a id="member-gfsaveprofilereconcilelease-methods-get_transaction_id"></a>

### `get_transaction_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_transaction_id() -> int:
```

获取产生当前 Lease 的事务 ID。

返回：正整数事务 ID；未配置时为 0。

<a id="member-gfsaveprofilereconcilelease-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_operation() -> StringName:
```

获取产生 outcome_unknown 的事务类型。

返回：`GFSaveProfileTransactionOperation.OPERATION_*` 常量之一。

<a id="member-gfsaveprofilereconcilelease-methods-get_reconcile_profile_id"></a>

### `get_reconcile_profile_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_reconcile_profile_id() -> StringName:
```

获取显式对账应重新读取的 Profile ID。

返回：非空 Profile ID。

<a id="member-gfsaveprofilereconcilelease-methods-get_source_profile_id"></a>

### `get_source_profile_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_source_profile_id() -> StringName:
```

获取原事务来源 Profile ID。

返回：来源 Profile ID；不适用时为空。

<a id="member-gfsaveprofilereconcilelease-methods-get_target_profile_id"></a>

### `get_target_profile_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_target_profile_id() -> StringName:
```

获取原事务目标 Profile ID。

返回：目标 Profile ID；不适用时为空。

<a id="member-gfsaveprofilereconcilelease-methods-get_domain_id"></a>

### `get_domain_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_domain_id() -> int:
```

获取运行时 Provider domain ID。

返回：Utility 生命周期内唯一的正整数 domain ID。

<a id="member-gfsaveprofilereconcilelease-methods-get_domain_generation"></a>

### `get_domain_generation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_domain_generation() -> int:
```

获取 Lease 创建时的 domain generation。

返回：正整数 domain generation。

<a id="member-gfsaveprofilereconcilelease-methods-get_epoch"></a>

### `get_epoch`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_epoch() -> int:
```

获取 Lease 创建时的 Utility lifecycle epoch。

返回：正整数 lifecycle epoch。

<a id="member-gfsaveprofilereconcilelease-methods-get_storage_request_ids"></a>

### `get_storage_request_ids`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_storage_request_ids() -> PackedInt64Array:
```

获取支撑 outcome_unknown 的底层 Storage 请求 ID。

返回：按发起顺序排列的正整数请求 ID。

<a id="member-gfsaveprofilereconcilelease-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_state() -> StringName:
```

获取当前 Lease 状态。

返回：`STATE_*` 常量之一。

<a id="member-gfsaveprofilereconcilelease-methods-is_waiting"></a>

### `is_waiting`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_waiting() -> bool:
```

检查 Lease 是否仍等待 late settlement。

返回：waiting 时返回 true。

<a id="member-gfsaveprofilereconcilelease-methods-is_ready"></a>

### `is_ready`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_ready() -> bool:
```

检查 Lease 是否可由 reconcile 操作接管。

返回：ready 时返回 true。

<a id="member-gfsaveprofilereconcilelease-methods-is_terminal"></a>

### `is_terminal`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_terminal() -> bool:
```

检查 Lease 是否已进入不可再对账的终态。

返回：resolved 或 disposed_unresolved 时返回 true。

<a id="member-gfsaveprofilereconcilelease-methods-get_settlement_evidence"></a>

### `get_settlement_evidence`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_settlement_evidence() -> Dictionary:
```

获取不含文档或 Provider payload 的 settlement evidence。

返回：有界 evidence 副本。

结构：

- `return`: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.

<a id="member-gfsaveprofilereconcilelease-methods-get_resolution_evidence"></a>

### `get_resolution_evidence`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_resolution_evidence() -> Dictionary:
```

获取成功对账后提交的最终证据。

返回：resolved 前为空；resolved 后返回有界 evidence 副本。

结构：

- `return`: Payload-free bounded Dictionary containing scalar, packed-array, Array, and Dictionary evidence only.
