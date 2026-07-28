# GFPlatformRuntime

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/platform/gf_platform_runtime.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`9.0.0`

平台 adapter 注册、路由与请求生命周期服务。 运行时允许多个外部 adapter 共存，但不会在同一契约存在多个候选时按注册顺序 猜测实现。项目必须通过 `set_contract_route` 显式消除歧义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`adapter_registered`](#member-gfplatformruntime-signals-adapter_registered) | `signal adapter_registered(adapter_id: StringName)` |
| 信号 | [`adapter_unregistered`](#member-gfplatformruntime-signals-adapter_unregistered) | `signal adapter_unregistered(adapter_id: StringName)` |
| 信号 | [`adapter_state_changed`](#member-gfplatformruntime-signals-adapter_state_changed) | `signal adapter_state_changed(adapter_id: StringName, previous_state: int, current_state: int)` |
| 信号 | [`context_changed`](#member-gfplatformruntime-signals-context_changed) | `signal context_changed(adapter_id: StringName, context: GFPlatformRuntimeContext)` |
| 信号 | [`lifecycle_event`](#member-gfplatformruntime-signals-lifecycle_event) | `signal lifecycle_event(adapter_id: StringName, event: GFPlatformLifecycleEvent)` |
| 信号 | [`activation_intent_received`](#member-gfplatformruntime-signals-activation_intent_received) | `signal activation_intent_received(adapter_id: StringName, intent: GFPlatformActivationIntent)` |
| 信号 | [`activation_intent_dropped`](#member-gfplatformruntime-signals-activation_intent_dropped) | `signal activation_intent_dropped(` |
| 信号 | [`request_started`](#member-gfplatformruntime-signals-request_started) | `signal request_started(adapter_id: StringName, request: GFPlatformBridgeRequest)` |
| 信号 | [`request_completed`](#member-gfplatformruntime-signals-request_completed) | `signal request_completed(adapter_id: StringName, result: GFPlatformBridgeResult)` |
| 方法 | [`ready`](#member-gfplatformruntime-methods-ready) | `func ready() -> void:` |
| 方法 | [`tick`](#member-gfplatformruntime-methods-tick) | `func tick(delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfplatformruntime-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`set_clock`](#member-gfplatformruntime-methods-set_clock) | `func set_clock(clock: GFClock) -> bool:` |
| 方法 | [`get_clock`](#member-gfplatformruntime-methods-get_clock) | `func get_clock() -> GFClock:` |
| 方法 | [`configure_activation_queue`](#member-gfplatformruntime-methods-configure_activation_queue) | `func configure_activation_queue(max_pending: int, max_seen: int) -> bool:` |
| 方法 | [`register_adapter`](#member-gfplatformruntime-methods-register_adapter) | `func register_adapter(adapter: GFPlatformAdapter) -> bool:` |
| 方法 | [`unregister_adapter`](#member-gfplatformruntime-methods-unregister_adapter) | `func unregister_adapter(adapter_id: StringName, shutdown_adapter: bool = true) -> bool:` |
| 方法 | [`initialize_adapter`](#member-gfplatformruntime-methods-initialize_adapter) | `func initialize_adapter(adapter_id: StringName, options: Dictionary = {}) -> GFAsyncCompletion:` |
| 方法 | [`set_contract_route`](#member-gfplatformruntime-methods-set_contract_route) | `func set_contract_route(contract_id: StringName, adapter_id: StringName) -> bool:` |
| 方法 | [`clear_contract_route`](#member-gfplatformruntime-methods-clear_contract_route) | `func clear_contract_route(contract_id: StringName) -> bool:` |
| 方法 | [`get_contract_route`](#member-gfplatformruntime-methods-get_contract_route) | `func get_contract_route(contract_id: StringName) -> StringName:` |
| 方法 | [`invoke`](#member-gfplatformruntime-methods-invoke) | `func invoke( request: GFPlatformBridgeRequest, adapter_id: StringName = &"" ) -> GFPlatformRequestHandle:` |
| 方法 | [`invoke_contract`](#member-gfplatformruntime-methods-invoke_contract) | `func invoke_contract( contract_id: StringName, method_id: StringName, payload: Dictionary = {}, options: Dictionary = {} ) -> GFPlatformRequestHandle:` |
| 方法 | [`cancel_request`](#member-gfplatformruntime-methods-cancel_request) | `func cancel_request(request_id: StringName, reason: StringName = &"cancelled") -> bool:` |
| 方法 | [`get_adapter_ids`](#member-gfplatformruntime-methods-get_adapter_ids) | `func get_adapter_ids() -> PackedStringArray:` |
| 方法 | [`get_context`](#member-gfplatformruntime-methods-get_context) | `func get_context(adapter_id: StringName) -> GFPlatformRuntimeContext:` |
| 方法 | [`get_activation_intents`](#member-gfplatformruntime-methods-get_activation_intents) | `func get_activation_intents() -> Array[GFPlatformActivationIntent]:` |
| 方法 | [`consume_activation_intent`](#member-gfplatformruntime-methods-consume_activation_intent) | `func consume_activation_intent( adapter_id: StringName, intent_id: StringName ) -> GFPlatformActivationIntent:` |
| 方法 | [`acknowledge_activation_intent`](#member-gfplatformruntime-methods-acknowledge_activation_intent) | `func acknowledge_activation_intent( adapter_id: StringName, intent_id: StringName ) -> bool:` |
| 方法 | [`clear_activation_intents`](#member-gfplatformruntime-methods-clear_activation_intents) | `func clear_activation_intents(clear_dedupe_history: bool = false) -> void:` |
| 方法 | [`has_capability`](#member-gfplatformruntime-methods-has_capability) | `func has_capability(capability_id: StringName, adapter_id: StringName = &"") -> bool:` |
| 方法 | [`get_debug_snapshot`](#member-gfplatformruntime-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |

## 信号

<a id="member-gfplatformruntime-signals-adapter_registered"></a>

### `adapter_registered`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal adapter_registered(adapter_id: StringName)
```

Adapter 注册后发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |

<a id="member-gfplatformruntime-signals-adapter_unregistered"></a>

### `adapter_unregistered`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal adapter_unregistered(adapter_id: StringName)
```

Adapter 注销后发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |

<a id="member-gfplatformruntime-signals-adapter_state_changed"></a>

### `adapter_state_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal adapter_state_changed(adapter_id: StringName, previous_state: int, current_state: int)
```

Adapter 状态变化后转发。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |
| `previous_state` | 变化前状态。 |
| `current_state` | 变化后状态。 |

<a id="member-gfplatformruntime-signals-context_changed"></a>

### `context_changed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal context_changed(adapter_id: StringName, context: GFPlatformRuntimeContext)
```

Adapter 上下文变化后转发。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |
| `context` | 平台上下文副本。 |

<a id="member-gfplatformruntime-signals-lifecycle_event"></a>

### `lifecycle_event`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal lifecycle_event(adapter_id: StringName, event: GFPlatformLifecycleEvent)
```

Adapter 生命周期事件转发。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |
| `event` | 生命周期事件副本。 |

<a id="member-gfplatformruntime-signals-activation_intent_received"></a>

### `activation_intent_received`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal activation_intent_received(adapter_id: StringName, intent: GFPlatformActivationIntent)
```

平台激活意图进入有界队列后发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 来源 Adapter ID。 |
| `intent` | 激活意图副本。 |

<a id="member-gfplatformruntime-signals-activation_intent_dropped"></a>

### `activation_intent_dropped`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal activation_intent_dropped(
```

激活意图因重复或容量限制未保留时发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 来源 Adapter ID。 |
| `intent_id` | 被丢弃的 Intent ID。 |
| `reason` | duplicate 或 capacity。 |

<a id="member-gfplatformruntime-signals-request_started"></a>

### `request_started`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal request_started(adapter_id: StringName, request: GFPlatformBridgeRequest)
```

请求交给 adapter 前发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 已解析的 Adapter ID；路由失败时为空。 |
| `request` | 请求副本。 |

<a id="member-gfplatformruntime-signals-request_completed"></a>

### `request_completed`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
signal request_completed(adapter_id: StringName, result: GFPlatformBridgeResult)
```

请求进入终态后发出。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 处理请求的 Adapter ID；路由失败时为空。 |
| `result` | 请求终态结果副本。 |

## 方法

<a id="member-gfplatformruntime-methods-ready"></a>

### `ready`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func ready() -> void:
```

在架构中自动采用已注册 GFTimeProvider 的底层时钟。 通过构造函数或 `set_clock()` 显式注入后不会被自动覆盖。

<a id="member-gfplatformruntime-methods-tick"></a>

### `tick`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func tick(delta: float) -> void:
```

推进 adapter callback pump 并处理请求超时。

参数：

| 名称 | 说明 |
|---|---|
| `delta` | 引擎原始帧间隔。 |

<a id="member-gfplatformruntime-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func dispose() -> void:
```

取消全部请求、注销 adapter 并关闭平台资源。

<a id="member-gfplatformruntime-methods-set_clock"></a>

### `set_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_clock(clock: GFClock) -> bool:
```

设置平台请求截止时间与结果耗时使用的统一单调时钟。 存在 Runtime 等待请求或 Adapter Provider 请求租约时拒绝替换，避免绝对截止值 跨越两个时间域。

参数：

| 名称 | 说明 |
|---|---|
| `clock` | 新平台时钟。 |

返回：时钟合法且当前没有请求或 Provider 租约时返回 true。

<a id="member-gfplatformruntime-methods-get_clock"></a>

### `get_clock`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_clock() -> GFClock:
```

获取当前平台时钟。

返回：当前时钟。

<a id="member-gfplatformruntime-methods-configure_activation_queue"></a>

### `configure_activation_queue`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure_activation_queue(max_pending: int, max_seen: int) -> bool:
```

配置激活意图队列和去重窗口容量。

参数：

| 名称 | 说明 |
|---|---|
| `max_pending` | 最多保留的待消费意图数。 |
| `max_seen` | 最多记忆的近期 Intent ID 数；不得小于 max_pending。 |

返回：容量有效并已应用时返回 true。

<a id="member-gfplatformruntime-methods-register_adapter"></a>

### `register_adapter`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func register_adapter(adapter: GFPlatformAdapter) -> bool:
```

注册平台 adapter。 注册只建立候选关系，不自动初始化 adapter，也不在冲突候选间建立隐式优先级。

参数：

| 名称 | 说明 |
|---|---|
| `adapter` | 已配置的外部平台 adapter。 |

返回：注册成功返回 true。

<a id="member-gfplatformruntime-methods-unregister_adapter"></a>

### `unregister_adapter`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func unregister_adapter(adapter_id: StringName, shutdown_adapter: bool = true) -> bool:
```

注销平台 adapter。 该 adapter 的等待请求会先进入 `adapter_unregistered` 取消终态，显式路由也会清除。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |
| `shutdown_adapter` | 是否关闭 adapter 底层资源。 |

返回：找到并注销返回 true。

<a id="member-gfplatformruntime-methods-initialize_adapter"></a>

### `initialize_adapter`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func initialize_adapter(adapter_id: StringName, options: Dictionary = {}) -> GFAsyncCompletion:
```

初始化指定 adapter。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |
| `options` | Adapter 定义的初始化选项。 |

返回：初始化完成源；adapter 不存在时立即失败。

结构：

- `options`: Dictionary adapter-defined initialization options.

<a id="member-gfplatformruntime-methods-set_contract_route"></a>

### `set_contract_route`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func set_contract_route(contract_id: StringName, adapter_id: StringName) -> bool:
```

为桥接契约设置显式 adapter 路由。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 桥接契约 ID。 |
| `adapter_id` | 必须声明支持该契约的 Adapter ID。 |

返回：路由有效并写入成功返回 true。

<a id="member-gfplatformruntime-methods-clear_contract_route"></a>

### `clear_contract_route`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func clear_contract_route(contract_id: StringName) -> bool:
```

清除桥接契约显式路由。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 桥接契约 ID。 |

返回：找到并清除返回 true。

<a id="member-gfplatformruntime-methods-get_contract_route"></a>

### `get_contract_route`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_contract_route(contract_id: StringName) -> StringName:
```

获取桥接契约当前显式路由。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 桥接契约 ID。 |

返回：Adapter ID；未设置返回空。

<a id="member-gfplatformruntime-methods-invoke"></a>

### `invoke`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func invoke( request: GFPlatformBridgeRequest, adapter_id: StringName = &"" ) -> GFPlatformRequestHandle:
```

提交完整平台桥接请求。 `adapter_id` 非空时优先使用指定 adapter；否则使用显式路由；只有恰好一个 候选时才允许自动解析。

参数：

| 名称 | 说明 |
|---|---|
| `request` | 完整桥接请求。 |
| `adapter_id` | 可选显式 Adapter ID。 |

返回：一次性请求句柄；所有输入和路由失败也返回终态句柄。

<a id="member-gfplatformruntime-methods-invoke_contract"></a>

### `invoke_contract`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func invoke_contract( contract_id: StringName, method_id: StringName, payload: Dictionary = {}, options: Dictionary = {} ) -> GFPlatformRequestHandle:
```

构建并提交平台桥接请求。

参数：

| 名称 | 说明 |
|---|---|
| `contract_id` | 桥接契约 ID。 |
| `method_id` | 方法 ID。 |
| `payload` | Adapter 定义的请求载荷。 |
| `options` | 可包含 adapter_id、request_id、timeout_msec 和 metadata。 |

返回：一次性请求句柄。

结构：

- `payload`: Dictionary adapter-defined request payload.
- `options`: Dictionary with optional adapter_id, request_id, timeout_msec, and metadata fields.

<a id="member-gfplatformruntime-methods-cancel_request"></a>

### `cancel_request`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func cancel_request(request_id: StringName, reason: StringName = &"cancelled") -> bool:
```

取消等待中的请求。

参数：

| 名称 | 说明 |
|---|---|
| `request_id` | 请求 ID。 |
| `reason` | 取消原因。 |

返回：找到等待请求并首次取消返回 true。

<a id="member-gfplatformruntime-methods-get_adapter_ids"></a>

### `get_adapter_ids`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_adapter_ids() -> PackedStringArray:
```

获取注册的 Adapter ID。

返回：排序后的 Adapter ID。

<a id="member-gfplatformruntime-methods-get_context"></a>

### `get_context`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_context(adapter_id: StringName) -> GFPlatformRuntimeContext:
```

获取 adapter 上下文副本。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | Adapter ID。 |

返回：上下文副本；adapter 不存在时返回 null。

<a id="member-gfplatformruntime-methods-get_activation_intents"></a>

### `get_activation_intents`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_activation_intents() -> Array[GFPlatformActivationIntent]:
```

获取当前待消费激活意图副本。

返回：按接收顺序排列的意图副本。

结构：

- `return`: Array[GFPlatformActivationIntent] pending activation intents.

<a id="member-gfplatformruntime-methods-consume_activation_intent"></a>

### `consume_activation_intent`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func consume_activation_intent( adapter_id: StringName, intent_id: StringName ) -> GFPlatformActivationIntent:
```

消费并移除指定激活意图。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 来源 Adapter ID。 |
| `intent_id` | 该 Adapter 内的 Intent ID。 |

返回：找到时返回意图副本，否则返回 null。

<a id="member-gfplatformruntime-methods-acknowledge_activation_intent"></a>

### `acknowledge_activation_intent`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func acknowledge_activation_intent( adapter_id: StringName, intent_id: StringName ) -> bool:
```

确认并移除指定激活意图。

参数：

| 名称 | 说明 |
|---|---|
| `adapter_id` | 来源 Adapter ID。 |
| `intent_id` | 该 Adapter 内的 Intent ID。 |

返回：找到并移除返回 true。

<a id="member-gfplatformruntime-methods-clear_activation_intents"></a>

### `clear_activation_intents`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_activation_intents(clear_dedupe_history: bool = false) -> void:
```

清空待消费激活意图。

参数：

| 名称 | 说明 |
|---|---|
| `clear_dedupe_history` | 是否同时清空近期 ID 去重窗口。 |

<a id="member-gfplatformruntime-methods-has_capability"></a>

### `has_capability`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func has_capability(capability_id: StringName, adapter_id: StringName = &"") -> bool:
```

检查一个或任意已就绪 adapter 是否声明能力。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力 ID。 |
| `adapter_id` | 指定 Adapter ID；为空时查询全部 READY adapter。 |

返回：能力存在返回 true。

<a id="member-gfplatformruntime-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`9.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取运行时调试快照。

返回：Adapter、路由和等待请求摘要。

结构：

- `return`: Dictionary with adapters, contract_routes, and pending_request_count.
