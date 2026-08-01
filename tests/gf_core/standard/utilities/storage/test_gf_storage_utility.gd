## 测试 GFStorageUtility 的读写、加密与失败回滚行为。
extends GutTest


var _storage: GFStorageUtility


class MigrationOverrideStorageUtility extends GFStorageUtility:
	var migration_call_count: int = 0

	func migrate_data(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		migration_call_count += 1
		var migrated: Dictionary = data.duplicate(true)
		migrated["custom_migration"] = true
		return migrated


class InheritedMigrationStorageUtility extends GFStorageUtility:
	pass


class FaultyStorageUtility extends GFStorageUtility:
	var fail_on_file_name: String = ""

	func _write_json(file_name: String, data: Dictionary) -> Error:
		if file_name == fail_on_file_name:
			return ERR_FILE_CANT_WRITE
		return super._write_json(file_name, data)


func _cleanup_file_family(file_name: String) -> void:
	for suffix: String in ["", ".tmp", ".bak", ".txn"]:
		var path: String = _storage._get_full_path(file_name + suffix)
		if FileAccess.file_exists(path):
			var _remove_absolute_result_21: Variant = DirAccess.remove_absolute(path)


func _remove_directory_if_exists(directory_name: String) -> void:
	var path: String = _storage._get_full_path(directory_name)
	if DirAccess.dir_exists_absolute(path):
		var _remove_absolute_result_27: Variant = DirAccess.remove_absolute(path)


func before_each() -> void:
	_storage = GFStorageUtility.new()
	_storage.save_dir_name = "test_saves"
	_storage.init()


func _replace_storage(storage: GFStorageUtility) -> void:
	_storage.dispose()
	_storage = storage


func after_each() -> void:
	if _storage != null:
		for file_name: String in [
			"test_legacy.json",
			"test_encryption.json",
			"test_integrity.json",
			"test_checksum_only.json",
			"test_missing_checksum.json",
			"test_missing_checksum_migration.json",
			"test_plain_json_strict.json",
			"test_plain_json_migration.json",
			"test_json_number_preserve.json",
			"test_legacy_version.json",
			"test_migrate_override.json",
			"test_registered_migration.json",
			"test_missing_migration_chain.json",
			"test_branching_migration.json",
			"test_failed_migration.json",
			"test_future_version.json",
			"test_async.json",
			"test_async_handle.json",
			"nested/async_signal_alias.json",
			"test_wait_async.json",
			"recover_from_backup.json",
			"recover_from_temp.json",
			"recover_from_stale_temp.json",
			"recover_delete.json",
			"duplicate_transaction.json",
			"queued_async.json",
			"escape.json",
			"nested/test_nested.json",
			"managed/a.json",
			"managed/b.tres",
			"managed/readme.txt",
			"managed/nested/c.json",
			"group/data.json",
			"group/meta.json",
			"group/alias.json",
			"marker_victim.json",
			"marker_outsider.json",
			"_invalid_storage_file",
		]:
			_cleanup_file_family(file_name)

		_cleanup_file_family("test_resource.tres")
		_remove_directory_if_exists("managed/nested")
		_remove_directory_if_exists("managed")
		_remove_directory_if_exists("escape_dir")
		_remove_directory_if_exists("preview/nested")
		_remove_directory_if_exists("preview")
		_remove_directory_if_exists("_invalid_storage_directory")
		_remove_directory_if_exists("nested")

		_storage.dispose()
		_storage = null


func test_encryption() -> void:
	_storage.encrypt_key = 42
	var data: Dictionary = {"secret": "confidential_data"}
	assert_eq(_storage.save_data("test_encryption.json", data), OK, "通用数据 API 应支持编码写入。")

	var raw_content: String = FileAccess.get_file_as_string(_storage._get_full_path("test_encryption.json"))
	assert_false(raw_content.contains("confidential_data"), "开启混淆后，文件内容不应包含明文。")

	var loaded: Dictionary = _load_payload("test_encryption.json")
	assert_eq(GFVariantData.get_option_string(loaded, "secret"), "confidential_data", "读取时应正确解码并恢复原始内容。")


func test_pure_data_methods() -> void:
	_storage.encrypt_key = 0
	var _save_data_result_152: Variant = _storage.save_data("test_legacy.json", {"old": "data"})
	var data: Dictionary = _load_payload("test_legacy.json")
	assert_eq(GFVariantData.get_option_string(data, "old"), "data", "旧版纯数据 API 仍应正常读写。")


func test_pure_data_api_rejects_empty_file_name() -> void:
	_storage.encrypt_key = 0

	assert_eq(_storage.save_data("", { "value": 1 }), ERR_INVALID_PARAMETER, "空文件名不应被保存。")
	var read_result: GFStorageReadResult = _storage.load_data("")
	assert_false(read_result.ok, "空文件名结果读取应标记失败。")
	assert_false(FileAccess.file_exists(_storage._get_full_path("_invalid_storage_file")), "空文件名不应写入兜底文件。")
	assert_not_null(_storage.last_load_result, "失败读取也应留下结构化结果。")
	assert_false(_storage.last_load_result.ok, "空文件名读取结果应标记失败。")
	assert_push_error("[GFStorageUtility] save_data 失败：file_name 为空。")
	assert_push_error("[GFStorageUtility] load_data 失败：file_name 为空。")


func test_async_pure_data_api_rejects_empty_file_name_with_failure_signals() -> void:
	watch_signals(_storage)

	var save_error: Error = _storage.save_data_async("", { "value": 1 })
	var load_error: Error = _storage.load_data_async("")

	assert_eq(save_error, ERR_INVALID_PARAMETER, "空文件名异步保存应立即失败。")
	assert_eq(load_error, ERR_INVALID_PARAMETER, "空文件名异步读取应立即失败。")
	assert_signal_emitted_with_parameters(_storage, "save_completed", ["", ERR_INVALID_PARAMETER])
	assert_signal_emitted(_storage, "load_completed", "空文件名异步读取应发出失败完成信号。")
	assert_not_null(_storage.last_load_result, "异步失败应保存结构化结果。")
	assert_false(_storage.last_load_result.ok, "空文件名异步读取结果应标记失败。")
	assert_push_error("[GFStorageUtility] save_data_async 失败：file_name 为空。")
	assert_push_error("[GFStorageUtility] load_data_async 失败：file_name 为空。")


func test_async_save_and_load_data_emit_completion_signals() -> void:
	_storage.encrypt_key = 0
	watch_signals(_storage)

	var save_error: Error = _storage.save_data_async("test_async.json", { "coins": 123 })
	await _pump_storage_async_tasks()

	assert_eq(save_error, OK, "异步保存应成功启动。")
	assert_signal_emitted(_storage, "save_completed", "异步保存完成时应发出 save_completed。")
	assert_eq(GFVariantData.get_option_int(_load_payload("test_async.json"), "coins"), 123, "异步保存后的数据应可被同步读取。")

	var load_error: Error = _storage.load_data_async("test_async.json")
	await _pump_storage_async_tasks()
	var last_data: Dictionary = _storage.last_load_result.payload

	assert_eq(load_error, OK, "异步读取应成功启动。")
	assert_signal_emitted(_storage, "load_completed", "异步读取完成时应发出 load_completed。")
	assert_true(_storage.last_load_result.ok, "异步读取结果应标记成功。")
	assert_eq(GFVariantData.get_option_int(last_data, "coins"), 123, "异步读取应恢复保存的数据。")


func test_async_request_handles_keep_identity_and_typed_failure_kind() -> void:
	_storage.encrypt_key = 0
	var save_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		"test_async_handle.json",
		{"coins": 321}
	)
	await _pump_storage_async_tasks()
	assert_true(save_operation.is_completed())
	assert_true(save_operation.get_result().is_successful())
	assert_eq(
		save_operation.get_result().get_operation(),
		GFStorageAsyncOperation.OPERATION_SAVE
	)

	var load_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		"test_async_handle.json"
	)
	await _pump_storage_async_tasks()
	assert_ne(load_operation.get_request_id(), save_operation.get_request_id())
	assert_true(load_operation.get_result().is_successful())
	assert_eq(
		GFVariantData.get_option_int(load_operation.get_result().get_read_result().payload, "coins"),
		321
	)

	var missing_operation: GFStorageAsyncOperation = _storage.load_data_request_async(
		"missing_async_handle.json"
	)
	await _pump_storage_async_tasks()
	assert_false(missing_operation.get_result().is_successful())
	assert_eq(
		missing_operation.get_result().get_read_result().failure_kind,
		GFStorageReadResult.FailureKind.NOT_FOUND
	)


