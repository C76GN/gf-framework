## 测试 GF 网络抽象的消息编码、后端桥接与限流器。
extends GutTest


# --- 常量 ---

const GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT = preload(
	"res://tests/gf_core/support/gf_transient_gdscript_test_support.gd"
)


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
		_record_transport_packet_sent(bytes.size())
		return OK

	func host(_options: Dictionary = {}) -> Error:
		return OK

	func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:
		return OK

	func disconnect_backend() -> void:
		disconnected_by_utility = true
		disconnected.emit("closed")

	func emit_packet_for_test(peer_id: int, bytes: PackedByteArray) -> void:
		_emit_message_received(peer_id, bytes)

	func mark_connected_at_zero_for_test() -> void:
		_transport_connected = true
		_transport_connected_at_msec = 0


class EagerConnectedBackend extends FakeBackend:
	func host(_options: Dictionary = {}) -> Error:
		connected.emit()
		return OK


class FailingHostBackend extends FakeBackend:
	func host(_options: Dictionary = {}) -> Error:
		return ERR_CANT_CREATE


class FakeLobbyBackend extends GFNetworkLobbyBackend:
	var closed: bool = false
	var lobbies: Array[GFNetworkLobbyDescriptor] = []
	var held_handles: Dictionary = {}
	var cancel_count: int = 0
	var complete_during_poll: bool = false
	var reenter_on_cancel: bool = false
	var reentrant_status: StringName = &""

	func _dispatch_operation(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		if GFVariantData.get_option_bool(request.provider_options, "hold"):
			held_handles[String(request.request_id)] = handle
			return true
		if request.provider_options.has("malformed_lobbies"):
			var malformed_lobbies: Variant = request.provider_options["malformed_lobbies"]
			return _succeed_operation(handle, {"lobbies": malformed_lobbies})
		if GFVariantData.get_option_bool(request.provider_options, "invalid_result"):
			if request.operation == GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES:
				var duplicate_lobby: GFNetworkLobbyDescriptor = (
					GFNetworkLobbyDescriptor.new().configure("duplicate-lobby")
				)
				return _succeed_operation(handle, {
					"lobbies": [duplicate_lobby, duplicate_lobby],
				})
			return _succeed_operation(handle)
		match request.operation:
			GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY:
				return _create_lobby(request, handle)
			GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES:
				return _query_lobbies(request, handle)
			GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY:
				return _join_lobby(request, handle)
			GFNetworkLobbyOperationRequest.OP_LEAVE_LOBBY:
				return _succeed_operation(handle, {"lobby_id": request.lobby_id})
			GFNetworkLobbyOperationRequest.OP_SET_LOBBY_METADATA:
				return _set_lobby_metadata(request, handle)
			GFNetworkLobbyOperationRequest.OP_SET_MEMBER_METADATA:
				return _set_member_metadata(request, handle)
		return false

	func _cancel_operation(
		_handle: GFNetworkLobbyOperationHandle,
		_reason: StringName
	) -> void:
		cancel_count += 1
		if reenter_on_cancel:
			var reentrant_request: GFNetworkLobbyOperationRequest = (
				GFNetworkLobbyOperationRequest.new().configure(
					&"close_reentrant",
					GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES
				)
			)
			var reentrant: GFNetworkLobbyOperationHandle = invoke_operation(
				reentrant_request
			)
			reentrant_status = reentrant.get_result().status

	func _poll(_delta: float) -> void:
		if not complete_during_poll:
			return
		complete_during_poll = false
		for request_key: Variant in held_handles.keys().duplicate():
			var _completed: bool = complete_held(StringName(str(request_key)))

	func _close() -> void:
		closed = true
		held_handles.clear()

	func complete_held(request_id: StringName) -> bool:
		var value: Variant = GFVariantData.get_option_value(
			held_handles,
			String(request_id)
		)
		if not (value is GFNetworkLobbyOperationHandle):
			return false
		var handle: GFNetworkLobbyOperationHandle = value
		var _erased: bool = held_handles.erase(String(request_id))
		return _complete_handle_successfully(handle)

	func complete_handle_late(handle: GFNetworkLobbyOperationHandle) -> bool:
		if handle != null:
			var _erased: bool = held_handles.erase(String(handle.get_request_id()))
		return _succeed_operation(handle)

	func _complete_handle_successfully(
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var request: GFNetworkLobbyOperationRequest = handle.get_request()
		match request.operation:
			GFNetworkLobbyOperationRequest.OP_CREATE_LOBBY:
				var create_lobby_id: String = request.lobby_id
				if create_lobby_id.is_empty():
					create_lobby_id = "held-lobby"
				var created_lobby: GFNetworkLobbyDescriptor = (
					GFNetworkLobbyDescriptor.new().configure(create_lobby_id)
				)
				return _succeed_operation(handle, {"lobby": created_lobby})
			GFNetworkLobbyOperationRequest.OP_JOIN_LOBBY:
				var joined_lobby_id: String = request.lobby_id
				if joined_lobby_id.is_empty():
					joined_lobby_id = "held-lobby"
				var joined_lobby: GFNetworkLobbyDescriptor = (
					GFNetworkLobbyDescriptor.new().configure(joined_lobby_id)
				)
				return _succeed_operation(handle, {"lobby": joined_lobby})
			GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES:
				return _succeed_operation(handle, {"lobbies": []})
		return _succeed_operation(handle, {"lobby_id": request.lobby_id})

	func _create_lobby(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var options: Dictionary = request.provider_options
		var lobby: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.new().configure(
			GFVariantData.get_option_string(options, "lobby_id", "test-lobby"),
			{
				"backend_id": &"fake",
				"display_name": GFVariantData.get_option_string(options, "display_name", "Test Lobby"),
				"max_members": GFVariantData.get_option_int(options, "max_members", 4),
				"tags": GFVariantData.get_option_packed_string_array(options, "tags"),
				"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
			}
		)
		_store_lobby(lobby)
		return _succeed_operation(handle, {"lobby": lobby})

	func _query_lobbies(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var query: GFNetworkLobbyQuery = request.query
		var result: Array[GFNetworkLobbyDescriptor] = []
		for lobby: GFNetworkLobbyDescriptor in lobbies:
			if lobby == null:
				continue
			if query != null and not query.matches(lobby):
				continue
			result.append(lobby.duplicate_lobby())
			if query != null and query.max_results > 0 and result.size() >= query.max_results:
				break
		return _succeed_operation(handle, {"lobbies": result})

	func _join_lobby(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var lobby: GFNetworkLobbyDescriptor = _find_lobby(request.lobby_id)
		if lobby == null:
			return _fail_operation(handle, &"not_found", "Lobby was not found.")
		return _succeed_operation(handle, {"lobby": lobby})

	func _set_lobby_metadata(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var lobby: GFNetworkLobbyDescriptor = _find_lobby(request.lobby_id)
		if lobby == null:
			return _fail_operation(handle, &"not_found", "Lobby was not found.")
		lobby.metadata = GFVariantData.merge_dictionary(
			lobby.metadata,
			request.payload,
			true
		)
		_store_lobby(lobby)
		_emit_lobby_updated(lobby)
		return _succeed_operation(handle, {"lobby": lobby})

	func _set_member_metadata(
		request: GFNetworkLobbyOperationRequest,
		handle: GFNetworkLobbyOperationHandle
	) -> bool:
		var lobby: GFNetworkLobbyDescriptor = _find_lobby(request.lobby_id)
		if lobby == null:
			return _fail_operation(handle, &"not_found", "Lobby was not found.")
		var member: GFNetworkLobbyMember = lobby.get_member(request.peer_id)
		if member == null:
			return _fail_operation(handle, &"member_not_found", "Lobby member was not found.")
		member.metadata = GFVariantData.merge_dictionary(
			member.metadata,
			request.payload,
			true
		)
		lobby.set_member(member)
		_store_lobby(lobby)
		_emit_lobby_updated(lobby)
		return _succeed_operation(handle, {"lobby": lobby})

	func emit_member_joined_for_test(lobby_id: String, member: GFNetworkLobbyMember) -> void:
		_emit_member_joined(lobby_id, member)

	func emit_member_left_for_test(lobby_id: String, peer_id: int) -> void:
		_emit_member_left(lobby_id, peer_id, "left")

	func _store_lobby(lobby: GFNetworkLobbyDescriptor) -> void:
		for index: int in range(lobbies.size()):
			if lobbies[index] != null and lobbies[index].lobby_id == lobby.lobby_id:
				lobbies[index] = lobby.duplicate_lobby()
				return
		lobbies.append(lobby.duplicate_lobby())

	func _find_lobby(lobby_id: String) -> GFNetworkLobbyDescriptor:
		for lobby: GFNetworkLobbyDescriptor in lobbies:
			if lobby != null and lobby.lobby_id == lobby_id:
				return lobby.duplicate_lobby()
		return null


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


func test_network_serializer_rejects_malformed_message_schema_before_normalization() -> void:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	var malformed_payload: PackedByteArray = serializer.serialize_dictionary({
		"type": &"state_update",
		"payload": "not-a-dictionary",
	})
	var malformed_sequence: PackedByteArray = serializer.serialize_dictionary({
		"type": &"state_update",
		"payload": {},
		"sequence": "seven",
	})

	var payload_result: Dictionary = serializer.deserialize_message_result(malformed_payload)
	var sequence_result: Dictionary = serializer.deserialize_message_result(malformed_sequence)

	assert_false(GFVariantData.get_option_bool(payload_result, "ok"), "错误 payload 类型不得归一化为空字典。")
	assert_eq(GFVariantData.get_option_string(payload_result, "error"), "payload_not_dictionary")
	assert_false(GFVariantData.get_option_bool(sequence_result, "ok"), "错误 sequence 类型必须在构造消息前拒绝。")
	assert_eq(GFVariantData.get_option_string(sequence_result, "error"), "sequence_not_integer")


func test_network_service_discovery_round_trips_packet_and_expires_service() -> void:
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var found_keys: PackedStringArray = PackedStringArray()
	var lost_keys: PackedStringArray = PackedStringArray()
	var _found_connected: Variant = discovery.service_found.connect(func(found_service_key: String, _record: Dictionary) -> void:
		var _append_result: bool = found_keys.append(found_service_key)
	)
	var _lost_connected: Variant = discovery.service_lost.connect(func(lost_service_key: String, _record: Dictionary, _reason: String) -> void:
		var _append_result: bool = lost_keys.append(lost_service_key)
	)
	var advertisement: Dictionary = discovery.make_advertisement(
		&"lobby",
		"enet://127.0.0.1:24567",
		{ "players": 2 },
		{
			"ttl_seconds": 1.0,
			"tags": PackedStringArray(["lan", "debug"]),
			"sequence": 7,
		}
	)

	var packet: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(advertisement)
	var decoded: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(packet)
	var accept_report: Dictionary = discovery.accept_packet(packet, "127.0.0.1", 32000)
	var service_key: String = GFVariantData.get_option_string(accept_report, "service_key")
	var record: Dictionary = discovery.get_service(service_key)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(record, "metadata")
	var tags: PackedStringArray = GFVariantData.get_option_packed_string_array(record, "tags")

	assert_true(GFVariantData.get_option_bool(decoded, "ok"), "服务广告应能 JSON 往返。")
	assert_true(GFVariantData.get_option_bool(accept_report, "ok"), "合法服务广告应被接收。")
	assert_eq(GFVariantData.get_option_string(accept_report, "status"), "found", "首次接收应报告 found。")
	assert_eq(service_key, GFNetworkServiceDiscovery.make_service_key(&"lobby", "enet://127.0.0.1:24567"), "服务 key 应稳定。")
	assert_true(found_keys.has(service_key), "首次接收应发出 service_found。")
	assert_eq(GFVariantData.get_option_int(metadata, "players"), 2, "服务 metadata 应保留。")
	assert_true(tags.has("lan"), "服务 tags 应保留。")
	assert_eq(GFVariantData.get_option_string(record, "remote_address"), "127.0.0.1", "远端地址应写入记录。")
	assert_eq(GFVariantData.get_option_int(record, "remote_port"), 32000, "远端端口应写入记录。")

	discovery.tick(0.9)
	assert_eq(discovery.get_services().size(), 1, "TTL 未到期时服务应保留。")
	discovery.tick(0.2)
	assert_true(discovery.get_services().is_empty(), "TTL 到期后服务应移除。")
	assert_true(lost_keys.has(service_key), "服务过期应发出 service_lost。")


func test_network_service_discovery_refresh_extends_existing_service_ttl() -> void:
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var updated_keys: PackedStringArray = PackedStringArray()
	var _updated_connected: Variant = discovery.service_updated.connect(func(updated_service_key: String, _record: Dictionary) -> void:
		var _append_result: bool = updated_keys.append(updated_service_key)
	)
	var advertisement: Dictionary = discovery.make_advertisement(&"lobby", "ws://localhost:9988", {}, {
		"ttl_seconds": 1.0,
		"sequence": 1,
	})

	var first_report: Dictionary = discovery.accept_advertisement(advertisement)
	discovery.tick(0.8)
	advertisement["sequence"] = 2
	var refresh_report: Dictionary = discovery.accept_advertisement(advertisement)
	discovery.tick(0.3)
	var service_key: String = GFVariantData.get_option_string(first_report, "service_key")
	var record: Dictionary = discovery.get_service(service_key)

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "首次服务广告应通过。")
	assert_eq(GFVariantData.get_option_string(refresh_report, "status"), "updated", "重复 endpoint 应报告 updated。")
	assert_true(updated_keys.has(service_key), "刷新服务应发出 service_updated。")
	assert_false(record.is_empty(), "刷新后的服务不应按旧 TTL 提前过期。")
	assert_eq(GFVariantData.get_option_int(record, "sequence"), 2, "刷新应更新服务记录字段。")


func test_network_service_discovery_uses_redacted_stable_service_keys() -> void:
	var raw_endpoint: String = "wss://user:secret@example.test:443/lobby?token=abc#debug"
	var key: String = GFNetworkServiceDiscovery.make_service_key(&"lobby", raw_endpoint)

	assert_true(key.begins_with("lobby@"), "服务 key 应保留服务类型前缀。")
	assert_false(key.contains("user"), "服务 key 不应暴露 endpoint userinfo。")
	assert_false(key.contains("secret"), "服务 key 不应暴露 endpoint 密码。")
	assert_false(key.contains("token"), "服务 key 不应暴露 query。")
	assert_false(key.contains("example.test"), "服务 key 不应暴露原始 host。")


func test_network_service_discovery_ignores_stale_advertisements() -> void:
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var advertisement: Dictionary = discovery.make_advertisement(&"lobby", "ws://localhost:9988", {
		"players": 4,
	}, {
		"sequence": 10,
		"time_msec": 1000,
	})

	var first_report: Dictionary = discovery.accept_advertisement(advertisement)
	advertisement["sequence"] = 9
	advertisement["metadata"] = { "players": 1 }
	var stale_report: Dictionary = discovery.accept_advertisement(advertisement)
	var record: Dictionary = discovery.get_service(GFVariantData.get_option_string(first_report, "service_key"))
	var metadata: Dictionary = GFVariantData.get_option_dictionary(record, "metadata")

	assert_eq(GFVariantData.get_option_string(stale_report, "status"), "ignored_stale", "低 sequence 广告不应覆盖当前记录。")
	assert_eq(GFVariantData.get_option_int(metadata, "players"), 4, "陈旧广告不应覆盖已有 metadata。")


func test_network_service_discovery_rejects_invalid_payloads() -> void:
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var empty_result: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(PackedByteArray())
	var invalid_payload: Dictionary = {
		"kind": GFNetworkServiceDiscovery.MESSAGE_KIND,
		"schema_version": GFNetworkServiceDiscovery.SCHEMA_VERSION,
		"service_id": "",
		"endpoint": "",
		"ttl_seconds": NAN,
	}
	var invalid_packet: PackedByteArray = GFVariantJsonCodec.stringify_json_compatible(
		invalid_payload
	).to_utf8_buffer()
	var invalid_result: Dictionary = discovery.accept_packet(invalid_packet)

	assert_false(GFVariantData.get_option_bool(empty_result, "ok"), "空 packet 应被拒绝。")
	assert_eq(GFVariantData.get_option_string(empty_result, "error"), "empty_bytes", "空 packet 应报告明确错误。")
	assert_false(GFVariantData.get_option_bool(invalid_result, "ok"), "无效服务广告应被拒绝。")
	assert_false(_find_report_issue(invalid_result, "missing_service_id").is_empty(), "缺失 service_id 应有稳定 issue kind。")
	assert_false(_find_report_issue(invalid_result, "missing_endpoint").is_empty(), "缺失 endpoint 应有稳定 issue kind。")
	assert_false(_find_report_issue(invalid_result, "invalid_ttl_seconds").is_empty(), "无效 TTL 应有稳定 issue kind。")
	assert_true(discovery.get_services().is_empty(), "坏包不应写入发现列表。")


func test_network_service_discovery_enforces_packet_and_metadata_budgets() -> void:
	var oversized_packet: PackedByteArray = PackedByteArray()
	var _resize_error: Error = oversized_packet.resize(GFNetworkMessageValidator.DEFAULT_MAX_PACKET_SIZE + 1) as Error
	var oversized_result: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(oversized_packet)

	var metadata: Dictionary = {}
	var cursor: Dictionary = metadata
	for index: int in range(6):
		var child: Dictionary = { "index": index }
		cursor["child"] = child
		cursor = child
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var advertisement: Dictionary = discovery.make_advertisement(&"lobby", "ws://localhost:9988", metadata)
	var deep_packet: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(advertisement)
	var restricted_options: Dictionary = {
		"max_metadata_depth": 3,
		"max_metadata_entries": 64,
	}
	var rejected_encode: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(
		advertisement,
		restricted_options
	)
	var deep_result: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(
		deep_packet,
		restricted_options
	)

	assert_false(GFVariantData.get_option_bool(oversized_result, "ok"), "超大广告应在 JSON parse 前拒绝。")
	assert_eq(GFVariantData.get_option_string(oversized_result, "error"), "advertisement_too_large")
	assert_true(rejected_encode.is_empty(), "encode 与 decode 必须共享相同 metadata 深度预算。")
	assert_false(GFVariantData.get_option_bool(deep_result, "ok"), "超深 metadata 应被结构预算拒绝。")
	assert_eq(GFVariantData.get_option_string(deep_result, "error"), "metadata_max_depth_exceeded")
	assert_push_error("[GFNetworkServiceDiscovery] 广告编码失败：metadata_max_depth_exceeded。")


func test_network_service_discovery_shares_byte_and_packed_entry_budgets() -> void:
	var discovery: GFNetworkServiceDiscovery = GFNetworkServiceDiscovery.new()
	var packed_metadata: PackedByteArray = PackedByteArray()
	var _packed_resize_error: Error = packed_metadata.resize(32) as Error
	var advertisement: Dictionary = discovery.make_advertisement(
		&"lobby",
		"ws://localhost:9988",
		{
			"packed": packed_metadata,
			"description": "x".repeat(256),
		}
	)
	var default_packet: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(advertisement)
	var entry_options: Dictionary = {
		"max_metadata_entries": 16,
	}
	var byte_options: Dictionary = {
		"max_advertisement_bytes": 64,
	}

	var entry_rejected_encode: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(
		advertisement,
		entry_options
	)
	var entry_rejected_decode: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(
		default_packet,
		entry_options
	)
	var byte_rejected_encode: PackedByteArray = GFNetworkServiceDiscovery.encode_advertisement(
		advertisement,
		byte_options
	)
	var byte_rejected_decode: Dictionary = GFNetworkServiceDiscovery.decode_advertisement(
		default_packet,
		byte_options
	)

	assert_true(entry_rejected_encode.is_empty(), "PackedArray 元素必须计入 encode 的 metadata 总节点预算。")
	assert_eq(GFVariantData.get_option_string(entry_rejected_decode, "error"), "metadata_max_nodes_exceeded", "decode 必须使用相同 PackedArray 节点预算。")
	assert_true(byte_rejected_encode.is_empty(), "encode 必须在返回前执行最终 UTF-8 byte 预算。")
	assert_eq(GFVariantData.get_option_string(byte_rejected_decode, "error"), "advertisement_too_large", "decode 必须在 parse 前执行同一 byte 预算。")
	assert_push_error("[GFNetworkServiceDiscovery] 广告编码失败：metadata_max_nodes_exceeded。")
	assert_push_error("[GFNetworkServiceDiscovery] 广告编码失败：advertisement_too_large。")


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


func test_network_contract_rejects_object_value_type() -> void:
	var field: GFNetworkContractField = GFNetworkContractField.new()
	field.field_name = &"runtime_object"
	field.value_type = GFNetworkContractField.ValueType.OBJECT

	var definition_report: Dictionary = field.validate_definition()
	var object_value: Node = Node.new()
	var value_report: Dictionary = field.validate_value(object_value)
	object_value.free()

	assert_false(GFVariantData.get_option_bool(definition_report, "ok"), "网络契约不应允许 Object 类型字段定义。")
	assert_false(GFVariantData.get_option_bool(value_report, "ok"), "网络契约不应允许 Object 值跨传输边界。")
	assert_false(_find_report_issue(definition_report, "object_value_type_not_transport_safe").is_empty(), "定义报告应说明 Object 不可传输。")


func test_network_contract_rejects_nested_transport_unsafe_values() -> void:
	var object_value: Node = Node.new()
	var dictionary_field: GFNetworkContractField = GFNetworkContractField.new()
	dictionary_field.field_name = &"dictionary"
	dictionary_field.value_type = GFNetworkContractField.ValueType.DICTIONARY
	var array_field: GFNetworkContractField = GFNetworkContractField.new()
	array_field.field_name = &"array"
	array_field.value_type = GFNetworkContractField.ValueType.ARRAY
	var variant_field: GFNetworkContractField = GFNetworkContractField.new()
	variant_field.field_name = &"variant"
	variant_field.value_type = GFNetworkContractField.ValueType.VARIANT

	var dictionary_report: Dictionary = dictionary_field.validate_value({ "nested": { "object": object_value } })
	var array_report: Dictionary = array_field.validate_value([[object_value]])
	var variant_report: Dictionary = variant_field.validate_value({ "object": object_value })
	object_value.free()

	assert_false(GFVariantData.get_option_bool(dictionary_report, "ok"), "Dictionary 字段不能嵌套 Object。")
	assert_false(GFVariantData.get_option_bool(array_report, "ok"), "Array 字段不能嵌套 Object。")
	assert_false(GFVariantData.get_option_bool(variant_report, "ok"), "Variant 字段不能绕过 transport-safe 校验。")
	assert_false(_find_report_issue(dictionary_report, "value_not_transport_safe").is_empty(), "报告应提供稳定 transport-safe issue。")


func test_network_transport_validator_rejects_non_finite_composite_values() -> void:
	var field: GFNetworkContractField = GFNetworkContractField.new()
	field.field_name = &"composite"
	field.value_type = GFNetworkContractField.ValueType.VARIANT
	var invalid_basis: Basis = Basis(
		Vector3.RIGHT,
		Vector3.UP,
		Vector3(0.0, 0.0, NAN)
	)
	var cases: Array[Dictionary] = [
		{"label": "Vector2", "value": Vector2(NAN, 0.0)},
		{"label": "Rect2", "value": Rect2(Vector2.ZERO, Vector2(INF, 1.0))},
		{"label": "Vector3", "value": Vector3(0.0, NAN, 0.0)},
		{"label": "Transform2D", "value": Transform2D(Vector2.RIGHT, Vector2.DOWN, Vector2(INF, 0.0))},
		{"label": "Vector4", "value": Vector4(0.0, 0.0, 0.0, NAN)},
		{"label": "Plane", "value": Plane(Vector3.UP, NAN)},
		{"label": "Quaternion", "value": Quaternion(0.0, 0.0, NAN, 1.0)},
		{"label": "AABB", "value": AABB(Vector3.ZERO, Vector3(INF, 1.0, 1.0))},
		{"label": "Basis", "value": invalid_basis},
		{"label": "Transform3D", "value": Transform3D(Basis.IDENTITY, Vector3(0.0, INF, 0.0))},
		{"label": "Color", "value": Color(1.0, 1.0, INF, 1.0)},
		{"label": "PackedVector2Array", "value": PackedVector2Array([Vector2(NAN, 0.0)])},
		{"label": "PackedVector3Array", "value": PackedVector3Array([Vector3(0.0, INF, 0.0)])},
		{"label": "PackedVector4Array", "value": PackedVector4Array([Vector4(0.0, 0.0, NAN, 0.0)])},
		{"label": "PackedColorArray", "value": PackedColorArray([Color(1.0, NAN, 1.0, 1.0)])},
	]

	for case_data: Dictionary in cases:
		var report: Dictionary = field.validate_value(case_data["value"])
		assert_false(
			GFVariantData.get_option_bool(report, "ok"),
			"%s 内的非有限分量必须在 transport 边界失败关闭。" % GFVariantData.get_option_string(case_data, "label")
		)


func test_network_peer_identity_and_lobby_descriptor_are_platform_neutral() -> void:
	var identity: GFNetworkPeerIdentity = GFNetworkPeerIdentity.new().configure(
		42,
		&"custom_platform",
		"external-user-1",
		"Tester",
		{ "region": "asia" },
		PackedStringArray(["invite", "lobby"])
	)
	var member: GFNetworkLobbyMember = GFNetworkLobbyMember.new().configure(42, identity, { "slot": 1 }, {
		"is_owner": true,
	})
	var lobby: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.new().configure("room-1", {
		"backend_id": &"fake",
		"owner_peer_id": 42,
		"max_members": 2,
		"tags": PackedStringArray(["ranked"]),
		"metadata": { "mode": "duel" },
		"members": [member],
	})
	var copy: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.from_dict(lobby.to_dict())

	assert_eq(identity.get_stable_key(), "custom_platform:external-user-1", "身份 key 应优先使用平台中立 platform/user 组合。")
	assert_true(identity.has_capability(&"invite"), "身份能力应可查询。")
	assert_eq(copy.lobby_id, "room-1", "Lobby ID 应能字典往返。")
	assert_eq(copy.get_member_count(), 1, "成员列表应能字典往返。")
	assert_eq(copy.get_member(42).get_display_name(), "Tester", "成员应保留身份展示名。")
	assert_false(copy.is_full(), "未达到 max_members 时不应视为已满。")


func test_network_lobby_query_filters_tags_metadata_and_capacity() -> void:
	var query: GFNetworkLobbyQuery = GFNetworkLobbyQuery.new()
	query.required_tags = PackedStringArray(["ranked"])
	query.required_metadata = { "mode": "duel" }
	var lobby: GFNetworkLobbyDescriptor = GFNetworkLobbyDescriptor.new().configure("room-1", {
		"display_name": "Ranked Duel",
		"max_members": 1,
		"tags": PackedStringArray(["ranked"]),
		"metadata": { "mode": "duel" },
		"members": [
			GFNetworkLobbyMember.new().configure(1),
		],
	})

	assert_false(query.matches(lobby), "默认查询不应包含已满 lobby。")
	query.include_full_lobbies = true
	assert_true(query.matches(lobby), "允许已满 lobby 后应匹配 tag 和 metadata。")
	query.search_text = "coop"
	assert_false(query.matches(lobby), "搜索文本不匹配时应拒绝。")


func test_network_lobby_service_tracks_backend_results_and_member_diffs() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)
	watch_signals(service)

	var create_handle: GFNetworkLobbyOperationHandle = service.create_lobby({
		"lobby_id": "room-1",
		"display_name": "Room One",
		"tags": PackedStringArray(["ranked"]),
	})
	var member: GFNetworkLobbyMember = GFNetworkLobbyMember.new().configure(7, GFNetworkPeerIdentity.new().configure(7, &"lan", "7"))
	backend.emit_member_joined_for_test("room-1", member)
	var current_after_join: GFNetworkLobbyDescriptor = service.current_lobby
	backend.emit_member_left_for_test("room-1", 7)
	var current_after_left: GFNetworkLobbyDescriptor = service.current_lobby
	var leave_handle: GFNetworkLobbyOperationHandle = service.leave_lobby()

	assert_true(create_handle.is_successful(), "创建请求应成功完成。")
	assert_not_null(current_after_join, "创建成功后 service 应记录 current_lobby。")
	assert_eq(current_after_join.get_member_count(), 1, "成员加入事件应更新 current_lobby。")
	assert_eq(current_after_left.get_member_count(), 0, "成员离开事件应更新 current_lobby。")
	assert_true(leave_handle.is_successful(), "离开请求应成功完成。")
	assert_signal_emitted(service, "lobby_created", "创建完成应转发 lobby_created。")
	assert_signal_emitted(service, "member_joined", "成员加入应转发 member_joined。")
	assert_signal_emitted(service, "member_left", "成员离开应转发 member_left。")


func test_network_lobby_service_correlates_concurrent_operations() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)

	var first: GFNetworkLobbyOperationHandle = service.create_lobby({
		"request_id": &"first",
		"hold": true,
	})
	var second: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"request_id": &"second",
		"hold": true,
	})
	var duplicate_handle: GFNetworkLobbyOperationHandle = service.create_lobby({
		"request_id": &"first",
	})

	assert_true(first.is_pending(), "首个操作应保持等待。")
	assert_true(second.is_pending(), "第二个操作应独立保持等待。")
	assert_eq(duplicate_handle.get_result().status, &"duplicate_request_id", "等待中的请求 ID 不得复用。")
	assert_true(backend.complete_held(&"second"), "应可按请求 ID 完成第二个操作。")
	assert_true(second.is_successful(), "第二个操作应成功。")
	assert_true(first.is_pending(), "完成第二个操作不应影响首个操作。")
	assert_true(backend.complete_held(&"first"), "应可按请求 ID 完成首个操作。")
	assert_eq(first.get_result().request_id, &"first", "结果必须保留请求关联。")


func test_network_lobby_service_timeout_cancels_backend_and_ignores_late_callback() -> void:
	var clock: GFManualClock = GFManualClock.new(1000000, 1700000000000)
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new(clock)
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)
	var handle: GFNetworkLobbyOperationHandle = service.create_lobby({
		"request_id": &"slow",
		"timeout_msec": 25,
		"hold": true,
	})

	var _advanced: bool = clock.advance_msec(25)
	service.tick(0.025)

	assert_eq(handle.get_result().status, &"timed_out", "截止时间应产生稳定超时终态。")
	assert_eq(backend.cancel_count, 1, "超时应通知 Backend 取消底层调用。")
	assert_eq(
		GFVariantData.get_option_int(backend.get_debug_snapshot(), "active_operation_count"),
		1,
		"Provider 确认前 Backend 必须保留操作租约。"
	)
	assert_false(backend.complete_handle_late(handle), "迟到回调不得覆盖超时结果。")
	assert_eq(
		GFVariantData.get_option_int(backend.get_debug_snapshot(), "active_operation_count"),
		0,
		"迟到 Provider 终态应释放操作租约。"
	)
	assert_eq(
		GFVariantData.get_option_int(backend.get_debug_snapshot(), "ignored_terminal_count"),
		1,
		"Backend 应记录被忽略的迟到终态。"
	)


