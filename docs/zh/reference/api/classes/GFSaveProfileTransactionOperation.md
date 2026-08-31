# GFSaveProfileTransactionOperation

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_transaction_operation.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`11.0.0`

Profile 身份与持久化事务的异步句柄。 句柄由 Save Profile 事务协调器完成一次且只完成一次。调用方可在连接信号前 检查 `is_completed()`，避免同步拒绝或立即终态造成竞态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`completed`](#member-gfsaveprofiletransactionoperation-signals-completed) | `signal completed(result: GFSaveProfileTransactionResult)` |
| 常量 | [`OPERATION_ACTIVATE`](#member-gfsaveprofiletransactionoperation-constants-operation_activate) | `const OPERATION_ACTIVATE: StringName = &"activate"` |
| 常量 | [`OPERATION_SWITCH`](#member-gfsaveprofiletransactionoperation-constants-operation_switch) | `const OPERATION_SWITCH: StringName = &"switch"` |
| 常量 | [`OPERATION_BOOTSTRAP`](#member-gfsaveprofiletransactionoperation-constants-operation_bootstrap) | `const OPERATION_BOOTSTRAP: StringName = &"bootstrap"` |
| 常量 | [`OPERATION_ADOPT`](#member-gfsaveprofiletransactionoperation-constants-operation_adopt) | `const OPERATION_ADOPT: StringName = &"adopt"` |
| 常量 | [`OPERATION_BOOTSTRAP_AND_SWITCH`](#member-gfsaveprofiletransactionoperation-constants-operation_bootstrap_and_switch) | `const OPERATION_BOOTSTRAP_AND_SWITCH: StringName = &"bootstrap_and_switch"` |
| 常量 | [`OPERATION_ADOPT_AND_SWITCH`](#member-gfsaveprofiletransactionoperation-constants-operation_adopt_and_switch) | `const OPERATION_ADOPT_AND_SWITCH: StringName = &"adopt_and_switch"` |
| 常量 | [`OPERATION_MUTATE_AND_PERSIST`](#member-gfsaveprofiletransactionoperation-constants-operation_mutate_and_persist) | `const OPERATION_MUTATE_AND_PERSIST: StringName = &"mutate_and_persist"` |
| 常量 | [`OPERATION_RECONCILE`](#member-gfsaveprofiletransactionoperation-constants-operation_reconcile) | `const OPERATION_RECONCILE: StringName = &"reconcile"` |
| 方法 | [`get_operation`](#member-gfsaveprofiletransactionoperation-methods-get_operation) | `func get_operation() -> StringName:` |
| 方法 | [`get_transaction_id`](#member-gfsaveprofiletransactionoperation-methods-get_transaction_id) | `func get_transaction_id() -> int:` |
| 方法 | [`get_source_profile_id`](#member-gfsaveprofiletransactionoperation-methods-get_source_profile_id) | `func get_source_profile_id() -> StringName:` |
| 方法 | [`get_target_profile_id`](#member-gfsaveprofiletransactionoperation-methods-get_target_profile_id) | `func get_target_profile_id() -> StringName:` |
| 方法 | [`is_pending`](#member-gfsaveprofiletransactionoperation-methods-is_pending) | `func is_pending() -> bool:` |
| 方法 | [`is_running`](#member-gfsaveprofiletransactionoperation-methods-is_running) | `func is_running() -> bool:` |
| 方法 | [`is_completed`](#member-gfsaveprofiletransactionoperation-methods-is_completed) | `func is_completed() -> bool:` |
| 方法 | [`get_result`](#member-gfsaveprofiletransactionoperation-methods-get_result) | `func get_result() -> GFSaveProfileTransactionResult:` |

## 信号

<a id="member-gfsaveprofiletransactionoperation-signals-completed"></a>

### `completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
signal completed(result: GFSaveProfileTransactionResult)
```

事务进入终态时发出一次。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不包含 Provider payload 的隔离终态结果。 |

## 常量

<a id="member-gfsaveprofiletransactionoperation-constants-operation_activate"></a>

### `OPERATION_ACTIVATE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_ACTIVATE: StringName = &"activate"
```

激活已存在的 Profile 存档。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_switch"></a>

### `OPERATION_SWITCH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_SWITCH: StringName = &"switch"
```

从当前活跃 Profile 事务切换到另一个已存在 Profile。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_bootstrap"></a>

### `OPERATION_BOOTSTRAP`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_BOOTSTRAP: StringName = &"bootstrap"
```

用当前 Provider 状态显式创建缺失 Profile 并激活。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_adopt"></a>

### `OPERATION_ADOPT`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_ADOPT: StringName = &"adopt"
```

显式采用当前 Provider 状态作为恢复后的活跃 Profile。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_bootstrap_and_switch"></a>

### `OPERATION_BOOTSTRAP_AND_SWITCH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_BOOTSTRAP_AND_SWITCH: StringName = &"bootstrap_and_switch"
```

从活动来源重新 flush 后，以当前 Provider 状态创建缺失目标并原子切换。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_adopt_and_switch"></a>

### `OPERATION_ADOPT_AND_SWITCH`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_ADOPT_AND_SWITCH: StringName = &"adopt_and_switch"
```

从活动来源重新 flush 后，以当前 Provider 状态覆盖损坏目标并原子切换。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_mutate_and_persist"></a>

### `OPERATION_MUTATE_AND_PERSIST`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_MUTATE_AND_PERSIST: StringName = &"mutate_and_persist"
```

应用完整候选 section 并持久化。

<a id="member-gfsaveprofiletransactionoperation-constants-operation_reconcile"></a>

### `OPERATION_RECONCILE`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
const OPERATION_RECONCILE: StringName = &"reconcile"
```

对账此前 outcome_unknown 的事务。

## 方法

<a id="member-gfsaveprofiletransactionoperation-methods-get_operation"></a>

### `get_operation`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_operation() -> StringName:
```

获取事务类型。

返回：`OPERATION_*` 常量之一。

<a id="member-gfsaveprofiletransactionoperation-methods-get_transaction_id"></a>

### `get_transaction_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_transaction_id() -> int:
```

获取 Utility 生命周期内唯一的事务 ID。

返回：正整数事务 ID；尚未配置时为 0。

<a id="member-gfsaveprofiletransactionoperation-methods-get_source_profile_id"></a>

### `get_source_profile_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_source_profile_id() -> StringName:
```

获取事务来源 Profile ID。 activate、bootstrap 与 adopt 没有来源身份；switch、bootstrap/adopt-and-switch、 mutate-and-persist 和 reconcile 使用当前受管 Profile 作为来源。

返回：来源 Profile ID；不适用时为空。

<a id="member-gfsaveprofiletransactionoperation-methods-get_target_profile_id"></a>

### `get_target_profile_id`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_target_profile_id() -> StringName:
```

获取事务目标 Profile ID。

返回：目标 Profile ID；不适用时为空。

<a id="member-gfsaveprofiletransactionoperation-methods-is_pending"></a>

### `is_pending`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_pending() -> bool:
```

检查事务是否等待调度。

返回：尚未运行或完成时返回 true。

<a id="member-gfsaveprofiletransactionoperation-methods-is_running"></a>

### `is_running`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_running() -> bool:
```

检查事务是否正在运行。

返回：已启动但无终态时返回 true。

<a id="member-gfsaveprofiletransactionoperation-methods-is_completed"></a>

### `is_completed`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func is_completed() -> bool:
```

检查事务是否已有终态。

返回：已完成时返回 true。

<a id="member-gfsaveprofiletransactionoperation-methods-get_result"></a>

### `get_result`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
func get_result() -> GFSaveProfileTransactionResult:
```

获取终态结果副本。 结果副本中的 Recovery/Reconcile Lease 保留原始句柄身份，其他集合均隔离复制。

返回：已完成结果；等待中返回 null。
