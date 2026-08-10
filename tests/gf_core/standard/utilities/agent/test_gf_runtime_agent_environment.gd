## 测试 Runtime Agent Environment 的传输无关协议与默认拒绝安全边界。
extends GutTest


var environment: ManualClockEnvironment
var handler: RecordingHandler
var request_schema: GFDictionarySchema
var response_schema: GFDictionarySchema


func before_each() -> void:
	environment = ManualClockEnvironment.new()
	environment.current_time_msec = 10_000
	handler = RecordingHandler.new()
	request_schema = _make_schema(&"agent.echo.request", [
		_make_field(&"message", GFSchemaField.ValueType.STRING, {
			"required": true,
			"allow_null": false,
		}),
	])
	response_schema = _make_schema(&"agent.echo.response", [
		_make_field(&"accepted", GFSchemaField.ValueType.BOOL, {
			"required": true,
			"allow_null": false,
		}),
		_make_field(&"echo", GFSchemaField.ValueType.STRING, {
			"required": true,
			"allow_null": false,
		}),
	])


func after_each() -> void:
	environment.dispose()


func test_environment_is_disabled_by_default_and_does_not_issue_credentials() -> void:
	var registration: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	var opened: Dictionary = environment.open_session(PackedStringArray(["echo"]))

	assert_true(GFVariantData.get_option_bool(registration, "ok"), "禁用态应允许受信宿主预注册 endpoint。")
	assert_false(environment.enabled, "Runtime Agent Environment 必须默认关闭。")
	assert_false(GFVariantData.get_option_bool(opened, "ok"), "禁用态不得签发 session。")
	assert_eq(GFVariantData.get_option_string(opened, "reason"), "environment_disabled")
	assert_false(opened.has("token"), "拒绝结果不得包含 token 字段。")


func test_registration_requires_closed_json_only_schema_and_rejects_duplicates() -> void:
	var open_schema: GFDictionarySchema = request_schema.duplicate_schema()
	open_schema.allow_extra_fields = true
	var unsafe_schema: GFDictionarySchema = _make_schema(&"agent.unsafe.request", [
		_make_field(&"value", GFSchemaField.ValueType.ANY),
	])
	var recursive_schema: GFDictionarySchema = _make_schema(&"agent.recursive.request")
	var recursive_field: GFSchemaField = _make_field(
		&"child",
		GFSchemaField.ValueType.DICTIONARY,
		{ "dictionary_schema": recursive_schema }
	)
	var _recursive_field_added: bool = recursive_schema.add_field(recursive_field)

	var open_result: Dictionary = environment.register_endpoint(
		"open",
		open_schema,
		response_schema,
		handler.handle
	)
	var unsafe_result: Dictionary = environment.register_endpoint(
		"unsafe",
		unsafe_schema,
		response_schema,
		handler.handle
	)
	var recursive_result: Dictionary = environment.register_endpoint(
		"recursive",
		recursive_schema,
		response_schema,
		handler.handle
	)
	var first: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	var duplicate_result: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)

	assert_false(GFVariantData.get_option_bool(open_result, "ok"), "允许额外字段的 schema 必须被拒绝。")
	assert_eq(GFVariantData.get_option_string(open_result, "reason"), "unsafe_request_schema")
	assert_false(GFVariantData.get_option_bool(unsafe_result, "ok"), "ANY 等非 JSON 严格类型必须被拒绝。")
	assert_false(GFVariantData.get_option_bool(recursive_result, "ok"), "循环 schema 必须 fail closed。")
	assert_true(GFVariantData.get_option_bool(first, "ok"), "严格 schema 应可注册。")
	assert_false(GFVariantData.get_option_bool(duplicate_result, "ok"), "重复 endpoint 不得隐式替换 handler。")
	assert_eq(GFVariantData.get_option_string(duplicate_result, "reason"), "endpoint_already_registered")
	recursive_field.dictionary_schema = null


func test_catalog_exposes_only_structural_schema_without_handler_metadata_or_defaults() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)

	var catalog: Dictionary = environment.get_endpoint_catalog()
	var endpoints: Array = GFVariantData.get_option_array(catalog, "endpoints")
	var endpoint: Dictionary = GFVariantData.as_dictionary(endpoints[0])
	var described_request: Dictionary = GFVariantData.get_option_dictionary(endpoint, "request_schema")
	var fields: Array = GFVariantData.get_option_array(described_request, "fields")
	var field: Dictionary = GFVariantData.as_dictionary(fields[0])

	assert_eq(GFVariantData.get_option_int(catalog, "protocol_version"), 1)
	assert_eq(GFVariantData.get_option_string(endpoint, "endpoint_id"), "echo")
	assert_false(endpoint.has("handler"), "目录不得暴露 Callable。")
	assert_false(described_request.has("metadata"), "目录不得暴露 schema metadata。")
	assert_false(field.has("metadata"), "目录不得暴露字段 metadata。")
	assert_false(field.has("default_value"), "目录不得暴露默认值。")
	assert_eq(GFVariantData.get_option_string(field, "type"), "string")


func test_session_uses_exact_grants_and_token_is_absent_from_public_observability() -> void:
	var secondary_handler: RecordingHandler = RecordingHandler.new()
	var _echo_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	var _secondary_registered: Dictionary = environment.register_endpoint(
		"secondary",
		request_schema,
		response_schema,
		secondary_handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")

	var denied: Dictionary = environment.execute_request(
		_make_request(session_id, "secondary", "request-1", { "message": "private-payload" }),
		token
	)
	var observable_text: String = JSON.stringify({
		"catalog": environment.get_endpoint_catalog(),
		"debug": environment.get_debug_snapshot(),
		"audit": environment.get_audit_events(),
	})
	var token_hash: String = ("%s:%s" % [session_id, token]).sha256_text()
	var internal_session_text: String = JSON.stringify(environment._sessions)

	assert_eq(token.length(), 64, "token 应由 32 个随机字节编码。")
	assert_false(GFVariantData.get_option_bool(denied, "ok"), "session 不得调用未授权 endpoint。")
	assert_eq(GFVariantData.get_option_string(denied, "reason"), "endpoint_not_granted")
	assert_eq(secondary_handler.call_count, 0, "越权请求不得触发 handler。")
	assert_eq(observable_text.find(token), -1, "目录、快照与审计不得包含明文 token。")
	assert_eq(observable_text.find(token_hash), -1, "公开可观察面也不得包含 token hash。")
	assert_eq(observable_text.find("private-payload"), -1, "审计不得复制业务载荷。")
	assert_eq(internal_session_text.find(token), -1, "session 内部状态不得保存明文 token。")
	assert_true(internal_session_text.find(token_hash) >= 0, "session 内部只保存绑定 session id 的 token hash。")


func test_valid_request_calls_handler_once_without_forwarding_token() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")

	var result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "request-1", { "message": "hello" }),
		token
	)
	var response: Dictionary = GFVariantData.get_option_dictionary(result, "response")
	var callback_text: String = JSON.stringify(handler.last_request)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "合法请求应成功。")
	assert_eq(GFVariantData.get_option_string(result, "status"), "succeeded")
	assert_eq(GFVariantData.get_option_string(response, "echo"), "hello")
	assert_eq(handler.call_count, 1, "每个 request id 最多调用一次 handler。")
	assert_eq(callback_text.find(token), -1, "handler request 不得包含 bearer token。")
	assert_eq(GFVariantData.get_option_int(handler.last_request, "protocol_version"), 1)


