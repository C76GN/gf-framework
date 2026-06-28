## 测试通用交互 Sensor/Receiver 节点。
extends GutTest


# --- 常量 ---

const GF_MESSAGE_DISPATCH_SUPPORT = preload("res://addons/gf/standard/common/gf_message_dispatch_support.gd")


# --- 辅助类 ---

class RecordingReceiver extends GFInteractionReceiver:
	var received_context: GFInteractionContext = null
	var validate_count: int = 0

	func _init() -> void:
		validation_callback = Callable(self, "_validate_interaction")

	func _validate_interaction(context: GFInteractionContext, _report: Dictionary) -> Dictionary:
		received_context = context
		validate_count += 1
		return {
			"ok": true,
			"metadata": {
				"validated": true,
			},
		}


class BusinessInteractionReceiver extends Node:
	var received_context: GFInteractionContext = null
	var received_id: StringName = &""

	func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> Dictionary:
		received_context = context
		received_id = interaction_id
		return {
			"ok": true,
			"interaction_id": interaction_id,
			"receiver": self,
			"reason": "handled",
			"message": "",
			"metadata": {
				"business": true,
			},
		}


class SideEffectInteractionReceiver extends Node:
	var received_context: GFInteractionContext = null
	var received_id: StringName = &""

	func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> void:
		received_context = context
		received_id = interaction_id


class PlainInteractionTarget extends Node:
	pass


class RecordingDispatchHost extends RefCounted:
	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_id = id_override
		return {
			"ok": true,
			"receiver": receiver,
			"interaction_id": id_override,
			"metadata": {},
		}


class RecordingDispatchNode extends Node:
	var received_receiver: Object = null
	var received_payload: Variant = null
	var received_id: StringName = &""

	func send_to(receiver: Object, payload_override: Variant = null, id_override: StringName = &"") -> Dictionary:
		received_receiver = receiver
		received_payload = payload_override
		received_id = id_override
		return {
			"ok": true,
			"receiver": receiver,
			"interaction_id": id_override,
			"metadata": {},
		}


class InvalidDispatchNode extends Node:
	var called: bool = false

	func send_to(_receiver: Object) -> Dictionary:
		called = true
		return {
			"ok": false,
			"metadata": {},
		}


# --- 测试方法 ---

func test_sensor_send_to_receiver_builds_context_and_report() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver)
	sensor.interaction_id = &"use"
	sensor.group_name = &"nearby"
	sensor.payload = { "amount": 2 }

	var report: Dictionary = sensor.send_to(receiver)
	var received_payload: Dictionary = GFVariantData.as_dictionary(receiver.received_context.payload)
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效接收器应接受交互。")
	assert_same(receiver.received_context.sender, sensor, "默认 sender 应为 Sensor 自身。")
	assert_same(receiver.received_context.target, receiver, "上下文 target 应指向接收器。")
	assert_eq(GFVariantData.get_option_int(received_payload, "amount"), 2, "payload 应写入上下文。")
	assert_eq(receiver.received_context.group_name, &"nearby", "group_name 应写入上下文。")
	assert_true(GFVariantData.get_option_bool(report_metadata, "validated"), "接收器校验结果应合并 metadata。")


func test_receiver_filters_interaction_ids() -> void:
	var receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	add_child_autofree(receiver)
	receiver.accepted_interaction_ids = [&"open"]

	var rejected: Dictionary = receiver.receive_interaction(GFInteractionContext.new(), &"use")
	var accepted: Dictionary = receiver.receive_interaction(GFInteractionContext.new(), &"open")

	assert_false(GFVariantData.get_option_bool(rejected, "ok"), "不在 accepted_interaction_ids 内的交互应被拒绝。")
	assert_eq(GFVariantData.get_option_string(rejected, "reason"), "unaccepted_id")
	assert_true(GFVariantData.get_option_bool(accepted, "ok"), "允许的交互 ID 应通过基础过滤。")


func test_receiver_path_forwards_interaction_to_business_receiver() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: BusinessInteractionReceiver = BusinessInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	bridge.name = "InteractionAreaBridge"
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "通过本地过滤的交互应转发给业务接收器。")
	assert_same(business_receiver.received_context, context, "业务接收器应收到同一个交互上下文。")
	assert_same(context.target, business_receiver, "转发时上下文 target 应更新为业务接收器。")
	assert_eq(business_receiver.received_id, &"use", "交互 ID 应透传给业务接收器。")
	assert_same(_object_option(report, "receiver"), business_receiver, "最终报告应来自业务接收器。")
	assert_true(GFVariantData.get_option_bool(report_metadata, "business"), "业务接收器返回的报告应成为最终报告。")
	assert_signal_emitted(bridge, "interaction_received", "业务接收成功后桥接节点应发出接收信号。")


