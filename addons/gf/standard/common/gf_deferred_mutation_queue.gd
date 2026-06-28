## GFDeferredMutationQueue: 确定性延迟变更队列。
##
## 用于把运行时或工具流程中收集到的状态变更延迟到显式 playback 点执行。
## 队列只保存 Callable、排序信息和诊断 metadata，不解释调用方的实体、组件、
## 节点或资源语义。
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


# --- 公共变量 ---

## playback() 默认每次最多应用多少条变更；小于等于 0 时不限制数量。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_mutations_per_playback: int = 0:
	set(value):
		max_mutations_per_playback = maxi(value, 0)

## playback() 默认最多占用多少秒；小于等于 0 时不启用时间预算。
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
var _next_handle: int = 1
var _next_order: int = 1
var _recorded_count: int = 0
var _applied_count: int = 0
var _cancelled_count: int = 0
var _failed_count: int = 0
var _skipped_owner_count: int = 0


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

## 记录一条延迟变更。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param mutation: playback() 时执行的回调。
## [br]
## @param options: 记录选项，支持 phase、sort_key、order、label、metadata 和 owner。
## [br]
## @schema options: Dictionary，可包含 phase: StringName、sort_key: int、order: int、label: String、metadata: Dictionary、owner: Object。
## [br]
## @return 变更句柄；mutation 无效时返回 0。
func record(mutation: Callable, options: Dictionary = {}) -> int:
	if not mutation.is_valid():
		push_error("[GFDeferredMutationQueue] record 失败：mutation 无效。")
		return 0

	var owner: Object = _variant_to_object(GFVariantData.get_option_value(options, "owner"))
	return _enqueue(mutation, owner, options)


## 记录一条绑定 owner 的延迟变更。owner 释放后变更会在 playback() 时跳过。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 变更拥有者。
## [br]
## @param mutation: playback() 时执行的回调。
## [br]
## @param options: 记录选项，支持 phase、sort_key、order、label 和 metadata。
## [br]
## @schema options: Dictionary，可包含 phase: StringName、sort_key: int、order: int、label: String、metadata: Dictionary。
## [br]
## @return 变更句柄；参数无效时返回 0。
func record_owned(owner: Object, mutation: Callable, options: Dictionary = {}) -> int:
	if owner == null:
		push_error("[GFDeferredMutationQueue] record_owned 失败：owner 为空。")
		return 0
	if not mutation.is_valid():
		push_error("[GFDeferredMutationQueue] record_owned 失败：mutation 无效。")
		return 0

	return _enqueue(mutation, owner, options)


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
## @schema return: Dictionary，包含 applied_count、failed_count、skipped_owner_count、pending_count、budget_exhausted、phase 和可选 records。
func playback(options: Dictionary = {}) -> Dictionary:
	var phase_filter: StringName = GFVariantData.get_option_string_name(options, "phase", &"")
	var max_count: int = GFVariantData.get_option_int(options, "max_count", max_mutations_per_playback)
	var max_seconds: float = GFVariantData.get_option_float(options, "max_seconds", max_seconds_per_playback)
	var limit: int = max_count if max_count > 0 else 2147483647
	var seconds_budget: float = maxf(max_seconds, 0.0)
	var started_usec: int = Time.get_ticks_usec()
	var applied_now: int = 0
	var failed_now: int = 0
	var skipped_owner_now: int = 0
	var budget_exhausted: bool = false
	var processed_records: Array[Dictionary] = []

	while applied_now + failed_now + skipped_owner_now < limit:
		if _is_playback_budget_exhausted(started_usec, seconds_budget, applied_now + failed_now + skipped_owner_now):
			budget_exhausted = true
			break

		var mutation_record: Dictionary = _pop_next_matching_record(phase_filter)
		if mutation_record.is_empty():
			break

		if _record_owner_is_released(mutation_record):
			skipped_owner_now += 1
			_skipped_owner_count += 1
			processed_records.append(_record_to_snapshot(mutation_record))
			continue

		var mutation: Callable = _get_record_mutation(mutation_record)
		if not mutation.is_valid():
			failed_now += 1
			_failed_count += 1
			processed_records.append(_record_to_snapshot(mutation_record))
			continue

		var result: Variant = mutation.call()
		if _mutation_result_is_failure(result):
			failed_now += 1
			_failed_count += 1
		else:
			applied_now += 1
			_applied_count += 1
		processed_records.append(_record_to_snapshot(mutation_record))

	var report: Dictionary = {
		"applied_count": applied_now,
		"failed_count": failed_now,
		"skipped_owner_count": skipped_owner_now,
		"pending_count": get_pending_count(),
		"budget_exhausted": budget_exhausted,
		"phase": phase_filter,
	}
	if GFVariantData.get_option_bool(options, "include_records", false):
		report["records"] = processed_records
	return report


## 预览待应用变更，不执行回调。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 预览选项，支持 phase 和 limit。
## [br]
## @schema options: Dictionary，可包含 phase: StringName 和 limit: int。
## [br]
## @return 待应用变更快照数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 handle、phase、sort_key、order、owner_id、label、metadata 和 recorded_msec。
func preview(options: Dictionary = {}) -> Array[Dictionary]:
	var phase_filter: StringName = GFVariantData.get_option_string_name(options, "phase", &"")
	var limit: int = GFVariantData.get_option_int(options, "limit", 0)
	var result: Array[Dictionary] = []
	var records: Array[Dictionary] = []

	_mutex.lock()
	for mutation_record: Dictionary in _queue:
		records.append(mutation_record.duplicate(true))
	_mutex.unlock()

	records.sort_custom(Callable(self, "_sort_records_ascending"))
	for mutation_record: Dictionary in records:
		if not _matches_phase(mutation_record, phase_filter):
			continue
		result.append(_record_to_snapshot(mutation_record))
		if limit > 0 and result.size() >= limit:
			break
	return result


