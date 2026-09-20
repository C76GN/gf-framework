# 测试独占异步读取的公开领取、隔离与 caller 生命周期合同。
extends GutTest


# --- 常量 ---

const _PUMP_FRAME_LIMIT: int = 300
const _RECEIPT_KEYS: Array[String] = [
	"request_id", "consumer_id", "file_name", "status", "end_kind", "error_code",
	"failure_kind", "read_failure_kind", "source_version", "target_version",
	"migrated", "integrity_checked", "integrity_ok", "committed_revision",
]


# --- 私有变量 ---

var _storage: GFStorageUtility
var _gated_storage: _GatedStorage
var _migration_cycle: Array = []
var _save_dir_name: String = ""
var _storage_root: String = ""


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_save_dir_name = "gf-storage-owned-read-" + GFUuid.generate_v4()
	_storage_root = GFStorageFamilyStore.make_storage_root_path_for_framework(_save_dir_name)
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0
	_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE


func after_each() -> void:
	_migration_cycle.clear()
	if _gated_storage != null:
		_gated_storage.release_for_test()
	_storage.dispose()
	_storage = null
	_gated_storage = null
	assert_true(_storage_root.begins_with("user://gf-storage-owned-read-"))
	if _storage_root.begins_with("user://gf-storage-owned-read-"):
		assert_eq(_remove_owned_tree(_storage_root), OK)
	_storage_root = ""
	_save_dir_name = ""


# --- 公共方法 ---

func test_manual_ticket_and_take_result_have_no_reading_authority() -> void:
	var ticket: GFStorageOwnedRead = GFStorageOwnedRead.new()
	assert_false(ticket.is_valid())
	assert_false(ticket.is_pending())
	assert_false(ticket.is_completed())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.INVALID)
	assert_eq(ticket.get_request_id(), 0)
	assert_eq(ticket.get_consumer_id(), 0)
	assert_eq(ticket.get_file_name(), "")
	assert_null(ticket.get_result())
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.INVALID)
	assert_false(ticket.release())
	assert_false(ticket.cancel_observation())
	var take_result: GFStorageOwnedReadTakeResult = GFStorageOwnedReadTakeResult.new()
	assert_false(take_result.is_ok())
	assert_eq(take_result.get_status(), GFStorageOwnedReadTakeResult.Status.INVALID)
	assert_null(take_result.get_read_result())


func test_immediate_failures_and_missing_file_remain_distinct_from_empty_success() -> void:
	var invalid: GFStorageOwnedRead = _storage.load_data_owned_request_async("../outside.json")
	assert_push_error("[GFStorageUtility][storage_utility.filename_profile_invalid] load_data_owned_request_async failed: file_name does not satisfy the portable logical path profile.")
	_assert_read_failure(invalid, GFStorageReadResult.FailureKind.INVALID_REQUEST)
	_assert_uncaptured_receipt(invalid)
	var invalid_options: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"valid.json", GFStorageAsyncRequestOptions.new()
	)
	_assert_read_failure(invalid_options, GFStorageReadResult.FailureKind.INVALID_REQUEST)
	_assert_uncaptured_receipt(invalid_options)
	var missing: GFStorageOwnedRead = _storage.load_data_owned_request_async("missing.json")
	_storage.wait_for_async_tasks()
	_assert_read_failure(missing, GFStorageReadResult.FailureKind.NOT_FOUND)
	_assert_uncaptured_receipt(missing)
	assert_eq(_storage.save_data("empty.json", {}), OK)
	var empty: GFStorageOwnedRead = _storage.load_data_owned_request_async("empty.json")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(empty)
	if read != null:
		assert_true(read.payload.is_empty())
	assert_eq(empty.get_result().get_source_version(), 1)
	assert_eq(empty.get_result().get_target_version(), 1)
	var legacy_revision: GFStorageRevisionResult = empty.get_result().get_committed_revision()
	assert_not_null(legacy_revision)
	if legacy_revision != null:
		assert_eq(legacy_revision.get_status(), GFStorageRevisionResult.Status.UNSUPPORTED)
	_storage.dispose()
	var unavailable: GFStorageOwnedRead = _storage.load_data_owned_request_async("empty.json")
	_assert_read_failure(unavailable, GFStorageReadResult.FailureKind.UNAVAILABLE)
	_assert_uncaptured_receipt(unavailable)


func test_failed_migration_preserves_observed_version_without_inventing_revision() -> void:
	_storage.save_version = 3
	assert_eq(_storage.save_data("future.json", {"value": 1}), OK)
	_storage.save_version = 2
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("future.json")
	_storage.wait_for_async_tasks()
	_assert_read_failure(ticket, GFStorageReadResult.FailureKind.FUTURE_VERSION)
	assert_eq(ticket.get_result().get_source_version(), 3)
	assert_eq(ticket.get_result().get_target_version(), 3)
	assert_null(ticket.get_result().get_committed_revision())


func test_owned_migration_accepts_finite_projection_and_typed_projection_array() -> void:
	var migrator: _AliasingMigrationStorage = _use_aliasing_migration_storage()
	var projections: Array[Projection] = [Projection.IDENTITY]
	migrator.injected_payload = {"projection": Projection.IDENTITY, "projections": projections}
	assert_eq(_storage.save_data("projection.json", {"value": 1}), OK)
	_storage.save_version = 2
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("projection.json")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var projection: Projection = read.payload.get("projection")
		var delivered: Array = read.payload.get("projections")
		assert_eq(projection, Projection.IDENTITY)
		assert_eq(delivered.get_typed_builtin(), TYPE_PROJECTION)
		assert_eq(delivered, projections)


func test_cooperative_disk_read_transfers_once_and_preserves_legacy_channel() -> void:
	_assert_disk_read_and_legacy_isolation(GFStorageUtility.AsyncExecutionMode.COOPERATIVE)


func test_threaded_disk_read_transfers_once_and_preserves_legacy_channel() -> void:
	_assert_disk_read_and_legacy_isolation(GFStorageUtility.AsyncExecutionMode.THREADED)


func test_ready_release_is_idempotent_and_does_not_revoke_a_taken_result() -> void:
	assert_eq(_storage.save_data("release.json", {"value": 7}), OK)
	var released: GFStorageOwnedRead = _storage.load_data_owned_request_async("release.json")
	_storage.wait_for_async_tasks()
	assert_eq(released.get_state(), GFStorageOwnedRead.State.READY)
	assert_true(released.release())
	assert_false(released.release())
	assert_eq(released.get_state(), GFStorageOwnedRead.State.RELEASED)
	_assert_take_status(released, GFStorageOwnedReadTakeResult.Status.RELEASED)
	assert_true(released.get_result().is_ok())
	var taken: GFStorageOwnedRead = _storage.load_data_owned_request_async("release.json")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(taken)
	assert_false(taken.release())
	assert_false(taken.cancel_observation())
	_storage.dispose()
	if read != null:
		assert_eq(GFVariantData.get_option_int(read.payload, "value"), 7)


