## GFDownloadUtility: 通用文件下载队列。
##
## 提供顺序下载、临时文件提交、可选续传、SHA-256 校验、暂停、取消和诊断快照。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFDownloadUtility
extends GFUtility


# --- 信号 ---

## 下载任务开始时发出。
## [br]
## @api public
## [br]
## @param task_id: 下载任务句柄。
## [br]
## @param task: 下载任务快照。
signal download_started(task_id: int, task: GFDownloadTask)

## 下载进度更新时发出。
## [br]
## @api public
## [br]
## @param task_id: 下载任务句柄。
## [br]
## @param received_bytes: 已接收字节数。
## [br]
## @param total_bytes: 总字节数；未知时为 -1。
signal download_progressed(task_id: int, received_bytes: int, total_bytes: int)

## 下载任务成功完成时发出。
## [br]
## @api public
## [br]
## @param task_id: 下载任务句柄。
## [br]
## @param result: 下载结果字典。
## [br]
## @schema result: Dictionary，包含任务字段、success、cancelled 和可选完成元数据。
signal download_completed(task_id: int, result: Dictionary)

## 下载任务失败时发出。
## [br]
## @api public
## [br]
## @param task_id: 下载任务句柄。
## [br]
## @param result: 下载结果字典。
## [br]
## @schema result: Dictionary，包含任务字段、success、cancelled 和错误详情。
signal download_failed(task_id: int, result: Dictionary)

## 下载任务被取消时发出。
## [br]
## @api public
## [br]
## @param task_id: 下载任务句柄。
## [br]
## @param result: 下载结果字典。
## [br]
## @schema result: Dictionary，包含任务字段、success、cancelled 和取消详情。
signal download_cancelled(task_id: int, result: Dictionary)


# --- 常量 ---

const _APPEND_BUFFER_SIZE_BYTES: int = 64 * 1024


# --- 公共变量 ---

## HTTP 请求超时时间，单位秒。
## [br]
## @api public
var timeout_seconds: float = 30.0

## 临时文件后缀。
## [br]
## @api public
var default_temp_suffix: String = ".download"

## 分段续传临时文件后缀。
## [br]
## @api public
var default_segment_suffix: String = ".segment"

## 目标文件已存在时默认是否覆盖。
## [br]
## @api public
var overwrite_existing: bool = true

## 进度信号最小间隔，单位秒。
## [br]
## @api public
var emit_progress_interval_seconds: float = 0.1

## 默认最大重试次数。
## [br]
## @api public
var default_max_retries: int = 0

## 默认重试等待秒数。
## [br]
## @api public
var default_retry_delay_seconds: float = 0.0


# --- 私有变量 ---

var _pending_tasks: Array[GFDownloadTask] = []
var _active_task: GFDownloadTask = null
var _active_request_data: Dictionary = {}
var _http_request: HTTPRequest = null
var _next_task_id: int = 1
var _paused: bool = false
var _results: Dictionary = {}
var _callbacks: Dictionary = {}
var _last_progress_emit_msec: int = 0


# --- GF 生命周期方法 ---

## 初始化下载队列运行时状态并启用暂停无关处理。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	_pending_tasks.clear()
	_active_task = null
	_active_request_data.clear()
	_next_task_id = 1
	_paused = false
	_results.clear()
	_callbacks.clear()
	_last_progress_emit_msec = 0


## 取消下载、释放 HTTPRequest 并清理运行时状态。
## [br]
## @api public
func dispose() -> void:
	clear_queue(true)
	if is_instance_valid(_http_request):
		_http_request.cancel_request()
		_http_request.queue_free()
	_http_request = null
	_results.clear()
	_callbacks.clear()
	_next_task_id = 1
	_paused = false


## 驱动下载进度采样。
## [br]
## @api public
## [br]
## @param _delta: 为兼容统一 tick 签名而保留的参数。
func tick(_delta: float = 0.0) -> void:
	if _active_task == null:
		_try_start_next_download()
		return
	if not is_instance_valid(_http_request):
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_progress_emit_msec < int(emit_progress_interval_seconds * 1000.0):
		return

	_last_progress_emit_msec = now_msec
	_active_task.received_bytes = int(_http_request.get_downloaded_bytes())
	_active_task.total_bytes = int(_http_request.get_body_size())
	download_progressed.emit(_active_task.task_id, _active_task.received_bytes, _active_task.total_bytes)


# --- 公共方法 ---

## 解析下载清单为标准条目列表。
## [br]
## @api public
## [br]
## @param data: 清单数据，可为 JSON 字符串、条目数组，或包含 files、entries、downloads 字段的字典。
## [br]
## @param options: 解析选项，支持 base_url、headers/default_headers 和 metadata。
## [br]
## @return 标准下载条目数组。
## [br]
## @schema data: Variant，JSON 字符串、Array[Dictionary] 或 Dictionary 清单。
## [br]
## @schema options: Dictionary，可包含 base_url、headers、default_headers 和 metadata。
## [br]
## @schema return: Array[Dictionary]，每个条目包含 url、target_path、headers、metadata 以及可选 expected_sha256、expected_size、resume、overwrite、max_retries、retry_delay_seconds。
## [br]
## @since 5.2.0
static func parse_manifest_entries(data: Variant, options: Dictionary = {}) -> Array[Dictionary]:
	var parsed_data: Variant = _parse_manifest_data(data)
	var raw_entries: Array = _get_manifest_raw_entries(parsed_data)
	var defaults: Dictionary = _build_manifest_defaults(parsed_data, options)
	var result: Array[Dictionary] = []

	for index: int in range(raw_entries.size()):
		var normalized: Dictionary = _normalize_manifest_entry(raw_entries[index], defaults, index)
		if normalized.is_empty():
			continue
		result.append(normalized)

	return result


