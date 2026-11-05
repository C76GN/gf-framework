## 测试 GFStorageSyncUtility 的后端同步、冲突解析和写回行为。
extends GutTest


class MemoryStorageBackend extends GFStorageBackend:
	var records: Dictionary = {}
	var fail_on_save: bool = false
	var load_error: Error = OK
	var save_count: int = 0
	var legacy_missing_result: bool = false
	var hide_records_from_probe: bool = false

	func set_record(
		file_name: String,
		data: Dictionary,
		metadata: Dictionary = {}
	) -> void:
		records[file_name] = { "data": data.duplicate(true), "metadata": metadata.duplicate(true), }


	func _save_data(
		file_name: String,
		data: Dictionary,
		metadata: Dictionary
	) -> Error:
		save_count += 1
		if fail_on_save:
			return ERR_FILE_CANT_WRITE
		set_record(
			file_name,
			data,
			metadata
		)
		return OK


	func _load_data(file_name: String) -> Dictionary:
		if load_error != OK:
			return {
				"ok": false,
				"error": "read failed",
				"error_code": int(load_error),
			}
		if not records.has(file_name):
			var result: Dictionary = {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": "missing",
			}
			if not legacy_missing_result:
				result["error_code"] = int(ERR_DOES_NOT_EXIST)
			return result

		var record: Dictionary = GFVariantData.get_option_dictionary(records, file_name)
		return {
			"ok": true,
			"data": GFVariantData.get_option_dictionary(record, "data"),
			"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
			"error": "",
		}


	func _has_data(file_name: String) -> bool:
		return not hide_records_from_probe and records.has(file_name)


	func _list_data() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for file_name: String in records.keys():
			var record: Dictionary = GFVariantData.get_option_dictionary(records, file_name)
			result.append({ "file_name": file_name, "metadata": GFVariantData.get_option_dictionary(record, "metadata"), })
		return result


	func _get_capabilities() -> Dictionary:
		return {
			"read": true,
			"write": true,
			"delete": false,
			"list": true,
			"sync": true,
		}


class FailoverTestClock extends GFClock:
	var monotonic_msec: int = 0

	func get_monotonic_msec() -> int:
		return monotonic_msec


	func advance_msec(delta_msec: int) -> void:
		monotonic_msec += maxi(delta_msec, 0)


class FailoverTestBackend extends GFStorageBackend:
	var records: Dictionary = {}
	var can_read: bool = true
	var raw_failed_error_code: Variant = null
	var load_error: Error = OK
	var save_error: Error = OK
	var delete_error: Error = OK
	var load_calls: int = 0
	var save_calls: int = 0

	func set_record(file_name: String, data: Dictionary) -> void:
		records[file_name] = data.duplicate(true)


	func _save_data(
		file_name: String,
		data: Dictionary,
		_metadata: Dictionary
	) -> Error:
		save_calls += 1
		if save_error != OK:
			return save_error
		records[file_name] = data.duplicate(true)
		return OK


	func _load_data(file_name: String) -> Dictionary:
		load_calls += 1
		if raw_failed_error_code != null:
			return {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": "Ambiguous failure code.",
				"error_code": raw_failed_error_code,
			}
		if load_error != OK:
			return {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": error_string(load_error),
				"error_code": int(load_error),
			}
		if not records.has(file_name):
			return {
				"ok": false,
				"data": {},
				"metadata": {},
				"error": "missing",
				"error_code": int(ERR_DOES_NOT_EXIST),
			}
		return {
			"ok": true,
			"data": GFVariantData.get_option_dictionary(records, file_name),
			"metadata": {},
			"error": "",
			"error_code": int(OK),
		}


	func _delete_data(file_name: String) -> Error:
		if delete_error != OK:
			return delete_error
		var _erased: bool = records.erase(file_name)
		return OK


	func _has_data(file_name: String) -> bool:
		return records.has(file_name)


	func _list_data() -> Array[Dictionary]:
		var file_names: PackedStringArray = PackedStringArray(records.keys())
		file_names.sort()
		var result: Array[Dictionary] = []
		for file_name: String in file_names:
			result.append({ "file_name": file_name, "metadata": {} })
		return result


	func _get_capabilities() -> Dictionary:
		return {
			"read": can_read,
			"write": true,
			"delete": true,
			"list": true,
			"sync": false,
		}