func test_network_lobby_service_backend_replacement_cancels_pending_operation() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var old_backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var next_backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(old_backend)
	var populated: GFNetworkLobbyOperationHandle = service.create_lobby({
		"lobby_id": "old-room",
	})
	assert_true(populated.is_successful(), "旧 Backend 应先建立可观察状态。")
	assert_not_null(service.current_lobby, "测试应记录旧 Lobby。")
	var handle: GFNetworkLobbyOperationHandle = service.create_lobby({"hold": true})

	service.backend = next_backend

	assert_eq(handle.get_result().status, &"backend_replaced", "替换 Backend 应取消等待操作。")
	assert_eq(old_backend.cancel_count, 1, "旧 Backend 应收到取消通知。")
	assert_true(old_backend.closed, "旧 Backend 应在断开信号后关闭。")
	assert_eq(service.backend, next_backend, "Service 应切换到新 Backend。")
	assert_null(service.current_lobby, "Backend 世代切换必须清除旧 current_lobby。")
	assert_true(service.get_lobbies().is_empty(), "Backend 世代切换必须清除旧快照。")


func test_network_lobby_operation_started_reentry_cannot_reuse_request_id() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)
	var nested_handles: Array[GFNetworkLobbyOperationHandle] = []
	var started_callback: Callable = (
		func(_request: GFNetworkLobbyOperationRequest) -> void:
			nested_handles.append(service.query_lobbies(null, {
				"request_id": &"same_lobby_request",
			}))
	)
	var connected: Error = service.operation_started.connect(started_callback) as Error
	assert_eq(connected, OK, "测试应监听操作开始信号。")

	var original: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"request_id": &"same_lobby_request",
		"hold": true,
	})

	assert_true(original.is_pending(), "原操作应保留唯一请求租约。")
	assert_eq(nested_handles.size(), 1, "开始回调只应触发一次重入尝试。")
	assert_eq(
		nested_handles[0].get_result().status,
		&"duplicate_request_id",
		"开始信号重入不得绕过请求 ID 预留。"
	)
	service.operation_started.disconnect(started_callback)
	assert_true(service.cancel_operation(&"same_lobby_request"), "测试清理应取消原操作。")
	assert_false(backend.complete_held(&"same_lobby_request"), "迟到完成不得覆盖取消。")
	service.dispose()


