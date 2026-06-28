## GFRequestOutboxUtility: 通用离线请求队列。
##
## 负责把项目提交的请求描述持久化、按重试策略重放，并通过 transport_callback
## 交给项目自己的网络、SDK 或工具链发送。它不内置任何账号、云服务或业务协议。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRequestOutboxUtility
extends GFUtility


# --- 信号 ---

## 请求成功进入队列。
## [br]
## @api public
## [br]
## @param envelope: 请求描述。
signal request_enqueued(envelope: GFRequestEnvelope)

## 请求开始重放。
## [br]
## @api public
## [br]
## @param envelope: 请求描述。
signal request_started(envelope: GFRequestEnvelope)

## 请求成功完成。
## [br]
## @api public
## [br]
## @param envelope: 请求描述。
## [br]
## @param result: transport 返回的结果字典。
## [br]
## @schema result: Dictionary，由 transport_callback 返回；ok 或 success=true 表示完成。
signal request_completed(envelope: GFRequestEnvelope, result: Dictionary)

## 请求失败。
## [br]
## @api public
## [br]
## @param envelope: 请求描述。
## [br]
## @param result: transport 返回的结果字典。
## [br]
## @schema result: Dictionary，由 transport_callback 返回，包含 error 或 reason 字段。
signal request_failed(envelope: GFRequestEnvelope, result: Dictionary)

## 队列快照变化。
## [br]
## @api public
## [br]
## @param snapshot: 调试快照。
## [br]
## @schema snapshot: Dictionary，由 get_debug_snapshot() 返回的调试快照。
signal queue_changed(snapshot: Dictionary)


# --- 公共变量 ---

## 队列持久化路径。
## [br]
## @api public
var storage_path: String = "user://gf_request_outbox.json"

## init() 时是否自动读取持久化队列。
## [br]
## @api public
var auto_load_on_init: bool = true

## 队列变化后是否自动写入 storage_path。
## [br]
## @api public
var auto_persist: bool = true

## 最大等待队列长度；小于等于 0 表示不限制。
## [br]
## @api public
var max_queue_size: int = 128

## 新入队请求默认最大尝试次数；小于等于 0 表示不限制。
## [br]
## @api public
var default_max_attempts: int = 3

## 重试延迟序列，单位毫秒；超过长度后复用最后一个值。
## [br]
## @api public
## [br]
## @schema retry_delays_msec: Array，按毫秒记录的重试延迟列表。
var retry_delays_msec: Array[int] = [500, 1000, 2000, 5000]

## 请求耗尽尝试次数后是否保留在失败列表中。
## [br]
## @api public
var keep_failed_requests: bool = true

## 失败列表最多保留数量；小于等于 0 表示不保留。
## [br]
## @api public
var max_failed_requests: int = 32

## 传输回调，签名为 func(envelope: GFRequestEnvelope) -> Dictionary；也可返回会发出结果值的 Signal。
## [br]
## @api public
var transport_callback: Callable = Callable()

## 可选重放过滤回调，签名为 func(envelope: GFRequestEnvelope) -> bool。
## [br]
## @api public
var replay_filter: Callable = Callable()


# --- 私有变量 ---

var _queue: Array[GFRequestEnvelope] = []
var _failed_requests: Array[GFRequestEnvelope] = []
var _is_replaying: bool = false
var _disposed: bool = false
var _replay_generation: int = 0


# --- GF 生命周期方法 ---

## 初始化请求 Outbox，并按配置读取持久化队列。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	_disposed = false
	if auto_load_on_init:
		var _load_error: Error = load_queue()


## 按配置保存队列并清理运行时状态。
## [br]
## @api public
func dispose() -> void:
	_invalidate_replay()
	_disposed = true
	if auto_persist:
		var _save_error: Error = save_queue()
	_queue.clear()
	_failed_requests.clear()
	_is_replaying = false


# --- 公共方法 ---