func test_envelope_payload_and_protocol_are_strictly_validated_before_callback() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"max_requests_per_window": 12,
		"max_request_ids": 12,
	})
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var extra_envelope: Dictionary = _make_request(
		session_id,
		"echo",
		"request-extra-envelope",
		{ "message": "hello" }
	)
	extra_envelope["unexpected"] = true
	var wrong_version: Dictionary = _make_request(
		session_id,
		"echo",
		"request-version",
		{ "message": "hello" }
	)
	wrong_version["protocol_version"] = 2
	var cyclic_payload: Dictionary = {}
	cyclic_payload["message"] = cyclic_payload
	var results: Array[Dictionary] = [
		environment.execute_request(extra_envelope, token),
		environment.execute_request(wrong_version, token),
		environment.execute_request(
			_make_request(session_id, "echo", "request-extra-payload", {
				"message": "hello",
				"extra": true,
			}),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "request-object", {
				"message": RefCounted.new(),
			}),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "request-cycle", cyclic_payload),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "request-bytes", {
				"message": "x".repeat(70_000),
			}),
			token
		),
	]

	for result: Dictionary in results:
		assert_false(GFVariantData.get_option_bool(result, "ok"), "非法 envelope 或 payload 必须拒绝。")
	assert_eq(handler.call_count, 0, "任何协议、结构或预算错误都不得调用 handler。")
	assert_eq(GFVariantData.get_option_string(results[0], "reason"), "invalid_request_envelope")
	assert_eq(GFVariantData.get_option_string(results[1], "reason"), "unsupported_protocol_version")
	assert_eq(GFVariantData.get_option_string(results[2], "reason"), "request_schema_rejected")
	assert_eq(GFVariantData.get_option_string(results[3], "reason"), "invalid_payload")
	assert_eq(GFVariantData.get_option_string(results[4], "reason"), "invalid_payload")
	assert_eq(GFVariantData.get_option_string(results[5], "reason"), "request_budget_exceeded")


func test_invalid_token_and_replayed_request_never_call_handler_twice() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var request: Dictionary = _make_request(
		session_id,
		"echo",
		"request-replay",
		{ "message": "hello" }
	)

	var invalid_token_result: Dictionary = environment.execute_request(request, "0".repeat(64))
	var first: Dictionary = environment.execute_request(request, token)
	var replay: Dictionary = environment.execute_request(request, token)

	assert_false(GFVariantData.get_option_bool(invalid_token_result, "ok"), "错误凭据必须拒绝。")
	assert_eq(GFVariantData.get_option_string(invalid_token_result, "reason"), "invalid_credentials")
	assert_true(GFVariantData.get_option_bool(first, "ok"), "首次合法请求应成功。")
	assert_false(GFVariantData.get_option_bool(replay, "ok"), "相同 request id 不得重放。")
	assert_eq(GFVariantData.get_option_string(replay, "reason"), "request_replayed")
	assert_eq(handler.call_count, 1, "错误凭据与重放都不得增加 handler 调用。")


func test_session_ttl_and_fixed_window_rate_limit_fail_closed() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var rate_session: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"ttl_msec": 1_000,
		"max_requests_per_window": 2,
		"rate_window_msec": 100,
		"max_request_ids": 8,
	})
	var rate_token: String = GFVariantData.get_option_string(rate_session, "token")
	var rate_session_id: String = GFVariantData.get_option_string(rate_session, "session_id")

	var first: Dictionary = environment.execute_request(
		_make_request(rate_session_id, "echo", "rate-1", { "message": "one" }),
		rate_token
	)
	var second: Dictionary = environment.execute_request(
		_make_request(rate_session_id, "echo", "rate-2", { "message": "two" }),
		rate_token
	)
	var limited: Dictionary = environment.execute_request(
		_make_request(rate_session_id, "echo", "rate-3", { "message": "three" }),
		rate_token
	)
	environment.current_time_msec += 101
	var reset: Dictionary = environment.execute_request(
		_make_request(rate_session_id, "echo", "rate-4", { "message": "four" }),
		rate_token
	)
	environment.current_time_msec += 900
	var expired: Dictionary = environment.execute_request(
		_make_request(rate_session_id, "echo", "rate-5", { "message": "five" }),
		rate_token
	)

	assert_true(GFVariantData.get_option_bool(first, "ok"))
	assert_true(GFVariantData.get_option_bool(second, "ok"))
	assert_false(GFVariantData.get_option_bool(limited, "ok"), "固定窗口超限必须拒绝。")
	assert_eq(GFVariantData.get_option_string(limited, "reason"), "rate_limited")
	assert_true(GFVariantData.get_option_bool(reset, "ok"), "新窗口应恢复请求额度。")
	assert_false(GFVariantData.get_option_bool(expired, "ok"), "过期 session 必须拒绝。")
	assert_eq(GFVariantData.get_option_string(expired, "reason"), "session_expired")
	assert_eq(handler.call_count, 3, "限流与过期请求不得触发 handler。")


func test_request_policy_denial_consumes_request_id_without_exposing_policy_payload() -> void:
	var denying_provider: DenyingPolicyProvider = DenyingPolicyProvider.new()
	var _configured_provider: GFPolicyProvider = denying_provider.configure(
		&"deny_runtime_agent",
		PackedStringArray(["gf.runtime_agent.request"])
	)
	var _provider_registered: bool = environment.policy_registry.register_provider(denying_provider)
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var request: Dictionary = _make_request(
		session_id,
		"echo",
		"policy-request",
		{ "message": "policy-secret" }
	)

	var denied: Dictionary = environment.execute_request(request, token)
	var replay: Dictionary = environment.execute_request(request, token)
	var observable_text: String = JSON.stringify({
		"denied": denied,
		"audit": environment.get_audit_events(),
	})

	assert_false(GFVariantData.get_option_bool(denied, "ok"), "策略拒绝必须阻断请求。")
	assert_eq(GFVariantData.get_option_string(denied, "reason"), "policy_denied")
	assert_eq(handler.call_count, 0, "策略拒绝不得调用 handler。")
	assert_eq(GFVariantData.get_option_string(replay, "reason"), "request_replayed", "已决策的 request id 不得复用。")
	assert_eq(observable_text.find("policy-secret"), -1, "策略输入 payload 不得复制到结果或审计。")


