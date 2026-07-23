# Runtime Agent Environment

`GFRuntimeAgentEnvironment` 为运行时自动化、受控本地工具或项目自有 Agent 适配器提供一条传输无关的最小调用边界。宿主只注册明确命名、明确输入输出 Schema 的 endpoint；调用方只能使用短期 session 中被精确授权的 endpoint。

该能力属于可选包 `gf.standard.agent_environment`，依赖 `gf.kernel` 与 `gf.standard.base`。它默认关闭，不会自行监听端口、连接模型服务、扫描项目对象或暴露诊断命令。

## 适用边界

适合：

- 把少量、明确、可审计的项目运行时操作开放给受控自动化；
- 由项目自有传输层在认证后转发版本化请求；
- 为每个调用会话限制 endpoint、有效期、速率和请求总量；
- 在不保存 payload、token 或 handler 输出的前提下记录安全决策事实。

不适合：

- 把任意方法名、反射、`Gf.send_command()` 或开发者控制台直接暴露给外部调用方；
- 直接执行文件、Shell、脚本、资源写入、截图或模型 SDK；
- 代替网络认证、TLS、账号权限、用户确认、操作回滚或操作系统沙箱；
- 防御恶意的同进程 GDScript、GDExtension、策略 Provider 或 endpoint handler。

## 拥有线程与传输边界

每个环境实例在创建时绑定当前线程，不支持转移 ownership。所有公开方法、`enabled` /
`policy_registry` setter，以及 `policy_registry.providers` 和 Provider 字段的原地修改，都必须在
该拥有线程串行执行。项目通常应在主线程创建环境；网络或 IPC worker 只负责解析传输，
再通过 `GFMainThreadDispatchQueue.post()` 或项目等价队列把请求编排回拥有线程，并在该线程
调用 `dispatch()`。

除 `get_debug_snapshot()` 外，跨线程调用 Dictionary 返回入口会以 `owner_thread_required`
fail closed；snapshot 返回带 `owner_thread_access == false` 的固定零值视图。bool/int/void
入口分别返回 false、0 或不执行，setter 也不改变状态。拒绝路径不会触碰 endpoint、session、
限流、防重放或审计 Dictionary，也不会发出审计 signal。直接从 worker 原地修改公开
registry/provider Resource 绕过了环境入口，属于受信宿主违反线程契约；环境不把同进程对象
伪装成线程安全或恶意代码沙箱。

## 最小接入

先在禁用态声明 closed Schema 和 endpoint：

```gdscript
var environment := GFRuntimeAgentEnvironment.new()

var message_field := GFSchemaField.new().configure(
	&"message",
	GFSchemaField.ValueType.STRING,
	{
		"required": true,
		"allow_null": false,
	}
)
var request_schema := GFDictionarySchema.new().configure(
	&"project.agent.echo.request",
	[message_field],
	{
		"allow_extra_fields": false,
		"coerce_values": false,
		"fail_on_coerce_error": true,
	}
)

var accepted_field := GFSchemaField.new().configure(
	&"accepted",
	GFSchemaField.ValueType.BOOL,
	{
		"required": true,
		"allow_null": false,
	}
)
var response_schema := GFDictionarySchema.new().configure(
	&"project.agent.echo.response",
	[accepted_field],
	{
		"allow_extra_fields": false,
		"coerce_values": false,
		"fail_on_coerce_error": true,
	}
)

var registration := environment.register_endpoint(
	"project.echo",
	request_schema,
	response_schema,
	func(request: Dictionary) -> Dictionary:
		var payload: Dictionary = request["payload"]
		print(payload["message"])
		return { "accepted": true }
)
if not registration["ok"]:
	push_error(registration["reason"])
```

环境会保存 Schema 的深副本。注册成功后修改原 Resource 或修改 `get_endpoint_catalog()` 的返回值，都不会改变已注册契约。重复 endpoint ID 不会隐式替换 handler；需要先调用 `unregister_endpoint()`。

由受信宿主显式启用并签发 session：

```gdscript
environment.enabled = true

var opened := environment.open_session(
	PackedStringArray(["project.echo"]),
	{
		"ttl_msec": 60_000,
		"max_requests_per_window": 20,
		"rate_window_msec": 60_000,
		"max_request_ids": 64,
	}
)
if not opened["ok"]:
	push_error(opened["reason"])
	return

var session_id: String = opened["session_id"]
var bearer_token: String = opened["token"]
```

