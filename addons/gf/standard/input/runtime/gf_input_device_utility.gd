## GFInputDeviceUtility: 本地玩家输入设备分配工具。
##
## 负责维护玩家索引与键鼠、手柄、触控、AI 或自定义设备的映射。
## 它不消费输入事件，也不规定动作名。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFInputDeviceUtility
extends GFUtility


# --- 信号 ---

## 设备映射发生变化时发出。
## [br]
## @api public
## [br]
## @param assignments: 当前设备映射副本。
signal assignments_changed(assignments: Array[GFInputDeviceAssignment])

## 最近产生输入的玩家变化时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
signal active_player_changed(player_index: int)

## 最近产生输入的设备变化时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param assignment: 活跃设备映射副本。
## [br]
## @param event: 触发变化的输入事件副本；手动设置时可能为空。
signal active_device_changed(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)

## 收到项目配置的加入输入时发出。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param assignment: 触发加入请求的设备映射副本。
## [br]
## @param event: 触发加入请求的输入事件副本。
signal player_join_requested(player_index: int, assignment: GFInputDeviceAssignment, event: InputEvent)

## 设备分配诊断事件被记录时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param event_record: 结构化设备分配事件副本。
## [br]
## @schema event_record: Dictionary assignment event record.
signal assignment_event_recorded(event_record: Dictionary)


# --- 常量 ---

## 默认保留的设备分配诊断事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_ASSIGNMENT_EVENTS: int = 64

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 公共变量 ---

## 最多保留的设备分配诊断事件数量。设置为 0 时不保留历史。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_assignment_events: int = DEFAULT_MAX_ASSIGNMENT_EVENTS:
	set(value):
		max_assignment_events = maxi(value, 0)
		_trim_assignment_events()

## 允许的最大本地玩家数。
## [br]
## @api public
var max_players: int = 4:
	set(value):
		max_players = maxi(value, 0)

## 是否为 0 号玩家自动分配键鼠。
## [br]
## @api public
var include_keyboard_mouse: bool = true

## 是否在移动平台自动添加触控设备。
## [br]
## @api public
var include_touch: bool = true

## 是否在收到未登记手柄输入时自动分配到空玩家席位。
## [br]
## @api public
var auto_assign_joypads_on_input: bool = true

## 未登记手柄轴输入需要达到该幅度才会触发自动分配，避免漂移噪声抢占席位。
## [br]
## @api public
var auto_assign_axis_threshold: float = 0.75

## 已登记手柄轴输入需要达到该幅度才会切换最近活跃玩家。
## [br]
## @api public
var active_player_axis_threshold: float = 0.2:
	set(value):
		active_player_axis_threshold = clampf(value, 0.0, 1.0)

## 可触发本地玩家加入请求的输入事件模板。为空时不启用 join 检测。
## [br]
## @api public
var join_events: Array[InputEvent] = []

## join 输入来自未登记设备时，是否自动分配到空玩家席位。
## [br]
## @api public
var auto_assign_devices_on_join: bool = true

## 当前最近活跃玩家索引。
## [br]
## @api public
var active_player_index: int = 0


# --- 私有变量 ---

var _assignments: Array[GFInputDeviceAssignment] = []
var _player_deadzones: Dictionary = {}
var _assignment_events: Array[Dictionary] = []
var _next_assignment_event_index: int = 1


# --- GF 生命周期方法 ---

## 初始化设备映射并订阅手柄连接变化。
## [br]
## @api public
func init() -> void:
	refresh_connected_devices()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		var _connection_result: int = Input.joy_connection_changed.connect(_on_joy_connection_changed)


## 清理设备映射并取消手柄连接变化订阅。
## [br]
## @api public
func dispose() -> void:
	_assignments.clear()
	_player_deadzones.clear()
	_assignment_events.clear()
	_next_assignment_event_index = 1
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


# --- 公共方法 ---