func test_response_schema_and_budget_failures_do_not_escape_handler_output() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")

	handler.response_override = {
		"accepted": true,
		"echo": 42,
	}
	var schema_rejected: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "response-schema", { "message": "hello" }),
		token
	)
	handler.response_override = {
		"accepted": true,
		"echo": "x".repeat(70_000),
	}
	var budget_rejected: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "response-budget", { "message": "hello" }),
		token
	)

	assert_false(GFVariantData.get_option_bool(schema_rejected, "ok"))
	assert_eq(GFVariantData.get_option_string(schema_rejected, "reason"), "response_schema_rejected")
	assert_false(schema_rejected.has("response"), "失败结果不得带出非法 handler 输出。")
	assert_false(GFVariantData.get_option_bool(budget_rejected, "ok"))
	assert_eq(GFVariantData.get_option_string(budget_rejected, "reason"), "response_budget_exceeded")
	assert_false(budget_rejected.has("response"), "超预算输出不得截断后冒充成功。")
	assert_eq(handler.call_count, 2, "输出失败发生在受信 handler 返回后。")


func test_handler_output_plain_json_failures_never_escape() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"max_requests_per_window": 12,
		"max_request_ids": 12,
	})
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var circular_response: Dictionary = {}
	circular_response["self"] = circular_response
	var deep_response: Variant = "leaf"
	for _index: int in range(40):
		deep_response = { "child": deep_response }
	var many_response_nodes: Array = []
	for index: int in range(2_100):
		many_response_nodes.append(index)
	var raw_responses: Array = [
		"not-a-dictionary",
		{ "accepted": true, "echo": NAN },
		{ "accepted": true, "echo": RefCounted.new() },
		{ "accepted": true, "echo": "ok", "__gf_variant__": {} },
		circular_response,
		{ "accepted": true, "echo": "ok", "deep": deep_response },
		{ "accepted": true, "echo": "ok", "nodes": many_response_nodes },
	]
	var expected_reasons: Array[String] = [
		"invalid_handler_response",
		"invalid_handler_response",
		"invalid_handler_response",
		"invalid_handler_response",
		"invalid_handler_response",
		"response_budget_exceeded",
		"response_budget_exceeded",
	]
	var results: Array[Dictionary] = []
	handler.use_raw_response_override = true
	for index: int in range(raw_responses.size()):
		handler.raw_response_override = raw_responses[index]
		results.append(environment.execute_request(
			_make_request(
				session_id,
				"echo",
				"unsafe-response-%d" % index,
				{ "message": "hello" }
			),
			token
		))

	for index: int in range(results.size()):
		assert_false(GFVariantData.get_option_bool(results[index], "ok"))
		assert_eq(
			GFVariantData.get_option_string(results[index], "reason"),
			expected_reasons[index]
		)
		assert_false(results[index].has("response"), "非法 handler 输出不得进入失败结果。")
	assert_eq(handler.call_count, raw_responses.size())


func test_unregister_reregister_does_not_resurrect_old_session_grant() -> void:
	var replacement_handler: RecordingHandler = RecordingHandler.new()
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var _unregistered: Dictionary = environment.unregister_endpoint("echo")
	var _reregistered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		replacement_handler.handle
	)

	var result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "request-stale", { "message": "hello" }),
		token
	)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "同名重注册不得恢复旧 grant。")
	assert_eq(GFVariantData.get_option_string(result, "reason"), "endpoint_grant_stale")
	assert_eq(handler.call_count, 0)
	assert_eq(replacement_handler.call_count, 0, "旧 session 不得触发 replacement handler。")


func test_callback_context_revocation_discards_result_and_reentrant_execution_is_rejected() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	handler.on_call = func() -> void:
		handler.nested_result = environment.execute_request(
			_make_request(session_id, "echo", "nested-request", { "message": "nested" }),
			token
		)
		var _revoked: bool = environment.revoke_session(session_id)

	var result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "outer-request", { "message": "outer" }),
		token
	)

	assert_eq(handler.call_count, 1, "同步 handler 执行期间不得重入另一个 handler。")
	assert_eq(GFVariantData.get_option_string(handler.nested_result, "reason"), "reentrant_execution")
	assert_false(GFVariantData.get_option_bool(result, "ok"), "回调期间 session 被撤销时不得发布输出。")
	assert_eq(GFVariantData.get_option_string(result, "reason"), "execution_context_changed")
	assert_false(result.has("response"))


func test_disabling_environment_revokes_existing_sessions() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")

	environment.enabled = false
	environment.enabled = true
	var result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "request-after-disable", { "message": "hello" }),
		token
	)

	assert_false(GFVariantData.get_option_bool(result, "ok"), "关闭环境必须立即撤销所有 session。")
	assert_eq(GFVariantData.get_option_string(result, "reason"), "invalid_credentials")
	assert_eq(handler.call_count, 0)


func test_audit_uses_request_digest_and_never_keeps_raw_request_id() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var request_id: String = "request.audit.raw-id"
	var _result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", request_id, { "message": "audit-payload-secret" }),
		token
	)

	var audit: Dictionary = environment.get_audit_events()
	var events: Array = GFVariantData.get_option_array(audit, "events")
	var last_event: Dictionary = GFVariantData.as_dictionary(events.back())
	var audit_text: String = JSON.stringify(audit)

	assert_eq(GFVariantData.get_option_string(last_event, "action"), "execute_request")
	assert_eq(last_event.size(), 10, "审计事件必须保持固定字段集。")
	assert_true(GFVariantData.get_option_string(last_event, "request_id_digest").length() >= 16)
	assert_eq(audit_text.find(request_id), -1, "审计不得保存原始 request id。")
	assert_eq(audit_text.find("audit-payload-secret"), -1, "审计不得保存业务 payload。")
	assert_eq(audit_text.find(token), -1, "审计不得保存 token。")


func test_audit_listener_reentry_is_drained_without_recursive_signal_emission() -> void:
	var listener_state: Dictionary = {
		"depth": 0,
		"max_depth": 0,
		"reentered": false,
	}
	var observed_sequences: Array[int] = []
	var _audit_listener_connected: Error = environment.audit_event_recorded.connect(func(event: Dictionary) -> void:
		listener_state["depth"] = GFVariantData.get_option_int(listener_state, "depth") + 1
		listener_state["max_depth"] = maxi(
			GFVariantData.get_option_int(listener_state, "max_depth"),
			GFVariantData.get_option_int(listener_state, "depth")
		)
		observed_sequences.append(GFVariantData.get_option_int(event, "sequence"))
		if not GFVariantData.get_option_bool(listener_state, "reentered"):
			listener_state["reentered"] = true
			var _nested_rejected: Dictionary = environment.register_endpoint(
				"",
				null,
				null,
				Callable()
			)
		listener_state["depth"] = GFVariantData.get_option_int(listener_state, "depth") - 1
	) as Error

	var _initial_rejected: Dictionary = environment.register_endpoint("", null, null, Callable())

	assert_eq(observed_sequences, [1, 2], "重入产生的审计应按 sequence 迭代派发。")
	assert_eq(
		GFVariantData.get_option_int(listener_state, "max_depth"),
		1,
		"审计 listener 发起 audited API 时不得递归 emit。"
	)