`open_session()` 是受信宿主控制面，不应直接映射为未鉴权的远程接口。token 由 32 个随机字节生成，只在成功结果中返回一次；环境只保存与 session ID 绑定后的完整 SHA-256。调用方和传输层仍必须保护 bearer token，不能写入日志、URL、审计事件或持久化快照。

请求 envelope 与 token 分离：

```gdscript
var result := environment.execute_request(
	{
		"protocol_version": GFRuntimeAgentEnvironment.PROTOCOL_VERSION,
		"session_id": session_id,
		"endpoint_id": "project.echo",
		"request_id": "request-0001",
		"payload": {
			"message": "hello",
		},
	},
	bearer_token
)
```

handler 收到 `protocol_version`、`session_id`、`endpoint_id`、`request_id` 和 `payload`，但永远收不到 token。成功结果才包含 `response`；失败结果只返回版本、状态和稳定原因。

## 严格 Schema 子集

endpoint Schema 不是普通 `GFDictionarySchema` 的全部能力。环境只接受：

- `allow_extra_fields == false`；
- `coerce_values == false`；
- `fail_on_coerce_error == true`；
- 非空、ASCII 稳定的 schema ID 与字段名；
- `BOOL`、`INT`、`FLOAT`、`STRING`、`DICTIONARY`、`ARRAY`；
- `DICTIONARY` 的显式 nested Schema；
- `ARRAY` 的显式 item field；
- 无循环，最大 16 层、512 个 Schema 节点、每个 Dictionary 最多 64 个字段；
- 空 metadata、空 validation rules、null default。

`ANY`、未知枚举、`Object`、`Resource`、`NodePath`、`StringName`、Vector/Color、缺失 nested Schema、开放嵌套结构和 coercion 都会在注册时 fail closed。目录只公开字段名、类型、required/null 规则和嵌套结构，不公开 handler、metadata 或默认值。

请求和响应还必须是 plain JSON tree：

- Dictionary key 只能是 `String`；
- 值只能是 null、bool、JSON 安全整数、有限 float、String、Dictionary 或 Array；
- 拒绝 NaN/INF、超出 `±9_007_199_254_740_991` 的整数、循环引用和 Godot Object；
- 递归拒绝 `__gf_report_value__`、`__gf_variant__`，调用方不能伪造报告 marker；
- 单值最大深度 32、节点数 2048、UTF-8 JSON 64 KiB。

环境在调用 `GFDictionarySchema` 前完成上述原引用预检，避免非 String key 归一化、循环深复制或开放类型的隐式放行。响应只有在 plain JSON、Schema 和精确预算全部通过后才会发布；不会把脱敏、截断或预算 marker 冒充成功业务响应。

## Session、安全顺序与重放

每个 session 保存 endpoint ID 到注册 generation 的精确映射。注销后再注册同名 endpoint 不会恢复旧权限，旧 session 会返回 `endpoint_grant_stale`。

一次执行按以下顺序收敛：

1. 检查环境启用态和 closed envelope；
2. 检查 token 形态，以固定长度摘要比较认证 session；
3. 检查单调时钟 TTL；
4. 对所有已认证尝试计入固定窗口限流，包括越权、重放和 Schema 拒绝；
5. 检查 endpoint grant 与注册 generation；
6. 检查 session 全局 request ID 摘要；
7. 在 payload、策略或 handler 执行前消费 request ID；
8. 校验 plain JSON、硬预算和请求 Schema；
9. 执行项目策略；
10. 复核环境、session、TTL、endpoint generation 和策略注册表；
11. 同步调用受信 handler；
12. 再次复核执行上下文，随后校验并发布响应。

request ID 在整个 session 内唯一，不按 endpoint 分区。`max_request_ids` 达到上限后不会淘汰旧摘要并重新允许重放，而是 fail closed，调用方应关闭旧 session 并由宿主重新签发。

`max_request_ids` 必须大于等于 `max_requests_per_window`。它是 session 生命周期总上限，不会随固定限流窗口重置。

默认与硬上限：

| 项目 | 默认 | 硬上限 |
| --- | ---: | ---: |
| session TTL | 60 秒 | 15 分钟 |
| 固定限流窗口 | 60 秒 | 5 分钟 |
| 每窗口请求 | 60 | 256 |
| session request ID | 256 | 512 |
| 活动 session | — | 32 |
| endpoint | — | 128 |
| 审计事件 | — | 256 |

时间字段来自单调毫秒时钟，不是 Unix 时间；检测到时钟回退会撤销该 session，而不会刷新限流窗口或延长 TTL。把 `enabled` 从 true 切换到 false 会立即清空全部 session；重新启用不会恢复旧凭据。`revoke_session()` 不要求 token，只能由受信宿主控制面调用。