func test_async_request_handle_rejects_invalid_path_without_hanging() -> void:
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async("")
	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_error_code(), ERR_INVALID_PARAMETER)
	assert_eq(
		operation.get_result().get_read_result().failure_kind,
		GFStorageReadResult.FailureKind.INVALID_REQUEST
	)
	assert_push_error("[GFStorageUtility] load_data_request_async 失败：file_name 为空。")


func test_async_request_handle_keeps_legacy_signal_file_name_and_canonical_identity() -> void:
	var requested_file_name: String = "nested//async_signal_alias.json"
	watch_signals(_storage)
	var operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		requested_file_name,
		{"value": 1}
	)
	await _pump_storage_async_tasks()
	assert_true(operation.is_completed())
	assert_eq(operation.get_file_name(), "nested/async_signal_alias.json")
	assert_signal_emitted_with_parameters(_storage, "save_completed", [requested_file_name, OK])


func test_save_data_creates_nested_directories() -> void:
	_storage.encrypt_key = 0
	var err: Error = _storage.save_data("nested/test_nested.json", {"value": 7})

	assert_eq(err, OK, "嵌套相对路径应自动创建目录并写入。")
	assert_true(FileAccess.file_exists(_storage._get_full_path("nested/test_nested.json")), "嵌套路径文件应存在。")
	assert_eq(GFVariantData.get_option_int(_load_payload("nested/test_nested.json"), "value"), 7, "嵌套路径数据应可读取。")


func test_save_data_group_commits_multiple_files_together() -> void:
	_storage.encrypt_key = 0

	var err: Error = _storage.save_data_group({
		"group/data.json": { "hp": 10 },
		"group/meta.json": { "display_name": "A" },
	})

	assert_eq(err, OK, "多文件事务保存应成功。")
	assert_eq(GFVariantData.get_option_int(_load_payload("group/data.json"), "hp"), 10, "数据文件应写入。")
	assert_eq(GFVariantData.get_option_string(_load_payload("group/meta.json"), "display_name"), "A", "元数据文件应写入。")


func test_save_data_group_rejects_unsafe_paths() -> void:
	var err: Error = _storage.save_data_group({
		"../escape.json": { "hp": 10 },
		"group/meta.json": { "display_name": "A" },
	})

	assert_eq(err, ERR_INVALID_PARAMETER, "多文件事务应拒绝任意非法路径。")
	assert_false(FileAccess.file_exists(_storage._get_full_path("group/meta.json")), "路径校验失败时不应写入其它文件。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（file_name）：../escape.json")


func test_save_data_group_rejects_canonical_path_aliases() -> void:
	var err: Error = _storage.save_data_group({
		"group//alias.json": { "value": 1 },
		"group/alias.json": { "value": 2 },
	})

	assert_eq(err, ERR_INVALID_PARAMETER, "同一 canonical file family 的 raw 别名必须在写入前被拒绝。")
	assert_false(FileAccess.file_exists(_storage._get_full_path("group/alias.json")), "别名冲突不得产生部分写入。")
	assert_push_error("[GFStorageUtility] save_data_group 失败：文件名解析到同一存储目标 group/alias.json。")


func test_storage_paths_reject_parent_segments_before_simplification() -> void:
	var err: Error = _storage.save_data("group/../escape.json", { "value": 1 })

	assert_eq(err, ERR_INVALID_PARAMETER, "任何原始父目录段都应被路径策略拒绝。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（file_name）：group/../escape.json")


func test_absolute_path_is_rejected_to_save_directory_by_default() -> void:
	var path: String = _storage._get_full_path("C:/outside/save.json")

	assert_false(_storage.allow_absolute_paths, "2.0 默认应拒绝绝对路径。")
	assert_eq(path, "", "绝对路径默认应 fail closed，不应收敛到存档目录。")
	assert_push_error("[GFStorageUtility] 已禁用绝对路径：C:/outside/save.json")


func test_absolute_path_can_be_enabled_for_trusted_tools() -> void:
	_storage.allow_absolute_paths = true

	assert_eq(_storage._get_full_path("C:/outside/save.json"), "C:/outside/save.json", "可信编辑器工具可显式启用绝对路径。")


func test_parent_directory_path_is_rejected() -> void:
	var path: String = _storage._get_full_path("../escape.json")

	assert_eq(path, "", "跨目录相对路径应 fail closed，不应收敛到存档目录内。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（file_name）：../escape.json")


func test_async_saves_to_same_file_are_serialized() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 2

	assert_eq(_storage.save_data_async("queued_async.json", { "value": 1 }), OK, "第一次异步保存应入队。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 2 }), OK, "同文件第二次异步保存应入队等待。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 3 }), OK, "同文件第三次异步保存应入队等待。")

	await _pump_storage_async_tasks()

	assert_eq(GFVariantData.get_option_int(_load_payload("queued_async.json"), "value"), 3, "同文件异步保存应按入队顺序串行，最终保留最后一次数据。")