func test_missing_remote_is_filled_from_local() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 },
		{ "timestamp_unix": 100 }
	)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)
	var remote_result: Dictionary = remote.load_data("profile.json")
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(remote_result, "data")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"缺失远端时同步应成功。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.COPIED_LOCAL_TO_REMOTE,
		"应报告 local -> remote 写回。"
	)
	assert_eq(
		GFVariantData.get_option_int(remote_data, "coins"),
		10,
		"远端应获得本地数据。"
	)
	assert_has(
		GFVariantData.get_option_array(result, "written_backends"),
		"remote",
		"结果应记录写回的后端。"
	)


func test_storage_backend_normalizes_legacy_load_error_codes() -> void:
	var backend: MemoryStorageBackend = MemoryStorageBackend.new()
	backend.legacy_missing_result = true

	var missing_result: Dictionary = backend.load_data("missing.json")
	backend.set_record(
		"present.json",
		{ "value": 1 }
	)
	var present_result: Dictionary = backend.load_data("present.json")

	assert_eq(
		GFVariantData.get_option_int(missing_result, "error_code"),
		ERR_CANT_OPEN
	)
	assert_eq(
		GFVariantData.get_option_int(present_result, "error_code"),
		OK
	)


func test_read_failure_never_authorizes_overwriting_unread_data() -> void:
	var read_errors: Array[Error] = [
		ERR_TIMEOUT,
		ERR_UNAUTHORIZED,
		ERR_CANT_OPEN,
		ERR_INVALID_DATA,
	]
	for read_error: Error in read_errors:
		for failed_side: String in ["local", "remote"]:
			var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
			var local: MemoryStorageBackend = MemoryStorageBackend.new()
			var remote: MemoryStorageBackend = MemoryStorageBackend.new()
			local.set_record(
				"profile.json",
				{ "coins": 10 }
			)
			remote.set_record(
				"profile.json",
				{ "coins": 99 }
			)
			var failed_backend: MemoryStorageBackend = local if failed_side == "local" else remote
			failed_backend.load_error = read_error
			failed_backend.hide_records_from_probe = true

			var result: Dictionary = sync.sync_data(
				"profile.json",
				local,
				remote
			)

			assert_false(
				GFResultDictionary.is_ok(result),
				"读取故障必须保留为同步失败。"
			)
			assert_eq(
				GFVariantData.get_option_int(result, "status"),
				GFStorageSyncUtility.SyncStatus.FAILED
			)
			assert_eq(
				local.save_count + remote.save_count,
				0,
				"读取失败且存在探针为 false 仍不得写回。"
			)
			failed_backend.load_error = OK
			assert_eq(
				GFVariantData.get_option_dictionary(
					local.load_data("profile.json"),
					"data"
				),
				{ "coins": 10 }
			)
			assert_eq(
				GFVariantData.get_option_dictionary(
					remote.load_data("profile.json"),
					"data"
				),
				{ "coins": 99 }
			)


func test_legacy_ambiguous_read_failure_is_not_treated_as_missing() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 }
	)
	remote.legacy_missing_result = true

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)

	assert_false(GFResultDictionary.is_ok(result))
	assert_eq(
		remote.save_count,
		0,
		"没有精确 missing 分类的旧 adapter 必须失败关闭。"
	)


func test_newer_remote_metadata_wins_default_strategy() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 },
		{ "timestamp_unix": 100 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 },
		{ "timestamp_unix": 200 }
	)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)
	var local_result: Dictionary = local.load_data("profile.json")
	var local_data: Dictionary = GFVariantData.get_option_dictionary(local_result, "data")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"默认 USE_NEWEST 应能处理有时间戳的冲突。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "selected_source"),
		&"remote",
		"时间戳更新的远端应成为来源。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.COPIED_REMOTE_TO_LOCAL,
		"应报告 remote -> local 写回。"
	)
	assert_eq(
		GFVariantData.get_option_int(local_data, "coins"),
		20,
		"本地应被更新为远端数据。"
	)


