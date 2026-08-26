extends GutTest


# --- 常量 ---

const GF_BOUNDED_ZIP_SUPPORT = preload("res://addons/gf/tools/config_pipeline/gf_bounded_zip_support.gd")
const TEST_ROOT: String = "res://ai_analysis/tmp_config_pipeline_bounded_zip_support"


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_remove_path_recursive(TEST_ROOT)
	var _make_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEST_ROOT)
	)


func after_each() -> void:
	_remove_path_recursive(TEST_ROOT)


# --- 测试用例 ---

func test_session_allows_bounded_read_of_valid_entry() -> void:
	var archive_path: String = TEST_ROOT.path_join("valid.zip")
	_write_zip(archive_path, {
		"data/item.txt": "payload",
	})

	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	var inspection: Dictionary = GF_BOUNDED_ZIP_SUPPORT.get_inspection(
		session
	)
	var read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"data/item.txt"
	)
	var close_result: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)

	assert_true(_option_bool(session, "ok"), "有效 ZIP 应创建受控读取会话。")
	assert_true(_option_bool(inspection, "ok"), "有效 ZIP 应通过有界预检：%s" % [_issues(inspection)])
	assert_gt(
		_option_int(inspection, "compressed_work_bytes"),
		0,
		"有效非空 ZIP 应报告实际绑定的压缩数据工作量。"
	)
	assert_lte(
		_option_int(inspection, "compressed_work_bytes"),
		_option_int(inspection, "archive_size_bytes"),
		"唯一压缩区间的累计哈希工作不得超过归档本身。"
	)
	assert_true(_option_bool(read_result, "ok"), "已预检 entry 应可受控读取。")
	assert_eq(close_result, OK, "读取会话应可显式关闭并清理快照。")
	assert_eq(
		_option_bytes(read_result, "bytes").get_string_from_utf8(),
		"payload",
		"受控读取应返回原始 entry 内容。"
	)


func test_inspection_rejects_archive_and_entry_count_budgets() -> void:
	var archive_path: String = TEST_ROOT.path_join("count.zip")
	_write_zip(archive_path, {
		"a.txt": "a",
		"b.txt": "b",
	})
	var archive_limits: Dictionary = _default_limits()
	archive_limits["max_archive_bytes"] = 1
	var count_limits: Dictionary = _default_limits()
	count_limits["max_entry_count"] = 1

	var archive_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		archive_limits
	)
	var count_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		count_limits
	)

	assert_false(_option_bool(archive_result, "ok"), "ZIP 原始文件大小必须先受硬预算限制。")
	assert_true(
		_issue_codes(archive_result).has("archive_size_limit"),
		"原始 ZIP 超限应返回稳定 issue code。"
	)
	assert_false(_option_bool(count_result, "ok"), "中央目录 entry 数量超限必须拒绝。")
	assert_true(
		_issue_codes(count_result).has("entry_count_limit"),
		"entry 数量超限应在任何解压前被识别。"
	)


func test_inspection_rejects_declared_size_and_compression_ratio_budgets() -> void:
	var archive_path: String = TEST_ROOT.path_join("sizes.zip")
	_write_zip(archive_path, {
		"a.txt": _repeat_text("a", 4096),
		"b.txt": _repeat_text("b", 4096),
	})
	var entry_limits: Dictionary = _default_limits()
	entry_limits["max_entry_uncompressed_bytes"] = 1024
	var total_limits: Dictionary = _default_limits()
	total_limits["max_total_uncompressed_bytes"] = 4096
	var ratio_limits: Dictionary = _default_limits()
	ratio_limits["max_compression_ratio"] = 2

	var entry_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		entry_limits
	)
	var total_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		total_limits
	)
	var ratio_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		ratio_limits
	)

	assert_true(
		_issue_codes(entry_result).has("entry_size_limit"),
		"单项声明解压大小应在 read_file 前受限。"
	)
	assert_true(
		_issue_codes(total_result).has("total_size_limit"),
		"全 archive 声明解压总量应在 read_file 前受限。"
	)
	assert_true(
		_issue_codes(ratio_result).has("compression_ratio_limit"),
		"异常压缩比应在 read_file 前受限。"
	)


func test_inspection_rejects_compressed_input_budget_before_read() -> void:
	var archive_path: String = TEST_ROOT.path_join("compressed_input.zip")
	_write_zip(archive_path, {
		"entry.txt": _repeat_text("bounded-input-", 64),
	})
	var limits: Dictionary = _default_limits()
	limits["max_entry_compressed_bytes"] = 1

	var result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		limits
	)

	assert_false(
		_option_bool(result, "ok"),
		"单项压缩输入必须在任何整项分配或解压前受硬预算限制。"
	)
	assert_true(
		_issue_codes(result).has("entry_compressed_size_limit"),
		"压缩输入超限应返回稳定 issue code。"
	)