func test_network_lobby_backend_change_during_start_fails_before_dispatch() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var old_backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var next_backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(old_backend)
	var started_callback: Callable = (
		func(_request: GFNetworkLobbyOperationRequest) -> void:
			service.backend = next_backend
	)
	var connected: Error = service.operation_started.connect(started_callback) as Error
	assert_eq(connected, OK, "测试应监听操作开始信号。")

	var handle: GFNetworkLobbyOperationHandle = service.query_lobbies()

	service.operation_started.disconnect(started_callback)
	assert_eq(
		handle.get_result().status,
		&"backend_replaced_before_dispatch",
		"开始回调替换 Backend 后不得向旧世代派发。"
	)
	assert_true(old_backend.closed, "旧 Backend 应关闭。")
	assert_eq(service.backend, next_backend, "Service 应保留新 Backend。")
	service.dispose()


func test_network_lobby_invalid_success_results_fail_closed() -> void:
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new()
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)

	var create_handle: GFNetworkLobbyOperationHandle = service.create_lobby({
		"invalid_result": true,
	})
	var query_handle: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"invalid_result": true,
	})
	var malformed_entry_handle: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"malformed_lobbies": [123],
	})
	var malformed_container_handle: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"malformed_lobbies": "not-an-array",
	})

	assert_eq(
		create_handle.get_result().status,
		&"invalid_backend_result",
		"创建成功不得缺少 Lobby。"
	)
	assert_eq(
		query_handle.get_result().status,
		&"invalid_backend_result",
		"查询成功不得包含重复 Lobby ID。"
	)
	assert_eq(
		malformed_entry_handle.get_result().status,
		&"invalid_backend_result",
		"查询成功不得静默丢弃非法 Lobby 条目。"
	)
	assert_eq(
		malformed_container_handle.get_result().status,
		&"invalid_backend_result",
		"查询成功不得把非法 Lobby 容器降级为空列表。"
	)
	var malformed_serialized: GFNetworkLobbyOperationResult = (
		GFNetworkLobbyOperationResult.from_dict({
			"request_id": &"serialized_invalid_lobbies",
			"operation": GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES,
			"ok": true,
			"status": &"ok",
			"lobbies": [123],
		})
	)
	assert_false(malformed_serialized.is_valid(), "反序列化结果不得丢弃非法 Lobby 条目。")
	assert_false(
		malformed_serialized.duplicate_result().is_valid(),
		"非法载荷状态必须在结果深拷贝后保留。"
	)
	service.dispose()


