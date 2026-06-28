## GFExecutionLaneDiagnostics: 通用执行通道诊断快照。
##
## 用于记录按 lane 划分的 queued / active / completed / failed / timeout / cancelled
## 等运行态指标。它只保存诊断数据，不调度任务、不决定重试策略，也不绑定具体业务通道。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFExecutionLaneDiagnostics
extends RefCounted


# --- 信号 ---

## lane 快照记录或更新时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @param snapshot: lane 快照副本。
## [br]
## @schema snapshot: Dictionary，包含 queued_count、active_count、completed_count、failed_count、timeout_count、cancelled_count 和 metadata。
signal lane_snapshot_recorded(lane_id: StringName, snapshot: Dictionary)

## lane 事件记录时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @param event: 事件快照副本。
## [br]
## @schema event: Dictionary，包含 event_type、lane_id、status、计数和 metadata。
signal lane_event_recorded(lane_id: StringName, event: Dictionary)


# --- 常量 ---

## lane 处于正常状态。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_OK: StringName = &"ok"

## lane 存在排队积压或取消。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_WARNING: StringName = &"warning"

## lane 存在失败或超时。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_ERROR: StringName = &"error"

## 请求进入队列事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_QUEUED: StringName = &"queued"

## 请求开始执行事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_STARTED: StringName = &"started"

## 请求完成事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_COMPLETED: StringName = &"completed"

## 请求失败事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_FAILED: StringName = &"failed"

## 请求取消事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_CANCELLED: StringName = &"cancelled"

## 请求超时事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_TIMEOUT: StringName = &"timeout"

## 请求释放槽位事件。
## [br]
## @api public
## [br]
## @since 7.0.0
const EVENT_RELEASED: StringName = &"released"

## 默认保留的最近事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_RECENT_EVENTS: int = 128


# --- 公共变量 ---

## 最近事件历史上限。设置为 0 时不保留事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
	set(value):
		max_recent_events = maxi(value, 0)
		_trim_events()

## lane 记录数量上限。为 0 时不限制；自动清理只会移除 inactive lane。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_lanes: int = 1024:
	set(value):
		max_lanes = maxi(value, 0)
		_compact_lanes_if_needed()

## 自动清理 inactive lane 的年龄阈值，单位毫秒。为 0 时不按时间自动清理。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_inactive_lane_age_msec: int = 0:
	set(value):
		max_inactive_lane_age_msec = maxi(value, 0)
		_compact_lanes_if_needed()


# --- 私有变量 ---

var _lanes: Dictionary = {}
var _events: Array[Dictionary] = []
var _next_sequence: int = 1


# --- 公共方法 ---

## 记录一个 lane 的完整快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @param options: 快照选项，支持 queued_count、active_count、completed_count、failed_count、timeout_count、cancelled_count、status、label 和 metadata。
## [br]
## @return lane 快照。
## [br]
## @schema options: Dictionary，包含计数、status、label 和 metadata。
## [br]
## @schema return: Dictionary，包含 lane_id、status、计数、max_queued_count、max_active_count、event_count 和 metadata。
func record_lane_snapshot(lane_id: StringName, options: Dictionary = {}) -> Dictionary:
	if lane_id == &"":
		return {}
	var lane: Dictionary = _get_or_create_lane(lane_id)
	lane["label"] = GFVariantData.get_option_string(options, "label", GFVariantData.get_option_string(lane, "label", String(lane_id)))
	lane["queued_count"] = maxi(GFVariantData.get_option_int(options, "queued_count", GFVariantData.get_option_int(lane, "queued_count")), 0)
	lane["active_count"] = maxi(GFVariantData.get_option_int(options, "active_count", GFVariantData.get_option_int(lane, "active_count")), 0)
	lane["completed_count"] = maxi(GFVariantData.get_option_int(options, "completed_count", GFVariantData.get_option_int(lane, "completed_count")), 0)
	lane["failed_count"] = maxi(GFVariantData.get_option_int(options, "failed_count", GFVariantData.get_option_int(lane, "failed_count")), 0)
	lane["timeout_count"] = maxi(GFVariantData.get_option_int(options, "timeout_count", GFVariantData.get_option_int(lane, "timeout_count")), 0)
	lane["cancelled_count"] = maxi(GFVariantData.get_option_int(options, "cancelled_count", GFVariantData.get_option_int(lane, "cancelled_count")), 0)
	lane["metadata"] = GFVariantData.merge_dictionary(
		GFVariantData.get_option_dictionary(lane, "metadata"),
		GFVariantData.get_option_dictionary(options, "metadata"),
		true,
		true
	)
	_update_lane_peaks(lane)
	lane["status"] = _normalize_status(GFVariantData.get_option_string_name(options, "status", _derive_lane_status(lane)))
	lane["last_seen_msec"] = Time.get_ticks_msec()
	lane["last_sequence"] = _take_sequence()
	_lanes[lane_id] = lane
	_compact_lanes_if_needed()
	var snapshot: Dictionary = _lane_to_snapshot(lane)
	lane_snapshot_recorded.emit(lane_id, snapshot.duplicate(true))
	return snapshot