func test_sync_save_waits_for_pending_same_file_async_tasks() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 1

	assert_eq(_storage.save_data_async("queued_async.json", { "value": 1 }), OK, "第一次异步保存应启动。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 2 }), OK, "同文件第二次异步保存应排队。")

	var save_error: Error = _storage.save_data("queued_async.json", { "value": 3 })

	assert_eq(save_error, OK, "同步保存应等待同文件异步任务收敛后再写入。")
	assert_true(_storage._async_tasks.is_empty(), "同步保存后不应残留同文件运行中任务。")
	assert_true(_storage._async_queue.is_empty(), "同步保存后不应残留同文件排队任务。")
	assert_eq(GFVariantData.get_option_int(_load_payload("queued_async.json"), "value"), 3, "同步保存应成为最终文件内容。")


func test_dispose_notifies_queued_async_tasks_as_failed() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 1
	var completed: Array = []
	var _connect_result_253: Variant = _storage.save_completed.connect(func(file_name: String, error: Error) -> void:
		completed.append([file_name, error])
	)

	assert_eq(_storage.save_data_async("queued_async.json", { "value": 1 }), OK, "第一次异步保存应启动。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 2 }), OK, "同文件第二次异步保存应留在队列中。")

	_storage.dispose()

	var saw_cancelled_queue: bool = false
	for entry: Array in completed:
		if GFVariantData.to_text(entry[0]) == "queued_async.json" and GFVariantData.to_int(entry[1]) == ERR_UNAVAILABLE:
			saw_cancelled_queue = true
			break
	assert_true(saw_cancelled_queue, "dispose 应对尚未开始的异步任务发出失败通知。")


func test_dispose_blocks_reentrant_tick_and_wait_from_starting_queued_tasks() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 1
	var callback_state: Dictionary = { "reentered": false }
	var _connect_result: Error = _storage.save_completed.connect(
		func(file_name: String, error: Error) -> void:
			if (
				file_name != "queued_async.json"
				or error != OK
				or GFVariantData.get_option_bool(callback_state, "reentered")
			):
				return
			callback_state["reentered"] = true
			_storage.tick(0.0)
			_storage.wait_for_async_tasks()
	) as Error
	var first_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		"queued_async.json",
		{ "value": 1 }
	)
	var queued_operation: GFStorageAsyncOperation = _storage.save_data_request_async(
		"queued_async.json",
		{ "value": 2 }
	)
	assert_eq(_storage._async_queue.size(), 1, "第二次保存应在 dispose 前保持排队。")

	_storage.dispose()

	assert_true(
		GFVariantData.get_option_bool(callback_state, "reentered"),
		"运行中任务的同步 completion callback 应覆盖 dispose 重入路径。"
	)
	assert_true(first_operation.get_result().is_successful(), "已启动任务应在 dispose 中正常收敛。")
	assert_false(queued_operation.get_result().is_successful(), "排队任务不得由重入 tick/wait 启动。")
	assert_eq(
		queued_operation.get_result().get_write_failure_kind(),
		GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE,
		"dispose 期间排队任务应稳定终止为 UNAVAILABLE。"
	)
	assert_eq(
		GFVariantData.get_option_int(_load_payload("queued_async.json"), "value"),
		1,
		"重入回调不得让排队写入产生磁盘副作用。"
	)


func test_dispose_clears_transient_state_and_releases_helpers() -> void:
	_storage.encrypt_key = 0
	_storage.last_load_result = GFStorageReadResult.new().configure_success({ "ok": true })
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		return data
	), "应能注册迁移用于验证 dispose 清理。")
	var _save_async_result: Variant = _storage.save_data_async("queued_async.json", { "value": 1 })

	_storage.dispose()

	assert_true(_storage._async_tasks.is_empty(), "dispose 后不应残留运行中任务。")
	assert_true(_storage._async_queue.is_empty(), "dispose 后不应残留排队任务。")
	assert_true(_storage._async_file_locks.is_empty(), "dispose 后不应残留文件锁。")
	assert_true(_storage._migration_steps.is_empty(), "dispose 后应清理迁移注册表。")
	assert_null(_storage.last_load_result, "dispose 后应清理最近读取结果。")
	assert_null(_storage._path_policy, "dispose 后应释放路径策略 helper。")
	assert_null(_storage._file_ops, "dispose 后应释放文件操作 helper。")
	assert_null(_storage._transaction_manager, "dispose 后应释放事务 helper。")

	var root_path: String = _storage.get_storage_directory_path()
	assert_eq(root_path, "user://test_saves", "dispose 后再次使用应按需重建 helper。")
	assert_not_null(_storage._path_policy, "再次使用存储工具时应按需重建路径策略 helper。")


func test_save_and_load_resource() -> void:
	var res: NoiseTexture2D = NoiseTexture2D.new()
	res.width = 128
	res.height = 128

	var file_name: String = "test_resource.tres"
	var err: Error = _storage.save_resource(file_name, res)
	assert_eq(err, OK, "保存 Resource 应成功。")

	_storage.allow_resource_loads = true
	_storage.allowed_resource_load_type_hints = PackedStringArray(["NoiseTexture2D"])
	var loaded_resource: Resource = _storage.load_resource(file_name, "NoiseTexture2D")
	assert_true(loaded_resource is NoiseTexture2D, "读取的 Resource 应保持原类型。")
	if not (loaded_resource is NoiseTexture2D):
		return
	var loaded_res: NoiseTexture2D = loaded_resource
	assert_eq(loaded_res.width, 128, "读取的 Resource 宽度应与保存值一致。")
	assert_eq(loaded_res.height, 128, "读取的 Resource 高度应与保存值一致。")


func test_load_resource_requires_explicit_opt_in_and_type_hint() -> void:
	var res: Resource = Resource.new()
	var file_name: String = "test_resource_policy.tres"
	assert_eq(_storage.save_resource(file_name, res), OK, "测试 Resource 应能保存。")

	var denied_resource: Resource = _storage.load_resource(file_name, "Resource")
	_storage.allow_resource_loads = true
	var missing_allowlist_resource: Resource = _storage.load_resource(file_name, "Resource")
	_storage.allowed_resource_load_type_hints = PackedStringArray(["Resource"])
	var missing_type_hint_resource: Resource = _storage.load_resource(file_name)

	assert_null(denied_resource, "默认策略不应允许 ResourceLoader 读取。")
	assert_null(missing_allowlist_resource, "启用 Resource 读取后仍应要求 type_hint allowlist。")
	assert_null(missing_type_hint_resource, "启用 Resource 读取后仍应要求 type_hint。")
	assert_push_error("[GFStorageUtility] load_resource 已被默认安全策略拒绝：请先显式启用 allow_resource_loads。")
	assert_push_error("[GFStorageUtility] load_resource 拒绝未允许的 type_hint：Resource。")
	assert_push_error("[GFStorageUtility] load_resource 需要显式 type_hint。")


func test_load_resource_validates_loaded_resource_type_hint() -> void:
	var resource: Resource = Resource.new()

	assert_true(_storage._is_loaded_resource_compatible(resource, "Resource"), "Resource 基类提示应匹配 Resource 实例。")
	assert_false(_storage._is_loaded_resource_compatible(resource, "PackedScene"), "加载结果必须匹配传入 type_hint。")


func test_file_management_ensure_list_and_delete_files() -> void:
	assert_eq(_storage.ensure_directory("managed/nested"), OK, "应能显式创建嵌套存储目录。")
	assert_eq(_storage.ensure_directory("."), OK, "点号目录应视为存储根目录。")
	assert_eq(_storage.save_data("managed/a.json", { "value": 1 }), OK, "应能写入待枚举 JSON 文件。")
	assert_eq(_storage.save_data("managed/nested/c.json", { "value": 3 }), OK, "应能写入嵌套 JSON 文件。")
	assert_eq(_storage.save_data("managed/readme.txt", { "value": 2 }), OK, "应能写入不同扩展名文件。")
	var res: Resource = Resource.new()
	assert_eq(_storage.save_resource("managed/b.tres", res), OK, "应能写入 Resource 文件。")

	assert_eq(
		_storage.list_files("managed", ".json", false),
		PackedStringArray(["managed/a.json"]),
		"非递归枚举只应返回当前目录下匹配扩展名的文件。",
	)
	assert_eq(
		_storage.list_files("managed", "json", true),
		PackedStringArray(["managed/a.json", "managed/nested/c.json"]),
		"递归枚举应返回排序后的存储相对路径。",
	)
	assert_eq(
		_storage.list_files("managed", "json", true, { "max_file_count": 1 }).size(),
		1,
		"递归枚举应遵守 max_file_count 上限。",
	)
	assert_push_warning("[GFStorageUtility] list_files 已达到 max_file_count=1，后续文件已跳过。")
	assert_eq(
		_storage.list_files("managed", "tres", true),
		PackedStringArray(["managed/b.tres"]),
		"扩展名过滤应同时支持 Resource 文件。",
	)

	assert_eq(_storage.delete_file("managed/a.json"), OK, "应能删除存储相对文件。")
	assert_false(FileAccess.file_exists(_storage._get_full_path("managed/a.json")), "删除后文件不应继续存在。")
	assert_eq(_storage.delete_file("managed/a.json"), ERR_FILE_NOT_FOUND, "重复删除不存在文件应返回明确错误码。")


func test_get_storage_directory_path_has_no_creation_side_effect() -> void:
	var directory_path: String = _storage.get_storage_directory_path("preview/nested")

	assert_eq(directory_path, "user://test_saves/preview/nested", "目录路径查询应复用存储路径策略。")
	assert_false(DirAccess.dir_exists_absolute(directory_path), "只查询目录路径不应创建目录。")