## 按当前硬件重新生成设备映射。
## [br]
## @api public
func refresh_connected_devices() -> void:
	_assignments.clear()

	if include_keyboard_mouse and _assignments.size() < max_players:
		_assignments.append(create_assignment(
			_assignments.size(),
			GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE,
			0
		))

	if include_touch and _is_touch_platform() and _assignments.size() < max_players:
		_assignments.append(create_assignment(
			_assignments.size(),
			GFInputDeviceAssignment.DeviceType.TOUCH,
			-1
		))

	for joypad_id: int in Input.get_connected_joypads():
		if _assignments.size() >= max_players:
			break
		_assignments.append(create_assignment(
			_assignments.size(),
			GFInputDeviceAssignment.DeviceType.JOYPAD,
			joypad_id
		))

	assignments_changed.emit(get_assignments())
	_record_assignment_event(
		&"assignments_refreshed",
		null,
		null,
		&"refresh_connected_devices",
		null,
		{ "assignment_count": _assignments.size() }
	)
	_repair_active_player_after_assignments_changed(&"assignments_refreshed")


## 创建一个设备映射。
## [br]
## @param player_index: 玩家索引。
## [br]
## @param device_type: 设备类型。
## [br]
## @param device_id: 设备 ID。
## [br]
## @return 新映射。
## [br]
## @api public
func create_assignment(
	player_index: int,
	device_type: GFInputDeviceAssignment.DeviceType,
	device_id: int
) -> GFInputDeviceAssignment:
	var assignment: GFInputDeviceAssignment = GFInputDeviceAssignment.new()
	assignment.player_index = player_index
	assignment.device_type = device_type
	assignment.device_id = _normalize_device_id(device_type, device_id)
	return assignment


## 手动设置一个玩家的设备映射。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param assignment: 设备映射。
## [br]
## @param reason: 调用方给出的分配原因。
## [br]
## @param event_metadata: 额外诊断元数据。
## [br]
## @param source_event: 触发分配的输入事件；可为空。
## [br]
## @schema event_metadata: Dictionary assignment event metadata.
func set_assignment(
	assignment: GFInputDeviceAssignment,
	reason: StringName = &"manual",
	event_metadata: Dictionary = {},
	source_event: InputEvent = null
) -> void:
	if assignment == null:
		return
	if assignment.player_index < 0 or assignment.player_index >= max_players:
		push_warning("[GFInputDeviceUtility] 忽略越界玩家设备映射：%d" % assignment.player_index)
		return

	var next_assignment: GFInputDeviceAssignment = assignment.duplicate_assignment()
	next_assignment.device_id = _normalize_device_id(next_assignment.device_type, next_assignment.device_id)
	var previous_assignment: GFInputDeviceAssignment = null
	var displaced_players: Array[int] = []
	var replaced: bool = false
	for index: int in range(_assignments.size() - 1, -1, -1):
		var current: GFInputDeviceAssignment = _assignments[index]
		if current.player_index == next_assignment.player_index:
			previous_assignment = current.duplicate_assignment()
			_assignments[index] = next_assignment
			replaced = true
			continue
		if (
			_should_enforce_unique_device(next_assignment)
			and current.device_type == next_assignment.device_type
			and _normalize_device_id(current.device_type, current.device_id) == next_assignment.device_id
		):
			displaced_players.append(current.player_index)
			_assignments.remove_at(index)

	if not replaced:
		_assignments.append(next_assignment)
	_assignments.sort_custom(func(a: GFInputDeviceAssignment, b: GFInputDeviceAssignment) -> bool:
		return a.player_index < b.player_index
	)
	assignments_changed.emit(get_assignments())
	var metadata: Dictionary = event_metadata.duplicate(true)
	if not displaced_players.is_empty():
		metadata["displaced_player_indices"] = displaced_players
	_record_assignment_event(&"assignment_set", next_assignment, previous_assignment, reason, source_event, metadata)
	_repair_active_player_after_assignments_changed(&"assignment_set")


