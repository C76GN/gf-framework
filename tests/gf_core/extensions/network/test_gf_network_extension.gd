## 测试 GF 网络抽象的消息编码、后端桥接与限流器。
extends GutTest


# --- 常量 ---



# --- 辅助类 ---

class FakeBackend extends GFNetworkBackend:
	var sent_peer_id: int = 0
	var sent_bytes: PackedByteArray = PackedByteArray()
	var sent_options: Dictionary = {}
	var disconnected_by_utility: bool = false

	func send_bytes(peer_id: int, bytes: PackedByteArray, options: Dictionary = {}) -> Error:
		sent_peer_id = peer_id
		sent_bytes = bytes
		sent_options = options.duplicate(true)
		return OK

	func host(_options: Dictionary = {}) -> Error:
		return OK

	func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:
		return OK

	func disconnect_backend() -> void:
		disconnected_by_utility = true
		disconnected.emit("closed")


class EagerConnectedBackend extends FakeBackend:
	func host(_options: Dictionary = {}) -> Error:
		connected.emit()
		return OK


class FailingHostBackend extends FakeBackend:
	func host(_options: Dictionary = {}) -> Error:
		return ERR_CANT_CREATE


# --- 测试方法 ---

## 验证消息序列化可保留通用元信息与载荷。
func test_network_serializer_round_trips_message() -> void:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	var message: GFNetworkMessage = GFNetworkMessage.new(&"state", { "hp": 10 }, 7, 12, 3, &"state_channel")

	var decoded: GFNetworkMessage = serializer.deserialize_message(serializer.serialize_message(message))

	assert_not_null(decoded, "解码结果不应为空。")
	assert_eq(decoded.message_type, &"state", "消息类型应保留。")
	assert_eq(decoded.sequence, 7, "sequence 应保留。")
	assert_eq(decoded.tick, 12, "tick 应保留。")
	assert_eq(decoded.sender_id, 3, "sender_id 应保留。")
	assert_eq(decoded.channel_id, &"state_channel", "channel_id 应保留。")
	assert_eq(GFVariantData.get_option_int(decoded.payload, "hp"), 10, "payload 应保留。")


func test_network_serializer_result_distinguishes_empty_dictionary_from_decode_failure() -> void:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	serializer.format = GFNetworkSerializer.Format.JSON

	var empty_result: Dictionary = serializer.deserialize_dictionary_result("{}".to_utf8_buffer())
	var empty_bytes_result: Dictionary = serializer.deserialize_dictionary_result(PackedByteArray())
	var array_result: Dictionary = serializer.deserialize_dictionary_result("[]".to_utf8_buffer())

	assert_true(GFVariantData.get_option_bool(empty_result, "ok"), "合法空字典应是成功结果。")
	assert_true(GFVariantData.get_option_dictionary(empty_result, "data").is_empty(), "合法空字典应保留为空数据。")
	assert_false(GFVariantData.get_option_bool(empty_bytes_result, "ok"), "空 bytes 不应与合法空字典混淆。")
	assert_eq(GFVariantData.get_option_string(empty_bytes_result, "error"), "empty_bytes", "空 bytes 应报告明确错误。")
	assert_false(GFVariantData.get_option_bool(array_result, "ok"), "非字典 JSON 不应解码成功。")
	assert_eq(GFVariantData.get_option_string(array_result, "error"), "json_not_dictionary", "非字典 JSON 应报告明确错误。")


