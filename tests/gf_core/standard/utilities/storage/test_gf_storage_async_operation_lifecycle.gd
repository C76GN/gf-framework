# 测试 Storage 异步请求的 caller/physical 双终态与 late-settlement 诊断契约。
extends GutTest


const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)
const _CALLER_RESULT_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/storage/gf_storage_async_caller_result.gd"
)
const _REQUEST_OPTIONS_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/storage/gf_storage_async_request_options.gd"
)
const _STORAGE_UTILITY_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/storage/gf_storage_utility.gd"
)
const _PUMP_FRAME_LIMIT: int = 300
const _LATE_DIAGNOSTIC_LIMIT: int = 64
const _LATE_DIAGNOSTIC_MAX_JSON_BYTES: int = 2048
const _LATE_DIAGNOSTIC_KEYS: Array[String] = [
	"consumer_id",
	"request_id",
	"operation",
	"file_name",
	"caller_status",
	"caller_end_kind",
	"caller_reason",
	"caller_completed_msec",
	"worker_accepted",
	"physical_cancel_requested",
	"settlement_kind",
	"physical_ok",
	"physical_error_code",
	"physical_completed_msec",
	"late_duration_msec",
	"read_failure_kind",
	"write_failure_kind",
	"delete_failure_kind",
	"delete_existing_member_count",
	"delete_removed_member_count",
	"delete_remaining_member_count",
	"delete_failed_member",
	"reset_failure_kind",
	"reset_source_kind",
	"reset_failed_phase",
	"reset_retired_member_count",
	"reset_recreated_member_count",
	"reset_remaining_evidence_count",
	"reset_failed_member",
]


class GatedWorkerStorageUtility extends GFStorageUtility:
	var block_next_worker: bool = true
	var worker_started: Semaphore = Semaphore.new()
	var worker_release: Semaphore = Semaphore.new()
	var worker_start_count: int = 0
	var _release_posted: bool = false

	func start_async_worker_for_framework(
		_task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		worker_start_count += 1
		if block_next_worker:
			block_next_worker = false
			return thread.start(Callable(self, &"_run_gated_worker").bind(callback))
		return thread.start(callback)

	func release_for_test() -> void:
		if _release_posted:
			return
		_release_posted = true
		worker_release.post()

	func arm_next_worker_gate_for_test() -> void:
		block_next_worker = true
		worker_started = Semaphore.new()
		worker_release = Semaphore.new()
		_release_posted = false

	func _run_gated_worker(callback: Callable) -> Variant:
		worker_started.post()
		worker_release.wait()
		return callback.call()


class GatedMigrationOrderingStorageUtility extends GatedWorkerStorageUtility:
	var migration_file_name: String = ""
	var primary_operation: GFStorageAsyncOperation = null
	var follower_operation: GFStorageAsyncOperation = null
	var follower_owner: RefCounted = RefCounted.new()
	var migration_call_count: int = 0
	var migration_saw_primary_physical_pending: bool = false
	var migration_saw_original_lock_retained: bool = false
	var migration_saw_follower_queued: bool = false
	var migration_saw_only_primary_worker_started: bool = false
	var follower_start_saw_primary_physical_completed: bool = false

	func start_async_worker_for_framework(
		task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		var is_follower_start: bool = worker_start_count > 0
		if is_follower_start:
			follower_start_saw_primary_physical_completed = (
				primary_operation != null and primary_operation.is_completed()
			)
		return super.start_async_worker_for_framework(task_type, thread, callback)

	func migrate_data(
		data: Dictionary,
		_from_version: int,
		_to_version: int
	) -> Dictionary:
		migration_call_count += 1
		migration_saw_primary_physical_pending = (
			primary_operation != null and primary_operation.is_pending()
		)
		var file_key: String = _get_async_file_key(migration_file_name)
		migration_saw_original_lock_retained = (
			not file_key.is_empty() and _async_file_locks.has(file_key)
		)
		arm_next_worker_gate_for_test()
		var options: GFStorageAsyncRequestOptions = (
			GFStorageAsyncRequestOptions.create(follower_owner)
		)
		follower_operation = save_data_request_async(
			migration_file_name,
			{ "generation": 2 },
			options
		)
		migration_saw_follower_queued = (
			follower_operation != null
			and follower_operation.is_pending()
			and _async_queue.size() == 1
		)
		migration_saw_only_primary_worker_started = worker_start_count == 1
		var migrated: Dictionary = data.duplicate(true)
		migrated["migration_applied"] = true
		return migrated


class StartedWorkerDisposeStorageUtility extends GatedWorkerStorageUtility:
	var override_call_count: int = 0
	var worker_started_before_dispose: bool = false
	var dispose_returned_inside_override: bool = false
	var tracked_before_dispose: bool = false
	var tracked_after_dispose: bool = false
	var lock_retained_after_dispose: bool = false
	var activation_failed_after_dispose: bool = false
	var admission_stayed_closed_after_activation: bool = false

	func start_async_worker_for_framework(
		_task_type: StringName,
		thread: Thread,
		callback: Callable
	) -> Error:
		override_call_count += 1
		worker_start_count += 1
		var start_error: Error = thread.start(callback)
		worker_started_before_dispose = thread.is_started()
		tracked_before_dispose = _async_tasks.size() == 1
		dispose()
		dispose_returned_inside_override = true
		var activation: GFAsyncCompletion = begin_activation(null)
		activation_failed_after_dispose = activation.is_failed()
		admission_stayed_closed_after_activation = not _io_admission_open
		tracked_after_dispose = _async_tasks.size() == 1
		lock_retained_after_dispose = _async_file_locks.size() == 1
		return start_error


class AutomaticCooperativeStorageUtility extends GatedWorkerStorageUtility:
	var thread_start_call_count: int = 0
	var recovery_call_count: int = 0
	var callback_task_types: Array[StringName] = []
	var callback_main_thread_results: Array[bool] = []
	var saved_generations: Array[int] = []

	func has_async_thread_capability_for_framework() -> bool:
		return false

	func start_async_worker_for_framework(
		_task_type: StringName,
		_thread: Thread,
		_callback: Callable
	) -> Error:
		thread_start_call_count += 1
		return ERR_CANT_CREATE

	func _recover_frozen_async_transaction(task: Dictionary) -> Dictionary:
		recovery_call_count += 1
		return super._recover_frozen_async_transaction(task)

	func _save_data_thread(
		file_name: String,
		final_path: String,
		temp_path: String,
		backup_path: String,
		transaction_path: String,
		transaction_pending_path: String,
		transaction_commit_path: String,
		transaction_commit_pending_path: String,
		transaction_id: String,
		data: Dictionary,
		codec_options: Dictionary
	) -> Dictionary:
		_record_cooperative_callback(&"save")
		saved_generations.append(GFVariantData.get_option_int(data, "generation", -1))
		return super._save_data_thread(
			file_name,
			final_path,
			temp_path,
			backup_path,
			transaction_path,
			transaction_pending_path,
			transaction_commit_path,
			transaction_commit_pending_path,
			transaction_id,
			data,
			codec_options
		)

	func _load_data_thread(
		file_name: String,
		path: String,
		codec_options: Dictionary
	) -> Dictionary:
		_record_cooperative_callback(&"load")
		return super._load_data_thread(file_name, path, codec_options)

	func _delete_file_thread(storage_root_path: String, logical_name: String) -> Dictionary:
		_record_cooperative_callback(&"delete")
		return super._delete_file_thread(storage_root_path, logical_name)

	func _record_cooperative_callback(task_type: StringName) -> void:
		callback_task_types.append(task_type)
		callback_main_thread_results.append(Thread.is_main_thread())


class ReentrantCooperativeWaitStorageUtility extends AutomaticCooperativeStorageUtility:
	var reentrant_file_name: String = ""
	var reentrant_read_returned: bool = false
	var reentrant_read_result: GFStorageReadResult = null

	func _record_cooperative_callback(task_type: StringName) -> void:
		if task_type == &"save" and not reentrant_read_returned:
			reentrant_read_result = load_data(reentrant_file_name)
			reentrant_read_returned = true
		super._record_cooperative_callback(task_type)


class ReentrantCooperativeDisposeStorageUtility extends AutomaticCooperativeStorageUtility:
	var dispose_invoked: bool = false
	var deferred_dispose_seen: bool = false
	var task_retained_after_dispose: bool = false
	var lock_retained_after_dispose: bool = false

	func _record_cooperative_callback(task_type: StringName) -> void:
		if task_type == &"save" and not dispose_invoked:
			dispose()
			dispose_invoked = true
			deferred_dispose_seen = _async_deferred_dispose_requested
			task_retained_after_dispose = _async_tasks.size() == 1
			lock_retained_after_dispose = _async_file_locks.size() == 1
		super._record_cooperative_callback(task_type)


class DisposeDuringCooperativeWaitMaintenanceStorageUtility extends AutomaticCooperativeStorageUtility:
	var dispose_on_next_lifecycle_poll: bool = false
	var dispose_invoked_during_poll: bool = false

	func _poll_async_operation_lifecycles() -> void:
		super._poll_async_operation_lifecycles()
		if not dispose_on_next_lifecycle_poll:
			return
		dispose_on_next_lifecycle_poll = false
		dispose()
		dispose_invoked_during_poll = true


class DeadlineDuringCooperativeWaitMaintenanceStorageUtility extends AutomaticCooperativeStorageUtility:
	var manual_clock: GFManualClock = null
	var advance_on_next_lifecycle_poll: bool = false
	var deadline_advanced_during_poll: bool = false

	func _poll_async_operation_lifecycles() -> void:
		super._poll_async_operation_lifecycles()
		if not advance_on_next_lifecycle_poll or manual_clock == null:
			return
		advance_on_next_lifecycle_poll = false
		deadline_advanced_during_poll = manual_clock.advance_msec(10)


var _storage: GatedWorkerStorageUtility
var _save_dir_name: String = ""
var _storage_root_path: String = ""
var _retained_lifecycle_owners: Array[RefCounted] = []


func before_each() -> void:
	_save_dir_name = "gf-storage-async-lifecycle-" + GFUuid.generate_v4()
	_storage_root_path = _GF_STORAGE_FAMILY_STORE_SCRIPT.make_storage_root_path_for_framework(
		_save_dir_name
	)
	assert_true(
		_storage_root_path.begins_with("user://gf-storage-async-lifecycle-"),
		"生命周期测试必须使用 UUID 独占 Storage root。"
	)
	_storage = GatedWorkerStorageUtility.new()
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0


func after_each() -> void:
	if _storage != null:
		_storage.release_for_test()
		_storage.dispose()
		_storage = null
	_retained_lifecycle_owners.clear()
	if _storage_root_path.begins_with("user://gf-storage-async-lifecycle-"):
		assert_eq(_remove_owned_test_tree(_storage_root_path), OK)
	_save_dir_name = ""
	_storage_root_path = ""


func test_dual_terminal_public_contract_and_enum_values_are_frozen() -> void:
	assert_true(
		ResourceLoader.exists(_CALLER_RESULT_SCRIPT_PATH),
		"必须提供 GFStorageAsyncCallerResult 公开值对象。"
	)
	assert_true(
		ResourceLoader.exists(_REQUEST_OPTIONS_SCRIPT_PATH),
		"必须提供 GFStorageAsyncRequestOptions 公开请求选项。"
	)
	if (
		not ResourceLoader.exists(_CALLER_RESULT_SCRIPT_PATH)
		or not ResourceLoader.exists(_REQUEST_OPTIONS_SCRIPT_PATH)
	):
		return

	var caller_result_script: GDScript = _load_gdscript(_CALLER_RESULT_SCRIPT_PATH)
	var request_options_script: GDScript = _load_gdscript(_REQUEST_OPTIONS_SCRIPT_PATH)
	assert_not_null(caller_result_script)
	assert_not_null(request_options_script)
	if caller_result_script == null or request_options_script == null:
		return

	var caller_constants: Dictionary = caller_result_script.get_script_constant_map()
	assert_eq(
		GFVariantData.get_option_dictionary(caller_constants, "Status"),
		{
			"PHYSICAL_SETTLED": 0,
			"CANCELLED": 1,
			"OUTCOME_UNKNOWN": 2,
		},
		"Caller Status 必须是闭合且稳定的三分枚举。"
	)
	assert_eq(
		GFVariantData.get_option_dictionary(caller_constants, "EndKind"),
		{
			"PHYSICAL_SETTLEMENT": 0,
			"EXPLICIT_CANCEL": 1,
			"TOKEN_CANCELLED": 2,
			"DEADLINE_EXPIRED": 3,
			"OWNER_RELEASED": 4,
			"UTILITY_DISPOSED": 5,
		},
		"Caller EndKind 必须保持 first-terminal 可审计分类。"
	)

	var async_result_value: Variant = GFStorageAsyncResult.new().get_script()
	assert_true(async_result_value is GDScript)
	if async_result_value is GDScript:
		var async_result_script: GDScript = async_result_value
		var async_constants: Dictionary = async_result_script.get_script_constant_map()
		assert_eq(
			GFVariantData.get_option_dictionary(async_constants, "SettlementKind"),
			{
				"DOMAIN_RESULT": 0,
				"CANCELLED": 1,
			},
			"Physical settlement 必须区分领域结果和真实取消。"
		)

	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	for method_name: StringName in [
		&"is_caller_pending",
		&"is_caller_completed",
		&"get_caller_result",
		&"cancel_observation",
	]:
		assert_true(operation.has_method(method_name), "Operation 缺少 %s。" % method_name)
	assert_true(operation.has_signal(&"caller_completed"), "Operation 缺少 caller_completed。")
	assert_true(
		_storage.has_method(&"set_async_clock_for_framework"),
		"Storage 必须允许框架测试注入 GFClock。"
	)
	assert_true(
		_storage.has_method(&"get_late_settlement_diagnostics"),
		"Storage 必须公开有界 late-settlement 诊断 ring。"
	)
	_assert_request_api_argument_count(&"save_data_request_async", 3)
	_assert_request_api_argument_count(&"save_payload_request_async", 3)
	_assert_request_api_argument_count(&"load_data_request_async", 2)
	_assert_request_api_argument_count(&"delete_file_request_async", 2)

	var invalid_options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.new()
	assert_false(
		invalid_options.is_valid(),
		"直接 new() 的 request options 必须 fail closed。"
	)
	assert_true(
		request_options_script.has_method(&"create"),
		"Request options 必须通过 static create() 建立合法快照。"
	)
	var lifecycle_owner: RefCounted = RefCounted.new()
	var options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.create(
		lifecycle_owner
	)
	assert_not_null(options, "默认 request options 必须可构造。")
	assert_true(options.is_valid())


func test_async_execution_mode_public_contract_is_frozen() -> void:
	var storage_script: GDScript = _load_gdscript(_STORAGE_UTILITY_SCRIPT_PATH)
	assert_not_null(storage_script)
	if storage_script == null:
		return
	var storage_constants: Dictionary = storage_script.get_script_constant_map()
	assert_eq(
		GFVariantData.get_option_dictionary(storage_constants, "AsyncExecutionMode"),
		{
			"AUTOMATIC": 0,
			"THREADED": 1,
			"COOPERATIVE": 2,
		},
		"AsyncExecutionMode 必须保持 automatic/threaded/cooperative 的稳定值。"
	)
	var plain_storage: GFStorageUtility = GFStorageUtility.new()
	assert_eq(
		plain_storage.async_execution_mode,
		GFStorageUtility.AsyncExecutionMode.AUTOMATIC,
		"默认执行模式必须是 AUTOMATIC。"
	)
	assert_true(
		plain_storage.has_method(&"has_async_thread_capability_for_framework"),
		"Storage 必须提供可覆盖的线程能力判定 seam。"
	)
	plain_storage.dispose()


func test_explicit_threaded_activation_fails_capability_check_before_cooperative_retry() -> void:
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.THREADED
	var threaded_activation: GFAsyncCompletion = storage.begin_activation(GFAsyncScope.new())
	assert_true(threaded_activation.is_failed())
	assert_eq(
		GFVariantData.get_option_int(threaded_activation.get_metadata(), "error_code", OK),
		ERR_CANT_CREATE
	)
	assert_eq(storage.thread_start_call_count, 0, "activation capability check 不得触达 worker seam。")

	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	var cooperative_activation: GFAsyncCompletion = storage.begin_activation(GFAsyncScope.new())
	assert_true(cooperative_activation.is_successful())
	assert_eq(storage.thread_start_call_count, 0)


func test_explicit_threaded_direct_use_fails_before_recovery_or_thread_start() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.THREADED
	var operation: GFStorageAsyncOperation = _request_save(
		"cooperative/threaded-direct-use.json",
		{ "generation": 1 },
		_new_options()
	)
	assert_not_null(operation)
	assert_push_error("Thread start failed")
	if operation == null:
		return
	_assert_physical_terminal(operation, "DOMAIN_RESULT", ERR_CANT_CREATE, false)
	assert_eq(
		operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.THREAD_START_FAILED
	)
	assert_eq(storage.recovery_call_count, 0, "缺少线程能力时不得先执行 transaction recovery。")
	assert_eq(storage.thread_start_call_count, 0, "缺少线程能力时不得触达 Thread.start seam。")
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_file_locks.is_empty())


func test_async_execution_mode_freezes_after_first_valid_async_queue() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	var operation: GFStorageAsyncOperation = _request_save(
		"cooperative/mode-freeze.json",
		{ "generation": 1 },
		_new_options()
	)
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_pending())
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.THREADED
	assert_push_error("[GFStorageUtility] async_execution_mode 已在首个异步请求后冻结。")
	assert_eq(
		storage.async_execution_mode,
		GFStorageUtility.AsyncExecutionMode.COOPERATIVE
	)
	assert_eq(storage.thread_start_call_count, 0)


