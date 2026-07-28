## GFDeferredMutationQueue: 确定性延迟变更队列。
##
## 用于把运行时或工具流程中收集到的状态变更延迟到显式 playback 点执行。
## record() 保存无 owner 的强 Callable；record_method() 通过弱 owner 和方法名
## 保存生命周期调用。队列不解释调用方的实体、组件、节点或资源语义。
## 记录和取消入口由 Mutex 保护；playback() 与生命周期入口只允许在主线程调用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFDeferredMutationQueue
extends GFUtility


# --- 常量 ---

## 默认变更阶段。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_PHASE: StringName = &"default"

## 默认最多保留的待应用变更数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_PENDING_MUTATIONS: int = 4096

## 最多允许配置的待应用变更数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_PENDING_MUTATIONS: int = 65_536

## playback() 未显式给出数量预算时使用的默认值。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_MUTATIONS_PER_PLAYBACK: int = 256

## 单次 playback() 或 preview() 允许处理的记录数量绝对上限。
## [br]
## @api public
## [br]
## @since 10.0.0
const ABSOLUTE_MAX_MUTATIONS_PER_PLAYBACK: int = 4096

## Playback 正常完成。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_COMPLETED: StringName = &"completed"

## Playback 在非主线程被调用。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_WRONG_THREAD: StringName = &"wrong_thread"

## 当前实例已经处于同步 playback 调用中。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_BUSY: StringName = &"busy"

const _RECORD_KIND_CALLABLE: StringName = &"callable"
const _RECORD_KIND_WEAK_METHOD: StringName = &"weak_method"


# --- 公共变量 ---

## 最多保留的待应用变更数量。降低容量不会驱逐现有记录。
## [br]
## @api public
## [br]
## @since 10.0.0
var max_pending_mutations: int = DEFAULT_MAX_PENDING_MUTATIONS:
	set(value):
		max_pending_mutations = clampi(
			value,
			1,
			ABSOLUTE_MAX_PENDING_MUTATIONS
		)

## playback() 默认每次最多应用多少条变更。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_mutations_per_playback: int = DEFAULT_MAX_MUTATIONS_PER_PLAYBACK:
	set(value):
		max_mutations_per_playback = clampi(
			value,
			1,
			ABSOLUTE_MAX_MUTATIONS_PER_PLAYBACK
		)

## playback() 在变更之间检查的非抢占式软时间预算。小于等于 0 时不启用；
## 不会中断单条变更，并且非空匹配快照至少会尝试应用一条变更。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_seconds_per_playback: float = 0.0:
	set(value):
		max_seconds_per_playback = maxf(value, 0.0)


# --- 私有变量 ---

var _mutex: Mutex = Mutex.new()
var _queue: Array[Dictionary] = []
var _playback_snapshot: Array[Dictionary] = []
var _playback_new_records: Array[Dictionary] = []
var _playback_matching_indexes: Array[int] = []
var _playback_matching_cursor: int = 0
var _playback_snapshot_matching_count: int = 0
var _playback_phase_filter: StringName = &""
var _playback_snapshot_active: bool = false
var _pending_count: int = 0
var _next_handle: int = 1
var _next_order: int = 1
var _playback_in_progress: bool = false
var _recorded_count: int = 0
var _applied_count: int = 0
var _cancelled_count: int = 0
var _failed_count: int = 0
var _skipped_owner_count: int = 0
var _high_watermark: int = 0
var _rejected_count: int = 0
var _dropped_count: int = 0


# --- GF 生命周期方法 ---

## 初始化队列并清空统计。
## [br]
## @api public
## [br]
## @since 7.0.0
func init() -> void:
	clear()


## 清空队列。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


# --- 公共方法 ---

