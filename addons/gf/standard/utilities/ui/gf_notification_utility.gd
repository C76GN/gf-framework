## GFNotificationUtility: 通用运行时通知队列。
##
## 管理通知数据、队列、去重和生命周期信号。默认串行展示，可配置多个活动通知。
## 单条活动通知接口面向最早开始展示且仍在活动的记录。项目决定展示布局和样式。
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

## 活动通知的动作被触发时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param notification: 触发动作的通知副本。
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


# --- 常量 ---

## 限制活动通知数量，使每帧倒计时与批量完成回调的规模有上界。
## [br]
## @api private
const _MAX_ACTIVE_NOTIFICATIONS: int = 32


# --- 公共变量 ---

## 默认展示时长。
## [br]
## @api public
var default_duration_seconds: float = 3.0

## 最大等待数量。设为 0 时只保留活动通知。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_queue_size: int = 32

## 活动通知的准入上限，默认 1，范围 1 至 32。提高上限会补入等待通知。降低上限时已有活动通知自然结束。
## [br]
## @api public
## [br]
## @since unreleased
var max_active_notifications: int = 1:
	set(value):
		max_active_notifications = clampi(
			value,
			1,
			_MAX_ACTIVE_NOTIFICATIONS
		)
		_process_queue()

## 是否抑制重复入队。有显式 key 时按 key 去重，否则按消息文本去重。
## [br]
## @api public
var suppress_duplicates: bool = true


# --- 私有变量 ---

## 尚未开始展示的记录，按优先级降序和入队顺序排列。
## [br]
## @api private
var _queue: Array[Dictionary] = []

## 活动通知按 ID 查找，并按 Dictionary 的插入顺序遍历，供单条入口选取最早仍活动的通知。
## [br]
## @api private
var _active_notifications: Dictionary[int, _ActiveNotification] = {}

## 队列处理和生命周期信号交付期间暂缓再次补位，直到最外层操作结束。
## [br]
## @api private
var _queue_update_depth: int = 0

## 清空和释放期间拒绝回调重新入队，使清空的通知批次具有确定终态。
## [br]
## @api private
var _clearing_notifications: bool = false

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
	if _active_notifications.is_empty():
		_process_queue()
		return

	var elapsed: float = maxf(delta, 0.0)
	var expired_ids: Array[int] = []
	for notification_id: int in _active_notifications:
		var active: _ActiveNotification = _active_notifications[notification_id]
		if active._paused or GFVariantData.get_option_bool(active._record, "sticky"):
			continue
		active._remaining_seconds -= elapsed
		if active._remaining_seconds <= 0.0:
			expired_ids.append(notification_id)
	if not expired_ids.is_empty():
		_finish_active_notifications(expired_ids, "timeout")


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
## @since 3.17.0
## [br]
## @param message: 通知正文。
## [br]
## @param title: 通知标题。
## [br]
## @param level: 通知等级。
## [br]
## @param options: 可选参数，支持 duration_seconds、key、metadata、priority、sticky、actions。
## [br]
## @return 接纳时返回通知 ID。重复通知返回已有 ID，空通知和清空期间的请求返回 0。
## [br]
## @schema options: Dictionary，支持 duration_seconds、key、metadata、priority、sticky 和 actions。actions 为 Array[StringName|String|Dictionary]，Dictionary action 包含 id、可选 label、dismiss 和 metadata；label 为空时由项目 UI 决定展示文案。
func push_notification(
	message: String,
	title: String = "",
	level: Level = Level.INFO,
	options: Dictionary = {}
) -> int:
	if _clearing_notifications:
		return 0
	if message.is_empty() and title.is_empty():
		return 0

	var duplicate_id: int = _find_duplicate_notification_id(message, options)
	if suppress_duplicates and duplicate_id > 0:
		return duplicate_id

	var notification_record: Dictionary = _make_notification(
		message,
		title,
		level,
		options
	)
	_queue.append(notification_record)
	_sort_queue_by_priority()
	_queue_update_depth += 1
	notification_queued.emit(notification_record.duplicate(true))
	_queue_update_depth -= 1
	_process_queue()
	return GFVariantData.to_int(notification_record["id"])


## 结束当前通知。
## [br]
## @api public
## [br]
## @param reason: 结束原因。
func dismiss_active(reason: String = "dismissed") -> void:
	var active_id: int = _get_oldest_active_id()
	var _dismissed: bool = dismiss_notification(active_id, reason)


## 按 ID 结束一条活动通知并处理腾出的名额。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param notification_id: push_notification() 返回的通知 ID。
## [br]
## @param reason: 交给 notification_finished 的结束原因。
## [br]
## @return 该 ID 处于活动状态并已结束时返回 true。
func dismiss_notification(notification_id: int, reason: String = "dismissed") -> bool:
	if not _active_notifications.has(notification_id):
		return false
	var finished_ids: Array[int] = [notification_id]
	_finish_active_notifications(finished_ids, reason)
	return true


