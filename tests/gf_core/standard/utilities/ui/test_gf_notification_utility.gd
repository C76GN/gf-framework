## 测试 GFNotificationUtility 的通用通知队列行为。
extends GutTest



# --- 测试方法 ---

## 验证通知入队后会立即成为当前通知。
func test_notification_push_starts_active_notification() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var notification_id: int = notifications.push_notification("Saved", "System")
	var active: Dictionary = notifications.get_active_notification()

	assert_gt(notification_id, 0, "推送通知应返回有效 id。")
	assert_eq(GFVariantData.get_option_string(active, "message"), "Saved", "首条通知应立即成为当前通知。")
	assert_eq(GFVariantData.get_option_string(active, "title"), "System", "通知标题应保留。")


## 验证通知按时长结束并启动下一条。
func test_notification_tick_advances_queue() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_23: Variant = notifications.push_notification("First", "", GFNotificationUtility.Level.INFO, { "duration_seconds": 0.1 })
	var _push_notification_result_24: Variant = notifications.push_notification("Second", "", GFNotificationUtility.Level.INFO, { "duration_seconds": 1.0 })

	notifications.tick(0.2)
	var active: Dictionary = notifications.get_active_notification()

	assert_eq(GFVariantData.get_option_string(active, "message"), "Second", "当前通知超时后应启动下一条。")
	assert_eq(notifications.get_queue().size(), 0, "第二条启动后等待队列应为空。")


## 验证重复通知会被抑制。
func test_notification_suppresses_duplicates() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var first_id: int = notifications.push_notification("Duplicated", "", GFNotificationUtility.Level.INFO, { "key": "same" })
	var second_id: int = notifications.push_notification("Duplicated again", "", GFNotificationUtility.Level.INFO, { "key": "same" })

	assert_eq(second_id, first_id, "同 key 通知应返回已有通知 id。")
	assert_eq(notifications.get_queue().size(), 0, "重复通知不应进入等待队列。")


## 验证显式 key 不会因为正文相同而误去重。
func test_notification_different_keys_allow_same_message() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()

	var first_id: int = notifications.push_notification("Saved", "", GFNotificationUtility.Level.INFO, { "key": "settings" })
	var second_id: int = notifications.push_notification("Saved", "", GFNotificationUtility.Level.INFO, { "key": "profile" })

	assert_ne(second_id, first_id, "不同 key 的相同正文通知不应被去重。")
	assert_eq(notifications.get_queue().size(), 1, "第二条通知应进入等待队列。")


func test_notification_options_accept_string_name_keys_and_copy_metadata() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var source_metadata: Dictionary = {
		"nested": {
			"value": 1,
		},
	}

	var _push_notification_result_63: Variant = notifications.push_notification("Saved", "", GFNotificationUtility.Level.INFO, {
		&"key": &"save",
		&"priority": "3",
		&"sticky": "on",
		&"metadata": source_metadata,
		&"actions": [
			{
				"id": &"open",
				"metadata": {
					"screen": "save",
				},
			},
			&"retry",
		],
	})
	var active: Dictionary = notifications.get_active_notification()
	var actions: Array = GFVariantData.as_array(active["actions"])
	var active_metadata: Dictionary = GFVariantData.as_dictionary(active["metadata"])
	var active_nested_metadata: Dictionary = GFVariantData.as_dictionary(active_metadata["nested"])
	var source_nested_metadata: Dictionary = GFVariantData.as_dictionary(source_metadata["nested"])
	var first_action: Dictionary = GFVariantData.as_dictionary(actions[0])
	var first_action_metadata: Dictionary = GFVariantData.as_dictionary(first_action["metadata"])
	var second_action: Dictionary = GFVariantData.as_dictionary(actions[1])
	active_nested_metadata["value"] = 2

	assert_eq(GFVariantData.get_option_string(active, "key"), "save", "StringName key 选项应被识别。")
	assert_eq(GFVariantData.get_option_int(active, "priority"), GFNotificationUtility.Priority.CRITICAL, "字符串数字 priority 应按 int 读取并限制范围。")
	assert_true(GFVariantData.get_option_bool(active, "sticky"), "字符串 on 应按 true 读取。")
	assert_eq(GFVariantData.get_option_int(source_nested_metadata, "value"), 1, "通知 metadata 应复制保存。")
	assert_eq(GFVariantData.get_option_string(first_action_metadata, "screen"), "save", "动作 metadata 应复制保存。")
	assert_eq(GFVariantData.get_option_string(first_action, "label"), "", "未显式设置的动作 label 应保持为空。")
	assert_eq(GFVariantData.get_option_string_name(second_action, "id"), &"retry", "StringName 动作应保留动作 ID。")
	assert_eq(GFVariantData.get_option_string(second_action, "label"), "", "StringName 动作不应派生展示文案。")


