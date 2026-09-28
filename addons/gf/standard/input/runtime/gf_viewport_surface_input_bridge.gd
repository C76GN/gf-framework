## GFViewportSurfaceInputBridge: 将外部表面命中桥接为 Viewport 指针事件。
##
## 调用方只提供稳定 source/device/pointer 身份、目标 Viewport 代际、
## 0..1 标准化表面坐标和显式单调毫秒。桥不求解射线、UV、Mesh、XR 或交互模式；
## 也不复制 Pointer Activity、Gesture 或 DragDrop 的所有权。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 11.0.0
class_name GFViewportSurfaceInputBridge
extends RefCounted


# --- 信号 ---

## 一个经过校验的指针事件已推送到目标 Viewport 后发出。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_id: 输入源标识。
## [br]
## @param device_id: 设备标识。
## [br]
## @param pointer_id: 输入源内指针标识。
## [br]
## @param capture_generation: hover 为 0，捕获事件为桥分配的代际。
## [br]
## @param target_generation: Resolver 提供的目标代际。
## [br]
## @param target: 已接收事件的 Viewport。
## [br]
## @param event: 新创建的 Mouse 或 Touch 事件。
signal input_forwarded(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	capture_generation: int,
	target_generation: int,
	target: Viewport,
	event: InputEvent
)


# --- 枚举 ---

## 输出到 Viewport 的指针事件家族。
## [br]
## @api public
## [br]
## @since 11.0.0
enum PointerType {
	## `InputEventMouseButton` / `InputEventMouseMotion`。
	MOUSE,
	## `InputEventScreenTouch` / `InputEventScreenDrag`。
	TOUCH,
}


# --- 常量 ---

## 默认允许同时活动的指针捕获数量。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_ACTIVE_POINTERS: int = 32

## 活动指针捕获数的配置上限。
## [br]
## @api private
## [br]
const _MAX_ACTIVE_POINTERS_LIMIT: int = 256

## 默认保留的点击历史数量。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_CLICK_HISTORY: int = 64

## 点击历史数量的配置上限。
## [br]
## @api private
## [br]
const _MAX_CLICK_HISTORY_LIMIT: int = 512

## 默认保留的指针时间高水位数量。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_POINTER_TIMESTAMPS: int = 256

## 指针时间高水位数量的配置上限。
## [br]
## @api private
## [br]
const _MAX_POINTER_TIMESTAMPS_LIMIT: int = 4096

## 默认双击时间间隔上限，单位毫秒。
## [br]
## @api private
## [br]
const _DEFAULT_DOUBLE_CLICK_INTERVAL_MSEC: int = 500

## 双击时间间隔配置上限，单位毫秒。
## [br]
## @api private
## [br]
const _MAX_DOUBLE_CLICK_INTERVAL_MSEC: int = 60_000

## 默认双击距离上限，单位像素。
## [br]
## @api private
## [br]
const _DEFAULT_DOUBLE_CLICK_DISTANCE_PIXELS: float = 8.0

## 双击距离配置上限，单位像素。
## [br]
## @api private
## [br]
const _MAX_DOUBLE_CLICK_DISTANCE_PIXELS: float = 4096.0

## 输入源标识允许的最大字符数。
## [br]
## @api private
## [br]
const _MAX_SOURCE_ID_LENGTH: int = 128

## 设备和指针标识允许的最大非负值。
## [br]
## @api private
## [br]
const _MAX_INPUT_ID: int = 2_147_483_647

## 指针分发 epoch 的最大值，达到上限后从 1 重新开始。
## [br]
## @api private
## [br]
const _MAX_POINTER_EPOCH: int = 2_147_483_647

## 当前支持按位跟踪的非滚轮鼠标按钮。
## [br]
## @api private
## [br]
const _MOUSE_BUTTONS: Array[MouseButton] = [
	MOUSE_BUTTON_LEFT,
	MOUSE_BUTTON_RIGHT,
	MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_XBUTTON1,
	MOUSE_BUTTON_XBUTTON2,
]


# --- 私有变量 ---

## 同时允许存在的捕获记录数量上限。
## [br]
## @api private
## [br]
var _max_active_pointers: int = _DEFAULT_MAX_ACTIVE_POINTERS

## 点击历史记录数量上限；0 表示不保留双击历史。
## [br]
## @api private
## [br]
var _max_click_history: int = _DEFAULT_MAX_CLICK_HISTORY

## 跨捕获代际保留的指针时间高水位数量上限。
## [br]
## @api private
## [br]
var _max_pointer_timestamps: int = _DEFAULT_MAX_POINTER_TIMESTAMPS

## 双击时间窗口，单位毫秒。
## [br]
## @api private
## [br]
var _double_click_interval_msec: int = _DEFAULT_DOUBLE_CLICK_INTERVAL_MSEC

## 双击两次位置允许的最大距离，单位像素。
## [br]
## @api private
## [br]
var _double_click_distance_pixels: float = _DEFAULT_DOUBLE_CLICK_DISTANCE_PIXELS

## 指针复合键到活动捕获记录的映射。
## [br]
## @api private
## [br]
var _captures: Dictionary = {}

## 来源、设备、指针和按钮组合到最近点击记录的映射。
## [br]
## @api private
## [br]
var _click_history: Dictionary = {}

## 指针复合键到最近已接受单调时间戳的有界映射。
## [br]
## @api private
## [br]
var _pointer_timestamp_high_water: Dictionary = {}

## 指针复合键到当前分发 epoch 的映射。
## [br]
## @api private
## [br]
var _pointer_epochs: Dictionary = {}

## 正在同步分发的指针复合键到嵌套深度的映射。
## [br]
## @api private
## [br]
var _pointer_dispatch_depths: Dictionary = {}

## 下一个捕获回执使用的代际编号，从 1 起分配。
## [br]
## @api private
## [br]
var _next_capture_generation: int = 1

## 是否已经接受过输入；开始后不再允许修改限额。
## [br]
## @api private
## [br]
var _started: bool = false

## 是否已进入终态并禁止常规输入处理。
## [br]
## @api private
## [br]
var _disposed: bool = false


# --- 公共方法 ---