## 将下载任务加入队列。
## [br]
## @api public
## [br]
## @param url: 下载 URL。
## [br]
## @param target_path: 最终写入路径。
## [br]
## @param callback: 完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。
## [br]
## @param options: 可选参数，支持 headers、resume、overwrite、expected_sha256、metadata、temp_path、segment_path、max_retries、retry_delay_seconds。
## [br]
## @return 任务句柄；输入无效时返回 0。
## [br]
## @schema options: Dictionary，可包含 headers、resume、overwrite、expected_sha256、metadata、temp_path、segment_path、max_retries 和 retry_delay_seconds。
func enqueue_download(
	url: String,
	target_path: String,
	callback: Callable = Callable(),
	options: Dictionary = {}
) -> int:
	if url.is_empty() or target_path.is_empty():
		push_error("[GFDownloadUtility] enqueue_download 失败：url 或 target_path 为空。")
		return 0

	var safe_target_path: String = _normalize_direct_download_path(target_path)
	if safe_target_path.is_empty():
		push_error("[GFDownloadUtility] enqueue_download 失败：target_path 不在受控 res:// 或 user:// 根内：%s。" % target_path)
		return 0

	var default_temp_path: String = safe_target_path + default_temp_suffix
	var temp_path: String = GFVariantData.get_option_string(options, "temp_path", default_temp_path)
	var safe_temp_path: String = _normalize_direct_download_path(temp_path)
	if safe_temp_path.is_empty() or not _download_paths_share_root(safe_target_path, safe_temp_path):
		push_error("[GFDownloadUtility] enqueue_download 失败：temp_path 不在 target_path 同一受控根内：%s。" % temp_path)
		return 0

	var default_segment_path: String = safe_temp_path + default_segment_suffix
	var segment_path: String = GFVariantData.get_option_string(options, "segment_path", default_segment_path)
	var safe_segment_path: String = _normalize_direct_download_path(segment_path)
	if safe_segment_path.is_empty() or not _download_paths_share_root(safe_target_path, safe_segment_path):
		push_error("[GFDownloadUtility] enqueue_download 失败：segment_path 不在 target_path 同一受控根内：%s。" % segment_path)
		return 0

	var task: GFDownloadTask = GFDownloadTask.new()
	task.task_id = _next_task_id
	_next_task_id += 1
	task.url = url
	task.target_path = safe_target_path
	task.temp_path = safe_temp_path
	task.segment_path = safe_segment_path
	task.headers = _normalize_headers(GFVariantData.get_option_value(options, "headers", PackedStringArray()))
	task.expected_sha256 = GFVariantData.get_option_string(options, "expected_sha256").to_lower()
	task.resume = GFVariantData.get_option_bool(options, "resume", true)
	task.overwrite = GFVariantData.get_option_bool(options, "overwrite", overwrite_existing)
	task.max_retries = maxi(0, GFVariantData.get_option_int(options, "max_retries", default_max_retries))
	task.retry_delay_seconds = maxf(0.0, GFVariantData.get_option_float(options, "retry_delay_seconds", default_retry_delay_seconds))
	task.metadata = GFVariantData.get_option_dictionary(options, "metadata")
	if callback.is_valid():
		_callbacks[task.task_id] = callback

	_pending_tasks.append(task)
	_try_start_next_download()
	return task.task_id


## 批量加入标准下载清单条目。
## [br]
## @api public
## [br]
## @param entries: parse_manifest_entries() 返回的标准条目，或兼容字段的条目字典数组。
## [br]
## @param target_root: 相对 target_path 的写入根路径。
## [br]
## @param callback: 每个任务完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。
## [br]
## @param options: 批量默认选项，支持 enqueue_download() 的通用选项。
## [br]
## @return 成功入队的任务句柄数组。
## [br]
## @schema entries: Array[Dictionary]，每个条目至少包含 url 和 target_path/path/file。
## [br]
## @schema options: Dictionary，可包含 headers、resume、overwrite、metadata、max_retries 和 retry_delay_seconds。
## [br]
## @since 5.2.0
func enqueue_manifest_entries(
	entries: Array[Dictionary],
	target_root: String,
	callback: Callable = Callable(),
	options: Dictionary = {}
) -> PackedInt32Array:
	var task_ids: PackedInt32Array = PackedInt32Array()
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var url: String = GFVariantData.get_option_string(entry, "url").strip_edges()
		var target_path: String = _resolve_manifest_target_path(entry, target_root)
		if url.is_empty() or target_path.is_empty():
			continue

		var download_options: Dictionary = _build_manifest_download_options(entry, options, index)
		var task_id: int = enqueue_download(url, target_path, callback, download_options)
		if task_id > 0:
			_append_packed_int32(task_ids, task_id)

	return task_ids


