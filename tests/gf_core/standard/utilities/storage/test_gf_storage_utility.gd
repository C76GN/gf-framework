## 测试 GFStorageUtility 的读写、加密与失败回滚行为。
extends GutTest


var _storage: GFStorageUtility


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


func after_each() -> void:
	if _storage != null:
		for i: int in range(10):
			_storage.delete_slot(i)
			_cleanup_file_family(_storage._get_data_filename(i))
			_cleanup_file_family(_storage._get_meta_filename(i))

		for file_name: String in [
			"test_legacy.json",
			"test_integrity.json",
			"test_checksum_only.json",
			"test_missing_checksum.json",
			"test_missing_checksum_migration.json",
			"test_plain_json_strict.json",
			"test_plain_json_migration.json",
			"test_json_number_preserve.json",
			"test_legacy_version.json",
			"test_registered_migration.json",
			"test_missing_migration_chain.json",
			"test_async.json",
			"test_wait_async.json",
			"recover_from_backup.json",
			"recover_from_temp.json",
			"recover_from_stale_temp.json",
			"duplicate_transaction.json",
			"queued_async.json",
			"escape.json",
			"nested/test_nested.json",
			"managed/a.json",
			"managed/b.tres",
			"managed/readme.txt",
			"managed/nested/c.json",
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

		_storage = null


func test_save_and_load_slot() -> void:
	_storage.encrypt_key = 0
	var data: Dictionary = {"hp": 100, "name": "Hero"}
	var meta: Dictionary = {"level": 10, "time": "2023-01-01"}

	assert_eq(_storage.save_slot(1, data, meta), OK, "保存槽位 1 应成功。")
	assert_true(_storage.has_slot(1), "槽位 1 应存在。")

	var loaded_meta: Dictionary = _storage.load_slot_meta(1)
	assert_eq(GFVariantData.get_option_int(loaded_meta, "level"), 10, "读取的元数据应与保存值一致。")

	var loaded_data: Dictionary = _storage.load_slot(1)
	assert_eq(GFVariantData.get_option_string(loaded_data, "name"), "Hero", "读取的核心数据应与保存值一致。")


func test_negative_slot_id_is_rejected() -> void:
	var error: Error = _storage.save_slot(-1, {"hp": 1}, {"level": 1})

	assert_eq(error, ERR_INVALID_PARAMETER, "负数 slot_id 不应写入槽位文件。")
	assert_false(_storage.has_slot(-1), "负数 slot_id 不应被视为有效槽位。")
	assert_true(_storage.load_slot(-1).is_empty(), "负数 slot_id 读取应返回空字典。")
	assert_push_error("[GFStorageUtility] save_slot 失败：slot_id 必须大于等于 0，当前为 -1。")


func test_encryption() -> void:
	_storage.encrypt_key = 42
	var data: Dictionary = {"secret": "confidential_data"}
	var _save_slot_result_109: Variant = _storage.save_slot(2, data)

	var raw_content: String = FileAccess.get_file_as_string(_storage._get_full_path(_storage._get_data_filename(2)))
	assert_false(raw_content.contains("confidential_data"), "开启混淆后，文件内容不应包含明文。")

	var loaded: Dictionary = _storage.load_slot(2)
	assert_eq(GFVariantData.get_option_string(loaded, "secret"), "confidential_data", "读取时应正确解码并恢复原始内容。")


func test_delete_slot() -> void:
	var _save_slot_result_119: Variant = _storage.save_slot(3, {"a": 1}, {"b": 2})
	assert_true(_storage.has_slot(3))

	_storage.delete_slot(3)
	assert_false(_storage.has_slot(3), "删除槽位后不应再存在。")


func test_list_slots_returns_valid_slots_sorted_with_metadata() -> void:
	_storage.encrypt_key = 0
	assert_eq(_storage.save_slot(7, {"value": 7}, {"name": "seven"}), OK, "应能保存槽位 7。")
	assert_eq(_storage.save_slot(2, {"value": 2}, {"name": "two"}), OK, "应能保存槽位 2。")
	assert_eq(_storage._write_json(_storage._get_meta_filename(8), {"name": "orphan"}), OK, "应能构造孤立 metadata。")

	var slots: Array[Dictionary] = _storage.list_slots()
	var first_metadata: Dictionary = GFVariantData.get_option_dictionary(slots[0], "metadata")

	assert_eq(slots.size(), 2, "只应枚举同时存在数据与元数据的有效槽位。")
	assert_eq(GFVariantData.get_option_int(slots[0], "slot_id"), 2, "槽位应按 ID 升序。")
	assert_eq(GFVariantData.get_option_int(slots[1], "slot_id"), 7, "槽位应按 ID 升序。")
	assert_eq(GFVariantData.get_option_string(first_metadata, "name"), "two", "应包含槽位元数据。")
	assert_true(GFVariantData.get_option_int(slots[0], "modified_time") > 0, "应包含 metadata 修改时间。")


func test_has_slot_requires_data_and_metadata_files() -> void:
	_storage.encrypt_key = 0
	var meta_file_name: String = _storage._get_meta_filename(6)
	assert_eq(_storage._write_json(meta_file_name, {"level": 1}), OK, "应能构造孤立 metadata 文件。")

	assert_false(_storage.has_slot(6), "只有 metadata 没有核心数据时不应视为有效槽位。")


func test_legacy_methods() -> void:
	_storage.encrypt_key = 0
	var _save_data_result_152: Variant = _storage.save_data("test_legacy.json", {"old": "data"})
	var data: Dictionary = _storage.load_data("test_legacy.json")
	assert_eq(GFVariantData.get_option_string(data, "old"), "data", "旧版纯数据 API 仍应正常读写。")


func test_pure_data_api_rejects_empty_file_name() -> void:
	_storage.encrypt_key = 0

	assert_eq(_storage.save_data("", { "value": 1 }), ERR_INVALID_PARAMETER, "空文件名不应被保存。")
	assert_true(_storage.load_data("").is_empty(), "空文件名读取应返回空字典。")
	assert_false(GFVariantData.get_option_bool(_storage.load_data_result(""), "ok"), "空文件名结果读取应标记失败。")
	assert_false(FileAccess.file_exists(_storage._get_full_path("_invalid_storage_file")), "空文件名不应写入兜底文件。")
	assert_false(GFVariantData.get_option_bool(_storage.last_load_result, "ok"), "空文件名读取结果应标记失败。")
	assert_push_error("[GFStorageUtility] save_data 失败：file_name 为空。")
	assert_push_error("[GFStorageUtility] load_data 失败：file_name 为空。")
	assert_push_error("[GFStorageUtility] load_data 失败：file_name 为空。")


func test_async_pure_data_api_rejects_empty_file_name_with_failure_signals() -> void:
	watch_signals(_storage)

	var save_error: Error = _storage.save_data_async("", { "value": 1 })
	var load_error: Error = _storage.load_data_async("")

	assert_eq(save_error, ERR_INVALID_PARAMETER, "空文件名异步保存应立即失败。")
	assert_eq(load_error, ERR_INVALID_PARAMETER, "空文件名异步读取应立即失败。")
	assert_signal_emitted_with_parameters(_storage, "save_completed", ["", ERR_INVALID_PARAMETER])
	assert_signal_emitted(_storage, "load_completed", "空文件名异步读取应发出失败完成信号。")
	assert_false(GFVariantData.get_option_bool(_storage.last_load_result, "ok"), "空文件名异步读取结果应标记失败。")
	assert_push_error("[GFStorageUtility] save_data_async 失败：file_name 为空。")
	assert_push_error("[GFStorageUtility] load_data_async 失败：file_name 为空。")


func test_async_save_and_load_data_emit_completion_signals() -> void:
	_storage.encrypt_key = 0
	watch_signals(_storage)

	var save_error: Error = _storage.save_data_async("test_async.json", { "coins": 123 })
	await _pump_storage_async_tasks()

	assert_eq(save_error, OK, "异步保存应成功启动。")
	assert_signal_emitted(_storage, "save_completed", "异步保存完成时应发出 save_completed。")
	assert_eq(GFVariantData.get_option_int(_storage.load_data("test_async.json"), "coins"), 123, "异步保存后的数据应可被同步读取。")

	var load_error: Error = _storage.load_data_async("test_async.json")
	await _pump_storage_async_tasks()
	var last_data: Dictionary = GFVariantData.get_option_dictionary(_storage.last_load_result, "data")

	assert_eq(load_error, OK, "异步读取应成功启动。")
	assert_signal_emitted(_storage, "load_completed", "异步读取完成时应发出 load_completed。")
	assert_true(GFVariantData.get_option_bool(_storage.last_load_result, "ok"), "异步读取结果应标记成功。")
	assert_eq(GFVariantData.get_option_int(last_data, "coins"), 123, "异步读取应恢复保存的数据。")


func test_save_data_creates_nested_directories() -> void:
	_storage.encrypt_key = 0
	var err: Error = _storage.save_data("nested/test_nested.json", {"value": 7})

	assert_eq(err, OK, "嵌套相对路径应自动创建目录并写入。")
	assert_true(FileAccess.file_exists(_storage._get_full_path("nested/test_nested.json")), "嵌套路径文件应存在。")
	assert_eq(GFVariantData.get_option_int(_storage.load_data("nested/test_nested.json"), "value"), 7, "嵌套路径数据应可读取。")


func test_absolute_path_is_rejected_to_save_directory_by_default() -> void:
	var path: String = _storage._get_full_path("C:/outside/save.json")

	assert_false(_storage.allow_absolute_paths, "2.0 默认应拒绝绝对路径。")
	assert_eq(path, "user://test_saves/save.json", "绝对路径默认应收敛到存档目录同名文件。")
	assert_push_error("[GFStorageUtility] 已禁用绝对路径：C:/outside/save.json")


func test_absolute_path_can_be_enabled_for_trusted_tools() -> void:
	_storage.allow_absolute_paths = true

	assert_eq(_storage._get_full_path("C:/outside/save.json"), "C:/outside/save.json", "可信编辑器工具可显式启用绝对路径。")


func test_parent_directory_path_is_rebased_to_save_directory_file_name() -> void:
	var path: String = _storage._get_full_path("../escape.json")

	assert_eq(path, "user://test_saves/escape.json", "跨目录相对路径应收敛到存档目录内的同名文件。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（file_name）：../escape.json")


func test_async_saves_to_same_file_are_serialized() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 2

	assert_eq(_storage.save_data_async("queued_async.json", { "value": 1 }), OK, "第一次异步保存应入队。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 2 }), OK, "同文件第二次异步保存应入队等待。")
	assert_eq(_storage.save_data_async("queued_async.json", { "value": 3 }), OK, "同文件第三次异步保存应入队等待。")

	await _pump_storage_async_tasks()

	assert_eq(GFVariantData.get_option_int(_storage.load_data("queued_async.json"), "value"), 3, "同文件异步保存应按入队顺序串行，最终保留最后一次数据。")


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


func test_dispose_clears_transient_state_and_releases_helpers() -> void:
	_storage.encrypt_key = 0
	_storage.last_load_result = { "ok": true }
	assert_true(_storage.register_migration(1, 2, func(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
		return data
	), "应能注册迁移用于验证 dispose 清理。")
	var _save_async_result: Variant = _storage.save_data_async("queued_async.json", { "value": 1 })

	_storage.dispose()

	assert_true(_storage._async_tasks.is_empty(), "dispose 后不应残留运行中任务。")
	assert_true(_storage._async_queue.is_empty(), "dispose 后不应残留排队任务。")
	assert_true(_storage._async_file_locks.is_empty(), "dispose 后不应残留文件锁。")
	assert_true(_storage._migration_steps.is_empty(), "dispose 后应清理迁移注册表。")
	assert_true(_storage.last_load_result.is_empty(), "dispose 后应清理最近读取结果。")
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

	var loaded_resource: Resource = _storage.load_resource(file_name)
	assert_true(loaded_resource is NoiseTexture2D, "读取的 Resource 应保持原类型。")
	if not (loaded_resource is NoiseTexture2D):
		return
	var loaded_res: NoiseTexture2D = loaded_resource
	assert_eq(loaded_res.width, 128, "读取的 Resource 宽度应与保存值一致。")
	assert_eq(loaded_res.height, 128, "读取的 Resource 高度应与保存值一致。")


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


func test_file_management_rebases_unsafe_directory_paths() -> void:
	assert_eq(_storage.ensure_directory("../escape_dir"), OK, "跨目录路径应收敛到存储根目录下的同名目录。")

	assert_true(DirAccess.dir_exists_absolute(_storage._get_full_path("escape_dir")), "收敛后的目录应创建在存储根目录内。")
	assert_push_error("[GFStorageUtility] 已拒绝跨目录路径（directory_name）：../escape_dir")


func test_file_management_rejects_empty_delete_file_path() -> void:
	assert_eq(_storage.delete_file(""), ERR_INVALID_PARAMETER, "空文件名不应删除任何文件。")

	assert_push_error("[GFStorageUtility] delete_file 失败：file_name 为空。")


func test_save_slot_removes_orphaned_data_when_meta_write_fails() -> void:
	var faulty_storage: FaultyStorageUtility = FaultyStorageUtility.new()
	_storage = faulty_storage
	_storage.save_dir_name = "test_saves"
	_storage.init()
	faulty_storage.fail_on_file_name = _storage._get_temp_filename(_storage._get_meta_filename(4))

	var err: Error = _storage.save_slot(4, {"hp": 1}, {"level": 1})
	var data_path: String = _storage._get_full_path(_storage._get_data_filename(4))

	assert_ne(err, OK, "元数据写入失败时应返回错误码。")
	assert_false(_storage.has_slot(4), "元数据失败后不应留下假阳性的槽位。")
	assert_false(FileAccess.file_exists(data_path), "新建槽位失败时应清理已写入的核心数据文件。")


func test_save_slot_preserves_existing_files_when_overwrite_meta_write_fails() -> void:
	_storage.encrypt_key = 0
	assert_eq(_storage.save_slot(5, {"hp": 10}, {"level": 1}), OK, "预置旧槽位应成功。")

	var faulty_storage: FaultyStorageUtility = FaultyStorageUtility.new()
	_storage = faulty_storage
	_storage.save_dir_name = "test_saves"
	_storage.encrypt_key = 0
	_storage.init()
	faulty_storage.fail_on_file_name = _storage._get_temp_filename(_storage._get_meta_filename(5))

	var err: Error = _storage.save_slot(5, {"hp": 999}, {"level": 9})

	assert_ne(err, OK, "覆盖槽位时 metadata 写失败应返回错误码。")
	assert_eq(GFVariantData.get_option_int(_storage.load_slot(5), "hp"), 10, "覆盖失败后应保留旧的核心数据。")
	assert_eq(GFVariantData.get_option_int(_storage.load_slot_meta(5), "level"), 1, "覆盖失败后应保留旧的元数据。")


func test_slot_transaction_recovery_rolls_back_partial_group_commit() -> void:
	_storage.encrypt_key = 0
	assert_eq(_storage.save_slot(9, {"hp": 10}, {"level": 1}), OK, "预置旧槽位应成功。")

	var data_file_name: String = _storage._get_data_filename(9)
	var meta_file_name: String = _storage._get_meta_filename(9)
	var file_names: Array[String] = [data_file_name, meta_file_name]
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

	assert_true(_storage.has_slot(9), "恢复后旧槽位仍应有效。")
	assert_eq(GFVariantData.get_option_int(_storage.load_slot(9), "hp"), 10, "未完成事务恢复后应回滚核心数据。")
	assert_eq(GFVariantData.get_option_int(_storage.load_slot_meta(9), "level"), 1, "未完成事务恢复后应回滚元数据。")


func test_load_data_restores_backup_when_primary_file_is_missing() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "recover_from_backup.json"
	var backup_file_name: String = _storage._get_backup_filename(file_name)
	assert_eq(_storage._write_json(backup_file_name, {"hp": 77}), OK, "应能预先写入备份文件。")

	var loaded: Dictionary = _storage.load_data(file_name)
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

	var loaded: Dictionary = _storage.load_data(file_name)
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

	var loaded: Dictionary = _storage.load_data(file_name)
	var temp_path: String = _storage._get_full_path(temp_file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "hp"), 11, "已有主文件时，应优先保留已提交数据。")
	assert_false(FileAccess.file_exists(temp_path), "恢复完成后应清理悬挂临时文件。")


func test_transaction_commit_deduplicates_file_names() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "duplicate_transaction.json"
	assert_eq(_storage._write_json(_storage._get_temp_filename(file_name), {"hp": 42}), OK, "应能构造待提交临时文件。")

	var error: Error = _storage._commit_transaction([file_name, file_name])

	assert_eq(error, OK, "事务提交应忽略重复文件名。")
	assert_eq(GFVariantData.get_option_int(_storage.load_data(file_name), "hp"), 42, "去重后的事务提交应产生正式文件。")
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
	tampered["coins"] = 99
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_string_result_473: Variant = file.store_string(JSON.stringify(tampered))
	file.close()
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_true(loaded.is_empty(), "严格校验失败时不应返回被篡改数据。")
	assert_signal_emitted(_storage, "data_integrity_failed", "校验失败应发出信号。")
	assert_push_warning("[GFStorageUtility] 读取数据失败：user://test_saves/test_integrity.json，原因：Integrity checksum mismatch")


func test_checksum_without_storage_metadata_does_not_write_version() -> void:
	_storage.encrypt_key = 0
	_storage.include_storage_metadata = false
	_storage.use_integrity_checksum = true
	var file_name: String = "test_checksum_only.json"

	assert_eq(_storage.save_data(file_name, { "coins": 10 }), OK, "应能保存只带 checksum 的数据。")
	var result: Dictionary = _storage.load_data_result(file_name)
	var loaded: Dictionary = GFVariantData.get_option_dictionary(result, "data")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "只启用 checksum 时读取结果应成功。")
	assert_eq(GFVariantData.get_option_int(loaded, "coins"), 10, "只启用 checksum 时应能正常读取。")
	assert_true(metadata.has("checksum"), "只启用 checksum 时仍应写入 checksum。")
	assert_false(metadata.has("version"), "未启用 include_storage_metadata 时不应写入 version。")
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

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_true(loaded.is_empty(), "要求 checksum 时，缺少 checksum 的存档不应返回数据。")
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

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "coins"), 10, "迁移旧存档时可显式允许缺少 checksum 的文件。")
	assert_signal_not_emitted(_storage, "data_integrity_failed", "显式允许缺少 checksum 时不应发出完整性失败信号。")