func test_receiver_path_accepts_side_effect_business_receiver() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: SideEffectInteractionReceiver = SideEffectInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "副作用式业务接收器不返回报告时仍应沿用桥接接收报告。")
	assert_same(business_receiver.received_context, context, "业务接收器应收到同一个交互上下文。")
	assert_same(context.target, business_receiver, "转发时上下文 target 应更新为业务接收器。")
	assert_eq(business_receiver.received_id, &"use", "交互 ID 应透传给业务接收器。")
	assert_same(_object_option(report, "receiver"), business_receiver, "默认接收报告应指向业务接收器。")
	assert_signal_emitted(bridge, "interaction_received", "业务接收器处理后桥接节点应发出接收信号。")


func test_receiver_path_can_only_retarget_context() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_target: PlainInteractionTarget = PlainInteractionTarget.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_target)
	business_target.name = "BusinessTarget"
	bridge.receiver_path = NodePath("../BusinessTarget")
	bridge.accepted_interaction_ids = [&"use"]
	watch_signals(bridge)

	var context: GFInteractionContext = GFInteractionContext.new(null, bridge, { "item": "door" })
	var report: Dictionary = bridge.receive_interaction(context, &"use")

	assert_true(bridge.can_receive_interaction(&"use"), "receiver_path 指向普通业务节点时仍应允许 Receiver 接收交互。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "普通业务节点可只作为交互 target，不必实现 receive_interaction()。")
	assert_same(context.target, business_target, "转发时上下文 target 应更新为业务 target。")
	assert_same(_object_option(report, "receiver"), business_target, "默认接收报告应指向业务 target。")
	assert_signal_emitted(bridge, "interaction_received", "Receiver retarget 后仍应发出接收信号。")


func test_receiver_path_does_not_forward_rejected_interaction() -> void:
	var root: Node = Node.new()
	var bridge: GFInteractionReceiver = GFInteractionReceiver.new()
	var business_receiver: BusinessInteractionReceiver = BusinessInteractionReceiver.new()
	add_child_autofree(root)
	root.add_child(bridge)
	root.add_child(business_receiver)
	business_receiver.name = "BusinessReceiver"
	bridge.receiver_path = NodePath("../BusinessReceiver")
	bridge.accepted_interaction_ids = [&"open"]

	var report: Dictionary = bridge.receive_interaction(GFInteractionContext.new(null, bridge), &"use")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "未通过本地 ID 过滤的交互不应转发。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "unaccepted_id")
	assert_null(business_receiver.received_context, "被本地拒绝时业务接收器不应收到上下文。")


func test_sensor_rejects_invalid_receiver() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_receiver: Node = Node.new()
	add_child_autofree(sensor)
	add_child_autofree(invalid_receiver)

	var report: Dictionary = sensor.send_to(invalid_receiver)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺少 receive_interaction() 的对象应被拒绝。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "invalid_receiver")


func test_sensor_broadcast_to_group_sends_to_receivers() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var receiver_a: RecordingReceiver = RecordingReceiver.new()
	var receiver_b: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(receiver_a)
	add_child_autofree(receiver_b)
	sensor.group_name = &"targets"
	receiver_a.add_to_group("targets")
	receiver_b.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 2, "广播应发送给分组中的所有接收器。")
	assert_eq(receiver_a.validate_count + receiver_b.validate_count, 2, "每个接收器都应收到一次交互。")


func test_sensor_broadcast_to_group_max_count_counts_accepted_receivers() -> void:
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var rejected_receiver: GFInteractionReceiver = GFInteractionReceiver.new()
	var accepted_receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(sensor)
	add_child_autofree(rejected_receiver)
	add_child_autofree(accepted_receiver)
	sensor.group_name = &"targets"
	rejected_receiver.enabled = false
	rejected_receiver.add_to_group("targets")
	accepted_receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group(&"", 1)

	assert_eq(accepted_receiver.validate_count, 1, "rejected 目标不应耗尽 max_count 的 accepted 配额。")
	assert_true(reports.size() >= 1, "广播应返回可诊断报告。")
	assert_true(GFVariantData.get_option_bool(reports[reports.size() - 1], "ok"), "最后一个报告应来自 accepted 目标。")


