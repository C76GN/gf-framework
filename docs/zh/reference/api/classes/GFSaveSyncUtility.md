# GFSaveSyncUtility

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/sync/gf_save_sync_utility.gd`
- 模块：`Save`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`unreleased`

将通用版本同步组合到受管 Profile 事务。 prepare_profile() 必须早于目标 Profile 的加载或保存；同步使用最近已确认的完整 文档。业务修改须通过 Profile 保存或事务持久化，不从未登记的内存改动猜测代际。 账号会话冻结到一个 Profile、namespace、key 和 Transport；不自动合并游客数据。 Journal 与下载应用复用既有 Coordinator，网络等待期间不占用业务事务。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 方法 | [`dispose`](#member-gfsavesyncutility-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`begin_quiesce`](#member-gfsavesyncutility-methods-begin_quiesce) | `func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:` |
| 方法 | [`setup`](#member-gfsavesyncutility-methods-setup) | `func setup( profiles: GFSaveProfileUtility, coordinator: GFSaveProfileTransactionCoordinator, projection: GFSaveSyncProjection, clock: GFClock = null ) -> bool:` |
| 方法 | [`prepare_profile`](#member-gfsavesyncutility-methods-prepare_profile) | `func prepare_profile(profile_id: StringName) -> bool:` |
| 方法 | [`open_session`](#member-gfsavesyncutility-methods-open_session) | `func open_session( profile_id: StringName, record_namespace: String, record_key: String, transport: GFStorageSyncTransport ) -> bool:` |
| 方法 | [`close_session`](#member-gfsavesyncutility-methods-close_session) | `func close_session() -> void:` |
| 方法 | [`synchronize`](#member-gfsavesyncutility-methods-synchronize) | `func synchronize(operation_id: String, options: Dictionary = {}) -> GFAsyncCompletion:` |
| 方法 | [`recover_pending`](#member-gfsavesyncutility-methods-recover_pending) | `func recover_pending() -> GFAsyncCompletion:` |
| 方法 | [`cancel_wait`](#member-gfsavesyncutility-methods-cancel_wait) | `func cancel_wait() -> bool:` |
| 方法 | [`tick`](#member-gfsavesyncutility-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfsavesyncutility-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 方法

<a id="member-gfsavesyncutility-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func dispose() -> void:
```

关闭会话并释放借用的服务引用；不释放外部 Profile 与 Coordinator。

<a id="member-gfsavesyncutility-methods-begin_quiesce"></a>

### `begin_quiesce`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
```

停止接纳并结束当前观察，本地已准入事务仍由 Coordinator 排空。

参数：

| 名称 | 说明 |
|---|---|
| `_scope` | 架构静默作用域。 |

返回：已结束观察的完成源。

<a id="member-gfsavesyncutility-methods-setup"></a>

### `setup`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func setup( profiles: GFSaveProfileUtility, coordinator: GFSaveProfileTransactionCoordinator, projection: GFSaveSyncProjection, clock: GFClock = null ) -> bool:
```

一次性装配，服务的生命周期仍由原所有者管理。

参数：

| 名称 | 说明 |
|---|---|
| `profiles` | 本地存档服务。 |
| `coordinator` | 管理同一服务的事务协调器。 |
| `projection` | 项目显式投影，默认协议拒绝上传与下载。 |
| `clock` | 可选单调时钟。 |

返回：装配成功时为 true。

<a id="member-gfsavesyncutility-methods-prepare_profile"></a>

### `prepare_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func prepare_profile(profile_id: StringName) -> bool:
```

为已注册 Profile 开启完整同步快照；之后须成功加载或保存一次。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 已注册目标 Profile。 |

返回：开启成功时为 true；不会替项目创建或切换档位。

<a id="member-gfsavesyncutility-methods-open_session"></a>

### `open_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func open_session( profile_id: StringName, record_namespace: String, record_key: String, transport: GFStorageSyncTransport ) -> bool:
```

绑定一个活动 Profile 的冻结账号会话，成功才替换旧会话。 已有 checkpoint 的账号和记录键必须匹配。切换账号应使用隔离 Profile， 或由项目执行明确的数据迁移；此入口不会清除旧账号意图或合并游客文档。

参数：

| 名称 | 说明 |
|---|---|
| `profile_id` | 已准备、加载且当前活动的 Profile。 |
| `record_namespace` | 稳定账号命名空间。 |
| `record_key` | 远端记录键。 |
| `transport` | 已冻结该账号凭证的适配器。 |

返回：身份和快照均通过检查时为 true。

<a id="member-gfsavesyncutility-methods-close_session"></a>

### `close_session`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func close_session() -> void:
```

结束会话观察，撤销迟到回调的本地写入资格。

<a id="member-gfsavesyncutility-methods-synchronize"></a>

### `synchronize`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func synchronize(operation_id: String, options: Dictionary = {}) -> GFAsyncCompletion:
```

同步最近已确认的完整文档；不会悄悄捕获或保存未登记的运行状态。 完成源成功表示观察正常终结，业务结果必须检查返回记录的 ok/status。 取消完成源或 cancel_wait() 仅结束观察，不能撤销远端或已准入的本地事务。

参数：

| 名称 | 说明 |
|---|---|
| `operation_id` | 本次新提交的唯一 ID。 |
| `options` | 模式、冲突选择和阶段超时。 |

返回：主线程完成源；可能已经完成。

结构：

- `options`: Closed Dictionary with mode(push/pull/preview),resolution(report/local/remote),timeout_msec:int1..300000; defaults follow GFStorageSyncRequest.
- `return`: GFAsyncCompletion success result is closed Dictionary with ok:bool,status:StringName,sync_result:GFStorageSyncResult/null,local_result:GFSaveProfileTransactionResult/null,local_applied:bool,acknowledged_generation:int,requires_recovery:bool,error_kind:StringName,path:String,layer:StringName,limits:Dictionary,observed:Dictionary.

<a id="member-gfsavesyncutility-methods-recover_pending"></a>

### `recover_pending`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func recover_pending() -> GFAsyncCompletion:
```

读取当前账号的未解决意图并复用通用引擎查证，绝不隐式重发。

返回：与 synchronize() 相同的完成记录；本地处于对账阻断时须先完成 Profile 恢复。

结构：

- `return`: GFAsyncCompletion success result follows synchronize().

<a id="member-gfsavesyncutility-methods-cancel_wait"></a>

### `cancel_wait`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func cancel_wait() -> bool:
```

结束当前观察；已经准入的下载或 checkpoint 事务继续由协调器排空。

返回：有观察可结束时为 true。

<a id="member-gfsavesyncutility-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func tick(delta: float) -> void:
```

推进本地安全完成通知及通用引擎超时；不替调用方驱动借用的服务。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 帧间隔，远端超时仍使用单调时间。 |

<a id="member-gfsavesyncutility-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含身份与文档载荷的状态摘要。

返回：会话和观察计数。

结构：

- `return`: Dictionary with session_open:bool,observing:bool,local_pending_count:int,disposed:bool.
