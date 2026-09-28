## GFInputDetector: 检测下一次输入事件的辅助节点。
##
## 可用于项目自己的改键界面。检测结果只返回 Godot InputEvent，冲突处理由项目层决定。
## 一轮检测从 begin 到结构化 finish 全程累计 elapsed；signal handler 可同步开始新一轮，
## 新会话会使尚未返回的旧 begin 调用栈失效，避免已宣布会话被静默覆盖。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputDetector
extends Node


# --- 信号 ---

## 开始检测时发出。
## [br]
## @api public
signal detection_started

## 检测结束时发出。input_event 为 null 表示取消或超时。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param input_event: 检测到的输入事件；取消或超时时为 null。
signal input_detected(input_event: InputEvent)

## 检测结束时发出结构化结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 检测结束结果。
signal detection_finished(result: GFInputDetectionResult)


# --- 枚举 ---

## 设备过滤类型。
## [br]
## @api public
enum DeviceType {
	## 键盘输入。
	KEYBOARD,
	## 鼠标输入。
	MOUSE,
	## 手柄按钮或轴输入。
	JOYPAD,
	## 触屏输入。
	TOUCH,
}

## 检测阶段。
## [br]
## @api public
enum DetectionState {
	## 未检测。
	IDLE,
	## 倒计时中。
	COUNTDOWN,
	## 等待取消输入释放。
	PRE_CLEAR,
	## 正在接收候选输入。
	DETECTING,
	## 等待检测到的输入释放。
	POST_CLEAR,
}


# --- 常量 ---

## 提供输入事件类型提取和事件复制操作。
## [br]
## @api private
## [br]
const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")

## 表示检测不限制动作值类型的内部哨兵值。
## [br]
## @api private
## [br]
const _ANY_VALUE_TYPE: int = -1


# --- 导出变量 ---

## 是否忽略键盘 echo 事件。
## [br]
## @api public
@export var ignore_echo: bool = true

## 轴输入检测阈值。
## [br]
## @api public
@export_range(0.0, 1.0, 0.01) var minimum_axis_amplitude: float = 0.25

## 正式接收输入前的倒计时。可用于改键界面避开确认按钮本身。
## [br]
## @api public
@export var countdown_seconds: float = 0.0

## 检测超时时间。小于等于 0 表示不超时；是否启用超时不影响 elapsed 的累计口径。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var timeout_seconds: float = 0.0

## 取消检测的输入事件列表。
## [br]
## @api public
## [br]
## @schema abort_events: Array[InputEvent] used to cancel detection or wait for release before accepting input.
@export var abort_events: Array[InputEvent] = []

## 开始正式检测前，是否等待 abort_events 中仍按住的输入释放。
## [br]
## @api public
@export var wait_for_clear_before_detection: bool = true

## 检测到输入后，是否等待该输入释放再发出 input_detected。
## [br]
## @api public
@export var wait_for_clear_after_detection: bool = false


# --- 私有变量 ---

## 当前检测阶段；新会话从 IDLE 进入倒计时、清除等待或输入接收阶段。
## [br]
## @api private
## [br]
var _state: DetectionState = DetectionState.IDLE

## 当前检测会话从开始到结束累计的有效秒数。
## [br]
## @api private
## [br]
var _elapsed: float = 0.0

## 正式接收候选输入前尚未结束的倒计时秒数。
## [br]
## @api private
## [br]
var _countdown_remaining: float = 0.0

## 当前会话的动作值类型过滤器；_ANY_VALUE_TYPE 表示不限制。
## [br]
## @api private
## [br]
var _value_type: int = _ANY_VALUE_TYPE

## 当前会话使用的允许设备类型列表副本。
## [br]
## @api private
## [br]
var _allowed_device_types: Array[int] = []

## 已接受但正在等待释放的输入事件；无需等待释放时会在完成前清空。
## [br]
## @api private
## [br]
var _pending_detected_event: InputEvent = null

## 待发出的检测结束原因，与 _pending_detected_event 一同构成待完成结果。
## [br]
## @api private
## [br]
var _pending_finish_reason: GFInputDetectionResult.FinishReason = GFInputDetectionResult.FinishReason.CANCELLED