## 解析并批量加入下载清单。
## [br]
## @api public
## [br]
## @param data: 清单数据，可为 JSON 字符串、条目数组，或包含 files、entries、downloads 字段的字典。
## [br]
## @param target_root: 相对 target_path 的写入根路径。
## [br]
## @param callback: 每个任务完成、失败或取消时执行的回调，签名为 func(result: Dictionary)。
## [br]
## @param options: 解析和入队选项，解析阶段支持 base_url、headers/default_headers、metadata，入队阶段支持 enqueue_download() 的通用选项。
## [br]
## @return 成功入队的任务句柄数组。
## [br]
## @schema data: Variant，JSON 字符串、Array[Dictionary] 或 Dictionary 清单。
## [br]
## @schema options: Dictionary，可包含 base_url、headers/default_headers、metadata、resume、overwrite、max_retries 和 retry_delay_seconds。
## [br]
## @since 5.2.0
func enqueue_manifest(
	data: Variant,
	target_root: String,
	callback: Callable = Callable(),
	options: Dictionary = {}
) -> PackedInt32Array:
	var entries: Array[Dictionary] = parse_manifest_entries(data, options)
	var enqueue_options: Dictionary = _strip_manifest_parse_options(options)
	return enqueue_manifest_entries(entries, target_root, callback, enqueue_options)


## 取消下载任务。
## [br]
## @api public
## [br]
## @param task_id: 任务句柄。
## [br]
## @param delete_temp: 是否删除临时文件。
## [br]
## @return 找到并取消任务时返回 true。
func cancel(task_id: int, delete_temp: bool = false) -> bool:
	if task_id <= 0:
		return false

	if _active_task != null and _active_task.task_id == task_id:
		var task: GFDownloadTask = _active_task
		_cancel_and_discard_http_request()
		_active_task = null
		_active_request_data.clear()
		task.status = GFDownloadTask.Status.CANCELLED
		task.error = "cancelled"
		if delete_temp:
			_delete_task_temp_files(task)
		_finish_task(task, false, true)
		_try_start_next_download()
		return true

	for index: int in range(_pending_tasks.size() - 1, -1, -1):
		var task: GFDownloadTask = _pending_tasks[index]
		if task.task_id == task_id:
			_pending_tasks.remove_at(index)
			task.status = GFDownloadTask.Status.CANCELLED
			task.error = "cancelled"
			if delete_temp:
				_delete_task_temp_files(task)
			_finish_task(task, false, true)
			return true
	return false


## 设置下载队列暂停状态。暂停时不会启动新任务，当前任务会保留临时文件并回到队首。
## [br]
## @api public
## [br]
## @param value: 是否暂停。
func set_paused(value: bool) -> void:
	if _paused == value:
		return

	_paused = value
	if _paused:
		_pause_active_task()
	else:
		_try_start_next_download()


## 暂停下载队列。
## [br]
## @api public
func pause() -> void:
	set_paused(true)


## 恢复下载队列。
## [br]
## @api public
func resume() -> void:
	set_paused(false)


## 检查下载队列是否暂停。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_paused() -> bool:
	return _paused


## 清空等待队列，可选取消当前任务。
## [br]
## @api public
## [br]
## @param cancel_active: 是否取消当前任务。
## [br]
## @param delete_temp: 是否删除临时文件。
func clear_queue(cancel_active: bool = false, delete_temp: bool = false) -> void:
	for task: GFDownloadTask in _pending_tasks:
		task.status = GFDownloadTask.Status.CANCELLED
		task.error = "cancelled"
		if delete_temp:
			_delete_task_temp_files(task)
		_finish_task(task, false, true)
	_pending_tasks.clear()

	if cancel_active and _active_task != null:
		var _cancelled: bool = cancel(_active_task.task_id, delete_temp)


## 获取当前正在下载的任务拷贝。
## [br]
## @api public
## [br]
## @return 当前任务；没有任务时返回 null。
func get_active_task() -> GFDownloadTask:
	return _active_task.duplicate_task() if _active_task != null else null


## 获取等待队列中的任务 ID。
## [br]
## @api public
## [br]
## @return 任务 ID 列表。
func get_queued_task_ids() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for task: GFDownloadTask in _pending_tasks:
		_append_packed_int32(result, task.task_id)
	return result


## 获取指定任务最近结果。
## [br]
## @api public
## [br]
## @param task_id: 任务句柄。
## [br]
## @return 结果字典；不存在时返回空字典。
## [br]
## @schema return: Dictionary，包含最新任务结果；没有结果时为空字典。
func get_result(task_id: int) -> Dictionary:
	return GFVariantData.to_dictionary(GFVariantData.get_option_value(_results, task_id, {}))


## 获取指定任务的当前快照或最终结果。
## [br]
## @api public
## [br]
## @param task_id: 任务句柄。
## [br]
## @return 任务快照；不存在时返回空字典。
## [br]
## @schema return: Dictionary，运行中或等待中的任务字段，或最终结果字段。
## [br]
## @since 5.2.0
func get_task_snapshot(task_id: int) -> Dictionary:
	if task_id <= 0:
		return {}
	if _active_task != null and _active_task.task_id == task_id:
		return _active_task.to_dict()
	for task: GFDownloadTask in _pending_tasks:
		if task.task_id == task_id:
			return task.to_dict()
	return get_result(task_id)