func test_network_lobby_timeout_wins_same_tick_provider_completion() -> void:
	var clock: GFManualClock = GFManualClock.new(1000000, 1700000000000)
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new(clock)
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)
	var handle: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"request_id": &"deadline_race",
		"timeout_msec": 10,
		"hold": true,
	})
	backend.complete_during_poll = true
	var _advanced: bool = clock.advance_msec(10)

	service.tick(0.01)

	assert_eq(handle.get_result().status, &"timed_out", "截止时间终态必须先于同帧 poll。")
	assert_eq(backend.cancel_count, 1, "超时只应请求一次 Provider 取消。")
	assert_eq(
		GFVariantData.get_option_int(backend.get_debug_snapshot(), "ignored_terminal_count"),
		1,
		"同帧迟到成功应被记录并忽略。"
	)
	assert_eq(
		GFVariantData.get_option_int(backend.get_debug_snapshot(), "active_operation_count"),
		0,
		"迟到回调后 Provider 租约应释放。"
	)
	service.dispose()


func test_network_lobby_debug_snapshot_omits_request_secrets_and_zero_time_is_valid() -> void:
	var clock: GFManualClock = GFManualClock.new(0, 1700000000000)
	var service: GFNetworkLobbyService = GFNetworkLobbyService.new(clock)
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	var _backend_set: bool = service.set_backend(backend)
	var pending_handle: GFNetworkLobbyOperationHandle = service.query_lobbies(null, {
		"request_id": &"secret_lobby_request",
		"hold": true,
		"token": "provider-secret",
		"metadata": {"access_token": "metadata-secret"},
	})
	var debug_text: String = JSON.stringify(pending_handle.get_debug_snapshot())

	assert_false(debug_text.contains("provider-secret"), "Provider 选项不得进入句柄快照。")
	assert_false(debug_text.contains("metadata-secret"), "请求 metadata 不得进入句柄快照。")
	assert_true(service.cancel_operation(&"secret_lobby_request"), "测试应取消等待操作。")
	assert_false(backend.complete_held(&"secret_lobby_request"), "迟到成功不得覆盖取消。")

	var completed: GFNetworkLobbyOperationHandle = service.create_lobby({
		"lobby_id": "zero-time-room",
	})
	assert_true(completed.is_successful(), "零时间戳成功结果必须有效。")
	assert_eq(completed.get_result().started_at_msec, 0)
	assert_eq(completed.get_result().completed_at_msec, 0)
	assert_eq(completed.get_result().get_duration_msec(), 0)
	service.dispose()


func test_network_lobby_backend_close_blocks_cancel_hook_reentry() -> void:
	var backend: FakeLobbyBackend = FakeLobbyBackend.new()
	backend.reenter_on_cancel = true
	var request: GFNetworkLobbyOperationRequest = (
		GFNetworkLobbyOperationRequest.new().configure(
			&"close_pending",
			GFNetworkLobbyOperationRequest.OP_QUERY_LOBBIES,
			{"provider_options": {"hold": true}}
		)
	)
	var handle: GFNetworkLobbyOperationHandle = backend.invoke_operation(request)

	backend.close()

	assert_eq(handle.get_result().status, &"backend_closed", "关闭应结束等待操作。")
	assert_eq(backend.cancel_count, 1, "关闭只应通知取消一次。")
	assert_eq(
		backend.reentrant_status,
		&"backend_closed",
		"取消钩子中的重入必须被关闭状态拒绝。"
	)


func test_network_message_validator_strict_contract_and_peer_context() -> void:
	var contract: GFNetworkContract = _make_lobby_network_contract()
	var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()
	validator.configure_from_contract(contract)
	validator.require_contract_message = true
	validator.enforce_sender_id_matches_peer = true
	validator.require_sender_id = true
	validator.min_sequence = 1
	validator.max_sequence = 10
	var valid: GFNetworkMessage = contract.make_message(&"player_ready", { "slot": 1 }, {
		"sender_id": 3,
		"sequence": 2,
	})
	var spoofed: GFNetworkMessage = contract.make_message(&"player_ready", { "slot": 1 }, {
		"sender_id": 9,
		"sequence": 2,
	})
	var unknown: GFNetworkMessage = GFNetworkMessage.new(&"unknown", {}, 2, 0, 3)
	var wrong_type: GFNetworkMessage = contract.make_message(&"player_ready", { "slot": "1" }, {
		"sender_id": 3,
		"sequence": 2,
	})

	var valid_report: Dictionary = validator.validate_message_for_peer(valid, 3)
	var spoofed_report: Dictionary = validator.validate_message_for_peer(spoofed, 3)
	var unknown_report: Dictionary = validator.validate_message_for_peer(unknown, 3)
	var wrong_type_report: Dictionary = validator.validate_message_for_peer(wrong_type, 3)

	assert_true(GFVariantData.get_option_bool(valid_report, "ok"), "合法消息应通过 strict 校验。")
	assert_false(GFVariantData.get_option_bool(spoofed_report, "ok"), "sender_id 与实际 peer 不一致应失败。")
	assert_true(GFVariantData.get_option_packed_string_array(spoofed_report, "errors").has("sender_id_mismatch"), "伪造 sender 应有稳定错误。")
	assert_true(GFVariantData.get_option_packed_string_array(unknown_report, "errors").has("unknown_contract_message_type"), "未知契约消息应失败。")
	assert_true(GFVariantData.get_option_packed_string_array(wrong_type_report, "errors").has("contract:type_mismatch"), "payload 类型错误应进入 contract 错误。")