## 大于 float 精确范围的相邻 Int64 revision 仍须优先于相反方向的时间戳。
func test_adjacent_int64_revisions_select_exact_newer_record() -> void:
	for remote_newer: bool in [false, true]:
		for with_timestamps: bool in [false, true]:
			var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
			var local: MemoryStorageBackend = MemoryStorageBackend.new()
			var remote: MemoryStorageBackend = MemoryStorageBackend.new()
			var local_metadata: Dictionary = { "revision": 9007199254740992 if remote_newer else 9007199254740993 }
			var remote_metadata: Dictionary = { "revision": 9007199254740993 if remote_newer else 9007199254740992 }
			if with_timestamps:
				local_metadata["timestamp_unix"] = 200 if remote_newer else 100
				remote_metadata["timestamp_unix"] = 100 if remote_newer else 200
			local.set_record(
				"profile.json",
				{ "side": "local" },
				local_metadata
			)
			remote.set_record(
				"profile.json",
				{ "side": "remote" },
				remote_metadata
			)
			var result: Dictionary = sync.sync_data(
				"profile.json",
				local,
				remote
			)
			var expected_side: String = "remote" if remote_newer else "local"
			assert_true(GFResultDictionary.is_ok(result))
			assert_eq(
				GFVariantData.get_option_string(result, "selected_source"),
				expected_side
			)
			for backend: MemoryStorageBackend in [local, remote]:
				var record: Dictionary = backend.load_data("profile.json")
				assert_eq(
					GFVariantData.get_option_dictionary(record, "data"),
					{ "side": expected_side }
				)
				assert_eq(
					GFVariantData.get_option_int(
						GFVariantData.get_option_dictionary(record, "metadata"),
						"revision"
					),
					9007199254740993
				)


func test_non_finite_newest_metadata_is_unresolved_without_writeback() -> void:
	var cases: Array[Array] = [
		[100.0, NAN],
		[NAN, 100.0],
		[100.0, INF],
		[INF, 100.0],
		[100.0, -INF],
		[-INF, 100.0],
		[NAN, NAN],
		[INF, INF],
	]
	for case_index: int in range(cases.size()):
		var values: Array = cases[case_index]
		var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
		var local: MemoryStorageBackend = MemoryStorageBackend.new()
		var remote: MemoryStorageBackend = MemoryStorageBackend.new()
		var file_name: String = "non_finite_%d.json" % case_index
		local.set_record(
			file_name,
			{ "side": "local" },
			{ "timestamp_unix": values[0] }
		)
		remote.set_record(
			file_name,
			{ "side": "remote" },
			{ "timestamp_unix": values[1] }
		)

		var result: Dictionary = sync.sync_data(
			file_name,
			local,
			remote
		)
		var local_data: Dictionary = GFVariantData.get_option_dictionary(
			local.load_data(file_name),
			"data"
		)
		var remote_data: Dictionary = GFVariantData.get_option_dictionary(
			remote.load_data(file_name),
			"data"
		)

		assert_false(
			GFVariantData.get_option_bool(result, "ok"),
			"非有限 newest 元数据必须保持 unresolved，case=%d。" % case_index
		)
		assert_eq(
			GFVariantData.get_option_int(result, "status"),
			GFStorageSyncUtility.SyncStatus.CONFLICT,
			"非有限 newest 元数据必须报告冲突，case=%d。" % case_index
		)
		assert_eq(
			GFVariantData.get_option_string(local_data, "side"),
			"local",
			"本地记录不得被改写。"
		)
		assert_eq(
			GFVariantData.get_option_string(remote_data, "side"),
			"remote",
			"远端记录不得被改写。"
		)


func test_custom_revision_keys_accept_string_name_options() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 },
		{ "build": 1 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 },
		{ "build": 2 }
	)
	var options: Dictionary = {}
	options[&"revision_keys"] = PackedStringArray(["build"])

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote,
		options
	)

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"自定义 revision_keys 使用 StringName 键时仍应参与新旧判断。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "selected_source"),
		&"remote",
		"自定义 revision key 更新的一侧应成为来源。"
	)


func test_non_numeric_metadata_comparison_uses_safe_text_conversion() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 },
		{ "revision": false }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 },
		{ "revision": true }
	)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"非数字元数据也应能稳定比较。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "selected_source"),
		&"remote",
		"文本比较后较新的远端应成为来源。"
	)


