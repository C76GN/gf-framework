# GFPlatformAdapter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/platform/gf_platform_adapter.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：协议与扩展点 (`protocol`)
- 首次版本：`9.0.0`

外部平台 adapter 协议。 Steam、微信小游戏、主机平台或自建平台实现应继承该类型，把具体 SDK 回调 转换为 GF 的上下文、生命周期事件和桥接结果。该基类不依赖任何平台 SDK。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`state_changed`](#member-gfplatformadapter-signals-state_changed) | `signal state_changed(previous_state: State, current_state: State)` |
| 信号 | [`context_changed`](#member-gfplatformadapter-signals-context_changed) | `signal context_changed(context: GFPlatformRuntimeContext)` |
| 信号 | [`lifecycle_event`](#member-gfplatformadapter-signals-lifecycle_event) | `signal lifecycle_event(event: GFPlatformLifecycleEvent)` |
| 信号 | [`activation_intent`](#member-gfplatformadapter-signals-activation_intent) | `signal activation_intent(intent: GFPlatformActivationIntent)` |
| 枚举 | [`State`](#member-gfplatformadapter-enums-state) | `enum State` |
| 方法 | [`configure`](#member-gfplatformadapter-methods-configure) | `func configure( adapter_id: StringName, platform_id: StringName, contract_ids: PackedStringArray, contract_descriptors: Array[GFPlatformContractDescriptor], initial_context: GFPlatformRuntimeContext = null ) -> bool:` |
| 方法 | [`get_adapter_id`](#member-gfplatformadapter-methods-get_adapter_id) | `func get_adapter_id() -> StringName:` |
| 方法 | [`get_platform_id`](#member-gfplatformadapter-methods-get_platform_id) | `func get_platform_id() -> StringName:` |
| 方法 | [`get_contract_ids`](#member-gfplatformadapter-methods-get_contract_ids) | `func get_contract_ids() -> PackedStringArray:` |
| 方法 | [`get_contract_descriptors`](#member-gfplatformadapter-methods-get_contract_descriptors) | `func get_contract_descriptors() -> Array[GFPlatformContractDescriptor]:` |
| 方法 | [`get_contract_descriptor`](#member-gfplatformadapter-methods-get_contract_descriptor) | `func get_contract_descriptor(contract_id: StringName) -> GFPlatformContractDescriptor:` |
| 方法 | [`supports_contract`](#member-gfplatformadapter-methods-supports_contract) | `func supports_contract(contract_id: StringName) -> bool:` |
| 方法 | [`get_state`](#member-gfplatformadapter-methods-get_state) | `func get_state() -> State:` |
| 方法 | [`is_ready`](#member-gfplatformadapter-methods-is_ready) | `func is_ready() -> bool:` |
| 方法 | [`initialize`](#member-gfplatformadapter-methods-initialize) | `func initialize(options: Dictionary = {}) -> GFAsyncCompletion:` |
| 方法 | [`get_context`](#member-gfplatformadapter-methods-get_context) | `func get_context() -> GFPlatformRuntimeContext:` |
| 方法 | [`invoke`](#member-gfplatformadapter-methods-invoke) | `func invoke(request: GFPlatformBridgeRequest) -> GFPlatformRequestHandle:` |
| 方法 | [`poll`](#member-gfplatformadapter-methods-poll) | `func poll(delta: float) -> void:` |
| 方法 | [`shutdown`](#member-gfplatformadapter-methods-shutdown) | `func shutdown() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfplatformadapter-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_initialize`](#member-gfplatformadapter-methods-_initialize) | `func _initialize(_options: Dictionary) -> void:` |
| 方法 | [`_dispatch`](#member-gfplatformadapter-methods-_dispatch) | `func _dispatch(_request: GFPlatformBridgeRequest, _handle: GFPlatformRequestHandle) -> bool:` |
| 方法 | [`_poll`](#member-gfplatformadapter-methods-_poll) | `func _poll(_delta: float) -> void:` |
| 方法 | [`_cancel_request`](#member-gfplatformadapter-methods-_cancel_request) | `func _cancel_request(_handle: GFPlatformRequestHandle, _reason: StringName) -> void:` |
| 方法 | [`_release_request`](#member-gfplatformadapter-methods-_release_request) | `func _release_request(handle: GFPlatformRequestHandle) -> bool:` |
| 方法 | [`_shutdown`](#member-gfplatformadapter-methods-_shutdown) | `func _shutdown() -> void:` |
| 方法 | [`_complete_initialization`](#member-gfplatformadapter-methods-_complete_initialization) | `func _complete_initialization(context: GFPlatformRuntimeContext) -> bool:` |
| 方法 | [`_fail_initialization`](#member-gfplatformadapter-methods-_fail_initialization) | `func _fail_initialization(error: String, metadata: Dictionary = {}) -> bool:` |
| 方法 | [`_publish_context`](#member-gfplatformadapter-methods-_publish_context) | `func _publish_context(context: GFPlatformRuntimeContext) -> bool:` |
| 方法 | [`_publish_lifecycle_event`](#member-gfplatformadapter-methods-_publish_lifecycle_event) | `func _publish_lifecycle_event(event: GFPlatformLifecycleEvent) -> bool:` |
| 方法 | [`_publish_activation_intent`](#member-gfplatformadapter-methods-_publish_activation_intent) | `func _publish_activation_intent(intent: GFPlatformActivationIntent) -> bool:` |
| 方法 | [`_succeed_request`](#member-gfplatformadapter-methods-_succeed_request) | `func _succeed_request( handle: GFPlatformRequestHandle, value: Variant = null, status: StringName = &"ok", metadata: Dictionary = {} ) -> bool:` |
| 方法 | [`_fail_request`](#member-gfplatformadapter-methods-_fail_request) | `func _fail_request( handle: GFPlatformRequestHandle, status: StringName, error: String, metadata: Dictionary = {} ) -> bool:` |

## 信号

<a id="member-gfplatformadapter-signals-state_changed"></a>

### `state_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal state_changed(previous_state: State, current_state: State)
```

Adapter 状态变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `previous_state` | 变化前状态。 |
| `current_state` | 变化后状态。 |

<a id="member-gfplatformadapter-signals-context_changed"></a>

### `context_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal context_changed(context: GFPlatformRuntimeContext)
```

平台运行时上下文变化后发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 新上下文副本。 |

<a id="member-gfplatformadapter-signals-lifecycle_event"></a>

### `lifecycle_event`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal lifecycle_event(event: GFPlatformLifecycleEvent)
```

收到平台生命周期事件后发出。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 生命周期事件副本。 |

<a id="member-gfplatformadapter-signals-activation_intent"></a>

### `activation_intent`

- API：`public`
- 首次版本：`unreleased`

```gdscript
signal activation_intent(intent: GFPlatformActivationIntent)
```

收到平台激活入口后发出。

参数：

| 名称 | 说明 |
|---|---|
| `intent` | 已规范化的激活意图副本。 |

## 枚举

<a id="member-gfplatformadapter-enums-state"></a>

### `State`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
enum State {
	## 尚未初始化。
	CREATED,
	## 正在执行 adapter 初始化。
	INITIALIZING,
	## 可接受平台请求。
	READY,
	## 初始化失败。
	FAILED,
	## 已关闭且不可重新使用。
	SHUTDOWN,
}
```

Adapter 生命周期状态。

## 方法

<a id="member-gfplatformadapter-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func configure( adapter_id: StringName, platform_id: StringName, contract_ids: PackedStringArray, contract_descriptors: Array[GFPlatformContractDescriptor], initial_context: GFPlatformRuntimeContext = null ) -> bool:
```

配置 adapter 身份和支持的桥接契约。 配置只允许在 CREATED 状态执行，防止运行期间改变路由身份。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter 稳定标识。 |
| `platform_id` | 平台稳定标识。 |
| `contract_ids` | 支持的桥接契约 ID。 |
| `contract_descriptors` | 平台契约描述符；必须与 contract_ids 一一对应。 |
| `initial_context` | 可选初始上下文。 |

返回：配置成功返回 true。

结构：

- `contract_descriptors`: Array[GFPlatformContractDescriptor] complete contract descriptors.

<a id="member-gfplatformadapter-methods-get_adapter_id"></a>

### `get_adapter_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_adapter_id() -> StringName:
```

获取 adapter ID。

返回：Adapter ID。

<a id="member-gfplatformadapter-methods-get_platform_id"></a>

### `get_platform_id`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_platform_id() -> StringName:
```

获取平台 ID。

返回：平台 ID。

<a id="member-gfplatformadapter-methods-get_contract_ids"></a>

### `get_contract_ids`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_contract_ids() -> PackedStringArray:
```

获取支持的桥接契约 ID 副本。

返回：排序去重后的契约 ID。

<a id="member-gfplatformadapter-methods-get_contract_descriptors"></a>

### `get_contract_descriptors`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_contract_descriptors() -> Array[GFPlatformContractDescriptor]:
```

获取声明的契约描述符副本。

返回：按 contract_id 排序的描述符副本。

结构：

- `return`: Array[GFPlatformContractDescriptor] declared platform contracts.

<a id="member-gfplatformadapter-methods-get_contract_descriptor"></a>

### `get_contract_descriptor`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_contract_descriptor(contract_id: StringName) -> GFPlatformContractDescriptor:
```

获取一个契约描述符副本。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 契约 ID。 |

返回：找到时返回描述符副本，否则返回 null。

<a id="member-gfplatformadapter-methods-supports_contract"></a>

### `supports_contract`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func supports_contract(contract_id: StringName) -> bool:
```

检查 adapter 是否支持桥接契约。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 桥接契约 ID。 |

返回：已声明支持时返回 true。

<a id="member-gfplatformadapter-methods-get_state"></a>

### `get_state`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_state() -> State:
```

获取当前状态。

返回：Adapter 状态。

<a id="member-gfplatformadapter-methods-is_ready"></a>

### `is_ready`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func is_ready() -> bool:
```

检查 adapter 是否可接受请求。

返回：READY 状态返回 true。

<a id="member-gfplatformadapter-methods-initialize"></a>

### `initialize`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func initialize(options: Dictionary = {}) -> GFAsyncCompletion:
```

初始化 adapter。 同一次初始化期间重复调用会返回同一个 completion；READY 状态返回立即成功的 completion。FAILED 或 SHUTDOWN 状态不会隐式重试。

参数：

| 名称 | 说明 |
|---|---|
| `options` | Adapter 定义的初始化选项。 |

返回：初始化完成源，成功结果为 `GFPlatformRuntimeContext`。

结构：

- `options`: Dictionary adapter-defined initialization options.

<a id="member-gfplatformadapter-methods-get_context"></a>

### `get_context`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_context() -> GFPlatformRuntimeContext:
```

获取运行时上下文副本。

返回：平台运行时上下文副本。

<a id="member-gfplatformadapter-methods-invoke"></a>

### `invoke`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func invoke(request: GFPlatformBridgeRequest) -> GFPlatformRequestHandle:
```

发起桥接请求。 该入口统一做状态、请求身份和契约支持检查，具体 adapter 只重写 `_dispatch`。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 平台桥接请求。 |

返回：一次性请求句柄。

<a id="member-gfplatformadapter-methods-poll"></a>

### `poll`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func poll(delta: float) -> void:
```

推进需要 callback pump 的平台 SDK。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 未受游戏暂停和时间缩放影响的帧间隔。 |

<a id="member-gfplatformadapter-methods-shutdown"></a>

### `shutdown`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func shutdown() -> void:
```

关闭 adapter 并释放平台资源。 SHUTDOWN 为终态；需要重新连接时应创建新 adapter 实例。

<a id="member-gfplatformadapter-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取 adapter 调试快照。

返回：Adapter 身份、状态、契约与脱敏上下文摘要。

结构：

- `return`: Dictionary with adapter identity, state, contracts, and redacted context summary.

<a id="member-gfplatformadapter-methods-_initialize"></a>

### `_initialize`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _initialize(_options: Dictionary) -> void:
```

执行平台初始化。 异步实现应在回调中调用 `_complete_initialization` 或 `_fail_initialization`； 基类实现立即使用当前上下文完成。

参数：

| 名称 | 说明 |
|---|---|
| `_options` | Adapter 初始化选项。 |

结构：

- `_options`: Dictionary adapter-defined initialization options.

<a id="member-gfplatformadapter-methods-_dispatch"></a>

### `_dispatch`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _dispatch(_request: GFPlatformBridgeRequest, _handle: GFPlatformRequestHandle) -> bool:
```

派发平台请求。 实现可同步或异步调用 `_succeed_request` / `_fail_request`。返回 false 表示请求 未被接受，基类会生成 dispatch_rejected 终态。

参数：

| 名称 | 说明 |
|---|---|
| `_request` | 请求副本。 |
| `_handle` | 由基类拥有的请求句柄。 |

返回：请求被接受时返回 true。

<a id="member-gfplatformadapter-methods-_poll"></a>

### `_poll`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _poll(_delta: float) -> void:
```

推进底层平台 callback pump。

参数：

| 名称 | 说明 |
|---|---|
| `_delta` | 未缩放帧间隔。 |

<a id="member-gfplatformadapter-methods-_cancel_request"></a>

### `_cancel_request`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _cancel_request(_handle: GFPlatformRequestHandle, _reason: StringName) -> void:
```

处理请求取消或超时通知。

参数：

| 名称 | 说明 |
|---|---|
| `_handle` | 已进入取消或超时终态的句柄。 |
| `_reason` | 取消原因。 |

<a id="member-gfplatformadapter-methods-_release_request"></a>

### `_release_request`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _release_request(handle: GFPlatformRequestHandle) -> bool:
```

确认底层 Provider 调用已经停止并释放请求租约。 本地取消和超时只结束调用方 Handle，不代表不可取消或异步取消的 SDK 调用已经 停止。Adapter 应在 Provider 确认取消后调用本方法；迟到成功或失败回调通过 `_succeed_request` / `_fail_request` 也会自动释放租约。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 已停止底层工作的请求句柄。 |

返回：当前 Adapter 仍持有该请求租约并已释放时返回 true。

<a id="member-gfplatformadapter-methods-_shutdown"></a>

### `_shutdown`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _shutdown() -> void:
```

释放底层平台资源。

<a id="member-gfplatformadapter-methods-_complete_initialization"></a>

### `_complete_initialization`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _complete_initialization(context: GFPlatformRuntimeContext) -> bool:
```

完成 adapter 初始化。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 已验证的平台上下文。 |

返回：首次成功完成返回 true。

<a id="member-gfplatformadapter-methods-_fail_initialization"></a>

### `_fail_initialization`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _fail_initialization(error: String, metadata: Dictionary = {}) -> bool:
```

标记 adapter 初始化失败。

参数：

| 名称 | 说明 |
|---|---|
| `error` | 失败说明。 |
| `metadata` | Adapter 定义的失败元数据。 |

返回：首次失败完成返回 true。

结构：

- `metadata`: Dictionary adapter-defined initialization failure metadata.

<a id="member-gfplatformadapter-methods-_publish_context"></a>

### `_publish_context`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _publish_context(context: GFPlatformRuntimeContext) -> bool:
```

发布更新后的平台上下文。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 新上下文。 |

返回：身份匹配且发布成功返回 true。

<a id="member-gfplatformadapter-methods-_publish_lifecycle_event"></a>

### `_publish_lifecycle_event`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _publish_lifecycle_event(event: GFPlatformLifecycleEvent) -> bool:
```

发布平台生命周期事件。 基类会覆盖 adapter 提供的 sequence，确保每个 adapter 的事件严格单调。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 生命周期事件。 |

返回：事件有效并已发布时返回 true。

<a id="member-gfplatformadapter-methods-_publish_activation_intent"></a>

### `_publish_activation_intent`

- API：`protected`
- 首次版本：`unreleased`

```gdscript
func _publish_activation_intent(intent: GFPlatformActivationIntent) -> bool:
```

发布平台激活意图。 基类补齐并校验 adapter/platform 身份和单调时间戳。Intent ID 必须由 adapter 根据平台事件生成，确保重放回调可以去重。

参数：

| 名称 | 说明 |
|---|---|
| `intent` | 平台激活意图。 |

返回：意图有效并已发布时返回 true。

<a id="member-gfplatformadapter-methods-_succeed_request"></a>

### `_succeed_request`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _succeed_request( handle: GFPlatformRequestHandle, value: Variant = null, status: StringName = &"ok", metadata: Dictionary = {} ) -> bool:
```

以成功结果完成请求。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待完成句柄。 |
| `value` | Adapter 返回值。 |
| `status` | 成功状态。 |
| `metadata` | Adapter 结果元数据。 |

返回：首次完成成功返回 true。

结构：

- `value`: Adapter-defined result value.
- `metadata`: Dictionary adapter-defined result metadata.

<a id="member-gfplatformadapter-methods-_fail_request"></a>

### `_fail_request`

- API：`protected`
- 首次版本：`9.0.0`

```gdscript
func _fail_request( handle: GFPlatformRequestHandle, status: StringName, error: String, metadata: Dictionary = {} ) -> bool:
```

以失败结果完成请求。

参数：

| 名称 | 说明 |
|---|---|
| `handle` | 待完成句柄。 |
| `status` | 稳定失败状态。 |
| `error` | 失败说明。 |
| `metadata` | Adapter 失败元数据。 |

返回：首次完成成功返回 true。

结构：

- `metadata`: Dictionary adapter-defined failure metadata.
