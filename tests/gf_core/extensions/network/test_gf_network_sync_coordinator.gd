## 测试网络同步协调器的身份、顺序、预算和事务式预测纠偏。
extends GutTest


# --- 辅助类 ---

class FakeSimulationAdapter extends GFNetworkSimulationAdapter:
	var state: Dictionary = {"value": 0}
	var input_scale: int = 1
	var reject_remote_inputs: bool = false
	var reject_all_inputs: bool = false
	var fail_capture: bool = false
	var fail_restore: bool = false
	var fail_simulate_tick: int = -1
	var fail_simulate_operation: StringName = &""
	var coordinator_to_reenter: GFNetworkSyncCoordinator = null
	var reentry_report: Dictionary = {}
	var simulated_ticks: Array[int] = []
	var restore_ticks: Array[int] = []

	func _capture_state(_tick: int, _context: Dictionary) -> Dictionary:
		if fail_capture:
			return {"ok": false, "error": "capture_failed"}
		return {
			"ok": true,
			"state": state.duplicate(true),
		}

	func _validate_state(
		candidate_state: Dictionary,
		_tick: int,
		_context: Dictionary
	) -> Dictionary:
		var value: Variant = GFVariantData.get_option_value(candidate_state, "value")
		return {
			"ok": typeof(value) == TYPE_INT,
			"error": "" if typeof(value) == TYPE_INT else "value_not_integer",
		}

	func _restore_state(
		next_state: Dictionary,
		tick: int,
		_context: Dictionary
	) -> Dictionary:
		if fail_restore:
			return {"ok": false, "error": "restore_failed"}
		state = next_state.duplicate(true)
		restore_ticks.append(tick)
		return {"ok": true}

	func _validate_input(
		frame: GFNetworkInputFrame,
		actual_peer_id: int,
		_context: Dictionary
	) -> Dictionary:
		if reject_all_inputs:
			return {"ok": false, "error": "input_rejected"}
		if reject_remote_inputs and actual_peer_id != 2:
			return {"ok": false, "error": "peer_rejected"}
		var delta_value: Variant = GFVariantData.get_option_value(frame.payload, "delta")
		return {
			"ok": frame.peer_id == actual_peer_id and typeof(delta_value) == TYPE_INT,
			"error": "invalid_input",
		}

	func _simulate_tick(
		tick: int,
		inputs: Array[GFNetworkInputFrame],
		context: Dictionary
	) -> Dictionary:
		if coordinator_to_reenter != null:
			reentry_report = coordinator_to_reenter.reset_stream("reentered")
			coordinator_to_reenter = null
		var operation: StringName = GFVariantData.get_option_string_name(context, "operation")
		if (
			tick == fail_simulate_tick
			and (fail_simulate_operation == &"" or operation == fail_simulate_operation)
		):
			return {"ok": false, "error": "simulate_failed"}
		var next_value: int = GFVariantData.get_option_int(state, "value") + 1
		for frame: GFNetworkInputFrame in inputs:
			next_value += GFVariantData.get_option_int(frame.payload, "delta") * input_scale
		state["value"] = next_value
		simulated_ticks.append(tick)
		return {"ok": true}

	func _states_equal(
		predicted_state: Dictionary,
		authoritative_state: Dictionary,
		_tick: int,
		_context: Dictionary
	) -> bool:
		return predicted_state == authoritative_state


class SignalReentryProbe extends RefCounted:
	var coordinator: GFNetworkSyncCoordinator = null
	var report: Dictionary = {}
	var snapshot_message: GFNetworkMessage = null

	func on_authority_snapshot(snapshot: GFNetworkSnapshot) -> void:
		snapshot_message = coordinator.make_snapshot_message(snapshot, 2)
		report = coordinator.reset_stream("signal-reentry")


class InputFinalizationProbe extends RefCounted:
	var records: Array[Dictionary] = []

	func on_input_finalized(
		peer_id: int,
		sequence: int,
		accepted: bool,
		reason: StringName
	) -> void:
		records.append({
			"peer_id": peer_id,
			"sequence": sequence,
			"accepted": accepted,
			"reason": reason,
		})


# --- 测试 ---

func test_input_frame_copies_payload_and_rejects_unsafe_values() -> void:
	var payload: Dictionary = {"delta": 2}
	var frame: GFNetworkInputFrame = GFNetworkInputFrame.new(3, 2, 1, payload)
	payload["delta"] = 99

	assert_eq(GFVariantData.get_option_int(frame.payload, "delta"), 2)
	assert_true(GFVariantData.get_option_bool(frame.validate_frame(), "ok"))
	var copied: GFNetworkInputFrame = frame.duplicate_frame()
	copied.payload["delta"] = 8
	assert_eq(GFVariantData.get_option_int(frame.payload, "delta"), 2)

	frame.payload["unsafe"] = Callable()
	var unsafe_report: Dictionary = frame.validate_frame()
	assert_false(GFVariantData.get_option_bool(unsafe_report, "ok"))
	assert_eq(GFVariantData.get_option_string(unsafe_report, "error"), "callable_not_transport_safe")