func test_network_contract_audit_reports_loose_fields_and_unknown_channels() -> void:
	var loose_field: GFNetworkContractField = GFNetworkContractField.new()
	loose_field.field_name = &"payload"
	loose_field.value_type = GFNetworkContractField.ValueType.VARIANT
	var message_contract: GFNetworkContractMessage = GFNetworkContractMessage.new()
	message_contract.message_type = &"loose"
	message_contract.channel_id = &"unknown"
	message_contract.fields = [loose_field]
	var contract: GFNetworkContract = GFNetworkContract.new()
	contract.contract_id = &"audit"
	contract.messages = [message_contract]
	var audit: GFNetworkContractAudit = GFNetworkContractAudit.new()

	var report: Dictionary = audit.audit_contract(contract, {
		"known_channel_ids": PackedStringArray(["reliable"]),
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "松散字段和未知通道应产生审计问题。")
	assert_false(_find_report_issue(report, "unknown_channel_id").is_empty(), "未知通道应有稳定 issue kind。")
	assert_false(_find_report_issue(report, "loose_variant_field").is_empty(), "Variant 字段应有稳定 issue kind。")


func test_network_field_serializer_replaces_non_finite_numbers() -> void:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = GFNetworkFieldSerializer.ValueType.VECTOR3

	var encoded: Array = serializer.serialize_value(Vector3(NAN, INF, 1.5))

	assert_eq(GFVariantData.to_float(encoded[0]), 0.0, "NaN 不应穿过网络字段序列化边界。")
	assert_eq(GFVariantData.to_float(encoded[1]), 0.0, "INF 不应穿过网络字段序列化边界。")
	assert_eq(GFVariantData.to_float(encoded[2]), 1.5, "有限值应保留。")


func test_network_field_serializer_round_trips_normalized_quaternion() -> void:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = GFNetworkFieldSerializer.ValueType.QUATERNION
	var source_quaternion: Quaternion = Quaternion(Vector3.UP, 0.75)

	var encoded: Array = GFVariantData.as_array(serializer.serialize_value(source_quaternion))
	var decoded_value: Variant = serializer.deserialize_value(encoded)

	assert_eq(encoded.size(), 4, "Quaternion 应编码为 x/y/z/w 四个分量。")
	assert_true(decoded_value is Quaternion, "Quaternion 字段应恢复原始值类型。")
	if not (decoded_value is Quaternion):
		return
	var decoded_quaternion: Quaternion = decoded_value
	assert_almost_eq(decoded_quaternion.x, source_quaternion.x, 0.000001, "x 分量应往返。")
	assert_almost_eq(decoded_quaternion.y, source_quaternion.y, 0.000001, "y 分量应往返。")
	assert_almost_eq(decoded_quaternion.z, source_quaternion.z, 0.000001, "z 分量应往返。")
	assert_almost_eq(decoded_quaternion.w, source_quaternion.w, 0.000001, "w 分量应往返。")
	assert_almost_eq(decoded_quaternion.length_squared(), 1.0, 0.000001, "解码后的旋转应保持单位长度。")


func test_network_field_serializer_sanitizes_and_quantizes_quaternion() -> void:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = GFNetworkFieldSerializer.ValueType.QUATERNION
	serializer.quantize_decimals = 1

	var encoded: Array = GFVariantData.as_array(serializer.serialize_value(Quaternion(0.2, 0.4, 0.1, 0.8)))
	var encoded_quaternion: Quaternion = Quaternion(
		GFVariantData.to_float(encoded[0]),
		GFVariantData.to_float(encoded[1]),
		GFVariantData.to_float(encoded[2]),
		GFVariantData.to_float(encoded[3])
	)
	var invalid_encoded: Array = GFVariantData.as_array(serializer.serialize_value(Quaternion(NAN, 0.0, 0.0, 1.0)))
	var huge_encoded: Array = GFVariantData.as_array(serializer.serialize_value(Quaternion(1.0e20, 0.0, 0.0, 1.0)))
	var huge_quaternion: Quaternion = Quaternion(
		GFVariantData.to_float(huge_encoded[0]),
		GFVariantData.to_float(huge_encoded[1]),
		GFVariantData.to_float(huge_encoded[2]),
		GFVariantData.to_float(huge_encoded[3])
	)
	var huge_decoded: Variant = serializer.deserialize_value([1.0e300, 0.0, 0.0, 1.0])
	var zero_decoded: Variant = serializer.deserialize_value([0.0, 0.0, 0.0, 0.0])
	var non_finite_decoded: Variant = serializer.deserialize_value([0.0, INF, 0.0, 1.0])
	var huge_decoded_quaternion: Quaternion = Quaternion.IDENTITY
	var zero_quaternion: Quaternion = Quaternion.IDENTITY
	var non_finite_quaternion: Quaternion = Quaternion.IDENTITY
	assert_true(huge_decoded is Quaternion, "有限超大分量仍应恢复 Quaternion 类型。")
	assert_true(zero_decoded is Quaternion, "零长度字段仍应恢复 Quaternion 类型。")
	assert_true(non_finite_decoded is Quaternion, "非有限字段仍应恢复 Quaternion 类型。")
	if huge_decoded is Quaternion:
		huge_decoded_quaternion = huge_decoded
	if zero_decoded is Quaternion:
		zero_quaternion = zero_decoded
	if non_finite_decoded is Quaternion:
		non_finite_quaternion = non_finite_decoded

	var expected_quantized: Quaternion = Quaternion(0.2, 0.4, 0.1, 0.9).normalized()
	assert_almost_eq(encoded_quaternion.x, expected_quantized.x, 0.000001, "Quaternion 的 x 分量应按策略量化后归一化。")
	assert_almost_eq(encoded_quaternion.y, expected_quantized.y, 0.000001, "Quaternion 的 y 分量应按策略量化后归一化。")
	assert_almost_eq(encoded_quaternion.z, expected_quantized.z, 0.000001, "Quaternion 的 z 分量应按策略量化后归一化。")
	assert_almost_eq(encoded_quaternion.w, expected_quantized.w, 0.000001, "Quaternion 的 w 分量应按策略量化后归一化。")
	assert_almost_eq(encoded_quaternion.length_squared(), 1.0, 0.000001, "量化后仍应重新归一化 Quaternion。")
	assert_almost_eq(huge_quaternion.length_squared(), 1.0, 0.000001, "有限超大分量不应因平方溢出变成零 Quaternion。")
	assert_almost_eq(huge_quaternion.x, 1.0, 0.000001, "超大分量编码应保留旋转方向。")
	assert_almost_eq(huge_quaternion.w, 0.0, 0.000001, "超大分量编码不应伪装成单位旋转。")
	assert_almost_eq(huge_decoded_quaternion.length_squared(), 1.0, 0.000001, "超大分量解码结果应保持单位长度。")
	assert_almost_eq(huge_decoded_quaternion.x, 1.0, 0.000001, "超大分量解码应保留旋转方向。")
	assert_almost_eq(huge_decoded_quaternion.w, 0.0, 0.000001, "超大分量解码不应退化为单位旋转。")
	assert_eq(invalid_encoded, [0.0, 0.0, 0.0, 1.0], "非有限 Quaternion 应编码为单位旋转。")
	assert_eq(zero_quaternion, Quaternion.IDENTITY, "零长度 Quaternion 应解码为单位旋转。")
	assert_eq(non_finite_quaternion, Quaternion.IDENTITY, "非有限 Quaternion 分量应解码为单位旋转。")


func test_network_contract_exposes_version_digest_and_peer_preflight() -> void:
	var contract: GFNetworkContract = _make_lobby_network_contract()
	contract.contract_version_major = 2
	contract.contract_version_minor = 20260308

	var version: Dictionary = contract.get_contract_version()
	var digest: String = GFVariantData.get_option_string(version, "schema_digest")
	var ok_report: Dictionary = contract.validate_peer_contract_version(version, {
		"require_schema_digest": true,
	})
	var mismatched_major: Dictionary = version.duplicate(true)
	mismatched_major["version_major"] = 3
	var major_report: Dictionary = contract.validate_peer_contract_version(mismatched_major)
	var mismatched_digest: Dictionary = version.duplicate(true)
	mismatched_digest["schema_digest"] = "0000000000000000000000000000000000000000000000000000000000000000"
	var digest_report: Dictionary = contract.validate_peer_contract_version(mismatched_digest, {
		"require_schema_digest": true,
	})

	assert_eq(GFVariantData.get_option_string_name(version, "contract_id"), &"lobby", "版本字典应包含契约 ID。")
	assert_eq(GFVariantData.get_option_int(version, "version_major"), 2, "版本字典应包含大版本。")
	assert_eq(GFVariantData.get_option_int(version, "version_minor"), 20260308, "版本字典应包含小版本。")
	assert_eq(GFVariantData.get_option_int(version, "schema_descriptor_version"), 1, "版本字典应包含 schema 描述格式版本。")
	assert_eq(digest.length(), 64, "schema digest 应为 SHA-256 hex。")
	assert_true(digest.is_valid_hex_number(), "schema digest 应使用 hex 文本。")
	assert_true(GFVariantData.get_option_bool(ok_report, "ok"), "相同契约版本和摘要应通过预检。")
	assert_false(GFVariantData.get_option_bool(major_report, "ok"), "大版本不一致应失败。")
	assert_false(_find_report_issue(major_report, "contract_version_major_mismatch").is_empty(), "大版本不一致应有稳定 issue kind。")
	assert_false(GFVariantData.get_option_bool(digest_report, "ok"), "要求摘要时 schema digest 不一致应失败。")
	assert_false(_find_report_issue(digest_report, "contract_schema_digest_mismatch").is_empty(), "摘要不一致应有稳定 issue kind。")


func test_network_contract_schema_digest_ignores_display_metadata_and_tracks_structure() -> void:
	var first: GFNetworkContract = _make_lobby_network_contract()
	first.display_name = "Lobby A"
	first.metadata = { "owner": "tools" }
	var second: GFNetworkContract = _make_lobby_network_contract()
	second.display_name = "Lobby B"
	second.metadata = { "owner": "runtime" }

	assert_eq(first.get_schema_digest(), second.get_schema_digest(), "display_name 和 metadata 不应改变 schema digest。")

	var message_contract: GFNetworkContractMessage = second.get_message_contract(&"player_ready")
	assert_not_null(message_contract, "测试契约应包含 player_ready 消息。")
	if message_contract == null:
		return
	var slot_field: GFNetworkContractField = message_contract.get_field(&"slot")
	assert_not_null(slot_field, "测试契约应包含 slot 字段。")
	if slot_field == null:
		return
	slot_field.required = false

	assert_ne(first.get_schema_digest(), second.get_schema_digest(), "字段结构变化应改变 schema digest。")


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
	contract.contract_version_major = 2
	contract.contract_version_minor = 42
	contract.messages = [message_contract]
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()

	var source: String = generator.build_source(contract, { "class_name": "LobbyNetworkMessages" })

	assert_true(source.contains("class_name LobbyNetworkMessages"), "应生成指定 class_name。")
	assert_true(source.contains("const CONTRACT_ID: StringName = &\"lobby\""), "应生成契约 ID 常量。")
	assert_true(source.contains("const CONTRACT_VERSION_MAJOR: int = 2"), "应生成契约大版本常量。")
	assert_true(source.contains("const CONTRACT_VERSION_MINOR: int = 42"), "应生成契约小版本常量。")
	assert_true(source.contains("const CONTRACT_SCHEMA_DIGEST: String = \""), "应生成契约 schema digest 常量。")
	assert_true(source.contains("static func get_contract_version() -> Dictionary:"), "应生成契约版本描述函数。")
	assert_true(source.contains("static func validate_peer_contract_version(peer_version: Dictionary, options: Dictionary = {}) -> Dictionary:"), "应生成契约版本预检函数。")
	assert_true(source.contains("const MESSAGE_PLAYER_READY: StringName = &\"player_ready\""), "应生成消息常量。")
	assert_true(source.contains("const CHANNEL_PLAYER_READY: StringName = &\"lobby\""), "应生成默认通道常量。")
	assert_true(source.contains("static func make_player_ready(slot: int, ready: bool = false, options: Dictionary = {}) -> GFNetworkMessage:"), "应生成强类型构造函数。")
	assert_true(source.contains("static func send_player_ready(network: GFNetworkUtility, peer_id: int, slot: int, ready: bool = false, options: Dictionary = {}) -> Error:"), "应生成强类型发送函数。")
	assert_true(source.contains("static func get_player_ready_slot(message: GFNetworkMessage, default_value: int = 0) -> int:"), "应生成字段读取函数。")

	var compile_report: Dictionary = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.compile_and_release(
		source.replace("class_name LobbyNetworkMessages\n", "")
	)
	assert_true(
		GFVariantData.get_option_bool(compile_report, "ok"),
		"生成源码去掉全局类注册行后应能被 GDScript 编译：%s" % compile_report
	)


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

	var compile_report: Dictionary = GF_TRANSIENT_GDSCRIPT_TEST_SUPPORT.compile_and_release(
		source.replace("class_name LobbyNetworkMessages\n", "")
	)
	assert_true(
		GFVariantData.get_option_bool(compile_report, "ok"),
		"可选 null 语义生成源码应能编译：%s" % compile_report
	)


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


func test_network_contract_generator_generate_with_report_reports_skipped_without_writing() -> void:
	var contract: GFNetworkContract = _make_lobby_network_contract()
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()
	var path: String = "user://gf_network_contract_generator_skip_%d.gd" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时网络契约生成文件。")
	if file == null:
		return
	var _store_string_result_214: Variant = file.store_string("manual")
	file.close()

	var report: Dictionary = generator.generate_with_report(contract, path, {
		"class_name": "LobbyNetworkMessages",
		"overwrite_existing": false,
		"scan_filesystem": false,
	})
	var read_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(read_file, "测试应能读取临时网络契约生成文件。")
	if read_file == null:
		var _cleanup_error_227: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var content: String = read_file.get_as_text()
	read_file.close()
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "测试应能删除临时网络契约生成文件。")

	assert_true(GFVariantData.get_option_bool(report, "success"), "skipped artifact 不应被标记为失败。")
	assert_eq(GFVariantData.get_option_string_name(report, "status"), GFGeneratedArtifactReport.STATUS_SKIPPED, "禁止覆盖时应返回 skipped 产物状态。")
	assert_eq(GFGeneratedArtifactReport.get_error_code(report), ERR_ALREADY_EXISTS, "报告仍应保留可供调用方阻断的错误码。")
	assert_false(GFVariantData.get_option_bool(report, "written"), "skipped artifact 不应写入文件。")
	assert_eq(content, "manual", "skipped artifact 不应改写已有文件。")
	assert_push_warning("[GFNetworkContractGenerator] 目标文件已存在，已跳过：%s" % path)