func test_legacy_plain_json_fallback_is_disabled_by_default() -> void:
	var file_name: String = "test_plain_json_strict.json"
	assert_eq(_storage._write_plain_json(file_name, { "coins": 10 }), OK, "应能构造旧版纯 JSON 文件。")
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_true(loaded.is_empty(), "配置混淆密钥后，2.0 默认不应静默读取旧版纯 JSON 文件。")
	assert_signal_emitted(_storage, "data_integrity_failed", "旧版纯 JSON 回退关闭时应发出读取失败信号。")
	assert_push_error("[GFStorageUtility] 读取数据失败：%s，原因：Payload is empty" % _storage._get_full_path(file_name))


func test_legacy_plain_json_fallback_can_be_enabled_for_migration() -> void:
	_storage.allow_legacy_plain_json_fallback = true
	var file_name: String = "test_plain_json_migration.json"
	assert_eq(_storage._write_plain_json(file_name, { "coins": 10 }), OK, "应能构造旧版纯 JSON 文件。")
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_eq(GFVariantData.get_option_int(loaded, "coins"), 10, "迁移旧存档时可显式允许旧版纯 JSON 文件。")
	assert_signal_not_emitted(_storage, "data_integrity_failed", "显式允许旧版纯 JSON 回退时不应发出读取失败信号。")


