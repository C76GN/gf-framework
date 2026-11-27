## 测试 GFNotificationUtility 的通用通知队列行为。
extends GutTest


# --- 内部类 ---

class _ActionLabel extends RefCounted:
	var on_format: Callable

	func _to_string() -> String:
		var _result: Variant = on_format.call()
		return "Cancel"


# --- 测试方法 ---

## 清空和释放都先结束活动通知，再交付回调，避免嵌套 dismiss 重复完成。
func test_clear_notification_finishes_active_only_once_under_reentry() -> void:
	for disposing: bool in [false, true]:
		var notifications: GFNotificationUtility = GFNotificationUtility.new()
		var finished_ids: Array[int] = []
		var _connected: int = notifications.notification_finished.connect(
			func(notification_entry: Dictionary, _reason: String) -> void:
				finished_ids.append(GFVariantData.get_option_int(notification_entry, "id"))
				if finished_ids.size() == 1:
					notifications.dismiss_active()
		)
		var notification_id: int = notifications.push_notification("Saved", "System")
		if disposing:
			notifications.dispose()
		else:
			notifications.clear_notifications()
		assert_eq(
			finished_ids.count(notification_id),
			1
		)
		assert_true(notifications.get_active_notification().is_empty())
		assert_true(notifications.get_queue().is_empty())
		for connection: Dictionary in notifications.notification_finished.get_connections():
			var callback: Callable = connection["callable"]
			notifications.notification_finished.disconnect(callback)


## 验证通知入队后会立即成为当前通知。
func test_notification_push_starts_active_notification() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var notification_id: int = notifications.push_notification("Saved", "System")
	var active: Dictionary = notifications.get_active_notification()

	assert_gt(
		notification_id,
		0,
		"推送通知应返回有效 id。"
	)
	assert_eq(
		GFVariantData.get_option_string(active, "message"),
		"Saved",
		"首条通知应立即成为当前通知。"
	)
	assert_eq(
		GFVariantData.get_option_string(active, "title"),
		"System",
		"通知标题应保留。"
	)


## 验证通知按时长结束并启动下一条。
func test_notification_tick_advances_queue() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_23: Variant = notifications.push_notification(
		"First",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 0.1 }
	)
	var _push_notification_result_24: Variant = notifications.push_notification(
		"Second",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 1.0 }
	)

	notifications.tick(0.2)
	var active: Dictionary = notifications.get_active_notification()

	assert_eq(
		GFVariantData.get_option_string(active, "message"),
		"Second",
		"当前通知超时后应启动下一条。"
	)
	assert_eq(
		notifications.get_queue().size(),
		0,
		"第二条启动后等待队列应为空。"
	)


## 验证重复通知会被抑制。
func test_notification_suppresses_duplicates() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var first_id: int = notifications.push_notification(
		"Duplicated",
		"",
		GFNotificationUtility.Level.INFO,
		{ "key": "same" }
	)
	var second_id: int = notifications.push_notification(
		"Duplicated again",
		"",
		GFNotificationUtility.Level.INFO,
		{ "key": "same" }
	)

	assert_eq(
		second_id,
		first_id,
		"同 key 通知应返回已有通知 id。"
	)
	assert_eq(
		notifications.get_queue().size(),
		0,
		"重复通知不应进入等待队列。"
	)