func test_inspection_rejects_nonportable_alias_and_path_budgets() -> void:
	var alias_path: String = TEST_ROOT.path_join("alias.zip")
	_write_zip(alias_path, {
		"Data/Item.txt": "a",
		"data/item.txt": "b",
	})
	var long_path: String = TEST_ROOT.path_join("long.zip")
	_write_zip(long_path, {
		"deep/path/item.txt": "value",
	})
	var limits: Dictionary = _default_limits()
	limits["max_path_length"] = 8
	limits["max_path_depth"] = 2

	var alias_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		alias_path,
		_default_limits()
	)
	var long_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		long_path,
		limits
	)

	assert_true(
		_issue_codes(alias_result).has("duplicate_portable_path"),
		"大小写别名必须按 portable identity 拒绝。"
	)
	assert_true(
		_issue_codes(long_result).has("path_length_limit"),
		"entry 路径长度必须有界。"
	)
	assert_true(
		_issue_codes(long_result).has("path_depth_limit"),
		"entry 路径深度必须有界。"
	)


func test_inspection_rejects_encrypted_and_unsupported_compression_headers() -> void:
	var encrypted_path: String = TEST_ROOT.path_join("encrypted.zip")
	_write_zip(encrypted_path, { "entry.txt": "value" })
	_patch_first_entry_flags(encrypted_path, 0x0001)
	var unsupported_path: String = TEST_ROOT.path_join("unsupported.zip")
	_write_zip(unsupported_path, { "entry.txt": "value" })
	_patch_first_entry_compression_method(unsupported_path, 99)

	var encrypted_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		encrypted_path,
		_default_limits()
	)
	var unsupported_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		unsupported_path,
		_default_limits()
	)

	assert_true(
		_issue_codes(encrypted_result).has("encrypted_entry_unsupported"),
		"加密 flag 必须在调用 ZIPReader.read_file 前拒绝。"
	)
	assert_true(
		_issue_codes(unsupported_result).has("compression_method_unsupported"),
		"不受支持的压缩格式必须显式拒绝。"
	)


func test_inspection_rejects_truncated_and_zip64_archives() -> void:
	var truncated_path: String = TEST_ROOT.path_join("truncated.zip")
	_write_zip(truncated_path, { "entry.txt": "value" })
	var truncated_bytes: PackedByteArray = _read_bytes(truncated_path)
	var _resize_error: Error = truncated_bytes.resize(
		truncated_bytes.size() - 5
	) as Error
	_write_bytes(truncated_path, truncated_bytes)
	var zip64_path: String = TEST_ROOT.path_join("zip64.zip")
	_write_zip(zip64_path, { "entry.txt": "value" })
	_patch_eocd_uint16(zip64_path, 10, 0xffff)

	var truncated_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		truncated_path,
		_default_limits()
	)
	var zip64_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		zip64_path,
		_default_limits()
	)

	assert_false(_option_bool(truncated_result, "ok"), "截断 EOCD 的 ZIP 必须拒绝。")
	assert_true(
		_issue_codes(truncated_result).has("missing_central_directory"),
		"截断 ZIP 应报告中央目录 footer 缺失。"
	)
	assert_true(
		_issue_codes(zip64_result).has("zip64_unsupported"),
		"ZIP64 sentinel 必须被显式识别，不能按 32 位 ZIP 继续解析。"
	)


func test_controlled_read_checks_caller_budget_before_read() -> void:
	var archive_path: String = TEST_ROOT.path_join("read_bounds.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)

	var pre_read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt",
		4
	)
	var accepted_read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt",
		5
	)
	var repeated_read_result: Dictionary = (
		GF_BOUNDED_ZIP_SUPPORT.read_entry(
			session,
			"entry.txt",
			5
		)
	)
	var _close_result: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)

	assert_false(_option_bool(pre_read_result, "ok"), "声明大小超出调用方预算时不得读取。")
	assert_eq(
		_option_int(pre_read_result, "actual_size_bytes", -1),
		-1,
		"read 前预算失败不应产生实际字节结果。"
	)
	assert_true(
		_option_bool(accepted_read_result, "ok"),
		"静态预算拒绝不得提前消费 entry。"
	)
	assert_false(
		_option_bool(repeated_read_result, "ok"),
		"成功开始读取后同一 session 不得重复消费 entry。"
	)
	assert_eq(
		_option_int(repeated_read_result, "error_code"),
		ERR_ALREADY_IN_USE
	)


