## GFNotificationUtility: 通用运行时通知队列。
##
## 只管理通知数据、队列、去重和生命周期信号，不规定 Toast、HUD 或编辑器 UI 样式。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNotificationUtility
extends GFUtility


# --- 信号 ---

## 通知进入队列时发出。
## [br]
## @api public
## [br]
## @param notification: 通知副本。
## [br]
## @schema notification: Dictionary，包含 id、key、dedupe_key、title、message、level、priority、sticky、duration_seconds、created_at_unix、actions 和 metadata。
signal notification_queued(notification: Dictionary)

## 通知开始展示时发出。
## [br]
## @api public
## [br]
## @param notification: 通知副本。
## [br]
## @schema notification: Dictionary，字段同 notification_queued 的 notification。
signal notification_started(notification: Dictionary)

## 通知结束时发出。
## [br]
## @api public
## [br]
## @param notification: 通知副本。
## [br]
## @param reason: 结束原因。
## [br]
## @schema notification: Dictionary，字段同 notification_queued 的 notification。
signal notification_finished(notification: Dictionary, reason: String)

## 当前通知动作被触发时发出。
## [br]
## @api public
## [br]
## @param notification: 当前通知副本。
## [br]
## @param action_id: 动作标识。
## [br]
## @schema notification: Dictionary，字段同 notification_queued 的 notification。
signal notification_action_invoked(notification: Dictionary, action_id: StringName)


# --- 枚举 ---

## 通知等级。
## [br]
## @api public
enum Level {
	## 普通信息。
	INFO,
	## 成功反馈。
	SUCCESS,
	## 警告信息。
	WARNING,
	## 错误信息。
	ERROR,
}

## 通知优先级。数值越大越靠前。
## [br]
## @api public
enum Priority {
	## 低优先级。
	LOW,
	## 默认优先级。
	NORMAL,
	## 高优先级。
	HIGH,
	## 最高优先级。
	CRITICAL,
}


# --- 公共变量 ---

## 默认展示时长。
## [br]
## @api public
var default_duration_seconds: float = 3.0

## 最大排队数量。设为 0 时只允许当前通知，不保留等待队列。
## [br]
## @api public
var max_queue_size: int = 32

## 是否抑制重复入队。有显式 key 时按 key 去重，否则按消息文本去重。
## [br]
## @api public
var suppress_duplicates: bool = true


# --- 私有变量 ---

## 等待开始展示的通知记录，按优先级及入队顺序排列；当前通知单独保存在 _active_notification。
## [br]
## @api private
var _queue: Array[Dictionary] = []

## 当前正在展示的通知记录；结束或清空时会移除。
## [br]
## @api private
var _active_notification: Dictionary = {}

## 当前通知尚余展示秒数，由 tick 递减；暂停或 sticky 通知不递减。
## [br]
## @api private
var _active_remaining_seconds: float = 0.0

## 是否暂停当前通知的倒计时。
## [br]
## @api private
var _active_paused: bool = false

## 下一个新通知记录使用的递增 id。
## [br]
## @api private
var _next_notification_id: int = 1


# --- GF 生命周期方法 ---

## 推进运行时逻辑。
## [br]
## @api public
## [br]
## @param delta: 本帧时间增量（秒）。
func tick(delta: float) -> void:
	if _active_notification.is_empty():
		_start_next_notification()
		return
	if _active_paused or GFVariantData.get_option_bool(_active_notification, "sticky"):
		return

	_active_remaining_seconds -= maxf(delta, 0.0)
	if _active_remaining_seconds <= 0.0:
		dismiss_active("timeout")

## 释放通知队列状态。
## [br]
## @api public
func dispose() -> void:
	clear_notifications("disposed")


# --- 公共方法 ---