func test_audit_listener_reentry_has_bounded_notification_work_and_retention() -> void:
	var listener_state: Dictionary = {
		"depth": 0,
		"max_depth": 0,
		"notification_count": 0,
	}
	var _audit_listener_connected: Error = environment.audit_event_recorded.connect(func(_event: Dictionary) -> void:
		listener_state["depth"] = GFVariantData.get_option_int(listener_state, "depth") + 1
		listener_state["max_depth"] = maxi(
			GFVariantData.get_option_int(listener_state, "max_depth"),
			GFVariantData.get_option_int(listener_state, "depth")
		)
		listener_state["notification_count"] = (
			GFVariantData.get_option_int(listener_state, "notification_count") + 1
		)
		if GFVariantData.get_option_int(listener_state, "notification_count") < 300:
			var _nested_rejected: Dictionary = environment.register_endpoint(
				"",
				null,
				null,
				Callable()
			)
		listener_state["depth"] = GFVariantData.get_option_int(listener_state, "depth") - 1
	) as Error

	var _initial_rejected: Dictionary = environment.register_endpoint("", null, null, Callable())
	var audit: Dictionary = environment.get_audit_events(256)
	var retained_events: Array = GFVariantData.get_option_array(audit, "events")
	var last_event: Dictionary = GFVariantData.as_dictionary(retained_events.back())

	assert_eq(
		GFVariantData.get_option_int(listener_state, "notification_count"),
		256,
		"单次同步 drain 最多派发 256 个审计通知。"
	)
	assert_eq(
		GFVariantData.get_option_int(listener_state, "max_depth"),
		1,
		"持续重入也只能形成迭代通知，不能增加调用栈深度。"
	)
	assert_eq(retained_events.size(), 256, "实时通知截断不能突破审计 ring 的保留上限。")
	assert_eq(
		GFVariantData.get_option_int(last_event, "sequence"),
		257,
		"第 256 个 listener 产生的记录仍应进入审计 ring，只丢弃超预算实时通知。"
	)


func test_audit_ring_is_bounded_returns_deep_copies_and_can_be_cleared() -> void:
	for _index: int in range(300):
		var _rejected: Dictionary = environment.register_endpoint(
			"",
			request_schema,
			response_schema,
			handler.handle
		)
	var audit: Dictionary = environment.get_audit_events(999)
	var events: Array = GFVariantData.get_option_array(audit, "events")
	var first_event: Dictionary = GFVariantData.as_dictionary(events.front())
	var last_event: Dictionary = GFVariantData.as_dictionary(events.back())
	first_event["action"] = "tampered"
	var fresh_audit: Dictionary = environment.get_audit_events(999)
	var fresh_events: Array = GFVariantData.get_option_array(fresh_audit, "events")
	var fresh_first_event: Dictionary = GFVariantData.as_dictionary(fresh_events.front())

	assert_eq(GFVariantData.get_option_int(audit, "retained_event_count"), 256)
	assert_eq(events.size(), 256)
	assert_eq(GFVariantData.get_option_int(last_event, "sequence"), 300)
	assert_eq(GFVariantData.get_option_string(fresh_first_event, "action"), "register_endpoint")
	environment.clear_audit_events()
	var cleared: Dictionary = environment.get_audit_events()
	assert_eq(GFVariantData.get_option_int(cleared, "event_count"), 0)
	assert_eq(GFVariantData.get_option_int(cleared, "retained_event_count"), 0)


func test_prune_and_dispose_leave_no_runtime_state() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var _opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"ttl_msec": 100,
	})
	environment.current_time_msec += 100

	var pruned_count: int = environment.prune_expired_sessions()
	var after_prune: Dictionary = environment.get_debug_snapshot()
	environment.dispose()
	var after_dispose: Dictionary = environment.get_debug_snapshot()

	assert_eq(pruned_count, 1)
	assert_eq(GFVariantData.get_option_int(after_prune, "active_session_count"), 0)
	assert_false(GFVariantData.get_option_bool(after_dispose, "enabled"))
	assert_eq(GFVariantData.get_option_int(after_dispose, "endpoint_count"), 0)
	assert_eq(GFVariantData.get_option_int(after_dispose, "active_session_count"), 0)
	assert_eq(GFVariantData.get_option_int(after_dispose, "audit_event_count"), 0)
	assert_eq(GFVariantData.get_option_int(after_dispose, "policy_provider_count"), 0)
	assert_true(GFVariantData.get_option_bool(after_dispose, "owner_thread_access"))


func test_nested_schema_contract_is_closed_and_registration_uses_an_immutable_copy() -> void:
	var open_nested_schema: GFDictionarySchema = _make_schema(&"agent.nested.open")
	open_nested_schema.allow_extra_fields = true
	var outer_schema: GFDictionarySchema = _make_schema(&"agent.outer.request", [
		_make_field(&"nested", GFSchemaField.ValueType.DICTIONARY, {
			"dictionary_schema": open_nested_schema,
		}),
	])
	var missing_nested_schema: GFDictionarySchema = _make_schema(&"agent.missing.request", [
		_make_field(&"nested", GFSchemaField.ValueType.DICTIONARY),
	])
	var metadata_schema: GFDictionarySchema = request_schema.duplicate_schema()
	metadata_schema.metadata = { "private": RefCounted.new() }

	var open_nested_result: Dictionary = environment.register_endpoint(
		"nested-open",
		outer_schema,
		response_schema,
		handler.handle
	)
	var missing_nested_result: Dictionary = environment.register_endpoint(
		"nested-missing",
		missing_nested_schema,
		response_schema,
		handler.handle
	)
	var metadata_result: Dictionary = environment.register_endpoint(
		"metadata",
		metadata_schema,
		response_schema,
		handler.handle
	)
	var registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	request_schema.allow_extra_fields = true
	request_schema.fields[0].value_type = GFSchemaField.ValueType.INT
	var first_catalog: Dictionary = environment.get_endpoint_catalog()
	var first_endpoints: Array = GFVariantData.get_option_array(first_catalog, "endpoints")
	var first_endpoint: Dictionary = GFVariantData.as_dictionary(first_endpoints[0])
	first_endpoint["request_schema"] = {}
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var result: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(opened, "session_id"),
			"echo",
			"immutable-schema",
			{ "message": "hello" }
		),
		GFVariantData.get_option_string(opened, "token")
	)

	assert_false(GFVariantData.get_option_bool(open_nested_result, "ok"), "嵌套开放 schema 必须拒绝。")
	assert_false(GFVariantData.get_option_bool(missing_nested_result, "ok"), "缺失嵌套 schema 必须拒绝。")
	assert_false(GFVariantData.get_option_bool(metadata_result, "ok"), "schema metadata 不得进入安全契约。")
	assert_true(GFVariantData.get_option_bool(registered, "ok"))
	assert_true(GFVariantData.get_option_bool(result, "ok"), "原 schema 或目录副本修改不得改变已注册契约。")
	assert_eq(GFVariantData.get_option_string(
		GFVariantData.get_option_dictionary(result, "response"),
		"echo"
	), "hello")


