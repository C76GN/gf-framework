# 测试 Settings Store 边界、激活加载与静默排空契约。
extends GutTest


# --- 常量 ---

const _SETTINGS_STORE_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/settings/gf_settings_store_utility.gd"
)
const _FILE_STORE_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/settings/gf_settings_file_store_utility.gd"
)
const _NULL_STORE_SCRIPT_PATH: String = (
	"res://addons/gf/standard/utilities/settings/gf_settings_null_store_utility.gd"
)
const _QUIESCE_FAILURE_METADATA_KEYS: Array[String] = [
	"error_codes",
	"failed_count",
	"failed_file_names",
	"pending_count",
	"pending_file_names",
]
const _RECORDING_STORE_SOURCE: String = """
extends "res://addons/gf/standard/utilities/settings/gf_settings_store_utility.gd"


var persistence_enabled_for_test: bool = true
var ready_for_test: bool = false
var read_saw_ready_for_test: bool = false
var read_result_for_test: GFStorageReadResult = GFStorageReadResult.new().configure_success({})
var write_error_for_test: Error = OK
var reset_write_error_after_call_for_test: bool = false
var read_calls_for_test: PackedStringArray = PackedStringArray()
var write_calls_for_test: Array[Dictionary] = []
var lifecycle_events_for_test: PackedStringArray = PackedStringArray()
var settings_for_test: Object = null
var mutation_key_for_test: StringName = &""
var mutation_value_for_test: Variant = null
var mutation_observed_value_for_test: Variant = null
var capability_calls_for_test: int = 0
var begin_quiesce_on_capability_for_test: bool = false
var capability_quiesce_completion_for_test: GFAsyncCompletion = null
var capability_quiesce_was_pending_for_test: bool = false
var dispose_on_capability_for_test: bool = false
var capability_dispose_requested_for_test: bool = false
var replacement_store_on_capability_for_test: Object = null
var replacement_owns_on_capability_for_test: bool = false
var capability_replacement_attempted_for_test: bool = false
var capability_replacement_error_for_test: Error = ERR_UNCONFIGURED
var dispose_on_read_for_test: bool = false
var read_dispose_requested_for_test: bool = false
var begin_quiesce_on_read_for_test: bool = false
var read_quiesce_completion_for_test: GFAsyncCompletion = null
var read_quiesce_was_pending_for_test: bool = false
var begin_quiesce_on_write_for_test: bool = false
var write_quiesce_completion_for_test: GFAsyncCompletion = null
var write_quiesce_was_pending_for_test: bool = false
var reentrant_store_on_dispose_for_test: Object = null
var reentrant_setter_error_on_dispose_for_test: Error = ERR_UNCONFIGURED
var begin_quiesce_on_dispose_for_test: bool = false
var dispose_quiesce_completion_for_test: GFAsyncCompletion = null
var dispose_quiesce_was_pending_for_test: bool = false
var dispose_settings_when_quiesce_completes_for_test: bool = false
var init_settings_when_quiesce_completes_for_test: bool = false
var quiesce_completion_action_connected_for_test: bool = false
var quiesce_completion_connect_error_for_test: Error = ERR_UNCONFIGURED
var dispose_settings_on_dispose_for_test: bool = false
var init_settings_on_dispose_for_test: bool = false
var settings_store_after_dispose_init_for_test: Object = null
var dispose_reentry_consumed_for_test: bool = false
var dispose_count_for_test: int = 0


func ready() -> void:
	ready_for_test = true
	var _appended: bool = lifecycle_events_for_test.append("store_ready")


func dispose() -> void:
	dispose_count_for_test += 1
	if dispose_reentry_consumed_for_test or settings_for_test == null:
		return
	if (
		reentrant_store_on_dispose_for_test == null
		and not begin_quiesce_on_dispose_for_test
		and not dispose_settings_on_dispose_for_test
		and not init_settings_on_dispose_for_test
	):
		return
	dispose_reentry_consumed_for_test = true
	if begin_quiesce_on_dispose_for_test:
		var completion_value: Variant = settings_for_test.call(
			&"begin_quiesce",
			GFAsyncScope.new()
		)
		if completion_value is GFAsyncCompletion:
			var completion: GFAsyncCompletion = completion_value
			dispose_quiesce_completion_for_test = completion
			dispose_quiesce_was_pending_for_test = completion.is_pending()
			_connect_quiesce_completion_action_for_test(completion)
	if reentrant_store_on_dispose_for_test != null:
		var setter_value: Variant = settings_for_test.call(
			&"set_settings_store_for_framework",
			reentrant_store_on_dispose_for_test,
			false
		)
		if setter_value is int:
			var setter_error: int = setter_value
			reentrant_setter_error_on_dispose_for_test = setter_error as Error
	if dispose_settings_on_dispose_for_test:
		var _dispose_result: Variant = settings_for_test.call(&"dispose")
	if init_settings_on_dispose_for_test:
		var _init_result: Variant = settings_for_test.call(&"init")
		settings_store_after_dispose_init_for_test = settings_for_test.get(&"_settings_store")


func is_persistence_enabled() -> bool:
	capability_calls_for_test += 1
	if (
		settings_for_test != null
		and begin_quiesce_on_capability_for_test
		and capability_quiesce_completion_for_test == null
	):
		var completion_value: Variant = settings_for_test.call(
			&"begin_quiesce",
			GFAsyncScope.new()
		)
		if completion_value is GFAsyncCompletion:
			var completion: GFAsyncCompletion = completion_value
			capability_quiesce_completion_for_test = completion
			capability_quiesce_was_pending_for_test = completion.is_pending()
			_connect_quiesce_completion_action_for_test(completion)
	if (
		settings_for_test != null
		and dispose_on_capability_for_test
		and not capability_dispose_requested_for_test
	):
		capability_dispose_requested_for_test = true
		var _dispose_result: Variant = settings_for_test.call(&"dispose")
	if (
		settings_for_test != null
		and replacement_store_on_capability_for_test != null
		and not capability_replacement_attempted_for_test
	):
		capability_replacement_attempted_for_test = true
		var replacement_error_value: Variant = settings_for_test.call(
			&"set_settings_store_for_framework",
			replacement_store_on_capability_for_test,
			replacement_owns_on_capability_for_test
		)
		if replacement_error_value is int:
			var replacement_error: int = replacement_error_value
			capability_replacement_error_for_test = replacement_error as Error
	return persistence_enabled_for_test


func read_settings(file_name: String) -> GFStorageReadResult:
	read_saw_ready_for_test = ready_for_test
	var _file_appended: bool = read_calls_for_test.append(file_name)
	var _event_appended: bool = lifecycle_events_for_test.append("read:" + file_name)
	if (
		settings_for_test != null
		and dispose_on_read_for_test
		and not read_dispose_requested_for_test
	):
		read_dispose_requested_for_test = true
		var _dispose_result: Variant = settings_for_test.call(&"dispose")
	if (
		settings_for_test != null
		and begin_quiesce_on_read_for_test
		and read_quiesce_completion_for_test == null
	):
		var completion_value: Variant = settings_for_test.call(
			&"begin_quiesce",
			GFAsyncScope.new()
		)
		if completion_value is GFAsyncCompletion:
			var completion: GFAsyncCompletion = completion_value
			read_quiesce_completion_for_test = completion
			read_quiesce_was_pending_for_test = completion.is_pending()
			_connect_quiesce_completion_action_for_test(completion)
	return read_result_for_test.duplicate_result()


func write_settings(file_name: String, data: Dictionary) -> Error:
	write_calls_for_test.append({
		"file_name": file_name,
		"data": data.duplicate(true),
	})
	var _event_appended: bool = lifecycle_events_for_test.append("write:" + file_name)
	if (
		settings_for_test != null
		and begin_quiesce_on_write_for_test
		and write_quiesce_completion_for_test == null
	):
		var completion_value: Variant = settings_for_test.call(
			&"begin_quiesce",
			GFAsyncScope.new()
		)
		if completion_value is GFAsyncCompletion:
			var completion: GFAsyncCompletion = completion_value
			write_quiesce_completion_for_test = completion
			write_quiesce_was_pending_for_test = completion.is_pending()
	if settings_for_test != null and mutation_key_for_test != &"":
		var _mutation_result: Variant = settings_for_test.call(
			"set_value",
			mutation_key_for_test,
			mutation_value_for_test,
			false
		)
		mutation_observed_value_for_test = settings_for_test.call(
			"get_value",
			mutation_key_for_test
		)
	var result: Error = write_error_for_test
	if reset_write_error_after_call_for_test:
		write_error_for_test = OK
		reset_write_error_after_call_for_test = false
	return result


func _connect_quiesce_completion_action_for_test(completion: GFAsyncCompletion) -> void:
	if (
		quiesce_completion_action_connected_for_test
		or (
			not dispose_settings_when_quiesce_completes_for_test
			and not init_settings_when_quiesce_completes_for_test
		)
	):
		return
	quiesce_completion_connect_error_for_test = completion.completed.connect(
		_on_quiesce_completed_for_test,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	quiesce_completion_action_connected_for_test = (
		quiesce_completion_connect_error_for_test == OK
	)


func _on_quiesce_completed_for_test(_completion: GFAsyncCompletion) -> void:
	if settings_for_test == null:
		return
	if init_settings_when_quiesce_completes_for_test:
		var _init_result: Variant = settings_for_test.call(&"init")
	if dispose_settings_when_quiesce_completes_for_test:
		var _dispose_result: Variant = settings_for_test.call(&"dispose")
"""


# --- 私有变量 ---