func test_json_number_normalization_is_disabled_by_default() -> void:
	_storage.encrypt_key = 0
	var file_name: String = "test_json_number_preserve.json"
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_string_result_566: Variant = file.store_string("{\"whole\": 1.0}")
	file.close()

	var preserved: Dictionary = _storage.load_data(file_name)
	_storage.normalize_json_numbers = true
	var normalized: Dictionary = _storage.load_data(file_name)

	assert_eq(typeof(GFVariantData.get_option_value(preserved, "whole")), TYPE_FLOAT, "2.0 默认应保留 JSON float 类型。")
	assert_eq(typeof(GFVariantData.get_option_value(normalized, "whole")), TYPE_INT, "迁移旧整数语义时可显式开启数字归一化。")


func test_load_data_result_reports_missing_file() -> void:
	var result: Dictionary = _storage.load_data_result("missing_result.json")

	assert_false(GFVariantData.get_option_bool(result, "ok"), "缺失文件的结构化读取结果应标记失败。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "File not found", "缺失文件应返回明确错误。")


func test_load_slot_result_reports_missing_or_invalid_slot() -> void:
	var missing_result: Dictionary = _storage.load_slot_result(8)
	var invalid_result: Dictionary = _storage.load_slot_result(-1)

	assert_false(GFVariantData.get_option_bool(missing_result, "ok"), "缺失槽位的结构化读取结果应标记失败。")
	assert_eq(GFVariantData.get_option_string(missing_result, "error"), "File not found", "缺失槽位应返回明确错误。")
	assert_false(GFVariantData.get_option_bool(invalid_result, "ok"), "非法槽位的结构化读取结果应标记失败。")
	assert_eq(GFVariantData.get_option_string(invalid_result, "error"), "Invalid slot_id: -1", "非法槽位应返回明确错误。")


func test_wait_for_async_tasks_drains_queued_tasks() -> void:
	_storage.encrypt_key = 0
	_storage.max_async_thread_count = 1

	assert_eq(_storage.save_data_async("test_wait_async.json", { "value": 1 }), OK, "第一次异步保存应启动。")
	assert_eq(_storage.save_data_async("test_wait_async.json", { "value": 2 }), OK, "同文件第二次异步保存应排队。")

	_storage.wait_for_async_tasks()

	assert_true(_storage._async_tasks.is_empty(), "等待后不应残留运行中任务。")
	assert_true(_storage._async_queue.is_empty(), "等待后不应残留排队任务。")
	assert_eq(GFVariantData.get_option_int(_storage.load_data("test_wait_async.json"), "value"), 2, "等待应处理完整队列并保留最后一次写入。")


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
	var legacy_data: Dictionary = {
		"_meta": {
			"version": 1,
		},
		"stats": {},
	}
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_626: Variant = file.store_buffer(codec.encode(legacy_data, { "obfuscation_key": 0 }))
	file.close()
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(loaded, "_meta")
	var stats: Dictionary = GFVariantData.get_option_dictionary(loaded, "stats")

	assert_eq(GFVariantData.get_option_int(metadata, "version"), 2, "迁移后版本应更新为当前 save_version。")
	assert_eq(GFVariantData.get_option_int(stats, "hp"), 100, "迁移时应深合并新增默认字段。")
	assert_eq(GFVariantData.get_option_bool(loaded, "unlocked"), true, "迁移时应补齐顶层新增默认字段。")
	assert_signal_emitted(_storage, "data_migrated", "旧版本数据迁移后应发出信号。")


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
	var _store_buffer_result_654: Variant = file.store_buffer(codec.encode({
		"_meta": {
			"version": 1,
		},
		"value": 10,
	}, { "obfuscation_key": 0 }))
	file.close()

	var loaded: Dictionary = _storage.load_data(file_name)
	var migrations: Array[Dictionary] = _storage.get_registered_migrations()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(loaded, "_meta")

	assert_eq(GFVariantData.get_option_bool(loaded, "step_one"), true, "第一段迁移应执行。")
	assert_eq(GFVariantData.get_option_bool(loaded, "step_two"), true, "第二段迁移应执行。")
	assert_eq(GFVariantData.get_option_int(metadata, "version"), 3, "迁移后版本应更新为当前版本。")
	assert_eq(migrations.size(), 2, "迁移注册表应可查询。")


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
	var _store_buffer_result_682: Variant = file.store_buffer(codec.encode({
		"_meta": {
			"version": 1,
		},
		"value": 10,
	}, { "obfuscation_key": 0 }))
	file.close()
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_true(loaded.is_empty(), "缺失迁移链时不应返回伪迁移数据。")
	assert_false(GFVariantData.get_option_bool(_storage.last_load_result, "ok"), "缺失迁移链应标记读取失败。")
	assert_eq(GFVariantData.get_option_string(_storage.last_load_result, "error"), "Missing migration chain: 1 -> 3", "失败原因应指出缺失链路。")
	assert_signal_emitted(_storage, "data_integrity_failed", "缺失迁移链应发出数据失败信号。")
	assert_signal_not_emitted(_storage, "data_migrated", "缺失迁移链不应发出迁移成功信号。")
	assert_push_warning("[GFStorageUtility] 未找到完整迁移链：1 -> 3。")
	assert_push_error("[GFStorageUtility] 迁移失败：Missing migration chain: 1 -> 3")


func test_strict_schema_migrations_rejects_version_bump_without_registered_steps() -> void:
	_storage.encrypt_key = 0
	_storage.save_version = 2
	_storage.strict_schema_migrations = true
	var file_name: String = "test_strict_migration_chain.json"
	var codec: GFStorageCodec = GFStorageCodec.new()
	var file: FileAccess = FileAccess.open(_storage._get_full_path(file_name), FileAccess.WRITE)
	var _store_buffer_result_709: Variant = file.store_buffer(codec.encode({
		"_meta": {
			"version": 1,
		},
		"value": 10,
	}, { "obfuscation_key": 0 }))
	file.close()
	watch_signals(_storage)

	var loaded: Dictionary = _storage.load_data(file_name)

	assert_true(loaded.is_empty(), "严格迁移模式下缺少迁移链时不应静默升级版本。")
	assert_false(GFVariantData.get_option_bool(_storage.last_load_result, "ok"), "严格迁移失败应标记读取失败。")
	assert_eq(GFVariantData.get_option_string(_storage.last_load_result, "error"), "Missing migration chain: 1 -> 2", "失败原因应指出缺失链路。")
	assert_signal_emitted(_storage, "data_integrity_failed", "严格迁移失败应发出数据失败信号。")
	assert_signal_not_emitted(_storage, "data_migrated", "严格迁移失败不应发出迁移成功信号。")
	assert_push_error("[GFStorageUtility] 迁移失败：Missing migration chain: 1 -> 2")


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


func _pump_storage_async_tasks() -> void:
	for _i: int in range(120):
		_storage.tick(0.0)
		if _storage._async_tasks.is_empty() and _storage._async_queue.is_empty():
			return
		await get_tree().process_frame