## 在首个样本前配置活动指针、跨代际时间与双击状态预算。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param max_active_pointers: 同时按下 key 上限，必须为 1..256。
## [br]
## @param max_click_history: 双击历史上限，0 禁用历史，最大 512。
## [br]
## @param double_click_interval_msec: 双击间隔，必须为 0..60000 毫秒。
## [br]
## @param double_click_distance_pixels: 在当前 Viewport 尺寸下的最大双击距离，必须有限且为 0..4096。
## [br]
## @param max_pointer_timestamps: 跨捕获代际保留的最近指针时间高水位数，必须为 1..4096。
## [br]
## @return: 尚未开始、未 dispose 且所有预算合法时返回 true。
func configure_limits(
	max_active_pointers: int = _DEFAULT_MAX_ACTIVE_POINTERS,
	max_click_history: int = _DEFAULT_MAX_CLICK_HISTORY,
	double_click_interval_msec: int = _DEFAULT_DOUBLE_CLICK_INTERVAL_MSEC,
	double_click_distance_pixels: float = _DEFAULT_DOUBLE_CLICK_DISTANCE_PIXELS,
	max_pointer_timestamps: int = _DEFAULT_MAX_POINTER_TIMESTAMPS
) -> bool:
	if (
		_started
		or _disposed
		or max_active_pointers < 1
		or max_active_pointers > _MAX_ACTIVE_POINTERS_LIMIT
		or max_click_history < 0
		or max_click_history > _MAX_CLICK_HISTORY_LIMIT
		or double_click_interval_msec < 0
		or double_click_interval_msec > _MAX_DOUBLE_CLICK_INTERVAL_MSEC
		or not _is_finite_scalar(double_click_distance_pixels)
		or double_click_distance_pixels < 0.0
		or double_click_distance_pixels > _MAX_DOUBLE_CLICK_DISTANCE_PIXELS
		or max_pointer_timestamps < 1
		or max_pointer_timestamps > _MAX_POINTER_TIMESTAMPS_LIMIT
	):
		return false
	_max_active_pointers = max_active_pointers
	_max_click_history = max_click_history
	_double_click_interval_msec = double_click_interval_msec
	_double_click_distance_pixels = double_click_distance_pixels
	_max_pointer_timestamps = max_pointer_timestamps
	return true


