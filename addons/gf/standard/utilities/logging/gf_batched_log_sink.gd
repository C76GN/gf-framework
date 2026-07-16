## GFBatchedLogSink: 结构化日志批量转发 sink。
##
## 该 sink 只负责清洗、缓冲和分批，把实际传输交给 sender_callback 或 batch_ready 信号。
## 它不绑定任何远端服务、HTTP 协议或业务字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFBatchedLogSink
extends GFLogSink


# --- 信号 ---

## 批次准备好时发出。
## [br]
## @api public
## [br]
## @param batch: 日志批次数组。
## [br]
## @schema batch: Array[Dictionary] of sanitized log entries.
signal batch_ready(batch: Array[Dictionary])


# --- 导出变量 ---

## 每批最多包含的日志条数。
## [br]
## @api public
@export var batch_size: int = 20:
	set(value):
		batch_size = maxi(value, 1)

## 队列最多保留的日志条数，超出时丢弃最旧条目。
## [br]
## @api public
@export var max_queue_size: int = 500:
	set(value):
		max_queue_size = maxi(value, 1)
		_trim_queue()

## 自动 flush 间隔。设为 0 时只按 batch_size 或显式 flush。
## [br]
## @api public
@export var flush_interval_msec: int = 1000:
	set(value):
		flush_interval_msec = maxi(value, 0)

## 是否在转发前移除 text 字段，减少重复载荷。
## [br]
## @api public
@export var omit_formatted_text: bool = false

## 发送时附加到批次外层的元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant] copied into each outgoing payload.
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 项目提供的发送回调，签名为 func(payload: Dictionary) -> Dictionary。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @schema sender_callback: Callable 接收包含 logs、metadata 和 dropped_count 的 Dictionary，并返回包含必需 ok: bool、可选 accepted: int 与 error: String 的 Dictionary；缺失或类型错误时 fail-closed。
var sender_callback: Callable = Callable()


# --- 私有变量 ---

var _queue: Array[Dictionary] = []
var _dropped_count: int = 0
var _last_flush_msec: int = 0
var _failed_send_count: int = 0
var _last_error: String = ""


# --- 公共方法 ---

## 使用外发批量日志所需的 privacy 脱敏 profile。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return privacy profile 名称。
## [br]
## @schema return: String naming GFReportValueCodec.REDACTION_PROFILE_PRIVACY.
func get_report_redaction_profile() -> String:
	return GFReportValueCodec.REDACTION_PROFILE_PRIVACY


## 初始化 sink。
## [br]
## @api public
## [br]
## @param _owner: 持有该 sink 的日志工具。
func init(_owner: Object) -> void:
	_last_flush_msec = Time.get_ticks_msec()


## 写入一条结构化日志。
## [br]
## @api public
## [br]
## @param entry: 日志条目字典。
## [br]
## @schema entry: Dictionary log entry produced by GFLogUtility.
func write(entry: Dictionary) -> void:
	var sanitized: Dictionary = GFReportValueCodec.to_report_dictionary(
		entry,
		_make_external_report_options()
	)
	if sanitized.is_empty() and not entry.is_empty():
		return
	var safe_context: Dictionary = GFVariantData.get_option_dictionary(sanitized, "context")
	var safe_tag: String = GFVariantData.get_option_string(sanitized, "tag")
	var safe_message: String = GFVariantData.get_option_string(sanitized, "message")
	sanitized["tag"] = safe_tag
	sanitized["message"] = safe_message
	sanitized["context"] = safe_context
	sanitized["text"] = _format_sanitized_text(
		GFVariantData.get_option_string(sanitized, "timestamp"),
		GFVariantData.get_option_string(sanitized, "level_name"),
		safe_tag,
		safe_message,
		safe_context
	)
	if omit_formatted_text:
		var _erase_result_102: Variant = sanitized.erase("text")

	_queue.append(sanitized)
	_trim_queue()
	if _queue.size() >= batch_size or _should_flush_by_interval():
		flush()