## 记录一条无 owner 的延迟变更。
## 该入口会强持有 mutation；需要绑定 owner 生命周期时使用 record_method()。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param mutation: playback() 时执行的回调。
## [br]
## @param options: 记录选项，支持 phase、sort_key、order、label 和 metadata。
## [br]
## @schema options: Dictionary，可包含 phase: StringName、sort_key: int、order: int、label: String、metadata: Dictionary。
## [br]
## @return 变更句柄；mutation 无效时返回 0。
func record(mutation: Callable, options: Dictionary = {}) -> int:
	if not mutation.is_valid():
		push_error("[GFDeferredMutationQueue] record 失败：mutation 无效。")
		return 0
	if options.has("owner") or options.has(&"owner"):
		push_error("[GFDeferredMutationQueue] record 失败：owner 选项已移除，请使用 record_method()。")
		return 0

	return _enqueue(mutation, options)


## 通过弱引用 owner 与方法名记录延迟变更。
## 队列不会保存 owner、Callable 或任意持久调用参数的强引用。为避免 metadata
## 间接保活 owner，安全入口只保存 phase、sort_key、order 和 label 选项。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner: 变更拥有者。
## [br]
## @param method_name: playback() 时调用的 owner 方法名。
## [br]
## @param options: 记录选项，支持 phase、sort_key、order 和 label。
## [br]
## @schema options: Dictionary，可包含 phase: StringName、sort_key: int、order: int 和 label: String；不会保存 metadata。
## [br]
## @return 变更句柄；参数无效时返回 0。
func record_method(
	owner: Object,
	method_name: StringName,
	options: Dictionary = {}
) -> int:
	if owner == null or not is_instance_valid(owner):
		push_error("[GFDeferredMutationQueue] record_method 失败：owner 无效。")
		return 0
	if method_name == &"":
		push_error("[GFDeferredMutationQueue] record_method 失败：method_name 为空。")
		return 0

	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(owner, method_name)
	return _enqueue_method(invocation, owner.get_instance_id(), options)