## 更新展示内容时保留活动计时、等待顺序和通知身份。
func test_update_preserves_queue_order_identity_and_active_timer() -> void:
	var notices: GFNotificationUtility = GFNotificationUtility.new()
	var active_id: int = notices.push_notification(
		"Reading",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 5.0 }
	)
	var queued_id: int = notices.push_notification(
		"Waiting",
		"",
		GFNotificationUtility.Level.INFO,
		{
			"key": "export",
			"sticky": true,
			"actions": ["cancel"],
		}
	)
	var next_id: int = notices.push_notification("Later")
	var updates: Array[int] = []
	var observe: Callable = func(changed_id: int) -> void:
		updates.append(changed_id)
		var record: Dictionary = notices.get_notification(changed_id)
		record["message"] = "observer copy"
	var _updated: int = notices.notification_updated.connect(observe)
	notices.tick(2.0)
	notices.pause_active()
	assert_eq(
		notices.update_notification(
			active_id,
			{ &"message": "Read" }
		),
		OK
	)
	assert_eq(
		notices.push_notification("Read"),
		active_id
	)
	assert_eq(
		notices.update_notification(
			queued_id,
			{ "message": "Writing", "title": "Export" }
		),
		OK
	)
	assert_eq(
		_notification_ids(notices.get_queue()),
		[queued_id, next_id]
	)
	var queued_record: Dictionary = notices.get_queue()[0]
	assert_true(queued_record.get("message") is String)
	assert_eq(
		GFVariantData.get_option_string(queued_record, "message"),
		"Writing"
	)
	assert_eq(
		notices.push_notification(
			"Duplicate",
			"",
			GFNotificationUtility.Level.INFO,
			{ "key": "export" }
		),
		queued_id
	)
	assert_eq(
		notices.update_notification(
			queued_id,
			{ "message": "Writing" }
		),
		OK
	)
	assert_eq(
		updates,
		[active_id, queued_id]
	)
	notices.tick(8.0)
	assert_true(notices.is_active_paused())
	notices.resume_active()
	notices.tick(3.0)
	var promoted_record: Dictionary = notices.get_active_notification()
	assert_true(promoted_record.get("id") is int)
	assert_eq(
		GFVariantData.get_option_int(promoted_record, "id"),
		queued_id
	)
	assert_true(notices.invoke_active_action(&"cancel"))
	notices.tick(8.0)
	assert_eq(
		notices.update_notification(
			queued_id,
			{ "actions": [], "level": GFNotificationUtility.Level.SUCCESS }
		),
		OK
	)
	assert_false(notices.invoke_active_action(&"cancel"))
	assert_eq(
		notices.update_notification(
			active_id,
			{ "message": "Late" }
		),
		ERR_DOES_NOT_EXIST
	)
	assert_eq(
		updates,
		[
			active_id,
			queued_id,
			queued_id,
		]
	)
	notices.notification_updated.disconnect(observe)


func test_update_validates_atomically_and_can_be_dismissed_by_observer() -> void:
	var notices: GFNotificationUtility = GFNotificationUtility.new()
	var id: int = notices.push_notification("Initial")
	var original: Dictionary = notices.get_active_notification()
	var dismiss: Callable = func(changed_id: int) -> void:
		assert_true(notices.dismiss_notification(changed_id))
	var _updated: int = notices.notification_updated.connect(dismiss)
	for patch: Dictionary in [
		{ "title": "partial", "priority": 1 },
		{ "level": 20 },
		{
			"actions": [2],
		},
		{ "message": "" },
	]:
		assert_eq(
			notices.update_notification(id, patch),
			ERR_INVALID_PARAMETER
		)
		assert_eq(
			notices.get_active_notification(),
			original
		)
	assert_eq(
		notices.update_notification(
			id,
			{ "message": "Done" }
		),
		OK
	)
	assert_true(notices.get_active_notifications().is_empty())
	assert_eq(
		notices.update_notification(id, {}),
		ERR_DOES_NOT_EXIST
	)
	notices.notification_updated.disconnect(dismiss)


func test_observers_read_current_state_after_another_observer_updates_or_closes() -> void:
	var notices: GFNotificationUtility = GFNotificationUtility.new()
	var id: int = notices.push_notification("Start")
	var observed: Array[String] = []
	var on_change: Callable = func(changed_id: int) -> void:
		match notices.get_notification(changed_id)["message"]:
			"Writing":
				assert_eq(
					notices.update_notification(
						changed_id,
						{ "message": "Done" }
					),
					OK
				)
			"Closing":
				assert_true(notices.dismiss_notification(changed_id))
	var observe: Callable = func(changed_id: int) -> void:
		observed.append(
			GFVariantData.get_option_string(
				notices.get_notification(changed_id),
				"message",
				"retired"
			)
		)
	var _changed: int = notices.notification_updated.connect(on_change)
	var _observed: int = notices.notification_updated.connect(observe)
	assert_eq(
		notices.update_notification(
			id,
			{ "message": "Writing" }
		),
		OK
	)
	assert_eq(
		notices.update_notification(
			id,
			{ "message": "Closing" }
		),
		OK
	)
	assert_eq(
		observed,
		[
			"Done",
			"Done",
			"retired",
		]
	)
	notices.notification_updated.disconnect(on_change)
	notices.notification_updated.disconnect(observe)