func test_file_management_rejects_unsafe_directory_paths() -> void:
	assert_eq(_storage.ensure_directory("../escape_dir"), ERR_INVALID_PARAMETER, "跨目录目录路径应 fail closed。")

	assert_false(DirAccess.dir_exists_absolute(_storage._get_full_path("escape_dir")), "非法目录不应在存储根目录内创建同名目录。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（directory_name）：../escape_dir")
	assert_push_error("[GFStorageUtility] ensure_directory 失败：directory_name 非法。")


func test_file_management_rejects_empty_delete_file_path() -> void:
	assert_eq(_storage.delete_file(""), ERR_INVALID_PARAMETER, "空文件名不应删除任何文件。")

	assert_push_error("[GFStorageUtility] delete_file 失败：file_name 为空。")


func test_delete_file_cleans_transaction_family_and_prevents_recovery() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "recover_delete.json"
	assert_eq(_storage.save_data(file_name, { "value": 1 }), OK, "预置待删除文件应成功。")
	assert_eq(_storage._write_json(_storage._get_temp_filename(file_name), { "value": 2 }), OK, "应能构造遗留临时文件。")
	assert_eq(_storage._write_json(_storage._get_backup_filename(file_name), { "value": 3 }), OK, "应能构造遗留备份文件。")
	var transaction_files: Array[String] = [file_name]
	assert_eq(_storage._write_transaction_markers(transaction_files, true), OK, "应能构造遗留事务标记。")

	var delete_error: Error = _storage.delete_file(file_name)
	var load_result: GFStorageReadResult = _storage.load_data(file_name)

	assert_eq(delete_error, OK, "删除应清理正式文件和事务族。")
	assert_false(load_result.ok, "删除后不应通过事务恢复读回数据。")
	assert_eq(load_result.error, "File not found", "删除后读取应稳定报告文件不存在。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(file_name)), "正式文件应被删除。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(_storage._get_temp_filename(file_name))), "临时文件应被删除。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(_storage._get_backup_filename(file_name))), "备份文件应被删除。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))), "事务标记应被删除。")


func test_transaction_marker_cannot_expand_recovery_beyond_requested_files() -> void:
	var victim_file_name: String = "marker_victim.json"
	var outsider_file_name: String = "marker_outsider.json"
	assert_eq(_storage.save_data(outsider_file_name, { "value": 1 }), OK, "应能预置事务范围外文件。")
	assert_eq(
		_storage._write_json(_storage._get_backup_filename(outsider_file_name), { "value": 999 }),
		OK,
		"应能构造范围外备份文件。"
	)
	assert_eq(
		_storage._write_plain_json(_storage._get_transaction_filename(victim_file_name), {
			"schema_version": 1,
			"transaction_id": "forged",
			"file_key": victim_file_name,
			"files": [victim_file_name, outsider_file_name],
			"committed": false,
			"had_final": false,
		}),
		OK,
		"应能构造不可信事务 marker。"
	)

	_storage._recover_transaction_files([victim_file_name])

	assert_true(
		FileAccess.file_exists(_storage._get_full_path(_storage._get_backup_filename(outsider_file_name))),
		"请求范围外的备份文件不得被事务恢复流程消费。"
	)
	assert_eq(
		GFVariantData.get_option_int(_load_payload(outsider_file_name), "value"),
		1,
		"marker 不得授权恢复当前请求之外的 file family。"
	)


func test_async_group_marker_cannot_expand_to_unapproved_absolute_sibling() -> void:
	_storage.encrypt_key = 0
	_storage.allow_absolute_paths = false
	var victim_file_name: String = "marker_victim.json"
	var outsider_file_name: String = "marker_outsider.json"
	var victim_path: String = _storage._get_full_path(victim_file_name)
	var outsider_path: String = ProjectSettings.globalize_path(
		_storage._get_full_path(outsider_file_name)
	).replace("\\", "/")
	var declared_files: Array[String] = [victim_file_name, outsider_path]
	assert_eq(_storage.save_data(victim_file_name, { "value": 1 }), OK, "应能预置相对目标。")
	assert_eq(_storage.save_data(outsider_file_name, { "value": 2 }), OK, "应能预置范围外文件。")
	assert_eq(
		DirAccess.rename_absolute(victim_path, victim_path + ".bak"),
		OK,
		"应能构造相对目标备份。"
	)
	assert_eq(
		DirAccess.rename_absolute(outsider_path, outsider_path + ".bak"),
		OK,
		"应能构造绝对 sibling 备份。"
	)
	assert_eq(_storage._write_json(victim_file_name, { "value": 999 }), OK, "应能构造相对目标新代次。")
	assert_eq(
		_storage._write_plain_json_absolute(outsider_path, { "value": 888 }),
		OK,
		"应能构造绝对 sibling 未提交 final。"
	)
	var victim_marker: Dictionary = {
		"schema_version": 1,
		"transaction_id": "absolute-sibling",
		"file_key": victim_file_name,
		"files": declared_files,
		"committed": false,
		"had_final": true,
	}
	var outsider_marker: Dictionary = victim_marker.duplicate(true)
	outsider_marker["file_key"] = outsider_path
	assert_eq(
		_storage._write_plain_json(
			_storage._get_transaction_filename(victim_file_name),
			victim_marker
		),
		OK,
		"应能构造相对目标 marker。"
	)
	assert_eq(
		_storage._write_plain_json_absolute(outsider_path + ".txn", outsider_marker),
		OK,
		"应能构造互相一致的绝对 sibling marker。"
	)

	_storage.max_async_thread_count = 1
	var blocker: GFStorageAsyncOperation = _storage.save_data_request_async(
		"queued_async.json",
		{ "value": 1 }
	)
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(victim_file_name)
	assert_eq(_storage._async_queue.size(), 1, "目标读取应先保持排队，以验证冻结的路径授权。")
	_storage.allow_absolute_paths = true
	_storage.wait_for_async_tasks()

	assert_true(blocker.get_result().is_successful(), "占位任务应正常完成。")
	assert_false(operation.get_result().is_successful(), "未授权事务成员应让目标读取 fail closed。")
	assert_eq(
		operation.get_result().get_error_code(),
		ERR_UNAUTHORIZED,
		"冻结的路径策略应稳定报告未授权。"
	)
	assert_true(FileAccess.get_file_as_string(victim_path).contains("999"), "拒绝恢复时目标 final 不得被改写。")
	assert_true(FileAccess.file_exists(victim_path + ".bak"), "拒绝恢复时目标 backup 不得被消费。")
	assert_true(FileAccess.file_exists(victim_path + ".txn"), "拒绝恢复时目标 marker 不得被删除。")
	assert_true(
		FileAccess.get_file_as_string(outsider_path).contains("888"),
		"未授权绝对 sibling 的 final 不得被事务恢复改写。"
	)
	assert_true(FileAccess.file_exists(outsider_path + ".bak"), "未授权绝对 sibling 的 backup 不得被消费。")
	assert_true(FileAccess.file_exists(outsider_path + ".txn"), "未授权绝对 sibling 的 marker 不得被删除。")
	assert_push_error(
		"[GFStorageUtility] 异步读取失败：%s，原因：Transaction recovery failed，错误码：%s" % [
			victim_file_name,
			ERR_UNAUTHORIZED,
		]
	)


func test_save_data_group_removes_orphaned_files_when_member_write_fails() -> void:
	var faulty_storage: FaultyStorageUtility = FaultyStorageUtility.new()
	_replace_storage(faulty_storage)
	_storage.save_dir_name = "test_saves"
	_storage.init()
	var data_file_name: String = "group/data.json"
	var metadata_file_name: String = "group/meta.json"
	faulty_storage.fail_on_file_name = _storage._get_temp_filename(metadata_file_name)

	var err: Error = _storage.save_data_group({
		data_file_name: {"hp": 1},
		metadata_file_name: {"level": 1},
	})

	assert_ne(err, OK, "任一成员写入失败时应返回错误码。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(data_file_name)), "新事务失败时不应留下已写入的正式文件。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(metadata_file_name)), "失败成员不应留下正式文件。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(_storage._get_temp_filename(data_file_name))), "失败后应清理其它成员的临时文件。")