## 移除指定玩家的设备映射。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param player_index: 玩家索引。
## [br]
## @param reason: 调用方给出的移除原因。
func remove_assignment(player_index: int, reason: StringName = &"manual") -> void:
	for index: int in range(_assignments.size() - 1, -1, -1):
		if _assignments[index].player_index == player_index:
			var previous_assignment: GFInputDeviceAssignment = _assignments[index].duplicate_assignment()
			_assignments.remove_at(index)
			assignments_changed.emit(get_assignments())
			_record_assignment_event(&"assignment_removed", null, previous_assignment, reason)
			_repair_active_player_after_assignments_changed(&"assignment_removed")
			return


## 获取指定玩家的设备映射。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @return 设备映射；不存在时返回 null。
func get_assignment(player_index: int) -> GFInputDeviceAssignment:
	for assignment: GFInputDeviceAssignment in _assignments:
		if assignment.player_index == player_index:
			return assignment
	return null


## 根据设备类型和设备 ID 获取玩家索引。
## [br]
## @param device_type: 设备类型。
## [br]
## @param device_id: 设备 ID。
## [br]
## @return 玩家索引；不存在时返回 -1。
## [br]
## @api public
func get_player_for_device(
	device_type: GFInputDeviceAssignment.DeviceType,
	device_id: int
) -> int:
	var normalized_device_id: int = _normalize_device_id(device_type, device_id)
	for assignment: GFInputDeviceAssignment in _assignments:
		if (
			assignment.device_type == device_type
			and _normalize_device_id(assignment.device_type, assignment.device_id) == normalized_device_id
		):
			return assignment.player_index
	return -1


## 根据输入事件获取玩家索引，不产生自动分配。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return 玩家索引；无法匹配时返回 -1。
func get_player_for_event(event: InputEvent) -> int:
	var device_type: int = _get_event_device_type(event)
	if device_type == -1:
		return -1

	var device_id: int = _get_event_device_id(event, device_type)
	return get_player_for_device(device_type, device_id)


## 处理输入事件并返回玩家索引。未登记手柄可按配置自动占位。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return 玩家索引；无法匹配时返回 -1。
func handle_input_event(event: InputEvent) -> int:
	if event == null:
		return -1

	var device_type: int = _get_event_device_type(event)
	if device_type == -1:
		return -1

	var device_id: int = _get_event_device_id(event, device_type)
	var player_index: int = get_player_for_device(device_type, device_id)
	if (
		player_index == -1
		and device_type == GFInputDeviceAssignment.DeviceType.JOYPAD
		and auto_assign_joypads_on_input
		and _is_event_active_enough_for_assignment(event)
	):
		player_index = assign_device_to_next_player(device_type, device_id, &"auto_assign_on_input", event)

	if player_index != -1 and _is_event_active_enough_for_active_player(event):
		_set_active_player(player_index, event)

	return player_index


## 处理本地玩家加入输入。只有匹配 join_events 的输入会触发。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return 请求加入的玩家索引；未匹配或无可用席位时返回 -1。
func handle_join_input_event(event: InputEvent) -> int:
	if event == null or not is_join_input_event(event):
		return -1
	if not _is_event_active_enough_for_active_player(event):
		return -1

	var device_type: int = _get_event_device_type(event)
	if device_type == -1:
		return -1

	var device_id: int = _get_event_device_id(event, device_type)
	var player_index: int = get_player_for_device(device_type, device_id)
	if player_index == -1 and auto_assign_devices_on_join:
		player_index = assign_device_to_next_player(device_type, device_id, &"join_input", event)

	if player_index == -1:
		return -1

	_set_active_player(player_index, event)
	var assignment: GFInputDeviceAssignment = get_assignment(player_index)
	player_join_requested.emit(
		player_index,
		assignment.duplicate_assignment() if assignment != null else null,
		_INPUT_EVENT_TOOLS.duplicate_input_event(event)
	)
	return player_index


## 检查输入事件是否匹配当前 join_events。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return 是否是加入输入。
func is_join_input_event(event: InputEvent) -> bool:
	if event == null:
		return false

	for template: InputEvent in join_events:
		if _event_matches_template(template, event):
			return true
	return false