func test_network_contract_generator_generate_many_treats_skipped_artifacts_as_non_failed() -> void:
	var contract: GFNetworkContract = _make_lobby_network_contract()
	var generator: GFNetworkContractGenerator = GFNetworkContractGenerator.new()
	var stamp: int = Time.get_ticks_usec()
	var contract_path: String = "user://gf_network_contract_%d.tres" % stamp
	var output_dir: String = "user://gf_network_contract_many_%d" % stamp
	var output_path: String = output_dir.path_join("lobby_network_messages.gd")
	assert_eq(ResourceSaver.save(contract, contract_path), OK, "测试应能写入临时契约资源。")
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)), OK, "测试应能创建临时输出目录。")
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时输出文件。")
	if file == null:
		var _cleanup_contract_error_258: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(contract_path))
		var _cleanup_dir_error_259: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir))
		return
	var _store_string_result_262: Variant = file.store_string("manual")
	file.close()

	var report: Dictionary = generator.generate_many(PackedStringArray([contract_path]), output_dir, false, {
		"scan_filesystem": false,
	})
	var artifact_summary: Dictionary = GFVariantData.get_option_dictionary(report, "artifact_summary")
	var generated_items: Array = GFVariantData.get_option_array(report, "generated")
	var first_item: Dictionary = GFVariantData.as_dictionary(generated_items[0])
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(output_path)), OK, "测试应能删除临时输出文件。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(contract_path)), OK, "测试应能删除临时契约资源。")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(output_dir)), OK, "测试应能删除临时输出目录。")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "批量生成中的 skipped artifact 不应让报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 0, "skipped artifact 不应生成 issue。")
	assert_eq(GFVariantData.get_option_int(report, "attempted_count"), 1, "批量报告应统计所有输入路径。")
	assert_eq(GFVariantData.get_option_int(report, "generated_count"), 0, "skipped artifact 不应计入实际写入数量。")
	assert_eq(GFVariantData.get_option_int(report, "skipped_count"), 1, "批量报告应统计 skipped artifact。")
	assert_eq(GFVariantData.get_option_int(artifact_summary, "skipped_count"), 1, "artifact summary 应保留 skipped 计数。")
	assert_eq(GFVariantData.get_option_string(first_item, "status"), String(GFGeneratedArtifactReport.STATUS_SKIPPED), "生成记录应暴露 artifact status。")
	assert_push_warning("[GFNetworkContractGenerator] 目标文件已存在，已跳过：%s" % output_path)


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
	var expected_rng: GFDeterministicRandom = GFDeterministicRandom.new()
	policy.delays_msec = [100]
	policy.jitter_ratio = 0.5
	policy.set_jitter_seed(12345)
	expected_rng.set_seed(12345)

	var expected: int = maxi(roundi(100.0 + expected_rng.next_float_range(-50.0, 50.0)), 0)

	assert_eq(policy.get_next_delay_msec(), expected, "jitter 应通过公开 seed 入口保持确定性。")


func test_network_runtime_numeric_configuration_rejects_non_finite_values() -> void:
	var limiter: GFNetworkRateLimiter = GFNetworkRateLimiter.new()
	limiter.capacity = NAN
	limiter.refill_per_second = INF
	limiter.tick(NAN)
	var consumed_infinite: bool = limiter.consume(INF)

	var policy: GFNetworkReconnectPolicy = GFNetworkReconnectPolicy.new()
	policy.jitter_ratio = NAN
	var nan_jitter: float = policy.jitter_ratio
	policy.jitter_ratio = INF

	var tracker: GFNetworkDirtyStateTracker = GFNetworkDirtyStateTracker.new()
	tracker.epsilon = NAN
	var nan_epsilon: float = tracker.epsilon
	tracker.epsilon = INF

	assert_false(is_nan(limiter.capacity) or is_inf(limiter.capacity), "capacity 必须保持有限。")
	assert_false(is_nan(limiter.refill_per_second) or is_inf(limiter.refill_per_second), "refill 必须保持有限。")
	assert_false(consumed_infinite, "非有限令牌消费必须 fail closed。")
	assert_eq(nan_jitter, 0.0, "NaN jitter 应归一化为禁用抖动。")
	assert_eq(policy.jitter_ratio, 0.0, "Inf jitter 应归一化为禁用抖动。")
	assert_eq(nan_epsilon, 0.0, "NaN epsilon 应归一化为严格比较。")
	assert_eq(tracker.epsilon, 0.0, "Inf epsilon 应归一化为严格比较。")


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


func test_network_sequence_is_transport_metadata_not_builtin_dedupe() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var received: Array[GFNetworkMessage] = []
	var _connect_result_271: Variant = utility.message_received.connect(func(_peer_id: int, received_message: GFNetworkMessage) -> void:
		received.append(received_message)
	)
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	var bytes: PackedByteArray = serializer.serialize_message(GFNetworkMessage.new(&"state", { "hp": 10 }, 7))

	backend.message_received.emit(4, bytes)
	backend.message_received.emit(4, bytes)

	assert_eq(received.size(), 2, "GF Network 不应基于 sequence 内置去重，ACK/去重属于项目层协议。")
	assert_eq(received[0].sequence, 7)
	assert_eq(received[1].sequence, 7)


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


func test_network_direct_send_applies_matching_channel_policy() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.transfer_channel = 2
	channel.reliable = false
	channel.max_packet_size = 8
	utility.register_channel(channel)

	var error: Error = utility.send_message(3, GFNetworkMessage.new(&"state", { "payload": "too large" }))

	assert_eq(error, ERR_INVALID_DATA, "direct send 不得绕过同名通道的包体上限。")
	assert_true(backend.sent_bytes.is_empty(), "被通道策略拒绝的消息不应到达后端。")

	channel.max_packet_size = 0
	error = utility.send_message(3, GFNetworkMessage.new(&"other", {}, 0, 0, -1, &"state"))
	assert_eq(error, OK, "合法 direct send 应成功。")
	assert_eq(GFVariantData.get_option_int(backend.sent_options, "channel"), 2, "channel_id 命中时应合并通道发送选项。")
	assert_false(GFVariantData.get_option_bool(backend.sent_options, "reliable", true), "direct send 应使用通道可靠性。")


func test_network_dirty_state_tracker_filters_priority_and_approximate_values() -> void:
	var tracker: GFNetworkDirtyStateTracker = GFNetworkDirtyStateTracker.new()
	tracker.epsilon = 0.01
	tracker.set_baseline({
		"position": Vector2.ZERO,
		"hp": 10,
		"spawn": "initial",
		"local_note": "old",
	})
	tracker.set_field_priority(&"position", GFNetworkDirtyStateTracker.Priority.REALTIME)
	tracker.set_field_priority(&"hp", GFNetworkDirtyStateTracker.Priority.HIGH)
	tracker.set_field_priority(&"spawn", GFNetworkDirtyStateTracker.Priority.SPAWN_ONLY)
	tracker.set_field_priority(&"local_note", GFNetworkDirtyStateTracker.Priority.LOCAL_ONLY)

	var state: Dictionary = {
		"position": Vector2(0.005, 0.0),
		"hp": 8,
		"spawn": "changed",
		"local_note": "changed",
	}
	var default_report: Dictionary = tracker.get_dirty_report(state)
	var high_only_report: Dictionary = tracker.get_dirty_report(state, {
		"priorities": [GFNetworkDirtyStateTracker.Priority.HIGH],
	})
	var spawn_report: Dictionary = tracker.get_dirty_report(state, {
		"include_spawn_only": true,
	})

	assert_false(tracker.is_field_dirty(state, &"position"), "小于 epsilon 的向量变化不应标记 dirty。")
	assert_eq(GFVariantData.get_option_packed_string_array(default_report, "dirty_fields"), PackedStringArray(["hp"]), "默认报告应排除 spawn/local 并只包含真实变化字段。")
	assert_eq(GFVariantData.get_option_packed_string_array(high_only_report, "dirty_fields"), PackedStringArray(["hp"]), "优先级过滤应只保留指定级别字段。")
	assert_true(GFVariantData.get_option_packed_string_array(spawn_report, "dirty_fields").has("spawn"), "显式 include_spawn_only 时应包含出生字段。")

	var updated_count: int = tracker.update_baseline(state, PackedStringArray(["hp"]))
	assert_eq(updated_count, 1, "更新指定字段基线应返回更新数量。")
	assert_false(tracker.is_field_dirty(state, &"hp"), "更新基线后字段不应继续 dirty。")


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


