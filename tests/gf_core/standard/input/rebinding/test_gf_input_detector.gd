## 测试 GFInputDetector 的值类型过滤和倒计时检测。
extends GutTest


# --- 私有变量 ---

var _detector: GFInputDetector
var _received_event: InputEvent
var _received_count: int


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_received_event = null
	_received_count = 0
	_detector = GFInputDetector.new()
	get_tree().root.add_child(_detector)
	var _connect_result_17: Variant = _detector.input_detected.connect(func(input_event: InputEvent) -> void:
		_received_event = input_event
		_received_count += 1
	)


func after_each() -> void:
	if is_instance_valid(_detector):
		_detector.queue_free()
	_detector = null
	await get_tree().process_frame


# --- 测试方法 ---

## 验证轴检测会过滤非轴输入。
func test_axis_detection_ignores_bool_events() -> void:
	_detector.detect_axis_1d()

	_detector._input(_make_key_event(KEY_SPACE, true))
	assert_null(_received_event, "轴检测不应接受按键事件。")

	_detector._input(_make_joy_motion_event(JOY_AXIS_LEFT_X, 0.5))
	assert_not_null(_received_event, "轴检测应接受超过阈值的手柄轴事件。")
	assert_true(_received_event is InputEventJoypadMotion, "检测结果应保留原生轴事件类型。")


## 验证三维轴检测也接受手柄轴事件。
func test_axis_3d_detection_accepts_joy_motion() -> void:
	_detector.detect_axis_3d()

	_detector._input(_make_joy_motion_event(JOY_AXIS_RIGHT_Y, 0.6))

	assert_not_null(_received_event, "三维轴检测应接受超过阈值的手柄轴事件。")
	assert_true(_received_event is InputEventJoypadMotion, "检测结果应保留原生轴事件类型。")


## 验证倒计时结束前不会接收候选输入。
func test_countdown_delays_input_acceptance() -> void:
	_detector.countdown_seconds = 0.1
	_detector.begin_detection()

	_detector._input(_make_key_event(KEY_SPACE, true))
	assert_null(_received_event, "倒计时内输入不应被接收。")
	assert_true(_detector.is_detecting(), "倒计时内检测仍应进行。")
	assert_false(_detector.is_accepting_input(), "倒计时内不应处于接收状态。")

	_detector._process(0.11)
	_detector._input(_make_key_event(KEY_SPACE, true))

	assert_not_null(_received_event, "倒计时结束后应接收输入。")


## 验证无倒计时且无需清理时会立即进入接收状态。
func test_detection_state_reports_accepting_phase() -> void:
	_detector.countdown_seconds = 0.0
	_detector.wait_for_clear_before_detection = false

	_detector.begin_detection()

	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.DETECTING, "检测器应立即进入接收阶段。")
	assert_true(_detector.is_accepting_input(), "接收阶段应允许候选输入。")


## 验证 timeout 会覆盖倒计时阶段，而不是只在接收输入阶段生效。
func test_timeout_covers_countdown_phase() -> void:
	_detector.countdown_seconds = 1.0
	_detector.timeout_seconds = 0.1

	_detector.begin_detection()
	_detector._process(0.11)

	assert_eq(_received_count, 1, "倒计时超时应发出一次检测结束信号。")
	assert_null(_received_event, "超时结果应为空事件。")
	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.IDLE, "超时后检测器应回到空闲状态。")


## 验证触屏输入在等待释放时会由后续 release 事件完成检测。
func test_touch_detection_waits_for_matching_release_event() -> void:
	_detector.wait_for_clear_after_detection = true
	_detector.begin_detection([GFInputDetector.DeviceType.TOUCH])

	_detector._input(_make_touch_event(3, true))

	assert_eq(_received_count, 0, "等待释放时不应立刻发出检测结果。")
	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.POST_CLEAR, "触屏按下后应进入后清理阶段。")

	_detector._input(_make_touch_event(3, false))

	assert_eq(_received_count, 1, "匹配触点释放后应发出检测结果。")
	assert_true(_received_event is InputEventScreenTouch, "检测结果应保留触屏事件类型。")
	if _received_event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = _received_event
		assert_true(touch_event.pressed, "返回的检测结果应是最初捕获的按下事件。")


## 验证重复开始检测会取消上一轮等待者。
func test_begin_detection_cancels_previous_detection() -> void:
	_detector.begin_detection()

	_detector.begin_detection()

	assert_eq(_received_count, 1, "重复 begin 应先结束上一轮检测。")
	assert_null(_received_event, "被替换的检测应以空事件结束。")
	assert_true(_detector.is_detecting(), "新检测应继续进行。")


# --- 私有/辅助方法 ---

func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event


func _make_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _make_touch_event(index: int, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event