## 聚合多个下载任务的进度。
## [br]
## @api public
## [br]
## @param task_ids: 任务句柄数组。
## [br]
## @return 聚合进度字典。
## [br]
## @schema return: Dictionary，包含 task_count、missing_count、completed_count、failed_count、cancelled_count、running_count、queued_count、terminal_count、finished、success、received_bytes、total_bytes、known_total_bytes、unknown_total_count 和 progress_ratio。
## [br]
## @since 5.2.0
func get_tasks_progress(task_ids: PackedInt32Array) -> Dictionary:
	var completed_count: int = 0
	var failed_count: int = 0
	var cancelled_count: int = 0
	var running_count: int = 0
	var queued_count: int = 0
	var missing_count: int = 0
	var received_bytes: int = 0
	var known_total_bytes: int = 0
	var unknown_total_count: int = 0
	var snapshot_lookup: Dictionary = _make_task_snapshot_lookup(task_ids)

	for task_id: int in task_ids:
		var snapshot_value: Variant = snapshot_lookup.get(task_id, {})
		var snapshot: Dictionary = GFVariantData.as_dictionary(snapshot_value)
		if snapshot.is_empty():
			missing_count += 1
			continue

		var status: int = GFVariantData.get_option_int(snapshot, "status", GFDownloadTask.Status.QUEUED)
		match status:
			GFDownloadTask.Status.COMPLETED:
				completed_count += 1
			GFDownloadTask.Status.FAILED:
				failed_count += 1
			GFDownloadTask.Status.CANCELLED:
				cancelled_count += 1
			GFDownloadTask.Status.RUNNING:
				running_count += 1
			_:
				queued_count += 1

		var total_bytes: int = GFVariantData.get_option_int(snapshot, "total_bytes", -1)
		var expected_size: int = _get_snapshot_expected_size(snapshot)
		var effective_total_bytes: int = total_bytes if total_bytes >= 0 else expected_size
		if effective_total_bytes >= 0:
			known_total_bytes += effective_total_bytes
		else:
			unknown_total_count += 1

		var task_received_bytes: int = maxi(0, GFVariantData.get_option_int(snapshot, "received_bytes"))
		if status == GFDownloadTask.Status.COMPLETED and task_received_bytes == 0 and effective_total_bytes > 0:
			task_received_bytes = effective_total_bytes
		received_bytes += task_received_bytes

	var terminal_count: int = completed_count + failed_count + cancelled_count
	var task_count: int = task_ids.size()
	var finished: bool = task_count > 0 and missing_count == 0 and terminal_count == task_count
	var success: bool = finished and completed_count == task_count
	var aggregate_total_bytes: int = known_total_bytes if unknown_total_count == 0 else -1
	var progress_ratio: float = -1.0
	if aggregate_total_bytes > 0:
		progress_ratio = clampf(float(received_bytes) / float(aggregate_total_bytes), 0.0, 1.0)
	elif aggregate_total_bytes == 0 and finished:
		progress_ratio = 1.0

	return {
		"task_count": task_count,
		"missing_count": missing_count,
		"completed_count": completed_count,
		"failed_count": failed_count,
		"cancelled_count": cancelled_count,
		"running_count": running_count,
		"queued_count": queued_count,
		"terminal_count": terminal_count,
		"finished": finished,
		"success": success,
		"received_bytes": received_bytes,
		"total_bytes": aggregate_total_bytes,
		"known_total_bytes": known_total_bytes,
		"unknown_total_count": unknown_total_count,
		"progress_ratio": progress_ratio,
	}


## 获取下载工具诊断快照。
## [br]
## @api public
## [br]
## @return 诊断快照字典。
## [br]
## @schema return: Dictionary，包含 paused、queued_count、queued_task_ids、active_task 和 result_count。
func get_debug_snapshot() -> Dictionary:
	var queued_ids: PackedInt32Array = PackedInt32Array()
	for task: GFDownloadTask in _pending_tasks:
		_append_packed_int32(queued_ids, task.task_id)

	return {
		"paused": _paused,
		"queued_count": _pending_tasks.size(),
		"queued_task_ids": queued_ids,
		"active_task": _active_task.to_dict() if _active_task != null else {},
		"result_count": _results.size(),
	}


# --- 可重写钩子 / 虚方法 ---

## 启动底层 HTTP 下载请求。
## [br]
## @api protected
## [br]
## @param request_data: 请求数据。
## [br]
## @return Godot 错误码。
## [br]
## @schema request_data: Dictionary，包含 task_id、url、headers、download_file 和 resume_offset。
func _start_http_request(request_data: Dictionary) -> Error:
	var request: HTTPRequest = _ensure_http_request()
	if request == null:
		return ERR_UNAVAILABLE

	request.timeout = timeout_seconds
	request.download_file = GFVariantData.get_option_string(request_data, "download_file")
	return request.request(
		GFVariantData.get_option_string(request_data, "url"),
		_get_dictionary_packed_string_array(request_data, "headers")
	)