func test_configure_requires_explicit_epoch_identity_and_bounded_capacity() -> void:
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()

	var missing_epoch: Dictionary = coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{}
	)
	assert_false(GFVariantData.get_option_bool(missing_epoch, "ok"))
	assert_eq(GFVariantData.get_option_string_name(missing_epoch, "reason"), &"invalid_stream_identity")

	var unbounded: Dictionary = coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{"epoch_id": "match-1", "history_capacity": 0}
	)
	assert_false(GFVariantData.get_option_bool(unbounded, "ok"))
	assert_eq(GFVariantData.get_option_string_name(unbounded, "reason"), &"invalid_resource_budget")

	var configured: Dictionary = coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{"epoch_id": "match-1", "history_capacity": 2}
	)
	assert_true(GFVariantData.get_option_bool(configured, "ok"))
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.ACTIVE)
	assert_false(coordinator.register_replica_peer(1), "权威自身不能注册为 replica。")
	assert_true(coordinator.register_replica_peer(2))
	assert_true(GFVariantData.get_option_bool(coordinator.reset_stream("match-2"), "ok"))
	assert_false(
		GFVariantData.get_option_bool(coordinator.reset_stream("match-1"), "ok"),
		"同一 coordinator 不能复用旧 epoch。"
	)
	assert_eq(coordinator.get_epoch_id(), "match-2")


func test_replica_local_input_builds_bound_message_without_reference_leak() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	var baseline: GFNetworkMessage = _snapshot_message(1, 1, 1, 0, {"value": 1})
	assert_true(GFVariantData.get_option_bool(coordinator.handle_message(1, baseline), "ok"))

	var payload: Dictionary = {"delta": 3}
	var report: Dictionary = coordinator.submit_local_input(payload, 2)
	payload["delta"] = 99
	var frame: GFNetworkInputFrame = _frame_from_report(report)
	var message: GFNetworkMessage = _message_from_report(report)

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(frame.peer_id, 2)
	assert_eq(frame.sequence, 1)
	assert_eq(message.message_type, GFNetworkSyncCoordinator.INPUT_MESSAGE_TYPE)
	assert_eq(message.channel_id, GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID)
	assert_eq(message.sender_id, 2)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(message.payload, "input"),
			"delta"
		),
		3
	)

	frame.payload["delta"] = 55
	assert_null(
		coordinator.make_input_message(frame),
		"调用方不能用已签发 sequence 构造不同输入载荷。"
	)
	var report_message: GFNetworkMessage = _message_from_report(report)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(report_message.payload, "input"),
			"delta"
		),
		3
	)


func test_replica_does_not_sign_input_past_safe_tick_limit() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	var max_safe_tick: int = 9_007_199_254_740_991
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(
			1,
			_snapshot_message(1, 1, max_safe_tick, 0, {"value": 1})
		),
		"ok"
	))
	var report: Dictionary = coordinator.submit_local_input({"delta": 1})

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"input_tick_out_of_window")


func test_authority_requires_registered_actual_peer_and_orders_inputs() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	assert_true(coordinator.register_replica_peer(3))
	assert_true(coordinator.register_replica_peer(2))
	var from_three: GFNetworkMessage = _input_message(3, 1, 1, {"delta": 30})
	var from_two: GFNetworkMessage = _input_message(2, 1, 1, {"delta": 2})

	assert_false(
		GFVariantData.get_option_bool(coordinator.handle_message(4, from_two), "ok"),
		"未注册实际 peer 必须被拒绝。"
	)
	assert_true(GFVariantData.get_option_bool(coordinator.handle_message(3, from_three), "ok"))
	assert_true(GFVariantData.get_option_bool(coordinator.handle_message(2, from_two), "ok"))
	var advance: Dictionary = coordinator.advance_authority_tick()
	var snapshot: GFNetworkSnapshot = _snapshot_from_report(advance)

	assert_true(GFVariantData.get_option_bool(advance, "ok"))
	assert_eq(GFVariantData.get_option_int(snapshot.state, "value"), 33)
	assert_eq(coordinator.get_current_tick(), 1)
	var message_two: GFNetworkMessage = coordinator.make_snapshot_message(snapshot, 2)
	var message_three: GFNetworkMessage = coordinator.make_snapshot_message(snapshot, 3)
	assert_eq(GFVariantData.get_option_int(message_two.payload, "ack_input_sequence"), 1)
	assert_eq(GFVariantData.get_option_int(message_three.payload, "ack_input_sequence"), 1)