func test_session_enforces_one_shot_entries_with_exact_cumulative_budget() -> void:
	var archive_path: String = TEST_ROOT.path_join("session_total.zip")
	_write_zip(archive_path, {
		"first.txt": "1234",
		"second.txt": "56789",
	})
	var limits: Dictionary = _default_limits()
	limits["max_total_uncompressed_bytes"] = 9
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		limits
	)

	var first_read: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"first.txt"
	)
	var second_read: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"second.txt"
	)
	var repeated_read: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"first.txt"
	)
	var close_error: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)

	assert_true(_option_bool(first_read, "ok"))
	assert_true(
		_option_bool(second_read, "ok"),
		"累计实际读取字节等于 session 上限时应精确通过。"
	)
	assert_false(_option_bool(repeated_read, "ok"))
	assert_eq(_option_int(repeated_read, "error_code"), ERR_ALREADY_IN_USE)
	assert_eq(close_error, OK)


func test_session_reads_the_bound_snapshot_and_closed_copies_fail() -> void:
	var archive_path: String = TEST_ROOT.path_join("snapshot.zip")
	_write_zip(archive_path, { "entry.txt": "original" })
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	var copied_session: Dictionary = session.duplicate(true)
	_write_zip(archive_path, { "entry.txt": "replacement" })

	var read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt"
	)
	var close_result: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)
	var closed_read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		copied_session,
		"entry.txt"
	)

	assert_eq(
		_option_bytes(read_result, "bytes").get_string_from_utf8(),
		"original",
		"会话必须读取预检时绑定的不可变快照，而不是后来被替换的源路径。"
	)
	assert_eq(close_result, OK, "原始会话应可关闭。")
	assert_false(
		_option_bool(closed_read_result, "ok"),
		"任意复制的已关闭会话句柄都必须失效。"
	)
	assert_eq(
		_option_int(closed_read_result, "error_code"),
		ERR_INVALID_PARAMETER
	)


func test_snapshot_cleanup_requires_the_current_process_owner_marker() -> void:
	var archive_path: String = TEST_ROOT.path_join("marker.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	assert_true(_option_bool(session, "ok"))
	var process_root: String = GF_BOUNDED_ZIP_SUPPORT._process_session_root
	var marker_path: String = process_root.path_join(
		GF_BOUNDED_ZIP_SUPPORT._PROCESS_ROOT_MARKER_FILE
	)
	var marker_bytes: PackedByteArray = _read_bytes(marker_path)
	var owned_paths: Array = GF_BOUNDED_ZIP_SUPPORT._owned_snapshots.keys()
	assert_eq(owned_paths.size(), 1)
	var snapshot_path: String = str(owned_paths[0]) if not owned_paths.is_empty() else ""
	_write_bytes(marker_path, "tampered".to_utf8_buffer())

	var refused_close: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(
		session
	)

	assert_eq(
		refused_close,
		ERR_UNAUTHORIZED,
		"process marker 漂移时 cleanup 必须拒绝按路径删除。"
	)
	assert_true(
		FileAccess.file_exists(snapshot_path),
		"身份不可信的 snapshot 必须保留给显式恢复，不能盲删。"
	)
	_write_bytes(marker_path, marker_bytes)
	var retry_error: Error = (
		GF_BOUNDED_ZIP_SUPPORT._retry_pending_snapshot_cleanup()
	)
	assert_eq(retry_error, OK)
	assert_false(FileAccess.file_exists(snapshot_path))


func test_snapshot_materialization_retries_pending_cleanup_under_one_lock() -> void:
	var archive_path: String = TEST_ROOT.path_join("atomic_cleanup.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	assert_true(_option_bool(session, "ok"))
	var process_root: String = GF_BOUNDED_ZIP_SUPPORT._process_session_root
	var marker_path: String = process_root.path_join(
		GF_BOUNDED_ZIP_SUPPORT._PROCESS_ROOT_MARKER_FILE
	)
	var marker_bytes: PackedByteArray = _read_bytes(marker_path)
	var owned_paths: Array = GF_BOUNDED_ZIP_SUPPORT._owned_snapshots.keys()
	assert_eq(owned_paths.size(), 1)
	var snapshot_path: String = (
		str(owned_paths[0]) if not owned_paths.is_empty() else ""
	)
	_write_bytes(marker_path, "tampered".to_utf8_buffer())
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT.close_archive(session),
		ERR_UNAUTHORIZED
	)

	var blocked_result: Dictionary = (
		GF_BOUNDED_ZIP_SUPPORT._materialize_archive_snapshot(
			archive_path,
			_default_limits(),
			{}
		)
	)

	assert_false(
		_option_bool(blocked_result, "ok"),
		"未完成的旧快照清理必须阻止同一临界区中的新快照物化。"
	)
	assert_true(
		_issue_codes(blocked_result).has("snapshot_cleanup_blocked"),
		"快照 helper 必须在持有 snapshot mutex 时先重试 pending cleanup。"
	)
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._owned_snapshots.size(),
		1,
		"pending cleanup 失败后不得登记或复制另一个快照。"
	)
	_write_bytes(marker_path, marker_bytes)
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._retry_pending_snapshot_cleanup(),
		OK
	)
	assert_false(FileAccess.file_exists(snapshot_path))