func test_network_serializer_message_result_rejects_empty_message() -> void:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	serializer.format = GFNetworkSerializer.Format.JSON

	var result: Dictionary = serializer.deserialize_message_result("{}".to_utf8_buffer())

	assert_false(GFVariantData.get_option_bool(result, "ok"), "空字典不能被当作有效网络消息。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "empty_message", "空消息应报告明确错误。")


func test_network_contract_builds_and_validates_typed_message() -> void:
	var slot_field: GFNetworkContractField = GFNetworkContractField.new()
	slot_field.field_name = &"slot"
	slot_field.value_type = GFNetworkContractField.ValueType.INT
	var ready_field: GFNetworkContractField = GFNetworkContractField.new()
	ready_field.field_name = &"ready"
	ready_field.value_type = GFNetworkContractField.ValueType.BOOL
	ready_field.required = false
	ready_field.default_value = false
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"player_ready"
	message_contract.channel_id = &"lobby"
	message_contract.fields = [slot_field, ready_field]
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"lobby"
	contract.messages = [message_contract]

	var message: GFNetworkMessage = contract.make_message(&"player_ready", { &"slot": 2 })
	var valid_report: Dictionary = contract.validate_message(message)
	var missing_report: Dictionary = message_contract.validate_payload({})
	var wrong_type_report: Dictionary = message_contract.validate_payload({ &"slot": "2" })

	assert_not_null(message, "契约应能构造 GFNetworkMessage。")
	assert_eq(message.message_type, &"player_ready", "消息类型应来自契约。")
	assert_eq(message.channel_id, &"lobby", "默认通道应写入消息元信息。")
	assert_eq(GFVariantData.get_option_int(message.payload, &"slot"), 2, "payload 应写入字段值。")
	assert_false(GFVariantData.get_option_bool(message.payload, &"ready", true), "可选字段应使用默认值。")
	assert_true(GFVariantData.get_option_bool(valid_report, "ok"), "有效消息应通过契约校验。")
	assert_false(GFVariantData.get_option_bool(missing_report, "ok"), "缺失必填字段应校验失败。")
	assert_false(GFVariantData.get_option_bool(wrong_type_report, "ok"), "字段类型错误应校验失败。")
	var missing_issues: Array = GFVariantData.get_option_array(missing_report, "issues")
	var first_missing_issue: Dictionary = GFVariantData.as_dictionary(missing_issues[0])
	var missing_counts: Dictionary = GFVariantData.get_option_dictionary(missing_report, "issue_counts_by_kind")
	assert_eq(GFVariantData.get_option_string(first_missing_issue, "kind"), "missing_required_field", "契约校验问题应使用标准 kind 字段。")
	assert_eq(GFVariantData.get_option_int(missing_report, "issue_count"), 1, "契约校验报告应统计问题总数。")
	assert_eq(GFVariantData.get_option_int(missing_counts, "missing_required_field"), 1, "契约校验报告应按 kind 统计。")
	assert_true(GFVariantData.get_option_string(missing_report, "next_action").contains("required field"), "契约校验报告应提供下一步建议。")


func test_network_contract_generator_builds_typed_helpers() -> void:
	var slot_field: GFNetworkContractField = GFNetworkContractField.new()
	slot_field.field_name = &"slot"
	slot_field.value_type = GFNetworkContractField.ValueType.INT
	var ready_field: GFNetworkContractField = GFNetworkContractField.new()
	ready_field.field_name = &"ready"
	ready_field.value_type = GFNetworkContractField.ValueType.BOOL
	ready_field.required = false
	ready_field.default_value = false
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"player_ready"
	message_contract.channel_id = &"lobby"
	message_contract.fields = [slot_field, ready_field]
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"lobby"
	contract.messages = [message_contract]
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()

	var source: String = generator.build_source(contract, { "class_name": "LobbyNetworkMessages" })

	assert_true(source.contains("class_name LobbyNetworkMessages"), "应生成指定 class_name。")
	assert_true(source.contains("const MESSAGE_PLAYER_READY: StringName = &\"player_ready\""), "应生成消息常量。")
	assert_true(source.contains("const CHANNEL_PLAYER_READY: StringName = &\"lobby\""), "应生成默认通道常量。")
	assert_true(source.contains("static func make_player_ready(slot: int, ready: bool = false, options: Dictionary = {}) -> GFNetworkMessage:"), "应生成强类型构造函数。")
	assert_true(source.contains("static func send_player_ready(network: GFNetworkUtility, peer_id: int, slot: int, ready: bool = false, options: Dictionary = {}) -> Error:"), "应生成强类型发送函数。")
	assert_true(source.contains("static func get_player_ready_slot(message: GFNetworkMessage, default_value: int = 0) -> int:"), "应生成字段读取函数。")

	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = source.replace("class_name LobbyNetworkMessages\n", "")
	assert_eq(runtime_script.reload(), OK, "生成源码去掉全局类注册行后应能被 GDScript 编译。")


func test_network_contract_generator_omits_optional_null_fields() -> void:
	var slot_field: GFNetworkContractField = GFNetworkContractField.new()
	slot_field.field_name = &"slot"
	slot_field.value_type = GFNetworkContractField.ValueType.INT
	var note_field: GFNetworkContractField = GFNetworkContractField.new()
	note_field.field_name = &"note"
	note_field.value_type = GFNetworkContractField.ValueType.STRING
	note_field.required = false
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"player_note"
	message_contract.fields = [slot_field, note_field]
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"lobby"
	contract.messages = [message_contract]
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()

	var source: String = generator.build_source(contract, { "class_name": "LobbyNetworkMessages" })

	assert_true(source.contains("static func make_player_note(slot: int, note: Variant = null, options: Dictionary = {}) -> GFNetworkMessage:"), "无默认值的可选字段应保留 null 作为未提供语义。")
	assert_true(source.contains("if note != null or GFVariantData.get_option_bool(options, \"include_null_optional_fields\"):"), "payload 构建应默认省略 null 可选字段。")

	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = source.replace("class_name LobbyNetworkMessages\n", "")
	assert_eq(runtime_script.reload(), OK, "可选 null 语义生成源码应能编译。")


func test_network_contract_generator_reports_invalid_resources_with_standard_report() -> void:
	var invalid_path: String = "user://not_a_network_contract.tres"
	assert_eq(ResourceSaver.save(Resource.new(), invalid_path), OK, "测试应能写入临时非契约资源。")
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()

	var report: Dictionary = generator.generate_many(PackedStringArray([invalid_path]))

	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "非 GFNetworkContract 资源应让生成报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "生成报告应统计问题总数。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "invalid_contract_resource", "生成报告问题应使用标准 kind。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "invalid_contract_resource"), 1, "生成报告应按 kind 统计。")
	var _remove_absolute_result_200: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))