func test_save_data_group_preserves_existing_files_when_member_write_fails() -> void:
	_storage.encrypt_key = 0
	var data_file_name: String = "group/data.json"
	var metadata_file_name: String = "group/meta.json"
	assert_eq(_storage.save_data_group({
		data_file_name: {"hp": 10},
		metadata_file_name: {"level": 1},
	}), OK, "预置旧事务数据应成功。")

	var faulty_storage: FaultyStorageUtility = FaultyStorageUtility.new()
	_replace_storage(faulty_storage)
	_storage.save_dir_name = "test_saves"
	_storage.encrypt_key = 0
	_storage.init()
	faulty_storage.fail_on_file_name = _storage._get_temp_filename(metadata_file_name)

	var err: Error = _storage.save_data_group({
		data_file_name: {"hp": 999},
		metadata_file_name: {"level": 9},
	})

	assert_ne(err, OK, "覆盖事务任一成员写失败时应返回错误码。")
	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "hp"), 10, "覆盖失败后应保留旧数据文件。")
	assert_eq(GFVariantData.get_option_int(_load_payload(metadata_file_name), "level"), 1, "覆盖失败后应保留旧元数据文件。")


func test_data_group_transaction_recovery_rolls_back_partial_commit() -> void:
	_storage.encrypt_key = 0
	var data_file_name: String = "group/data.json"
	var meta_file_name: String = "group/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	assert_eq(_storage.save_data_group({
		data_file_name: { "hp": 10 },
		meta_file_name: { "level": 1 },
	}), OK, "预置旧事务数据应成功。")
	assert_eq(_storage._write_transaction_markers(file_names, false), OK, "应能构造未完成事务标记。")

	assert_eq(
		DirAccess.rename_absolute(_storage._get_full_path(data_file_name), _storage._get_full_path(_storage._get_backup_filename(data_file_name))),
		OK,
		"应能模拟核心数据备份。",
	)
	assert_eq(
		DirAccess.rename_absolute(_storage._get_full_path(meta_file_name), _storage._get_full_path(_storage._get_backup_filename(meta_file_name))),
		OK,
		"应能模拟元数据备份。",
	)
	assert_eq(_storage._write_json(_storage._get_temp_filename(data_file_name), {"hp": 999}), OK, "应能构造新核心数据临时文件。")
	assert_eq(_storage._write_json(_storage._get_temp_filename(meta_file_name), {"level": 9}), OK, "应能构造新元数据临时文件。")
	assert_eq(
		DirAccess.rename_absolute(_storage._get_full_path(_storage._get_temp_filename(data_file_name)), _storage._get_full_path(data_file_name)),
		OK,
		"应能模拟只提交了核心数据。",
	)

	_storage._recover_transaction_files(file_names)

	assert_eq(GFVariantData.get_option_int(_load_payload(data_file_name), "hp"), 10, "未完成事务恢复后应回滚数据文件。")
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "level"), 1, "未完成事务恢复后应回滚元数据文件。")


func test_single_member_load_recovers_entire_partially_committed_group() -> void:
	_storage.encrypt_key = 0
	var data_file_name: String = "group/data.json"
	var meta_file_name: String = "group/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	assert_eq(_storage.save_data_group({
		data_file_name: { "hp": 10 },
		meta_file_name: { "level": 1 },
	}), OK, "预置旧事务数据应成功。")
	assert_eq(_storage._write_transaction_markers(file_names, false), OK, "应能构造未完成事务标记。")

	for file_name: String in file_names:
		assert_eq(
			DirAccess.rename_absolute(
				_storage._get_full_path(file_name),
				_storage._get_full_path(_storage._get_backup_filename(file_name))
			),
			OK,
			"应能模拟正式文件进入事务备份。"
		)
	assert_eq(_storage._write_json(data_file_name, {"hp": 999}), OK, "应能模拟提交新数据文件。")
	assert_eq(_storage._write_json(meta_file_name, {"level": 9}), OK, "应能模拟提交新元数据文件。")

	var data_marker: Dictionary = _storage._read_transaction_marker(data_file_name)
	data_marker["committed"] = true
	assert_eq(
		_storage._write_plain_json(_storage._get_transaction_filename(data_file_name), data_marker),
		OK,
		"应能模拟只写完一个 committed marker。"
	)

	var loaded_data: Dictionary = _load_payload(data_file_name)

	assert_eq(GFVariantData.get_option_int(loaded_data, "hp"), 10, "读取任一成员都应把整个未完整提交事务回滚到旧代次。")
	assert_eq(GFVariantData.get_option_int(_load_payload(meta_file_name), "level"), 1, "同组其它成员不得保留新代次。")
	for file_name: String in file_names:
		assert_false(
			FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))),
			"全组恢复后不应残留事务标记。"
		)


func test_async_single_member_load_recovers_entire_partially_committed_group() -> void:
	_storage.encrypt_key = 0
	var data_file_name: String = "group/data.json"
	var meta_file_name: String = "group/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	assert_eq(_storage.save_data_group({
		data_file_name: { "hp": 10 },
		meta_file_name: { "level": 1 },
	}), OK, "预置旧事务数据应成功。")
	assert_eq(_storage._write_transaction_markers(file_names, false), OK, "应能构造未完成事务标记。")

	for file_name: String in file_names:
		assert_eq(
			DirAccess.rename_absolute(
				_storage._get_full_path(file_name),
				_storage._get_full_path(_storage._get_backup_filename(file_name))
			),
			OK,
			"应能模拟正式文件进入事务备份。"
		)
	assert_eq(_storage._write_json(data_file_name, { "hp": 999 }), OK, "应能模拟只提交了新数据文件。")
	assert_eq(
		_storage._write_json(_storage._get_temp_filename(meta_file_name), { "level": 9 }),
		OK,
		"应能模拟尚未提交的新元数据临时文件。"
	)

	_storage.max_async_thread_count = 1
	var blocker: GFStorageAsyncOperation = _storage.save_data_request_async(
		"queued_async.json",
		{ "value": 1 }
	)
	var operation: GFStorageAsyncOperation = _storage.load_data_request_async(data_file_name)
	assert_eq(_storage._async_queue.size(), 1, "目标读取应先保持排队，以验证冻结的事务根。")
	_storage.save_dir_name = "test_saves_after_enqueue"
	_storage.wait_for_async_tasks()
	_storage.save_dir_name = "test_saves"
	var result: GFStorageReadResult = operation.get_result().get_read_result()

	assert_true(blocker.get_result().is_successful(), "占位任务应正常完成。")
	assert_true(result.ok, "异步读取应在恢复后成功。")
	assert_eq(
		GFVariantData.get_option_int(result.payload, "hp"),
		10,
		"异步读取任一成员都必须先把整个未提交事务回滚到旧代次。"
	)
	assert_eq(
		GFVariantData.get_option_int(_load_payload(meta_file_name), "level"),
		1,
		"同组其它成员不得保留未提交代次。"
	)
	for file_name: String in file_names:
		assert_false(
			FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))),
			"异步 I/O 前完成全组恢复后不应残留事务标记。"
		)