## 转发未按下鼠标在表面上的 hover motion。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_id: 稳定 Resolver/输入源标识。
## [br]
## @param device_id: 非负设备标识。
## [br]
## @param pointer_id: 输入源内非负指针标识。
## [br]
## @param target: 当前命中且已进入 SceneTree 的 Viewport。
## [br]
## @param target_generation: Resolver 提供的正整数目标代际。
## [br]
## @param normalized_position: 有限且两分量均为 0..1 的表面坐标。
## [br]
## @param timestamp_msec: 非负单调毫秒；不得早于该 key 仍在预算内的时间高水位。
## [br]
## @return: 输入合法、key 未捕获、时间未回退并已同步推送到目标时返回 true。
func forward_mouse_hover(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> bool:
	if not _can_accept_input() or not _surface_sample_is_valid(
		source_id,
		device_id,
		pointer_id,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	):
		return false
	var key: String = _make_pointer_key(source_id, device_id, pointer_id)
	if _captures.has(key) or not _pointer_timestamp_is_current(key, timestamp_msec):
		return false
	_started = true
	_remember_pointer_timestamp(key, timestamp_msec)
	var size: Vector2 = _get_target_size(target)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.device = device_id
	event.position = _uv_to_position(normalized_position, size)
	event.global_position = event.position
	event.button_mask = 0
	return _dispatch_event(
		source_id,
		device_id,
		pointer_id,
		0,
		target_generation,
		target,
		event
	)


## 按下指针并创建调用方必须保留的代际回执。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_id: 稳定 Resolver/输入源标识。
## [br]
## @param device_id: 非负设备标识。
## [br]
## @param pointer_id: 输入源内非负指针标识。
## [br]
## @param pointer_type: `PointerType.MOUSE` 或 `PointerType.TOUCH`。
## [br]
## @param target: 命中且已进入 SceneTree 的 Viewport。
## [br]
## @param target_generation: Resolver 提供的正整数目标代际。
## [br]
## @param normalized_position: 有限且两分量均为 0..1 的表面坐标。
## [br]
## @param timestamp_msec: 非负单调毫秒；不得早于该 key 仍在预算内的时间高水位。
## [br]
## @param mouse_button: 鼠标捕获的首个非滚轮按钮；Touch 时忽略。
## [br]
## @return: 成功时返回新回执；时间未回退的重复同状态 press 更新最后样本并返回现有回执；失败返回 null。
func capture_pointer(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	pointer_type: PointerType,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int,
	mouse_button: MouseButton = MOUSE_BUTTON_LEFT
) -> GFViewportSurfaceInputCapture:
	if not _can_accept_input() or not _surface_sample_is_valid(
		source_id,
		device_id,
		pointer_id,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	):
		return null
	if pointer_type not in [PointerType.MOUSE, PointerType.TOUCH]:
		return null
	if pointer_type == PointerType.MOUSE and not _mouse_button_is_supported(mouse_button):
		return null
	var key: String = _make_pointer_key(source_id, device_id, pointer_id)
	if not _pointer_timestamp_is_current(key, timestamp_msec):
		return null

	_started = true
	var _pruned: int = _prune_dead_records(timestamp_msec)
	if not _can_accept_input() or not _surface_sample_is_valid(
		source_id,
		device_id,
		pointer_id,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	):
		return null
	if not _pointer_timestamp_is_current(key, timestamp_msec):
		return null
	var existing: CaptureRecord = _get_capture_record(key)
	if existing != null:
		var existing_receipt: GFViewportSurfaceInputCapture = _get_receipt(existing)
		if (
			existing_receipt != null
			and existing.pointer_type == pointer_type
			and existing.target_instance_id == target.get_instance_id()
			and existing.target_generation == target_generation
			and timestamp_msec >= existing.last_timestamp_msec
			and (
				pointer_type == PointerType.TOUCH
				or existing.button_mask & _mouse_button_bit(mouse_button) != 0
			)
		):
			existing.last_uv = normalized_position
			existing.last_timestamp_msec = timestamp_msec
			_remember_pointer_timestamp(key, timestamp_msec)
			return existing_receipt
		return null
	if _captures.size() >= _max_active_pointers:
		return null

	var capture_generation: int = _take_capture_generation()
	var receipt: GFViewportSurfaceInputCapture = GFViewportSurfaceInputCapture.new()
	var configured: bool = receipt.configure_from_input_layer(
		get_instance_id(),
		source_id,
		device_id,
		pointer_id,
		pointer_type,
		capture_generation,
		target_generation
	)
	if not configured:
		return null

	var record: CaptureRecord = CaptureRecord.new()
	record.key = key
	record.source_id = source_id
	record.device_id = device_id
	record.pointer_id = pointer_id
	record.pointer_type = pointer_type
	record.capture_generation = capture_generation
	record.target_generation = target_generation
	record.target_instance_id = target.get_instance_id()
	record.target_ref = weakref(target)
	record.receipt_ref = weakref(receipt)
	record.last_uv = normalized_position
	record.last_timestamp_msec = timestamp_msec
	record.button_mask = _mouse_button_bit(mouse_button) if pointer_type == PointerType.MOUSE else 1
	_captures[key] = record
	_remember_pointer_timestamp(key, timestamp_msec)
	_advance_pointer_epoch(key)

	var double_click: bool = _is_double_click(record, mouse_button, timestamp_msec)
	var event: InputEvent = _make_press_event(record, target, mouse_button, double_click)
	var dispatch_epoch: int = _get_pointer_epoch(key)
	if event == null or not _dispatch_record_event(record, target, event):
		if _get_capture_record(key) == record and _get_pointer_epoch(key) == dispatch_epoch:
			var _erased_failed_capture: bool = _captures.erase(key)
			_advance_pointer_epoch(key)
			_prune_pointer_epoch(key)
		return null
	return receipt


## 在捕获目标内移动指针。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 按下时返回的原始回执。
## [br]
## @param target: 当前命中 Viewport，必须与回执捕获目标相同。
## [br]
## @param target_generation: 必须与按下时目标代际相同。
## [br]
## @param normalized_position: 新的有限 0..1 表面坐标。
## [br]
## @param timestamp_msec: 不得早于该捕获上一样本的单调毫秒。
## [br]
## @return: 回执、目标、代际、坐标和时间都合法时返回 true。
func move_pointer(
	capture: GFViewportSurfaceInputCapture,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> bool:
	var record: CaptureRecord = _get_live_surface_record(
		capture,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	)
	if record == null:
		return false
	var size: Vector2 = _get_target_size(target)
	var previous_position: Vector2 = _uv_to_position(record.last_uv, size)
	var position: Vector2 = _uv_to_position(normalized_position, size)
	record.last_uv = normalized_position
	record.last_timestamp_msec = timestamp_msec
	_remember_pointer_timestamp(record.key, timestamp_msec)
	_advance_pointer_epoch(record.key)
	var event: InputEvent = _make_motion_event(record, position, position - previous_position)
	return event != null and _dispatch_record_event(record, target, event)


## 在已捕获鼠标上增加一个非滚轮按钮。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 活动鼠标捕获回执。
## [br]
## @param target: 与捕获相同的当前 Viewport。
## [br]
## @param target_generation: 捕获的外部目标代际。
## [br]
## @param normalized_position: 有限 0..1 表面坐标。
## [br]
## @param timestamp_msec: 非回退单调毫秒。
## [br]
## @param mouse_button: 待按下的非滚轮按钮。
## [br]
## @return: 新按钮已推送或该按钮已处于按下状态时返回 true。
func press_mouse_button(
	capture: GFViewportSurfaceInputCapture,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int,
	mouse_button: MouseButton
) -> bool:
	if not _mouse_button_is_supported(mouse_button):
		return false
	var record: CaptureRecord = _get_live_surface_record(
		capture,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	)
	if record == null or record.pointer_type != PointerType.MOUSE:
		return false
	var bit: int = _mouse_button_bit(mouse_button)
	if record.button_mask & bit != 0:
		record.last_uv = normalized_position
		record.last_timestamp_msec = timestamp_msec
		_remember_pointer_timestamp(record.key, timestamp_msec)
		return true
	record.last_uv = normalized_position
	record.last_timestamp_msec = timestamp_msec
	_remember_pointer_timestamp(record.key, timestamp_msec)
	record.button_mask |= bit
	_advance_pointer_epoch(record.key)
	var event: InputEventMouseButton = _make_mouse_button_event(
		record,
		target,
		mouse_button,
		true,
		_is_double_click(record, mouse_button, timestamp_msec),
		false
	)
	return _dispatch_record_event(record, target, event)


## 在最后一个合法表面位置释放指针或鼠标按钮。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 活动捕获回执。
## [br]
## @param timestamp_msec: 非回退单调毫秒。
## [br]
## @param mouse_button: 鼠标待释放的受支持非滚轮按钮；Touch 时忽略。
## [br]
## @return: 回执仍为当前代际，且按钮已释放或已处于释放状态时返回 true；不支持的鼠标按钮返回 false。
func release_pointer(
	capture: GFViewportSurfaceInputCapture,
	timestamp_msec: int,
	mouse_button: MouseButton = MOUSE_BUTTON_LEFT
) -> bool:
	var record: CaptureRecord = _get_record_for_receipt(capture, timestamp_msec)
	if record == null:
		return false
	return _release_record(record, capture, timestamp_msec, mouse_button)


## 更新最后合法表面位置后释放指针或鼠标按钮。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 活动捕获回执。
## [br]
## @param target: 与捕获相同的当前 Viewport。
## [br]
## @param target_generation: 捕获的外部目标代际。
## [br]
## @param normalized_position: 终止时有限 0..1 表面坐标。
## [br]
## @param timestamp_msec: 非回退单调毫秒。
## [br]
## @param mouse_button: 鼠标待释放的受支持非滚轮按钮；Touch 时忽略。
## [br]
## @return: 位置与捕获身份合法，且按钮已释放或已处于释放状态时返回 true；不支持的鼠标按钮返回 false。
func release_pointer_on_surface(
	capture: GFViewportSurfaceInputCapture,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int,
	mouse_button: MouseButton = MOUSE_BUTTON_LEFT
) -> bool:
	var record: CaptureRecord = _get_live_surface_record(
		capture,
		target,
		target_generation,
		normalized_position,
		timestamp_msec
	)
	if record == null:
		return false
	if record.pointer_type == PointerType.MOUSE:
		var bit: int = _mouse_button_bit(mouse_button)
		if bit == 0:
			return false
	record.last_uv = normalized_position
	record.last_timestamp_msec = timestamp_msec
	return _release_record(record, capture, timestamp_msec, mouse_button)


## 在最后合法位置取消整个指针捕获。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 活动捕获回执。
## [br]
## @param timestamp_msec: 非回退单调毫秒。
## [br]
## @return: 回执匹配当前代际且捕获已清理时返回 true。
func cancel_pointer(capture: GFViewportSurfaceInputCapture, timestamp_msec: int) -> bool:
	var record: CaptureRecord = _get_record_for_receipt(capture, timestamp_msec)
	if record == null:
		return false
	return _cancel_record(record, timestamp_msec)


## 取消指定输入源的全部捕获，并清除调用前已结束指针的双击与时间状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param source_id: 待清理的输入源标识。
## [br]
## @param timestamp_msec: 终止样本单调毫秒，早于捕获最新样本时自动使用最新值。
## [br]
## @param device_id: -1 表示该 source 的全部设备，否则只清理指定非负设备。
## [br]
## @return: 本次移除的捕获数。
func cancel_source(
	source_id: StringName,
	timestamp_msec: int,
	device_id: int = -1
) -> int:
	if not _can_accept_input() or source_id == &"" or timestamp_msec < 0 or device_id < -1:
		return 0
	_remove_completed_source_lifecycle_state(source_id, device_id)
	var removed: int = 0
	for record: CaptureRecord in _get_capture_snapshot():
		if _get_capture_record(record.key) != record or record.source_id != source_id:
			continue
		if device_id >= 0 and record.device_id != device_id:
			continue
		var epoch_before_cancel: int = _begin_pointer_dispatch(record.key)
		var expected_cancel_epoch: int = _next_pointer_epoch_value(epoch_before_cancel)
		var _cancelled: bool = _cancel_record(record, maxi(timestamp_msec, record.last_timestamp_msec))
		if (
			not _captures.has(record.key)
			and not _pointer_has_click_history(record.key)
			and _get_pointer_epoch(record.key) == expected_cancel_epoch
		):
			var _erased_timestamp: bool = _pointer_timestamp_high_water.erase(record.key)
		_end_pointer_dispatch(record.key)
		removed += 1
	return removed


## 取消指定 Viewport 外部代际的全部捕获。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param target: 待失效的 Viewport。
## [br]
## @param target_generation: 只清理与该正整数外部代际完全匹配的捕获。
## [br]
## @param timestamp_msec: 终止样本单调毫秒。
## [br]
## @return: 本次移除的捕获数。
func cancel_target(target: Viewport, target_generation: int, timestamp_msec: int) -> int:
	if (
		not _can_accept_input()
		or target == null
		or not is_instance_valid(target)
		or target_generation <= 0
		or timestamp_msec < 0
	):
		return 0
	var target_instance_id: int = target.get_instance_id()
	var removed: int = 0
	for record: CaptureRecord in _get_capture_snapshot():
		if (
			_get_capture_record(record.key) != record
			or record.target_instance_id != target_instance_id
			or record.target_generation != target_generation
		):
			continue
		var _cancelled: bool = _cancel_record(record, maxi(timestamp_msec, record.last_timestamp_msec))
		removed += 1
	return removed


## 清理回执、目标或 SceneTree 生命周期已结束的捕获。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param timestamp_msec: 活目标补发 cancel 时的单调毫秒。
## [br]
## @return: 本次移除的捕获数。
func prune_released_captures(timestamp_msec: int = 0) -> int:
	if not _can_accept_input() or timestamp_msec < 0:
		return 0
	return _prune_dead_records(timestamp_msec)


## 检查回执是否仍指向当前活动捕获。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param capture: 待检查回执。
## [br]
## @return: 桥、key、代际、回执对象和弱目标均仍匹配时返回 true。
func has_capture(capture: GFViewportSurfaceInputCapture) -> bool:
	var record: CaptureRecord = _get_record_for_receipt(capture, -1, false)
	return record != null and _get_live_target(record) != null


## 获取当前活动指针 key 数。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 不超过配置预算的捕获数。
func get_active_pointer_count() -> int:
	return _captures.size()


## 获取当前双击历史数。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 不超过配置预算的历史条目数。
func get_click_history_count() -> int:
	return _click_history.size()


## 获取当前跨代际指针时间高水位数。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 不超过配置预算的最近指针 key 数。
func get_pointer_timestamp_count() -> int:
	return _pointer_timestamp_high_water.size()


## 检查桥是否已进入不可复用终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: [method dispose] 已调用时返回 true。
func is_disposed() -> bool:
	return _disposed


## 取消所有活动捕获并清空有界历史。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param timestamp_msec: 终止样本单调毫秒；负数视为 0。
func dispose(timestamp_msec: int = 0) -> void:
	if _disposed:
		return
	_disposed = true
	if Thread.is_main_thread():
		for record: CaptureRecord in _get_capture_snapshot():
			if _get_capture_record(record.key) == record:
				var _cancelled: bool = _cancel_record(
					record,
					maxi(maxi(timestamp_msec, 0), record.last_timestamp_msec),
					true
				)
	_captures.clear()
	_click_history.clear()
	_pointer_timestamp_high_water.clear()
	for pointer_key_variant: Variant in _pointer_epochs.keys():
		if pointer_key_variant is String:
			var pointer_key: String = pointer_key_variant
			_prune_pointer_epoch(pointer_key)


# --- 私有/辅助方法 ---

## 仅在线程为主线程且尚未 dispose 时允许处理输入。
## [br]
## @api private
## [br]
func _can_accept_input() -> bool:
	return not _disposed and Thread.is_main_thread()


## 校验来源标识、设备和指针范围、目标代际、时间戳、存活目标及标准化坐标。
## [br]
## @api private
## [br]
func _surface_sample_is_valid(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> bool:
	return (
		source_id != &""
		and String(source_id).length() <= _MAX_SOURCE_ID_LENGTH
		and device_id >= 0
		and device_id <= _MAX_INPUT_ID
		and pointer_id >= 0
		and pointer_id <= _MAX_INPUT_ID
		and target_generation > 0
		and timestamp_msec >= 0
		and _target_is_live(target)
		and _normalized_position_is_valid(normalized_position)
		and _get_target_size(target) != Vector2.ZERO
	)


## 按回执取得当前捕获，并确认目标实例、目标代际、坐标和目标尺寸仍有效。
## [br]
## @api private
## [br]
func _get_live_surface_record(
	capture: GFViewportSurfaceInputCapture,
	target: Viewport,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> CaptureRecord:
	var record: CaptureRecord = _get_record_for_receipt(capture, timestamp_msec)
	if (
		record == null
		or target == null
		or not _target_is_live(target)
		or record.target_instance_id != target.get_instance_id()
		or record.target_generation != target_generation
		or not _normalized_position_is_valid(normalized_position)
		or _get_target_size(target) == Vector2.ZERO
	):
		return null
	return record


## 验证回执有效且属于本桥后，按其身份构造键并匹配当前记录；可选检查非回退时间戳。
## [br]
## @api private
## [br]
func _get_record_for_receipt(
	capture: GFViewportSurfaceInputCapture,
	timestamp_msec: int,
	validate_time: bool = true
) -> CaptureRecord:
	if not _can_accept_input() or capture == null or not capture.is_valid():
		return null
	if not capture.belongs_to_bridge_from_input_layer(get_instance_id()):
		return null
	var key: String = _make_pointer_key(
		capture.get_source_id(),
		capture.get_device_id(),
		capture.get_pointer_id()
	)
	var record: CaptureRecord = _get_capture_record(key)
	if not _record_matches_receipt(record, capture):
		return null
	if validate_time and (timestamp_msec < 0 or timestamp_msec < record.last_timestamp_msec):
		return null
	return record


## 比较当前记录保存的回执对象及捕获代际、目标代际、来源、设备、指针和类型。
## [br]
## @api private
## [br]
func _record_matches_receipt(
	record: CaptureRecord,
	receipt: GFViewportSurfaceInputCapture
) -> bool:
	if record == null or receipt == null:
		return false
	var current_receipt: GFViewportSurfaceInputCapture = _get_receipt(record)
	return (
		current_receipt == receipt
		and record.capture_generation == receipt.get_capture_generation()
		and record.target_generation == receipt.get_target_generation()
		and record.source_id == receipt.get_source_id()
		and record.device_id == receipt.get_device_id()
		and record.pointer_id == receipt.get_pointer_id()
		and record.pointer_type == receipt.get_pointer_type()
	)


## 释放触摸捕获或指定鼠标按钮；更新高水位与点击记录后推送释放事件，并按回执状态决定是否完成。
## 目标失效时丢弃记录；鼠标按钮已释放时只更新时间并返回 true。
## [br]
## @api private
## [br]
func _release_record(
	record: CaptureRecord,
	receipt: GFViewportSurfaceInputCapture,
	timestamp_msec: int,
	mouse_button: MouseButton
) -> bool:
	if record == null or _get_capture_record(record.key) != record:
		return false
	var target: Viewport = _get_live_target(record)
	if target == null or _get_target_size(target) == Vector2.ZERO:
		_drop_record(record)
		return false
	if record.pointer_type == PointerType.TOUCH:
		var _erased_touch_capture: bool = _captures.erase(record.key)
		record.last_timestamp_msec = timestamp_msec
		_remember_pointer_timestamp(record.key, timestamp_msec)
		_remember_click(record, 0, timestamp_msec)
		_advance_pointer_epoch(record.key)
		var touch_event: InputEventScreenTouch = _make_touch_event(record, target, false, false, false)
		var delivered_touch: bool = _dispatch_record_event(record, target, touch_event)
		_prune_pointer_epoch(record.key)
		return delivered_touch
	if record.pointer_type != PointerType.MOUSE or not _mouse_button_is_supported(mouse_button):
		return false
	var bit: int = _mouse_button_bit(mouse_button)
	if record.button_mask & bit == 0:
		record.last_timestamp_msec = timestamp_msec
		_remember_pointer_timestamp(record.key, timestamp_msec)
		return true
	record.button_mask &= ~bit
	record.last_timestamp_msec = timestamp_msec
	_remember_pointer_timestamp(record.key, timestamp_msec)
	_remember_click(record, mouse_button, timestamp_msec)
	if record.button_mask == 0:
		var _erased_capture: bool = _captures.erase(record.key)
	_advance_pointer_epoch(record.key)
	var mouse_event: InputEventMouseButton = _make_mouse_button_event(
		record,
		target,
		mouse_button,
		false,
		false,
		false
	)
	var delivered: bool = _dispatch_record_event(record, target, mouse_event)
	var completed: bool = delivered and (
		record.button_mask != 0
		or not _record_matches_receipt(_get_capture_record(record.key), receipt)
	)
	_prune_pointer_epoch(record.key)
	return completed


## 移除捕获和点击历史并记录终止时间；目标有效时发送触摸取消或逐个发送当前按下按钮的取消释放。
## [br]
## @api private
## [br]
func _cancel_record(
	record: CaptureRecord,
	timestamp_msec: int,
	allow_disposed_dispatch: bool = false
) -> bool:
	if record == null or _get_capture_record(record.key) != record:
		return false
	var target: Viewport = _get_live_target(record)
	var original_mask: int = record.button_mask
	var _erased_capture: bool = _captures.erase(record.key)
	_remove_click_history_for_pointer(record.source_id, record.device_id, record.pointer_id)
	_advance_pointer_epoch(record.key)
	record.last_timestamp_msec = maxi(timestamp_msec, record.last_timestamp_msec)
	_remember_pointer_timestamp(record.key, record.last_timestamp_msec)
	if target == null or _get_target_size(target) == Vector2.ZERO:
		_prune_pointer_epoch(record.key)
		return false
	if record.pointer_type == PointerType.TOUCH:
		var touch_event: InputEventScreenTouch = _make_touch_event(record, target, false, false, true)
		var delivered_touch: bool = _dispatch_record_event(
			record,
			target,
			touch_event,
			allow_disposed_dispatch
		)
		_prune_pointer_epoch(record.key)
		return delivered_touch
	var delivered_any: bool = false
	var remaining_mask: int = original_mask
	for mouse_button: MouseButton in _MOUSE_BUTTONS:
		var bit: int = _mouse_button_bit(mouse_button)
		if remaining_mask & bit == 0:
			continue
		remaining_mask &= ~bit
		record.button_mask = remaining_mask
		var event: InputEventMouseButton = _make_mouse_button_event(
			record,
			target,
			mouse_button,
			false,
			false,
			true
		)
		if not _dispatch_record_event(record, target, event, allow_disposed_dispatch):
			_prune_pointer_epoch(record.key)
			return false
		delivered_any = true
	_prune_pointer_epoch(record.key)
	return delivered_any


## 仅当记录仍是当前捕获时删除捕获和点击历史，保留其时间高水位并推进 epoch。
## [br]
## @api private
## [br]
func _drop_record(record: CaptureRecord) -> void:
	if record == null or _get_capture_record(record.key) != record:
		return
	var _erased_capture: bool = _captures.erase(record.key)
	_remove_click_history_for_pointer(record.source_id, record.device_id, record.pointer_id)
	_remember_pointer_timestamp(record.key, record.last_timestamp_msec)
	_advance_pointer_epoch(record.key)
	_prune_pointer_epoch(record.key)


## 遍历捕获表快照并清理无效值、目标仍存活但回执失效的捕获，或目标已失效的记录。
## 仅在表中记录仍等于快照值时处理，返回本次移除的记录数。
## [br]
## @api private
## [br]
func _prune_dead_records(timestamp_msec: int) -> int:
	var removed: int = 0
	var capture_snapshot: Dictionary = _captures.duplicate()
	for key_variant: Variant in capture_snapshot.keys():
		if not key_variant is String:
			continue
		var key: String = key_variant
		var snapshot_value: Variant = capture_snapshot.get(key)
		if _captures.get(key) != snapshot_value:
			continue
		var record: CaptureRecord = snapshot_value if snapshot_value is CaptureRecord else null
		if record == null:
			var _erased_invalid: bool = _captures.erase(key)
			_advance_pointer_epoch(key)
			_prune_pointer_epoch(key)
			removed += 1
			continue
		var target: Viewport = _get_live_target(record)
		if target != null and _get_receipt(record) != null:
			continue
		if target != null:
			var _cancelled: bool = _cancel_record(record, maxi(timestamp_msec, record.last_timestamp_msec))
		else:
			_drop_record(record)
		removed += 1
	return removed


## 从捕获字典值中收集 CaptureRecord 类型的记录。
## [br]
## @api private
## [br]
func _get_capture_snapshot() -> Array[CaptureRecord]:
	var snapshot: Array[CaptureRecord] = []
	for value: Variant in _captures.values():
		if value is CaptureRecord:
			snapshot.append(value)
	return snapshot


## 按记录类型创建鼠标按钮或触摸按下事件；不支持的指针类型返回 null。
## [br]
## @api private
## [br]
func _make_press_event(
	record: CaptureRecord,
	target: Viewport,
	mouse_button: MouseButton,
	double_click: bool
) -> InputEvent:
	if record.pointer_type == PointerType.MOUSE:
		return _make_mouse_button_event(record, target, mouse_button, true, double_click, false)
	if record.pointer_type == PointerType.TOUCH:
		return _make_touch_event(record, target, true, double_click, false)
	return null


## 按记录类型创建鼠标移动或触摸拖动事件，并设置位置、相对位移及按钮状态。
## [br]
## @api private
## [br]
func _make_motion_event(
	record: CaptureRecord,
	position: Vector2,
	relative: Vector2
) -> InputEvent:
	if record.pointer_type == PointerType.MOUSE:
		var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
		mouse_event.device = record.device_id
		mouse_event.position = position
		mouse_event.global_position = position
		mouse_event.relative = relative
		mouse_event.button_mask = record.button_mask
		return mouse_event
	if record.pointer_type == PointerType.TOUCH:
		var touch_event: InputEventScreenDrag = InputEventScreenDrag.new()
		touch_event.device = record.device_id
		touch_event.index = record.pointer_id
		touch_event.position = position
		touch_event.relative = relative
		return touch_event
	return null


## 根据捕获记录和最近表面坐标创建鼠标按钮事件，填入按钮掩码、按下、双击及取消标志。
## [br]
## @api private
## [br]
func _make_mouse_button_event(
	record: CaptureRecord,
	target: Viewport,
	mouse_button: MouseButton,
	pressed: bool,
	double_click: bool,
	canceled: bool
) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	var position: Vector2 = _uv_to_position(record.last_uv, _get_target_size(target))
	event.device = record.device_id
	event.position = position
	event.global_position = position
	event.button_index = mouse_button
	event.button_mask = record.button_mask
	event.pressed = pressed
	event.double_click = double_click
	event.canceled = canceled
	return event


## 根据捕获记录和最近表面坐标创建屏幕触摸事件，填入触摸索引及按下、双击、取消标志。
## [br]
## @api private
## [br]
func _make_touch_event(
	record: CaptureRecord,
	target: Viewport,
	pressed: bool,
	double_tap: bool,
	canceled: bool
) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.device = record.device_id
	event.index = record.pointer_id
	event.position = _uv_to_position(record.last_uv, _get_target_size(target))
	event.pressed = pressed
	event.double_tap = double_tap
	event.canceled = canceled
	return event


## 将捕获记录中的来源、设备、指针和代际信息传给通用分发，并要求记录状态仍符合预期。
## [br]
## @api private
## [br]
func _dispatch_record_event(
	record: CaptureRecord,
	target: Viewport,
	event: InputEvent,
	allow_disposed_dispatch: bool = false
) -> bool:
	var expect_active_record: bool = _get_capture_record(record.key) == record
	return _dispatch_event(
		record.source_id,
		record.device_id,
		record.pointer_id,
		record.capture_generation,
		record.target_generation,
		target,
		event,
		record,
		expect_active_record,
		allow_disposed_dispatch
	)


## 在主线程向存活 Viewport 推送事件，并在推送和 input_forwarded 信号回调后重新检查指针 epoch 与捕获状态。
## [br]
## @api private
## [br]
func _dispatch_event(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	capture_generation: int,
	target_generation: int,
	target: Viewport,
	event: InputEvent,
	expected_record: CaptureRecord = null,
	expect_active_record: bool = false,
	allow_disposed_dispatch: bool = false
) -> bool:
	if not Thread.is_main_thread() or not _target_is_live(target) or event == null:
		return false
	var pointer_key: String = _make_pointer_key(source_id, device_id, pointer_id)
	var expected_epoch: int = _begin_pointer_dispatch(pointer_key)
	target.push_input(event, true)
	var completed: bool = _dispatch_expectation_holds(
		expected_record,
		expect_active_record,
		target,
		pointer_key,
		expected_epoch,
		allow_disposed_dispatch
	)
	if completed:
		input_forwarded.emit(
			source_id,
			device_id,
			pointer_id,
			capture_generation,
			target_generation,
			target,
			event
		)
		completed = _dispatch_expectation_holds(
			expected_record,
			expect_active_record,
			target,
			pointer_key,
			expected_epoch,
			allow_disposed_dispatch
		)
	_end_pointer_dispatch(pointer_key)
	return completed


## 检查 dispose、目标存活和指针 epoch；若有预期记录，还核对其仍活动或已被移除。
## [br]
## @api private
## [br]
func _dispatch_expectation_holds(
	expected_record: CaptureRecord,
	expect_active_record: bool,
	target: Viewport,
	pointer_key: String,
	expected_epoch: int,
	allow_disposed_dispatch: bool
) -> bool:
	if (
		(_disposed and not allow_disposed_dispatch)
		or not _target_is_live(target)
		or _get_pointer_epoch(pointer_key) != expected_epoch
	):
		return false
	if expected_record == null:
		return true
	var current_record: CaptureRecord = _get_capture_record(expected_record.key)
	if expect_active_record:
		return (
			current_record == expected_record
			and current_record.capture_generation == expected_record.capture_generation
		)
	return current_record == null


## 增加指定指针的同步分发深度，必要时初始化 epoch，并返回当前 epoch。
## [br]
## @api private
## [br]
func _begin_pointer_dispatch(pointer_key: String) -> int:
	var depth_value: Variant = _pointer_dispatch_depths.get(pointer_key, 0)
	var depth: int = depth_value if depth_value is int else 0
	_pointer_dispatch_depths[pointer_key] = depth + 1
	if not _pointer_epochs.has(pointer_key):
		_pointer_epochs[pointer_key] = 0
	return _get_pointer_epoch(pointer_key)


## 减少或移除指针分发深度，然后尝试清理不再被状态引用的 epoch。
## [br]
## @api private
## [br]
func _end_pointer_dispatch(pointer_key: String) -> void:
	var depth_value: Variant = _pointer_dispatch_depths.get(pointer_key, 0)
	var depth: int = depth_value if depth_value is int else 0
	if depth <= 1:
		var _erased_depth: bool = _pointer_dispatch_depths.erase(pointer_key)
	else:
		_pointer_dispatch_depths[pointer_key] = depth - 1
	_prune_pointer_epoch(pointer_key)


## 按 epoch 递增规则推进指定指针的分发代际。
## [br]
## @api private
## [br]
func _advance_pointer_epoch(pointer_key: String) -> void:
	var current: int = _get_pointer_epoch(pointer_key)
	_pointer_epochs[pointer_key] = _next_pointer_epoch_value(current)


## 计算下一个 epoch；达到配置上限时回到 1。
## [br]
## @api private
## [br]
static func _next_pointer_epoch_value(current: int) -> int:
	return 1 if current >= _MAX_POINTER_EPOCH else current + 1


## 读取指针 epoch；缺失或存储值类型不符时返回 0。
## [br]
## @api private
## [br]
func _get_pointer_epoch(pointer_key: String) -> int:
	var value: Variant = _pointer_epochs.get(pointer_key, 0)
	return value if value is int else 0


## 仅当指针没有活动分发、捕获或点击历史时从 epoch 字典移除其状态。
## [br]
## @api private
## [br]
func _prune_pointer_epoch(pointer_key: String) -> void:
	if (
		_pointer_dispatch_depths.has(pointer_key)
		or _captures.has(pointer_key)
		or _pointer_has_click_history(pointer_key)
	):
		return
	var _erased_epoch: bool = _pointer_epochs.erase(pointer_key)


## 检查点击历史是否包含以该指针复合键加分隔符为前缀的记录。
## [br]
## @api private
## [br]
func _pointer_has_click_history(pointer_key: String) -> bool:
	var click_prefix: String = pointer_key + ":"
	for click_key_variant: Variant in _click_history.keys():
		if click_key_variant is String:
			var click_key: String = click_key_variant
			if click_key.begins_with(click_prefix):
				return true
	return false


## 时间高水位存在时只接受不早于它的毫秒值；未记录过该指针时接受。
## [br]
## @api private
## [br]
func _pointer_timestamp_is_current(pointer_key: String, timestamp_msec: int) -> bool:
	var value: Variant = _pointer_timestamp_high_water.get(pointer_key)
	if value is int:
		var high_water_timestamp_msec: int = value
		return timestamp_msec >= high_water_timestamp_msec
	return true


## 只接受不早于现有高水位的时间戳，并将键重新插入末端；超出预算时从字典首端淘汰。
## [br]
## @api private
## [br]
func _remember_pointer_timestamp(pointer_key: String, timestamp_msec: int) -> void:
	var value: Variant = _pointer_timestamp_high_water.get(pointer_key)
	if value is int:
		var high_water_timestamp_msec: int = value
		if timestamp_msec < high_water_timestamp_msec:
			return
	var _erased_existing: bool = _pointer_timestamp_high_water.erase(pointer_key)
	_pointer_timestamp_high_water[pointer_key] = timestamp_msec
	while _pointer_timestamp_high_water.size() > _max_pointer_timestamps:
		var keys: Array = _pointer_timestamp_high_water.keys()
		if keys.is_empty():
			break
		var _erased_oldest: bool = _pointer_timestamp_high_water.erase(keys[0])


## 在点击历史启用且目标存活时保存来源、目标代际、位置和时间，并按预算淘汰最早插入项。
## 触点使用按钮键 0；记录变更会推进相应指针 epoch。
## [br]
## @api private
## [br]
func _remember_click(record: CaptureRecord, mouse_button: int, timestamp_msec: int) -> void:
	if _max_click_history == 0:
		return
	var target: Viewport = _get_live_target(record)
	if target == null:
		return
	var click_key: String = _make_click_key(
		record.source_id,
		record.device_id,
		record.pointer_id,
		mouse_button
	)
	var click: ClickRecord = ClickRecord.new()
	click.source_id = record.source_id
	click.device_id = record.device_id
	click.pointer_id = record.pointer_id
	click.mouse_button = mouse_button
	click.target_generation = record.target_generation
	click.target_instance_id = record.target_instance_id
	click.target_ref = weakref(target)
	click.normalized_position = record.last_uv
	click.timestamp_msec = timestamp_msec
	var _erased_previous: bool = _click_history.erase(click_key)
	_click_history[click_key] = click
	_advance_pointer_epoch(record.key)
	while _click_history.size() > _max_click_history:
		var keys: Array = _click_history.keys()
		if keys.is_empty():
			break
		var oldest_key_value: Variant = keys[0]
		var oldest_click: ClickRecord = null
		if oldest_key_value is String:
			var oldest_key: String = oldest_key_value
			oldest_click = _get_click_record(oldest_key)
		var _erased_oldest: bool = _click_history.erase(oldest_key_value)
		if oldest_click != null:
			var oldest_pointer_key: String = _make_pointer_key(
				oldest_click.source_id,
				oldest_click.device_id,
				oldest_click.pointer_id
			)
			_prune_pointer_epoch(oldest_pointer_key)


## 检查同来源设备、指针和按钮是否有同一目标代际内的前次点击，且间隔和当前像素距离均在配置范围内。
## [br]
## @api private
## [br]
func _is_double_click(
	record: CaptureRecord,
	mouse_button: int,
	timestamp_msec: int
) -> bool:
	if _max_click_history == 0:
		return false
	var click: ClickRecord = _get_click_record(_make_click_key(
		record.source_id,
		record.device_id,
		record.pointer_id,
		mouse_button if record.pointer_type == PointerType.MOUSE else 0
	))
	if (
		click == null
		or click.target_instance_id != record.target_instance_id
		or click.target_generation != record.target_generation
		or timestamp_msec < click.timestamp_msec
		or timestamp_msec - click.timestamp_msec > _double_click_interval_msec
	):
		return false
	var target: Viewport = _get_live_target(record)
	var click_target: Viewport = _get_click_target(click)
	if target == null or click_target != target:
		return false
	var size: Vector2 = _get_target_size(target)
	return (
		_uv_to_position(click.normalized_position, size).distance_to(
			_uv_to_position(record.last_uv, size)
		)
		<= _double_click_distance_pixels
	)


## 删除与来源、设备和指针标识完全匹配的全部点击历史记录。
## [br]
## @api private
## [br]
func _remove_click_history_for_pointer(
	source_id: StringName,
	device_id: int,
	pointer_id: int
) -> void:
	for key_variant: Variant in _click_history.keys():
		if not key_variant is String:
			continue
		var key: String = key_variant
		var click: ClickRecord = _get_click_record(key)
		if (
			click != null
			and click.source_id == source_id
			and click.device_id == device_id
			and click.pointer_id == pointer_id
		):
			var _erased_click: bool = _click_history.erase(key)


## 移除指定来源和可选设备中已结束指针的点击历史与时间高水位，并推进及清理受影响 epoch。
## 活动捕获对应的生命周期状态会保留。
## [br]
## @api private
## [br]
func _remove_completed_source_lifecycle_state(source_id: StringName, device_id: int) -> void:
	var affected_pointer_keys: Dictionary = {}
	for click_key_variant: Variant in _click_history.keys():
		if not click_key_variant is String:
			continue
		var click_key: String = click_key_variant
		var click: ClickRecord = _get_click_record(click_key)
		if (
			click == null
			or click.source_id != source_id
			or (device_id >= 0 and click.device_id != device_id)
		):
			continue
		var pointer_key: String = _make_pointer_key(
			click.source_id,
			click.device_id,
			click.pointer_id
		)
		if _captures.has(pointer_key):
			continue
		var _erased_click: bool = _click_history.erase(click_key)
		affected_pointer_keys[pointer_key] = true
	for pointer_key_variant: Variant in _pointer_timestamp_high_water.keys():
		if not pointer_key_variant is String:
			continue
		var pointer_key: String = pointer_key_variant
		if (
			_captures.has(pointer_key)
			or not _pointer_key_matches_source(pointer_key, source_id, device_id)
		):
			continue
		var _erased_timestamp: bool = _pointer_timestamp_high_water.erase(pointer_key)
		affected_pointer_keys[pointer_key] = true
	for pointer_key_variant: Variant in affected_pointer_keys.keys():
		if pointer_key_variant is String:
			var pointer_key: String = pointer_key_variant
			_advance_pointer_epoch(pointer_key)
			_prune_pointer_epoch(pointer_key)


## 解析指针键中的长度前缀来源和设备字段，判断其是否匹配给定来源及可选设备。
## device_id 小于 0 时只要求来源匹配。
## [br]
## @api private
## [br]
static func _pointer_key_matches_source(
	pointer_key: String,
	source_id: StringName,
	device_id: int
) -> bool:
	var source: String = String(source_id)
	var prefix: String = "%d:%s:" % [source.length(), source]
	if not pointer_key.begins_with(prefix):
		return false
	if device_id < 0:
		return true
	var remainder: String = pointer_key.substr(prefix.length())
	var separator: int = remainder.find(":")
	if separator <= 0:
		return false
	var device_text: String = remainder.left(separator)
	return device_text.is_valid_int() and int(device_text) == device_id


## 从捕获表读取指定键并收窄为 CaptureRecord；其他类型返回 null。
## [br]
## @api private
## [br]
func _get_capture_record(key: String) -> CaptureRecord:
	var value: Variant = _captures.get(key)
	if value is CaptureRecord:
		var record: CaptureRecord = value
		return record
	return null


## 从点击历史读取指定键并收窄为 ClickRecord；其他类型返回 null。
## [br]
## @api private
## [br]
func _get_click_record(key: String) -> ClickRecord:
	var value: Variant = _click_history.get(key)
	if value is ClickRecord:
		var click: ClickRecord = value
		return click
	return null


## 通过捕获记录保存的弱引用取得回执；记录、引用或对象类型无效时返回 null。
## [br]
## @api private
## [br]
func _get_receipt(record: CaptureRecord) -> GFViewportSurfaceInputCapture:
	if record == null or record.receipt_ref == null:
		return null
	var value: Variant = record.receipt_ref.get_ref()
	if value is GFViewportSurfaceInputCapture:
		var receipt: GFViewportSurfaceInputCapture = value
		return receipt
	return null


## 通过捕获记录的目标弱引用取得 Viewport，并仅返回仍处于可用状态的目标。
## [br]
## @api private
## [br]
func _get_live_target(record: CaptureRecord) -> Viewport:
	if record == null or record.target_ref == null:
		return null
	var value: Variant = record.target_ref.get_ref()
	if value is Viewport:
		var target: Viewport = value
		return target if _target_is_live(target) else null
	return null


## 通过点击记录的目标弱引用取得仍可用的 Viewport。
## [br]
## @api private
## [br]
func _get_click_target(click: ClickRecord) -> Viewport:
	if click == null or click.target_ref == null:
		return null
	var value: Variant = click.target_ref.get_ref()
	if value is Viewport:
		var target: Viewport = value
		return target if _target_is_live(target) else null
	return null


## 取得当前捕获代际后递增计数；计数变为非正数时下一个值重置为 1。
## [br]
## @api private
## [br]
func _take_capture_generation() -> int:
	var generation: int = _next_capture_generation
	_next_capture_generation += 1
	if _next_capture_generation <= 0:
		_next_capture_generation = 1
	return generation


## 使用来源字符串长度、来源、设备和指针组成无歧义的内部复合键。
## [br]
## @api private
## [br]
static func _make_pointer_key(source_id: StringName, device_id: int, pointer_id: int) -> String:
	var source: String = String(source_id)
	return "%d:%s:%d:%d" % [source.length(), source, device_id, pointer_id]


## 在指针复合键后追加鼠标按钮编号，生成点击历史键。
## [br]
## @api private
## [br]
static func _make_click_key(
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	mouse_button: int
) -> String:
	return "%s:%d" % [_make_pointer_key(source_id, device_id, pointer_id), mouse_button]


## 判断 Viewport 非空、实例有效且已进入 SceneTree。
## [br]
## @api private
## [br]
static func _target_is_live(target: Viewport) -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


## 读取有效目标尺寸；SubViewport 使用其 size，其他 Viewport 使用可见矩形尺寸，无效或非正尺寸返回零。
## [br]
## @api private
## [br]
static func _get_target_size(target: Viewport) -> Vector2:
	if not _target_is_live(target):
		return Vector2.ZERO
	var size: Vector2 = target.get_visible_rect().size
	if target is SubViewport:
		var sub_viewport: SubViewport = target
		size = Vector2(sub_viewport.size)
	if not _vector_is_finite(size) or size.x <= 0.0 or size.y <= 0.0:
		return Vector2.ZERO
	return size


## 检查标准化坐标有限且两个分量都位于闭区间 [0, 1]。
## [br]
## @api private
## [br]
static func _normalized_position_is_valid(position: Vector2) -> bool:
	return (
		_vector_is_finite(position)
		and position.x >= 0.0
		and position.x <= 1.0
		and position.y >= 0.0
		and position.y <= 1.0
	)


## 将标准化坐标映射到目标像素坐标，最大坐标为各维尺寸减 1 的非负值。
## [br]
## @api private
## [br]
static func _uv_to_position(normalized_position: Vector2, size: Vector2) -> Vector2:
	var last_position: Vector2 = Vector2(
		maxf(size.x - 1.0, 0.0),
		maxf(size.y - 1.0, 0.0)
	)
	return normalized_position * last_position


## 判断按钮是否位于内部支持的五种非滚轮鼠标按钮列表中。
## [br]
## @api private
## [br]
static func _mouse_button_is_supported(mouse_button: MouseButton) -> bool:
	return mouse_button in _MOUSE_BUTTONS


## 返回受支持鼠标按钮对应的掩码位；不支持时返回 0。
## [br]
## @api private
## [br]
static func _mouse_button_bit(mouse_button: MouseButton) -> int:
	if not _mouse_button_is_supported(mouse_button):
		return 0
	return 1 << (int(mouse_button) - 1)


## 检查标量既不是 NaN 也不是无穷值。
## [br]
## @api private
## [br]
static func _is_finite_scalar(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


## 检查 Vector2 两个分量均为有限值。
## [br]
## @api private
## [br]
static func _vector_is_finite(value: Vector2) -> bool:
	return _is_finite_scalar(value.x) and _is_finite_scalar(value.y)


# --- 内部类 ---

## 单个表面指针捕获的框架内部状态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 11.0.0
class CaptureRecord extends RefCounted:
	## 捕获表中的复合键。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var key: String = ""

	## 输入来源标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var source_id: StringName = &""

	## 输入设备标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var device_id: int = -1

	## 来源内的指针标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var pointer_id: int = -1

	## 指针类型。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var pointer_type: int = -1

	## 当前捕获代次。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var capture_generation: int = 0

	## 当前目标身份代次。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_generation: int = 0

	## 捕获目标的实例标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_instance_id: int = 0

	## 捕获目标的弱引用。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_ref: WeakRef = null

	## 返回给调用方的回执弱引用。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var receipt_ref: WeakRef = null

	## 最近一次合法的归一化坐标。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var last_uv: Vector2 = Vector2.ZERO

	## 最近一次接受的单调时间戳。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var last_timestamp_msec: int = 0

	## 当前按下的鼠标按钮位掩码。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var button_mask: int = 0


## 单个鼠标点击序列的框架内部状态。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 11.0.0
class ClickRecord extends RefCounted:
	## 输入来源标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var source_id: StringName = &""

	## 输入设备标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var device_id: int = -1

	## 来源内的指针标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var pointer_id: int = -1

	## 参与点击序列的鼠标按钮。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var mouse_button: int = 0

	## 点击时目标的身份代次。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_generation: int = 0

	## 点击目标的实例标识。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_instance_id: int = 0

	## 点击目标的弱引用。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var target_ref: WeakRef = null

	## 最近点击的归一化坐标。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var normalized_position: Vector2 = Vector2.ZERO

	## 最近一次点击的单调时间戳。
	## [br]
	## @api framework_internal
	## [br]
	## @since 11.0.0
	var timestamp_msec: int = 0