var _settings_instances: Array[GFSettingsUtility] = []
var _store_instances: Array[Object] = []
var _runtime_scripts: Array[GDScript] = []
var _owned_file_names: PackedStringArray = PackedStringArray()
var _architectures: Array[GFArchitecture] = []
var _previous_global_architecture: GFArchitecture = null
var _global_architecture_overridden: bool = false


# --- GUT 生命周期方法 ---

func after_each() -> void:
	_restore_global_architecture_for_test()

	for architecture: GFArchitecture in _architectures:
		architecture.dispose()
	_architectures.clear()

	for settings: GFSettingsUtility in _settings_instances:
		if is_instance_valid(settings):
			settings.dispose()
	_settings_instances.clear()

	for store: Object in _store_instances:
		if is_instance_valid(store) and store.has_method(&"dispose"):
			var _dispose_result: Variant = store.call(&"dispose")
	_store_instances.clear()

	for file_name: String in _owned_file_names:
		var path: String = "user://" + file_name
		if FileAccess.file_exists(path):
			var _remove_error: Error = DirAccess.remove_absolute(path)
	_owned_file_names.clear()

	for runtime_script: GDScript in _runtime_scripts:
		runtime_script.source_code = "extends RefCounted\n"
		var _cleanup_error: Error = runtime_script.reload(false)
	_runtime_scripts.clear()


# --- 测试用例 ---

func test_store_scripts_and_sync_port_surface_are_available() -> void:
	var expected_paths: PackedStringArray = PackedStringArray([
		_SETTINGS_STORE_SCRIPT_PATH,
		_FILE_STORE_SCRIPT_PATH,
		_NULL_STORE_SCRIPT_PATH,
	])
	for script_path: String in expected_paths:
		assert_true(
			ResourceLoader.exists(script_path),
			"Settings Store 类型脚本必须存在：%s。" % script_path
		)

	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(_script_has_method(store_script, &"is_persistence_enabled"))
	assert_true(_script_has_method(store_script, &"read_settings"))
	assert_true(_script_has_method(store_script, &"write_settings"))


func test_persistence_dependency_is_required_only_when_enabled() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null or not _require_property(settings, &"persistence_enabled"):
		return

	settings.set(&"persistence_enabled", true)
	var enabled_dependencies: Array = _call_array(settings, &"get_required_utilities")
	assert_true(
		enabled_dependencies.has(store_script),
		"启用持久化时必须声明 GFSettingsStoreUtility alias 依赖。"
	)

	settings.set(&"persistence_enabled", false)
	var disabled_dependencies: Array = _call_array(settings, &"get_required_utilities")
	assert_false(
		disabled_dependencies.has(store_script),
		"关闭持久化时不得保留 Store 生命周期依赖。"
	)


func test_disabled_persistence_activates_without_store_or_file_io() -> void:
	var settings: GFSettingsUtility = _new_settings()
	if not _require_property(settings, &"persistence_enabled"):
		return
	var file_name: String = _new_owned_file_name("memory-only")
	settings.set(&"persistence_enabled", false)
	settings.storage_file_name = file_name
	settings.auto_load_on_init = true
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.0
	settings.init()
	settings.ready()

	var activation: GFAsyncCompletion = _call_completion(settings, &"begin_activation")
	assert_not_null(activation)
	if activation == null:
		return
	assert_true(activation.is_successful(), "纯内存 Settings 应在没有 Store 时激活。")

	settings.set_value(&"runtime/value", 7)
	settings.tick(10.0)
	var quiesce: GFAsyncCompletion = _call_completion(settings, &"begin_quiesce")
	assert_not_null(quiesce)
	if quiesce != null:
		assert_true(quiesce.is_successful(), "纯内存 Settings 静默不应执行持久化。")
	assert_false(
		FileAccess.file_exists("user://" + file_name),
		"persistence_enabled=false 不得回退到 FileAccess。"
	)


func test_disabled_persistence_bypasses_overridden_read_hook() -> void:
	var settings: DisabledPersistenceReadProbe = DisabledPersistenceReadProbe.new()
	_settings_instances.append(settings)
	settings.persistence_enabled = false
	settings.auto_load_on_init = true
	settings.storage_file_name = "disabled-read-probe.json"

	settings.init()
	settings.ready()
	var activation: GFAsyncCompletion = settings.begin_activation(GFAsyncScope.new())
	assert_true(activation.is_successful())
	var load_result: GFSettingsLoadResult = settings.load_settings("disabled-explicit.json")

	assert_eq(
		settings.read_calls_for_test,
		0,
		"关闭持久化后，init、activation 与显式 load 都不得进入 protected read hook。"
	)
	assert_false(load_result.is_successful())
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_STORAGE_FAILED)
	assert_eq(load_result.get_error_code(), ERR_UNAVAILABLE)
	var storage_result: GFStorageReadResult = load_result.get_storage_result()
	assert_not_null(storage_result)
	if storage_result != null:
		assert_eq(storage_result.failure_kind, GFStorageReadResult.FailureKind.UNAVAILABLE)


func test_architecture_activation_loads_only_after_store_ready() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null or not _require_property(settings, &"persistence_enabled"):
		return
	settings.set(&"persistence_enabled", true)
	settings.storage_file_name = "activation.json"
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "loaded/value": 19 })
	)
	var architecture: GFArchitecture = _new_architecture()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(await architecture.register_utility_instance_as(store, store_script))
	assert_true(await architecture.register_utility_instance(settings))
	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test").size(),
		0,
		"架构初始化前不得读取 Store。"
	)

	assert_true(await architecture.init(), "Settings 架构应完成激活。")
	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test"),
		PackedStringArray(["activation.json"])
	)
	assert_true(
		_get_bool_property(store, &"read_saw_ready_for_test"),
		"activation load 必须发生在 Store ready 之后。"
	)
	assert_eq(GFVariantData.to_int(settings.get_value(&"loaded/value")), 19)


func test_store_read_quiesce_waits_for_load_commit_and_activation_stays_closed() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null:
		return
	settings.persistence_enabled = true
	settings.storage_file_name = "read-reentrant.json"
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	store.set(&"settings_for_test", settings)
	store.set(&"begin_quiesce_on_read_for_test", true)
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "loaded/reentrant": 41 })
	)

	var architecture: GFArchitecture = _new_architecture()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(await architecture.register_utility_instance_as(store, store_script))
	assert_true(await architecture.register_utility_instance(settings))
	assert_true(await architecture.init())

	assert_true(
		_get_bool_property(store, &"read_quiesce_was_pending_for_test"),
		"Store.read 内的 quiesce 必须等待已接纳 load critical section 收敛。"
	)
	var quiesce_value: Variant = store.get(&"read_quiesce_completion_for_test")
	assert_true(quiesce_value is GFAsyncCompletion)
	if quiesce_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = quiesce_value
		assert_true(quiesce.is_successful())
	var load_result: GFSettingsLoadResult = settings.get_last_load_result()
	assert_not_null(load_result)
	if load_result != null:
		assert_true(load_result.is_successful())
		assert_true(load_result.was_applied())
	assert_eq(
		GFVariantData.to_int(settings.get_value(&"loaded/reentrant")),
		41,
		"load 不得报告 applied 却在重入 quiesce 中丢弃载荷。"
	)

	settings.set_value(&"after/activation", 1, false)
	assert_false(
		settings.has_setting(&"after/activation"),
		"activation 返回前已开始的 quiesce 不得被 activation 重新打开准入。"
	)


func test_activation_quiesce_completion_dispose_cannot_publish_success() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null:
		return
	settings.persistence_enabled = true
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	store.set(&"settings_for_test", settings)
	store.set(&"begin_quiesce_on_capability_for_test", true)
	store.set(&"dispose_settings_when_quiesce_completes_for_test", true)

	var architecture: GFArchitecture = _new_architecture()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(await architecture.register_utility_instance_as(store, store_script))
	assert_true(await architecture.register_utility_instance(settings))
	assert_false(
		await architecture.init(),
		"activation critical exit 中 quiesce completion 已 dispose 时不得发布成功。"
	)
	assert_true(architecture.has_initialization_failed())
	assert_false(architecture.is_accepting_runtime_work())
	assert_false(architecture.is_module_active(settings))
	assert_push_error("[GFArchitecture] activation 失败")
	assert_true(
		_get_bool_property(store, &"capability_quiesce_was_pending_for_test"),
		"capability 回调内启动的 quiesce 必须等待 activation critical section。"
	)
	assert_eq(
		_get_error_property(store, &"quiesce_completion_connect_error_for_test"),
		OK
	)
	var completion_value: Variant = store.get(&"capability_quiesce_completion_for_test")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	assert_eq(_inject_store(settings, store), ERR_BUSY, "失败 activation 必须保持最终 disposed。")


func test_store_capability_and_read_dispose_fail_activation_closed() -> void:
	var callback_kinds: Array[StringName] = [&"capability", &"read"]
	for callback_kind: StringName in callback_kinds:
		var settings: GFSettingsUtility = _new_settings()
		var store: Object = _new_recording_store()
		if store == null:
			return
		settings.persistence_enabled = true
		settings.storage_file_name = "dispose-%s.json" % String(callback_kind)
		settings.auto_load_on_init = callback_kind == &"read"
		settings.auto_save_on_change = false
		store.set(&"settings_for_test", settings)
		store.set(
			&"read_result_for_test",
			GFStorageReadResult.new().configure_success({ "loaded/value": 53 })
		)
		store.set(&"dispose_on_capability_for_test", callback_kind == &"capability")
		store.set(&"dispose_on_read_for_test", callback_kind == &"read")

		var architecture: GFArchitecture = _new_architecture()
		var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
		assert_not_null(store_script)
		if store_script == null:
			return
		assert_true(await architecture.register_utility_instance_as(store, store_script))
		assert_true(await architecture.register_utility_instance(settings))
		assert_false(
			await architecture.init(),
			"Store %s 回调请求 dispose 后 activation 必须失败。" % callback_kind
		)
		assert_true(architecture.has_initialization_failed())
		assert_false(architecture.is_accepting_runtime_work())
		assert_false(architecture.is_module_active(settings))
		assert_push_error("[GFArchitecture] activation 失败")

		settings.set_value(&"after/dispose", 1, false)
		assert_false(
			settings.has_setting(&"after/dispose"),
			"dispose 请求收敛后不得重开 Settings mutation admission。"
		)
		assert_eq(
			_inject_store(settings, store),
			ERR_BUSY,
			"activation 失败后 Settings 必须保持最终 disposed。"
		)