func test_unordered_conflict_is_reported_without_write() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 }
	)
	watch_signals(sync)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)
	var local_data: Dictionary = GFVariantData.get_option_dictionary(
		local.load_data("profile.json"),
		"data"
	)
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(
		remote.load_data("profile.json"),
		"data"
	)

	assert_false(
		GFVariantData.get_option_bool(result, "ok"),
		"无法判断新旧时不应自动解决冲突。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.CONFLICT,
		"结果应标记为冲突。"
	)
	assert_eq(
		GFVariantData.get_option_array(result, "conflicts").size(),
		1,
		"应返回冲突报告。"
	)
	assert_eq(
		GFVariantData.get_option_int(local_data, "coins"),
		10,
		"本地不应被改写。"
	)
	assert_eq(
		GFVariantData.get_option_int(remote_data, "coins"),
		20,
		"远端不应被改写。"
	)
	assert_signal_emitted(
		sync,
		"sync_conflict_detected",
		"检测冲突时应发出信号。"
	)
	assert_signal_emitted(
		sync,
		"sync_conflict_unresolved",
		"未解决冲突应以独立终止信号报告。"
	)
	assert_signal_not_emitted(
		sync,
		"sync_completed",
		"未解决冲突不应伪装成同步完成。"
	)
	assert_signal_not_emitted(
		sync,
		"sync_failed",
		"未解决冲突不应伪装成后端失败。"
	)


func test_explicit_local_strategy_resolves_conflict() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 }
	)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote,
		{ "strategy": GFStorageSyncUtility.ConflictStrategy.USE_LOCAL, }
	)
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(
		remote.load_data("profile.json"),
		"data"
	)

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"显式 USE_LOCAL 应解决冲突。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(result, "selected_source"),
		&"local",
		"来源应为本地。"
	)
	assert_eq(
		GFVariantData.get_option_int(remote_data, "coins"),
		10,
		"远端应被本地数据覆盖。"
	)


func test_custom_resolver_can_merge_and_write_both_sides() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 },
		{ "timestamp_unix": 100 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 },
		{ "timestamp_unix": 200 }
	)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote,
		{
			"strategy": GFStorageSyncUtility.ConflictStrategy.CUSTOM,
			"resolver": func(
				_report: GFStorageConflictReport,
				local_record: Dictionary,
				remote_record: Dictionary,
				_options: Dictionary
			) -> Dictionary:
				var local_record_data: Dictionary = GFVariantData.get_option_dictionary(local_record, "data")
				var remote_record_data: Dictionary = GFVariantData.get_option_dictionary(remote_record, "data")
				return {
					"data": { "coins": (GFVariantData.get_option_int(local_record_data, "coins") + GFVariantData.get_option_int(remote_record_data, "coins")), },
					"metadata": { "timestamp_unix": 300, },
					"resolution": GFStorageConflictReport.Resolution.MERGED,
				},
		}
	)
	var local_data: Dictionary = GFVariantData.get_option_dictionary(
		local.load_data("profile.json"),
		"data"
	)
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(
		remote.load_data("profile.json"),
		"data"
	)

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"自定义 resolver 应能合并冲突。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.MERGED,
		"自定义结果应报告 merged。"
	)
	assert_eq(
		GFVariantData.get_option_int(local_data, "coins"),
		30,
		"本地应写入合并结果。"
	)
	assert_eq(
		GFVariantData.get_option_int(remote_data, "coins"),
		30,
		"远端应写入合并结果。"
	)


func test_custom_resolver_options_accept_string_name_keys_and_copy_metadata() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	var resolver_metadata: Dictionary = {
		"nested": { "revision": 3, },
	}
	local.set_record(
		"profile.json",
		{ "coins": 10 }
	)
	remote.set_record(
		"profile.json",
		{ "coins": 20 }
	)
	var options: Dictionary = {}
	options[&"strategy"] = GFStorageSyncUtility.ConflictStrategy.CUSTOM
	options[&"write_to_local"] = "off"
	options[&"write_to_remote"] = "on"
	options[&"resolver"] = func(
		_report: GFStorageConflictReport,
		_local_record: Dictionary,
		_remote_record: Dictionary,
		_options: Dictionary
	) -> Dictionary:
		return {
			"data": { "coins": 99, },
			"metadata": resolver_metadata,
			"resolution": GFStorageConflictReport.Resolution.MERGED,
		}

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote,
		options
	)
	var result_metadata_value: Variant = GFVariantData.get_option_value(result, "metadata")
	assert_true(
		result_metadata_value is Dictionary,
		"同步结果应带有 metadata 字典。"
	)
	if not (result_metadata_value is Dictionary):
		return
	var result_metadata: Dictionary = result_metadata_value
	var result_nested_value: Variant = GFVariantData.get_option_value(result_metadata, "nested")
	assert_true(
		result_nested_value is Dictionary,
		"同步结果 metadata 应保留嵌套字典。"
	)
	if not (result_nested_value is Dictionary):
		return
	var result_nested: Dictionary = result_nested_value
	result_nested["revision"] = 100
	var local_data: Dictionary = GFVariantData.get_option_dictionary(
		local.load_data("profile.json"),
		"data"
	)
	var remote_data: Dictionary = GFVariantData.get_option_dictionary(
		remote.load_data("profile.json"),
		"data"
	)
	var resolver_nested: Dictionary = GFVariantData.get_option_dictionary(resolver_metadata, "nested")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"自定义 resolver 应接受 StringName 选项键。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.MERGED,
		"自定义结果应报告 merged。"
	)
	assert_eq(
		GFVariantData.get_option_int(local_data, "coins"),
		10,
		"write_to_local=off 时不应写回本地。"
	)
	assert_eq(
		GFVariantData.get_option_int(remote_data, "coins"),
		99,
		"write_to_remote=on 时应写回远端。"
	)
	assert_eq(
		GFVariantData.get_option_int(resolver_nested, "revision"),
		3,
		"resolver 元数据应被深拷贝。"
	)