func test_waiting_release_discards_delivery_without_cancelling_physical_read() -> void:
	assert_eq(_storage.save_data("release-waiting.json", {"value": 8}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("release-waiting.json")
	var notifications: Array[int] = _count_completions(ticket)
	assert_true(ticket.release())
	assert_true(ticket.is_pending())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.RELEASED)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.RELEASED)
	_storage.wait_for_async_tasks()
	assert_true(ticket.is_completed())
	assert_true(ticket.get_result().is_ok(), "release 只放弃领取权，不应伪造取消。")
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.RELEASED)
	assert_eq(notifications[0], 1)
	assert_true(_storage.get_late_settlement_diagnostics().is_empty())
	assert_false(ticket.release())


func test_ready_result_survives_owner_token_deadline_and_utility_disposal() -> void:
	assert_eq(_storage.save_data("ready.json", {"value": 9}), OK)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var owner_ref: WeakRef = weakref(lifecycle_owner)
	var source: GFCancellationSource = GFCancellationSource.new()
	var clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	assert_true(_storage.set_async_clock_for_framework(clock))
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"ready.json", GFStorageAsyncRequestOptions.create(lifecycle_owner, source.get_token(), 10)
	)
	var notifications: Array[int] = _count_completions(ticket)
	_storage.wait_for_async_tasks()
	lifecycle_owner = null
	assert_true(owner_ref.get_ref() == null)
	assert_true(source.cancel(&"after_ready"))
	assert_true(clock.advance_msec(10))
	_storage.tick(0.0)
	_storage.dispose()
	assert_false(ticket.cancel_observation())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.READY)
	assert_eq(notifications[0], 1)
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		assert_eq(GFVariantData.get_option_int(read.payload, "value"), 9)
	source.dispose()


func test_migration_retained_nested_and_packed_aliases_cannot_mutate_owned_result() -> void:
	var migrator: _AliasingMigrationStorage = _use_aliasing_migration_storage()
	migrator.injected_payload = {"bytes": PackedByteArray([1, 2, 3])}
	assert_eq(_storage.save_data("aliases.json", {"items": [{"value": 1}]}), OK)
	_storage.save_version = 2
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("aliases.json")
	_storage.wait_for_async_tasks()
	assert_false(migrator.retained_payload.is_empty())
	var read: GFStorageReadResult = _take_success(ticket)
	if read == null:
		return
	var original_items: Array = GFVariantData.as_array(migrator.retained_payload.get("items"))
	var original_item: Dictionary = GFVariantData.as_dictionary(original_items[0])
	original_item["value"] = 100
	var original_bytes: PackedByteArray = migrator.retained_payload.get("bytes")
	original_bytes[0] = 100
	migrator.retained_payload["bytes"] = original_bytes
	var owned_items: Array = GFVariantData.as_array(read.payload.get("items"))
	var owned_item: Dictionary = GFVariantData.as_dictionary(owned_items[0])
	var owned_bytes: PackedByteArray = read.payload.get("bytes")
	assert_eq(GFVariantData.get_option_int(owned_item, "value"), 1)
	assert_eq(owned_bytes, PackedByteArray([1, 2, 3]))
	owned_item["value"] = 200
	owned_bytes[1] = 200
	read.payload["bytes"] = owned_bytes
	assert_eq(GFVariantData.get_option_int(original_item, "value"), 100)
	assert_eq(original_bytes, PackedByteArray([100, 2, 3]))
	assert_true(read.migrated)
	assert_true(ticket.get_result().was_migrated())
	assert_eq(ticket.get_result().get_source_version(), 1)
	assert_eq(ticket.get_result().get_target_version(), 2)


func test_object_and_resource_migration_outputs_are_explicitly_unsupported() -> void:
	assert_eq(_storage.save_data("object.json", {"kind": "object"}), OK)
	assert_eq(_storage.save_data("resource.json", {"kind": "resource"}), OK)
	_storage.save_version = 2
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["unsupported"] = (
			Resource.new() if GFVariantData.get_option_string(data, "kind") == "resource"
			else RefCounted.new()
		)
		return data
	))
	for file_name: String in ["object.json", "resource.json"]:
		var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(file_name)
		_storage.wait_for_async_tasks()
		assert_true(ticket.is_completed())
		assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
		var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
		assert_not_null(receipt)
		if receipt == null:
			continue
		assert_false(receipt.is_ok())
		assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
		assert_ne(receipt.get_read_failure_kind(), GFStorageReadResult.FailureKind.CORRUPT)
		_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)
		_assert_small_receipt(receipt)
	assert_null(_storage.last_load_result, "不支持独占交付时不能回退到 legacy 缓存。")


func test_override_rejects_empty_object_typed_container_cycle_and_excess_depth() -> void:
	var migrator: _AliasingMigrationStorage = _use_aliasing_migration_storage()
	assert_eq(_storage.save_data("unsupported-graph.json", {"value": 1}), OK)
	_storage.save_version = 2
	var empty_resources: Array[Resource] = []
	_migration_cycle.append(_migration_cycle)
	var deep_payload: Dictionary = {}
	var cursor: Dictionary = deep_payload
	for _depth: int in range(129):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	var cases: Array[Dictionary] = [
		{"kind": "empty_typed_resource", "value": empty_resources},
		{"kind": "cycle", "value": _migration_cycle},
		{"kind": "depth", "value": deep_payload},
	]
	for scenario: Dictionary in cases:
		var kind: String = GFVariantData.get_option_string(scenario, "kind")
		migrator.injected_payload = {"unsupported": scenario.get("value")}
		var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("unsupported-graph.json")
		_storage.wait_for_async_tasks()
		assert_true(ticket.is_completed(), kind)
		assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED, kind)
		var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
		assert_not_null(receipt, kind)
		if receipt != null:
			assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD, kind)
			assert_eq(receipt.get_read_failure_kind(), GFStorageReadResult.FailureKind.NONE, kind)
			assert_true(receipt.was_migrated(), kind)
			_assert_small_receipt(receipt)
		_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)
	_migration_cycle.clear()
	assert_null(_storage.last_load_result)
	assert_true(_storage.get_late_settlement_diagnostics().is_empty())


func test_registered_migrations_reject_unsupported_graph_before_next_step_or_result_copy() -> void:
	assert_eq(_storage.save_data("registered-graph.json", {"value": 1}), OK)
	_migration_cycle.append(_migration_cycle)
	var deep_payload: Dictionary = {}
	var cursor: Dictionary = deep_payload
	for _depth: int in range(129):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	var cases: Array[Dictionary] = [
		{"kind": "cycle", "value": _migration_cycle},
		{"kind": "depth", "value": deep_payload},
	]
	for step_count: int in [1, 2]:
		for scenario: Dictionary in cases:
			_storage.clear_migrations()
			_storage.save_version = step_count + 1
			var label: String = "%s/%d-step" % [GFVariantData.get_option_string(scenario, "kind"), step_count]
			var unsupported_value: Variant = scenario.get("value")
			var following_step_calls: Array[int] = [0]
			assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
				data["unsupported"] = unsupported_value
				return data
			))
			if step_count == 2:
				assert_true(_storage.register_migration(2, 3, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
					following_step_calls[0] += 1
					return data
				))
			var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("registered-graph.json")
			_storage.wait_for_async_tasks()
			assert_true(ticket.is_completed(), label)
			assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED, label)
			var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
			assert_not_null(receipt, label)
			if receipt != null:
				assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD, label)
				assert_eq(receipt.get_read_failure_kind(), GFStorageReadResult.FailureKind.NONE, label)
				_assert_small_receipt(receipt)
			assert_eq(following_step_calls[0], 0, "不安全的迁移输出不得进入下一步：" + label)
			_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)
	_migration_cycle.clear()
	assert_null(_storage.last_load_result)