func test_explicit_load_read_dispose_cannot_publish_applied_success() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.storage_file_name = "explicit-read-dispose.json"
	store.set(&"settings_for_test", settings)
	store.set(&"dispose_on_read_for_test", true)
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "disposed/read": 59 })
	)
	var signal_state: Dictionary = {
		"total_count": 0,
		"success_or_applied_count": 0,
	}
	var callback: Callable = func(result: GFSettingsLoadResult) -> void:
		signal_state["total_count"] = (
			GFVariantData.get_option_int(signal_state, "total_count") + 1
		)
		if result.is_successful() or result.was_applied():
			signal_state["success_or_applied_count"] = (
				GFVariantData.get_option_int(signal_state, "success_or_applied_count") + 1
			)
	var connect_error: Error = settings.settings_load_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	var load_result: GFSettingsLoadResult = settings.load_settings()
	if settings.settings_load_completed.is_connected(callback):
		settings.settings_load_completed.disconnect(callback)

	assert_false(load_result.is_successful())
	assert_false(load_result.was_applied())
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_STORAGE_FAILED)
	assert_eq(load_result.get_error_code(), ERR_UNAVAILABLE)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "total_count"),
		0,
		"read 回调先请求 dispose 后不得发布任何 load completion signal。"
	)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "success_or_applied_count"),
		0,
		"read 回调先请求 dispose 后不得发布 successful/applied load 终态。"
	)
	assert_null(settings.get_last_load_result(), "dispose-first load 不得提交 last-load 状态。")
	assert_false(settings.has_setting(&"disposed/read"), "dispose-first load 不得应用读取载荷。")
	assert_eq(_inject_store(settings, store), ERR_BUSY, "显式 load 返回时必须已收敛 disposed。")


func test_recovery_policy_dispose_stops_load_before_store_io() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.storage_file_name = "policy-dispose.json"
	var policy: DisposingRecoveryPolicy = DisposingRecoveryPolicy.new()
	policy.settings_for_test = settings
	var signal_state: Dictionary = {
		"total_count": 0,
		"success_or_applied_count": 0,
	}
	var callback: Callable = func(result: GFSettingsLoadResult) -> void:
		signal_state["total_count"] = (
			GFVariantData.get_option_int(signal_state, "total_count") + 1
		)
		if result.is_successful() or result.was_applied():
			signal_state["success_or_applied_count"] = (
				GFVariantData.get_option_int(signal_state, "success_or_applied_count") + 1
			)
	var connect_error: Error = settings.settings_load_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	var load_result: GFSettingsLoadResult = settings.load_settings("", policy)
	if settings.settings_load_completed.is_connected(callback):
		settings.settings_load_completed.disconnect(callback)

	assert_eq(policy.validate_calls_for_test, 1)
	assert_true(
		_get_packed_string_array(store, &"read_calls_for_test").is_empty(),
		"RecoveryPolicy 回调先请求 dispose 后不得开始 Store read。"
	)
	assert_false(load_result.is_successful())
	assert_false(load_result.was_applied())
	assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_STORAGE_FAILED)
	assert_eq(load_result.get_error_code(), ERR_UNAVAILABLE)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "total_count"),
		0,
		"dispose-first policy validation 不得发布任何 load completion signal。"
	)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "success_or_applied_count"),
		0,
		"dispose-first policy validation 不得发布 successful/applied load 终态。"
	)
	assert_null(settings.get_last_load_result(), "dispose-first policy validation 不得提交 last-load。")
	assert_eq(_inject_store(settings, store), ERR_BUSY, "load 返回时必须已收敛 disposed。")


func test_standalone_init_capability_callback_cannot_replace_admitted_store() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var admitted_store: Object = _new_recording_store()
	var replacement_store: Object = _new_recording_store()
	if admitted_store == null or replacement_store == null:
		return
	settings.persistence_enabled = true
	settings.storage_file_name = "standalone-capability-identity.json"
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	admitted_store.set(&"settings_for_test", settings)
	admitted_store.set(&"replacement_store_on_capability_for_test", replacement_store)
	admitted_store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "store/source": "admitted" })
	)
	replacement_store.set(&"persistence_enabled_for_test", false)
	replacement_store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "store/source": "replacement" })
	)
	assert_eq(_inject_store(settings, admitted_store), OK)
	var _admitted_ready_result: Variant = admitted_store.call(&"ready")
	var _replacement_ready_result: Variant = replacement_store.call(&"ready")

	settings.init()

	assert_eq(
		_get_error_property(
			admitted_store,
			&"capability_replacement_error_for_test"
		),
		ERR_BUSY,
		"standalone capability 回调不得替换本次 admission 已绑定的 Store。"
	)
	assert_eq(
		_get_packed_string_array(admitted_store, &"read_calls_for_test"),
		PackedStringArray(["standalone-capability-identity.json"]),
		"capability 与 load 必须保持同一 admitted Store 身份。"
	)
	assert_true(
		_get_packed_string_array(replacement_store, &"read_calls_for_test").is_empty(),
		"被拒绝的 replacement Store 不得接收本次物理读取。"
	)
	assert_eq(GFVariantData.to_text(settings.get_value(&"store/source")), "admitted")


func test_standalone_init_preserves_legacy_auto_load_without_activation_duplicate() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null or not _require_property(settings, &"persistence_enabled"):
		return
	settings.set(&"persistence_enabled", true)
	settings.storage_file_name = "standalone.json"
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "standalone/value": 29 })
	)
	if _inject_store(settings, store) != OK:
		return
	var _store_ready_result: Variant = store.call(&"ready")

	settings.init()
	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test"),
		PackedStringArray(["standalone.json"]),
		"standalone init 必须保留历史 auto-load 入口。"
	)
	assert_eq(GFVariantData.to_int(settings.get_value(&"standalone/value")), 29)
	var activation: GFAsyncCompletion = _call_completion(settings, &"begin_activation")
	assert_not_null(activation)
	if activation != null:
		assert_true(activation.is_successful())
	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test").size(),
		1,
		"standalone activation 不得重复 init 已完成的读取。"
	)


func test_quiesce_completion_init_does_not_reload_or_reopen_admission() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_load_on_init = true
	settings.storage_file_name = "quiesce-completed-init.json"
	store.set(&"settings_for_test", settings)
	store.set(&"begin_quiesce_on_read_for_test", true)
	store.set(&"init_settings_when_quiesce_completes_for_test", true)
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "quiesce/init": 61 })
	)
	var signal_state: Dictionary = { "total_count": 0 }
	var callback: Callable = func(_result: GFSettingsLoadResult) -> void:
		signal_state["total_count"] = (
			GFVariantData.get_option_int(signal_state, "total_count") + 1
		)
	var connect_error: Error = settings.settings_load_completed.connect(callback) as Error
	assert_eq(connect_error, OK)

	var load_result: GFSettingsLoadResult = settings.load_settings()
	if settings.settings_load_completed.is_connected(callback):
		settings.settings_load_completed.disconnect(callback)

	assert_true(load_result.is_successful())
	assert_true(load_result.was_applied())
	assert_eq(GFVariantData.to_int(settings.get_value(&"quiesce/init")), 61)
	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test"),
		PackedStringArray(["quiesce-completed-init.json"]),
		"quiesce 已终结后 completion callback 重入 init 不得重复 Store read。"
	)
	assert_eq(
		GFVariantData.get_option_int(signal_state, "total_count"),
		1,
		"completion callback 重入 init 不得发布第二个 load terminal。"
	)
	assert_true(_get_bool_property(store, &"read_quiesce_was_pending_for_test"))
	assert_eq(
		_get_error_property(store, &"quiesce_completion_connect_error_for_test"),
		OK
	)
	var completion_value: Variant = store.get(&"read_quiesce_completion_for_test")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	settings.set_value(&"quiesce/after_init", 67, false)
	assert_false(
		settings.has_setting(&"quiesce/after_init"),
		"terminal quiesce callback 重入 init 不得重新打开 mutation admission。"
	)


func test_store_setter_accepts_standalone_pre_activation_and_rejects_architecture_post_init() -> void:
	var standalone_settings: GFSettingsUtility = _new_settings()
	var standalone_store: Object = _new_recording_store()
	if standalone_store == null:
		return
	standalone_settings.persistence_enabled = true
	standalone_settings.auto_load_on_init = false
	standalone_settings.init()
	assert_eq(
		_inject_store(standalone_settings, standalone_store),
		OK,
		"standalone init 后、activation 前仍应允许替换 Store。"
	)

	var architecture_settings: GFSettingsUtility = _new_settings()
	var architecture_store: Object = _new_recording_store()
	var replacement_store: Object = _new_recording_store()
	if architecture_store == null or replacement_store == null:
		return
	architecture_settings.persistence_enabled = true
	architecture_settings.auto_load_on_init = false
	var architecture: GFArchitecture = _new_architecture()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(
		await architecture.register_utility_instance_as(architecture_store, store_script)
	)
	assert_true(await architecture.register_utility_instance(architecture_settings))
	assert_true(await architecture.init())
	assert_eq(
		_inject_store(architecture_settings, replacement_store),
		ERR_BUSY,
		"Architecture init 后 Store binding 必须保持冻结。"
	)