func test_backend_write_failure_is_reported() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"profile.json",
		{ "coins": 10 }
	)
	remote.fail_on_save = true
	watch_signals(sync)

	var result: Dictionary = sync.sync_data(
		"profile.json",
		local,
		remote
	)
	var errors: Dictionary = GFVariantData.get_option_dictionary(result, "errors")

	assert_false(
		GFVariantData.get_option_bool(result, "ok"),
		"后端写入失败时同步应失败。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "status"),
		GFStorageSyncUtility.SyncStatus.FAILED,
		"结果应标记为失败。"
	)
	assert_true(
		errors.has(&"remote"),
		"应记录失败后端。"
	)
	assert_signal_emitted(
		sync,
		"sync_failed",
		"同步失败时应发出信号。"
	)


func test_sync_many_returns_status_counts() -> void:
	var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
	var local: MemoryStorageBackend = MemoryStorageBackend.new()
	var remote: MemoryStorageBackend = MemoryStorageBackend.new()
	local.set_record(
		"a.json",
		{ "value": 1 }
	)
	local.set_record(
		"b.json",
		{ "value": 2 }
	)
	remote.set_record(
		"b.json",
		{ "value": 2 }
	)

	var result: Dictionary = sync.sync_many(
		PackedStringArray(["a.json", "b.json"]),
		local,
		remote
	)
	var counts: Dictionary = GFVariantData.get_option_dictionary(result, "status_counts")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"批量同步应整体成功。"
	)
	assert_eq(
		GFVariantData.get_option_int(counts, "copied_local_to_remote"),
		1,
		"应统计复制项。"
	)
	assert_eq(
		GFVariantData.get_option_int(counts, "unchanged"),
		1,
		"应统计未变化项。"
	)


func test_failover_backend_reads_first_available_backend_with_structured_report() -> void:
	var primary: FailoverTestBackend = FailoverTestBackend.new()
	var secondary: FailoverTestBackend = FailoverTestBackend.new()
	primary.load_error = ERR_UNAVAILABLE
	secondary.set_record(
		"profile.json",
		{ "coins": 42 }
	)
	var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
	var configured_backends: Array[GFStorageBackend] = [primary, secondary]

	assert_true(
		backend.configure_backends(
			configured_backends,
			PackedStringArray(["primary", "secondary"])
		)
	)
	var result: Dictionary = backend.load_data("profile.json")
	var report: Dictionary = backend.get_last_operation_report()
	var attempts: Array = GFVariantData.get_option_array(report, "attempts")

	assert_true(
		GFVariantData.get_option_bool(result, "ok"),
		"主后端不可用时应读取次后端。"
	)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(result, "data"),
			"coins"
		),
		42
	)
	assert_eq(
		GFVariantData.get_option_string_name(report, "selected_backend_id"),
		&"secondary"
	)
	assert_eq(
		attempts.size(),
		2,
		"报告应保留每次有界尝试。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(attempts[0]),
			"status"
		),
		"failed"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(attempts[1]),
			"status"
		),
		"succeeded"
	)