func test_action_normalization_commits_only_to_the_current_notification() -> void:
	var notices: GFNotificationUtility = GFNotificationUtility.new()
	var id: int = notices.push_notification("Export")
	var action_label: _ActionLabel = _ActionLabel.new()
	var patch: Dictionary = {
		"actions": [
			{ "id": "cancel", "label": action_label },
		],
	}
	action_label.on_format = notices.update_notification.bind(
		id,
		{ "title": "Writing" }
	)
	assert_eq(
		notices.update_notification(id, patch),
		OK
	)
	var updated_record: Dictionary = notices.get_notification(id)
	assert_true(updated_record.get("title") is String)
	assert_eq(
		GFVariantData.get_option_string(updated_record, "title"),
		"Writing"
	)
	action_label.on_format = notices.dismiss_notification.bind(id)
	assert_eq(
		notices.update_notification(id, patch),
		ERR_DOES_NOT_EXIST
	)
	assert_true(notices.get_notification(id).is_empty())


## 验证显式 key 不会因为正文相同而误去重。
func test_notification_different_keys_allow_same_message() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var first_id: int = notifications.push_notification(
		"Saved",
		"",
		GFNotificationUtility.Level.INFO,
		{ "key": "settings" }
	)
	var second_id: int = notifications.push_notification(
		"Saved",
		"",
		GFNotificationUtility.Level.INFO,
		{ "key": "profile" }
	)

	assert_ne(
		second_id,
		first_id,
		"不同 key 的相同正文通知不应被去重。"
	)
	assert_eq(
		notifications.get_queue().size(),
		1,
		"第二条通知应进入等待队列。"
	)


func test_notification_options_accept_string_name_keys_and_copy_metadata() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var source_metadata: Dictionary = {
		"nested": { "value": 1, },
	}

	var _push_notification_result_63: Variant = notifications.push_notification(
		"Saved",
		"",
		GFNotificationUtility.Level.INFO,
		{
			&"key": &"save",
			&"priority": "3",
			&"sticky": "on",
			&"metadata": source_metadata,
			&"actions": [
				{
					"id": &"open",
					"metadata": { "screen": "save", },
				},
				&"retry",
			],
		}
	)
	var active: Dictionary = notifications.get_active_notification()
	var actions: Array = GFVariantData.as_array(active["actions"])
	var active_metadata: Dictionary = GFVariantData.as_dictionary(active["metadata"])
	var active_nested_metadata: Dictionary = GFVariantData.as_dictionary(active_metadata["nested"])
	var source_nested_metadata: Dictionary = GFVariantData.as_dictionary(source_metadata["nested"])
	var first_action: Dictionary = GFVariantData.as_dictionary(actions[0])
	var first_action_metadata: Dictionary = GFVariantData.as_dictionary(first_action["metadata"])
	var second_action: Dictionary = GFVariantData.as_dictionary(actions[1])
	active_nested_metadata["value"] = 2

	assert_eq(
		GFVariantData.get_option_string(active, "key"),
		"save",
		"StringName key 选项应被识别。"
	)
	assert_eq(
		GFVariantData.get_option_int(active, "priority"),
		GFNotificationUtility.Priority.CRITICAL,
		"字符串数字 priority 应按 int 读取并限制范围。"
	)
	assert_true(
		GFVariantData.get_option_bool(active, "sticky"),
		"字符串 on 应按 true 读取。"
	)
	assert_eq(
		GFVariantData.get_option_int(source_nested_metadata, "value"),
		1,
		"通知 metadata 应复制保存。"
	)
	assert_eq(
		GFVariantData.get_option_string(first_action_metadata, "screen"),
		"save",
		"动作 metadata 应复制保存。"
	)
	assert_eq(
		GFVariantData.get_option_string(first_action, "label"),
		"",
		"未显式设置的动作 label 应保持为空。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(second_action, "id"),
		&"retry",
		"StringName 动作应保留动作 ID。"
	)
	assert_eq(
		GFVariantData.get_option_string(second_action, "label"),
		"",
		"StringName 动作不应派生展示文案。"
	)


