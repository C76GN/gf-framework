## 测试 GFInputDetector 的值类型过滤和倒计时检测。
extends GutTest


# --- 私有变量 ---

var _detector: GFInputDetector
var _received_event: InputEvent
var _received_result: GFInputDetectionResult
var _received_count: int
var _received_result_count: int


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_received_event = null
	_received_result = null
	_received_count = 0
	_received_result_count = 0
	_detector = GFInputDetector.new()
	get_tree().root.add_child(_detector)
	var _connect_result_17: Variant = _detector.input_detected.connect(func(input_event: InputEvent) -> void:
		_received_event = input_event
		_received_count += 1
	)
	var _connect_result_21: Variant = _detector.detection_finished.connect(func(result: GFInputDetectionResult) -> void:
		_received_result = result
		_received_result_count += 1
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
	assert_not_null(_received_result, "检测器应发出结构化结果。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.SUCCESS, "检测成功时应标记 success。")
	assert_true(_received_result.is_success(), "成功结果应可直接判断。")


## 验证默认检测只接收离散可绑定输入，避免鼠标移动或触屏拖拽误触发改键。
func test_default_detection_ignores_motion_and_drag_events() -> void:
	_detector.begin_detection()

	_detector._input(_make_mouse_motion_event(Vector2(12.0, -4.0)))
	_detector._input(_make_screen_drag_event(1, Vector2(8.0, 3.0)))

	assert_null(_received_event, "默认检测不应接收鼠标移动或触屏拖拽。")
	assert_true(_detector.is_detecting(), "忽略连续输入后检测应继续等待。")

	_detector._input(_make_key_event(KEY_SPACE, true))

	assert_not_null(_received_event, "后续离散输入仍应被接收。")
	assert_true(_received_event is InputEventKey, "检测结果应保留离散输入事件类型。")


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


func test_pre_clear_tracks_abort_touch_release_from_detection_start() -> void:
	var abort_input_events: Array[InputEvent] = [_make_touch_event(7, true)]
	_detector.abort_events = abort_input_events
	_detector.wait_for_clear_before_detection = true

	_detector.begin_detection([GFInputDetector.DeviceType.TOUCH])

	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.PRE_CLEAR, "已按下取消触点应阻止检测立即接收输入。")
	_detector._input(_make_touch_event(7, false))
	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.DETECTING, "匹配 release 应结束前清理阶段。")

	_detector._input(_make_touch_event(3, true))

	assert_not_null(_received_event, "取消触点释放后应能检测新的触屏输入。")
	assert_eq(_received_count, 1, "前清理 release 本身不应被误报为候选输入。")


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
	assert_eq(_received_result_count, 1, "倒计时超时应发出一次结构化结果。")
	assert_null(_received_event, "超时结果应为空事件。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.TIMEOUT, "超时结果应明确标记 timeout。")
	assert_false(_received_result.is_success(), "超时结果不应视为成功。")
	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.IDLE, "超时后检测器应回到空闲状态。")
	assert_eq(_detector.get_last_detection_result(), _received_result, "检测器应保留最近一次结构化结果。")