## 取消一条尚未应用的变更。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param handle: record() 返回的变更句柄。
## [br]
## @return 找到并取消时返回 true。
func cancel(handle: int) -> bool:
	if handle <= 0:
		return false

	_mutex.lock()
	for index: int in range(_queue.size()):
		if _get_record_handle(_queue[index]) == handle:
			_queue.remove_at(index)
			_cancelled_count += 1
			_mutex.unlock()
			return true
	_mutex.unlock()
	return false


## 取消指定 owner 绑定的全部待应用变更。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param owner: 变更拥有者。
## [br]
## @return 取消数量。
func cancel_owner(owner: Object) -> int:
	if owner == null:
		return 0

	var owner_id: int = owner.get_instance_id()
	var removed_count: int = 0
	_mutex.lock()
	for index: int in range(_queue.size() - 1, -1, -1):
		if _get_record_owner_id(_queue[index]) == owner_id:
			_queue.remove_at(index)
			removed_count += 1
	_cancelled_count += removed_count
	_mutex.unlock()
	return removed_count


## 清空全部待应用变更和统计。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_mutex.lock()
	_queue.clear()
	_next_handle = 1
	_next_order = 1
	_recorded_count = 0
	_applied_count = 0
	_cancelled_count = 0
	_failed_count = 0
	_skipped_owner_count = 0
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
	var count: int = _queue.size()
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
## @schema return: Dictionary，包含 pending_count、phase_counts、recorded_count、applied_count、cancelled_count、failed_count 和 skipped_owner_count。
func get_debug_snapshot() -> Dictionary:
	_mutex.lock()
	var phase_counts: Dictionary = {}
	var handles: PackedInt32Array = PackedInt32Array()
	for mutation_record: Dictionary in _queue:
		var phase_key: String = String(_get_record_phase(mutation_record))
		phase_counts[phase_key] = GFVariantData.get_option_int(phase_counts, phase_key, 0) + 1
		var _handle_appended: bool = handles.append(_get_record_handle(mutation_record))
	var pending_count: int = _queue.size()
	var recorded_count: int = _recorded_count
	var applied_count: int = _applied_count
	var cancelled_count: int = _cancelled_count
	var failed_count: int = _failed_count
	var skipped_owner_count: int = _skipped_owner_count
	_mutex.unlock()

	return {
		"pending_count": pending_count,
		"pending_handles": handles,
		"phase_counts": _sort_dictionary_by_key(phase_counts),
		"recorded_count": recorded_count,
		"applied_count": applied_count,
		"cancelled_count": cancelled_count,
		"failed_count": failed_count,
		"skipped_owner_count": skipped_owner_count,
	}


# --- 私有/辅助方法 ---

func _enqueue(mutation: Callable, owner: Object, options: Dictionary) -> int:
	_mutex.lock()
	var handle: int = _next_handle
	_next_handle += 1
	var order: int = GFVariantData.get_option_int(options, "order", _next_order)
	if not options.has("order"):
		_next_order += 1
	var mutation_record: Dictionary = {
		"handle": handle,
		"mutation": mutation,
		"owner_ref": weakref(owner) if owner != null else null,
		"owner_id": owner.get_instance_id() if owner != null else 0,
		"phase": GFVariantData.get_option_string_name(options, "phase", DEFAULT_PHASE),
		"sort_key": GFVariantData.get_option_int(options, "sort_key"),
		"order": order,
		"label": GFVariantData.get_option_string(options, "label"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata").duplicate(true),
		"recorded_msec": Time.get_ticks_msec(),
	}
	_insert_record_sorted(mutation_record)
	_recorded_count += 1
	_mutex.unlock()
	return handle


func _pop_next_matching_record(phase_filter: StringName) -> Dictionary:
	_mutex.lock()
	for index: int in range(_queue.size()):
		var mutation_record: Dictionary = _queue[index]
		if not _matches_phase(mutation_record, phase_filter):
			continue
		_queue.remove_at(index)
		_mutex.unlock()
		return mutation_record
	_mutex.unlock()
	return {}


func _insert_record_sorted(mutation_record: Dictionary) -> void:
	var low: int = 0
	var high: int = _queue.size()
	while low < high:
		var middle: int = floori(float(low + high) / 2.0)
		if _sort_records_ascending(mutation_record, _queue[middle]):
			high = middle
		else:
			low = middle + 1
	var _insert_result: Variant = _queue.insert(low, mutation_record)


func _matches_phase(mutation_record: Dictionary, phase_filter: StringName) -> bool:
	return phase_filter == &"" or _get_record_phase(mutation_record) == phase_filter


func _is_playback_budget_exhausted(started_usec: int, max_seconds: float, processed_count: int) -> bool:
	if max_seconds <= 0.0 or processed_count <= 0:
		return false
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	return elapsed_seconds >= max_seconds


func _record_owner_is_released(mutation_record: Dictionary) -> bool:
	var owner_ref: WeakRef = _get_record_owner_ref(mutation_record)
	return owner_ref != null and owner_ref.get_ref() == null


func _mutation_result_is_failure(result: Variant) -> bool:
	if result is bool:
		var bool_result: bool = result
		return not bool_result
	if result is Dictionary:
		var dictionary_result: Dictionary = result
		return not GFVariantData.get_option_bool(dictionary_result, "ok", true)
	return false


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


func _get_record_owner_ref(mutation_record: Dictionary) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(mutation_record, "owner_ref")
	if value is WeakRef:
		var owner_ref: WeakRef = value
		return owner_ref
	return null


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		return object_value
	return null
