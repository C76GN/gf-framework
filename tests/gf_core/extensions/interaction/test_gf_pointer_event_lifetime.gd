# 验证指针信号回调后，旧事件不能改投新绑定或已失效的接收实例。
extends GutTest


# --- 测试用例 ---

func test_receiver_path_change_cancels_release_and_old_click() -> void:
	var fixture: PointerFixture = _make_fixture()
	var released_contexts: Array[GFInteractionContext] = []
	var clicked_contexts: Array[GFInteractionContext] = []
	var callback: Callable = func(context: GFInteractionContext, _event: InputEventMouseButton) -> void:
		released_contexts.append(context)
		fixture.pointer.receiver_path = NodePath("../../ReceiverB")
	var _released_connected: int = fixture.pointer.pointer_released.connect(callback)
	var _clicked_connected: int = fixture.pointer.pointer_clicked.connect(
		func(context: GFInteractionContext, _event: InputEventMouseButton) -> void:
			clicked_contexts.append(context)
	)
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	assert_eq(
		released_contexts.size(),
		1
	)
	assert_same(
		released_contexts[0].target,
		fixture.receiver_a
	)
	assert_eq(
		fixture.receiver_a.events.size(),
		0,
		"旧事件不继续发送给已解除绑定的 A。"
	)
	assert_eq(
		fixture.receiver_b.events.size(),
		0,
		"旧 release 不应改投 B。"
	)
	assert_eq(
		clicked_contexts.size(),
		0,
		"接收器改绑取消旧按压派生的 click。"
	)
	fixture.pointer.pointer_released.disconnect(callback)
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	_assert_events(
		fixture.receiver_b,
		[&"released", &"clicked"]
	)


func test_rebinding_or_disable_enable_does_not_revive_old_release() -> void:
	for change: StringName in [
		&"collision",
		&"collision_roundtrip",
		&"path_roundtrip",
		&"disable_enable",
	]:
		var fixture: PointerFixture = _make_fixture()
		var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
			match change:
				&"collision":
					fixture.pointer.bind_collision_object(fixture.other_body)
				&"collision_roundtrip":
					fixture.pointer.bind_collision_object(fixture.other_body)
					fixture.pointer.bind_collision_object(fixture.body)
				&"path_roundtrip":
					fixture.pointer.receiver_path = NodePath("../../ReceiverB")
					fixture.pointer.receiver_path = NodePath("../../ReceiverA")
				&"disable_enable":
					fixture.pointer.enabled = false
					fixture.pointer.enabled = true
		var _connected: int = fixture.pointer.pointer_released.connect(callback)
		fixture.emit_button(MOUSE_BUTTON_LEFT, true)
		fixture.emit_button(MOUSE_BUTTON_LEFT, false)
		assert_eq(
			fixture.receiver_a.events.size(),
			0,
			str(change)
		)
		assert_eq(
			fixture.receiver_b.events.size(),
			0,
			str(change)
		)


func test_automatic_button_events_cancel_when_callback_changes_receiver() -> void:
	for event_name: StringName in [
		&"pressed",
		&"clicked",
		&"wheel",
	]:
		var fixture: PointerFixture = _make_fixture()
		fixture.pointer.send_on_released = false
		fixture.pointer.send_on_pressed = event_name == &"pressed"
		fixture.pointer.send_on_wheel = event_name == &"wheel"
		var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
			fixture.pointer.receiver_path = NodePath("../../ReceiverB")
		var _connected: Error = fixture.pointer.connect(
			StringName("pointer_" + String(event_name)),
			callback
		)
		if event_name == &"wheel":
			fixture.emit_button(MOUSE_BUTTON_WHEEL_UP, true)
		else:
			fixture.emit_button(MOUSE_BUTTON_LEFT, true)
			if event_name == &"clicked":
				fixture.emit_button(MOUSE_BUTTON_LEFT, false)
		assert_eq(
			fixture.receiver_a.events.size(),
			0,
			str(event_name)
		)
		assert_eq(
			fixture.receiver_b.events.size(),
			0,
			str(event_name)
		)


func test_automatic_hover_events_cancel_when_callback_changes_receiver() -> void:
	for entering: bool in [true, false]:
		var fixture: PointerFixture = _make_fixture()
		fixture.pointer.send_on_hover = true
		var callback: Callable = func(_context: GFInteractionContext) -> void:
			fixture.pointer.receiver_path = NodePath("../../ReceiverB")
		var signal_name: StringName = &"pointer_entered" if entering else &"pointer_exited"
		var _connected: Error = fixture.pointer.connect(signal_name, callback)
		if entering:
			fixture.body.mouse_entered.emit()
		else:
			fixture.body.mouse_exited.emit()
		assert_eq(
			fixture.receiver_a.events.size(),
			0
		)
		assert_eq(
			fixture.receiver_b.events.size(),
			0
		)