## 记录一个 lane 事件并更新计数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @param event_type: 事件类型，建议使用 EVENT_* 常量。
## [br]
## @param options: 事件选项，支持 queued_delta、active_delta、status、label 和 metadata。
## [br]
## @return 事件快照。
## [br]
## @schema options: Dictionary，包含 queued_delta、active_delta、status、label 和 metadata。
## [br]
## @schema return: Dictionary，包含 sequence、event_type、lane_id、status、计数和 metadata。
func record_lane_event(lane_id: StringName, event_type: StringName, options: Dictionary = {}) -> Dictionary:
	if lane_id == &"" or event_type == &"":
		return {}
	var lane: Dictionary = _get_or_create_lane(lane_id)
	var event_metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var queued_delta: int = GFVariantData.get_option_int(options, "queued_delta", _default_queued_delta(event_type))
	var active_delta: int = GFVariantData.get_option_int(options, "active_delta", _default_active_delta(event_type))
	lane["label"] = GFVariantData.get_option_string(options, "label", GFVariantData.get_option_string(lane, "label", String(lane_id)))
	lane["queued_count"] = maxi(GFVariantData.get_option_int(lane, "queued_count") + queued_delta, 0)
	lane["active_count"] = maxi(GFVariantData.get_option_int(lane, "active_count") + active_delta, 0)
	lane["event_count"] = GFVariantData.get_option_int(lane, "event_count") + 1
	lane["last_event_type"] = event_type
	lane["last_seen_msec"] = Time.get_ticks_msec()
	lane["last_sequence"] = _take_sequence()
	lane["metadata"] = GFVariantData.merge_dictionary(
		GFVariantData.get_option_dictionary(lane, "metadata"),
		event_metadata,
		true,
		true
	)
	match event_type:
		EVENT_COMPLETED:
			lane["completed_count"] = GFVariantData.get_option_int(lane, "completed_count") + 1
		EVENT_FAILED:
			lane["failed_count"] = GFVariantData.get_option_int(lane, "failed_count") + 1
		EVENT_CANCELLED:
			lane["cancelled_count"] = GFVariantData.get_option_int(lane, "cancelled_count") + 1
		EVENT_TIMEOUT:
			lane["timeout_count"] = GFVariantData.get_option_int(lane, "timeout_count") + 1
		_:
			pass
	_update_lane_peaks(lane)
	lane["status"] = _normalize_status(GFVariantData.get_option_string_name(options, "status", _derive_lane_status(lane)))
	_lanes[lane_id] = lane
	_compact_lanes_if_needed()

	var event: Dictionary = {
		"sequence": GFVariantData.get_option_int(lane, "last_sequence"),
		"event_type": event_type,
		"lane_id": lane_id,
		"status": GFVariantData.get_option_string_name(lane, "status", STATUS_OK),
		"queued_count": GFVariantData.get_option_int(lane, "queued_count"),
		"active_count": GFVariantData.get_option_int(lane, "active_count"),
		"completed_count": GFVariantData.get_option_int(lane, "completed_count"),
		"failed_count": GFVariantData.get_option_int(lane, "failed_count"),
		"timeout_count": GFVariantData.get_option_int(lane, "timeout_count"),
		"cancelled_count": GFVariantData.get_option_int(lane, "cancelled_count"),
		"metadata": event_metadata.duplicate(true),
		"timestamp_msec": Time.get_ticks_msec(),
	}
	_events.append(event)
	_trim_events()
	lane_event_recorded.emit(lane_id, event.duplicate(true))
	return event.duplicate(true)