## 创建并入队一个请求。
## [br]
## @api public
## [br]
## @param method: HTTPClient.Method 数值。
## [br]
## @param url: 请求目标地址或项目自定义端点。
## [br]
## @param body: 请求载荷。
## [br]
## @param headers: 请求 Header。
## [br]
## @param metadata: 项目自定义元数据。
## [br]
## @return 入队成功时返回请求描述；失败返回 null。
## [br]
## @schema body: Dictionary，项目传输层持有的请求载荷。
## [br]
## @schema metadata: Dictionary，随请求持久化的项目侧元数据。
func enqueue_request(
	method: int,
	url: String,
	body: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	metadata: Dictionary = {}
) -> GFRequestEnvelope:
	var envelope: GFRequestEnvelope = GFRequestEnvelope.new(method, url, body, headers, metadata)
	envelope.max_attempts = default_max_attempts
	return envelope if enqueue(envelope) else null


## 入队已有请求描述。
## [br]
## @api public
## [br]
## @param envelope: 请求描述。
## [br]
## @return 入队成功返回 true。
func enqueue(envelope: GFRequestEnvelope) -> bool:
	if _disposed:
		return false
	if envelope == null or not envelope.is_valid():
		return false
	if max_queue_size > 0 and _queue.size() >= max_queue_size:
		return false

	if envelope.request_id == &"":
		envelope.request_id = StringName(_generate_request_id())
	if envelope.created_at_unix <= 0:
		envelope.created_at_unix = int(Time.get_unix_time_from_system())

	_queue.append(envelope)
	request_enqueued.emit(envelope)
	_persist_and_emit_changed()
	return true


## 重放可尝试的请求。
## [br]
## @api public
## [br]
## @param max_count: 最多处理数量；小于等于 0 表示不限制。
## [br]
## @return 重放报告。
## [br]
## @schema return: Dictionary，包含 ok、processed、succeeded、failed、skipped、pending、failed_stored 和 reason。
func replay(max_count: int = 0) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"processed": 0,
		"succeeded": 0,
		"failed": 0,
		"skipped": 0,
		"pending": _queue.size(),
		"failed_stored": _failed_requests.size(),
		"reason": "",
	}
	if not transport_callback.is_valid():
		report["ok"] = false
		report["reason"] = "missing_transport"
		return report
	if _is_replaying:
		report["ok"] = false
		report["reason"] = "replay_in_progress"
		return report

	_is_replaying = true
	var replay_generation: int = _replay_generation
	var now_msec: int = Time.get_ticks_msec()
	var index: int = 0
	while index < _queue.size():
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		if max_count > 0 and _get_report_count(report, "processed") >= max_count:
			break

		var envelope: GFRequestEnvelope = _queue[index]
		if not _can_replay_envelope(envelope, now_msec):
			_increment_report_count(report, "skipped")
			index += 1
			continue

		_increment_report_count(report, "processed")
		request_started.emit(envelope)
		envelope.mark_attempt()
		var result: Dictionary = await _call_transport(envelope)
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		var queue_index: int = _find_queue_index(envelope)
		if _is_success_result(result):
			envelope.mark_success()
			if queue_index >= 0:
				_queue.remove_at(queue_index)
				index = queue_index
			else:
				index = mini(index, _queue.size())
			_increment_report_count(report, "succeeded")
			request_completed.emit(envelope, result)
			continue

		_increment_report_count(report, "failed")
		envelope.mark_failure(
			_get_result_error_text(result),
			_get_retry_delay_msec(envelope.attempt_count)
		)
		request_failed.emit(envelope, result)
		if envelope.is_exhausted():
			if queue_index >= 0:
				_queue.remove_at(queue_index)
				index = queue_index
			else:
				index = mini(index, _queue.size())
			_store_failed_request(envelope)
			continue
		if queue_index >= 0:
			index = queue_index + 1
		else:
			index = mini(index, _queue.size())

	report["pending"] = _queue.size()
	report["failed_stored"] = _failed_requests.size()
	_is_replaying = false
	_persist_and_emit_changed()
	return report


## 移除指定请求。
## [br]
## @api public
## [br]
## @param request_id: 请求标识。
## [br]
## @return 移除成功返回 true。
func remove_request(request_id: StringName) -> bool:
	for index: int in range(_queue.size()):
		if _queue[index].request_id == request_id:
			_queue.remove_at(index)
			_persist_and_emit_changed()
			return true
	return false


## 清空等待队列。
## [br]
## @api public
func clear_queue() -> void:
	_invalidate_replay()
	_queue.clear()
	_persist_and_emit_changed()


