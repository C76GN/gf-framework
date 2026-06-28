## 测试 GFRemoteCacheUtility 的缓存命中、JSON 解析与失败回退。
extends GutTest


# --- 私有变量 ---

var _cache: FakeRemoteCacheUtility


# --- 测试生命周期 ---

func before_each() -> void:
	_cache = FakeRemoteCacheUtility.new()
	_cache.cache_dir_name = "gf_remote_cache_test_%d" % Time.get_ticks_usec()
	_cache.init()
	_cache.clear_cache()


func after_each() -> void:
	if _cache != null:
		_cache.clear_cache()
		_cache.dispose()
		_cache = null


# --- 测试 ---

func test_cache_dir_name_sanitizes_empty_and_traversal_values() -> void:
	var sentinel_path: String = "user://gf_remote_cache_sentinel_%d.txt" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(sentinel_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 根目录哨兵文件。")
	if file != null:
		var _store_result: Variant = file.store_string("keep")
		file.close()

	_cache.cache_dir_name = ""
	_cache.clear_cache()
	assert_true(FileAccess.file_exists(sentinel_path), "空 cache_dir_name 不应导致 clear_cache 删除 user:// 根文件。")
	assert_eq(
		GFVariantData.get_option_string(_cache.get_debug_snapshot(), "cache_dir_path"),
		"user://gf_remote_cache",
		"空 cache_dir_name 应回退到稳定默认目录。"
	)

	_cache.cache_dir_name = "../unsafe/cache"
	assert_eq(
		GFVariantData.get_option_string(_cache.get_debug_snapshot(), "cache_dir_path"),
		"user://gf_remote_cache",
		"带 traversal 的 cache_dir_name 应回退到稳定默认目录。"
	)

	var _remove_error: Error = DirAccess.remove_absolute(sentinel_path)


func test_fetch_text_writes_and_reuses_cache() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "payload",
	})

	_cache.fetch_text("https://example.test/text", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	_cache.fetch_text("https://example.test/text", func(result: Dictionary) -> void:
		results.append(result)
	)

	assert_eq(results.size(), 2, "第二次请求应直接命中缓存。")
	assert_eq(_cache.request_count, 1, "缓存命中不应再次启动 HTTP 请求。")
	var first_result: Dictionary = results[0]
	var cached_result: Dictionary = results[1]
	assert_false(GFVariantData.get_option_bool(first_result, "from_cache"), "首次请求不应来自缓存。")
	assert_true(GFVariantData.get_option_bool(cached_result, "from_cache"), "第二次请求应来自缓存。")
	assert_eq(GFVariantData.get_option_string(cached_result, "content"), "payload", "缓存内容应保持一致。")


func test_fetch_text_overwrites_cache_without_sidecar_files() -> void:
	var cache_key: String = "stable-cache-key"
	var url: String = "https://example.test/text"
	_cache.cache_key_builder = func(_url: String, _headers: PackedStringArray, _format: StringName) -> String:
		return cache_key
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "first",
	})
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "second",
	})

	_cache.fetch_text(url)
	await get_tree().process_frame
	_cache.fetch_text(url, Callable(), -1, true)
	await get_tree().process_frame

	var cache_file_name: String = "%s.cache" % cache_key.md5_text()
	var cache_file_names: PackedStringArray = _list_file_names(
		GFVariantData.get_option_string(_cache.get_debug_snapshot(), "cache_dir_path")
	)

	assert_eq(_cache.get_cached_text(url), "second", "缓存提交后应读取最新内容。")
	assert_true(cache_file_names.has(cache_file_name), "最终缓存文件应存在。")
	assert_false(cache_file_names.has("%s.tmp" % cache_file_name), "提交后不应残留临时文件。")
	assert_false(cache_file_names.has("%s.bak" % cache_file_name), "提交后不应残留备份文件。")