## 记录相关触点索引当前是否仍按下，供屏幕触摸输入的释放检测使用。
## [br]
## @api private
## [br]
var _pending_screen_touches: Dictionary = {}

## 最近一次已发出的结构化检测结果；尚未完成会话时为 null。
## [br]
## @api private
## [br]
var _last_detection_result: GFInputDetectionResult = null

## 每次开始会话递增，用于识别结束信号回调中同步创建的新会话。
## [br]
## @api private
## [br]
var _session_generation: int = 0


# --- Godot 生命周期方法 ---

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS as Node.ProcessMode
	set_process(false)


func _input(event: InputEvent) -> void:
	if _state == DetectionState.IDLE:
		return
	if _should_ignore_event(event):
		return
	if _state == DetectionState.COUNTDOWN:
		_update_pending_touch_release(event)
		return
	if _state == DetectionState.PRE_CLEAR:
		_update_pending_touch_release(event)
		if _are_abort_events_released():
			_start_accepting_input()
		return
	if _state == DetectionState.POST_CLEAR:
		_update_pending_touch_release(event)
		if _pending_detected_event == null or not _is_event_still_pressed(_pending_detected_event):
			_emit_detected_input()
		return
	if _state != DetectionState.DETECTING:
		return
	if _matches_abort_event(event):
		_mark_current_input_as_handled()
		cancel_detection()
		return
	if not _matches_device_filter(event):
		return
	if not _matches_value_type_filter(event):
		return

	_mark_current_input_as_handled()
	_finish_detection(
		_INPUT_EVENT_TOOLS.duplicate_input_event(event),
		wait_for_clear_after_detection,
		GFInputDetectionResult.FinishReason.SUCCESS
	)


func _process(delta: float) -> void:
	if _state == DetectionState.IDLE:
		return

	var safe_delta: float = delta if is_finite(delta) and delta > 0.0 else 0.0
	_accumulate_elapsed(safe_delta)
	if is_finite(timeout_seconds) and timeout_seconds > 0.0:
		if _elapsed >= timeout_seconds:
			_finish_detection(null, false, GFInputDetectionResult.FinishReason.TIMEOUT)
			return

	if _state == DetectionState.COUNTDOWN:
		_countdown_remaining = maxf(_countdown_remaining - safe_delta, 0.0)
		if _countdown_remaining <= 0.0:
			_enter_pre_clear_or_detecting()
		return

	if _state == DetectionState.PRE_CLEAR:
		if _are_abort_events_released():
			_start_accepting_input()
		return

	if _state == DetectionState.POST_CLEAR:
		if _pending_detected_event == null or not _is_event_still_pressed(_pending_detected_event):
			_emit_detected_input()
		return


# --- 公共方法 ---

## 开始检测下一次输入。已有会话会先以 REPLACED 完成；其完成回调若同步开始
## 另一会话，则回调创建的最新会话优先，当前调用不会再覆盖它。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func begin_detection(allowed_device_types: Array[int] = []) -> void:
	_begin_detection_internal(_ANY_VALUE_TYPE, allowed_device_types)


## 按动作值类型开始检测下一次输入。
## [br]
## @api public
## [br]
## @param value_type: 期望的动作值类型。
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func begin_detection_for_value_type(
	value_type: GFInputAction.ValueType,
	allowed_device_types: Array[int] = []
) -> void:
	_begin_detection_internal(value_type, allowed_device_types)


## 按动作资源开始检测下一次输入。
## [br]
## @api public
## [br]
## @param action: 输入动作资源。
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func begin_detection_for_action(
	action: GFInputAction,
	allowed_device_types: Array[int] = []
) -> void:
	if action == null:
		begin_detection(allowed_device_types)
		return

	begin_detection_for_value_type(action.value_type, allowed_device_types)


## 开始检测布尔输入。
## [br]
## @api public
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func detect_bool(allowed_device_types: Array[int] = []) -> void:
	begin_detection_for_value_type(GFInputAction.ValueType.BOOL, allowed_device_types)