func test_sensor_broadcast_to_group_uses_sender_send_to_override() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: RecordingDispatchNode = RecordingDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../Sender")
	receiver.add_to_group("targets")
	watch_signals(sensor)

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "分组广播应通过可覆写发送者发送一次交互。")
	assert_same(sender.received_receiver, receiver, "sender_path 指向的发送者实现 send_to() 时应接管分组广播。")
	assert_true(sender.received_payload == null, "未覆盖 payload 时应透传 null，让业务发送者使用自身默认值。")
	assert_eq(sender.received_id, &"", "未覆盖交互 ID 时应透传空值，让业务发送者使用自身默认值。")
	assert_signal_emitted(sensor, "interaction_sent", "业务发送者接管分组广播时 Sensor 仍应发出 interaction_sent。")
	assert_signal_emitted(sensor, "interaction_accepted", "业务发送者返回成功报告时 Sensor 仍应发出 interaction_accepted。")


func test_sensor_ignores_sender_send_to_override_with_invalid_signature() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var invalid_sender: InvalidDispatchNode = InvalidDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(invalid_sender)
	root.add_child(receiver)
	invalid_sender.name = "InvalidSender"
	sensor.group_name = &"targets"
	sensor.sender_path = NodePath("../InvalidSender")
	receiver.add_to_group("targets")

	var reports: Array[Dictionary] = sensor.broadcast_to_group()

	assert_eq(reports.size(), 1, "无效 sender override 应回退到 Sensor 标准发送。")
	assert_false(invalid_sender.called, "签名不匹配的 send_to 不应被调用。")
	assert_same(receiver.received_context.sender, invalid_sender, "上下文 sender 仍应来自 sender_path。")


func test_sensor_collision_candidates_resolve_receiver_ancestors() -> void:
	var host: RecordingDispatchHost = RecordingDispatchHost.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var collider_child: Node = Node.new()
	add_child_autofree(receiver)
	receiver.add_child(collider_child)

	var reports: Array[Dictionary] = []
	reports.assign(GF_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		host,
		[collider_child],
		0,
		{ "value": 3 },
		&"hit",
		&"receive_interaction"
	))

	assert_eq(reports.size(), 1, "碰撞候选应能向上解析到交互接收器。")
	assert_true(GFVariantData.get_option_bool(reports[0], "ok"), "解析到的接收器应交给发送宿主。")
	assert_same(host.received_receiver, receiver, "交互上下文 target 应使用解析后的接收器。")
	assert_eq(GFVariantData.as_dictionary(host.received_payload), { "value": 3 }, "payload 覆盖值应透传给发送宿主。")
	assert_eq(host.received_id, &"hit", "交互 ID 覆盖值应透传给发送宿主。")


func test_sensor_collision_dispatch_uses_sender_send_to_override() -> void:
	var root: Node = Node.new()
	var sensor: GFInteractionSensor = GFInteractionSensor.new()
	var sender: RecordingDispatchNode = RecordingDispatchNode.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	add_child_autofree(root)
	root.add_child(sensor)
	root.add_child(sender)
	root.add_child(receiver)
	sender.name = "Sender"
	sensor.sender_path = NodePath("../Sender")
	watch_signals(sensor)

	var reports: Array[Dictionary] = []
	reports.assign(GF_MESSAGE_DISPATCH_SUPPORT._send_to_collision_candidates(
		sensor._resolve_collision_dispatch_host(),
		[receiver],
		0,
		{ "value": 3 },
		&"use",
		&"receive_interaction",
		Callable(sensor, "_emit_collision_dispatch_result")
	))

	assert_eq(reports.size(), 1, "碰撞广播应通过可覆写发送者发送一次交互。")
	assert_same(sender.received_receiver, receiver, "sender_path 指向的发送者实现 send_to() 时应接管碰撞分发。")
	assert_eq(GFVariantData.as_dictionary(sender.received_payload), { "value": 3 }, "payload 覆盖值应透传给业务发送者。")
	assert_eq(sender.received_id, &"use", "交互 ID 覆盖值应透传给业务发送者。")
	assert_signal_emitted(sensor, "interaction_sent", "业务发送者接管碰撞分发时 Sensor 仍应发出 interaction_sent。")