## 完成当前活动下载，并根据结果提交、重试或失败任务。
## [br]
## @api protected
## [br]
## @param success: 底层请求是否成功取得响应体。
## [br]
## @param response_code: HTTP 响应码。
## [br]
## @param error: 失败原因。
## [br]
## @param retryable: 是否允许按任务重试策略重新入队。
func _complete_active_download(
	success: bool,
	response_code: int,
	error: String = "",
	retryable: bool = false
) -> void:
	if _active_task == null:
		return

	var task: GFDownloadTask = _active_task
	var request_data: Dictionary = _active_request_data.duplicate(true)
	_active_task = null
	_active_request_data.clear()
	task.response_code = response_code

	if success:
		var commit_error: Error = _commit_download_file(task, request_data, response_code)
		if commit_error == OK:
			task.status = GFDownloadTask.Status.COMPLETED
			task.error = ""
			_finish_task(task, true, false)
		else:
			_fail_or_retry_task(task, "Commit failed: %s" % error_string(commit_error), false)
	else:
		_fail_or_retry_task(
			task,
			error,
			retryable or _is_retryable_http_failure(response_code),
			request_data,
			response_code
		)

	_try_start_next_download()


# --- 私有/辅助方法 ---

static func _parse_manifest_data(data: Variant) -> Variant:
	if data is String:
		var manifest_text: String = data
		var text: String = manifest_text.strip_edges()
		if text.is_empty():
			return []
		var json: JSON = JSON.new()
		if json.parse(text) != OK:
			return []
		return json.data
	return data


static func _get_manifest_raw_entries(data: Variant) -> Array:
	if data is Array:
		var array_entries: Array = data
		return array_entries
	if data is Dictionary:
		var manifest: Dictionary = data
		var files: Array = GFVariantData.get_option_array(manifest, "files")
		if not files.is_empty():
			return files
		var entries: Array = GFVariantData.get_option_array(manifest, "entries")
		if not entries.is_empty():
			return entries
		return GFVariantData.get_option_array(manifest, "downloads")
	return []


static func _build_manifest_defaults(data: Variant, options: Dictionary) -> Dictionary:
	var defaults: Dictionary = {
		"base_url": GFVariantData.get_option_string(options, "base_url").strip_edges(),
		"headers": _normalize_headers(GFVariantData.get_option_value(options, "headers", GFVariantData.get_option_value(options, "default_headers", PackedStringArray()))),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	if data is Dictionary:
		var manifest: Dictionary = data
		var base_url: String = GFVariantData.get_option_string(manifest, "base_url").strip_edges()
		if not base_url.is_empty():
			defaults["base_url"] = base_url
		defaults["headers"] = _merge_headers(
			GFVariantData.get_option_packed_string_array(defaults, "headers"),
			_normalize_headers(GFVariantData.get_option_value(manifest, "default_headers", GFVariantData.get_option_value(manifest, "headers", PackedStringArray())))
		)
		defaults["metadata"] = _merge_metadata(
			GFVariantData.get_option_dictionary(defaults, "metadata"),
			GFVariantData.get_option_dictionary(manifest, "metadata")
		)
	return defaults


static func _normalize_manifest_entry(value: Variant, defaults: Dictionary, index: int) -> Dictionary:
	var entry: Dictionary = {}
	if value is Dictionary:
		entry = value
	elif value is String:
		entry = {
			"path": value,
		}
	else:
		return {}

	var source_url: String = _first_entry_string(entry, ["url", "source", "href"])
	var target_path: String = _first_entry_string(entry, ["target_path", "path", "file"])
	if source_url.is_empty():
		source_url = target_path
	source_url = _resolve_manifest_url(source_url, GFVariantData.get_option_string(defaults, "base_url"))
	if source_url.is_empty():
		return {}
	if target_path.is_empty():
		target_path = _get_url_file_name(source_url)

	var headers: PackedStringArray = _merge_headers(
		GFVariantData.get_option_packed_string_array(defaults, "headers"),
		_normalize_headers(GFVariantData.get_option_value(entry, "headers", PackedStringArray()))
	)
	var metadata: Dictionary = _merge_metadata(
		GFVariantData.get_option_dictionary(defaults, "metadata"),
		GFVariantData.get_option_dictionary(entry, "metadata")
	)
	metadata["manifest_index"] = index
	metadata["manifest_path"] = target_path

	var normalized: Dictionary = {
		"url": source_url,
		"target_path": target_path,
		"headers": headers,
		"metadata": metadata,
	}
	var expected_sha256: String = _get_entry_expected_sha256(entry)
	if not expected_sha256.is_empty():
		normalized["expected_sha256"] = expected_sha256
	var expected_size: int = _first_entry_int(entry, ["expected_size", "size", "bytes"], -1)
	if expected_size >= 0:
		normalized["expected_size"] = expected_size
		metadata["expected_size"] = expected_size
		normalized["metadata"] = metadata

	_copy_manifest_entry_option(entry, normalized, "resume")
	_copy_manifest_entry_option(entry, normalized, "overwrite")
	_copy_manifest_entry_option(entry, normalized, "max_retries")
	_copy_manifest_entry_option(entry, normalized, "retry_delay_seconds")
	return normalized


static func _strip_manifest_parse_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	_erase_dictionary_key_static(result, "base_url")
	_erase_dictionary_key_static(result, &"base_url")
	_erase_dictionary_key_static(result, "headers")
	_erase_dictionary_key_static(result, &"headers")
	_erase_dictionary_key_static(result, "default_headers")
	_erase_dictionary_key_static(result, &"default_headers")
	_erase_dictionary_key_static(result, "metadata")
	_erase_dictionary_key_static(result, &"metadata")
	return result


static func _resolve_manifest_url(url: String, base_url: String) -> String:
	var value: String = url.strip_edges()
	if value.is_empty() or _has_uri_scheme(value) or base_url.strip_edges().is_empty():
		return value
	return base_url.strip_edges().trim_suffix("/") + "/" + value.trim_prefix("/")


static func _has_uri_scheme(value: String) -> bool:
	return value.contains("://") or value.begins_with("uid://")


static func _get_url_file_name(url: String) -> String:
	var path: String = url
	var query_index: int = path.find("?")
	if query_index >= 0:
		path = path.substr(0, query_index)
	var fragment_index: int = path.find("#")
	if fragment_index >= 0:
		path = path.substr(0, fragment_index)
	return path.get_file()


static func _first_entry_string(entry: Dictionary, keys: Array, default_value: String = "") -> String:
	for key: Variant in keys:
		if _has_dictionary_key(entry, key):
			return str(GFVariantData.get_option_value(entry, key, default_value)).strip_edges()
	return default_value


static func _first_entry_int(entry: Dictionary, keys: Array, default_value: int = 0) -> int:
	for key: Variant in keys:
		if _has_dictionary_key(entry, key):
			return GFVariantData.get_option_int(entry, key, default_value)
	return default_value


static func _get_entry_expected_sha256(entry: Dictionary) -> String:
	var value: String = _first_entry_string(entry, ["expected_sha256", "sha256"]).to_lower()
	if not value.is_empty():
		return value
	var generic_hash: String = _first_entry_string(entry, ["hash"]).to_lower()
	return generic_hash if generic_hash.length() == 64 else ""


static func _copy_manifest_entry_option(source: Dictionary, target: Dictionary, key: String) -> void:
	if not _has_dictionary_key(source, key):
		return
	target[key] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(source, key))