func test_automatic_threadless_mode_runs_save_load_delete_without_starting_thread() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/round-trip.json"
	var descriptor: Dictionary = (
		_GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
			_storage_root_path,
			file_name
		)
	)
	var final_path: String = GFVariantData.get_option_string(descriptor, "payload_path")
	assert_false(final_path.is_empty())

	var save_operation: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "value": 17 },
		_new_options()
	)
	assert_not_null(save_operation)
	if save_operation == null:
		return
	assert_true(save_operation.is_pending(), "请求 API 内只能入 cooperative queue。")
	assert_eq(storage._async_queue.size(), 1)
	assert_true(storage._async_tasks.is_empty())
	assert_eq(storage.thread_start_call_count, 0, "AUTOMATIC fallback 不得调用 Thread.start seam。")
	assert_true(storage.callback_task_types.is_empty(), "请求 API 内不得同步执行 I/O。")
	assert_false(FileAccess.file_exists(final_path))

	storage.tick(0.0)
	assert_true(save_operation.is_pending(), "tick N 只能接纳 cooperative task。")
	assert_true(storage._async_queue.is_empty())
	assert_eq(storage._async_tasks.size(), 1)
	assert_true(storage.callback_task_types.is_empty(), "tick N 不得执行刚接纳的 task。")
	storage.tick(0.0)
	_assert_physical_terminal(save_operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(save_operation, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	assert_eq(storage.callback_task_types, [&"save"])
	assert_eq(storage.callback_main_thread_results, [true])
	assert_true(FileAccess.file_exists(final_path))

	var load_operation: GFStorageAsyncOperation = _request_load(file_name, _new_options())
	assert_not_null(load_operation)
	if load_operation == null:
		return
	assert_true(load_operation.is_pending())
	assert_eq(storage.callback_task_types, [&"save"])
	storage.tick(0.0)
	assert_true(load_operation.is_pending())
	assert_eq(storage.callback_task_types, [&"save"])
	storage.tick(0.0)
	_assert_physical_terminal(load_operation, "DOMAIN_RESULT", OK, true)
	var read_result: GFStorageReadResult = load_operation.get_result().get_read_result()
	assert_not_null(read_result)
	if read_result != null:
		assert_true(read_result.ok)
		assert_eq(GFVariantData.get_option_int(read_result.payload, "value", -1), 17)
	assert_eq(storage.callback_task_types, [&"save", &"load"])

	var delete_operation: GFStorageAsyncOperation = _request_delete(file_name, _new_options())
	assert_not_null(delete_operation)
	if delete_operation == null:
		return
	assert_true(delete_operation.is_pending())
	storage.tick(0.0)
	assert_true(delete_operation.is_pending())
	assert_eq(storage.callback_task_types, [&"save", &"load"])
	storage.tick(0.0)
	_assert_physical_terminal(delete_operation, "DOMAIN_RESULT", OK, true)
	assert_not_null(delete_operation.get_result().get_delete_result())
	assert_eq(storage.callback_task_types, [&"save", &"load", &"delete"])
	assert_eq(storage.callback_main_thread_results, [true, true, true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_false(FileAccess.file_exists(final_path))


func test_automatic_threadless_queued_cancel_is_physical_cancel_without_io() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/queued-cancel.json"
	var descriptor: Dictionary = (
		_GF_STORAGE_FAMILY_STORE_SCRIPT.make_family_descriptor_for_framework(
			_storage_root_path,
			file_name
		)
	)
	var final_path: String = GFVariantData.get_option_string(descriptor, "payload_path")
	var operation: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_pending())
	assert_eq(storage._async_queue.size(), 1)
	assert_true(storage._async_tasks.is_empty())
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(operation, physical_signal_count, caller_signal_count)

	assert_true(GFVariantData.to_bool(operation.call("cancel_observation")))
	_assert_physical_terminal(operation, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(operation, "PHYSICAL_SETTLED", "EXPLICIT_CANCEL")
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage.callback_task_types.is_empty())
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)
	storage.tick(0.0)
	storage.tick(0.0)
	assert_true(storage.callback_task_types.is_empty(), "接纳前取消不得迟到执行 I/O。")
	assert_false(FileAccess.file_exists(final_path))


func test_automatic_threadless_accepted_cancel_preserves_physical_and_same_file_lane() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.max_async_thread_count = 1
	var file_name: String = "cooperative/accepted-cancel.json"
	var primary: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	assert_not_null(primary)
	if primary == null:
		return
	storage.tick(0.0)
	assert_true(primary.is_pending(), "tick N 接纳后仍必须等待 cooperative execution。")
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_file_locks.size(), 1)
	assert_true(storage.callback_task_types.is_empty())

	assert_true(GFVariantData.to_bool(primary.call("cancel_observation")))
	_assert_caller_terminal(primary, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	assert_true(primary.is_pending(), "accepted save cancel 只能结束 caller 观察。")
	var follower: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(follower)
	if follower == null:
		return
	assert_true(follower.is_pending())
	assert_eq(storage._async_queue.size(), 1, "同文件 follower 必须等待 primary 物理终态。")
	assert_eq(storage._async_tasks.size(), 1)

	storage.tick(0.0)
	_assert_physical_terminal(primary, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(primary, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	assert_true(follower.is_pending())
	assert_eq(storage.callback_task_types, [&"save"])
	assert_eq(storage.saved_generations, [1])
	assert_eq(storage._async_tasks.size(), 1, "primary 结算后可接纳但不得同 tick 执行 follower。")
	assert_eq(storage._async_file_locks.size(), 1)

	storage.tick(0.0)
	_assert_physical_terminal(follower, "DOMAIN_RESULT", OK, true)
	assert_eq(storage.callback_task_types, [&"save", &"save"])
	assert_eq(storage.saved_generations, [1, 2])
	assert_eq(storage.callback_main_thread_results, [true, true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	var loaded: GFStorageReadResult = storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "generation", -1), 2)


func test_automatic_threadless_accepted_deadline_precedes_physical_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var manual_clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	assert_true(storage.set_async_clock_for_framework(manual_clock))
	var operation: GFStorageAsyncOperation = _request_save(
		"cooperative/deadline.json",
		{ "generation": 5 },
		_new_options(null, null, 10)
	)
	assert_not_null(operation)
	if operation == null:
		return
	storage.tick(0.0)
	assert_true(operation.is_pending())
	assert_true(_is_caller_pending(operation))
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_file_locks.size(), 1)
	assert_true(manual_clock.advance_msec(10))

	storage.tick(0.0)
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "DEADLINE_EXPIRED")
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_eq(storage.saved_generations, [5])
	assert_eq(storage.callback_main_thread_results, [true])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	var diagnostics: Array[Dictionary] = storage.get_late_settlement_diagnostics()
	assert_eq(diagnostics.size(), 1)
	if diagnostics.size() == 1:
		var diagnostic: Dictionary = diagnostics[0]
		assert_eq(
			GFVariantData.get_option_int(diagnostic, "caller_status"),
			_caller_status_value("OUTCOME_UNKNOWN")
		)
		assert_eq(
			GFVariantData.get_option_int(diagnostic, "caller_end_kind"),
			_caller_end_kind_value("DEADLINE_EXPIRED")
		)
		assert_true(GFVariantData.get_option_bool(diagnostic, "worker_accepted"))
		assert_true(GFVariantData.get_option_bool(diagnostic, "physical_ok"))


func test_automatic_threadless_same_file_fifo_executes_at_most_one_item_per_tick() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.max_async_thread_count = 4
	var file_name: String = "cooperative/fifo.json"
	var operations: Array[GFStorageAsyncOperation] = []
	var completion_order: Array[int] = []
	for generation: int in range(1, 4):
		var operation: GFStorageAsyncOperation = _request_save(
			file_name,
			{ "generation": generation },
			_new_options()
		)
		assert_not_null(operation)
		if operation == null:
			return
		operations.append(operation)
		var connect_error: Error = operation.completed.connect(
			Callable(self, &"_append_completed_request_id").bind(
				completion_order,
				operation.get_request_id()
			),
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		assert_eq(connect_error, OK)
	assert_eq(storage._async_queue.size(), 3)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage.callback_task_types.is_empty())

	storage.tick(0.0)
	assert_eq(storage.callback_task_types.size(), 0, "首 tick 只能接纳第一项。")
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_queue.size(), 2)
	storage.tick(0.0)
	assert_eq(storage.callback_task_types.size(), 1)
	assert_true(operations[0].is_completed())
	assert_true(operations[1].is_pending())
	assert_true(operations[2].is_pending())
	storage.tick(0.0)
	assert_eq(storage.callback_task_types.size(), 2)
	assert_true(operations[1].is_completed())
	assert_true(operations[2].is_pending())
	storage.tick(0.0)
	assert_eq(storage.callback_task_types.size(), 3)
	assert_true(operations[2].is_completed())

	for operation: GFStorageAsyncOperation in operations:
		_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_eq(
		completion_order,
		[
			operations[0].get_request_id(),
			operations[1].get_request_id(),
			operations[2].get_request_id(),
		]
	)
	assert_eq(storage.saved_generations, [1, 2, 3])
	assert_eq(storage.callback_main_thread_results, [true, true, true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	var loaded: GFStorageReadResult = storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "generation", -1), 3)


func test_automatic_threadless_quiesce_drains_accepted_work_without_threads() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var first: GFStorageAsyncOperation = _request_save(
		"cooperative/quiesce-first.json",
		{ "generation": 1 },
		_new_options()
	)
	var second: GFStorageAsyncOperation = _request_save(
		"cooperative/quiesce-second.json",
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var quiesce: GFAsyncCompletion = storage.begin_quiesce(GFAsyncScope.new())
	assert_false(quiesce.is_completed(), "尚有已接纳工作时 quiesce 必须等待。")
	for _tick_index: int in range(6):
		var callback_count_before: int = storage.callback_task_types.size()
		storage.tick(0.0)
		assert_lte(
			storage.callback_task_types.size() - callback_count_before,
			1,
			"cooperative executor 每 tick 最多执行一项。"
		)
		if quiesce.is_completed():
			break

	assert_true(quiesce.is_completed())
	assert_true(quiesce.is_successful())
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(second, "DOMAIN_RESULT", OK, true)
	assert_eq(storage.saved_generations, [1, 2])
	assert_eq(storage.callback_main_thread_results, [true, true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())


func test_automatic_threadless_wait_synchronously_drains_queued_work() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/wait-drain.json"
	var operation: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 7 },
		_new_options()
	)
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_pending())
	assert_eq(storage._async_queue.size(), 1)
	assert_true(storage._async_tasks.is_empty())

	storage.wait_for_async_tasks()
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_eq(storage.saved_generations, [7])
	assert_eq(storage.callback_main_thread_results, [true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	var loaded: GFStorageReadResult = storage.load_data(file_name)
	assert_true(loaded.ok)
	assert_eq(GFVariantData.get_option_int(loaded.payload, "generation", -1), 7)


func test_automatic_threadless_completion_wait_drains_before_deferred_dispose() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/completion-wait-drain.json"
	var first: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	var second: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var callback_state: Dictionary = {
		"count": 0,
		"second_completed_after_wait": false,
		"second_success_after_wait": false,
	}
	var callback: Callable = func(completed_file_name: String, error: Error) -> void:
		if completed_file_name != file_name or error != OK:
			return
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		if GFVariantData.get_option_int(callback_state, "count") != 1:
			return
		storage.wait_for_async_tasks()
		callback_state["second_completed_after_wait"] = second.is_completed()
		callback_state["second_success_after_wait"] = (
			second.is_completed()
			and second.get_result() != null
			and second.get_result().is_successful()
		)
		storage.dispose()
	var connect_error: Error = storage.save_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	storage.tick(0.0)
	assert_true(first.is_pending())
	assert_true(second.is_pending())
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_queue.size(), 1)
	storage.tick(0.0)

	if storage.save_completed.is_connected(callback):
		storage.save_completed.disconnect(callback)
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_completed_after_wait"
	), "completion signal 内的 wait 返回前必须排空剩余队列。")
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_success_after_wait"
	), "wait 已排空的 follower 不得被随后的 deferred dispose 取消。")
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 2)
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(second, "DOMAIN_RESULT", OK, true)
	assert_eq(storage.saved_generations, [1, 2])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._io_admission_open)