## 先撤下全部活动通知并清空等待队列，再为每条原先活动的通知发出结束信号。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param reason: 结束原因。
func clear_notifications(reason: String = "cleared") -> void:
	if _clearing_notifications:
		return

	_clearing_notifications = true
	_queue.clear()
	var finished_ids: Array[int] = []
	finished_ids.assign(_active_notifications.keys())
	_finish_active_notifications(finished_ids, reason)
	_clearing_notifications = false


## 获取当前通知。
## [br]
## @api public
## [br]
## @return 当前通知副本。
## [br]
## @schema return: Dictionary，当前通知记录；无当前通知时为空。字段同 notification_queued 的 notification。
func get_active_notification() -> Dictionary:
	var active_id: int = _get_oldest_active_id()
	if active_id == 0:
		return {}
	var active: _ActiveNotification = _active_notifications[active_id]
	return active._record.duplicate(true)


## 按开始展示的顺序获取所有活动通知的副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 活动通知记录数组。
## [br]
## @schema return: Array，元素为通知记录 Dictionary，字段同 notification_queued 的 notification。
func get_active_notifications() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for notification_id: int in _active_notifications:
		var active: _ActiveNotification = _active_notifications[notification_id]
		result.append(active._record.duplicate(true))
	return result


## 暂停当前通知倒计时。
## [br]
## @api public
func pause_active() -> void:
	var active_id: int = _get_oldest_active_id()
	if active_id != 0:
		var active: _ActiveNotification = _active_notifications[active_id]
		active._paused = true


## 恢复当前通知倒计时。
## [br]
## @api public
func resume_active() -> void:
	var active_id: int = _get_oldest_active_id()
	if active_id != 0:
		var active: _ActiveNotification = _active_notifications[active_id]
		active._paused = false


## 当前通知是否处于暂停状态。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_active_paused() -> bool:
	var active_id: int = _get_oldest_active_id()
	if active_id == 0:
		return false
	var active: _ActiveNotification = _active_notifications[active_id]
	return active._paused


## 触发当前通知的一个动作。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @return 当前通知包含该动作时返回 true。
func invoke_active_action(action_id: StringName) -> bool:
	var active_id: int = _get_oldest_active_id()
	return invoke_notification_action(active_id, action_id)