## 按 phase、sort_key、order 和记录句柄的稳定顺序应用延迟变更。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: playback 选项，支持 phase、max_count、max_seconds 和 include_records。
## [br]
## @schema options: Dictionary，可包含 phase: StringName、max_count: int、max_seconds: float、include_records: bool。
## [br]
## @return 应用报告。
## [br]
## @schema return: Dictionary，包含 ok、status、reason、applied_count、failed_count、skipped_owner_count、pending_count、budget_exhausted、phase 和可选 records。
func playback(options: Dictionary = {}) -> Dictionary:
	var phase_filter: StringName = GFVariantData.get_option_string_name(options, "phase", &"")
	if not Thread.is_main_thread():
		return {
			"ok": false,
			"status": STATUS_WRONG_THREAD,
			"reason": STATUS_WRONG_THREAD,
			"applied_count": 0,
			"failed_count": 0,
			"skipped_owner_count": 0,
			"pending_count": get_pending_count(),
			"budget_exhausted": false,
			"phase": phase_filter,
		}
	if _playback_in_progress:
		return {
			"ok": false,
			"status": STATUS_BUSY,
			"reason": STATUS_BUSY,
			"applied_count": 0,
			"failed_count": 0,
			"skipped_owner_count": 0,
			"pending_count": get_pending_count(),
			"budget_exhausted": false,
			"phase": phase_filter,
		}

	_playback_in_progress = true
	var max_count: int = GFVariantData.get_option_int(
		options,
		"max_count",
		max_mutations_per_playback
	)
	var max_seconds: float = GFVariantData.get_option_float(options, "max_seconds", max_seconds_per_playback)
	var limit: int = clampi(
		max_count if max_count > 0 else max_mutations_per_playback,
		1,
		ABSOLUTE_MAX_MUTATIONS_PER_PLAYBACK
	)
	var seconds_budget: float = maxf(max_seconds, 0.0)
	var started_usec: int = Time.get_ticks_usec()
	var applied_now: int = 0
	var failed_now: int = 0
	var skipped_owner_now: int = 0
	var budget_exhausted: bool = false
	var include_records: bool = GFVariantData.get_option_bool(
		options,
		"include_records",
		false
	)
	var processed_records: Array[Dictionary] = []
	_begin_playback_snapshot(phase_filter)

	while applied_now + failed_now + skipped_owner_now < limit:
		if _is_playback_budget_exhausted(started_usec, seconds_budget, applied_now + failed_now + skipped_owner_now):
			budget_exhausted = _has_playback_snapshot_records()
			break

		var mutation_record: Dictionary = _pop_next_playback_record()
		if mutation_record.is_empty():
			break

		if _record_uses_weak_method(mutation_record):
			var invocation: GFWeakMethodInvocation = _get_record_weak_method_invocation(mutation_record)
			if invocation == null:
				failed_now += 1
				_failed_count += 1
				if include_records:
					processed_records.append(
						_record_to_snapshot(mutation_record)
					)
				continue

			var invocation_result: Dictionary = invocation.invoke()
			var invocation_status: StringName = GFVariantData.get_option_string_name(
				invocation_result,
				"status"
			)
			if invocation_status == GFWeakMethodInvocation.STATUS_OWNER_RELEASED:
				skipped_owner_now += 1
				_skipped_owner_count += 1
			elif invocation_status != GFWeakMethodInvocation.STATUS_INVOKED:
				failed_now += 1
				_failed_count += 1
			elif _mutation_result_is_failure(
				GFVariantData.get_option_value(invocation_result, "value")
			):
				failed_now += 1
				_failed_count += 1
			else:
				applied_now += 1
				_applied_count += 1
			if include_records:
				processed_records.append(
					_record_to_snapshot(mutation_record)
				)
			continue

		var mutation: Callable = _get_record_mutation(mutation_record)
		if not mutation.is_valid():
			failed_now += 1
			_failed_count += 1
			if include_records:
				processed_records.append(
					_record_to_snapshot(mutation_record)
				)
			continue

		var result: Variant = mutation.call()
		if _mutation_result_is_failure(result):
			failed_now += 1
			_failed_count += 1
		else:
			applied_now += 1
			_applied_count += 1
		if include_records:
			processed_records.append(_record_to_snapshot(mutation_record))

	var processed_count: int = (
		applied_now
		+ failed_now
		+ skipped_owner_now
	)
	if (
		processed_count >= limit
		and _has_playback_snapshot_records()
	):
		budget_exhausted = true

	_finish_playback_snapshot()
	var report: Dictionary = {
		"ok": true,
		"status": STATUS_COMPLETED,
		"reason": &"",
		"applied_count": applied_now,
		"failed_count": failed_now,
		"skipped_owner_count": skipped_owner_now,
		"pending_count": get_pending_count(),
		"budget_exhausted": budget_exhausted,
		"phase": phase_filter,
	}
	if include_records:
		report["records"] = processed_records
	_playback_in_progress = false
	return report


## 预览待应用变更，不执行回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 预览选项，支持 phase 和 limit；省略或非正 limit 使用有界 playback 默认值。
## [br]
## @schema options: Dictionary，可包含 phase: StringName 和 limit: int。
## [br]
## @return 待应用变更快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 handle、phase、sort_key、order、owner_id、label、metadata 和 recorded_msec。
func preview(options: Dictionary = {}) -> Array[Dictionary]:
	var phase_filter: StringName = GFVariantData.get_option_string_name(options, "phase", &"")
	var requested_limit: int = GFVariantData.get_option_int(
		options,
		"limit",
		max_mutations_per_playback
	)
	var limit: int = clampi(
		requested_limit if requested_limit > 0 else max_mutations_per_playback,
		1,
		ABSOLUTE_MAX_MUTATIONS_PER_PLAYBACK
	)
	var selected_records: Array[Dictionary] = []

	_mutex.lock()
	var pending_records: Array[Dictionary] = _collect_pending_records_locked()
	for mutation_record: Dictionary in pending_records:
		if not _matches_phase(mutation_record, phase_filter):
			continue
		selected_records.append(mutation_record)
		if selected_records.size() >= limit:
			break
	_mutex.unlock()
	var result: Array[Dictionary] = []
	for mutation_record: Dictionary in selected_records:
		result.append(_record_to_snapshot(mutation_record))
	return result