func test_automatic_threadless_operation_completion_wait_drains_before_dispose() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/operation-completion-wait-drain.json"
	var first: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	var second: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var callback_state: Dictionary = {
		"count": 0,
		"second_completed_after_wait": false,
		"second_success_after_wait": false,
	}
	var callback: Callable = func(_result: GFStorageAsyncResult) -> void:
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		storage.wait_for_async_tasks()
		callback_state["second_completed_after_wait"] = second.is_completed()
		callback_state["second_success_after_wait"] = (
			second.is_completed()
			and second.get_result() != null
			and second.get_result().is_successful()
		)
		storage.dispose()
	var connect_error: Error = first.completed.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)

	storage.tick(0.0)
	assert_true(first.is_pending())
	assert_true(second.is_pending())
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_queue.size(), 1)
	storage.tick(0.0)

	if first.completed.is_connected(callback):
		first.completed.disconnect(callback)
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1)
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_completed_after_wait"
	), "operation completed listener 内的 wait 返回前必须排空同文件 follower。")
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_success_after_wait"
	), "physical completion listener 重入 wait 后，follower 不得被 deferred dispose 取消。")
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(second, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(second, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	assert_eq(storage.saved_generations, [1, 2])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._async_deferred_dispose_requested)
	assert_false(storage._io_admission_open)


func test_automatic_threadless_deferred_dispose_prevents_completion_wait_acceptance() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	var file_name: String = "cooperative/dispose-before-completion-wait.json"
	var first: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	var second: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var callback_state: Dictionary = {
		"count": 0,
		"deferred_dispose_seen": false,
		"second_stayed_queued_after_wait": false,
	}
	var callback: Callable = func(completed_file_name: String, error: Error) -> void:
		if completed_file_name != file_name or error != OK:
			return
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		if GFVariantData.get_option_int(callback_state, "count") != 1:
			return
		storage.dispose()
		callback_state["deferred_dispose_seen"] = storage._async_deferred_dispose_requested
		storage.wait_for_async_tasks()
		callback_state["second_stayed_queued_after_wait"] = (
			second.is_pending()
			and storage._async_queue.size() == 1
			and storage._async_tasks.is_empty()
		)
	var connect_error: Error = storage.save_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	storage.tick(0.0)
	storage.tick(0.0)

	if storage.save_completed.is_connected(callback):
		storage.save_completed.disconnect(callback)
	assert_true(GFVariantData.get_option_bool(callback_state, "deferred_dispose_seen"))
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_stayed_queued_after_wait"
	), "deferred dispose 取得清理权后，重入 wait 不得再接纳 follower。")
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1)
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(second, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(second, "PHYSICAL_SETTLED", "UTILITY_DISPOSED")
	assert_eq(storage.saved_generations, [1])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._async_deferred_dispose_requested)
	assert_false(storage._io_admission_open)


