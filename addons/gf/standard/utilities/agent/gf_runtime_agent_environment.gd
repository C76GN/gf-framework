## GFRuntimeAgentEnvironment: 传输无关的受限运行时 Agent 调用环境。
##
## 受信宿主显式注册严格 endpoint，再为调用方签发仅授权指定 endpoint 的短期 session。
## 环境负责协议版本、bearer token、TTL、限流、防重放、结构预算、策略检查和无载荷审计；
## 它不提供网络传输、模型客户端、文件或命令执行，也不是进程或脚本沙箱。
## 实例绑定创建线程；所有公开入口与公开策略对象的原地修改都必须在该线程串行执行，
## 外层 transport 应先编排回拥有线程。跨线程公开入口会 fail closed 且不写共享审计状态。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFRuntimeAgentEnvironment
extends GFUtility


# --- 信号 ---

## 追加安全审计事件时触发。
## [br]
## 事件只包含固定协议字段、稳定标识和 request id 摘要，不包含 token、payload、
## handler 输出或策略返回数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param event: 固定字段、无业务载荷的 Runtime Agent 审计事件。
## [br]
## @schema event: Dictionary { schema_version: int, protocol_version: int, sequence: int, timestamp_msec: int, action: String, outcome: String, reason: String, session_id: String, endpoint_id: String, request_id_digest: String }.
signal audit_event_recorded(event: Dictionary)


# --- 常量 ---

## Runtime Agent 请求协议版本。
## [br]
## @api public
## [br]
## @since unreleased
const PROTOCOL_VERSION: int = 1

## Runtime Agent 结果与审计结构版本。
## [br]
## @api public
## [br]
## @since unreleased
const SCHEMA_VERSION: int = 1

const _SESSION_POLICY_KIND: String = "gf.runtime_agent.session"
const _REQUEST_POLICY_KIND: String = "gf.runtime_agent.request"
const _TOKEN_BYTE_COUNT: int = 32
const _TOKEN_TEXT_LENGTH: int = _TOKEN_BYTE_COUNT * 2
const _MAX_IDENTIFIER_LENGTH: int = 128
const _MAX_ENDPOINTS: int = 128
const _MAX_ACTIVE_SESSIONS: int = 32
const _MAX_SCHEMA_DEPTH: int = 16
const _MAX_SCHEMA_NODES: int = 512
const _MAX_SCHEMA_FIELDS: int = 64
const _MAX_VALUE_DEPTH: int = 32
const _MAX_VALUE_NODES: int = 2048
const _MAX_VALUE_BYTES: int = 64 * 1024
const _MAX_AUDIT_EVENTS: int = 256
const _DEFAULT_SESSION_TTL_MSEC: int = 60_000
const _MAX_SESSION_TTL_MSEC: int = 15 * 60_000
const _DEFAULT_RATE_WINDOW_MSEC: int = 60_000
const _MAX_RATE_WINDOW_MSEC: int = 5 * 60_000
const _DEFAULT_MAX_REQUESTS_PER_WINDOW: int = 60
const _MAX_REQUESTS_PER_WINDOW: int = 256
const _DEFAULT_MAX_REQUEST_IDS: int = 256
const _MAX_REQUEST_IDS: int = 512
const _JSON_SAFE_INTEGER_MAX: int = 9_007_199_254_740_991
const _JSON_SAFE_INTEGER_MIN: int = -9_007_199_254_740_991
const _REPORT_MARKER_KEY: String = "__gf_report_value__"
const _VARIANT_MARKER_KEY: String = "__gf_variant__"

const _REQUEST_KEYS: Array[String] = [
	"protocol_version",
	"session_id",
	"endpoint_id",
	"request_id",
	"payload",
]
const _SESSION_OPTION_KEYS: Array[String] = [
	"ttl_msec",
	"max_requests_per_window",
	"rate_window_msec",
	"max_request_ids",
]
const _ALLOWED_SCHEMA_TYPES: Array[int] = [
	GFSchemaField.ValueType.BOOL,
	GFSchemaField.ValueType.INT,
	GFSchemaField.ValueType.FLOAT,
	GFSchemaField.ValueType.STRING,
	GFSchemaField.ValueType.DICTIONARY,
	GFSchemaField.ValueType.ARRAY,
]


# --- 公共变量 ---

## 是否接受新 session 和请求。
##
## 默认 false。由 true 切换为 false 会立即撤销全部 session；再次启用不会恢复旧凭据。
## endpoint 注册会保留，便于宿主先完成声明再显式开放环境。
## [br]
## @api public
## [br]
## @since unreleased
var enabled: bool = false:
	set(value):
		if not _is_owner_thread():
			return
		if enabled == value:
			return
		enabled = value
		_security_context_epoch += 1
		if not enabled:
			_sessions.clear()
			if not _disposing:
				_append_audit("set_enabled", "succeeded", "sessions_revoked", "", "", "")

## session 签发与请求执行使用的策略注册表。
##
## 空注册表表示没有项目附加策略；null 会 fail closed。策略 Provider 属于受信宿主，
## 可以读取当次策略 artifact，但其结果和 artifact 不会复制到 Runtime Agent 响应或审计。
## registry、providers 数组及 Provider 字段的原地修改也必须由环境拥有线程串行完成。
## 原地修改前必须调用 invalidate_policy_context()，以覆盖调用间发生并恢复的 ABA 变化；
## 当前公开配置摘要仍会对未通知但持续存在的配置漂移 fail closed。
## [br]
## @api public
## [br]
## @since unreleased
var policy_registry: GFPolicyRegistry = GFPolicyRegistry.new():
	set(value):
		if not _is_owner_thread():
			return
		if is_same(policy_registry, value):
			return
		policy_registry = value
		_security_context_epoch += 1


# --- 私有变量 ---

var _owner_thread_id: int = 0
var _security_context_epoch: int = 0
var _endpoints: Dictionary = {}
var _sessions: Dictionary = {}
var _audit_events: Array[Dictionary] = []
var _next_endpoint_generation: int = 0
var _next_audit_sequence: int = 0
var _handler_active: bool = false
var _policy_evaluation_active: bool = false
var _disposing: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_owner_thread_id = OS.get_thread_caller_id()


# --- GF 生命周期方法 ---

## 释放 endpoint、session、凭据摘要与内存审计。
## [br]
## 跨拥有线程调用不会改变环境；transport 必须先把控制流编排回拥有线程。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if not _is_owner_thread():
		return
	_disposing = true
	enabled = false
	_endpoints.clear()
	_sessions.clear()
	_audit_events.clear()
	policy_registry = null
	_handler_active = false
	_policy_evaluation_active = false
	_disposing = false


# --- 公共方法 ---