func test_network_json_serializer_can_use_typed_variant_codec() -> void:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	serializer.format = GFNetworkSerializer.Format.JSON
	serializer.use_typed_json_codec = true
	var message: GFNetworkMessage = GFNetworkMessage.new(&"state", {
		"position": Vector2(1.0, 2.0),
		"tags": PackedStringArray(["a", "b"]),
	})

	var decoded: GFNetworkMessage = serializer.deserialize_message(serializer.serialize_message(message))

	assert_not_null(decoded, "类型化 JSON 解码结果不应为空。")
	assert_eq(GFVariantData.get_option_vector2(decoded.payload, "position"), Vector2(1.0, 2.0), "类型化 JSON 应保留 Vector2。")
	assert_eq(GFVariantData.get_option_packed_string_array(decoded.payload, "tags"), PackedStringArray(["a", "b"]), "类型化 JSON 应保留 PackedStringArray。")


func test_reconnect_policy_uses_delay_sequence_and_attempt_limit() -> void:
	var policy: GFNetworkReconnectPolicy = GFNetworkReconnectPolicy.new()
	policy.delays_msec = [10, 20]
	policy.max_attempts = 3

	assert_eq(policy.get_next_delay_msec(), 10)
	assert_eq(policy.get_next_delay_msec(), 20)
	assert_eq(policy.get_next_delay_msec(), 20, "超过序列长度后应复用最后一个延迟。")
	assert_eq(policy.get_next_delay_msec(), -1, "达到最大尝试次数后应拒绝继续。")

	policy.record_success()
	assert_eq(policy.get_attempt_count(), 0, "连接成功后应重置尝试次数。")


func test_reconnect_policy_jitter_respects_seeded_rng_state() -> void:
	var policy: GFNetworkReconnectPolicy = GFNetworkReconnectPolicy.new()
	var expected_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	policy.delays_msec = [100]
	policy.jitter_ratio = 0.5
	policy._rng.seed = 12345
	expected_rng.seed = 12345

	var expected: int = maxi(roundi(100.0 + expected_rng.randf_range(-50.0, 50.0)), 0)

	assert_eq(policy.get_next_delay_msec(), expected, "jitter 不应在每次计算时重新 randomize 覆盖已设定 RNG 状态。")


## 验证 NetworkUtility 会通过后端发送并解码后端收到的消息。
func test_network_utility_bridges_backend_messages() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var received: Array[GFNetworkMessage] = []
	var _connect_result_252: Variant = utility.message_received.connect(func(_peer_id: int, received_message: GFNetworkMessage) -> void:
		received.append(received_message)
	)

	var outgoing_message: GFNetworkMessage = GFNetworkMessage.new(&"ping", { "value": 1 })
	var error: Error = utility.send_message(4, outgoing_message)
	backend.message_received.emit(4, backend.sent_bytes)

	assert_eq(error, OK, "发送消息应成功。")
	assert_eq(backend.sent_peer_id, 4, "后端应收到目标 peer。")
	assert_eq(received.size(), 1, "后端消息应被解码并广播。")
	assert_eq(received[0].message_type, &"ping", "解码后的消息类型应正确。")
	assert_eq(received[0].sender_id, 4, "入站消息的 sender_id 应以传输层 peer_id 为准，不能信任载荷自报。")


func test_network_utility_reports_decode_failure_details() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.serializer.format = GFNetworkSerializer.Format.JSON
	utility.set_backend(backend)
	watch_signals(utility)

	backend.message_received.emit(1, "[]".to_utf8_buffer())

	assert_signal_emitted_with_parameters(utility, "message_rejected", [
		1,
		"decode_failed",
		{
			"ok": false,
			"data": {},
			"error": "json_not_dictionary",
		},
	])


## 验证令牌桶限流器按时间恢复令牌。
func test_network_rate_limiter_refills_tokens() -> void:
	var limiter: GFNetworkRateLimiter = GFNetworkRateLimiter.new(1.0, 2.0)

	assert_true(limiter.consume(), "初始令牌应允许一次消费。")
	assert_false(limiter.consume(), "令牌耗尽后应拒绝消费。")
	limiter.tick(0.5)

	assert_true(limiter.consume(), "恢复足够令牌后应允许消费。")


## 验证网络频道会合并发送选项并进入调试快照。
func test_network_channel_controls_send_options() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.transfer_channel = 2
	channel.reliable = false
	utility.register_channel(channel)

	var error: Error = utility.send_message_on_channel(3, GFNetworkMessage.new(&"state", {}), &"state")
	var snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(error, OK, "通道发送应成功。")
	assert_eq(GFVariantData.get_option_int(backend.sent_options, "channel"), 2, "通道编号应写入后端发送选项。")
	assert_false(GFVariantData.get_option_bool(backend.sent_options, "reliable", true), "通道可靠性应写入后端发送选项。")
	assert_eq(GFVariantData.get_option_array(snapshot, "channels").size(), 1, "调试快照应包含已注册通道。")