func test_unbound_standalone_settings_ignores_unrelated_global_architecture() -> void:
	var unrelated_architecture: GFArchitecture = _new_architecture()
	_override_global_architecture_for_test(unrelated_architecture)
	assert_same(GFAutoload.get_architecture_or_null(), unrelated_architecture)

	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null:
		return
	settings.persistence_enabled = true
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	settings.storage_file_name = "standalone-with-unrelated-global.json"
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "standalone/global": 97 })
	)

	var setter_error: Error = _inject_store(settings, store)
	assert_eq(
		setter_error,
		OK,
		"未 inject_dependencies 的 standalone Settings 不得继承无关全局 Architecture。"
	)
	var _store_ready_result: Variant = store.call(&"ready")
	settings.init()

	assert_eq(
		_get_packed_string_array(store, &"read_calls_for_test"),
		PackedStringArray(["standalone-with-unrelated-global.json"]),
		"standalone init 必须继续使用显式注入的 Store。"
	)
	assert_eq(GFVariantData.to_int(settings.get_value(&"standalone/global")), 97)


func test_owned_store_dispose_reentry_is_atomic_and_mounted_binding_is_frozen() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var owned_store: Object = _new_recording_store()
	var replacement_store: Object = _new_recording_store()
	var reentrant_store: Object = _new_recording_store()
	if owned_store == null or replacement_store == null or reentrant_store == null:
		return
	assert_eq(_inject_store(settings, owned_store, true), OK)
	owned_store.set(&"settings_for_test", settings)
	owned_store.set(&"reentrant_store_on_dispose_for_test", reentrant_store)
	owned_store.set(&"dispose_settings_on_dispose_for_test", true)

	var outer_error: Error = _inject_store(settings, replacement_store)
	assert_eq(
		_get_error_property(owned_store, &"reentrant_setter_error_on_dispose_for_test"),
		ERR_BUSY,
		"owned Store dispose 回调不得抢占正在提交的 replacement。"
	)
	assert_eq(
		outer_error,
		ERR_BUSY,
		"replacement 内发生 reentrant dispose 时 outer setter 不得误报 OK。"
	)
	assert_eq(_get_int_property(owned_store, &"dispose_count_for_test"), 1)
	assert_eq(
		_inject_store(settings, replacement_store),
		ERR_BUSY,
		"reentrant dispose 收敛后 Store binding 必须保持最终冻结。"
	)
	settings.set_value(&"after/reentrant-dispose", 1, false)
	assert_false(settings.has_setting(&"after/reentrant-dispose"))

	var mounted_settings: GFSettingsUtility = _new_settings()
	var mounted_store: Object = _new_recording_store()
	if mounted_store == null:
		return
	var architecture: GFArchitecture = _new_architecture()
	assert_true(await architecture.register_utility_instance(mounted_settings))
	assert_eq(
		_inject_store(mounted_settings, mounted_store),
		ERR_BUSY,
		"Utility 挂载 Architecture 后即应冻结 Store binding，不得等到 init。"
	)


func test_owned_store_dispose_init_cannot_resurrect_store_binding() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var owned_store: Object = _new_recording_store()
	if owned_store == null:
		return
	settings.persistence_enabled = true
	settings.auto_load_on_init = true
	assert_eq(_inject_store(settings, owned_store, true), OK)
	owned_store.set(&"settings_for_test", settings)
	owned_store.set(&"init_settings_on_dispose_for_test", true)

	settings.dispose()

	assert_eq(_get_int_property(owned_store, &"dispose_count_for_test"), 1)
	assert_true(
		owned_store.get(&"settings_store_after_dispose_init_for_test") == null,
		"owned Store.dispose 回调重入 init 不得在 disposed Settings 上复活 FileStore。"
	)
	assert_true(settings.get(&"_settings_store") == null, "disposed Settings 必须保持空 Store binding。")
	assert_true(_get_packed_string_array(owned_store, &"read_calls_for_test").is_empty())
	assert_true(_get_array_property(owned_store, &"write_calls_for_test").is_empty())
	assert_eq(_inject_store(settings, owned_store, true), ERR_BUSY)


func test_owned_store_dispose_quiesce_preserves_committed_replacement_result() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var owned_store: Object = _new_recording_store()
	var replacement_store: Object = _new_recording_store()
	if owned_store == null or replacement_store == null:
		return
	assert_eq(_inject_store(settings, owned_store, true), OK)
	owned_store.set(&"settings_for_test", settings)
	owned_store.set(&"begin_quiesce_on_dispose_for_test", true)

	var outer_error: Error = _inject_store(settings, replacement_store, true)
	assert_eq(_get_int_property(owned_store, &"dispose_count_for_test"), 1)
	assert_true(
		_get_bool_property(owned_store, &"dispose_quiesce_was_pending_for_test"),
		"旧 owned Store 的 dispose 回调内，quiesce 必须等待 replacement 事务离开临界区。"
	)
	var completion_value: Variant = owned_store.get(&"dispose_quiesce_completion_for_test")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful(), "已提交 replacement 后启动的 quiesce 必须正常终结。")
	assert_eq(
		outer_error,
		OK,
		"replacement 已提交且仅启动 quiesce 时，outer setter 必须准确返回 OK。"
	)
	assert_eq(
		_get_int_property(replacement_store, &"dispose_count_for_test"),
		0,
		"调用方收到 OK 后 replacement 必须仍由 Settings 精确持有。"
	)

	settings.dispose()
	assert_eq(
		_get_int_property(replacement_store, &"dispose_count_for_test"),
		1,
		"Settings dispose 必须且只需释放已接纳的 owned replacement。"
	)


func test_owned_store_quiesce_completion_dispose_invalidates_outer_replacement() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var owned_store: Object = _new_recording_store()
	var replacement_store: Object = _new_recording_store()
	if owned_store == null or replacement_store == null:
		return
	assert_eq(_inject_store(settings, owned_store, true), OK)
	owned_store.set(&"settings_for_test", settings)
	owned_store.set(&"begin_quiesce_on_dispose_for_test", true)
	owned_store.set(&"dispose_settings_when_quiesce_completes_for_test", true)

	var outer_error: Error = _inject_store(settings, replacement_store, true)
	assert_true(
		_get_bool_property(owned_store, &"dispose_quiesce_was_pending_for_test"),
		"旧 owned Store 的 quiesce 必须等 replacement critical exit。"
	)
	assert_eq(
		_get_error_property(owned_store, &"quiesce_completion_connect_error_for_test"),
		OK
	)
	var completion_value: Variant = owned_store.get(&"dispose_quiesce_completion_for_test")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	assert_eq(
		outer_error,
		ERR_BUSY,
		"q.completed 在 outer return 前 dispose parent 时 replacement 不得误报 OK。"
	)
	assert_eq(
		_get_int_property(replacement_store, &"dispose_count_for_test"),
		1,
		"已 commit replacement 必须在 deferred parent dispose 中精确释放一次。"
	)
	assert_eq(_inject_store(settings, replacement_store, true), ERR_BUSY)


func test_missing_store_payload_does_not_block_architecture_activation() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if store == null or not _require_property(settings, &"persistence_enabled"):
		return
	settings.set(&"persistence_enabled", true)
	settings.storage_file_name = "missing.json"
	settings.auto_load_on_init = true
	settings.auto_save_on_change = false
	settings.set_value(&"memory/current", 23, false)
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_failure(
			"Settings file does not exist.",
			ERR_FILE_NOT_FOUND,
			{},
			GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
			0,
			GFStorageReadResult.FailureKind.NOT_FOUND
		)
	)

	var architecture: GFArchitecture = _new_architecture()
	var store_script: GDScript = _load_gdscript(_SETTINGS_STORE_SCRIPT_PATH)
	assert_not_null(store_script)
	if store_script == null:
		return
	assert_true(await architecture.register_utility_instance_as(store, store_script))
	assert_true(await architecture.register_utility_instance(settings))
	assert_true(await architecture.init(), "missing 是可启动的首次运行状态。")
	assert_eq(
		GFVariantData.to_int(settings.get_value(&"memory/current")),
		23,
		"missing 不得清空当前内存状态。"
	)
	assert_eq(_get_array_property(store, &"write_calls_for_test").size(), 0)
	var load_result: GFSettingsLoadResult = settings.get_last_load_result()
	assert_not_null(load_result, "missing 仍应保留结构化加载诊断。")
	if load_result != null:
		assert_eq(load_result.get_status(), GFSettingsLoadResult.STATUS_MISSING)
		assert_false(load_result.is_successful())