## 开始检测一维轴输入。
## [br]
## @api public
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func detect_axis_1d(allowed_device_types: Array[int] = []) -> void:
	begin_detection_for_value_type(GFInputAction.ValueType.AXIS_1D, allowed_device_types)


## 开始检测二维轴输入。
## [br]
## @api public
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func detect_axis_2d(allowed_device_types: Array[int] = []) -> void:
	begin_detection_for_value_type(GFInputAction.ValueType.AXIS_2D, allowed_device_types)


## 开始检测三维轴输入。
## [br]
## @api public
## [br]
## @param allowed_device_types: 允许的设备类型。空数组表示不限制。
## [br]
## @schema allowed_device_types: Array[int]，包含 DeviceType 枚举值；为空表示不过滤设备。
func detect_axis_3d(allowed_device_types: Array[int] = []) -> void:
	begin_detection_for_value_type(GFInputAction.ValueType.AXIS_3D, allowed_device_types)


## 获取正式接收输入前剩余的倒计时秒数。
## [br]
## @api public
## [br]
## @return 剩余秒数。
func get_countdown_remaining() -> float:
	return _countdown_remaining


## 获取当前检测阶段。
## [br]
## @api public
## [br]
## @return 检测阶段。
func get_detection_state() -> DetectionState:
	return _state


## 是否已经结束倒计时并正在接收候选输入。
## [br]
## @api public
## [br]
## @return 是否可接收输入。
func is_accepting_input() -> bool:
	return _state == DetectionState.DETECTING


## 取消检测。
## [br]
## @api public
func cancel_detection() -> void:
	if _state == DetectionState.IDLE:
		return
	_finish_detection(null, false, GFInputDetectionResult.FinishReason.CANCELLED)


## 检查当前是否正在检测。
## [br]
## @api public
## [br]
## @return 是否正在检测。
func is_detecting() -> bool:
	return _state != DetectionState.IDLE


## 获取最近一次检测结束结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 最近一次检测结束结果；尚未结束过检测时返回 null。
func get_last_detection_result() -> GFInputDetectionResult:
	return _last_detection_result


# --- 私有/辅助方法 ---

## 将当前输入标记为已处理，避免它继续传给其他视口处理者。
## [br]
## @api private
## [br]
func _mark_current_input_as_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


## 替换现有会话并初始化新的过滤器、计时和触摸状态；若旧会话的结束信号回调已创建更新会话，则保留回调创建的会话。
## [br]
## @api private
## [br]
func _begin_detection_internal(value_type: int, allowed_device_types: Array[int]) -> void:
	if _state != DetectionState.IDLE:
		var replaced_generation: int = _session_generation
		_finish_detection(null, false, GFInputDetectionResult.FinishReason.REPLACED)
		if _session_generation != replaced_generation:
			return
	_session_generation += 1
	_allowed_device_types = allowed_device_types.duplicate()
	_elapsed = 0.0
	_countdown_remaining = maxf(countdown_seconds, 0.0)
	_value_type = value_type
	_pending_detected_event = null
	_pending_finish_reason = GFInputDetectionResult.FinishReason.CANCELLED
	_pending_screen_touches.clear()
	_track_abort_touch_states()
	_state = DetectionState.COUNTDOWN if _countdown_remaining > 0.0 else DetectionState.PRE_CLEAR
	if _state == DetectionState.PRE_CLEAR:
		_enter_pre_clear_or_detecting()
	set_process(_state != DetectionState.IDLE)
	detection_started.emit()


## 暂存结束结果；若成功事件仍处于按下状态且要求等待释放，则进入 POST_CLEAR，否则立即发出结果。
## [br]
## @api private
## [br]
func _finish_detection(
	input_event: InputEvent,
	wait_for_release: bool,
	finish_reason: GFInputDetectionResult.FinishReason
) -> void:
	if input_event != null and wait_for_release and _is_event_still_pressed(input_event):
		_pending_detected_event = input_event
		_pending_finish_reason = finish_reason
		_track_pending_touch(input_event)
		_state = DetectionState.POST_CLEAR
		set_process(true)
		return

	_pending_detected_event = input_event
	_pending_finish_reason = finish_reason
	_emit_detected_input()