## 移除一个 lane。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @return 找到并移除时返回 true。
func remove_lane(lane_id: StringName) -> bool:
	if not _lanes.has(lane_id):
		return false
	var _erased_lane: bool = _lanes.erase(lane_id)
	return true


## 清理 inactive lane。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param max_age_msec: 大于等于 0 时移除超过该年龄的 inactive lane；小于 0 时仅应用 max_lanes 容量上限。
## [br]
## @return 移除的 lane 数量。
func compact_lanes(max_age_msec: int = -1) -> int:
	return _compact_lanes(max_age_msec)


## 清空全部 lane 和事件历史。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_lanes.clear()
	_events.clear()
	_next_sequence = 1


## 获取一个 lane 的快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param lane_id: 执行通道 ID。
## [br]
## @return lane 快照；不存在时为空字典。
## [br]
## @schema return: Dictionary，包含 lane_id、status、计数、max_queued_count、max_active_count、event_count 和 metadata。
func get_lane_snapshot(lane_id: StringName) -> Dictionary:
	if not _lanes.has(lane_id):
		return {}
	return _lane_to_snapshot(GFVariantData.as_dictionary(_lanes[lane_id]))


## 获取全部 lane 快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部。
## [br]
## @return lane 快照数组，按最近更新时间倒序排列。
## [br]
## @schema return: Array[Dictionary]，每个元素为 lane 快照。
func get_lane_snapshots(limit: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for lane_value: Variant in _lanes.values():
		result.append(_lane_to_snapshot(GFVariantData.as_dictionary(lane_value)))
	result.sort_custom(Callable(self, "_sort_snapshots_desc"))
	if limit <= 0 or result.size() <= limit:
		return result
	var limited: Array[Dictionary] = []
	for index: int in range(limit):
		limited.append(result[index])
	return limited


## 获取最近 lane 事件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部。
## [br]
## @return 最近事件数组，按记录顺序返回。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 sequence、event_type、lane_id、status、计数和 metadata。
func get_recent_events(limit: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = 0
	if limit > 0 and _events.size() > limit:
		start_index = _events.size() - limit
	for index: int in range(start_index, _events.size()):
		result.append(_events[index].duplicate(true))
	return result


## 获取整体健康快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: recent_lanes 与 recent_events 的最大数量。
## [br]
## @return 健康快照字典。
## [br]
## @schema return: Dictionary，包含 status、lane_count、queued_count、active_count、failed_count、timeout_count、cancelled_count、recent_lanes 和 recent_events。
func get_health_snapshot(limit: int = 5) -> Dictionary:
	var queued_count: int = 0
	var active_count: int = 0
	var completed_count: int = 0
	var failed_count: int = 0
	var timeout_count: int = 0
	var cancelled_count: int = 0
	var status: StringName = STATUS_OK
	for lane_value: Variant in _lanes.values():
		var lane: Dictionary = GFVariantData.as_dictionary(lane_value)
		queued_count += GFVariantData.get_option_int(lane, "queued_count")
		active_count += GFVariantData.get_option_int(lane, "active_count")
		completed_count += GFVariantData.get_option_int(lane, "completed_count")
		failed_count += GFVariantData.get_option_int(lane, "failed_count")
		timeout_count += GFVariantData.get_option_int(lane, "timeout_count")
		cancelled_count += GFVariantData.get_option_int(lane, "cancelled_count")
		status = _max_status(status, GFVariantData.get_option_string_name(lane, "status", STATUS_OK))
	return {
		"status": status,
		"lane_count": _lanes.size(),
		"queued_count": queued_count,
		"active_count": active_count,
		"completed_count": completed_count,
		"failed_count": failed_count,
		"timeout_count": timeout_count,
		"cancelled_count": cancelled_count,
		"recent_lanes": get_lane_snapshots(limit),
		"recent_events": get_recent_events(limit),
	}


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary，包含 max_recent_events、health、lanes 和 recent_events。
func get_debug_snapshot() -> Dictionary:
	return {
		"max_recent_events": max_recent_events,
		"max_lanes": max_lanes,
		"max_inactive_lane_age_msec": max_inactive_lane_age_msec,
		"health": get_health_snapshot(5),
		"lanes": get_lane_snapshots(),
		"recent_events": get_recent_events(),
	}


# --- 私有/辅助方法 ---

func _get_or_create_lane(lane_id: StringName) -> Dictionary:
	if _lanes.has(lane_id):
		return GFVariantData.as_dictionary(_lanes[lane_id])
	return {
		"lane_id": lane_id,
		"label": String(lane_id),
		"status": STATUS_OK,
		"queued_count": 0,
		"active_count": 0,
		"completed_count": 0,
		"failed_count": 0,
		"timeout_count": 0,
		"cancelled_count": 0,
		"max_queued_count": 0,
		"max_active_count": 0,
		"event_count": 0,
		"last_event_type": &"",
		"last_seen_msec": 0,
		"last_sequence": 0,
		"metadata": {},
	}


func _lane_to_snapshot(lane: Dictionary) -> Dictionary:
	return {
		"lane_id": GFVariantData.get_option_string_name(lane, "lane_id"),
		"label": GFVariantData.get_option_string(lane, "label"),
		"status": GFVariantData.get_option_string_name(lane, "status", STATUS_OK),
		"queued_count": GFVariantData.get_option_int(lane, "queued_count"),
		"active_count": GFVariantData.get_option_int(lane, "active_count"),
		"completed_count": GFVariantData.get_option_int(lane, "completed_count"),
		"failed_count": GFVariantData.get_option_int(lane, "failed_count"),
		"timeout_count": GFVariantData.get_option_int(lane, "timeout_count"),
		"cancelled_count": GFVariantData.get_option_int(lane, "cancelled_count"),
		"max_queued_count": GFVariantData.get_option_int(lane, "max_queued_count"),
		"max_active_count": GFVariantData.get_option_int(lane, "max_active_count"),
		"event_count": GFVariantData.get_option_int(lane, "event_count"),
		"last_event_type": GFVariantData.get_option_string_name(lane, "last_event_type"),
		"last_seen_msec": GFVariantData.get_option_int(lane, "last_seen_msec"),
		"last_sequence": GFVariantData.get_option_int(lane, "last_sequence"),
		"metadata": GFVariantData.get_option_dictionary(lane, "metadata"),
	}


func _update_lane_peaks(lane: Dictionary) -> void:
	lane["max_queued_count"] = maxi(
		GFVariantData.get_option_int(lane, "max_queued_count"),
		GFVariantData.get_option_int(lane, "queued_count")
	)
	lane["max_active_count"] = maxi(
		GFVariantData.get_option_int(lane, "max_active_count"),
		GFVariantData.get_option_int(lane, "active_count")
	)


func _derive_lane_status(lane: Dictionary) -> StringName:
	if GFVariantData.get_option_int(lane, "failed_count") > 0 or GFVariantData.get_option_int(lane, "timeout_count") > 0:
		return STATUS_ERROR
	if GFVariantData.get_option_int(lane, "cancelled_count") > 0 or GFVariantData.get_option_int(lane, "queued_count") > 0:
		return STATUS_WARNING
	return STATUS_OK


func _normalize_status(status: StringName) -> StringName:
	match status:
		STATUS_WARNING, STATUS_ERROR:
			return status
		_:
			return STATUS_OK


func _max_status(left: StringName, right: StringName) -> StringName:
	if _status_rank(right) > _status_rank(left):
		return right
	return left


func _status_rank(status: StringName) -> int:
	match status:
		STATUS_ERROR:
			return 2
		STATUS_WARNING:
			return 1
		_:
			return 0


func _default_queued_delta(event_type: StringName) -> int:
	match event_type:
		EVENT_QUEUED:
			return 1
		EVENT_STARTED:
			return -1
		_:
			return 0


func _default_active_delta(event_type: StringName) -> int:
	match event_type:
		EVENT_STARTED:
			return 1
		EVENT_COMPLETED, EVENT_FAILED, EVENT_CANCELLED, EVENT_TIMEOUT, EVENT_RELEASED:
			return -1
		_:
			return 0


func _take_sequence() -> int:
	var result: int = _next_sequence
	_next_sequence += 1
	return result


func _trim_events() -> void:
	while _events.size() > max_recent_events:
		_events.pop_front()


func _compact_lanes_if_needed() -> void:
	if max_inactive_lane_age_msec > 0:
		var _removed_by_age: int = _compact_lanes(max_inactive_lane_age_msec)
	elif max_lanes > 0 and _lanes.size() > max_lanes:
		var _removed_by_count: int = _compact_lanes(-1)


func _compact_lanes(max_age_msec: int) -> int:
	var removed_count: int = 0
	if max_age_msec >= 0:
		var cutoff_msec: int = Time.get_ticks_msec() - max_age_msec
		for lane_id: StringName in _sorted_lane_ids_for_removal():
			var lane: Dictionary = GFVariantData.as_dictionary(_lanes.get(lane_id, {}))
			if _lane_is_active(lane):
				continue
			if GFVariantData.get_option_int(lane, "last_seen_msec") > cutoff_msec:
				continue
			var _erased_by_age: bool = _lanes.erase(lane_id)
			removed_count += 1
	if max_lanes > 0:
		for lane_id: StringName in _sorted_lane_ids_for_removal():
			if _lanes.size() <= max_lanes:
				break
			var lane: Dictionary = GFVariantData.as_dictionary(_lanes.get(lane_id, {}))
			if _lane_is_active(lane):
				continue
			var _erased_by_count: bool = _lanes.erase(lane_id)
			removed_count += 1
	return removed_count


func _sorted_lane_ids_for_removal() -> Array[StringName]:
	var lane_ids: Array[StringName] = []
	for raw_lane_id: Variant in _lanes.keys():
		var lane_id: StringName = GFVariantData.to_string_name(raw_lane_id)
		if lane_id != &"":
			lane_ids.append(lane_id)
	lane_ids.sort_custom(func(left: StringName, right: StringName) -> bool:
		var left_lane: Dictionary = GFVariantData.as_dictionary(_lanes.get(left, {}))
		var right_lane: Dictionary = GFVariantData.as_dictionary(_lanes.get(right, {}))
		return GFVariantData.get_option_int(left_lane, "last_sequence") < GFVariantData.get_option_int(right_lane, "last_sequence")
	)
	return lane_ids


func _lane_is_active(lane: Dictionary) -> bool:
	return (
		GFVariantData.get_option_int(lane, "queued_count") > 0
		or GFVariantData.get_option_int(lane, "active_count") > 0
	)


func _sort_snapshots_desc(left: Variant, right: Variant) -> bool:
	var left_snapshot: Dictionary = GFVariantData.as_dictionary(left)
	var right_snapshot: Dictionary = GFVariantData.as_dictionary(right)
	return GFVariantData.get_option_int(left_snapshot, "last_sequence") > GFVariantData.get_option_int(right_snapshot, "last_sequence")