func test_automatic_threadless_wait_rechecks_dispose_after_lifecycle_poll() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: DisposeDuringCooperativeWaitMaintenanceStorageUtility = (
		DisposeDuringCooperativeWaitMaintenanceStorageUtility.new()
	)
	_replace_storage_for_test(storage)
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	var file_name: String = "cooperative/dispose-during-wait-poll.json"
	var first: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	var second: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var callback_state: Dictionary = {
		"count": 0,
		"second_stayed_queued_after_wait": false,
	}
	var callback: Callable = func(completed_file_name: String, error: Error) -> void:
		if completed_file_name != file_name or error != OK:
			return
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		if GFVariantData.get_option_int(callback_state, "count") != 1:
			return
		storage.dispose_on_next_lifecycle_poll = true
		storage.wait_for_async_tasks()
		callback_state["second_stayed_queued_after_wait"] = (
			storage.dispose_invoked_during_poll
			and second.is_pending()
			and storage._async_queue.size() == 1
			and storage._async_tasks.is_empty()
		)
	var connect_error: Error = storage.save_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	storage.tick(0.0)
	storage.tick(0.0)

	if storage.save_completed.is_connected(callback):
		storage.save_completed.disconnect(callback)
	assert_true(storage.dispose_invoked_during_poll)
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"second_stayed_queued_after_wait"
	), "lifecycle poll 回调取得 dispose 权后，wait 必须在 start 前二次失败关闭。")
	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1)
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(second, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(second, "PHYSICAL_SETTLED", "UTILITY_DISPOSED")
	assert_eq(storage.saved_generations, [1])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._async_deferred_dispose_requested)
	assert_false(storage._io_admission_open)