func test_migration_preserves_same_file_io_reentry_guard() -> void:
	assert_eq(_storage.save_data("reentry.json", {"value": 1}), OK)
	_storage.save_version = 2
	var nested_errors: Array[Error] = []
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		var nested: GFStorageReadResult = _storage.load_data("reentry.json")
		nested_errors.append(nested.error_code)
		return data
	))
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("reentry.json")
	_storage.wait_for_async_tasks()
	assert_eq(nested_errors, [ERR_BUSY])
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		assert_eq(GFVariantData.get_option_int(read.payload, "value"), 1)


func test_revision_receipt_and_taken_read_keep_actual_token_across_migration_signal_commit() -> void:
	assert_eq(_storage.create_revision_storage(), OK)
	assert_eq(_storage.save_data("revision.json", {"value": 1}), OK)
	var source_token: String = _storage.query_committed_revision("revision.json").get_revision()
	assert_false(source_token.is_empty())
	_storage.save_version = 2
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["value"] = 2
		return data
	))
	var persisted_errors: Array[Error] = []
	var on_migrated: Callable = func(file_name: String, _from: int, _to: int) -> void:
		persisted_errors.append(_storage.save_data(file_name, {"value": 3}))
	assert_eq(_storage.data_migrated.connect(on_migrated), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("revision.json")
	_storage.wait_for_async_tasks()
	_storage.data_migrated.disconnect(on_migrated)
	var read: GFStorageReadResult = _take_success(ticket)
	if read == null:
		return
	assert_eq(persisted_errors, [OK])
	assert_ne(_storage.query_committed_revision("revision.json").get_revision(), source_token)
	assert_eq(read.get_committed_revision().get_revision(), source_token)
	assert_eq(ticket.get_result().get_committed_revision().get_revision(), source_token)
	assert_eq(GFVariantData.get_option_int(read.payload, "value"), 2)
	_assert_small_receipt(ticket.get_result())


func test_queued_cancel_completes_once_without_running_migration() -> void:
	assert_eq(_storage.save_data("queued.json", {"value": 1}), OK)
	_storage.save_version = 2
	var migrated: Array[int] = [0]
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		migrated[0] += 1
		return data
	))
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("queued.json")
	var notifications: Array[int] = _count_completions(ticket)
	assert_true(ticket.cancel_observation())
	assert_false(ticket.cancel_observation())
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL)
	assert_eq(ticket.get_result().get_status(), GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED)
	_storage.wait_for_async_tasks()
	assert_eq(notifications[0], 1)
	assert_eq(migrated[0], 0)
	assert_true(_storage.get_late_settlement_diagnostics().is_empty())


func test_precancelled_token_returns_terminal_before_worker_acceptance() -> void:
	_use_gated_storage()
	assert_eq(_storage.save_data("precancelled.json", {"value": 1}), OK)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(source.cancel(&"before_request"))
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"precancelled.json", GFStorageAsyncRequestOptions.create(lifecycle_owner, source.get_token())
	)
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.TOKEN_CANCELLED)
	if ticket.get_result() != null:
		assert_eq(ticket.get_result().get_status(), GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED)
	assert_eq(_gated_storage.worker_start_count, 0)
	_gated_storage.release_for_test()
	_storage.wait_for_async_tasks()
	assert_eq(_gated_storage.worker_start_count, 0, "预取消必须在入口内阻止 worker 接纳。")
	assert_true(_storage.get_late_settlement_diagnostics().is_empty())
	assert_null(_storage.last_load_result)
	source.dispose()


func test_accepted_cooperative_cancel_preserves_late_settlement_and_legacy_file_lane() -> void:
	assert_eq(_storage.save_data("lane.json", {"value": 11}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("lane.json")
	var notifications: Array[int] = _count_completions(ticket)
	_storage.tick(0.0)
	assert_true(ticket.is_pending())
	assert_true(ticket.cancel_observation())
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL)
	assert_eq(ticket.get_result().get_status(), GFStorageAsyncCallerResult.Status.CANCELLED)
	var follower: GFStorageAsyncOperation = _storage.load_data_request_async("lane.json")
	assert_true(follower.is_pending())
	_storage.tick(0.0)
	assert_true(follower.is_pending(), "同文件 follower 可被接纳，但不能在同 tick 抢先执行。")
	_storage.wait_for_async_tasks()
	assert_eq(notifications[0], 1)
	assert_true(follower.get_result().is_successful())
	var read: GFStorageReadResult = follower.get_result().get_read_result()
	assert_eq(GFVariantData.get_option_int(read.payload, "value"), 11)
	_assert_successful_late_load(ticket)


func test_accepted_token_cancel_uses_small_diagnostic_and_discards_late_payload() -> void:
	assert_eq(_storage.save_data("token.json", {"secret": "owned-payload-secret"}), OK)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"token.json", GFStorageAsyncRequestOptions.create(lifecycle_owner, source.get_token())
	)
	var notifications: Array[int] = _count_completions(ticket)
	_storage.tick(0.0)
	assert_true(source.cancel(&"private_reason", {"secret": "cancellation-secret"}))
	_storage.tick(0.0)
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.TOKEN_CANCELLED)
	_storage.wait_for_async_tasks()
	assert_eq(notifications[0], 1)
	_assert_successful_late_load(ticket)
	_assert_small_receipt(ticket.get_result())
	assert_false(JSON.stringify(ticket.get_result().to_dict()).contains("secret"))
	source.dispose()


func test_accepted_deadline_uses_manual_clock_and_does_not_turn_late_read_into_success() -> void:
	assert_eq(_storage.save_data("deadline.json", {"value": 12}), OK)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	assert_true(_storage.set_async_clock_for_framework(clock))
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"deadline.json", GFStorageAsyncRequestOptions.create(lifecycle_owner, null, 10)
	)
	var notifications: Array[int] = _count_completions(ticket)
	_storage.tick(0.0)
	assert_true(ticket.is_pending())
	assert_true(clock.advance_msec(10))
	_storage.tick(0.0)
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.DEADLINE_EXPIRED)
	_storage.wait_for_async_tasks()
	assert_eq(notifications[0], 1)
	_assert_successful_late_load(ticket)