## 验证按通道发送会写入消息通道元信息，且不修改原始消息 payload。
func test_send_message_on_channel_serializes_channel_id_metadata() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	utility.register_channel(channel)
	var message: GFNetworkMessage = GFNetworkMessage.new(&"state_delta", { "value": 1 })

	var error: Error = utility.send_message_on_channel(3, message, &"state")
	var decoded: GFNetworkMessage = utility.serializer.deserialize_message(backend.sent_bytes)

	assert_eq(error, OK, "通道发送应成功。")
	assert_eq(decoded.channel_id, &"state", "发送副本应包含逻辑通道。")
	assert_false(message.payload.has("channel_id"), "通道元信息不应污染业务 payload。")


## 验证入站消息会按 message_type 匹配通道包体上限。
func test_network_utility_rejects_inbound_packet_over_channel_limit() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.max_packet_size = 8
	utility.register_channel(channel)
	watch_signals(utility)

	var bytes: PackedByteArray = utility.serializer.serialize_message(GFNetworkMessage.new(&"state", { "payload": "too large" }))
	backend.message_received.emit(1, bytes)

	assert_signal_emitted(utility, "message_rejected", "超过通道上限的入站消息应被拒绝。")
	assert_signal_not_emitted(utility, "message_received", "被拒绝的入站消息不应继续广播。")


## 验证入站消息可按 channel_id 元信息匹配通道包体上限。
func test_network_utility_rejects_inbound_packet_over_channel_id_limit() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.max_packet_size = 8
	utility.register_channel(channel)
	watch_signals(utility)

	var bytes: PackedByteArray = utility.serializer.serialize_message(GFNetworkMessage.new(&"state_delta", { "payload": "too large" }, 0, 0, -1, &"state"))
	backend.message_received.emit(1, bytes)

	assert_signal_emitted(utility, "message_rejected", "超过通道上限的入站消息应被拒绝。")
	assert_signal_not_emitted(utility, "message_received", "被拒绝的入站消息不应继续广播。")


## 验证入站通道匹配不再读取业务 payload.channel_id。
func test_network_utility_does_not_resolve_channel_from_payload_field() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.max_packet_size = 8
	utility.register_channel(channel)
	watch_signals(utility)

	var message: GFNetworkMessage = GFNetworkMessage.new(
		&"state_delta",
		{ "channel_id": "state", "payload": "too large" }
	)
	var bytes: PackedByteArray = utility.serializer.serialize_message(message)
	backend.message_received.emit(1, bytes)

	assert_signal_not_emitted(utility, "message_rejected", "业务 payload.channel_id 不应触发通道级包体限制。")
	assert_signal_emitted(utility, "message_received", "未携带通道元信息的消息应按普通消息广播。")


## 验证 ENet endpoint 解析支持带括号 IPv6 和 options.port。
func test_enet_endpoint_parser_supports_ipv6_forms() -> void:
	var backend: GFENetNetworkBackend = GFENetNetworkBackend.new()

	var bracketed: Dictionary = backend._parse_endpoint("[::1]:9000", {})
	var option_port: Dictionary = backend._parse_endpoint("2001:db8::1", { "port": 9001 })

	assert_eq(GFVariantData.get_option_string(bracketed, "address"), "::1", "带括号 IPv6 应去掉括号。")
	assert_eq(GFVariantData.get_option_int(bracketed, "port"), 9000, "带括号 IPv6 应解析端口。")
	assert_eq(GFVariantData.get_option_string(option_port, "address"), "2001:db8::1", "未带端口的 IPv6 应保持完整地址。")
	assert_eq(GFVariantData.get_option_int(option_port, "port"), 9001, "IPv6 可通过 options.port 指定端口。")


func test_websocket_backend_rejects_missing_port() -> void:
	var backend: GFWebSocketNetworkBackend = GFWebSocketNetworkBackend.new()

	assert_eq(backend.host({}), ERR_INVALID_PARAMETER, "WebSocket 主机必须显式提供端口。")