## 清空失败请求列表。
## [br]
## @api public
func clear_failed_requests() -> void:
	_failed_requests.clear()
	_persist_and_emit_changed()


## 获取等待队列长度。
## [br]
## @api public
## [br]
## @return 队列长度。
func get_queue_size() -> int:
	return _queue.size()


## 获取失败请求数量。
## [br]
## @api public
## [br]
## @return 失败请求数量。
func get_failed_request_count() -> int:
	return _failed_requests.size()


## 获取等待请求副本。
## [br]
## @api public
## [br]
## @return 请求副本数组。
## [br]
## @schema return: Array，当前等待重放的 GFRequestEnvelope 副本。
func get_pending_requests() -> Array[GFRequestEnvelope]:
	var result: Array[GFRequestEnvelope] = []
	for envelope: GFRequestEnvelope in _queue:
		result.append(envelope.duplicate_request())
	return result


## 获取失败请求副本。
## [br]
## @api public
## [br]
## @return 失败请求副本数组。
## [br]
## @schema return: Array，重试耗尽后保存的 GFRequestEnvelope 副本。
func get_failed_requests() -> Array[GFRequestEnvelope]:
	var result: Array[GFRequestEnvelope] = []
	for envelope: GFRequestEnvelope in _failed_requests:
		result.append(envelope.duplicate_request())
	return result


## 保存队列到 storage_path。
## [br]
## @api public
## [br]
## @return Godot 错误码。
func save_queue() -> Error:
	if storage_path.is_empty():
		return ERR_INVALID_PARAMETER

	var base_dir: String = storage_path.get_base_dir()
	if not base_dir.is_empty() and base_dir != "user://":
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			return dir_error

	var file: FileAccess = FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var data: Variant = GFVariantJsonCodec.variant_to_json_compatible(_to_storage_dict())
	_store_string_checked(file, JSON.stringify(data, "\t"))
	var error: Error = file.get_error()
	file.close()
	return error


## 从 storage_path 读取队列。
## [br]
## @api public
## [br]
## @return Godot 错误码。
func load_queue() -> Error:
	_invalidate_replay()
	_queue.clear()
	_failed_requests.clear()
	if storage_path.is_empty() or not FileAccess.file_exists(storage_path):
		queue_changed.emit(get_debug_snapshot())
		return OK

	var file: FileAccess = FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var text: String = file.get_as_text()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error

	var parsed: Variant = JSON.parse_string(text)
	var data_value: Variant = GFVariantJsonCodec.json_compatible_to_variant(parsed)
	if not (data_value is Dictionary):
		return ERR_PARSE_ERROR

	var data: Dictionary = GFVariantData.as_dictionary(data_value)
	_apply_storage_dict(data)
	queue_changed.emit(get_debug_snapshot())
	return OK


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含存储设置、队列计数、传输可用性和请求 ID 列表。
func get_debug_snapshot() -> Dictionary:
	return {
		"storage_path": storage_path,
		"auto_persist": auto_persist,
		"max_queue_size": max_queue_size,
		"default_max_attempts": default_max_attempts,
		"pending_count": _queue.size(),
		"failed_count": _failed_requests.size(),
		"has_transport": transport_callback.is_valid(),
		"pending_request_ids": _get_request_ids(_queue),
		"failed_request_ids": _get_request_ids(_failed_requests),
	}


# --- 私有/辅助方法 ---

func _get_report_count(report: Dictionary, key: String) -> int:
	return GFVariantData.get_option_int(report, key)


func _invalidate_replay() -> void:
	_replay_generation += 1
	_is_replaying = false


func _is_replay_invalid(replay_generation: int) -> bool:
	return _disposed or replay_generation != _replay_generation


func _make_interrupted_replay_report(report: Dictionary, replay_generation: int) -> Dictionary:
	report["ok"] = false
	report["pending"] = _queue.size()
	report["failed_stored"] = _failed_requests.size()
	report["reason"] = "disposed" if _disposed else "replay_invalidated"
	if replay_generation == _replay_generation:
		_is_replaying = false
	return report


func _increment_report_count(report: Dictionary, key: String) -> void:
	report[key] = _get_report_count(report, key) + 1


