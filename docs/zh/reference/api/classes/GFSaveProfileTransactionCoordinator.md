# GFSaveProfileTransactionCoordinator

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/profile/gf_save_profile_transaction_coordinator.gd`
- 模块：`Save`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

活动 Profile 身份与跨 Profile 事务协调器。 Coordinator 在完全相同且同序的 Provider 实例拓扑上建立独立 domain，委托 `GFSaveProfileUtility` 完成 generation、Storage IO、重试与 detached settlement。 它不解释业务 payload，也不拥有项目的身份到路径、云同步或恢复选择。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`active_profile_changed`](#member-gfsaveprofiletransactioncoordinator-signals-active_profile_changed) | `signal active_profile_changed( previous_profile_id: StringName, current_profile_id: StringName )` |
| 信号 | [`transaction_completed`](#member-gfsaveprofiletransactioncoordinator-signals-transaction_completed) | `signal transaction_completed(result: GFSaveProfileTransactionResult)` |
| 常量 | [`DOMAIN_STATE_INACTIVE`](#member-gfsaveprofiletransactioncoordinator-constants-domain_state_inactive) | `const DOMAIN_STATE_INACTIVE: StringName = &"inactive"` |
| 常量 | [`DOMAIN_STATE_ACTIVE`](#member-gfsaveprofiletransactioncoordinator-constants-domain_state_active) | `const DOMAIN_STATE_ACTIVE: StringName = &"active"` |
| 常量 | [`DOMAIN_STATE_TRANSACTING`](#member-gfsaveprofiletransactioncoordinator-constants-domain_state_transacting) | `const DOMAIN_STATE_TRANSACTING: StringName = &"transacting"` |
| 常量 | [`DOMAIN_STATE_RECONCILIATION_REQUIRED`](#member-gfsaveprofiletransactioncoordinator-constants-domain_state_reconciliation_required) | `const DOMAIN_STATE_RECONCILIATION_REQUIRED: StringName = &"reconciliation_required"` |
| 常量 | [`DOMAIN_STATE_DISPOSED`](#member-gfsaveprofiletransactioncoordinator-constants-domain_state_disposed) | `const DOMAIN_STATE_DISPOSED: StringName = &"disposed"` |
| 方法 | [`get_required_utilities`](#member-gfsaveprofiletransactioncoordinator-methods-get_required_utilities) | `func get_required_utilities() -> Array[Script]:` |
| 方法 | [`ready`](#member-gfsaveprofiletransactioncoordinator-methods-ready) | `func ready() -> void:` |
| 方法 | [`begin_activation`](#member-gfsaveprofiletransactioncoordinator-methods-begin_activation) | `func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`begin_quiesce`](#member-gfsaveprofiletransactioncoordinator-methods-begin_quiesce) | `func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`tick`](#member-gfsaveprofiletransactioncoordinator-methods-tick) | `func tick(_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfsaveprofiletransactioncoordinator-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`release_dependencies`](#member-gfsaveprofiletransactioncoordinator-methods-release_dependencies) | `func release_dependencies() -> void:` |
| 方法 | [`setup`](#member-gfsaveprofiletransactioncoordinator-methods-setup) | `func setup( profile_utility: GFSaveProfileUtility ) -> GFSaveProfileTransactionCoordinator:` |
| 方法 | [`register_profile`](#member-gfsaveprofiletransactioncoordinator-methods-register_profile) | `func register_profile( profile: GFSaveProfile, migrations: GFSaveMigrationRegistry = null ) -> Dictionary:` |
| 方法 | [`unregister_profile`](#member-gfsaveprofiletransactioncoordinator-methods-unregister_profile) | `func unregister_profile(profile_id: StringName) -> bool:` |
| 方法 | [`get_active_profile_id`](#member-gfsaveprofiletransactioncoordinator-methods-get_active_profile_id) | `func get_active_profile_id(profile_id: StringName) -> StringName:` |
| 方法 | [`get_domain_state_snapshot`](#member-gfsaveprofiletransactioncoordinator-methods-get_domain_state_snapshot) | `func get_domain_state_snapshot(profile_id: StringName) -> Dictionary:` |
| 方法 | [`activate_profile`](#member-gfsaveprofiletransactioncoordinator-methods-activate_profile) | `func activate_profile( profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileTransactionOperation:` |
| 方法 | [`switch_profile`](#member-gfsaveprofiletransactioncoordinator-methods-switch_profile) | `func switch_profile( target_profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileTransactionOperation:` |
| 方法 | [`bootstrap_profile`](#member-gfsaveprofiletransactioncoordinator-methods-bootstrap_profile) | `func bootstrap_profile( lease: GFSaveProfileRecoveryLease, request: GFSaveProfileRequest = null ) -> GFSaveProfileTransactionOperation:` |
| 方法 | [`adopt_profile`](#member-gfsaveprofiletransactioncoordinator-methods-adopt_profile) | `func adopt_profile( lease: GFSaveProfileRecoveryLease, request: GFSaveProfileRequest = null ) -> GFSaveProfileTransactionOperation:` |
| 方法 | [`mutate_and_persist`](#member-gfsaveprofiletransactioncoordinator-methods-mutate_and_persist) | `func mutate_and_persist( profile_id: StringName, request: GFSaveProfileMutationRequest ) -> GFSaveProfileTransactionOperation:` |
| 方法 | [`reconcile_profile`](#member-gfsaveprofiletransactioncoordinator-methods-reconcile_profile) | `func reconcile_profile( lease: GFSaveProfileReconcileLease, request: GFSaveProfileReconcileRequest = null ) -> GFSaveProfileTransactionOperation:` |

## 信号

<a id="member-gfsaveprofiletransactioncoordinator-signals-active_profile_changed"></a>

### `active_profile_changed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal active_profile_changed( previous_profile_id: StringName, current_profile_id: StringName )
```

活动 Profile 身份完成原子提交后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_profile_id` | 提交前活动 Profile；首次激活时为空。 |
| `current_profile_id` | 提交后活动 Profile。 |

<a id="member-gfsaveprofiletransactioncoordinator-signals-transaction_completed"></a>

### `transaction_completed`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal transaction_completed(result: GFSaveProfileTransactionResult)
```

任一事务进入稳定终态时发出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | 不包含持久化 payload 的隔离结果。 |

## 常量

<a id="member-gfsaveprofiletransactioncoordinator-constants-domain_state_inactive"></a>

### `DOMAIN_STATE_INACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DOMAIN_STATE_INACTIVE: StringName = &"inactive"
```

Domain 尚未建立活动身份。

<a id="member-gfsaveprofiletransactioncoordinator-constants-domain_state_active"></a>

### `DOMAIN_STATE_ACTIVE`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DOMAIN_STATE_ACTIVE: StringName = &"active"
```

Domain 已建立一个可直接 save/flush 的活动身份。

<a id="member-gfsaveprofiletransactioncoordinator-constants-domain_state_transacting"></a>

### `DOMAIN_STATE_TRANSACTING`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DOMAIN_STATE_TRANSACTING: StringName = &"transacting"
```

Domain 正在执行一个事务。

<a id="member-gfsaveprofiletransactioncoordinator-constants-domain_state_reconciliation_required"></a>

### `DOMAIN_STATE_RECONCILIATION_REQUIRED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DOMAIN_STATE_RECONCILIATION_REQUIRED: StringName = &"reconciliation_required"
```

Domain 被 outcome_unknown 或显式故障围栏占用，必须对账。

<a id="member-gfsaveprofiletransactioncoordinator-constants-domain_state_disposed"></a>

### `DOMAIN_STATE_DISPOSED`

- API：`public`
- 首次版本：`unreleased`

```gdscript
const DOMAIN_STATE_DISPOSED: StringName = &"disposed"
```

Coordinator 已释放。

## 方法

<a id="member-gfsaveprofiletransactioncoordinator-methods-get_required_utilities"></a>

### `get_required_utilities`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_required_utilities() -> Array[Script]:
```

声明底层 Save Profile Utility 依赖。

返回：仅包含 `GFSaveProfileUtility`。

<a id="member-gfsaveprofiletransactioncoordinator-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func ready() -> void:
```

在架构 ready 阶段采用已注册的 Profile Utility。

<a id="member-gfsaveprofiletransactioncoordinator-methods-begin_activation"></a>

### `begin_activation`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

开放事务准入；底层 Utility 不可用时失败。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 当前激活阶段的取消作用域。 |

返回：一次性激活完成源。

<a id="member-gfsaveprofiletransactioncoordinator-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
```

关闭新事务准入，并等待已接纳事务与 reconcile fence 收敛。

参数：

| 名称 | 说明 |
|---|---|
| `scope` | 当前静默阶段的取消作用域。 |

返回：全部 domain 可安全关闭时完成的一次性完成源。

<a id="member-gfsaveprofiletransactioncoordinator-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(_delta: float) -> void:
```

推进已接纳的同步 Provider mutation 阶段。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 未使用；底层 IO 由 Profile Utility 推进。 |

<a id="member-gfsaveprofiletransactioncoordinator-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

强制结束未完成事务并释放全部 manager capability。

<a id="member-gfsaveprofiletransactioncoordinator-methods-release_dependencies"></a>

### `release_dependencies`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func release_dependencies() -> void:
```

释放架构注入依赖。

<a id="member-gfsaveprofiletransactioncoordinator-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func setup( profile_utility: GFSaveProfileUtility ) -> GFSaveProfileTransactionCoordinator:
```

显式注入底层 Profile Utility，供 standalone 场景与测试使用。

参数：

| 名称 | 说明 |
|---|---|
| `profile_utility` | 已配置的底层 Profile Utility。 |

返回：当前 Coordinator；输入无效或已有受管 Profile 时返回 null。

<a id="member-gfsaveprofiletransactioncoordinator-methods-register_profile"></a>

### `register_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func register_profile( profile: GFSaveProfile, migrations: GFSaveMigrationRegistry = null ) -> Dictionary:
```

注册并声明一个受管 Profile。 完全相同且同序的 Provider 实例序列共享 domain；任意部分重叠或同实例异序 会在触碰底层注册前失败。

参数：

| 名称 | 说明 |
|---|---|
| `profile` | Profile 声明。 |
| `migrations` | 可选迁移注册表。 |

返回：底层注册报告，附加 managed 与 provider_domain_id 字段。

结构：

- `return`: GFValidationReportDictionary-compatible report with managed and provider_domain_id fields.

<a id="member-gfsaveprofiletransactioncoordinator-methods-unregister_profile"></a>

### `unregister_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func unregister_profile(profile_id: StringName) -> bool:
```

注销一个无活动身份、事务或 fence 的受管 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 受管 Profile ID。 |

返回：安全注销成功时返回 true。

<a id="member-gfsaveprofiletransactioncoordinator-methods-get_active_profile_id"></a>

### `get_active_profile_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_active_profile_id(profile_id: StringName) -> StringName:
```

获取指定受管 Profile 所在 domain 的活动身份。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 用于定位 Provider domain 的任一受管 Profile ID。 |

返回：活动 Profile ID；domain 未激活或 Profile 不存在时为空。

<a id="member-gfsaveprofiletransactioncoordinator-methods-get_domain_state_snapshot"></a>

### `get_domain_state_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_domain_state_snapshot(profile_id: StringName) -> Dictionary:
```

获取无载荷 domain 调试快照。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 用于定位 Provider domain 的任一受管 Profile ID。 |

返回：domain 状态、活动身份、generation、epoch 与事务/lease ID。

结构：

- `return`: Payload-free Dictionary with domain_id, state, active_profile_id, profile_ids, domain_generation, transaction_epoch, transaction_id, reconcile_lease_id, quiescing, and disposed fields.

<a id="member-gfsaveprofiletransactioncoordinator-methods-activate_profile"></a>

### `activate_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func activate_profile( profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileTransactionOperation:
```

严格读取一个已存在存档并建立首次活动身份。 missing/corrupt 不会应用低层 `ACTION_USE_CURRENT_STATE`；结果分别返回只能用于 `bootstrap_profile()` 或 `adopt_profile()` 的类型化 Recovery Lease。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 已注册受管 Profile ID。 |
| `context` | 迁移与 Provider apply 临时上下文。 |
| `metadata` | 仅写入外层事务结果的调用方元数据。 |

返回：类型化 activate 操作。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.
- `metadata`: Dictionary with caller-defined result metadata.

<a id="member-gfsaveprofiletransactioncoordinator-methods-switch_profile"></a>

### `switch_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func switch_profile( target_profile_id: StringName, context: Dictionary = {}, metadata: Dictionary = {} ) -> GFSaveProfileTransactionOperation:
```

从当前活动 Profile 原子切换到同一 Provider domain 的目标 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `target_profile_id` | 同一 domain 内的目标 Profile ID。 |
| `context` | 目标读取的迁移与 Provider 临时上下文。 |
| `metadata` | 仅写入外层事务结果的调用方元数据。 |

返回：类型化 switch 操作。

结构：

- `context`: Dictionary with caller-defined ephemeral operation data.
- `metadata`: Dictionary with caller-defined result metadata.

<a id="member-gfsaveprofiletransactioncoordinator-methods-bootstrap_profile"></a>

### `bootstrap_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func bootstrap_profile( lease: GFSaveProfileRecoveryLease, request: GFSaveProfileRequest = null ) -> GFSaveProfileTransactionOperation:
```

使用 activate 返回的 missing lease 创建存档并首次激活。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 尚未过期的 missing Recovery Lease。 |
| `request` | 当前 Provider 状态的保存请求；null 表示空元数据。 |

返回：类型化 bootstrap 操作；拒绝不会 claim lease 或 request。

<a id="member-gfsaveprofiletransactioncoordinator-methods-adopt_profile"></a>

### `adopt_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func adopt_profile( lease: GFSaveProfileRecoveryLease, request: GFSaveProfileRequest = null ) -> GFSaveProfileTransactionOperation:
```

使用 activate 返回的 corrupt lease 明确覆盖损坏存档并首次激活。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 尚未过期的 corrupt Recovery Lease。 |
| `request` | 当前 Provider 状态的保存请求；null 表示空元数据。 |

返回：类型化 adopt 操作；拒绝不会 claim lease 或 request。

<a id="member-gfsaveprofiletransactioncoordinator-methods-mutate_and_persist"></a>

### `mutate_and_persist`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func mutate_and_persist( profile_id: StringName, request: GFSaveProfileMutationRequest ) -> GFSaveProfileTransactionOperation:
```

事务化应用一个或多个完整 section replacement 并持久化活动 Profile。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 当前 domain 的活动 Profile ID。 |
| `request` | 一次性候选与元数据请求。 |

返回：类型化 mutate-and-persist 操作；边界拒绝不会 claim request。

<a id="member-gfsaveprofiletransactioncoordinator-methods-reconcile_profile"></a>

### `reconcile_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func reconcile_profile( lease: GFSaveProfileReconcileLease, request: GFSaveProfileReconcileRequest = null ) -> GFSaveProfileTransactionOperation:
```

在 late generation 证据收敛后严格重载 lease 指定 Profile 并解除 fence。 waiting lease 返回 `reconcile_pending`，且不 claim lease/request；调用方可在 `GFSaveProfileReconcileLease.settled` 后用同一 lease 与新请求重试。

参数：

| 名称 | 说明 |
|---|---|
| `lease` | 当前 Coordinator 持有的 Reconcile Lease。 |
| `request` | 一次性 reconcile context 与结果元数据。 |

返回：类型化 reconcile 操作。