## 快照待完成结果和计时数据，清理当前会话状态，然后依次发出结构化结果信号与兼容信号。
## [br]
## @api private
## [br]
func _emit_detected_input() -> void:
	var input_event: InputEvent = _pending_detected_event
	var finish_reason: GFInputDetectionResult.FinishReason = _pending_finish_reason
	var detection_elapsed_seconds: float = _elapsed
	var detection_value_type: int = _value_type
	var detection_allowed_device_types: Array[int] = _allowed_device_types.duplicate()
	_state = DetectionState.IDLE
	_elapsed = 0.0
	_countdown_remaining = 0.0
	_value_type = _ANY_VALUE_TYPE
	_pending_detected_event = null
	_pending_finish_reason = GFInputDetectionResult.FinishReason.CANCELLED
	_pending_screen_touches.clear()
	set_process(false)
	_last_detection_result = GFInputDetectionResult.create(
		finish_reason,
		input_event,
		detection_elapsed_seconds,
		detection_value_type,
		detection_allowed_device_types
	)
	detection_finished.emit(_last_detection_result)
	input_detected.emit(input_event)


## 根据配置检查取消输入是否仍按下；需要等待时进入 PRE_CLEAR，否则转入输入接收阶段。
## [br]
## @api private
## [br]
func _enter_pre_clear_or_detecting() -> void:
	if wait_for_clear_before_detection and not _are_abort_events_released():
		_state = DetectionState.PRE_CLEAR
		set_process(true)
		return
	_start_accepting_input()


## 将阶段切换为接收候选输入并启用逐帧处理。
## [br]
## @api private
## [br]
func _start_accepting_input() -> void:
	_state = DetectionState.DETECTING
	set_process(true)


## 累加正向时间增量；无效或负的既有累计值先归零，溢出时仅在启用了有效超时的情况下钳到超时值。
## [br]
## @api private
## [br]
func _accumulate_elapsed(delta: float) -> void:
	if not is_finite(_elapsed) or _elapsed < 0.0:
		_elapsed = 0.0
	if delta <= 0.0:
		return
	var next_elapsed: float = _elapsed + delta
	if is_finite(next_elapsed):
		_elapsed = next_elapsed
	elif is_finite(timeout_seconds) and timeout_seconds > 0.0:
		_elapsed = timeout_seconds


## 忽略键盘 echo；摇杆轴事件的绝对幅度低于 minimum_axis_amplitude 时也忽略。
## [br]
## @api private
## [br]
func _should_ignore_event(event: InputEvent) -> bool:
	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(event)
	if key_event != null:
		return ignore_echo and key_event.echo

	var joy_motion: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(event)
	if joy_motion != null:
		return absf(joy_motion.axis_value) < minimum_axis_amplitude
	return false


## 检查事件是否与 abort_events 中任一非空事件匹配。
## [br]
## @api private
## [br]
func _matches_abort_event(event: InputEvent) -> bool:
	for abort_event: InputEvent in abort_events:
		if abort_event != null and abort_event.is_match(event, true):
			return true
	return false


## 确认 abort_events 中没有仍处于按下状态的事件。
## [br]
## @api private
## [br]
func _are_abort_events_released() -> bool:
	for abort_event: InputEvent in abort_events:
		if abort_event != null and _is_event_still_pressed(abort_event):
			return false
	return true