func test_fetch_json_parses_data() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "{\"value\":3}",
	})

	_cache.fetch_json("https://example.test/json", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	assert_eq(results.size(), 1, "JSON 请求应返回一次结果。")
	var json_result: Dictionary = results[0]
	assert_true(GFVariantData.get_option_bool(json_result, "success"), "合法 JSON 应返回成功。")
	var data: Dictionary = GFVariantData.get_option_dictionary(json_result, "data")
	assert_eq(GFVariantData.get_option_int(data, "value"), 3, "JSON 内容应被解析到 data。")


func test_invalid_json_response_is_not_written_to_cache() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "{invalid",
	})

	_cache.fetch_json("https://example.test/bad_json", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "{\"value\":4}",
	})
	_cache.fetch_json("https://example.test/bad_json", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	assert_eq(_cache.request_count, 2, "无效 JSON 不应写入缓存并阻止后续刷新。")
	var invalid_result: Dictionary = results[0]
	var valid_result: Dictionary = results[1]
	assert_false(GFVariantData.get_option_bool(invalid_result, "success"), "无效 JSON 应返回失败。")
	assert_true(GFVariantData.get_option_bool(valid_result, "success"), "后续合法 JSON 应可成功返回。")
	var data: Dictionary = GFVariantData.get_option_dictionary(valid_result, "data")
	assert_eq(GFVariantData.get_option_int(data, "value"), 4, "合法 JSON 应被解析。")


func test_cache_key_separates_text_and_json_for_same_url() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "plain",
	})
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "{\"value\":5}",
	})

	_cache.fetch_text("https://example.test/shared", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame
	_cache.fetch_json("https://example.test/shared", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	assert_eq(_cache.request_count, 2, "同 URL 的 text/json 缓存不应串用。")
	var text_result: Dictionary = results[0]
	var json_result: Dictionary = results[1]
	assert_eq(GFVariantData.get_option_string(text_result, "content"), "plain", "文本缓存应保留原始文本。")
	var data: Dictionary = GFVariantData.get_option_dictionary(json_result, "data")
	assert_eq(GFVariantData.get_option_int(data, "value"), 5, "JSON 请求应读取独立响应。")


func test_failed_refresh_uses_stale_cache() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "old",
	})
	_cache.fetch_text("https://example.test/fallback", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	_cache.responses.append({
		"success": false,
		"response_code": 500,
		"error": "server failed",
	})
	_cache.fetch_text("https://example.test/fallback", func(result: Dictionary) -> void:
		results.append(result)
	, -1, true)
	await get_tree().process_frame

	assert_eq(results.size(), 2, "刷新失败也应返回回调结果。")
	var fallback_result: Dictionary = results[1]
	assert_true(GFVariantData.get_option_bool(fallback_result, "success"), "存在陈旧缓存时刷新失败应回退成功。")
	assert_true(GFVariantData.get_option_bool(fallback_result, "from_cache"), "刷新失败回退结果应来自缓存。")
	assert_true(GFVariantData.get_option_bool(fallback_result, "stale"), "刷新失败回退结果应标记为陈旧缓存。")
	assert_eq(GFVariantData.get_option_string(fallback_result, "content"), "old", "刷新失败应返回此前缓存内容。")


func test_same_cache_key_requests_are_coalesced() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({
		"success": true,
		"response_code": 200,
		"content": "shared",
	})

	_cache.fetch_text("https://example.test/coalesced", func(result: Dictionary) -> void:
		results.append(result)
	)
	_cache.fetch_text("https://example.test/coalesced", func(result: Dictionary) -> void:
		results.append(result)
	)
	await get_tree().process_frame

	assert_eq(_cache.request_count, 1, "相同缓存 key 的并发请求应合并为一次 HTTP。")
	assert_eq(results.size(), 2, "合并请求仍应回调所有调用方。")
	var shared_result: Dictionary = results[0]
	assert_eq(GFVariantData.get_option_string(shared_result, "content"), "shared", "合并请求应共享同一结果。")


func test_pending_request_limit_rejects_excess_requests() -> void:
	var results: Array[Dictionary] = []
	_cache.max_pending_requests = 1
	_cache.responses.append({ "success": true, "response_code": 200, "content": "a" })
	_cache.responses.append({ "success": true, "response_code": 200, "content": "b" })

	_cache.fetch_text("https://example.test/a", func(result: Dictionary) -> void:
		results.append(result)
	)
	_cache.fetch_text("https://example.test/b", func(result: Dictionary) -> void:
		results.append(result)
	)
	_cache.fetch_text("https://example.test/c", func(result: Dictionary) -> void:
		results.append(result)
	)

	assert_eq(results.size(), 1, "超过 pending 上限的请求应立即回调失败。")
	var rejected_result: Dictionary = results[0]
	assert_false(GFVariantData.get_option_bool(rejected_result, "success"), "超过 pending 上限的请求应失败。")
	assert_eq(GFVariantData.get_option_string(rejected_result, "error"), "Pending request limit exceeded", "失败原因应明确。")
	await get_tree().process_frame
	await get_tree().process_frame


func test_cancel_drops_pending_request_without_callback() -> void:
	var results: Array[Dictionary] = []
	_cache.responses.append({ "success": true, "response_code": 200, "content": "a" })
	_cache.responses.append({ "success": true, "response_code": 200, "content": "b" })

	_cache.fetch_text("https://example.test/active", func(result: Dictionary) -> void:
		results.append(result)
	)
	_cache.fetch_text("https://example.test/pending", func(result: Dictionary) -> void:
		results.append(result)
	)
	var cancelled: int = _cache.cancel("https://example.test/pending")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(cancelled, 1, "取消 pending 请求应返回取消数量。")
	assert_eq(results.size(), 1, "被取消的 pending 请求不应触发回调。")
	var active_result: Dictionary = results[0]
	assert_eq(GFVariantData.get_option_string(active_result, "content"), "a", "未取消的 active 请求应正常完成。")


func _list_file_names(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result

	var _list_dir_begin_result_260: Variant = dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var _append_result_264: Variant = result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


# --- 辅助子类 ---

class FakeRemoteCacheUtility:
	extends GFRemoteCacheUtility

	var responses: Array[Dictionary] = []
	var request_count: int = 0

	func _start_http_request(_request_data: Dictionary) -> Error:
		request_count += 1
		var response: Dictionary = {
			"success": true,
			"response_code": 200,
			"content": "",
			"error": "",
		}
		if not responses.is_empty():
			response = responses.pop_front()

		call_deferred(
			"_complete_active_request",
			GFVariantData.get_option_bool(response, "success", true),
			GFVariantData.get_option_int(response, "response_code", 200),
			GFVariantData.get_option_string(response, "content"),
			GFVariantData.get_option_string(response, "error")
		)
		return OK
