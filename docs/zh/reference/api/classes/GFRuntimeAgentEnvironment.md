# GFRuntimeAgentEnvironment

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/agent/gf_runtime_agent_environment.gd`
- 模块：`Standard`
- 继承：`GFUtility`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`10.0.0`

传输无关的受限运行时 Agent 调用环境。 受信宿主显式注册严格 endpoint，再为调用方签发仅授权指定 endpoint 的短期 session。 环境负责协议版本、bearer token、TTL、限流、防重放、结构预算、策略检查和无载荷审计； 它不提供网络传输、模型客户端、文件或命令执行，也不是进程或脚本沙箱。 实例绑定创建线程；所有公开入口与公开策略对象的原地修改都必须在该线程串行执行， 外层 transport 应先编排回拥有线程。跨线程公开入口会 fail closed 且不写共享审计状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`audit_event_recorded`](#member-gfruntimeagentenvironment-signals-audit_event_recorded) | `signal audit_event_recorded(event: Dictionary)` |
| 常量 | [`PROTOCOL_VERSION`](#member-gfruntimeagentenvironment-constants-protocol_version) | `const PROTOCOL_VERSION: int = 1` |
| 常量 | [`SCHEMA_VERSION`](#member-gfruntimeagentenvironment-constants-schema_version) | `const SCHEMA_VERSION: int = 1` |
| 属性 | [`enabled`](#member-gfruntimeagentenvironment-properties-enabled) | `var enabled: bool = false:` |
| 属性 | [`policy_registry`](#member-gfruntimeagentenvironment-properties-policy_registry) | `var policy_registry: GFPolicyRegistry = GFPolicyRegistry.new():` |
| 方法 | [`dispose`](#member-gfruntimeagentenvironment-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_endpoint`](#member-gfruntimeagentenvironment-methods-register_endpoint) | `func register_endpoint( endpoint_id: String, request_schema: GFDictionarySchema, response_schema: GFDictionarySchema, handler: Callable ) -> Dictionary:` |
| 方法 | [`unregister_endpoint`](#member-gfruntimeagentenvironment-methods-unregister_endpoint) | `func unregister_endpoint(endpoint_id: String) -> Dictionary:` |
| 方法 | [`get_endpoint_catalog`](#member-gfruntimeagentenvironment-methods-get_endpoint_catalog) | `func get_endpoint_catalog() -> Dictionary:` |
| 方法 | [`open_session`](#member-gfruntimeagentenvironment-methods-open_session) | `func open_session( endpoint_ids: PackedStringArray, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`close_session`](#member-gfruntimeagentenvironment-methods-close_session) | `func close_session(session_id: String, bearer_token: String) -> Dictionary:` |
| 方法 | [`revoke_session`](#member-gfruntimeagentenvironment-methods-revoke_session) | `func revoke_session(session_id: String) -> bool:` |
| 方法 | [`invalidate_policy_context`](#member-gfruntimeagentenvironment-methods-invalidate_policy_context) | `func invalidate_policy_context() -> int:` |
| 方法 | [`execute_request`](#member-gfruntimeagentenvironment-methods-execute_request) | `func execute_request(request: Dictionary, bearer_token: String) -> Dictionary:` |
| 方法 | [`prune_expired_sessions`](#member-gfruntimeagentenvironment-methods-prune_expired_sessions) | `func prune_expired_sessions() -> int:` |
| 方法 | [`get_audit_events`](#member-gfruntimeagentenvironment-methods-get_audit_events) | `func get_audit_events(limit: int = 64) -> Dictionary:` |
| 方法 | [`clear_audit_events`](#member-gfruntimeagentenvironment-methods-clear_audit_events) | `func clear_audit_events() -> void:` |
| 方法 | [`get_debug_snapshot`](#member-gfruntimeagentenvironment-methods-get_debug_snapshot) | `func get_debug_snapshot() -> Dictionary:` |
| 方法 | [`_get_current_time_msec`](#member-gfruntimeagentenvironment-methods-_get_current_time_msec) | `func _get_current_time_msec() -> int:` |

## 信号

<a id="member-gfruntimeagentenvironment-signals-audit_event_recorded"></a>

### `audit_event_recorded`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
signal audit_event_recorded(event: Dictionary)
```

追加安全审计事件时触发。 事件只包含固定协议字段、稳定标识和 request id 摘要，不包含 token、payload、 handler 输出或策略返回数据。

参数：

| 名称 | 说明 |
|---|---|
| `event` | 固定字段、无业务载荷的 Runtime Agent 审计事件。 |

结构：

- `event`: Dictionary { schema_version: int, protocol_version: int, sequence: int, timestamp_msec: int, action: String, outcome: String, reason: String, session_id: String, endpoint_id: String, request_id_digest: String }.

## 常量

<a id="member-gfruntimeagentenvironment-constants-protocol_version"></a>

### `PROTOCOL_VERSION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const PROTOCOL_VERSION: int = 1
```

Runtime Agent 请求协议版本。

<a id="member-gfruntimeagentenvironment-constants-schema_version"></a>

### `SCHEMA_VERSION`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
const SCHEMA_VERSION: int = 1
```

Runtime Agent 结果与审计结构版本。

## 属性

<a id="member-gfruntimeagentenvironment-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var enabled: bool = false:
```

是否接受新 session 和请求。 默认 false。由 true 切换为 false 会立即撤销全部 session；再次启用不会恢复旧凭据。 endpoint 注册会保留，便于宿主先完成声明再显式开放环境。

<a id="member-gfruntimeagentenvironment-properties-policy_registry"></a>

### `policy_registry`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var policy_registry: GFPolicyRegistry = GFPolicyRegistry.new():
```

session 签发与请求执行使用的策略注册表。 空注册表表示没有项目附加策略；null 会 fail closed。策略 Provider 属于受信宿主， 可以读取当次策略 artifact，但其结果和 artifact 不会复制到 Runtime Agent 响应或审计。 registry、providers 数组及 Provider 字段的原地修改也必须由环境拥有线程串行完成。 原地修改前必须调用 invalidate_policy_context()，以覆盖调用间发生并恢复的 ABA 变化； 当前公开配置摘要仍会对未通知但持续存在的配置漂移 fail closed。

## 方法

<a id="member-gfruntimeagentenvironment-methods-dispose"></a>

### `dispose`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func dispose() -> void:
```

释放 endpoint、session、凭据摘要与内存审计。 跨拥有线程调用不会改变环境；transport 必须先把控制流编排回拥有线程。

<a id="member-gfruntimeagentenvironment-methods-register_endpoint"></a>

### `register_endpoint`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func register_endpoint( endpoint_id: String, request_schema: GFDictionarySchema, response_schema: GFDictionarySchema, handler: Callable ) -> Dictionary:
```

注册一个受信 endpoint。 request_schema 与 response_schema 必须是 closed、无 coercion、无 metadata/default/rule， 且只使用 JSON 原生字段类型的有限非循环结构。环境保存 schema 副本，注册后调用方修改 原 Resource 不会改变 endpoint 契约。重复 ID 必须先显式注销，不会隐式替换 handler。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint_id` | 稳定 endpoint 标识。 |
| `request_schema` | 严格请求 payload schema。 |
| `response_schema` | 严格响应 schema。 |
| `handler` | 同步受信回调；接收不含 token 的请求 Dictionary，返回 Dictionary。 |

返回：版本化注册结果。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_id?: String }.

<a id="member-gfruntimeagentenvironment-methods-unregister_endpoint"></a>

### `unregister_endpoint`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func unregister_endpoint(endpoint_id: String) -> Dictionary:
```

注销 endpoint。 已签发 session 中的旧 grant 不会绑定到后续同名注册；旧请求会以 endpoint_grant_stale 失败，避免注销/重注册的 ABA 权限恢复。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint_id` | endpoint 标识。 |

返回：版本化注销结果。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_id?: String }.

<a id="member-gfruntimeagentenvironment-methods-get_endpoint_catalog"></a>

### `get_endpoint_catalog`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_endpoint_catalog() -> Dictionary:
```

获取不含 handler、token、metadata 和默认值的 endpoint 目录。

返回：版本化安全目录。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_count?: int, endpoints?: Array[Dictionary { endpoint_id: String, request_schema: Dictionary { schema_id: String, allow_extra_fields: bool, fields: Array[Dictionary] }, response_schema: Dictionary { schema_id: String, allow_extra_fields: bool, fields: Array[Dictionary] } }] }.

<a id="member-gfruntimeagentenvironment-methods-open_session"></a>

### `open_session`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func open_session( endpoint_ids: PackedStringArray, options: Dictionary = {} ) -> Dictionary:
```

为一组精确 endpoint grant 创建短期 session。 此方法属于受信宿主控制面，不是无需认证的远程 endpoint。返回的 token 只出现一次； 环境仅保存与 session id 绑定后的 SHA-256。时间字段使用环境单调毫秒时钟，不是 Unix 时间。

参数：

| 名称 | 说明 |
|---|---|
| `endpoint_ids` | session 唯一允许调用的 endpoint ID。 |
| `options` | 严格选项；支持 ttl_msec、max_requests_per_window、rate_window_msec 和 max_request_ids。 |

返回：成功时包含一次性 token 的版本化 session 凭据；失败时不含 token 字段。

结构：

- `endpoint_ids`: PackedStringArray exact endpoint grants.
- `options`: Dictionary { ttl_msec?: int, max_requests_per_window?: int, rate_window_msec?: int, max_request_ids?: int }; no other keys are accepted.
- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, session_id?: String, token?: String, endpoint_ids?: Array[String], issued_at_msec?: int, expires_at_msec?: int }; credential fields exist only on success.

<a id="member-gfruntimeagentenvironment-methods-close_session"></a>

### `close_session`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func close_session(session_id: String, bearer_token: String) -> Dictionary:
```

使用凭据关闭 session。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | session 标识。 |
| `bearer_token` | open_session() 一次返回的 token。 |

返回：版本化关闭结果。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String }.

<a id="member-gfruntimeagentenvironment-methods-revoke_session"></a>

### `revoke_session`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func revoke_session(session_id: String) -> bool:
```

由受信宿主按 session id 撤销凭据。 此入口不要求 bearer token，因此只能放在宿主控制面，不能直接映射为未鉴权远程 endpoint。

参数：

| 名称 | 说明 |
|---|---|
| `session_id` | 待撤销 session 标识。 |

返回：找到并撤销 session 时返回 true。

<a id="member-gfruntimeagentenvironment-methods-invalidate_policy_context"></a>

### `invalidate_policy_context`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func invalidate_policy_context() -> int:
```

使策略上下文的任意原地或外部变化立即失效。 修改 registry/provider 公开可变对象，或改变无法由环境观察的自定义字段、外部服务状态 与闭包捕获值之前，受信宿主必须调用本入口。调用会撤销全部 session，并使正在进行的 session 签发或请求在回调后的上下文复核中失败。

返回：本次撤销的 session 数量；跨拥有线程调用返回 0。

<a id="member-gfruntimeagentenvironment-methods-execute_request"></a>

### `execute_request`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func execute_request(request: Dictionary, bearer_token: String) -> Dictionary:
```

执行一个版本化 Runtime Agent 请求。 bearer token 与协议请求分离，不会进入 handler、策略响应、目录、调试快照或审计。 通过身份和精确 grant 校验后，request id 会在策略与 handler 前被消费；失败请求不能 以同一 request id 重试。handler 返回后会复核 session、endpoint generation 和策略注册表 身份，发生同步撤销或替换时丢弃输出。handler 已产生的副作用无法回滚。

参数：

| 名称 | 说明 |
|---|---|
| `request` | closed 请求 envelope。 |
| `bearer_token` | session bearer token；不会写入 request 副本。 |

返回：版本化执行结果；仅成功结果包含 response。

结构：

- `request`: Dictionary { protocol_version: int, session_id: String, endpoint_id: String, request_id: String, payload: Dictionary }; exactly these five keys are accepted.
- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, response?: Dictionary }; response exists only on success and matches the endpoint response schema.

<a id="member-gfruntimeagentenvironment-methods-prune_expired_sessions"></a>

### `prune_expired_sessions`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func prune_expired_sessions() -> int:
```

删除所有已过期 session。

返回：本次删除数量。

<a id="member-gfruntimeagentenvironment-methods-get_audit_events"></a>

### `get_audit_events`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_audit_events(limit: int = 64) -> Dictionary:
```

获取最近的无载荷安全审计事件。

参数：

| 名称 | 说明 |
|---|---|
| `limit` | 最多返回数量；钳制到 0..256。 |

返回：版本化审计结果。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, event_count?: int, retained_event_count?: int, events?: Array[Dictionary { schema_version: int, protocol_version: int, sequence: int, timestamp_msec: int, action: String, outcome: String, reason: String, session_id: String, endpoint_id: String, request_id_digest: String }] }.

<a id="member-gfruntimeagentenvironment-methods-clear_audit_events"></a>

### `clear_audit_events`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func clear_audit_events() -> void:
```

清空环境内存审计环形缓冲。

<a id="member-gfruntimeagentenvironment-methods-get_debug_snapshot"></a>

### `get_debug_snapshot`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func get_debug_snapshot() -> Dictionary:
```

获取不含凭据、请求 ID 与业务值的调试快照。

返回：固定形态调试快照。

结构：

- `return`: Dictionary { schema_version: int, protocol_version: int, enabled: bool, endpoint_count: int, active_session_count: int, audit_event_count: int, policy_provider_count: int, handler_active: bool, secrets_stored_as_hashes: bool, owner_thread_access: bool }.

<a id="member-gfruntimeagentenvironment-methods-_get_current_time_msec"></a>

### `_get_current_time_msec`

- API：`protected`
- 首次版本：`10.0.0`

```gdscript
func _get_current_time_msec() -> int:
```

获取环境单调毫秒时钟。 测试实现可覆写此入口；生产实现使用 Time.get_ticks_msec()，不受系统墙钟回拨影响。

返回：单调毫秒值。