func test_nested_array_schema_executes_and_registration_deep_copies_all_children() -> void:
	var item_dictionary_schema: GFDictionarySchema = _make_schema(&"agent.items.item", [
		_make_field(&"value", GFSchemaField.ValueType.STRING, {
			"required": true,
			"allow_null": false,
		}),
	])
	var item_field: GFSchemaField = _make_field(
		&"",
		GFSchemaField.ValueType.DICTIONARY,
		{
			"allow_null": false,
			"dictionary_schema": item_dictionary_schema,
		}
	)
	var array_field: GFSchemaField = _make_field(
		&"items",
		GFSchemaField.ValueType.ARRAY,
		{
			"required": true,
			"allow_null": false,
			"array_item_schema": item_field,
		}
	)
	var array_schema: GFDictionarySchema = _make_schema(
		&"agent.items.request",
		[array_field]
	)
	var registered: Dictionary = environment.register_endpoint(
		"items",
		array_schema,
		response_schema,
		handler.handle
	)
	array_field.array_item_schema.value_type = GFSchemaField.ValueType.INT
	item_dictionary_schema.fields[0].value_type = GFSchemaField.ValueType.INT
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["items"]))
	var result: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(opened, "session_id"),
			"items",
			"nested-array",
			{
				"items": [
					{ "value": "one" },
					{ "value": "two" },
				],
			}
		),
		GFVariantData.get_option_string(opened, "token")
	)

	assert_true(GFVariantData.get_option_bool(registered, "ok"))
	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"注册后修改数组 item 与 nested schema 不得改变保存的深副本。"
	)
	assert_eq(handler.call_count, 1)


func test_plain_json_preflight_rejects_non_string_keys_markers_and_unsafe_numbers() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"max_requests_per_window": 8,
		"max_request_ids": 8,
	})
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var non_string_key_payload: Dictionary = {}
	non_string_key_payload[&"message"] = "hello"
	var results: Array[Dictionary] = [
		environment.execute_request(
			_make_request(session_id, "echo", "json-key", non_string_key_payload),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "json-marker", {
				"message": "hello",
				"__gf_report_value__": {},
			}),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "json-nan", { "message": NAN }),
			token
		),
		environment.execute_request(
			_make_request(session_id, "echo", "json-int", {
				"message": 9_007_199_254_740_992,
			}),
			token
		),
	]

	for result: Dictionary in results:
		assert_false(GFVariantData.get_option_bool(result, "ok"))
		assert_eq(GFVariantData.get_option_string(result, "reason"), "invalid_payload")
	assert_eq(handler.call_count, 0, "JSON 预检失败不得进入 schema 或 handler。")


func test_empty_policy_registry_is_neutral_while_null_and_session_policy_denial_fail_closed() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	environment.policy_registry = null
	var null_open: Dictionary = environment.open_session(PackedStringArray(["echo"]))
	environment.policy_registry = GFPolicyRegistry.new()
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	environment.policy_registry = null
	var null_execute: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(opened, "session_id"),
			"echo",
			"null-policy",
			{ "message": "hello" }
		),
		GFVariantData.get_option_string(opened, "token")
	)
	var session_deny_registry: GFPolicyRegistry = GFPolicyRegistry.new()
	var session_denier: DenyingPolicyProvider = DenyingPolicyProvider.new()
	var _configured_denier: GFPolicyProvider = session_denier.configure(
		&"deny_runtime_agent_session",
		PackedStringArray(["gf.runtime_agent.session"])
	)
	var _denier_registered: bool = session_deny_registry.register_provider(session_denier)
	environment.policy_registry = session_deny_registry
	var denied_open: Dictionary = environment.open_session(PackedStringArray(["echo"]))

	assert_eq(GFVariantData.get_option_string(null_open, "reason"), "policy_registry_unavailable")
	assert_false(null_open.has("token"), "null registry 拒绝不得签发 token。")
	assert_false(GFVariantData.get_option_bool(null_execute, "ok"), "执行时 null registry 必须 fail closed。")
	assert_eq(GFVariantData.get_option_string(null_execute, "reason"), "policy_registry_unavailable")
	assert_false(GFVariantData.get_option_bool(denied_open, "ok"), "session 策略拒绝不得签发凭据。")
	assert_eq(GFVariantData.get_option_string(denied_open, "reason"), "policy_denied")
	assert_false(denied_open.has("token"))
	assert_eq(handler.call_count, 0)


func test_session_policy_cannot_issue_credentials_after_disabling_environment() -> void:
	var disabling_provider: DisablingSessionPolicyProvider = DisablingSessionPolicyProvider.new()
	disabling_provider.environment = environment
	var _configured_provider: GFPolicyProvider = disabling_provider.configure(
		&"disable_during_runtime_agent_session",
		PackedStringArray(["gf.runtime_agent.session"])
	)
	var _provider_registered: bool = environment.policy_registry.register_provider(
		disabling_provider
	)
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true

	var opened: Dictionary = environment.open_session(PackedStringArray(["echo"]))
	var snapshot: Dictionary = environment.get_debug_snapshot()

	assert_false(GFVariantData.get_option_bool(opened, "ok"))
	assert_eq(GFVariantData.get_option_string(opened, "reason"), "policy_context_changed")
	assert_false(opened.has("token"), "策略回调改变启用上下文后不得签发 token。")
	assert_false(environment.enabled)
	assert_eq(GFVariantData.get_option_int(snapshot, "active_session_count"), 0)


func test_policy_receives_a_copy_and_policy_revocation_prevents_handler_execution() -> void:
	var mutating_provider: MutatingPolicyProvider = MutatingPolicyProvider.new()
	var _configured_provider: GFPolicyProvider = mutating_provider.configure(
		&"mutating_runtime_agent_policy",
		PackedStringArray(["gf.runtime_agent.request"])
	)
	var _provider_registered: bool = environment.policy_registry.register_provider(mutating_provider)
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	mutating_provider.environment = environment
	mutating_provider.session_id = session_id

	var copied_payload_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "policy-copy", { "message": "original" }),
		token
	)
	mutating_provider.revoke_session = true
	var revoked_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "policy-revoke", { "message": "second" }),
		token
	)

	assert_true(GFVariantData.get_option_bool(copied_payload_result, "ok"))
	assert_eq(GFVariantData.get_option_string(
		GFVariantData.get_option_dictionary(copied_payload_result, "response"),
		"echo"
	), "original", "策略对 artifact 的修改不得污染 handler payload。")
	assert_false(GFVariantData.get_option_bool(revoked_result, "ok"))
	assert_eq(GFVariantData.get_option_string(revoked_result, "reason"), "execution_context_changed")
	assert_eq(handler.call_count, 1, "策略期间撤销 session 后不得调用 handler。")