func test_session_capacity_counts_active_and_in_flight_opens() -> void:
	var archive_path: String = TEST_ROOT.path_join("capacity.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var active_session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	assert_true(_option_bool(active_session, "ok"))
	var in_flight_count: int = (
		GF_BOUNDED_ZIP_SUPPORT._ABSOLUTE_MAX_ACTIVE_SESSIONS - 1
	)
	for _index: int in range(in_flight_count):
		assert_true(
			GF_BOUNDED_ZIP_SUPPORT._reserve_session_capacity(),
			"硬上限内的 opening session 应能预留容量。"
		)
	var snapshot_count_before: int = (
		GF_BOUNDED_ZIP_SUPPORT._owned_snapshots.size()
	)
	var reserved_bytes_before: int = (
		GF_BOUNDED_ZIP_SUPPORT._reserved_snapshot_bytes
	)

	var rejected_session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)

	assert_false(
		_option_bool(rejected_session, "ok"),
		"active 与 in-flight open 合计达到硬上限后必须失败关闭。"
	)
	assert_true(
		_issue_codes(rejected_session).has("session_capacity"),
		"容量拒绝应返回稳定 issue code。"
	)
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._owned_snapshots.size(),
		snapshot_count_before,
		"容量应在昂贵快照复制前预留并拒绝。"
	)
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._reserved_snapshot_bytes,
		reserved_bytes_before,
		"容量拒绝不得增加进程快照字节预留。"
	)
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._pending_session_reservations,
		in_flight_count,
		"被拒绝的 open 不得消费或泄漏其他 in-flight reservation。"
	)
	for _index: int in range(in_flight_count):
		GF_BOUNDED_ZIP_SUPPORT._release_session_capacity_reservation()
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT.close_archive(active_session),
		OK
	)
	assert_eq(GF_BOUNDED_ZIP_SUPPORT._pending_session_reservations, 0)
	assert_true(GF_BOUNDED_ZIP_SUPPORT._active_sessions.is_empty())


func test_open_releases_failed_reservation_and_consumes_successful_one() -> void:
	var missing_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		TEST_ROOT.path_join("missing.zip"),
		_default_limits()
	)
	assert_false(_option_bool(missing_result, "ok"))
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._pending_session_reservations,
		0,
		"快照创建失败后必须释放 opening session reservation。"
	)
	assert_true(GF_BOUNDED_ZIP_SUPPORT._active_sessions.is_empty())
	var archive_path: String = TEST_ROOT.path_join("consume.zip")
	_write_zip(archive_path, { "entry.txt": "value" })

	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)

	assert_true(_option_bool(session, "ok"))
	assert_eq(
		GF_BOUNDED_ZIP_SUPPORT._pending_session_reservations,
		0,
		"成功注册必须原子消费自己的 opening reservation。"
	)
	assert_eq(GF_BOUNDED_ZIP_SUPPORT._active_sessions.size(), 1)
	assert_eq(GF_BOUNDED_ZIP_SUPPORT.close_archive(session), OK)
	assert_true(GF_BOUNDED_ZIP_SUPPORT._active_sessions.is_empty())