func test_owner_release_suppresses_notification_but_keeps_queryable_terminal() -> void:
	assert_eq(_storage.save_data("owner.json", {"value": 13}), OK)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var owner_ref: WeakRef = weakref(lifecycle_owner)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async(
		"owner.json", GFStorageAsyncRequestOptions.create(lifecycle_owner)
	)
	var notifications: Array[int] = _count_completions(ticket)
	_storage.tick(0.0)
	lifecycle_owner = null
	assert_true(owner_ref.get_ref() == null)
	_storage.tick(0.0)
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.OWNER_RELEASED)
	_storage.wait_for_async_tasks()
	assert_eq(notifications[0], 0)
	_assert_successful_late_load(ticket)


func test_threaded_cancel_has_one_terminal_and_preserves_same_file_follower() -> void:
	_use_gated_storage()
	assert_eq(_storage.save_data("threaded-lane.json", {"value": 14}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("threaded-lane.json")
	var notifications: Array[int] = _count_completions(ticket)
	var started: bool = await _pump_until_worker_started()
	assert_true(started)
	if not started:
		return
	assert_true(ticket.cancel_observation())
	_assert_cancelled(ticket, GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL)
	var follower: GFStorageAsyncOperation = _storage.load_data_request_async("threaded-lane.json")
	assert_true(follower.is_pending())
	assert_eq(_gated_storage.worker_start_count, 1)
	_gated_storage.release_for_test()
	_storage.wait_for_async_tasks()
	assert_eq(_gated_storage.worker_start_count, 2)
	assert_eq(notifications[0], 1)
	assert_true(follower.get_result().is_successful())
	_assert_successful_late_load(ticket)


func test_dispose_joins_accepted_read_and_cancels_queued_owned_read() -> void:
	_use_gated_storage()
	assert_eq(_storage.save_data("dispose.json", {"value": 15}), OK)
	var active: GFStorageOwnedRead = _storage.load_data_owned_request_async("dispose.json")
	var active_notifications: Array[int] = _count_completions(active)
	var started: bool = await _pump_until_worker_started()
	assert_true(started)
	if not started:
		return
	var queued: GFStorageOwnedRead = _storage.load_data_owned_request_async("dispose.json")
	var queued_notifications: Array[int] = _count_completions(queued)
	_gated_storage.release_for_test()
	_storage.dispose()
	assert_true(active.is_completed())
	assert_eq(active.get_state(), GFStorageOwnedRead.State.READY)
	assert_eq(active_notifications[0], 1)
	_assert_cancelled(queued, GFStorageAsyncCallerResult.EndKind.UTILITY_DISPOSED)
	assert_eq(queued_notifications[0], 1)
	var read: GFStorageReadResult = _take_success(active)
	if read != null:
		assert_eq(GFVariantData.get_option_int(read.payload, "value"), 15)


func test_dropped_waiting_and_ready_tickets_are_not_retained_by_utility() -> void:
	assert_eq(_storage.save_data("dropped.json", {"items": [{"value": 16}]}), OK)
	var queued: GFStorageOwnedRead = _storage.load_data_owned_request_async("dropped.json")
	var queued_ref: WeakRef = weakref(queued)
	queued = null
	assert_true(queued_ref.get_ref() == null, "未接纳记录不能强持有 ticket。")
	_storage.wait_for_async_tasks()
	var accepted: GFStorageOwnedRead = _storage.load_data_owned_request_async("dropped.json")
	_storage.tick(0.0)
	var accepted_ref: WeakRef = weakref(accepted)
	accepted = null
	assert_true(accepted_ref.get_ref() == null, "已接纳记录不能强持有 ticket。")
	_storage.wait_for_async_tasks()
	var ready_ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("dropped.json")
	_storage.wait_for_async_tasks()
	assert_eq(ready_ticket.get_state(), GFStorageOwnedRead.State.READY)
	var ready_ref: WeakRef = weakref(ready_ticket)
	ready_ticket = null
	assert_true(ready_ref.get_ref() == null, "READY ticket 只能由调用方持有。")
	var follower: GFStorageAsyncOperation = _storage.load_data_request_async("dropped.json")
	_storage.wait_for_async_tasks()
	assert_true(follower.get_result().is_successful(), "丢弃句柄后物理任务和文件 lane 必须收敛。")


func test_taken_read_is_not_kept_alive_by_ticket_or_receipt() -> void:
	assert_eq(_storage.save_data("last-reference.json", {"value": 17}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("last-reference.json")
	_storage.wait_for_async_tasks()
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	var take_result: GFStorageOwnedReadTakeResult = ticket.take()
	assert_true(take_result.is_ok())
	var read: GFStorageReadResult = take_result.get_read_result()
	assert_not_null(read)
	if read == null:
		return
	assert_same(read, take_result.get_read_result(), "getter 只返回已转移的同一对象。")
	var read_ref: WeakRef = weakref(read)
	read = null
	take_result = null
	assert_true(read_ref.get_ref() == null, "ticket、receipt 与 Utility 不能留住已移交的结果。")
	assert_true(receipt.is_ok())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.TAKEN)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.ALREADY_TAKEN)


func test_completed_callback_can_drop_taken_read_before_signal_returns() -> void:
	assert_eq(_storage.save_data("callback-lifetime.json", {"value": 19}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("callback-lifetime.json")
	var released_inside_callback: Array[bool] = []
	var on_completed: Callable = func(_receipt: GFStorageOwnedReadReceipt) -> void:
		var take_result: GFStorageOwnedReadTakeResult = ticket.take()
		var read: GFStorageReadResult = take_result.get_read_result()
		if read == null:
			released_inside_callback.append(false)
			return
		var read_ref: WeakRef = weakref(read)
		read = null
		take_result = null
		released_inside_callback.append(read_ref.get_ref() == null)
	assert_eq(ticket.completed.connect(on_completed), OK)
	_storage.wait_for_async_tasks()
	ticket.completed.disconnect(on_completed)
	assert_eq(released_inside_callback, [true], "通知前必须移除框架内部完整结果别名，不能等 signal 栈返回才释放。")
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.TAKEN)


func test_quiesce_completion_observes_terminal_owned_ticket_and_can_take() -> void:
	assert_eq(_storage.save_data("quiesce.json", {"value": 20}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("quiesce.json")
	_storage.tick(0.0)
	assert_true(ticket.is_pending())
	var scope: GFAsyncScope = GFAsyncScope.new()
	var quiesce: GFAsyncCompletion = _storage.begin_quiesce(scope)
	assert_false(quiesce.is_completed())
	var terminal_observations: Array[bool] = []
	var take_statuses: Array[GFStorageOwnedReadTakeResult.Status] = []
	var taken_values: Array[int] = []
	var on_quiesced: Callable = func(_completion: GFAsyncCompletion) -> void:
		terminal_observations.append(ticket.is_completed())
		var take_result: GFStorageOwnedReadTakeResult = ticket.take()
		take_statuses.append(take_result.get_status())
		var read: GFStorageReadResult = take_result.get_read_result()
		if read != null:
			taken_values.append(GFVariantData.get_option_int(read.payload, "value"))
	assert_eq(quiesce.completed.connect(on_quiesced), OK)
	_storage.tick(0.0)
	_storage.wait_for_async_tasks()
	quiesce.completed.disconnect(on_quiesced)
	assert_true(quiesce.is_successful())
	assert_eq(terminal_observations, [true], "quiesce 成功不能先于仍归 Storage 管理的 caller 终态。")
	assert_eq(take_statuses, [GFStorageOwnedReadTakeResult.Status.SUCCESS])
	assert_eq(taken_values, [20])
	scope.complete()


func test_malformed_worker_result_converges_to_read_failure_instead_of_waiting() -> void:
	_storage.dispose()
	var injected: _InjectedWorkerStorage = _InjectedWorkerStorage.new()
	injected.save_dir_name = _save_dir_name
	injected.encrypt_key = 0
	injected.async_execution_mode = GFStorageUtility.AsyncExecutionMode.THREADED
	_storage = injected
	assert_eq(_storage.save_data("malformed.json", {"value": 21}), OK)
	var cases: Array[Dictionary] = [
		{"ok": true, "error_code": ERR_FILE_CANT_READ, "failure_kind": GFStorageReadResult.FailureKind.NONE},
		{"ok": false, "error_code": OK, "failure_kind": GFStorageReadResult.FailureKind.IO_FAILED},
	]
	for scenario: Dictionary in cases:
		injected.result_fields = scenario
		var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("malformed.json")
		var notifications: Array[int] = _count_completions(ticket)
		_storage.wait_for_async_tasks()
		_assert_read_failure(ticket, GFStorageReadResult.FailureKind.IO_FAILED)
		assert_eq(notifications[0], 1)
		if ticket.get_result() != null:
			assert_ne(ticket.get_result().get_error_code(), OK)
	assert_eq(injected.worker_start_count, cases.size())
	assert_null(_storage.last_load_result)


func test_worker_thread_take_is_rejected_without_consuming_ready_result() -> void:
	assert_eq(_storage.save_data("thread-affinity.json", {"value": 18}), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("thread-affinity.json")
	_storage.wait_for_async_tasks()
	var thread: Thread = Thread.new()
	var start_error: Error = thread.start(func() -> GFStorageOwnedReadTakeResult:
		return ticket.take()
	)
	assert_eq(start_error, OK)
	if start_error != OK:
		return
	var attempt: GFStorageOwnedReadTakeResult = thread.wait_to_finish()
	assert_eq(attempt.get_status(), GFStorageOwnedReadTakeResult.Status.WRONG_THREAD)
	assert_null(attempt.get_read_result())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.READY)
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		assert_eq(GFVariantData.get_option_int(read.payload, "value"), 18)


func test_owned_defaults_ignore_unsafe_values_for_existing_equivalent_keys() -> void:
	assert_eq(_storage.save_data("ignored-defaults.json", {
		"existing": 31,
		"blocked_cycle": 32,
		"nested": {"existing": 33},
	}), OK)
	_migration_cycle.append(_migration_cycle)
	_storage.default_values_for_new_keys = {
		&"existing": Resource.new(),
		"blocked_cycle": _migration_cycle,
		&"nested": {&"existing": RefCounted.new(), &"added": 34},
		"added": 35,
	}
	for target_version: int in [1, 2]:
		_storage.save_version = target_version
		var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("ignored-defaults.json")
		_storage.wait_for_async_tasks()
		var read: GFStorageReadResult = _take_success(ticket)
		if read != null:
			assert_eq(read.payload.size(), 4)
			assert_eq(GFVariantData.get_option_int(read.payload, "existing"), 31)
			assert_eq(GFVariantData.get_option_int(read.payload, "blocked_cycle"), 32)
			assert_eq(GFVariantData.get_option_int(read.payload, "added"), 35)
			var nested: Dictionary = GFVariantData.get_option_dictionary(read.payload, "nested")
			assert_eq(nested.size(), 2)
			assert_eq(GFVariantData.get_option_int(nested, "existing"), 33)
			assert_eq(GFVariantData.get_option_int(nested, "added"), 34)
	_migration_cycle.clear()


func test_owned_migration_override_does_not_validate_unused_defaults() -> void:
	var migrator: _AliasingMigrationStorage = _use_aliasing_migration_storage()
	assert_eq(_storage.save_data("override-defaults.json", {"existing": 36}), OK)
	_migration_cycle.append(_migration_cycle)
	_storage.default_values_for_new_keys = {"unused_object": Resource.new(), "unused_cycle": _migration_cycle}
	_storage.save_version = 2
	migrator.injected_payload = {"from_override": 37}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("override-defaults.json")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		assert_true(read.migrated)
		assert_eq(read.payload.size(), 2)
		assert_eq(GFVariantData.get_option_int(read.payload, "existing"), 36)
		assert_eq(GFVariantData.get_option_int(read.payload, "from_override"), 37)
	_migration_cycle.clear()


func test_owned_defaults_reject_incompatible_entries_before_typed_dictionary_assignment() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_values: Dictionary[String, int] = {"existing": 39}
	assert_eq(_storage.save_data("typed-defaults.bin", {"nested": typed_values}), OK)
	var baseline: GFStorageReadResult = _storage.load_data("typed-defaults.bin")
	assert_true(baseline.ok)
	var nested_baseline: Dictionary = GFVariantData.as_dictionary(baseline.payload.get("nested"))
	assert_eq(nested_baseline.get_typed_key_builtin(), TYPE_STRING)
	assert_eq(nested_baseline.get_typed_value_builtin(), TYPE_INT)
	var incompatible_defaults: Array[Dictionary] = [
		{"inserted": Resource.new()},
		{"inserted": "cannot convert to int"},
		{42: 40},
	]
	for defaults: Dictionary in incompatible_defaults:
		_storage.default_values_for_new_keys = {"nested": defaults}
		var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("typed-defaults.bin")
		_storage.wait_for_async_tasks()
		assert_true(ticket.is_completed())
		assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
		var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
		assert_not_null(receipt)
		if receipt != null:
			assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
			assert_eq(receipt.get_read_failure_kind(), GFStorageReadResult.FailureKind.NONE)
		_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)


func test_owned_defaults_preserve_typed_dictionary_numeric_and_string_name_conversions() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_values: Dictionary[String, float] = {"existing": 41.0}
	var typed_integers: Dictionary[String, int] = {}
	var typed_strings: Dictionary[String, String] = {}
	var typed_names: Dictionary[StringName, StringName] = {}
	assert_eq(_storage.save_data("compatible-defaults.bin", {
		"nested": typed_values, "integers": typed_integers, "strings": typed_strings, "names": typed_names,
	}), OK)
	_storage.default_values_for_new_keys = {
		&"nested": {&"existing": Resource.new(), &"inserted": 42},
		"integers": {"inserted": 43.75},
		"strings": {&"inserted": &"string value"},
		"names": {"inserted": "name value"},
	}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("compatible-defaults.bin")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var nested: Dictionary = GFVariantData.as_dictionary(read.payload.get("nested"))
		assert_eq(nested.get_typed_key_builtin(), TYPE_STRING)
		assert_eq(nested.get_typed_value_builtin(), TYPE_FLOAT)
		assert_eq(nested.size(), 2)
		assert_eq(GFVariantData.get_option_float(nested, "existing"), 41.0)
		assert_eq(GFVariantData.get_option_float(nested, "inserted"), 42.0)
		var integers: Dictionary = GFVariantData.as_dictionary(read.payload.get("integers"))
		var strings: Dictionary = GFVariantData.as_dictionary(read.payload.get("strings"))
		var names: Dictionary = GFVariantData.as_dictionary(read.payload.get("names"))
		assert_eq(integers.get_typed_value_builtin(), TYPE_INT)
		assert_eq(GFVariantData.get_option_int(integers, "inserted"), 43)
		assert_eq(strings.get_typed_key_builtin(), TYPE_STRING)
		assert_eq(strings.get_typed_value_builtin(), TYPE_STRING)
		assert_eq(GFVariantData.get_option_string(strings, "inserted"), "string value")
		assert_eq(names.get_typed_key_builtin(), TYPE_STRING_NAME)
		assert_eq(names.get_typed_value_builtin(), TYPE_STRING_NAME)
		assert_eq(GFVariantData.get_option_string_name(names, "inserted"), &"name value")


func test_owned_defaults_accept_string_keys_for_typed_node_path_dictionary() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_paths: Dictionary[NodePath, int] = {^"Root/Existing": 43}
	assert_eq(_storage.save_data("node-path-defaults.bin", {"paths": typed_paths}), OK)
	_storage.default_values_for_new_keys = {
		"paths": {"Root/Existing": Resource.new(), "Root/Added": 44},
	}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("node-path-defaults.bin")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var paths: Dictionary = GFVariantData.as_dictionary(read.payload.get("paths"))
		assert_eq(paths.get_typed_key_builtin(), TYPE_NODE_PATH)
		assert_eq(paths.get_typed_value_builtin(), TYPE_INT)
		assert_eq(paths.size(), 2)
		var existing_value: int = GFVariantData.get_option_int(paths, ^"Root/Existing")
		var added_value: int = GFVariantData.get_option_int(paths, ^"Root/Added")
		assert_eq(existing_value, 43)
		assert_eq(added_value, 44)


func test_owned_typed_defaults_share_one_cumulative_payload_validation_budget() -> void:
	_storage.dispose()
	var tracking_storage: _BudgetTrackingStorage = _BudgetTrackingStorage.new()
	tracking_storage.save_dir_name = _save_dir_name
	tracking_storage.encrypt_key = 0
	tracking_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	tracking_storage.file_format = GFStorageCodec.Format.BINARY
	_storage = tracking_storage
	var typed_values: Dictionary[String, Array] = {}
	assert_eq(_storage.save_data("cumulative-defaults.bin", {"values": typed_values}), OK)
	var packed_values: PackedByteArray = PackedByteArray()
	assert_eq(packed_values.resize(262_144), OK)
	var shared_values: Array = [packed_values]
	_storage.default_values_for_new_keys = {
		"values": {"first": shared_values, "second": shared_values, "third": shared_values, "fourth": shared_values},
	}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("cumulative-defaults.bin")
	_storage.wait_for_async_tasks()
	assert_true(ticket.is_completed())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_not_null(receipt)
	if receipt != null:
		assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
	assert_lte(tracking_storage.packed_validation_visits, 3, "默认值预检不能为每个缺失字段重置一百万值预算。")


func test_owned_defaults_reject_invalid_color_text_without_native_assignment_error() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_colors: Dictionary[String, Color] = {}
	assert_eq(_storage.save_data("invalid-color-defaults.bin", {"colors": typed_colors}), OK)
	_storage.default_values_for_new_keys = {"colors": {"invalid": "not-a-color"}}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("invalid-color-defaults.bin")
	_storage.wait_for_async_tasks()
	assert_true(ticket.is_completed())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_not_null(receipt)
	if receipt != null:
		assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)


func test_owned_defaults_accept_native_named_and_hex_color_text() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_colors: Dictionary[String, Color] = {}
	assert_eq(_storage.save_data("valid-color-defaults.bin", {"colors": typed_colors}), OK)
	_storage.default_values_for_new_keys = {"colors": {"named": "red", "hex": "#336699"}}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("valid-color-defaults.bin")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var colors: Dictionary = GFVariantData.as_dictionary(read.payload.get("colors"))
		assert_eq(colors.get_typed_value_builtin(), TYPE_COLOR)
		var named_value: Variant = colors.get("named")
		var hex_value: Variant = colors.get("hex")
		assert_true(named_value is Color)
		assert_true(hex_value is Color)
		if named_value is Color and hex_value is Color:
			var named_color: Color = named_value
			var hex_color: Color = hex_value
			assert_eq(named_color, Color.RED)
			assert_eq(hex_color, Color(0.2, 0.4, 0.6))


func test_owned_defaults_reject_invalid_text_before_packed_color_conversion() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_colors: Dictionary[String, PackedColorArray] = {}
	assert_eq(_storage.save_data("invalid-packed-color-defaults.bin", {"colors": typed_colors}), OK)
	_storage.default_values_for_new_keys = {"colors": {"invalid": ["not-a-color"]}}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("invalid-packed-color-defaults.bin")
	_storage.wait_for_async_tasks()
	assert_true(ticket.is_completed())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_not_null(receipt)
	if receipt != null:
		assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)


func test_owned_defaults_accept_named_and_hex_text_in_packed_color_conversion() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_colors: Dictionary[String, PackedColorArray] = {}
	assert_eq(_storage.save_data("valid-packed-color-defaults.bin", {"colors": typed_colors}), OK)
	_storage.default_values_for_new_keys = {"colors": {"values": ["red", "#336699"]}}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("valid-packed-color-defaults.bin")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var colors: Dictionary = GFVariantData.as_dictionary(read.payload.get("colors"))
		assert_eq(colors.get_typed_value_builtin(), TYPE_PACKED_COLOR_ARRAY)
		var packed_value: Variant = colors.get("values")
		assert_true(packed_value is PackedColorArray)
		if packed_value is PackedColorArray:
			var packed_colors: PackedColorArray = packed_value
			assert_eq(packed_colors, PackedColorArray([Color.RED, Color(0.2, 0.4, 0.6)]))


func test_owned_defaults_keep_native_packed_integer_element_fallback() -> void:
	_storage.file_format = GFStorageCodec.Format.BINARY
	var typed_packed: Dictionary[String, PackedInt32Array] = {}
	assert_eq(_storage.save_data("packed-defaults.bin", {"packed": typed_packed}), OK)
	var source_values: Array = [{}]
	var native: Dictionary = Dictionary({}, TYPE_STRING, &"", null, TYPE_PACKED_INT32_ARRAY, &"", null)
	native["value"] = source_values
	_storage.default_values_for_new_keys = {"packed": {"value": source_values}}
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("packed-defaults.bin")
	_storage.wait_for_async_tasks()
	var read: GFStorageReadResult = _take_success(ticket)
	if read != null:
		var packed: Dictionary = GFVariantData.as_dictionary(read.payload.get("packed"))
		assert_eq(packed.get_typed_value_builtin(), TYPE_PACKED_INT32_ARRAY)
		var native_value: Variant = native.get("value")
		var owned_value: Variant = packed.get("value")
		assert_true(native_value is PackedInt32Array)
		assert_true(owned_value is PackedInt32Array)
		if native_value is PackedInt32Array and owned_value is PackedInt32Array:
			var native_packed: PackedInt32Array = native_value
			var owned_packed: PackedInt32Array = owned_value
			assert_eq(native_packed, PackedInt32Array([0]))
			assert_eq(owned_packed, native_packed)


func test_owned_defaults_reject_unsafe_values_that_would_enter_the_payload() -> void:
	assert_eq(_storage.save_data("inserted-defaults.json", {"nested": {"existing": 38}}), OK)
	_migration_cycle.append(_migration_cycle)
	var deep_default: Dictionary = {}
	var cursor: Dictionary = deep_default
	for _depth: int in range(129):
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	var unsafe_defaults: Array[Variant] = [Resource.new(), RefCounted.new(), _migration_cycle, deep_default]
	for target_version: int in [1, 2]:
		_storage.save_version = target_version
		for unsafe_value: Variant in unsafe_defaults:
			_storage.default_values_for_new_keys = {&"nested": {"inserted": unsafe_value}}
			var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("inserted-defaults.json")
			_storage.wait_for_async_tasks()
			assert_true(ticket.is_completed())
			assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
			var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
			assert_not_null(receipt)
			if receipt != null:
				assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.UNSUPPORTED_PAYLOAD)
				assert_eq(receipt.get_read_failure_kind(), GFStorageReadResult.FailureKind.NONE)
			_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)
	_migration_cycle.clear()