func test_dispose_first_inside_accepted_callback_blocks_new_lifecycle_io() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "dispose-first-pending.json"
	settings.set_value(&"dispose/pending", 71)
	assert_true(_get_array_property(store, &"write_calls_for_test").is_empty())
	var baseline_capability_calls: int = _get_int_property(store, &"capability_calls_for_test")
	var load_signal_state: Dictionary = { "total_count": 0 }
	var load_callback: Callable = func(_result: GFSettingsLoadResult) -> void:
		load_signal_state["total_count"] = (
			GFVariantData.get_option_int(load_signal_state, "total_count") + 1
		)
	var load_connect_error: Error = settings.settings_load_completed.connect(load_callback) as Error
	assert_eq(load_connect_error, OK)
	var callback_state: Dictionary = {
		"entered": false,
		"activation": null,
		"load_result": null,
		"last_load_inside": null,
		"flush_error": int(OK),
		"quiesce": null,
	}
	var callback: Callable = func(
		_key: StringName,
		_old_value: Variant,
		_new_value: Variant
	) -> void:
		if GFVariantData.get_option_bool(callback_state, "entered"):
			return
		callback_state["entered"] = true
		settings.dispose()
		callback_state["activation"] = settings.begin_activation(GFAsyncScope.new())
		var load_result: GFSettingsLoadResult = settings.load_settings("dispose-first-load.json")
		callback_state["load_result"] = load_result
		callback_state["last_load_inside"] = settings.get_last_load_result()
		callback_state["flush_error"] = int(settings.flush_pending_save())
		callback_state["quiesce"] = settings.begin_quiesce(GFAsyncScope.new())
	var connect_error: Error = settings.setting_changed.connect(callback) as Error
	assert_eq(connect_error, OK)

	settings.set_value(&"dispose/accepted", 73)
	if settings.setting_changed.is_connected(callback):
		settings.setting_changed.disconnect(callback)
	if settings.settings_load_completed.is_connected(load_callback):
		settings.settings_load_completed.disconnect(load_callback)

	assert_true(GFVariantData.get_option_bool(callback_state, "entered"))
	assert_eq(
		_get_int_property(store, &"capability_calls_for_test"),
		baseline_capability_calls,
		"dispose intent 获胜后 nested activation 不得再调用 Store capability。"
	)
	assert_true(
		_get_packed_string_array(store, &"read_calls_for_test").is_empty(),
		"dispose-first nested load 不得开始 Store read。"
	)
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		0,
		"dispose-first public flush/quiesce 不得写 pending 或当前 accepted snapshot。"
	)
	var activation_value: Variant = callback_state.get("activation")
	assert_true(activation_value is GFAsyncCompletion)
	if activation_value is GFAsyncCompletion:
		var activation: GFAsyncCompletion = activation_value
		assert_true(activation.is_failed())
	var load_value: Variant = callback_state.get("load_result")
	assert_true(load_value is GFSettingsLoadResult)
	if load_value is GFSettingsLoadResult:
		var load_result: GFSettingsLoadResult = load_value
		assert_false(load_result.is_successful())
		assert_false(load_result.was_applied())
		assert_eq(load_result.get_error_code(), ERR_UNAVAILABLE)
	assert_true(
		callback_state.get("last_load_inside") == null,
		"dispose-first nested load 不得在 deferred dispose 前改写 last-load。"
	)
	assert_eq(
		GFVariantData.get_option_int(load_signal_state, "total_count"),
		0,
		"dispose-first nested load 不得发布 completion signal。"
	)
	assert_ne(
		GFVariantData.get_option_int(callback_state, "flush_error"),
		int(OK),
		"dispose-first public flush 必须拒绝新物理 attempt。"
	)
	var quiesce_value: Variant = callback_state.get("quiesce")
	assert_true(quiesce_value is GFAsyncCompletion)
	if quiesce_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = quiesce_value
		assert_false(quiesce.is_pending(), "dispose-first quiesce 必须无 I/O 地收敛。")
	assert_eq(_inject_store(settings, store), ERR_BUSY)


func test_quiesce_first_then_dispose_drains_accepted_snapshot_exactly_once() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "quiesce-first-dispose.json"
	var callback_state: Dictionary = {
		"entered": false,
		"pending_inside": false,
		"completion": null,
	}
	var callback: Callable = func(
		_key: StringName,
		_old_value: Variant,
		_new_value: Variant
	) -> void:
		if GFVariantData.get_option_bool(callback_state, "entered"):
			return
		callback_state["entered"] = true
		var completion: GFAsyncCompletion = settings.begin_quiesce(GFAsyncScope.new())
		callback_state["completion"] = completion
		callback_state["pending_inside"] = completion.is_pending()
		settings.dispose()
	var connect_error: Error = settings.setting_changed.connect(callback) as Error
	assert_eq(connect_error, OK)

	settings.set_value(&"quiesce/accepted", 79)
	if settings.setting_changed.is_connected(callback):
		settings.setting_changed.disconnect(callback)

	assert_true(GFVariantData.get_option_bool(callback_state, "entered"))
	assert_true(
		GFVariantData.get_option_bool(callback_state, "pending_inside"),
		"quiesce-first 必须等待当前 accepted mutation 形成冻结 snapshot。"
	)
	var completion_value: Variant = callback_state.get("completion")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	_assert_single_write_payload(store, "quiesce-first-dispose.json", {
		"quiesce/accepted": 79,
	})
	assert_eq(_inject_store(settings, store), ERR_BUSY, "quiesce 排空后 deferred dispose 必须收敛。")


func test_setting_changed_quiesce_waits_for_accepted_set_and_save() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "reentrant-set.json"
	var callback_state: Dictionary = {
		"entered": false,
		"returned": false,
		"pending_inside": false,
		"completion": null,
	}
	var callback: Callable = func(
		_key: StringName,
		_old_value: Variant,
		_new_value: Variant
	) -> void:
		if GFVariantData.get_option_bool(callback_state, "entered"):
			return
		callback_state["entered"] = true
		var completion: GFAsyncCompletion = settings.begin_quiesce(GFAsyncScope.new())
		callback_state["completion"] = completion
		callback_state["pending_inside"] = completion.is_pending()
		callback_state["returned"] = true
	var connect_error: Error = settings.setting_changed.connect(callback) as Error
	assert_eq(connect_error, OK)

	settings.set_value(&"reentrant/set", 17)
	if settings.setting_changed.is_connected(callback):
		settings.setting_changed.disconnect(callback)

	assert_true(GFVariantData.get_option_bool(callback_state, "entered"))
	assert_true(GFVariantData.get_option_bool(callback_state, "returned"))
	assert_true(
		GFVariantData.get_option_bool(callback_state, "pending_inside"),
		"begin_quiesce 不得在首个 setting_changed 用户回调返回前伪完成。"
	)
	var completion_value: Variant = callback_state.get("completion")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	assert_eq(GFVariantData.to_int(settings.get_value(&"reentrant/set")), 17)
	_assert_single_write_payload(store, "reentrant-set.json", {
		"reentrant/set": 17,
	})


func test_setting_changed_quiesce_waits_for_entire_accepted_apply_transaction() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "reentrant-apply.json"
	var callback_state: Dictionary = {
		"entered": false,
		"pending_inside": false,
		"completion": null,
	}
	var callback: Callable = func(
		_key: StringName,
		_old_value: Variant,
		_new_value: Variant
	) -> void:
		if GFVariantData.get_option_bool(callback_state, "entered"):
			return
		callback_state["entered"] = true
		var completion: GFAsyncCompletion = settings.begin_quiesce(GFAsyncScope.new())
		callback_state["completion"] = completion
		callback_state["pending_inside"] = completion.is_pending()
	var connect_error: Error = settings.setting_changed.connect(callback) as Error
	assert_eq(connect_error, OK)

	var report: Dictionary = settings.apply_values({
		&"reentrant/apply_a": 23,
		&"reentrant/apply_b": 29,
	})
	if settings.setting_changed.is_connected(callback):
		settings.setting_changed.disconnect(callback)

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 2)
	assert_true(
		GFVariantData.get_option_bool(callback_state, "pending_inside"),
		"apply_values 首个用户回调内的 quiesce 必须等待整个已接纳事务。"
	)
	var completion_value: Variant = callback_state.get("completion")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_successful())
	assert_eq(GFVariantData.to_int(settings.get_value(&"reentrant/apply_a")), 23)
	assert_eq(GFVariantData.to_int(settings.get_value(&"reentrant/apply_b")), 29)
	_assert_single_write_payload(store, "reentrant-apply.json", {
		"reentrant/apply_a": 23,
		"reentrant/apply_b": 29,
	})


func test_quiesce_closes_mutation_then_flushes_all_admitted_targets() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.set_value(&"guarded/value", "before", false)
	store.set(&"settings_for_test", settings)
	store.set(&"mutation_key_for_test", &"guarded/value")
	store.set(&"mutation_value_for_test", "during_write")

	settings.storage_file_name = "debounce-a.json"
	settings.set_value(&"target/a", 1)
	settings.storage_file_name = "debounce-b.json"
	settings.set_value(&"target/b", 2)
	settings.begin_batch()
	settings.storage_file_name = "open-batch.json"
	settings.set_value(&"target/c", 3)

	var quiesce: GFAsyncCompletion = _call_completion(settings, &"begin_quiesce")
	assert_not_null(quiesce)
	if quiesce == null:
		return
	assert_true(quiesce.is_successful())
	assert_eq(
		_get_written_file_names(store),
		PackedStringArray([
			"debounce-a.json",
			"debounce-b.json",
			"open-batch.json",
		]),
		"quiesce 必须按准入顺序排空两个 debounce 目标和开放 batch 目标。"
	)
	assert_eq(
		GFVariantData.to_text(settings.get_value(&"guarded/value")),
		"before",
		"Store write 重入不得在 quiesce mutation gate 关闭后修改状态。"
	)
	assert_eq(
		GFVariantData.to_text(store.get(&"mutation_observed_value_for_test")),
		"before",
		"mutation gate 必须先于首个物理 write 生效。"
	)