func test_authority_only_serializes_latest_unmodified_snapshot_for_recipient() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var first: GFNetworkSnapshot = _snapshot_from_report(coordinator.advance_authority_tick())
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(2, _input_message(2, 1, 2, {"delta": 2})),
		"ok"
	))
	var latest: GFNetworkSnapshot = _snapshot_from_report(coordinator.advance_authority_tick())

	assert_null(
		coordinator.make_snapshot_message(first, 2),
		"旧状态不能携带当前 ack 再次签发。"
	)
	latest.state["value"] = 999
	assert_null(
		coordinator.make_snapshot_message(latest, 2),
		"调用方修改过的状态不能复用已签发 sequence。"
	)
	var stored_latest: GFNetworkSnapshot = coordinator.get_authoritative_history().get_latest_snapshot()
	var message: GFNetworkMessage = coordinator.make_snapshot_message(stored_latest, 2)
	assert_not_null(message)
	assert_eq(GFVariantData.get_option_int(message.payload, "recipient_peer_id"), 2)
	assert_eq(GFVariantData.get_option_int(message.payload, "ack_input_sequence"), 1)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(message.payload, "state"),
			"value"
		),
		4
	)


func test_input_sequence_duplicate_is_idempotent_and_gap_is_rejected() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var first: GFNetworkMessage = _input_message(2, 1, 1, {"delta": 2})

	var accepted: Dictionary = coordinator.handle_message(2, first)
	var duplicate_report: Dictionary = coordinator.handle_message(2, first)
	var gap: Dictionary = coordinator.handle_message(
		2,
		_input_message(2, 3, 1, {"delta": 9})
	)
	var debug: Dictionary = coordinator.get_debug_snapshot()

	assert_true(GFVariantData.get_option_bool(accepted, "ok"))
	assert_true(GFVariantData.get_option_bool(duplicate_report, "ok"))
	assert_true(GFVariantData.get_option_bool(duplicate_report, "duplicate"))
	assert_false(GFVariantData.get_option_bool(gap, "ok"))
	assert_eq(GFVariantData.get_option_string_name(gap, "reason"), &"input_sequence_gap")
	assert_eq(GFVariantData.get_option_int(debug, "pending_input_count"), 1)


func test_projection_payload_is_transport_safe_and_fingerprintable() -> void:
	var replica_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var authority_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var replica: GFNetworkSyncCoordinator = _configured_replica(replica_adapter)
	var authority: GFNetworkSyncCoordinator = _configured_authority(authority_adapter)
	assert_true(GFVariantData.get_option_bool(
		replica.handle_message(1, _snapshot_message(1, 1, 1, 0, {"value": 1})),
		"ok"
	))
	var submitted: Dictionary = replica.submit_local_input({
		"delta": 1,
		"projection": Projection.create_perspective(1.2, 1.0, 0.1, 100.0),
	}, 2)

	assert_true(GFVariantData.get_option_bool(submitted, "ok"))
	assert_true(GFVariantData.get_option_bool(
		authority.handle_message(2, _message_from_report(submitted)),
		"ok"
	))


func test_large_transform_payload_shares_transport_and_fingerprint_budget() -> void:
	var replica_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var authority_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var replica: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	var authority: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	var options: Dictionary = {
		"epoch_id": "large-transform",
		"max_value_nodes": 8192,
		"max_payload_bytes": 1024 * 1024,
	}
	assert_true(GFVariantData.get_option_bool(replica.configure(
		GFNetworkSyncCoordinator.Role.REPLICA,
		2,
		1,
		replica_adapter,
		options
	), "ok"))
	assert_true(GFVariantData.get_option_bool(authority.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		authority_adapter,
		options
	), "ok"))
	assert_true(authority.register_replica_peer(2))
	assert_true(GFVariantData.get_option_bool(
		replica.handle_message(
			1,
			_snapshot_message(
				1,
				1,
				1,
				0,
				{"value": 1},
				"large-transform"
			)
		),
		"ok"
	))
	var transforms: Array[Transform3D] = []
	for _index: int in range(4200):
		transforms.append(Transform3D.IDENTITY)
	var submitted: Dictionary = replica.submit_local_input({
		"delta": 1,
		"transforms": transforms,
	}, 2)

	assert_true(
		GFVariantData.get_option_bool(submitted, "ok"),
		"Transport 节点预算允许的复合值必须也能生成协议指纹。"
	)
	assert_true(GFVariantData.get_option_bool(
		authority.handle_message(2, _message_from_report(submitted)),
		"ok"
	))