func _get_result_ok(result: Dictionary) -> bool:
	return GFVariantData.get_option_bool(result, "ok")


func _get_result_success(result: Dictionary) -> bool:
	return GFVariantData.get_option_bool(result, "success")


func _get_result_error_text(result: Dictionary) -> String:
	var fallback: String = GFVariantData.get_option_string(result, "reason", "request_failed")
	return GFVariantData.get_option_string(result, "error", fallback)


func _can_replay_envelope(envelope: GFRequestEnvelope, now_msec: int) -> bool:
	if envelope == null or not envelope.can_attempt(now_msec):
		return false
	if replay_filter.is_valid():
		return GFVariantData.to_bool(replay_filter.call(envelope))
	return true


func _call_transport(envelope: GFRequestEnvelope) -> Dictionary:
	var value: Variant = transport_callback.call(envelope)
	if value is Signal:
		var transport_signal: Signal = value
		value = await transport_signal
	return _normalize_transport_result(value)


func _normalize_transport_result(value: Variant) -> Dictionary:
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.is_empty():
			return { "ok": false, "error": "empty_transport_result" }
		var result: Dictionary = _normalize_transport_result(values[0])
		if values.size() > 1:
			result["signal_args"] = GFVariantData.duplicate_variant(values)
		return result
	if value is Dictionary:
		var result: Dictionary = GFVariantData.as_dictionary(GFVariantData.duplicate_variant(value))
		if not result.has("ok") and result.has("success"):
			result["ok"] = _get_result_success(result)
		return result
	if value is bool:
		return { "ok": GFVariantData.to_bool(value) }
	if value is int:
		var error: int = GFVariantData.to_int(value)
		return { "ok": error == OK, "error_code": error, "error": error_string(error) }
	return { "ok": value != null }


func _is_success_result(result: Dictionary) -> bool:
	if result.has("ok"):
		return _get_result_ok(result)
	if result.has("success"):
		return _get_result_success(result)
	return false


func _find_queue_index(envelope: GFRequestEnvelope) -> int:
	for index: int in range(_queue.size()):
		if _queue[index] == envelope:
			return index
	return -1


func _get_retry_delay_msec(attempt_count: int) -> int:
	if retry_delays_msec.is_empty():
		return 0
	var index: int = clampi(attempt_count - 1, 0, retry_delays_msec.size() - 1)
	return maxi(retry_delays_msec[index], 0)


func _store_failed_request(envelope: GFRequestEnvelope) -> void:
	if not keep_failed_requests or max_failed_requests <= 0:
		return
	_failed_requests.append(envelope)
	while _failed_requests.size() > max_failed_requests:
		_failed_requests.pop_front()


func _persist_and_emit_changed() -> void:
	if auto_persist:
		var _save_error: Error = save_queue()
	queue_changed.emit(get_debug_snapshot())


func _to_storage_dict() -> Dictionary:
	var pending: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in _queue:
		pending.append(envelope.to_dict(true))

	var failed: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in _failed_requests:
		failed.append(envelope.to_dict(true))

	return {
		"version": 1,
		"pending": pending,
		"failed": failed,
	}


func _apply_storage_dict(data: Dictionary) -> void:
	for entry_value: Variant in GFVariantData.get_option_array(data, "pending"):
		if entry_value is Dictionary:
			var envelope: GFRequestEnvelope = GFRequestEnvelope.from_dict(GFVariantData.as_dictionary(entry_value))
			if envelope.is_valid():
				_queue.append(envelope)

	for entry_value: Variant in GFVariantData.get_option_array(data, "failed"):
		if entry_value is Dictionary:
			var envelope: GFRequestEnvelope = GFRequestEnvelope.from_dict(GFVariantData.as_dictionary(entry_value))
			if envelope.is_valid():
				_failed_requests.append(envelope)


func _get_request_ids(requests: Array[GFRequestEnvelope]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for envelope: GFRequestEnvelope in requests:
		var _appended: bool = result.append(String(envelope.request_id))
	return result


func _generate_request_id() -> String:
	return "req_%d_%d" % [Time.get_unix_time_from_system(), randi()]


func _store_string_checked(file: FileAccess, value: String) -> void:
	var store_result: Variant = file.store_string(value)
	if store_result != null:
		return