func test_failed_quiesce_has_exact_metadata_and_retains_retry_snapshot() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "retry.json"
	settings.set_value(&"retry/value", { "generation": 1 })
	store.set(&"write_error_for_test", ERR_FILE_CANT_WRITE)
	store.set(&"reset_write_error_after_call_for_test", true)

	var quiesce: GFAsyncCompletion = _call_completion(settings, &"begin_quiesce")
	assert_not_null(quiesce)
	if quiesce == null:
		return
	assert_true(quiesce.is_failed(), "任一 flush 失败必须使 quiesce 失败。")
	_assert_exact_quiesce_failure_metadata(quiesce, "retry.json", ERR_FILE_CANT_WRITE)
	var first_calls: Array = _get_array_property(store, &"write_calls_for_test")
	assert_eq(first_calls.size(), 1)
	if first_calls.is_empty():
		return
	var first_call: Dictionary = _variant_to_dictionary(first_calls[0])

	var repeated_quiesce: GFAsyncCompletion = _call_completion(settings, &"begin_quiesce")
	assert_same(repeated_quiesce, quiesce, "begin_quiesce 必须幂等返回同一终态 completion。")
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		1,
		"重复 begin_quiesce 不得隐式重试物理 IO。"
	)

	var retry_error: Error = settings.flush_pending_save()
	assert_eq(retry_error, OK, "quiescing 中应允许显式重试已接纳失败快照。")
	var retried_calls: Array = _get_array_property(store, &"write_calls_for_test")
	assert_eq(retried_calls.size(), 2)
	if retried_calls.size() == 2:
		var retry_call: Dictionary = _variant_to_dictionary(retried_calls[1])
		assert_eq(
			GFVariantData.get_option_string(retry_call, "file_name"),
			GFVariantData.get_option_string(first_call, "file_name")
		)
		var retry_data: Dictionary = GFVariantData.get_option_dictionary(retry_call, "data")
		var first_data: Dictionary = GFVariantData.get_option_dictionary(first_call, "data")
		assert_eq(
			retry_data,
			first_data,
			"retry 必须复用首次失败时冻结的 payload snapshot。"
		)
	assert_true(quiesce.is_failed(), "显式 retry 不得重写已提交的 quiesce 终态。")


func test_quiesce_first_failure_still_flushes_later_targets_and_retains_exact_pending() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "multi-failed.json"
	settings.set_value(&"multi/failed", 83)
	settings.storage_file_name = "multi-succeeded.json"
	settings.set_value(&"multi/succeeded", 89)
	store.set(&"write_error_for_test", ERR_FILE_CANT_WRITE)
	store.set(&"reset_write_error_after_call_for_test", true)

	var quiesce: GFAsyncCompletion = settings.begin_quiesce(GFAsyncScope.new())
	assert_true(quiesce.is_failed())
	_assert_exact_quiesce_failure_metadata(
		quiesce,
		"multi-failed.json",
		ERR_FILE_CANT_WRITE
	)
	assert_eq(
		_get_written_file_names(store),
		PackedStringArray(["multi-failed.json", "multi-succeeded.json"]),
		"首个 target 失败后 quiesce 仍必须尝试并提交后续独立 target。"
	)

	assert_eq(settings.flush_pending_save(), OK)
	assert_eq(
		_get_written_file_names(store),
		PackedStringArray([
			"multi-failed.json",
			"multi-succeeded.json",
			"multi-failed.json",
		]),
		"显式 retry 只能重试 metadata 中保留的失败 target。"
	)
	assert_true(quiesce.is_failed(), "显式 retry 不得重写原 quiesce 失败终态。")


func test_cyclic_auto_save_preserves_capture_failure_and_same_target_can_supersede() -> void:
	var quiesce_settings: GFSettingsUtility = _new_settings()
	var quiesce_store: Object = _new_recording_store()
	if not _activate_without_load(quiesce_settings, quiesce_store):
		return
	quiesce_settings.auto_save_on_change = true
	quiesce_settings.save_debounce_seconds = 60.0
	quiesce_settings.storage_file_name = "cyclic-quiesce.json"
	var quiesce_cyclic: Array = []
	quiesce_cyclic.append(quiesce_cyclic)

	quiesce_settings.set_value(&"cyclic/value", quiesce_cyclic)
	assert_push_error(
		"[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：cyclic-quiesce.json。"
	)
	var quiesce: GFAsyncCompletion = quiesce_settings.begin_quiesce(GFAsyncScope.new())
	assert_true(quiesce.is_failed())
	_assert_exact_quiesce_failure_metadata(
		quiesce,
		"cyclic-quiesce.json",
		ERR_INVALID_DATA
	)
	assert_eq(
		_get_array_property(quiesce_store, &"write_calls_for_test").size(),
		0,
		"capture failure 必须在 Store I/O 前失败。"
	)

	var supersede_settings: GFSettingsUtility = _new_settings()
	var supersede_store: Object = _new_recording_store()
	if not _activate_without_load(supersede_settings, supersede_store):
		return
	supersede_settings.auto_save_on_change = true
	supersede_settings.save_debounce_seconds = 60.0
	supersede_settings.storage_file_name = "cyclic-supersede.json"
	var supersede_cyclic: Array = []
	supersede_cyclic.append(supersede_cyclic)
	supersede_settings.set_value(&"cyclic/value", supersede_cyclic)
	assert_push_error(
		"[GFSettingsUtility] 设置数据包含循环引用，已拒绝持久化：cyclic-supersede.json。"
	)
	assert_eq(supersede_settings.flush_pending_save(), ERR_INVALID_DATA)
	assert_eq(_get_array_property(supersede_store, &"write_calls_for_test").size(), 0)

	var repaired_value: Array = []
	supersede_settings.set_value(&"cyclic/value", repaired_value)
	assert_eq(supersede_settings.flush_pending_save(), OK)
	_assert_single_write_payload(supersede_store, "cyclic-supersede.json", {
		"cyclic/value": repaired_value,
	})


func test_failed_auto_save_does_not_hot_retry_until_explicit_flush() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 0.5
	settings.storage_file_name = "blocked-auto-retry.json"
	store.set(&"write_error_for_test", ERR_FILE_CANT_WRITE)
	store.set(&"reset_write_error_after_call_for_test", true)
	settings.set_value(&"retry/value", { "generation": 1 })

	settings.tick(0.5)
	var first_calls: Array = _get_array_property(store, &"write_calls_for_test")
	assert_eq(first_calls.size(), 1)
	if first_calls.size() != 1:
		return
	var first_call: Dictionary = _variant_to_dictionary(first_calls[0])
	settings.tick(0.5)
	settings.tick(5.0)
	settings.tick(60.0)
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		1,
		"首次物理失败后 tick 不得自动热重试 blocked snapshot。"
	)

	assert_eq(settings.flush_pending_save(), OK)
	var retried_calls: Array = _get_array_property(store, &"write_calls_for_test")
	assert_eq(retried_calls.size(), 2)
	if retried_calls.size() == 2:
		var retry_call: Dictionary = _variant_to_dictionary(retried_calls[1])
		assert_eq(
			GFVariantData.get_option_string(retry_call, "file_name"),
			GFVariantData.get_option_string(first_call, "file_name")
		)
		assert_eq(
			GFVariantData.get_option_dictionary(retry_call, "data"),
			GFVariantData.get_option_dictionary(first_call, "data"),
			"显式 flush 必须重试同一冻结 payload。"
		)


func test_explicit_flush_write_quiesce_reuses_same_failed_attempt() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "write-reentrant-quiesce.json"
	store.set(&"settings_for_test", settings)
	store.set(&"begin_quiesce_on_write_for_test", true)
	store.set(&"write_error_for_test", ERR_FILE_CANT_WRITE)
	settings.set_value(&"write/value", { "generation": 1 })

	assert_eq(settings.flush_pending_save(), ERR_FILE_CANT_WRITE)
	assert_true(
		_get_bool_property(store, &"write_quiesce_was_pending_for_test"),
		"write 回调内 quiesce 必须等待当前已接纳 Store attempt 收敛。"
	)
	var completion_value: Variant = store.get(&"write_quiesce_completion_for_test")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_failed())
		_assert_exact_quiesce_failure_metadata(
			quiesce,
			"write-reentrant-quiesce.json",
			ERR_FILE_CANT_WRITE
		)
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		1,
		"quiesce 必须继承同次 write attempt 的失败，不得重复 Store I/O。"
	)


func test_pre_cancelled_quiesce_starts_no_io_and_preserves_retry_snapshots() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "cancel-pending.json"
	settings.set_value(&"cancel/pending", 31)
	settings.begin_batch()
	settings.storage_file_name = "cancel-open-batch.json"
	settings.set_value(&"cancel/open_batch", 37)
	var scope: GFAsyncScope = GFAsyncScope.new()
	assert_true(scope.cancel("settings_quiesce_pre_cancelled"))

	var quiesce: GFAsyncCompletion = settings.begin_quiesce(scope)
	assert_true(quiesce.is_cancelled())
	assert_eq(quiesce.get_cancel_reason(), &"settings_quiesce_pre_cancelled")
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		0,
		"预取消 quiesce 不得启动任何物理写入。"
	)

	assert_eq(settings.flush_pending_save(), OK)
	assert_eq(
		_get_written_file_names(store),
		PackedStringArray(["cancel-pending.json", "cancel-open-batch.json"]),
		"预取消必须保留 pending 与开放 batch 快照供显式 retry。"
	)