func test_epoch_sender_and_transport_safe_input_are_checked_before_adapter() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var wrong_sender: GFNetworkMessage = _input_message(8, 1, 1, {"delta": 1})
	var wrong_epoch: GFNetworkMessage = _input_message(2, 1, 1, {"delta": 1}, "old")
	var wrong_recipient: GFNetworkMessage = _input_message(
		2,
		1,
		1,
		{"delta": 1},
		"match-1",
		9
	)
	var unsafe: GFNetworkMessage = _input_message(2, 1, 1, {"delta": NAN})

	assert_eq(
		GFVariantData.get_option_string_name(
			coordinator.handle_message(2, wrong_sender),
			"reason"
		),
		&"sender_peer_mismatch"
	)
	assert_eq(
		GFVariantData.get_option_string_name(
			coordinator.handle_message(2, wrong_epoch),
			"reason"
		),
		&"epoch_mismatch"
	)
	assert_eq(
		GFVariantData.get_option_string_name(
			coordinator.handle_message(2, wrong_recipient),
			"reason"
		),
		&"unexpected_input_recipient"
	)
	assert_eq(
		GFVariantData.get_option_string_name(coordinator.handle_message(2, unsafe), "reason"),
		&"unsafe_message_payload"
	)
	assert_eq(GFVariantData.get_option_int(coordinator.get_debug_snapshot(), "pending_input_count"), 0)


func test_adapter_rejected_input_is_finalized_without_entering_simulation() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	adapter.reject_remote_inputs = true
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	assert_true(coordinator.register_replica_peer(3))
	var report: Dictionary = coordinator.handle_message(
		3,
		_input_message(3, 1, 1, {"delta": 5})
	)
	var advance: Dictionary = coordinator.advance_authority_tick()
	var snapshot: GFNetworkSnapshot = _snapshot_from_report(advance)
	var outbound: GFNetworkMessage = coordinator.make_snapshot_message(snapshot, 3)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "status"), &"finalized_rejected")
	assert_eq(GFVariantData.get_option_int(outbound.payload, "ack_input_sequence"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot.state, "value"), 1)


func test_authority_revalidates_dynamic_input_authorization_at_target_tick() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var probe: InputFinalizationProbe = InputFinalizationProbe.new()
	var _connected: int = coordinator.input_finalized.connect(probe.on_input_finalized)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(2, _input_message(2, 1, 1, {"delta": 7})),
		"ok"
	))
	adapter.reject_all_inputs = true

	var advance: Dictionary = coordinator.advance_authority_tick()
	var snapshot: GFNetworkSnapshot = _snapshot_from_report(advance)
	var outbound: GFNetworkMessage = coordinator.make_snapshot_message(snapshot, 2)

	assert_true(GFVariantData.get_option_bool(advance, "ok"))
	assert_eq(GFVariantData.get_option_int(advance, "input_count"), 0)
	assert_eq(GFVariantData.get_option_int(advance, "rejected_input_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot.state, "value"), 1)
	assert_eq(GFVariantData.get_option_int(outbound.payload, "ack_input_sequence"), 1)
	assert_eq(probe.records.size(), 1)
	assert_false(GFVariantData.get_option_bool(probe.records[0], "accepted"))
	assert_eq(
		GFVariantData.get_option_string_name(probe.records[0], "reason"),
		&"adapter_rejected_at_tick"
	)


func test_snapshot_ack_is_frozen_per_recipient_until_next_authority_tick() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	assert_true(coordinator.register_replica_peer(3))
	var first_snapshot: GFNetworkSnapshot = _snapshot_from_report(
		coordinator.advance_authority_tick()
	)
	var first_message: GFNetworkMessage = coordinator.make_snapshot_message(
		first_snapshot,
		3
	)
	assert_eq(GFVariantData.get_option_int(first_message.payload, "ack_input_sequence"), 0)

	adapter.reject_remote_inputs = true
	var rejected: Dictionary = coordinator.handle_message(
		3,
		_input_message(3, 1, 2, {"delta": 4})
	)
	assert_false(GFVariantData.get_option_bool(rejected, "ok"))
	var repeated_message: GFNetworkMessage = coordinator.make_snapshot_message(
		first_snapshot,
		3
	)
	assert_eq(
		repeated_message.to_dict(),
		first_message.to_dict(),
		"同一 snapshot sequence 与 recipient 必须重复生成完全相同的协议内容。"
	)

	var next_snapshot: GFNetworkSnapshot = _snapshot_from_report(
		coordinator.advance_authority_tick()
	)
	var next_message: GFNetworkMessage = coordinator.make_snapshot_message(
		next_snapshot,
		3
	)
	assert_eq(GFVariantData.get_option_int(next_message.payload, "ack_input_sequence"), 1)


func test_snapshot_ack_lifecycle_handles_late_peers_divergence_and_reset() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var first_snapshot: GFNetworkSnapshot = _snapshot_from_report(
		coordinator.advance_authority_tick()
	)
	assert_true(coordinator.register_replica_peer(3))
	assert_eq(
		GFVariantData.get_option_int(
			coordinator.make_snapshot_message(first_snapshot, 3).payload,
			"ack_input_sequence"
		),
		0,
		"快照创建后注册的 peer 仍应获得该 sequence 的冻结初始 ack。"
	)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(2, _input_message(2, 1, 3, {"delta": 2})),
		"ok"
	))
	adapter.reject_remote_inputs = true
	assert_false(GFVariantData.get_option_bool(
		coordinator.handle_message(3, _input_message(3, 1, 2, {"delta": 3})),
		"ok"
	))

	var second_snapshot: GFNetworkSnapshot = _snapshot_from_report(
		coordinator.advance_authority_tick()
	)
	var peer_two_message: GFNetworkMessage = coordinator.make_snapshot_message(
		second_snapshot,
		2
	)
	var peer_three_message: GFNetworkMessage = coordinator.make_snapshot_message(
		second_snapshot,
		3
	)
	assert_eq(GFVariantData.get_option_int(peer_two_message.payload, "ack_input_sequence"), 0)
	assert_eq(GFVariantData.get_option_int(peer_three_message.payload, "ack_input_sequence"), 1)

	assert_true(GFVariantData.get_option_bool(
		coordinator.reset_stream("match-2"),
		"ok"
	))
	assert_true(coordinator.register_replica_peer(2))
	assert_null(
		coordinator.make_snapshot_message(second_snapshot, 2),
		"重置后的新 epoch 不能签发旧流快照。"
	)


