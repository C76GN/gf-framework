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
## @since 3.17.0
## [br]
## @param envelope: 请求描述的隔离副本；监听器修改不会写回内部队列。
signal request_enqueued(envelope: GFRequestEnvelope)

## 请求开始重放。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param envelope: 请求描述的隔离副本；监听器修改不会写回内部队列。
signal request_started(envelope: GFRequestEnvelope)

## 请求成功完成。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param envelope: 请求描述的隔离副本；监听器修改不会写回内部队列。
## [br]
## @param result: transport 返回结果的隔离副本；监听器修改不会写回内部状态。
## [br]
## @schema result: Dictionary，由 transport_callback 返回；ok 或 success=true 表示完成。
signal request_completed(envelope: GFRequestEnvelope, result: Dictionary)

## 请求失败。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param envelope: 请求描述的隔离副本；监听器修改不会写回内部队列。
## [br]
## @param result: transport 返回结果的隔离副本；监听器修改不会写回内部状态。
## [br]
## @schema result: Dictionary，由 transport_callback 返回，包含 error 或 reason 字段。
signal request_failed(envelope: GFRequestEnvelope, result: Dictionary)

## 队列快照变化。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param snapshot: 隔离的调试快照。
## [br]
## @schema snapshot: Dictionary，由 get_debug_snapshot() 返回的调试快照。
signal queue_changed(snapshot: Dictionary)

## 队列持久化操作失败。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param operation: 失败操作，当前为 save 或 load；load 包含恢复候选提升。
## [br]
## @param error: Godot 错误码。
## [br]
## @param path: 队列持久化路径。
signal persistence_failed(operation: StringName, error: Error, path: String)


# --- 常量 ---

const _STORAGE_VERSION: int = 2
const _TEMP_SUFFIX: String = ".tmp"
const _BACKUP_SUFFIX: String = ".bak"
const _DEFAULT_MAX_STORAGE_BYTES: int = 16 * 1024 * 1024
const _PERSISTENCE_MAX_DEPTH: int = 64
const _PERSISTENCE_MAX_COLLECTION_ITEMS: int = 65_536
const _PERSISTENCE_MAX_STRING_LENGTH: int = 65_536
const _PERSISTENCE_MAX_TOTAL_NODES: int = 1_000_000
const _PERSISTENCE_MAX_ESTIMATED_BYTES: int = 64 * 1024 * 1024
const _PERSISTENCE_SCALAR_ESTIMATED_BYTES: int = 32
const _PERSISTENCE_COLLECTION_ESTIMATED_BYTES: int = 64
const _PERSISTENCE_JSON_CODEC_EXPANSION_FACTOR: int = 8
const _PERSISTENCE_JSON_MAX_DEPTH: int = (
	_PERSISTENCE_MAX_DEPTH * _PERSISTENCE_JSON_CODEC_EXPANSION_FACTOR + 32
)
const _PERSISTENCE_JSON_MAX_TOTAL_NODES: int = (
	_PERSISTENCE_MAX_TOTAL_NODES * _PERSISTENCE_JSON_CODEC_EXPANSION_FACTOR
)
const _PERSISTENCE_JSON_MAX_ESTIMATED_BYTES: int = (
	_PERSISTENCE_MAX_ESTIMATED_BYTES * _PERSISTENCE_JSON_CODEC_EXPANSION_FACTOR
)
const _PERSISTENCE_MAX_RAW_STORAGE_BYTES: int = _PERSISTENCE_JSON_MAX_ESTIMATED_BYTES


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

## 持久化事务允许的最大 UTF-8 JSON 字节数，默认 16 MiB。
##
## 保存和恢复候选都会执行该限制；小于等于 0 表示关闭可配置文件字节限制，但仍有
## 不可关闭的 512 MiB 原始恢复/编码安全上限。
## 保存结果超限时返回 ERR_OUT_OF_MEMORY，且不会提交临时事务或替换之前的
## 有效文件。JSON 编码前仍固定限制递归深度 64、单集合 65_536 项、单字符串
## 65_536 字符、累计 1_000_000 个值节点和 64 MiB 估算工作量；这些结构安全
## 上限不受 max_storage_bytes 是否关闭影响。
## [br]
## @api public
## [br]
## @since unreleased
var max_storage_bytes: int = _DEFAULT_MAX_STORAGE_BYTES

## 传输回调，签名为 func(envelope: GFRequestEnvelope) -> Dictionary；也可返回会发出结果值的 Signal。
## envelope 是隔离副本，回调修改不会写回内部队列。
## [br]
## @api public
## [br]
## @since 3.17.0
var transport_callback: Callable = Callable()

## 可选重放过滤回调，签名为 func(envelope: GFRequestEnvelope) -> bool。
## envelope 是隔离副本，回调修改不会写回内部队列。
## [br]
## @api public
## [br]
## @since 3.17.0
var replay_filter: Callable = Callable()


# --- 私有变量 ---

var _queue: Array[GFRequestEnvelope] = []
var _failed_requests: Array[GFRequestEnvelope] = []
var _is_replaying: bool = false
var _disposed: bool = false
var _replay_generation: int = 0
var _last_persistence_error: Error = OK
var _queue_revision: int = 0
var _persisted_revision: int = 0
var _persisted_storage_path: String = "user://gf_request_outbox.json"
var _persisted_state_text: String = ""
var _is_emitting_persistence_failure: bool = false
var _suppress_persistence_failure_signal: bool = false


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
	_mark_queue_changed()
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
	if envelope.idempotency_key.is_empty():
		envelope.idempotency_key = String(envelope.request_id)
	if envelope.created_at_unix <= 0:
		envelope.created_at_unix = int(Time.get_unix_time_from_system())

	_queue.append(envelope)
	request_enqueued.emit(envelope.duplicate_request())
	_persist_and_emit_changed()
	return true