func test_failover_failed_reads_preserve_unknown_and_copy_only_all_missing() -> void:
	var cases: Array[Dictionary] = [
		{
			"primary": ERR_TIMEOUT,
			"secondary": ERR_FILE_NOT_FOUND,
			"expected": ERR_TIMEOUT,
			"copy": false,
		},
		{
			"primary": ERR_FILE_NOT_FOUND,
			"secondary": ERR_TIMEOUT,
			"expected": ERR_TIMEOUT,
			"copy": false,
		},
		{
			"primary": ERR_TIMEOUT,
			"secondary": ERR_UNAUTHORIZED,
			"expected": ERR_UNAUTHORIZED,
			"copy": false,
		},
		{
			"primary": ERR_FILE_NOT_FOUND,
			"secondary": ERR_DOES_NOT_EXIST,
			"expected": ERR_DOES_NOT_EXIST,
			"copy": true,
		},
	]
	for raw_code: Variant in [
		OK,
		str(int(ERR_FILE_NOT_FOUND)),
		float(ERR_FILE_NOT_FOUND),
	]:
		for raw_first: bool in [true, false]:
			var ambiguous_case: Dictionary = {
				"primary": ERR_TIMEOUT if raw_first else ERR_FILE_NOT_FOUND,
				"secondary": ERR_FILE_NOT_FOUND if raw_first else ERR_TIMEOUT,
				"expected": ERR_CANT_OPEN,
				"copy": false,
			}
			ambiguous_case["primary_raw" if raw_first else "secondary_raw"] = raw_code
			ambiguous_case["primary_attempt" if raw_first else "secondary_attempt"] = ERR_CANT_OPEN
			cases.append(ambiguous_case)
	for case: Dictionary in cases:
		var primary: FailoverTestBackend = FailoverTestBackend.new()
		var secondary: FailoverTestBackend = FailoverTestBackend.new()
		primary.load_error = case.get("primary")
		secondary.load_error = case.get("secondary")
		primary.raw_failed_error_code = case.get("primary_raw")
		secondary.raw_failed_error_code = case.get("secondary_raw")
		if primary.load_error not in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST]:
			primary.set_record(
				"profile.json",
				{ "value": "primary-unread" }
			)
		if secondary.load_error not in [ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST]:
			secondary.set_record(
				"profile.json",
				{ "value": "secondary-unread" }
			)
		var primary_before: Dictionary = primary.records.duplicate(true)
		var secondary_before: Dictionary = secondary.records.duplicate(true)
		var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
		var configured_backends: Array[GFStorageBackend] = [primary, secondary]
		assert_true(
			backend.configure_backends(
				configured_backends,
				PackedStringArray(["primary", "secondary"]),
				{ "failure_threshold": 0 }
			)
		)
		var load_result: Dictionary = backend.load_data("profile.json")
		var report: Dictionary = backend.get_last_operation_report()
		var attempts: Array = GFVariantData.get_option_array(report, "attempts")
		var load_error_value: Variant = load_result.get("error_code")
		var report_error_value: Variant = report.get("error_code")
		var expected_error: int = GFVariantData.get_option_int(case, "expected")
		assert_true(load_error_value is int)
		if load_error_value is int:
			var load_error_code: int = load_error_value
			assert_eq(load_error_code, expected_error)
		assert_true(report_error_value is int)
		if report_error_value is int:
			var report_error_code: int = report_error_value
			assert_eq(report_error_code, expected_error)
		assert_eq(
			attempts.size(),
			2
		)
		var primary_error_value: Variant = GFVariantData.as_dictionary(attempts[0]).get("error_code")
		var secondary_error_value: Variant = GFVariantData.as_dictionary(attempts[1]).get("error_code")
		var expected_primary_error: int = GFVariantData.get_option_int(
			case,
			"primary_attempt",
			GFVariantData.get_option_int(case, "primary")
		)
		var expected_secondary_error: int = GFVariantData.get_option_int(
			case,
			"secondary_attempt",
			GFVariantData.get_option_int(case, "secondary")
		)
		assert_true(primary_error_value is int)
		if primary_error_value is int:
			var primary_error_code: int = primary_error_value
			assert_eq(primary_error_code, expected_primary_error)
		assert_true(secondary_error_value is int)
		if secondary_error_value is int:
			var secondary_error_code: int = secondary_error_value
			assert_eq(secondary_error_code, expected_secondary_error)
		var local: MemoryStorageBackend = MemoryStorageBackend.new()
		local.set_record(
			"profile.json",
			{ "value": "local-healthy" }
		)
		var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()
		var result: Dictionary = sync.sync_data(
			"profile.json",
			local,
			backend
		)
		var should_copy: bool = GFVariantData.get_option_bool(case, "copy")
		assert_eq(
			GFResultDictionary.is_ok(result),
			should_copy
		)
		assert_eq(
			primary.save_calls,
			1 if should_copy else 0
		)
		assert_eq(secondary.save_calls, 0)
		assert_eq(local.save_count, 0)
		if should_copy:
			var copied_record: Variant = primary.records.get("profile.json")
			assert_true(copied_record is Dictionary)
			if copied_record is Dictionary:
				var copied_dictionary: Dictionary = copied_record
				assert_eq(
					copied_dictionary,
					{ "value": "local-healthy" }
				)
		else:
			assert_eq(
				primary.records,
				primary_before,
				"后续 missing 不能授权覆盖未读 primary。"
			)
			assert_eq(secondary.records, secondary_before)