## 验证触屏输入在等待释放时会由后续 release 事件完成检测。
func test_touch_detection_waits_for_matching_release_event() -> void:
	_detector.wait_for_clear_after_detection = true
	_detector.begin_detection([GFInputDetector.DeviceType.TOUCH])

	_detector._input(_make_touch_event(3, true))

	assert_eq(_received_count, 0, "等待释放时不应立刻发出检测结果。")
	assert_eq(_detector.get_detection_state(), GFInputDetector.DetectionState.POST_CLEAR, "触屏按下后应进入后清理阶段。")

	_detector._input(_make_touch_event(3, false))

	assert_eq(_received_count, 1, "匹配触点释放后应发出检测结果。")
	assert_eq(_received_result_count, 1, "匹配触点释放后应发出结构化结果。")
	assert_true(_received_event is InputEventScreenTouch, "检测结果应保留触屏事件类型。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.SUCCESS, "触屏检测成功时应标记 success。")
	if _received_event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = _received_event
		assert_true(touch_event.pressed, "返回的检测结果应是最初捕获的按下事件。")


## 验证重复开始检测会取消上一轮等待者。
func test_begin_detection_cancels_previous_detection() -> void:
	_detector.begin_detection()

	_detector.begin_detection()

	assert_eq(_received_count, 1, "重复 begin 应先结束上一轮检测。")
	assert_null(_received_event, "被替换的检测应以空事件结束。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.REPLACED, "被新检测替换时应明确标记 replaced。")
	assert_true(_detector.is_detecting(), "新检测应继续进行。")


func test_replaced_finish_callback_begin_wins_over_stale_outer_begin() -> void:
	var callback_state: Dictionary = {
		"started_count": 0,
		"reentered": false,
	}
	var _started_connection: Variant = _detector.detection_started.connect(func() -> void:
		callback_state["started_count"] = GFVariantData.get_option_int(callback_state, "started_count") + 1
	)
	var _reentry_connection: Variant = _detector.detection_finished.connect(
		func(result: GFInputDetectionResult) -> void:
			if (
				result.reason != GFInputDetectionResult.FinishReason.REPLACED
				or GFVariantData.get_option_bool(callback_state, "reentered")
			):
				return
			callback_state["reentered"] = true
			_detector.begin_detection([GFInputDetector.DeviceType.MOUSE])
	)

	_detector.begin_detection([GFInputDetector.DeviceType.KEYBOARD])
	_detector.begin_detection([GFInputDetector.DeviceType.TOUCH])

	assert_eq(GFVariantData.get_option_int(callback_state, "started_count"), 2, "替换回调开始的新会话应使旧 begin 调用栈失效，不能再宣布第三个会话。")
	assert_eq(_received_result_count, 1, "初始会话应精确收到一次 replaced 结果。")

	_detector._input(_make_key_event(KEY_SPACE, true))
	assert_true(_detector.is_detecting(), "重入创建的鼠标会话不应被旧调用栈覆盖成键盘或触屏会话。")

	_detector._input(_make_mouse_button_event(MOUSE_BUTTON_LEFT, true))

	assert_eq(_received_result_count, 2, "重入会话成功后也应精确收到一次完成结果。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.SUCCESS, "最终完成结果应属于重入会话。")
	assert_eq(GFVariantData.get_option_int(callback_state, "started_count"), _received_result_count, "每个已宣布开始的会话都应恰好完成一次。")


func test_default_detection_elapsed_includes_accepting_wait() -> void:
	_detector.timeout_seconds = 0.0
	_detector.wait_for_clear_before_detection = false
	_detector.begin_detection()

	_detector._process(0.25)
	_detector._input(_make_key_event(KEY_SPACE, true))

	assert_not_null(_received_result, "默认检测成功时应返回结构化结果。")
	assert_almost_eq(_received_result.elapsed_seconds, 0.25, 0.0001, "无 timeout 时也必须累计正式等待输入的时间。")


## 验证显式取消会产生结构化取消结果。
func test_cancel_detection_reports_cancelled_reason() -> void:
	_detector.begin_detection()

	_detector.cancel_detection()

	assert_eq(_received_count, 1, "显式取消应发出旧版检测结束信号。")
	assert_eq(_received_result_count, 1, "显式取消应发出结构化结果。")
	assert_null(_received_event, "取消结果应为空事件。")
	assert_eq(_received_result.reason, GFInputDetectionResult.FinishReason.CANCELLED, "显式取消应标记 cancelled。")
	assert_false(_received_result.has_input_event(), "取消结果不应包含输入事件。")


## 验证结构化结果可导出为 JSON 安全字典。
func test_detection_result_dictionary_uses_input_identity() -> void:
	var input_event: InputEventKey = _make_key_event(KEY_SPACE, true)

	var result: GFInputDetectionResult = GFInputDetectionResult.create(
		GFInputDetectionResult.FinishReason.SUCCESS,
		input_event,
		0.25,
		int(GFInputAction.ValueType.BOOL),
		[GFInputDetector.DeviceType.KEYBOARD]
	)
	var data: Dictionary = result.to_dictionary()
	var reason_text: String = GFVariantData.get_option_string(data, &"reason")
	var success: bool = GFVariantData.get_option_bool(data, &"success")
	var raw_identity: Variant = data.get(&"input_identity", {})

	assert_eq(reason_text, "success", "字典应包含稳定结束原因。")
	assert_true(success, "字典应包含成功标记。")
	assert_true(raw_identity is Dictionary, "字典应包含输入身份字典。")
	if raw_identity is Dictionary:
		var identity: Dictionary = raw_identity
		var identity_kind: String = GFVariantData.get_option_string(identity, &"kind")
		assert_eq(identity_kind, "key", "输入身份应复用统一事件身份。")


func test_detection_result_dictionary_normalizes_nonfinite_elapsed() -> void:
	var result: GFInputDetectionResult = GFInputDetectionResult.create(
		GFInputDetectionResult.FinishReason.CANCELLED,
		null,
		INF
	)
	var created_data: Dictionary = result.to_dictionary()

	assert_eq(result.elapsed_seconds, 0.0, "create 应把非有限 elapsed 规范为稳定非负值。")
	assert_eq(GFVariantData.get_option_float(created_data, &"elapsed_seconds"), 0.0, "JSON 字典不得泄漏 Infinity。")

	result.elapsed_seconds = NAN
	var mutated_data: Dictionary = result.to_dictionary()
	var json_text: String = JSON.stringify(mutated_data)
	var decoded: Variant = JSON.parse_string(json_text)

	assert_eq(GFVariantData.get_option_float(mutated_data, &"elapsed_seconds"), 0.0, "直接变异字段后，JSON 边界仍应重新规范非有限值。")
	assert_true(decoded is Dictionary, "非有限输入的检测结果仍应完成 JSON round-trip。")
	assert_false(json_text.contains("null"), "elapsed 不应依赖 JSON 将非有限数退化为 null。")


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


func _make_mouse_button_event(button: MouseButton, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _make_mouse_motion_event(relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	return event


func _make_touch_event(index: int, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	return event


func _make_screen_drag_event(index: int, relative: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.relative = relative
	return event