func test_session_can_be_owned_and_consumed_by_a_worker_thread() -> void:
	var archive_path: String = TEST_ROOT.path_join("worker_owned.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var worker: Thread = Thread.new()
	assert_eq(
		worker.start(
			_open_and_read_zip_from_worker.bind(
				archive_path,
				_default_limits()
			)
		),
		OK,
		"测试 worker 应能启动。"
	)
	var worker_value: Variant = worker.wait_to_finish()
	var worker_result: Dictionary = (
		worker_value if worker_value is Dictionary else {}
	)
	var session: Dictionary = (
		worker_result.get("session")
		if worker_result.get("session") is Dictionary
		else {}
	)
	var inspection: Dictionary = (
		worker_result.get("inspection")
		if worker_result.get("inspection") is Dictionary
		else {}
	)
	var files: PackedStringArray = (
		worker_result.get("files")
		if worker_result.get("files") is PackedStringArray
		else PackedStringArray()
	)
	var read_result: Dictionary = (
		worker_result.get("read")
		if worker_result.get("read") is Dictionary
		else {}
	)

	assert_true(
		_option_bool(session, "ok"),
		"后台 worker 应能创建有界 ZIP 会话。"
	)
	assert_true(
		_option_bool(inspection, "ok"),
		"会话 owner worker 应能查询预检结果。"
	)
	assert_eq(files, PackedStringArray(["entry.txt"]))
	assert_true(
		_option_bool(read_result, "ok"),
		"会话 owner worker 应能读取受控 entry。"
	)
	assert_eq(
		_option_bytes(read_result, "bytes").get_string_from_utf8(),
		"value"
	)
	assert_eq(
		_option_int(worker_result, "close_error", ERR_BUG),
		OK,
		"会话 owner worker 应能完成句柄与快照清理。"
	)


func test_session_rejects_cross_thread_access_without_invalidating_owner() -> void:
	var archive_path: String = TEST_ROOT.path_join("thread.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)
	var worker: Thread = Thread.new()
	assert_eq(
		worker.start(_query_zip_session_from_worker.bind(session.duplicate(true))),
		OK,
		"测试 worker 应能启动。"
	)
	var worker_value: Variant = worker.wait_to_finish()
	var worker_result: Dictionary = (
		worker_value if worker_value is Dictionary else {}
	)
	var worker_inspection: Dictionary = (
		worker_result.get("inspection")
		if worker_result.get("inspection") is Dictionary
		else {}
	)
	var worker_files: PackedStringArray = (
		worker_result.get("files")
		if worker_result.get("files") is PackedStringArray
		else PackedStringArray()
	)
	var worker_read: Dictionary = (
		worker_result.get("read")
		if worker_result.get("read") is Dictionary
		else {}
	)
	var worker_close_error: int = _option_int(
		worker_result,
		"close_error",
		ERR_BUG
	)
	var main_read: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt"
	)
	var close_error: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)

	assert_true(
		_issue_codes(worker_inspection).has("wrong_thread"),
		"非 owner worker 查询 inspection 必须失败关闭。"
	)
	assert_true(worker_files.is_empty(), "非 owner worker 不得读取 session 文件表。")
	assert_false(_option_bool(worker_read, "ok"), "非 owner worker 不得读取共享归档游标。")
	assert_eq(_option_int(worker_read, "error_code"), ERR_UNAUTHORIZED)
	assert_eq(
		worker_close_error,
		ERR_UNAUTHORIZED,
		"非 owner worker 不得关闭句柄或清理 owner 的快照。"
	)
	assert_true(_option_bool(main_read, "ok"), "跨线程拒绝不得破坏 owner 会话。")
	assert_eq(close_error, OK)


func test_controlled_read_rejects_crc_mismatch() -> void:
	var archive_path: String = TEST_ROOT.path_join("crc.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	_patch_first_entry_crc32(archive_path, 0)
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		_default_limits()
	)

	var read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt"
	)
	assert_engine_error(
		"Condition \"err != 1\" is true",
		"Godot 的有界 gzip 解压器应拒绝错误的 CRC32 trailer。"
	)
	var inspection: Dictionary = GF_BOUNDED_ZIP_SUPPORT.get_inspection(
		session
	)
	var _close_result: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)

	assert_true(
		_option_bool(inspection, "ok"),
		"local/central 一致但内容 CRC 错误应留给受控读取识别。"
	)
	assert_false(
		_option_bool(read_result, "ok"),
		"长度相同的损坏内容也必须失败关闭。"
	)
	assert_eq(_option_int(read_result, "error_code"), ERR_FILE_CORRUPT)