## 取消一条尚未应用的变更。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: record() 或 record_method() 返回的变更句柄。
## [br]
## @return 找到并取消时返回 true。
func cancel(handle: int) -> bool:
	if handle <= 0:
		return false

	_mutex.lock()
	var cancelled: bool = _cancel_handle_locked(handle)
	if cancelled:
		_cancelled_count += 1
	_mutex.unlock()
	return cancelled


## 取消指定 owner 的全部待应用弱方法调用。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 变更拥有者。
## [br]
## @return 取消数量。
func cancel_owner(owner: Object) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0

	var owner_id: int = owner.get_instance_id()
	_mutex.lock()
	var removed_count: int = _cancel_owner_locked(owner_id)
	_cancelled_count += removed_count
	_mutex.unlock()
	return removed_count


## 清空全部待应用变更和统计。句柄与隐式 order 在实例生命周期内保持单调。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_mutex.lock()
	_queue.clear()
	_playback_snapshot.clear()
	_playback_new_records.clear()
	_playback_matching_indexes.clear()
	_playback_matching_cursor = 0
	_playback_snapshot_matching_count = 0
	_pending_count = 0
	_recorded_count = 0
	_applied_count = 0
	_cancelled_count = 0
	_failed_count = 0
	_skipped_owner_count = 0
	_high_watermark = 0
	_rejected_count = 0
	_dropped_count = 0
	_mutex.unlock()


## 获取待应用变更数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 队列长度。
func get_pending_count() -> int:
	_mutex.lock()
	var count: int = _pending_count
	_mutex.unlock()
	return count


## 检查队列是否为空。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 队列为空时返回 true。
func is_empty() -> bool:
	return get_pending_count() == 0


## 获取队列调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 pending_count、max_pending_mutations、max_mutations_per_playback、phase_counts、recorded_count、applied_count、cancelled_count、failed_count、skipped_owner_count、high_watermark、rejected_count 和 dropped_count。
func get_debug_snapshot() -> Dictionary:
	_mutex.lock()
	var pending_records: Array[Dictionary] = _collect_pending_records_locked()
	var pending_count: int = _pending_count
	var recorded_count: int = _recorded_count
	var applied_count: int = _applied_count
	var cancelled_count: int = _cancelled_count
	var failed_count: int = _failed_count
	var skipped_owner_count: int = _skipped_owner_count
	var configured_max_pending: int = max_pending_mutations
	var configured_playback_budget: int = max_mutations_per_playback
	var high_watermark: int = _high_watermark
	var rejected_count: int = _rejected_count
	var dropped_count: int = _dropped_count
	_mutex.unlock()

	var phase_counts: Dictionary = {}
	var handles: PackedInt64Array = PackedInt64Array()
	for mutation_record: Dictionary in pending_records:
		var phase_key: String = String(_get_record_phase(mutation_record))
		phase_counts[phase_key] = GFVariantData.get_option_int(phase_counts, phase_key, 0) + 1
		var _handle_appended: bool = handles.append(_get_record_handle(mutation_record))

	return {
		"pending_count": pending_count,
		"max_pending_mutations": configured_max_pending,
		"max_mutations_per_playback": configured_playback_budget,
		"pending_handles": handles,
		"phase_counts": _sort_dictionary_by_key(phase_counts),
		"recorded_count": recorded_count,
		"applied_count": applied_count,
		"cancelled_count": cancelled_count,
		"failed_count": failed_count,
		"skipped_owner_count": skipped_owner_count,
		"high_watermark": high_watermark,
		"rejected_count": rejected_count,
		"dropped_count": dropped_count,
	}