## 注册一个受信 endpoint。
##
## request_schema 与 response_schema 必须是 closed、无 coercion、无 metadata/default/rule，
## 且只使用 JSON 原生字段类型的有限非循环结构。环境保存 schema 副本，注册后调用方修改
## 原 Resource 不会改变 endpoint 契约。重复 ID 必须先显式注销，不会隐式替换 handler。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param endpoint_id: 稳定 endpoint 标识。
## [br]
## @param request_schema: 严格请求 payload schema。
## [br]
## @param response_schema: 严格响应 schema。
## [br]
## @param handler: 同步受信回调；接收不含 token 的请求 Dictionary，返回 Dictionary。
## [br]
## @return 版本化注册结果。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_id?: String }.
func register_endpoint(
	endpoint_id: String,
	request_schema: GFDictionarySchema,
	response_schema: GFDictionarySchema,
	handler: Callable
) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	if not _is_valid_identifier(endpoint_id):
		return _audit_result(
			_make_result(false, "rejected", "invalid_endpoint_id"),
			"register_endpoint",
			"",
			"",
			""
		)
	if _endpoints.has(endpoint_id):
		return _audit_result(
			_make_result(false, "rejected", "endpoint_already_registered", {
				"endpoint_id": endpoint_id,
			}),
			"register_endpoint",
			"",
			endpoint_id,
			""
		)
	if _endpoints.size() >= _MAX_ENDPOINTS:
		return _audit_result(
			_make_result(false, "rejected", "endpoint_limit_reached"),
			"register_endpoint",
			"",
			endpoint_id,
			""
		)
	if not handler.is_valid():
		return _audit_result(
			_make_result(false, "rejected", "invalid_handler"),
			"register_endpoint",
			"",
			endpoint_id,
			""
		)
	if not _is_safe_schema(request_schema):
		return _audit_result(
			_make_result(false, "rejected", "unsafe_request_schema"),
			"register_endpoint",
			"",
			endpoint_id,
			""
		)
	if not _is_safe_schema(response_schema):
		return _audit_result(
			_make_result(false, "rejected", "unsafe_response_schema"),
			"register_endpoint",
			"",
			endpoint_id,
			""
		)

	_next_endpoint_generation += 1
	_endpoints[endpoint_id] = {
		"generation": _next_endpoint_generation,
		"request_schema": request_schema.duplicate_schema(),
		"response_schema": response_schema.duplicate_schema(),
		"handler": handler,
	}
	return _audit_result(
		_make_result(true, "registered", "", {
			"endpoint_id": endpoint_id,
		}),
		"register_endpoint",
		"",
		endpoint_id,
		""
	)


## 注销 endpoint。
##
## 已签发 session 中的旧 grant 不会绑定到后续同名注册；旧请求会以
## endpoint_grant_stale 失败，避免注销/重注册的 ABA 权限恢复。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param endpoint_id: endpoint 标识。
## [br]
## @return 版本化注销结果。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_id?: String }.
func unregister_endpoint(endpoint_id: String) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	if not _is_valid_identifier(endpoint_id):
		return _audit_result(
			_make_result(false, "rejected", "invalid_endpoint_id"),
			"unregister_endpoint",
			"",
			"",
			""
		)
	if not _endpoints.has(endpoint_id):
		return _audit_result(
			_make_result(false, "rejected", "endpoint_not_registered", {
				"endpoint_id": endpoint_id,
			}),
			"unregister_endpoint",
			"",
			endpoint_id,
			""
		)
	var _endpoint_erased: bool = _endpoints.erase(endpoint_id)
	return _audit_result(
		_make_result(true, "unregistered", "", {
			"endpoint_id": endpoint_id,
		}),
		"unregister_endpoint",
		"",
		endpoint_id,
		""
	)


## 获取不含 handler、token、metadata 和默认值的 endpoint 目录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 版本化安全目录。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, endpoint_count?: int, endpoints?: Array[Dictionary { endpoint_id: String, request_schema: Dictionary { schema_id: String, allow_extra_fields: bool, fields: Array[Dictionary] }, response_schema: Dictionary { schema_id: String, allow_extra_fields: bool, fields: Array[Dictionary] } }] }.
func get_endpoint_catalog() -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	var endpoint_ids: Array[String] = []
	for endpoint_key: Variant in _endpoints.keys():
		if not (endpoint_key is String):
			continue
		var endpoint_id: String = endpoint_key
		endpoint_ids.append(endpoint_id)
	endpoint_ids.sort()
	var descriptions: Array[Dictionary] = []
	for endpoint_id: String in endpoint_ids:
		var endpoint: Dictionary = _as_dictionary(_endpoints[endpoint_id])
		var current_request_schema: GFDictionarySchema = _as_schema(endpoint.get("request_schema"))
		var current_response_schema: GFDictionarySchema = _as_schema(endpoint.get("response_schema"))
		descriptions.append({
			"endpoint_id": endpoint_id,
			"request_schema": _describe_safe_schema(current_request_schema),
			"response_schema": _describe_safe_schema(current_response_schema),
		})
	return _make_result(true, "catalog", "", {
		"endpoint_count": descriptions.size(),
		"endpoints": descriptions,
	})