# --- 私有/辅助方法 ---

func _assert_disk_read_and_legacy_isolation(mode: GFStorageUtility.AsyncExecutionMode) -> void:
	_storage.async_execution_mode = mode
	assert_eq(_storage.save_data("legacy.json", {"cache": "keep"}), OK)
	assert_eq(_storage.save_data("owned.json", {"items": [{"value": 3}], "secret": "owned-secret"}), OK)
	var legacy_read: GFStorageReadResult = _storage.load_data("legacy.json")
	assert_true(legacy_read.ok)
	var previous_cache: GFStorageReadResult = _storage.last_load_result
	var legacy_results: Array[GFStorageReadResult] = []
	var on_legacy: Callable = func(_file_name: String, result: GFStorageReadResult) -> void:
		legacy_results.append(result)
	assert_eq(_storage.load_completed.connect(on_legacy), OK)
	var ticket: GFStorageOwnedRead = _storage.load_data_owned_request_async("owned.json")
	assert_true(ticket.is_valid())
	assert_true(ticket.is_pending())
	assert_false(ticket.is_completed())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.WAITING)
	assert_eq(ticket.get_file_name(), "owned.json")
	assert_gt(ticket.get_request_id(), 0)
	assert_gt(ticket.get_consumer_id(), 0)
	assert_null(ticket.get_result())
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.NOT_READY)
	var callback_results: Array[GFStorageOwnedReadTakeResult] = []
	var callback_receipts: Array[GFStorageOwnedReadReceipt] = []
	var on_completed: Callable = func(completed_receipt: GFStorageOwnedReadReceipt) -> void:
		callback_receipts.append(completed_receipt)
		callback_results.append(ticket.take())
	assert_eq(ticket.completed.connect(on_completed), OK)
	_storage.wait_for_async_tasks()
	ticket.completed.disconnect(on_completed)
	assert_true(ticket.is_completed())
	assert_false(ticket.is_pending())
	assert_eq(callback_results.size(), 1)
	assert_eq(callback_receipts.size(), 1)
	assert_true(legacy_results.is_empty(), "owned 入口不能通过旧信号分发完整 payload。")
	assert_same(previous_cache, _storage.last_load_result)
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.TAKEN)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.ALREADY_TAKEN)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	_assert_small_receipt(receipt)
	assert_eq(receipt.get_request_id(), ticket.get_request_id())
	assert_eq(receipt.get_consumer_id(), ticket.get_consumer_id())
	assert_eq(receipt.get_file_name(), ticket.get_file_name())
	if callback_results.size() == 1 and callback_receipts.size() == 1:
		assert_same(receipt, callback_receipts[0])
		assert_true(callback_results[0].is_ok())
		var read: GFStorageReadResult = callback_results[0].get_read_result()
		assert_not_null(read)
		if read != null:
			assert_true(read.ok)
			assert_eq(receipt.was_integrity_checked(), read.integrity_status != GFStorageReadResult.IntegrityStatus.NOT_CHECKED)
			assert_eq(receipt.is_integrity_ok(), read.integrity_status == GFStorageReadResult.IntegrityStatus.VALID)
			var items: Array = GFVariantData.as_array(read.payload.get("items"))
			var item: Dictionary = GFVariantData.as_dictionary(items[0])
			item["value"] = 99
	var legacy_operation: GFStorageAsyncOperation = _storage.load_data_request_async("owned.json")
	_storage.wait_for_async_tasks()
	_storage.load_completed.disconnect(on_legacy)
	assert_true(legacy_operation.get_result().is_successful())
	assert_eq(legacy_results.size(), 1, "随后旧入口仍保留旧通知合同。")
	var reread: GFStorageReadResult = legacy_operation.get_result().get_read_result()
	var reread_items: Array = GFVariantData.as_array(reread.payload.get("items"))
	var reread_item: Dictionary = GFVariantData.as_dictionary(reread_items[0])
	assert_eq(GFVariantData.get_option_int(reread_item, "value"), 3)