func test_network_utility_rejects_conflicting_channel_id_bypass() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	var strict_channel: GFNetworkChannel = GFNetworkChannel.new()
	strict_channel.channel_id = &"state"
	strict_channel.max_packet_size = 8
	var loose_channel: GFNetworkChannel = GFNetworkChannel.new()
	loose_channel.channel_id = &"bulk"
	loose_channel.max_packet_size = 0
	utility.register_channel(strict_channel)
	utility.register_channel(loose_channel)
	watch_signals(utility)

	var bytes: PackedByteArray = utility.serializer.serialize_message(GFNetworkMessage.new(&"state", { "payload": "too large" }, 0, 0, -1, &"bulk"))
	backend.message_received.emit(1, bytes)

	assert_signal_emitted(utility, "message_rejected", "message_type 匹配的严格通道不能被 conflicting channel_id 绕过。")
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


func test_websocket_backend_rejects_non_websocket_endpoint_before_connect() -> void:
	var backend: GFWebSocketNetworkBackend = GFWebSocketNetworkBackend.new()

	assert_eq(backend.connect_to_endpoint("http://example.test/socket"), ERR_INVALID_PARAMETER)
	assert_eq(backend.connect_to_endpoint("ws:///missing-host"), ERR_INVALID_PARAMETER)
	assert_eq(backend.connect_to_endpoint("ws://example.test/socket\nforged"), ERR_INVALID_PARAMETER)


func test_enet_close_emits_disconnect_for_each_tracked_peer() -> void:
	var backend: GFENetNetworkBackend = GFENetNetworkBackend.new()
	var disconnected_peer_ids: Array[int] = []
	var _connected: Error = backend.peer_disconnected.connect(func(peer_id: int) -> void:
		disconnected_peer_ids.append(peer_id)
	) as Error
	backend._peer = ENetMultiplayerPeer.new()
	backend._on_peer_connected(4)
	backend._on_peer_connected(2)

	backend._close_peer(true)
	disconnected_peer_ids.sort()

	assert_eq(disconnected_peer_ids, [2, 4], "关闭 ENet 后端应逐个清理已跟踪 peer。")