static func _has_dictionary_key(source: Dictionary, key: Variant) -> bool:
	if source.has(key):
		return true
	if key is String:
		var string_key: String = key
		return source.has(StringName(string_key))
	if key is StringName:
		var string_name_key: StringName = key
		return source.has(str(string_name_key))
	return false


static func _merge_headers(first: PackedStringArray, second: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = first.duplicate()
	result.append_array(second)
	return result


static func _merge_metadata(first: Dictionary, second: Dictionary) -> Dictionary:
	var result: Dictionary = first.duplicate(true)
	for key: Variant in second.keys():
		result[key] = GFVariantData.duplicate_variant(second[key])
	return result


static func _erase_dictionary_key_static(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return

func _try_start_next_download() -> void:
	if _paused or _active_task != null or _pending_tasks.is_empty():
		return

	var task: GFDownloadTask = _pop_next_ready_task()
	if task == null:
		return

	if FileAccess.file_exists(task.target_path) and not task.overwrite:
		if not _verify_file_checksum(task, task.target_path, "target file"):
			task.status = GFDownloadTask.Status.FAILED
			_finish_task(task, false, false)
			_try_start_next_download()
			return

		task.status = GFDownloadTask.Status.COMPLETED
		_finish_task(task, true, false, { "from_existing_file": true })
		_try_start_next_download()
		return

	_ensure_parent_dir(task.temp_path)
	_ensure_parent_dir(task.target_path)
	_active_task = task
	_active_task.status = GFDownloadTask.Status.RUNNING
	_active_request_data = _build_request_data(task)
	var error: Error = _start_http_request(_active_request_data)
	if error != OK:
		_active_task = null
		_active_request_data.clear()
		task.status = GFDownloadTask.Status.FAILED
		task.error = "Request failed: %s" % error_string(error)
		_finish_task(task, false, false)
		_try_start_next_download()
		return

	_last_progress_emit_msec = 0
	download_started.emit(task.task_id, task.duplicate_task())


func _build_request_data(task: GFDownloadTask) -> Dictionary:
	var resume_offset: int = 0
	if task.resume and FileAccess.file_exists(task.temp_path):
		resume_offset = _get_file_size(task.temp_path)

	var request_headers: PackedStringArray = task.headers.duplicate()
	var download_file: String = task.temp_path
	if resume_offset > 0:
		_append_packed_string(request_headers, "Range: bytes=%d-" % resume_offset)
		download_file = task.segment_path

	return {
		"task_id": task.task_id,
		"url": task.url,
		"headers": request_headers,
		"download_file": download_file,
		"resume_offset": resume_offset,
	}


func _ensure_http_request() -> HTTPRequest:
	if is_instance_valid(_http_request):
		return _http_request

	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop
	if tree == null:
		return null

	_http_request = HTTPRequest.new()
	_http_request.name = "GFDownloadHTTPRequest"
	_connect_request_completed(_http_request)
	tree.root.add_child(_http_request)
	return _http_request


func _cancel_and_discard_http_request() -> void:
	if is_instance_valid(_http_request):
		_http_request.cancel_request()
		_http_request.queue_free()
	_http_request = null


func _commit_download_file(task: GFDownloadTask, request_data: Dictionary, response_code: int) -> Error:
	var resume_offset: int = GFVariantData.get_option_int(request_data, "resume_offset")
	if resume_offset > 0:
		if response_code == 206:
			var append_error: Error = _append_file(task.segment_path, task.temp_path)
			if append_error != OK:
				return append_error
			_remove_absolute_file_if_exists(task.segment_path)
		elif FileAccess.file_exists(task.segment_path):
			if FileAccess.file_exists(task.temp_path):
				_remove_absolute_file_if_exists(task.temp_path)
			var replace_error: Error = DirAccess.rename_absolute(task.segment_path, task.temp_path)
			if replace_error != OK:
				return replace_error

	if not _verify_checksum(task):
		return ERR_INVALID_DATA

	if FileAccess.file_exists(task.target_path):
		if not task.overwrite:
			return ERR_ALREADY_EXISTS
		var remove_error: Error = DirAccess.remove_absolute(task.target_path)
		if remove_error != OK:
			return remove_error

	return DirAccess.rename_absolute(task.temp_path, task.target_path)


func _append_file(source_path: String, target_path: String) -> Error:
	if not FileAccess.file_exists(source_path):
		return OK

	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return FileAccess.get_open_error()
	var target: FileAccess = FileAccess.open(target_path, FileAccess.READ_WRITE)
	if target == null:
		source.close()
		return FileAccess.get_open_error()

	target.seek_end()
	while not source.eof_reached():
		var chunk: PackedByteArray = source.get_buffer(_APPEND_BUFFER_SIZE_BYTES)
		if chunk.is_empty():
			break
		var _store_buffer_result: Variant = target.store_buffer(chunk)
	source.close()
	target.close()
	return OK


func _verify_checksum(task: GFDownloadTask) -> bool:
	return _verify_file_checksum(task, task.temp_path, "temp file")


func _verify_file_checksum(task: GFDownloadTask, file_path: String, label: String) -> bool:
	if task.expected_sha256.is_empty():
		return true
	if not FileAccess.file_exists(file_path):
		task.error = "checksum failed: %s missing" % label
		return false

	var actual: String = FileAccess.get_sha256(file_path).to_lower()
	if actual != task.expected_sha256:
		task.error = "checksum mismatch: %s" % label
		return false
	return true


func _finish_task(
	task: GFDownloadTask,
	success: bool,
	cancelled: bool,
	extra: Dictionary = {}
) -> void:
	var result: Dictionary = task.to_dict()
	result["success"] = success
	result["cancelled"] = cancelled
	for key: Variant in extra.keys():
		result[key] = extra[key]

	_results[task.task_id] = result.duplicate(true)
	var callback: Callable = _get_callback(task.task_id)
	_erase_dictionary_key(_callbacks, task.task_id)
	if callback.is_valid():
		callback.call(result.duplicate(true))

	if cancelled:
		download_cancelled.emit(task.task_id, result)
	elif success:
		download_completed.emit(task.task_id, result)
	else:
		download_failed.emit(task.task_id, result)


func _pause_active_task() -> void:
	if _active_task == null:
		return

	var task: GFDownloadTask = _active_task
	task.status = GFDownloadTask.Status.PAUSED
	_cancel_and_discard_http_request()
	_active_task = null
	_active_request_data.clear()
	_pending_tasks.push_front(task)


static func _normalize_headers(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var headers: PackedStringArray = value
		return headers.duplicate()
	if value is Array:
		var result: PackedStringArray = PackedStringArray()
		for item: Variant in value:
			_append_packed_string(result, str(item))
		return result
	if value is Dictionary:
		var result: PackedStringArray = PackedStringArray()
		var data: Dictionary = value
		for key: Variant in data.keys():
			_append_packed_string(result, "%s: %s" % [str(key), str(data[key])])
		return result
	return PackedStringArray()


func _resolve_manifest_target_path(entry: Dictionary, target_root: String) -> String:
	var target_path: String = _first_entry_string(entry, ["target_path", "path", "file"])
	if target_path.is_empty():
		target_path = _get_url_file_name(GFVariantData.get_option_string(entry, "url"))
	target_path = target_path.replace("\\", "/").strip_edges()
	if _is_supported_absolute_target_path(target_path):
		if _has_parent_path_segment(target_path.trim_prefix("res://").trim_prefix("user://")):
			return ""
		return target_path.simplify_path()
	if not _is_safe_relative_download_path(target_path):
		return ""

	var root: String = target_root.strip_edges()
	if root.is_empty():
		return ""
	return root.path_join(target_path).simplify_path()


func _is_supported_absolute_target_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")


func _is_safe_relative_download_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.contains("://") or path.contains(":"):
		return false
	if path == "." or path.get_file().is_empty() or _has_parent_path_segment(path):
		return false
	return true


func _normalize_direct_download_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if not _is_supported_absolute_target_path(normalized):
		return ""
	var relative_path: String = normalized.trim_prefix("res://").trim_prefix("user://")
	if relative_path.is_empty() or relative_path.get_file().is_empty() or _has_parent_path_segment(relative_path):
		return ""
	return normalized.simplify_path()


func _download_paths_share_root(left_path: String, right_path: String) -> bool:
	return _download_path_root(left_path) == _download_path_root(right_path)


func _download_path_root(path: String) -> String:
	if path.begins_with("res://"):
		return "res://"
	if path.begins_with("user://"):
		return "user://"
	return ""


func _has_parent_path_segment(path: String) -> bool:
	for segment: String in path.split("/", false):
		if segment == "..":
			return true
	return false


func _build_manifest_download_options(entry: Dictionary, options: Dictionary, index: int) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	_erase_dictionary_key_static(result, "temp_path")
	_erase_dictionary_key_static(result, &"temp_path")
	_erase_dictionary_key_static(result, "segment_path")
	_erase_dictionary_key_static(result, &"segment_path")
	var metadata: Dictionary = _merge_metadata(
		GFVariantData.get_option_dictionary(options, "metadata"),
		GFVariantData.get_option_dictionary(entry, "metadata")
	)
	metadata["manifest_index"] = GFVariantData.get_option_int(metadata, "manifest_index", index)
	result["metadata"] = metadata

	result["headers"] = _merge_headers(
		_normalize_headers(GFVariantData.get_option_value(options, "headers", PackedStringArray())),
		_normalize_headers(GFVariantData.get_option_value(entry, "headers", PackedStringArray()))
	)

	for key: String in ["expected_sha256", "resume", "overwrite", "temp_path", "segment_path", "max_retries", "retry_delay_seconds"]:
		if _has_dictionary_key(entry, key):
			result[key] = GFVariantData.duplicate_variant(GFVariantData.get_option_value(entry, key))
	return result


func _get_snapshot_expected_size(snapshot: Dictionary) -> int:
	var expected_size: int = GFVariantData.get_option_int(snapshot, "expected_size", -1)
	if expected_size >= 0:
		return expected_size
	var metadata: Dictionary = GFVariantData.get_option_dictionary(snapshot, "metadata")
	return GFVariantData.get_option_int(metadata, "expected_size", -1)


func _make_task_snapshot_lookup(task_ids: PackedInt32Array) -> Dictionary:
	var requested_ids: Dictionary = {}
	for task_id: int in task_ids:
		if task_id > 0:
			requested_ids[task_id] = true

	var snapshots: Dictionary = {}
	if _active_task != null and requested_ids.has(_active_task.task_id):
		snapshots[_active_task.task_id] = _active_task.to_dict()

	for task: GFDownloadTask in _pending_tasks:
		if requested_ids.has(task.task_id):
			snapshots[task.task_id] = task.to_dict()

	for task_id: int in task_ids:
		if task_id <= 0 or snapshots.has(task_id):
			continue
		var result: Dictionary = get_result(task_id)
		if not result.is_empty():
			snapshots[task_id] = result
	return snapshots


func _pop_next_ready_task() -> GFDownloadTask:
	var now_msec: int = Time.get_ticks_msec()
	for index: int in range(_pending_tasks.size()):
		var task: GFDownloadTask = _pending_tasks[index]
		if task.retry_not_before_msec > now_msec:
			continue
		_pending_tasks.remove_at(index)
		return task
	return null


func _fail_or_retry_task(
	task: GFDownloadTask,
	error: String,
	retryable: bool,
	request_data: Dictionary = {},
	response_code: int = 0
) -> void:
	task.error = error
	if retryable and _schedule_retry(task):
		_cleanup_failed_retry_download_file(request_data, response_code)
		return

	task.status = GFDownloadTask.Status.FAILED
	_finish_task(task, false, false)


func _schedule_retry(task: GFDownloadTask) -> bool:
	if task.retry_count >= task.max_retries:
		return false

	task.retry_count += 1
	task.status = GFDownloadTask.Status.QUEUED
	task.received_bytes = 0
	task.total_bytes = -1
	task.response_code = 0
	task.retry_not_before_msec = Time.get_ticks_msec() + int(task.retry_delay_seconds * 1000.0)
	_pending_tasks.push_front(task)
	return true


func _is_retryable_http_failure(response_code: int) -> bool:
	return response_code == 0 or response_code == 408 or response_code == 425 or response_code == 429 or response_code >= 500


func _cleanup_failed_retry_download_file(request_data: Dictionary, response_code: int) -> void:
	if response_code == 0:
		return

	var download_file: String = GFVariantData.get_option_string(request_data, "download_file")
	if download_file.is_empty() or not FileAccess.file_exists(download_file):
		return
	_remove_absolute_file_if_exists(download_file)


func _delete_task_temp_files(task: GFDownloadTask) -> void:
	if FileAccess.file_exists(task.temp_path):
		_remove_absolute_file_if_exists(task.temp_path)
	if FileAccess.file_exists(task.segment_path):
		_remove_absolute_file_if_exists(task.segment_path)


func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = int(file.get_length())
	file.close()
	return size


func _ensure_parent_dir(path: String) -> void:
	var dir_path: String = path.get_base_dir()
	if dir_path.is_empty() or DirAccess.dir_exists_absolute(dir_path):
		return
	_make_dir_recursive_absolute(dir_path)


func _get_dictionary_packed_string_array(source: Dictionary, key: Variant) -> PackedStringArray:
	return _normalize_headers(GFVariantData.get_option_value(source, key, PackedStringArray()))


func _get_callback(task_id: int) -> Callable:
	var value: Variant = GFVariantData.get_option_value(_callbacks, task_id, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _connect_request_completed(request: HTTPRequest) -> void:
	var error: Error = request.request_completed.connect(_on_request_completed) as Error
	if error != OK:
		return


static func _append_packed_int32(target: PackedInt32Array, value: int) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _remove_absolute_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var _remove_error: Error = DirAccess.remove_absolute(path)


func _make_dir_recursive_absolute(path: String) -> void:
	var _mkdir_error: Error = DirAccess.make_dir_recursive_absolute(path)


# --- 信号处理函数 ---

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_complete_active_download(false, response_code, "HTTP request result: %d" % result)
		return

	if response_code < 200 or response_code >= 300:
		_complete_active_download(false, response_code, "HTTP %d" % response_code)
		return

	_complete_active_download(true, response_code)