func test_limits_are_closed_exact_and_bounded_by_framework_absolutes() -> void:
	var archive_path: String = TEST_ROOT.path_join("limits.zip")
	_write_zip(archive_path, { "entry.txt": "value" })
	var unknown_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		{ "unknown_limit": 1 }
	)
	var float_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		{ "max_entry_count": 1.0 }
	)
	var absolute_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		{ "max_entry_count": 20_001 }
	)

	assert_false(_option_bool(unknown_result, "ok"), "未知预算字段必须失败关闭。")
	assert_true(
		_issue_codes(unknown_result).has("invalid_limit_option"),
		"闭合 schema 应返回稳定 issue code。"
	)
	assert_false(_option_bool(float_result, "ok"), "预算必须是精确 int。")
	assert_false(_option_bool(absolute_result, "ok"), "调用方不得抬高框架绝对上限。")
	assert_true(
		_issue_codes(absolute_result).has("invalid_limit_value"),
		"越过绝对上限应返回稳定 issue code。"
	)


func test_inspection_rejects_central_directory_and_file_prefix_conflicts() -> void:
	var archive_path: String = TEST_ROOT.path_join("prefix.zip")
	_write_zip(archive_path, {
		"data": "file",
		"data/item.txt": "child",
	})
	var central_limits: Dictionary = _default_limits()
	central_limits["max_central_directory_bytes"] = 1

	var prefix_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		_default_limits()
	)
	var central_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		central_limits
	)

	assert_true(
		_issue_codes(prefix_result).has("file_directory_prefix_conflict"),
		"文件路径不得同时成为另一 entry 的目录前缀。"
	)
	assert_true(
		_issue_codes(central_result).has("central_directory_size_limit"),
		"中央目录本身必须受独立字节预算约束。"
	)


func test_inspection_rejects_duplicate_local_record_before_compressed_work() -> void:
	var archive_path: String = TEST_ROOT.path_join("duplicate_local_record.zip")
	_write_zip(archive_path, {
		"first.txt": _repeat_text("first-payload-", 128),
		"other.txt": _repeat_text("other-payload-", 128),
	})
	_patch_second_entry_local_offset_to_first(archive_path)

	var result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		_default_limits()
	)

	assert_false(
		_option_bool(result, "ok"),
		"复用同一 local record 的多个 central entry 必须失败关闭。"
	)
	assert_true(
		_issue_codes(result).has("duplicate_local_header"),
		"重复 local offset 应返回稳定 issue code。"
	)
	assert_eq(
		_option_int(result, "compressed_work_bytes", -1),
		0,
		"结构预检失败后不得对重复 compressed range 执行 SHA-256 工作。"
	)


func test_inspection_rejects_overlapping_local_records_before_compressed_work() -> void:
	var archive_path: String = TEST_ROOT.path_join("overlapping_local_records.zip")
	_write_zip(archive_path, {
		"first.txt": _repeat_text("first-payload-", 64),
		"second.txt": _repeat_text("second-payload-", 64),
	})
	_expand_first_compressed_range_into_second_record(archive_path)

	var result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		_default_limits()
	)

	assert_false(
		_option_bool(result, "ok"),
		"声明相互重叠的不同 local record 必须失败关闭。"
	)
	assert_true(
		_issue_codes(result).has("overlapping_entry_records"),
		"重叠 local record 应返回稳定 issue code。"
	)
	assert_eq(
		_option_int(result, "compressed_work_bytes", -1),
		0,
		"全部结构与区间校验通过前不得执行任何 compressed range 哈希。"
	)


func test_inspection_rejects_unicode_portable_path_aliases() -> void:
	var archive_path: String = TEST_ROOT.path_join("unicode.zip")
	_write_zip(archive_path, { "data/café.txt": "value" })

	var result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.inspect_archive(
		archive_path,
		_default_limits()
	)

	assert_false(
		_option_bool(result, "ok"),
		"portable ZIP 路径必须限制为 ASCII，避免 Unicode 文件系统别名。"
	)
	assert_true(
		_issue_codes(result).has("unsafe_entry_path"),
		"Unicode entry 应在建立 portable identity 前失败关闭。"
	)


# --- 私有/辅助方法 ---

func _default_limits() -> Dictionary:
	return {
		"max_archive_bytes": 1024 * 1024,
		"max_entry_count": 32,
		"max_entry_compressed_bytes": 16 * 1024,
		"max_entry_uncompressed_bytes": 16 * 1024,
		"max_total_uncompressed_bytes": 32 * 1024,
		"max_compression_ratio": 100,
		"max_path_length": 128,
		"max_path_depth": 8,
		"max_central_directory_bytes": 64 * 1024,
	}