func test_rejected_input_finalization_gap_obeys_global_pending_budget() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	assert_true(GFVariantData.get_option_bool(coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{
			"epoch_id": "bounded-finalization",
			"max_pending_inputs": 2,
		}
	), "ok"))
	assert_true(coordinator.register_replica_peer(3))
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(
			3,
			_input_message(3, 1, 8, {"delta": 1}, "bounded-finalization")
		),
		"ok"
	))
	adapter.reject_remote_inputs = true
	assert_false(GFVariantData.get_option_bool(
		coordinator.handle_message(
			3,
			_input_message(3, 2, 8, {"delta": 2}, "bounded-finalization")
		),
		"ok"
	))
	var over_budget: Dictionary = coordinator.handle_message(
		3,
		_input_message(3, 3, 8, {"delta": 3}, "bounded-finalization")
	)
	var debug: Dictionary = coordinator.get_debug_snapshot()

	assert_eq(GFVariantData.get_option_string_name(over_budget, "reason"), &"pending_input_budget_exceeded")
	assert_eq(GFVariantData.get_option_int(debug, "pending_input_count"), 1)
	assert_eq(GFVariantData.get_option_int(debug, "pending_finalization_count"), 1)


func test_unregistered_peer_cannot_rejoin_or_replay_inside_same_epoch() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var old_message: GFNetworkMessage = _input_message(2, 1, 1, {"delta": 4})
	assert_true(GFVariantData.get_option_bool(coordinator.handle_message(2, old_message), "ok"))
	assert_true(coordinator.unregister_replica_peer(2))

	assert_false(coordinator.register_replica_peer(2))
	assert_false(GFVariantData.get_option_bool(coordinator.handle_message(2, old_message), "ok"))
	assert_eq(
		GFVariantData.get_option_int(
			coordinator.get_debug_snapshot(),
			"retired_replica_peer_count"
		),
		1
	)


func test_authority_simulation_failure_rolls_back_without_consuming_input() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(2, _input_message(2, 1, 1, {"delta": 4})),
		"ok"
	))
	adapter.fail_simulate_tick = 1
	var failed: Dictionary = coordinator.advance_authority_tick()

	assert_false(GFVariantData.get_option_bool(failed, "ok"))
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 0)
	assert_eq(coordinator.get_current_tick(), 0)
	assert_eq(GFVariantData.get_option_int(coordinator.get_debug_snapshot(), "pending_input_count"), 1)

	adapter.fail_simulate_tick = -1
	assert_true(GFVariantData.get_option_bool(coordinator.advance_authority_tick(), "ok"))
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 5)