## 推入通知。
## [br]
## @api public
## [br]
## @param message: 通知正文。
## [br]
## @param title: 通知标题。
## [br]
## @param level: 通知等级。
## [br]
## @param options: 可选参数，支持 duration_seconds、key、metadata、priority、sticky、actions。
## [br]
## @return 通知 id；被去重抑制时返回已有通知 id。
## [br]
## @schema options: Dictionary，支持 duration_seconds、key、metadata、priority、sticky 和 actions。actions 为 Array[StringName|String|Dictionary]，Dictionary action 包含 id、可选 label、dismiss 和 metadata；label 为空时由项目 UI 决定展示文案。
func push_notification(
	message: String,
	title: String = "",
	level: Level = Level.INFO,
	options: Dictionary = {}
) -> int:
	if message.is_empty() and title.is_empty():
		return 0

	var duplicate_id: int = _find_duplicate_notification_id(message, options)
	if suppress_duplicates and duplicate_id > 0:
		return duplicate_id

	var notification_record: Dictionary = _make_notification(message, title, level, options)
	_queue.append(notification_record)
	notification_queued.emit(notification_record.duplicate(true))
	if _active_notification.is_empty():
		_start_next_notification()
	_trim_queue()
	return GFVariantData.to_int(notification_record["id"])


## 结束当前通知。
## [br]
## @api public
## [br]
## @param reason: 结束原因。
func dismiss_active(reason: String = "dismissed") -> void:
	if _active_notification.is_empty():
		return

	var finished: Dictionary = _active_notification.duplicate(true)
	_active_notification.clear()
	_active_remaining_seconds = 0.0
	_active_paused = false
	notification_finished.emit(finished, reason)
	_start_next_notification()


## 清空当前通知和等待队列。
## [br]
## @api public
## [br]
## @param reason: 结束原因。
func clear_notifications(reason: String = "cleared") -> void:
	if not _active_notification.is_empty():
		var finished: Dictionary = _active_notification.duplicate(true)
		notification_finished.emit(finished, reason)
	_active_notification.clear()
	_active_remaining_seconds = 0.0
	_active_paused = false
	_queue.clear()


## 获取当前通知。
## [br]
## @api public
## [br]
## @return 当前通知副本。
## [br]
## @schema return: Dictionary，当前通知记录；无当前通知时为空。字段同 notification_queued 的 notification。
func get_active_notification() -> Dictionary:
	return _active_notification.duplicate(true)


## 暂停当前通知倒计时。
## [br]
## @api public
func pause_active() -> void:
	if not _active_notification.is_empty():
		_active_paused = true


## 恢复当前通知倒计时。
## [br]
## @api public
func resume_active() -> void:
	_active_paused = false


## 当前通知是否处于暂停状态。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_active_paused() -> bool:
	return _active_paused


## 触发当前通知的一个动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 当前通知包含该动作时返回 true。
func invoke_active_action(action_id: StringName) -> bool:
	if _active_notification.is_empty() or action_id == &"":
		return false

	var actions: Array = GFVariantData.get_option_array(_active_notification, "actions")
	for action_value: Variant in actions:
		var action: Dictionary = GFVariantData.as_dictionary(action_value)
		if GFVariantData.get_option_string_name(action, "id") == action_id:
			notification_action_invoked.emit(_active_notification.duplicate(true), action_id)
			if GFVariantData.get_option_bool(action, "dismiss"):
				dismiss_active("action:%s" % action_id)
			return true
	return false


## 获取等待队列。
## [br]
## @api public
## [br]
## @return 通知副本数组。
## [br]
## @schema return: Array，元素为通知记录 Dictionary，字段同 notification_queued 的 notification。
func get_queue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for notification_record: Dictionary in _queue:
		result.append(notification_record.duplicate(true))
	return result


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 通知队列状态。
## [br]
## @schema return: Dictionary，包含 active、queue、queue_size、active_remaining_seconds、active_paused 和 max_queue_size。
func get_debug_snapshot() -> Dictionary:
	return {
		"active": get_active_notification(),
		"queue": get_queue(),
		"queue_size": _queue.size(),
		"active_remaining_seconds": _active_remaining_seconds,
		"active_paused": _active_paused,
		"max_queue_size": max_queue_size,
	}


# --- 私有/辅助方法 ---