func test_automatic_threadless_wait_stops_after_queued_deadline_requests_dispose() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: DeadlineDuringCooperativeWaitMaintenanceStorageUtility = (
		DeadlineDuringCooperativeWaitMaintenanceStorageUtility.new()
	)
	_replace_storage_for_test(storage)
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	var manual_clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	storage.manual_clock = manual_clock
	assert_true(storage.set_async_clock_for_framework(manual_clock))
	var file_name: String = "cooperative/dispose-during-start-poll.json"
	var first: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 1 },
		_new_options()
	)
	var deadline: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 2 },
		_new_options(null, null, 10)
	)
	var follower: GFStorageAsyncOperation = _request_save(
		file_name,
		{ "generation": 3 },
		_new_options()
	)
	assert_not_null(first)
	assert_not_null(deadline)
	assert_not_null(follower)
	if first == null or deadline == null or follower == null:
		return
	var callback_state: Dictionary = {
		"save_count": 0,
		"dispose_invoked": false,
		"follower_stayed_queued_after_wait": false,
	}
	var deadline_callback: Callable = func(_result: GFStorageAsyncResult) -> void:
		storage.dispose()
		callback_state["dispose_invoked"] = true
	var deadline_connect_error: Error = deadline.completed.connect(
		deadline_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(deadline_connect_error, OK)
	var save_callback: Callable = func(completed_file_name: String, error: Error) -> void:
		if completed_file_name != file_name or error != OK:
			return
		callback_state["save_count"] = (
			GFVariantData.get_option_int(callback_state, "save_count") + 1
		)
		if GFVariantData.get_option_int(callback_state, "save_count") != 1:
			return
		storage.advance_on_next_lifecycle_poll = true
		storage.wait_for_async_tasks()
		callback_state["follower_stayed_queued_after_wait"] = (
			follower.is_pending()
			and storage._async_queue.size() == 1
			and storage._async_tasks.is_empty()
		)
	var save_connect_error: Error = storage.save_completed.connect(save_callback) as Error
	assert_eq(save_connect_error, OK)

	storage.tick(0.0)
	storage.tick(0.0)

	if storage.save_completed.is_connected(save_callback):
		storage.save_completed.disconnect(save_callback)
	if deadline.completed.is_connected(deadline_callback):
		deadline.completed.disconnect(deadline_callback)
	assert_true(storage.deadline_advanced_during_poll)
	assert_true(GFVariantData.get_option_bool(callback_state, "dispose_invoked"))
	assert_true(GFVariantData.get_option_bool(
		callback_state,
		"follower_stayed_queued_after_wait"
	), "queued deadline 回调取得 dispose 权后，不得在同一次 start loop 接纳 follower。")
	assert_eq(GFVariantData.get_option_int(callback_state, "save_count"), 1)
	_assert_physical_terminal(first, "DOMAIN_RESULT", OK, true)
	_assert_physical_terminal(deadline, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(deadline, "PHYSICAL_SETTLED", "DEADLINE_EXPIRED")
	_assert_physical_terminal(follower, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(follower, "PHYSICAL_SETTLED", "UTILITY_DISPOSED")
	assert_eq(storage.saved_generations, [1])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._async_deferred_dispose_requested)
	assert_false(storage._io_admission_open)


func test_automatic_threadless_reentrant_same_file_wait_fails_busy_without_spinning() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: ReentrantCooperativeWaitStorageUtility = (
		ReentrantCooperativeWaitStorageUtility.new()
	)
	_replace_storage_for_test(storage)
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	storage.reentrant_file_name = "cooperative/reentrant-wait.json"
	var operation: GFStorageAsyncOperation = _request_save(
		storage.reentrant_file_name,
		{ "generation": 9 },
		_new_options()
	)
	assert_not_null(operation)
	if operation == null:
		return
	storage.tick(0.0)
	assert_true(operation.is_pending())
	storage.tick(0.0)
	assert_push_error("wait_for_async_tasks 不能在 Storage executor 同步执行栈内重入")
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_true(storage.reentrant_read_returned, "重入同步读取必须有界返回。")
	assert_not_null(storage.reentrant_read_result)
	if storage.reentrant_read_result != null:
		assert_false(storage.reentrant_read_result.ok)
		assert_eq(storage.reentrant_read_result.error_code, ERR_BUSY)
	assert_eq(storage.callback_task_types, [&"save"], "重入读取不得执行第二个 I/O callback。")
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_file_locks.is_empty())


func test_automatic_threadless_reentrant_dispose_waits_for_physical_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: ReentrantCooperativeDisposeStorageUtility = (
		ReentrantCooperativeDisposeStorageUtility.new()
	)
	_replace_storage_for_test(storage)
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	var operation: GFStorageAsyncOperation = _request_save(
		"cooperative/reentrant-dispose.json",
		{ "generation": 11 },
		_new_options()
	)
	assert_not_null(operation)
	if operation == null:
		return
	storage.tick(0.0)
	assert_true(operation.is_pending())
	assert_eq(storage._async_tasks.size(), 1)
	assert_eq(storage._async_file_locks.size(), 1)

	storage.tick(0.0)
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(operation, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	assert_true(storage.dispose_invoked)
	assert_true(storage.deferred_dispose_seen, "executor 回调内 dispose 必须延迟。")
	assert_true(storage.task_retained_after_dispose, "回调返回前不得清除 active task。")
	assert_true(storage.lock_retained_after_dispose, "回调返回前不得释放 exact family lock。")
	assert_eq(storage.saved_generations, [11])
	assert_eq(storage.callback_main_thread_results, [true])
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())
	assert_false(storage._async_deferred_dispose_requested)
	assert_false(storage._io_admission_open)


func test_automatic_threadless_dispose_executes_accepted_and_cancels_remaining_queue() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var storage: AutomaticCooperativeStorageUtility = _use_automatic_cooperative_storage()
	storage.max_async_thread_count = 1
	var active: GFStorageAsyncOperation = _request_save(
		"cooperative/dispose-active.json",
		{ "generation": 1 },
		_new_options()
	)
	assert_not_null(active)
	if active == null:
		return
	storage.tick(0.0)
	assert_true(active.is_pending())
	assert_eq(storage._async_tasks.size(), 1)
	assert_true(storage.callback_task_types.is_empty())
	var queued: GFStorageAsyncOperation = _request_save(
		"cooperative/dispose-queued.json",
		{ "generation": 2 },
		_new_options()
	)
	assert_not_null(queued)
	if queued == null:
		return
	assert_true(queued.is_pending())
	assert_eq(storage._async_queue.size(), 1)

	storage.dispose()
	_assert_physical_terminal(active, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(active, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	_assert_physical_terminal(queued, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(queued, "PHYSICAL_SETTLED", "UTILITY_DISPOSED")
	assert_eq(storage.saved_generations, [1])
	assert_eq(storage.callback_main_thread_results, [true])
	assert_eq(storage.thread_start_call_count, 0)
	assert_true(storage._async_tasks.is_empty())
	assert_true(storage._async_queue.is_empty())
	assert_true(storage._async_file_locks.is_empty())


func test_caller_result_enforces_operation_and_physical_settlement_union() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var domain_request_id: int = 701
	var domain_file_name: String = "caller-contract/domain.json"
	var domain_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(domain_result.configure_for_framework(
		domain_request_id,
		GFStorageAsyncOperation.OPERATION_SAVE,
		domain_file_name,
		true,
		OK
	))
	var cancelled_request_id: int = 702
	var cancelled_file_name: String = "caller-contract/cancelled.json"
	var cancelled_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	assert_true(cancelled_result.configure_cancelled_for_framework(
		cancelled_request_id,
		GFStorageAsyncOperation.OPERATION_SAVE,
		cancelled_file_name
	))

	var load_unknown: GFStorageAsyncCallerResult = GFStorageAsyncCallerResult.new()
	assert_false(load_unknown.configure_for_framework(
		801,
		801,
		GFStorageAsyncOperation.OPERATION_LOAD,
		"caller-contract/load.json",
		GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
		&"cancelled",
		100,
		ERR_BUSY
	), "load caller 不得声称持久化副作用未知。")

	var save_cancelled: GFStorageAsyncCallerResult = GFStorageAsyncCallerResult.new()
	assert_false(save_cancelled.configure_for_framework(
		802,
		802,
		GFStorageAsyncOperation.OPERATION_SAVE,
		"caller-contract/save.json",
		GFStorageAsyncCallerResult.Status.CANCELLED,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
		&"cancelled",
		100,
		ERR_SKIP
	), "active save caller 不得伪装成确定取消。")

	var domain_with_external_end: GFStorageAsyncCallerResult = (
		GFStorageAsyncCallerResult.new()
	)
	assert_false(domain_with_external_end.configure_for_framework(
		803,
		domain_request_id,
		GFStorageAsyncOperation.OPERATION_SAVE,
		domain_file_name,
		GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
		&"cancelled",
		100,
		OK,
		domain_result
	), "DOMAIN_RESULT 必须由 PHYSICAL_SETTLEMENT 结束 caller。")

	var cancelled_with_physical_end: GFStorageAsyncCallerResult = (
		GFStorageAsyncCallerResult.new()
	)
	assert_false(cancelled_with_physical_end.configure_for_framework(
		804,
		cancelled_request_id,
		GFStorageAsyncOperation.OPERATION_SAVE,
		cancelled_file_name,
		GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED,
		GFStorageAsyncCallerResult.EndKind.PHYSICAL_SETTLEMENT,
		&"physical_settlement",
		100,
		ERR_SKIP,
		cancelled_result
	), "接纳前 CANCELLED 必须保留真实外部 caller cause。")

	var queued_cancelled: GFStorageAsyncCallerResult = GFStorageAsyncCallerResult.new()
	assert_true(queued_cancelled.configure_for_framework(
		805,
		cancelled_request_id,
		GFStorageAsyncOperation.OPERATION_SAVE,
		cancelled_file_name,
		GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED,
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
		&"cancelled",
		100,
		ERR_SKIP,
		cancelled_result
	), "queued physical CANCELLED + EXPLICIT_CANCEL 必须是合法联合分支。")
	assert_eq(
		queued_cancelled.get_status(),
		GFStorageAsyncCallerResult.Status.PHYSICAL_SETTLED
	)
	assert_eq(
		queued_cancelled.get_end_kind(),
		GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL
	)
	assert_eq(
		queued_cancelled.get_physical_result().get_settlement_kind(),
		GFStorageAsyncResult.SettlementKind.CANCELLED
	)


func test_physical_cancel_marker_is_pre_acceptance_only_and_repeat_idempotent() -> void:
	var accepted_operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(accepted_operation.configure_for_framework(
		901,
		GFStorageAsyncOperation.OPERATION_SAVE,
		"marker/accepted.json"
	))
	assert_true(accepted_operation.mark_worker_accepted_for_framework())
	assert_false(
		accepted_operation.mark_physical_cancel_requested_for_framework(),
		"worker 接纳后不得再伪造接纳前物理取消。"
	)

	var queued_operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	assert_true(queued_operation.configure_for_framework(
		902,
		GFStorageAsyncOperation.OPERATION_SAVE,
		"marker/queued.json"
	))
	assert_true(queued_operation.mark_physical_cancel_requested_for_framework())
	assert_true(
		queued_operation.mark_physical_cancel_requested_for_framework(),
		"接纳前重复标记必须幂等返回已满足。"
	)
	assert_false(
		queued_operation.mark_worker_accepted_for_framework(),
		"物理取消标记后不得再接纳 worker。"
	)


func test_normal_physical_settlement_completes_both_terminals_exactly_once() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.block_next_worker = false
	var options: RefCounted = _new_options()
	var operation: GFStorageAsyncOperation = _request_save(
		"normal/result.json",
		{ "value": 7 },
		options
	)
	if operation == null:
		return
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(operation, physical_signal_count, caller_signal_count)

	assert_true(await _pump_until_physical_completed(operation))
	_assert_physical_terminal(
		operation,
		"DOMAIN_RESULT",
		OK,
		true
	)
	_assert_caller_terminal(
		operation,
		"PHYSICAL_SETTLED",
		"PHYSICAL_SETTLEMENT"
	)
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)
	_storage.tick(0.0)
	_storage.tick(0.0)
	assert_eq(physical_signal_count[0], 1, "physical completed 必须 exactly-once。")
	assert_eq(caller_signal_count[0], 1, "caller_completed 必须 exactly-once。")


func test_physical_listener_releasing_owner_suppresses_following_caller_signal() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var owner_box: Array[RefCounted] = [RefCounted.new()]
	var lifecycle_owner: RefCounted = owner_box[0]
	var owner_ref: WeakRef = weakref(lifecycle_owner)
	var options: RefCounted = _new_options(lifecycle_owner, null, 0, false)
	var operation: GFStorageAsyncOperation = _request_save(
		"owner/physical-listener.json",
		{ "value": 1 },
		options
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	options = null
	lifecycle_owner = null
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	var physical_connect_error: Error = operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			physical_signal_count[0] += 1
			owner_box.clear(),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var caller_connect_error: Error = operation.caller_completed.connect(
		func(_result: GFStorageAsyncCallerResult) -> void:
			caller_signal_count[0] += 1,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(physical_connect_error, OK)
	assert_eq(caller_connect_error, OK)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	assert_true(owner_ref.get_ref() == null, "physical listener 必须已释放 scoped owner。")
	assert_eq(physical_signal_count[0], 1)
	assert_eq(
		caller_signal_count[0],
		0,
		"completed listener 释放 owner 后，后续 caller_completed 必须被抑制。"
	)
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(
		operation,
		"PHYSICAL_SETTLED",
		"PHYSICAL_SETTLEMENT"
	)


func test_queued_explicit_cancel_is_true_cancel_before_worker_acceptance() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.max_async_thread_count = 1
	assert_eq(_storage.save_data("queued/target.json", { "keep": true }), OK)
	var blocker: GFStorageAsyncOperation = _request_save(
		"queued/blocker.json",
		{ "blocker": true },
		_new_options()
	)
	assert_not_null(blocker)
	assert_true(await _wait_for_worker_started(_storage))

	var queued: GFStorageAsyncOperation = _request_delete(
		"queued/target.json",
		_new_options()
	)
	if queued == null:
		return
	assert_eq(_storage._async_queue.size(), 1, "目标请求必须尚未被 worker 接纳。")
	assert_eq(_storage.worker_start_count, 1)
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(queued, physical_signal_count, caller_signal_count)

	var _first_cancel_result: Variant = queued.call("cancel_observation")
	var _repeated_cancel_result: Variant = queued.call("cancel_observation")
	assert_true(await _pump_until_physical_completed(queued))

	assert_true(_storage._async_queue.is_empty(), "真取消必须原子移除 queued task。")
	assert_eq(_storage.worker_start_count, 1, "被取消请求不得启动 worker。")
	_assert_physical_terminal(queued, "CANCELLED", ERR_SKIP, false)
	_assert_caller_terminal(
		queued,
		"PHYSICAL_SETTLED",
		"EXPLICIT_CANCEL"
	)
	var queued_result: GFStorageAsyncResult = queued.get_result()
	assert_null(queued_result.get_read_result())
	assert_null(queued_result.get_delete_result())
	assert_true(queued_result.get_write_validation_report().is_empty())
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	var preserved_result: GFStorageReadResult = _storage.load_data("queued/target.json")
	assert_true(preserved_result.ok, "接纳前取消不得触碰目标 family。")
	assert_true(GFVariantData.get_option_bool(preserved_result.payload, "keep"))


func test_active_save_cancel_keeps_file_lock_and_thread_slot_until_physical_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.max_async_thread_count = 1
	var operation: GFStorageAsyncOperation = _request_save(
		"active/shared.json",
		{ "generation": 1 },
		_new_options()
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(operation, physical_signal_count, caller_signal_count)

	var _first_cancel_result: Variant = operation.call("cancel_observation")
	var _repeated_cancel_result: Variant = operation.call("cancel_observation")
	assert_true(await _pump_until_caller_completed(operation))
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	assert_true(operation.is_pending(), "active save 的 physical 工作必须继续。")
	assert_false(operation.is_completed())
	assert_eq(_storage._async_tasks.size(), 1, "active save 必须继续占用线程槽。")
	assert_eq(_storage._async_file_locks.size(), 1, "active save 必须继续持有文件锁。")

	var same_file_follower: GFStorageAsyncOperation = _request_save(
		"active/shared.json",
		{ "generation": 2 },
		_new_options()
	)
	var other_file_follower: GFStorageAsyncOperation = _request_save(
		"active/other.json",
		{ "generation": 3 },
		_new_options()
	)
	assert_not_null(same_file_follower)
	assert_not_null(other_file_follower)
	assert_eq(_storage._async_queue.size(), 2, "线程槽与同文件锁均不得因 caller cancel 提前释放。")
	assert_eq(_storage.worker_start_count, 1)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_file_locks.is_empty())
	assert_true(_storage._async_queue.is_empty())


func test_reentrant_migration_keeps_same_file_follower_queued_until_primary_physical() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var migration_storage: GatedMigrationOrderingStorageUtility = (
		GatedMigrationOrderingStorageUtility.new()
	)
	_replace_storage_for_test(migration_storage)
	migration_storage.max_async_thread_count = 2
	var file_name: String = "reentrant/migration.json"
	migration_storage.save_version = 1
	assert_eq(
		migration_storage.save_data(file_name, { "generation": 1 }),
		OK,
		"迁移 fixture 必须先建立旧版本 committed family。"
	)
	migration_storage.save_version = 2
	migration_storage.migration_file_name = file_name
	var file_key: String = migration_storage._get_async_file_key(file_name)
	assert_false(file_key.is_empty())
	var migrated_signal_count: Array[int] = [0]
	var migrated_signal_saw_physical: Array[bool] = [false]
	var migrated_signal_saw_lock_released: Array[bool] = [false]
	var migrated_signal_versions: Array[int] = [-1, -1]
	var migration_storage_ref: WeakRef = weakref(migration_storage)
	var migrated_connect_error: Error = migration_storage.data_migrated.connect(
		func(
			_signaled_file_name: String,
			from_version: int,
			to_version: int
		) -> void:
			var observed_storage_value: Variant = migration_storage_ref.get_ref()
			if not observed_storage_value is GatedMigrationOrderingStorageUtility:
				return
			var observed_storage: GatedMigrationOrderingStorageUtility = (
				observed_storage_value
			)
			migrated_signal_count[0] += 1
			migrated_signal_versions[0] = from_version
			migrated_signal_versions[1] = to_version
			migrated_signal_saw_physical[0] = (
				observed_storage.primary_operation != null
				and observed_storage.primary_operation.is_completed()
			)
			migrated_signal_saw_lock_released[0] = (
				not observed_storage._async_file_locks.has(file_key)
			),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(migrated_connect_error, OK)

	var primary: GFStorageAsyncOperation = _request_load(
		file_name,
		_new_options()
	)
	if primary == null:
		return
	migration_storage.primary_operation = primary
	assert_true(await _wait_for_worker_started(migration_storage))

	migration_storage.release_for_test()
	assert_true(
		await _pump_until_worker_started(migration_storage),
		"primary settlement 后应启动同文件 follower。"
	)
	assert_eq(migration_storage.migration_call_count, 1)
	assert_true(
		migration_storage.migration_saw_primary_physical_pending,
		"migrate_data override 内 primary physical 必须仍为 pending。"
	)
	assert_true(
		migration_storage.migration_saw_original_lock_retained,
		"migrate_data override 内 original same-file lock 必须继续保留。"
	)
	assert_true(
		migration_storage.migration_saw_follower_queued,
		"override 内新建的 same-file follower 必须停留在 queue。"
	)
	assert_true(
		migration_storage.migration_saw_only_primary_worker_started,
		"same-file follower 不得在 migration override 内提前启动。"
	)
	assert_true(
		migration_storage.follower_start_saw_primary_physical_completed,
		"same-file follower 的 worker start 必须晚于 primary physical terminal。"
	)
	_assert_physical_terminal(primary, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(primary, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	var primary_read_result: GFStorageReadResult = primary.get_result().get_read_result()
	assert_not_null(primary_read_result)
	if primary_read_result != null:
		assert_true(primary_read_result.migrated)
		assert_true(
			GFVariantData.get_option_bool(
				primary_read_result.payload,
				"migration_applied"
			)
		)
	assert_eq(migrated_signal_count[0], 1)
	assert_eq(migrated_signal_versions, [1, 2])
	assert_true(
		migrated_signal_saw_physical[0],
		"data_migrated observer 必须看到已提交的 physical terminal。"
	)
	assert_true(
		migrated_signal_saw_lock_released[0],
		"data_migrated observer 必须看到 original file lock 已释放。"
	)
	var follower: GFStorageAsyncOperation = migration_storage.follower_operation
	assert_not_null(follower)
	if follower == null:
		return
	assert_true(follower.is_pending())
	assert_eq(migration_storage.worker_start_count, 2)
	assert_true(
		migration_storage._async_file_locks.has(file_key),
		"follower 启动后必须取得自己的 same-file lock。"
	)

	migration_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(follower, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(follower, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	assert_true(migration_storage._async_file_locks.is_empty())


func test_async_integrity_signal_observes_physical_terminal_and_released_file_lock() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.include_storage_metadata = true
	_storage.use_integrity_checksum = true
	_storage.strict_integrity = true
	var file_name: String = "signals/integrity.json"
	assert_eq(_storage.save_data(file_name, { "coins": 10 }), OK)
	var path: String = _storage._get_full_path(file_name)
	var document_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(document_value is Dictionary)
	if not document_value is Dictionary:
		return
	var document: Dictionary = document_value
	var tampered_payload: Dictionary = GFVariantData.get_option_dictionary(
		document,
		GFStorageCodec.PAYLOAD_KEY
	)
	tampered_payload["coins"] = 99
	document[GFStorageCodec.PAYLOAD_KEY] = tampered_payload
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	var _stored: bool = file.store_string(JSON.stringify(document))
	var write_error: Error = file.get_error()
	file.close()
	assert_eq(write_error, OK)
	var file_key: String = _storage._get_async_file_key(file_name)
	var operation: GFStorageAsyncOperation = _request_load(file_name, _new_options())
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	var integrity_signal_count: Array[int] = [0]
	var integrity_signal_saw_physical: Array[bool] = [false]
	var integrity_signal_saw_lock_released: Array[bool] = [false]
	var integrity_signal_error: Array[String] = [""]
	var operation_ref: WeakRef = weakref(operation)
	var storage_ref: WeakRef = weakref(_storage)
	var integrity_connect_error: Error = _storage.data_integrity_failed.connect(
		func(_signaled_file_name: String, error: String) -> void:
			var observed_operation_value: Variant = operation_ref.get_ref()
			var observed_storage_value: Variant = storage_ref.get_ref()
			if (
				not observed_operation_value is GFStorageAsyncOperation
				or not observed_storage_value is GatedWorkerStorageUtility
			):
				return
			var observed_operation: GFStorageAsyncOperation = observed_operation_value
			var observed_storage: GatedWorkerStorageUtility = observed_storage_value
			integrity_signal_count[0] += 1
			integrity_signal_error[0] = error
			integrity_signal_saw_physical[0] = observed_operation.is_completed()
			integrity_signal_saw_lock_released[0] = (
				not observed_storage._async_file_locks.has(file_key)
			),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(integrity_connect_error, OK)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", ERR_FILE_CORRUPT, false)
	_assert_caller_terminal(operation, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	var read_result: GFStorageReadResult = operation.get_result().get_read_result()
	assert_not_null(read_result)
	if read_result != null:
		assert_eq(
			read_result.integrity_status,
			GFStorageReadResult.IntegrityStatus.INVALID
		)
	assert_eq(integrity_signal_count[0], 1)
	assert_eq(integrity_signal_error[0], "Integrity checksum mismatch")
	assert_true(
		integrity_signal_saw_physical[0],
		"data_integrity_failed observer 必须看到已提交的 physical terminal。"
	)
	assert_true(
		integrity_signal_saw_lock_released[0],
		"data_integrity_failed observer 必须看到 exact file lock 已释放。"
	)


func test_late_ring_commits_current_request_before_completed_listener_runs() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var operation: GFStorageAsyncOperation = _request_save(
		"late-order/save.json",
		{ "value": 1 },
		_new_options()
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	assert_true(operation.cancel_observation(&"late_order_probe"))
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	var listener_saw_current_request: Array[bool] = [false]
	var listener_ring_size: Array[int] = [-1]
	var operation_ref: WeakRef = weakref(operation)
	var storage_ref: WeakRef = weakref(_storage)
	var physical_connect_error: Error = operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			var observed_operation_value: Variant = operation_ref.get_ref()
			var observed_storage_value: Variant = storage_ref.get_ref()
			if (
				not observed_operation_value is GFStorageAsyncOperation
				or not observed_storage_value is GatedWorkerStorageUtility
			):
				return
			var observed_operation: GFStorageAsyncOperation = observed_operation_value
			var observed_storage: GatedWorkerStorageUtility = observed_storage_value
			var diagnostics: Array[Dictionary] = (
				observed_storage.get_late_settlement_diagnostics()
			)
			listener_ring_size[0] = diagnostics.size()
			for diagnostic: Dictionary in diagnostics:
				if (
					GFVariantData.get_option_int(diagnostic, "request_id")
					== observed_operation.get_request_id()
				):
					listener_saw_current_request[0] = true
					break,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(physical_connect_error, OK)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	assert_true(
		listener_saw_current_request[0],
		"late diagnostic 必须 commit-before-notify，completed listener 应立即可读。"
	)
	assert_eq(listener_ring_size[0], 1)
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)


func test_active_save_deadline_uses_injected_manual_clock_without_stopping_physical_work() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var manual_clock: GFManualClock = GFManualClock.new(1_000_000, 1_700_000_000_000)
	var clock_result: Variant = _storage.call("set_async_clock_for_framework", manual_clock)
	assert_true(GFVariantData.to_bool(clock_result))
	var operation: GFStorageAsyncOperation = _request_save(
		"deadline/save.json",
		{ "value": "physical" },
		_new_options(null, null, 10)
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	assert_true(manual_clock.advance_msec(9))
	_storage.tick(0.0)
	assert_true(_is_caller_pending(operation), "deadline 前 caller 必须保持 pending。")
	assert_true(manual_clock.advance_msec(1))
	_storage.tick(0.0)
	assert_true(await _pump_until_caller_completed(operation))

	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "DEADLINE_EXPIRED")
	assert_true(operation.is_pending(), "deadline 只结束 caller，不得伪造 save 物理终态。")
	assert_eq(_storage._async_tasks.size(), 1)
	assert_eq(_storage._async_file_locks.size(), 1)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "DEADLINE_EXPIRED")


func test_owner_release_suppresses_caller_signal_but_keeps_queryable_terminal() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var lifecycle_owner: RefCounted = RefCounted.new()
	var owner_ref: WeakRef = weakref(lifecycle_owner)
	var options: RefCounted = _new_options(lifecycle_owner, null, 0, false)
	var operation: GFStorageAsyncOperation = _request_save(
		"owner/save.json",
		{ "value": 1 },
		options
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(operation, physical_signal_count, caller_signal_count)

	options = null
	lifecycle_owner = null
	assert_true(owner_ref.get_ref() == null, "Options 与 Operation 不得强持有 caller owner。")
	_storage.tick(0.0)
	assert_true(await _pump_until_caller_completed(operation))

	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "OWNER_RELEASED")
	assert_eq(caller_signal_count[0], 0, "owner 已释放时必须抑制 caller callback。")
	assert_true(operation.is_pending())
	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 0)


func test_active_load_token_cancel_ends_caller_but_preserves_physical_domain_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	assert_eq(_storage.save_data("token/load.json", { "value": "secret" }), OK)
	var source: GFCancellationSource = GFCancellationSource.new()
	var options: RefCounted = _new_options(null, source.get_token())
	var operation: GFStorageAsyncOperation = _request_load("token/load.json", options)
	if operation == null:
		source.dispose()
		return
	assert_true(await _wait_for_worker_started(_storage))
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	_connect_terminal_counters(operation, physical_signal_count, caller_signal_count)
	assert_true(
		source.cancel(&"lifecycle_token_cancelled", { "private_metadata": "not-diagnostic" })
	)
	_storage.tick(0.0)
	assert_true(await _pump_until_caller_completed(operation))

	_assert_caller_terminal(
		operation,
		"CANCELLED",
		"TOKEN_CANCELLED",
		&"lifecycle_token_cancelled"
	)
	assert_true(operation.is_pending(), "active load 必须等 worker 真实结算后才释放槽位。")
	assert_eq(_storage._async_tasks.size(), 1)
	assert_eq(_storage._async_file_locks.size(), 1)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_not_null(operation.get_result().get_read_result())
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)
	source.dispose()


func test_payload_attempt_survives_caller_terminal_until_physical_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var transfer: GFStoragePayloadTransfer = GFStoragePayloadTransfer.take_ownership({
		"payload": "retained-until-physical",
	})
	var operation: GFStorageAsyncOperation = _request_payload_save(
		"payload/save.json",
		transfer,
		_new_options()
	)
	if operation == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	assert_eq(transfer.get_active_attempt_count(), 1)
	assert_true(transfer.release())
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.RELEASE_PENDING)

	var _cancel_result: Variant = operation.call("cancel_observation")
	assert_true(await _pump_until_caller_completed(operation))
	_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
	assert_eq(transfer.get_active_attempt_count(), 1)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.RELEASE_PENDING)
	assert_eq(
		operation.get_payload_transfer(),
		transfer,
		"caller terminal 不得让 transfer attempt 冒充 physical terminal。"
	)

	_storage.release_for_test()
	assert_true(await _pump_until_storage_idle())
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	assert_eq(transfer.get_active_attempt_count(), 0)
	assert_eq(transfer.get_state(), GFStoragePayloadTransfer.State.RELEASED)
	assert_null(operation.get_payload_transfer())


func test_physical_first_reentrant_cancel_and_repeated_terminal_calls_are_idempotent() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.block_next_worker = false
	var operation: GFStorageAsyncOperation = _request_save(
		"race/physical-first.json",
		{ "value": 1 },
		_new_options()
	)
	if operation == null:
		return
	var physical_signal_count: Array[int] = [0]
	var caller_signal_count: Array[int] = [0]
	var reentrant_cancel_count: Array[int] = [0]
	var operation_ref: WeakRef = weakref(operation)
	var physical_connect_error: Error = operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			var observed_operation_value: Variant = operation_ref.get_ref()
			if not observed_operation_value is GFStorageAsyncOperation:
				return
			var observed_operation: GFStorageAsyncOperation = observed_operation_value
			physical_signal_count[0] += 1
			var _first_reentrant_result: Variant = (
				observed_operation.call("cancel_observation")
			)
			var _second_reentrant_result: Variant = (
				observed_operation.call("cancel_observation")
			)
			reentrant_cancel_count[0] += 2,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var caller_connect_error: Error = operation.connect(
		&"caller_completed",
		func(_result: Variant) -> void:
			caller_signal_count[0] += 1,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(physical_connect_error, OK)
	assert_eq(caller_connect_error, OK)

	assert_true(await _pump_until_physical_completed(operation))
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(
		operation,
		"PHYSICAL_SETTLED",
		"PHYSICAL_SETTLEMENT"
	)
	var _late_cancel_result: Variant = operation.call("cancel_observation")
	_storage.tick(0.0)
	assert_eq(reentrant_cancel_count[0], 2)
	assert_eq(physical_signal_count[0], 1)
	assert_eq(caller_signal_count[0], 1)


func test_dispose_inside_worker_start_override_preserves_tracking_until_settlement() -> void:
	if not _lifecycle_scenarios_ready():
		return
	var dispose_storage: StartedWorkerDisposeStorageUtility = (
		StartedWorkerDisposeStorageUtility.new()
	)
	_replace_storage_for_test(dispose_storage)
	var operation: GFStorageAsyncOperation = _request_save(
		"reentrant/worker-start-dispose.json",
		{ "value": 1 },
		_new_options()
	)
	if operation == null:
		return

	assert_eq(dispose_storage.override_call_count, 1)
	assert_true(
		dispose_storage.worker_started_before_dispose,
		"fixture 必须先真实启动 worker，再从 override 内调用 dispose。"
	)
	assert_true(dispose_storage.tracked_before_dispose)
	assert_true(
		dispose_storage.dispose_returned_inside_override,
		"worker-start reentrancy guard 必须让 dispose 延后并先返回 override。"
	)
	assert_true(
		dispose_storage.activation_failed_after_dispose,
		"deferred dispose 已请求后 begin_activation 必须失败。"
	)
	assert_true(
		dispose_storage.admission_stayed_closed_after_activation,
		"失败的 reentrant activation 不得重新打开 I/O admission。"
	)
	assert_true(
		dispose_storage.tracked_after_dispose,
		"override 内 dispose 返回后，已启动 worker 仍必须处于 Utility tracking。"
	)
	assert_true(
		dispose_storage.lock_retained_after_dispose,
		"override 内 dispose 不得提前清除已启动 worker 的 file lock。"
	)
	_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(operation, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	assert_true(dispose_storage._async_tasks.is_empty())
	assert_true(dispose_storage._async_queue.is_empty())
	assert_true(dispose_storage._async_file_locks.is_empty())
	var settling_records_value: Variant = dispose_storage.get("_async_settling_records")
	assert_true(settling_records_value is Dictionary)
	if settling_records_value is Dictionary:
		var settling_records: Dictionary = settling_records_value
		assert_true(settling_records.is_empty())


func test_dispose_cancels_queued_and_ends_active_caller_before_joining_worker() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.max_async_thread_count = 1
	assert_eq(_storage.save_data("dispose/queued.json", { "keep": true }), OK)
	var active: GFStorageAsyncOperation = _request_save(
		"dispose/active.json",
		{ "value": 1 },
		_new_options()
	)
	if active == null:
		return
	assert_true(await _wait_for_worker_started(_storage))
	var queued: GFStorageAsyncOperation = _request_delete(
		"dispose/queued.json",
		_new_options()
	)
	if queued == null:
		return
	assert_eq(_storage._async_queue.size(), 1)
	var active_physical_count: Array[int] = [0]
	var active_caller_count: Array[int] = [0]
	var queued_physical_count: Array[int] = [0]
	var queued_caller_count: Array[int] = [0]
	_connect_terminal_counters(active, active_physical_count, active_caller_count)
	_connect_terminal_counters(queued, queued_physical_count, queued_caller_count)

	_storage.release_for_test()
	_storage.dispose()

	_assert_caller_terminal(active, "PHYSICAL_SETTLED", "PHYSICAL_SETTLEMENT")
	_assert_physical_terminal(active, "DOMAIN_RESULT", OK, true)
	_assert_caller_terminal(queued, "PHYSICAL_SETTLED", "UTILITY_DISPOSED")
	_assert_physical_terminal(queued, "CANCELLED", ERR_SKIP, false)
	assert_eq(active_physical_count[0], 1)
	assert_eq(active_caller_count[0], 1)
	assert_eq(queued_physical_count[0], 1)
	assert_eq(queued_caller_count[0], 1)
	assert_true(_storage._async_tasks.is_empty())
	assert_true(_storage._async_queue.is_empty())
	assert_true(_storage._async_file_locks.is_empty())


func test_late_settlement_diagnostics_are_exact_payload_free_deep_copy_fifo_ring() -> void:
	if not _lifecycle_scenarios_ready():
		return
	_storage.max_async_thread_count = 1
	var payload_sentinel: String = "GF_PRIVATE_PAYLOAD_" + "x".repeat(16_384)
	for index: int in range(_LATE_DIAGNOSTIC_LIMIT + 1):
		_storage.arm_next_worker_gate_for_test()
		var file_name: String = "diagnostics/%02d.json" % index
		var operation: GFStorageAsyncOperation = _request_save(
			file_name,
			{ "secret": payload_sentinel },
			_new_options()
		)
		assert_not_null(operation)
		if operation == null:
			return
		assert_true(await _wait_for_worker_started(_storage))
		var _cancel_result: Variant = operation.call("cancel_observation")
		_storage.release_for_test()
		assert_true(await _pump_until_storage_idle())
		_assert_caller_terminal(operation, "OUTCOME_UNKNOWN", "EXPLICIT_CANCEL")
		_assert_physical_terminal(operation, "DOMAIN_RESULT", OK, true)

	var diagnostics: Array[Dictionary] = _get_late_settlement_diagnostics()
	assert_eq(diagnostics.size(), _LATE_DIAGNOSTIC_LIMIT, "Ring 必须只保留最近 64 条。")
	if diagnostics.size() != _LATE_DIAGNOSTIC_LIMIT:
		return
	var first_diagnostic: Dictionary = diagnostics.front()
	var last_diagnostic: Dictionary = diagnostics.back()
	assert_eq(
		GFVariantData.get_option_string(first_diagnostic, "file_name"),
		"diagnostics/01.json",
		"Ring 满载后必须按 FIFO 淘汰最旧条目。"
	)
	assert_eq(
		GFVariantData.get_option_string(last_diagnostic, "file_name"),
		"diagnostics/64.json"
	)

	for diagnostic: Dictionary in diagnostics:
		_assert_late_diagnostic_schema(diagnostic, payload_sentinel)

	diagnostics[0]["file_name"] = "tampered/by-caller.json"
	diagnostics.clear()
	var second_read: Array[Dictionary] = _get_late_settlement_diagnostics()
	assert_eq(second_read.size(), _LATE_DIAGNOSTIC_LIMIT, "调用方不得清空内部 ring。")
	var second_first_diagnostic: Dictionary = second_read.front()
	assert_eq(
		GFVariantData.get_option_string(second_first_diagnostic, "file_name"),
		"diagnostics/01.json",
		"返回值必须深复制，调用方不得篡改内部条目。"
	)


func _lifecycle_scenarios_ready() -> bool:
	if (
		not ResourceLoader.exists(_CALLER_RESULT_SCRIPT_PATH)
		or not ResourceLoader.exists(_REQUEST_OPTIONS_SCRIPT_PATH)
	):
		return false
	var request_options_script: GDScript = _load_gdscript(_REQUEST_OPTIONS_SCRIPT_PATH)
	if request_options_script == null or not request_options_script.has_method(&"create"):
		return false
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	for method_name: StringName in [
		&"is_caller_pending",
		&"is_caller_completed",
		&"get_caller_result",
		&"cancel_observation",
	]:
		if not operation.has_method(method_name):
			return false
	if not operation.has_signal(&"caller_completed"):
		return false
	var lifecycle_owner: RefCounted = RefCounted.new()
	var probe_options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.create(
		lifecycle_owner
	)
	if probe_options == null or not probe_options.is_valid():
		return false
	if (
		not GFStorageAsyncResult.new().has_method(&"get_settlement_kind")
		or not _storage.has_method(&"set_async_clock_for_framework")
		or not _storage.has_method(&"get_late_settlement_diagnostics")
	):
		return false
	return (
		_get_method_argument_count(_storage, &"save_data_request_async") == 3
		and _get_method_argument_count(_storage, &"save_payload_request_async") == 3
		and _get_method_argument_count(_storage, &"load_data_request_async") == 2
		and _get_method_argument_count(_storage, &"delete_file_request_async") == 2
	)


func _replace_storage_for_test(replacement: GatedWorkerStorageUtility) -> void:
	assert_not_null(replacement)
	if replacement == null:
		return
	if _storage != null:
		_storage.release_for_test()
		_storage.dispose()
	_storage = replacement
	_storage.save_dir_name = _save_dir_name
	_storage.encrypt_key = 0


func _use_automatic_cooperative_storage() -> AutomaticCooperativeStorageUtility:
	var storage: AutomaticCooperativeStorageUtility = AutomaticCooperativeStorageUtility.new()
	_replace_storage_for_test(storage)
	storage.async_execution_mode = GFStorageUtility.AsyncExecutionMode.AUTOMATIC
	return storage


func _append_completed_request_id(
	_result: GFStorageAsyncResult,
	target: Array[int],
	request_id: int
) -> void:
	target.append(request_id)


func _new_options(
	lifecycle_owner: Object = null,
	cancellation_token: GFCancellationToken = null,
	timeout_msec: int = 0,
	retain_lifecycle_owner: bool = true
) -> RefCounted:
	var actual_owner: Object = lifecycle_owner
	if actual_owner == null:
		actual_owner = RefCounted.new()
	if retain_lifecycle_owner and actual_owner is RefCounted:
		var retained_owner: RefCounted = actual_owner
		_retained_lifecycle_owners.append(retained_owner)
	var options: GFStorageAsyncRequestOptions = GFStorageAsyncRequestOptions.create(
		actual_owner,
		cancellation_token,
		timeout_msec
	)
	assert_not_null(options, "Request options create() 必须返回 typed snapshot。")
	assert_true(options.is_valid())
	if not options.is_valid():
		return null
	return options


func _request_save(
	file_name: String,
	data: Dictionary,
	options: RefCounted
) -> GFStorageAsyncOperation:
	assert_not_null(options)
	if options == null:
		return null
	var operation_value: Variant = _storage.call(
		"save_data_request_async",
		file_name,
		data,
		options
	)
	return _variant_to_operation(operation_value)


func _request_payload_save(
	file_name: String,
	transfer: GFStoragePayloadTransfer,
	options: RefCounted
) -> GFStorageAsyncOperation:
	assert_not_null(options)
	if options == null:
		return null
	var operation_value: Variant = _storage.call(
		"save_payload_request_async",
		file_name,
		transfer,
		options
	)
	return _variant_to_operation(operation_value)


func _request_load(
	file_name: String,
	options: RefCounted
) -> GFStorageAsyncOperation:
	assert_not_null(options)
	if options == null:
		return null
	var operation_value: Variant = _storage.call(
		"load_data_request_async",
		file_name,
		options
	)
	return _variant_to_operation(operation_value)


func _request_delete(
	file_name: String,
	options: RefCounted
) -> GFStorageAsyncOperation:
	assert_not_null(options)
	if options == null:
		return null
	var operation_value: Variant = _storage.call(
		"delete_file_request_async",
		file_name,
		options
	)
	return _variant_to_operation(operation_value)


func _variant_to_operation(value: Variant) -> GFStorageAsyncOperation:
	assert_true(value is GFStorageAsyncOperation, "Request API 必须返回 GFStorageAsyncOperation。")
	if value is GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = value
		return operation
	return null


func _connect_terminal_counters(
	operation: GFStorageAsyncOperation,
	physical_signal_count: Array[int],
	caller_signal_count: Array[int]
) -> void:
	var physical_connect_error: Error = operation.completed.connect(
		func(_result: GFStorageAsyncResult) -> void:
			physical_signal_count[0] += 1,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var caller_connect_error: Error = operation.connect(
		&"caller_completed",
		func(_result: Variant) -> void:
			caller_signal_count[0] += 1,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(physical_connect_error, OK)
	assert_eq(caller_connect_error, OK)


func _assert_physical_terminal(
	operation: GFStorageAsyncOperation,
	settlement_name: String,
	expected_error: Error,
	expected_success: bool
) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(operation.is_completed())
	assert_false(operation.is_pending())
	var result: GFStorageAsyncResult = operation.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_request_id(), operation.get_request_id())
	assert_eq(result.get_operation(), operation.get_operation())
	assert_eq(result.get_file_name(), operation.get_file_name())
	assert_eq(result.get_error_code(), expected_error)
	assert_eq(result.is_successful(), expected_success)
	assert_eq(
		_call_int(result, &"get_settlement_kind"),
		_async_settlement_value(settlement_name)
	)


func _assert_caller_terminal(
	operation: GFStorageAsyncOperation,
	status_name: String,
	end_kind_name: String,
	expected_reason: StringName = &""
) -> void:
	assert_not_null(operation)
	if operation == null:
		return
	assert_true(_is_caller_completed(operation))
	assert_false(_is_caller_pending(operation))
	var caller_result: RefCounted = _get_caller_result(operation)
	assert_not_null(caller_result)
	if caller_result == null:
		return
	assert_eq(_call_int(caller_result, &"get_status"), _caller_status_value(status_name))
	assert_eq(_call_int(caller_result, &"get_end_kind"), _caller_end_kind_value(end_kind_name))
	var caller_reason: StringName = _call_string_name(caller_result, &"get_reason")
	assert_false(caller_reason.is_empty(), "Caller terminal 必须携带稳定 StringName reason。")
	if not expected_reason.is_empty():
		assert_eq(caller_reason, expected_reason)


func _get_caller_result(operation: GFStorageAsyncOperation) -> RefCounted:
	var result_value: Variant = operation.call("get_caller_result")
	if result_value is RefCounted:
		var result: RefCounted = result_value
		return result
	return null


func _is_caller_pending(operation: GFStorageAsyncOperation) -> bool:
	return GFVariantData.to_bool(operation.call("is_caller_pending"))


func _is_caller_completed(operation: GFStorageAsyncOperation) -> bool:
	return GFVariantData.to_bool(operation.call("is_caller_completed"))


func _call_int(object_value: Object, method_name: StringName) -> int:
	assert_true(object_value.has_method(method_name), "%s 缺少 %s。" % [object_value, method_name])
	if not object_value.has_method(method_name):
		return -1
	var value: Variant = object_value.call(method_name)
	assert_true(value is int, "%s 必须返回 int enum。" % method_name)
	return value if value is int else -1


func _call_string_name(object_value: Object, method_name: StringName) -> StringName:
	assert_true(object_value.has_method(method_name), "%s 缺少 %s。" % [object_value, method_name])
	if not object_value.has_method(method_name):
		return &""
	var value: Variant = object_value.call(method_name)
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var string_value: String = value
		return StringName(string_value)
	assert_true(false, "%s 必须返回 StringName。" % method_name)
	return &""


func _caller_status_value(member_name: String) -> int:
	return _script_enum_value(_CALLER_RESULT_SCRIPT_PATH, "Status", member_name)


func _caller_end_kind_value(member_name: String) -> int:
	return _script_enum_value(_CALLER_RESULT_SCRIPT_PATH, "EndKind", member_name)


func _async_settlement_value(member_name: String) -> int:
	var script_value: Variant = GFStorageAsyncResult.new().get_script()
	assert_true(script_value is GDScript)
	if script_value is GDScript:
		var async_result_script: GDScript = script_value
		var constants: Dictionary = async_result_script.get_script_constant_map()
		var values: Dictionary = GFVariantData.get_option_dictionary(
			constants,
			"SettlementKind"
		)
		return GFVariantData.get_option_int(values, member_name, -1)
	return -1


func _script_enum_value(path: String, enum_name: String, member_name: String) -> int:
	var gdscript: GDScript = _load_gdscript(path)
	assert_not_null(gdscript)
	if gdscript == null:
		return -1
	var constants: Dictionary = gdscript.get_script_constant_map()
	var values: Dictionary = GFVariantData.get_option_dictionary(constants, enum_name)
	return GFVariantData.get_option_int(values, member_name, -1)


func _get_late_settlement_diagnostics() -> Array[Dictionary]:
	var diagnostics_value: Variant = _storage.call("get_late_settlement_diagnostics")
	assert_true(diagnostics_value is Array)
	if not diagnostics_value is Array:
		return []
	var untyped_diagnostics: Array = diagnostics_value
	var diagnostics: Array[Dictionary] = []
	for entry_value: Variant in untyped_diagnostics:
		assert_true(entry_value is Dictionary)
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			diagnostics.append(entry)
	return diagnostics


func _assert_late_diagnostic_schema(
	diagnostic: Dictionary,
	payload_sentinel: String
) -> void:
	var actual_keys: Array[String] = _dictionary_string_keys(diagnostic)
	var expected_keys: Array[String] = _LATE_DIAGNOSTIC_KEYS.duplicate()
	actual_keys.sort()
	expected_keys.sort()
	assert_eq(actual_keys, expected_keys, "Late diagnostic 必须使用 exact 29-key schema。")
	for value: Variant in diagnostic.values():
		assert_true(
			value is bool or value is int or value is String or value is StringName,
			"Late diagnostic 只能包含 fixed scalar。"
		)
	var serialized: String = JSON.stringify(diagnostic)
	assert_false(serialized.contains(payload_sentinel), "Late diagnostic 不得泄露 payload。")
	assert_lte(
		serialized.to_utf8_buffer().size(),
		_LATE_DIAGNOSTIC_MAX_JSON_BYTES,
		"单条 fixed scalar diagnostic 应自然保持有界。"
	)
	assert_gt(GFVariantData.get_option_int(diagnostic, "consumer_id"), 0)
	assert_gt(GFVariantData.get_option_int(diagnostic, "request_id"), 0)
	assert_eq(
		GFVariantData.get_option_string_name(diagnostic, "operation"),
		GFStorageAsyncOperation.OPERATION_SAVE
	)
	var file_name: String = GFVariantData.get_option_string(diagnostic, "file_name")
	assert_true(file_name.begins_with("diagnostics/"))
	assert_lte(file_name.length(), 255)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "caller_status"),
		_caller_status_value("OUTCOME_UNKNOWN")
	)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "caller_end_kind"),
		_caller_end_kind_value("EXPLICIT_CANCEL")
	)
	assert_false(
		GFVariantData.get_option_string_name(diagnostic, "caller_reason").is_empty()
	)
	assert_true(GFVariantData.get_option_bool(diagnostic, "worker_accepted"))
	assert_false(GFVariantData.get_option_bool(diagnostic, "physical_cancel_requested"))
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "settlement_kind"),
		_async_settlement_value("DOMAIN_RESULT")
	)
	assert_true(GFVariantData.get_option_bool(diagnostic, "physical_ok"))
	assert_eq(GFVariantData.get_option_int(diagnostic, "physical_error_code"), OK)
	assert_gte(GFVariantData.get_option_int(diagnostic, "caller_completed_msec"), 0)
	assert_gte(GFVariantData.get_option_int(diagnostic, "physical_completed_msec"), 0)
	assert_gte(GFVariantData.get_option_int(diagnostic, "late_duration_msec"), 0)
	assert_eq(GFVariantData.get_option_int(diagnostic, "read_failure_kind"), -1)
	assert_eq(
		GFVariantData.get_option_int(diagnostic, "write_failure_kind"),
		GFStorageAsyncResult.WriteFailureKind.NONE
	)
	for reset_key: String in [
		"reset_failure_kind",
		"reset_source_kind",
		"reset_failed_phase",
		"reset_retired_member_count",
		"reset_recreated_member_count",
		"reset_remaining_evidence_count",
		"reset_failed_member",
	]:
		assert_eq(GFVariantData.get_option_int(diagnostic, reset_key), -1)
	assert_eq(GFVariantData.get_option_int(diagnostic, "delete_failure_kind"), -1)
	assert_eq(GFVariantData.get_option_int(diagnostic, "delete_existing_member_count"), -1)
	assert_eq(GFVariantData.get_option_int(diagnostic, "delete_removed_member_count"), -1)
	assert_eq(GFVariantData.get_option_int(diagnostic, "delete_remaining_member_count"), -1)
	assert_eq(GFVariantData.get_option_int(diagnostic, "delete_failed_member"), -1)


func _dictionary_string_keys(dictionary: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key_value: Variant in dictionary.keys():
		if key_value is String:
			var string_key: String = key_value
			result.append(string_key)
		elif key_value is StringName:
			var string_name_key: StringName = key_value
			result.append(String(string_name_key))
		else:
			assert_true(false, "Diagnostic key 必须是 String/StringName。")
	return result


func _wait_for_worker_started(storage: GatedWorkerStorageUtility) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		if storage.worker_started.try_wait():
			return true
		await get_tree().process_frame
	return false


func _pump_until_worker_started(storage: GatedWorkerStorageUtility) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		if storage.worker_started.try_wait():
			return true
		await get_tree().process_frame
	return storage.worker_started.try_wait()


func _pump_until_caller_completed(operation: GFStorageAsyncOperation) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		if _is_caller_completed(operation):
			return true
		await get_tree().process_frame
	return _is_caller_completed(operation)


func _pump_until_physical_completed(operation: GFStorageAsyncOperation) -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		if operation.is_completed():
			return true
		await get_tree().process_frame
	return operation.is_completed()


func _pump_until_storage_idle() -> bool:
	for _frame_index: int in range(_PUMP_FRAME_LIMIT):
		_storage.tick(0.0)
		if _storage._async_tasks.is_empty() and _storage._async_queue.is_empty():
			return true
		await get_tree().process_frame
	return _storage._async_tasks.is_empty() and _storage._async_queue.is_empty()


func _assert_request_api_argument_count(method_name: StringName, expected_count: int) -> void:
	assert_true(_storage.has_method(method_name), "Storage 缺少 %s。" % method_name)
	if not _storage.has_method(method_name):
		return
	assert_eq(
		_get_method_argument_count(_storage, method_name),
		expected_count,
		"%s 必须追加冻结的 trailing options。" % method_name
	)


func _get_method_argument_count(object_value: Object, method_name: StringName) -> int:
	for method_value: Variant in object_value.get_method_list():
		if not method_value is Dictionary:
			continue
		var method_entry: Dictionary = method_value
		if GFVariantData.get_option_string_name(method_entry, "name") != method_name:
			continue
		var arguments_value: Variant = method_entry.get("args", [])
		if arguments_value is Array:
			var arguments: Array = arguments_value
			return arguments.size()
		return -1
	return -1


func _load_gdscript(path: String) -> GDScript:
	var resource_value: Variant = load(path)
	if resource_value is GDScript:
		var gdscript: GDScript = resource_value
		return gdscript
	return null


func _remove_owned_test_tree(path: String) -> Error:
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.include_hidden = true
	for file_name: String in directory.get_files():
		var remove_file_error: Error = DirAccess.remove_absolute(path.path_join(file_name))
		if remove_file_error != OK:
			return remove_file_error
	for directory_name: String in directory.get_directories():
		var child_path: String = path.path_join(directory_name)
		var remove_directory_error: Error = (
			DirAccess.remove_absolute(child_path)
			if directory.is_link(directory_name)
			else _remove_owned_test_tree(child_path)
		)
		if remove_directory_error != OK:
			return remove_directory_error
	directory = null
	return DirAccess.remove_absolute(path)