func test_websocket_backend_round_trips_bytes() -> void:
	var server: GFWebSocketNetworkBackend = GFWebSocketNetworkBackend.new()
	var client: GFWebSocketNetworkBackend = GFWebSocketNetworkBackend.new()
	var port: int = 0
	var host_error: Error = ERR_UNAVAILABLE
	for offset: int in range(20):
		port = 19300 + offset
		host_error = server.host({
			"port": port,
			"bind_address": "127.0.0.1",
		})
		if host_error == OK:
			break
	assert_eq(host_error, OK, "测试应能启动本地 WebSocket 主机。")
	if host_error != OK:
		return

	var server_peer_ids: Array[int] = []
	var server_messages: Array[PackedByteArray] = []
	var _connect_result_432: Variant = server.peer_connected.connect(func(peer_id: int) -> void:
		server_peer_ids.append(peer_id)
	)
	var _connect_result_435: Variant = server.message_received.connect(func(_peer_id: int, packet_bytes: PackedByteArray) -> void:
		server_messages.append(packet_bytes)
	)

	var connect_error: Error = client.connect_to_endpoint("ws://127.0.0.1:%d" % port)
	assert_eq(connect_error, OK, "客户端应能开始连接本地 WebSocket 主机。")

	for _step: int in range(120):
		server.poll(0.016)
		client.poll(0.016)
		if not server_peer_ids.is_empty():
			break
		await get_tree().process_frame

	assert_gt(server_peer_ids.size(), 0, "服务器应收到 WebSocket peer 连接。")
	if server_peer_ids.is_empty():
		server.disconnect_backend()
		client.disconnect_backend()
		return

	var bytes: PackedByteArray = PackedByteArray([1, 2, 3, 4])
	var send_error: Error = client.send_bytes(GFWebSocketNetworkBackend.SERVER_PEER_ID, bytes)
	assert_eq(send_error, OK, "客户端应能发送二进制包。")

	for _step: int in range(120):
		server.poll(0.016)
		client.poll(0.016)
		if not server_messages.is_empty():
			break
		await get_tree().process_frame

	assert_gt(server_messages.size(), 0, "服务器应收到客户端发送的原始 bytes。")
	if server_messages.is_empty():
		server.disconnect_backend()
		client.disconnect_backend()
		return
	assert_eq(server_messages[0], bytes, "服务器应收到客户端发送的原始 bytes。")
	server.disconnect_backend()
	client.disconnect_backend()


## 验证消息校验器会拒绝不合规消息。
func test_network_message_validator_rejects_invalid_message() -> void:
	var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()

	var report: Dictionary = validator.validate_message(GFNetworkMessage.new(&"", {}))

	assert_false(GFVariantData.get_option_bool(report, "ok"), "默认校验器不应允许空消息类型。")
	assert_true(GFVariantData.get_option_packed_string_array(report, "errors").has("empty_message_type"), "校验报告应包含 empty_message_type。")


## 验证消息校验器默认启用全局包体上限。
func test_network_message_validator_rejects_large_packet_by_default() -> void:
	var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()
	var bytes: PackedByteArray = PackedByteArray()
	var _resize_result_490: Variant = bytes.resize(GFNetworkMessageValidator.DEFAULT_MAX_PACKET_SIZE + 1)

	var report: Dictionary = validator.validate_bytes(bytes)
	var snapshot: Dictionary = validator.get_debug_snapshot()

	assert_eq(GFVariantData.get_option_int(snapshot, "max_packet_size"), GFNetworkMessageValidator.DEFAULT_MAX_PACKET_SIZE, "2.0 默认应启用全局包体上限。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "超过默认全局上限的包体应被拒绝。")
	assert_true(GFVariantData.get_option_packed_string_array(report, "errors").has("packet_too_large"), "校验报告应包含 packet_too_large。")


## 验证项目可显式关闭全局包体上限。
func test_network_message_validator_can_disable_global_packet_limit() -> void:
	var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()
	validator.max_packet_size = 0
	var bytes: PackedByteArray = PackedByteArray()
	var _resize_result_505: Variant = bytes.resize(GFNetworkMessageValidator.DEFAULT_MAX_PACKET_SIZE + 1)

	var report: Dictionary = validator.validate_bytes(bytes)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "显式设置 0 后应允许项目自定义大包策略。")


## 验证 NetworkUtility 会维护通用会话状态。
func test_network_utility_tracks_session_state() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(FakeBackend.new())

	var host_error: Error = utility.host({ "port": 9000, "max_clients": 8 })
	var host_snapshot: Dictionary = utility.get_debug_snapshot()
	utility.disconnect_network()
	var _connect_to_endpoint_result_520: Variant = utility.connect_to_endpoint("127.0.0.1:9000")
	var client_snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(host_error, OK, "主机会话启动应成功。")
	var host_session: Dictionary = GFVariantData.get_option_dictionary(host_snapshot, "session")
	var client_session: Dictionary = GFVariantData.get_option_dictionary(client_snapshot, "session")
	assert_eq(GFVariantData.get_option_string(host_session, "mode_name"), "host", "主机会话应记录 host 模式。")
	assert_eq(GFVariantData.get_option_int(host_session, "max_peers"), 8, "主机会话应记录最大连接数。")
	assert_eq(GFVariantData.get_option_string(client_session, "mode_name"), "client", "客户端连接应记录 client 模式。")


func test_network_session_warns_and_ignores_non_dictionary_metadata() -> void:
	var session: GFNetworkSession = GFNetworkSession.new()

	session.start_host({ "metadata": "invalid" })

	assert_true(session.metadata.is_empty(), "非 Dictionary metadata 应被忽略。")
	assert_push_warning("[GFNetworkSession] metadata 必须是 Dictionary，已忽略。")