## 为一组精确 endpoint grant 创建短期 session。
##
## 此方法属于受信宿主控制面，不是无需认证的远程 endpoint。返回的 token 只出现一次；
## 环境仅保存与 session id 绑定后的 SHA-256。时间字段使用环境单调毫秒时钟，不是 Unix 时间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param endpoint_ids: session 唯一允许调用的 endpoint ID。
## [br]
## @param options: 严格选项；支持 ttl_msec、max_requests_per_window、rate_window_msec 和 max_request_ids。
## [br]
## @return 成功时包含一次性 token 的版本化 session 凭据；失败时不含 token 字段。
## [br]
## @schema endpoint_ids: PackedStringArray exact endpoint grants.
## [br]
## @schema options: Dictionary { ttl_msec?: int, max_requests_per_window?: int, rate_window_msec?: int, max_request_ids?: int }; no other keys are accepted.
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, session_id?: String, token?: String, endpoint_ids?: Array[String], issued_at_msec?: int, expires_at_msec?: int }; credential fields exist only on success.
func open_session(
	endpoint_ids: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	if _policy_evaluation_active:
		return _audit_result(
			_make_result(false, "rejected", "reentrant_policy_evaluation"),
			"open_session",
			"",
			"",
			""
		)
	if not enabled:
		return _audit_result(
			_make_result(false, "rejected", "environment_disabled"),
			"open_session",
			"",
			"",
			""
		)
	if policy_registry == null:
		return _audit_result(
			_make_result(false, "rejected", "policy_registry_unavailable"),
			"open_session",
			"",
			"",
			""
		)
	var opening_security_context_epoch: int = _security_context_epoch
	var opening_registry: GFPolicyRegistry = policy_registry
	var opening_registry_signature: String = _make_policy_registry_signature(opening_registry)
	if opening_registry_signature.is_empty():
		return _audit_result(
			_make_result(false, "rejected", "policy_configuration_invalid"),
			"open_session",
			"",
			"",
			""
		)
	if endpoint_ids.size() > _MAX_ENDPOINTS:
		return _audit_result(
			_make_result(false, "rejected", "endpoint_grant_limit_exceeded"),
			"open_session",
			"",
			"",
			""
		)
	if options.size() > _SESSION_OPTION_KEYS.size():
		return _audit_result(
			_make_result(false, "rejected", "invalid_session_options"),
			"open_session",
			"",
			"",
			""
		)
	for endpoint_id: String in endpoint_ids:
		if not _is_valid_identifier(endpoint_id):
			return _audit_result(
				_make_result(false, "rejected", "invalid_endpoint_grant"),
				"open_session",
				"",
				"",
				""
			)
	var now_msec: int = _get_current_time_msec()
	var _pruned_session_count: int = _prune_expired_sessions_internal(now_msec)
	if _sessions.size() >= _MAX_ACTIVE_SESSIONS:
		return _audit_result(
			_make_result(false, "rejected", "session_limit_reached"),
			"open_session",
			"",
			"",
			""
		)

	var parsed_options: Dictionary = _parse_session_options(options)
	if not GFVariantData.get_option_bool(parsed_options, "ok"):
		return _audit_result(
			_make_result(false, "rejected", "invalid_session_options"),
			"open_session",
			"",
			"",
			""
		)
	var normalized_endpoint_ids: Array[String] = _normalize_endpoint_ids(endpoint_ids)
	if normalized_endpoint_ids.is_empty():
		return _audit_result(
			_make_result(false, "rejected", "empty_endpoint_grants"),
			"open_session",
			"",
			"",
			""
		)

	var grants: Dictionary = {}
	for endpoint_id: String in normalized_endpoint_ids:
		if not _is_valid_identifier(endpoint_id) or not _endpoints.has(endpoint_id):
			return _audit_result(
				_make_result(false, "rejected", "unknown_endpoint_grant"),
				"open_session",
				"",
				endpoint_id if _is_valid_identifier(endpoint_id) else "",
				""
			)
		var endpoint: Dictionary = _as_dictionary(_endpoints[endpoint_id])
		grants[endpoint_id] = GFVariantData.get_option_int(endpoint, "generation")

	var session_id: String = _make_unique_session_id()
	if session_id.is_empty():
		return _audit_result(
			_make_result(false, "failed", "session_id_generation_failed"),
			"open_session",
			"",
			"",
			""
		)
	var ttl_msec: int = GFVariantData.get_option_int(parsed_options, "ttl_msec")
	var expires_at_msec: int = now_msec + ttl_msec
	var session_policy_artifact: Dictionary = {
		"kind": _SESSION_POLICY_KIND,
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"endpoint_ids": normalized_endpoint_ids.duplicate(),
		"issued_at_msec": now_msec,
		"expires_at_msec": expires_at_msec,
		"limits": {
			"max_requests_per_window": GFVariantData.get_option_int(
				parsed_options,
				"max_requests_per_window"
			),
			"rate_window_msec": GFVariantData.get_option_int(
				parsed_options,
				"rate_window_msec"
			),
			"max_request_ids": GFVariantData.get_option_int(
				parsed_options,
				"max_request_ids"
			),
		},
	}
	var policy_decision: Dictionary = _evaluate_policy(session_policy_artifact, {
		"operation": "open_session",
	})
	if not GFVariantData.get_option_bool(policy_decision, "ok"):
		return _audit_result(
			_make_result(
				false,
				"rejected",
				GFVariantData.get_option_string(policy_decision, "reason", "policy_denied")
			),
			"open_session",
			session_id,
			"",
			""
		)
	if (
		not enabled
		or _security_context_epoch != opening_security_context_epoch
		or not is_same(policy_registry, opening_registry)
		or _make_policy_registry_signature(opening_registry) != opening_registry_signature
		or not _are_grants_current(grants)
	):
		return _audit_result(
			_make_result(false, "rejected", "execution_context_changed"),
			"open_session",
			session_id,
			"",
			""
		)
	if _get_current_time_msec() >= expires_at_msec:
		return _audit_result(
			_make_result(false, "rejected", "session_creation_expired"),
			"open_session",
			session_id,
			"",
			""
		)

	var token: String = _generate_token()
	if token.length() != _TOKEN_TEXT_LENGTH:
		return _audit_result(
			_make_result(false, "failed", "token_generation_failed"),
			"open_session",
			session_id,
			"",
			""
		)
	_sessions[session_id] = {
		"token_hash": _hash_token(session_id, token),
		"grants": grants,
		"issued_at_msec": now_msec,
		"expires_at_msec": expires_at_msec,
		"last_seen_msec": now_msec,
		"max_requests_per_window": GFVariantData.get_option_int(
			parsed_options,
			"max_requests_per_window"
		),
		"rate_window_msec": GFVariantData.get_option_int(
			parsed_options,
			"rate_window_msec"
		),
		"rate_window_started_at_msec": now_msec,
		"requests_in_window": 0,
		"max_request_ids": GFVariantData.get_option_int(parsed_options, "max_request_ids"),
		"request_id_hashes": {},
		"policy_registry_signature": opening_registry_signature,
	}
	var result: Dictionary = _make_result(true, "session_opened", "", {
		"session_id": session_id,
		"token": token,
		"endpoint_ids": normalized_endpoint_ids.duplicate(),
		"issued_at_msec": now_msec,
		"expires_at_msec": expires_at_msec,
	})
	_append_audit("open_session", "succeeded", "", session_id, "", "")
	return result


## 使用凭据关闭 session。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param session_id: session 标识。
## [br]
## @param bearer_token: open_session() 一次返回的 token。
## [br]
## @return 版本化关闭结果。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String }.
func close_session(session_id: String, bearer_token: String) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	var authentication: Dictionary = _authenticate_session(
		session_id,
		bearer_token,
		_get_current_time_msec()
	)
	if not GFVariantData.get_option_bool(authentication, "ok"):
		return _audit_result(
			_make_result(
				false,
				"rejected",
				GFVariantData.get_option_string(authentication, "reason", "invalid_credentials")
			),
			"close_session",
			session_id if _is_valid_identifier(session_id) else "",
			"",
			""
		)
	var _closed_session_erased: bool = _sessions.erase(session_id)
	return _audit_result(
		_make_result(true, "session_closed"),
		"close_session",
		session_id,
		"",
		""
	)


## 由受信宿主按 session id 撤销凭据。
##
## 此入口不要求 bearer token，因此只能放在宿主控制面，不能直接映射为未鉴权远程 endpoint。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param session_id: 待撤销 session 标识。
## [br]
## @return 找到并撤销 session 时返回 true。
func revoke_session(session_id: String) -> bool:
	if not _is_owner_thread():
		return false
	if not _is_valid_identifier(session_id) or not _sessions.has(session_id):
		return false
	var _revoked_session_erased: bool = _sessions.erase(session_id)
	_append_audit("revoke_session", "succeeded", "", session_id, "", "")
	return true


## 使策略上下文的任意原地或外部变化立即失效。
##
## 修改 registry/provider 公开可变对象，或改变无法由环境观察的自定义字段、外部服务状态
## 与闭包捕获值之前，受信宿主必须调用本入口。调用会撤销全部 session，并使正在进行的
## session 签发或请求在回调后的上下文复核中失败。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次撤销的 session 数量；跨拥有线程调用返回 0。
func invalidate_policy_context() -> int:
	if not _is_owner_thread():
		return 0
	var revoked_count: int = _sessions.size()
	_security_context_epoch += 1
	_sessions.clear()
	_append_audit(
		"invalidate_policy_context",
		"succeeded",
		"sessions_revoked",
		"",
		"",
		""
	)
	return revoked_count


## 执行一个版本化 Runtime Agent 请求。
##
## bearer token 与协议请求分离，不会进入 handler、策略响应、目录、调试快照或审计。
## 通过身份和精确 grant 校验后，request id 会在策略与 handler 前被消费；失败请求不能
## 以同一 request id 重试。handler 返回后会复核 session、endpoint generation 和策略注册表
## 身份，发生同步撤销或替换时丢弃输出。handler 已产生的副作用无法回滚。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param request: closed 请求 envelope。
## [br]
## @param bearer_token: session bearer token；不会写入 request 副本。
## [br]
## @return 版本化执行结果；仅成功结果包含 response。
## [br]
## @schema request: Dictionary { protocol_version: int, session_id: String, endpoint_id: String, request_id: String, payload: Dictionary }; exactly these five keys are accepted.
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, response?: Dictionary }; response exists only on success and matches the endpoint response schema.
func execute_request(request: Dictionary, bearer_token: String) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	if _handler_active:
		return _make_result(false, "rejected", "reentrant_execution")
	if _policy_evaluation_active:
		return _make_result(false, "rejected", "reentrant_policy_evaluation")
	if not enabled:
		return _audit_result(
			_make_result(false, "rejected", "environment_disabled"),
			"execute_request",
			"",
			"",
			""
		)
	var envelope_check: Dictionary = _validate_request_envelope(request)
	if not GFVariantData.get_option_bool(envelope_check, "ok"):
		var envelope_reason: String = GFVariantData.get_option_string(
			envelope_check,
			"reason",
			"invalid_request_envelope"
		)
		return _audit_result(
			_make_result(false, "rejected", envelope_reason),
			"execute_request",
			"",
			"",
			""
		)

	var session_id: String = GFVariantData.get_option_string(request, "session_id")
	var endpoint_id: String = GFVariantData.get_option_string(request, "endpoint_id")
	var request_id: String = GFVariantData.get_option_string(request, "request_id")
	var request_id_hash: String = request_id.sha256_text()
	var now_msec: int = _get_current_time_msec()
	var authentication: Dictionary = _authenticate_session(session_id, bearer_token, now_msec)
	if not GFVariantData.get_option_bool(authentication, "ok"):
		return _audit_result(
			_make_result(
				false,
				"rejected",
				GFVariantData.get_option_string(authentication, "reason", "invalid_credentials")
			),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	var session: Dictionary = _as_dictionary(authentication.get("session"))
	var rate_check: Dictionary = _consume_rate_budget(session, now_msec)
	if not GFVariantData.get_option_bool(rate_check, "ok"):
		return _audit_result(
			_make_result(false, "rejected", "rate_limited"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	var grant_check: Dictionary = _validate_session_grant(session, endpoint_id)
	if not GFVariantData.get_option_bool(grant_check, "ok"):
		return _audit_result(
			_make_result(
				false,
				"rejected",
				GFVariantData.get_option_string(grant_check, "reason", "endpoint_not_granted")
			),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var request_id_hashes: Dictionary = _get_session_dictionary(session, "request_id_hashes")
	if request_id_hashes.has(request_id_hash):
		return _audit_result(
			_make_result(false, "rejected", "request_replayed"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	if request_id_hashes.size() >= GFVariantData.get_option_int(session, "max_request_ids"):
		return _audit_result(
			_make_result(false, "rejected", "request_id_budget_exhausted"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	request_id_hashes[request_id_hash] = true
	session["request_id_hashes"] = request_id_hashes

	var payload_value: Variant = request["payload"]
	var payload: Dictionary = payload_value
	var payload_check: Dictionary = _validate_plain_json_value(payload)
	if not GFVariantData.get_option_bool(payload_check, "ok"):
		var payload_error: String = GFVariantData.get_option_string(payload_check, "error")
		var payload_reason: String = (
			"request_budget_exceeded"
			if _is_budget_error(payload_error)
			else "invalid_payload"
		)
		return _audit_result(
			_make_result(false, "rejected", payload_reason),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var endpoint: Dictionary = _as_dictionary(_endpoints.get(endpoint_id))
	var current_request_schema: GFDictionarySchema = _as_schema(endpoint.get("request_schema"))
	if (
		current_request_schema == null
		or not _matches_safe_schema(payload, current_request_schema)
		or not current_request_schema.validate_dictionary(payload).is_ok()
	):
		return _audit_result(
			_make_result(false, "rejected", "request_schema_rejected"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	if policy_registry == null:
		return _audit_result(
			_make_result(false, "rejected", "policy_registry_unavailable"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var endpoint_generation: int = GFVariantData.get_option_int(endpoint, "generation")
	var handler: Callable = _as_callable(endpoint.get("handler"))
	var registry_snapshot: GFPolicyRegistry = policy_registry
	var registry_signature: String = _make_policy_registry_signature(registry_snapshot)
	var safe_payload: Dictionary = payload.duplicate(true)
	var policy_artifact: Dictionary = {
		"kind": _REQUEST_POLICY_KIND,
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"endpoint_id": endpoint_id,
		"request_id_digest": request_id_hash.substr(0, 16),
		"payload": safe_payload.duplicate(true),
	}
	var policy_decision: Dictionary = _evaluate_policy(policy_artifact, {
		"operation": "execute_request",
	})
	if not GFVariantData.get_option_bool(policy_decision, "ok"):
		return _audit_result(
			_make_result(
				false,
				"rejected",
				GFVariantData.get_option_string(policy_decision, "reason", "policy_denied")
			),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	if not _is_execution_context_current(
		session_id,
		endpoint_id,
		endpoint_generation,
		registry_snapshot,
		registry_signature
	):
		return _audit_result(
			_make_result(false, "rejected", "execution_context_changed"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	if not handler.is_valid():
		return _audit_result(
			_make_result(false, "failed", "handler_unavailable"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var handler_request: Dictionary = {
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"endpoint_id": endpoint_id,
		"request_id": request_id,
		"payload": safe_payload.duplicate(true),
	}
	_handler_active = true
	var raw_response: Variant = handler.call(handler_request)
	_handler_active = false
	if not _is_execution_context_current(
		session_id,
		endpoint_id,
		endpoint_generation,
		registry_snapshot,
		registry_signature
	):
		return _audit_result(
			_make_result(false, "rejected", "execution_context_changed"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	if not (raw_response is Dictionary):
		return _audit_result(
			_make_result(false, "failed", "invalid_handler_response"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	var response: Dictionary = raw_response
	var response_check: Dictionary = _validate_plain_json_value(response)
	if not GFVariantData.get_option_bool(response_check, "ok"):
		var response_error: String = GFVariantData.get_option_string(response_check, "error")
		var response_reason: String = (
			"response_budget_exceeded"
			if _is_budget_error(response_error)
			else "invalid_handler_response"
		)
		return _audit_result(
			_make_result(false, "failed", response_reason),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)
	var current_response_schema: GFDictionarySchema = _as_schema(endpoint.get("response_schema"))
	if (
		current_response_schema == null
		or not _matches_safe_schema(response, current_response_schema)
		or not current_response_schema.validate_dictionary(response).is_ok()
	):
		return _audit_result(
			_make_result(false, "failed", "response_schema_rejected"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var encoded_response: Dictionary = GFReportValueCodec.to_report_dictionary(
		response,
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_PRIVACY,
			{
				"max_depth": _MAX_VALUE_DEPTH,
				"max_string_length": _MAX_VALUE_BYTES,
				"max_collection_items": _MAX_VALUE_NODES,
				"max_packed_length": 0,
				"max_total_nodes": _MAX_VALUE_NODES,
				"max_total_bytes": _MAX_VALUE_BYTES,
				"encode_dictionary_keys": false,
				"path_redaction": "none",
			}
		)
	)
	var encoded_check: Dictionary = _validate_plain_json_value(encoded_response)
	if (
		not GFVariantData.get_option_bool(encoded_check, "ok")
		or _contains_report_marker(encoded_response)
		or not _json_values_are_identical(response, encoded_response)
		or not _matches_safe_schema(encoded_response, current_response_schema)
	):
		return _audit_result(
			_make_result(false, "failed", "response_budget_exceeded"),
			"execute_request",
			session_id,
			endpoint_id,
			request_id
		)

	var success_result: Dictionary = _make_result(true, "succeeded", "", {
		"response": encoded_response,
	})
	_append_audit("execute_request", "succeeded", "", session_id, endpoint_id, request_id)
	return success_result


## 删除所有已过期 session。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次删除数量。
func prune_expired_sessions() -> int:
	if not _is_owner_thread():
		return 0
	return _prune_expired_sessions_internal(_get_current_time_msec())


## 获取最近的无载荷安全审计事件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param limit: 最多返回数量；钳制到 0..256。
## [br]
## @return 版本化审计结果。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, ok: bool, status: String, reason: String, event_count?: int, retained_event_count?: int, events?: Array[Dictionary { schema_version: int, protocol_version: int, sequence: int, timestamp_msec: int, action: String, outcome: String, reason: String, session_id: String, endpoint_id: String, request_id_digest: String }] }.
func get_audit_events(limit: int = 64) -> Dictionary:
	if not _is_owner_thread():
		return _make_result(false, "rejected", "owner_thread_required")
	var effective_limit: int = mini(maxi(limit, 0), _MAX_AUDIT_EVENTS)
	var start_index: int = maxi(_audit_events.size() - effective_limit, 0)
	var events: Array[Dictionary] = []
	for index: int in range(start_index, _audit_events.size()):
		events.append(_audit_events[index].duplicate(true))
	return _make_result(true, "audit", "", {
		"event_count": events.size(),
		"retained_event_count": _audit_events.size(),
		"events": events,
	})


## 清空环境内存审计环形缓冲。
## [br]
## @api public
## [br]
## @since unreleased
func clear_audit_events() -> void:
	if not _is_owner_thread():
		return
	_audit_events.clear()


## 获取不含凭据、请求 ID 与业务值的调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 固定形态调试快照。
## [br]
## @schema return: Dictionary { schema_version: int, protocol_version: int, enabled: bool, endpoint_count: int, active_session_count: int, audit_event_count: int, policy_provider_count: int, handler_active: bool, secrets_stored_as_hashes: bool, owner_thread_access: bool }.
func get_debug_snapshot() -> Dictionary:
	if not _is_owner_thread():
		return {
			"schema_version": SCHEMA_VERSION,
			"protocol_version": PROTOCOL_VERSION,
			"enabled": false,
			"endpoint_count": 0,
			"active_session_count": 0,
			"audit_event_count": 0,
			"policy_provider_count": 0,
			"handler_active": false,
			"secrets_stored_as_hashes": true,
			"owner_thread_access": false,
		}
	var provider_count: int = 0
	if policy_registry != null:
		provider_count = policy_registry.providers.size()
	return {
		"schema_version": SCHEMA_VERSION,
		"protocol_version": PROTOCOL_VERSION,
		"enabled": enabled,
		"endpoint_count": _endpoints.size(),
		"active_session_count": _sessions.size(),
		"audit_event_count": _audit_events.size(),
		"policy_provider_count": provider_count,
		"handler_active": _handler_active,
		"secrets_stored_as_hashes": true,
		"owner_thread_access": true,
	}


# --- 可重写钩子 / 虚方法 ---

## 获取环境单调毫秒时钟。
##
## 测试实现可覆写此入口；生产实现使用 Time.get_ticks_msec()，不受系统墙钟回拨影响。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @return 单调毫秒值。
func _get_current_time_msec() -> int:
	return Time.get_ticks_msec()


# --- 私有/辅助方法 ---

func _is_owner_thread() -> bool:
	return (
		_owner_thread_id == 0
		or OS.get_thread_caller_id() == _owner_thread_id
	)


func _validate_request_envelope(request: Dictionary) -> Dictionary:
	if request.size() != _REQUEST_KEYS.size():
		return {
			"ok": false,
			"reason": "invalid_request_envelope",
		}
	for key: Variant in request.keys():
		if not (key is String) or not _REQUEST_KEYS.has(key):
			return {
				"ok": false,
				"reason": "invalid_request_envelope",
			}
	for required_key: String in _REQUEST_KEYS:
		if not request.has(required_key):
			return {
				"ok": false,
				"reason": "invalid_request_envelope",
			}
	if not (request["protocol_version"] is int):
		return {
			"ok": false,
			"reason": "invalid_request_envelope",
		}
	if GFVariantData.get_option_int(request, "protocol_version") != PROTOCOL_VERSION:
		return {
			"ok": false,
			"reason": "unsupported_protocol_version",
		}
	if (
		not (request["session_id"] is String)
		or not (request["endpoint_id"] is String)
		or not (request["request_id"] is String)
		or not (request["payload"] is Dictionary)
	):
		return {
			"ok": false,
			"reason": "invalid_request_envelope",
		}
	if (
		not _is_valid_identifier(GFVariantData.get_option_string(request, "session_id"))
		or not _is_valid_identifier(GFVariantData.get_option_string(request, "endpoint_id"))
		or not _is_valid_identifier(GFVariantData.get_option_string(request, "request_id"))
	):
		return {
			"ok": false,
			"reason": "invalid_request_envelope",
		}
	return { "ok": true }


func _parse_session_options(options: Dictionary) -> Dictionary:
	for key: Variant in options.keys():
		if (
			not (key is String)
			or not _SESSION_OPTION_KEYS.has(key)
			or not (options[key] is int)
		):
			return { "ok": false }
	var ttl_msec: int = _strict_option_int(options, "ttl_msec", _DEFAULT_SESSION_TTL_MSEC)
	var max_requests_per_window: int = _strict_option_int(
		options,
		"max_requests_per_window",
		_DEFAULT_MAX_REQUESTS_PER_WINDOW
	)
	var rate_window_msec: int = _strict_option_int(
		options,
		"rate_window_msec",
		_DEFAULT_RATE_WINDOW_MSEC
	)
	var max_request_ids: int = _strict_option_int(
		options,
		"max_request_ids",
		_DEFAULT_MAX_REQUEST_IDS
	)
	if ttl_msec < 1 or ttl_msec > _MAX_SESSION_TTL_MSEC:
		return { "ok": false }
	if rate_window_msec < 1 or rate_window_msec > _MAX_RATE_WINDOW_MSEC:
		return { "ok": false }
	if (
		max_requests_per_window < 1
		or max_requests_per_window > _MAX_REQUESTS_PER_WINDOW
	):
		return { "ok": false }
	if max_request_ids < max_requests_per_window or max_request_ids > _MAX_REQUEST_IDS:
		return { "ok": false }
	return {
		"ok": true,
		"ttl_msec": ttl_msec,
		"max_requests_per_window": max_requests_per_window,
		"rate_window_msec": rate_window_msec,
		"max_request_ids": max_request_ids,
	}


func _normalize_endpoint_ids(endpoint_ids: PackedStringArray) -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	for endpoint_id: String in endpoint_ids:
		if seen.has(endpoint_id):
			continue
		seen[endpoint_id] = true
		result.append(endpoint_id)
	result.sort()
	return result


func _authenticate_session(
	session_id: String,
	bearer_token: String,
	now_msec: int
) -> Dictionary:
	if (
		not _is_valid_identifier(session_id)
		or not _is_valid_token_text(bearer_token)
		or not _sessions.has(session_id)
	):
		return {
			"ok": false,
			"reason": "invalid_credentials",
		}
	var session: Dictionary = _as_dictionary(_sessions[session_id])
	var expected_hash: String = GFVariantData.get_option_string(session, "token_hash")
	var candidate_hash: String = _hash_token(session_id, bearer_token)
	if not _constant_time_hash_equal(expected_hash, candidate_hash):
		return {
			"ok": false,
			"reason": "invalid_credentials",
		}
	if policy_registry == null:
		var _unavailable_policy_session_erased: bool = _sessions.erase(session_id)
		return {
			"ok": false,
			"reason": "policy_registry_unavailable",
		}
	var current_policy_signature: String = _make_policy_registry_signature(policy_registry)
	if current_policy_signature.is_empty():
		var _invalid_policy_session_erased: bool = _sessions.erase(session_id)
		return {
			"ok": false,
			"reason": "policy_configuration_invalid",
		}
	if (
		current_policy_signature
		!= GFVariantData.get_option_string(session, "policy_registry_signature")
	):
		var _changed_policy_session_erased: bool = _sessions.erase(session_id)
		return {
			"ok": false,
			"reason": "policy_context_changed",
		}
	if now_msec >= GFVariantData.get_option_int(session, "expires_at_msec"):
		var _expired_session_erased: bool = _sessions.erase(session_id)
		return {
			"ok": false,
			"reason": "session_expired",
		}
	if now_msec < GFVariantData.get_option_int(session, "last_seen_msec"):
		var _regressed_session_erased: bool = _sessions.erase(session_id)
		return {
			"ok": false,
			"reason": "session_clock_regressed",
		}
	session["last_seen_msec"] = now_msec
	return {
		"ok": true,
		"session": session,
	}


func _validate_session_grant(session: Dictionary, endpoint_id: String) -> Dictionary:
	var grants: Dictionary = _get_session_dictionary(session, "grants")
	if not grants.has(endpoint_id):
		return {
			"ok": false,
			"reason": "endpoint_not_granted",
		}
	if not _endpoints.has(endpoint_id):
		return {
			"ok": false,
			"reason": "endpoint_grant_stale",
		}
	var endpoint: Dictionary = _as_dictionary(_endpoints[endpoint_id])
	if (
		GFVariantData.get_option_int(endpoint, "generation")
		!= GFVariantData.get_option_int(grants, endpoint_id)
	):
		return {
			"ok": false,
			"reason": "endpoint_grant_stale",
		}
	return { "ok": true }


func _consume_rate_budget(session: Dictionary, now_msec: int) -> Dictionary:
	var window_started_at_msec: int = GFVariantData.get_option_int(
		session,
		"rate_window_started_at_msec"
	)
	var window_msec: int = GFVariantData.get_option_int(session, "rate_window_msec")
	if (
		now_msec < window_started_at_msec
		or now_msec - window_started_at_msec >= window_msec
	):
		session["rate_window_started_at_msec"] = now_msec
		session["requests_in_window"] = 0
	var request_count: int = GFVariantData.get_option_int(session, "requests_in_window")
	if request_count >= GFVariantData.get_option_int(session, "max_requests_per_window"):
		return { "ok": false }
	session["requests_in_window"] = request_count + 1
	return { "ok": true }


func _evaluate_policy(artifact: Dictionary, context: Dictionary) -> Dictionary:
	if policy_registry == null:
		return {
			"ok": false,
			"reason": "policy_registry_unavailable",
		}
	if _policy_evaluation_active:
		return {
			"ok": false,
			"reason": "reentrant_policy_evaluation",
		}
	var registry_snapshot: GFPolicyRegistry = policy_registry
	var registry_signature: String = _make_policy_registry_signature(registry_snapshot)
	if registry_signature.is_empty():
		return {
			"ok": false,
			"reason": "policy_configuration_invalid",
		}
	_policy_evaluation_active = true
	var result: Dictionary = registry_snapshot.evaluate_artifact(
		artifact.duplicate(true),
		context.duplicate(true)
	)
	_policy_evaluation_active = false
	if (
		not is_same(policy_registry, registry_snapshot)
		or _make_policy_registry_signature(registry_snapshot) != registry_signature
	):
		return {
			"ok": false,
			"reason": "policy_context_changed",
		}
	if not GFVariantData.get_option_bool(result, "ok", false):
		return {
			"ok": false,
			"reason": "policy_denied",
		}
	return { "ok": true }


func _make_policy_registry_signature(registry: GFPolicyRegistry) -> String:
	if registry == null:
		return ""
	var provider_snapshots: Array = []
	for provider: GFPolicyProvider in registry.providers:
		if provider == null:
			provider_snapshots.append(null)
			continue
		var supported_artifact_kinds: Array[String] = []
		for artifact_kind: String in provider.supported_artifact_kinds:
			supported_artifact_kinds.append(artifact_kind)
		provider_snapshots.append({
			"instance_id": str(provider.get_instance_id()),
			"provider_id": String(provider.provider_id),
			"display_name": provider.display_name,
			"supported_artifact_kinds": supported_artifact_kinds,
			"priority": str(provider.priority),
			"input_schema": provider.input_schema,
			"output_schema": provider.output_schema,
			"deterministic": provider.deterministic,
			"metadata": provider.metadata,
		})
	var signature_snapshot: Dictionary = {
		"security_context_epoch": str(_security_context_epoch),
		"providers": provider_snapshots,
	}
	if not GFVariantData.get_option_bool(
		_validate_plain_json_value(signature_snapshot),
		"ok"
	):
		return ""
	return JSON.stringify(signature_snapshot, "", true).sha256_text()


func _is_execution_context_current(
	session_id: String,
	endpoint_id: String,
	endpoint_generation: int,
	registry_snapshot: GFPolicyRegistry,
	registry_signature: String
) -> bool:
	if not enabled or not _sessions.has(session_id) or not _endpoints.has(endpoint_id):
		return false
	var session: Dictionary = _as_dictionary(_sessions[session_id])
	if _get_current_time_msec() >= GFVariantData.get_option_int(session, "expires_at_msec"):
		var _context_session_erased: bool = _sessions.erase(session_id)
		return false
	if (
		GFVariantData.get_option_string(session, "policy_registry_signature")
		!= registry_signature
	):
		return false
	var endpoint: Dictionary = _as_dictionary(_endpoints[endpoint_id])
	if GFVariantData.get_option_int(endpoint, "generation") != endpoint_generation:
		return false
	if policy_registry == null or not is_same(policy_registry, registry_snapshot):
		return false
	return _make_policy_registry_signature(registry_snapshot) == registry_signature


func _are_grants_current(grants: Dictionary) -> bool:
	for endpoint_key: Variant in grants.keys():
		if not (endpoint_key is String):
			return false
		var endpoint_id: String = endpoint_key
		if not _endpoints.has(endpoint_id):
			return false
		var endpoint: Dictionary = _as_dictionary(_endpoints[endpoint_id])
		if (
			GFVariantData.get_option_int(endpoint, "generation")
			!= GFVariantData.get_option_int(grants, endpoint_id)
		):
			return false
	return true


func _is_safe_schema(schema: GFDictionarySchema) -> bool:
	if schema == null:
		return false
	var state: Dictionary = {
		"schema_nodes": 0,
		"active_schemas": [],
		"active_fields": [],
	}
	if not _validate_safe_schema_node(schema, state, 0):
		return false
	return schema.validate_definition().is_ok()


func _validate_safe_schema_node(
	schema: GFDictionarySchema,
	state: Dictionary,
	depth: int
) -> bool:
	if schema == null or depth > _MAX_SCHEMA_DEPTH:
		return false
	if _visited_contains(_state_array(state, "active_schemas"), schema):
		return false
	state["schema_nodes"] = GFVariantData.get_option_int(state, "schema_nodes") + 1
	if GFVariantData.get_option_int(state, "schema_nodes") > _MAX_SCHEMA_NODES:
		return false
	if (
		not _is_valid_identifier(String(schema.schema_id))
		or schema.allow_extra_fields
		or schema.coerce_values
		or not schema.fail_on_coerce_error
		or not schema.metadata.is_empty()
		or schema.fields.size() > _MAX_SCHEMA_FIELDS
	):
		return false
	_state_array(state, "active_schemas").append(schema)
	var seen_names: Dictionary = {}
	for field: GFSchemaField in schema.fields:
		if (
			field == null
			or not _validate_safe_field_node(field, state, depth + 1, false)
			or seen_names.has(String(field.field_name))
		):
			var _removed_failed_schema: Variant = _state_array(
				state,
				"active_schemas"
			).pop_back()
			return false
		seen_names[String(field.field_name)] = true
	var _removed_schema: Variant = _state_array(state, "active_schemas").pop_back()
	return true


func _validate_safe_field_node(
	field: GFSchemaField,
	state: Dictionary,
	depth: int,
	is_array_item: bool
) -> bool:
	if field == null or depth > _MAX_SCHEMA_DEPTH:
		return false
	if _visited_contains(_state_array(state, "active_fields"), field):
		return false
	state["schema_nodes"] = GFVariantData.get_option_int(state, "schema_nodes") + 1
	if GFVariantData.get_option_int(state, "schema_nodes") > _MAX_SCHEMA_NODES:
		return false
	if not _ALLOWED_SCHEMA_TYPES.has(field.value_type):
		return false
	if (
		not field.metadata.is_empty()
		or not field.validation_rules.is_empty()
		or field.default_value != null
	):
		return false
	if is_array_item:
		if field.field_name != &"" or field.required:
			return false
	elif not _is_valid_identifier(String(field.field_name)):
		return false

	_state_array(state, "active_fields").append(field)
	var valid: bool = true
	match field.value_type:
		GFSchemaField.ValueType.DICTIONARY:
			valid = (
				field.array_item_schema == null
				and _validate_safe_schema_node(field.dictionary_schema, state, depth + 1)
			)
		GFSchemaField.ValueType.ARRAY:
			valid = (
				field.dictionary_schema == null
				and _validate_safe_field_node(field.array_item_schema, state, depth + 1, true)
			)
		_:
			valid = field.dictionary_schema == null and field.array_item_schema == null
	var _removed_field: Variant = _state_array(state, "active_fields").pop_back()
	return valid


func _describe_safe_schema(schema: GFDictionarySchema) -> Dictionary:
	var fields: Array[Dictionary] = []
	if schema != null:
		for field: GFSchemaField in schema.fields:
			fields.append(_describe_safe_field(field))
	return {
		"schema_id": String(schema.schema_id) if schema != null else "",
		"allow_extra_fields": false,
		"fields": fields,
	}


func _describe_safe_field(field: GFSchemaField) -> Dictionary:
	var result: Dictionary = {
		"name": String(field.field_name),
		"type": _schema_type_name(field.value_type),
		"required": field.required,
		"allow_null": field.allow_null,
	}
	if field.value_type == GFSchemaField.ValueType.DICTIONARY:
		result["dictionary_schema"] = _describe_safe_schema(field.dictionary_schema)
	elif field.value_type == GFSchemaField.ValueType.ARRAY:
		result["array_item_schema"] = _describe_safe_field(field.array_item_schema)
	return result


func _schema_type_name(value_type: GFSchemaField.ValueType) -> String:
	match value_type:
		GFSchemaField.ValueType.BOOL:
			return "bool"
		GFSchemaField.ValueType.INT:
			return "int"
		GFSchemaField.ValueType.FLOAT:
			return "float"
		GFSchemaField.ValueType.STRING:
			return "string"
		GFSchemaField.ValueType.DICTIONARY:
			return "dictionary"
		GFSchemaField.ValueType.ARRAY:
			return "array"
	return "unsupported"


func _matches_safe_schema(values: Dictionary, schema: GFDictionarySchema) -> bool:
	if schema == null or values.size() > schema.fields.size():
		return false
	var fields_by_name: Dictionary = {}
	for field: GFSchemaField in schema.fields:
		if field == null:
			return false
		var field_name: String = String(field.field_name)
		fields_by_name[field_name] = field
		if field.required and not values.has(field_name):
			return false
	for key: Variant in values.keys():
		if not (key is String) or not fields_by_name.has(key):
			return false
		var field: GFSchemaField = fields_by_name[key]
		if not _matches_safe_field(values[key], field):
			return false
	return true


func _matches_safe_field(value: Variant, field: GFSchemaField) -> bool:
	if field == null:
		return false
	if value == null:
		return field.allow_null
	match field.value_type:
		GFSchemaField.ValueType.BOOL:
			return value is bool
		GFSchemaField.ValueType.INT:
			return value is int
		GFSchemaField.ValueType.FLOAT:
			return value is int or value is float
		GFSchemaField.ValueType.STRING:
			return value is String
		GFSchemaField.ValueType.DICTIONARY:
			if not (value is Dictionary):
				return false
			var dictionary_value: Dictionary = value
			return _matches_safe_schema(dictionary_value, field.dictionary_schema)
		GFSchemaField.ValueType.ARRAY:
			if not (value is Array):
				return false
			var array_value: Array = value
			for item: Variant in array_value:
				if not _matches_safe_field(item, field.array_item_schema):
					return false
			return true
	return false


func _validate_plain_json_value(value: Variant) -> Dictionary:
	var state: Dictionary = {
		"node_count": 0,
		"work_bytes": 0,
		"visited": [],
	}
	var error: String = _validate_plain_json_node(value, state, 0)
	if not error.is_empty():
		return {
			"ok": false,
			"error": error,
		}
	var json_text: String = JSON.stringify(value)
	var byte_count: int = json_text.to_utf8_buffer().size()
	if byte_count > _MAX_VALUE_BYTES:
		return {
			"ok": false,
			"error": "max_bytes_exceeded",
		}
	return {
		"ok": true,
		"node_count": GFVariantData.get_option_int(state, "node_count"),
		"byte_count": byte_count,
	}


func _validate_plain_json_node(
	value: Variant,
	state: Dictionary,
	depth: int
) -> String:
	if depth > _MAX_VALUE_DEPTH:
		return "max_depth_exceeded"
	state["node_count"] = GFVariantData.get_option_int(state, "node_count") + 1
	if GFVariantData.get_option_int(state, "node_count") > _MAX_VALUE_NODES:
		return "max_nodes_exceeded"

	match typeof(value):
		TYPE_NIL:
			return _consume_json_work_bytes(state, 4)
		TYPE_BOOL:
			return _consume_json_work_bytes(state, 5)
		TYPE_INT:
			var integer_value: int = value
			if integer_value < _JSON_SAFE_INTEGER_MIN or integer_value > _JSON_SAFE_INTEGER_MAX:
				return "unsafe_integer"
			return _consume_json_work_bytes(state, 24)
		TYPE_FLOAT:
			var float_value: float = value
			if is_nan(float_value) or is_inf(float_value):
				return "non_finite_number"
			return _consume_json_work_bytes(state, 32)
		TYPE_STRING:
			var string_value: String = value
			if string_value.length() > _MAX_VALUE_BYTES:
				return "max_bytes_exceeded"
			return _consume_json_work_bytes(state, string_value.to_utf8_buffer().size() + 2)
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			if _visited_contains(_state_array(state, "visited"), dictionary_value):
				return "circular_reference"
			_state_array(state, "visited").append(dictionary_value)
			var dictionary_budget_error: String = _consume_json_work_bytes(state, 2)
			if not dictionary_budget_error.is_empty():
				var _removed_budget_dictionary: Variant = _state_array(
					state,
					"visited"
				).pop_back()
				return dictionary_budget_error
			for key: Variant in dictionary_value:
				if not (key is String):
					var _removed_invalid_key_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return "invalid_dictionary_key"
				var key_text: String = key
				if key_text == _REPORT_MARKER_KEY or key_text == _VARIANT_MARKER_KEY:
					var _removed_reserved_key_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return "reserved_marker"
				if key_text.length() > _MAX_VALUE_BYTES:
					var _removed_oversized_key_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return "max_bytes_exceeded"
				state["node_count"] = GFVariantData.get_option_int(state, "node_count") + 1
				if GFVariantData.get_option_int(state, "node_count") > _MAX_VALUE_NODES:
					var _removed_node_budget_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return "max_nodes_exceeded"
				var key_budget_error: String = _consume_json_work_bytes(
					state,
					key_text.to_utf8_buffer().size() + 3
				)
				if not key_budget_error.is_empty():
					var _removed_key_budget_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return key_budget_error
				var child_error: String = _validate_plain_json_node(
					dictionary_value[key],
					state,
					depth + 1
				)
				if not child_error.is_empty():
					var _removed_child_dictionary: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return child_error
			var _removed_dictionary: Variant = _state_array(state, "visited").pop_back()
			return ""
		TYPE_ARRAY:
			var array_value: Array = value
			if _visited_contains(_state_array(state, "visited"), array_value):
				return "circular_reference"
			_state_array(state, "visited").append(array_value)
			var array_budget_error: String = _consume_json_work_bytes(state, 2)
			if not array_budget_error.is_empty():
				var _removed_budget_array: Variant = _state_array(state, "visited").pop_back()
				return array_budget_error
			for item: Variant in array_value:
				var child_error: String = _validate_plain_json_node(item, state, depth + 1)
				if not child_error.is_empty():
					var _removed_child_array: Variant = _state_array(
						state,
						"visited"
					).pop_back()
					return child_error
			var _removed_array: Variant = _state_array(state, "visited").pop_back()
			return ""
		_:
			return "non_json_value"


func _consume_json_work_bytes(state: Dictionary, amount: int) -> String:
	state["work_bytes"] = GFVariantData.get_option_int(state, "work_bytes") + maxi(amount, 0)
	if GFVariantData.get_option_int(state, "work_bytes") > _MAX_VALUE_BYTES:
		return "max_bytes_exceeded"
	return ""


func _contains_report_marker(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		if dictionary_value.has(_REPORT_MARKER_KEY) or dictionary_value.has(_VARIANT_MARKER_KEY):
			return true
		for child: Variant in dictionary_value.values():
			if _contains_report_marker(child):
				return true
	elif value is Array:
		var array_value: Array = value
		for child: Variant in array_value:
			if _contains_report_marker(child):
				return true
	return false


func _json_values_are_identical(left: Variant, right: Variant) -> bool:
	return JSON.stringify(left, "", true) == JSON.stringify(right, "", true)


func _is_budget_error(error: String) -> bool:
	return error in [
		"max_depth_exceeded",
		"max_nodes_exceeded",
		"max_bytes_exceeded",
	]


func _prune_expired_sessions_internal(now_msec: int) -> int:
	var expired_ids: Array[String] = []
	for session_key: Variant in _sessions.keys():
		if not (session_key is String):
			continue
		var session_id: String = session_key
		var session: Dictionary = _as_dictionary(_sessions[session_id])
		if now_msec >= GFVariantData.get_option_int(session, "expires_at_msec"):
			expired_ids.append(session_id)
	for session_id: String in expired_ids:
		var _pruned_session_erased: bool = _sessions.erase(session_id)
		_append_audit("prune_session", "succeeded", "session_expired", session_id, "", "")
	return expired_ids.size()


func _make_unique_session_id() -> String:
	for _attempt: int in range(4):
		var candidate: String = GFUuid.generate_v4()
		if _is_valid_identifier(candidate) and not _sessions.has(candidate):
			return candidate
	return ""


func _generate_token() -> String:
	var crypto: Crypto = Crypto.new()
	return crypto.generate_random_bytes(_TOKEN_BYTE_COUNT).hex_encode()


func _hash_token(session_id: String, token: String) -> String:
	return ("%s:%s" % [session_id, token]).sha256_text()


func _constant_time_hash_equal(left: String, right: String) -> bool:
	if left.length() != 64 or right.length() != 64:
		return false
	var mismatch: int = 0
	for index: int in range(64):
		mismatch |= left.unicode_at(index) ^ right.unicode_at(index)
	return mismatch == 0


func _is_valid_token_text(token: String) -> bool:
	if token.length() != _TOKEN_TEXT_LENGTH:
		return false
	for index: int in range(token.length()):
		var character_code: int = token.unicode_at(index)
		if not (
			(character_code >= 48 and character_code <= 57)
			or (character_code >= 97 and character_code <= 102)
		):
			return false
	return true


func _is_valid_identifier(value: String) -> bool:
	if value.is_empty() or value.length() > _MAX_IDENTIFIER_LENGTH:
		return false
	for index: int in range(value.length()):
		var character_code: int = value.unicode_at(index)
		var allowed: bool = (
			(character_code >= 48 and character_code <= 57)
			or (character_code >= 65 and character_code <= 90)
			or (character_code >= 97 and character_code <= 122)
			or character_code in [45, 46, 47, 58, 95]
		)
		if not allowed:
			return false
	return true


func _append_audit(
	action: String,
	outcome: String,
	reason: String,
	session_id: String,
	endpoint_id: String,
	request_id: String
) -> void:
	_next_audit_sequence += 1
	var event: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"protocol_version": PROTOCOL_VERSION,
		"sequence": _next_audit_sequence,
		"timestamp_msec": _get_current_time_msec(),
		"action": action,
		"outcome": outcome,
		"reason": reason,
		"session_id": session_id,
		"endpoint_id": endpoint_id,
		"request_id_digest": request_id.sha256_text().substr(0, 16) if not request_id.is_empty() else "",
	}
	_audit_events.append(event)
	while _audit_events.size() > _MAX_AUDIT_EVENTS:
		_audit_events.remove_at(0)
	audit_event_recorded.emit(event.duplicate(true))


func _audit_result(
	result: Dictionary,
	action: String,
	session_id: String,
	endpoint_id: String,
	request_id: String
) -> Dictionary:
	var outcome: String = (
		"succeeded"
		if GFVariantData.get_option_bool(result, "ok")
		else GFVariantData.get_option_string(result, "status", "rejected")
	)
	_append_audit(
		action,
		outcome,
		GFVariantData.get_option_string(result, "reason"),
		session_id,
		endpoint_id,
		request_id
	)
	return result


func _make_result(
	ok: bool,
	status: String,
	reason: String = "",
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"protocol_version": PROTOCOL_VERSION,
		"ok": ok,
		"status": status,
		"reason": reason,
	}
	for key: Variant in extra.keys():
		result[key] = extra[key]
	return result


func _strict_option_int(options: Dictionary, key: String, default_value: int) -> int:
	if options.has(key):
		var value: Variant = options[key]
		if value is int:
			return value
	return default_value


func _get_session_dictionary(session: Dictionary, key: String) -> Dictionary:
	var value: Variant = session.get(key)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _state_array(state: Dictionary, key: String) -> Array:
	var value: Variant = state.get(key)
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


func _visited_contains(visited: Array, value: Variant) -> bool:
	for existing: Variant in visited:
		if is_same(existing, value):
			return true
	return false


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value
	return {}


func _as_schema(value: Variant) -> GFDictionarySchema:
	if value is GFDictionarySchema:
		var schema: GFDictionarySchema = value
		return schema
	return null


func _as_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable_value: Callable = value
		return callable_value
	return Callable()