## 验证 0 队列容量只保留当前通知。
func test_notification_zero_queue_size_drops_waiting_notifications() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_queue_size = 0
	watch_signals(notifications)

	var _push_notification_result_104: Variant = notifications.push_notification(
		"Active",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 1.0 }
	)
	var _push_notification_result_105: Variant = notifications.push_notification(
		"Dropped",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 1.0 }
	)

	assert_eq(
		GFVariantData.get_option_string(
			notifications.get_active_notification(),
			"message"
		),
		"Active",
		"0 队列容量仍应允许当前通知展示。"
	)
	assert_eq(
		notifications.get_queue().size(),
		0,
		"0 队列容量不应保留等待通知。"
	)


func test_notification_priority_orders_waiting_queue() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_113: Variant = notifications.push_notification(
		"Active",
		"",
		GFNotificationUtility.Level.INFO,
		{ "priority": GFNotificationUtility.Priority.LOW, "sticky": true, }
	)
	var _push_notification_result_117: Variant = notifications.push_notification(
		"Normal",
		"",
		GFNotificationUtility.Level.INFO,
		{ "priority": GFNotificationUtility.Priority.NORMAL, }
	)
	var _push_notification_result_120: Variant = notifications.push_notification(
		"Critical",
		"",
		GFNotificationUtility.Level.ERROR,
		{ "priority": GFNotificationUtility.Priority.CRITICAL, }
	)

	var queue: Array[Dictionary] = notifications.get_queue()
	var critical_notification: Dictionary = queue[0]
	var normal_notification: Dictionary = queue[1]

	assert_eq(
		queue.size(),
		2,
		"当前通知之外的通知应留在等待队列。"
	)
	assert_eq(
		GFVariantData.get_option_string(critical_notification, "message"),
		"Critical",
		"高优先级等待通知应排在队首。"
	)
	assert_eq(
		GFVariantData.get_option_string(normal_notification, "message"),
		"Normal",
		"低优先级等待通知应排在后面。"
	)


func test_sticky_and_paused_notifications_do_not_timeout() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_133: Variant = notifications.push_notification(
		"Sticky",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 0.0, "sticky": true, }
	)
	notifications.tick(10.0)

	assert_eq(
		GFVariantData.get_option_string(
			notifications.get_active_notification(),
			"message"
		),
		"Sticky",
		"sticky 通知不应因倒计时结束自动关闭。"
	)

	notifications.dismiss_active()
	var _push_notification_result_142: Variant = notifications.push_notification(
		"Pausable",
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": 0.1, }
	)
	notifications.pause_active()
	notifications.tick(1.0)

	assert_true(
		notifications.is_active_paused(),
		"pause_active 后应报告暂停。"
	)
	assert_eq(
		GFVariantData.get_option_string(
			notifications.get_active_notification(),
			"message"
		),
		"Pausable",
		"暂停状态下通知不应超时。"
	)

	notifications.resume_active()
	notifications.tick(1.0)

	assert_true(
		notifications.get_active_notification().is_empty(),
		"恢复后通知应继续倒计时并超时。"
	)


func test_notification_actions_emit_signal_and_can_dismiss() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	watch_signals(notifications)
	var invoked: Array = []
	var _connect_result_161: Variant = notifications.notification_action_invoked.connect(
		func(notification_payload: Dictionary, action_id: StringName) -> void:
			invoked.append([GFVariantData.get_option_string(notification_payload, "message"), action_id])
	)
	var _push_notification_result_164: Variant = notifications.push_notification(
		"Actionable",
		"",
		GFNotificationUtility.Level.INFO,
		{
			"actions": [
				{
					"id": &"confirm",
					"label": "Confirm",
					"dismiss": true,
				},
			],
			"duration_seconds": 10.0,
		}
	)

	var handled: bool = notifications.invoke_active_action(&"confirm")

	assert_true(handled, "已注册动作应能被触发。")
	assert_eq(
		invoked,
		[
			["Actionable", &"confirm"],
		],
		"触发动作时应发出动作信号。"
	)
	assert_true(
		notifications.get_active_notification().is_empty(),
		"dismiss 动作触发后应关闭当前通知。"
	)
	assert_signal_emitted(
		notifications,
		"notification_finished",
		"被丢弃通知应发出 finished 信号。"
	)