func _take_success(ticket: GFStorageOwnedRead) -> GFStorageReadResult:
	assert_true(ticket.is_completed())
	assert_not_null(ticket.get_result())
	if ticket.get_result() == null:
		return null
	assert_true(ticket.get_result().is_ok())
	var take_result: GFStorageOwnedReadTakeResult = ticket.take()
	assert_eq(take_result.get_status(), GFStorageOwnedReadTakeResult.Status.SUCCESS)
	assert_true(take_result.is_ok())
	var read: GFStorageReadResult = take_result.get_read_result()
	assert_not_null(read)
	return read


func _assert_take_status(ticket: GFStorageOwnedRead, status: GFStorageOwnedReadTakeResult.Status) -> void:
	var take_result: GFStorageOwnedReadTakeResult = ticket.take()
	assert_eq(take_result.get_status(), status)
	assert_false(take_result.is_ok())
	assert_null(take_result.get_read_result())


func _assert_uncaptured_receipt(ticket: GFStorageOwnedRead) -> void:
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_eq(receipt.get_source_version(), 0)
	assert_eq(receipt.get_target_version(), 0)
	assert_null(receipt.get_committed_revision())
	assert_true(GFVariantData.get_option_dictionary(receipt.to_dict(), "committed_revision").is_empty())