func test_replica_applies_baseline_only_from_configured_authority() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	var forged: GFNetworkMessage = _snapshot_message(8, 1, 1, 0, {"value": 99})
	var valid: GFNetworkMessage = _snapshot_message(1, 1, 1, 0, {"value": 7})

	var forged_report: Dictionary = coordinator.handle_message(8, forged)
	var valid_report: Dictionary = coordinator.handle_message(1, valid)

	assert_false(GFVariantData.get_option_bool(forged_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(forged_report, "reason"),
		&"unexpected_authority_peer"
	)
	assert_true(GFVariantData.get_option_bool(valid_report, "ok"))
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.ACTIVE)
	assert_eq(coordinator.get_current_tick(), 1)
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 7)


func test_prediction_correction_replays_only_unacknowledged_future_inputs() -> void:
	var authority_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var replica_adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	replica_adapter.input_scale = 2
	var authority: GFNetworkSyncCoordinator = _configured_authority(authority_adapter)
	var replica: GFNetworkSyncCoordinator = _configured_replica(replica_adapter)

	var tick_one: Dictionary = authority.advance_authority_tick()
	var snapshot_one: GFNetworkSnapshot = _snapshot_from_report(tick_one)
	assert_true(GFVariantData.get_option_bool(
		replica.handle_message(1, authority.make_snapshot_message(snapshot_one, 2)),
		"ok"
	))

	var input_two: Dictionary = replica.submit_local_input({"delta": 2}, 2)
	var input_three: Dictionary = replica.submit_local_input({"delta": 3}, 3)
	assert_true(GFVariantData.get_option_bool(authority.handle_message(2, _message_from_report(input_two)), "ok"))
	assert_true(GFVariantData.get_option_bool(authority.handle_message(2, _message_from_report(input_three)), "ok"))
	assert_true(GFVariantData.get_option_bool(replica.advance_prediction_tick(), "ok"))
	assert_true(GFVariantData.get_option_bool(replica.advance_prediction_tick(), "ok"))
	assert_eq(GFVariantData.get_option_int(replica_adapter.state, "value"), 13)

	var tick_two: Dictionary = authority.advance_authority_tick()
	var snapshot_two: GFNetworkSnapshot = _snapshot_from_report(tick_two)
	var correction: Dictionary = replica.handle_message(
		1,
		authority.make_snapshot_message(snapshot_two, 2)
	)

	assert_true(GFVariantData.get_option_bool(correction, "ok"))
	assert_true(GFVariantData.get_option_bool(correction, "corrected"))
	assert_eq(GFVariantData.get_option_int(correction, "replayed_tick_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(replica_adapter.state, "value"),
		11,
		"权威 tick 2 后只应以 replica 策略重放未 ack 的 tick 3 输入。"
	)
	assert_eq(GFVariantData.get_option_int(replica.get_debug_snapshot(), "local_input_count"), 1)


func test_snapshot_duplicate_is_idempotent_but_same_sequence_conflict_requires_resync() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	var first: GFNetworkMessage = _snapshot_message(1, 1, 1, 0, {"value": 1})
	var conflict: GFNetworkMessage = _snapshot_message(1, 1, 1, 0, {"value": 2})

	assert_true(GFVariantData.get_option_bool(coordinator.handle_message(1, first), "ok"))
	var duplicate_report: Dictionary = coordinator.handle_message(1, first)
	var conflict_report: Dictionary = coordinator.handle_message(1, conflict)

	assert_true(GFVariantData.get_option_bool(duplicate_report, "duplicate"))
	assert_false(GFVariantData.get_option_bool(conflict_report, "ok"))
	assert_eq(
		coordinator.get_phase(),
		GFNetworkSyncCoordinator.Phase.RESYNC_REQUIRED
	)
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 1)


func test_stale_snapshot_is_ignored_before_its_obsolete_ack_is_validated() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(1, _snapshot_message(1, 1, 1, 0, {"value": 1})),
		"ok"
	))
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(1, _snapshot_message(1, 2, 2, 0, {"value": 2})),
		"ok"
	))
	var stale: Dictionary = coordinator.handle_message(
		1,
		_snapshot_message(1, 1, 1, 99, {"value": 1})
	)

	assert_false(GFVariantData.get_option_bool(stale, "ok"))
	assert_eq(GFVariantData.get_option_string_name(stale, "reason"), &"snapshot_sequence_stale")
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.ACTIVE)
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 2)


