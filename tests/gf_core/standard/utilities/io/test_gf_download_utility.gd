## 测试 GFDownloadUtility 的临时提交、续传、校验与取消行为。
extends GutTest

# --- 私有变量 ---

var _utility: FakeDownloadUtility
var _paths: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = FakeDownloadUtility.new()
	_utility.init()
	_paths.clear()


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
		_utility = null
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var _remove_error: Error = DirAccess.remove_absolute(path)


# --- 测试 ---

func test_enqueue_download_commits_temp_and_reports_success() -> void:
	var target: String = _track_path("user://gf_download_success_%d.txt" % Time.get_ticks_usec())
	var results: Array[Dictionary] = []
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var handle: int = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)

	assert_gt(handle, 0, "有效下载应返回任务句柄。")
	assert_eq(_read_text(target), "ok", "下载完成后应提交到目标文件。")
	assert_eq(results.size(), 1, "完成回调应执行一次。")
	assert_true(GFVariantData.get_option_bool(download_result, "success"), "成功结果应标记 success。")
	assert_eq(GFVariantData.get_option_int(_utility.get_result(handle), "status"), GFDownloadTask.Status.COMPLETED, "任务结果应记录完成状态。")


func test_resume_download_appends_segment_when_server_returns_partial_content() -> void:
	var target: String = _track_path("user://gf_download_resume_%d.txt" % Time.get_ticks_usec())
	var temp: String = _track_path(target + ".download")
	var _segment: String = _track_path(temp + ".segment")
	_write_text(temp, "old")
	_utility.responses.append({ "success": true, "response_code": 206, "content": "new" })

	var _enqueue_download_result_54: Variant = _utility.enqueue_download(
		"https://example.test/file",
		target,
		Callable(),
		{ "resume": true }
	)
	await get_tree().process_frame

	var headers: PackedStringArray = _request_headers(0)

	assert_true(headers.has("Range: bytes=3-"), "存在临时文件时应带 Range 头续传。")
	assert_eq(_read_text(target), "oldnew", "206 响应应把分段文件追加到临时文件后再提交。")


func test_enqueue_download_accepts_string_name_options_and_copies_metadata() -> void:
	var target: String = _track_path("user://gf_download_options_%d.txt" % Time.get_ticks_usec())
	var source_metadata: Dictionary = {
		"nested": {
			"value": 1,
		},
	}
	var results: Array[Dictionary] = []
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var handle: int = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		&"overwrite": "on",
		&"max_retries": "1",
		&"metadata": source_metadata,
	})
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)
	var result_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(download_result, "metadata"))
	var result_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result_metadata, "nested"))
	var source_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source_metadata, "nested"))
	result_nested["value"] = 2

	assert_gt(handle, 0, "有效下载应返回任务句柄。")
	assert_true(GFVariantData.get_option_bool(download_result, "success"), "下载应成功。")
	assert_eq(GFVariantData.get_option_int(download_result, "max_retries"), 1, "StringName 选项键和值应被归一读取。")
	assert_eq(GFVariantData.get_option_int(source_nested, "value"), 1, "下载任务 metadata 应复制保存。")


func test_checksum_failure_reports_failed_without_target_commit() -> void:
	var target: String = _track_path("user://gf_download_checksum_%d.txt" % Time.get_ticks_usec())
	var results: Array[Dictionary] = []
	_utility.responses.append({ "success": true, "response_code": 200, "content": "bad" })

	var _enqueue_download_result_102: Variant = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		"expected_sha256": "0000",
	})
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)

	assert_eq(results.size(), 1, "校验失败也应返回结果。")
	assert_false(GFVariantData.get_option_bool(download_result, "success"), "校验失败应标记失败。")
	assert_false(FileAccess.file_exists(target), "校验失败不应提交目标文件。")


func test_existing_target_without_overwrite_accepts_matching_checksum() -> void:
	var target: String = _track_path("user://gf_download_existing_ok_%d.txt" % Time.get_ticks_usec())
	_write_text(target, "cached")
	var checksum: String = FileAccess.get_sha256(target)
	var results: Array[Dictionary] = []

	var handle: int = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		"overwrite": false,
		"expected_sha256": checksum,
	})
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)

	assert_gt(handle, 0, "有效下载应返回任务句柄。")
	assert_true(_utility.request_log.is_empty(), "已有文件校验通过时不应发起 HTTP 请求。")
	assert_eq(results.size(), 1, "已有文件命中也应返回结果。")
	assert_true(GFVariantData.get_option_bool(download_result, "success"), "已有文件 checksum 匹配时应视为完成。")
	assert_true(GFVariantData.get_option_bool(download_result, "from_existing_file"), "结果应标记来自已有目标文件。")
	assert_eq(_read_text(target), "cached", "已有目标文件不应被改写。")