func test_policy_registry_definition_change_invalidates_existing_session() -> void:
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var added_provider: DenyingPolicyProvider = DenyingPolicyProvider.new()
	var _configured_provider: GFPolicyProvider = added_provider.configure(
		&"added_after_session",
		PackedStringArray(["gf.runtime_agent.request"])
	)
	var _provider_registered: bool = environment.policy_registry.register_provider(added_provider)

	var changed: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "policy-changed", { "message": "hello" }),
		token
	)
	var revoked: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "policy-revoked", { "message": "hello" }),
		token
	)

	assert_eq(GFVariantData.get_option_string(changed, "reason"), "policy_context_changed")
	assert_eq(GFVariantData.get_option_string(revoked, "reason"), "invalid_credentials")
	assert_eq(handler.call_count, 0, "策略集合改变后旧 session 不得继续执行。")


func test_policy_signature_is_structured_and_covers_public_provider_configuration() -> void:
	var delimiter_provider: DenyingPolicyProvider = DenyingPolicyProvider.new()
	var _delimiter_configured: GFPolicyProvider = delimiter_provider.configure(
		&"delimiter_sensitive_policy",
		PackedStringArray(["gf.runtime_agent.request", "other"])
	)
	var _delimiter_registered: bool = environment.policy_registry.register_provider(
		delimiter_provider
	)
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var delimiter_session: Dictionary = _open_session(PackedStringArray(["echo"]))
	delimiter_provider.supported_artifact_kinds = PackedStringArray([
		"gf.runtime_agent.request,other",
	])
	var delimiter_result: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(delimiter_session, "session_id"),
			"echo",
			"policy-delimiter",
			{ "message": "hello" }
		),
		GFVariantData.get_option_string(delimiter_session, "token")
	)

	var _cleared_policy_sessions: int = environment.invalidate_policy_context()
	environment.policy_registry.clear()
	var metadata_provider: MetadataPolicyProvider = MetadataPolicyProvider.new()
	var _metadata_configured: GFPolicyProvider = metadata_provider.configure(
		&"metadata_policy",
		PackedStringArray(["gf.runtime_agent.request"]),
		{ "allow": false }
	)
	var _metadata_registered: bool = environment.policy_registry.register_provider(
		metadata_provider
	)
	var metadata_session: Dictionary = _open_session(PackedStringArray(["echo"]))
	metadata_provider.metadata["allow"] = true
	var metadata_result: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(metadata_session, "session_id"),
			"echo",
			"policy-metadata",
			{ "message": "hello" }
		),
		GFVariantData.get_option_string(metadata_session, "token")
	)
	var _invalidated_public_policy: int = environment.invalidate_policy_context()
	metadata_provider.metadata = { "unsafe": RefCounted.new() }
	var invalid_configuration: Dictionary = environment.open_session(
		PackedStringArray(["echo"])
	)

	assert_eq(
		GFVariantData.get_option_string(delimiter_result, "reason"),
		"policy_context_changed",
		"结构化签名必须区分 kind 数组与包含逗号的单个 kind。"
	)
	assert_eq(
		GFVariantData.get_option_string(metadata_result, "reason"),
		"policy_context_changed",
		"公开 Provider 配置改变后旧 session 不得沿用。"
	)
	assert_eq(
		GFVariantData.get_option_string(invalid_configuration, "reason"),
		"policy_configuration_invalid",
		"非 plain-JSON Provider 配置不得参与 session 签发。"
	)
	assert_eq(handler.call_count, 0)


func test_custom_policy_state_requires_explicit_context_invalidation() -> void:
	var toggle_provider: TogglePolicyProvider = TogglePolicyProvider.new()
	var _configured_provider: GFPolicyProvider = toggle_provider.configure(
		&"custom_state_policy",
		PackedStringArray(["gf.runtime_agent.request"])
	)
	var _provider_registered: bool = environment.policy_registry.register_provider(toggle_provider)
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var revoked_count: int = environment.invalidate_policy_context()
	toggle_provider.allow_requests = true

	var stale_result: Dictionary = environment.execute_request(
		_make_request(
			GFVariantData.get_option_string(opened, "session_id"),
			"echo",
			"custom-policy-state",
			{ "message": "hello" }
		),
		GFVariantData.get_option_string(opened, "token")
	)

	assert_eq(revoked_count, 1)
	assert_eq(GFVariantData.get_option_string(stale_result, "reason"), "invalid_credentials")
	assert_eq(handler.call_count, 0)


func test_non_owner_thread_cannot_mutate_or_execute_environment() -> void:
	var _endpoint_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var target_environment: GFRuntimeAgentEnvironment = environment
	var request: Dictionary = _make_request(
		GFVariantData.get_option_string(opened, "session_id"),
		"echo",
		"worker-request",
		{ "message": "hello" }
	)
	var token: String = GFVariantData.get_option_string(opened, "token")
	var audit_before: int = GFVariantData.get_option_int(
		environment.get_audit_events(),
		"retained_event_count"
	)
	var worker: Thread = Thread.new()
	var start_error: Error = worker.start(func() -> Dictionary:
		target_environment.enabled = false
		return {
			"unregister": target_environment.unregister_endpoint("echo"),
			"execute": target_environment.execute_request(request, token),
			"snapshot": target_environment.get_debug_snapshot(),
		}
	)
	assert_eq(start_error, OK, "跨线程拒绝测试 worker 应启动成功。")
	if start_error != OK:
		return
	var worker_value: Variant = worker.wait_to_finish()
	var worker_record: Dictionary = (
		worker_value
		if worker_value is Dictionary
		else {}
	)
	var unregister_result: Dictionary = GFVariantData.get_option_dictionary(
		worker_record,
		"unregister"
	)
	var execute_result: Dictionary = GFVariantData.get_option_dictionary(
		worker_record,
		"execute"
	)
	var worker_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		worker_record,
		"snapshot"
	)
	var audit_after: int = GFVariantData.get_option_int(
		environment.get_audit_events(),
		"retained_event_count"
	)

	assert_eq(
		GFVariantData.get_option_string(unregister_result, "reason"),
		"owner_thread_required"
	)
	assert_eq(
		GFVariantData.get_option_string(execute_result, "reason"),
		"owner_thread_required"
	)
	assert_false(GFVariantData.get_option_bool(worker_snapshot, "owner_thread_access", true))
	assert_true(environment.enabled, "跨线程 setter 不得改变启用态。")
	assert_eq(
		GFVariantData.get_option_int(environment.get_endpoint_catalog(), "endpoint_count"),
		1
	)
	assert_eq(audit_after, audit_before, "跨线程拒绝不得写共享审计缓冲。")
	assert_eq(handler.call_count, 0)