## 按 ID 触发活动通知的动作。动作要求结束时，只结束发出该动作的通知。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param notification_id: push_notification() 返回的通知 ID。
## [br]
## @param action_id: 动作标识。
## [br]
## @return 该 ID 处于活动状态且包含该动作时返回 true。
func invoke_notification_action(notification_id: int, action_id: StringName) -> bool:
	if action_id == &"" or not _active_notifications.has(notification_id):
		return false

	var active: _ActiveNotification = _active_notifications[notification_id]
	var actions: Array = GFVariantData.get_option_array(active._record, "actions")
	for action_value: Variant in actions:
		var action: Dictionary = GFVariantData.as_dictionary(action_value)
		if GFVariantData.get_option_string_name(action, "id") == action_id:
			notification_action_invoked.emit(
				active._record.duplicate(true),
				action_id
			)
			if GFVariantData.get_option_bool(action, "dismiss"):
				var _dismissed: bool = dismiss_notification(
					notification_id,
					"action:%s" % action_id
				)
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
	var active_id: int = _get_oldest_active_id()
	var remaining_seconds: float = 0.0
	var paused: bool = false
	if active_id != 0:
		var active: _ActiveNotification = _active_notifications[active_id]
		remaining_seconds = active._remaining_seconds
		paused = active._paused
	return {
		"active": get_active_notification(),
		"queue": get_queue(),
		"queue_size": _queue.size(),
		"active_remaining_seconds": remaining_seconds,
		"active_paused": paused,
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
		"key": GFVariantData.get_option_string(
			options,
			"key",
			message
		),
		"dedupe_key": GFVariantData.get_option_string(options, "key"),
		"title": title,
		"message": message,
		"level": level,
		"priority": clampi(
			GFVariantData.get_option_int(
				options,
				"priority",
				Priority.NORMAL
			),
			Priority.LOW,
			Priority.CRITICAL
		),
		"sticky": GFVariantData.get_option_bool(
			options,
			"sticky",
			false
		),
		"duration_seconds": maxf(
			GFVariantData.get_option_float(
				options,
				"duration_seconds",
				default_duration_seconds
			),
			0.0
		),
		"created_at_unix": Time.get_unix_time_from_system(),
		"actions": _normalize_actions(
			GFVariantData.get_option_value(
				options,
				"actions",
				[]
			)
		),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	_next_notification_id += 1
	return notification_record


## 获取最早开始展示且仍活动的通知 ID，供单条通知入口使用。空集合返回 0。
## [br]
## @api private
func _get_oldest_active_id() -> int:
	for notification_id: int in _active_notifications:
		return notification_id
	return 0


## 填满活动名额后执行等待容量限制。回调产生的请求由当前循环继续处理。
## [br]
## @api private
func _process_queue() -> void:
	if _queue_update_depth > 0 or _clearing_notifications:
		return

	_queue_update_depth += 1
	while not _queue.is_empty():
		if _active_notifications.size() < max_active_notifications:
			_start_next_notification()
		elif _queue.size() > maxi(max_queue_size, 0):
			var dropped: Dictionary = GFVariantData.as_dictionary(_queue.pop_back())
			notification_finished.emit(
				dropped.duplicate(true),
				"dropped"
			)
		else:
			break
	_queue_update_depth -= 1


## 激活队首记录并启动独立倒计时。开始回调可能已经结束这条通知。
## [br]
## @api private
func _start_next_notification() -> void:
	var record: Dictionary = GFVariantData.as_dictionary(_queue.pop_front())
	var notification_id: int = GFVariantData.get_option_int(record, "id")
	var active: _ActiveNotification = _ActiveNotification.new()
	active._record = record
	active._remaining_seconds = GFVariantData.get_option_float(
		record,
		"duration_seconds",
		default_duration_seconds
	)
	_active_notifications[notification_id] = active
	notification_started.emit(record.duplicate(true))
	if active._remaining_seconds <= 0.0 and not GFVariantData.get_option_bool(record, "sticky"):
		var _dismissed: bool = dismiss_notification(notification_id, "timeout")


## 先撤下本批结束的全部活动记录，再发送完成信号并补位，避免回调重复结束或误关补入的记录。
## [br]
## @api private
func _finish_active_notifications(notification_ids: Array[int], reason: String) -> void:
	var finished: Array[Dictionary] = []
	for notification_id: int in notification_ids:
		var active: _ActiveNotification = _active_notifications[notification_id]
		finished.append(active._record)
		var _removed: bool = _active_notifications.erase(notification_id)

	_queue_update_depth += 1
	for record: Dictionary in finished:
		notification_finished.emit(
			record.duplicate(true),
			reason
		)
	_queue_update_depth -= 1
	_process_queue()


## 在活动通知和等待队列中查找首个去重匹配项；没有匹配时返回 0。
## [br]
## @api private
func _find_duplicate_notification_id(message: String, options: Dictionary) -> int:
	var key: String = GFVariantData.get_option_string(options, "key")
	for notification_id: int in _active_notifications:
		var active: _ActiveNotification = _active_notifications[notification_id]
		if _matches_notification(
			active._record,
			key,
			message
		):
			return notification_id

	for notification_record: Dictionary in _queue:
		if _matches_notification(
			notification_record,
			key,
			message
		):
			return GFVariantData.get_option_int(notification_record, "id")
	return 0


## 显式 key 只匹配相同去重 key；未提供 key 时仅匹配同样没有显式 key 且消息相同的记录。
## [br]
## @api private
func _matches_notification(
	notification_record: Dictionary,
	key: String,
	message: String
) -> bool:
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
	_queue.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority: int = GFVariantData.get_option_int(
				left,
				"priority",
				Priority.NORMAL
			)
			var right_priority: int = GFVariantData.get_option_int(
				right,
				"priority",
				Priority.NORMAL
			)
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
				result.append(
					{
						"id": simple_action_id,
						"label": "",
						"dismiss": false,
						"metadata": {},
					}
				)
			continue
		if not (action_variant is Dictionary):
			continue

		var source: Dictionary = GFVariantData.as_dictionary(action_variant)
		var dictionary_action_id: StringName = GFVariantData.get_option_string_name(source, "id")
		if dictionary_action_id == &"":
			continue
		result.append(
			{
				"id": dictionary_action_id,
				"label": GFVariantData.get_option_string(source, "label"),
				"dismiss": GFVariantData.get_option_bool(source, "dismiss"),
				"metadata": GFVariantData.get_option_dictionary(source, "metadata"),
			}
		)
	return result


# --- 内部类 ---

## 保存单条活动通知的计时状态，公开快照只复制通知记录。
## [br]
## @api private
class _ActiveNotification extends RefCounted:


	# --- 私有变量 ---

	## 从等待队列移入的通知记录，在活动期间由通知工具持有。
	## [br]
	## @api private
	var _record: Dictionary = {}

	## 这条通知余下的展示时间，由通知工具推进。
	## [br]
	## @api private
	var _remaining_seconds: float = 0.0

	## 暂停当前记录的倒计时，直到通过单条通知入口恢复。
	## [br]
	## @api private
	var _paused: bool = false