func test_existing_target_without_overwrite_rejects_checksum_mismatch() -> void:
	var target: String = _track_path("user://gf_download_existing_bad_%d.txt" % Time.get_ticks_usec())
	_write_text(target, "cached")
	var results: Array[Dictionary] = []

	var _enqueue_download_result_143: Variant = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		"overwrite": false,
		"expected_sha256": "0000",
	})
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)

	assert_true(_utility.request_log.is_empty(), "已有文件 checksum 不匹配时不应绕过目标文件策略再发起请求。")
	assert_eq(results.size(), 1, "校验失败应返回结果。")
	assert_false(GFVariantData.get_option_bool(download_result, "success"), "checksum 不匹配应标记失败。")
	assert_eq(GFVariantData.get_option_int(download_result, "status"), GFDownloadTask.Status.FAILED, "任务状态应标记失败。")
	assert_true(GFVariantData.get_option_string(download_result, "error").contains("checksum mismatch"), "失败原因应说明 checksum 不匹配。")
	assert_eq(_read_text(target), "cached", "失败时不应改写已有目标文件。")


func test_retryable_failure_requeues_before_reporting_result() -> void:
	var target: String = _track_path("user://gf_download_retry_%d.txt" % Time.get_ticks_usec())
	var results: Array[Dictionary] = []
	_utility.responses.append({
		"success": false,
		"response_code": 0,
		"error": "temporary",
		"retryable": true,
	})
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var handle: int = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		"max_retries": 1,
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var download_result: Dictionary = _first_result(results)

	assert_gt(handle, 0, "有效下载应返回任务句柄。")
	assert_eq(_utility.request_log.size(), 2, "可重试失败应再次发起请求。")
	assert_eq(results.size(), 1, "重试成功后只应报告最终结果。")
	assert_true(GFVariantData.get_option_bool(download_result, "success"), "重试成功应返回成功结果。")
	assert_eq(GFVariantData.get_option_int(download_result, "retry_count"), 1, "结果应记录已重试次数。")
	assert_eq(_read_text(target), "ok", "重试成功后应提交最终文件。")