func test_snapshot_recipient_binding_rejects_cross_replica_delivery() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	var wrong_recipient: GFNetworkMessage = _snapshot_message(
		1,
		1,
		1,
		0,
		{"value": 7},
		"match-1",
		3
	)
	var report: Dictionary = coordinator.handle_message(1, wrong_recipient)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(report, "reason"),
		&"unexpected_snapshot_recipient"
	)
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.AWAITING_BASELINE)
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 0)


func test_non_predicting_replica_resyncs_when_ack_lags_past_local_input_tick() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	assert_true(GFVariantData.get_option_bool(coordinator.configure(
		GFNetworkSyncCoordinator.Role.REPLICA,
		2,
		1,
		adapter,
		{
			"epoch_id": "no-prediction",
			"prediction_enabled": false,
		}
	), "ok"))
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(
			1,
			_snapshot_message(1, 1, 1, 0, {"value": 1}, "no-prediction")
		),
		"ok"
	))
	assert_true(GFVariantData.get_option_bool(
		coordinator.submit_local_input({"delta": 2}, 2),
		"ok"
	))
	var report: Dictionary = coordinator.handle_message(
		1,
		_snapshot_message(1, 2, 2, 0, {"value": 2}, "no-prediction")
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"local_input_precedes_baseline")
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.RESYNC_REQUIRED)


func test_invalid_ack_requires_new_epoch_without_applying_state() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(1, _snapshot_message(1, 1, 1, 0, {"value": 1})),
		"ok"
	))
	var report: Dictionary = coordinator.handle_message(
		1,
		_snapshot_message(1, 2, 2, 9, {"value": 99})
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"invalid_input_ack")
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.RESYNC_REQUIRED)
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), 1)
	assert_true(GFVariantData.get_option_bool(coordinator.reset_stream("match-2"), "ok"))
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.AWAITING_BASELINE)


func test_replay_failure_restores_pre_apply_state_and_preserves_cursors() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_replica(adapter)
	assert_true(GFVariantData.get_option_bool(
		coordinator.handle_message(1, _snapshot_message(1, 1, 1, 0, {"value": 1})),
		"ok"
	))
	assert_true(GFVariantData.get_option_bool(coordinator.submit_local_input({"delta": 2}, 2), "ok"))
	assert_true(GFVariantData.get_option_bool(coordinator.submit_local_input({"delta": 3}, 3), "ok"))
	assert_true(GFVariantData.get_option_bool(coordinator.advance_prediction_tick(), "ok"))
	assert_true(GFVariantData.get_option_bool(coordinator.advance_prediction_tick(), "ok"))
	var predicted_value: int = GFVariantData.get_option_int(adapter.state, "value")
	adapter.fail_simulate_tick = 3
	adapter.fail_simulate_operation = &"replay_prediction"

	var failed: Dictionary = coordinator.handle_message(
		1,
		_snapshot_message(1, 2, 2, 1, {"value": 4})
	)

	assert_false(GFVariantData.get_option_bool(failed, "ok"))
	assert_eq(GFVariantData.get_option_string_name(failed, "reason"), &"prediction_replay_failed")
	assert_eq(GFVariantData.get_option_int(adapter.state, "value"), predicted_value)
	assert_eq(coordinator.get_current_tick(), 3)
	assert_eq(GFVariantData.get_option_int(coordinator.get_debug_snapshot(), "last_snapshot_sequence"), 1)


func test_faulted_instance_cannot_reset_unknown_adapter_state() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	adapter.fail_simulate_tick = 1
	adapter.fail_restore = true

	var failed: Dictionary = coordinator.advance_authority_tick()
	var reset: Dictionary = coordinator.reset_stream("match-2")

	assert_false(GFVariantData.get_option_bool(failed, "ok"))
	assert_eq(coordinator.get_phase(), GFNetworkSyncCoordinator.Phase.FAULTED)
	assert_false(GFVariantData.get_option_bool(reset, "ok"))
	assert_eq(GFVariantData.get_option_string_name(reset, "reason"), &"faulted_instance_terminal")
	assert_eq(coordinator.get_epoch_id(), "match-1")
	assert_false(
		coordinator.unregister_replica_peer(2),
		"FAULTED 终态不能继续修改 peer 或待输入状态。"
	)


