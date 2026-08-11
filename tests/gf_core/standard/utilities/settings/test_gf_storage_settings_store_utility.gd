# 测试 GFStorageSettingsStoreUtility 的依赖声明、同步映射与释放语义。
extends GutTest


# --- 私有变量 ---

var _architectures: Array[GFArchitecture] = []


# --- GUT 生命周期方法 ---

func after_each() -> void:
	for architecture: GFArchitecture in _architectures:
		if is_instance_valid(architecture):
			architecture.dispose()
	_architectures.clear()


# --- 测试用例 ---

func test_adapter_declares_exact_storage_dependency() -> void:
	var adapter: GFStorageSettingsStoreUtility = GFStorageSettingsStoreUtility.new()
	var dependencies: Array[Script] = adapter.get_required_utilities()

	assert_eq(dependencies.size(), 1, "Storage adapter 应只声明一个物理依赖。")
	assert_same(dependencies[0], GFStorageUtility, "Storage adapter 必须声明 GFStorageUtility。")
	assert_false(adapter.is_persistence_enabled(), "ready 前不得宣称持久化可用。")


func test_ready_maps_sync_storage_and_release_restores_unavailable_results() -> void:
	var architecture: GFArchitecture = _new_architecture()
	var storage: RecordingStorageUtility = RecordingStorageUtility.new()
	var adapter: GFStorageSettingsStoreUtility = GFStorageSettingsStoreUtility.new()
	storage.read_result_for_test = GFStorageReadResult.new().configure_success({
		"volume": 0.75,
	})

	assert_true(await architecture.register_utility_instance(storage))
	assert_true(await architecture.register_utility_instance(adapter))
	assert_true(await architecture.init(), "测试架构应按依赖顺序完成 ready。")
	assert_true(adapter.is_persistence_enabled(), "ready 应缓存已完成生命周期的 Storage。")

	var file_name: String = "settings-%s.json" % GFUuid.generate_v4()
	var write_data: Dictionary = {
		"nested": { "value": 7 },
	}
	assert_eq(adapter.write_settings(file_name, write_data), OK)
	assert_eq(storage.last_write_file_name_for_test, file_name)
	var stored_nested: Dictionary = GFVariantData.get_option_dictionary(
		storage.last_write_data_for_test,
		"nested"
	)
	assert_eq(GFVariantData.get_option_int(stored_nested, "value"), 7)

	var read_result: GFStorageReadResult = adapter.read_settings(file_name)
	assert_true(read_result.ok)
	assert_eq(storage.last_read_file_name_for_test, file_name)
	assert_eq(GFVariantData.get_option_float(read_result.payload, "volume"), 0.75)
	assert_not_same(read_result, storage.read_result_for_test, "adapter 应隔离 Storage 读取结果。")

	adapter.release_dependencies()
	assert_false(adapter.is_persistence_enabled(), "释放依赖后必须清理 Storage 缓存。")
	var unavailable_result: GFStorageReadResult = adapter.read_settings(file_name)
	assert_false(unavailable_result.ok)
	assert_eq(unavailable_result.error_code, ERR_UNAVAILABLE)
	assert_eq(
		unavailable_result.failure_kind,
		GFStorageReadResult.FailureKind.UNAVAILABLE
	)
	assert_eq(adapter.write_settings(file_name, {}), ERR_UNAVAILABLE)


func test_architecture_shutdown_orders_settings_write_before_adapter_and_storage_quiesce() -> void:
	var architecture: GFArchitecture = _new_architecture()
	var lifecycle_events: Array[String] = []
	var storage: RecordingStorageUtility = RecordingStorageUtility.new()
	var adapter: RecordingStorageSettingsStoreUtility = (
		RecordingStorageSettingsStoreUtility.new()
	)
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	storage.lifecycle_events_for_test = lifecycle_events
	adapter.lifecycle_events_for_test = lifecycle_events
	settings.persistence_enabled = true
	settings.auto_load_on_init = false
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "shutdown-order.json"

	assert_true(await architecture.register_utility_instance(storage))
	assert_true(
		await architecture.register_utility_instance_as(adapter, GFSettingsStoreUtility)
	)
	assert_true(await architecture.register_utility_instance(settings))
	assert_true(await architecture.init())

	settings.set_value(&"shutdown/value", 53)
	assert_true(lifecycle_events.is_empty(), "防抖期间不得提前执行物理写入。")
	var shutdown_result: GFArchitectureShutdownResult = await architecture.shutdown_async()

	assert_true(shutdown_result.is_successful())
	assert_eq(
		lifecycle_events,
		[
			"settings_write",
			"adapter_quiesce",
			"storage_quiesce",
		],
		"真实 Architecture 必须按 Settings → Store adapter → Storage 排空。"
	)


# --- 私有/辅助方法 ---

func _new_architecture() -> GFArchitecture:
	var architecture: GFArchitecture = GFArchitecture.new()
	_architectures.append(architecture)
	return architecture


# --- 内部类 ---

class RecordingStorageSettingsStoreUtility extends GFStorageSettingsStoreUtility:
	var lifecycle_events_for_test: Array[String] = []

	func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
		lifecycle_events_for_test.append("adapter_quiesce")
		return super.begin_quiesce(scope)


class RecordingStorageUtility extends GFStorageUtility:
	var read_result_for_test: GFStorageReadResult = (
		GFStorageReadResult.new().configure_success({})
	)
	var last_read_file_name_for_test: String = ""
	var last_write_file_name_for_test: String = ""
	var last_write_data_for_test: Dictionary = {}
	var lifecycle_events_for_test: Array[String] = []

	func init() -> void:
		pass

	func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		lifecycle_events_for_test.append("storage_quiesce")
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _succeeded: bool = completion.succeed()
		return completion

	func dispose() -> void:
		super.dispose()

	func save_data(file_name: String, data: Dictionary) -> Error:
		lifecycle_events_for_test.append("settings_write")
		last_write_file_name_for_test = file_name
		last_write_data_for_test = data.duplicate(true)
		return OK

	func load_data(file_name: String) -> GFStorageReadResult:
		last_read_file_name_for_test = file_name
		return read_result_for_test