## 查询事件当前是否按下；屏幕触摸优先使用跟踪表中的最新状态，并按事件类型读取 Godot 输入状态。
## [br]
## @api private
## [br]
func _is_event_still_pressed(event: InputEvent) -> bool:
	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(event)
	if key_event != null:
		if key_event.physical_keycode != KEY_NONE:
			return Input.is_physical_key_pressed(key_event.physical_keycode)
		return key_event.keycode != KEY_NONE and Input.is_key_pressed(key_event.keycode)

	var mouse_button: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(event)
	if mouse_button != null:
		return Input.is_mouse_button_pressed(mouse_button.button_index)

	var joy_button: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(event)
	if joy_button != null:
		return Input.is_joy_button_pressed(joy_button.device, joy_button.button_index)

	var joy_motion: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(event)
	if joy_motion != null:
		return absf(Input.get_joy_axis(joy_motion.device, joy_motion.axis)) >= minimum_axis_amplitude

	var action_event: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(event)
	if action_event != null:
		return Input.is_action_pressed(action_event.action)

	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch != null:
		if _pending_screen_touches.has(screen_touch.index):
			return GFVariantData.get_option_bool(_pending_screen_touches, screen_touch.index)
		if _state != DetectionState.DETECTING:
			return false
		return screen_touch.pressed
	return false


## 重置触摸跟踪表，并在待结束事件是屏幕触摸时记录其索引和 pressed 状态。
## [br]
## @api private
## [br]
func _track_pending_touch(event: InputEvent) -> void:
	_pending_screen_touches.clear()
	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch == null:
		return
	_pending_screen_touches[screen_touch.index] = screen_touch.pressed


## 重置触摸跟踪表，并记录 abort_events 中屏幕触摸事件的初始 pressed 状态。
## [br]
## @api private
## [br]
func _track_abort_touch_states() -> void:
	_pending_screen_touches.clear()
	for abort_event: InputEvent in abort_events:
		var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(abort_event)
		if screen_touch != null:
			_pending_screen_touches[screen_touch.index] = screen_touch.pressed


## 更新已跟踪屏幕触摸索引的 pressed 状态；未跟踪的触点不会加入映射。
## [br]
## @api private
## [br]
func _update_pending_touch_release(event: InputEvent) -> void:
	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch == null:
		return
	if not _pending_screen_touches.has(screen_touch.index):
		return
	_pending_screen_touches[screen_touch.index] = screen_touch.pressed


## 设备过滤列表为空时允许所有事件；否则仅允许能分类且类型包含在列表中的事件。
## [br]
## @api private
## [br]
func _matches_device_filter(event: InputEvent) -> bool:
	if _allowed_device_types.is_empty():
		return true

	var device_type: int = _get_event_device_type(event)
	return device_type != -1 and _allowed_device_types.has(device_type)


## 按当前动作值类型筛选候选事件；通用模式仅接受布尔事件，轴类型接受摇杆轴事件，未处理的类型回退为允许。
## [br]
## @api private
## [br]
func _matches_value_type_filter(event: InputEvent) -> bool:
	if _value_type == _ANY_VALUE_TYPE:
		return _is_default_bindable_event(event)

	match _value_type:
		GFInputAction.ValueType.BOOL:
			return _is_bool_event(event)
		GFInputAction.ValueType.AXIS_1D, GFInputAction.ValueType.AXIS_2D, GFInputAction.ValueType.AXIS_3D:
			return event is InputEventJoypadMotion
		_:
			return true


## 当前值类型不受限制时使用的默认候选规则，即只接受布尔输入事件。
## [br]
## @api private
## [br]
func _is_default_bindable_event(event: InputEvent) -> bool:
	return _is_bool_event(event)


## 判断受支持的动作、键盘键、鼠标按钮、手柄按钮或屏幕触摸事件是否处于按下状态。
## [br]
## @api private
## [br]
func _is_bool_event(event: InputEvent) -> bool:
	var action_event: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(event)
	if action_event != null:
		return action_event.pressed

	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(event)
	if key_event != null:
		return key_event.pressed

	var mouse_button: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(event)
	if mouse_button != null:
		return mouse_button.pressed

	var joy_button: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(event)
	if joy_button != null:
		return joy_button.pressed

	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch != null:
		return screen_touch.pressed
	return false


## 将键盘、鼠标、手柄和触摸事件分类为 DeviceType；不支持的事件返回 -1。
## [br]
## @api private
## [br]
func _get_event_device_type(event: InputEvent) -> int:
	if event is InputEventKey:
		return DeviceType.KEYBOARD
	if event is InputEventMouse:
		return DeviceType.MOUSE
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return DeviceType.JOYPAD
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return DeviceType.TOUCH
	return -1