# --- 私有/辅助方法 ---

func _enqueue(mutation: Callable, options: Dictionary) -> int:
	return _enqueue_record({
		"record_kind": _RECORD_KIND_CALLABLE,
		"mutation": mutation,
	}, 0, options, true)


func _enqueue_method(
	invocation: GFWeakMethodInvocation,
	owner_id: int,
	options: Dictionary
) -> int:
	return _enqueue_record({
		"record_kind": _RECORD_KIND_WEAK_METHOD,
		"weak_method_invocation": invocation,
	}, owner_id, options, false)


func _enqueue_record(
	execution_record: Dictionary,
	owner_id: int,
	options: Dictionary,
	persist_metadata: bool
) -> int:
	_mutex.lock()
	if _pending_count >= max_pending_mutations:
		_rejected_count += 1
		_mutex.unlock()
		return 0
	var handle: int = _next_handle
	_next_handle += 1
	var order: int = GFVariantData.get_option_int(options, "order", _next_order)
	if not options.has("order"):
		_next_order += 1
	var metadata: Dictionary = {}
	if persist_metadata:
		metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	var mutation_record: Dictionary = {
		"handle": handle,
		"owner_id": owner_id,
		"phase": GFVariantData.get_option_string_name(options, "phase", DEFAULT_PHASE),
		"sort_key": GFVariantData.get_option_int(options, "sort_key"),
		"order": order,
		"label": GFVariantData.get_option_string(options, "label"),
		"metadata": metadata,
		"recorded_msec": Time.get_ticks_msec(),
	}
	for execution_key: Variant in execution_record:
		mutation_record[execution_key] = execution_record[execution_key]
	if _playback_snapshot_active:
		_insert_record_sorted_into(
			_playback_new_records,
			mutation_record
		)
	else:
		_insert_record_sorted_into(_queue, mutation_record)
	_pending_count += 1
	_recorded_count += 1
	_high_watermark = maxi(_high_watermark, _pending_count)
	_mutex.unlock()
	return handle


func _begin_playback_snapshot(phase_filter: StringName) -> void:
	_mutex.lock()
	_playback_snapshot = _queue
	_queue = []
	_playback_new_records.clear()
	_playback_matching_indexes.clear()
	_playback_matching_cursor = 0
	_playback_snapshot_matching_count = 0
	_playback_phase_filter = phase_filter
	for index: int in range(_playback_snapshot.size()):
		if not _matches_phase(
			_playback_snapshot[index],
			phase_filter
		):
			continue
		_playback_matching_indexes.append(index)
		_playback_snapshot_matching_count += 1
	_playback_snapshot_active = true
	_mutex.unlock()


func _pop_next_playback_record() -> Dictionary:
	_mutex.lock()
	while (
		_playback_matching_cursor
		< _playback_matching_indexes.size()
	):
		var snapshot_index: int = _playback_matching_indexes[
			_playback_matching_cursor
		]
		_playback_matching_cursor += 1
		var mutation_record: Dictionary = _playback_snapshot[
			snapshot_index
		]
		if mutation_record.is_empty():
			continue
		_playback_snapshot[snapshot_index] = {}
		_playback_snapshot_matching_count -= 1
		_pending_count -= 1
		_mutex.unlock()
		return mutation_record
	_mutex.unlock()
	return {}


func _has_playback_snapshot_records() -> bool:
	_mutex.lock()
	var has_records: bool = _playback_snapshot_matching_count > 0
	_mutex.unlock()
	return has_records


func _finish_playback_snapshot() -> void:
	_mutex.lock()
	var remaining_snapshot: Array[Dictionary] = []
	for mutation_record: Dictionary in _playback_snapshot:
		if mutation_record.is_empty():
			continue
		remaining_snapshot.append(mutation_record)
	_queue = _merge_sorted_records(
		remaining_snapshot,
		_playback_new_records
	)
	_playback_snapshot.clear()
	_playback_new_records.clear()
	_playback_matching_indexes.clear()
	_playback_matching_cursor = 0
	_playback_snapshot_matching_count = 0
	_playback_phase_filter = &""
	_playback_snapshot_active = false
	_pending_count = _queue.size()
	_mutex.unlock()