## 使用常见本地多人加入输入填充 join_events。
## [br]
## @api public
## [br]
## @param include_keyboard: 是否加入 Enter / 小键盘 Enter。
## [br]
## @param include_joypad: 是否加入手柄确认 / 开始按钮。
func configure_default_join_events(include_keyboard: bool = true, include_joypad: bool = true) -> void:
	join_events.clear()
	if include_keyboard:
		join_events.append(_make_join_key_event(KEY_ENTER))
		join_events.append(_make_join_key_event(KEY_KP_ENTER))
	if include_joypad:
		join_events.append(_make_join_joy_button_event(JOY_BUTTON_A))
		join_events.append(_make_join_joy_button_event(JOY_BUTTON_START))


## 清空 join 输入模板。
## [br]
## @api public
func clear_join_events() -> void:
	join_events.clear()


## 把设备分配给第一个空玩家席位。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param device_type: 设备类型。
## [br]
## @param device_id: 设备 ID。
## [br]
## @param reason: 调用方给出的分配原因。
## [br]
## @param source_event: 触发分配的输入事件；可为空。
## [br]
## @return 分配到的玩家索引；无空位时返回 -1。
func assign_device_to_next_player(
	device_type: GFInputDeviceAssignment.DeviceType,
	device_id: int,
	reason: StringName = &"auto_assign",
	source_event: InputEvent = null
) -> int:
	var normalized_device_id: int = _normalize_device_id(device_type, device_id)
	var existing_player: int = get_player_for_device(device_type, normalized_device_id)
	if existing_player != -1:
		return existing_player

	var player_index: int = _find_first_empty_player_index()
	if player_index == -1:
		return -1

	set_assignment(create_assignment(player_index, device_type, normalized_device_id), reason, {}, source_event)
	return player_index


## 设置最近活跃玩家。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
func set_active_player(player_index: int) -> void:
	if player_index < 0 or player_index >= max_players:
		return
	if get_assignment(player_index) == null:
		return
	_set_active_player(player_index, null, &"manual")


## 设置玩家级输入死区。小于 0 表示清除覆盖。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @param deadzone: 死区值。
func set_player_deadzone(player_index: int, deadzone: float) -> void:
	if player_index < 0:
		return
	if deadzone < 0.0:
		var _deadzone_removed: bool = _player_deadzones.erase(player_index)
	else:
		_player_deadzones[player_index] = clampf(deadzone, 0.0, 1.0)


## 获取玩家级输入死区覆盖。
## [br]
## @param player_index: 玩家索引。
## [br]
## @param fallback: 没有覆盖时返回的值。
## [br]
## @return 死区值。
## [br]
## @api public
func get_player_deadzone(player_index: int, fallback: float = -1.0) -> float:
	var raw_deadzone: Variant = fallback
	if _player_deadzones.has(player_index):
		raw_deadzone = _player_deadzones[player_index]
	if raw_deadzone is float:
		return raw_deadzone
	if raw_deadzone is int:
		var int_deadzone: int = raw_deadzone
		return float(int_deadzone)
	if raw_deadzone is bool:
		var bool_deadzone: bool = raw_deadzone
		return float(bool_deadzone)
	return fallback


## 获取玩家设备显示名。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @return 显示名。
func get_device_name(player_index: int) -> String:
	var assignment: GFInputDeviceAssignment = get_assignment(player_index)
	if assignment == null:
		return ""

	match assignment.device_type:
		GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE:
			return "Keyboard / Mouse"
		GFInputDeviceAssignment.DeviceType.TOUCH:
			return "Touch"
		GFInputDeviceAssignment.DeviceType.JOYPAD:
			return Input.get_joy_name(assignment.device_id)
		GFInputDeviceAssignment.DeviceType.AI:
			return "AI"
		GFInputDeviceAssignment.DeviceType.CUSTOM:
			return "Custom %d" % assignment.device_id
		_:
			return ""


## 获取当前活跃设备映射。
## [br]
## @api public
## [br]
## @return 活跃设备映射副本；不存在时返回 null。
func get_active_assignment() -> GFInputDeviceAssignment:
	var assignment: GFInputDeviceAssignment = get_assignment(active_player_index)
	return assignment.duplicate_assignment() if assignment != null else null