func test_concurrent_notifications_expire_independently_and_refill_by_priority() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_active_notifications = 2
	var first_id: int = _push_timed_notification(
		notifications,
		"Long",
		2.0
	)
	var second_id: int = _push_timed_notification(
		notifications,
		"Short",
		0.5
	)
	var waiting_id: int = _push_timed_notification(
		notifications,
		"Waiting",
		0.25
	)
	var high_priority_id: int = _push_timed_notification(
		notifications,
		"Important",
		0.25,
		GFNotificationUtility.Priority.HIGH
	)

	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, second_id]
	)
	assert_eq(
		_notification_ids(notifications.get_queue()),
		[high_priority_id, waiting_id]
	)

	notifications.pause_active()
	notifications.tick(0.5)
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, high_priority_id]
	)
	assert_true(notifications.is_active_paused())

	notifications.tick(0.25)
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, waiting_id]
	)
	notifications.tick(0.25)
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id]
	)
	assert_eq(
		GFVariantData.get_option_float(
			notifications.get_debug_snapshot(),
			"active_remaining_seconds"
		),
		2.0
	)


func test_active_limit_changes_fill_slots_and_let_existing_records_finish() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	assert_eq(notifications.max_active_notifications, 1)
	notifications.max_active_notifications = 0
	assert_eq(notifications.max_active_notifications, 1)
	notifications.max_active_notifications = 100
	assert_eq(notifications.max_active_notifications, 32)
	notifications.max_active_notifications = 1

	var first_id: int = notifications.push_notification("First")
	var second_id: int = notifications.push_notification("Second")
	notifications.max_active_notifications = 2
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, second_id]
	)

	notifications.max_active_notifications = 1
	var waiting_id: int = notifications.push_notification("Waiting")
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, second_id]
	)
	assert_false(notifications.dismiss_notification(waiting_id))
	assert_true(notifications.dismiss_notification(second_id))
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id]
	)

	notifications.dismiss_active()
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[waiting_id]
	)


func test_concurrent_records_are_copied_and_deduplicate_across_all_active_slots() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_active_notifications = 2
	var first_id: int = notifications.push_notification("First")
	var second_id: int = notifications.push_notification(
		"Second",
		"",
		GFNotificationUtility.Level.INFO,
		{
			"key": "progress",
			"metadata": { "progress": 1, },
		}
	)
	var duplicate_id: int = notifications.push_notification(
		"Duplicate",
		"",
		GFNotificationUtility.Level.INFO,
		{ "key": "progress" }
	)
	assert_eq(duplicate_id, second_id)
	assert_true(notifications.get_queue().is_empty())

	var snapshot: Array[Dictionary] = notifications.get_active_notifications()
	var metadata: Dictionary = GFVariantData.as_dictionary(snapshot[1]["metadata"])
	metadata["progress"] = 99
	snapshot[0]["id"] = -1
	snapshot.clear()

	var fresh: Array[Dictionary] = notifications.get_active_notifications()
	assert_eq(
		_notification_ids(fresh),
		[first_id, second_id]
	)
	var fresh_metadata: Dictionary = GFVariantData.as_dictionary(fresh[1]["metadata"])
	assert_eq(
		GFVariantData.get_option_int(fresh_metadata, "progress"),
		1
	)


func test_action_closes_only_its_notification_under_reentry() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_active_notifications = 2
	var first_id: int = notifications.push_notification("First")
	var action_id: int = notifications.push_notification(
		"Actionable",
		"",
		GFNotificationUtility.Level.INFO,
		{
			"actions": [
				{ "id": &"ack", "dismiss": true, },
			],
		}
	)
	var waiting_id: int = notifications.push_notification("Waiting")
	var invoked_ids: Array[int] = []
	var on_action: Callable = func(record: Dictionary, _action: StringName) -> void:
		var notification_id: int = GFVariantData.get_option_int(record, "id")
		invoked_ids.append(notification_id)
		var _dismissed: bool = notifications.dismiss_notification(notification_id, "handled")
	var _connected: int = notifications.notification_action_invoked.connect(on_action)

	assert_false(notifications.invoke_active_action(&"ack"))
	assert_true(notifications.invoke_notification_action(action_id, &"ack"))
	assert_eq(
		invoked_ids,
		[action_id]
	)
	assert_false(notifications.dismiss_notification(action_id))
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[first_id, waiting_id]
	)
	notifications.notification_action_invoked.disconnect(on_action)