func test_retryable_http_error_does_not_resume_from_error_body() -> void:
	var target: String = _track_path("user://gf_download_retry_body_%d.txt" % Time.get_ticks_usec())
	var results: Array[Dictionary] = []
	_utility.responses.append({
		"success": false,
		"response_code": 500,
		"content": "server-error",
		"error": "HTTP 500",
	})
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var _enqueue_download_result_199: Variant = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	, {
		"max_retries": 1,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	var retry_headers: PackedStringArray = _request_headers(1)
	var download_result: Dictionary = _first_result(results)

	assert_false(retry_headers.has("Range: bytes=12-"), "HTTP 错误响应体不应被当作可续传内容。")
	assert_eq(results.size(), 1, "重试成功后只应报告最终结果。")
	assert_true(GFVariantData.get_option_bool(download_result, "success"), "HTTP 错误重试成功应返回成功结果。")
	assert_eq(_read_text(target), "ok", "最终文件不应包含错误响应体。")


func test_cancel_active_download_reports_cancelled() -> void:
	var target: String = _track_path("user://gf_download_cancel_%d.txt" % Time.get_ticks_usec())
	_utility.auto_complete = false
	var results: Array[Dictionary] = []

	var handle: int = _utility.enqueue_download("https://example.test/file", target, func(result: Dictionary) -> void:
		results.append(result)
	)
	var cancelled: bool = _utility.cancel(handle, true)
	var download_result: Dictionary = _first_result(results)
	var active_task: Dictionary = GFVariantData.get_option_dictionary(_utility.get_debug_snapshot(), "active_task")

	assert_true(cancelled, "当前下载任务应可取消。")
	assert_eq(results.size(), 1, "取消应触发回调结果。")
	assert_true(GFVariantData.get_option_bool(download_result, "cancelled"), "取消结果应标记 cancelled。")
	assert_true(active_task.is_empty(), "取消后不应保留 active_task。")


func test_parse_manifest_entries_normalizes_defaults_and_metadata() -> void:
	var checksum: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var manifest: Dictionary = {
		"base_url": "https://cdn.example.test/assets",
		"default_headers": PackedStringArray(["Accept: application/octet-stream"]),
		"metadata": {
			"channel": "stable",
		},
		"files": [
			{
				"path": "audio/theme.ogg",
				"sha256": checksum,
				"size": 12,
			},
			{
				"url": "https://other.example.test/ui.png",
				"target_path": "ui/ui.png",
				"headers": {
					"X-Test": "1",
				},
				"metadata": {
					"kind": "ui",
				},
			},
		],
	}

	var entries: Array[Dictionary] = GFDownloadUtility.parse_manifest_entries(manifest)
	var first: Dictionary = entries[0]
	var second: Dictionary = entries[1]
	var first_headers: PackedStringArray = GFVariantData.get_option_packed_string_array(first, "headers")
	var second_headers: PackedStringArray = GFVariantData.get_option_packed_string_array(second, "headers")
	var first_metadata: Dictionary = GFVariantData.get_option_dictionary(first, "metadata")
	var second_metadata: Dictionary = GFVariantData.get_option_dictionary(second, "metadata")

	assert_eq(entries.size(), 2, "清单应解析为两个标准条目。")
	assert_eq(GFVariantData.get_option_string(first, "url"), "https://cdn.example.test/assets/audio/theme.ogg", "相对 URL 应按 base_url 解析。")
	assert_eq(GFVariantData.get_option_string(first, "target_path"), "audio/theme.ogg", "path 应作为默认目标路径。")
	assert_eq(GFVariantData.get_option_string(first, "expected_sha256"), checksum, "sha256 应映射为 expected_sha256。")
	assert_eq(GFVariantData.get_option_int(first, "expected_size"), 12, "size 应映射为 expected_size。")
	assert_true(first_headers.has("Accept: application/octet-stream"), "默认请求头应复制到条目。")
	assert_eq(GFVariantData.get_option_string(first_metadata, "channel"), "stable", "清单 metadata 应复制到条目。")
	assert_true(second_headers.has("X-Test: 1"), "条目请求头应转换为 HTTP 头字符串。")
	assert_eq(GFVariantData.get_option_string(second_metadata, "kind"), "ui", "条目 metadata 应覆盖到标准条目。")


func test_enqueue_manifest_batches_entries_under_target_root_and_metadata() -> void:
	var file_a: String = "gf_download_manifest_a_%d.txt" % Time.get_ticks_usec()
	var file_b: String = "gf_download_manifest_b_%d.txt" % Time.get_ticks_usec()
	var target_a: String = _track_path("user://" + file_a)
	var target_b: String = _track_path("user://" + file_b)
	var results: Array[Dictionary] = []
	_utility.responses.append({ "success": true, "response_code": 200, "content": "aa" })
	_utility.responses.append({ "success": true, "response_code": 200, "content": "bb" })

	var ids: PackedInt32Array = _utility.enqueue_manifest([
		{
			"url": "https://example.test/a.txt",
			"target_path": file_a,
			"size": 2,
		},
		{
			"url": "https://example.test/b.txt",
			"target_path": file_b,
			"metadata": {
				"label": "b",
			},
		},
	], "user://", func(result: Dictionary) -> void:
		results.append(result)
	, {
		"metadata": {
			"batch": "main",
		},
		"overwrite": true,
		"temp_path": "user://gf_download_manifest_shared_temp.tmp",
	})
	await get_tree().process_frame
	await get_tree().process_frame
	var first_metadata: Dictionary = GFVariantData.get_option_dictionary(results[0], "metadata")
	var second_metadata: Dictionary = GFVariantData.get_option_dictionary(results[1], "metadata")

	assert_eq(ids.size(), 2, "有效清单条目应全部入队。")
	assert_eq(_read_text(target_a), "aa", "第一个清单条目应写入 target_root 下的目标路径。")
	assert_eq(_read_text(target_b), "bb", "第二个清单条目应写入 target_root 下的目标路径。")
	assert_eq(results.size(), 2, "批量回调应按每个任务执行一次。")
	assert_eq(GFVariantData.get_option_string(first_metadata, "batch"), "main", "批量 metadata 应透传到任务结果。")
	assert_eq(GFVariantData.get_option_int(first_metadata, "manifest_index"), 0, "任务 metadata 应包含清单索引。")
	assert_eq(GFVariantData.get_option_string(second_metadata, "label"), "b", "条目 metadata 应透传到任务结果。")
	assert_ne(GFVariantData.get_option_string(results[0], "temp_path"), "user://gf_download_manifest_shared_temp.tmp", "批量默认 temp_path 不应被复用到每个条目。")


func test_get_tasks_progress_aggregates_manifest_results() -> void:
	var file_a: String = "gf_download_progress_a_%d.txt" % Time.get_ticks_usec()
	var file_b: String = "gf_download_progress_b_%d.txt" % Time.get_ticks_usec()
	var _target_a: String = _track_path("user://" + file_a)
	var _target_b: String = _track_path("user://" + file_b)
	_utility.responses.append({ "success": true, "response_code": 200, "content": "aa" })
	_utility.responses.append({ "success": true, "response_code": 200, "content": "bb" })

	var ids: PackedInt32Array = _utility.enqueue_manifest([
		{
			"url": "https://example.test/a.txt",
			"target_path": file_a,
			"size": 2,
		},
		{
			"url": "https://example.test/b.txt",
			"target_path": file_b,
			"size": 2,
		},
	], "user://")
	await get_tree().process_frame
	await get_tree().process_frame

	var progress: Dictionary = _utility.get_tasks_progress(ids)

	assert_eq(GFVariantData.get_option_int(progress, "task_count"), 2, "聚合进度应记录任务总数。")
	assert_eq(GFVariantData.get_option_int(progress, "completed_count"), 2, "全部完成时应统计完成数。")
	assert_true(GFVariantData.get_option_bool(progress, "finished"), "全部终态且无缺失时应标记 finished。")
	assert_true(GFVariantData.get_option_bool(progress, "success"), "全部成功完成时应标记 success。")
	assert_eq(GFVariantData.get_option_int(progress, "total_bytes"), 4, "清单 expected_size 应作为聚合总字节数。")
	assert_eq(GFVariantData.get_option_int(progress, "received_bytes"), 4, "完成任务应使用 expected_size 补足接收字节数。")
	assert_almost_eq(GFVariantData.get_option_float(progress, "progress_ratio"), 1.0, 0.001, "全部完成时进度比例应为 1。")


func test_get_tasks_progress_aggregates_large_pending_queue() -> void:
	_utility.auto_complete = false
	var manifest: Array[Dictionary] = []
	for index: int in range(512):
		manifest.append({
			"url": "https://example.test/%d.txt" % index,
			"target_path": "gf_download_large_pending_%d_%d.txt" % [Time.get_ticks_usec(), index],
			"size": 10,
		})
	var ids: PackedInt32Array = _utility.enqueue_manifest(manifest, "user://")
	var _append_result: bool = ids.append(999_999)

	var progress: Dictionary = _utility.get_tasks_progress(ids)

	assert_eq(ids.size(), 513, "测试输入应包含大量有效任务与一个缺失任务。")
	assert_eq(GFVariantData.get_option_int(progress, "task_count"), 513, "聚合进度应保留输入任务总数。")
	assert_eq(GFVariantData.get_option_int(progress, "running_count"), 1, "当前下载任务应统计为 running。")
	assert_eq(GFVariantData.get_option_int(progress, "queued_count"), 511, "等待队列应一次性聚合为 queued。")
	assert_eq(GFVariantData.get_option_int(progress, "missing_count"), 1, "不存在的任务 ID 应统计为 missing。")
	assert_eq(GFVariantData.get_option_int(progress, "known_total_bytes"), 5120, "大队列聚合应保留清单 size 总和。")


func test_enqueue_manifest_rejects_unsafe_relative_targets() -> void:
	var file_name: String = "gf_download_manifest_safe_%d.txt" % Time.get_ticks_usec()
	var target: String = _track_path("user://" + file_name)
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var ids: PackedInt32Array = _utility.enqueue_manifest([
		{
			"url": "https://example.test/escape.txt",
			"target_path": "../escape.txt",
		},
		{
			"url": "https://example.test/escape-tail.txt",
			"target_path": "folder/..",
		},
		{
			"url": "https://example.test/safe.txt",
			"target_path": file_name,
		},
	], "user://")
	await get_tree().process_frame

	assert_eq(ids.size(), 1, "危险相对目标路径不应入队。")
	assert_eq(_utility.request_log.size(), 1, "只有安全条目应发起下载。")
	assert_eq(_read_text(target), "ok", "安全条目仍应正常写入。")


func test_enqueue_manifest_rejects_absolute_targets_and_escaping_roots() -> void:
	var root_name: String = "gf_download_manifest_root_%d" % Time.get_ticks_usec()
	var safe_target: String = _track_path("user://%s/safe.txt" % root_name)
	var absolute_target: String = _track_path("user://gf_download_manifest_absolute_%d.txt" % Time.get_ticks_usec())
	_utility.responses.append({ "success": true, "response_code": 200, "content": "ok" })

	var ids: PackedInt32Array = _utility.enqueue_manifest([
		{
			"url": "https://example.test/absolute.txt",
			"target_path": absolute_target,
		},
		{
			"url": "https://example.test/safe.txt",
			"target_path": "safe.txt",
		},
	], "user://%s" % root_name)
	var escaped_root_ids: PackedInt32Array = _utility.enqueue_manifest([
		{
			"url": "https://example.test/root-escape.txt",
			"target_path": "escaped.txt",
		},
	], "user://%s/.." % root_name)
	await get_tree().process_frame

	assert_eq(ids.size(), 1, "清单条目必须使用 target_root 下的相对目标。")
	assert_true(escaped_root_ids.is_empty(), "包含 parent traversal 的 target_root 应整体拒绝条目。")
	assert_eq(_utility.request_log.size(), 1, "只有受 target_root 约束的条目应发起请求。")
	assert_eq(_read_text(safe_target), "ok", "安全相对目标仍应写入声明根。")
	assert_false(FileAccess.file_exists(absolute_target), "清单不得以绝对 target_path 绕过 target_root。")


func test_overwrite_commit_failure_restores_previous_target() -> void:
	var target: String = _track_path("user://gf_download_commit_rollback_%d.txt" % Time.get_ticks_usec())
	var temp: String = _track_path(target + ".download")
	var backup: String = _track_path(target + ".gf_download_backup")
	_write_text(target, "old")
	_utility.fail_target_commit_once = true
	_utility.responses.append({ "success": true, "response_code": 200, "content": "new" })
	var results: Array[Dictionary] = []

	var _task_id: int = _utility.enqueue_download(
		"https://example.test/file",
		target,
		func(callback_result: Dictionary) -> void:
			results.append(callback_result),
		{ "overwrite": true }
	)
	await get_tree().process_frame
	var result: Dictionary = _first_result(results)

	assert_false(GFVariantData.get_option_bool(result, "success", true), "最终 rename 失败时任务应失败。")
	assert_eq(_read_text(target), "old", "替换失败必须恢复调用前的目标内容。")
	assert_eq(_read_text(temp), "new", "失败的候选文件应保留以便诊断或重试。")
	assert_false(FileAccess.file_exists(backup), "成功回滚后不应残留备份文件。")


func test_resume_append_write_failure_preserves_previous_temp_content() -> void:
	var target: String = _track_path("user://gf_download_append_failure_%d.txt" % Time.get_ticks_usec())
	var temp: String = _track_path(target + ".download")
	var segment: String = _track_path(temp + ".segment")
	_write_text(temp, "old")
	_utility.fail_append_store_once = true
	_utility.responses.append({ "success": true, "response_code": 206, "content": "new" })
	var results: Array[Dictionary] = []

	var _task_id: int = _utility.enqueue_download(
		"https://example.test/file",
		target,
		func(callback_result: Dictionary) -> void:
			results.append(callback_result),
		{ "resume": true }
	)
	await get_tree().process_frame
	var result: Dictionary = _first_result(results)

	assert_false(GFVariantData.get_option_bool(result, "success", true), "追加写失败必须传播到任务结果。")
	assert_eq(_read_text(temp), "old", "追加失败必须回滚到原临时文件长度。")
	assert_true(FileAccess.file_exists(segment), "失败分段应保留以便诊断或重试。")
	assert_false(FileAccess.file_exists(target), "追加未完整完成时不得提交最终目标。")


func test_enqueue_download_rejects_unsafe_direct_paths() -> void:
	var safe_target: String = _track_path("user://gf_download_direct_safe_%d.txt" % Time.get_ticks_usec())
	var unrelated_temp: String = _track_path("user://gf_download_unrelated_%d.tmp" % Time.get_ticks_usec())

	var unsafe_target_id: int = _utility.enqueue_download("https://example.test/target", "../escape.txt")
	var native_target_id: int = _utility.enqueue_download("https://example.test/native", "C:/gf_escape.txt")
	var unsafe_temp_id: int = _utility.enqueue_download("https://example.test/temp", safe_target, Callable(), {
		"temp_path": "../escape.tmp",
	})
	var unrelated_temp_id: int = _utility.enqueue_download("https://example.test/unrelated", safe_target, Callable(), {
		"temp_path": unrelated_temp,
	})
	var unsafe_segment_id: int = _utility.enqueue_download("https://example.test/segment", safe_target, Callable(), {
		"segment_path": "res://gf_download_other_root.segment",
	})
	await get_tree().process_frame

	assert_eq(unsafe_target_id, 0, "direct target 不应允许 parent traversal。")
	assert_eq(native_target_id, 0, "direct target 不应默认允许原生绝对路径。")
	assert_eq(unsafe_temp_id, 0, "temp_path 不应越过受控根。")
	assert_eq(unrelated_temp_id, 0, "temp_path 即使同属 user:// 也必须由 target 派生。")
	assert_eq(unsafe_segment_id, 0, "segment_path 应与 target 位于同一受控根。")
	assert_eq(_utility.request_log.size(), 0, "无效直接路径不应启动 HTTP 请求。")
	assert_push_error("[GFDownloadUtility] enqueue_download 失败：target_path 不在受控 res:// 或 user:// 根内：../escape.txt。")
	assert_push_error("[GFDownloadUtility] enqueue_download 失败：target_path 不在受控 res:// 或 user:// 根内：C:/gf_escape.txt。")
	assert_push_error("[GFDownloadUtility] enqueue_download 失败：temp_path 由 utility 独占管理，不接受调用方覆盖。")
	assert_push_error("[GFDownloadUtility] enqueue_download 失败：temp_path 由 utility 独占管理，不接受调用方覆盖。")
	assert_push_error("[GFDownloadUtility] enqueue_download 失败：segment_path 由 utility 独占管理，不接受调用方覆盖。")


# --- 私有/辅助方法 ---

func _track_path(path: String) -> String:
	_paths.append(path)
	return path


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	var _store_string_result_245: Variant = file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _first_result(results: Array[Dictionary]) -> Dictionary:
	if results.is_empty():
		return {}
	return results[0]


func _request_headers(index: int) -> PackedStringArray:
	var request_data: Dictionary = _utility.request_log[index]
	return GFVariantData.get_option_packed_string_array(request_data, "headers")


# --- 内部类 ---

class FakeDownloadUtility:
	extends GFDownloadUtility

	var responses: Array[Dictionary] = []
	var request_log: Array[Dictionary] = []
	var auto_complete: bool = true
	var fail_target_commit_once: bool = false
	var fail_append_store_once: bool = false

	func _start_http_request(request_data: Dictionary) -> Error:
		request_log.append(request_data.duplicate(true))
		if not auto_complete:
			return OK

		var response: Dictionary = {
			"success": true,
			"response_code": 200,
			"content": "payload",
			"error": "",
		}
		if not responses.is_empty():
			response = responses.pop_front()

		var download_file_path: String = GFVariantData.get_option_string(request_data, "download_file")
		var file: FileAccess = FileAccess.open(download_file_path, FileAccess.WRITE)
		if file != null:
			var _store_string_result_295: Variant = file.store_string(GFVariantData.get_option_string(response, "content"))
			file.close()

		call_deferred(
			"_complete_active_download",
			GFVariantData.get_option_bool(response, "success", true),
			GFVariantData.get_option_int(response, "response_code", 200),
			GFVariantData.get_option_string(response, "error"),
			GFVariantData.get_option_bool(response, "retryable")
		)
		return OK

	func _rename_file_for_commit(source_path: String, target_path: String) -> Error:
		if fail_target_commit_once and source_path.ends_with(".download"):
			fail_target_commit_once = false
			return ERR_CANT_CREATE
		return super._rename_file_for_commit(source_path, target_path)

	func _store_append_chunk(target: FileAccess, chunk: PackedByteArray) -> Error:
		if fail_append_store_once:
			fail_append_store_once = false
			return ERR_FILE_CANT_WRITE
		return super._store_append_chunk(target, chunk)