## 验证后端在 host() 内立即报告 connected 时，会话已经带有主机 peer 信息且不会重复派发。
func test_network_utility_host_session_is_ready_before_eager_backend_connected() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(EagerConnectedBackend.new())
	var connected_peer_ids: Array[int] = []
	var _connect_result_545: Variant = utility.session.session_connected.connect(func(local_peer_id: int) -> void:
		connected_peer_ids.append(local_peer_id)
	)

	var error: Error = utility.host({ "port": 9000, "local_peer_id": 9 })

	assert_eq(error, OK, "主机会话启动应成功。")
	assert_eq(connected_peer_ids, [9], "后端立即 connected 不应造成 session_connected 重复或使用默认 peer。")
	assert_eq(utility.session.local_peer_id, 9, "会话应保留配置的本地 peer。")


func test_network_utility_host_failure_does_not_emit_session_connected() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(FailingHostBackend.new())
	var connected_peer_ids: Array[int] = []
	var _connect_result_560: Variant = utility.session.session_connected.connect(func(local_peer_id: int) -> void:
		connected_peer_ids.append(local_peer_id)
	)

	var error: Error = utility.host({ "port": 9000, "local_peer_id": 9 })

	assert_eq(error, ERR_CANT_CREATE, "后端 host 失败时应返回错误。")
	assert_true(connected_peer_ids.is_empty(), "host 失败不应短暂发出 session_connected。")
	assert_false(utility.session.is_active, "host 失败后会话应关闭。")
	assert_false(utility.session.has_connection, "host 失败后不应保留 connected 状态。")


func test_network_utility_replacing_backend_closes_previous_backend() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var first_backend: FakeBackend = FakeBackend.new()
	var second_backend: FakeBackend = FakeBackend.new()
	utility.set_backend(first_backend)
	var _host_result_577: Variant = utility.host({ "port": 9000 })

	utility.set_backend(second_backend)

	assert_true(first_backend.disconnected_by_utility, "替换后端时应关闭旧后端资源。")
	assert_false(utility.session.is_active, "替换后端应清理旧会话状态。")
	assert_eq(utility.backend, second_backend, "NetworkUtility 应切换到新后端。")


## 验证网络工具与可选 ENet 后端提供调试快照。
func test_network_debug_snapshots_are_available() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(FakeBackend.new())

	var utility_snapshot: Dictionary = utility.get_debug_snapshot()
	var enet_snapshot: Dictionary = GFENetNetworkBackend.new().get_debug_snapshot()

	assert_true(GFVariantData.get_option_bool(utility_snapshot, "backend_configured"), "设置后端后快照应标记已配置。")
	assert_eq(GFVariantData.get_option_string(enet_snapshot, "connection_status_name"), "disconnected", "未连接 ENet 后端应报告 disconnected。")
	assert_eq(GFVariantData.get_option_int(enet_snapshot, "max_packets_per_poll"), 64, "ENet 快照应包含每帧收包预算。")


## 验证 Network 扩展会从扩展侧向 Diagnostics 贡献网络快照。
func test_network_utility_contributes_diagnostics_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(FakeBackend.new())
	await arch.register_utility_instance(diagnostics)
	await arch.register_utility_instance(utility)
	await arch.init()

	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var network: Dictionary = GFVariantData.get_option_dictionary(snapshot, "network")

	assert_true(network.has("backend_configured"), "Network 扩展应通过通用注册入口贡献 network 快照。")
	assert_true(GFVariantData.get_option_bool(network, "backend_configured"), "贡献的 network 快照应来自当前 NetworkUtility。")

	arch.dispose()


## 验证固定 tick 时钟按预算推进并保留插值 alpha。
func test_fixed_tick_clock_advances_with_budget() -> void:
	var clock: GFFixedTickClock = GFFixedTickClock.new(10.0)
	clock.max_steps_per_update = 2
	var started_ticks: Array[int] = []
	var finished_ticks: Array[int] = []
	var exhausted_reports: Array[Dictionary] = []
	var _connect_result_627: Variant = clock.tick_started.connect(func(tick: int, _tick_seconds: float) -> void:
		started_ticks.append(tick)
	)
	var _connect_result_630: Variant = clock.tick_finished.connect(func(tick: int, _tick_seconds: float) -> void:
		finished_ticks.append(tick)
	)
	var _connect_result_633: Variant = clock.tick_budget_exhausted.connect(func(available_steps: int, processed_steps: int, remaining_seconds: float) -> void:
		exhausted_reports.append({
			"available_steps": available_steps,
			"processed_steps": processed_steps,
			"remaining_seconds": remaining_seconds,
		})
	)

	var steps: int = clock.advance(0.35)

	assert_eq(steps, 2, "单次推进应受最大步数限制。")
	assert_eq(clock.current_tick, 2, "当前 tick 应推进两步。")
	assert_eq(started_ticks, [1, 2], "固定时钟应按单 tick 发出开始信号。")
	assert_eq(finished_ticks, [1, 2], "固定时钟应按单 tick 发出结束信号。")
	assert_eq(exhausted_reports.size(), 1, "预算不足时应发出诊断信号。")
	assert_true(clock.get_interpolation_alpha() <= 1.0, "插值 alpha 应保持在 0 到 1。")
	assert_eq(clock.get_tick_factor(), clock.get_interpolation_alpha(), "tick_factor 应作为插值比例别名。")