## 获取当前活跃设备显示名。
## [br]
## @api public
## [br]
## @return 活跃设备显示名。
func get_active_device_name() -> String:
	return get_device_name(active_player_index)


## 启动指定玩家手柄震动。
## [br]
## @param player_index: 玩家索引。
## [br]
## @param weak_magnitude: 低频马达强度，范围 0 到 1。
## [br]
## @param strong_magnitude: 高频马达强度，范围 0 到 1。
## [br]
## @param duration_seconds: 持续时间，0 表示由引擎默认处理。
## [br]
## @return 成功转发到手柄设备时返回 true。
## [br]
## @api public
func start_vibration_for_player(
	player_index: int,
	weak_magnitude: float,
	strong_magnitude: float,
	duration_seconds: float = 0.0
) -> bool:
	var assignment: GFInputDeviceAssignment = get_assignment(player_index)
	if assignment == null or assignment.device_type != GFInputDeviceAssignment.DeviceType.JOYPAD:
		return false
	if assignment.device_id < 0:
		return false

	Input.start_joy_vibration(
		assignment.device_id,
		clampf(weak_magnitude, 0.0, 1.0),
		clampf(strong_magnitude, 0.0, 1.0),
		maxf(duration_seconds, 0.0)
	)
	return true


## 停止指定玩家手柄震动。
## [br]
## @api public
## [br]
## @param player_index: 玩家索引。
## [br]
## @return 成功转发到手柄设备时返回 true。
func stop_vibration_for_player(player_index: int) -> bool:
	var assignment: GFInputDeviceAssignment = get_assignment(player_index)
	if assignment == null or assignment.device_type != GFInputDeviceAssignment.DeviceType.JOYPAD:
		return false
	if assignment.device_id < 0:
		return false

	Input.stop_joy_vibration(assignment.device_id)
	return true


## 获取所有设备映射的拷贝。
## [br]
## @api public
## [br]
## @return 映射数组。
func get_assignments() -> Array[GFInputDeviceAssignment]:
	var result: Array[GFInputDeviceAssignment] = []
	for assignment: GFInputDeviceAssignment in _assignments:
		result.append(assignment.duplicate_assignment())
	return result


## 清空所有映射。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 调用方给出的清空原因。
func clear_assignments(reason: StringName = &"manual") -> void:
	var previous_count: int = _assignments.size()
	_assignments.clear()
	assignments_changed.emit(get_assignments())
	_record_assignment_event(
		&"assignments_cleared",
		null,
		null,
		reason,
		null,
		{ "previous_count": previous_count }
	)
	_repair_active_player_after_assignments_changed(&"assignments_cleared")


## 获取设备分配诊断事件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param limit: 最大返回数量；小于等于 0 时返回全部事件。
## [br]
## @return 设备分配事件数组。
## [br]
## @schema return: Array[Dictionary] assignment event records.
func get_assignment_events(limit: int = 0) -> Array[Dictionary]:
	if limit <= 0 or _assignment_events.size() <= limit:
		return _assignment_events.duplicate(true)
	var result: Array[Dictionary] = []
	var start_index: int = maxi(_assignment_events.size() - limit, 0)
	for index: int in range(start_index, _assignment_events.size()):
		result.append(_assignment_events[index].duplicate(true))
	return result


## 获取当前设备分配诊断报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param event_limit: 最近事件数量。
## [br]
## @return 设备分配报告。
## [br]
## @schema return: Dictionary containing max_players, active_player_index, assignments, active_assignment, event_count, and recent_events.
func get_assignment_report(event_limit: int = 10) -> Dictionary:
	var assignments: Array[Dictionary] = []
	for assignment: GFInputDeviceAssignment in _assignments:
		assignments.append(_assignment_to_dictionary(assignment))
	return {
		"max_players": max_players,
		"active_player_index": active_player_index,
		"assignment_count": _assignments.size(),
		"assignments": assignments,
		"active_assignment": _assignment_to_dictionary(get_assignment(active_player_index)),
		"event_count": _assignment_events.size(),
		"recent_events": get_assignment_events(event_limit),
	}