func test_async_group_recovery_preserves_markers_for_retry_after_restore_failure() -> void:
	_storage.encrypt_key = 0
	var data_file_name: String = "group/data.json"
	var meta_file_name: String = "group/meta.json"
	var file_names: Array[String] = [data_file_name, meta_file_name]
	assert_eq(_storage.save_data_group({
		data_file_name: { "hp": 10 },
		meta_file_name: { "level": 1 },
	}), OK, "预置旧事务数据应成功。")
	assert_eq(_storage._write_transaction_markers(file_names, false), OK, "应能构造未完成事务标记。")
	for file_name: String in file_names:
		assert_eq(
			DirAccess.rename_absolute(
				_storage._get_full_path(file_name),
				_storage._get_full_path(_storage._get_backup_filename(file_name))
			),
			OK,
			"应能模拟正式文件进入事务备份。"
		)
	var blocked_final_path: String = _storage._get_full_path(data_file_name)
	assert_eq(
		DirAccess.make_dir_absolute(blocked_final_path),
		OK,
		"应能用同名目录稳定阻断 backup 恢复。"
	)

	var failed_operation: GFStorageAsyncOperation = _storage.load_data_request_async(data_file_name)
	_storage.wait_for_async_tasks()

	assert_false(failed_operation.get_result().is_successful(), "成员恢复失败时异步读取必须失败。")
	for file_name: String in file_names:
		assert_true(
			FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))),
			"任一成员恢复失败后必须保留全组 marker 供幂等重试。"
		)
	assert_push_error("[GFStorageUtility] 回滚事务文件失败：")
	assert_push_error("[GFStorageUtility] 异步读取失败：")
	assert_eq(DirAccess.remove_absolute(blocked_final_path), OK, "解除模拟故障应成功。")

	var retry_operation: GFStorageAsyncOperation = _storage.load_data_request_async(data_file_name)
	_storage.wait_for_async_tasks()
	var retry_result: GFStorageReadResult = retry_operation.get_result().get_read_result()

	assert_true(retry_result.ok, "解除故障后重试应完成全组恢复。")
	assert_eq(GFVariantData.get_option_int(retry_result.payload, "hp"), 10, "目标成员应恢复旧代次。")
	assert_eq(
		GFVariantData.get_option_int(_load_payload(meta_file_name), "level"),
		1,
		"同组其它成员应保持旧代次。"
	)
	for file_name: String in file_names:
		assert_false(
			FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))),
			"全组重试成功后才应清理事务标记。"
		)


func test_load_data_restores_backup_when_primary_file_is_missing() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "recover_from_backup.json"
	var backup_file_name: String = _storage._get_backup_filename(file_name)
	assert_eq(_storage._write_json(backup_file_name, {"hp": 77}), OK, "应能预先写入备份文件。")

	var loaded: Dictionary = _load_payload(file_name)
	var final_path: String = _storage._get_full_path(file_name)
	var backup_path: String = _storage._get_full_path(backup_file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "hp"), 77, "主文件缺失但存在备份时，应自动恢复最近一次已提交的数据。")
	assert_true(FileAccess.file_exists(final_path), "恢复后应重新生成主文件。")
	assert_false(FileAccess.file_exists(backup_path), "恢复完成后不应残留备份文件。")


func test_load_data_promotes_temp_file_when_no_committed_file_exists() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "recover_from_temp.json"
	var temp_file_name: String = _storage._get_temp_filename(file_name)
	assert_eq(_storage._write_json(temp_file_name, {"hp": 88}), OK, "应能预先写入临时文件。")

	var loaded: Dictionary = _load_payload(file_name)
	var final_path: String = _storage._get_full_path(file_name)
	var temp_path: String = _storage._get_full_path(temp_file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "hp"), 88, "仅存在临时文件时，应自动提升为正式文件。")
	assert_true(FileAccess.file_exists(final_path), "恢复后应生成主文件。")
	assert_false(FileAccess.file_exists(temp_path), "恢复完成后不应残留临时文件。")


func test_load_data_discards_stale_temp_when_primary_file_already_exists() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "recover_from_stale_temp.json"
	var temp_file_name: String = _storage._get_temp_filename(file_name)
	assert_eq(_storage._write_json(file_name, {"hp": 11}), OK, "应能预先写入主文件。")
	assert_eq(_storage._write_json(temp_file_name, {"hp": 99}), OK, "应能预先写入悬挂临时文件。")

	var loaded: Dictionary = _load_payload(file_name)
	var temp_path: String = _storage._get_full_path(temp_file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "hp"), 11, "已有主文件时，应优先保留已提交数据。")
	assert_false(FileAccess.file_exists(temp_path), "恢复完成后应清理悬挂临时文件。")


func test_transaction_commit_deduplicates_file_names() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "duplicate_transaction.json"
	assert_eq(_storage._write_json(_storage._get_temp_filename(file_name), {"hp": 42}), OK, "应能构造待提交临时文件。")

	var error: Error = _storage._commit_transaction([file_name, file_name])

	assert_eq(error, OK, "事务提交应忽略重复文件名。")
	assert_eq(GFVariantData.get_option_int(_load_payload(file_name), "hp"), 42, "去重后的事务提交应产生正式文件。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(_storage._get_transaction_filename(file_name))), "提交完成后不应残留事务标记。")


func test_integrity_checksum_rejects_tampered_data() -> void:
	_storage.encrypt_key = 0
	_storage.include_storage_metadata = true
	_storage.use_integrity_checksum = true
	_storage.strict_integrity = true
	var file_name: String = "test_integrity.json"
	assert_eq(_storage.save_data(file_name, { "coins": 10 }), OK, "应能保存带 checksum 的数据。")

	var path: String = _storage._get_full_path(file_name)
	var content: String = FileAccess.get_file_as_string(path)
	var tampered: Dictionary = GFVariantData.get_option_dictionary({
		"payload": JSON.parse_string(content),
	}, "payload")
	var tampered_payload: Dictionary = GFVariantData.get_option_dictionary(tampered, GFStorageCodec.PAYLOAD_KEY)
	tampered_payload["coins"] = 99
	tampered[GFStorageCodec.PAYLOAD_KEY] = tampered_payload
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_string_result_473: Variant = file.store_string(JSON.stringify(tampered))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "严格校验失败时不应返回被篡改数据。")
	assert_true(loaded.payload.is_empty(), "失败结果不得暴露可误用的被篡改数据。")
	assert_signal_emitted(_storage, "data_integrity_failed", "校验失败应发出信号。")
	assert_push_warning("[GFStorageUtility] 读取数据失败：user://test_saves/test_integrity.json，原因：Integrity checksum mismatch")