func _query_zip_session_from_worker(session: Dictionary) -> Dictionary:
	return {
		"inspection": GF_BOUNDED_ZIP_SUPPORT.get_inspection(session),
		"files": GF_BOUNDED_ZIP_SUPPORT.get_files(session),
		"read": GF_BOUNDED_ZIP_SUPPORT.read_entry(
			session,
			"entry.txt"
		),
		"close_error": GF_BOUNDED_ZIP_SUPPORT.close_archive(session),
	}


func _open_and_read_zip_from_worker(
	archive_path: String,
	limits: Dictionary
) -> Dictionary:
	var session: Dictionary = GF_BOUNDED_ZIP_SUPPORT.open_archive(
		archive_path,
		limits
	)
	if not _option_bool(session, "ok"):
		return {
			"session": session,
			"inspection": {},
			"files": PackedStringArray(),
			"read": {},
			"close_error": ERR_INVALID_PARAMETER,
		}
	var inspection: Dictionary = GF_BOUNDED_ZIP_SUPPORT.get_inspection(
		session
	)
	var files: PackedStringArray = GF_BOUNDED_ZIP_SUPPORT.get_files(
		session
	)
	var read_result: Dictionary = GF_BOUNDED_ZIP_SUPPORT.read_entry(
		session,
		"entry.txt"
	)
	var close_error: Error = GF_BOUNDED_ZIP_SUPPORT.close_archive(session)
	return {
		"session": session,
		"inspection": inspection,
		"files": files,
		"read": read_result,
		"close_error": close_error,
	}


func _write_zip(path: String, entries: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var _make_result: Error = DirAccess.make_dir_recursive_absolute(
		absolute_path.get_base_dir()
	)
	var writer: ZIPPacker = ZIPPacker.new()
	assert_eq(writer.open(absolute_path), OK, "测试应能创建 ZIP。")
	var entry_paths: PackedStringArray = PackedStringArray()
	for entry_key: Variant in entries.keys():
		var _path_appended: bool = entry_paths.append(str(entry_key))
	entry_paths.sort()
	for entry_path: String in entry_paths:
		assert_eq(writer.start_file(entry_path), OK, "测试应能创建 ZIP entry。")
		var write_error: Error = writer.write_file(str(entries.get(entry_path)).to_utf8_buffer())
		assert_eq(write_error, OK, "测试应能写入 ZIP entry。")
		assert_eq(writer.close_file(), OK, "测试应能关闭 ZIP entry。")
	assert_eq(writer.close(), OK, "测试应能关闭 ZIP。")


func _patch_first_entry_flags(path: String, flags: int) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var local_offset: int = _find_signature(bytes, PackedByteArray([0x50, 0x4b, 0x03, 0x04]))
	var central_offset: int = _find_signature(bytes, PackedByteArray([0x50, 0x4b, 0x01, 0x02]))
	assert_gte(local_offset, 0, "测试 ZIP 应包含 local header。")
	assert_gte(central_offset, 0, "测试 ZIP 应包含 central header。")
	_write_uint16_le(bytes, local_offset + 6, flags)
	_write_uint16_le(bytes, central_offset + 8, flags)
	_write_bytes(path, bytes)


func _patch_first_entry_compression_method(path: String, compression_method: int) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var local_offset: int = _find_signature(bytes, PackedByteArray([0x50, 0x4b, 0x03, 0x04]))
	var central_offset: int = _find_signature(bytes, PackedByteArray([0x50, 0x4b, 0x01, 0x02]))
	assert_gte(local_offset, 0, "测试 ZIP 应包含 local header。")
	assert_gte(central_offset, 0, "测试 ZIP 应包含 central header。")
	_write_uint16_le(bytes, local_offset + 8, compression_method)
	_write_uint16_le(bytes, central_offset + 10, compression_method)
	_write_bytes(path, bytes)


func _patch_first_entry_crc32(path: String, crc32: int) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var local_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x03, 0x04])
	)
	var central_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x01, 0x02])
	)
	assert_gte(local_offset, 0, "测试 ZIP 应包含 local header。")
	assert_gte(central_offset, 0, "测试 ZIP 应包含 central header。")
	_write_uint32_le(bytes, local_offset + 14, crc32)
	_write_uint32_le(bytes, central_offset + 16, crc32)
	_write_bytes(path, bytes)


func _patch_eocd_uint16(path: String, relative_offset: int, value: int) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var eocd_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x05, 0x06])
	)
	assert_gte(eocd_offset, 0, "测试 ZIP 应包含 EOCD。")
	_write_uint16_le(bytes, eocd_offset + relative_offset, value)
	_write_bytes(path, bytes)