func _assert_read_failure(ticket: GFStorageOwnedRead, failure_kind: GFStorageReadResult.FailureKind) -> void:
	assert_true(ticket.is_valid())
	assert_true(ticket.is_completed())
	assert_false(ticket.is_pending())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_not_null(receipt)
	if receipt == null:
		return
	assert_false(receipt.is_ok())
	assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.READ_FAILED)
	assert_eq(receipt.get_read_failure_kind(), failure_kind)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)
	_assert_small_receipt(receipt)


func _assert_cancelled(ticket: GFStorageOwnedRead, end_kind: GFStorageAsyncCallerResult.EndKind) -> void:
	assert_true(ticket.is_completed())
	assert_false(ticket.is_pending())
	assert_eq(ticket.get_state(), GFStorageOwnedRead.State.FAILED)
	var receipt: GFStorageOwnedReadReceipt = ticket.get_result()
	assert_not_null(receipt)
	if receipt == null:
		return
	assert_false(receipt.is_ok())
	assert_eq(receipt.get_end_kind(), end_kind)
	assert_eq(receipt.get_failure_kind(), GFStorageOwnedReadReceipt.FailureKind.CANCELLED)
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)


func _assert_successful_late_load(ticket: GFStorageOwnedRead) -> void:
	var diagnostics: Array[Dictionary] = _storage.get_late_settlement_diagnostics()
	assert_eq(diagnostics.size(), 1)
	if diagnostics.size() != 1:
		return
	assert_eq(GFVariantData.get_option_int(diagnostics[0], "request_id"), ticket.get_request_id())
	assert_true(GFVariantData.get_option_bool(diagnostics[0], "worker_accepted"))
	assert_true(GFVariantData.get_option_bool(diagnostics[0], "physical_ok"))
	assert_eq(GFVariantData.get_option_int(diagnostics[0], "physical_error_code"), OK)
	assert_false(diagnostics[0].has("payload"))
	assert_false(diagnostics[0].has("metadata"))
	_assert_take_status(ticket, GFStorageOwnedReadTakeResult.Status.FAILED)