func _cancel_handle_locked(handle: int) -> bool:
	if not _playback_snapshot_active:
		for index: int in range(_queue.size()):
			if _get_record_handle(_queue[index]) != handle:
				continue
			_queue.remove_at(index)
			_pending_count -= 1
			return true
		return false

	for index: int in range(_playback_snapshot.size()):
		var snapshot_record: Dictionary = _playback_snapshot[index]
		if (
			snapshot_record.is_empty()
			or _get_record_handle(snapshot_record) != handle
		):
			continue
		_playback_snapshot[index] = {}
		if _matches_phase(
			snapshot_record,
			_playback_phase_filter
		):
			_playback_snapshot_matching_count -= 1
		_pending_count -= 1
		return true
	for index: int in range(_playback_new_records.size()):
		if _get_record_handle(_playback_new_records[index]) != handle:
			continue
		_playback_new_records.remove_at(index)
		_pending_count -= 1
		return true
	return false


func _cancel_owner_locked(owner_id: int) -> int:
	var removed_count: int = 0
	if not _playback_snapshot_active:
		for index: int in range(_queue.size() - 1, -1, -1):
			if _get_record_owner_id(_queue[index]) != owner_id:
				continue
			_queue.remove_at(index)
			removed_count += 1
			_pending_count -= 1
		return removed_count

	for index: int in range(_playback_snapshot.size()):
		var snapshot_record: Dictionary = _playback_snapshot[index]
		if (
			snapshot_record.is_empty()
			or _get_record_owner_id(snapshot_record) != owner_id
		):
			continue
		_playback_snapshot[index] = {}
		if _matches_phase(
			snapshot_record,
			_playback_phase_filter
		):
			_playback_snapshot_matching_count -= 1
		removed_count += 1
		_pending_count -= 1
	for index: int in range(
		_playback_new_records.size() - 1,
		-1,
		-1
	):
		if _get_record_owner_id(_playback_new_records[index]) != owner_id:
			continue
		_playback_new_records.remove_at(index)
		removed_count += 1
		_pending_count -= 1
	return removed_count


func _collect_pending_records_locked() -> Array[Dictionary]:
	var pending_records: Array[Dictionary] = []
	if not _playback_snapshot_active:
		for mutation_record: Dictionary in _queue:
			if mutation_record.is_empty():
				continue
			pending_records.append(mutation_record)
		return pending_records

	var remaining_snapshot: Array[Dictionary] = []
	for mutation_record: Dictionary in _playback_snapshot:
		if mutation_record.is_empty():
			continue
		remaining_snapshot.append(mutation_record)
	return _merge_sorted_records(
		remaining_snapshot,
		_playback_new_records
	)


func _merge_sorted_records(
	left_records: Array[Dictionary],
	right_records: Array[Dictionary]
) -> Array[Dictionary]:
	var merged_records: Array[Dictionary] = []
	var left_index: int = 0
	var right_index: int = 0
	while (
		left_index < left_records.size()
		and right_index < right_records.size()
	):
		if _sort_records_ascending(
			left_records[left_index],
			right_records[right_index]
		):
			merged_records.append(left_records[left_index])
			left_index += 1
		else:
			merged_records.append(right_records[right_index])
			right_index += 1
	while left_index < left_records.size():
		merged_records.append(left_records[left_index])
		left_index += 1
	while right_index < right_records.size():
		merged_records.append(right_records[right_index])
		right_index += 1
	return merged_records