# --- 私有/辅助方法 ---

func _is_touch_platform() -> bool:
	var os_name: String = OS.get_name()
	return os_name == "Android" or os_name == "iOS"


func _get_event_device_type(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouse:
		return GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return GFInputDeviceAssignment.DeviceType.TOUCH
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return GFInputDeviceAssignment.DeviceType.JOYPAD
	return -1


func _get_event_device_id(
	event: InputEvent,
	device_type: GFInputDeviceAssignment.DeviceType
) -> int:
	match device_type:
		GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE:
			return 0
		GFInputDeviceAssignment.DeviceType.TOUCH:
			return -1
		GFInputDeviceAssignment.DeviceType.JOYPAD:
			return event.device
		_:
			return event.device


func _normalize_device_id(
	device_type: GFInputDeviceAssignment.DeviceType,
	device_id: int
) -> int:
	match device_type:
		GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE:
			return 0
		GFInputDeviceAssignment.DeviceType.TOUCH:
			return -1
		_:
			return device_id


func _record_assignment_event(
	event_type: StringName,
	assignment: GFInputDeviceAssignment,
	previous_assignment: GFInputDeviceAssignment = null,
	reason: StringName = &"",
	source_event: InputEvent = null,
	event_metadata: Dictionary = {}
) -> void:
	var record: Dictionary = {
		"event_index": _next_assignment_event_index,
		"event_type": event_type,
		"reason": reason,
		"player_index": assignment.player_index if assignment != null else -1,
		"device_type": assignment.device_type if assignment != null else -1,
		"device_id": assignment.device_id if assignment != null else 0,
		"assignment": _assignment_to_dictionary(assignment),
		"previous_assignment": _assignment_to_dictionary(previous_assignment),
		"input_event": _input_event_to_dictionary(source_event),
		"metadata": event_metadata.duplicate(true),
	}
	_next_assignment_event_index += 1
	if max_assignment_events <= 0:
		assignment_event_recorded.emit(record.duplicate(true))
		return
	_assignment_events.append(record)
	_trim_assignment_events()
	assignment_event_recorded.emit(record.duplicate(true))


func _trim_assignment_events() -> void:
	if max_assignment_events <= 0:
		_assignment_events.clear()
		return
	while _assignment_events.size() > max_assignment_events:
		_assignment_events.pop_front()


func _assignment_to_dictionary(assignment: GFInputDeviceAssignment) -> Dictionary:
	if assignment == null:
		return {}
	return {
		"player_index": assignment.player_index,
		"device_type": assignment.device_type,
		"device_type_name": _device_type_to_text(assignment.device_type),
		"device_id": assignment.device_id,
		"metadata": assignment.metadata.duplicate(true),
	}


func _device_type_to_text(device_type: int) -> String:
	match device_type:
		GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE:
			return "keyboard_mouse"
		GFInputDeviceAssignment.DeviceType.JOYPAD:
			return "joypad"
		GFInputDeviceAssignment.DeviceType.TOUCH:
			return "touch"
		GFInputDeviceAssignment.DeviceType.AI:
			return "ai"
		GFInputDeviceAssignment.DeviceType.CUSTOM:
			return "custom"
		_:
			return "unknown"


func _input_event_to_dictionary(event: InputEvent) -> Dictionary:
	if event == null:
		return {}
	var result: Dictionary = {
		"class": event.get_class(),
		"device": event.device,
	}
	if event is InputEventKey:
		var key_event: InputEventKey = event
		result["pressed"] = key_event.pressed
		result["keycode"] = key_event.keycode
		result["physical_keycode"] = key_event.physical_keycode
	elif event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		result["pressed"] = mouse_button.pressed
		result["button_index"] = mouse_button.button_index
	elif event is InputEventJoypadButton:
		var joy_button: InputEventJoypadButton = event
		result["pressed"] = joy_button.pressed
		result["button_index"] = joy_button.button_index
	elif event is InputEventJoypadMotion:
		var joy_motion: InputEventJoypadMotion = event
		result["axis"] = joy_motion.axis
		result["axis_value"] = joy_motion.axis_value
	elif event is InputEventScreenTouch:
		var screen_touch: InputEventScreenTouch = event
		result["pressed"] = screen_touch.pressed
		result["index"] = screen_touch.index
	elif event is InputEventAction:
		var action_event: InputEventAction = event
		result["pressed"] = action_event.pressed
		result["action"] = action_event.action
	return result


func _find_first_empty_player_index() -> int:
	for player_index: int in range(max_players):
		if get_assignment(player_index) == null:
			return player_index
	return -1


func _is_event_active_enough_for_assignment(event: InputEvent) -> bool:
	var joy_motion: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(event)
	if joy_motion != null:
		return absf(joy_motion.axis_value) >= auto_assign_axis_threshold
	return _is_event_active_enough_for_active_player(event)


func _is_event_active_enough_for_active_player(event: InputEvent) -> bool:
	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(event)
	if key_event != null:
		return key_event.pressed

	var mouse_button: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(event)
	if mouse_button != null:
		return mouse_button.pressed

	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch != null:
		return screen_touch.pressed

	var joy_button: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(event)
	if joy_button != null:
		return joy_button.pressed

	var joy_motion: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(event)
	if joy_motion != null:
		return absf(joy_motion.axis_value) >= active_player_axis_threshold
	return true


func _event_matches_template(template: InputEvent, event: InputEvent) -> bool:
	if template == null or event == null:
		return false

	var template_action: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(template)
	var event_action: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(event)
	if template_action != null and event_action != null:
		return template_action.action == event_action.action and event_action.pressed

	return _is_event_active_enough_for_active_player(event) and template.is_match(event, true)


func _make_join_key_event(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event


func _make_join_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	event.pressure = 1.0
	return event


func _set_active_player(
	player_index: int,
	event: InputEvent = null,
	reason: StringName = &"input_event"
) -> void:
	if active_player_index == player_index:
		return
	active_player_index = player_index
	active_player_changed.emit(active_player_index)
	var assignment: GFInputDeviceAssignment = get_assignment(active_player_index)
	var event_copy: InputEvent = null
	if event != null:
		event_copy = _INPUT_EVENT_TOOLS.duplicate_input_event(event)
	_record_assignment_event(&"active_device_changed", assignment, null, reason, event)
	active_device_changed.emit(
		active_player_index,
		assignment.duplicate_assignment() if assignment != null else null,
		event_copy
	)


func _repair_active_player_after_assignments_changed(reason: StringName) -> void:
	if active_player_index >= 0 and get_assignment(active_player_index) != null:
		return
	_set_active_player(_find_first_assigned_player_index(), null, reason)


func _find_first_assigned_player_index() -> int:
	if _assignments.is_empty():
		return -1
	var first_player_index: int = _assignments[0].player_index
	for assignment: GFInputDeviceAssignment in _assignments:
		first_player_index = mini(first_player_index, assignment.player_index)
	return first_player_index


func _should_enforce_unique_device(assignment: GFInputDeviceAssignment) -> bool:
	if assignment == null:
		return false
	if assignment.device_type == GFInputDeviceAssignment.DeviceType.AI and assignment.device_id < 0:
		return false
	return true


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return

	var changed: bool = false
	for index: int in range(_assignments.size() - 1, -1, -1):
		var assignment: GFInputDeviceAssignment = _assignments[index]
		if (
			assignment.device_type == GFInputDeviceAssignment.DeviceType.JOYPAD
			and assignment.device_id == device
		):
			var removed_assignment: GFInputDeviceAssignment = assignment.duplicate_assignment()
			_assignments.remove_at(index)
			_record_assignment_event(&"assignment_removed", null, removed_assignment, &"device_disconnected")
			changed = true
	if changed:
		assignments_changed.emit(get_assignments())
		_repair_active_player_after_assignments_changed(&"device_disconnected")