func test_multiplayer_peer_backend_enforces_explicit_peer_ownership() -> void:
	var borrowed_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var borrowed_port: int = 0
	var borrowed_error: Error = ERR_UNAVAILABLE
	for offset: int in range(20):
		borrowed_port = 19400 + offset
		borrowed_error = borrowed_peer.create_server(borrowed_port, 2)
		if borrowed_error == OK:
			break
	assert_eq(borrowed_error, OK, "测试应能创建 borrowed ENet Peer。")
	if borrowed_error != OK:
		return

	var backend: GFMultiplayerPeerNetworkBackend = GFMultiplayerPeerNetworkBackend.new()
	var adopt_error: Error = backend.adopt_peer(borrowed_peer, {
		"ownership": GFMultiplayerPeerNetworkBackend.Ownership.BORROWED,
		"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		"endpoint": "enet://user:secret@127.0.0.1:%d?token=hidden" % borrowed_port,
	})
	var debug_text: String = JSON.stringify(backend.get_debug_snapshot())

	assert_eq(adopt_error, OK, "已初始化 Peer 应可被接管。")
	assert_eq(
		backend.adopt_peer(borrowed_peer, {
			"ownership": GFMultiplayerPeerNetworkBackend.Ownership.BORROWED,
			"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		}),
		ERR_ALREADY_IN_USE,
		"同一 Peer 不得被重复接管并触发意外关闭。"
	)
	assert_eq(backend.get_peer(), borrowed_peer, "get_peer 应返回借用引用。")
	assert_false(backend.owns_peer(), "BORROWED Peer 不应转移关闭责任。")
	assert_false(debug_text.contains("secret"), "调试快照应移除 endpoint userinfo。")
	assert_false(debug_text.contains("hidden"), "调试快照应移除 endpoint query。")

	backend.disconnect_backend()
	assert_eq(
		borrowed_peer.get_connection_status(),
		MultiplayerPeer.CONNECTION_CONNECTED,
		"释放 BORROWED Peer 不得关闭外部连接。"
	)
	borrowed_peer.close()

	var owned_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var owned_error: Error = ERR_UNAVAILABLE
	for offset: int in range(20):
		owned_error = owned_peer.create_server(19420 + offset, 2)
		if owned_error == OK:
			break
	assert_eq(owned_error, OK, "测试应能创建 owned ENet Peer。")
	if owned_error != OK:
		return
	var owned_adopt_error: Error = backend.adopt_peer(owned_peer, {
		"ownership": GFMultiplayerPeerNetworkBackend.Ownership.OWNED,
		"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
	})
	assert_eq(owned_adopt_error, OK, "OWNED Peer 应可被接管。")
	assert_true(backend.owns_peer(), "OWNED Peer 应由 Backend 负责关闭。")
	backend.disconnect_backend()
	assert_eq(
		owned_peer.get_connection_status(),
		MultiplayerPeer.CONNECTION_DISCONNECTED,
		"释放 OWNED Peer 必须关闭底层连接。"
	)


func test_multiplayer_peer_backend_take_transfers_owned_lifecycle() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var host_error: Error = ERR_UNAVAILABLE
	for offset: int in range(20):
		host_error = peer.create_server(19460 + offset, 2)
		if host_error == OK:
			break
	assert_eq(host_error, OK, "测试应能创建 Owned Peer。")
	if host_error != OK:
		return
	var backend: GFMultiplayerPeerNetworkBackend = GFMultiplayerPeerNetworkBackend.new()
	assert_eq(
		backend.adopt_peer(peer, {
			"ownership": GFMultiplayerPeerNetworkBackend.Ownership.OWNED,
			"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		}),
		OK
	)

	var transferred: MultiplayerPeer = backend.take_peer()
	backend.disconnect_backend()

	assert_eq(transferred, peer, "take_peer 应返回原 Peer。")
	assert_null(backend.get_peer(), "转移后 Backend 不得继续持有 Peer。")
	assert_eq(
		peer.get_connection_status(),
		MultiplayerPeer.CONNECTION_CONNECTED,
		"所有权转移后 Backend 不得关闭 Peer。"
	)
	peer.close()


func test_network_utility_bootstraps_already_connected_multiplayer_peer() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var host_error: Error = ERR_UNAVAILABLE
	var port: int = 0
	for offset: int in range(20):
		port = 19480 + offset
		host_error = peer.create_server(port, 2)
		if host_error == OK:
			break
	assert_eq(host_error, OK, "测试应能创建已连接 Peer。")
	if host_error != OK:
		return
	var backend: GFMultiplayerPeerNetworkBackend = GFMultiplayerPeerNetworkBackend.new()
	assert_eq(backend.adopt_peer(peer, {
		"ownership": GFMultiplayerPeerNetworkBackend.Ownership.BORROWED,
		"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		"endpoint": "enet://127.0.0.1:%d" % port,
	}), OK)
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	watch_signals(utility)

	utility.backend = backend

	assert_true(utility.session.is_active, "接管时应创建 Session。")
	assert_true(utility.session.has_connection, "已连接 Backend 应立即同步连接终态。")
	assert_eq(utility.session.mode, GFNetworkSession.Mode.HOST)
	assert_eq(utility.session.endpoint, "enet://127.0.0.1:%d" % port)
	assert_eq(utility.session.local_peer_id, peer.get_unique_id())
	assert_signal_emit_count(utility, "connected", 1, "采用已连接 Backend 应转发一次连接事件。")
	utility.dispose()
	assert_eq(
		peer.get_connection_status(),
		MultiplayerPeer.CONNECTION_CONNECTED,
		"Utility 释放 Borrowed Peer 时不得关闭外部连接。"
	)
	peer.close()


func test_multiplayer_peer_backend_rejects_unsupported_send_features() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var host_error: Error = ERR_UNAVAILABLE
	for offset: int in range(20):
		host_error = peer.create_server(19440 + offset, 2)
		if host_error == OK:
			break
	assert_eq(host_error, OK, "测试应能创建 ENet Peer。")
	if host_error != OK:
		return
	var backend: GFMultiplayerPeerNetworkBackend = GFMultiplayerPeerNetworkBackend.new()
	assert_eq(
		backend.adopt_peer(peer),
		ERR_INVALID_PARAMETER,
		"接管必须显式声明 ownership 和 role。"
	)
	assert_eq(
		backend.adopt_peer(peer, {
			"ownership": 999,
			"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		}),
		ERR_INVALID_PARAMETER,
		"未知 ownership 不得静默降级为 BORROWED。"
	)
	assert_eq(
		backend.adopt_peer(peer, {
			"ownership": "0",
			"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		}),
		ERR_INVALID_PARAMETER,
		"ownership 必须使用明确的枚举整数类型。"
	)
	assert_eq(
		backend.adopt_peer(peer, {
			"ownership": GFMultiplayerPeerNetworkBackend.Ownership.BORROWED,
			"role": "1",
		}),
		ERR_INVALID_PARAMETER,
		"role 必须使用明确的枚举整数类型。"
	)
	var adopt_error: Error = backend.adopt_peer(peer, {
		"ownership": GFMultiplayerPeerNetworkBackend.Ownership.OWNED,
		"role": GFMultiplayerPeerNetworkBackend.Role.SERVER,
		"supports_channels": false,
		"supports_transfer_modes": false,
	})

	assert_eq(adopt_error, OK, "Peer 应可按能力声明接管。")
	assert_eq(
		backend.send_bytes(-1, PackedByteArray([1]), {"channel": 1}),
		ERR_UNAVAILABLE,
		"不支持 channel 的 Peer 必须明确拒绝非默认 channel。"
	)
	assert_eq(
		backend.send_bytes(-1, PackedByteArray([1]), {"reliable": true}),
		ERR_UNAVAILABLE,
		"不支持 transfer mode 的 Peer 必须明确拒绝可靠性覆盖。"
	)
	backend.disconnect_backend()


func test_network_transport_metrics_distinguish_unknown_values_and_bound_history() -> void:
	var metrics: GFNetworkTransportMetrics = GFNetworkTransportMetrics.new()
	var _rtt_set: bool = metrics.set_metric(
		GFNetworkTransportMetrics.ROUND_TRIP_TIME_MSEC,
		24.5
	)
	assert_true(metrics.has_metric(GFNetworkTransportMetrics.ROUND_TRIP_TIME_MSEC))
	assert_eq(metrics.get_metric(GFNetworkTransportMetrics.ROUND_TRIP_TIME_MSEC), 24.5)
	assert_false(
		metrics.set_metric(GFNetworkTransportMetrics.PACKET_LOSS_RATIO, 1.5),
		"非法丢包率不得进入指标快照。"
	)
	assert_false(metrics.set_metric(&"bad", NAN), "NaN 不得进入指标快照。")
	assert_true(metrics.set_metric(&" custom_metric ", 7.0), "自定义指标 ID 应规范化后写入。")
	assert_true(metrics.has_metric(&" custom_metric "), "查询应使用与写入一致的 ID 规范化。")
	assert_eq(metrics.get_metric(&" custom_metric "), 7.0)
	assert_true(metrics.clear_metric(&" custom_metric "), "移除应使用与写入一致的 ID 规范化。")
	assert_false(metrics.has_metric(&"custom_metric"), "移除后规范化指标不应继续存在。")

	var backend: FakeBackend = FakeBackend.new()
	backend.mark_connected_at_zero_for_test()
	var _send_error: Error = backend.send_bytes(1, PackedByteArray([1, 2, 3]))
	backend.emit_packet_for_test(1, PackedByteArray([4, 5]))
	var backend_metrics: GFNetworkTransportMetrics = backend.get_transport_metrics()
	assert_eq(backend_metrics.get_metric(GFNetworkTransportMetrics.BYTES_SENT), 3.0)
	assert_eq(backend_metrics.get_metric(GFNetworkTransportMetrics.BYTES_RECEIVED), 2.0)
	assert_false(
		backend_metrics.has_metric(GFNetworkTransportMetrics.ROUND_TRIP_TIME_MSEC),
		"不支持 RTT 的 Backend 不得伪造零值。"
	)
	assert_true(
		backend_metrics.has_metric(GFNetworkTransportMetrics.CONNECTION_AGE_MSEC),
		"零毫秒连接起点仍应产生连接时长指标。"
	)

	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.max_transport_metric_samples = 2
	utility.set_backend(backend)
	var _first_sample: GFNetworkTransportMetrics = utility.capture_transport_metrics()
	var _second_sample: GFNetworkTransportMetrics = utility.capture_transport_metrics()
	var _third_sample: GFNetworkTransportMetrics = utility.capture_transport_metrics()
	var samples: Array[GFNetworkTransportMetrics] = utility.get_transport_metric_samples()
	assert_eq(samples.size(), 2, "指标历史必须遵守固定容量。")
	utility.max_transport_metric_samples = 1
	assert_eq(
		utility.get_transport_metric_samples().size(),
		1,
		"降低容量应立即裁剪既有历史。"
	)
	var _mutated: bool = samples[0].set_metric(&"external_mutation", 1.0)
	assert_false(
		utility.get_transport_metric_samples()[0].has_metric(&"external_mutation"),
		"返回的指标历史必须与内部快照隔离。"
	)
	utility.max_transport_metric_samples = 0
	assert_true(
		utility.get_transport_metric_samples().is_empty(),
		"容量归零应立即释放指标历史。"
	)


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


func test_network_message_validator_accepts_string_name_required_payload_keys() -> void:
	var validator: GFNetworkMessageValidator = GFNetworkMessageValidator.new()
	validator.required_payload_keys = PackedStringArray(["entity_id"])

	var report: Dictionary = validator.validate_message(GFNetworkMessage.new(&"spawn", { &"entity_id": 7 }))

	assert_true(GFVariantData.get_option_bool(report, "ok"), "required_payload_keys 应接受 StringName payload key。")


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


func test_network_utility_times_out_silent_client_connect() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var backend: FakeBackend = FakeBackend.new()
	utility.set_backend(backend)
	utility.connect_timeout_msec = 1
	watch_signals(utility)

	var error: Error = utility.connect_to_endpoint("127.0.0.1:9000")
	utility.tick(0.002)

	assert_eq(error, OK, "后端接受异步连接请求时应先返回 OK。")
	assert_false(utility.session.is_active, "静默连接超过超时时间后应关闭 session。")
	assert_true(backend.disconnected_by_utility, "连接超时应关闭后端资源。")
	assert_signal_emitted(utility, "disconnected", "连接超时应发出断开信号。")


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

	utility.backend = second_backend

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


func test_network_debug_snapshot_redacts_endpoint_and_secret_metadata() -> void:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	utility.set_backend(FakeBackend.new())
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.channel_id = &"state"
	channel.metadata = {
		"auth_token": "abc",
		"region": "asia",
	}
	utility.register_channel(channel)

	var _connect_result_661: Variant = utility.connect_to_endpoint("wss://user:pass@example.test/game?token=abc", {
		"metadata": {
			"auth_token": "abc",
			"region": "asia",
		},
	})
	var snapshot_text: String = JSON.stringify(utility.get_debug_snapshot())

	assert_false(snapshot_text.contains("abc"), "诊断快照不应包含 token 原文。")
	assert_false(snapshot_text.contains("user:pass"), "诊断快照不应包含 URL userinfo。")
	assert_false(snapshot_text.contains("token=abc"), "诊断快照不应包含 URL query token。")
	assert_true(snapshot_text.contains("asia"), "非敏感 metadata 应保留调试价值。")


func test_network_direct_debug_entries_redact_sensitive_values() -> void:
	var session: GFNetworkSession = GFNetworkSession.new()
	session.start_client("wss://user:pass@example.test/game?token=abc", {
		"metadata": {
			"auth_token": "abc",
			"region": "asia",
		},
	})
	var channel: GFNetworkChannel = GFNetworkChannel.new()
	channel.metadata = {
		"secret": "abc",
		"region": "asia",
	}
	var websocket: GFWebSocketNetworkBackend = GFWebSocketNetworkBackend.new()
	websocket._mode = GFWebSocketNetworkBackend.Mode.CLIENT
	websocket._endpoint = "wss://user:pass@example.test/game?token=abc"

	var snapshot_text: String = JSON.stringify({
		"session": session.get_debug_snapshot(),
		"channel": channel.describe(),
		"backend": websocket.get_debug_snapshot(),
	})

	assert_false(snapshot_text.contains("abc"), "直接调试入口不应泄露敏感值。")
	assert_false(snapshot_text.contains("user:pass"), "直接调试入口不应泄露 URL userinfo。")
	assert_false(snapshot_text.contains("token=abc"), "直接调试入口不应泄露 URL query token。")
	assert_true(snapshot_text.contains("asia"), "非敏感 metadata 应保留。")


func test_network_debug_redaction_normalizes_common_key_styles() -> void:
	var sanitized: Dictionary = GFNetworkDebugTools.sanitize_debug_dictionary({
		"apiKey": "api-secret",
		"access-key": "access-secret",
		"sessionId": "session-secret",
		"clientSecretValue": "client-secret",
		"private-key-pem": "private-secret",
		"displayKeyframe": "visible",
		"secretaryName": "ordinary-secretary",
		"monkeyIsland": "ordinary-monkey",
	})
	var snapshot_text: String = JSON.stringify(sanitized)

	assert_false(snapshot_text.contains("api-secret"), "camelCase apiKey 应被脱敏。")
	assert_false(snapshot_text.contains("access-secret"), "kebab-case access-key 应被脱敏。")
	assert_false(snapshot_text.contains("session-secret"), "squashed sessionId 应被脱敏。")
	assert_false(snapshot_text.contains("client-secret"), "camelCase 中间敏感 token 应被脱敏。")
	assert_false(snapshot_text.contains("private-secret"), "规范化 private-key 复合字段应被脱敏。")
	assert_true(snapshot_text.contains("visible"), "普通包含 key 字样的字段不应被过度脱敏。")
	assert_true(snapshot_text.contains("ordinary-secretary"), "secretary 等普通词不得因子串 secret 被误杀。")
	assert_true(snapshot_text.contains("ordinary-monkey"), "普通词内部的 key 字符串不得被误杀。")


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


func test_fixed_tick_clock_rejects_non_finite_configuration_and_state() -> void:
	var clock: GFFixedTickClock = GFFixedTickClock.new(NAN)
	var initial_tick_rate: float = clock.tick_rate
	clock.accumulator_seconds = INF
	var steps: int = clock.advance(NAN)
	clock.configure(INF)
	clock.from_dict({
		"tick_rate": NAN,
		"current_tick": 7,
		"accumulator_seconds": INF,
	})

	assert_false(is_nan(initial_tick_rate) or is_inf(initial_tick_rate), "构造后的 tick_rate 必须有限。")
	assert_eq(steps, 0, "非有限 delta 不应推进 tick。")
	assert_false(is_nan(clock.tick_rate) or is_inf(clock.tick_rate), "配置和恢复不得污染 tick_rate。")
	assert_false(is_nan(clock.accumulator_seconds) or is_inf(clock.accumulator_seconds), "恢复后的 accumulator 必须有限。")
	assert_eq(clock.current_tick, 7, "合法整数状态仍应恢复。")


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


func test_network_snapshot_rejects_malformed_or_over_budget_patch_atomically() -> void:
	var start: GFNetworkSnapshot = GFNetworkSnapshot.new(10, { "hp": 10 }, 2)
	var wrong_format: Dictionary = {
		"ok": true,
		"format": &"wrong",
		"version": 1,
		"from_tick": 10,
		"to_tick": 11,
		"set": [{ "path": ["hp"], "value": 1 }],
		"erase": [],
		"metadata": {},
	}
	var deep_path: Array = []
	for index: int in range(10):
		deep_path.append("level_%d" % index)
	var over_budget: Dictionary = {
		"ok": true,
		"format": &"gf_network_snapshot_patch",
		"version": 1,
		"from_tick": 10,
		"to_tick": 11,
		"set": [{ "path": deep_path, "value": 1 }],
		"erase": [],
		"metadata": {},
	}

	var wrong_result: GFNetworkSnapshot = start.apply_patch(wrong_format)
	var deep_result: GFNetworkSnapshot = start.apply_patch(over_budget)

	assert_eq(wrong_result.to_dict(), start.to_dict(), "错误 format 的 patch 必须原子拒绝。")
	assert_eq(deep_result.to_dict(), start.to_dict(), "超深 path 的 patch 必须原子拒绝。")


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


func _find_report_issue(report: Dictionary, kind: String) -> Dictionary:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return issue
	return {}


func _make_lobby_network_contract() -> GFNetworkContract:
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
	return contract


func _snapshot_from_dictionary(source: Dictionary, key: Variant) -> GFNetworkSnapshot:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is GFNetworkSnapshot:
		return value
	return null