## 验证 0 队列容量只保留当前通知。
func test_notification_zero_queue_size_drops_waiting_notifications() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	notifications.max_queue_size = 0
	watch_signals(notifications)

	var _push_notification_result_104: Variant = notifications.push_notification("Active", "", GFNotificationUtility.Level.INFO, { "duration_seconds": 1.0 })
	var _push_notification_result_105: Variant = notifications.push_notification("Dropped", "", GFNotificationUtility.Level.INFO, { "duration_seconds": 1.0 })

	assert_eq(GFVariantData.get_option_string(notifications.get_active_notification(), "message"), "Active", "0 队列容量仍应允许当前通知展示。")
	assert_eq(notifications.get_queue().size(), 0, "0 队列容量不应保留等待通知。")


func test_notification_priority_orders_waiting_queue() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_113: Variant = notifications.push_notification("Active", "", GFNotificationUtility.Level.INFO, {
		"priority": GFNotificationUtility.Priority.LOW,
		"sticky": true,
	})
	var _push_notification_result_117: Variant = notifications.push_notification("Normal", "", GFNotificationUtility.Level.INFO, {
		"priority": GFNotificationUtility.Priority.NORMAL,
	})
	var _push_notification_result_120: Variant = notifications.push_notification("Critical", "", GFNotificationUtility.Level.ERROR, {
		"priority": GFNotificationUtility.Priority.CRITICAL,
	})

	var queue: Array[Dictionary] = notifications.get_queue()
	var critical_notification: Dictionary = queue[0]
	var normal_notification: Dictionary = queue[1]

	assert_eq(queue.size(), 2, "当前通知之外的通知应留在等待队列。")
	assert_eq(GFVariantData.get_option_string(critical_notification, "message"), "Critical", "高优先级等待通知应排在队首。")
	assert_eq(GFVariantData.get_option_string(normal_notification, "message"), "Normal", "低优先级等待通知应排在后面。")


func test_sticky_and_paused_notifications_do_not_timeout() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	var _push_notification_result_133: Variant = notifications.push_notification("Sticky", "", GFNotificationUtility.Level.INFO, {
		"duration_seconds": 0.0,
		"sticky": true,
	})
	notifications.tick(10.0)

	assert_eq(GFVariantData.get_option_string(notifications.get_active_notification(), "message"), "Sticky", "sticky 通知不应因倒计时结束自动关闭。")

	notifications.dismiss_active()
	var _push_notification_result_142: Variant = notifications.push_notification("Pausable", "", GFNotificationUtility.Level.INFO, {
		"duration_seconds": 0.1,
	})
	notifications.pause_active()
	notifications.tick(1.0)

	assert_true(notifications.is_active_paused(), "pause_active 后应报告暂停。")
	assert_eq(GFVariantData.get_option_string(notifications.get_active_notification(), "message"), "Pausable", "暂停状态下通知不应超时。")

	notifications.resume_active()
	notifications.tick(1.0)

	assert_true(notifications.get_active_notification().is_empty(), "恢复后通知应继续倒计时并超时。")


func test_notification_actions_emit_signal_and_can_dismiss() -> void:
	var notifications: GFNotificationUtility = GFNotificationUtility.new()
	watch_signals(notifications)
	var invoked: Array = []
	var _connect_result_161: Variant = notifications.notification_action_invoked.connect(func(notification_payload: Dictionary, action_id: StringName) -> void:
		invoked.append([GFVariantData.get_option_string(notification_payload, "message"), action_id])
	)
	var _push_notification_result_164: Variant = notifications.push_notification("Actionable", "", GFNotificationUtility.Level.INFO, {
		"actions": [
			{
				"id": &"confirm",
				"label": "Confirm",
				"dismiss": true,
			},
		],
		"duration_seconds": 10.0,
	})

	var handled: bool = notifications.invoke_active_action(&"confirm")

	assert_true(handled, "已注册动作应能被触发。")
	assert_eq(invoked, [["Actionable", &"confirm"]], "触发动作时应发出动作信号。")
	assert_true(notifications.get_active_notification().is_empty(), "dismiss 动作触发后应关闭当前通知。")
	assert_signal_emitted(notifications, "notification_finished", "被丢弃通知应发出 finished 信号。")