func _insert_record_sorted_into(
	target_records: Array[Dictionary],
	mutation_record: Dictionary
) -> void:
	var low: int = 0
	var high: int = target_records.size()
	while low < high:
		var middle: int = floori(float(low + high) / 2.0)
		if _sort_records_ascending(
			mutation_record,
			target_records[middle]
		):
			high = middle
		else:
			low = middle + 1
	var _insert_result: Variant = target_records.insert(
		low,
		mutation_record
	)


func _matches_phase(mutation_record: Dictionary, phase_filter: StringName) -> bool:
	return phase_filter == &"" or _get_record_phase(mutation_record) == phase_filter


func _is_playback_budget_exhausted(started_usec: int, max_seconds: float, processed_count: int) -> bool:
	if max_seconds <= 0.0 or processed_count <= 0:
		return false
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return elapsed_seconds >= max_seconds


func _mutation_result_is_failure(result: Variant) -> bool:
	if result is bool:
		var bool_result: bool = result
		return not bool_result
	if result is Dictionary:
		var dictionary_result: Dictionary = result
		return not GFVariantData.get_option_bool(dictionary_result, "ok", true)
	return false


func _record_uses_weak_method(mutation_record: Dictionary) -> bool:
	return (
		GFVariantData.get_option_string_name(mutation_record, "record_kind")
		== _RECORD_KIND_WEAK_METHOD
	)


func _record_to_snapshot(mutation_record: Dictionary) -> Dictionary:
	return {
		"handle": _get_record_handle(mutation_record),
		"phase": _get_record_phase(mutation_record),
		"sort_key": GFVariantData.get_option_int(mutation_record, "sort_key"),
		"order": GFVariantData.get_option_int(mutation_record, "order"),
		"owner_id": _get_record_owner_id(mutation_record),
		"label": GFVariantData.get_option_string(mutation_record, "label"),
		"metadata": GFVariantData.get_option_dictionary(mutation_record, "metadata").duplicate(true),
		"recorded_msec": GFVariantData.get_option_int(mutation_record, "recorded_msec"),
	}


func _sort_records_ascending(left: Variant, right: Variant) -> bool:
	var left_record: Dictionary = GFVariantData.as_dictionary(left)
	var right_record: Dictionary = GFVariantData.as_dictionary(right)
	var left_phase: String = String(_get_record_phase(left_record))
	var right_phase: String = String(_get_record_phase(right_record))
	if left_phase != right_phase:
		return left_phase < right_phase

	var left_sort_key: int = GFVariantData.get_option_int(left_record, "sort_key")
	var right_sort_key: int = GFVariantData.get_option_int(right_record, "sort_key")
	if left_sort_key != right_sort_key:
		return left_sort_key < right_sort_key

	var left_order: int = GFVariantData.get_option_int(left_record, "order")
	var right_order: int = GFVariantData.get_option_int(right_record, "order")
	if left_order != right_order:
		return left_order < right_order

	return _get_record_handle(left_record) < _get_record_handle(right_record)


func _sort_dictionary_by_key(data: Dictionary) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = keys.append(GFVariantData.to_text(raw_key))
	keys.sort()
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = GFVariantData.duplicate_variant(data.get(key), true)
	return result


func _get_record_handle(mutation_record: Dictionary) -> int:
	return GFVariantData.get_option_int(mutation_record, "handle")


func _get_record_owner_id(mutation_record: Dictionary) -> int:
	return GFVariantData.get_option_int(mutation_record, "owner_id")


func _get_record_phase(mutation_record: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(mutation_record, "phase", DEFAULT_PHASE)


func _get_record_mutation(mutation_record: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(mutation_record, "mutation", Callable())
	if value is Callable:
		var mutation: Callable = value
		return mutation
	return Callable()


func _get_record_weak_method_invocation(
	mutation_record: Dictionary
) -> GFWeakMethodInvocation:
	var value: Variant = GFVariantData.get_option_value(
		mutation_record,
		"weak_method_invocation"
	)
	if value is GFWeakMethodInvocation:
		var invocation: GFWeakMethodInvocation = value
		return invocation
	return null