func test_deferred_quiesce_scope_cancel_starts_no_io_and_preserves_accepted_set() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "cancel-deferred.json"
	var scope: GFAsyncScope = GFAsyncScope.new()
	var callback_state: Dictionary = {
		"entered": false,
		"pending_before_cancel": false,
		"cancel_accepted": false,
		"completion": null,
	}
	var callback: Callable = func(
		_key: StringName,
		_old_value: Variant,
		_new_value: Variant
	) -> void:
		if GFVariantData.get_option_bool(callback_state, "entered"):
			return
		callback_state["entered"] = true
		var completion: GFAsyncCompletion = settings.begin_quiesce(scope)
		callback_state["completion"] = completion
		callback_state["pending_before_cancel"] = completion.is_pending()
		callback_state["cancel_accepted"] = scope.cancel(
			"settings_quiesce_cancelled_in_critical"
		)
	var connect_error: Error = settings.setting_changed.connect(callback) as Error
	assert_eq(connect_error, OK)

	settings.set_value(&"cancel/deferred", 43)
	if settings.setting_changed.is_connected(callback):
		settings.setting_changed.disconnect(callback)

	assert_true(GFVariantData.get_option_bool(callback_state, "pending_before_cancel"))
	assert_true(GFVariantData.get_option_bool(callback_state, "cancel_accepted"))
	var completion_value: Variant = callback_state.get("completion")
	assert_true(completion_value is GFAsyncCompletion)
	if completion_value is GFAsyncCompletion:
		var quiesce: GFAsyncCompletion = completion_value
		assert_true(quiesce.is_cancelled())
		assert_eq(quiesce.get_cancel_reason(), &"settings_quiesce_cancelled_in_critical")
	assert_eq(GFVariantData.to_int(settings.get_value(&"cancel/deferred")), 43)
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		0,
		"critical 中取消 quiesce 后不得启动 deferred 物理写入。"
	)

	assert_eq(settings.flush_pending_save(), OK)
	_assert_single_write_payload(store, "cancel-deferred.json", {
		"cancel/deferred": 43,
	})


func test_dispose_after_quiesce_does_not_repeat_io() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	settings.auto_save_on_change = true
	settings.save_debounce_seconds = 60.0
	settings.storage_file_name = "dispose.json"
	settings.set_value(&"dispose/value", 1)

	var quiesce: GFAsyncCompletion = _call_completion(settings, &"begin_quiesce")
	assert_not_null(quiesce)
	if quiesce == null:
		return
	assert_true(quiesce.is_successful())
	assert_eq(_get_array_property(store, &"write_calls_for_test").size(), 1)

	settings.dispose()
	settings.dispose()
	assert_eq(
		_get_array_property(store, &"write_calls_for_test").size(),
		1,
		"dispose 只清理状态，不得重复 quiesce 已完成的 IO。"
	)


func test_disposed_load_returns_isolated_unavailable_without_state_or_signal_commit() -> void:
	var settings: GFSettingsUtility = _new_settings()
	var store: Object = _new_recording_store()
	if not _activate_without_load(settings, store):
		return
	store.set(
		&"read_result_for_test",
		GFStorageReadResult.new().configure_success({ "disposed/baseline": 47 })
	)
	var signal_state: Dictionary = { "count": 0 }
	var callback: Callable = func(_result: GFSettingsLoadResult) -> void:
		signal_state["count"] = GFVariantData.get_option_int(signal_state, "count") + 1
	var connect_error: Error = settings.settings_load_completed.connect(callback) as Error
	assert_eq(connect_error, OK)
	var baseline_result: GFSettingsLoadResult = settings.load_settings("disposed-baseline.json")
	assert_true(baseline_result.is_successful())
	assert_eq(GFVariantData.get_option_int(signal_state, "count"), 1)

	settings.dispose()
	assert_null(settings.get_last_load_result(), "dispose 后 last-load 公开状态应保持已释放语义。")
	var first_unavailable: GFSettingsLoadResult = settings.load_settings("disposed-first.json")
	var second_unavailable: GFSettingsLoadResult = settings.load_settings("disposed-second.json")
	if settings.settings_load_completed.is_connected(callback):
		settings.settings_load_completed.disconnect(callback)

	assert_not_same(first_unavailable, second_unavailable, "每次 disposed load 都必须返回隔离结果。")
	for unavailable_result: GFSettingsLoadResult in [first_unavailable, second_unavailable]:
		assert_false(unavailable_result.is_successful())
		assert_eq(unavailable_result.get_status(), GFSettingsLoadResult.STATUS_STORAGE_FAILED)
		assert_eq(unavailable_result.get_error_code(), ERR_UNAVAILABLE)
		var storage_result: GFStorageReadResult = unavailable_result.get_storage_result()
		assert_not_null(storage_result)
		if storage_result != null:
			assert_eq(
				storage_result.failure_kind,
				GFStorageReadResult.FailureKind.UNAVAILABLE
			)
	var first_storage_result: GFStorageReadResult = first_unavailable.get_storage_result()
	var second_storage_result: GFStorageReadResult = second_unavailable.get_storage_result()
	assert_not_same(
		first_storage_result,
		second_storage_result,
		"disposed load 的底层读取证据也必须隔离。"
	)
	assert_null(settings.get_last_load_result(), "disposed load 不得重写 last-load 状态。")
	assert_eq(
		GFVariantData.get_option_int(signal_state, "count"),
		1,
		"disposed load 不得发出 settings_load_completed。"
	)


func test_null_store_reports_unavailable_instead_of_fake_success() -> void:
	var null_store: Object = _new_script_instance(_NULL_STORE_SCRIPT_PATH)
	if null_store == null:
		return
	assert_false(_call_bool(null_store, &"is_persistence_enabled"))
	var read_value: Variant = null_store.call(&"read_settings", "settings.json")
	assert_true(read_value is GFStorageReadResult)
	if read_value is GFStorageReadResult:
		var read_result: GFStorageReadResult = read_value
		assert_false(read_result.ok)
		assert_eq(read_result.error_code, ERR_UNAVAILABLE)
		assert_eq(read_result.failure_kind, GFStorageReadResult.FailureKind.UNAVAILABLE)
	assert_eq(
		_call_error(null_store, &"write_settings", ["settings.json", { "value": 1 }]),
		ERR_UNAVAILABLE
	)


func test_file_store_accepts_portable_basename_and_rejects_unsafe_paths() -> void:
	var file_store: Object = _new_script_instance(_FILE_STORE_SCRIPT_PATH)
	if file_store == null:
		return
	assert_true(_call_bool(file_store, &"is_persistence_enabled"))
	var file_name: String = _new_owned_file_name("file-store")
	var payload: Dictionary = { "portable/value": 31 }
	assert_eq(
		_call_error(file_store, &"write_settings", [file_name, payload]),
		OK
	)
	var read_value: Variant = file_store.call(&"read_settings", file_name)
	assert_true(read_value is GFStorageReadResult)
	if read_value is GFStorageReadResult:
		var read_result: GFStorageReadResult = read_value
		assert_true(read_result.ok)
		assert_eq(read_result.payload, { "portable/value": 31.0 })

	assert_eq(
		_call_error(file_store, &"write_settings", ["../escape.json", payload]),
		ERR_INVALID_PARAMETER
	)
	assert_push_error(
		"[GFSettingsUtility] 已拒绝不安全设置文件名：../escape.json。"
	)
	assert_eq(
		_call_error(file_store, &"write_settings", ["nested/settings.json", payload]),
		ERR_INVALID_PARAMETER
	)
	assert_push_error(
		"[GFSettingsUtility] 已拒绝不安全设置文件名：nested/settings.json。"
	)
	assert_eq(
		_call_error(file_store, &"write_settings", ["/escape.json", payload]),
		ERR_INVALID_PARAMETER
	)
	assert_push_error(
		"[GFSettingsUtility] 已拒绝原生绝对设置路径：/escape.json。"
	)


# --- 私有/辅助方法 ---

func _new_settings() -> GFSettingsUtility:
	var settings: GFSettingsUtility = GFSettingsUtility.new()
	_settings_instances.append(settings)
	return settings


func _new_recording_store() -> Object:
	if not ResourceLoader.exists(_SETTINGS_STORE_SCRIPT_PATH):
		assert_true(false, "GFSettingsStoreUtility 脚本必须存在。")
		return null
	var runtime_script: GDScript = GDScript.new()
	runtime_script.source_code = _RECORDING_STORE_SOURCE
	var reload_error: Error = runtime_script.reload(false)
	assert_eq(reload_error, OK, "Recording Store 运行时双桩必须可编译。")
	if reload_error != OK:
		return null
	_runtime_scripts.append(runtime_script)
	var instance_value: Variant = runtime_script.new()
	if instance_value is Object:
		var instance: Object = instance_value
		_store_instances.append(instance)
		return instance
	assert_true(false, "Recording Store 运行时双桩必须可实例化。")
	return null


func _new_script_instance(script_path: String) -> Object:
	var gdscript: GDScript = _load_gdscript(script_path)
	assert_not_null(gdscript, "必须可加载脚本：%s。" % script_path)
	if gdscript == null:
		return null
	var instance_value: Variant = gdscript.new()
	if instance_value is Object:
		var instance: Object = instance_value
		_store_instances.append(instance)
		return instance
	assert_true(false, "必须可实例化脚本：%s。" % script_path)
	return null


func _activate_without_load(settings: GFSettingsUtility, store: Object) -> bool:
	if store == null or not _require_property(settings, &"persistence_enabled"):
		return false
	settings.set(&"persistence_enabled", true)
	settings.auto_load_on_init = false
	settings.auto_save_on_change = false
	if _inject_store(settings, store) != OK:
		return false
	settings.init()
	var _store_ready_result: Variant = store.call(&"ready")
	settings.ready()
	var activation: GFAsyncCompletion = _call_completion(settings, &"begin_activation")
	assert_not_null(activation)
	if activation == null:
		return false
	assert_true(activation.is_successful(), "测试 Settings 必须先完成激活。")
	return activation.is_successful()