func test_adapter_reentry_is_rejected_while_outer_tick_commits_consistently() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	adapter.coordinator_to_reenter = coordinator

	var report: Dictionary = coordinator.advance_authority_tick()

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_false(GFVariantData.get_option_bool(adapter.reentry_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(adapter.reentry_report, "reason"),
		&"operation_in_progress"
	)
	assert_eq(coordinator.get_epoch_id(), "match-1")
	assert_eq(coordinator.get_current_tick(), 1)


func test_synchronous_notifications_reject_mutating_reentry_until_return() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = _configured_authority(adapter)
	var probe: SignalReentryProbe = SignalReentryProbe.new()
	probe.coordinator = coordinator
	var _connected: int = coordinator.authority_snapshot_created.connect(
		probe.on_authority_snapshot
	)

	var report: Dictionary = coordinator.advance_authority_tick()

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_not_null(
		probe.snapshot_message,
		"只读消息签发应允许在已提交状态的同步通知内执行。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			probe.snapshot_message.payload,
			"recipient_peer_id"
		),
		2
	)
	assert_false(GFVariantData.get_option_bool(probe.report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(probe.report, "reason"),
		&"operation_in_progress"
	)
	assert_eq(coordinator.get_epoch_id(), "match-1")
	assert_false(
		GFVariantData.get_option_bool(
			coordinator.get_debug_snapshot(),
			"notification_active"
		)
	)


func test_history_and_debug_snapshots_are_bounded_and_payload_free() -> void:
	var adapter: FakeSimulationAdapter = FakeSimulationAdapter.new()
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	assert_true(GFVariantData.get_option_bool(coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{"epoch_id": "bounded", "history_capacity": 2}
	), "ok"))
	for _index: int in range(4):
		assert_true(GFVariantData.get_option_bool(coordinator.advance_authority_tick(), "ok"))
	var history: GFNetworkHistoryBuffer = coordinator.get_authoritative_history()
	var debug: Dictionary = coordinator.get_debug_snapshot()

	assert_eq(history.size(), 2)
	assert_eq(history.get_ticks(), PackedInt64Array([3, 4]))
	assert_false(debug.has("state"))
	assert_false(debug.has("input"))
	assert_eq(GFVariantData.get_option_int(debug, "authoritative_history_size"), 2)


# --- 私有/辅助方法 ---

func _configured_authority(
	adapter: FakeSimulationAdapter
) -> GFNetworkSyncCoordinator:
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	var report: Dictionary = coordinator.configure(
		GFNetworkSyncCoordinator.Role.AUTHORITY,
		1,
		1,
		adapter,
		{"epoch_id": "match-1"}
	)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(coordinator.register_replica_peer(2))
	return coordinator


func _configured_replica(
	adapter: FakeSimulationAdapter
) -> GFNetworkSyncCoordinator:
	var coordinator: GFNetworkSyncCoordinator = GFNetworkSyncCoordinator.new()
	var report: Dictionary = coordinator.configure(
		GFNetworkSyncCoordinator.Role.REPLICA,
		2,
		1,
		adapter,
		{"epoch_id": "match-1"}
	)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	return coordinator


func _input_message(
	peer_id: int,
	sequence: int,
	tick: int,
	input: Dictionary,
	epoch_id: String = "match-1",
	recipient_peer_id: int = 1
) -> GFNetworkMessage:
	return GFNetworkMessage.new(
		GFNetworkSyncCoordinator.INPUT_MESSAGE_TYPE,
		{
			"protocol_version": GFNetworkSyncCoordinator.PROTOCOL_VERSION,
			"epoch_id": epoch_id,
			"recipient_peer_id": recipient_peer_id,
			"input": input.duplicate(true),
		},
		sequence,
		tick,
		peer_id,
		GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID
	)


func _snapshot_message(
	peer_id: int,
	sequence: int,
	tick: int,
	ack_sequence: int,
	state: Dictionary,
	epoch_id: String = "match-1",
	recipient_peer_id: int = 2
) -> GFNetworkMessage:
	return GFNetworkMessage.new(
		GFNetworkSyncCoordinator.SNAPSHOT_MESSAGE_TYPE,
		{
			"protocol_version": GFNetworkSyncCoordinator.PROTOCOL_VERSION,
			"epoch_id": epoch_id,
			"recipient_peer_id": recipient_peer_id,
			"state": state.duplicate(true),
			"ack_input_sequence": ack_sequence,
		},
		sequence,
		tick,
		peer_id,
		GFNetworkSyncCoordinator.DEFAULT_CHANNEL_ID
	)


func _frame_from_report(report: Dictionary) -> GFNetworkInputFrame:
	var value: Variant = GFVariantData.get_option_value(report, "frame")
	if value is GFNetworkInputFrame:
		return value
	return null


func _message_from_report(report: Dictionary) -> GFNetworkMessage:
	var value: Variant = GFVariantData.get_option_value(report, "message")
	if value is GFNetworkMessage:
		return value
	return null


func _snapshot_from_report(report: Dictionary) -> GFNetworkSnapshot:
	var value: Variant = GFVariantData.get_option_value(report, "snapshot")
	if value is GFNetworkSnapshot:
		return value
	return null