## 验证网络快照可以生成并应用浅层差量。
func test_network_snapshot_delta_round_trips_state() -> void:
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(10, { "hp": 10, "mana": 3 }, 2)
	var target: GFNetworkSnapshot = GFNetworkSnapshot.new(12, { "hp": 8, "position": Vector2(1.0, 2.0) }, 2)

	var delta: Dictionary = start.make_delta_to(target)
	var applied: GFNetworkSnapshot = start.apply_delta(delta)

	assert_true(GFVariantData.get_option_bool(delta, "ok"), "有效目标快照应生成差量。")
	assert_eq(applied.tick, 12, "应用差量后 tick 应更新。")
	assert_eq(GFVariantData.to_int(applied.get_value(&"hp")), 8, "变更字段应被应用。")
	assert_false(applied.has_value(&"mana"), "目标中不存在的字段应被删除。")
	assert_eq(GFVariantData.to_vector2(applied.get_value(&"position")), Vector2(1.0, 2.0), "新增字段应被应用。")


## 验证网络快照差量会保留非字符串删除键。
func test_network_snapshot_delta_preserves_variant_erase_keys() -> void:
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(1, { 7: "old", "hp": 10 }, 2)
	var target: GFNetworkSnapshot = GFNetworkSnapshot.new(2, { "hp": 10 }, 2)

	var delta: Dictionary = start.make_delta_to(target)
	var applied: GFNetworkSnapshot = start.apply_delta(delta)

	assert_true(GFVariantData.get_option_bool(delta, "ok"), "有效目标快照应生成差量。")
	assert_false(applied.state.has(7), "Variant 删除键应按原类型删除。")


func test_network_snapshot_patch_round_trips_nested_state() -> void:
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(10, {
		"entity": {
			"hp": 10,
			"mana": 3,
			"status": {
				"burning": true,
			},
		},
		"stale": 1,
	}, 2)
	var target: GFNetworkSnapshot = GFNetworkSnapshot.new(12, {
		"entity": {
			"hp": 8,
			"status": {
				"frozen": true,
			},
		},
		"position": Vector2(1.0, 2.0),
	}, 2, { "source": "server" })

	var patch: Dictionary = start.make_patch_to(target)
	var applied: GFNetworkSnapshot = start.apply_patch(patch)
	var entity: Dictionary = GFVariantData.get_option_dictionary(applied.state, "entity")
	var status: Dictionary = GFVariantData.get_option_dictionary(entity, "status")

	assert_true(GFVariantData.get_option_bool(patch, "ok"), "有效目标快照应生成 patch。")
	assert_gt(GFVariantData.get_option_array(patch, "set").size(), 0, "嵌套变更应产生 set 操作。")
	assert_gt(GFVariantData.get_option_array(patch, "erase").size(), 0, "嵌套删除应产生 erase 操作。")
	assert_eq(applied.tick, 12, "应用 patch 后 tick 应更新。")
	assert_eq(GFVariantData.get_option_int(entity, "hp"), 8, "嵌套字段应被更新。")
	assert_false(entity.has("mana"), "目标中不存在的嵌套字段应被删除。")
	assert_true(GFVariantData.get_option_bool(status, "frozen"), "新增嵌套字段应被写入。")
	assert_false(status.has("burning"), "嵌套状态中不存在的字段应被删除。")
	assert_false(applied.state.has("stale"), "顶层删除仍应生效。")
	assert_eq(GFVariantData.get_option_vector2(applied.state, "position"), Vector2(1.0, 2.0), "新增顶层字段应被写入。")
	assert_eq(GFVariantData.get_option_string(applied.metadata, "source"), "server", "目标元数据应随 patch 更新。")


func test_network_snapshot_patch_preserves_empty_dictionary_set() -> void:
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(1, {}, 2)
	var target: GFNetworkSnapshot = GFNetworkSnapshot.new(2, { "entity": {} }, 2)

	var patch: Dictionary = start.make_patch_to(target)
	var applied: GFNetworkSnapshot = start.apply_patch(patch)

	assert_eq(GFVariantData.get_option_array(patch, "set").size(), 1, "新增空字典字段应作为整体 set。")
	assert_true(applied.state.has("entity"), "应用 patch 后应保留空字典字段。")
	assert_true(GFVariantData.get_option_dictionary(applied.state, "entity").is_empty(), "空字典字段不应丢失。")