func _new_architecture() -> GFArchitecture:
	var architecture: GFArchitecture = GFArchitecture.new()
	_architectures.append(architecture)
	return architecture


func _override_global_architecture_for_test(architecture: GFArchitecture) -> void:
	if not _global_architecture_overridden:
		_previous_global_architecture = Gf._architecture
		_global_architecture_overridden = true
	Gf._architecture = architecture


func _restore_global_architecture_for_test() -> void:
	if not _global_architecture_overridden:
		return
	Gf._architecture = _previous_global_architecture
	_previous_global_architecture = null
	_global_architecture_overridden = false


func _inject_store(
	settings: GFSettingsUtility,
	store: Object,
	owns: bool = false
) -> Error:
	assert_true(
		settings.has_method(&"set_settings_store_for_framework"),
		"GFSettingsUtility 必须提供 Store framework injection seam。"
	)
	if not settings.has_method(&"set_settings_store_for_framework"):
		return ERR_UNAVAILABLE
	var error_value: Variant = settings.call(
		&"set_settings_store_for_framework",
		store,
		owns
	)
	assert_true(error_value is int, "Store injection 必须返回 Error。")
	if error_value is int:
		var error_int: int = error_value
		return error_int as Error
	return ERR_INVALID_DATA


func _call_completion(object_value: Object, method_name: StringName) -> GFAsyncCompletion:
	assert_true(object_value.has_method(method_name), "%s 必须存在。" % method_name)
	if not object_value.has_method(method_name):
		return null
	var result: Variant = object_value.call(method_name, GFAsyncScope.new())
	assert_true(result is GFAsyncCompletion, "%s 必须返回 GFAsyncCompletion。" % method_name)
	if result is GFAsyncCompletion:
		var completion: GFAsyncCompletion = result
		return completion
	return null


func _call_array(object_value: Object, method_name: StringName) -> Array:
	assert_true(object_value.has_method(method_name), "%s 必须存在。" % method_name)
	if not object_value.has_method(method_name):
		return []
	var value: Variant = object_value.call(method_name)
	assert_true(value is Array, "%s 必须返回 Array。" % method_name)
	if value is Array:
		var result: Array = value
		return result
	return []


func _call_bool(object_value: Object, method_name: StringName) -> bool:
	assert_true(object_value.has_method(method_name), "%s 必须存在。" % method_name)
	if not object_value.has_method(method_name):
		return false
	var value: Variant = object_value.call(method_name)
	assert_true(value is bool, "%s 必须返回 bool。" % method_name)
	return value if value is bool else false


func _call_error(
	object_value: Object,
	method_name: StringName,
	arguments: Array
) -> Error:
	assert_true(object_value.has_method(method_name), "%s 必须存在。" % method_name)
	if not object_value.has_method(method_name):
		return ERR_UNAVAILABLE
	var value: Variant = object_value.callv(method_name, arguments)
	assert_true(value is int, "%s 必须返回 Error。" % method_name)
	if value is int:
		var error_int: int = value
		return error_int as Error
	return ERR_INVALID_DATA


func _require_property(object_value: Object, property_name: StringName) -> bool:
	var found: bool = false
	for property_value: Variant in object_value.get_property_list():
		if not property_value is Dictionary:
			continue
		var property_entry: Dictionary = property_value
		var raw_name: Variant = property_entry.get("name", &"")
		if raw_name is StringName:
			var string_name_value: StringName = raw_name
			if string_name_value == property_name:
				found = true
				break
		elif raw_name is String:
			var string_value: String = raw_name
			if StringName(string_value) == property_name:
				found = true
				break
	assert_true(found, "%s 必须公开属性 %s。" % [object_value, property_name])
	return found


func _script_has_method(gdscript: GDScript, method_name: StringName) -> bool:
	for method_value: Variant in gdscript.get_script_method_list():
		if not method_value is Dictionary:
			continue
		var method_entry: Dictionary = method_value
		var raw_name: Variant = method_entry.get("name", &"")
		if raw_name is StringName:
			var string_name_value: StringName = raw_name
			if string_name_value == method_name:
				return true
		elif raw_name is String:
			var string_value: String = raw_name
			if StringName(string_value) == method_name:
				return true
	return false


func _load_gdscript(script_path: String) -> GDScript:
	if not ResourceLoader.exists(script_path):
		return null
	var resource_value: Variant = load(script_path)
	if resource_value is GDScript:
		var gdscript: GDScript = resource_value
		return gdscript
	return null


func _get_array_property(object_value: Object, property_name: StringName) -> Array:
	var value: Variant = object_value.get(property_name)
	assert_true(value is Array, "%s 必须是 Array。" % property_name)
	if value is Array:
		var result: Array = value
		return result
	return []


func _get_packed_string_array(
	object_value: Object,
	property_name: StringName
) -> PackedStringArray:
	var value: Variant = object_value.get(property_name)
	assert_true(value is PackedStringArray, "%s 必须是 PackedStringArray。" % property_name)
	if value is PackedStringArray:
		var result: PackedStringArray = value
		return result
	return PackedStringArray()


func _get_bool_property(object_value: Object, property_name: StringName) -> bool:
	var value: Variant = object_value.get(property_name)
	assert_true(value is bool, "%s 必须是 bool。" % property_name)
	return value if value is bool else false


func _get_int_property(object_value: Object, property_name: StringName) -> int:
	var value: Variant = object_value.get(property_name)
	assert_true(value is int, "%s 必须是 int。" % property_name)
	return value if value is int else 0


func _get_error_property(object_value: Object, property_name: StringName) -> Error:
	return _get_int_property(object_value, property_name) as Error


func _get_written_file_names(store: Object) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for call_value: Variant in _get_array_property(store, &"write_calls_for_test"):
		var call_entry: Dictionary = _variant_to_dictionary(call_value)
		var file_name_value: Variant = call_entry.get("file_name", "")
		if file_name_value is String:
			var file_name: String = file_name_value
			var _appended: bool = result.append(file_name)
	return result


func _assert_single_write_payload(
	store: Object,
	file_name: String,
	expected_values: Dictionary
) -> void:
	var write_calls: Array = _get_array_property(store, &"write_calls_for_test")
	assert_eq(write_calls.size(), 1, "必须只提交一次冻结保存快照。")
	if write_calls.size() != 1:
		return
	var write_call: Dictionary = _variant_to_dictionary(write_calls[0])
	assert_eq(GFVariantData.get_option_string(write_call, "file_name"), file_name)
	var data: Dictionary = _variant_to_dictionary(write_call.get("data", {}))
	var actual_values: Dictionary = {}
	for key_value: Variant in expected_values.keys():
		actual_values[key_value] = GFVariantData.get_option_value(data, key_value)
	assert_eq(actual_values, expected_values, "冻结保存快照必须包含全部已接纳值。")


func _assert_exact_quiesce_failure_metadata(
	completion: GFAsyncCompletion,
	file_name: String,
	error_code: Error
) -> void:
	var metadata: Dictionary = completion.get_metadata()
	var actual_keys: Array[String] = []
	for key_value: Variant in metadata.keys():
		if key_value is String:
			var string_key: String = key_value
			actual_keys.append(string_key)
		elif key_value is StringName:
			var string_name_key: StringName = key_value
			actual_keys.append(String(string_name_key))
	actual_keys.sort()
	assert_eq(actual_keys, _QUIESCE_FAILURE_METADATA_KEYS, "quiesce 失败元数据必须是闭合 5-key。")
	assert_eq(
		_variant_to_packed_string_array(metadata.get("failed_file_names")),
		PackedStringArray([file_name]),
		"失败目标必须保持准入顺序。"
	)
	assert_eq(
		GFVariantData.get_option_dictionary(metadata, "error_codes"),
		{ file_name: int(error_code) }
	)
	assert_eq(
		_variant_to_packed_string_array(metadata.get("pending_file_names")),
		PackedStringArray([file_name])
	)
	assert_eq(GFVariantData.get_option_int(metadata, "failed_count"), 1)
	assert_eq(GFVariantData.get_option_int(metadata, "pending_count"), 1)


func _variant_to_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		var result: Dictionary = value
		return result
	assert_true(false, "测试记录必须是 Dictionary。")
	return {}


func _variant_to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var result: PackedStringArray = value
		return result
	assert_true(false, "测试记录必须是 PackedStringArray。")
	return PackedStringArray()


func _new_owned_file_name(label: String) -> String:
	var file_name: String = "gf-settings-lifecycle-%s-%s.json" % [
		label,
		GFUuid.generate_v4(),
	]
	var _appended: bool = _owned_file_names.append(file_name)
	var path: String = "user://" + file_name
	if FileAccess.file_exists(path):
		var _remove_error: Error = DirAccess.remove_absolute(path)
	return file_name


# --- 内部类 ---

class DisabledPersistenceReadProbe extends GFSettingsUtility:
	var read_calls_for_test: int = 0

	func _read_persisted_data(_file_name: String) -> GFStorageReadResult:
		read_calls_for_test += 1
		return GFStorageReadResult.new().configure_success({ "unexpected/io": true })


class DisposingRecoveryPolicy extends GFSettingsRecoveryPolicy:
	var settings_for_test: GFSettingsUtility = null
	var validate_calls_for_test: int = 0

	func validate_policy() -> Dictionary:
		validate_calls_for_test += 1
		if settings_for_test != null:
			settings_for_test.dispose()
		return super.validate_policy()