func _patch_second_entry_local_offset_to_first(path: String) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var local_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x03, 0x04])
	)
	var first_central_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x01, 0x02])
	)
	var second_central_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x01, 0x02]),
		first_central_offset + 4
	)
	assert_gte(local_offset, 0, "测试 ZIP 应包含 local header。")
	assert_gte(first_central_offset, 0, "测试 ZIP 应包含首个 central header。")
	assert_gte(second_central_offset, 0, "测试 ZIP 应包含第二个 central header。")
	_write_uint32_le(bytes, second_central_offset + 42, local_offset)
	_write_bytes(path, bytes)


func _expand_first_compressed_range_into_second_record(path: String) -> void:
	var bytes: PackedByteArray = _read_bytes(path)
	var first_local_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x03, 0x04])
	)
	var second_local_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x03, 0x04]),
		first_local_offset + 4
	)
	var first_central_offset: int = _find_signature(
		bytes,
		PackedByteArray([0x50, 0x4b, 0x01, 0x02])
	)
	assert_gte(first_local_offset, 0, "测试 ZIP 应包含首个 local header。")
	assert_gte(second_local_offset, 0, "测试 ZIP 应包含第二个 local header。")
	assert_gte(first_central_offset, 0, "测试 ZIP 应包含首个 central header。")
	var first_data_offset: int = (
		first_local_offset
		+ 30
		+ _read_uint16_le(bytes, first_local_offset + 26)
		+ _read_uint16_le(bytes, first_local_offset + 28)
	)
	var overlapping_compressed_size: int = (
		second_local_offset - first_data_offset + 1
	)
	assert_gt(
		overlapping_compressed_size,
		0,
		"恶意声明应覆盖到第二个 local record。"
	)
	_write_uint32_le(
		bytes,
		first_local_offset + 18,
		overlapping_compressed_size
	)
	_write_uint32_le(
		bytes,
		first_central_offset + 20,
		overlapping_compressed_size
	)
	_write_bytes(path, bytes)


func _find_signature(
	bytes: PackedByteArray,
	signature: PackedByteArray,
	start_offset: int = 0
) -> int:
	if signature.is_empty() or bytes.size() < signature.size():
		return -1
	for offset: int in range(
		maxi(start_offset, 0),
		bytes.size() - signature.size() + 1
	):
		var matches: bool = true
		for signature_index: int in range(signature.size()):
			if bytes[offset + signature_index] != signature[signature_index]:
				matches = false
				break
		if matches:
			return offset
	return -1


func _read_uint16_le(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8)


func _write_uint16_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff


func _write_uint32_le(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = value & 0xff
	bytes[offset + 1] = (value >> 8) & 0xff
	bytes[offset + 2] = (value >> 16) & 0xff
	bytes[offset + 3] = (value >> 24) & 0xff


func _read_bytes(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 ZIP。")
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能改写 ZIP。")
	if file == null:
		return
	var _store_result: bool = file.store_buffer(bytes)
	file.close()


func _repeat_text(value: String, count: int) -> String:
	var result: String = ""
	for _index: int in range(count):
		result += value
	return result


func _remove_path_recursive(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return
	var _list_error: Error = directory.list_dir_begin()
	var item_name: String = directory.get_next()
	while not item_name.is_empty():
		var child_path: String = absolute_path.path_join(item_name)
		if directory.current_is_dir():
			_remove_path_recursive(child_path)
		else:
			var _remove_file_error: Error = DirAccess.remove_absolute(child_path)
		item_name = directory.get_next()
	directory.list_dir_end()
	var _remove_directory_error: Error = DirAccess.remove_absolute(absolute_path)


func _issues(result: Dictionary) -> PackedStringArray:
	var value: Variant = result.get("issues")
	return value if value is PackedStringArray else PackedStringArray()


func _issue_codes(result: Dictionary) -> PackedStringArray:
	var value: Variant = result.get("issue_codes")
	return value if value is PackedStringArray else PackedStringArray()


func _option_bool(options: Dictionary, key: String, fallback: bool = false) -> bool:
	var value: Variant = options.get(key)
	return value if value is bool else fallback


func _option_int(options: Dictionary, key: String, fallback: int = 0) -> int:
	var value: Variant = options.get(key)
	return value if value is int else fallback


func _option_bytes(options: Dictionary, key: String) -> PackedByteArray:
	var value: Variant = options.get(key)
	return value if value is PackedByteArray else PackedByteArray()


func _option_array(options: Dictionary, key: String) -> Array:
	var value: Variant = options.get(key)
	return value if value is Array else []
