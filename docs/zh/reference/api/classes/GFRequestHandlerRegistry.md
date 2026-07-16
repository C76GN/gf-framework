# GFRequestHandlerRegistry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/common/gf_request_handler_registry.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`7.0.0`

单处理器请求调用注册表。 用于表达 “Invoke / TryInvoke” 语义：每个 request_type 至多有一个处理器。 多订阅广播仍应使用 GFTypeEventSystem；本注册表只负责明确的一对一请求调用契约， 不规定请求载荷结构，也不执行业务路由策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`handler_registered`](#member-gfrequesthandlerregistry-signals-handler_registered) | `signal handler_registered(request_type: StringName, replaced: bool, metadata: Dictionary)` |
| 信号 | [`handler_unregistered`](#member-gfrequesthandlerregistry-signals-handler_unregistered) | `signal handler_unregistered(request_type: StringName, metadata: Dictionary)` |
| 信号 | [`request_invoked`](#member-gfrequesthandlerregistry-signals-request_invoked) | `signal request_invoked(request_type: StringName, result: Variant, metadata: Dictionary)` |
| 常量 | [`STATUS_REGISTERED`](#member-gfrequesthandlerregistry-constants-status_registered) | `const STATUS_REGISTERED: StringName = &"registered"` |
| 常量 | [`STATUS_REPLACED`](#member-gfrequesthandlerregistry-constants-status_replaced) | `const STATUS_REPLACED: StringName = &"replaced"` |
| 常量 | [`STATUS_UNREGISTERED`](#member-gfrequesthandlerregistry-constants-status_unregistered) | `const STATUS_UNREGISTERED: StringName = &"unregistered"` |
| 常量 | [`STATUS_DUPLICATE`](#member-gfrequesthandlerregistry-constants-status_duplicate) | `const STATUS_DUPLICATE: StringName = &"duplicate"` |
| 常量 | [`STATUS_MISSING`](#member-gfrequesthandlerregistry-constants-status_missing) | `const STATUS_MISSING: StringName = &"missing"` |
| 常量 | [`STATUS_INVOKED`](#member-gfrequesthandlerregistry-constants-status_invoked) | `const STATUS_INVOKED: StringName = &"invoked"` |
| 常量 | [`STATUS_INVALID`](#member-gfrequesthandlerregistry-constants-status_invalid) | `const STATUS_INVALID: StringName = &"invalid"` |
| 常量 | [`STATUS_MISMATCH`](#member-gfrequesthandlerregistry-constants-status_mismatch) | `const STATUS_MISMATCH: StringName = &"mismatch"` |
| 常量 | [`DEFAULT_MAX_RECENT_EVENTS`](#member-gfrequesthandlerregistry-constants-default_max_recent_events) | `const DEFAULT_MAX_RECENT_EVENTS: int = 64` |
| 属性 | [`max_recent_events`](#member-gfrequesthandlerregistry-properties-max_recent_events) | `var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:` |
| 方法 | [`make_bridge_contract_entries`](#member-gfrequesthandlerregistry-methods-make_bridge_contract_entries) | `static func make_bridge_contract_entries( required_request_types: PackedStringArray, registry: GFRequestHandlerRegistry, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`register_handler`](#member-gfrequesthandlerregistry-methods-register_handler) | `func register_handler(request_type: StringName, handler: Callable, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`unregister_handler`](#member-gfrequesthandlerregistry-methods-unregister_handler) | `func unregister_handler( request_type: StringName, handler: Callable = Callable(), metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`invoke`](#member-gfrequesthandlerregistry-methods-invoke) | `func invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`try_invoke`](#member-gfrequesthandlerregistry-methods-try_invoke) | `func try_invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:` |
| 方法 | [`to_json_compatible_result`](#member-gfrequesthandlerregistry-methods-to_json_compatible_result) | `static func to_json_compatible_result(result: Dictionary, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`has_handler`](#member-gfrequesthandlerregistry-methods-has_handler) | `func has_handler(request_type: StringName) -> bool:` |
| 方法 | [`get_handler_ids`](#member-gfrequesthandlerregistry-methods-get_handler_ids) | `func get_handler_ids() -> Array[StringName]:` |
| 方法 | [`get_handler_snapshot`](#member-gfrequesthandlerregistry-methods-get_handler_snapshot) | `func get_handler_snapshot(request_type: StringName) -> Dictionary:` |
| 方法 | [`get_recent_events`](#member-gfrequesthandlerregistry-methods-get_recent_events) | `func get_recent_events() -> Array[Dictionary]:` |
| 方法 | [`get_json_compatible_recent_events`](#member-gfrequesthandlerregistry-methods-get_json_compatible_recent_events) | `func get_json_compatible_recent_events(options: Dictionary = {}) -> Array[Dictionary]:` |
| 方法 | [`clear`](#member-gfrequesthandlerregistry-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfrequesthandlerregistry-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`get_json_compatible_debug_snapshot`](#member-gfrequesthandlerregistry-methods-get_json_compatible_debug_snapshot) | `func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:` |

## 信号

<a id="member-gfrequesthandlerregistry-signals-handler_registered"></a>

### `handler_registered`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal handler_registered(request_type: StringName, replaced: bool, metadata: Dictionary)
```

handler 注册或替换时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 请求类型。 |
| `replaced` | 是否替换了旧 handler。 |
| `metadata` | 注册元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的 handler 上下文。

<a id="member-gfrequesthandlerregistry-signals-handler_unregistered"></a>

### `handler_unregistered`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal handler_unregistered(request_type: StringName, metadata: Dictionary)
```

handler 注销时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 请求类型。 |
| `metadata` | 注销元数据。 |

结构：

- `metadata`: Dictionary，调用方定义的 handler 上下文。

<a id="member-gfrequesthandlerregistry-signals-request_invoked"></a>

### `request_invoked`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
signal request_invoked(request_type: StringName, result: Variant, metadata: Dictionary)
```

请求成功调用时发出。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 请求类型。 |
| `result` | handler 返回值副本。 |
| `metadata` | 调用元数据。 |

结构：

- `result`: Variant，handler 返回值。
- `metadata`: Dictionary，包含 request_type、sequence、context 和 handler metadata。

## 常量

<a id="member-gfrequesthandlerregistry-constants-status_registered"></a>

### `STATUS_REGISTERED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REGISTERED: StringName = &"registered"
```

handler 已注册。

<a id="member-gfrequesthandlerregistry-constants-status_replaced"></a>

### `STATUS_REPLACED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_REPLACED: StringName = &"replaced"
```

handler 已替换。

<a id="member-gfrequesthandlerregistry-constants-status_unregistered"></a>

### `STATUS_UNREGISTERED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_UNREGISTERED: StringName = &"unregistered"
```

handler 已注销。

<a id="member-gfrequesthandlerregistry-constants-status_duplicate"></a>

### `STATUS_DUPLICATE`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_DUPLICATE: StringName = &"duplicate"
```

handler 已存在且不允许替换。

<a id="member-gfrequesthandlerregistry-constants-status_missing"></a>

### `STATUS_MISSING`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_MISSING: StringName = &"missing"
```

未找到 handler。

<a id="member-gfrequesthandlerregistry-constants-status_invoked"></a>

### `STATUS_INVOKED`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVOKED: StringName = &"invoked"
```

请求已调用。

<a id="member-gfrequesthandlerregistry-constants-status_invalid"></a>

### `STATUS_INVALID`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_INVALID: StringName = &"invalid"
```

请求或 handler 无效。

<a id="member-gfrequesthandlerregistry-constants-status_mismatch"></a>

### `STATUS_MISMATCH`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const STATUS_MISMATCH: StringName = &"mismatch"
```

handler 不匹配。

<a id="member-gfrequesthandlerregistry-constants-default_max_recent_events"></a>

### `DEFAULT_MAX_RECENT_EVENTS`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
const DEFAULT_MAX_RECENT_EVENTS: int = 64
```

默认保留的最近调用事件数量。

## 属性

<a id="member-gfrequesthandlerregistry-properties-max_recent_events"></a>

### `max_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
```

最近注册/调用事件历史上限。设置为 0 时不保留历史。

## 方法

<a id="member-gfrequesthandlerregistry-methods-make_bridge_contract_entries"></a>

### `make_bridge_contract_entries`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func make_bridge_contract_entries( required_request_types: PackedStringArray, registry: GFRequestHandlerRegistry, options: Dictionary = {} ) -> Dictionary:
```

构建请求 handler 桥接契约条目。 该方法只把请求类型和注册表快照转换为通用 bridge contract/adapters 条目，不生成最终验证报告。

参数：

| 名称 | 说明 |
|---|---|
| `required_request_types` | 必需请求类型列表。 |
| `registry` | 请求 handler 注册表。 |
| `options` | 构建选项，支持 kind、signature 和 adapter_kind。 |

返回：请求 handler bridge 条目数据。

结构：

- `options`: Dictionary request-handler bridge entry options.
- `return`: Dictionary with contract_entries and adapter_entries arrays.

<a id="member-gfrequesthandlerregistry-methods-register_handler"></a>

### `register_handler`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func register_handler(request_type: StringName, handler: Callable, options: Dictionary = {}) -> Dictionary:
```

注册单处理器请求 handler。 handler 会收到一个 Dictionary 参数，包含 request_type、payload、context、sequence 和 handler_metadata。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |
| `handler` | 处理请求的 Callable，签名为 Callable(request: Dictionary) -> Variant。 |
| `options` | 注册选项，支持 replace、owner_id 和 metadata。 |

返回：注册结果。

结构：

- `options`: Dictionary，包含 replace: bool、owner_id: StringName 和 metadata: Dictionary。
- `return`: Dictionary，包含 ok、status、request_type、replaced 和 metadata。

<a id="member-gfrequesthandlerregistry-methods-unregister_handler"></a>

### `unregister_handler`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func unregister_handler( request_type: StringName, handler: Callable = Callable(), metadata: Dictionary = {} ) -> Dictionary:
```

注销请求 handler。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |
| `handler` | 可选 handler；有效时只有完全匹配才注销。 |
| `metadata` | 注销元数据。 |

返回：注销结果。

结构：

- `metadata`: Dictionary，调用方定义的注销上下文。
- `return`: Dictionary with ok, status, request_type, result, error, handler_count, and metadata.

<a id="member-gfrequesthandlerregistry-methods-invoke"></a>

### `invoke`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:
```

调用请求 handler。 缺少 handler 会返回 missing 状态；handler 运行时错误由 Godot 按普通 Callable 调用规则报告。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |
| `payload` | 请求载荷。 |
| `context` | 调用上下文。 |

返回：调用结果。

结构：

- `payload`: Variant，调用方定义的请求载荷。
- `context`: Dictionary，调用方定义的调用上下文。
- `return`: Dictionary，包含 ok、status、request_type、result、context 和 metadata。

<a id="member-gfrequesthandlerregistry-methods-try_invoke"></a>

### `try_invoke`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func try_invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:
```

尝试调用请求 handler。 与 invoke() 相同，但缺少 handler 被视为可预期结果，并在返回值中标记 missing_allowed。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |
| `payload` | 请求载荷。 |
| `context` | 调用上下文。 |

返回：调用结果。

结构：

- `payload`: Variant，调用方定义的请求载荷。
- `context`: Dictionary，调用方定义的调用上下文。
- `return`: Dictionary，包含 ok、status、request_type、result、context、metadata 和 missing_allowed。

<a id="member-gfrequesthandlerregistry-methods-to_json_compatible_result"></a>

### `to_json_compatible_result`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_result(result: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将请求调用结果转换为 JSON.stringify() 安全的诊断报告。 功能型 invoke()/try_invoke() 返回值保持原始 Variant；日志、快照和跨进程诊断应使用该方法输出。

参数：

| 名称 | 说明 |
|---|---|
| `result` | invoke()/try_invoke() 返回的调用结果。 |
| `options` | 编码选项，透传给 GFReportValueCodec。 |

返回：JSON-safe 调用结果。

结构：

- `result`: Dictionary raw request invocation result.
- `options`: Dictionary report value codec options.
- `return`: Dictionary safe for JSON.stringify().

<a id="member-gfrequesthandlerregistry-methods-has_handler"></a>

### `has_handler`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func has_handler(request_type: StringName) -> bool:
```

判断请求类型是否已注册 handler。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |

返回：已注册且 handler 有效时返回 true。

<a id="member-gfrequesthandlerregistry-methods-get_handler_ids"></a>

### `get_handler_ids`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_handler_ids() -> Array[StringName]:
```

获取已注册请求类型。

返回：请求类型数组。

<a id="member-gfrequesthandlerregistry-methods-get_handler_snapshot"></a>

### `get_handler_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_handler_snapshot(request_type: StringName) -> Dictionary:
```

获取某个 handler 的快照。

参数：

| 名称 | 说明 |
|---|---|
| `request_type` | 稳定请求类型。 |

返回：handler 快照；未注册时为空字典。

结构：

- `return`: Dictionary，包含 request_type、owner_id、metadata、registered_msec、invocation_count、last_invoked_msec 和 has_valid_handler。

<a id="member-gfrequesthandlerregistry-methods-get_recent_events"></a>

### `get_recent_events`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_recent_events() -> Array[Dictionary]:
```

获取最近注册/调用事件。

返回：最近事件数组。

结构：

- `return`: Array[Dictionary]，每个元素包含 sequence、event_type、request_type、status 和 metadata。

<a id="member-gfrequesthandlerregistry-methods-get_json_compatible_recent_events"></a>

### `get_json_compatible_recent_events`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_json_compatible_recent_events(options: Dictionary = {}) -> Array[Dictionary]:
```

获取 JSON.stringify() 安全的最近注册/调用事件。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 编码选项，透传给 GFReportValueCodec。 |

返回：JSON-safe 最近事件数组。

结构：

- `options`: Dictionary report value codec options.
- `return`: Array[Dictionary]，每个元素均可安全传给 JSON.stringify()。

<a id="member-gfrequesthandlerregistry-methods-clear"></a>

### `clear`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func clear() -> void:
```

清空全部 handler 和历史事件。

<a id="member-gfrequesthandlerregistry-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取注册表调试快照。

返回：注册表状态快照。

结构：

- `return`: Dictionary，包含 handler_count、统计计数、handlers 和 recent_events。

<a id="member-gfrequesthandlerregistry-methods-get_json_compatible_debug_snapshot"></a>

### `get_json_compatible_debug_snapshot`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
```

获取 JSON.stringify() 安全的注册表调试快照。 功能型 get_debug_snapshot() 保留原始 Variant；日志、导出和跨进程诊断应使用该方法。

参数：

| 名称 | 说明 |
|---|---|
| `options` | 编码选项，透传给 GFReportValueCodec。 |

返回：JSON-safe 注册表状态快照。

结构：

- `options`: Dictionary report value codec options.
- `return`: Dictionary safe for JSON.stringify().