func test_checksum_without_diagnostics_metadata_still_writes_data_version() -> void:
	_storage.encrypt_key = 0
	_storage.include_storage_metadata = false
	_storage.use_integrity_checksum = true
	var file_name: String = "test_checksum_only.json"

	assert_eq(_storage.save_data(file_name, { "coins": 10 }), OK, "应能保存只带 checksum 的数据。")
	var result: GFStorageReadResult = _storage.load_data(file_name)
	var loaded: Dictionary = result.payload
	var metadata: Dictionary = result.metadata

	assert_true(result.ok, "只启用 checksum 时读取结果应成功。")
	assert_eq(GFVariantData.get_option_int(loaded, "coins"), 10, "只启用 checksum 时应能正常读取。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "完整性状态应与 metadata 分离。")
	assert_eq(GFVariantData.get_option_int(metadata, GFStorageCodec.VERSION_KEY), 1, "数据版本必须始终写入。")
	assert_false(metadata.has("timestamp"), "未启用 include_storage_metadata 时不应写入 timestamp。")


func test_checksum_enabled_rejects_missing_checksum_file_by_default() -> void:
	_storage.encrypt_key = 0
	_storage.use_integrity_checksum = true
	_storage.strict_integrity = true
	var file_name: String = "test_missing_checksum.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_509: Variant = file.store_buffer(codec.encode({ "coins": 10 }, { "obfuscation_key": 0 }))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "要求 checksum 时，缺少 checksum 的存档不应返回数据。")
	assert_eq(loaded.integrity_status, GFStorageReadResult.IntegrityStatus.MISSING, "失败结果应区分缺少 checksum。")
	assert_signal_emitted(_storage, "data_integrity_failed", "缺少 checksum 应发出完整性失败信号。")
	assert_push_warning("[GFStorageUtility] 读取数据失败：user://test_saves/test_missing_checksum.json，原因：Integrity checksum missing")


func test_missing_checksum_file_can_be_allowed_for_migration() -> void:
	_storage.encrypt_key = 0
	_storage.use_integrity_checksum = true
	_storage.strict_integrity = true
	_storage.require_integrity_checksum = false
	var file_name: String = "test_missing_checksum_migration.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_528: Variant = file.store_buffer(codec.encode({ "coins": 10 }, { "obfuscation_key": 0 }))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_true(loaded.ok, "可显式允许缺少 checksum 的文档。")
	assert_eq(GFVariantData.get_option_int(loaded.payload, "coins"), 10, "允许缺少 checksum 时应返回业务 payload。")
	assert_signal_not_emitted(_storage, "data_integrity_failed", "显式允许缺少 checksum 时不应发出完整性失败信号。")


func test_plain_json_without_storage_document_is_rejected() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "test_plain_json_strict.json"
	assert_eq(_storage._write_plain_json(file_name, { "coins": 10 }), OK, "应能构造非 GF 文档 JSON 文件。")
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "运行时存储工具不应读取没有严格 Envelope 的 JSON。")
	assert_signal_emitted(_storage, "data_integrity_failed", "非法存储文档应发出读取失败信号。")
	assert_push_error("[GFStorageUtility] 读取数据失败：%s，原因：Storage document envelope missing or malformed" % _storage._get_full_path(file_name))


func test_removed_legacy_option_is_not_part_of_storage_utility() -> void:
	var file_name: String = "test_plain_json_migration.json"
	assert_false(_storage.get_property_list().any(func(property: Dictionary) -> bool:
		return GFVariantData.get_option_string(property, "name") == "allow_legacy_plain_json_fallback"
	), "运行时 Utility 不应保留 legacy fallback 开关。")
	assert_false(FileAccess.file_exists(_storage._get_full_path(file_name)), "迁移测试不得创建运行时兼容文件。")


func test_json_number_normalization_is_disabled_by_default() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "test_json_number_preserve.json"
	assert_eq(_storage.save_data(file_name, { "whole": 1.0 }), OK, "应能保存带 float 的严格存储文档。")

	var preserved: Dictionary = _load_payload(file_name)
	_storage.normalize_json_numbers = true
	var normalized: Dictionary = _load_payload(file_name)

	assert_eq(typeof(GFVariantData.get_option_value(preserved, "whole")), TYPE_FLOAT, "2.0 默认应保留 JSON float 类型。")
	assert_eq(typeof(GFVariantData.get_option_value(normalized, "whole")), TYPE_INT, "迁移旧整数语义时可显式开启数字归一化。")


func test_load_data_reports_missing_file() -> void:
	var result: GFStorageReadResult = _storage.load_data("missing_result.json")

	assert_false(result.ok, "缺失文件的结构化读取结果应标记失败。")
	assert_eq(result.error, "File not found", "缺失文件应返回明确错误。")


func test_wait_for_async_tasks_drains_queued_tasks() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 1

	assert_eq(_storage.save_data_async("test_wait_async.json", { "value": 1 }), OK, "第一次异步保存应启动。")
	assert_eq(_storage.save_data_async("test_wait_async.json", { "value": 2 }), OK, "同文件第二次异步保存应排队。")

	_storage.wait_for_async_tasks()

	assert_true(_storage._async_tasks.is_empty(), "等待后不应残留运行中任务。")
	assert_true(_storage._async_queue.is_empty(), "等待后不应残留排队任务。")
	assert_eq(GFVariantData.get_option_int(_load_payload("test_wait_async.json"), "value"), 2, "等待应处理完整队列并保留最后一次写入。")