## 根据输入选项组装通知记录，并分配唯一递增 id。
## [br]
## @api private
func _make_notification(
	message: String,
	title: String,
	level: Level,
	options: Dictionary
) -> Dictionary:
	var notification_record: Dictionary = {
		"id": _next_notification_id,
		"key": GFVariantData.get_option_string(options, "key", message),
		"dedupe_key": GFVariantData.get_option_string(options, "key"),
		"title": title,
		"message": message,
		"level": level,
		"priority": clampi(GFVariantData.get_option_int(options, "priority", Priority.NORMAL), Priority.LOW, Priority.CRITICAL),
		"sticky": GFVariantData.get_option_bool(options, "sticky", false),
		"duration_seconds": maxf(GFVariantData.get_option_float(options, "duration_seconds", default_duration_seconds), 0.0),
		"created_at_unix": Time.get_unix_time_from_system(),
		"actions": _normalize_actions(GFVariantData.get_option_value(options, "actions", [])),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	_next_notification_id += 1
	return notification_record


## 队列有待处理记录且当前没有活动通知时，启动队首记录并初始化其倒计时。
## [br]
## @api private
func _start_next_notification() -> void:
	if not _active_notification.is_empty() or _queue.is_empty():
		return

	_active_notification = GFVariantData.as_dictionary(_queue.pop_front())
	_active_paused = false
	_active_remaining_seconds = GFVariantData.get_option_float(
		_active_notification,
		"duration_seconds",
		default_duration_seconds
	)
	notification_started.emit(_active_notification.duplicate(true))
	if _active_remaining_seconds <= 0.0 and not GFVariantData.get_option_bool(_active_notification, "sticky"):
		dismiss_active("timeout")


## 按优先级整理等待队列，并丢弃超出容量的末尾记录。
## [br]
## @api private
func _trim_queue() -> void:
	_sort_queue_by_priority()
	var max_size: int = maxi(max_queue_size, 0)
	while _queue.size() > max_size:
		var dropped: Dictionary = GFVariantData.as_dictionary(_queue.pop_back())
		notification_finished.emit(dropped.duplicate(true), "dropped")


## 在活动通知和等待队列中查找首个去重匹配项；没有匹配时返回 0。
## [br]
## @api private
func _find_duplicate_notification_id(message: String, options: Dictionary) -> int:
	var key: String = GFVariantData.get_option_string(options, "key")
	if _matches_notification(_active_notification, key, message):
		return GFVariantData.get_option_int(_active_notification, "id")

	for notification_record: Dictionary in _queue:
		if _matches_notification(notification_record, key, message):
			return GFVariantData.get_option_int(notification_record, "id")
	return 0


## 显式 key 只匹配相同去重 key；未提供 key 时仅匹配同样没有显式 key 且消息相同的记录。
## [br]
## @api private
func _matches_notification(notification_record: Dictionary, key: String, message: String) -> bool:
	if notification_record.is_empty():
		return false

	var notification_key: String = GFVariantData.get_option_string(notification_record, "dedupe_key")
	if not key.is_empty():
		return notification_key == key
	if not notification_key.is_empty():
		return false
	return GFVariantData.get_option_string(notification_record, "message") == message


## 将等待队列按优先级降序、同优先级 id 升序排列。
## [br]
## @api private
func _sort_queue_by_priority() -> void:
	_queue.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = GFVariantData.get_option_int(left, "priority", Priority.NORMAL)
		var right_priority: int = GFVariantData.get_option_int(right, "priority", Priority.NORMAL)
		if left_priority == right_priority:
			return GFVariantData.get_option_int(left, "id") < GFVariantData.get_option_int(right, "id")
		return left_priority > right_priority
	)


## 将动作输入规整为有效动作记录；只接受字符串标识或含非空 id 的 Dictionary。
## [br]
## @api private
func _normalize_actions(actions_variant: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (actions_variant is Array):
		return result

	for action_variant: Variant in GFVariantData.as_array(actions_variant):
		if action_variant is StringName or action_variant is String:
			var simple_action_id: StringName = GFVariantData.to_string_name(action_variant)
			if simple_action_id != &"":
				result.append({
					"id": simple_action_id,
					"label": "",
					"dismiss": false,
					"metadata": {},
				})
			continue
		if not (action_variant is Dictionary):
			continue

		var source: Dictionary = GFVariantData.as_dictionary(action_variant)
		var dictionary_action_id: StringName = GFVariantData.get_option_string_name(source, "id")
		if dictionary_action_id == &"":
			continue
		result.append({
			"id": dictionary_action_id,
			"label": GFVariantData.get_option_string(source, "label"),
			"dismiss": GFVariantData.get_option_bool(source, "dismiss"),
			"metadata": GFVariantData.get_option_dictionary(source, "metadata"),
		})
	return result