func test_same_tick_expirations_detach_before_callbacks_and_refill() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_active_notifications = 2
	var first_id: int = _push_timed_notification(
		notifications,
		"Short one",
		0.5
	)
	var second_id: int = _push_timed_notification(
		notifications,
		"Short two",
		0.5
	)
	var waiting_id: int = _push_timed_notification(
		notifications,
		"Waiting",
		0.25
	)
	var finished_ids: Array[int] = []
	var completion_reasons: Array[String] = []
	var active_counts: Array[int] = []
	var on_finished: Callable = func(record: Dictionary, reason: String) -> void:
		finished_ids.append(GFVariantData.get_option_int(record, "id"))
		completion_reasons.append(reason)
		active_counts.append(notifications.get_active_notifications().size())
		if finished_ids.size() == 1:
			var _dismissed: bool = notifications.dismiss_notification(second_id)
	var _connected: int = notifications.notification_finished.connect(on_finished)

	notifications.tick(0.5)
	assert_eq(
		finished_ids,
		[first_id, second_id]
	)
	assert_eq(
		completion_reasons,
		["timeout", "timeout"]
	)
	assert_eq(
		active_counts,
		[0, 0]
	)
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[waiting_id]
	)
	notifications.notification_finished.disconnect(on_finished)


func test_zero_waiting_capacity_fills_slots_after_started_callbacks() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_active_notifications = 2
	notifications.max_queue_size = 0
	var reentrant_ids: Array[int] = []
	var on_started: Callable = func(record: Dictionary) -> void:
		if GFVariantData.get_option_string(record, "message") != "Instant":
			return
		var notification_id: int = GFVariantData.get_option_int(record, "id")
		var _dismissed: bool = notifications.dismiss_notification(notification_id, "handled")
		reentrant_ids.append(notifications.push_notification("Replacement"))
	var _connected: int = notifications.notification_started.connect(on_started)

	var anchor_id: int = notifications.push_notification("Anchor")
	var instant_id: int = _push_timed_notification(
		notifications,
		"Instant",
		0.0
	)
	assert_eq(
		reentrant_ids.size(),
		1
	)
	assert_false(notifications.dismiss_notification(instant_id))
	assert_eq(
		_notification_ids(notifications.get_active_notifications()),
		[anchor_id, reentrant_ids[0]]
	)
	assert_true(notifications.get_queue().is_empty())
	notifications.notification_started.disconnect(on_started)


func test_concurrent_clear_and_dispose_finish_only_detached_active_records() -> void:
	for disposing: bool in [false, true]:
		var notifications: GFNotificationUtility = GFNotificationUtility.new()
		notifications.max_active_notifications = 2
		var first_id: int = notifications.push_notification("First")
		var second_id: int = notifications.push_notification("Second")
		var _waiting_id: int = notifications.push_notification("Waiting")
		var finished_ids: Array[int] = []
		var pushed_ids: Array[int] = []
		var completion_reasons: Array[String] = []
		var on_finished: Callable = func(record: Dictionary, reason: String) -> void:
			finished_ids.append(GFVariantData.get_option_int(record, "id"))
			completion_reasons.append(reason)
			notifications.dismiss_active()
			pushed_ids.append(notifications.push_notification("Reentrant"))
		var _connected: int = notifications.notification_finished.connect(on_finished)

		if disposing:
			notifications.dispose()
		else:
			notifications.clear_notifications()

		var expected_reason: String = "disposed" if disposing else "cleared"
		assert_eq(
			finished_ids,
			[first_id, second_id]
		)
		assert_eq(
			completion_reasons,
			[expected_reason, expected_reason]
		)
		assert_eq(
			pushed_ids,
			[0, 0]
		)
		assert_true(notifications.get_active_notifications().is_empty())
		assert_true(notifications.get_queue().is_empty())
		notifications.notification_finished.disconnect(on_finished)


# --- 私有/辅助方法 ---

func _push_timed_notification(
	notifications: GFNotificationUtility,
	message: String,
	seconds: float,
	priority: GFNotificationUtility.Priority = GFNotificationUtility.Priority.NORMAL
) -> int:
	return notifications.push_notification(
		message,
		"",
		GFNotificationUtility.Level.INFO,
		{ "duration_seconds": seconds, "priority": priority, }
	)


func _notification_ids(records: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for record: Dictionary in records:
		result.append(GFVariantData.get_option_int(record, "id"))
	return result