## 以隔离快照入队请求，并返回内存与持久化结果。
##
## 该入口不会把调用方持有的 envelope 直接放入内部队列。require_persistence=true 时，
## 会先验证 body 与 metadata 可由 GFVariantJsonCodec 无损往返；Object、Callable、
## Signal、RID、循环集合、超过固定结构安全预算和其他不支持值会在修改队列前被
## 拒绝。保存失败会回滚本次入队；false 时保持普通 enqueue() 的内存接受语义。
## [br]
## 通知监听器返回后会复核精确请求仍由队列持有且可靠状态有效。本次事务固定使用
## 调用开始时的 storage_path，同步通知中的路径改写不会改变事务目标；同步清空、
## 移除、释放或重新加载导致交接失效时返回 ok=false、reason=enqueue_invalidated，
## 并补偿保存当前队列状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param envelope: 请求描述；内部只保存它的深副本。
## [br]
## @param require_persistence: 是否要求本次请求可靠写入 storage_path。
## [br]
## @return 入队报告。
## [br]
## @schema return: Dictionary，包含 ok、status、reason、envelope、persisted 和 persistence_error。
func enqueue_with_report(
	envelope: GFRequestEnvelope,
	require_persistence: bool = false
) -> Dictionary:
	if _disposed:
		return _make_enqueue_report(false, &"rejected", &"disposed")
	if envelope == null or not envelope.is_valid():
		return _make_enqueue_report(false, &"rejected", &"invalid_envelope")
	if max_queue_size > 0 and _queue.size() >= max_queue_size:
		return _make_enqueue_report(false, &"rejected", &"queue_full")
	if (
		require_persistence
		and not _validate_persistable_envelope(
			envelope,
			_make_persistence_validation_state()
		)
	):
		return _make_enqueue_report(false, &"rejected", &"non_persistable_envelope")

	var receipt_storage_path: String = storage_path
	var persist_on_enqueue: bool = require_persistence or auto_persist
	var queued_envelope: GFRequestEnvelope = envelope.duplicate_request()
	_prepare_envelope_identity(queued_envelope)
	var previous_queue_revision: int = _queue_revision
	var previous_persisted_revision: int = _persisted_revision
	var previous_persisted_storage_path: String = _persisted_storage_path
	var previous_persisted_state_text: String = _persisted_state_text
	_queue.append(queued_envelope)
	_mark_queue_changed()

	var persistence_error: Error = OK
	if require_persistence:
		var previous_suppression: bool = _suppress_persistence_failure_signal
		_suppress_persistence_failure_signal = true
		persistence_error = save_queue()
		_suppress_persistence_failure_signal = previous_suppression
	elif auto_persist:
		persistence_error = save_queue()
	if require_persistence and persistence_error != OK:
		var queued_index: int = _find_queue_index(queued_envelope)
		if queued_index >= 0:
			_queue.remove_at(queued_index)
		_queue_revision = previous_queue_revision
		_persisted_revision = previous_persisted_revision
		_persisted_storage_path = previous_persisted_storage_path
		_persisted_state_text = previous_persisted_state_text
		if not _suppress_persistence_failure_signal:
			_emit_persistence_failure(&"save", persistence_error)
		return _make_enqueue_report(
			false,
			&"rejected",
			&"persistence_failed",
			null,
			persistence_error
		)

	request_enqueued.emit(queued_envelope.duplicate_request())
	queue_changed.emit(get_debug_snapshot())
	if persist_on_enqueue and storage_path != receipt_storage_path:
		storage_path = receipt_storage_path
	if (
		_disposed
		or _find_queue_index(queued_envelope) < 0
		or (
			require_persistence
			and not _has_current_persistence_proof(receipt_storage_path)
		)
	):
		var compensation_error: Error = OK
		if persist_on_enqueue and persistence_error == OK:
			compensation_error = _checkpoint_enqueue_state_at(receipt_storage_path)
		if (
			compensation_error == OK
			and not _disposed
			and storage_path == receipt_storage_path
			and _find_queue_index(queued_envelope) >= 0
			and (
				not require_persistence
				or _has_current_persistence_proof(receipt_storage_path)
			)
		):
			return _make_enqueue_report(
				true,
				&"enqueued",
				&"",
				queued_envelope,
				OK
			)
		return _make_enqueue_report(
			false,
			&"rejected",
			&"enqueue_invalidated",
			null,
			compensation_error
		)
	return _make_enqueue_report(
		true,
		&"enqueued",
		&"",
		queued_envelope,
		persistence_error
	)