func test_valid_large_and_path_like_response_strings_are_not_truncated_or_redacted() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var path_like_text: String = "C:/private/data/session.json"
	handler.response_override = {
		"accepted": true,
		"echo": path_like_text,
	}
	var path_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "response-path", { "message": "hello" }),
		token
	)
	var large_text: String = "x".repeat(10_000)
	handler.response_override = {
		"accepted": true,
		"echo": large_text,
	}
	var large_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "response-large", { "message": "hello" }),
		token
	)

	assert_eq(GFVariantData.get_option_string(
		GFVariantData.get_option_dictionary(path_result, "response"),
		"echo"
	), path_like_text, "合法业务字符串不得被报告 codec 路径脱敏。")
	assert_eq(GFVariantData.get_option_string(
		GFVariantData.get_option_dictionary(large_result, "response"),
		"echo"
	).length(), large_text.length(), "预算内字符串不得被静默截断。")


func test_handler_result_is_discarded_when_ttl_expires_during_callback() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"ttl_msec": 100,
	})
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	handler.on_call = func() -> void:
		environment.current_time_msec += 100

	var result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "expires-in-handler", { "message": "hello" }),
		token
	)

	assert_eq(handler.call_count, 1)
	assert_false(GFVariantData.get_option_bool(result, "ok"))
	assert_eq(GFVariantData.get_option_string(result, "reason"), "execution_context_changed")
	assert_false(result.has("response"), "回调期间过期时不得发布 handler 输出。")


func test_monotonic_clock_regression_revokes_session() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	environment.current_time_msec -= 1

	var regressed: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "clock-regressed", { "message": "hello" }),
		token
	)
	var revoked: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "clock-revoked", { "message": "hello" }),
		token
	)

	assert_eq(GFVariantData.get_option_string(regressed, "reason"), "session_clock_regressed")
	assert_eq(GFVariantData.get_option_string(revoked, "reason"), "invalid_credentials")
	assert_eq(handler.call_count, 0, "时钟回退不得刷新窗口或延长 session。")


func test_schema_depth_and_payload_depth_node_budgets_are_hard() -> void:
	var nested_schema: GFDictionarySchema = _make_schema(&"agent.depth.leaf", [
		_make_field(&"value", GFSchemaField.ValueType.STRING),
	])
	for index: int in range(10):
		nested_schema = _make_schema(StringName("agent.depth.%d" % index), [
			_make_field(&"child", GFSchemaField.ValueType.DICTIONARY, {
				"dictionary_schema": nested_schema,
			}),
		])
	var schema_result: Dictionary = environment.register_endpoint(
		"too-deep",
		nested_schema,
		response_schema,
		handler.handle
	)
	var _echo_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var deep_value: Variant = "leaf"
	for index: int in range(40):
		deep_value = { "child": deep_value }
	var deep_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "payload-depth", { "message": deep_value }),
		token
	)
	var many_nodes: Array = []
	for index: int in range(2_100):
		many_nodes.append(index)
	var node_result: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "payload-nodes", { "message": many_nodes }),
		token
	)

	assert_false(GFVariantData.get_option_bool(schema_result, "ok"), "超深 schema 必须在注册时拒绝。")
	assert_eq(GFVariantData.get_option_string(schema_result, "reason"), "unsafe_request_schema")
	assert_eq(GFVariantData.get_option_string(deep_result, "reason"), "request_budget_exceeded")
	assert_eq(GFVariantData.get_option_string(node_result, "reason"), "request_budget_exceeded")
	assert_eq(handler.call_count, 0)


func test_session_options_grants_and_capacity_limits_are_closed() -> void:
	var _echo_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var empty_grants: Dictionary = environment.open_session(PackedStringArray())
	var invalid_grant: Dictionary = environment.open_session(PackedStringArray(["bad grant"]))
	var unknown_grant: Dictionary = environment.open_session(PackedStringArray(["missing"]))
	var unknown_option: Dictionary = environment.open_session(
		PackedStringArray(["echo"]),
		{ "unknown": 1 }
	)
	var wrong_option_type: Dictionary = environment.open_session(
		PackedStringArray(["echo"]),
		{ "ttl_msec": "100" }
	)
	var inconsistent_limits: Dictionary = environment.open_session(
		PackedStringArray(["echo"]),
		{
			"max_requests_per_window": 2,
			"max_request_ids": 1,
		}
	)
	var duplicate_grants: Dictionary = environment.open_session(
		PackedStringArray(["echo", "echo"])
	)

	var registered_count: int = 1
	for index: int in range(127):
		var registration: Dictionary = environment.register_endpoint(
			"limit-%03d" % index,
			request_schema,
			response_schema,
			handler.handle
		)
		if GFVariantData.get_option_bool(registration, "ok"):
			registered_count += 1
	var endpoint_overflow: Dictionary = environment.register_endpoint(
		"limit-overflow",
		request_schema,
		response_schema,
		handler.handle
	)
	var opened_count: int = 1
	for _index: int in range(31):
		var opened: Dictionary = environment.open_session(PackedStringArray(["echo"]))
		if GFVariantData.get_option_bool(opened, "ok"):
			opened_count += 1
	var session_overflow: Dictionary = environment.open_session(PackedStringArray(["echo"]))

	assert_eq(GFVariantData.get_option_string(empty_grants, "reason"), "empty_endpoint_grants")
	assert_eq(GFVariantData.get_option_string(invalid_grant, "reason"), "invalid_endpoint_grant")
	assert_eq(GFVariantData.get_option_string(unknown_grant, "reason"), "unknown_endpoint_grant")
	assert_eq(GFVariantData.get_option_string(unknown_option, "reason"), "invalid_session_options")
	assert_eq(GFVariantData.get_option_string(wrong_option_type, "reason"), "invalid_session_options")
	assert_eq(GFVariantData.get_option_string(inconsistent_limits, "reason"), "invalid_session_options")
	assert_true(GFVariantData.get_option_bool(duplicate_grants, "ok"))
	assert_eq(
		GFVariantData.get_option_array(duplicate_grants, "endpoint_ids").size(),
		1,
		"重复 grant 应规范化为唯一的精确授权。"
	)
	assert_eq(registered_count, 128)
	assert_eq(GFVariantData.get_option_string(endpoint_overflow, "reason"), "endpoint_limit_reached")
	assert_eq(opened_count, 32)
	assert_eq(GFVariantData.get_option_string(session_overflow, "reason"), "session_limit_reached")