func test_pointer_interaction_3d_sends_click_context_to_receiver() -> void:
	var root: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(root)
	root.add_child(body)
	root.add_child(receiver)
	body.add_child(pointer)
	pointer.receiver_path = NodePath("../../RecordingReceiver")
	receiver.name = "RecordingReceiver"
	pointer.interaction_id = &"inspect"
	pointer.payload = { "kind": "object" }
	pointer.bind_collision_object(body)

	var press: InputEventMouseButton = _make_mouse_button(MOUSE_BUTTON_LEFT, true)
	var release: InputEventMouseButton = _make_mouse_button(MOUSE_BUTTON_LEFT, false)
	pointer._on_collision_input_event(null, press, Vector3(1.0, 2.0, 3.0), Vector3.UP, 0)
	pointer._on_collision_input_event(null, release, Vector3(1.0, 2.0, 3.0), Vector3.UP, 0)

	assert_not_null(receiver.received_context, "点击应发送交互上下文。")
	assert_same(receiver.received_context.target, receiver, "上下文 target 应为解析到的接收器。")
	var received_payload: Dictionary = GFVariantData.as_dictionary(receiver.received_context.payload)
	assert_eq(GFVariantData.get_option_string(received_payload, "kind"), "object", "基础 payload 应保留。")
	assert_eq(GFVariantData.get_option_string_name(received_payload, "pointer_event"), &"clicked", "点击事件应写入 payload。")
	assert_eq(GFVariantData.get_option_vector3(received_payload, "pointer_position"), Vector3(1.0, 2.0, 3.0), "点击位置应写入 payload。")
	assert_false(received_payload.has("pointer_camera"), "pointer payload 不应携带 Camera3D 原始对象。")
	assert_false(received_payload.has("pointer_input_event"), "pointer payload 不应携带 InputEvent 原始对象。")
	assert_eq(GFVariantData.get_option_string(received_payload, "pointer_input_event_class"), "InputEventMouseButton", "pointer payload 应保留事件类型快照。")


func test_pointer_interaction_3d_emits_hover_without_sending_by_default() -> void:
	var root: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	var receiver: RecordingReceiver = RecordingReceiver.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	var entered: Array[GFInteractionContext] = []
	add_child_autofree(root)
	root.add_child(body)
	root.add_child(receiver)
	body.add_child(pointer)
	pointer.receiver_path = NodePath("../../RecordingReceiver")
	receiver.name = "RecordingReceiver"
	var _connect_result_370: Variant = pointer.pointer_entered.connect(func(context: GFInteractionContext) -> void:
		entered.append(context)
	)
	pointer.bind_collision_object(body)

	pointer._on_collision_mouse_entered()

	assert_eq(entered.size(), 1, "hover 进入应发出本地信号。")
	assert_null(receiver.received_context, "默认不应把 hover 自动发送给接收器。")


func test_pointer_interaction_3d_rebinding_resets_hover_press_state() -> void:
	var first_body: StaticBody3D = StaticBody3D.new()
	var second_body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(first_body)
	add_child_autofree(second_body)
	first_body.add_child(pointer)
	pointer.bind_collision_object(first_body)
	watch_signals(pointer)

	pointer._on_collision_mouse_entered()
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer.bind_collision_object(second_body)
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false), Vector3.ZERO, Vector3.UP, 0)

	assert_false(pointer._is_hovered, "重新绑定时应清理 hover 状态。")
	assert_eq(pointer._pressed_button, 0, "重新绑定时应清理 pressed button。")
	assert_signal_not_emitted(pointer, "pointer_clicked", "旧对象上的 press 不应在新对象 release 时形成点击。")


func test_pointer_interaction_3d_restores_input_ray_pickable_on_unbind() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	body.add_child(pointer)
	body.input_ray_pickable = false

	pointer.bind_collision_object(body)
	var pickable_during_bind: bool = body.input_ray_pickable
	pointer.bind_collision_object(null)

	assert_true(pickable_during_bind, "绑定期间应确保 input_ray_pickable。")
	assert_false(body.input_ray_pickable, "解绑后应恢复外部 CollisionObject3D 原始 pickable 设置。")


func test_pointer_interaction_3d_disabling_resets_active_state() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()
	add_child_autofree(body)
	body.add_child(pointer)
	pointer.bind_collision_object(body)
	watch_signals(pointer)

	pointer._on_collision_mouse_entered()
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, true), Vector3.ZERO, Vector3.UP, 0)
	pointer.enabled = false
	pointer._on_collision_input_event(null, _make_mouse_button(MOUSE_BUTTON_LEFT, false), Vector3.ZERO, Vector3.UP, 0)

	assert_false(pointer._is_hovered, "禁用时应清理 hover 状态。")
	assert_eq(pointer._pressed_button, 0, "禁用时应清理 pressed button。")
	assert_signal_not_emitted(pointer, "pointer_clicked", "禁用后 release 不应继承旧 press 形成点击。")


# --- 私有/辅助方法 ---

func _make_mouse_button(button_index: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	return event


func _object_option(options: Dictionary, key: Variant) -> Object:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is Object:
		var object: Object = value
		return object
	return null