## 策略模型

环境默认持有一个空 `GFPolicyRegistry`。空注册表是明确的中性允许：安全边界仍由“默认关闭 + 显式 endpoint + 精确 session grant + token/TTL/限流/Schema/预算”组成。将 `policy_registry` 设为 null 会 fail closed。session 会绑定签发时的安全上下文 epoch、Provider 顺序/实例，以及 Provider 的 `provider_id`、`display_name`、`supported_artifact_kinds`、`priority`、`input_schema`、`output_schema`、`deterministic` 和 `metadata`。摘要使用排序后的结构化 JSON，不使用可碰撞的分隔符拼接；这些 Dictionary 配置必须是前述预算内的 plain JSON，否则 session 签发以 `policy_configuration_invalid` fail closed。把 `environment.policy_registry` 替换为另一对象会递增 epoch；未通知但持续存在的公开配置漂移也会因摘要不匹配而 fail closed。

`GFPolicyRegistry` 与 Provider 是公开可变 Resource，环境无法观察两次环境调用之间完整发生并恢复的 S1→S2→S1 原地变化。拥有线程在调用 `register_provider()`、`unregister_provider()`、`clear()`，修改 Provider 公开字段，或改变自定义 Provider 的非公开字段、闭包捕获值、外部服务授权状态之前，必须先调用 `invalidate_policy_context()`。该入口递增安全上下文并立即撤销全部 session，因此既覆盖公开配置 ABA，也覆盖无法反射的自定义状态。只改可变策略对象而不通知环境属于 Provider 集成错误。

项目可分别注册支持以下 artifact kind 的 Provider：

- `gf.runtime_agent.session`：在签发 token 前检查 endpoint 集、有效期和请求限制；
- `gf.runtime_agent.request`：在 handler 前检查 session、endpoint、request ID 摘要和 payload。

请求策略可以读取 payload，因此 Provider 也是受信代码，项目必须自行控制其日志、遥测和外部调用。环境只读取汇总 `ok`，不会把策略的 artifact、issues、data 或 metadata 写入响应和审计。需要一次性人工批准、高风险分级、账号身份或业务授权时，应由项目策略和控制面实现；不要把这些决策伪装成通用 endpoint metadata。

## 审计与可观察面

`audit_event_recorded` 与 `get_audit_events()` 只包含固定字段：

- schema/protocol version、单调 sequence 和 timestamp；
- action、outcome、reason；
- session ID、endpoint ID；
- 原始 request ID 的截断 SHA-256 摘要。

`request_id_digest` 只用于同一部署内的相关性，不是匿名化机制；无密钥截断摘要无法抵抗
对低熵、可枚举 ID 的字典猜测。`request_id` 应是 opaque 协议标识，不得编码用户资料、
业务秘密或其他需要保密的语义。

不包含：

- token 或 token hash；
- payload、handler 请求或响应；
- 策略 artifact、issue、data 或 metadata；
- Schema metadata/default；
- 任意对象、路径或业务日志。

`get_debug_snapshot()` 只返回启用态、endpoint/session/audit/provider 数量、执行状态和
`owner_thread_access`。跨线程快照是固定的零值拒绝视图，不读取共享 Dictionary。调用方仍应
把 session ID、endpoint ID 和时间视作可能敏感的运行信息，并按项目保留策略处理。

## 威胁模型与同步限制

该环境保护的是“不可信协议数据进入受信同步 handler”这一层边界，不是 OS sandbox：

- handler、策略 Provider 和审计 signal 监听者均为同进程受信代码，可以访问引擎、读取其他秘密、阻塞主线程或产生副作用；
- 同步回调无法被抢占。回调后 TTL/revision 复核只能阻止发布过时结果，不能回滚已经发生的副作用；
- 默认拒绝 handler 重入另一个 handler，但不能阻止恶意同进程代码绕开环境直接调用项目 API；
- 网络传输、连接认证、加密、来源身份、跨进程隔离和用户批准均由项目或外层适配器负责；
  外层还必须在解码 Dictionary 前限制 frame/body 大小，并对 malformed envelope 与无效凭据
  做连接级限流；64 KiB plain-JSON 预算和 session limiter 不是网络入口的全局 DoS 防线；
- endpoint 应保持小、同步、确定终态和可独立授权。长任务应由 endpoint 创建项目自有的有界操作句柄，而不是在 handler 内阻塞。

关闭服务时调用 `dispose()`，清除 endpoint、session、凭据摘要和内存审计；如果由 `GFArchitecture` 持有，架构释放阶段会调用该生命周期入口。