## 发送当前队列中的一批日志。
## [br]
## @api public
func flush() -> void:
	if _queue.is_empty():
		_last_flush_msec = Time.get_ticks_msec()
		return

	var take_count: int = mini(batch_size, _queue.size())
	var batch: Array[Dictionary] = []
	for _index: int in range(take_count):
		batch.append(_queue.pop_front())

	_last_flush_msec = Time.get_ticks_msec()
	var payload: Dictionary = {
		"logs": batch,
		"metadata": GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(
			metadata.duplicate(true),
			_make_external_report_options()
		)),
		"dropped_count": _dropped_count,
	}
	if sender_callback.is_valid():
		var send_result: Variant = sender_callback.call(payload.duplicate(true))
		if not (send_result is Dictionary):
			_record_send_failure("sender_callback must return Dictionary")
			_requeue_front(batch)
			return
		var send_dictionary: Dictionary = send_result
		if not send_dictionary.has("ok") or not (send_dictionary["ok"] is bool):
			_record_send_failure("sender_callback result requires ok: bool")
			_requeue_front(batch)
			return
		if not GFVariantData.get_option_bool(send_dictionary, "ok"):
			_record_send_failure(GFVariantData.get_option_string(send_dictionary, "error", "sender_callback reported failure"))
			_requeue_front(batch)
			return
		var accepted_count: int = clampi(GFVariantData.get_option_int(send_dictionary, "accepted", batch.size()), 0, batch.size())
		if accepted_count < batch.size():
			var remaining: Array[Dictionary] = []
			for index: int in range(accepted_count, batch.size()):
				remaining.append(batch[index])
			_requeue_front(remaining)
		_last_error = ""
		return
	batch_ready.emit(batch.duplicate(true))


## 关闭 sink 并尽力 flush。
## [br]
## @api public
func shutdown() -> void:
	flush()


## 获取队列中的日志数量。
## [br]
## @api public
## [br]
## @return 待发送日志数量。
func get_pending_count() -> int:
	return _queue.size()


## 获取因队列上限丢弃的日志数量。
## [br]
## @api public
## [br]
## @return 丢弃数量。
func get_dropped_count() -> int:
	return _dropped_count


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return sink 状态字典。
## [br]
## @schema return: Dictionary with pending_count, dropped_count, failed_send_count, last_error, batch_size, max_queue_size, flush_interval_msec, and has_sender_callback.
func get_debug_snapshot() -> Dictionary:
	return {
		"pending_count": _queue.size(),
		"dropped_count": _dropped_count,
		"failed_send_count": _failed_send_count,
		"last_error": _last_error,
		"batch_size": batch_size,
		"max_queue_size": max_queue_size,
		"flush_interval_msec": flush_interval_msec,
		"has_sender_callback": sender_callback.is_valid(),
	}


# --- 私有/辅助方法 ---

func _trim_queue() -> void:
	while _queue.size() > max_queue_size:
		_queue.pop_front()
		_dropped_count += 1


func _requeue_front(batch: Array[Dictionary]) -> void:
	for index: int in range(batch.size() - 1, -1, -1):
		_queue.push_front(batch[index].duplicate(true))
	_trim_queue()


func _record_send_failure(message: String) -> void:
	_failed_send_count += 1
	_last_error = message


func _make_external_report_options() -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_PRIVACY,
		{
			"max_depth": 12,
			"max_string_length": 4096,
			"max_collection_items": 256,
			"max_packed_length": 256,
			"max_total_nodes": 8192,
			"max_total_bytes": 256 * 1024,
			"encode_dictionary_keys": false,
		}
	)


func _format_sanitized_text(
	timestamp: String,
	level_name: String,
	tag: String,
	message: String,
	context: Dictionary
) -> String:
	var text: String = "[%s][%s][%s] %s" % [timestamp, level_name, tag, message]
	if not context.is_empty():
		text += " " + JSON.stringify(context)
	return text


func _should_flush_by_interval() -> bool:
	if flush_interval_msec <= 0:
		return false
	return Time.get_ticks_msec() - _last_flush_msec >= flush_interval_msec