## 验证网络历史缓冲按容量保留最新快照并可查询最近 tick。
func test_network_history_buffer_prunes_by_capacity() -> void:
	var history: GFNetworkHistoryBuffer = GFNetworkHistoryBuffer.new(2)
	var _add_state_result_733: Variant = history.add_state(1, { "value": 1 })
	var _add_state_result_734: Variant = history.add_state(2, { "value": 2 })
	var _add_state_result_735: Variant = history.add_state(3, { "value": 3 })

	var closest: GFNetworkSnapshot = history.get_closest_snapshot(2)
	var latest: GFNetworkSnapshot = history.get_latest_snapshot()

	assert_false(history.has_snapshot(1), "超过容量后最旧快照应被裁剪。")
	assert_eq(history.size(), 2, "历史数量应受 capacity 限制。")
	assert_eq(closest.tick, 2, "应能查询最接近的快照。")
	assert_eq(latest.tick, 3, "最新快照应为最大 tick。")


func test_network_history_buffer_queries_ranges_and_surrounding_snapshots() -> void:
	var history: GFNetworkHistoryBuffer = GFNetworkHistoryBuffer.new(0)
	var _add_state_result_748: Variant = history.add_state(1, { "value": 1 })
	var _add_state_result_749: Variant = history.add_state(3, { "value": 3 })
	var _add_state_result_750: Variant = history.add_state(5, { "value": 5 })

	var range_snapshots: Array[GFNetworkSnapshot] = history.get_snapshots_between(1, 5, false)
	var surrounding: Dictionary = history.get_surrounding_snapshots(4)
	var previous: GFNetworkSnapshot = _snapshot_from_dictionary(surrounding, "previous")
	var next: GFNetworkSnapshot = _snapshot_from_dictionary(surrounding, "next")

	assert_eq(range_snapshots.size(), 1, "开区间查询应只返回边界内快照。")
	assert_eq(range_snapshots[0].tick, 3, "范围查询应按 tick 升序返回快照。")
	assert_eq(previous.tick, 3, "包围查询应返回前序快照。")
	assert_eq(next.tick, 5, "包围查询应返回后序快照。")


func test_network_snapshot_schema_encodes_and_decodes_fields() -> void:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = GFNetworkFieldSerializer.ValueType.VECTOR2
	serializer.quantize_decimals = 1
	var schema: GFNetworkSnapshotSchema = GFNetworkSnapshotSchema.new()
	schema.set_field_serializer(&"position", serializer)
	var snapshot: GFNetworkSnapshot = GFNetworkSnapshot.new(7, {
		&"position": Vector2(1.24, 2.26),
		"name": "unit",
	}, 4)

	var encoded: Dictionary = schema.encode_snapshot(snapshot)
	var decoded: GFNetworkSnapshot = schema.decode_snapshot(encoded)
	var encoded_state: Dictionary = GFVariantData.get_option_dictionary(encoded, "state")

	assert_eq(GFVariantData.get_option_array(encoded_state, &"position"), [1.2, 2.3], "Schema 应按字段编码 Vector2。")
	assert_eq(decoded.tick, 7, "Schema 解码应保留 tick。")
	assert_eq(decoded.peer_id, 4, "Schema 解码应保留 peer。")
	assert_eq(GFVariantData.get_option_vector2(decoded.state, &"position"), Vector2(1.2, 2.3), "Schema 应恢复字段类型。")
	assert_eq(GFVariantData.get_option_string(decoded.state, "name"), "unit", "未注册字段应按配置原样保留。")


func test_network_snapshot_schema_encodes_and_decodes_patch_values() -> void:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = GFNetworkFieldSerializer.ValueType.VECTOR2
	serializer.quantize_decimals = 1
	var schema: GFNetworkSnapshotSchema = GFNetworkSnapshotSchema.new()
	schema.set_field_serializer(&"position", serializer)
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(1, { "position": Vector2.ZERO }, 2)
	var target: GFNetworkSnapshot = GFNetworkSnapshot.new(2, {
		"position": Vector2(1.24, 2.26),
		"name": "unit",
	}, 2)

	var patch: Dictionary = start.make_patch_to(target)
	var encoded: Dictionary = schema.encode_patch(patch)
	var decoded: Dictionary = schema.decode_patch(encoded)
	var applied: GFNetworkSnapshot = start.apply_patch(decoded)
	var encoded_position: Variant = null
	var set_ops: Array = GFVariantData.get_option_array(encoded, "set")
	for op: Dictionary in set_ops:
		var path: Array = GFVariantData.get_option_array(op, "path")
		if not path.is_empty() and GFVariantData.to_text(path[0]) == "position":
			encoded_position = op["value"]

	assert_eq(GFVariantData.as_array(encoded_position), [1.2, 2.3], "Schema 应按字段编码 patch set 值。")
	assert_eq(GFVariantData.get_option_vector2(applied.state, "position"), Vector2(1.2, 2.3), "Schema 应恢复 patch set 字段类型。")
	assert_eq(GFVariantData.get_option_string(applied.state, "name"), "unit", "未注册 patch 字段应按配置原样保留。")


func _snapshot_from_dictionary(source: Dictionary, key: Variant) -> GFNetworkSnapshot:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is GFNetworkSnapshot:
		return value
	return null