func _assert_small_receipt(receipt: GFStorageOwnedReadReceipt) -> void:
	assert_not_null(receipt)
	if receipt == null:
		return
	var snapshot: Dictionary = receipt.to_dict()
	assert_eq(snapshot.size(), _RECEIPT_KEYS.size())
	for key: String in _RECEIPT_KEYS:
		assert_true(snapshot.has(key), "缺少 receipt 白名单字段：%s" % key)
	assert_false(JSON.stringify(snapshot).contains("owned-secret"))
	assert_lt(JSON.stringify(snapshot).to_utf8_buffer().size(), 2048)
	snapshot["file_name"] = "mutated"
	var revision: Dictionary = GFVariantData.as_dictionary(snapshot.get("committed_revision"))
	revision["revision"] = "mutated"
	assert_ne(receipt.get_file_name(), "mutated")
	if receipt.get_committed_revision() != null:
		assert_ne(receipt.get_committed_revision().get_revision(), "mutated")


func _count_completions(ticket: GFStorageOwnedRead) -> Array[int]:
	var count: Array[int] = [0]
	assert_eq(ticket.completed.connect(func(_receipt: GFStorageOwnedReadReceipt) -> void:
		count[0] += 1
	), OK)
	return count


func _use_gated_storage() -> void:
	_storage.dispose()
	_gated_storage = _GatedStorage.new()
	_gated_storage.save_dir_name = _save_dir_name
	_gated_storage.encrypt_key = 0
	_gated_storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.THREADED
	_gated_storage.max_async_thread_count = 1
	_storage = _gated_storage


func _use_aliasing_migration_storage() -> _AliasingMigrationStorage:
	_storage.dispose()
	var migrator: _AliasingMigrationStorage = _AliasingMigrationStorage.new()
	migrator.save_dir_name = _save_dir_name
	migrator.encrypt_key = 0
	migrator.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	_storage = migrator
	return migrator


func _pump_until_worker_started() -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		if _gated_storage.worker_started.try_wait():
			return true
		await get_tree().process_frame
	return false


func _remove_owned_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_error != OK:
			return remove_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_tree(child_path)
		)
		if remove_error != OK:
			return remove_error
	directory = null
	return DirAccess.remove_absolute(path)


# --- 内部类 ---

class _BudgetTrackingStorage extends GFStorageUtility:
	var packed_validation_visits: int = 0

	func _is_thread_payload_value_finite(value: Variant, value_type: Variant.Type) -> bool:
		if value_type == TYPE_PACKED_BYTE_ARRAY:
			packed_validation_visits += 1
		return super._is_thread_payload_value_finite(value, value_type)


class _InjectedWorkerStorage extends GFStorageUtility:
	var result_fields: Dictionary = {}
	var worker_start_count: int = 0

	func start_async_worker_for_framework(
		_task_type: StringName, thread: Thread, _callback: Callable
	) -> Error:
		worker_start_count += 1
		return thread.start(Callable(self, &"_return_injected_result").bind(result_fields.duplicate(true)))

	func _return_injected_result(fields: Dictionary) -> Dictionary:
		var result: Dictionary = {
			"ok": true,
			"payload": {"value": 21},
			"metadata": {},
			"integrity_status": GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
			"error_code": OK,
			"error": "",
			"failure_kind": GFStorageReadResult.FailureKind.NONE,
			"document_schema_version": 1,
			"source_data_version": 1,
			"data_version": 1,
			"migrated": false,
		}
		for key: Variant in fields:
			result[key] = fields[key]
		return result


class _AliasingMigrationStorage extends GFStorageUtility:
	var injected_payload: Dictionary = {}
	var retained_payload: Dictionary = {}

	func migrate_data(data: Dictionary, _old_version: int, _new_version: int) -> Dictionary:
		for key: Variant in injected_payload:
			data[key] = injected_payload[key]
		retained_payload = data
		return data


class _GatedStorage extends GFStorageUtility:
	var worker_started: Semaphore = Semaphore.new()
	var worker_release: Semaphore = Semaphore.new()
	var worker_start_count: int = 0
	var _release_posted: bool = false

	func start_async_worker_for_framework(
		_task_type: StringName, thread: Thread, callback: Callable
	) -> Error:
		worker_start_count += 1
		if worker_start_count == 1:
			return thread.start(Callable(self, &"_run_gated_worker").bind(callback))
		return thread.start(callback)

	func release_for_test() -> void:
		if _release_posted:
			return
		_release_posted = true
		worker_release.post()

	func _run_gated_worker(callback: Callable) -> Variant:
		worker_started.post()
		worker_release.wait()
		return callback.call()