func test_failover_skipped_reads_do_not_authorize_missing_sync_copy() -> void:
	for use_cooldown: bool in [true, false]:
		var primary: FailoverTestBackend = FailoverTestBackend.new()
		var secondary: FailoverTestBackend = FailoverTestBackend.new()
		primary.set_record(
			"profile.json",
			{ "value": "primary-unread" }
		)
		var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
		var configured_backends: Array[GFStorageBackend] = [primary, secondary]
		assert_true(
			backend.configure_backends(
				configured_backends,
				PackedStringArray(["primary", "secondary"]),
				{ "failure_threshold": 1, "cooldown_msec": 1000 }
			)
		)
		var clock: FailoverTestClock = FailoverTestClock.new()
		assert_true(backend.set_clock(clock))
		if use_cooldown:
			primary.load_error = ERR_TIMEOUT
			var _warmup: Dictionary = backend.load_data("profile.json")
			primary.load_error = OK
		else:
			primary.can_read = false
		var local: MemoryStorageBackend = MemoryStorageBackend.new()
		local.set_record(
			"profile.json",
			{ "value": "local-healthy" }
		)
		var sync: GFStorageSyncUtility = GFStorageSyncUtility.new()

		var result: Dictionary = sync.sync_data(
			"profile.json",
			local,
			backend
		)
		var report: Dictionary = backend.get_last_operation_report()
		var attempts: Array = GFVariantData.get_option_array(report, "attempts")

		assert_false(
			GFResultDictionary.is_ok(result),
			"未读后端仍是 unknown，后续 missing 不能证明逻辑记录不存在。"
		)
		var remote_error_value: Variant = GFVariantData.as_dictionary(result.get("remote")).get("error_code")
		assert_true(remote_error_value is int)
		if remote_error_value is int:
			var remote_error_code: int = remote_error_value
			assert_eq(remote_error_code, ERR_UNAVAILABLE)
		var operation_value: Variant = report.get("operation")
		assert_true(operation_value is StringName)
		if operation_value is StringName:
			var operation: StringName = operation_value
			assert_eq(operation, &"load")
		var reason_value: Variant = GFVariantData.as_dictionary(attempts[0]).get("reason")
		assert_true(reason_value is String)
		if reason_value is String:
			var reason: String = reason_value
			assert_eq(
				reason,
				"cooldown" if use_cooldown else "unsupported"
			)
		assert_eq(
			primary.load_calls,
			1 if use_cooldown else 0
		)
		assert_eq(primary.save_calls, 0)
		assert_eq(secondary.save_calls, 0)
		assert_eq(local.save_count, 0)
		var retained_record: Variant = primary.records.get("profile.json")
		assert_true(retained_record is Dictionary)
		if retained_record is Dictionary:
			var retained_dictionary: Dictionary = retained_record
			assert_eq(
				retained_dictionary,
				{ "value": "primary-unread" }
			)
		assert_false(secondary.records.has("profile.json"))