func test_close_session_requires_the_token_and_removes_credentials() -> void:
	var _registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	environment.enabled = true
	var first_opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var second_opened: Dictionary = _open_session(PackedStringArray(["echo"]))
	var token: String = GFVariantData.get_option_string(first_opened, "token")
	var session_id: String = GFVariantData.get_option_string(first_opened, "session_id")

	var wrong_token: Dictionary = environment.close_session(session_id, "0".repeat(64))
	var closed: Dictionary = environment.close_session(session_id, token)
	var after_close: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "after-close", { "message": "hello" }),
		token
	)

	assert_ne(
		GFVariantData.get_option_string(first_opened, "token"),
		GFVariantData.get_option_string(second_opened, "token"),
		"独立 session 不得复用 bearer token。"
	)
	assert_eq(GFVariantData.get_option_string(wrong_token, "reason"), "invalid_credentials")
	assert_true(GFVariantData.get_option_bool(closed, "ok"))
	assert_eq(GFVariantData.get_option_string(after_close, "reason"), "invalid_credentials")
	assert_eq(handler.call_count, 0)


func test_authenticated_rejections_consume_rate_budget_and_replay_cache_never_evicts() -> void:
	var secondary_handler: RecordingHandler = RecordingHandler.new()
	var _echo_registered: Dictionary = environment.register_endpoint(
		"echo",
		request_schema,
		response_schema,
		handler.handle
	)
	var _secondary_registered: Dictionary = environment.register_endpoint(
		"secondary",
		request_schema,
		response_schema,
		secondary_handler.handle
	)
	environment.enabled = true
	var opened: Dictionary = _open_session(PackedStringArray(["echo"]), {
		"ttl_msec": 1_000,
		"max_requests_per_window": 3,
		"rate_window_msec": 100,
		"max_request_ids": 3,
	})
	var token: String = GFVariantData.get_option_string(opened, "token")
	var session_id: String = GFVariantData.get_option_string(opened, "session_id")
	var unauthorized: Dictionary = environment.execute_request(
		_make_request(session_id, "secondary", "rate-unauthorized", { "message": "hello" }),
		token
	)
	var invalid_schema_request: Dictionary = _make_request(
		session_id,
		"echo",
		"rate-invalid",
		{
			"message": "hello",
			"extra": true,
		}
	)
	var invalid_schema: Dictionary = environment.execute_request(invalid_schema_request, token)
	var replay: Dictionary = environment.execute_request(invalid_schema_request, token)
	var limited: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "rate-valid", { "message": "hello" }),
		token
	)
	environment.current_time_msec += 101
	var first: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "cache-1", { "message": "one" }),
		token
	)
	var second: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "cache-2", { "message": "two" }),
		token
	)
	var exhausted: Dictionary = environment.execute_request(
		_make_request(session_id, "echo", "cache-3", { "message": "three" }),
		token
	)
	environment.current_time_msec += 101
	var old_replay: Dictionary = environment.execute_request(invalid_schema_request, token)

	assert_eq(GFVariantData.get_option_string(unauthorized, "reason"), "endpoint_not_granted")
	assert_eq(GFVariantData.get_option_string(invalid_schema, "reason"), "request_schema_rejected")
	assert_eq(GFVariantData.get_option_string(replay, "reason"), "request_replayed")
	assert_eq(GFVariantData.get_option_string(limited, "reason"), "rate_limited", "已认证拒绝也应消耗限流预算。")
	assert_true(GFVariantData.get_option_bool(first, "ok"))
	assert_true(GFVariantData.get_option_bool(second, "ok"))
	assert_eq(GFVariantData.get_option_string(exhausted, "reason"), "request_id_budget_exhausted")
	assert_eq(GFVariantData.get_option_string(old_replay, "reason"), "request_replayed", "满载后旧 request id 仍不得重放。")
	assert_eq(handler.call_count, 2)


func _open_session(endpoint_ids: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = environment.open_session(endpoint_ids, options)
	assert_true(GFVariantData.get_option_bool(result, "ok"), "测试前置 session 应成功创建。")
	return result


func _make_request(
	session_id: String,
	endpoint_id: String,
	request_id: String,
	payload: Dictionary
) -> Dictionary:
	return {
		"protocol_version": GFRuntimeAgentEnvironment.PROTOCOL_VERSION,
		"session_id": session_id,
		"endpoint_id": endpoint_id,
		"request_id": request_id,
		"payload": payload,
	}


func _make_schema(
	schema_id: StringName,
	fields: Array[GFSchemaField] = []
) -> GFDictionarySchema:
	var schema: GFDictionarySchema = GFDictionarySchema.new()
	return schema.configure(schema_id, fields, {
		"allow_extra_fields": false,
		"coerce_values": false,
		"fail_on_coerce_error": true,
	})


func _make_field(
	field_name: StringName,
	value_type: GFSchemaField.ValueType,
	options: Dictionary = {}
) -> GFSchemaField:
	var field: GFSchemaField = GFSchemaField.new()
	return field.configure(field_name, value_type, options)


class ManualClockEnvironment extends GFRuntimeAgentEnvironment:
	var current_time_msec: int = 0


	func _get_current_time_msec() -> int:
		return current_time_msec


class RecordingHandler extends RefCounted:
	var call_count: int = 0
	var last_request: Dictionary = {}
	var response_override: Dictionary = {}
	var raw_response_override: Variant = null
	var use_raw_response_override: bool = false
	var on_call: Callable = Callable()
	var nested_result: Dictionary = {}


	func handle(request: Dictionary) -> Variant:
		call_count += 1
		last_request = request.duplicate(true)
		if on_call.is_valid():
			on_call.call()
		if use_raw_response_override:
			return raw_response_override
		if not response_override.is_empty():
			return response_override.duplicate(true)
		var payload: Dictionary = GFVariantData.get_option_dictionary(request, "payload")
		return {
			"accepted": true,
			"echo": GFVariantData.get_option_string(payload, "message"),
		}


class DenyingPolicyProvider extends GFPolicyProvider:
	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		return make_result(false, &"failed", artifact, [
			{
				"kind": "denied",
				"message": "Denied by test policy.",
			},
		])


class DisablingSessionPolicyProvider extends GFPolicyProvider:
	var environment: GFRuntimeAgentEnvironment = null


	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		if environment != null:
			environment.enabled = false
		return make_result(true, &"passed", artifact)


class MetadataPolicyProvider extends GFPolicyProvider:
	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		var allowed: bool = GFVariantData.get_option_bool(metadata, "allow")
		return make_result(allowed, &"passed" if allowed else &"denied", artifact)


class TogglePolicyProvider extends GFPolicyProvider:
	var allow_requests: bool = false


	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		return make_result(
			allow_requests,
			&"passed" if allow_requests else &"denied",
			artifact
		)


class MutatingPolicyProvider extends GFPolicyProvider:
	var environment: GFRuntimeAgentEnvironment = null
	var session_id: String = ""
	var revoke_session: bool = false


	func _evaluate_policy(artifact: Dictionary, _context: Dictionary) -> Dictionary:
		var payload: Dictionary = GFVariantData.get_option_dictionary(artifact, "payload")
		payload["message"] = "mutated-by-policy"
		if revoke_session and environment != null:
			var _revoked: bool = environment.revoke_session(session_id)
		return make_result(true, &"passed", artifact)