func test_same_path_replacement_cancels_automatic_release_and_old_click() -> void:
	var fixture: PointerFixture = _make_fixture()
	var clicked: Array[GFInteractionContext] = []
	var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
		fixture.receiver_a.name = "RetiredReceiverA"
		fixture.receiver_b.name = "ReceiverA"
	var _released_connected: int = fixture.pointer.pointer_released.connect(callback)
	var _clicked_connected: int = fixture.pointer.pointer_clicked.connect(
		func(context: GFInteractionContext, _event: InputEventMouseButton) -> void:
			clicked.append(context)
	)
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	assert_eq(
		fixture.receiver_a.events.size(),
		0
	)
	assert_eq(
		fixture.receiver_b.events.size(),
		0
	)
	assert_eq(
		clicked.size(),
		0
	)


func test_receiver_replaced_between_press_and_release_does_not_inherit_click() -> void:
	var fixture: PointerFixture = _make_fixture()
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.receiver_a.name = "RetiredReceiverA"
	fixture.receiver_b.name = "ReceiverA"
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	_assert_events(
		fixture.receiver_b,
		[&"released"]
	)


func test_queued_receiver_or_pointer_cannot_receive_remaining_automatic_release() -> void:
	for delete_pointer: bool in [false, true]:
		var fixture: PointerFixture = _make_fixture()
		var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
			if delete_pointer:
				fixture.pointer.queue_free()
			else:
				fixture.receiver_a.queue_free()
		var _connected: int = fixture.pointer.pointer_released.connect(callback)
		fixture.emit_button(MOUSE_BUTTON_LEFT, true)
		fixture.emit_button(MOUSE_BUTTON_LEFT, false)
		assert_eq(
			fixture.receiver_a.events.size(),
			0
		)


func test_new_press_from_release_callback_is_retained_after_old_release_cancels() -> void:
	var fixture: PointerFixture = _make_fixture()
	var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
		fixture.pointer.receiver_path = NodePath("../../ReceiverB")
		fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	var _connected: int = fixture.pointer.pointer_released.connect(callback, CONNECT_ONE_SHOT)
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	assert_eq(
		fixture.receiver_b.events.size(),
		0
	)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	_assert_events(
		fixture.receiver_b,
		[&"released", &"clicked"]
	)


func test_preconfigured_explicit_handoff_sends_one_new_interaction() -> void:
	var fixture: PointerFixture = _make_fixture()
	fixture.pointer.send_on_released = false
	var callback: Callable = func(_context: GFInteractionContext, _event: InputEventMouseButton) -> void:
		fixture.pointer.receiver_path = NodePath("../../ReceiverB")
		var report: Dictionary = fixture.pointer.send_pointer_interaction(&"released")
		assert_true(GFVariantData.get_option_bool(report, "ok"))
	var _connected: int = fixture.pointer.pointer_released.connect(callback)
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	assert_eq(
		fixture.receiver_a.events.size(),
		0
	)
	_assert_events(
		fixture.receiver_b,
		[&"released"]
	)


func test_unchanged_binding_sends_release_and_click_once() -> void:
	var fixture: PointerFixture = _make_fixture()
	fixture.emit_button(MOUSE_BUTTON_LEFT, true)
	fixture.emit_button(MOUSE_BUTTON_LEFT, false)
	_assert_events(
		fixture.receiver_a,
		[&"released", &"clicked"]
	)
	assert_eq(
		fixture.receiver_b.events.size(),
		0
	)


# --- 私有/辅助方法 ---

## 每个用例拥有独立场景和两个记录接收器，避免共享注册或全局输入状态。
func _make_fixture() -> PointerFixture:
	var fixture: PointerFixture = PointerFixture.new()
	add_child_autofree(fixture)
	return fixture


## 用同一元素类型比较完整事件序列，区分重复发送与漏发。
func _assert_events(receiver: EventReceiver, expected: Array[StringName]) -> void:
	assert_eq(receiver.events, expected)


# --- 内部类 ---

## 仅记录通过公开接收协议提交的事件，测试不读取 Pointer 的私有状态。
class EventReceiver extends Node:
	var events: Array[StringName] = []


	func receive_interaction(context: GFInteractionContext, id: StringName = &"") -> Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(context.payload)
		events.append(GFVariantData.get_option_string_name(data, "pointer_event"))
		return { "ok": true, "interaction_id": id }


## 通过 CollisionObject3D 的真实信号入口驱动事件，节点均随 fixture 释放。
class PointerFixture extends Node3D:
	var body: StaticBody3D = StaticBody3D.new()
	var other_body: StaticBody3D = StaticBody3D.new()
	var receiver_a: EventReceiver = EventReceiver.new()
	var receiver_b: EventReceiver = EventReceiver.new()
	var pointer: GFPointerInteraction3D = GFPointerInteraction3D.new()


	func _init() -> void:
		receiver_a.name = "ReceiverA"
		receiver_b.name = "ReceiverB"
		add_child(body)
		add_child(other_body)
		add_child(receiver_a)
		add_child(receiver_b)
		pointer.receiver_path = NodePath("../../ReceiverA")
		pointer.send_on_released = true
		body.add_child(pointer)


	func emit_button(button: MouseButton, pressed: bool) -> void:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		body.input_event.emit(
			null,
			event,
			Vector3.ZERO,
			Vector3.UP,
			0
		)