func test_load_data_applies_version_defaults() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 2
	_storage.default_values_for_new_keys = {
		"stats": {
			"hp": 100,
		},
		"unlocked": true,
	}
	var file_name: String = "test_legacy_version.json"
	var legacy_data: Dictionary = { "stats": {} }
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_626: Variant = file.store_buffer(codec.encode(legacy_data, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()
	watch_signals(_storage)

	var read_result: GFStorageReadResult = _storage.load_data(file_name)
	var loaded: Dictionary = read_result.payload
	var metadata: Dictionary = read_result.metadata
	var stats: Dictionary = GFVariantData.get_option_dictionary(loaded, "stats")

	assert_true(read_result.migrated, "旧数据版本应被显式标记为已迁移。")
	assert_eq(GFVariantData.get_option_int(metadata, GFStorageCodec.VERSION_KEY), 2, "迁移后版本应更新为当前 save_version。")
	assert_eq(GFVariantData.get_option_int(stats, "hp"), 100, "迁移时应深合并新增默认字段。")
	assert_eq(GFVariantData.get_option_bool(loaded, "unlocked"), true, "迁移时应补齐顶层新增默认字段。")
	assert_signal_emitted(_storage, "data_migrated", "旧版本数据迁移后应发出信号。")


func test_load_data_preserves_migrate_data_override_extension_point() -> void:
	var override_storage: MigrationOverrideStorageUtility = MigrationOverrideStorageUtility.new()
	override_storage.save_dir_name = "test_saves"
	override_storage.init()
	_replace_storage(override_storage)
	_storage.encrypt_key = 0
	_storage.save_version = 2
	_storage.default_values_for_new_keys = {"framework_default": true}
	var file_name: String = "test_migrate_override.json"
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _stored: Variant = file.store_buffer(GFStorageCodec.new().encode({ "value": 10 }, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()

	var read_result: GFStorageReadResult = _storage.load_data(file_name)

	assert_true(read_result.ok)
	assert_true(read_result.migrated)
	assert_eq(override_storage.migration_call_count, 1, "读取旧版本必须经过既有 migrate_data 覆写点。")
	assert_true(
		GFVariantData.get_option_bool(read_result.payload, "custom_migration"),
		"覆写迁移产生的数据不得被注册链直调路径跳过。"
	)
	assert_false(
		read_result.payload.has("framework_default"),
		"自定义 migrate_data 返回的精确 schema 不得被外层再次补默认字段。"
	)


func test_registered_migrations_run_as_version_chain() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 3
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		data["step_one"] = true
		return data
	), "应能注册 1 -> 2 迁移。")
	assert_true(_storage.register_migration(2, 3, func(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		data["step_two"] = true
		return data
	), "应能注册 2 -> 3 迁移。")
	var file_name: String = "test_registered_migration.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_654: Variant = file.store_buffer(codec.encode({ "value": 10 }, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()

	var read_result: GFStorageReadResult = _storage.load_data(file_name)
	var loaded: Dictionary = read_result.payload
	var migrations: Array[Dictionary] = _storage.get_registered_migrations()
	var metadata: Dictionary = read_result.metadata

	assert_eq(GFVariantData.get_option_bool(loaded, "step_one"), true, "第一段迁移应执行。")
	assert_eq(GFVariantData.get_option_bool(loaded, "step_two"), true, "第二段迁移应执行。")
	assert_eq(GFVariantData.get_option_int(metadata, GFStorageCodec.VERSION_KEY), 3, "迁移后版本应更新为当前版本。")
	assert_eq(migrations.size(), 2, "迁移注册表应可查询。")


func test_registered_migration_wrong_return_type_fails_without_advancing_version() -> void:
	var inherited_storage: InheritedMigrationStorageUtility = InheritedMigrationStorageUtility.new()
	inherited_storage.save_dir_name = "test_saves"
	inherited_storage.init()
	_replace_storage(inherited_storage)
	_storage.encrypt_key = 0
	_storage.save_version = 2
	assert_true(_storage.register_migration(1, 2, func(
		_data: Dictionary,
		_from_version: int,
		_to_version: int
	) -> Variant:
		return 7
	))
	var file_name: String = "test_failed_migration.json"
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _stored: Variant = file.store_buffer(GFStorageCodec.new().encode({"value": 10}, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()
	watch_signals(_storage)

	var result: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(result.ok)
	assert_eq(result.failure_kind, GFStorageReadResult.FailureKind.MIGRATION_FAILED)
	assert_eq(result.data_version, 1)
	assert_signal_not_emitted(_storage, "data_migrated")
	assert_push_error(
		"[GFStorageUtility] 读取数据失败：user://test_saves/test_failed_migration.json，原因：Migration step 1 -> 2 must return Dictionary."
	)


func test_migration_resolver_selects_reachable_shortest_path() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 4
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["dead_branch"] = true
		return data
	), "应能注册断链分支。")
	assert_true(_storage.register_migration(1, 3, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["reachable_branch"] = true
		return data
	), "应能注册可达分支。")
	assert_true(_storage.register_migration(3, 4, func(data: Dictionary, _from: int, _to: int) -> Dictionary:
		data["target_reached"] = true
		return data
	), "应能注册目标迁移。")
	var file_name: String = "test_branching_migration.json"
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _branching_store_result: Variant = file.store_buffer(GFStorageCodec.new().encode({}, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()

	var loaded: Dictionary = _load_payload(file_name)

	assert_true(GFVariantData.get_option_bool(loaded, "reachable_branch"), "迁移解析器应避开较小但断链的目标。")
	assert_true(GFVariantData.get_option_bool(loaded, "target_reached"), "迁移解析器应抵达目标版本。")
	assert_false(GFVariantData.get_option_bool(loaded, "dead_branch"), "未选中的断链分支不应执行。")


func test_future_storage_version_is_rejected_by_default() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 2
	var file_name: String = "test_future_version.json"
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _future_store_result: Variant = file.store_buffer(GFStorageCodec.new().encode({ "future_only": true }, {
		"obfuscation_key": 0,
		"version": 5,
	}))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "未来版本数据应 fail closed，避免被当前 schema 降级保存。")
	assert_true(loaded.payload.is_empty(), "未来版本失败结果不得暴露可误用 payload。")
	assert_false(_storage.last_load_result.ok, "未来版本应标记读取失败。")
	assert_eq(
		_storage.last_load_result.error,
		"Unsupported future storage version: 5 > 2",
		"未来版本失败原因应稳定。"
	)
	assert_signal_emitted(_storage, "data_integrity_failed", "未来版本拒绝应发出数据失败信号。")
	assert_push_error("[GFStorageUtility] 读取数据失败：user://test_saves/test_future_version.json，原因：Unsupported future storage version: 5 > 2")


func test_missing_registered_migration_chain_fails_without_marking_target_version() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 3
	assert_true(_storage.register_migration(2, 3, func(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		data["step_two"] = true
		return data
	), "应能注册不完整迁移链中的后半段。")
	var file_name: String = "test_missing_migration_chain.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_682: Variant = file.store_buffer(codec.encode({ "value": 10 }, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "缺失迁移链时不应返回伪迁移数据。")
	assert_true(loaded.payload.is_empty(), "缺失迁移链失败结果不得暴露伪迁移数据。")
	assert_false(_storage.last_load_result.ok, "缺失迁移链应标记读取失败。")
	assert_eq(_storage.last_load_result.error, "Missing migration chain: 1 -> 3", "失败原因应指出缺失链路。")
	assert_signal_emitted(_storage, "data_integrity_failed", "缺失迁移链应发出数据失败信号。")
	assert_signal_not_emitted(_storage, "data_migrated", "缺失迁移链不应发出迁移成功信号。")
	assert_push_warning("[GFStorageUtility] 未找到完整迁移链：1 -> 3。")
	assert_push_error("[GFStorageUtility] 读取数据失败：user://test_saves/test_missing_migration_chain.json，原因：Missing migration chain: 1 -> 3")


func test_strict_schema_migrations_rejects_version_bump_without_registered_steps() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 2
	_storage.strict_schema_migrations = true
	var file_name: String = "test_strict_migration_chain.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_709: Variant = file.store_buffer(codec.encode({ "value": 10 }, {
		"obfuscation_key": 0,
		"version": 1,
	}))
	file.close()
	watch_signals(_storage)

	var loaded: GFStorageReadResult = _storage.load_data(file_name)

	assert_false(loaded.ok, "严格迁移模式下缺少迁移链时不应静默升级版本。")
	assert_true(loaded.payload.is_empty(), "严格迁移失败不得暴露未迁移数据。")
	assert_false(_storage.last_load_result.ok, "严格迁移失败应标记读取失败。")
	assert_eq(_storage.last_load_result.error, "Missing migration chain: 1 -> 2", "失败原因应指出缺失链路。")
	assert_signal_emitted(_storage, "data_integrity_failed", "严格迁移失败应发出数据失败信号。")
	assert_signal_not_emitted(_storage, "data_migrated", "严格迁移失败不应发出迁移成功信号。")
	assert_push_error("[GFStorageUtility] 读取数据失败：user://test_saves/test_strict_migration_chain.json，原因：Missing migration chain: 1 -> 2")


func test_storage_backend_default_contract_and_conflict_report_roundtrip() -> void:
	var backend: GFStorageBackend = GFStorageBackend.new()
	var report: GFStorageConflictReport = GFStorageConflictReport.from_dict({
		"file_name": "profile.json",
		"key": "coins",
		"local_value": 10,
		"remote_value": 12,
		"resolved_value": 12,
		"resolution": GFStorageConflictReport.Resolution.USE_REMOTE,
		"metadata": {
			"source": "test",
		},
	})
	var report_copy: GFStorageConflictReport = report.duplicate_report()
	var load_result: Dictionary = backend.load_data("profile.json")
	var capabilities: Dictionary = backend.get_capabilities()

	assert_eq(backend.save_data("profile.json", {"coins": 10}), ERR_UNAVAILABLE, "默认后端不应假装支持写入。")
	assert_false(GFVariantData.get_option_bool(load_result, "ok"), "默认后端读取应返回失败结果。")
	assert_false(GFVariantData.get_option_bool(capabilities, "sync"), "默认能力应声明不支持同步。")
	assert_true(report.is_resolved(), "非 UNRESOLVED 冲突报告应视为已解决。")
	assert_eq(report_copy.to_dict(), report.to_dict(), "冲突报告复制应保留所有字段。")
	var runtime_value: Resource = Resource.new()
	report.local_value = runtime_value
	var safe_report: Dictionary = report.to_json_safe_dict()
	assert_true(
		GFVariantData.get_option_value(safe_report, "local_value") is Dictionary,
		"冲突报告应提供独立 JSON-safe 投影，不改变 native to_dict() 契约。"
	)
	assert_ne(JSON.stringify(safe_report), "", "JSON-safe 冲突报告应可直接序列化。")


func _load_payload(file_name: String) -> Dictionary:
	var result: GFStorageReadResult = _storage.load_data(file_name)
	assert_true(result.ok, "测试辅助读取应成功：%s；%s" % [file_name, result.error])
	if not result.ok:
		return {}
	return result.payload.duplicate(true)


func _pump_storage_async_tasks() -> void:
	for _i: int in range(120):
		_storage.tick(0.0)
		if _storage._async_tasks.is_empty() and _storage._async_queue.is_empty():
			return
		await get_tree().process_frame
