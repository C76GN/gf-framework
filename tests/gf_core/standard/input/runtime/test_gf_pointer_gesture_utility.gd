## 测试 GFPointerGestureUtility 的通用指针手势摘要。
extends GutTest


# --- 常量 ---

const _GF_POINTER_GESTURE_UTILITY_SCRIPT = preload("res://addons/gf/standard/input/runtime/gf_pointer_gesture_utility.gd")


# --- 测试方法 ---

func test_pointer_gesture_tracks_single_pointer_pan() -> void:
	var utility: Object = _make_utility()
	watch_signals(utility)

	var press: InputEventScreenTouch = InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = Vector2(2.0, 3.0)
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(7.0, 5.0)

	assert_true(_handle_input_event(utility, press), "触摸按下应被识别。")
	assert_true(_handle_input_event(utility, drag), "触摸拖动应被识别。")

	var snapshot: Dictionary = _get_gesture_snapshot(utility)
	assert_eq(GFVariantData.get_option_int(snapshot, "pointer_count"), 1, "单指手势应报告一个活动指针。")
	assert_eq(GFVariantData.get_option_vector2(snapshot, "center"), Vector2(7.0, 5.0), "中心应等于单指位置。")
	assert_eq(GFVariantData.get_option_vector2(snapshot, "pan_delta"), Vector2(5.0, 2.0), "单指移动应输出 pan delta。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "scale"), 1.0, 0.001, "单指移动不应产生缩放。")
	assert_signal_emitted(utility, "gesture_updated", "手势更新应发出信号。")


func test_pointer_gesture_tracks_two_pointer_scale_and_rotation() -> void:
	var utility: Object = _make_utility()
	var first_touch: InputEventScreenTouch = _make_touch_event(1, true, Vector2.ZERO)
	var second_touch: InputEventScreenTouch = _make_touch_event(2, true, Vector2(10.0, 0.0))
	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(0.0, 20.0)

	var _first_handled: bool = _handle_input_event(utility, first_touch)
	var _second_handled: bool = _handle_input_event(utility, second_touch)
	assert_true(_handle_input_event(utility, drag), "第二个触点移动应更新双指手势。")

	var snapshot: Dictionary = _get_gesture_snapshot(utility)

	assert_eq(GFVariantData.get_option_int(snapshot, "pointer_count"), 2, "双指手势应报告两个活动指针。")
	assert_eq(GFVariantData.get_option_vector2(snapshot, "center"), Vector2(0.0, 10.0), "中心应取两个触点中点。")
	assert_eq(GFVariantData.get_option_vector2(snapshot, "previous_center"), Vector2(5.0, 0.0), "上一中心应来自移动前两个触点。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "scale"), 2.0, 0.001, "距离 10 -> 20 应输出 2 倍缩放。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "rotation_delta"), PI / 2.0, 0.001, "水平到垂直应输出 90 度旋转。")


func test_pointer_gesture_tracks_mouse_wheel_zoom() -> void:
	var utility: Object = _make_utility()
	utility.set("mouse_wheel_zoom_factor", 1.25)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(9.0, 4.0)

	assert_true(_handle_input_event(utility, wheel), "鼠标滚轮应被识别为缩放手势。")

	var snapshot: Dictionary = _get_gesture_snapshot(utility)
	assert_eq(GFVariantData.get_option_string_name(snapshot, "source"), &"mouse_wheel", "快照应标记鼠标滚轮来源。")
	assert_eq(GFVariantData.get_option_vector2(snapshot, "center"), Vector2(9.0, 4.0), "缩放中心应使用事件位置。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "scale"), 1.25, 0.001, "滚轮向上应输出放大因子。")


func test_pointer_gesture_ends_when_last_pointer_releases() -> void:
	var utility: Object = _make_utility()
	watch_signals(utility)
	var press: InputEventScreenTouch = _make_touch_event(4, true, Vector2.ONE)
	var release: InputEventScreenTouch = _make_touch_event(4, false, Vector2.ONE)

	var _press_handled: bool = _handle_input_event(utility, press)
	assert_true(_handle_input_event(utility, release), "释放活动触点应被识别。")

	var snapshot: Dictionary = _get_gesture_snapshot(utility)
	assert_false(GFVariantData.get_option_bool(snapshot, "active"), "最后一个触点释放后手势应结束。")
	assert_eq(_get_active_pointer_count(utility), 0, "活动指针应清空。")
	assert_signal_emitted(utility, "gesture_ended", "手势结束应发出信号。")


# --- 私有/辅助方法 ---

func _make_utility() -> Object:
	var instance: Object = _GF_POINTER_GESTURE_UTILITY_SCRIPT.new()
	return instance


func _handle_input_event(utility: Object, event: InputEvent) -> bool:
	return GFVariantData.to_bool(utility.call("handle_input_event", event))


func _get_gesture_snapshot(utility: Object) -> Dictionary:
	var value: Variant = utility.call("get_gesture_snapshot")
	return GFVariantData.as_dictionary(value).duplicate(true)


func _get_active_pointer_count(utility: Object) -> int:
	return GFVariantData.to_int(utility.call("get_active_pointer_count"))


func _make_touch_event(pointer_id: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = pointer_id
	event.pressed = pressed
	event.position = position
	return event