func test_failover_backend_cooldown_skips_unhealthy_primary_then_allows_probe() -> void:
	var primary: FailoverTestBackend = FailoverTestBackend.new()
	var secondary: FailoverTestBackend = FailoverTestBackend.new()
	primary.save_error = ERR_UNAVAILABLE
	var clock: FailoverTestClock = FailoverTestClock.new()
	var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
	var configured_backends: Array[GFStorageBackend] = [primary, secondary]
	assert_true(
		backend.configure_backends(
			configured_backends,
			PackedStringArray(["primary", "secondary"]),
			{ "failure_threshold": 1, "cooldown_msec": 1000, }
		)
	)
	assert_true(backend.set_clock(clock))

	assert_eq(
		backend.save_data(
			"first.json",
			{ "value": 1 }
		),
		OK
	)
	assert_eq(primary.save_calls, 1)
	assert_eq(secondary.save_calls, 1)
	assert_eq(
		backend.save_data(
			"second.json",
			{ "value": 2 }
		),
		OK
	)
	var cooldown_report: Dictionary = backend.get_last_operation_report()
	var cooldown_attempts: Array = GFVariantData.get_option_array(cooldown_report, "attempts")
	assert_eq(
		primary.save_calls,
		1,
		"静默期内不应重复调用已打开熔断的主后端。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(cooldown_attempts[0]),
			"reason"
		),
		"cooldown"
	)

	clock.advance_msec(1000)
	primary.save_error = OK
	assert_eq(
		backend.save_data(
			"third.json",
			{ "value": 3 }
		),
		OK
	)
	var recovery_report: Dictionary = backend.get_last_operation_report()
	assert_eq(
		primary.save_calls,
		2,
		"冷却结束后应允许主后端探测恢复。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(recovery_report, "selected_backend_id"),
		&"primary"
	)
	assert_false(
		secondary.records.has("third.json"),
		"FIRST_SUCCESS 不应在主后端成功后继续写入。"
	)


func test_failover_backend_primary_only_does_not_hide_primary_write_failure() -> void:
	var primary: FailoverTestBackend = FailoverTestBackend.new()
	var secondary: FailoverTestBackend = FailoverTestBackend.new()
	primary.save_error = ERR_FILE_CANT_WRITE
	var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
	var configured_backends: Array[GFStorageBackend] = [primary, secondary]
	assert_true(
		backend.configure_backends(
			configured_backends,
			PackedStringArray(["primary", "secondary"]),
			{ "mutation_policy": GFStorageFailoverBackend.MutationPolicy.PRIMARY_ONLY }
		)
	)

	var error: Error = backend.save_data(
		"profile.json",
		{ "coins": 7 }
	)
	var report: Dictionary = backend.get_last_operation_report()

	assert_eq(error, ERR_FILE_CANT_WRITE)
	assert_eq(primary.save_calls, 1)
	assert_eq(
		secondary.save_calls,
		0,
		"PRIMARY_ONLY 不应隐式把写入转移到次后端。"
	)
	assert_false(GFVariantData.get_option_bool(report, "ok"))


func test_failover_backend_rejects_invalid_options_transactionally() -> void:
	var primary: FailoverTestBackend = FailoverTestBackend.new()
	var secondary: FailoverTestBackend = FailoverTestBackend.new()
	var replacement: FailoverTestBackend = FailoverTestBackend.new()
	var backend: GFStorageFailoverBackend = GFStorageFailoverBackend.new()
	var configured_backends: Array[GFStorageBackend] = [primary, secondary]
	assert_true(
		backend.configure_backends(
			configured_backends,
			PackedStringArray(["primary", "secondary"]),
			{ "mutation_policy": GFStorageFailoverBackend.MutationPolicy.PRIMARY_ONLY }
		)
	)

	var replacement_backends: Array[GFStorageBackend] = [replacement]
	assert_false(
		backend.configure_backends(
			replacement_backends,
			PackedStringArray(["replacement"]),
			{ "mutation_policy": 99 }
		)
	)
	var snapshot: Dictionary = backend.get_health_snapshot()

	assert_eq(
		backend.get_backend_ids(),
		PackedStringArray(["primary", "secondary"])
	)
	assert_eq(
		GFVariantData.get_option_int(snapshot, "mutation_policy"),
		GFStorageFailoverBackend.MutationPolicy.PRIMARY_ONLY,
		"非法配置不应部分替换既有写入策略。"
	)
	assert_eq(
		backend.get_backend_count(),
		2,
		"非法配置不应部分替换既有后端。"
	)

	assert_true(
		backend.configure_backends(
			replacement_backends,
			PackedStringArray(["replacement"])
		)
	)
	assert_eq(
		GFVariantData.get_option_int(
			backend.get_health_snapshot(),
			"mutation_policy"
		),
		GFStorageFailoverBackend.MutationPolicy.FIRST_SUCCESS,
		"完整重新配置省略选项时应恢复声明默认值。"
	)