## 重放可尝试的请求；恢复出的已耗尽 pending 会直接迁移到失败列表而不再次发送。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param max_count: 最多处理数量；小于等于 0 表示不限制。
## [br]
## @return 重放报告。
## [br]
## @schema return: Dictionary，包含 ok、processed、succeeded、failed、recovered_exhausted、skipped、pending、failed_stored、reason 和 persistence_error。
func replay(max_count: int = 0) -> Dictionary:
	var report: Dictionary = {
		"ok": true,
		"processed": 0,
		"succeeded": 0,
		"failed": 0,
		"recovered_exhausted": 0,
		"skipped": 0,
		"pending": _queue.size(),
		"failed_stored": _failed_requests.size(),
		"reason": "",
		"persistence_error": OK,
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
	var index: int = 0
	while index < _queue.size():
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		if max_count > 0 and _get_report_count(report, "processed") >= max_count:
			break

		var envelope: GFRequestEnvelope = _queue[index]
		if envelope != null and envelope.is_exhausted():
			_queue.remove_at(index)
			_store_failed_request(envelope)
			_mark_queue_changed()
			_increment_report_count(report, "recovered_exhausted")
			if not _checkpoint_replay_state(report):
				return _make_persistence_failed_replay_report(report)
			continue
		var can_replay: bool = _can_replay_envelope(envelope, _get_unix_time_msec())
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		var filtered_queue_index: int = _find_queue_index(envelope)
		if filtered_queue_index < 0:
			index = mini(index, _queue.size())
			continue
		if not can_replay:
			_increment_report_count(report, "skipped")
			index = filtered_queue_index + 1
			continue

		_increment_report_count(report, "processed")
		request_started.emit(envelope.duplicate_request())
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		var started_queue_index: int = _find_queue_index(envelope)
		if started_queue_index < 0:
			index = mini(index, _queue.size())
			continue
		index = started_queue_index
		envelope.mark_attempt()
		_mark_queue_changed()
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
			_mark_queue_changed()
			_increment_report_count(report, "succeeded")
			var success_checkpoint_ok: bool = _checkpoint_replay_state(report)
			request_completed.emit(envelope.duplicate_request(), result.duplicate(true))
			if _is_replay_invalid(replay_generation):
				return _make_interrupted_replay_report(report, replay_generation)
			if not success_checkpoint_ok:
				return _make_persistence_failed_replay_report(report)
			continue

		_increment_report_count(report, "failed")
		envelope.mark_failure(
			_get_result_error_text(result),
			_get_retry_delay_msec(envelope.attempt_count)
		)
		var exhausted: bool = envelope.is_exhausted()
		if exhausted and queue_index >= 0:
			_queue.remove_at(queue_index)
			index = queue_index
			_store_failed_request(envelope)
		elif queue_index >= 0:
			index = queue_index + 1
		else:
			index = mini(index, _queue.size())
		if queue_index >= 0:
			_mark_queue_changed()
		var failure_checkpoint_ok: bool = true
		if queue_index >= 0:
			failure_checkpoint_ok = _checkpoint_replay_state(report)
		request_failed.emit(envelope.duplicate_request(), result.duplicate(true))
		if _is_replay_invalid(replay_generation):
			return _make_interrupted_replay_report(report, replay_generation)
		if not failure_checkpoint_ok:
			return _make_persistence_failed_replay_report(report)
		if exhausted:
			continue
		var current_queue_index: int = _find_queue_index(envelope)
		if current_queue_index >= 0:
			index = current_queue_index + 1
		elif queue_index >= 0:
			index = mini(queue_index, _queue.size())
		else:
			index = mini(index, _queue.size())

	report["pending"] = _queue.size()
	report["failed_stored"] = _failed_requests.size()
	_is_replaying = false
	queue_changed.emit(get_debug_snapshot())
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


## 以同目录临时文件校验、旧文件备份和原子替换保存队列到 storage_path。
## 不可无损编码的值图返回 ERR_INVALID_DATA；超过 max_storage_bytes 返回
## ERR_OUT_OF_MEMORY；两者都不会替换之前的有效事务。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return Godot 错误码。
func save_queue() -> Error:
	if storage_path.is_empty():
		return _record_persistence_result(&"save", ERR_INVALID_PARAMETER)
	if not _is_allowed_storage_path(storage_path):
		return _record_persistence_result(&"save", ERR_UNAUTHORIZED)
	if not _validate_persistable_queue():
		return _record_persistence_result(&"save", ERR_INVALID_DATA)

	var base_dir: String = storage_path.get_base_dir()
	if not base_dir.is_empty() and base_dir != "user://":
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			return _record_persistence_result(&"save", dir_error)

	var data: Variant = GFVariantJsonCodec.variant_to_json_compatible(_to_storage_dict())
	var text: String = JSON.stringify(data, "\t") + "\n"
	var text_bytes: int = text.to_utf8_buffer().size()
	if (
		text_bytes > _PERSISTENCE_MAX_RAW_STORAGE_BYTES
		or (max_storage_bytes > 0 and text_bytes > max_storage_bytes)
	):
		return _record_persistence_result(&"save", ERR_OUT_OF_MEMORY)
	return _record_persistence_result(
		&"save",
		_write_storage_transaction(text),
		text
	)


## 从 storage_path 读取队列；正式文件缺失或损坏时会尝试有效临时文件与备份。
## 所有候选都受 max_storage_bytes 与不可关闭的原始输入上限限制；读取长度变化、
## 非规范 typed marker、解析或预算失败都不会替换当前内存状态。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return Godot 错误码。
func load_queue() -> Error:
	if storage_path.is_empty():
		return _record_persistence_result(&"load", ERR_INVALID_PARAMETER)
	if not _is_allowed_storage_path(storage_path):
		return _record_persistence_result(&"load", ERR_UNAUTHORIZED)

	var recovery_report: Dictionary = _load_storage_with_recovery()
	if not GFVariantData.get_option_bool(recovery_report, "found"):
		_commit_loaded_state([], [])
		_last_persistence_error = OK
		_set_persistence_proof(storage_path, _serialize_current_queue_state())
		queue_changed.emit(get_debug_snapshot())
		return OK
	if not GFVariantData.get_option_bool(recovery_report, "ok"):
		var recovery_error: Error = GFVariantData.get_option_int(
			recovery_report,
			"error",
			ERR_PARSE_ERROR
		) as Error
		return _record_persistence_result(&"load", recovery_error)

	var pending: Array[GFRequestEnvelope] = _get_parsed_envelopes(recovery_report, "pending")
	var failed: Array[GFRequestEnvelope] = _get_parsed_envelopes(recovery_report, "failed")
	_commit_loaded_state(pending, failed)
	_last_persistence_error = OK
	_set_persistence_proof(storage_path, _serialize_current_queue_state())
	queue_changed.emit(get_debug_snapshot())
	return OK


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含存储设置、队列计数、传输可用性、last_persistence_error、is_persisted 和请求 ID 列表。
func get_debug_snapshot() -> Dictionary:
	return {
		"storage_path": storage_path,
		"auto_persist": auto_persist,
		"max_queue_size": max_queue_size,
		"max_storage_bytes": max_storage_bytes,
		"default_max_attempts": default_max_attempts,
		"pending_count": _queue.size(),
		"failed_count": _failed_requests.size(),
		"last_persistence_error": _last_persistence_error,
		"is_persisted": _has_current_persistence_proof(),
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


func _make_persistence_failed_replay_report(report: Dictionary) -> Dictionary:
	report["ok"] = false
	report["pending"] = _queue.size()
	report["failed_stored"] = _failed_requests.size()
	report["reason"] = "persistence_failed"
	report["persistence_error"] = _last_persistence_error
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


func _can_replay_envelope(envelope: GFRequestEnvelope, now_unix_msec: int) -> bool:
	if envelope == null or not envelope.can_attempt(now_unix_msec):
		return false
	if replay_filter.is_valid():
		return GFVariantData.to_bool(replay_filter.call(envelope.duplicate_request()))
	return true


func _call_transport(envelope: GFRequestEnvelope) -> Dictionary:
	var value: Variant = transport_callback.call(envelope.duplicate_request())
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
		if is_same(_queue[index], envelope):
			return index
	return -1


func _prepare_envelope_identity(envelope: GFRequestEnvelope) -> void:
	if envelope.request_id == &"":
		envelope.request_id = StringName(_generate_request_id())
	if envelope.idempotency_key.is_empty():
		envelope.idempotency_key = String(envelope.request_id)
	if envelope.created_at_unix <= 0:
		envelope.created_at_unix = int(Time.get_unix_time_from_system())


func _make_enqueue_report(
	ok: bool,
	status: StringName,
	reason: StringName,
	envelope: GFRequestEnvelope = null,
	persistence_error: Error = OK
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"reason": reason,
		"envelope": envelope.duplicate_request() if envelope != null else null,
		"persisted": ok and _has_current_persistence_proof(),
		"persistence_error": persistence_error,
	}


func _checkpoint_enqueue_state_at(path: String) -> Error:
	var configured_path: String = storage_path
	var previous_suppression: bool = _suppress_persistence_failure_signal
	storage_path = path
	_suppress_persistence_failure_signal = true
	var checkpoint_error: Error = save_queue()
	_suppress_persistence_failure_signal = previous_suppression
	storage_path = configured_path
	return checkpoint_error


func _make_persistence_validation_state(
	max_depth: int = _PERSISTENCE_MAX_DEPTH,
	max_total_nodes: int = _PERSISTENCE_MAX_TOTAL_NODES,
	max_estimated_bytes: int = _PERSISTENCE_MAX_ESTIMATED_BYTES
) -> Dictionary:
	return {
		"nodes": 0,
		"estimated_bytes": 0,
		"active": [],
		"max_depth": max_depth,
		"max_total_nodes": max_total_nodes,
		"max_estimated_bytes": max_estimated_bytes,
	}


func _validate_persistable_queue() -> bool:
	return _validate_persistable_envelope_arrays(_queue, _failed_requests)


func _validate_persistable_envelope_arrays(
	pending: Array[GFRequestEnvelope],
	failed: Array[GFRequestEnvelope]
) -> bool:
	var state: Dictionary = _make_persistence_validation_state()
	if not _reserve_persistence_budget(
		state,
		1,
		_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
	):
		return false
	for envelope: GFRequestEnvelope in pending:
		if not _validate_persistable_envelope(envelope, state):
			return false
	for envelope: GFRequestEnvelope in failed:
		if not _validate_persistable_envelope(envelope, state):
			return false
	return true


func _validate_persistable_envelope(
	envelope: GFRequestEnvelope,
	state: Dictionary
) -> bool:
	if envelope == null:
		return false
	if not _reserve_persistence_budget(
		state,
		1,
		_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
	):
		return false
	for text: String in [
		String(envelope.request_id),
		envelope.url,
		envelope.idempotency_key,
		envelope.last_error,
	]:
		if not _validate_persistence_text(text, state):
			return false
	if not _validate_persistable_value(envelope.headers, 0, state):
		return false
	if not _validate_persistable_value(envelope.body, 0, state):
		return false
	return _validate_persistable_value(envelope.metadata, 0, state)


func _validate_persistable_value(
	value: Variant,
	depth: int,
	state: Dictionary,
	is_dictionary_key: bool = false
) -> bool:
	if depth > GFVariantData.get_option_int(
		state,
		"max_depth",
		_PERSISTENCE_MAX_DEPTH
	):
		return false
	var value_type: int = typeof(value)
	match value_type:
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return _reserve_persistence_budget(
				state,
				1,
				_PERSISTENCE_SCALAR_ESTIMATED_BYTES
			)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _validate_persistence_text(str(value), state)
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D:
			return _reserve_persistence_budget(
				state,
				1,
				_PERSISTENCE_SCALAR_ESTIMATED_BYTES
			)
		TYPE_ARRAY:
			if is_dictionary_key:
				return false
			var array: Array = value
			if array.size() > _PERSISTENCE_MAX_COLLECTION_ITEMS:
				return false
			if _is_active_persistence_collection(array, state):
				return false
			if not _reserve_persistence_budget(
				state,
				1,
				_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
			):
				return false
			_push_active_persistence_collection(array, state)
			for item: Variant in array:
				if not _validate_persistable_value(item, depth + 1, state):
					_pop_active_persistence_collection(state)
					return false
			_pop_active_persistence_collection(state)
			return true
		TYPE_DICTIONARY:
			if is_dictionary_key:
				return false
			var dictionary: Dictionary = value
			if dictionary.size() > _PERSISTENCE_MAX_COLLECTION_ITEMS:
				return false
			if _is_active_persistence_collection(dictionary, state):
				return false
			if not _reserve_persistence_budget(
				state,
				1,
				_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
			):
				return false
			_push_active_persistence_collection(dictionary, state)
			for key: Variant in dictionary.keys():
				if (
					not _validate_persistable_value(key, depth + 1, state, true)
					or not _validate_persistable_value(dictionary[key], depth + 1, state)
				):
					_pop_active_persistence_collection(state)
					return false
			_pop_active_persistence_collection(state)
			return true
		TYPE_PACKED_STRING_ARRAY:
			if is_dictionary_key:
				return false
			var string_values: PackedStringArray = value
			if string_values.size() > _PERSISTENCE_MAX_COLLECTION_ITEMS:
				return false
			if not _reserve_persistence_budget(
				state,
				1,
				_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
			):
				return false
			for item: String in string_values:
				if not _validate_persistence_text(item, state):
					return false
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			if is_dictionary_key:
				return false
			var packed_size: int = len(value)
			if packed_size > _PERSISTENCE_MAX_COLLECTION_ITEMS:
				return false
			return _reserve_persistence_budget(
				state,
				1 + packed_size,
				_PERSISTENCE_COLLECTION_ESTIMATED_BYTES
				+ packed_size * _get_persistence_packed_element_bytes(value_type)
			)
	return false


func _validate_persistence_text(value: String, state: Dictionary) -> bool:
	if value.length() > _PERSISTENCE_MAX_STRING_LENGTH:
		return false
	return _reserve_persistence_budget(
		state,
		1,
		_PERSISTENCE_SCALAR_ESTIMATED_BYTES + value.to_utf8_buffer().size()
	)


func _reserve_persistence_budget(
	state: Dictionary,
	node_count: int,
	estimated_bytes: int
) -> bool:
	if node_count < 0 or estimated_bytes < 0:
		return false
	var next_nodes: int = GFVariantData.get_option_int(state, "nodes") + node_count
	if next_nodes > GFVariantData.get_option_int(
		state,
		"max_total_nodes",
		_PERSISTENCE_MAX_TOTAL_NODES
	):
		return false
	var next_estimated_bytes: int = (
		GFVariantData.get_option_int(state, "estimated_bytes")
		+ estimated_bytes
	)
	if next_estimated_bytes > GFVariantData.get_option_int(
		state,
		"max_estimated_bytes",
		_PERSISTENCE_MAX_ESTIMATED_BYTES
	):
		return false
	state["nodes"] = next_nodes
	state["estimated_bytes"] = next_estimated_bytes
	return true


func _get_persistence_packed_element_bytes(value_type: int) -> int:
	match value_type:
		TYPE_PACKED_BYTE_ARRAY:
			return 1
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return 8
		TYPE_PACKED_VECTOR2_ARRAY:
			return 16
		TYPE_PACKED_VECTOR3_ARRAY:
			return 24
		TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return 32
	return _PERSISTENCE_SCALAR_ESTIMATED_BYTES


func _is_active_persistence_collection(value: Variant, state: Dictionary) -> bool:
	var active_value: Variant = GFVariantData.get_option_value(state, "active", [])
	if not (active_value is Array):
		return false
	var active: Array = active_value
	for candidate: Variant in active:
		if is_same(candidate, value):
			return true
	return false


func _push_active_persistence_collection(value: Variant, state: Dictionary) -> void:
	var active: Array = _get_active_persistence_collections(state)
	active.append(value)
	state["active"] = active


func _pop_active_persistence_collection(state: Dictionary) -> void:
	var active: Array = _get_active_persistence_collections(state)
	if not active.is_empty():
		var _removed: Variant = active.pop_back()
	state["active"] = active


func _get_active_persistence_collections(state: Dictionary) -> Array:
	var active_value: Variant = GFVariantData.get_option_value(state, "active", [])
	if active_value is Array:
		var active: Array = active_value
		return active
	var fallback: Array = []
	state["active"] = fallback
	return fallback


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
	_mark_queue_changed()
	if auto_persist:
		var _save_error: Error = save_queue()
	queue_changed.emit(get_debug_snapshot())


func _checkpoint_replay_state(report: Dictionary) -> bool:
	if not auto_persist:
		return true
	var save_error: Error = save_queue()
	report["persistence_error"] = save_error
	queue_changed.emit(get_debug_snapshot())
	return save_error == OK


func _to_storage_dict() -> Dictionary:
	var pending: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in _queue:
		pending.append(_envelope_to_storage_dict(envelope))

	var failed: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in _failed_requests:
		failed.append(_envelope_to_storage_dict(envelope))

	return {
		"version": _STORAGE_VERSION,
		"pending": pending,
		"failed": failed,
	}


func _envelope_to_storage_dict(envelope: GFRequestEnvelope) -> Dictionary:
	var result: Dictionary = envelope.to_dict()
	var codec_options: Dictionary = {
		"encode_dictionary_keys": true,
	}
	result["body"] = GFVariantJsonCodec.variant_to_json_compatible(
		envelope.body,
		codec_options
	)
	result["metadata"] = GFVariantJsonCodec.variant_to_json_compatible(
		envelope.metadata,
		codec_options
	)
	return result


func _parse_storage_dict(data: Dictionary) -> Dictionary:
	if (
		data.size() != 3
		or not data.has("version")
		or not data.has("pending")
		or not data.has("failed")
		or not _is_exact_json_integer(data["version"])
		or GFVariantData.to_exact_int(data["version"], -1) != _STORAGE_VERSION
	):
		return { "ok": false }
	var pending_report: Dictionary = _parse_envelope_array(
		data["pending"],
		max_queue_size if max_queue_size > 0 else -1
	)
	if not GFVariantData.get_option_bool(pending_report, "ok"):
		return { "ok": false }
	var failed_report: Dictionary = _parse_envelope_array(
		data["failed"],
		maxi(max_failed_requests, 0)
	)
	if not GFVariantData.get_option_bool(failed_report, "ok"):
		return { "ok": false }
	var pending: Array[GFRequestEnvelope] = _get_parsed_envelopes(pending_report, "requests")
	var failed: Array[GFRequestEnvelope] = _get_parsed_envelopes(failed_report, "requests")
	if _has_duplicate_request_ids(pending, failed):
		return { "ok": false }
	if not _validate_persistable_envelope_arrays(pending, failed):
		return { "ok": false }
	return {
		"ok": true,
		"pending": pending,
		"failed": failed,
	}


func _parse_envelope_array(value: Variant, max_count: int) -> Dictionary:
	if not (value is Array):
		return { "ok": false }
	var entries: Array = value
	if max_count >= 0 and entries.size() > max_count:
		return { "ok": false }
	var requests: Array[GFRequestEnvelope] = []
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			return { "ok": false }
		var entry: Dictionary = entry_value
		if not _is_exact_stored_envelope(entry):
			return { "ok": false }
		var envelope: GFRequestEnvelope = GFRequestEnvelope.from_dict(entry)
		if (
			not envelope.is_valid()
			or envelope.request_id == &""
			or envelope.idempotency_key.is_empty()
			or envelope.attempt_count < 0
			or envelope.next_attempt_at_unix_msec < 0
			or envelope.get_method_name() != entry["method_name"]
		):
			return { "ok": false }
		requests.append(envelope)
	return { "ok": true, "requests": requests }


func _is_exact_stored_envelope(data: Dictionary) -> bool:
	var required_fields: PackedStringArray = PackedStringArray([
		"request_id",
		"method",
		"method_name",
		"url",
		"body",
		"headers",
		"idempotency_key",
		"created_at_unix",
		"attempt_count",
		"max_attempts",
		"next_attempt_at_unix_msec",
		"last_error",
		"metadata",
	])
	if data.size() != required_fields.size():
		return false
	for field_name: String in required_fields:
		if not data.has(field_name):
			return false
	if (
		typeof(data["request_id"]) != TYPE_STRING
		or typeof(data["method_name"]) != TYPE_STRING
		or typeof(data["url"]) != TYPE_STRING
		or not (data["body"] is Dictionary)
		or not (data["headers"] is Array)
		or typeof(data["idempotency_key"]) != TYPE_STRING
		or typeof(data["last_error"]) != TYPE_STRING
		or not (data["metadata"] is Dictionary)
	):
		return false
	for integer_field: String in [
		"method",
		"created_at_unix",
		"attempt_count",
		"max_attempts",
		"next_attempt_at_unix_msec",
	]:
		if not _is_exact_json_integer(data[integer_field]):
			return false
	var request_id: String = data["request_id"]
	var url: String = data["url"]
	var idempotency_key: String = data["idempotency_key"]
	if (
		request_id.is_empty()
		or url.is_empty()
		or idempotency_key.is_empty()
		or GFVariantData.to_exact_int(data["created_at_unix"], 0) <= 0
		or GFVariantData.to_exact_int(data["attempt_count"], -1) < 0
		or GFVariantData.to_exact_int(data["next_attempt_at_unix_msec"], -1) < 0
	):
		return false
	var headers: Array = data["headers"]
	for header: Variant in headers:
		if typeof(header) != TYPE_STRING:
			return false
	return true


func _is_exact_json_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not (value is float):
		return false
	var numeric_value: float = value
	return (
		is_finite(numeric_value)
		and numeric_value == floor(numeric_value)
		and absf(numeric_value) <= 9_007_199_254_740_991.0
	)


func _get_parsed_envelopes(report: Dictionary, key: String) -> Array[GFRequestEnvelope]:
	var result: Array[GFRequestEnvelope] = []
	var values: Variant = GFVariantData.get_option_value(report, key, [])
	if not (values is Array):
		return result
	for value: Variant in values:
		if value is GFRequestEnvelope:
			result.append(value)
	return result


func _has_duplicate_request_ids(
	pending: Array[GFRequestEnvelope],
	failed: Array[GFRequestEnvelope]
) -> bool:
	var request_ids: Dictionary = {}
	for envelope: GFRequestEnvelope in pending:
		if request_ids.has(envelope.request_id):
			return true
		request_ids[envelope.request_id] = true
	for envelope: GFRequestEnvelope in failed:
		if request_ids.has(envelope.request_id):
			return true
		request_ids[envelope.request_id] = true
	return false


func _commit_loaded_state(
	pending: Array[GFRequestEnvelope],
	failed: Array[GFRequestEnvelope]
) -> void:
	_invalidate_replay()
	_queue.clear()
	_failed_requests.clear()
	_queue.append_array(pending)
	_failed_requests.append_array(failed)
	_mark_queue_changed()


func _get_request_ids(requests: Array[GFRequestEnvelope]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for envelope: GFRequestEnvelope in requests:
		var _appended: bool = result.append(String(envelope.request_id))
	return result


func _generate_request_id() -> String:
	return "req_%d_%d_%d" % [
		int(Time.get_unix_time_from_system() * 1000000.0),
		OS.get_process_id(),
		randi(),
	]


func _is_allowed_storage_path(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/").strip_edges()
	if not normalized_path.begins_with("user://"):
		return false
	var relative_path: String = normalized_path.substr("user://".length())
	if relative_path.is_empty():
		return false
	for segment: String in relative_path.split("/", false):
		if segment == "..":
			return false
	return true


func _store_string_checked(file: FileAccess, value: String) -> void:
	var store_result: Variant = file.store_string(value)
	if store_result != null:
		return


func _get_unix_time_msec() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _mark_queue_changed() -> void:
	_queue_revision += 1


func _set_persistence_proof(path: String, state_text: String) -> void:
	_persisted_revision = _queue_revision
	_persisted_storage_path = path
	_persisted_state_text = state_text


func _clear_persistence_proof() -> void:
	_persisted_revision = -1
	_persisted_storage_path = ""
	_persisted_state_text = ""


func _has_current_persistence_proof(path: String = storage_path) -> bool:
	if not (
		not path.is_empty()
		and storage_path == path
		and _persisted_storage_path == path
		and _persisted_revision == _queue_revision
	):
		return false
	if not _validate_persistable_queue():
		return false
	return _serialize_current_queue_state() == _persisted_state_text


func _serialize_current_queue_state() -> String:
	var data: Variant = GFVariantJsonCodec.variant_to_json_compatible(_to_storage_dict())
	return JSON.stringify(data, "\t") + "\n"


func _record_persistence_result(
	operation: StringName,
	error: Error,
	persisted_state_text: String = ""
) -> Error:
	_last_persistence_error = error
	if error != OK:
		_clear_persistence_proof()
		if not _suppress_persistence_failure_signal:
			_emit_persistence_failure(operation, error)
	elif operation == &"save":
		_set_persistence_proof(storage_path, persisted_state_text)
	return error


func _emit_persistence_failure(operation: StringName, error: Error) -> void:
	if _is_emitting_persistence_failure:
		return
	_is_emitting_persistence_failure = true
	persistence_failed.emit(operation, error, storage_path)
	_is_emitting_persistence_failure = false


func _write_storage_transaction(text: String) -> Error:
	var temp_path: String = storage_path + _TEMP_SUFFIX
	var backup_path: String = storage_path + _BACKUP_SUFFIX
	var temp_cleanup_error: Error = _remove_file_if_exists(temp_path)
	if temp_cleanup_error != OK:
		return temp_cleanup_error

	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	_store_string_checked(file, text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		var _failed_temp_cleanup: Error = _remove_file_if_exists(temp_path)
		return write_error

	var validation_report: Dictionary = _parse_storage_path(temp_path)
	if not GFVariantData.get_option_bool(validation_report, "ok"):
		var _invalid_temp_cleanup: Error = _remove_file_if_exists(temp_path)
		return ERR_FILE_CORRUPT

	var backed_up: bool = false
	if FileAccess.file_exists(storage_path):
		var backup_cleanup_error: Error = _remove_file_if_exists(backup_path)
		if backup_cleanup_error != OK:
			var _backup_cleanup_temp: Error = _remove_file_if_exists(temp_path)
			return backup_cleanup_error
		var backup_error: Error = DirAccess.rename_absolute(storage_path, backup_path)
		if backup_error != OK:
			var _backup_failed_temp_cleanup: Error = _remove_file_if_exists(temp_path)
			return backup_error
		backed_up = true

	var commit_error: Error = DirAccess.rename_absolute(temp_path, storage_path)
	if commit_error != OK:
		if backed_up and FileAccess.file_exists(backup_path):
			var _restore_error: Error = DirAccess.rename_absolute(backup_path, storage_path)
		var _commit_failed_temp_cleanup: Error = _remove_file_if_exists(temp_path)
		return commit_error

	var _stale_backup_cleanup: Error = _remove_file_if_exists(backup_path)
	return OK


func _load_storage_with_recovery() -> Dictionary:
	var temp_path: String = storage_path + _TEMP_SUFFIX
	var backup_path: String = storage_path + _BACKUP_SUFFIX
	var candidates: PackedStringArray = PackedStringArray()
	for path: String in [storage_path, temp_path, backup_path]:
		if FileAccess.file_exists(path):
			var _appended: bool = candidates.append(path)
	if candidates.is_empty():
		return { "found": false, "ok": true }

	for candidate_path: String in candidates:
		var parse_report: Dictionary = _parse_storage_path(candidate_path)
		if not GFVariantData.get_option_bool(parse_report, "ok"):
			continue
		if candidate_path != storage_path:
			var recover_error: Error = _promote_recovery_candidate(candidate_path)
			if recover_error != OK:
				return {
					"found": true,
					"ok": false,
					"error": recover_error,
				}
		else:
			var _temp_cleanup: Error = _remove_file_if_exists(temp_path)
			var _backup_cleanup: Error = _remove_file_if_exists(backup_path)
		parse_report["found"] = true
		return parse_report
	return {
		"found": true,
		"ok": false,
		"error": ERR_PARSE_ERROR,
	}


func _parse_storage_path(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return { "ok": false, "error": FileAccess.get_open_error() }
	var initial_length: int = file.get_length()
	var read_limit: int = (
		mini(max_storage_bytes, _PERSISTENCE_MAX_RAW_STORAGE_BYTES)
		if max_storage_bytes > 0
		else _PERSISTENCE_MAX_RAW_STORAGE_BYTES
	)
	if initial_length < 0 or initial_length > read_limit:
		file.close()
		return { "ok": false, "error": ERR_OUT_OF_MEMORY }
	var raw_bytes: PackedByteArray = file.get_buffer(initial_length)
	var read_error: Error = file.get_error()
	var final_length: int = file.get_length()
	file.close()
	if read_error != OK:
		return { "ok": false, "error": read_error }
	if raw_bytes.size() != initial_length or final_length != initial_length:
		return { "ok": false, "error": ERR_PARSE_ERROR }
	var text: String = raw_bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != raw_bytes:
		return { "ok": false, "error": ERR_PARSE_ERROR }

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return { "ok": false, "error": ERR_PARSE_ERROR }
	var json_validation_state: Dictionary = _make_persistence_validation_state(
		_PERSISTENCE_JSON_MAX_DEPTH,
		_PERSISTENCE_JSON_MAX_TOTAL_NODES,
		_PERSISTENCE_JSON_MAX_ESTIMATED_BYTES
	)
	if not _validate_persistable_value(json.data, 0, json_validation_state):
		return { "ok": false, "error": ERR_OUT_OF_MEMORY }
	if not _validate_canonical_json_codec_markers(json.data):
		return { "ok": false, "error": ERR_PARSE_ERROR }
	var data_value: Variant = GFVariantJsonCodec.json_compatible_to_variant(json.data)
	if not data_value is Dictionary:
		return { "ok": false, "error": ERR_PARSE_ERROR }
	var parse_report: Dictionary = _parse_storage_dict(GFVariantData.as_dictionary(data_value))
	if not GFVariantData.get_option_bool(parse_report, "ok"):
		return { "ok": false, "error": ERR_PARSE_ERROR }
	return parse_report


func _validate_canonical_json_codec_markers(value: Variant) -> bool:
	if value is Array:
		var array: Array = value
		for item: Variant in array:
			if not _validate_canonical_json_codec_markers(item):
				return false
		return true
	if not (value is Dictionary):
		return true
	var dictionary: Dictionary = value
	if dictionary.size() == 1 and dictionary.has(GFVariantJsonCodec.JSON_MARKER_KEY):
		var decoded: Variant = GFVariantJsonCodec.json_compatible_to_variant(dictionary)
		var canonical: Variant = GFVariantJsonCodec.variant_to_json_compatible(
			decoded,
			{
				"encode_dictionary_keys": true,
			}
		)
		return _json_compatible_values_match(dictionary, canonical)
	for key: Variant in dictionary.keys():
		if not _validate_canonical_json_codec_markers(dictionary[key]):
			return false
	return true


func _json_compatible_values_match(left: Variant, right: Variant, depth: int = 0) -> bool:
	if depth > _PERSISTENCE_JSON_MAX_DEPTH:
		return false
	if (left is int or left is float) and (right is int or right is float):
		var left_number: float = GFVariantData.to_float(left, NAN)
		var right_number: float = GFVariantData.to_float(right, NAN)
		return (
			is_finite(left_number)
			and is_finite(right_number)
			and left_number == right_number
		)
	if typeof(left) != typeof(right):
		return false
	if left is Array:
		var left_array: Array = left
		var right_array: Array = right
		if left_array.size() != right_array.size():
			return false
		for index: int in range(left_array.size()):
			if not _json_compatible_values_match(
				left_array[index],
				right_array[index],
				depth + 1
			):
				return false
		return true
	if left is Dictionary:
		var left_dictionary: Dictionary = left
		var right_dictionary: Dictionary = right
		if left_dictionary.size() != right_dictionary.size():
			return false
		for key: Variant in left_dictionary.keys():
			if (
				not right_dictionary.has(key)
				or not _json_compatible_values_match(
					left_dictionary[key],
					right_dictionary[key],
					depth + 1
				)
			):
				return false
		return true
	return left == right


func _promote_recovery_candidate(candidate_path: String) -> Error:
	var temp_path: String = storage_path + _TEMP_SUFFIX
	var backup_path: String = storage_path + _BACKUP_SUFFIX
	if FileAccess.file_exists(storage_path):
		var remove_error: Error = _remove_file_if_exists(storage_path)
		if remove_error != OK:
			return remove_error
	var promote_error: Error = DirAccess.rename_absolute(candidate_path, storage_path)
	if promote_error != OK:
		return promote_error
	if temp_path != candidate_path:
		var _temp_cleanup: Error = _remove_file_if_exists(temp_path)
	if backup_path != candidate_path:
		var _backup_cleanup: Error = _remove_file_if_exists(backup_path)
	return OK


func _remove_file_if_exists(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)
